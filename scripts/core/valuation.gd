class_name Valuation
extends RefCounted
## Toutes les formules de valeur : coûts de réparation, valeur apparente/réelle,
## correspondance client et prix maximal accepté (WTP).


static func defect_def(m: GameModel, d: ShipDefect) -> Dictionary:
	return m.db.defects.get(d.type, {})


## Facteur multiplicatif des défauts. Visibles par le client : ouverts et connus.
static func penalty_factor(m: GameModel, s: Ship, include_hidden: bool, include_concealed: bool) -> float:
	var f: float = 1.0
	for d: ShipDefect in s.defects:
		var counts: bool = false
		if d.state == "open":
			counts = d.known or include_hidden
		elif d.state == "concealed":
			counts = include_concealed
		if counts:
			f *= clampf(1.0 - float(defect_def(m, d).get("penalty", 0.05)) * float(d.sev), 0.2, 1.0)
	return f


static func option_bonus(m: GameModel, s: Ship) -> float:
	var b: float = 0.0
	for o: String in s.options:
		b += float(m.db.options.get(o, {}).get("value", 0.0))
	return b * m.stat("custom_value")


static func wear_factor(m: GameModel, s: Ship) -> float:
	return 1.0 - m.db.cfgf("market", "wear_value_loss", 0.15) * clampf(s.wear, 0.0, 1.0)


## Valeur perçue par un acheteur (défauts cachés et dissimulés invisibles).
static func apparent_value(m: GameModel, s: Ship) -> float:
	return s.base_value(m.db) * penalty_factor(m, s, false, false) * (1.0 + option_bonus(m, s)) * wear_factor(m, s)


## Valeur réelle (tous les défauts non réparés comptent).
static func true_value(m: GameModel, s: Ship) -> float:
	return s.base_value(m.db) * penalty_factor(m, s, true, true) * (1.0 + option_bonus(m, s)) * wear_factor(m, s)


static func repair_cost(m: GameModel, s: Ship, d: ShipDefect, worker_parts_mult: float = 1.0) -> int:
	var def: Dictionary = defect_def(m, d)
	return maxi(10, int(round(s.base_value(m.db) * float(def.get("cost", 0.01)) * float(d.sev) * m.stat("repair_cost") * worker_parts_mult)))


static func repair_work(m: GameModel, d: ShipDefect) -> float:
	return float(defect_def(m, d).get("work", 2.0)) * float(d.sev)


static func conceal_cost(m: GameModel, s: Ship, d: ShipDefect) -> int:
	var def: Dictionary = defect_def(m, d)
	return maxi(5, int(round(s.base_value(m.db) * float(def.get("conceal_cost", 0.004)) * float(d.sev) * m.stat("conceal_cost"))))


static func conceal_work(m: GameModel, d: ShipDefect) -> float:
	return maxf(0.5, float(defect_def(m, d).get("conceal_work", 1.0)) * float(d.sev) * 0.75)


static func job_cost(m: GameModel, s: Ship, d: ShipDefect, kind: String) -> int:
	return conceal_cost(m, s, d) if kind == "conceal" else repair_cost(m, s, d)


static func job_work(m: GameModel, d: ShipDefect, kind: String) -> float:
	return conceal_work(m, d) if kind == "conceal" else repair_work(m, d)


static func option_cost(m: GameModel, id: String) -> int:
	return int(round(float(m.db.options.get(id, {}).get("cost", 100)) * m.stat("custom_cost")))


static func paint_cost(m: GameModel, s: Ship) -> int:
	return maxi(40, int(round(s.base_value(m.db) * m.db.cfgf("workshop", "paint_cost_frac", 0.015) * m.stat("custom_cost"))))


## Coût total estimé des travaux sur les défauts connus selon la politique en vigueur.
static func repair_estimate(m: GameModel, s: Ship) -> int:
	var total: int = 0
	for d: ShipDefect in s.known_open_defects():
		var action: String = WorkshopSystem.policy_action(m, d)
		if action == "repair" or action == "conceal":
			total += job_cost(m, s, d, action)
	return total


