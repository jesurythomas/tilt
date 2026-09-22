## test_armory_ui.gd
## PORTS: nothing — new file, covers src/ui/armory_ui.gd, armory_theme.gd and
## scenes/armory.tscn
extends GutTest
## Proves the Armory shell: theme tokens, open/close, the tab aliases, the
## balance readout, and (Tasks 2-5) every purchase path from a tapped button.

const ARMORY_SCENE: PackedScene = preload("res://scenes/armory.tscn")

var _armory: ArmoryUI = null
var _progression: ProgressionManager = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))
	_progression = ProgressionManager.new()
	_armory = ARMORY_SCENE.instantiate() as ArmoryUI
	add_child_autofree(_armory)
	_armory.bind(_progression)
	await get_tree().process_frame


func after_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))


func _button(name: String) -> Button:
	var b: Button = _armory.find_child(name, true, false) as Button
	assert_not_null(b, "%s must exist" % name)
	return b


func _label(name: String) -> Label:
	var l: Label = _armory.find_child(name, true, false) as Label
	assert_not_null(l, "%s must exist" % name)
	return l


func test_theme_carries_the_css_tokens() -> void:
	assert_eq(ArmoryTheme.COLOR_ION, Color("#5B8CFF"))
	assert_eq(ArmoryTheme.COLOR_FLARE, Color("#FFB14D"))
	assert_eq(ArmoryTheme.PANEL_BG, Color("#0B0E14"))
	var theme: Theme = ArmoryTheme.build(1.0)
	assert_not_null(theme)
	assert_true(theme.is_type_variation("TabButton", "Button"), "TabButton variation")
	assert_true(theme.is_type_variation("PlayButton", "Button"), "PlayButton variation")
	assert_eq(theme.get_font_size("font_size", "TitleLabel"), ArmoryTheme.TITLE_FONT)
	var doubled: Theme = ArmoryTheme.build(2.0)
	assert_eq(doubled.get_font_size("font_size", "TitleLabel"), ArmoryTheme.TITLE_FONT * 2)


func test_starts_hidden_and_opens_on_weapons() -> void:
	assert_false(_armory.is_open())
	assert_false(_armory.visible)
	_armory.open()
	assert_true(_armory.is_open())
	assert_true(_armory.visible)
	assert_eq(_armory.active_tab, ArmoryUI.Tab.WEAPONS)


func test_open_maps_every_legacy_tab_name() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:296-308
	var expected: Dictionary[String, int] = {
		"weapons": ArmoryUI.Tab.WEAPONS,
		"perks": ArmoryUI.Tab.WEAPONS,
		"ships": ArmoryUI.Tab.SHIPS,
		"cursors": ArmoryUI.Tab.SHIPS,
		"arena": ArmoryUI.Tab.ARENA,
		"arenas": ArmoryUI.Tab.ARENA,
		"enemies": ArmoryUI.Tab.ARENA,
		"handling": ArmoryUI.Tab.HANDLING,
		"tuning": ArmoryUI.Tab.HANDLING,
		"boosts": ArmoryUI.Tab.BOOSTS,
	}
	for name: String in expected.keys():
		_armory.open(name)
		assert_eq(_armory.active_tab as int, expected[name], name)
	_armory.open("nonsense")
	assert_eq(_armory.active_tab, ArmoryUI.Tab.WEAPONS, "unknown falls back to weapons (:308)")


func test_open_without_tab_keeps_the_last_tab() -> void:
	_armory.open("boosts")
	_armory.close()
	_armory.open()
	assert_eq(
		_armory.active_tab, ArmoryUI.Tab.BOOSTS, "ArmoryUI.ts:295 remaps only when a tab is given"
	)


