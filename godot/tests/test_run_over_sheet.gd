## test_run_over_sheet.gd
## PORTS: nothing — new file, covers src/ui/run_over_sheet.gd (interface spec §6.3)
extends GutTest
## Proves the Run over sheet's board controls, fit, rules 04/05, and that it
## shows what TiltGame.ts:2088-2122 computes.


func _sheet(size: Vector2, scale: float) -> RunOverSheet:
	var host: Control = Control.new()
	host.size = size
	host.theme = UiTheme.build(scale)
	add_child_autofree(host)
	var sheet: RunOverSheet = RunOverSheet.new()
	host.add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.set_ui_scale(scale)
	sheet.visible = true
	return sheet


func _result() -> RunOverSheet.RunResult:
	var result: RunOverSheet.RunResult = RunOverSheet.RunResult.new()
	result.score = 32420
	result.kills = 89
	result.best_chain = 12
	result.time_text = "1:42"
	result.mode_name = "Standard"
	result.mode_multiplier = 1.0
	result.best_diff = 4110
	result.earned = 3331
	result.balance = 7331
	return result


func _label(sheet: Node, name: String) -> Label:
	var label: Label = sheet.find_child(name, true, false) as Label
	assert_not_null(label, name)
	return label


func _assert_fits(size: Vector2, scale: float) -> void:
	var sheet: RunOverSheet = _sheet(size, scale)
	sheet.show_result(_result())
	await get_tree().process_frame
	await get_tree().process_frame
	var outside: Array[String] = UiChecks.outside(sheet, sheet.get_global_rect())
	assert_true(outside.is_empty(), "fits %s: %s" % [size, outside])
	var short: Array[String] = UiChecks.short_buttons(sheet, UiTheme.TOUCH_TARGET * scale)
	assert_true(short.is_empty(), "rule 05 at %s: %s" % [size, short])
	var retry: Button = sheet.find_child("RestartButton", true, false) as Button
	assert_gte(retry.size.y, UiTheme.HERO_TARGET * scale - 0.5, "Retry is a hero action")
	var panel: Control = sheet.find_child("Sheet", true, false) as Control
	assert_gte(
		retry.get_global_rect().position.x,
		panel.get_global_rect().get_center().x,
		"rule 04: the primary action sits in the right half"
	)
	for column: String in ["LeftColumn", "RightColumn"]:
		var box: Node = sheet.find_child(column, true, false)
		assert_true(UiChecks.overlapping_siblings(box).is_empty(), column)


func test_sheet_carries_the_board_controls() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	for name: String in [
		"FinalScoreLabel",
		"FinalSubtitleLabel",
		"NewBestBanner",
		"FinalKillsLabel",
		"FinalChainLabel",
		"FinalTimeLabel",
		"PointsEarnedLabel",
		"PointsBalanceLabel",
		"MilestonesList",
		"ControlPicker",
		"RestartButton",
		"GameOverArmoryButton",
		"SpendValueLabel",
	]:
		assert_not_null(sheet.find_child(name, true, false), name)
	assert_null(sheet.find_child("MenuButton", true, false), "Menu is M11's (spec §5)")
	assert_null(sheet.find_child("FinalCoinsLabel", true, false), "coins cell dropped (spec §6.3)")
	assert_false(
		(sheet.find_child("MilestonesList", true, false) as Control).visible,
		"hidden until M9 fills it"
	)


func test_layout_fits_the_board_frame() -> void:
	await _assert_fits(Vector2(844, 390), 1.0)


func test_layout_fits_the_a55() -> void:
	await _assert_fits(Vector2(2340, 1080), 1080.0 / 390.0)


func test_show_result_fills_every_figure() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	sheet.show_result(_result())
	assert_eq(_label(sheet, "FinalScoreLabel").text, "32,420")
	assert_eq(_label(sheet, "FinalSubtitleLabel").text, "Swarmed at 1:42 — Standard, 1.0×")
	assert_true((sheet.find_child("NewBestBanner", true, false) as Control).visible)
	assert_eq(_label(sheet, "NewBestLabel").text, "New best — up 4,110")
	assert_eq(_label(sheet, "FinalKillsLabel").text, "89")
	assert_eq(_label(sheet, "FinalChainLabel").text, "12×")
	assert_eq(_label(sheet, "FinalTimeLabel").text, "1:42")
	assert_eq(_label(sheet, "PointsEarnedLabel").text, "+3,331")
	assert_eq(_label(sheet, "PointsBalanceLabel").text, "7,331")
	assert_eq(_label(sheet, "SpendValueLabel").text, "7,331")


func test_banner_hides_without_a_new_best() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2097-2102
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var result: RunOverSheet.RunResult = _result()
	result.best_diff = 0
	sheet.show_result(result)
	assert_false((sheet.find_child("NewBestBanner", true, false) as Control).visible)


func test_subtitle_text() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2095
	assert_eq(
		RunOverSheet.subtitle_text("0:07", "Code Red", 1.5), "Swarmed at 0:07 — Code Red, 1.5×"
	)
