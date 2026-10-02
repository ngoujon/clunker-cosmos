class_name StaffSystem
extends RefCounted
## Ressources humaines : vivier de candidats renouvelé chaque jour, embauche/renvoi,
## affectation aux postes, efficacité, XP/niveaux, fatigue, moral, salaires et démissions.


static func salary_for(m: GameModel, role: String, level: int, traits: Array[String]) -> int:
	var base: float = float(m.db.roles.get(role, {}).get("base_salary", 70))
	var s: float = base * (1.0 + m.db.cfgf("staff", "level_salary", 0.12) * float(level - 1))
	for t: String in traits:
		s *= float(m.db.traits.get(t, {}).get("mods", {}).get("salary", 1.0))
	return maxi(10, int(round(s)))


static func make_employee(m: GameModel, role: String, level: int) -> Employee:
	var e: Employee = Employee.new()
	e.id = "e%d" % m.new_id()
	e.role = role
	e.level = level
	e.name = "%s %s" % [Util.pick_str(m.rng, m.db.staff_first_names), Util.pick_str(m.rng, m.db.staff_last_names)]
	e.portrait = Util.pick_str(m.rng, m.db.staff_portraits)
	var trait_ids: Array[String] = []
	for t: String in m.db.traits:
		trait_ids.append(t)
	Util.shuffle_with(m.rng, trait_ids)
	var nt: int = 2 if m.rng.randf() < 0.35 else 1
	for i: int in nt:
		e.traits.append(trait_ids[i])
	var spread: float = m.db.cfgf("staff", "salary_spread", 0.15)
	e.salary = maxi(10, int(round(float(salary_for(m, role, level, e.traits)) * m.rng.randf_range(1.0 - spread, 1.0 + spread))))
	var rules: Array = m.db.roles.get(role, {}).get("rules", [])
	e.rule = str(rules[0]) if not rules.is_empty() else ""
	e.morale = m.db.cfgf("staff", "morale_start", 70.0)
	return e


static func refresh_pool(m: GameModel) -> void:
	m.candidates.clear()
	var roles: Array[String] = m.db.role_ids()
	var max_lvl: int = m.db.cfgi("staff", "candidate_level_max", 3) + m.stati("hire_level")
	for i: int in maxi(1, m.stati("hire_pool")):
		var lvl: int = 1
		for j: int in max_lvl - 1:
			if m.rng.randf() < 0.45:
				lvl += 1
		m.candidates.append(make_employee(m, Util.pick_str(m.rng, roles), lvl))


static func hire_cost(m: GameModel, e: Employee) -> int:
	return int(round(float(e.salary) * m.stat("salary_mult") * float(m.db.cfgi("staff", "signing_days", 2))))


static func hire(m: GameModel, candidate_id: String) -> Dictionary:
	var e: Employee = m.find_candidate(candidate_id)
	if e == null:
		return GameModel.fail("no_candidate")
	if m.staff.size() >= m.max_staff():
		return GameModel.fail("staff_full")
	if not m.spend(hire_cost(m, e), "hire"):
		return GameModel.fail("credits")
	m.candidates.erase(e)
	e.hired_day = m.day
	m.staff.append(e)
	if bool(m.settings.get("auto_assign", true)):
		auto_assign(m)
	m.count("hired")
	m.emit({"type": "employee_hired", "employee": e.id, "role": e.role, "level": e.level})
	return GameModel.ok({"employee": e.id})


static func hire_template(m: GameModel, template_id: String) -> Employee:
	var t: Dictionary = m.db.staff_templates.get(template_id, {})
	if t.is_empty():
		return null
	var e: Employee = make_employee(m, str(t.get("role", "mechanic")), int(t.get("level", 1)))
	e.name = str(t.get("name", e.name))
	e.traits = Util.str_array(t.get("traits", []))
	e.portrait = str(t.get("portrait", e.portrait))
	e.salary = int(t.get("salary", e.salary))
	e.hired_day = m.day
	m.staff.append(e)
	auto_assign(m)
	m.emit({"type": "employee_hired", "employee": e.id, "role": e.role, "level": e.level, "template": template_id})
	return e


static func release_job(m: GameModel, e: Employee) -> void:
	var kind: String = str(e.job.get("kind", ""))
	var s: Ship = m.find_ship(int(e.job.get("ship", -1)))
	if kind == "defect" and s != null:
		var idx: int = int(e.job.get("defect", -1))
		if idx >= 0 and idx < s.defects.size() and s.defects[idx].worker == e.id:
			s.defects[idx].worker = ""
	elif kind == "custom" and s != null and str(s.custom_job.get("worker", "")) == e.id:
		s.custom_job["worker"] = ""
	elif kind == "sell":
		var c: Client = m.find_client(int(e.job.get("client", -1)))
		if c != null:
			c.busy = ""
	e.job = {}


static func fire(m: GameModel, employee_id: String) -> Dictionary:
	var e: Employee = m.find_employee(employee_id)
	if e == null:
		return GameModel.fail("no_employee")
	release_job(m, e)
	m.staff.erase(e)
	m.emit({"type": "employee_fired", "employee": e.id, "role": e.role})
	return GameModel.ok()


