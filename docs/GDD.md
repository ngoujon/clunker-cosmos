# Clunker Cosmos — Game Design Document

*Jeu de gestion 2D en pixel art pour PC (Steam). Godot 4.7.1, GDScript typé.*

## 1. Pitch

Vous héritez du garage orbital de votre tante Odile, garagiste légendaire disparue sans laisser d'adresse… mais
avec 60 000 crédits de dettes envers Galax-Auto, la multinationale qui rêve de racheter les lieux. Achetez des épaves
de vaisseaux aux enchères, réparez-les (ou maquillez leurs défauts, à vos risques et périls), personnalisez-les et
revendez-les à une clientèle alien aux goûts très particuliers. Au début, vous faites tout vous-même ; peu à peu,
une équipe d'employés, que l'on voit travailler dans la vue en coupe, automatise l'atelier.

**Ton** : comédie de science-fiction bon enfant (BOLT, l'IA de bord sarcastique ; des clients gélatineux ; un
inspecteur au stylo quatre couleurs), dialogues pleins d'humour. **Public** : amateurs de jeux de gestion cosy,
sessions courtes ou longues. Ce n'est **pas un idle** : rien n'avance quand le jeu est fermé.

## 2. Boucle de jeu

```
 Enchères ──► Garage ──► Personnalisation ──► Vente ──► Crédits/RP/Réputation ──► Réinvestissement
 (scan payant,  (réparer /   (peinture par       (négociation,     (recherche, embauches,
  état caché)    maquiller /  palette-swap,       contre-offres,     agrandissement, dette)
                 déclarer)    options)            SAV, contrôles)
```

1. **Acheter** (écran Enchères) : chaque lieu débloqué propose des lots quotidiens. L'état est **partiellement
   caché** : seuls certains défauts sont visibles ; un **scan payant** en révèle davantage. Enchères **par
   procuration** (on fixe un maximum secret, on paie un incrément au-dessus du 2e enchérisseur). Les concurrents
   PNJ montent progressivement jusqu'à leur maximum. Gagner sans place libre ou sans fonds = lot perdu + réputation.
