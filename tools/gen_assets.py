"""Pipeline d'assets de Wreck & Resell (ComfyUI → pixelize → assets/ + manifeste).

Étapes :
  generate      génère les images brutes manquantes (art/raw/, ignoré par git) via l'API HTTP de ComfyUI
  sheets        planches de revue par catégorie (art/review/*.png)
  build         post-traite la graine retenue (art/selection.json) vers assets/, écrit art/manifest.json,
                assets/ships/anchors.json, les dérivés UI 9-slice, assets/palette.png et docs/AI_DISCLOSURE.md
  placeholders  crée des formes simples conformes à la palette pour tout asset absent (développement)
  validate      vérifie les workflows contre /object_info (ou l'instantané hors ligne)

Usage : python tools/gen_assets.py generate [--only hull,icon] | sheets | build | placeholders | validate
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asset_specs  # noqa: E402
import comfy_client as cc  # noqa: E402
import pixelize  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "art" / "raw"
REVIEW = ROOT / "art" / "review"
ASSETS = ROOT / "assets"
MANIFEST = ROOT / "art" / "manifest.json"
SELECTION = ROOT / "art" / "selection.json"
WORKFLOW = "zimage_turbo_txt2img"
MODEL = "z_image_turbo_bf16.safetensors (Z-Image-Turbo, Apache-2.0) + qwen_3_4b + ae ; détourage BiRefNet (MIT)"


def raw_path(spec: dict[str, Any], seed: int, mask: bool = False) -> Path:
    return RAW / spec["category"] / f"{spec['id']}__s{seed}{'_mask' if mask else ''}.png"


def selection() -> dict[str, int]:
    if SELECTION.exists():
        return {k: int(v) for k, v in json.loads(SELECTION.read_text(encoding="utf-8")).items() if not k.startswith("_")}
    return {}


def chosen_seed(spec: dict[str, Any], sel: dict[str, int]) -> int:
    return int(sel.get(spec["id"], spec["seeds"][0]))


def generate(only: set[str] | None) -> None:
    client = cc.ComfyClient()
    if not client.alive():
        raise SystemExit("ComfyUI injoignable : " + client.base)
    wf = cc.load_workflow(WORKFLOW)
    todo = [(s, seed) for s in asset_specs.specs() for seed in s["seeds"] if (not only or s["category"] in only or s["id"] in only)]
    sel = selection()
    for s in asset_specs.specs():
        if s["id"] in sel and sel[s["id"]] not in s["seeds"] and (not only or s["category"] in only or s["id"] in only):
            todo.append((s, sel[s["id"]]))
    t_all = time.time()
    done = 0
    for spec, seed in todo:
        rp = raw_path(spec, seed)
        if rp.exists():
            continue
        rp.parent.mkdir(parents=True, exist_ok=True)
        params = {"POSITIVE": spec["prompt"], "NEGATIVE": asset_specs.NEGATIVE, "SEED": seed, "WIDTH": spec["w"], "HEIGHT": spec["h"], "PREFIX": f"wr_assets/{spec['id']}_s{seed}"}
        t0 = time.time()
        imgs = client.run(cc.fill(wf, params), timeout=900)
        rp.write_bytes(imgs["8"][0])
        raw_path(spec, seed, True).write_bytes(imgs["12"][0])
        done += 1
        print(f"[{done}] {spec['category']}/{spec['id']} s{seed} {time.time() - t0:.1f}s", flush=True)
    print(f"génération terminée : {done} images en {time.time() - t_all:.0f}s", flush=True)


def process_spec(spec: dict[str, Any], seed: int) -> Image.Image:
    rp = raw_path(spec, seed)
    mp = raw_path(spec, seed, True)
    raw = Image.open(rp)
    mask = Image.open(mp) if mp.exists() and spec["pp"].get("mode") == "sprite" else None
    return pixelize.process(raw, mask, spec["pp"])


def sheets(only: set[str] | None) -> None:
    REVIEW.mkdir(parents=True, exist_ok=True)
    by_cat: dict[str, list[dict[str, Any]]] = {}
    for s in asset_specs.specs():
        if only and s["category"] not in only:
            continue
        by_cat.setdefault(s["category"], []).append(s)
    for cat, items in by_cat.items():
        seeds = max(len(s["seeds"]) for s in items)
        cell = 120 if cat != "background" else 500
        cols = seeds * 2
        per_row = max(1, 1500 // (cell * cols))
        rows = (len(items) + per_row - 1) // per_row
        sheet = Image.new("RGB", (per_row * cols * cell, rows * (cell + 14)), (30, 30, 40))
        dr = ImageDraw.Draw(sheet)
        for i, s in enumerate(items):
            r, c = divmod(i, per_row)
            x0, y0 = c * cols * cell, r * (cell + 14)
            dr.text((x0 + 2, y0), s["id"], fill=(220, 220, 220))
            for k, seed in enumerate(s["seeds"]):
                rp = raw_path(s, seed)
                if not rp.exists():
                    continue
                th = Image.open(rp).convert("RGB")
                th.thumbnail((cell - 4, cell - 4))
                sheet.paste(th, (x0 + k * 2 * cell + 2, y0 + 14))
                try:
                    px = process_spec(s, seed)
                except Exception as exc:  # garder la planche lisible
                    dr.text((x0 + (k * 2 + 1) * cell, y0 + 40), str(exc)[:18], fill=(255, 90, 90))
                    continue
                sc = max(1, min((cell - 4) // px.width, (cell - 4) // px.height))
                big = px.resize((px.width * sc, px.height * sc), Image.NEAREST)
                bg = Image.new("RGBA", big.size, (70, 70, 90, 255))
                bg.alpha_composite(big)
                sheet.paste(bg.convert("RGB"), (x0 + (k * 2 + 1) * cell + 2, y0 + 14))
                dr.text((x0 + (k * 2 + 1) * cell + 2, y0 + cell), f"s{seed}", fill=(255, 220, 120))
        out = REVIEW / f"{cat}.png"
        sheet.save(out)
        print("planche :", out)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def derive_ui(manifest: list[dict[str, Any]]) -> None:
    """Construit les 9-slices (panneaux, boutons, cadre) à partir des sources UI générées."""
    general, _ = pixelize.load_palette()
    pal = [tuple(int(v) for v in c) for c in general]

    def symmetric(src: Image.Image, w: int, h: int) -> Image.Image:
        # quart supérieur gauche miroité : 9-slice parfaitement symétrique
        s = src.resize((w, h), Image.NEAREST)
        a = np.array(s)
        hw, hh = (w + 1) // 2, (h + 1) // 2
        q = a[:hh, :hw]
        top = np.concatenate([q, q[:, : w - hw][:, ::-1]], axis=1)
        full = np.concatenate([top, top[: h - hh][::-1]], axis=0)
        return Image.fromarray(full, "RGBA")

    def shade(img: Image.Image, steps: int) -> Image.Image:
        """Éclaircit (+) ou assombrit (-) en restant dans la palette (déplacement de luminance)."""
        a = np.array(img).copy()
        lab = pixelize.srgb_to_oklab(np.array(pal, dtype=np.uint8))
        order = list(np.argsort(lab[:, 0]))
        for y in range(a.shape[0]):
            for x in range(a.shape[1]):
                if a[y, x, 3] == 0:
                    continue
                c = tuple(int(v) for v in a[y, x, :3])
                if c not in pal:
                    continue
                i = order.index(pal.index(c))
                j = int(np.clip(i + steps, 0, len(order) - 1))
                a[y, x, :3] = pal[order[j]]
        return Image.fromarray(a, "RGBA")

    def flatten_center(img: Image.Image, margin: int) -> Image.Image:
        a = np.array(img).copy()
        h, w = a.shape[:2]
        center = a[h // 2, w // 2].copy()
        a[margin:h - margin, margin:w - margin] = center
        a[..., 3] = 255
        return Image.fromarray(a, "RGBA")

    src_panel = ASSETS / "ui" / "_panel_src.png"
    src_button = ASSETS / "ui" / "_button_src.png"
    if not src_panel.exists() or not src_button.exists():
        return
    panel = flatten_center(symmetric(Image.open(src_panel).convert("RGBA"), 24, 24), 6)
    button = flatten_center(symmetric(Image.open(src_button).convert("RGBA"), 24, 12), 4)
    outputs = {
        "panel": panel,
        "panel_dark": shade(panel, -2),
        "frame": shade(panel, 1),
        "button": button,
        "button_hover": shade(button, 2),
        "button_pressed": shade(button, -2),
        "button_disabled": shade(shade(button, -3), 0),
    }
    for name, img in outputs.items():
        out = ASSETS / "ui" / f"{name}.png"
        img.save(out)
        manifest.append({"id": f"ui_{name}", "category": "ui", "file": f"assets/ui/{name}.png", "source": "derived",
                         "derived_from": ["assets/ui/_panel_src.png" if "panel" in name or name == "frame" else "assets/ui/_button_src.png"],
                         "process": "quart miroité (9-slice symétrique), centre aplati, décalage de luminance dans la palette",
                         "size": [img.width, img.height], "sha256": sha256(out)})


def write_palette_png(manifest: list[dict[str, Any]]) -> None:
    data = json.loads(pixelize.PALETTE_FILE.read_text(encoding="utf-8"))
    cols = [pixelize.hex_to_rgb(c) for c in data["colors"]]
    img = Image.new("RGBA", (len(cols), 1))
    for i, c in enumerate(cols):
        img.putpixel((i, 0), (*c, 255))
    out = ASSETS / "palette.png"
    img.save(out)
    manifest.append({"id": "palette", "category": "palette", "file": "assets/palette.png", "source": "handmade",
                     "process": "palette globale de 32 couleurs (art/palette.json), conçue pour le projet", "sha256": sha256(out)})


def build(allow_missing: bool) -> None:
    sel = selection()
    manifest: list[dict[str, Any]] = []
    anchors: dict[str, Any] = {}
    missing: list[str] = []
    for spec in asset_specs.specs():
        seed = chosen_seed(spec, sel)
        if not raw_path(spec, seed).exists():
            missing.append(f"{spec['id']} (s{seed})")
            continue
        img = process_spec(spec, seed)
        out = ASSETS / spec["out"]
        out.parent.mkdir(parents=True, exist_ok=True)
        img.save(out)
        n, bad = pixelize.palette_report(img)
        if bad:
            raise SystemExit(f"{out}: couleurs hors palette {bad[:5]}")
        if spec["category"] in ("hull", "engine", "cockpit", "wings"):
            anchors[spec["id"]] = pixelize.anchors_for(img, spec["category"])
        manifest.append({
            "id": spec["id"], "category": spec["category"], "file": f"assets/{spec['out']}", "source": "comfyui",
            "model": MODEL, "workflow": f"comfy/workflows/{WORKFLOW}.json", "prompt": spec["prompt"],
            "negative": asset_specs.NEGATIVE, "seed": seed, "candidates": spec["seeds"], "gen_size": [spec["w"], spec["h"]],
            "postprocess": {"tool": "tools/pixelize.py", **spec["pp"]}, "size": [img.width, img.height], "colors": n,
            "sha256": sha256(out),
        })
    if missing and not allow_missing:
        raise SystemExit("images brutes manquantes : " + ", ".join(missing[:20]))
    derive_ui(manifest)
    write_palette_png(manifest)
    (ASSETS / "ships").mkdir(parents=True, exist_ok=True)
    (ASSETS / "ships" / "anchors.json").write_text(json.dumps(anchors, indent=1), encoding="utf-8")
    MANIFEST.write_text(json.dumps({"_comment": "Traçabilité des assets : prompt, graine, workflow, modèle, post-traitement.", "palette": "art/palette.json", "assets": manifest}, indent=1, ensure_ascii=False), encoding="utf-8")
    write_disclosure(manifest)
    print(f"build : {len(manifest)} entrées de manifeste, {len(anchors)} pièces ancrées, {len(missing)} manquants")


def write_disclosure(manifest: list[dict[str, Any]]) -> None:
    gen = [m for m in manifest if m["source"] == "comfyui"]
    by_cat: dict[str, int] = {}
    for m in gen:
        by_cat[m["category"]] = by_cat.get(m["category"], 0) + 1
    lines = [
        "# Déclaration d'utilisation de l'IA générative (AI disclosure)",
        "",
        "Ce fichier est régénéré par `python tools/gen_assets.py build` ; le détail exhaustif (prompt, graine,",
        "workflow, post-traitement, empreinte SHA-256) de chaque fichier se trouve dans `art/manifest.json`.",
        "",
        "## Résumé pour la page Steam (section « AI Generated Content Disclosure »)",
        "",
        "> **Pre-generated content** : all 2D pixel art (spaceship parts, wear overlays, character portraits, icons,",
        "> backgrounds and UI frames) was generated locally with the open-weights model Z-Image-Turbo (Apache-2.0)",
        "> through ComfyUI, then reduced and quantized to a hand-made 32-color palette by our own script",
        "> (`tools/pixelize.py`). Background removal uses BiRefNet (MIT). No live/runtime AI generation happens in",
        "> the game. Prompts describe original concepts only: no artist, studio, franchise or existing character",
        "> was referenced or imitated. Game code, design, story and texts were written with the help of an AI",
        "> coding assistant (Claude) under human direction.",
        "",
        "## Outils et modèles",
        "",
        "| Rôle | Modèle / outil | Licence |",
        "|---|---|---|",
        "| Génération d'images (retenu) | Z-Image-Turbo bf16 + encodeur Qwen3-4B + VAE ae | Apache-2.0 |",
        "| Détourage | BiRefNet (nœud ComfyUI RemoveBackground) | MIT |",
        "| Post-traitement | tools/pixelize.py (code du projet) | propriétaire du projet |",
        "| Évalués puis écartés | SDXL base 1.0 + LoRA pixel-art-xl, FLUX.1-schnell, Qwen-Image 2512 | voir MODEL_LICENSES.md |",
        "",
        "## Assets générés par catégorie",
        "",
        "| Catégorie | Nombre |",
        "|---|---|",
    ]
    for cat, n in sorted(by_cat.items()):
        lines.append(f"| {cat} | {n} |")
    lines += ["", f"Total : {len(gen)} fichiers générés, {len(manifest) - len(gen)} dérivés ou faits main.", "",
              "## Liste des fichiers", "", "| Fichier | Graine | Prompt (début) |", "|---|---|---|"]
    for m in gen:
        p = m["prompt"].replace("|", "/")
        lines.append(f"| `{m['file']}` | {m['seed']} | {p[:110]}… |")
    (ROOT / "docs" / "AI_DISCLOSURE.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def placeholders() -> None:
    """Formes simples (palette respectée) pour développer l'UI avant l'art final."""
    general, primer = pixelize.load_palette()
    g = [tuple(int(v) for v in c) for c in general]
    pr = [tuple(int(v) for v in c) for c in primer]
    rng = np.random.default_rng(7)
    anchors: dict[str, Any] = {}
    made = 0
    for spec in asset_specs.specs():
        out = ASSETS / spec["out"]
        if out.exists():
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        pp = spec["pp"]
        size = pp.get("canvas") or pp.get("size") or pp.get("max")
        w, h = int(size[0]), int(size[1])
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        col = g[int(rng.integers(6, len(g)))]
        if spec["category"] == "background":
            d.rectangle([0, 0, w, h], fill=g[1])
            for i in range(0, w, 40):
                d.rectangle([i, h - 60, i + 36, h - 4], outline=g[3], fill=g[2])
        elif spec["category"] in ("hull", "wings"):
            d.ellipse([1, 1, w - 2, h - 2], fill=pr[1], outline=g[0])
            d.ellipse([w // 4, h // 4, w // 2, h // 2], fill=pr[2])
        elif spec["category"] == "wear":
            for _ in range(12):
                x, y = int(rng.integers(0, w)), int(rng.integers(0, h))
                d.rectangle([x, y, x + 2, y + 1], fill=g[9])
        else:
            d.rectangle([1, 1, w - 2, h - 2], fill=col, outline=g[0])
        img.save(out)
        if spec["category"] in ("hull", "engine", "cockpit", "wings"):
            anchors[spec["id"]] = pixelize.anchors_for(img, spec["category"])
        made += 1
    ap = ASSETS / "ships" / "anchors.json"
    if not ap.exists() or made:
        old = json.loads(ap.read_text(encoding="utf-8")) if ap.exists() else {}
        old.update(anchors)
        ap.write_text(json.dumps(old, indent=1), encoding="utf-8")
    print(f"placeholders : {made} fichiers créés")


def validate() -> int:
    client = cc.ComfyClient()
    errors: list[str] = []
    classes: set[str] = set()
    if client.alive():
        oi = client.object_info()
        source = "/object_info (live)"
    else:
        oi = json.loads(cc.SNAPSHOT.read_text(encoding="utf-8"))
        source = "instantané hors ligne"
    for wf_path in sorted(cc.WORKFLOW_DIR.glob("*.json")):
        wf = json.loads(wf_path.read_text(encoding="utf-8"))
        dummy = {k: (1 if k in ("SEED", "WIDTH", "HEIGHT") else 1.0 if k == "LORA_STRENGTH" else "x") for k in cc.placeholders(wf)}
        dummy.update({"WIDTH": 1024, "HEIGHT": 1024})
        filled = cc.fill(wf, dummy)
        errs = cc.validate(filled, oi)
        classes |= {n["class_type"] for k, n in wf.items() if not k.startswith("_")}
        errors += [f"{wf_path.name}: {e}" for e in errs]
        print(f"{wf_path.name}: {'OK' if not errs else str(len(errs)) + ' erreur(s)'} ({source})")
    if client.alive():
        cc.save_snapshot(client, classes)
    for e in errors:
        print("  ", e)
    return 1 if errors else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("step", choices=["generate", "sheets", "build", "placeholders", "validate"])
    ap.add_argument("--only", default="")
    ap.add_argument("--allow-missing", action="store_true")
    args = ap.parse_args()
    only = {x for x in args.only.split(",") if x} or None
    if args.step == "generate":
        generate(only)
    elif args.step == "sheets":
        sheets(only)
    elif args.step == "build":
        build(args.allow_missing)
    elif args.step == "placeholders":
        placeholders()
    elif args.step == "validate":
        return validate()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
