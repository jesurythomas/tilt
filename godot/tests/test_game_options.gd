## test_game_options.gd
## PORTS: nothing — new file, covers src/meta/game_options.gd
extends GutTest
## Proves the default settings, the mode catalog, the shake multiplier, the
## settings save round trip in the TS shape, and the corrupt fallback.


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _write_raw(text: String) -> void:
	var file: FileAccess = FileAccess.open(GameOptionsManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func before_each() -> void:
	_remove(GameOptionsManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GameOptionsManager.SAVE_PATH))


func after_each() -> void:
	_remove(GameOptionsManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GameOptionsManager.SAVE_PATH))


func test_defaults() -> void:
	var o: GameOptionsManager = GameOptionsManager.new()
	assert_eq(o.settings.mode, Types.GameMode.CLASSIC, "GameOptions.ts:79")
	assert_eq(o.settings.control_scheme, Types.ControlScheme.HYBRID, ":80")
	assert_true(o.settings.sfx_enabled)
	assert_almost_eq(o.settings.sfx_volume, 0.8, 0.0001, ":82")
	assert_true(o.settings.music_enabled)
	assert_almost_eq(o.settings.music_volume, 0.7, 0.0001, ":84")
	assert_eq(o.settings.screen_shake, GameOptionsManager.ScreenShake.NORMAL, ":85")
	assert_true(o.settings.tether_line)
	assert_true(o.settings.high_contrast_halo)
	assert_false(o.settings.show_gridlines, ":88")


func test_mode_catalog_and_lookup() -> void:
	var o: GameOptionsManager = GameOptionsManager.new()
	assert_eq(o.modes.size(), 3)
	assert_eq(
		o.modes[0].id,
		Types.GameMode.CLASSIC,
		"catalog order is classic, gauntlet, code-red (:37-71)"
	)
	assert_eq(o.modes[1].id, Types.GameMode.GAUNTLET)
	assert_eq(o.modes[2].id, Types.GameMode.CODE_RED)
	assert_eq(o.get_mode_config(Types.GameMode.CLASSIC).name, "Standard")
	assert_almost_eq(
		o.get_mode_config(Types.GameMode.GAUNTLET).score_multiplier, 1.25, 0.0001, ":58"
	)
	assert_almost_eq(
		o.get_mode_config(Types.GameMode.CODE_RED).score_multiplier, 1.5, 0.0001, ":69"
	)
	assert_eq(o.get_mode_config(Types.GameMode.CODE_RED).badge, "1.5×")
	assert_eq(
		o.get_mode_config(o.settings.mode).id, Types.GameMode.CLASSIC, "the TS default arg (:113)"
	)


func test_set_mode_saves_and_survives_restart() -> void:
	var o: GameOptionsManager = GameOptionsManager.new()
	o.set_mode(Types.GameMode.CODE_RED)
	assert_eq(o.settings.mode, Types.GameMode.CODE_RED)
	assert_true(FileAccess.file_exists(GameOptionsManager.SAVE_PATH), "setMode saves (:119)")
	var again: GameOptionsManager = GameOptionsManager.new()
	assert_eq(again.settings.mode, Types.GameMode.CODE_RED)


func test_shake_multiplier() -> void:
	var o: GameOptionsManager = GameOptionsManager.new()
	o.settings.screen_shake = GameOptionsManager.ScreenShake.OFF
	assert_almost_eq(o.get_shake_multiplier(), 0.0, 0.0001, ":125")
	o.settings.screen_shake = GameOptionsManager.ScreenShake.LOW
	assert_almost_eq(o.get_shake_multiplier(), 0.5, 0.0001, ":127")
	o.settings.screen_shake = GameOptionsManager.ScreenShake.NORMAL
	assert_almost_eq(o.get_shake_multiplier(), 1.0, 0.0001, ":130")
	o.settings.screen_shake = GameOptionsManager.ScreenShake.FULL
	assert_almost_eq(o.get_shake_multiplier(), 1.0, 0.0001, "'full' shares 'normal' (:129)")
	o.settings.screen_shake = GameOptionsManager.ScreenShake.EXTREME
	assert_almost_eq(o.get_shake_multiplier(), 1.8, 0.0001, ":132")


func test_file_uses_the_typescript_strings_and_keys() -> void:
	var o: GameOptionsManager = GameOptionsManager.new()
	o.settings.mode = Types.GameMode.CODE_RED
	o.settings.control_scheme = Types.ControlScheme.GYRO
	o.settings.screen_shake = GameOptionsManager.ScreenShake.EXTREME
	o.settings.show_gridlines = true
	o.save()
	var file: FileAccess = FileAccess.open(GameOptionsManager.SAVE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	assert_true(text.contains('"mode":"code-red"'), "GameMode strings (:5)")
	assert_true(text.contains('"controlScheme":"gyro"'), ":21")
	assert_true(text.contains('"screenShake":"extreme"'), ":26")
	assert_true(text.contains('"showGridlines":true'))
	assert_true(text.contains('"musicVolume"'))
	var again: GameOptionsManager = GameOptionsManager.new()
	assert_eq(again.settings.mode, Types.GameMode.CODE_RED)
	assert_eq(again.settings.control_scheme, Types.ControlScheme.GYRO)
	assert_eq(again.settings.screen_shake, GameOptionsManager.ScreenShake.EXTREME)
	assert_true(again.settings.show_gridlines)


func test_web_shaped_partial_file_merges_over_defaults() -> void:
	_write_raw('{"mode": "gauntlet", "sfxVolume": 0.25, "screenShake": "bogus"}')
	var o: GameOptionsManager = GameOptionsManager.new()
	assert_eq(o.settings.mode, Types.GameMode.GAUNTLET)
	assert_almost_eq(o.settings.sfx_volume, 0.25, 0.0001)
	assert_almost_eq(o.settings.music_volume, 0.7, 0.0001, "absent keeps default (:98)")
	assert_eq(
		o.settings.screen_shake,
		GameOptionsManager.ScreenShake.NORMAL,
		"unknown string keeps default"
	)
	assert_false(o.settings.show_gridlines, "=== true only (:100)")


func test_show_gridlines_is_true_only_for_a_json_true() -> void:
	_write_raw('{"showGridlines": 1}')
	assert_false(GameOptionsManager.new().settings.show_gridlines, ":100")
	_remove(GameOptionsManager.SAVE_PATH)
	_write_raw('{"showGridlines": true}')
	assert_true(GameOptionsManager.new().settings.show_gridlines)


func test_corrupt_settings_file_falls_back_and_is_backed_up() -> void:
	_write_raw('{"mode": ')
	var o: GameOptionsManager = GameOptionsManager.new()
	assert_eq(o.settings.mode, Types.GameMode.CLASSIC)
	assert_true(FileAccess.file_exists(SaveStore.corrupt_path_for(GameOptionsManager.SAVE_PATH)))
