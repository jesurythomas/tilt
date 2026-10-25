## pad_focus.gd
## PORTS: nothing — new file per ruling PAD R3 (user 2026-10-23: "and UI support for the
## controller"; plan docs/superpowers/plans/2026-10-23-gamepad-stick.md)
class_name PadFocus
extends Control
## Lets a controller drive the menus. Godot's built-in ui_* actions already move focus with the
## D-pad and press the focused button with A; what the game lacked is a focused control to
## start from and a way to see it (the theme's focus box is empty, so a tap leaves no ring).
##
## While the controller is in use, each frame: the screen on top (`root_provider`, which
## GameRoot answers in go_back's order) must hold the focus, or its first focusable control
## takes it; in play, with no screen up, focus is dropped so A dashes rather than pressing a
## HUD button. A ring is drawn around the focused control. Inactive, it draws nothing and
## leaves focus alone. Sits last on the CanvasLayer, over every screen; taps pass through.

## DIVERGENCE(PAD R3): the ring is the dash gauge's ready cyan, outside the control by INSET.
const RING_COLOR: Color = Color("#3dfff0")
const RING_WIDTH: float = 2.0
const INSET: float = 3.0
const CORNER: float = 8.0
## The theme variation of each screen's main action.
const PRIMARY_VARIATION: StringName = &"PrimaryButton"
## DIVERGENCE(PAD R6, user 2026-10-23: "I cant scroll down on achievements check on other
## screens too"): a D-pad press that cannot move the focus scrolls the screen's list by this
## share of its height; the right stick scrolls this many list heights a second at full tilt.
const SCROLL_STEP: float = 0.35
const STICK_SCROLL_SPEED: float = 1.5

## True while the controller is the input in use (GameRoot sets it).
var is_active: bool = false:
	set(value):
		is_active = value
		if not value:
			_ring = Rect2()
			_memory.clear()  # a touch in between: the next screen opens on its primary
			queue_redraw()
## Returns the Control whose descendants may hold focus now, or null (nothing to focus).
var root_provider: Callable = func() -> Control: return null

var _ui_scale: float = 1.0
var _ring: Rect2 = Rect2()
## DIVERGENCE(PAD R3 fix): where the focus last was in each screen still up, by the screen's
## instance id. A screen that rebuilds its controls (picking a mode re-renders the menu) frees the
## focused one, and a sheet opened over a screen takes the focus away; either way the focus comes
## back to the control nearest that point (closing Settings lands on the gear), not to the top.
## Cleared when no screen is up (a run) or a touch ends controller mode.
var _memory: Dictionary[int, Vector2] = {}


func _ready() -> void:
	name = "PadFocus"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not is_active:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var root: Control = root_provider.call()
	_scroll_by_right_stick(root, delta)
	if root == null or not root.is_visible_in_tree():
		if focused != null:
			focused.release_focus()
		# No screen up: the next time one opens (the Run over is reused run to run), it opens
		# on its primary button, not where the ring was last time.
		_memory.clear()
		_show_ring(Rect2())
		return
	if focused == null or not focused.is_visible_in_tree() or not root.is_ancestor_of(focused):
		if _memory.has(root.get_instance_id()):
			var was_at: Vector2 = _memory[root.get_instance_id()]
			focused = nearest_focusable(root, was_at)
		else:
			focused = entry_focus(root)
		if focused == null:
			_show_ring(Rect2())
			return
		follow_focus_in(root)
		focused.grab_focus()
	var rect: Rect2 = focused.get_global_rect()
	_memory[root.get_instance_id()] = rect.get_center()
	_show_ring(Rect2(rect.position - global_position, rect.size).grow(INSET * _ui_scale))


## DIVERGENCE(PAD R6): Godot leaves ui_up / ui_down unhandled when no control lies that way
## (Achievements' rows, How to play's pages are not buttons), so the press scrolls the list.
func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var direction: float = 0.0
	if event.is_action_pressed("ui_down"):
		direction = 1.0
	elif event.is_action_pressed("ui_up"):
		direction = -1.0
	if direction == 0.0:
		return
	var root: Control = root_provider.call()
	var scroll: ScrollContainer = scroll_target(root)
	if scroll == null:
		return
	scroll.scroll_vertical += roundi(direction * scroll.size.y * SCROLL_STEP)
	get_viewport().set_input_as_handled()


