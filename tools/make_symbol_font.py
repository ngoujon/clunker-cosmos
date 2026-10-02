"""Police de repli des symboles : sous-ensemble de Noto Sans Math (OFL) aux métriques de Barlow.

Usage :
  .venv/Scripts/python.exe tools/make_symbol_font.py

Godot calcule la hauteur de ligne d'une police comme le maximum des hauteurs de la police et de ses
replis : Noto Sans Math (ascendante 1,07 em, descendante 0,42 em) agrandissait toutes les lignes du jeu.
On ne garde que les quelques symboles absents de Barlow Semi Condensed et de Lilita One (flèches,
pastilles, formes, étoiles, coche) et on aligne les métriques verticales sur Barlow (1,0 / 0,2 em).
Source : art/fonts_src/NotoSansMath-Regular.ttf (non importée par Godot).
Sortie : assets/fonts/CosmosSymbols.ttf (+ licence OFL d'origine, modification signalée).
Dépendance : fontTools (`.venv/Scripts/python.exe -m pip install fonttools`).
"""
from __future__ import annotations

import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "fonts_src" / "NotoSansMath-Regular.ttf"
OUT = ROOT / "assets" / "fonts" / "CosmosSymbols.ttf"
LICENSE_SRC = ROOT / "art" / "fonts_src" / "OFL-NotoSansMath.txt"
LICENSE_OUT = ROOT / "assets" / "fonts" / "OFL-CosmosSymbols.txt"
CHARS = "→←↑↓●○■□▲▼▶◀★☆✓♥♦◆◇▸▹►"
FAMILY = "Cosmos Symbols"
ASCENT, DESCENT = 1000, 200


def main() -> int:
    font = TTFont(SRC)
    cmap = font.getBestCmap()
    missing = [c for c in CHARS if ord(c) not in cmap]
    if missing:
        raise SystemExit(f"symboles absents de {SRC.name} : {''.join(missing)}")
    opts = subset.Options()
    opts.layout_features = []
    opts.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
    opts.notdef_outline = True
    opts.drop_tables += ["MATH"]
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[ord(c) for c in CHARS])
    sub.subset(font)
    hhea = font["hhea"]
    hhea.ascent, hhea.descent, hhea.lineGap = ASCENT, -DESCENT, 0
    os2 = font["OS/2"]
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = ASCENT, -DESCENT, 0
    os2.usWinAscent, os2.usWinDescent = ASCENT, DESCENT
    # Version modifiée : nom de famille distinct (OFL), mention de la modification.
    names = font["name"]
    for rec in list(names.names):
        if rec.nameID in (1, 3, 4, 6, 16, 17):
            names.removeNames(nameID=rec.nameID)
    names.setName(FAMILY, 1, 3, 1, 0x409)
    names.setName("Regular", 2, 3, 1, 0x409)
    names.setName(f"{FAMILY} Regular (subset of Noto Sans Math)", 3, 3, 1, 0x409)
    names.setName(FAMILY, 4, 3, 1, 0x409)
    names.setName(FAMILY.replace(" ", ""), 6, 3, 1, 0x409)
    font.save(OUT)
    note = (f"{FAMILY} : version modifiée de Noto Sans Math (sous-ensemble de {len(CHARS)} symboles, métriques\n"
            f"verticales réalignées) produite par tools/make_symbol_font.py pour Clunker Cosmos.\n"
            f"Modified version of Noto Sans Math (glyph subset, adjusted vertical metrics).\n\n")
    LICENSE_OUT.write_text(note + LICENSE_SRC.read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
    print(f"{OUT.relative_to(ROOT)} : {len(CHARS)} symboles, {OUT.stat().st_size} octets")
    return 0


if __name__ == "__main__":
    sys.exit(main())
