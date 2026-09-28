## test_weapon_system.gd
## PORTS: nothing — new file, covers src/sim/weapon_system.gd
extends GutTest
## Proves WeaponSystem orb spawning, pickup detection, and nuke detonation.

var _player: PlayerShip = null
var _particles: ParticleEngine = null
var _grid: VectorGrid = null
var _audio: AudioBank = null


func before_each() -> void:
	_player = PlayerShip.new(500.0, 300.0)
	_particles = ParticleEngine.new()
	_grid = VectorGrid.new(1000.0, 600.0)
	_audio = AudioBank.new()


func test_spawn_orb_creates_nuke_orb() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var orb: Types.WeaponOrb = ws.spawn_orb(bounds, Types.WeaponType.NUKE, 200.0, 200.0)
	assert_eq(ws.orbs.size(), 1)
	assert_eq(orb.type, Types.WeaponType.NUKE)
	assert_almost_eq(orb.radius, 16.0, 0.001)
	assert_almost_eq(orb.lifetime, 12.0, 0.001)


func test_orb_collected_when_player_touches_it() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	# Spawn orb right on player (500, 300)
	ws.spawn_orb(bounds, Types.WeaponType.NUKE, 500.0, 300.0)

	var activated_types: Array[Types.WeaponType] = []
	ws.on_weapon_activated = func(type: Types.WeaponType) -> void: activated_types.append(type)

	var enemies: Array[PerilEnemy] = []
	ws.update(
		0.016,
		_player,
		enemies,
		bounds,
		_particles,
		_grid,
		_audio,
		func(_e: PerilEnemy, _w: Types.WeaponType) -> void: pass
	)

	assert_eq(ws.orbs.size(), 0, "orb consumed upon contact")
	assert_eq(activated_types.size(), 1, "weapon activated callback fired")
	assert_eq(activated_types[0], Types.WeaponType.NUKE)
	assert_eq(ws.active_weapons.size(), 1, "active nuke weapon spawned")
	assert_eq(ws.active_weapons[0].type, Types.WeaponType.NUKE)


func test_nuke_expands_and_vaporizes_enemies_in_radius() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)

	# Direct activation of nuke at (500, 300)
	ws.activate_weapon(
		Types.WeaponType.NUKE,
		500.0,
		300.0,
		_player,
		[],
		_particles,
		_grid,
		_audio,
		func(_e: PerilEnemy, _w: Types.WeaponType) -> void: pass
	)
	assert_eq(ws.active_weapons.size(), 1)

	# Create enemy within blast radius (e.g. 50px away)
	var e: PerilEnemy = PerilEnemy.new()
	e.id = 99
	e.x = 550.0
	e.y = 300.0
	e.radius = 8.5
	var enemies: Array[PerilEnemy] = [e]

	var killed_enemies: Array[PerilEnemy] = []
	var killed_weapons: Array[Types.WeaponType] = []
	var on_killed: Callable = func(enemy: PerilEnemy, weapon: Types.WeaponType) -> void:
		killed_enemies.append(enemy)
		killed_weapons.append(weapon)

	# Update nuke halfway through duration (0.3s)
	ws.update(0.3, _player, enemies, bounds, _particles, _grid, _audio, on_killed)

	assert_eq(killed_enemies.size(), 1, "enemy in blast radius killed")
	assert_eq(killed_weapons[0], Types.WeaponType.NUKE)
	assert_eq(enemies.size(), 0, "enemy removed from array")


func test_nuke_expires_after_duration() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	ws.activate_weapon(
		Types.WeaponType.NUKE,
		100.0,
		100.0,
		_player,
		[],
		_particles,
		_grid,
		_audio,
		func(_e: PerilEnemy, _w: Types.WeaponType) -> void: pass
	)
	assert_eq(ws.active_weapons.size(), 1)

	ws.update(
		0.7,
		_player,
		[],
		bounds,
		_particles,
		_grid,
		_audio,
		func(_e: PerilEnemy, _w: Types.WeaponType) -> void: pass
	)
	assert_eq(ws.active_weapons.size(), 0, "nuke removed when duration expires")


func test_reset_clears_orbs_and_active_weapons() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	ws.spawn_orb(bounds)
	ws.activate_weapon(
		Types.WeaponType.NUKE,
		100.0,
		100.0,
		_player,
		[],
		_particles,
		_grid,
		_audio,
		func(_e: PerilEnemy, _w: Types.WeaponType) -> void: pass
	)
	assert_eq(ws.orbs.size(), 1)
	assert_eq(ws.active_weapons.size(), 1)

	ws.reset()
	assert_eq(ws.orbs.size(), 0)
	assert_eq(ws.active_weapons.size(), 0)


func _no_kill() -> Callable:
	return func(_e: PerilEnemy, _w: Types.WeaponType) -> void: pass


