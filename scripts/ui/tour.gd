extends Node
## Visite automatique de l'interface, lancée par `-- --tour=<mode>` :
##   smoke    (headless) construit chaque écran sur une partie avancée, déclenche les principales
##            interactions et imprime « ##RESULT {json} » (vérifié par tools/check_all.py) ;
##   screens  (fenêtré) enregistre des captures PNG de chaque écran dans --out ;
##   steam    (fenêtré) captures pour la fiche magasin Steam, sur une partie mise en scène (--lang, --out) ;
##   trailer  (fenêtré, avec --write-movie) joue une séquence scénarisée pour la vidéo promotionnelle ;
##   capsules (fenêtré) rend les visuels de la page Steam (scripts/ui/capsules.gd) ;
##   perf     (fenêtré) mesure les images par seconde (synchro verticale coupée) sur l'écran titre puis sur
##            chaque écran d'une partie avancée en vitesse maximale, et imprime « ##RESULT {json} ».
## Captures : fenêtre --window=LxH (1920x1080 par défaut) et taille d'interface --ui-scale=k (0 : réglage
## automatique, comme chez le joueur). La bande-annonce garde l'interface en 480×270 (×4 en 1080p).

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
	if mode != "smoke":
		# Captures et vidéo : la vraie souris (survols, infobulles) ne doit pas apparaître à l'image.
		main.get_viewport().gui_disable_input = true
	if mode != "trailer":
		Audio.enabled = false
	if mode in ["screens", "steam", "perf"]:
		# Rendu « canvas_items » : l'image capturée a la taille de la fenêtre (texte net à cette résolution).
		var dims: PackedStringArray = str(args.get("window", "1920x1080")).split("x")
		main.get_window().size = Vector2i(int(dims[0]), int(dims[1]))
		MainUI.forced_scale = int(args.get("ui-scale", "0"))
		main.apply_view(true)
	elif mode == "trailer":
		MainUI.forced_scale = int(args.get("ui-scale", "4"))
		main.apply_view(true)
	print("TOUR: fenêtre %dx%d, interface %dx%d ×%d" % [main.get_window().size.x, main.get_window().size.y, MainUI.W, MainUI.H, MainUI.K])
	if args.has("lang"):
		I18n.set_locale(str(args["lang"]), false)
	match mode:
		"screens":
			_screens.call_deferred()
		"perf":
			_perf.call_deferred()
		"steam":
			_steam.call_deferred()
		"trailer", "capsules":
			var script: GDScript = load("res://scripts/ui/%s.gd" % mode)
			var tr: Node = script.new()
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


# --- Mesure des performances ----------------------------------------------------

var _samples: Array[float] = []
var _sampling: bool = false


func _process(delta: float) -> void:
	if _sampling:
		_samples.append(delta)


## Échantillonne `sec` secondes de temps d'image : {fps moyen, 1 % des pires images, pire image en ms}.
func _measure(sec: float) -> Dictionary:
	await frames(30)
	_samples.clear()
	_sampling = true
	await get_tree().create_timer(sec).timeout
	_sampling = false
	var sorted: Array[float] = _samples.duplicate()
	sorted.sort()
	var total: float = 0.0
	for d: float in sorted:
		total += d
	var n: int = sorted.size()
	var worst: Array[float] = sorted.slice(n - maxi(1, n / 100), n)
	var wsum: float = 0.0
	for d: float in worst:
		wsum += d
	var slow: int = 0
	for d: float in sorted:
		if d > 1.0 / 55.0:
			slow += 1
	return {"fps": snappedf(float(n) / maxf(total, 0.001), 0.1), "low1": snappedf(float(worst.size()) / maxf(wsum, 0.0001), 0.1),
		"worst_ms": snappedf(sorted[n - 1] * 1000.0 if n > 0 else 0.0, 0.1), "frames": n, "slow_frames": slow}


