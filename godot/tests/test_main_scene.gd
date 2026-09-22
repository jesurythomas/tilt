## test_main_scene.gd
## PORTS: nothing — new file, covers scenes/main.tscn
extends GutTest
## Verifies scenes/main.tscn exposes every node hud_controller.gd and
## control_picker.gd look up, per M2.5 spec §4.3, §4.4, §7.1, §7.4.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))


func after_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))


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

	var buttons: Array[String] = [
		"RestartButton", "PauseButton", "ResumeButton", "PauseArmoryButton", "GameOverArmoryButton"
	]
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


func test_main_scene_carries_the_armory_and_its_buttons() -> void:
	var root: Node = MAIN_SCENE.instantiate()
	add_child_autofree(root)
	var armory: Node = root.find_child("Armory", true, false)
	assert_true(armory is ArmoryUI, "Armory must be instanced under CanvasLayer")
	assert_false((armory as ArmoryUI).visible, "closed at boot")
	var canvas: Node = root.find_child("CanvasLayer", true, false)
	assert_eq(armory.get_parent(), canvas, "same CanvasLayer as the HUD, after it")
	assert_gt(
		armory.get_index(), root.find_child("Hud", true, false).get_index(), "draws above the HUD"
	)
	assert_true(root.find_child("PauseArmoryButton", true, false) is Button)
	assert_true(root.find_child("GameOverArmoryButton", true, false) is Button)


func test_armory_root_and_overlay_cover_the_whole_viewport() -> void:
	# Finding 1: only the panel is inset by arena_origin; the root Control and
	# its Overlay ColorRect must cover the full screen (game.css:1601-1602
	# `.armory-overlay { position: fixed; inset: 0 }`).
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	root.resize_canvas()
	var viewport_rect: Rect2 = root.get_viewport().get_visible_rect()
	var armory: Control = root.find_child("Armory", true, false) as Control
	var overlay: ColorRect = armory.find_child("Overlay", true, false) as ColorRect
	assert_eq(armory.get_global_rect(), viewport_rect, "Armory root stays full-rect")
	assert_eq(overlay.get_global_rect(), viewport_rect, "Overlay always covers the screen")


func test_pause_armory_button_leaves_the_pause_panel_under_the_overlay() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2343-2347 (branch not taken from
	# an already-paused phase), :2379-2385
	# PORT-NOTE: the phase is already PAUSED here, so the playing→paused
	# branch at :2344 is skipped and the pause modal is never hidden; on the
	# web the Armory's z-100 overlay (game.css:1603) simply draws over it, and
	# handleArmoryClosed's classList.remove('hidden') (:2380) is then a no-op.
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var pause_button: Button = root.find_child("PauseButton", true, false) as Button
	pause_button.pressed.emit()
	assert_true(root.is_paused())
	var pause_panel: Control = root.find_child("PausePanel", true, false) as Control
	assert_true(pause_panel.visible)

	var armory_button: Button = root.find_child("PauseArmoryButton", true, false) as Button
	armory_button.pressed.emit()
	assert_true(root.is_armory_open())
	assert_true(root.is_paused(), "still paused underneath")
	assert_true(
		pause_panel.visible, "already paused; the playing→paused branch isn't taken (:2344)"
	)

	root.close_armory()
	assert_false(root.is_armory_open())
	assert_true(
		pause_panel.visible, "handleArmoryClosed's remove('hidden') is a no-op here (:2380)"
	)
	assert_true(root.is_paused())


func test_opening_the_armory_while_playing_pauses() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	assert_false(root.is_paused())
	root.open_armory("boosts")
	assert_true(root.is_paused(), "openArmory pauses a live run (:2344-2345)")
	var armory: ArmoryUI = root.find_child("Armory", true, false) as ArmoryUI
	assert_eq(armory.active_tab, ArmoryUI.Tab.BOOSTS)
	var pause_panel: Control = root.find_child("PausePanel", true, false) as Control
	assert_false(pause_panel.visible)
	root.close_armory()
	assert_true(pause_panel.visible, "the player resumes from the pause overlay")


func test_game_over_armory_button_opens_without_touching_phase() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var stats: Types.GameStats = Types.GameStats.new()
	GameEvents.run_ended.emit(0, stats)
	var button: Button = root.find_child("GameOverArmoryButton", true, false) as Button
	button.pressed.emit()
	assert_true(root.is_armory_open())
	assert_false(root.is_paused(), "game-over is not the playing phase; nothing to pause (:2344)")
	root.close_armory()
	var pause_panel: Control = root.find_child("PausePanel", true, false) as Control
	assert_false(
		pause_panel.visible, "handleArmoryClosed only restores the modal when paused (:2380)"
	)


func test_b_key_toggles_and_escape_closes_the_armory() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:1319-1328
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var pause_panel: Control = root.find_child("PausePanel", true, false) as Control
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_B
	key.pressed = true
	root._unhandled_input(key)
	assert_true(root.is_armory_open())
	assert_true(root.is_paused(), "b from PLAYING pauses the run (:2344-2345)")
	assert_false(pause_panel.visible, "pauseModal hidden on the playing→paused transition (:2346)")
	root._unhandled_input(key)
	assert_false(root.is_armory_open(), "b toggles")
	assert_true(pause_panel.visible, "pauseModal restored on close (:2380-2381)")
	key.keycode = KEY_U
	root._unhandled_input(key)
	assert_true(root.is_armory_open(), "u toggles too")
	key.keycode = KEY_ESCAPE
	root._unhandled_input(key)
	assert_false(root.is_armory_open(), "Escape closes")


func test_armory_state_change_pushes_cosmetics_to_the_layers() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.progression.equip_ship("tactical")
	var armory: ArmoryUI = root.find_child("Armory", true, false) as ArmoryUI
	armory.state_changed.emit()
	var entity_layer: EntityLayer = root.find_child("EntityLayer", true, false) as EntityLayer
	assert_eq(
		entity_layer.get_ship_skin().id,
		"tactical",
		"handleProgressionChanged → layers (:2356-2361)"
	)
	var grid_layer: GridLayer = root.find_child("GridLayer", true, false) as GridLayer
	assert_eq(grid_layer.get_arena_theme().id, "void")