func test_nuke_radius_and_speed_come_from_the_tuning_table_per_rank() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	ws.activate_weapon(
		Types.WeaponType.NUKE, 100.0, 100.0, _player, [], _particles, _grid, _audio, _no_kill()
	)
	var base: Types.ActiveWeapon = ws.active_weapons[0]
	assert_almost_eq(base.max_radius, Tuning.get_tuned_value("nuke", "radius", 0), 0.001)
	assert_almost_eq(base.max_radius, 360.0, 0.001, "rank 0 is the table base")
	assert_almost_eq(base.duration, 0.65, 0.001, "WeaponSystem.ts:402 at speed rank 0")

	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.nuke.radius = 5
	perks.nuke.speed = 3
	ws.activate_weapon(
		Types.WeaponType.NUKE,
		100.0,
		100.0,
		_player,
		[],
		_particles,
		_grid,
		_audio,
		_no_kill(),
		perks
	)
	var ranked: Types.ActiveWeapon = ws.active_weapons[1]
	assert_almost_eq(ranked.max_radius, Tuning.get_tuned_value("nuke", "radius", 5), 0.001)
	assert_almost_eq(ranked.max_radius, 470.0, 0.001, "rank 5 is the table max")
	assert_almost_eq(ranked.duration, 0.65 / 1.75, 0.0001, "0.65 / (1 + 3 * 0.25)")
	assert_almost_eq(ranked.max_duration, ranked.duration, 0.0001)


func test_nuke_scale_multiplies_the_tuned_radius() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	ws.set_scale(1.5)
	ws.activate_weapon(
		Types.WeaponType.NUKE, 100.0, 100.0, _player, [], _particles, _grid, _audio, _no_kill()
	)
	assert_almost_eq(ws.active_weapons[0].max_radius, 360.0 * 1.5, 0.001)
	assert_almost_eq(ws.active_weapons[0].radius, 10.0 * 1.5, 0.001, "WeaponSystem.ts:410")


func test_trigger_weapon_activates_without_a_kill_callback() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	ws.trigger_weapon(Types.WeaponType.NUKE, 100.0, 100.0, _player, [], _particles, _grid, _audio)
	assert_eq(ws.active_weapons.size(), 1)
	assert_eq(ws.active_weapons[0].type, Types.WeaponType.NUKE)
	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.nuke.radius = 2
	ws.trigger_weapon(
		Types.WeaponType.NUKE,
		100.0,
		100.0,
		_player,
		[],
		_particles,
		_grid,
		_audio,
		Callable(),
		perks
	)
	assert_almost_eq(ws.active_weapons[1].max_radius, 404.0, 0.001, "perks reach activate_weapon")


func test_random_weapon_type_follows_the_weighted_table() -> void:
	seed(20260921)
	var ws: WeaponSystem = WeaponSystem.new()
	var counts: Dictionary[Types.WeaponType, int] = {}
	for i: int in range(2000):
		var t: Types.WeaponType = ws.get_random_weapon_type()
		counts[t] = counts.get(t, 0) + 1
	assert_eq(counts.size(), 7, "every weapon is drawn")
	assert_gt(counts[Types.WeaponType.MISSILES], 280, "20/109 of 2000 is 367")
	assert_lt(counts[Types.WeaponType.VORTEX], 200, "5/109 of 2000 is 92 — the rare drop")
	assert_gt(counts[Types.WeaponType.VORTEX], 30)


func test_orb_spawning_draws_from_the_drop_table_not_only_nuke() -> void:
	seed(20260921)
	var ws: WeaponSystem = WeaponSystem.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var far_player: PlayerShip = PlayerShip.new(-500.0, -500.0)
	var seen: Dictionary[Types.WeaponType, bool] = {}
	for i: int in range(40):
		ws.reset()
		ws.update(2.0, far_player, [], bounds, _particles, _grid, _audio, _no_kill())
		for orb: Types.WeaponOrb in ws.orbs:
			seen[orb.type] = true
	assert_gt(seen.size(), 1, "M2's stub returned NUKE only")


func _tick(ws: WeaponSystem, seconds: float) -> void:
	var enemies: Array[PerilEnemy] = []
	for i: int in range(roundi(seconds * 120.0)):
		ws.update(
			1.0 / 120.0,
			_player,
			enemies,
			Vector2(1000.0, 600.0),
			_particles,
			_grid,
			_audio,
			func(_e: PerilEnemy, _w: Types.WeaponType) -> void: pass
		)


## ORB R1 (user: "add a magnetic field similar to the coins to the power ups"): an orb
## inside the field flies to the ship and is picked up; one outside it stays put.
func test_the_orb_magnet_pulls_a_near_orb_in() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	ws.spawn_orb(bounds, Types.WeaponType.LASER, 500.0 + 150.0, 300.0)
	var far: Types.WeaponOrb = ws.spawn_orb(bounds, Types.WeaponType.NUKE, 500.0, 300.0 - 250.0)
	var activated: Array[Types.WeaponType] = []
	ws.on_weapon_activated = func(type: Types.WeaponType) -> void: activated.append(type)
	_tick(ws, 0.05)
	assert_lt(ws.orbs[0].x, 650.0, "the near orb moved toward the ship")
	_tick(ws, 1.0)
	assert_eq(activated, [Types.WeaponType.LASER], "pulled in and picked up")
	assert_eq(ws.orbs.size(), 1)
	assert_eq(far.y, 50.0, "outside the field it stays put")


func test_the_orb_magnet_can_be_turned_off() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	ws.orb_magnet_radius = 0.0
	var orb: Types.WeaponOrb = ws.spawn_orb(
		Vector2(1000.0, 600.0), Types.WeaponType.LASER, 600.0, 300.0
	)
	_tick(ws, 0.5)
	assert_eq(orb.x, 600.0, "TS rules: orbs never move")
