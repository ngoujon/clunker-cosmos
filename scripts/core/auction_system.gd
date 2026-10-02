class_name AuctionSystem
extends RefCounted
## Enchères : génération quotidienne des lots, scans payants, enchères par procuration,
## résolution à la clôture et automatisation de l'Acheteur.


static func generate_day(m: GameModel) -> void:
	var keep: Array[AuctionLot] = []
	for l: AuctionLot in m.lots:
		if not l.closed and l.close_hour > m.now():
			keep.append(l)
	m.lots = keep
	var n: int = maxi(1, m.stati("auction_lots"))
	var day_start: int = m.day * 24
	var hours: Array[int] = Util.int_array(m.db.cfg("auction", "close_hours", [12, 16, 20]))
	for loc: String in m.unlocked_locations():
		for i: int in n:
			var rare: bool = m.rng.randf() < m.db.cfgf("auction", "rare_chance", 0.04) * m.stat("rare_chance")
			var ship: Ship = ShipFactory.make_wreck(m, loc, rare)
			var close: int = day_start + hours[m.rng.randi_range(0, hours.size() - 1)]
			add_lot(m, loc, ship, "", close)
	spawn_pending_now(m)


## Met aux enchères les lots spéciaux en attente dont le lieu est accessible.
## Un lot spécial perdu revient en attente (il réapparaît le lendemain) tant que l'objet n'est pas obtenu.
static func spawn_pending_now(m: GameModel) -> void:
	var still_pending: Array[String] = []
	for sp: String in m.pending_specials:
		if _special_owned(m, sp):
			continue
		if _special_listed(m, sp):
			still_pending.append(sp)
			continue
		var loc_id: String = str(m.db.special_lots.get(sp, {}).get("location", "ferropolis"))
		if m.is_unlocked("location:" + loc_id):
			add_lot(m, loc_id, ShipFactory.make_special(m, sp), sp, maxi(m.day * 24 + 20, m.now() + 10))
		still_pending.append(sp)
	m.pending_specials = still_pending


static func _special_listed(m: GameModel, sp: String) -> bool:
	for l: AuctionLot in m.lots:
		if l.special == sp and not l.closed:
			return true
	return false


static func _special_owned(m: GameModel, sp: String) -> bool:
	var item: String = str(m.db.special_lots.get(sp, {}).get("item", ""))
	return not item.is_empty() and item in m.items


static func add_lot(m: GameModel, loc: String, ship: Ship, special: String, close_hour: int) -> AuctionLot:
	var lot: AuctionLot = AuctionLot.new()
	lot.id = m.new_id()
	lot.location = loc
	lot.ship = ship
	lot.special = special
	lot.open_hour = mini(m.now(), close_hour - 2)
	lot.close_hour = maxi(close_hour, m.now() + 2)
	var base: float = ship.base_value(m.db)
	var price_mult: float = float(m.db.locations.get(loc, {}).get("price_mult", 1.0))
	if not special.is_empty():
		price_mult *= float(m.db.special_lots.get(special, {}).get("price_mult", 1.0))
	lot.start_price = Util.roundi_to(base * m.db.cfgf("auction", "start_frac", 0.1) * price_mult, 10)
	var tv: float = Valuation.true_value(m, ship)
	var npc: float = tv * m.rng.randf_range(m.db.cfgf("auction", "npc_min", 0.42), m.db.cfgf("auction", "npc_max", 0.66)) * price_mult
	if not special.is_empty():
		npc *= 0.6
	lot.npc_max = maxi(lot.start_price, Util.roundi_to(npc, 10))
	m.lots.append(lot)
	return lot


static func scan_cost(m: GameModel, lot: AuctionLot) -> int:
	var c: float = m.db.cfgf("auction", "scan_base_cost", 80) + lot.ship.base_value(m.db) * m.db.cfgf("auction", "scan_cost_frac", 0.012)
	return Util.roundi_to(c * m.stat("scan_cost"), 5)


static func scan(m: GameModel, lot: AuctionLot, by: String, bonus: float = 0.0) -> Dictionary:
	if lot.scanned:
		return GameModel.fail("already_scanned")
	var cost: int = scan_cost(m, lot)
	if not m.spend(cost, "scans"):
		return GameModel.fail("credits")
	lot.scanned = true
	lot.ship.scanned = true
	var found: int = 0
	for d: ShipDefect in lot.ship.hidden_defects():
		var p: float = clampf(m.stat("scan_power") + bonus - float(m.db.defects[d.type].get("scan_diff", 0.3)) * 0.5, 0.05, 0.98)
		if m.rng.randf() < p:
			d.known = true
			found += 1
	m.add_rp(m.db.cfgf("research", "rp_per_scan", 0.5))
	m.emit({"type": "lot_scanned", "lot": lot.id, "found": found, "by": by, "cost": cost})
	return GameModel.ok({"found": found, "cost": cost})


static func min_bid(m: GameModel, lot: AuctionLot) -> int:
	if lot.player_leading(m.now()):
		return lot.player_max + lot.increment()
	return maxi(lot.start_price, lot.visible_price(m.now()) + lot.increment())


