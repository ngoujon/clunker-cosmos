class_name GarageScreen
extends GameScreen
## Garage en vue en coupe : baies (3 par étage, mezzanines ajoutées avec l'agrandissement), vaisseaux
## composés et peints, employés à leur poste, travail du patron (« Coup de main ») et fiche détaillée.

const COLS: int = 3
const BAY_W: int = 156
const BAY_H: int = 72
const DETAIL_W: int = 206

var _detail_scroll_key: String = "detail"


func background() -> Array:
	return ["res://assets/backgrounds/garage.png", 0.0]


func bay_rect(i: int) -> Rect2:
	var row: int = i / COLS
	var col: int = i % COLS
	return Rect2(4 + col * (BAY_W + 2), size.y - 2 - (row + 1) * (BAY_H + 2), BAY_W, BAY_H)


func rebuild() -> void:
	UIKit.clear(self)
	var gm: GameModel = m()
	var slots: int = gm.ship_slots()
	var rows: int = clampi(ceili(float(slots) / float(COLS)), 1, 3)
	for r: int in range(1, rows):
		_mezzanine(r)
	for i: int in slots:
		var s: Ship = gm.ships[i] if i < gm.ships.size() else null
		_bay(i, s)
	for i: int in range(slots, gm.ships.size()):
		_bay(i, gm.ships[i])
	_owner_box()
	if rows < 3:
		_staff_strip()
	var sel: Ship = gm.find_ship(main.selected_ship)
	if sel != null:
		_detail(sel)


# --- Décor ---------------------------------------------------------------------

func _mezzanine(row: int) -> void:
	var y: float = size.y - 2 - row * (BAY_H + 2) - 3
	var deck: ColorRect = ColorRect.new()
	deck.color = UIKit.C_SLATE
	deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(deck, Rect2(0, y, size.x, 5))
	var edge: ColorRect = ColorRect.new()
	edge.color = Color("#8a8fa6")
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(edge, Rect2(0, y, size.x, 1))
	for k: int in 12:
		var stripe: ColorRect = ColorRect.new()
		stripe.color = Color("#e0a42a") if k % 2 == 0 else UIKit.C_DARK
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		place(stripe, Rect2(k * 40, y + 2, 20, 2))
	for c: int in COLS + 1:
		var pillar: ColorRect = ColorRect.new()
		pillar.color = Color("#4a4d66")
		pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		place(pillar, Rect2(1 + c * (BAY_W + 2), y + 5, 3, BAY_H - 2))


func _bay(i: int, s: Ship) -> void:
	var r: Rect2 = bay_rect(mini(i, 8))
	var gm: GameModel = m()
	var selected: bool = s != null and s.id == main.selected_ship
	var frame: BayFrame = BayFrame.new()
	frame.selected = selected
	frame.empty = s == null
	place(frame, r)
	if s == null:
		var hint: Label = UIKit.label(t("ui.garage.empty_bay"), UIKit.C_DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		place(hint, Rect2(r.position.x, r.position.y + r.size.y - 16, r.size.x, 10))
		clickable(frame, func() -> void: main.show_screen("auctions"))
		frame.tooltip_text = t("ui.garage.empty_tip")
		return
	var v: ShipView = ShipView.new()
	v.setup(s, db())
	v.bob = not s.is_busy()
	var vx: float = r.position.x + floorf((r.size.x - v.size.x) / 2.0)
	var vy: float = r.position.y + r.size.y - 5 - v.size.y
	v.position = Vector2(vx, maxf(r.position.y + 10, vy))
	add_child(v)
	clickable(frame, func() -> void:
		main.selected_ship = s.id
		dirty = true)
	frame.tooltip_text = "%s — %s" % [s.name, t("class.%s" % s.ship_class(db()))]
	# Plaque : nom + icônes d'état
	var plate: HBoxContainer = UIKit.hbox([], 1)
	var name_l: Label = UIKit.label(s.name, UIKit.C_ACCENT if selected else UIKit.C_TEXT)
	plate.add_child(name_l)
	var known: int = s.known_open_defects().size()
	if known > 0:
		plate.add_child(UIKit.icon_rect("ui_warning", 10))
		plate.add_child(UIKit.label(str(known), UIKit.C_ORANGE))
	if s.for_sale:
		plate.add_child(UIKit.icon_rect("ui_sell", 10))
	if not s.item.is_empty() or s.rare:
		plate.add_child(UIKit.icon_rect("ui_star", 10))
	var plate_p: PanelContainer = UIKit.panel(plate, "DarkPanel")
	plate_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate_p)
	plate_p.position = r.position + Vector2(2, 1)
	# Travail en cours : barre + travailleur
	var job: Dictionary = _ship_job(s)
	if not job.is_empty():
		var jr: HBoxContainer = UIKit.hbox([], 2)
		var worker: String = str(job["worker"])
		if worker != "owner":
			var e: Employee = gm.find_employee(worker)
			if e != null:
				var ri: TextureRect = UIKit.icon_rect("role_" + e.role, 16)
				ri.tooltip_text = e.name
				jr.add_child(ri)
		jr.add_child(UIKit.icon_rect(str(job["icon"]), 16))
		var col: Color = UIKit.C_ORANGE if str(job["icon"]) == "ui_conceal" else UIKit.C_GOOD
		jr.add_child(UIKit.bar(float(job["done"]), float(job["total"]), col, 44, 4))
		var jp: PanelContainer = UIKit.panel(jr, "DarkPanel")
		jp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(jp)
		jp.position = Vector2(r.position.x + r.size.x - 86, r.position.y + 1)


