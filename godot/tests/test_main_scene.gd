# gdlint:disable=max-public-methods,max-file-lines
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
	_remove(GoalManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH))
	_remove(GoalManager.CUMULATIVE_SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.CUMULATIVE_SAVE_PATH))
	_remove(ScoreManager.BEST_SCORE_PATH)
	_remove(TiltInput.CALIBRATION_PATH)


func after_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))
	_remove(ControlSettings.SETTINGS_PATH)
	_remove(GameOptionsManager.SAVE_PATH)
	_remove(GoalManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH))
	_remove(GoalManager.CUMULATIVE_SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.CUMULATIVE_SAVE_PATH))
	_remove(ScoreManager.BEST_SCORE_PATH)
	_remove(TiltInput.CALIBRATION_PATH)


## Boots the scene and starts a run from the menu, as Play does (TiltMenu.ts:238-241),
## then skips the cold open (M11b) so the run is PLAYING.
func _boot_into_run() -> GameRoot:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	return root


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

	# The menu's Steer row carries a third picker (M11a R7); this counts the HUD's.
	var hud: Node = root.find_child("Hud", true, false)
	var pickers: Array[Node] = hud.find_children("*", "ControlPicker", true, false)
	assert_eq(pickers.size(), 2, "one picker on the pause overlay, one on the death screen")


func test_pause_overlay_marks_the_active_scheme_on_open() -> void:
	var root: GameRoot = await _boot_into_run()

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
	var root: GameRoot = await _boot_into_run()
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
	var root: GameRoot = await _boot_into_run()
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
	var root: GameRoot = await _boot_into_run()
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
	var root: GameRoot = await _boot_into_run()
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
	var root: GameRoot = await _boot_into_run()
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
	var root: GameRoot = await _boot_into_run()
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
	var root: GameRoot = await _boot_into_run()
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
	var root: GameRoot = await _boot_into_run()
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	var sound: CheckButton = root.find_child("SoundSwitch", true, false) as CheckButton
	assert_eq(sound.button_pressed, root.options.settings.sfx_enabled, "mirrors the save on open")
	sound.button_pressed = false
	assert_false(root.options.settings.sfx_enabled)
	assert_false(GameOptionsManager.new().settings.sfx_enabled, "options.save() (:1399)")
	var music: CheckButton = root.find_child("MusicSwitch", true, false) as CheckButton
	music.button_pressed = false
	assert_false(root.options.settings.music_enabled)


func test_runs_log_run_start_and_run_end_to_telemetry() -> void:
	var rec: RecordingTelemetryBackend = RecordingTelemetryBackend.new()
	var previous: TelemetryBackend = Telemetry.backend
	Telemetry.backend = rec
	Telemetry.run_count = 0
	var root: GameRoot = await _boot_into_run()
	assert_eq(
		rec.last_params("run_start"),
		{
			"mode": "classic",
			"first_run": 1,
			"run_index": 1,
			"ship": root.progression.data.equipped_cursor_id,
			"arena": root.progression.data.equipped_arena_theme_id,
		},
		"MVP R6: launch_run logs run_start"
	)
	root._run_controller.scores.stats.score = 900
	root._run_controller.trigger_player_death()
	var ended: Dictionary = rec.last_params("run_end")
	assert_eq(
		[ended["mode"], ended["score"], ended["first_run"], ended["is_best"]],
		["classic", 900, 1, 1],
		"first_run is read before death clears it"
	)
	assert_eq(
		[ended["lives_used"], ended["killer"]],
		[root._run_controller.max_lives, "unknown"],
		"no enemy touched the ship"
	)
	root.restart_run()
	var restarted: Dictionary = rec.last_params("run_start")
	assert_eq([restarted["run_index"], restarted["first_run"]], [2, 0], "restart is a new run")
	Telemetry.backend = previous


func test_reset_progress_keeps_the_usage_opt_out() -> void:
	var saved: GameOptionsManager = GameOptionsManager.new()
	saved.settings.share_usage_data = false
	saved.settings.first_run_done = true
	saved.save()
	GameRoot.reset_progress_files(true)
	var after: GameOptionsManager = GameOptionsManager.new()
	assert_false(after.settings.share_usage_data, "a reset must not turn analytics back on")
	assert_false(after.settings.first_run_done, "everything else is reset")
	GameRoot.reset_progress_files(false)
	assert_true(GameOptionsManager.new().settings.share_usage_data, "no opt-out: back to default")


