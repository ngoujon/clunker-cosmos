"""Vérification complète de Clunker Cosmos (bibliothèque standard uniquement, Python ≥ 3.10).

Usage : python tools/check_all.py [--skip-import]

Chaque contrôle affiche une ligne « [OK] » ou « [ÉCHEC] » ; le script se termine par
« ALL CHECKS PASSED » (code 0) uniquement si tout est vert.

Contrôles :
  1. import Godot (enregistrement des classes, aucune erreur de script)
  2. tests unitaires headless (≥ 50, RH, enchères, réparation/vente, arbre, quêtes, sauvegarde, réglages)
  3. simulation de 30 jours (≥ 10 ventes, résultat d'exploitation > 0, 0 erreur)
  4. chapitres 1 et 2 de l'histoire bouclés par l'autopilote
  5. test de fumée de l'interface (tous les écrans construits et manipulés en headless)
  6. validation des assets dans Godot (présence, tailles, palette ≤ 32 couleurs, ancrages)
  7. manifeste des assets (prompt, graine, workflow, empreintes) + divulgation IA ; manifeste audio
  8. workflows ComfyUI validés contre l'instantané /object_info + licences des modèles
  9. documents requis
 10. captures d'écran du vrai jeu (docs/screens)
"""
from __future__ import annotations

import hashlib
import json
import re
import struct
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import godot  # noqa: E402  (stdlib uniquement)

RESULTS: list[tuple[str, bool, str]] = []
ERROR_PATTERNS = ("SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR: ")


def report(name: str, ok: bool, detail: str) -> bool:
    RESULTS.append((name, ok, detail))
    mark = "[OK]    " if ok else "[ÉCHEC] "
    print(f"{mark}{name} — {detail}", flush=True)
    return ok


def godot_run(args: list[str], timeout: float = 900, headless: bool = True) -> tuple[int, str]:
    try:
        p = godot.run(args, timeout=timeout, headless=headless)
    except subprocess.TimeoutExpired:
        return 124, "TIMEOUT"
    return p.returncode, (p.stdout or "") + (p.stderr or "")


def script_errors(out: str) -> list[str]:
    return [ln.strip() for ln in out.splitlines() if any(p in ln for p in ERROR_PATTERNS)]


def parse_result(out: str) -> dict:
    for ln in reversed(out.splitlines()):
        if ln.startswith("##RESULT "):
            try:
                return json.loads(ln[len("##RESULT "):])
            except json.JSONDecodeError:
                return {}
    return {}


# --- 1. Import ------------------------------------------------------------------

def check_import() -> None:
    code, out = godot_run(["--import"], timeout=900)
    errs = script_errors(out)
    report("Import Godot", code == 0 and not errs, f"code {code}, {len(errs)} erreur(s)" + (f" : {errs[:3]}" if errs else ""))


# --- 2. Tests unitaires -----------------------------------------------------------

REQUIRED_SUITES = {
    "test_staff": "RH", "test_auction": "enchères", "test_workshop": "réparation", "test_market": "vente",
    "test_research": "arbre techno", "test_quests": "quêtes", "test_save": "sauvegarde",
    "test_settings": "réglages", "test_audio": "audio", "test_fonts": "polices",
}


def check_unit() -> None:
    code, out = godot_run(["res://tests/runner.tscn", "--", "--suite=unit"])
    res = parse_result(out)
    errs = script_errors(out)
    total, passed = int(res.get("total", 0)), int(res.get("passed", 0))
    suites = res.get("suites", {})
    missing = [f"{k} ({v})" for k, v in REQUIRED_SUITES.items() if int(suites.get(k, {}).get("total", 0)) == 0]
    ok = code == 0 and total >= 50 and passed == total and not missing and not errs
    detail = f"{passed}/{total} réussis, {len(suites)} suites"
    if missing:
        detail += f", suites manquantes : {missing}"
    if res.get("failures"):
        detail += f", échecs : {res['failures'][:5]}"
    if errs:
        detail += f", erreurs de script : {errs[:3]}"
    report("Tests unitaires headless", ok, detail)
    for k, v in REQUIRED_SUITES.items():
        s = suites.get(k, {})
        print(f"          · {v:<13} {s.get('passed', 0)}/{s.get('total', 0)}", flush=True)