## {worker, icon, done, total} du travail en cours sur le vaisseau, ou {}.
func _ship_job(s: Ship) -> Dictionary:
	for d: ShipDefect in s.defects:
		if d.is_busy():
			return {"worker": d.worker, "icon": "ui_conceal" if d.work_kind == "conceal" else "ui_repair", "done": d.progress, "total": Valuation.job_work(m(), d, d.work_kind)}
	if not s.custom_job.is_empty() and not str(s.custom_job.get("worker", "")).is_empty():
		return {"worker": str(s.custom_job["worker"]), "icon": "ui_paint", "done": float(s.custom_job.get("done", 0.0)), "total": float(s.custom_job.get("work", 1.0))}
	return {}


func _owner_box() -> void:
	var gm: GameModel = m()
	var v: VBoxContainer = UIKit.vbox([], 1)
	var head: HBoxContainer = UIKit.hbox([UIKit.label(t("ui.garage.you"), UIKit.C_ACCENT)], 3)
	var job_text: String = t("ui.garage.owner_free")
	var prog: Array[float] = WorkshopSystem.owner_progress(gm)
	if not gm.owner_job.is_empty():
		var s: Ship = gm.find_ship(int(gm.owner_job.get("ship", -1)))
		var idx: int = int(gm.owner_job.get("defect", -1))
		if s != null and str(gm.owner_job.get("kind", "")) == "defect" and idx >= 0 and idx < s.defects.size():
			var d: ShipDefect = s.defects[idx]
			job_text = t("ui.garage.owner_" + ("conceal" if d.work_kind == "conceal" else "repair"), {"defect": t("defect.%s.name" % d.type), "ship": s.name})
		elif s != null:
			job_text = t("ui.garage.owner_custom", {"ship": s.name})
	if not gm.is_owner_hour():
		job_text = t("ui.garage.owner_sleep")
	head.add_child(UIKit.label(job_text, UIKit.C_TEXT))
	v.add_child(head)
	var row: HBoxContainer = UIKit.hbox([], 3)
	if prog.size() == 2:
		row.add_child(UIKit.bar(prog[0], prog[1], UIKit.C_GOOD, 70, 5))
	var boosts_left: int = gm.db.cfgi("time", "owner_boosts_per_hour", 6) - gm.owner_boosts
	var b: Button = UIKit.button(t("ui.garage.boost", {"n": boosts_left}), func() -> void:
		act(m().act_boost()), "ui_repair", t("ui.garage.boost_tip"))
	b.disabled = gm.owner_job.is_empty() or boosts_left <= 0
	row.add_child(b)
	row.add_child(UIKit.label(t("ui.garage.capacity", {"n": gm.ships.size(), "max": gm.ship_slots(), "level": gm.garage_level}), UIKit.C_DIM))
	v.add_child(row)
	var p: PanelContainer = UIKit.panel(v, "DarkPanel")
	add_child(p)
	p.position = Vector2(2, 2)


