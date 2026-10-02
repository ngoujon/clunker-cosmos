class_name AuctionScreen
extends GameScreen
## Enchères : onglets par lieu (fonds dédiés), liste des lots, fiche du lot (état partiellement caché,
## scan payant, estimation, enchère par procuration).

var location: String = "ferropolis"
var selected_lot: int = -1


func background() -> Array:
	return ["res://assets/backgrounds/%s.png" % str(db().locations.get(location, {}).get("background", "loc_ferropolis")), 0.18]


func on_show() -> void:
	if not m().is_unlocked("location:" + location):
		location = "ferropolis"
	dirty = true


func _open_lots() -> Array[AuctionLot]:
	var out: Array[AuctionLot] = []
	for l: AuctionLot in m().lots:
		if not l.closed and l.location == location:
			out.append(l)
	out.sort_custom(func(a: AuctionLot, b: AuctionLot) -> bool:
		if (a.special.is_empty()) != (b.special.is_empty()):
			return not a.special.is_empty()
		return a.close_hour < b.close_hour)
	return out


func rebuild() -> void:
	UIKit.clear(self)
	var gm: GameModel = m()
	# Onglets des lieux
	var tabs: HBoxContainer = UIKit.hbox([], 1)
	for lid: String in db().location_order:
		var lid2: String = lid
		var unlocked: bool = gm.is_unlocked("location:" + lid)
		var n: int = 0
		for l: AuctionLot in gm.lots:
			if not l.closed and l.location == lid:
				n += 1
		var label: String = t("location.%s.name" % lid) + (" (%d)" % n if unlocked else "")
		var b: Button = UIKit.button(label, func() -> void:
			location = lid2
			selected_lot = -1
			main.show_screen("auctions"), "" if unlocked else "ui_lock")
		b.toggle_mode = true
		b.theme_type_variation = "NavButton"
		b.set_pressed_no_signal(lid == location)
		b.disabled = not unlocked
		b.tooltip_text = t("location.%s.desc" % lid) + ("" if unlocked else "\n" + _unlock_hint(lid))
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		tabs.add_child(b)
	place(tabs, Rect2(2, 1, size.x - 4, 18))
	var lots: Array[AuctionLot] = _open_lots()
	if selected_lot < 0 or gm.find_lot(selected_lot) == null or gm.find_lot(selected_lot).closed:
		selected_lot = lots[0].id if not lots.is_empty() else -1
	# Liste des lots
	var list: VBoxContainer = UIKit.vbox([], 2)
	if lots.is_empty():
		list.add_child(UIKit.panel(UIKit.wrap_label(t("ui.auction.no_lots"), 170, UIKit.C_DIM), "DarkPanel"))
	for l: AuctionLot in lots:
		list.add_child(_lot_card(l))
	make_scroll("lots_" + location, list, Rect2(2, 21, 190, size.y - 23))
	var sel: AuctionLot = gm.find_lot(selected_lot)
	if sel != null:
		_detail(sel)


func _unlock_hint(lid: String) -> String:
	for nid: String in db().tech:
		for e: Variant in db().tech[nid].get("effects", []):
			var ed: Dictionary = e
			if str(ed.get("op", "")) == "unlock" and str(ed.get("target", "")) == "location:" + lid:
				return t("ui.auction.unlock_by", {"node": t("tech.%s.name" % nid)})
	return t("ui.auction.unlock_story")


func _status(l: AuctionLot) -> Array:
	var gm: GameModel = m()
	if l.player_max > 0:
		if l.player_leading(gm.now()):
			return [t("ui.auction.leading", {"max": UIKit.credits(l.player_max)}), UIKit.C_GOOD]
		return [t("ui.auction.outbid"), UIKit.C_BAD]
	return [t("ui.auction.no_bid"), UIKit.C_DIM]


func _hours_left(l: AuctionLot) -> int:
	return maxi(0, l.close_hour - m().now())


func _lot_card(l: AuctionLot) -> Control:
	var gm: GameModel = m()
	var s: Ship = l.ship
	var v: VBoxContainer = UIKit.vbox([], 0)
	var top: HBoxContainer = UIKit.hbox([UIKit.label(t("class.%s" % s.ship_class(db())), UIKit.C_ACCENT), UIKit.label(t("ui.tier", {"n": s.tier(db())}), UIKit.C_DIM)], 3)
	top.add_child(UIKit.spacer(0, 0, true))
	if not l.special.is_empty():
		top.add_child(UIKit.label(t("ui.auction.special"), UIKit.C_ACCENT))
	elif s.rare:
		top.add_child(UIKit.label(t("ui.auction.rare"), UIKit.C_ACCENT))
	if l.scanned:
		top.add_child(UIKit.icon_rect("ui_scan", 10))
	v.add_child(top)
	v.add_child(UIKit.label(t("ui.auction.price_line", {"price": UIKit.credits(l.visible_price(gm.now())), "h": _hours_left(l), "close": "%02d:00" % (l.close_hour % 24)})))
	var st: Array = _status(l)
	v.add_child(UIKit.label(str(st[0]), st[1]))
	var c: PanelContainer = card(v, l.id == selected_lot)
	clickable(c, func() -> void:
		selected_lot = l.id
		dirty = true)
	return c


