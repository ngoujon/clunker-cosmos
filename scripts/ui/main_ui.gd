class_name MainUI
extends Control
## Racine de l'interface : écran titre, HUD (barre du haut + navigation), écrans de jeu, dialogues,
## notifications, fenêtres modales (paramètres, tutoriel), musique et bruitages des événements.
## Toute l'UI est construite en code (thème UIKit). Sa résolution logique dépend de la fenêtre et de la
## taille d'interface choisie (ViewScale) : au moins 480×270, la taille de conception des décors.

const BASE_W: int = 480
const BASE_H: int = 270
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
	"emergency_loan": ["ui_debt", UIKit.C_ORANGE], "low_funds": ["ui_warning", UIKit.C_BAD],
}
## Événements accompagnés du jingle de victoire (assets/audio/music/jingle_win.ogg).
const JINGLE_EVENTS: PackedStringArray = ["chapter_started", "debt_cleared", "story_ending"]
## Bruitage joué pour chaque événement du modèle (assets/audio/sfx/<id>.wav).
const EVENT_SFX: Dictionary = {
	"wreck_bought": "purchase", "wreck_gift": "level_up", "lot_lost": "notify", "lot_defaulted": "warning",
	"ship_sold": "cash", "sav_claim": "warning", "inspection": "warning", "employee_hired": "hire",
	"employee_fired": "fire", "employee_quit": "fire", "employee_level": "level_up", "quest_available": "quest_new",
	"quest_started": "notify", "quest_completed": "quest_done", "quest_failed": "ui_error", "debt_paid": "debt_paid",
	"debt_reduced": "debt_paid", "debt_late": "warning", "debt_cleared": "level_up", "item_found": "level_up",
	"chapter_started": "quest_done", "location_unlocked": "level_up", "salaries_unpaid": "warning",
	"garage_upgraded": "level_up", "defect_found": "warning", "research_done": "research", "day_started": "day_start",
	"emergency_loan": "warning", "low_funds": "warning", "bid_placed": "bid", "lot_scanned": "scan",
	"defect_repaired": "repair_done", "defect_concealed": "paint", "client_left": "notify", "story_ending": "level_up",
}
## Délai avant d'adapter l'interface à une fenêtre redimensionnée (une seule fois à la fin du geste).
const RESIZE_DELAY_MS: int = 120

## Résolution logique actuelle de l'interface, et pixels d'écran par pixel d'interface (ViewScale).
static var W: int = BASE_W
static var H: int = BASE_H
static var K: int = 1
## Taille imposée par les visites automatiques (captures, bande-annonce) : -1 réglage du joueur,
## 0 automatique, sinon le facteur k.
static var forced_scale: int = -1

var bg: Backdrop
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
var away_banner: PanelContainer
var title_screen: TitleScreen = null
var game_layer: Control
var selected_ship: int = -1
## Faux pendant la bande-annonce : les dialogues de quête ne s'ouvrent pas tout seuls.
var auto_dialogues: bool = true
var _modal_stack: Array[Control] = []
var _tour: Node = null
var _tutorial_layer: Control = null
var _view_applied: bool = false
var _resize_at_ms: int = 0
## Bouton « Taille de l'interface » de la fenêtre des paramètres ouverte (texte mis à jour au besoin).
var _ui_scale_button: Button = null


func _ready() -> void:
	# Images HD décodées en tâche de fond dès le lancement (voir UIKit.warmup) ; pas en headless (tests).
	if DisplayServer.get_name() != "headless":
		UIKit.warmup()
	theme = UIKit.theme()
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	apply_view()
	# Fenêtre redimensionnée ou plein écran : résolution logique et curseur adaptés (voir apply_view).
	get_window().size_changed.connect(func() -> void: _resize_at_ms = Time.get_ticks_msec())
	Game.model_changed.connect(_on_model_changed)
	Game.hour_passed.connect(_on_hour)
	Game.game_event.connect(_on_event)
	Game.away_changed.connect(_on_away)
	I18n.locale_changed.connect(_on_locale)
	var args: Dictionary = parse_args()
	if args.has("tour"):
		var tour_script: GDScript = load("res://scripts/ui/tour.gd")
		_tour = tour_script.new()
		add_child(_tour)
		_tour.call("start", self, args)
	else:
		Game.import_legacy_save()
		set_fullscreen(Game.settings.fullscreen, false)
		show_title()


