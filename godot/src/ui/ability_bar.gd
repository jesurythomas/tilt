## ability_bar.gd
## PORTS: nothing — new file per ruling HUD R2 (user 2026-10-14: "We need to show the Dash
## cooldown and clickable items"; plan docs/superpowers/plans/2026-10-14-dash-and-abilities.md)
class_name AbilityBar
extends HBoxContainer
## The dash gauge and the item buttons, in a bottom corner of the arena frame.
##
## The gauge is display only (a tap on it passes through and counts toward a double tap). It
## refills over the cooldown, drains in the shield's green while the dash shield is up, shows
## the seconds left while cooling, and lights up when the dash is ready. Each item button shows
## its power-up's orb, fires it once, and dims once used. DIVERGENCE(HUD R3, user 2026-10-14:
## "having the background on abilities/items seem bad"): neither has a panel behind it; the
## orbs and the ring sit on the playfield. HudController feeds show_abilities()
## every frame; nothing redraws unless what it shows changed.

## An item button was pressed; `slot` is its loadout slot.
signal item_pressed(slot: int)

## DIVERGENCE(HUD R2): sizes in UI px at 1x — the gauge, the item buttons (a touch target), the
## gap, the gauge's ring, the item orb and the gauge glyph; the seconds' font size. HUD R3: with
## no panel behind it, the orb fills most of its touch target.
const GAUGE_SIZE: int = 44
const ITEM_SIZE: int = 48
const GAP: int = 10
const RING_WIDTH: float = 3.0
const ORB_SIZE: int = 42
const GLYPH_SIZE: int = 20
const SECONDS_SIZE: int = 14
## DIVERGENCE(HUD R2): the ring's fill is redrawn in this many steps (a 20 s cooldown: ~0.4 s).
const FRACTION_STEPS: int = 48
## DIVERGENCE(HUD R2): a used item's opacity.
const USED_ALPHA: float = 0.3
## DIVERGENCE(HUD R2): ready is the HUD's top tier cyan, the shield the power-up shield's green.
const COLOR_READY: Color = Color("#3dfff0")
const COLOR_SHIELD: Color = UiTheme.COLOR_LOCKED_IN
const COLOR_COOLDOWN: Color = UiTheme.COLOR_ION
## DIVERGENCE(PAD R2): the controller button each control answers to, shown as a badge in its
## bottom-right corner while the controller is in use (labels per pad family, PAD R4); the
## badge's font size and height.
const PAD_ITEM_ACTIONS: Array[GamepadInput.PadAction] = [
	GamepadInput.PadAction.ITEM_1, GamepadInput.PadAction.ITEM_2
]
const BADGE_FONT_SIZE: int = 10
const BADGE_HEIGHT: int = 16

var _ui_scale: float = 1.0
var _is_left: bool = false
var _gauge: DashGauge = null
var _buttons: Array[Button] = []
var _shown_types: Array[Types.WeaponType] = []
var _shown_used: Array[bool] = []
var _is_pad_hinted: bool = false
var _pad_family: GamepadInput.Family = GamepadInput.Family.XBOX


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	_gauge = DashGauge.new()
	_gauge.name = "DashGauge"
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_gauge)
	_gauge.add_child(PadBadge.new(GamepadInput.PadAction.DASH))
	set_ui_scale(_ui_scale)


## Resizes the gauge and buttons for `scale` (HudController's ui_scale).
func set_ui_scale(scale: float) -> void:
	_ui_scale = scale
	add_theme_constant_override("separation", UiTheme.px(GAP, scale))
	if _gauge != null:
		_gauge.custom_minimum_size = Vector2.ONE * UiTheme.px(GAUGE_SIZE, scale)
		_gauge.ui_scale = scale
		_gauge.queue_redraw()
	_shown_types = []
	_shown_used = []
	_refresh_badges()


## Puts the gauge on the inside edge: right of the items in the left corner, left of them in
## the right corner (the items sit nearest the thumb).
func set_left(is_left: bool) -> void:
	_is_left = is_left
	alignment = BoxContainer.ALIGNMENT_BEGIN if is_left else BoxContainer.ALIGNMENT_END
	if _gauge != null:
		move_child(_gauge, get_child_count() - 1 if is_left else 0)


