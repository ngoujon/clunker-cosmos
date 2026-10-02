class_name ResearchSystem
extends RefCounted
## Arbre technologique : prérequis, coûts (points de recherche + crédits), effets data-driven.


## "" si la recherche est possible, sinon la raison : unknown | done | prereq | rp | credits.
static func can_research(m: GameModel, id: String) -> String:
	var node: Dictionary = m.db.tech.get(id, {})
	if node.is_empty():
		return "unknown"
	if id in m.researched:
		return "done"
	for p: Variant in node.get("prereqs", []):
		if not str(p) in m.researched:
			return "prereq"
	if m.research_points + 0.0001 < float(node.get("rp", 0)):
		return "rp"
	if m.credits < int(node.get("credits", 0)):
		return "credits"
	return ""


## État d'affichage d'un nœud : done | ready | available | locked.
static func node_state(m: GameModel, id: String) -> String:
	var r: String = can_research(m, id)
	match r:
		"done":
			return "done"
		"":
			return "ready"
		"prereq":
			return "locked"
	return "available"


static func research(m: GameModel, id: String) -> Dictionary:
	var reason: String = can_research(m, id)
	if not reason.is_empty():
		return GameModel.fail(reason)
	var node: Dictionary = m.db.tech[id]
	m.research_points -= float(node.get("rp", 0))
	m.spend(int(node.get("credits", 0)), "research")
	_apply(m, id, false)
	return GameModel.ok()


## Déblocage gratuit (récompense de quête).
static func grant(m: GameModel, id: String) -> void:
	if id in m.researched or not m.db.tech.has(id):
		return
	_apply(m, id, true)


static func _apply(m: GameModel, id: String, free: bool) -> void:
	m.researched.append(id)
	m.mark_stats_dirty()
	for e: Variant in m.db.tech[id].get("effects", []):
		var eff: Dictionary = e
		if str(eff.get("op", "")) == "unlock":
			m.unlock(str(eff.get("target", "")))
	if bool(m.settings.get("auto_assign", true)):
		StaffSystem.auto_assign(m)
	m.count("research_done")
	m.emit({"type": "research_done", "node": id, "free": free})


static func available(m: GameModel) -> Array[String]:
	var out: Array[String] = []
	for id: String in m.db.tech:
		var r: String = can_research(m, id)
		if r != "done" and r != "prereq" and r != "unknown":
			out.append(id)
	return out
