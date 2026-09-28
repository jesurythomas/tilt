## test_weapon_icons.gd
## ICONS R1: the shared icon set — every power-up and boost has a glyph that rasterises
## to a visible silhouette, the weapon ↔ key mapping round-trips, and orb sprites and
## glyph textures are memoised at the requested size.
extends GutTest

const BOOSTS: Array[String] = [
	"extraLives", "hullCompact", "enemySlow", "scoreMultiplier", "pointsMultiplier"
]


func _coverage(tex: Texture2D) -> float:
	var img: Image = tex.get_image()
	var lit: int = 0
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.5:
				lit += 1
	return float(lit) / float(img.get_width() * img.get_height())


func test_every_weapon_and_boost_has_a_visible_glyph_at_24_px() -> void:
	var keys: Array[String] = []
	for type: Types.WeaponType in Types.WeaponType.values():
		keys.append(WeaponIcons.weapon_key(type))
	keys.append_array(BOOSTS)
	for key: String in keys:
		assert_true(WeaponIcons.GLYPHS.has(key), "glyph for %s" % key)
		var tex: Texture2D = WeaponIcons.texture(key, 24)
		assert_eq(tex.get_width(), 24, key)
		var cov: float = _coverage(tex)
		assert_between(cov, 0.12, 0.7, "%s silhouette covers %.2f of its cell" % [key, cov])


func test_weapon_keys_round_trip() -> void:
	for type: Types.WeaponType in Types.WeaponType.values():
		var key: String = WeaponIcons.weapon_key(type)
		assert_ne(key, "", "every power-up has a key")
		assert_eq(WeaponIcons.weapon_type(key), type)
	assert_eq(WeaponIcons.weapon_key(Types.WeaponType.VORTEX), "blackhole", "the Armory's id")
	assert_eq(WeaponIcons.weapon_type("extraLives"), Types.ABSENT, "boosts are not weapons")


func test_textures_are_memoised_per_size() -> void:
	var a: Texture2D = WeaponIcons.texture("nuke", 32)
	assert_same(WeaponIcons.texture("nuke", 32), a)
	assert_ne(WeaponIcons.texture("nuke", 48), a)
	var orb: Texture2D = WeaponIcons.orb_texture(Types.WeaponType.SHIELD, 40)
	assert_eq(orb.get_width(), 40)
	assert_same(WeaponIcons.orb_texture(Types.WeaponType.SHIELD, 40), orb)


func test_ui_colour_is_the_orb_colour_lifted() -> void:
	for type: Types.WeaponType in Types.WeaponType.values():
		var c: Color = WeaponIcons.color_of(type)
		assert_eq(c, WeaponSystem.get_weapon_color(type), "one colour per weapon")
		assert_gt(WeaponIcons.ui_color_of(type).get_luminance(), c.get_luminance())
