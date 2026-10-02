class_name WorkerView
extends Control
## Employé en pied dans la vue en coupe du garage : sprite généré (assets/workers/<portrait>.png) et
## petite animation de travail dessinée en code au pixel près (rebond, outil, étincelles, peinture,
## bulles). Survol : infobulle et repère au-dessus de la tête ; clic : signal `pressed` (écran Équipe).
## L'animation s'arrête quand le jeu est en pause ; toutes les positions sont entières.

signal pressed

const W: int = 20
const H: int = 26
## Pas d'animation : 12 images/s, comme une animation pixel art.
const STEP: float = 1.0 / 12.0
## Main du personnage (regard vers la droite), relative au coin haut-gauche du sprite.
const HAND: Vector2i = Vector2i(14, 16)
const C_OUTLINE: Color = Color("#0d0e14")
const C_STEEL: Color = Color("#8a8fa6")
const C_STEEL_LIGHT: Color = Color("#c8cbd6")
const C_WHITE: Color = Color("#f2f0e6")
const C_ACCENT: Color = Color("#f5dc6a")
const C_SPARKS: Array[Color] = [Color("#f5dc6a"), Color("#f5a05a"), Color("#f2f0e6")]
const C_PUTTY: Color = Color("#c8cbd6")
const C_CUP: Color = Color("#b5303a")
const C_GLYPH: Color = Color("#2a2b3d")
const C_HANDLE: Color = Color("#8a5a1c")
const C_SCREEN_A: Color = Color("#5aa0e8")
const C_SCREEN_B: Color = Color("#4cc6c0")
## Glyphes des bulles (3×5 ou moins), « # » = pixel plein.
const GLYPHS: Dictionary = {
	"?": ["###", "..#", ".##", "...", ".#."],
	"!": ["#", "#", "#", ".", "#"],
	"¢": [".#.", "###", "#..", "###", ".#."],
	"z": ["###", "..#", ".#.", "#..", "###"],
	"…": ["#.#.#"],
}
## Bulles par activité (alternées).
const BUBBLES: Dictionary = {"bid": ["¢", "!"], "sell": ["¢", "…"], "research": ["?", "!"], "idle": ["…"], "pause": ["…"]}

static var _images: Dictionary = {}

var employee_id: String = ""
var activity: String = "idle"
var face_left: bool = false
var tired: bool = false
var paint_color: Color = Color("#e8655a")
## Garde-corps de la mezzanine redessiné devant le corps (pas devant l'objet tenu) : l'employé de
## l'étage se tient derrière la rambarde, comme le mobilier du décor.
var rail: Texture2D = null
var rail_y: int = 0
var _tex: Texture2D = null
var _img: Image = null
var _f: int = 0
var _acc: float = 0.0
var _hover: bool = false
var _parts: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	size = Vector2(W, H)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


## `portrait` : identifiant du portrait de l'employé (staff_01…) ; `p_activity` : voir StaffLayout.
func setup(id: String, portrait: String, p_activity: String, p_face_left: bool) -> void:
	employee_id = id
	activity = p_activity
	face_left = p_face_left
	var path: String = "res://assets/workers/%s.png" % portrait
	_tex = UIKit.tex(path) if ResourceLoader.exists(path) else null
	_img = _image_for(path, _tex)
	_rng.seed = hash(id)
	# Phases décalées : deux employés voisins ne bougent pas en même temps.
	_f = _rng.randi_range(0, 95)
	queue_redraw()


static func _image_for(path: String, tex: Texture2D) -> Image:
	if tex == null:
		return null
	if not _images.has(path):
		_images[path] = tex.get_image()
	return _images[path]


func _gui_input(ev: InputEvent) -> void:
	var mb: InputEventMouseButton = ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


## Survol au pixel près : seules les parties opaques du personnage (± 1 pixel) captent la souris.
func _has_point(point: Vector2) -> bool:
	if _img == null:
		return Rect2(Vector2.ZERO, size).has_point(point)
	var px: int = int(floorf(point.x))
	var py: int = int(floorf(point.y)) - _bob()
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x: int = px + d.x
		var y: int = py + d.y
		if face_left:
			x = W - 1 - x
		if x >= 0 and y >= 0 and x < _img.get_width() and y < _img.get_height() and _img.get_pixel(x, y).a > 0.5:
			return true
	return false


func _process(delta: float) -> void:
	if Game.speed() <= 0.0:
		return
	_acc += delta
	var stepped: bool = false
	while _acc >= STEP:
		_acc -= STEP
		_step()
		stepped = true
	if stepped:
		queue_redraw()


# --- Animation ------------------------------------------------------------------

