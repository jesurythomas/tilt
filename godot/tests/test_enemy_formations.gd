## test_enemy_formations.gd
## PORTS: nothing — new file, covers the formation dispatchers and the armada
## in src/sim/enemy_swarm.gd
extends GutTest
## Covers trigger_random_formation, trigger_gauntlet_formation and
## spawn_mode_armada. Choice-dependent assertions hold for any roll; the seed
## only makes a failing run reproducible.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)
## Array[int] rather than Array[Types.EnemyType]: enum-typed arrays are not
## relied on; EnemyType values are ints and has() compares by value.
const FORMATION_TYPES: Array[int] = [
	Types.EnemyType.ARROW_DRONE,
	Types.EnemyType.CIRCLE_DOT,
	Types.EnemyType.WALL_DOT,
	Types.EnemyType.TURRET_DOT,
	Types.EnemyType.SNAKE_SEGMENT,
]

var _swarm: EnemySwarm = null


func before_each() -> void:
	_swarm = EnemySwarm.new()
	seed(20260920)


func test_random_formation_only_produces_the_five_classic_formations() -> void:
	var seen: Dictionary = {}
	var stray: int = 0
	for i: int in range(200):
		_swarm.trigger_random_formation(PLAYER, BOUNDS, 0)
		assert_gt(_swarm.enemies.size(), 0, "every roll spawns something")
		for e: Types.Enemy in _swarm.enemies:
			if not FORMATION_TYPES.has(e.type):
				stray += 1
			seen[e.type] = true
		_swarm.enemies.clear()
	assert_eq(stray, 0, "no non-formation type ever appears")
	assert_eq(seen.size(), 5, "200 rolls at 1/5 each: a missing formation has odds under 1e-18")


func test_gauntlet_formation_never_walls_or_encircles() -> void:
	var seen: Dictionary = {}
	var forbidden: int = 0
	for i: int in range(200):
		_swarm.trigger_gauntlet_formation(PLAYER, BOUNDS, 0)
		for e: Types.Enemy in _swarm.enemies:
			if e.type == Types.EnemyType.WALL_DOT or e.type == Types.EnemyType.CIRCLE_DOT:
				forbidden += 1
			seen[e.type] = true
		_swarm.enemies.clear()
	assert_eq(forbidden, 0)
	assert_eq(seen.size(), 3, "arrow, turret and snake all occur")


func test_code_red_armada_rings_the_player_with_24_seekers() -> void:
	_swarm.spawn_mode_armada(Types.GameMode.CODE_RED, BOUNDS, PLAYER)
	assert_eq(_swarm.enemies.size(), 24)
	for e: Types.Enemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.SEEKER)
		assert_almost_eq(Vector2(e.x, e.y).distance_to(PLAYER), 600.0 * 0.44, 0.01)


func test_classic_and_gauntlet_armadas_are_eight_edge_seekers() -> void:
	_swarm.spawn_mode_armada(Types.GameMode.CLASSIC, BOUNDS, PLAYER)
	assert_eq(_swarm.enemies.size(), 8)
	_swarm.reset()
	_swarm.spawn_mode_armada(Types.GameMode.GAUNTLET, BOUNDS, PLAYER)
	assert_eq(_swarm.enemies.size(), 8)
	for e: Types.Enemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.SEEKER)
		assert_true(e.x < 0.0 or e.x > BOUNDS.x or e.y < 0.0 or e.y > BOUNDS.y, "edge spawn")
