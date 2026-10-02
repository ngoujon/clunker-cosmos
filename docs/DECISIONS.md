# Décisions (choix faits en autonomie)

Format : décision — raison (option la plus simple quand il y avait un doute).

## Technique

1. **Godot 4.7.1 stable déjà installé** (Téléchargements) utilisé tel quel ; `tools/godot.py` le retrouve ou
   télécharge la même version dans `tools/godot/`.
2. **Renderer GL Compatibility** au lieu de Forward+/D3D12 du squelette — jeu 2D, meilleure compatibilité
   matérielle sur Steam. Jolt (3D) retiré.
3. **Stretch mode `viewport` + `scale_mode = integer`**, fenêtre 1440×810 (×3) — pixels parfaits.
4. **Typage strict** : `untyped_declaration` passé en erreur → impossible d'oublier un type.
5. **Logique en classes statiques « systèmes » + objets de données RefCounted** (pas de références
   croisées entre RefCounted → pas de fuites de cycles), testable sans arbre de scènes.
6. **Temps discret à l'heure** (1 h de jeu = 4 s réelles à ×1 ; vitesses ×1/×2/×4). Le travail se fait
   pendant le service (8 h-18 h) ; le patron travaille 8 h-20 h quand le joueur est en ligne.
7. **Hors-ligne** : au chargement, le temps écoulé est simulé (plafond 24 h de jeu, +24 h avec « Veilleur de
   nuit ») ; le patron ne travaille pas hors ligne, les employés oui. Rapport affiché au retour.
8. **Sauvegarde JSON versionnée** (`save_version` = 2, migration v1→v2 testée) ; état du générateur
   aléatoire sauvegardé → reprise déterministe.
9. **Enchères par procuration** (second prix + incrément) : simple, juste et testable ; les PNJ montent
   progressivement jusqu'à leur maximum caché, calculé sur la valeur *réelle* (ils « savent » un peu).
10. **Textes bilingues inline dans le contenu** (`{"fr", "en"}`) convertis en clés de traduction au
    chargement : impossible d'oublier une langue (vérifié par les tests).
11. **Police Tiny5 (OFL)** en 8 px (16 px pour les titres) : seule candidate testée qui reste nette en 480×270
    avec tous les accents français (comparatif `art/compare/fonts.png`).
12. **UI construite en code** (pas de .tscn par écran) : plus simple à maintenir et à tester.
13. **Quêtes principales seulement en mode Histoire** ; les quêtes secondaires (commandes) existent dans les
    deux modes, sont proposées et jamais obligatoires.
14. **Dette envers Galax-Auto dans les deux modes** (pression économique), échéance hebdomadaire prélevée
    automatiquement ; en cas d'impayé : pénalité + réputation, jamais de game over.
15. **Effectif temporairement au-delà du plafond** autorisé uniquement pour les employés offerts par une
    quête (sinon la récompense serait perdue) ; l'embauche reste bloquée tant qu'on est au plafond.
16. **Épave offerte par quête** livrée directement au garage même s'il est plein (idem).
17. **Lots spéciaux de l'Aurore** : remis aux enchères chaque jour tant que le fragment n'est pas obtenu,
    prix réduit et concurrence PNJ adoucie pour ne jamais bloquer l'histoire.
18. **Défauts dangereux non dissimulables** (fuite de plasma, recycleur d'air) : ils doivent être réparés ou
    déclarés.
19. **Politique de l'atelier** (honnête / pragmatique / requin) appliquée automatiquement par les mécaniciens,
    avec décision manuelle par défaut possible (réparer / maquiller / déclarer).

## Art

20. **Pistes comparées** sur les mêmes prompts et graines (`tools/compare_models.py`, planche
    `art/compare/sheet.png`) : SDXL base + LoRA pixel-art-xl, FLUX.1-schnell (fp8), Z-Image-Turbo, Qwen-Image 2512.
    **Retenu : Z-Image-Turbo** — pixel art le plus propre et cohérent (aplats, contours épais, bon respect des
    prompts) et ~6-10 s/image ; Qwen-Image est comparable mais ~60 s/image ; SDXL+LoRA suit mal les prompts
    (moteur vertical, outils incohérents) ; FLUX-schnell produit des objets trop petits et moins « pixel ».
    Avec des prompts « plein cadre », Z-Image fait aussi de bons décors (`art/compare/z_bg_sheet.png`) →
    un seul modèle pour tout = cohérence maximale.
21. **Palette unique de 32 couleurs conçue pour le projet** (aucune palette connue copiée), dont 3 couleurs
    « apprêt » réservées aux zones peignables (shader palette-swap).
22. **Réduction « nearest » par vote majoritaire** : échantillonnage nearest à 4× la taille cible puis couleur de
    palette majoritaire par cellule — pas de mélange ni de couleur nouvelle, plus robuste qu'un seul
    échantillon par pixel.
23. **Zones peignables** : coques et ailes sont générées avec des panneaux rouges ; `pixelize.py` remappe ces
    pixels (par teinte) sur la rampe « apprêt » ; le shader les remplace en jeu par la peinture choisie.
24. **Points d'ancrage calculés depuis l'alpha** (vaisseaux orientés vers la droite) et stockés dans
    `assets/ships/anchors.json`.
25. **Moteurs retournés automatiquement** si la flamme est à droite (heuristique de couleurs chaudes).
26. **Icônes 16×16** générées une par une (une graine) ; portraits 48×48 ; fonds 480×270 ; UI 9-slice dérivée
    de deux sources générées (quart miroité pour une symétrie parfaite, variantes par décalage de luminance
    dans la palette).
27. **Images brutes non versionnées** (`art/raw/`, ~centaines de Mo) : reproductibles via le manifeste
    (prompt, graine, workflow).

## Équilibrage

28. Départ : 8 000 ¢, dette 60 000 ¢ (2 500 ¢/semaine), réputation 30. Les PNJ misent 42-66 % de la valeur
    réelle de l'épave. Le jeu doit rester rentable pour un joueur raisonnable (simulation : >10 ventes/mois).
