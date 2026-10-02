class_name MarketSystem
extends RefCounted
## Clients aliens, négociation, ventes, service après-vente et contrôles du Bureau
## Galactique de la Consommation.


static func spawn_clients(m: GameModel, initial: bool) -> void:
	var rate: float = m.db.cfgf("market", "clients_per_day", 1.6) * m.stat("client_rate") * (0.6 + m.reputation / 100.0)
	var n: int = int(rate) + (1 if m.rng.randf() < rate - floorf(rate) else 0)
	if initial:
		n = maxi(n, 2)
	var regular: int = 0
	for c: Client in m.clients:
		if c.quest.is_empty():
			regular += 1
	n = mini(n, m.db.cfgi("market", "max_clients", 6) - regular)
	for i: int in n:
		m.clients.append(make_client(m))


static func make_client(m: GameModel) -> Client:
	var c: Client = Client.new()
	c.id = m.new_id()
	var sp_ids: Array[String] = []
	for k: String in m.db.species:
		sp_ids.append(k)
	c.species = Util.pick_str(m.rng, sp_ids)
	var sp: Dictionary = m.db.species[c.species]
	c.portrait = str(sp.get("portrait", ""))
	c.name = client_name(m, sp)
	var tier: int = 0
	for loc: String in m.unlocked_locations():
		tier = maxi(tier, int(m.db.locations[loc].get("client_tier", 0)))
	var budget: float = m.db.cfgf("market", "budget_base", 9000.0) * m.rng.randf_range(m.db.cfgf("market", "budget_spread_min", 0.55), m.db.cfgf("market", "budget_spread_max", 1.7))
	budget *= float(sp.get("budget", 1.0)) * m.stat("client_budget") * (1.0 + m.db.cfgf("market", "budget_per_location_tier", 0.25) * float(tier)) * (0.8 + m.reputation / 150.0)
	c.budget = Util.roundi_to(budget, 50)
	var likes: Array[String] = Util.str_array(sp.get("likes", []))
	if not likes.is_empty():
		c.likes_tags.append(Util.pick_str(m.rng, likes))
	var cls_scores: Dictionary = {}
	for h: String in m.db.parts_by_slot.get("hull", []):
		var cls: String = str(m.db.part(h).get("class", ""))
		var w: float = 1.0
		for t: Variant in m.db.part(h).get("tags", []):
			if str(t) in likes:
				w += 2.0
		cls_scores[cls] = w
	var cls1: String = Util.pick_weighted(m.rng, cls_scores)
	c.likes_classes.append(cls1)
	if m.rng.randf() < 0.5:
		var cls2: String = Util.pick_weighted(m.rng, cls_scores)
		if cls2 != cls1:
			c.likes_classes.append(cls2)
	var cols: Array[String] = Util.str_array(sp.get("colors", []))
	if not cols.is_empty():
		c.likes_colors.append(Util.pick_str(m.rng, cols))
	if m.rng.randf() < 0.3:
		var opts: Array[String] = []
		for o: String in m.db.options:
			if m.is_unlocked("option:" + o):
				for t: Variant in m.db.options[o].get("tags", []):
					if str(t) in likes and not o in opts:
						opts.append(o)
		if not opts.is_empty():
			c.likes_options.append(Util.pick_str(m.rng, opts))
	c.arrival_day = m.day
	c.leave_day = m.day + m.rng.randi_range(m.db.cfgi("market", "patience_min", 2), m.db.cfgi("market", "patience_max", 4))
	return c


static func client_name(m: GameModel, sp: Dictionary) -> String:
	var syl: Array[String] = Util.str_array(sp.get("syllables", ["zo"]))
	var a: String = Util.pick_str(m.rng, syl) + Util.pick_str(m.rng, syl)
	var b: String = Util.pick_str(m.rng, syl) + Util.pick_str(m.rng, syl) + Util.pick_str(m.rng, syl)
	return "%s %s" % [a.capitalize().replace(" ", ""), b.capitalize().replace(" ", "")]


static func spawn_order_client(m: GameModel, quest_id: String, obj: Dictionary) -> Client:
	var c: Client = Client.new()
	c.id = m.new_id()
	c.species = str(obj.get("species", "glorbian"))
	var sp: Dictionary = m.db.species.get(c.species, {})
	c.portrait = str(sp.get("portrait", ""))
	c.name = str(obj.get("client_name", client_name(m, sp)))
	c.budget = int(obj.get("budget", 8000))
	c.quest = quest_id
	c.criteria = obj.get("criteria", {})
	c.likes_classes = Util.str_array(c.criteria.get("class", []))
	c.likes_tags = Util.str_array(c.criteria.get("tags", []))
	if c.criteria.has("color"):
		c.likes_colors.append(str(c.criteria["color"]))
	c.likes_options = Util.str_array(c.criteria.get("options", []))
	c.arrival_day = m.day
	c.leave_day = 99999
	m.clients.append(c)
	return c


