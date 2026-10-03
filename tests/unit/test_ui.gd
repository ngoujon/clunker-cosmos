extends TestCase
## Interface : toutes les clés de texte utilisées existent (FR+EN), libellés des catégories, raisons
## d'échec et statistiques ; phrases d'événements complètes ; composition des vaisseaux.

const UI_DIRS: PackedStringArray = ["res://scripts/ui", "res://scripts/ui/screens"]
const CORE_DIR: String = "res://scripts/core"


func _sources(dirs: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for d: String in dirs:
		for f: String in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				out[d + "/" + f] = FileAccess.get_file_as_string(d + "/" + f)
	return out


func _has(key: String) -> bool:
	return db.texts.has(key)


func test_literal_ui_keys_exist() -> void:
	var re: RegEx = RegEx.create_from_string("\"((?:ui|reason|stat)\\.[a-z0-9_.]+)\"")
	var missing: Array[String] = []
	var n: int = 0
	var srcs: Dictionary = _sources(UI_DIRS)
	for path: String in srcs:
		var src: String = srcs[path]
		for mt: RegExMatch in re.search_all(src):
			var key: String = mt.get_string(1)
			if key.ends_with(".") or key.ends_with("_"):
				continue
			n += 1
			if not _has(key) and not key in missing:
				missing.append(key)
	gt(float(n), 200.0, "clés littérales trouvées")
	eq(missing.size(), 0, "clés d'interface manquantes : %s" % str(missing))


func test_failure_reasons_have_texts() -> void:
	var re: RegEx = RegEx.create_from_string("fail\\(\"([a-z_]+)\"\\)")
	var missing: Array[String] = []
	var srcs: Dictionary = _sources(PackedStringArray([CORE_DIR]))
	for path: String in srcs:
		for mt: RegExMatch in re.search_all(str(srcs[path])):
			var key: String = "reason." + mt.get_string(1)
			if not _has(key) and not key in missing:
				missing.append(key)
	for r: String in ["unknown", "done", "prereq", "rp", "credits"]:
		if not _has("reason." + r):
			missing.append("reason." + r)
	eq(missing.size(), 0, "raisons sans texte : %s" % str(missing))


func test_money_categories_have_labels() -> void:
	var re: RegEx = RegEx.create_from_string("(?:earn|spend|force_spend)\\([^\\n]*?, \"([a-z_]+)\"\\)")
	var missing: Array[String] = []
	var srcs: Dictionary = _sources(PackedStringArray([CORE_DIR]))
	var found: int = 0
	for path: String in srcs:
		for mt: RegExMatch in re.search_all(str(srcs[path])):
			found += 1
			var key: String = "ui.cat." + mt.get_string(1)
			if not _has(key) and not key in missing:
				missing.append(key)
	gt(float(found), 10.0, "catégories trouvées")
	eq(missing.size(), 0, "catégories sans libellé : %s" % str(missing))


func test_stats_and_dynamic_families_have_labels() -> void:
	var missing: Array[String] = []
	for st: String in db.stats:
		if not _has("stat." + st):
			missing.append("stat." + st)
	for id: String in MainUI.SCREEN_IDS:
		for k: String in ["ui.nav." + id, "ui.nav.%s.tip" % id]:
			if not _has(k):
				missing.append(k)
	for p: String in GameModel.POLICIES:
		for k: String in ["ui.policy." + p, "ui.policy.%s.desc" % p]:
			if not _has(k):
				missing.append(k)
	for s: String in ["done", "ready", "available", "locked"]:
		if not _has("ui.research.state_" + s):
			missing.append("ui.research.state_" + s)
	for s: String in ["active", "available", "done", "failed", "locked"]:
		if not _has("ui.quests.status_" + s):
			missing.append("ui.quests.status_" + s)
	for s: String in ["auto", "repair", "conceal", "disclose"]:
		if not _has("ui.decision." + s):
			missing.append("ui.decision." + s)
	for i: int in 4:
		if not _has("ui.top.speed%d" % i):
			missing.append("ui.top.speed%d" % i)
	eq(missing.size(), 0, "libellés manquants : %s" % str(missing))


func test_event_texts_complete() -> void:
	var m: GameModel = new_model(5, true)
	var samples: Array[Dictionary] = [
		{"type": "wreck_bought", "ship": -1, "price": 1200}, {"type": "ship_sold", "ship": -1, "price": 9000, "profit": 2500},
		{"type": "sav_claim", "ship_name": "X", "defect": "d_rust", "cost": 100}, {"type": "inspection", "found": 2, "fines": 3000},
		{"type": "inspection", "found": 0, "fines": 0}, {"type": "quest_completed", "quest": "m1_01"},
		{"type": "item_found", "item": "aurora_keel"}, {"type": "chapter_started", "chapter": 2},
		{"type": "location_unlocked", "location": "kryo7"}, {"type": "debt_late", "amount": 2500, "penalty": 250},
		{"type": "defect_found", "defect": "d_misfire", "ship": -1, "cause": "repair"}, {"type": "research_done", "node": "at_1", "free": true},
	]
	var bad: Array[String] = []
	for ev: Dictionary in samples:
		var txt: String = EventText.describe(ev)
		if txt.is_empty() or txt.contains("{") or txt.begins_with("ui."):
			bad.append("%s -> '%s'" % [ev["type"], txt])
	eq(bad.size(), 0, "phrases incomplètes : %s" % str(bad))
	check(m != null)


func test_ship_view_composes_all_hulls() -> void:
	var m: GameModel = new_model(8)
	var sizes: Array[Vector2] = []
	for h: String in db.parts_by_slot["hull"]:
		var s: Ship = ShipFactory.make_wreck(m, "ferropolis")
		s.hull = h
		s.paint = "paint_red"
		var v: ShipView = ShipView.new()
		v.setup(s, db)
		sizes.append(v.custom_minimum_size)
		check(v.custom_minimum_size.x >= 40.0 and v.custom_minimum_size.y >= 20.0, "taille du vaisseau %s : %s" % [h, str(v.custom_minimum_size)])
		check(v.custom_minimum_size.x <= 160.0 and v.custom_minimum_size.y <= 72.0, "vaisseau %s trop grand pour une baie : %s" % [h, str(v.custom_minimum_size)])
		v.free()
	eq(sizes.size(), 8, "coques composées")


func test_paint_ramps_valid() -> void:
	for pid: String in db.paints:
		var ramp: Array[Color] = ShipView.paint_ramp(db, pid)
		eq(ramp.size(), 3, "rampe %s" % pid)


func test_cursor_shapes_valid() -> void:
	var cols: Dictionary = CursorKit.colors()
	for id: String in ["arrow", "hand", "help"]:
		var sh: Array[Dictionary] = CursorKit.shapes(id)
		check(not sh.is_empty(), "formes de %s" % id)
		for s: Dictionary in sh:
			check(cols.has(str(s["color"])), "couleur connue dans %s" % id)
		var sz: Vector2i = CursorKit.SIZES[id]
		var img: Image = CursorKit.image(id, 2)
		eq(img.get_size(), sz * 2, "image ×2 de %s" % id)
		var hs: Vector2i = CursorKit.HOTSPOTS[id]
		check(img.get_pixel(hs.x * 2 + 1, hs.y * 2 + 1).a > 0.3, "point actif de %s sur une partie visible" % id)
		var partial: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				var a: float = img.get_pixel(x, y).a
				if a > 0.05 and a < 0.95:
					partial += 1
		check(partial > 0, "bords lissés (anticrénelage) pour %s" % id)
		check(img.get_width() <= 256 and img.get_height() <= 256, "taille de curseur acceptée par Godot")
	eq(CursorKit.scale_for(1), 1, "interface ×1 : curseur ×1")
	eq(CursorKit.scale_for(2), 2, "interface ×2 : curseur ×2")
	eq(CursorKit.scale_for(3), 2, "interface ×3 : curseur ×2")
	eq(CursorKit.scale_for(5), 4, "interface ×5 : curseur ×4")


func test_hd_textures_logical_size() -> void:
	# Les images sont stockées à DETAIL fois leur taille logique et affichées à leur taille logique.
	var icon: Texture2D = UIKit.icon("ui_credits")
	check(icon != null, "icône chargée")
	eq(Vector2i(icon.get_size()), Vector2i(16, 16), "icône à 16×16 logiques")
	var bg: Texture2D = UIKit.tex("res://assets/backgrounds/garage.png")
	eq(Vector2i(bg.get_size()), Vector2i(480, 270), "décor à 480×270 logiques")
	var w: Texture2D = UIKit.tex("res://assets/workers/staff_01.png")
	eq(Vector2i(w.get_size()), Vector2i(20, 26), "personnage à 20×26 logiques")
	check(UIKit.tex("res://assets/ships/hull/hull_shuttle_paint.png") != null, "masque de peinture de la coque")
	var panel: StyleBox = UIKit.theme().get_stylebox("panel", "PanelContainer")
	check(panel is StyleBoxFlat and (panel as StyleBoxFlat).corner_radius_top_left > 0, "panneaux lisses arrondis")
