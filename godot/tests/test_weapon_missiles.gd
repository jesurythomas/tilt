## test_weapon_missiles.gd
## PORTS: nothing — new file, covers the missiles weapon in src/sim/weapon_system.gd
extends GutTest
## Covers missile launch (count and speed per rank), homing guidance, target
## reacquisition, the smoke trail, and the blast radius per rank.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)

var _player: PlayerShip = null
var _particles: ParticleEngine = null
var _grid: VectorGrid = null
var _audio: AudioBank = null
var _ws: WeaponSystem = null
var _killed: Array[PerilEnemy] = []
var _killed_by: Array[Types.WeaponType] = []
var _last_kills: int = 0


func before_each() -> void:
	_player = PlayerShip.new(-500.0, -500.0)
	_particles = ParticleEngine.new()
	_grid = VectorGrid.new(1000.0, 600.0)
	_audio = AudioBank.new()
	_ws = WeaponSystem.new()
	_killed = []
	_killed_by = []


func _on_killed() -> Callable:
	return func(e: PerilEnemy, w: Types.WeaponType) -> void:
		_killed.append(e)
		_killed_by.append(w)


func _enemy(id: int, x: float, y: float) -> PerilEnemy:
	var e: PerilEnemy = PerilEnemy.new()
	e.id = id
	e.x = x
	e.y = y
	e.radius = 8.0
	return e


func _missile(x: float, y: float, lifetime: float) -> Types.HomingMissile:
	var m: Types.HomingMissile = Types.HomingMissile.new()
	m.id = 1
	m.x = x
	m.y = y
	m.lifetime = lifetime
	_ws.missiles.append(m)
	return m


func test_launch_count_and_speed_come_from_the_table_at_rank_zero() -> void:
	_ws.activate_weapon(
		Types.WeaponType.MISSILES,
		500.0,
		300.0,
		_player,
		[],
		_particles,
		_grid,
		_audio,
		_on_killed()
	)
	assert_eq(_ws.missiles.size(), int(Tuning.get_tuned_value("missiles", "count", 0)))
	assert_eq(_ws.missiles.size(), 8, "the table base")
	assert_eq(_ws.active_weapons.size(), 0, "missiles are not an ActiveWeapon")
	for m: Types.HomingMissile in _ws.missiles:
		assert_almost_eq(m.x, 500.0, 0.001)
		assert_almost_eq(m.y, 300.0, 0.001)
		assert_almost_eq(m.lifetime, 3.5, 0.001, "WeaponSystem.ts:430")
		assert_eq(m.smoke_timer, 0.0)
		assert_eq(m.target_id, Types.ABSENT, "targetId: null")
		var speed: float = Vector2(m.vx, m.vy).length()
		assert_between(speed, 260.0 - 0.001, 340.0 + 0.001, "(260 + rand * 80) at scale 1")
	var ids: Array[int] = []
	for m: Types.HomingMissile in _ws.missiles:
		assert_false(ids.has(m.id), "ids are unique")
		ids.append(m.id)


func test_launch_ranks_change_count_and_speed() -> void:
	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.missiles.count = 3
	perks.missiles.flight_speed = 3
	_ws.activate_weapon(
		Types.WeaponType.MISSILES,
		500.0,
		300.0,
		_player,
		[],
		_particles,
		_grid,
		_audio,
		_on_killed(),
		perks
	)
	assert_eq(_ws.missiles.size(), int(Tuning.get_tuned_value("missiles", "count", 3)))
	assert_eq(_ws.missiles.size(), 11)
	for m: Types.HomingMissile in _ws.missiles:
		var speed: float = Vector2(m.vx, m.vy).length()
		assert_between(speed, 260.0 * 1.6 - 0.001, 340.0 * 1.6 + 0.001, "1 + 3 * 0.2")


func test_missiles_fan_out_around_the_circle() -> void:
	_ws.activate_weapon(
		Types.WeaponType.MISSILES,
		500.0,
		300.0,
		_player,
		[],
		_particles,
		_grid,
		_audio,
		_on_killed()
	)
	for i: int in range(8):
		var m: Types.HomingMissile = _ws.missiles[i]
		var expected: float = float(i) * TAU / 8.0
		var actual: float = atan2(m.vy, m.vx)
		var diff: float = absf(angle_difference(expected, actual))
		assert_lte(diff, 0.2 + 0.0001, "jitter is (rand * 0.4 - 0.2)")


