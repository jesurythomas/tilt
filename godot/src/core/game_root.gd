## game_root.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1822-1853 (loop), 1855-1891
## (update steps 1-3), 2259-2318 (render dispatch) and 2419-2439
## (resizeCanvas), per spec §5.1
class_name GameRoot
extends Node2D
## Owns every subsystem, reproduces resizeCanvas() and drives frame order.
##
## Frame order (spec §5.4) — M1 implements steps 1, 2 and 3 only:
##   1. grid.update(dt)
##   2. particles.update(dt)
##   3. player.update(...) after control-scheme resolution
## Later modules insert their systems at their documented indices. No module
## may reorder an existing step.

var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _player: PlayerShip = null
var _router: InputRouter = null
var _touch: TouchInput = null
var _tilt: TiltInput = null
var _state: GameStateMachine = null
var _bounds: Vector2 = Vector2.ZERO

@onready var _grid_layer: GridLayer = %GridLayer
@onready var _entity_layer: EntityLayer = %EntityLayer


func _ready() -> void:
	_bounds = get_viewport_rect().size
	_grid = VectorGrid.new(_bounds.x, _bounds.y)
	_particles = ParticleEngine.new()
	_player = PlayerShip.new(_bounds.x / 2.0, _bounds.y / 2.0)
	_router = InputRouter.new()
	_touch = TouchInput.new()
	_tilt = TiltInput.new()
	_state = GameStateMachine.new(_player, _grid, _particles, _router, _tilt)

	_grid_layer.bind(_grid)
	_entity_layer.bind(_player)

	resize_canvas()
	get_viewport().size_changed.connect(resize_canvas)

	if _tilt.is_supported:
		var started: bool = _tilt.request_permission_and_start()
		Log.info("tilt sensor start requested: %s" % started)

	_state.start()
	# PORT-NOTE: TiltGame.ts:1476 stops at the menu and the menu's Play button
	# calls launchRun(). TiltMenu is M11 (spec §8), so M1 launches immediately;
	# otherwise nothing is steerable and the module cannot be accepted.
	# TODO(M11): remove this and let the menu call launch_run().
	_state.launch_run(Types.GameMode.CLASSIC)
	Log.info("M1 boot: bounds=%s arena_scale=%f" % [_bounds, arena_scale(_bounds.x, _bounds.y)])


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
	# PORT-NOTE: TiltGame.ts:1843-1848 accumulates real time and substeps at
	# 1/120 s, passing fixedDt * GAME_SPEED to update(). Godot's fixed step
	# replaces that accumulator, running at 120 Hz per project.godot
	# physics_ticks_per_second=120 (amends spec §4.3's 60 Hz per spec D8); the
	# per-step delta still carries GAME_SPEED so the sim advances 25% slower per
	# real second, exactly as the TypeScript does. max_fps=60 is unchanged — it
	# caps rendering, not physics.
	match _state.phase:
		Types.GamePhase.PLAYING:
			_update(delta * Tuning.GAME_SPEED)
		Types.GamePhase.CINEMATIC:
			# PORT: web/src/tilt-to-live/TiltGame.ts:1834-1836
			_grid.update(delta)
			_particles.update(delta)
			# TODO(M11): cinematic.update(dt, width, height).
		Types.GamePhase.MENU:
			# TODO(M11): updateMenuSimulation(dt) — render/menu_backdrop.gd.
			pass
		_:
			pass


func _process(_delta: float) -> void:
	_grid_layer.queue_redraw()
	_entity_layer.queue_redraw()


## Calculates the arena scale factor for a viewport dimension.
## PORT: web/src/tilt-to-live/TiltGame.ts:2422-2431
static func arena_scale(width: float, height: float) -> float:
	var w: float = maxf(320.0, floorf(width))  # PORT: web/src/tilt-to-live/TiltGame.ts:2422
	var h: float = maxf(240.0, floorf(height))  # PORT: web/src/tilt-to-live/TiltGame.ts:2423
	var min_dim: float = minf(w, h)
	return maxf(0.60, minf(1.15, min_dim / 680.0))  # PORT: web/src/tilt-to-live/TiltGame.ts:2431


## Resizes viewport-dependent state.
## PORT: web/src/tilt-to-live/TiltGame.ts:2419-2439
func resize_canvas() -> void:
	# PORT-NOTE: TiltGame.ts:2420 and 2425-2426 resize the canvas backing store
	# by devicePixelRatio. Godot owns the framebuffer and content_scale_mode is
	# disabled (spec §4.1), so get_viewport_rect().size is already the pixel
	# size the sim works in and there is nothing to scale.
	_bounds = get_viewport_rect().size
	var scale: float = arena_scale(_bounds.x, _bounds.y)
	_player.set_scale(scale)
	# TODO(M3): swarm.setScale(scale).
	# TODO(M4): weapons.setScale(scale).
	# TODO(M10): gauntletMaze.setScale(scale).
	# TODO(M2): renderer scale — render/render_context.gd.
	_grid.resize(_bounds.x, _bounds.y)
	_state.set_bounds(_bounds)
	_entity_layer.set_elapsed(_state.elapsed)


## Frame order steps 1-3. PORT: web/src/tilt-to-live/TiltGame.ts:1855-1891
func _update(dt: float) -> void:
	_state.elapsed += dt  # PORT: web/src/tilt-to-live/TiltGame.ts:1856

	# 1. Update Grid
	_grid.update(dt)

	# 2. Update Particles
	# PORT-NOTE: particles update before the player here, matching
	# TiltGame.ts:1866. Particles emitted this tick therefore draw unaged.
	# Looks accidental; preserved deliberately — it is part of the tuned feel.
	_particles.update(dt)

	# 3. Update Player Ship with scheme checks
	var effective_mode: Types.ControlMode = _router.resolve_control_mode()
	if effective_mode == Types.ControlMode.GYRO:
		_tilt.poll()

	_player.update(
		dt,
		_router.mouse_pos,
		_bounds,
		_particles,
		effective_mode,
		_router.get_movement_vector(),
		1.0,
		4.0,
		1.0,
		1.0,
		Color("#00ddff"),
		_tilt.tilt_vector
	)
	# TODO(M7): the last five arguments come from progression.data.tuning
	# (sensitivity, deadzone) and progression.getEquippedShip() (hitboxScale,
	# turnRate, thrusterColor). PlayerShip.ts:101-102 defaults are used here.

	# TODO(M10): step 3.5 — gauntletMaze.update() in gauntlet mode.
	# TODO(M3): step 4 — swarm.update().
	# TODO(M4): step 5 — weapons.update().
	# TODO(M7): step 7 — coins.update().
	# TODO(M2): step 8 — scores.update(); step 9 — check_collisions().
	# TODO(M9): step 10 — run-tracker sync and live goal evaluation.
	# TODO(M2): step 11 — HUD signal emission.

	_entity_layer.set_elapsed(_state.elapsed)
