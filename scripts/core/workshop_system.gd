class_name WorkshopSystem
extends RefCounted
## Atelier : réparation ou dissimulation des défauts (patron ou mécaniciens), personnalisation
## (peinture + options, patron ou carrossiers) et mise en vente automatique.

const BASE_REVEAL: float = 0.10


## Action effective sur un défaut connu : repair | conceal | disclose.
static func policy_action(m: GameModel, d: ShipDefect) -> String:
	if d.decision != "auto":
		return d.decision
	var def: Dictionary = m.db.defects.get(d.type, {})
	var concealable: bool = bool(def.get("concealable", true))
	match str(m.settings.get("defect_policy", "honest")):
		"pragmatic":
			if bool(def.get("danger", false)) or d.sev >= 2 or not concealable:
				return "repair"
			return "conceal"
		"shark":
			return "conceal" if concealable else "repair"
	return "repair"


static func needs_work(m: GameModel, s: Ship) -> bool:
	for d: ShipDefect in s.known_open_defects():
		if policy_action(m, d) != "disclose":
			return true
	return false


static func actionable(m: GameModel, s: Ship) -> Array[ShipDefect]:
	var out: Array[ShipDefect] = []
	for d: ShipDefect in s.known_open_defects():
		if not d.is_busy() and policy_action(m, d) != "disclose":
			out.append(d)
	return out


# --- Défauts ------------------------------------------------------------------

static func start_defect(m: GameModel, worker_id: String, s: Ship, d: ShipDefect, kind: String, parts_mult: float = 1.0) -> bool:
	var cost: int = Valuation.conceal_cost(m, s, d) if kind == "conceal" else Valuation.repair_cost(m, s, d, parts_mult)
	if not m.spend(cost, "conceal" if kind == "conceal" else "repairs"):
		return false
	s.invested += cost
	d.worker = worker_id
	d.work_kind = kind
	d.progress = 0.0
	s.for_sale = false
	return true


## Applique `amount` heures de travail ; renvoie true si le travail est terminé.
static func apply_defect_work(m: GameModel, s: Ship, d: ShipDefect, amount: float, reveal_bonus: float, break_chance: float) -> bool:
	d.progress += amount
	var system: String = str(m.db.defects.get(d.type, {}).get("system", ""))
	var p_reveal: float = (BASE_REVEAL + m.stat("reveal_on_repair") + reveal_bonus) * amount
	for h: ShipDefect in s.hidden_defects():
		if str(m.db.defects.get(h.type, {}).get("system", "")) == system and m.rng.randf() < p_reveal:
			h.known = true
			m.emit({"type": "defect_found", "ship": s.id, "defect": h.type, "cause": "repair"})
	if d.progress + 0.0001 < Valuation.job_work(m, d, d.work_kind):
		return false
	finish_defect(m, s, d, break_chance)
	return true


static func finish_defect(m: GameModel, s: Ship, d: ShipDefect, break_chance: float) -> void:
	var kind: String = d.work_kind
	var by: String = d.worker
	d.state = "concealed" if kind == "conceal" else "repaired"
	d.worker = ""
	d.work_kind = ""
	d.progress = 0.0
	if kind == "conceal":
		m.count("defects_concealed")
		m.emit({"type": "defect_concealed", "ship": s.id, "defect": d.type, "sev": d.sev, "by": by})
	else:
		m.count("defects_repaired")
		s.wear = maxf(0.0, s.wear - 0.03)
		m.add_rp(m.db.cfgf("research", "rp_per_repair", 0.5))
		m.emit({"type": "defect_repaired", "ship": s.id, "defect": d.type, "sev": d.sev, "by": by})
	if break_chance > 0.0 and m.rng.randf() < break_chance:
		var nd: ShipDefect = ShipDefect.make(str(m.db.cfg("workshop", "break_defect", "d_dent")), 1, true)
		s.defects.append(nd)
		m.emit({"type": "defect_found", "ship": s.id, "defect": nd.type, "cause": "clumsy"})


