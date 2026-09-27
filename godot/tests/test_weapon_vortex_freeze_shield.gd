## test_weapon_vortex_freeze_shield.gd
## PORTS: nothing — new file, covers vortex, freeze and shield in src/sim/weapon_system.gd
extends GutTest
## Covers the vortex's radius and duration per rank, its pull, singularity
## kill, gravity rank, collapse shockwave and supernova keystone, the
## event-horizon cloak; the freeze's marks and duration per rank; the
## shield's duration per rank.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)

var _player: PlayerShip = null
var _particles: ParticleEngine = null
var _grid: VectorGrid = null
var _audio: AudioBank = null
var _ws: WeaponSystem = null
var _killed: Array[Types.Enemy] = []
var _killed_by: Array[Types.WeaponType] = []
var _last_vortex_kills: int = 0


func before_each() -> void:
	_player = PlayerShip.new(-500.0, -500.0)
	_particles = ParticleEngine.new()
	_grid = VectorGrid.new(1000.0, 600.0)
	_audio = AudioBank.new()
	_ws = WeaponSystem.new()
	_killed = []
	_killed_by = []


func _on_killed() -> Callable:
	return func(e: Types.Enemy, w: Types.WeaponType) -> void:
		_killed.append(e)
		_killed_by.append(w)


func _enemy(id: int, x: float, y: float) -> Types.Enemy:
	var e: Types.Enemy = Types.Enemy.new()
	e.id = id
	e.x = x
	e.y = y
	e.radius = 8.0
	return e


func _activate(
	type: Types.WeaponType,
	x: float,
	y: float,
	enemies: Array[Types.Enemy],
	perks: ProgressionManager.WeaponPerks = null
) -> void:
	_ws.activate_weapon(
		type, x, y, _player, enemies, _particles, _grid, _audio, _on_killed(), perks
	)


func _update(
	enemies: Array[Types.Enemy], dt: float, perks: ProgressionManager.WeaponPerks = null
) -> void:
	_ws.update(dt, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed(), perks)


func test_vortex_radius_and_duration_come_from_the_table_per_rank() -> void:
	_activate(Types.WeaponType.VORTEX, 500.0, 300.0, [])
	var w: Types.ActiveWeapon = _ws.active_weapons[0]
	assert_eq(w.type, Types.WeaponType.VORTEX)
	assert_almost_eq(w.radius, Tuning.get_tuned_value("blackhole", "radius", 0), 0.001)
	assert_almost_eq(w.radius, 340.0, 0.001)
	assert_almost_eq(w.duration, Tuning.get_tuned_value("blackhole", "duration", 0), 0.001)
	assert_almost_eq(w.duration, 4.8, 0.001)
	assert_almost_eq(w.max_duration, 4.8, 0.001)

	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.blackhole.radius = 2
	perks.blackhole.duration = 2
	_activate(Types.WeaponType.VORTEX, 500.0, 300.0, [], perks)
	var ranked: Types.ActiveWeapon = _ws.active_weapons[1]
	assert_almost_eq(ranked.radius, 376.0, 0.001, "340 + 2 * 18")
	assert_almost_eq(ranked.duration, 5.8, 0.001, "4.8 + 2 * 0.5")


func test_vortex_pulls_an_enemy_inward_and_spins_it() -> void:
	_activate(Types.WeaponType.VORTEX, 500.0, 300.0, [])
	var e: Types.Enemy = _enemy(1, 600.0, 300.0)
	var enemies: Array[Types.Enemy] = [e]
	_update(enemies, 0.1)
	assert_eq(enemies.size(), 1, "100 px out is beyond the 30 px horizon")
	var t: float = 1.0 - 100.0 / 340.0
	assert_almost_eq(e.x, 600.0 - (90.0 + 340.0 * t) * 0.1, 0.001, "direct suction")
	assert_almost_eq(e.vx, -(450.0 + 1350.0 * t * t) * 0.1, 0.001, "inward gravity")
	assert_almost_eq(e.vy, -(300.0 + 750.0 * t) * 0.1, 0.001, "tangential swirl")


func test_vortex_gravity_rank_multiplies_the_pull() -> void:
	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.blackhole.gravity = 5
	_activate(Types.WeaponType.VORTEX, 500.0, 300.0, [], perks)
	var e: Types.Enemy = _enemy(1, 600.0, 300.0)
	var enemies: Array[Types.Enemy] = [e]
	_update(enemies, 0.1, perks)
	var t: float = 1.0 - 100.0 / 340.0
	assert_almost_eq(e.x, 600.0 - (90.0 + 340.0 * t) * 0.1 * 2.0, 0.001, "1 + 5 * 0.2")


func test_vortex_kills_inside_the_event_horizon() -> void:
	_activate(Types.WeaponType.VORTEX, 500.0, 300.0, [])
	var enemies: Array[Types.Enemy] = [_enemy(1, 510.0, 300.0)]
	_update(enemies, 0.1)
	assert_eq(_killed.size(), 1, "10 px is inside the 30 px horizon")
	assert_eq(_killed_by[0], Types.WeaponType.VORTEX)
	assert_eq(enemies.size(), 0)


func test_vortex_collapse_shockwave_reaches_260_px() -> void:
	_activate(Types.WeaponType.VORTEX, 500.0, 300.0, [])
	_ws.active_weapons[0].duration = 0.05
	var near: Types.Enemy = _enemy(1, 700.0, 300.0)
	var far: Types.Enemy = _enemy(2, 800.0, 300.0)
	var enemies: Array[Types.Enemy] = [near, far]
	_update(enemies, 0.1)
	assert_eq(_ws.active_weapons.size(), 0, "the vortex is spent")
	assert_eq(_killed.size(), 1)
	assert_eq(_killed[0].id, 1, "pulled to 677 px, inside 260")
	assert_eq(enemies.size(), 1)
	assert_eq(enemies[0].id, 2, "pulled to 787 px, 287 from centre, outside 260")


