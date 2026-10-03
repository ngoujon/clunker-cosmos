"""Pipeline d'assets de Clunker Cosmos (ComfyUI → hd_art → assets/ + manifeste).

Étapes :
  generate      génère les images brutes manquantes (art/raw_hd/, ignoré par git) via l'API HTTP de ComfyUI
                (txt2img, ou img2img depuis une image de composition pour le garage)
  sheets        planches de revue par catégorie (art/review/*.png)
  build         post-traite la graine retenue (art/selection.json) vers assets/ (images à DETAIL × la taille
                logique, masques de peinture), écrit art/manifest.json, assets/ships/anchors.json (en pixels
                logiques) et docs/AI_DISCLOSURE.md
  placeholders  crée des formes simples conformes à la palette pour tout asset absent (développement)
  validate      vérifie les workflows contre /object_info (ou l'instantané hors ligne)

Usage : python tools/gen_assets.py generate [--only hull,icon] | sheets | build | placeholders | validate
"""
from __future__ import annotations

import argparse
import hashlib
import io
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
import hd_art  # noqa: E402
import pixelize  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "art" / "raw_hd"
REVIEW = ROOT / "art" / "review"
ASSETS = ROOT / "assets"
MANIFEST = ROOT / "art" / "manifest.json"
SELECTION = ROOT / "art" / "selection.json"
WORKFLOW = "zimage_turbo_txt2img"
WORKFLOW_I2I = "zimage_turbo_img2img"
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
    wf_i2i = cc.load_workflow(WORKFLOW_I2I)
    todo = [(s, seed) for s in asset_specs.specs() for seed in s["seeds"]
            if (not only or s["category"] in only or s["id"] in only) and s["id"] not in asset_specs.HANDMADE_ICONS]
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
        params = {"POSITIVE": spec["prompt"], "NEGATIVE": asset_specs.NEGATIVE, "SEED": seed, "WIDTH": spec["w"], "HEIGHT": spec["h"], "PREFIX": f"cc25d/{spec['id']}_s{seed}"}
        t0 = time.time()
        if spec.get("init"):
            init = Image.open(ROOT / spec["init"]).convert("RGB").resize((spec["w"], spec["h"]), Image.LANCZOS)
            buf = io.BytesIO()
            init.save(buf, "PNG")
            params["INIT"] = client.upload_image(f"cc25d_{spec['id']}_init.png", buf.getvalue())
            params["DENOISE"] = float(spec.get("denoise", 0.6))
            imgs = client.run(cc.fill(wf_i2i, params), timeout=900)
        else:
            imgs = client.run(cc.fill(wf, params), timeout=900)
        rp.write_bytes(imgs["8"][0])
        if "12" in imgs:
            raw_path(spec, seed, True).write_bytes(imgs["12"][0])
        done += 1
        print(f"[{done}] {spec['category']}/{spec['id']} s{seed} {time.time() - t0:.1f}s", flush=True)
    print(f"génération terminée : {done} images en {time.time() - t_all:.0f}s", flush=True)


