# Décisions (choix faits en autonomie)

Format : décision — raison (option la plus simple quand il y avait un doute).

## Technique

1. **Godot 4.7.1 stable déjà installé** (Téléchargements) utilisé tel quel ; `tools/godot.py` le retrouve ou
   télécharge la même version dans `tools/godot/`.
2. **Renderer GL Compatibility** au lieu de Forward+/D3D12 du squelette — jeu 2D, meilleure compatibilité
   matérielle sur Steam. Jolt (3D) retiré.
3. **Stretch mode `viewport` + `scale_mode = integer`**, fenêtre 1440×810 (×3) — pixels parfaits.
   *(Remplacée par les n° 51 et 67 : rendu `canvas_items`, taille d'interface variable.)*
4. **Typage strict** : `untyped_declaration` passé en erreur → impossible d'oublier un type.
5. **Logique en classes statiques « systèmes » + objets de données RefCounted** (pas de références
   croisées entre RefCounted → pas de fuites de cycles), testable sans arbre de scènes.
6. **Temps discret à l'heure** (1 h de jeu = 4 s réelles à ×1 ; vitesses ×1/×2/×4). Le travail se fait
   pendant le service (8 h-18 h) ; le patron travaille 8 h-20 h quand le joueur est en ligne.
7. **Hors-ligne** : au chargement, le temps écoulé est simulé (plafond 24 h de jeu, +24 h avec « Veilleur de
   nuit ») ; le patron ne travaille pas hors ligne, les employés oui. Rapport affiché au retour.
   *(Remplacée par le n° 54 : plus aucune progression hors ligne.)*
8. **Sauvegarde JSON versionnée** (`save_version` = 2, migration v1→v2 testée) ; état du générateur
   aléatoire sauvegardé → reprise déterministe.
9. **Enchères par procuration** (second prix + incrément) : simple, juste et testable ; les PNJ montent
   progressivement jusqu'à leur maximum caché, calculé sur la valeur *réelle* (ils « savent » un peu).
10. **Textes bilingues inline dans le contenu** (`{"fr", "en"}`) convertis en clés de traduction au
    chargement : impossible d'oublier une langue (vérifié par les tests).
11. **Police Tiny5 (OFL)** en 8 px (16 px pour les titres) : seule candidate testée qui reste nette en 480×270
    avec tous les accents français (comparatif `art/compare/fonts.png`). *(Remplacée par le n° 51.)*
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

## Interface

29. **Une seule scène (`scenes/main.tscn`)**, tout le reste construit en code (`MainUI` + un `GameScreen` par
    écran). Les écrans se reconstruisent à chaque heure de jeu ou action (drapeau `dirty`), en conservant le
    défilement et jamais pendant un clic.
30. **Garage en coupe** : 3 baies par étage ; les baies 4-6 et 7-9 (agrandissements, recherche) apparaissent sur des
    mezzanines dessinées en code au-dessus du décor. La bande d'employés (portraits 24×24) n'est affichée que tant
    qu'il reste de la place (≤ 2 étages) ; l'écran Équipe montre toujours tout.
31. **Arbre techno en colonnes** (une branche par colonne, profondeur vers le bas) : plus lisible en 480×270 que
    des lignes horizontales où les voies se chevauchaient.
32. **Négociation à prix proposés** (−5 %, estimation, +8 %) plutôt qu'un champ de saisie : plus simple à la
    souris en basse résolution ; les commandes de quête se vendent au prix fixé par le client.
33. **Le temps est suspendu** pendant les dialogues et fenêtres modales (`Game.hold`), pas pendant la navigation.
34. **Captures et test de fumée par une « visite » intégrée** (`-- --tour=smoke|screens`) : la même partie de
    démonstration (mode Histoire, autopilote 14 jours, graine 20261) sert aux captures, au test headless de l'UI
    et à la vidéo promotionnelle.
35. **Portraits 24×24 dédiés**, réduits directement depuis l'image source (plus nets qu'un 48×48 divisé par deux).

36. **Boutons sans icône** : variation de thème `TextButton` aux marges élargies (sinon le texte mordait sur le
    cadre du 9-slice) ; titres de section posés directement sur le décor avec un bandeau sombre semi-opaque.

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

