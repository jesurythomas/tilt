## tilt_input.gd
## PORTS: web/src/tilt-to-live/GyroscopeController.ts (190 lines, source commit 7be9614)
class_name TiltInput
extends RefCounted
## Device tilt steering with a calibrated neutral pose.
##
## PORT-NOTE: the browser delivers `deviceorientation` events carrying beta and
## gamma in degrees. Godot has no such event; the equivalent reading is derived
## from Input.get_gravity() and pushed in by poll() (added in this module's
## Android bridge task). apply_orientation() below is the verbatim body of
## GyroscopeController.handleOrientation (web/src/tilt-to-live/GyroscopeController.ts:133-189)
## and is therefore fully testable headless.

## PORT: web/src/tilt-to-live/GyroscopeController.ts:10
enum PermissionState { UNKNOWN, GRANTED, DENIED }

# PORT-NOTE: web/src/tilt-to-live/GyroscopeController.ts:39 uses the
# localStorage key `tilt_gyro_calibration`, a fourth key spec §2.2 does not
# list. Same JSON shape, written straight to user:// for now.
# TODO(M7): route this through meta/save_store.gd once it exists.
## Where the calibrated neutral pose is persisted.
const CALIBRATION_PATH: String = "user://tilt_gyro_calibration.json"

## Degrees of tilt for full deflection.
const MAX_TILT_ANGLE: float = 24.0  # PORT: web/src/tilt-to-live/GyroscopeController.ts:172
## Radial neutral deadzone for steady resting hands.
const DEADZONE_THRESHOLD: float = 0.07  # PORT: web/src/tilt-to-live/GyroscopeController.ts:178
## Default resting phone tilt.
const DEFAULT_CALIBRATED_BETA: float = 38.0  # PORT: web/src/tilt-to-live/GyroscopeController.ts:18

# DIVERGENCE(M2.5 §5.4): guards a zero or negative tilt_sensitivity from a
# division fault. The value is an arbitrary small epsilon, not a measured
# quantity — it exists only so the divisor cannot reach zero.
const MIN_SENSITIVITY_DIVISOR: float = 0.0001

## True when the platform reports motion sensors.
var is_supported: bool = false
## True while the sensor is being polled.
var is_listening: bool = false
## Motion permission state. Android grants implicitly.
var permission_state: PermissionState = PermissionState.UNKNOWN
## Calibrated neutral front-back angle, degrees.
var calibrated_beta: float = DEFAULT_CALIBRATED_BETA
## Calibrated neutral left-right angle, degrees.
var calibrated_gamma: float = 0.0
## Steering output, normalised to [-1, 1] per axis.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:22
var tilt_vector: Vector2 = Vector2.ZERO

## Divides MAX_TILT_ANGLE. 1.0 reproduces the cited value exactly.
# DIVERGENCE(M2.5 §5.4): GyroscopeController.ts has no sensitivity control.
var tilt_sensitivity: float = 1.0
## Interpolation weight toward the newly computed vector. 0.0 is unsmoothed.
# DIVERGENCE(M2.5 §5.4): GyroscopeController.ts snaps tilt_vector directly.
var tilt_smoothing: float = 0.0

# DIVERGENCE(M2.5 §5.2): the device path calibrates against a full gravity
# vector rather than two derived angles, so the rotation transform is applied
# exactly once. calibrated_beta/gamma remain for apply_orientation() (§2.3).
var _calibrated_gravity: Vector3 = Vector3.ZERO
var _calibration_pending: bool = false

var _raw_beta: float = 0.0
var _raw_gamma: float = 0.0
var _has_received_data: bool = false
var _on_calibrated: Callable = Callable()


func _init() -> void:
	_check_support()
	_load_calibration()


