## weapon_icons.gd
## DIVERGENCE(ICONS R1): no TS counterpart. One icon set for the Armory, the HUD weapon
## timer and the playfield orbs (user 2026-09-28: "update the look of the icons for the
## upgrades and the icons of the powerups in the game itself. they look really bad"); plan
## docs/superpowers/plans/2026-09-28-armory-economy-icons.md. Each glyph is a white
## silhouette on a 24-unit grid with one stroke weight; callers tint it (modulate).
class_name WeaponIcons
extends RefCounted

## Glyph grid, in SVG units.
const VIEW: float = 24.0
## Orb sprite grid, in SVG units.
const ORB_VIEW: float = 64.0
## Stroke attributes shared by the line glyphs.
const LINE: String = (
	'fill="none" stroke="#fff" stroke-width="2.4" '
	+ 'stroke-linecap="round" stroke-linejoin="round"'
)
const LINE_THIN: String = (
	'fill="none" stroke="#fff" stroke-width="1.7" '
	+ 'stroke-linecap="round" stroke-linejoin="round"'
)

## Glyph bodies by key: the Armory's weapon ids, then its boost ids.
const GLYPHS: Dictionary[String, String] = {
	# Radiation trefoil.
	"nuke":
	(
		'<circle cx="12" cy="12" r="2.5" fill="#fff"/><path fill="#fff" d="M6.9 3.17A10.2'
		+ " 10.2 0 0 1 17.1 3.17L14.15 8.28A4.3 4.3 0 0 0 9.85 8.28ZM22.2 12A10.2 10.2 0 0 1"
		+ " 17.1 20.83L14.15 15.72A4.3 4.3 0 0 0 16.3 12ZM6.9 20.83A10.2 10.2 0 0 1 1.8 12L7.7"
		+ ' 12A4.3 4.3 0 0 0 9.85 15.72Z"/>'
	),
	# Rocket flying up-right, with a window, fins and a flame.
	"missiles":
	(
		'<g transform="rotate(45 12 12)"><path fill="#fff" fill-rule="evenodd" d="M12 2.3C14.9'
		+ " 4.4 15.6 7 15.6 9.6V16.2H8.4V9.6C8.4 7 9.1 4.4 12 2.3ZM13.6 9.4A1.6 1.6 0 1 0 10.4"
		+ ' 9.4A1.6 1.6 0 1 0 13.6 9.4Z"/><path fill="#fff" d="M8.4 11.4L5.2 16.2V18.8L8.4'
		+ ' 16.8ZM15.6 11.4L18.8 16.2V18.8L15.6 16.8ZM9.9 17.4H14.1L12 22.2Z"/></g>'
	),
	# Bolt.
	"lightning": '<path fill="#fff" d="M13.8 1.6L4.4 13.7H11L9.3 22.4L19.6 9.5H12.9Z"/>',
	# The sweeping beam: a hub, two beams and motion arcs.
	"laser":
	(
		'<circle cx="12" cy="12" r="3.4" fill="#fff"/><path fill="none" stroke="#fff" '
		+ 'stroke-width="3" stroke-linecap="round" '
		+ 'd="M15.54 8.46L19.64 4.36M8.46 15.54L4.36 19.64"/><path '
		+ LINE_THIN
		+ ' d="M19.92 14.12A8.2 8.2 0 0 1 14.12 19.92M4.08 9.88A8.2 8.2 0 0 1 9.88 4.08"/>'
	),
	# Core and three spiral arms.
	"blackhole":
	(
		'<circle cx="12" cy="12" r="3.4" fill="#fff"/><path '
		+ LINE
		+ ' d="M17.4 12Q19.35 18.17 9.46 21.47M9.3 16.68Q2.98 15.28 5.07 5.07M9.3 7.32Q13.67'
		+ ' 2.55 21.47 9.46"/>'
	),
	# Six-armed snowflake.
	"freeze":
	(
		'<path stroke-width="2.2" fill="none" stroke="#fff" stroke-linecap="round" d="M12'
		+ " 12L12 2.4M12 6L9.7 4.07M12 6L14.3 4.07M12 12L20.31 7.2M17.2 9L17.72 6.05M17.2 9L20.02"
		+ " 10.03M12 12L20.31 16.8M17.2 15L20.02 13.97M17.2 15L17.72 17.95M12 12L12 21.6M12 18L14.3"
		+ " 19.93M12 18L9.7 19.93M12 12L3.69 16.8M6.8 15L6.28 17.95M6.8 15L3.98 13.97M12 12L3.69"
		+ ' 7.2M6.8 9L3.98 10.03M6.8 9L6.28 6.05"/><circle cx="12" cy="12" r="2.1" fill="#fff"/>'
	),
	# Heater shield: a rim and a half-filled field.
	"shield":
	(
		'<path fill="#fff" fill-rule="evenodd" d="M12 2.2L20.4 5.4V11.6C20.4 16.6 16.9 20.2 12'
		+ " 22C7.1 20.2 3.6 16.6 3.6 11.6V5.4ZM12 4.7L18.1 7V11.6C18.1 15.3 15.6 18.1 12 19.6C8.4"
		+ ' 18.1 5.9 15.3 5.9 11.6V7Z"/><path fill="#fff" d="M12 7.3V17.1C9.7 16 8.1 14.1 8.1'
		+ ' 11.7V8.8Z"/>'
	),
	# Heart.
	"extraLives":
	(
		'<path fill="#fff" d="M12 20.8C5.4 15.8 2.8 12.4 2.8 8.9C2.8 6 5 3.8 7.8 3.8C9.6 3.8'
		+ " 11 4.8 12 6.4C13 4.8 14.4 3.8 16.2 3.8C19 3.8 21.2 6 21.2 8.9C21.2 12.4 18.6 15.8"
		+ ' 12 20.8Z"/>'
	),
	# The ship inside closing corner brackets.
	"hullCompact":
	(
		'<path fill="#fff" d="M17.6 12L7.4 6.1L9.9 12L7.4 17.9Z"/><path '
		+ LINE
		+ ' d="M3 8V3H8M16 3H21V8M21 16V21H16M8 21H3V16"/>'
	),
	# Hourglass.
	"enemySlow":
	(
		'<path fill="#fff" d="M5.4 2.4H18.6V4.7H17.2V6.1C17.2 8.9 15 10.6 13.6 12C15 13.4 17.2'
		+ " 15.1 17.2 17.9V19.3H18.6V21.6H5.4V19.3H6.8V17.9C6.8 15.1 9 13.4 10.4 12C9 10.6 6.8"
		+ ' 8.9 6.8 6.1V4.7H5.4Z"/>'
	),
	# Five-point star.
	"scoreMultiplier":
	(
		'<path fill="#fff" d="M12 2.6L14.53 9.32L21.7 9.65L16.09 14.13L18 21.05L12 17.1L6'
		+ ' 21.05L7.91 14.13L2.3 9.65L9.47 9.32Z"/>'
	),
	# Cut gem.
	"pointsMultiplier":
	(
		'<path fill="#fff" fill-rule="evenodd" d="M7.2 3.4H16.8L21.3 9.2L12 21.2L2.7'
		+ ' 9.2ZM5.8 10L12 17.8L18.2 10Z"/>'
	),
}

