class_name GarageScreen
extends GameScreen
## Garage en vue en coupe : baies (3 par étage, mezzanines ajoutées avec l'agrandissement), vaisseaux
## composés et peints, employés en pied à leur poste (baies, bureaux et labo de l'étage, coin pause),
## travail du patron (« Coup de main ») et fiche détaillée.
## La scène (baies, vaisseaux, employés) est posée dans les coordonnées du décor (garage.png, 480×270) et
## agrandie d'un nombre entier de pixels d'écran par pixel d'image, la plus grande échelle qui tient ;
## plaques, cadre du patron et fiche restent à la taille de l'interface, par-dessus.

const COLS: int = 3
const BAY_W: int = 156
## Hauteur des baies selon le nombre d'étages de baies (1 à 3) : resserrée pour garder l'étage visible.
const BAY_H_BY_ROWS: Array[int] = [72, 65, 62]
## Largeur minimale de la fiche du vaisseau (pixels d'interface) ; elle s'élargit avec l'écran.
const DETAIL_W: int = 206
const ART_SIZE: Vector2 = Vector2(480, 270)
## Bande du décor toujours visible (entre les barres du haut et du bas à 480×270).
const ART_VIEW: Rect2 = Rect2(0, 20, 480, 230)
## Base de la grille des baies (coordonnées du décor).
const FLOOR_Y: int = 248
## Mezzanine du décor (coordonnées du décor) : plancher où se tiennent les employés de l'étage, et bande
## recopiée au-dessus des baies quand trois étages de baies la recouvrent.
const MEZZ_FLOOR: int = 111
const MEZZ_STRIP: Rect2i = Rect2i(0, 84, 480, 28)
## Barre du garde-corps de la mezzanine (redessinée devant le corps des employés de l'étage).
const MEZZ_RAIL: Rect2i = Rect2i(0, 99, 480, 5)
## Places de l'étage, [x du centre, regard à gauche], alignées sur le mobilier du décor : bureau des
## acheteurs et des vendeurs, labo des chercheurs, coin pause (machine à café, casiers).
const SPOTS: Dictionary = {
	"buy": [[132, true], [57, false]],
	"sell": [[96, false], [115, true], [22, false], [150, true]],
	"lab": [[225, false], [283, true], [195, false], [254, true]],
	"break": [[338, false], [359, true], [388, false], [408, true], [428, false], [446, true]],
}
## Étendue horizontale de chaque coin de l'étage (places supplémentaires décalées à l'intérieur).
const ZONE_X: Dictionary = {"buy": [14, 156], "sell": [14, 156], "lab": [180, 300], "break": [326, 452]}
const ZONE_ORDER: Array[String] = ["buy", "sell", "lab", "break"]

var _detail_scroll_key: String = "detail"
var _rows: int = 1
## id du vaisseau → [rect de la baie, rect du vaisseau] (placement des mécaniciens et carrossiers).
var _ship_rects: Dictionary = {}
## Scène agrandie (coordonnées du décor) et son échelle (pixels d'interface par pixel d'image).
var _stage: Control = null
var _stage_scale: float = 1.0


func background() -> Array:
	return ["res://assets/backgrounds/garage.png", 0.0]


## Échelle de la scène : la bande utile du décor tient entière dans l'écran.
func stage_scale() -> float:
	return ViewScale.fit_scale(size, ART_VIEW.size, MainUI.K)


## Position (dans cet écran) du coin du décor : bande utile centrée.
func stage_origin() -> Vector2:
	var sc: float = stage_scale()
	return ViewScale.snap((size - ART_VIEW.size * sc) / 2.0 - ART_VIEW.position * sc, MainUI.K)


## Le décor du fond (dessiné par MainUI) est cadré exactement sous la scène.
func art_rect() -> Rect2:
	var offset: Vector2 = global_position - main.global_position if main != null else Vector2.ZERO
	return Rect2(offset + stage_origin(), ART_SIZE * stage_scale())


## Point de la scène (coordonnées du décor) → position dans cet écran (pixels d'interface).
func to_screen(p: Vector2) -> Vector2:
	return _stage.position + p * _stage_scale


