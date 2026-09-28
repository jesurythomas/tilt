## icon_sheet.gd — renders the WeaponIcons set for review (ICONS R1). Not in the suite:
##   "$GODOT" --headless --path godot -s addons/gut/gut_cmdln.gd -gtest=res://bench/icon_sheet.gd -gexit
## Writes godot/build/icon_sheet.png: per glyph, white at 24 and 48 px on the panel colour,
## tinted at 48 px, greyscale at 48 px, then (weapons) the orb sprite at 32, 48 and 72 px.
extends GutTest

const CELL: int = 96
const KEYS: Array[String] = [
	"nuke",
	"missiles",
	"lightning",
	"laser",
	"blackhole",
	"freeze",
	"shield",
	"extraLives",
	"hullCompact",
	"enemySlow",
	"scoreMultiplier",
	"pointsMultiplier",
]


func _blit(sheet: Image, tex: Texture2D, cx: int, cy: int, tint: Color, grey: bool) -> void:
	var img: Image = tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var t: Color = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
			if grey:
				var l: float = t.get_luminance()
				t = Color(l, l, l, t.a)
			var px: int = cx - img.get_width() / 2 + x
			var py: int = cy - img.get_height() / 2 + y
			var under: Color = sheet.get_pixel(px, py)
			sheet.set_pixel(px, py, under.blend(t))


func test_render_sheet() -> void:
	var cols: int = 8
	var sheet: Image = Image.create_empty(
		CELL * cols, CELL * KEYS.size(), false, Image.FORMAT_RGBA8
	)
	sheet.fill(UiTheme.COLOR_SHELL)
	for row: int in range(KEYS.size()):
		var key: String = KEYS[row]
		var cy: int = row * CELL + CELL / 2
		for col: int in range(1, 5):
			sheet.fill_rect(
				Rect2i(col * CELL + 4, row * CELL + 4, CELL - 8, CELL - 8), UiTheme.COLOR_PANEL
			)
		var type: int = WeaponIcons.weapon_type(key)
		var tint: Color = UiTheme.COLOR_FLARE
		if type != Types.ABSENT:
			tint = WeaponIcons.ui_color_of(type)
		_blit(sheet, WeaponIcons.texture(key, 24), CELL + CELL / 2, cy, Color.WHITE, false)
		_blit(sheet, WeaponIcons.texture(key, 48), 2 * CELL + CELL / 2, cy, Color.WHITE, false)
		_blit(sheet, WeaponIcons.texture(key, 48), 3 * CELL + CELL / 2, cy, tint, false)
		_blit(sheet, WeaponIcons.texture(key, 48), 4 * CELL + CELL / 2, cy, tint, true)
		if type != Types.ABSENT:
			var sizes: Array[int] = [32, 48, 72]
			for k: int in range(sizes.size()):
				var orb: Texture2D = WeaponIcons.orb_texture(type, sizes[k])
				_blit(sheet, orb, (5 + k) * CELL + CELL / 2, cy, Color.WHITE, false)
	var out: String = ProjectSettings.globalize_path("res://build/icon_sheet.png")
	sheet.save_png(out)
	print("SHEET ", out)
	pass_test("sheet")
