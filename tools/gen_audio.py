"""Audio de Clunker Cosmos : musiques (ACE-Step 1.5 via ComfyUI local) + effets sonores (synthèse procédurale).

Étapes :
  music      génère les candidats manquants de chaque morceau (une par graine de TRACKS) via l'API HTTP de ComfyUI
             → build/audio_raw/<id>_s<graine>.flac (ignoré par git). --chosen : seulement la graine retenue au manifeste.
  pick       mesure chaque candidat, garde le meilleur score, le normalise (-16 LUFS intégrés, limiteur ≤ -1,5 dBFS,
             crête vraie ≤ -1 dBTP après encodage, fondus) et l'encode en OGG Vorbis q5 48 kHz stéréo
             → assets/audio/music/<id>.ogg
  sfx        synthétise les effets (tools/sfx_synth.py) → assets/audio/sfx/<id>.wav (mono 44,1 kHz 16 bits)
  manifest   recalcule durées et empreintes des fichiers présents dans art/audio_manifest.json
  validate   vérifie le workflow rempli pour chaque morceau contre /object_info (live, sinon l'instantané)
  all        music + pick + sfx

Usage : .venv/Scripts/python.exe tools/gen_audio.py all | music [--only title,garage_a] [--chosen] | pick | sfx | manifest | validate

Choix de la graine (on ne peut pas écouter) : le « contenu » va de la première à la dernière trame de 50 ms au-dessus
de -60 dBFS (le silence final d'un morceau qui se termine avant la durée demandée est coupé au mastering). Rejet si le
contenu est trop court (< demande - 12 s ; jingle < 60 %), si la musique démarre après 1 s, si un silence interne
dépasse 1,5 s ou si l'écrêtage dur dépasse 50 ppm ; sinon score = 100 - pénalités : instabilité du niveau court terme
K-pondéré (fenêtres de 3 s, hors intro et 9 dernières secondes) au-delà de 2 dB, sauts entre fenêtres au-delà de 4 dB,
trous internes, plage de loudness hors 3-9 LU, facteur de crête hors 9-18 dB, variation de timbre (écart-type moyen de
l'énergie relative par tiers d'octave) au-delà de 3 dB, part d'aigus > 8 kHz au-delà de 8 %, dépassements de 0 dBFS
dans la sortie du modèle, stéréo anticorrélée. Jingle : fenêtres d'1 s, stabilité mesurée sans l'accord final, pas de
pénalité de timbre, mais il doit retomber à la fin (≥ 6 dB sur la dernière seconde). Toutes les mesures sont tracées.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import comfy_client as cc  # noqa: E402
import sfx_synth  # noqa: E402
from sfx_synth import k_gain  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "build" / "audio_raw"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MANIFEST = ROOT / "art" / "audio_manifest.json"
WORKFLOW = "ace_step15_music"
SR_MUSIC = 48000
TARGET_LUFS = -16.0
LIMIT_DBFS = -1.5
MAX_TRUE_PEAK = -1.0
LICENSE_MUSIC = ("MIT (ACE-Step 1.5, Copyright (c) 2026 ACEStep) ; poids reconditionnés par Comfy-Org (Apache-2.0) ; "
                 "morceau généré localement pour le projet, utilisation commerciale autorisée")
LICENSE_SFX = "œuvre originale du projet (synthèse procédurale, aucune ressource tierce)"

INSTRUMENTAL = "[Instrumental]"
TRACKS: dict[str, dict[str, Any]] = {
    "title": {
        "role": "menu titre",
        "duration": 84, "bpm": 112, "keyscale": "D major", "timesignature": "4", "seeds": [1101, 1102, 1103],
        "tags": ("Instrumental retro space funk with a light synthwave shine. Joyful, adventurous and upbeat main menu "
                 "theme. Bright analog synth lead melody, funky slap bass, crisp drum machine groove, clean rhythm "
                 "electric guitar, shimmering arpeggiated synths and warm pads. Playful, optimistic, catchy, cosmic "
                 "road trip mood. No vocals."),
    },
    "garage_a": {
        "role": "jeu (atelier, détendu)",
        "duration": 144, "bpm": 92, "keyscale": "F major", "timesignature": "4", "seeds": [1201, 1202, 1203],
        "tags": ("Instrumental lo-fi space funk for a relaxed workshop. Laid-back groovy bassline, mellow electric "
                 "piano chords, soft drum machine with a light swing, warm analog synth pads, a gentle synth lead "
                 "playing a simple melody now and then. Cozy, easygoing, steady and unobtrusive background music "
                 "for long play sessions. No vocals."),
    },
    "garage_b": {
        "role": "jeu (atelier, ensoleillé)",
        "duration": 136, "bpm": 104, "keyscale": "Bb major", "timesignature": "4", "seeds": [1301, 1302, 1303],
        "tags": ("Instrumental retro synth funk, sunny and easygoing. Bouncy synth bass, muted funk guitar, soft "
                 "analog brass stabs, clavinet style keys, tight drum machine with handclaps and light percussion. "
                 "Cheerful, groovy, mid-tempo, warm and polished background music for a busy but friendly "
                 "spaceship garage. No vocals."),
    },
    "garage_c": {
        "role": "jeu (orbite de nuit, rêveur)",
        "duration": 128, "bpm": 84, "keyscale": "E minor", "timesignature": "4", "seeds": [1401, 1402, 1403],
        "tags": ("Instrumental dreamy space lounge, downtempo lo-fi synthwave. Warm electric piano chords, deep round "
                 "bass, brushed drum machine, twinkling arpeggios, soft analog pads and gentle tape warmth. Calm, "
                 "cozy, spacious and slightly nostalgic late night orbit atmosphere, unobtrusive background music. "
                 "No vocals."),
    },
    "jingle_win": {
        "role": "jingle de victoire (fin de chapitre)",
        "duration": 10, "bpm": 120, "keyscale": "C major", "timesignature": "4", "seeds": [1504, 1505, 1506],
        "short": True, "fade_in": 0.02, "fade_out": 1.2,
        "lyrics": "[Intro - drum fill]\n\n[Fanfare - synth brass melody]\n\n[Flourish - bright arpeggio]\n\n[Outro - sustained final chord]",
        "tags": ("Short instrumental victory fanfare jingle. Triumphant retro synth brass, bright arpeggio flourish, "
                 "punchy drum fill and a final sustained major chord. Joyful, celebratory, mission accomplished. "
                 "No vocals."),
    },
}


# --- ffmpeg / décodage / mesures -------------------------------------------------------------------------------

def ffmpeg_exe() -> str:
    try:
        import imageio_ffmpeg  # type: ignore
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        found = shutil.which("ffmpeg")
        if found:
            return found
        raise SystemExit("ffmpeg introuvable : .venv/Scripts/python.exe -m pip install imageio-ffmpeg")


def decode(path: Path, sr: int = SR_MUSIC, channels: int = 2) -> np.ndarray:
    raw = subprocess.run([ffmpeg_exe(), "-v", "error", "-i", str(path), "-f", "f32le", "-acodec", "pcm_f32le",
                          "-ac", str(channels), "-ar", str(sr), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels).astype(np.float64)


def ebur128(x: np.ndarray, sr: int = SR_MUSIC) -> dict[str, float]:
    """Loudness EBU R128 (ffmpeg) d'un signal float : intégrée (LUFS), plage (LU), crête vraie (dBTP)."""
    ch = x.shape[1]
    p = subprocess.run([ffmpeg_exe(), "-hide_banner", "-nostats", "-f", "f32le", "-ar", str(sr), "-ac", str(ch), "-i", "-",
                        "-af", "ebur128=peak=true", "-f", "null", "-"],
                       input=np.ascontiguousarray(x, dtype=np.float32).tobytes(), capture_output=True)
    return parse_ebur128(p.stderr.decode("utf-8", "replace"))


