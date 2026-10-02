class_name GameModel
extends RefCounted
## État complet d'une partie et boucle horaire. Aucune dépendance aux nœuds :
## toute la logique est testable en headless. L'UI lit l'état et appelle les méthodes act_*.

signal game_event(ev: Dictionary)

const POLICIES: PackedStringArray = ["honest", "pragmatic", "shark"]
const EVENT_LOG_CAP: int = 250
const REPORTS_CAP: int = 30
const SOLD_KEEP_DAYS: int = 21

var db: ContentDB
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 0
var story_mode: bool = true

# Temps
var day: int = 1
var hour: int = 8
var owner_online: bool = true

# Ressources
var credits: int = 0
var research_points: float = 0.0
var reputation: float = 30.0
var debt: int = 0
var debt_paid_total: int = 0
var late_payments: int = 0
var garage_level: int = 1
var suspicion: float = 0.0

# Entités
var next_id: int = 1
var ships: Array[Ship] = []
var lots: Array[AuctionLot] = []
var clients: Array[Client] = []
var staff: Array[Employee] = []
var candidates: Array[Employee] = []
var sold: Array[Dictionary] = []
var researched: Array[String] = []
var unlocked: Dictionary = {}
var items: Array[String] = []
var flags: Dictionary = {}
var extra_mods: Array[Dictionary] = []
var pending_specials: Array[String] = []

# Joueur
var owner_job: Dictionary = {}
var owner_boosts: int = 0
var settings: Dictionary = {
	"defect_policy": "honest",
	"custom_budget": 0.06,
	"auto_list": true,
	"buyer_budget": 0.6,
	"seller_min_margin": 0.05,
	"auto_assign": true,
}

# Quêtes et histoire
var quest_state: Dictionary = {}
var dialogue_queue: Array[Dictionary] = []
var journal: Array[Dictionary] = []
var chapter: int = 0
var ending: String = ""

# Statistiques, rapports, contrôle d'intégrité
var counters: Dictionary = {}
var day_report: Dictionary = {}
var reports: Array[Dictionary] = []
var event_log: Array[Dictionary] = []
var errors: Array[String] = []

var _stats_cache: Dictionary = {}
var _stats_dirty: bool = true


# ---------------------------------------------------------------------------
# Création

static func create(p_db: ContentDB, p_seed: int, p_story: bool) -> GameModel:
	var m: GameModel = GameModel.new()
	m.db = p_db
	m.seed_value = p_seed
	m.rng.seed = p_seed
	m.story_mode = p_story
	var start: Dictionary = p_db.config.get("start", {})
	m.credits = int(start.get("credits", 5000))
	m.reputation = float(start.get("reputation", 30))
	m.debt = int(start.get("debt", 60000))
	m.research_points = float(start.get("research_points", 0))
	m.garage_level = int(start.get("garage_level", 1))
	m.day = int(start.get("day", 1))
	m.hour = int(start.get("hour", 8))
	m._init_unlocks()
	m._open_day_report()
	QuestSystem.init(m)
	AuctionSystem.generate_day(m)
	MarketSystem.spawn_clients(m, true)
	StaffSystem.refresh_pool(m)
	QuestSystem.update(m)
	return m


func _init_unlocks() -> void:
	for id: String in db.locations:
		if bool(db.locations[id].get("unlocked", false)):
			unlocked["location:" + id] = true
	for id: String in db.paints:
		if bool(db.paints[id].get("unlocked", false)):
			unlocked["paint:" + id] = true
	for id: String in db.options:
		if bool(db.options[id].get("unlocked", false)):
			unlocked["option:" + id] = true


# ---------------------------------------------------------------------------
# Temps

func now() -> int:
	return day * 24 + hour


func is_shift_hour(h: int = -1) -> bool:
	var hh: int = hour if h < 0 else h
	return hh >= db.cfgi("time", "shift_start", 8) and hh < db.cfgi("time", "shift_end", 18)


