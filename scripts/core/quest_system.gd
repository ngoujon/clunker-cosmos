class_name QuestSystem
extends RefCounted
## Quêtes pilotées par les données (data/quests.json) : déclencheurs, objectifs (comptés via
## les événements ou évalués sur l'état), dialogues, récompenses et choix de fin.
## Quêtes principales : uniquement en mode Histoire, démarrage automatique.
## Quêtes secondaires (commandes) : proposées, toujours facultatives, acceptées par le joueur.

## Objectifs comptés à partir des événements du modèle.
const EVENT_OBJECTIVES: Dictionary = {
	"buy_wrecks": "wreck_bought",
	"scan_lots": "lot_scanned",
	"repair_defects": "defect_repaired",
	"conceal_defects": "defect_concealed",
	"customize": "customized",
	"sell_ships": "ship_sold",
	"earn_sales": "ship_sold",
	"deliver_order": "ship_sold",
	"hire": "employee_hired",
	"survive_inspection": "inspection",
}

## Objectifs évalués sur l'état courant.
const STATE_OBJECTIVES: PackedStringArray = [
	"credits_at_least", "reputation_at_least", "research_node", "research_count", "location_unlocked",
	"has_item", "items_count", "staff_at_least", "garage_level", "debt_paid_total", "debt_cleared",
	"day_at_least", "choice",
]


static func init(m: GameModel) -> void:
	for id: String in m.db.quest_order:
		if not m.quest_state.has(id):
			m.quest_state[id] = {"status": "locked", "progress": [], "start_day": 0, "deadline": 0, "choice": -1}


static func quest(m: GameModel, id: String) -> Dictionary:
	return m.db.quests.get(id, {})


static func status(m: GameModel, id: String) -> String:
	return str(m.quest_state.get(id, {}).get("status", "locked"))


static func ids_with_status(m: GameModel, st: String, kind: String = "") -> Array[String]:
	var out: Array[String] = []
	for id: String in m.db.quest_order:
		if status(m, id) == st and (kind.is_empty() or str(quest(m, id).get("kind", "")) == kind):
			out.append(id)
	return out


# --- Boucle -------------------------------------------------------------------

static func update(m: GameModel) -> void:
	for id: String in m.db.quest_order:
		var st: Dictionary = m.quest_state[id]
		var q: Dictionary = quest(m, id)
		match str(st["status"]):
			"locked":
				if _triggered(m, q):
					if str(q.get("kind", "side")) == "main":
						start(m, id)
					else:
						st["status"] = "available"
						st["offer_day"] = m.day
						m.emit({"type": "quest_available", "quest": id})
			"active":
				if int(st.get("deadline", 0)) > 0 and m.day > int(st["deadline"]):
					fail(m, id)
				elif all_done(m, id):
					complete(m, id)
	_update_chapter(m)


static func _triggered(m: GameModel, q: Dictionary) -> bool:
	if str(q.get("kind", "side")) == "main" and not m.story_mode:
		return false
	if q.has("story_only") and bool(q["story_only"]) and not m.story_mode:
		return false
	for c: Variant in q.get("trigger", []):
		if not condition(m, c as Dictionary):
			return false
	return true


static func condition(m: GameModel, c: Dictionary) -> bool:
	var v: float = float(c.get("value", 0))
	match str(c.get("type", "")):
		"quest_done":
			return status(m, str(c.get("id", ""))) == "done"
		"quest_started":
			return status(m, str(c.get("id", ""))) in ["active", "done"]
		"day_at_least":
			return float(m.day) >= v
		"reputation_at_least":
			return m.reputation >= v
		"sales_at_least":
			return m.counter("ships_sold") >= v
		"credits_at_least":
			return float(m.credits) >= v
		"flag":
			return bool(m.flags.get(str(c.get("id", "")), false))
		"not_flag":
			return not bool(m.flags.get(str(c.get("id", "")), false))
		"location_unlocked":
			return m.is_unlocked("location:" + str(c.get("id", "")))
		"research_node":
			return str(c.get("id", "")) in m.researched
		"chapter_at_least":
			return float(m.chapter) >= v
		"has_item":
			return str(c.get("id", "")) in m.items
		"staff_at_least":
			return float(m.staff.size()) >= v
		"story":
			return m.story_mode
	return false


# --- Cycle de vie -------------------------------------------------------------

static func start(m: GameModel, id: String) -> void:
	var q: Dictionary = quest(m, id)
	var st: Dictionary = m.quest_state[id]
	st["status"] = "active"
	st["start_day"] = m.day
	var objs: Array = q.get("objectives", [])
	var progress: Array = []
	for i: int in objs.size():
		progress.append(0)
	st["progress"] = progress
	var days: int = int(q.get("deadline_days", 0))
	st["deadline"] = m.day + days if days > 0 else 0
	for eff: Variant in q.get("on_start", []):
		apply_effect(m, id, eff as Dictionary)
	for obj: Variant in objs:
		var o: Dictionary = obj
		if str(o.get("type", "")) == "deliver_order":
			var c: Client = MarketSystem.spawn_order_client(m, id, o)
			st["client"] = c.id
	_queue_dialogue(m, id, "start")
	m.journal.append({"day": m.day, "quest": id, "event": "started"})
	m.emit({"type": "quest_started", "quest": id})


