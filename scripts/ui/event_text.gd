class_name EventText
extends RefCounted
## Phrases lisibles (FR/EN) pour les événements du modèle : notifications, rapports, hors-ligne.


static func _ship_name(id: int) -> String:
	var m: GameModel = Game.model
	if m == null:
		return "?"
	var s: Ship = m.find_ship(id)
	if s != null:
		return s.name
	for rec: Dictionary in m.sold:
		if int(rec.get("ship", -1)) == id:
			return str(rec.get("name", "?"))
	return "#%d" % id


static func _employee_name(id: String) -> String:
	var m: GameModel = Game.model
	if m == null:
		return id
	var e: Employee = m.find_employee(id)
	return e.name if e != null else id


static func _cr(ev: Dictionary, key: String) -> String:
	return UIKit.credits(int(ev.get(key, 0)))


static func _q(ev: Dictionary) -> String:
	return I18n.t("quest.%s.title" % str(ev.get("quest", "")))


static func _def(ev: Dictionary) -> String:
	return I18n.t("defect.%s.name" % str(ev.get("defect", "")))


static func describe(ev: Dictionary) -> String:
	var et: String = str(ev.get("type", ""))
	match et:
		"wreck_bought":
			if not str(ev.get("special", "")).is_empty():
				return I18n.t("ui.ev.special_bought", {"price": _cr(ev, "price")})
			return I18n.t("ui.ev.wreck_bought", {"ship": _ship_name(int(ev.get("ship", -1))), "price": _cr(ev, "price")})
		"wreck_gift":
			return I18n.t("ui.ev.wreck_gift", {"ship": _ship_name(int(ev.get("ship", -1)))})
		"lot_lost":
			return I18n.t("ui.ev.lot_lost", {"price": _cr(ev, "price")})
		"lot_defaulted":
			return I18n.t("ui.ev.lot_defaulted")
		"ship_sold":
			return I18n.t("ui.ev.ship_sold", {"ship": _ship_name(int(ev.get("ship", -1))), "price": _cr(ev, "price"), "profit": _cr(ev, "profit")})
		"sav_claim":
			return I18n.t("ui.ev.sav_claim", {"ship": str(ev.get("ship_name", "")), "defect": _def(ev), "cost": _cr(ev, "cost")})
		"inspection":
			if int(ev.get("found", 0)) > 0:
				return I18n.t("ui.ev.inspection_fine", {"found": int(ev.get("found", 0)), "fines": _cr(ev, "fines")})
			return I18n.t("ui.ev.inspection_clean")
		"employee_quit":
			return I18n.t("ui.ev.employee_quit", {"name": str(ev.get("name", ""))})
		"employee_level":
			return I18n.t("ui.ev.employee_level", {"name": _employee_name(str(ev.get("employee", ""))), "level": int(ev.get("level", 1))})
		"employee_hired":
			return I18n.t("ui.ev.employee_hired", {"name": _employee_name(str(ev.get("employee", "")))})
		"quest_available":
			return I18n.t("ui.ev.quest_available", {"title": _q(ev)})
		"quest_started":
			return I18n.t("ui.ev.quest_started", {"title": _q(ev)})
		"quest_completed":
			return I18n.t("ui.ev.quest_completed", {"title": _q(ev)})
		"quest_failed":
			return I18n.t("ui.ev.quest_failed", {"title": _q(ev)})
		"debt_paid":
			return I18n.t("ui.ev.debt_paid_auto" if bool(ev.get("auto", false)) else "ui.ev.debt_paid", {"amount": _cr(ev, "amount")})
		"debt_late":
			return I18n.t("ui.ev.debt_late", {"amount": _cr(ev, "amount"), "penalty": _cr(ev, "penalty")})
		"emergency_loan":
			return I18n.t("ui.ev.emergency_loan", {"amount": _cr(ev, "amount"), "debt": _cr(ev, "debt")})
		"low_funds":
			return I18n.t("ui.ev.low_funds")
		"debt_cleared":
			return I18n.t("ui.ev.debt_cleared")
		"item_found":
			return I18n.t("ui.ev.item_found", {"item": I18n.t("item.%s.name" % str(ev.get("item", "")))})
		"chapter_started":
			var ch: int = int(ev.get("chapter", 1))
			return I18n.t("ui.ev.chapter_started", {"n": ch, "title": I18n.t("chapter.%d.title" % ch)})
		"location_unlocked":
			return I18n.t("ui.ev.location_unlocked", {"location": I18n.t("location.%s.name" % str(ev.get("location", "")))})
		"salaries_unpaid":
			return I18n.t("ui.ev.salaries_unpaid", {"amount": _cr(ev, "amount")})
		"garage_upgraded":
			return I18n.t("ui.ev.garage_upgraded", {"level": int(ev.get("level", 1))})
		"defect_found":
			var key: String = "ui.ev.defect_clumsy" if str(ev.get("cause", "")) == "clumsy" else "ui.ev.defect_found"
			return I18n.t(key, {"defect": _def(ev), "ship": _ship_name(int(ev.get("ship", -1)))})
		"research_done":
			return I18n.t("ui.ev.research_free" if bool(ev.get("free", false)) else "ui.ev.research_done", {"node": I18n.t("tech.%s.name" % str(ev.get("node", "")))})
		"day_started":
			return I18n.t("ui.ev.day_started", {"day": int(ev.get("day", 1))})
		"defect_repaired":
			return I18n.t("ui.ev.defect_repaired", {"defect": _def(ev), "ship": _ship_name(int(ev.get("ship", -1)))})
		"defect_concealed":
			return I18n.t("ui.ev.defect_concealed", {"defect": _def(ev), "ship": _ship_name(int(ev.get("ship", -1)))})
		"customized":
			return I18n.t("ui.ev.customized", {"ship": _ship_name(int(ev.get("ship", -1)))})
		"client_left":
			return I18n.t("ui.ev.client_left", {"species": I18n.t("species.%s.name" % str(ev.get("species", "")))})
		"lot_scanned":
			return I18n.t("ui.ev.lot_scanned", {"found": int(ev.get("found", 0))})
		"story_ending":
			return I18n.t("ending.%s.title" % str(ev.get("ending", "")))
	return ""
