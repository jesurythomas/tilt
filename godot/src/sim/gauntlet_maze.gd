## gauntlet_maze.gd
## PORTS: web/src/tilt-to-live/GauntletMaze.ts (388 lines, source commit 7be9614)
class_name GauntletMaze
extends RefCounted
## Descending wall maze for Gauntlet mode: rows of solid segments scroll down,
## block and push the ship, and crush it against the arena floor.
##
## Instantiated by GameRoot and owned by RunController. Never an autoload
## (spec §5.2).
##
## PORT-NOTE: render() (GauntletMaze.ts:302-387) is drawn by EntityLayer, as
## every sim file's render body is (entity_layer.gd:1-8; spec §5.5 puts the
## maze first in that layer).
## PORT-NOTE: spawnRow is private in the TS and sits between reset and update;
## CONVENTIONS §2 orders private methods after public ones.

## PORT: web/src/tilt-to-live/GauntletMaze.ts:30
var rows: Array[GauntletWallRow] = []
## PORT: web/src/tilt-to-live/GauntletMaze.ts:31
var current_speed: float = 75.0
## PORT: web/src/tilt-to-live/GauntletMaze.ts:32
var scale: float = 1.0
## PORT: web/src/tilt-to-live/GauntletMaze.ts:40-42
var wall_height: float:
	get:
		return 22.0 * scale
## PORT: web/src/tilt-to-live/GauntletMaze.ts:44-46
var row_spacing: float:
	get:
		return 230.0 * scale

var _next_row_id: int = 1  # PORT: web/src/tilt-to-live/GauntletMaze.ts:33
var _last_gap_x: float = 400.0  # PORT: web/src/tilt-to-live/GauntletMaze.ts:34


## PORT: web/src/tilt-to-live/GauntletMaze.ts:36-38
func set_scale(p_scale: float) -> void:
	scale = clampf(p_scale, 0.5, 1.8)


## Clears the maze and seeds four rows above the arena.
## PORT: web/src/tilt-to-live/GauntletMaze.ts:48-59
func reset(width: float = 800.0, _height: float = 600.0) -> void:
	rows = []
	_next_row_id = 1
	current_speed = 75.0 * maxf(0.72, scale)  # PORT: web/src/tilt-to-live/GauntletMaze.ts:51
	_last_gap_x = width / 2.0

	var initial_rows: int = 4  # PORT: web/src/tilt-to-live/GauntletMaze.ts:54
	for i: int in range(initial_rows):
		var y: float = -float(i) * row_spacing
		_spawn_row(y, width)


## Scrolls the rows, keeps the maze continuous, and blocks, pushes and crushes
## the ship. PORT: web/src/tilt-to-live/GauntletMaze.ts:203-300
func update(
	dt: float,
	bounds: Vector2,
	player: PlayerShip,
	score: int,
	survival_time: float,
	particles: ParticleEngine,
	on_crushed: Callable
) -> void:
	# 1. Calculate speed scaling with score & survival time.
	var base_speed: float = 75.0  # PORT: web/src/tilt-to-live/GauntletMaze.ts:213
	# PORT: web/src/tilt-to-live/GauntletMaze.ts:214
	var score_bonus: float = minf(130.0, (float(score) / 20000.0) * 45.0)
	# PORT: web/src/tilt-to-live/GauntletMaze.ts:215
	var time_bonus: float = minf(75.0, survival_time * 1.2)
	# PORT: web/src/tilt-to-live/GauntletMaze.ts:216
	current_speed = (base_speed + score_bonus + time_bonus) * maxf(0.72, scale)

	# 2. Move all wall rows downwards.
	for row: GauntletWallRow in rows:
		row.y += current_speed * dt

	# 3. Remove rows that scrolled off bottom of arena.
	var kept: Array[GauntletWallRow] = []
	for row: GauntletWallRow in rows:
		if row.y < bounds.y + 60.0:  # PORT: web/src/tilt-to-live/GauntletMaze.ts:224
			kept.append(row)
	rows = kept

	# 4. Spawn new rows from top to maintain continuous maze.
	var highest_y: float = bounds.y
	for row: GauntletWallRow in rows:
		if row.y < highest_y:
			highest_y = row.y

	if highest_y > -50.0:  # PORT: web/src/tilt-to-live/GauntletMaze.ts:234
		var new_y: float = highest_y - row_spacing
		_spawn_row(new_y, bounds.x)

	# 5. Physics: Solid Collision & Blocking against Player Ship.
	if player.is_dead:
		return

	var r: float = player.radius
	var is_squeezed_by_wall: bool = false

	for row: GauntletWallRow in rows:
		# Quick vertical culling.
		if player.y + r < row.y or player.y - r > row.y + row.height:
			continue

		for seg: WallSegment in row.segments:
			var rx: float = seg.x
			var ry: float = row.y
			var rw: float = seg.width
			var rh: float = row.height

			# Closest point on rectangle to circle center.
			var cx: float = maxf(rx, minf(player.x, rx + rw))
			var cy: float = maxf(ry, minf(player.y, ry + rh))

			var dx: float = player.x - cx
			var dy: float = player.y - cy
			var dist2: float = dx * dx + dy * dy

			if dist2 < r * r:
				var dist: float = sqrt(dist2)
				if dist > 0.001:  # PORT: web/src/tilt-to-live/GauntletMaze.ts:268
					var overlap: float = r - dist
					player.x += (dx / dist) * overlap
					player.y += (dy / dist) * overlap
				else:
					player.y += r

				# Emit friction sparks at contact point.
				if randf() < 0.35:  # PORT: web/src/tilt-to-live/GauntletMaze.ts:277
					# PORT: web/src/tilt-to-live/GauntletMaze.ts:278
					particles.emit_sparks(cx, cy, 2, Color("#ffaa00"), 90.0)

				# If the player is being pushed down by descending wall.
				# PORT: web/src/tilt-to-live/GauntletMaze.ts:282
				if player.y >= ry - 2.0 and player.y <= ry + rh + r + 4.0:
					player.y += current_speed * dt
					if player.vy < current_speed:
						player.vy = current_speed
					is_squeezed_by_wall = true

	# 6. Lethal Crush Condition.
	var bottom_floor: float = bounds.y - (r + 8.0)  # PORT: web/src/tilt-to-live/GauntletMaze.ts:295
	if player.y >= bottom_floor and is_squeezed_by_wall:
		on_crushed.call()


