class_name MainUI
extends Control
## Racine de l'interface : écran titre, HUD (barre du haut + navigation), écrans de jeu, dialogues,
## notifications et fenêtres modales. Toute l'UI est construite en code (thème UIKit, police Tiny5).

const W: int = 480
const H: int = 270
const TOP_H: int = 20
const NAV_H: int = 20
const SCREEN_IDS: PackedStringArray = ["garage", "auctions", "sales", "staff", "research", "quests", "office"]
const SCREEN_ICONS: Dictionary = {
	"garage": "ui_garage", "auctions": "ui_auction", "sales": "ui_sales", "staff": "ui_staff",
	"research": "ui_research", "quests": "ui_quests", "office": "ui_report",
}
const TOAST_EVENTS: Dictionary = {
	"wreck_bought": ["ui_auction", UIKit.C_GOOD], "wreck_gift": ["ui_star", UIKit.C_ACCENT],
	"lot_lost": ["ui_auction", UIKit.C_DIM], "lot_defaulted": ["ui_warning", UIKit.C_BAD],
	"ship_sold": ["ui_sell", UIKit.C_GOOD], "sav_claim": ["ui_warning", UIKit.C_BAD],
	"inspection": ["ui_warning", UIKit.C_ORANGE], "employee_quit": ["ui_staff", UIKit.C_BAD],
	"employee_level": ["ui_star", UIKit.C_ACCENT], "quest_available": ["ui_quests", UIKit.C_BLUE],
	"quest_started": ["ui_quests", UIKit.C_BLUE], "quest_completed": ["ui_check", UIKit.C_GOOD],
	"quest_failed": ["ui_warning", UIKit.C_BAD], "debt_paid": ["ui_debt", UIKit.C_TEXT],
	"debt_late": ["ui_debt", UIKit.C_BAD], "item_found": ["ui_star", UIKit.C_ACCENT],
	"chapter_started": ["ui_quests", UIKit.C_ACCENT], "location_unlocked": ["ui_auction", UIKit.C_ACCENT],
	"salaries_unpaid": ["ui_warning", UIKit.C_BAD], "garage_upgraded": ["ui_garage", UIKit.C_GOOD],
	"defect_found": ["ui_scan", UIKit.C_ORANGE], "research_done": ["ui_research", UIKit.C_BLUE],
	"day_started": ["ui_day", UIKit.C_DIM], "debt_cleared": ["ui_check", UIKit.C_GOOD],
}

var bg: TextureRect
var bg_dim: ColorRect
var host: Control
var top_bar: TopBar
var nav: PanelContainer
var nav_buttons: Dictionary = {}
var screens: Dictionary = {}
var current: String = ""
var toasts: VBoxContainer
var dialogue: DialogueBox
var modal_layer: Control
var title_screen: TitleScreen = null
var game_layer: Control
var selected_ship: int = -1
## Faux pendant la bande-annonce : les dialogues de quête ne s'ouvrent pas tout seuls.
var auto_dialogues: bool = true
var _modal_stack: Array[Control] = []
var _tour: Node = null


func _ready() -> void:
	theme = UIKit.theme()
	position = Vector2.ZERO
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Game.model_changed.connect(_on_model_changed)
	Game.hour_passed.connect(_on_hour)
	Game.game_event.connect(_on_event)
	Game.offline_report_ready.connect(_on_offline_report)
	I18n.locale_changed.connect(_on_locale)
	var args: Dictionary = parse_args()
	if args.has("tour"):
		var tour_script: GDScript = load("res://scripts/ui/tour.gd")
		_tour = tour_script.new()
		add_child(_tour)
		_tour.call("start", self, args)
	else:
		show_title()


static func parse_args() -> Dictionary:
	var d: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			d[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return d


func _build() -> void:
	bg = TextureRect.new()
	bg.size = Vector2(W, H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.stretch_mode = TextureRect.STRETCH_KEEP
	add_child(bg)
	bg_dim = ColorRect.new()
	bg_dim.size = Vector2(W, H)
	bg_dim.color = Color(UIKit.C_DARK, 0.0)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_dim)
	game_layer = Control.new()
	game_layer.size = Vector2(W, H)
	game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_layer)
	host = Control.new()
	host.position = Vector2(0, TOP_H)
	host.size = Vector2(W, H - TOP_H - NAV_H)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.clip_contents = true
	game_layer.add_child(host)
	top_bar = TopBar.new()
	top_bar.main = self
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(W, TOP_H)
	game_layer.add_child(top_bar)
	nav = PanelContainer.new()
	nav.theme_type_variation = "NavPanel"
	nav.position = Vector2(0, H - NAV_H)
	nav.size = Vector2(W, NAV_H)
	game_layer.add_child(nav)
	toasts = VBoxContainer.new()
	toasts.position = Vector2(W - 172, TOP_H + 2)
	toasts.size = Vector2(170, 10)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 1)
	game_layer.add_child(toasts)
	dialogue = DialogueBox.new()
	dialogue.main = self
	dialogue.visible = false
	game_layer.add_child(dialogue)
	modal_layer = Control.new()
	modal_layer.size = Vector2(W, H)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	game_layer.visible = false


