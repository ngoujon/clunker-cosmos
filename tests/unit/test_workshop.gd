extends TestCase
## Atelier : réparation, dissimulation, politiques, personnalisation, mise en vente.


func test_owner_repair_costs_and_completes() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_rust", 1]])
	goto_hour(m, 8)
	var cost: int = Valuation.repair_cost(m, s, s.defects[0])
	var credits0: int = m.credits
	ok(m.act_repair(s.id, 0, "repair"), "réparation lancée")
	eq(m.credits, credits0 - cost, "pièces payées")
	eq(s.invested, cost, "coût investi")
	m.advance_hours(int(ceil(Valuation.repair_work(m, s.defects[0]))))
	eq(s.defects[0].state, "repaired", "défaut réparé")
	check(m.owner_job.is_empty(), "patron libre")
	gt(m.counter("ev_defect_repaired"), 0.0, "événement de réparation")


func test_owner_busy_refuses_second_job() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_rust", 2], ["d_dent", 1]])
	goto_hour(m, 8)
	ok(m.act_repair(s.id, 0, "repair"), "premier travail")
	refused(m.act_repair(s.id, 1, "repair"), "owner_busy", "un seul travail à la fois")


func test_owner_boost_speeds_up() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_breach", 3]])
	goto_hour(m, 8)
	ok(m.act_repair(s.id, 0, "repair"), "réparation")
	ok(m.act_boost(), "coup de main")
	near(s.defects[0].progress, db.cfgf("time", "owner_boost_hours", 0.5), 0.001, "progression manuelle")


func test_conceal_marks_defect_and_keeps_true_value_low() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_breach", 2]])
	var apparent0: float = Valuation.apparent_value(m, s)
	goto_hour(m, 8)
	ok(m.act_repair(s.id, 0, "conceal"), "dissimulation")
	m.advance_hours(int(ceil(Valuation.conceal_work(m, s.defects[0]))) + 1)
	eq(s.defects[0].state, "concealed", "défaut dissimulé")
	gt(Valuation.apparent_value(m, s), apparent0, "valeur apparente en hausse")
	check(Valuation.true_value(m, s) < Valuation.apparent_value(m, s), "la valeur réelle reste plus basse")


func test_dangerous_defect_not_concealable() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_plasma_leak", 1]])
	goto_hour(m, 8)
	refused(m.act_repair(s.id, 0, "conceal"), "not_concealable", "fuite de plasma")
	refused(m.act_set_decision(s.id, 0, "conceal"), "not_concealable", "décision")


func test_policy_actions() -> void:
	var m: GameModel = new_model()
	var minor: ShipDefect = ShipDefect.make("d_dent", 1, true)
	var major: ShipDefect = ShipDefect.make("d_dent", 3, true)
	var danger: ShipDefect = ShipDefect.make("d_plasma_leak", 1, true)
	eq(WorkshopSystem.policy_action(m, minor), "repair", "honnête")
	m.act_set_setting("defect_policy", "pragmatic")
	eq(WorkshopSystem.policy_action(m, minor), "conceal", "pragmatique : petit défaut maquillé")
	eq(WorkshopSystem.policy_action(m, major), "repair", "pragmatique : gros défaut réparé")
	m.act_set_setting("defect_policy", "shark")
	eq(WorkshopSystem.policy_action(m, major), "conceal", "requin")
	eq(WorkshopSystem.policy_action(m, danger), "repair", "requin : danger réparé quand même")
	minor.decision = "disclose"
	eq(WorkshopSystem.policy_action(m, minor), "disclose", "décision manuelle prioritaire")


func test_mechanic_repairs_automatically() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_rust", 1], ["d_dent", 1]])
	hire_role(m, "mechanic", 2)
	goto_hour(m, 8)
	m.advance_hours(10)
	eq(s.known_open_defects().size(), 0, "tous les défauts traités")
	check(s.for_sale, "mis en vente automatiquement")


func test_repair_reveals_hidden_defects() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_breach", 3], ["d_rust", 1, false]])
	m.extra_mods.append({"op": "add", "stat": "reveal_on_repair", "value": 5.0})
	m.mark_stats_dirty()
	goto_hour(m, 8)
	ok(m.act_repair(s.id, 0, "repair"), "réparation")
	m.advance_hour()
	check(s.defects[1].known, "défaut caché découvert pendant la réparation")


func test_paint_changes_color_and_wear() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [], 0.8)
	goto_hour(m, 8)
	ok(m.act_customize(s.id, "paint", "paint_red"), "peinture")
	m.advance_hours(int(ceil(WorkshopSystem.custom_work(m, s, "paint", "paint_red"))) + 1)
	eq(s.color(db), "rouge", "couleur appliquée")
	check(s.wear <= db.cfgf("workshop", "wear_after_paint", 0.15) + 0.001, "usure masquée")


func test_locked_paint_refused() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m)
	refused(m.act_customize(s.id, "paint", "paint_purple"), "locked", "violet non débloqué")


func test_option_adds_value() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [], 0.0)
	var v0: float = Valuation.apparent_value(m, s)
	goto_hour(m, 8)
	ok(m.act_customize(s.id, "option", "opt_rack"), "option")
	m.advance_hours(3)
	check("opt_rack" in s.options, "option installée")
	gt(Valuation.apparent_value(m, s), v0, "valeur augmentée")


func test_bodyworker_customizes_then_lists() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_yacht", [], 0.7)
	add_client(m, 90000, ["yacht"], ["bleu"])
	hire_role(m, "bodyworker", 3)
	goto_hour(m, 8)
	m.advance_hours(10)
	m.advance_hours(24)
	eq(s.color(db), "bleu", "peint selon la demande")
	check(s.customized and s.for_sale, "personnalisé puis mis en vente")


func test_auto_list_after_owner_repairs() -> void:
	var m: GameModel = new_model()
	var s: Ship = add_ship(m, "hull_cargo", [["d_dent", 1]])
	m.advance_hour()
	check(not s.for_sale, "pas en vente avec un défaut à traiter")
	ok(m.act_set_decision(s.id, 0, "disclose"), "déclarer le défaut")
	m.advance_hour()
	check(s.for_sale, "en vente une fois les décisions prises")
