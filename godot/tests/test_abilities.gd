## test_abilities.gd
## PORTS: nothing — new file, covers src/sim/ability_system.gd and its RunController wiring
## (rulings DASH R1-R4, ITEM R1; plan docs/superpowers/plans/2026-10-14-dash-and-abilities.md)
extends GutTest
## Proves the dash (ready at the start, a quarter of the arena, the shield, the cooldown that
## waits for the shield window, no buffering, walls) and the item slots (once a run, reset at
## the next), alone and inside a run.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const DT: float = 1.0 / 120.0

var _abilities: AbilitySystem = null
var _player: PlayerShip = null
var _particles: ParticleEngine = null
var _grid: VectorGrid = null
var _audio: SpyAudioBank = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_abilities = AbilitySystem.new()
	_abilities.reset(20.0, 2.0, [])
	_player = PlayerShip.new(BOUNDS.x * 0.5, BOUNDS.y * 0.5)
	_particles = ParticleEngine.new()
	_grid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	_audio = SpyAudioBank.new()


func after_each() -> void:
	for path: String in [
		ProgressionManager.SAVE_PATH,
		GameOptionsManager.SAVE_PATH,
		ScoreManager.BEST_SCORE_PATH,
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
	]:
		_remove(path)


## Runs the dash for `seconds` of ticks; returns how many ticks started a dash.
func _tick(seconds: float, maze: GauntletMaze = null) -> int:
	var started: int = 0
	for i: int in range(roundi(seconds / DT)):
		if _abilities.update_dash(DT, _player, BOUNDS, maze, _particles, _grid, _audio):
			started += 1
	return started


func test_the_dash_is_ready_at_the_start() -> void:
	assert_true(_abilities.is_dash_ready())
	assert_eq(_abilities.dash_state(), AbilitySystem.DashState.READY)
	assert_almost_eq(_abilities.dash_fraction(), 1.0, 0.0001)


func test_a_moving_ship_dashes_a_quarter_of_the_width_ahead() -> void:
	_player.vx = 300.0
	_abilities.request_dash()
	assert_eq(_tick(AbilitySystem.DASH_SECONDS + 0.05), 1)
	assert_almost_eq(_player.x, BOUNDS.x * 0.5 + BOUNDS.x * 0.25, 0.5, "user: 1/4 of the screen")
	assert_almost_eq(_player.y, BOUNDS.y * 0.5, 0.5)
	assert_almost_eq(_player.angle, 0.0, 0.0001, "faces the dash")
	assert_true(_player.vx > 0.0, "leaves the burst moving the same way")


func test_a_still_ship_dashes_where_it_faces_and_a_quarter_of_the_height_up() -> void:
	_player.angle = -PI / 2.0
	_abilities.request_dash()
	_tick(AbilitySystem.DASH_SECONDS + 0.05)
	assert_almost_eq(_player.y, BOUNDS.y * 0.5 - BOUNDS.y * 0.25, 0.5)
	assert_almost_eq(_player.x, BOUNDS.x * 0.5, 0.5)


func test_dash_distance_is_a_quarter_along_the_direction() -> void:
	var diagonal: Vector2 = Vector2(1.0, 1.0).normalized()
	assert_almost_eq(
		AbilitySystem.dash_distance(diagonal, BOUNDS),
		0.25 * Vector2(BOUNDS.x * diagonal.x, BOUNDS.y * diagonal.y).length(),
		0.0001
	)
	assert_almost_eq(AbilitySystem.dash_distance(Vector2.RIGHT, BOUNDS), 250.0, 0.0001)
	assert_almost_eq(AbilitySystem.dash_distance(Vector2.UP, BOUNDS), 150.0, 0.0001)


func test_the_dash_shields_the_ship_for_two_seconds() -> void:
	_abilities.request_dash()
	_tick(DT)
	assert_true(_player.has_shield(), "user: shielded for 2 seconds")
	assert_almost_eq(_player.shield_timer, 2.0, 0.0001)
	assert_eq(_abilities.dash_state(), AbilitySystem.DashState.SHIELD)


