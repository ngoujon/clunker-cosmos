class_name OfficeScreen
extends GameScreen
## Bureau : finances (dette Galax-Auto), agrandissement du garage, politique de l'atelier
## (honnête / pragmatique / requin), automatisation et rapport du jour.

const BUYER_BUDGETS: Array[float] = [0.3, 0.6, 0.9]
const SELLER_MARGINS: Array[float] = [0.0, 0.05, 0.15]


func rebuild() -> void:
	UIKit.clear(self)
	var gm: GameModel = m()
	var left: VBoxContainer = UIKit.vbox([], 3)
	# Finances
	left.add_child(section(t("ui.office.finances")))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	var period: int = maxi(1, gm.db.cfgi("debt", "period_days", 7))
	var next_due: int = gm.day + (period - ((gm.day - 1) % period))
	for r: Array in [
		["ui.office.credits", UIKit.credits(gm.credits)],
		["ui.office.debt", UIKit.credits(gm.debt)],
		["ui.office.installment", t("ui.office.installment_v", {"amount": UIKit.credits(mini(gm.db.cfgi("debt", "installment", 2500), gm.debt)), "day": next_due})],
		["ui.office.paid", UIKit.credits(gm.debt_paid_total)],
		["ui.office.profit", UIKit.credits(int(gm.operating_profit()))],
	]:
		grid.add_child(UIKit.label(t(str(r[0])), UIKit.C_DIM))
		grid.add_child(UIKit.label(str(r[1])))
	left.add_child(grid)
	if gm.debt > 0:
		var pay: HFlowContainer = HFlowContainer.new()
		pay.add_theme_constant_override("h_separation", 2)
		pay.add_theme_constant_override("v_separation", 2)
		for amount: int in [1000, 5000]:
			var a: int = mini(amount, gm.debt)
			var b: Button = UIKit.button(t("ui.office.pay", {"amount": UIKit.credits(a)}), func() -> void: act(m().act_pay_debt(a)), "ui_debt")
			b.disabled = gm.credits < a
			pay.add_child(b)
		var all_b: Button = UIKit.button(t("ui.office.pay_all"), func() -> void: act(m().act_pay_debt(m().debt)))
		all_b.disabled = gm.credits < gm.debt
		pay.add_child(all_b)
		left.add_child(pay)
	# Garage
	left.add_child(section(t("ui.office.garage", {"level": gm.garage_level})))
	left.add_child(UIKit.label(t("ui.office.capacity", {"slots": gm.ship_slots(), "staff": gm.max_staff()}), UIKit.C_DIM))
	var cost: int = gm.garage_upgrade_cost()
	if cost >= 0:
		var nxt: Dictionary = db().garage_level_data(gm.garage_level + 1)
		var up: Button = UIKit.button(t("ui.office.upgrade", {"cost": UIKit.credits(cost)}), func() -> void: act(m().act_upgrade_garage(), t("ui.office.upgraded")), "ui_garage", t("ui.office.upgrade_tip", {"slots": int(nxt.get("slots", 0)), "staff": int(nxt.get("max_staff", 0))}))
		up.disabled = gm.credits < cost
		left.add_child(up)
	else:
		left.add_child(UIKit.label(t("ui.office.max_level"), UIKit.C_GOOD))
	# Politique
	left.add_child(section(t("ui.office.policy")))
	var pol: HBoxContainer = UIKit.hbox([], 2)
	var cur: String = str(gm.settings.get("defect_policy", "honest"))
	for p: String in GameModel.POLICIES:
		var pid: String = p
		var b2: Button = UIKit.button(t("ui.policy." + p), func() -> void: act(m().act_set_setting("defect_policy", pid)))
		b2.toggle_mode = true
		b2.set_pressed_no_signal(p == cur)
		b2.tooltip_text = t("ui.policy.%s.desc" % p)
		pol.add_child(b2)
	left.add_child(pol)
	left.add_child(UIKit.wrap_label(t("ui.policy.%s.desc" % cur), 220, UIKit.C_DIM))
	# Automatisation
	left.add_child(section(t("ui.office.automation")))
	var auto_list: bool = bool(gm.settings.get("auto_list", true))
	var al: Button = UIKit.button(t("ui.office.auto_list") + (" : " + t("ui.on") if auto_list else " : " + t("ui.off")), func() -> void: act(m().act_set_setting("auto_list", not auto_list)))
	al.tooltip_text = t("ui.office.auto_list_tip")
	left.add_child(al)
	left.add_child(_choice_row("ui.office.buyer_budget", "buyer_budget", BUYER_BUDGETS))
	left.add_child(_choice_row("ui.office.seller_margin", "seller_min_margin", SELLER_MARGINS))
	make_scroll("office_left", UIKit.panel(left, "DarkPanel"), Rect2(2, 2, 236, size.y - 4))
	_report_panel()


