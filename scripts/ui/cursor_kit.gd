class_name CursorKit
extends RefCounted
## Curseur de souris du jeu (remplace celui de Windows dans la fenêtre) : flèche dorée, main sur les boutons,
## flèche « ? » sur les éléments à infobulle. Formes vectorielles (polygones, capsules, cercles) rastérisées
## avec anticrénelage (3 × 3 échantillons par pixel) à la taille de l'interface. Ce sont des curseurs
## « matériels » (Input.set_custom_mouse_cursor) : aucune latence par rapport à la souris.

## Taille de chaque motif en unités de dessin (multipliées par k pixels d'écran).
const SIZES: Dictionary = {"arrow": Vector2i(12, 18), "hand": Vector2i(15, 16), "help": Vector2i(19, 18)}
const HOTSPOTS: Dictionary = {"arrow": Vector2i(1, 1), "hand": Vector2i(5, 1), "help": Vector2i(1, 1)}
const ARROW: PackedVector2Array = [
	Vector2(1, 1), Vector2(1, 15.2), Vector2(4.6, 11.8), Vector2(7.2, 17), Vector2(9.4, 16), Vector2(6.9, 10.9), Vector2(11, 10.9),
]
## Épaisseur du contour sombre (unités de dessin).
const OUTLINE: float = 1.0
const SUPERSAMPLE: int = 3


static func colors() -> Dictionary:
	return {"outline": UIKit.C_DARK, "fill": UIKit.C_ACCENT, "light": UIKit.C_TEXT, "shade": UIKit.C_ORANGE}


## Formes d'un curseur : liste de {"kind": "poly"|"capsule"|"circle", ..., "color": clé de colors()}, dessinées
## dans l'ordre (le contour sombre est ajouté automatiquement autour de l'ensemble).
static func shapes(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match id:
		"hand":
			out.append({"kind": "capsule", "a": Vector2(5.5, 2.2), "b": Vector2(5.5, 9), "r": 1.6, "color": "light"})
			for x: float in [8.2, 10.4, 12.4]:
				out.append({"kind": "capsule", "a": Vector2(x, 7.2), "b": Vector2(x, 10), "r": 1.25, "color": "light"})
			out.append({"kind": "capsule", "a": Vector2(2.2, 9.6), "b": Vector2(4.2, 12), "r": 1.3, "color": "light"})
			out.append({"kind": "poly", "pts": PackedVector2Array([Vector2(4, 8.5), Vector2(13.6, 8.5), Vector2(13.4, 13), Vector2(11.5, 15), Vector2(5.5, 15), Vector2(3.6, 12.5)]), "color": "light"})
			out.append({"kind": "poly", "pts": PackedVector2Array([Vector2(5.3, 13.4), Vector2(11.9, 13.4), Vector2(11.4, 15), Vector2(5.6, 15)]), "color": "fill"})
		_:
			out.append({"kind": "poly", "pts": ARROW, "color": "fill"})
			out.append({"kind": "capsule", "a": Vector2(1.7, 2.6), "b": Vector2(1.7, 12.6), "r": 0.5, "color": "light"})
			if id == "help":
				# Point d'interrogation en bas à droite : arc en capsules + point.
				var c: Vector2 = Vector2(15.2, 9.6)
				var prev: Vector2 = c + Vector2(-2.0, 0.0)
				for i: int in range(1, 9):
					var ang: float = PI + PI * 1.4 * float(i) / 8.0
					var q: Vector2 = c + Vector2(cos(ang), sin(ang)) * 2.0
					out.append({"kind": "capsule", "a": prev, "b": q, "r": 0.8, "color": "fill"})
					prev = q
				out.append({"kind": "capsule", "a": prev, "b": Vector2(15.2, 13.4), "r": 0.8, "color": "fill"})
				out.append({"kind": "circle", "c": Vector2(15.2, 15.9), "r": 0.95, "color": "fill"})
	return out


## Distance signée (négative à l'intérieur) d'un point à une forme, en unités de dessin.
static func _sd(sh: Dictionary, p: Vector2) -> float:
	match str(sh["kind"]):
		"circle":
			return p.distance_to(sh["c"] as Vector2) - float(sh["r"])
		"capsule":
			var a: Vector2 = sh["a"]
			var b: Vector2 = sh["b"]
			var ab: Vector2 = b - a
			var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			return p.distance_to(a + ab * t) - float(sh["r"])
	var pts: PackedVector2Array = sh["pts"]
	var d: float = INF
	for i: int in pts.size():
		var a2: Vector2 = pts[i]
		var e: Vector2 = pts[(i + 1) % pts.size()] - a2
		var t2: float = clampf((p - a2).dot(e) / maxf(e.length_squared(), 0.0001), 0.0, 1.0)
		d = minf(d, p.distance_to(a2 + e * t2))
	return -d if Geometry2D.is_point_in_polygon(p, pts) else d


static var _cache: Dictionary = {}


## Image du curseur à k pixels d'écran par unité de dessin (gardée en mémoire : rastérisée une seule fois).
static func image(id: String, k: int) -> Image:
	var kk: int = maxi(1, k)
	var key: String = "%s@%d" % [id, kk]
	if not _cache.has(key):
		_cache[key] = _rasterize(id, kk)
	return _cache[key]


static func _rasterize(id: String, kk: int) -> Image:
	var sz: Vector2i = SIZES.get(id, SIZES["arrow"])
	var w: int = sz.x * kk
	var h: int = sz.y * kk
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var sh: Array[Dictionary] = shapes(id)
	var cols: Dictionary = colors()
	var n: int = SUPERSAMPLE
	# Demi-diagonale d'un pixel d'écran en unités de dessin : au-delà, le pixel entier est hors des formes.
	var half: float = 0.75 / float(kk)
	for y: int in h:
		for x: int in w:
			var center: Vector2 = Vector2(x + 0.5, y + 0.5) / float(kk)
			var dmin: float = INF
			for s0: Dictionary in sh:
				dmin = minf(dmin, _sd(s0, center))
			if dmin > OUTLINE + half:
				continue
			var acc: Color = Color(0, 0, 0, 0)
			for sy: int in n:
				for sx: int in n:
					var p: Vector2 = Vector2(x + (sx + 0.5) / n, y + (sy + 0.5) / n) / float(kk)
					var col: Color = Color(0, 0, 0, 0)
					var near_edge: bool = false
					for s: Dictionary in sh:
						var d: float = _sd(s, p)
						if d <= 0.0:
							col = cols[str(s["color"])]
						elif d <= OUTLINE:
							near_edge = true
					if col.a == 0.0 and near_edge:
						col = cols["outline"]
					acc += Color(col.r * col.a, col.g * col.a, col.b * col.a, col.a)
			var a: float = acc.a / float(n * n)
			if a > 0.0:
				img.set_pixel(x, y, Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, a))
	return img


