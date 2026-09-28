## test_keystones.gd
## KEY R1 (user 2026-09-28: "make sure abilities have atleast 3 keystones each"): every
## keystone the TS never coded does what its Armory card says, and nothing without it.
extends GutTest

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)

var _player: PlayerShip = null
var _particles: ParticleEngine = null
var _grid: VectorGrid = null
var _audio: AudioBank = null
var _ws: WeaponSystem = null
var _killed: Array[PerilEnemy] = []


func before_each() -> void:
	seed(7)
	_player = PlayerShip.new(-500.0, -500.0)
	_particles = ParticleEngine.new()
	_grid = VectorGrid.new(1000.0, 600.0)
	_audio = AudioBank.new()
	_ws = WeaponSystem.new()
	_killed = []


func _on_killed() -> Callable:
	return func(e: PerilEnemy, _w: Types.WeaponType) -> void: _killed.append(e)


func _enemy(id: int, x: float, y: float) -> PerilEnemy:
	var e: PerilEnemy = PerilEnemy.new()
	e.id = id
	e.x = x
	e.y = y
	e.radius = 8.0
	return e


func _perks() -> ProgressionManager.WeaponPerks:
	return ProgressionManager.WeaponPerks.new()


func _activate(
	type: Types.WeaponType,
	x: float,
	y: float,
	enemies: Array[PerilEnemy],
	perks: ProgressionManager.WeaponPerks
) -> void:
	_ws.activate_weapon(
		type, x, y, _player, enemies, _particles, _grid, _audio, _on_killed(), perks
	)


func _update(enemies: Array[PerilEnemy], dt: float, perks: ProgressionManager.WeaponPerks) -> void:
	_ws.update(dt, _player, enemies, BOUNDS, _particles, _grid, _audio, _on_killed(), perks)


func _alive(enemies: Array[PerilEnemy], id: int) -> bool:
	for e: PerilEnemy in enemies:
		if e.id == id:
			return true
	return false


# ---- Blackhole ------------------------------------------------------------------------


func test_event_horizon_kills_further_from_the_core() -> void:
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.blackhole.event_horizon = owned
		var enemies: Array[PerilEnemy] = [_enemy(1, 545.0, 300.0)]  # 45 px out
		_activate(Types.WeaponType.VORTEX, 500.0, 300.0, enemies, p)
		_update(enemies, 0.001, p)
		assert_eq(_alive(enemies, 1), not owned, "45 px: dead only with Event Horizon")


func test_dark_harvest_feeds_the_well() -> void:
	var durations: Array[float] = []
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.blackhole.dark_harvest = owned
		var enemies: Array[PerilEnemy] = [_enemy(1, 510.0, 300.0), _enemy(2, 490.0, 300.0)]
		_activate(Types.WeaponType.VORTEX, 500.0, 300.0, enemies, p)
		_update(enemies, 0.001, p)
		assert_eq(enemies.size(), 0, "both swallowed")
		durations.append(_ws.active_weapons[0].duration)
	assert_almost_eq(durations[1] - durations[0], 2 * WeaponSystem.DARK_HARVEST_STEP, 0.0001)


# ---- Missiles -------------------------------------------------------------------------


func test_cluster_split_spawns_two_children_once() -> void:
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.missiles.cluster_split = owned
		var m: Types.HomingMissile = _ws._new_missile(500.0, 300.0, 0.0, 0.0)
		m.lifetime = 0.001
		_ws.missiles.append(m)
		var enemies: Array[PerilEnemy] = [_enemy(1, 900.0, 100.0)]
		_update(enemies, 0.01, p)
		assert_eq(_ws.missiles.size(), 2 if owned else 0, "the blast splits in two")
		if owned:
			assert_eq(_ws.missiles[0].generation, 1)
			for child: Types.HomingMissile in _ws.missiles:
				child.lifetime = 0.001
			_update(enemies, 0.01, p)
			assert_eq(_ws.missiles.size(), 0, "children do not split again")


