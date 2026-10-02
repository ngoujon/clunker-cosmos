extends Node
## Bande-annonce scénarisée (vidéo promotionnelle Steam) jouée par le vrai jeu :
##   godot --path . --write-movie build/trailer_fr/frame.png --fixed-fps 30 \
##         res://scenes/main.tscn -- --tour=trailer --lang=fr
## (voir tools/make_trailer.py). Un faux curseur montre les clics ; les actions passent par l'UI réelle
## (signaux des boutons, donc avec leurs bruitages) ou, pour les montages accélérés, directement par l'API
## du modèle. La musique du menu accompagne toute la vidéo (enregistrée avec le son par le Movie Maker).
## Les messages « TRAILER: … » de la console servent de contrôle (actions réussies, boutons trouvés).

const BAND_H: int = 26

var main: MainUI = null
var tour: Node = null
var m: GameModel = null
var cursor: FakeCursor = null
var band: Control = null
var band_label: Label = null
var layer: CanvasLayer = null
var fade: ColorRect = null
var bid_lot: int = -1


func run(p_main: MainUI, p_tour: Node) -> void:
	main = p_main
	tour = p_tour
	_run.call_deferred()


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


# --- Habillage : bandeau de texte, curseur, fondus --------------------------------

func _build_overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	band = Control.new()
	band.size = Vector2(MainUI.W, BAND_H)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.modulate.a = 0.0
	layer.add_child(band)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(UIKit.C_DARK, 0.86)
	bg.size = band.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(bg)
	for y: int in [0, BAND_H - 1]:
		var edge: ColorRect = ColorRect.new()
		edge.color = UIKit.C_ACCENT
		edge.size = Vector2(MainUI.W, 1)
		edge.position = Vector2(0, y)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(edge)
	band_label = _big_label("", 16, UIKit.C_TEXT)
	band_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band_label.size = band.size
	band.add_child(band_label)
	var clayer: CanvasLayer = CanvasLayer.new()
	clayer.layer = 30
	add_child(clayer)
	cursor = FakeCursor.new()
	cursor.position = Vector2(240, 135)
	clayer.add_child(cursor)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.size = Vector2(MainUI.W, MainUI.H)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clayer.add_child(fade)


func _big_label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = UIKit.label(text, color)
	l.theme = UIKit.theme()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_shadow_color", UIKit.C_DARK)
	var off: int = 2 if font_size >= 32 else 1
	l.add_theme_constant_override("shadow_offset_x", off)
	l.add_theme_constant_override("shadow_offset_y", off)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Bandeau de légende : en bas par défaut (il masque la barre de navigation, la moins utile à l'écran),
## en haut quand le bas est occupé (boîte de dialogue).
func say(key: String, top: bool = false) -> void:
	band_label.text = I18n.t(key)
	band.position.y = float(MainUI.TOP_H) + 2.0 if top else float(MainUI.H - BAND_H)
	var tw: Tween = band.create_tween()
	tw.tween_property(band, "modulate:a", 1.0, 0.25)


func unsay() -> void:
	var tw: Tween = band.create_tween()
	tw.tween_property(band, "modulate:a", 0.0, 0.25)


func fade_to(alpha: float, dur: float) -> void:
	var tw: Tween = fade.create_tween()
	tw.tween_property(fade, "color:a", alpha, dur)
	await tw.finished


func move_to(pos: Vector2, dur: float = 0.45) -> void:
	var tw: Tween = cursor.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cursor, "position", pos, dur)
	await tw.finished


func click_at(pos: Vector2) -> void:
	await move_to(pos)
	cursor.press()
	await wait(0.15)


## Clic sur un contrôle réel : le curseur s'y rend puis le bouton est déclenché par son signal.
func click(c: Control) -> void:
	if c == null:
		return
	await click_at(c.get_global_rect().get_center())
	var b: Button = c as Button
	if b != null:
		if b.toggle_mode:
			b.button_pressed = not b.button_pressed
		b.pressed.emit()
	else:
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		c.gui_input.emit(ev)
	await wait(0.1)


## Bouton visible et actif dont le texte commence par `prefix` ; signale l'absence dans la console.
func btn(root: Node, prefix: String) -> Button:
	var b: Button = find_button(root, prefix)
	if b == null:
		print("TRAILER: bouton introuvable « %s »" % prefix)
	return b


