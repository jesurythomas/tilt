## test_native_swarm.gd
## Oracle for M11c N3: the C++ swarm loop and separation (PerilNative.swarm_step,
## separate_enemies) must leave every enemy field, the enemy list and the RNG exactly
## where the GDScript reference (EnemySwarm.use_native = false) leaves them.
extends GutTest

const BOUNDS: Vector2 = Vector2(2162.0, 1056.0)
const PLAYER: Vector2 = Vector2(1081.0, 528.0)
const DT: float = 1.0 / 120.0
const FIELDS: Array[String] = [
	"id",
	"type",
	"x",
	"y",
	"vx",
	"vy",
	"radius",
	"frozen",
	"freeze_timer",
	"age",
	"health",
	"target_angle",
	"special_timer",
	"leader_id",
	"parent_wave_id",
	"orbit_center",
	"orbit_radius",
	"orbit_speed",
	"chilled",
	"is_hazard",
	"state",
	"aim_angle",
	"aim_timer",
	"fire_cooldown",
	"parent_carrier_id",
	"orbit_angle",
	"pulse_timer",
	"stealth_opacity",
]


class RunResult:
	var rows: Array[PackedByteArray] = []
	var counts: PackedInt32Array = PackedInt32Array()
	var rng: int = 0
	var particles: int = 0
	var types_seen: int = 0


## What the last _collision_run exercised: [rams, shatters, lives lost, close calls].
var _collision_branches: PackedInt32Array = PackedInt32Array()

## Kills and close calls in the last _pile_up.
var _pile_counts: Vector2i = Vector2i.ZERO


func after_each() -> void:
	EnemySwarm.use_native = true


## Every enemy type, each branch of its update: seekers (some chilled, some pinned
## to a wall), sweep dots leaving the arena, circle dots, gate and free turret dots,
## a spike mine, snake leaders and a follower, chargers, artillery, carriers with
## satellites, bullets, pulsars and specters.
func _mixed_swarm(swarm: EnemySwarm) -> void:
	swarm.scale = 1.25
	swarm.set_speed_scale(0.9)
	for i: int in range(60):
		var s: PerilEnemy = swarm.spawn_seeker(BOUNDS, randf() * BOUNDS.x, randf() * BOUNDS.y)
		s.chilled = i % 7 == 0
	swarm.spawn_seeker(BOUNDS, 1.0, 1.0)
	swarm.spawn_seeker(BOUNDS, BOUNDS.x - 1.0, BOUNDS.y - 1.0)
	swarm.spawn_wall_formation(BOUNDS)
	swarm.spawn_arrow_formation(BOUNDS, true)
	swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 20000, true)
	swarm.spawn_rotating_gate(BOUNDS)
	swarm.spawn_turret(BOUNDS)
	swarm.spawn_snake(BOUNDS)
	var tail: PerilEnemy = swarm.enemies[swarm.enemies.size() - 1]
	tail.leader_id = swarm.enemies[swarm.enemies.size() - 2].id
	var mine: PerilEnemy = PerilEnemy.new()
	mine.type = Types.EnemyType.SPIKE_MINE
	mine.x = 300.0
	mine.y = 300.0
	mine.vx = -900.0
	mine.vy = 40.0
	mine.radius = 9.0
	swarm.enemies.append(mine)
	for i: int in range(3):
		swarm.spawn_charger(BOUNDS, PLAYER)
		swarm.spawn_artillery(BOUNDS, PLAYER)
		swarm.spawn_carrier(BOUNDS, PLAYER)
		swarm.spawn_pulsar(BOUNDS, PLAYER)
		swarm.spawn_specter(BOUNDS, PLAYER)
		swarm.spawn_bullet(PLAYER.x + 200.0, PLAYER.y, PLAYER)
	# A slow bullet that stays inside the arena until its 4.5 s age cull.
	var slow: PerilEnemy = swarm.spawn_bullet(900.0, 200.0, Vector2(900.0, 1000.0))
	slow.vx = 0.0
	slow.vy = 6.0


## Runs `ticks` of EnemySwarm.update on one path from seed 4242 and returns the
## enemies' fields as bytes, the enemy count per tick, then one draw from the RNG.
func _run(native: bool, mode: Types.GameMode, ticks: int) -> RunResult:
	EnemySwarm.use_native = native
	seed(4242)
	var swarm: EnemySwarm = EnemySwarm.new()
	var particles: ParticleEngine = ParticleEngine.new()
	_mixed_swarm(swarm)
	var types_seen: Dictionary[int, bool] = {}
	var out: RunResult = RunResult.new()
	for t: int in range(ticks):
		if t == ticks / 3:
			swarm.freeze_all(0.5)
		# The player drifts so turrets and chargers keep re-aiming.
		var player: Vector2 = PLAYER + Vector2(cos(t * 0.02) * 300.0, sin(t * 0.03) * 200.0)
		swarm.update(DT, player, BOUNDS, particles, 26000, mode)
		out.counts.append(swarm.enemies.size())
		for e: PerilEnemy in swarm.enemies:
			types_seen[e.type] = true
	for e: PerilEnemy in swarm.enemies:
		var row: Array = []
		for f: String in FIELDS:
			row.append(e.get(f))
		out.rows.append(var_to_bytes(row))
	out.rng = randi()
	out.particles = particles.particles.size()
	out.types_seen = types_seen.size()
	return out


