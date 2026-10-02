extends Node
## Autoload « Game » : détient la partie en cours (GameModel), fait avancer le temps réel,
## gère la sauvegarde/chargement et la progression hors ligne. Passif tant qu'aucune partie
## n'est lancée (les tests headless n'en dépendent pas).

signal model_changed
signal hour_passed
signal game_event(ev: Dictionary)
signal offline_report_ready(report: Dictionary)

const SAVE_PATH: String = "user://saves/slot1.json"
const AUTOSAVE_SECONDS: float = 30.0
const SPEEDS: Array[float] = [0.0, 1.0, 2.0, 4.0]

var model: GameModel = null
var running: bool = false
var speed_index: int = 1
var _acc: float = 0.0
var _autosave_acc: float = 0.0
var last_offline_report: Dictionary = {}
## Nombre de fenêtres modales (dialogues, rapports) qui suspendent le temps.
var hold: int = 0
## Faux pendant les visites automatiques (captures, vidéo) : la sauvegarde du joueur n'est jamais touchée.
var persist: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func new_game(story: bool, seed_value: int = -1) -> void:
	var s: int = seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	_set_model(GameModel.create(Content.db, s, story))
	running = true
	save()


func load_game() -> bool:
	var data: Dictionary = SaveCodec.read_file(SAVE_PATH)
	if data.is_empty():
		return false
	var m: GameModel = SaveCodec.from_dict(Content.db, data)
	_set_model(m)
	var elapsed: float = maxf(0.0, Time.get_unix_time_from_system() - float(data.get("saved_at", 0)))
	last_offline_report = OfflineSim.run(m, elapsed)
	running = true
	if int(last_offline_report.get("hours", 0)) > 0:
		offline_report_ready.emit(last_offline_report)
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


func _set_model(m: GameModel) -> void:
	if model != null and model.game_event.is_connected(_on_model_event):
		model.game_event.disconnect(_on_model_event)
	model = m
	model.game_event.connect(_on_model_event)
	_acc = 0.0
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
	if hold > 0:
		return
	var sph: float = Content.db.cfgf("time", "seconds_per_hour", 4.0)
	_acc += delta * speed()
	var guard: int = 0
	while _acc >= sph and guard < 48:
		_acc -= sph
		model.advance_hour()
		hour_passed.emit()
		guard += 1


## Fraction de l'heure en cours (animations).
func hour_fraction() -> float:
	return clampf(_acc / Content.db.cfgf("time", "seconds_per_hour", 4.0), 0.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and model != null and running:
		save()
