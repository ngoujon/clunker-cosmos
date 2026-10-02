extends TestCase
## Sauvegarde versionnée : aller-retour, déterminisme, fichiers, migration v1 → v2.


func _played(seed_value: int, days: int, story: bool = true) -> GameModel:
	var m: GameModel = new_model(seed_value, story)
	var ap: Autopilot = Autopilot.new()
	ap.play_hours(m, days * 24)
	return m


func _strip(d: Dictionary) -> String:
	var c: Dictionary = d.duplicate(true)
	c.erase("saved_at")
	return JSON.stringify(c)


func test_save_has_current_version() -> void:
	var m: GameModel = new_model()
	var d: Dictionary = SaveCodec.to_dict(m)
	eq(int(d["save_version"]), SaveCodec.VERSION, "version de sauvegarde")
	check(d.has("game_version") and d.has("saved_at"), "métadonnées")


## Jeu de gestion, pas un idle : rien n'avance pendant que le jeu est fermé, quelle que soit la date
## de la sauvegarde.
func test_load_never_advances_time() -> void:
	var m: GameModel = _played(6, 2)
	var d: Dictionary = SaveCodec.to_dict(m)
	d["saved_at"] = int(d["saved_at"]) - 30 * 24 * 3600
	var m2: GameModel = SaveCodec.from_dict(db, d)
	eq(m2.day, m.day, "même jour")
	eq(m2.hour, m.hour, "même heure")
	eq(m2.credits, m.credits, "mêmes crédits")
	eq(m2.ships.size(), m.ships.size(), "mêmes vaisseaux")
	check(m2.owner_online, "patron présent")


func test_roundtrip_preserves_state() -> void:
	var m: GameModel = _played(3, 4)
	var d1: Dictionary = SaveCodec.to_dict(m)
	var m2: GameModel = SaveCodec.from_dict(db, d1)
	var d2: Dictionary = SaveCodec.to_dict(m2)
	eq(_strip(d2), _strip(d1), "état identique après rechargement")
	eq(m2.ships.size(), m.ships.size(), "vaisseaux")
	eq(m2.staff.size(), m.staff.size(), "employés")


func test_roundtrip_continues_deterministically() -> void:
	var a: GameModel = _played(4, 3)
	var b: GameModel = SaveCodec.from_dict(db, SaveCodec.to_dict(a))
	var ap_a: Autopilot = Autopilot.new()
	var ap_b: Autopilot = Autopilot.new()
	ap_a.play_hours(a, 48)
	ap_b.play_hours(b, 48)
	eq(b.credits, a.credits, "même trésorerie après 2 jours")
	eq(b.counter("ships_sold"), a.counter("ships_sold"), "mêmes ventes")
	eq(b.rng.state, a.rng.state, "même état du générateur")


func test_save_and_load_file() -> void:
	var m: GameModel = _played(6, 2)
	var path: String = "user://tests/save_test.json"
	eq(SaveCodec.save_file(m, path), OK, "écriture")
	var m2: GameModel = SaveCodec.load_file(db, path)
	check(m2 != null, "relecture")
	if m2 == null:
		return
	eq(m2.credits, m.credits, "crédits")
	eq(m2.day, m.day, "jour")
	eq(m2.quest_state.size(), m.quest_state.size(), "état des quêtes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_load_missing_file_returns_null() -> void:
	check(SaveCodec.load_file(db, "user://does/not/exist.json") == null, "fichier absent")


func test_migration_from_v1() -> void:
	var v1: Dictionary = {
		"save_version": 1,
		"model": {
			"seed": 5, "day": 3, "hour": 10, "money": 1234, "rep": 55.0,
			"ships": [{"id": 2, "hull": "hull_cargo", "engine": "eng_ion", "cockpit": "cock_box", "wings": "wing_stub",
				"defects": [{"type": "d_rust", "sev": 1, "hidden": true}, {"type": "d_dent", "sev": 2, "hidden": false}]}],
		},
	}
	var migrated: Dictionary = SaveCodec.migrate(v1)
	eq(int(migrated["save_version"]), SaveCodec.VERSION, "version migrée")
	var m: GameModel = SaveCodec.from_dict(db, v1)
	eq(m.credits, 1234, "money → credits")
	near(m.reputation, 55.0, 0.001, "rep → reputation")
	eq(m.ships.size(), 1, "vaisseau conservé")
	check(not m.ships[0].defects[0].known, "hidden → known=false")
	check(m.ships[0].defects[1].known, "hidden=false → known")
	check(m.is_unlocked("location:ferropolis"), "déblocages par défaut reconstruits")
	m.advance_hours(30)
	eq(m.errors.size(), 0, "partie migrée jouable")


func test_settings_and_quests_survive() -> void:
	var m: GameModel = _played(8, 2)
	m.act_set_setting("defect_policy", "shark")
	var m2: GameModel = SaveCodec.from_dict(db, SaveCodec.to_dict(m))
	eq(str(m2.settings["defect_policy"]), "shark", "politique conservée")
	eq(QuestSystem.status(m2, "m1_01"), QuestSystem.status(m, "m1_01"), "statut de quête conservé")