static func find_button(root: Node, prefix: String) -> Button:
	for c: Node in root.get_children():
		var b: Button = c as Button
		if b != null and b.is_visible_in_tree() and not b.disabled and b.text.begins_with(prefix):
			return b
		var found: Button = find_button(c, prefix)
		if found != null:
			return found
	return null


func screen_now(id: String) -> GameScreen:
	clear_toasts()
	main.show_screen(id)
	var s: GameScreen = main.screen(id)
	s.force_rebuild()
	return s


## Repère temporel d'un plan (le Movie Maker avance de 1/30 s par image).
func mark(shot: String) -> void:
	print("TRAILER: plan %s @ %.1f s" % [shot, float(Engine.get_frames_drawn()) / 30.0])


## Les notifications d'un plan précédent ne doivent pas s'empiler sur le suivant.
func clear_toasts() -> void:
	for c: Node in main.toasts.get_children():
		c.queue_free()


# --- Séquence ------------------------------------------------------------------------

func _run() -> void:
	I18n.set_locale(str(tour.args.get("lang", "fr")), false)
	main.auto_dialogues = false
	main.show_title()
	# Un seul morceau du début à la fin : les changements d'écran ne relancent pas la musique.
	Audio.play_music("title")
	Audio.music_locked = true
	_build_overlay()
	m = tour.call("demo_model", 12, 7031)
	for loc: String in Content.db.location_order:
		m.unlock("location:" + loc)
	# Garage agrandi pour la vidéo : plus de baies visibles et une place libre pour enchérir.
	var cost: int = m.garage_upgrade_cost()
	if cost > 0:
		m.credits += cost
		m.act_upgrade_garage()
	m.credits += 20000
	AuctionSystem.generate_day(m)
	m.dialogue_queue.clear()
	print("TRAILER: début")
	mark("titre")
	await _shot_title()
	Game.use_model(m)
	Game.set_speed(0)
	main.start_game()
	mark("enchères")
	await _shot_auction()
	_fill_garage()
	mark("réparation")
	await _shot_repair()
	mark("peinture")
	await _shot_paint()
	mark("vente")
	await _shot_sales()
	mark("équipe")
	await _shot_staff()
	mark("équipe au travail")
	await _shot_crew()
	mark("politique")
	await _shot_policy()
	mark("labo")
	await _shot_research()
	mark("histoire")
	await _shot_story()
	mark("lieux")
	var montage: Control = await _shot_locations()
	mark("carton final")
	await _shot_end(montage)
	print("TRAILER: fin (%d images)" % Engine.get_frames_drawn())
	get_tree().quit(0)


func _shot_title() -> void:
	# Ouverture : fondu depuis le noir sur l'écran titre (sans le menu), puis le menu apparaît et on clique.
	var menu: Control = null
	for c: Node in main.title_screen.get_children():
		if c is PanelContainer:
			menu = c as Control
	if menu != null:
		menu.modulate.a = 0.0
	cursor.visible = false
	await fade_to(0.0, 0.6)
	say("trailer.hook")
	await wait(2.6)
	unsay()
	if menu != null:
		var tw: Tween = menu.create_tween()
		tw.tween_property(menu, "modulate:a", 1.0, 0.3)
	cursor.position = Vector2(300, 250)
	cursor.visible = true
	await wait(0.3)
	var b: Button = btn(main.title_screen, I18n.t("ui.menu.new_story"))
	if b != null:
		await click_at(b.get_global_rect().get_center())
	await wait(0.3)


func _shot_auction() -> void:
	var auc: AuctionScreen = main.screen("auctions") as AuctionScreen
	var best: AuctionLot = null
	for l: AuctionLot in m.lots:
		if not l.closed and l.location == "ferropolis" and not l.scanned and (best == null or l.ship.base_value(m.db) > best.ship.base_value(m.db)):
			best = l
	if best != null:
		auc.location = best.location
		auc.selected_lot = best.id
		bid_lot = best.id
	var s: GameScreen = screen_now("auctions")
	say("trailer.auction")
	await wait(1.2)
	await click(btn(s, I18n.t("ui.auction.scan", {"cost": ""}).get_slice(" ", 0)))
	await wait(1.4)
	s.force_rebuild()
	var bid: Button = find_button(s, I18n.t("ui.auction.bid_advice", {"amount": ""}).get_slice(" ", 0))
	if bid == null:
		bid = btn(s, I18n.t("ui.auction.bid", {"amount": ""}).get_slice(" ", 0))
	await click(bid)
	if best != null:
		print("TRAILER: enchère scannée=%s mise max=%d" % [best.scanned, best.player_max])
	await wait(1.6)
	unsay()


