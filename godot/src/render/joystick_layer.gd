## joystick_layer.gd
## NO TS COUNTERPART — authorised by M2.5 spec §8.2.
class_name JoystickLayer
extends Node2D
## Top render layer: draws the floating virtual joystick when it is engaged.
##
## Appended last in main.tscn so it draws above the entity and effect layers.
## Parent spec §5.5 fixes render order; this adds a step at the end without
## moving an existing one.

# DIVERGENCE(M2.5 §8.2): the palette is the arena's, from grid_layer.gd:33-34,
# so the stick belongs to the same neon-vector language as the playfield.
const BASE_COLOR: Color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.22)
const BASE_RING_COLOR: Color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.45)
# DIVERGENCE(M2.5 §8.2): cyan accent matches the existing palette entry at
# entity_layer.gd:21, so the knob reads as the same accent colour elsewhere in
# the HUD/entity layers rather than an unrelated one-off value.
const KNOB_COLOR: Color = Color(0.0, 220.0 / 255.0, 1.0, 0.75)
# Knob radius in pixels; sized by eye against BASE_RADIUS for a comfortable
# thumb target. Provisional — to be confirmed in the M2.5 device pass.
const KNOB_RADIUS: float = 34.0
## DIVERGENCE(TOUCH R1): the knob keeps KNOB_RADIUS's share of the base as the stick's
## size changes (FloatingJoystick.set_size).
const KNOB_FRACTION: float = KNOB_RADIUS / FloatingJoystick.BASE_RADIUS
## DIVERGENCE(ENH-302 R4): an anchored stick at rest draws at this share of its colours' alpha,
## so players know where to put their thumb without it covering play. Provisional until the
## A55 pass.
const IDLE_ALPHA: float = 0.4

## DIVERGENCE(ENH-302 R4): true while an anchored stick should show at rest. Set by GameRoot.
var show_idle: bool = false

var _joystick: FloatingJoystick = null
var _arena_origin: Vector2 = Vector2.ZERO


## Gives this layer the joystick it draws. Called by GameRoot.
func bind(joystick: FloatingJoystick) -> void:
	_joystick = joystick


## Sets the playfield's top-left corner in viewport space. Called by GameRoot.
func set_arena_origin(origin: Vector2) -> void:
	_arena_origin = origin


func _draw() -> void:
	if _joystick == null:
		return
	if _joystick.is_active:
		_draw_stick(_joystick.base_position, _joystick.knob_position, 1.0)
	elif show_idle and _joystick.is_anchored:
		_draw_stick(_joystick.anchor, _joystick.anchor, IDLE_ALPHA)


func _draw_stick(base: Vector2, knob: Vector2, alpha: float) -> void:
	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)
	draw_circle(base, _joystick.radius, Color(BASE_COLOR, BASE_COLOR.a * alpha))
	draw_arc(
		base, _joystick.radius, 0.0, TAU, 48, Color(BASE_RING_COLOR, BASE_RING_COLOR.a * alpha), 2.0
	)
	draw_circle(knob, _joystick.radius * KNOB_FRACTION, Color(KNOB_COLOR, KNOB_COLOR.a * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
