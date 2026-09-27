## test_enemy_charger_artillery.gd
## PORTS: nothing — new file, covers chargers, artillery and bullets in src/sim/enemy_swarm.gd
extends GutTest
## Covers the charger's aim/charge/cool cycle, artillery's distance band and
## firing, and bullet flight and expiry.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)
## 1/8 s: exactly representable, so timer comparisons against 1.1, 0.75 and
## 0.9 land where the arithmetic says they do.
const DT: float = 0.125

var _particles: ParticleEngine = null
var _swarm: EnemySwarm = null


func before_each() -> void:
	_particles = ParticleEngine.new()
	_swarm = EnemySwarm.new()


func _speed(e: PerilEnemy) -> float:
	return Vector2(e.vx, e.vy).length()


func test_spawn_charger_starts_aiming_at_the_player() -> void:
	var c: PerilEnemy = _swarm.spawn_charger(BOUNDS, PLAYER)
	assert_eq(c.type, Types.EnemyType.CHARGER)
	assert_almost_eq(c.radius, 11.0, 0.001)
	assert_eq(c.state, Types.EnemyState.AIMING)
	assert_almost_eq(c.aim_timer, 1.1, 0.001)
	assert_almost_eq(c.aim_angle, atan2(PLAYER.y - c.y, PLAYER.x - c.x), 0.0001)
	assert_true(c.x < 0.0 or c.x > BOUNDS.x or c.y < 0.0 or c.y > BOUNDS.y, "25 px outside an edge")


func test_charger_cycles_aiming_charging_cooling() -> void:
	var c: PerilEnemy = _swarm.spawn_charger(BOUNDS, PLAYER)
	c.x = 100.0
	c.y = 300.0
	_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.AIMING)
	assert_almost_eq(_speed(c), 35.0, 0.001, "creeps at 35 while locking on")
	assert_almost_eq(c.x, 100.0 + 35.0 * DT, 0.0001)
	for i: int in range(7):
		_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.AIMING, "1.1 - 8 * 0.125 = 0.1 > 0")
	_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.CHARGING, "ninth tick expires the aim timer")
	assert_almost_eq(_speed(c), 480.0, 0.001)
	assert_almost_eq(c.special_timer, 0.75, 0.001)
	for i: int in range(6):
		_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.COOLING, "0.75 - 6 * 0.125 = 0")
	assert_almost_eq(c.special_timer, 0.9, 0.001)
	_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_lt(_speed(c), 480.0, "cooling decays velocity by 0.08^dt")
	for i: int in range(7):
		_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.AIMING, "0.9 - 8 * 0.125 < 0: back to aiming")
	assert_almost_eq(c.aim_timer, 1.1, 0.001)


func test_charging_charger_emits_thruster_sparks() -> void:
	var c: PerilEnemy = _swarm.spawn_charger(BOUNDS, PLAYER)
	c.x = 100.0
	c.y = 300.0
	c.state = Types.EnemyState.CHARGING
	c.special_timer = 100.0
	c.aim_angle = 0.0
	for i: int in range(100):
		_swarm.update_charger(c, PLAYER, 0.01, _particles)
	assert_gt(_particles.particles.size(), 0, "p = 0.6 per tick; 0.4^100 chance of none")
	assert_lte(_particles.particles.size(), 100, "at most one spark per tick")


func test_charger_defaults_state_and_aim_timer_when_absent() -> void:
	var c: PerilEnemy = PerilEnemy.new()
	c.type = Types.EnemyType.CHARGER
	c.x = 100.0
	c.y = 300.0
	_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.AIMING, "EnemySwarm.ts:338")
	assert_almost_eq(c.aim_timer, 1.1 - DT, 0.0001, "EnemySwarm.ts:339 then one tick")


func test_spawn_artillery_is_a_two_health_ranged_unit() -> void:
	var a: PerilEnemy = _swarm.spawn_artillery(BOUNDS, PLAYER)
	assert_eq(a.type, Types.EnemyType.ARTILLERY)
	assert_almost_eq(a.health, 2.0, 0.001)
	assert_almost_eq(a.radius, 13.0, 0.001)
	assert_between(a.fire_cooldown, 2.2, 3.0)
	assert_almost_eq(a.aim_angle, atan2(PLAYER.y - a.y, PLAYER.x - a.x), 0.0001)


func _place(a: PerilEnemy) -> void:
	a.x = 500.0
	a.y = 300.0
	a.vx = 0.0
	a.vy = 0.0


func test_artillery_keeps_its_distance_band() -> void:
	var a: PerilEnemy = _swarm.spawn_artillery(BOUNDS, PLAYER)
	a.fire_cooldown = 100.0
	_place(a)
	_swarm.update_artillery(a, Vector2(600.0, 300.0), 0.1)
	assert_lt(a.vx, 0.0, "inside 220: retreats")
	_place(a)
	_swarm.update_artillery(a, Vector2(900.0, 300.0), 0.1)
	assert_gt(a.vx, 0.0, "beyond 320: closes")
	_place(a)
	_swarm.update_artillery(a, Vector2(770.0, 300.0), 0.1)
	assert_almost_eq(a.vx, 0.0, 0.0001, "inside the band: only strafes")
	assert_almost_eq(absf(a.vy), 40.0 * 3.0 * 0.1, 0.0001, "strafe 40 eased by 3.0 * dt")


func test_artillery_fires_a_bullet_at_the_player_and_recoils() -> void:
	var target: Vector2 = Vector2(800.0, 300.0)
	var a: PerilEnemy = _swarm.spawn_artillery(BOUNDS, target)
	_place(a)
	a.fire_cooldown = 0.05
	_swarm.update_artillery(a, target, 0.1)
	assert_eq(_swarm.enemies.size(), 2, "one bullet spawned")
	var b: PerilEnemy = _swarm.enemies[1]
	assert_eq(b.type, Types.EnemyType.BULLET)
	assert_almost_eq(
		b.x, a.x + 22.0, 0.0001, "muzzle is 22 along the aim from the post-move position"
	)
	assert_almost_eq(b.y, a.y, 0.0001)
	assert_almost_eq(_speed(b), 260.0, 0.001)
	assert_almost_eq(b.radius, 5.5, 0.001)
	assert_lt(a.vx, -80.0, "recoil of 90 against the aim")
	assert_between(a.fire_cooldown, 2.8, 3.6, "reload is 2.8 + rand * 0.8, not the spawn value")


func test_spawn_bullet_flies_toward_its_target() -> void:
	var b: PerilEnemy = _swarm.spawn_bullet(100.0, 100.0, Vector2(100.0, 400.0))
	assert_eq(b.type, Types.EnemyType.BULLET)
	assert_almost_eq(b.vx, 0.0, 0.0001)
	assert_almost_eq(b.vy, 260.0, 0.0001)
	assert_almost_eq(b.radius, 5.5, 0.001)
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_almost_eq(b.y, 126.0, 0.0001, "flies straight; not clamped, not steered")


func test_bullets_expire_by_age_or_distance() -> void:
	var old: PerilEnemy = _swarm.spawn_bullet(500.0, 300.0, Vector2(600.0, 300.0))
	old.age = 4.5
	_swarm.spawn_bullet(-61.0, 300.0, Vector2(-100.0, 300.0))
	var live: PerilEnemy = _swarm.spawn_bullet(500.0, 300.0, Vector2(600.0, 300.0))
	_swarm.update(0.01, PLAYER, BOUNDS, _particles)
	assert_eq(_swarm.enemies.size(), 1, "age > 4.5 and x < -60 are both culled")
	assert_eq(_swarm.enemies[0], live)
