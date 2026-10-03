class_name UIKit
extends RefCounted
## Thème (panneaux lisses aux coins arrondis, polices lissées) et fabriques de widgets pour l'UI construite en code.
## Le jeu est rendu en mode « canvas_items » : texte et images sont rastérisés à la résolution de la fenêtre.
## Les images (rendu 3D stylisé, version 2.5D) sont stockées à DETAIL fois leur taille logique et affichées à
## leur taille logique (filtrage linéaire et mipmaps) : elles restent nettes à toutes les tailles d'interface.

const FONT_PATH: String = "res://assets/fonts/BarlowSemiCondensed-Medium.ttf"
const DISPLAY_FONT_PATH: String = "res://assets/fonts/LilitaOne-Regular.ttf"
## Repli pour les symboles absents des deux polices (→ ● ○ ★…) : sous-ensemble de Noto Sans Math aux
## métriques de Barlow (tools/make_symbol_font.py), sinon toutes les lignes seraient plus hautes.
const SYMBOL_FONT_PATH: String = "res://assets/fonts/CosmosSymbols.ttf"
const C_TEXT: Color = Color("#f2f0e6")
const C_DIM: Color = Color("#8a8fa6")
const C_ACCENT: Color = Color("#f5dc6a")
const C_ORANGE: Color = Color("#d9652a")
const C_GOOD: Color = Color("#7ccf5e")
const C_BAD: Color = Color("#e8655a")
const C_BLUE: Color = Color("#5aa0e8")
const C_DARK: Color = Color("#0d0e14")
const C_PANEL: Color = Color("#1f2a5c")
const C_SLATE: Color = Color("#2a2b3d")
## Fond des panneaux (verre sombre légèrement bleuté) et liserés.
const C_GLASS: Color = Color(0.075, 0.09, 0.16, 0.93)
const C_GLASS_DARK: Color = Color(0.035, 0.045, 0.085, 0.88)
const C_EDGE: Color = Color(0.5, 0.6, 0.9, 0.32)
## Pixels d'image par pixel logique des assets (tools/hd_art.py, DETAIL).
const DETAIL: int = 4

static var _theme: Theme = null
static var _font: FontFile = null
static var _display_font: FontFile = null
static var _tex_cache: Dictionary = {}


static func font() -> FontFile:
	if _font == null:
		_font = _load_font(FONT_PATH)
	return _font


## Police des titres et du logo.
static func display_font() -> FontFile:
	if _display_font == null:
		_display_font = _load_font(DISPLAY_FONT_PATH)
		var fb: Array[Font] = [font()]
		_display_font.fallbacks = fb
	return _display_font


static func _load_font(path: String) -> FontFile:
	var f: FontFile = load(path) as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.allow_system_fallback = false
	var fb: Array[Font] = [load(SYMBOL_FONT_PATH) as FontFile]
	f.fallbacks = fb
	return f


## Texture d'un asset (images importées comme `Image` : décodage sur le processeur, sans relecture depuis la
## carte graphique). Préparée d'avance par `warmup` quand c'est possible, sinon tout de suite.
static func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var img: Image = null
	_warm_mutex.lock()
	if _warm_ready.has(path):
		img = _warm_ready[path]
		_warm_ready.erase(path)
	_warm_mutex.unlock()
	if img == null:
		img = prepare_image(path)
	var t: Texture2D = hd_texture(img)
	_tex_cache[path] = t
	return t


## Image prête à l'affichage (copie avec mipmaps), ou null. Sans état partagé : utilisable depuis un thread.
static func prepare_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var src: Image = load(path) as Image
	if src == null or src.is_empty():
		return null
	var img: Image = src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	if not img.has_mipmaps():
		img.generate_mipmaps()
	return img


## Texture HD affichée à sa taille logique (taille de l'image / DETAIL), avec mipmaps pour rester nette
## quand elle est réduite.
static func hd_texture(img: Image) -> Texture2D:
	if img == null:
		return null
	var it: ImageTexture = ImageTexture.create_from_image(img)
	it.set_size_override(Vector2i(maxi(1, img.get_width() / DETAIL), maxi(1, img.get_height() / DETAIL)))
	return it


