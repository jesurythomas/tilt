## test_control_settings.gd
## PORTS: nothing — new file, covers src/native/control_settings.gd
extends GutTest
## Covers round-trip persistence, clamping of hand-edited values, and the
## defensive fallbacks required by M2.5 spec §4.1.


func _remove_settings_file() -> void:
	var path: String = ProjectSettings.globalize_path(ControlSettings.SETTINGS_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func before_each() -> void:
	_remove_settings_file()


func after_each() -> void:
	_remove_settings_file()


func test_defaults_when_no_file_exists() -> void:
	var settings: ControlSettings = ControlSettings.new()
	assert_almost_eq(
		settings.tilt_sensitivity,
		1.0,
		0.0001,
		"sensitivity 1.0 reproduces the cited MAX_TILT_ANGLE"
	)
	assert_true(
		settings.scheme == Types.ControlScheme.GYRO or settings.scheme == Types.ControlScheme.MOUSE,
		"default scheme is GYRO on mobile, MOUSE elsewhere"
	)


func test_settings_round_trip_through_the_user_file() -> void:
	var settings: ControlSettings = ControlSettings.new()
	settings.scheme = Types.ControlScheme.KEYBOARD
	settings.tilt_sensitivity = 1.4
	settings.tilt_smoothing = 0.25
	settings.save_settings()

	var reloaded: ControlSettings = ControlSettings.new()
	assert_eq(reloaded.scheme, Types.ControlScheme.KEYBOARD, "scheme survives a reload")
	assert_almost_eq(reloaded.tilt_sensitivity, 1.4, 0.0001, "sensitivity survives a reload")
	assert_almost_eq(reloaded.tilt_smoothing, 0.25, 0.0001, "smoothing survives a reload")


func test_out_of_range_sensitivity_is_clamped_on_load() -> void:
	var path: String = ControlSettings.SETTINGS_PATH
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "test fixture is writable")
	file.store_string('{"scheme": 3, "tilt_sensitivity": 900.0, "tilt_smoothing": -5.0}')
	file.close()

	var settings: ControlSettings = ControlSettings.new()
	assert_lte(
		settings.tilt_sensitivity,
		ControlSettings.MAX_SENSITIVITY,
		"a hand-edited file cannot produce an unplayable game"
	)
	assert_gte(settings.tilt_smoothing, 0.0, "smoothing cannot go negative")


func test_malformed_json_falls_back_to_defaults() -> void:
	var file: FileAccess = FileAccess.open(ControlSettings.SETTINGS_PATH, FileAccess.WRITE)
	assert_not_null(file, "test fixture is writable")
	file.store_string("this is not json{{{")
	file.close()

	var settings: ControlSettings = ControlSettings.new()
	assert_almost_eq(settings.tilt_sensitivity, 1.0, 0.0001, "defaults survive a corrupt file")


func test_unknown_scheme_value_falls_back_to_a_valid_scheme() -> void:
	var file: FileAccess = FileAccess.open(ControlSettings.SETTINGS_PATH, FileAccess.WRITE)
	assert_not_null(file, "test fixture is writable")
	file.store_string('{"scheme": 99}')
	file.close()

	var settings: ControlSettings = ControlSettings.new()
	assert_true(
		(
			settings.scheme >= Types.ControlScheme.HYBRID
			and settings.scheme <= Types.ControlScheme.GYRO
		),
		"an out-of-range enum ordinal cannot be stored"
	)
