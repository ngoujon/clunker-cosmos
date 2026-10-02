extends TestCase
## Réglages du joueur : valeurs par défaut, aller-retour ConfigFile, bornes, pauses automatiques.
## (Aucune écriture sur disque : uniquement des ConfigFile en mémoire.)


func test_defaults() -> void:
	var s: GameSettings = GameSettings.from_config(ConfigFile.new())
	check(s.fullscreen, "plein écran au premier lancement")
	check(s.pause_on_focus_loss, "pause quand la fenêtre perd le focus")
	eq(s.idle_pause_minutes, 5, "pause après 5 min d'inactivité")
	eq(s.locale, "", "langue du système")
	check(s.master_volume > 0.0 and s.music_volume > 0.0 and s.sfx_volume > 0.0, "son actif")


func test_roundtrip() -> void:
	var s: GameSettings = GameSettings.new()
	s.fullscreen = false
	s.master_volume = 0.5
	s.music_volume = 0.25
	s.sfx_volume = 1.0
	s.locale = "en"
	s.pause_on_focus_loss = false
	s.idle_pause_minutes = 10
	var cfg: ConfigFile = ConfigFile.new()
	s.to_config(cfg)
	var r: GameSettings = GameSettings.from_config(cfg)
	check(not r.fullscreen, "fenêtré")
	near(r.master_volume, 0.5, 0.0001, "volume général")
	near(r.music_volume, 0.25, 0.0001, "musique")
	near(r.sfx_volume, 1.0, 0.0001, "bruitages")
	eq(r.locale, "en", "langue")
	check(not r.pause_on_focus_loss, "pause de focus désactivée")
	eq(r.idle_pause_minutes, 10, "inactivité")


func test_invalid_values_are_clamped_or_ignored() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "master", 3.5)
	cfg.set_value("audio", "music", -1.0)
	cfg.set_value("audio", "sfx", "fort")
	cfg.set_value("general", "locale", "tlh")
	cfg.set_value("game", "idle_pause_minutes", 7)
	var s: GameSettings = GameSettings.from_config(cfg)
	near(s.master_volume, 1.0, 0.0001, "borné à 1")
	near(s.music_volume, 0.0, 0.0001, "borné à 0")
	near(s.sfx_volume, GameSettings.new().sfx_volume, 0.0001, "valeur invalide ignorée")
	eq(s.locale, "", "langue inconnue ignorée")
	eq(s.idle_pause_minutes, GameSettings.new().idle_pause_minutes, "durée hors choix ignorée")


func test_keeps_locale_key_of_i18n() -> void:
	# I18n écrit general/locale dans le même fichier : les deux restent compatibles.
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("general", "locale", "fr")
	var s: GameSettings = GameSettings.from_config(cfg)
	eq(s.locale, "fr", "langue relue")
	s.to_config(cfg)
	eq(str(cfg.get_value("general", "locale", "")), "fr", "langue conservée")


func test_volume_db() -> void:
	near(GameSettings.volume_db(1.0), 0.0, 0.001, "plein volume = 0 dB")
	check(GameSettings.volume_db(0.0) <= -79.0, "volume nul = silence")
	check(GameSettings.volume_db(0.5) < 0.0 and GameSettings.volume_db(0.5) > -10.0, "moitié ≈ -6 dB")


func test_idle_choices_cycle() -> void:
	var seen: Array[int] = []
	var v: int = 0
	for i: int in GameSettings.IDLE_CHOICES.size():
		v = GameSettings.next_idle_choice(v)
		seen.append(v)
	eq(seen.back(), 0, "le cycle revient à « jamais »")
	eq(seen.size(), GameSettings.IDLE_CHOICES.size(), "tous les choix parcourus")


func test_should_pause() -> void:
	var s: GameSettings = GameSettings.new()
	eq(s.should_pause(true, 0.0), "", "joueur présent")
	eq(s.should_pause(false, 0.0), "focus", "fenêtre inactive")
	eq(s.should_pause(true, 5.0 * 60.0), "idle", "5 min sans activité")
	eq(s.should_pause(true, 4.9 * 60.0), "", "pas encore")
	s.pause_on_focus_loss = false
	s.idle_pause_minutes = 0
	eq(s.should_pause(false, 1.0e6), "", "pauses automatiques désactivées")
