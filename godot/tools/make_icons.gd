## make_icons.gd — renders the app icons from the ship glyph (M11c review).
## The launcher icon and the Android 12 system splash showed Godot's default icon.
## These draw the game's arrow ship (UiTheme.ship_glyph_svg's path, ion blue) with a
## soft ion glow on the void colour, matching the boot splash and cold open.
## Headless is fine (SVG and gradients rasterise on the CPU):
##   "$GODOT" --headless --path godot -s res://tools/make_icons.gd
extends SceneTree

const OUT_DIR: String = "res://assets/icon/"
const VOID: Color = Color("#08090E")
const ION: Color = Color("#5B8CFF")
## The ship path on its 40-unit viewBox (Hud.dc.html's lives glyph).
const SHIP_PATH: String = "M34 20 L11 8 L16 20 L11 32 Z"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# Launcher / project icon: full bleed, ship at 62% of the side.
	_save(_icon(512, 0.62, true, true), "icon.png")
	_save(_icon(192, 0.62, true, true), "icon_192.png")
	# Adaptive icon: the launcher masks to a circle-ish 66% safe zone, so the ship
	# sits at 40% of the 432 canvas; background and foreground are separate layers.
	_save(_icon(432, 0.40, false, false), "adaptive_foreground.png")
	_save(_icon(432, 0.0, true, true), "adaptive_background.png")
	_save(_icon(432, 0.40, false, false, Color.WHITE), "adaptive_monochrome.png")
	quit()


## A size x size icon: optional void fill and glow, and the ship at `ship_frac` of the side.
func _icon(size: int, ship_frac: float, fill: bool, glow: bool, ship_color: Color = ION) -> Image:
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	if fill:
		img.fill(VOID)
	if glow:
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(ION, 0.28), Color(ION, 0.0)])
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = g
		tex.width = size
		tex.height = size
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var glow_img: Image = tex.get_image()
		glow_img.convert(Image.FORMAT_RGBA8)
		img.blend_rect(glow_img, Rect2i(0, 0, size, size), Vector2i.ZERO)
	if ship_frac > 0.0:
		var ship_px: int = roundi(size * ship_frac)
		var svg: String = (
			(
				"<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 40 40'>"
				% [ship_px, ship_px]
			)
			+ "<path d='%s' fill='#%s'/></svg>" % [SHIP_PATH, ship_color.to_html(false)]
		)
		var ship: Image = Image.new()
		ship.load_svg_from_string(svg, 1.0)
		ship.convert(Image.FORMAT_RGBA8)
		var at: Vector2i = Vector2i((size - ship.get_width()) / 2, (size - ship.get_height()) / 2)
		img.blend_rect(ship, Rect2i(Vector2i.ZERO, ship.get_size()), at)
	return img


func _save(img: Image, file: String) -> void:
	var err: Error = img.save_png(ProjectSettings.globalize_path(OUT_DIR + file))
	print("make_icons: %s %s -> %d" % [file, img.get_size(), err])
