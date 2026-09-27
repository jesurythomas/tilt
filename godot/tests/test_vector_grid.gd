## test_vector_grid.gd
## PORTS: nothing — new file, covers src/sim/vector_grid.gd
extends GutTest
## Covers the point lattice, the spring settle, the explosion impulse, and the
## M11c P3 packed/sleeping/windowed grid against the pre-P3 object grid.


## The pre-P3 VectorGrid (object per point), verbatim in behaviour (vector_grid.gd at fbf7e94).
class ReferenceGrid:
	var cols: int = 0
	var rows: int = 0
	var points: Array[RefPoint] = []

	func _init(width: float, height: float) -> void:
		cols = ceili(width / 36.0) + 1
		rows = ceili(height / 36.0) + 1
		for r: int in range(rows):
			for c: int in range(cols):
				var p: RefPoint = RefPoint.new()
				p.x = c * 36.0
				p.y = r * 36.0
				p.orig_x = p.x
				p.orig_y = p.y
				points.append(p)

	func update() -> void:
		for p: RefPoint in points:
			var dx: float = p.orig_x - p.x
			var dy: float = p.orig_y - p.y
			p.vx += dx * 0.08
			p.vy += dy * 0.08
			p.vx *= 0.90
			p.vy *= 0.90
			p.x += p.vx
			p.y += p.vy

	func apply_explosion(cx: float, cy: float, force: float, radius: float) -> void:
		var r2: float = radius * radius
		for p: RefPoint in points:
			var dx: float = p.x - cx
			var dy: float = p.y - cy
			var dist2: float = dx * dx + dy * dy
			if dist2 < r2 and dist2 > 0.001:
				var dist: float = sqrt(dist2)
				var factor: float = (1.0 - dist / radius) * force
				p.vx += (dx / dist) * factor
				p.vy += (dy / dist) * factor


class RefPoint:
	var x: float = 0.0
	var y: float = 0.0
	var orig_x: float = 0.0
	var orig_y: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0


func test_resize_builds_the_expected_lattice() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	# ceil(360/36) + 1 = 11 columns, ceil(180/36) + 1 = 6 rows — VectorGrid.ts:25-26
	assert_eq(grid.cols, 11, "column count")
	assert_eq(grid.rows, 6, "row count")
	assert_eq(grid.px.size(), 66, "one point per cell")
	assert_almost_eq(grid.px[0], 0.0, 0.0001, "first point sits on the origin")
	assert_almost_eq(grid.px[1], 36.0, 0.0001, "second point is one spacing over")


func test_update_pulls_a_displaced_point_back_toward_its_origin() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	grid.px[0] = 100.0
	grid.touch(0)  # a direct move bypasses the explosion that wakes the point
	grid.update(1.0 / 60.0)
	assert_lt(grid.px[0], 100.0, "the spring pulls the point back toward orig_x")
	assert_gt(grid.px[0], 0.0, "one step does not snap it home")


func test_update_settles_a_displaced_point() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	grid.px[0] = 100.0
	grid.touch(0)  # a direct move bypasses the explosion that wakes the point
	for i: int in range(400):
		grid.update(1.0 / 60.0)
	assert_almost_eq(grid.px[0], 0.0, 0.5, "the point settles on its origin")


func test_apply_explosion_pushes_points_outward_within_the_radius() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	grid.apply_explosion(0.0, 0.0, 100.0, 60.0)
	assert_gt(grid.vx[1], 0.0, "(36, 0) inside the radius is pushed away from the centre")
	assert_almost_eq(grid.vx[10], 0.0, 0.0001, "(360, 0) outside the radius is untouched")


func test_apply_implosion_pulls_points_inward() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	grid.apply_implosion(0.0, 0.0, 100.0, 60.0)
	assert_lt(grid.vx[1], 0.0, "implosion is explosion with a negated force — VectorGrid.ts:83")


func test_matches_the_pre_p3_object_grid_within_the_settle_threshold() -> void:
	seed(99)
	var ref: ReferenceGrid = ReferenceGrid.new(900.0, 400.0)
	var grid: VectorGrid = VectorGrid.new(900.0, 400.0)
	var script: Array[PackedFloat64Array] = [
		PackedFloat64Array([300.0, 200.0, 16.0, 90.0]),
		PackedFloat64Array([450.0, 100.0, -16.0, 200.0]),
	]
	for step: int in range(120):
		if step == 0 or step == 20:
			var s: PackedFloat64Array = script[0 if step == 0 else 1]
			ref.apply_explosion(s[0], s[1], s[2], s[3])
			grid.apply_explosion(s[0], s[1], s[2], s[3])
		if step >= 40 and step < 70:
			# A power-up mass kill: several blasts between two updates.
			for k: int in range(3):
				var x: float = randf() * 900.0
				var y: float = randf() * 400.0
				var force: float = 22.0 if k == 0 else 4.5
				var radius: float = 380.0 if k == 0 else 60.0
				ref.apply_explosion(x, y, force, radius)
				grid.apply_explosion(x, y, force, radius)
		ref.update()
		grid.update(1.0 / 120.0)
	# M11c review: the active-set grid snaps a point to rest below SETTLE_EPS instead of
	# letting it decay forever, so values may differ from the pre-P3 grid by less than
	# that (measured 2026-09-27: 0.000086 px, 0.000008 px/step). Otherwise it is the
	# same arithmetic.
	var max_dp: float = 0.0
	var max_dv: float = 0.0
	for i: int in range(ref.points.size()):
		var q: RefPoint = ref.points[i]
		max_dp = maxf(max_dp, maxf(absf(q.x - grid.px[i]), absf(q.y - grid.py[i])))
		max_dv = maxf(max_dv, maxf(absf(q.vx - grid.vx[i]), absf(q.vy - grid.vy[i])))
	assert_lt(max_dp, VectorGrid.SETTLE_EPS, "positions within the settle threshold")
	assert_lt(max_dv, VectorGrid.SETTLE_EPS, "velocities within the settle threshold")


func test_a_sleeping_grid_ignores_updates_and_blasts() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	grid.awake = false
	grid.apply_explosion(0.0, 0.0, 100.0, 60.0)
	grid.update(1.0 / 120.0)
	assert_eq(grid.vx[1], 0.0, "no impulse while asleep")
	assert_eq(grid.px[1], 36.0, "no movement while asleep")


func test_resize_while_asleep_builds_the_new_lattice() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	grid.awake = false
	grid.resize(720.0, 360.0)
	assert_eq(grid.cols, 21)
	assert_eq(grid.rows, 11)
	assert_eq(grid.px.size(), 21 * 11)
	assert_eq(grid.py[21 * 10], 360.0, "last row sits at its rest height")


func test_a_woken_grid_reacts_to_the_next_blast() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	grid.awake = false
	grid.resize(720.0, 360.0)
	grid.awake = true
	grid.apply_explosion(0.0, 0.0, 100.0, 60.0)
	assert_gt(grid.vx[1], 0.0, "the woken grid takes the impulse")
