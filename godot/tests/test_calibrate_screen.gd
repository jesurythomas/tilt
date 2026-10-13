## test_calibrate_screen.gd
## PORTS: nothing — new file, covers ui/calibrate_screen.gd
extends GutTest
## The Calibrate board (interface spec §6.6, M11a R4-R5).


func _screen() -> CalibrateScreen:
	var screen: CalibrateScreen = CalibrateScreen.new()
	screen.theme = UiTheme.build(1.0)
	screen.size = Vector2(844.0, 390.0)
	add_child_autofree(screen)
	screen.bind(TiltInput.new())
	return screen


func test_open_shows_and_close_hides() -> void:
	var screen: CalibrateScreen = _screen()
	assert_false(screen.is_open())
	screen.open()
	assert_true(screen.is_open())
	watch_signals(screen)
	(screen.find_child("CancelButton", true, false) as Button).pressed.emit()
	assert_false(screen.is_open(), "Cancel closes (R4)")
	assert_signal_emitted(screen, "closed")


func test_set_level_asks_then_closes() -> void:
	var screen: CalibrateScreen = _screen()
	screen.open()
	watch_signals(screen)
	(screen.find_child("SetLevelButton", true, false) as Button).pressed.emit()
	assert_signal_emitted(screen, "set_level_requested", "R4")
	assert_false(screen.is_open())


func test_the_dot_follows_the_tilt_vector_to_the_top_speed_ring() -> void:
	var screen: CalibrateScreen = _screen()
	screen.open()
	screen._tilt.tilt_vector = Vector2(0.5, 0.0)
	assert_almost_eq(screen.dot_offset(), Vector2(33.0, 0.0), Vector2(0.001, 0.001), "half of 66")
	screen._tilt.tilt_vector = Vector2(0.0, 3.0)
	assert_almost_eq(screen.dot_offset(), Vector2(0.0, 66.0), Vector2(0.001, 0.001), "clamped")


func test_the_dot_rests_at_the_centre() -> void:
	var screen: CalibrateScreen = _screen()
	screen.open()
	assert_eq(screen.dot_offset(), Vector2.ZERO)


func test_every_target_meets_the_48_rule() -> void:
	var screen: CalibrateScreen = _screen()
	screen.open()
	await get_tree().process_frame
	for node_name: String in ["SetLevelButton", "CancelButton"]:
		var b: Button = screen.find_child(node_name, true, false) as Button
		assert_true(b.size.y >= 48.0, node_name)


## BUG-101 R3 (user: "i only see set level but not the button below it"): at the A55's size the
## left block grew down from the centre and pushed Cancel off the screen.
func test_both_buttons_fit_on_the_a55() -> void:
	var screen: CalibrateScreen = CalibrateScreen.new()
	add_child_autofree(screen)
	screen.size = Vector2(2340.0, 1080.0)
	screen.bind(TiltInput.new())
	screen.set_ui_scale(2.77, Vector2.ZERO)
	screen.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var bounds: Rect2 = screen.get_global_rect()
	for node_name: String in ["SetLevelButton", "CancelButton"]:
		var b: Button = screen.find_child(node_name, true, false) as Button
		assert_true(bounds.encloses(b.get_global_rect()), node_name + " is on screen")
