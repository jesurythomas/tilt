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


## ENH-302 R2: a fixed stick, grabbed near its centre; the knob jumps to the thumb.
func test_an_anchored_stick_is_grabbed_near_its_centre() -> void:
	var centre: Vector2 = Vector2(200.0, 800.0)
	_stick.set_anchor(centre)
	var r: float = FloatingJoystick.BASE_RADIUS
	_stick.on_touch(0, centre + Vector2(r, 0.0))
	assert_true(_stick.is_active, "a touch within the grab zone engages the stick")
	assert_eq(_stick.base_position, centre, "the base stays on the anchor")
	assert_almost_eq(_stick.vector.x, 1.0, 0.0001, "the knob jumps to the thumb at once")


func test_a_touch_outside_the_grab_zone_is_ignored() -> void:
	var centre: Vector2 = Vector2(200.0, 800.0)
	_stick.set_anchor(centre)
	var zone: float = FloatingJoystick.BASE_RADIUS * FloatingJoystick.GRAB_FRACTION
	_stick.on_touch(0, centre + Vector2(zone + 1.0, 0.0))
	assert_false(_stick.is_active, "a touch elsewhere does not steer")
	_stick.on_touch(1, centre)
	assert_true(_stick.is_active, "the ignored finger does not block a real grab")


func test_an_anchored_base_never_moves() -> void:
	var centre: Vector2 = Vector2(200.0, 800.0)
	_stick.set_anchor(centre)
	_stick.on_touch(0, centre)
	_stick.on_drag(0, centre + Vector2(0.0, -400.0))
	assert_eq(_stick.base_position, centre, "an overshooting thumb leaves the base in place")
	assert_almost_eq(
		_stick.knob_position.distance_to(centre),
		FloatingJoystick.BASE_RADIUS,
		0.0001,
		"the knob stops at the rim"
	)
	assert_almost_eq(_stick.vector.y, -1.0, 0.0001, "full deflection up")


func test_releasing_an_anchored_stick_recentres_it() -> void:
	var centre: Vector2 = Vector2(200.0, 800.0)
	_stick.set_anchor(centre)
	_stick.on_touch(0, centre + Vector2(30.0, 0.0))
	_stick.on_release(0)
	assert_false(_stick.is_active, "release disengages")
	assert_eq(_stick.vector, Vector2.ZERO, "no steering after release")
	assert_true(_stick.is_anchored, "the stick stays fixed for the next touch")
	assert_eq(_stick.anchor, centre, "at the same place")


func test_the_grab_zone_follows_the_stick_size() -> void:
	var centre: Vector2 = Vector2(200.0, 800.0)
	_stick.set_anchor(centre)
	_stick.set_size(1080.0 / 390.0, 0.6)
	var zone: float = FloatingJoystick.BASE_RADIUS * 0.6 * FloatingJoystick.GRAB_FRACTION
	_stick.on_touch(0, centre + Vector2(zone + 1.0, 0.0))
	assert_false(_stick.is_active, "a smaller stick has a smaller zone")


func test_clear_anchor_returns_to_the_floating_stick() -> void:
	_stick.set_anchor(Vector2(200.0, 800.0))
	_stick.clear_anchor()
	_stick.on_touch(0, Vector2(1500.0, 300.0))
	assert_false(_stick.is_anchored, "dynamic again")
	assert_eq(_stick.base_position, Vector2(1500.0, 300.0), "the base lands under the finger")
