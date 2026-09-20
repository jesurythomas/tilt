## test_enemy_turret_snake.gd
## PORTS: nothing — new file, covers turrets, gates, walls and snakes in src/sim/enemy_swarm.gd
extends GutTest
## Covers the free turret, the rotating gate variant of turret_dot, the
## sequential gauntlet wall cycle, and snake segments.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)

var _particles: ParticleEngine = null
var _swarm: EnemySwarm = null


func before_each() -> void:
	_particles = ParticleEngine.new()
	_swarm = EnemySwarm.new()


func test_spawn_turret_places_a_slow_drifting_three_health_dot() -> void:
	_swarm.spawn_turret(BOUNDS)
	assert_eq(_swarm.enemies.size(), 1)
	var t: Types.Enemy = _swarm.enemies[0]
	assert_eq(t.type, Types.EnemyType.TURRET_DOT)
	assert_almost_eq(t.health, 3.0, 0.001)
	assert_almost_eq(t.radius, 12.0, 0.001)
	assert_between(t.x, 80.0, BOUNDS.x - 80.0)
	assert_between(t.y, 80.0, BOUNDS.y - 80.0)
	assert_lte(absf(t.vx), 15.0, "(randf() - 0.5) * 30")
	assert_lte(absf(t.vy), 15.0)
	assert_eq(t.orbit_center, Vector2.ZERO, "a free turret has no orbit")
	assert_true(is_nan(t.target_angle), "aim is unset until the first update")


func test_turret_snaps_to_the_player_then_eases() -> void:
	_swarm.spawn_turret(BOUNDS)
	var t: Types.Enemy = _swarm.enemies[0]
	t.x = 500.0
	t.y = 300.0
	t.vx = 0.0
	t.vy = 0.0
	_swarm.update_turret_dot(t, Vector2(600.0, 300.0), 0.1)
	assert_almost_eq(t.target_angle, 0.0, 0.0001, "first update snaps (EnemySwarm.ts:300)")
	_swarm.update_turret_dot(t, Vector2(500.0, 400.0), 0.1)
	assert_almost_eq(t.target_angle, (PI / 2.0) * 0.25, 0.0001, "then eases by min(1, dt * 2.5)")


func test_rotating_gate_spawns_six_hazard_dots_about_the_centre() -> void:
	_swarm.spawn_rotating_gate(BOUNDS)
	assert_eq(_swarm.enemies.size(), 6)
	var centre: Vector2 = BOUNDS / 2.0
	var radii: Array[float] = []
	for e: Types.Enemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.TURRET_DOT)
		assert_true(e.is_hazard)
		assert_eq(e.orbit_center, centre)
		assert_almost_eq(absf(e.orbit_speed), 0.75, 0.001)
		assert_almost_eq(e.radius, 8.5, 0.001, "unscaled (EnemySwarm.ts:1082)")
		var expected_angle: float = 0.0 if e.x > centre.x else PI
		assert_almost_eq(e.target_angle, expected_angle, 0.0001)
		radii.append(e.orbit_radius)
	radii.sort()
	var expected: Array[float] = [32.0, 32.0, 56.0, 56.0, 80.0, 80.0]
	assert_eq(radii, expected)


func test_rotating_gate_dots_orbit_and_ignore_clamp_and_separation() -> void:
	_swarm.spawn_rotating_gate(BOUNDS)
	var centre: Vector2 = BOUNDS / 2.0
	var gate: Types.Enemy = _swarm.enemies[0]
	var angle_before: float = gate.target_angle
	_swarm.update(0.1, Vector2(10.0, 10.0), BOUNDS, _particles)
	assert_almost_eq(gate.target_angle, angle_before + gate.orbit_speed * 0.1, 0.0001)
	for e: Types.Enemy in _swarm.enemies:
		assert_almost_eq(
			Vector2(e.x, e.y).distance_to(centre), e.orbit_radius, 0.001, "stays on its orbit"
		)


func test_sequential_gauntlet_wall_cycles_through_four_directions() -> void:
	var num_cols: int = floori(BOUNDS.x / 22.0)
	var num_rows: int = floori(BOUNDS.y / 22.0)
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_eq(_swarm.enemies.size(), num_cols - 7, "|i - gapIndex| <= 3 skips seven")
	for e: Types.Enemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.WALL_DOT)
		assert_true(e.is_hazard)
		assert_almost_eq(e.y, -30.0, 0.001)
		assert_almost_eq(e.vy, 150.0, 0.001)
		assert_almost_eq(e.radius, 8.5, 0.001)
	_swarm.enemies.clear()
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_eq(_swarm.enemies.size(), num_rows - 7)
	assert_almost_eq(_swarm.enemies[0].x, BOUNDS.x + 30.0, 0.001, "second: right to left")
	assert_almost_eq(_swarm.enemies[0].vx, -150.0, 0.001)
	_swarm.enemies.clear()
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_almost_eq(_swarm.enemies[0].y, BOUNDS.y + 30.0, 0.001, "third: bottom to top")
	assert_almost_eq(_swarm.enemies[0].vy, -150.0, 0.001)
	_swarm.enemies.clear()
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_almost_eq(_swarm.enemies[0].x, -30.0, 0.001, "fourth: left to right")
	assert_almost_eq(_swarm.enemies[0].vx, 150.0, 0.001)
	_swarm.enemies.clear()
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_almost_eq(_swarm.enemies[0].y, -30.0, 0.001, "fifth wraps to top-down")
	_swarm.reset()
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_almost_eq(_swarm.enemies[0].y, -30.0, 0.001, "reset() restarts the cycle")


func test_snake_spawns_eight_segments_head_first() -> void:
	_swarm.spawn_snake(BOUNDS)
	assert_eq(_swarm.enemies.size(), 8)
	var head: Types.Enemy = _swarm.enemies[0]
	assert_almost_eq(head.radius, 10.0, 0.001)
	for i: int in range(8):
		var seg: Types.Enemy = _swarm.enemies[i]
		assert_eq(seg.type, Types.EnemyType.SNAKE_SEGMENT)
		assert_almost_eq(seg.x, head.x - float(i) * 14.0, 0.001)
		assert_eq(seg.y, head.y)
		assert_almost_eq(seg.vx, 110.0, 0.001)
		assert_eq(seg.leader_id, Types.ABSENT, "EnemySwarm.ts never assigns leaderId")
		if i > 0:
			assert_almost_eq(seg.radius, 8.0, 0.001)


func test_snake_segment_advances_then_may_re_aim() -> void:
	_swarm.spawn_snake(BOUNDS)
	var head: Types.Enemy = _swarm.enemies[0]
	var start_x: float = head.x
	_swarm.update_snake_segment(head, 0.1)
	assert_almost_eq(head.x, start_x + 11.0, 0.0001, "moves by the old velocity before any re-aim")
	var speed: float = Vector2(head.vx, head.vy).length()
	assert_true(
		absf(speed - 110.0) < 0.001 or absf(speed - 120.0) < 0.001,
		"keeps 110 or re-aims at 120 — true for any roll"
	)
