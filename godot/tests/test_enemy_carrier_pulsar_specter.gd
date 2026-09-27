## test_enemy_carrier_pulsar_specter.gd
## PORTS: nothing — new file, covers carriers, pulsars, specters and kill
## reactions in src/sim/enemy_swarm.gd
extends GutTest
## Covers the carrier and its satellites, pulsar pulses and splitting, specter
## phasing, on_enemy_killed and freeze_all.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)

var _particles: ParticleEngine = null
var _swarm: EnemySwarm = null


func before_each() -> void:
	_particles = ParticleEngine.new()
	_swarm = EnemySwarm.new()


func _dist(a: PerilEnemy, b: PerilEnemy) -> float:
	return Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))


func test_spawn_carrier_brings_four_orbiting_satellites() -> void:
	var carrier: PerilEnemy = _swarm.spawn_carrier(BOUNDS, PLAYER)
	assert_eq(carrier.type, Types.EnemyType.CARRIER)
	assert_almost_eq(carrier.health, 4.0, 0.001)
	assert_almost_eq(carrier.radius, 18.0, 0.001)
	assert_eq(_swarm.enemies.size(), 5)
	for i: int in range(1, 5):
		var sat: PerilEnemy = _swarm.enemies[i]
		assert_eq(sat.type, Types.EnemyType.SEEKER)
		assert_eq(sat.parent_carrier_id, carrier.id)
		assert_almost_eq(sat.radius, 6.0, 0.001)
		assert_almost_eq(sat.orbit_radius, 38.0, 0.001)
		assert_almost_eq(sat.orbit_angle, float(i - 1) * TAU / 4.0, 0.0001)
		assert_almost_eq(_dist(sat, carrier), 38.0, 0.001)


func test_carrier_drifts_toward_the_player_and_carries_its_satellites() -> void:
	var carrier: PerilEnemy = _swarm.spawn_carrier(BOUNDS, PLAYER)
	carrier.x = 200.0
	carrier.y = 300.0
	_swarm.update_carrier(carrier, PLAYER, 0.1)
	assert_almost_eq(carrier.vx, 55.0 * 1.5 * 0.1, 0.0001, "target 55 eased by 1.5 * dt")
	for i: int in range(1, 5):
		var sat: PerilEnemy = _swarm.enemies[i]
		assert_almost_eq(_dist(sat, carrier), 38.0, 0.001)
		assert_eq(sat.vx, 0.0)
		assert_eq(sat.vy, 0.0)
		assert_almost_eq(sat.orbit_angle, float(i - 1) * TAU / 4.0 + 2.0 * 0.1, 0.0001)


func test_tethered_satellites_are_neither_clamped_nor_separated() -> void:
	var carrier: PerilEnemy = _swarm.spawn_carrier(BOUNDS, PLAYER)
	carrier.x = 30.0
	carrier.y = 300.0
	_swarm.update(0.01, PLAYER, BOUNDS, _particles)
	for i: int in range(1, 5):
		var sat: PerilEnemy = _swarm.enemies[i]
		assert_almost_eq(_dist(sat, carrier), 38.0, 0.001, "left on orbit even at x < 0")


func test_killing_a_carrier_frees_and_flings_its_satellites() -> void:
	var carrier: PerilEnemy = _swarm.spawn_carrier(BOUNDS, PLAYER)
	_swarm.on_enemy_killed(carrier, _particles)
	for i: int in range(1, 5):
		var sat: PerilEnemy = _swarm.enemies[i]
		assert_eq(sat.parent_carrier_id, Types.ABSENT)
		assert_between(Vector2(sat.vx, sat.vy).length(), 160.0, 240.0)
	assert_eq(_swarm.enemies.size(), 5, "the caller removes the carrier (TiltGame.ts:2021)")
	assert_eq(
		_particles.particles.size(),
		4 * 8 + 40 + 1,
		"8 sparks per satellite, a 40-spark explosion and its ring"
	)


func test_on_enemy_killed_tolerates_a_null_particle_engine() -> void:
	var carrier: PerilEnemy = _swarm.spawn_carrier(BOUNDS, PLAYER)
	_swarm.on_enemy_killed(carrier)
	assert_eq(_swarm.enemies[1].parent_carrier_id, Types.ABSENT)


func test_spawn_pulsar_and_periodic_pulse() -> void:
	var p: PerilEnemy = _swarm.spawn_pulsar(BOUNDS, PLAYER)
	assert_eq(p.type, Types.EnemyType.PULSAR)
	assert_almost_eq(p.health, 2.0, 0.001)
	assert_almost_eq(p.radius, 12.5, 0.001)
	assert_almost_eq(p.pulse_timer, 2.2, 0.001)
	p.x = 200.0
	p.y = 300.0
	for i: int in range(17):
		_swarm.update_pulsar(p, PLAYER, 0.125, _particles)
	assert_eq(_particles.particles.size(), 0, "2.125 s elapsed: no pulse yet")
	_swarm.update_pulsar(p, PLAYER, 0.125, _particles)
	assert_eq(_particles.particles.size(), 14, "one 14-spark pulse at 2.2 s")
	assert_almost_eq(p.pulse_timer, 2.2, 0.001, "timer re-armed")
	assert_gt(p.vx, 0.0, "drifts toward the player")


func test_killing_a_pulsar_splits_it_into_two_mini_seekers() -> void:
	var p: PerilEnemy = _swarm.spawn_pulsar(BOUNDS, PLAYER)
	p.x = 400.0
	p.y = 300.0
	_swarm.on_enemy_killed(p, _particles)
	assert_eq(_swarm.enemies.size(), 3)
	for i: int in range(1, 3):
		var mini: PerilEnemy = _swarm.enemies[i]
		assert_eq(mini.type, Types.EnemyType.SEEKER)
		assert_almost_eq(mini.radius, 6.5, 0.001)
		assert_almost_eq(_dist(mini, p), 10.0, 0.001)
		assert_between(Vector2(mini.vx, mini.vy).length(), 135.0, 180.0)
	assert_eq(_particles.particles.size(), 24 + 1, "24-spark explosion plus its ring")


func test_specter_phases_with_age() -> void:
	var s: PerilEnemy = _swarm.spawn_specter(BOUNDS, PLAYER)
	assert_eq(s.type, Types.EnemyType.SPECTER)
	assert_almost_eq(s.radius, 8.0, 0.001)
	assert_almost_eq(s.stealth_opacity, 0.8, 0.001)
	s.x = 200.0
	s.y = 300.0
	s.age = 0.5
	_swarm.update_specter(s, PLAYER, 0.1)
	assert_almost_eq(s.stealth_opacity, 0.25 + 0.75 * pow(sin(0.5 * 3.2), 2.0), 0.0001)
	assert_almost_eq(s.vx, 145.0 * 3.8 * 0.1, 0.0001, "target 145 eased by 3.8 * dt")


func test_freeze_all_halts_every_enemy_for_the_duration() -> void:
	var c: PerilEnemy = _swarm.spawn_charger(BOUNDS, PLAYER)
	_swarm.spawn_specter(BOUNDS, PLAYER)
	_swarm.freeze_all()
	for e: PerilEnemy in _swarm.enemies:
		assert_true(e.frozen)
		assert_almost_eq(e.freeze_timer, 7.0, 0.001)
	c.x = 300.0
	c.y = 300.0
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_almost_eq(c.x, 300.0, 0.0001, "frozen enemies do not move")
	assert_almost_eq(c.freeze_timer, 6.9, 0.001)
	_swarm.freeze_all(0.05)
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_false(c.frozen, "thaws when the timer runs out")
