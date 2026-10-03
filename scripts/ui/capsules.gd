extends Node
## Visuels de la page Steam (capsules, fond de page, logo, icônes) composés avec les vrais assets du jeu :
## décors de lieux, vaisseaux peints par le shader du jeu, logo en Lilita One. Chaque visuel est composé
## dans un SubViewport en coordonnées « pixel » (taille de base) étirées d'un facteur entier jusqu'à la
## taille exigée par Steam : les images HD restent nettes (filtrage linéaire, mipmaps) et le logo est rastérisé à la taille finale.
##   godot --path . res://scenes/main.tscn -- --tour=capsules --out=docs/steam/capsules
## (voir tools/steam_assets.py, qui ajoute ensuite l'icône .ico et icon.svg).

## Vaisseaux de vitrine : une épave d'origine (apprêt, très usée) et des modèles remis à neuf.
const SHIPS: Array[Dictionary] = [
	{"hull": "hull_fighter", "engine": "eng_plasma", "cockpit": "cock_bubble", "wings": "wing_delta", "paint": "paint_primer", "wear": 0.9},
	{"hull": "hull_fighter", "engine": "eng_plasma", "cockpit": "cock_bubble", "wings": "wing_delta", "paint": "paint_red", "wear": 0.0},
	{"hull": "hull_yacht", "engine": "eng_ion", "cockpit": "cock_lounge", "wings": "wing_swept", "paint": "paint_blue", "wear": 0.0},
	{"hull": "hull_explorer", "engine": "eng_fusion", "cockpit": "cock_crystal", "wings": "wing_solar", "paint": "paint_yellow", "wear": 0.0},
	{"hull": "hull_courier", "engine": "eng_twin", "cockpit": "cock_visor", "wings": "wing_stub", "paint": "paint_green", "wear": 0.0},
	{"hull": "hull_cargo", "engine": "eng_warp", "cockpit": "cock_armored", "wings": "wing_solar", "paint": "paint_teal", "wear": 0.3},
]

## Taille de base (pixels du jeu) × échelle = taille Steam. bg : décor, agrandi d'un facteur entier
## (bg_k) et recadré (bg_anchor : point du décor gardé au centre). ships : [indice, x, y, échelle]
## en fractions de la taille. logo : "line", "two" ou "".
const SPECS: Array[Dictionary] = [
	{"file": "header_capsule_920x430", "size": Vector2i(460, 215), "scale": 2, "bg": "loc_ferropolis", "bg_k": 1, "bg_anchor": Vector2(0.5, 0.55),
	 "logo": "line", "logo_y": 0.21, "logo_w": 0.86, "logo_h": 0.34, "ships": [[0, 0.25, 0.66, 2], [1, 0.75, 0.66, 2]]},
	{"file": "small_capsule_462x174", "size": Vector2i(231, 87), "scale": 2, "bg": "loc_ferropolis", "bg_k": 1, "bg_anchor": Vector2(0.5, 0.45),
	 "logo": "two", "logo_y": 0.5, "logo_w": 0.92, "logo_h": 0.92, "ships": []},
	{"file": "main_capsule_1232x706", "size": Vector2i(616, 353), "scale": 2, "bg": "loc_ferropolis", "bg_k": 2, "bg_anchor": Vector2(0.5, 0.5),
	 "logo": "line", "logo_y": 0.15, "logo_w": 0.82, "logo_h": 0.28, "ships": [[0, 0.24, 0.6, 2], [1, 0.74, 0.6, 2], [2, 0.3, 0.86, 1], [3, 0.7, 0.87, 1]]},
	{"file": "vertical_capsule_748x896", "size": Vector2i(374, 448), "scale": 2, "bg": "loc_nebula", "bg_k": 2, "bg_anchor": Vector2(0.45, 0.5),
	 "logo": "two", "logo_y": 0.17, "logo_w": 0.88, "logo_h": 0.3, "ships": [[0, 0.5, 0.5, 2], [1, 0.5, 0.78, 2]]},
	{"file": "library_capsule_600x900", "size": Vector2i(300, 450), "scale": 2, "bg": "loc_nebula", "bg_k": 2, "bg_anchor": Vector2(0.45, 0.5),
	 "logo": "two", "logo_y": 0.17, "logo_w": 0.9, "logo_h": 0.3, "ships": [[0, 0.5, 0.5, 2], [1, 0.5, 0.78, 2]]},
	{"file": "library_hero_3840x1240", "size": Vector2i(960, 310), "scale": 4, "bg": "loc_ferropolis", "bg_k": 2, "bg_anchor": Vector2(0.5, 0.52),
	 "logo": "", "ships": [[0, 0.12, 0.62, 2], [1, 0.36, 0.48, 2], [2, 0.62, 0.66, 2], [3, 0.87, 0.5, 2]]},
	{"file": "library_logo_1280x176", "size": Vector2i(320, 44), "scale": 4, "bg": "", "logo": "line", "logo_y": 0.5, "logo_w": 0.98, "logo_h": 1.0, "ships": []},
	{"file": "page_background_1438x810", "size": Vector2i(719, 405), "scale": 2, "bg": "loc_kryo7", "bg_k": 2, "bg_anchor": Vector2(0.5, 0.5),
	 "logo": "", "dim": 0.35, "ships": []},
	{"file": "community_icon_184x184", "size": Vector2i(46, 46), "scale": 4, "bg": "", "portrait": "story_bolt", "ships": []},
	{"file": "icon_256x256", "size": Vector2i(64, 64), "scale": 4, "bg": "", "portrait": "story_bolt", "rounded": true, "ships": []},
]