func test_the_cooldown_starts_when_the_shield_window_ends() -> void:
	_abilities.request_dash()
	_tick(1.9)
	assert_eq(_abilities.dash_state(), AbilitySystem.DashState.SHIELD, "still shielded at 1.9 s")
	assert_almost_eq(_abilities.dash_cooldown_left, 0.0, 0.0001, "no cooldown yet")
	_tick(0.2)
	assert_eq(_abilities.dash_state(), AbilitySystem.DashState.COOLDOWN)
	assert_almost_eq(_abilities.dash_cooldown_left, 20.0, 0.1, "user: after the shield expires")
	_tick(19.8)
	assert_false(_abilities.is_dash_ready())
	_tick(0.3)
	assert_true(_abilities.is_dash_ready(), "ready 2 + 20 s after the dash")


func test_a_request_while_cooling_is_dropped_not_buffered() -> void:
	_abilities.request_dash()
	_tick(DT)
	_abilities.request_dash()
	assert_eq(_tick(23.0), 0, "the second request never fires")
	assert_true(_abilities.is_dash_ready())
	_abilities.request_dash()
	assert_eq(_tick(DT), 1)
	assert_eq(_abilities.dashes, 2)


func test_upgrades_set_the_cooldown_and_shield() -> void:
	_abilities.reset(15.0, 5.0, [])
	_abilities.request_dash()
	_tick(DT)
	assert_almost_eq(_player.shield_timer, 5.0, 0.0001)
	_tick(5.0)
	assert_almost_eq(_abilities.dash_cooldown_left, 15.0, 0.1)


func test_a_longer_power_up_shield_is_not_cut_and_does_not_delay_the_cooldown() -> void:
	_player.activate_shield(6.0)
	_abilities.request_dash()
	_tick(DT)
	assert_almost_eq(_player.shield_timer, 6.0, 0.0001, "activate_shield keeps the longer one")
	_tick(2.1)
	assert_eq(
		_abilities.dash_state(), AbilitySystem.DashState.COOLDOWN, "the dash's own window ended"
	)


func test_the_dash_stops_at_the_arena_edge() -> void:
	_player.x = BOUNDS.x - 60.0
	_player.vx = 300.0
	_abilities.request_dash()
	_tick(0.3)
	assert_almost_eq(_player.x, BOUNDS.x - _player.radius - AbilitySystem.WALL_PAD, 0.001)


func test_the_dash_stops_short_of_a_gauntlet_wall() -> void:
	var maze: GauntletMaze = GauntletMaze.new()
	var row: GauntletMaze.GauntletWallRow = GauntletMaze.GauntletWallRow.new()
	row.y = BOUNDS.y * 0.5 - 40.0
	row.height = 80.0
	var seg: GauntletMaze.WallSegment = GauntletMaze.WallSegment.new()
	seg.x = BOUNDS.x * 0.5 + 100.0
	seg.width = 40.0
	row.segments = [seg]
	maze.rows = [row]
	_player.vx = 300.0
	_abilities.request_dash()
	_tick(0.3, maze)
	assert_true(_player.x + _player.radius <= seg.x, "never inside the wall")
	assert_true(_player.x > BOUNDS.x * 0.5 + 60.0, "but went up to it")
	assert_false(maze.blocks(_player.x, _player.y, _player.radius))


func test_a_dash_sounds_and_signals() -> void:
	watch_signals(GameEvents)
	_abilities.request_dash()
	_tick(DT)
	assert_signal_emitted(GameEvents, "dash_activated")
	assert_true(_audio.requested.has("warp_in"))


func test_a_dead_ship_cannot_dash() -> void:
	_player.is_dead = true
	_abilities.request_dash()
	assert_eq(_tick(DT), 0)
	assert_true(_abilities.is_dash_ready())


func test_items_map_to_power_ups_two_at_most() -> void:
	_abilities.reset(20.0, 2.0, ["blackhole", "ghost", "nuke", "shield"])
	assert_eq(
		_abilities.item_types,
		[Types.WeaponType.VORTEX, Types.WeaponType.NUKE] as Array[Types.WeaponType]
	)
	assert_eq(_abilities.item_used, [false, false] as Array[bool])


