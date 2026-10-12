## shot_stick.gd — renders ENH-302's Stick position at the A55's size, for review: Settings →
## Controls with the Touch stick row (forced visible; it is phone-only), then the playfield
## with a Left stick at rest and a Right stick held. Windowed; not in the suite:
##   "$GODOT" --path godot --render-thread safe -s addons/gut/gut_cmdln.gd \
##     -gtest=res://bench/shot_stick.gd -gexit
## Writes godot/build/shots/stick_a55.png (three rows, half size).
extends GutTest

const SIZE: Vector2i = Vector2i(2340, 1080)
## The A55's landscape safe-area inset, as shot_settings.gd uses.
const ORIGIN: Vector2 = Vector2(8.0, 12.0)


func _settings_shot(settings: ControlSettings) -> Image:
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(vp)
	var menu: TiltMenu = TiltMenu.new()
	menu.size = Vector2(SIZE)
	menu.theme = UiTheme.build(float(SIZE.y) / 390.0)
	vp.add_child(menu)
	menu.bind(
		GameOptionsManager.new(),
		ProgressionManager.new(),
		GoalManager.new(),
		ScoreManager.new(),
		settings
	)
	menu.set_ui_scale(float(SIZE.y) / 390.0, ORIGIN)
	menu.show_menu()
	menu.open_options_modal()
	(menu.find_child("StickCard", true, false) as Control).visible = true
	(menu.find_child("SchemeCard_keys", true, false) as Control).visible = false
	for f: int in range(4):
		await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _stick_shot(side: ControlSettings.StickAnchor, held: Vector2) -> Image:
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(vp)
	var bg: ColorRect = ColorRect.new()
	bg.color = UiTheme.COLOR_VOID
	bg.size = Vector2(SIZE)
	vp.add_child(bg)
	var stick: FloatingJoystick = FloatingJoystick.new()
	stick.set_size(float(SIZE.y) / 390.0, 1.0)
	var bounds: Vector2 = Vector2(SIZE) - ORIGIN * 2.0
	stick.apply_anchor(side, bounds)
	var layer: JoystickLayer = JoystickLayer.new()
	vp.add_child(layer)
	layer.bind(stick)
	layer.set_arena_origin(ORIGIN)
	layer.show_idle = true
	if held != Vector2.ZERO:
		stick.on_touch(0, stick.anchor + held)
	layer.queue_redraw()
	for f: int in range(3):
		await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func test_render() -> void:
	var settings: ControlSettings = ControlSettings.new()
	settings.scheme = Types.ControlScheme.MOUSE
	settings.stick_anchor = ControlSettings.StickAnchor.LEFT
	var shots: Array[Image] = [
		await _settings_shot(settings),
		await _stick_shot(ControlSettings.StickAnchor.LEFT, Vector2.ZERO),
		await _stick_shot(ControlSettings.StickAnchor.RIGHT, Vector2(-60.0, -70.0)),
	]
	var sheet: Image = Image.create_empty(
		SIZE.x, SIZE.y * shots.size(), false, shots[0].get_format()
	)
	for i: int in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, SIZE), Vector2i(0, SIZE.y * i))
	sheet.resize(SIZE.x / 2, SIZE.y * shots.size() / 2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	sheet.save_png(ProjectSettings.globalize_path("res://build/shots/stick_a55.png"))
	pass_test("shot")
