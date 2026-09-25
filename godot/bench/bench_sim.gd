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
	print("BENCH %-22s %8.1f us/tick  (en=%d)" % [label, float(usec) / ticks, _swarm.enemies.size()])


func test_bench() -> void:
	# Swarm step (includes separation), from 115 seeded seekers.
	var t0: int = Time.get_ticks_usec()
	for i: int in range(TICKS):
		_swarm.update(DT, Vector2(BOUNDS.x * 0.5, BOUNDS.y * 0.5), BOUNDS, _particles, 30000, Types.GameMode.CLASSIC)
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