static func accept(m: GameModel, id: String) -> Dictionary:
	if status(m, id) != "available":
		return GameModel.fail("not_available")
	start(m, id)
	return GameModel.ok()


static func complete(m: GameModel, id: String) -> void:
	var q: Dictionary = quest(m, id)
	var st: Dictionary = m.quest_state[id]
	st["status"] = "done"
	st["done_day"] = m.day
	_remove_order_client(m, id)
	for eff: Variant in q.get("rewards", []):
		apply_effect(m, id, eff as Dictionary)
	_queue_dialogue(m, id, "end")
	m.journal.append({"day": m.day, "quest": id, "event": "completed"})
	m.count("quests_done")
	m.emit({"type": "quest_completed", "quest": id, "kind": str(q.get("kind", ""))})


static func fail(m: GameModel, id: String) -> void:
	var st: Dictionary = m.quest_state[id]
	st["status"] = "failed"
	_remove_order_client(m, id)
	_queue_dialogue(m, id, "fail")
	m.journal.append({"day": m.day, "quest": id, "event": "failed"})
	m.emit({"type": "quest_failed", "quest": id})


static func _remove_order_client(m: GameModel, id: String) -> void:
	for c: Client in m.clients.duplicate():
		if c.quest == id:
			MarketSystem.remove_client(m, c)


static func choose(m: GameModel, id: String, idx: int) -> Dictionary:
	if status(m, id) != "active":
		return GameModel.fail("not_active")
	var choices: Array = quest(m, id).get("choices", [])
	if idx < 0 or idx >= choices.size():
		return GameModel.fail("bad_choice")
	var ch: Dictionary = choices[idx]
	m.quest_state[id]["choice"] = idx
	if ch.has("flag"):
		m.flags[str(ch["flag"])] = true
	for eff: Variant in ch.get("effects", []):
		apply_effect(m, id, eff as Dictionary)
	m.emit({"type": "choice_made", "quest": id, "choice": idx})
	update(m)
	return GameModel.ok()


# --- Objectifs ------------------------------------------------------------------

static func on_event(m: GameModel, ev: Dictionary) -> void:
	var et: String = str(ev.get("type", ""))
	for id: String in m.db.quest_order:
		var st: Dictionary = m.quest_state.get(id, {})
		if str(st.get("status", "")) != "active":
			continue
		var objs: Array = quest(m, id).get("objectives", [])
		var progress: Array = st["progress"]
		for i: int in objs.size():
			var o: Dictionary = objs[i]
			var ot: String = str(o.get("type", ""))
			if EVENT_OBJECTIVES.get(ot, "") != et or not _event_matches(m, id, o, ev):
				continue
			if ot == "earn_sales":
				progress[i] = int(progress[i]) + int(ev.get("price", 0))
			else:
				progress[i] = int(progress[i]) + 1


static func _event_matches(m: GameModel, quest_id: String, o: Dictionary, ev: Dictionary) -> bool:
	var ot: String = str(o.get("type", ""))
	if ot == "deliver_order":
		return str(ev.get("quest", "")) == quest_id
	if ot == "survive_inspection":
		return int(ev.get("found", 1)) == 0
	if o.has("location") and str(ev.get("location", "")) != str(o["location"]):
		return false
	if o.has("role") and str(ev.get("role", "")) != str(o["role"]):
		return false
	if o.has("class") and str(ev.get("class", "")) != str(o["class"]):
		return false
	if o.has("color") and str(ev.get("color", "")) != str(o["color"]):
		return false
	if o.has("tag") and not str(o["tag"]) in Util.str_array(ev.get("tags", [])):
		return false
	if o.has("species") and str(ev.get("species", "")) != str(o["species"]):
		return false
	if o.has("kind") and str(ev.get("kind", "")) != str(o["kind"]):
		return false
	if o.has("min_price") and int(ev.get("price", 0)) < int(o["min_price"]):
		return false
	if bool(o.get("honest", false)) and not bool(ev.get("honest", false)):
		return false
	if o.has("min_tier") and int(ev.get("tier", 0)) < int(o["min_tier"]):
		return false
	if bool(o.get("rare", false)) and not bool(ev.get("rare", false)):
		return false
	return true


