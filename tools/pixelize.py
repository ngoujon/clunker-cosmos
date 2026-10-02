"""Post-traitement pixel art de Clunker Cosmos.

Chaîne : détourage (masque BiRefNet produit par ComfyUI, ou couleur de fond) → recadrage →
quantification perceptuelle (OKLab) sur la palette unique (art/palette.json, ≤ 32 couleurs) →
réduction « nearest » par vote majoritaire (chaque pixel cible prend la couleur de palette la plus
fréquente de sa cellule : aucun mélange, aucune couleur nouvelle) → contour optionnel.

Zones peignables : les pixels dont la teinte correspond à `paint_hue` sont remappés sur les 3
couleurs réservées « primer », que le shader palette-swap remplace en jeu par la peinture choisie.

Usage CLI :
    python tools/pixelize.py raw.png --mask raw_mask.png --out sprite.png --size 96x48 --mode sprite
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PALETTE_FILE = ROOT / "art" / "palette.json"

# Teintes (degrés) des couleurs de « peinture » demandées dans les prompts.
PAINT_HUES = {"red": (345.0, 20.0), "blue": (200.0, 250.0), "green": (85.0, 160.0), "orange": (15.0, 45.0)}


def hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def load_palette() -> tuple[np.ndarray, np.ndarray]:
    """Renvoie (couleurs générales Nx3, couleurs primer 3x3) en uint8."""
    data = json.loads(PALETTE_FILE.read_text(encoding="utf-8"))
    primer = [c.lower() for c in data["primer"]]
    general = [hex_to_rgb(c) for c in data["colors"] if c.lower() not in primer]
    return np.array(general, dtype=np.uint8), np.array([hex_to_rgb(c) for c in primer], dtype=np.uint8)


def srgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
    c = rgb.astype(np.float64) / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    l = 0.4122214708 * c[..., 0] + 0.5363325363 * c[..., 1] + 0.0514459929 * c[..., 2]
    m = 0.2119034982 * c[..., 0] + 0.6806995451 * c[..., 1] + 0.1073969566 * c[..., 2]
    s = 0.0883024619 * c[..., 0] + 0.2817188376 * c[..., 1] + 0.6299787005 * c[..., 2]
    l, m, s = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ], axis=-1)


def nearest_index(rgb: np.ndarray, pal: np.ndarray, chroma_weight: float = 1.0) -> np.ndarray:
    """Index de la couleur de palette la plus proche (distance OKLab) pour chaque pixel."""
    flat = rgb.reshape(-1, 3)
    plab = srgb_to_oklab(pal)
    w = np.array([1.0, chroma_weight, chroma_weight])
    out = np.empty(len(flat), dtype=np.int32)
    for i in range(0, len(flat), 65536):
        lab = srgb_to_oklab(flat[i:i + 65536])
        d = (((lab[:, None, :] - plab[None, :, :]) * w) ** 2).sum(-1)
        out[i:i + 65536] = d.argmin(1)
    return out.reshape(rgb.shape[:2])


def hue_sat_val(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    c = rgb.astype(np.float64) / 255.0
    mx, mn = c.max(-1), c.min(-1)
    diff = mx - mn
    hue = np.zeros(mx.shape)
    nz = diff > 1e-6
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    idx = nz & (mx == r)
    hue[idx] = ((g - b)[idx] / diff[idx]) % 6
    idx = nz & (mx == g)
    hue[idx] = ((b - r)[idx] / diff[idx]) + 2
    idx = nz & (mx == b)
    hue[idx] = ((r - g)[idx] / diff[idx]) + 4
    sat = np.where(mx > 1e-6, diff / np.maximum(mx, 1e-6), 0)
    return hue * 60.0, sat, mx


def in_hue(h: np.ndarray, lo: float, hi: float) -> np.ndarray:
    return (h >= lo) & (h <= hi) if lo <= hi else (h >= lo) | (h <= hi)


def largest_components(mask: np.ndarray, min_frac: float = 0.02) -> np.ndarray:
    """Garde les composantes connexes significatives du masque (supprime les poussières)."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    sizes: list[int] = [0]
    cur = 0
    for y in range(h):
        for x in range(w):
            if mask[y, x] and labels[y, x] == 0:
                cur += 1
                stack = [(y, x)]
                labels[y, x] = cur
                n = 0
                while stack:
                    cy, cx = stack.pop()
                    n += 1
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and labels[ny, nx] == 0:
                            labels[ny, nx] = cur
                            stack.append((ny, nx))
                sizes.append(n)
    if cur == 0:
        return mask
    biggest = max(sizes)
    keep = [i for i, s in enumerate(sizes) if i > 0 and s >= biggest * min_frac]
    return np.isin(labels, keep)


