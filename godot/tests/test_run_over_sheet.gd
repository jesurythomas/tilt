# gdlint:disable=max-public-methods
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
	result.mode_name = "Survival"
	result.mode_multiplier = 1.0
	result.best_diff = 4110
	result.earned = 3331
	result.balance = 7331
	return result


func _label(sheet: Node, name: String) -> Label:
	var label: Label = sheet.find_child(name, true, false) as Label
	assert_not_null(label, name)
	return label


func _assert_fits(size: Vector2, scale: float, is_offering_ad: bool = false) -> void:
	var sheet: RunOverSheet = _sheet(size, scale)
	sheet.show_result(_result())
	sheet.set_reward_offer(is_offering_ad, false)
	sheet.finish_count_up()
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
		"MilestonesList",
		"MilestonesClip",
		"ControlPicker",
		"RestartButton",
		"GameOverArmoryButton",
	]:
		assert_not_null(sheet.find_child(name, true, false), name)
	# RUNOVER R1 (user: no previous balance, no coin count).
	for gone: String in [
		"PointsBalanceLabel", "SpendValueLabel", "CoinsRow", "PointsEarnedHint", "UpgradesReadyHint"
	]:
		assert_null(sheet.find_child(gone, true, false), gone)
	var armory: Button = sheet.find_child("GameOverArmoryButton", true, false) as Button
	assert_eq((armory.find_child("NavLabel", true, false) as Label).text, "Armory", "UI R13")
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


func test_layout_fits_the_board_frame_with_the_ad_offer() -> void:
	await _assert_fits(Vector2(844, 390), 1.0, true)  # ADS R6


func test_layout_fits_the_a55_with_the_ad_offer() -> void:
	await _assert_fits(Vector2(2340, 1080), 1080.0 / 390.0, true)  # ADS R6


func test_the_ad_offer_is_hidden_until_offered_and_asks_for_the_ad() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var offer: Button = sheet.find_child("WatchAdButton", true, false) as Button
	assert_false(offer.visible, "hidden until GameRoot offers it")
	sheet.set_reward_offer(true, false)
	assert_true(offer.visible)
	assert_eq(offer.tooltip_text, "Watch ad · 3× points")
	watch_signals(sheet)
	offer.pressed.emit()
	assert_signal_emitted(sheet, "reward_requested")
	sheet.set_reward_offer(true, true)
	assert_true(offer.disabled, "greyed while its ad is on its way")


## ADS R10 (user: "make it more appealing to look at").
func test_the_ad_offer_shows_the_badge_and_what_the_points_would_become() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	sheet.show_result(_result())
	sheet.set_reward_offer(true, false)
	assert_eq(_label(sheet, "RewardBadge").text, "%d×" % GameRoot.AD_REWARD_MULTIPLIER)
	assert_eq(_label(sheet, "RewardLabel").text, "Watch ad")
	assert_eq(_label(sheet, "RewardPayoff").text, "+9,993", "3,331 three times over")
	var offer: Button = sheet.find_child("WatchAdButton", true, false) as Button
	assert_eq(offer.theme_type_variation, "RewardButton")
	for node_name: String in ["RewardContent", "RewardBadge", "RewardLabel", "RewardPayoff"]:
		var node: Control = sheet.find_child(node_name, true, false) as Control
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s leaves the tap" % node_name)


func test_the_light_sweeps_the_offer_only_while_it_can_be_tapped() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	sheet.show_result(_result())
	assert_false(sheet.is_reward_shining(), "not while hidden")
	sheet.set_reward_offer(true, false)
	assert_true(sheet.is_reward_shining())
	sheet.set_reward_offer(true, true)
	assert_false(sheet.is_reward_shining(), "still while its ad opens")
	assert_eq(_label(sheet, "RewardLabel").text, "Opening ad…")
	sheet.set_reward_offer(false, false)
	assert_false(sheet.is_reward_shining())
	var shine: Control = sheet.find_child("RewardShine", true, false) as Control
	assert_lt(shine.position.x + shine.size.x, 0.1, "parked off the left edge")


func test_a_bonus_counts_up_from_the_shown_figure() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	sheet.show_result(_result())
	sheet.finish_count_up()
	sheet.show_bonus(9993)
	assert_eq(_label(sheet, "PointsEarnedLabel").text, "+3,331", "starts from the old figure")
	sheet.finish_count_up()
	assert_eq(_label(sheet, "PointsEarnedLabel").text, "+9,993")


