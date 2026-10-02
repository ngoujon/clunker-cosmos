# Licences des modèles et ressources tierces

Règle du projet : **seuls des modèles dont la licence autorise l'usage commercial des images produites** ont été
téléchargés (Hugging Face) et utilisés localement via ComfyUI. Aucun modèle n'est redistribué avec le jeu : seules
les images générées puis post-traitées (`assets/`) sont livrées. La liste machine des modèles est dans
`comfy/models.json` ; la traçabilité de chaque image (prompt, graine, workflow) dans `art/manifest.json`.

## Modèle retenu pour tous les assets du jeu

| Fichier | Rôle | Licence | Usage commercial des sorties | Source |
|---|---|---|---|---|
| `z_image_turbo_bf16.safetensors` | Z-Image-Turbo (diffusion, 6B) | Apache-2.0 | Oui | https://huggingface.co/Comfy-Org/z_image_turbo (modèle d'origine : Tongyi-MAI/Z-Image-Turbo) |
| `qwen_3_4b.safetensors` | Encodeur de texte Qwen3-4B (pour Z-Image) | Apache-2.0 | Oui | https://huggingface.co/Comfy-Org/z_image_turbo |
| `ae.safetensors` | Autoencodeur (VAE) FLUX.1 utilisé par Z-Image | Apache-2.0 (dépôt FLUX.1-schnell) | Oui | https://huggingface.co/Comfy-Org/z_image_turbo |
| `birefnet.safetensors` | BiRefNet, détourage (nœud `RemoveBackground`) | MIT | Oui | https://huggingface.co/Comfy-Org/BiRefNet |

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
| Police **Tiny5** (Stefan Schmidt) | SIL Open Font License 1.1 — usage commercial et embarqué autorisés | `assets/fonts/Tiny5-Regular.ttf`, licence jointe `assets/fonts/OFL-Tiny5.txt` |
| Moteur **Godot 4.7.1** | MIT | non redistribué dans le dépôt (mention de licence à inclure dans le jeu exporté) |
| Palette de 32 couleurs | création du projet | `art/palette.json` |

## Logiciels utilisés (non distribués)

ComfyUI Desktop (GPL-3.0, outil local), Python 3.13 + Pillow (MIT-CMU) + NumPy (BSD-3) dans `.venv`.
Les sorties d'un outil GPL ne sont pas soumises à la GPL.
