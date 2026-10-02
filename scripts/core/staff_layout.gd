class_name StaffLayout
extends RefCounted
## Où se tient chaque employé dans la vue en coupe du garage (logique pure, testable en headless).
## Pendant le service : mécaniciens et carrossiers dans la baie du vaisseau qu'ils réparent ou peignent,
## acheteurs et vendeurs aux bureaux de l'étage, chercheurs au labo, employés sans tâche au coin pause.
## Hors service (ou de nuit) : personne.

## Zones de l'étage occupées par poste (emplacement = numéro du poste, donc stable d'une heure à l'autre).
const DESK_ZONES: Dictionary = {"buyer": "buy", "seller": "sell", "researcher": "lab"}


## Une entrée par employé présent : {"employee", "zone" (bay|buy|sell|lab|break), "ship" (-1 hors baie),
## "activity" (repair|conceal|paint|bid|sell|research|idle|pause), "slot"}.
## Emplacements : rang parmi les employés du même vaisseau (baie), numéro du poste (bureaux, labo)
## ou rang d'arrivée au coin pause ; la vue décale ceux qui dépassent les places dessinées.
static func placements(m: GameModel) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not m.is_shift_hour():
		return out
	var per_ship: Dictionary = {}
	var on_break: int = 0
	for e: Employee in m.staff:
		var p: Dictionary = placement(m, e)
		match str(p["zone"]):
			"bay":
				var sid: int = int(p["ship"])
				p["slot"] = int(per_ship.get(sid, 0))
				per_ship[sid] = int(p["slot"]) + 1
			"break":
				p["slot"] = on_break
				on_break += 1
			_:
				p["slot"] = station_index(e.station)
		out.append(p)
	return out


## Zone et activité d'un employé en service (sans emplacement).
static func placement(m: GameModel, e: Employee) -> Dictionary:
	var p: Dictionary = {"employee": e.id, "zone": "break", "ship": -1, "activity": "idle", "slot": 0}
	if not e.is_working():
		p["activity"] = "pause"
		return p
	match str(e.job.get("kind", "")):
		"defect":
			var s: Ship = m.find_ship(int(e.job.get("ship", -1)))
			if s != null:
				var idx: int = int(e.job.get("defect", -1))
				var conceal: bool = idx >= 0 and idx < s.defects.size() and s.defects[idx].work_kind == "conceal"
				p.merge({"zone": "bay", "ship": s.id, "activity": "conceal" if conceal else "repair"}, true)
				return p
		"custom":
			var s2: Ship = m.find_ship(int(e.job.get("ship", -1)))
			if s2 != null:
				p.merge({"zone": "bay", "ship": s2.id, "activity": "paint"}, true)
				return p
		"sell":
			p.merge({"zone": "sell", "activity": "sell"}, true)
			return p
	match e.role:
		"buyer":
			p.merge({"zone": "buy", "activity": "bid"}, true)
		"researcher":
			p.merge({"zone": "lab", "activity": "research"}, true)
	return p


## Numéro du poste « <rôle>_<n> » (0 si illisible).
static func station_index(station: String) -> int:
	var cut: int = station.rfind("_")
	if cut < 0 or not station.substr(cut + 1).is_valid_int():
		return 0
	return maxi(0, station.substr(cut + 1).to_int())


## Employés présents dans une baie donnée (ordre d'affichage).
static func ship_workers(m: GameModel, ship_id: int) -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in placements(m):
		if str(p["zone"]) == "bay" and int(p["ship"]) == ship_id:
			out.append(str(p["employee"]))
	return out
