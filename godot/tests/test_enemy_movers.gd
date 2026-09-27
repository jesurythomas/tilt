## test_enemy_movers.gd
## PORTS: nothing — new file, covers the sweep-formation movers in src/sim/enemy_swarm.gd
extends GutTest
## Covers arrow drones, circle dots, wall dots and spike mines: their formation
## spawners, their movement, and their exclusion from clamping and separation.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)

var _particles: ParticleEngine = null
var _swarm: EnemySwarm = null


func before_each() -> void:
	_particles = ParticleEngine.new()
	_swarm = EnemySwarm.new()


func _count_type(type: Types.EnemyType) -> int:
	var n: int = 0
	for e: PerilEnemy in _swarm.enemies:
		if e.type == type:
			n += 1
	return n


func test_arrow_formation_spawns_seven_drones_in_one_wing() -> void:
	_swarm.spawn_arrow_formation(BOUNDS)
	assert_eq(_swarm.enemies.size(), 7, "one wing is seven drones (EnemySwarm.ts:859-864)")
	var first: PerilEnemy = _swarm.enemies[0]
	for e: PerilEnemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.ARROW_DRONE)
		assert_almost_eq(e.radius, 8.0, 0.001)
		assert_almost_eq(absf(e.vx), 260.0, 0.001, "wing speed is 260 * max(0.72, scale)")
		assert_eq(e.vx, first.vx, "every drone in a wing shares the wing's vx")
		assert_eq(e.vy, 0.0)
	assert_true(first.x < 0.0 or first.x > BOUNDS.x, "the wing starts off-screen")
	assert_between(first.y, 100.0, BOUNDS.y - 100.0)


func test_dual_pincer_spawns_both_wings() -> void:
	_swarm.spawn_arrow_formation(BOUNDS, true)
	assert_eq(_swarm.enemies.size(), 14)
	var from_left: int = 0
	var from_right: int = 0
	for e: PerilEnemy in _swarm.enemies:
		if e.vx > 0.0:
			from_left += 1
		else:
			from_right += 1
	assert_eq(from_left, 7)
	assert_eq(from_right, 7)


func test_arrow_drone_moves_straight_and_is_not_clamped() -> void:
	_swarm.spawn_arrow_formation(BOUNDS)
	var lead: PerilEnemy = _swarm.enemies[0]
	var start_x: float = lead.x
	var start_y: float = lead.y
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_almost_eq(lead.x, start_x + lead.vx * 0.1, 0.001, "drone integrates vx only")
	assert_almost_eq(lead.y, start_y, 0.001, "no steering, no separation nudge")
	assert_true(lead.x < 0.0 or lead.x > BOUNDS.x, "a drone off-screen is not clamped in")


func test_arrow_drone_is_removed_after_leaving_the_arena() -> void:
	_swarm.spawn_arrow_formation(BOUNDS)
	for e: PerilEnemy in _swarm.enemies:
		e.x = BOUNDS.x + 200.0
	_swarm.update(0.01, PLAYER, BOUNDS, _particles)
	assert_eq(_swarm.enemies.size(), 0, "beyond bounds + 140 the drone is culled")


func test_circle_encirclement_count_scales_with_score() -> void:
	# DIVERGENCE(M11c P9): user ruling 2026-09-26 — fewer dots, wider gaps (TS 12-16).
	_swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 0)
	assert_eq(_count_type(Types.EnemyType.CIRCLE_DOT), 8, "8 + floor(0 / 10000)")
	_swarm.reset()
	_swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 15000)
	assert_eq(_count_type(Types.EnemyType.CIRCLE_DOT), 9, "8 + 1")
	_swarm.reset()
	_swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 90000)
	assert_eq(_count_type(Types.EnemyType.CIRCLE_DOT), 10, "capped at 10")


func test_circle_dots_ring_the_player_then_close_in() -> void:
	_swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 0)
	for e: PerilEnemy in _swarm.enemies:
		assert_almost_eq(Vector2(e.x, e.y).distance_to(PLAYER), 260.0, 0.01)
		assert_almost_eq(e.special_timer, 1.25, 0.001)
	var probe: PerilEnemy = _swarm.enemies[0]
	var start_x: float = probe.x
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_almost_eq(probe.x, start_x, 0.001, "still paused")
	for i: int in range(13):
		_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_lt(Vector2(probe.x, probe.y).distance_to(PLAYER), 260.0, "closes once the pause ends")


func test_tight_circle_uses_the_code_red_values() -> void:
	_swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 0, true)
	assert_eq(_swarm.enemies.size(), 11, "DIVERGENCE(M11c P9): user ruling, TS 16")
	for e: PerilEnemy in _swarm.enemies:
		assert_almost_eq(Vector2(e.x, e.y).distance_to(PLAYER), 180.0, 0.01)
		assert_almost_eq(e.special_timer, 0.75, 0.001)


func test_wall_spacing_still_blocks_the_default_ship() -> void:
	# M11c P29: the midpoint between two wall dots stays inside the default ship's
	# contact distance (hitbox 1.0, no hull compact); smaller hitboxes may pass (user).
	var contact: float = 9.0 * 1.0 + 8.0
	assert_lt(EnemySwarm.WALL_SPACING * 0.5, contact, "the default ship cannot pass")


