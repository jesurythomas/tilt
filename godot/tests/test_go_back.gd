## test_go_back.gd
## PORTS: nothing — new file, covers GameRoot.go_back and pause_on_focus_loss (MVP Week 1)
extends GutTest
## Proves the Android back button closes the topmost sheet, pauses a run, and
## leaves the app only from a bare menu; and that losing focus pauses a run.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _boot() -> GameRoot:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	return root


func _boot_into_run() -> GameRoot:
	var root: GameRoot = await _boot()
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	return root


func test_back_on_a_bare_menu_is_not_handled_so_the_app_may_quit() -> void:
	var root: GameRoot = await _boot()
	if root._how_to_play.is_open():
		root._how_to_play.close()  # HTP R1: a first launch opens the guide over the menu
	assert_false(root.go_back(), "nothing to close on the menu")


## DIVERGENCE(HTP R1): the guide sits over the menu; back closes it first.
func test_back_closes_how_to_play() -> void:
	var root: GameRoot = await _boot()
	root.open_how_to_play()
	root._menu.open_options_modal()
	assert_true(root.go_back())
	assert_false(root._how_to_play.is_open())
	assert_true(root._menu.is_options_open(), "Settings beneath stays up")


func test_back_closes_settings_over_the_menu() -> void:
	var root: GameRoot = await _boot()
	root._menu.open_options_modal()
	assert_true(root.go_back())
	assert_false(root._menu.is_options_open())
	assert_true(root.is_in_menu(), "still on the menu")


func test_back_closes_calibrate() -> void:
	var root: GameRoot = await _boot()
	root.open_calibrate_screen()
	assert_true(root.go_back())
	assert_false(root._calibrate_screen.is_open())


func test_back_closes_the_armory_before_anything_beneath() -> void:
	var root: GameRoot = await _boot_into_run()
	root.toggle_pause()
	root.open_armory()
	assert_true(root.go_back())
	assert_false(root._armory.is_open())
	assert_true(root.is_paused(), "the pause sheet stays up beneath")


func test_back_closes_the_milestones_modal() -> void:
	var root: GameRoot = await _boot()
	root.open_all_goals_modal()
	assert_true(root.go_back())
	assert_false(root._goals_hud.is_modal_open())


func test_back_pauses_a_run_and_a_second_back_resumes() -> void:
	var root: GameRoot = await _boot_into_run()
	assert_true(root.go_back())
	assert_true(root.is_paused())
	assert_true(root.go_back())
	assert_false(root.is_paused())
	assert_eq(root._state.phase, Types.GamePhase.PLAYING)


func test_back_skips_the_cold_open() -> void:
	var root: GameRoot = await _boot()
	root.launch_run(root.options.settings.mode)
	root.restart_run()
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC)
	assert_true(root.go_back())
	assert_ne(root._state.phase, Types.GamePhase.CINEMATIC)


func test_focus_loss_pauses_a_run_and_shows_the_sheet() -> void:
	var root: GameRoot = await _boot_into_run()
	root.pause_on_focus_loss()
	assert_true(root.is_paused())
	assert_true(root._hud._pause_panel.visible)


func test_focus_loss_never_resumes_or_pauses_the_menu() -> void:
	var root: GameRoot = await _boot()
	root.pause_on_focus_loss()
	assert_true(root.is_in_menu())
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	root.pause_on_focus_loss()
	root.pause_on_focus_loss()
	assert_true(root.is_paused(), "a second focus loss leaves it paused")
