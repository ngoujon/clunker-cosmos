class_name StaffScreen
extends GameScreen
## Ressources humaines : employés (niveau/XP, traits, salaire, moral, fatigue, poste, règle de priorité)
## et vivier de candidats renouvelé chaque jour. Effectif plafonné par la taille du garage.


static func status_text(gm: GameModel, e: Employee) -> String:
	if not e.is_working():
		return I18n.t("ui.staff.status_pause")
	if not gm.is_shift_hour():
		return I18n.t("ui.staff.status_off")
	var kind: String = str(e.job.get("kind", ""))
	match kind:
		"defect":
			var s: Ship = gm.find_ship(int(e.job.get("ship", -1)))
			return I18n.t("ui.staff.status_repair", {"ship": s.name if s != null else "?"})
		"custom":
			var s2: Ship = gm.find_ship(int(e.job.get("ship", -1)))
			return I18n.t("ui.staff.status_custom", {"ship": s2.name if s2 != null else "?"})
		"sell":
			var c: Client = gm.find_client(int(e.job.get("client", -1)))
			return I18n.t("ui.staff.status_sell", {"client": c.name if c != null else "?"})
	match e.role:
		"buyer":
			return I18n.t("ui.staff.status_buyer")
		"researcher":
			return I18n.t("ui.staff.status_research")
	return I18n.t("ui.staff.status_idle")


func rebuild() -> void:
	UIKit.clear(self)
	var gm: GameModel = m()
	var head: HBoxContainer = UIKit.hbox([], 8)
	head.add_child(UIKit.label(t("ui.staff.headcount", {"n": gm.staff.size(), "max": gm.max_staff()}), UIKit.C_ACCENT))
	head.add_child(UIKit.label(t("ui.staff.payroll", {"amount": UIKit.credits(StaffSystem.daily_payroll(gm))})))
	var st_parts: Array[String] = []
	for r: String in db().role_ids():
		st_parts.append("%s %d" % [t("role.%s.name" % r), gm.station_count(r)])
	var st: Label = UIKit.label(t("ui.staff.stations", {"list": ", ".join(st_parts)}), UIKit.C_DIM)
	head.add_child(st)
	place(UIKit.panel(head, "DarkPanel"), Rect2(2, 2, size.x - 4, 14))
	var list: VBoxContainer = UIKit.vbox([], 2)
	if gm.staff.is_empty():
		list.add_child(UIKit.panel(UIKit.wrap_label(t("ui.staff.none"), 260, UIKit.C_DIM), "DarkPanel"))
	for e: Employee in gm.staff:
		list.add_child(_employee_card(e))
	make_scroll("staff", list, Rect2(2, 20, 290, size.y - 22))
	var pool: VBoxContainer = UIKit.vbox([], 2)
	pool.add_child(section(t("ui.staff.pool")))
	pool.add_child(backdrop(UIKit.wrap_label(t("ui.staff.pool_note"), 160, UIKit.C_DIM)))
	for c: Employee in gm.candidates:
		pool.add_child(_candidate_card(c))
	make_scroll("pool", pool, Rect2(296, 20, size.x - 298, size.y - 22))


