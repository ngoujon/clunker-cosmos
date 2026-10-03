# Déclaration d'utilisation de l'IA générative (AI disclosure)

Ce fichier est régénéré par `python tools/gen_assets.py build` ; le détail exhaustif (prompt, graine,
workflow, post-traitement, empreinte SHA-256) de chaque fichier se trouve dans `art/manifest.json`.

## Résumé pour la page Steam (section « AI Generated Content Disclosure »)

> **Pre-generated content** : all 2.5D artwork (stylized 3D-rendered spaceship parts, wear overlays, character
> portraits and sprites, icons and backgrounds) was generated locally with the open-weights model Z-Image-Turbo
> (Apache-2.0) through ComfyUI, then cut out, downscaled and sharpened by our own script (`tools/hd_art.py`);
> the garage backdrop was restyled from our previous in-house backdrop (img2img) to keep its layout. Background
> removal uses BiRefNet (MIT). Interface frames and the mouse cursor are drawn by code. The five instrumental music tracks were
> pre-generated locally with the open-weights model ACE-Step 1.5 (MIT) from generic style descriptions,
> then mastered by our own script (`tools/gen_audio.py`); sound effects are synthesized by code, without AI.
> No live/runtime AI generation happens in the game. Prompts describe original concepts only: no artist,
> studio, franchise, existing work or character was referenced or imitated. Game code, design, story and
> texts were written with the help of an AI coding assistant (Claude) under human direction.

## Outils et modèles

| Rôle | Modèle / outil | Licence |
|---|---|---|
| Génération d'images (retenu) | Z-Image-Turbo bf16 + encodeur Qwen3-4B + VAE ae | Apache-2.0 |
| Détourage | BiRefNet (nœud ComfyUI RemoveBackground) | MIT |
| Musique (pré-générée) | ACE-Step 1.5 turbo (`ace_step_1.5_turbo_aio.safetensors`) | MIT (reconditionnement Comfy-Org Apache-2.0) |
| Bruitages | tools/sfx_synth.py (synthèse procédurale, sans IA) | propriétaire du projet |
| Post-traitement | tools/hd_art.py (code du projet) | propriétaire du projet |
| Évalués puis écartés | SDXL base 1.0 + LoRA pixel-art-xl, FLUX.1-schnell, Qwen-Image 2512 | voir MODEL_LICENSES.md |

## Assets générés par catégorie

| Catégorie | Nombre |
|---|---|
| background | 6 |
| cockpit | 6 |
| engine | 6 |
| hull | 8 |
| icon | 109 |
| portrait | 26 |
| portrait_small | 26 |
| wear | 4 |
| wings | 4 |
| worker | 10 |

Total : 205 fichiers générés, 4 dérivés ou faits main.

## Liste des fichiers