## Appends one wall row at `y`, picking one of four obstacle archetypes.
## PORT: web/src/tilt-to-live/GauntletMaze.ts:61-201
func _spawn_row(y: float, width: float) -> void:
	# PORT: web/src/tilt-to-live/GauntletMaze.ts:62
	var standard_gap: float = maxf(65.0, 135.0 * scale)
	var min_x: float = maxf(30.0, 60.0 * scale)  # PORT: web/src/tilt-to-live/GauntletMaze.ts:63
	# PORT: web/src/tilt-to-live/GauntletMaze.ts:64
	var max_x: float = maxf(min_x + standard_gap + 30.0, width - standard_gap - min_x)

	var pattern_roll: float = randf()
	var segments: Array[WallSegment] = []
	var gaps: Array[MazeGap] = []
	var pattern_index: int = 0

	if pattern_roll < 0.35:  # PORT: web/src/tilt-to-live/GauntletMaze.ts:76
		pattern_index = 0
		# Pattern 0: Single Guided Gap Wall.
		var dir: float = 1.0 if randf() < 0.5 else -1.0  # PORT: web/src/tilt-to-live/GauntletMaze.ts:80
		var shift: float = (70.0 + randf() * 110.0) * dir  # PORT: web/src/tilt-to-live/GauntletMaze.ts:81
		var gap_x: float = _last_gap_x + shift
		if gap_x < min_x:
			gap_x = min_x + 50.0 + randf() * 60.0  # PORT: web/src/tilt-to-live/GauntletMaze.ts:83
		if gap_x > max_x:
			gap_x = max_x - 50.0 - randf() * 60.0  # PORT: web/src/tilt-to-live/GauntletMaze.ts:84
		gap_x = maxf(min_x, minf(max_x, gap_x))
		_last_gap_x = gap_x

		if gap_x > 1.0:
			segments.append(WallSegment.new(0.0, gap_x))
		var right_x: float = gap_x + standard_gap
		if right_x < width:
			segments.append(WallSegment.new(right_x, width - right_x))
		gaps.append(MazeGap.new(gap_x, standard_gap))
	elif pattern_roll < 0.60 and width >= 750.0:  # PORT: web/src/tilt-to-live/GauntletMaze.ts:96
		pattern_index = 1
		# Pattern 1: Dual Corridor Wall.
		var g_width: float = 130.0  # PORT: web/src/tilt-to-live/GauntletMaze.ts:99
		# PORT: web/src/tilt-to-live/GauntletMaze.ts:100
		var primary_candidate: float = maxf(
			min_x, minf(max_x, _last_gap_x + (randf() * 90.0 - 45.0))
		)
		var secondary_candidate: float
		if primary_candidate > width * 0.5:
			# PORT: web/src/tilt-to-live/GauntletMaze.ts:103
			secondary_candidate = maxf(min_x, primary_candidate - (250.0 + randf() * 100.0))
		else:
			# PORT: web/src/tilt-to-live/GauntletMaze.ts:105
			secondary_candidate = minf(max_x, primary_candidate + (250.0 + randf() * 100.0))

		var g_left: float = minf(primary_candidate, secondary_candidate)
		var g_right: float = maxf(primary_candidate, secondary_candidate)

		if g_left > 0.0:
			segments.append(WallSegment.new(0.0, g_left))
		var center_start: float = g_left + g_width
		var center_width: float = g_right - center_start
		if center_width > 20.0:  # PORT: web/src/tilt-to-live/GauntletMaze.ts:116
			segments.append(WallSegment.new(center_start, center_width))
		var right_start: float = g_right + g_width
		if right_start < width:
			segments.append(WallSegment.new(right_start, width - right_start))

		gaps.append(MazeGap.new(g_left, g_width))
		gaps.append(MazeGap.new(g_right, g_width))

		_last_gap_x = primary_candidate
	elif pattern_roll < 0.85:  # PORT: web/src/tilt-to-live/GauntletMaze.ts:126
		# PORT: web/src/tilt-to-live/GauntletMaze.ts:127
		pattern_index = 2
		# Pattern 2: Floating Shorter Barricades / Pillars.
		var block_width: float = 140.0 + randf() * 50.0  # PORT: web/src/tilt-to-live/GauntletMaze.ts:130
		# PORT: web/src/tilt-to-live/GauntletMaze.ts:131
		var block1_x: float = maxf(80.0, width * 0.18 + randf() * (width * 0.08))
		# PORT: web/src/tilt-to-live/GauntletMaze.ts:132
		var block2_x: float = minf(
			width - block_width - 80.0, width * 0.64 + randf() * (width * 0.08)
		)

		segments.append(WallSegment.new(block1_x, block_width))
		if block2_x > block1_x + block_width + 80.0:  # PORT: web/src/tilt-to-live/GauntletMaze.ts:135
			segments.append(WallSegment.new(block2_x, block_width))

		gaps.append(MazeGap.new(0.0, block1_x))
		var mid_gap_x: float = block1_x + block_width
		# PORT: web/src/tilt-to-live/GauntletMaze.ts:143
		var mid_gap_width: float = maxf(80.0, block2_x - mid_gap_x)
		gaps.append(MazeGap.new(mid_gap_x, mid_gap_width))
		var right_start: float = block2_x + block_width
		if width - right_start > 0.0:
			gaps.append(MazeGap.new(right_start, width - right_start))

		# Update lastGapX to whichever passage is closest.
		var closest_gap_center: float = mid_gap_x + mid_gap_width / 2.0
		var min_gap_dist: float = absf(closest_gap_center - _last_gap_x)
		for g: MazeGap in gaps:
			var center: float = g.x + g.width / 2.0
			var dist: float = absf(center - _last_gap_x)
			if dist < min_gap_dist:
				min_gap_dist = dist
				closest_gap_center = center
		_last_gap_x = closest_gap_center
	else:
		# PORT: web/src/tilt-to-live/GauntletMaze.ts:164
		pattern_index = 3
		# Pattern 3: Central Island Block.
		# PORT: web/src/tilt-to-live/GauntletMaze.ts:167
		var island_width: float = minf(300.0, width * 0.35)
		var island_x: float
		if _last_gap_x < width * 0.5:
			# PORT: web/src/tilt-to-live/GauntletMaze.ts:171
			island_x = width * 0.45 + randf() * (width * 0.12)
		else:
			# PORT: web/src/tilt-to-live/GauntletMaze.ts:174
			island_x = width * 0.20 + randf() * (width * 0.12)
		segments.append(WallSegment.new(island_x, island_width))

		var left_gap_width: float = island_x
		var right_gap_start: float = island_x + island_width
		var right_gap_width: float = width - right_gap_start

		gaps.append(MazeGap.new(0.0, left_gap_width))
		gaps.append(MazeGap.new(right_gap_start, right_gap_width))

		var left_center: float = left_gap_width / 2.0
		var right_center: float = right_gap_start + right_gap_width / 2.0
		_last_gap_x = (
			left_center
			if absf(left_center - _last_gap_x) < absf(right_center - _last_gap_x)
			else right_center
		)

	# PORT-NOTE: every pattern pushes at least one gap, so the `|| { … }`
	# fallback (:190) never fires — preserved deliberately.
	var primary_gap: MazeGap = (
		gaps[0] if not gaps.is_empty() else MazeGap.new(width / 2.0, standard_gap)
	)
	var row: GauntletWallRow = GauntletWallRow.new()
	row.id = _next_row_id
	_next_row_id += 1
	row.y = y
	row.height = wall_height
	row.gap_x = primary_gap.x
	row.gap_width = primary_gap.width
	row.gaps = gaps
	row.segments = segments
	row.pattern = pattern_index
	rows.append(row)


## A solid stretch of one wall row. PORT: web/src/tilt-to-live/GauntletMaze.ts:8-11
class WallSegment:
	extends RefCounted
	var x: float = 0.0
	var width: float = 0.0

	func _init(p_x: float = 0.0, p_width: float = 0.0) -> void:
		x = p_x
		width = p_width


## A safe passage through one wall row. PORT: web/src/tilt-to-live/GauntletMaze.ts:13-16
class MazeGap:
	extends RefCounted
	var x: float = 0.0
	var width: float = 0.0

	func _init(p_x: float = 0.0, p_width: float = 0.0) -> void:
		x = p_x
		width = p_width


## One descending wall row. PORT: web/src/tilt-to-live/GauntletMaze.ts:18-27
class GauntletWallRow:
	extends RefCounted
	var id: int = 0
	var y: float = 0.0
	var height: float = 0.0
	var gap_x: float = 0.0
	var gap_width: float = 0.0
	var gaps: Array[MazeGap] = []
	var segments: Array[WallSegment] = []
	var pattern: int = 0