var main: MainUI = null
var tour: Node = null


func run(p_main: MainUI, p_tour: Node) -> void:
	main = p_main
	tour = p_tour
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = str(tour.args.get("out", ProjectSettings.globalize_path("res://docs/steam/capsules")))
	DirAccess.make_dir_recursive_absolute(out_dir)
	for spec: Dictionary in SPECS:
		var img: Image = await _render(spec)
		var path: String = out_dir.path_join(str(spec["file"]) + ".png")
		img.save_png(path)
		print("capsule : ", path, " ", img.get_width(), "x", img.get_height())
	get_tree().quit(0)


func _render(spec: Dictionary) -> Image:
	var size: Vector2i = spec["size"]
	var k: int = int(spec["scale"])
	var transparent: bool = str(spec.get("bg", "")).is_empty()
	var sv: SubViewport = SubViewport.new()
	sv.size = size * k
	sv.size_2d_override = size
	sv.size_2d_override_stretch = true
	sv.oversampling_override = float(k)
	sv.transparent_bg = transparent
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sv.snap_2d_transforms_to_pixel = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var root: Control = Control.new()
	root.size = Vector2(size)
	root.theme = UIKit.theme()
	sv.add_child(root)
	_compose(root, spec)
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	sv.queue_free()
	return img


func _compose(root: Control, spec: Dictionary) -> void:
	var W: float = root.size.x
	var H: float = root.size.y
	var bg_id: String = str(spec.get("bg", ""))
	if not bg_id.is_empty():
		var tex: Texture2D = UIKit.tex("res://assets/backgrounds/%s.png" % bg_id)
		var k: int = int(spec.get("bg_k", 1))
		var bg: TextureRect = TextureRect.new()
		bg.texture = tex
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.size = Vector2(MainUI.BASE_W * k, MainUI.BASE_H * k)
		var anchor: Vector2 = spec.get("bg_anchor", Vector2(0.5, 0.5))
		bg.position = (Vector2(W, H) / 2.0 - bg.size * anchor).round()
		bg.position = bg.position.clamp(Vector2(W, H) - bg.size, Vector2.ZERO)
		root.add_child(bg)
	if spec.has("dim"):
		var dim: ColorRect = ColorRect.new()
		dim.color = Color(UIKit.C_DARK, float(spec["dim"]))
		dim.size = root.size
		root.add_child(dim)
	if spec.has("portrait"):
		_portrait(root, str(spec["portrait"]), bool(spec.get("rounded", false)))
	for sh: Array in spec.get("ships", []):
		_ship(root, SHIPS[int(sh[0])], Vector2(float(sh[1]) * W, float(sh[2]) * H), int(sh[3]))
	var logo_y: float = float(spec.get("logo_y", 0.2)) * H
	var logo_w: float = float(spec.get("logo_w", 0.9)) * W
	var logo_h: float = float(spec.get("logo_h", 1.0)) * H
	match str(spec.get("logo", "")):
		"line":
			_logo(root, [I18n.t("ui.title")], logo_y, logo_w, logo_h, not bg_id.is_empty())
		"two":
			var words: PackedStringArray = I18n.t("ui.title").split(" ")
			var cut: int = words.size() - 1
			_logo(root, [" ".join(words.slice(0, cut)), " ".join(words.slice(cut))], logo_y, logo_w, logo_h, not bg_id.is_empty())


