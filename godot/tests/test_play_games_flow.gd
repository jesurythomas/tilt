## test_play_games_flow.gd
## PORTS: nothing — new file, covers GameRoot's Play Games wiring (PGS R3-R5)
extends GutTest
## Proves the game checks the sign-in at launch, posts a death's score to the mode's board,
## opens boards from the menu and the Run over, holds them while Retry's ad opens, and shows no
## podium in a build without Play Games.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const BOARD_SURVIVAL: String = "CgkI-survival"

var _ads: RecordingAdsBackend = null
var _previous_ads: AdsBackend = null
var _games: RecordingGamesBackend = null
var _previous_games: GamesBackend = null
var _saved_board: Variant = null


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
	_previous_ads = Ads.backend
	_ads = RecordingAdsBackend.new()
	Ads.set_backend(_ads)
	Ads.reset_session()
	_previous_games = PlayGames.backend
	_games = RecordingGamesBackend.new()
	PlayGames.set_backend(_games)
	var setting: String = GamesConfig.LEADERBOARD_SETTINGS[Types.GameMode.CLASSIC]
	_saved_board = ProjectSettings.get_setting(setting, null)
	ProjectSettings.set_setting(setting, BOARD_SURVIVAL)


func after_each() -> void:
	Ads.reset_session()
	Ads.set_backend(_previous_ads)
	Ads.reset_session()
	PlayGames.set_backend(_previous_games)
	ProjectSettings.set_setting(
		GamesConfig.LEADERBOARD_SETTINGS[Types.GameMode.CLASSIC], _saved_board
	)
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, null)
	AudioServer.set_bus_mute(0, false)
	_remove_saves()


func _boot() -> GameRoot:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	return root


## Boots signed in, then dies in a Survival run that scored `score`, with the Run over up.
func _boot_to_run_over(score: int) -> GameRoot:
	var root: GameRoot = await _boot()
	_games.sign_in_checked.emit(true)
	_games.calls.clear()
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, true)
	_ads.consent_finished.emit(true, false)
	_ads.interstitial_loaded.emit()
	root.launch_run(Types.GameMode.CLASSIC)
	root.skip_cinematic()
	root._player.shield_timer = 0.0  # past the cold open's spawn shield
	root._run_controller.scores.stats.score = score
	root._run_controller.lives = 1
	root._run_controller.lose_life()
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER)
	root._hud._on_run_over_timer_timeout()
	return root


func _button(root: GameRoot, button_name: String) -> Button:
	return root.find_child(button_name, true, false) as Button


func test_launch_checks_the_sign_in_after_the_first_frame() -> void:
	await _boot()
	assert_eq(_games.calls, ["check"] as Array[String], "PGS R3")


func test_a_death_posts_its_score_to_the_modes_board() -> void:
	await _boot_to_run_over(4321)
	assert_eq(_games.calls, ["submit %s 4321" % BOARD_SURVIVAL] as Array[String], "PGS R4")


func test_the_run_overs_podium_opens_the_runs_board() -> void:
	var root: GameRoot = await _boot_to_run_over(4321)
	_games.calls.clear()
	var podium: Button = _button(root, "GameOverLeaderboardsButton")
	assert_true(podium.is_visible_in_tree(), "PGS R5")
	podium.pressed.emit()
	assert_eq(_games.calls, ["show " + BOARD_SURVIVAL] as Array[String])


func test_the_menus_podium_opens_every_board() -> void:
	var root: GameRoot = await _boot()
	_games.sign_in_checked.emit(true)
	_games.calls.clear()
	var podium: Button = _button(root, "MenuLeaderboardsButton")
	assert_not_null(podium, "PGS R5")
	podium.pressed.emit()
	assert_eq(_games.calls, ["show "] as Array[String])


func test_the_podium_waits_out_retrys_ad() -> void:
	var root: GameRoot = await _boot_to_run_over(4321)
	_games.calls.clear()
	_button(root, "RestartButton").pressed.emit()
	assert_true(Ads.is_break_pending())
	_button(root, "GameOverLeaderboardsButton").pressed.emit()
	root.open_all_leaderboards()
	assert_eq(_games.calls, [] as Array[String], "ADS R14: nothing over the run about to start")


func test_without_play_games_no_podium_shows() -> void:
	PlayGames.set_backend(GamesBackend.new())
	var root: GameRoot = await _boot_to_run_over(4321)
	assert_false(_button(root, "GameOverLeaderboardsButton").visible)
	root.return_to_menu()
	assert_null(_button(root, "MenuLeaderboardsButton"))
