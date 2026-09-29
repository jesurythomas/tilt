## shot_run_over.gd — renders the Run over at the A55's size with six achievements, for
## review (ACH R3). Windowed; not in the suite:
##   "$GODOT" --path godot --render-thread safe -s addons/gut/gut_cmdln.gd -gtest=res://bench/shot_run_over.gd -gexit
## Writes godot/build/run_over_a55.png (the list scrolled to the top, then to the end).
extends GutTest

const SIZE: Vector2i = Vector2i(2340, 1080)


func _goal(id: String, title: String, reward: int) -> GoalManager.Goal:
	var g: GoalManager.Goal = GoalManager.Goal.new()
	g.id = id
	g.title = title
	g.reward_points = reward
	return g


func test_render() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(vp)
	var host: Control = Control.new()
	host.size = Vector2(SIZE)
	host.theme = UiTheme.build(float(SIZE.y) / 390.0)
	vp.add_child(host)
	var sheet: RunOverSheet = RunOverSheet.new()
	host.add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.set_ui_scale(float(SIZE.y) / 390.0)
	var result: RunOverSheet.RunResult = RunOverSheet.RunResult.new()
	result.score = 18420
	result.kills = 212
	result.best_chain = 9
	result.time_text = "1:12"
	result.mode_name = "Overdrive"
	result.mode_multiplier = 1.5
	result.earned = 1274
	result.milestones = [
		_goal("score_1k", "Rookie Dodger", 50),
		_goal("score_5k", "Neon Striker", 100),
		_goal("score_10k", "Swarm Survivor", 150),
		_goal("kills_15", "First Blood", 50),
		_goal("total_kills_100", "Centurion", 100),
		_goal("survive_60", "Minute Man", 100),
	]
	sheet.show_result(result)
	sheet.finish_count_up()
	for f: int in range(4):
		await RenderingServer.frame_post_draw
	var top: Image = vp.get_texture().get_image()
	var clip: ScrollContainer = sheet.find_child("MilestonesClip", true, false) as ScrollContainer
	clip.scroll_vertical = int(clip.get_v_scroll_bar().max_value)
	for f: int in range(3):
		await RenderingServer.frame_post_draw
	var bottom: Image = vp.get_texture().get_image()
	var both: Image = Image.create_empty(SIZE.x, SIZE.y * 2, false, top.get_format())
	both.blit_rect(top, Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
	both.blit_rect(bottom, Rect2i(Vector2i.ZERO, SIZE), Vector2i(0, SIZE.y))
	both.resize(SIZE.x / 2, SIZE.y)
	both.save_png(ProjectSettings.globalize_path("res://build/run_over_a55.png"))
	pass_test("shot")