## True while the bar sits in the bottom-left corner.
func is_on_left() -> bool:
	return _is_left


## Shows `abilities`' dash and items; cheap when nothing changed.
func show_abilities(abilities: AbilitySystem) -> void:
	if _gauge != null:
		_gauge.show_dash(abilities)
	if abilities.item_types != _shown_types:
		_rebuild_buttons(abilities.item_types)
	if abilities.item_used != _shown_used:
		_shown_used = abilities.item_used.duplicate()
		for slot: int in range(_buttons.size()):
			var is_used: bool = slot < _shown_used.size() and _shown_used[slot]
			_buttons[slot].disabled = is_used
			_buttons[slot].modulate.a = USED_ALPHA if is_used else 1.0


## DIVERGENCE(PAD R2): shows or hides the controller button badges, labelled for `family`
## (PAD R4).
func set_pad_hints(is_shown: bool, family: GamepadInput.Family = GamepadInput.Family.XBOX) -> void:
	_is_pad_hinted = is_shown
	_pad_family = family
	_refresh_badges()


## True while the controller button badges show.
func has_pad_hints() -> bool:
	return _is_pad_hinted


## The badge on the gauge or an item button (tests read it), or null.
static func badge_of(control: Control) -> PadBadge:
	if control == null:
		return null
	for child: Node in control.get_children():
		if child is PadBadge:
			return child
	return null


## The item button for `slot`, or null.
func item_button(slot: int) -> Button:
	return _buttons[slot] if slot >= 0 and slot < _buttons.size() else null


## The gauge (tests read its state).
func gauge() -> DashGauge:
	return _gauge


func _rebuild_buttons(types: Array[Types.WeaponType]) -> void:
	_shown_types = types.duplicate()
	_shown_used = []
	for button: Button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons = []
	var side: float = float(UiTheme.px(ITEM_SIZE, _ui_scale))
	for slot: int in range(types.size()):
		var button: Button = Button.new()
		button.name = "ItemButton_%d" % slot
		button.focus_mode = Control.FOCUS_NONE
		# DIVERGENCE(HUD R3): no panel, in any state; the orb is the button.
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.custom_minimum_size = Vector2(side, side)
		button.icon = WeaponIcons.orb_texture(types[slot], UiTheme.px(ORB_SIZE, _ui_scale))
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text = WeaponIcons.weapon_key(types[slot])
		button.pressed.connect(func() -> void: item_pressed.emit(slot))
		if slot < PAD_ITEM_ACTIONS.size():
			button.add_child(PadBadge.new(PAD_ITEM_ACTIONS[slot]))
		add_child(button)
		_buttons.append(button)
	set_left(_is_left)
	_refresh_badges()


func _refresh_badges() -> void:
	var owners: Array[Control] = [_gauge]
	owners.append_array(_buttons)
	for control: Control in owners:
		var badge: PadBadge = badge_of(control)
		if badge != null:
			badge.visible = _is_pad_hinted
			badge.text = GamepadInput.label_for(badge.action, _pad_family)
			badge.place(_ui_scale)