func _ship(root: Control, d: Dictionary, center: Vector2, k: int) -> void:
	var s: Ship = Ship.new()
	s.hull = str(d["hull"])
	s.engine = str(d["engine"])
	s.cockpit = str(d["cockpit"])
	s.wings = str(d["wings"])
	s.paint = str(d["paint"])
	s.wear = float(d["wear"])
	s.visual_seed = 7
	var v: ShipView = ShipView.new()
	v.setup(s, Content.db)
	v.scale = Vector2(k, k)
	v.position = (center - v.size * float(k) / 2.0).round()
	root.add_child(v)


## Logo : la plus grande taille de Lilita One qui tient dans `max_w` × `max_h`. Lilita One à la taille fs :
## capitales de 0,7 fs (pas de jambages dans le titre) ; interligne serré de 0,92 fs ; bandeau sombre
## avec une marge de 0,3 fs autour des lettres.
const CAP: float = 0.7
const LEADING: float = 0.92
const PAD: float = 0.3


func _logo(root: Control, lines: Array, center_y: float, max_w: float, max_h: float, band: bool) -> void:
	var font: Font = UIKit.display_font()
	var n: int = lines.size()
	var fs: int = 8
	for cand: int in range(8, 400):
		var widest: float = 0.0
		for ln: Variant in lines:
			widest = maxf(widest, font.get_string_size(str(ln), HORIZONTAL_ALIGNMENT_LEFT, -1, cand).x)
		var block: float = float(cand) * (LEADING * float(n - 1) + CAP + (PAD * 2.0 if band else 0.1))
		if widest + float(cand) * 0.3 <= max_w and block <= max_h:
			fs = cand
	var f: float = float(fs)
	var block_h: float = f * (LEADING * float(n - 1) + CAP)
	var top: float = round(center_y - block_h / 2.0)
	if band:
		var pad: float = round(f * PAD)
		var strip: ColorRect = ColorRect.new()
		strip.color = Color(UIKit.C_DARK, 0.62)
		strip.position = Vector2(0, top - pad)
		strip.size = Vector2(root.size.x, block_h + pad * 2.0)
		root.add_child(strip)
		for y: float in [top - pad - 1.0, top + block_h + pad]:
			var edge: ColorRect = ColorRect.new()
			edge.color = UIKit.C_ACCENT
			edge.position = Vector2(0, y)
			edge.size = Vector2(root.size.x, 1)
			root.add_child(edge)
	var ascent: float = font.get_ascent(fs)
	for i: int in n:
		var l: Label = UIKit.label(str(lines[i]), UIKit.C_ACCENT)
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_constant_override("line_spacing", 0)
		l.add_theme_color_override("font_outline_color", UIKit.C_DARK)
		l.add_theme_constant_override("outline_size", maxi(2, int(f / 10.0)))
		l.add_theme_color_override("font_shadow_color", UIKit.C_DARK)
		var off: int = maxi(1, int(f / 18.0))
		l.add_theme_constant_override("shadow_offset_x", off)
		l.add_theme_constant_override("shadow_offset_y", off)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		# Haut des capitales de la ligne i à top + i × interligne : ligne de base = haut des capitales + 0,7 fs.
		l.position = Vector2(0, top + f * LEADING * float(i) + f * CAP - ascent)
		l.size = Vector2(root.size.x, font.get_height(fs))
		root.add_child(l)


## Icône : portrait de BOLT (l'IA du garage) sur fond de panneau, coins arrondis en option.
func _portrait(root: Control, id: String, rounded: bool) -> void:
	var W: float = root.size.x
	var H: float = root.size.y
	var back: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UIKit.C_PANEL
	sb.border_color = UIKit.C_ACCENT
	sb.set_border_width_all(2 if rounded else 0)
	sb.set_corner_radius_all(10 if rounded else 0)
	sb.anti_aliasing = false
	back.add_theme_stylebox_override("panel", sb)
	back.size = root.size
	root.add_child(back)
	var r: TextureRect = TextureRect.new()
	r.texture = UIKit.portrait(id)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size = Vector2(48, 48)
	r.position = ((Vector2(W, H) - r.size) / 2.0).round()
	root.add_child(r)
