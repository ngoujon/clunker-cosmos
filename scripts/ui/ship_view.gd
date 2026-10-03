class_name ShipView
extends Control
## Vaisseau composé de ses 4 pièces (points d'ancrage calculés depuis l'alpha, assets/ships/anchors.json),
## peinture par masque (zones peintes recolorées avec la rampe de la peinture, ombrage du rendu conservé) et
## calque d'usure sur la coque. En 2.5D, le vaisseau flotte au-dessus du sol (`floor_y`) : ombre douce portée,
## plus petite et plus pâle quand il monte.

const SHADER: Shader = preload("res://shaders/ship_part.gdshader")
const WEAR_BY_DEFECT: Dictionary = {"d_rust": "wear_rust", "d_dent": "wear_dent", "d_breach": "wear_dent", "d_plasma_leak": "wear_scorch", "d_misfire": "wear_scorch", "d_fuel_line": "wear_scorch"}
const WEAR_IDS: PackedStringArray = ["wear_scratch", "wear_rust", "wear_dent", "wear_scorch"]

static var _anchors: Dictionary = {}

var ship_id: int = -1
var bob: bool = false
var _root: Control = null
var _hull_mat: ShaderMaterial = null
var _wing_mat: ShaderMaterial = null
var _t: float = 0.0
## Sol sous le vaisseau (coordonnées locales, < 0 : pas d'ombre).
var floor_y: float = -1.0

static var _shadow_tex: GradientTexture2D = null


