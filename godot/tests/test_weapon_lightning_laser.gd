## test_weapon_lightning_laser.gd
## PORTS: nothing — new file, covers lightning and laser in src/sim/weapon_system.gd
extends GutTest
## Covers lightning chain range and max targets per rank, the arc and branch
## records, arc fade-out; laser length and duration per rank, the sweep, and
## the cross-beam keystone.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)

var _player: PlayerShip = null
var _particles: ParticleEngine = null
var _grid: VectorGrid = null
var _audio: AudioBank = null
var _ws: WeaponSystem = null
var _killed: Array[PerilEnemy] = []
var _killed_by: Array[Types.WeaponType] = []


func before_each() -> void:
	_player = PlayerShip.new(500.0, 300.0)
	_player.angle = 0.0
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


func _activate(
	type: Types.WeaponType,
	x: float,
	y: float,
	enemies: Array[PerilEnemy],
	perks: ProgressionManager.WeaponPerks = null
) -> void:
	_ws.activate_weapon(
		type, x, y, _player, enemies, _particles, _grid, _audio, _on_killed(), perks
	)


func test_lightning_chains_within_the_rank_zero_range_and_stops_beyond_it() -> void:
	assert_almost_eq(Tuning.get_tuned_value("lightning", "chainRange", 0), 220.0, 0.001)
	var a: PerilEnemy = _enemy(1, 150.0, 100.0)
	var b: PerilEnemy = _enemy(2, 250.0, 100.0)
	var c: PerilEnemy = _enemy(3, 500.0, 100.0)
	var enemies: Array[PerilEnemy] = [a, b, c]
	_activate(Types.WeaponType.LIGHTNING, 100.0, 100.0, enemies)
	assert_eq(_killed.size(), 2, "50 then 100 px hops; the 250 px hop exceeds 220")
	assert_eq(_killed_by[0], Types.WeaponType.LIGHTNING)
	assert_eq(enemies.size(), 1)
	assert_eq(enemies[0].id, 3)
	assert_eq(_ws.lightning_arcs.size(), 2)
	var first: Types.LightningArc = _ws.lightning_arcs[0]
	assert_almost_eq(first.x1, 100.0, 0.001)
	assert_almost_eq(first.y1, 100.0, 0.001)
	assert_almost_eq(first.x2, 150.0, 0.001)
	assert_almost_eq(first.y2, 100.0, 0.001)
	assert_almost_eq(first.intensity, 1.0, 0.001)
	var second: Types.LightningArc = _ws.lightning_arcs[1]
	assert_almost_eq(second.x1, 150.0, 0.001, "the next arc starts at the last victim")
	assert_almost_eq(second.x2, 250.0, 0.001)


func test_lightning_branches_are_three_jittered_points_along_the_arc() -> void:
	var enemies: Array[PerilEnemy] = [_enemy(1, 300.0, 100.0)]
	_activate(Types.WeaponType.LIGHTNING, 100.0, 100.0, enemies)
	var arc: Types.LightningArc = _ws.lightning_arcs[0]
	assert_eq(arc.branches.size(), 3, "segments = 4, s in 1..3")
	for s: int in range(1, 4):
		var t: float = float(s) / 4.0
		var pt: Vector2 = arc.branches[s - 1]
		assert_between(pt.x, 100.0 + 200.0 * t - 12.0 - 0.001, 100.0 + 200.0 * t + 12.0 + 0.001)
		assert_between(pt.y, 100.0 - 12.0 - 0.001, 100.0 + 12.0 + 0.001, "(rand - 0.5) * 24")


func test_lightning_chain_range_rank_reaches_the_farther_enemy() -> void:
	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.lightning.chain_range = 3
	assert_almost_eq(Tuning.get_tuned_value("lightning", "chainRange", 3), 286.0, 0.001)
	var enemies: Array[PerilEnemy] = [
		_enemy(1, 150.0, 100.0), _enemy(2, 250.0, 100.0), _enemy(3, 500.0, 100.0)
	]
	_activate(Types.WeaponType.LIGHTNING, 100.0, 100.0, enemies, perks)
	assert_eq(_killed.size(), 3, "250 px is inside 286")
	assert_eq(_ws.lightning_arcs.size(), 3)


