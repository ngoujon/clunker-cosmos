class_name ShipDefect
extends RefCounted
## Un défaut d'un vaisseau. state : open | repaired | concealed.
## decision : auto (suit la politique) | repair | conceal | disclose.

var type: String = ""
var sev: int = 1
var known: bool = false
var state: String = "open"
var decision: String = "auto"
var progress: float = 0.0
var work_kind: String = ""
var worker: String = ""
var sav_done: bool = false


static func make(p_type: String, p_sev: int, p_known: bool) -> ShipDefect:
	var d: ShipDefect = ShipDefect.new()
	d.type = p_type
	d.sev = p_sev
	d.known = p_known
	return d


func is_open() -> bool:
	return state == "open"


func is_busy() -> bool:
	return not worker.is_empty()


func to_dict() -> Dictionary:
	return {
		"type": type, "sev": sev, "known": known, "state": state, "decision": decision,
		"progress": progress, "work_kind": work_kind, "worker": worker, "sav_done": sav_done,
	}


static func from_dict(d: Dictionary) -> ShipDefect:
	var x: ShipDefect = ShipDefect.new()
	x.type = str(d.get("type", ""))
	x.sev = int(d.get("sev", 1))
	x.known = bool(d.get("known", false))
	x.state = str(d.get("state", "open"))
	x.decision = str(d.get("decision", "auto"))
	x.progress = float(d.get("progress", 0.0))
	x.work_kind = str(d.get("work_kind", ""))
	x.worker = str(d.get("worker", ""))
	x.sav_done = bool(d.get("sav_done", false))
	return x
