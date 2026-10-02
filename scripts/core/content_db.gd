class_name ContentDB
extends RefCounted
## Charge tout le contenu JSON (res://data) et l'expose sous forme de dictionnaires indexés.
## Les textes bilingues {"fr": .., "en": ..} sont enregistrés dans `texts` sous des clés stables
## (ex. "part.hull_shuttle.name") pour alimenter le TranslationServer côté UI.

const DATA_DIR: String = "res://data"
const LOCALES: PackedStringArray = ["fr", "en"]
const SLOTS: PackedStringArray = ["hull", "engine", "cockpit", "wings"]

var config: Dictionary = {}
var parts: Dictionary = {}
var parts_by_slot: Dictionary = {}
var classes: Dictionary = {}
var tags: Array[String] = []
var designations: Array[String] = []
var systems: Dictionary = {}
var defects: Dictionary = {}
var paints: Dictionary = {}
var colors: Array[String] = []
var options: Dictionary = {}
var species: Dictionary = {}
var staff_portraits: Array[String] = []
var staff_first_names: Array[String] = []
var staff_last_names: Array[String] = []
var roles: Dictionary = {}
var rules: Dictionary = {}
var traits: Dictionary = {}
var staff_templates: Dictionary = {}
var locations: Dictionary = {}
var location_order: Array[String] = []
var special_lots: Dictionary = {}
var items: Dictionary = {}
var branches: Array[Dictionary] = []
var tech: Dictionary = {}
var quests: Dictionary = {}
var quest_order: Array[String] = []
var characters: Dictionary = {}
var chapters: Array[Dictionary] = []
var endings: Dictionary = {}
var stats: Dictionary = {}
## Pages du tutoriel (menu Tutoriel), dans l'ordre d'affichage.
var tutorial: Array[Dictionary] = []
var texts: Dictionary = {}
var errors: PackedStringArray = []


static func load_default() -> ContentDB:
	var db: ContentDB = ContentDB.new()
	db.load_dir(DATA_DIR)
	return db


func load_dir(dir: String) -> void:
	errors.clear()
	config = _read(dir + "/config.json")
	stats = config.get("stats", {})
	_load_parts(_read(dir + "/parts.json"))
	_load_defects(_read(dir + "/defects.json"))
	_load_custom(_read(dir + "/customization.json"))
	_load_species(_read(dir + "/species.json"))
	_load_staff(_read(dir + "/staff.json"))
	_load_locations(_read(dir + "/locations.json"))
	_load_tech(_read(dir + "/tech_tree.json"))
	_load_story(_read(dir + "/story.json"))
	_load_quests(_read(dir + "/quests.json"))
	_load_tutorial(_read(dir + "/tutorial.json"))
	_load_ui_texts(_read(dir + "/ui_text.json"))


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("fichier manquant : %s" % path)
		return {}
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("JSON invalide : %s" % path)
		return {}
	return parsed


func _text(key: String, value: Variant) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("texte non bilingue : %s" % key)
		return
	var d: Dictionary = value
	for loc: String in LOCALES:
		if not d.has(loc) or str(d[loc]).is_empty():
			errors.append("traduction %s manquante : %s" % [loc, key])
	texts[key] = d


func _load_parts(d: Dictionary) -> void:
	var slot_keys: Dictionary = {"hull": "hulls", "engine": "engines", "cockpit": "cockpits", "wings": "wings"}
	for slot: String in SLOTS:
		var ids: Array[String] = []
		for p: Dictionary in d.get(slot_keys[slot], []):
			var id: String = p["id"]
			p["slot"] = slot
			parts[id] = p
			ids.append(id)
			_text("part.%s.name" % id, p.get("name"))
			_text("part.%s.desc" % id, p.get("desc"))
		parts_by_slot[slot] = ids
	classes = d.get("classes", {})
	for c: String in classes:
		_text("class.%s" % c, classes[c])
	var tag_dict: Dictionary = d.get("tags", {})
	for t: String in tag_dict:
		tags.append(t)
		_text("tag.%s" % t, tag_dict[t])
	for s: Variant in d.get("designations", []):
		designations.append(str(s))


func _load_defects(d: Dictionary) -> void:
	systems = d.get("systems", {})
	for s: String in systems:
		_text("system.%s" % s, systems[s])
	for def: Dictionary in d.get("defects", []):
		var id: String = def["id"]
		defects[id] = def
		_text("defect.%s.name" % id, def.get("name"))
		_text("defect.%s.desc" % id, def.get("desc"))


func _load_custom(d: Dictionary) -> void:
	for p: Dictionary in d.get("paints", []):
		paints[p["id"]] = p
		_text("paint.%s" % p["id"], p.get("name"))
	var cols: Dictionary = d.get("colors", {})
	for c: String in cols:
		colors.append(c)
		_text("color.%s" % c, cols[c])
	for o: Dictionary in d.get("options", []):
		options[o["id"]] = o
		_text("option.%s.name" % o["id"], o.get("name"))
		_text("option.%s.desc" % o["id"], o.get("desc"))


