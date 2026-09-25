## grid_layer.gd
## PORTS: web/src/tilt-to-live/VectorGrid.ts:86-117 (render) and
## web/src/tilt-to-live/TiltRenderer.ts:59-127 (arena background, grid tint,
## perimeter), per spec §4.2 and D4
class_name GridLayer
extends Node2D
## Bottom render layer: arena background, the reactive grid, the perimeter.
##
## PORT-NOTE: TiltRenderer.ts:97 draws the grid only when showGridlines is on,
## and GameOptions.ts:88 defaults it to false.
## GameRoot sets show_gridlines from GameOptionsManager.settings.show_gridlines (M7).
##
## PORT-NOTE: TiltRenderer.ts:82-92 builds a canvas radial gradient with an
## inner radius of width*0.1 and an outer radius of width*0.8, stops at 0,
## 0.65 and 1. GradientTexture2D has no inner radius, so the 0.65 stop is
## re-expressed against the 0..width*0.8 span this texture actually covers:
## (0.1 + 0.65 * 0.7) / 0.8 = 0.69375. The 0.1/0.8 = 0.125 inner stop is
## unaffected. The painted result is identical.
##
## PORT-NOTE: TiltRenderer.ts:64-74's code-red and gauntlet background, grid and
## boundary colours are dead in the TS: getEquippedArenaTheme() always returns a
## config (ProgressionManager.ts:786-788), so :76-80 always overrides them. They
## are ported (the theme wins, as there) and show only with no theme bound
## (M10 R6). The overlays (:101-118) are what a mode actually looks like.

## PORT: web/src/tilt-to-live/TiltRenderer.ts:60 (classic arena background)
const BG_INNER: Color = Color("#100c1e")
const BG_MID: Color = Color("#090712")
const BG_OUTER: Color = Color("#040308")
## PORT: web/src/tilt-to-live/TiltRenderer.ts:61
const GRID_COLOR: Color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.28)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:62
const BOUNDARY_COLOR: Color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.45)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:125 (the 0.12-alpha outer stroke)
const BOUNDARY_HALO_ALPHA: float = 0.12
const GRADIENT_OUTER_FACTOR: float = 0.8  # PORT: web/src/tilt-to-live/TiltRenderer.ts:88
const INSET: float = 6.0  # PORT: web/src/tilt-to-live/TiltRenderer.ts:123
## PORT: web/src/tilt-to-live/TiltRenderer.ts:67 (code-red background)
const CODE_RED_BG_INNER: Color = Color("#180e28")
const CODE_RED_BG_MID: Color = Color("#0c0716")
const CODE_RED_BG_OUTER: Color = Color("#05030a")
## The plasma rgb every code-red tint uses.
## PORT: web/src/tilt-to-live/TiltRenderer.ts:68-69, :105-106
const PLASMA: Color = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:71 (gauntlet background)
const GAUNTLET_BG_INNER: Color = Color("#221403")
const GAUNTLET_BG_MID: Color = Color("#110a01")
const GAUNTLET_BG_OUTER: Color = Color("#060301")
## PORT: web/src/tilt-to-live/TiltRenderer.ts:72
const GAUNTLET_GRID: Color = Color(1.0, 170.0 / 255.0, 0.0, 0.35)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:73
const GAUNTLET_BOUNDARY: Color = Color(1.0, 180.0 / 255.0, 0.0, 0.75)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:111
const GAUNTLET_BRACKET: Color = Color(1.0, 190.0 / 255.0, 0.0, 0.7)
## Vignette radii as width fractions. PORT: web/src/tilt-to-live/TiltRenderer.ts:104
const VIGNETTE_INNER: float = 0.35
const VIGNETTE_OUTER: float = 0.75
## Rasterisation size of the baked vignette (see _build_background's note).
const VIGNETTE_TEXTURE_SIZE: float = 256.0
# DIVERGENCE(M2.5 §10): hide gridlines per user request and GameOptions.ts:88 default
# (showGridlines = false) to eliminate per-frame dynamic polyline allocations on mobile.
var show_gridlines: bool = false

