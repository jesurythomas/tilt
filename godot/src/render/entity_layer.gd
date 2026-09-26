# gdlint:disable=max-file-lines
# PORT-NOTE: EntityLayer carries PlayerShip.ts, EnemySwarm.ts, WeaponSystem.ts,
# CoinSystem.ts and GauntletMaze.ts render() bodies (spec §4.2/D4); precedent
# progression_manager.gd:1-4.
## entity_layer.gd
## PORTS: web/src/tilt-to-live/PlayerShip.ts:271-632 (render player)
##        web/src/tilt-to-live/EnemySwarm.ts:1191-1648 (render)
##        web/src/tilt-to-live/WeaponSystem.ts:793-923 (render orbs, orb glyphs)
##        web/src/tilt-to-live/GauntletMaze.ts:302-387 (render)
##        per spec §5.5 and D4
class_name EntityLayer
extends Node2D
## Middle render layer. Draws weapon orbs, active weapons, enemies, and player ship.
##
## PORT-NOTE: PlayerShip.ts:359-592 branches over six alternate ship shapes
## driven by the equipped ShipSkinConfig, which GameRoot pushes in through
## set_ship_skin() (TiltGame.ts:2310). A null skin draws PlayerShip.ts:274-293's
## classic fallback — the constants below — which is also what the menu
## backdrop (M11a) gets.

## PORT: web/src/tilt-to-live/PlayerShip.ts:284-292 (the classic skin defaults)
const HULL_COLOR: Color = Color("#ffffff")
const PRIMARY_COLOR: Color = Color("#00ddff")
const ACCENT_COLOR: Color = Color("#00ffee")
const THRUSTER_COLOR: Color = Color("#00ddff")
## PORT: web/src/tilt-to-live/PlayerShip.ts:290
const TRAIL_COLOR: Color = Color(0.0, 220.0 / 255.0, 1.0, 0.4)
## PORT: web/src/tilt-to-live/PlayerShip.ts:356-357 (shielded stroke and core)
const SHIELD_STROKE: Color = Color("#00ffff")
## The orb radius the glyphs were drawn for. PORT: web/src/tilt-to-live/WeaponSystem.ts:593
const BASE_ORB_RADIUS: float = 16.0
## PORT: web/src/tilt-to-live/GauntletMaze.ts:315
const MAZE_BODY: Color = Color("#140c04")
## PORT: web/src/tilt-to-live/GauntletMaze.ts:324
const MAZE_STRIPE: Color = Color(1.0, 170.0 / 255.0, 0.0, 0.22)
## PORT: web/src/tilt-to-live/GauntletMaze.ts:337
const MAZE_EDGE: Color = Color("#ffaa00")
## PORT: web/src/tilt-to-live/GauntletMaze.ts:342
const MAZE_LEADING_EDGE: Color = Color("#FFB14D")
## PORT: web/src/tilt-to-live/GauntletMaze.ts:362
const MAZE_BEACON: Color = Color("#3DDC97")
## DIVERGENCE(M11c P13): baked dot sprites are cached per 1/8 px of sim radius.
const DOT_KEY_STEPS: float = 8.0
## DIVERGENCE(M11c P13): one screen pixel of clear border around a baked sprite.
const BAKE_MARGIN: float = 1.0
## DIVERGENCE(M11c P14): chords per dash of a dashed arc (a dash spans at most ~0.5 rad).
const DASH_ARC_CHORDS: int = 3
## DIVERGENCE(M11c P14): points of the draw_arc fallback in _ring (the TS arcs are analytic;
## the replaced calls used 24-32).
const RING_ARC_POINTS: int = 24


## DIVERGENCE(M11c P13): the two baked textures of one default-dot look. Each is
## drawn at exactly its texel size (half-extents in screen px); outer scales with
## the pulse.
class DotSprites:
	extends RefCounted
	var outer: ImageTexture = null
	var outer_half: float = 0.0
	var inner: ImageTexture = null
	var inner_half: float = 0.0


## The ship this layer draws. Null until bind() or bind_entities() is called.
var _player: PlayerShip = null
## The enemy swarm this layer draws. Null until bind_entities() is called.
var _swarm: EnemySwarm = null
## The weapon system this layer draws. Null until bind_entities() is called.
var _weapons: WeaponSystem = null
## The coin system this layer draws. Null until bind_entities() is called.
var _coins: CoinSystem = null
## The gauntlet maze this layer draws. Null until bind_maze() is called.
var _maze: GauntletMaze = null
## The run's mode; the maze draws only in gauntlet. PORT: web/src/tilt-to-live/TiltRenderer.ts:130
var _game_mode: Types.GameMode = Types.GameMode.CLASSIC
## Run clock in seconds, driving the pulsing shield and thruster flicker.
var _elapsed: float = 0.0
## Outer high contrast halo toggle. PORT: web/src/tilt-to-live/EnemySwarm.ts:1558
var _high_contrast_halo: bool = true
## The equipped ship; null draws PlayerShip.ts:274-293's classic fallback.
var _ship_skin: ProgressionManager.ShipSkinConfig = null
## The equipped enemy skin; null is the no-skin arm (the menu backdrop's case).
var _enemy_skin: ProgressionManager.EnemySkinConfig = null

# DIVERGENCE(M2.5 §6.1): the playfield is inset from the viewport, so every
# draw call in playfield-local coordinates is translated by this.
var _arena_origin: Vector2 = Vector2.ZERO

# DIVERGENCE(mobile-scale): render-only entity multiplier, see
# GameRoot.MOBILE_MODEL_SCALE. Every entity is drawn under a transform whose
# scale is this, so its whole geometry — body, arms, rings, glyph — grows
# together; sim radii and hitboxes are untouched.
var _model_scale: float = 1.0

## DIVERGENCE(M11c P13): baked default-dot sprites by radius and colour variant.
var _dot_cache: Dictionary[int, DotSprites] = {}
## DIVERGENCE(M11c P13): baked frozen-dot sprites by radius.
var _frozen_cache: Dictionary[int, ImageTexture] = {}


func _draw() -> void:
	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)
	var pt_draw: int = PerfProbe.now()
	if is_maze_drawn():
		_draw_maze()
	_draw_coins()
	_draw_weapons()
	_draw_enemies()
	_draw_player()
	PerfProbe.add("d_entity", pt_draw)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Gives this layer the ship it draws (M1 backward compatibility).
func bind(player: PlayerShip) -> void:
	_player = player


## Gives this layer all entity systems it draws. Called by GameRoot.
func bind_entities(
	player: PlayerShip,
	swarm: EnemySwarm = null,
	weapons: WeaponSystem = null,
	coins: CoinSystem = null
) -> void:
	_player = player
	_swarm = swarm
	_weapons = weapons
	_coins = coins


## Gives this layer the gauntlet maze it draws. Called by GameRoot.
func bind_maze(maze: GauntletMaze) -> void:
	_maze = maze


## Sets the run's mode. PORT: web/src/tilt-to-live/TiltGame.ts:2315
func set_game_mode(mode: Types.GameMode) -> void:
	_game_mode = mode


## True when the maze is drawn this frame. PORT: web/src/tilt-to-live/TiltRenderer.ts:130
func is_maze_drawn() -> bool:
	return _game_mode == Types.GameMode.GAUNTLET and _maze != null


## The hazard stripes of one segment, each stroke's rectangle clipped to the
## segment (M10 R8). PORT: web/src/tilt-to-live/GauntletMaze.ts:319-334
# PORT-NOTE(M10 final review F-1): a stroke whose full x-extent lies inside
# [0, seg_width] is only ever cut by the y=0/y=row_height edges of `clip`,
# never by its x=0/x=seg_width edges, so its clipped shape is identical for
# every such interior stroke up to an x translation by sx. This restructure
# clips one reference stroke against a wide y-only band once and translates
# it per interior stroke, instead of calling intersect_polygons per stroke;
# only the strokes that cross x=0 or x=seg_width still take the full clip.
# The geometry produced is unchanged (R8) — this is a performance restructure.
static func stripe_polygons(
	seg_width: float, row_height: float, elapsed: float
) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var half_width: float = 6.0 / 2.0  # PORT: web/src/tilt-to-live/GauntletMaze.ts:325
	var stripe_spacing: float = 16.0  # PORT: web/src/tilt-to-live/GauntletMaze.ts:326
	# PORT: web/src/tilt-to-live/GauntletMaze.ts:327
	var stripe_offset: float = fmod(elapsed * 20.0, stripe_spacing)
	# Each stroke runs (sx, 0) → (sx + h, h); butt caps are perpendicular to it.
	var normal: Vector2 = Vector2(-1.0, 1.0).normalized() * half_width
	var clip: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(seg_width, 0.0),
			Vector2(seg_width, row_height),
			Vector2(0.0, row_height)
		]
	)
	var half_span: float = absf(normal.x)
	var y_margin: float = row_height + half_span * 2.0
	var y_band: PackedVector2Array = PackedVector2Array(
		[
			Vector2(-y_margin, 0.0),
			Vector2(y_margin, 0.0),
			Vector2(y_margin, row_height),
			Vector2(-y_margin, row_height)
		]
	)
	var reference_stroke: PackedVector2Array = PackedVector2Array(
		[
			normal,
			-normal,
			Vector2(row_height, row_height) - normal,
			Vector2(row_height, row_height) + normal
		]
	)
	var reference_pieces: Array[PackedVector2Array] = []
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(reference_stroke, y_band):
		reference_pieces.append(piece)

	var sx: float = -row_height + stripe_offset
	while sx < seg_width + row_height:
		var stroke_min_x: float = sx - half_span
		var stroke_max_x: float = sx + row_height + half_span
		if stroke_min_x >= 0.0 and stroke_max_x <= seg_width:
			for piece: PackedVector2Array in reference_pieces:
				var translated: PackedVector2Array = PackedVector2Array()
				for p: Vector2 in piece:
					translated.append(p + Vector2(sx, 0.0))
				out.append(translated)
		else:
			var from: Vector2 = Vector2(sx, 0.0)
			var to: Vector2 = Vector2(sx + row_height, row_height)
			var stroke: PackedVector2Array = PackedVector2Array(
				[from + normal, from - normal, to - normal, to + normal]
			)
			for boundary_piece: PackedVector2Array in Geometry2D.intersect_polygons(stroke, clip):
				out.append(boundary_piece)
		sx += stripe_spacing
	return out


