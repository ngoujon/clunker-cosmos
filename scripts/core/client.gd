class_name Client
extends RefCounted
## Client alien : budget, préférences, patience. `quest` non vide = commande liée à une quête.

var id: int = 0
var name: String = ""
var species: String = ""
var portrait: String = ""
var budget: int = 0
var likes_classes: Array[String] = []
var likes_tags: Array[String] = []
var likes_colors: Array[String] = []
var likes_options: Array[String] = []
var arrival_day: int = 0
var leave_day: int = 0
var quest: String = ""
var criteria: Dictionary = {}
var busy: String = ""
var refusals: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "species": species, "portrait": portrait, "budget": budget,
		"likes_classes": likes_classes.duplicate(), "likes_tags": likes_tags.duplicate(),
		"likes_colors": likes_colors.duplicate(), "likes_options": likes_options.duplicate(),
		"arrival_day": arrival_day, "leave_day": leave_day, "quest": quest,
		"criteria": criteria.duplicate(true), "busy": busy, "refusals": refusals,
	}


static func from_dict(d: Dictionary) -> Client:
	var c: Client = Client.new()
	c.id = int(d.get("id", 0))
	c.name = str(d.get("name", ""))
	c.species = str(d.get("species", ""))
	c.portrait = str(d.get("portrait", ""))
	c.budget = int(d.get("budget", 0))
	c.likes_classes = Util.str_array(d.get("likes_classes", []))
	c.likes_tags = Util.str_array(d.get("likes_tags", []))
	c.likes_colors = Util.str_array(d.get("likes_colors", []))
	c.likes_options = Util.str_array(d.get("likes_options", []))
	c.arrival_day = int(d.get("arrival_day", 0))
	c.leave_day = int(d.get("leave_day", 0))
	c.quest = str(d.get("quest", ""))
	c.criteria = d.get("criteria", {})
	c.busy = str(d.get("busy", ""))
	c.refusals = int(d.get("refusals", 0))
	return c
