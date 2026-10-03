# Avancement — Clunker Cosmos

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
- [x] **J6 — Version 0.2** (demandes de l'utilisateur après le kit Steam) : polices lisibles (Barlow Semi
  Condensed, Lilita One) ; tutoriel (12 pages, F1) ; plein écran par défaut et fenêtre Paramètres ; musique
  (ACE-Step 1.5, 5 pistes) et 32 bruitages synthétisés, volumes ; humour dans les dialogues ; nom « Clunker
  Cosmos » ; jeu de gestion sans progression hors ligne (pauses automatiques) ; infobulles des ressources ;
  employés visibles au travail dans le garage ; curseur pixel art ; **taille de l'interface réglable**
  (résolution logique fenêtre / k : 853×480 en 1440p par défaut, jusqu'à 1280×720), décors à leur propre échelle
  entière, bords de panneaux continus. Kit Steam régénéré (bande-annonce de 1 min 10 s avec son, captures avec
  la nouvelle interface, capsules).
- [x] **J7 — Export Windows** (demande) : préréglage « Windows Desktop » (`export_presets.cfg`), icône `icon.ico`
  dans l'exe et la barre des tâches, `tools/export_windows.py` → `<Bureau>/Clunker Cosmos/` (`Clunker Cosmos.exe`
  109 Mo + `.pck` 11 Mo + `.ico`) ; le jeu exporté passe le test de fumée et s'affiche correctement en fenêtre.
- [x] **J8 — Version 0.3 : passage en 2.5D** (demande : plus de pixel art) : 205 images régénérées en rendu 3D
  stylisé (Z-Image-Turbo, 2 à 3 graines par asset, revue des planches, 11 prompts corrigés), stockées à 4× leur
  taille logique (`tools/hd_art.py`) et affichées lissées avec mipmaps (`UIKit.tex`) ; garage restylé en img2img
  (même disposition) ; peinture des vaisseaux par masque ; usure douce ; ombres des vaisseaux, parallaxe,
  vignettage et poussières ; interface lisse (panneaux arrondis, curseur vectoriel, animations anticrénelées).
  Captures, kit Steam, icône et export Windows régénérés. Dépôt public `github.com/ngoujon/clunker-cosmos`.

## État actuel

- `python tools/check_all.py` : `ALL CHECKS PASSED` (13 contrôles, exit 0).
- Tests headless : 147/147 tests unitaires (15 suites) ; simulation 30 j (graine 7, mode classique) : 54 ventes,
  0 erreur ; histoire (graine 11) : chapitres 1-2 bouclés au jour 8.
- Interface vérifiée en 1920×1080 (×3), 2560×1440 (×3 et ×2), 1600×900 et 1280×720 (redimensionnement) ; test de
  fumée sur toutes les tailles d'interface possibles.

## Prochaines étapes (hors périmètre de cette version)

1. Écouter les musiques générées (choisies par mesures automatiques) et ajuster les volumes si besoin.
2. Test de l'export Windows sur une configuration minimale, envoi Steamworks
   (voir `docs/STEAM_STORE.md`, section « Reste à faire »).
3. Succès et Steam Cloud (GodotSteam), éventuellement macOS / Linux / Steam Deck.
