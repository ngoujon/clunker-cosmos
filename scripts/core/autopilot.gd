class_name Autopilot
extends RefCounted
## Joueur automatique : prend les décisions « manuelles » d'un joueur raisonnable (enchères,
## réparations du patron, ventes, embauches, recherche, quêtes). Utilisé par la simulation
## de 30 jours, les tests et le bouclage scripté des chapitres. N'utilise que l'API act_*.

const HIRE_ORDER: Array[String] = ["mechanic", "seller", "buyer", "researcher", "mechanic", "bodyworker", "seller", "mechanic", "researcher", "buyer", "bodyworker", "mechanic"]
const RESEARCH_ORDER: Array[String] = [
	"at_1", "co_1", "li_1", "rh_1", "di_1", "co_2", "at_2", "at_3", "pe_1", "di_2", "rh_2", "li_2",
	"co_3", "at_4", "rh_3", "co_4", "li_3", "pe_3", "pe_2", "di_3", "at_5", "rh_4", "di_4", "co_5",
	"li_4", "pe_4", "rh_5", "li_5", "pe_5", "di_5", "co_6", "at_6", "rh_6", "li_6", "pe_6", "di_6",
	"co_7", "at_7", "rh_7", "pe_7", "di_7", "li_7",
]

var choice_index: int = 0
var accept_side_quests: bool = true
var actions: int = 0
var log: Array[String] = []


func step(m: GameModel) -> void:
	m.dialogue_queue.clear()
	_quests(m)
	_hire(m)
	_research(m)
	_garage(m)
	_owner_work(m)
	if not m.has_working("buyer"):
		_bid(m)
	if not m.has_working("seller"):
		_sell(m)
	_debt(m)


## Avance de `hours` heures en jouant à chaque heure.
func play_hours(m: GameModel, hours: int) -> void:
	for i: int in hours:
		step(m)
		m.advance_hour()


func reserve(m: GameModel) -> int:
	return 1200 + StaffSystem.daily_payroll(m) * 4 + int(m.db.config.get("upkeep_per_level", 100)) * m.garage_level * 4


# --- Quêtes ---------------------------------------------------------------------