## Plein écran (F11, Alt+Entrée ou paramètres), mémorisé dans les réglages du joueur.
static func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(on: bool, remember: bool = true) -> void:
	if on != is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if remember:
		Game.settings.fullscreen = on
		Game.save_settings()


static func parse_args() -> Dictionary:
	var d: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			d[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return d


## Taille de l'interface (réglage du joueur ou facteur imposé) appliquée à la taille de la fenêtre :
## résolution logique de la fenêtre, curseur, puis mise en page si elle a changé.
func apply_view(force: bool = false) -> void:
	_resize_at_ms = 0
	var win: Vector2i = get_window().size
	var k: int = ViewScale.resolve(win, forced_scale if forced_scale >= 0 else Game.settings.ui_scale)
	var logical: Vector2i = ViewScale.logical_size(win, k)
	if _view_applied and not force and k == K and logical == Vector2i(W, H):
		return
	_view_applied = true
	K = k
	W = logical.x
	H = logical.y
	get_window().content_scale_size = logical
	size = Vector2(W, H)
	CursorKit.apply(K)
	_relayout()


func _exit_tree() -> void:
	UIKit.warmup_finish()


func _process(_delta: float) -> void:
	UIKit.pump_warmup()
	if _resize_at_ms > 0 and Time.get_ticks_msec() - _resize_at_ms >= RESIZE_DELAY_MS:
		apply_view()


## Nouvelle résolution logique : les conteneurs suivent par leurs ancres ; les écrans se reconstruisent,
## l'écran titre est recomposé, les fenêtres modales restent centrées.
func _relayout() -> void:
	dialogue.layout(Vector2(W, H))
	_center_away_banner()
	for id: String in screens:
		(screens[id] as GameScreen).dirty = true
	if title_screen != null:
		_make_title()
	if is_instance_valid(_ui_scale_button):
		_ui_scale_button.text = _ui_scale_text()
	place_background()


## Rectangle d'une image de décor 480×270 qui couvre toute la zone (débordement rogné).
static func cover_rect(area: Vector2) -> Rect2:
	var s: float = ViewScale.cover_scale(area, Vector2(BASE_W, BASE_H), K)
	var sz: Vector2 = Vector2(BASE_W, BASE_H) * s
	return Rect2(ViewScale.snap((area - sz) / 2.0, K), sz)


func _full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _build() -> void:
	bg = Backdrop.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_full_rect(bg)
	bg_dim = ColorRect.new()
	bg_dim.color = Color(UIKit.C_DARK, 0.0)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_dim)
	_full_rect(bg_dim)
	game_layer = Control.new()
	game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_layer)
	_full_rect(game_layer)
	host = Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.clip_contents = true
	game_layer.add_child(host)
	_full_rect(host)
	host.offset_top = TOP_H
	host.offset_bottom = -NAV_H
	top_bar = TopBar.new()
	top_bar.main = self
	game_layer.add_child(top_bar)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = TOP_H
	nav = PanelContainer.new()
	nav.theme_type_variation = "NavPanel"
	game_layer.add_child(nav)
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_top = -NAV_H
	toasts = VBoxContainer.new()
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 1)
	game_layer.add_child(toasts)
	toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toasts.offset_left = -172
	toasts.offset_right = -2
	toasts.offset_top = TOP_H + 2
	toasts.offset_bottom = TOP_H + 12
	dialogue = DialogueBox.new()
	dialogue.main = self
	dialogue.visible = false
	game_layer.add_child(dialogue)
	away_banner = UIKit.panel(UIKit.hbox([UIKit.icon_rect("ui_pause"), UIKit.label("")], 4), "FramePanel")
	away_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	away_banner.visible = false
	game_layer.add_child(away_banner)
	modal_layer = Control.new()
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	_full_rect(modal_layer)
	game_layer.visible = false


