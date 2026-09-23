## test_game_state_machine.gd
## PORTS: nothing — new file, covers src/core/game_state_machine.gd
extends GutTest
## Covers the menu/playing/paused transitions M1 owns.

const BOUNDS: Vector2 = Vector2(1280.0, 720.0)

var _player: PlayerShip = null
var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _router: InputRouter = null
var _tilt: TiltInput = null
var _machine: GameStateMachine = null


func before_each() -> void:
	_player = PlayerShip.new(0.0, 0.0)
	_grid = VectorGrid.new(BOUNDS.x, BOUNDS.y)
	_particles = ParticleEngine.new()
	_router = InputRouter.new()
	_tilt = TiltInput.new()
	_machine = GameStateMachine.new(_player, _grid, _particles, _router, _tilt)
	_machine.set_bounds(BOUNDS)


func test_start_enters_the_menu() -> void:
	_machine.start()
	assert_eq(_machine.phase, Types.GamePhase.MENU, "TiltGame.ts:1476")


func test_reset_run_centres_the_ship_and_enters_playing() -> void:
	_machine.reset_run(Types.GameMode.CLASSIC)
	assert_eq(_machine.phase, Types.GamePhase.PLAYING, "TiltGame.ts:1562")
	assert_almost_eq(_player.x, 640.0, 0.0001, "TiltGame.ts:1593 centres the ship")
	assert_almost_eq(_player.y, 360.0, 0.0001, "TiltGame.ts:1593 centres the ship")
	assert_eq(_router.mouse_pos, Vector2(640.0, 360.0), "TiltGame.ts:1594")
	assert_eq(_router.control_mode, Types.ControlMode.MOUSE, "TiltGame.ts:1596")
	assert_almost_eq(_machine.elapsed, 0.0, 0.0001, "TiltGame.ts:1564")


func test_reset_run_starts_the_tilt_sensor_only_under_the_gyro_scheme() -> void:
	_router.control_scheme = Types.ControlScheme.GYRO
	_machine.reset_run(Types.GameMode.CLASSIC)
	assert_true(_tilt.is_listening, "TiltGame.ts:1553-1554")
	_router.control_scheme = Types.ControlScheme.HYBRID
	_machine.reset_run(Types.GameMode.CLASSIC)
	assert_false(_tilt.is_listening, "TiltGame.ts:1555-1556")


func test_toggle_pause_round_trips_between_playing_and_paused() -> void:
	_machine.reset_run(Types.GameMode.CLASSIC)
	_machine.toggle_pause()
	assert_eq(_machine.phase, Types.GamePhase.PAUSED, "TiltGame.ts:1621")
	_machine.toggle_pause()
	assert_eq(_machine.phase, Types.GamePhase.PLAYING, "TiltGame.ts:1636")


func test_toggle_pause_does_nothing_in_the_menu() -> void:
	_machine.start()
	_machine.toggle_pause()
	assert_eq(_machine.phase, Types.GamePhase.MENU, "only playing/paused toggle")


func test_return_to_menu_from_a_run_clears_input_and_stops_the_sensor() -> void:
	_router.control_scheme = Types.ControlScheme.GYRO
	_machine.reset_run(Types.GameMode.CLASSIC)
	_router.press_movement_key(Types.MoveDirection.UP)
	_machine.return_to_menu()
	assert_eq(_machine.phase, Types.GamePhase.MENU, "TiltGame.ts:1498")
	assert_false(_router.has_active_movement_keys(), "TiltGame.ts:1499")
	assert_false(_tilt.is_listening, "TiltGame.ts:1500")


func test_return_to_menu_is_a_no_op_when_already_in_the_menu() -> void:
	_machine.start()
	_machine.elapsed = 5.0
	_machine.return_to_menu()
	assert_almost_eq(_machine.elapsed, 5.0, 0.0001, "TiltGame.ts:1497 early-returns")


func test_format_time_pads_seconds() -> void:
	assert_eq(GameStateMachine.format_time(65.0), "1:05", "TiltGame.ts:1644-1648")
	assert_eq(GameStateMachine.format_time(9.9), "0:09", "TiltGame.ts:1644-1648")
