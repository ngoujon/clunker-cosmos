"""Captures d'écran du vrai jeu (fenêtré, rendu GPU) via la visite automatique intégrée.

Usage :
  python tools/screenshots.py                 # docs/screens/*.png en 1440×810 (×3, nearest), `--tour=screens`
  python tools/screenshots.py --steam         # docs/steam/screenshots/{fr,en}/*.png en 1920×1080 (×4), `--tour=steam`
  python tools/screenshots.py --steam --lang=en
  python tools/screenshots.py --only=garage,research

Les parties montrées sont des parties de démonstration (mode Histoire) jouées par l'autopilote ; la série
Steam est mise en scène (garage agrandi et plein, tous les lieux, quelques technologies). Rien n'est retouché :
ce sont les écrans du jeu tels que rendus par Godot, agrandis au plus proche voisin.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import godot  # noqa: E402


def capture(tour: str, out: Path, scale: int, extra: list[str]) -> int:
    out.mkdir(parents=True, exist_ok=True)
    args = ["res://scenes/main.tscn", "--", f"--tour={tour}", f"--out={out.as_posix()}", f"--scale={scale}"] + extra
    p = godot.run(args, timeout=600, headless=False)
    text = (p.stdout or "") + (p.stderr or "")
    shots = [ln.split(":", 1)[1].strip() for ln in text.splitlines() if ln.startswith("capture :")]
    for s in shots:
        print("capture :", s)
    errors = [ln for ln in text.splitlines() if "SCRIPT ERROR" in ln or "ERROR:" in ln]
    if p.returncode != 0 or errors or not shots:
        print("échec des captures", p.returncode, errors[:5])
        return 1
    print(f"{len(shots)} captures dans {out}")
    return 0


def main() -> int:
    extra = [a for a in sys.argv[1:] if a.startswith("--only=")]
    if "--steam" not in sys.argv:
        return capture("screens", ROOT / "docs" / "screens", 3, extra)
    langs = ["fr", "en"]
    for a in sys.argv[1:]:
        if a.startswith("--lang="):
            langs = [x for x in a.split("=", 1)[1].split(",") if x]
    rc = 0
    for lang in langs:
        rc |= capture("steam", ROOT / "docs" / "steam" / "screenshots" / lang, 4, extra + [f"--lang={lang}"])
    return rc


if __name__ == "__main__":
    sys.exit(main())