func bay_h() -> int:
	return BAY_H_BY_ROWS[clampi(_rows, 1, BAY_H_BY_ROWS.size()) - 1]


## Rectangle d'une baie, en coordonnées du décor.
func bay_rect(i: int) -> Rect2:
	var row: int = i / COLS
	var col: int = i % COLS
	return Rect2(4 + col * (BAY_W + 2), FLOOR_Y - (row + 1) * (bay_h() + 2), BAY_W, bay_h())


## Largeur de la fiche du vaisseau : un tiers de l'écran, entre 206 et 320 pixels d'interface.
func detail_w() -> int:
	return clampi(int(size.x * 0.3), DETAIL_W, 320)


func stage_place(c: Control, rect: Rect2) -> Control:
	c.position = rect.position
	c.size = rect.size
	_stage.add_child(c)
	return c


func rebuild() -> void:
	UIKit.clear(self)
	_ship_rects.clear()
	_stage_scale = stage_scale()
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.position = stage_origin()
	_stage.size = ART_SIZE
	_stage.scale = Vector2(_stage_scale, _stage_scale)
	add_child(_stage)
	if main != null and visible:
		main.place_background()
	var gm: GameModel = m()
	var slots: int = gm.ship_slots()
	_rows = clampi(ceili(float(slots) / float(COLS)), 1, 3)
	if _rows >= 3:
		_upper_floor_backdrop()
	for r: int in range(1, _rows):
		_mezzanine(r)
	for i: int in slots:
		var s: Ship = gm.ships[i] if i < gm.ships.size() else null
		_bay(i, s)
	for i: int in range(slots, gm.ships.size()):
		_bay(i, gm.ships[i])
	var box: Control = _owner_box()
	_workers(box)
	move_child(box, get_child_count() - 1)
	_crew_chip()
	var sel: Ship = gm.find_ship(main.selected_ship)
	if sel != null:
		_detail(sel)


# --- Décor ---------------------------------------------------------------------

## Bord inférieur (exclu) des personnages de l'étage : plancher de la mezzanine du décor, ou bande
## recopiée au-dessus du dernier étage de baies quand celles-ci recouvrent la mezzanine.
func _office_floor() -> int:
	if _rows >= 3:
		return int(bay_rect(COLS * (_rows - 1)).position.y) - 1
	return MEZZ_FLOOR + 1


## Trois étages de baies : le dernier recouvre la mezzanine du décor. On l'habille comme l'étage du
## dessous (fond recopié) et on recopie la mezzanine (bureaux, labo, coin pause) au-dessus.
func _upper_floor_backdrop() -> void:
	var tex: Texture2D = UIKit.tex("res://assets/backgrounds/garage.png")
	var src: Rect2 = bay_rect(COLS)
	var top: Rect2 = bay_rect(COLS * 2)
	_atlas(tex, Rect2(0, src.position.y - 1, ART_SIZE.x, src.size.y + 2), Vector2(0, top.position.y - 1))
	var strip_y: int = _office_floor() - 1 - (MEZZ_FLOOR - MEZZ_STRIP.position.y)
	_atlas(tex, Rect2(MEZZ_STRIP), Vector2(MEZZ_STRIP.position.x, strip_y))


func _atlas(tex: Texture2D, region: Rect2, at: Vector2) -> void:
	var a: AtlasTexture = AtlasTexture.new()
	a.atlas = tex
	a.region = region
	var r: TextureRect = TextureRect.new()
	r.texture = a
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_place(r, Rect2(at, region.size))


func _mezzanine(row: int) -> void:
	var y: float = FLOOR_Y - row * (bay_h() + 2) - 3
	var deck: ColorRect = ColorRect.new()
	deck.color = UIKit.C_SLATE
	deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_place(deck, Rect2(0, y, ART_SIZE.x, 5))
	var edge: ColorRect = ColorRect.new()
	edge.color = Color("#8a8fa6")
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_place(edge, Rect2(0, y, ART_SIZE.x, 1))
	for k: int in 12:
		var stripe: ColorRect = ColorRect.new()
		stripe.color = Color("#e0a42a") if k % 2 == 0 else UIKit.C_DARK
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_place(stripe, Rect2(k * 40, y + 2, 20, 2))
	for c: int in COLS + 1:
		var pillar: ColorRect = ColorRect.new()
		pillar.color = Color("#4a4d66")
		pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_place(pillar, Rect2(1 + c * (BAY_W + 2), y + 5, 3, bay_h() - 2))


