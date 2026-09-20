## game_root.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1822-1853 (loop), 1855-2083 (update),
##        2259-2318 (render dispatch), 2419-2439 (resizeCanvas)
##        per spec §5.1 and §5.4
class_name GameRoot
extends Node2D
## Owns every subsystem, reproduces resizeCanvas() and drives frame order.

# DIVERGENCE(M2.5 §6.2): the web game runs edge to edge; a phone has a bezel,
# a camera cutout and a gesture bar. Provisional values, to be measured on the
# A55 during the M2.5 device pass.
## Smallest inset applied when the platform reports no safe-area reduction.
const MIN_INSET_X: float = 8.0
const MIN_INSET_Y: float = 12.0
## Largest fraction of each axis the inset may consume, so a device reporting
## an aggressive safe area cannot letterbox the game.
const MAX_INSET_RATIO: float = 0.04

# DIVERGENCE(M2.5 §7.3): TiltGame.ts:2431 clamps the arena scale at 1.15, a
# ceiling tuned for a desktop canvas. On the target device (2340x1080) the
# formula yields 1.588 and the ceiling cuts it to 1.15, making entities
# proportionally ~27% smaller than the same formula produces on desktop, on a
# physically much smaller screen. Raising the ceiling restores the formula's
# own proportionality; the formula itself is unchanged. Provisional — the
# final value is measured on the A55 in the M2.5 device pass.
const MAX_ARENA_SCALE: float = 1.75

## The playfield's top-left corner in viewport space. Render layers translate
## by this; the simulation never sees it (M2.5 spec §6.1).
var arena_origin: Vector2 = Vector2.ZERO

var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _player: PlayerShip = null
var _swarm: EnemySwarm = null
var _weapons: WeaponSystem = null
var _scores: ScoreManager = null
var _audio: AudioBank = null
var _run_controller: RunController = null
var _router: InputRouter = null
var _touch: TouchInput = null
var _tilt: TiltInput = null
var _state: GameStateMachine = null
var _bounds: Vector2 = Vector2.ZERO

@onready var _grid_layer: GridLayer = %GridLayer
@onready var _entity_layer: EntityLayer = %EntityLayer
@onready var _effect_layer: EffectLayer = %EffectLayer


func _ready() -> void:
	add_to_group("game_root")
	_bounds = get_viewport_rect().size
	_grid = VectorGrid.new(int(_bounds.x), int(_bounds.y))
	_particles = ParticleEngine.new()
	_player = PlayerShip.new(_bounds.x / 2.0, _bounds.y / 2.0)
	_swarm = EnemySwarm.new()
	_weapons = WeaponSystem.new()
	_scores = ScoreManager.new()
	_audio = AudioBank.new()
	_run_controller = RunController.new(
		_player, _swarm, _weapons, _particles, _grid, _scores, _audio
	)
	_router = InputRouter.new()
	_touch = TouchInput.new()
	_tilt = TiltInput.new()
	_state = GameStateMachine.new(_player, _grid, _particles, _router, _tilt)

	_grid_layer.bind(_grid)
	_entity_layer.bind_entities(_player, _swarm, _weapons)
	_effect_layer.bind(_particles, _scores)

	resize_canvas()
	get_viewport().size_changed.connect(resize_canvas)

	if _tilt.is_supported:
		var started: bool = _tilt.request_permission_and_start()
		Log.info("tilt sensor start requested: %s" % started)

	_state.start()
	# In M2, calibrate tilt on start so current phone angle is neutral
	_tilt.calibrate_current_position()
	_state.launch_run(Types.GameMode.CLASSIC)
	_run_controller.reset_run(_bounds)
	Log.info("M2 boot: bounds=%s arena_scale=%f" % [_bounds, arena_scale(_bounds.x, _bounds.y)])


