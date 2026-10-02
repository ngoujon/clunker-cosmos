extends TestCase
## Ventes : clients, préférences, négociation, SAV, contrôles, vendeur automatique, commandes.


func test_clients_spawn_daily() -> void:
	var m: GameModel = new_model()
	ge(float(m.clients.size()), 2.0, "clients au départ")
	m.clients.clear()
	m.advance_hours(24)
	ge(float(m.clients.size()), 1.0, "nouveaux clients le lendemain")


func test_clients_leave_after_patience() -> void:
	var m: GameModel = new_model()
	var c: Client = add_client(m)
	c.leave_day = m.day
	m.advance_hours(48)
	check(m.find_client(c.id) == null, "client parti")


func test_wtp_capped_by_budget() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_explorer", [], 0.0)
	var c: Client = add_client(m, 1000)
	check(Valuation.client_wtp(m, c, s) <= 1000, "plafonné au budget")


func test_preferences_increase_wtp() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [], 0.2)
	var plain: Client = add_client(m, 900000)
	var fan: Client = add_client(m, 900000, ["cargo"], ["primer"])
	gt(Valuation.client_match(m, fan, s), Valuation.client_match(m, plain, s), "classe et couleur préférées")
	gt(float(Valuation.estimate_wtp(m, fan, s)), float(Valuation.estimate_wtp(m, plain, s)), "prix accepté plus élevé")


func test_sale_when_ask_below_wtp() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [], 0.2)
	s.for_sale = true
	var c: Client = add_client(m, 900000)
	var wtp: int = Valuation.client_wtp(m, c, s)
	var credits0: int = m.credits
	var res: Dictionary = m.act_sell(s.id, c.id, wtp - 10)
	eq(str(res.get("result", "")), "sold", "vendu")
	eq(m.credits, credits0 + wtp - 10, "encaissé")
	check(m.find_ship(s.id) == null and m.find_client(c.id) == null, "vaisseau et client partis")
	eq(int(m.counter("ships_sold")), 1, "compteur de ventes")


func test_counter_offer_zone() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [], 0.2)
	var c: Client = add_client(m, 900000)
	var wtp: int = Valuation.client_wtp(m, c, s)
	var res: Dictionary = m.act_sell(s.id, c.id, int(float(wtp) * 1.05))
	eq(str(res.get("result", "")), "counter", "contre-offre")
	eq(int(res["price"]), wtp, "le client propose son maximum")
	ok(m.act_accept_counter(s.id, c.id, int(res["price"])), "contre-offre acceptée")
	eq(int(m.counter("ships_sold")), 1, "vendu")


func test_refusal_then_client_leaves() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [], 0.2)
	var c: Client = add_client(m, 900000)
	for i: int in 3:
		var res: Dictionary = m.act_sell(s.id, c.id, 9999999)
		eq(str(res.get("result", "")), "refused", "refus %d" % i)
	check(m.find_client(c.id) == null, "le client part après 3 refus")


func test_reputation_rises_with_sales() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [], 0.2)
	var c: Client = add_client(m, 900000, ["cargo"])
	var rep0: float = m.reputation
	m.act_sell(s.id, c.id, 100)
	gt(m.reputation, rep0, "réputation après une vente")


func test_concealing_pays_more_than_disclosing() -> void:
	var m: GameModel = new_model()
	var a: Ship = add_ship(m, "hull_cargo", [["d_breach", 2]], 0.2)
	var b: Ship = add_ship(m, "hull_cargo", [["d_breach", 2]], 0.2)
	b.defects[0].state = "concealed"
	gt(Valuation.apparent_value(m, b), Valuation.apparent_value(m, a), "défaut caché = prix plus élevé")


func test_sav_claim_on_concealed_defect() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_breach", 2]], 0.2)
	s.defects[0].state = "concealed"
	var c: Client = add_client(m, 900000)
	m.act_sell(s.id, c.id, 100)
	m.extra_mods.append({"op": "mul", "stat": "sav_chance", "value": 1000.0})
	m.mark_stats_dirty()
	var rep0: float = m.reputation
	MarketSystem.daily_after_sales(m)
	eq(int(m.counter("sav_claims")), 1, "réclamation SAV")
	check(m.reputation < rep0, "perte de réputation")
	gt(m.counter("expense_sav"), 0.0, "remboursement payé")


func test_inspection_fines_concealed_sales() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_rust", 2]], 0.2)
	s.defects[0].state = "concealed"
	var c: Client = add_client(m, 900000)
	m.act_sell(s.id, c.id, 5000)
	var rep0: float = m.reputation
	var ev: Dictionary = MarketSystem.inspect(m)
	eq(int(ev["found"]), 1, "défaut dissimulé trouvé")
	gt(float(ev["fines"]), 0.0, "amende")
	check(m.reputation < rep0, "réputation pénalisée")
	var ev2: Dictionary = MarketSystem.inspect(m)
	eq(int(ev2["found"]), 0, "pas de double peine")


func test_inspection_clean_rewards_reputation() -> void:
	var m: GameModel = new_model()
	var rep0: float = m.reputation
	MarketSystem.inspect(m)
	gt(m.reputation, rep0, "garage exemplaire")


func test_suspicion_raises_inspection_risk() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_rust", 1], ["d_dent", 1]], 0.2)
	for d: ShipDefect in s.defects:
		d.state = "concealed"
	var c: Client = add_client(m, 900000)
	m.act_sell(s.id, c.id, 100)
	eq(m.suspicion, 2.0, "suspicion accumulée")


func test_seller_automation_sells() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [], 0.2)
	s.purchase_price = 1000
	s.for_sale = true
	add_client(m, 900000, ["cargo"])
	hire_role(m, "seller", 3)
	goto_hour(m, 8)
	m.advance_hours(6)
	check(m.find_ship(s.id) == null, "vendu par le vendeur")
	ge(m.counter("ships_sold"), 1.0, "vente comptée")


func test_order_client_requires_criteria() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [], 0.2)
	var c: Client = add_client(m, 12000)
	c.quest = "fake_order"
	c.criteria = {"class": ["yacht"]}
	var res: Dictionary = m.act_sell(s.id, c.id, 100)
	eq(str(res.get("result", "")), "criteria", "refus : mauvais vaisseau")
	c.criteria = {"class": ["cargo"]}
	eq(Valuation.estimate_wtp(m, c, s), 12000, "paie le budget de la commande")


func test_emergency_loan_when_broke_without_ships() -> void:
	var m: GameModel = new_model()
	m.ships.clear()
	for l: AuctionLot in m.lots:
		l.player_max = 0
	m.credits = -500
	var debt0: int = m.debt
	m.advance_hours(24)
	gt(float(m.credits), 1000.0, "prêt de dépannage versé")
	gt(float(m.debt), float(debt0), "prêt ajouté à la dette")
	m.credits = -500
	m.advance_hours(24)
	check(m.credits < 0, "un seul prêt par période")


func test_low_funds_hint_when_ships_remain() -> void:
	var m: GameModel = new_model()
	add_ship(m, "hull_shuttle", [], 0.3)
	m.credits = -200
	var debt0: int = m.debt
	m.advance_hours(24)
	var hinted: bool = false
	for ev: Dictionary in m.event_log:
		if str(ev.get("type", "")) == "low_funds":
			hinted = true
	check(hinted, "conseil de vente émis")
	eq(m.debt, debt0, "pas de prêt tant qu'un vaisseau peut être vendu")

