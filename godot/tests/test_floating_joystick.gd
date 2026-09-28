## test_floating_joystick.gd
## PORTS: nothing — new file, covers src/native/floating_joystick.gd
extends GutTest
## Covers the floating-joystick contract from M2.5 spec §8.1: the base lands
## where the finger lands, the vector is clamped to unit magnitude, and a
## second finger cannot steal control.

var _stick: FloatingJoystick = null


func before_each() -> void:
	_stick = FloatingJoystick.new()


func test_starts_inactive_with_no_output() -> void:
	assert_false(_stick.is_active, "nothing is drawn or driven before a touch")
	assert_eq(_stick.vector, Vector2.ZERO, "no steering before a touch")


func test_touch_places_the_base_under_the_finger() -> void:
	_stick.on_touch(0, Vector2(300.0, 400.0))
	assert_true(_stick.is_active, "a touch engages the stick")
	assert_eq(_stick.base_position, Vector2(300.0, 400.0), "the base lands under the finger")
	assert_eq(_stick.vector, Vector2.ZERO, "a touch with no drag yields no steering")


func test_drag_produces_a_direction() -> void:
	_stick.on_touch(0, Vector2(300.0, 400.0))
	_stick.on_drag(0, Vector2(300.0 + FloatingJoystick.BASE_RADIUS, 400.0))
	assert_almost_eq(_stick.vector.x, 1.0, 0.0001, "a full-radius drag right is full deflection")
	assert_almost_eq(_stick.vector.y, 0.0, 0.0001, "no vertical component from a horizontal drag")


func test_drag_beyond_the_base_radius_clamps_to_unit_magnitude() -> void:
	_stick.on_touch(0, Vector2(300.0, 400.0))
	_stick.on_drag(0, Vector2(300.0 + FloatingJoystick.BASE_RADIUS * 10.0, 400.0))
	assert_almost_eq(_stick.vector.length(), 1.0, 0.0001, "magnitude never exceeds 1.0")
	assert_almost_eq(
		_stick.knob_position.distance_to(_stick.base_position),
		FloatingJoystick.BASE_RADIUS,
		0.0001,
		"the knob stays inside the base"
	)


func test_a_drag_inside_the_dead_radius_yields_no_steering() -> void:
	_stick.on_touch(0, Vector2(300.0, 400.0))
	var dead: float = FloatingJoystick.BASE_RADIUS * FloatingJoystick.DEAD_FRACTION
	_stick.on_drag(0, Vector2(300.0 + dead * 0.5, 400.0))
	assert_eq(_stick.vector, Vector2.ZERO, "a resting thumb does not steer")


func test_release_clears_everything() -> void:
	_stick.on_touch(0, Vector2(300.0, 400.0))
	_stick.on_drag(0, Vector2(400.0, 400.0))
	_stick.on_release(0)
	assert_false(_stick.is_active, "releasing disengages the stick")
	assert_eq(_stick.vector, Vector2.ZERO, "releasing stops the ship steering")


func test_a_second_finger_cannot_steal_control() -> void:
	_stick.on_touch(0, Vector2(300.0, 400.0))
	_stick.on_touch(1, Vector2(900.0, 200.0))
	assert_eq(_stick.base_position, Vector2(300.0, 400.0), "the first finger keeps the stick")

	_stick.on_drag(1, Vector2(950.0, 200.0))
	assert_eq(_stick.vector, Vector2.ZERO, "the second finger cannot steer")


func test_releasing_the_second_finger_does_not_disengage() -> void:
	_stick.on_touch(0, Vector2(300.0, 400.0))
	_stick.on_touch(1, Vector2(900.0, 200.0))
	_stick.on_release(1)
	assert_true(_stick.is_active, "only the owning finger can release the stick")


func test_reset_clears_an_engaged_stick() -> void:
	_stick.on_touch(0, Vector2(300.0, 400.0))
	_stick.on_drag(0, Vector2(400.0, 400.0))
	_stick.reset()
	assert_false(_stick.is_active, "reset disengages, for a scheme change mid-touch")
	assert_eq(_stick.vector, Vector2.ZERO, "reset stops the ship steering")


## TOUCH R1 (player: the stick "is nowhere close to being as intuitive or feels as good as
## gyro"): a thumb past the rim drags the base with it, so reversing is one flick.
func test_the_base_follows_a_thumb_past_the_rim() -> void:
	_stick.on_touch(0, Vector2(300.0, 400.0))
	_stick.on_drag(0, Vector2(300.0 + 400.0, 400.0))
	assert_eq(_stick.base_position, Vector2(700.0 - FloatingJoystick.BASE_RADIUS, 400.0))
	# Back the other way: one diameter reverses it fully (a fixed base needed 400 px + r).
	_stick.on_drag(0, Vector2(700.0 - FloatingJoystick.BASE_RADIUS * 2.0, 400.0))
	assert_almost_eq(_stick.vector.x, -1.0, 0.0001, "full reverse after one diameter")


## TOUCH R1: past the dead zone the output ramps from 0, as tilt's does, not from 0.07.
func test_the_output_ramps_from_zero_past_the_dead_zone() -> void:
	_stick.on_touch(0, Vector2(300.0, 400.0))
	var dead: float = FloatingJoystick.BASE_RADIUS * FloatingJoystick.DEAD_FRACTION
	_stick.on_drag(0, Vector2(300.0 + dead + 0.01, 400.0))
	assert_lt(_stick.vector.x, 0.001, "just past the dead zone is barely moving")
	_stick.on_drag(0, Vector2(300.0 + FloatingJoystick.BASE_RADIUS * 0.5, 400.0))
	assert_between(_stick.vector.x, 0.45, 0.5, "half travel is about half speed")


## TOUCH R1 (player: "is the stick control radius configurable"): the Stick size setting
## scales the radius, and the radius scales with the screen's ui_scale.
func test_set_size_scales_the_radius() -> void:
	_stick.set_size(1080.0 / 390.0, 1.0)
	assert_almost_eq(_stick.radius, FloatingJoystick.BASE_RADIUS, 0.001, "the A55's 115 px")
	_stick.set_size(1080.0 / 390.0, 0.6)
	assert_almost_eq(_stick.radius, FloatingJoystick.BASE_RADIUS * 0.6, 0.001)
	_stick.on_touch(0, Vector2(300.0, 400.0))
	_stick.on_drag(0, Vector2(300.0 + FloatingJoystick.BASE_RADIUS * 0.6, 400.0))
	assert_almost_eq(_stick.vector.x, 1.0, 0.0001, "a smaller stick hits full speed sooner")
