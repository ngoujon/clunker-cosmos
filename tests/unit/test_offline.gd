extends TestCase
## Progression hors ligne : plafond, absence du patron, travail des employés, rapport.


func test_hours_from_elapsed_time() -> void:
	var m: GameModel = new_model()
	var sph: float = db.cfgf("time", "seconds_per_hour", 4.0)
	eq(OfflineSim.hours_for(m, sph * 10.0 + 0.5), 10, "10 heures de jeu")


func test_hours_capped() -> void:
	var m: GameModel = new_model()
	eq(OfflineSim.hours_for(m, 1.0e9), int(db.cfgf("offline", "cap_hours", 24.0)), "plafond")


func test_cap_extended_by_research() -> void:
	var m: GameModel = new_model()
	ResearchSystem.grant(m, "at_7")
	eq(OfflineSim.hours_for(m, 1.0e9), int(db.cfgf("offline", "cap_hours", 24.0)) + 24, "Veilleur de nuit")


func test_zero_elapsed_changes_nothing() -> void:
	var m: GameModel = new_model()
	var day0: int = m.day
	var hour0: int = m.hour
	var rep: Dictionary = OfflineSim.run(m, 0.0)
	eq(int(rep["hours"]), 0, "aucune heure")
	eq(m.day, day0, "même jour")
	eq(m.hour, hour0, "même heure")


func test_owner_does_not_work_offline() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_breach", 3]])
	goto_hour(m, 8)
	ok(m.act_repair(s.id, 0, "repair"), "réparation du patron")
	OfflineSim.run_hours(m, 6)
	near(s.defects[0].progress, 0.0, 0.0001, "le patron ne travaille pas hors ligne")
	check(m.owner_online, "patron de retour en ligne")


func test_staff_work_offline_with_report() -> void:
	var m: GameModel = new_model()
	add_ship(m, "hull_cargo", [["d_rust", 1], ["d_dent", 1], ["d_toilet", 1]])
	hire_role(m, "mechanic", 3)
	var rep: Dictionary = OfflineSim.run_hours(m, 24)
	eq(int(rep["hours"]), 24, "24 heures simulées")
	ge(float(rep["repairs"]), 3.0, "réparations faites hors ligne")
	for k: String in ["credits_delta", "sold", "revenue", "bought", "repairs", "events", "days_passed"]:
		check(rep.has(k), "champ de rapport %s" % k)


func test_offline_sales_by_seller() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [], 0.2)
	s.for_sale = true
	add_client(m, 900000, ["cargo"])
	hire_role(m, "seller", 3)
	var rep: Dictionary = OfflineSim.run_hours(m, 12)
	ge(float(rep["sold"]), 1.0, "vente réalisée hors ligne")
	gt(float(rep["revenue"]), 0.0, "chiffre d'affaires")
	var types: Array[String] = []
	for ev: Dictionary in rep["events"]:
		types.append(str(ev["type"]))
	check("ship_sold" in types, "vente listée dans le rapport")


func test_offline_auctions_resolve_with_buyer() -> void:
	var m: GameModel = new_model()
	m.credits = 80000
	hire_role(m, "buyer", 4)
	OfflineSim.run_hours(m, 24)
	gt(m.counter("ev_bid_placed"), 0.0, "l'acheteur enchérit hors ligne")


func test_daily_report_generated() -> void:
	var m: GameModel = new_model()
	m.advance_hours(24)
	var r: Dictionary = m.last_report()
	check(not r.is_empty(), "rapport du jour")
	check(r.has("income") and r.has("expense") and r.has("events"), "contenu du rapport")
	eq(int(r["day"]), 1, "rapport du jour 1")