func test_an_item_fires_once_a_run() -> void:
	_abilities.reset(20.0, 2.0, ["laser", "freeze"])
	_abilities.request_item(1)
	_abilities.request_item(1)
	assert_eq(_abilities.take_item_requests(), [Types.WeaponType.FREEZE] as Array[Types.WeaponType])
	assert_false(_abilities.is_item_ready(1))
	assert_true(_abilities.is_item_ready(0))
	_abilities.request_item(1)
	_abilities.request_item(5)
	assert_eq(_abilities.take_item_requests(), [] as Array[Types.WeaponType], "used, or no slot")
	_abilities.reset(20.0, 2.0, ["laser", "freeze"])
	assert_true(_abilities.is_item_ready(1), "user: only resets during a new run")


func _run_controller() -> RunController:
	for path: String in [
		ProgressionManager.SAVE_PATH,
		GameOptionsManager.SAVE_PATH,
		ScoreManager.BEST_SCORE_PATH,
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
	]:
		_remove(path)
	var progression: ProgressionManager = ProgressionManager.new()
	var rc: RunController = RunController.new(
		_player,
		EnemySwarm.new(),
		WeaponSystem.new(),
		_particles,
		_grid,
		ScoreManager.new(),
		_audio,
		progression,
		GameOptionsManager.new(),
		CoinSystem.new()
	)
	rc.goals = GoalManager.new(progression)
	rc.maze = GauntletMaze.new()
	return rc


func test_a_run_reads_the_upgrades_and_loadout() -> void:
	var rc: RunController = _run_controller()
	rc.progression.data.points = 100000
	rc.progression.buy_dash_cooldown()
	rc.progression.buy_dash_shield()
	rc.progression.buy_item("nuke")
	rc.reset_run(BOUNDS)
	assert_almost_eq(rc.abilities.dash_cooldown, 19.0, 0.0001)
	assert_almost_eq(rc.abilities.dash_shield, 2.5, 0.0001)
	assert_eq(rc.abilities.item_types, [Types.WeaponType.NUKE] as Array[Types.WeaponType])
	assert_true(rc.abilities.is_dash_ready(), "ready at every run start")


func test_an_item_in_a_run_fires_its_power_up_like_a_pickup() -> void:
	var rc: RunController = _run_controller()
	rc.progression.data.points = 100000
	rc.progression.buy_item("nuke")
	rc.reset_run(BOUNDS)
	rc.swarm.enemies.clear()
	watch_signals(GameEvents)
	rc.abilities.request_item(0)
	rc.update(
		DT, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
	)
	assert_eq(rc.weapons.active_weapons.size(), 1)
	assert_eq(rc.weapons.active_weapons[0].type, Types.WeaponType.NUKE)
	assert_eq(rc.run_tracker.nukes_detonated, 1, "counts for milestones")
	assert_signal_emitted_with_parameters(GameEvents, "weapon_activated", [Types.WeaponType.NUKE])
	assert_false(_audio.requested.has("orb_pickup"), "no pickup chime")
	assert_false(rc.abilities.is_item_ready(0))


func test_a_dash_in_a_run_rams_a_dot_on_its_path() -> void:
	var rc: RunController = _run_controller()
	rc.reset_run(BOUNDS)
	rc.swarm.enemies.clear()
	rc.swarm.spawn_seeker(BOUNDS, BOUNDS.x * 0.5 + 120.0, BOUNDS.y * 0.5)
	_player.vx = 300.0
	rc.abilities.request_dash()
	for i: int in range(roundi(AbilitySystem.DASH_SECONDS / DT) + 2):
		rc.update(
			DT, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
		)
	assert_eq(rc.swarm.enemies.size(), 0, "the dash shield rams it")
	assert_eq(rc.lives, 1, "no life lost")
	assert_eq(rc.run_tracker.shield_rams, 1)