func _unhandled_input(event: InputEvent) -> void:
	_touch.handle_event(event, _router, arena_origin)

	if event is InputEventKey:
		var key_event: InputEventKey = event
		var dir: int = _router.get_movement_key_direction(key_event.keycode)
		if dir == Types.ABSENT:
			return
		if key_event.pressed:
			# PORT: web/src/tilt-to-live/TiltGame.ts:1296-1299
			if (
				_router.control_scheme != Types.ControlScheme.MOUSE
				and _router.control_scheme != Types.ControlScheme.GYRO
			):
				_router.press_movement_key(dir)
				_router.control_mode = Types.ControlMode.KEYBOARD
		else:
			# PORT: web/src/tilt-to-live/TiltGame.ts:1337-1340
			_router.release_movement_key(dir)


func _physics_process(delta: float) -> void:
	match _state.phase:
		Types.GamePhase.PLAYING:
			_update(delta * Tuning.GAME_SPEED)
		Types.GamePhase.CINEMATIC:
			_grid.update(delta)
			_particles.update(delta)
		_:
			pass


func _process(_delta: float) -> void:
	_grid_layer.queue_redraw()
	_entity_layer.queue_redraw()
	_effect_layer.queue_redraw()


## Advances simulation systems via RunController.
func _update(dt: float) -> void:
	_state.elapsed += dt

	var effective_mode: Types.ControlMode = _router.resolve_control_mode()
	if effective_mode == Types.ControlMode.GYRO:
		_tilt.poll()

	_run_controller.update(
		dt, effective_mode, _router.mouse_pos, _router.get_movement_vector(), _tilt.tilt_vector
	)

	_entity_layer.set_elapsed(_run_controller.elapsed)


## Restarts the run cleanly into playing state.
func restart_run() -> void:
	_tilt.calibrate_current_position()
	_state.phase = Types.GamePhase.PLAYING
	_run_controller.reset_run(_bounds)
	GameEvents.phase_changed.emit(Types.GamePhase.PLAYING)


## Calculates the arena scale factor for a viewport dimension.
## PORT: web/src/tilt-to-live/TiltGame.ts:2422-2431
static func arena_scale(width: float, height: float) -> float:
	var w: float = maxf(320.0, floorf(width))
	var h: float = maxf(240.0, floorf(height))
	var min_dim: float = minf(w, h)
	return maxf(0.60, minf(MAX_ARENA_SCALE, min_dim / 680.0))


## The per-axis inset between the viewport edge and the playfield.
# DIVERGENCE(M2.5 §6.2): no TypeScript counterpart.
static func arena_inset(viewport: Vector2, safe: Rect2) -> Vector2:
	# A degenerate or oversized safe area is not trusted; the floor and the
	# ceiling below bracket whatever the platform reports.
	var reported_x: float = 0.0
	var reported_y: float = 0.0
	if safe.size.x > 0.0 and safe.size.y > 0.0:
		reported_x = maxf(safe.position.x, viewport.x - (safe.position.x + safe.size.x))
		reported_y = maxf(safe.position.y, viewport.y - (safe.position.y + safe.size.y))

	var inset_x: float = clampf(reported_x, MIN_INSET_X, viewport.x * MAX_INSET_RATIO)
	var inset_y: float = clampf(reported_y, MIN_INSET_Y, viewport.y * MAX_INSET_RATIO)
	return Vector2(inset_x, inset_y)


## Resizes viewport-dependent state.
## PORT: web/src/tilt-to-live/TiltGame.ts:2419-2439
func resize_canvas() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	# DIVERGENCE(M2.5 §6.1): _bounds is now the playfield size rather than the
	# viewport size, and arena_origin says where the playfield starts. Every
	# simulation system keeps working in 0..bounds and is unchanged.
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	var inset: Vector2 = arena_inset(viewport, safe)
	arena_origin = inset
	_bounds = viewport - inset * 2.0

	var scale: float = arena_scale(_bounds.x, _bounds.y)
	_player.set_scale(scale)
	_swarm.set_scale(scale)
	_weapons.set_scale(scale)
	_grid.resize(int(_bounds.x), int(_bounds.y))
	_state.set_bounds(_bounds)
	_run_controller.bounds = _bounds
	_entity_layer.set_elapsed(_state.elapsed)

	_grid_layer.set_arena_origin(arena_origin)
	_entity_layer.set_arena_origin(arena_origin)
	_effect_layer.set_arena_origin(arena_origin)
