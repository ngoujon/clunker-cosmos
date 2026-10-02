"""Effets sonores de Clunker Cosmos synthétisés par code (numpy) : rétro/chiptune doux, sans IA ni échantillon tiers.

Chaque effet = une recette (fonction) + ses paramètres (SOUNDS). render_all() écrit assets/audio/sfx/<id>.wav en mono
44,1 kHz 16 bits. Niveau : le RMS K-pondéré maximal sur 50 ms est amené à la cible de l'effet (clics et bips discrets,
jingles plus présents), crête plafonnée à -3 dBFS. Le bruit vient d'un générateur à graine fixe (dérivée de
l'identifiant) : la sortie est identique octet pour octet à chaque exécution.

Briques : oscillateurs à bande limitée par synthèse additive (sinus, triangle, dent de scie, carré, impulsion à
rapport cyclique), enveloppes attaque/décroissance exponentielle/relâche, glissés et vibrato, partiels inharmoniques
(cloches, métal, bois), filtre à variables d'état (TPT) à fréquence variable, bruit filtré, petite réverbération
(réponse impulsionnelle synthétique : bruit à décroissance exponentielle).
"""
from __future__ import annotations

import wave
import zlib
from pathlib import Path
from typing import Any, Callable

import numpy as np

SR = 44100
PEAK_MAX_DB = -3.0
_NOTE = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


# --- Briques ------------------------------------------------------------------------------------------------------

def hz(note: str | float) -> float:
    """'A4' → 440 ; accepte dièses/bémols ('F#4', 'Bb3') ou une fréquence."""
    if not isinstance(note, str):
        return float(note)
    name, rest, acc = note[0].upper(), note[1:], 0
    while rest and rest[0] in "#b":
        acc += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 440.0 * 2 ** ((_NOTE[name] + acc + (int(rest) - 4) * 12) / 12)


def ns(dur: float) -> int:
    return max(1, int(round(dur * SR)))


def times(n: int) -> np.ndarray:
    return np.arange(n) / SR


def wave_of(kind: str, freq: np.ndarray, duty: float = 0.5, soft: float = 0.5, cap: float = 8000.0) -> np.ndarray:
    """Forme d'onde à bande limitée (harmoniques ≤ cap Hz, atténuées en plus de k^-soft), crête ≈ 1."""
    ph = 2 * np.pi * (np.cumsum(freq) - freq[0]) / SR
    if kind == "sine":
        return np.sin(ph)
    kmax = max(1, int(cap / float(freq.max())))
    out = np.zeros_like(ph)
    for k in range(1, kmax + 1):
        w = k ** -soft
        if kind == "tri" and k % 2:
            out += w * (-1) ** ((k - 1) // 2) * np.sin(k * ph) / k ** 2
        elif kind == "square" and k % 2:
            out += w * np.sin(k * ph) / k
        elif kind == "saw":
            out += w * (-1) ** (k + 1) * np.sin(k * ph) / k
        elif kind == "pulse":
            out += w * np.sin(k * np.pi * duty) * np.cos(k * (ph - np.pi * duty)) / k
    peak = float(np.abs(out).max())
    return out / peak if peak > 0 else out


def envelope(n: int, attack: float = 0.004, tau: float | None = None, release: float = 0.02) -> np.ndarray:
    """Attaque (sinus²), puis plateau ou décroissance exponentielle de constante tau, relâche (cosinus²) en fin."""
    t = times(n)
    env = np.ones(n)
    a = min(n, ns(attack))
    env[:a] = np.sin(0.5 * np.pi * np.linspace(0.0, 1.0, a)) ** 2
    if tau:
        env[a:] = np.exp(-(t[a:] - t[a - 1]) / tau)
    r = min(n - a, ns(release)) if release > 0 else 0
    if r > 0:
        env[n - r:] *= np.cos(0.5 * np.pi * np.linspace(0.0, 1.0, r)) ** 2
    return env


def freq_curve(n: int, f0: float, glide: tuple[Any, float] | None = None, vibrato: tuple[float, float, float] | None = None,
               bend_end: tuple[float, float] | None = None) -> np.ndarray:
    """Fréquence instantanée : glissé exponentiel (cible, durée), vibrato (Hz, demi-tons, délai), chute finale
    (demi-tons, durée)."""
    t = times(n)
    f = np.full(n, f0)
    if glide:
        f = f0 * (hz(glide[0]) / f0) ** np.clip(t / max(glide[1], 1e-4), 0.0, 1.0)
    if vibrato:
        rate, depth, delay = vibrato
        f = f * 2 ** (depth * np.clip((t - delay) / 0.08, 0.0, 1.0) * np.sin(2 * np.pi * rate * t) / 12)
    if bend_end:
        semis, d = bend_end
        f = f * 2 ** (semis * np.clip((t - (t[-1] - d)) / d, 0.0, 1.0) ** 1.5 / 12)
    return f


def voice(note: str | float, dur: float, kind: str = "tri", duty: float = 0.5, soft: float = 0.5, cap: float = 8000.0,
          attack: float = 0.004, tau: float | None = None, release: float = 0.02, glide: tuple[Any, float] | None = None,
          vibrato: tuple[float, float, float] | None = None, bend_end: tuple[float, float] | None = None) -> np.ndarray:
    n = ns(dur)
    f = freq_curve(n, hz(note), glide, vibrato, bend_end)
    return wave_of(kind, f, duty, soft, cap) * envelope(n, attack, tau, release)


def partials(f0: float, dur: float, ratios: list[float], amps: list[float], taus: list[float],
             attack: float = 0.001) -> np.ndarray:
    """Somme de sinus inharmoniques à décroissances propres (cloche, métal, bois)."""
    n = ns(dur)
    t = times(n)
    out = np.zeros(n)
    for r, a, tau in zip(ratios, amps, taus):
        if f0 * r < SR * 0.45:
            out += a * np.sin(2 * np.pi * f0 * r * t) * np.exp(-t / tau)
    return out * envelope(n, attack, None, 0.004)


def band(x: np.ndarray, lo: float | None = None, hi: float | None = None, order: int = 2) -> np.ndarray:
    """Filtre passe-bande de Butterworth en amplitude, appliqué en fréquence (pour du bruit stationnaire)."""
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    h = np.ones_like(f)
    if lo:
        h /= np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    if hi:
        h /= np.sqrt(1 + (f / hi) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x) * h, n=len(x))