## Décalage vertical du corps (0 ou -1).
func _bob() -> int:
	match activity:
		"repair":
			return -1 if _f % 6 in [3, 4] else 0
		"conceal":
			return -1 if _f % 8 == 4 else 0
		"paint":
			return -1 if _f % 16 in [0, 1] else 0
		"bid", "sell", "research":
			return -1 if _f % 10 == 0 else 0
	return -1 if (_f % (36 if tired else 24)) < (6 if tired else 4) else 0


func _step() -> void:
	_f += 1
	var alive: Array[Dictionary] = []
	for p: Dictionary in _parts:
		p["life"] = float(p["life"]) - STEP
		var v: Vector2 = p["v"]
		p["p"] = (p["p"] as Vector2) + v * STEP
		p["v"] = v + Vector2(0.0, float(p.get("g", 0.0))) * STEP
		if float(p["life"]) > 0.0:
			alive.append(p)
	_parts = alive
	var tip: Vector2 = Vector2(HAND.x + 6, HAND.y - 1)
	match activity:
		"repair":
			if _f % 6 == 3:
				for _i: int in _rng.randi_range(3, 5):
					_spark(tip, Vector2(_rng.randf_range(8.0, 36.0), _rng.randf_range(-40.0, -8.0)), C_SPARKS[_rng.randi() % C_SPARKS.size()], 0.4, 110.0)
		"conceal":
			if _f % 8 == 4:
				_spark(tip, Vector2(_rng.randf_range(4.0, 10.0), _rng.randf_range(-8.0, -2.0)), C_PUTTY, 0.5, 0.0)
		"paint":
			# Nuage de peinture : bouffées de 2 pixels qui s'amenuisent en s'éloignant de la buse.
			_spark(Vector2(HAND.x + 5, HAND.y - 3 + _rng.randi_range(0, 1)), Vector2(_rng.randf_range(14.0, 26.0), _rng.randf_range(-7.0, 7.0)), paint_color, 0.5, 0.0, 2)
		"idle", "pause":
			if _f % 10 == 0:
				_spark(Vector2(HAND.x + 1, HAND.y - 3), Vector2(_rng.randf_range(-2.0, 2.0), -6.0), C_STEEL_LIGHT, 0.6, 0.0)


func _spark(pos: Vector2, vel: Vector2, c: Color, life: float, gravity: float, px_size: int = 1) -> void:
	_parts.append({"p": pos, "v": vel, "c": c, "life": life, "g": gravity, "s": px_size})


## Bulle affichée à cet instant ("" sinon) : 1,5 s toutes les 5 s environ, décalée par employé.
func _bubble() -> String:
	var glyphs: Array = BUBBLES.get(activity, [])
	if tired and activity in ["idle", "pause"]:
		glyphs = ["z"]
	if glyphs.is_empty():
		return ""
	var cycle: int = _f % 60
	if cycle >= 18:
		return ""
	return str(glyphs[(_f / 60) % glyphs.size()])


# --- Dessin -------------------------------------------------------------------------

## Pixel en coordonnées « regard vers la droite » (miroir si le personnage regarde à gauche).
func _px(x: int, y: int, c: Color, w: int = 1, h: int = 1) -> void:
	var rx: int = W - x - w if face_left else x
	draw_rect(Rect2(rx, y, w, h), c)


