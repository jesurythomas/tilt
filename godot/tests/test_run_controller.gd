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
var _progression: ProgressionManager
var _options: GameOptionsManager
var _coins: CoinSystem
var _rc: RunController
var _bounds: Vector2 = Vector2(1000.0, 600.0)


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))
	_remove(GameOptionsManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GameOptionsManager.SAVE_PATH))
	_player = PlayerShip.new(_bounds.x * 0.5, _bounds.y * 0.5)
	_swarm = EnemySwarm.new()
	_weapons = WeaponSystem.new()
	_particles = ParticleEngine.new()
	_grid = VectorGrid.new(int(_bounds.x), int(_bounds.y))
	_scores = ScoreManager.new()
	_audio = AudioBank.new()
	_progression = ProgressionManager.new()
	_options = GameOptionsManager.new()
	_coins = CoinSystem.new()
	_rc = RunController.new(
		_player,
		_swarm,
		_weapons,
		_particles,
		_grid,
		_scores,
		_audio,
		_progression,
		_options,
		_coins
	)


func after_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))
	_remove(GameOptionsManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GameOptionsManager.SAVE_PATH))


func test_reset_run_initializes_state_and_spawns_orb() -> void:
	_rc.reset_run(_bounds)
	assert_true(_rc.is_run_active, "run should be active")
	assert_eq(_rc.lives, 1, "lives should match max_lives")
	assert_eq(_player.x, _bounds.x * 0.5)
	assert_eq(_player.y, _bounds.y * 0.5)
	assert_eq(_weapons.orbs.size(), 1, "starting weapon orb must spawn")
	assert_eq(
		_weapons.orbs[0].type,
		Types.WeaponType.SHIELD,
		"the classic ship's startingWeapon (ProgressionManager.ts:138, TiltGame.ts:1965)"
	)


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


func test_collecting_an_orb_emits_weapon_activated() -> void:
	_rc.reset_run(_bounds)
	_weapons.orbs.clear()
	_weapons.spawn_orb(_bounds, Types.WeaponType.LASER, _player.x, _player.y)
	watch_signals(GameEvents)
	_rc.update(
		0.016, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
	)
	assert_signal_emitted_with_parameters(GameEvents, "weapon_activated", [Types.WeaponType.LASER])
	assert_eq(_weapons.active_weapons.size(), 1, "the laser is live")


func test_shield_radius_follows_the_perk_rank_at_run_start() -> void:
	_rc.reset_run(_bounds)
	assert_almost_eq(_player.shield_radius, Tuning.get_tuned_value("shield", "radius", 0), 0.001)
	assert_almost_eq(_player.shield_radius, 20.0, 0.001, "TiltGame.ts:1572-1574 at rank 0")
	_progression.data.perks.shield.radius = 3
	_rc.reset_run(_bounds)
	assert_almost_eq(_player.shield_radius, 26.0, 0.001, "20 + 3 * 2")


func test_perk_ranks_reach_the_weapon_system_through_update() -> void:
	_rc.reset_run(_bounds)
	_progression.data.perks.nuke.radius = 5
	_weapons.orbs.clear()
	_weapons.spawn_orb(_bounds, Types.WeaponType.NUKE, _player.x, _player.y)
	_rc.update(
		0.016, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
	)
	assert_eq(_weapons.active_weapons.size(), 1)
	assert_almost_eq(
		_weapons.active_weapons[0].max_radius, 470.0, 0.001, "rank 5 reached activate_weapon"
	)


func test_reset_run_takes_lives_and_multipliers_from_progression() -> void:
	_progression.data.extra_lives = 1
	_progression.data.hull_compact = 2
	_progression.data.enemy_slow = 3
	_progression.data.score_multiplier = 4
	var radius_before: float = _player.radius
	_rc.reset_run(_bounds)
	assert_eq(_rc.max_lives, 2, "getStartingLives (TiltGame.ts:1567)")
	assert_eq(_rc.lives, 2, ":1568")
	assert_almost_eq(_player.radius, radius_before * 0.88, 0.0001, "setHitboxMultiplier (:1570)")
	assert_almost_eq(_swarm.speed_scale, 0.88, 0.0001, "setSpeedScale (:1599)")
	assert_almost_eq(
		_scores.progression_multiplier, 1.4, 0.0001, "setProgressionMultiplier (:1551)"
	)
	assert_almost_eq(_scores.mode_multiplier, 1.0, 0.0001, "classic mode (:1550)")


func test_reset_run_resets_the_coins() -> void:
	var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	coin.lifetime = 5.0
	_coins.coins.append(coin)
	_coins.coins_collected = 3
	_rc.reset_run(_bounds)
	assert_eq(_coins.coins.size(), 0, "coins.reset() (TiltGame.ts:1601)")
	assert_eq(_coins.coins_collected, 0)


func test_starting_orb_is_the_equipped_ships_weapon() -> void:
	_progression.equip_ship("tactical")
	_rc.reset_run(_bounds)
	assert_eq(_weapons.orbs.size(), 1)
	assert_eq(_weapons.orbs[0].type, Types.WeaponType.MISSILES, "the Viper's startingWeapon (:159)")


func test_coins_update_at_step_seven_and_credit_progression() -> void:
	_rc.reset_run(_bounds)
	var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	coin.id = 1
	coin.x = _player.x
	coin.y = _player.y
	coin.radius = CoinSystem.COIN_RADIUS
	coin.lifetime = 10.0
	coin.max_lifetime = CoinSystem.COIN_LIFETIME
	_coins.coins.append(coin)
	var points_before: int = _progression.data.points
	_rc.update(
		0.016, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
	)
	assert_eq(_coins.coins.size(), 0, "picked up")
	assert_eq(_coins.coins_collected, 1)
	assert_eq(_progression.data.points, points_before + 25, "addPointsCredited (TiltGame.ts:1939)")
	assert_eq(_coins.points_from_coins, 25)


func test_coin_value_uses_the_points_multiplier_only_through_the_callback() -> void:
	_progression.data.points_multiplier = 2
	_rc.reset_run(_bounds)
	var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	coin.x = _player.x
	coin.y = _player.y
	coin.radius = CoinSystem.COIN_RADIUS
	coin.lifetime = 10.0
	_coins.coins.append(coin)
	var points_before: int = _progression.data.points
	_rc.update(
		0.016, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
	)
	assert_eq(
		_progression.data.points, points_before + 30, "floor(25 * 1.2) — applied once (:1939)"
	)
	assert_eq(_coins.points_from_coins, 30, "the credited figure, not the base value")


func test_player_update_reads_tuning_and_the_equipped_ship() -> void:
	_progression.data.points = 100000
	_progression.buy_ship("solar")
	_rc.reset_run(_bounds)
	var classic_radius: float = 9.0 * _player.scale
	_rc.update(
		0.016, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
	)
	assert_almost_eq(
		_player.radius, classic_radius * 1.90, 0.0001, "the Aegis hitboxScale (:199) via :1889"
	)