func is_owner_hour() -> bool:
	return owner_online and hour >= db.cfgi("time", "owner_start", 8) and hour < db.cfgi("time", "owner_end", 20)


func advance_hours(n: int) -> void:
	for i: int in n:
		advance_hour()


## Une heure de jeu : travail de l'heure courante, puis passage à l'heure suivante.
func advance_hour() -> void:
	StaffSystem.hour_tick(self)
	WorkshopSystem.owner_tick(self)
	WorkshopSystem.auto_list_all(self)
	owner_boosts = 0
	hour += 1
	if hour >= 24:
		hour = 0
		day += 1
		_new_day()
	AuctionSystem.hour_tick(self)
	MarketSystem.hour_tick(self)
	QuestSystem.update(self)
	_check_invariants()


func _new_day() -> void:
	_close_day_report()
	StaffSystem.daily(self)
	force_spend(int(db.config.get("upkeep_per_level", 100)) * garage_level, "upkeep")
	_debt_due()
	MarketSystem.daily_after_sales(self)
	MarketSystem.expire_clients(self)
	MarketSystem.spawn_clients(self, false)
	AuctionSystem.generate_day(self)
	StaffSystem.refresh_pool(self)
	_trim_sold()
	emit({"type": "day_started", "day": day})


func _debt_due() -> void:
	var period: int = maxi(1, db.cfgi("debt", "period_days", 7))
	if debt <= 0 or (day - 1) % period != 0 or day <= 1:
		return
	var amount: int = mini(db.cfgi("debt", "installment", 2500), debt)
	if credits >= amount:
		spend(amount, "debt")
		debt -= amount
		debt_paid_total += amount
		late_payments = 0
		emit({"type": "debt_paid", "amount": amount, "auto": true})
	else:
		var penalty: int = int(round(float(amount) * db.cfgf("debt", "late_penalty", 0.1)))
		debt += penalty
		late_payments += 1
		add_reputation(-db.cfgf("debt", "late_reputation", 3.0))
		emit({"type": "debt_late", "amount": amount, "penalty": penalty})


func _trim_sold() -> void:
	var keep: Array[Dictionary] = []
	for s: Dictionary in sold:
		if day - int(s.get("day", 0)) <= SOLD_KEEP_DAYS:
			keep.append(s)
	sold = keep


# ---------------------------------------------------------------------------
# Statistiques à modificateurs (arbre techno + récompenses)

func stat(name: String) -> float:
	if _stats_dirty:
		_rebuild_stats()
	return float(_stats_cache.get(name, 0.0))


func stati(name: String) -> int:
	return int(floor(stat(name) + 0.0001))


func mark_stats_dirty() -> void:
	_stats_dirty = true


func _rebuild_stats() -> void:
	var add: Dictionary = {}
	var mul: Dictionary = {}
	var effects: Array[Dictionary] = []
	for id: String in researched:
		for e: Variant in db.tech.get(id, {}).get("effects", []):
			effects.append(e as Dictionary)
	for e: Dictionary in extra_mods:
		effects.append(e)
	for e: Dictionary in effects:
		var op: String = str(e.get("op", ""))
		var st: String = str(e.get("stat", ""))
		if op == "add":
			add[st] = float(add.get(st, 0.0)) + float(e.get("value", 0.0))
		elif op == "mul":
			mul[st] = float(mul.get(st, 1.0)) * float(e.get("value", 1.0))
	_stats_cache = {}
	for st: String in db.stats:
		_stats_cache[st] = (float(db.stats[st]) + float(add.get(st, 0.0))) * float(mul.get(st, 1.0))
	_stats_dirty = false


func is_unlocked(target: String) -> bool:
	return bool(unlocked.get(target, false))


func unlock(target: String) -> void:
	if is_unlocked(target):
		return
	unlocked[target] = true
	if target.begins_with("location:"):
		emit({"type": "location_unlocked", "location": target.substr(9)})
	else:
		emit({"type": "unlocked", "target": target})