## [valeur courante, cible] d'un objectif (pour l'UI et les tests).
static func objective_values(m: GameModel, id: String, i: int) -> Array[float]:
	var o: Dictionary = (quest(m, id).get("objectives", []) as Array)[i]
	var st: Dictionary = m.quest_state.get(id, {})
	var ot: String = str(o.get("type", ""))
	var target: float = float(o.get("count", o.get("value", 1)))
	if EVENT_OBJECTIVES.has(ot):
		var progress: Array = st.get("progress", [])
		var cur: float = float(progress[i]) if i < progress.size() else 0.0
		if ot == "deliver_order":
			target = 1.0
		return [cur, target]
	match ot:
		"credits_at_least":
			return [float(m.credits), target]
		"reputation_at_least":
			return [m.reputation, target]
		"research_node":
			return [1.0 if str(o.get("id", "")) in m.researched else 0.0, 1.0]
		"research_count":
			return [float(m.researched.size()), target]
		"location_unlocked":
			return [1.0 if m.is_unlocked("location:" + str(o.get("id", ""))) else 0.0, 1.0]
		"has_item":
			return [1.0 if str(o.get("id", "")) in m.items else 0.0, 1.0]
		"items_count":
			var n: int = 0
			for it: String in m.items:
				if it.begins_with(str(o.get("prefix", ""))):
					n += 1
			return [float(n), target]
		"staff_at_least":
			var cnt: int = 0
			for e: Employee in m.staff:
				if not o.has("role") or e.role == str(o["role"]):
					cnt += 1
			return [float(cnt), target]
		"garage_level":
			return [float(m.garage_level), target]
		"debt_paid_total":
			return [float(m.debt_paid_total), target]
		"debt_cleared":
			return [1.0 if m.debt <= 0 else 0.0, 1.0]
		"day_at_least":
			return [float(m.day), target]
		"choice":
			return [1.0 if int(st.get("choice", -1)) >= 0 else 0.0, 1.0]
	return [0.0, 1.0]


static func objective_done(m: GameModel, id: String, i: int) -> bool:
	var v: Array[float] = objective_values(m, id, i)
	return v[0] + 0.0001 >= v[1]


static func all_done(m: GameModel, id: String) -> bool:
	var objs: Array = quest(m, id).get("objectives", [])
	for i: int in objs.size():
		if not objective_done(m, id, i):
			return false
	return true


# --- Effets (récompenses, démarrage, choix) -------------------------------------

static func apply_effect(m: GameModel, quest_id: String, eff: Dictionary) -> void:
	match str(eff.get("type", "")):
		"credits":
			m.earn(int(eff.get("amount", 0)), "quest")
		"rp":
			m.add_rp(float(eff.get("amount", 0)))
		"reputation":
			m.add_reputation(float(eff.get("amount", 0)))
		"item":
			var item: String = str(eff.get("id", ""))
			if not item in m.items:
				m.items.append(item)
				m.emit({"type": "item_found", "item": item, "quest": quest_id})
		"special_lot":
			var sp: String = str(eff.get("id", ""))
			if not sp in m.pending_specials:
				m.pending_specials.append(sp)
			AuctionSystem.spawn_pending_now(m)
		"rare_wreck":
			var loc: String = str(eff.get("location", "ferropolis"))
			var s: Ship = ShipFactory.make_wreck(m, loc, true)
			s.acquired_day = m.day
			m.ships.append(s)
			m.emit({"type": "wreck_gift", "ship": s.id, "quest": quest_id})
		"employee":
			StaffSystem.hire_template(m, str(eff.get("template", "")))
		"unlock":
			m.unlock(str(eff.get("target", "")))
		"tech":
			ResearchSystem.grant(m, str(eff.get("id", "")))
		"flag":
			m.flags[str(eff.get("id", ""))] = true
		"debt_reduction":
			var a: int = mini(int(eff.get("amount", 0)), m.debt)
			m.debt -= a
			m.emit({"type": "debt_reduced", "amount": a})
		"modifier":
			m.extra_mods.append({"op": str(eff.get("op", "add")), "stat": str(eff.get("stat", "")), "value": float(eff.get("value", 0.0))})
			m.mark_stats_dirty()
		"ending":
			m.ending = str(eff.get("id", ""))
			m.emit({"type": "story_ending", "ending": m.ending})


static func _queue_dialogue(m: GameModel, id: String, phase: String) -> void:
	var lines: Array = quest(m, id).get("dialogue_" + phase, [])
	if lines.is_empty():
		return
	var out: Array = []
	for i: int in lines.size():
		var line: Dictionary = lines[i]
		out.append({"speaker": str(line.get("speaker", "bolt")), "key": "dlg.%s.%s.%d" % [id, phase, i]})
	m.dialogue_queue.append({"quest": id, "phase": phase, "lines": out})


static func _update_chapter(m: GameModel) -> void:
	var ch: int = m.chapter
	for id: String in m.db.quest_order:
		var q: Dictionary = quest(m, id)
		if str(q.get("kind", "")) == "main" and status(m, id) in ["active", "done"]:
			ch = maxi(ch, int(q.get("chapter", 0)))
	if ch > m.chapter:
		m.chapter = ch
		m.emit({"type": "chapter_started", "chapter": ch})


## Toutes les quêtes principales d'un chapitre sont-elles terminées ?
static func chapter_complete(m: GameModel, ch: int) -> bool:
	var any: bool = false
	for id: String in m.db.quest_order:
		var q: Dictionary = quest(m, id)
		if str(q.get("kind", "")) == "main" and int(q.get("chapter", 0)) == ch:
			any = true
			if status(m, id) != "done":
				return false
	return any
