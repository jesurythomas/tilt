## gamepad_input.gd
## PORTS: nothing — new file per ruling PAD R1 (user 2026-10-23: "what would be needed to get
## my odin controls working on stick mode"; plan docs/superpowers/plans/2026-10-23-gamepad-stick.md)
class_name GamepadInput
extends RefCounted
## Reads a controller's left stick for the Touch scheme, so a handheld with built-in sticks (an
## AYN Odin 2) steers like the on-screen stick: a direction with a magnitude, zero at rest.
##
## Also names the button each pad press maps to, so GameRoot's input handler stays a lookup.
## Polled by GameRoot each physics tick, like TiltInput; emits nothing.

## The game action a pad button stands for. NONE for buttons the game does not use.
enum PadAction { NONE, DASH, ITEM_1, ITEM_2, PAUSE, BACK }

## DIVERGENCE(PAD R4): which printed labels a pad has. Buttons are read by position (Godot's
## SDL mapping), so only the names shown on screen change with the family.
enum Family { XBOX, PLAYSTATION, NINTENDO }

## DIVERGENCE(PAD R1): a radial dead zone. Thumbsticks rest a few percent off centre; 0.2 is
## Godot's default action deadzone (0.5) halved, small enough to keep fine steering.
const DEAD_ZONE: float = 0.2

## DIVERGENCE(PAD R4): the label printed on each family's buttons, per action. Godot's A is the
## Xbox A and the PlayStation cross. Android maps Switch-style pads by label, not position: on
## the user's "Nintendo Switch Pro Controller" (USB 2020:0111, 2026-10-23) the button printed
## A came through as BTN_SOUTH, which its key layout makes BUTTON_A; Nintendo's own Pro
## Controller layout (Vendor_057e_Product_2009.kl) also maps the printed A to BUTTON_A. So it
## reads A there too, and the printed B is Back, as on a Switch.
const LABELS: Dictionary = {
	Family.XBOX: {PadAction.DASH: "A", PadAction.ITEM_1: "LB", PadAction.ITEM_2: "RB"},
	Family.PLAYSTATION: {PadAction.DASH: "×", PadAction.ITEM_1: "L1", PadAction.ITEM_2: "R1"},
	Family.NINTENDO: {PadAction.DASH: "A", PadAction.ITEM_1: "L", PadAction.ITEM_2: "R"},
}
## Lowercase fragments of Input.get_joy_name() that name a family; anything else reads as Xbox
## (the layout Android handhelds and most generic pads copy).
const PLAYSTATION_NAMES: Array[String] = [
	"playstation", "dualsense", "dualshock", "sony", "ps4", "ps5"
]
const NINTENDO_NAMES: Array[String] = ["nintendo", "switch", "pro controller", "joy-con"]


## Turns a raw stick reading (each axis -1..1) into a steering vector: zero inside the dead
## zone, then rescaled so the edge of the dead zone is 0 and full tilt is 1. Direction is kept.
static func shape(raw: Vector2) -> Vector2:
	var length: float = raw.length()
	if length <= DEAD_ZONE:
		return Vector2.ZERO
	var magnitude: float = minf((length - DEAD_ZONE) / (1.0 - DEAD_ZONE), 1.0)
	return raw / length * magnitude


## Maps a pad button to its game action. Positional (Godot's SDL layout): A is the bottom face
## button, whatever the pad prints on it.
static func action_for(button: JoyButton) -> PadAction:
	match button:
		JOY_BUTTON_A, JOY_BUTTON_LEFT_STICK:
			# PAD R5 (user 2026-10-23: "onehanded play optimization - stick button triggers the
			# dash"): clicking the steering stick dashes, so one thumb steers and dashes.
			return PadAction.DASH
		JOY_BUTTON_LEFT_SHOULDER:
			return PadAction.ITEM_1
		JOY_BUTTON_RIGHT_SHOULDER:
			return PadAction.ITEM_2
		JOY_BUTTON_START:
			return PadAction.PAUSE
		JOY_BUTTON_B:
			return PadAction.BACK
	return PadAction.NONE


## DIVERGENCE(PAD R3 fix, user 2026-10-23: "I cant select play with a or b"): Godot's default
## ui_accept is keys only, so a focused menu button ignored A. Adds the bottom face button to
## it, once. Nothing holds focus in play (PadFocus), so A still reaches GameRoot as the dash.
static func map_accept() -> void:
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.device = -1  # every pad
	if not InputMap.action_has_event("ui_accept", press):
		InputMap.action_add_event("ui_accept", press)


## DIVERGENCE(PAD R4): the family a pad's name belongs to.
static func family_for(joy_name: String) -> Family:
	var lower: String = joy_name.to_lower()
	for fragment: String in PLAYSTATION_NAMES:
		if lower.contains(fragment):
			return Family.PLAYSTATION
	for fragment: String in NINTENDO_NAMES:
		if lower.contains(fragment):
			return Family.NINTENDO
	return Family.XBOX


## The label `family` prints on the button for `action`, or "" when the HUD shows none.
static func label_for(action: PadAction, family: Family) -> String:
	var labels: Dictionary = LABELS[family]
	return labels.get(action, "")


## DIVERGENCE(PAD R2): whether the controller is in use after `event`: a pad button press or a
## stick pushed past the dead zone turns it on, a screen touch turns it off, anything else
## leaves `is_active` as it was. Drives the button badges on the HUD.
static func is_active_after(event: InputEvent, is_active: bool) -> bool:
	if event is InputEventJoypadButton:
		var button: InputEventJoypadButton = event
		return true if button.pressed else is_active
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		return true if absf(motion.axis_value) > DEAD_ZONE else is_active
	if event is InputEventScreenTouch:
		return false
	return is_active


## The strongest left stick among the connected pads, shaped. Zero when none is connected.
func poll() -> Vector2:
	var best: Vector2 = Vector2.ZERO
	for device: int in Input.get_connected_joypads():
		var raw: Vector2 = Vector2(
			Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		)
		var shaped: Vector2 = shape(raw)
		if shaped.length() > best.length():
			best = shaped
	return best
