"""Vidéo promotionnelle Steam rendue par le vrai jeu, avec sa musique et ses bruitages, encodée en MP4 H.264.

Usage :
  .venv/Scripts/python.exe tools/make_trailer.py              # FR + EN → docs/steam/trailer_fr.mp4, trailer_en.mp4
  .venv/Scripts/python.exe tools/make_trailer.py --lang=fr    # une seule langue
  .venv/Scripts/python.exe tools/make_trailer.py --keep       # garde les images dans build/trailer_<lang>/

1. Godot (fenêtré, 1920×1080) enregistre la séquence scénarisée `--tour=trailer` (scripts/ui/trailer.gd) avec
   son Movie Maker : `--write-movie build/trailer_<lang>/frame.png --fixed-fps 30`. Le temps du jeu avance de
   1/30 s par image, quelle que soit la vitesse de la machine. Le rendu « canvas_items » dessine le pixel art
   à l'échelle ×4 (interface 480×270, pixels nets) et le texte directement en 1080p ; le son du jeu (musique +
   bruitages) est écrit à côté des images dans un fichier WAV. Movie Maker prend la taille de la vidéo dans les
   réglages du projet (taille de fenêtre imposée, 1440×810) et ignore `--resolution` : un `override.cfg`
   temporaire (1920×1080) est posé à la racine du projet le temps de l'enregistrement, puis retiré.
2. ffmpeg (paquet `imageio-ffmpeg` du venv) encode : H.264 High, yuv420p, 30 i/s, BT.709, AAC 192 kb/s.
"""
from __future__ import annotations

import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import godot  # noqa: E402

FPS = 30
SIZE = (1920, 1080)
OUT_DIR = ROOT / "docs" / "steam"


def ffmpeg_exe() -> str:
    try:
        import imageio_ffmpeg  # type: ignore
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        found = shutil.which("ffmpeg")
        if found:
            return found
        raise SystemExit("ffmpeg introuvable : .venv/Scripts/python.exe -m pip install imageio-ffmpeg")


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


def record(lang: str) -> Path:
    frames = ROOT / "build" / f"trailer_{lang}"
    if frames.exists():
        shutil.rmtree(frames)
    frames.mkdir(parents=True)
    args = ["--write-movie", (frames / "frame.png").as_posix(), "--fixed-fps", str(FPS),
            "--resolution", f"{SIZE[0]}x{SIZE[1]}", "res://scenes/main.tscn", "--", "--tour=trailer", f"--lang={lang}"]
    print(f"[{lang}] enregistrement Godot (Movie Maker)…", flush=True)
    override = ROOT / "override.cfg"
    if override.exists():
        raise SystemExit("override.cfg existe déjà à la racine du projet : retirez-le avant l'enregistrement")
    override.write_text("[display]\n\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\n"
                        % SIZE, encoding="utf-8")
    try:
        p = godot.run(args, timeout=5400, headless=False)
    finally:
        override.unlink(missing_ok=True)
    text = (p.stdout or "") + (p.stderr or "")
    for ln in text.splitlines():
        if ln.startswith("TRAILER:"):
            print("   ", ln)
    problems = [ln for ln in text.splitlines() if "SCRIPT ERROR" in ln or "ERROR:" in ln or "introuvable" in ln]
    if p.returncode != 0 or problems or "TRAILER: fin" not in text:
        raise SystemExit(f"échec de l'enregistrement ({p.returncode}) : {problems[:5]}")
    pngs = sorted(frames.glob("frame*.png"))
    if not pngs:
        raise SystemExit("aucune image produite")
    w, h = png_size(pngs[0])
    if (w, h) != SIZE:
        raise SystemExit(f"taille inattendue {w}×{h} (attendu {SIZE[0]}×{SIZE[1]})")
    print(f"    {len(pngs)} images {w}×{h} ({len(pngs) / FPS:.1f} s), son : {', '.join(x.name for x in frames.glob('*.wav')) or 'aucun'}", flush=True)
    return frames


def encode(frames: Path, out: Path) -> None:
    first = sorted(frames.glob("frame*.png"))[0].name
    digits = len(first) - len("frame") - len(".png")
    wavs = sorted(frames.glob("*.wav"))
    audio_in = ["-i", wavs[0].as_posix()] if wavs else ["-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000"]
    cmd = [ffmpeg_exe(), "-y", "-hide_banner", "-loglevel", "error",
           "-framerate", str(FPS), "-i", (frames / f"frame%0{digits}d.png").as_posix(), *audio_in,
           "-map", "0:v", "-map", "1:a", "-shortest",
           "-vf", "scale=out_color_matrix=bt709:out_range=tv,"
                  "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv",
           "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
           "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "14", "-tune", "animation",
           "-pix_fmt", "yuv420p", "-r", str(FPS), "-g", str(FPS * 2),
           "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart", out.as_posix()]
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(cmd, check=True)
    print(f"    -> {out.relative_to(ROOT)} ({out.stat().st_size / 1e6:.1f} Mo)", flush=True)


def main() -> int:
    langs = ["fr", "en"]
    for a in sys.argv[1:]:
        if a.startswith("--lang="):
            langs = [x for x in a.split("=", 1)[1].split(",") if x]
    for lang in langs:
        frames = record(lang)
        encode(frames, OUT_DIR / f"trailer_{lang}.mp4")
        if "--keep" not in sys.argv:
            shutil.rmtree(frames)
    return 0


if __name__ == "__main__":
    sys.exit(main())