def ebur128_file(path: Path) -> dict[str, float]:
    p = subprocess.run([ffmpeg_exe(), "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True)
    return parse_ebur128(p.stderr.decode("utf-8", "replace"))


def parse_ebur128(text: str) -> dict[str, float]:
    summary = text[text.rfind("Summary:"):] if "Summary:" in text else text

    def grab(pattern: str) -> float:
        m = re.search(pattern, summary)
        if not m:
            return float("nan")
        return float("-inf") if m.group(1) == "-inf" else float(m.group(1))

    return {"I": grab(r"I:\s+(-?[\d.]+|-inf) LUFS"), "LRA": grab(r"LRA:\s+(-?[\d.]+) LU"),
            "TP": grab(r"Peak:\s+(-?[\d.]+|-inf) dBFS")}


def k_weight(x: np.ndarray, sr: int) -> np.ndarray:
    """Pondération K (UIT-R BS.1770) appliquée en amplitude dans le domaine fréquentiel."""
    spec = np.fft.rfft(x, axis=0) * k_gain(np.fft.rfftfreq(x.shape[0], 1.0 / sr))[:, None]
    return np.fft.irfft(spec, n=x.shape[0], axis=0)


def windows_loudness(x: np.ndarray, sr: int, win_s: float) -> np.ndarray:
    y = k_weight(x, sr)
    w = int(win_s * sr)
    m = y.shape[0] // w
    if m == 0:
        return np.array([])
    ms = (y[: m * w].reshape(m, w, y.shape[1]) ** 2).mean(axis=1).sum(axis=1)
    return -0.691 + 10 * np.log10(ms + 1e-20)


def band_profile(seg: np.ndarray, sr: int) -> np.ndarray:
    """Énergie relative (dB) par bande d'un tiers d'octave environ, de 40 Hz à 16 kHz (empreinte de timbre)."""
    pw = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2
    f = np.fft.rfftfreq(len(seg), 1.0 / sr)
    edges = np.geomspace(40.0, 16000.0, 27)
    e = np.array([pw[(f >= lo) & (f < hi)].sum() for lo, hi in zip(edges[:-1], edges[1:])]) + 1e-20
    return 10 * np.log10(e / e.sum())


def analyze(path: Path, spec: dict[str, Any]) -> dict[str, Any]:
    """Mesures objectives d'un candidat. Le « contenu » va de la première à la dernière trame de 50 ms au-dessus de
    -60 dBFS : le silence final (morceau terminé avant la durée demandée) est retiré au mastering, il n'est pas un
    défaut ; seuls les silences internes comptent."""
    x = decode(path)
    sr = SR_MUSIC
    n = x.shape[0]
    short = bool(spec.get("short"))
    a = np.abs(x)
    mono = x.mean(axis=1)
    hop = int(0.05 * sr)
    frames = n // hop
    fr_db = 20 * np.log10(np.sqrt((mono[: frames * hop].reshape(frames, hop) ** 2).mean(axis=1)) + 1e-12)
    sounding = np.flatnonzero(fr_db >= -60.0)
    first, last = (int(sounding[0]), int(sounding[-1])) if sounding.size else (0, frames - 1)
    inner = fr_db[first: last + 1] < -60.0
    edges = np.diff(np.r_[0, inner.astype(np.int8), 0])
    runs = (np.flatnonzero(edges == -1) - np.flatnonzero(edges == 1)) * 0.05
    xc = x[first * hop: (last + 1) * hop]
    win = 1.0 if short else 3.0
    st = windows_loudness(xc, sr, win)
    if short:
        body = st[:-2] if st.size > 3 else st  # jingle : sans l'accord final qui retombe
    else:
        body = st[1:-3] if st.size >= 6 else st  # sans la première fenêtre (intro) ni les 9 dernières secondes
    w = int(win * sr)
    idx = range(xc.shape[0] // w)
    keep = list(idx) if short or len(idx) < 6 else list(idx)[1:-3]
    monoc = xc.mean(axis=1)
    prof = np.array([band_profile(monoc[i * w:(i + 1) * w], sr) for i in keep]) if keep else np.zeros((1, 26))
    f = np.fft.rfftfreq(w, 1.0 / sr)
    hf = [float((pw[f > 8000].sum()) / (pw.sum() + 1e-20)) for pw in
          (np.abs(np.fft.rfft(monoc[i * w:(i + 1) * w])) ** 2 for i in keep)]
    eb = ebur128(xc, sr)
    rms = float(np.sqrt((xc ** 2).mean()))
    left, right = xc[:, 0], xc[:, 1]
    corr = float(np.corrcoef(left, right)[0, 1]) if left.std() > 0 and right.std() > 0 else 1.0
    m: dict[str, Any] = {
        "duration_s": round(n / sr, 2),
        "content_s": round((last - first + 1) * 0.05, 2),
        "lead_in_s": round(first * 0.05, 2),
        "longest_inner_silence_s": round(float(runs.max()) if runs.size else 0.0, 2),
        "inner_gaps_s": round(float(runs[runs >= 0.3].sum()) if runs.size else 0.0, 2),
        "clip_ppm": round(float((a >= 0.998).sum()) / a.size * 1e6, 1),
        "overs_ppm": round(float((a >= 0.5).sum()) / a.size * 1e6, 1),
        "crest_db": round(20 * np.log10(float(np.abs(xc).max()) / (rms + 1e-12)), 2),
        "lufs": round(eb["I"], 2), "lra": round(eb["LRA"], 2), "true_peak_db": round(eb["TP"], 2),
        "st_std_db": round(float(body.std()), 2),
        "st_jump_db": round(float(np.abs(np.diff(body)).max()) if body.size > 1 else 0.0, 2),
        "timbre_var_db": round(float(prof.std(axis=0).mean()), 2),
        "hf_ratio": round(float(np.mean(hf)), 4) if hf else 0.0,
        "stereo_corr": round(corr, 3),
    }
    if short:
        m["end_drop_db"] = round(float(np.percentile(fr_db[first: last + 1], 90) - fr_db[max(first, last - 19): last + 1].mean()), 2)
    m["rejected"], m["score"] = score(m, float(spec["duration"]), short)
    return m


def score(m: dict[str, Any], requested: float, short: bool) -> tuple[str, float]:
    reasons: list[str] = []
    if m["content_s"] < (requested * 0.6 if short else requested - 12.0):
        reasons.append("trop court")
    if m["lead_in_s"] > 1.0:
        reasons.append("démarrage tardif")
    if m["longest_inner_silence_s"] > 1.5:
        reasons.append("silence interne")
    if m["clip_ppm"] > 50:
        reasons.append("écrêtage")
    pen = 0.0
    pen += 4.0 * max(0.0, m["st_std_db"] - 2.0)
    pen += 2.0 * max(0.0, m["st_jump_db"] - (6.0 if short else 4.0))
    pen += 5.0 * m["inner_gaps_s"]
    if not short:
        pen += 2.0 * (max(0.0, 3.0 - m["lra"]) + max(0.0, m["lra"] - 9.0))
    pen += 1.5 * (max(0.0, 9.0 - m["crest_db"]) + max(0.0, m["crest_db"] - 18.0))
    if not short:  # un jingle enchaîne volontairement roulement, cuivres, arpège et accord
        pen += 4.0 * max(0.0, m["timbre_var_db"] - 3.0)
    pen += 100.0 * max(0.0, m["hf_ratio"] - 0.08)
    pen += min(3.0, 0.01 * m["overs_ppm"])
    pen += 10.0 * max(0.0, 0.2 - m["stereo_corr"])
    if short:
        pen += 1.0 * max(0.0, 6.0 - m.get("end_drop_db", 0.0))  # un jingle doit se terminer (accord final qui retombe)
    return ", ".join(reasons), round(100.0 - pen, 2)


# --- ComfyUI ----------------------------------------------------------------------------------------------------

def raw_path(track: str, seed: int) -> Path:
    return RAW / f"{track}_s{seed}.flac"


def filled_workflow(track: str, spec: dict[str, Any], seed: int) -> dict[str, Any]:
    wf = cc.load_workflow(WORKFLOW)
    overrides = wf.get("_meta_workflow", {}).get("overrides", {})
    out = cc.fill(wf, {"TAGS": spec["tags"], "LYRICS": spec.get("lyrics", INSTRUMENTAL), "SEED": int(seed),
                       "PREFIX": f"clunker_cosmos/music/{track}_s{seed}"})
    values = {"bpm": int(spec["bpm"]), "duration": float(spec["duration"]), "seconds": float(spec["duration"]),
              "timesignature": str(spec.get("timesignature", "4")), "keyscale": str(spec["keyscale"])}
    for nid, names in overrides.items():
        for name in names:
            out[nid]["inputs"][name] = values[name]
    return out


def fetch_audio(client: cc.ComfyClient, entry: dict[str, Any]) -> bytes:
    for data in entry.get("outputs", {}).values():
        for item in data.get("audio", []):
            q = urllib.parse.urlencode({"filename": item["filename"], "subfolder": item.get("subfolder", ""),
                                        "type": item.get("type", "output")})
            with urllib.request.urlopen(f"{client.base}/view?{q}", timeout=300) as r:
                return r.read()
    raise RuntimeError("aucune sortie audio dans l'historique ComfyUI")


def manifest_data() -> dict[str, Any]:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {"_comment": "", "assets": []}


def chosen_seeds() -> dict[str, int]:
    out: dict[str, int] = {}
    for a in manifest_data().get("assets", []):
        if a.get("type") == "music" and "seed" in a.get("source", {}):
            out[a["id"]] = int(a["source"]["seed"])
    return out


def music(only: set[str] | None, chosen_only: bool, force: bool) -> None:
    client = cc.ComfyClient()
    if not client.alive():
        raise SystemExit("ComfyUI injoignable : " + client.base)
    RAW.mkdir(parents=True, exist_ok=True)
    chosen = chosen_seeds()
    todo: list[tuple[str, int]] = []
    for track, spec in TRACKS.items():
        if only and track not in only:
            continue
        seeds = [chosen[track]] if chosen_only and track in chosen else spec["seeds"]
        todo += [(track, s) for s in seeds if force or not raw_path(track, s).exists()]
    print(f"{len(todo)} morceau(x) à générer")
    for i, (track, seed) in enumerate(todo, 1):
        spec = TRACKS[track]
        wf = filled_workflow(track, spec, seed)
        errs = cc.validate(wf, client.object_info())
        if errs:
            raise SystemExit("workflow invalide :\n  " + "\n  ".join(errs))
        t0 = time.time()
        entry = client.wait(client.queue(wf), timeout=3600)
        raw_path(track, seed).write_bytes(fetch_audio(client, entry))
        print(f"[{i}/{len(todo)}] {track} graine {seed} : {time.time() - t0:.0f} s", flush=True)


# --- Post-traitement ----------------------------------------------------------------------------------------------

def limiter(x: np.ndarray, limit: float, sr: int, look_s: float = 0.003) -> np.ndarray:
    """Limiteur à anticipation : minimum glissant (avant) du gain requis puis moyenne glissante (arrière) de même
    longueur ; le gain final ne dépasse jamais le gain requis, sans discontinuité."""
    need = np.minimum(1.0, limit / np.maximum(np.abs(x).max(axis=1), 1e-12))
    if need.min() >= 1.0:
        return x
    w = max(1, int(look_s * sr))
    pad = np.r_[need, np.ones(w - 1)]
    view = np.lib.stride_tricks.sliding_window_view(pad, w)
    g_min = view.min(axis=1)
    c = np.cumsum(np.r_[np.ones(w - 1), g_min])
    g = (c[w - 1:] - np.r_[0.0, c[:-w]]) / w
    return x * np.minimum(g, need)[:, None]


def fade(n: int, sr: int, fade_in: float, fade_out: float) -> np.ndarray:
    env = np.ones(n)
    i = min(n, int(fade_in * sr))
    o = min(n, int(fade_out * sr))
    if i > 0:
        env[:i] = np.sin(0.5 * np.pi * np.linspace(0.0, 1.0, i)) ** 2
    if o > 0:
        env[n - o:] *= np.cos(0.5 * np.pi * np.linspace(0.0, 1.0, o)) ** 2
    return env


def master(src: Path, dst: Path, spec: dict[str, Any]) -> dict[str, Any]:
    """Coupe les silences de bord, normalise à TARGET_LUFS, limite les crêtes, applique les fondus et encode en OGG.
    Si la crête vraie du fichier encodé dépasse MAX_TRUE_PEAK (dépassements dus au codec), le plafond du limiteur
    est abaissé d'autant et l'encodage refait."""
    sr = SR_MUSIC
    x = decode(src)
    thr = np.abs(x).max() * 10 ** (-50 / 20)
    loud = np.flatnonzero(np.abs(x).max(axis=1) > thr)
    start = max(0, int(loud[0]) - int(0.01 * sr))
    end = min(x.shape[0], int(loud[-1]) + int(0.3 * sr))
    x = x[start:end]
    env = fade(x.shape[0], sr, float(spec.get("fade_in", 0.3)), float(spec.get("fade_out", 2.0)))
    limit_db = LIMIT_DBFS
    gain_db = TARGET_LUFS - ebur128(x, sr)["I"]
    dst.parent.mkdir(parents=True, exist_ok=True)
    final: dict[str, float] = {}
    for _ in range(4):
        for _ in range(4):
            y = limiter(x * 10 ** (gain_db / 20), 10 ** (limit_db / 20), sr) * env[:, None]
            err = TARGET_LUFS - ebur128(y, sr)["I"]
            if abs(err) < 0.1:
                break
            gain_db += err
        cmd = [ffmpeg_exe(), "-y", "-hide_banner", "-loglevel", "error", "-f", "f32le", "-ar", str(sr), "-ac", "2", "-i", "-",
               "-c:a", "libvorbis", "-q:a", "5", "-ar", str(sr), "-ac", "2", "-map_metadata", "-1",
               "-fflags", "+bitexact", "-flags:a", "+bitexact", dst.as_posix()]
        subprocess.run(cmd, input=np.ascontiguousarray(y, dtype=np.float32).tobytes(), check=True)
        final = ebur128_file(dst)
        if final["TP"] <= MAX_TRUE_PEAK:
            break
        limit_db -= final["TP"] - MAX_TRUE_PEAK + 0.2
    return {"trim_start_s": round(start / sr, 3), "trim_end_s": round(end / sr, 3), "gain_db": round(gain_db, 2),
            "limit_dbfs": round(limit_db, 2), "lufs": round(final["I"], 2), "true_peak_db": round(final["TP"], 2),
            "lra": round(final["LRA"], 2)}


def pick(only: set[str] | None) -> None:
    wf_nodes = cc.load_workflow(WORKFLOW)
    wf_meta = wf_nodes.get("_meta_workflow", {})
    entries: list[dict[str, Any]] = []
    for track, spec in TRACKS.items():
        if only and track not in only:
            continue
        cands = [s for s in spec["seeds"] if raw_path(track, s).exists()]
        if not cands:
            print(f"{track} : aucun candidat (lancer d'abord « music »)")
            continue
        results: list[dict[str, Any]] = []
        for seed in cands:
            m = analyze(raw_path(track, seed), spec)
            results.append({"seed": seed, **m})
            print(f"{track} s{seed} : score {m['score']:6.2f} {('REJET ' + m['rejected']) if m['rejected'] else ''} "
                  f"contenu {m['content_s']} s, silence interne max {m['longest_inner_silence_s']} s, {m['lufs']} LUFS, "
                  f"LRA {m['lra']}, σ court terme {m['st_std_db']} dB, saut {m['st_jump_db']} dB, crête/RMS {m['crest_db']} dB, "
                  f"timbre {m['timbre_var_db']} dB, aigus {m['hf_ratio']}, dépassements {m['overs_ppm']} ppm", flush=True)
        ok = [r for r in results if not r["rejected"]] or results
        best = max(ok, key=lambda r: r["score"])
        dst = MUSIC_DIR / f"{track}.ogg"
        post = master(raw_path(track, best["seed"]), dst, spec)
        dur = float(len(decode(dst)) / SR_MUSIC)
        print(f"  → {dst.relative_to(ROOT)} (graine {best['seed']}, {dur:.1f} s, {post['lufs']} LUFS, crête vraie "
              f"{post['true_peak_db']} dBTP)", flush=True)
        enc = wf_nodes["3"]["inputs"]
        ks = wf_nodes["6"]["inputs"]
        entries.append({
            "id": track, "path": dst.relative_to(ROOT).as_posix(), "type": "music", "role": spec["role"],
            "source": {
                "tool": "ComfyUI (local) + ACE-Step 1.5 turbo", "model": wf_meta.get("models", [""])[0],
                "workflow": f"comfy/workflows/{WORKFLOW}.json", "tags": spec["tags"],
                "lyrics": spec.get("lyrics", INSTRUMENTAL), "language": enc["language"], "seed": best["seed"],
                "bpm": spec["bpm"], "keyscale": spec["keyscale"], "timesignature": spec.get("timesignature", "4"),
                "duration_requested_s": spec["duration"],
                "sampler": {"steps": ks["steps"], "cfg": ks["cfg"], "sampler": ks["sampler_name"],
                            "scheduler": ks["scheduler"], "shift": wf_nodes["2"]["inputs"]["shift"]},
                "lm": {"generate_audio_codes": enc["generate_audio_codes"], "cfg_scale": enc["cfg_scale"],
                       "temperature": enc["temperature"], "top_p": enc["top_p"], "top_k": enc["top_k"],
                       "min_p": enc["min_p"]},
                "selection": {"criterion": "score = 100 - pénalités (voir docstring de tools/gen_audio.py)",
                              "candidates": results},
                "postprocess": {"target_lufs": TARGET_LUFS, "max_true_peak_dbtp": MAX_TRUE_PEAK,
                                "fade_in_s": float(spec.get("fade_in", 0.3)), "fade_out_s": float(spec.get("fade_out", 2.0)),
                                "codec": "OGG Vorbis q5, 48 kHz stéréo", **post},
            },
            "duration_s": round(dur, 2), "sha256": sha256(dst), "license": LICENSE_MUSIC,
        })
    merge_manifest(entries)


def sfx() -> None:
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, Any]] = []
    for info in sfx_synth.render_all(SFX_DIR):
        p = Path(info["path"])
        entries.append({
            "id": info["id"], "path": p.relative_to(ROOT).as_posix(), "type": "sfx", "role": info["desc"],
            "source": {"tool": "synthèse procédurale tools/sfx_synth.py (numpy)", "recipe": info["recipe"],
                       "params": info["params"], "level": info["level"]},
            "duration_s": info["duration_s"], "peak_dbfs": info["peak_dbfs"], "sha256": sha256(p), "license": LICENSE_SFX,
        })
        print(f"{p.relative_to(ROOT)} : {info['duration_s']:.3f} s, crête {info['peak_dbfs']} dBFS, "
              f"niveau {info['level']['measured']} dB (cible {info['level']['target']})")
    merge_manifest(entries)


# --- Manifeste ------------------------------------------------------------------------------------------------------

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def merge_manifest(entries: list[dict[str, Any]]) -> None:
    data = manifest_data()
    by_id = {a["id"]: a for a in data.get("assets", [])}
    for e in entries:
        by_id[e["id"]] = e
    order = list(TRACKS.keys()) + [s["id"] for s in sfx_synth.SOUNDS]
    assets = sorted(by_id.values(), key=lambda a: (order.index(a["id"]) if a["id"] in order else len(order), a["id"]))
    out = {
        "_comment": ("Audio de Clunker Cosmos, généré par tools/gen_audio.py. Musiques : ACE-Step 1.5 turbo dans ComfyUI "
                     "local (licence MIT), instrumentales, invites de style génériques (aucun artiste ni œuvre cités). "
                     "Effets : synthèse procédurale numpy (tools/sfx_synth.py), sans IA ni échantillon tiers."),
        "generator": "tools/gen_audio.py",
        "assets": assets,
    }
    MANIFEST.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"manifeste : {MANIFEST.relative_to(ROOT)} ({len(assets)} entrées)")


