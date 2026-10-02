class_name ShipFactory
extends RefCounted
## Génère des épaves (aléatoires ou spéciales) à partir des données des lieux et des pièces.

const SEV_WEIGHTS: Dictionary = {"1": 50, "2": 35, "3": 15}


static func pick_part(m: GameModel, slot: String, tier: int) -> String:
	var weights: Dictionary = {}
	for id: String in m.db.parts_by_slot.get(slot, []):
		var t: int = int(m.db.part(id).get("tier", 1))
		if t <= tier:
			weights[id] = 1.0 + 2.0 * float(t == tier) + 0.5 * float(t == tier - 1)
	if weights.is_empty():
		return str((m.db.parts_by_slot.get(slot, []) as Array)[0])
	return Util.pick_weighted(m.rng, weights)


static func make_wreck(m: GameModel, location_id: String, rare: bool = false) -> Ship:
	var loc: Dictionary = m.db.locations.get(location_id, {})
	var tier: int = int(Util.pick_weighted(m.rng, loc.get("tiers", {"1": 1})))
	if rare:
		tier = mini(4, tier + 1)
	var s: Ship = Ship.new()
	s.id = m.new_id()
	s.hull = pick_part(m, "hull", tier)
	s.engine = pick_part(m, "engine", tier)
	s.cockpit = pick_part(m, "cockpit", tier)
	s.wings = pick_part(m, "wings", tier)
	s.rare = rare
	s.name = designation(m)
	s.wear = m.rng.randf_range(0.45, 0.95)
	s.visual_seed = m.rng.randi_range(1, 999999)
	var range_d: Array = loc.get("defects", [3, 6])
	var n: int = m.rng.randi_range(int(range_d[0]), int(range_d[1]))
	roll_defects(m, s, n, float(loc.get("visible_mult", 1.0)))
	return s


static func make_special(m: GameModel, special_id: String) -> Ship:
	var sp: Dictionary = m.db.special_lots.get(special_id, {})
	var parts: Dictionary = sp.get("parts", {})
	var s: Ship = Ship.new()
	s.id = m.new_id()
	s.hull = str(parts.get("hull", "hull_shuttle"))
	s.engine = str(parts.get("engine", "eng_putt"))
	s.cockpit = str(parts.get("cockpit", "cock_box"))
	s.wings = str(parts.get("wings", "wing_stub"))
	s.rare = true
	s.special = special_id
	s.item = str(sp.get("item", ""))
	s.name = "Aurore"
	s.wear = 0.9
	s.visual_seed = m.rng.randi_range(1, 999999)
	for dd: Variant in sp.get("defects", []):
		var arr: Array = dd
		s.defects.append(ShipDefect.make(str(arr[0]), int(arr[1]), true))
	return s


static func designation(m: GameModel) -> String:
	var base: String = Util.pick_str(m.rng, m.db.designations)
	return "%s-%d" % [base, m.rng.randi_range(1, 99)]


static func roll_defects(m: GameModel, s: Ship, n: int, visible_mult: float) -> void:
	var pool: Array[String] = []
	for id: String in m.db.defects:
		pool.append(id)
	Util.shuffle_with(m.rng, pool)
	for i: int in mini(n, pool.size()):
		var def: Dictionary = m.db.defects[pool[i]]
		var sev: int = int(Util.pick_weighted(m.rng, SEV_WEIGHTS))
		var known: bool = m.rng.randf() < clampf(float(def.get("visible", 0.5)) * visible_mult, 0.0, 1.0)
		s.defects.append(ShipDefect.make(pool[i], sev, known))