func test_wall_formation_leaves_a_three_dot_gap() -> void:
	_swarm.spawn_wall_formation(BOUNDS)
	var horizontal: bool = _swarm.enemies[0].vy != 0.0
	# DIVERGENCE(M11c P29): spacing 32 (TS 22), gap 3 slots (TS 5), user ruling.
	var num_dots: int = floori((BOUNDS.x if horizontal else BOUNDS.y) / 32.0)
	assert_eq(_swarm.enemies.size(), num_dots - 3, "|i - gapIndex| <= 1 skips three")
	for e: PerilEnemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.WALL_DOT)
		assert_almost_eq(e.radius, 8.0, 0.001)
		if horizontal:
			assert_eq(e.vx, 0.0)
			assert_almost_eq(absf(e.vy), 140.0, 0.001)
			assert_true(e.y == -30.0 or e.y == BOUNDS.y + 30.0)
		else:
			assert_eq(e.vy, 0.0)
			assert_almost_eq(absf(e.vx), 140.0, 0.001)
			assert_true(e.x == -30.0 or e.x == BOUNDS.x + 30.0)


func test_wall_dots_are_neither_clamped_nor_separated() -> void:
	var a: PerilEnemy = PerilEnemy.new()
	a.type = Types.EnemyType.WALL_DOT
	a.x = 200.0
	a.y = -30.0
	a.vy = 140.0
	a.radius = 8.0
	var b: PerilEnemy = PerilEnemy.new()
	b.type = Types.EnemyType.WALL_DOT
	b.x = 202.0
	b.y = -30.0
	b.vy = 140.0
	b.radius = 8.0
	_swarm.enemies.append(a)
	_swarm.enemies.append(b)
	_swarm.update(0.01, PLAYER, BOUNDS, _particles)
	assert_almost_eq(a.x, 200.0, 0.0001, "no separation push")
	assert_almost_eq(b.x, 202.0, 0.0001)
	assert_almost_eq(a.y, -30.0 + 1.4, 0.0001, "still outside the arena: no clamp")


func test_spike_mine_drifts_by_its_velocity() -> void:
	var mine: PerilEnemy = PerilEnemy.new()
	mine.type = Types.EnemyType.SPIKE_MINE
	mine.x = 300.0
	mine.y = 300.0
	mine.vx = 40.0
	mine.vy = -20.0
	mine.radius = 8.0
	_swarm.enemies.append(mine)
	_swarm.set_speed_scale(0.5)
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_almost_eq(mine.x, 302.0, 0.0001, "vx * dt * speed_scale")
	assert_almost_eq(mine.y, 299.0, 0.0001)


func _sweeper(type: Types.EnemyType, pos: Vector2, vel: Vector2) -> PerilEnemy:
	var e: PerilEnemy = PerilEnemy.new()
	e.type = type
	e.x = pos.x
	e.y = pos.y
	e.vx = vel.x
	e.vy = vel.y
	e.radius = 8.0
	e.health = 1.0
	_swarm.enemies.append(e)
	return e


func test_sweep_dots_step_by_speed_scale_and_cull_only_past_140() -> void:
	# M11c P28: wall and arrow dots step inline and share one x/y read with the cull.
	_swarm.speed_scale = 0.5
	var kept_w: PerilEnemy = _sweeper(
		Types.EnemyType.WALL_DOT, Vector2(-139.5, 300.0), Vector2(-100.0, 0.0)
	)
	var kept_v: PerilEnemy = _sweeper(
		Types.EnemyType.WALL_DOT, Vector2(500.0, -139.5), Vector2(0.0, -100.0)
	)
	var kept_a: PerilEnemy = _sweeper(
		Types.EnemyType.ARROW_DRONE, Vector2(BOUNDS.x + 139.5, 300.0), Vector2(100.0, 0.0)
	)
	var gone_w: PerilEnemy = _sweeper(
		Types.EnemyType.WALL_DOT, Vector2(-144.0, 600.0), Vector2(-100.0, 0.0)
	)
	var gone_a: PerilEnemy = _sweeper(
		Types.EnemyType.ARROW_DRONE, Vector2(700.0, BOUNDS.y + 144.0), Vector2(0.0, 100.0)
	)
	_swarm.update(0.01, PLAYER, BOUNDS, _particles)
	assert_almost_eq(kept_w.x, -140.0, 0.0001, "x += vx * dt * speed_scale")
	assert_almost_eq(kept_v.y, -140.0, 0.0001, "y += vy * dt * speed_scale")
	assert_almost_eq(kept_a.x, BOUNDS.x + 140.0, 0.0001)
	assert_true(_swarm.enemies.has(kept_w), "at -140 exactly: kept")
	assert_true(_swarm.enemies.has(kept_v))
	assert_true(_swarm.enemies.has(kept_a))
	assert_false(_swarm.enemies.has(gone_w), "past -140: culled")
	assert_false(_swarm.enemies.has(gone_a), "past bounds + 140: culled")