func _build_nav() -> void:
	UIKit.clear(nav)
	nav_buttons.clear()
	var row: HBoxContainer = UIKit.hbox([], 1)
	nav.add_child(row)
	for id: String in SCREEN_IDS:
		var sid: String = id
		var b: Button = UIKit.button(I18n.t("ui.nav." + id), func() -> void: show_screen(sid), SCREEN_ICONS[id], "", "ui_tab")
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
	_make_title()
	_set_background("res://assets/backgrounds/loc_ferropolis.png", 0.25)
	Audio.play_music("title")


## (Re)compose l'écran titre à la résolution logique actuelle, sous les fenêtres modales.
func _make_title() -> void:
	if title_screen != null:
		title_screen.queue_free()
	title_screen = TitleScreen.new()
	title_screen.main = self
	add_child(title_screen)
	move_child(title_screen, modal_layer.get_index())


func start_game() -> void:
	if title_screen != null:
		title_screen.queue_free()
		title_screen = null
	game_layer.visible = true
	_rebuild_all()
	show_screen("garage")
	Audio.play_music("garage")
	toast(I18n.t("ui.tutorial.hint"), UIKit.C_BLUE, "ui_quests")
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
		scr.visible = false
		host.add_child(scr)
		_full_rect(scr)
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
	place_background()


## Le décor couvre l'écran, sauf si l'écran courant impose son cadrage (scène du garage).
func place_background() -> void:
	var r: Rect2 = Rect2()
	if game_layer.visible and screens.has(current):
		r = (screens[current] as GameScreen).art_rect()
	if r.size == Vector2.ZERO:
		r = cover_rect(Vector2(W, H))
	bg.parallax = not (game_layer.visible and current == "garage")
	bg.rect = r
	bg.queue_redraw()


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
	if not game_layer.visible:
		return
	if et in JINGLE_EVENTS:
		Audio.play_jingle("jingle_win")
	elif et == "customized":
		Audio.play("option" if str(ev.get("kind", "")) == "option" else "paint")
	elif EVENT_SFX.has(et):
		Audio.play(str(EVENT_SFX[et]))
	if TOAST_EVENTS.has(et):
		var text: String = EventText.describe(ev)
		if not text.is_empty():
			var spec: Array = TOAST_EVENTS[et]
			toast(text, spec[1], str(spec[0]))


## Pause automatique (fenêtre inactive ou inactivité) : bandeau au-dessus du jeu.
func _on_away(reason: String) -> void:
	away_banner.visible = not reason.is_empty() and game_layer.visible
	if reason.is_empty():
		return
	var lbl: Label = away_banner.get_child(0).get_child(1) as Label
	lbl.text = I18n.t("ui.away." + reason)
	_center_away_banner()


