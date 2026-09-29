# gdlint:disable=max-public-methods
## test_tilt_menu.gd
## PORTS: nothing — new file, covers ui/tilt_menu.gd
extends GutTest
## The menu screen (TiltMenu.ts:87-255) and, from Task 5, the options modal.

var _options: GameOptionsManager = null
var _progression: ProgressionManager = null
var _goals: GoalManager = null
var _scores: ScoreManager = null
var _settings: ControlSettings = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _clear() -> void:
	for path: String in [
		GameOptionsManager.SAVE_PATH,
		ProgressionManager.SAVE_PATH,
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
		ControlSettings.SETTINGS_PATH,
		ScoreManager.BEST_SCORE_PATH,
	]:
		_remove(path)


func before_each() -> void:
	_clear()
	_options = GameOptionsManager.new()
	_progression = ProgressionManager.new()
	_goals = GoalManager.new()
	_scores = ScoreManager.new()
	_settings = ControlSettings.new()


func after_each() -> void:
	_clear()


func _menu() -> TiltMenu:
	var menu: TiltMenu = TiltMenu.new()
	menu.theme = UiTheme.build(1.0)
	menu.size = Vector2(844.0, 390.0)
	add_child_autofree(menu)
	menu.bind(_options, _progression, _goals, _scores, _settings)
	menu.show_menu()
	return menu


func test_menu_exposes_its_controls() -> void:
	var menu: TiltMenu = _menu()
	for node_name: String in [
		"MenuTitle",
		"PlayButton",
		"MenuArmoryButton",
		"MenuMilestonesButton",
		"MenuSettingsButton",
		"MenuCalibrateButton",
		"ModeCard_classic",
		"ModeCard_gauntlet",
		"ModeCard_code-red",
	]:
		assert_not_null(menu.find_child(node_name, true, false), node_name)
	var title: Label = menu.find_child("MenuTitle", true, false) as Label
	assert_eq(title.text, "PERIL\nPOINT", "R6")


func test_mode_cards_show_ts_names_taglines_and_multipliers() -> void:
	var menu: TiltMenu = _menu()
	var card: Control = menu.find_child("ModeCard_code-red", true, false) as Control
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in card.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_has(texts, "Code Red", "GameOptions.ts:62")
	assert_has(texts, "Double density from the first second.", "GameOptions.ts:64")
	assert_does_not_have(texts, "1.5×", "UI R8: no multiplier on the cards (TiltMenu.ts:151)")


func test_picking_a_card_saves_the_mode_and_rerenders() -> void:
	var menu: TiltMenu = _menu()
	(menu.find_child("ModeCard_gauntlet", true, false) as Button).pressed.emit()
	assert_eq(_options.settings.mode, Types.GameMode.GAUNTLET, "TiltMenu.ts:222")
	assert_eq(GameOptionsManager.new().settings.mode, Types.GameMode.GAUNTLET, "saved")
	assert_true(menu.is_mode_selected(Types.GameMode.GAUNTLET), "re-rendered (:223)")


func test_play_hides_the_menu_and_requests_the_saved_mode() -> void:
	_options.set_mode(Types.GameMode.CODE_RED)
	var menu: TiltMenu = _menu()
	watch_signals(menu)
	(menu.find_child("PlayButton", true, false) as Button).pressed.emit()
	assert_false(menu.is_menu_visible(), "TiltMenu.ts:239")
	assert_signal_emitted_with_parameters(menu, "launch_requested", [Types.GameMode.CODE_RED])


func test_nav_buttons_emit_their_requests() -> void:
	var menu: TiltMenu = _menu()
	watch_signals(menu)
	(menu.find_child("MenuArmoryButton", true, false) as Button).pressed.emit()
	(menu.find_child("MenuMilestonesButton", true, false) as Button).pressed.emit()
	(menu.find_child("MenuCalibrateButton", true, false) as Button).pressed.emit()
	assert_signal_emitted(menu, "armory_requested", "TiltMenu.ts:244-246")
	assert_signal_emitted(menu, "all_goals_requested", "TiltMenu.ts:248-250")
	assert_signal_emitted(menu, "calibrate_screen_requested", "R5")


func test_stats_row_shows_the_balance_from_the_first_launch() -> void:
	var menu: TiltMenu = _menu()
	var row: Control = menu.find_child("StatsRow", true, false) as Control
	assert_true(row.is_visible_in_tree(), "UI R1: shown with no best yet (the TS hid it, :180)")
	assert_eq((menu.find_child("StatBest", true, false) as Label).text, "0")
	_scores.stats.best_score = 32420
	_progression.data.points = 7331
	menu.render()
	row = menu.find_child("StatsRow", true, false) as Control
	assert_true(row.is_visible_in_tree())
	assert_eq((menu.find_child("StatBest", true, false) as Label).text, "32,420")
	assert_eq((menu.find_child("StatPoints", true, false) as Label).text, "7,331")