## PORT: web/src/tilt-to-live/GauntletMaze.ts:353
static func beacon_pulse(elapsed: float, row_id: int) -> float:
	return 0.6 + 0.4 * sin(elapsed * 8.0 + float(row_id))


## Run clock, for the pulsing shield and thruster flicker.
func set_elapsed(elapsed: float) -> void:
	_elapsed = elapsed


## Sets whether enemy high contrast halo is drawn.
func set_high_contrast_halo(enabled: bool) -> void:
	if enabled != _high_contrast_halo:
		_dot_cache.clear()
	_high_contrast_halo = enabled


## Sets the ship skin the player is drawn with. PORT: web/src/tilt-to-live/TiltGame.ts:2310
func set_ship_skin(skin: ProgressionManager.ShipSkinConfig) -> void:
	_ship_skin = skin


func get_ship_skin() -> ProgressionManager.ShipSkinConfig:
	return _ship_skin


## Sets the enemy skin every dot is drawn with. PORT: web/src/tilt-to-live/TiltGame.ts:2311
func set_enemy_skin(skin: ProgressionManager.EnemySkinConfig) -> void:
	if skin != _enemy_skin:
		_dot_cache.clear()
	_enemy_skin = skin


func get_enemy_skin() -> ProgressionManager.EnemySkinConfig:
	return _enemy_skin


## Sets the playfield's top-left corner in viewport space. Called by GameRoot.
func set_arena_origin(origin: Vector2) -> void:
	_arena_origin = origin


## Sets the render-only entity multiplier. Called by GameRoot.
func set_model_scale(model_scale: float) -> void:
	if model_scale != _model_scale:
		_dot_cache.clear()
		_frozen_cache.clear()
	_model_scale = model_scale


func get_model_scale() -> float:
	return _model_scale


## Puts one entity's playfield position at the origin, rotated and scaled by
## the model scale, so its drawer works in entity-local pixels.
func _begin_entity(pos: Vector2, angle: float = 0.0) -> void:
	draw_set_transform(_arena_origin + pos, angle, Vector2.ONE * _model_scale)


## Restores the standing arena transform _draw() set.
func _end_entity() -> void:
	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)


## Gauntlet walls, the first thing this layer draws (spec §5.5).
## PORT: web/src/tilt-to-live/GauntletMaze.ts:302-387
# PORT-NOTE: walls are arena geometry the ship collides with, so they draw in
# playfield space without the render-only model scale.
# TODO(M11c): the beacons' shadowColor/shadowBlur = 8 glow (:363-364) waits for
# the glow decision (spec §4.5), as every in-arena glow has since M2. In the TS
# that shadow state is never reset, so it also bleeds onto later rows' walls
# (M10 R9).
func _draw_maze() -> void:
	var arena_height: float = get_viewport_rect().size.y - _arena_origin.y * 2.0
	for row: GauntletMaze.GauntletWallRow in _maze.rows:
		# Skip rows completely off-screen.
		if row.y + row.height < 0.0 or row.y > arena_height:
			continue

		# 1. Render Solid Wall Segments.
		for seg: GauntletMaze.WallSegment in row.segments:
			var origin: Vector2 = Vector2(seg.x, row.y)
			var rect: Rect2 = Rect2(origin, Vector2(seg.width, row.height))
			draw_rect(rect, MAZE_BODY)
			var shift: Transform2D = Transform2D(0.0, origin)
			for stripe: PackedVector2Array in stripe_polygons(seg.width, row.height, _elapsed):
				draw_colored_polygon(shift * stripe, MAZE_STRIPE)
			draw_rect(rect, MAZE_EDGE, false, 2.0)  # PORT: web/src/tilt-to-live/GauntletMaze.ts:338-339
			# PORT: web/src/tilt-to-live/GauntletMaze.ts:343-347
			draw_line(
				origin + Vector2(0.0, row.height),
				origin + Vector2(seg.width, row.height),
				MAZE_LEADING_EDGE,
				2.5
			)

		# 2. Safe Gap Guidance Beacons.
		var pulse: float = beacon_pulse(_elapsed, row.id)
		var active_gaps: Array[GauntletMaze.MazeGap] = row.gaps
		if active_gaps.is_empty():
			# PORT-NOTE: every row has a gap (gauntlet_maze.gd's _spawn_row), so
			# this fallback (:354) never fires — preserved deliberately.
			active_gaps = [GauntletMaze.MazeGap.new(row.gap_x, row.gap_width)]
		var mid_y: float = row.y + row.height / 2.0
		for gap: GauntletMaze.MazeGap in active_gaps:
			var left: Vector2 = Vector2(gap.x, mid_y)
			var right: Vector2 = Vector2(gap.x + gap.width, mid_y)
			draw_circle(left, 3.5 * pulse, MAZE_BEACON)  # PORT: web/src/tilt-to-live/GauntletMaze.ts:366
			draw_circle(right, 3.5 * pulse, MAZE_BEACON)  # PORT: web/src/tilt-to-live/GauntletMaze.ts:371
			# PORT: web/src/tilt-to-live/GauntletMaze.ts:375
			var beam: Color = Color(MAZE_BEACON, 0.15 * pulse)
			# PORT: web/src/tilt-to-live/GauntletMaze.ts:376-382 (setLineDash [4, 4])
			_draw_dashed_line_offset(left, right, 4.0, 4.0, 0.0, beam, 1.5)


## Coins, under the orbs (spec §5.5). PORT: web/src/tilt-to-live/CoinSystem.ts:126-175
# PORT-NOTE: the radial gradient (:146-149, stops #FFE3B0 / COIN_COLOR /
# #B8792A) is two flat circles per the M3 ruling: the disc in COIN_COLOR and
# a highlight at the gradient's (-2, -2) centre in #FFE3B0 at the 0.55 stop's
# radius fraction; the outer #B8792A stop reads as the 1.4 px white stroke's
# neighbour and is not drawn. The two quadraticCurveTo glyph strokes
# (:167-169) are sampled polylines.
# DIVERGENCE(M11c P14): full circles and outlines draw from CircleSprites (see _ring).
func _draw_coins() -> void:
	if _coins == null or _coins.coins.is_empty():
		return
	for coin: CoinSystem.CoinPickup in _coins.coins:
		var pulse: float = 0.9 + 0.1 * sin(_elapsed * 7.0 + coin.pulse_offset)  # PORT: :131
		var fade_alpha: float = 1.0
		if coin.lifetime < CoinSystem.FADE_WARNING_TIME:
			fade_alpha = maxf(0.15, coin.lifetime / CoinSystem.FADE_WARNING_TIME)  # PORT: :132
		_begin_entity(Vector2(coin.x, coin.y))
		var pos: Vector2 = Vector2.ZERO

		# Soft amber glow halo. PORT: :139-142 (`${COIN_COLOR}33` = alpha 0x33)
		var halo: Color = CoinSystem.COIN_COLOR
		halo.a = (0x33 / 255.0) * fade_alpha
		CircleSprites.draw_disc(self, pos, (coin.radius + 7.0) * pulse, halo)

		# Solid coin disc. PORT: :146-153
		var disc: Color = CoinSystem.COIN_COLOR
		disc.a = fade_alpha
		var r: float = coin.radius * pulse
		CircleSprites.draw_disc(self, pos, r, disc)
		var highlight: Color = Color("#FFE3B0")  # PORT: :147
		highlight.a = fade_alpha
		CircleSprites.draw_disc(self, pos + Vector2(-2.0, -2.0), r * 0.55, highlight)  # PORT: :146, :148
		var rim: Color = Color.WHITE
		rim.a = fade_alpha
		# PORT-NOTE: polyline resolution, a Godot choice with no TS counterpart
		# (canvas arc/quadraticCurveTo are analytic) — same class as the M3
		# gradient ruling.
		_ring(pos, r, 1.4, rim)  # PORT: :155-157

		# Currency glyph (dollar-style bar). PORT: :160-170
		var ink: Color = Color("#4A2E0A")
		ink.a = fade_alpha
		draw_line(
			pos + Vector2(0.0, -coin.radius * 0.55),
			pos + Vector2(0.0, coin.radius * 0.55),
			ink,
			1.8
		)
		var upper: PackedVector2Array = _quadratic_points(
			pos + Vector2(-coin.radius * 0.4, -coin.radius * 0.25),
			pos + Vector2(coin.radius * 0.45, -coin.radius * 0.25),
			pos + Vector2(coin.radius * 0.4, 0.0)
		)
		var lower: PackedVector2Array = _quadratic_points(
			pos + Vector2(coin.radius * 0.4, 0.0),
			pos + Vector2(coin.radius * 0.45, coin.radius * 0.25),
			pos + Vector2(-coin.radius * 0.4, coin.radius * 0.25)
		)
		upper.append_array(lower)
		draw_polyline(upper, ink, 1.8)
		_end_entity()


