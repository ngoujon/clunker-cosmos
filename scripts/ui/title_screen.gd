class_name TitleScreen
extends Control
## Écran titre : continuer, nouvelle partie (mode Histoire ou Classique), tutoriel, paramètres,
## quitter, et bascule rapide de langue.
## Une petite parade de vaisseaux générés aléatoirement anime le fond.

var main: MainUI = null
var _mode_info: Label
var _ships: Array[ShipView] = []
var _t: float = 0.0
## Parade et logo suivent l'échelle du décor (pixels nets, comme à 480×270) ; le menu, celle de l'interface.
var _art_scale: float = 1.0
var _parade: Control = null


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(MainUI.W, MainUI.H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var W: float = size.x
	var H: float = size.y
	_art_scale = MainUI.cover_rect(size).size.x / float(MainUI.BASE_W)
	var s: float = _art_scale
	_build_parade()
	var title: Label = UIKit.label(I18n.t("ui.title"), UIKit.C_ACCENT)
	title.add_theme_font_override("font", UIKit.display_font())
	title.add_theme_font_size_override("font_size", roundi(40 * s))
	title.add_theme_color_override("font_shadow_color", UIKit.C_DARK)
	title.add_theme_constant_override("shadow_offset_x", roundi(2 * s))
	title.add_theme_constant_override("shadow_offset_y", roundi(2 * s))
	title.add_theme_color_override("font_outline_color", UIKit.C_DARK)
	title.add_theme_constant_override("outline_size", roundi(4 * s))
	title.position = Vector2(0, roundf(12 * s))
	title.size = Vector2(W, roundf(46 * s))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub: Label = UIKit.label(I18n.t("ui.subtitle"), UIKit.C_TEXT)
	sub.add_theme_font_size_override("font_size", roundi(8 * s))
	sub.add_theme_color_override("font_shadow_color", UIKit.C_DARK)
	sub.add_theme_constant_override("shadow_offset_x", roundi(s))
	sub.add_theme_constant_override("shadow_offset_y", roundi(s))
	sub.add_theme_color_override("font_outline_color", UIKit.C_DARK)
	sub.add_theme_constant_override("outline_size", roundi(3 * s))
	sub.position = Vector2(0, roundf(58 * s))
	sub.size = Vector2(W, roundf(10 * s))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	var menu: VBoxContainer = UIKit.vbox([], 3)
	if Game.has_save() and Game.persist:
		menu.add_child(_menu_button("ui.menu.continue", _continue, "ui_play"))
	menu.add_child(_menu_button("ui.menu.new_story", func() -> void: _new_game(true), "ui_quests", "ui.menu.story_desc"))
	menu.add_child(_menu_button("ui.menu.new_classic", func() -> void: _new_game(false), "ui_garage", "ui.menu.classic_desc"))
	menu.add_child(_menu_button("ui.menu.tutorial", func() -> void: main.open_tutorial(), "ui_research", "ui.menu.tutorial_desc"))
	menu.add_child(_menu_button("ui.menu.settings", func() -> void: main.open_settings(), "ui_settings", "ui.menu.settings_desc"))
	menu.add_child(_menu_button("ui.menu.quit", func() -> void: main.quit_game(), ""))
	# Interface très fine (petit facteur) : le menu reste à l'échelle du logo (jamais plus petit que la
	# moitié du décor), agrandi d'un nombre entier de pixels d'écran pour rester net.
	var ms: float = maxf(1.0, floorf(_art_scale / 2.0 * MainUI.K) / float(MainUI.K))
	var panel: PanelContainer = UIKit.panel(menu, "DarkPanel")
	panel.custom_minimum_size = Vector2(170, 0)
	add_child(panel)
	panel.reset_size()
	panel.scale = Vector2(ms, ms)
	panel.position = Vector2(floorf((W - 170 * ms) / 2.0), floorf(H - (18 + panel.size.y) * ms))
	# Bascule rapide de langue (aussi dans les paramètres).
	var langs: HBoxContainer = UIKit.hbox([], 2)
	for loc: String in ["fr", "en"]:
		var code: String = loc
		var lb: Button = UIKit.button(loc.to_upper(), func() -> void: I18n.set_locale(code), "", I18n.t("ui.settings.lang_" + loc))
		lb.toggle_mode = true
		lb.set_pressed_no_signal(I18n.locale == loc)
		langs.add_child(lb)
	add_child(langs)
	langs.reset_size()
	langs.scale = Vector2(ms, ms)
	langs.position = (Vector2(W, H) - (langs.size + Vector2(4, 4)) * ms).floor()
	_mode_info = UIKit.wrap_label("", 300, UIKit.C_DIM)
	_mode_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_info.scale = Vector2(ms, ms)
	_mode_info.position = Vector2(floorf((W - 300 * ms) / 2.0), floorf(H - 18 * ms))
	_mode_info.size = Vector2(300, 10)
	add_child(_mode_info)
	var ver: Label = UIKit.label("v" + str(ProjectSettings.get_setting("application/config/version", "0.1")), UIKit.C_DIM)
	ver.position = Vector2(4, H - 12)
	add_child(ver)


func _menu_button(key: String, cb: Callable, icon_id: String, desc_key: String = "") -> Button:
	var b: Button = UIKit.button(I18n.t(key), cb, icon_id)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 20)
	if not desc_key.is_empty():
		b.mouse_entered.connect(func() -> void: _mode_info.text = I18n.t(desc_key))
		b.mouse_exited.connect(func() -> void: _mode_info.text = "")
	return b


func _build_parade() -> void:
	_parade = Control.new()
	_parade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parade.scale = Vector2(_art_scale, _art_scale)
	add_child(_parade)
	var demo: GameModel = GameModel.create(Content.db, 4242, false)
	var picks: Array[Ship] = []
	for l: AuctionLot in demo.lots:
		picks.append(l.ship)
	for i: int in 3:
		picks.append(ShipFactory.make_wreck(demo, "ferropolis", i == 1))
	var paints: PackedStringArray = ["paint_red", "paint_blue", "paint_yellow", "paint_green", "paint_white"]
	var x: int = 6
	var i2: int = 0
	for s: Ship in picks:
		if i2 >= 4:
			break
		s.paint = paints[i2 % paints.size()]
		s.wear = 0.1 + 0.2 * float(i2 % 2)
		var v: ShipView = ShipView.new()
		v.setup(s, Content.db)
		v.bob = true
		v.position = Vector2(x, 84 + (i2 % 2) * 22)
		_parade.add_child(v)
		_ships.append(v)
		x += int(v.size.x) + 10
		i2 += 1


## Largeur visible de la parade (pixels d'image).
func _parade_width() -> float:
	return size.x / _art_scale


func _process(delta: float) -> void:
	_t += delta
	for i: int in _ships.size():
		var v: ShipView = _ships[i]
		v.position.x += delta * 10.0
		if v.position.x > _parade_width() + 10:
			v.position.x = -v.size.x - 10


func _continue() -> void:
	if Game.load_game():
		main.start_game()


func _new_game(story: bool) -> void:
	if Game.has_save():
		main.confirm(I18n.t("ui.menu.overwrite"), func() -> void: _start(story))
	else:
		_start(story)


func _start(story: bool) -> void:
	Game.new_game(story)
	main.start_game()
