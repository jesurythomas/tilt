## test_enemy_swarm.gd
## PORTS: nothing — new file, covers src/sim/enemy_swarm.gd
extends GutTest
## Proves EnemySwarm seeker spawning, steering, flocking separation and bounds clamping.

var _particles: ParticleEngine = null


func before_each() -> void:
	_particles = ParticleEngine.new()


func test_spawn_seeker_creates_valid_enemy() -> void:
	var swarm: EnemySwarm = EnemySwarm.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var e: Types.Enemy = swarm.spawn_seeker(bounds)
	assert_eq(swarm.enemies.size(), 1)
	assert_eq(e.type, Types.EnemyType.SEEKER)
	assert_almost_eq(e.radius, 8.5, 0.001, "seeker radius is 8.5 * scale")
	assert_false(e.frozen)


func test_seeker_steers_towards_player() -> void:
	var swarm: EnemySwarm = EnemySwarm.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var e: Types.Enemy = swarm.spawn_seeker(bounds, 100.0, 100.0)
	var player_pos: Vector2 = Vector2(300.0, 100.0)  # player directly to the right

	swarm.update(0.1, player_pos, bounds, _particles)
	assert_true(e.vx > 0.0, "seeker velocity steers right toward player")
	assert_almost_eq(e.vy, 0.0, 0.5, "seeker vertical velocity remains near 0")
	assert_true(e.x > 100.0, "seeker moved to the right")


func test_flocking_separation_pushes_overlapping_dots_apart() -> void:
	var swarm: EnemySwarm = EnemySwarm.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var e1: Types.Enemy = swarm.spawn_seeker(bounds, 200.0, 200.0)
	var e2: Types.Enemy = swarm.spawn_seeker(bounds, 202.0, 200.0)

	var initial_dist: float = e2.x - e1.x
	assert_almost_eq(initial_dist, 2.0, 0.01)

	swarm.apply_flocking_separation()
	var separated_dist: float = e2.x - e1.x
	assert_true(
		separated_dist > initial_dist,
		(
			"flocking separation pushes dots apart (initial %f, now %f)"
			% [initial_dist, separated_dist]
		)
	)


func test_seeker_clamps_and_bounces_inside_bounds() -> void:
	var swarm: EnemySwarm = EnemySwarm.new()
	var bounds: Vector2 = Vector2(500.0, 400.0)
	var e: Types.Enemy = swarm.spawn_seeker(bounds, 4.0, 200.0)
	e.vx = -50.0  # moving left towards out of bounds

	swarm.update(0.05, Vector2(0.0, 200.0), bounds, _particles)
	assert_true(e.x >= e.radius, "e.x clamped at or above radius margin")
	assert_true(e.vx >= 0.0, "e.vx reflected outward")


func test_reset_clears_enemies_and_timers() -> void:
	var swarm: EnemySwarm = EnemySwarm.new()
	var bounds: Vector2 = Vector2(500.0, 400.0)
	swarm.spawn_seeker(bounds)
	swarm.spawn_seeker(bounds)
	assert_eq(swarm.enemies.size(), 2)

	swarm.reset()
	assert_eq(swarm.enemies.size(), 0, "reset clears enemies array")