| Fichier | Graine | Prompt (début) |
|---|---|---|
| `assets/ships/hull/hull_shuttle.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/hull/hull_courier.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/hull/hull_tug.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/hull/hull_miner.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/hull/hull_cargo.png` | 55 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/hull/hull_fighter.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/hull/hull_yacht.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/hull/hull_explorer.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/engine/eng_putt.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/engine/eng_ion.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/engine/eng_twin.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/engine/eng_plasma.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/engine/eng_fusion.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/engine/eng_warp.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/cockpit/cock_box.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/cockpit/cock_bubble.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/cockpit/cock_visor.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/cockpit/cock_armored.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/cockpit/cock_lounge.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/cockpit/cock_crystal.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/wings/wing_stub.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/wings/wing_delta.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/wings/wing_swept.png` | 66 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/wings/wing_solar.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/ships/wear/wear_rust.png` | 22 | high resolution grunge decal texture, messy random splatter of orange and brown rust stains of irregular sizes… |
| `assets/ships/wear/wear_scratch.png` | 11 | high resolution grunge decal texture, messy random dark grey scratch lines of different lengths crossing at ra… |
| `assets/ships/wear/wear_dent.png` | 22 | high resolution grunge decal texture, messy random dark grey dents and dings of irregular sizes and shapes, sc… |
| `assets/ships/wear/wear_scorch.png` | 11 | high resolution grunge decal texture, messy random black soot smudges and burn splotches of irregular sizes an… |
| `assets/portraits/client_01.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_01.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_02.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_02.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_03.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_03.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_04.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_04.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_05.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_05.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_06.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_06.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_07.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_07.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_08.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_08.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_09.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_09.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_10.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_10.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_11.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_11.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/client_12.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/client_12.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/staff_01.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/staff_01.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/staff_02.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/staff_02.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/staff_03.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/staff_03.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/staff_04.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/staff_04.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/staff_05.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/staff_05.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/staff_06.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/staff_06.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/staff_07.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/staff_07.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/staff_08.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/staff_08.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/staff_09.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/staff_09.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/staff_10.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/staff_10.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/story_bolt.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/story_bolt.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/story_odile.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/story_odile.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/story_lustre.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/story_lustre.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/story_inspector.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/portraits/small/story_inspector.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/workers/staff_01.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/workers/staff_02.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/workers/staff_03.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/workers/staff_04.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/workers/staff_05.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/workers/staff_06.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/workers/staff_07.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/workers/staff_08.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/workers/staff_09.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/workers/staff_10.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_credits.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_rp.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_rep.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_debt.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_day.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_garage.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_auction.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_staff.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_research.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_quests.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_sales.png` | 44 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_settings.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_scan.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_bid.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_repair.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_conceal.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_paint.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_sell.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_hire.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_check.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_lock.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_warning.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_star.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/ui_report.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/role_buyer.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/role_mechanic.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/role_bodyworker.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/role_seller.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/role_researcher.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/branch_atelier.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/branch_commerce.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/branch_perso.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/branch_rh.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/branch_diagnostic.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/branch_lieux.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/item_keel.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/item_heart.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/item_sail.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/item_star.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/item_compass.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_rust.png` | 44 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_dent.png` | 44 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_breach.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_misfire.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_plasma.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_fuel.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_nav.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_canopy.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_ai.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_wing.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_wiring.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_battery.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_air.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_gravity.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/def_toilet.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_polish.png` | 44 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_flames.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_horn.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_rack.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_baby.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_spoiler.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_neon.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_leather.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_minibar.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_shield.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_autopilot.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/opt_solar.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_at_1.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_at_2.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_at_3.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_at_4.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_at_5.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_at_6.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_at_7.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_co_1.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_co_2.png` | 44 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_co_3.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_co_4.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_co_5.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_co_6.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_co_7.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_pe_1.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_pe_2.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_pe_3.png` | 44 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_pe_4.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_pe_5.png` | 44 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_pe_6.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_pe_7.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_rh_1.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_rh_2.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_rh_3.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_rh_4.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_rh_5.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_rh_6.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_rh_7.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_di_1.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_di_2.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_di_3.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_di_4.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_di_5.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_di_6.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_di_7.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_li_1.png` | 55 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_li_2.png` | 22 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_li_3.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_li_4.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_li_5.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_li_6.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/icons/tech_li_7.png` | 11 | stylized 3D render, high quality game asset, smooth sculpted shapes, soft studio lighting with gentle rim ligh… |
| `assets/backgrounds/garage.png` | 33 | stylized 3D rendered game environment, 2.5D diorama, cinematic soft lighting, volumetric light rays, subtle de… |
| `assets/backgrounds/loc_ferropolis.png` | 11 | stylized 3D rendered game environment, 2.5D diorama, cinematic soft lighting, volumetric light rays, subtle de… |
| `assets/backgrounds/loc_kryo7.png` | 11 | stylized 3D rendered game environment, 2.5D diorama, cinematic soft lighting, volumetric light rays, subtle de… |
| `assets/backgrounds/loc_nebula.png` | 22 | stylized 3D rendered game environment, 2.5D diorama, cinematic soft lighting, volumetric light rays, subtle de… |
| `assets/backgrounds/loc_tartarus.png` | 11 | stylized 3D rendered game environment, 2.5D diorama, cinematic soft lighting, volumetric light rays, subtle de… |
| `assets/backgrounds/loc_opalia.png` | 22 | stylized 3D rendered game environment, 2.5D diorama, cinematic soft lighting, volumetric light rays, subtle de… |

## Audio

- **Musique** : pistes instrumentales **pré-générées localement** avec ACE-Step 1.5 turbo (licence MIT) dans
  ComfyUI (workflow `comfy/workflows/ace_step15_music.json`, script `tools/gen_audio.py`) à partir de
  descriptions de style génériques ; trois graines par piste, choix par mesures objectives, puis mastering
  (-16 LUFS, fondus). Détail (invites, graines, réglages, mesures) dans `art/audio_manifest.json`.
- **Bruitages** : 32 effets synthétisés par code (numpy, `tools/sfx_synth.py`), sans IA ni échantillon tiers.

| Fichier | Rôle | Graine | Style demandé (début) |
|---|---|---|---|
| `assets/audio/music/title.ogg` | menu titre | 1103 | Instrumental retro space funk with a light synthwave shine. Joyful, adventurous and upbeat main menu… |
| `assets/audio/music/garage_a.ogg` | jeu (atelier, détendu) | 1202 | Instrumental lo-fi space funk for a relaxed workshop. Laid-back groovy bassline, mellow electric pia… |
| `assets/audio/music/garage_b.ogg` | jeu (atelier, ensoleillé) | 1303 | Instrumental retro synth funk, sunny and easygoing. Bouncy synth bass, muted funk guitar, soft analo… |
| `assets/audio/music/garage_c.ogg` | jeu (orbite de nuit, rêveur) | 1403 | Instrumental dreamy space lounge, downtempo lo-fi synthwave. Warm electric piano chords, deep round … |
| `assets/audio/music/jingle_win.ogg` | jingle de victoire (fin de chapitre) | 1504 | Short instrumental victory fanfare jingle. Triumphant retro synth brass, bright arpeggio flourish, p… |
