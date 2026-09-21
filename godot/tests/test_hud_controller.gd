## test_hud_controller.gd
## Verifies HUD signal response and game over display.
extends GutTest


func test_hud_score_changed_updates_labels() -> void:
	var hud: HudController = HudController.new()
	var score_lbl: Label = Label.new()
	score_lbl.name = "ScoreLabel"
	var mult_lbl: Label = Label.new()
	mult_lbl.name = "MultiplierLabel"
	var best_lbl: Label = Label.new()
	best_lbl.name = "BestLabel"

	hud.add_child(score_lbl)
	hud.add_child(mult_lbl)
	hud.add_child(best_lbl)
	add_child_autofree(hud)

	GameEvents.score_changed.emit(1500, 4, 3000)
	assert_eq(score_lbl.text, "1500")
	assert_eq(mult_lbl.text, "4x")
	assert_true(mult_lbl.visible)
	assert_eq(best_lbl.text, "BEST 3000")


func test_hud_run_ended_shows_game_over() -> void:
	var hud: HudController = HudController.new()
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "GameOverPanel"
	var final_score_lbl: Label = Label.new()
	final_score_lbl.name = "FinalScoreLabel"
	var final_kills_lbl: Label = Label.new()
	final_kills_lbl.name = "FinalKillsLabel"
	var final_time_lbl: Label = Label.new()
	final_time_lbl.name = "FinalTimeLabel"

	hud.add_child(panel)
	hud.add_child(final_score_lbl)
	hud.add_child(final_kills_lbl)
	hud.add_child(final_time_lbl)
	add_child_autofree(hud)

	var stats: Types.GameStats = Types.GameStats.new()
	stats.kills = 25
	stats.survival_time = 75.0
	stats.best_score = 5000

	GameEvents.run_ended.emit(4200, stats)
	assert_true(panel.visible, "GameOverPanel must be visible on run_ended")
	assert_eq(final_score_lbl.text, "SCORE: 4200")
	assert_eq(final_kills_lbl.text, "KILLS: 25")
	assert_eq(final_time_lbl.text, "TIME: 1:15")

	GameEvents.phase_changed.emit(Types.GamePhase.PLAYING)
	assert_false(panel.visible, "GameOverPanel hidden on return to playing")


func test_control_picker_emits_the_chosen_scheme() -> void:
	var picker: ControlPicker = ControlPicker.new()
	var tilt_button: Button = Button.new()
	tilt_button.name = "TiltButton"
	var touch_button: Button = Button.new()
	touch_button.name = "TouchButton"
	var keyboard_button: Button = Button.new()
	keyboard_button.name = "KeyboardButton"
	picker.add_child(tilt_button)
	picker.add_child(touch_button)
	picker.add_child(keyboard_button)
	add_child_autofree(picker)

	watch_signals(picker)
	# GUT's fourth argument is the emission index, not a message — index 0 is
	# the first emission, index 1 the second.
	tilt_button.pressed.emit()
	assert_signal_emitted_with_parameters(picker, "scheme_chosen", [Types.ControlScheme.GYRO], 0)

	touch_button.pressed.emit()
	assert_signal_emitted_with_parameters(picker, "scheme_chosen", [Types.ControlScheme.MOUSE], 1)


func test_control_picker_marks_the_active_scheme() -> void:
	var picker: ControlPicker = ControlPicker.new()
	var tilt_button: Button = Button.new()
	tilt_button.name = "TiltButton"
	var touch_button: Button = Button.new()
	touch_button.name = "TouchButton"
	var keyboard_button: Button = Button.new()
	keyboard_button.name = "KeyboardButton"
	picker.add_child(tilt_button)
	picker.add_child(touch_button)
	picker.add_child(keyboard_button)
	add_child_autofree(picker)

	picker.set_active_scheme(Types.ControlScheme.GYRO)
	assert_true(tilt_button.button_pressed, "the active scheme reads as selected")
	assert_false(touch_button.button_pressed, "only one scheme is selected at a time")