static func assign(m: GameModel, employee_id: String, station: String) -> Dictionary:
	var e: Employee = m.find_employee(employee_id)
	if e == null:
		return GameModel.fail("no_employee")
	if station.is_empty():
		release_job(m, e)
		e.station = ""
		return GameModel.ok()
	if not station in m.station_ids(e.role):
		return GameModel.fail("bad_station")
	var occ: Employee = m.station_occupant(station)
	if occ != null and occ != e:
		return GameModel.fail("station_taken")
	e.station = station
	return GameModel.ok()


static func auto_assign(m: GameModel) -> void:
	for e: Employee in m.staff:
		if e.is_working() and e.station in m.station_ids(e.role):
			continue
		e.station = ""
		for st: String in m.station_ids(e.role):
			if m.station_occupant(st) == null:
				e.station = st
				break


static func efficiency(m: GameModel, e: Employee) -> float:
	var lvl: float = 1.0 + m.db.cfgf("staff", "level_efficiency", 0.12) * float(e.level - 1)
	var fat_start: float = m.db.cfgf("staff", "fatigue_penalty_start", 50.0)
	var fat: float = 1.0 - maxf(0.0, e.fatigue - fat_start) / 100.0
	var mor: float = 0.8 + 0.4 * clampf(e.morale, 0.0, 100.0) / 100.0
	return lvl * e.trait_mod(m.db, "speed", 1.0) * fat * mor


static func hour_tick(m: GameModel) -> void:
	var shift: bool = m.is_shift_hour()
	for e: Employee in m.staff.duplicate():
		if shift and e.is_working():
			var eff: float = efficiency(m, e)
			match e.role:
				"buyer":
					AuctionSystem.buyer_step(m, e, eff)
				"mechanic":
					WorkshopSystem.mechanic_step(m, e, eff)
				"bodyworker":
					WorkshopSystem.bodyworker_step(m, e, eff)
				"seller":
					MarketSystem.seller_step(m, e, eff)
				"researcher":
					var crunch: float = 1.3 if e.rule == "crunch" else 1.0
					m.add_rp(m.db.cfgf("research", "rp_per_hour", 1.0) * eff * m.stat("research_speed") * e.trait_mod(m.db, "research", 1.0) * crunch)
			var fat_mult: float = 2.0 if e.rule == "crunch" else 1.0
			e.fatigue += m.db.cfgf("staff", "fatigue_per_hour", 6.0) * m.stat("fatigue_rate") * e.trait_mod(m.db, "fatigue", 1.0) * fat_mult
			e.xp += m.db.cfgf("staff", "xp_per_hour", 4.0) * m.stat("xp_gain") * e.trait_mod(m.db, "xp", 1.0)
			e.hours_worked += 1.0
			_level_up(m, e)
		else:
			e.fatigue -= m.db.cfgf("staff", "rest_per_hour", 7.0)
		e.fatigue = clampf(e.fatigue, 0.0, 100.0)


static func xp_needed(m: GameModel, e: Employee) -> float:
	return m.db.cfgf("staff", "xp_per_level", 60.0) * float(e.level)


static func _level_up(m: GameModel, e: Employee) -> void:
	var max_level: int = m.db.cfgi("staff", "max_level", 10)
	while e.level < max_level and e.xp >= xp_needed(m, e):
		e.xp -= xp_needed(m, e)
		e.level += 1
		var base: float = float(m.db.roles.get(e.role, {}).get("base_salary", 70))
		e.salary += int(round(base * m.db.cfgf("staff", "level_salary", 0.12)))
		m.emit({"type": "employee_level", "employee": e.id, "level": e.level, "role": e.role})


static func daily_payroll(m: GameModel) -> int:
	var total: int = 0
	for e: Employee in m.staff:
		total += int(round(float(e.salary) * m.stat("salary_mult")))
	return total


static func daily(m: GameModel) -> void:
	var total: int = daily_payroll(m)
	var paid: bool = m.spend(total, "salaries")
	if not paid and total > 0:
		m.emit({"type": "salaries_unpaid", "amount": total})
	for e: Employee in m.staff.duplicate():
		var delta: float = m.stat("morale_daily") + e.trait_mod(m.db, "morale_daily", 0.0)
		if e.fatigue < 40.0:
			delta += m.db.cfgf("staff", "morale_rest_bonus", 1.5)
		else:
			delta -= m.db.cfgf("staff", "morale_tired_malus", 4.0) * (e.fatigue - 40.0) / 60.0
		if not paid:
			delta -= m.db.cfgf("staff", "morale_unpaid_malus", 15.0)
		delta += (60.0 - e.morale) * 0.05
		var floor_v: float = e.trait_mod(m.db, "morale_floor", 0.0)
		e.morale = clampf(e.morale + delta, floor_v, 100.0)
		if e.morale < m.db.cfgf("staff", "morale_quit", 12.0):
			e.low_morale_days += 1
		else:
			e.low_morale_days = 0
		if e.low_morale_days >= m.db.cfgi("staff", "quit_days", 2):
			release_job(m, e)
			m.staff.erase(e)
			m.emit({"type": "employee_quit", "employee": e.id, "name": e.name, "role": e.role})
