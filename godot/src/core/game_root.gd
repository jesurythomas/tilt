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

# DIVERGENCE(M2.5 §8.1): measured on SM_A556E — full 540 px/s speed on a touch
# screen caused overshooting and twitchy dodging. 0.72 caps top speed to 390 px/s.
const TOUCH_JOYSTICK_SPEED_SCALE: float = 0.72

## The playfield's top-left corner in viewport space. Render layers translate
## by this; the simulation never sees it (M2.5 spec §6.1).
var arena_origin: Vector2 = Vector2.ZERO

## Player control settings, persisted across launches.
var settings: ControlSettings = null

## The player's save. PORT: web/src/tilt-to-live/TiltGame.ts:55
var progression: ProgressionManager = null
## Mode and settings. PORT: web/src/tilt-to-live/TiltGame.ts:65
var options: GameOptionsManager = null

var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _player: PlayerShip = null
var _swarm: EnemySwarm = null
var _weapons: WeaponSystem = null
var _coins: CoinSystem = null
var _scores: ScoreManager = null
var _audio: AudioBank = null
var _run_controller: RunController = null
var _router: InputRouter = null
var _touch: TouchInput = null
var _tilt: TiltInput = null
var _joystick: FloatingJoystick = null
var _state: GameStateMachine = null
var _bounds: Vector2 = Vector2.ZERO

@onready var _grid_layer: GridLayer = %GridLayer
@onready var _entity_layer: EntityLayer = %EntityLayer
@onready var _effect_layer: EffectLayer = %EffectLayer
@onready var _joystick_layer: JoystickLayer = %JoystickLayer
@onready var _hud: HudController = find_child("Hud", true, false) as HudController
@onready var _armory: ArmoryUI = %Armory


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
	progression = ProgressionManager.new()
	options = GameOptionsManager.new()
	_coins = CoinSystem.new()
	_run_controller = RunController.new(
		_player, _swarm, _weapons, _particles, _grid, _scores, _audio, progression, options, _coins
	)
	_router = InputRouter.new()
	_touch = TouchInput.new()
	_tilt = TiltInput.new()
	_joystick = FloatingJoystick.new()
	# DIVERGENCE(M2.5 §4.2): the scheme comes from persisted settings rather
	# than the hardcoded HYBRID at input_router.gd:14.
	settings = ControlSettings.new()
	_router.control_scheme = settings.scheme
	_tilt.tilt_sensitivity = settings.tilt_sensitivity
	_tilt.tilt_smoothing = settings.tilt_smoothing
	_state = GameStateMachine.new(_player, _grid, _particles, _router, _tilt)

	_grid_layer.bind(_grid)
	# PORT: web/src/tilt-to-live/TiltGame.ts:2280 (showGridlines into the renderer)
	_grid_layer.show_gridlines = options.settings.show_gridlines
	_entity_layer.bind_entities(_player, _swarm, _weapons, _coins)
	_effect_layer.bind(_particles, _scores, _weapons)
	_joystick_layer.bind(_joystick)

	# PORT: web/src/tilt-to-live/TiltGame.ts:180-184
	_armory.bind(progression)
	_armory.state_changed.connect(_on_armory_state_changed)
	_armory.closed.connect(_on_armory_closed)
	_apply_equipped_cosmetics()
	GameEvents.run_ended.connect(_on_run_ended)

	resize_canvas()
	get_viewport().size_changed.connect(resize_canvas)

	if _tilt.is_supported:
		var started: bool = _tilt.request_permission_and_start()
		Log.info("tilt sensor start requested: %s" % started)

	_state.start()
	# DIVERGENCE(M2.5 §5.3): this requests calibration; TiltInput now waits for
	# a real gravity sample rather than falling back to a hardcoded pose.
	_tilt.calibrate_current_position()
	_state.launch_run(Types.GameMode.CLASSIC)
	_run_controller.reset_run(_bounds)
	Log.info("M2 boot: bounds=%s arena_scale=%f" % [_bounds, arena_scale(_bounds.x, _bounds.y)])