static func anchors() -> Dictionary:
	if _anchors.is_empty() and FileAccess.file_exists("res://assets/ships/anchors.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ships/anchors.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			_anchors = parsed
	return _anchors


static func _v(a: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(a) == TYPE_ARRAY and (a as Array).size() >= 2:
		return Vector2i(int(a[0]), int(a[1]))
	return fallback


static func part_texture(slot: String, id: String) -> Texture2D:
	var folder: String = {"hull": "hull", "engine": "engine", "cockpit": "cockpit", "wings": "wings"}.get(slot, slot)
	return UIKit.tex("res://assets/ships/%s/%s.png" % [folder, id])


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(s: Ship, db: ContentDB) -> void:
	ship_id = s.id
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var an: Dictionary = anchors()
	var ha: Dictionary = an.get(s.hull, {})
	var hull_size: Vector2i = _v(ha.get("size"), Vector2i(80, 34))
	var placed: Array[Dictionary] = []
	var eng: Dictionary = an.get(s.engine, {})
	placed.append({"slot": "engine", "id": s.engine, "pos": _v(ha.get("engine"), Vector2i(2, hull_size.y / 2)) - _v(eng.get("mount"), Vector2i(20, 9))})
	var cock: Dictionary = an.get(s.cockpit, {})
	placed.append({"slot": "cockpit", "id": s.cockpit, "pos": _v(ha.get("cockpit"), Vector2i(hull_size.x * 2 / 3, 4)) - _v(cock.get("mount"), Vector2i(12, 14))})
	placed.append({"slot": "hull", "id": s.hull, "pos": Vector2i.ZERO})
	var wing: Dictionary = an.get(s.wings, {})
	placed.append({"slot": "wings", "id": s.wings, "pos": _v(ha.get("wings"), Vector2i(hull_size.x * 2 / 5, hull_size.y / 2)) - _v(wing.get("mount"), Vector2i(15, 5))})
	var min_p: Vector2i = Vector2i(100000, 100000)
	var max_p: Vector2i = Vector2i(-100000, -100000)
	for p: Dictionary in placed:
		var tex: Texture2D = part_texture(str(p["slot"]), str(p["id"]))
		p["tex"] = tex
		var sz: Vector2i = Vector2i(tex.get_size()) if tex != null else Vector2i(8, 8)
		var pos: Vector2i = p["pos"]
		min_p = Vector2i(mini(min_p.x, pos.x), mini(min_p.y, pos.y))
		max_p = Vector2i(maxi(max_p.x, pos.x + sz.x), maxi(max_p.y, pos.y + sz.y))
	var ramp: Array[Color] = paint_ramp(db, s.paint)
	_hull_mat = null
	_wing_mat = null
	for p: Dictionary in placed:
		var tex2: Texture2D = p["tex"]
		if tex2 == null:
			continue
		var r: TextureRect = TextureRect.new()
		r.texture = tex2
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = Vector2(p["pos"] - min_p)
		r.size = tex2.get_size()
		var slot: String = str(p["slot"])
		if slot == "hull" or slot == "wings":
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = SHADER
			mat.set_shader_parameter("part_size", tex2.get_size())
			var mask: Texture2D = UIKit.tex("res://assets/ships/%s/%s_paint.png" % [slot, str(p["id"])])
			if mask != null:
				mat.set_shader_parameter("paint_mask", mask)
				mat.set_shader_parameter("use_paint", true)
			_apply_ramp(mat, ramp)
			if slot == "hull":
				_setup_wear(mat, s, db)
				_hull_mat = mat
			else:
				_wing_mat = mat
			r.material = mat
		_root.add_child(r)
	custom_minimum_size = Vector2(max_p - min_p)
	size = custom_minimum_size


static func paint_ramp(db: ContentDB, paint: String) -> Array[Color]:
	var out: Array[Color] = []
	for h: Variant in db.paints.get(paint, db.paints.get("paint_primer", {})).get("ramp", ["#3c4a3e", "#5d6e57", "#8a9a7a"]):
		out.append(Color(str(h)))
	while out.size() < 3:
		out.append(Color.GRAY)
	return out


static func _apply_ramp(mat: ShaderMaterial, ramp: Array[Color]) -> void:
	mat.set_shader_parameter("dst0", ramp[0])
	mat.set_shader_parameter("dst1", ramp[1])
	mat.set_shader_parameter("dst2", ramp[2])


func _setup_wear(mat: ShaderMaterial, s: Ship, _db: ContentDB) -> void:
	var wear_id: String = ""
	for d: ShipDefect in s.defects:
		if d.is_open() and d.known and WEAR_BY_DEFECT.has(d.type):
			wear_id = WEAR_BY_DEFECT[d.type]
			break
	if wear_id.is_empty():
		wear_id = WEAR_IDS[absi(s.visual_seed) % WEAR_IDS.size()]
	var wt: Texture2D = UIKit.tex("res://assets/ships/wear/%s.png" % wear_id)
	if wt == null or s.wear <= 0.02:
		return
	mat.set_shader_parameter("use_wear", true)
	mat.set_shader_parameter("wear_tex", wt)
	mat.set_shader_parameter("wear_tex_size", wt.get_size())
	mat.set_shader_parameter("wear_offset", Vector2(float(absi(s.visual_seed) % 37), float(absi(s.visual_seed / 37) % 19)))
	mat.set_shader_parameter("wear_amount", clampf(s.wear * 1.15, 0.0, 1.0))


func set_flash(v: float) -> void:
	for mat: ShaderMaterial in [_hull_mat, _wing_mat]:
		if mat != null:
			mat.set_shader_parameter("flash", v)


func set_tint(c: Color) -> void:
	if _root != null:
		_root.modulate = c
	for mat: ShaderMaterial in [_hull_mat, _wing_mat]:
		if mat != null:
			mat.set_shader_parameter("tint", c)


func _process(delta: float) -> void:
	if not bob or _root == null:
		return
	_t += delta
	_root.position.y = sin(_t * 1.7 + float(ship_id)) * 1.4 - 0.4
	if floor_y >= 0.0:
		queue_redraw()


## Ombre portée au sol : ellipse floue sous le vaisseau, réduite quand il s'élève.
func _draw() -> void:
	if floor_y < 0.0:
		return
	if _shadow_tex == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.55))
		g.set_color(1, Color(0, 0, 0, 0))
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.gradient = g
		_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_shadow_tex.fill_to = Vector2(1.0, 0.5)
		_shadow_tex.width = 128
		_shadow_tex.height = 32
	var lift: float = maxf(0.0, floor_y - size.y - (_root.position.y if _root != null else 0.0))
	var k: float = clampf(1.0 - lift / 40.0, 0.55, 1.0)
	var w: float = size.x * 0.95 * k
	var h: float = maxf(4.0, size.y * 0.32) * k
	draw_texture_rect(_shadow_tex, Rect2(size.x / 2.0 - w / 2.0, floor_y - h / 2.0, w, h), false, Color(1, 1, 1, k))
