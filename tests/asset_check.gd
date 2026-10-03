class_name AssetCheck
extends RefCounted
## Validation des assets du jeu (headless) : présence, chargement, tailles (images HD à DETAIL fois leur taille
## logique), masques de peinture, points d'ancrage, et couverture des références du contenu (icônes,
## portraits, fonds).

const ANCHORS_PATH: String = "res://assets/ships/anchors.json"
## Pixels d'image par pixel logique (doit valoir UIKit.DETAIL et tools/hd_art.py DETAIL).
const DETAIL: int = 4


## Liste des assets requis : {chemin: {"w": .., "h": .., "kind": ..}} (w/h = 0 → libre).
static func required(db: ContentDB) -> Dictionary:
	var req: Dictionary = {}
	for slot: String in ContentDB.SLOTS:
		for id: String in db.parts_by_slot.get(slot, []):
			req["res://assets/ships/%s/%s.png" % [slot, id]] = {"kind": "part"}
			if slot == "hull" or slot == "wings":
				req["res://assets/ships/%s/%s_paint.png" % [slot, id]] = {"kind": "paint_mask"}
	for w: String in ["wear_rust", "wear_scratch", "wear_dent", "wear_scorch"]:
		req["res://assets/ships/wear/%s.png" % w] = {"kind": "wear"}
	for sp: String in db.species:
		req["res://assets/portraits/%s.png" % str(db.species[sp]["portrait"])] = {"kind": "portrait", "w": 48, "h": 48}
	for p: String in db.staff_portraits:
		req["res://assets/portraits/%s.png" % p] = {"kind": "portrait", "w": 48, "h": 48}
		# Personnage en pied de la vue en coupe du garage (scripts/ui/worker_view.gd).
		req["res://assets/workers/%s.png" % p] = {"kind": "worker", "w": 20, "h": 26}
	for c: String in db.characters:
		var por: String = str(db.characters[c].get("portrait", ""))
		if not por.is_empty():
			req["res://assets/portraits/%s.png" % por] = {"kind": "portrait", "w": 48, "h": 48}
	for icon: String in icon_ids(db):
		req["res://assets/icons/%s.png" % icon] = {"kind": "icon", "w": 16, "h": 16}
	req["res://assets/backgrounds/garage.png"] = {"kind": "background", "w": 480, "h": 270}
	for loc: String in db.locations:
		req["res://assets/backgrounds/%s.png" % str(db.locations[loc]["background"])] = {"kind": "background", "w": 480, "h": 270}
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
	var errors: Array[String] = []
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
		var ew: int = int(spec.get("w", 0)) * DETAIL
		var eh: int = int(spec.get("h", 0)) * DETAIL
		if ew > 0 and (img.get_width() != ew or img.get_height() != eh):
			errors.append("taille %dx%d au lieu de %dx%d : %s" % [img.get_width(), img.get_height(), ew, eh, path])
		if img.get_width() % DETAIL != 0 or img.get_height() % DETAIL != 0:
			errors.append("taille %dx%d non multiple de %d : %s" % [img.get_width(), img.get_height(), DETAIL, path])
	var anchors: Variant = JSON.parse_string(FileAccess.get_file_as_string(ANCHORS_PATH)) if FileAccess.file_exists(ANCHORS_PATH) else null
	if typeof(anchors) != TYPE_DICTIONARY:
		errors.append("anchors.json manquant ou invalide")
	else:
		for slot: String in ContentDB.SLOTS:
			for id: String in db.parts_by_slot.get(slot, []):
				if not (anchors as Dictionary).has(id):
					errors.append("points d'ancrage manquants : " + id)
	var result: Dictionary = {"assets": req.size(), "counts": counts, "errors": errors.slice(0, 40), "error_count": errors.size()}
	for e: String in errors.slice(0, 40):
		print("  ! " + e)
	print("ASSETS: %d fichiers vérifiés, %d erreurs" % [req.size(), errors.size()])
	print("##RESULT " + JSON.stringify(result))
	return 0 if errors.is_empty() else 1
