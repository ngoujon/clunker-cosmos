class_name DialogueBox
extends PanelContainer
## Boîte de dialogue des quêtes : portrait, nom de l'orateur (personnage ou espèce), texte affiché
## progressivement. Clic = ligne suivante. Suspend le temps tant qu'elle est ouverte.

const CHARS_PER_SEC: float = 70.0

var main: MainUI = null
var _data: Dictionary = {}
var _lines: Array = []
var _idx: int = 0
var _portrait: TextureRect
var _name: Label
var _context: Label
var _text: Label
var _hint: Label
var _skip: Button
var _typing: float = 0.0


func _init() -> void:
	theme_type_variation = "FramePanel"
	position = Vector2(8, 270 - 20 - 86)
	size = Vector2(464, 84)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row: HBoxContainer = UIKit.hbox([], 6)
	add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(48, 48)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)
	var col: VBoxContainer = UIKit.vbox([], 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head: HBoxContainer = UIKit.hbox([], 4)
	_name = UIKit.label("", UIKit.C_ACCENT)
	_context = UIKit.label("", UIKit.C_DIM)
	head.add_child(_name)
	head.add_child(UIKit.spacer(0, 0, true))
	head.add_child(_context)
	col.add_child(head)
	_text = UIKit.wrap_label("", 390)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_text)
	var foot: HBoxContainer = UIKit.hbox([], 4)
	_hint = UIKit.label("", UIKit.C_DIM)
	foot.add_child(_hint)
	foot.add_child(UIKit.spacer(0, 0, true))
	_skip = UIKit.button(I18n.t("ui.dialogue.skip"), _close)
	foot.add_child(_skip)
	col.add_child(foot)


func show_dialogue(d: Dictionary) -> void:
	_data = d
	_lines = d.get("lines", [])
	_idx = 0
	if _lines.is_empty():
		return
	visible = true
	Game.hold += 1
	var q: String = str(d.get("quest", ""))
	_context.text = I18n.t("quest.%s.title" % q) if not q.is_empty() else ""
	_skip.text = I18n.t("ui.dialogue.skip")
	_render()


func current_line() -> Dictionary:
	return _lines[_idx] if _idx < _lines.size() else {}


static func speaker_info(sp: String) -> Dictionary:
	var db: ContentDB = Content.db
	if db.characters.has(sp):
		var c: Dictionary = db.characters[sp]
		return {"name": "" if sp == "narrator" else I18n.t("char.%s" % sp), "portrait": str(c.get("portrait", ""))}
	if db.species.has(sp):
		return {"name": I18n.t("species.%s.name" % sp), "portrait": str(db.species[sp].get("portrait", ""))}
	return {"name": "", "portrait": ""}


func _render() -> void:
	var line: Dictionary = current_line()
	var info: Dictionary = speaker_info(str(line.get("speaker", "")))
	_name.text = str(info["name"])
	var p: String = str(info["portrait"])
	_portrait.texture = UIKit.portrait(p) if not p.is_empty() else null
	_portrait.visible = not p.is_empty()
	_text.text = I18n.t(str(line.get("key", "")))
	_text.add_theme_color_override("font_color", UIKit.C_DIM if str(line.get("speaker", "")) == "narrator" else UIKit.C_TEXT)
	_text.visible_characters = 0
	_typing = 0.0
	_hint.text = I18n.t("ui.dialogue.next", {"i": _idx + 1, "n": _lines.size()})


func _process(delta: float) -> void:
	if not visible or _text.visible_characters < 0:
		return
	_typing += delta * CHARS_PER_SEC
	_text.visible_characters = int(_typing)
	if _text.visible_characters >= _text.get_total_character_count():
		_text.visible_characters = -1


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if visible and k != null and k.pressed and not k.echo and k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		advance()
		get_viewport().set_input_as_handled()


func advance() -> void:
	if _text.visible_characters >= 0:
		_text.visible_characters = -1
		return
	_idx += 1
	if _idx >= _lines.size():
		_close()
	else:
		_render()


## Termine immédiatement la ligne en cours (captures d'écran).
func finish_typing() -> void:
	_text.visible_characters = -1


func _close() -> void:
	if not visible:
		return
	visible = false
	Game.hold = maxi(0, Game.hold - 1)
	if main != null:
		main.dialogue_closed(_data)