def process_spec(spec: dict[str, Any], seed: int) -> tuple[Image.Image, Image.Image | None]:
    rp = raw_path(spec, seed)
    mp = raw_path(spec, seed, True)
    raw = Image.open(rp)
    mask = Image.open(mp) if mp.exists() and spec["pp"].get("mode") == "sprite" else None
    return hd_art.process(raw, mask, spec["pp"])


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
                    hd, _ = process_spec(s, seed)
                except Exception as exc:  # garder la planche lisible
                    dr.text((x0 + (k * 2 + 1) * cell, y0 + 40), str(exc)[:18], fill=(255, 90, 90))
                    continue
                big = hd.copy()
                big.thumbnail((cell - 4, cell - 4), Image.LANCZOS)
                bg = Image.new("RGBA", big.size, (70, 70, 90, 255))
                bg.alpha_composite(big)
                sheet.paste(bg.convert("RGB"), (x0 + (k * 2 + 1) * cell + 2, y0 + 14))
                dr.text((x0 + (k * 2 + 1) * cell + 2, y0 + cell), f"s{seed}", fill=(255, 220, 120))
        out = REVIEW / f"{cat}.png"
        sheet.save(out)
        print("planche :", out)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def handmade_icons(manifest: list[dict[str, Any]]) -> None:
    """Symboles de lecture (pause, lecture, ×2, ×4) dessinés par code, lissés (suréchantillonnage ×4)."""
    ss = 4
    n = 16 * hd_art.DETAIL
    big = n * ss
    fill, dark = (245, 220, 106, 255), (13, 14, 20, 230)
    u = big / 16.0

    def tri(d: ImageDraw.ImageDraw, x0: float, w: float, col: tuple[int, ...], grow: float = 0.0) -> None:
        d.polygon([((x0 - grow) * u, (3 - grow) * u), ((x0 + w + grow * 1.6) * u, 8 * u), ((x0 - grow) * u, (13 + grow) * u)], fill=col)

    def bars(d: ImageDraw.ImageDraw, col: tuple[int, ...], grow: float = 0.0) -> None:
        for x in (4.0, 9.0):
            d.rounded_rectangle([(x - grow) * u, (3 - grow) * u, (x + 3 + grow) * u, (13 + grow) * u], radius=0.8 * u, fill=col)

    shapes: dict[str, Any] = {
        "ui_pause": lambda d, c, g: bars(d, c, g),
        "ui_play": lambda d, c, g: tri(d, 5, 7, c, g),
        "ui_fast": lambda d, c, g: (tri(d, 2, 6, c, g), tri(d, 8, 6, c, g)),
        "ui_faster": lambda d, c, g: (tri(d, 1, 5, c, g), tri(d, 6, 5, c, g), tri(d, 11, 4, c, g)),
    }
    for name, draw_fn in shapes.items():
        img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        draw_fn(d, dark, 0.9)
        draw_fn(d, fill, 0.0)
        img = img.resize((n, n), Image.LANCZOS)
        out = ASSETS / "icons" / f"{name}.png"
        img.save(out)
        manifest.append({"id": name, "category": "icon", "file": f"assets/icons/{name}.png", "source": "handmade",
                         "process": "symbole dessiné par code (tools/gen_assets.py handmade_icons), lissé",
                         "size": [n, n], "sha256": sha256(out)})


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
        if spec["id"] in asset_specs.HANDMADE_ICONS:
            continue
        seed = chosen_seed(spec, sel)
        if not raw_path(spec, seed).exists():
            missing.append(f"{spec['id']} (s{seed})")
            continue
        img, paint = process_spec(spec, seed)
        out = ASSETS / spec["out"]
        out.parent.mkdir(parents=True, exist_ok=True)
        img.save(out)
        if paint is not None:
            paint.save(out.with_name(out.stem + "_paint.png"))
        if spec["category"] in ("hull", "engine", "cockpit", "wings"):
            anchors[spec["id"]] = pixelize.anchors_for(hd_art.logical_alpha(img), spec["category"])
        manifest.append({
            "id": spec["id"], "category": spec["category"], "file": f"assets/{spec['out']}", "source": "comfyui",
            "model": MODEL, "workflow": f"comfy/workflows/{WORKFLOW}.json", "prompt": spec["prompt"],
            "negative": asset_specs.NEGATIVE, "seed": seed, "candidates": spec["seeds"], "gen_size": [spec["w"], spec["h"]],
            "init": spec.get("init"), "denoise": spec.get("denoise"),
            "postprocess": {"tool": "tools/hd_art.py", "detail": hd_art.DETAIL, **spec["pp"]}, "size": [img.width, img.height],
            "sha256": sha256(out),
        })
        if spec["category"] == "portrait":
            # Version 24×24 (logique) réduite depuis l'image HD.
            pp_small = {**spec["pp"], "max": [24, 24], "canvas": [24, 24]}
            small = hd_art.downsize(img, (24, 24))
            sout = ASSETS / "portraits" / "small" / f"{spec['id']}.png"
            sout.parent.mkdir(parents=True, exist_ok=True)
            small.save(sout)
            manifest.append({
                "id": spec["id"] + "_small", "category": "portrait_small", "file": f"assets/portraits/small/{spec['id']}.png",
                "source": "comfyui", "model": MODEL, "workflow": f"comfy/workflows/{WORKFLOW}.json", "prompt": spec["prompt"],
                "negative": asset_specs.NEGATIVE, "seed": seed, "candidates": spec["seeds"], "gen_size": [spec["w"], spec["h"]],
                "postprocess": {"tool": "tools/hd_art.py", "detail": hd_art.DETAIL, **pp_small}, "size": [small.width, small.height],
                "sha256": sha256(sout),
            })
    if missing and not allow_missing:
        raise SystemExit("images brutes manquantes : " + ", ".join(missing[:20]))
    handmade_icons(manifest)
    write_palette_png(manifest)
    (ASSETS / "ships").mkdir(parents=True, exist_ok=True)
    (ASSETS / "ships" / "anchors.json").write_text(json.dumps(anchors, indent=1), encoding="utf-8", newline="\n")
    MANIFEST.write_text(json.dumps({"_comment": "Traçabilité des assets : prompt, graine, workflow, modèle, post-traitement.", "palette": "art/palette.json", "assets": manifest}, indent=1, ensure_ascii=False), encoding="utf-8", newline="\n")
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
        "> **Pre-generated content** : all 2D pixel art (spaceship parts, wear overlays, character portraits and",
        "> sprites, icons, backgrounds and UI frames) was generated locally with the open-weights model Z-Image-Turbo (Apache-2.0)",
        "> through ComfyUI, then reduced and quantized to a hand-made 32-color palette by our own script",
        "> (`tools/pixelize.py`). Background removal uses BiRefNet (MIT). The five instrumental music tracks were",
        "> pre-generated locally with the open-weights model ACE-Step 1.5 (MIT) from generic style descriptions,",
        "> then mastered by our own script (`tools/gen_audio.py`); sound effects are synthesized by code, without AI.",
        "> No live/runtime AI generation happens in the game. Prompts describe original concepts only: no artist,",
        "> studio, franchise, existing work or character was referenced or imitated. Game code, design, story and",
        "> texts were written with the help of an AI coding assistant (Claude) under human direction.",
        "",
        "## Outils et modèles",
        "",
        "| Rôle | Modèle / outil | Licence |",
        "|---|---|---|",
        "| Génération d'images (retenu) | Z-Image-Turbo bf16 + encodeur Qwen3-4B + VAE ae | Apache-2.0 |",
        "| Détourage | BiRefNet (nœud ComfyUI RemoveBackground) | MIT |",
        "| Musique (pré-générée) | ACE-Step 1.5 turbo (`ace_step_1.5_turbo_aio.safetensors`) | MIT (reconditionnement Comfy-Org Apache-2.0) |",
        "| Bruitages | tools/sfx_synth.py (synthèse procédurale, sans IA) | propriétaire du projet |",
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
    lines += _audio_disclosure()
    (ROOT / "docs" / "AI_DISCLOSURE.md").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def _audio_disclosure() -> list[str]:
    """Section « Audio » de la divulgation, depuis art/audio_manifest.json (tools/gen_audio.py)."""
    path = ROOT / "art" / "audio_manifest.json"
    if not path.exists():
        return []
    items = json.loads(path.read_text(encoding="utf-8")).get("assets", [])
    music = [a for a in items if a.get("type") == "music"]
    sfx = [a for a in items if a.get("type") == "sfx"]
    out = ["", "## Audio", "",
           "- **Musique** : pistes instrumentales **pré-générées localement** avec ACE-Step 1.5 turbo (licence MIT) dans",
           "  ComfyUI (workflow `comfy/workflows/ace_step15_music.json`, script `tools/gen_audio.py`) à partir de",
           "  descriptions de style génériques ; trois graines par piste, choix par mesures objectives, puis mastering",
           "  (-16 LUFS, fondus). Détail (invites, graines, réglages, mesures) dans `art/audio_manifest.json`.",
           f"- **Bruitages** : {len(sfx)} effets synthétisés par code (numpy, `tools/sfx_synth.py`), sans IA ni échantillon tiers.",
           "", "| Fichier | Rôle | Graine | Style demandé (début) |", "|---|---|---|---|"]
    for a in music:
        src = a.get("source", {})
        tags = str(src.get("tags", "")).replace("|", "/")
        out.append(f"| `{a['path']}` | {a.get('role', '')} | {src.get('seed', '')} | {tags[:100]}… |")
    return out


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
        ap.write_text(json.dumps(old, indent=1), encoding="utf-8", newline="\n")
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
