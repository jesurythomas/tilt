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
	assert_eq(_pm.data.points, 7331, "no callback installed yet — see PORT-NOTE on bind()")
	assert_false(
		(_node("GoalToast") as Control).visible, "no callback installed yet — see PORT-NOTE"
	)
	assert_eq(_gm.cumulative.total_points_earned, 2, "the goal itself still records the reward")


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
	assert_eq((_node("ToastReward") as Label).text, "+1")
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


func test_menu_mode_hides_the_rail() -> void:
	_hud.bind(_gm, _pm)
	var rail: Control = _node("EdgeRail") as Control
	_hud.set_menu_mode(true)
	assert_false(rail.visible, ":166-175")
	assert_true(_hud.in_menu_mode)
	_hud.set_menu_mode(false)
	assert_true(rail.visible)


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