# A quadratic Bézier (Canvas quadraticCurveTo) sampled as a polyline.
# PORT-NOTE: polyline resolution, a Godot choice with no TS counterpart
# (canvas arc/quadraticCurveTo are analytic) — same class as the M3 gradient
# ruling.
func _quadratic_points(p0: Vector2, control: Vector2, p1: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(9):
		var t: float = float(i) / 8.0
		var q0: Vector2 = p0.lerp(control, t)
		var q1: Vector2 = control.lerp(p1, t)
		out.append(q0.lerp(q1, t))
	return out


# DIVERGENCE(M11c P14): full circles and outlines draw from CircleSprites (see _ring).
func _draw_weapons() -> void:
	if _weapons == null:
		return

	# 1. Floating weapon orbs (PORT: web/src/tilt-to-live/WeaponSystem.ts:793-828)
	for orb: Types.WeaponOrb in _weapons.orbs:
		var is_expiring: bool = orb.lifetime < 3.0 and (int(_elapsed * 8.0) % 2 == 0)
		if is_expiring:
			continue

		var pulse: float = 0.88 + 0.12 * sin(_elapsed * 6.0 + orb.pulse_offset)
		var orb_col: Color = _weapons.get_weapon_color(orb.type)
		_begin_entity(Vector2(orb.x, orb.y))
		var orb_pos: Vector2 = Vector2.ZERO

		# Outer pulsing glow (PORT: WeaponSystem.ts:804-807)
		var glow_col: Color = Color(orb_col.r, orb_col.g, orb_col.b, 0.2)
		CircleSprites.draw_disc(self, orb_pos, (orb.radius + 8.0) * pulse, glow_col)

		# Translucent bubble fill (PORT: WeaponSystem.ts:809-817)
		var bubble_col: Color = Color(orb_col.r, orb_col.g, orb_col.b, 0.65)
		CircleSprites.draw_disc(self, orb_pos, orb.radius, bubble_col)

		# Sharp neon perimeter (PORT: WeaponSystem.ts:820-822)
		_ring(orb_pos, orb.radius, 1.8, Color.WHITE)

		# Glyph symbols (PORT: WeaponSystem.ts:833-923)
		# DIVERGENCE(mobile-scale): the TS draws the glyph at fixed pixels
		# inside a bubble that scales with the arena (WeaponSystem.ts:593 sets
		# radius = 16 * scale), so on a phone the symbol shrinks to a speck.
		# The glyph is scaled to its bubble here; at desktop scale (~1.05)
		# this is visually the TS.
		draw_set_transform(
			_arena_origin + Vector2(orb.x, orb.y),
			0.0,
			Vector2.ONE * _model_scale * (orb.radius / BASE_ORB_RADIUS)
		)
		_draw_orb_glyph(orb_pos, orb.type)
		_end_entity()


## PORT: web/src/tilt-to-live/WeaponSystem.ts:833-923
# DIVERGENCE(M11c P14): full circles and outlines draw from CircleSprites (see _ring).
func _draw_orb_glyph(pos: Vector2, type: Types.WeaponType) -> void:
	var width: float = 1.6  # PORT: web/src/tilt-to-live/WeaponSystem.ts:836
	match type:
		Types.WeaponType.NUKE:
			# Radioactive trefoil. PORT: web/src/tilt-to-live/WeaponSystem.ts:841-849
			CircleSprites.draw_disc(self, pos, 2.5, Color.WHITE)
			for i: int in range(3):
				var a: float = (float(i) * PI * 2.0) / 3.0
				draw_arc(pos, 8.0, a - 0.45, a + 0.45, 16, Color.WHITE, width)
		Types.WeaponType.MISSILES:
			# Rocket. PORT: web/src/tilt-to-live/WeaponSystem.ts:854-860
			var rocket: PackedVector2Array = PackedVector2Array(
				[
					pos + Vector2(0.0, -7.0),
					pos + Vector2(4.0, 5.0),
					pos + Vector2(0.0, 2.0),
					pos + Vector2(-4.0, 5.0)
				]
			)
			draw_colored_polygon(rocket, Color.WHITE)
		Types.WeaponType.LIGHTNING:
			# Bolt. PORT: web/src/tilt-to-live/WeaponSystem.ts:865-873
			# PORT-NOTE: the TS outline (2,-7)(-4,0)(0,0)(-2,7)(4,0)(0,0) touches itself
			# at (0,0); Godot's triangulator draws nothing for a non-simple polygon, so the
			# outline is filled as the two triangles the canvas nonzero rule produces.
			var upper: PackedVector2Array = PackedVector2Array(
				[pos + Vector2(2.0, -7.0), pos + Vector2(-4.0, 0.0), pos + Vector2(0.0, 0.0)]
			)
			var lower: PackedVector2Array = PackedVector2Array(
				[pos + Vector2(0.0, 0.0), pos + Vector2(-2.0, 7.0), pos + Vector2(4.0, 0.0)]
			)
			draw_colored_polygon(upper, Color.WHITE)
			draw_colored_polygon(lower, Color.WHITE)
		Types.WeaponType.LASER:
			# Crossed beams. PORT: web/src/tilt-to-live/WeaponSystem.ts:878-881
			draw_line(pos + Vector2(-6.0, -6.0), pos + Vector2(6.0, 6.0), Color.WHITE, width)
			draw_line(pos + Vector2(6.0, -6.0), pos + Vector2(-6.0, 6.0), Color.WHITE, width)
		Types.WeaponType.VORTEX:
			# Spiral. PORT: web/src/tilt-to-live/WeaponSystem.ts:886-894
			var spiral: PackedVector2Array = PackedVector2Array()
			for r: int in range(2, 8):
				var a: float = float(r) * 0.9
				spiral.append(pos + Vector2(cos(a) * float(r), sin(a) * float(r)))
			draw_polyline(spiral, Color.WHITE, width)
		Types.WeaponType.FREEZE:
			# Snowflake. PORT: web/src/tilt-to-live/WeaponSystem.ts:899-905
			for i: int in range(6):
				var a: float = (float(i) * PI) / 3.0
				draw_line(pos, pos + Vector2(cos(a) * 7.0, sin(a) * 7.0), Color.WHITE, width)
		Types.WeaponType.SHIELD:
			# Shield outline. PORT: web/src/tilt-to-live/WeaponSystem.ts:910-918
			var shield: PackedVector2Array = PackedVector2Array(
				[
					pos + Vector2(0.0, -6.0),
					pos + Vector2(5.0, -3.0),
					pos + Vector2(4.0, 3.0),
					pos + Vector2(0.0, 7.0),
					pos + Vector2(-4.0, 3.0),
					pos + Vector2(-5.0, -3.0),
				]
			)
			draw_polyline(_closed(shield), Color.WHITE, width)


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1191-1648 (render)
## PORT-NOTE: skin is the equipped EnemySkinConfig GameRoot pushes in through
## set_enemy_skin() (TiltGame.ts:2311); null is the menu backdrop's case
## (:2275). Charger, artillery and carrier gate their skin arms on
## skin.id !== 'classic' (EnemySwarm.ts:1260, :1293, :1406) while pulsar,
## specter and the default dot gate on skin alone (:1476, :1521, :1561) —
## the asymmetry is the TS's and is preserved (LAW 2). In a live run skin is
## never null, so the hazard-orange arms (:1563-1566, :1579-1580, :1598-1601,
## :1616-1617, :1627-1628) are reachable only from the backdrop.
## PORT-NOTE: createRadialGradient (EnemySwarm.ts:1370, :1484, :1531, :1589) is
## not baked as a texture in this module. Per the M2 precedent at :187-199
## (Open question 3), each two/three-stop gradient is approximated as two flat
## draw_circle calls: the full radius filled with the middle stop's colour,
## then a smaller circle at (radius * middle-stop-position) filled with the
## innermost stop's colour. The outermost stop is dropped by this technique.
## _gameMode is unused in the TS (EnemySwarm.ts:1196) and gets no port.
func _draw_enemies() -> void:
	if _swarm == null:
		return

	for e: Types.Enemy in _swarm.enemies:
		if e.frozen:
			_draw_frozen_dot(e)
			continue
		if e.type == Types.EnemyType.CHARGER:
			_draw_charger(e)
			continue
		if e.type == Types.EnemyType.ARTILLERY:
			_draw_artillery(e)
			continue
		if e.type == Types.EnemyType.BULLET:
			_draw_bullet(e)
			continue
		if e.type == Types.EnemyType.CARRIER:
			_draw_carrier(e)
			continue
		if e.parent_carrier_id != Types.ABSENT:
			_draw_satellite(e)
			continue
		if e.type == Types.EnemyType.PULSAR:
			_draw_pulsar(e)
			continue
		if e.type == Types.EnemyType.SPECTER:
			_draw_specter(e)
			continue
		_draw_default_dot(e)


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1204-1222
# DIVERGENCE(M11c P13): the three layers are baked into one cached texture.
func _draw_frozen_dot(e: Types.Enemy) -> void:
	var key: int = roundi(e.radius * DOT_KEY_STEPS)
	var s: float = _model_scale
	var size: int = ceili(((e.radius + 3.0) * s + BAKE_MARGIN) * 2.0)
	var tex: ImageTexture = _frozen_cache.get(key)
	if tex == null:
		tex = CircleSprites.bake_layers(
			size,
			PackedFloat32Array([(e.radius + 3.0) * s, (e.radius + 1.0) * s, (e.radius - 1.0) * s]),
			PackedFloat32Array([0.0, 1.5 * s, 0.0]),
			PackedColorArray(
				[Color(136.0 / 255.0, 238.0 / 255.0, 1.0, 0.45), Color.WHITE, Color("#4488aa")]
			)
		)
		_frozen_cache[key] = tex
	var half: float = size * 0.5
	draw_texture_rect(
		tex, Rect2(Vector2(e.x, e.y) - Vector2(half, half), Vector2(half, half) * 2.0), false
	)


## `skin && skin.id !== 'classic'`. PORT: web/src/tilt-to-live/EnemySwarm.ts:1260
func _has_alt_skin() -> bool:
	return _enemy_skin != null and _enemy_skin.id != "classic"


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1225-1286
func _draw_charger(e: Types.Enemy) -> void:
	# PORT: EnemySwarm.ts:1226
	var angle: float = (
		atan2(e.vy, e.vx)
		if e.state == Types.EnemyState.CHARGING
		else (e.aim_angle if not is_nan(e.aim_angle) else 0.0)
	)
	_begin_entity(Vector2(e.x, e.y), angle)

	# Laser telegraph line while aiming (PORT: EnemySwarm.ts:1229-1243)
	if e.state == Types.EnemyState.AIMING:
		var dash_offset: float = fmod(_elapsed * 50.0, 16.0)  # PORT: EnemySwarm.ts:1232
		var telegraph_col: Color = Color(
			1.0, 60.0 / 255.0, 30.0 / 255.0, 0.4 + 0.4 * sin(_elapsed * 22.0)
		)  # PORT: EnemySwarm.ts:1233
		_draw_dashed_line_offset(
			Vector2(14.0, 0.0), Vector2(480.0, 0.0), 8.0, 6.0, -dash_offset, telegraph_col, 1.5
		)  # PORT: EnemySwarm.ts:1235-1240

	# Rocket thruster plume if charging (PORT: EnemySwarm.ts:1247-1257)
	if e.state == Types.EnemyState.CHARGING:
		var jet_len: float = 14.0 + randf() * 8.0  # PORT: EnemySwarm.ts:1249
		var plume: PackedVector2Array = PackedVector2Array(
			[Vector2(-8.0, -4.0), Vector2(-8.0 - jet_len, 0.0), Vector2(-8.0, 4.0)]
		)  # PORT: EnemySwarm.ts:1250-1256
		draw_colored_polygon(plume, Color("#ffaa00"))  # PORT: EnemySwarm.ts:1250

	# Arrowhead delta dart chassis (PORT: EnemySwarm.ts:1259-1272)
	# PORT: EnemySwarm.ts:1260-1261
	var hull_col: Color = (
		_enemy_skin.body_gradient[1]
		if _has_alt_skin()
		else (Color("#ff2a00") if e.state == Types.EnemyState.CHARGING else Color("#dd1c00"))
	)
	var edge_col: Color = _enemy_skin.border_color if _has_alt_skin() else Color("#ffaa33")
	var hull: PackedVector2Array = PackedVector2Array(
		[Vector2(14.0, 0.0), Vector2(-10.0, -11.0), Vector2(-6.0, 0.0), Vector2(-10.0, 11.0)]
	)  # PORT: EnemySwarm.ts:1266-1269
	draw_colored_polygon(hull, hull_col)
	draw_polyline(_closed(hull), edge_col, 1.8)  # PORT: EnemySwarm.ts:1261-1264

	# Cockpit / energy crystal core (PORT: EnemySwarm.ts:1274-1282)
	# PORT: EnemySwarm.ts:1275
	var core_col: Color = (
		Color.WHITE
		if e.state == Types.EnemyState.CHARGING
		else (_enemy_skin.pupil_color if _has_alt_skin() else Color("#FFB14D"))
	)
	var core: PackedVector2Array = PackedVector2Array(
		[Vector2(6.0, 0.0), Vector2(-2.0, -3.5), Vector2(0.0, 0.0), Vector2(-2.0, 3.5)]
	)  # PORT: EnemySwarm.ts:1277-1280
	draw_colored_polygon(core, core_col)

	_end_entity()


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1289-1350
# DIVERGENCE(M11c P14): full circles and outlines draw from CircleSprites (see _ring).
func _draw_artillery(e: Types.Enemy) -> void:
	var angle: float = e.aim_angle if not is_nan(e.aim_angle) else 0.0  # PORT: EnemySwarm.ts:1290
	_begin_entity(Vector2(e.x, e.y), angle)

	# Cannon barrel (PORT: EnemySwarm.ts:1295-1299)
	# PORT: EnemySwarm.ts:1293
	var barrel_stroke: Color = _enemy_skin.border_color if _has_alt_skin() else Color("#ff0066")
	var barrel_rect: Rect2 = Rect2(4.0, -4.0, 18.0, 8.0)
	draw_rect(barrel_rect, Color("#180e22"))
	draw_rect(barrel_rect, barrel_stroke, false, 1.5)

	# Muzzle charge flash if preparing to fire (PORT: EnemySwarm.ts:1302-1308)
	if not is_nan(e.fire_cooldown) and e.fire_cooldown < 0.8:
		var charge_ratio: float = (0.8 - e.fire_cooldown) / 0.8  # PORT: EnemySwarm.ts:1303
		CircleSprites.draw_disc(
			self,
			Vector2(22.0, 0.0),
			3.0 + charge_ratio * 4.0,
			Color(1.0, 0.0, 150.0 / 255.0, 0.5 + charge_ratio * 0.5)
		)  # PORT: EnemySwarm.ts:1304-1306

	# Heavy hexagonal hull (PORT: EnemySwarm.ts:1310-1327)
	var hex_radius: float = 13.0  # PORT: EnemySwarm.ts:1317
	var hex: PackedVector2Array = PackedVector2Array()
	for h: int in range(6):
		var a: float = float(h) * PI / 3.0  # PORT: EnemySwarm.ts:1319
		hex.append(Vector2(cos(a) * hex_radius, sin(a) * hex_radius))
	# PORT: EnemySwarm.ts:1311
	var hex_fill: Color = _enemy_skin.body_gradient[2] if _has_alt_skin() else Color("#1c0a1a")
	# PORT: EnemySwarm.ts:1312
	var hex_stroke: Color = _enemy_skin.border_color if _has_alt_skin() else Color("#ff0077")
	draw_colored_polygon(hex, hex_fill)
	draw_polyline(_closed(hex), hex_stroke, 2.2)

	# Armored cross struts (PORT: EnemySwarm.ts:1329-1335)
	var strut_col: Color = Color(1.0, 1.0, 1.0, 0.25)
	draw_line(Vector2(-hex_radius, 0.0), Vector2(hex_radius, 0.0), strut_col, 1.0)
	draw_line(Vector2(0.0, -hex_radius), Vector2(0.0, hex_radius), strut_col, 1.0)

	# Pulsing optic sensor eye (PORT: EnemySwarm.ts:1337-1346)
	var optic_pulse: float = 0.8 + 0.2 * sin(_elapsed * 14.0)  # PORT: EnemySwarm.ts:1338
	# PORT: EnemySwarm.ts:1339
	var optic_col: Color = _enemy_skin.body_gradient[0] if _has_alt_skin() else Color("#ff00bb")
	CircleSprites.draw_disc(self, Vector2.ZERO, 5.0 * optic_pulse, optic_col)
	CircleSprites.draw_disc(self, Vector2.ZERO, 2.0, Color.WHITE)

	_end_entity()


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1353-1385
# DIVERGENCE(M11c P14): full circles and outlines draw from CircleSprites (see _ring).
func _draw_bullet(e: Types.Enemy) -> void:
	var angle: float = atan2(e.vy, e.vx)  # PORT: EnemySwarm.ts:1354
	_begin_entity(Vector2(e.x, e.y), angle)

	# Plasma comet tail (PORT: EnemySwarm.ts:1358-1367)
	var tail: PackedVector2Array = PackedVector2Array(
		[Vector2(-18.0, 0.0), Vector2(0.0, -4.0), Vector2(0.0, 4.0)]
	)
	var tail_colors: PackedColorArray = PackedColorArray(
		[
			Color(1.0, 0.0, 128.0 / 255.0, 0.0),
			Color(1.0, 0.0, 180.0 / 255.0, 0.85),
			Color(1.0, 0.0, 180.0 / 255.0, 0.85)
		]
	)  # PORT: EnemySwarm.ts:1359-1360
	draw_polygon(tail, tail_colors)

	# Core plasma energy ball (PORT: EnemySwarm.ts:1370-1373, two-circle rule)
	CircleSprites.draw_disc(self, Vector2.ZERO, e.radius, Color("#ff2299"))
	CircleSprites.draw_disc(self, Vector2.ZERO, e.radius * 0.5, Color.WHITE)
	_ring(Vector2.ZERO, e.radius, 1.2, Color.WHITE)  # PORT: EnemySwarm.ts:1379-1381

	_end_entity()


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1388-1444
# DIVERGENCE(M11c P14): full circles and outlines draw from CircleSprites (see _ring).
func _draw_carrier(e: Types.Enemy) -> void:
	var carrier_pos: Vector2 = Vector2(e.x, e.y)

	# Tether lines to child satellites, under the standing arena transform
	# (PORT: EnemySwarm.ts:1390-1401)
	for sat: Types.Enemy in _swarm.enemies:
		if sat.parent_carrier_id == e.id:
			var tether_col: Color = Color(
				0.0, 229.0 / 255.0, 1.0, 0.4 + 0.3 * sin(_elapsed * 12.0 + float(sat.id))
			)  # PORT: EnemySwarm.ts:1393
			draw_line(carrier_pos, Vector2(sat.x, sat.y), tether_col, 1.2)

	# PORT: EnemySwarm.ts:1403
	_begin_entity(carrier_pos, _elapsed * 0.45)

	# Pulsing orbital shield ring (PORT: EnemySwarm.ts:1406-1414)
	var ring_col: Color = (
		_enemy_skin.glow_color if _has_alt_skin() else Color(1.0, 30.0 / 255.0, 80.0 / 255.0, 0.45)
	)  # PORT: EnemySwarm.ts:1406
	_draw_dashed_arc(Vector2.ZERO, e.radius + 8.0, 10.0, 8.0, -_elapsed * 30.0, ring_col, 2.0)

	# Diamond dreadnought mothership hull (PORT: EnemySwarm.ts:1416-1429)
	# PORT: EnemySwarm.ts:1417
	var diamond_fill: Color = _enemy_skin.body_gradient[2] if _has_alt_skin() else Color("#220816")
	# PORT: EnemySwarm.ts:1418
	var diamond_stroke: Color = _enemy_skin.border_color if _has_alt_skin() else Color("#ff2a55")
	var diamond: PackedVector2Array = PackedVector2Array(
		[
			Vector2(e.radius + 4.0, 0.0),
			Vector2(0.0, -e.radius - 4.0),
			Vector2(-e.radius - 4.0, 0.0),
			Vector2(0.0, e.radius + 4.0)
		]
	)  # PORT: EnemySwarm.ts:1423-1426
	draw_colored_polygon(diamond, diamond_fill)
	draw_polyline(_closed(diamond), diamond_stroke, 2.4)

	# Inner glowing core (PORT: EnemySwarm.ts:1431-1440)
	# PORT: EnemySwarm.ts:1432
	var core_col: Color = _enemy_skin.body_gradient[0] if _has_alt_skin() else Color("#ff1144")
	CircleSprites.draw_disc(self, Vector2.ZERO, 8.0, core_col)
	CircleSprites.draw_disc(self, Vector2.ZERO, 3.5, Color.WHITE)

	_end_entity()


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1447-1466
# DIVERGENCE(M11c P14): full circles and outlines draw from CircleSprites (see _ring).
func _draw_satellite(e: Types.Enemy) -> void:
	_begin_entity(Vector2(e.x, e.y))
	var pos: Vector2 = Vector2.ZERO
	_ring(pos, e.radius + 3.0, 1.5, Color("#00e5ff"))
	CircleSprites.draw_disc(self, pos, e.radius + 2.0, Color(0.0, 229.0 / 255.0, 1.0, 0.35))
	CircleSprites.draw_disc(self, pos, e.radius * 0.5, Color.WHITE)
	_end_entity()


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1469-1513
## PORT-NOTE: skin gates the borderColor/bodyGradient/pupilColor branches
## alone (:1476, :1483, :1490, :1498), unlike charger/artillery/carrier which
## gate on skin.id !== 'classic' — the asymmetry is the TS's and is preserved.
# DIVERGENCE(M11c P14): full circles and outlines draw from CircleSprites (see _ring).
func _draw_pulsar(e: Types.Enemy) -> void:
	_begin_entity(Vector2(e.x, e.y))
	var pos: Vector2 = Vector2.ZERO
	# PORT: EnemySwarm.ts:1470
	var pulse_phase: float = (2.2 - e.pulse_timer) / 2.2 if not is_nan(e.pulse_timer) else 0.0
	var ring_radius: float = e.radius + 5.0 + pulse_phase * 16.0  # PORT: EnemySwarm.ts:1471
	var ring_alpha: float = maxf(0.0, (1.0 - pulse_phase) * 0.8)  # PORT: EnemySwarm.ts:1472,1475
	# PORT: EnemySwarm.ts:1476-1480
	var ring_col: Color = (
		_enemy_skin.border_color if _enemy_skin != null else Color(1.0, 71.0 / 255.0, 87.0 / 255.0)
	)
	ring_col.a = ring_alpha
	_ring(pos, ring_radius, 2.0, ring_col)
	# Core vibrant body gradient (PORT: EnemySwarm.ts:1483-1487, two-circle rule)
	var inner: Color = _enemy_skin.body_gradient[0] if _enemy_skin != null else Color("#ff8899")
	var mid: Color = _enemy_skin.body_gradient[1] if _enemy_skin != null else Color("#ee1133")
	CircleSprites.draw_disc(self, pos, e.radius, mid)
	CircleSprites.draw_disc(self, pos, e.radius * 0.6, inner)
	# PORT: EnemySwarm.ts:1490-1495
	var stroke: Color = _enemy_skin.border_color if _enemy_skin != null else Color("#ffa502")
	_ring(pos, e.radius, 2.2, stroke)

	# Eight-point spinning star core (PORT: EnemySwarm.ts:1499-1509)
	# PORT: EnemySwarm.ts:1498
	var star_col: Color = _enemy_skin.pupil_color if _enemy_skin != null else Color.WHITE
	var star: PackedVector2Array = PackedVector2Array()
	for p: int in range(8):
		var a: float = float(p) * PI / 4.0 + _elapsed * 3.0  # PORT: EnemySwarm.ts:1501
		var r: float = e.radius * 0.55 if p % 2 == 0 else e.radius * 0.22  # PORT: EnemySwarm.ts:1502
		star.append(pos + Vector2(cos(a) * r, sin(a) * r))
	draw_colored_polygon(star, star_col)
	_end_entity()


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1516-1552
## PORT-NOTE: skin gates the borderColor/bodyGradient/pupilColor branches
## alone (:1521, :1530, :1537, :1545), matching pulsar's asymmetry — see
## _draw_pulsar's PORT-NOTE.
# DIVERGENCE(M11c P14): full circles and outlines draw from CircleSprites (see _ring).
func _draw_specter(e: Types.Enemy) -> void:
	_begin_entity(Vector2(e.x, e.y))
	var pos: Vector2 = Vector2.ZERO
	# PORT: EnemySwarm.ts:1517
	var alpha: float = e.stealth_opacity if not is_nan(e.stealth_opacity) else 0.65

	# PORT: EnemySwarm.ts:1521-1528
	var dash_col: Color = _enemy_skin.border_color if _enemy_skin != null else Color("#a78bfa")
	dash_col.a = alpha
	_draw_dashed_arc(pos, e.radius + 3.0, 4.0, 4.0, -_elapsed * 25.0, dash_col, 1.6)

	# Core vibrant body gradient (PORT: EnemySwarm.ts:1530-1534, two-circle rule)
	var mid: Color = _enemy_skin.body_gradient[1] if _enemy_skin != null else Color("#8b5cf6")
	mid.a = alpha
	var inner: Color = _enemy_skin.body_gradient[0] if _enemy_skin != null else Color("#c4b5fd")
	inner.a = alpha
	CircleSprites.draw_disc(self, pos, e.radius, mid)
	CircleSprites.draw_disc(self, pos, e.radius * 0.65, inner)
	# PORT: EnemySwarm.ts:1537-1542
	var stroke: Color = _enemy_skin.border_color if _enemy_skin != null else Color("#e0e7ff")
	stroke.a = alpha
	_ring(pos, e.radius, 1.5, stroke)

	# PORT: EnemySwarm.ts:1545-1548
	var pupil_col: Color = _enemy_skin.pupil_color if _enemy_skin != null else Color.WHITE
	pupil_col.a = alpha
	CircleSprites.draw_disc(self, pos, 2.5, pupil_col)
	_end_entity()


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1554-1643 (default dot + turret indicator)
# DIVERGENCE(M11c P13): the dot's layers are baked into two cached textures (see
# _dot_sprites) and drawn as two rects, in the TS order (halo and glow, then body,
# inner, border and pupil). The halo's stroke now scales with the pulse
# (1.02-1.2 px instead of 1.2 px).
func _draw_default_dot(e: Types.Enemy) -> void:
	var e_pos: Vector2 = Vector2(e.x, e.y)
	var pulse: float = 0.85 + 0.15 * sin(_elapsed * 9.0 + float(e.id))
	var sprites: DotSprites = _dot_sprites(e.radius, e.chilled, e.is_hazard)
	var outer_half: float = sprites.outer_half * pulse
	draw_texture_rect(
		sprites.outer,
		Rect2(e_pos - Vector2(outer_half, outer_half), Vector2(outer_half, outer_half) * 2.0),
		false
	)
	var inner_half: float = sprites.inner_half
	draw_texture_rect(
		sprites.inner,
		Rect2(e_pos - Vector2(inner_half, inner_half), Vector2(inner_half, inner_half) * 2.0),
		false
	)

	# Turret dot warning indicator (PORT: EnemySwarm.ts:1635-1643)
	if (
		e.type == Types.EnemyType.TURRET_DOT
		and not is_nan(e.target_angle)
		and e.orbit_center == Vector2.ZERO
	):
		_begin_entity(e_pos, e.target_angle)
		draw_line(
			Vector2(e.radius, 0.0),
			Vector2(e.radius + 18.0, 0.0),
			Color(1.0, 50.0 / 255.0, 50.0 / 255.0, 0.5),
			1.5
		)
		_end_entity()


## The default dot's colours: halo, glow, body, inner, border, pupil.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:1557-1632
func _dot_palette(chilled: bool, is_hazard: bool) -> PackedColorArray:
	# Outer glow & high contrast halo (PORT: EnemySwarm.ts:1557-1572)
	var halo_col: Color
	if chilled:
		halo_col = Color(140.0 / 255.0, 240.0 / 255.0, 1.0, 0.7)
	elif _enemy_skin != null:
		halo_col = _enemy_skin.glow_color  # PORT: :1561-1562
	elif is_hazard:
		halo_col = Color(1.0, 180.0 / 255.0, 0.0, 0.7)
	else:
		halo_col = Color(1.0, 30.0 / 255.0, 60.0 / 255.0, 0.7)

	# Outer glow color (PORT: EnemySwarm.ts:1574-1586)
	var glow_col: Color
	if chilled:
		glow_col = Color(130.0 / 255.0, 230.0 / 255.0, 1.0, 0.55)
	elif _enemy_skin != null:
		glow_col = _enemy_skin.glow_color  # PORT: :1577-1578
	elif is_hazard:
		glow_col = Color(1.0, 170.0 / 255.0, 0.0, 0.45)
	else:
		glow_col = Color(1.0, 30.0 / 255.0, 60.0 / 255.0, 0.35)

	# Core vibrant body (PORT: EnemySwarm.ts:1588-1610)
	var body_col: Color
	var inner_col: Color
	if chilled:
		body_col = Color("#55bbff")
		inner_col = Color("#e0f8ff")
	elif _enemy_skin != null:
		body_col = _enemy_skin.body_gradient[1]  # PORT: :1594-1597
		inner_col = _enemy_skin.body_gradient[0]
	elif is_hazard:
		body_col = Color("#ffaa00")
		inner_col = Color("#fff066")
	else:
		body_col = Color("#ee1133")
		inner_col = Color("#ff6677")

	# Border (PORT: EnemySwarm.ts:1612-1620)
	var border_col: Color
	if chilled:
		border_col = Color("#aae6ff")
	elif _enemy_skin != null:
		border_col = _enemy_skin.border_color  # PORT: :1614-1615
	elif is_hazard:
		border_col = Color("#ffd555")
	else:
		border_col = Color("#ff8899")

	# Pupil / core dot (PORT: EnemySwarm.ts:1622-1632)
	var pupil_col: Color
	if chilled:
		pupil_col = Color("#002244")
	elif _enemy_skin != null:
		pupil_col = _enemy_skin.pupil_color  # PORT: :1625-1626
	elif is_hazard:
		pupil_col = Color("#221100")
	else:
		pupil_col = Color("#110005")
	return PackedColorArray([halo_col, glow_col, body_col, inner_col, border_col, pupil_col])


## DIVERGENCE(M11c P13): the two baked textures of one default-dot look, cached per
## radius and colour variant until the skin, halo toggle or model scale changes.
func _dot_sprites(radius: float, chilled: bool, is_hazard: bool) -> DotSprites:
	var variant: int = 2 if chilled else (1 if is_hazard else 0)
	var key: int = roundi(radius * DOT_KEY_STEPS) * 4 + variant
	var cached: DotSprites = _dot_cache.get(key)
	if cached != null:
		return cached
	var palette: PackedColorArray = _dot_palette(chilled, is_hazard)
	var s: float = _model_scale
	var sprites: DotSprites = DotSprites.new()
	# Outer: the halo ring (radius + 5, 1.2 px wide, only with the halo on), then the
	# glow disc (radius + 4). PORT: web/src/tilt-to-live/EnemySwarm.ts:1557-1586
	var outer_size: int = ceili(((radius + 5.0 + 0.6) * s + BAKE_MARGIN) * 2.0)
	var radii: PackedFloat32Array = PackedFloat32Array()
	var widths: PackedFloat32Array = PackedFloat32Array()
	var colors: PackedColorArray = PackedColorArray()
	if _high_contrast_halo:
		radii.append((radius + 5.0) * s)
		widths.append(1.2 * s)
		colors.append(palette[0])
	radii.append((radius + 4.0) * s)
	widths.append(0.0)
	colors.append(palette[1])
	sprites.outer = CircleSprites.bake_layers(outer_size, radii, widths, colors)
	sprites.outer_half = outer_size * 0.5
	# Inner: body, inner (0.65), border ring (1.2 px), pupil (0.38).
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:1588-1632
	var inner_size: int = ceili(((radius + 0.6) * s + BAKE_MARGIN) * 2.0)
	sprites.inner = CircleSprites.bake_layers(
		inner_size,
		PackedFloat32Array([radius * s, radius * 0.65 * s, radius * s, radius * 0.38 * s]),
		PackedFloat32Array([0.0, 0.0, 1.2 * s, 0.0]),
		PackedColorArray([palette[2], palette[3], palette[4], palette[5]])
	)
	sprites.inner_half = inner_size * 0.5
	_dot_cache[key] = sprites
	return sprites


## PORT-NOTE: Godot has no dash offset or dashed arc; this helper and
## _draw_dashed_arc below are the setLineDash equivalent, analogous to
## _closed(). Both walk the dash pattern in arc-length from a phase computed
## from line_dash_offset, matching Canvas2D's animated dash behaviour.
func _draw_dashed_line_offset(
	from: Vector2,
	to: Vector2,
	dash: float,
	gap: float,
	line_dash_offset: float,
	color: Color,
	width: float
) -> void:
	var delta: Vector2 = to - from
	var length: float = delta.length()
	if length <= 0.0:
		return
	var direction: Vector2 = delta / length
	var period: float = dash + gap
	var s: float = fposmod(-line_dash_offset, period) - period
	# DIVERGENCE(M11c P14): every dash goes into one draw_multiline call.
	var points: PackedVector2Array = PackedVector2Array()
	while s < length:
		var s0: float = maxf(s, 0.0)
		var s1: float = minf(s + dash, length)
		if s1 > s0:
			points.append(from + direction * s0)
			points.append(from + direction * s1)
		s += period
	if not points.is_empty():
		draw_multiline(points, color, width)


func _draw_dashed_arc(
	center: Vector2,
	radius: float,
	dash: float,
	gap: float,
	line_dash_offset: float,
	color: Color,
	width: float
) -> void:
	var length: float = TAU * radius
	if length <= 0.0:
		return
	var period: float = dash + gap
	var s: float = fposmod(-line_dash_offset, period) - period
	# DIVERGENCE(M11c P14): every dash's chords go into one draw_multiline call
	# (was one six-segment draw_arc per dash).
	var points: PackedVector2Array = PackedVector2Array()
	while s < length:
		var s0: float = maxf(s, 0.0)
		var s1: float = minf(s + dash, length)
		if s1 > s0:
			var a0: float = s0 / radius
			var step: float = (s1 - s0) / radius / DASH_ARC_CHORDS
			for c: int in range(DASH_ARC_CHORDS):
				var a: float = a0 + step * c
				points.append(center + Vector2(cos(a), sin(a)) * radius)
				points.append(center + Vector2(cos(a + step), sin(a + step)) * radius)
		s += period
	if not points.is_empty():
		draw_multiline(points, color, width)


## DIVERGENCE(M11c P14): a full circle outline from CircleSprites' shared ring
## texture when it is faithful at the drawn size, else draw_arc (the P5 rule).
func _ring(center: Vector2, radius: float, width: float, color: Color) -> void:
	if CircleSprites.ring_is_faithful(radius * _model_scale, width * _model_scale):
		CircleSprites.draw_ring(self, center, radius, width, color)
	else:
		draw_arc(center, radius, 0.0, TAU, RING_ARC_POINTS, color, width)


## PORT: web/src/tilt-to-live/PlayerShip.ts:271-632
func _draw_player() -> void:
	if _player == null or _player.is_dead:
		return

	# PORT: :274-293 — the classic fallback when no skin is supplied.
	var hull_color: Color = _ship_skin.hull_color if _ship_skin != null else HULL_COLOR
	var primary_color: Color = _ship_skin.primary_color if _ship_skin != null else PRIMARY_COLOR
	var accent_color: Color = _ship_skin.accent_color if _ship_skin != null else ACCENT_COLOR
	var thruster_color: Color = _ship_skin.thruster_color if _ship_skin != null else THRUSTER_COLOR
	var shape: ProgressionManager.ShipShape = (
		_ship_skin.shape if _ship_skin != null else ProgressionManager.ShipShape.CLASSIC
	)

	_draw_trail()

	# DIVERGENCE(M2.5 §6.1): draw_set_transform replaces rather than composes, so the
	# playfield origin must be re-applied here or the ship draws off its collision position.
	draw_set_transform(
		_arena_origin + Vector2(_player.x, _player.y),
		_player.angle,
		Vector2.ONE * _player.scale * _model_scale
	)

	if _player.has_shield():
		_draw_shield()

	# PORT: :356-357
	var stroke_col: Color = SHIELD_STROKE if _player.has_shield() else primary_color
	var core_col: Color = SHIELD_STROKE if _player.has_shield() else accent_color

	# PORT: :359-618
	match shape:
		ProgressionManager.ShipShape.VIPER:
			_draw_hull_viper(hull_color, primary_color, stroke_col, core_col)
		ProgressionManager.ShipShape.PHANTOM:
			_draw_hull_phantom(hull_color, accent_color, stroke_col, core_col)
		ProgressionManager.ShipShape.SOLAR:
			_draw_hull_solar(hull_color, primary_color, stroke_col, core_col)
		ProgressionManager.ShipShape.CYBER:
			_draw_hull_cyber(hull_color, primary_color, accent_color, stroke_col, core_col)
		ProgressionManager.ShipShape.SHURIKEN:
			_draw_hull_shuriken(hull_color, accent_color, stroke_col, core_col)
		ProgressionManager.ShipShape.CELESTIAL:
			_draw_hull_celestial(hull_color, primary_color, stroke_col, core_col)
		_:
			_draw_hull_classic(hull_color, stroke_col, core_col)

	# 3. Thruster flame plume. PORT: :620-629 (`skin.thrusterColor || skin.tint` —
	# every catalog entry sets thrusterColor, so tint is never read)
	var flame_col: Color = ACCENT_COLOR if _player.has_shield() else thruster_color
	var flame_len: float = 6.0 + randf() * 6.0
	var flame: PackedVector2Array = PackedVector2Array(
		[Vector2(-13.0, -3.5), Vector2(-13.0 - flame_len, 0.0), Vector2(-13.0, 3.5)]
	)
	draw_colored_polygon(flame, flame_col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## PORT: web/src/tilt-to-live/PlayerShip.ts:296-312
func _draw_trail() -> void:
	if _player.trail_history.size() <= 1:
		return
	var trail: Color = _ship_skin.trail_color if _ship_skin != null else TRAIL_COLOR
	for i: int in range(_player.trail_history.size() - 1):
		var pt1: Vector2 = _player.trail_history[i]
		var pt2: Vector2 = _player.trail_history[i + 1]
		var progress: float = 1.0 - float(i) / float(_player.trail_history.size())
		# :302-304 — the skin's trail colour with its alpha replaced by progress * 0.42
		var col: Color = (
			Color(0.0, 1.0, 220.0 / 255.0, progress * 0.45)
			if _player.has_shield()
			else Color(trail.r, trail.g, trail.b, progress * 0.42)
		)
		draw_line(pt1, pt2, col, progress * 5.5 * _player.scale)


## The main hull polygon of each shape, in ship space (prow at +x).
## PORT: web/src/tilt-to-live/PlayerShip.ts:371-381 (viper), :411-416 (phantom),
## :448-460 (solar), :496-503 (cyber), :526-533 (shuriken, curves sampled),
## :571-575 (celestial, curves sampled), :598-601 (classic)
static func hull_points_for(shape: ProgressionManager.ShipShape) -> PackedVector2Array:
	match shape:
		ProgressionManager.ShipShape.VIPER:
			return PackedVector2Array(
				[
					Vector2(18.0, 0.0),
					Vector2(2.0, -5.0),
					Vector2(-10.0, -14.0),
					Vector2(-13.0, -11.0),
					Vector2(-8.0, -4.0),
					Vector2(-14.0, -6.0),
					Vector2(-14.0, 6.0),
					Vector2(-8.0, 4.0),
					Vector2(-13.0, 11.0),
					Vector2(-10.0, 14.0),
					Vector2(2.0, 5.0),
				]
			)
		ProgressionManager.ShipShape.PHANTOM:
			return PackedVector2Array(
				[
					Vector2(17.0, 0.0),
					Vector2(2.0, -12.0),
					Vector2(-14.0, -9.0),
					Vector2(-6.0, 0.0),
					Vector2(-14.0, 9.0),
					Vector2(2.0, 12.0),
				]
			)
		ProgressionManager.ShipShape.SOLAR:
			return PackedVector2Array(
				[
					Vector2(16.0, -3.0),
					Vector2(16.0, 3.0),
					Vector2(4.0, 9.0),
					Vector2(-4.0, 9.0),
					Vector2(-12.0, 14.0),
					Vector2(-14.0, 12.0),
					Vector2(-10.0, 5.0),
					Vector2(-13.0, 0.0),
					Vector2(-10.0, -5.0),
					Vector2(-14.0, -12.0),
					Vector2(-12.0, -14.0),
					Vector2(-4.0, -9.0),
					Vector2(4.0, -9.0),
				]
			)
		ProgressionManager.ShipShape.CYBER:
			return PackedVector2Array(
				[
					Vector2(16.0, 0.0),
					Vector2(8.0, -6.0),
					Vector2(-8.0, -9.0),
					Vector2(-13.0, -5.0),
					Vector2(-8.0, 0.0),
					Vector2(-13.0, 5.0),
					Vector2(-8.0, 9.0),
					Vector2(8.0, 6.0),
				]
			)
		ProgressionManager.ShipShape.SHURIKEN:
			# :526-533 — four blades, each a lineTo tip then a quadraticCurveTo back in
			var pts: PackedVector2Array = PackedVector2Array([Vector2(17.0, 0.0)])
			pts.append_array(_quad(Vector2(17.0, 0.0), Vector2(8.0, 5.0), Vector2(2.0, 2.0)))
			pts.append(Vector2(0.0, 16.0))
			pts.append_array(_quad(Vector2(0.0, 16.0), Vector2(-5.0, 8.0), Vector2(-2.0, 2.0)))
			pts.append(Vector2(-15.0, 0.0))
			pts.append_array(_quad(Vector2(-15.0, 0.0), Vector2(-8.0, -5.0), Vector2(-2.0, -2.0)))
			pts.append(Vector2(0.0, -16.0))
			pts.append_array(_quad(Vector2(0.0, -16.0), Vector2(5.0, -8.0), Vector2(2.0, -2.0)))
			return pts
		ProgressionManager.ShipShape.CELESTIAL:
			# :571-575 — nose, two swept wings and a notch, all quadratic
			var pts: PackedVector2Array = PackedVector2Array([Vector2(18.0, 0.0)])
			pts.append_array(_quad(Vector2(18.0, 0.0), Vector2(4.0, -8.0), Vector2(-12.0, -12.0)))
			pts.append_array(_quad(Vector2(-12.0, -12.0), Vector2(-8.0, 0.0), Vector2(-6.0, 0.0)))
			pts.append_array(_quad(Vector2(-6.0, 0.0), Vector2(-8.0, 0.0), Vector2(-12.0, 12.0)))
			pts.append_array(_quad(Vector2(-12.0, 12.0), Vector2(4.0, 8.0), Vector2(18.0, 0.0)))
			return pts
		_:
			return PackedVector2Array(
				[Vector2(15.0, 0.0), Vector2(-12.0, -9.0), Vector2(-7.0, 0.0), Vector2(-12.0, 9.0)]
			)


## quadraticCurveTo sampled without its start point (the caller already has it).
static func _quad(p0: Vector2, control: Vector2, p1: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(1, 9):
		var t: float = float(i) / 8.0
		var q0: Vector2 = p0.lerp(control, t)
		var q1: Vector2 = control.lerp(p1, t)
		out.append(q0.lerp(q1, t))
	return out


## PORT: web/src/tilt-to-live/PlayerShip.ts:360-405
func _draw_hull_viper(hull_col: Color, primary: Color, stroke_col: Color, core_col: Color) -> void:
	# Twin canards (:362-366)
	draw_colored_polygon(
		PackedVector2Array([Vector2(4.0, -4.0), Vector2(1.0, -9.0), Vector2(-1.0, -4.0)]), primary
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(4.0, 4.0), Vector2(1.0, 9.0), Vector2(-1.0, 4.0)]), primary
	)
	# Forward-swept delta hull (:369-387)
	var hull: PackedVector2Array = hull_points_for(ProgressionManager.ShipShape.VIPER)
	draw_colored_polygon(hull, hull_col)
	draw_polyline(_closed(hull), stroke_col, 1.8)
	# Wingtip laser pods (:390-394)
	draw_circle(Vector2(-10.0, -14.0), 2.0, primary)
	draw_circle(Vector2(-10.0, 14.0), 2.0, primary)
	# Cockpit canopy (:397-404)
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(8.0, 0.0), Vector2(-2.0, -2.5), Vector2(-5.0, 0.0), Vector2(-2.0, 2.5)]
		),
		core_col
	)


