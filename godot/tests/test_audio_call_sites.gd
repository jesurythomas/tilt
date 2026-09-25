## test_audio_call_sites.gd
## PORTS: nothing — proves the M2–M4 SFX call sites fire at their TS moment (spec §8 M5 Accept)
extends GutTest
## Each live play* call (M5 R8 lists the uncalled ones), driven through the sim
## system that makes it and recorded by SpyAudioBank.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)

var _spy: SpyAudioBank = null
var _player: PlayerShip = null
var _particles: ParticleEngine = null
var _grid: VectorGrid = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _clear_saves() -> void:
	for path: String in [
		ProgressionManager.SAVE_PATH,
		GameOptionsManager.SAVE_PATH,
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
	]:
		_remove(path)
		_remove(SaveStore.corrupt_path_for(path))


func before_each() -> void:
	_clear_saves()
	_spy = SpyAudioBank.new()
	_player = PlayerShip.new(BOUNDS.x * 0.5, BOUNDS.y * 0.5)
	_particles = ParticleEngine.new()
	_grid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))


func after_each() -> void:
	_clear_saves()


func _run_controller() -> RunController:
	var rc: RunController = RunController.new(
		_player,
		EnemySwarm.new(),
		WeaponSystem.new(),
		_particles,
		_grid,
		ScoreManager.new(),
		_spy,
		ProgressionManager.new(),
		GameOptionsManager.new(),
		CoinSystem.new()
	)
	rc.goals = GoalManager.new(rc.progression)
	rc.maze = GauntletMaze.new()
	rc.reset_run(BOUNDS)
	_spy.requested.clear()
	_spy.lifecycle.clear()
	return rc


func test_kills_pop_the_next_combo_note() -> void:
	var scores: ScoreManager = ScoreManager.new()
	for i: int in range(3):
		scores.register_kill(0.0, 0.0, Types.WeaponType.NUKE, _spy)
	var expected: Array[String] = ["dot_pop_01", "dot_pop_02", "dot_pop_03"]
	assert_eq(_spy.requested, expected, "playDotPop(comboCount) (ScoreManager.ts:115)")


func test_combo_milestones_chime_at_10_16_25_then_every_15th() -> void:
	var scores: ScoreManager = ScoreManager.new()
	var chimes_at: Array[int] = []
	for combo: int in range(1, 46):
		scores.register_kill(0.0, 0.0, Types.WeaponType.NUKE, _spy)
		if _spy.requested.back() == "milestone":
			chimes_at.append(combo)
	assert_eq(chimes_at, [10, 16, 25, 30, 45] as Array[int], "ScoreManager.ts:121-131")


func test_close_call_chimes() -> void:
	ScoreManager.new().register_close_call(0.0, 0.0, _spy)
	assert_eq(_spy.requested, ["close_call"] as Array[String], "ScoreManager.ts:136")


func test_coin_pickup_chimes() -> void:
	var coins: CoinSystem = CoinSystem.new()
	var on_collected: Callable = func(value: int) -> int: return value
	var t: float = 0.0
	while coins.coins.is_empty() and t < 10.0:
		coins.update(0.05, _player, BOUNDS, _particles, _spy, 1.0, on_collected)
		t += 0.05
	assert_false(coins.coins.is_empty(), "a coin spawned")
	_player.x = coins.coins[0].x
	_player.y = coins.coins[0].y
	coins.update(0.01, _player, BOUNDS, _particles, _spy, 1.0, on_collected)
	assert_eq(_spy.requested, ["coin_pickup"] as Array[String], "CoinSystem.ts:90")


func test_orb_pickup_fires_the_weapon_then_the_chime() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	ws.spawn_orb(BOUNDS, Types.WeaponType.NUKE, _player.x, _player.y)
	var enemies: Array[Types.Enemy] = []
	ws.update(
		0.016,
		_player,
		enemies,
		BOUNDS,
		_particles,
		_grid,
		_spy,
		func(_e: Types.Enemy, _w: Types.WeaponType) -> void: pass
	)
	assert_eq(
		_spy.requested,
		["nuke", "orb_pickup"] as Array[String],
		"activateWeapon then playOrbPickup (WeaponSystem.ts:93-95)"
	)


