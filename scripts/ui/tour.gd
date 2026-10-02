extends Node
## Visite automatique de l'interface, lancée par `-- --tour=<mode>` :
##   smoke    (headless) construit chaque écran sur une partie avancée, déclenche les principales
##            interactions et imprime « ##RESULT {json} » (vérifié par tools/check_all.py) ;
##   screens  (fenêtré) enregistre des captures PNG de chaque écran dans --out (×--scale) ;
##   trailer  (fenêtré, avec --write-movie) joue une séquence scénarisée pour la vidéo promotionnelle.

const DEMO_SEED: int = 20261
const DEMO_DAYS: int = 14

var main: MainUI = null
var args: Dictionary = {}
var errors: Array[String] = []


func start(p_main: MainUI, p_args: Dictionary) -> void:
	main = p_main
	args = p_args
	Game.persist = false
	var mode: String = str(args.get("tour", "smoke"))
	match mode:
		"screens":
			_screens.call_deferred()
		"trailer":
			var trailer_script: GDScript = load("res://scripts/ui/trailer.gd")
			var tr: Node = trailer_script.new()
			add_child(tr)
			tr.call("run", main, self)
		_:
			_smoke.call_deferred()


## Partie de démonstration : mode Histoire jouée par l'autopilote pendant quelques jours.
func demo_model(days: int = DEMO_DAYS, seed_value: int = DEMO_SEED) -> GameModel:
	var m: GameModel = GameModel.create(Content.db, seed_value, true)
	var ap: Autopilot = Autopilot.new()
	ap.play_hours(m, days * 24)
	# Heure de travail, file de dialogues vidée : l'atelier est en pleine activité.
	while m.hour != 10:
		ap.play_hours(m, 1)
	m.dialogue_queue.clear()
	return m


func frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func open_screen(id: String) -> GameScreen:
	main.show_screen(id)
	var s: GameScreen = main.screen(id)
	s.force_rebuild()
	return s


# --- Test de fumée --------------------------------------------------------------

func _smoke() -> void:
	var t0: int = Time.get_ticks_msec()
	var m: GameModel = demo_model()
	Game.use_model(m)
	Game.set_speed(0)
	main.start_game()
	await frames(2)
	var built: Dictionary = {}
	for id: String in MainUI.SCREEN_IDS:
		var s: GameScreen = open_screen(id)
		await frames(2)
		built[id] = s.get_child_count()
		if s.get_child_count() == 0:
			errors.append("écran vide : " + id)
	# Interactions principales
	if not m.ships.is_empty():
		main.selected_ship = m.ships[0].id
		open_screen("garage")
		await frames(1)
	var auc: AuctionScreen = main.screen("auctions") as AuctionScreen
	for lid: String in m.unlocked_locations():
		auc.location = lid
		open_screen("auctions")
		await frames(1)
	var sales: SalesScreen = main.screen("sales") as SalesScreen
	for c: Client in m.clients:
		sales.selected_client = c.id
		open_screen("sales")
		await frames(1)
	var qs: QuestScreen = main.screen("quests") as QuestScreen
	for qid: String in Content.db.quest_order:
		if QuestSystem.status(m, qid) != "locked":
			qs.select(qid)
			open_screen("quests")
	var rs: ResearchScreen = main.screen("research") as ResearchScreen
	for nid: String in Content.db.tech:
		rs.selected_node = nid
		rs.force_rebuild()
	main.open_settings()
	await frames(1)
	main.close_all_modals()
	main.show_report_popup(OfflineSim.run_hours(m, 6), true)
	await frames(1)
	main.close_all_modals()
	main.dialogue.show_dialogue({"quest": "m1_01", "phase": "start", "lines": [{"speaker": "bolt", "key": "dlg.m1_01.start.1"}, {"speaker": "glorbian", "key": "dlg.m1_01.start.0"}]})
	main.dialogue.advance()
	main.dialogue.advance()
	main.dialogue.advance()
	main.dialogue.advance()
	await frames(1)
	I18n.set_locale("en", false)
	await frames(2)
	open_screen("garage")
	I18n.set_locale("fr", false)
	await frames(2)
	# Le temps avance avec l'UI ouverte
	Game.set_speed(3)
	for i: int in 30:
		m.advance_hour()
		main._on_hour()
		await frames(1)
	for id: String in MainUI.SCREEN_IDS:
		open_screen(id)
	await frames(2)
	errors.append_array(m.errors)
	var result: Dictionary = {"ok": errors.is_empty(), "screens": built, "errors": errors, "day": m.day, "ships": m.ships.size(), "staff": m.staff.size(), "ms": Time.get_ticks_msec() - t0}
	print("UI SMOKE: %d écrans construits, %d erreurs" % [built.size(), errors.size()])
	print("##RESULT " + JSON.stringify(result))
	get_tree().quit(0 if errors.is_empty() else 1)


