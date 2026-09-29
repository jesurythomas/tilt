## test_haptics.gd
## PORTS: nothing — new file, covers src/core/haptics.gd (MVP Week 1)
extends GutTest
## Proves the Haptics autoload pulses on a nuke, a death and a close call, stays
## quiet for everything else, and honours the Settings toggle.

var _calls: Array[int] = []
var _previous: Callable = Callable()


func _record(ms: int) -> void:
	_calls.append(ms)


func before_each() -> void:
	_calls = []
	_previous = Haptics.vibrate
	Haptics.vibrate = _record
	Haptics.enabled = true


func after_each() -> void:
	Haptics.vibrate = _previous
	Haptics.enabled = true


func test_nuke_pulses() -> void:
	GameEvents.weapon_activated.emit(Types.WeaponType.NUKE)
	assert_eq(_calls.size(), 1, "one pulse for a nuke")


func test_other_weapons_do_not_pulse() -> void:
	GameEvents.weapon_activated.emit(Types.WeaponType.LASER)
	assert_eq(_calls.size(), 0)


func test_fatal_hit_pulses_and_a_survived_hit_does_not() -> void:
	GameEvents.life_lost.emit(2)
	assert_eq(_calls.size(), 0, "a life left: no pulse")
	GameEvents.life_lost.emit(0)
	assert_eq(_calls.size(), 1, "the last life gone: one pulse")


func test_close_call_pulses_shorter_than_a_death() -> void:
	GameEvents.close_call.emit()
	GameEvents.life_lost.emit(0)
	assert_eq(_calls.size(), 2)
	assert_lt(_calls[0], _calls[1], "a close call is a tick, a death is a thud")


func test_disabled_is_silent() -> void:
	Haptics.enabled = false
	GameEvents.weapon_activated.emit(Types.WeaponType.NUKE)
	GameEvents.life_lost.emit(0)
	GameEvents.close_call.emit()
	assert_eq(_calls.size(), 0)