func test_vortex_supernova_keystone_widens_the_collapse() -> void:
	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.blackhole.supernova_collapse = true
	_activate(Types.WeaponType.VORTEX, 500.0, 300.0, [], perks)
	_ws.active_weapons[0].duration = 0.05
	var enemies: Array[Types.Enemy] = [_enemy(1, 700.0, 300.0), _enemy(2, 800.0, 300.0)]
	_update(enemies, 0.1, perks)
	assert_almost_eq(Tuning.SUPERNOVA_SHOCKWAVE, 320.0, 0.001)
	assert_eq(_killed.size(), 2, "287 px is inside the 320 px supernova")


func test_vortex_cloak_keystone_shields_the_player_inside() -> void:
	_player = PlayerShip.new(520.0, 300.0)
	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.blackhole.invulnerable_inside = true
	_activate(Types.WeaponType.VORTEX, 500.0, 300.0, [], perks)
	assert_false(_player.has_shield())
	_update([], 0.1, perks)
	assert_true(_player.has_shield(), "inside the pull radius")
	assert_almost_eq(_player.shield_timer, 0.3, 0.001, "refreshed to 0.3 s")


func test_freeze_marks_every_enemy_with_the_table_duration_per_rank() -> void:
	var enemies: Array[Types.Enemy] = [_enemy(1, 100.0, 100.0), _enemy(2, 900.0, 500.0)]
	_activate(Types.WeaponType.FREEZE, 500.0, 300.0, enemies)
	assert_eq(_ws.active_weapons.size(), 0, "freeze is instantaneous")
	assert_eq(enemies.size(), 2, "nothing is killed")
	for e: Types.Enemy in enemies:
		assert_true(e.frozen)
		assert_almost_eq(e.freeze_timer, Tuning.get_tuned_value("freeze", "duration", 0), 0.001)
		assert_almost_eq(e.freeze_timer, 4.5, 0.001)
		assert_false(e.chilled, "WeaponSystem.ts never writes chilled")
	assert_gt(_particles.particles.size(), 0, "ice shatter burst")

	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.freeze.duration = 2
	_activate(Types.WeaponType.FREEZE, 500.0, 300.0, enemies, perks)
	for e: Types.Enemy in enemies:
		assert_almost_eq(e.freeze_timer, 5.9, 0.001, "4.5 + 2 * 0.7")


func test_shield_duration_comes_from_the_table_per_rank() -> void:
	_activate(Types.WeaponType.SHIELD, 500.0, 300.0, [])
	assert_eq(_ws.active_weapons.size(), 0, "shield lives on the player")
	assert_true(_player.has_shield())
	assert_almost_eq(_player.shield_timer, Tuning.get_tuned_value("shield", "duration", 0), 0.001)
	assert_almost_eq(_player.shield_timer, 6.0, 0.001)

	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.shield.duration = 3
	_activate(Types.WeaponType.SHIELD, 500.0, 300.0, [], perks)
	assert_almost_eq(_player.shield_timer, 9.0, 0.001, "6 + 3 * 1; max() keeps the longer")


## M11c P33: a vortex among 150 seekers for 240 ticks (the pull, kills inside 30 px
## and the collapse); hashes every enemy's x/y/vx/vy each 10 ticks and the kill order.
func _vortex_run_hash() -> String:
	seed(1357)
	var swarm: EnemySwarm = EnemySwarm.new()
	var bounds: Vector2 = Vector2(1600.0, 900.0)
	for i: int in range(150):
		swarm.spawn_seeker(bounds, 400.0 + randf() * 800.0, 150.0 + randf() * 600.0)
		swarm.enemies[-1].vx = randf() * 200.0 - 100.0
		swarm.enemies[-1].vy = randf() * 200.0 - 100.0
	var weapons: WeaponSystem = WeaponSystem.new()
	var player: PlayerShip = PlayerShip.new(800.0, 450.0)
	var particles: ParticleEngine = ParticleEngine.new()
	var grid: VectorGrid = VectorGrid.new(bounds.x, bounds.y)
	var audio: AudioBank = AudioBank.new()
	var kills: PackedInt64Array = PackedInt64Array()
	var on_kill: Callable = func(e: Types.Enemy, _w: Types.WeaponType) -> void: kills.append(e.id)
	weapons.trigger_weapon(
		Types.WeaponType.VORTEX,
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
	for tick: int in range(240):
		weapons._orb_spawn_timer = 1.0e9
		weapons.update(1.0 / 120.0, player, swarm.enemies, bounds, particles, grid, audio, on_kill)
		if tick % 10 == 9:
			var row: PackedFloat64Array = PackedFloat64Array([float(tick)])
			for e: Types.Enemy in swarm.enemies:
				row.append_array([e.x, e.y, e.vx, e.vy])
			ctx.update(row.to_byte_array())
	ctx.update(var_to_bytes(kills))
	_last_vortex_kills = kills.size()
	return ctx.finish().hex_encode()


func test_vortex_matches_the_pre_p33_field_access() -> void:
	# Recorded from the pre-P33 code (field-by-field reads and writes), 2026-09-27.
	assert_eq(
		_vortex_run_hash(),
		"017f0fc905ddef87140591f7f6dfd8cb0833c2097af3ac4609969903a2fdb138",
		"the field locals change nothing"
	)
	assert_gte(_last_vortex_kills, 15, "the run kills enough to exercise the kill branch")
