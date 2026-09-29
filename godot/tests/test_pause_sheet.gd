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
		"QuitToMenuButton",
		"ControlPicker",
		"CalibrateButton",
		"SoundSwitch",
		"MusicSwitch",
		"PauseArmoryButton",
		"PauseSettingsButton",
	]:
		assert_not_null(sheet.find_child(name, true, false), name)
	var sheet_panel: PanelContainer = sheet.find_child("Sheet", true, false) as PanelContainer
	assert_eq(sheet_panel.theme_type_variation, &"Sheet")


func test_layout_fits_the_board_frame() -> void:
	await _assert_fits(Vector2(844, 390), 1.0)


func test_layout_fits_the_a55() -> void:
	await _assert_fits(Vector2(2340, 1080), 1080.0 / 390.0)


func test_stats_line() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:1624-1625; mode name per spec §6.2
	assert_eq(PauseSheet.stats_text(18940, "1:04", "Survival"), "Score 18,940 · 1:04 · Survival")


func test_switches_mirror_without_emitting() -> void:
	var sheet: PauseSheet = _sheet(Vector2(844, 390), 1.0)
	var sound: CheckButton = sheet.find_child("SoundSwitch", true, false) as CheckButton
	watch_signals(sound)
	sheet.set_switches(false, true)
	assert_false(sound.button_pressed)
	assert_true((sheet.find_child("MusicSwitch", true, false) as CheckButton).button_pressed)
	assert_signal_not_emitted(sound, "toggled", "opening the sheet must not write settings")


func test_pause_has_quit_to_menu_and_settings_and_no_mode_picker() -> void:
	var sheet: PauseSheet = _sheet(Vector2(844, 390), 1.0)
	assert_not_null(sheet.find_child("QuitToMenuButton", true, false), "TiltGame.ts:1153")
	assert_not_null(sheet.find_child("PauseSettingsButton", true, false), "Pause.dc.html")
	assert_null(sheet.find_child("ModePicker", true, false), "M10 R1 removed with the menu")


## UI R13 (user: "there are inconsistencies with the buttons. e.g. menu achivements has the
## icons, game over achivements do not have it"): the menu, Pause and Run over share one
## nav button — the NavButton face with a glyph beside its label.
func test_every_nav_button_carries_its_glyph() -> void:
	var pause: PauseSheet = PauseSheet.new()
	add_child_autofree(pause)
	pause.set_ui_scale(1.0)
	var over: RunOverSheet = RunOverSheet.new()
	add_child_autofree(over)
	over.set_ui_scale(1.0)
	var hosts: Dictionary[String, Node] = {
		"RestartRunButton": pause,
		"QuitToMenuButton": pause,
		"PauseArmoryButton": pause,
		"PauseSettingsButton": pause,
		"GameOverMenuButton": over,
		"GameOverArmoryButton": over,
	}
	for button_name: String in hosts:
		var host: Node = hosts[button_name]
		var button: Button = host.find_child(button_name, true, false) as Button
		assert_eq(button.theme_type_variation, "NavButton", button_name)
		var icon: TextureRect = button.find_child("NavIcon", true, false) as TextureRect
		assert_not_null(icon.texture, "%s has its glyph" % button_name)
	assert_not_null((pause.find_child("ResumeButton", true, false) as Button).icon, "Resume ▶")
	assert_not_null((over.find_child("RestartButton", true, false) as Button).icon, "Retry ↻")
	var trophy: TextureRect = over.find_child("AchievementsTrophy", true, false) as TextureRect
	assert_not_null(trophy.texture, "the Run over's achievements header has the trophy")