func test_boot_applies_the_saved_usage_opt_out() -> void:
	var saved: GameOptionsManager = GameOptionsManager.new()
	saved.settings.share_usage_data = false
	saved.save()
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	assert_false(Telemetry.enabled, "MVP R6: the opt-out is honoured from the first frame")
	Telemetry.enabled = true


func test_pause_restart_run_starts_a_fresh_run() -> void:
	var root: GameRoot = await _boot_into_run()
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	assert_true(root.is_paused())
	(root.find_child("RestartRunButton", true, false) as Button).pressed.emit()
	assert_false(root.is_paused(), "GameRoot.restart_run() → PLAYING (interface spec §5)")
	assert_false((root.find_child("PausePanel", true, false) as Control).visible)


func test_pause_stats_show_score_time_and_mode() -> void:
	var root: GameRoot = await _boot_into_run()
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	var stats: Label = root.find_child("PauseStats", true, false) as Label
	var mode: String = root.options.get_mode_config(root.options.settings.mode).name
	assert_true(stats.text.ends_with(" · " + mode), stats.text)


func test_run_over_shows_points_and_the_armory_button() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2118-2122
	var root: GameRoot = await _boot_into_run()
	GameEvents.run_ended.emit(0, Types.GameStats.new())
	# PORT: web/src/tilt-to-live/TiltGame.ts:2089-2151 — the sheet fills 450 ms
	# after the death tick (I-1).
	await get_tree().create_timer(0.5).timeout
	var panel: RunOverSheet = root.find_child("GameOverPanel", true, false) as RunOverSheet
	assert_true(panel.visible)
	panel.finish_count_up()
	# RUNOVER R1: what the run earned, no balance; the button reads "Armory".
	assert_eq((panel.find_child("PointsEarnedLabel", true, false) as Label).text, "+0")
	assert_null(panel.find_child("PointsBalanceLabel", true, false))
	var armory: Button = panel.find_child("GameOverArmoryButton", true, false) as Button
	assert_eq((armory.find_child("NavLabel", true, false) as Label).text, "Armory", "UI R13")
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


func test_an_armory_unlock_completes_its_goal_through_game_root() -> void:
	var root: GameRoot = await _boot_into_run()
	watch_signals(GameEvents)
	root.progression.data.unlocked_cursors.append("solar")
	var armory: ArmoryUI = root.find_child("Armory", true, false) as ArmoryUI
	armory.state_changed.emit()
	assert_true(root.goals.is_completed("unlock_ship_solar"), "TiltGame.ts:2358 → GoalsHUD.ts:264")
	assert_eq(
		root.progression.data.points, ProgressionManager.STARTING_POINTS + 100, "2 × 50 (ECON R1)"
	)
	assert_eq(root._run_controller.points_earned_this_run, 100, "TiltGame.ts:202 (×50)")
	assert_true((root.find_child("GoalToast", true, false) as Control).visible, ":203")
	assert_signal_emitted_with_parameters(GameEvents, "goal_completed", ["unlock_ship_solar"])


func test_rail_and_toast_live_in_the_hud() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var rail: Node = root.find_child("EdgeRail", true, false)
	assert_eq(String(rail.get_parent().name), "Frame", "interface spec §6.5: the frame's top edge")
	var toast: Node = root.find_child("GoalToast", true, false)
	assert_eq(String(toast.get_parent().name), "ToastSlot", "under the lives icons")


func test_calibrate_reports_through_a_message_toast() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var ok: bool = root.calibrate_gyro()
	var title: Label = root.find_child("ToastTitle", true, false) as Label
	var subtitle: Label = root.find_child("ToastSubtitle", true, false) as Label
	# PORT: web/src/tilt-to-live/TiltGame.ts:2335, :2337
	assert_eq(title.text, "TILT CALIBRATED" if ok else "GYRO SENSOR")
	assert_eq(subtitle.text, "Neutral Angle Zeroed ✓" if ok else "Sensor Unavailable or Blocked")