# --- 3-4. Simulation et histoire -----------------------------------------------------

def check_sim() -> None:
    code, out = godot_run(["res://tests/runner.tscn", "--", "--suite=sim", "--days=30", "--seed=7", "--mode=classic"])
    r = parse_result(out)
    errs = script_errors(out)
    ok = code == 0 and int(r.get("sales", 0)) >= 10 and int(r.get("operating_profit", 0)) > 0 and not r.get("errors") and not errs
    report("Simulation 30 jours", ok, f"{r.get('sales', 0)} ventes, résultat d'exploitation {r.get('operating_profit', 0)} ¢, "
           f"{len(r.get('errors', []) or []) + len(errs)} erreur(s)")


def check_story() -> None:
    code, out = godot_run(["res://tests/runner.tscn", "--", "--suite=story", "--max-days=90", "--seed=11", "--chapters=2"])
    r = parse_result(out)
    errs = script_errors(out)
    ok = code == 0 and bool(r.get("ok", False)) and not errs
    chapters = r.get("chapters", {})
    done = [k for k, v in sorted(chapters.items()) if v]
    report("Histoire : chapitres 1-2 bouclés", ok and len(done) >= 2, f"chapitres terminés {done} au jour {r.get('day', '?')}, "
           f"{r.get('quests_done', 0)} quêtes, {len(errs)} erreur(s)")


# --- 5. Interface ------------------------------------------------------------------

def check_ui_smoke() -> None:
    code, out = godot_run(["res://scenes/main.tscn", "--", "--tour=smoke"], timeout=600)
    r = parse_result(out)
    errs = script_errors(out)
    screens = r.get("screens", {})
    ok = code == 0 and bool(r.get("ok", False)) and len(screens) >= 7 and not errs
    report("Interface (test de fumée headless)", ok, f"{len(screens)} écrans construits et manipulés, {len(errs) + len(r.get('errors', []))} erreur(s)")


# --- 6-7. Assets ------------------------------------------------------------------

def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("pas un PNG")
    return struct.unpack(">II", head[16:24])


def check_assets_godot() -> None:
    code, out = godot_run(["res://tests/runner.tscn", "--", "--suite=assets"])
    r = parse_result(out)
    ok = code == 0 and int(r.get("error_count", 1)) == 0 and int(r.get("colors", 99)) <= 32
    counts = r.get("counts", {})
    report("Assets (Godot)", ok, f"{r.get('assets', 0)} fichiers ({', '.join(f'{k} {v}' for k, v in sorted(counts.items()))}), "
           f"{r.get('colors', '?')} couleurs, {r.get('error_count', '?')} erreur(s)")


