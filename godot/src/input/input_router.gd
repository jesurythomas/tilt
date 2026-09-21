## input_router.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1869-1878 (control-scheme resolution)
## and TiltGame.ts:2388-2417 (movement helpers), per spec §5.1
class_name InputRouter
extends RefCounted
## Resolves which control scheme is driving the ship and turns held movement
## keys into a normalised direction.
##
## Not a signal emitter: input is read by GameRoot each physics tick, exactly
## as TiltGame.update() reads it (spec §5.3 bans sim→sim signals).

## Configured scheme. PORT: web/src/tilt-to-live/GameOptions.ts:80
# PORT-NOTE: GameOptionsManager.settings.control_scheme persists this for save-shape
# fidelity (M7); the live value is ControlSettings.scheme, assigned by GameRoot
# (M2.5 spec §4.2, a DIVERGENCE). Nothing reads the persisted copy.
var control_scheme: Types.ControlScheme = Types.ControlScheme.HYBRID

## Last-used input device. PORT: web/src/tilt-to-live/TiltGame.ts:79
var control_mode: Types.ControlMode = Types.ControlMode.MOUSE

## Pointer position in arena space. PORT: web/src/tilt-to-live/TiltGame.ts:78
var mouse_pos: Vector2 = Vector2(400.0, 300.0)

# PORT-NOTE: web/src/tilt-to-live/TiltGame.ts:80 holds a Set<'up'|'down'|
# 'left'|'right'>. GDScript has no Set; a typed array with has()/erase() is
# the closest honest port.
var _active_movement_keys: Array[Types.MoveDirection] = []


## True while at least one movement key is held.
## PORT: web/src/tilt-to-live/TiltGame.ts:2388-2390
func has_active_movement_keys() -> bool:
	return _active_movement_keys.size() > 0


## Marks a movement direction as held.
## PORT: web/src/tilt-to-live/TiltGame.ts:1297
func press_movement_key(dir: Types.MoveDirection) -> void:
	if not _active_movement_keys.has(dir):
		_active_movement_keys.append(dir)


## Marks a movement direction as released.
## PORT: web/src/tilt-to-live/TiltGame.ts:1337-1340
func release_movement_key(dir: Types.MoveDirection) -> void:
	_active_movement_keys.erase(dir)


## Releases every held movement direction.
## PORT: web/src/tilt-to-live/TiltGame.ts:1499
func clear_movement_keys() -> void:
	_active_movement_keys.clear()


## Maps a keycode to a movement direction, or Types.ABSENT.
## PORT: web/src/tilt-to-live/TiltGame.ts:2392-2399
func get_movement_key_direction(keycode: Key) -> int:
	# PORT-NOTE: the TypeScript matches both KeyboardEvent.code and .key, which
	# in the browser is how one handles layout differences. Godot delivers a
	# single physical keycode, so each line collapses to its keycode set.
	if keycode == KEY_W or keycode == KEY_UP or keycode == KEY_KP_8:
		return Types.MoveDirection.UP
	if keycode == KEY_S or keycode == KEY_DOWN or keycode == KEY_KP_2:
		return Types.MoveDirection.DOWN
	if keycode == KEY_A or keycode == KEY_LEFT or keycode == KEY_KP_4:
		return Types.MoveDirection.LEFT
	if keycode == KEY_D or keycode == KEY_RIGHT or keycode == KEY_KP_6:
		return Types.MoveDirection.RIGHT
	return Types.ABSENT


## Combines the held movement directions into a normalised steering vector.
## PORT: web/src/tilt-to-live/TiltGame.ts:2401-2417
func get_movement_vector() -> Vector2:
	var dx: float = 0.0
	var dy: float = 0.0

	if _active_movement_keys.has(Types.MoveDirection.UP):
		dy -= 1.0
	if _active_movement_keys.has(Types.MoveDirection.DOWN):
		dy += 1.0
	if _active_movement_keys.has(Types.MoveDirection.LEFT):
		dx -= 1.0
	if _active_movement_keys.has(Types.MoveDirection.RIGHT):
		dx += 1.0

	if dx != 0.0 and dy != 0.0:
		var inv_len: float = 1.0 / sqrt(2.0)  # PORT: web/src/tilt-to-live/TiltGame.ts:2411
		dx *= inv_len
		dy *= inv_len

	return Vector2(dx, dy)


## Which mode actually drives the ship this frame.
## PORT: web/src/tilt-to-live/TiltGame.ts:1869-1878
func resolve_control_mode() -> Types.ControlMode:
	if control_scheme == Types.ControlScheme.MOUSE:
		return Types.ControlMode.MOUSE
	if control_scheme == Types.ControlScheme.KEYBOARD:
		return Types.ControlMode.KEYBOARD
	if control_scheme == Types.ControlScheme.GYRO:
		return Types.ControlMode.GYRO
	if has_active_movement_keys():
		return Types.ControlMode.KEYBOARD
	return control_mode