func test_run_over_lists_the_runs_milestones_and_opens_the_screen() -> void:
	var root: GameRoot = await _boot_into_run()
	var rc: RunController = root._run_controller
	rc.run_tracker.score = 1000
	rc.trigger_player_death()
	# PORT: web/src/tilt-to-live/TiltGame.ts:2089-2151 — the sheet fills 450 ms
	# after the death tick (I-1).
	await get_tree().create_timer(0.5).timeout
	var list: VBoxContainer = root.find_child("MilestonesList", true, false) as VBoxContainer
	assert_true(list.visible, "TiltGame.ts:2140")
	assert_eq(list.get_child_count(), 1)
	var text: Label = list.get_child(0).find_child("MilestoneText", true, false) as Label
	assert_eq(text.text, "Rookie Dodger", ":2136 — ACH R3: the title alone")
	(root.find_child("GameOverPanel", true, false) as RunOverSheet).finish_count_up()
	var earned: Label = root.find_child("PointsEarnedLabel", true, false) as Label
	assert_eq(earned.text, "+110", "payout 60 + score_1k 50 (ECON R1)")
	assert_eq(root.progression.data.points, 610, "500 + 110 banked (:2119)")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	list.gui_input.emit(click)
	var release: InputEventMouseButton = click.duplicate() as InputEventMouseButton
	release.pressed = false
	list.gui_input.emit(release)  # ACH R3: the list opens the screen on release
	var screen: Control = root.find_child("MilestonesModal", true, false) as Control
	assert_true(screen.visible, "GoalsHUD.ts:131-132")
	(root.find_child("GoalsHud", true, false) as GoalsHUD).close_all_goals_modal()
	(root.find_child("PointsRow", true, false) as Control).gui_input.emit(click)
	assert_true(screen.visible, "GoalsHUD.ts:133-134")


func test_run_over_hides_an_empty_milestones_list() -> void:
	var root: GameRoot = await _boot_into_run()
	root._run_controller.trigger_player_death()
	# PORT: web/src/tilt-to-live/TiltGame.ts:2089-2151 — the sheet fills 450 ms
	# after the death tick (I-1).
	await get_tree().create_timer(0.5).timeout
	assert_false((root.find_child("MilestonesList", true, false) as Control).visible, ":2141-2143")
	(root.find_child("GameOverPanel", true, false) as RunOverSheet).finish_count_up()
	assert_eq((root.find_child("PointsEarnedLabel", true, false) as Label).text, "+60")
	assert_eq(root.progression.data.points, 560, "the payout floor banked")


## I-1 regression: the death tick's step 8 (run_controller.gd:227) runs
## evaluate_live_total_goals AFTER trigger_player_death's evaluate_run has
## already folded the run's goal rewards into cumulative.total_points_earned
## (goal_manager.gd:213-214), so a total_points goal can complete on the death
## tick itself. Run over's 450 ms delay (TiltGame.ts:2089-2151) must still
## show that completion's points in "Points earned" and the balance.
func test_run_over_includes_a_total_goal_completed_on_the_death_tick() -> void:
	var root: GameRoot = await _boot_into_run()
	var rc: RunController = root._run_controller
	var balance_before: int = rc.progression.data.points
	# One milestone short of total_points_10's target of 500 (ECON R1: 10 × 50);
	# score_1k's +50 reward (evaluate_run step 3) closes the gap, which only
	# evaluate_live_total_goals (step 8) can see (:1954 vs :2086 order).
	rc.goals.cumulative.total_points_earned = 450
	rc.run_tracker.score = 1000
	rc.trigger_player_death()
	assert_false(rc.goals.is_completed("total_points_10"), "not yet — step 8 has not run")
	# Simulate run_controller.gd step 8, which runs after run_ended in the same
	# tick (update()'s top-of-function guard is only checked once per call).
	rc.goals.evaluate_live_total_goals(rc.run_tracker)
	assert_true(rc.goals.is_completed("total_points_10"), "death-tick live check")
	await get_tree().create_timer(0.5).timeout
	(root.find_child("GameOverPanel", true, false) as RunOverSheet).finish_count_up()
	var earned: Label = root.find_child("PointsEarnedLabel", true, false) as Label
	# ECON R1: the payout (60 base, 0 s, 0 kills) + score_1k 50 + total_points_10 100.
	assert_eq(earned.text, "+210", "payout + both milestones, step 8 included")
	assert_eq(
		rc.progression.data.points,
		balance_before + 210,
		"the death-tick completion must reach the balance (:2119)",
	)