def check_manifest() -> None:
    mpath = ROOT / "art" / "manifest.json"
    if not mpath.exists():
        report("Manifeste des assets", False, "art/manifest.json absent")
        return
    data = json.loads(mpath.read_text(encoding="utf-8"))
    assets = data.get("assets", [])
    problems: list[str] = []
    generated = [a for a in assets if a.get("source") == "comfyui"]
    for a in assets:
        f = ROOT / a.get("file", "")
        if not f.exists():
            problems.append(f"manquant {a.get('file')}")
            continue
        if a.get("sha256") and hashlib.sha256(f.read_bytes()).hexdigest() != a["sha256"]:
            problems.append(f"empreinte différente {a.get('file')}")
    for a in generated:
        for key in ("prompt", "seed", "workflow", "model"):
            if key not in a:
                problems.append(f"{a.get('id')} sans {key}")
        wf = ROOT / a.get("workflow", "")
        if not wf.exists():
            problems.append(f"workflow absent {a.get('workflow')}")
    disclosure = ROOT / "docs" / "AI_DISCLOSURE.md"
    dtext = disclosure.read_text(encoding="utf-8") if disclosure.exists() else ""
    undisclosed = [a["file"] for a in generated if a["file"] not in dtext]
    if not dtext:
        problems.append("docs/AI_DISCLOSURE.md absent")
    elif undisclosed:
        problems.append(f"{len(undisclosed)} asset(s) absents de AI_DISCLOSURE.md")
    cats: dict[str, int] = {}
    for a in generated:
        cats[a["category"]] = cats.get(a["category"], 0) + 1
    minimum = {"hull": 8, "engine": 6, "cockpit": 6, "wings": 4, "wear": 4, "portrait": 26, "icon": 60, "background": 6}
    for c, n in minimum.items():
        if cats.get(c, 0) < n:
            problems.append(f"catégorie {c} : {cats.get(c, 0)} < {n}")
    report("Manifeste + divulgation IA", not problems, f"{len(assets)} entrées, {len(generated)} générées "
           f"({', '.join(f'{k} {v}' for k, v in sorted(cats.items()))})" + (f" ; problèmes : {problems[:4]}" if problems else ""))


def check_audio_manifest() -> None:
    """Musiques (ACE-Step 1.5) et bruitages (synthèse) : fichiers présents, empreintes, provenance, divulgation."""
    mpath = ROOT / "art" / "audio_manifest.json"
    if not mpath.exists():
        report("Manifeste audio", False, "art/audio_manifest.json absent")
        return
    items = json.loads(mpath.read_text(encoding="utf-8")).get("assets", [])
    problems: list[str] = []
    for a in items:
        f = ROOT / a.get("path", "")
        if not f.exists():
            problems.append(f"manquant {a.get('path')}")
            continue
        if a.get("sha256") and hashlib.sha256(f.read_bytes()).hexdigest() != a["sha256"]:
            problems.append(f"empreinte différente {a.get('path')}")
        if not a.get("license"):
            problems.append(f"{a.get('id')} sans licence")
        if a.get("type") == "music":
            src = a.get("source", {})
            for key in ("model", "workflow", "seed", "tags"):
                if key not in src:
                    problems.append(f"{a.get('id')} sans {key}")
            if not (ROOT / src.get("workflow", "")).exists():
                problems.append(f"workflow absent {src.get('workflow')}")
    music = [a for a in items if a.get("type") == "music"]
    sfx = [a for a in items if a.get("type") == "sfx"]
    dtext = (ROOT / "docs" / "AI_DISCLOSURE.md").read_text(encoding="utf-8") if (ROOT / "docs" / "AI_DISCLOSURE.md").exists() else ""
    undisclosed = [a["path"] for a in music if a["path"] not in dtext]
    if undisclosed:
        problems.append(f"musiques absentes de AI_DISCLOSURE.md : {undisclosed}")
    if len(music) < 4 or len(sfx) < 20:
        problems.append(f"{len(music)} musiques, {len(sfx)} bruitages")
    report("Manifeste audio + divulgation", not problems, f"{len(music)} musiques ACE-Step 1.5, {len(sfx)} bruitages synthétisés"
           + (f" ; problèmes : {problems[:4]}" if problems else ""))


# --- 8. Workflows et licences -------------------------------------------------------