func _traits_label(e: Employee, width: int) -> Label:
	var names: Array[String] = []
	var tips: Array[String] = []
	for tr: String in e.traits:
		names.append(t("trait.%s.name" % tr))
		tips.append("%s : %s" % [t("trait.%s.name" % tr), t("trait.%s.desc" % tr)])
	var l: Label = UIKit.wrap_label(", ".join(names), width, UIKit.C_BLUE)
	l.tooltip_text = "\n".join(tips)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _employee_card(e: Employee) -> Control:
	var gm: GameModel = m()
	var row: HBoxContainer = UIKit.hbox([], 4)
	var pv: VBoxContainer = UIKit.vbox([UIKit.portrait_rect(e.portrait)], 1)
	pv.add_child(UIKit.label(t("ui.staff.salary", {"amount": UIKit.credits(e.salary)}), UIKit.C_DIM))
	row.add_child(pv)
	var v: VBoxContainer = UIKit.vbox([], 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top: HBoxContainer = UIKit.hbox([UIKit.label(e.name, UIKit.C_ACCENT), UIKit.icon_rect("role_" + e.role, 16), UIKit.label("%s · %s" % [t("role.%s.name" % e.role), t("ui.staff.level", {"n": e.level})])], 3)
	v.add_child(top)
	var bars: HBoxContainer = UIKit.hbox([], 3)
	bars.add_child(UIKit.label(t("ui.staff.xp"), UIKit.C_DIM))
	bars.add_child(UIKit.bar(e.xp, StaffSystem.xp_needed(gm, e), UIKit.C_BLUE, 30, 4))
	bars.add_child(UIKit.label(t("ui.staff.morale"), UIKit.C_DIM))
	bars.add_child(UIKit.bar(e.morale, 100.0, UIKit.C_GOOD if e.morale >= 40.0 else UIKit.C_BAD, 30, 4))
	bars.add_child(UIKit.label(t("ui.staff.fatigue"), UIKit.C_DIM))
	bars.add_child(UIKit.bar(e.fatigue, 100.0, UIKit.C_ORANGE, 30, 4))
	v.add_child(bars)
	v.add_child(_traits_label(e, 220))
	v.add_child(UIKit.label(status_text(gm, e) + "  ·  " + t("ui.staff.efficiency", {"v": pct(StaffSystem.efficiency(gm, e))}), UIKit.C_DIM))
	var ctl: HBoxContainer = UIKit.hbox([], 2)
	var st: OptionButton = OptionButton.new()
	st.focus_mode = Control.FOCUS_NONE
	st.add_item(t("ui.staff.pause"), 0)
	var ids: Array[String] = gm.station_ids(e.role)
	for k: int in ids.size():
		var occ: Employee = gm.station_occupant(ids[k])
		var label: String = t("ui.staff.station", {"role": t("role.%s.name" % e.role), "n": k + 1})
		if occ != null and occ != e:
			label += " (%s)" % occ.name.get_slice(" ", 0)
		st.add_item(label, k + 1)
	st.select(ids.find(e.station) + 1)
	st.tooltip_text = t("ui.staff.station_tip")
	st.item_selected.connect(func(idx: int) -> void:
		var target: String = "" if idx == 0 else ids[idx - 1]
		act(m().act_assign(e.id, target)))
	ctl.add_child(st)
	var rules: Array = db().roles.get(e.role, {}).get("rules", [])
	var rb: OptionButton = OptionButton.new()
	rb.focus_mode = Control.FOCUS_NONE
	for k: int in rules.size():
		rb.add_item(t("rule.%s.name" % str(rules[k])), k)
		rb.set_item_tooltip(k, t("rule.%s.desc" % str(rules[k])))
	rb.select(maxi(0, rules.find(e.rule)))
	rb.tooltip_text = t("ui.staff.rule_tip") + "\n" + t("rule.%s.desc" % e.rule)
	rb.item_selected.connect(func(idx: int) -> void: act(m().act_set_rule(e.id, str(rules[idx]))))
	ctl.add_child(rb)
	ctl.add_child(UIKit.spacer(0, 0, true))
	ctl.add_child(UIKit.button(t("ui.staff.fire"), func() -> void:
		main.confirm(t("ui.staff.fire_confirm", {"name": e.name}), func() -> void: act(m().act_fire(e.id)))))
	v.add_child(ctl)
	row.add_child(v)
	return UIKit.panel(row, "DarkPanel")


func _candidate_card(c: Employee) -> Control:
	var gm: GameModel = m()
	var v: VBoxContainer = UIKit.vbox([], 1)
	var top: HBoxContainer = UIKit.hbox([UIKit.portrait_rect(c.portrait)], 3)
	var info: VBoxContainer = UIKit.vbox([UIKit.label(c.name, UIKit.C_ACCENT)], 0)
	info.add_child(UIKit.hbox([UIKit.icon_rect("role_" + c.role, 16), UIKit.label(t("role.%s.name" % c.role))], 2))
	info.add_child(UIKit.label(t("ui.staff.level", {"n": c.level}), UIKit.C_DIM))
	info.add_child(UIKit.label(t("ui.staff.salary", {"amount": UIKit.credits(c.salary)}), UIKit.C_DIM))
	top.add_child(info)
	v.add_child(top)
	v.add_child(_traits_label(c, 160))
	var cost: int = StaffSystem.hire_cost(gm, c)
	var b: Button = UIKit.button(t("ui.staff.hire", {"cost": UIKit.credits(cost)}), func() -> void:
		act(m().act_hire(c.id), t("ui.staff.hired", {"name": c.name})), "ui_hire", t("role.%s.desc" % c.role))
	b.disabled = gm.staff.size() >= gm.max_staff()
	if b.disabled:
		b.tooltip_text = t("reason.staff_full")
	v.add_child(b)
	return UIKit.panel(v, "DarkPanel")