func unlocked_locations() -> Array[String]:
	var out: Array[String] = []
	for id: String in db.location_order:
		if is_unlocked("location:" + id):
			out.append(id)
	return out


# ---------------------------------------------------------------------------
# Capacités du garage

func level_data() -> Dictionary:
	return db.garage_level_data(garage_level)


func ship_slots() -> int:
	return int(level_data().get("slots", 3)) + stati("ship_slots")


func max_staff() -> int:
	return int(level_data().get("max_staff", 3)) + stati("max_staff")


func station_count(role: String) -> int:
	var st: Dictionary = level_data().get("stations", {})
	return int(st.get(role, 0)) + stati("station_" + role)


func station_ids(role: String) -> Array[String]:
	var out: Array[String] = []
	for i: int in station_count(role):
		out.append("%s_%d" % [role, i])
	return out


func station_occupant(station: String) -> Employee:
	for e: Employee in staff:
		if e.station == station:
			return e
	return null


## Emplacements libres en tenant compte des lots où le joueur mène déjà.
func free_slots(include_leading: bool = true) -> int:
	var used: int = ships.size()
	if include_leading:
		for l: AuctionLot in lots:
			if not l.closed and l.player_max > 0:
				used += 1
	return ship_slots() - used


func garage_upgrade_cost() -> int:
	if garage_level >= db.max_garage_level():
		return -1
	return int(db.garage_level_data(garage_level + 1).get("cost", 0))


# ---------------------------------------------------------------------------
# Finances et compteurs

func earn(amount: int, category: String) -> void:
	if amount <= 0:
		return
	credits += amount
	count("income_" + category, amount)
	count("income_total", amount)
	var inc: Dictionary = day_report.get("income", {})
	inc[category] = int(inc.get(category, 0)) + amount
	day_report["income"] = inc


## Dépense si les fonds suffisent ; renvoie false sinon.
func spend(amount: int, category: String) -> bool:
	if amount <= 0:
		return true
	if credits < amount:
		return false
	force_spend(amount, category)
	return true


## Dépense obligatoire (peut rendre le solde négatif).
func force_spend(amount: int, category: String) -> void:
	if amount <= 0:
		return
	credits -= amount
	count("expense_" + category, amount)
	count("expense_total", amount)
	var exp: Dictionary = day_report.get("expense", {})
	exp[category] = int(exp.get(category, 0)) + amount
	day_report["expense"] = exp


func count(key: String, n: float = 1.0) -> void:
	counters[key] = float(counters.get(key, 0.0)) + n


func counter(key: String) -> float:
	return float(counters.get(key, 0.0))


## Résultat d'exploitation : ventes + primes de quêtes - coûts d'exploitation (hors dette et investissements).
func operating_profit() -> float:
	var income: float = counter("income_sales") + counter("income_quest") + counter("income_scrap")
	var costs: float = 0.0
	for cat: String in ["purchases", "fees", "scans", "repairs", "conceal", "custom", "salaries", "upkeep", "fines", "sav", "hire"]:
		costs += counter("expense_" + cat)
	return income - costs


func add_reputation(delta: float) -> void:
	var d: float = delta
	if d > 0.0:
		d *= stat("reputation_gain")
	reputation = clampf(reputation + d, 0.0, 100.0)


func add_rp(amount: float) -> void:
	research_points += amount
	count("rp_gained", amount)


func new_id() -> int:
	next_id += 1
	return next_id


# ---------------------------------------------------------------------------
# Événements et rapports

func emit(ev: Dictionary) -> void:
	ev["day"] = day
	ev["hour"] = hour
	event_log.append(ev)
	if event_log.size() > EVENT_LOG_CAP:
		event_log = event_log.slice(event_log.size() - EVENT_LOG_CAP)
	var evs: Array = day_report.get("events", [])
	evs.append(ev)
	day_report["events"] = evs
	count("ev_" + str(ev.get("type", "")))
	QuestSystem.on_event(self, ev)
	game_event.emit(ev)


