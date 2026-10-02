extends TestCase
## Quêtes : déclencheurs, mode Histoire, objectifs, récompenses, secondaires, choix de fin.


func _story() -> GameModel:
	return new_model(5, true)


func _win_any_lot(m: GameModel) -> void:
	m.credits = 100000
	for l: AuctionLot in m.lots:
		if not l.closed:
			m.act_bid(l.id, l.npc_max + 3000)
			AuctionSystem.resolve(m, l)
			return


func test_main_quests_only_in_story_mode() -> void:
	var classic: GameModel = new_model(5, false)
	classic.advance_hours(5)
	eq(QuestSystem.status(classic, "m1_01"), "locked", "pas d'histoire en mode classique")
	var story: GameModel = _story()
	eq(QuestSystem.status(story, "m1_01"), "active", "première quête active en mode Histoire")
	eq(story.chapter, 1, "chapitre 1")


func test_first_quest_queues_dialogue() -> void:
	var m: GameModel = _story()
	check(not m.dialogue_queue.is_empty(), "dialogue d'introduction en file")
	var dlg: Dictionary = m.dialogue_queue[0]
	eq(str(dlg["quest"]), "m1_01", "dialogue de la première quête")
	for line: Variant in dlg["lines"]:
		var ld: Dictionary = line
		check(db.texts.has(str(ld["key"])), "texte de dialogue présent : %s" % ld["key"])
		check(db.characters.has(str(ld["speaker"])) or db.species.has(str(ld["speaker"])), "orateur connu : %s" % ld["speaker"])


func test_buy_objective_completes_with_reward() -> void:
	var m: GameModel = _story()
	var rp0: float = m.research_points
	_win_any_lot(m)
	QuestSystem.update(m)
	eq(QuestSystem.status(m, "m1_01"), "done", "quête terminée")
	gt(m.research_points, rp0, "récompense en RP")
	eq(QuestSystem.status(m, "m1_02"), "active", "quête suivante démarrée")


func test_count_objective_progress() -> void:
	var m: GameModel = _story()
	_win_any_lot(m)
	QuestSystem.update(m)
	var s: Ship = add_ship(m, "hull_cargo", [["d_rust", 1], ["d_dent", 1], ["d_toilet", 1]])
	for d: ShipDefect in s.defects:
		d.work_kind = "repair"
		WorkshopSystem.finish_defect(m, s, d, 0.0)
	var v: Array[float] = QuestSystem.objective_values(m, "m1_02", 0)
	eq(v[0], 3.0, "3 défauts réparés comptés")
	QuestSystem.update(m)
	eq(QuestSystem.status(m, "m1_02"), "done", "objectif atteint")


func test_state_objective_research_count() -> void:
	var m: GameModel = _story()
	QuestSystem.start(m, "m2_02")
	check(not QuestSystem.all_done(m, "m2_02"), "pas encore")
	ResearchSystem.grant(m, "at_1")
	ResearchSystem.grant(m, "co_1")
	QuestSystem.update(m)
	eq(QuestSystem.status(m, "m2_02"), "done", "deux recherches")


func test_on_start_spawns_special_lot() -> void:
	var m: GameModel = _story()
	QuestSystem.start(m, "m1_05")
	var found: bool = false
	for l: AuctionLot in m.lots:
		if l.special == "aurora_keel":
			found = true
	check(found, "lot de la Quille aux enchères")


func test_side_quests_offered_and_accepted() -> void:
	var m: GameModel = new_model(9, false)
	_unlock_everything(m)
	QuestSystem.update(m)
	var avail: Array[String] = QuestSystem.ids_with_status(m, "available", "side")
	gt(float(avail.size()), 0.0, "quêtes secondaires proposées en mode classique")
	ok(m.act_accept_quest(avail[0]), "acceptation")
	eq(QuestSystem.status(m, avail[0]), "active", "active")
	refused(m.act_accept_quest(avail[0]), "not_available", "pas deux fois")