func test_lightning_max_targets_rank_extends_the_chain() -> void:
	var enemies: Array[PerilEnemy] = []
	for i: int in range(16):
		enemies.append(_enemy(i + 1, 110.0 + float(i) * 10.0, 100.0))
	_activate(Types.WeaponType.LIGHTNING, 100.0, 100.0, enemies)
	assert_eq(_killed.size(), int(Tuning.get_tuned_value("lightning", "maxTargets", 0)))
	assert_eq(_killed.size(), 14, "the table base")
	assert_eq(enemies.size(), 2)

	before_each()
	enemies = []
	for i: int in range(16):
		enemies.append(_enemy(i + 1, 110.0 + float(i) * 10.0, 100.0))
	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.lightning.max_targets = 1
	_activate(Types.WeaponType.LIGHTNING, 100.0, 100.0, enemies, perks)
	assert_eq(_killed.size(), 16, "17 chains at rank 1 clear all 16")
	assert_eq(enemies.size(), 0)


func test_lightning_arcs_fade_and_are_removed() -> void:
	var enemies: Array[PerilEnemy] = [_enemy(1, 150.0, 100.0)]
	_activate(Types.WeaponType.LIGHTNING, 100.0, 100.0, enemies)
	_ws.update(0.1, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_almost_eq(_ws.lightning_arcs[0].intensity, 0.6, 0.0001, "intensity -= dt * 4")
	_ws.update(0.2, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_eq(_ws.lightning_arcs.size(), 0, "removed at intensity <= 0")


func test_laser_length_and_duration_come_from_the_table_per_rank() -> void:
	_activate(Types.WeaponType.LASER, 0.0, 0.0, [])
	var w: Types.ActiveWeapon = _ws.active_weapons[0]
	assert_eq(w.type, Types.WeaponType.LASER)
	assert_almost_eq(w.x, 500.0, 0.001, "the beam is centred on the player, not the orb")
	assert_almost_eq(w.y, 300.0, 0.001)
	assert_almost_eq(w.radius, Tuning.get_tuned_value("laser", "length", 0), 0.001)
	assert_almost_eq(w.radius, 260.0, 0.001)
	assert_almost_eq(w.duration, Tuning.get_tuned_value("laser", "duration", 0), 0.001)
	assert_almost_eq(w.duration, 1.8, 0.001)
	assert_almost_eq(w.max_duration, 1.8, 0.001)
	assert_almost_eq(w.angle, 0.0, 0.001, "starts at the player's heading")

	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.laser.length = 5
	perks.laser.duration = 2
	_activate(Types.WeaponType.LASER, 0.0, 0.0, [], perks)
	var ranked: Types.ActiveWeapon = _ws.active_weapons[1]
	assert_almost_eq(ranked.radius, 360.0, 0.001, "rank 5 is the table max")
	assert_almost_eq(ranked.duration, 2.6, 0.001, "1.8 + 2 * 0.4")


func test_laser_sweeps_with_the_player_and_slices_along_the_beam() -> void:
	_activate(Types.WeaponType.LASER, 0.0, 0.0, [])
	var w: Types.ActiveWeapon = _ws.active_weapons[0]
	var on_beam: PerilEnemy = _enemy(1, 600.0, 300.0)
	var off_beam: PerilEnemy = _enemy(2, 500.0, 400.0)
	var beyond: PerilEnemy = _enemy(3, 900.0, 300.0)
	var enemies: Array[PerilEnemy] = [on_beam, off_beam, beyond]
	_player.x = 520.0
	_ws.update(0.01, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_almost_eq(w.x, 520.0, 0.001, "follows the ship")
	assert_almost_eq(w.angle, 0.01 * PI * 3.5, 0.0001, "spins at 3.5 pi rad/s")
	assert_eq(_killed.size(), 1)
	assert_eq(_killed[0].id, 1, "perp 8.8 px <= radius + 14")
	assert_eq(_killed_by[0], Types.WeaponType.LASER)
	assert_true(enemies.has(off_beam), "perp 99 px is off the beam")
	assert_true(enemies.has(beyond), "proj 378 px is past the 260 px half-length")


func test_laser_cross_beam_keystone_adds_the_perpendicular_beam() -> void:
	var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	perks.laser.cross_beam = true
	_activate(Types.WeaponType.LASER, 0.0, 0.0, [], perks)
	var off_beam: PerilEnemy = _enemy(2, 500.0, 400.0)
	var enemies: Array[PerilEnemy] = [off_beam]
	_ws.update(0.01, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_eq(_killed.size(), 1, "the perpendicular beam reaches it")
	assert_eq(enemies.size(), 0)


func test_laser_expires_after_its_duration() -> void:
	_activate(Types.WeaponType.LASER, 0.0, 0.0, [])
	_ws.update(1.9, _player, [], BOUNDS, _particles, _grid, _audio, _on_killed())
	assert_eq(_ws.active_weapons.size(), 0)
