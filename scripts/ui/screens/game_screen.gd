class_name GameScreen
extends Control
## Base des écrans de jeu : reconstruction paresseuse (drapeau `dirty`), conservation du défilement,
## accès au modèle et remontée des résultats d'action vers MainUI.

var main: MainUI = null
var dirty: bool = true
var _scroll_state: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func m() -> GameModel:
	return Game.model


func db() -> ContentDB:
	return Content.db


func t(key: String, params: Dictionary = {}) -> String:
	return I18n.t(key, params)


## [chemin du fond, opacité du voile sombre]
func background() -> Array:
	return ["res://assets/backgrounds/garage.png", 0.62]


func on_show() -> void:
	dirty = true


func on_hour() -> void:
	dirty = true


func on_event(_ev: Dictionary) -> void:
	pass


func rebuild() -> void:
	pass


func _process(_delta: float) -> void:
	if dirty and visible and Game.model != null and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dirty = false
		rebuild()


## Reconstruit immédiatement (utilisé par les captures d'écran automatiques).
func force_rebuild() -> void:
	dirty = false
	rebuild()


func act(res: Dictionary, success_text: String = "") -> bool:
	dirty = true
	return main.report(res, success_text)


func place(c: Control, rect: Rect2) -> Control:
	c.position = rect.position
	c.size = rect.size
	add_child(c)
	return c


## Conteneur défilant dont la position est conservée entre deux reconstructions.
func make_scroll(key: String, child: Control, rect: Rect2) -> ScrollContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.position = rect.position
	sc.size = rect.size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(child)
	add_child(sc)
	_restore_scroll(sc, key, float(_scroll_state.get(key, 0.0)))
	return sc


func _restore_scroll(sc: ScrollContainer, key: String, v: float) -> void:
	await get_tree().process_frame
	if not is_instance_valid(sc):
		return
	sc.scroll_vertical = int(v)
	sc.get_v_scroll_bar().value_changed.connect(func(val: float) -> void: _scroll_state[key] = val)


func section(text: String) -> Label:
	return backdrop(UIKit.label(text, UIKit.C_ACCENT))


## Texte posé directement sur le décor : bandeau sombre derrière pour rester lisible.
static func backdrop(l: Label) -> Label:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(UIKit.C_DARK, 0.85)
	l.add_theme_stylebox_override("normal", sb)
	return l


func card(child: Control, selected: bool = false) -> PanelContainer:
	return UIKit.panel(child, "FramePanel" if selected else "DarkPanel")


## Rend un contrôle cliquable (sélection).
func clickable(c: Control, cb: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(ev: InputEvent) -> void:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			cb.call())


static func pct(v: float) -> String:
	return "%d %%" % int(round(v * 100.0))
