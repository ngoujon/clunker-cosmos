extends TestCase
## Ressources humaines : vivier, embauche, postes, efficacité, XP, fatigue, moral, salaires.


func test_pool_size_matches_stat() -> void:
	var m: GameModel = new_model()
	eq(m.candidates.size(), int(db.stats["hire_pool"]), "taille du vivier")
	ResearchSystem.grant(m, "rh_1")
	ResearchSystem.grant(m, "rh_2")
	StaffSystem.refresh_pool(m)
	eq(m.candidates.size(), int(db.stats["hire_pool"]) + 2, "vivier après Petites annonces")


func test_pool_renews_each_day() -> void:
	var m: GameModel = new_model()
	var before: Array[String] = []
	for c: Employee in m.candidates:
		before.append(c.id)
	m.advance_hours(24)
	for c: Employee in m.candidates:
		check(not c.id in before, "candidat %s non renouvelé" % c.id)


func test_hire_pays_signing_and_assigns_station() -> void:
	var m: GameModel = new_model()
	var c: Employee = m.candidates[0]
	var cost: int = StaffSystem.hire_cost(m, c)
	var credits0: int = m.credits
	ok(m.act_hire(c.id), "embauche")
	eq(m.credits, credits0 - cost, "prime d'embauche")
	eq(m.staff.size(), 1, "effectif")
	check(m.staff[0].station.begins_with(c.role), "affecté à un poste de son rôle")
	check(m.find_candidate(c.id) == null, "retiré du vivier")


func test_hire_respects_max_staff() -> void:
	var m: GameModel = new_model()
	m.credits = 100000
	for i: int in m.max_staff():
		hire_role(m, "mechanic")
	StaffSystem.refresh_pool(m)
	refused(m.act_hire(m.candidates[0].id), "staff_full", "effectif plein")


func test_hire_requires_credits() -> void:
	var m: GameModel = new_model()
	m.credits = 0
	refused(m.act_hire(m.candidates[0].id), "credits", "fonds insuffisants")


func test_fire_releases_job() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_rust", 2]])
	var e: Employee = hire_role(m, "mechanic")
	goto_hour(m, 9)
	m.advance_hour()
	eq(s.defects[0].worker, e.id, "le mécanicien travaille sur le défaut")
	ok(m.act_fire(e.id), "renvoi")
	eq(s.defects[0].worker, "", "défaut libéré")
	eq(m.staff.size(), 0, "effectif après renvoi")


func test_assign_rejects_wrong_role_station() -> void:
	var m: GameModel = new_model()
	var e: Employee = hire_role(m, "mechanic")
	refused(m.act_assign(e.id, "seller_0"), "bad_station", "poste d'un autre rôle")
	ok(m.act_assign(e.id, ""), "mise en pause")
	eq(e.station, "", "en pause")
	ok(m.act_assign(e.id, "mechanic_1"), "affectation baie 2")


func test_assign_rejects_taken_station() -> void:
	var m: GameModel = new_model()
	var a: Employee = hire_role(m, "seller")
	var b: Employee = hire_role(m, "seller")
	eq(a.station, "seller_0", "premier vendeur au poste")
	eq(b.station, "", "un seul bureau de vente : le second attend")
	refused(m.act_assign(b.id, "seller_0"), "station_taken", "poste occupé")


func test_station_count_limits_workers() -> void:
	var m: GameModel = new_model()
	eq(m.station_count("mechanic"), 2, "baies au niveau 1")
	ResearchSystem.grant(m, "at_4")
	eq(m.station_count("mechanic"), 3, "baie supplémentaire")


func test_efficiency_level_fatigue_morale() -> void:
	var m: GameModel = new_model()
	var e: Employee = hire_role(m, "mechanic", 1)
	e.morale = 50.0
	var base: float = StaffSystem.efficiency(m, e)
	e.level = 5
	gt(StaffSystem.efficiency(m, e), base, "le niveau augmente l'efficacité")
	e.level = 1
	e.fatigue = 90.0
	check(StaffSystem.efficiency(m, e) < base, "la fatigue réduit l'efficacité")


