"""Captures d'écran du vrai jeu (fenêtré, rendu GPU) via la visite automatique `--tour=screens`.

Usage :
  python tools/screenshots.py                 # docs/screens/*.png en 1440×810 (×3, nearest)
  python tools/screenshots.py --steam         # docs/steam/screenshots/*.png en 1920×1080 (×4)
  python tools/screenshots.py --only=garage,research

La partie montrée est une partie de démonstration (mode Histoire) jouée par l'autopilote pendant
quelques jours : rien n'est retouché, ce sont les écrans du jeu tels que rendus par Godot.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import godot  # noqa: E402


def main() -> int:
    steam = "--steam" in sys.argv
    out = ROOT / ("docs/steam/screenshots" if steam else "docs/screens")
    out.mkdir(parents=True, exist_ok=True)
    args = ["res://scenes/main.tscn", "--", "--tour=screens", f"--out={out.as_posix()}", f"--scale={4 if steam else 3}"]
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            args.append(a)
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


if __name__ == "__main__":
    sys.exit(main())