static func pick_defect(m: GameModel, rule: String) -> Array:
	var best: Array = []
	var best_score: float = -INF
	for s: Ship in m.ships:
		for d: ShipDefect in actionable(m, s):
			var def: Dictionary = m.db.defects.get(d.type, {})
			var score: float = 0.0
			match rule:
				"quick_first":
					score = -Valuation.job_work(m, d, policy_action(m, d))
				"value_first":
					score = s.base_value(m.db) * float(def.get("penalty", 0.05)) * float(d.sev)
				"oldest_first":
					score = -float(s.acquired_day * 100000 + s.id)
				_:
					score = float(def.get("danger", false)) * 100.0 + float(d.sev) * 10.0 - float(s.id) * 0.001
			if score > best_score:
				best_score = score
				best = [s, d]
	return best


static func mechanic_step(m: GameModel, e: Employee, eff: float) -> void:
	var s: Ship = null
	var d: ShipDefect = null
	if not e.job.is_empty():
		s = m.find_ship(int(e.job.get("ship", -1)))
		var idx: int = int(e.job.get("defect", -1))
		if s != null and idx >= 0 and idx < s.defects.size() and s.defects[idx].worker == e.id:
			d = s.defects[idx]
		else:
			e.job = {}
	if d == null:
		var pick: Array = pick_defect(m, e.rule)
		if pick.is_empty():
			return
		s = pick[0]
		d = pick[1]
		if not start_defect(m, e.id, s, d, policy_action(m, d), e.trait_mod(m.db, "parts_cost", 1.0)):
			return
		e.job = {"kind": "defect", "ship": s.id, "defect": s.defects.find(d)}
	var done: bool = apply_defect_work(m, s, d, eff * m.stat("repair_speed"), e.trait_mod(m.db, "reveal", 0.0), e.trait_mod(m.db, "break_chance", 0.0))
	if done:
		e.job = {}


# --- Patron (travail manuel) --------------------------------------------------

static func owner_start_defect(m: GameModel, ship_id: int, idx: int, kind: String) -> Dictionary:
	if not m.owner_job.is_empty():
		return GameModel.fail("owner_busy")
	var s: Ship = m.find_ship(ship_id)
	if s == null or idx < 0 or idx >= s.defects.size():
		return GameModel.fail("no_ship")
	var d: ShipDefect = s.defects[idx]
	if not d.known or not d.is_open() or d.is_busy():
		return GameModel.fail("not_available")
	if not kind in ["repair", "conceal"]:
		return GameModel.fail("bad_kind")
	if kind == "conceal" and not bool(m.db.defects[d.type].get("concealable", true)):
		return GameModel.fail("not_concealable")
	if not start_defect(m, "owner", s, d, kind):
		return GameModel.fail("credits")
	m.owner_job = {"kind": "defect", "ship": s.id, "defect": idx}
	return GameModel.ok()


static func owner_start_custom(m: GameModel, ship_id: int, kind: String, id: String) -> Dictionary:
	if not m.owner_job.is_empty():
		return GameModel.fail("owner_busy")
	var s: Ship = m.find_ship(ship_id)
	if s == null:
		return GameModel.fail("no_ship")
	if s.is_busy():
		return GameModel.fail("busy")
	var check: String = custom_check(m, s, kind, id)
	if not check.is_empty():
		return GameModel.fail(check)
	if not start_custom(m, "owner", s, kind, id):
		return GameModel.fail("credits")
	m.owner_job = {"kind": "custom", "ship": s.id}
	return GameModel.ok()


static func owner_tick(m: GameModel) -> void:
	if m.is_owner_hour() and not m.owner_job.is_empty():
		progress_owner(m, 1.0)


static func progress_owner(m: GameModel, hours: float) -> void:
	var job: Dictionary = m.owner_job
	var s: Ship = m.find_ship(int(job.get("ship", -1)))
	if s == null:
		m.owner_job = {}
		return
	var speed: float = hours * m.stat("owner_speed")
	if str(job.get("kind", "")) == "defect":
		var idx: int = int(job.get("defect", -1))
		if idx < 0 or idx >= s.defects.size() or s.defects[idx].worker != "owner":
			m.owner_job = {}
			return
		if apply_defect_work(m, s, s.defects[idx], speed * m.stat("repair_speed"), 0.0, 0.0):
			m.owner_job = {}
	else:
		if s.custom_job.is_empty() or str(s.custom_job.get("worker", "")) != "owner":
			m.owner_job = {}
			return
		if apply_custom_work(m, s, speed * m.stat("paint_speed")):
			m.owner_job = {}