func test_trait_modifiers_apply() -> void:
	var m: GameModel = new_model()
	var e: Employee = hire_role(m, "mechanic")
	e.morale = 50.0
	var base: float = StaffSystem.efficiency(m, e)
	e.traits = ["speedy"]
	near(StaffSystem.efficiency(m, e), base * 1.2, 0.001, "trait Rapide")
	e.traits = ["insomniac"]
	near(e.trait_mod(db, "fatigue", 1.0), 0.6, 0.001, "trait Insomniaque")
	e.traits = ["loyal"]
	near(e.trait_mod(db, "morale_floor", 0.0), 40.0, 0.001, "trait Loyal")


func test_xp_levels_up_and_raises_salary() -> void:
	var m: GameModel = new_model()
	var e: Employee = hire_role(m, "researcher", 1)
	var salary0: int = e.salary
	goto_hour(m, 8)
	m.advance_hours(24 * 3)
	gt(float(e.level), 1.0, "montée de niveau après 3 jours")
	gt(float(e.salary), float(salary0), "augmentation de salaire")
	gt(m.counter("ev_employee_level"), 0.0, "événement de niveau")


func test_fatigue_accumulates_on_shift_and_recovers() -> void:
	var m: GameModel = new_model()
	var e: Employee = hire_role(m, "researcher")
	goto_hour(m, 8)
	m.advance_hours(6)
	gt(e.fatigue, 20.0, "fatigue pendant le service")
	goto_hour(m, 7)
	near(e.fatigue, 0.0, 0.01, "repos nocturne")


func test_salaries_paid_daily() -> void:
	var m: GameModel = new_model()
	var e: Employee = hire_role(m, "seller")
	goto_hour(m, 23)
	var before: float = m.counter("expense_salaries")
	m.advance_hour()
	near(m.counter("expense_salaries") - before, float(e.salary), 0.5, "salaire versé à minuit")


func test_unpaid_salaries_hurt_morale_and_quit() -> void:
	var m: GameModel = new_model()
	var e: Employee = hire_role(m, "seller")
	var loyal: Employee = hire_role(m, "mechanic")
	loyal.traits = ["loyal"]
	e.morale = 20.0
	loyal.morale = 20.0
	m.credits = -100000
	m.advance_hours(24 * 3)
	check(m.find_employee(e.id) == null, "démission après salaires impayés")
	check(m.find_employee(loyal.id) != null, "l'employé loyal reste")
	gt(m.counter("ev_employee_quit"), 0.0, "événement de démission")


func test_priority_rule_quick_first() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_breach", 3], ["d_dent", 1]])
	var e: Employee = hire_role(m, "mechanic")
	ok(m.act_set_rule(e.id, "quick_first"), "règle")
	eq(m.hour, 8, "début de service")
	m.advance_hour()
	eq(int(e.job.get("defect", -1)), 1, "le travail le plus court d'abord")
	eq(s.defects[1].worker, e.id, "défaut rapide pris")


func test_priority_rule_critical_first() -> void:
	var m: GameModel = new_model()
	add_ship(m, "hull_cargo", [["d_dent", 1], ["d_plasma_leak", 1]])
	var e: Employee = hire_role(m, "mechanic")
	ok(m.act_set_rule(e.id, "critical_first"), "règle")
	m.advance_hour()
	eq(int(e.job.get("defect", -1)), 1, "défaut dangereux d'abord")


func test_set_rule_validation() -> void:
	var m: GameModel = new_model()
	var e: Employee = hire_role(m, "seller")
	refused(m.act_set_rule(e.id, "critical_first"), "bad_rule", "règle d'un autre rôle")
	ok(m.act_set_rule(e.id, "quick_sale"), "règle valide")


func test_researcher_produces_rp() -> void:
	var m: GameModel = new_model()
	hire_role(m, "researcher")
	goto_hour(m, 8)
	var rp0: float = m.research_points
	m.advance_hours(10)
	gt(m.research_points - rp0, 7.0, "points de recherche produits en une journée")
