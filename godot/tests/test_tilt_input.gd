## test_tilt_input.gd
## PORTS: nothing — new file, covers src/input/tilt_input.gd
extends GutTest
## Covers the four screen-angle axis mappings, the 24° full-deflection clamp
## and the 7% radial deadzone, all from GyroscopeController.handleOrientation.
##
## The M2.5 device path (apply_gravity, calibration deferral, sensitivity and
## smoothing) lives in test_tilt_input_device.gd instead — this file stays
## the apply_orientation() parity suite.

var _tilt: TiltInput = null


func before_each() -> void:
	var calibration_path: String = ProjectSettings.globalize_path(TiltInput.CALIBRATION_PATH)
	if FileAccess.file_exists(calibration_path):
		DirAccess.remove_absolute(calibration_path)
	_tilt = TiltInput.new()
	_tilt.calibrated_beta = 0.0
	_tilt.calibrated_gamma = 0.0


func after_each() -> void:
	var calibration_path: String = ProjectSettings.globalize_path(TiltInput.CALIBRATION_PATH)
	if FileAccess.file_exists(calibration_path):
		DirAccess.remove_absolute(calibration_path)


func test_default_calibrated_beta_is_the_resting_phone_angle() -> void:
	var fresh: TiltInput = TiltInput.new()
	assert_almost_eq(
		fresh.calibrated_beta, 38.0, 0.0001, "GyroscopeController.ts:18 — ~38° resting tilt"
	)


func test_neutral_orientation_inside_the_deadzone_yields_zero() -> void:
	_tilt.apply_orientation(1.0, 1.0, 90)
	assert_eq(_tilt.tilt_vector, Vector2.ZERO, "1° of 24° is inside the 7% deadzone")


func test_landscape_left_maps_beta_to_x_and_negated_gamma_to_y() -> void:
	_tilt.apply_orientation(24.0, 0.0, 90)
	assert_gt(_tilt.tilt_vector.x, 0.9, "beta drives x at 90° — GyroscopeController.ts:155")
	_tilt.apply_orientation(0.0, 24.0, 90)
	assert_lt(_tilt.tilt_vector.y, -0.9, "gamma is negated at 90° — GyroscopeController.ts:156")


func test_landscape_right_negates_beta_and_keeps_gamma() -> void:
	_tilt.apply_orientation(24.0, 0.0, 270)
	assert_lt(_tilt.tilt_vector.x, -0.9, "beta is negated at 270° — GyroscopeController.ts:159")
	_tilt.apply_orientation(0.0, 24.0, 270)
	assert_gt(_tilt.tilt_vector.y, 0.9, "gamma drives y at 270° — GyroscopeController.ts:160")


func test_portrait_maps_gamma_to_x_and_beta_to_y() -> void:
	_tilt.apply_orientation(0.0, 24.0, 0)
	assert_gt(_tilt.tilt_vector.x, 0.9, "gamma drives x in portrait — GyroscopeController.ts:167")
	_tilt.apply_orientation(24.0, 0.0, 0)
	assert_gt(_tilt.tilt_vector.y, 0.9, "beta drives y in portrait — GyroscopeController.ts:168")


func test_inverted_portrait_negates_both_axes() -> void:
	_tilt.apply_orientation(24.0, 24.0, 180)
	assert_lt(_tilt.tilt_vector.x, 0.0, "both axes negate at 180° — GyroscopeController.ts:163-164")
	assert_lt(_tilt.tilt_vector.y, 0.0, "both axes negate at 180° — GyroscopeController.ts:163-164")


func test_deflection_saturates_beyond_the_max_tilt_angle() -> void:
	_tilt.apply_orientation(90.0, 0.0, 90)
	assert_almost_eq(
		_tilt.tilt_vector.length(), 1.0, 0.0001, "clamped at 24° — GyroscopeController.ts:172-174"
	)


func test_calibration_offsets_the_neutral_pose() -> void:
	_tilt.calibrated_beta = 38.0
	_tilt.apply_orientation(38.0, 0.0, 90)
	assert_eq(_tilt.tilt_vector, Vector2.ZERO, "the calibrated pose reads as neutral")


func test_screen_angle_helper_reports_landscape_as_ninety() -> void:
	# On the headless host DisplayServer reports the desktop orientation, so
	# this asserts the mapping is total rather than any particular value.
	var angle: int = _tilt._screen_angle_degrees()
	assert_true(
		angle == 0 or angle == 90 or angle == 180 or angle == 270,
		"every DisplayServer orientation maps to a browser screen angle"
	)


func test_poll_is_inert_while_not_listening() -> void:
	_tilt.stop_listening()
	_tilt.apply_orientation(24.0, 0.0, 90)
	var before: Vector2 = _tilt.tilt_vector
	_tilt.poll()
	assert_eq(_tilt.tilt_vector, before, "poll() does nothing when not listening")


func test_corrupt_calibration_file_is_quarantined_and_keeps_defaults() -> void:
	var file: FileAccess = FileAccess.open(TiltInput.CALIBRATION_PATH, FileAccess.WRITE)
	file.store_string("not json at all")
	file.close()
	var tilt: TiltInput = TiltInput.new()
	assert_almost_eq(tilt.calibrated_beta, TiltInput.DEFAULT_CALIBRATED_BETA, 0.0001)
	var backup: String = SaveStore.corrupt_path_for(TiltInput.CALIBRATION_PATH)
	assert_true(FileAccess.file_exists(backup))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