## Garage plein pour les plans d'atelier : épaves variées venues des autres lieux.
func _fill_garage() -> void:
	# Les mises automatiques de la démo réservent des baies : seule celle du plan d'enchères est gardée.
	for l: AuctionLot in m.lots:
		if not l.closed and l.player_max > 0 and l.id != bid_lot:
			l.player_max = 0
	var locs: PackedStringArray = ["opalia", "tartarus", "nebula", "kryo7"]
	var i: int = 0
	while m.free_slots(true) > 0 and i < 8:
		var w: Ship = ShipFactory.make_wreck(m, locs[i % locs.size()])
		for d: ShipDefect in w.defects:
			d.known = true
		m.ships.append(w)
		i += 1
	print("TRAILER: garage %d/%d" % [m.ships.size(), m.ship_slots()])


## Le plus beau vaisseau libre ayant un défaut connu à réparer : [vaisseau, indice du défaut].
func _repair_target() -> Array:
	var best: Array = []
	var best_v: float = -1.0
	for sh: Ship in m.ships:
		if sh.is_busy():
			continue
		for i: int in sh.defects.size():
			var d: ShipDefect = sh.defects[i]
			if d.known and d.is_open() and not d.is_busy():
				if sh.base_value(m.db) > best_v:
					best_v = sh.base_value(m.db)
					best = [sh, i]
				break
	return best


func _shot_repair() -> void:
	m.owner_job = {}
	for sh: Ship in m.ships:
		for d: ShipDefect in sh.defects:
			if d.worker == "owner":
				d.worker = ""
	var target: Array = _repair_target()
	if target.is_empty():
		print("TRAILER: aucun défaut à réparer")
		return
	var sh: Ship = target[0]
	main.selected_ship = sh.id
	var s: GameScreen = screen_now("garage")
	say("trailer.repair")
	await wait(1.0)
	await click(btn(s, I18n.t("ui.defect.repair", {"cost": ""}).get_slice(" ", 0)))
	s.force_rebuild()
	await wait(0.4)
	for i: int in 4:
		await click(btn(s, I18n.t("ui.garage.boost", {"n": ""}).get_slice(" ", 0)))
		s.force_rebuild()
		await wait(0.25)
	print("TRAILER: réparation %s, coups de main %d" % [str(m.owner_job), m.owner_boosts])
	await wait(1.0)
	unsay()


func _shot_paint() -> void:
	var sh: Ship = m.find_ship(main.selected_ship)
	if sh == null:
		return
	var s: GameScreen = screen_now("garage")
	say("trailer.paint")
	var order: PackedStringArray = ["paint_red", "paint_blue", "paint_yellow", "paint_green", "paint_purple", "paint_white", "paint_gold"]
	var wear0: float = sh.wear
	for pid: String in order:
		await move_to(cursor.position + Vector2(randf_range(-6, 6), randf_range(-3, 3)), 0.12)
		cursor.press()
		Audio.play("paint", 0.1)
		sh.paint = pid
		sh.wear = maxf(0.0, sh.wear - wear0 / float(order.size()))
		s.force_rebuild()
		await wait(0.55)
	await wait(0.6)
	unsay()


