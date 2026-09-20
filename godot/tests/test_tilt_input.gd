# gdlint:ignore = max-public-methods
# GUT test funcs are not a public API surface; M2.5 task 2 pushed this
# file's test count past the default cap.
## test_tilt_input.gd
## PORTS: nothing — new file, covers src/input/tilt_input.gd
extends GutTest
## Covers the four screen-angle axis mappings, the 24° full-deflection clamp
## and the 7% radial deadzone, all from GyroscopeController.handleOrientation.

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


func test_calibrate_without_sensor_data_defers_instead_of_guessing() -> void:
	# DIVERGENCE(M2.5 §5.3): M2 fell back to DEFAULT_CALIBRATED_BETA here and
	# persisted a pose measured from a different grip. That was the drift.
	_tilt.calibrate_current_position()
	assert_true(_tilt.is_calibration_pending(), "calibration waits for real sensor data")
	assert_eq(_tilt.tilt_vector, Vector2.ZERO, "calibrating zeroes the output")


func test_pending_calibration_is_captured_on_the_first_gravity_sample() -> void:
	_tilt.start_listening()
	_tilt.calibrate_current_position()
	var pose: Vector3 = Vector3(0.0, -8.0, -5.7)
	_tilt.apply_gravity(pose, 90)
	assert_false(_tilt.is_calibration_pending(), "the first sample completes calibration")
	assert_eq(_tilt.tilt_vector, Vector2.ZERO, "the calibrating pose reads as neutral")


func test_the_calibrated_pose_reads_as_neutral_however_it_is_held() -> void:
	_tilt.start_listening()
	_tilt.calibrate_current_position()
	# An awkward grip the M2 DEFAULT_CALIBRATED_BETA would have mismapped.
	var pose: Vector3 = Vector3(2.5, -6.0, -7.2)
	_tilt.apply_gravity(pose, 90)
	_tilt.apply_gravity(pose, 90)
	assert_eq(_tilt.tilt_vector, Vector2.ZERO, "no drift while held at the calibrated pose")


func test_tilting_produces_output_on_one_axis_at_a_time() -> void:
	# DIVERGENCE(M2.5 §5.1 Defect A): M2 applied the landscape rotation twice,
	# so a single-axis movement bled into both outputs.
	_tilt.start_listening()
	_tilt.calibrate_current_position()
	var neutral: Vector3 = Vector3(0.0, -8.0, -5.7)
	_tilt.apply_gravity(neutral, 90)

	var rolled: Vector3 = Vector3(2.0, -8.0, -5.7)
	_tilt.apply_gravity(rolled, 90)
	var rolled_out: Vector2 = _tilt.tilt_vector
	assert_gt(rolled_out.length(), 0.0, "a real tilt produces steering")
	assert_gt(
		absf(rolled_out.x),
		absf(rolled_out.y) * 2.0,
		"tilting on one device axis drives one screen axis, not both"
	)


func test_sensitivity_of_one_reproduces_the_cited_deflection() -> void:
	_tilt.tilt_sensitivity = 1.0
	_tilt.apply_orientation(24.0, 0.0, 90)
	assert_almost_eq(
		_tilt.tilt_vector.length(),
		1.0,
		0.0001,
		"sensitivity 1.0 is arithmetically the cited MAX_TILT_ANGLE — GyroscopeController.ts:172"
	)


func test_higher_sensitivity_needs_less_tilt_for_the_same_deflection() -> void:
	_tilt.tilt_sensitivity = 1.0
	_tilt.apply_orientation(12.0, 0.0, 90)
	var at_one: float = _tilt.tilt_vector.length()

	_tilt.tilt_vector = Vector2.ZERO
	_tilt.tilt_sensitivity = 2.0
	_tilt.apply_orientation(12.0, 0.0, 90)
	var at_two: float = _tilt.tilt_vector.length()

	assert_gt(at_two, at_one, "doubling sensitivity halves the tilt needed")


func test_smoothing_of_zero_reproduces_unsmoothed_output() -> void:
	_tilt.tilt_smoothing = 0.0
	_tilt.apply_orientation(24.0, 0.0, 90)
	assert_almost_eq(
		_tilt.tilt_vector.length(), 1.0, 0.0001, "smoothing 0.0 is M2 behaviour exactly"
	)


func test_a_legacy_m2_calibration_file_loads_as_pending() -> void:
	var file: FileAccess = FileAccess.open(TiltInput.CALIBRATION_PATH, FileAccess.WRITE)
	assert_not_null(file, "test fixture is writable")
	file.store_string('{"beta": 21.5, "gamma": -3.25}')
	file.close()

	var reloaded: TiltInput = TiltInput.new()
	assert_true(
		reloaded.is_calibration_pending(),
		"an M2 file carries no gravity vector, so the device path recalibrates"
	)
	assert_almost_eq(
		reloaded.calibrated_beta, 21.5, 0.0001, "beta still loads for apply_orientation"
	)


func test_calibration_round_trips_through_the_user_file() -> void:
	_tilt.calibrated_beta = 21.5
	_tilt.calibrated_gamma = -3.25
	_tilt.start_listening()
	_tilt.calibrate_current_position()
	_tilt.apply_gravity(Vector3(0.0, -8.0, -5.7), 90)
	_tilt.save_calibration()

	var reloaded: TiltInput = TiltInput.new()
	assert_almost_eq(reloaded.calibrated_beta, 21.5, 0.0001, "beta survives a reload")
	assert_almost_eq(reloaded.calibrated_gamma, -3.25, 0.0001, "gamma survives a reload")
	assert_false(reloaded.is_calibration_pending(), "the gravity vector survives a reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TiltInput.CALIBRATION_PATH))


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