static func expire_clients(m: GameModel) -> void:
	var keep: Array[Client] = []
	for c: Client in m.clients:
		if not c.quest.is_empty():
			if str(m.quest_state.get(c.quest, {}).get("status", "")) == "active":
				keep.append(c)
		elif c.leave_day >= m.day or not c.busy.is_empty():
			keep.append(c)
		else:
			m.emit({"type": "client_left", "client": c.id, "species": c.species})
	m.clients = keep


static func remove_client(m: GameModel, c: Client) -> void:
	m.clients.erase(c)
	for e: Employee in m.staff:
		if int(e.job.get("client", -1)) == c.id:
			e.job = {}


static func hour_tick(_m: GameModel) -> void:
	pass


## Négociation : `ask` <= prix max → vente ; jusqu'à +10 % → contre-offre ; au-delà → refus.
static func negotiate(m: GameModel, s: Ship, c: Client, ask: int, seller_bonus: float, by: String) -> Dictionary:
	if not c.quest.is_empty() and not Valuation.matches_criteria(m, s, c.criteria):
		c.refusals += 1
		return GameModel.ok({"result": "criteria", "price": 0})
	var wtp: int = Valuation.client_wtp(m, c, s, seller_bonus)
	if ask <= wtp:
		complete_sale(m, s, c, ask, by)
		return GameModel.ok({"result": "sold", "price": ask})
	if float(ask) <= float(wtp) * (1.0 + m.db.cfgf("market", "counter_margin", 0.1)):
		return GameModel.ok({"result": "counter", "price": wtp})
	c.refusals += 1
	if c.refusals >= 3 and c.quest.is_empty():
		remove_client(m, c)
		m.emit({"type": "client_left", "client": c.id, "species": c.species})
	return GameModel.ok({"result": "refused", "price": 0})


static func complete_sale(m: GameModel, s: Ship, c: Client, price: int, by: String) -> void:
	var concealed: Array = []
	var unknown: Array = []
	for d: ShipDefect in s.defects:
		if d.state == "concealed":
			concealed.append({"type": d.type, "sev": d.sev, "done": false})
		elif d.state == "open" and not d.known:
			unknown.append({"type": d.type, "sev": d.sev, "done": false})
	var match_f: float = Valuation.client_match(m, c, s)
	var cost: int = s.purchase_price + s.invested
	m.earn(price, "sales")
	m.sold.append({"ship": s.id, "name": s.name, "hull": s.hull, "price": price, "day": m.day, "client": c.name, "species": c.species, "concealed": concealed, "unknown": unknown, "cost": cost, "base": int(s.base_value(m.db))})
	m.ships.erase(s)
	remove_client(m, c)
	m.add_reputation(m.db.cfgf("market", "rep_per_sale", 1.0) + (m.db.cfgf("market", "rep_bonus_match", 1.0) if match_f >= 1.1 else 0.0))
	m.suspicion += float(concealed.size())
	m.count("ships_sold")
	m.count("sales_value", float(price))
	m.count("ships_profit", float(price - cost))
	m.add_rp(m.db.cfgf("research", "rp_per_sale", 2.0))
	m.emit({
		"type": "ship_sold", "ship": s.id, "price": price, "client": c.id, "species": c.species,
		"class": s.ship_class(m.db), "color": s.color(m.db), "tags": s.tags(m.db), "options": s.options.duplicate(),
		"concealed": concealed.size(), "honest": concealed.is_empty(), "quest": c.quest, "profit": price - cost,
		"by": by, "tier": s.tier(m.db), "hull": s.hull,
	})


# --- Après-vente et contrôles -------------------------------------------------

static func daily_after_sales(m: GameModel) -> void:
	var warranty: int = m.db.cfgi("market", "warranty_days", 7)
	for rec: Dictionary in m.sold:
		if m.day - int(rec.get("day", 0)) > warranty:
			continue
		for kind: String in ["concealed", "unknown"]:
			for entry: Dictionary in rec.get(kind, []):
				if bool(entry.get("done", false)):
					continue
				var def: Dictionary = m.db.defects.get(str(entry["type"]), {})
				var p: float = float(def.get("sav", 0.3)) * m.stat("sav_chance") / float(warranty)
				if m.rng.randf() < p:
					entry["done"] = true
					var cost: int = int(round(float(rec.get("base", 5000)) * float(def.get("cost", 0.01)) * float(entry["sev"]) * m.db.cfgf("market", "sav_refund_mult", 1.5)))
					m.force_spend(cost, "sav")
					var rep: float = m.db.cfgf("market", "sav_rep_concealed" if kind == "concealed" else "sav_rep_unknown", 1.0) * float(entry["sev"]) * m.stat("sav_rep_mult")
					m.add_reputation(-rep)
					m.count("sav_claims")
					m.emit({"type": "sav_claim", "ship_name": str(rec.get("name", "")), "hull": str(rec.get("hull", "")), "defect": str(entry["type"]), "cost": cost, "reputation": -rep, "concealed": kind == "concealed"})
	m.suspicion *= m.db.cfgf("inspection", "suspicion_decay", 0.85)
	var p_insp: float = (m.db.cfgf("inspection", "base_chance", 0.015) + m.suspicion * m.db.cfgf("inspection", "suspicion_weight", 0.012)) * m.stat("inspection_chance")
	if m.rng.randf() < p_insp:
		inspect(m)


