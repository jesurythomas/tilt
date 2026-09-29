## shot_settings.gd — renders the Settings board at the A55's size, scrolled to the top and
## to the end, for review (menu overflow, 2026-09-29). Windowed; not in the suite:
##   "$GODOT" --path godot --render-thread safe -s addons/gut/gut_cmdln.gd -gtest=res://bench/shot_settings.gd -gexit
## Writes godot/build/shots/settings_a55.png (top over end, half size).
extends GutTest

const SIZE: Vector2i = Vector2i(2340, 1080)


func test_render() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(vp)
	var options: GameOptionsManager = GameOptionsManager.new()
	var menu: TiltMenu = TiltMenu.new()
	menu.size = Vector2(SIZE)
	menu.theme = UiTheme.build(float(SIZE.y) / 390.0)
	vp.add_child(menu)
	menu.bind(
		options,
		ProgressionManager.new(),
		GoalManager.new(),
		ScoreManager.new(),
		ControlSettings.new()
	)
	menu.set_ui_scale(float(SIZE.y) / 390.0, Vector2(8.0, 12.0))
	menu.show_menu()
	menu.open_options_modal()
	for f: int in range(4):
		await RenderingServer.frame_post_draw
	var top: Image = vp.get_texture().get_image()
	var scroll: ScrollContainer = menu.find_child("OptionsScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	for f: int in range(3):
		await RenderingServer.frame_post_draw
	var bottom: Image = vp.get_texture().get_image()
	var both: Image = Image.create_empty(SIZE.x, SIZE.y * 2, false, top.get_format())
	both.blit_rect(top, Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
	both.blit_rect(bottom, Rect2i(Vector2i.ZERO, SIZE), Vector2i(0, SIZE.y))
	both.resize(SIZE.x / 2, SIZE.y)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	both.save_png(ProjectSettings.globalize_path("res://build/shots/settings_a55.png"))
	pass_test("shot")
