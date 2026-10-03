"""Export Windows du jeu : uniquement les fichiers nécessaires pour jouer (exe + pck), dans exports/Clunker Cosmos/.

Usage :
  python tools/export_windows.py                      # → exports/Clunker Cosmos/ (dossier ignoré par git)
  python tools/export_windows.py --out=build/windows  # autre dossier
  python tools/export_windows.py --debug              # modèle debug (messages d'erreur détaillés)

Préréglage « Windows Desktop » (export_presets.cfg) : exécutable 64 bits + « Clunker Cosmos.pck » à côté, icône
`icon.ico` dans l'exe (et dans la barre des tâches via application/config/windows_native_icon), nom et version du
projet dans les propriétés du fichier, données JSON incluses, build/ exclu. Modèles d'export Godot 4.7.1 requis
dans %APPDATA%/Godot/export_templates/4.7.1.stable (éditeur : Éditeur → Gérer les modèles d'export).
Le dossier ne contient rien d'autre (l'icône est intégrée à l'exe ; l'.ico pour Steamworks est dans
docs/steam/capsules/). exports/ reçoit un .gdignore (Godot n'importe pas ce dossier). Vérification : le jeu
exporté joue sa visite de fumée en headless (jamais d'écriture de la sauvegarde ni des réglages du joueur).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import godot  # noqa: E402

NAME = "Clunker Cosmos"
PRESET = "Windows Desktop"
ERROR_PATTERNS = ("SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR: ")


def errors(text: str) -> list[str]:
    return [ln.strip() for ln in text.splitlines() if any(p in ln for p in ERROR_PATTERNS)]


def export(out_dir: Path, debug: bool) -> Path:
    tpl = (Path(os.environ.get("APPDATA", "")) / "Godot" / "export_templates" / godot.VERSION.replace("-", ".")
           / f"windows_{'debug' if debug else 'release'}_x86_64.exe")
    if not tpl.is_file():
        raise SystemExit(f"modèle d'export absent : {tpl}\n"
                         "(éditeur Godot : Éditeur → Gérer les modèles d'export → Télécharger et installer)")
    out_dir.mkdir(parents=True, exist_ok=True)
    if out_dir.parent == ROOT / "exports":
        (out_dir.parent / ".gdignore").touch()
    exe = out_dir / f"{NAME}.exe"
    pck = out_dir / f"{NAME}.pck"
    for old in (exe, pck, out_dir / f"{NAME}.console.exe", out_dir / f"{NAME}.ico"):
        old.unlink(missing_ok=True)
    print(f"export {'debug' if debug else 'release'} -> {exe}", flush=True)
    p = godot.run(["--export-debug" if debug else "--export-release", PRESET, exe.as_posix()], timeout=900)
    text = (p.stdout or "") + (p.stderr or "")
    if p.returncode != 0 or not exe.is_file() or not pck.is_file() or errors(text):
        print(text[-3000:])
        raise SystemExit(f"échec de l'export ({p.returncode}) : {errors(text)[:5]}")
    print(f"    {exe.name} : {exe.stat().st_size / 1e6:.1f} Mo, {pck.name} : {pck.stat().st_size / 1e6:.1f} Mo", flush=True)
    return exe


def smoke(exe: Path) -> None:
    """Le jeu exporté se lance, charge son contenu et construit tous ses écrans (rendu factice, sans fenêtre)."""
    p = subprocess.run([str(exe), "--headless", "--", "--tour=smoke"], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=600)
    text = (p.stdout or "") + (p.stderr or "")
    result: dict = {}
    for ln in text.splitlines():
        if ln.startswith("##RESULT "):
            result = json.loads(ln[len("##RESULT "):])
    if p.returncode != 0 or not result.get("ok") or errors(text):
        print(text[-3000:])
        raise SystemExit(f"le jeu exporté échoue au test de fumée ({p.returncode}) : {errors(text)[:5]}")
    print(f"    jeu exporté : {len(result.get('screens', {}))} écrans construits et manipulés, 0 erreur", flush=True)


def main() -> int:
    out_dir = ROOT / "exports" / NAME
    for a in sys.argv[1:]:
        if a.startswith("--out="):
            out_dir = Path(a.split("=", 1)[1])
            if not out_dir.is_absolute():
                out_dir = ROOT / out_dir
    exe = export(out_dir, "--debug" in sys.argv)
    smoke(exe)
    print(f"export terminé : {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
