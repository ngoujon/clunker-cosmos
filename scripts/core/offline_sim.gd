class_name OfflineSim
extends RefCounted
## Progression hors ligne : l'atelier continue de tourner avec les employés (le patron, lui,
## ne travaille pas) pendant le temps écoulé, plafonné. Produit un rapport lisible.

const NOTABLE: PackedStringArray = [
	"ship_sold", "wreck_bought", "sav_claim", "inspection", "employee_quit", "employee_level",
	"quest_completed", "quest_available", "debt_paid", "debt_late", "item_found", "salaries_unpaid",
	"lot_defaulted", "chapter_started",
]


static func hours_for(m: GameModel, elapsed_seconds: float) -> int:
	var sph: float = maxf(0.1, m.db.cfgf("time", "seconds_per_hour", 4.0))
	var eff: float = m.db.cfgf("offline", "efficiency", 1.0) + m.stat("offline_efficiency")
	var cap: float = m.db.cfgf("offline", "cap_hours", 24.0) + m.stat("offline_cap_hours")
	return clampi(int(floor(elapsed_seconds / sph * eff)), 0, int(cap))


static func run(m: GameModel, elapsed_seconds: float) -> Dictionary:
	var hours: int = hours_for(m, elapsed_seconds)
	return run_hours(m, hours, elapsed_seconds)


static func run_hours(m: GameModel, hours: int, elapsed_seconds: float = 0.0) -> Dictionary:
	var before: Dictionary = m.counters.duplicate()
	var credits0: int = m.credits
	var rp0: float = m.research_points
	var rep0: float = m.reputation
	var log_start: int = m.event_log.size()
	var day0: int = m.day
	var was_online: bool = m.owner_online
	m.owner_online = false
	var notable: Array[Dictionary] = []
	var on_event: Callable = func(ev: Dictionary) -> void:
		if str(ev.get("type", "")) in NOTABLE and notable.size() < 60:
			notable.append(ev.duplicate())
	m.game_event.connect(on_event)
	m.advance_hours(hours)
	m.game_event.disconnect(on_event)
	m.owner_online = was_online
	var delta: Callable = func(key: String) -> float: return m.counter(key) - float(before.get(key, 0.0))
	return {
		"elapsed_seconds": elapsed_seconds,
		"hours": hours,
		"days_passed": m.day - day0,
		"credits_delta": m.credits - credits0,
		"rp_delta": m.research_points - rp0,
		"reputation_delta": m.reputation - rep0,
		"sold": int(delta.call("ships_sold")),
		"revenue": int(delta.call("income_sales")),
		"bought": int(delta.call("wrecks_bought")),
		"repairs": int(delta.call("defects_repaired")),
		"concealed": int(delta.call("defects_concealed")),
		"customizations": int(delta.call("customizations")),
		"expenses": int(delta.call("expense_total")),
		"events": notable,
		"log_from": log_start,
	}