func test_play_launches_the_selected_mode() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	(root._menu.find_child("ModeCard_gauntlet", true, false) as Button).pressed.emit()
	(root._menu.find_child("PlayButton", true, false) as Button).pressed.emit()
	assert_eq(root._run_controller.mode, Types.GameMode.GAUNTLET, "TiltGame.ts:1486-1488")
	assert_not_null(root._run_controller.maze)
	assert_eq(root._run_controller.maze, root._maze)
	var expected: float = clampf(
		GameRoot.effective_arena_scale(root._bounds.x, root._bounds.y, OS.has_feature("mobile")),
		0.5,
		1.8
	)
	assert_almost_eq(root._maze.scale, expected, 0.0001, "TiltGame.ts:2435")


func test_game_root_attaches_the_audio_bank() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var bank: AudioBank = root._audio
	assert_not_null(bank._playback, "GameRoot._ready attaches the bank (M5 R10)")
	assert_eq(bank._streams.size(), AudioBank.SFX_STEMS.size(), "every baked file loaded")


func test_a_launched_run_starts_the_music_when_it_is_on() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var bank: AudioBank = root._audio
	assert_false(bank._music_player.playing, "no music in the menu")
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()  # M11b: the cold open ends before the run plays
	assert_eq(
		bank._music_player.playing,
		root.options.settings.music_enabled,
		"the cinematic's handover starts it (TiltGame.ts:170-172, M11b R6)"
	)


func test_shake_offsets_the_arena_layers_and_decays() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.launch_run(root.options.settings.mode)
	root.trigger_shake(10.0)
	assert_eq(root.camera_shake, 10.0, "TiltRenderer.ts:16")
	await get_tree().process_frame
	assert_almost_eq(root.camera_shake, 8.8, 0.0001, "x0.88 per rendered frame (:51)")
	var grid_layer: Node2D = root.find_child("GridLayer", true, false) as Node2D
	var entity_layer: Node2D = root.find_child("EntityLayer", true, false) as Node2D
	var effect_layer: Node2D = root.find_child("EffectLayer", true, false) as Node2D
	assert_eq(grid_layer.position, entity_layer.position, "one offset for the whole ctx.save")
	assert_eq(grid_layer.position, effect_layer.position)
	assert_true(absf(grid_layer.position.x) <= 10.0 and absf(grid_layer.position.y) <= 10.0)


func test_halo_option_reaches_the_entity_layer() -> void:
	var saved: GameOptionsManager = GameOptionsManager.new()
	saved.settings.high_contrast_halo = false
	saved.save()
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	assert_false(root._entity_layer._high_contrast_halo, "TiltGame.ts:2281/:2314")
	root.options.settings.high_contrast_halo = true
	root.apply_readability()
	assert_true(root._entity_layer._high_contrast_halo)


func test_boot_shows_the_menu_and_no_run() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	assert_true(root.is_in_menu(), "TiltGame.ts:1476")
	assert_true(root._menu.is_menu_visible(), ":1478")
	assert_false(root._audio._music_player.playing, "no music in the menu")
	assert_true(root._goals_hud.in_menu_mode, ":1477")
	assert_false(
		(root.find_child("ScoreBlock", true, false) as Control).is_visible_in_tree(), "R12"
	)


func test_the_backdrop_steps_only_in_the_menu() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var before: float = root._backdrop.elapsed
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_gt(root._backdrop.elapsed, before, "TiltGame.ts:1829-1830")
	root.launch_run(root.options.settings.mode)
	var frozen: float = root._backdrop.elapsed
	await get_tree().physics_frame
	assert_eq(root._backdrop.elapsed, frozen, "only the run steps while playing")


func test_return_to_menu_rebinds_the_backdrop_and_back() -> void:
	var root: GameRoot = await _boot_into_run()
	assert_eq(root._entity_layer._player, root._player, "run bindings")
	root.return_to_menu()
	assert_true(root.is_in_menu())
	assert_eq(root._entity_layer._player, root._backdrop.menu_player, "R13")
	assert_null(root._entity_layer._ship_skin, "renderMenuBackground passes no skin (:2274)")
	assert_null(root._grid_layer.get_arena_theme(), ":2276")
	assert_false(root._effect_layer.is_banner_drawn())
	root.launch_run(root.options.settings.mode)
	assert_eq(root._entity_layer._player, root._player, "rebound for the run")
	assert_eq(root._entity_layer._ship_skin, root.progression.get_equipped_ship())


