class_name SalesScreen
extends GameScreen
## Comptoir : clients aliens (budget, goûts, patience, commandes) et négociation vaisseau par vaisseau.

var selected_client: int = -1
var preselected_ship: int = -1
## Dernier résultat de négociation : {"client", "ship", "result", "price"}
var last_result: Dictionary = {}


func preselect_ship(id: int) -> void:
	preselected_ship = id
	dirty = true


func rebuild() -> void:
	UIKit.clear(self)
	var gm: GameModel = m()
	var clients: Array[Client] = gm.clients.duplicate()
	clients.sort_custom(func(a: Client, b: Client) -> bool:
		if a.quest.is_empty() != b.quest.is_empty():
			return not a.quest.is_empty()
		return a.leave_day < b.leave_day)
	if gm.find_client(selected_client) == null:
		selected_client = -1
		if preselected_ship >= 0:
			var s: Ship = gm.find_ship(preselected_ship)
			var best: int = -1
			for c: Client in clients:
				var w: int = Valuation.estimate_wtp(gm, c, s) if s != null else 0
				if w > best:
					best = w
					selected_client = c.id
		if selected_client < 0 and not clients.is_empty():
			selected_client = clients[0].id
	var lw: int = split(222)
	var list: VBoxContainer = UIKit.vbox([], 2)
	list.add_child(section(t("ui.sales.clients", {"n": clients.size()})))
	if clients.is_empty():
		list.add_child(UIKit.panel(UIKit.wrap_label(t("ui.sales.no_clients"), 200 + list_grow, UIKit.C_DIM), "DarkPanel"))
	for c: Client in clients:
		list.add_child(_client_card(c))
	make_scroll("clients", list, Rect2(2, 2, lw, size.y - 4))
	var sel: Client = gm.find_client(selected_client)
	if sel != null:
		_detail(sel)


static func likes_text(gm: GameModel, c: Client) -> String:
	var parts: Array[String] = []
	for cl: String in c.likes_classes:
		parts.append(I18n.t("class.%s" % cl))
	for col: String in c.likes_colors:
		parts.append(I18n.t("color.%s" % col))
	for tg: String in c.likes_tags:
		parts.append(I18n.t("tag.%s" % tg))
	for o: String in c.likes_options:
		parts.append(I18n.t("option.%s.name" % o))
	return ", ".join(parts) if not parts.is_empty() else "—"


func _client_card(c: Client) -> Control:
	var gm: GameModel = m()
	var row: HBoxContainer = UIKit.hbox([], 4)
	var pr: TextureRect = UIKit.portrait_rect(c.portrait)
	row.add_child(pr)
	var v: VBoxContainer = UIKit.vbox([], 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(c.name, UIKit.C_ACCENT))
	v.add_child(UIKit.label(t("species.%s.name" % c.species), UIKit.C_DIM))
	if not c.quest.is_empty():
		v.add_child(UIKit.label(t("ui.sales.order", {"title": t("quest.%s.title" % c.quest)}), UIKit.C_BLUE))
		v.add_child(UIKit.label(t("ui.sales.reward", {"budget": UIKit.credits(c.budget)})))
	else:
		v.add_child(UIKit.label(t("ui.sales.budget", {"budget": UIKit.credits(c.budget)})))
		var left: int = c.leave_day - gm.day
		v.add_child(UIKit.label(t("ui.sales.leaves", {"n": left}) if left > 0 else t("ui.sales.leaves_today"), UIKit.C_ORANGE if left <= 0 else UIKit.C_DIM))
	v.add_child(UIKit.wrap_label(t("ui.sales.likes", {"likes": likes_text(gm, c)}), 150 + list_grow, UIKit.C_TEXT))
	if not c.busy.is_empty():
		v.add_child(UIKit.label(t("ui.sales.with_seller"), UIKit.C_DIM))
	row.add_child(v)
	var cp: PanelContainer = card(row, c.id == selected_client)
	clickable(cp, func() -> void:
		selected_client = c.id
		last_result = {}
		dirty = true)
	return cp


func _detail(c: Client) -> void:
	var gm: GameModel = m()
	var v: VBoxContainer = UIKit.vbox([], 2)
	var head: HBoxContainer = UIKit.hbox([UIKit.portrait_rect(c.portrait)], 4)
	var hv: VBoxContainer = UIKit.vbox([UIKit.label(c.name, UIKit.C_ACCENT), UIKit.wrap_label(t("species.%s.desc" % c.species), 180 + detail_grow, UIKit.C_DIM)], 1)
	head.add_child(hv)
	v.add_child(head)
	if not c.quest.is_empty():
		v.add_child(section(t("ui.sales.criteria")))
		v.add_child(UIKit.wrap_label(criteria_text(c.criteria), 230 + detail_grow))
	if c.refusals > 0:
		v.add_child(UIKit.label(t("ui.sales.patience", {"n": c.refusals}), UIKit.C_ORANGE))
	if not last_result.is_empty() and int(last_result.get("client", -1)) == c.id:
		v.add_child(_result_box(c))
	v.add_child(section(t("ui.sales.your_ships")))
	var ships: Array[Ship] = gm.ships.duplicate()
	ships.sort_custom(func(a: Ship, b: Ship) -> bool:
		if a.id == preselected_ship:
			return true
		if b.id == preselected_ship:
			return false
		return Valuation.estimate_wtp(gm, c, a) > Valuation.estimate_wtp(gm, c, b))
	if ships.is_empty():
		v.add_child(UIKit.label(t("ui.sales.no_ships"), UIKit.C_DIM))
	for s: Ship in ships:
		v.add_child(_ship_offer(c, s))
	var p: PanelContainer = UIKit.panel(v, "DarkPanel")
	make_scroll("sale_detail", p, Rect2(228 + list_grow, 2, size.x - 230 - list_grow, size.y - 4))


