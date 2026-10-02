extends TestCase
## Arbre technologique : prérequis, coûts, effets en modificateurs, déblocages.


func _rich(m: GameModel) -> void:
	m.credits = 1000000
	m.research_points = 10000.0


func test_requires_prereqs() -> void:
	var m: GameModel = new_model()
	_rich(m)
	refused(m.act_research("at_2"), "prereq", "at_2 sans at_1")
	ok(m.act_research("at_1"), "at_1")
	ok(m.act_research("at_2"), "at_2 après at_1")


func test_cross_branch_prereq() -> void:
	var m: GameModel = new_model()
	_rich(m)
	for id: String in ["li_1", "li_3", "li_4"]:
		ok(m.act_research(id), id)
	refused(m.act_research("li_6"), "prereq", "Opalia exige aussi co_3")
	for id2: String in ["co_1", "co_2", "co_3"]:
		ok(m.act_research(id2), id2)
	ok(m.act_research("li_6"), "Opalia")


func test_costs_rp_and_credits() -> void:
	var m: GameModel = new_model()
	m.credits = 5000
	m.research_points = 100.0
	var node: Dictionary = db.tech["co_1"]
	ok(m.act_research("co_1"), "co_1")
	eq(m.credits, 5000 - int(node["credits"]), "crédits dépensés")
	near(m.research_points, 100.0 - float(node["rp"]), 0.001, "RP dépensés")


func test_insufficient_rp_or_credits() -> void:
	var m: GameModel = new_model()
	m.research_points = 0.0
	refused(m.act_research("at_1"), "rp", "RP insuffisants")
	m.research_points = 100.0
	m.credits = 0
	refused(m.act_research("at_1"), "credits", "crédits insuffisants")


func test_effect_modifies_stat() -> void:
	var m: GameModel = new_model()
	_rich(m)
	near(m.stat("repair_speed"), 1.0, 0.0001, "vitesse de base")
	ok(m.act_research("at_1"), "at_1")
	near(m.stat("repair_speed"), 1.1, 0.0001, "+10 %")
	ok(m.act_research("at_2"), "at_2")
	near(m.stat("repair_speed"), 1.1 * 1.15, 0.0001, "effets multiplicatifs cumulés")


func test_additive_effects() -> void:
	var m: GameModel = new_model()
	_rich(m)
	var slots0: int = m.ship_slots()
	for id: String in ["at_1", "at_2", "at_3", "at_4", "at_5"]:
		ok(m.act_research(id), id)
	eq(m.ship_slots(), slots0 + 2, "Hangar agrandi : +2 emplacements")


func test_unlock_location() -> void:
	var m: GameModel = new_model()
	_rich(m)
	check(not m.is_unlocked("location:kryo7"), "Kryo-7 verrouillé")
	ok(m.act_research("li_1"), "permis")
	check(m.is_unlocked("location:kryo7"), "Kryo-7 débloqué")
	check("kryo7" in m.unlocked_locations(), "dans la liste des lieux")


func test_unlock_paint_and_option() -> void:
	var m: GameModel = new_model()
	_rich(m)
	for id: String in ["pe_1", "pe_2", "pe_3"]:
		ok(m.act_research(id), id)
	check(m.is_unlocked("paint:paint_purple"), "violet débloqué")
	check(m.is_unlocked("option:opt_neon"), "néons débloqués")


func test_cannot_research_twice() -> void:
	var m: GameModel = new_model()
	_rich(m)
	ok(m.act_research("di_1"), "di_1")
	refused(m.act_research("di_1"), "done", "déjà fait")


func test_grant_is_free() -> void:
	var m: GameModel = new_model()
	var credits0: int = m.credits
	ResearchSystem.grant(m, "rh_1")
	check("rh_1" in m.researched, "accordé")
	eq(m.credits, credits0, "gratuit")


func test_node_states_for_graph() -> void:
	var m: GameModel = new_model()
	m.credits = 1000000
	m.research_points = 9.0
	eq(ResearchSystem.node_state(m, "at_1"), "ready", "racine abordable")
	eq(ResearchSystem.node_state(m, "at_2"), "locked", "prérequis manquant")
	eq(ResearchSystem.node_state(m, "li_1"), "available", "RP insuffisants")
