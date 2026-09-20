## test_wave_director.gd
## PORTS: nothing — new file, covers the wave director inside EnemySwarm.update()
extends GutTest
## Covers the score thresholds that unlock elite types per mode, the twin and
## double seeker spawns, the first wave time, and which formations each mode
## may schedule. Each update() call runs the spawn block at most once and the
## wave block at most once, and enemies are cleared between calls, so what is
## present after a call is exactly what that call spawned. Threshold
## assertions hold for any roll: the rarest branch checked (a charger once
## every elite is unlocked) has p >= 0.09 per spawn event, and 400 one-second
## calls sample at least 200 events (the classic interval is at most 1.5 s), so
## a false negative has odds under 1e-8; the seed only makes a failing run
## reproducible.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)
const ELITES: Array[int] = [
	Types.EnemyType.CHARGER,
	Types.EnemyType.SPECTER,
	Types.EnemyType.ARTILLERY,
	Types.EnemyType.PULSAR,
	Types.EnemyType.CARRIER,
]
const FORMATION_TYPES: Array[int] = [
	Types.EnemyType.ARROW_DRONE,
	Types.EnemyType.CIRCLE_DOT,
	Types.EnemyType.WALL_DOT,
	Types.EnemyType.TURRET_DOT,
	Types.EnemyType.SNAKE_SEGMENT,
]

var _particles: ParticleEngine = null
var _swarm: EnemySwarm = null


func before_each() -> void:
	_particles = ParticleEngine.new()
	_swarm = EnemySwarm.new()
	seed(20260920)


func _count_type(type: Types.EnemyType) -> int:
	var n: int = 0
	for e: Types.Enemy in _swarm.enemies:
		if e.type == type:
			n += 1
	return n


func _count_in(types: Array[int]) -> int:
	var n: int = 0
	for e: Types.Enemy in _swarm.enemies:
		if types.has(e.type):
			n += 1
	return n


## Runs `calls` one-second updates at `score` in `mode` and returns the set of
## elite types that spawned (keys are Types.EnemyType values).
func _elites_seen(score: int, mode: Types.GameMode, calls: int) -> Dictionary:
	var seen: Dictionary = {}
	for i: int in range(calls):
		_swarm.update(1.0, PLAYER, BOUNDS, _particles, score, mode)
		for e: Types.Enemy in _swarm.enemies:
			if ELITES.has(e.type):
				seen[e.type] = true
		_swarm.enemies.clear()
	return seen


func _assert_elites(seen: Dictionary, expected: Array[int], label: String) -> void:
	assert_eq(seen.size(), expected.size(), label + ": exactly these elites")
	for t: int in expected:
		assert_true(seen.has(t), label + ": type %d unlocked" % t)


func test_classic_unlocks_elites_at_5k_10k_16k_22k_32k() -> void:
	var classic: Types.GameMode = Types.GameMode.CLASSIC
	_assert_elites(_elites_seen(4999, classic, 400), [], "below 5000")
	_swarm.reset()
	_assert_elites(_elites_seen(5000, classic, 400), [Types.EnemyType.CHARGER], "5000")
	_swarm.reset()
	_assert_elites(
		_elites_seen(10000, classic, 400),
		[Types.EnemyType.CHARGER, Types.EnemyType.SPECTER],
		"10000"
	)
	_swarm.reset()
	_assert_elites(
		_elites_seen(16000, classic, 400),
		[Types.EnemyType.CHARGER, Types.EnemyType.SPECTER, Types.EnemyType.ARTILLERY],
		"16000"
	)
	_swarm.reset()
	_assert_elites(
		_elites_seen(22000, classic, 400),
		[
			Types.EnemyType.CHARGER,
			Types.EnemyType.SPECTER,
			Types.EnemyType.ARTILLERY,
			Types.EnemyType.PULSAR,
		],
		"22000"
	)
	_swarm.reset()
	_assert_elites(_elites_seen(32000, classic, 400), ELITES, "32000")