def check_workflows() -> None:
    snap_path = ROOT / "comfy" / "object_info_snapshot.json"
    problems: list[str] = []
    if not snap_path.exists():
        report("Workflows ComfyUI", False, "instantané /object_info absent")
        return
    snap = json.loads(snap_path.read_text(encoding="utf-8"))
    wfs = sorted((ROOT / "comfy" / "workflows").glob("*.json"))
    nodes = 0
    for wf in wfs:
        graph = json.loads(wf.read_text(encoding="utf-8"))
        for nid, node in graph.items():
            if nid.startswith("_") or not isinstance(node, dict):
                continue
            nodes += 1
            ct = node.get("class_type", "")
            info = snap.get(ct)
            if info is None:
                problems.append(f"{wf.name}:{nid} nœud inconnu {ct}")
                continue
            required = info.get("input", {}).get("required", {})
            for name, spec in required.items():
                if name not in node.get("inputs", {}):
                    problems.append(f"{wf.name}:{nid} entrée manquante {name}")
                    continue
                val = node["inputs"][name]
                choices = spec[0] if isinstance(spec, list) and spec and isinstance(spec[0], list) else None
                if choices is not None and isinstance(val, str) and "{{" not in val and val not in choices:
                    problems.append(f"{wf.name}:{nid} valeur {val!r} absente de /object_info pour {name}")
            for name, val in node.get("inputs", {}).items():
                if isinstance(val, list) and len(val) == 2 and isinstance(val[0], str) and val[0] not in graph:
                    problems.append(f"{wf.name}:{nid} lien vers nœud absent {val[0]}")
    report("Workflows ComfyUI (validation /object_info)", bool(wfs) and not problems,
           f"{len(wfs)} workflows, {nodes} nœuds" + (f" ; problèmes : {problems[:4]}" if problems else ""))
    lic = ROOT / "docs" / "MODEL_LICENSES.md"
    models = json.loads((ROOT / "comfy" / "models.json").read_text(encoding="utf-8")).get("models", [])
    text = lic.read_text(encoding="utf-8") if lic.exists() else ""
    commercial_ok = ("Apache-2.0", "MIT", "OpenRAIL", "OFL", "CreativeML")
    missing = [m["file"] for m in models if m["file"] not in text]
    bad = [m["file"] for m in models if not any(k in m.get("license", "") for k in commercial_ok)]
    report("Licences des modèles", bool(text) and not missing and not bad,
           f"{len(models)} modèles documentés dans docs/MODEL_LICENSES.md" + (f" ; absents : {missing}" if missing else "") + (f" ; licence non commerciale : {bad}" if bad else ""))


# --- 9-10. Documents et captures -------------------------------------------------------

def check_docs() -> None:
    req = ["README.md", "CLAUDE.md", "docs/GDD.md", "docs/PROGRESS.md", "docs/DECISIONS.md", "docs/MODEL_LICENSES.md", "docs/AI_DISCLOSURE.md"]
    missing = [r for r in req if not (ROOT / r).exists() or (ROOT / r).stat().st_size < 200]
    report("Documents", not missing, f"{len(req) - len(missing)}/{len(req)} présents" + (f" ; manquants : {missing}" if missing else ""))


def check_screens() -> None:
    d = ROOT / "docs" / "screens"
    shots = sorted(d.glob("*.png")) if d.exists() else []
    names = " ".join(p.stem for p in shots)
    needed = ["garage", "auctions", "staff", "research", "quests"]
    missing = [n for n in needed if n not in names]
    sizes = {png_size(p) for p in shots}
    small = [p.name for p in shots if png_size(p)[0] < 960]
    ok = len(shots) >= 5 and not missing and not small
    report("Captures d'écran (docs/screens)", ok, f"{len(shots)} captures {sorted(sizes)}" + (f" ; manquantes : {missing}" if missing else "") + (f" ; trop petites : {small}" if small else ""))


# --- 11. Kit Steam (vidéo, captures, capsules, fiche) -------------------------------------

