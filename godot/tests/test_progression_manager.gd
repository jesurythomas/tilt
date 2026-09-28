## test_progression_manager.gd
## PORTS: nothing — new file, covers load/save in src/meta/progression_manager.gd
extends GutTest
## Proves the save round trip, the deep merge with defaults, the two points
## floors, list de-duplication, and the corrupt-file fallback (spec §6.4).


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _write_raw(text: String) -> void:
	var file: FileAccess = FileAccess.open(ProgressionManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_raw() -> String:
	var file: FileAccess = FileAccess.open(ProgressionManager.SAVE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	return text


func before_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))


func after_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))


func test_no_file_gives_the_defaults_and_writes_nothing() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	assert_eq(pm.data.points, 500, "DIVERGENCE(ECON R3) start balance (TS 7331, :423)")
	assert_eq(pm.data.lifetime_points, 500)
	assert_eq(pm.data.perks.blackhole.duration, 3, ":427")
	assert_eq(pm.data.perks.missiles.count, 5, ":444")
	assert_eq(pm.data.unlocked_cursors, ["classic", "tactical", "singularity"])
	assert_eq(pm.data.equipped_arena_theme_id, "void")
	assert_almost_eq(pm.data.tuning.deadzone, 4.0, 0.0001)
	assert_false(FileAccess.file_exists(ProgressionManager.SAVE_PATH), "load never writes")


func test_save_then_fresh_instance_reads_the_same_data() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	pm.data.points = 9000
	pm.data.lifetime_points = 20000
	pm.data.perks.nuke.radius = 4
	pm.data.perks.laser.cross_beam = true
	pm.data.unlocked_cursors.append("solar")
	pm.data.equipped_cursor_id = "solar"
	pm.data.tuning.deadzone = 8.0
	pm.data.extra_lives = 2
	pm.save()

	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.points, 9000)
	assert_eq(again.data.lifetime_points, 20000)
	assert_eq(again.data.perks.nuke.radius, 4)
	assert_true(again.data.perks.laser.cross_beam)
	assert_eq(again.data.unlocked_cursors, ["classic", "tactical", "singularity", "solar"])
	assert_eq(again.data.equipped_cursor_id, "solar")
	assert_almost_eq(again.data.tuning.deadzone, 8.0, 0.0001)
	assert_eq(again.data.extra_lives, 2)


func test_file_on_disk_uses_the_typescript_key_spellings() -> void:
	ProgressionManager.new().save()
	var text: String = _read_raw()
	for key: String in [
		"lifetimePoints",
		"equippedCursorId",
		"unlockedEnemySkins",
		"equippedArenaThemeId",
		"invulnerableInside",
		"blastRadius",
		"maxTargets",
		"shatterCascade",
		"extraLives",
		"pointsMultiplier",
	]:
		assert_true(text.contains('"%s"' % key), "spec §4.6: key %s" % key)
	assert_false(text.contains("lifetime_points"), "no snake_case leaks into the file")


func test_partial_web_save_merges_over_defaults() -> void:
	_write_raw(
		"""{"points": 12000, "perks": {"laser": {"crossBeam": true}},
		"unlockedCursors": ["cyber"], "tuning": {"sensitivity": 1.5}}"""
	)
	var pm: ProgressionManager = ProgressionManager.new()
	assert_eq(pm.data.points, 12000)
	assert_eq(pm.data.lifetime_points, 12000, "absent -> at least the balance (ECON R3)")
	assert_true(pm.data.perks.laser.cross_beam, "present key wins")
	assert_eq(pm.data.perks.laser.length, 2, "absent sibling keeps the default (:500)")
	assert_eq(pm.data.perks.blackhole.gravity, 4, "absent weapon keeps the default (:496)")
	assert_eq(
		pm.data.unlocked_cursors,
		["classic", "tactical", "singularity", "cyber"],
		"the three free ships are always unlocked (:504)"
	)
	assert_almost_eq(pm.data.tuning.sensitivity, 1.5, 0.0001)
	assert_almost_eq(pm.data.tuning.deadzone, 4.0, 0.0001, "absent tuning key keeps default (:507)")


func test_low_balances_are_kept() -> void:
	# DIVERGENCE(ECON R3): the TS reset points < 500 to 7331 and floored lifetime
	# points at 7331 (:491-492); saved figures now stand.
	_write_raw('{"points": 100, "lifetimePoints": 10}')
	var low: ProgressionManager = ProgressionManager.new()
	assert_eq(low.data.points, 100)
	assert_eq(low.data.lifetime_points, 100, "never below the balance")
	_remove(ProgressionManager.SAVE_PATH)

	_write_raw('{"points": 500, "lifetimePoints": 20000}')
	var ok: ProgressionManager = ProgressionManager.new()
	assert_eq(ok.data.points, 500, "exactly 500 is kept")
	assert_eq(ok.data.lifetime_points, 20000)
	_remove(ProgressionManager.SAVE_PATH)

	_write_raw('{"points": 0}')
	var zero: ProgressionManager = ProgressionManager.new()
	assert_eq(zero.data.points, 0, "a spent-out save stays spent")


func test_unlocked_lists_are_deduplicated_in_order() -> void:
	_write_raw(
		"""{"unlockedEnemySkins": ["gold", "classic", "gold"],
		"unlockedArenaThemes": ["nebula", "void"], "unlockedCursors": ["classic", "solar", "solar"]}"""
	)
	var pm: ProgressionManager = ProgressionManager.new()
	assert_eq(
		pm.data.unlocked_enemy_skins, ["classic", "gold"], "Set keeps first occurrence (:505)"
	)
	assert_eq(pm.data.unlocked_arena_themes, ["void", "nebula"], ":506")
	assert_eq(pm.data.unlocked_cursors, ["classic", "tactical", "singularity", "solar"])


func test_wrong_types_keep_the_defaults() -> void:
	_write_raw('{"points": "lots", "tuning": {"deadzone": "x"}, "perks": 5}')
	var pm: ProgressionManager = ProgressionManager.new()
	assert_eq(pm.data.points, ProgressionManager.STARTING_POINTS, "a non-number keeps the default")
	assert_almost_eq(pm.data.tuning.deadzone, 4.0, 0.0001)
	assert_eq(pm.data.perks.blackhole.duration, 3, "a non-object perks block is ignored")


func test_corrupt_file_falls_back_to_defaults_and_is_backed_up() -> void:
	_write_raw('{"points": 999999, oops')
	var pm: ProgressionManager = ProgressionManager.new()
	assert_eq(
		pm.data.points, ProgressionManager.STARTING_POINTS, "spec §6.4: defaults, never a crash"
	)
	var backup: String = SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH)
	assert_true(FileAccess.file_exists(backup), "the bad file is kept")
	assert_false(FileAccess.file_exists(ProgressionManager.SAVE_PATH), "and moved out of the way")
	pm.save()
	assert_true(FileAccess.file_exists(ProgressionManager.SAVE_PATH), "the next save is clean")
	assert_true(FileAccess.file_exists(backup), "and does not touch the backup")