func test_next_teaser_shows_the_first_active_goal() -> void:
	var menu: TiltMenu = _menu()
	var teaser: Control = menu.find_child("NextTeaser", true, false) as Control
	assert_not_null(teaser, "a fresh save has active goals (TiltMenu.ts:97)")
	assert_true(teaser.is_visible_in_tree(), "R8")
	# UI R6: on its own card, title and description on separate lines, with the reward.
	assert_not_null(menu.find_child("NextTeaserCard", true, false))
	assert_eq((menu.find_child("NextTeaserTitle", true, false) as Label).text, "Rookie Dodger")
	assert_eq(
		(menu.find_child("NextTeaserText", true, false) as Label).text, "Reach 1,000 score in a run"
	)
	assert_eq((menu.find_child("NextTeaserReward", true, false) as Label).text, "+50 pts")


func test_steer_picker_reports_the_scheme() -> void:
	var menu: TiltMenu = _menu()
	watch_signals(menu)
	var picker: ControlPicker = (
		menu.find_children("*", "ControlPicker", true, false)[0] as ControlPicker
	)
	picker.scheme_chosen.emit(Types.ControlScheme.GYRO)
	assert_signal_emitted_with_parameters(menu, "scheme_chosen", [Types.ControlScheme.GYRO])


func test_every_menu_target_meets_the_48_rule() -> void:
	var menu: TiltMenu = _menu()
	await get_tree().process_frame
	for button: Node in menu.find_children("*", "Button", true, false):
		var b: Button = button as Button
		if b.is_visible_in_tree():
			assert_true(b.size.y >= 48.0, "%s height %f (interface spec §4.5)" % [b.name, b.size.y])


func _settings_open() -> TiltMenu:
	var menu: TiltMenu = _menu()
	(menu.find_child("MenuSettingsButton", true, false) as Button).pressed.emit()
	return menu


func test_settings_button_opens_the_modal_and_back_closes_it() -> void:
	var menu: TiltMenu = _settings_open()
	assert_true(menu.is_options_open(), "TiltMenu.ts:252-254")
	(menu.find_child("OptionsBackButton", true, false) as Button).pressed.emit()
	assert_false(menu.is_options_open(), "TiltMenu.ts:419-421")


func test_halo_and_grid_switches_save_and_announce() -> void:
	var menu: TiltMenu = _settings_open()
	watch_signals(menu)
	(menu.find_child("HaloSwitch", true, false) as CheckButton).toggled.emit(false)
	(menu.find_child("GridSwitch", true, false) as CheckButton).toggled.emit(true)
	var saved: GameOptionsManager = GameOptionsManager.new()
	assert_false(saved.settings.high_contrast_halo, "TiltMenu.ts:429-433")
	assert_true(saved.settings.show_gridlines, "TiltMenu.ts:441-445")
	assert_signal_emit_count(menu, "readability_changed", 2, "R9: applied at once")


func test_usage_switch_saves_and_opts_telemetry_out() -> void:
	var rec: RecordingTelemetryBackend = RecordingTelemetryBackend.new()
	var previous: TelemetryBackend = Telemetry.backend
	Telemetry.backend = rec
	var menu: TiltMenu = _settings_open()
	var usage: CheckButton = menu.find_child("UsageSwitch", true, false) as CheckButton
	assert_true(usage.button_pressed, "DIVERGENCE(MVP R6): sharing is on by default")
	usage.toggled.emit(false)
	assert_false(GameOptionsManager.new().settings.share_usage_data, "saved")
	assert_false(Telemetry.enabled, "applied at once")
	assert_eq(rec.collection_calls, [false] as Array[bool])
	Telemetry.backend = previous
	Telemetry.enabled = true


func test_shake_segments_store_the_ts_ids() -> void:
	var menu: TiltMenu = _settings_open()
	(menu.find_child("ShakeLow", true, false) as Button).pressed.emit()
	assert_eq(GameOptionsManager.new().settings.screen_shake, GameOptionsManager.ScreenShake.LOW)
	(menu.find_child("ShakeFull", true, false) as Button).pressed.emit()
	assert_eq(
		GameOptionsManager.new().settings.screen_shake,
		GameOptionsManager.ScreenShake.FULL,
		"data-shake=full (TiltMenu.ts:345)"
	)


func test_the_default_normal_shake_marks_full() -> void:
	var menu: TiltMenu = _settings_open()
	assert_true(
		(menu.find_child("ShakeFull", true, false) as Button).button_pressed,
		"isCurrentShake: normal counts as full (TiltMenu.ts:280-285)"
	)


func test_audio_switches_announce() -> void:
	var menu: TiltMenu = _settings_open()
	watch_signals(menu)
	(menu.find_child("SfxSwitch", true, false) as CheckButton).toggled.emit(false)
	(menu.find_child("MusicSwitch", true, false) as CheckButton).toggled.emit(false)
	# R9 (Q2 ruling). GUT's 4th argument here is the emit index, not a message.
	assert_signal_emitted_with_parameters(menu, "sfx_toggled", [false])
	assert_signal_emitted_with_parameters(menu, "music_toggled", [false])
	assert_signal_not_emitted(menu, "readability_changed", "audio is not readability")


func test_aim_line_is_omitted() -> void:
	var menu: TiltMenu = _settings_open()
	assert_null(menu.find_child("AimSwitch", true, false), "R3")