## Préchargement : toutes les images de assets/ sont décodées (avec mipmaps) sur un thread de fond dès le
## lancement ; `pump_warmup` les envoie ensuite à la carte graphique par petits lots, dans un budget de temps
## par image. Ouvrir un écran pour la première fois ne provoque plus d'à-coup.
static var _warm_mutex: Mutex = Mutex.new()
static var _warm_ready: Dictionary = {}
static var _warm_task: int = -1


static func warmup() -> void:
	if _warm_task >= 0:
		return
	var paths: PackedStringArray = []
	_collect_pngs("res://assets", paths)
	_warm_task = WorkerThreadPool.add_task(func() -> void:
		for p: String in paths:
			var img: Image = prepare_image(p)
			if img == null:
				continue
			_warm_mutex.lock()
			_warm_ready[p] = img
			_warm_mutex.unlock(), false, "Préchargement des images")


## Fermeture du jeu : attend la fin du préchargement (aucun thread ne doit rester actif) et libère les textures.
static func warmup_finish() -> void:
	if _warm_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_warm_task)
		_warm_task = -1
	_warm_mutex.lock()
	_warm_ready.clear()
	_warm_mutex.unlock()
	_tex_cache.clear()


static func _collect_pngs(dir: String, out: PackedStringArray) -> void:
	for f: String in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			_collect_pngs(dir.path_join(f.trim_suffix("/")), out)
		elif f.ends_with(".png"):
			out.append(dir.path_join(f))


## Crée les textures des images préchargées, sans dépasser `budget_ms` millisecondes (à appeler à chaque image).
static func pump_warmup(budget_ms: float = 3.0) -> void:
	if _warm_task < 0:
		return
	var t0: int = Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - t0) / 1000.0 < budget_ms:
		var path: String = ""
		var img: Image = null
		_warm_mutex.lock()
		if not _warm_ready.is_empty():
			path = str(_warm_ready.keys()[0])
			img = _warm_ready[path]
			_warm_ready.erase(path)
		_warm_mutex.unlock()
		if img == null:
			break
		if not _tex_cache.has(path):
			_tex_cache[path] = hd_texture(img)


## Masque de peinture d'une pièce de vaisseau (<pièce>_paint.png, niveaux de gris), ou null.
static func paint_mask(path: String) -> Texture2D:
	return tex(path.get_basename() + "_paint.png")


static func icon(id: String) -> Texture2D:
	return tex("res://assets/icons/%s.png" % id)


static func portrait(id: String) -> Texture2D:
	return tex("res://assets/portraits/%s.png" % id)


## Portrait 24×24 (réduit depuis l'image source) ; à défaut, le 48×48.
static func portrait_small(id: String) -> Texture2D:
	var t: Texture2D = tex("res://assets/portraits/small/%s.png" % id)
	return t if t != null else portrait(id)


## Panneau lisse : fond, liseré d'un pixel, coins arrondis, ombre portée douce.
static func _panel_box(bg: Color, border: Color, radius: int = 4, shadow: int = 3, margin: int = 6) -> StyleBoxFlat:
	var f: StyleBoxFlat = StyleBoxFlat.new()
	f.bg_color = bg
	f.border_color = border
	f.set_border_width_all(1)
	f.set_corner_radius_all(radius)
	f.corner_detail = 6
	f.anti_aliasing = true
	f.shadow_color = Color(0, 0, 0, 0.35)
	f.shadow_size = shadow
	f.shadow_offset = Vector2(0, 1)
	f.content_margin_left = margin
	f.content_margin_right = margin
	f.content_margin_top = maxi(2, margin - 2)
	f.content_margin_bottom = maxi(2, margin - 2)
	return f


