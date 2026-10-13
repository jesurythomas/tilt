## test_ad_break.gd
## PORTS: nothing — new file, covers GameRoot's ad break and Settings' Ad privacy row (ADS R2, R3)
extends GutTest
## Proves that only leaving the Run over (Retry, Menu) is an ad break, that its action waits
## for the ad, that each death counts for the pacing, and that Settings offers UMP's privacy
## options only when UMP asks for them.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _rec: RecordingAdsBackend = null
var _previous: AdsBackend = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _remove_saves() -> void:
	for path: String in [
		ProgressionManager.SAVE_PATH,
		ControlSettings.SETTINGS_PATH,
		GameOptionsManager.SAVE_PATH,
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
		ScoreManager.BEST_SCORE_PATH,
		TiltInput.CALIBRATION_PATH,
		Ads.SAVE_PATH,
	]:
		_remove(path)
		_remove(SaveStore.corrupt_path_for(path))


func before_each() -> void:
	_remove_saves()
	_previous = Ads.backend
	_rec = RecordingAdsBackend.new()
	Ads.set_backend(_rec)
	Ads.reset_session()


func after_each() -> void:
	Ads.reset_session()
	Ads.set_backend(_previous)
	Ads.reset_session()
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, null)
	AudioServer.set_bus_mute(0, false)
	_remove_saves()


func _boot() -> GameRoot:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	return root


## Boots, grants consent with an ad loaded and the pacing off, and dies in a run.
func _boot_to_run_over() -> GameRoot:
	var root: GameRoot = await _boot()
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, true)
	_rec.consent_finished.emit(true, false)
	_rec.interstitial_loaded.emit()
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	root._player.shield_timer = 0.0  # past the cold open's spawn shield
	root._run_controller.lives = 1
	root._run_controller.lose_life()
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER)
	return root


func _press(root: GameRoot, button_name: String) -> void:
	var button: Button = root.find_child(button_name, true, false) as Button
	assert_not_null(button, "%s must exist" % button_name)
	button.pressed.emit()


func test_launch_gathers_consent_after_the_first_frame() -> void:
	await _boot()
	assert_eq(_rec.count("consent"), 1)


func test_a_death_counts_for_the_pacing() -> void:
	var root: GameRoot = await _boot_to_run_over()
	assert_eq(Ads.pacing.games_since_ad, 1)
	assert_not_null(root)


func test_retry_from_the_run_over_waits_for_the_ad() -> void:
	var root: GameRoot = await _boot_to_run_over()
	_press(root, "RestartButton")
	assert_eq(_rec.count("show"), 1)
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER, "the run waits for the ad")
	_rec.interstitial_opened.emit()
	_rec.interstitial_closed.emit()
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "then the run restarts")


func test_menu_from_the_run_over_waits_for_the_ad() -> void:
	var root: GameRoot = await _boot_to_run_over()
	_press(root, "GameOverMenuButton")
	assert_eq(_rec.count("show"), 1)
	assert_false(root.is_in_menu(), "the menu waits for the ad")
	_rec.interstitial_closed.emit()
	assert_true(root.is_in_menu())


func test_a_double_tap_on_retry_restarts_once() -> void:
	var root: GameRoot = await _boot_to_run_over()
	_press(root, "RestartButton")
	_press(root, "RestartButton")
	assert_eq(_rec.count("show"), 1)
	_rec.interstitial_closed.emit()
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC)


func test_pause_restart_and_quit_are_not_ad_breaks() -> void:
	var root: GameRoot = await _boot()
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, true)
	_rec.consent_finished.emit(true, false)
	_rec.interstitial_loaded.emit()
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	root.toggle_pause()
	root.restart_run()
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "Pause's Restart run is immediate")
	root.skip_cinematic()
	root.toggle_pause()
	root.return_to_menu()
	assert_true(root.is_in_menu(), "Pause's Quit to menu is immediate")
	assert_eq(_rec.count("show"), 0)


func test_without_an_ad_retry_restarts_at_once() -> void:
	var root: GameRoot = await _boot_to_run_over()
	_rec.interstitial_failed_to_load.emit()
	Ads.is_ad_loaded = false
	_press(root, "RestartButton")
	assert_eq(_rec.count("show"), 0)
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC)


func test_settings_offers_ad_privacy_only_when_ump_asks() -> void:
	var root: GameRoot = await _boot()
	root._menu.open_options_modal()
	assert_null(root.find_child("AdPrivacyButton", true, false), "hidden without the requirement")
	_rec.consent_finished.emit(true, true)
	var manage: Button = root.find_child("AdPrivacyButton", true, false) as Button
	assert_not_null(manage, "consent asking for it redraws Settings with the row")
	manage.pressed.emit()
	assert_eq(_rec.count("privacy"), 1)
