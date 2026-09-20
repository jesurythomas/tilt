## grid_layer.gd
## PORTS: web/src/tilt-to-live/VectorGrid.ts:86-117 (render) and
## web/src/tilt-to-live/TiltRenderer.ts:59-127 (arena background, grid tint,
## perimeter), per spec §4.2 and D4
class_name GridLayer
extends Node2D
## Bottom render layer: arena background, the reactive grid, the perimeter.
##
## PORT-NOTE: TiltRenderer.ts:97 draws the grid only when showGridlines is on,
## and GameOptions.ts:88 defaults it to false. M1 has no settings system and
## its acceptance criterion requires an observable grid, so it draws
## unconditionally.
## TODO(M7): gate this on GameOptions.showGridlines.
##
## PORT-NOTE: TiltRenderer.ts:82-92 builds a canvas radial gradient with an
## inner radius of width*0.1 and an outer radius of width*0.8, stops at 0,
## 0.65 and 1. GradientTexture2D has no inner radius, so the 0.65 stop is
## re-expressed against the 0..width*0.8 span this texture actually covers:
## (0.1 + 0.65 * 0.7) / 0.8 = 0.69375. The 0.1/0.8 = 0.125 inner stop is
## unaffected. The painted result is identical.

## PORT: web/src/tilt-to-live/TiltRenderer.ts:60 (classic arena background)
const BG_INNER: Color = Color("#100c1e")
const BG_MID: Color = Color("#090712")
const BG_OUTER: Color = Color("#040308")
## PORT: web/src/tilt-to-live/TiltRenderer.ts:61
## PORT-NOTE: VectorGrid.ts:88's default 'rgba(0, 220, 255, 0.09)' is never
## used in practice: TiltRenderer.ts:98 always passes an explicit gridColor
## (this one, or the code-red/gauntlet/arenaTheme overrides at :64-80, none of
## which exist yet in M1).
const GRID_COLOR: Color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.28)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:62
const BOUNDARY_COLOR: Color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.45)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:125 (the 0.12-alpha outer stroke)
const BOUNDARY_HALO_ALPHA: float = 0.12
const GRADIENT_OUTER_FACTOR: float = 0.8  # PORT: web/src/tilt-to-live/TiltRenderer.ts:88
const INSET: float = 6.0  # PORT: web/src/tilt-to-live/TiltRenderer.ts:123

## The reactive grid drawn every frame. Null until bind() is called.
var _grid: VectorGrid = null
## Pre-baked radial gradient standing in for TiltRenderer.ts's canvas gradient.
var _background: GradientTexture2D = null
# DIVERGENCE(M2.5 §6.1): the playfield is inset from the viewport, so every
# draw call in playfield-local coordinates is translated by this.
var _arena_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	_background = _build_background()


func _draw() -> void:
	if _grid == null:
		return
	var viewport: Vector2 = get_viewport_rect().size
	# DIVERGENCE(M2.5 §6.1): the background still covers the whole viewport so
	# the inset reads as a frame rather than black bars; the grid and the
	# perimeter are drawn in playfield space.
	var size: Vector2 = viewport - _arena_origin * 2.0

	draw_rect(Rect2(Vector2.ZERO, viewport), BG_OUTER)
	if _background != null:
		# PORT-NOTE: this block expresses the canvas gradient's centre and
		# radius as a Rect2/UV mapping onto the pre-baked texture built in
		# _build_background() — size / 2.0 (centre), Vector2(radius, radius)
		# and radius * 2.0 (destination rect), fill_from/fill_to (0.5,0.5) and
		# (1.0,0.5) (radial UV axis) are geometry, not tunable game values.
		var radius: float = viewport.x * GRADIENT_OUTER_FACTOR
		var centre: Vector2 = viewport / 2.0
		draw_texture_rect(
			_background,
			Rect2(centre - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)),
			false
		)

	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)
	_draw_grid()

	# PORT: web/src/tilt-to-live/TiltRenderer.ts:120-127
	var frame: Rect2 = Rect2(INSET, INSET, size.x - INSET * 2.0, size.y - INSET * 2.0)
	draw_rect(frame, BOUNDARY_COLOR, false, 2.5)
	var halo: Color = BOUNDARY_COLOR
	halo.a = BOUNDARY_HALO_ALPHA
	draw_rect(frame, halo, false, 8.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# TODO(M10): code-red and gauntlet background, grid tint and overlays
	# (TiltRenderer.ts:64-74, 101-118).
	# TODO(M7): arena theme override (TiltRenderer.ts:76-80).


## Gives this layer the grid it draws. Called by GameRoot.
func bind(grid: VectorGrid) -> void:
	_grid = grid


## Sets the playfield's top-left corner in viewport space. Called by GameRoot.
func set_arena_origin(origin: Vector2) -> void:
	_arena_origin = origin


## PORT: web/src/tilt-to-live/VectorGrid.ts:86-117
func _draw_grid() -> void:
	for r: int in range(_grid.rows):
		var row: PackedVector2Array = PackedVector2Array()
		var row_offset: int = r * _grid.cols
		for c: int in range(_grid.cols):
			var p: VectorGrid.GridPoint = _grid.points[row_offset + c]
			row.append(Vector2(p.x, p.y))
		if row.size() > 1:
			draw_polyline(row, GRID_COLOR, 1.0)

	for c: int in range(_grid.cols):
		var col: PackedVector2Array = PackedVector2Array()
		for r: int in range(_grid.rows):
			var p: VectorGrid.GridPoint = _grid.points[r * _grid.cols + c]
			col.append(Vector2(p.x, p.y))
		if col.size() > 1:
			draw_polyline(col, GRID_COLOR, 1.0)


func _build_background() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.125, 0.69375, 1.0])
	gradient.colors = PackedColorArray([BG_INNER, BG_INNER, BG_MID, BG_OUTER])

	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	# PORT-NOTE: rasterisation size of the gradient texture; the canvas
	# gradient TiltRenderer.ts:82-92 ports is computed analytically and has no
	# equivalent resolution parameter.
	texture.width = 256
	texture.height = 256
	return texture
