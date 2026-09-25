# gdlint:disable=max-public-methods
## test_run_controller.gd
## Unit tests for in-run coordinator RunController.
extends GutTest

const TICK: float = 0.75 / 120.0  # Tuning.GAME_SPEED at 120 Hz (spec §4.3 D8)

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
var _maze: GauntletMaze
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
	_remove(GoalManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH))
	_remove(GoalManager.CUMULATIVE_SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.CUMULATIVE_SAVE_PATH))
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
	_rc.goals = GoalManager.new(_progression)
	_maze = GauntletMaze.new()
	_rc.maze = _maze


func after_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))
	_remove(GameOptionsManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GameOptionsManager.SAVE_PATH))
	_remove(GoalManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH))
	_remove(GoalManager.CUMULATIVE_SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.CUMULATIVE_SAVE_PATH))


func test_reset_run_initializes_state() -> void:
	_rc.reset_run(_bounds)
	assert_true(_rc.is_run_active, "run should be active")
	assert_eq(_rc.lives, 1, "lives should match max_lives")
	assert_eq(_player.x, _bounds.x * 0.5)
	assert_eq(_player.y, _bounds.y * 0.5)
	assert_eq(
		_weapons.orbs.size(), 0, "the starting orb waits for the cinematic (TiltGame.ts:173-176)"
	)


func test_finish_cinematic_spawns_the_starting_orb() -> void:
	_rc.reset_run(_bounds)
	_rc.finish_cinematic(_bounds)
	assert_eq(_weapons.orbs.size(), 1, "TiltGame.ts:176")
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
	_rc.finish_cinematic(_bounds)  # M11b: the starting orb now spawns at the cinematic's end
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


func test_reset_run_starts_a_fresh_tracker_in_the_active_mode() -> void:
	_rc.run_tracker.kills = 9
	_rc.points_earned_this_run = 4
	_options.settings.mode = Types.GameMode.CODE_RED
	_rc.reset_run(_bounds)
	assert_eq(_rc.run_tracker.kills, 0, "TiltGame.ts:1578-1591")
	assert_eq(_rc.run_tracker.multiplier, 1.0)
	assert_eq(_rc.run_tracker.mode, "code-red", "options.settings.mode (:1579)")
	assert_eq(_rc.points_earned_this_run, 0, ":1566")


func test_weapon_kills_bump_their_tracker_counters() -> void:
	_rc.reset_run(_bounds)
	var kinds: Array[Types.WeaponType] = [
		Types.WeaponType.VORTEX,
		Types.WeaponType.LASER,
		Types.WeaponType.MISSILES,
		Types.WeaponType.FREEZE,
		Types.WeaponType.SHIELD,
		Types.WeaponType.NUKE,
		Types.WeaponType.LIGHTNING,
	]
	for kind: Types.WeaponType in kinds:
		var e: Types.Enemy = Types.Enemy.new()
		e.x = 100.0
		e.y = 100.0
		_rc.handle_enemy_killed(e, kind)
	var t: GoalManager.RunTracker = _rc.run_tracker
	assert_eq(t.vortex_absorbs, 1, "TiltGame.ts:1988-1990")
	assert_eq(t.laser_slices, 1, ":1991-1993")
	assert_eq(t.missiles_fired, 1, ":1994-1996")
	assert_eq(t.freeze_shatters, 1, ":1997-1999")
	assert_eq(t.shield_rams, 1, ":2000-2002")
	assert_eq(t.nukes_detonated, 0, "nuke kills are not counted — only activations")


func test_weapon_activation_counts_nukes_and_sixteen_missiles() -> void:
	_rc.reset_run(_bounds)
	_weapons.on_weapon_activated.call(Types.WeaponType.NUKE)
	_weapons.on_weapon_activated.call(Types.WeaponType.MISSILES)
	_weapons.on_weapon_activated.call(Types.WeaponType.LASER)
	assert_eq(_rc.run_tracker.nukes_detonated, 1, "TiltGame.ts:213-214")
	assert_eq(_rc.run_tracker.missiles_fired, 16, "a fixed 16 per pickup (:216)")


