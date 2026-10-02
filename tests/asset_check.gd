class_name AssetCheck
extends RefCounted
## Validation des assets du jeu (headless) : présence, chargement, tailles, palette globale,
## points d'ancrage, et couverture des références du contenu (icônes, portraits, fonds).

const PALETTE_PATH: String = "res://art/palette.json"
const ANCHORS_PATH: String = "res://assets/ships/anchors.json"


static func palette() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_PATH))
	var out: Dictionary = {}
	if typeof(d) == TYPE_DICTIONARY:
		for c: Variant in (d as Dictionary).get("colors", []):
			out[str(c).to_lower()] = true
	return out


## Liste des assets requis : {chemin: {"w": .., "h": .., "kind": ..}} (w/h = 0 → libre).
static func required(db: ContentDB) -> Dictionary:
	var req: Dictionary = {}
	for slot: String in ContentDB.SLOTS:
		for id: String in db.parts_by_slot.get(slot, []):
			req["res://assets/ships/%s/%s.png" % [slot, id]] = {"kind": "part"}
	for w: String in ["wear_rust", "wear_scratch", "wear_dent", "wear_scorch"]:
		req["res://assets/ships/wear/%s.png" % w] = {"kind": "wear"}
	for sp: String in db.species:
		req["res://assets/portraits/%s.png" % str(db.species[sp]["portrait"])] = {"kind": "portrait", "w": 48, "h": 48}
	for p: String in db.staff_portraits:
		req["res://assets/portraits/%s.png" % p] = {"kind": "portrait", "w": 48, "h": 48}
	for c: String in db.characters:
		var por: String = str(db.characters[c].get("portrait", ""))
		if not por.is_empty():
			req["res://assets/portraits/%s.png" % por] = {"kind": "portrait", "w": 48, "h": 48}
	for icon: String in icon_ids(db):
		req["res://assets/icons/%s.png" % icon] = {"kind": "icon", "w": 16, "h": 16}
	req["res://assets/backgrounds/garage.png"] = {"kind": "background", "w": 480, "h": 270}
	for loc: String in db.locations:
		req["res://assets/backgrounds/%s.png" % str(db.locations[loc]["background"])] = {"kind": "background", "w": 480, "h": 270}
	for ui: String in ["panel", "panel_dark", "button", "button_hover", "button_pressed", "button_disabled", "frame"]:
		req["res://assets/ui/%s.png" % ui] = {"kind": "ui"}
	return req


static func icon_ids(db: ContentDB) -> Array[String]:
	var out: Array[String] = []
	for id: String in db.defects:
		out.append(str(db.defects[id]["icon"]))
	for id: String in db.options:
		out.append(str(db.options[id]["icon"]))
	for id: String in db.tech:
		out.append(str(db.tech[id]["icon"]))
	for b: Dictionary in db.branches:
		out.append(str(b["icon"]))
	for id: String in db.roles:
		out.append(str(db.roles[id]["icon"]))
	for id: String in db.items:
		out.append(str(db.items[id]["icon"]))
	for u: String in UI_ICONS:
		out.append(u)
	var uniq: Array[String] = []
	for i: String in out:
		if not i in uniq:
			uniq.append(i)
	return uniq


const UI_ICONS: Array[String] = [
	"ui_credits", "ui_rp", "ui_rep", "ui_debt", "ui_day", "ui_pause", "ui_play", "ui_fast", "ui_faster",
	"ui_garage", "ui_auction", "ui_staff", "ui_research", "ui_quests", "ui_sales", "ui_settings",
	"ui_scan", "ui_bid", "ui_repair", "ui_conceal", "ui_paint", "ui_sell", "ui_hire", "ui_check",
	"ui_lock", "ui_warning", "ui_star", "ui_report",
]


static func run() -> int:
	var db: ContentDB = ContentDB.load_default()
	var pal: Dictionary = palette()
	var errors: Array[String] = []
	var all_colors: Dictionary = {}
	var counts: Dictionary = {}
	var req: Dictionary = required(db)
	for path: String in req:
		var spec: Dictionary = req[path]
		var kind: String = str(spec["kind"])
		counts[kind] = int(counts.get(kind, 0)) + 1
		var abs_path: String = ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(path):
			errors.append("manquant : " + path)
			continue
		var img: Image = Image.load_from_file(abs_path)
		if img == null or img.is_empty():
			errors.append("illisible : " + path)
			continue
		if int(spec.get("w", 0)) > 0 and (img.get_width() != int(spec["w"]) or img.get_height() != int(spec["h"])):
			errors.append("taille %dx%d au lieu de %dx%d : %s" % [img.get_width(), img.get_height(), spec["w"], spec["h"], path])
		var bad: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var hx: String = "#" + c.to_html(false).to_lower()
				all_colors[hx] = true
				if not pal.has(hx):
					bad += 1
		if bad > 0:
			errors.append("%d pixels hors palette : %s" % [bad, path])
	var anchors: Variant = JSON.parse_string(FileAccess.get_file_as_string(ANCHORS_PATH)) if FileAccess.file_exists(ANCHORS_PATH) else null
	if typeof(anchors) != TYPE_DICTIONARY:
		errors.append("anchors.json manquant ou invalide")
	else:
		for slot: String in ContentDB.SLOTS:
			for id: String in db.parts_by_slot.get(slot, []):
				if not (anchors as Dictionary).has(id):
					errors.append("points d'ancrage manquants : " + id)
	if all_colors.size() > 32:
		errors.append("palette globale > 32 couleurs (%d)" % all_colors.size())
	var result: Dictionary = {"assets": req.size(), "counts": counts, "colors": all_colors.size(), "errors": errors.slice(0, 40), "error_count": errors.size()}
	for e: String in errors.slice(0, 40):
		print("  ! " + e)
	print("ASSETS: %d fichiers vérifiés, %d couleurs, %d erreurs" % [req.size(), all_colors.size(), errors.size()])
	print("##RESULT " + JSON.stringify(result))
	return 0 if errors.is_empty() else 1
