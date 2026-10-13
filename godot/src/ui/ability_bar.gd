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
## its power-up's orb, fires it once, and dims once used. HudController feeds show_abilities()
## every frame; nothing redraws unless what it shows changed.

## An item button was pressed; `slot` is its loadout slot.
signal item_pressed(slot: int)

## DIVERGENCE(HUD R2): sizes in UI px at 1x — the gauge, the item buttons (a touch target), the
## gap, the gauge's ring, the item orb and the gauge glyph; the seconds' font size.
const GAUGE_SIZE: int = 44
const ITEM_SIZE: int = 48
const GAP: int = 10
const RING_WIDTH: float = 3.0
const ORB_SIZE: int = 34
const GLYPH_SIZE: int = 20
const SECONDS_SIZE: int = 14
## DIVERGENCE(HUD R2): the ring's fill is redrawn in this many steps (a 20 s cooldown: ~0.4 s).
const FRACTION_STEPS: int = 48
## DIVERGENCE(HUD R2): a used item's opacity, and the gauge disc's.
const USED_ALPHA: float = 0.3
const DISC_ALPHA: float = 0.85
## DIVERGENCE(HUD R2): ready is the HUD's top tier cyan, the shield the power-up shield's green.
const COLOR_READY: Color = Color("#3dfff0")
const COLOR_SHIELD: Color = UiTheme.COLOR_LOCKED_IN
const COLOR_COOLDOWN: Color = UiTheme.COLOR_ION

var _ui_scale: float = 1.0
var _is_left: bool = false
var _gauge: DashGauge = null
var _buttons: Array[Button] = []
var _shown_types: Array[Types.WeaponType] = []
var _shown_used: Array[bool] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	_gauge = DashGauge.new()
	_gauge.name = "DashGauge"
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_gauge)
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
		button.theme_type_variation = "IconButton"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(side, side)
		button.icon = WeaponIcons.orb_texture(types[slot], UiTheme.px(ORB_SIZE, _ui_scale))
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text = WeaponIcons.weapon_key(types[slot])
		button.pressed.connect(func() -> void: item_pressed.emit(slot))
		add_child(button)
		_buttons.append(button)
	set_left(_is_left)


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
		draw_circle(centre, radius, UiTheme.tint(UiTheme.COLOR_PANEL, DISC_ALPHA))
		draw_arc(centre, radius, 0.0, TAU, 48, UiTheme.COLOR_LINE, ring_width, true)
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