func test_return_to_menu_from_the_menu_is_a_no_op() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	watch_signals(GameEvents)
	root.return_to_menu()
	assert_signal_not_emitted(GameEvents, "phase_changed", "TiltGame.ts:1497")


func test_p_and_escape_follow_the_ts_key_map() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_P
	key.pressed = true
	root._unhandled_input(key)
	assert_true(root.is_in_menu(), "menu: p does nothing (:1327-1329)")
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()  # M11b: the cold open ends before the run plays
	root._unhandled_input(key)
	assert_true(root.is_paused(), "playing → paused")
	var pause_panel: Control = root.find_child("PausePanel", true, false) as Control
	assert_true(pause_panel.visible, "the pause sheet opens (:1619-1630)")
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root._unhandled_input(esc)
	assert_false(root.is_paused(), "paused → playing (:1325)")
	assert_false(pause_panel.visible, "the pause sheet closes on resume")
	root.open_armory()
	root._unhandled_input(esc)
	assert_false(root.is_armory_open(), "Armory open → Escape closes it first (:1326-1327)")
	assert_true(root.is_paused(), "and the run stays paused")


func test_space_enter_and_r_restart_after_death() -> void:
	var root: GameRoot = await _boot_into_run()
	root._player.shield_timer = 0.0  # M11b: past the cold open's spawn shield (:216)
	root._run_controller.lives = 1
	root._run_controller.lose_life()
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	root._unhandled_input(key)
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "TiltGame.ts:1311-1316, :1523-1530")
	root.skip_cinematic()
	assert_eq(root._state.phase, Types.GamePhase.PLAYING, "TiltGame.ts:1311-1316, :1523-1530")


func test_play_opens_the_cold_open_and_hands_over_to_the_run() -> void:
	# DEVIATION(brief): GUT's default headless viewport snaps to a tiny size
	# (test_hud_sits_inside_the_arena_frame's "Global Constraints"), so the
	# cinematic's classic seekers spawn on top of the player, who still carries
	# the cold open's spawn shield (:216) — every seeker dies to a shield ram
	# the instant PLAYING ticks. Hosting in an explicit-size SubViewport, as
	# that test does, gives the handover a real arena. No assertion changed.
	var host: SubViewport = SubViewport.new()
	host.size = Vector2i(1280, 720)
	add_child_autofree(host)
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	host.add_child(root)
	await get_tree().process_frame
	watch_signals(GameEvents)
	root.launch_run(Types.GameMode.CLASSIC)
	var cold_open: EntranceCinematic = root.find_child("ColdOpen", true, false) as EntranceCinematic
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "TiltGame.ts:1526")
	assert_true(cold_open.visible)
	assert_signal_emitted_with_parameters(GameEvents, "phase_changed", [Types.GamePhase.CINEMATIC])
	assert_eq(root._weapons.orbs.size(), 0, "nothing in the arena yet (:60-61)")
	for i: int in range(40):
		root._physics_process(1.0 / 60.0)
	assert_eq(root._state.phase, Types.GamePhase.PLAYING, "onFinish (:169)")
	assert_false(cold_open.visible)
	assert_eq(root._swarm.enemies.size(), 8, "the Classic handover (:204)")
	assert_eq(root._weapons.orbs.size(), 2, "the nuke (:212) + the starting orb (:176)")


func test_music_starts_once_at_the_handover() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.options.settings.music_enabled = true
	root.launch_run(Types.GameMode.CLASSIC)
	assert_false(root._audio._music_player.playing, "not during the cold open (:168-172)")
	root.skip_cinematic()
	root.skip_cinematic()
	assert_true(root._audio._music_player.playing, "TiltGame.ts:170-172")
	assert_eq(root._weapons.orbs.size(), 2, "Review Focus 1: one handover, one starting orb")