## Bouton lisse : bord inférieur plus épais (relief), coins arrondis.
static func _button_box(bg: Color, border: Color, margin: int = 4) -> StyleBoxFlat:
	var f: StyleBoxFlat = _panel_box(bg, border, 3, 0, margin)
	f.border_width_bottom = 2
	return f


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = font()
	t.default_font_size = 8
	var panel: StyleBox = _panel_box(C_GLASS, C_EDGE)
	var panel_dark: StyleBox = _panel_box(C_GLASS_DARK, Color(C_EDGE, 0.22), 4, 2)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PopupPanel", panel)
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", panel_dark)
	t.set_type_variation("FramePanel", "PanelContainer")
	t.set_stylebox("panel", "FramePanel", _panel_box(C_GLASS, Color(C_ACCENT, 0.75), 5, 5))
	t.set_stylebox("normal", "Button", _button_box(Color("#26325a"), Color("#4a5d94")))
	t.set_stylebox("hover", "Button", _button_box(Color("#33447a"), Color(C_ACCENT, 0.85)))
	t.set_stylebox("pressed", "Button", _button_box(Color("#1a2340"), C_ACCENT))
	t.set_stylebox("disabled", "Button", _button_box(Color("#171b29"), Color("#2c3247")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for b: String in ["Button", "OptionButton"]:
		t.set_color("font_color", b, C_TEXT)
		t.set_color("font_hover_color", b, C_ACCENT)
		t.set_color("font_pressed_color", b, C_ACCENT)
		t.set_color("font_disabled_color", b, C_DIM)
		t.set_constant("h_separation", b, 2)
	for s: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(s, "OptionButton", t.get_stylebox(s, "Button"))
	# Boutons sans icône : marges plus larges pour que le texte reste dans la zone sombre du 9-slice.
	t.set_type_variation("TextButton", "Button")
	for s: String in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBox = t.get_stylebox(s, "Button").duplicate()
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		t.set_stylebox(s, "TextButton", sb)
	t.set_color("font_color", "Label", C_TEXT)
	t.set_constant("line_spacing", "Label", 1)
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", display_font())
	t.set_font_size("font_size", "Title", 12)
	t.set_color("font_color", "Title", C_ACCENT)
	t.set_type_variation("Dim", "Label")
	t.set_color("font_color", "Dim", C_DIM)
	t.set_constant("separation", "HBoxContainer", 2)
	t.set_constant("separation", "VBoxContainer", 2)
	var sbg: StyleBoxFlat = _round(C_DARK, 2)
	var sfill: StyleBoxFlat = _round(C_GOOD, 2)
	t.set_stylebox("background", "ProgressBar", sbg)
	t.set_stylebox("fill", "ProgressBar", sfill)
	t.set_color("font_color", "ProgressBar", C_TEXT)
	t.set_stylebox("panel", "TooltipPanel", panel_dark)
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	var popup: StyleBoxFlat = _panel_box(Color("#1b2036"), C_EDGE, 3, 3, 2)
	popup.set_content_margin_all(2)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_ACCENT)
	var hov: StyleBoxFlat = _round(C_PANEL, 2)
	t.set_stylebox("hover", "PopupMenu", hov)
	var vs: StyleBoxFlat = _round(Color(C_DIM, 0.8), 2)
	vs.set_content_margin_all(1)
	t.set_stylebox("grabber", "VScrollBar", vs)
	t.set_stylebox("grabber_highlight", "VScrollBar", vs)
	t.set_stylebox("grabber_pressed", "VScrollBar", vs)
	var vsb: StyleBoxFlat = _round(Color(C_DARK, 0.6), 2)
	vsb.set_content_margin_all(1)
	t.set_stylebox("scroll", "VScrollBar", vsb)
	t.set_stylebox("scroll", "HScrollBar", vsb)
	t.set_stylebox("grabber", "HScrollBar", vs)
	# Curseurs (volumes) : piste sombre, partie remplie orange, poignée ronde.
	var track: StyleBoxFlat = _flat(C_DARK, C_DIM, 1, 0, 2)
	t.set_stylebox("slider", "HSlider", track)
	var filled: StyleBoxFlat = _flat(C_ORANGE, C_DIM, 1, 0, 2)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(C_ACCENT, C_DIM, 1, 0, 2))
	t.set_icon("grabber", "HSlider", _grabber_tex(C_TEXT))
	t.set_icon("grabber_highlight", "HSlider", _grabber_tex(C_ACCENT))
	t.set_icon("grabber_disabled", "HSlider", _grabber_tex(C_DIM))
	_compact_styles(t)
	_theme = t
	return t


