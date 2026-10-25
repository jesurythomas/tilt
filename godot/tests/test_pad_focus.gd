## test_pad_focus.gd
## PORTS: nothing — new file, covers src/ui/pad_focus.gd (PAD R3)
extends GutTest
## Proves the controller's focus starts on the top screen's first usable control, stays inside
## that screen, is dropped in play, and is ringed only while the controller is in use.

var _focus: PadFocus = null
var _screen: VBoxContainer = null
var _other: VBoxContainer = null
var _root: Control = null


func before_each() -> void:
	_screen = VBoxContainer.new()
	_other = VBoxContainer.new()
	var hidden: Button = Button.new()
	hidden.visible = false
	var disabled: Button = Button.new()
	disabled.disabled = true
	var plain: Label = Label.new()
	var first: Button = Button.new()
	first.name = "First"
	first.custom_minimum_size = Vector2(80, 40)
	var second: Button = Button.new()
	second.name = "Second"
	var primary: Button = Button.new()
	primary.name = "Primary"
	primary.theme_type_variation = PadFocus.PRIMARY_VARIATION
	for node: Control in [hidden, disabled, plain, first, second, primary]:
		_screen.add_child(node)
	var elsewhere: Button = Button.new()
	elsewhere.name = "Elsewhere"
	_other.add_child(elsewhere)
	add_child_autofree(_screen)
	add_child_autofree(_other)
	_root = _screen
	_focus = PadFocus.new()
	_focus.root_provider = func() -> Control: return _root
	add_child_autofree(_focus)


func test_first_focusable_skips_hidden_disabled_and_labels() -> void:
	assert_eq(PadFocus.first_focusable(_screen).name, "First")


func test_inactive_leaves_focus_alone() -> void:
	_focus._process(0.0)
	assert_null(get_viewport().gui_get_focus_owner(), "a touch player gets no focus")
	assert_eq(_focus.ring(), Rect2(), "and no ring")


func test_active_focuses_the_primary_button_and_rings_it() -> void:
	_focus.is_active = true
	_focus._process(0.0)
	assert_eq(get_viewport().gui_get_focus_owner().name, "Primary", "Play / Resume / Retry")
	assert_ne(_focus.ring(), Rect2(), "the ring shows")


func test_focus_outside_the_top_screen_is_pulled_back() -> void:
	_focus.is_active = true
	(_other.get_child(0) as Button).grab_focus()
	_focus._process(0.0)
	assert_eq(get_viewport().gui_get_focus_owner().name, "Primary")


func test_focus_inside_the_screen_is_kept() -> void:
	_focus.is_active = true
	(_screen.get_node("Second") as Button).grab_focus()
	_focus._process(0.0)
	assert_eq(get_viewport().gui_get_focus_owner().name, "Second")


func test_no_screen_drops_focus_so_a_dashes() -> void:
	_focus.is_active = true
	_focus._process(0.0)
	_root = null
	_focus._process(0.0)
	assert_null(get_viewport().gui_get_focus_owner())
	assert_eq(_focus.ring(), Rect2())


func test_going_inactive_clears_the_ring() -> void:
	_focus.is_active = true
	_focus._process(0.0)
	_focus.is_active = false
	assert_eq(_focus.ring(), Rect2())


func test_a_rebuilt_screen_keeps_the_ring_near_where_it_was() -> void:
	_focus.is_active = true
	var second: Button = _screen.get_node("Second")
	await wait_process_frames(1)  # lay the box out
	second.grab_focus()
	_focus._process(0.0)
	# The screen re-renders: the focused control is freed and a new one takes its place.
	var index: int = second.get_index()
	_screen.remove_child(second)
	second.free()
	var replacement: Button = Button.new()
	replacement.name = "Replacement"
	_screen.add_child(replacement)
	_screen.move_child(replacement, index)  # rebuilt in place
	await wait_process_frames(1)
	_focus._process(0.0)
	assert_eq(get_viewport().gui_get_focus_owner().name, "Replacement", "not back to the top")


func test_a_screen_without_a_primary_opens_on_its_first_control() -> void:
	var primary: Button = _screen.get_node("Primary")
	_screen.remove_child(primary)
	primary.free()
	assert_eq(PadFocus.entry_focus(_screen).name, "First")


func test_a_reopened_screen_starts_on_its_primary_again() -> void:
	_focus.is_active = true
	(_screen.get_node("Second") as Button).grab_focus()
	_focus._process(0.0)
	var opened: Control = _root
	_root = null  # the screen closes (a run is played)
	_focus._process(0.0)
	_root = opened  # the same screen opens again
	_focus._process(0.0)
	assert_eq(get_viewport().gui_get_focus_owner().name, "Primary", "not where it was last time")


func test_a_touch_in_between_also_resets_where_the_screen_opens() -> void:
	_focus.is_active = true
	(_screen.get_node("Second") as Button).grab_focus()
	_focus._process(0.0)
	_focus.is_active = false  # the player touched the screen
	(_screen.get_node("Second") as Button).release_focus()
	_focus.is_active = true
	_focus._process(0.0)
	assert_eq(get_viewport().gui_get_focus_owner().name, "Primary")


func _long_list() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "List"
	scroll.custom_minimum_size = Vector2(200, 100)
	var rows: VBoxContainer = VBoxContainer.new()
	for i: int in range(30):
		var row: Label = Label.new()
		row.text = "row %d" % i
		row.custom_minimum_size = Vector2(0, 40)
		rows.add_child(row)
	scroll.add_child(rows)
	_screen.add_child(scroll)
	return scroll


func test_the_list_to_scroll_is_found() -> void:
	var scroll: ScrollContainer = _long_list()
	await wait_process_frames(2)
	assert_eq(PadFocus.scroll_target(_screen), scroll)


func test_a_down_press_with_nowhere_to_go_scrolls_the_list() -> void:
	var scroll: ScrollContainer = _long_list()
	await wait_process_frames(2)
	_focus.is_active = true
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_DPAD_DOWN
	press.pressed = true
	_focus._unhandled_input(press)
	assert_gt(scroll.scroll_vertical, 0, "scrolled down")
	var before: int = scroll.scroll_vertical
	press.button_index = JOY_BUTTON_DPAD_UP
	_focus._unhandled_input(press)
	assert_lt(scroll.scroll_vertical, before, "and back up")


func test_touch_mode_does_not_scroll() -> void:
	var scroll: ScrollContainer = _long_list()
	await wait_process_frames(2)
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_DPAD_DOWN
	press.pressed = true
	_focus._unhandled_input(press)
	assert_eq(scroll.scroll_vertical, 0)


func test_closing_a_sheet_returns_the_ring_to_what_opened_it() -> void:
	_focus.is_active = true
	await wait_process_frames(1)
	(_screen.get_node("Second") as Button).grab_focus()
	_focus._process(0.0)
	var menu: Control = _root
	_root = _other  # a sheet opens over the menu
	_focus._process(0.0)
	assert_eq(get_viewport().gui_get_focus_owner().name, "Elsewhere")
	_root = menu  # and closes
	_focus._process(0.0)
	assert_eq(get_viewport().gui_get_focus_owner().name, "Second", "back on the opener")
