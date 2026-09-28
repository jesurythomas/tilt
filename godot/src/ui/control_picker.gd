## control_picker.gd
## NO TS COUNTERPART — authorised by M2.5 spec §4.3; restyled as the Segmented
## control by the interface spec §6.2 (System.dc.html, Pause.dc.html).
class_name ControlPicker
extends PanelContainer
## Segmented control-scheme picker — Touch | Tilt, plus Keyboard off-mobile —
## instanced on the Pause and Run over sheets.
##
## HYBRID is deliberately not offered (M2.5 spec D2): it remains in
## Types.ControlScheme as a cited port of GameOptions.ts:21, but "whichever
## device was touched last" is the non-choice this module exists to fix.

## Emitted when the player picks a scheme.
signal scheme_chosen(scheme: Types.ControlScheme)

## Gap between segments. DIVERGENCE(UI-SYSTEM): System.dc.html — Segmented gap 3
const SEGMENT_GAP: int = 3

var _row: HBoxContainer = null

@onready var _tilt_button: Button = get_node_or_null("%TiltButton")
@onready var _touch_button: Button = get_node_or_null("%TouchButton")
@onready var _keyboard_button: Button = get_node_or_null("%KeyboardButton")


func _ready() -> void:
	theme_type_variation = "Segmented"
	_row = find_child("Buttons", false, false) as HBoxContainer
	if _tilt_button == null:
		_tilt_button = find_child("TiltButton", true, false) as Button
	if _touch_button == null:
		_touch_button = find_child("TouchButton", true, false) as Button
	if _keyboard_button == null:
		_keyboard_button = find_child("KeyboardButton", true, false) as Button

	if _tilt_button != null:
		# button_pressed is ignored unless toggle_mode is true.
		_tilt_button.toggle_mode = true
		_tilt_button.theme_type_variation = "SegmentButton"
		_tilt_button.pressed.connect(_on_scheme_button_pressed.bind(Types.ControlScheme.GYRO))
	if _touch_button != null:
		# button_pressed is ignored unless toggle_mode is true.
		_touch_button.toggle_mode = true
		_touch_button.theme_type_variation = "SegmentButton"
		_touch_button.pressed.connect(_on_scheme_button_pressed.bind(Types.ControlScheme.MOUSE))
	if _keyboard_button != null:
		# button_pressed is ignored unless toggle_mode is true.
		_keyboard_button.toggle_mode = true
		_keyboard_button.theme_type_variation = "SegmentButton"
		_keyboard_button.pressed.connect(
			_on_scheme_button_pressed.bind(Types.ControlScheme.KEYBOARD)
		)
		# A phone has no keyboard; offering one is a dead option.
		_keyboard_button.visible = not OS.has_feature("mobile")
	set_ui_scale(1.0)


## Marks one scheme as the active one.
func set_active_scheme(scheme: Types.ControlScheme) -> void:
	if _tilt_button != null:
		_tilt_button.button_pressed = scheme == Types.ControlScheme.GYRO
	if _touch_button != null:
		_touch_button.button_pressed = scheme == Types.ControlScheme.MOUSE
	if _keyboard_button != null:
		_keyboard_button.button_pressed = scheme == Types.ControlScheme.KEYBOARD


## Scales each segment's touch target and the gap between segments.
func set_ui_scale(scale: float) -> void:
	if _row != null:
		_row.add_theme_constant_override("separation", UiTheme.px(SEGMENT_GAP, scale))
	for button: Button in [_tilt_button, _touch_button, _keyboard_button]:
		if button != null:
			button.custom_minimum_size.y = UiTheme.TOUCH_TARGET * scale
	# DIVERGENCE(UI R11): a glyph per scheme, tinted ion when selected.
	if _touch_button != null:
		_touch_button.icon = UiTheme.svg_texture(UiTheme.ICON_TOUCH, scale)
	if _tilt_button != null:
		_tilt_button.icon = UiTheme.svg_texture(UiTheme.ICON_TILT, scale)


func _on_scheme_button_pressed(scheme: Types.ControlScheme) -> void:
	set_active_scheme(scheme)
	scheme_chosen.emit(scheme)
