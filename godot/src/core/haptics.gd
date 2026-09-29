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

## False when the player switched Vibration off in Settings.
var enabled: bool = true
## The motor. A Callable so tests can record pulses; a no-op off a phone.
var vibrate: Callable = Input.vibrate_handheld


func _ready() -> void:
	GameEvents.weapon_activated.connect(_on_weapon_activated)
	GameEvents.life_lost.connect(_on_life_lost)
	GameEvents.close_call.connect(_on_close_call)


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