func _shot_sales() -> void:
	# Couple client / vaisseau qui accepte la première offre (-5 %) : la vente se conclut à l'écran.
	var best_c: Client = null
	var best_s: Ship = null
	var best_v: int = 0
	var best_score: int = -1
	for c: Client in m.clients:
		if not c.quest.is_empty() or not c.busy.is_empty():
			continue
		for sh: Ship in m.ships:
			if sh.is_busy():
				continue
			var v: int = Valuation.estimate_wtp(m, c, sh)
			if v <= 0:
				continue
			var ask0: int = Util.roundi_to(float(v) * 0.95, 10)
			var score: int = v + (1000000 if ask0 <= Valuation.client_wtp(m, c, sh) else 0)
			if score > best_score:
				best_score = score
				best_v = v
				best_c = c
				best_s = sh
	if best_c == null:
		print("TRAILER: aucun client")
		return
	var sales: SalesScreen = main.screen("sales") as SalesScreen
	sales.selected_client = best_c.id
	sales.preselected_ship = best_s.id
	var s: GameScreen = screen_now("sales")
	say("trailer.sales")
	await wait(1.4)
	var ask: int = Util.roundi_to(float(best_v) * 0.95, 10)
	await click(btn(s, UIKit.credits(ask)))
	s.force_rebuild()
	await wait(0.8)
	var accept: Button = find_button(s, I18n.t("ui.sales.accept"))
	if accept != null:
		await click(accept)
	print("TRAILER: vente conclue=%s" % str(m.find_ship(best_s.id) == null))
	await wait(1.6)
	unsay()


func _shot_staff() -> void:
	if m.staff.size() >= m.max_staff():
		var cost: int = m.garage_upgrade_cost()
		if cost > 0:
			m.credits += cost
			m.act_upgrade_garage()
	var s: GameScreen = screen_now("staff")
	say("trailer.staff")
	await wait(1.2)
	var n0: int = m.staff.size()
	await click(btn(s, I18n.t("ui.staff.hire", {"cost": ""}).get_slice(" ", 0)))
	print("TRAILER: embauche %d -> %d" % [n0, m.staff.size()])
	s.force_rebuild()
	await wait(1.8)
	unsay()


## Vue d'ensemble du garage en accéléré : les employés travaillent à leurs postes.
func _shot_crew() -> void:
	main.selected_ship = -1
	_fill_garage()
	screen_now("garage")
	await move_to(Vector2(431, 10), 0.6)
	var fast: Button = main.top_bar.speed_button(3)
	if fast != null:
		await click(fast)
	else:
		Game.set_speed(3)
	main.top_bar.refresh()
	say("trailer.crew")
	await wait(5.5)
	Game.set_speed(0)
	main.top_bar.refresh()
	unsay()
	await wait(0.3)
	clear_toasts()


## Politique de l'atelier : de l'honnêteté au requin, en un clic.
func _shot_policy() -> void:
	var s: GameScreen = screen_now("office")
	say("trailer.policy")
	await wait(0.8)
	var shark: Button = find_button(s, I18n.t("ui.policy.shark"))
	if shark != null:
		await click(shark)
	print("TRAILER: politique %s" % str(m.settings.get("defect_policy", "?")))
	await wait(2.0)
	unsay()
	await wait(0.2)


func _shot_research() -> void:
	var rs: ResearchScreen = main.screen("research") as ResearchScreen
	m.research_points += 60.0
	m.credits += 5000
	var avail: Array[String] = ResearchSystem.available(m)
	if not avail.is_empty():
		rs.selected_node = avail[0]
	var s: GameScreen = screen_now("research")
	say("trailer.research")
	await wait(1.2)
	await click(btn(s, I18n.t("ui.research.do")))
	print("TRAILER: recherche %s" % str(m.researched.has(rs.selected_node)))
	s.force_rebuild()
	await wait(1.6)
	unsay()


func _shot_story() -> void:
	screen_now("quests")
	say("trailer.story", true)
	main.dialogue.show_dialogue({"quest": "m1_01", "phase": "start", "lines": [
		{"speaker": "odile", "key": "dlg.m1_05.start.2"}, {"speaker": "lustre", "key": "dlg.m1_04.start.1"},
		{"speaker": "bolt", "key": "dlg.m1_04.start.3"},
	]})
	await move_to(Vector2(300, 220), 0.8)
	for pause: float in [3.6, 3.6]:
		await wait(pause)
		cursor.press()
		main.dialogue.advance()
		main.dialogue.advance()
	await wait(2.6)
	main.dialogue.advance()
	main.dialogue.advance()
	unsay()
	await wait(0.3)