func _staff_strip() -> void:
	var gm: GameModel = m()
	if gm.staff.is_empty():
		return
	var row: HBoxContainer = UIKit.hbox([], 2)
	for e: Employee in gm.staff:
		var chip: VBoxContainer = UIKit.vbox([], 0)
		var top: Control = Control.new()
		top.custom_minimum_size = Vector2(24, 24)
		top.mouse_filter = Control.MOUSE_FILTER_PASS
		var pr: TextureRect = TextureRect.new()
		pr.texture = UIKit.portrait_small(e.portrait)
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pr.custom_minimum_size = Vector2(24, 24)
		pr.size = Vector2(24, 24)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not e.is_working() or not m().is_shift_hour():
			pr.modulate = Color(0.55, 0.55, 0.6)
		top.add_child(pr)
		var ri: TextureRect = UIKit.icon_rect("role_" + e.role, 16)
		ri.position = Vector2(14, 14)
		ri.size = Vector2(16, 16)
		ri.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(ri)
		chip.add_child(top)
		chip.add_child(UIKit.bar(100.0 - e.fatigue, 100.0, UIKit.C_GOOD if e.fatigue < 50.0 else UIKit.C_ORANGE, 24, 2))
		chip.tooltip_text = "%s — %s %d\n%s" % [e.name, t("role.%s.name" % e.role), e.level, StaffScreen.status_text(gm, e)]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(chip)
	var p: PanelContainer = UIKit.panel(row, "DarkPanel")
	add_child(p)
	p.reset_size()
	p.position = Vector2(size.x - p.get_combined_minimum_size().x - 2, 2)
	clickable(p, func() -> void: main.show_screen("staff"))


# --- Fiche du vaisseau -------------------------------------------------------------