func test_update_syncs_the_tracker_from_scores_and_elapsed() -> void:
	_rc.reset_run(_bounds)
	_scores.stats.score = 1234
	_scores.stats.kills = 7
	_rc.update(1.0 / 120.0, Types.ControlMode.MOUSE, Vector2(200, 200), Vector2.ZERO, Vector2.ZERO)
	assert_eq(_rc.run_tracker.score, _scores.stats.score, "TiltGame.ts:1949")
	assert_eq(_rc.run_tracker.kills, _scores.stats.kills, ":1950")
	assert_eq(_rc.run_tracker.multiplier, _scores.stats.multiplier, ":1951")
	assert_eq(_rc.run_tracker.survival_time, _rc.elapsed, ":1952")
	assert_eq(_rc.run_tracker.close_calls, _scores.stats.close_calls, ":1953")


func test_update_completes_live_total_goals() -> void:
	_rc.reset_run(_bounds)
	_rc.goals.cumulative.total_kills = 99
	_scores.stats.kills = 1
	_rc.update(1.0 / 120.0, Types.ControlMode.MOUSE, Vector2(200, 200), Vector2.ZERO, Vector2.ZERO)
	assert_true(_rc.goals.is_completed("total_kills_100"), "TiltGame.ts:1954 → GoalsHUD.ts:244")


func test_death_evaluates_the_run_and_keeps_the_result() -> void:
	_rc.reset_run(_bounds)
	_rc.run_tracker.score = 1000
	_rc.trigger_player_death()
	var ids: Array[String] = []
	for g: GoalManager.Goal in _rc.run_completed_goals:
		ids.append(g.id)
	assert_eq(ids, ["score_1k"] as Array[String], "TiltGame.ts:2086")
	assert_true(_rc.goals.is_completed("score_1k"))


func _tick() -> void:
	_rc.update(
		TICK, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
	)


func test_reset_run_captures_the_saved_mode() -> void:
	_options.set_mode(Types.GameMode.GAUNTLET)
	_rc.reset_run(_bounds)
	assert_eq(_rc.mode, Types.GameMode.GAUNTLET, "M10 R4")
	assert_almost_eq(_scores.mode_multiplier, 1.25, 0.0001, "TiltGame.ts:1549-1550")
	assert_eq(_rc.run_tracker.mode, "gauntlet", ":1579")
	assert_eq(_maze.rows.size(), 4, "gauntletMaze.reset (:1604)")


func test_mode_change_waits_for_the_next_reset() -> void:
	_rc.reset_run(_bounds)
	_options.set_mode(Types.GameMode.CODE_RED)
	_tick()
	assert_eq(_rc.mode, Types.GameMode.CLASSIC, "a Pause pick never changes the running run (R1)")
	assert_almost_eq(_scores.mode_multiplier, 1.0, 0.0001)
	_rc.reset_run(_bounds)
	assert_eq(_rc.mode, Types.GameMode.CODE_RED)
	assert_almost_eq(_scores.mode_multiplier, 1.5, 0.0001)


func test_gauntlet_tick_scrolls_the_maze_and_classic_does_not() -> void:
	_rc.reset_run(_bounds)
	var classic_y: float = _maze.rows[0].y
	_tick()
	assert_almost_eq(_maze.rows[0].y, classic_y, 0.0001, "maze only updates in gauntlet (:1894)")
	_options.set_mode(Types.GameMode.GAUNTLET)
	_rc.reset_run(_bounds)
	var gauntlet_y: float = _maze.rows[0].y
	_tick()
	assert_gt(_maze.rows[0].y, gauntlet_y, "step 4 scrolls the walls (spec §5.4)")


func test_gauntlet_scores_survival_each_tick() -> void:
	_options.set_mode(Types.GameMode.GAUNTLET)
	_rc.reset_run(_bounds)
	_tick()
	# round(250 * 0.00625 * 1.25 * 1.0) = round(1.953) (ScoreManager.ts:68)
	assert_eq(_scores.stats.score, 2, "scores.update receives the mode")
	_options.set_mode(Types.GameMode.CLASSIC)
	_rc.reset_run(_bounds)
	_tick()
	assert_eq(_scores.stats.score, 0, "no survival tick in classic")


