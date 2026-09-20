## test_vector_grid.gd
## PORTS: nothing — new file, covers src/sim/vector_grid.gd
extends GutTest
## Covers the point lattice, the spring settle and the explosion impulse.


func test_resize_builds_the_expected_lattice() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	# ceil(360/36) + 1 = 11 columns, ceil(180/36) + 1 = 6 rows — VectorGrid.ts:25-26
	assert_eq(grid.cols, 11, "column count")
	assert_eq(grid.rows, 6, "row count")
	assert_eq(grid.points.size(), 66, "one point per cell")
	assert_almost_eq(grid.points[0].x, 0.0, 0.0001, "first point sits on the origin")
	assert_almost_eq(grid.points[1].x, 36.0, 0.0001, "second point is one spacing over")


func test_update_pulls_a_displaced_point_back_toward_its_origin() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	var p: VectorGrid.GridPoint = grid.points[0]
	p.x = 100.0
	p.y = 0.0
	grid.update(1.0 / 60.0)
	assert_lt(p.x, 100.0, "the spring pulls the point back toward orig_x")
	assert_gt(p.x, 0.0, "one step does not snap it home")


func test_update_settles_a_displaced_point() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	var p: VectorGrid.GridPoint = grid.points[0]
	p.x = 100.0
	for i: int in range(400):
		grid.update(1.0 / 60.0)
	assert_almost_eq(p.x, 0.0, 0.5, "the point settles on its origin")


func test_apply_explosion_pushes_points_outward_within_the_radius() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	var near: VectorGrid.GridPoint = grid.points[1]  # (36, 0)
	var far: VectorGrid.GridPoint = grid.points[10]  # (360, 0)
	grid.apply_explosion(0.0, 0.0, 100.0, 60.0)
	assert_gt(near.vx, 0.0, "a point inside the radius is pushed away from the centre")
	assert_almost_eq(far.vx, 0.0, 0.0001, "a point outside the radius is untouched")


func test_apply_implosion_pulls_points_inward() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	var near: VectorGrid.GridPoint = grid.points[1]
	grid.apply_implosion(0.0, 0.0, 100.0, 60.0)
	assert_lt(near.vx, 0.0, "implosion is explosion with a negated force — VectorGrid.ts:83")
