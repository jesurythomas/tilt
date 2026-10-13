## haptics.gd
## PORTS: nothing — new file (MVP Week 1)
# PORT-NOTE: no `class_name`, against CONVENTIONS §2. An autoload script cannot
# carry one (same as Telemetry, Log and GameEvents).
extends Node
## Phone vibration on a nuke, a death and a close call. Autoloaded as `Haptics`.
##
## Standing rule (spec §5.3): signals go sim→UI only, so no sim class calls this.
## It listens to GameEvents, like Telemetry does.

# DIVERGENCE(MVP Week 1): pulse lengths in ms are new, tuned by feel on the A55.
const NUKE_MS: int = 120
const DEATH_MS: int = 250
const CLOSE_CALL_MS: int = 30
## DIVERGENCE(DASH R2): a short kick when the ship dashes.
const DASH_MS: int = 25
## DIVERGENCE(HAPTICS R1): the buzz when Vibration is switched on, so the player feels it work.
const PREVIEW_MS: int = 60

# DIVERGENCE(HAPTICS R1, user 2026-10-13: "vibration isnt working"): Godot's vibrate_handheld
# tags each pulse USAGE_TOUCH, and Android drops it when the phone's touch-feedback vibration is
# off (the A55's `dumpsys vibrator_manager`: TOUCH = OFF, every pulse "ignored_for_settings").
# Games vibrate as media, so on Android 13+ the pulse goes straight to the Vibrator as media.
## android.os.VibrationAttributes.USAGE_MEDIA (API 33).
const ANDROID_USAGE_MEDIA: int = 19
## android.os.VibrationEffect.DEFAULT_AMPLITUDE.
const ANDROID_DEFAULT_AMPLITUDE: int = -1

## False when the player switched Vibration off in Settings.
var enabled: bool = true
## The motor. A Callable so tests can record pulses; a no-op off a phone.
var vibrate: Callable = Input.vibrate_handheld

var _vibrator: Object = null
var _media_usage: Object = null
var _effect_class: Object = null


func _ready() -> void:
	GameEvents.weapon_activated.connect(_on_weapon_activated)
	GameEvents.life_lost.connect(_on_life_lost)
	GameEvents.close_call.connect(_on_close_call)
	GameEvents.dash_activated.connect(_on_dash_activated)  # DIVERGENCE(DASH R2)
	_bind_media_vibrator()


## DIVERGENCE(HAPTICS R1): one short buzz, for the Settings switch turning on.
func preview() -> void:
	_pulse(PREVIEW_MS)


# DIVERGENCE(HAPTICS R1): binds the Android Vibrator with media attributes; anything missing
# (not Android, below API 33) keeps Godot's vibrate_handheld.
func _bind_media_vibrator() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	var activity: Variant = Engine.get_singleton("AndroidRuntime").call("getActivity")
	var attributes: JavaClass = JavaClassWrapper.wrap("android.os.VibrationAttributes")
	_effect_class = JavaClassWrapper.wrap("android.os.VibrationEffect")
	if not activity is Object or attributes == null or _effect_class == null:
		return
	var context: Object = activity
	var vibrator: Variant = context.call("getSystemService", "vibrator")
	var usage: Variant = attributes.call("createForUsage", ANDROID_USAGE_MEDIA)
	if not vibrator is Object or not usage is Object:
		return
	_vibrator = vibrator
	_media_usage = usage
	vibrate = _vibrate_as_media
	Log.info("haptics: media vibration bound")


func _vibrate_as_media(ms: int) -> void:
	var effect: Variant = _effect_class.call("createOneShot", ms, ANDROID_DEFAULT_AMPLITUDE)
	_vibrator.call("vibrate", effect, _media_usage)


func _pulse(ms: int) -> void:
	if enabled:
		vibrate.call(ms)


func _on_weapon_activated(type: Types.WeaponType) -> void:
	if type == Types.WeaponType.NUKE:
		_pulse(NUKE_MS)


func _on_life_lost(lives_remaining: int) -> void:
	if lives_remaining <= 0:
		_pulse(DEATH_MS)


func _on_close_call() -> void:
	_pulse(CLOSE_CALL_MS)


func _on_dash_activated() -> void:
	_pulse(DASH_MS)