func test_homing_acquires_the_nearest_enemy_and_steers() -> void:
	var m: Types.HomingMissile = _missile(100.0, 100.0, 3.5)
	var far: PerilEnemy = _enemy(7, 100.0, 500.0)
	var near: PerilEnemy = _enemy(9, 300.0, 100.0)
	var enemies: Array[PerilEnemy] = [far, near]
	_ws.update(0.1, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_eq(m.target_id, 9, "closest enemy becomes the target")
	assert_almost_eq(m.vx, 396.0, 0.001, "(440 - 0) * 0.1 * 9")
	assert_almost_eq(m.vy, 0.0, 0.001)
	assert_almost_eq(m.x, 139.6, 0.001, "moved by vx * dt")
	assert_eq(enemies.size(), 2, "no hit yet")
	assert_eq(_ws.missiles.size(), 1)


func test_homing_keeps_its_target_while_it_lives_and_retargets_when_it_dies() -> void:
	var m: Types.HomingMissile = _missile(100.0, 100.0, 3.5)
	m.target_id = 7
	var far: PerilEnemy = _enemy(7, 100.0, 500.0)
	var near: PerilEnemy = _enemy(9, 300.0, 100.0)
	var enemies: Array[PerilEnemy] = [far, near]
	_ws.update(0.01, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_eq(m.target_id, 7, "an existing live target is kept even if farther")
	assert_gt(m.vy, 0.0, "steers toward the far one")
	enemies.erase(far)
	_ws.update(0.01, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_eq(m.target_id, 9, "reacquires the nearest survivor")


func test_smoke_trail_emits_every_thirty_milliseconds() -> void:
	var m: Types.HomingMissile = _missile(100.0, 100.0, 3.5)
	_ws.update(0.02, _player, [], BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_eq(_particles.particles.size(), 0, "0.02 is under the 0.03 threshold")
	assert_almost_eq(m.smoke_timer, 0.02, 0.0001)
	_ws.update(0.02, _player, [], BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_eq(_particles.particles.size(), 1, "one smoke mote")
	assert_eq(m.smoke_timer, 0.0, "timer resets")


func test_expiry_detonates_with_the_rank_zero_blast_radius() -> void:
	_missile(100.0, 100.0, 0.01)
	var inside: PerilEnemy = _enemy(1, 130.0, 100.0)
	var outside: PerilEnemy = _enemy(2, 155.0, 100.0)
	var enemies: Array[PerilEnemy] = [inside, outside]
	_ws.update(0.02, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_eq(_ws.missiles.size(), 0, "missile consumed")
	assert_eq(_killed.size(), 1)
	assert_eq(_killed[0].id, 1, "28 px away is inside the 40 px blast")
	assert_eq(_killed_by[0], Types.WeaponType.MISSILES)
	assert_eq(enemies.size(), 1)
	assert_eq(enemies[0].id, 2, "53 px away survives rank 0")


func test_blast_radius_rank_reaches_the_farther_enemy() -> void:
	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.missiles.blast_radius = 3
	assert_almost_eq(Tuning.get_tuned_value("missiles", "blastRadius", 3), 58.0, 0.001)
	_missile(100.0, 100.0, 0.01)
	var inside: PerilEnemy = _enemy(1, 130.0, 100.0)
	var outside: PerilEnemy = _enemy(2, 155.0, 100.0)
	var enemies: Array[PerilEnemy] = [inside, outside]
	_ws.update(0.02, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed(), perks)
	assert_eq(_killed.size(), 2, "53 px is inside the 58 px blast at rank 3")
	assert_eq(enemies.size(), 0)


func test_contact_detonates_before_expiry() -> void:
	_missile(100.0, 100.0, 3.5)
	var touching: PerilEnemy = _enemy(1, 112.0, 100.0)
	var enemies: Array[PerilEnemy] = [touching]
	_ws.update(0.001, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_eq(_ws.missiles.size(), 0, "within radius + 8 is a hit")
	assert_eq(_killed.size(), 1)


## M11c P32: 16 missiles into 150 enemies (seekers and pulsars, which split on death),
## 360 ticks; hashes every missile's position each tick and the kill order.
func _missile_run_hash() -> String:
	seed(2468)
	var swarm: EnemySwarm = EnemySwarm.new()
	var bounds: Vector2 = Vector2(1600.0, 900.0)
	for i: int in range(150):
		if i % 15 == 0:
			swarm.spawn_pulsar(bounds, Vector2.ZERO)
			swarm.enemies[-1].x = 500.0 + randf() * 600.0
			swarm.enemies[-1].y = 200.0 + randf() * 500.0
		else:
			swarm.spawn_seeker(bounds, 500.0 + randf() * 600.0, 200.0 + randf() * 500.0)
	var weapons: WeaponSystem = WeaponSystem.new()
	var player: PlayerShip = PlayerShip.new(800.0, 450.0)
	var particles: ParticleEngine = ParticleEngine.new()
	var grid: VectorGrid = VectorGrid.new(bounds.x, bounds.y)
	var audio: AudioBank = AudioBank.new()
	var kills: PackedInt64Array = PackedInt64Array()
	var on_kill: Callable = func(e: PerilEnemy, _w: Types.WeaponType) -> void:
		kills.append(e.id)
		swarm.on_enemy_killed(e, particles)
	weapons.trigger_weapon(
		Types.WeaponType.MISSILES,
		800.0,
		450.0,
		player,
		swarm.enemies,
		particles,
		grid,
		audio,
		on_kill
	)
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for tick: int in range(360):
		weapons._orb_spawn_timer = 1.0e9
		weapons.update(1.0 / 120.0, player, swarm.enemies, bounds, particles, grid, audio, on_kill)
		var row: PackedFloat64Array = PackedFloat64Array([float(tick)])
		for m: Types.HomingMissile in weapons.missiles:
			row.append_array([m.x, m.y, m.vx, m.vy, float(m.target_id)])
		ctx.update(row.to_byte_array())
	ctx.update(kills.to_byte_array())
	ctx.update(var_to_bytes(swarm.enemies.size()))
	_last_kills = kills.size()
	return ctx.finish().hex_encode()


func test_missiles_match_the_pre_p32_full_scans() -> void:
	# Recorded from the pre-P32 code (full target/contact scans), 2026-09-27.
	assert_eq(
		_missile_run_hash(),
		"bcf1798be2b93dc3d14bfc31385a86943b4cf8b5b57835ac7aa54ee5d5375149",
		"the snapshot scans change nothing"
	)
	assert_gte(_last_kills, 15, "the run kills enough to exercise retargets and splits")
