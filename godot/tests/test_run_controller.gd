## test_run_controller.gd
## Unit tests for in-run coordinator RunController.
extends GutTest

var _player: PlayerShip
var _swarm: EnemySwarm
var _weapons: WeaponSystem
var _particles: ParticleEngine
var _grid: VectorGrid
var _scores: ScoreManager
var _audio: AudioBank
var _rc: RunController
var _bounds: Vector2 = Vector2(1000.0, 600.0)


func before_each() -> void:
	_player = PlayerShip.new(_bounds.x * 0.5, _bounds.y * 0.5)
	_swarm = EnemySwarm.new()
	_weapons = WeaponSystem.new()
	_particles = ParticleEngine.new()
	_grid = VectorGrid.new(int(_bounds.x), int(_bounds.y))
	_scores = ScoreManager.new()
	_audio = AudioBank.new()
	_rc = RunController.new(_player, _swarm, _weapons, _particles, _grid, _scores, _audio)


func test_reset_run_initializes_state_and_spawns_orb() -> void:
	_rc.reset_run(_bounds)
	assert_true(_rc.is_run_active, "run should be active")
	assert_eq(_rc.lives, 1, "lives should match max_lives")
	assert_eq(_player.x, _bounds.x * 0.5)
	assert_eq(_player.y, _bounds.y * 0.5)
	assert_eq(_weapons.orbs.size(), 1, "starting weapon orb must spawn")
	assert_eq(_weapons.orbs[0].type, Types.WeaponType.NUKE)


func test_update_advances_simulation_systems() -> void:
	_rc.reset_run(_bounds)
	_rc.update(0.016, Types.ControlMode.KEYBOARD, Vector2.ZERO, Vector2(1.0, 0.0), Vector2.ZERO)
	assert_almost_eq(_rc.elapsed, 0.016, 0.001)


func test_collision_with_enemy_triggers_death_when_single_life() -> void:
	_rc.reset_run(_bounds)
	var e: Types.Enemy = _swarm.spawn_seeker(_bounds, _player.x, _player.y)
	assert_not_null(e)

	_rc.check_collisions()
	assert_true(_player.is_dead, "player must die on enemy collision")
	assert_false(_rc.is_run_active, "run must become inactive")
	assert_eq(_rc.lives, 0, "lives must be zero")


func test_collision_with_shield_destroys_enemy() -> void:
	_rc.reset_run(_bounds)
	_player.activate_shield(3.0)
	var e: Types.Enemy = _swarm.spawn_seeker(_bounds, _player.x, _player.y)
	assert_not_null(e)
	assert_eq(_swarm.enemies.size(), 1)

	_rc.check_collisions()
	assert_false(_player.is_dead, "player protected by shield")
	assert_eq(_swarm.enemies.size(), 0, "enemy destroyed by shield ram")
	assert_eq(_scores.stats.kills, 1, "kill awarded for shield ram")


func test_close_call_registers_bonus() -> void:
	_rc.reset_run(_bounds)
	var e: Types.Enemy = _swarm.spawn_seeker(_bounds, _player.x + _player.radius + 18.0, _player.y)
	assert_not_null(e)

	_rc.check_collisions()
	assert_false(_player.is_dead)
	assert_eq(_scores.stats.close_calls, 1, "close call recorded")
	assert_almost_eq(_player.close_call_timer, 0.75, 0.01)