func _bay(i: int, s: Ship) -> void:
	var r: Rect2 = bay_rect(mini(i, 8))
	var gm: GameModel = m()
	var selected: bool = s != null and s.id == main.selected_ship
	var frame: BayFrame = BayFrame.new()
	frame.selected = selected
	frame.empty = s == null
	stage_place(frame, r)
	if s == null:
		var hint: Label = UIKit.label(t("ui.garage.empty_bay"), UIKit.C_DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bottom: Vector2 = to_screen(Vector2(r.position.x, r.end.y))
		place(hint, Rect2(bottom.x, bottom.y - 16, r.size.x * _stage_scale, 10))
		clickable(frame, func() -> void: main.show_screen("auctions"))
		frame.tooltip_text = t("ui.garage.empty_tip")
		return
	var v: ShipView = ShipView.new()
	v.setup(s, db())
	v.bob = not s.is_busy()
	var vx: float = r.position.x + floorf((r.size.x - v.size.x) / 2.0)
	var vy: float = r.end.y - 5 - v.size.y
	if vy < r.position.y + 10:
		# Grand vaisseau dans une baie resserrée : posé au sol, quitte à passer sous la plaque.
		vy = maxf(r.position.y + 2, r.end.y - v.size.y)
	v.position = Vector2(vx, vy)
	# 2.5D : ombre douce du vaisseau sur le sol de la baie.
	v.floor_y = r.end.y - 3.0 - vy
	_stage.add_child(v)
	_ship_rects[s.id] = [r, Rect2(v.position, v.size)]
	clickable(frame, func() -> void:
		main.selected_ship = s.id
		dirty = true)
	frame.tooltip_text = "%s — %s" % [s.name, t("class.%s" % s.ship_class(db()))]
	# Plaque : nom + icônes d'état
	var plate: HBoxContainer = UIKit.hbox([], 1)
	var name_l: Label = UIKit.label(s.name, UIKit.C_ACCENT if selected else UIKit.C_TEXT)
	plate.add_child(name_l)
	var known: int = s.known_open_defects().size()
	if known > 0:
		plate.add_child(UIKit.icon_rect("ui_warning", 10))
		plate.add_child(UIKit.label(str(known), UIKit.C_ORANGE))
	if s.for_sale:
		plate.add_child(UIKit.icon_rect("ui_sell", 10))
	if not s.item.is_empty() or s.rare:
		plate.add_child(UIKit.icon_rect("ui_star", 10))
	var plate_p: PanelContainer = UIKit.panel(plate, "DarkPanel")
	plate_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate_p)
	plate_p.position = to_screen(r.position) + Vector2(2, 1)
	# Travail en cours : barre + travailleur
	var job: Dictionary = _ship_job(s)
	if not job.is_empty():
		var jr: HBoxContainer = UIKit.hbox([], 2)
		var worker: String = str(job["worker"])
		if worker != "owner":
			var e: Employee = gm.find_employee(worker)
			if e != null:
				var ri: TextureRect = UIKit.icon_rect("role_" + e.role, 16)
				ri.tooltip_text = e.name
				jr.add_child(ri)
		jr.add_child(UIKit.icon_rect(str(job["icon"]), 16))
		var col: Color = UIKit.C_ORANGE if str(job["icon"]) == "ui_conceal" else UIKit.C_GOOD
		jr.add_child(UIKit.bar(float(job["done"]), float(job["total"]), col, 44, 4))
		var jp: PanelContainer = UIKit.panel(jr, "DarkPanel")
		jp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(jp)
		jp.reset_size()
		jp.position = to_screen(Vector2(r.end.x, r.position.y)) + Vector2(-jp.size.x - 2, 1)


