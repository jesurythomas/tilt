## enemy_textures.gd
## PORTS: nothing — new file.
## DIVERGENCE(SKIN R1, user 2026-09-28: "instead of just base enemy colors changing, add
## textures to the enemies for unlocks"): each unlockable enemy skin paints a pattern
## over the default dot's body, under its border and pupil — baked once per dot size
## into the dot sprite (EntityLayer._dot_sprites), so it costs nothing per frame. The
## Classic skin (and no skin, the menu) keeps the TS's plain body.
class_name EnemyTextures
extends RefCounted

## Skins with a pattern, in catalog order. PORT-NOTE: ids from
## web/src/tilt-to-live/ProgressionManager.ts:280-341.
## DIVERGENCE(THEME R1, user 2026-09-29): the last ten are the concept and country-colour
## skins, painted from four shared shapes (rays, rings, stripes, dots).
const TEXTURED: Array[String] = [
	"toxic",
	"glitch",
	"magma",
	"void",
	"gold",
	"arctic",
	"ember",
	"neon",
	"ocean",
	"desert",
	"ph",
	"jp",
	"br",
	"us",
	"de",
]


## True when `skin_id` paints a pattern.
static func has_texture(skin_id: String) -> bool:
	return TEXTURED.has(skin_id)


## The pattern for `skin_id` as an SVG of size×size px, for a dot of radius `r` px
## centred in it; "" for a plain skin. Colours come from the skin's own palette.
static func svg(skin_id: String, size: int, r: float) -> String:
	var body: String = _pattern(skin_id, size * 0.5, r)
	if body == "":
		return ""
	return (
		(
			"<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 %d %d'>"
			% [size, size, size, size]
		)
		+ body
		+ "</svg>"
	)


## The pattern rasterised to a size×size image (null for a plain skin).
static func image(skin_id: String, size: int, r: float) -> Image:
	var source: String = svg(skin_id, size, r)
	if source == "":
		return null
	var img: Image = Image.new()
	if img.load_svg_from_string(source, 1.0) != OK:
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## One default dot — body, inner disc, pattern, border ring, pupil — baked as an image of
## size×size px with radius r px. `colors` is [body, inner, border, pupil]; `ring` the
## border's width in px. EntityLayer._dot_sprites and the Armory preview share it.
static func dot_image(
	size: int, r: float, colors: PackedColorArray, ring: float, skin_id: String
) -> Image:
	var base: Image = CircleSprites.bake_layers_image(
		size,
		PackedFloat32Array([r, r * 0.65]),
		PackedFloat32Array([0.0, 0.0]),
		PackedColorArray([colors[0], colors[1]])
	)
	var pattern: Image = image(skin_id, size, r)
	if pattern != null:
		# The body disc masks the pattern (a pixel with any body coverage takes it).
		var mask: Image = CircleSprites.bake_layers_image(
			size, PackedFloat32Array([r]), PackedFloat32Array([0.0]), PackedColorArray([colors[0]])
		)
		base.blend_rect_mask(pattern, mask, Rect2i(0, 0, size, size), Vector2i.ZERO)
	var top: Image = CircleSprites.bake_layers_image(
		size,
		PackedFloat32Array([r, r * 0.38]),
		PackedFloat32Array([ring, 0.0]),
		PackedColorArray([colors[2], colors[3]])
	)
	base.blend_rect(top, Rect2i(0, 0, size, size), Vector2i.ZERO)
	return base


## A point at (u, v) dot radii from the centre, as "x,y".
static func _pt(c: float, r: float, u: float, v: float) -> String:
	return "%.2f,%.2f" % [c + u * r, c + v * r]


static func _pattern(skin_id: String, c: float, r: float) -> String:
	match skin_id:
		"toxic":
			return _toxic(c, r)
		"glitch":
			return _glitch(c, r)
		"magma":
			return _magma(c, r)
		"void":
			return _void(c, r)
		"gold":
			return _gold(c, r)
		# DIVERGENCE(THEME R1): the concept skins, then the country-colour skins.
		"arctic":
			return _rays(c, r, 6, "#ffffff", 0.85)
		"ember":
			return _dots(
				c,
				r,
				[
					Vector3(-0.5, -0.4, 0.14),
					Vector3(0.45, -0.55, 0.1),
					Vector3(0.55, 0.3, 0.16),
					Vector3(-0.3, 0.55, 0.12),
					Vector3(0.0, 0.05, 0.09),
					Vector3(-0.72, 0.2, 0.08),
				],
				"#1a1412",
				0.7
			)
		"neon":
			return _petals(c, r, "#ffe6f2")
		"ocean":
			return _dots(
				c,
				r,
				[
					Vector3(-0.5, -0.3, 0.1),
					Vector3(0.4, -0.5, 0.13),
					Vector3(0.5, 0.35, 0.09),
					Vector3(-0.2, 0.6, 0.12),
					Vector3(-0.72, 0.25, 0.07),
					Vector3(0.1, 0.0, 0.16),
				],
				"#b6ff5c",
				0.85
			)
		"desert":
			return _stripes(c, r, 20.0, 5, "#6b3f12", 0.45)
		"ph":
			return _rays(c, r, 8, "#fcd116", 0.9)
		"jp":
			return _rings(c, r, "#ffffff", 0.85)
		"br":
			return _stripes(c, r, 45.0, 4, "#ffdf00", 0.8)
		"us":
			return _stripes(c, r, 0.0, 4, "#ffffff", 0.85)
		"de":
			return _stripes(c, r, 90.0, 4, "#ffce00", 0.85)
	return ""