static func criteria_text(crit: Dictionary) -> String:
	var lines: Array[String] = []
	if crit.has("class"):
		var names: Array[String] = []
		for cl: String in Util.str_array(crit["class"]):
			names.append(I18n.t("class.%s" % cl))
		lines.append(I18n.t("ui.crit.class", {"v": ", ".join(names)}))
	if crit.has("tags"):
		var tg: Array[String] = []
		for x: String in Util.str_array(crit["tags"]):
			tg.append(I18n.t("tag.%s" % x))
		lines.append(I18n.t("ui.crit.tags", {"v": ", ".join(tg)}))
	if crit.has("color"):
		lines.append(I18n.t("ui.crit.color", {"v": I18n.t("color.%s" % str(crit["color"]))}))
	if crit.has("options"):
		var op: Array[String] = []
		for x: String in Util.str_array(crit["options"]):
			op.append(I18n.t("option.%s.name" % x))
		lines.append(I18n.t("ui.crit.options", {"v": ", ".join(op)}))
	if crit.has("max_known_open"):
		lines.append(I18n.t("ui.crit.max_defects", {"v": int(crit["max_known_open"])}))
	if crit.has("max_wear"):
		lines.append(I18n.t("ui.crit.max_wear", {"v": "%d %%" % int(round(float(crit["max_wear"]) * 100.0))}))
	if bool(crit.get("honest", false)):
		lines.append(I18n.t("ui.crit.honest"))
	if crit.has("min_tier"):
		lines.append(I18n.t("ui.crit.min_tier", {"v": int(crit["min_tier"])}))
	return "\n".join(lines) if not lines.is_empty() else "—"


func _result_box(c: Client) -> Control:
	var res: String = str(last_result.get("result", ""))
	var price: int = int(last_result.get("price", 0))
	var v: VBoxContainer = UIKit.vbox([], 2)
	match res:
		"counter":
			v.add_child(UIKit.label(t("ui.sales.counter", {"price": UIKit.credits(price)}), UIKit.C_ACCENT))
			var row: HBoxContainer = UIKit.hbox([], 2)
			var ship_id: int = int(last_result.get("ship", -1))
			row.add_child(UIKit.button(t("ui.sales.accept"), func() -> void:
				var r: Dictionary = m().act_accept_counter(ship_id, c.id, price)
				last_result = {}
				act(r, t("ui.sales.sold", {"price": UIKit.credits(price)})), "ui_check"))
			row.add_child(UIKit.button(t("ui.sales.decline"), func() -> void:
				last_result = {}
				dirty = true))
			v.add_child(row)
		"refused":
			v.add_child(UIKit.label(t("ui.sales.refused"), UIKit.C_BAD))
		"criteria":
			v.add_child(UIKit.label(t("ui.sales.criteria_fail"), UIKit.C_BAD))
	return UIKit.panel(v, "FramePanel")


func _ship_offer(c: Client, s: Ship) -> Control:
	var gm: GameModel = m()
	var v: VBoxContainer = UIKit.vbox([], 1)
	var top: HBoxContainer = UIKit.hbox([], 3)
	var ramp: Array[Color] = ShipView.paint_ramp(db(), s.paint)
	top.add_child(UIKit.color_swatch(ramp[1], 8))
	top.add_child(UIKit.label(s.name, UIKit.C_ACCENT if s.id == preselected_ship else UIKit.C_TEXT))
	top.add_child(UIKit.label(t("class.%s" % s.ship_class(db())), UIKit.C_DIM))
	var match_f: float = Valuation.client_match(gm, c, s)
	if match_f >= 1.0:
		top.add_child(UIKit.icon_rect("ui_star", 10))
	v.add_child(top)
	var est: int = Valuation.estimate_wtp(gm, c, s)
	var cost: int = s.purchase_price + s.invested
	if s.is_busy():
		v.add_child(UIKit.label(t("ui.sales.busy"), UIKit.C_DIM))
	elif est <= 0:
		v.add_child(UIKit.label(t("ui.sales.no_match"), UIKit.C_DIM))
	else:
		v.add_child(UIKit.label(t("ui.sales.estimate", {"price": UIKit.credits(est), "cost": UIKit.credits(cost)}), UIKit.C_DIM))
		var row: HBoxContainer = UIKit.hbox([], 2)
		var asks: Array[int] = [Util.roundi_to(float(est) * 0.95, 10), Util.roundi_to(float(est), 10), Util.roundi_to(float(est) * 1.08, 10)]
		if not c.quest.is_empty():
			asks = [c.budget]
		for a: int in asks:
			var ask: int = a
			row.add_child(UIKit.button(UIKit.credits(ask), func() -> void: _offer(c, s, ask), "ui_sell" if a == asks[0] else "", t("ui.sales.offer_tip")))
		v.add_child(row)
	var known: int = s.known_open_defects().size()
	var conc: int = s.concealed_defects().size()
	if known > 0 or conc > 0:
		v.add_child(UIKit.label(t("ui.sales.defects_note", {"known": known, "concealed": conc}), UIKit.C_ORANGE))
	return UIKit.panel(v, "DarkPanel")


func _offer(c: Client, s: Ship, ask: int) -> void:
	var res: Dictionary = m().act_sell(s.id, c.id, ask)
	if not bool(res.get("ok", false)):
		act(res)
		return
	var r: String = str(res.get("result", ""))
	if r == "sold":
		last_result = {}
		preselected_ship = -1
		act(res, t("ui.sales.sold", {"price": UIKit.credits(ask)}))
		return
	last_result = {"client": c.id, "ship": s.id, "result": r, "price": int(res.get("price", 0))}
	act(res)