## {worker, icon, done, total} du travail en cours sur le vaisseau, ou {}.
func _ship_job(s: Ship) -> Dictionary:
	for d: ShipDefect in s.defects:
		if d.is_busy():
			return {"worker": d.worker, "icon": "ui_conceal" if d.work_kind == "conceal" else "ui_repair", "done": d.progress, "total": Valuation.job_work(m(), d, d.work_kind)}
	if not s.custom_job.is_empty() and not str(s.custom_job.get("worker", "")).is_empty():
		return {"worker": str(s.custom_job["worker"]), "icon": "ui_paint", "done": float(s.custom_job.get("done", 0.0)), "total": float(s.custom_job.get("work", 1.0))}
	return {}


func _owner_box() -> Control:
	var gm: GameModel = m()
	var v: VBoxContainer = UIKit.vbox([], 1)
	var head: HBoxContainer = UIKit.hbox([UIKit.label(t("ui.garage.you"), UIKit.C_ACCENT)], 3)
	var job_text: String = t("ui.garage.owner_free")
	var prog: Array[float] = WorkshopSystem.owner_progress(gm)
	if not gm.owner_job.is_empty():
		var s: Ship = gm.find_ship(int(gm.owner_job.get("ship", -1)))
		var idx: int = int(gm.owner_job.get("defect", -1))
		if s != null and str(gm.owner_job.get("kind", "")) == "defect" and idx >= 0 and idx < s.defects.size():
			var d: ShipDefect = s.defects[idx]
			job_text = t("ui.garage.owner_" + ("conceal" if d.work_kind == "conceal" else "repair"), {"defect": t("defect.%s.name" % d.type), "ship": s.name})
		elif s != null:
			job_text = t("ui.garage.owner_custom", {"ship": s.name})
	if not gm.is_owner_hour():
		job_text = t("ui.garage.owner_sleep")
	head.add_child(UIKit.label(job_text, UIKit.C_TEXT))
	v.add_child(head)
	var row: HBoxContainer = UIKit.hbox([], 3)
	if prog.size() == 2:
		row.add_child(UIKit.bar(prog[0], prog[1], UIKit.C_GOOD, 70, 5))
	var boosts_left: int = gm.db.cfgi("time", "owner_boosts_per_hour", 6) - gm.owner_boosts
	var b: Button = UIKit.button(t("ui.garage.boost", {"n": boosts_left}), func() -> void:
		act(m().act_boost()), "ui_repair", t("ui.garage.boost_tip"))
	b.disabled = gm.owner_job.is_empty() or boosts_left <= 0
	row.add_child(b)
	row.add_child(UIKit.label(t("ui.garage.capacity", {"n": gm.ships.size(), "max": gm.ship_slots(), "level": gm.garage_level}), UIKit.C_DIM))
	v.add_child(row)
	var p: PanelContainer = UIKit.panel(v, "DarkPanel")
	add_child(p)
	p.position = Vector2(2, 2)
	p.reset_size()
	return p


# --- Employés -------------------------------------------------------------------------

## Employés en service dessinés à leur place (StaffLayout) : dans la baie du vaisseau qu'ils réparent ou
## peignent, ou à l'étage (bureau, labo, coin pause). Personne hors des heures de service.
func _workers(owner_box: Control) -> void:
	var gm: GameModel = m()
	var upstairs: Array[Dictionary] = []
	for p: Dictionary in StaffLayout.placements(gm):
		var e: Employee = gm.find_employee(str(p["employee"]))
		if e == null:
			continue
		if str(p["zone"]) == "bay":
			_bay_worker(e, p)
		else:
			p["e"] = e
			upstairs.append(p)
	if upstairs.is_empty():
		return
	var feet: int = _office_floor()
	if _rows >= 3:
		_strip_workers(upstairs, feet, owner_box)
		return
	for p: Dictionary in upstairs:
		var zone: String = str(p["zone"])
		var spots: Array = SPOTS[zone]
		var k: int = int(p["slot"])
		var spot: Array = spots[k % spots.size()]
		var extra: int = k / spots.size()
		# Places supplémentaires : décalées de 7 pixels, alternativement à droite et à gauche.
		var x: int = int(spot[0]) + (7 if extra % 2 == 1 else -7) * ((extra + 1) / 2)
		var span: Array = ZONE_X[zone]
		x = clampi(x, int(span[0]) + WorkerView.W / 2, int(span[1]) - WorkerView.W / 2)
		var wv: WorkerView = _add_worker(p["e"] as Employee, str(p["activity"]), bool(spot[1]), Vector2(x - WorkerView.W / 2, feet - WorkerView.H))
		_behind_rail(wv)


