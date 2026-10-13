## double_tap.gd
## PORTS: nothing — new file per ruling DASH R1 (user 2026-10-14: "Double tapping the phone
## quickly triggers dash"; plan docs/superpowers/plans/2026-10-14-dash-and-abilities.md)
class_name DoubleTap
extends RefCounted
## Recognises a double tap from raw touches, by Android GestureDetector's rule: the first touch
## is a tap (lifted quickly, barely moved), and the second lands soon after that lift, near it.
## Any finger may make either tap, so a second finger can double-tap while the first holds the
## stick; a steering drag is never a tap.
##
## Distances are in UI units (× `scale` on screen; 1 unit is about 1 dp), times in seconds from
## the caller's clock, so tests drive it without real time.

## DIVERGENCE(DASH R1): Android's DOUBLE_TAP_TIMEOUT (300 ms) for both the tap's hold and the
## gap to the second press, its DOUBLE_TAP_MIN_TIME (40 ms) and DOUBLE_TAP_SLOP (100 dp); the tap
## slop is a little over Android's 8 dp touch slop, for a thumb on a moving game.
const TAP_MAX_SECONDS: float = 0.3
const DOUBLE_TAP_SECONDS: float = 0.3
const DOUBLE_TAP_MIN_SECONDS: float = 0.04
const TAP_SLOP: float = 16.0
const DOUBLE_TAP_SLOP: float = 100.0

## The HUD's ui_scale, which turns the slops into screen pixels.
var scale: float = 1.0

## Touches down now, by index.
var _touches: Dictionary[int, Touch] = {}
## The last finished tap: when it lifted (−INF: none) and where it pressed.
var _tap_up_time: float = -INF
var _tap_position: Vector2 = Vector2.ZERO


## A finger lands. Returns true when it completes a double tap.
func press(index: int, position: Vector2, now: float) -> bool:
	var gap: float = now - _tap_up_time
	var is_double: bool = (
		gap >= DOUBLE_TAP_MIN_SECONDS
		and gap <= DOUBLE_TAP_SECONDS
		and position.distance_to(_tap_position) <= DOUBLE_TAP_SLOP * scale
	)
	var touch: Touch = Touch.new()
	touch.down_time = now
	touch.down_position = position
	# The finishing press never starts the next double tap: a triple tap dashes once.
	touch.is_spent = is_double
	_touches[index] = touch
	if is_double:
		_tap_up_time = -INF
	return is_double


## A finger moves; past the tap slop it is a drag, never a tap.
func drag(index: int, position: Vector2) -> void:
	var touch: Touch = _touches.get(index, null)
	if touch != null and position.distance_to(touch.down_position) > TAP_SLOP * scale:
		touch.is_spent = true


## A finger lifts; a quick, still touch becomes the tap a double tap starts from.
func release(index: int, position: Vector2, now: float) -> void:
	var touch: Touch = _touches.get(index, null)
	_touches.erase(index)
	if touch == null or touch.is_spent:
		return
	if now - touch.down_time > TAP_MAX_SECONDS:
		return
	if position.distance_to(touch.down_position) > TAP_SLOP * scale:
		return
	_tap_up_time = now
	_tap_position = touch.down_position


## Forgets every touch and tap (a run starting, the scheme changing).
func reset() -> void:
	_touches.clear()
	_tap_up_time = -INF


## One finger's press.
class Touch:
	extends RefCounted
	var down_time: float = 0.0
	var down_position: Vector2 = Vector2.ZERO
	## True once it moved past the slop, or when it finished a double tap.
	var is_spent: bool = false
