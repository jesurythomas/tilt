## test_tilt_menu.gd
## PORTS: nothing — new file, covers ui/tilt_menu.gd
extends GutTest
## The menu screen (TiltMenu.ts:87-255) and, from Task 5, the options modal.

var _options: GameOptionsManager = null
var _progression: ProgressionManager = null
var _goals: GoalManager = null
var _scores: ScoreManager = null
var _settings: ControlSettings = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _clear() -> void:
	for path: String in [
		GameOptionsManager.SAVE_PATH,
		ProgressionManager.SAVE_PATH,
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
		ControlSettings.SETTINGS_PATH,
		ScoreManager.BEST_SCORE_PATH,
	]:
		_remove(path)


func before_each() -> void:
	_clear()
	_options = GameOptionsManager.new()
	_progression = ProgressionManager.new()
	_goals = GoalManager.new()
	_scores = ScoreManager.new()
	_settings = ControlSettings.new()


func after_each() -> void:
	_clear()


func _menu() -> TiltMenu:
	var menu: TiltMenu = TiltMenu.new()
	menu.theme = UiTheme.build(1.0)
	menu.size = Vector2(844.0, 390.0)
	add_child_autofree(menu)
	menu.bind(_options, _progression, _goals, _scores, _settings)
	menu.show_menu()
	return menu


func test_menu_exposes_its_controls() -> void:
	var menu: TiltMenu = _menu()
	for node_name: String in [
		"MenuTitle",
		"PlayButton",
		"MenuArmoryButton",
		"MenuMilestonesButton",
		"MenuSettingsButton",
		"MenuCalibrateButton",
		"ModeCard_classic",
		"ModeCard_gauntlet",
		"ModeCard_code-red",
	]:
		assert_not_null(menu.find_child(node_name, true, false), node_name)
	var title: Label = menu.find_child("MenuTitle", true, false) as Label
	assert_eq(title.text, "PERIL\nPOINT", "R6")


func test_mode_cards_show_ts_names_taglines_and_multipliers() -> void:
	var menu: TiltMenu = _menu()
	var card: Control = menu.find_child("ModeCard_code-red", true, false) as Control
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in card.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_has(texts, "Code Red", "GameOptions.ts:62")
	assert_has(texts, "Double density from the first second.", "GameOptions.ts:64")
	assert_has(texts, "1.50×", "toFixed(2) since 1.5 % 1 != 0 (TiltMenu.ts:144)")


func test_picking_a_card_saves_the_mode_and_rerenders() -> void:
	var menu: TiltMenu = _menu()
	(menu.find_child("ModeCard_gauntlet", true, false) as Button).pressed.emit()
	assert_eq(_options.settings.mode, Types.GameMode.GAUNTLET, "TiltMenu.ts:222")
	assert_eq(GameOptionsManager.new().settings.mode, Types.GameMode.GAUNTLET, "saved")
	assert_true(menu.is_mode_selected(Types.GameMode.GAUNTLET), "re-rendered (:223)")


func test_play_hides_the_menu_and_requests_the_saved_mode() -> void:
	_options.set_mode(Types.GameMode.CODE_RED)
	var menu: TiltMenu = _menu()
	watch_signals(menu)
	(menu.find_child("PlayButton", true, false) as Button).pressed.emit()
	assert_false(menu.is_menu_visible(), "TiltMenu.ts:239")
	assert_signal_emitted_with_parameters(menu, "launch_requested", [Types.GameMode.CODE_RED])


func test_nav_buttons_emit_their_requests() -> void:
	var menu: TiltMenu = _menu()
	watch_signals(menu)
	(menu.find_child("MenuArmoryButton", true, false) as Button).pressed.emit()
	(menu.find_child("MenuMilestonesButton", true, false) as Button).pressed.emit()
	(menu.find_child("MenuCalibrateButton", true, false) as Button).pressed.emit()
	assert_signal_emitted(menu, "armory_requested", "TiltMenu.ts:244-246")
	assert_signal_emitted(menu, "all_goals_requested", "TiltMenu.ts:248-250")
	assert_signal_emitted(menu, "calibrate_screen_requested", "R5")


func test_stats_row_hides_until_a_best_exists() -> void:
	var menu: TiltMenu = _menu()
	var row: Control = menu.find_child("StatsRow", true, false) as Control
	assert_false(row != null and row.is_visible_in_tree(), "bestScore 0 → hidden (TiltMenu.ts:180)")
	_scores.stats.best_score = 32420
	_progression.data.points = 7331
	menu.render()
	row = menu.find_child("StatsRow", true, false) as Control
	assert_true(row.is_visible_in_tree())
	assert_eq((menu.find_child("StatBest", true, false) as Label).text, "32,420")
	assert_eq((menu.find_child("StatPoints", true, false) as Label).text, "7,331")


func test_next_teaser_shows_the_first_active_goal() -> void:
	var menu: TiltMenu = _menu()
	var teaser: Control = menu.find_child("NextTeaser", true, false) as Control
	assert_not_null(teaser, "a fresh save has active goals (TiltMenu.ts:97)")
	assert_true(teaser.is_visible_in_tree(), "R8")


func test_steer_picker_reports_the_scheme() -> void:
	var menu: TiltMenu = _menu()
	watch_signals(menu)
	var picker: ControlPicker = (
		menu.find_children("*", "ControlPicker", true, false)[0] as ControlPicker
	)
	picker.scheme_chosen.emit(Types.ControlScheme.GYRO)
	assert_signal_emitted_with_parameters(menu, "scheme_chosen", [Types.ControlScheme.GYRO])


func test_every_menu_target_meets_the_48_rule() -> void:
	var menu: TiltMenu = _menu()
	await get_tree().process_frame
	for button: Node in menu.find_children("*", "Button", true, false):
		var b: Button = button as Button
		if b.is_visible_in_tree():
			assert_true(b.size.y >= 48.0, "%s height %f (interface spec §4.5)" % [b.name, b.size.y])
