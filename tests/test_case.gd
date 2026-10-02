class_name TestCase
extends RefCounted
## Base des suites de tests headless. Les méthodes `test_*` sont découvertes par tests/runner.gd.
## Les assertions enregistrent les échecs sans interrompre le test.

static var _shared_db: ContentDB = null

var failures: Array[String] = []
var db: ContentDB


func _init() -> void:
	if _shared_db == null:
		_shared_db = ContentDB.load_default()
	db = _shared_db


func before_each() -> void:
	pass


func new_model(seed_value: int = 42, story: bool = false) -> GameModel:
	return GameModel.create(db, seed_value, story)


func check(cond: bool, msg: String = "condition fausse") -> void:
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (typeof(actual) in [TYPE_INT, TYPE_FLOAT] and typeof(expected) in [TYPE_INT, TYPE_FLOAT]):
		failures.append("%s : types différents (%s vs %s)" % [msg, str(actual), str(expected)])
	elif actual != expected:
		failures.append("%s : attendu %s, obtenu %s" % [msg, str(expected), str(actual)])


func near(actual: float, expected: float, tol: float, msg: String = "") -> void:
	if absf(actual - expected) > tol:
		failures.append("%s : attendu %.4f ±%.4f, obtenu %.4f" % [msg, expected, tol, actual])


func gt(a: float, b: float, msg: String = "") -> void:
	if not a > b:
		failures.append("%s : %.4f n'est pas > %.4f" % [msg, a, b])


func ge(a: float, b: float, msg: String = "") -> void:
	if not a >= b:
		failures.append("%s : %.4f n'est pas >= %.4f" % [msg, a, b])


func ok(res: Dictionary, msg: String = "") -> void:
	if not bool(res.get("ok", false)):
		failures.append("%s : action refusée (%s)" % [msg, str(res.get("reason", "?"))])


func refused(res: Dictionary, reason: String, msg: String = "") -> void:
	if bool(res.get("ok", false)):
		failures.append("%s : action acceptée alors qu'elle devait être refusée" % msg)
	elif not reason.is_empty() and str(res.get("reason", "")) != reason:
		failures.append("%s : raison attendue %s, obtenue %s" % [msg, reason, str(res.get("reason", ""))])


# --- Fabriques utiles ------------------------------------------------------------

## Vaisseau contrôlé ajouté au garage.
func add_ship(m: GameModel, hull: String = "hull_cargo", defects: Array = [], wear: float = 0.5) -> Ship:
	var s: Ship = Ship.new()
	s.id = m.new_id()
	s.hull = hull
	s.engine = "eng_ion"
	s.cockpit = "cock_box"
	s.wings = "wing_stub"
	s.name = "TEST-1"
	s.wear = wear
	s.acquired_day = m.day
	for d: Variant in defects:
		var arr: Array = d
		s.defects.append(ShipDefect.make(str(arr[0]), int(arr[1]), bool(arr[2]) if arr.size() > 2 else true))
	m.ships.append(s)
	return s


## Client contrôlé.
func add_client(m: GameModel, budget: int = 50000, classes: Array[String] = [], colors: Array[String] = []) -> Client:
	var c: Client = Client.new()
	c.id = m.new_id()
	c.species = "glorbian"
	c.name = "Test Client"
	c.budget = budget
	c.likes_classes = classes
	c.likes_colors = colors
	c.arrival_day = m.day
	c.leave_day = m.day + 5
	m.clients.append(c)
	return c


func hire_role(m: GameModel, role: String, level: int = 1) -> Employee:
	var e: Employee = StaffSystem.make_employee(m, role, level)
	e.traits.clear()
	m.staff.append(e)
	StaffSystem.auto_assign(m)
	return e


## Place le modèle juste avant le début de la journée de travail.
func goto_hour(m: GameModel, h: int) -> void:
	var guard: int = 0
	while m.hour != h and guard < 48:
		m.advance_hour()
		guard += 1