func _detail(s: Ship) -> void:
	var gm: GameModel = m()
	var v: VBoxContainer = UIKit.vbox([], 2)
	var head: HBoxContainer = UIKit.hbox([UIKit.label(s.name, UIKit.C_ACCENT)], 2)
	head.add_child(UIKit.spacer(0, 0, true))
	head.add_child(UIKit.button("×", func() -> void:
		main.selected_ship = -1
		dirty = true))
	v.add_child(head)
	v.add_child(UIKit.label("%s · %s · %s" % [t("class.%s" % s.ship_class(db())), t("ui.tier", {"n": s.tier(db())}), t("paint.%s" % s.paint)], UIKit.C_DIM))
	var preview: CenterContainer = CenterContainer.new()
	var sv: ShipView = ShipView.new()
	sv.setup(s, db())
	preview.add_child(sv)
	v.add_child(preview)
	var parts: Label = UIKit.wrap_label("%s / %s / %s / %s" % [t("part.%s.name" % s.hull), t("part.%s.name" % s.engine), t("part.%s.name" % s.cockpit), t("part.%s.name" % s.wings)], DETAIL_W - 16, UIKit.C_DIM)
	v.add_child(parts)
	var val: GridContainer = GridContainer.new()
	val.columns = 2
	val.add_theme_constant_override("h_separation", 6)
	val.add_child(UIKit.label(t("ui.garage.value"), UIKit.C_DIM))
	val.add_child(UIKit.label(UIKit.credits(int(Valuation.apparent_value(gm, s)))))
	val.add_child(UIKit.label(t("ui.garage.invested"), UIKit.C_DIM))
	val.add_child(UIKit.label("%s + %s" % [UIKit.credits(s.purchase_price), UIKit.credits(s.invested)]))
	val.add_child(UIKit.label(t("ui.garage.wear"), UIKit.C_DIM))
	var wear_row: HBoxContainer = UIKit.hbox([UIKit.bar(s.wear, 1.0, UIKit.C_ORANGE, 50, 4), UIKit.label(pct(s.wear))], 3)
	val.add_child(wear_row)
	v.add_child(val)
	# Défauts
	v.add_child(section(t("ui.garage.defects")))
	if not s.scanned:
		v.add_child(UIKit.wrap_label(t("ui.garage.not_scanned"), DETAIL_W - 16, UIKit.C_DIM))
	var any: bool = false
	for i: int in s.defects.size():
		var d: ShipDefect = s.defects[i]
		if not d.known:
			continue
		any = true
		v.add_child(_defect_row(s, d, i))
	if not any:
		v.add_child(UIKit.label(t("ui.garage.no_defect"), UIKit.C_GOOD))
	# Personnalisation
	v.add_child(section(t("ui.garage.custom")))
	if not s.custom_job.is_empty():
		v.add_child(UIKit.hbox([UIKit.icon_rect("ui_paint"), UIKit.label(t("ui.garage.custom_running")), UIKit.bar(float(s.custom_job.get("done", 0.0)), float(s.custom_job.get("work", 1.0)), UIKit.C_GOOD, 50, 4)], 2))
	var paints: HFlowContainer = HFlowContainer.new()
	paints.add_theme_constant_override("h_separation", 1)
	paints.add_theme_constant_override("v_separation", 1)
	for pid: String in db().paints:
		if not gm.is_unlocked("paint:" + pid) or pid == "paint_primer":
			continue
		paints.add_child(_paint_button(s, pid))
	v.add_child(paints)
	var opts: HFlowContainer = HFlowContainer.new()
	opts.add_theme_constant_override("h_separation", 1)
	opts.add_theme_constant_override("v_separation", 1)
	for oid: String in db().options:
		if not gm.is_unlocked("option:" + oid):
			continue
		opts.add_child(_option_button(s, oid))
	v.add_child(opts)
	# Vente
	v.add_child(section(t("ui.garage.sale")))
	var sale: HFlowContainer = HFlowContainer.new()
	sale.add_theme_constant_override("h_separation", 2)
	sale.add_theme_constant_override("v_separation", 2)
	sale.add_child(UIKit.button(t("ui.garage.unlist") if s.for_sale else t("ui.garage.list"), func() -> void: act(m().act_list(s.id, not s.for_sale)), "ui_sell"))
	sale.add_child(UIKit.button(t("ui.garage.find_client"), func() -> void:
		main.show_screen("sales")
		(main.screen("sales") as SalesScreen).preselect_ship(s.id)))
	var scrap_value: int = int(round(s.base_value(db()) * 0.2))
	sale.add_child(UIKit.button(t("ui.garage.scrap", {"price": UIKit.credits(scrap_value)}), func() -> void:
		main.confirm(t("ui.garage.scrap_confirm", {"ship": s.name, "price": UIKit.credits(scrap_value)}), func() -> void:
			main.selected_ship = -1
			act(m().act_scrap(s.id)))))
	v.add_child(sale)
	var p: PanelContainer = UIKit.panel(v, "DarkPanel")
	var sc: ScrollContainer = make_scroll(_detail_scroll_key, p, Rect2(size.x - DETAIL_W - 2, 2, DETAIL_W, size.y - 4))
	sc.get_v_scroll_bar().custom_minimum_size = Vector2(4, 0)


