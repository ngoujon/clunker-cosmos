extends Node
## Autoload « Game » : détient la partie en cours (GameModel), fait avancer le temps réel et gère
## la sauvegarde. Jeu de gestion, pas un idle : rien n'avance quand le jeu est fermé, et le temps
## se suspend aussi quand la fenêtre n'est plus active ou après quelques minutes d'inactivité
## (réglages du joueur). Passif tant qu'aucune partie n'est lancée (les tests headless n'en dépendent pas).

signal model_changed
signal hour_passed
signal game_event(ev: Dictionary)
## Pause automatique : raison "focus" ou "idle", "" à la reprise.
signal away_changed(reason: String)

const SAVE_PATH: String = "user://saves/slot1.json"
## Ancien nom du projet (dossier de données utilisateur avant le renommage en « Clunker Cosmos »).
const LEGACY_DIR_NAME: String = "Wreck & Resell"
const AUTOSAVE_SECONDS: float = 30.0
const SPEEDS: Array[float] = [0.0, 1.0, 2.0, 4.0]

var model: GameModel = null
var running: bool = false
var speed_index: int = 1
var _acc: float = 0.0
var _autosave_acc: float = 0.0
## Nombre de fenêtres modales (dialogues, rapports) qui suspendent le temps.
var hold: int = 0
## Faux pendant les visites automatiques (captures, vidéo) : la sauvegarde et les réglages du joueur
## ne sont jamais touchés et les pauses automatiques sont désactivées.
var persist: bool = true
var settings: GameSettings = null
## Pause automatique en cours ("" : aucune).
var away: String = ""
var _focused: bool = true
var _idle_seconds: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = GameSettings.load_file()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Premier lancement après le renommage du jeu : copie la sauvegarde de l'ancien dossier de données
## (« Wreck & Resell ») dans le nouveau. L'original n'est ni modifié ni supprimé. Appelé uniquement au
## démarrage normal (jamais pendant les tests ou les visites automatiques).
func import_legacy_save() -> bool:
	if not persist or has_save():
		return false
	var legacy: String = OS.get_user_data_dir().get_base_dir().path_join(LEGACY_DIR_NAME).path_join("saves/slot1.json")
	if not FileAccess.file_exists(legacy):
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	return DirAccess.copy_absolute(legacy, ProjectSettings.globalize_path(SAVE_PATH)) == OK


func save_settings() -> void:
	if persist:
		settings.save_file()


func new_game(story: bool, seed_value: int = -1) -> void:
	var s: int = seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	_set_model(GameModel.create(Content.db, s, story))
	running = true
	save()


## Recharge la partie exactement où elle en était : le temps ne s'écoule pas jeu fermé.
func load_game() -> bool:
	var data: Dictionary = SaveCodec.read_file(SAVE_PATH)
	if data.is_empty():
		return false
	_set_model(SaveCodec.from_dict(Content.db, data))
	running = true
	return true


## Utilisé par les captures et la démo : remplace la partie courante par un modèle préparé.
func use_model(m: GameModel) -> void:
	_set_model(m)
	running = true


func stop() -> void:
	if model != null and model.game_event.is_connected(_on_model_event):
		model.game_event.disconnect(_on_model_event)
	running = false
	model = null
	hold = 0
	_set_away("")


func _set_model(m: GameModel) -> void:
	if model != null and model.game_event.is_connected(_on_model_event):
		model.game_event.disconnect(_on_model_event)
	model = m
	model.game_event.connect(_on_model_event)
	_acc = 0.0
	_idle_seconds = 0.0
	model_changed.emit()


func _on_model_event(ev: Dictionary) -> void:
	game_event.emit(ev)


func save() -> void:
	if model != null and persist:
		SaveCodec.save_file(model, SAVE_PATH)


func speed() -> float:
	return SPEEDS[speed_index]


func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)


func _process(delta: float) -> void:
	if model == null or not running:
		return
	_autosave_acc += delta
	if _autosave_acc >= AUTOSAVE_SECONDS:
		_autosave_acc = 0.0
		save()
	_update_away(delta)
	if hold > 0 or not away.is_empty():
		return
	var sph: float = Content.db.cfgf("time", "seconds_per_hour", 4.0)
	_acc += delta * speed()
	var guard: int = 0
	while _acc >= sph and guard < 48:
		_acc -= sph
		model.advance_hour()
		hour_passed.emit()
		guard += 1


## Pauses automatiques (partie du joueur uniquement, jamais pendant les visites automatiques).
func _update_away(delta: float) -> void:
	if not persist or settings == null:
		return
	_idle_seconds += delta
	var reason: String = settings.should_pause(_focused, _idle_seconds)
	if reason.is_empty():
		_set_away("")
	elif away.is_empty() and speed_index > 0 and hold == 0:
		# Le temps tournait : on le suspend (déjà en pause, rien à faire).
		_set_away(reason)


func _set_away(reason: String) -> void:
	if reason == away:
		return
	away = reason
	if reason.is_empty():
		_idle_seconds = 0.0
	else:
		save()
	away_changed.emit(away)


## Toute action du joueur (souris, clavier, manette) remet à zéro le compteur d'inactivité.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch:
		_idle_seconds = 0.0
		if away == "idle":
			_set_away("")


## Fraction de l'heure en cours (animations).
func hour_fraction() -> float:
	return clampf(_acc / Content.db.cfgf("time", "seconds_per_hour", 4.0), 0.0, 1.0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_idle_seconds = 0.0
		NOTIFICATION_WM_CLOSE_REQUEST:
			if model != null and running:
				save()
