class_name TopBar
extends PanelContainer
## Barre du haut : crédits, points de recherche, réputation, dette, date/heure, vitesse du temps.

const SPEED_ICONS: PackedStringArray = ["ui_pause", "ui_play", "ui_fast", "ui_faster"]

var main: MainUI = null
var _labels: Dictionary = {}
var _stat_boxes: Dictionary = {}
var _speed_buttons: Array[Button] = []


func _init() -> void:
	theme_type_variation = "BarPanel"


func rebuild() -> void:
	UIKit.clear(self)
	_labels.clear()
	_stat_boxes.clear()
	_speed_buttons.clear()
	var row: HBoxContainer = UIKit.hbox([], 3)
	add_child(row)
	for id: String in ["credits", "rp", "rep", "debt"]:
		var box: HBoxContainer = UIKit.hbox([UIKit.icon_rect("ui_" + id)], 1)
		var l: Label = UIKit.label("")
		l.custom_minimum_size = Vector2(46 if id in ["credits", "debt"] else 26, 0)
		box.add_child(l)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		box.tooltip_text = I18n.t("ui.top.%s.tip" % id)
		_labels[id] = l
		_stat_boxes[id] = box
		row.add_child(box)
	row.add_child(UIKit.spacer(0, 0, true))
	var day_box: HBoxContainer = UIKit.hbox([UIKit.icon_rect("ui_day")], 1)
	var dl: Label = UIKit.label("")
	dl.custom_minimum_size = Vector2(74, 0)
	day_box.add_child(dl)
	_labels["day"] = dl
	row.add_child(day_box)
	for i: int in SPEED_ICONS.size():
		var idx: int = i
		var b: Button = UIKit.button("", func() -> void:
			Game.set_speed(idx)
			refresh(), SPEED_ICONS[i], I18n.t("ui.top.speed%d" % i))
		b.toggle_mode = true
		b.theme_type_variation = "IconButton"
		_speed_buttons.append(b)
		row.add_child(b)
	var menu_b: Button = UIKit.button("", func() -> void: main.open_settings(), "ui_settings", I18n.t("ui.top.settings"))
	menu_b.theme_type_variation = "IconButton"
	row.add_child(menu_b)
	refresh()


func refresh() -> void:
	var m: GameModel = Game.model
	if m == null or _labels.is_empty():
		return
	(_labels["credits"] as Label).text = UIKit.credits(m.credits)
	(_labels["credits"] as Label).add_theme_color_override("font_color", UIKit.C_BAD if m.credits < 0 else UIKit.C_TEXT)
	(_labels["rp"] as Label).text = "%.0f" % floorf(m.research_points)
	(_labels["rep"] as Label).text = "%d" % int(round(m.reputation))
	(_labels["debt"] as Label).text = UIKit.credits(m.debt) if m.debt > 0 else I18n.t("ui.top.no_debt")
	var period: int = maxi(1, m.db.cfgi("debt", "period_days", 7))
	var next_due: int = m.day + (period - ((m.day - 1) % period))
	(_stat_boxes["debt"] as Control).tooltip_text = I18n.t("ui.top.debt.tip") + "\n" + I18n.t("ui.top.debt.next", {"day": next_due, "amount": UIKit.credits(mini(m.db.cfgi("debt", "installment", 2500), m.debt))})
	var shift: String = I18n.t("ui.top.shift") if m.is_shift_hour() else I18n.t("ui.top.closed")
	(_labels["day"] as Label).text = I18n.t("ui.top.day", {"day": m.day, "hour": "%02d:00" % m.hour}) + " " + shift
	for i: int in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == Game.speed_index)
