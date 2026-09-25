## test_enemy_swarm_separation.gd
## Oracle for the M11c P4 separation prefilter: positions must match the
## pre-P4 pair loop bit for bit.
extends GutTest

const KINDS: int = 6


## The pre-P4 EnemySwarm.apply_flocking_separation body, verbatim (enemy_swarm.gd at fbf7e94).
func _reference_separation(enemies: Array[Types.Enemy]) -> void:
	var min_distance: float = 16.0
	var min_distance2: float = min_distance * min_distance
	var count: int = enemies.size()
	for i: int in range(count):
		var a: Types.Enemy = enemies[i]
		if (
			a.frozen
			or a.type == Types.EnemyType.WALL_DOT
			or a.type == Types.EnemyType.BULLET
			or a.orbit_center != Vector2.ZERO
			or a.parent_carrier_id != Types.ABSENT
		):
			continue
		for j: int in range(i + 1, count):
			var b: Types.Enemy = enemies[j]
			if (
				b.frozen
				or b.type == Types.EnemyType.WALL_DOT
				or b.type == Types.EnemyType.BULLET
				or b.orbit_center != Vector2.ZERO
				or b.parent_carrier_id != Types.ABSENT
			):
				continue
			var dx: float = b.x - a.x
			var dy: float = b.y - a.y
			var dist2: float = dx * dx + dy * dy
			if dist2 < min_distance2 and dist2 > 0.0001:
				var dist: float = sqrt(dist2)
				var push: float = (min_distance - dist) * 0.15
				var px: float = (dx / dist) * push
				var py: float = (dy / dist) * push
				a.x -= px
				a.y -= py
				b.x += px
				b.y += py


## 150 enemies of every kind packed into a 120 px box, so many pairs overlap.
func _packed_swarm() -> Array[Types.Enemy]:
	seed(1234)
	var out: Array[Types.Enemy] = []
	for i: int in range(150):
		var e: Types.Enemy = Types.Enemy.new()
		e.id = i
		e.x = randf() * 120.0
		e.y = randf() * 120.0
		match i % KINDS:
			1:
				e.type = Types.EnemyType.WALL_DOT
			2:
				e.type = Types.EnemyType.BULLET
			3:
				e.frozen = true
			4:
				e.parent_carrier_id = 1
			5:
				e.orbit_center = Vector2(5.0, 5.0)
		out.append(e)
	return out


func _copy(src: Array[Types.Enemy]) -> Array[Types.Enemy]:
	var out: Array[Types.Enemy] = []
	for s: Types.Enemy in src:
		var e: Types.Enemy = Types.Enemy.new()
		e.id = s.id
		e.type = s.type
		e.x = s.x
		e.y = s.y
		e.frozen = s.frozen
		e.parent_carrier_id = s.parent_carrier_id
		e.orbit_center = s.orbit_center
		out.append(e)
	return out


func test_positions_match_the_pre_p4_pair_loop_exactly() -> void:
	var reference: Array[Types.Enemy] = _packed_swarm()
	var swarm: EnemySwarm = EnemySwarm.new()
	swarm.enemies = _copy(reference)
	for tick: int in range(30):
		_reference_separation(reference)
		swarm.apply_flocking_separation()
	var mismatches: int = 0
	for i: int in range(reference.size()):
		if swarm.enemies[i].x != reference[i].x or swarm.enemies[i].y != reference[i].y:
			mismatches += 1
	assert_eq(mismatches, 0, "every x/y equal to the reference, bit for bit")


func test_candidates_exclude_every_ineligible_kind() -> void:
	var swarm: EnemySwarm = EnemySwarm.new()
	swarm.enemies = _packed_swarm()
	var idx: PackedInt32Array = swarm.separation_candidates()
	assert_eq(idx.size(), 25, "only the plain seekers (i % 6 == 0) remain")
	for i: int in idx:
		assert_eq(i % KINDS, 0)