func _defect_row(s: Ship, d: ShipDefect, i: int) -> Control:
	var gm: GameModel = m()
	var def: Dictionary = db().defects.get(d.type, {})
	var v: VBoxContainer = UIKit.vbox([], 1)
	var top: HBoxContainer = UIKit.hbox([UIKit.icon_rect(str(def.get("icon", "ui_warning")))], 2)
	var name_col: Color = UIKit.C_BAD if bool(def.get("danger", false)) else UIKit.C_TEXT
	top.add_child(UIKit.label(t("defect.%s.name" % d.type), name_col))
	top.add_child(UIKit.label(UIKit.sev_dots(d.sev), UIKit.C_ORANGE))
	top.add_child(UIKit.spacer(0, 0, true))
	match d.state:
		"repaired":
			top.add_child(UIKit.label(t("ui.defect.repaired"), UIKit.C_GOOD))
		"concealed":
			top.add_child(UIKit.label(t("ui.defect.concealed"), UIKit.C_ORANGE))
	top.tooltip_text = t("defect.%s.desc" % d.type) + ("\n" + t("ui.defect.danger") if bool(def.get("danger", false)) else "")
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(top)
	if d.is_open():
		var row: HBoxContainer = UIKit.hbox([], 2)
		if d.is_busy():
			var who: String = t("ui.garage.you") if d.worker == "owner" else EventText._employee_name(d.worker)
			row.add_child(UIKit.label(who, UIKit.C_DIM))
			row.add_child(UIKit.bar(d.progress, Valuation.job_work(gm, d, d.work_kind), UIKit.C_ORANGE if d.work_kind == "conceal" else UIKit.C_GOOD, 60, 4))
		else:
			var rc: int = Valuation.repair_cost(gm, s, d)
			var rb: Button = UIKit.button(t("ui.defect.repair", {"cost": UIKit.credits(rc)}), func() -> void: act(m().act_repair(s.id, i, "repair")), "", t("ui.defect.repair_tip", {"hours": "%.1f" % (Valuation.repair_work(gm, d) / gm.stat("owner_speed") / gm.stat("repair_speed"))}))
			row.add_child(rb)
			if bool(def.get("concealable", true)):
				var cc: int = Valuation.conceal_cost(gm, s, d)
				row.add_child(UIKit.button(t("ui.defect.conceal", {"cost": UIKit.credits(cc)}), func() -> void: act(m().act_repair(s.id, i, "conceal")), "", t("ui.defect.conceal_tip")))
			var ob: OptionButton = OptionButton.new()
			ob.focus_mode = Control.FOCUS_NONE
			ob.fit_to_longest_item = false
			var decisions: PackedStringArray = ["auto", "repair", "conceal", "disclose"]
			for k: int in decisions.size():
				if decisions[k] == "conceal" and not bool(def.get("concealable", true)):
					continue
				ob.add_item(t("ui.decision." + decisions[k]), k)
			ob.select(ob.get_item_index(decisions.find(d.decision)))
			ob.tooltip_text = t("ui.decision.tip")
			ob.item_selected.connect(func(idx: int) -> void: act(m().act_set_decision(s.id, i, decisions[ob.get_item_id(idx)])))
			row.add_child(ob)
		v.add_child(row)
	return v


func _paint_button(s: Ship, pid: String) -> Control:
	var ramp: Array[Color] = ShipView.paint_ramp(db(), pid)
	var b: Button = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(14, 14)
	var sw: ColorRect = UIKit.color_swatch(ramp[1], 8)
	sw.position = Vector2(3, 3)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sw)
	var cost: int = Valuation.paint_cost(m(), s)
	b.tooltip_text = t("ui.garage.paint_tip", {"paint": t("paint.%s" % pid), "cost": UIKit.credits(cost)})
	b.disabled = s.paint == pid
	b.pressed.connect(func() -> void: act(m().act_customize(s.id, "paint", pid)))
	return b


func _option_button(s: Ship, oid: String) -> Control:
	var o: Dictionary = db().options.get(oid, {})
	var b: Button = UIKit.button("", func() -> void: act(m().act_customize(s.id, "option", oid)), str(o.get("icon", oid)))
	var cost: int = Valuation.option_cost(m(), oid)
	b.tooltip_text = "%s — %s\n%s" % [t("option.%s.name" % oid), UIKit.credits(cost), t("option.%s.desc" % oid)]
	if oid in s.options:
		b.disabled = true
		b.tooltip_text += "\n" + t("ui.garage.installed")
	return b


## Cadre de baie : survol et sélection dessinés en pixels.
class BayFrame extends Control:
	var selected: bool = false
	var empty: bool = false
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		if empty:
			draw_rect(r.grow(-1), Color(UIKit.C_DARK, 0.35), true)
			_dashes(r.grow(-1), Color(UIKit.C_DIM, 0.8))
		if selected:
			draw_rect(r.grow(-0.5), UIKit.C_ACCENT, false, 1.0)
		elif _hover:
			draw_rect(r.grow(-0.5), Color(UIKit.C_TEXT, 0.6), false, 1.0)

	func _dashes(r: Rect2, c: Color) -> void:
		var x: float = r.position.x
		while x < r.end.x:
			draw_rect(Rect2(x, r.position.y, 3, 1), c)
			draw_rect(Rect2(x, r.end.y - 1, 3, 1), c)
			x += 6.0
		var y: float = r.position.y
		while y < r.end.y:
			draw_rect(Rect2(r.position.x, y, 1, 3), c)
			draw_rect(Rect2(r.end.x - 1, y, 1, 3), c)
			y += 6.0