## Toxic Biohazard — "bubbling caustic cores": pale bubbles with dark rims.
static func _toxic(c: float, r: float) -> String:
	var out: String = ""
	for b: Vector3 in [
		Vector3(-0.55, -0.35, 0.2),
		Vector3(0.48, -0.52, 0.16),
		Vector3(0.6, 0.3, 0.22),
		Vector3(-0.28, 0.62, 0.17),
		Vector3(0.08, -0.78, 0.11),
		Vector3(-0.78, 0.18, 0.12),
	]:
		out += (
			(
				"<circle cx='%.2f' cy='%.2f' r='%.2f' fill='#ccffd5' fill-opacity='0.7' "
				% [c + b.x * r, c + b.y * r, b.z * r]
			)
			+ "stroke='#005518' stroke-opacity='0.8' stroke-width='%.2f'/>" % maxf(0.8, r * 0.06)
		)
	return out


## Cyber Glitch — cyan and magenta scan bands knocked sideways, over dark scanlines.
static func _glitch(c: float, r: float) -> String:
	var out: String = ""
	var line: float = maxf(0.8, r * 0.07)
	var y: float = -0.9
	while y < 0.95:
		out += (
			"<rect x='%.2f' y='%.2f' width='%.2f' height='%.2f' fill='#002255' fill-opacity='0.55'/>"
			% [c - r, c + y * r, r * 2.0, line]
		)
		y += 0.24
	for band: Array in [
		[-0.62, 0.16, -0.25, "#88ffff"], [-0.12, 0.13, 0.3, "#ff0077"], [0.4, 0.15, -0.1, "#88ffff"]
	]:
		out += (
			"<rect x='%.2f' y='%.2f' width='%.2f' height='%.2f' fill='%s' fill-opacity='0.85'/>"
			% [c + (band[2] - 0.7) * r, c + band[0] * r, r * 1.4, band[1] * r, band[3]]
		)
	return out


## Molten Magma — "ember cores encased in cracked obsidian rock": a dark crust with
## glowing cracks running in from the rim.
static func _magma(c: float, r: float) -> String:
	var crust: String = (
		(
			"<circle cx='%.2f' cy='%.2f' r='%.2f' fill='none' stroke='#1c0500' stroke-opacity='0.8' "
			% [c, c, r * 0.82]
		)
		+ "stroke-width='%.2f'/>" % (r * 0.36)
	)
	var cracks: String = ""
	var width: float = maxf(0.9, r * 0.09)
	for crack: PackedVector2Array in [
		PackedVector2Array([Vector2(0.0, -1.0), Vector2(0.1, -0.78), Vector2(-0.05, -0.6)]),
		PackedVector2Array([Vector2(0.92, 0.38), Vector2(0.7, 0.3), Vector2(0.58, 0.42)]),
		PackedVector2Array([Vector2(-0.7, 0.72), Vector2(-0.52, 0.52), Vector2(-0.58, 0.38)]),
		PackedVector2Array([Vector2(-0.95, -0.3), Vector2(-0.72, -0.22), Vector2(-0.6, -0.34)]),
		PackedVector2Array([Vector2(0.55, -0.83), Vector2(0.46, -0.62)]),
	]:
		var pts: PackedStringArray = PackedStringArray()
		for p: Vector2 in crack:
			pts.append(_pt(c, r, p.x, p.y))
		cracks += (
			(
				"<polyline points='%s' fill='none' stroke='#ffcc00' stroke-width='%.2f' "
				% [" ".join(pts), width]
			)
			+ "stroke-linecap='round' stroke-linejoin='round'/>"
		)
	return crust + cracks


## Abyssal Void — a violet swirl spiralling into the dark core.
static func _void(c: float, r: float) -> String:
	var out: String = ""
	var width: float = maxf(0.9, r * 0.1)
	for arm: int in range(3):
		var a0: float = TAU * arm / 3.0
		var pts: PackedStringArray = PackedStringArray()
		for step: int in range(9):
			var t: float = step / 8.0
			var a: float = a0 + t * 2.2
			var rad: float = 0.92 - t * 0.5
			pts.append(_pt(c, r, cos(a) * rad, sin(a) * rad))
		out += (
			(
				"<polyline points='%s' fill='none' stroke='#cc88ff' stroke-opacity='0.85' "
				% " ".join(pts)
			)
			+ "stroke-width='%.2f' stroke-linecap='round' stroke-linejoin='round'/>" % width
		)
	return out