## The reactive grid drawn every frame. Null until bind() is called.
var _grid: VectorGrid = null
## Pre-baked radial gradient standing in for TiltRenderer.ts's canvas gradient.
var _background: GradientTexture2D = null
# DIVERGENCE(M2.5 §6.1): the playfield is inset from the viewport, so every
# draw call in playfield-local coordinates is translated by this.
var _arena_origin: Vector2 = Vector2.ZERO
## The equipped arena theme; null keeps TiltRenderer.ts:60-62's defaults.
var _arena_theme: ProgressionManager.ArenaThemeConfig = null
## The run's mode. PORT: web/src/tilt-to-live/TiltGame.ts:2315 (gameMode into the renderer)
var _game_mode: Types.GameMode = Types.GameMode.CLASSIC
## Run clock driving the code-red pulse. PORT: web/src/tilt-to-live/TiltRenderer.ts:65
var _elapsed: float = 0.0
## Baked plasma vignette, tinted per frame by its pulsing alpha.
var _vignette: GradientTexture2D = null


func _ready() -> void:
	_background = _build_background()
	_vignette = _build_vignette()


func _draw() -> void:
	if _grid == null:
		return
	var pt_draw: int = PerfProbe.now()
	var viewport: Vector2 = get_viewport_rect().size
	# DIVERGENCE(M2.5 §6.1): the background still covers the whole viewport so
	# the inset reads as a frame rather than black bars; the grid and the
	# perimeter are drawn in playfield space.
	var size: Vector2 = viewport - _arena_origin * 2.0

	draw_rect(Rect2(Vector2.ZERO, viewport), background_colors()[2])
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
	if show_gridlines:
		_draw_grid()

	_draw_mode_overlay(size)

	# PORT: web/src/tilt-to-live/TiltRenderer.ts:120-127
	var frame: Rect2 = Rect2(INSET, INSET, size.x - INSET * 2.0, size.y - INSET * 2.0)
	var boundary: Color = boundary_color()
	draw_rect(frame, boundary, false, 2.5)
	var halo: Color = boundary
	halo.a = BOUNDARY_HALO_ALPHA
	draw_rect(frame, halo, false, 8.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	PerfProbe.add("d_grid", pt_draw)


## Gives this layer the grid it draws. Called by GameRoot.
func bind(grid: VectorGrid) -> void:
	_grid = grid


## Sets the playfield's top-left corner in viewport space. Called by GameRoot.
func set_arena_origin(origin: Vector2) -> void:
	_arena_origin = origin


## Sets the arena theme and rebakes the background. PORT: web/src/tilt-to-live/TiltGame.ts:2312
func set_arena_theme(theme_config: ProgressionManager.ArenaThemeConfig) -> void:
	_arena_theme = theme_config
	_background = _build_background()


func get_arena_theme() -> ProgressionManager.ArenaThemeConfig:
	return _arena_theme


## Sets the run's mode; rebakes the background when it changes.
func set_game_mode(mode: Types.GameMode) -> void:
	if mode == _game_mode:
		return
	_game_mode = mode
	_background = _build_background()


func get_game_mode() -> Types.GameMode:
	return _game_mode


## Run clock, for the code-red pulse.
func set_elapsed(elapsed: float) -> void:
	_elapsed = elapsed


## 0.5 + 0.5 sin(4t). PORT: web/src/tilt-to-live/TiltRenderer.ts:65, :103
static func alert_pulse(elapsed: float) -> float:
	return 0.5 + 0.5 * sin(elapsed * 4.0)


## The three background stops. PORT: web/src/tilt-to-live/TiltRenderer.ts:60-80
func background_colors() -> Array[Color]:
	if _arena_theme != null:
		return _arena_theme.bg_gradient
	match _game_mode:
		Types.GameMode.CODE_RED:
			return [CODE_RED_BG_INNER, CODE_RED_BG_MID, CODE_RED_BG_OUTER]
		Types.GameMode.GAUNTLET:
			return [GAUNTLET_BG_INNER, GAUNTLET_BG_MID, GAUNTLET_BG_OUTER]
	return [BG_INNER, BG_MID, BG_OUTER]


## PORT: web/src/tilt-to-live/TiltRenderer.ts:61, :68, :72, :78
func grid_color() -> Color:
	if _arena_theme != null:
		return _arena_theme.grid_color
	match _game_mode:
		Types.GameMode.CODE_RED:
			# PORT: web/src/tilt-to-live/TiltRenderer.ts:68
			return Color(PLASMA, 0.28 + 0.08 * alert_pulse(_elapsed))
		Types.GameMode.GAUNTLET:
			return GAUNTLET_GRID
	return GRID_COLOR


## PORT: web/src/tilt-to-live/TiltRenderer.ts:62, :69, :73, :79
func boundary_color() -> Color:
	if _arena_theme != null:
		return _arena_theme.boundary_color
	match _game_mode:
		Types.GameMode.CODE_RED:
			# PORT: web/src/tilt-to-live/TiltRenderer.ts:69
			return Color(PLASMA, 0.55 + 0.2 * alert_pulse(_elapsed))
		Types.GameMode.GAUNTLET:
			return GAUNTLET_BOUNDARY
	return BOUNDARY_COLOR


## The baked radial gradient (test-visible).
func background_texture() -> GradientTexture2D:
	return _background


## PORT: web/src/tilt-to-live/VectorGrid.ts:86-117
func _draw_grid() -> void:
	for r: int in range(_grid.rows):
		var row: PackedVector2Array = PackedVector2Array()
		var row_offset: int = r * _grid.cols
		for c: int in range(_grid.cols):
			row.append(Vector2(_grid.px[row_offset + c], _grid.py[row_offset + c]))
		if row.size() > 1:
			draw_polyline(row, grid_color(), 1.0)

	for c: int in range(_grid.cols):
		var col: PackedVector2Array = PackedVector2Array()
		for r: int in range(_grid.rows):
			col.append(Vector2(_grid.px[r * _grid.cols + c], _grid.py[r * _grid.cols + c]))
		if col.size() > 1:
			draw_polyline(col, grid_color(), 1.0)


## Mode-specific atmosphere, in playfield space. PORT: web/src/tilt-to-live/TiltRenderer.ts:101-118
func _draw_mode_overlay(size: Vector2) -> void:
	if _game_mode == Types.GameMode.CODE_RED:
		# PORT: web/src/tilt-to-live/TiltRenderer.ts:103-107
		var alpha: float = 0.10 * alert_pulse(_elapsed)
		# PORT-NOTE: the canvas gradient spans radius width*0.75 and the canvas
		# clips it to the arena; the baked texture maps onto that radius's
		# square and only the playfield's part of it is drawn.
		var tex_side: float = size.x * VIGNETTE_OUTER * 2.0
		var texel: float = VIGNETTE_TEXTURE_SIZE / tex_side
		var source: Rect2 = Rect2((Vector2(tex_side, tex_side) - size) / 2.0 * texel, size * texel)
		draw_texture_rect_region(
			_vignette, Rect2(Vector2.ZERO, size), source, Color(1.0, 1.0, 1.0, alpha)
		)
	elif _game_mode == Types.GameMode.GAUNTLET:
		# Industrial hazard corner brackets. PORT: web/src/tilt-to-live/TiltRenderer.ts:110-117
		var s: float = 28.0  # PORT: web/src/tilt-to-live/TiltRenderer.ts:113
		var edge: float = 10.0  # PORT: web/src/tilt-to-live/TiltRenderer.ts:114-117
		var width: float = 2.5  # PORT: web/src/tilt-to-live/TiltRenderer.ts:112
		draw_rect(Rect2(edge, edge, s, s), GAUNTLET_BRACKET, false, width)
		draw_rect(Rect2(size.x - edge - s, edge, s, s), GAUNTLET_BRACKET, false, width)
		draw_rect(Rect2(edge, size.y - edge - s, s, s), GAUNTLET_BRACKET, false, width)
		draw_rect(Rect2(size.x - edge - s, size.y - edge - s, s, s), GAUNTLET_BRACKET, false, width)


## The code-red vignette: transparent plasma to the inner radius, full plasma at
## the outer; drawn tinted by alpha. PORT: web/src/tilt-to-live/TiltRenderer.ts:104-106
func _build_vignette() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, VIGNETTE_INNER / VIGNETTE_OUTER, 1.0])
	var clear: Color = Color(PLASMA, 0.0)
	gradient.colors = PackedColorArray([clear, clear, Color(PLASMA, 1.0)])

	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = int(VIGNETTE_TEXTURE_SIZE)
	texture.height = int(VIGNETTE_TEXTURE_SIZE)
	return texture


func _build_background() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.125, 0.69375, 1.0])
	var stops: Array[Color] = background_colors()
	gradient.colors = PackedColorArray([stops[0], stops[0], stops[1], stops[2]])

	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	# PORT-NOTE: rasterisation size of the gradient texture; the canvas
	# gradient TiltRenderer.ts:82-92 ports is computed analytically and has no
	# equivalent resolution parameter.
	texture.width = int(VIGNETTE_TEXTURE_SIZE)
	texture.height = int(VIGNETTE_TEXTURE_SIZE)
	return texture
