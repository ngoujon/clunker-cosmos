# Avancement — Wreck & Resell

## Jalons

- [x] **J0 — Environnement** : Godot 4.7.1 (headless OK), ComfyUI Desktop v0.37.1 (RTX 4070 Ti SUPER 16 Go,
  port 8188), venv Python (Pillow, numpy), modèles téléchargés (FLUX.1-schnell fp8, Z-Image-Turbo, Qwen-Image 2512).
- [x] **J1 — Logique + contenu + tests** : moteur complet en GDScript typé (enchères, atelier, ventes/SAV/contrôles,
  RH, arbre techno, quêtes, sauvegarde versionnée, hors-ligne, autopilote), contenu JSON FR/EN (8 coques,
  6 moteurs, 6 cockpits, 4 ailes, 15 défauts, 12 options, 12 peintures, 12 espèces, 5 rôles, 14 traits,
  5 lieux, 42 nœuds techno, 23 quêtes principales sur 5 chapitres + 2 fins, 18 quêtes secondaires),
  113 tests headless, simulation 30 jours, chapitres 1-2 scriptés.
- [x] **J1b — Pipeline art** : workflows API (4 pistes), client HTTP, validation `/object_info`, comparatif,
  `pixelize.py`, `gen_assets.py` (generate/sheets/build/placeholders/validate), placeholders.
- [ ] **J2 — Interface** : écrans garage (vue en coupe), enchères, RH, arbre (graphe), journal de quêtes,
  ventes, dialogues, rapport du jour / hors-ligne, menu de nouvelle partie, FR/EN.
- [ ] **J3 — Art final** : génération Z-Image, revue des planches, sélection, build, shader palette-swap + usure.
- [ ] **J4 — Vérifications** : `tools/check_all.py`, captures `docs/screens/`, README, GDD, finitions.

## État actuel

- Tests : 113/113. Simulation 30 j (graine 7) : 54 ventes, résultat d'exploitation > 0, 0 erreur.
  Histoire (graine 11) : chapitres 1 et 2 bouclés en 8 jours de jeu.
- Génération des 175 assets (238 images) lancée avec Z-Image-Turbo.

## Prochaines étapes

1. UI complète (thème, écrans) avec les placeholders.
2. Revue des planches d'art (`art/review/*.png`), choix des graines (`art/selection.json`), `build`.
3. `tools/check_all.py` + `tools/screenshots.py`, captures regardées et corrigées.
4. README, GDD, licences, divulgation IA.
