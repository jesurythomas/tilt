## test_play_games.gd
## PORTS: nothing — new file, covers src/core/play_games.gd and games_config.gd (PGS R2-R5, R7)
extends GutTest
## Proves the launch's sign-in check, a run's score going to its mode's board only when it
## should, a board asked for while signed out waiting for a sign-in, and the config's IDs.

const BOARD_SURVIVAL: String = "CgkI-survival"
const BOARD_CORRIDOR: String = "CgkI-corridor"

var _rec: RecordingGamesBackend = null
var _previous: GamesBackend = null
var _saved: Dictionary[String, Variant] = {}


func before_each() -> void:
	_saved.clear()
	for setting: String in _settings():
		_saved[setting] = ProjectSettings.get_setting(setting, null)
	ProjectSettings.set_setting(
		GamesConfig.LEADERBOARD_SETTINGS[Types.GameMode.CLASSIC], BOARD_SURVIVAL
	)
	ProjectSettings.set_setting(
		GamesConfig.LEADERBOARD_SETTINGS[Types.GameMode.GAUNTLET], BOARD_CORRIDOR
	)
	ProjectSettings.set_setting(GamesConfig.LEADERBOARD_SETTINGS[Types.GameMode.CODE_RED], "")
	_previous = PlayGames.backend
	_rec = RecordingGamesBackend.new()
	PlayGames.set_backend(_rec)


func after_each() -> void:
	PlayGames.set_backend(_previous)
	for setting: String in _settings():
		ProjectSettings.set_setting(setting, _saved[setting])


func _settings() -> Array[String]:
	var settings: Array[String] = [GamesConfig.PROJECT_ID_SETTING]
	settings.append_array(GamesConfig.LEADERBOARD_SETTINGS.values())
	return settings


## Launch check answered: signed in.
func _signed_in() -> void:
	PlayGames.start()
	_rec.sign_in_checked.emit(true)
	_rec.calls.clear()


func test_the_null_backend_has_no_play_games() -> void:
	PlayGames.set_backend(GamesBackend.new())
	assert_false(PlayGames.is_available(), "desktop, headless and tests show no buttons")


func test_start_checks_the_sign_in_once() -> void:
	PlayGames.start()
	PlayGames.start()
	assert_eq(_rec.calls, ["check"] as Array[String])
	assert_false(PlayGames.is_signed_in, "not until the check answers")
	_rec.sign_in_checked.emit(true)
	assert_true(PlayGames.is_signed_in)


func test_start_without_play_games_does_nothing() -> void:
	var null_backend: GamesBackend = GamesBackend.new()
	PlayGames.set_backend(null_backend)
	PlayGames.start()
	assert_false(PlayGames.is_signed_in)


func test_a_signed_in_run_posts_to_its_modes_board() -> void:
	_signed_in()
	PlayGames.submit_run(Types.GameMode.CLASSIC, 1459665)
	PlayGames.submit_run(Types.GameMode.GAUNTLET, 42)
	assert_eq(
		_rec.calls,
		["submit %s 1459665" % BOARD_SURVIVAL, "submit %s 42" % BOARD_CORRIDOR] as Array[String]
	)


func test_a_score_above_32_bits_is_posted_whole() -> void:
	_signed_in()
	PlayGames.submit_run(Types.GameMode.CLASSIC, 5_000_000_000)
	assert_eq(_rec.calls, ["submit %s 5000000000" % BOARD_SURVIVAL] as Array[String])


func test_nothing_is_posted_while_signed_out() -> void:
	PlayGames.start()
	_rec.sign_in_checked.emit(false)
	_rec.calls.clear()
	PlayGames.submit_run(Types.GameMode.CLASSIC, 500)
	assert_eq(_rec.calls, [] as Array[String], "PGS R4: nothing queued while signed out")


func test_a_zero_score_or_a_mode_without_a_board_posts_nothing() -> void:
	_signed_in()
	PlayGames.submit_run(Types.GameMode.CLASSIC, 0)
	PlayGames.submit_run(Types.GameMode.CODE_RED, 900)
	assert_eq(_rec.calls, [] as Array[String])


func test_a_signed_in_player_opens_the_board_at_once() -> void:
	_signed_in()
	PlayGames.show_leaderboard(Types.GameMode.GAUNTLET)
	PlayGames.show_all_leaderboards()
	assert_eq(_rec.calls, ["show " + BOARD_CORRIDOR, "show "] as Array[String])