## Midas Gold — "polished metallic ... with radiant star gleams": a darker lower rim,
## a white gleam and a four-point sparkle.
static func _gold(c: float, r: float) -> String:
	var shade: String = (
		"<path d='M%s A%.2f %.2f 0 0 0 %s A%.2f %.2f 0 0 1 %s Z' fill='#aa7700' fill-opacity='0.6'/>"
		% [_pt(c, r, -1.0, 0.0), r, r, _pt(c, r, 1.0, 0.0), r * 1.0, r * 0.55, _pt(c, r, -1.0, 0.0)]
	)
	var gleam: String = (
		(
			"<ellipse cx='%.2f' cy='%.2f' rx='%.2f' ry='%.2f' fill='#ffffff' fill-opacity='0.8' "
			% [c - 0.38 * r, c - 0.42 * r, 0.3 * r, 0.15 * r]
		)
		+ "transform='rotate(-35 %.2f %.2f)'/>" % [c - 0.38 * r, c - 0.42 * r]
	)
	var sx: float = 0.5
	var sy: float = -0.5
	var arm: float = 0.3
	var waist: float = 0.07
	var star: String = (
		"<polygon points='%s %s %s %s %s %s %s %s' fill='#ffffff'/>"
		% [
			_pt(c, r, sx, sy - arm),
			_pt(c, r, sx + waist, sy - waist),
			_pt(c, r, sx + arm, sy),
			_pt(c, r, sx + waist, sy + waist),
			_pt(c, r, sx, sy + arm),
			_pt(c, r, sx - waist, sy + waist),
			_pt(c, r, sx - arm, sy),
			_pt(c, r, sx - waist, sy - waist),
		]
	)
	return shade + gleam + star


## `count` spokes from the eye out to the rim.
static func _rays(c: float, r: float, count: int, color: String, opacity: float) -> String:
	var out: String = ""
	for i: int in range(count):
		var dir: Vector2 = Vector2.from_angle(TAU * i / count)
		var from: Vector2 = dir * 0.3 * r
		var to: Vector2 = dir * r
		out += (
			(
				"<line x1='%.2f' y1='%.2f' x2='%.2f' y2='%.2f' "
				% [c + from.x, c + from.y, c + to.x, c + to.y]
			)
			+ (
				"stroke='%s' stroke-opacity='%.2f' stroke-width='%.2f' stroke-linecap='round'/>"
				% [color, opacity, maxf(0.9, r * 0.09)]
			)
		)
	return out


## Concentric rings around the eye.
static func _rings(c: float, r: float, color: String, opacity: float) -> String:
	var out: String = ""
	for radius: float in [0.5, 0.78]:
		out += (
			(
				"<circle cx='%.2f' cy='%.2f' r='%.2f' fill='none' stroke='%s' stroke-opacity='%.2f' "
				% [c, c, r * radius, color, opacity]
			)
			+ "stroke-width='%.2f'/>" % maxf(0.9, r * 0.1)
		)
	return out


## `count` bands across the dot, turned `degrees`.
static func _stripes(
	c: float, r: float, degrees: float, count: int, color: String, opacity: float
) -> String:
	var out: String = "<g transform='rotate(%.1f %.2f %.2f)'>" % [degrees, c, c]
	var band: float = r * 2.0 / (count * 2.0)
	for i: int in range(count):
		out += (
			"<rect x='%.2f' y='%.2f' width='%.2f' height='%.2f' fill='%s' fill-opacity='%.2f'/>"
			% [c - r, c - r + band * (2 * i + 0.5), r * 2.0, band, color, opacity]
		)
	return out + "</g>"


## Filled dots at (u, v) dot radii with radius w dot radii.
static func _dots(
	c: float, r: float, dots: Array[Vector3], color: String, opacity: float
) -> String:
	var out: String = ""
	for d: Vector3 in dots:
		out += (
			"<circle cx='%.2f' cy='%.2f' r='%.2f' fill='%s' fill-opacity='%.2f'/>"
			% [c + d.x * r, c + d.y * r, d.z * r, color, opacity]
		)
	return out


## Five blossoms in a ring around the eye.
static func _petals(c: float, r: float, color: String) -> String:
	var dots: Array[Vector3] = []
	for i: int in range(5):
		var a: float = TAU * i / 5.0 - PI * 0.5
		dots.append(Vector3(cos(a) * 0.55, sin(a) * 0.55, 0.2))
	return _dots(c, r, dots, color, 0.8)
