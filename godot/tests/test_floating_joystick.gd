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
	_stick.on_drag(0, Vector2(300.0 + FloatingJoystick.DEAD_RADIUS * 0.5, 400.0))
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