static func place_bid(m: GameModel, lot: AuctionLot, amount: int) -> Dictionary:
	if amount < min_bid(m, lot):
		return GameModel.fail("too_low")
	var fee: float = m.stat("auction_fee")
	if float(amount) * (1.0 + fee) > float(m.credits):
		return GameModel.fail("credits")
	if lot.player_max <= 0 and m.free_slots(true) <= 0:
		return GameModel.fail("no_slot")
	lot.player_max = amount
	m.emit({"type": "bid_placed", "lot": lot.id, "amount": amount})
	return GameModel.ok({"leading": lot.player_leading(m.now())})


static func hour_tick(m: GameModel) -> void:
	for lot: AuctionLot in m.lots:
		if not lot.closed and lot.close_hour <= m.now():
			resolve(m, lot)


static func resolve(m: GameModel, lot: AuctionLot) -> void:
	lot.closed = true
	var price: int = lot.winning_price()
	if price < 0:
		lot.result = "lost"
		if lot.player_max > 0:
			m.emit({"type": "lot_lost", "lot": lot.id, "price": lot.npc_max})
		return
	var fee: int = int(round(float(price) * m.stat("auction_fee")))
	if m.free_slots(false) <= 0 or m.credits < price + fee:
		lot.result = "defaulted"
		m.add_reputation(-m.db.cfgf("auction", "default_reputation", 5.0))
		m.emit({"type": "lot_defaulted", "lot": lot.id, "price": price})
		return
	m.spend(price, "purchases")
	m.spend(fee, "fees")
	lot.result = "won"
	lot.paid = price + fee
	var s: Ship = lot.ship
	s.acquired_day = m.day
	s.purchase_price = price + fee
	m.ships.append(s)
	m.count("wrecks_bought")
	m.emit({"type": "wreck_bought", "ship": s.id, "price": price + fee, "location": lot.location, "special": lot.special, "rare": s.rare})
	if not s.item.is_empty() and not s.item in m.items:
		m.items.append(s.item)
		m.emit({"type": "item_found", "item": s.item, "ship": s.id})


# --- Automatisation : Acheteur ------------------------------------------------

## Valeur maximale que l'acheteur est prêt à miser (marge cible incluse).
static func valuation(m: GameModel, lot: AuctionLot, noise: float) -> int:
	var est: Dictionary = Valuation.lot_estimate(m, lot)
	var target: float = float(est["mid"]) * (1.0 - 0.28) * (1.0 + noise) / (1.0 + m.stat("auction_fee"))
	return maxi(0, Util.roundi_to(target, 10))


static func buyer_candidates(m: GameModel, rule: String) -> Array[AuctionLot]:
	var out: Array[AuctionLot] = []
	var score: Dictionary = {}
	for lot: AuctionLot in m.lots:
		if lot.closed or lot.close_hour <= m.now() + 1:
			continue
		out.append(lot)
		var price: float = float(lot.visible_price(m.now()))
		match rule:
			"cheapest":
				score[lot.id] = -price
			"rare_first":
				score[lot.id] = lot.ship.base_value(m.db) + (1.0e6 if lot.ship.rare or not lot.special.is_empty() else 0.0)
			_:
				score[lot.id] = float(Valuation.lot_estimate(m, lot)["mid"]) - price
	out.sort_custom(func(a: AuctionLot, b: AuctionLot) -> bool: return float(score[a.id]) > float(score[b.id]))
	return out


## Une heure de travail de l'acheteur : un scan (1 h) ou une série d'offres.
static func buyer_step(m: GameModel, e: Employee, eff: float) -> void:
	var noise_scale: float = 0.12 / (1.0 + 0.25 * float(e.level - 1)) * e.trait_mod(m.db, "valuation_noise", 1.0)
	var pending: int = 0
	for s: Ship in m.ships:
		pending += Valuation.repair_estimate(m, s)
	var budget: int = int(float(m.credits - pending) * float(m.settings.get("buyer_budget", 0.6)))
	var committed: int = 0
	for l: AuctionLot in m.lots:
		if not l.closed and l.player_max > 0:
			committed += l.player_max + Valuation.repair_estimate(m, l.ship)
	var scanned_this_hour: bool = false
	for lot: AuctionLot in buyer_candidates(m, e.rule):
		if m.free_slots(true) <= 0 and lot.player_max <= 0:
			break
		var est: Dictionary = Valuation.lot_estimate(m, lot)
		if not lot.scanned and not scanned_this_hour and eff > 0.3 and int(est["mid"]) > 2000 and m.credits > scan_cost(m, lot) * 6:
			scan(m, lot, e.id, 0.05 * float(e.level - 1) + e.trait_mod(m.db, "reveal", 0.0))
			scanned_this_hour = true
			continue
		var noise: float = (Util.hash01(lot.id, e.id.hash(), 7) - 0.5) * 2.0 * noise_scale
		var want: int = valuation(m, lot, noise)
		if not lot.special.is_empty():
			want = maxi(want, int(float(lot.start_price) * 3.0))
		var need: int = min_bid(m, lot)
		var extra: int = want - lot.player_max + (Valuation.repair_estimate(m, lot.ship) if lot.player_max <= 0 else 0)
		if want >= need and lot.player_max < want and committed + extra <= budget:
			var res: Dictionary = place_bid(m, lot, want)
			if bool(res["ok"]):
				committed += extra
