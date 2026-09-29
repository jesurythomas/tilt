## arena_sheet.gd — renders every arena theme as a run draws it (GridLayer at the A55's
## proportions), 4 x 4, for review (THEME R2). Windowed; not in the suite:
##   "$GODOT" --path godot --render-thread safe -s addons/gut/gut_cmdln.gd -gtest=res://bench/arena_sheet.gd -gexit
## Writes godot/build/shots/arena_sheet.png. ARENA_SHEET_WAIT (seconds, default 1.5) is how
## long the effects run before the capture. ARENA_SHEET_ONLY="arctic,ember" renders just
## those themes, two across, at 1170 x 540 (half the A55).
extends GutTest

const CELL: Vector2i = Vector2i(780, 360)
const BIG_CELL: Vector2i = Vector2i(1170, 540)


func test_render() -> void:
	var progression: ProgressionManager = ProgressionManager.new()
	var themes: Array[ProgressionManager.ArenaThemeConfig] = []
	var only: PackedStringArray = OS.get_environment("ARENA_SHEET_ONLY").split(",", false)
	for theme_config: ProgressionManager.ArenaThemeConfig in progression.arena_theme_catalog:
		if only.is_empty() or only.has(theme_config.id):
			themes.append(theme_config)
	var cell: Vector2i = CELL if only.is_empty() else BIG_CELL
	var columns: int = 4 if only.is_empty() else 2
	var viewports: Array[SubViewport] = []
	for theme_config: ProgressionManager.ArenaThemeConfig in themes:
		var vp: SubViewport = SubViewport.new()
		vp.size = cell
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child_autofree(vp)
		var layer: GridLayer = GridLayer.new()
		vp.add_child(layer)
		layer.bind(VectorGrid.new(cell.x, cell.y))
		layer.set_arena_theme(theme_config)
		layer.refresh()
		viewports.append(vp)
	var wait: float = 1.5
	if OS.has_environment("ARENA_SHEET_WAIT"):
		wait = float(OS.get_environment("ARENA_SHEET_WAIT"))
	await get_tree().create_timer(wait).timeout
	for f: int in range(3):
		await RenderingServer.frame_post_draw
	var rows: int = ceili(float(themes.size()) / columns)
	var sheet: Image = Image.create_empty(
		cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8
	)
	for i: int in range(viewports.size()):
		var img: Image = viewports[i].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(
			img,
			Rect2i(Vector2i.ZERO, cell),
			Vector2i((i % columns) * cell.x, (i / columns) * cell.y)
		)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	sheet.save_png(ProjectSettings.globalize_path("res://build/shots/arena_sheet.png"))
	pass_test("shot")
