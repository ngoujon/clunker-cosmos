extends Node
## Autoload « Content » : base de contenu JSON partagée (chargée une fois au démarrage).

var db: ContentDB


func _init() -> void:
	db = ContentDB.load_default()
	for e: String in db.errors:
		push_warning("[Content] " + e)


## Recharge le contenu (outil de développement).
func reload() -> void:
	db = ContentDB.load_default()
