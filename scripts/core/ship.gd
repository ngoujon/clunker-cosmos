class_name Ship
extends RefCounted
## Vaisseau (épave ou remis à neuf) composé de 4 pièces modulaires.

var id: int = 0
var name: String = ""
var hull: String = ""
var engine: String = ""
var cockpit: String = ""
var wings: String = ""
var paint: String = "paint_primer"
var options: Array[String] = []
var defects: Array[ShipDefect] = []
var wear: float = 0.5
var for_sale: bool = false
var customized: bool = false
var scanned: bool = false
var acquired_day: int = 0
var purchase_price: int = 0
var invested: int = 0
var rare: bool = false
var special: String = ""
var item: String = ""
var visual_seed: int = 0
## File de personnalisation planifiée : [{"kind": "paint"|"option", "id": ..}]
var custom_plan: Array[Dictionary] = []
## Travail de personnalisation en cours : {"kind", "id", "work", "done", "worker"}
var custom_job: Dictionary = {}


func part_ids() -> Array[String]:
	return [hull, engine, cockpit, wings]


func base_value(db: ContentDB) -> float:
	var v: float = 0.0
	for p: String in part_ids():
		v += float(db.part(p).get("value", 0))
	if rare:
		v *= db.cfgf("auction", "rare_value_mult", 1.3)
	return v


func ship_class(db: ContentDB) -> String:
	return str(db.part(hull).get("class", ""))


func tier(db: ContentDB) -> int:
	return int(db.part(hull).get("tier", 1))


func tags(db: ContentDB) -> Array[String]:
	var out: Array[String] = []
	for p: String in part_ids():
		for t: Variant in db.part(p).get("tags", []):
			var ts: String = str(t)
			if not out.has(ts):
				out.append(ts)
	for o: String in options:
		for t: Variant in db.options.get(o, {}).get("tags", []):
			var ts2: String = str(t)
			if not out.has(ts2):
				out.append(ts2)
	return out


func color(db: ContentDB) -> String:
	return str(db.paints.get(paint, {}).get("color", "primer"))


func open_defects() -> Array[ShipDefect]:
	var out: Array[ShipDefect] = []
	for d: ShipDefect in defects:
		if d.is_open():
			out.append(d)
	return out


func known_open_defects() -> Array[ShipDefect]:
	var out: Array[ShipDefect] = []
	for d: ShipDefect in defects:
		if d.is_open() and d.known:
			out.append(d)
	return out


func hidden_defects() -> Array[ShipDefect]:
	var out: Array[ShipDefect] = []
	for d: ShipDefect in defects:
		if d.is_open() and not d.known:
			out.append(d)
	return out


func concealed_defects() -> Array[ShipDefect]:
	var out: Array[ShipDefect] = []
	for d: ShipDefect in defects:
		if d.state == "concealed":
			out.append(d)
	return out


func is_busy() -> bool:
	if not custom_job.is_empty():
		return true
	for d: ShipDefect in defects:
		if d.is_busy():
			return true
	return false


func to_dict() -> Dictionary:
	var defs: Array = []
	for d: ShipDefect in defects:
		defs.append(d.to_dict())
	return {
		"id": id, "name": name, "hull": hull, "engine": engine, "cockpit": cockpit, "wings": wings,
		"paint": paint, "options": options.duplicate(), "defects": defs, "wear": wear,
		"for_sale": for_sale, "customized": customized, "scanned": scanned,
		"acquired_day": acquired_day, "purchase_price": purchase_price, "invested": invested,
		"rare": rare, "special": special, "item": item, "visual_seed": visual_seed,
		"custom_plan": custom_plan.duplicate(true), "custom_job": custom_job.duplicate(true),
	}


static func from_dict(d: Dictionary) -> Ship:
	var s: Ship = Ship.new()
	s.id = int(d.get("id", 0))
	s.name = str(d.get("name", ""))
	s.hull = str(d.get("hull", ""))
	s.engine = str(d.get("engine", ""))
	s.cockpit = str(d.get("cockpit", ""))
	s.wings = str(d.get("wings", ""))
	s.paint = str(d.get("paint", "paint_primer"))
	s.options = Util.str_array(d.get("options", []))
	for dd: Variant in d.get("defects", []):
		s.defects.append(ShipDefect.from_dict(dd))
	s.wear = float(d.get("wear", 0.5))
	s.for_sale = bool(d.get("for_sale", false))
	s.customized = bool(d.get("customized", false))
	s.scanned = bool(d.get("scanned", false))
	s.acquired_day = int(d.get("acquired_day", 0))
	s.purchase_price = int(d.get("purchase_price", 0))
	s.invested = int(d.get("invested", 0))
	s.rare = bool(d.get("rare", false))
	s.special = str(d.get("special", ""))
	s.item = str(d.get("item", ""))
	s.visual_seed = int(d.get("visual_seed", 0))
	for cp: Variant in d.get("custom_plan", []):
		s.custom_plan.append(cp as Dictionary)
	s.custom_job = d.get("custom_job", {})
	return s
