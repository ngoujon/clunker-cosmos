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
- [x] **J2 — Interface** : écran titre (parade de vaisseaux, Histoire / Classique, FR/EN), garage en coupe
  (baies, mezzanine, coup de main, détail avec réparer / maquiller / peindre / options / vendre), enchères
  (5 lieux, scan, mises par procuration, maximum conseillé), ventes (clients, critères, offres, contre-offres),
  équipe (postes, règles de priorité, embauche), labo (graphe de 42 nœuds), quêtes + journal, bureau
  (finances, dette, agrandissement, politique, automatisation, rapport du jour), dialogues (machine à écrire),
  rapport hors-ligne, toasts d'événements. Visite automatique `--tour=smoke|screens` pour les tests et captures.
- [x] **J3 — Art final** : 197 images Z-Image-Turbo retenues après revue des planches (graines dans
  `art/selection.json`), post-traitées en palette de 32 couleurs ; vaisseaux composés par ancres ; shader
  `ship_part.gdshader` (peinture par palette-swap + calque d'usure) ; manifeste et divulgation IA à jour.
- [x] **J4 — Vérifications** : `tools/check_all.py` → `ALL CHECKS PASSED` (11 contrôles), 9 captures du vrai jeu
  dans `docs/screens/` relues et corrigées, README, GDD, DECISIONS, MODEL_LICENSES, AI_DISCLOSURE.
- [x] **J5 — Kit Steam** (demande ajoutée par l'utilisateur) : bande-annonce FR et EN rendue par le jeu
  (`docs/steam/trailer_fr.mp4`, `trailer_en.mp4` : 1 min 08 s, 1920×1080, H.264), 9 captures 1920×1080 par
  langue, capsules et icônes provisoires, `docs/STEAM_STORE.md` (fiche FR/EN, configuration requise, langues,
  tags, divulgation IA, reste à faire). Ajouts au jeu : plein écran (F11), icône BOLT, rapport hors-ligne borné.

## État actuel

- `python tools/check_all.py` : 12/12 contrôles (dont le kit Steam), `ALL CHECKS PASSED`, code de sortie 0.
- Tests headless : 120/120 (11 suites). Simulation 30 j (graine 7, mode classique) : 54 ventes, résultat
  d'exploitation 327 752 ¢, 0 erreur. Histoire (graine 11) : chapitres 1 et 2 bouclés au jour 8.
- Assets : 180 fichiers validés (palette de 32 couleurs), 209 entrées de manifeste dont 197 générées.

## Prochaines étapes (hors périmètre de cette version)

1. Audio (musique, bruitages) puis bande-annonce sonorisée.
2. Export Windows (modèles d'export Godot), test sur configuration minimale, envoi Steamworks
   (voir `docs/STEAM_STORE.md`, section « Reste à faire »).
3. Succès et Steam Cloud (GodotSteam), éventuellement macOS / Linux / Steam Deck.
