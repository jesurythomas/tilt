## circle_sprites.gd
## DIVERGENCE(M11c P5): no TS counterpart. Canvas 2D arcs are cheap in a browser;
## Godot's draw_circle/draw_arc re-tessellate on the CPU at ~30x the cost of a
## draw_rect (measured 2026-09-26: ~7.5 us per call on the desktop, several times
## that on the A55). The hot paths (enemy dots, particles) draw these shared white
## textures instead, tinted by the same colours, in the same layer order.
class_name CircleSprites
extends RefCounted

## DIVERGENCE(M11c P5): texture edge length in texels.
const TEX_SIZE: int = 64
## DIVERGENCE(M11c P5): ring textures are shared per 0.02 of stroke-width / radius.
const RATIO_STEP: float = 0.02
## DIVERGENCE(M11c P5): stroke ratios above 2 (a stroke wider than the diameter) clamp.
const MAX_RATIO: float = 2.0
## One texel of the texture half-size, the anti-aliasing band.
const AA: float = 2.0 / TEX_SIZE
## The disc's half-alpha edge, as a fraction of the texture half-size.
const DISC_EDGE: float = 1.0 - AA * 1.5

static var _disc: GradientTexture2D = null
static var _rings: Dictionary[int, GradientTexture2D] = {}


## White disc: opaque to DISC_EDGE, fading over one texel.
static func disc() -> Texture2D:
	if _disc == null:
		_disc = _radial(
			PackedFloat32Array([0.0, DISC_EDGE - AA * 0.5, DISC_EDGE + AA * 0.5]),
			PackedFloat32Array([1.0, 1.0, 0.0])
		)
	return _disc


## Rect that draws disc() with its edge on radius around centre.
static func disc_rect(centre: Vector2, radius: float) -> Rect2:
	var half: float = radius / DISC_EDGE
	return Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)


## Draws a filled circle like CanvasItem.draw_circle(centre, radius, color).
static func draw_disc(ci: CanvasItem, centre: Vector2, radius: float, color: Color) -> void:
	ci.draw_texture_rect(disc(), disc_rect(centre, radius), false, color)


## Quantised stroke-width / radius ratio.
static func ring_key(radius: float, width: float) -> int:
	var ratio: float = clampf(width / maxf(radius, 0.001), RATIO_STEP, MAX_RATIO)
	return roundi(ratio / RATIO_STEP)


## The ring's centre line as a fraction of the texture half-size.
static func ring_centre(key: int) -> float:
	var ratio: float = key * RATIO_STEP
	return (1.0 - AA * 2.0) / (1.0 + ratio * 0.5)


## White ring for one ratio step, memoised.
static func ring(key: int) -> Texture2D:
	if _rings.has(key):
		return _rings[key]
	var c: float = ring_centre(key)
	var hw: float = key * RATIO_STEP * c * 0.5
	var inner: float = c - hw
	var outer: float = c + hw
	var offsets: PackedFloat32Array
	var alphas: PackedFloat32Array
	if inner - AA * 0.5 <= 0.0:
		offsets = PackedFloat32Array([0.0, outer - AA * 0.5, outer + AA * 0.5])
		alphas = PackedFloat32Array([1.0, 1.0, 0.0])
	else:
		offsets = PackedFloat32Array(
			[inner - AA * 0.5, inner + AA * 0.5, outer - AA * 0.5, outer + AA * 0.5]
		)
		alphas = PackedFloat32Array([0.0, 1.0, 1.0, 0.0])
	var tex: GradientTexture2D = _radial(offsets, alphas)
	_rings[key] = tex
	return tex


## True when ring(key) reproduces draw_arc at this size: one texel spans at most a
## screen pixel (in the caller's local space) and the stroke ratio is not clamped.
## DIVERGENCE(M11c P5, final review): large thin rings (the kill shockwave) blur
## past this, so callers fall back to draw_arc for them.
static func ring_is_faithful(radius: float, width: float) -> bool:
	if radius <= 0.0 or width / radius < RATIO_STEP:
		return false
	var key: int = ring_key(radius, width)
	var texel_px: float = (radius / ring_centre(key)) / (TEX_SIZE * 0.5)
	return texel_px <= 1.0


## Rect that draws ring(key) with its centre line on radius around centre.
static func ring_rect(centre: Vector2, radius: float, key: int) -> Rect2:
	var half: float = radius / ring_centre(key)
	return Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)


## Draws a full circle outline like draw_arc(centre, radius, 0, TAU, n, color, width).
static func draw_ring(
	ci: CanvasItem, centre: Vector2, radius: float, width: float, color: Color
) -> void:
	var key: int = ring_key(radius, width)
	ci.draw_texture_rect(ring(key), ring_rect(centre, radius, key), false, color)


static func _radial(offsets: PackedFloat32Array, alphas: PackedFloat32Array) -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	var colors: PackedColorArray = PackedColorArray()
	for a: float in alphas:
		colors.append(Color(1.0, 1.0, 1.0, a))
	g.offsets = offsets
	g.colors = colors
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.width = TEX_SIZE
	tex.height = TEX_SIZE
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