## Trois étages de baies : l'étage est une bande recopiée en haut de l'écran, en partie cachée par le
## cadre du patron ; les employés de l'étage s'y alignent à droite de ce cadre, regroupés par coin
## (bureau, labo, pause) et se faisant face deux à deux.
func _strip_workers(upstairs: Array[Dictionary], feet: int, owner_box: Control) -> void:
	upstairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var za: int = ZONE_ORDER.find(str(a["zone"]))
		var zb: int = ZONE_ORDER.find(str(b["zone"]))
		return za < zb or (za == zb and int(a["slot"]) < int(b["slot"])))
	var box_right: float = (owner_box.position.x + owner_box.size.x - _stage.position.x) / _stage_scale
	var x0: int = maxi(0, ceili(box_right)) + 4 + WorkerView.W / 2
	var x1: int = int(ART_SIZE.x) - 4 - WorkerView.W / 2
	var n: int = upstairs.size()
	var changes: int = 0
	for k: int in range(1, n):
		if str(upstairs[k]["zone"]) != str(upstairs[k - 1]["zone"]):
			changes += 1
	var gap: float = clampf(float(x1 - x0) / maxf(1.0, float(n - 1) + 0.75 * float(changes)), 8.0, 24.0)
	var x: float = float(x0)
	for k: int in n:
		var p: Dictionary = upstairs[k]
		if k > 0:
			x += gap * (1.75 if str(p["zone"]) != str(upstairs[k - 1]["zone"]) else 1.0)
		var cx: int = mini(roundi(x), x1)
		var wv: WorkerView = _add_worker(p["e"] as Employee, str(p["activity"]), k % 2 == 1, Vector2(cx - WorkerView.W / 2, feet - WorkerView.H))
		_behind_rail(wv)


## Haut (dans cet écran) de la barre du garde-corps de l'étage.
func _rail_top() -> int:
	return _office_floor() - 1 - (MEZZ_FLOOR - MEZZ_RAIL.position.y)


func _behind_rail(wv: WorkerView) -> void:
	var a: AtlasTexture = AtlasTexture.new()
	a.atlas = UIKit.tex("res://assets/backgrounds/garage.png")
	a.region = Rect2(wv.position.x, MEZZ_RAIL.position.y, WorkerView.W, MEZZ_RAIL.size.y)
	wv.rail = a
	wv.rail_y = _rail_top() - int(wv.position.y)


## Mécanicien ou carrossier : au sol de la baie, aux extrémités du vaisseau puis vers son centre,
## tourné vers lui.
func _bay_worker(e: Employee, p: Dictionary) -> void:
	var rects: Array = _ship_rects.get(int(p["ship"]), [])
	if rects.is_empty():
		return
	var r: Rect2 = rects[0]
	var sr: Rect2 = rects[1]
	var k: int = int(p["slot"])
	var left_side: bool = k % 2 == 0
	var depth: float = float(k / 2) * 15.0
	var cx: float = sr.position.x + 9.0 + depth if left_side else sr.end.x - 9.0 - depth
	cx = clampf(cx, r.position.x + WorkerView.W / 2 + 1, r.end.x - WorkerView.W / 2 - 1)
	var wv: WorkerView = _add_worker(e, str(p["activity"]), not left_side, Vector2(roundi(cx) - WorkerView.W / 2, roundi(r.end.y) - WorkerView.H))
	var s: Ship = m().find_ship(int(p["ship"]))
	if s != null and str(p["activity"]) == "paint":
		var pid: String = str(s.custom_job.get("id", s.paint)) if str(s.custom_job.get("kind", "")) == "paint" else s.paint
		wv.paint_color = ShipView.paint_ramp(db(), pid)[1]


