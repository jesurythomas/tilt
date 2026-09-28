## arena_preview.gd
## PORTS: nothing — new file.
## DIVERGENCE(ARMORY R7, user 2026-09-28: "on the right hand side - show what it looks like
## in the arena"; "make it also the same for ships"): a still of the arena as the browsed
## Armory items would look in a run — the theme's radial background (the run's own
## shader), grid and edge, a scatter of dots in the enemy skin, and the ship. Drawn once
## per change, not every frame.
class_name ArenaPreview
extends Control

const BACKGROUND_SHADER: Shader = preload("res://src/render/arena_background.gdshader")
## Where the dots sit, as fractions of the preview (x, y) and their size (1 = large).
const DOTS: Array[Vector3] = [
	Vector3(0.16, 0.22, 1.0),
	Vector3(0.28, 0.72, 0.7),
	Vector3(0.44, 0.18, 0.7),
	Vector3(0.72, 0.26, 1.0),
	Vector3(0.84, 0.58, 0.7),
	Vector3(0.66, 0.8, 1.0),
	Vector3(0.12, 0.52, 0.7),
	Vector3(0.9, 0.16, 0.7),
	Vector3(0.36, 0.44, 1.0),
]
## The ship's spot, as fractions of the preview.
const SHIP_AT: Vector2 = Vector2(0.56, 0.52)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:88 (grid_layer.gd GRADIENT_OUTER_FACTOR)
const GRADIENT_OUTER_FACTOR: float = 0.8
## PORT: web/src/tilt-to-live/TiltRenderer.ts:120-127 (grid_layer.gd INSET, halo 0.12)
const EDGE_INSET: float = 6.0
const EDGE_WIDTH: float = 2.5
const HALO_WIDTH: float = 8.0
const HALO_ALPHA: float = 0.12

var grid_color: Color = Color.WHITE
var boundary_color: Color = Color.WHITE
var grid_step: float = 24.0
var edge_scale: float = 1.0
var dot_large: Texture2D = null
var dot_small: Texture2D = null
var ship: Texture2D = null
## The ship's size in px (its texture may be oversampled).
var ship_size: float = 48.0

var _background: ColorRect = null
var _material: ShaderMaterial = null


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = BACKGROUND_SHADER
	_background = ColorRect.new()
	_background.name = "Background"
	_background.material = _material
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.show_behind_parent = true
	add_child(_background)
	resized.connect(_on_resized)


## The theme's three background stops. PORT: web/src/tilt-to-live/TiltRenderer.ts:82-92
func set_background(stops: Array[Color]) -> void:
	_material.set_shader_parameter("inner_color", stops[0])
	_material.set_shader_parameter("mid_color", stops[1])
	_material.set_shader_parameter("outer_color", stops[2])
	queue_redraw()


func _on_resized() -> void:
	_background.size = size
	_material.set_shader_parameter("centre", size / 2.0)
	_material.set_shader_parameter("radius", maxf(1.0, size.x * GRADIENT_OUTER_FACTOR))
	queue_redraw()


func _draw() -> void:
	if grid_step > 1.0:
		var x: float = grid_step
		while x < size.x:
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), grid_color, 1.0)
			x += grid_step
		var y: float = grid_step
		while y < size.y:
			draw_line(Vector2(0.0, y), Vector2(size.x, y), grid_color, 1.0)
			y += grid_step
	var inset: float = EDGE_INSET * edge_scale
	var frame: Rect2 = Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	var halo: Color = boundary_color
	halo.a = HALO_ALPHA
	draw_rect(frame, halo, false, HALO_WIDTH * edge_scale)
	draw_rect(frame, boundary_color, false, EDGE_WIDTH * edge_scale)
	for d: Vector3 in DOTS:
		var tex: Texture2D = dot_large if d.z >= 1.0 else dot_small
		if tex != null:
			var at: Vector2 = Vector2(d.x, d.y) * size - tex.get_size() * 0.5
			draw_texture(tex, at)
	if ship != null:
		var half: Vector2 = Vector2(ship_size, ship_size) * 0.5
		draw_texture_rect(ship, Rect2(SHIP_AT * size - half, half * 2.0), false)