## The power-up each Armory weapon id stands for (the Armory calls VORTEX "blackhole").
const WEAPON_KEYS: Dictionary[Types.WeaponType, String] = {
	Types.WeaponType.NUKE: "nuke",
	Types.WeaponType.MISSILES: "missiles",
	Types.WeaponType.LIGHTNING: "lightning",
	Types.WeaponType.LASER: "laser",
	Types.WeaponType.VORTEX: "blackhole",
	Types.WeaponType.FREEZE: "freeze",
	Types.WeaponType.SHIELD: "shield",
}

## Disc behind an orb's glyph.
const ORB_CORE: Color = Color(0.05, 0.03, 0.09)

static var _cache: Dictionary[String, Texture2D] = {}


## A glyph as a standalone white SVG document, `size` units square.
static func svg(key: String, size: float = VIEW) -> String:
	return (
		'<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 24 24">%s</svg>'
		% [size, size, GLYPHS.get(key, "")]
	)


## The white glyph rasterised at px × px, memoised.
static func texture(key: String, px: int) -> Texture2D:
	var cache_key: String = "g:%s:%d" % [key, px]
	if not _cache.has(cache_key):
		_cache[cache_key] = _raster(svg(key, float(px)))
	return _cache[cache_key]


## The glyph key for a power-up.
static func weapon_key(type: Types.WeaponType) -> String:
	return WEAPON_KEYS.get(type, "")


## The power-up (a Types.WeaponType) for an Armory weapon id; Types.ABSENT for none.
static func weapon_type(key: String) -> int:
	for type: Types.WeaponType in WEAPON_KEYS:
		if WEAPON_KEYS[type] == key:
			return type
	return Types.ABSENT


## One colour per weapon everywhere: the playfield orb colour
## (PORT: web/src/tilt-to-live/WeaponSystem.ts:600-610, WeaponSystem.get_weapon_color).
static func color_of(type: Types.WeaponType) -> Color:
	return WeaponSystem.get_weapon_color(type)


## The weapon colour lifted for text and glyphs on the dark UI (the TS vortex #8822ff and
## laser #cc22ff read dim on #141821): mixed a third of the way to white.
static func ui_color_of(type: Types.WeaponType) -> Color:
	return color_of(type).lerp(Color.WHITE, 0.3)


## The orb sprite as SVG: a dark core lit in the weapon colour, a white rim and the
## white glyph at ~60% of the diameter.
static func orb_svg(type: Types.WeaponType, size: float) -> String:
	var c: String = "#" + color_of(type).to_html(false)
	var core: String = "#" + ORB_CORE.to_html(false)
	return (
		(
			'<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 64 64">'
			+ '<defs><radialGradient id="g" cx="0.5" cy="0.42" r="0.58">'
			+ '<stop offset="0" stop-color="%s" stop-opacity="0.85"/>'
			+ '<stop offset="0.7" stop-color="%s" stop-opacity="0.95"/>'
			+ '<stop offset="1" stop-color="%s"/></radialGradient></defs>'
			+ '<circle cx="32" cy="32" r="28.5" fill="url(#g)"/>'
			+ '<circle cx="32" cy="32" r="28.5" fill="none" stroke="%s" stroke-width="3.5"/>'
			+ '<circle cx="32" cy="32" r="30.2" fill="none" stroke="#fff" stroke-width="1.6"'
			+ ' stroke-opacity="0.85"/>'
			+ '<g transform="translate(13 13) scale(1.583)">%s</g></svg>'
		)
		% [size, size, c, core, core, c, GLYPHS.get(weapon_key(type), "")]
	)


## The orb sprite rasterised at px × px, memoised.
static func orb_texture(type: Types.WeaponType, px: int) -> Texture2D:
	var cache_key: String = "o:%d:%d" % [type, px]
	if not _cache.has(cache_key):
		_cache[cache_key] = _raster(orb_svg(type, float(px)))
	return _cache[cache_key]


static func _raster(doc: String) -> Texture2D:
	var img: Image = Image.new()
	img.load_svg_from_string(doc, 1.0)
	return ImageTexture.create_from_image(img)
