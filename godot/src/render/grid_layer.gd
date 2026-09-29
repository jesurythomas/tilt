## grid_layer.gd
## PORTS: web/src/tilt-to-live/VectorGrid.ts:86-117 (render) and
## web/src/tilt-to-live/TiltRenderer.ts:59-127 (arena background, grid tint,
## perimeter), per spec §4.2 and D4
class_name GridLayer
extends Node2D
## Bottom render layer: arena background, the reactive grid, the perimeter.
##
## PORT-NOTE: TiltRenderer.ts:97 draws the grid only when showGridlines is on;
## GameOptions.ts:88 defaults it to false, the port to true (M11c review ruling).
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
## DIVERGENCE(THEME R2): the height the background effects are drawn for (the A55's).
const PATTERN_UNIT_HEIGHT: float = 1080.0
## Vignette radii as width fractions. PORT: web/src/tilt-to-live/TiltRenderer.ts:104
const VIGNETTE_INNER: float = 0.35
const VIGNETTE_OUTER: float = 0.75
## Rasterisation size of the baked vignette.
const VIGNETTE_TEXTURE_SIZE: float = 256.0
## DIVERGENCE(M11c review): the per-pixel background (radial gradient + dither).
const BACKGROUND_SHADER: Shader = preload("res://src/render/arena_background.gdshader")
## DIVERGENCE(M11c review): on by default again (user ruling 2026-09-27, "re-add the
## grid"); GameRoot sets it from GameOptionsManager.settings.show_gridlines.
var show_gridlines: bool = true
## DIVERGENCE(M11c review): false while the menu shows — its right column covers half
## the arena, so the perimeter framed only the left half of the screen.
var show_perimeter: bool = true
## DIVERGENCE(M11c review, verification 2026-09-27): true while the menu shows — the
## grid is drawn from the screen origin so it fills the screen; drawn from the arena
## inset it left a plain band at the left and top that read as an edge around half
## the screen.
var grid_fills_viewport: bool = false

## The reactive grid. Null until bind() is called.
var _grid: VectorGrid = null
## DIVERGENCE(M11c review): the layer draws through three children, in this order:
## the background (a shader; redrawn only when its inputs change), the grid lines
## (drawn white and tinted by modulate; redrawn only when the lattice moves), and the
## frame (mode overlay + perimeter; redrawn every refresh()).
var _bg_node: Node2D = null
var _lines_node: Node2D = null
var _frame_node: Node2D = null
var _bg_material: ShaderMaterial = null
## What the background and lines last drew with, to skip unchanged redraws.
var _bg_key: Array = []
var _lines_key: Array = []
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


## DIVERGENCE(M11c review): one of the layer's child canvases; it calls back into the
## layer to draw.
class Part:
	extends Node2D
	var draw_fn: Callable

	func _draw() -> void:
		draw_fn.call(self)


func _ready() -> void:
	_vignette = _build_vignette()
	_bg_material = ShaderMaterial.new()
	_bg_material.shader = BACKGROUND_SHADER
	_bg_node = _add_part("GridBackground", _draw_background)
	_bg_node.material = _bg_material
	_lines_node = _add_part("GridLines", _draw_grid)
	_frame_node = _add_part("GridFrame", _draw_frame)
	_update_background_uniforms()


func _add_part(part_name: String, draw_fn: Callable) -> Node2D:
	var part: Part = Part.new()
	part.name = part_name
	part.draw_fn = draw_fn
	add_child(part)
	return part


## Redraws what changed; GameRoot calls it once per rendered frame (was queue_redraw).
func refresh() -> void:
	if _grid == null or _frame_node == null:
		return
	var pt_draw: int = PerfProbe.now()
	var viewport: Vector2 = get_viewport_rect().size
	var bg_key: Array = [viewport, background_colors(), _arena_theme]
	if bg_key != _bg_key:
		_bg_key = bg_key
		_update_background_uniforms()
		_bg_node.queue_redraw()
	_lines_node.visible = show_gridlines
	if show_gridlines:
		# PORT: web/src/tilt-to-live/VectorGrid.ts:109 (strokeStyle = gridColor), as modulate
		_lines_node.modulate = grid_color()
		var lines_key: Array = [
			_grid.revision, _arena_origin, _grid.cols, _grid.rows, grid_fills_viewport
		]
		if lines_key != _lines_key:
			_lines_key = lines_key
			_lines_node.queue_redraw()
	_frame_node.queue_redraw()
	PerfProbe.add("d_grid", pt_draw)


## The radial gradient's inputs for the background shader.
## PORT: web/src/tilt-to-live/TiltRenderer.ts:82-92
func _update_background_uniforms() -> void:
	if _bg_material == null:
		return
	var viewport: Vector2 = get_viewport_rect().size
	var stops: Array[Color] = background_colors()
	_bg_material.set_shader_parameter("inner_color", stops[0])
	_bg_material.set_shader_parameter("mid_color", stops[1])
	_bg_material.set_shader_parameter("outer_color", stops[2])
	_bg_material.set_shader_parameter("centre", viewport / 2.0)
	_bg_material.set_shader_parameter("radius", viewport.x * GRADIENT_OUTER_FACTOR)
	# DIVERGENCE(THEME R2): the theme's effect; none without a theme (menu, tests).
	var themed: bool = _arena_theme != null
	var pattern: int = int(_arena_theme.pattern) if themed else 0
	_bg_material.set_shader_parameter("pattern", pattern)
	_bg_material.set_shader_parameter("unit", viewport.y / PATTERN_UNIT_HEIGHT)
	if themed:
		_bg_material.set_shader_parameter("accent", _arena_theme.dust_color)
		_bg_material.set_shader_parameter("accent2", _arena_theme.boundary_color)