func _perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var res: Dictionary = {}
	var tc: int = Time.get_ticks_usec()
	for cid: String in ["arrow", "hand", "help"]:
		CursorKit._rasterize(cid, CursorKit.scale_for(MainUI.K))
	res["cursor_ms"] = snappedf(float(Time.get_ticks_usec() - tc) / 1000.0, 0.1)
	res["title"] = await _measure(4.0)
	print("PERF: title ", res["title"])
	var m: GameModel = demo_model()
	Game.use_model(m)
	main.start_game()
	Game.set_speed(99)
	for id: String in ["garage", "auctions", "sales", "staff", "research", "quests", "office"]:
		var t0: int = Time.get_ticks_usec()
		open_screen(id)
		var open_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		res[id] = await _measure(4.0)
		res[id]["open_ms"] = snappedf(open_ms, 0.1)
		print("PERF: %s %s" % [id, str(res[id])])
	print("##RESULT " + JSON.stringify(res))
	get_tree().quit()


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
	# Changement de taille d'interface (comme depuis les paramètres) : tous les écrans se recomposent.
	for k: int in ViewScale.choices(main.get_window().size):
		MainUI.forced_scale = k
		main.apply_view(true)
		for id: String in MainUI.SCREEN_IDS:
			var s2: GameScreen = open_screen(id)
			if s2.get_child_count() == 0:
				errors.append("écran vide en ×%d : %s" % [k, id])
		await frames(1)
	MainUI.forced_scale = 0
	main.apply_view(true)
	main.open_settings()
	await frames(1)
	main.close_all_modals()
	main.open_tutorial()
	await frames(1)
	if not main.tutorial_open():
		errors.append("tutoriel non ouvert")
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
	var out_dir: String = str(args.get("out", ProjectSettings.globalize_path("res://docs/screens")))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var want: Vector2i = main.get_window().size
	if img.get_size() != want:
		push_warning("capture %s : fenêtre de %s au lieu de %s" % [name, img.get_size(), want])
		img.resize(want.x, want.y, Image.INTERPOLATE_LANCZOS)
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
	if only.contains("settings"):
		# Uniquement sur demande (--only=settings) : vérification visuelle de la fenêtre des paramètres.
		main.dialogue.advance()
		main.open_settings()
		await frames(2)
		await capture("10_settings")
		main.close_all_modals()
	if only.contains("tutorial"):
		# Uniquement sur demande (--only=tutorial) : menu Tutoriel, page « L'atelier ».
		main.dialogue.advance()
		main.open_tutorial("workshop")
		await frames(2)
		await capture("11_tutorial")
		main.close_all_modals()
	if only.contains("resize"):
		# Uniquement sur demande (--only=resize) : la fenêtre change de taille, l'interface doit suivre
		# (résolution logique attendue vérifiée après le délai de redimensionnement, puis capturée).
		main.dialogue.advance()
		for dims: Vector2i in [Vector2i(1600, 900), Vector2i(1280, 720)]:
			main.get_window().size = dims
			await get_tree().create_timer(0.5).timeout
			var want: Vector2i = ViewScale.logical_size(dims, ViewScale.resolve(dims, MainUI.forced_scale))
			if Vector2i(MainUI.W, MainUI.H) != want:
				push_error("redimensionnement %s : interface %dx%d au lieu de %s" % [dims, MainUI.W, MainUI.H, want])
			await capture("13_resize_%dx%d" % [dims.x, dims.y])
	if only.contains("tooltip"):
		# Uniquement sur demande (--only=tooltip) : infobulle d'une ressource (survol simulé, sans
		# déplacer le vrai curseur).
		main.dialogue.advance()
		main.get_viewport().gui_disable_input = false
		var box: Control = main.top_bar.stat_box(str(args.get("stat", "credits")))
		var ev: InputEventMouseMotion = InputEventMouseMotion.new()
		ev.position = box.get_global_rect().get_center()
		main.get_viewport().push_input(ev, true)
		await get_tree().create_timer(1.5).timeout
		await capture("12_tooltip")
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


