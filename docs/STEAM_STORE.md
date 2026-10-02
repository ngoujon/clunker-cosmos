# Kit Steam — Wreck & Resell *(titre provisoire)*

Tout ce qu'il faut pour remplir la fiche magasin Steam : fichiers prêts à envoyer, textes FR/EN à copier,
configuration requise, langues, tags, divulgation IA, et la liste de ce qui reste à faire avant la publication.

> Les tailles d'images et règles citées sont celles de Steamworks au moment de la rédaction (formats des
> capsules mis à jour en 2024). Vérifiez-les dans Steamworks au moment de l'envoi.

## 1. Fichiers fournis

| Fichier | Usage sur Steam | Caractéristiques |
|---|---|---|
| `docs/steam/trailer_fr.mp4` | Bande-annonce (version française) | 1 min 08 s, 1920×1080, H.264 High, 30 i/s, BT.709, piste AAC muette, 6,6 Mo |
| `docs/steam/trailer_en.mp4` | Bande-annonce (version anglaise) | idem, textes en anglais |
| `docs/steam/screenshots/en/01…09.png` | Captures d'écran (série principale) | 9 captures 1920×1080 (16:9), jeu en anglais |
| `docs/steam/screenshots/fr/01…09.png` | Captures en français (fiche localisée) | les mêmes scènes, jeu en français |
| `docs/steam/capsules/header_capsule_920x430.png` | Capsule d'en-tête (*Header Capsule*) | 920×430 |
| `docs/steam/capsules/small_capsule_462x174.png` | Petite capsule (*Small Capsule*) | 462×174 |
| `docs/steam/capsules/main_capsule_1232x706.png` | Capsule principale (*Main Capsule*) | 1232×706 |
| `docs/steam/capsules/vertical_capsule_748x896.png` | Capsule verticale (*Vertical Capsule*) | 748×896 |
| `docs/steam/capsules/page_background_1438x810.png` | Fond de page (facultatif) | 1438×810, sans texte |
| `docs/steam/capsules/library_capsule_600x900.png` | Bibliothèque : capsule | 600×900 |
| `docs/steam/capsules/library_header_920x430.png` | Bibliothèque : en-tête | 920×430 |
| `docs/steam/capsules/library_hero_3840x1240.png` | Bibliothèque : image héros | 3840×1240, sans texte ni logo |
| `docs/steam/capsules/library_logo_1280x176.png` | Bibliothèque : logo | 1280×176, PNG transparent |
| `docs/steam/capsules/community_icon_184x184.png` | Icône de communauté | 184×184 (BOLT, l'IA du garage) |
| `docs/steam/capsules/icon.ico`, `icon_256x256.png` | Icône du client / de l'exécutable Windows | 16 à 256 px |

Tous ces visuels sortent **du vrai jeu** : la vidéo et les captures sont rendues par Godot (aucune retouche),
les capsules sont composées avec les assets du jeu (décors, vaisseaux peints par le shader du jeu, police Tiny5)
et agrandies au plus proche voisin, sans flou. Les capsules sont des **versions provisoires** propres et
conformes (logo lisible, aucun autre texte) ; un graphiste pourra les remplacer.

Régénérer le kit :

```
.venv/Scripts/python.exe tools/make_trailer.py      # vidéos FR + EN (Movie Maker de Godot + ffmpeg)
python tools/screenshots.py --steam                 # captures 1920×1080 FR + EN
.venv/Scripts/python.exe tools/steam_assets.py      # capsules, icônes
```

## 2. Informations générales

| Champ | Valeur |
|---|---|
| Nom | Wreck & Resell (provisoire — vérifier la disponibilité du nom et des marques) |
| Genres Steam | Simulation, Stratégie, Occasionnel, Indépendant |
| Type | Gestion / idle, solo, mode Histoire facultatif ou mode Classique |
| Développeur / éditeur | *à compléter* |
| Date de sortie | *à définir* (« Bientôt disponible » / *Coming soon*) |
| Prix | *à définir* |
| Plateforme | Windows 64 bits (macOS et Linux possibles avec Godot, non testés) |
| Moteur | Godot 4.7.1 (licence MIT), rendu « Compatibility » (OpenGL 3.3) |
| Contrôles | Souris (obligatoire) + raccourcis clavier (Espace : pause, 1-3 : vitesse, Échap : menu, F11 ou Alt+Entrée : plein écran, F12 : capture) ; pas de manette |
| Affichage | fenêtré 1440×810 ou plein écran (mémorisé) ; image 480×270 agrandie d'un facteur entier, bandes noires si besoin |
| Steam Deck | non testé (souris nécessaire : jouable a priori au pavé tactile, sans garantie) |
| Connexion Internet | non requise (aucune donnée collectée) |
| Fonctions Steam | aucune pour l'instant (succès, Steam Cloud, cartes à échanger : à ajouter, par ex. avec GodotSteam) |
| Sauvegarde | locale, versionnée, sauvegarde automatique ; progression hors ligne au retour |
| Audio | **aucun pour l'instant** (hors périmètre de cette version) |

## 3. Langues

| Langue | Interface | Audio complet | Sous-titres |
|---|:-:|:-:|:-:|
| Français | ✔ | — | — |
| Anglais (English) | ✔ | — | — |

- Tous les textes sont traduits : interface, dialogues, quêtes, journal, descriptions. Changement de langue à
  l'écran titre ou dans les paramètres.
- Le jeu n'a ni voix ni son : ne cochez ni « Audio complet » ni « Sous-titres ».
- La fiche peut être en anglais (langue par défaut) avec une traduction française : textes ci-dessous.
  Deux versions de la bande-annonce et des captures sont fournies : la série anglaise pour la fiche par défaut,
  la série française pour la fiche localisée (ou pour vos réseaux).

## 4. Configuration requise (Windows)

| | Minimale | Recommandée |
|---|---|---|
| Système | Windows 10 64 bits | Windows 10 / 11 64 bits |
| Processeur | 64 bits avec SSE4.2, 2 cœurs à 2 GHz | 4 cœurs à 2,5 GHz |
| Mémoire vive | 2 Go | 4 Go |
| Graphismes | compatible OpenGL 3.3 (Intel HD Graphics 4000, NVIDIA GeForce GT 630, AMD Radeon HD 5570) | carte de 2015 ou plus récente (Intel UHD Graphics 620, NVIDIA GeForce GTX 750, AMD Radeon R7 260) |
| DirectX | version 11 (Godot peut basculer sur Direct3D 11 via ANGLE si le pilote OpenGL est absent) | version 11 |
| Stockage | 200 Mo d'espace disponible | 200 Mo d'espace disponible |
| Écran | 1280×720 | 1920×1080 (image ×4 exacte) |
| Notes | souris requise ; aucune connexion requise | |

Ces valeurs viennent de la configuration du moteur (Godot 4.7, rendu Compatibility) et du poids du jeu
(quelques Mo de contenu + ≈ 100 Mo de moteur une fois exporté) : le jeu est très léger. **À confirmer** sur
une machine modeste après le premier export Windows.

Textes prêts à coller dans Steamworks :

```
MINIMUM — OS: Windows 10 64-bit | Processor: 64-bit dual core 2 GHz with SSE4.2 | Memory: 2 GB RAM |
Graphics: OpenGL 3.3 compatible (Intel HD Graphics 4000 / GeForce GT 630 / Radeon HD 5570) |
DirectX: Version 11 | Storage: 200 MB available space | Additional notes: Mouse required. No audio yet.

RECOMMENDED — OS: Windows 10/11 64-bit | Processor: quad core 2.5 GHz | Memory: 4 GB RAM |
Graphics: Intel UHD Graphics 620 / GeForce GTX 750 / Radeon R7 260 | DirectX: Version 11 |
Storage: 200 MB available space | Additional notes: 1920×1080 display for pixel-perfect ×4 scaling.
```

## 5. Textes de la fiche

### Description courte (≤ 300 caractères)

**FR (276 caractères)** —
Héritez d'un garage orbital criblé de dettes : achetez des épaves aux enchères, réparez-les (ou maquillez leurs défauts…), repeignez-les et revendez-les à des clients aliens exigeants. Embauchez une équipe excentrique qui fait tourner l'atelier, même quand vous n'êtes pas là.

**EN (224 characters)** —
Inherit a debt-ridden orbital garage: buy wrecks at auction, fix them (or hide their flaws…), repaint them and resell them to picky alien customers. Hire a quirky crew that keeps the workshop running, even while you're away.

### « À propos du jeu » — EN (balises Steam)

```
[h2]Your aunt's orbital garage is yours... and so is her debt[/h2]
Aunt Odile, a legendary mechanic, has vanished, leaving you an orbital garage, a sarcastic onboard AI named BOLT and a 60,000-credit debt to Galax-Auto. To keep the keys, you'll have to do what she did best: turn space wrecks into great deals.

[h2]Buy. Fix. Pimp. Sell.[/h2]
[list]
[*][b]Buy[/b] wrecks at auction across 5 locations. Their condition is partly hidden: pay for a scan... or take your chances.
[*][b]Fix[/b] their defects, or [b]hide them[/b] to sell higher, at the risk of warranty claims, a ruined reputation and surprise inspections.
[*][b]Customize[/b] them: 12 paint jobs, 12 options and more than 1,000 combinations of hulls, engines, cockpits and wings.
[*][b]Sell[/b] to alien customers from 12 species, each with a budget and very specific tastes. Haggle, accept counter-offers, fulfill special orders.
[*][b]Reinvest[/b]: expand the garage and research 42 technologies across 6 branches.
[/list]

[h2]A workshop that runs itself[/h2]
Hire buyers, mechanics, body artists, salespeople and researchers from a pool that changes every day. Each one has a level, personality traits, morale and fatigue. Assign stations and priority rules, then watch the workshop automate itself. It even keeps working while you're away, with a detailed report when you come back.

[h2]An optional story[/h2]
Story mode: 5 chapters, 2 endings, the hunt for the 5 pieces of the legendary Aurora, a rival with far too many teeth and plenty of jokes. Prefer pure management? Play Classic mode.

[h2]Features[/h2]
[list]
[*]Crisp pixel art at any resolution (integer scaling)
[*]Animated cross-section of your garage, real time with pause and 3 speeds
[*]Capped offline progress and daily reports
[*]Fully playable in English and French
[/list]
```

### « À propos du jeu » — FR (balises Steam)

```
[h2]Le garage orbital de votre tante est à vous… ses dettes aussi[/h2]
Tante Odile, garagiste légendaire, a disparu en vous laissant un garage orbital, une IA de bord sarcastique nommée BOLT et 60 000 crédits de dette envers Galax-Auto. Pour garder les clés, il va falloir faire ce qu'elle faisait de mieux : transformer des épaves spatiales en bonnes affaires.

[h2]Acheter. Réparer. Bichonner. Revendre.[/h2]
[list]
[*][b]Achetez[/b] des épaves aux enchères dans 5 lieux. Leur état est en partie caché : payez un scan… ou tentez votre chance.
[*][b]Réparez[/b] leurs défauts, ou [b]maquillez-les[/b] pour vendre plus cher, au risque du SAV, d'une réputation ruinée et de contrôles surprises.
[*][b]Personnalisez[/b]-les : 12 peintures, 12 options et plus de 1 000 combinaisons de coques, moteurs, cockpits et ailes.
[*][b]Revendez[/b]-les à des clients aliens de 12 espèces, chacun avec son budget et des goûts bien précis. Négociez, acceptez des contre-offres, honorez des commandes spéciales.
[*][b]Réinvestissez[/b] : agrandissez le garage et recherchez 42 technologies réparties sur 6 branches.
[/list]

[h2]Un atelier qui tourne tout seul[/h2]
Embauchez acheteurs, mécaniciens, carrossiers, vendeurs et chercheurs parmi un vivier renouvelé chaque jour. Chacun a un niveau, des traits de caractère, un moral et de la fatigue. Affectez les postes et les règles de priorité, puis regardez l'atelier s'automatiser. Il continue même de tourner en votre absence, avec un rapport détaillé à votre retour.

[h2]Une histoire facultative[/h2]
Mode Histoire : 5 chapitres, 2 fins, la quête des 5 pièces de la légendaire Aurore, un rival aux dents bien trop nombreuses et beaucoup d'humour. Envie de gestion pure ? Jouez en mode Classique.

[h2]Caractéristiques[/h2]
[list]
[*]Pixel art net à toutes les résolutions (mise à l'échelle entière)
[*]Coupe animée de votre garage, temps réel avec pause et 3 vitesses
[*]Progression hors ligne plafonnée et rapports quotidiens
[*]Entièrement jouable en français et en anglais
[/list]
```

### Tags suggérés (par ordre d'importance)

Idler, Management, Simulation, Pixel Graphics, Space, Economy, Casual, Funny, Sci-fi, 2D, Singleplayer,
Resource Management, Automation, Trading, Strategy, Indie, Cute, Relaxing, Comedy, Story Rich.

## 6. Captures d'écran (contenu et légendes pour la presse / les réseaux)

| # | Fichier | Légende FR | Caption EN |
|---|---|---|---|
| 1 | `01_title.png` | Écran titre : choisissez le mode Histoire ou Classique | Title screen: pick Story or Classic mode |
| 2 | `02_garage.png` | Le garage en coupe : l'Aurore, repeinte en or, attend ses réparations | The garage cross-section: the Aurora, freshly painted gold, awaits repairs |
| 3 | `03_auctions.png` | Enchères au Nébula Bazar : scannez avant de miser | Auctions at the Nebula Bazaar: scan before you bid |
| 4 | `04_sales.png` | Des clients aliens, des budgets et des goûts très précis | Alien customers with budgets and very specific tastes |
| 5 | `05_staff.png` | Votre équipe : postes, règles de priorité, traits de caractère | Your crew: stations, priority rules, personality traits |
| 6 | `06_research.png` | 42 technologies sur 6 branches | 42 technologies across 6 branches |
| 7 | `07_story.png` | Galax-Auto veut votre garage… pour 12 crédits | Galax-Auto wants your garage… for 12 credits |
| 8 | `08_offline.png` | L'atelier a tourné 24 h sans vous | The workshop ran for 24 hours without you |
| 9 | `09_quests.png` | Chapitres, commandes et journal de quêtes | Chapters, orders and quest journal |

Les parties montrées sont de vraies parties de démonstration jouées par l'autopilote du jeu, mises en scène pour
la vitrine (garage agrandi et plein, tous les lieux ouverts, quelques technologies accordées).

## 7. Bande-annonce

Rendue image par image par le jeu lui-même (Movie Maker de Godot, 30 i/s), agrandie ×4 au plus proche voisin
puis encodée en H.264 : le pixel art reste parfaitement net. Un faux curseur montre les clics.

| Temps | Plan | Légende FR | Caption EN |
|---|---|---|---|
| 0:00 | Écran titre, parade de vaisseaux | Un garage orbital. Des épaves. Des aliens. | An orbital garage. Wrecks. Aliens. |
| 0:04 | Enchères : scan puis mise | Achetez des épaves aux enchères | Buy wrecks at auction |
| 0:10 | Atelier : réparation + coups de main | Réparez-les… ou maquillez-les ! | Fix them… or fake it! |
| 0:17 | Peintures qui défilent, usure qui disparaît | Personnalisez-les à votre goût | Customize them your way |
| 0:22 | Vente conclue à un client alien | Revendez-les à des clients aliens | Sell them to picky aliens |
| 0:27 | Embauche | Embauchez une équipe excentrique | Hire a quirky crew |
| 0:31 | Temps accéléré ×4, puis rapport hors ligne | Votre atelier tourne tout seul / Même quand vous n'êtes pas là | Your workshop runs itself / Even while you're away |
| 0:40 | Arbre technologique | 42 technologies à découvrir | 42 technologies to unlock |
| 0:44 | Dialogues : Tante Odile, Augustin Lustre, BOLT | Une histoire en 5 chapitres, 2 fins | A 5-chapter story, 2 endings |
| 0:55 | Les 5 lieux en plein écran | 5 lieux d'enchères à conquérir | 5 auction sites to conquer |
| 1:02 | Carton final | Bientôt sur Steam | Coming soon on Steam |

- **Muette** : le jeu n'a pas encore d'audio. La piste son silencieuse est là pour la compatibilité ; Steam lance
  de toute façon les vidéos sans le son sur la fiche. Pour ajouter une musique (sous licence commerciale) :
  `ffmpeg -i trailer_en.mp4 -i musique.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -shortest trailer_en_music.mp4`
- Débit vidéo faible (≈ 0,8 Mbit/s) car le pixel art se compresse très bien ; la qualité est quasi sans perte
  (CRF 12). Steam réencode de toute façon les vidéos envoyées.
- Le carton final dit « Bientôt sur Steam » : à refaire au lancement (texte `trailer.cta` dans
  `data/ui_text.json`, puis `tools/make_trailer.py`).

## 8. Classification et contenu

- Aucune violence, aucun contenu sexuel, aucune grossièreté ; humour léger.
- Enchères et ventes avec une **monnaie fictive** uniquement : pas d'argent réel, pas d'achats intégrés,
  pas de mécanique de type loterie.
- Aucune collecte de données, aucun service en ligne.
- Questionnaire de contenu Steam : rien à déclarer ; le jeu devrait relever de PEGI 3 / ESRB E (à confirmer
  si une classification officielle est demandée, par ex. via IARC).

## 9. Divulgation de l'IA (questionnaire de contenu Steam)

Rubrique *AI Generated Content Disclosure* — **contenu pré-généré** (aucune génération pendant le jeu) :

> **EN** — All 2D pixel art (spaceship parts, wear overlays, character portraits, icons, backgrounds and UI
> frames) was generated locally with the open-weights model Z-Image-Turbo (Apache-2.0) through ComfyUI, then
> reduced and quantized to a hand-made 32-color palette by our own tools. Prompts describe original concepts
> only: no artist, studio, franchise or existing character was referenced or imitated. The game's code, design,
> story and texts were written with the help of an AI coding assistant (Claude) under human direction. Store
> trailer and screenshots are captured from the game itself. No AI content is generated while playing.

> **FR** — Tout le pixel art 2D (pièces de vaisseaux, calques d'usure, portraits, icônes, décors et cadres
> d'interface) a été généré localement avec le modèle open-weights Z-Image-Turbo (Apache-2.0) via ComfyUI, puis
> réduit et quantifié sur une palette de 32 couleurs par nos propres outils. Les prompts décrivent uniquement des
> concepts originaux : aucun artiste, studio, licence ou personnage existant n'a été cité ni imité. Le code, le
> game design, l'histoire et les textes ont été écrits avec l'aide d'un assistant de programmation IA (Claude)
> sous direction humaine. La bande-annonce et les captures proviennent du jeu lui-même. Aucun contenu n'est
> généré par IA pendant la partie.

Détail par fichier (prompt, graine, workflow, empreinte) : `art/manifest.json` ; modèles et licences :
`docs/MODEL_LICENSES.md` ; synthèse : `docs/AI_DISCLOSURE.md`.

## 10. Reste à faire avant la publication

1. **Compte Steamworks** (frais Steam Direct de 100 $ par jeu), création de l'application, informations légales
   et bancaires.
2. **Export Windows** : installer les modèles d'export de Godot 4.7.1 (éditeur → *Gérer les modèles d'export*),
   créer un préréglage « Windows Desktop », icône `docs/steam/capsules/icon.ico`, puis tester l'exécutable sur une
   machine modeste (configuration minimale ci-dessus à confirmer).
3. **Envoi du build** avec SteamPipe (SteamCMD) et options de lancement.
4. **Fiche** : textes ci-dessus, captures, capsules, bande-annonce, tags, configuration, langues, divulgation IA,
   questionnaire de contenu ; page « Bientôt disponible » publiée au moins 2 semaines avant la sortie (examen de
   Valve de quelques jours ouvrés pour la fiche puis pour le build).
5. **Recommandé avant la sortie** : musique et bruitages (puis une version sonorisée de la bande-annonce),
   succès Steam et Steam Cloud (par ex. via GodotSteam, MIT), vérification du nom « Wreck & Resell »
   (provisoire), site ou adresse de support, prix et date de sortie.
