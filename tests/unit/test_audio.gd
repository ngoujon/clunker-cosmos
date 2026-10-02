extends TestCase
## Audio : chaque bruitage et chaque musique référencés par le code existent dans assets/audio.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"


func _sfx_exists(id: String) -> bool:
	return ResourceLoader.exists(SFX_DIR + id + ".wav")


func test_event_sounds_exist() -> void:
	var missing: Array[String] = []
	for et: String in MainUI.EVENT_SFX:
		var id: String = str(MainUI.EVENT_SFX[et])
		if not _sfx_exists(id) and not id in missing:
			missing.append(id)
	for id: String in ["paint", "option"]:
		if not _sfx_exists(id):
			missing.append(id)
	eq(missing.size(), 0, "bruitages d'événements manquants : %s" % str(missing))


func test_dialogue_blips_exist() -> void:
	var missing: Array[String] = []
	for sp: String in DialogueBox.BLIPS:
		if not _sfx_exists(str(DialogueBox.BLIPS[sp])):
			missing.append(str(DialogueBox.BLIPS[sp]))
	if not _sfx_exists("blip_npc"):
		missing.append("blip_npc")
	eq(missing.size(), 0, "bips de dialogue manquants : %s" % str(missing))


## Tous les identifiants littéraux passés à Audio.play(...) existent, ainsi que les bruitages de boutons
## (clic, survol, onglets, vitesse, ouverture, bascule : paramètre `sfx` de UIKit.button).
func test_literal_sound_ids_exist() -> void:
	var re_play: RegEx = RegEx.create_from_string("Audio\\.play\\(\"([a-z0-9_]+)\"")
	var missing: Array[String] = []
	for id: String in ["ui_click", "ui_hover", "ui_tab", "speed", "ui_open", "ui_close", "ui_toggle", "ui_error"]:
		if not _sfx_exists(id):
			missing.append(id)
	var n: int = 0
	for d: String in ["res://scripts/ui", "res://scripts/ui/screens", "res://scripts/autoload"]:
		for f: String in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"):
				continue
			var src: String = FileAccess.get_file_as_string(d + "/" + f)
			for mt: RegExMatch in re_play.search_all(src):
				n += 1
				var id: String = mt.get_string(1)
				if not _sfx_exists(id) and not id in missing:
					missing.append(id)
	ge(float(n), 5.0, "identifiants trouvés")
	eq(missing.size(), 0, "bruitages référencés mais absents : %s" % str(missing))


func test_playlists_exist() -> void:
	var missing: Array[String] = []
	for pl: String in Audio.PLAYLISTS:
		for track: Variant in Audio.PLAYLISTS[pl]:
			if not ResourceLoader.exists(MUSIC_DIR + str(track) + ".ogg"):
				missing.append(str(track))
	if not ResourceLoader.exists(MUSIC_DIR + "jingle_win.ogg"):
		missing.append("jingle_win")
	eq(missing.size(), 0, "musiques manquantes : %s" % str(missing))


func test_volume_settings_map_to_buses() -> void:
	for bus: String in ["Master", "Music", "SFX"]:
		check(AudioServer.get_bus_index(bus) >= 0, "bus %s" % bus)
