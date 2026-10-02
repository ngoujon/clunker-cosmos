extends Node
## Autoload « I18n » : construit les traductions FR/EN à partir des textes du contenu
## et gère la langue courante (persistée dans user://settings.cfg).

const SETTINGS_PATH: String = "user://settings.cfg"
const LOCALES: PackedStringArray = ["fr", "en"]

signal locale_changed(locale: String)

var locale: String = "fr"


func _ready() -> void:
	build()
	var cfg: ConfigFile = ConfigFile.new()
	var loc: String = ""
	if cfg.load(SETTINGS_PATH) == OK:
		loc = str(cfg.get_value("general", "locale", ""))
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
	if persist:
		var cfg: ConfigFile = ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("general", "locale", locale)
		cfg.save(SETTINGS_PATH)
	locale_changed.emit(locale)


func toggle() -> void:
	set_locale("en" if locale == "fr" else "fr")


## tr() + remplacement des {paramètres}.
func t(key: String, params: Dictionary = {}) -> String:
	var s: String = TranslationServer.translate(key)
	if params.is_empty():
		return s
	return s.format(params)
