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
## Distance from the base at which the knob reaches full deflection, before
## set_size() (the A55's measure).
const BASE_RADIUS: float = 115.0
## DIVERGENCE(TOUCH R1, player feedback 2026-09-29: "is the stick control radius
## configurable"): the radius in UI px at ui_scale 1 — BASE_RADIUS on the A55
## (ui_scale 1080 / 390) — so a stick is the same physical size on every phone.
const RADIUS_UNITS: float = BASE_RADIUS * 390.0 / 1080.0
## DIVERGENCE(TOUCH R1): the dead zone as a fraction of the radius — tilt's radial
## deadzone (TiltInput.DEADZONE_THRESHOLD, GyroscopeController.ts:178); M2.5 used a
## flat 8 px, 0.07 of 115.
const DEAD_FRACTION: float = 0.07
## DIVERGENCE(ENH-302 R2, GitHub #4): an anchored stick is grabbed by a touch within this
## many radii of its centre.
const GRAB_FRACTION: float = 2.0

## True while a finger is driving the stick.
var is_active: bool = false
## Where the finger landed; it follows a thumb that runs past the rim (TOUCH R1).
## Meaningless while is_active is false.
var base_position: Vector2 = Vector2.ZERO
## Where the knob is drawn, clamped to `radius` from the base.
var knob_position: Vector2 = Vector2.ZERO
## Steering direction, magnitude 0.0 to 1.0.
var vector: Vector2 = Vector2.ZERO
## Full-deflection distance in px (see set_size).
var radius: float = BASE_RADIUS
## DIVERGENCE(ENH-302 R1): true while the stick is fixed at `anchor` (Stick position Left
## or Right) rather than floating under the finger.
var is_anchored: bool = false
## Where an anchored stick sits. Meaningless while is_anchored is false.
var anchor: Vector2 = Vector2.ZERO

# Which touch index owns the stick, or Types.ABSENT when it is idle. A second
# simultaneous finger is ignored rather than stealing control, so a stray palm
# touch cannot yank the ship mid-run.
var _owner_index: int = Types.ABSENT


## DIVERGENCE(TOUCH R1): sizes the stick for this screen — RADIUS_UNITS at `ui_scale`,
## times the player's Stick size setting (ControlSettings.stick_size).
func set_size(ui_scale: float, stick_size: float) -> void:
	radius = maxf(1.0, RADIUS_UNITS * ui_scale * stick_size)


## DIVERGENCE(ENH-302 R1): fixes the stick at `centre`, playfield-local.
func set_anchor(centre: Vector2) -> void:
	is_anchored = true
	anchor = centre
	if is_active:
		base_position = centre


## DIVERGENCE(ENH-302 R1): back to the floating stick.
func clear_anchor() -> void:
	is_anchored = false
	anchor = Vector2.ZERO


## Engages the stick if no finger already owns it.
## DIVERGENCE(ENH-302 R2): an anchored stick only takes a touch within GRAB_FRACTION radii of
## its centre, and its knob jumps to the thumb.
func on_touch(index: int, position: Vector2) -> void:
	if _owner_index != Types.ABSENT:
		return
	if is_anchored and position.distance_to(anchor) > radius * GRAB_FRACTION:
		return
	_owner_index = index
	is_active = true
	base_position = anchor if is_anchored else position
	knob_position = base_position
	vector = Vector2.ZERO
	if is_anchored:
		on_drag(index, position)


## Moves the knob, if this is the owning finger.
## DIVERGENCE(TOUCH R1, player feedback: "the stick responsiveness is nowhere close to
## being as intuitive or feels as good as gyro"): a thumb past the rim drags the base
## after it, so reversing is always at most one diameter away (a fixed base made a
## drifted thumb cross the whole old offset first); and the output ramps from 0 at the
## dead zone's edge to 1 at the rim, as tilt re-normalises past its deadzone
## (GyroscopeController.ts:183-187), instead of jumping to 0.07.
func on_drag(index: int, position: Vector2) -> void:
	if index != _owner_index:
		return

	var offset: Vector2 = position - base_position
	var distance: float = offset.length()

	if distance > radius:
		offset = offset / distance * radius
		# DIVERGENCE(ENH-302 R2): an anchored base stays put; the knob stops at the rim.
		if not is_anchored:
			base_position = position - offset
		distance = radius

	knob_position = base_position + offset
	var mag: float = distance / radius
	if mag < DEAD_FRACTION:
		vector = Vector2.ZERO
		return
	vector = offset / distance * ((mag - DEAD_FRACTION) / (1.0 - DEAD_FRACTION))


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
