class_name ViewScale
extends RefCounted
## Taille de l'interface. La fenêtre (en pixels d'écran) est divisée par un facteur entier k, « pixels
## d'écran par pixel d'interface » : la résolution logique de l'interface vaut fenêtre / k (au moins
## 480×270, la taille de conception). Plus k est petit, plus l'interface est fine et plus il y a de place.
## Les décors, vaisseaux et employés (images HD, version 2.5D) suivent leur propre échelle, continue : la plus
## grande qui tient (ou qui couvre l'écran), jamais moins d'un pixel d'interface par pixel logique d'image.
## Fonctions pures (testées en headless) ; l'application à la fenêtre est faite par MainUI.

## Taille de conception (et des décors) : minimum de la résolution logique.
const BASE: Vector2i = Vector2i(480, 270)
## Réglage automatique : hauteur logique au plus de AUTO_HEIGHT (853×480 en 1440p, 640×360 en 1080p).
const AUTO_HEIGHT: int = 480
## Hauteur logique maximale proposée (au-delà, le texte devient minuscule).
const MAX_HEIGHT: int = 1080


## Plus grand facteur possible : la résolution logique reste au moins égale à 480×270.
static func max_scale(win: Vector2i) -> int:
	return maxi(1, mini(win.x / BASE.x, win.y / BASE.y))


## Plus petit facteur proposé : 2 (texte de 16 pixels d'écran), sauf si la fenêtre est trop petite.
static func min_scale(win: Vector2i) -> int:
	var hi: int = max_scale(win)
	return clampi(maxi(2, ceili(float(win.y) / float(MAX_HEIGHT))), 1, hi)


## Facteurs proposés au joueur, de l'interface la plus grande à la plus fine.
static func choices(win: Vector2i) -> Array[int]:
	var out: Array[int] = []
	var k: int = max_scale(win)
	while k >= min_scale(win):
		out.append(k)
		k -= 1
	return out


static func auto_scale(win: Vector2i) -> int:
	return clampi(ceili(float(win.y) / float(AUTO_HEIGHT)), min_scale(win), max_scale(win))


## Facteur effectif pour un réglage (0 : automatique ; sinon borné aux choix possibles).
static func resolve(win: Vector2i, setting: int) -> int:
	if setting <= 0:
		return auto_scale(win)
	return clampi(setting, min_scale(win), max_scale(win))


## Résolution logique de l'interface pour la fenêtre et le facteur k.
static func logical_size(win: Vector2i, k: int) -> Vector2i:
	var kk: int = maxi(1, k)
	return Vector2i(maxi(BASE.x, win.x / kk), maxi(BASE.y, win.y / kk))


## Réglage suivant du bouton « Taille de l'interface » : Auto, puis les tailles plus fines que l'automatique
## (plus de place à l'écran), puis les plus grandes, puis retour à Auto.
static func next_setting(win: Vector2i, setting: int) -> int:
	var ka: int = auto_scale(win)
	var order: Array[int] = [0]
	for k: int in choices(win):
		if k < ka:
			order.append(k)
	for k: int in choices(win):
		if k > ka:
			order.append(k)
	return order[(order.find(setting) + 1) % order.size()]


## Échelle (en pixels logiques par pixel logique d'image) d'une image de `content` pixels qui doit tenir
## entièrement dans `area` (pixels logiques), jamais moins de 1. `k` est gardé pour la compatibilité des appels.
static func fit_scale(area: Vector2, content: Vector2, _k: int) -> float:
	return maxf(1.0, minf(area.x / content.x, area.y / content.y))


## Échelle d'une image qui doit couvrir toute la zone `area` (débordement rogné), même règle.
static func cover_scale(area: Vector2, content: Vector2, _k: int) -> float:
	return maxf(1.0, maxf(area.x / content.x, area.y / content.y))


## Arrondit une position logique au pixel d'écran (k pixels d'écran par pixel logique).
static func snap(v: Vector2, k: int) -> Vector2:
	var kk: float = float(maxi(1, k))
	return (v * kk).floor() / kk