def bg_mask_from_corners(rgb: np.ndarray, tol: float = 0.08) -> np.ndarray:
    """Masque de premier plan par distance à la couleur moyenne des coins (secours sans BiRefNet)."""
    h, w = rgb.shape[:2]
    k = max(2, min(h, w) // 32)
    corners = np.concatenate([rgb[:k, :k].reshape(-1, 3), rgb[:k, -k:].reshape(-1, 3), rgb[-k:, :k].reshape(-1, 3), rgb[-k:, -k:].reshape(-1, 3)])
    bg = srgb_to_oklab(corners.mean(0, keepdims=True).astype(np.uint8))[0]
    lab = srgb_to_oklab(rgb)
    return np.sqrt(((lab - bg) ** 2).sum(-1)) > tol


def mode_reduce(idx: np.ndarray, alpha: np.ndarray, out_w: int, out_h: int, n_colors: int) -> tuple[np.ndarray, np.ndarray]:
    """Réduction par cellules : couleur majoritaire (sur pixels opaques), opacité si ≥ 50 %."""
    h, w = idx.shape
    ys = np.linspace(0, h, out_h + 1).astype(int)
    xs = np.linspace(0, w, out_w + 1).astype(int)
    out = np.zeros((out_h, out_w), dtype=np.int32)
    out_a = np.zeros((out_h, out_w), dtype=bool)
    for j in range(out_h):
        for i in range(out_w):
            cell = idx[ys[j]:max(ys[j + 1], ys[j] + 1), xs[i]:max(xs[i + 1], xs[i] + 1)]
            ca = alpha[ys[j]:max(ys[j + 1], ys[j] + 1), xs[i]:max(xs[i + 1], xs[i] + 1)]
            if ca.mean() >= 0.5:
                out_a[j, i] = True
                vals = cell[ca] if ca.any() else cell.ravel()
                out[j, i] = np.bincount(vals.ravel(), minlength=n_colors).argmax()
    return out, out_a


def add_outline(rgba: np.ndarray, color: tuple[int, int, int]) -> np.ndarray:
    a = rgba[..., 3] > 0
    grown = a.copy()
    grown[1:, :] |= a[:-1, :]
    grown[:-1, :] |= a[1:, :]
    grown[:, 1:] |= a[:, :-1]
    grown[:, :-1] |= a[:, 1:]
    ring = grown & ~a
    out = rgba.copy()
    out[ring] = (*color, 255)
    return out


def enhance(rgb: np.ndarray, contrast: float, saturation: float) -> np.ndarray:
    c = rgb.astype(np.float64)
    if saturation != 1.0:
        grey = c.mean(-1, keepdims=True)
        c = grey + (c - grey) * saturation
    if contrast != 1.0:
        c = 128 + (c - 128) * contrast
    return np.clip(c, 0, 255).astype(np.uint8)


def fit_size(bw: int, bh: int, max_w: int, max_h: int) -> tuple[int, int]:
    s = min(max_w / bw, max_h / bh)
    return max(1, round(bw * s)), max(1, round(bh * s))


def process(rgb_img: Image.Image, mask_img: Image.Image | None, spec: dict[str, Any]) -> Image.Image:
    """Transforme une image brute en sprite pixel art conforme à la palette.

    spec : mode (sprite|opaque), size [w,h] (taille exacte, opaque) ou max [w,h] (sprite, ratio
    conservé), paint_hue (red|blue|green|orange|None), outline (bool), contrast, saturation,
    mask_threshold, chroma_weight, pad (marge en pixels autour du sprite), fill_holes (bouche les
    trous du masque, ex. blouse blanche sur fond blanc), reduce ("box" : voir box_reduce).
    """
    general, primer = load_palette()
    rgb = np.array(rgb_img.convert("RGB"))
    rgb = enhance(rgb, float(spec.get("contrast", 1.1)), float(spec.get("saturation", 1.15)))
    mode = spec.get("mode", "sprite")
    if spec.get("orient") == "flame_left":
        a0 = _quick_alpha(rgb, mask_img)
        ys0, xs0 = np.where(a0)
        rotated = bool(len(xs0)) and (ys0.max() - ys0.min() + 1) > 1.25 * (xs0.max() - xs0.min() + 1)
        if rotated:
            # moteur dessiné à la verticale : rotation de 90° horaire (le haut passe à droite, la tuyère à gauche)
            rgb = np.rot90(rgb, k=-1).copy()
            a0 = np.rot90(a0, k=-1)
            if mask_img is not None:
                mask_img = mask_img.transpose(Image.ROTATE_270)
        # Une fusée verticale a sa flamme en bas : après rotation elle est déjà à gauche.
        if not rotated and _warm_on_right(rgb, a0):
            rgb = rgb[:, ::-1].copy()
            if mask_img is not None:
                mask_img = mask_img.transpose(Image.FLIP_LEFT_RIGHT)
    if spec.get("mask") == "corners":
        mask_img = None
    if mode == "sprite":
        if mask_img is not None:
            m = np.array(mask_img.convert("L").resize(rgb_img.size, Image.BILINEAR)).astype(np.float64) / 255.0
            alpha = m >= float(spec.get("mask_threshold", 0.5))
        else:
            alpha = bg_mask_from_corners(rgb)
        small = Image.fromarray((alpha * 255).astype(np.uint8)).resize((max(1, alpha.shape[1] // 4), max(1, alpha.shape[0] // 4)), Image.NEAREST)
        keep = largest_components(np.array(small) > 127, float(spec.get("min_component", 0.05)))
        keep_full = np.array(Image.fromarray((keep * 255).astype(np.uint8)).resize((alpha.shape[1], alpha.shape[0]), Image.NEAREST)) > 127
        alpha &= keep_full
        if spec.get("fill_holes"):
            holes = fill_holes(keep) & ~keep
            alpha |= np.array(Image.fromarray((holes * 255).astype(np.uint8)).resize((alpha.shape[1], alpha.shape[0]), Image.NEAREST)) > 127
        if not alpha.any():
            raise ValueError("masque vide après détourage")
        ys, xs = np.where(alpha)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        if spec.get("crop", True) is False:
            y0, y1, x0, x1 = 0, alpha.shape[0], 0, alpha.shape[1]
        rgb, alpha = rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1]
        pad = int(spec.get("pad", 1 if spec.get("outline", True) else 0))
        max_w, max_h = spec.get("max", spec.get("size", [64, 64]))
        out_w, out_h = fit_size(x1 - x0, y1 - y0, max_w - 2 * pad, max_h - 2 * pad)
    else:
        alpha = np.ones(rgb.shape[:2], dtype=bool)
        out_w, out_h = spec["size"]
        pad = 0
        # recadrage centré au ratio cible
        h, w = rgb.shape[:2]
        tr = out_w / out_h
        if w / h > tr:
            nw = int(h * tr)
            x0 = (w - nw) // 2
            rgb, alpha = rgb[:, x0:x0 + nw], alpha[:, x0:x0 + nw]
        else:
            nh = int(w / tr)
            y0 = (h - nh) // 2
            rgb, alpha = rgb[y0:y0 + nh], alpha[y0:y0 + nh]

    if spec.get("reduce") == "box" and mode == "sprite":
        return _finish(box_reduce(rgb, alpha, out_w, out_h, general, spec), spec, mode, pad, general)

    # Échantillonnage nearest à 4x la taille cible (le vote majoritaire se fait sur 4x4 points).
    work_w, work_h = min(rgb.shape[1], out_w * 4), min(rgb.shape[0], out_h * 4)
    if (work_w, work_h) != (rgb.shape[1], rgb.shape[0]):
        rgb = np.array(Image.fromarray(rgb).resize((work_w, work_h), Image.NEAREST))
        alpha = np.array(Image.fromarray((alpha * 255).astype(np.uint8)).resize((work_w, work_h), Image.NEAREST)) > 127

    # Palette de travail : couleurs générales (+ primer pour les zones peignables).
    pal = general
    idx = nearest_index(rgb, general, float(spec.get("chroma_weight", 1.6)))
    paint = spec.get("paint_hue")
    if paint:
        lo, hi = PAINT_HUES[paint]
        hue, sat, val = hue_sat_val(rgb)
        pmask = in_hue(hue, lo, hi) & (sat > float(spec.get("paint_min_sat", 0.30))) & (val > 0.18) & alpha
        if pmask.any():
            lum = srgb_to_oklab(rgb)[..., 0]
            pl = lum[pmask]
            q1, q2 = np.quantile(pl, [0.33, 0.70])
            level = np.where(lum < q1, 0, np.where(lum < q2, 1, 2))
            idx = np.where(pmask, len(general) + level, idx)
        pal = np.concatenate([general, primer])
    small_idx, small_a = mode_reduce(idx, alpha, out_w, out_h, len(pal))
    rgba = np.zeros((out_h, out_w, 4), dtype=np.uint8)
    rgba[..., :3] = pal[small_idx]
    rgba[..., 3] = np.where(small_a, 255, 0)
    if spec.get("marks"):
        # Calque d'usure : ne garder que la fraction la plus « marquée » de la texture
        # (saturée pour la rouille, claire pour les rayures, sombre pour les bosses et la suie).
        lab = srgb_to_oklab(rgba[..., :3])
        crit = str(spec["marks"])
        if crit == "saturated":
            score = np.hypot(lab[..., 1], lab[..., 2])
        elif crit == "bright":
            score = lab[..., 0]
        else:
            score = -lab[..., 0]
        thr = np.quantile(score, 1.0 - float(spec.get("keep_frac", 0.25)))
        rgba[..., 3] = np.where(score >= thr, 255, 0)
    return _finish(rgba, spec, mode, pad, general)


def _finish(rgba: np.ndarray, spec: dict[str, Any], mode: str, pad: int, general: np.ndarray) -> Image.Image:
    """Marge, contour et canevas communs à toutes les réductions."""
    out_h, out_w = rgba.shape[:2]
    if mode == "sprite" and pad:
        padded = np.zeros((out_h + 2 * pad, out_w + 2 * pad, 4), dtype=np.uint8)
        padded[pad:pad + out_h, pad:pad + out_w] = rgba
        rgba = padded
        if spec.get("outline", True):
            rgba = add_outline(rgba, tuple(int(v) for v in general[0]))
    img = Image.fromarray(rgba, "RGBA")
    if spec.get("canvas"):
        img = place_on_canvas(img, spec["canvas"], spec.get("align", "center"))
    return img


def fill_holes(mask: np.ndarray) -> np.ndarray:
    """Masque sans trous : seules les zones transparentes reliées au bord de l'image restent transparentes."""
    h, w = mask.shape
    outside = np.zeros_like(mask, dtype=bool)
    stack = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    stack = [(y, x) for y, x in stack if not mask[y, x]]
    for y, x in stack:
        outside[y, x] = True
    while stack:
        y, x = stack.pop()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx] and not outside[ny, nx]:
                outside[ny, nx] = True
                stack.append((ny, nx))
    return ~outside


def box_reduce(rgb: np.ndarray, alpha: np.ndarray, out_w: int, out_h: int, pal: np.ndarray, spec: dict[str, Any]) -> np.ndarray:
    """Réduction par moyenne de zone (pixels opaques seulement), puis couleur de palette la plus proche.

    Réservée aux très petits personnages (~26 px de haut) : le vote majoritaire n'y retient que les
    épais contours noirs de l'image source, alors que la moyenne garde les yeux, lunettes et moustaches.
    Aucune couleur hors palette : le mélange n'existe qu'avant la quantification.
    """
    a = alpha.astype(np.float32)

    def box(arr: np.ndarray) -> np.ndarray:
        return np.array(Image.fromarray(arr.astype(np.float32), "F").resize((out_w, out_h), Image.BOX))

    sa = box(a)
    sr = np.stack([box(rgb[..., c].astype(np.float32) * a) for c in range(3)], -1)
    col = np.clip(sr / np.maximum(sa[..., None], 1e-6), 0, 255).astype(np.uint8)
    col = enhance(col, float(spec.get("box_contrast", 1.15)), float(spec.get("box_saturation", 1.25)))
    idx = nearest_index(col, pal, float(spec.get("chroma_weight", 1.6)))
    rgba = np.zeros((out_h, out_w, 4), dtype=np.uint8)
    rgba[..., :3] = pal[idx]
    rgba[..., 3] = np.where(sa >= 0.5, 255, 0)
    return rgba


def place_on_canvas(img: Image.Image, size: list[int], align: str) -> Image.Image:
    """Centre (ou aligne en bas) un sprite dans un canevas transparent de taille fixe."""
    cw, ch = size
    if img.width > cw or img.height > ch:
        s = min(cw / img.width, ch / img.height)
        img = img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.NEAREST)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    x = (cw - img.width) // 2
    y = ch - img.height if align == "bottom" else (ch - img.height) // 2
    canvas.alpha_composite(img, (x, y))
    return canvas


def _warm_on_right(rgb: np.ndarray, alpha: np.ndarray | None = None) -> bool:
    """Vrai si une flamme (pixels orange/jaune saturés et lumineux) est majoritairement à droite de l'objet."""
    hue, sat, val = hue_sat_val(rgb)
    warm = in_hue(hue, 5.0, 60.0) & (sat > 0.55) & (val > 0.6)
    if alpha is not None:
        warm &= alpha
    ys, xs = np.where(warm)
    obj = int(alpha.sum()) if alpha is not None else rgb.shape[0] * rgb.shape[1]
    if len(xs) < max(30, int(0.01 * obj)):
        return False
    if alpha is not None and alpha.any():
        cx = float(np.where(alpha)[1].mean())
    else:
        cx = rgb.shape[1] / 2
    return float(xs.mean()) > cx


def _quick_alpha(rgb: np.ndarray, mask_img: Image.Image | None) -> np.ndarray:
    if mask_img is not None:
        m = np.array(mask_img.convert("L").resize((rgb.shape[1], rgb.shape[0]), Image.BILINEAR))
        return m >= 128
    return bg_mask_from_corners(rgb)


def palette_report(img: Image.Image) -> tuple[int, list[str]]:
    """Nombre de couleurs opaques et liste de celles hors palette."""
    general, primer = load_palette()
    allowed = {tuple(int(v) for v in c) for c in np.concatenate([general, primer])}
    arr = np.array(img.convert("RGBA")).reshape(-1, 4)
    opaque = arr[arr[:, 3] > 0][:, :3]
    cols = {tuple(int(v) for v in c) for c in np.unique(opaque, axis=0)} if len(opaque) else set()
    bad = ["#%02x%02x%02x" % c for c in cols - allowed]
    return len(cols), bad


def anchors_for(img: Image.Image, slot: str) -> dict[str, list[int]]:
    """Points d'ancrage déduits de l'alpha (vaisseaux orientés vers la droite)."""
    a = np.array(img.convert("RGBA"))[..., 3] > 0
    ys, xs = np.where(a)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    cy = (y0 + y1) // 2

    def col_span(x: int) -> tuple[int, int]:
        col = np.where(a[:, x])[0]
        return (int(col.min()), int(col.max())) if len(col) else (cy, cy)

    if slot == "hull":
        left = col_span(x0 + 1)
        cx = x0 + int((x1 - x0) * 0.68)
        top = col_span(cx)
        wx = x0 + int((x1 - x0) * 0.42)
        wspan = col_span(wx)
        return {
            "engine": [x0 + 2, (left[0] + left[1]) // 2],
            "cockpit": [cx, top[0] + 2],
            "wings": [wx, (wspan[0] + wspan[1]) // 2 + max(1, (wspan[1] - wspan[0]) // 6)],
            "size": [img.width, img.height],
        }
    if slot == "engine":
        right = col_span(x1 - 1)
        return {"mount": [x1 - 2, (right[0] + right[1]) // 2], "size": [img.width, img.height]}
    if slot == "cockpit":
        mid = x0 + (x1 - x0) // 2
        return {"mount": [mid, col_span(mid)[1] - 2], "size": [img.width, img.height]}
    if slot == "wings":
        return {"mount": [x0 + int((x1 - x0) * 0.55), y0 + int((y1 - y0) * 0.35)], "size": [img.width, img.height]}
    return {"size": [img.width, img.height]}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image")
    ap.add_argument("--mask")
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", default="64x64", help="LxH (max pour sprite, exact pour opaque)")
    ap.add_argument("--mode", default="sprite", choices=["sprite", "opaque"])
    ap.add_argument("--paint", default=None, choices=sorted(PAINT_HUES))
    ap.add_argument("--no-outline", action="store_true")
    args = ap.parse_args()
    w, h = (int(v) for v in args.size.lower().split("x"))
    spec = {"mode": args.mode, ("max" if args.mode == "sprite" else "size"): [w, h], "paint_hue": args.paint, "outline": not args.no_outline}
    img = process(Image.open(args.image), Image.open(args.mask) if args.mask else None, spec)
    img.save(args.out)
    n, bad = palette_report(img)
    print(f"{args.out}: {img.width}x{img.height}, {n} couleurs, hors palette: {len(bad)}")
    return 0 if not bad else 1


if __name__ == "__main__":
    raise SystemExit(main())
