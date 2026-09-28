## test_device_matrix.gd
## UI R7 (user 2026-09-28: "things should be dynamically scaling depending on device"):
## the menu, every Armory tab and the Run over lay out on real phone and tablet screens —
## each at its own ui_scale and arena inset — with nothing off screen, no overlapping
## blocks and every button at least a touch target tall.
extends GutTest

## Landscape viewports: A55 (2340×1080), Pixel 10 (2424×1080), 20:9 FHD+ (2400×1080), a
## small 720p phone (1600×720), a QHD+ flagship (3200×1440), 16:9 FHD (1920×1080), a 4:3
## tablet (2048×1536) and a 16:10 tablet (2560×1600).
const DEVICES: Array[Vector2] = [
	Vector2(2340.0, 1080.0),
	Vector2(2424.0, 1080.0),
	Vector2(2400.0, 1080.0),
	Vector2(1600.0, 720.0),
	Vector2(3200.0, 1440.0),
	Vector2(1920.0, 1080.0),
	Vector2(2048.0, 1536.0),
	Vector2(2560.0, 1600.0),
]

var _options: GameOptionsManager = null
var _progression: ProgressionManager = null
var _goals: GoalManager = null
var _scores: ScoreManager = null
var _settings: ControlSettings = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	for path: String in [
		ProgressionManager.SAVE_PATH,
		GameOptionsManager.SAVE_PATH,
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
		ControlSettings.SETTINGS_PATH,
	]:
		_remove(path)
	_options = GameOptionsManager.new()
	_progression = ProgressionManager.new()
	_goals = GoalManager.new()
	_scores = ScoreManager.new()
	_settings = ControlSettings.new()


## The scale and inset GameRoot gives a screen of this size (no reported safe area, so
## the minimum insets — the tightest case for height).
func _layout(size: Vector2) -> Array:
	return [HudController.ui_scale_for(size), GameRoot.arena_inset(size, Rect2())]


func test_menu_fits_every_device() -> void:
	for size: Vector2 in DEVICES:
		var layout: Array = _layout(size)
		var scale: float = layout[0]
		var menu: TiltMenu = TiltMenu.new()
		menu.size = size
		add_child_autofree(menu)
		menu.bind(_options, _progression, _goals, _scores, _settings)
		var inset: Vector2 = layout[1]
		menu.set_ui_scale(scale, inset)
		menu.show_menu()
		await get_tree().process_frame
		await get_tree().process_frame
		var tag: String = "%dx%d" % [size.x, size.y]
		var outside: Array[String] = UiChecks.outside(menu, Rect2(Vector2.ZERO, size))
		assert_true(outside.is_empty(), "%s: on screen %s" % [tag, outside])
		var tagline: Control = menu.find_child("MenuTagline", true, false) as Control
		var left: Control = menu.find_child("LeftBlock", true, false) as Control
		var gap: float = left.get_global_rect().position.y - tagline.get_global_rect().end.y
		assert_gt(gap, 0.0, "%s: the left column clears the tagline (%.0f px)" % [tag, gap])
		assert_gte(menu.fit_factor(), TiltMenu.FIT_MIN_FACTOR, tag)
		var short: Array[String] = UiChecks.short_buttons(
			menu, UiTheme.TOUCH_TARGET * scale * menu.fit_factor() - 0.5
		)
		assert_true(short.is_empty(), "%s: touch targets %s" % [tag, short])


func test_armory_fits_every_device() -> void:
	var scene: PackedScene = load("res://scenes/armory.tscn")
	for size: Vector2 in DEVICES:
		var layout: Array = _layout(size)
		var scale: float = layout[0]
		for tab: String in ["weapons", "ships", "arena", "handling", "boosts"]:
			var host: Control = Control.new()
			host.size = size
			add_child_autofree(host)
			var armory: ArmoryUI = scene.instantiate() as ArmoryUI
			host.add_child(armory)
			armory.bind(_progression, _settings)
			var inset: Vector2 = layout[1]
			armory.set_ui_scale(scale, inset)
			armory.open(tab)
			await get_tree().process_frame
			await get_tree().process_frame
			var tag: String = "%dx%d %s" % [size.x, size.y, tab]
			var outside: Array[String] = UiChecks.outside(armory, armory.get_global_rect())
			assert_true(outside.is_empty(), "%s: on screen %s" % [tag, outside])
			var header: Node = armory.find_child("Header", true, false)
			assert_true(UiChecks.overlapping_siblings(header).is_empty(), "%s: header" % tag)
			var short: Array[String] = UiChecks.short_buttons(
				armory, UiTheme.TOUCH_TARGET * scale - 0.5
			)
			assert_true(short.is_empty(), "%s: touch targets %s" % [tag, short])


func test_run_over_fits_every_device() -> void:
	for size: Vector2 in DEVICES:
		var scale: float = _layout(size)[0]
		var host: Control = Control.new()
		host.size = size
		host.theme = UiTheme.build(scale)
		add_child_autofree(host)
		var sheet: RunOverSheet = RunOverSheet.new()
		host.add_child(sheet)
		sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sheet.set_ui_scale(scale)
		var result: RunOverSheet.RunResult = RunOverSheet.RunResult.new()
		result.score = 530229
		result.kills = 1874
		result.best_diff = 120000
		result.earned = 12740
		sheet.show_result(result)
		sheet.finish_count_up()
		sheet.visible = true
		await get_tree().process_frame
		await get_tree().process_frame
		var tag: String = "%dx%d" % [size.x, size.y]
		var outside: Array[String] = UiChecks.outside(sheet, Rect2(Vector2.ZERO, size))
		assert_true(outside.is_empty(), "%s: on screen %s" % [tag, outside])
		for column: String in ["LeftColumn", "RightColumn"]:
			var box: Node = sheet.find_child(column, true, false)
			assert_true(UiChecks.overlapping_siblings(box).is_empty(), "%s %s" % [tag, column])