func test_side_quest_deadline_fails() -> void:
	var m: GameModel = new_model(9, false)
	_unlock_everything(m)
	QuestSystem.update(m)
	var target: String = ""
	for id: String in QuestSystem.ids_with_status(m, "available", "side"):
		if int(QuestSystem.quest(m, id).get("deadline_days", 0)) > 0 and not QuestSystem.all_done(m, id):
			target = id
			break
	check(not target.is_empty(), "une commande avec délai")
	if target.is_empty():
		return
	ok(m.act_accept_quest(target), "acceptation")
	m.day += int(QuestSystem.quest(m, target)["deadline_days"]) + 1
	QuestSystem.update(m)
	eq(QuestSystem.status(m, target), "failed", "échec après le délai")


func test_deliver_order_completes() -> void:
	var m: GameModel = new_model(9, false)
	_unlock_everything(m)
	QuestSystem.update(m)
	var target: String = ""
	var obj: Dictionary = {}
	for id: String in QuestSystem.ids_with_status(m, "available", "side"):
		for o: Variant in QuestSystem.quest(m, id).get("objectives", []):
			if str((o as Dictionary).get("type", "")) == "deliver_order":
				target = id
				obj = o
		if not target.is_empty():
			break
	check(not target.is_empty(), "une commande client disponible")
	if target.is_empty():
		return
	ok(m.act_accept_quest(target), "acceptation")
	var client: Client = null
	for c: Client in m.clients:
		if c.quest == target:
			client = c
	check(client != null, "client de la commande présent")
	var s: Ship = _ship_matching(m, obj.get("criteria", {}))
	check(s != null, "vaisseau conforme construit")
	if s == null or client == null:
		return
	var res: Dictionary = m.act_sell(s.id, client.id, client.budget)
	eq(str(res.get("result", "")), "sold", "commande livrée")
	QuestSystem.update(m)
	eq(QuestSystem.status(m, target), "done", "quête terminée")


func test_final_choice_sets_ending() -> void:
	var m: GameModel = _story()
	check(db.quests.has("m5_final"), "quête finale présente")
	QuestSystem.start(m, "m5_final")
	ok(m.act_choose("m5_final", 0), "choix 1")
	eq(QuestSystem.status(m, "m5_final"), "done", "quête finale terminée")
	check(not m.ending.is_empty(), "une fin est choisie")
	check(db.endings.has(m.ending), "fin connue : %s" % m.ending)


func test_second_ending_reachable() -> void:
	var m: GameModel = _story()
	QuestSystem.start(m, "m5_final")
	ok(m.act_choose("m5_final", 1), "choix 2")
	check(db.endings.has(m.ending), "fin connue")
	var other: GameModel = _story()
	QuestSystem.start(other, "m5_final")
	other.act_choose("m5_final", 0)
	check(other.ending != m.ending, "les deux fins sont différentes")


func test_journal_records_events() -> void:
	var m: GameModel = _story()
	_win_any_lot(m)
	QuestSystem.update(m)
	var events: Array[String] = []
	for j: Dictionary in m.journal:
		events.append(str(j["event"]))
	check("started" in events and "completed" in events, "journal : démarrage et fin")


# --- Aides -----------------------------------------------------------------------

func _unlock_everything(m: GameModel) -> void:
	m.day = 40
	m.reputation = 90.0
	m.credits = 500000
	for id: String in db.tech:
		ResearchSystem.grant(m, id)
	m.counters["ships_sold"] = 50.0


func _ship_matching(m: GameModel, crit: Dictionary) -> Ship:
	var classes: Array[String] = Util.str_array(crit.get("class", []))
	var tags: Array[String] = Util.str_array(crit.get("tags", []))
	for h: String in db.parts_by_slot["hull"]:
		if not classes.is_empty() and not str(db.part(h)["class"]) in classes:
			continue
		for e: String in db.parts_by_slot["engine"]:
			for c: String in db.parts_by_slot["cockpit"]:
				for w: String in db.parts_by_slot["wings"]:
					var s: Ship = Ship.new()
					s.id = m.new_id()
					s.hull = h
					s.engine = e
					s.cockpit = c
					s.wings = w
					s.wear = 0.0
					for o: String in Util.str_array(crit.get("options", [])):
						s.options.append(o)
					if crit.has("color"):
						s.paint = WorkshopSystem.paint_for_color(m, str(crit["color"]))
					var all_tags: bool = true
					for t: String in tags:
						if not t in s.tags(db):
							all_tags = false
					if all_tags and Valuation.matches_criteria(m, s, crit):
						m.ships.append(s)
						return s
	return null