## Progression du travail du patron pour l'UI : [fait, total] ou [] si inactif.
static func owner_progress(m: GameModel) -> Array[float]:
	var s: Ship = m.find_ship(int(m.owner_job.get("ship", -1)))
	if s == null:
		return []
	if str(m.owner_job.get("kind", "")) == "defect":
		var idx: int = int(m.owner_job.get("defect", -1))
		if idx < 0 or idx >= s.defects.size():
			return []
		var d: ShipDefect = s.defects[idx]
		return [d.progress, Valuation.job_work(m, d, d.work_kind)]
	return [float(s.custom_job.get("done", 0.0)), float(s.custom_job.get("work", 1.0))]


# --- Personnalisation ---------------------------------------------------------

static func custom_check(m: GameModel, s: Ship, kind: String, id: String) -> String:
	if kind == "paint":
		if not m.db.paints.has(id):
			return "bad_id"
		if not m.is_unlocked("paint:" + id):
			return "locked"
		if s.paint == id:
			return "already"
	elif kind == "option":
		if not m.db.options.has(id):
			return "bad_id"
		if not m.is_unlocked("option:" + id):
			return "locked"
		if id in s.options:
			return "already"
	else:
		return "bad_kind"
	return ""


static func custom_work(m: GameModel, s: Ship, kind: String, id: String) -> float:
	if kind == "paint":
		return m.db.cfgf("workshop", "paint_hours", 3.0) * (0.75 + 0.25 * float(s.tier(m.db)))
	return float(m.db.options.get(id, {}).get("work", 2.0))


static func custom_cost(m: GameModel, s: Ship, kind: String, id: String) -> int:
	return Valuation.paint_cost(m, s) if kind == "paint" else Valuation.option_cost(m, id)


static func start_custom(m: GameModel, worker_id: String, s: Ship, kind: String, id: String) -> bool:
	var cost: int = custom_cost(m, s, kind, id)
	if not m.spend(cost, "custom"):
		return false
	s.invested += cost
	s.for_sale = false
	s.custom_job = {"kind": kind, "id": id, "work": custom_work(m, s, kind, id), "done": 0.0, "worker": worker_id}
	return true


static func apply_custom_work(m: GameModel, s: Ship, amount: float) -> bool:
	s.custom_job["done"] = float(s.custom_job.get("done", 0.0)) + amount
	if float(s.custom_job["done"]) + 0.0001 < float(s.custom_job.get("work", 1.0)):
		return false
	var kind: String = str(s.custom_job.get("kind", ""))
	var id: String = str(s.custom_job.get("id", ""))
	var by: String = str(s.custom_job.get("worker", ""))
	s.custom_job = {}
	if kind == "paint":
		s.paint = id
		s.wear = minf(s.wear, m.db.cfgf("workshop", "wear_after_paint", 0.15))
	else:
		if not id in s.options:
			s.options.append(id)
		if bool(m.db.options.get(id, {}).get("clears_wear", false)):
			s.wear = 0.0
	m.count("customizations")
	m.emit({"type": "customized", "ship": s.id, "kind": kind, "id": id, "by": by})
	return true


## Couleur la plus demandée (commandes en priorité) parmi les peintures débloquées.
static func target_color(m: GameModel, s: Ship) -> String:
	for c: Client in m.clients:
		if not c.quest.is_empty() and c.criteria.has("color"):
			var crit: Dictionary = c.criteria.duplicate()
			crit.erase("color")
			crit.erase("options")
			crit.erase("max_wear")
			if Valuation.matches_criteria(m, s, crit):
				return str(c.criteria["color"])
	var votes: Dictionary = {}
	for c: Client in m.clients:
		var w: float = 1.0 + (0.5 if s.ship_class(m.db) in c.likes_classes else 0.0)
		for col: String in c.likes_colors:
			votes[col] = float(votes.get(col, 0.0)) + w
	var best: String = ""
	var best_v: float = 0.0
	for col: String in votes:
		if float(votes[col]) > best_v and not paint_for_color(m, col).is_empty():
			best_v = float(votes[col])
			best = col
	return best


static func paint_for_color(m: GameModel, col: String) -> String:
	for id: String in m.db.paints:
		if str(m.db.paints[id].get("color", "")) == col and m.is_unlocked("paint:" + id):
			return id
	return ""