def noise(dur: float, rng: np.random.Generator, lo: float | None = None, hi: float | None = None,
          attack: float = 0.001, tau: float | None = None, release: float = 0.005) -> np.ndarray:
    n = ns(dur)
    x = band(rng.standard_normal(n), lo, hi)
    x /= float(np.abs(x).max()) or 1.0
    return x * envelope(n, attack, tau, release)


def svf(x: np.ndarray, cutoff: float | np.ndarray, q: float = 0.707, mode: str = "lp") -> np.ndarray:
    """Filtre à variables d'état (topologie TPT), fréquence de coupure éventuellement variable échantillon par échantillon."""
    n = len(x)
    c = np.clip(np.broadcast_to(np.asarray(cutoff, dtype=float), (n,)), 10.0, SR * 0.45)
    g = np.tan(np.pi * c / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    xs, b1, b2, b3 = x.tolist(), a1.tolist(), a2.tolist(), a3.tolist()
    out = [0.0] * n
    ic1 = ic2 = 0.0
    for i in range(n):
        v3 = xs[i] - ic2
        v1 = b1[i] * ic1 + b2[i] * v3
        v2 = ic2 + b2[i] * ic1 + b3[i] * v3
        ic1, ic2 = 2 * v1 - ic1, 2 * v2 - ic2
        out[i] = v2 if mode == "lp" else v1 if mode == "bp" else xs[i] - k * v1 - v2
    return np.array(out)


def room(x: np.ndarray, mix: float, decay: float = 0.5, tone: float = 5000.0, predelay: float = 0.012,
         seed: int = 7) -> np.ndarray:
    """Petite réverbération : convolution par du bruit à décroissance exponentielle (RT60 = decay), filtré."""
    rng = np.random.default_rng(seed)
    n_ir = ns(decay * 1.2)
    t = times(n_ir)
    ir = band(rng.standard_normal(n_ir) * np.exp(-t * 6.91 / decay), 180.0, tone)
    ir = np.r_[np.zeros(ns(predelay)), ir]
    ir /= float(np.sqrt((ir ** 2).sum()))
    size = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x) + len(ir) - 1]
    return np.r_[x, np.zeros(len(ir) - 1)] + mix * wet


def place(events: list[tuple[float, np.ndarray, float]], total: float | None = None) -> np.ndarray:
    """Mélange de (instant s, signal, gain)."""
    end = max(ns(t) + len(s) for t, s, _ in events)
    out = np.zeros(max(end, ns(total) if total else 0))
    for t, s, g in events:
        i = ns(t) if t > 0 else 0
        out[i: i + len(s)] += g * s
    return out


# --- Mesure et écriture ----------------------------------------------------------------------------------------------

# Pondération K de l'UIT-R BS.1770 (coefficients définis à 48 kHz, évalués à la fréquence physique).
_K1 = ([1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585])
_K2 = ([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621])


def k_gain(freqs: np.ndarray) -> np.ndarray:
    z = np.exp(1j * 2 * np.pi * freqs / 48000.0)

    def h(b: list[float], a: list[float]) -> np.ndarray:
        return (b[0] + b[1] / z + b[2] / z ** 2) / (a[0] + a[1] / z + a[2] / z ** 2)

    return np.abs(h(*_K1) * h(*_K2))


def level_db(x: np.ndarray, win: float = 0.05) -> float:
    """RMS K-pondéré maximal sur une fenêtre glissante de 50 ms (dB)."""
    y = np.fft.irfft(np.fft.rfft(x) * k_gain(np.fft.rfftfreq(len(x), 1.0 / SR)), n=len(x))
    w = min(len(y), ns(win))
    c = np.cumsum(np.r_[0.0, y ** 2])
    ms = (c[w:] - c[:-w]) / w
    return float(10 * np.log10(ms.max() + 1e-20))


