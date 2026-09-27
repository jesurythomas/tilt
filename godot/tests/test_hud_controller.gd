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
	# M11c review: past the previous best the label says so.
	GameEvents.score_changed.emit(3500, 4, 3000)
	assert_eq(best_lbl.text, "NEW BEST")
	GameEvents.score_changed.emit(100, 1, 0)
	assert_eq(best_lbl.text, "BEST 0", "no best yet: nothing to beat")


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


## Builds a HUD with main.tscn's in-run nodes (Frame, ScoreBlock, LeftColumn/LivesRow,
## LeftColumn/ToastSlot, PauseButton, WeaponTimer), unbound from any run.
func _make_hud() -> HudController:
	var hud: HudController = HudController.new()
	var frame: Panel = Panel.new()
	frame.name = "Frame"
	hud.add_child(frame)
	var score_block: VBoxContainer = VBoxContainer.new()
	score_block.name = "ScoreBlock"
	frame.add_child(score_block)
	var left: VBoxContainer = VBoxContainer.new()
	left.name = "LeftColumn"
	frame.add_child(left)
	var lives: HBoxContainer = HBoxContainer.new()
	lives.name = "LivesRow"
	left.add_child(lives)
	var toast: VBoxContainer = VBoxContainer.new()
	toast.name = "ToastSlot"
	left.add_child(toast)
	var pause: Button = Button.new()
	pause.name = "PauseButton"
	frame.add_child(pause)
	var timer: VBoxContainer = VBoxContainer.new()
	timer.name = "WeaponTimer"
	frame.add_child(timer)
	add_child_autofree(hud)
	return hud


func test_menu_phase_hides_the_run_hud_but_keeps_the_frame_and_toasts() -> void:
	var hud: HudController = _make_hud()
	GameEvents.phase_changed.emit(Types.GamePhase.MENU)
	for node_name: String in ["ScoreBlock", "LivesRow", "PauseButton", "WeaponTimer"]:
		assert_false((hud.find_child(node_name, true, false) as Control).visible, node_name)
	assert_true((hud.find_child("Frame", true, false) as Control).visible, "R12")
	assert_true((hud.find_child("ToastSlot", true, false) as Control).visible, "R12")
	GameEvents.phase_changed.emit(Types.GamePhase.PLAYING)
	assert_true((hud.find_child("ScoreBlock", true, false) as Control).visible)
	assert_true((hud.find_child("PauseButton", true, false) as Control).visible)


func _hud_with_multiplier() -> Array:
	var hud: HudController = HudController.new()
	var mult_lbl: Label = Label.new()
	mult_lbl.name = "MultiplierLabel"
	hud.add_child(mult_lbl)
	add_child_autofree(hud)
	return [hud, mult_lbl]


func test_same_tier_multiplier_keeps_the_chip_style() -> void:
	# DIVERGENCE(M11c P6): the chip restyles only when its tier colour changes.
	var mult_lbl: Label = _hud_with_multiplier()[1]
	GameEvents.score_changed.emit(10, 2, 0)
	var style: StyleBox = mult_lbl.get_theme_stylebox("normal")
	GameEvents.score_changed.emit(20, 3, 0)
	assert_same(mult_lbl.get_theme_stylebox("normal"), style, "2× → 3× is the same tier")
	assert_eq(mult_lbl.text, "3×")


func test_tier_change_restyles_the_chip() -> void:
	var mult_lbl: Label = _hud_with_multiplier()[1]
	GameEvents.score_changed.emit(10, 4, 0)
	var style: StyleBox = mult_lbl.get_theme_stylebox("normal")
	GameEvents.score_changed.emit(20, 5, 0)
	assert_ne(mult_lbl.get_theme_stylebox("normal"), style, "4× → 5× crosses a tier")
	assert_eq(
		mult_lbl.get_theme_color("font_color"), HudController.tier_color_for(5), "new tier text"
	)


func test_dropping_to_one_hides_the_chip_and_rising_again_restyles_it() -> void:
	var mult_lbl: Label = _hud_with_multiplier()[1]
	GameEvents.score_changed.emit(10, 20, 0)
	GameEvents.score_changed.emit(10, 1, 0)
	assert_false(mult_lbl.visible, "hidden at 1×")
	GameEvents.score_changed.emit(10, 20, 0)
	assert_true(mult_lbl.visible)
	assert_eq(mult_lbl.get_theme_color("font_color"), HudController.tier_color_for(20))


func test_a_mass_kill_builds_one_pulse_per_frame_unless_the_tier_changes() -> void:
	# M11c review (power-up FPS): 150 kills in one tick restarted the tween 150 times.
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
	var first: Tween = hud._score_pulse_tween
	for i: int in range(20):
		GameEvents.enemy_killed.emit(Types.Enemy.new(), Types.WeaponType.NUKE)
	assert_same(hud._score_pulse_tween, first, "same frame, same tier: one pulse")
	GameEvents.score_changed.emit(2000, 20, 3000)
	GameEvents.enemy_killed.emit(Types.Enemy.new(), Types.WeaponType.NUKE)
	assert_ne(hud._score_pulse_tween, first, "a tier change in the frame restarts it")
	assert_eq(score_lbl.modulate, HudController.tier_color_for(20), "the last tier wins")
	await get_tree().process_frame
	var before: Tween = hud._score_pulse_tween
	GameEvents.enemy_killed.emit(Types.Enemy.new(), Types.WeaponType.NUKE)
	assert_ne(hud._score_pulse_tween, before, "the next frame pulses again")
