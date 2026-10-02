extends TestCase
## Fumée : quelques jours d'autopilote sans erreur, dans les deux modes.


func test_classic_week_runs_clean() -> void:
	var m: GameModel = new_model(21, false)
	var ap: Autopilot = Autopilot.new()
	ap.play_hours(m, 24 * 7)
	eq(m.errors.size(), 0, "aucune erreur d'intégrité : %s" % str(m.errors))
	ge(m.counter("ships_sold"), 1.0, "au moins une vente en une semaine")
	gt(m.counter("wrecks_bought"), 0.0, "au moins un achat")


func test_story_week_progresses() -> void:
	var m: GameModel = new_model(22, true)
	var ap: Autopilot = Autopilot.new()
	ap.play_hours(m, 24 * 7)
	eq(m.errors.size(), 0, "aucune erreur")
	eq(QuestSystem.status(m, "m1_01"), "done", "première quête bouclée")


func test_determinism_same_seed() -> void:
	var a: GameModel = new_model(77, false)
	var b: GameModel = new_model(77, false)
	Autopilot.new().play_hours(a, 72)
	Autopilot.new().play_hours(b, 72)
	eq(a.credits, b.credits, "même graine, même résultat")
