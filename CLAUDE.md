# CLAUDE.md — Wreck & Resell (titre provisoire)

Jeu idle/gestion 2D pixel art (Steam) : garage orbital de vaisseaux d'occasion, vue en coupe.
Godot **4.7.1 stable** + **GDScript typé** (avertissement `untyped_declaration` = erreur : tout doit être typé,
y compris les variables de boucle `for x: T in ...`). Résolution 480×270, scaling entier, filtre Nearest,
renderer GL Compatibility. Audio et multijoueur hors périmètre.

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
| Captures d'écran | `python tools/screenshots.py` (lance le jeu fenêtré, écrit docs/screens/*.png) |

Godot : `%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`
(localisé par `tools/godot.py`, sinon téléchargé dans `tools/godot/`). Python : `.venv` local (Pillow, numpy) ;
`tools/check_all.py` n'utilise que la stdlib et appelle `.venv` pour les étapes d'art si présent.
L'éditeur Godot de l'utilisateur peut être ouvert sur le projet : ne jamais tuer ses processus.

## Architecture

- `scripts/core/` — **logique pure** (RefCounted, aucune dépendance aux nœuds), testable en headless :
  - `GameModel` : état complet + boucle horaire `advance_hour()` + API `act_*` (renvoient `{"ok", "reason", ...}`).
  - Systèmes statiques : `AuctionSystem`, `WorkshopSystem`, `MarketSystem`, `StaffSystem`, `ResearchSystem`,
    `QuestSystem`, `Valuation`, `ShipFactory`, `OfflineSim`, `SaveCodec` (versionnée + migrations), `Autopilot`.
  - Données : `Ship`/`ShipDefect`, `Employee`, `AuctionLot`, `Client` (to_dict/from_dict).
  - `ContentDB` charge `data/*.json` ; les textes bilingues `{fr,en}` deviennent des clés (`part.<id>.name`…).
- `scripts/autoload/` — `Content` (ContentDB), `I18n` (TranslationServer FR/EN), `Game` (partie courante,
  temps réel, sauvegarde `user://saves/slot1.json`, hors-ligne au chargement).
- `scripts/ui/` + `scenes/` — interface construite en code (thème 9-slice, police Tiny5).
- `data/` — tout le contenu (JSON) : config d'équilibrage, pièces, défauts, personnalisation, espèces,
  personnel, lieux, arbre techno, histoire, quêtes, textes UI.
- `tests/` — `runner.tscn` (suites unit/sim/story/assets), `TestCase`, `tests/unit/test_*.gd`.
- `tools/` — pipeline Python (ComfyUI, pixelize, génération, captures, check_all).
- `art/` — palette globale (32 couleurs), manifeste des assets, comparatifs ; `art/raw/` est ignoré par git.
- `assets/` — sprites finaux (ne pas éditer à la main : régénérés par `gen_assets.py build`).

## Règles

- Temps : 1 h de jeu = `time.seconds_per_hour` s réelles ; jour = 24 h ; service des employés 8 h-18 h.
- Toute nouvelle mécanique : données dans `data/`, logique dans `scripts/core/`, test dans `tests/unit/`.
- Tous les textes visibles : clé + FR + EN (`data/ui_text.json` pour l'UI).
- Art : uniquement via ComfyUI local + `tools/pixelize.py`, palette `art/palette.json` ; tracer dans
  `art/manifest.json`. Aucune imitation d'artiste/studio/personnage existant.
- Décisions arbitraires → `docs/DECISIONS.md`. Avancement → `docs/PROGRESS.md`. Un commit par jalon.
- Ne rien modifier hors du projet (sauf modèles/custom nodes dans le dossier ComfyUI).