func test_space_enter_and_escape_skip_the_cold_open_and_escape_does_not_pause() -> void:
	for keycode: Key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
		add_child_autofree(root)
		await get_tree().process_frame
		root.launch_run(Types.GameMode.CLASSIC)
		var key: InputEventKey = InputEventKey.new()
		key.keycode = keycode
		key.pressed = true
		root._unhandled_input(key)
		assert_eq(
			root._state.phase, Types.GamePhase.PLAYING, "TiltGame.ts:1302-1309 (%d)" % keycode
		)
		assert_false(root.is_paused(), "Review Focus 4: the skip returns before p/Escape")


func test_a_tap_on_the_cold_open_skips_it() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.launch_run(Types.GameMode.CLASSIC)
	var cold_open: EntranceCinematic = root.find_child("ColdOpen", true, false) as EntranceCinematic
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	cold_open._gui_input(touch)
	assert_eq(root._state.phase, Types.GamePhase.PLAYING, "TiltEntranceCinematic.ts:96-102")


func test_restart_inside_the_run_over_delay_keeps_the_sheet_shut() -> void:
	var root: GameRoot = await _boot_into_run()
	root._player.shield_timer = 0.0  # M11b: past the cold open's spawn shield (:216)
	root._run_controller.lose_life()
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root._unhandled_input(key)
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "TiltGame.ts:1315")
	var timer: Timer = root._hud._run_over_timer
	assert_true(timer.is_stopped(), "R9: resetRun hides the modals (:1612-1613)")
	var sheet: Control = root.find_child("GameOverPanel", true, false) as Control
	assert_false(sheet.visible, "Review Focus 3")


func test_retry_replays_the_cold_open_with_a_fresh_arena() -> void:
	var root: GameRoot = await _boot_into_run()
	root._swarm.spawn_seeker(root._bounds, 10.0, 10.0)
	root.restart_run()
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "TiltGame.ts:1519-1521 (R10)")
	assert_eq(root._swarm.enemies.size(), 0, "the cold open clears the arena (:60)")
	root.skip_cinematic()
	assert_eq(root._swarm.enemies.size(), 8, "Review Focus 5: only the new handover")
	assert_eq(root._weapons.orbs.size(), 2)


func test_menu_settles_under_milestones_and_armory() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var menu: Node = root.find_child("Menu", true, false)
	var hud: Node = root.find_child("Hud", true, false)
	var goals: Node = root.find_child("GoalsHud", true, false)
	assert_gt(menu.get_index(), hud.get_index(), "over Pause (Settings from Pause, Task 7)")
	assert_lt(menu.get_index(), goals.get_index(), "under Milestones and Armory")


## M11a R12: the idle run behind the menu must not re-show the run HUD, and the
## next run's lives row must redraw even when its pips match the last run's.
func test_the_menu_keeps_the_run_hud_hidden_and_the_next_run_redraws_it() -> void:
	var root: GameRoot = await _boot_into_run()
	var lives: Control = root.find_child("LivesRow", true, false) as Control
	var timer: Control = root.find_child("WeaponTimer", true, false) as Control
	root._run_controller.max_lives = 3
	root._run_controller.lives = 3
	root._run_controller.player.shield_timer = 3.0
	await get_tree().process_frame
	assert_true(lives.visible, "precondition: a 3-life run shows its icons")
	assert_true(timer.visible, "precondition: the shield timer shows")
	root.return_to_menu()
	await get_tree().process_frame
	assert_false(timer.visible, "R12: hidden in the menu, live shield or not")
	assert_false(lives.visible, "R12")
	root.launch_run(Types.GameMode.GAUNTLET)
	assert_eq(root.options.settings.mode, Types.GameMode.GAUNTLET, "TiltGame.ts:1487-1489")
	root._run_controller.max_lives = 3
	root._run_controller.lives = 3
	await get_tree().process_frame
	assert_true(lives.visible, "the same pips redraw in the next run (R12)")


func test_reset_cancel_keeps_every_file() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.options.save()
	root.progression.add_points(5)
	root._menu.open_options_modal()
	(root.find_child("ResetButton", true, false) as Button).pressed.emit()
	(root.find_child("ResetCancelButton", true, false) as Button).pressed.emit()
	assert_true(FileAccess.file_exists(GameOptionsManager.SAVE_PATH))
	assert_true(FileAccess.file_exists(ProgressionManager.SAVE_PATH))


