## test_how_to_play_screen.gd
## PORTS: nothing — new file, covers ui/how_to_play_screen.gd (HTP R1)
extends GutTest
## The How to play guide: paging, the power-up picker and its clips, and fit on the A55.


func _screen() -> HowToPlayScreen:
	var screen: HowToPlayScreen = HowToPlayScreen.new()
	screen.theme = UiTheme.build(1.0)
	screen.size = Vector2(844.0, 390.0)
	add_child_autofree(screen)
	screen.bind(GameOptionsManager.new())
	return screen


func _press(screen: HowToPlayScreen, button_name: String) -> void:
	(screen.find_child(button_name, true, false) as Button).pressed.emit()


func _title(screen: HowToPlayScreen) -> String:
	return (screen.find_child("HowToPlayTitle", true, false) as Label).text


func test_starts_closed_and_opens_on_the_first_page() -> void:
	var screen: HowToPlayScreen = _screen()
	assert_false(screen.is_open())
	assert_false(screen.visible)
	screen.open()
	assert_true(screen.is_open())
	assert_true(screen.visible)
	assert_eq(screen.page(), 0)
	assert_eq(_title(screen), "The basics")


func test_next_and_back_walk_the_pages() -> void:
	var screen: HowToPlayScreen = _screen()
	screen.open()
	assert_true(
		(screen.find_child("HowToPlayBackButton", true, false) as Button).disabled,
		"no Back on the first page"
	)
	for i: int in range(1, HowToPlayScreen.PAGES.size()):
		_press(screen, "HowToPlayNextButton")
		assert_eq(screen.page(), i)
		assert_eq(_title(screen), HowToPlayScreen.PAGES[i])
	_press(screen, "HowToPlayBackButton")
	assert_eq(screen.page(), HowToPlayScreen.PAGES.size() - 2)


func test_got_it_on_the_last_page_closes() -> void:
	var screen: HowToPlayScreen = _screen()
	screen.open(HowToPlayScreen.PAGES.size() - 1)
	var next: Button = screen.find_child("HowToPlayNextButton", true, false) as Button
	assert_eq(next.text, "Got it")
	watch_signals(screen)
	next.pressed.emit()
	assert_false(screen.is_open())
	assert_signal_emitted(screen, "closed")


func test_the_close_chevron_closes_from_any_page() -> void:
	var screen: HowToPlayScreen = _screen()
	screen.open(2)
	watch_signals(screen)
	_press(screen, "HowToPlayCloseButton")
	assert_false(screen.is_open())
	assert_false(screen.visible)
	assert_signal_emitted(screen, "closed")


func test_every_power_up_has_a_clip_and_an_orb_button() -> void:
	var screen: HowToPlayScreen = _screen()
	screen.open(1)
	for type: Types.WeaponType in HowToPlayScreen.WEAPONS:
		var key: String = WeaponIcons.weapon_key(type)
		assert_true(ResourceLoader.exists(HowToPlayScreen.CLIP_PATH % key), key + " clip")
		assert_not_null(screen.find_child("Orb_" + key, true, false), key + " orb button")


func test_picking_an_orb_swaps_the_clip_and_the_lines() -> void:
	var screen: HowToPlayScreen = _screen()
	screen.open(1)
	assert_not_null(screen.clip(), "the Power-ups page plays a clip")
	assert_eq(screen.selected_weapon(), Types.WeaponType.NUKE)
	_press(screen, "Orb_freeze")
	assert_eq(screen.selected_weapon(), Types.WeaponType.FREEZE)
	assert_eq((screen.find_child("WeaponName", true, false) as Label).text, "Freeze")
	assert_eq(
		(screen.find_child("WeaponLine", true, false) as Label).text,
		HowToPlayScreen.WEAPON_LINES[Types.WeaponType.FREEZE]
	)
	assert_eq(screen.clip().stream.resource_path, HowToPlayScreen.CLIP_PATH % "freeze")
	assert_true((screen.find_child("Orb_freeze", true, false) as Button).button_pressed)
	assert_false((screen.find_child("Orb_nuke", true, false) as Button).button_pressed)


func test_the_clip_goes_with_the_page() -> void:
	var screen: HowToPlayScreen = _screen()
	screen.open(1)
	assert_not_null(screen.clip())
	_press(screen, "HowToPlayNextButton")
	assert_null(screen.clip(), "no clip off the Power-ups page")
	screen.open(1)
	screen.close()
	assert_null(screen.clip(), "closing drops the clip")


func test_the_enemy_list_holds_every_enemy() -> void:
	var screen: HowToPlayScreen = _screen()
	screen.open(2)
	var list: Node = screen.find_child("EnemyList", true, false)
	assert_eq(list.get_child_count(), HowToPlayScreen.ENEMIES.size())


func test_the_modes_column_lists_every_mode() -> void:
	var screen: HowToPlayScreen = _screen()
	screen.open(3)
	for config: GameOptionsManager.ModeConfig in GameOptionsManager.new().modes:
		var found: bool = false
		for label: Node in screen.find_children("*", "Label", true, false):
			if (label as Label).text == config.name:
				found = true
		assert_true(found, config.name)


func test_every_target_meets_the_48_rule() -> void:
	var screen: HowToPlayScreen = _screen()
	screen.open(1)
	await get_tree().process_frame
	for node: Node in screen.find_children("*", "Button", true, false):
		var b: Button = node as Button
		assert_true(b.size.y >= 48.0, b.name)
		assert_true(b.size.x >= 48.0, b.name)


## The header's buttons and every page's body stay on the A55's screen (2340×1080 at 2.77).
func test_every_page_fits_the_a55() -> void:
	var screen: HowToPlayScreen = HowToPlayScreen.new()
	add_child_autofree(screen)
	screen.size = Vector2(2340.0, 1080.0)
	screen.bind(GameOptionsManager.new())
	screen.set_ui_scale(2.77, Vector2.ZERO)
	for i: int in range(HowToPlayScreen.PAGES.size()):
		screen.open(i)
		await get_tree().process_frame
		await get_tree().process_frame
		var bounds: Rect2 = screen.get_global_rect()
		for node_name: String in [
			"HowToPlayCloseButton", "HowToPlayBackButton", "HowToPlayNextButton", "HowToPlayBody"
		]:
			var c: Control = screen.find_child(node_name, true, false) as Control
			assert_true(bounds.encloses(c.get_global_rect()), "page %d: %s" % [i, node_name])