static func plan_customization(m: GameModel, s: Ship) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var col: String = target_color(m, s)
	var paint: String = paint_for_color(m, col) if not col.is_empty() else ""
	if paint.is_empty() and s.paint == "paint_primer":
		paint = "paint_white" if m.is_unlocked("paint:paint_white") else ""
	if not paint.is_empty() and paint != s.paint:
		plan.append({"kind": "paint", "id": paint})
	var budget: float = s.base_value(m.db) * float(m.settings.get("custom_budget", 0.06))
	var wanted: Dictionary = {}
	for c: Client in m.clients:
		for o: String in c.likes_options:
			wanted[o] = true
		if not c.quest.is_empty():
			for o2: String in Util.str_array(c.criteria.get("options", [])):
				wanted[o2] = true
	var cands: Array[String] = []
	for id: String in m.db.options:
		if m.is_unlocked("option:" + id) and not id in s.options:
			cands.append(id)
	var score: Dictionary = {}
	for id: String in cands:
		var o: Dictionary = m.db.options[id]
		score[id] = float(o.get("value", 0.0)) * s.base_value(m.db) / maxf(1.0, float(o.get("cost", 100))) + (10.0 if wanted.has(id) else 0.0)
	cands.sort_custom(func(a: String, b: String) -> bool: return float(score[a]) > float(score[b]))
	var spent: float = 0.0
	for id: String in cands:
		var cost: float = float(Valuation.option_cost(m, id))
		if (spent + cost <= budget or wanted.has(id)) and plan.size() < 3:
			plan.append({"kind": "option", "id": id})
			spent += cost
	return plan


static func bodyworker_candidates(m: GameModel, rule: String) -> Array[Ship]:
	var out: Array[Ship] = []
	for s: Ship in m.ships:
		if s.customized or needs_work(m, s):
			continue
		if not s.custom_job.is_empty() and str(s.custom_job.get("worker", "")) != "":
			continue
		out.append(s)
	var score: Dictionary = {}
	for s: Ship in out:
		var sc: float = s.base_value(m.db)
		if rule == "quick_first":
			sc = -float(s.custom_plan.size()) - float(s.id) * 0.0001
		elif rule == "order_first":
			for c: Client in m.clients:
				if not c.quest.is_empty():
					var crit: Dictionary = c.criteria.duplicate()
					for k: String in ["color", "options", "max_wear"]:
						crit.erase(k)
					if Valuation.matches_criteria(m, s, crit):
						sc += 1.0e6
		score[s.id] = sc
	out.sort_custom(func(a: Ship, b: Ship) -> bool: return float(score[a.id]) > float(score[b.id]))
	return out


static func bodyworker_step(m: GameModel, e: Employee, eff: float) -> void:
	var s: Ship = null
	if not e.job.is_empty():
		s = m.find_ship(int(e.job.get("ship", -1)))
		if s == null or s.custom_job.is_empty() or str(s.custom_job.get("worker", "")) != e.id:
			e.job = {}
			s = null
	if s == null:
		for cand: Ship in bodyworker_candidates(m, e.rule):
			if not cand.custom_job.is_empty():
				cand.custom_job["worker"] = e.id
				s = cand
				break
			if cand.custom_plan.is_empty():
				cand.custom_plan = plan_customization(m, cand)
			while not cand.custom_plan.is_empty():
				var step: Dictionary = cand.custom_plan.pop_front()
				if custom_check(m, cand, str(step["kind"]), str(step["id"])).is_empty():
					if start_custom(m, e.id, cand, str(step["kind"]), str(step["id"])):
						s = cand
					break
			if s != null:
				break
			if cand.custom_plan.is_empty() and cand.custom_job.is_empty():
				cand.customized = true
		if s == null:
			return
		e.job = {"kind": "custom", "ship": s.id}
	if apply_custom_work(m, s, eff * m.stat("paint_speed")):
		e.job = {}
		if s.custom_plan.is_empty():
			s.customized = true


static func auto_list_all(m: GameModel) -> void:
	if not bool(m.settings.get("auto_list", true)):
		return
	var has_body: bool = m.has_working("bodyworker")
	for s: Ship in m.ships:
		if s.for_sale or s.is_busy() or needs_work(m, s):
			continue
		if s.customized or not has_body:
			s.for_sale = true