## The list a controller scrolls under `root`: the scroll box holding the focus, else the
## tallest shown one that has something to scroll. Null when nothing scrolls.
static func scroll_target(root: Node) -> ScrollContainer:
	if root == null:
		return null
	var focused: Control = (root as Control).get_viewport().gui_get_focus_owner()
	var best: ScrollContainer = null
	for scroll: ScrollContainer in _scrolls(root, []):
		if not scroll.is_visible_in_tree() or not _can_scroll(scroll):
			continue
		if focused != null and scroll.is_ancestor_of(focused):
			return scroll
		if best == null or scroll.size.y > best.size.y:
			best = scroll
	return best


## Matches the HUD's ui_scale, for the ring's width and inset.
func set_ui_scale(scale: float) -> void:
	_ui_scale = scale
	queue_redraw()


## The ring's rect in this control's space; empty while nothing is ringed.
func ring() -> Rect2:
	return _ring


## DIVERGENCE(PAD R3 fix, 2026-10-23: the Run over opened on Watch ad, so a quick A after a
## death started an ad): a screen opens on its primary button (Play, Resume, Retry, Next, Set
## level, the reset sheet's Cancel), else on its first focusable control.
static func entry_focus(root: Node) -> Control:
	for control: Control in _focusables(root, []):
		if control.theme_type_variation == PRIMARY_VARIATION:
			return control
	return first_focusable(root)


## The first control under `root`, in tree order, that is shown, takes focus and is enabled.
static func first_focusable(root: Node) -> Control:
	for child: Node in root.get_children():
		if child is Control:
			var control: Control = child
			if not control.visible:
				continue
			if _takes_focus(control):
				return control
		var found: Control = first_focusable(child)
		if found != null:
			return found
	return null


## The shown, enabled, focusable control under `root` whose centre is nearest `point` (global).
static func nearest_focusable(root: Node, point: Vector2) -> Control:
	var best: Control = null
	var best_distance: float = INF
	for control: Control in _focusables(root, []):
		var distance: float = control.get_global_rect().get_center().distance_squared_to(point)
		if distance < best_distance:
			best = control
			best_distance = distance
	return best


## Every scroll box under `root` scrolls to the focused control, so the D-pad can reach rows
## below the fold (they scroll by drag otherwise).
static func follow_focus_in(root: Node) -> void:
	for child: Node in root.get_children():
		if child is ScrollContainer:
			var scroll: ScrollContainer = child
			scroll.follow_focus = true
		follow_focus_in(child)


static func _scrolls(root: Node, found: Array[ScrollContainer]) -> Array[ScrollContainer]:
	for child: Node in root.get_children():
		if child is ScrollContainer:
			found.append(child)
		_scrolls(child, found)
	return found


static func _can_scroll(scroll: ScrollContainer) -> bool:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	return bar.max_value - bar.page > 1.0


func _scroll_by_right_stick(root: Control, delta: float) -> void:
	var push: float = 0.0
	for device: int in Input.get_connected_joypads():
		var y: float = Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		if absf(y) > absf(push):
			push = y
	if absf(push) <= GamepadInput.DEAD_ZONE:
		return
	var scroll: ScrollContainer = scroll_target(root)
	if scroll != null:
		scroll.scroll_vertical += roundi(push * scroll.size.y * STICK_SCROLL_SPEED * delta)


static func _focusables(root: Node, found: Array[Control]) -> Array[Control]:
	for child: Node in root.get_children():
		if child is Control:
			var control: Control = child
			if not control.visible:
				continue
			if _takes_focus(control):
				found.append(control)
		_focusables(child, found)
	return found


static func _takes_focus(control: Control) -> bool:
	if control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton:
		var button: BaseButton = control
		return not button.disabled
	return true


func _show_ring(rect: Rect2) -> void:
	if rect == _ring:
		return
	_ring = rect
	queue_redraw()


func _draw() -> void:
	if not is_active or _ring.size == Vector2.ZERO:
		return
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = RING_COLOR
	box.set_border_width_all(maxi(1, roundi(RING_WIDTH * _ui_scale)))
	box.set_corner_radius_all(roundi(CORNER * _ui_scale))
	draw_style_box(box, _ring)
