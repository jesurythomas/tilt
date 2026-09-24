## test_gauntlet_maze.gd
## PORTS: nothing — new file, covers src/sim/gauntlet_maze.gd (spec §6.3 Tier 1)
extends GutTest
## Proves the maze's rows, scaling, scroll/recycle, the four spawn patterns'
## geometry, blocking, pushing and the floor crush.

const BOUNDS: Vector2 = Vector2(800.0, 600.0)

var _maze: GauntletMaze
var _player: PlayerShip
var _particles: ParticleEngine
var _crushes: Array[int] = [0]


func before_each() -> void:
	seed(20260924)
	_maze = GauntletMaze.new()
	_player = PlayerShip.new(BOUNDS.x * 0.5, BOUNDS.y * 0.5)
	_particles = ParticleEngine.new()
	_crushes = [0]


func _on_crushed() -> void:
	_crushes[0] += 1


## One solid full-width row whose top edge is at `y`.
func _solid_row(y: float, height: float) -> GauntletMaze.GauntletWallRow:
	var row: GauntletMaze.GauntletWallRow = GauntletMaze.GauntletWallRow.new()
	row.id = 99
	row.y = y
	row.height = height
	row.segments = [GauntletMaze.WallSegment.new(0.0, BOUNDS.x)]
	row.gaps = [GauntletMaze.MazeGap.new(0.0, 0.0)]
	return row


func test_reset_builds_four_rows_a_spacing_apart() -> void:
	_maze.reset(BOUNDS.x, BOUNDS.y)
	assert_eq(_maze.rows.size(), 4, "GauntletMaze.ts:54")
	for i: int in range(4):
		assert_eq(_maze.rows[i].id, i + 1, "ids from 1 (:50, :192)")
		assert_almost_eq(_maze.rows[i].y, -230.0 * i, 0.0001, ":56")
		assert_almost_eq(_maze.rows[i].height, 22.0, 0.0001, ":41")
		assert_false(_maze.rows[i].gaps.is_empty(), "every row has a gap")
	assert_almost_eq(_maze.current_speed, 75.0, 0.0001, ":51")


func test_set_scale_clamps_and_scales_geometry() -> void:
	_maze.set_scale(3.0)
	assert_almost_eq(_maze.scale, 1.8, 0.0001, ":37")
	assert_almost_eq(_maze.wall_height, 22.0 * 1.8, 0.0001, ":41")
	assert_almost_eq(_maze.row_spacing, 230.0 * 1.8, 0.0001, ":45")
	_maze.set_scale(0.1)
	assert_almost_eq(_maze.scale, 0.5, 0.0001, ":37")
	_maze.reset(BOUNDS.x, BOUNDS.y)
	assert_almost_eq(_maze.current_speed, 75.0 * 0.72, 0.0001, "max(0.72, scale) (:51)")


func test_speed_follows_score_and_time() -> void:
	_player.is_dead = true
	_maze.reset(BOUNDS.x, BOUNDS.y)
	_maze.update(0.0, BOUNDS, _player, 40000, 100.0, _particles, _on_crushed)
	# (75 + min(130, 40000/20000*45) + min(75, 100*1.2)) * 1.0 (:213-216)
	assert_almost_eq(_maze.current_speed, 75.0 + 90.0 + 75.0, 0.0001)
	_maze.update(0.0, BOUNDS, _player, 100000, 10.0, _particles, _on_crushed)
	assert_almost_eq(_maze.current_speed, 75.0 + 130.0 + 12.0, 0.0001, "score bonus caps at 130")


func test_rows_scroll_recycle_and_respawn() -> void:
	_player.is_dead = true
	_maze.reset(BOUNDS.x, BOUNDS.y)
	# One 9 s step at 75 px/s moves every row 675 px: 675, 445, 215, -15.
	_maze.update(9.0, BOUNDS, _player, 0, 0.0, _particles, _on_crushed)
	var ys: Array[float] = []
	for row: GauntletMaze.GauntletWallRow in _maze.rows:
		ys.append(row.y)
	# 675 >= 600 + 60 is culled (:224); the highest (-15) is > -50, so one row
	# spawns a spacing above it (:234-237).
	assert_eq(ys.size(), 4)
	assert_almost_eq(ys[0], 445.0, 0.0001)
	assert_almost_eq(ys[1], 215.0, 0.0001)
	assert_almost_eq(ys[2], -15.0, 0.0001)
	assert_almost_eq(ys[3], -245.0, 0.0001)
	assert_eq(_maze.rows[3].id, 5, "next id continues")


