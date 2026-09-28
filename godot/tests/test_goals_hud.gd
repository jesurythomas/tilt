# gdlint:disable=max-public-methods
## test_goals_hud.gd
## PORTS: nothing — new file, covers src/ui/goals_hud.gd (interface spec §6.5)
extends GutTest
## Proves the rail, the toast, the unlock check on bind, the menu-mode toggle,
## the M/Escape keys and (Task 6) the Milestones screen.

var _hud: GoalsHUD = null
var _gm: GoalManager = null
var _pm: ProgressionManager = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _remove_saves() -> void:
	for path: String in [
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
		ProgressionManager.SAVE_PATH,
	]:
		_remove(path)
		_remove(SaveStore.corrupt_path_for(path))


func _key(code: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func _node(name: String) -> Node:
	var node: Node = _hud.find_child(name, true, false)
	assert_not_null(node, name)
	return node


func before_each() -> void:
	_remove_saves()
	_gm = GoalManager.new()
	_pm = ProgressionManager.new()
	_hud = GoalsHUD.new()
	add_child_autofree(_hud)


func after_each() -> void:
	_remove_saves()


func test_bind_wires_progression_and_completes_owned_unlocks() -> void:
	_pm.data.unlocked_cursors.append("solar")
	_hud.bind(_gm, _pm)
	assert_true(_gm.is_completed("unlock_ship_solar"), "GoalsHUD.ts:28, :36")
	# B3: bind() runs _init_dom(), which ends in render() and calls
	# check_unlock_goals() BEFORE _setup_listeners() installs the callbacks
	# (GoalsHUD.ts:30-31, :105) — the TS order. A pre-owned unlock completes
	# with no addPoints and no toast; only cumulative.totalPointsEarned moves.
	assert_eq(
		_pm.data.points,
		ProgressionManager.STARTING_POINTS,
		"no callback installed yet — see PORT-NOTE on bind()"
	)
	assert_false(
		(_node("GoalToast") as Control).visible, "no callback installed yet — see PORT-NOTE"
	)
	assert_eq(_gm.cumulative.total_points_earned, 100, "the goal itself still records the reward")


func test_render_fills_the_rail_by_completion() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k", "kills_15"] as Array[String])
	_gm = GoalManager.new()
	_hud.bind(_gm, _pm)
	var fill: Control = _node("EdgeRailFill") as Control
	assert_almost_eq(
		fill.anchor_right, 2.0 / 57.0, 0.0001, "frame width × done ÷ total (spec §6.5)"
	)


func test_rail_is_a_line_on_its_hosts_top_edge() -> void:
	var frame: Control = Control.new()
	add_child_autofree(frame)
	_hud.bind(_gm, _pm, frame)
	_hud.set_ui_scale(2.0)
	# B4: the rail hosts under `frame`, not `_hud` — look it up there directly.
	var rail: Control = frame.find_child("EdgeRail", true, false) as Control
	assert_not_null(rail, "EdgeRail")
	assert_eq(rail.get_parent(), frame, "on the arena frame (R8)")
	assert_eq(rail.anchor_left, 0.0, "from the frame's left corner")
	assert_eq(rail.anchor_right, 1.0)
	assert_eq(rail.offset_top, -2.0, "Hud.dc.html: top 11 over the frame's 12, × 2")
	assert_eq(rail.offset_bottom - rail.offset_top, 6.0, "3 px × 2")
	assert_eq(rail.mouse_filter, Control.MOUSE_FILTER_IGNORE, "not tappable (spec §6.5, R11)")
	var fill: ColorRect = frame.find_child("EdgeRailFill", true, false) as ColorRect
	assert_not_null(fill, "EdgeRailFill")
	assert_eq(fill.color, UiTheme.COLOR_ION)


func test_goal_toast_shows_title_reward_and_restarts_its_timer() -> void:
	_hud.bind(_gm, _pm)
	_hud.show_goal_toast(_gm.catalog[0])
	assert_true((_node("GoalToast") as Control).visible)
	assert_eq((_node("ToastTitle") as Label).text, "Rookie Dodger")
	assert_eq((_node("ToastReward") as Label).text, "+50 pts")
	var timer: Timer = _node("ToastTimer") as Timer
	assert_almost_eq(timer.wait_time, 3.0, 0.001, "GoalsHUD.ts:209")
	assert_false(timer.is_stopped())
	timer.timeout.emit()
	assert_false((_node("GoalToast") as Control).visible, ":207")


func test_a_second_toast_replaces_the_first() -> void:
	_hud.bind(_gm, _pm)
	_hud.show_goal_toast(_gm.catalog[0])
	var timer: Timer = _node("ToastTimer") as Timer
	# PLAN DEFECT: Timer.time_left has no setter in Godot 4.7.2 (getter only,
	# ClassDB confirms no set_time_left) — the brief's `timer.time_left = 0.4`
	# fails to parse ("Cannot assign a new value to a read-only property").
	# timer.start(0.4) drives the timer into the same "partway through"
	# state the test needs, preserving its intent.
	timer.start(0.4)
	_hud.show_goal_toast(_gm.catalog[1])
	var toast: Control = _node("GoalToast") as Control
	assert_eq(toast.get_child_count(), 1, "innerHTML is rewritten, not appended (:192)")
	assert_eq((_node("ToastTitle") as Label).text, _gm.catalog[1].title)
	# M9: Review Focus 5 — the second toast restarts the timer, it does not stack.
	assert_almost_eq(timer.time_left, 3.0, 0.001, "restarted, not left counting down")


func test_message_toast_carries_subtitle_and_badge() -> void:
	_hud.bind(_gm, _pm)
	_hud.show_message_toast("TILT CALIBRATED", "Neutral Angle Zeroed ✓", "OK")
	assert_eq((_node("ToastTitle") as Label).text, "TILT CALIBRATED")
	assert_eq((_node("ToastSubtitle") as Label).text, "Neutral Angle Zeroed ✓")
	assert_eq((_node("ToastReward") as Label).text, "OK")
	assert_almost_eq((_node("ToastTimer") as Timer).wait_time, 2.8, 0.001, ":234")


func test_toast_goes_into_its_host_at_content_width() -> void:
	var slot: VBoxContainer = VBoxContainer.new()
	add_child_autofree(slot)
	_hud.bind(_gm, _pm, null, slot)
	# B4: the toast hosts under `slot`, not `_hud` — look it up there directly.
	var toast: Control = slot.find_child("GoalToast", true, false) as Control
	assert_not_null(toast, "GoalToast")
	assert_eq(toast.get_parent(), slot, "under the lives icons (spec §6.5, R8)")
	assert_eq(toast.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN)


func test_rail_stays_hidden_in_menu_and_in_play() -> void:
	# DIVERGENCE(M11c review): user ruling — the rail read as a stuck bar in play.
	_hud.bind(_gm, _pm)
	var rail: Control = _node("EdgeRail") as Control
	assert_false(rail.visible, "hidden from the start")
	_hud.set_menu_mode(true)
	assert_false(rail.visible, ":166-175")
	assert_true(_hud.in_menu_mode)
	_hud.set_menu_mode(false)
	assert_false(rail.visible, "hidden in play too")


func test_m_toggles_and_escape_closes_the_modal() -> void:
	_hud.bind(_gm, _pm)
	_hud._unhandled_input(_key(KEY_M))
	assert_true(_hud.is_modal_open(), ":146-155")
	_hud._unhandled_input(_key(KEY_M))
	assert_false(_hud.is_modal_open())
	_hud._unhandled_input(_key(KEY_M))
	_hud._unhandled_input(_key(KEY_ESCAPE))
	assert_false(_hud.is_modal_open(), ":156-158")


func test_rail_and_toast_never_eat_touches() -> void:
	_hud.bind(_gm, _pm)
	assert_eq(_hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_node("GoalToast") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_node("EdgeRailFill") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func _open() -> Control:
	_hud.bind(_gm, _pm)
	_hud.open_all_goals_modal()
	await get_tree().process_frame
	return _hud.find_child("MilestonesModal", true, false) as Control


func _text(name: String) -> String:
	return (_node(name) as Label).text


func _card(id: String) -> Control:
	return _hud.find_child("MilestoneCard_" + id, true, false) as Control


## A GoalsHUD in an explicit-size host (the headless root snaps to 64×64 — M8.5 lesson).
func _hosted(size: Vector2, scale: float) -> GoalsHUD:
	var host: Control = Control.new()
	host.size = size
	add_child_autofree(host)
	var hud: GoalsHUD = GoalsHUD.new()
	host.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.bind(_gm, _pm)
	hud.set_ui_scale(scale)
	hud.open_all_goals_modal()
	return hud


func _assert_screen_fits(size: Vector2, scale: float) -> void:
	var hud: GoalsHUD = _hosted(size, scale)
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: Control = hud.find_child("MilestonesModal", true, false) as Control
	var outside: Array[String] = UiChecks.outside(screen, screen.get_global_rect())
	assert_true(outside.is_empty(), "fits %s: %s" % [size, outside])
	var short: Array[String] = UiChecks.short_buttons(screen, UiTheme.TOUCH_TARGET * scale)
	assert_true(short.is_empty(), "rule 05 at %s: %s" % [size, short])
	var header: Node = hud.find_child("Header", true, false)
	assert_true(UiChecks.overlapping_siblings(header).is_empty(), "header at %s" % size)
	for tier: String in ["Score", "Combat", "Mastery"]:
		var column: Control = hud.find_child("Tier_" + tier, true, false) as Control
		assert_gt(column.size.x, 0.0, "%s column has width at %s" % [tier, size])


func test_header_shows_counter_progress_and_points() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	assert_eq(_text("TitleLabel"), "Milestones")
	assert_eq(_text("CounterLabel"), "1", "GoalsHUD.ts:367")
	assert_eq(_text("CounterDenomLabel"), "/57")
	assert_eq(_text("HeaderPointsLabel"), "500", ":372 toLocaleString (ECON R3 start)")
	assert_eq(_text("HeaderPointsUnit"), "PTS", "Milestones.dc.html caps unit")
	var fill: Control = _node("ProgressFill") as Control
	assert_almost_eq(fill.anchor_right, 0.02, 0.0001, "round(1/57*100) = 2 (:317)")


func test_three_tier_columns_with_their_counts() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["kills_15"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	var names: Array[String] = []
	var counts: Array[String] = []
	for tier: String in ["Score", "Combat", "Mastery"]:
		var group: Control = _hud.find_child("Tier_" + tier, true, false) as Control
		assert_not_null(group, tier)
		var tier_name: Label = group.find_child("TierName", true, false) as Label
		assert_true(tier_name.uppercase, "caps label")
		names.append(tier_name.text)
		counts.append((group.find_child("TierCount", true, false) as Label).text)
	assert_eq(names, ["Score", "Combat", "Mastery"] as Array[String], ":356-360")
	assert_eq(counts, ["0 of 9", "1 of 17", "0 of 31"] as Array[String], ":384-391")
	var score_name: Label = (
		_hud.find_child("Tier_Score", true, false).find_child("TierName", true, false) as Label
	)
	assert_eq(score_name.get_theme_color("font_color"), UiTheme.COLOR_ION, ":357 tint")


func test_open_goals_come_before_done_goals() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	var cards: Node = _hud.find_child("Tier_Score", true, false).find_child(
		"TierCards", true, false
	)
	var last: Node = cards.get_child(cards.get_child_count() - 1)
	assert_eq(String(last.name), "MilestoneCard_score_1k", "done last (interface spec §6.5)")
	assert_ne(String(cards.get_child(0).name), "MilestoneCard_score_1k")


func test_done_card_shows_description_and_no_bar() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	var card: Control = _card("score_1k")
	assert_eq(
		(card.find_child("GoalLabel", true, false) as Label).text, "Reach 1,000 score in a run"
	)
	assert_null(card.find_child("BarTrack", true, false), ":424-439")
	var box: StyleBoxFlat = (card as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.bg_color, UiTheme.DONE_CARD, "Milestones.dc.html done card")
	var pts: Label = card.find_child("PointsLabel", true, false) as Label
	assert_eq(pts.get_theme_color("font_color"), UiTheme.TEXT_FAINT, "done points are faint")


func test_total_goal_shows_live_progress() -> void:
	_gm.cumulative.total_kills = 40
	await _open()
	var card: Control = _card("total_kills_100")
	assert_eq((card.find_child("GoalLabel", true, false) as Label).text, "40 / 100", ":458-460")
	var fill: Control = card.find_child("BarFill", true, false) as Control
	assert_almost_eq(fill.anchor_right, 0.40, 0.0001, ":420-422")


func test_open_run_goal_shows_description_and_no_bar() -> void:
	await _open()
	var card: Control = _card("score_1k")
	assert_eq(
		(card.find_child("GoalLabel", true, false) as Label).text, "Reach 1,000 score in a run"
	)
	assert_null(card.find_child("BarTrack", true, false), "interface spec §6.5 (R10)")


func test_unlock_card_has_no_bar() -> void:
	await _open()
	assert_null(_card("unlock_ship_solar").find_child("BarTrack", true, false), ":444-455")


func test_back_button_closes_the_screen() -> void:
	var screen: Control = await _open()
	(_node("BackButton") as Button).pressed.emit()
	assert_false(screen.visible, ":484-486")


func test_render_refreshes_an_open_screen() -> void:
	await _open()
	_gm.cumulative.total_kills = 70
	_hud.render()
	var card: Control = _card("total_kills_100")
	assert_eq((card.find_child("GoalLabel", true, false) as Label).text, "70 / 100", ":280-282")


func test_screen_fits_the_board_frame() -> void:
	await _assert_screen_fits(Vector2(844, 390), 1.0)


func test_screen_fits_the_a55() -> void:
	await _assert_screen_fits(Vector2(2340, 1080), 1080.0 / 390.0)


func test_screen_fits_a_desktop_window() -> void:
	await _assert_screen_fits(Vector2(1280, 720), HudController.ui_scale_for(Vector2(1280, 720)))


func test_long_text_stays_on_one_line() -> void:
	var hud: GoalsHUD = _hosted(Vector2(844, 390), 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	for node: Node in hud.find_children("MilestoneCard_*", "PanelContainer", true, false):
		var card: Control = node as Control
		assert_almost_eq(card.size.y, 58.0, 0.5, "%s stays 58 px (one line each)" % card.name)
	var goal: Label = hud.find_child("GoalLabel", true, false) as Label
	assert_eq(goal.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "rule 03")


func test_screen_blocks_taps_but_lets_columns_scroll() -> void:
	var screen: Control = await _open()
	assert_eq(screen.mouse_filter, Control.MOUSE_FILTER_STOP, "nothing under it takes the tap")
	var scroll: Node = _hud.find_child("TierScroll", true, false)
	# B5: ScrollContainer's own internal scrollbars (mouse_filter STOP) are also
	# under `scroll` — walk from its content node (TierSections) down, not from the
	# ScrollContainer itself, so the assertion never inspects them.
	var content: Node = scroll.find_child("TierSections", false, false)
	var nodes: Array[Node] = [content]
	nodes.append_array(content.find_children("*", "Control", true, false))
	for node: Node in nodes:
		var control: Control = node as Control
		assert_ne(control.mouse_filter, Control.MOUSE_FILTER_STOP, "%s must pass drags" % node.name)


func test_one_column_stacks_the_three_tiers_in_order() -> void:
	# DIVERGENCE(M11c P11): user ruling 2026-09-26 — a single column, tiers stacked
	# (Milestones.dc.html drew three side by side).
	await _open()
	await get_tree().process_frame
	var scrolls: Array[Node] = _hud.find_children("TierScroll", "ScrollContainer", true, false)
	assert_eq(scrolls.size(), 1, "one scroll view for every tier")
	var ys: Array[float] = []
	for tier: String in ["Score", "Combat", "Mastery"]:
		var group: Control = _hud.find_child("Tier_" + tier, true, false) as Control
		assert_true(scrolls[0].is_ancestor_of(group), "%s scrolls with the others" % tier)
		ys.append(group.global_position.y)
	assert_lt(ys[0], ys[1], "Score above Combat")
	assert_lt(ys[1], ys[2], "Combat above Mastery")