func _draw() -> void:
	var bob: int = _bob()
	if _tex != null:
		if face_left:
			draw_set_transform(Vector2(W, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(_tex, Rect2(0, bob, W, H), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_px(6, 4 + bob, C_STEEL, 8, 19)
	if rail != null:
		draw_texture_rect(rail, Rect2(0, rail_y, W, rail.get_height()), false)
	_draw_tool(bob)
	for p: Dictionary in _parts:
		var pos: Vector2 = p["p"]
		var ps: int = int(p.get("s", 1)) if float(p["life"]) > 0.25 else 1
		_px(int(floorf(pos.x)), int(floorf(pos.y)) + bob, p["c"], ps, ps)
	if activity == "repair" and _f % 6 == 3:
		# Éclair du coup de clé, au bout des mâchoires.
		var fx: int = HAND.x + 6
		var fy: int = HAND.y - 1 + bob
		_px(fx, fy - 1, C_ACCENT, 1, 3)
		_px(fx - 1, fy, C_ACCENT, 3, 1)
		_px(fx, fy, C_WHITE)
	var g: String = _bubble()
	if not g.is_empty():
		_draw_bubble(g, bob)
	if _hover:
		# Repère de survol : petit triangle au-dessus de la tête.
		_px(8, -4, C_ACCENT, 5, 1)
		_px(9, -3, C_ACCENT, 3, 1)
		_px(10, -2, C_ACCENT, 1, 1)


func _draw_tool(bob: int) -> void:
	var hx: int = HAND.x
	var hy: int = HAND.y + bob
	var pts: Array[Array] = []
	match activity:
		"repair":
			if _f % 6 < 3:
				# Clé levée : manche vertical, mâchoires en U vers le haut.
				for k: int in 4:
					pts.append([hx, hy - 1 - k, C_STEEL_LIGHT])
				pts.append_array([[hx - 1, hy - 5, C_STEEL_LIGHT], [hx + 1, hy - 5, C_STEEL_LIGHT], [hx - 1, hy - 6, C_STEEL], [hx + 1, hy - 6, C_STEEL]])
			else:
				# Clé abattue vers le vaisseau (les étincelles partent des mâchoires).
				for k: int in 4:
					pts.append([hx + k, hy - 1, C_STEEL_LIGHT])
				pts.append_array([[hx + 4, hy - 2, C_STEEL_LIGHT], [hx + 4, hy, C_STEEL_LIGHT], [hx + 5, hy - 2, C_STEEL], [hx + 5, hy, C_STEEL]])
		"conceal":
			# Spatule de mastic qui va et vient.
			var dx: int = 1 if _f % 8 >= 4 else 0
			pts.append_array([[hx + dx, hy - 1, C_HANDLE], [hx + 1 + dx, hy - 1, C_HANDLE]])
			for y: int in 3:
				pts.append_array([[hx + 2 + dx, hy - 2 + y, C_STEEL_LIGHT], [hx + 3 + dx, hy - 2 + y, C_PUTTY if y == 1 else C_STEEL_LIGHT]])
		"paint":
			# Pistolet à peinture : corps, buse, godet à la couleur de la peinture, poignée.
			for x: int in 3:
				pts.append_array([[hx + x, hy - 2, C_STEEL], [hx + x, hy - 1, C_STEEL]])
			pts.append_array([[hx + 3, hy - 2, C_STEEL_LIGHT], [hx + 1, hy - 4, paint_color], [hx + 2, hy - 4, paint_color],
				[hx + 1, hy - 3, paint_color], [hx + 2, hy - 3, paint_color], [hx, hy, C_HANDLE]])
		"bid", "sell", "research":
			# Tablette : cadre sombre, écran qui clignote au rythme de la frappe.
			var screen: Color = C_SCREEN_A if _f % 4 < 2 else C_SCREEN_B
			for x: int in 4:
				for y: int in 3:
					var inside: bool = x in [1, 2] and y == 1
					pts.append([hx - 1 + x, hy - 2 + y, screen if inside else C_GLYPH])
		"idle", "pause":
			# Tasse de café (le café fume, voir _step).
			for x: int in 3:
				pts.append([hx + x, hy - 2, C_WHITE])
				for y: int in 2:
					pts.append([hx + x, hy - 1 + y, C_CUP])
			pts.append([hx + 3, hy - 1, C_CUP])
	_item(pts)


## Petit objet tenu en main : pixels [x, y, couleur] (regard à droite) cernés d'un contour sombre.
func _item(pts: Array[Array]) -> void:
	if pts.is_empty():
		return
	var filled: Dictionary = {}
	for p: Array in pts:
		filled[Vector2i(int(p[0]), int(p[1]))] = true
	for p: Array in pts:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = Vector2i(int(p[0]), int(p[1])) + d
			if not filled.has(q):
				_px(q.x, q.y, C_OUTLINE)
	for p: Array in pts:
		_px(int(p[0]), int(p[1]), p[2] as Color)


func _draw_bubble(g: String, bob: int) -> void:
	var rows: Array = GLYPHS.get(g, ["?"])
	var gw: int = str(rows[0]).length()
	var gh: int = rows.size()
	var bw: int = gw + 4
	var bh: int = gh + 4
	var bx: int = 12
	var by: int = -bh - 1 + bob
	_px(bx + 1, by, C_OUTLINE, bw - 2, 1)
	_px(bx + 1, by + bh - 1, C_OUTLINE, bw - 2, 1)
	_px(bx, by + 1, C_OUTLINE, 1, bh - 2)
	_px(bx + bw - 1, by + 1, C_OUTLINE, 1, bh - 2)
	_px(bx + 1, by + 1, C_WHITE, bw - 2, bh - 2)
	_px(bx + 1, by + bh, C_OUTLINE, 2, 1)
	_px(bx + 1, by + bh - 1, C_WHITE, 1, 1)
	# Le texte n'est jamais en miroir : position calculée depuis le bord gauche réel de la bulle.
	var left: int = W - bx - bw if face_left else bx
	for r: int in gh:
		var line: String = str(rows[r])
		for c: int in line.length():
			if line[c] == "#":
				draw_rect(Rect2(left + 2 + c, by + 2 + r, 1, 1), C_GLYPH)
