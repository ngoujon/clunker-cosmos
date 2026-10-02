# Déclaration d'utilisation de l'IA générative (AI disclosure)

Ce fichier est régénéré par `python tools/gen_assets.py build` ; le détail exhaustif (prompt, graine,
workflow, post-traitement, empreinte SHA-256) de chaque fichier se trouve dans `art/manifest.json`.

## Résumé pour la page Steam (section « AI Generated Content Disclosure »)

> **Pre-generated content** : all 2D pixel art (spaceship parts, wear overlays, character portraits and
> sprites, icons, backgrounds and UI frames) was generated locally with the open-weights model Z-Image-Turbo (Apache-2.0)
> through ComfyUI, then reduced and quantized to a hand-made 32-color palette by our own script
> (`tools/pixelize.py`). Background removal uses BiRefNet (MIT). The five instrumental music tracks were
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
| Post-traitement | tools/pixelize.py (code du projet) | propriétaire du projet |
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
| ui | 2 |
| wear | 4 |
| wings | 4 |
| worker | 10 |

Total : 207 fichiers générés, 12 dérivés ou faits main.

## Liste des fichiers

| Fichier | Graine | Prompt (début) |
|---|---|---|
| `assets/ships/hull/hull_shuttle.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/hull/hull_courier.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/hull/hull_tug.png` | 111 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/hull/hull_miner.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/hull/hull_cargo.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/hull/hull_fighter.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/hull/hull_yacht.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/hull/hull_explorer.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/engine/eng_putt.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/engine/eng_ion.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/engine/eng_twin.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/engine/eng_plasma.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/engine/eng_fusion.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/engine/eng_warp.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/cockpit/cock_box.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/cockpit/cock_bubble.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/cockpit/cock_visor.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/cockpit/cock_armored.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/cockpit/cock_lounge.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/cockpit/cock_crystal.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/wings/wing_stub.png` | 111 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/wings/wing_delta.png` | 444 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/wings/wing_swept.png` | 666 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/wings/wing_solar.png` | 111 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/wear/wear_rust.png` | 802 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/wear/wear_scratch.png` | 801 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/wear/wear_dent.png` | 801 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ships/wear/wear_scorch.png` | 801 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_01.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_01.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_02.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_02.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_03.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_03.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_04.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_04.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_05.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_05.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_06.png` | 111 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_06.png` | 111 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_07.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_07.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_08.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_08.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_09.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_09.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_10.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_10.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_11.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_11.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/client_12.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/client_12.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/staff_01.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/staff_01.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/staff_02.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/staff_02.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/staff_03.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/staff_03.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/staff_04.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/staff_04.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/staff_05.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/staff_05.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/staff_06.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/staff_06.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/staff_07.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/staff_07.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/staff_08.png` | 111 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/staff_08.png` | 111 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/staff_09.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/staff_09.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/staff_10.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/staff_10.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/story_bolt.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/story_bolt.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/story_odile.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/story_odile.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/story_lustre.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/story_lustre.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/story_inspector.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/portraits/small/story_inspector.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/workers/staff_01.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/workers/staff_02.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/workers/staff_03.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/workers/staff_04.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/workers/staff_05.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/workers/staff_06.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/workers/staff_07.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/workers/staff_08.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/workers/staff_09.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/workers/staff_10.png` | 202 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_credits.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_rp.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_rep.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_debt.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_day.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_garage.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_auction.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_staff.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_research.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_quests.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_sales.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_settings.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_scan.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_bid.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_repair.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_conceal.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_paint.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_sell.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_hire.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_check.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_lock.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_warning.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_star.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/ui_report.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/role_buyer.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/role_mechanic.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/role_bodyworker.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/role_seller.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/role_researcher.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/branch_atelier.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/branch_commerce.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/branch_perso.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/branch_rh.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/branch_diagnostic.png` | 111 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/branch_lieux.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/item_keel.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/item_heart.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/item_sail.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/item_star.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/item_compass.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_rust.png` | 111 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_dent.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_breach.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_misfire.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_plasma.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_fuel.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_nav.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_canopy.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_ai.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_wing.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_wiring.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_battery.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_air.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_gravity.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/def_toilet.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_polish.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_flames.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_horn.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_rack.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_baby.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_spoiler.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_neon.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_leather.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_minibar.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_shield.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_autopilot.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/opt_solar.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_at_1.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_at_2.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_at_3.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_at_4.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_at_5.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_at_6.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_at_7.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_co_1.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_co_2.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_co_3.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_co_4.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_co_5.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_co_6.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_co_7.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_pe_1.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_pe_2.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_pe_3.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_pe_4.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_pe_5.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_pe_6.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_pe_7.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_rh_1.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_rh_2.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_rh_3.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_rh_4.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_rh_5.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_rh_6.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_rh_7.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_di_1.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_di_2.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_di_3.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_di_4.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_di_5.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_di_6.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_di_7.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_li_1.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_li_2.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_li_3.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_li_4.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_li_5.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_li_6.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/icons/tech_li_7.png` | 101 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/backgrounds/garage.png` | 301 | detailed pixel art, 16-bit retro game background, crisp pixels, limited palette, full-screen game scene fillin… |
| `assets/backgrounds/loc_ferropolis.png` | 301 | detailed pixel art, 16-bit retro game background, crisp pixels, limited palette, full-screen landscape scene f… |
| `assets/backgrounds/loc_kryo7.png` | 302 | detailed pixel art, 16-bit retro game background, crisp pixels, limited palette, full-screen landscape scene f… |
| `assets/backgrounds/loc_nebula.png` | 302 | detailed pixel art, 16-bit retro game background, crisp pixels, limited palette, full-screen landscape scene f… |
| `assets/backgrounds/loc_tartarus.png` | 302 | detailed pixel art, 16-bit retro game background, crisp pixels, limited palette, full-screen landscape scene f… |
| `assets/backgrounds/loc_opalia.png` | 302 | detailed pixel art, 16-bit retro game background, crisp pixels, limited palette, full-screen landscape scene f… |
| `assets/ui/_panel_src.png` | 401 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |
| `assets/ui/_button_src.png` | 401 | pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark … |

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