## Persists the calibrated pose to CALIBRATION_PATH as JSON.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:48-55
func save_calibration() -> void:
	var file: FileAccess = FileAccess.open(CALIBRATION_PATH, FileAccess.WRITE)
	# PORT-NOTE: web/src/tilt-to-live/GyroscopeController.ts:49-54 swallows this
	# failure in a try/catch; a warning is logged here deliberately because a
	# silently ignored calibration file is undiagnosable on device.
	if file == null:
		Log.warn("tilt calibration could not be written to %s" % CALIBRATION_PATH)
		return
	(
		file
		. store_string(
			(
				JSON
				. stringify(
					{
						"beta": calibrated_beta,
						"gamma": calibrated_gamma,
						# DIVERGENCE(M2.5 §5.2): added key; M2 files without it load
						# as calibration-pending rather than using a stale pose.
						"gravity":
						[_calibrated_gravity.x, _calibrated_gravity.y, _calibrated_gravity.z],
					}
				)
			)
		)
	)
	file.close()


## Grants permission (Android has no runtime prompt) and starts listening.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:60-91
func request_permission_and_start() -> bool:
	# PORT-NOTE: message text is reworded from `console.warn('DeviceOrientationEvent
	# not supported on this browser/platform')` (GyroscopeController.ts:62)
	# because there is no DeviceOrientationEvent on Godot.
	if not is_supported:
		Log.warn("motion sensors are not supported on this platform")
		return false

	# PORT-NOTE: web/src/tilt-to-live/GyroscopeController.ts:66-84 handles iOS
	# 13+ Safari's DeviceOrientationEvent.requestPermission(). Android needs no
	# runtime permission for the accelerometer, so this is the Android branch
	# (GyroscopeController.ts:86-90) alone.
	# TODO(M11): revisit when the iOS export lands (spec D1).
	permission_state = PermissionState.GRANTED
	start_listening()
	return true


## Marks the controller as actively listening; a no-op if already started.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:93-97
func start_listening() -> void:
	if is_listening:
		return
	is_listening = true


## Stops listening and zeroes the steering output.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:99-104
func stop_listening() -> void:
	if not is_listening:
		return
	is_listening = false
	tilt_vector = Vector2.ZERO


## Zeroes the neutral pose at the current attitude.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:109-123
func calibrate_current_position() -> void:
	# DIVERGENCE(M2.5 §5.3): GyroscopeController.ts:113-115 falls back to
	# DEFAULT_CALIBRATED_BETA when no reading has arrived. On Android that
	# branch is always taken from _ready(), because the sensor has not
	# delivered a sample yet — and the wrong pose was then persisted. The
	# calibration now waits for real data instead of guessing.
	if _has_received_data:
		calibrated_beta = _raw_beta
		calibrated_gamma = _raw_gamma
		_calibration_pending = true
	else:
		_calibration_pending = true
	save_calibration()
	if _on_calibrated.is_valid():
		_on_calibrated.call(calibrated_beta, calibrated_gamma)
	tilt_vector = Vector2.ZERO


## True while waiting for a gravity sample to calibrate against.
func is_calibration_pending() -> bool:
	return _calibration_pending


## Registers a callback invoked with (beta, gamma) after each calibration.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:125-127
func set_on_calibrated(cb: Callable) -> void:
	_on_calibrated = cb


## True once at least one orientation reading has been applied.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:129-131
func has_sensor_data() -> bool:
	return _has_received_data


## Maps a device attitude to the steering vector.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:133-189
func apply_orientation(beta: float, gamma: float, screen_angle: int) -> void:
	_has_received_data = true
	_raw_beta = beta
	_raw_gamma = gamma

	var roll: float = 0.0
	var pitch: float = 0.0

	if screen_angle == 90:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:154-156 (landscape left)
		roll = beta - calibrated_beta
		pitch = -(gamma - calibrated_gamma)
	elif screen_angle == -90 or screen_angle == 270:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:158-160 (landscape right)
		roll = -(beta - calibrated_beta)
		pitch = gamma - calibrated_gamma
	elif screen_angle == 180:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:162-164 (inverted portrait)
		roll = -(gamma - calibrated_gamma)
		pitch = -(beta - calibrated_beta)
	else:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:166-168 (portrait)
		roll = gamma - calibrated_gamma
		pitch = beta - calibrated_beta

	_apply_angles(roll, pitch)