func test_a_mode_without_a_board_opens_every_board() -> void:
	_signed_in()
	PlayGames.show_leaderboard(Types.GameMode.CODE_RED)
	assert_eq(_rec.calls, ["show "] as Array[String])


func test_a_signed_out_tap_signs_in_then_opens_the_board() -> void:
	PlayGames.start()
	_rec.sign_in_checked.emit(false)
	_rec.calls.clear()
	PlayGames.show_leaderboard(Types.GameMode.CLASSIC)
	assert_eq(_rec.calls, ["sign_in"] as Array[String], "PGS R3: asks first")
	_rec.sign_in_checked.emit(true)
	assert_eq(_rec.calls, ["sign_in", "show " + BOARD_SURVIVAL] as Array[String])
	assert_true(PlayGames.is_signed_in)


func test_a_failed_sign_in_opens_nothing_and_asks_once() -> void:
	PlayGames.start()
	_rec.sign_in_checked.emit(false)
	_rec.calls.clear()
	PlayGames.show_all_leaderboards()
	PlayGames.show_all_leaderboards()
	assert_eq(_rec.calls, ["sign_in"] as Array[String], "a second tap waits on the first")
	_rec.sign_in_checked.emit(false)
	assert_eq(_rec.calls, ["sign_in"] as Array[String], "cancelled: no board, no second ask")
	PlayGames.show_all_leaderboards()
	assert_eq(_rec.calls, ["sign_in", "sign_in"] as Array[String], "a later tap asks again")


func test_a_tap_during_the_launch_check_waits_for_it() -> void:
	PlayGames.start()
	PlayGames.show_all_leaderboards()
	assert_eq(_rec.calls, ["check"] as Array[String], "no sign-in while the check is out")
	_rec.sign_in_checked.emit(true)
	assert_eq(_rec.calls, ["check", "show "] as Array[String], "the check signed in")


func test_a_tap_during_a_failed_launch_check_then_asks() -> void:
	PlayGames.start()
	PlayGames.show_leaderboard(Types.GameMode.CLASSIC)
	_rec.sign_in_checked.emit(false)
	assert_eq(_rec.calls, ["check", "sign_in"] as Array[String])
	_rec.sign_in_checked.emit(true)
	assert_eq(_rec.calls, ["check", "sign_in", "show " + BOARD_SURVIVAL] as Array[String])


func test_signing_out_in_play_games_stops_the_posts() -> void:
	_signed_in()
	_rec.signed_out.emit()
	assert_false(PlayGames.is_signed_in, "PGS R7")
	PlayGames.submit_run(Types.GameMode.CLASSIC, 500)
	PlayGames.show_all_leaderboards()
	assert_eq(_rec.calls, ["sign_in"] as Array[String], "the next tap signs in again")


func test_config_is_off_until_the_project_id_is_digits() -> void:
	ProjectSettings.set_setting(GamesConfig.PROJECT_ID_SETTING, "")
	assert_false(GamesConfig.is_configured(), "blank: exports leave Play Games out")
	ProjectSettings.set_setting(GamesConfig.PROJECT_ID_SETTING, "+73436178")
	assert_false(GamesConfig.is_configured())
	ProjectSettings.set_setting(GamesConfig.PROJECT_ID_SETTING, "7343 6178")
	assert_false(GamesConfig.is_configured())
	ProjectSettings.set_setting(GamesConfig.PROJECT_ID_SETTING, " 734361789228 ")
	assert_true(GamesConfig.is_configured(), "trimmed")
	assert_eq(GamesConfig.project_id(), "734361789228")


func test_the_manifest_app_id_escapes_its_first_digit() -> void:
	ProjectSettings.set_setting(GamesConfig.PROJECT_ID_SETTING, "734361789228")
	assert_eq(GamesConfig.manifest_app_id(), "\\u0037" + "34361789228", "PGS R2: \\u0037 is 7")


func test_each_mode_has_its_own_board_setting() -> void:
	var settings: Array[String] = GamesConfig.LEADERBOARD_SETTINGS.values()
	assert_eq(settings.size(), Types.GameMode.size(), "one board per mode (MVP R2)")
	for mode: Types.GameMode in Types.GameMode.values():
		assert_true(GamesConfig.LEADERBOARD_SETTINGS.has(mode))