func _open_day_report() -> void:
	day_report = {"day": day, "income": {}, "expense": {}, "events": [], "credits_start": credits}


func _close_day_report() -> void:
	day_report["credits_end"] = credits
	reports.append(day_report)
	if reports.size() > REPORTS_CAP:
		reports = reports.slice(reports.size() - REPORTS_CAP)
	_open_day_report()


func last_report() -> Dictionary:
	return reports[reports.size() - 1] if not reports.is_empty() else {}


func _check_invariants() -> void:
	if is_nan(research_points) or is_nan(reputation):
		errors.append("NaN détecté (jour %d)" % day)
	if ships.size() > ship_slots() + 3:
		errors.append("trop de vaisseaux : %d (jour %d)" % [ships.size(), day])
	if staff.size() > max_staff() + 3:
		errors.append("trop d'employés : %d (jour %d)" % [staff.size(), day])
	for s: Ship in ships:
		for d: ShipDefect in s.defects:
			if d.sev < 1 or d.sev > 3 or not db.defects.has(d.type):
				errors.append("défaut invalide sur le vaisseau %d" % s.id)


# ---------------------------------------------------------------------------
# Recherche d'entités

func find_ship(id: int) -> Ship:
	for s: Ship in ships:
		if s.id == id:
			return s
	return null


func find_lot(id: int) -> AuctionLot:
	for l: AuctionLot in lots:
		if l.id == id:
			return l
	return null


func find_client(id: int) -> Client:
	for c: Client in clients:
		if c.id == id:
			return c
	return null


func find_employee(id: String) -> Employee:
	for e: Employee in staff:
		if e.id == id:
			return e
	return null


func find_candidate(id: String) -> Employee:
	for e: Employee in candidates:
		if e.id == id:
			return e
	return null


func staff_by_role(role: String) -> Array[Employee]:
	var out: Array[Employee] = []
	for e: Employee in staff:
		if e.role == role:
			out.append(e)
	return out


func has_working(role: String) -> bool:
	for e: Employee in staff:
		if e.role == role and e.is_working():
			return true
	return false


# ---------------------------------------------------------------------------
# Actions du joueur (UI, autopilote). Renvoient {"ok": bool, "reason": String, ...}.

static func ok(extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"ok": true, "reason": ""}
	d.merge(extra)
	return d


static func fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func act_bid(lot_id: int, amount: int) -> Dictionary:
	var lot: AuctionLot = find_lot(lot_id)
	if lot == null or lot.closed:
		return fail("lot_closed")
	return AuctionSystem.place_bid(self, lot, amount)


func act_scan(lot_id: int) -> Dictionary:
	var lot: AuctionLot = find_lot(lot_id)
	if lot == null or lot.closed:
		return fail("lot_closed")
	return AuctionSystem.scan(self, lot, "owner")


func act_repair(ship_id: int, defect_index: int, kind: String = "repair") -> Dictionary:
	return WorkshopSystem.owner_start_defect(self, ship_id, defect_index, kind)


func act_set_decision(ship_id: int, defect_index: int, decision: String) -> Dictionary:
	var s: Ship = find_ship(ship_id)
	if s == null or defect_index < 0 or defect_index >= s.defects.size():
		return fail("no_ship")
	if not decision in ["auto", "repair", "conceal", "disclose"]:
		return fail("bad_decision")
	var d: ShipDefect = s.defects[defect_index]
	if decision == "conceal" and not bool(db.defects[d.type].get("concealable", true)):
		return fail("not_concealable")
	d.decision = decision
	return ok()


func act_customize(ship_id: int, kind: String, id: String) -> Dictionary:
	return WorkshopSystem.owner_start_custom(self, ship_id, kind, id)