func test_each_weapon_fires_its_sound() -> void:
	var cases: Dictionary[Types.WeaponType, String] = {
		Types.WeaponType.NUKE: "nuke",  # WeaponSystem.ts:400
		Types.WeaponType.MISSILES: "missile_launch",  # :417
		Types.WeaponType.LIGHTNING: "lightning",  # :438
		Types.WeaponType.LASER: "laser_beam",  # :500
		Types.WeaponType.VORTEX: "vortex",  # :518
		Types.WeaponType.FREEZE: "freeze",  # :539
	}
	for type: Types.WeaponType in cases:
		_spy.requested.clear()
		var enemies: Array[Types.Enemy] = []
		WeaponSystem.new().trigger_weapon(
			type, _player.x, _player.y, _player, enemies, _particles, _grid, _spy
		)
		assert_eq(_spy.requested[0], cases[type], "weapon %d" % type)
	_spy.requested.clear()
	var none: Array[Types.Enemy] = []
	WeaponSystem.new().trigger_weapon(
		Types.WeaponType.SHIELD, _player.x, _player.y, _player, none, _particles, _grid, _spy
	)
	assert_true(_spy.requested.is_empty(), "the shield is silent (WeaponSystem.ts:541-556)")


func test_missiles_explode_when_their_fuel_runs_out() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	var enemies: Array[Types.Enemy] = []
	ws.trigger_weapon(
		Types.WeaponType.MISSILES, _player.x, _player.y, _player, enemies, _particles, _grid, _spy
	)
	for i: int in range(250):
		ws.update(
			0.016,
			_player,
			enemies,
			BOUNDS,
			_particles,
			_grid,
			_spy,
			func(_e: Types.Enemy, _w: Types.WeaponType) -> void: pass
		)
	assert_true(
		_spy.requested.has("missile_explode"), "lifetime 3.5 s → blast (WeaponSystem.ts:341)"
	)


func test_ramming_a_frozen_enemy_shatters_it() -> void:
	var rc: RunController = _run_controller()
	var e: Types.Enemy = rc.swarm.spawn_seeker(BOUNDS, _player.x, _player.y)
	e.frozen = true
	rc.check_collisions()
	assert_eq(
		_spy.requested,
		["ice_shatter", "dot_pop_01"] as Array[String],
		"playIceShatter then registerKill (TiltGame.ts:2025-2026)"
	)


func test_losing_a_life_sounds_the_siren() -> void:
	var rc: RunController = _run_controller()
	rc.lives = 2
	rc.max_lives = 2
	rc.swarm.spawn_seeker(BOUNDS, _player.x, _player.y)
	rc.check_collisions()
	assert_eq(_spy.requested, ["siren"] as Array[String], "TiltGame.ts:2061")
	assert_true(_spy.lifecycle.is_empty(), "the music keeps playing")


func test_death_plays_the_crash_and_stops_the_music() -> void:
	var rc: RunController = _run_controller()
	rc.swarm.spawn_seeker(BOUNDS, _player.x, _player.y)
	rc.check_collisions()
	assert_eq(_spy.requested, ["player_death"] as Array[String], "TiltGame.ts:2075")
	assert_eq(_spy.lifecycle, ["stop_music"] as Array[String], "TiltGame.ts:2076")


func test_a_new_run_starts_the_music_when_it_is_on() -> void:
	var rc: RunController = _run_controller()
	rc.options.settings.music_enabled = true
	rc.reset_run(BOUNDS)
	assert_eq(_spy.lifecycle, ["start_music"] as Array[String], "TiltGame.ts:170-172 (M6 R7)")


func test_a_new_run_stays_silent_when_music_is_off() -> void:
	var rc: RunController = _run_controller()
	rc.options.settings.music_enabled = false
	rc.reset_run(BOUNDS)
	assert_true(_spy.lifecycle.is_empty(), "the musicEnabled guard (TiltGame.ts:170)")