func _build_nav() -> void:
	UIKit.clear(nav)
	nav_buttons.clear()
	var row: HBoxContainer = UIKit.hbox([], 1)
	nav.add_child(row)
	for id: String in SCREEN_IDS:
		var sid: String = id
		var b: Button = UIKit.button(I18n.t("ui.nav." + id), func() -> void: show_screen(sid), SCREEN_ICONS[id])
		b.toggle_mode = true
		b.theme_type_variation = "NavButton"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_constant_override("h_separation", 1)
		b.tooltip_text = I18n.t("ui.nav.%s.tip" % id)
		row.add_child(b)
		nav_buttons[id] = b
	_update_nav_state()


func _update_nav_state() -> void:
	for id: String in nav_buttons:
		var b: Button = nav_buttons[id]
		b.set_pressed_no_signal(id == current)
	if Game.model != null and nav_buttons.has("quests"):
		var avail: int = QuestSystem.ids_with_status(Game.model, "available").size()
		var qb: Button = nav_buttons["quests"]
		qb.text = I18n.t("ui.nav.quests") + (" (%d)" % avail if avail > 0 else "")


# --- Écran titre / partie ------------------------------------------------------

func show_title() -> void:
	close_all_modals()
	game_layer.visible = false
	Game.running = false
	if title_screen != null:
		title_screen.queue_free()
	title_screen = TitleScreen.new()
	title_screen.main = self
	add_child(title_screen)
	move_child(title_screen, get_child_count() - 2)
	_set_background("res://assets/backgrounds/loc_ferropolis.png", 0.25)


func start_game() -> void:
	if title_screen != null:
		title_screen.queue_free()
		title_screen = null
	game_layer.visible = true
	_rebuild_all()
	show_screen("garage")
	check_dialogue()


func _on_model_changed() -> void:
	if Game.model != null and game_layer.visible:
		_rebuild_all()


func _rebuild_all() -> void:
	for id: String in screens:
		(screens[id] as Node).queue_free()
	screens.clear()
	for id: String in SCREEN_IDS:
		var scr: GameScreen = _make_screen(id)
		scr.main = self
		scr.position = Vector2.ZERO
		scr.size = host.size
		scr.visible = false
		host.add_child(scr)
		screens[id] = scr
	_build_nav()
	top_bar.rebuild()
	if not current.is_empty():
		var c: String = current
		current = ""
		show_screen(c)


func _make_screen(id: String) -> GameScreen:
	match id:
		"garage":
			return GarageScreen.new()
		"auctions":
			return AuctionScreen.new()
		"sales":
			return SalesScreen.new()
		"staff":
			return StaffScreen.new()
		"research":
			return ResearchScreen.new()
		"quests":
			return QuestScreen.new()
	return OfficeScreen.new()


func show_screen(id: String) -> void:
	if not screens.has(id):
		return
	current = id
	for sid: String in screens:
		var s: GameScreen = screens[sid]
		s.visible = sid == id
	var scr: GameScreen = screens[id]
	scr.on_show()
	_apply_screen_background(scr)
	_update_nav_state()


func _apply_screen_background(scr: GameScreen) -> void:
	var bgi: Array = scr.background()
	_set_background(str(bgi[0]), float(bgi[1]))


func _set_background(path: String, dim: float) -> void:
	bg.texture = UIKit.tex(path)
	bg_dim.color = Color(UIKit.C_DARK, dim)


func screen(id: String) -> GameScreen:
	return screens.get(id, null)


# --- Temps et événements -----------------------------------------------------

func _on_hour() -> void:
	top_bar.refresh()
	for id: String in screens:
		(screens[id] as GameScreen).on_hour()
	_update_nav_state()
	check_dialogue()