func test_reset_confirm_removes_progress_and_keeps_controls() -> void:
	GameOptionsManager.new().save()
	var goals: GoalManager = GoalManager.new()
	goals.save_completed()
	goals.save_cumulative()
	var progression: ProgressionManager = ProgressionManager.new()
	progression.add_points(5)
	ControlSettings.new().save_settings()
	SaveStore.save_dict(ScoreManager.BEST_SCORE_PATH, {"bestScore": 1200})
	GameRoot.reset_progress_files()
	assert_false(FileAccess.file_exists(GameOptionsManager.SAVE_PATH), "settings_v1 (:512)")
	assert_false(FileAccess.file_exists(GoalManager.SAVE_PATH), "completed_goals_v1 (:513)")
	assert_false(
		FileAccess.file_exists(GoalManager.CUMULATIVE_SAVE_PATH), "cumulative_stats_v1 (:514)"
	)
	assert_false(
		FileAccess.file_exists(ProgressionManager.SAVE_PATH), "R10 (Q1 ruling): :515's intent"
	)
	assert_false(
		FileAccess.file_exists(ScoreManager.BEST_SCORE_PATH), "R10 (Q1 ruling): :516's intent"
	)
	assert_true(FileAccess.file_exists(ControlSettings.SETTINGS_PATH), "R10: not in the prompt")


func test_settings_switches_apply_at_once() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root._menu.open_options_modal()
	(root.find_child("HaloSwitch", true, false) as CheckButton).toggled.emit(false)
	(root.find_child("GridSwitch", true, false) as CheckButton).toggled.emit(true)
	(root.find_child("SfxSwitch", true, false) as CheckButton).toggled.emit(false)
	assert_false(root._entity_layer._high_contrast_halo, "R2/R9")
	assert_true(root._grid_layer.show_gridlines)
	assert_true(root._audio.is_muted(), "R9 (Q2 ruling): set_sfx_enabled at once")
	assert_false(GameOptionsManager.new().settings.sfx_enabled, "and saved")


func test_the_menu_calibrate_icon_opens_the_screen_and_set_level_calibrates() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	(root.find_child("MenuCalibrateButton", true, false) as Button).pressed.emit()
	var screen: CalibrateScreen = root.find_child("Calibrate", true, false) as CalibrateScreen
	assert_true(screen.is_open(), "R5")
	(screen.find_child("SetLevelButton", true, false) as Button).pressed.emit()
	assert_false(screen.is_open())
	# Headless has no gyro (TiltInput.is_supported is Android/iOS only), so
	# calibrate_gyro's toast falls back to the "Sensor Unavailable" title (:2337).
	var title: Label = root.find_child("ToastTitle", true, false) as Label
	assert_eq(title.text, "GYRO SENSOR", "calibrate_gyro's toast shows on the menu (R12)")
	assert_true((root.find_child("GoalToast", true, false) as Control).visible)
	assert_false(
		root._tilt.is_listening,
		"trivially true headless: is_supported gates start_listening to Android/iOS (R4)"
	)


func test_pause_quit_to_menu_hides_everything_and_stops_music() -> void:
	var root: GameRoot = await _boot_into_run()
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	(root.find_child("QuitToMenuButton", true, false) as Button).pressed.emit()
	assert_true(root.is_in_menu(), "TiltGame.ts:1392-1393")
	assert_false((root.find_child("PausePanel", true, false) as Control).visible, ":1502")
	assert_false(root._audio._music_player.playing, ":1501")
	assert_true(root._menu.is_menu_visible(), ":1509")


func test_run_over_menu_returns_to_the_menu() -> void:
	var root: GameRoot = await _boot_into_run()
	root._player.shield_timer = 0.0  # M11b: past the cold open's spawn shield (:216)
	root._run_controller.lives = 1
	root._run_controller.lose_life()
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER)
	# PORT: web/src/tilt-to-live/TiltGame.ts:2089-2151 — the sheet fills 450 ms
	# after the death tick (I-1).
	await get_tree().create_timer(0.5).timeout
	(root.find_child("GameOverMenuButton", true, false) as Button).pressed.emit()
	assert_true(root.is_in_menu(), "TiltGame.ts:1428-1430")
	assert_false((root.find_child("GameOverPanel", true, false) as Control).visible, ":1503")


