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
# TODO(M7): fold into meta/save_store.gd alongside tilt_gyro_calibration.json
# and tilt_to_live_best.json, per M2.5 spec D7.

## Where the settings are persisted.
const SETTINGS_PATH: String = "user://peril_point_settings.json"

## Sensitivity bounds. 1.0 reproduces the cited MAX_TILT_ANGLE exactly.
const MIN_SENSITIVITY: float = 0.4
const MAX_SENSITIVITY: float = 2.5
## Smoothing bounds. 0.0 reproduces unsmoothed M2 behaviour exactly.
const MIN_SMOOTHING: float = 0.0
const MAX_SMOOTHING: float = 0.9

## Which control scheme drives the ship.
var scheme: Types.ControlScheme = Types.ControlScheme.MOUSE
## Divides MAX_TILT_ANGLE. Higher means less tilt for full deflection.
var tilt_sensitivity: float = 1.0
## Interpolation weight applied to tilt_vector each poll.
var tilt_smoothing: float = 0.0


func _init() -> void:
	scheme = Types.ControlScheme.GYRO if OS.has_feature("mobile") else Types.ControlScheme.MOUSE
	_load_settings()


## Persists the current settings to SETTINGS_PATH as JSON.
func save_settings() -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		Log.warn("control settings could not be written to %s" % SETTINGS_PATH)
		return
	(
		file
		. store_string(
			(
				JSON
				. stringify(
					{
						"scheme": int(scheme),
						"tilt_sensitivity": tilt_sensitivity,
						"tilt_smoothing": tilt_smoothing,
					}
				)
			)
		)
	)
	file.close()


# Mirrors the defensive JSON handling in tilt_input.gd:229-253: an unreadable
# or wrongly-typed value warns and keeps the default rather than crashing.
func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var raw: String = file.get_as_text()
	file.close()

	# PORT-NOTE: Variant is unavoidable for unvalidated JSON (CONVENTIONS §4).
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		Log.warn("control settings are not a JSON object; keeping defaults")
		return
	var data: Dictionary = parsed

	var scheme_value: Variant = data.get("scheme")
	if scheme_value is float:
		# PORT-NOTE: safe because we checked isinstance(scheme_value, float) above
		@warning_ignore("unsafe_cast")
		var ordinal: int = int(scheme_value as float)
		if ordinal >= Types.ControlScheme.HYBRID and ordinal <= Types.ControlScheme.GYRO:
			scheme = ordinal
		else:
			Log.warn("control settings carry an unknown scheme %d; keeping default" % ordinal)

	var sensitivity_value: Variant = data.get("tilt_sensitivity")
	if sensitivity_value is float:
		# PORT-NOTE: safe because we checked isinstance(sensitivity_value, float) above
		@warning_ignore("unsafe_cast")
		tilt_sensitivity = clampf(sensitivity_value as float, MIN_SENSITIVITY, MAX_SENSITIVITY)

	var smoothing_value: Variant = data.get("tilt_smoothing")
	if smoothing_value is float:
		# PORT-NOTE: safe because we checked isinstance(smoothing_value, float) above
		@warning_ignore("unsafe_cast")
		tilt_smoothing = clampf(smoothing_value as float, MIN_SMOOTHING, MAX_SMOOTHING)
