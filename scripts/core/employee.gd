class_name Employee
extends RefCounted
## Employé (ou candidat) du garage.

var id: String = ""
var name: String = ""
var role: String = ""
var level: int = 1
var xp: float = 0.0
var traits: Array[String] = []
var salary: int = 50
var morale: float = 70.0
var fatigue: float = 0.0
var portrait: String = ""
## Poste occupé : "<role>_<index>" ou "" (en pause / non affecté).
var station: String = ""
var rule: String = ""
## Travail en cours : {"kind", "ship", "defect", "lot", "client", "work", "done"}.
var job: Dictionary = {}
var low_morale_days: int = 0
var hired_day: int = 0
var hours_worked: float = 0.0


const ADDITIVE_MODS: PackedStringArray = ["sale_bonus", "reveal", "break_chance", "morale_daily"]


## Cumule les modificateurs de traits : additifs, maximum (morale_floor) ou multiplicatifs.
func trait_mod(db: ContentDB, key: String, default: float) -> float:
	var v: float = default
	for t: String in traits:
		var mods: Dictionary = db.traits.get(t, {}).get("mods", {})
		if not mods.has(key):
			continue
		var m: float = float(mods[key])
		if key in ADDITIVE_MODS:
			v += m
		elif key == "morale_floor":
			v = maxf(v, m)
		else:
			v *= m
	return v


func is_working() -> bool:
	return not station.is_empty()


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "role": role, "level": level, "xp": xp, "traits": traits.duplicate(),
		"salary": salary, "morale": morale, "fatigue": fatigue, "portrait": portrait,
		"station": station, "rule": rule, "job": job.duplicate(true),
		"low_morale_days": low_morale_days, "hired_day": hired_day, "hours_worked": hours_worked,
	}


static func from_dict(d: Dictionary) -> Employee:
	var e: Employee = Employee.new()
	e.id = str(d.get("id", ""))
	e.name = str(d.get("name", ""))
	e.role = str(d.get("role", ""))
	e.level = int(d.get("level", 1))
	e.xp = float(d.get("xp", 0.0))
	e.traits = Util.str_array(d.get("traits", []))
	e.salary = int(d.get("salary", 50))
	e.morale = float(d.get("morale", 70.0))
	e.fatigue = float(d.get("fatigue", 0.0))
	e.portrait = str(d.get("portrait", ""))
	e.station = str(d.get("station", ""))
	e.rule = str(d.get("rule", ""))
	e.job = d.get("job", {})
	e.low_morale_days = int(d.get("low_morale_days", 0))
	e.hired_day = int(d.get("hired_day", 0))
	e.hours_worked = float(d.get("hours_worked", 0.0))
	return e
