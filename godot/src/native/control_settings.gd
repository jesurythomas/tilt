## control_settings.gd
## NO TS COUNTERPART — authorised by M2.5 spec §4.1.
class_name ControlSettings
extends RefCounted
## Player-chosen control scheme and tilt tuning, persisted across launches.
##
## The web game has no settings surface for these: GameOptions.ts:80 fixes the
## control scheme at construction and GyroscopeController.ts exposes no
## sensitivity. Both are M2.5 divergences, authorised by spec §4.1 and §5.4.
##
# Persisted through SaveStore alongside tilt_gyro_calibration.json and
# tilt_to_live_best.json, per M2.5 spec D7.

## DIVERGENCE(ENH-302 R1, GitHub #4): where the touch stick sits. DYNAMIC floats under the
## finger (M2.5 §8.1); LEFT and RIGHT fix it in that bottom corner of the playfield.
enum StickAnchor { DYNAMIC, LEFT, RIGHT }

## Where the settings are persisted.
const SETTINGS_PATH: String = "user://peril_point_settings.json"

## Sensitivity bounds. 1.0 reproduces the cited MAX_TILT_ANGLE exactly.
const MIN_SENSITIVITY: float = 0.4
const MAX_SENSITIVITY: float = 2.5
## Smoothing bounds. 0.0 reproduces unsmoothed M2 behaviour exactly.
const MIN_SMOOTHING: float = 0.0
const MAX_SMOOTHING: float = 0.9
## DIVERGENCE(TOUCH R1, player feedback 2026-09-29: "is the stick control radius
## configurable"): Stick size bounds, a multiple of the A55-measured radius
## (FloatingJoystick.set_size). 1.0 is the M2.5 stick.
const MIN_STICK_SIZE: float = 0.6
const MAX_STICK_SIZE: float = 1.6

## Which control scheme drives the ship.
var scheme: Types.ControlScheme = Types.ControlScheme.MOUSE
## Divides MAX_TILT_ANGLE. Higher means less tilt for full deflection.
var tilt_sensitivity: float = 1.0
## Interpolation weight applied to tilt_vector each poll.
var tilt_smoothing: float = 0.0
## DIVERGENCE(TOUCH R1): the touch stick's radius, as a multiple of its default.
var stick_size: float = 1.0
## DIVERGENCE(ENH-302 R1): where the touch stick sits.
var stick_anchor: StickAnchor = StickAnchor.DYNAMIC


func _init() -> void:
	scheme = Types.ControlScheme.GYRO if OS.has_feature("mobile") else Types.ControlScheme.MOUSE
	_load_settings()


## Persists the current settings to SETTINGS_PATH as JSON.
func save_settings() -> void:
	(
		SaveStore
		. save_dict(
			SETTINGS_PATH,
			{
				"scheme": int(scheme),
				"tilt_sensitivity": tilt_sensitivity,
				"tilt_smoothing": tilt_smoothing,
				"stick_size": stick_size,
				"stick_anchor": int(stick_anchor),
			}
		)
	)


# An unreadable or wrongly-typed value keeps the default rather than crashing;
# a file that is not a JSON object is quarantined by SaveStore.
func _load_settings() -> void:
	var data: Dictionary = SaveStore.load_dict(SETTINGS_PATH)
	if data.is_empty():
		return

	var ordinal: int = SaveStore.read_int(data, "scheme", int(scheme))
	if ordinal >= Types.ControlScheme.HYBRID and ordinal <= Types.ControlScheme.GYRO:
		scheme = ordinal
	else:
		Log.warn("control settings carry an unknown scheme %d; keeping default" % ordinal)

	tilt_sensitivity = clampf(
		SaveStore.read_float(data, "tilt_sensitivity", tilt_sensitivity),
		MIN_SENSITIVITY,
		MAX_SENSITIVITY
	)
	tilt_smoothing = clampf(
		SaveStore.read_float(data, "tilt_smoothing", tilt_smoothing), MIN_SMOOTHING, MAX_SMOOTHING
	)
	stick_size = clampf(
		SaveStore.read_float(data, "stick_size", stick_size), MIN_STICK_SIZE, MAX_STICK_SIZE
	)
	var anchor: int = SaveStore.read_int(data, "stick_anchor", int(stick_anchor))
	if anchor >= StickAnchor.DYNAMIC and anchor <= StickAnchor.RIGHT:
		stick_anchor = anchor
	else:
		Log.warn("control settings carry an unknown stick anchor %d; keeping default" % anchor)
