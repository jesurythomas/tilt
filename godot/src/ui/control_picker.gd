## control_picker.gd
## NO TS COUNTERPART — authorised by M2.5 spec §4.3.
class_name ControlPicker
extends Control
## Three-button control-scheme picker, instanced on both the Game Over panel
## and the pause overlay.
##
## HYBRID is deliberately not offered (M2.5 spec D2): it remains in
## Types.ControlScheme as a cited port of GameOptions.ts:21, but "whichever
## device was touched last" is the non-choice this module exists to fix.

## Emitted when the player picks a scheme.
signal scheme_chosen(scheme: Types.ControlScheme)

@onready var _tilt_button: Button = get_node_or_null("%TiltButton")
@onready var _touch_button: Button = get_node_or_null("%TouchButton")
@onready var _keyboard_button: Button = get_node_or_null("%KeyboardButton")


func _ready() -> void:
	if _tilt_button == null:
		_tilt_button = find_child("TiltButton", true, false) as Button
	if _touch_button == null:
		_touch_button = find_child("TouchButton", true, false) as Button
	if _keyboard_button == null:
		_keyboard_button = find_child("KeyboardButton", true, false) as Button

	if _tilt_button != null:
		# button_pressed is ignored unless toggle_mode is true.
		_tilt_button.toggle_mode = true
		_tilt_button.pressed.connect(_on_scheme_button_pressed.bind(Types.ControlScheme.GYRO))
	if _touch_button != null:
		# button_pressed is ignored unless toggle_mode is true.
		_touch_button.toggle_mode = true
		_touch_button.pressed.connect(_on_scheme_button_pressed.bind(Types.ControlScheme.MOUSE))
	if _keyboard_button != null:
		# button_pressed is ignored unless toggle_mode is true.
		_keyboard_button.toggle_mode = true
		_keyboard_button.pressed.connect(
			_on_scheme_button_pressed.bind(Types.ControlScheme.KEYBOARD)
		)
		# A phone has no keyboard; offering one is a dead option.
		_keyboard_button.visible = not OS.has_feature("mobile")


## Marks one scheme as the active one.
func set_active_scheme(scheme: Types.ControlScheme) -> void:
	if _tilt_button != null:
		_tilt_button.button_pressed = scheme == Types.ControlScheme.GYRO
	if _touch_button != null:
		_touch_button.button_pressed = scheme == Types.ControlScheme.MOUSE
	if _keyboard_button != null:
		_keyboard_button.button_pressed = scheme == Types.ControlScheme.KEYBOARD


func _on_scheme_button_pressed(scheme: Types.ControlScheme) -> void:
	set_active_scheme(scheme)
	scheme_chosen.emit(scheme)