func _add_worker(e: Employee, activity: String, face_left: bool, pos: Vector2) -> WorkerView:
	var gm: GameModel = m()
	var wv: WorkerView = WorkerView.new()
	wv.setup(e.id, e.portrait, activity, face_left)
	wv.tired = e.fatigue >= 70.0
	wv.position = pos.round()
	wv.tooltip_text = "%s — %s %s\n%s\n%s %d %% · %s %d %%" % [e.name, t("role.%s.name" % e.role), t("ui.staff.level", {"n": e.level}),
		StaffScreen.status_text(gm, e), t("ui.staff.fatigue"), roundi(e.fatigue), t("ui.staff.morale"), roundi(e.morale)]
	wv.pressed.connect(func() -> void: main.show_screen("staff"))
	_stage.add_child(wv)
	return wv


## Hors des heures de service, l'équipe est absente : une étiquette le rappelle (clic : écran Équipe).
func _crew_chip() -> void:
	var gm: GameModel = m()
	if gm.staff.is_empty() or gm.is_shift_hour():
		return
	var row: HBoxContainer = UIKit.hbox([UIKit.icon_rect("ui_staff", 10), UIKit.label(t("ui.garage.crew_off", {"hour": gm.db.cfgi("time", "shift_start", 8)}), UIKit.C_DIM)], 2)
	var p: PanelContainer = UIKit.panel(row, "DarkPanel")
	add_child(p)
	p.reset_size()
	p.position = Vector2(size.x - p.get_combined_minimum_size().x - 2, 2)
	clickable(p, func() -> void: main.show_screen("staff"))


# --- Fiche du vaisseau -------------------------------------------------------------

func _detail(s: Ship) -> void:
	var gm: GameModel = m()
	var v: VBoxContainer = UIKit.vbox([], 2)
	var head: HBoxContainer = UIKit.hbox([UIKit.label(s.name, UIKit.C_ACCENT)], 2)
	head.add_child(UIKit.spacer(0, 0, true))
	head.add_child(UIKit.button("×", func() -> void:
		main.selected_ship = -1
		dirty = true))
	v.add_child(head)
	v.add_child(UIKit.label("%s · %s · %s" % [t("class.%s" % s.ship_class(db())), t("ui.tier", {"n": s.tier(db())}), t("paint.%s" % s.paint)], UIKit.C_DIM))
	var preview: CenterContainer = CenterContainer.new()
	var sv: ShipView = ShipView.new()
	sv.setup(s, db())
	var zoom: int = UIKit.art_zoom()
	while zoom > 1 and sv.size.x * zoom > detail_w() - 16:
		zoom -= 1
	preview.add_child(UIKit.zoomed(sv, zoom))
	v.add_child(preview)
	var dw: int = detail_w()
	var parts: Label = UIKit.wrap_label("%s / %s / %s / %s" % [t("part.%s.name" % s.hull), t("part.%s.name" % s.engine), t("part.%s.name" % s.cockpit), t("part.%s.name" % s.wings)], dw - 16, UIKit.C_DIM)
	v.add_child(parts)
	var val: GridContainer = GridContainer.new()
	val.columns = 2
	val.add_theme_constant_override("h_separation", 6)
	val.add_child(UIKit.label(t("ui.garage.value"), UIKit.C_DIM))
	val.add_child(UIKit.label(UIKit.credits(int(Valuation.apparent_value(gm, s)))))
	val.add_child(UIKit.label(t("ui.garage.invested"), UIKit.C_DIM))
	val.add_child(UIKit.label("%s + %s" % [UIKit.credits(s.purchase_price), UIKit.credits(s.invested)]))
	val.add_child(UIKit.label(t("ui.garage.wear"), UIKit.C_DIM))
	var wear_row: HBoxContainer = UIKit.hbox([UIKit.bar(s.wear, 1.0, UIKit.C_ORANGE, 50, 4), UIKit.label(pct(s.wear))], 3)
	val.add_child(wear_row)
	v.add_child(val)
	# Défauts
	v.add_child(section(t("ui.garage.defects")))
	if not s.scanned:
		v.add_child(UIKit.wrap_label(t("ui.garage.not_scanned"), dw - 16, UIKit.C_DIM))
	var any: bool = false
	for i: int in s.defects.size():
		var d: ShipDefect = s.defects[i]
		if not d.known:
			continue
		any = true
		v.add_child(_defect_row(s, d, i))
	if not any:
		v.add_child(UIKit.label(t("ui.garage.no_defect"), UIKit.C_GOOD))
	# Personnalisation
	v.add_child(section(t("ui.garage.custom")))
	if not s.custom_job.is_empty():
		v.add_child(UIKit.hbox([UIKit.icon_rect("ui_paint"), UIKit.label(t("ui.garage.custom_running")), UIKit.bar(float(s.custom_job.get("done", 0.0)), float(s.custom_job.get("work", 1.0)), UIKit.C_GOOD, 50, 4)], 2))
	var paints: HFlowContainer = HFlowContainer.new()
	paints.add_theme_constant_override("h_separation", 1)
	paints.add_theme_constant_override("v_separation", 1)
	for pid: String in db().paints:
		if not gm.is_unlocked("paint:" + pid) or pid == "paint_primer":
			continue
		paints.add_child(_paint_button(s, pid))
	v.add_child(paints)
	var opts: HFlowContainer = HFlowContainer.new()
	opts.add_theme_constant_override("h_separation", 1)
	opts.add_theme_constant_override("v_separation", 1)
	for oid: String in db().options:
		if not gm.is_unlocked("option:" + oid):
			continue
		opts.add_child(_option_button(s, oid))
	v.add_child(opts)
	# Vente
	v.add_child(section(t("ui.garage.sale")))
	var sale: HFlowContainer = HFlowContainer.new()
	sale.add_theme_constant_override("h_separation", 2)
	sale.add_theme_constant_override("v_separation", 2)
	sale.add_child(UIKit.button(t("ui.garage.unlist") if s.for_sale else t("ui.garage.list"), func() -> void: act(m().act_list(s.id, not s.for_sale)), "ui_sell"))
	sale.add_child(UIKit.button(t("ui.garage.find_client"), func() -> void:
		main.show_screen("sales")
		(main.screen("sales") as SalesScreen).preselect_ship(s.id)))
	var scrap_value: int = int(round(s.base_value(db()) * 0.2))
	sale.add_child(UIKit.button(t("ui.garage.scrap", {"price": UIKit.credits(scrap_value)}), func() -> void:
		main.confirm(t("ui.garage.scrap_confirm", {"ship": s.name, "price": UIKit.credits(scrap_value)}), func() -> void:
			main.selected_ship = -1
			act(m().act_scrap(s.id)))))
	v.add_child(sale)
	var p: PanelContainer = UIKit.panel(v, "DarkPanel")
	var sc: ScrollContainer = make_scroll(_detail_scroll_key, p, Rect2(size.x - dw - 2, 2, dw, size.y - 4))
	sc.get_v_scroll_bar().custom_minimum_size = Vector2(4, 0)