func _detail(l: AuctionLot) -> void:
	var gm: GameModel = m()
	var s: Ship = l.ship
	var v: VBoxContainer = UIKit.vbox([], 2)
	var head: HBoxContainer = UIKit.hbox([UIKit.label(s.name, UIKit.C_ACCENT), UIKit.label("%s · %s" % [t("class.%s" % s.ship_class(db())), t("ui.tier", {"n": s.tier(db())})], UIKit.C_DIM)], 4)
	v.add_child(head)
	if not l.special.is_empty():
		v.add_child(UIKit.wrap_label(t("ui.auction.special_desc", {"name": t("special.%s.name" % l.special)}), 250, UIKit.C_ACCENT))
	var mid: HBoxContainer = UIKit.hbox([], 4)
	var preview: CenterContainer = CenterContainer.new()
	preview.custom_minimum_size = Vector2(150, 66)
	var sv: ShipView = ShipView.new()
	sv.setup(s, db())
	sv.bob = true
	preview.add_child(sv)
	preview.tooltip_text = "%s / %s / %s / %s" % [t("part.%s.name" % s.hull), t("part.%s.name" % s.engine), t("part.%s.name" % s.cockpit), t("part.%s.name" % s.wings)]
	preview.mouse_filter = Control.MOUSE_FILTER_PASS
	mid.add_child(preview)
	var side: VBoxContainer = UIKit.vbox([UIKit.label(t("ui.auction.defects"), UIKit.C_DIM)], 1)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var defs: HFlowContainer = HFlowContainer.new()
	var known: int = 0
	for d: ShipDefect in s.defects:
		if d.known and d.is_open():
			known += 1
			var ic: TextureRect = UIKit.icon_rect(str(db().defects.get(d.type, {}).get("icon", "ui_warning")))
			ic.tooltip_text = "%s %s" % [t("defect.%s.name" % d.type), UIKit.sev_dots(d.sev)]
			defs.add_child(ic)
	if known == 0:
		defs.add_child(UIKit.label(t("ui.auction.none_known"), UIKit.C_DIM))
	side.add_child(defs)
	side.add_child(UIKit.label(t("ui.auction.scanned") if l.scanned else t("ui.auction.hidden_unknown"), UIKit.C_BLUE if l.scanned else UIKit.C_ORANGE))
	mid.add_child(side)
	v.add_child(mid)
	var est: Dictionary = Valuation.lot_estimate(gm, l)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 0)
	var rows: Array[Array] = [
		["ui.auction.estimate", "%s – %s" % [UIKit.credits(int(est["low"])), UIKit.credits(int(est["high"]))]],
		["ui.auction.repairs", UIKit.credits(int(est["repairs"]))],
		["ui.auction.current", UIKit.credits(l.visible_price(gm.now()))],
		["ui.auction.your_max", UIKit.credits(l.player_max) if l.player_max > 0 else "—"],
		["ui.auction.closes", t("ui.auction.closes_at", {"day": l.close_hour / 24, "hour": "%02d:00" % (l.close_hour % 24), "h": _hours_left(l)})],
	]
	for r: Array in rows:
		grid.add_child(UIKit.label(t(str(r[0])), UIKit.C_DIM))
		grid.add_child(UIKit.label(str(r[1])))
	v.add_child(grid)
	var st: Array = _status(l)
	v.add_child(UIKit.label(str(st[0]), st[1]))
	# Actions
	var acts: HFlowContainer = HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 2)
	acts.add_theme_constant_override("v_separation", 2)
	var scan_b: Button = UIKit.button(t("ui.auction.scan", {"cost": UIKit.credits(AuctionSystem.scan_cost(gm, l))}), func() -> void:
		var res: Dictionary = m().act_scan(l.id)
		act(res, t("ui.auction.scan_result", {"found": int(res.get("found", 0))}) if bool(res.get("ok", false)) else ""), "ui_scan", t("ui.auction.scan_tip"))
	scan_b.disabled = l.scanned
	acts.add_child(scan_b)
	var minb: int = AuctionSystem.min_bid(gm, l)
	var advice: int = maxi(minb, AuctionSystem.valuation(gm, l, 0.0))
	var amounts: Array[int] = [minb, Util.roundi_to(float(minb) * 1.2, 10)]
	if advice > amounts[1]:
		amounts.append(advice)
	for a: int in amounts:
		var amount: int = a
		var key: String = "ui.auction.bid_advice" if a == advice and a != minb else "ui.auction.bid"
		acts.add_child(UIKit.button(t(key, {"amount": UIKit.credits(amount)}), func() -> void:
			act(m().act_bid(l.id, amount), t("ui.auction.bid_ok", {"amount": UIKit.credits(amount)})), "ui_bid"))
	v.add_child(acts)
	v.add_child(UIKit.wrap_label(t("ui.auction.proxy_note", {"fee": pct(gm.stat("auction_fee"))}), 250, UIKit.C_DIM))
	var p: PanelContainer = UIKit.panel(v, "DarkPanel")
	make_scroll("lot_detail", p, Rect2(196, 21, size.x - 198, size.y - 23))