## PORT: web/src/tilt-to-live/PlayerShip.ts:407-442
func _draw_hull_phantom(hull_col: Color, accent: Color, stroke_col: Color, core_col: Color) -> void:
	# Stealth diamond faceted voidcraft (:409-422)
	var hull: PackedVector2Array = hull_points_for(ProgressionManager.ShipShape.PHANTOM)
	draw_colored_polygon(hull, hull_col)
	draw_polyline(_closed(hull), stroke_col, 1.8)
	# Spine facet line (:425-430)
	draw_line(Vector2(17.0, 0.0), Vector2(-6.0, 0.0), accent, 1.0)
	# Central pulsing dark-matter crystal (:433-441)
	var p_pulse: float = 0.8 + 0.2 * sin(_elapsed * 10.0)
	draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(4.0, 0.0),
				Vector2(-2.0, -4.0 * p_pulse),
				Vector2(-6.0, 0.0),
				Vector2(-2.0, 4.0 * p_pulse),
			]
		),
		core_col
	)


## PORT: web/src/tilt-to-live/PlayerShip.ts:444-482
func _draw_hull_solar(hull_col: Color, primary: Color, stroke_col: Color, core_col: Color) -> void:
	# Heavy reinforced battlecruiser (:446-466)
	var hull: PackedVector2Array = hull_points_for(ProgressionManager.ShipShape.SOLAR)
	draw_colored_polygon(hull, hull_col)
	draw_polyline(_closed(hull), stroke_col, 2.0)
	# Armored shoulder insets (:469-471)
	draw_rect(Rect2(-2.0, -7.0, 4.0, 3.0), primary)
	draw_rect(Rect2(-2.0, 4.0, 4.0, 3.0), primary)
	# Bridge deck (:474-481)
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(6.0, 0.0), Vector2(-2.0, -2.5), Vector2(-4.0, 0.0), Vector2(-2.0, 2.5)]
		),
		core_col
	)