func test_code_red_unlocks_elites_at_2500_6k_10k_16k_24k() -> void:
	var red: Types.GameMode = Types.GameMode.CODE_RED
	_assert_elites(_elites_seen(2499, red, 400), [], "below 2500")
	_swarm.reset()
	_assert_elites(_elites_seen(2500, red, 400), [Types.EnemyType.CHARGER], "2500")
	_swarm.reset()
	_assert_elites(
		_elites_seen(6000, red, 400), [Types.EnemyType.CHARGER, Types.EnemyType.SPECTER], "6000"
	)
	_swarm.reset()
	_assert_elites(
		_elites_seen(10000, red, 400),
		[Types.EnemyType.CHARGER, Types.EnemyType.SPECTER, Types.EnemyType.ARTILLERY],
		"10000"
	)
	_swarm.reset()
	_assert_elites(
		_elites_seen(16000, red, 400),
		[
			Types.EnemyType.CHARGER,
			Types.EnemyType.SPECTER,
			Types.EnemyType.ARTILLERY,
			Types.EnemyType.PULSAR,
		],
		"16000"
	)
	_swarm.reset()
	_assert_elites(_elites_seen(24000, red, 400), ELITES, "24000")


func test_code_red_spawns_seekers_in_pairs() -> void:
	for i: int in range(30):
		_swarm.update(1.0, PLAYER, BOUNDS, _particles, 0, Types.GameMode.CODE_RED)
		var seekers: int = _count_type(Types.EnemyType.SEEKER)
		assert_true(seekers == 0 or seekers == 2, "twin spawns: got %d" % seekers)
		_swarm.enemies.clear()


func test_classic_doubles_seeker_spawns_only_from_12k() -> void:
	var max_below: int = 0
	for i: int in range(100):
		_swarm.update(1.0, PLAYER, BOUNDS, _particles, 11999)
		max_below = maxi(max_below, _count_type(Types.EnemyType.SEEKER))
		_swarm.enemies.clear()
	assert_eq(max_below, 1, "below 12000 a spawn event yields one seeker")
	_swarm.reset()
	var max_at: int = 0
	for i: int in range(300):
		_swarm.update(1.0, PLAYER, BOUNDS, _particles, 12000)
		max_at = maxi(max_at, _count_type(Types.EnemyType.SEEKER))
		_swarm.enemies.clear()
	assert_eq(max_at, 2, "from 12000 a quarter of non-elite events spawn two")


func test_first_formation_wave_fires_at_four_seconds() -> void:
	for i: int in range(7):
		_swarm.update(0.5, PLAYER, BOUNDS, _particles)
	assert_eq(_count_in(FORMATION_TYPES), 0, "3.5 s: no wave yet")
	_swarm.update(0.5, PLAYER, BOUNDS, _particles)
	assert_gt(_count_in(FORMATION_TYPES), 0, "wave_timer starts at 4.0 (EnemySwarm.ts:40)")


func test_code_red_waves_are_walls_pincers_or_tight_circles() -> void:
	var waves: int = 0
	for i: int in range(200):
		_swarm.update(0.5, PLAYER, BOUNDS, _particles, 0, Types.GameMode.CODE_RED)
		var arrows: int = _count_type(Types.EnemyType.ARROW_DRONE)
		var circles: int = _count_type(Types.EnemyType.CIRCLE_DOT)
		var walls: int = _count_type(Types.EnemyType.WALL_DOT)
		assert_true(arrows == 0 or arrows == 14, "code red arrows are the dual pincer")
		assert_true(circles == 0 or circles == 16, "code red circles are tight")
		assert_eq(_count_type(Types.EnemyType.TURRET_DOT), 0)
		assert_eq(_count_type(Types.EnemyType.SNAKE_SEGMENT), 0)
		if arrows + circles + walls > 0:
			waves += 1
		_swarm.enemies.clear()
	assert_gte(waves, 20, "interval 3.6-4.8 s over 100 s")


func test_gauntlet_waves_exclude_walls_and_circles() -> void:
	var waves: int = 0
	var forbidden: int = 0
	for i: int in range(400):
		_swarm.update(0.5, PLAYER, BOUNDS, _particles, 0, Types.GameMode.GAUNTLET)
		forbidden += _count_type(Types.EnemyType.WALL_DOT)
		forbidden += _count_type(Types.EnemyType.CIRCLE_DOT)
		if _count_in(FORMATION_TYPES) > 0:
			waves += 1
		_swarm.enemies.clear()
	assert_eq(forbidden, 0)
	assert_gte(waves, 12, "interval at most 16 s over 200 s")
