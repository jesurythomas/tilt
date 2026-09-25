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
		"MilestonesClip",
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
		"hidden until a result lists milestones"
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


func _goal(id: String, title: String, description: String, reward: int) -> GoalManager.Goal:
	var goal: GoalManager.Goal = GoalManager.Goal.new()
	goal.id = id
	goal.title = title
	goal.description = description
	goal.reward_points = reward
	return goal


func _click() -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func test_milestones_list_shows_each_earned_goal() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2132-2140
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var result: RunOverSheet.RunResult = _result()
	result.milestones = (
		[
			_goal("score_1k", "Rookie Dodger", "Reach 1,000 score in a run", 1),
			_goal("kills_15", "First Blood", "Destroy 15 red dots in a run", 1),
		]
		as Array[GoalManager.Goal]
	)
	sheet.show_result(result)
	var list: VBoxContainer = sheet.find_child("MilestonesList", true, false) as VBoxContainer
	assert_true(list.visible)
	assert_eq(list.get_child_count(), 2)
	var row: Node = list.get_child(0)
	assert_eq(String(row.name), "MilestoneRow_score_1k")
	assert_eq(
		(row.find_child("MilestoneText", true, false) as Label).text,
		"Rookie Dodger — Reach 1,000 score in a run",
		":2136"
	)
	assert_eq((row.find_child("MilestonePoints", true, false) as Label).text, "+1", ":2137")


func test_milestones_list_hides_when_none_were_earned() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2141-2143
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var result: RunOverSheet.RunResult = _result()
	result.milestones = [_goal("score_1k", "Rookie Dodger", "x", 1)] as Array[GoalManager.Goal]
	sheet.show_result(result)
	sheet.show_result(_result())
	var list: VBoxContainer = sheet.find_child("MilestonesList", true, false) as VBoxContainer
	assert_false(list.visible)
	assert_eq(list.get_child_count(), 0, "innerHTML = '' (:2142)")


func test_tapping_the_points_row_or_the_list_requests_the_screen() -> void:
	# PORT: web/src/tilt-to-live/GoalsHUD.ts:129-135 (M9 plan R1)
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	watch_signals(sheet)
	(sheet.find_child("PointsRow", true, false) as Control).gui_input.emit(_click())
	assert_signal_emit_count(sheet, "milestones_requested", 1)
	(sheet.find_child("MilestonesList", true, false) as Control).gui_input.emit(_click())
	assert_signal_emit_count(sheet, "milestones_requested", 2)
	var release: InputEventMouseButton = _click()
	release.pressed = false
	(sheet.find_child("PointsRow", true, false) as Control).gui_input.emit(release)
	assert_signal_emit_count(sheet, "milestones_requested", 2, "a release is not a second tap")


func test_many_milestones_keep_the_sheet_on_screen() -> void:
	# M9 plan R9: the list takes the column's free space and clips.
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var result: RunOverSheet.RunResult = _result()
	var many: Array[GoalManager.Goal] = []
	for i: int in range(7):
		many.append(_goal("g%d" % i, "Milestone %d" % i, "a long description for row %d" % i, 2))
	result.milestones = many
	sheet.show_result(result)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Control = sheet.find_child("Sheet", true, false) as Control
	assert_true(
		sheet.get_global_rect().grow(0.5).encloses(panel.get_global_rect()),
		"the sheet stays inside 844×390"
	)
	var retry: Control = sheet.find_child("RestartButton", true, false) as Control
	# M1: wrapped by hand — gdformat --check would fail an existing file at >100 columns.
	assert_true(
		panel.get_global_rect().grow(0.5).encloses(retry.get_global_rect()), "Retry on the sheet"
	)
	assert_true((sheet.find_child("MilestonesClip", true, false) as Control).clip_contents)


func test_run_over_has_a_menu_button() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var menu: Button = sheet.find_child("GameOverMenuButton", true, false) as Button
	assert_not_null(menu, "TiltGame.ts:1226")
	assert_eq(menu.text, "Menu")


func test_coins_row_shows_only_after_a_pickup() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	sheet.set_coins(0, 0)
	var row: Control = sheet.find_child("CoinsRow", true, false) as Control
	assert_false(row.visible, "TiltGame.ts:2130")
	sheet.set_coins(3, 1)
	assert_true(row.visible, "TiltGame.ts:2128")
	assert_true(sheet.coins_detail_text().ends_with("+1 pt"), "singular (:2127)")
	sheet.set_coins(3, 120)
	assert_eq(sheet.coins_detail_text(), "3 · +120 pts", ":2127")