## Coup de main manuel : fait avancer le travail du patron.
func act_boost() -> Dictionary:
	if owner_job.is_empty():
		return fail("no_job")
	if owner_boosts >= db.cfgi("time", "owner_boosts_per_hour", 6):
		return fail("tired")
	owner_boosts += 1
	WorkshopSystem.progress_owner(self, db.cfgf("time", "owner_boost_hours", 0.5))
	return ok()


func act_list(ship_id: int, on: bool) -> Dictionary:
	var s: Ship = find_ship(ship_id)
	if s == null:
		return fail("no_ship")
	s.for_sale = on
	return ok()


func act_sell(ship_id: int, client_id: int, ask: int) -> Dictionary:
	var s: Ship = find_ship(ship_id)
	var c: Client = find_client(client_id)
	if s == null or c == null:
		return fail("no_target")
	if s.is_busy():
		return fail("busy")
	if not c.busy.is_empty():
		return fail("client_busy")
	return MarketSystem.negotiate(self, s, c, ask, 0.0, "owner")


## Accepte une contre-offre (prix proposé par le client).
func act_accept_counter(ship_id: int, client_id: int, price: int) -> Dictionary:
	var s: Ship = find_ship(ship_id)
	var c: Client = find_client(client_id)
	if s == null or c == null:
		return fail("no_target")
	MarketSystem.complete_sale(self, s, c, price, "owner")
	return ok({"price": price})


func act_scrap(ship_id: int) -> Dictionary:
	var s: Ship = find_ship(ship_id)
	if s == null:
		return fail("no_ship")
	if s.is_busy():
		return fail("busy")
	var value: int = int(round(s.base_value(db) * 0.2))
	earn(value, "scrap")
	ships.erase(s)
	emit({"type": "ship_scrapped", "ship": s.id, "price": value})
	return ok({"price": value})


func act_hire(candidate_id: String) -> Dictionary:
	return StaffSystem.hire(self, candidate_id)


func act_fire(employee_id: String) -> Dictionary:
	return StaffSystem.fire(self, employee_id)


func act_assign(employee_id: String, station: String) -> Dictionary:
	return StaffSystem.assign(self, employee_id, station)


func act_set_rule(employee_id: String, rule: String) -> Dictionary:
	var e: Employee = find_employee(employee_id)
	if e == null:
		return fail("no_employee")
	var allowed: Array = db.roles.get(e.role, {}).get("rules", [])
	if not rule in allowed:
		return fail("bad_rule")
	e.rule = rule
	return ok()


func act_research(node_id: String) -> Dictionary:
	return ResearchSystem.research(self, node_id)


func act_upgrade_garage() -> Dictionary:
	var cost: int = garage_upgrade_cost()
	if cost < 0:
		return fail("max_level")
	if not spend(cost, "garage"):
		return fail("credits")
	garage_level += 1
	if bool(settings.get("auto_assign", true)):
		StaffSystem.auto_assign(self)
	emit({"type": "garage_upgraded", "level": garage_level})
	return ok()


func act_pay_debt(amount: int) -> Dictionary:
	var a: int = mini(amount, debt)
	if a <= 0:
		return fail("no_debt")
	if not spend(a, "debt"):
		return fail("credits")
	debt -= a
	debt_paid_total += a
	emit({"type": "debt_paid", "amount": a, "auto": false})
	if debt <= 0:
		emit({"type": "debt_cleared"})
	return ok()


func act_accept_quest(quest_id: String) -> Dictionary:
	return QuestSystem.accept(self, quest_id)


func act_choose(quest_id: String, choice_index: int) -> Dictionary:
	return QuestSystem.choose(self, quest_id, choice_index)


func act_set_setting(key: String, value: Variant) -> Dictionary:
	if not settings.has(key):
		return fail("bad_setting")
	if key == "defect_policy" and not str(value) in POLICIES:
		return fail("bad_policy")
	settings[key] = value
	return ok()


func pop_dialogue() -> Dictionary:
	if dialogue_queue.is_empty():
		return {}
	return dialogue_queue.pop_front()