func _defect_row(s: Ship, d: ShipDefect, i: int) -> Control:
	var gm: GameModel = m()
	var def: Dictionary = db().defects.get(d.type, {})
	var v: VBoxContainer = UIKit.vbox([], 1)
	var top: HBoxContainer = UIKit.hbox([UIKit.icon_rect(str(def.get("icon", "ui_warning")))], 2)
	var name_col: Color = UIKit.C_BAD if bool(def.get("danger", false)) else UIKit.C_TEXT
	top.add_child(UIKit.label(t("defect.%s.name" % d.type), name_col))
	top.add_child(UIKit.label(UIKit.sev_dots(d.sev), UIKit.C_ORANGE))
	top.add_child(UIKit.spacer(0, 0, true))
	match d.state:
		"repaired":
			top.add_child(UIKit.label(t("ui.defect.repaired"), UIKit.C_GOOD))
		"concealed":
			top.add_child(UIKit.label(t("ui.defect.concealed"), UIKit.C_ORANGE))
	top.tooltip_text = t("defect.%s.desc" % d.type) + ("\n" + t("ui.defect.danger") if bool(def.get("danger", false)) else "")
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(top)
	if d.is_open():
		var row: HBoxContainer = UIKit.hbox([], 2)
		if d.is_busy():
			var who: String = t("ui.garage.you") if d.worker == "owner" else EventText._employee_name(d.worker)
			row.add_child(UIKit.label(who, UIKit.C_DIM))
			row.add_child(UIKit.bar(d.progress, Valuation.job_work(gm, d, d.work_kind), UIKit.C_ORANGE if d.work_kind == "conceal" else UIKit.C_GOOD, 60, 4))
		else:
			var rc: int = Valuation.repair_cost(gm, s, d)
			var rb: Button = UIKit.button(t("ui.defect.repair", {"cost": UIKit.credits(rc)}), func() -> void: act(m().act_repair(s.id, i, "repair")), "", t("ui.defect.repair_tip", {"hours": "%.1f" % (Valuation.repair_work(gm, d) / gm.stat("owner_speed") / gm.stat("repair_speed"))}))
			row.add_child(rb)
			if bool(def.get("concealable", true)):
				var cc: int = Valuation.conceal_cost(gm, s, d)
				row.add_child(UIKit.button(t("ui.defect.conceal", {"cost": UIKit.credits(cc)}), func() -> void: act(m().act_repair(s.id, i, "conceal")), "", t("ui.defect.conceal_tip")))
			var ob: OptionButton = OptionButton.new()
			ob.focus_mode = Control.FOCUS_NONE
			ob.fit_to_longest_item = false
			var decisions: PackedStringArray = ["auto", "repair", "conceal", "disclose"]
			for k: int in decisions.size():
				if decisions[k] == "conceal" and not bool(def.get("concealable", true)):
					continue
				ob.add_item(t("ui.decision." + decisions[k]), k)
			ob.select(ob.get_item_index(decisions.find(d.decision)))
			ob.tooltip_text = t("ui.decision.tip")
			ob.item_selected.connect(func(idx: int) -> void: act(m().act_set_decision(s.id, i, decisions[ob.get_item_id(idx)])))
			row.add_child(ob)
		v.add_child(row)
	return v