# --- Captures pour la fiche Steam -------------------------------------------------

## Partie de démonstration enrichie : garage agrandi et plein, tous les lieux ouverts, quelques
## technologies accordées (comme une récompense de quête), un vaisseau vedette repeint.
func steam_model() -> GameModel:
	var m: GameModel = demo_model(16, DEMO_SEED)
	for loc: String in Content.db.location_order:
		m.unlock("location:" + loc)
	var cost: int = m.garage_upgrade_cost()
	if cost > 0:
		m.credits += cost
		m.act_upgrade_garage()
	for i: int in 8:
		var avail: Array[String] = ResearchSystem.available(m)
		if avail.is_empty():
			break
		ResearchSystem.grant(m, avail[i % avail.size()])
	AuctionSystem.generate_day(m)
	for l: AuctionLot in m.lots:
		if not l.closed and l.player_max > 0:
			l.player_max = 0
	var locs: PackedStringArray = ["opalia", "nebula", "tartarus", "kryo7"]
	var k: int = 0
	while m.free_slots(true) > 0 and k < 8:
		var w: Ship = ShipFactory.make_wreck(m, locs[k % locs.size()])
		for d: ShipDefect in w.defects:
			d.known = true
		m.ships.append(w)
		k += 1
	m.dialogue_queue.clear()
	return m


## Capture « propre » : sans les notifications des actions de mise en scène.
func steam_capture(name: String) -> void:
	for c: Node in main.toasts.get_children():
		c.queue_free()
	await frames(1)
	await capture(name)


func _steam() -> void:
	main.auto_dialogues = false
	main.show_title()
	await frames(20)
	await steam_capture("01_title")
	var m: GameModel = steam_model()
	Game.use_model(m)
	Game.set_speed(0)
	main.start_game()
	await frames(2)
	# Garage : le plus beau vaisseau, repeint et presque remis à neuf.
	var star: Ship = null
	for s: Ship in m.ships:
		if star == null or s.base_value(m.db) > star.base_value(m.db):
			star = s
	if star != null:
		star.paint = "paint_gold"
		star.wear = minf(star.wear, 0.12)
		main.selected_ship = star.id
	open_screen("garage")
	await steam_capture("02_garage")
	# Enchères au Nébula Bazar : meilleur lot, scanné.
	var auc: AuctionScreen = main.screen("auctions") as AuctionScreen
	var best: AuctionLot = null
	for l: AuctionLot in m.lots:
		if not l.closed and l.location == "nebula" and (best == null or l.ship.base_value(m.db) > best.ship.base_value(m.db)):
			best = l
	if best != null:
		m.credits += 1000
		m.act_scan(best.id)
		auc.location = best.location
		auc.selected_lot = best.id
	open_screen("auctions")
	await steam_capture("03_auctions")
	_prepare(m, "sales")
	open_screen("sales")
	await steam_capture("04_sales")
	open_screen("staff")
	await steam_capture("05_staff")
	_prepare(m, "research")
	open_screen("research")
	await steam_capture("06_research")
	main.selected_ship = -1
	open_screen("garage")
	main.dialogue.show_dialogue({"quest": "m1_04", "phase": "start", "lines": [{"speaker": "lustre", "key": "dlg.m1_04.start.1"}]})
	main.dialogue.finish_typing()
	await steam_capture("07_story")
	main.dialogue.advance()
	m.dialogue_queue.clear()
	# L'équipe au travail : vue d'ensemble du garage pendant le service, quelques heures plus tard.
	Autopilot.new().play_hours(m, 3)
	m.dialogue_queue.clear()
	main.selected_ship = -1
	open_screen("garage")
	await frames(30)
	await steam_capture("08_crew")
	_prepare(m, "quests")
	open_screen("quests")
	await steam_capture("09_quests")
	get_tree().quit(0)