func test_segments_stay_inside_the_arena_at_every_width() -> void:
	var patterns_seen: Dictionary[int, bool] = {}
	for scale: float in [1.0, 1.75]:
		for width: float in [780.0, 844.0, 1280.0, 2340.0]:
			_maze.set_scale(scale)
			for n: int in range(50):
				_maze.reset(width, BOUNDS.y)
				for row: GauntletMaze.GauntletWallRow in _maze.rows:
					patterns_seen[row.pattern] = true
					assert_false(row.gaps.is_empty(), "a row with no gap at %s" % width)
					for seg: GauntletMaze.WallSegment in row.segments:
						assert_gt(seg.width, 0.0, "segment width at %s" % width)
						assert_gte(seg.x, 0.0, "segment start at %s" % width)
						assert_lte(seg.x + seg.width, width + 0.001, "segment end at %s" % width)
	for pattern: int in [0, 1, 2, 3]:
		assert_true(patterns_seen.has(pattern), "pattern %d is reachable" % pattern)


func test_wall_blocks_the_player_from_below() -> void:
	var r: float = _player.radius
	_maze.rows = [_solid_row(100.0, 22.0)]
	_player.x = 400.0
	_player.y = 122.0 + r - 2.0
	_maze.update(0.0, BOUNDS, _player, 0, 0.0, _particles, _on_crushed)
	# Pushed out to tangency with the bottom edge (:265-274); dt 0 adds no carry.
	assert_almost_eq(_player.y, 122.0 + r, 0.0001)
	assert_almost_eq(_player.vy, 75.0, 0.0001, "vy raised to the wall speed (:284-286)")
	assert_eq(_crushes[0], 0)


func test_descending_wall_carries_the_player_down() -> void:
	var r: float = _player.radius
	_maze.rows = [_solid_row(100.0, 22.0)]
	# After the move the row spans 107.5..129.5 (75 px/s * 0.1 s).
	_player.x = 400.0
	_player.y = 129.5 + r - 2.0
	_maze.update(0.1, BOUNDS, _player, 0, 0.0, _particles, _on_crushed)
	assert_almost_eq(_player.y, 129.5 + r + 7.5, 0.0001, "push-out then carry (:283)")


func test_pinned_player_is_crushed_once_per_tick() -> void:
	# A 40-px wall over the arena floor with the ship inside it.
	_maze.rows = [_solid_row(BOUNDS.y - 40.0, 40.0)]
	_player.x = 400.0
	_player.y = BOUNDS.y - 10.0
	_maze.update(0.0, BOUNDS, _player, 0, 0.0, _particles, _on_crushed)
	assert_eq(_crushes[0], 1, "GauntletMaze.ts:295-299")
	_maze.update(0.0, BOUNDS, _player, 0, 0.0, _particles, _on_crushed)
	assert_eq(_crushes[0], 2, "the callback fires every pinned tick; lose_life guards it")


func test_no_crush_without_wall_contact() -> void:
	_maze.rows = [_solid_row(100.0, 22.0)]
	_player.x = 400.0
	_player.y = BOUNDS.y - 5.0
	_maze.update(0.0, BOUNDS, _player, 0, 0.0, _particles, _on_crushed)
	assert_eq(_crushes[0], 0, "on the floor but not squeezed")


func test_dead_player_is_not_touched() -> void:
	_maze.rows = [_solid_row(BOUNDS.y - 40.0, 40.0)]
	_player.x = 400.0
	_player.y = BOUNDS.y - 10.0
	_player.is_dead = true
	_maze.update(0.0, BOUNDS, _player, 0, 0.0, _particles, _on_crushed)
	assert_almost_eq(_player.y, BOUNDS.y - 10.0, 0.0001, ":240")
	assert_eq(_crushes[0], 0)
