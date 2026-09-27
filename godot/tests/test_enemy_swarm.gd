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
	var e: PerilEnemy = swarm.spawn_seeker(bounds)
	assert_eq(swarm.enemies.size(), 1)
	assert_eq(e.type, Types.EnemyType.SEEKER)
	assert_almost_eq(e.radius, 8.5, 0.001, "seeker radius is 8.5 * scale")
	assert_false(e.frozen)


func test_seeker_steers_towards_player() -> void:
	var swarm: EnemySwarm = EnemySwarm.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var e: PerilEnemy = swarm.spawn_seeker(bounds, 100.0, 100.0)
	var player_pos: Vector2 = Vector2(300.0, 100.0)  # player directly to the right

	swarm.update(0.1, player_pos, bounds, _particles)
	assert_true(e.vx > 0.0, "seeker velocity steers right toward player")
	assert_almost_eq(e.vy, 0.0, 0.5, "seeker vertical velocity remains near 0")
	assert_true(e.x > 100.0, "seeker moved to the right")


func test_flocking_separation_pushes_overlapping_dots_apart() -> void:
	var swarm: EnemySwarm = EnemySwarm.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var e1: PerilEnemy = swarm.spawn_seeker(bounds, 200.0, 200.0)
	var e2: PerilEnemy = swarm.spawn_seeker(bounds, 202.0, 200.0)

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
	var e: PerilEnemy = swarm.spawn_seeker(bounds, 4.0, 200.0)
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


func test_seeker_clamp_halves_and_reflects_velocity_at_each_wall() -> void:
	# M11c P27: the seeker clamp runs inline on locals. A seeker on the player does not
	# steer (distance <= 1), so its step is exactly x += vx * dt; each wall must set the
	# position to the pad and the velocity to +-|v| * 0.5.
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var cases: Array = [
		[Vector2(2.0, 300.0), Vector2(-1000.0, 0.0), "left"],
		[Vector2(998.0, 300.0), Vector2(1000.0, 0.0), "right"],
		[Vector2(500.0, 2.0), Vector2(0.0, -1000.0), "top"],
		[Vector2(500.0, 598.0), Vector2(0.0, 1000.0), "bottom"],
	]
	for c: Array in cases:
		var swarm: EnemySwarm = EnemySwarm.new()
		var pos: Vector2 = c[0]
		var vel: Vector2 = c[1]
		var e: PerilEnemy = swarm.spawn_seeker(bounds, pos.x, pos.y)
		e.vx = vel.x
		e.vy = vel.y
		swarm.update(0.01, pos, bounds, _particles)
		var pad: float = e.radius
		match c[2]:
			"left":
				assert_eq(e.x, pad, "left: x at the pad")
				assert_eq(e.vx, 500.0, "left: vx = |vx| * 0.5")
			"right":
				assert_eq(e.x, bounds.x - pad, "right: x at the pad")
				assert_eq(e.vx, -500.0, "right: vx = -|vx| * 0.5")
			"top":
				assert_eq(e.y, pad, "top: y at the pad")
				assert_eq(e.vy, 500.0, "top: vy = |vy| * 0.5")
			"bottom":
				assert_eq(e.y, bounds.y - pad, "bottom: y at the pad")
				assert_eq(e.vy, -500.0, "bottom: vy = -|vy| * 0.5")


func test_satellite_seeker_is_not_clamped() -> void:
	# M11c P27: a carrier's satellite (a seeker with parent_carrier_id) skips the clamp.
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var swarm: EnemySwarm = EnemySwarm.new()
	var e: PerilEnemy = swarm.spawn_seeker(bounds, 2.0, 300.0)
	e.parent_carrier_id = 99999
	e.vx = -1000.0
	swarm.update(0.01, Vector2(2.0, 300.0), bounds, _particles)
	assert_eq(e.x, 2.0 + -1000.0 * 0.01, "moved past the wall, unclamped")
