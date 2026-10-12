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

## DIVERGENCE(ENH-301): the soft glow's falloff, white alpha at each offset from the centre.
const GLOW_OFFSETS: PackedFloat32Array = [0.0, 0.4, 1.0]
const GLOW_ALPHAS: PackedFloat32Array = [1.0, 0.55, 0.0]

static var _disc: GradientTexture2D = null
static var _glow: GradientTexture2D = null
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


## DIVERGENCE(ENH-301): a soft glow fading from color at the centre to clear at radius.
static func draw_glow(ci: CanvasItem, centre: Vector2, radius: float, color: Color) -> void:
	if _glow == null:
		_glow = _radial(GLOW_OFFSETS, GLOW_ALPHAS)
	var half: Vector2 = Vector2(radius, radius)
	ci.draw_texture_rect(_glow, Rect2(centre - half, half * 2.0), false, color)


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


## DIVERGENCE(M11c P13): one texture holding concentric layers composited in order,
## so an entity drawn as several circles costs one draw call. Texels are screen
## pixels: layer i is a disc of radii[i] px (widths[i] == 0.0) or a ring centred on
## radii[i] px, widths[i] px wide, filled with colors[i]. The texture is size x size
## with the circles' centre in its middle; draw it at exactly that size.
static func bake_layers(
	size: int, radii: PackedFloat32Array, widths: PackedFloat32Array, colors: PackedColorArray
) -> ImageTexture:
	return ImageTexture.create_from_image(bake_layers_image(size, radii, widths, colors))


## bake_layers' image, before it becomes a texture (M11c N5 packs two into an atlas).
static func bake_layers_image(
	size: int, radii: PackedFloat32Array, widths: PackedFloat32Array, colors: PackedColorArray
) -> Image:
	var canvas: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for i: int in range(radii.size()):
		var layer: Image = _layer_image(size, radii[i], widths[i], colors[i])
		canvas.blend_rect(layer, Rect2i(0, 0, size, size), Vector2i.ZERO)
	return canvas


## One anti-aliased disc or ring as a size x size image (see bake_layers).
static func _layer_image(size: int, radius: float, width: float, color: Color) -> Image:
	# GradientTexture2D maps pixel x to x / (size - 1), so one gradient unit is
	# (size - 1) / 2 pixels (measured 2026-09-27).
	var unit: float = maxf((size - 1) * 0.5, 1.0)
	var offsets: PackedFloat32Array
	var alphas: PackedFloat32Array
	if width <= 0.0:
		offsets = PackedFloat32Array([0.0, radius - 0.5, radius + 0.5])
		alphas = PackedFloat32Array([1.0, 1.0, 0.0])
	elif width < 1.0:
		# A sub-pixel stroke covers at most `width` of a pixel.
		offsets = PackedFloat32Array([radius - 0.5, radius, radius + 0.5])
		alphas = PackedFloat32Array([0.0, width, 0.0])
	else:
		var inner: float = radius - width * 0.5
		var outer: float = radius + width * 0.5
		offsets = PackedFloat32Array([inner - 0.5, inner + 0.5, outer - 0.5, outer + 0.5])
		alphas = PackedFloat32Array([0.0, 1.0, 1.0, 0.0])
	var colors: PackedColorArray = PackedColorArray()
	for i: int in range(offsets.size()):
		offsets[i] = clampf(offsets[i] / unit, 0.0, 1.0)
		colors.append(Color(color.r, color.g, color.b, color.a * alphas[i]))
	var g: Gradient = Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var img: Image = tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
