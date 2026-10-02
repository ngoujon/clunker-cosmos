# Licences des modèles et ressources tierces

Règle du projet : **seuls des modèles dont la licence autorise l'usage commercial des sorties produites** ont été
téléchargés (Hugging Face) et utilisés localement via ComfyUI. Aucun modèle n'est redistribué avec le jeu : seules
les images et musiques générées puis post-traitées (`assets/`) sont livrées. La liste machine des modèles est dans
`comfy/models.json` ; la traçabilité de chaque image (prompt, graine, workflow) dans `art/manifest.json`, celle de
chaque musique et bruitage dans `art/audio_manifest.json`.

## Modèle retenu pour tous les assets du jeu

| Fichier | Rôle | Licence | Usage commercial des sorties | Source |
|---|---|---|---|---|
| `z_image_turbo_bf16.safetensors` | Z-Image-Turbo (diffusion, 6B) | Apache-2.0 | Oui | https://huggingface.co/Comfy-Org/z_image_turbo (modèle d'origine : Tongyi-MAI/Z-Image-Turbo) |
| `qwen_3_4b.safetensors` | Encodeur de texte Qwen3-4B (pour Z-Image) | Apache-2.0 | Oui | https://huggingface.co/Comfy-Org/z_image_turbo |
| `ae.safetensors` | Autoencodeur (VAE) FLUX.1 utilisé par Z-Image | Apache-2.0 (dépôt FLUX.1-schnell) | Oui | https://huggingface.co/Comfy-Org/z_image_turbo |
| `birefnet.safetensors` | BiRefNet, détourage (nœud `RemoveBackground`) | MIT | Oui | https://huggingface.co/Comfy-Org/BiRefNet |

## Audio — ACE-Step 1.5 turbo (musique)

| Fichier | Rôle | Licence | Usage commercial des sorties | Source |
|---|---|---|---|---|
| `ace_step_1.5_turbo_aio.safetensors` | ACE-Step 1.5 turbo, checkpoint « tout-en-un » (DiT turbo, LM 5 Hz, encodeur de texte, VAE audio ; 10,0 Go) | **MIT** (poids et code ACE-Step 1.5, Copyright (c) 2026 ACEStep) ; reconditionnement Comfy-Org **Apache-2.0** | Oui, sans plafond de revenus | https://huggingface.co/Comfy-Org/ace_step_1.5_ComfyUI_files (poids officiels https://huggingface.co/ACE-Step/Ace-Step1.5, code https://github.com/ace-step/ACE-Step-1.5) |

Les cinq musiques du jeu (menu, trois ambiances d'atelier, jingle) sont pré-générées localement (workflow
`comfy/workflows/ace_step15_music.json`, script `tools/gen_audio.py`). Recommandations des auteurs suivies : invites
de style génériques uniquement (aucun artiste, œuvre, jeu ou film cité), musiques purement instrumentales, usage
d'IA déclaré dans `docs/AI_DISCLOSURE.md`.

`stable-audio-open-1.0.safetensors` est présent dans le dossier ComfyUI mais **n'est pas utilisé** : la Stability AI
Community License limite l'usage commercial gratuit aux structures sous un plafond de revenus annuels (licence
entreprise au-delà), ce qui ne respecte pas l'exigence de licence commerciale du projet. Les bruitages sont
synthétisés par code (`tools/sfx_synth.py`, numpy), sans aucun modèle ni échantillon tiers.

## Modèles évalués puis écartés (comparatif `art/compare/sheet.png`, voir DECISIONS.md n° 20)

Aucune image de ces pistes n'est utilisée dans le jeu ; ils ne servent qu'à la comparaison.

| Fichier | Rôle | Licence | Usage commercial des sorties | Source |
|---|---|---|---|---|
| `sd_xl_base_1.0.safetensors` | Stable Diffusion XL base 1.0 | CreativeML Open RAIL++-M | Oui (avec restrictions d'usage de la licence) | https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0 |
| `pixel-art-xl.safetensors` | LoRA « pixel-art-xl » pour SDXL | CreativeML Open RAIL-M | Oui (avec restrictions d'usage de la licence) | https://huggingface.co/nerijs/pixel-art-xl |
| `flux1-schnell-fp8.safetensors` | FLUX.1-schnell (fp8) | Apache-2.0 | Oui | https://huggingface.co/Comfy-Org/flux1-schnell (modèle d'origine : black-forest-labs/FLUX.1-schnell) |
| `qwen_image_2512_fp8_e4m3fn.safetensors` | Qwen-Image 2512 (fp8) | Apache-2.0 | Oui | https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI |
| `qwen_2.5_vl_7b_fp8_scaled.safetensors` | Encodeur Qwen2.5-VL 7B (pour Qwen-Image) | Apache-2.0 | Oui | https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI |
| `qwen_image_vae.safetensors` | VAE de Qwen-Image | Apache-2.0 | Oui | https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI |

FLUX.1-**dev** (licence non commerciale) a été volontairement exclu.

## Autres ressources

| Ressource | Licence | Fichier |
|---|---|---|
| Police **Barlow Semi Condensed** Medium (The Barlow Project Authors) — textes | SIL Open Font License 1.1 — usage commercial et embarqué autorisés | `assets/fonts/BarlowSemiCondensed-Medium.ttf`, licence `assets/fonts/OFL-BarlowSemiCondensed.txt` |
| Police **Lilita One** (Juan Montoreano, nom réservé « Lilita ») — titres et logo, non modifiée | SIL Open Font License 1.1 | `assets/fonts/LilitaOne-Regular.ttf`, licence `assets/fonts/OFL-LilitaOne.txt` |
| Police **Cosmos Symbols** — sous-ensemble de 22 symboles de **Noto Sans Math** (The Noto Project Authors) aux métriques réalignées (`tools/make_symbol_font.py`), renommé comme l'OFL le demande pour une version modifiée | SIL Open Font License 1.1 | `assets/fonts/CosmosSymbols.ttf`, licence `assets/fonts/OFL-CosmosSymbols.txt` ; source `art/fonts_src/` (non livrée) |
| Polices sources : https://github.com/google/fonts (dossiers `ofl/barlowsemicondensed`, `ofl/lilitaone`, `ofl/notosansmath`) | — | — |
| Moteur **Godot 4.7.1** | MIT | non redistribué dans le dépôt (mention de licence à inclure dans le jeu exporté) |
| Palette de 32 couleurs | création du projet | `art/palette.json` |

## Logiciels utilisés (non distribués)

ComfyUI Desktop (GPL-3.0, outil local), Python 3.13 + Pillow (MIT-CMU) + NumPy (BSD-3) + fontTools (MIT) +
imageio-ffmpeg (BSD-2, binaire ffmpeg LGPL/GPL utilisé comme outil d'encodage) dans `.venv`.
Les sorties d'un outil GPL ne sont pas soumises à la GPL.
