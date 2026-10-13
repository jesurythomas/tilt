## test_double_tap.gd
## PORTS: nothing — new file, covers src/input/double_tap.gd and GameRoot's dash and item input
## (rulings DASH R1, ITEM R1)
extends GutTest
## Proves the double-tap rule (quick, still, near, in time; any finger; drags never count; a
## triple tap dashes once) and that GameRoot turns it, Shift and 1/2 into requests only in a
## live run.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const AT: Vector2 = Vector2(400.0, 300.0)

var _tap: DoubleTap = null


func before_each() -> void:
	_tap = DoubleTap.new()


## A full tap: press at `t`, lift `hold` seconds later. Returns press()'s answer.
func _tap_at(index: int, position: Vector2, t: float, hold: float = 0.08) -> bool:
	var is_double: bool = _tap.press(index, position, t)
	_tap.release(index, position, t + hold)
	return is_double


func test_two_quick_taps_make_a_double_tap() -> void:
	assert_false(_tap_at(0, AT, 1.0))
	assert_true(_tap.press(0, AT + Vector2(20.0, 10.0), 1.2), "0.12 s after the lift, 22 px off")


func test_the_second_tap_must_come_in_time() -> void:
	_tap_at(0, AT, 1.0)
	assert_false(_tap.press(0, AT, 1.08 + DoubleTap.DOUBLE_TAP_SECONDS + 0.01))


func test_a_bounce_under_forty_ms_is_not_a_second_tap() -> void:
	_tap_at(0, AT, 1.0)
	assert_false(_tap.press(0, AT, 1.08 + 0.02))


func test_the_second_tap_must_be_near_the_first() -> void:
	_tap_at(0, AT, 1.0)
	assert_false(_tap.press(0, AT + Vector2(DoubleTap.DOUBLE_TAP_SLOP + 1.0, 0.0), 1.2))


func test_slops_follow_the_ui_scale() -> void:
	_tap.scale = 2.0
	_tap_at(0, AT, 1.0)
	assert_true(_tap.press(0, AT + Vector2(150.0, 0.0), 1.2), "100 units is 200 px at 2x")


func test_a_long_press_is_not_a_tap() -> void:
	_tap_at(0, AT, 1.0, DoubleTap.TAP_MAX_SECONDS + 0.05)
	assert_false(_tap.press(0, AT, 1.45))


func test_a_steering_drag_is_not_a_tap() -> void:
	_tap.press(0, AT, 1.0)
	_tap.drag(0, AT + Vector2(DoubleTap.TAP_SLOP + 5.0, 0.0))
	_tap.drag(0, AT)
	_tap.release(0, AT, 1.05)
	assert_false(_tap.press(0, AT, 1.15), "it moved past the slop, even if it came back")


func test_a_second_finger_double_taps_while_the_first_steers() -> void:
	_tap.press(0, Vector2(100.0, 500.0), 0.5)
	_tap.drag(0, Vector2(160.0, 470.0))
	assert_false(_tap_at(1, AT, 1.0))
	_tap.drag(0, Vector2(190.0, 440.0))
	assert_true(_tap.press(1, AT, 1.2))


func test_a_triple_tap_dashes_once() -> void:
	_tap_at(0, AT, 1.0)
	assert_true(_tap_at(0, AT, 1.2))
	assert_false(_tap.press(0, AT, 1.4), "the finishing tap starts nothing")


func test_reset_forgets_the_pending_tap() -> void:
	_tap_at(0, AT, 1.0)
	_tap.reset()
	assert_false(_tap.press(0, AT, 1.2))


func _boot_into_run() -> GameRoot:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	return root


func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


func _touch(index: int, position: Vector2, is_pressed: bool) -> InputEventScreenTouch:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = index
	touch.position = position
	touch.pressed = is_pressed
	return touch


func test_a_double_tap_in_a_run_asks_for_a_dash() -> void:
	var root: GameRoot = await _boot_into_run()
	var abilities: AbilitySystem = root._run_controller.abilities
	for event: InputEventScreenTouch in [_touch(0, AT, true), _touch(0, AT, false)]:
		root._unhandled_input(event)
	OS.delay_msec(80)  # the gesture reads the wall clock; a headless timer runs faster
	root._unhandled_input(_touch(0, AT, true))
	assert_true(abilities._is_dash_requested)


func test_shift_dashes_and_one_and_two_fire_items_only_in_a_run() -> void:
	var root: GameRoot = await _boot_into_run()
	var abilities: AbilitySystem = root._run_controller.abilities
	root._unhandled_input(_key(KEY_SHIFT))
	root._unhandled_input(_key(KEY_2))
	assert_true(abilities._is_dash_requested)
	assert_eq(abilities._item_requests, [1] as Array[int])
	abilities.reset(20.0, 2.0, [])
	root.toggle_pause()
	root._unhandled_input(_key(KEY_SHIFT))
	root.use_item(0)
	assert_false(abilities._is_dash_requested, "paused: no dash")
	assert_eq(abilities._item_requests, [] as Array[int], "paused: no item")
