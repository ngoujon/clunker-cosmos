extends TestCase
## Placement des employés dans la vue en coupe du garage : baies, bureaux, labo, coin pause, absences.


func _find(placements: Array[Dictionary], e: Employee) -> Dictionary:
	for p: Dictionary in placements:
		if str(p["employee"]) == e.id:
			return p
	return {}


func test_nobody_outside_shift() -> void:
	var m: GameModel = new_model()
	hire_role(m, "mechanic")
	hire_role(m, "researcher")
	goto_hour(m, 20)
	eq(StaffLayout.placements(m).size(), 0, "personne la nuit")
	goto_hour(m, 9)
	eq(StaffLayout.placements(m).size(), 2, "tout le monde pendant le service")


func test_mechanic_stands_in_the_bay_of_his_ship() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_rust", 2]])
	var e: Employee = hire_role(m, "mechanic")
	goto_hour(m, 9)
	m.advance_hour()
	var p: Dictionary = _find(StaffLayout.placements(m), e)
	eq(str(p.get("zone", "")), "bay", "zone du mécanicien")
	eq(int(p.get("ship", -1)), s.id, "baie du vaisseau réparé")
	check(str(p.get("activity", "")) in ["repair", "conceal"], "activité d'atelier")
	eq(StaffLayout.ship_workers(m, s.id), [e.id] as Array[String], "liste des employés de la baie")


func test_conceal_activity_follows_defect_work_kind() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_rust", 2]])
	var e: Employee = hire_role(m, "mechanic")
	goto_hour(m, 9)
	s.defects[0].worker = e.id
	s.defects[0].work_kind = "conceal"
	e.job = {"kind": "defect", "ship": s.id, "defect": 0}
	eq(str(StaffLayout.placement(m, e)["activity"]), "conceal", "maquillage")
	s.defects[0].work_kind = "repair"
	eq(str(StaffLayout.placement(m, e)["activity"]), "repair", "réparation")


func test_two_workers_on_one_ship_get_distinct_slots() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_rust", 2], ["d_dent", 2]])
	var a: Employee = hire_role(m, "mechanic")
	var b: Employee = hire_role(m, "mechanic")
	goto_hour(m, 9)
	for i: int in 2:
		var e: Employee = a if i == 0 else b
		s.defects[i].worker = e.id
		e.job = {"kind": "defect", "ship": s.id, "defect": i}
	var pl: Array[Dictionary] = StaffLayout.placements(m)
	eq(int(_find(pl, a)["slot"]), 0, "premier mécanicien")
	eq(int(_find(pl, b)["slot"]), 1, "second mécanicien à côté")


func test_bodyworker_paints_in_the_bay() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m)
	var e: Employee = hire_role(m, "bodyworker")
	goto_hour(m, 9)
	s.custom_job = {"kind": "paint", "id": "paint_red", "worker": e.id, "work": 4.0, "done": 1.0}
	e.job = {"kind": "custom", "ship": s.id}
	var p: Dictionary = StaffLayout.placement(m, e)
	eq(str(p["zone"]), "bay", "zone du carrossier")
	eq(int(p["ship"]), s.id, "baie du vaisseau peint")
	eq(str(p["activity"]), "paint", "activité peinture")


func test_office_roles_sit_at_their_station() -> void:
	var m: GameModel = new_model()
	var buyer: Employee = hire_role(m, "buyer")
	var researcher: Employee = hire_role(m, "researcher")
	goto_hour(m, 10)
	var pl: Array[Dictionary] = StaffLayout.placements(m)
	eq(str(_find(pl, buyer)["zone"]), "buy", "acheteur au bureau des enchères")
	eq(str(_find(pl, researcher)["zone"]), "lab", "chercheur au labo")
	eq(str(_find(pl, researcher)["activity"]), "research", "activité recherche")
	eq(int(_find(pl, buyer)["slot"]), StaffLayout.station_index(buyer.station), "place = numéro du poste")


func test_seller_negotiates_at_desk_or_rests() -> void:
	var m: GameModel = new_model()
	var e: Employee = hire_role(m, "seller")
	goto_hour(m, 9)
	eq(str(StaffLayout.placement(m, e)["zone"]), "break", "vendeur sans client : pause")
	var s: Ship = add_ship(m)
	var c: Client = add_client(m)
	e.job = {"kind": "sell", "ship": s.id, "client": c.id, "work": 2.0, "done": 0.0}
	var p: Dictionary = StaffLayout.placement(m, e)
	eq(str(p["zone"]), "sell", "vendeur en négociation au bureau")
	eq(str(p["activity"]), "sell", "activité vente")


func test_idle_and_unassigned_staff_take_a_break() -> void:
	var m: GameModel = new_model()
	var idle: Employee = hire_role(m, "mechanic")
	var off: Employee = hire_role(m, "bodyworker")
	ok(m.act_assign(off.id, ""), "mise en pause")
	goto_hour(m, 9)
	var pl: Array[Dictionary] = StaffLayout.placements(m)
	eq(str(_find(pl, idle)["zone"]), "break", "mécanicien sans vaisseau")
	eq(str(_find(pl, idle)["activity"]), "idle", "sans tâche")
	eq(str(_find(pl, off)["activity"]), "pause", "non affecté")
	eq(int(_find(pl, idle)["slot"]), 0, "première place du coin pause")
	eq(int(_find(pl, off)["slot"]), 1, "seconde place du coin pause")


func test_station_index_parsing() -> void:
	eq(StaffLayout.station_index("mechanic_3"), 3, "numéro de poste")
	eq(StaffLayout.station_index("seller_0"), 0, "premier poste")
	eq(StaffLayout.station_index(""), 0, "sans poste")
	eq(StaffLayout.station_index("bad"), 0, "illisible")
