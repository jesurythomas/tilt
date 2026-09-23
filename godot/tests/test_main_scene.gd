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
	_remove(ControlSettings.SETTINGS_PATH)
	_remove(GameOptionsManager.SAVE_PATH)


func after_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))
	_remove(ControlSettings.SETTINGS_PATH)
	_remove(GameOptionsManager.SAVE_PATH)


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


func test_hud_sits_inside_the_arena_frame() -> void:
	# Interface spec §4.4: every HUD control anchors to the frame, never the edge.
	# DEVIATION(brief): the brief's version adds MAIN_SCENE straight to the GUT
	# test tree, whose root Viewport snaps to 64×64 headless (Global Constraints:
	# "Resizing get_tree().root headless does not give a usable size"). At that
	# size the frame is smaller than the HUD's own base-px content, so ScoreBlock
	# and PauseButton overflow it — not a HUD defect. Per that same constraint's
	# fix ("put a screen under a host Control of explicit size"), this test hosts
	# the scene in an explicitly-sized SubViewport (1280×720, the plan's own
	# assumed headless size, interface spec §4.3) instead. No production file or
	# assertion value changed.
	var host: SubViewport = SubViewport.new()
	host.size = Vector2i(1280, 720)
	add_child_autofree(host)
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	host.add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var frame: Control = root.find_child("Frame", true, false) as Control
	assert_not_null(frame, "Frame must exist")
	var rect: Rect2 = frame.get_global_rect()
	assert_almost_eq(
		rect.position, root.arena_origin, Vector2(0.5, 0.5), "frame starts at the inset"
	)
	var viewport: Vector2 = root.get_viewport().get_visible_rect().size
	assert_almost_eq(
		rect.size, viewport - root.arena_origin * 2.0, Vector2(0.5, 0.5), "frame is the playfield"
	)
	for name: String in ["ScoreBlock", "LeftColumn", "PauseButton"]:
		var control: Control = frame.find_child(name, true, false) as Control
		assert_true(rect.encloses(control.get_global_rect()), name + " sits inside the frame")
	var scale: float = HudController.ui_scale_for(viewport)
	assert_true(UiChecks.short_buttons(frame, UiTheme.TOUCH_TARGET * scale).is_empty(), "rule 05")


func test_hud_shows_lives_and_the_weapon_timer_from_the_run() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.toggle_pause()  # the sim stops ticking, so the shield timer holds still
	root._run_controller.max_lives = 3
	root._run_controller.lives = 2
	root._run_controller.player.shield_timer = 1.6
	await get_tree().process_frame
	var lives: HBoxContainer = root.find_child("LivesRow", true, false) as HBoxContainer
	assert_true(lives.visible, "a 3-life run shows its icons (TiltGame.ts:2176)")
	assert_eq(lives.get_child_count(), 3)
	var timer: Control = root.find_child("WeaponTimer", true, false) as Control
	assert_true(timer.visible)
	var label: Label = root.find_child("WeaponTimerLabel", true, false) as Label
	assert_eq(label.text, "SHIELD 1.6s")


func test_pause_calibrate_shows_only_for_tilt() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2226-2244
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var pause_panel: Control = root.find_child("PausePanel", true, false) as Control
	var touch: Button = pause_panel.find_child("TouchButton", true, false) as Button
	touch.pressed.emit()
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	var calibrate: Button = pause_panel.find_child("CalibrateButton", true, false) as Button
	assert_false(calibrate.visible, "hidden unless the scheme is gyro")
	(pause_panel.find_child("TiltButton", true, false) as Button).pressed.emit()
	assert_true(calibrate.visible, "shown once tilt is chosen")


func test_pause_switches_write_settings_through_game_root() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:1396-1416, :1626-1630
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	var sound: CheckButton = root.find_child("SoundSwitch", true, false) as CheckButton
	assert_eq(sound.button_pressed, root.options.settings.sfx_enabled, "mirrors the save on open")
	sound.button_pressed = false
	assert_false(root.options.settings.sfx_enabled)
	assert_false(GameOptionsManager.new().settings.sfx_enabled, "options.save() (:1399)")
	var music: CheckButton = root.find_child("MusicSwitch", true, false) as CheckButton
	music.button_pressed = false
	assert_false(root.options.settings.music_enabled)


func test_pause_restart_run_starts_a_fresh_run() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	assert_true(root.is_paused())
	(root.find_child("RestartRunButton", true, false) as Button).pressed.emit()
	assert_false(root.is_paused(), "GameRoot.restart_run() → PLAYING (interface spec §5)")
	assert_false((root.find_child("PausePanel", true, false) as Control).visible)


func test_pause_stats_show_score_time_and_mode() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	var stats: Label = root.find_child("PauseStats", true, false) as Label
	var mode: String = root.options.get_mode_config(root.options.settings.mode).name
	assert_true(stats.text.ends_with(" · " + mode), stats.text)


func test_run_over_shows_points_and_spend() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2118-2122
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var balance: int = root.progression.data.points
	GameEvents.run_ended.emit(0, Types.GameStats.new())
	var panel: Control = root.find_child("GameOverPanel", true, false) as Control
	assert_true(panel.visible)
	assert_eq(
		(panel.find_child("PointsBalanceLabel", true, false) as Label).text,
		UiTheme.group_digits(balance)
	)
	assert_eq(
		(panel.find_child("SpendValueLabel", true, false) as Label).text,
		UiTheme.group_digits(balance),
		"Spend N reads the balance (:2122)"
	)
	assert_false(
		(panel.find_child("NewBestBanner", true, false) as Control).visible,
		"a zero-score run is not a new best (:2097)"
	)


func test_armory_tilt_slider_reaches_the_tilt_input() -> void:
	# Interface spec §6.4 (ruled): the slider is ControlSettings.tilt_sensitivity,
	# which TiltInput reads (game_root.gd _ready); GameRoot re-applies it on
	# state_changed.
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.open_armory("handling")
	var slider: HSlider = root.find_child("TiltSlider", true, false) as HSlider
	slider.value = 1.6
	assert_almost_eq(root.settings.tilt_sensitivity, 1.6, 0.0001)
	assert_almost_eq(root._tilt.tilt_sensitivity, 1.6, 0.0001)
