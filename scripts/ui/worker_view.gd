class_name WorkerView
extends Control
## Employé en pied dans la vue en coupe du garage : personnage 3D pré-rendu (assets/workers/<portrait>.png) et
## petite animation de travail dessinée en code avec des formes lissées (rebond, outil, étincelles, peinture,
## bulles de texte). Survol : infobulle et repère au-dessus de la tête ; clic : signal `pressed` (écran Équipe).
## L'animation s'arrête quand le jeu est en pause.

signal pressed

const W: int = 20
const H: int = 26
## Pas de la simulation de l'animation (12 images/s) ; le rebond est interpolé entre deux pas.
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
	# Image HD : DETAIL pixels d'image par pixel logique.
	var k: float = float(_img.get_width()) / float(W)
	var py: float = point.y - _bob()
	for d: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var x: float = point.x + d.x
		if face_left:
			x = W - x
		var ix: int = int(x * k)
		var iy: int = int((py + d.y) * k)
		if ix >= 0 and iy >= 0 and ix < _img.get_width() and iy < _img.get_height() and _img.get_pixel(ix, iy).a > 0.5:
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
	if stepped or activity in ["repair", "conceal", "paint"]:
		queue_redraw()


# --- Animation ------------------------------------------------------------------

## Décalage vertical du corps (0 ou -1), adouci entre deux pas d'animation.
func _bob() -> float:
	var a: int = _bob_at(_f)
	var b: int = _bob_at(_f + 1)
	return lerpf(float(a), float(b), clampf(_acc / STEP, 0.0, 1.0))


func _bob_at(f: int) -> int:
	match activity:
		"repair":
			return -1 if f % 6 in [3, 4] else 0
		"conceal":
			return -1 if f % 8 == 4 else 0
		"paint":
			return -1 if f % 16 in [0, 1] else 0
		"bid", "sell", "research":
			return -1 if f % 10 == 0 else 0
	return -1 if (f % (36 if tired else 24)) < (6 if tired else 4) else 0


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

## Point en coordonnées « regard vers la droite » (miroir si le personnage regarde à gauche).
func _m(p: Vector2) -> Vector2:
	return Vector2(W - p.x, p.y) if face_left else p


func _line(a: Vector2, b: Vector2, c: Color, w: float = 1.0) -> void:
	draw_line(_m(a), _m(b), c, w, true)