## Les 5 lieux en plein écran, en fondu enchaîné, avec leur nom.
func _shot_locations() -> Control:
	clear_toasts()
	cursor.visible = false
	var show: Control = Control.new()
	show.size = Vector2(MainUI.W, MainUI.H)
	show.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(show)
	layer.move_child(show, 0)
	var name_l: Label = _big_label("", 16, UIKit.C_ACCENT)
	name_l.position = Vector2(0, 30)
	name_l.size = Vector2(MainUI.W, 20)
	say("trailer.locations")
	for loc: String in Content.db.location_order:
		var bg: TextureRect = TextureRect.new()
		bg.texture = UIKit.tex("res://assets/backgrounds/%s.png" % str(Content.db.locations[loc].get("background", "")))
		bg.size = show.size
		bg.modulate.a = 0.0
		show.add_child(bg)
		if name_l.get_parent() == null:
			show.add_child(name_l)
		show.move_child(name_l, -1)
		name_l.text = I18n.t("location.%s.name" % loc)
		var tw: Tween = bg.create_tween()
		tw.tween_property(bg, "modulate:a", 1.0, 0.3)
		await wait(1.35)
	unsay()
	var tw2: Tween = name_l.create_tween()
	tw2.tween_property(name_l, "modulate:a", 0.0, 0.25)
	return show


func _shot_end(montage: Control) -> void:
	main.close_all_modals()
	var end: Control = Control.new()
	end.size = Vector2(MainUI.W, MainUI.H)
	end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(end)
	if montage == null:
		var bg: TextureRect = TextureRect.new()
		bg.texture = UIKit.tex("res://assets/backgrounds/loc_opalia.png")
		bg.size = end.size
		end.add_child(bg)
	var strip: ColorRect = ColorRect.new()
	strip.color = Color(UIKit.C_DARK, 0.72)
	strip.position = Vector2(0, 74)
	strip.size = Vector2(MainUI.W, 122)
	end.add_child(strip)
	for y: int in [74, 195]:
		var edge: ColorRect = ColorRect.new()
		edge.color = UIKit.C_ACCENT
		edge.position = Vector2(0, y)
		edge.size = Vector2(MainUI.W, 1)
		end.add_child(edge)
	var title: Label = _big_label(I18n.t("ui.title"), 36, UIKit.C_ACCENT)
	title.add_theme_font_override("font", UIKit.display_font())
	title.add_theme_color_override("font_outline_color", UIKit.C_DARK)
	title.add_theme_constant_override("outline_size", 4)
	title.position = Vector2(0, 80)
	title.size = Vector2(MainUI.W, 42)
	end.add_child(title)
	var lines: Array[Array] = [["trailer.cta", 16, UIKit.C_TEXT, 128], ["trailer.features", 8, UIKit.C_TEXT, 156], ["trailer.langs", 8, UIKit.C_DIM, 174]]
	for ln: Array in lines:
		var l: Label = _big_label(I18n.t(str(ln[0])), int(ln[1]), ln[2] as Color)
		l.position = Vector2(0, float(ln[3]))
		l.size = Vector2(MainUI.W, 20)
		end.add_child(l)
	end.modulate.a = 0.0
	var tw: Tween = end.create_tween()
	tw.tween_property(end, "modulate:a", 1.0, 0.6)
	await wait(4.4)
	Audio.stop_music(1.2)
	await wait(0.6)
	await fade_to(1.0, 0.6)
	await wait(0.4)
	Audio.stop_all()
	await wait(0.2)


## Curseur du jeu (CursorKit) dessiné en pixels : le Movie Maker n'enregistre pas le curseur matériel.
class FakeCursor extends Control:
	var _press: float = 0.0
	var _arrow: PackedStringArray = CursorKit.pattern("arrow")
	var _colors: Dictionary = CursorKit.colors()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(_arrow[0].length(), _arrow.size())

	func press() -> void:
		_press = 1.0

	func _process(delta: float) -> void:
		if _press > 0.0:
			_press = maxf(0.0, _press - delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		if _press > 0.0:
			var r: float = 3.0 + (1.0 - _press) * 6.0
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, Color(UIKit.C_ACCENT, _press), 1.0)
		var off: Vector2 = Vector2(1, 1) if _press > 0.5 else Vector2.ZERO
		for y: int in _arrow.size():
			var row: String = _arrow[y]
			for x: int in row.length():
				var ch: String = row[x]
				if _colors.has(ch):
					draw_rect(Rect2(off + Vector2(x, y), Vector2.ONE), _colors[ch] as Color)