## Found 2026-10-12: 11+ digits widened the sheet and pushed Retry/Menu/Armory off it.
func _assert_big_score_fits(size: Vector2, scale: float) -> void:
	var sheet: RunOverSheet = _sheet(size, scale)
	var result: RunOverSheet.RunResult = _result()
	result.score = 99_999_999_999_999
	sheet.show_result(result)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Control = sheet.find_child("Sheet", true, false) as Control
	assert_almost_eq(panel.size.x, RunOverSheet.SHEET_WIDTH * scale, 0.5, "sheet keeps its width")
	var score: Label = _label(sheet, "FinalScoreLabel")
	assert_eq(score.text, "99,999,999,999,999", "every digit shown")
	var left: Control = sheet.find_child("LeftColumn", true, false) as Control
	assert_true(left.get_global_rect().grow(0.5).encloses(score.get_global_rect()), "in its column")
	var font_px: int = score.get_theme_font_size("font_size")
	var width: float = (
		score
		. get_theme_font("font")
		. get_string_size(score.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
		. x
	)
	assert_lte(width, score.size.x + 0.5, "the digits fit the label")


func test_a_big_score_fits_the_board_frame() -> void:
	await _assert_big_score_fits(Vector2(844, 390), 1.0)


func test_a_big_score_fits_the_a55() -> void:
	await _assert_big_score_fits(Vector2(2340, 1080), 1080.0 / 390.0)


## RUNOVER R2 (Copilot, PR #7): HudController rescales a sheet already showing a score
## (hud_controller.gd set_ui_scale); the digits still fit after the new layout.
func test_a_shown_big_score_fits_after_a_rescale() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var result: RunOverSheet.RunResult = _result()
	result.score = 99_999_999_999_999
	sheet.show_result(result)
	await get_tree().process_frame
	var scale: float = 1080.0 / 390.0
	var host: Control = sheet.get_parent() as Control
	host.size = Vector2(2340, 1080)
	host.theme = UiTheme.build(scale)
	sheet.set_ui_scale(scale)
	await get_tree().process_frame
	await get_tree().process_frame
	var score: Label = _label(sheet, "FinalScoreLabel")
	var font_px: int = score.get_theme_font_size("font_size")
	var width: float = (
		score
		. get_theme_font("font")
		. get_string_size(score.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
		. x
	)
	assert_gt(font_px, 0)
	assert_lte(width, score.size.x + 0.5, "the digits fit the label after the rescale")


func test_a_short_score_keeps_the_board_size() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	sheet.show_result(_result())
	await get_tree().process_frame
	await get_tree().process_frame
	var score: Label = _label(sheet, "FinalScoreLabel")
	assert_eq(score.get_theme_font_size("font_size"), UiTheme.BIG_SCORE_SIZE)


func test_show_result_fills_every_figure() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	sheet.show_result(_result())
	sheet.finish_count_up()
	assert_eq(_label(sheet, "FinalScoreLabel").text, "32,420")
	assert_eq(_label(sheet, "FinalSubtitleLabel").text, "Swarmed at 1:42 — Survival")
	assert_true((sheet.find_child("NewBestBanner", true, false) as Control).visible)
	assert_eq(_label(sheet, "NewBestLabel").text, "New best — up 4,110")
	assert_eq(_label(sheet, "FinalKillsLabel").text, "89")
	assert_eq(_label(sheet, "FinalChainLabel").text, "12×")
	assert_eq(_label(sheet, "FinalTimeLabel").text, "1:42")
	assert_eq(_label(sheet, "PointsEarnedLabel").text, "+3,331")


func test_earned_counts_up_from_zero_and_a_tap_skips() -> void:
	# RUNOVER R1.
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	sheet.show_result(_result())
	assert_eq(_label(sheet, "PointsEarnedLabel").text, "+0", "starts at zero")
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	sheet._gui_input(tap)
	assert_eq(_label(sheet, "PointsEarnedLabel").text, "+3,331", "a tap shows the total")


func test_earned_count_up_lands_on_the_total() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	sheet.show_result(_result())
	await get_tree().create_timer(RunOverSheet.COUNT_UP_SECONDS + 0.2).timeout
	assert_eq(_label(sheet, "PointsEarnedLabel").text, "+3,331")


func test_the_kills_cell_reads_destroyed() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var captions: Array[String] = []
	for label: Node in sheet.find_child("StatGrid", true, false).find_children(
		"*", "Label", true, false
	):
		captions.append((label as Label).text)
	assert_true(captions.has("DESTROYED") or captions.has("Destroyed"), str(captions))


func test_banner_hides_without_a_new_best() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2097-2102
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var result: RunOverSheet.RunResult = _result()
	result.best_diff = 0
	sheet.show_result(result)
	assert_false((sheet.find_child("NewBestBanner", true, false) as Control).visible)


func test_subtitle_text() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2095
	assert_eq(RunOverSheet.subtitle_text("0:07", "Overdrive"), "Swarmed at 0:07 — Overdrive")


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
		"Rookie Dodger",
		":2136 — ACH R3: the title alone"
	)
	assert_eq(
		(row.find_child("MilestonePoints", true, false) as Label).text,
		"+1 pt",
		":2137 + unit (M11c review)"
	)


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
	# ACH R3: the scrolling list opens the screen on a tap's release, not its press.
	var list: Control = sheet.find_child("MilestonesList", true, false) as Control
	list.gui_input.emit(_click())
	assert_signal_emit_count(sheet, "milestones_requested", 1, "a press alone may be a drag")
	var up: InputEventMouseButton = _click()
	up.pressed = false
	list.gui_input.emit(up)
	assert_signal_emit_count(sheet, "milestones_requested", 2)
	var drag_start: InputEventMouseButton = _click()
	list.gui_input.emit(drag_start)
	var drag_end: InputEventMouseButton = _click()
	drag_end.pressed = false
	drag_end.position = drag_start.position + Vector2(0.0, 60.0)
	list.gui_input.emit(drag_end)
	assert_signal_emit_count(sheet, "milestones_requested", 2, "a drag scrolls, it does not tap")
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
	# ACH R3: the list scrolls in its space, so every achievement stays reachable.
	var clip: ScrollContainer = sheet.find_child("MilestonesClip", true, false) as ScrollContainer
	assert_not_null(clip)
	assert_gt(clip.get_v_scroll_bar().max_value, clip.size.y, "7 rows overflow and scroll")
	assert_eq(_label(sheet, "AchievementsHeader").text, "ACHIEVEMENTS · 7")


func test_run_over_has_a_menu_button() -> void:
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var menu: Button = sheet.find_child("GameOverMenuButton", true, false) as Button
	assert_not_null(menu, "TiltGame.ts:1226")
	assert_eq((menu.find_child("NavLabel", true, false) as Label).text, "Menu", "UI R13")