func _on_event(ev: Dictionary) -> void:
	var et: String = str(ev.get("type", ""))
	for id: String in screens:
		(screens[id] as GameScreen).on_event(ev)
	if et == "story_ending":
		_show_ending(str(ev.get("ending", "")))
	if TOAST_EVENTS.has(et) and game_layer.visible:
		var text: String = EventText.describe(ev)
		if not text.is_empty():
			var spec: Array = TOAST_EVENTS[et]
			toast(text, spec[1], str(spec[0]))


func refresh_after_action() -> void:
	top_bar.refresh()
	for id: String in screens:
		(screens[id] as GameScreen).dirty = true
	_update_nav_state()
	check_dialogue()


## Affiche le résultat d'une action : rien si succès (sauf message), raison traduite sinon.
func report(res: Dictionary, success_text: String = "") -> bool:
	refresh_after_action()
	if bool(res.get("ok", false)):
		if not success_text.is_empty():
			toast(success_text, UIKit.C_GOOD, "ui_check")
		return true
	toast(I18n.t("reason." + str(res.get("reason", "unknown"))), UIKit.C_BAD, "ui_warning")
	return false


func toast(text: String, color: Color = UIKit.C_TEXT, icon_id: String = "") -> void:
	while toasts.get_child_count() >= 5:
		var old: Node = toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	var row: HBoxContainer = UIKit.hbox([], 2)
	if not icon_id.is_empty():
		row.add_child(UIKit.icon_rect(icon_id))
	row.add_child(UIKit.wrap_label(text, 140, color))
	var p: PanelContainer = UIKit.panel(row, "DarkPanel")
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(p)
	var tw: Tween = p.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


# --- Dialogues -----------------------------------------------------------------

func check_dialogue() -> void:
	if Game.model == null or dialogue.visible or not _modal_stack.is_empty() or not auto_dialogues:
		return
	var d: Dictionary = Game.model.pop_dialogue()
	if d.is_empty():
		return
	dialogue.show_dialogue(d)


func dialogue_closed(d: Dictionary) -> void:
	var q: String = str(d.get("quest", ""))
	if Game.model != null and not q.is_empty() and not (QuestSystem.quest(Game.model, q).get("choices", []) as Array).is_empty() and QuestSystem.status(Game.model, q) == "active":
		show_screen("quests")
		(screens["quests"] as QuestScreen).select(q)
	check_dialogue()


# --- Fenêtres modales -----------------------------------------------------------

func open_modal(content: Control, min_size: Vector2 = Vector2(300, 0)) -> Control:
	var layer: Control = Control.new()
	layer.size = Vector2(W, H)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.size = Vector2(W, H)
	dim.color = Color(UIKit.C_DARK, 0.6)
	layer.add_child(dim)
	var p: PanelContainer = UIKit.panel(content, "FramePanel")
	p.custom_minimum_size = min_size
	layer.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	modal_layer.add_child(layer)
	_modal_stack.append(layer)
	Game.hold += 1
	return layer


func close_modal() -> void:
	if _modal_stack.is_empty():
		return
	var layer: Control = _modal_stack.pop_back()
	layer.queue_free()
	Game.hold = maxi(0, Game.hold - 1)
	refresh_after_action()


func close_all_modals() -> void:
	while not _modal_stack.is_empty():
		close_modal()


func confirm(text: String, on_yes: Callable) -> void:
	var v: VBoxContainer = UIKit.vbox([UIKit.wrap_label(text, 220)], 6)
	var row: HBoxContainer = UIKit.hbox([], 4)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UIKit.button(I18n.t("ui.cancel"), close_modal))
	row.add_child(UIKit.button(I18n.t("ui.confirm"), func() -> void:
		close_modal()
		on_yes.call()))
	v.add_child(row)
	open_modal(v, Vector2(240, 0))


func _on_offline_report(rep: Dictionary) -> void:
	show_report_popup(rep, true)