func test_hyper_thrusters_lock_on_at_launch() -> void:
	var p: ProgressionManager.WeaponPerks = _perks()
	p.missiles.hyper_thrusters = true
	var enemies: Array[PerilEnemy] = [_enemy(1, 600.0, 300.0), _enemy(2, 700.0, 300.0)]
	_activate(Types.WeaponType.MISSILES, 500.0, 300.0, enemies, p)
	for m: Types.HomingMissile in _ws.missiles:
		assert_ne(m.target_id, Types.ABSENT, "locked at launch")
		assert_almost_eq(m.cruise, WeaponSystem.HYPER_CRUISE, 0.001)
	assert_eq(_ws.missiles[0].target_id, 1, "the nearest first")
	var plain: WeaponSystem = WeaponSystem.new()
	plain.activate_weapon(
		Types.WeaponType.MISSILES,
		500.0,
		300.0,
		_player,
		enemies,
		_particles,
		_grid,
		_audio,
		_on_killed(),
		_perks()
	)
	assert_eq(plain.missiles[0].target_id, Types.ABSENT, "the TS picks a target in flight")


func test_second_salvo_launches_again_from_the_ship() -> void:
	var p: ProgressionManager.WeaponPerks = _perks()
	p.missiles.second_salvo = true
	_player.x = 200.0
	_player.y = 200.0
	var enemies: Array[PerilEnemy] = []
	_activate(Types.WeaponType.MISSILES, 500.0, 300.0, enemies, p)
	var first: int = _ws.missiles.size()
	_update(enemies, 0.3, p)
	assert_eq(_ws.missiles.size(), first, "not yet")
	_update(enemies, 0.35, p)
	assert_eq(_ws.missiles.size(), first * 2, "a second salvo")
	assert_almost_eq(_ws.missiles[-1].x, 200.0, 20.0, "from the ship")


# ---- Laser ----------------------------------------------------------------------------


func test_heavy_beam_cuts_a_wider_path() -> void:
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.laser.heavy_beam = owned
		_player.x = 500.0
		_player.y = 300.0
		_player.angle = 0.0
		var enemies: Array[PerilEnemy] = [_enemy(1, 600.0, 330.0)]  # ~29 px off the beam
		_activate(Types.WeaponType.LASER, 500.0, 300.0, enemies, p)
		_update(enemies, 0.001, p)
		assert_eq(_alive(enemies, 1), not owned, "29 px: cut only by the heavy beam")


func test_rapid_sweep_turns_faster() -> void:
	var angles: Array[float] = []
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.laser.rapid_sweep = owned
		_player.angle = 0.0
		var enemies: Array[PerilEnemy] = []
		_activate(Types.WeaponType.LASER, 0.0, 0.0, enemies, p)
		_update(enemies, 0.1, p)
		angles.append(_ws.active_weapons[0].angle)
	assert_almost_eq(angles[1], angles[0] * WeaponSystem.RAPID_SWEEP_FACTOR, 0.0001)


# ---- Nuke -----------------------------------------------------------------------------


func _run_nuke(p: ProgressionManager.WeaponPerks, enemies: Array[PerilEnemy]) -> void:
	_activate(Types.WeaponType.NUKE, 500.0, 300.0, enemies, p)
	# Small ticks: the TS's last tick overshoots the radius by dt / 0.65 (progress > 1).
	for i: int in range(70):
		_update(enemies, 0.01, p)


func test_fallout_zone_leaves_a_burn_zone() -> void:
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.nuke.fallout_zone = owned
		var enemies: Array[PerilEnemy] = []
		_run_nuke(p, enemies)
		assert_eq(_ws.active_weapons.size(), 1 if owned else 0, "the zone outlives the blast")
		if owned:
			enemies.append(_enemy(1, 510.0, 300.0))
			_update(enemies, 0.1, p)
			assert_false(_alive(enemies, 1), "a dot entering the zone burns")
			for i: int in range(40):
				_update(enemies, 0.1, p)
			assert_eq(_ws.active_weapons.size(), 0, "gone after 3 s")