static func rep_factor(m: GameModel) -> float:
	return 0.9 + m.reputation / 500.0


static func client_match(m: GameModel, c: Client, s: Ship) -> float:
	var mk: Dictionary = m.db.config.get("market", {})
	var f: float = float(mk.get("match_base", 0.88))
	if s.ship_class(m.db) in c.likes_classes:
		f += float(mk.get("match_class", 0.14))
	var tags: Array[String] = s.tags(m.db)
	var tag_hits: int = 0
	for t: String in c.likes_tags:
		if t in tags:
			tag_hits += 1
	f += float(mk.get("match_tag", 0.06)) * float(mini(tag_hits, 2))
	if s.color(m.db) in c.likes_colors:
		f += float(mk.get("match_color", 0.07))
	for o: String in c.likes_options:
		if o in s.options:
			f += float(mk.get("match_option", 0.05))
	return f


## Le vaisseau satisfait-il les critères d'une commande (quête secondaire) ?
static func matches_criteria(m: GameModel, s: Ship, crit: Dictionary) -> bool:
	if crit.is_empty():
		return true
	if crit.has("class") and not s.ship_class(m.db) in Util.str_array(crit["class"]):
		return false
	if crit.has("tags"):
		var tags: Array[String] = s.tags(m.db)
		for t: String in Util.str_array(crit["tags"]):
			if not t in tags:
				return false
	if crit.has("color") and s.color(m.db) != str(crit["color"]):
		return false
	if crit.has("options"):
		for o: String in Util.str_array(crit["options"]):
			if not o in s.options:
				return false
	if crit.has("max_known_open") and s.known_open_defects().size() > int(crit["max_known_open"]):
		return false
	if crit.has("max_wear") and s.wear > float(crit["max_wear"]):
		return false
	if bool(crit.get("honest", false)) and not s.concealed_defects().is_empty():
		return false
	if crit.has("min_tier") and s.tier(m.db) < int(crit["min_tier"]):
		return false
	return true


## Estimation (sans bruit) de ce que le client acceptera de payer.
static func estimate_wtp(m: GameModel, c: Client, s: Ship) -> int:
	if not c.quest.is_empty():
		if not matches_criteria(m, s, c.criteria):
			return 0
		return c.budget
	var v: float = apparent_value(m, s) * client_match(m, c, s) * rep_factor(m) * m.stat("sale_price") * (1.0 + m.stat("haggle"))
	return mini(c.budget, int(round(v)))


## Prix maximal réellement accepté (bruit déterministe propre au couple client/vaisseau).
static func client_wtp(m: GameModel, c: Client, s: Ship, seller_bonus: float = 0.0) -> int:
	if not c.quest.is_empty():
		return estimate_wtp(m, c, s)
	var noise: float = lerpf(m.db.cfgf("market", "noise_min", 0.93), m.db.cfgf("market", "noise_max", 1.07), Util.hash01(c.id, s.id, m.seed_value))
	var v: float = apparent_value(m, s) * client_match(m, c, s) * rep_factor(m) * m.stat("sale_price") * (1.0 + m.stat("haggle") + seller_bonus) * noise
	return mini(int(round(float(c.budget) * (1.0 + seller_bonus))), int(round(v)))


## Estimation affichée d'un lot : valeur après remise en état moins une décote de risque.
static func lot_estimate(m: GameModel, lot: AuctionLot) -> Dictionary:
	var s: Ship = lot.ship
	var restored: float = s.base_value(m.db) * (1.0 - m.db.cfgf("market", "wear_value_loss", 0.15) * 0.2)
	var risk: float = 0.06 if lot.scanned else 0.16
	var repairs: int = repair_estimate(m, s)
	var mid: float = restored * (1.0 - risk) - float(repairs)
	var spread: float = 0.08 if lot.scanned else 0.2
	return {"low": int(mid * (1.0 - spread)), "mid": int(mid), "high": int(mid * (1.0 + spread)), "repairs": repairs, "restored": int(restored)}