func test_calibrate_link_shows_only_for_tilt_and_armory_link_closes() -> void:
	var menu: TiltMenu = _settings_open()
	var calibrate: Control = menu.find_child("SettingsCalibrateButton", true, false) as Control
	assert_false(calibrate != null and calibrate.is_visible_in_tree(), "TiltMenu.ts:378")
	_settings.scheme = Types.ControlScheme.GYRO
	menu.open_options_modal()
	calibrate = menu.find_child("SettingsCalibrateButton", true, false) as Control
	assert_true(calibrate.is_visible_in_tree())
	watch_signals(menu)
	(menu.find_child("ArmoryLink", true, false) as Button).pressed.emit()
	assert_false(menu.is_options_open(), "TiltMenu.ts:501")
	assert_signal_emitted(menu, "armory_requested", "TiltMenu.ts:502")


func test_reset_asks_first_and_cancel_emits_nothing() -> void:
	var menu: TiltMenu = _settings_open()
	watch_signals(menu)
	(menu.find_child("ResetButton", true, false) as Button).pressed.emit()
	var confirm: Control = menu.find_child("ResetConfirm", true, false) as Control
	assert_true(confirm.is_visible_in_tree(), "window.confirm (TiltMenu.ts:507)")
	(menu.find_child("ResetCancelButton", true, false) as Button).pressed.emit()
	assert_false(confirm.is_visible_in_tree())
	assert_signal_not_emitted(menu, "reset_confirmed")
	(menu.find_child("ResetButton", true, false) as Button).pressed.emit()
	(menu.find_child("ResetConfirmButton", true, false) as Button).pressed.emit()
	assert_signal_emitted(menu, "reset_confirmed", "TiltMenu.ts:510")


func test_mode_taglines_are_laid_out_with_height() -> void:
	# M11c review: a general layout guard. The device regression (wrap + clip_text hid
	# every tagline on the emulator) did not reproduce headless at scale 1.0.
	var menu: TiltMenu = _menu()
	await get_tree().process_frame
	await get_tree().process_frame
	for mode: String in ["classic", "gauntlet", "code-red"]:
		var card: Control = menu.find_child("ModeCard_" + mode, true, false) as Control
		var tagline: Label = null
		for label: Node in card.find_children("*", "Label", true, false):
			if (label as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
				tagline = label as Label
		assert_not_null(tagline, mode)
		if tagline != null:
			assert_gt(tagline.size.y, 0.0, mode + " tagline has height")
			assert_gt(tagline.size.x, 0.0, mode + " tagline has width")


func test_next_card_clears_the_tagline_on_phone_screens() -> void:
	# UI R6: the taller NEXT card must not reach the tagline (it touched it at 2424×1080).
	for size: Vector2 in [Vector2(844.0, 390.0), Vector2(2340.0, 1080.0), Vector2(2424.0, 1080.0)]:
		var menu: TiltMenu = TiltMenu.new()
		menu.size = size
		add_child_autofree(menu)
		menu.bind(_options, _progression, _goals, _scores, _settings)
		menu.set_ui_scale(size.y / 390.0, Vector2.ZERO)
		menu.show_menu()
		await get_tree().process_frame
		await get_tree().process_frame
		var tagline: Control = menu.find_child("MenuTagline", true, false) as Control
		var card: Control = menu.find_child("NextTeaserCard", true, false) as Control
		var gap: float = card.get_global_rect().position.y - tagline.get_global_rect().end.y
		assert_gt(gap, 4.0 * size.y / 390.0, "%s: %.0f px between tagline and card" % [size, gap])


func test_steer_taps_keep_the_menu_scale() -> void:
	# UI R7: a re-render (a Touch/Tilt tap) must not change the fitted scale.
	var menu: TiltMenu = TiltMenu.new()
	menu.size = Vector2(2424.0, 1080.0)
	add_child_autofree(menu)
	menu.bind(_options, _progression, _goals, _scores, _settings)
	menu.set_ui_scale(1080.0 / 390.0, Vector2(8.0, 12.0))
	menu.show_menu()
	var fitted: float = menu.fit_factor()
	for i: int in range(6):
		menu.render()
		assert_eq(menu.fit_factor(), fitted, "render %d keeps the scale" % i)


func test_code_red_is_red() -> void:
	# UI R9 (user: "code red should actually be red").
	var red: Color = _options.get_mode_config(Types.GameMode.CODE_RED).color
	assert_gt(red.r, 0.9)
	assert_lt(red.b, 0.5, "red, not the TS's violet")


func test_vibration_switch_saves_and_applies() -> void:
	var menu: TiltMenu = _settings_open()
	var vibration: CheckButton = menu.find_child("VibrationSwitch", true, false) as CheckButton
	assert_true(vibration.button_pressed, "DIVERGENCE(MVP Week 1): on by default")
	vibration.toggled.emit(false)
	assert_false(GameOptionsManager.new().settings.haptics_enabled, "saved")
	assert_false(Haptics.enabled, "applied at once")
	Haptics.enabled = true