func show_report_popup(rep: Dictionary, offline: bool) -> void:
	var v: VBoxContainer = UIKit.vbox([], 3)
	v.add_child(UIKit.label(I18n.t("ui.offline.title" if offline else "ui.report.title"), UIKit.C_ACCENT, "Title"))
	if offline:
		v.add_child(UIKit.label(I18n.t("ui.offline.away", {"hours": int(rep.get("hours", 0))}), UIKit.C_DIM))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	var rows: Array[Array] = [
		["ui.offline.sold", str(int(rep.get("sold", 0)))],
		["ui.offline.revenue", UIKit.credits(int(rep.get("revenue", 0)))],
		["ui.offline.bought", str(int(rep.get("bought", 0)))],
		["ui.offline.repairs", str(int(rep.get("repairs", 0)))],
		["ui.offline.custom", str(int(rep.get("customizations", 0)))],
		["ui.offline.expenses", UIKit.credits(int(rep.get("expenses", 0)))],
		["ui.offline.credits", ("+" if int(rep.get("credits_delta", 0)) >= 0 else "") + UIKit.credits(int(rep.get("credits_delta", 0)))],
		["ui.offline.rp", "+%.1f" % float(rep.get("rp_delta", 0.0))],
	]
	for r: Array in rows:
		grid.add_child(UIKit.label(I18n.t(str(r[0])), UIKit.C_DIM))
		grid.add_child(UIKit.label(str(r[1])))
	v.add_child(grid)
	var evs: Array = rep.get("events", [])
	if not evs.is_empty():
		v.add_child(UIKit.label(I18n.t("ui.offline.events"), UIKit.C_ACCENT))
		var lst: VBoxContainer = UIKit.vbox([], 1)
		var n: int = 0
		for e: Variant in evs:
			var txt: String = EventText.describe(e as Dictionary)
			if txt.is_empty():
				continue
			lst.add_child(UIKit.wrap_label("• " + txt, 260))
			n += 1
			if n >= 8:
				break
		v.add_child(lst)
	var ok_b: Button = UIKit.button(I18n.t("ui.ok"), close_modal)
	ok_b.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(ok_b)
	open_modal(v, Vector2(280, 0))


func _show_ending(ending: String) -> void:
	if ending.is_empty():
		return
	var v: VBoxContainer = UIKit.vbox([], 4)
	v.add_child(UIKit.label(I18n.t("ui.ending.title"), UIKit.C_DIM))
	v.add_child(UIKit.label(I18n.t("ending.%s.title" % ending), UIKit.C_ACCENT, "Title"))
	v.add_child(UIKit.wrap_label(I18n.t("ending.%s.text" % ending), 300))
	v.add_child(UIKit.wrap_label(I18n.t("ui.ending.continue"), 300, UIKit.C_DIM))
	v.add_child(UIKit.button(I18n.t("ui.ok"), close_modal))
	open_modal(v, Vector2(320, 0))


func open_settings() -> void:
	var v: VBoxContainer = UIKit.vbox([], 4)
	v.add_child(UIKit.label(I18n.t("ui.settings.title"), UIKit.C_ACCENT, "Title"))
	var lang: HBoxContainer = UIKit.hbox([UIKit.label(I18n.t("ui.settings.language")), UIKit.spacer(0, 0, true)], 4)
	lang.add_child(UIKit.button("Français", func() -> void:
		close_modal()
		I18n.set_locale("fr")))
	lang.add_child(UIKit.button("English", func() -> void:
		close_modal()
		I18n.set_locale("en")))
	v.add_child(lang)
	v.add_child(UIKit.button(I18n.t("ui.settings.save"), func() -> void:
		Game.save()
		close_modal()
		toast(I18n.t("ui.settings.saved"), UIKit.C_GOOD, "ui_check")))
	v.add_child(UIKit.button(I18n.t("ui.settings.title_menu"), func() -> void:
		Game.save()
		close_all_modals()
		Game.stop()
		show_title()))
	v.add_child(UIKit.button(I18n.t("ui.settings.quit"), func() -> void:
		Game.save()
		get_tree().quit()))
	v.add_child(UIKit.label(I18n.t("ui.settings.keys"), UIKit.C_DIM))
	v.add_child(UIKit.button(I18n.t("ui.close"), close_modal))
	open_modal(v, Vector2(220, 0))


func _on_locale(_loc: String) -> void:
	if title_screen != null:
		show_title()
	elif Game.model != null:
		_rebuild_all()


# --- Clavier -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if Game.model == null or not game_layer.visible:
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_SPACE:
			Game.set_speed(1 if Game.speed_index == 0 else 0)
			top_bar.refresh()
		KEY_1, KEY_2, KEY_3:
			Game.set_speed(int(k.keycode - KEY_0))
			top_bar.refresh()
		KEY_F12:
			_save_screenshot()
		KEY_ESCAPE:
			if not _modal_stack.is_empty():
				close_modal()
			else:
				open_settings()


func _save_screenshot() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path: String = "user://screenshots/shot_%d.png" % Time.get_unix_time_from_system()
	img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	toast(I18n.t("ui.screenshot_saved"), UIKit.C_GOOD, "ui_check")
