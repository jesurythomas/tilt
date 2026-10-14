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


## Boots, grants consent with a rewarded ad loaded (the pacing as shipped), and dies in a run.
func _boot_to_run_over_with_reward() -> GameRoot:
	var root: GameRoot = await _boot()
	_rec.consent_finished.emit(true, false)
	_rec.rewarded_loaded.emit()
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	root._player.shield_timer = 0.0  # past the cold open's spawn shield
	root._run_controller.lives = 1
	root._run_controller.lose_life()
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER)
	return root


func _offer(root: GameRoot) -> Button:
	return root.find_child("WatchAdButton", true, false) as Button


func test_the_run_over_offers_the_rewarded_ad_when_one_is_ready() -> void:
	var root: GameRoot = await _boot_to_run_over_with_reward()
	assert_true(_offer(root).visible)
	assert_false(_offer(root).disabled)


func test_no_offer_until_a_rewarded_ad_loads() -> void:
	var root: GameRoot = await _boot()
	_rec.consent_finished.emit(true, false)
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	root._player.shield_timer = 0.0
	root._run_controller.lives = 1
	root._run_controller.lose_life()
	assert_false(_offer(root).visible, "no ad, no offer")
	_rec.rewarded_loaded.emit()
	assert_true(_offer(root).visible, "it appears when one loads")


func test_watching_the_ad_triples_the_runs_points_once() -> void:
	var root: GameRoot = await _boot_to_run_over_with_reward()
	var run: RunController = root._run_controller
	var earned: int = run.points_credited_this_run
	assert_gt(earned, 0, "the payout at death")
	var balance: int = run.progression.data.points
	_press(root, "WatchAdButton")
	assert_eq(_rec.count("reward_show"), 1)
	assert_true(_offer(root).disabled, "greyed while its ad is on its way")
	_rec.rewarded_opened.emit()
	_rec.rewarded_earned.emit()
	assert_eq(run.points_credited_this_run, earned * GameRoot.AD_REWARD_MULTIPLIER)
	assert_eq(run.progression.data.points, balance + earned * 2)
	assert_false(_offer(root).visible, "once a run")
	_rec.rewarded_closed.emit()
	_rec.rewarded_loaded.emit()
	assert_false(_offer(root).visible, "a fresh ad does not reopen it")
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER, "the player stays on the Run over")


func test_the_bonus_skips_the_points_multiplier() -> void:
	var root: GameRoot = await _boot_to_run_over_with_reward()
	var run: RunController = root._run_controller
	run.progression.data.points_multiplier = 3
	var earned: int = run.points_credited_this_run
	var balance: int = run.progression.data.points
	_press(root, "WatchAdButton")
	_rec.rewarded_opened.emit()
	_rec.rewarded_earned.emit()
	assert_eq(run.progression.data.points, balance + earned * 2, "already multiplied once")


func test_closing_the_ad_early_keeps_the_offer_for_the_next_ad() -> void:
	var root: GameRoot = await _boot_to_run_over_with_reward()
	var run: RunController = root._run_controller
	var earned: int = run.points_credited_this_run
	_press(root, "WatchAdButton")
	_rec.rewarded_opened.emit()
	_rec.rewarded_closed.emit()
	assert_eq(run.points_credited_this_run, earned, "no reward")
	assert_false(_offer(root).visible, "until another ad loads")
	_rec.rewarded_loaded.emit()
	assert_true(_offer(root).visible)


func test_retry_while_the_rewarded_ad_opens_is_ignored() -> void:
	var root: GameRoot = await _boot_to_run_over_with_reward()
	root._hud._on_run_over_timer_timeout()
	var panel: Control = root.find_child("GameOverPanel", true, false) as Control
	assert_true(panel.visible)
	_press(root, "WatchAdButton")
	_press(root, "RestartButton")
	assert_true(panel.visible, "the sheet stays while the ad is on its way")
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER)
	_rec.rewarded_opened.emit()
	_rec.rewarded_closed.emit()
	_press(root, "RestartButton")
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "Retry works once it is done")


## ADS R13 (Copilot, PR #15): the watchdog gave up on the rewarded ad, the player tapped Retry,
## then the ad opened and paid out: the bonus is the first run's, and the new run keeps its own.
func test_a_reward_paid_after_retry_goes_to_its_own_run() -> void:
	var root: GameRoot = await _boot_to_run_over_with_reward()
	var run: RunController = root._run_controller
	var earned: int = run.points_credited_this_run
	var balance: int = run.progression.data.points
	_press(root, "WatchAdButton")
	# The watchdog fired, called directly: awaiting it would render the arena for frames, and a
	# disc texture first built in a headless frame reads back null in test_circle_sprites.
	Ads._on_open_timeout(Ads._break_serial)
	_press(root, "RestartButton")
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "the watchdog let Retry through")
	_rec.rewarded_opened.emit()
	_rec.rewarded_earned.emit()
	_rec.rewarded_closed.emit()
	assert_eq(run.progression.data.points, balance + earned * 2, "the first run's bonus")
	assert_false(run.is_reward_claimed, "the new run can still claim its own")
	assert_eq(run.points_credited_this_run, 0)


## ADS R14 (Copilot, PR #15): Retry's own ad takes up to OPEN_TIMEOUT_SECONDS to open; the
## sheet stays up until the run restarts, so the Run over is never blank.
func test_retry_keeps_the_sheet_while_its_ad_opens() -> void:
	var root: GameRoot = await _boot_to_run_over()
	root._hud._on_run_over_timer_timeout()
	var panel: Control = root.find_child("GameOverPanel", true, false) as Control
	assert_true(panel.visible)
	_press(root, "RestartButton")
	assert_eq(_rec.count("show"), 1)
	assert_true(panel.visible, "the sheet stays while the ad opens")
	_rec.interstitial_opened.emit()
	_rec.interstitial_closed.emit()
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC)
	assert_false(panel.visible, "the restart hides it")