func test_chain_reaction_bursts_reach_past_the_blast() -> void:
	var outside_dead: Array[int] = []
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.nuke.chain_reaction = owned
		var r: float = Tuning.get_tuned_value("nuke", "radius", 0)
		var enemies: Array[PerilEnemy] = []
		for i: int in range(40):
			var a: float = TAU * i / 40.0
			# Inner ring at r − 10 (vaporized); outer at r + 35, past the blast's reach
			# (r × 1.016 + 23) but within a burst's 60 px of an inner dot.
			enemies.append(_enemy(i, 500.0 + cos(a) * (r - 10.0), 300.0 + sin(a) * (r - 10.0)))
			var o: PerilEnemy = _enemy(100 + i, 500.0, 300.0)
			o.x = 500.0 + cos(a) * (r + 35.0)
			o.y = 300.0 + sin(a) * (r + 35.0)
			enemies.append(o)
		_run_nuke(p, enemies)
		outside_dead.append(40 - enemies.size())
	assert_eq(outside_dead[0], 0, "the blast alone stops at its radius")
	assert_gt(outside_dead[1], 0, "bursts reach dots past it")


func test_stun_wave_freezes_the_survivors_nearby() -> void:
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.nuke.stun_wave = owned
		var r: float = Tuning.get_tuned_value("nuke", "radius", 0)
		var near: PerilEnemy = _enemy(1, 500.0 + r * 1.3, 300.0)
		var far: PerilEnemy = _enemy(2, 500.0 + r * 1.8, 300.0)
		var enemies: Array[PerilEnemy] = [near, far]
		_run_nuke(p, enemies)
		assert_eq(near.frozen, owned, "1.3× the radius: frozen with Stun Wave")
		assert_false(far.frozen, "1.8× is past the wave")


# ---- Freeze ---------------------------------------------------------------------------


func test_cryo_nova_blasts_the_pickup_area() -> void:
	var p: ProgressionManager.WeaponPerks = _perks()
	p.freeze.cryo_nova = true
	var enemies: Array[PerilEnemy] = [_enemy(1, 600.0, 300.0), _enemy(2, 900.0, 300.0)]
	_activate(Types.WeaponType.FREEZE, 500.0, 300.0, enemies, p)
	assert_false(_alive(enemies, 1), "100 px: blasted")
	assert_true(_alive(enemies, 2), "400 px: only frozen")
	assert_true(enemies[0].frozen)


func test_ice_armor_shields_on_pickup() -> void:
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.freeze.ice_armor = owned
		var enemies: Array[PerilEnemy] = []
		_activate(Types.WeaponType.FREEZE, 500.0, 300.0, enemies, p)
		assert_eq(_player.has_shield(), owned)


# ---- Shield ---------------------------------------------------------------------------


func test_overcharge_pulses_when_the_shield_ends() -> void:
	var p: ProgressionManager.WeaponPerks = _perks()
	p.shield.overcharge_pulse = true
	_player.x = 500.0
	_player.y = 300.0
	var enemies: Array[PerilEnemy] = [_enemy(1, 600.0, 300.0), _enemy(2, 900.0, 300.0)]
	_activate(Types.WeaponType.SHIELD, 500.0, 300.0, enemies, p)
	_update(enemies, 0.1, p)
	assert_eq(enemies.size(), 2, "no pulse while the shield holds")
	_player.shield_timer = 0.0
	_update(enemies, 0.01, p)
	assert_false(_alive(enemies, 1), "100 px: caught by the pulse")
	assert_true(_alive(enemies, 2), "400 px: out of reach")
	_update(enemies, 0.01, p)
	assert_true(_alive(enemies, 2), "one pulse only")


# ---- Lightning ------------------------------------------------------------------------


func _strike(p: ProgressionManager.WeaponPerks, enemies: Array[PerilEnemy]) -> void:
	_activate(Types.WeaponType.LIGHTNING, 500.0, 300.0, enemies, p)


func test_superconductor_doubles_the_jump() -> void:
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.lightning.superconductor = owned
		var enemies: Array[PerilEnemy] = [_enemy(1, 800.0, 300.0)]  # 300 px: past 220
		_strike(p, enemies)
		assert_eq(_alive(enemies, 1), not owned)


