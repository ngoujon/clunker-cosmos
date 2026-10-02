class_name GameSettings
extends RefCounted
## Réglages du joueur (user://settings.cfg) : affichage, audio, langue, pauses automatiques.
## Logique pure : conversion depuis/vers un ConfigFile avec valeurs bornées ; l'application
## (fenêtre, bus audio, langue) est faite par l'interface et l'autoload Audio.

const PATH: String = "user://settings.cfg"
## Pause après inactivité : choix proposés, en minutes (0 = jamais).
const IDLE_CHOICES: PackedInt32Array = [0, 2, 5, 10]
const LOCALES: PackedStringArray = ["fr", "en"]

## Plein écran par défaut au premier lancement.
var fullscreen: bool = true
var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.8
## Vide : langue du système (français si le système est en français, anglais sinon).
var locale: String = ""
## Le temps s'arrête quand la fenêtre n'est plus active (autre application, fenêtre réduite).
var pause_on_focus_loss: bool = true
## Le temps s'arrête après ce nombre de minutes sans souris ni clavier (0 = jamais).
var idle_pause_minutes: int = 5


static func from_config(cfg: ConfigFile) -> GameSettings:
	var s: GameSettings = GameSettings.new()
	s.fullscreen = bool(cfg.get_value("display", "fullscreen", s.fullscreen))
	s.master_volume = _volume(cfg.get_value("audio", "master", s.master_volume), s.master_volume)
	s.music_volume = _volume(cfg.get_value("audio", "music", s.music_volume), s.music_volume)
	s.sfx_volume = _volume(cfg.get_value("audio", "sfx", s.sfx_volume), s.sfx_volume)
	var loc: String = str(cfg.get_value("general", "locale", ""))
	s.locale = loc if loc in LOCALES else ""
	s.pause_on_focus_loss = bool(cfg.get_value("game", "pause_on_focus_loss", s.pause_on_focus_loss))
	var idle: Variant = cfg.get_value("game", "idle_pause_minutes", s.idle_pause_minutes)
	s.idle_pause_minutes = int(idle) if (idle is int or idle is float) and int(idle) in IDLE_CHOICES else s.idle_pause_minutes
	return s


func to_config(cfg: ConfigFile) -> void:
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	if not locale.is_empty():
		cfg.set_value("general", "locale", locale)
	cfg.set_value("game", "pause_on_focus_loss", pause_on_focus_loss)
	cfg.set_value("game", "idle_pause_minutes", idle_pause_minutes)


static func load_file(path: String = PATH) -> GameSettings:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return GameSettings.new()
	return from_config(cfg)


## Écrit les réglages en conservant les clés inconnues du fichier existant.
func save_file(path: String = PATH) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(path)
	to_config(cfg)
	return cfg.save(path)


static func _volume(v: Variant, fallback: float) -> float:
	if v is float or v is int:
		return clampf(float(v), 0.0, 1.0)
	return fallback


## Volume linéaire (0-1) → décibels pour un bus audio (silence complet à 0).
static func volume_db(linear: float) -> float:
	return -80.0 if linear <= 0.001 else linear_to_db(clampf(linear, 0.0, 1.0))


## Choix suivant de la pause d'inactivité (cycle Jamais → 2 → 5 → 10 → Jamais).
static func next_idle_choice(current: int) -> int:
	var i: int = IDLE_CHOICES.find(current)
	return IDLE_CHOICES[(i + 1) % IDLE_CHOICES.size()]


## Faut-il suspendre le temps ? `reason` : "focus" (fenêtre inactive) ou "idle" (inactivité).
func should_pause(focused: bool, idle_seconds: float) -> String:
	if pause_on_focus_loss and not focused:
		return "focus"
	if idle_pause_minutes > 0 and idle_seconds >= float(idle_pause_minutes) * 60.0:
		return "idle"
	return ""
