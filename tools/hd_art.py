"""Post-traitement « 2.5D » de Clunker Cosmos (version 0.3, remplace la pixelisation).

Chaîne : détourage doux (masque BiRefNet de ComfyUI, ou distance à la couleur des coins) → recadrage →
réduction de qualité (Lanczos en alpha prémultiplié, léger renforcement de netteté) à DETAIL fois la taille
logique de l'asset en jeu → marge transparente et canevas. Le jeu affiche ces images à leur taille logique
(`UIKit.tex` : taille réduite d'un facteur DETAIL, mipmaps, filtrage linéaire), si bien qu'elles restent
nettes à toutes les tailles d'interface.

Zones peignables (coques, ailes) : les pixels de la teinte `paint_hue` forment un masque doux enregistré à
côté de l'image (`<id>_paint.png`) ; le shader `ship_part.gdshader` y recolore la pièce avec la peinture choisie
en gardant l'ombrage du rendu.
"""
from __future__ import annotations

import math
from typing import Any

import numpy as np
from PIL import Image, ImageFilter

import pixelize as px

## Pixels d'image par pixel logique du jeu (doit valoir UIKit.DETAIL).
DETAIL = 4


def _soft_alpha(rgb: np.ndarray, mask_img: Image.Image | None) -> np.ndarray:
    """Alpha entre 0 et 1 : masque BiRefNet (déjà doux) ou distance à la couleur des coins."""
    h, w = rgb.shape[:2]
    if mask_img is not None:
        return np.array(mask_img.convert("L").resize((w, h), Image.BILINEAR)).astype(np.float32) / 255.0
    k = max(2, min(h, w) // 32)
    corners = np.concatenate([rgb[:k, :k].reshape(-1, 3), rgb[:k, -k:].reshape(-1, 3), rgb[-k:, :k].reshape(-1, 3), rgb[-k:, -k:].reshape(-1, 3)])
    bg = px.srgb_to_oklab(corners.mean(0, keepdims=True).astype(np.uint8))[0]
    d = np.sqrt(((px.srgb_to_oklab(rgb) - bg) ** 2).sum(-1))
    return np.clip((d - 0.04) / 0.10, 0.0, 1.0).astype(np.float32)


def _resize_premul(rgb: np.ndarray, alpha: np.ndarray, size: tuple[int, int]) -> tuple[np.ndarray, np.ndarray]:
    """Réduction Lanczos en alpha prémultiplié (pas de halo blanc du fond autour des sprites)."""
    a = alpha.astype(np.float32)
    chans = []
    for c in range(3):
        ch = Image.fromarray((rgb[..., c].astype(np.float32) * a), "F").resize(size, Image.LANCZOS)
        chans.append(np.array(ch))
    sa = np.clip(np.array(Image.fromarray(a, "F").resize(size, Image.LANCZOS)), 0.0, 1.0)
    col = np.stack(chans, -1) / np.maximum(sa[..., None], 1e-4)
    col = np.where(sa[..., None] > 1e-3, col, 0.0)
    return np.clip(col, 0, 255).astype(np.uint8), sa


def _sharpen(img: Image.Image) -> Image.Image:
    rgb = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def _paint_mask(rgb: np.ndarray, alpha: np.ndarray, hue_name: str) -> np.ndarray:
    """Masque doux (0-255) des pixels de la teinte de peinture, saturés et pas trop sombres."""
    lo, hi = px.PAINT_HUES[hue_name]
    hue, sat, val = px.hue_sat_val(rgb)
    m = px.in_hue(hue, lo, hi).astype(np.float32)
    m *= np.clip((sat - 0.22) / 0.18, 0.0, 1.0) * np.clip((val - 0.08) / 0.10, 0.0, 1.0)
    m = np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255.0
    return (np.clip(m * alpha, 0, 1) * 255).astype(np.uint8)


def _place(img: Image.Image, canvas: tuple[int, int], align: str) -> tuple[Image.Image, tuple[int, int]]:
    cw, ch = canvas
    out = Image.new(img.mode, (cw, ch), 0 if img.mode == "L" else (0, 0, 0, 0))
    x = (cw - img.width) // 2
    y = ch - img.height - (DETAIL if align == "bottom_pad" else 0) if align.startswith("bottom") else (ch - img.height) // 2
    out.paste(img, (x, y))
    return out, (x, y)


def process(rgb_img: Image.Image, mask_img: Image.Image | None, spec: dict[str, Any]) -> tuple[Image.Image, Image.Image | None]:
    """Image brute → (image RGBA à DETAIL × la taille logique, masque de peinture L ou None)."""
    rgb = np.array(rgb_img.convert("RGB"))
    mode = spec.get("mode", "sprite")
    if mode == "opaque":
        out_w, out_h = (int(v) * DETAIL for v in spec["size"])
        h, w = rgb.shape[:2]
        tr = out_w / out_h
        if w / h > tr:
            nw = int(round(h * tr))
            rgb = rgb[:, (w - nw) // 2:(w - nw) // 2 + nw]
        else:
            nh = int(round(w / tr))
            rgb = rgb[(h - nh) // 2:(h - nh) // 2 + nh]
        img = Image.fromarray(rgb).resize((out_w, out_h), Image.LANCZOS).convert("RGBA")
        return img, None
    if mode == "decal":
        # Calque d'usure : alpha = écart au fond blanc, toute l'image gardée (couvre la pièce en se répétant).
        alpha = _soft_alpha(rgb, None)
        out_w, out_h = (int(v) * DETAIL for v in spec["size"])
        col, sa = _resize_premul(rgb, alpha, (out_w, out_h))
        rgba = np.dstack([col, (sa * 255).astype(np.uint8)])
        return Image.fromarray(rgba, "RGBA"), None

    if spec.get("orient") == "flame_left":
        a0 = px._quick_alpha(rgb, mask_img)
        ys0, xs0 = np.where(a0)
        rotated = bool(len(xs0)) and (ys0.max() - ys0.min() + 1) > 1.25 * (xs0.max() - xs0.min() + 1)
        if rotated:
            rgb = np.rot90(rgb, k=-1).copy()
            a0 = np.rot90(a0, k=-1)
            if mask_img is not None:
                mask_img = mask_img.transpose(Image.ROTATE_270)
        if not rotated and px._warm_on_right(rgb, a0):
            rgb = rgb[:, ::-1].copy()
            if mask_img is not None:
                mask_img = mask_img.transpose(Image.FLIP_LEFT_RIGHT)
    alpha = _soft_alpha(rgb, mask_img)
    hard = alpha >= 0.5
    # Composantes significatives (poussières et objets parasites retirés), calculées en basse résolution.
    small = Image.fromarray((hard * 255).astype(np.uint8)).resize((max(1, hard.shape[1] // 4), max(1, hard.shape[0] // 4)), Image.NEAREST)
    keep = px.largest_components(np.array(small) > 127, float(spec.get("min_component", 0.05)))
    if spec.get("fill_holes"):
        keep = px.fill_holes(keep)
    keep_img = Image.fromarray((keep * 255).astype(np.uint8)).resize((alpha.shape[1], alpha.shape[0]), Image.NEAREST)
    keep_full = np.array(keep_img.filter(ImageFilter.MaxFilter(9))) > 127
    alpha = np.where(keep_full, alpha, 0.0)
    if spec.get("fill_holes"):
        # Trous du masque bouchés (blouse blanche sur fond blanc) : intérieur du masque rempli rendu opaque.
        alpha = np.maximum(alpha, (np.array(keep_img.filter(ImageFilter.MinFilter(9))) > 127).astype(np.float32))
    if not (alpha >= 0.5).any():
        raise ValueError("masque vide après détourage")
    ys, xs = np.where(alpha >= 0.08)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgb, alpha = rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1]
    rgb = px.enhance(rgb, float(spec.get("contrast", 1.04)), float(spec.get("saturation", 1.06)))
    max_w, max_h = spec.get("max", spec.get("size", [64, 64]))
    # Marge transparente d'un pixel logique (filtrage linéaire sans bord coupé).
    avail_w, avail_h = (int(max_w) - 2) * DETAIL, (int(max_h) - 2) * DETAIL
    s = min(avail_w / (x1 - x0), avail_h / (y1 - y0))
    ow, oh = max(1, round((x1 - x0) * s)), max(1, round((y1 - y0) * s))
    col, sa = _resize_premul(rgb, alpha, (ow, oh))
    sprite = _sharpen(Image.fromarray(np.dstack([col, (sa * 255).astype(np.uint8)]), "RGBA"))
    paint = Image.fromarray(_paint_mask(col, sa, spec["paint_hue"]), "L") if spec.get("paint_hue") else None
    if spec.get("canvas"):
        canvas = (int(spec["canvas"][0]) * DETAIL, int(spec["canvas"][1]) * DETAIL)
        align = spec.get("align", "center")
    else:
        canvas = (math.ceil(ow / DETAIL + 2) * DETAIL, math.ceil(oh / DETAIL + 2) * DETAIL)
        align = "center"
    sprite, _ = _place(sprite, canvas, "bottom" if align == "bottom" else "center")
    if paint is not None:
        paint, _ = _place(paint, canvas, "bottom" if align == "bottom" else "center")
    return sprite, paint


def logical_alpha(img: Image.Image) -> Image.Image:
    """Image RGBA réduite à sa taille logique (alpha binarisé) : calcul des points d'ancrage des pièces."""
    w, h = img.width // DETAIL, img.height // DETAIL
    a = np.array(img.getchannel("A").resize((w, h), Image.BOX)) >= 110
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[..., 3] = np.where(a, 255, 0)
    return Image.fromarray(rgba, "RGBA")


def downsize(img: Image.Image, logical: tuple[int, int]) -> Image.Image:
    """Version réduite (ex. portrait 24×24 logique) depuis l'image HD, en alpha prémultiplié."""
    arr = np.array(img.convert("RGBA"))
    col, sa = _resize_premul(arr[..., :3], arr[..., 3].astype(np.float32) / 255.0, (logical[0] * DETAIL, logical[1] * DETAIL))
    return _sharpen(Image.fromarray(np.dstack([col, (sa * 255).astype(np.uint8)]), "RGBA"))
