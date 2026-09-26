## bench_sim.gd — desktop CPU benchmark for the M11c perf pass (not part of the suite).
## Run: "$GODOT" --headless --path godot -s addons/gut/gut_cmdln.gd -gtest=res://bench/bench_sim.gd -gexit
## Numbers are desktop µs; compare runs against each other, not against the A55.
extends GutTest

const BOUNDS: Vector2 = Vector2(2162.0, 1056.0)  # the A55 arena at arena_scale 1.25
const ENEMIES: int = 115
const TICKS: int = 600
const DT: float = 1.0 / 120.0 * 0.75

var _rc: RunController = null
var _swarm: EnemySwarm = null
var _grid: VectorGrid = null
var _particles: ParticleEngine = null


func before_each() -> void:
	seed(1234)
	var player: PlayerShip = PlayerShip.new(BOUNDS.x * 0.5, BOUNDS.y * 0.5)
	_swarm = EnemySwarm.new()
	_swarm.scale = 1.25
	_particles = ParticleEngine.new()
	_grid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var progression: ProgressionManager = ProgressionManager.new()
	_rc = RunController.new(
		player,
		_swarm,
		WeaponSystem.new(),
		_particles,
		_grid,
		ScoreManager.new(),
		AudioBank.new(),
		progression,
		GameOptionsManager.new(),
		CoinSystem.new()
	)
	_rc.goals = GoalManager.new(progression)
	_rc.maze = GauntletMaze.new()
	_rc.bounds = BOUNDS
	_seed_swarm()


func _seed_swarm() -> void:
	_swarm.enemies.clear()
	for i: int in range(ENEMIES):
		_swarm.spawn_seeker(BOUNDS, randf() * BOUNDS.x, randf() * BOUNDS.y)


func _report(label: String, usec: int, ticks: int) -> void:
	print(
		"BENCH %-22s %8.1f us/tick  (en=%d)" % [label, float(usec) / ticks, _swarm.enemies.size()]
	)


func test_bench() -> void:
	# Swarm step (includes separation), from 115 seeded seekers.
	var t0: int = Time.get_ticks_usec()
	for i: int in range(TICKS):
		_swarm.update(
			DT,
			Vector2(BOUNDS.x * 0.5, BOUNDS.y * 0.5),
			BOUNDS,
			_particles,
			30000,
			Types.GameMode.CLASSIC
		)
	_report("swarm.update", Time.get_ticks_usec() - t0, TICKS)

	_seed_swarm()
	t0 = Time.get_ticks_usec()
	for i: int in range(TICKS):
		_swarm.apply_flocking_separation()
	_report("separation", Time.get_ticks_usec() - t0, TICKS)

	t0 = Time.get_ticks_usec()
	for i: int in range(TICKS):
		_grid.update(DT)
	_report("grid.update", Time.get_ticks_usec() - t0, TICKS)

	# A power-up mass kill: 30 kills in one tick, through the real kill path.
	_seed_swarm()
	t0 = Time.get_ticks_usec()
	for i: int in range(30):
		_rc.handle_enemy_killed(_swarm.enemies[i], Types.WeaponType.NUKE)
	_report("30 kills (one tick)", Time.get_ticks_usec() - t0, 1)
	_particles.particles.clear()
	pass_test("bench")


func test_bench_hits() -> void:
	# Shield ram through 20 enemies in one tick, then the death tick (saves write behind, as in-game).
	SaveStore.write_behind = true
	_rc.reset_run(BOUNDS)
	_seed_swarm()
	var p: PlayerShip = _rc.player
	for i: int in range(20):
		_swarm.enemies[i].x = p.x
		_swarm.enemies[i].y = p.y
	p.activate_shield(5.0)
	var t0: int = Time.get_ticks_usec()
	_rc.check_collisions()
	_report("shield ram x20", Time.get_ticks_usec() - t0, 1)
	p.shield_timer = 0.0
	_swarm.enemies[0].x = p.x
	_swarm.enemies[0].y = p.y
	t0 = Time.get_ticks_usec()
	_rc.check_collisions()
	_report("death tick", Time.get_ticks_usec() - t0, 1)
	t0 = Time.get_ticks_usec()
	_rc.goals.evaluate_run(_rc.run_tracker)
	_report("  goals.evaluate_run", Time.get_ticks_usec() - t0, 1)
	t0 = Time.get_ticks_usec()
	_rc.scores.finalize_game()
	_report("  scores.finalize_game", Time.get_ticks_usec() - t0, 1)
	SaveStore.flush()
	SaveStore.write_behind = false
	pass_test("bench")


func test_bench_kill_parts() -> void:
	_rc.reset_run(BOUNDS)
	_seed_swarm()
	var t0: int = Time.get_ticks_usec()
	for i: int in range(20):
		_rc.scores.register_kill(10.0, 10.0, Types.WeaponType.SHIELD, _rc.audio)
	_report("20x register_kill", Time.get_ticks_usec() - t0, 1)
	t0 = Time.get_ticks_usec()
	for i: int in range(20):
		_particles.emit_explosion(10.0, 10.0, Color.RED, 20)
	_report("20x emit_explosion cold", Time.get_ticks_usec() - t0, 1)
	_particles.update(10.0)  # retire all: the pool is now warm
	t0 = Time.get_ticks_usec()
	for i: int in range(20):
		_particles.emit_explosion(10.0, 10.0, Color.RED, 20)
	_report("20x emit_explosion warm", Time.get_ticks_usec() - t0, 1)
	t0 = Time.get_ticks_usec()
	_particles.update(0.01)
	_report("update 400 particles", Time.get_ticks_usec() - t0, 1)
	t0 = Time.get_ticks_usec()
	_particles.update(10.0)
	_report("retire 400 particles", Time.get_ticks_usec() - t0, 1)
	t0 = Time.get_ticks_usec()
	for i: int in range(20):
		_swarm.on_enemy_killed(_swarm.enemies[i], _particles)
	_report("20x on_enemy_killed", Time.get_ticks_usec() - t0, 1)
	t0 = Time.get_ticks_usec()
	for i: int in range(20):
		GameEvents.enemy_killed.emit(_swarm.enemies[i], Types.WeaponType.SHIELD)
	_report("20x enemy_killed.emit", Time.get_ticks_usec() - t0, 1)
	pass_test("bench")


func test_bench_late_mix() -> void:
	# The emulator's 150+ state (2026-09-27): seekers, a wall and the heavy types.
	var centre: Vector2 = BOUNDS * 0.5
	_seed_swarm()
	_swarm.spawn_wall_formation(BOUNDS)
	for i: int in range(4):
		_swarm.spawn_carrier(BOUNDS, centre)
	for i: int in range(3):
		_swarm.spawn_artillery(BOUNDS, centre)
		_swarm.spawn_pulsar(BOUNDS, centre)
		_swarm.spawn_specter(BOUNDS, centre)
		_swarm.spawn_charger(BOUNDS, centre)
	var n: int = _swarm.enemies.size()
	var t0: int = Time.get_ticks_usec()
	for i: int in range(TICKS):
		_swarm.update(DT, centre, BOUNDS, _particles, 30000, Types.GameMode.CODE_RED)
	_report("swarm.update late mix", Time.get_ticks_usec() - t0, TICKS)
	print("  (started with %d)" % n)
	PerfProbe.enabled = true
	PerfProbe.reset()
	for i: int in range(TICKS):
		_swarm.update(DT, centre, BOUNDS, _particles, 30000, Types.GameMode.CODE_RED)
	_particles.particles.clear()
	pass_test("bench")