# --- Captures d'écran -------------------------------------------------------------

func capture(name: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var scale: int = int(args.get("scale", "3"))
	var out_dir: String = str(args.get("out", ProjectSettings.globalize_path("res://docs/screens")))
	DirAccess.make_dir_recursive_absolute(out_dir)
	if img.get_width() != MainUI.W:
		img.resize(MainUI.W, MainUI.H, Image.INTERPOLATE_NEAREST)
	if scale > 1:
		img.resize(MainUI.W * scale, MainUI.H * scale, Image.INTERPOLATE_NEAREST)
	var path: String = out_dir.path_join(name + ".png")
	img.save_png(path)
	print("capture : ", path)


func _screens() -> void:
	var only: String = str(args.get("only", ""))
	if only.is_empty() or only.contains("title"):
		main.show_title()
		await frames(20)
		await capture("00_title")
	var m: GameModel = demo_model()
	Game.use_model(m)
	Game.set_speed(0)
	main.start_game()
	await frames(2)
	var plan: Array[String] = ["garage", "auctions", "staff", "research", "quests", "sales", "office"]
	for i: int in plan.size():
		var id: String = plan[i]
		if not only.is_empty() and not only.contains(id):
			continue
		_prepare(m, id)
		open_screen(id)
		await capture("%02d_%s" % [i + 1, id])
	if only.is_empty() or only.contains("dialogue"):
		open_screen("garage")
		main.selected_ship = -1
		main.screen("garage").force_rebuild()
		main.dialogue.show_dialogue({"quest": "m2_04", "phase": "start", "lines": [{"speaker": "bolt", "key": "dlg.m1_02.start.1"}]})
		main.dialogue.finish_typing()
		await capture("08_dialogue")
	get_tree().quit(0)


## Met en scène un écran avant sa capture (sélections représentatives).
func _prepare(m: GameModel, id: String) -> void:
	match id:
		"garage":
			main.selected_ship = -1
			for s: Ship in m.ships:
				if not s.known_open_defects().is_empty():
					main.selected_ship = s.id
					break
		"auctions":
			var auc: AuctionScreen = main.screen("auctions") as AuctionScreen
			var best: AuctionLot = null
			for l: AuctionLot in m.lots:
				if not l.closed and (best == null or l.ship.base_value(m.db) > best.ship.base_value(m.db)):
					best = l
			if best != null:
				auc.location = best.location
				auc.selected_lot = best.id
		"quests":
			var qs: QuestScreen = main.screen("quests") as QuestScreen
			var act: Array[String] = QuestSystem.ids_with_status(m, "active", "main")
			if not act.is_empty():
				qs.selected_quest = act[0]
		"research":
			var rs: ResearchScreen = main.screen("research") as ResearchScreen
			var avail: Array[String] = ResearchSystem.available(m)
			if not avail.is_empty():
				rs.selected_node = avail[0]
		"sales":
			var ss: SalesScreen = main.screen("sales") as SalesScreen
			for c: Client in m.clients:
				if not c.quest.is_empty():
					ss.selected_client = c.id
					break