func test_tab_row_has_five_buttons_and_switches() -> void:
	_armory.open()
	await get_tree().process_frame
	var tabs: HBoxContainer = _armory.find_child("Tabs", true, false) as HBoxContainer
	assert_not_null(tabs)
	assert_eq(tabs.get_child_count(), 5)
	var ships: Button = _button("Tab_ships")
	assert_true(ships.toggle_mode, "button_pressed needs toggle_mode")
	assert_true(_button("Tab_weapons").button_pressed)
	ships.pressed.emit()
	assert_eq(_armory.active_tab, ArmoryUI.Tab.SHIPS)
	assert_true(ships.button_pressed)
	assert_false(_button("Tab_weapons").button_pressed)
	assert_not_null(_armory.find_child("ShipsTab", true, false), "the ships tab body was built")


func test_balance_shows_formatted_points() -> void:
	_armory.open()
	assert_eq(_label("BalanceLabel").text, "7,331 pts")
	_progression.data.points = 1
	_armory.render()
	assert_eq(_label("BalanceLabel").text, "1 pt")


func test_close_hides_and_emits() -> void:
	_armory.open()
	watch_signals(_armory)
	_armory.close()
	assert_false(_armory.visible)
	assert_false(_armory.is_open())
	assert_signal_emitted(_armory, "closed")


func test_close_and_back_and_play_buttons_close() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:1123-1131
	for name: String in ["CloseButton", "BackButton", "PlayButton"]:
		_armory.open()
		_button(name).pressed.emit()
		assert_false(_armory.is_open(), name)


func test_mobile_chrome_is_platform_gated() -> void:
	_armory.open()
	var is_mobile: bool = OS.has_feature("mobile")
	assert_eq(
		_button("BackButton").visible, is_mobile, "back button only on mobile (game.css:2836)"
	)
	assert_eq(_button("CloseButton").visible, not is_mobile, "close hidden on mobile (:2840)")
	var footer: Control = _armory.find_child("StickyFooter", true, false) as Control
	assert_eq(footer.visible, is_mobile, "sticky Play footer only on mobile (:2908)")


func test_format_points() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:70-72
	assert_eq(ArmoryUI.format_points(0), "0 pts")
	assert_eq(ArmoryUI.format_points(1), "1 pt")
	assert_eq(ArmoryUI.format_points(400), "400 pts")
	assert_eq(ArmoryUI.format_points(7331), "7,331 pts")
	assert_eq(ArmoryUI.format_points(1234567), "1,234,567 pts")


func test_format_tuning_value() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:46-57
	assert_eq(ArmoryUI.format_tuning_value(4.8, Tuning.TuningUnit.SECONDS), "4.8s")
	assert_eq(ArmoryUI.format_tuning_value(6.0, Tuning.TuningUnit.SECONDS), "6.0s")
	assert_eq(ArmoryUI.format_tuning_value(20.0, Tuning.TuningUnit.PERCENT), "+20%")
	assert_eq(ArmoryUI.format_tuning_value(340.0, Tuning.TuningUnit.RANGE), "340")
	assert_eq(ArmoryUI.format_tuning_value(8.0, Tuning.TuningUnit.COUNT), "8")


func test_svg_texture_rasterises() -> void:
	var svg: String = (
		"<svg xmlns='http://www.w3.org/2000/svg' width='30' height='30'>"
		+ "<circle cx='15' cy='15' r='5' fill='#A78BFA'/></svg>"
	)
	var tex: ImageTexture = ArmoryUI.svg_texture(svg, 2.0)
	assert_not_null(tex)
	assert_eq(tex.get_size(), Vector2(60.0, 60.0))
	assert_eq(tex.get_image().get_pixel(30, 30), Color("#A78BFA"))


func test_ui_scale_resizes_touch_targets() -> void:
	_armory.open()
	_armory.set_ui_scale(2.0)
	await get_tree().process_frame
	assert_eq(_button("Tab_weapons").custom_minimum_size.y, ControlPicker.BASE_TOUCH_TARGET * 2.0)
	assert_eq(_button("PlayButton").custom_minimum_size.y, ArmoryTheme.PLAY_BUTTON_HEIGHT * 2.0)
