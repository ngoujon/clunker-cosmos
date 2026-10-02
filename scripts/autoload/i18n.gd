extends Node
## Autoload « I18n » : construit les traductions FR/EN à partir des textes du contenu
## et gère la langue courante (persistée dans les réglages du joueur, user://settings.cfg).

const LOCALES: PackedStringArray = ["fr", "en"]

signal locale_changed(locale: String)

var locale: String = "fr"


func _ready() -> void:
	build()
	var loc: String = GameSettings.load_file().locale
	if loc.is_empty():
		loc = "fr" if OS.get_locale_language() == "fr" else "en"
	set_locale(loc, false)


func build() -> void:
	var texts: Dictionary = Content.db.texts
	for loc: String in LOCALES:
		var t: Translation = Translation.new()
		t.locale = loc
		for key: String in texts:
			var d: Dictionary = texts[key]
			t.add_message(key, str(d.get(loc, d.get("fr", key))))
		TranslationServer.add_translation(t)


func set_locale(loc: String, persist: bool = true) -> void:
	locale = loc if loc in LOCALES else "en"
	TranslationServer.set_locale(locale)
	if persist and Game.settings != null:
		Game.settings.locale = locale
		Game.save_settings()
	locale_changed.emit(locale)


## tr() + remplacement des {paramètres}.
func t(key: String, params: Dictionary = {}) -> String:
	var s: String = TranslationServer.translate(key)
	if params.is_empty():
		return s
	return s.format(params)