2. **Réparer** (écran Garage, vue en coupe) : chaque défaut (15 types, 6 systèmes, gravité 1-3) peut être
   **réparé** (coût en pièces + heures de travail), **maquillé** (bien moins cher et plus rapide, mais le défaut
   reste) ou **déclaré** (vendu en l'état, prix réduit). Les défauts dangereux ne peuvent pas être maquillés.
   Réparer peut révéler d'autres défauts cachés du même système.
3. **Personnaliser** : 12 peintures (shader palette-swap des 3 couleurs « apprêt » réservées) et 12 options
   (spoiler, néons, minibar…), certaines à débloquer dans l'arbre.
4. **Vendre** (écran Ventes) : 12 espèces aliens avec budget, classes/couleurs/options préférées et patience
   (refus ⇒ départ). On propose un prix : accepté, **contre-offre** (jusqu'à +10 %) ou refus. La valeur perçue
   ignore les défauts cachés et maquillés…
5. **Conséquences** : un défaut maquillé ou ignoré peut déclencher un **SAV** (remboursement + réputation)
   pendant la garantie de 7 jours ; chaque défaut maquillé vendu augmente les **soupçons** du Bureau Galactique
   de la Consommation, qui peut **contrôler** l'atelier (amendes, réputation) — ou le féliciter s'il est propre.
6. **Réinvestir** : recherche, embauches, agrandissement du garage (5 niveaux), remboursement de la dette.

## 3. Ressources

| Ressource | Sources | Usages |
|---|---|---|
| Crédits (¢) | ventes, quêtes, ferraille | achats, pièces, salaires, entretien, recherche, garage, dette |
| Points de recherche (RP) | réparations, ventes, scans, chercheurs | arbre technologique |
| Réputation (0-100) | ventes réussies, clients satisfaits, contrôles propres | nombre et budget des clients |
| Dette Galax-Auto | 60 000 ¢ au départ | échéance automatique de 2 500 ¢ tous les 7 jours (pénalité si impayée, jamais de game over) |
| Prêt de dépannage | sans vaisseau, sans mise en cours et à moins de 1 500 ¢ | +3 000 ¢ ajoutés à la dette avec 15 % de frais, au plus une fois par semaine ; dans le rouge avec un vaisseau : conseil de vente |

## 4. Temps

- 1 heure de jeu = 4 s réelles à ×1 (×2, ×4, pause). Les employés travaillent de 8 h à 18 h (+2 h avec la
  technologie « Équipe du soir ») ; le patron (le joueur) de 8 h à 20 h, et peut donner des « coups de main »
  (6 par heure) pour accélérer son travail.
- **Aucune progression hors ligne** : la partie reprend exactement où elle était. Le temps se suspend aussi quand
  la fenêtre n'est plus active et après quelques minutes d'inactivité (réglages : jamais, 2, 5 ou 10 min).
- Rapport du jour consultable dans le Bureau.

## 5. Employés

- **Vivier renouvelé chaque jour** (taille et niveau max améliorables). Rôles : **Acheteur** (scanne et
  enchérit), **Mécanicien** (répare/maquille selon la politique), **Carrossier** (peint et personnalise selon
  la demande), **Vendeur** (négocie), **Chercheur** (produit des RP).
- Chaque employé : niveau 1-10 et XP, 1-2 **traits** parmi 14 (Rapide, Perfectionniste, Maladroit, Génie,
  Charmeur…), salaire, **moral** et **fatigue** (efficacité, démission si le moral s'effondre).
- **Postes** : un employé travaille seulement s'il est affecté à un poste de son rôle ; le nombre de postes et
  l'effectif maximal dépendent du niveau du garage (et de la recherche).
- **Règles de priorité** par employé (ex. Mécanicien : critiques d'abord / rapides d'abord / valeur d'abord /
  plus anciens d'abord ; Vendeur : prix fort / vente rapide / commandes d'abord).
- **Politique de l'atelier** (Honnête / Pragmatique / Requin) appliquée automatiquement, avec consigne
  par défaut modifiable défaut par défaut.

## 6. Arbre technologique

6 branches × 7 nœuds (42) : **Atelier**, **Commerce**, **Personnalisation**, **RH**, **Diagnostic**, **Lieux**.
Chaque nœud a des prérequis (y compris inter-branches), un coût en RP + crédits et des **effets
data-driven** : modificateurs `add`/`mul` sur ~37 statistiques (vitesse de réparation, prix de vente, puissance
des scans, frais d'enchères, effectif max, heures de service…) ou déblocages (peintures, options, lieux).
Écran en graphe : colonnes = branches, rangs = profondeur, liens orthogonaux, états (acquis / disponible /
ressources insuffisantes / verrouillé).

## 7. Lieux d'enchères

| Lieu | Particularité |
|---|---|
| Casse de Ferropolis | départ, épaves bon marché |
| Anneaux de Kryo-7 | épaves congelées, bien conservées |
| Nébula Bazar | marché noir, prix bas, surprises |
| Cimetière de Tartarus | épaves lourdes à petit prix |
| Lune d'Opalia | prestige, clients riches |

## 8. Histoire et quêtes

**Deux modes** à la création de partie : **Histoire** (quêtes principales + commandes) et **Classique**
(bac à sable, commandes seulement). Les quêtes sont **toujours facultatives** dans leur réalisation : aucune
n'empêche de jouer librement. Tout est **data-driven** (`data/quests.json`) : déclencheurs (conditions),
objectifs (comptés par événements ou évalués sur l'état), dialogues (début/fin/échec), récompenses (crédits,
RP, réputation, épaves rares, lots spéciaux, employés uniques, technologies, modificateurs), délais, choix.

**Intrigue** — l'héritage du garage orbital de la tante disparue, la dette envers Galax-Auto qui veut racheter,
BOLT l'IA sarcastique, et l'**Aurore**, vaisseau légendaire démonté en **5 pièces dispersées dans les 5 lieux**.

| Chapitre | Titre | Résumé |
|---|---|---|
| 1 | L'Héritage | Un garage orbital, une IA sarcastique et 60 000 crédits de dettes : bienvenue dans la famille. |
| 2 | Les affaires reprennent | Recruter, chercher, conquérir Kryo-7… et survivre aux holo-pubs de Galax-Auto. |
| 3 | Le Marché noir | Le Nébula Bazar, ses bonnes affaires douteuses et une inspectrice au stylo à quatre couleurs. |
| 4 | Le Cimetière | À Tartarus, les vaisseaux viennent mourir. Vous venez les ressusciter. |
| 5 | L'Aurore | Cinq pièces, une lune de luxe, une tante retrouvée et un choix qui change tout. |

**Deux fins** : *Indépendance* (garder l'Aurore et le garage) ou *Franchise* (vendre l'Aurore à Galax-Auto).
23 quêtes principales et 18 commandes secondaires (clients aux critères précis : classe, couleur, options,
usure, honnêteté…). Personnages : BOLT, Tante Odile, Augustin Lustre (Galax-Auto), l'inspectrice Plimsoll,
et les clients des 12 espèces.

## 9. Direction artistique

- Conception en **480×270**, pixel art au plus proche voisin à l'échelle entière ; la résolution de l'interface
  s'adapte à l'écran (853×480 en 1440p, 640×360 en 1080p par défaut, réglable) pendant que décors et vaisseaux
  gardent leur propre échelle entière. Textes en **Barlow Semi Condensed** (lisible, non pixel), logo et titres
  en **Lilita One**, rastérisés à la résolution de l'écran.
- **Palette unique de 32 couleurs** conçue pour le projet, dont 3 couleurs « apprêt » réservées aux zones
  peignables ; peinture appliquée en jeu par **shader palette-swap**.
- Vaisseaux **modulaires** : 8 coques, 6 moteurs, 6 cockpits, 4 paires d'ailes avec **points d'ancrage**
  calculés depuis l'alpha ; 4 **calques d'usure** (rouille, rayures, bosses, brûlures) découpés sur la coque.
- 12 portraits de clients, 10 employés (portrait et personnage en pied animé à son poste), 4 personnages ;
  > 100 icônes 16×16 ; garage en coupe et 5 fonds de lieux ; UI 9-slice ; curseur de souris en pixel art.
- Production : génération locale (ComfyUI, Z-Image-Turbo, Apache-2.0) puis réduction/quantification par
  `tools/pixelize.py`. Voir `docs/AI_DISCLOSURE.md` et `docs/MODEL_LICENSES.md`.

## 10. Interface

Barre du haut (crédits, RP, réputation, dette, jour/heure, vitesse ; infobulles explicatives au survol),
navigation en bas (Garage, Enchères, Ventes, Équipe, Labo, Quêtes, Bureau), notifications, boîte de dialogue
avec portrait, **tutoriel** en 12 pages (écran titre, bouton « ? », F1), **paramètres** (plein écran, taille de
l'interface, volumes, langue, pauses automatiques, sauvegarde).
Raccourcis : Espace (pause), 1-3 (vitesse), Échap (paramètres), F1 (tutoriel), F11 ou Alt+Entrée (plein écran),
F12 (capture).

## 10 bis. Audio

Musiques instrumentales (thème du menu, trois ambiances d'atelier enchaînées, jingle de victoire) générées
localement avec ACE-Step 1.5 (MIT) ; 32 bruitages synthétisés par code (interface, enchères, réparations,
ventes…) et un « bip de voix » par personnage pendant les dialogues. Volumes général, musique et bruitages.

## 11. Technique

- Logique pure (`scripts/core/`, RefCounted + systèmes statiques) séparée de l'UI, **testable en headless**
  (tests unitaires, simulation 30 jours, chapitres 1-2 scriptés, test de fumée de l'UI à toutes les tailles
  d'interface).
- Contenu JSON (`data/`), textes **FR + EN** (bascule à chaud), **sauvegarde JSON versionnée** avec migration,
  générateur aléatoire déterministe sauvegardé, autosauvegarde toutes les 30 s.
- Hors périmètre : multijoueur.

## 12. Équilibrage (valeurs de départ)

8 000 ¢, réputation 30, dette 60 000 ¢. Garage niveau 1 : 3 baies, 3 employés. La simulation de référence
(autopilote, graine 7, 30 jours, mode Classique) doit produire ≥ 10 ventes et un résultat d'exploitation positif.
