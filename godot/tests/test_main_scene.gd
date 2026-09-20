## test_main_scene.gd
## PORTS: nothing — new file, covers scenes/main.tscn
extends GutTest
## Verifies scenes/main.tscn exposes every node hud_controller.gd and
## control_picker.gd look up, per M2.5 spec §4.3, §4.4, §7.1, §7.4.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")


func test_main_scene_exposes_required_hud_nodes() -> void:
	var root: Node = MAIN_SCENE.instantiate()
	add_child_autofree(root)

	var labels: Array[String] = [
		"ScoreLabel",
		"BestLabel",
		"MultiplierLabel",
		"FinalScoreLabel",
		"FinalKillsLabel",
		"FinalTimeLabel",
		"NewBestLabel",
	]
	for label_name: String in labels:
		var node: Node = root.find_child(label_name, true, false)
		assert_true(node is Label, "%s must exist and be a Label" % label_name)

	var controls: Array[String] = ["GameOverPanel", "PausePanel"]
	for control_name: String in controls:
		var node: Node = root.find_child(control_name, true, false)
		assert_true(node is Control, "%s must exist and be a Control" % control_name)

	var buttons: Array[String] = ["RestartButton", "PauseButton", "ResumeButton"]
	for button_name: String in buttons:
		var node: Node = root.find_child(button_name, true, false)
		assert_true(node is Button, "%s must exist and be a Button" % button_name)

	var layers: Array[String] = ["GridLayer", "EntityLayer", "EffectLayer", "JoystickLayer"]
	for layer_name: String in layers:
		var node: Node = root.find_child(layer_name, true, false)
		assert_true(node is Node2D, "%s must exist and be a Node2D" % layer_name)

	var pickers: Array[Node] = root.find_children("*", "ControlPicker", true, false)
	assert_eq(pickers.size(), 2, "one picker on the pause overlay, one on the death screen")


func test_pause_overlay_marks_the_active_scheme_on_open() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame

	var pause_button: Button = root.find_child("PauseButton", true, false) as Button
	assert_not_null(pause_button, "PauseButton must exist")
	pause_button.pressed.emit()

	var pause_panel: Control = root.find_child("PausePanel", true, false) as Control
	assert_not_null(pause_panel, "PausePanel must exist")
	var picker: ControlPicker = (
		pause_panel.find_child("ControlPicker", true, false) as ControlPicker
	)
	assert_not_null(picker, "the pause overlay carries a ControlPicker")

	var tilt_button: Button = picker.find_child("TiltButton", true, false) as Button
	var touch_button: Button = picker.find_child("TouchButton", true, false) as Button
	var keyboard_button: Button = picker.find_child("KeyboardButton", true, false) as Button

	# I1: root.settings is created in GameRoot._ready(), which runs after
	# HudController._ready() (HudController is GameRoot's descendant), so the
	# picker's initial _sync_pickers() call is a no-op. Opening the pause
	# overlay must re-sync it against whatever GameRoot.settings.scheme holds.
	match root.settings.scheme:
		Types.ControlScheme.GYRO:
			assert_true(tilt_button.button_pressed)
			assert_false(touch_button.button_pressed)
			assert_false(keyboard_button.button_pressed)
		Types.ControlScheme.KEYBOARD:
			assert_false(tilt_button.button_pressed)
			assert_false(touch_button.button_pressed)
			assert_true(keyboard_button.button_pressed)
		_:
			assert_false(tilt_button.button_pressed)
			assert_true(touch_button.button_pressed)
			assert_false(keyboard_button.button_pressed)


func test_control_pickers_report_a_nonzero_minimum_height() -> void:
	var root: Node = MAIN_SCENE.instantiate()
	add_child_autofree(root)
	await get_tree().process_frame

	var pickers: Array[Node] = root.find_children("*", "ControlPicker", true, false)
	for picker: Node in pickers:
		var typed: ControlPicker = picker as ControlPicker
		assert_gt(
			typed.get_combined_minimum_size().y,
			0.0,
			"a zero minimum height overflows the HBox onto RESUME / PLAY AGAIN"
		)