# The clamp, deadzone and re-normalisation shared by the ported
# apply_orientation() path and the M2.5 device path.
# PORT: web/src/tilt-to-live/GyroscopeController.ts:172-187 — moved verbatim,
# no value changed.
func _apply_angles(roll: float, pitch: float) -> void:
	# DIVERGENCE(M2.5 §5.4): the divisor was the bare MAX_TILT_ANGLE. At
	# tilt_sensitivity 1.0 this is arithmetically identical.
	var full_deflection: float = MAX_TILT_ANGLE / maxf(MIN_SENSITIVITY_DIVISOR, tilt_sensitivity)
	var vx: float = maxf(-1.0, minf(1.0, roll / full_deflection))
	var vy: float = maxf(-1.0, minf(1.0, pitch / full_deflection))

	var mag: float = sqrt(vx * vx + vy * vy)

	var target: Vector2 = Vector2.ZERO
	if mag >= DEADZONE_THRESHOLD:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:183-187
		var scaled_mag: float = (mag - DEADZONE_THRESHOLD) / (1.0 - DEADZONE_THRESHOLD)
		target = Vector2((vx / mag) * scaled_mag, (vy / mag) * scaled_mag)

	# DIVERGENCE(M2.5 §5.4): GyroscopeController.ts assigns tilt_vector
	# directly. At tilt_smoothing 0.0 this lerp is that assignment.
	tilt_vector = tilt_vector.lerp(target, 1.0 - tilt_smoothing)


## Reads the device sensor and applies it. Called once per physics tick by
## GameRoot while the gyro scheme is active.
func poll() -> void:
	if not is_listening:
		return
	var g: Vector3 = Input.get_gravity()
	if g == Vector3.ZERO:
		g = Input.get_accelerometer()
	if g == Vector3.ZERO:
		return
	apply_gravity(g, _screen_angle_degrees())


## Maps a gravity vector to the steering vector, relative to the calibrated
## pose. Separated from poll() so it is testable with an injected reading.
##
# DIVERGENCE(M2.5 §5.2): replaces M2's gravity → angles → synthetic beta/gamma
# → apply_orientation() chain, which applied the screen rotation twice (once
# in the decomposition, once inside apply_orientation) and therefore
# cross-coupled the two output axes. This applies it exactly once, here.
func apply_gravity(g: Vector3, screen_angle: int) -> void:
	_has_received_data = true
	var normalised: Vector3 = g.normalized()

	if _calibration_pending:
		_calibrated_gravity = normalised
		_calibration_pending = false
		tilt_vector = Vector2.ZERO
		return

	if _calibrated_gravity == Vector3.ZERO:
		_calibrated_gravity = normalised
		tilt_vector = Vector2.ZERO
		return

	var deviation: Vector3 = normalised - _calibrated_gravity

	# The device axes that correspond to screen right and screen up. Godot
	# reports gravity in the device's own frame, whose relationship to the
	# screen depends on the applied rotation — so this is where, and the only
	# place where, the rotation is accounted for.
	# DIVERGENCE(M2.5 §5.2): see the tag above apply_gravity().
	# PORT-NOTE: the 90 case is derived from the five measured A55 poses cited
	# in this file's poll() history (nose left/right -> Δg.x steers vx; top
	# away/toward -> Δg.y steers vy) — neutral landscape=(-0.058,-7.992,-5.683),
	# nose left=(-2.375,-6.034,-7.357) -> vx<0, nose right=(3.004,-4.368,-8.250)
	# -> vx>0, top away/up=(-0.058,-1.513,-9.689) -> pitch decreases -> vy<0.
	# 270 is the 90 case's inverse. 180 and 0 (portrait) are unverified: the
	# game is landscape-locked and no portrait pose was ever measured on
	# device.
	var screen_right: Vector3 = Vector3.ZERO
	var screen_up: Vector3 = Vector3.ZERO
	match screen_angle:
		90:
			screen_right = Vector3(1.0, 0.0, 0.0)
			screen_up = Vector3(0.0, -1.0, 0.0)
		270:
			screen_right = Vector3(-1.0, 0.0, 0.0)
			screen_up = Vector3(0.0, 1.0, 0.0)
		180:
			screen_right = Vector3(-1.0, 0.0, 0.0)
			screen_up = Vector3(0.0, 1.0, 0.0)
		_:
			screen_right = Vector3(1.0, 0.0, 0.0)
			screen_up = Vector3(0.0, -1.0, 0.0)

	# asin of the projection converts the unit-vector deviation to degrees,
	# which is the unit _apply_angles() and MAX_TILT_ANGLE work in.
	var roll: float = rad_to_deg(asin(clampf(deviation.dot(screen_right), -1.0, 1.0)))
	var pitch: float = rad_to_deg(asin(clampf(deviation.dot(screen_up), -1.0, 1.0)))
	_apply_angles(roll, pitch)


