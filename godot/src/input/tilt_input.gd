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
	if file == null:
		Log.warn("tilt calibration could not be written to %s" % CALIBRATION_PATH)
		return
	file.store_string(JSON.stringify({"beta": calibrated_beta, "gamma": calibrated_gamma}))
	file.close()


## Grants permission (Android has no runtime prompt) and starts listening.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:60-91
func request_permission_and_start() -> bool:
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
	if _has_received_data:
		calibrated_beta = _raw_beta
		calibrated_gamma = _raw_gamma
	else:
		calibrated_beta = DEFAULT_CALIBRATED_BETA
		calibrated_gamma = 0.0
	save_calibration()
	if _on_calibrated.is_valid():
		_on_calibrated.call(calibrated_beta, calibrated_gamma)
	tilt_vector = Vector2.ZERO


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

	var vx: float = maxf(-1.0, minf(1.0, roll / MAX_TILT_ANGLE))
	var vy: float = maxf(-1.0, minf(1.0, pitch / MAX_TILT_ANGLE))

	var mag: float = sqrt(vx * vx + vy * vy)

	if mag < DEADZONE_THRESHOLD:
		tilt_vector = Vector2.ZERO
	else:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:183-187
		var scaled_mag: float = (mag - DEADZONE_THRESHOLD) / (1.0 - DEADZONE_THRESHOLD)
		tilt_vector = Vector2((vx / mag) * scaled_mag, (vy / mag) * scaled_mag)


# PORT-NOTE: web/src/tilt-to-live/GyroscopeController.ts:31-35 probes for
# DeviceOrientationEvent on window. The Godot equivalent is the platform:
# sensors are Android/iOS only (Input.get_gravity() returns Vector3.ZERO
# everywhere else).
func _check_support() -> void:
	var os_name: String = OS.get_name()
	is_supported = os_name == "Android" or os_name == "iOS"


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
