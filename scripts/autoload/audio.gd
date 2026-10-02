extends Node
## Autoload « Audio » : bus « Music » et « SFX » créés au démarrage, musique par listes de lecture
## avec fondus enchaînés, bruitages courts joués par un petit groupe de lecteurs.
## Fichiers : assets/audio/music/<id>.ogg (ACE-Step 1.5, généré localement) et
## assets/audio/sfx/<id>.wav (synthèse procédurale, tools/sfx_synth.py). Un fichier absent est ignoré.

const MUSIC_DIR: String = "res://assets/audio/music/"
const SFX_DIR: String = "res://assets/audio/sfx/"
const PLAYLISTS: Dictionary = {
	"title": ["title"],
	"garage": ["garage_a", "garage_b", "garage_c"],
}
const FADE_SECONDS: float = 1.5
const POOL_SIZE: int = 10
## Intervalle minimal entre deux lectures du même bruitage (rafales d'événements à vitesse ×4).
const MIN_INTERVAL_MS: int = 70
## Réglage de niveau par bruitage (dB) : clics et survols discrets, jingles présents.
const SFX_GAIN: Dictionary = {
	"ui_hover": -14.0, "ui_click": -6.0, "ui_tab": -6.0, "ui_toggle": -6.0, "speed": -6.0,
	"blip_bolt": -12.0, "blip_odile": -12.0, "blip_lustre": -12.0, "blip_inspector": -12.0, "blip_npc": -12.0,
	"day_start": -4.0, "notify": -4.0, "scan": -3.0,
}

## Faux en headless (tests) et pendant les captures d'écran : aucun son n'est joué.
var enabled: bool = true
## Vrai pendant la bande-annonce : play_music() n'interrompt pas le morceau en cours.
var music_locked: bool = false
var _music: Array[AudioStreamPlayer] = []
var _active: int = 0
var _playlist: String = ""
var _track: int = -1
var _sfx: Array[AudioStreamPlayer] = []
var _jingle: AudioStreamPlayer = null
var _cache: Dictionary = {}
var _last_ms: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.get_name() != "headless"
	_rng.randomize()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i: int in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		p.finished.connect(_on_track_finished.bind(i))
		add_child(p)
		_music.append(p)
	_jingle = AudioStreamPlayer.new()
	_jingle.bus = "Music"
	add_child(_jingle)
	for i: int in POOL_SIZE:
		var s: AudioStreamPlayer = AudioStreamPlayer.new()
		s.bus = "SFX"
		add_child(s)
		_sfx.append(s)
	apply_volumes(Game.settings)


## Coupe immédiatement tous les sons et libère les flux. À appeler quelques images avant de quitter :
## le serveur audio libère les lectures arrêtées de façon différée (sinon Godot signale des lectures
## encore actives et des ressources « toujours utilisées » à la fermeture).
func stop_all() -> void:
	_playlist = ""
	for p: AudioStreamPlayer in _music + _sfx + [_jingle]:
		if p != null:
			p.stop()
			p.stream = null
	_cache.clear()


func _exit_tree() -> void:
	stop_all()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func apply_volumes(s: GameSettings) -> void:
	if s == null:
		return
	_set_bus("Master", s.master_volume)
	_set_bus("Music", s.music_volume)
	_set_bus("SFX", s.sfx_volume)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, GameSettings.volume_db(linear))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path) as AudioStream
	_cache[path] = st
	return st


func has_sfx(id: String) -> bool:
	return _load(SFX_DIR + id + ".wav") != null


# --- Musique -----------------------------------------------------------------------

## Lance une liste de lecture ("title", "garage") ; sans effet si elle joue déjà.
func play_music(playlist: String) -> void:
	if not enabled or music_locked or playlist == _playlist or not PLAYLISTS.has(playlist):
		return
	_playlist = playlist
	var tracks: Array = PLAYLISTS[playlist]
	_track = _rng.randi_range(0, tracks.size() - 1)
	_start_track()


func stop_music(fade: float = FADE_SECONDS) -> void:
	_playlist = ""
	for p: AudioStreamPlayer in _music:
		if p.playing:
			var tw: Tween = create_tween()
			tw.tween_property(p, "volume_db", -80.0, fade)
			tw.tween_callback(p.stop)


func current_playlist() -> String:
	return _playlist


func _start_track() -> void:
	var tracks: Array = PLAYLISTS[_playlist]
	var st: AudioStream = null
	for i: int in tracks.size():
		st = _load(MUSIC_DIR + str(tracks[(_track + i) % tracks.size()]) + ".ogg")
		if st != null:
			_track = (_track + i) % tracks.size()
			break
	if st == null:
		return
	if st is AudioStreamOggVorbis:
		# Une liste d'un seul morceau boucle ; sinon on enchaîne le suivant à la fin.
		(st as AudioStreamOggVorbis).loop = tracks.size() == 1
	var old: AudioStreamPlayer = _music[_active]
	_active = 1 - _active
	var p: AudioStreamPlayer = _music[_active]
	p.stream = st
	p.volume_db = -40.0
	p.play()
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(p, "volume_db", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, FADE_SECONDS)
		tw.chain().tween_callback(old.stop)


func _on_track_finished(i: int) -> void:
	if i != _active or _playlist.is_empty():
		return
	var tracks: Array = PLAYLISTS[_playlist]
	_track = (_track + 1) % tracks.size()
	_start_track()


## Courte fanfare (fin de chapitre, dette remboursée) : la musique s'efface le temps du jingle.
func play_jingle(id: String) -> void:
	if not enabled:
		return
	var st: AudioStream = _load(MUSIC_DIR + id + ".ogg")
	if st == null:
		return
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = false
	_jingle.stream = st
	_jingle.play()
	var p: AudioStreamPlayer = _music[_active]
	if p.playing:
		var tw: Tween = create_tween()
		tw.tween_property(p, "volume_db", -18.0, 0.3)
		tw.tween_interval(maxf(0.5, st.get_length() - 1.0))
		tw.tween_property(p, "volume_db", 0.0, 1.5)


# --- Bruitages ------------------------------------------------------------------------

## Joue un bruitage court ; `pitch_jitter` varie légèrement la hauteur (bips de dialogue, clics).
func play(id: String, pitch_jitter: float = 0.0, gain_db: float = 0.0) -> void:
	if not enabled:
		return
	var st: AudioStream = _load(SFX_DIR + id + ".wav")
	if st == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -100000)) < MIN_INTERVAL_MS:
		return
	_last_ms[id] = now
	var p: AudioStreamPlayer = null
	for s: AudioStreamPlayer in _sfx:
		if not s.playing:
			p = s
			break
	if p == null:
		p = _sfx[0]
		_sfx.push_back(_sfx.pop_front())
	p.stream = st
	p.volume_db = float(SFX_GAIN.get(id, 0.0)) + gain_db
	p.pitch_scale = 1.0 + (_rng.randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 0.0)
	p.play()