func _choice_row(label_key: String, setting: String, values: Array[float]) -> Control:
	var gm: GameModel = m()
	var row: HBoxContainer = UIKit.hbox([UIKit.label(t(label_key), UIKit.C_DIM)], 2)
	var cur: float = float(gm.settings.get(setting, values[1]))
	for v: float in values:
		var val: float = v
		var b: Button = UIKit.button(pct(v), func() -> void: act(m().act_set_setting(setting, val)))
		b.toggle_mode = true
		b.set_pressed_no_signal(absf(cur - v) < 0.001)
		row.add_child(b)
	row.tooltip_text = t(label_key + "_tip")
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	return row


func _report_panel() -> void:
	var gm: GameModel = m()
	var rep: Dictionary = gm.last_report()
	var v: VBoxContainer = UIKit.vbox([], 2)
	if rep.is_empty():
		v.add_child(section(t("ui.office.report_none")))
		rep = gm.day_report
	else:
		v.add_child(section(t("ui.office.report", {"day": int(rep.get("day", 0))})))
	var inc: Dictionary = rep.get("income", {})
	var exp: Dictionary = rep.get("expense", {})
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	var total_in: int = 0
	var total_out: int = 0
	for k: String in inc:
		grid.add_child(UIKit.label(t("ui.cat." + k), UIKit.C_DIM))
		grid.add_child(UIKit.label("+" + UIKit.credits(int(inc[k])), UIKit.C_GOOD))
		total_in += int(inc[k])
	for k: String in exp:
		grid.add_child(UIKit.label(t("ui.cat." + k), UIKit.C_DIM))
		grid.add_child(UIKit.label("-" + UIKit.credits(int(exp[k])), UIKit.C_BAD))
		total_out += int(exp[k])
	grid.add_child(UIKit.label(t("ui.office.net"), UIKit.C_ACCENT))
	var net: int = total_in - total_out
	grid.add_child(UIKit.label(("+" if net >= 0 else "") + UIKit.credits(net), UIKit.C_GOOD if net >= 0 else UIKit.C_BAD))
	v.add_child(grid)
	var evs: Array = rep.get("events", [])
	var lines: Array[String] = []
	for e: Variant in evs:
		var ed: Dictionary = e
		if not str(ed.get("type", "")) in OfflineSim.NOTABLE and str(ed.get("type", "")) != "lot_lost":
			continue
		var txt: String = EventText.describe(ed)
		if not txt.is_empty():
			lines.append(txt)
	if not lines.is_empty():
		v.add_child(section(t("ui.office.events")))
		for txt: String in lines.slice(maxi(0, lines.size() - 10)):
			v.add_child(UIKit.wrap_label("• " + txt, 210))
	v.add_child(section(t("ui.office.stats")))
	var sg: GridContainer = GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 8)
	for r: Array in [
		["ui.office.sales", str(int(gm.counter("ships_sold")))],
		["ui.office.bought", str(int(gm.counter("wrecks_bought")))],
		["ui.office.repairs", str(int(gm.counter("defects_repaired")))],
		["ui.office.concealed", str(int(gm.counter("defects_concealed")))],
		["ui.office.sav", str(int(gm.counter("sav_claims")))],
		["ui.office.inspections", str(int(gm.counter("inspections")))],
	]:
		sg.add_child(UIKit.label(t(str(r[0])), UIKit.C_DIM))
		sg.add_child(UIKit.label(str(r[1])))
	v.add_child(sg)
	var susp: HBoxContainer = UIKit.hbox([UIKit.label(t("ui.office.suspicion"), UIKit.C_DIM), UIKit.bar(gm.suspicion, 10.0, UIKit.C_BAD, 60, 4)], 3)
	susp.tooltip_text = t("ui.office.suspicion_tip")
	susp.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(susp)
	make_scroll("office_report", UIKit.panel(v, "DarkPanel"), Rect2(242, 2, size.x - 244, size.y - 4))