## Poignée de curseur ronde (8×8 logiques, dessinée lissée à DETAIL fois cette taille, contour sombre).
static func _grabber_tex(c: Color) -> ImageTexture:
	var n: int = 8 * DETAIL
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r: float = n / 2.0
	for y: int in n:
		for x: int in n:
			var d: float = Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a: float = clampf(r - d, 0.0, 1.0)
			if a <= 0.0:
				continue
			var col: Color = C_DARK.lerp(c, clampf(r - DETAIL * 1.2 - d, 0.0, 1.0))
			col.a = a
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	var t: ImageTexture = ImageTexture.create_from_image(img)
	t.set_size_override(Vector2i(8, 8))
	return t


static func _round(bg: Color, radius: int) -> StyleBoxFlat:
	var f: StyleBoxFlat = StyleBoxFlat.new()
	f.bg_color = bg
	f.set_corner_radius_all(radius)
	f.anti_aliasing = true
	return f


static func _flat(bg: Color, border: Color, bw: int, ml: int, mt: int, radius: int = 2) -> StyleBoxFlat:
	var f: StyleBoxFlat = StyleBoxFlat.new()
	f.bg_color = bg
	f.border_color = border
	f.set_border_width_all(bw)
	f.set_corner_radius_all(radius)
	f.anti_aliasing = true
	f.content_margin_left = ml
	f.content_margin_right = ml
	f.content_margin_top = mt
	f.content_margin_bottom = mt
	return f


## Barres (haut/bas) et boutons compacts : la place est comptée en 480×270.
static func _compact_styles(t: Theme) -> void:
	var bar: StyleBoxFlat = _flat(Color(C_DARK, 0.9), Color(C_EDGE, 0.25), 0, 3, 1, 0)
	bar.border_width_bottom = 1
	bar.shadow_color = Color(0, 0, 0, 0.4)
	bar.shadow_size = 4
	t.set_type_variation("BarPanel", "PanelContainer")
	t.set_stylebox("panel", "BarPanel", bar)
	var nav: StyleBoxFlat = _flat(Color(C_DARK, 0.9), Color(C_EDGE, 0.25), 0, 1, 1, 0)
	nav.border_width_top = 1
	nav.shadow_color = Color(0, 0, 0, 0.4)
	nav.shadow_size = 4
	t.set_type_variation("NavPanel", "PanelContainer")
	t.set_stylebox("panel", "NavPanel", nav)
	t.set_type_variation("IconButton", "Button")
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.set_content_margin_all(1)
	t.set_stylebox("normal", "IconButton", empty)
	t.set_stylebox("disabled", "IconButton", empty)
	t.set_stylebox("hover", "IconButton", _flat(Color(C_PANEL, 0.5), C_DIM, 1, 1, 1))
	t.set_stylebox("pressed", "IconButton", _flat(C_PANEL, C_ACCENT, 1, 1, 1))
	t.set_stylebox("hover_pressed", "IconButton", _flat(C_PANEL, C_ACCENT, 1, 1, 1))
	t.set_type_variation("NavButton", "Button")
	t.set_stylebox("normal", "NavButton", _flat(C_SLATE, C_DARK, 1, 3, 1))
	t.set_stylebox("hover", "NavButton", _flat(C_PANEL, C_DIM, 1, 3, 1))
	t.set_stylebox("pressed", "NavButton", _flat(C_PANEL, C_ACCENT, 1, 3, 1))
	t.set_stylebox("hover_pressed", "NavButton", _flat(C_PANEL, C_ACCENT, 1, 3, 1))
	t.set_stylebox("disabled", "NavButton", _flat(C_DARK, C_SLATE, 1, 3, 1))
	t.set_color("font_pressed_color", "NavButton", C_ACCENT)
	t.set_color("font_hover_pressed_color", "NavButton", C_ACCENT)


