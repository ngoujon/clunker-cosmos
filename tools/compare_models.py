"""Compare les pistes de génération (SDXL+LoRA pixel art, FLUX.1-schnell, Z-Image-Turbo, Qwen-Image)
sur les mêmes prompts/seeds, applique pixelize.py et produit une planche art/compare/sheet.png.

Usage : python tools/compare_models.py [--tracks sdxl_pixel,z_image] [--skip-generate]
"""
from __future__ import annotations

import argparse
import io
import json
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import comfy_client as cc  # noqa: E402
import pixelize  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "compare"
STYLE = "pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges"
NEG = "blurry, photo, realistic, 3d render, text, watermark, signature, logo, frame, border, multiple objects, cropped, noisy gradient"

TRACKS = {
    "sdxl_pixel": {"workflow": "sdxl_pixel_txt2img", "extra": {"LORA_STRENGTH": 1.0}},
    "flux_schnell": {"workflow": "flux_schnell_txt2img", "extra": {}},
    "z_image": {"workflow": "zimage_turbo_txt2img", "extra": {}},
    "qwen_image": {"workflow": "qwen_image_txt2img", "extra": {}},
}

ASSETS = [
    {"id": "hull", "w": 1344, "h": 768, "spec": {"mode": "sprite", "max": [96, 48], "paint_hue": "red"},
     "prompt": f"{STYLE}, side view of a single used spaceship hull without wings, facing right, chunky retro sci-fi shuttle body, red painted hull panels with grey metal details, small round windows, isolated on a plain white background, centered, entire object visible"},
    {"id": "engine", "w": 1024, "h": 1024, "spec": {"mode": "sprite", "max": [40, 32]},
     "prompt": f"{STYLE}, side view of a single spaceship rocket engine thruster module, facing right, grey metal with orange glowing nozzle, isolated on a plain white background, centered, entire object visible"},
    {"id": "portrait", "w": 1024, "h": 1024, "spec": {"mode": "sprite", "max": [48, 48]},
     "prompt": f"{STYLE}, portrait of a friendly green gelatinous alien customer, head and shoulders, front view, big round eyes, wearing a tiny bow tie, isolated on a plain white background, centered"},
    {"id": "icon", "w": 1024, "h": 1024, "spec": {"mode": "sprite", "max": [24, 24]},
     "prompt": f"{STYLE}, single game inventory icon of a big wrench, simple shape, centered, thick dark outline, isolated on a plain white background"},
    {"id": "background", "w": 1344, "h": 768, "spec": {"mode": "opaque", "size": [480, 270]},
     "prompt": f"{STYLE}, cross-section side view of an orbital space station garage interior, three repair bays with cranes and tools, metal floors, round windows showing stars and a planet, cozy industrial atmosphere, wide shot"},
]
SEEDS = [1101, 2202]


def generate(tracks: list[str]) -> None:
    client = cc.ComfyClient()
    if not client.alive():
        raise SystemExit("ComfyUI injoignable sur " + client.base)
    for track in tracks:
        t = TRACKS[track]
        wf = cc.load_workflow(t["workflow"])
        for a in ASSETS:
            for seed in SEEDS:
                raw_path = OUT / "raw" / track / f"{a['id']}_{seed}.png"
                if raw_path.exists():
                    continue
                raw_path.parent.mkdir(parents=True, exist_ok=True)
                params = {"POSITIVE": a["prompt"], "NEGATIVE": NEG, "SEED": seed, "WIDTH": a["w"], "HEIGHT": a["h"], "PREFIX": f"wr_compare/{track}_{a['id']}_{seed}", **t["extra"]}
                t0 = time.time()
                imgs = client.run(cc.fill(wf, params), timeout=1800)
                raw_path.write_bytes(imgs["8"][0])
                (raw_path.with_name(raw_path.stem + "_mask.png")).write_bytes(imgs["12"][0])
                print(f"[{track}] {a['id']} seed {seed} : {time.time() - t0:.1f} s", flush=True)


def build_sheet(tracks: list[str]) -> Path:
    cell_w, cell_h = 300, 190
    sheet = Image.new("RGB", (160 + cell_w * len(ASSETS), 30 + cell_h * len(tracks) * len(SEEDS)), (24, 24, 32))
    dr = ImageDraw.Draw(sheet)
    for i, a in enumerate(ASSETS):
        dr.text((160 + i * cell_w + 4, 8), a["id"], fill=(230, 230, 230))
    row = 0
    report: dict[str, dict[str, str]] = {}
    for track in tracks:
        for seed in SEEDS:
            y = 30 + row * cell_h
            dr.text((6, y + 6), f"{track}\nseed {seed}", fill=(230, 230, 230))
            for i, a in enumerate(ASSETS):
                raw_path = OUT / "raw" / track / f"{a['id']}_{seed}.png"
                if not raw_path.exists():
                    continue
                raw = Image.open(raw_path)
                mask_path = raw_path.with_name(raw_path.stem + "_mask.png")
                mask = Image.open(mask_path) if mask_path.exists() and a["spec"]["mode"] == "sprite" else None
                x = 160 + i * cell_w
                thumb = raw.copy()
                thumb.thumbnail((cell_w // 2 - 6, cell_h - 12))
                sheet.paste(thumb.convert("RGB"), (x + 2, y + 4))
                try:
                    px = pixelize.process(raw, mask, a["spec"])
                except Exception as exc:  # garder la planche même si un rendu échoue
                    dr.text((x + cell_w // 2, y + 20), f"ERR {exc}"[:40], fill=(255, 80, 80))
                    continue
                px_dir = OUT / "px" / track
                px_dir.mkdir(parents=True, exist_ok=True)
                px.save(px_dir / f"{a['id']}_{seed}.png")
                scale = max(1, min((cell_w // 2 - 6) // px.width, (cell_h - 12) // px.height))
                big = px.resize((px.width * scale, px.height * scale), Image.NEAREST)
                bg = Image.new("RGBA", big.size, (60, 60, 76, 255))
                bg.alpha_composite(big)
                sheet.paste(bg.convert("RGB"), (x + cell_w // 2, y + 4))
                n, bad = pixelize.palette_report(px)
                report.setdefault(track, {})[f"{a['id']}_{seed}"] = f"{px.width}x{px.height} {n} couleurs"
            row += 1
    path = OUT / "sheet.png"
    sheet.save(path)
    (OUT / "report.json").write_text(json.dumps(report, indent=1), encoding="utf-8")
    return path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tracks", default=",".join(TRACKS))
    ap.add_argument("--skip-generate", action="store_true")
    args = ap.parse_args()
    tracks = [t for t in args.tracks.split(",") if t]
    if not args.skip_generate:
        generate(tracks)
    print("planche :", build_sheet(tracks))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