func test_forked_lightning_strikes_a_second_chain() -> void:
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.lightning.forked_lightning = owned
		# 150 px each side of the pickup, 300 px apart: one chain cannot reach both.
		var enemies: Array[PerilEnemy] = [_enemy(1, 650.0, 300.0), _enemy(2, 350.0, 300.0)]
		_strike(p, enemies)
		assert_false(_alive(enemies, 1))
		assert_eq(_alive(enemies, 2), not owned, "the fork reaches the other side")


func test_arc_detonation_kills_past_the_chain_cap() -> void:
	for owned: bool in [false, true]:
		before_each()
		var p: ProgressionManager.WeaponPerks = _perks()
		p.lightning.plasma_arc = owned
		var enemies: Array[PerilEnemy] = []
		for i: int in range(16):  # the chain strikes 14 at rank 0
			enemies.append(_enemy(i, 520.0 + 12.0 * i, 300.0))
		_strike(p, enemies)
		assert_eq(enemies.size(), 0 if owned else 2, "the leftovers sit within 45 px")


# ---- RunController keystones ----------------------------------------------------------


func _run_controller() -> RunController:
	var pm: ProgressionManager = ProgressionManager.new()
	var rc: RunController = RunController.new(
		PlayerShip.new(500.0, 300.0),
		EnemySwarm.new(),
		WeaponSystem.new(),
		ParticleEngine.new(),
		VectorGrid.new(1000, 600),
		ScoreManager.new(),
		AudioBank.new(),
		pm,
		GameOptionsManager.new(),
		CoinSystem.new()
	)
	rc.goals = GoalManager.new(pm)
	rc.maze = GauntletMaze.new()
	rc.reset_run(BOUNDS)
	return rc


func test_battering_ram_kills_around_the_rammed_dot() -> void:
	for owned: bool in [false, true]:
		var rc: RunController = _run_controller()
		rc.progression.data.perks.shield.battering_ram = owned
		rc.player.activate_shield(5.0)
		rc.swarm.enemies = [_enemy(1, 500.0, 300.0), _enemy(2, 540.0, 300.0)]
		rc._collide(0, rc.player.x, rc.player.y, rc.player.radius)
		assert_eq(rc.swarm.enemies.size(), 0 if owned else 1, "40 px neighbour: owned only")


func test_shatter_cascade_shatters_nearby_frozen_dots() -> void:
	for owned: bool in [false, true]:
		var rc: RunController = _run_controller()
		rc.progression.data.perks.freeze.shatter_cascade = owned
		rc.player.shield_timer = 0.0
		var a: PerilEnemy = _enemy(1, 500.0, 300.0)
		var b: PerilEnemy = _enemy(2, 550.0, 300.0)
		var c: PerilEnemy = _enemy(3, 560.0, 300.0)
		for e: PerilEnemy in [a, b]:
			e.frozen = true
			e.freeze_timer = 5.0
		rc.swarm.enemies = [a, b, c]
		rc._collide(0, rc.player.x, rc.player.y, rc.player.radius)
		assert_eq(rc.swarm.enemies.size(), 1 if owned else 2, "the frozen neighbour goes too")
		assert_true(rc.swarm.enemies.has(c), "an unfrozen dot is untouched")


func test_coin_vacuum_widens_the_magnet_while_shielded() -> void:
	var rc: RunController = _run_controller()
	rc.progression.data.perks.shield.coin_vacuum = true
	rc.player.shield_timer = 0.0
	rc.update(1.0 / 120.0, Types.ControlMode.MOUSE, Vector2(500, 300), Vector2.ZERO, Vector2.ZERO)
	assert_almost_eq(rc.coins.magnet_radius, CoinSystem.MAGNET_RADIUS, 0.001, "unshielded")
	rc.player.activate_shield(3.0)
	rc.update(1.0 / 120.0, Types.ControlMode.MOUSE, Vector2(500, 300), Vector2.ZERO, Vector2.ZERO)
	assert_almost_eq(rc.coins.magnet_radius, RunController.COIN_VACUUM_RADIUS, 0.001)
