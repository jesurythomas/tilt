## test_gamepad_input.gd
## PORTS: nothing — new file, covers src/input/gamepad_input.gd (PAD R1)
extends GutTest
## Covers the stick's dead zone and rescale, and the button map.


func test_a_resting_stick_steers_nowhere() -> void:
	assert_eq(GamepadInput.shape(Vector2.ZERO), Vector2.ZERO, "centred")
	assert_eq(GamepadInput.shape(Vector2(0.15, -0.1)), Vector2.ZERO, "drift inside the dead zone")


func test_full_tilt_is_unit_length() -> void:
	var v: Vector2 = GamepadInput.shape(Vector2(1.0, 0.0))
	assert_almost_eq(v.x, 1.0, 0.0001, "full right is 1")
	assert_almost_eq(v.y, 0.0, 0.0001, "no y")


func test_a_corner_reading_is_capped_at_one() -> void:
	# A square-gated pad reports (1, 1) in a corner: length 1.41.
	var v: Vector2 = GamepadInput.shape(Vector2(1.0, 1.0))
	assert_almost_eq(v.length(), 1.0, 0.0001, "never faster than full tilt")
	assert_almost_eq(v.x, v.y, 0.0001, "still diagonal")


func test_magnitude_ramps_from_the_dead_zone_edge() -> void:
	var half: float = GamepadInput.DEAD_ZONE + (1.0 - GamepadInput.DEAD_ZONE) * 0.5
	var v: Vector2 = GamepadInput.shape(Vector2(0.0, -half))
	assert_almost_eq(v.length(), 0.5, 0.0001, "halfway past the dead zone is half speed")
	assert_lt(v.y, 0.0, "up stays up (negative y)")


func test_buttons_map_to_actions() -> void:
	assert_eq(GamepadInput.action_for(JOY_BUTTON_A), GamepadInput.PadAction.DASH, "A dashes")
	assert_eq(
		GamepadInput.action_for(JOY_BUTTON_LEFT_SHOULDER), GamepadInput.PadAction.ITEM_1, "LB"
	)
	assert_eq(
		GamepadInput.action_for(JOY_BUTTON_RIGHT_SHOULDER), GamepadInput.PadAction.ITEM_2, "RB"
	)
	assert_eq(GamepadInput.action_for(JOY_BUTTON_START), GamepadInput.PadAction.PAUSE, "Start")
	assert_eq(GamepadInput.action_for(JOY_BUTTON_X), GamepadInput.PadAction.NONE, "X is unused")


func test_poll_without_a_pad_is_zero() -> void:
	# Headless runs have no joypads connected.
	assert_eq(GamepadInput.new().poll(), Vector2.ZERO, "no pad, no steering")


func test_pad_use_turns_on_and_a_touch_turns_off() -> void:
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	assert_true(GamepadInput.is_active_after(press, false), "a button press")
	var nudge: InputEventJoypadMotion = InputEventJoypadMotion.new()
	nudge.axis = JOY_AXIS_LEFT_X
	nudge.axis_value = 0.1
	assert_false(GamepadInput.is_active_after(nudge, false), "drift is not use")
	nudge.axis_value = -0.8
	assert_true(GamepadInput.is_active_after(nudge, false), "a real push")
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	assert_false(GamepadInput.is_active_after(touch, true), "a touch hands back to the screen")
	var key: InputEventKey = InputEventKey.new()
	assert_true(GamepadInput.is_active_after(key, true), "other input leaves it alone")


func test_b_is_back() -> void:
	assert_eq(GamepadInput.action_for(JOY_BUTTON_B), GamepadInput.PadAction.BACK)


func test_families_from_pad_names() -> void:
	assert_eq(GamepadInput.family_for("Xbox Wireless Controller"), GamepadInput.Family.XBOX)
	assert_eq(
		GamepadInput.family_for("Odin Controller"),
		GamepadInput.Family.XBOX,
		"unknown pads read as Xbox"
	)
	assert_eq(
		GamepadInput.family_for("DualSense Wireless Controller"), GamepadInput.Family.PLAYSTATION
	)
	assert_eq(
		GamepadInput.family_for("Sony Interactive Entertainment Wireless Controller"),
		GamepadInput.Family.PLAYSTATION
	)
	assert_eq(GamepadInput.family_for("PS4 Controller"), GamepadInput.Family.PLAYSTATION)
	assert_eq(
		GamepadInput.family_for("Nintendo Switch Pro Controller"), GamepadInput.Family.NINTENDO
	)
	assert_eq(GamepadInput.family_for("Joy-Con (L/R)"), GamepadInput.Family.NINTENDO)


func test_labels_follow_the_family() -> void:
	var dash: GamepadInput.PadAction = GamepadInput.PadAction.DASH
	var item: GamepadInput.PadAction = GamepadInput.PadAction.ITEM_1
	assert_eq(GamepadInput.label_for(dash, GamepadInput.Family.XBOX), "A")
	assert_eq(GamepadInput.label_for(dash, GamepadInput.Family.PLAYSTATION), "×")
	assert_eq(
		GamepadInput.label_for(dash, GamepadInput.Family.NINTENDO), "A", "Android maps by label"
	)
	assert_eq(GamepadInput.label_for(item, GamepadInput.Family.PLAYSTATION), "L1")
	assert_eq(GamepadInput.label_for(item, GamepadInput.Family.NINTENDO), "L")
	assert_eq(GamepadInput.label_for(GamepadInput.PadAction.PAUSE, GamepadInput.Family.XBOX), "")


func test_a_accepts_in_menus() -> void:
	GamepadInput.map_accept()
	GamepadInput.map_accept()
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	press.device = 0
	assert_true(press.is_action("ui_accept"), "a focused button takes A")
	var count: int = 0
	for event: InputEvent in InputMap.action_get_events("ui_accept"):
		if event is InputEventJoypadButton:
			count += 1
	assert_eq(count, 1, "added once")


func test_the_stick_click_dashes_for_one_handed_play() -> void:
	assert_eq(GamepadInput.action_for(JOY_BUTTON_LEFT_STICK), GamepadInput.PadAction.DASH)
