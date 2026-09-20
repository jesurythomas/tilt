## game_root.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1822-1853 (loop), 1855-2083 (update),
##        2259-2318 (render dispatch), 2419-2439 (resizeCanvas)
##        per spec §5.1 and §5.4
class_name GameRoot
extends Node2D
## Owns every subsystem, reproduces resizeCanvas() and drives frame order.

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


func _input(event: InputEvent) -> void:
	_touch.handle_event(event, _router)

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
	return maxf(0.60, minf(1.15, min_dim / 680.0))


## Resizes viewport-dependent state.
## PORT: web/src/tilt-to-live/TiltGame.ts:2419-2439
func resize_canvas() -> void:
	_bounds = get_viewport_rect().size
	var scale: float = arena_scale(_bounds.x, _bounds.y)
	_player.set_scale(scale)
	_swarm.set_scale(scale)
	_weapons.set_scale(scale)
	_grid.resize(int(_bounds.x), int(_bounds.y))
	_state.set_bounds(_bounds)
	_run_controller.bounds = _bounds
	_entity_layer.set_elapsed(_state.elapsed)
