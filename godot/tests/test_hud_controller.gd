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
	assert_eq(score_lbl.text, "1,500")
	assert_eq(mult_lbl.text, "4×")
	assert_true(mult_lbl.visible)
	assert_eq(best_lbl.text, "BEST 3,000")


func test_hud_run_ended_shows_the_run_over_sheet() -> void:
	var hud: HudController = HudController.new()
	var sheet: RunOverSheet = RunOverSheet.new()
	sheet.name = "GameOverPanel"
	hud.add_child(sheet)
	add_child_autofree(hud)

	var stats: Types.GameStats = Types.GameStats.new()
	stats.kills = 25
	stats.survival_time = 75.0
	stats.best_score = 5000
	stats.max_multiplier = 12.0

	GameEvents.run_ended.emit(4200, stats)
	# PORT: web/src/tilt-to-live/TiltGame.ts:2089-2151 — the sheet fills 450 ms
	# after the death tick (I-1).
	await get_tree().create_timer(0.5).timeout
	assert_true(sheet.visible, "GameOverPanel must be visible on run_ended")
	assert_eq((sheet.find_child("FinalScoreLabel", true, false) as Label).text, "4,200")
	assert_eq((sheet.find_child("FinalKillsLabel", true, false) as Label).text, "25")
	assert_eq((sheet.find_child("FinalTimeLabel", true, false) as Label).text, "1:15")
	assert_eq((sheet.find_child("FinalChainLabel", true, false) as Label).text, "12×")

	GameEvents.phase_changed.emit(Types.GamePhase.PLAYING)
	assert_false(sheet.visible, "GameOverPanel hidden on return to playing")


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
	assert_eq(
		mult_lbl.get_theme_color("font_color"),
		HudController.TIER_ORANGE,
		"7x multiplier chip text is orange"
	)
	var chip: StyleBoxFlat = mult_lbl.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(
		chip.border_color,
		UiTheme.tint(HudController.TIER_ORANGE, UiTheme.CHIP_BORDER_ALPHA),
		"the Chip border carries the tier at 45% (System.dc.html)"
	)


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


func test_score_label_pivot_stays_centred_as_the_label_resizes() -> void:
	var hud: HudController = HudController.new()
	var score_lbl: Label = Label.new()
	score_lbl.name = "ScoreLabel"
	hud.add_child(score_lbl)
	add_child_autofree(hud)

	await wait_frames(1)

	GameEvents.score_changed.emit(123456789, 1, 0)

	await wait_frames(1)

	assert_eq(
		score_lbl.pivot_offset, score_lbl.size / 2.0, "pivot follows the label's resized size"
	)


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


func test_lives_pips_hide_a_single_life_run() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2176-2185
	assert_true(HudController.lives_pips(1, 1).is_empty(), "one-life runs show no pips")
	var pips: Array[bool] = HudController.lives_pips(2, 3)
	assert_eq(pips.size(), 3, "one icon per starting life")
	assert_true(pips[0] and pips[1], "remaining lives are filled")
	assert_false(pips[2], "the lost life is empty")


func test_weapon_timer_prefers_the_shield() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2188-2194
	var player: PlayerShip = PlayerShip.new(0.0, 0.0)
	player.shield_timer = 3.0
	var laser: Types.ActiveWeapon = Types.ActiveWeapon.new()
	laser.type = Types.WeaponType.LASER
	laser.duration = 5.0
	laser.max_duration = 8.0
	var weapons: Array[Types.ActiveWeapon] = [laser]
	var reading: HudController.WeaponTimer = HudController.weapon_timer_for(player, weapons)
	assert_true(reading.is_shown)
	assert_eq(reading.weapon_type, Types.WeaponType.SHIELD)
	assert_almost_eq(reading.fraction, 0.5, 0.0001, "3.0 of the TS's fixed 6.0 (:2190)")
	assert_eq(HudController.weapon_timer_text(reading), "SHIELD 3.0s")


func test_weapon_timer_picks_the_longest_remaining_timed_weapon() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2195-2210
	var player: PlayerShip = PlayerShip.new(0.0, 0.0)
	player.shield_timer = 0.0
	var vortex: Types.ActiveWeapon = Types.ActiveWeapon.new()
	vortex.type = Types.WeaponType.VORTEX
	vortex.duration = 1.0
	vortex.max_duration = 4.0
	var freeze: Types.ActiveWeapon = Types.ActiveWeapon.new()
	freeze.type = Types.WeaponType.FREEZE
	freeze.duration = 2.0
	freeze.max_duration = 8.0
	var nuke: Types.ActiveWeapon = Types.ActiveWeapon.new()
	nuke.type = Types.WeaponType.NUKE
	var weapons: Array[Types.ActiveWeapon] = [vortex, freeze, nuke]
	var reading: HudController.WeaponTimer = HudController.weapon_timer_for(player, weapons)
	assert_eq(reading.weapon_type, Types.WeaponType.FREEZE)
	assert_almost_eq(reading.fraction, 0.25, 0.0001)
	assert_eq(HudController.weapon_timer_text(reading), "FREEZE 2.0s")


func test_weapon_timer_hidden_without_a_timed_weapon() -> void:
	var player: PlayerShip = PlayerShip.new(0.0, 0.0)
	player.shield_timer = 0.0
	var none: Array[Types.ActiveWeapon] = []
	assert_false(HudController.weapon_timer_for(player, none).is_shown, "TiltGame.ts:2212-2213")