## Taille du curseur : celle des pixels de l'interface (k pixels d'écran, voir ViewScale), un cran en
## dessous au-delà de ×2 (sinon la flèche paraît énorme).
static func scale_for(ui_scale: int) -> int:
	var k: int = maxi(1, ui_scale)
	return k if k <= 2 else k - 1


## Installe les curseurs pour la taille d'interface actuelle (à rappeler quand elle change).
static func apply(ui_scale: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var k: int = scale_for(ui_scale)
	var arrow: Image = image("arrow", k)
	var arrow_shapes: Array[Input.CursorShape] = [
		Input.CURSOR_ARROW, Input.CURSOR_IBEAM, Input.CURSOR_WAIT, Input.CURSOR_BUSY, Input.CURSOR_CROSS,
		Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP, Input.CURSOR_FORBIDDEN, Input.CURSOR_MOVE,
		Input.CURSOR_VSIZE, Input.CURSOR_HSIZE, Input.CURSOR_BDIAGSIZE, Input.CURSOR_FDIAGSIZE,
		Input.CURSOR_VSPLIT, Input.CURSOR_HSPLIT,
	]
	for shape: Input.CursorShape in arrow_shapes:
		Input.set_custom_mouse_cursor(arrow, shape, Vector2(HOTSPOTS["arrow"]) * float(k))
	Input.set_custom_mouse_cursor(image("hand", k), Input.CURSOR_POINTING_HAND, Vector2(HOTSPOTS["hand"]) * float(k))
	Input.set_custom_mouse_cursor(image("help", k), Input.CURSOR_HELP, Vector2(HOTSPOTS["help"]) * float(k))