## PORT: web/src/tilt-to-live/PlayerShip.ts:484-520
func _draw_hull_cyber(
	hull_col: Color, primary: Color, accent: Color, stroke_col: Color, core_col: Color
) -> void:
	# Floating vector brackets (:486-491)
	draw_polyline(
		PackedVector2Array([Vector2(-2.0, -13.0), Vector2(-8.0, -15.0), Vector2(-12.0, -11.0)]),
		primary,
		1.6
	)
	draw_polyline(
		PackedVector2Array([Vector2(-2.0, 13.0), Vector2(-8.0, 15.0), Vector2(-12.0, 11.0)]),
		primary,
		1.6
	)
	# Cyber hull (:494-509)
	var hull: PackedVector2Array = hull_points_for(ProgressionManager.ShipShape.CYBER)
	draw_colored_polygon(hull, hull_col)
	draw_polyline(_closed(hull), stroke_col, 1.8)
	# Hex matrix core (:512-519)
	draw_rect(Rect2(-2.0, -3.0, 6.0, 6.0), accent, false, 1.2)
	draw_circle(Vector2(1.0, 0.0), 2.2, core_col)


## PORT: web/src/tilt-to-live/PlayerShip.ts:522-553
func _draw_hull_shuriken(
	hull_col: Color, accent: Color, stroke_col: Color, core_col: Color
) -> void:
	# Dynamic quad-blade ninja star (:524-539)
	var hull: PackedVector2Array = hull_points_for(ProgressionManager.ShipShape.SHURIKEN)
	draw_colored_polygon(hull, hull_col)
	draw_polyline(_closed(hull), stroke_col, 1.8)
	# Center spinning rune (:542-547) — ctx.rotate(elapsed * 6) on a 6x6 strokeRect
	var rune: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in [
		Vector2(-3.0, -3.0), Vector2(3.0, -3.0), Vector2(3.0, 3.0), Vector2(-3.0, 3.0)
	]:
		rune.append(corner.rotated(_elapsed * 6.0))
	draw_polyline(_closed(rune), accent, 1.2)
	draw_circle(Vector2.ZERO, 2.5, core_col)  # :549-552