static func inspect(m: GameModel) -> Dictionary:
	var lookback: int = m.db.cfgi("inspection", "lookback_days", 14)
	var fines: int = 0
	var found: int = 0
	for rec: Dictionary in m.sold:
		if m.day - int(rec.get("day", 0)) > lookback:
			continue
		for entry: Dictionary in rec.get("concealed", []):
			if bool(entry.get("inspected", false)):
				continue
			entry["inspected"] = true
			found += 1
			fines += int(round(float(rec.get("price", 0)) * m.db.cfgf("inspection", "fine_frac", 0.25) * float(entry["sev"]) / 2.0))
	if found > 0:
		m.force_spend(fines, "fines")
		m.add_reputation(-m.db.cfgf("inspection", "rep_per_concealed", 3.0) * float(found))
	else:
		m.add_reputation(m.db.cfgf("inspection", "rep_clean", 1.0))
	m.count("inspections")
	var ev: Dictionary = {"type": "inspection", "found": found, "fines": fines}
	m.emit(ev)
	return ev


# --- Automatisation : Vendeur -------------------------------------------------

static func seller_bonus(m: GameModel, e: Employee) -> float:
	return e.trait_mod(m.db, "sale_bonus", 0.0) + 0.01 * float(e.level - 1)


static func min_price(m: GameModel, s: Ship) -> int:
	return int(float(s.purchase_price + s.invested) * (1.0 + float(m.settings.get("seller_min_margin", 0.05))))


static func seller_ask(m: GameModel, e: Employee, s: Ship, c: Client) -> int:
	var est: float = float(Valuation.estimate_wtp(m, c, s)) * (1.0 + seller_bonus(m, e))
	var err: float = 0.08 / (1.0 + 0.25 * float(e.level - 1))
	var noise: float = (Util.hash01(c.id, s.id, e.id.hash()) - 0.5) * 2.0 * err
	var mult: float = 1.0
	match e.rule:
		"max_price":
			mult = 1.03
		"quick_sale":
			mult = 0.95
	# Après chaque refus, le vendeur revoit son prix à la baisse.
	mult -= 0.06 * float(c.refusals)
	return int(est * (1.0 + noise) * mult)


static func seller_step(m: GameModel, e: Employee, eff: float) -> void:
	if not e.job.is_empty():
		var s: Ship = m.find_ship(int(e.job.get("ship", -1)))
		var c: Client = m.find_client(int(e.job.get("client", -1)))
		if s == null or c == null or s.is_busy():
			if c != null:
				c.busy = ""
			e.job = {}
			return
		e.job["done"] = float(e.job.get("done", 0.0)) + eff
		if float(e.job["done"]) < float(e.job.get("work", 2.0)):
			return
		c.busy = ""
		e.job = {}
		var res: Dictionary = negotiate(m, s, c, seller_ask(m, e, s, c), seller_bonus(m, e), e.id)
		if str(res.get("result", "")) == "counter" and int(res["price"]) >= min_price(m, s):
			complete_sale(m, s, c, int(res["price"]), e.id)
		return
	var best_s: Ship = null
	var best_c: Client = null
	var best_score: float = -INF
	for s: Ship in m.ships:
		if not s.for_sale or s.is_busy() or _ship_in_negotiation(m, s):
			continue
		for c: Client in m.clients:
			if not c.busy.is_empty():
				continue
			var est: int = Valuation.estimate_wtp(m, c, s)
			if est <= 0 or est < min_price(m, s):
				continue
			var score: float = float(est)
			if e.rule == "quick_sale":
				score = float(est) / maxf(1.0, s.base_value(m.db)) - float(c.leave_day - m.day) * 0.05
			if not c.quest.is_empty():
				score += 2.0e6 if e.rule == "order_first" else 1.0e6
			if score > best_score:
				best_score = score
				best_s = s
				best_c = c
	if best_s == null:
		return
	best_c.busy = e.id
	e.job = {"kind": "sell", "ship": best_s.id, "client": best_c.id, "work": m.db.cfgf("market", "negotiation_hours", 2.0), "done": 0.0}


static func _ship_in_negotiation(m: GameModel, s: Ship) -> bool:
	for e: Employee in m.staff:
		if str(e.job.get("kind", "")) == "sell" and int(e.job.get("ship", -1)) == s.id:
			return true
	return false