func _paint_button(s: Ship, pid: String) -> Control:
	var ramp: Array[Color] = ShipView.paint_ramp(db(), pid)
	var b: Button = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(14, 14)
	var sw: ColorRect = UIKit.color_swatch(ramp[1], 8)
	sw.position = Vector2(3, 3)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sw)
	var cost: int = Valuation.paint_cost(m(), s)
	b.tooltip_text = t("ui.garage.paint_tip", {"paint": t("paint.%s" % pid), "cost": UIKit.credits(cost)})
	b.disabled = s.paint == pid
	b.pressed.connect(func() -> void: act(m().act_customize(s.id, "paint", pid)))
	return b


func _option_button(s: Ship, oid: String) -> Control:
	var o: Dictionary = db().options.get(oid, {})
	var b: Button = UIKit.button("", func() -> void: act(m().act_customize(s.id, "option", oid)), str(o.get("icon", oid)))
	var cost: int = Valuation.option_cost(m(), oid)
	b.tooltip_text = "%s — %s\n%s" % [t("option.%s.name" % oid), UIKit.credits(cost), t("option.%s.desc" % oid)]
	if oid in s.options:
		b.disabled = true
		b.tooltip_text += "\n" + t("ui.garage.installed")
	return b


## Cadre de baie : survol et sélection dessinés en pixels.
class BayFrame extends Control:
	var selected: bool = false
	var empty: bool = false
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		if empty:
			draw_rect(r.grow(-1), Color(UIKit.C_DARK, 0.35), true)
			_dashes(r.grow(-1), Color(UIKit.C_DIM, 0.8))
		if selected:
			draw_rect(r.grow(-0.5), UIKit.C_ACCENT, false, 1.0)
		elif _hover:
			draw_rect(r.grow(-0.5), Color(UIKit.C_TEXT, 0.6), false, 1.0)

	func _dashes(r: Rect2, c: Color) -> void:
		var x: float = r.position.x
		while x < r.end.x:
			draw_rect(Rect2(x, r.position.y, 3, 1), c)
			draw_rect(Rect2(x, r.end.y - 1, 3, 1), c)
			x += 6.0
		var y: float = r.position.y
		while y < r.end.y:
			draw_rect(Rect2(r.position.x, y, 1, 3), c)
			draw_rect(Rect2(r.end.x - 1, y, 1, 3), c)
			y += 6.0
