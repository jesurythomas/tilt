## touch_input.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1253-1285 (pointermove and touchmove), per spec §5.1
class_name TouchInput
extends RefCounted
## Turns pointer and touch motion into the pointer position the ship steers
## toward.
##
## PORT-NOTE: TiltGame.ts:1256-1258 rescales client coordinates by the canvas
## backing-store ratio. With content_scale_mode = disabled (spec §4.1) a Godot
## event position is already in the same pixels the sim works in, so there is
## no rescale to port.
##
## PORT-NOTE: TiltGame.ts:1254 and :1274 both early-out while `!this.isRunning`.
## GameRoot only forwards input events while the run is active, so that guard
## is its concern, not this class's.
##
## PORT-NOTE: the TypeScript registers no touchstart/pointerdown handler, so a
## tap that produces no motion never updates mousePos. InputEventScreenTouch
## is therefore not handled here — porting it would invent behaviour the
## TypeScript does not have.
##
## PORT-NOTE: on Android, Godot's default emulate_mouse_from_touch delivers
## both an InputEventScreenDrag and a synthesized InputEventMouseMotion for a
## single drag, so both branches below fire for the same position. Harmless
## and preserved rather than filtered.


## Applies one input event to the router.
## PORT: web/src/tilt-to-live/TiltGame.ts:1253-1285
# DIVERGENCE(M2.5 §6.1): arena_origin is subtracted so the pointer position
# reaches the router in playfield space, which is the space the sim runs in.
func handle_event(event: InputEvent, router: InputRouter, arena_origin: Vector2) -> void:
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		# PORT: web/src/tilt-to-live/TiltGame.ts:1280
		if router.control_scheme != Types.ControlScheme.GYRO:
			router.mouse_pos = drag.position - arena_origin
			router.control_mode = Types.ControlMode.MOUSE
		return

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		# PORT: web/src/tilt-to-live/TiltGame.ts:1259-1260
		router.mouse_pos = motion.position - arena_origin
		# PORT: web/src/tilt-to-live/TiltGame.ts:1263-1269
		if (
			not router.has_active_movement_keys()
			and router.control_scheme != Types.ControlScheme.KEYBOARD
			and router.control_scheme != Types.ControlScheme.GYRO
		):
			router.control_mode = Types.ControlMode.MOUSE
		return