## PORT: web/src/tilt-to-live/PlayerShip.ts:555-592
func _draw_hull_celestial(
	hull_col: Color, primary: Color, stroke_col: Color, core_col: Color
) -> void:
	# Floating celestial halo ring (:557-566): a dashed [6,3] ellipse (-7,0) rx 5 ry 14,
	# dash offset -elapsed*12, sampled as a polyline of 32 chords.
	# PORT-NOTE: chord count is a rasterisation choice; canvas ellipse() is analytic.
	var ring: PackedVector2Array = PackedVector2Array()
	for i: int in range(33):
		var a: float = TAU * float(i) / 32.0
		ring.append(Vector2(-7.0 + cos(a) * 5.0, sin(a) * 14.0))
	var offset: float = -_elapsed * 12.0
	for i: int in range(32):
		_draw_dashed_line_offset(ring[i], ring[i + 1], 6.0, 3.0, offset, primary, 1.6)
		offset -= ring[i].distance_to(ring[i + 1])
	# Sweeping divine hull (:569-581)
	var hull: PackedVector2Array = hull_points_for(ProgressionManager.ShipShape.CELESTIAL)
	draw_colored_polygon(hull, hull_col)
	draw_polyline(_closed(hull), stroke_col, 1.8)
	# Astral diode cockpit (:584-591)
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(6.0, 0.0), Vector2(-1.0, -3.0), Vector2(-3.0, 0.0), Vector2(-1.0, 3.0)]
		),
		core_col
	)