func test_mode_multiplier_scales_kill_score() -> void:
	_options.set_mode(Types.GameMode.CODE_RED)
	_rc.reset_run(_bounds)
	var enemy: Types.Enemy = _swarm.spawn_seeker(_bounds, 100.0, 100.0)
	_rc.handle_enemy_killed(enemy, Types.WeaponType.NUKE)
	# round(10 * 1 * 1.5 * 1.0) (ScoreManager.ts register_kill; score_manager.gd:119)
	assert_eq(_scores.stats.score, 15)


func test_maze_crush_costs_one_life() -> void:
	_options.set_mode(Types.GameMode.GAUNTLET)
	_rc.reset_run(_bounds)
	_rc.lives = 2
	_rc.max_lives = 2
	# A 40-px wall across the arena floor with the ship inside it.
	var row: GauntletMaze.GauntletWallRow = GauntletMaze.GauntletWallRow.new()
	row.y = _bounds.y - 40.0
	row.height = 40.0
	row.segments = [GauntletMaze.WallSegment.new(0.0, _bounds.x)]
	row.gaps = [GauntletMaze.MazeGap.new(0.0, 0.0)]
	_maze.rows = [row]
	_player.x = _bounds.x * 0.5
	_player.y = _bounds.y - 10.0
	_tick()
	assert_eq(_rc.lives, 1, "the crush callback is lose_life (TiltGame.ts:1902)")
	assert_true(_player.has_shield(), "the post-hit shield (:2064)")
	_tick()
	assert_eq(_rc.lives, 1, "the shield guards the every-tick crush (:2052-2055)")


func test_reset_run_rebuilds_the_maze() -> void:
	_options.set_mode(Types.GameMode.GAUNTLET)
	_rc.reset_run(_bounds)
	for i: int in range(240):
		_tick()
	_rc.reset_run(_bounds)
	assert_eq(_maze.rows.size(), 4)
	assert_eq(_maze.rows[0].id, 1)
	assert_almost_eq(_maze.rows[0].y, 0.0, 0.0001)


func test_run_result_names_the_runs_mode() -> void:
	_options.set_mode(Types.GameMode.GAUNTLET)
	_rc.reset_run(_bounds)
	_options.set_mode(Types.GameMode.CODE_RED)
	var result: RunOverSheet.RunResult = HudController.run_result_for(0, _scores.stats, _rc)
	assert_eq(result.mode_name, "Gauntlet", "the run's mode, not the pending pick (R4)")
	assert_almost_eq(result.mode_multiplier, 1.25, 0.0001)


func test_reset_run_applies_the_sound_options() -> void:
	_options.settings.sfx_enabled = false
	_options.settings.sfx_volume = 0.4
	_options.settings.music_volume = 0.5
	_rc.reset_run(_bounds)
	assert_true(_audio.is_muted(), "setMuted(!sfxEnabled) (TiltGame.ts:1608)")
	assert_almost_eq(_audio._sfx_volume, 0.4, 0.0001, "setSfxVolume (:1609)")
	assert_almost_eq(_audio.music_gain, 0.175, 0.0001, "setMusicVolume: 0.5 * 0.35 (:1610)")
	_options.settings.sfx_enabled = true
	_rc.reset_run(_bounds)
	assert_false(_audio.is_muted(), "Retry re-applies the switch (M5 R11)")


func test_losing_a_life_shakes_by_14_times_the_option() -> void:
	_rc.reset_run(_bounds)
	var amounts: Array[float] = []
	_rc.trigger_shake = func(amount: float) -> void: amounts.append(amount)
	_options.settings.screen_shake = GameOptionsManager.ScreenShake.LOW
	_rc.lives = 3
	_rc.lose_life()
	assert_eq(amounts, [7.0] as Array[float], "14 x 0.5 (TiltGame.ts:2064, GameOptions.ts:123)")


func test_death_shakes_by_24_times_the_option() -> void:
	_rc.reset_run(_bounds)
	var amounts: Array[float] = []
	_rc.trigger_shake = func(amount: float) -> void: amounts.append(amount)
	_options.settings.screen_shake = GameOptionsManager.ScreenShake.OFF
	_rc.lives = 1
	_rc.lose_life()
	assert_eq(amounts, [0.0] as Array[float], "24 x 0 (TiltGame.ts:2081)")