# DIVERGENCE(M2.5 §6.1): the background still covers the whole viewport so the inset
# reads as a frame rather than black bars; the grid and perimeter draw in playfield space.
func _draw_background(part: Node2D) -> void:
	part.draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.WHITE)


## Mode overlay and perimeter. PORT: web/src/tilt-to-live/TiltRenderer.ts:101-127
func _draw_frame(part: Node2D) -> void:
	var size: Vector2 = get_viewport_rect().size - _arena_origin * 2.0
	part.draw_set_transform(_arena_origin, 0.0, Vector2.ONE)
	_draw_mode_overlay(part, size)
	if show_perimeter:
		# PORT: web/src/tilt-to-live/TiltRenderer.ts:120-127
		var frame: Rect2 = Rect2(INSET, INSET, size.x - INSET * 2.0, size.y - INSET * 2.0)
		var boundary: Color = boundary_color()
		part.draw_rect(frame, boundary, false, 2.5)
		var halo: Color = boundary
		halo.a = BOUNDARY_HALO_ALPHA
		part.draw_rect(frame, halo, false, 8.0)
	part.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Gives this layer the grid it draws. Called by GameRoot.
func bind(grid: VectorGrid) -> void:
	_grid = grid


## Sets the playfield's top-left corner in viewport space. Called by GameRoot.
func set_arena_origin(origin: Vector2) -> void:
	_arena_origin = origin


## Sets the arena theme (the background follows on the next refresh()).
## PORT: web/src/tilt-to-live/TiltGame.ts:2312
func set_arena_theme(theme_config: ProgressionManager.ArenaThemeConfig) -> void:
	_arena_theme = theme_config


func get_arena_theme() -> ProgressionManager.ArenaThemeConfig:
	return _arena_theme


## Sets the run's mode (the background follows on the next refresh()).
func set_game_mode(mode: Types.GameMode) -> void:
	_game_mode = mode


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


## The grid lines' canvas item, for GameRoot's arena clip (M11c review).
func lines_canvas_item() -> RID:
	return _lines_node.get_canvas_item() if _lines_node != null else RID()


## The background shader's material (test-visible).
func background_material() -> ShaderMaterial:
	return _bg_material


## PORT: web/src/tilt-to-live/VectorGrid.ts:86-117
# DIVERGENCE(M11c review): drawn in white (the Lines node's modulate carries the grid
# colour) and only when the lattice moved (see refresh()).
func _draw_grid(part: Node2D) -> void:
	if _grid == null:
		return
	var origin: Vector2 = Vector2.ZERO if grid_fills_viewport else _arena_origin
	part.draw_set_transform(origin, 0.0, Vector2.ONE)
	for r: int in range(_grid.rows):
		var row: PackedVector2Array = PackedVector2Array()
		var row_offset: int = r * _grid.cols
		for c: int in range(_grid.cols):
			row.append(Vector2(_grid.px[row_offset + c], _grid.py[row_offset + c]))
		if row.size() > 1:
			part.draw_polyline(row, Color.WHITE, 1.0)

	for c: int in range(_grid.cols):
		var col: PackedVector2Array = PackedVector2Array()
		for r: int in range(_grid.rows):
			col.append(Vector2(_grid.px[r * _grid.cols + c], _grid.py[r * _grid.cols + c]))
		if col.size() > 1:
			part.draw_polyline(col, Color.WHITE, 1.0)
	part.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Mode-specific atmosphere, in playfield space. PORT: web/src/tilt-to-live/TiltRenderer.ts:101-118
func _draw_mode_overlay(part: Node2D, size: Vector2) -> void:
	if _game_mode == Types.GameMode.CODE_RED:
		# PORT: web/src/tilt-to-live/TiltRenderer.ts:103-107
		var alpha: float = 0.10 * alert_pulse(_elapsed)
		# PORT-NOTE: the canvas gradient spans radius width*0.75 and the canvas
		# clips it to the arena; the baked texture maps onto that radius's
		# square and only the playfield's part of it is drawn.
		var tex_side: float = size.x * VIGNETTE_OUTER * 2.0
		var texel: float = VIGNETTE_TEXTURE_SIZE / tex_side
		var source: Rect2 = Rect2((Vector2(tex_side, tex_side) - size) / 2.0 * texel, size * texel)
		part.draw_texture_rect_region(
			_vignette, Rect2(Vector2.ZERO, size), source, Color(1.0, 1.0, 1.0, alpha)
		)
	elif _game_mode == Types.GameMode.GAUNTLET:
		# Industrial hazard corner brackets. PORT: web/src/tilt-to-live/TiltRenderer.ts:110-117
		var s: float = 28.0  # PORT: web/src/tilt-to-live/TiltRenderer.ts:113
		var edge: float = 10.0  # PORT: web/src/tilt-to-live/TiltRenderer.ts:114-117
		var width: float = 2.5  # PORT: web/src/tilt-to-live/TiltRenderer.ts:112
		part.draw_rect(Rect2(edge, edge, s, s), GAUNTLET_BRACKET, false, width)
		part.draw_rect(Rect2(size.x - edge - s, edge, s, s), GAUNTLET_BRACKET, false, width)
		part.draw_rect(Rect2(edge, size.y - edge - s, s, s), GAUNTLET_BRACKET, false, width)
		part.draw_rect(
			Rect2(size.x - edge - s, size.y - edge - s, s, s), GAUNTLET_BRACKET, false, width
		)


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
