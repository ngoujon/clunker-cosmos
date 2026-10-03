"""Localise (ou télécharge dans tools/godot/) Godot 4 stable et lance des commandes headless.

Ordre de recherche : variable GODOT_BIN, tools/godot/*console*.exe, Téléchargements de l'utilisateur,
PATH. À défaut, télécharge Godot 4.7.1-stable (win64) depuis GitHub dans tools/godot/.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCAL_DIR = ROOT / "tools" / "godot"
VERSION = "4.7.1-stable"
URL = f"https://github.com/godotengine/godot/releases/download/{VERSION}/Godot_v{VERSION}_win64.exe.zip"


def _candidates() -> list[Path]:
    out: list[Path] = []
    env = os.environ.get("GODOT_BIN")
    if env:
        out.append(Path(env))
    out += sorted(LOCAL_DIR.glob("**/*console*.exe"))
    home = Path.home() / "Downloads"
    out += sorted(home.glob("Godot_v4*stable*_win64*/*console*.exe"))
    out += sorted(home.glob("Godot_v4*stable*_win64_console.exe"))
    for name in ("godot4", "godot"):
        w = shutil.which(name)
        if w:
            out.append(Path(w))
    return out


def find_godot(download: bool = True) -> Path:
    for c in _candidates():
        if c.is_file():
            return c
    if not download:
        raise FileNotFoundError("Godot introuvable")
    LOCAL_DIR.mkdir(parents=True, exist_ok=True)
    zpath = LOCAL_DIR / "godot.zip"
    print(f"Téléchargement de Godot {VERSION}…", flush=True)
    urllib.request.urlretrieve(URL, zpath)
    with zipfile.ZipFile(zpath) as z:
        z.extractall(LOCAL_DIR)
    zpath.unlink()
    for c in LOCAL_DIR.glob("**/*console*.exe"):
        return c
    raise FileNotFoundError("archive Godot sans exécutable console")


def ignore_work_dirs() -> None:
    """build/ (images de la bande-annonce, captures temporaires) et exports/ ne sont jamais importés par Godot."""
    for d in ("build", "exports"):
        (ROOT / d).mkdir(exist_ok=True)
        (ROOT / d / ".gdignore").touch()


def run(args: list[str], timeout: float = 600, headless: bool = True) -> subprocess.CompletedProcess[str]:
    ignore_work_dirs()
    exe = find_godot()
    cmd = [str(exe)] + (["--headless"] if headless else []) + ["--path", str(ROOT)] + args
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)


if __name__ == "__main__":
    p = run(sys.argv[1:], headless="--windowed" not in sys.argv)
    sys.stdout.write(p.stdout)
    sys.stderr.write(p.stderr)
    sys.exit(p.returncode)