def finalize(x: np.ndarray, target_db: float) -> tuple[np.ndarray, dict[str, float]]:
    x = svf(x, 25.0, 0.707, "hp")  # composante continue et infra-graves
    a = np.abs(x)
    last = int(np.flatnonzero(a > a.max() * 10 ** (-60 / 20))[-1])
    x = x[: min(len(x), last + ns(0.004))]
    n = len(x)
    fi, fo = min(n // 4, ns(0.001)), min(n // 3, ns(0.006))
    x[:fi] *= np.linspace(0.0, 1.0, fi)
    x[n - fo:] *= np.cos(0.5 * np.pi * np.linspace(0.0, 1.0, fo)) ** 2
    gain_db = target_db - level_db(x)
    peak_db = 20 * np.log10(float(np.abs(x).max())) + gain_db
    if peak_db > PEAK_MAX_DB:
        gain_db -= peak_db - PEAK_MAX_DB
    y = x * 10 ** (gain_db / 20)
    return y, {"target": target_db, "measured": round(level_db(y), 2),
               "peak_dbfs": round(20 * np.log10(float(np.abs(y).max())), 2)}


def write_wav(path: Path, y: np.ndarray) -> None:
    pcm = np.clip(np.round(y * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# --- Recettes ---------------------------------------------------------------------------------------------------------

def tick(rng: np.random.Generator, ping: float, tau: float = 0.006, noise_amp: float = 0.5) -> np.ndarray:
    """Petit clic mécanique : bruit aigu très bref + résonance."""
    p = partials(ping, max(0.03, tau * 5), [1.0, 1.52], [1.0, 0.35], [tau, tau * 0.6])
    return place([(0.0, p, 1.0), (0.0, noise(0.012, rng, 2500, 9000, 0.0003, 0.0018), noise_amp)])


def woodblock(rng: np.random.Generator, f0: float, tau: float = 0.035) -> np.ndarray:
    body = partials(f0, 0.2, [1.0, 2.72, 4.15], [1.0, 0.45, 0.18], [tau, tau * 0.45, tau * 0.25])
    return place([(0.0, body, 1.0), (0.0, noise(0.02, rng, 900, 6000, 0.0003, 0.003), 0.35)])


def bell(f0: float, dur: float, taus: list[float], ratios: list[float] | None = None,
         amps: list[float] | None = None, attack: float = 0.002) -> np.ndarray:
    return partials(f0, dur, ratios or [1.0, 2.0, 3.01, 4.07], amps or [1.0, 0.4, 0.18, 0.07], taus, attack)


def r_ui_click(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Clic doux : sinus aigu qui retombe + corps triangle + transitoire de bruit."""
    body = voice(p["f"], 0.05, "sine", attack=0.0004, tau=0.007, release=0.004, glide=(p["f_end"], 0.02))
    low = voice(p["f"] / 2, 0.05, "tri", attack=0.0004, tau=0.009, release=0.004)
    return place([(0.0, body, 1.0), (0.0, low, 0.35), (0.0, noise(0.01, rng, 2000, 8000, 0.0002, 0.0015), 0.3)])


def r_ui_hover(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Effleurement : bip triangle très court, légèrement montant."""
    return voice(p["note"], 0.035, "tri", soft=1.0, attack=0.0015, tau=0.006, release=0.006, glide=(p["to"], 0.015))


def two_notes(notes: list[str], step: float, kind: str, duty: float, taus: list[float], soft: float = 0.8) -> np.ndarray:
    ev = [(i * step, voice(n, 0.03 + tau * 4, kind, duty=duty, soft=soft, cap=6000, attack=0.002, tau=tau, release=0.01), 1.0)
          for i, (n, tau) in enumerate(zip(notes, taus))]
    return place(ev)


def whoosh(rng: np.random.Generator, dur: float, f_from: float, f_to: float, q: float = 1.5) -> np.ndarray:
    n = ns(dur)
    cut = f_from * (f_to / f_from) ** np.linspace(0.0, 1.0, n)
    x = svf(rng.standard_normal(n), cut, q, "bp")
    x /= float(np.abs(x).max()) or 1.0
    return x * envelope(n, dur * 0.35, None, dur * 0.5)


def r_ui_open(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Ouverture : deux notes montantes (impulsion 25 %) + souffle filtré qui monte."""
    return place([(0.0, two_notes(p["notes"], p["step"], "pulse", 0.25, [0.04, 0.07]), 1.0),
                  (0.0, whoosh(rng, 0.13, 1000, 4000), p["air"])])


def r_ui_close(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Fermeture : les mêmes notes en descendant + souffle qui descend."""
    return place([(0.0, two_notes(p["notes"], p["step"], "pulse", 0.25, [0.04, 0.06]), 1.0),
                  (0.0, whoosh(rng, 0.13, 4000, 1000), p["air"])])


def r_ui_error(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Erreur : deux notes graves descendantes, carré adouci (« bop-bop »)."""
    a = voice(p["notes"][0], 0.09, "square", soft=0.6, cap=3500, attack=0.003, tau=0.15, release=0.025)
    b = voice(p["notes"][1], 0.15, "square", soft=0.6, cap=3500, attack=0.003, tau=0.15, release=0.04,
              bend_end=(-0.6, 0.1))
    return place([(0.0, a, 1.0), (0.11, b, 1.0)])


def r_ui_toggle(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Interrupteur : clic + deux mini-notes (tic-tac montant)."""
    return place([(0.0, tick(rng, 2400, 0.004), 0.6),
                  (0.0, voice(p["notes"][0], 0.03, "tri", attack=0.001, tau=0.015, release=0.006), 0.8),
                  (0.028, voice(p["notes"][1], 0.045, "tri", attack=0.001, tau=0.02, release=0.008), 0.8)])


def r_ui_tab(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Onglet : froissement très bref + bip triangle."""
    return place([(0.0, noise(0.012, rng, 3000, 9000, 0.0003, 0.002), 0.35),
                  (0.0, voice(p["note"], 0.055, "tri", attack=0.001, tau=0.012, release=0.006, glide=(p["to"], 0.01)), 1.0)])


def r_speed(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Vitesse : petit arpège montant (impulsion 12,5 %) + souffle."""
    ev = [(i * p["step"], voice(n, 0.08, "pulse", duty=0.125, soft=0.6, cap=7000, attack=0.002, tau=0.035, release=0.01), 1.0)
          for i, n in enumerate(p["notes"])]
    return place(ev + [(0.0, whoosh(rng, 0.2, 800, 4000, 2.0), p["air"])])


def r_cash(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Vente : « ka » (bruit bref) puis « tching » métallique à deux frappes, scintillement."""
    ching = bell(hz(p["notes"][0]), 0.8, [0.35, 0.25, 0.2, 0.12, 0.08], [1.0, 1.5, 2.0, 2.76, 3.4], [1.0, 0.5, 0.35, 0.2, 0.1])
    ching2 = bell(hz(p["notes"][1]), 0.7, [0.3, 0.2, 0.15, 0.1], [1.0, 1.5, 2.0, 2.76], [1.0, 0.45, 0.3, 0.15])
    x = place([(0.0, noise(0.02, rng, 1500, 6000, 0.0005, 0.004), 0.6), (0.012, ching, 0.8), (0.08, ching2, 0.6)])
    t = times(len(x))
    x *= 1 - 0.12 * (t > 0.15) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t))
    return room(x, 0.12, 0.5, 7000)


def r_purchase(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Épave remportée : deux coups de marteau d'enchères puis « ta-da » (carré adouci + tierce)."""
    g1 = woodblock(rng, p["gavel"], 0.06)
    g2 = woodblock(rng, p["gavel"] * 0.94, 0.07)
    ta = voice(p["notes"][0], 0.09, "square", soft=0.8, cap=6000, attack=0.003, tau=0.08, release=0.02)
    da = voice(p["notes"][1], 0.45, "square", soft=0.8, cap=6000, attack=0.004, tau=0.3, release=0.06, vibrato=(5.5, 0.12, 0.15))
    third = voice(p["notes"][2], 0.45, "tri", attack=0.004, tau=0.3, release=0.06)
    x = place([(0.0, g1, 0.9), (0.14, g2, 1.0), (0.3, ta, 0.55), (0.38, da, 0.55), (0.38, third, 0.35)])
    return room(x, 0.12, 0.45)


def r_bid(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Mise : « toc » de bois + petit bip qui monte."""
    blip = voice(p["note"], 0.06, "tri", attack=0.002, tau=0.03, release=0.01, glide=(p["to"], 0.03))
    return place([(0.0, woodblock(rng, p["wood"], 0.035), 1.0), (0.02, blip, 0.4)])


def r_scan(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Scanner : balayage sinusoïdal montant pulsé (22 Hz), bruit filtré qui suit, puis deux bips de fin."""
    d = p["sweep_s"]
    n = ns(d)
    t = times(n)
    f = p["f_from"] * (p["f_to"] / p["f_from"]) ** (t / d)
    tone = 0.65 * wave_of("sine", f) + 0.3 * wave_of("sine", f * 0.5)
    am = 0.55 + 0.45 * (0.5 + 0.5 * np.cos(2 * np.pi * p["pulse_hz"] * t)) ** 2
    hiss = svf(rng.standard_normal(n), f * 1.5, 4.0, "bp")
    hiss /= float(np.abs(hiss).max()) or 1.0
    sweep = (tone * am + 0.15 * hiss) * envelope(n, 0.03, None, 0.06)
    beep = voice(p["beep"], 0.05, "sine", attack=0.002, release=0.012)
    x = place([(0.0, sweep, 0.8), (d + 0.05, beep, 0.55), (d + 0.15, beep, 0.55)])
    return room(x, 0.1, 0.35)


def r_repair_start(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Clé à cliquet : série de clics métalliques réguliers puis petit « tink »."""
    ev = []
    for i in range(p["clicks"]):
        ping = p["ping"] * (1 + 0.03 * rng.uniform(-1, 1))
        ev.append((i * p["step"], tick(rng, ping, 0.005, 0.7), 1.0 if i % 2 == 0 else 0.8))
    tink = partials(p["tink"], 0.25, [1.0, 2.4, 3.9], [1.0, 0.4, 0.15], [0.12, 0.07, 0.04])
    ev.append((p["clicks"] * p["step"] + 0.03, tink, 0.5))
    return place(ev)


def r_repair_done(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Réparation finie : appoggiature puis « ding » de cloche claire, sous-octave douce."""
    grace = voice(p["grace"], 0.05, "tri", attack=0.002, tau=0.03, release=0.01)
    ding = bell(hz(p["note"]), 0.7, [0.5, 0.3, 0.18, 0.09])
    sub = voice(hz(p["note"]) / 2, 0.5, "sine", attack=0.003, tau=0.22, release=0.05)
    return room(place([(0.0, grace, 0.45), (0.045, ding, 0.8), (0.045, sub, 0.3)]), 0.12, 0.5)


def r_boost(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Coup de main : coup de marteau (choc grave + tintement métallique) puis étincelle montante."""
    thump = voice(150.0, 0.25, "sine", attack=0.001, tau=0.07, release=0.03, glide=(60.0, 0.08))
    clang = partials(p["metal"], 0.35, [1.0, 1.71, 2.83, 3.96], [1.0, 0.7, 0.5, 0.3], [0.14, 0.1, 0.07, 0.05])
    hit = noise(0.03, rng, 1000, 7000, 0.0003, 0.008)
    spark = voice(p["spark"][0], 0.12, "tri", attack=0.002, tau=0.06, release=0.02, glide=(p["spark"][1], 0.09))
    return room(place([(0.0, thump, 1.0), (0.0, clang, 0.55), (0.0, hit, 0.4), (0.12, spark, 0.35)]), 0.08, 0.35)


def r_paint(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Bombe de peinture : deux cliquetis de bille puis « pschitt » (bruit aigu filtré, léger frémissement)."""
    n = ns(p["spray_s"])
    hiss = band(rng.standard_normal(n), 2200, 7000)
    hiss /= float(np.abs(hiss).max()) or 1.0
    wobble = band(rng.standard_normal(n), None, 30, 1)
    flutter = np.clip(1 + 0.12 * wobble / (float(wobble.std()) or 1.0), 0.75, 1.25)
    spray = hiss * flutter * envelope(n, 0.03, None, 0.15)
    return place([(0.0, tick(rng, 2600, 0.008, 0.5), 0.6), (0.07, tick(rng, 2500, 0.008, 0.5), 0.5), (0.15, spray, 0.7)])


def r_option(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Pose d'option : « clac-clic » mécanique + petite note claire."""
    chime = voice(p["note"], 0.2, "tri", attack=0.002, tau=0.08, release=0.03)
    return place([(0.0, tick(rng, 2200, 0.008), 0.8), (0.045, tick(rng, 2900, 0.007), 0.7), (0.09, chime, 0.6)])


def fanfare(notes: list[tuple[float, str, float]], kind: str, duty: float, soft: float, last_vib: bool = True) -> np.ndarray:
    ev = []
    for i, (t, n, d) in enumerate(notes):
        last = i == len(notes) - 1
        ev.append((t, voice(n, d, kind, duty=duty, soft=soft, cap=6500, attack=0.004, tau=0.35 if last else 0.12,
                            release=0.06 if last else 0.02, vibrato=(5.5, 0.15, 0.15) if last and last_vib else None), 1.0))
    return place(ev)


def r_hire(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Embauche : mini-fanfare montante (impulsion 25 %), tierce et basse triangle sur la note finale."""
    lead = fanfare([tuple(x) for x in p["lead"]], "pulse", 0.25, 0.7)
    t_last = p["lead"][-1][0]
    harm = voice(p["harmony"], 0.5, "tri", attack=0.004, tau=0.35, release=0.06)
    bass = voice(p["bass"], 0.45, "tri", attack=0.004, tau=0.3, release=0.06)
    return room(place([(0.0, lead, 0.6), (t_last, harm, 0.35), (t_last, bass, 0.45)]), 0.12, 0.5)


def r_fire(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Licenciement : « wah-wah-waaah » triste et comique (dent de scie dans un filtre résonant qui s'ouvre et se
    referme à chaque note, vibrato puis chute sur la dernière)."""
    ev = []
    for i, (t, note, d) in enumerate(p["notes"]):
        last = i == len(p["notes"]) - 1
        n = ns(d)
        f = freq_curve(n, hz(note), None, (5.5, 0.35, 0.12) if last else None, (-1.0, 0.25) if last else None)
        x = wave_of("saw", f, soft=0.3, cap=6000)
        u = np.linspace(0.0, 1.0, n)
        cut = 350 + 1350 * np.sin(np.pi * np.clip(u / 0.7, 0.0, 1.0)) ** 1.5 if not last else 350 + 1250 * np.sin(np.pi * np.clip(u / 0.85, 0.0, 1.0))
        y = svf(x, cut, 2.5, "lp") * envelope(n, 0.015, None, 0.05 if not last else 0.12)
        ev.append((t, y, 1.0))
    return room(place(ev), 0.12, 0.5)


def r_research(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Recherche : carillon de science-fiction (cloches FM en arpège pentatonique) sur nappe douce."""
    ev = []
    for i, note in enumerate(p["notes"]):
        fc = hz(note)
        n = ns(0.6)
        t = times(n)
        mod = np.sin(2 * np.pi * fc * p["ratio"] * t) * p["index"] * np.exp(-t / 0.08)
        x = np.sin(2 * np.pi * fc * t + mod) * envelope(n, 0.002, 0.3, 0.05)
        ev.append((i * p["step"], x, 0.7))
    n = ns(0.8)
    t = times(n)
    f = hz(p["pad"])
    pad = (np.sin(2 * np.pi * f * 2 ** (6 / 1200) * t) + np.sin(2 * np.pi * f * 2 ** (-6 / 1200) * t)) * 0.5
    pad *= (0.8 + 0.2 * np.sin(2 * np.pi * 7 * t)) * envelope(n, 0.15, None, 0.35)
    ev.append((0.0, pad, 0.25))
    return room(place(ev), 0.25, 0.6, 6000)


def r_quest_new(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Nouvelle quête : deux notes de cloche montantes (« attention »)."""
    a = bell(hz(p["notes"][0]), 0.45, [0.35, 0.2, 0.12, 0.06], amps=[1.0, 0.35, 0.15, 0.06])
    b = bell(hz(p["notes"][1]), 0.55, [0.4, 0.22, 0.12, 0.06], amps=[1.0, 0.35, 0.15, 0.06])
    return room(place([(0.0, a, 0.8), (p["step"], b, 0.8)]), 0.15, 0.5)


def r_quest_done(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Quête accomplie : arpège C-E-G puis accord final tenu (carré adouci + triangles), étincelle aiguë."""
    lead = fanfare([tuple(x) for x in p["lead"]], "square", 0.5, 0.9)
    t_last = p["lead"][-1][0]
    ev = [(0.0, lead, 0.55)]
    for n in p["chord"]:
        ev.append((t_last, voice(n, 0.6, "tri", attack=0.005, tau=0.4, release=0.08), 0.3))
    ev.append((t_last, voice(p["bass"], 0.55, "tri", attack=0.005, tau=0.35, release=0.08), 0.45))
    ev.append((t_last, bell(hz(p["sparkle"]), 0.4, [0.25, 0.15, 0.08, 0.05]), 0.18))
    return room(place(ev), 0.15, 0.55)


def r_level_up(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Montée de niveau : arpège rapide sur deux octaves (impulsion 12,5 %), note finale tenue et scintillante."""
    ev = []
    for i, note in enumerate(p["notes"]):
        last = i == len(p["notes"]) - 1
        ev.append((i * p["step"], voice(note, 0.38 if last else 0.12, "pulse", duty=0.125, soft=0.6, cap=7000, attack=0.002,
                                        tau=0.2 if last else 0.06, release=0.05 if last else 0.015,
                                        vibrato=(7.0, 0.12, 0.08) if last else None), 1.0))
    t_last = (len(p["notes"]) - 1) * p["step"]
    ev.append((t_last, bell(hz(p["notes"][-1]) * 1.0, 0.5, [0.3, 0.18, 0.1, 0.05]), 0.25))
    return room(place(ev), 0.15, 0.5)


def r_day_start(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Nouvelle journée : deux cloches douces à longue résonance."""
    ratios = [1.0, 2.0, 3.0, 4.2, 5.4]
    amps = [1.0, 0.5, 0.25, 0.12, 0.05]
    b1 = partials(hz(p["notes"][0]), 1.4, ratios, amps, [1.0, 0.7, 0.45, 0.3, 0.2], attack=0.004)
    b2 = partials(hz(p["notes"][1]), 1.2, ratios, amps, [0.9, 0.6, 0.4, 0.25, 0.15], attack=0.004)
    return room(place([(0.0, b1, 0.7), (p["step"], b2, 0.45)]), 0.2, 0.8, 6000)


def r_debt_paid(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Échéance payée : sonnette de tiroir-caisse, tiroir qui glisse et se cale, pièces qui tintent."""
    ding = partials(hz(p["bell"]), 0.6, [1.0, 2.32, 4.25], [1.0, 0.4, 0.15], [0.35, 0.15, 0.08])
    n = ns(0.2)
    slide = band(rng.standard_normal(n), 300, 2500) * envelope(n, 0.02, None, 0.05)
    slide /= float(np.abs(slide).max()) or 1.0
    thunk = place([(0.0, voice(170.0, 0.12, "sine", attack=0.001, tau=0.04, release=0.02, glide=(110.0, 0.05)), 1.0),
                   (0.0, noise(0.03, rng, 200, 1500, 0.0005, 0.01), 0.4)])
    ev = [(0.0, ding, 0.7), (0.06, slide, 0.3), (0.25, thunk, 0.7)]
    for i, t in enumerate(p["coins"]):
        f0 = float(rng.uniform(4000, 6200))
        ev.append((t, partials(f0, 0.12, [1.0, 1.6], [1.0, 0.4], [0.05, 0.03]), 0.35 * (0.85 ** i)))
    return room(place(ev), 0.1, 0.4)


def r_warning(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Alerte douce : deux tons alternés deux fois, carré très adouci."""
    ev = []
    for i, note in enumerate(p["notes"]):
        d = 0.14 if i == len(p["notes"]) - 1 else 0.11
        ev.append((i * p["step"], voice(note, d, "square", soft=1.2, cap=3000, attack=0.006, release=0.025), 1.0))
    return place(ev)


def r_notify(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Notification : « bloup-bip » (deux notes qui glissent vers le haut)."""
    a = voice(p["notes"][0][0], 0.07, "tri", soft=1.0, attack=0.002, tau=0.05, release=0.01, glide=(p["notes"][0][1], 0.02))
    b = voice(p["notes"][1][0], 0.16, "tri", soft=1.0, attack=0.002, tau=0.09, release=0.03, glide=(p["notes"][1][1], 0.02))
    return room(place([(0.0, a, 1.0), (0.07, b, 1.0)]), 0.1, 0.35)


def r_blip_bolt(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Voix de BOLT : impulsion 25 % en deux paliers, modulée en anneau (timbre robotique)."""
    n = ns(p["dur"])
    step = np.clip((times(n) - p["dur"] / 2) / 0.003 + 0.5, 0.0, 1.0)
    f = hz(p["notes"][0]) * (hz(p["notes"][1]) / hz(p["notes"][0])) ** step
    x = wave_of("pulse", f, 0.25, 0.6, 5000)
    ring = np.sin(2 * np.pi * p["ring_hz"] * times(n))
    return (0.55 * x + 0.45 * x * ring) * envelope(n, 0.002, None, 0.008)


def r_blip_odile(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Voix d'Odile : triangle chaud qui retombe légèrement, sous-octave sinus."""
    a = voice(p["note"], p["dur"], "tri", soft=0.8, cap=3000, attack=0.005, release=0.015, glide=(p["to"], p["dur"]))
    b = voice(hz(p["note"]) / 2, p["dur"], "sine", attack=0.005, release=0.015)
    return a + 0.25 * b


def r_blip_lustre(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Voix de Lustre : sinus mielleux qui monte avec un vibrato rapide, deux voix désaccordées."""
    out = np.zeros(ns(p["dur"]))
    for cents in (-10.0, 10.0):
        f0 = hz(p["note"]) * 2 ** (cents / 1200)
        to = hz(p["to"]) * 2 ** (cents / 1200)
        out += voice(f0, p["dur"], "sine", attack=0.006, release=0.015, glide=(to, p["dur"]), vibrato=(28.0, 0.4, 0.0))
        out += 0.3 * voice(f0 * 2, p["dur"], "sine", attack=0.006, release=0.015, glide=(to * 2, p["dur"]))
    return out


def r_blip_inspector(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Voix de l'inspectrice : carré sec, hauteur fixe, attaque et relâche brèves."""
    return voice(p["note"], p["dur"], "square", soft=0.3, cap=4500, attack=0.001, release=0.005)


def r_blip_npc(p: dict[str, Any], rng: np.random.Generator) -> np.ndarray:
    """Voix neutre : impulsion 50 % adoucie, courte décroissance."""
    return voice(p["note"], p["dur"], "pulse", duty=0.5, soft=0.7, cap=4000, attack=0.002, tau=0.02, release=0.006)


Recipe = Callable[[dict[str, Any], np.random.Generator], np.ndarray]

SOUNDS: list[dict[str, Any]] = [
    {"id": "ui_click", "desc": "clic de bouton", "level": -21, "fn": r_ui_click, "params": {"f": 1750.0, "f_end": 1150.0}},
    {"id": "ui_hover", "desc": "survol d'un bouton", "level": -26, "fn": r_ui_hover, "params": {"note": "C7", "to": "D7"}},
    {"id": "ui_open", "desc": "ouverture d'une fenêtre", "level": -19, "fn": r_ui_open, "params": {"notes": ["G5", "D6"], "step": 0.05, "air": 0.12}},
    {"id": "ui_close", "desc": "fermeture d'une fenêtre", "level": -20, "fn": r_ui_close, "params": {"notes": ["D6", "G5"], "step": 0.05, "air": 0.1}},
    {"id": "ui_error", "desc": "action impossible", "level": -18, "fn": r_ui_error, "params": {"notes": ["Eb4", "Bb3"]}},
    {"id": "ui_toggle", "desc": "case à cocher / interrupteur", "level": -20, "fn": r_ui_toggle, "params": {"notes": ["C6", "G6"]}},
    {"id": "ui_tab", "desc": "changement d'onglet", "level": -21, "fn": r_ui_tab, "params": {"note": "A5", "to": "C6"}},
    {"id": "speed", "desc": "changement de vitesse du temps", "level": -19, "fn": r_speed, "params": {"notes": ["C6", "E6", "G6"], "step": 0.045, "air": 0.15}},
    {"id": "cash", "desc": "vente conclue", "level": -14, "fn": r_cash, "params": {"notes": ["D7", "G7"]}},
    {"id": "purchase", "desc": "épave remportée aux enchères", "level": -14, "fn": r_purchase, "params": {"gavel": 420.0, "notes": ["G5", "C6", "E5"]}},
    {"id": "bid", "desc": "mise placée", "level": -17, "fn": r_bid, "params": {"wood": 950.0, "note": "E6", "to": "A6"}},
    {"id": "scan", "desc": "balayage du scanner", "level": -17, "fn": r_scan, "params": {"sweep_s": 0.7, "f_from": 320.0, "f_to": 2400.0, "pulse_hz": 22.0, "beep": "C7"}},
    {"id": "repair_start", "desc": "début de réparation (clé à cliquet)", "level": -17, "fn": r_repair_start, "params": {"clicks": 7, "step": 0.034, "ping": 3300.0, "tink": 1760.0}},
    {"id": "repair_done", "desc": "réparation terminée", "level": -15, "fn": r_repair_done, "params": {"grace": "B5", "note": "E6"}},
    {"id": "boost", "desc": "coup de main (coup de marteau)", "level": -15, "fn": r_boost, "params": {"metal": 760.0, "spark": ["C6", "C7"]}},
    {"id": "paint", "desc": "peinture (bombe)", "level": -18, "fn": r_paint, "params": {"spray_s": 0.5}},
    {"id": "option", "desc": "pose d'une option", "level": -17, "fn": r_option, "params": {"note": "G6"}},
    {"id": "hire", "desc": "embauche (mini-fanfare)", "level": -13, "fn": r_hire, "params": {"lead": [[0.0, "G4", 0.1], [0.11, "C5", 0.1], [0.22, "E5", 0.1], [0.33, "G5", 0.55]], "harmony": "E5", "bass": "C4"}},
    {"id": "fire", "desc": "licenciement (wah-wah triste)", "level": -14, "fn": r_fire, "params": {"notes": [[0.0, "G4", 0.24], [0.25, "F#4", 0.24], [0.5, "F4", 0.6]]}},
    {"id": "research", "desc": "recherche terminée (carillon)", "level": -14, "fn": r_research, "params": {"notes": ["E6", "G6", "A6", "D7"], "step": 0.08, "ratio": 1.41, "index": 1.2, "pad": "E5"}},
    {"id": "quest_new", "desc": "nouvelle quête", "level": -15, "fn": r_quest_new, "params": {"notes": ["A5", "E6"], "step": 0.11}},
    {"id": "quest_done", "desc": "quête accomplie (jingle court)", "level": -12, "fn": r_quest_done, "params": {"lead": [[0.0, "C5", 0.08], [0.09, "E5", 0.08], [0.18, "G5", 0.08], [0.27, "C6", 0.6]], "chord": ["E5", "G5"], "bass": "C4", "sparkle": "C7"}},
    {"id": "level_up", "desc": "montée de niveau (arpège)", "level": -12, "fn": r_level_up, "params": {"notes": ["C5", "E5", "G5", "C6", "E6", "G6", "C7"], "step": 0.045}},
    {"id": "day_start", "desc": "début de journée (cloche douce)", "level": -16, "fn": r_day_start, "params": {"notes": ["F5", "C6"], "step": 0.25}},
    {"id": "debt_paid", "desc": "échéance de dette payée (tiroir-caisse)", "level": -14, "fn": r_debt_paid, "params": {"bell": "E7", "coins": [0.3, 0.34, 0.4, 0.47]}},
    {"id": "warning", "desc": "alerte douce", "level": -15, "fn": r_warning, "params": {"notes": ["A5", "E5", "A5", "E5"], "step": 0.13}},
    {"id": "notify", "desc": "notification", "level": -16, "fn": r_notify, "params": {"notes": [["Bb5", "C6"], ["F6", "G6"]]}},
    {"id": "blip_bolt", "desc": "voix de BOLT (bip robotique)", "level": -21, "fn": r_blip_bolt, "params": {"dur": 0.042, "notes": ["C5", "E5"], "ring_hz": 180.0}},
    {"id": "blip_odile", "desc": "voix d'Odile (bip chaleureux)", "level": -21, "fn": r_blip_odile, "params": {"dur": 0.048, "note": "G4", "to": "F#4"}},
    {"id": "blip_lustre", "desc": "voix de Lustre (bip mielleux)", "level": -21, "fn": r_blip_lustre, "params": {"dur": 0.05, "note": "D5", "to": "E5"}},
    {"id": "blip_inspector", "desc": "voix de l'inspectrice (bip sec)", "level": -22, "fn": r_blip_inspector, "params": {"dur": 0.03, "note": "A5"}},
    {"id": "blip_npc", "desc": "voix neutre des PNJ", "level": -21, "fn": r_blip_npc, "params": {"dur": 0.038, "note": "B4"}},
]


def render(spec: dict[str, Any]) -> tuple[np.ndarray, dict[str, float]]:
    rng = np.random.default_rng(zlib.crc32(spec["id"].encode("utf-8")))
    return finalize(spec["fn"](spec["params"], rng), float(spec["level"]))


def render_all(out_dir: Path) -> list[dict[str, Any]]:
    out_dir.mkdir(parents=True, exist_ok=True)
    infos: list[dict[str, Any]] = []
    for spec in SOUNDS:
        y, lvl = render(spec)
        path = out_dir / f"{spec['id']}.wav"
        write_wav(path, y)
        doc = (spec["fn"].__doc__ or "").strip().replace("\n", " ")
        infos.append({"id": spec["id"], "path": str(path), "desc": spec["desc"], "recipe": " ".join(doc.split()),
                      "params": spec["params"], "level": {"target": lvl["target"], "measured": lvl["measured"]},
                      "peak_dbfs": lvl["peak_dbfs"], "duration_s": round(len(y) / SR, 3)})
    return infos


if __name__ == "__main__":
    import sys
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"
    for info in render_all(target):
        print(f"{info['id']:15s} {info['duration_s']:.3f} s  crête {info['peak_dbfs']:6.2f} dBFS  niveau {info['level']['measured']:6.2f} dB")
