## test_pause_sheet.gd
## PORTS: nothing — new file, covers src/ui/pause_sheet.gd (interface spec §6.2)
extends GutTest
## Proves the Pause sheet's board controls, its fit on the board frame and the
## A55, rule 05, and the stats line.


func _sheet(size: Vector2, scale: float) -> PauseSheet:
	var host: Control = Control.new()
	host.size = size
	host.theme = UiTheme.build(scale)
	add_child_autofree(host)
	var sheet: PauseSheet = PauseSheet.new()
	host.add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.set_ui_scale(scale)
	sheet.visible = true
	return sheet


func _assert_fits(size: Vector2, scale: float) -> void:
	var sheet: PauseSheet = _sheet(size, scale)
	await get_tree().process_frame
	await get_tree().process_frame
	var bounds: Rect2 = sheet.get_global_rect()
	var outside: Array[String] = UiChecks.outside(sheet, bounds)
	assert_true(outside.is_empty(), "fits %s: %s" % [size, outside])
	var short: Array[String] = UiChecks.short_buttons(sheet, UiTheme.TOUCH_TARGET * scale)
	assert_true(short.is_empty(), "rule 05 at %s: %s" % [size, short])
	var resume: Button = sheet.find_child("ResumeButton", true, false) as Button
	assert_gte(resume.size.y, UiTheme.HERO_TARGET * scale - 0.5, "Resume is a hero action")
	for column: String in ["LeftColumn", "RightColumn"]:
		var box: Node = sheet.find_child(column, true, false)
		assert_true(UiChecks.overlapping_siblings(box).is_empty(), column)


func test_sheet_carries_the_board_controls() -> void:
	var sheet: PauseSheet = _sheet(Vector2(844, 390), 1.0)
	for name: String in [
		"Scrim",
		"Sheet",
		"PauseStats",
		"ResumeButton",
		"RestartRunButton",
		"ModePicker",
		"ControlPicker",
		"CalibrateButton",
		"SoundSwitch",
		"MusicSwitch",
		"PauseArmoryButton",
	]:
		assert_not_null(sheet.find_child(name, true, false), name)
	assert_null(sheet.find_child("QuitButton", true, false), "Quit to menu is M11's (spec §5)")
	assert_null(sheet.find_child("SettingsButton", true, false), "Settings is M11's (spec §5)")
	var sheet_panel: PanelContainer = sheet.find_child("Sheet", true, false) as PanelContainer
	assert_eq(sheet_panel.theme_type_variation, &"Sheet")


func test_layout_fits_the_board_frame() -> void:
	await _assert_fits(Vector2(844, 390), 1.0)


func test_layout_fits_the_a55() -> void:
	await _assert_fits(Vector2(2340, 1080), 1080.0 / 390.0)


func test_stats_line() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:1624-1625; mode name per spec §6.2
	assert_eq(PauseSheet.stats_text(18940, "1:04", "Standard"), "18,940 · 1:04 · Standard")


func test_switches_mirror_without_emitting() -> void:
	var sheet: PauseSheet = _sheet(Vector2(844, 390), 1.0)
	var sound: CheckButton = sheet.find_child("SoundSwitch", true, false) as CheckButton
	watch_signals(sound)
	sheet.set_switches(false, true)
	assert_false(sound.button_pressed)
	assert_true((sheet.find_child("MusicSwitch", true, false) as CheckButton).button_pressed)
	assert_signal_not_emitted(sound, "toggled", "opening the sheet must not write settings")


func test_mode_picker_marks_the_active_mode_and_emits() -> void:
	var sheet: PauseSheet = _sheet(Vector2(844, 390), 1.0)
	var options: GameOptionsManager = GameOptionsManager.new()
	sheet.set_mode_choices(options.modes, Types.GameMode.GAUNTLET)
	var classic: Button = sheet.find_child("ModeClassicButton", true, false) as Button
	var gauntlet: Button = sheet.find_child("ModeGauntletButton", true, false) as Button
	var code_red: Button = sheet.find_child("ModeCodeRedButton", true, false) as Button
	assert_eq(classic.text, "Standard", "names from the catalog (GameOptions.ts:37-71)")
	assert_eq(code_red.text, "Code Red")
	assert_true(gauntlet.button_pressed)
	assert_false(classic.button_pressed)
	watch_signals(sheet)
	code_red.pressed.emit()
	assert_signal_emitted_with_parameters(sheet, "mode_chosen", [Types.GameMode.CODE_RED])
	assert_true(code_red.button_pressed)
	assert_false(gauntlet.button_pressed)
