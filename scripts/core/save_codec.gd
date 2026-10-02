class_name SaveCodec
extends RefCounted
## Sauvegarde versionnée (JSON). `save_version` est incrémenté à chaque changement de format ;
## `migrate()` convertit les anciennes sauvegardes étape par étape.
##   v1 : prototype (champs "money", "rep", défauts avec "hidden").
##   v2 : format actuel.

const VERSION: int = 2


static func to_dict(m: GameModel) -> Dictionary:
	var ships: Array = []
	for s: Ship in m.ships:
		ships.append(s.to_dict())
	var lots: Array = []
	for l: AuctionLot in m.lots:
		lots.append(l.to_dict())
	var clients: Array = []
	for c: Client in m.clients:
		clients.append(c.to_dict())
	var staff: Array = []
	for e: Employee in m.staff:
		staff.append(e.to_dict())
	var cands: Array = []
	for e: Employee in m.candidates:
		cands.append(e.to_dict())
	return {
		"save_version": VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"saved_at": int(Time.get_unix_time_from_system()),
		"model": {
			"seed": m.seed_value, "rng_state": str(m.rng.state), "story_mode": m.story_mode,
			"day": m.day, "hour": m.hour,
			"credits": m.credits, "research_points": m.research_points, "reputation": m.reputation,
			"debt": m.debt, "debt_paid_total": m.debt_paid_total, "late_payments": m.late_payments, "last_rescue_day": m.last_rescue_day,
			"garage_level": m.garage_level, "suspicion": m.suspicion, "next_id": m.next_id,
			"ships": ships, "lots": lots, "clients": clients, "staff": staff, "candidates": cands,
			"sold": m.sold.duplicate(true), "researched": m.researched.duplicate(),
			"unlocked": m.unlocked.duplicate(), "items": m.items.duplicate(), "flags": m.flags.duplicate(),
			"extra_mods": m.extra_mods.duplicate(true), "pending_specials": m.pending_specials.duplicate(),
			"owner_job": m.owner_job.duplicate(true), "settings": m.settings.duplicate(),
			"quest_state": m.quest_state.duplicate(true), "dialogue_queue": m.dialogue_queue.duplicate(true),
			"journal": m.journal.duplicate(true), "chapter": m.chapter, "ending": m.ending,
			"counters": m.counters.duplicate(), "day_report": m.day_report.duplicate(true),
			"reports": m.reports.duplicate(true),
		},
	}


static func migrate(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var v: int = int(d.get("save_version", 1))
	while v < VERSION:
		match v:
			1:
				d = _v1_to_v2(d)
		v += 1
		d["save_version"] = v
	return d


static func _v1_to_v2(d: Dictionary) -> Dictionary:
	var mdl: Dictionary = d.get("model", {})
	if mdl.has("money"):
		mdl["credits"] = mdl["money"]
		mdl.erase("money")
	if mdl.has("rep"):
		mdl["reputation"] = mdl["rep"]
		mdl.erase("rep")
	for s: Variant in mdl.get("ships", []):
		for df: Variant in (s as Dictionary).get("defects", []):
			var dd: Dictionary = df
			if dd.has("hidden"):
				dd["known"] = not bool(dd["hidden"])
				dd.erase("hidden")
	if not mdl.has("settings"):
		mdl["settings"] = {}
	d["model"] = mdl
	return d


static func from_dict(db: ContentDB, data: Dictionary) -> GameModel:
	var d: Dictionary = migrate(data)
	var s: Dictionary = d.get("model", {})
	var m: GameModel = GameModel.new()
	m.db = db
	m.seed_value = int(s.get("seed", 0))
	m.rng.seed = m.seed_value
	if s.has("rng_state"):
		m.rng.state = int(str(s["rng_state"]))
	m.story_mode = bool(s.get("story_mode", true))
	m.day = int(s.get("day", 1))
	m.hour = int(s.get("hour", 8))
	m.credits = int(s.get("credits", 0))
	m.research_points = float(s.get("research_points", 0.0))
	m.reputation = float(s.get("reputation", 30.0))
	m.debt = int(s.get("debt", 0))
	m.debt_paid_total = int(s.get("debt_paid_total", 0))
	m.late_payments = int(s.get("late_payments", 0))
	m.last_rescue_day = int(s.get("last_rescue_day", 0))
	m.garage_level = int(s.get("garage_level", 1))
	m.suspicion = float(s.get("suspicion", 0.0))
	m.next_id = int(s.get("next_id", 1))
	for x: Variant in s.get("ships", []):
		m.ships.append(Ship.from_dict(x))
	for x: Variant in s.get("lots", []):
		m.lots.append(AuctionLot.from_dict(x))
	for x: Variant in s.get("clients", []):
		m.clients.append(Client.from_dict(x))
	for x: Variant in s.get("staff", []):
		m.staff.append(Employee.from_dict(x))
	for x: Variant in s.get("candidates", []):
		m.candidates.append(Employee.from_dict(x))
	for x: Variant in s.get("sold", []):
		m.sold.append(x as Dictionary)
	m.researched = Util.str_array(s.get("researched", []))
	m.unlocked = s.get("unlocked", {})
	if m.unlocked.is_empty():
		m._init_unlocks()
	m.items = Util.str_array(s.get("items", []))
	m.flags = s.get("flags", {})
	for x: Variant in s.get("extra_mods", []):
		m.extra_mods.append(x as Dictionary)
	m.pending_specials = Util.str_array(s.get("pending_specials", []))
	m.owner_job = s.get("owner_job", {})
	var settings: Dictionary = s.get("settings", {})
	for k: String in settings:
		m.settings[k] = settings[k]
	m.quest_state = s.get("quest_state", {})
	for x: Variant in s.get("dialogue_queue", []):
		m.dialogue_queue.append(x as Dictionary)
	for x: Variant in s.get("journal", []):
		m.journal.append(x as Dictionary)
	m.chapter = int(s.get("chapter", 0))
	m.ending = str(s.get("ending", ""))
	m.counters = s.get("counters", {})
	m.day_report = s.get("day_report", {})
	if m.day_report.is_empty():
		m._open_day_report()
	for x: Variant in s.get("reports", []):
		m.reports.append(x as Dictionary)
	QuestSystem.init(m)
	m.mark_stats_dirty()
	return m


static func save_file(m: GameModel, path: String) -> Error:
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(m), "\t"))
	f.close()
	return OK


static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func load_file(db: ContentDB, path: String) -> GameModel:
	var d: Dictionary = read_file(path)
	if d.is_empty():
		return null
	return from_dict(db, d)
