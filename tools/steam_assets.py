"""Visuels de la page Steam rendus par le jeu (capsules, fond, logo, icônes) + icône du jeu.

Usage :
  .venv/Scripts/python.exe tools/steam_assets.py

1. Godot (fenêtré) lance `--tour=capsules` (scripts/ui/capsules.gd) : chaque visuel est composé avec les vrais
   assets (décors, vaisseaux peints par le shader du jeu, logo en Lilita One) directement à la taille finale
   → docs/steam/capsules/<nom>_<largeur>x<hauteur>.png aux tailles demandées par Steam.
2. Copie de l'en-tête pour la bibliothèque (même taille), icône Windows multi-tailles `icon.ico` (copiée à la
   racine du projet : icône de l'exécutable exporté et de la barre des tâches) et `icon.svg` du projet (icône de
   fenêtre des autres systèmes) redessinée en pixels à partir de l'icône 64×64.
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import godot  # noqa: E402

OUT = ROOT / "docs" / "steam" / "capsules"


def render() -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    p = godot.run(["res://scenes/main.tscn", "--", "--tour=capsules", f"--out={OUT.as_posix()}"], timeout=600, headless=False)
    text = (p.stdout or "") + (p.stderr or "")
    made = [Path(ln.split(":", 1)[1].strip().split(" ")[0]) for ln in text.splitlines() if ln.startswith("capsule :")]
    errors = [ln for ln in text.splitlines() if "SCRIPT ERROR" in ln or "ERROR:" in ln]
    if p.returncode != 0 or errors or not made:
        raise SystemExit(f"échec du rendu des capsules ({p.returncode}) : {errors[:5]}")
    return made


def svg_from_pixels(img: Image.Image, size: int = 128) -> str:
    """SVG « pixel » : un rectangle par suite horizontale de pixels de même couleur (rendu net à toute taille)."""
    w, h = img.size
    px = img.load()
    rects: list[str] = []
    for y in range(h):
        x = 0
        while x < w:
            r, g, b, a = px[x, y]
            if a < 128:
                x += 1
                continue
            x0 = x
            while x < w and px[x, y] == (r, g, b, a):
                x += 1
            rects.append(f'<rect x="{x0}" y="{y}" width="{x - x0}" height="1" fill="#{r:02x}{g:02x}{b:02x}"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {w} {h}" '
            f'shape-rendering="crispEdges">' + "".join(rects) + "</svg>\n")


def icons() -> None:
    big = Image.open(OUT / "icon_256x256.png").convert("RGBA")
    base = big.resize((64, 64), Image.NEAREST)
    sizes = [16, 24, 32, 48, 64, 128, 256]
    frames = [big.resize((s, s), Image.NEAREST) for s in sizes]
    frames[-1].save(OUT / "icon.ico", sizes=[(s, s) for s in sizes], append_images=frames[:-1])
    shutil.copyfile(OUT / "icon.ico", ROOT / "icon.ico")
    (ROOT / "icon.svg").write_text(svg_from_pixels(base), encoding="utf-8", newline="\n")
    print("icône :", (OUT / "icon.ico").relative_to(ROOT), "+ icon.ico et icon.svg du projet")


def main() -> int:
    made = render()
    for m in made:
        print("capsule :", m.relative_to(ROOT) if m.is_absolute() else m)
    shutil.copyfile(OUT / "header_capsule_920x430.png", OUT / "library_header_920x430.png")
    print("capsule :", (OUT / "library_header_920x430.png").relative_to(ROOT), "(copie de l'en-tête)")
    icons()
    return 0


if __name__ == "__main__":
    sys.exit(main())
