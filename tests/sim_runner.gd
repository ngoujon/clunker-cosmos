class_name SimRunner
extends RefCounted
## Simulations headless pilotées par l'autopilote :
##  - run_sim : N jours (critères : >= 10 ventes, résultat d'exploitation > 0, 0 erreur) ;
##  - run_story : mode Histoire jusqu'à la fin des chapitres demandés.


static func summary(m: GameModel, credits0: int) -> Dictionary:
	return {
		"day": m.day, "sales": int(m.counter("ships_sold")), "revenue": int(m.counter("income_sales")),
		"operating_profit": int(m.operating_profit()), "net_cash": m.credits - credits0, "credits": m.credits,
		"debt": m.debt, "debt_paid": m.debt_paid_total, "staff": m.staff.size(), "researched": m.researched.size(),
		"reputation": snappedf(m.reputation, 0.1), "bought": int(m.counter("wrecks_bought")),
		"repairs": int(m.counter("defects_repaired")), "concealed": int(m.counter("defects_concealed")),
		"sav": int(m.counter("sav_claims")), "inspections": int(m.counter("inspections")),
		"quests_done": int(m.counter("quests_done")), "chapter": m.chapter, "garage_level": m.garage_level,
		"errors": m.errors.duplicate(),
	}


static func run_sim(days: int, seed_value: int, mode: String) -> int:
	var db: ContentDB = ContentDB.load_default()
	if not db.errors.is_empty():
		print("erreurs de contenu : ", db.errors)
	var m: GameModel = GameModel.create(db, seed_value, mode == "story")
	var ap: Autopilot = Autopilot.new()
	var credits0: int = m.credits
	var t0: int = Time.get_ticks_msec()
	print("SIMULATION %d jours, graine %d, mode %s" % [days, seed_value, mode])
	for d: int in days:
		ap.play_hours(m, 24)
		print("  J%02d  crédits %7d  vaisseaux %d  employés %d  ventes %3d  rép %5.1f  RP %6.1f" % [m.day, m.credits, m.ships.size(), m.staff.size(), int(m.counter("ships_sold")), m.reputation, m.research_points])
	var s: Dictionary = summary(m, credits0)
	s["days"] = days
	s["seed"] = seed_value
	s["mode"] = mode
	s["autopilot_actions"] = ap.actions
	s["ms"] = Time.get_ticks_msec() - t0
	var okv: bool = int(s["sales"]) >= 10 and int(s["operating_profit"]) > 0 and m.errors.is_empty() and db.errors.is_empty()
	s["ok"] = okv
	print("ventes=%d  CA=%d  résultat d'exploitation=%d  trésorerie nette=%d  erreurs=%d" % [s["sales"], s["revenue"], s["operating_profit"], s["net_cash"], m.errors.size()])
	print("##RESULT " + JSON.stringify(s))
	return 0 if okv else 1


static func run_story(max_days: int, seed_value: int, chapters: int) -> int:
	var db: ContentDB = ContentDB.load_default()
	var m: GameModel = GameModel.create(db, seed_value, true)
	var ap: Autopilot = Autopilot.new()
	var credits0: int = m.credits
	var done_days: Dictionary = {}
	print("HISTOIRE : chapitres 1 à %d, graine %d, limite %d jours" % [chapters, seed_value, max_days])
	var finished: bool = false
	while m.day <= max_days and not finished:
		ap.step(m)
		m.advance_hour()
		for id: String in db.quest_order:
			if QuestSystem.status(m, id) == "done" and not done_days.has(id):
				done_days[id] = m.day
				print("  J%02d  quête terminée : %s (%s)" % [m.day, id, db.text("quest.%s.title" % id, "fr")])
		finished = true
		for ch: int in range(1, chapters + 1):
			if not QuestSystem.chapter_complete(m, ch):
				finished = false
	var s: Dictionary = summary(m, credits0)
	var per_chapter: Dictionary = {}
	for ch: int in range(1, chapters + 1):
		per_chapter[str(ch)] = QuestSystem.chapter_complete(m, ch)
	s["chapters"] = per_chapter
	s["quest_days"] = done_days
	s["dialogues_seen"] = int(m.counter("ev_quest_started"))
	s["ok"] = finished and m.errors.is_empty()
	print("chapitres bouclés : %s en %d jours" % [str(per_chapter), m.day])
	print("##RESULT " + JSON.stringify(s))
	return 0 if finished and m.errors.is_empty() else 1
