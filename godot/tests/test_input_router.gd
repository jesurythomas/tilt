## test_input_router.gd
## PORTS: nothing — new file, covers src/input/input_router.gd and touch_input.gd
extends GutTest
## Covers the movement vector, key mapping, control-scheme resolution and the
## screen-drag / pointer-move handlers.

var _router: InputRouter = null


func before_each() -> void:
	_router = InputRouter.new()


func test_defaults_match_the_typescript() -> void:
	assert_eq(
		_router.control_scheme, Types.ControlScheme.HYBRID, "GameOptions.ts:80 defaults to hybrid"
	)
	assert_eq(_router.control_mode, Types.ControlMode.MOUSE, "TiltGame.ts:79 defaults to mouse")
	assert_eq(_router.mouse_pos, Vector2(400.0, 300.0), "TiltGame.ts:78 seeds the pointer")


func test_movement_vector_is_zero_with_no_keys() -> void:
	assert_eq(_router.get_movement_vector(), Vector2.ZERO, "no keys, no movement")


func test_opposing_keys_cancel() -> void:
	_router.press_movement_key(Types.MoveDirection.LEFT)
	_router.press_movement_key(Types.MoveDirection.RIGHT)
	assert_eq(_router.get_movement_vector(), Vector2.ZERO, "left and right cancel")


func test_diagonals_are_normalised() -> void:
	_router.press_movement_key(Types.MoveDirection.UP)
	_router.press_movement_key(Types.MoveDirection.RIGHT)
	var v: Vector2 = _router.get_movement_vector()
	assert_almost_eq(v.length(), 1.0, 0.0001, "TiltGame.ts:2410-2414 divides by sqrt(2)")
	assert_almost_eq(v.x, 0.70710678, 0.0001, "x component")
	assert_almost_eq(v.y, -0.70710678, 0.0001, "up is negative y")


func test_release_and_clear() -> void:
	_router.press_movement_key(Types.MoveDirection.UP)
	assert_true(_router.has_active_movement_keys(), "a pressed key registers")
	_router.release_movement_key(Types.MoveDirection.UP)
	assert_false(_router.has_active_movement_keys(), "releasing removes it")
	_router.press_movement_key(Types.MoveDirection.DOWN)
	_router.clear_movement_keys()
	assert_false(_router.has_active_movement_keys(), "clear empties the set")


func test_key_direction_mapping() -> void:
	assert_eq(_router.get_movement_key_direction(KEY_W), Types.MoveDirection.UP, "W is up")
	assert_eq(_router.get_movement_key_direction(KEY_UP), Types.MoveDirection.UP, "ArrowUp is up")
	assert_eq(_router.get_movement_key_direction(KEY_KP_8), Types.MoveDirection.UP, "Numpad8 is up")
	assert_eq(_router.get_movement_key_direction(KEY_S), Types.MoveDirection.DOWN, "S is down")
	assert_eq(_router.get_movement_key_direction(KEY_A), Types.MoveDirection.LEFT, "A is left")
	assert_eq(_router.get_movement_key_direction(KEY_D), Types.MoveDirection.RIGHT, "D is right")
	assert_eq(_router.get_movement_key_direction(KEY_Q), Types.ABSENT, "Q is not a movement key")


func test_control_scheme_resolution_pins_each_explicit_scheme() -> void:
	_router.control_mode = Types.ControlMode.MOUSE
	_router.control_scheme = Types.ControlScheme.GYRO
	assert_eq(_router.resolve_control_mode(), Types.ControlMode.GYRO, "TiltGame.ts:1874-1875")
	_router.control_scheme = Types.ControlScheme.KEYBOARD
	assert_eq(_router.resolve_control_mode(), Types.ControlMode.KEYBOARD, "TiltGame.ts:1872-1873")
	_router.control_scheme = Types.ControlScheme.MOUSE
	assert_eq(_router.resolve_control_mode(), Types.ControlMode.MOUSE, "TiltGame.ts:1870-1871")


func test_hybrid_falls_through_to_keyboard_only_while_keys_are_held() -> void:
	_router.control_scheme = Types.ControlScheme.HYBRID
	_router.control_mode = Types.ControlMode.MOUSE
	assert_eq(_router.resolve_control_mode(), Types.ControlMode.MOUSE, "hybrid keeps control_mode")
	_router.press_movement_key(Types.MoveDirection.UP)
	assert_eq(_router.resolve_control_mode(), Types.ControlMode.KEYBOARD, "TiltGame.ts:1876-1877")


func test_screen_drag_moves_the_pointer_and_selects_mouse_mode() -> void:
	var touch: TouchInput = TouchInput.new()
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.position = Vector2(123.0, 456.0)
	_router.control_mode = Types.ControlMode.KEYBOARD
	touch.handle_event(drag, _router)
	assert_eq(_router.mouse_pos, Vector2(123.0, 456.0), "the drag sets the pointer")
	assert_eq(_router.control_mode, Types.ControlMode.MOUSE, "TiltGame.ts:1283")


func test_screen_drag_is_ignored_under_the_gyro_scheme() -> void:
	var touch: TouchInput = TouchInput.new()
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.position = Vector2(123.0, 456.0)
	_router.control_scheme = Types.ControlScheme.GYRO
	touch.handle_event(drag, _router)
	assert_eq(_router.mouse_pos, Vector2(400.0, 300.0), "TiltGame.ts:1280 skips gyro")


func test_mouse_motion_sets_pointer_and_mode_when_no_keys_held_in_hybrid() -> void:
	var touch: TouchInput = TouchInput.new()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(50.0, 60.0)
	_router.control_scheme = Types.ControlScheme.HYBRID
	_router.control_mode = Types.ControlMode.KEYBOARD
	touch.handle_event(motion, _router)
	assert_eq(
		_router.mouse_pos, Vector2(50.0, 60.0), "TiltGame.ts:1259-1260 always tracks the pointer"
	)
	assert_eq(
		_router.control_mode, Types.ControlMode.MOUSE, "TiltGame.ts:1263-1269 switches to mouse"
	)


func test_mouse_motion_updates_pointer_but_not_mode_under_keyboard_scheme() -> void:
	var touch: TouchInput = TouchInput.new()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(50.0, 60.0)
	_router.control_scheme = Types.ControlScheme.KEYBOARD
	_router.control_mode = Types.ControlMode.KEYBOARD
	touch.handle_event(motion, _router)
	assert_eq(
		_router.mouse_pos, Vector2(50.0, 60.0), "TiltGame.ts:1259-1260 always tracks the pointer"
	)
	assert_eq(
		_router.control_mode,
		Types.ControlMode.KEYBOARD,
		"TiltGame.ts:1265-1266 excludes the keyboard scheme"
	)
