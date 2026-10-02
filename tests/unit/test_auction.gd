extends TestCase
## Enchères : lots quotidiens, scans, offres par procuration, résolution, acheteur automatique.


func _open_lot(m: GameModel) -> AuctionLot:
	for l: AuctionLot in m.lots:
		if not l.closed and l.close_hour > m.now() + 1:
			return l
	return null


func test_daily_lots_per_unlocked_location() -> void:
	var m: GameModel = new_model()
	eq(m.lots.size(), int(db.stats["auction_lots"]), "lots au jour 1 (Ferropolis seulement)")
	ResearchSystem.grant(m, "li_1")
	m.advance_hours(24)
	var by_loc: Dictionary = {}
	for l: AuctionLot in m.lots:
		by_loc[l.location] = int(by_loc.get(l.location, 0)) + 1
	eq(int(by_loc.get("kryo7", 0)), int(db.stats["auction_lots"]), "lots à Kryo-7 après déblocage")


func test_visible_price_rises_over_time() -> void:
	var m: GameModel = new_model()
	var l: AuctionLot = _open_lot(m)
	var p0: int = l.visible_price(l.open_hour)
	var p1: int = l.visible_price(l.close_hour)
	ge(float(p1), float(p0), "le prix monte")
	eq(p1, l.npc_max, "les PNJ vont jusqu'à leur maximum")


func test_scan_costs_and_reveals() -> void:
	var m: GameModel = new_model()
	var l: AuctionLot = _open_lot(m)
	l.ship.defects.clear()
	l.ship.defects.append(ShipDefect.make("d_rust", 1, false))
	l.ship.defects.append(ShipDefect.make("d_wiring", 2, false))
	m.extra_mods.append({"op": "add", "stat": "scan_power", "value": 5.0})
	m.mark_stats_dirty()
	var cost: int = AuctionSystem.scan_cost(m, l)
	var credits0: int = m.credits
	var res: Dictionary = m.act_scan(l.id)
	ok(res, "scan")
	eq(m.credits, credits0 - cost, "coût du scan")
	eq(l.ship.hidden_defects().size(), 0, "défauts cachés révélés")
	check(l.scanned, "lot marqué scanné")


func test_scan_twice_refused() -> void:
	var m: GameModel = new_model()
	var l: AuctionLot = _open_lot(m)
	ok(m.act_scan(l.id), "premier scan")
	refused(m.act_scan(l.id), "already_scanned", "second scan")


func test_bid_too_low_refused() -> void:
	var m: GameModel = new_model()
	var l: AuctionLot = _open_lot(m)
	refused(m.act_bid(l.id, 1), "too_low", "offre trop basse")


func test_bid_requires_credits() -> void:
	var m: GameModel = new_model()
	var l: AuctionLot = _open_lot(m)
	m.credits = 10
	refused(m.act_bid(l.id, AuctionSystem.min_bid(m, l)), "credits", "fonds insuffisants")


func test_bid_requires_free_slot() -> void:
	var m: GameModel = new_model()
	for i: int in m.ship_slots():
		add_ship(m)
	var l: AuctionLot = _open_lot(m)
	refused(m.act_bid(l.id, AuctionSystem.min_bid(m, l)), "no_slot", "garage plein")


func test_proxy_win_pays_second_price_plus_fee() -> void:
	var m: GameModel = new_model()
	m.credits = 100000
	var l: AuctionLot = _open_lot(m)
	var my_max: int = l.npc_max + 5000
	ok(m.act_bid(l.id, my_max), "offre max")
	var ships0: int = m.ships.size()
	AuctionSystem.resolve(m, l)
	eq(l.result, "won", "lot gagné")
	var price: int = mini(my_max, maxi(l.start_price, l.npc_max + l.increment()))
	var fee: int = int(round(float(price) * m.stat("auction_fee")))
	eq(l.paid, price + fee, "second prix + frais")
	check(l.paid < my_max, "paie moins que son offre max")
	eq(m.ships.size(), ships0 + 1, "épave livrée au garage")
	gt(m.counter("ev_wreck_bought"), 0.0, "événement d'achat")


func test_lose_when_npc_higher() -> void:
	var m: GameModel = new_model()
	var l: AuctionLot = _open_lot(m)
	l.npc_max = 999999
	ok(m.act_bid(l.id, AuctionSystem.min_bid(m, l)), "offre")
	var ships0: int = m.ships.size()
	AuctionSystem.resolve(m, l)
	eq(l.result, "lost", "lot perdu")
	eq(m.ships.size(), ships0, "pas de vaisseau")


func test_lot_closes_at_its_hour() -> void:
	var m: GameModel = new_model()
	var l: AuctionLot = _open_lot(m)
	m.credits = 100000
	ok(m.act_bid(l.id, l.npc_max + 1000), "offre")
	var guard: int = 0
	while not l.closed and guard < 48:
		m.advance_hour()
		guard += 1
	check(l.closed, "lot clos")
	eq(m.now(), l.close_hour, "clôture à l'heure prévue")
	eq(l.result, "won", "gagné")


func test_default_when_cannot_pay() -> void:
	var m: GameModel = new_model()
	m.credits = 100000
	var l: AuctionLot = _open_lot(m)
	ok(m.act_bid(l.id, l.npc_max + 2000), "offre")
	m.credits = 0
	var rep0: float = m.reputation
	AuctionSystem.resolve(m, l)
	eq(l.result, "defaulted", "défaut de paiement")
	check(m.reputation < rep0, "réputation pénalisée")


func test_special_lot_grants_item() -> void:
	var m: GameModel = new_model()
	m.credits = 200000
	m.pending_specials.append("aurora_keel")
	AuctionSystem.spawn_pending_now(m)
	var l: AuctionLot = null
	for x: AuctionLot in m.lots:
		if x.special == "aurora_keel":
			l = x
	check(l != null, "lot spécial mis en vente")
	ok(m.act_bid(l.id, l.npc_max + 5000), "offre")
	AuctionSystem.resolve(m, l)
	check("aurora_keel" in m.items, "fragment de l'Aurore obtenu")


func test_buyer_automation_scans_and_bids() -> void:
	var m: GameModel = new_model()
	m.credits = 50000
	hire_role(m, "buyer", 3)
	goto_hour(m, 8)
	m.advance_hours(4)
	var bids: int = 0
	for l: AuctionLot in m.lots:
		if l.player_max > 0:
			bids += 1
	gt(m.counter("ev_lot_scanned"), 0.0, "l'acheteur scanne")
	gt(float(bids), 0.0, "l'acheteur enchérit")


func test_lot_estimate_narrower_after_scan() -> void:
	var m: GameModel = new_model()
	var l: AuctionLot = _open_lot(m)
	var e0: Dictionary = Valuation.lot_estimate(m, l)
	ok(m.act_scan(l.id), "scan")
	var e1: Dictionary = Valuation.lot_estimate(m, l)
	check(int(e1["high"]) - int(e1["low"]) < int(e0["high"]) - int(e0["low"]), "fourchette resserrée")