def mp4_info(path: Path) -> dict:
    """Durée (s) et taille de la piste vidéo d'un MP4, lues dans les boîtes moov/mvhd et trak/tkhd."""
    data = path.read_bytes()
    info: dict = {"duration": 0.0, "video": (0, 0), "brand": data[8:12].decode("latin-1") if data[4:8] == b"ftyp" else ""}

    def boxes(start: int, end: int):
        i = start
        while i + 8 <= end:
            size, kind = struct.unpack(">I4s", data[i:i + 8])
            head = 8
            if size == 1:
                size = struct.unpack(">Q", data[i + 8:i + 16])[0]
                head = 16
            elif size == 0:
                size = end - i
            if size < head:
                return
            yield kind.decode("latin-1"), i + head, i + size
            i += size

    for kind, b0, b1 in boxes(0, len(data)):
        if kind != "moov":
            continue
        for k2, c0, c1 in boxes(b0, b1):
            if k2 == "mvhd":
                v = data[c0]
                if v == 1:
                    ts, dur = struct.unpack(">IQ", data[c0 + 20:c0 + 32])
                else:
                    ts, dur = struct.unpack(">II", data[c0 + 12:c0 + 20])
                info["duration"] = dur / ts if ts else 0.0
            elif k2 == "trak":
                for k3, d0, d1 in boxes(c0, c1):
                    if k3 == "tkhd":
                        w, h = struct.unpack(">II", data[d1 - 8:d1])
                        if w and h:
                            info["video"] = (w >> 16, h >> 16)
                    elif k3 == "mdia":
                        for k4, e0, e1 in boxes(d0, d1):
                            if k4 == "hdlr" and data[e0 + 8:e0 + 12] == b"soun":
                                info["audio"] = True
    return info


def check_steam() -> None:
    steam = ROOT / "docs" / "steam"
    problems: list[str] = []
    durations: list[str] = []
    for lang in ("fr", "en"):
        mp4 = steam / f"trailer_{lang}.mp4"
        if not mp4.exists():
            problems.append(f"{mp4.name} absent")
            continue
        info = mp4_info(mp4)
        if info["video"] != (1920, 1080) or not (30.0 <= info["duration"] <= 180.0) or not info.get("audio"):
            problems.append(f"{mp4.name} : {info}")
        durations.append(f"{lang} {info['duration']:.1f} s")
        shots = sorted((steam / "screenshots" / lang).glob("*.png"))
        bad = [x.name for x in shots if png_size(x) != (1920, 1080)]
        if len(shots) < 5 or bad:
            problems.append(f"captures {lang} : {len(shots)} ({bad})")
    caps = {"header_capsule_920x430": (920, 430), "small_capsule_462x174": (462, 174), "main_capsule_1232x706": (1232, 706),
            "vertical_capsule_748x896": (748, 896), "library_capsule_600x900": (600, 900), "library_header_920x430": (920, 430),
            "library_hero_3840x1240": (3840, 1240), "community_icon_184x184": (184, 184)}
    for name, size in caps.items():
        f = steam / "capsules" / f"{name}.png"
        if not f.exists() or png_size(f) != size:
            problems.append(f"capsule {name}")
    md = ROOT / "docs" / "STEAM_STORE.md"
    text = md.read_text(encoding="utf-8") if md.exists() else ""
    for needed in ("Configuration requise", "Langues", "Description courte", "Divulgation de l'IA", "Tags"):
        if needed not in text:
            problems.append(f"STEAM_STORE.md sans « {needed} »")
    report("Kit Steam (vidéos, captures, capsules, fiche)", not problems,
           f"vidéos 1920×1080 avec son ({', '.join(durations)}), captures FR/EN 1920×1080, {len(caps)} capsules, docs/STEAM_STORE.md"
           + (f" ; problèmes : {problems}" if problems else ""))


def main() -> int:
    t0 = time.time()
    print("Clunker Cosmos — vérification complète", flush=True)
    print(f"Godot : {godot.find_godot()}", flush=True)
    if "--skip-import" not in sys.argv:
        check_import()
    check_unit()
    check_sim()
    check_story()
    check_ui_smoke()
    check_assets_godot()
    check_manifest()
    check_audio_manifest()
    check_workflows()
    check_docs()
    check_screens()
    check_steam()
    failed = [n for n, ok, _ in RESULTS if not ok]
    print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} contrôles réussis en {time.time() - t0:.0f} s", flush=True)
    if failed:
        print("CHECKS FAILED : " + ", ".join(failed), flush=True)
        return 1
    print("ALL CHECKS PASSED", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