func _unhandled_input(event: InputEvent) -> void:
	# DIVERGENCE(M2.5 §8.1): the TOUCH scheme drives the floating joystick;
	# every other scheme keeps TiltGame.ts's steer-toward-pointer behaviour.
	# NOTE: TOUCH is the control picker's label for Types.ControlScheme.MOUSE
	# (spec §4.3) — the enum value is a cited port of GameOptions.ts:21.
	if _router.control_scheme == Types.ControlScheme.MOUSE and OS.has_feature("mobile"):
		if event is InputEventScreenTouch:
			var touch: InputEventScreenTouch = event
			if touch.pressed:
				_joystick.on_touch(touch.index, touch.position - arena_origin)
			else:
				_joystick.on_release(touch.index)
			return
		if event is InputEventScreenDrag:
			var drag: InputEventScreenDrag = event
			_joystick.on_drag(drag.index, drag.position - arena_origin)
			return
	else:
		_touch.handle_event(event, _router, arena_origin)

	# PORT: web/src/tilt-to-live/TiltGame.ts:1319-1328 — b/u toggle, Escape closes.
	# TODO(M11): 'p'/Escape pause toggle (:1329-1330) lands with the menu's key map.
	if event is InputEventKey:
		var armory_key: InputEventKey = event
		if armory_key.pressed and not armory_key.echo:
			if armory_key.keycode == KEY_B or armory_key.keycode == KEY_U:
				if _armory.is_open():
					close_armory()
				else:
					open_armory()
				return
			if armory_key.keycode == KEY_ESCAPE and _armory.is_open():
				close_armory()
				return

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
	_joystick_layer.queue_redraw()


## Advances simulation systems via RunController.
func _update(dt: float) -> void:
	_state.elapsed += dt

	var effective_mode: Types.ControlMode = _router.resolve_control_mode()
	var directional: Vector2 = Vector2.ZERO

	if effective_mode == Types.ControlMode.GYRO:
		_tilt.poll()
		directional = _tilt.tilt_vector
	elif _router.control_scheme == Types.ControlScheme.MOUSE and OS.has_feature("mobile"):
		# DIVERGENCE(M2.5 §8.3, D3): the joystick emits a normalised direction
		# with magnitude — the same shape as TiltInput.tilt_vector — so it
		# feeds the existing gyro branch at player_ship.gd:235. No value is
		# added to Types.ControlMode, a cited port of PlayerShip.ts:99, and no
		# ported movement code changes. The mode reads GYRO for the whole TOUCH
		# scheme, not merely while the joystick is active — otherwise lifting
		# the thumb fell back to resolve_control_mode()'s MOUSE branch, which
		# steers toward _router.mouse_pos, frozen at the arena centre because
		# mobile-TOUCH never feeds _touch.handle_event. _joystick.vector is
		# already Vector2.ZERO when idle, so the gyro branch's damping brings
		# the ship to rest instead. See M2.5 spec §8.3 for why this trade was
		# taken.
		effective_mode = Types.ControlMode.GYRO
		directional = _joystick.vector * TOUCH_JOYSTICK_SPEED_SCALE

	_run_controller.update(
		dt, effective_mode, _router.mouse_pos, _router.get_movement_vector(), directional
	)

	_entity_layer.set_elapsed(_run_controller.elapsed)
	_effect_layer.set_elapsed(_run_controller.elapsed)


## Switches the active control scheme and persists the choice.
# DIVERGENCE(M2.5 §4.2): no TypeScript counterpart — GameOptions.ts:80 fixes
# the scheme at construction and the web game has no in-game picker.
func set_control_scheme(scheme: Types.ControlScheme) -> void:
	settings.scheme = scheme
	settings.save_settings()
	_router.control_scheme = scheme

	# PORT: the sensor transition at game_state_machine.gd:125-128.
	if scheme == Types.ControlScheme.GYRO:
		_tilt.start_listening()
		_tilt.calibrate_current_position()
	else:
		_tilt.stop_listening()

	# A half-held input from the previous scheme must not leak into the new one.
	_router.clear_movement_keys()
	_joystick.reset()


## Toggles the paused phase. Delegates to the ported state machine.
func toggle_pause() -> void:
	_state.toggle_pause()