func _load_species(d: Dictionary) -> void:
	for s: Dictionary in d.get("species", []):
		species[s["id"]] = s
		_text("species.%s.name" % s["id"], s.get("name"))
		_text("species.%s.desc" % s["id"], s.get("desc"))
	for p: Variant in d.get("staff_portraits", []):
		staff_portraits.append(str(p))
	for n: Variant in d.get("staff_first_names", []):
		staff_first_names.append(str(n))
	for n: Variant in d.get("staff_last_names", []):
		staff_last_names.append(str(n))


func _load_staff(d: Dictionary) -> void:
	for r: Dictionary in d.get("roles", []):
		roles[r["id"]] = r
		_text("role.%s.name" % r["id"], r.get("name"))
		_text("role.%s.desc" % r["id"], r.get("desc"))
	rules = d.get("rules", {})
	for r: String in rules:
		_text("rule.%s.name" % r, rules[r].get("name"))
		_text("rule.%s.desc" % r, rules[r].get("desc"))
	for t: Dictionary in d.get("traits", []):
		traits[t["id"]] = t
		_text("trait.%s.name" % t["id"], t.get("name"))
		_text("trait.%s.desc" % t["id"], t.get("desc"))
	for tpl: Dictionary in d.get("templates", []):
		staff_templates[tpl["id"]] = tpl


func _load_locations(d: Dictionary) -> void:
	for l: Dictionary in d.get("locations", []):
		locations[l["id"]] = l
		location_order.append(l["id"])
		_text("location.%s.name" % l["id"], l.get("name"))
		_text("location.%s.desc" % l["id"], l.get("desc"))
	for s: Dictionary in d.get("special_lots", []):
		special_lots[s["id"]] = s
		_text("special.%s.name" % s["id"], s.get("name"))
	items = d.get("items", {})
	for i: String in items:
		_text("item.%s.name" % i, items[i].get("name"))
		_text("item.%s.desc" % i, items[i].get("desc"))


func _load_tech(d: Dictionary) -> void:
	for b: Dictionary in d.get("branches", []):
		branches.append(b)
		_text("branch.%s" % b["id"], b.get("name"))
	for n: Dictionary in d.get("nodes", []):
		tech[n["id"]] = n
		_text("tech.%s.name" % n["id"], n.get("name"))
		_text("tech.%s.desc" % n["id"], n.get("desc"))


func _load_story(d: Dictionary) -> void:
	characters = d.get("characters", {})
	for c: String in characters:
		_text("char.%s" % c, characters[c].get("name"))
	for ch: Dictionary in d.get("chapters", []):
		chapters.append(ch)
		_text("chapter.%d.title" % int(ch["number"]), ch.get("title"))
	endings = d.get("endings", {})
	for e: String in endings:
		_text("ending.%s.title" % e, endings[e].get("title"))
		_text("ending.%s.text" % e, endings[e].get("text"))


func _load_quests(d: Dictionary) -> void:
	for q: Dictionary in d.get("quests", []):
		var id: String = q["id"]
		quests[id] = q
		quest_order.append(id)
		_text("quest.%s.title" % id, q.get("title"))
		_text("quest.%s.desc" % id, q.get("desc"))
		var oi: int = 0
		for obj: Dictionary in q.get("objectives", []):
			if obj.has("text"):
				_text("quest.%s.obj%d" % [id, oi], obj["text"])
			oi += 1
		for phase: String in ["start", "end", "fail"]:
			var li: int = 0
			for line: Dictionary in q.get("dialogue_" + phase, []):
				_text("dlg.%s.%s.%d" % [id, phase, li], line.get("text"))
				li += 1
		var ci: int = 0
		for ch: Dictionary in q.get("choices", []):
			_text("quest.%s.choice%d" % [id, ci], ch.get("label"))
			ci += 1


func _load_tutorial(d: Dictionary) -> void:
	tutorial.clear()
	for page: Dictionary in d.get("pages", []):
		var id: String = page["id"]
		tutorial.append(page)
		_text("tuto.%s.title" % id, page.get("title"))
		_text("tuto.%s.body" % id, page.get("body"))
		if page.has("bolt"):
			_text("tuto.%s.bolt" % id, page["bolt"])


func _load_ui_texts(d: Dictionary) -> void:
	for k: String in d:
		if k.begins_with("_"):
			continue
		_text(k, d[k])


# --- Accès pratiques -------------------------------------------------------

func text(key: String, locale: String = "fr") -> String:
	if not texts.has(key):
		return key
	var d: Dictionary = texts[key]
	return str(d.get(locale, d.get("fr", key)))


func part(id: String) -> Dictionary:
	return parts.get(id, {})


func garage_level_data(level: int) -> Dictionary:
	var levels: Array = config.get("garage_levels", [])
	var idx: int = clampi(level - 1, 0, levels.size() - 1)
	return levels[idx]


func max_garage_level() -> int:
	return (config.get("garage_levels", []) as Array).size()


func cfg(section: String, key: String, default: Variant = null) -> Variant:
	var s: Dictionary = config.get(section, {})
	return s.get(key, default)


func cfgf(section: String, key: String, default: float = 0.0) -> float:
	return float(cfg(section, key, default))


func cfgi(section: String, key: String, default: int = 0) -> int:
	return int(cfg(section, key, default))


func role_ids() -> Array[String]:
	var out: Array[String] = []
	for r: String in roles:
		out.append(r)
	return out