func _assert_paths_match(mode: Types.GameMode, ticks: int) -> void:
	var gd: RunResult = _run(false, mode, ticks)
	var cpp: RunResult = _run(true, mode, ticks)
	assert_eq(gd.types_seen, Types.EnemyType.size(), "every enemy type ran")
	assert_eq(cpp.counts, gd.counts, "the same enemy count on every tick (spawns and culls)")
	assert_eq(cpp.rows.size(), gd.rows.size(), "same enemy count")
	var mismatches: int = 0
	for i: int in range(mini(cpp.rows.size(), gd.rows.size())):
		if cpp.rows[i] != gd.rows[i]:
			mismatches += 1
	assert_eq(mismatches, 0, "every enemy field bit-identical")
	assert_eq(cpp.rng, gd.rng, "the RNG is in the same state")
	assert_eq(cpp.particles, gd.particles, "the same particles")


func test_native_loop_matches_gdscript_in_code_red() -> void:
	_assert_paths_match(Types.GameMode.CODE_RED, 900)


func test_native_loop_matches_gdscript_in_classic() -> void:
	_assert_paths_match(Types.GameMode.CLASSIC, 600)


func test_native_separation_matches_gdscript_below_the_sweep_threshold() -> void:
	# N3c: fewer than SWEEP_MIN_CANDIDATES candidates take the plain pair loop.
	var results: Array[PackedByteArray] = []
	for native: bool in [false, true]:
		EnemySwarm.use_native = native
		seed(77)
		var swarm: EnemySwarm = EnemySwarm.new()
		for i: int in range(20):
			swarm.spawn_seeker(BOUNDS, 1000.0 + randf() * 40.0, 500.0 + randf() * 40.0)
		assert_lt(swarm.separation_candidates().size(), EnemySwarm.SWEEP_MIN_CANDIDATES)
		for t: int in range(30):
			swarm.apply_flocking_separation()
		var xy: PackedFloat64Array = PackedFloat64Array()
		for e: PerilEnemy in swarm.enemies:
			xy.append(e.x)
			xy.append(e.y)
		results.append(xy.to_byte_array())
	assert_eq(results[1], results[0], "x/y bit-identical")


## A full RunController run on one path from seed 5151: the ship chases a mouse
## circling through a dense swarm (pulsars and carriers, so kills add and drop
## enemies), shielded for the first third (rams), frozen swarm for the second
## (shatters), bare for the rest (crashes and close calls; 50 lives).
func _collision_run(native: bool, ticks: int) -> PackedByteArray:
	EnemySwarm.use_native = native
	seed(5151)
	var swarm: EnemySwarm = EnemySwarm.new()
	var particles: ParticleEngine = ParticleEngine.new()
	var progression: ProgressionManager = ProgressionManager.new()
	var rc: RunController = RunController.new(
		PlayerShip.new(PLAYER.x, PLAYER.y),
		swarm,
		WeaponSystem.new(),
		particles,
		VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y)),
		ScoreManager.new(),
		AudioBank.new(),
		progression,
		GameOptionsManager.new(),
		CoinSystem.new()
	)
	rc.goals = GoalManager.new(progression)
	rc.maze = GauntletMaze.new()
	rc.reset_run(BOUNDS)
	rc.lives = 50
	swarm.scale = 1.25
	for i: int in range(150):
		swarm.spawn_seeker(BOUNDS, randf() * BOUNDS.x, randf() * BOUNDS.y)
	for i: int in range(4):
		swarm.spawn_pulsar(BOUNDS, PLAYER)
		swarm.spawn_carrier(BOUNDS, PLAYER)
	rc.player.activate_shield(float(ticks) / 3.0 * DT)
	var trace: PackedInt32Array = PackedInt32Array()
	var kills_at_freeze: int = 0
	for t: int in range(ticks):
		if t == ticks / 3:
			kills_at_freeze = rc.scores.stats.kills
			swarm.freeze_all(float(ticks) / 3.0 * DT)
		var mouse: Vector2 = PLAYER + Vector2(cos(t * 0.01) * 700.0, sin(t * 0.013) * 380.0)
		rc.update(DT, Types.ControlMode.MOUSE, mouse, Vector2.ZERO, Vector2.ZERO)
		trace.append(swarm.enemies.size())
		trace.append(rc.lives)
		trace.append(rc.scores.stats.kills)
		trace.append(rc.scores.stats.close_calls)
	var kills_after_freeze: int = trace[(ticks * 2 / 3) * 4 + 2]
	_collision_branches = PackedInt32Array(
		[
			kills_at_freeze,
			kills_after_freeze - kills_at_freeze,
			50 - rc.lives,
			rc.scores.stats.close_calls,
		]
	)
	var rows: Array = [trace, rc.scores.stats.score, randi(), particles.particles.size()]
	for e: PerilEnemy in swarm.enemies:
		for f: String in FIELDS:
			rows.append(e.get(f))
	return var_to_bytes(rows)


