# CLAUDE.md — Clunker Cosmos

Jeu de gestion 2.5D (Steam) : garage orbital de vaisseaux d'occasion, vue en coupe, rendu 3D stylisé pré-calculé. **Pas un idle** :
rien n'avance jeu fermé, le temps se suspend fenêtre inactive ou après inactivité (réglages).
Godot **4.7.1 stable** + **GDScript typé** (avertissement `untyped_declaration` = erreur : tout doit être typé,
y compris les variables de boucle `for x: T in ...`). Renderer GL Compatibility, stretch `canvas_items` : texte
rastérisé à la résolution de la fenêtre ; images HD stockées à 4× leur taille logique (`UIKit.DETAIL`), affichées à
leur taille logique (filtrage linéaire + mipmaps, `UIKit.tex`). Résolution logique
**variable** (au moins 480×270) : fenêtre / k entier (`ViewScale`, réglage « Taille de l'interface »).
Multijoueur hors périmètre.

**Après un compactage de contexte : relire ce fichier puis `docs/PROGRESS.md`.**

## Commandes

| Action | Commande |
|---|---|
| Toutes les vérifications | `python tools/check_all.py` (doit finir par `ALL CHECKS PASSED`, exit 0) |
| Tests unitaires headless | `tools/run_tests.sh --suite=unit [--filter=xxx]` |
| Simulation 30 jours | `tools/run_tests.sh --suite=sim --days=30 --seed=7 --mode=classic` |
| Chapitres 1-2 scriptés | `tools/run_tests.sh --suite=story --max-days=90 --seed=11` |
| Validation des assets | `tools/run_tests.sh --suite=assets` |
| Générer l'art (ComfyUI sur :8188) | `.venv/Scripts/python.exe tools/gen_assets.py generate` puis `sheets`, `build` |
| Générer l'audio | `.venv/Scripts/python.exe tools/gen_audio.py all` (musiques ACE-Step via ComfyUI + bruitages synthétisés) |
| Police de symboles | `.venv/Scripts/python.exe tools/make_symbol_font.py` (sous-ensemble de Noto Sans Math) |
| Mesure des i/s | `godot --path . res://scenes/main.tscn -- --tour=perf --window=2560x1440` (##RESULT : i/s, 1 % bas, pire image, ouverture des écrans) |
| Captures d'écran | `python tools/screenshots.py [--window=2560x1440] [--ui-scale=2] [--only=garage,settings,tutorial,tooltip,resize]` (fenêtré, docs/screens/*.png en 1920×1080 par défaut) |
| Kit Steam | `.venv/Scripts/python.exe tools/make_trailer.py`, `python tools/screenshots.py --steam`, `.venv/Scripts/python.exe tools/steam_assets.py` → docs/steam/ (voir docs/STEAM_STORE.md) |
| Export Windows | `python tools/export_windows.py [--out=dossier] [--debug]` → `<Bureau>/Clunker Cosmos/` (exe + pck + ico, préréglage `export_presets.cfg`, modèles d'export 4.7.1 dans `%APPDATA%/Godot`, test de fumée du jeu exporté) |

Godot : `%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`
(localisé par `tools/godot.py`, sinon téléchargé dans `tools/godot/`). Python : `.venv` local (Pillow, numpy,
fontTools, imageio-ffmpeg) ; `tools/check_all.py` n'utilise que la stdlib et appelle `.venv` pour les étapes d'art
si présent. Nouvelle classe (`class_name`) : `godot --headless --path . --import` avant les tests.
L'éditeur Godot de l'utilisateur peut être ouvert sur le projet : ne jamais tuer ses processus.

## Architecture

- `scripts/core/` — **logique pure** (RefCounted, aucune dépendance aux nœuds), testable en headless :
  - `GameModel` : état complet + boucle horaire `advance_hour()` + API `act_*` (renvoient `{"ok", "reason", ...}`).
  - Systèmes statiques : `AuctionSystem`, `WorkshopSystem`, `MarketSystem`, `StaffSystem`, `ResearchSystem`,
    `QuestSystem`, `Valuation`, `ShipFactory`, `StaffLayout` (place des employés dans le garage),
    `SaveCodec` (versionnée + migrations), `Autopilot`.
  - Données : `Ship`/`ShipDefect`, `Employee`, `AuctionLot`, `Client` (to_dict/from_dict) ; `GameSettings`
    (réglages du joueur, `user://settings.cfg`).
  - `ContentDB` charge `data/*.json` ; les textes bilingues `{fr,en}` deviennent des clés (`part.<id>.name`…).
- `scripts/autoload/` — `Content` (ContentDB), `I18n` (TranslationServer FR/EN), `Game` (partie courante,
  temps réel, pauses automatiques, réglages, sauvegarde `user://saves/slot1.json`), `Audio` (bus Master/Music/SFX,
  playlists, bruitages ; inactif en headless).
- `scripts/ui/` + `scenes/` — interface construite en code (thème 9-slice, polices Barlow Semi Condensed et
  Lilita One + repli « Cosmos Symbols », curseur `CursorKit`). `MainUI.W/H/K` (statiques) = résolution logique
  et facteur actuels : ne jamais écrire 480×270 en dur, utiliser `size` ou `MainUI.W/H` ; les décors suivent
  leur propre échelle entière (`ViewScale.fit_scale/cover_scale`, scène du garage en coordonnées du décor).
  Visites automatiques `res://scenes/main.tscn -- --tour=smoke|screens|steam|trailer|capsules`
  (`tour.gd`, `trailer.gd`, `capsules.gd`, options `--window=LxH --ui-scale=k`) : `Game.persist=false` (jamais
  d'écriture de la sauvegarde ni des réglages du joueur), son coupé hors `trailer`, souris réelle ignorée hors `smoke`.
- `data/` — tout le contenu (JSON) : config d'équilibrage, pièces, défauts, personnalisation, espèces,
  personnel, lieux, arbre techno, histoire, quêtes, tutoriel, textes UI.
- `tests/` — `runner.tscn` (suites unit/sim/story/assets), `TestCase`, `tests/unit/test_*.gd`.
- `tools/` — pipeline Python (ComfyUI, `hd_art.py`, génération d'images et d'audio, captures, kit Steam, check_all).
- `art/` — manifestes (images, audio), composition du garage (`art/layout/`), palette des peintures, comparatifs ;
  `art/raw_hd/` est ignoré par git.
- `assets/` — sprites, musiques, bruitages, polices (ne pas éditer à la main : régénérés par les outils).

## Règles

- Temps : 1 h de jeu = `time.seconds_per_hour` s réelles ; jour = 24 h ; service des employés 8 h-18 h
  (+2 h avec « Équipe du soir »). Aucune progression hors ligne.
- Toute nouvelle mécanique : données dans `data/`, logique dans `scripts/core/`, test dans `tests/unit/`.
- Tous les textes visibles : clé + FR + EN (`data/ui_text.json` pour l'UI).
- Art : uniquement via ComfyUI local + `tools/hd_art.py` (style rendu 3D stylisé, voir `tools/asset_specs.py`) ; tracer dans
  `art/manifest.json`. Audio : ACE-Step 1.5 (MIT) via ComfyUI ou synthèse par code, tracé dans
  `art/audio_manifest.json`. Licence commerciale obligatoire ; aucune imitation d'artiste/studio/personnage existant.
- Décisions arbitraires → `docs/DECISIONS.md`. Avancement → `docs/PROGRESS.md`. Un commit par jalon.
- Ne rien modifier hors du projet (sauf modèles/custom nodes dans le dossier ComfyUI).