# PORT-NOTE: web/src/tilt-to-live/GyroscopeController.ts:31-35 probes for
# DeviceOrientationEvent on window. The Godot equivalent is the platform:
# sensors are Android/iOS only (Input.get_gravity() returns Vector3.ZERO
# everywhere else).
func _check_support() -> void:
	var os_name: String = OS.get_name()
	is_supported = os_name == "Android" or os_name == "iOS"


## The screen rotation in the degrees GyroscopeController expects.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:140-147
func _screen_angle_degrees() -> int:
	match DisplayServer.screen_get_orientation():
		DisplayServer.SCREEN_LANDSCAPE:
			return 90
		DisplayServer.SCREEN_REVERSE_LANDSCAPE:
			return 270
		DisplayServer.SCREEN_REVERSE_PORTRAIT:
			return 180
		_:
			return 0


## Loads a previously saved calibration from CALIBRATION_PATH, if present.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:37-46
func _load_calibration() -> void:
	if not FileAccess.file_exists(CALIBRATION_PATH):
		return
	var file: FileAccess = FileAccess.open(CALIBRATION_PATH, FileAccess.READ)
	if file == null:
		return
	var raw: String = file.get_as_text()
	file.close()
	# PORT-NOTE: Variant is unavoidable for unvalidated JSON (CONVENTIONS §4).
	var parsed: Variant = JSON.parse_string(raw)
	# PORT-NOTE: web/src/tilt-to-live/GyroscopeController.ts:38-45 swallows this
	# failure in a try/catch; a warning is logged here deliberately because a
	# silently ignored calibration file is undiagnosable on device.
	if not (parsed is Dictionary):
		Log.warn("tilt calibration is not a JSON object; keeping defaults")
		return
	var data: Dictionary = parsed
	# PORT-NOTE: mirrors `typeof parsed.beta === 'number'`
	# (web/src/tilt-to-live/GyroscopeController.ts:42-43); `is float` rejects a
	# string value the way the TS typeof check does, unlike has() + float().
	var beta_value: Variant = data.get("beta")
	if beta_value is float:
		calibrated_beta = beta_value
	var gamma_value: Variant = data.get("gamma")
	if gamma_value is float:
		calibrated_gamma = gamma_value
	var gravity_value: Variant = data.get("gravity")
	if gravity_value is Array:
		var components: Array = gravity_value
		if components.size() == 3:
			@warning_ignore("unsafe_call_argument")
			_calibrated_gravity = Vector3(
				float(components[0]), float(components[1]), float(components[2])
			)
			# DIVERGENCE(M2.5 §5.2): Variant components come from unvalidated
			# JSON (CONVENTIONS §4); float() genuinely requires the cast.
		else:
			_calibration_pending = true
	else:
		# An M2-era file has no gravity key. Recalibrate rather than guess.
		_calibration_pending = true