func _draw() -> void:
	var bob: float = _bob()
	if _tex != null:
		if face_left:
			draw_set_transform(Vector2(W, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(_tex, Rect2(0, bob, W, H), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_rect(Rect2(_m(Vector2(6, 4 + bob)) - (Vector2(8, 0) if face_left else Vector2.ZERO), Vector2(8, 19)), C_STEEL)
	if rail != null:
		draw_texture_rect(rail, Rect2(0, rail_y, W, rail.get_height()), false)
	_draw_tool(bob)
	for p: Dictionary in _parts:
		var pos: Vector2 = (p["p"] as Vector2) + Vector2(0, bob)
		var life: float = float(p["life"])
		var r: float = 0.45 * float(p.get("s", 1)) * clampf(life / 0.25, 0.4, 1.0)
		var col: Color = p["c"]
		draw_circle(_m(pos), r * 2.2, Color(col, 0.18 * minf(1.0, life * 3.0)), true, -1.0, true)
		draw_circle(_m(pos), r, Color(col, minf(1.0, life * 3.0)), true, -1.0, true)
	if activity == "repair" and _f % 6 == 3:
		# Éclair du coup de clé, au bout des mâchoires.
		var f: Vector2 = Vector2(HAND.x + 6.5, HAND.y - 0.5 + bob)
		draw_circle(_m(f), 2.2, Color(C_ACCENT, 0.35), true, -1.0, true)
		_line(f + Vector2(0, -1.6), f + Vector2(0, 1.6), C_ACCENT, 0.6)
		_line(f + Vector2(-1.6, 0), f + Vector2(1.6, 0), C_ACCENT, 0.6)
		draw_circle(_m(f), 0.6, C_WHITE, true, -1.0, true)
	var g: String = _bubble()
	if not g.is_empty():
		_draw_bubble(g, bob)
	if _hover:
		# Repère de survol : petit triangle au-dessus de la tête.
		var tri: PackedVector2Array = [Vector2(7.5, -4.5), Vector2(12.5, -4.5), Vector2(10, -1.5)]
		draw_colored_polygon(tri, C_ACCENT)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), C_OUTLINE, 0.4, true)


func _draw_tool(bob: float) -> void:
	var h: Vector2 = Vector2(HAND.x, HAND.y + bob)
	match activity:
		"repair":
			if _f % 6 < 3:
				# Clé levée : manche vertical, mâchoires en U vers le haut.
				_tool([[h + Vector2(0, -0.5), h + Vector2(0, -4.5)]], 1.2, C_STEEL_LIGHT)
				_tool([[h + Vector2(-1, -4.5), h + Vector2(-1, -6.5)], [h + Vector2(1, -4.5), h + Vector2(1, -6.5)]], 0.9, C_STEEL)
			else:
				# Clé abattue vers le vaisseau (les étincelles partent des mâchoires).
				_tool([[h + Vector2(0, -0.5), h + Vector2(4, -0.5)]], 1.2, C_STEEL_LIGHT)
				_tool([[h + Vector2(4, -1.5), h + Vector2(6, -1.5)], [h + Vector2(4, 0.5), h + Vector2(6, 0.5)]], 0.9, C_STEEL)
		"conceal":
			# Spatule de mastic qui va et vient.
			var dx: float = 1.0 if _f % 8 >= 4 else 0.0
			_tool([[h + Vector2(dx, -0.5), h + Vector2(dx + 1.8, -0.5)]], 1.0, C_HANDLE)
			_tool([[h + Vector2(dx + 2.6, -2), h + Vector2(dx + 2.6, 1)]], 1.6, C_STEEL_LIGHT)
			_line(h + Vector2(dx + 3.4, -0.8), h + Vector2(dx + 3.4, 0.2), C_PUTTY, 0.8)
		"paint":
			# Pistolet à peinture : corps, buse, godet à la couleur de la peinture, poignée.
			_tool([[h + Vector2(0, -1.5), h + Vector2(3, -1.5)]], 1.8, C_STEEL)
			_tool([[h + Vector2(3, -1.8), h + Vector2(4, -1.8)]], 0.8, C_STEEL_LIGHT)
			_tool([[h + Vector2(0.4, -0.5), h + Vector2(0, 1)]], 0.9, C_HANDLE)
			draw_circle(_m(h + Vector2(1.6, -3.4)), 1.4, C_OUTLINE, true, -1.0, true)
			draw_circle(_m(h + Vector2(1.6, -3.4)), 1.0, paint_color, true, -1.0, true)
		"bid", "sell", "research":
			# Tablette : cadre sombre, écran qui clignote au rythme de la frappe.
			var screen: Color = C_SCREEN_A if _f % 4 < 2 else C_SCREEN_B
			var r: Rect2 = Rect2(h + Vector2(-1.2, -2.6), Vector2(4.4, 3.2))
			if face_left:
				r.position.x = W - r.end.x
			draw_rect(r.grow(0.4), C_OUTLINE, true, -1.0, true)
			draw_rect(r, C_GLYPH, true, -1.0, true)
			draw_rect(r.grow(-0.8), screen, true, -1.0, true)
		"idle", "pause":
			# Tasse de café (le café fume, voir _step).
			var cup: Rect2 = Rect2(h + Vector2(0, -2), Vector2(3, 3))
			if face_left:
				cup.position.x = W - cup.end.x
			draw_rect(cup.grow(0.4), C_OUTLINE, true, -1.0, true)
			draw_rect(cup, C_CUP, true, -1.0, true)
			draw_rect(Rect2(cup.position, Vector2(3, 0.8)), C_WHITE, true, -1.0, true)
			draw_arc(_m(h + Vector2(3.4, -0.4)), 0.9, 0.0, TAU, 12, C_CUP, 0.6, true)


## Outil tenu en main : segments [a, b] d'épaisseur `w`, cernés d'un contour sombre.
func _tool(segs: Array, w: float, c: Color) -> void:
	for sg: Array in segs:
		_line(sg[0], sg[1], C_OUTLINE, w + 0.9)
	for sg: Array in segs:
		_line(sg[0], sg[1], c, w)


func _draw_bubble(g: String, bob: float) -> void:
	var f: Font = UIKit.display_font()
	var fs: int = 7
	var tw: float = f.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bw: float = maxf(7.0, tw + 4.0)
	var bh: float = 8.0
	# Le texte n'est jamais en miroir : bulle placée depuis son bord gauche réel.
	var left: float = W - 12.0 - bw if face_left else 12.0
	var top: float = -bh - 1.0 + bob
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = C_WHITE
	sb.border_color = C_OUTLINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.anti_aliasing = true
	var tail_x: float = left + (bw - 2.5 if face_left else 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 1.5, top + bh - 1), Vector2(tail_x + 1.5, top + bh - 1), Vector2(tail_x, top + bh + 1.8)]), C_OUTLINE)
	draw_style_box(sb, Rect2(left, top, bw, bh))
	draw_string(f, Vector2(left + (bw - tw) / 2.0, top + bh - 2.0), g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_GLYPH)