## PORT: web/src/tilt-to-live/PlayerShip.ts:594-617
func _draw_hull_classic(hull_col: Color, stroke_col: Color, core_col: Color) -> void:
	var hull: PackedVector2Array = hull_points_for(ProgressionManager.ShipShape.CLASSIC)
	draw_colored_polygon(hull, hull_col)
	draw_polyline(_closed(hull), stroke_col, 1.8)
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(5.0, 0.0), Vector2(-4.0, -3.0), Vector2(-2.0, 0.0), Vector2(-4.0, 3.0)]
		),
		core_col
	)


## PORT: web/src/tilt-to-live/PlayerShip.ts:319-353
func _draw_shield() -> void:
	var shield_radius: float = _player.shield_radius
	var pulse: float = 0.75 + sin(_elapsed * 8.0) * 0.25

	# PORT-NOTE: 64 segments is a rasterisation choice; the canvas arc()
	# PlayerShip.ts:328 draws a mathematically smooth circle.
	draw_arc(
		Vector2.ZERO,
		shield_radius,
		0.0,
		PI * 2.0,
		64,
		Color(0.0, 1.0, 200.0 / 255.0, pulse * 0.8),
		2.5
	)
	draw_circle(Vector2.ZERO, shield_radius, Color(0.0, 1.0, 220.0 / 255.0, 0.15))

	var hex: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var a: float = (i * PI) / 3.0 + _elapsed * 2.0
		hex.append(Vector2(cos(a) * (shield_radius - 2.0), sin(a) * (shield_radius - 2.0)))
	draw_polyline(_closed(hex), Color(180.0 / 255.0, 1.0, 240.0 / 255.0, pulse * 0.5), 1.0)


## PORT-NOTE: draw_polyline does not close its own loop; this is the
## ctx.closePath() equivalent used by the hull outline and shield hex facets.
func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = points.duplicate()
	out.append(points[0])
	return out
