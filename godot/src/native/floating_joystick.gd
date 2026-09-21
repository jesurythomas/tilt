## floating_joystick.gd
## NO TS COUNTERPART — authorised by M2.5 spec §8.
class_name FloatingJoystick
extends RefCounted
## Floating on-screen joystick: the base appears wherever the finger lands,
## the knob tracks the drag, both clear on release.
##
## The web game has no joystick — TiltGame.ts:1253-1285 steers the ship toward
## the raw pointer position instead. That behaviour is preserved in
## touch_input.gd and still drives the HYBRID and desktop schemes; this is the
## alternative the TOUCH scheme selects.
##
## All positions are playfield-local: GameRoot subtracts the arena origin
## (M2.5 spec §6.1) before calling in.

# DIVERGENCE(M2.5 §8.1): measured on SM_A556E — 90px was too small a travel
# on 1080p mobile screens; 115px gives comfortable thumb travel range.
## Distance from the base at which the knob reaches full deflection.
const BASE_RADIUS: float = 115.0
## Radius inside which a resting thumb produces no steering.
const DEAD_RADIUS: float = 8.0

## True while a finger is driving the stick.
var is_active: bool = false
## Where the finger landed. Meaningless while is_active is false.
var base_position: Vector2 = Vector2.ZERO
## Where the knob is drawn, clamped to BASE_RADIUS from the base.
var knob_position: Vector2 = Vector2.ZERO
## Steering direction, magnitude 0.0 to 1.0.
var vector: Vector2 = Vector2.ZERO

# Which touch index owns the stick, or Types.ABSENT when it is idle. A second
# simultaneous finger is ignored rather than stealing control, so a stray palm
# touch cannot yank the ship mid-run.
var _owner_index: int = Types.ABSENT


## Engages the stick if no finger already owns it.
func on_touch(index: int, position: Vector2) -> void:
	if _owner_index != Types.ABSENT:
		return
	_owner_index = index
	is_active = true
	base_position = position
	knob_position = position
	vector = Vector2.ZERO


## Moves the knob, if this is the owning finger.
func on_drag(index: int, position: Vector2) -> void:
	if index != _owner_index:
		return

	var offset: Vector2 = position - base_position
	var distance: float = offset.length()

	if distance <= DEAD_RADIUS:
		knob_position = position
		vector = Vector2.ZERO
		return

	if distance > BASE_RADIUS:
		offset = offset / distance * BASE_RADIUS

	knob_position = base_position + offset
	vector = offset / BASE_RADIUS


## Disengages the stick, if this is the owning finger.
func on_release(index: int) -> void:
	if index != _owner_index:
		return
	reset()


## Disengages unconditionally. Used when the control scheme changes mid-touch.
func reset() -> void:
	_owner_index = Types.ABSENT
	is_active = false
	base_position = Vector2.ZERO
	knob_position = Vector2.ZERO
	vector = Vector2.ZERO