# --- Fabriques -----------------------------------------------------------------

static func label(text: String, color: Color = C_TEXT, variation: String = "") -> Label:
	var l: Label = Label.new()
	l.text = text
	if variation.is_empty():
		l.add_theme_color_override("font_color", color)
	else:
		l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, width: int, color: Color = C_TEXT) -> Label:
	var l: Label = label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


## Bouton avec bruitage de clic (`sfx`, vide = muet) et léger son au survol.
static func button(text: String, cb: Callable, icon_id: String = "", tooltip: String = "", sfx: String = "ui_click") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if not icon_id.is_empty():
		b.icon = icon(icon_id)
	else:
		b.theme_type_variation = "TextButton"
	if not tooltip.is_empty():
		b.tooltip_text = tooltip
	if not sfx.is_empty():
		b.pressed.connect(func() -> void: Audio.play(sfx, 0.04))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Audio.play("ui_hover", 0.05))
	b.pressed.connect(cb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## Curseur 0-100 % (volumes) ; `cb` reçoit la valeur entre 0 et 1.
static func slider(value: float, cb: Callable, width: int = 90) -> HSlider:
	var s: HSlider = HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 5.0
	s.value = roundf(value * 100.0)
	s.custom_minimum_size = Vector2(width, 10)
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	s.value_changed.connect(func(v: float) -> void: cb.call(v / 100.0))
	return s


## Infobulle riche : première ligne en titre (couleur d'accent), suite avec retour à la ligne.
static func rich_tooltip(text: String, width: int = 200) -> Control:
	var parts: PackedStringArray = text.split("\n", true, 1)
	var v: VBoxContainer = vbox([], 1)
	v.add_child(label(parts[0], C_ACCENT))
	if parts.size() > 1:
		v.add_child(wrap_label(parts[1], width, C_TEXT))
	return v


static func icon_rect(id: String, size: int = 16) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = icon(id)
	r.custom_minimum_size = Vector2(size, size)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


## Agrandissement entier des aperçus (vaisseau des fiches) : celui des décors quand l'interface est fine
## (voir ViewScale), 1 en 480×270.
static func art_zoom() -> int:
	return maxi(1, floori(MainUI.cover_rect(Vector2(MainUI.W, MainUI.H)).size.x / float(MainUI.BASE_W) + 0.001))


## Enveloppe un visuel (taille fixe, ex. ShipView) agrandi d'un facteur entier pour les conteneurs.
static func zoomed(c: Control, f: int) -> Control:
	if f <= 1:
		return c
	var box: Control = Control.new()
	box.custom_minimum_size = c.get_combined_minimum_size() * float(f)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.scale = Vector2(f, f)
	box.add_child(c)
	return box


static func portrait_rect(id: String, scale_factor: int = 1) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = portrait(id)
	r.custom_minimum_size = Vector2(48, 48) * float(scale_factor)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


static func hbox(children: Array = [], sep: int = 2) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for c: Variant in children:
		h.add_child(c as Node)
	return h


static func vbox(children: Array = [], sep: int = 2) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	for c: Variant in children:
		v.add_child(c as Node)
	return v


static func panel(child: Control, variation: String = "") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	if not variation.is_empty():
		p.theme_type_variation = variation
	p.add_child(child)
	return p


static func bar(value: float, max_value: float, color: Color, width: int = 40, height: int = 4) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(width, height)
	b.add_theme_stylebox_override("fill", _round(color, 2))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func spacer(w: int = 0, h: int = 0, expand: bool = false) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(w, h)
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func scroll(child: Control, min_size: Vector2) -> ScrollContainer:
	var s: ScrollContainer = ScrollContainer.new()
	s.custom_minimum_size = min_size
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func color_swatch(c: Color, size: int = 8) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = c
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


static func clear(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func credits(v: int) -> String:
	return Util.fmt_credits(v)


static func sev_dots(sev: int) -> String:
	return "●".repeat(sev) + "○".repeat(maxi(0, 3 - sev))
