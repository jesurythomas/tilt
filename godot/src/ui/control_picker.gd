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

# DIVERGENCE(M2.5 §4.3): 48dp minimum touch target, provisional until the
# device pass.
const BASE_TOUCH_TARGET: float = 48.0

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

	# DIVERGENCE(M2.5 §4.3): a plain Control with no minimum size collapses to
	# 0px inside the VBoxContainers on both the pause and game over panels,
	# which overflows the HBox onto RESUME / PLAY AGAIN. Node _ready() runs
	# child-first, so this fallback covers the first layout pass before
	# HudController._ready() calls set_ui_scale() with the viewport-derived
	# scale.
	set_ui_scale(1.0)


## Marks one scheme as the active one.
func set_active_scheme(scheme: Types.ControlScheme) -> void:
	if _tilt_button != null:
		_tilt_button.button_pressed = scheme == Types.ControlScheme.GYRO
	if _touch_button != null:
		_touch_button.button_pressed = scheme == Types.ControlScheme.MOUSE
	if _keyboard_button != null:
		_keyboard_button.button_pressed = scheme == Types.ControlScheme.KEYBOARD


## Scales each button's minimum touch target to the viewport.
func set_ui_scale(scale: float) -> void:
	# DIVERGENCE(M2.5 §4.3): the scene root is a plain Control with no minimum
	# size, so the pause/game-over VBoxContainers allocate it 0px and the
	# HBox of buttons overflows onto the next sibling (RESUME / PLAY AGAIN).
	# Reporting the same minimum height here keeps the picker's layout slot
	# in step with its buttons.
	custom_minimum_size.y = BASE_TOUCH_TARGET * scale
	if _tilt_button != null:
		_tilt_button.custom_minimum_size.y = BASE_TOUCH_TARGET * scale
	if _touch_button != null:
		_touch_button.custom_minimum_size.y = BASE_TOUCH_TARGET * scale
	if _keyboard_button != null:
		_keyboard_button.custom_minimum_size.y = BASE_TOUCH_TARGET * scale


func _on_scheme_button_pressed(scheme: Types.ControlScheme) -> void:
	set_active_scheme(scheme)
	scheme_chosen.emit(scheme)
