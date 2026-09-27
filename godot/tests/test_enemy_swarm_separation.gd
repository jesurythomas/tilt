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


## Plain seekers: `spread` across a 2162 x 1056 arena plus `clump` packed in a 60 px box.
func _seekers(spread: int, clump: int) -> Array[Types.Enemy]:
	seed(99)
	var out: Array[Types.Enemy] = []
	for i: int in range(spread + clump):
		var e: Types.Enemy = Types.Enemy.new()
		e.id = i
		if i < spread:
			e.x = randf() * 2162.0
			e.y = randf() * 1056.0
		else:
			e.x = 1000.0 + randf() * 60.0
			e.y = 500.0 + randf() * 60.0
		out.append(e)
	return out


func _assert_sweep_matches(reference: Array[Types.Enemy], ticks: int) -> void:
	var swarm: EnemySwarm = EnemySwarm.new()
	swarm.enemies = _copy(reference)
	assert_gte(
		swarm.separation_candidates().size(), EnemySwarm.SWEEP_MIN_CANDIDATES, "sweep engaged"
	)
	for tick: int in range(ticks):
		_reference_separation(reference)
		swarm.apply_flocking_separation()
	var mismatches: int = 0
	for i: int in range(reference.size()):
		if swarm.enemies[i].x != reference[i].x or swarm.enemies[i].y != reference[i].y:
			mismatches += 1
	assert_eq(mismatches, 0, "every x/y equal to the reference, bit for bit")


func test_sweep_matches_the_pair_loop_on_a_late_swarm() -> void:
	# M11c P15: 240 spread seekers and a 60-seeker clump, 60 ticks.
	_assert_sweep_matches(_seekers(240, 60), 60)


func test_sweep_matches_the_pair_loop_when_it_falls_back() -> void:
	# M11c P15: 120 seekers in one 60 px box push far enough to exceed the slack.
	_assert_sweep_matches(_seekers(0, 120), 30)


func test_sweep_matches_the_pair_loop_on_a_column() -> void:
	# M11c P26: 120 seekers in a 4 x 80 px column push mostly along y, past the slack
	# (the y fallback), beside 200 spread seekers (the y-filtered window).
	var enemies: Array[Types.Enemy] = _seekers(200, 0)
	for i: int in range(120):
		var e: Types.Enemy = Types.Enemy.new()
		e.id = 200 + i
		e.x = 1500.0 + randf() * 4.0
		e.y = 300.0 + randf() * 80.0
		enemies.append(e)
	_assert_sweep_matches(enemies, 40)


func test_sweep_writes_back_an_enemy_pushed_only_by_the_fallback() -> void:
	# M11c P27: A is pushed past SWEEP_SLACK by B and C (the plain-scan fallback), then
	# pushes D, which nothing else reaches this tick; D's new x must be written back.
	# 32 fillers 100 px apart keep the sweep engaged without touching the four.
	var enemies: Array[Types.Enemy] = []
	var spots: Array[Vector2] = [
		Vector2(1000.0, 500.0),
		Vector2(1000.1, 500.0),
		Vector2(1000.1, 500.05),
		Vector2(980.0, 500.0)
	]
	for p: Vector2 in spots:
		var e: Types.Enemy = Types.Enemy.new()
		e.id = enemies.size()
		e.x = p.x
		e.y = p.y
		enemies.append(e)
	for i: int in range(32):
		var f: Types.Enemy = Types.Enemy.new()
		f.id = enemies.size()
		f.x = 100.0 + float(i % 8) * 100.0
		f.y = 100.0 + float(i / 8) * 100.0
		enemies.append(f)
	var d_before: float = enemies[3].x
	var swarm: EnemySwarm = EnemySwarm.new()
	swarm.enemies = _copy(enemies)
	swarm.apply_flocking_separation()
	assert_ne(swarm.enemies[3].x, d_before, "D was pushed")
	_reference_separation(enemies)
	assert_eq(swarm.enemies[3].x, enemies[3].x, "D matches the pair loop exactly")
	for i: int in range(4):
		assert_eq(swarm.enemies[i].x, enemies[i].x, "x %d" % i)
		assert_eq(swarm.enemies[i].y, enemies[i].y, "y %d" % i)