## Objectifs non atteints des quêtes actives (principales seulement si main_only).
func _active_objectives(m: GameModel, main_only: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in QuestSystem.ids_with_status(m, "active", "main" if main_only else ""):
		var objs: Array = QuestSystem.quest(m, id).get("objectives", [])
		for i: int in objs.size():
			if not QuestSystem.objective_done(m, id, i):
				var o: Dictionary = (objs[i] as Dictionary).duplicate()
				o["_quest"] = id
				out.append(o)
	return out


func _quests(m: GameModel) -> void:
	if accept_side_quests:
		for id: String in QuestSystem.ids_with_status(m, "available", "side"):
			if bool(m.act_accept_quest(id)["ok"]):
				actions += 1
	for o: Dictionary in _active_objectives(m, false):
		if str(o.get("type", "")) == "choice":
			var q: String = str(o["_quest"])
			var n: int = (QuestSystem.quest(m, q).get("choices", []) as Array).size()
			if n > 0 and bool(m.act_choose(q, clampi(choice_index, 0, n - 1))["ok"]):
				actions += 1


func _wanted_roles(m: GameModel) -> Array[String]:
	var out: Array[String] = []
	for o: Dictionary in _active_objectives(m):
		var t: String = str(o.get("type", ""))
		if (t == "hire" or t == "staff_at_least") and o.has("role"):
			out.append(str(o["role"]))
		elif t == "hire" or t == "staff_at_least":
			out.append("")
	return out


func _wanted_nodes(m: GameModel) -> Array[String]:
	var out: Array[String] = []
	for o: Dictionary in _active_objectives(m):
		var t: String = str(o.get("type", ""))
		if t == "research_node":
			out.append_array(_path_to(m, str(o.get("id", ""))))
		elif t == "location_unlocked":
			var target: String = "location:" + str(o.get("id", ""))
			for nid: String in m.db.tech:
				for e: Variant in m.db.tech[nid].get("effects", []):
					if str((e as Dictionary).get("target", "")) == target:
						out.append_array(_path_to(m, nid))
	return out


## Nœuds à rechercher (prérequis d'abord) pour atteindre `id`.
func _path_to(m: GameModel, id: String) -> Array[String]:
	var out: Array[String] = []
	if id in m.researched or not m.db.tech.has(id):
		return out
	for p: Variant in m.db.tech[id].get("prereqs", []):
		for x: String in _path_to(m, str(p)):
			if not x in out:
				out.append(x)
	out.append(id)
	return out


# --- Personnel ------------------------------------------------------------------

func _hire(m: GameModel) -> void:
	if m.staff.size() >= m.max_staff() or m.candidates.is_empty():
		return
	var wanted: Array[String] = _wanted_roles(m)
	var need_role: String = ""
	if not wanted.is_empty():
		need_role = wanted[0]
	else:
		var counts: Dictionary = {}
		for e: Employee in m.staff:
			counts[e.role] = int(counts.get(e.role, 0)) + 1
		var seen: Dictionary = {}
		for r: String in HIRE_ORDER:
			seen[r] = int(seen.get(r, 0)) + 1
			if int(counts.get(r, 0)) < int(seen[r]):
				need_role = r
				break
	var best: Employee = null
	var best_score: float = -INF
	for c: Employee in m.candidates:
		if not need_role.is_empty() and c.role != need_role:
			continue
		var score: float = float(c.level) / float(maxi(1, c.salary)) * 100.0
		if score > best_score:
			best_score = score
			best = c
	if best == null:
		return
	var urgent: bool = not wanted.is_empty()
	var cost: int = StaffSystem.hire_cost(m, best)
	var payroll_after: int = StaffSystem.daily_payroll(m) + best.salary
	if m.credits - cost < (payroll_after * 3 if urgent else reserve(m) + payroll_after * 3):
		return
	if bool(m.act_hire(best.id)["ok"]):
		actions += 1
		log.append("J%d embauche %s (%s)" % [m.day, best.name, best.role])


# --- Recherche, garage, dette -----------------------------------------------------

func _research(m: GameModel) -> void:
	var order: Array[String] = _wanted_nodes(m)
	var urgent_n: int = order.size()
	for id: String in RESEARCH_ORDER:
		if not id in order:
			order.append(id)
	for i: int in order.size():
		var id: String = order[i]
		if not ResearchSystem.can_research(m, id).is_empty():
			continue
		var cost: int = int(m.db.tech[id].get("credits", 0))
		var floor_c: int = (300 if i < urgent_n else reserve(m)) + _pending_repairs(m)
		if m.credits - cost < floor_c:
			continue
		if bool(m.act_research(id)["ok"]):
			actions += 1
			log.append("J%d recherche %s" % [m.day, id])
			return


func _pending_repairs(m: GameModel) -> int:
	var pending: int = 0
	for s: Ship in m.ships:
		pending += Valuation.repair_estimate(m, s)
	return pending


func _garage(m: GameModel) -> void:
	var cost: int = m.garage_upgrade_cost()
	var wants_level: bool = false
	for o: Dictionary in _active_objectives(m):
		if str(o.get("type", "")) == "garage_level":
			wants_level = true
	if cost > 0 and (m.credits > cost * 2 + reserve(m) or (wants_level and m.credits > cost + reserve(m))):
		if bool(m.act_upgrade_garage()["ok"]):
			actions += 1


func _debt(m: GameModel) -> void:
	for o: Dictionary in _active_objectives(m):
		var t: String = str(o.get("type", ""))
		if t == "debt_paid_total":
			var missing: int = int(o.get("value", 0)) - m.debt_paid_total
			var pay: int = mini(missing, m.credits - reserve(m))
			if pay > 0 and bool(m.act_pay_debt(pay)["ok"]):
				actions += 1
		elif t == "debt_cleared":
			var pay2: int = mini(m.debt, m.credits - reserve(m))
			if pay2 > 0 and bool(m.act_pay_debt(pay2)["ok"]):
				actions += 1


# --- Travail manuel du patron --------------------------------------------------

func _owner_work(m: GameModel) -> void:
	if not m.owner_job.is_empty() or not m.is_owner_hour():
		return
	var best_ship: Ship = null
	var best_left: float = INF
	for s: Ship in m.ships:
		var todo: Array[ShipDefect] = WorkshopSystem.actionable(m, s)
		if todo.is_empty():
			continue
		var left: float = 0.0
		for d: ShipDefect in todo:
			left += Valuation.job_work(m, d, WorkshopSystem.policy_action(m, d))
		if left < best_left:
			best_left = left
			best_ship = s
	if best_ship != null:
		var d0: ShipDefect = WorkshopSystem.actionable(m, best_ship)[0]
		var res: Dictionary = m.act_repair(best_ship.id, best_ship.defects.find(d0), WorkshopSystem.policy_action(m, d0))
		if bool(res["ok"]):
			actions += 1
		elif str(res.get("reason", "")) == "credits":
			_unstick(m)
		return
	if m.has_working("bodyworker"):
		return
	for c: Client in m.clients:
		if c.quest.is_empty() or not c.criteria.has("color"):
			continue
		for s: Ship in m.ships:
			var crit: Dictionary = c.criteria.duplicate()
			crit.erase("color")
			crit.erase("options")
			if s.color(m.db) != str(c.criteria["color"]) and Valuation.matches_criteria(m, s, crit):
				var paint: String = WorkshopSystem.paint_for_color(m, str(c.criteria["color"]))
				if not paint.is_empty() and bool(m.act_customize(s.id, "paint", paint)["ok"]):
					actions += 1
					return


# --- Enchères (sans acheteur) ------------------------------------------------------

func _wanted_items(m: GameModel) -> Array[String]:
	var out: Array[String] = []
	for o: Dictionary in _active_objectives(m):
		if str(o.get("type", "")) == "has_item":
			out.append(str(o.get("id", "")))
	return out


## Coût total d'un lot : offre + frais + réparations estimées.
static func lot_commitment(m: GameModel, lot: AuctionLot, bid: int) -> int:
	return int(float(bid) * (1.0 + m.stat("auction_fee"))) + Valuation.repair_estimate(m, lot.ship)


## Trésorerie disponible pour enchérir : crédits moins les réparations à financer et une réserve.
static func bid_budget(m: GameModel, floor_reserve: int) -> int:
	var pending: int = 0
	for s: Ship in m.ships:
		pending += Valuation.repair_estimate(m, s)
	return m.credits - pending - floor_reserve


func _bid(m: GameModel) -> void:
	var wanted_items: Array[String] = _wanted_items(m)
	var committed: int = 0
	for l: AuctionLot in m.lots:
		if not l.closed and l.player_max > 0 and l.special.is_empty():
			committed += lot_commitment(m, l, l.player_max)
	var budget: int = bid_budget(m, 400 + StaffSystem.daily_payroll(m) * 2)
	for l2: AuctionLot in m.lots:
		if not l2.closed and l2.player_max > 0 and not l2.special.is_empty():
			budget -= lot_commitment(m, l2, l2.player_max)
	for lot: AuctionLot in AuctionSystem.buyer_candidates(m, "best_margin"):
		var is_wanted: bool = not lot.ship.item.is_empty() and lot.ship.item in wanted_items
		if m.free_slots(true) <= 0 and lot.player_max <= 0 and not is_wanted:
			continue
		if m.free_slots(false) <= 0 and is_wanted:
			_free_a_slot(m)
		var est: Dictionary = Valuation.lot_estimate(m, lot)
		if not lot.scanned and int(est["mid"]) > 2500 and m.credits > AuctionSystem.scan_cost(m, lot) * 5:
			if bool(m.act_scan(lot.id)["ok"]):
				actions += 1
		var want: int = AuctionSystem.valuation(m, lot, 0.0)
		if is_wanted:
			var cap: int = int(float(m.credits - _pending_repairs(m) - 300) / (1.0 + m.stat("auction_fee")))
			want = maxi(want, cap)
		var need: int = AuctionSystem.min_bid(m, lot)
		if want < need or lot.player_max >= want:
			continue
		if is_wanted:
			if bool(m.act_bid(lot.id, want)["ok"]):
				actions += 1
			continue
		var before: int = lot_commitment(m, lot, lot.player_max) if lot.player_max > 0 else 0
		var after: int = lot_commitment(m, lot, want)
		if not is_wanted and committed - before + after > budget:
			continue
		if bool(m.act_bid(lot.id, want)["ok"]):
			committed += after - before
			actions += 1


## Trésorerie à sec : on déclare les défauts du vaisseau le plus avancé pour le vendre en l'état.
func _unstick(m: GameModel) -> void:
	for s0: Ship in m.ships:
		if s0.for_sale:
			return
	var best: Ship = null
	for s: Ship in m.ships:
		if not s.is_busy() and (best == null or Valuation.apparent_value(m, s) > Valuation.apparent_value(m, best)):
			best = s
	if best == null:
		return
	for i: int in best.defects.size():
		var d: ShipDefect = best.defects[i]
		if d.known and d.is_open() and not d.is_busy():
			m.act_set_decision(best.id, i, "disclose")
	actions += 1
	log.append("J%d vente en l'état du vaisseau %d (trésorerie à sec)" % [m.day, best.id])


func _free_a_slot(m: GameModel) -> void:
	var worst: Ship = null
	for s: Ship in m.ships:
		if s.is_busy():
			continue
		if worst == null or s.base_value(m.db) < worst.base_value(m.db):
			worst = s
	if worst != null:
		m.act_scrap(worst.id)


# --- Ventes (sans vendeur) ------------------------------------------------------------

func _sell(m: GameModel) -> void:
	for s: Ship in m.ships.duplicate():
		if not s.for_sale or s.is_busy():
			continue
		var age: int = m.day - s.acquired_day
		var floor_price: int = MarketSystem.min_price(m, s) if age < 8 else s.purchase_price
		var best: Client = null
		var best_est: int = 0
		for c: Client in m.clients:
			if not c.busy.is_empty():
				continue
			var est: int = Valuation.estimate_wtp(m, c, s)
			if est > best_est:
				best_est = est
				best = c
		if best == null or best_est < floor_price:
			continue
		var res: Dictionary = m.act_sell(s.id, best.id, int(float(best_est) * 0.99))
		actions += 1
		if str(res.get("result", "")) == "counter" and int(res["price"]) >= floor_price:
			m.act_accept_counter(s.id, best.id, int(res["price"]))
