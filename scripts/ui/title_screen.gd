class_name TitleScreen
extends Control
## Écran titre : continuer, nouvelle partie (mode Histoire ou Classique), langue, quitter.
## Une petite parade de vaisseaux générés aléatoirement anime le fond.

var main: MainUI = null
var _mode_info: Label
var _ships: Array[ShipView] = []
var _t: float = 0.0


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(MainUI.W, MainUI.H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_parade()
	var title: Label = UIKit.label(I18n.t("ui.title"), UIKit.C_ACCENT)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_shadow_color", UIKit.C_DARK)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.position = Vector2(0, 22)
	title.size = Vector2(MainUI.W, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub: Label = UIKit.label(I18n.t("ui.subtitle"), UIKit.C_TEXT)
	sub.add_theme_color_override("font_shadow_color", UIKit.C_DARK)
	sub.add_theme_constant_override("shadow_offset_x", 1)
	sub.add_theme_constant_override("shadow_offset_y", 1)
	sub.position = Vector2(0, 60)
	sub.size = Vector2(MainUI.W, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	var menu: VBoxContainer = UIKit.vbox([], 3)
	if Game.has_save():
		menu.add_child(_menu_button("ui.menu.continue", _continue, "ui_play"))
	menu.add_child(_menu_button("ui.menu.new_story", func() -> void: _new_game(true), "ui_quests", "ui.menu.story_desc"))
	menu.add_child(_menu_button("ui.menu.new_classic", func() -> void: _new_game(false), "ui_garage", "ui.menu.classic_desc"))
	menu.add_child(_menu_button("ui.menu.language", func() -> void: I18n.toggle(), "ui_settings"))
	menu.add_child(_menu_button("ui.menu.quit", func() -> void: get_tree().quit(), ""))
	var panel: PanelContainer = UIKit.panel(menu, "DarkPanel")
	panel.custom_minimum_size = Vector2(170, 0)
	add_child(panel)
	panel.reset_size()
	panel.position = Vector2(int((MainUI.W - 170) / 2.0), 150)
	_mode_info = UIKit.wrap_label("", 300, UIKit.C_DIM)
	_mode_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_info.position = Vector2(90, 252)
	_mode_info.size = Vector2(300, 10)
	add_child(_mode_info)
	var ver: Label = UIKit.label("v" + str(ProjectSettings.get_setting("application/config/version", "0.1")), UIKit.C_DIM)
	ver.position = Vector2(4, 258)
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
		add_child(v)
		_ships.append(v)
		x += int(v.size.x) + 10
		i2 += 1


func _process(delta: float) -> void:
	_t += delta
	for i: int in _ships.size():
		var v: ShipView = _ships[i]
		v.position.x += delta * 10.0
		if v.position.x > MainUI.W + 10:
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