def refresh_manifest() -> None:
    data = manifest_data()
    for a in data.get("assets", []):
        p = ROOT / a["path"]
        if not p.exists():
            print("absent :", a["path"])
            continue
        a["sha256"] = sha256(p)
        sr, ch = (SR_MUSIC, 2) if a["type"] == "music" else (44100, 1)
        a["duration_s"] = round(len(decode(p, sr, ch)) / sr, 3 if a["type"] == "sfx" else 2)
    merge_manifest(data.get("assets", []))


def validate() -> int:
    client = cc.ComfyClient()
    if client.alive():
        oi, source = client.object_info(), "/object_info (live)"
    else:
        oi, source = json.loads(cc.SNAPSHOT.read_text(encoding="utf-8")), "instantané hors ligne"
    errors = 0
    for track, spec in TRACKS.items():
        errs = cc.validate(filled_workflow(track, spec, spec["seeds"][0]), oi)
        errors += len(errs)
        print(f"{WORKFLOW} [{track}] : {'OK' if not errs else str(len(errs)) + ' erreur(s)'} ({source})")
        for e in errs:
            print("  ", e)
    return 1 if errors else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("step", choices=["all", "music", "pick", "sfx", "manifest", "validate"])
    ap.add_argument("--only", default="")
    ap.add_argument("--chosen", action="store_true", help="music : seulement la graine retenue dans le manifeste")
    ap.add_argument("--force", action="store_true", help="music : régénère même si le fichier brut existe")
    args = ap.parse_args()
    only = {x.strip() for x in args.only.split(",") if x.strip()} or None
    if args.step in ("music", "all"):
        music(only, args.chosen, args.force)
    if args.step in ("pick", "all"):
        pick(only)
    if args.step in ("sfx", "all"):
        sfx()
    if args.step == "manifest":
        refresh_manifest()
    if args.step == "validate":
        return validate()
    return 0


if __name__ == "__main__":
    sys.exit(main())