func _center_away_banner() -> void:
	away_banner.reset_size()
	away_banner.position = Vector2(floorf((W - away_banner.size.x) / 2.0), TOP_H + 6)


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
	Audio.play("ui_error")
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
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(layer)
	_full_rect(layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(UIKit.C_DARK, 0.6)
	layer.add_child(dim)
	_full_rect(dim)
	var p: PanelContainer = UIKit.panel(content, "FramePanel")
	p.custom_minimum_size = min_size
	layer.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	_modal_stack.append(layer)
	Game.hold += 1
	Audio.play("ui_open")
	_fit_modal.call_deferred(p)
	return layer


## Recentre la fenêtre quand les textes à retour à la ligne ont leur vraie hauteur (connue seulement
## après une première mise en page) : sinon elle reste trop haute et déborde de l'écran.
func _fit_modal(p: PanelContainer) -> void:
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	p.reset_size()
	p.position = ((Vector2(W, H) - p.size) / 2.0).floor().max(Vector2.ZERO)


func close_modal() -> void:
	if _modal_stack.is_empty():
		return
	var layer: Control = _modal_stack.pop_back()
	if layer == _tutorial_layer:
		_tutorial_layer = null
	layer.queue_free()
	Game.hold = maxi(0, Game.hold - 1)
	Audio.play("ui_close")
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


# --- Paramètres -------------------------------------------------------------------

## Fenêtre des paramètres (écran titre et partie) : affichage, audio, jeu, aide ; en partie, aussi
## sauvegarder / menu principal / quitter.
func open_settings() -> void:
	var s: GameSettings = Game.settings
	var in_game: bool = Game.model != null and game_layer.visible
	var v: VBoxContainer = UIKit.vbox([], 4)
	v.add_child(UIKit.label(I18n.t("ui.settings.title"), UIKit.C_ACCENT, "Title"))
	var cols: HBoxContainer = UIKit.hbox([], 12)
	v.add_child(cols)
	var left: VBoxContainer = UIKit.vbox([], 3)
	left.custom_minimum_size = Vector2(190, 0)
	cols.add_child(left)
	left.add_child(UIKit.label(I18n.t("ui.settings.display"), UIKit.C_ACCENT))
	left.add_child(_setting_row(I18n.t("ui.settings.fullscreen"), _toggle_button(is_fullscreen(), func(on: bool) -> void:
		set_fullscreen(on))))
	# Taille de l'interface : cycle Auto → plus grande → … → plus fine (résolution logique affichée).
	var ui_b: Button = UIKit.button(_ui_scale_text(), func() -> void: pass, "", I18n.t("ui.settings.ui_scale_tip"))
	ui_b.pressed.connect(func() -> void:
		s.ui_scale = ViewScale.next_setting(get_window().size, s.ui_scale)
		Game.save_settings()
		apply_view()
		ui_b.text = _ui_scale_text())
	ui_b.custom_minimum_size = Vector2(76, 0)
	_ui_scale_button = ui_b
	left.add_child(_setting_row(I18n.t("ui.settings.ui_scale"), ui_b))
	left.add_child(UIKit.wrap_label(I18n.t("ui.settings.ui_scale_hint"), 190, UIKit.C_DIM))
	left.add_child(UIKit.label(I18n.t("ui.settings.audio"), UIKit.C_ACCENT))
	left.add_child(_volume_row("ui.settings.master", s.master_volume, func(x: float) -> void: s.master_volume = x))
	left.add_child(_volume_row("ui.settings.music", s.music_volume, func(x: float) -> void: s.music_volume = x))
	left.add_child(_volume_row("ui.settings.sfx", s.sfx_volume, func(x: float) -> void: s.sfx_volume = x))
	var right: VBoxContainer = UIKit.vbox([], 3)
	right.custom_minimum_size = Vector2(190, 0)
	cols.add_child(right)
	right.add_child(UIKit.label(I18n.t("ui.settings.game"), UIKit.C_ACCENT))
	var langs: HBoxContainer = UIKit.hbox([], 2)
	for loc: String in ["fr", "en"]:
		var code: String = loc
		var lb: Button = UIKit.button(I18n.t("ui.settings.lang_" + loc), func() -> void: _change_locale(code))
		lb.toggle_mode = true
		lb.set_pressed_no_signal(I18n.locale == loc)
		langs.add_child(lb)
	right.add_child(_setting_row(I18n.t("ui.settings.language"), langs))
	right.add_child(_setting_row(I18n.t("ui.settings.pause_focus"), _toggle_button(s.pause_on_focus_loss, func(on: bool) -> void:
		s.pause_on_focus_loss = on
		Game.save_settings())))
	var idle_b: Button = UIKit.button(_idle_text(s.idle_pause_minutes), func() -> void: pass)
	idle_b.pressed.connect(func() -> void:
		s.idle_pause_minutes = GameSettings.next_idle_choice(s.idle_pause_minutes)
		idle_b.text = _idle_text(s.idle_pause_minutes)
		Game.save_settings())
	idle_b.custom_minimum_size = Vector2(44, 0)
	right.add_child(_setting_row(I18n.t("ui.settings.pause_idle"), idle_b))
	right.add_child(UIKit.label(I18n.t("ui.settings.help"), UIKit.C_ACCENT))
	right.add_child(UIKit.button(I18n.t("ui.tutorial.open"), func() -> void: open_tutorial(), "ui_quests"))
	right.add_child(UIKit.wrap_label(I18n.t("ui.settings.keys"), 190, UIKit.C_DIM))
	var foot: HBoxContainer = UIKit.hbox([], 4)
	if in_game:
		foot.add_child(UIKit.button(I18n.t("ui.settings.save"), func() -> void:
			Game.save()
			close_modal()
			toast(I18n.t("ui.settings.saved"), UIKit.C_GOOD, "ui_check")))
		foot.add_child(UIKit.button(I18n.t("ui.settings.title_menu"), func() -> void:
			Game.save()
			close_all_modals()
			Game.stop()
			show_title()))
		foot.add_child(UIKit.button(I18n.t("ui.settings.quit"), func() -> void:
			Game.save()
			quit_game()))
	foot.add_child(UIKit.spacer(0, 0, true))
	foot.add_child(UIKit.button(I18n.t("ui.close"), close_modal))
	v.add_child(foot)
	open_modal(v, Vector2(400, 0))


func _setting_row(text: String, ctrl: Control) -> HBoxContainer:
	var row: HBoxContainer = UIKit.hbox([UIKit.label(text), UIKit.spacer(0, 0, true)], 4)
	ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ctrl)
	return row