## The dash ring: a disc, a track, the fill, and the glyph or the seconds left.
class DashGauge:
	extends Control

	## The HUD's ui_scale.
	var ui_scale: float = 1.0
	## What was last drawn.
	var state: AbilitySystem.DashState = AbilitySystem.DashState.READY
	var steps: int = FRACTION_STEPS
	var seconds: int = 0

	## Redraws when the state, the fill step or the seconds shown changed.
	func show_dash(abilities: AbilitySystem) -> void:
		var new_state: AbilitySystem.DashState = abilities.dash_state()
		var new_steps: int = floori(abilities.dash_fraction() * FRACTION_STEPS)
		var new_seconds: int = ceili(abilities.dash_cooldown_left)
		if new_state == state and new_steps == steps and new_seconds == seconds:
			return
		state = new_state
		steps = new_steps
		seconds = new_seconds
		queue_redraw()

	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var ring_width: float = RING_WIDTH * ui_scale
		var radius: float = minf(size.x, size.y) * 0.5 - ring_width * 0.5
		# DIVERGENCE(HUD R3): no disc behind the ring; the track alone marks the gauge.
		draw_arc(centre, radius, 0.0, TAU, 48, UiTheme.COLOR_LINE_STRONG, ring_width, true)
		var color: Color = COLOR_READY
		if state == AbilitySystem.DashState.SHIELD:
			color = COLOR_SHIELD
		elif state == AbilitySystem.DashState.COOLDOWN:
			color = COLOR_COOLDOWN
		var fraction: float = float(steps) / float(FRACTION_STEPS)
		if fraction > 0.0:
			var start: float = -PI / 2.0
			draw_arc(centre, radius, start, start + TAU * fraction, 48, color, ring_width, true)
		if state == AbilitySystem.DashState.COOLDOWN:
			var font: Font = UiTheme.mono(UiTheme.Weight.SEMIBOLD)
			var font_size: int = UiTheme.px(SECONDS_SIZE, ui_scale)
			var text: String = str(seconds)
			var text_size: Vector2 = font.get_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			)
			var baseline: Vector2 = Vector2(
				centre.x - text_size.x * 0.5, centre.y + font.get_ascent(font_size) * 0.5 - 1.0
			)
			# HUD R3: over the playfield, the seconds take the HUD's void outline
			# (UiTheme.legible_over_play) so dots behind them do not show through.
			draw_string_outline(
				font,
				baseline,
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				UiTheme.OVER_PLAY_OUTLINE,
				UiTheme.COLOR_VOID
			)
			draw_string(
				font,
				baseline,
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				UiTheme.TEXT_SECONDARY
			)
			return
		var glyph_px: int = UiTheme.px(GLYPH_SIZE, ui_scale)
		var glyph: Texture2D = WeaponIcons.texture("dash", glyph_px)
		draw_texture(glyph, centre - Vector2.ONE * glyph_px * 0.5, color)


## DIVERGENCE(PAD R2): a small pill naming a controller button, pinned to its parent's
## bottom-right corner. Display only; taps pass through.
class PadBadge:
	extends Control

	## The action it names; `text` is that action's label on the pad in use, e.g. "A" or "LB".
	var action: GamepadInput.PadAction = GamepadInput.PadAction.NONE
	var text: String = ""
	var _ui_scale: float = 1.0

	func _init(for_action: GamepadInput.PadAction) -> void:
		action = for_action
		text = GamepadInput.label_for(for_action, GamepadInput.Family.XBOX)
		name = "PadBadge"
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Sizes the pill for `scale` and pins it to the parent's bottom-right corner.
	func place(scale: float) -> void:
		_ui_scale = scale
		var font: Font = UiTheme.mono(UiTheme.Weight.SEMIBOLD)
		var font_size: int = UiTheme.px(BADGE_FONT_SIZE, scale)
		var height: float = float(UiTheme.px(BADGE_HEIGHT, scale))
		var text_width: float = (
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
		var width: float = maxf(height, text_width + height * 0.6)
		set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		offset_left = -width
		offset_top = -height
		offset_right = 0.0
		offset_bottom = 0.0
		queue_redraw()

	func _draw() -> void:
		var radius: float = size.y * 0.5
		var pill: StyleBoxFlat = StyleBoxFlat.new()
		pill.bg_color = UiTheme.COLOR_VOID
		pill.border_color = UiTheme.TEXT_SECONDARY
		pill.set_border_width_all(maxi(1, roundi(_ui_scale)))
		pill.set_corner_radius_all(roundi(radius))
		draw_style_box(pill, Rect2(Vector2.ZERO, size))
		var font: Font = UiTheme.mono(UiTheme.Weight.SEMIBOLD)
		var font_size: int = UiTheme.px(BADGE_FONT_SIZE, _ui_scale)
		var text_size: Vector2 = font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		)
		var baseline: Vector2 = Vector2(
			(size.x - text_size.x) * 0.5, size.y * 0.5 + font.get_ascent(font_size) * 0.5 - 1.0
		)
		draw_string(
			font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.TEXT_SECONDARY
		)