func test_ui_scale_grows_the_score_font_on_a_larger_viewport() -> void:
	var hud: HudController = HudController.new()
	var score_lbl: Label = Label.new()
	score_lbl.name = "ScoreLabel"
	hud.add_child(score_lbl)
	add_child_autofree(hud)

	hud.set_ui_scale(1.0)
	var at_one: int = score_lbl.get_theme_font_size("font_size")
	hud.set_ui_scale(2.0)
	var at_two: int = score_lbl.get_theme_font_size("font_size")

	assert_gt(at_two, at_one, "a bigger viewport gets bigger text")


func test_tier_color_for_matches_multiplier_thresholds() -> void:
	assert_eq(HudController.tier_color_for(1), HudController.TIER_WHITE, "1x is white")
	assert_eq(HudController.tier_color_for(2), HudController.TIER_YELLOW, "2x is yellow")
	assert_eq(HudController.tier_color_for(4), HudController.TIER_YELLOW, "4x is yellow")
	assert_eq(HudController.tier_color_for(5), HudController.TIER_ORANGE, "5x is orange")
	assert_eq(HudController.tier_color_for(9), HudController.TIER_ORANGE, "9x is orange")
	assert_eq(HudController.tier_color_for(10), HudController.TIER_MAGENTA, "10x is magenta")
	assert_eq(HudController.tier_color_for(19), HudController.TIER_MAGENTA, "19x is magenta")
	assert_eq(HudController.tier_color_for(20), HudController.TIER_CYAN, "20x is cyan")
	assert_eq(HudController.tier_color_for(50), HudController.TIER_CYAN, "50x is cyan")


func test_multiplier_label_sits_in_its_tier_colour() -> void:
	var hud: HudController = HudController.new()
	var score_lbl: Label = Label.new()
	score_lbl.name = "ScoreLabel"
	var mult_lbl: Label = Label.new()
	mult_lbl.name = "MultiplierLabel"
	hud.add_child(score_lbl)
	hud.add_child(mult_lbl)
	add_child_autofree(hud)

	GameEvents.score_changed.emit(700, 7, 3000)
	assert_eq(mult_lbl.modulate, HudController.TIER_ORANGE, "7x multiplier label is orange")


func test_enemy_killed_pulses_the_score_label_then_settles() -> void:
	var hud: HudController = HudController.new()
	var score_lbl: Label = Label.new()
	score_lbl.name = "ScoreLabel"
	var mult_lbl: Label = Label.new()
	mult_lbl.name = "MultiplierLabel"
	hud.add_child(score_lbl)
	hud.add_child(mult_lbl)
	add_child_autofree(hud)

	GameEvents.score_changed.emit(700, 7, 3000)
	GameEvents.enemy_killed.emit(Types.Enemy.new(), Types.WeaponType.NUKE)

	assert_gt(score_lbl.scale.x, 1.0, "score label scales up on a kill")
	assert_eq(score_lbl.modulate, HudController.TIER_ORANGE, "score label flashes the tier colour")

	await get_tree().create_timer(HudController.PULSE_SECONDS + 0.05).timeout

	assert_almost_eq(score_lbl.scale.x, 1.0, 0.001, "score label settles back to scale 1")
	assert_eq(score_lbl.modulate, HudController.TIER_WHITE, "score label settles back to white")


func test_control_picker_ui_scale_grows_the_touch_targets() -> void:
	var picker: ControlPicker = ControlPicker.new()
	var tilt_button: Button = Button.new()
	tilt_button.name = "TiltButton"
	var touch_button: Button = Button.new()
	touch_button.name = "TouchButton"
	var keyboard_button: Button = Button.new()
	keyboard_button.name = "KeyboardButton"
	picker.add_child(tilt_button)
	picker.add_child(touch_button)
	picker.add_child(keyboard_button)
	add_child_autofree(picker)

	picker.set_ui_scale(1.5)
	assert_almost_eq(tilt_button.custom_minimum_size.y, 72.0, 0.001)
	assert_almost_eq(touch_button.custom_minimum_size.y, 72.0, 0.001)
	assert_almost_eq(keyboard_button.custom_minimum_size.y, 72.0, 0.001)