37. **Revue des planches avant sélection** (`art/review/*.png`) : graine retenue par asset dans
    `art/selection.json` ; les assets ratés sont refaits avec un prompt corrigé et de nouvelles graines
    (`RESEEDED` dans `tools/asset_specs.py`) : coque de remorqueur générée avec des roues, ailes générées comme
    des vaisseaux complets, deux portraits jugés trop proches de personnages connus (champignon à chapeau rouge
    à pois blancs, mécanicien à bandana) remplacés par des designs originaux.
38. **Ailes décrites comme des plaques** (« plaque triangulaire », « lame en parallélogramme », « panneau solaire ») :
    le mot *wing* faisait dessiner un vaisseau entier.
39. **Usure en décalcomanies** : taches dispersées générées sur fond blanc, détourées par les coins puis
    appliquées par le shader par blocs de 5×5 px selon un seuil de hachage (proportion = usure du vaisseau,
    type de tache choisi d'après les défauts). Les textures plein cadre donnaient des aplats peu lisibles.
40. **Moteurs dessinés à la verticale tournés de 90°** avant le test d'orientation ; la flamme est détectée sur
    les teintes 5-60° saturées et lumineuses (le bleu/violet des tuyères n'est plus pris pour une flamme).
41. **Icônes de lecture (pause, ×1, ×2, ×4) dessinées par script** dans la palette : symboles universels plus
    lisibles en 16×16 qu'une génération ; marquées « faites main » dans le manifeste.
42. **Icône de la branche Diagnostic régénérée** (scanner portatif) : le stéthoscope devenait invisible après
    quantification (contour sombre sur fond sombre) ; la variante ressemblant à une console de jeu portable
    a été écartée (trop proche d'un produit existant).

## Équilibrage

28. Départ : 8 000 ¢, dette 60 000 ¢ (2 500 ¢/semaine), réputation 30. Les PNJ misent 42-66 % de la valeur
    réelle de l'épave. Le jeu doit rester rentable pour un joueur raisonnable (simulation : >10 ventes/mois).

50. **Filet de sécurité économique** (`rescue` dans `data/config.json`) : sans vaisseau, sans mise en cours et à
    moins de 1 500 ¢, Galax-Auto prête 3 000 ¢ (ajoutés à la dette avec 15 % de frais, une fois par semaine au
    plus) ; dans le rouge avec un vaisseau en stock, un conseil « vendez un vaisseau » s'affiche. Sans cela, un
    joueur à court d'argent et sans vaisseau ne pouvait plus ni miser ni réparer : partie bloquée.

## Kit Steam

43. **Bande-annonce rendue par le jeu** (Movie Maker de Godot, `--fixed-fps 30`) : une séquence scénarisée
    (`scripts/ui/trailer.gd`) pilote la vraie interface (signaux des boutons) avec un faux curseur dessiné en
    pixels. Les images sont celles du viewport (480×270), agrandies ×4 au plus proche voisin : pixels nets et
    rendu déterministe, en FR et en EN. *(Texte désormais rastérisé en 1080p : n° 69.)*
44. **ffmpeg du paquet `imageio-ffmpeg` installé dans le venv** (rien hors du projet) ; H.264 High CRF 12,
    yuv420p BT.709 (le ×4 tombe sur la grille 2×2 du 4:2:0 : aucune bavure de couleur) ; piste AAC muette, car
    l'audio est hors périmètre (Steam lance de toute façon les vidéos sans le son). *(Remplacée par le n° 69 :
    son du jeu, AAC 192 kb/s.)*
45. **Parties mises en scène pour la vitrine** (vidéo et captures Steam) : garage agrandi et rempli, crédits
    ajoutés, mises automatiques de la démo retirées, technologies accordées comme une récompense de quête. Les
    écrans restent ceux du jeu, sans retouche. La souris réelle est ignorée pendant les visites (sinon des
    infobulles parasites apparaissaient à l'image).
46. **Capsules provisoires composées avec les assets du jeu** dans un SubViewport (taille de base × facteur
    entier) : logo Tiny5 à une taille multiple de 8, aucun autre texte (règles Steam), une épave d'origine à
    côté du même vaisseau remis à neuf pour résumer la boucle de jeu. *(Logo en Lilita One : n° 69.)*
47. **Icône du jeu = BOLT** (portrait existant) : `icon.svg` du projet remplacé par une version « pixel »
    (un rectangle par suite de pixels, net à toute taille) et `icon.ico` multi-tailles pour l'export Windows ;
    l'icône Godot par défaut ne convient pas à un jeu publié.
48. **Plein écran** (F11, Alt+Entrée, bouton des paramètres) mémorisé dans `user://settings.cfg` : attendu sur
    PC. Le rapport hors-ligne a une liste d'événements défilante et les fenêtres modales sont recentrées après
    mise en page (la vidéo a montré un rapport qui débordait de l'écran). *(Rapport hors-ligne supprimé : n° 54.)*
49. **Configuration requise déduite** des exigences de Godot 4.7 (rendu Compatibility, OpenGL 3.3) et du poids du
    jeu, à confirmer après le premier export : les modèles d'export s'installent hors du projet, donc aucun
    exécutable n'a été produit ici.

## Version 0.2 — demandes après le kit Steam

51. **Polices lisibles au lieu du pixel** (demande) : Barlow Semi Condensed Medium pour le texte, Lilita One pour
    le logo et les titres (OFL toutes deux, non modifiées). Rendu `canvas_items` : le texte est rastérisé à la
    résolution de la fenêtre (net à toute taille), le pixel art reste au plus proche voisin, à l'échelle entière.
52. **Repli de symboles « Cosmos Symbols »** : sous-ensemble (→ ● ★ ✓…) de Noto Sans Math, renommé, aux
    métriques de Barlow (`tools/make_symbol_font.py`) : avec la police complète, Godot agrandissait toutes les
    lignes (la hauteur de ligne est le maximum de la chaîne de repli).
53. **Nom « Clunker Cosmos »** (demande) : le dossier de données de Godot suit le nom du projet ; au premier
    lancement, la sauvegarde de l'ancien dossier (« Wreck & Resell ») est copiée, l'originale restant intacte.
54. **Jeu de gestion, pas un idle** (demande) : plus aucune simulation hors ligne (OfflineSim et rapport
    supprimés), la partie reprend exactement où elle était. Le temps se suspend aussi quand la fenêtre perd le
    focus et après 5 min sans souris ni clavier (réglables ; jamais pendant les visites automatiques).
55. **« Veilleur de nuit » devient « Équipe du soir »** (+2 h de service des employés, réparations +10 %) : les
    bonus hors ligne n'avaient plus de sens.
56. **Tutoriel en menu** (demande) : 12 pages courtes (`data/tutorial.json`) avec un aparté de BOLT, ouvert depuis
    l'écran titre, le bouton « ? » de la barre, les paramètres ou F1 ; aucun tutoriel imposé.
57. **Fenêtre Paramètres** commune à l'écran titre et à la partie : affichage, audio, langue, pauses automatiques,
    aide ; réglages dans `user://settings.cfg` (`GameSettings`, logique pure testée). Plein écran par défaut au
    premier lancement (demande).
58. **Infobulles riches de la barre du haut** (demande) : titre et explication avec les valeurs du moment
    (prochaine échéance de la dette, heures de service…), curseur « ? » sur les ressources.
59. **Musique** : ACE-Step 1.5 turbo (MIT) via ComfyUI avec les réglages officiels (8 étapes, cfg 1, euler/simple,
    shift 3 ; codes audio cfg 2, température 0,85, top_p 0,9), paroles `[Instrumental]`, -6 dB avant la
    sauvegarde FLAC (écrêtage 16 bits). Graine choisie automatiquement parmi 3 par morceau, faute d'écoute
    (critère dans `tools/gen_audio.py`, mesures dans le manifeste). Mastering -16 LUFS, crête ≤ -1 dBTP, OGG Vorbis.
60. **Stable Audio Open écarté** (licence plafonnée en revenus) : les 32 bruitages sont synthétisés par code
    (numpy, rendu identique à chaque exécution), niveaux calibrés par catégorie, un « bip de voix » par
    personnage joué avec une légère variation de hauteur.
61. **Audio côté jeu** : autoload `Audio` (bus Master, Music, SFX), playlists (titre ; atelier, trois pistes) en
    fondu enchaîné, jingle de victoire avec la musique atténuée de 18 dB. Coupé dans les tests et les visites
    (sauf la bande-annonce) et arrêté avant de quitter (sinon Godot signale des ressources audio non libérées).
62. **Humour dans les dialogues** (demande) : textes des quêtes et de l'histoire réécrits en FR et en EN, sans
    changer les faits ni les objectifs.
63. **Employés visibles au travail** (demande) : un personnage en pied (20×26 px, Z-Image, revue des planches) par
    portrait ; le rôle se lit à la place et à l'outil. Placement en logique pure (`StaffLayout`) : baie du
    vaisseau en cours, bureaux et labo de la mezzanine, coin pause pour les inactifs ; absents hors service
    (étiquette « Équipe en repos ») ; animation figée quand le jeu est en pause.
64. **Pixelisation des personnages** : réduction par moyenne puis palette, et remplissage des trous du masque
    (`pixelize.py`, options réservées à ces sprites de 26 px ; les autres assets restent identiques au pixel près).
65. **Hauteur des baies selon le nombre de rangées** (72/65/62 px) pour garder l'étage visible ; à 3 rangées, la
    bande de la mezzanine est recopiée au-dessus des baies.
66. **Curseur personnalisé** (demande) : flèche, main et « ? » dessinés en code avec la palette ; curseurs
    matériels (aucune latence) à la taille des pixels de l'interface (un cran en dessous au-delà de ×2).
67. **Taille de l'interface réglable** (demande : interface trop zoomée en 1440p) : la fenêtre est divisée par un
    facteur entier k (pixels d'écran par pixel d'interface) et la résolution logique vaut fenêtre / k, au moins
    480×270 (`ViewScale`, testé). Automatique : hauteur logique au plus 480 (853×480 en 1440p, 640×360 en
    1080p) ; dans les paramètres, de ×2 (texte de 16 px à l'écran) à l'échelle maximale, résolution affichée.
    Facteurs entiers uniquement : 9-slices et icônes restent nets. Recomposition après un redimensionnement de
    la fenêtre (une fois le geste terminé).
68. **Décors et vaisseaux à leur propre échelle entière** : la scène du garage (coordonnées du décor 480×270 :
    baies, vaisseaux, employés) est agrandie du plus grand nombre entier de pixels d'écran par pixel d'image qui
    tient ; plaques, cadre du patron et fiche restent à la taille de l'interface, par-dessus. Les autres fonds
    couvrent l'écran (rognés). Les écrans « liste + fiche » s'élargissent proportionnellement (lignes bornées pour
    rester lisibles), les candidats passent sur plusieurs colonnes, le graphe du labo s'étire ; les aperçus de
    vaisseaux et le menu de l'écran titre suivent l'échelle des décors quand l'interface est fine.
69. **Bande-annonce et visuels Steam** : la vidéo garde la mise en page 480×270 (interface ×4 en 1080p, lisible
    dans un petit lecteur) mais le texte est rastérisé en 1080p ; son du jeu (musique et bruitages) en AAC
    192 kb/s, H.264 CRF 14. Captures Steam et `docs/screens` en 1920×1080 avec la taille d'interface automatique
    (640×360 ×3), ce que voit un joueur en 1080p. Capsules rendues directement à la taille finale (logo Lilita One).
70. **Bords des panneaux continus** : les 9-slices des panneaux (quart miroité) ont une encoche au milieu de chaque
    bord ; étirée sur les panneaux larges des grandes résolutions, elle devenait un trou. Au chargement du thème,
    la partie étirée de chaque ligne et colonne de bord prend sa couleur la plus fréquente
    (`UIKit.seamless_image`, testé) ; coins et fichiers d'assets inchangés, boutons non concernés.
71. **Export Windows** (demande : exe dans un dossier du Bureau avec une icône) : modèles d'export 4.7.1 déjà
    installés dans `%APPDATA%/Godot` (rien téléchargé). Exe 64 bits en release + `.pck` séparé (format habituel
    pour Steam, moins de faux positifs antivirus qu'un pck intégré). Icône `icon.ico` multi-tailles intégrée par
    Godot (sans rcedit) et utilisée pour la barre des tâches (`windows_native_icon`), copiée aussi dans le dossier
    (raccourcis, icône du client Steam). Données JSON incluses explicitement, `build/` exclu ; tests laissés dans le
    pck (80 Ko). Version 0.1.0 conservée (identique aux captures). L'outil vérifie le jeu exporté (test de fumée).
72. **Passage en 2.5D** (demande : « tout en 2.5D, plus de pixel art ni de 8 bits, garder le thème spatial ») :
    rendu 3D stylisé **pré-calculé** (images Z-Image-Turbo au style « stylized 3D render », éclairage doux) plutôt
    que de vrais modèles 3D : l'interface, la logique, la mise en page en 480×270 logiques et l'assemblage des
    vaisseaux par ancres restent valables, et le jeu garde son renderer GL Compatibility. Des modèles 3D (TRELLIS 2
    est installé) auraient demandé de refaire l'assemblage, la peinture et l'éclairage de 24 pièces : écarté.
73. **Images HD à 4× leur taille logique** (`tools/hd_art.py`, `UIKit.DETAIL`) : détourage BiRefNet doux, réduction
    Lanczos en alpha prémultiplié (pas de halo), léger renforcement, marge d'un pixel logique. En jeu, `UIKit.tex`
    crée une `ImageTexture` avec mipmaps dont la taille est forcée à la taille logique : tout le code existant
    (tailles, ancres, TextureRect) fonctionne sans changement, et l'image reste nette jusqu'en 4K. Filtrage linéaire
    avec mipmaps par défaut, accrochage au pixel désactivé. En headless, substitut de la bonne taille.
74. **Garage restylé en img2img** depuis l'ancien décor (agrandi, flou de 1,5 px, débruitage 0,8) : la disposition
    (baies, mezzanine, mobilier) sert de coordonnées au code (baies, places des employés), elle devait rester.
    Avec plus de flou ou moins de débruitage, l'image restait floue ; avec plus de débruitage, la disposition
    bougeait. Composition gardée dans `art/layout/garage_layout.png`.
75. **Peinture par masque** : les coques et ailes sont générées en rouge ; un masque doux des pixels rouges
    (`<pièce>_paint.png`) est enregistré à côté et le shader y applique la rampe de la peinture selon la
    luminosité du rendu (ombrage gardé), en conservant les reflets blancs. Remplace le palette-swap ; les rampes des
    peintures (couleurs de `art/palette.json`) sont inchangées. Seuils bas (saturation 0,14) : sinon des taches
    rouges sombres restaient visibles après une peinture.
76. **Usure douce** : calques d'usure HD répétés sur la pièce, dosés par un bruit lissé (plus de blocs de 5 pixels)
    et mélangés à 60 % ; l'usure du vaisseau est atténuée (× 0,75) pour que les épaves restent lisibles.
77. **Profondeur** : ombre douce de chaque vaisseau sur le sol de sa baie (plus petite quand il monte), rebond
    continu des vaisseaux et des employés ; décors avec vignettage et poussières lumineuses ; parallaxe légère qui
    suit la souris sur les décors plein écran (pas au garage, dont la scène est posée exactement sur le décor, ni
    dans les visites automatiques). Les décors passent à une échelle continue (tenir ou couvrir l'écran).
78. **Interface lisse** : panneaux en verre sombre aux coins arrondis avec ombre portée, boutons arrondis
    (`StyleBoxFlat`), plus de 9-slices générés ; curseur vectoriel (formes rastérisées avec 16 échantillons par
    pixel) ; animations des employés en formes anticrénelées (outils, étincelles lumineuses, bulle de texte en
    Lilita One) ; symboles de lecture dessinés lissés. La palette de 32 couleurs n'est plus imposée aux images.
79. **Revue des planches 2.5D** : deux graines par asset (trois pour personnages et décors). Prompts corrigés
    après revue : cargo (sortait en baleine), aile en flèche (épée, puis avion entier), 8 icônes devenues des
    lettres dans un cube (prix, rouille, bosse, lustrage, panneau holographique, néon, cabine de peinture,
    permis glacé).
80. **Version 0.3.0** : changement visuel complet ; captures, kit Steam et export Windows régénérés.
81. **60 i/s garantis** (demande : « le jeu rame ») : mesure intégrée `--tour=perf` (synchro verticale coupée,
    2560×1440) : 870 à 1 400 i/s selon l'écran, pire image 5,7 ms, aucune image au-delà de 18 ms. Les à-coups
    venaient du premier affichage d'un écran (jusqu'à 54 ms : lecture des images HD depuis la carte graphique et
    calcul des mipmaps) et du curseur (230 ms au lancement). Les images de `assets/` sont désormais importées comme
    `Image` (décodage sur le processeur), préparées avec leurs mipmaps sur un thread de fond dès le lancement
    (`UIKit.warmup`) puis envoyées à la carte graphique par lots de 3 ms par image (`UIKit.pump_warmup`) :
    ouverture d'un écran ≤ 11 ms. Curseur : 3 × 3 échantillons, pixels loin des formes ignorés, images gardées
    en mémoire (97 ms une seule fois). La fenêtre « MovieWriter » de l'enregistrement de la bande-annonce est
    volontairement plus lente que le temps réel : ce n'est pas le jeu.