func _toggle_button(on: bool, cb: Callable) -> Button:
	var b: Button = UIKit.button(I18n.t("ui.settings.on" if on else "ui.settings.off"), func() -> void: pass, "", "", "ui_toggle")
	b.toggle_mode = true
	b.set_pressed_no_signal(on)
	b.custom_minimum_size = Vector2(44, 0)
	b.toggled.connect(func(state: bool) -> void:
		b.text = I18n.t("ui.settings.on" if state else "ui.settings.off")
		cb.call(state))
	return b


func _volume_row(key: String, value: float, setter: Callable) -> HBoxContainer:
	var pct: Label = UIKit.label("%d %%" % roundi(value * 100.0), UIKit.C_DIM)
	pct.custom_minimum_size = Vector2(24, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var sl: HSlider = UIKit.slider(value, func(x: float) -> void:
		setter.call(x)
		pct.text = "%d %%" % roundi(x * 100.0)
		Audio.apply_volumes(Game.settings)
		Audio.play("ui_click")
		Game.save_settings(), 80)
	var row: HBoxContainer = UIKit.hbox([UIKit.label(I18n.t(key)), UIKit.spacer(0, 0, true), sl, pct], 4)
	return row


## « Auto · 853×480 » ou « 1280×720 » : résolution logique de l'interface.
func _ui_scale_text() -> String:
	var res: String = "%d×%d" % [W, H]
	return I18n.t("ui.settings.ui_auto", {"res": res}) if Game.settings.ui_scale <= 0 else res


func _idle_text(minutes: int) -> String:
	return I18n.t("ui.settings.never") if minutes <= 0 else I18n.t("ui.settings.minutes", {"n": minutes})


func _change_locale(loc: String) -> void:
	if loc == I18n.locale:
		return
	close_all_modals()
	I18n.set_locale(loc)
	open_settings()


func _on_locale(_loc: String) -> void:
	if title_screen != null:
		show_title()
	elif Game.model != null:
		_rebuild_all()


# --- Tutoriel ---------------------------------------------------------------------

## Menu Tutoriel : liste des sujets à gauche, page à droite avec l'aparté de BOLT (data/tutorial.json).
func open_tutorial(page_id: String = "") -> void:
	var pages: Array[Dictionary] = Content.db.tutorial
	if pages.is_empty() or _tutorial_layer != null:
		return
	var state: Dictionary = {"i": 0}
	for i: int in pages.size():
		if str(pages[i]["id"]) == page_id:
			state["i"] = i
	var v: VBoxContainer = UIKit.vbox([], 4)
	var head: HBoxContainer = UIKit.hbox([UIKit.icon_rect("ui_quests"), UIKit.label(I18n.t("ui.tutorial.title"), UIKit.C_ACCENT, "Title")], 4)
	v.add_child(head)
	var body: HBoxContainer = UIKit.hbox([], 6)
	v.add_child(body)
	var list: VBoxContainer = UIKit.vbox([], 1)
	var list_buttons: Array[Button] = []
	body.add_child(UIKit.scroll(list, Vector2(118, 186)))
	var col: VBoxContainer = UIKit.vbox([], 3)
	col.custom_minimum_size = Vector2(286, 0)
	body.add_child(col)
	var title_row: HBoxContainer = UIKit.hbox([], 4)
	var page_icon: TextureRect = UIKit.icon_rect("ui_quests")
	var page_title: Label = UIKit.label("", UIKit.C_ACCENT, "Title")
	title_row.add_child(page_icon)
	title_row.add_child(page_title)
	col.add_child(title_row)
	var text: Label = UIKit.wrap_label("", 272)
	col.add_child(UIKit.scroll(text, Vector2(286, 116)))
	var bolt_text: Label = UIKit.wrap_label("", 236, UIKit.C_BLUE)
	var bolt_portrait: String = str(Content.db.characters.get("bolt", {}).get("portrait", ""))
	var bolt_row: HBoxContainer = UIKit.hbox([UIKit.portrait_rect(bolt_portrait), bolt_text], 4)
	col.add_child(UIKit.panel(bolt_row, "DarkPanel"))
	var foot: HBoxContainer = UIKit.hbox([], 4)
	var prev_b: Button = UIKit.button(I18n.t("ui.tutorial.prev"), func() -> void: pass)
	var next_b: Button = UIKit.button(I18n.t("ui.tutorial.next"), func() -> void: pass)
	var counter: Label = UIKit.label("", UIKit.C_DIM)
	foot.add_child(prev_b)
	foot.add_child(next_b)
	foot.add_child(counter)
	foot.add_child(UIKit.spacer(0, 0, true))
	foot.add_child(UIKit.button(I18n.t("ui.close"), close_modal))
	v.add_child(foot)
	var render: Callable = func() -> void:
		var i: int = int(state["i"])
		var page: Dictionary = pages[i]
		var id: String = str(page["id"])
		page_icon.texture = UIKit.icon(str(page.get("icon", "ui_quests")))
		page_title.text = I18n.t("tuto.%s.title" % id)
		text.text = I18n.t("tuto.%s.body" % id)
		bolt_text.text = "BOLT : " + I18n.t("tuto.%s.bolt" % id) if I18n.locale == "fr" else "BOLT: " + I18n.t("tuto.%s.bolt" % id)
		counter.text = "%d / %d" % [i + 1, pages.size()]
		prev_b.disabled = i == 0
		next_b.disabled = i == pages.size() - 1
		for k: int in list_buttons.size():
			list_buttons[k].set_pressed_no_signal(k == i)
	for i: int in pages.size():
		var idx: int = i
		var lb: Button = UIKit.button(I18n.t("tuto.%s.title" % str(pages[i]["id"])), func() -> void:
			state["i"] = idx
			render.call(), str(pages[i].get("icon", "")), "", "ui_tab")
		lb.toggle_mode = true
		lb.theme_type_variation = "NavButton"
		lb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(lb)
		list_buttons.append(lb)
	prev_b.pressed.connect(func() -> void:
		state["i"] = maxi(0, int(state["i"]) - 1)
		render.call())
	next_b.pressed.connect(func() -> void:
		state["i"] = mini(pages.size() - 1, int(state["i"]) + 1)
		render.call())
	render.call()
	_tutorial_layer = open_modal(v, Vector2(420, 0))


func tutorial_open() -> bool:
	return _tutorial_layer != null


# --- Clavier -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_F1:
		if _tutorial_layer == null:
			open_tutorial()
		else:
			close_modal()
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_ESCAPE and not _modal_stack.is_empty():
		close_modal()
		get_viewport().set_input_as_handled()
		return
	if Game.model == null or not game_layer.visible:
		return
	match k.keycode:
		KEY_SPACE:
			Game.set_speed(1 if Game.speed_index == 0 else 0)
			Audio.play("speed")
			top_bar.refresh()
		KEY_1, KEY_2, KEY_3:
			Game.set_speed(int(k.keycode - KEY_0))
			Audio.play("speed")
			top_bar.refresh()
		KEY_F12:
			_save_screenshot()
		KEY_ESCAPE:
			open_settings()


## Quitte le jeu après avoir coupé les sons (voir Audio.stop_all).
func quit_game() -> void:
	Audio.stop_all()
	for i: int in 3:
		await get_tree().process_frame
	get_tree().quit()


## Décor plein écran (2.5D) : l'image est dessinée dans `rect` (pixels d'interface), avec un vignettage et des
## poussières lumineuses en suspension. `parallax` : le décor glisse légèrement à l'opposé de la souris
## (agrandi de PARALLAX_MARGIN pour ne jamais montrer ses bords) ; désactivé au garage, dont la scène est
## posée exactement sur le décor, et dans les visites automatiques.
class Backdrop extends Control:
	const PARALLAX_MARGIN: float = 8.0
	const MOTES: int = 36
	var texture: Texture2D = null
	var rect: Rect2 = Rect2()
	var parallax: bool = false
	var _offset: Vector2 = Vector2.ZERO
	var _t: float = 0.0
	var _motes: Array[Vector3] = []
	var _vignette: GradientTexture2D = null

	func _ready() -> void:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7
		for i: int in MOTES:
			_motes.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0.0, 0.0, 0.02, 0.5))
		g.add_point(0.55, Color(0, 0, 0, 0))
		_vignette = GradientTexture2D.new()
		_vignette.gradient = g
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.5)
		_vignette.fill_to = Vector2(1.05, 1.05)
		_vignette.width = 256
		_vignette.height = 144

	func _process(delta: float) -> void:
		_t += delta
		var target: Vector2 = Vector2.ZERO
		if parallax and Game.persist and size.x > 0.0:
			var m: Vector2 = (get_local_mouse_position() / size - Vector2(0.5, 0.5)).clampf(-0.5, 0.5)
			target = -m * 2.0 * PARALLAX_MARGIN * 0.8
		_offset = _offset.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		if texture != null and rect.size != Vector2.ZERO:
			var r: Rect2 = rect
			if parallax:
				var grow: Vector2 = Vector2(PARALLAX_MARGIN, PARALLAX_MARGIN * rect.size.y / rect.size.x)
				r = Rect2(rect.position - grow + _offset, rect.size + grow * 2.0)
			draw_texture_rect(texture, r, false)
		# Poussières : petits points lumineux qui montent lentement en ondulant.
		for i: int in _motes.size():
			var mo: Vector3 = _motes[i]
			var speed: float = 0.006 + mo.z * 0.01
			var y: float = fposmod(mo.y - _t * speed, 1.0)
			var x: float = mo.x + sin(_t * 0.4 + mo.z * 6.0) * 0.01
			var a: float = 0.08 + 0.12 * (0.5 + 0.5 * sin(_t * (0.8 + mo.z) + float(i)))
			var p: Vector2 = Vector2(x * size.x, y * size.y) + _offset * (0.5 + mo.z)
			draw_circle(p, 0.5 + mo.z * 0.9, Color(1.0, 0.92, 0.75, a), true, -1.0, true)
		if _vignette != null:
			draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)


func _save_screenshot() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path: String = "user://screenshots/shot_%d.png" % Time.get_unix_time_from_system()
	img.save_png(path)
	toast(I18n.t("ui.screenshot_saved"), UIKit.C_GOOD, "ui_check")
