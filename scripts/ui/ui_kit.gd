class_name UIKit
extends RefCounted
## Thème pixel (9-slice générés + police Tiny5) et fabriques de widgets pour l'UI construite en code.

const FONT_PATH: String = "res://assets/fonts/Tiny5-Regular.ttf"
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

static var _theme: Theme = null
static var _font: FontFile = null
static var _tex_cache: Dictionary = {}


static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH) as FontFile
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.force_autohinter = false
	return _font


static func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex_cache[path] = t
	return t


static func icon(id: String) -> Texture2D:
	return tex("res://assets/icons/%s.png" % id)


static func portrait(id: String) -> Texture2D:
	return tex("res://assets/portraits/%s.png" % id)


## Portrait 24×24 (réduit depuis l'image source) ; à défaut, le 48×48.
static func portrait_small(id: String) -> Texture2D:
	var t: Texture2D = tex("res://assets/portraits/small/%s.png" % id)
	return t if t != null else portrait(id)


static func _box(path: String, margin: int, fallback: Color, border: Color) -> StyleBox:
	var t: Texture2D = tex(path)
	if t != null:
		var sb: StyleBoxTexture = StyleBoxTexture.new()
		sb.texture = t
		sb.texture_margin_left = margin
		sb.texture_margin_right = margin
		sb.texture_margin_top = margin
		sb.texture_margin_bottom = margin
		sb.content_margin_left = margin
		sb.content_margin_right = margin
		sb.content_margin_top = maxi(2, margin - 2)
		sb.content_margin_bottom = maxi(2, margin - 2)
		return sb
	var f: StyleBoxFlat = StyleBoxFlat.new()
	f.bg_color = fallback
	f.border_color = border
	f.set_border_width_all(1)
	f.set_content_margin_all(3)
	return f


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = font()
	t.default_font_size = 8
	var panel: StyleBox = _box("res://assets/ui/panel.png", 6, C_PANEL, C_DIM)
	var panel_dark: StyleBox = _box("res://assets/ui/panel_dark.png", 6, C_SLATE, C_DARK)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PopupPanel", panel)
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", panel_dark)
	t.set_type_variation("FramePanel", "PanelContainer")
	t.set_stylebox("panel", "FramePanel", _box("res://assets/ui/frame.png", 6, C_SLATE, C_ACCENT))
	var bn: StyleBox = _box("res://assets/ui/button.png", 4, C_SLATE, C_DIM)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", _box("res://assets/ui/button_hover.png", 4, C_PANEL, C_ACCENT))
	t.set_stylebox("pressed", "Button", _box("res://assets/ui/button_pressed.png", 4, C_DARK, C_ACCENT))
	t.set_stylebox("disabled", "Button", _box("res://assets/ui/button_disabled.png", 4, C_DARK, C_SLATE))
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
	t.set_font_size("font_size", "Title", 16)
	t.set_color("font_color", "Title", C_ACCENT)
	t.set_type_variation("Dim", "Label")
	t.set_color("font_color", "Dim", C_DIM)
	t.set_constant("separation", "HBoxContainer", 2)
	t.set_constant("separation", "VBoxContainer", 2)
	var sbg: StyleBoxFlat = StyleBoxFlat.new()
	sbg.bg_color = C_DARK
	var sfill: StyleBoxFlat = StyleBoxFlat.new()
	sfill.bg_color = C_GOOD
	t.set_stylebox("background", "ProgressBar", sbg)
	t.set_stylebox("fill", "ProgressBar", sfill)
	t.set_color("font_color", "ProgressBar", C_TEXT)
	t.set_stylebox("panel", "TooltipPanel", panel_dark)
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	var popup: StyleBoxFlat = StyleBoxFlat.new()
	popup.bg_color = C_SLATE
	popup.border_color = C_DIM
	popup.set_border_width_all(1)
	popup.set_content_margin_all(2)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_ACCENT)
	var hov: StyleBoxFlat = StyleBoxFlat.new()
	hov.bg_color = C_PANEL
	t.set_stylebox("hover", "PopupMenu", hov)
	var vs: StyleBoxFlat = StyleBoxFlat.new()
	vs.bg_color = C_DIM
	vs.set_content_margin_all(1)
	t.set_stylebox("grabber", "VScrollBar", vs)
	t.set_stylebox("grabber_highlight", "VScrollBar", vs)
	t.set_stylebox("grabber_pressed", "VScrollBar", vs)
	var vsb: StyleBoxFlat = StyleBoxFlat.new()
	vsb.bg_color = C_DARK
	vsb.set_content_margin_all(1)
	t.set_stylebox("scroll", "VScrollBar", vsb)
	t.set_stylebox("scroll", "HScrollBar", vsb)
	t.set_stylebox("grabber", "HScrollBar", vs)
	_compact_styles(t)
	_theme = t
	return t


static func _flat(bg: Color, border: Color, bw: int, ml: int, mt: int) -> StyleBoxFlat:
	var f: StyleBoxFlat = StyleBoxFlat.new()
	f.bg_color = bg
	f.border_color = border
	f.set_border_width_all(bw)
	f.content_margin_left = ml
	f.content_margin_right = ml
	f.content_margin_top = mt
	f.content_margin_bottom = mt
	return f


## Barres (haut/bas) et boutons compacts : la place est comptée en 480×270.
static func _compact_styles(t: Theme) -> void:
	var bar: StyleBoxFlat = _flat(C_DARK, C_SLATE, 0, 3, 1)
	bar.border_width_bottom = 1
	t.set_type_variation("BarPanel", "PanelContainer")
	t.set_stylebox("panel", "BarPanel", bar)
	var nav: StyleBoxFlat = _flat(C_DARK, C_SLATE, 0, 1, 1)
	nav.border_width_top = 1
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


static func button(text: String, cb: Callable, icon_id: String = "", tooltip: String = "") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if not icon_id.is_empty():
		b.icon = icon(icon_id)
	else:
		b.theme_type_variation = "TextButton"
	if not tooltip.is_empty():
		b.tooltip_text = tooltip
	b.pressed.connect(cb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func icon_rect(id: String, size: int = 16) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = icon(id)
	r.custom_minimum_size = Vector2(size, size)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


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
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
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