## True while the run is paused.
func is_paused() -> bool:
	return _state.phase == Types.GamePhase.PAUSED


## Restarts the run cleanly into playing state.
func restart_run() -> void:
	_tilt.calibrate_current_position()
	_joystick.reset()
	_state.phase = Types.GamePhase.PLAYING
	_run_controller.reset_run(_bounds)
	GameEvents.phase_changed.emit(Types.GamePhase.PLAYING)


## PORT: web/src/tilt-to-live/TiltGame.ts:2343-2350
func open_armory(tab: String = "") -> void:
	if _state.phase == Types.GamePhase.PLAYING:
		_state.phase = Types.GamePhase.PAUSED
		_hud.set_pause_panel_visible(false)
		# TODO(M5): audio.stopMusic() (:2347).
	_armory.open(tab)


## PORT: web/src/tilt-to-live/TiltGame.ts:2352-2354
func close_armory() -> void:
	_armory.close()


## True while the Armory overlay is up.
func is_armory_open() -> bool:
	return _armory.is_open()


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
	_effect_layer.set_elapsed(_state.elapsed)

	_grid_layer.set_arena_origin(arena_origin)
	_entity_layer.set_arena_origin(arena_origin)
	_effect_layer.set_arena_origin(arena_origin)
	_joystick_layer.set_arena_origin(arena_origin)

	# The Armory shares the HUD's ui_scale; on mobile its edge-to-edge panel is
	# inset by arena_origin so it stays inside the safe area (spec §8 M8).
	_armory.set_ui_scale(HudController.ui_scale_for(viewport))
	_armory.offset_left = arena_origin.x
	_armory.offset_top = arena_origin.y
	_armory.offset_right = -arena_origin.x
	_armory.offset_bottom = -arena_origin.y


## PORT: web/src/tilt-to-live/TiltGame.ts:2073 (triggerPlayerDeath's phase flip)
# PORT-NOTE: the TS sets this.phase = 'gameOver' inside triggerPlayerDeath, but
# the port put that method in the sim (run_controller.gd:266-278), which only
# emits GameEvents.run_ended and GameEvents.phase_changed(GAME_OVER) — a sim
# system may not hold GamePhase (spec §5.3, sim→game only via signals). The
# shell mirrors the sim's run_ended signal here instead.
func _on_run_ended(_final_score: int, _stats: Types.GameStats) -> void:
	_state.phase = Types.GamePhase.GAME_OVER


## handleProgressionChanged. PORT: web/src/tilt-to-live/TiltGame.ts:2356-2361
# PORT-NOTE: updateHUD (:2357) is signal-driven here and has nothing to
# refresh; goalsHUD.render (:2358) is M9's; menu.render (:2359) is M11's;
# updateCursor (:2360) has no pointer on Android. What a purchase does change
# on this platform is the equipped cosmetics the layers draw.
func _on_armory_state_changed() -> void:
	_apply_equipped_cosmetics()


## handleArmoryClosed. PORT: web/src/tilt-to-live/TiltGame.ts:2379-2385
func _on_armory_closed() -> void:
	if _state.phase == Types.GamePhase.PAUSED:
		_hud.set_pause_panel_visible(true)
	# TODO(M9): goalsHUD.render (:2383). TODO(M11): menu.render (:2384).
	_apply_equipped_cosmetics()


## PORT: web/src/tilt-to-live/TiltGame.ts:2310-2312 — the render call reads the
## equipped cursor/ship, enemy skin and arena theme every frame.
# PORT-NOTE: pushed into the layers on boot and after each Armory change
# instead of read per frame: equipping happens nowhere else, and the layers
# never hold a ProgressionManager (spec §5.2 keeps them dumb). The menu
# backdrop (M11) passes null for all three (:2274-2276).
func _apply_equipped_cosmetics() -> void:
	_entity_layer.set_ship_skin(progression.get_equipped_ship())
	_entity_layer.set_enemy_skin(progression.get_equipped_enemy_skin())
	_grid_layer.set_arena_theme(progression.get_equipped_arena_theme())
