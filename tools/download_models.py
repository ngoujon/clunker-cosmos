"""Télécharge les modèles listés dans comfy/models.json vers le dossier de modèles ComfyUI.

Stdlib uniquement. Reprise des téléchargements interrompus (en-tête Range),
vérification de la taille finale. Usage :
    python tools/download_models.py [--track flux_schnell] [--list]
Le dossier cible vient de COMFY_MODELS_DIR, sinon du dossier partagé de Comfy Desktop.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MODELS_DIR = Path(os.environ.get("LOCALAPPDATA", "")) / "Comfy-Desktop" / "ComfyUI-Shared" / "models"
CHUNK = 8 * 1024 * 1024


def models_dir() -> Path:
    env = os.environ.get("COMFY_MODELS_DIR")
    return Path(env) if env else DEFAULT_MODELS_DIR


def download(url: str, dest: Path, size: int) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size == size:
        print(f"[ok] {dest.name} déjà présent ({size} octets)", flush=True)
        return
    part = dest.with_suffix(dest.suffix + ".part")
    for attempt in range(1, 6):
        have = part.stat().st_size if part.exists() else 0
        req = urllib.request.Request(url, headers={"User-Agent": "wreck-resell-tools/1.0"})
        if have:
            req.add_header("Range", f"bytes={have}-")
        try:
            with urllib.request.urlopen(req, timeout=60) as resp, open(part, "ab" if have else "wb") as out:
                if have and resp.status != 206:
                    out.truncate(0)
                    have = 0
                t0 = time.time()
                done = have
                last = t0
                while True:
                    buf = resp.read(CHUNK)
                    if not buf:
                        break
                    out.write(buf)
                    done += len(buf)
                    now = time.time()
                    if now - last > 15:
                        speed = (done - have) / max(now - t0, 1e-6) / 1e6
                        print(f"  {dest.name}: {done / 1e9:.2f}/{size / 1e9:.2f} Go ({speed:.1f} Mo/s)", flush=True)
                        last = now
        except Exception as exc:  # réseau instable : on reprend
            print(f"  tentative {attempt} échouée pour {dest.name}: {exc}", flush=True)
            time.sleep(5)
            continue
        if part.stat().st_size == size:
            part.replace(dest)
            print(f"[ok] {dest.name} téléchargé", flush=True)
            return
        print(f"  taille inattendue pour {dest.name}: {part.stat().st_size} != {size}", flush=True)
    raise SystemExit(f"échec du téléchargement de {url}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--track", action="append", help="ne télécharger que ces pistes")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()
    data = json.loads((ROOT / "comfy" / "models.json").read_text(encoding="utf-8"))
    base = models_dir()
    for m in data["models"]:
        dest = base / m["folder"] / m["file"]
        if args.list:
            state = "présent" if dest.exists() and dest.stat().st_size == m["size"] else "absent"
            print(f"{m['id']:<22} {m['track']:<13} {m['license']:<28} {state}")
            continue
        if args.track and m["track"] not in args.track and m["track"] != "all":
            continue
        download(m["url"], dest, int(m["size"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
