extends TestCase
## Validité du contenu JSON (FR+EN, références croisées, forme de l'arbre).


func test_content_loads_without_errors() -> void:
	eq(db.errors.size(), 0, "erreurs de chargement : %s" % str(db.errors))


func test_texts_are_bilingual() -> void:
	var missing: int = 0
	for k: String in db.texts:
		var d: Dictionary = db.texts[k]
		if str(d.get("fr", "")).is_empty() or str(d.get("en", "")).is_empty():
			missing += 1
	eq(missing, 0, "textes sans FR ou EN")
	gt(db.texts.size(), 300.0, "nombre de textes")


func test_modular_parts_counts() -> void:
	eq((db.parts_by_slot["hull"] as Array).size(), 8, "coques")
	eq((db.parts_by_slot["engine"] as Array).size(), 6, "moteurs")
	eq((db.parts_by_slot["cockpit"] as Array).size(), 6, "cockpits")
	eq((db.parts_by_slot["wings"] as Array).size(), 4, "ailes")


func test_tech_tree_shape() -> void:
	ge(float(db.branches.size()), 6.0, "branches")
	var per_branch: Dictionary = {}
	for id: String in db.tech:
		var b: String = str(db.tech[id]["branch"])
		per_branch[b] = int(per_branch.get(b, 0)) + 1
	for b: Dictionary in db.branches:
		ge(float(per_branch.get(b["id"], 0)), 6.0, "nœuds de la branche %s" % b["id"])
	for id: String in db.tech:
		for p: Variant in db.tech[id].get("prereqs", []):
			check(db.tech.has(str(p)), "prérequis inconnu %s pour %s" % [p, id])
		check(int(db.tech[id].get("rp", 0)) > 0 and int(db.tech[id].get("credits", 0)) > 0, "coût RP + crédits pour %s" % id)


func test_tech_tree_acyclic() -> void:
	var state: Dictionary = {}
	for id: String in db.tech:
		check(not _has_cycle(id, state), "cycle via %s" % id)


func _has_cycle(id: String, state: Dictionary) -> bool:
	if int(state.get(id, 0)) == 1:
		return true
	if int(state.get(id, 0)) == 2:
		return false
	state[id] = 1
	for p: Variant in db.tech[id].get("prereqs", []):
		if _has_cycle(str(p), state):
			return true
	state[id] = 2
	return false


func test_tech_effects_valid() -> void:
	for id: String in db.tech:
		for e: Variant in db.tech[id].get("effects", []):
			var eff: Dictionary = e
			var op: String = str(eff.get("op", ""))
			if op == "unlock":
				var t: String = str(eff.get("target", ""))
				var parts: PackedStringArray = t.split(":")
				var table: Dictionary = {"location": db.locations, "paint": db.paints, "option": db.options}.get(parts[0], {})
				check(table.has(parts[1]), "cible inconnue %s (%s)" % [t, id])
			else:
				check(op in ["add", "mul"], "op inconnue %s" % op)
				check(db.stats.has(str(eff.get("stat", ""))), "stat inconnue %s (%s)" % [eff.get("stat", ""), id])


func test_paint_ramps_use_global_palette() -> void:
	var pal: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json"))
	check(typeof(pal) == TYPE_DICTIONARY, "palette lisible")
	var colors: Array = (pal as Dictionary).get("colors", [])
	check(colors.size() <= 32, "palette <= 32 couleurs")
	for id: String in db.paints:
		for c: Variant in db.paints[id]["ramp"]:
			check(str(c).to_lower() in colors, "couleur %s de %s hors palette" % [c, id])


func test_species_and_portraits() -> void:
	ge(float(db.species.size()), 12.0, "espèces clientes")
	ge(float(db.staff_portraits.size()), 8.0, "portraits d'employés")
	eq(db.roles.size(), 5, "rôles")


func test_quest_references_valid() -> void:
	gt(float(db.quests.size()), 20.0, "nombre de quêtes")
	for id: String in db.quests:
		var q: Dictionary = db.quests[id]
		for c: Variant in q.get("trigger", []):
			var cd: Dictionary = c
			if str(cd.get("type", "")) in ["quest_done", "quest_started"]:
				check(db.quests.has(str(cd.get("id", ""))), "déclencheur vers quête inconnue (%s)" % id)
		for list_name: String in ["rewards", "on_start"]:
			for e: Variant in q.get(list_name, []):
				var ed: Dictionary = e
				match str(ed.get("type", "")):
					"special_lot":
						check(db.special_lots.has(str(ed.get("id", ""))), "lot spécial inconnu (%s)" % id)
					"employee":
						check(db.staff_templates.has(str(ed.get("template", ""))), "modèle d'employé inconnu (%s)" % id)
					"tech":
						check(db.tech.has(str(ed.get("id", ""))), "nœud inconnu (%s)" % id)


func test_story_has_five_chapters_and_two_endings() -> void:
	eq(db.chapters.size(), 5, "chapitres")
	eq(db.endings.size(), 2, "fins")
	var main_by_ch: Dictionary = {}
	var sides: int = 0
	for id: String in db.quests:
		var q: Dictionary = db.quests[id]
		if str(q.get("kind", "")) == "main":
			main_by_ch[int(q.get("chapter", 0))] = int(main_by_ch.get(int(q.get("chapter", 0)), 0)) + 1
		else:
			sides += 1
	for ch: int in range(1, 6):
		ge(float(main_by_ch.get(ch, 0)), 3.0, "quêtes principales du chapitre %d" % ch)
	ge(float(sides), 10.0, "quêtes secondaires")
