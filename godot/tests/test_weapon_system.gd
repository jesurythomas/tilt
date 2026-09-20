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

	var enemies: Array[Types.Enemy] = []
	ws.update(
		0.016,
		_player,
		enemies,
		bounds,
		_particles,
		_grid,
		_audio,
		func(_e: Types.Enemy, _w: Types.WeaponType) -> void: pass
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
		func(_e: Types.Enemy, _w: Types.WeaponType) -> void: pass
	)
	assert_eq(ws.active_weapons.size(), 1)

	# Create enemy within blast radius (e.g. 50px away)
	var e: Types.Enemy = Types.Enemy.new()
	e.id = 99
	e.x = 550.0
	e.y = 300.0
	e.radius = 8.5
	var enemies: Array[Types.Enemy] = [e]

	var killed_enemies: Array[Types.Enemy] = []
	var killed_weapons: Array[Types.WeaponType] = []
	var on_killed: Callable = func(enemy: Types.Enemy, weapon: Types.WeaponType) -> void:
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
		func(_e: Types.Enemy, _w: Types.WeaponType) -> void: pass
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
		func(_e: Types.Enemy, _w: Types.WeaponType) -> void: pass
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
		func(_e: Types.Enemy, _w: Types.WeaponType) -> void: pass
	)
	assert_eq(ws.orbs.size(), 1)
	assert_eq(ws.active_weapons.size(), 1)

	ws.reset()
	assert_eq(ws.orbs.size(), 0)
	assert_eq(ws.active_weapons.size(), 0)