func test_pause_settings_opens_the_options_modal_over_pause() -> void:
	var root: GameRoot = await _boot_into_run()
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	(root.find_child("PauseSettingsButton", true, false) as Button).pressed.emit()
	assert_true(root._menu.is_options_open(), "TiltGame.ts:1418-1420")
	assert_true(root.is_paused(), "the run stays paused")
	(root._menu.find_child("ResetButton", true, false) as Button).pressed.emit()
	(root.find_child("OptionsBackButton", true, false) as Button).pressed.emit()
	assert_false(
		(root.find_child("ResetConfirm", true, false) as Control).visible,
		"closing the modal takes its confirm with it"
	)
	assert_true((root.find_child("PausePanel", true, false) as Control).visible, "back to Pause")


func test_closing_settings_from_pause_refreshes_the_pause_sheet() -> void:
	# Final review I-2 (DIVERGENCE(M11a I-2)): closing Settings over Pause
	# emitted nothing, so Pause's own Sound switch kept showing whatever it
	# read when Pause first opened, even after Settings changed the option.
	var root: GameRoot = await _boot_into_run()
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	root.open_options_from_pause()
	(root._menu.find_child("SfxSwitch", true, false) as CheckButton).toggled.emit(false)
	(root.find_child("OptionsBackButton", true, false) as Button).pressed.emit()
	var pause_sound: CheckButton = (
		(root.find_child("PausePanel", true, false) as Control).find_child(
			"SoundSwitch", true, false
		)
		as CheckButton
	)
	assert_eq(
		pause_sound.button_pressed,
		root.options.settings.sfx_enabled,
		"Pause's own switch must reflect a change made in Settings (final review I-2)"
	)


func test_launch_run_does_not_recalibrate_the_gyro() -> void:
	# Final review I-1(b): launch_run's uncited calibrate_current_position()
	# call (TiltGame.ts launchRun/resetRun never recalibrate) silently
	# overwrote whatever pose the player had just set on the Calibrate
	# board, because Play always follows Calibrate back to the menu.
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root._tilt.start_listening()
	root._tilt.calibrate_current_position()
	var pose: Vector3 = Vector3(2.0, -8.0, -5.7)
	root._tilt.apply_gravity(pose, 90)
	assert_false(root._tilt.is_calibration_pending(), "the pose is captured before Play")
	var calibrated_before: Vector3 = root._tilt._calibrated_gravity
	root.launch_run(root.options.settings.mode)
	assert_false(root._tilt.is_calibration_pending(), "launch_run must not re-arm a calibration")
	assert_eq(
		root._tilt._calibrated_gravity,
		calibrated_before,
		"launch_run must not recalibrate the gyro (final review I-1)"
	)


func test_a_run_clips_the_play_layers_to_the_arena() -> void:
	# M11c review: blast rings and pushed grid lines drew into the margin.
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(root.arena_clip_rect.has_area(), "no clip in the menu")
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	root.camera_shake = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(root.arena_clip_rect.position, root.arena_origin, "clipped at the arena origin")
	assert_eq(root.arena_clip_rect.size, root.get_viewport_rect().size - root.arena_origin * 2.0)


func test_run_over_lists_every_achievement_of_the_run() -> void:
	# ACH R2: a live achievement completed mid-run is listed with evaluate_run's at death.
	var root: GameRoot = await _boot_into_run()
	var rc: RunController = root._run_controller
	rc.goals.cumulative.total_kills = 99
	rc.run_tracker.kills = 1
	rc.goals.evaluate_live_total_goals(rc.run_tracker)  # step 8 mid-run: total_kills_100
	rc.run_tracker.score = 1000
	rc.trigger_player_death()  # evaluate_run: score_1k
	await get_tree().create_timer(0.5).timeout
	var list: VBoxContainer = root.find_child("MilestonesList", true, false) as VBoxContainer
	var ids: Array[String] = []
	for row: Node in list.get_children():
		ids.append(str(row.name).trim_prefix("MilestoneRow_"))
	assert_true(ids.has("total_kills_100"), "the mid-run one: %s" % [ids])
	assert_true(ids.has("score_1k"), "the death-tick one")
	var header: Label = root.find_child("AchievementsHeader", true, false) as Label
	assert_eq(header.text, "ACHIEVEMENTS · %d" % ids.size())
	rc.reset_run(root._bounds)
	assert_true(rc.run_achievements.is_empty(), "a new run starts a new list")