func test_native_collisions_match_gdscript() -> void:
	# N3d: the native x reject + re-query after each kill against the plain loop.
	var gd: PackedByteArray = _collision_run(false, 1200)
	for k: int in range(4):
		assert_gt(
			_collision_branches[k], 0, "branch %d (rams, shatters, crashes, close calls) ran" % k
		)
	var cpp: PackedByteArray = _collision_run(true, 1200)
	assert_eq(cpp, gd, "the same run: counts, lives, kills, close calls, score, RNG, fields")


## One tick's check_collisions with enemies piled on the ship: rams (shielded) or
## shatters (frozen), with kills that add pulsar splits and free satellites, the
## array's last enemy included, and near misses below them.
func _pile_up(native: bool, shielded: bool) -> PackedByteArray:
	EnemySwarm.use_native = native
	seed(6262)
	var swarm: EnemySwarm = EnemySwarm.new()
	var particles: ParticleEngine = ParticleEngine.new()
	var progression: ProgressionManager = ProgressionManager.new()
	var rc: RunController = RunController.new(
		PlayerShip.new(PLAYER.x, PLAYER.y),
		swarm,
		WeaponSystem.new(),
		particles,
		VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y)),
		ScoreManager.new(),
		AudioBank.new(),
		progression,
		GameOptionsManager.new(),
		CoinSystem.new()
	)
	rc.goals = GoalManager.new(progression)
	rc.maze = GauntletMaze.new()
	rc.reset_run(BOUNDS)
	rc.lives = 50
	for i: int in range(60):
		swarm.spawn_seeker(BOUNDS, randf() * BOUNDS.x, randf() * BOUNDS.y)
	for i: int in range(3):
		swarm.spawn_pulsar(BOUNDS, PLAYER)
		swarm.spawn_carrier(BOUNDS, PLAYER)
	var p: PlayerShip = rc.player
	var n: int = swarm.enemies.size()
	for k: int in range(20):
		# Every third index from the end, so the last enemy and the specials are on it.
		var e: PerilEnemy = swarm.enemies[n - 1 - k * 3]
		e.x = p.x + randf() * 2.0
		e.y = p.y + randf() * 2.0
	for k: int in range(5):
		var near: PerilEnemy = swarm.enemies[k]
		near.x = p.x + p.radius + near.radius + 8.0
		near.y = p.y
	if shielded:
		p.activate_shield(5.0)
	else:
		swarm.freeze_all(5.0)
	rc.check_collisions()
	_pile_counts = Vector2i(rc.scores.stats.kills, rc.scores.stats.close_calls)
	var rows: Array = [
		swarm.enemies.size(),
		rc.lives,
		rc.scores.stats.kills,
		rc.scores.stats.close_calls,
		rc.scores.stats.score,
		randi(),
		particles.particles.size(),
	]
	for e: PerilEnemy in swarm.enemies:
		for f: String in FIELDS:
			rows.append(e.get(f))
	return var_to_bytes(rows)


func test_native_collisions_match_gdscript_on_a_pile_up() -> void:
	# N3d: after each kill the native path re-queries from the next index.
	for shielded: bool in [true, false]:
		var gd: PackedByteArray = _pile_up(false, shielded)
		assert_eq(_pile_counts.x, 20, "shielded=%s: all 20 on the ship die" % shielded)
		assert_eq(_pile_counts.y, 1, "shielded=%s: one close call" % shielded)
		var cpp: PackedByteArray = _pile_up(true, shielded)
		assert_eq(cpp, gd, "shielded=%s: the same tick" % shielded)


func test_native_enemy_type_ids_match_types() -> void:
	var ids: Dictionary = PerilNative.enemy_type_ids()
	assert_eq(ids.size(), Types.EnemyType.size())
	for name: String in Types.EnemyType.keys():
		var got: int = ids.get(name, -1)
		var want: int = Types.EnemyType[name]
		assert_eq(got, want, name)


func test_perilenemy_defaults_match_the_ts_optionals() -> void:
	# PORT: web/src/tilt-to-live/Types.ts:87-116 — optionals start unset.
	var e: PerilEnemy = PerilEnemy.new()
	assert_eq(e.type, Types.EnemyType.SEEKER)
	assert_eq(e.leader_id, Types.ABSENT)
	assert_eq(e.parent_wave_id, Types.ABSENT)
	assert_eq(e.parent_carrier_id, Types.ABSENT)
	assert_eq(e.state, Types.ABSENT)
	assert_eq(e.orbit_center, Vector2.ZERO)
	for f: String in [
		"target_angle",
		"special_timer",
		"orbit_radius",
		"orbit_speed",
		"aim_angle",
		"aim_timer",
		"fire_cooldown",
		"orbit_angle",
		"pulse_timer",
		"stealth_opacity",
	]:
		var v: float = e.get(f)
		assert_true(is_nan(v), "%s starts NAN" % f)
	e.x = 0.1 + 0.2
	assert_eq(e.x, 0.1 + 0.2, "x holds a 64-bit float")
