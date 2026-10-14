# gdlint:disable=max-public-methods
## test_ads.gd
## PORTS: nothing — new file, covers src/core/ads.gd, ad_pacing.gd, ads_config.gd (ADS R1-R6, R9)
extends GutTest
## Proves the ad break: the pacing (ADS R5) and its save, consent before any load, the action
## running exactly once whether the ad closes, fails or never opens, and the sound coming back.

var _rec: RecordingAdsBackend = null
var _previous: AdsBackend = null
var _actions: int = 0
var _other_actions: int = 0


func _remove_save() -> void:
	for path: String in [Ads.SAVE_PATH, SaveStore.corrupt_path_for(Ads.SAVE_PATH)]:
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_actions = 0
	_other_actions = 0
	_previous = Ads.backend
	_remove_save()
	_rec = RecordingAdsBackend.new()
	Ads.set_backend(_rec)
	Ads.reset_session()
	AudioServer.set_bus_mute(0, false)


func after_each() -> void:
	Engine.time_scale = 1.0
	Ads.reset_session()
	Ads.set_backend(_previous)
	_remove_save()
	Ads.reset_session()
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, null)
	AudioServer.set_bus_mute(0, false)


func _count_action() -> void:
	_actions += 1


func _count_other_action() -> void:
	_other_actions += 1


## Consent granted and one ad loaded.
func _ready_with_ad() -> void:
	Ads.start()
	_rec.consent_finished.emit(true, false)
	_rec.interstitial_loaded.emit()


## Enough qualifying games for the pacing to allow an ad.
func _make_due() -> void:
	for _i: int in range(Ads.pacing.games_per_ad):
		Ads.note_run_end(AdPacing.MIN_RUN_SECONDS, false)


## A pacing whose current gap is `games`.
func _pacing(games: int) -> AdPacing:
	var pacing: AdPacing = AdPacing.new(RandomNumberGenerator.new())
	pacing.games_per_ad = games
	return pacing


func test_pacing_is_never_due_before_a_run_ends() -> void:
	assert_false(_pacing(5).is_due())


func test_pacing_draws_each_gap_from_five_to_ten_games() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var pacing: AdPacing = AdPacing.new(rng)
	var seen: Dictionary[int, bool] = {}
	for _i: int in range(200):
		assert_between(pacing.games_per_ad, 5, 10)
		seen[pacing.games_per_ad] = true
		pacing.note_ad_shown()
	assert_eq(seen.size(), 6, "every gap from 5 to 10 comes up")


func test_pacing_is_due_after_the_drawn_number_of_games() -> void:
	var pacing: AdPacing = _pacing(7)
	for _i: int in range(6):
		pacing.note_run_end(21.0, false)
	assert_false(pacing.is_due(), "six games of seven")
	pacing.note_run_end(21.0, false)
	assert_true(pacing.is_due())


func test_pacing_is_due_after_five_minutes_of_play_if_that_comes_first() -> void:
	var pacing: AdPacing = _pacing(10)
	pacing.note_run_end(150.0, false)
	assert_false(pacing.is_due(), "two and a half minutes")
	pacing.note_run_end(150.0, false)
	assert_true(pacing.is_due(), "two games, five minutes of play")


func test_pacing_skips_a_short_run() -> void:
	var pacing: AdPacing = _pacing(5)
	for _i: int in range(4):
		pacing.note_run_end(60.0, false)
	pacing.note_run_end(19.9, false)
	assert_false(pacing.is_due(), "a run under 20 s earns no ad")
	pacing.note_run_end(20.0, false)
	assert_true(pacing.is_due(), "the next longer run does")


func test_pacing_skips_the_players_first_run() -> void:
	var pacing: AdPacing = _pacing(5)
	pacing.note_run_end(400.0, true)
	assert_false(pacing.is_due(), "no ad after the first run ever, however long")
	pacing.note_run_end(20.0, false)
	assert_true(pacing.is_due())


func test_pacing_starts_over_after_an_ad() -> void:
	var pacing: AdPacing = _pacing(5)
	for _i: int in range(5):
		pacing.note_run_end(60.0, false)
	pacing.note_ad_shown()
	assert_eq(pacing.games_since_ad, 0)
	assert_eq(pacing.play_seconds_since_ad, 0.0)
	pacing.note_run_end(60.0, false)
	assert_false(pacing.is_due())


func test_pacing_round_trips_its_counts() -> void:
	var pacing: AdPacing = _pacing(8)
	pacing.note_run_end(42.5, false)
	pacing.note_run_end(10.0, false)
	var loaded: AdPacing = _pacing(5)
	var json: JSON = JSON.new()
	assert_eq(json.parse(JSON.stringify(pacing.to_dict())), OK)
	var data: Dictionary = json.data
	loaded.load_dict(data)
	assert_eq(loaded.games_since_ad, 2)
	assert_almost_eq(loaded.play_seconds_since_ad, 52.5, 0.001)
	assert_eq(loaded.games_per_ad, 8)


func test_pacing_keeps_its_fresh_values_over_a_bad_save() -> void:
	var pacing: AdPacing = _pacing(6)
	pacing.load_dict({"games_since_ad": -3, "play_seconds_since_ad": "x", "games_per_ad": 40})
	assert_eq(pacing.games_since_ad, 0)
	assert_eq(pacing.play_seconds_since_ad, 0.0)
	assert_eq(pacing.games_per_ad, 6)


func test_the_count_carries_across_launches() -> void:
	Ads.note_run_end(30.0, false)
	Ads.note_run_end(30.0, false)
	var gap: int = Ads.pacing.games_per_ad
	Ads.reset_session()
	assert_eq(Ads.pacing.games_since_ad, 2, "as after a relaunch")
	assert_almost_eq(Ads.pacing.play_seconds_since_ad, 60.0, 0.001)
	assert_eq(Ads.pacing.games_per_ad, gap)


func test_an_opened_ad_saves_the_fresh_count() -> void:
	_ready_with_ad()
	_make_due()
	Ads.ad_break(_count_action)
	_rec.interstitial_opened.emit()
	_rec.interstitial_closed.emit()
	Ads.reset_session()
	assert_eq(Ads.pacing.games_since_ad, 0)
	assert_eq(Ads.pacing.play_seconds_since_ad, 0.0)


func test_start_gathers_consent_once_with_the_config() -> void:
	Ads.start()
	Ads.start()
	var expected: String = (
		"consent %s %d" % [AdsConfig.test_device_hashed_id(), AdsConfig.debug_geography()]
	)
	assert_eq(_rec.calls, [expected] as Array[String])


func test_consent_loads_the_interstitial_and_tells_settings() -> void:
	Ads.consent_changed.connect(_count_action)
	Ads.start()
	_rec.consent_finished.emit(true, true)
	Ads.consent_changed.disconnect(_count_action)
	assert_true(Ads.can_request_ads)
	assert_true(Ads.is_privacy_options_required)
	assert_eq(_actions, 1, "consent_changed")
	assert_eq(_rec.count("load " + AdsConfig.interstitial_id()), 1)


func test_without_consent_nothing_loads_and_the_break_runs_at_once() -> void:
	Ads.start()
	_rec.consent_finished.emit(false, false)
	_make_due()
	Ads.ad_break(_count_action)
	assert_eq(_actions, 1)
	assert_eq(_rec.count("load"), 0)
	assert_eq(_rec.count("show"), 0)


func test_a_break_that_is_not_due_runs_the_action_without_an_ad() -> void:
	_ready_with_ad()
	Ads.note_run_end(60.0, false)
	Ads.ad_break(_count_action)
	assert_eq(_actions, 1)
	assert_eq(_rec.count("show"), 0)
	assert_true(Ads.is_ad_loaded, "the ad waits for a later break")


func test_a_break_never_waits_for_a_load() -> void:
	Ads.start()
	_rec.consent_finished.emit(true, false)
	_make_due()
	Ads.ad_break(_count_action)
	assert_eq(_actions, 1)
	assert_eq(_rec.count("show"), 0)


func test_a_due_break_shows_the_ad_and_runs_the_action_when_it_closes() -> void:
	_ready_with_ad()
	_make_due()
	Ads.ad_break(_count_action)
	assert_eq(_rec.count("show"), 1)
	assert_eq(_actions, 0, "the action waits for the ad")
	assert_true(Ads.is_break_pending())
	assert_true(AudioServer.is_bus_mute(0), "the game is silent under the ad")
	_rec.interstitial_opened.emit()
	assert_eq(Ads.pacing.games_since_ad, 0, "an opened ad starts the pacing over")
	_rec.interstitial_closed.emit()
	assert_eq(_actions, 1)
	assert_false(Ads.is_break_pending())
	assert_false(AudioServer.is_bus_mute(0), "sound is back")
	assert_eq(_rec.count("load"), 2, "the next ad loads")


func test_an_ad_that_fails_to_show_still_runs_the_action() -> void:
	_ready_with_ad()
	_make_due()
	Ads.ad_break(_count_action)
	_rec.interstitial_failed_to_show.emit()
	assert_eq(_actions, 1)
	assert_false(AudioServer.is_bus_mute(0))
	assert_eq(Ads.pacing.games_since_ad, Ads.pacing.games_per_ad, "an unseen ad resets nothing")
	assert_eq(_rec.count("load"), 2, "a fresh ad loads")


func test_an_ad_that_never_opens_lets_the_break_go_on() -> void:
	_ready_with_ad()
	_make_due()
	Engine.time_scale = 20.0
	Ads.ad_break(_count_action)
	await get_tree().create_timer(Ads.OPEN_TIMEOUT_SECONDS + 0.5).timeout
	Engine.time_scale = 1.0
	assert_eq(_actions, 1, "the watchdog runs the action")
	assert_false(AudioServer.is_bus_mute(0))
	_rec.interstitial_opened.emit()
	_rec.interstitial_closed.emit()
	assert_eq(_actions, 1, "a late ad does not run it twice")


func test_an_open_ad_holds_the_action_past_the_watchdog() -> void:
	_ready_with_ad()
	_make_due()
	Engine.time_scale = 20.0
	Ads.ad_break(_count_action)
	_rec.interstitial_opened.emit()
	await get_tree().create_timer(Ads.OPEN_TIMEOUT_SECONDS + 0.5).timeout
	Engine.time_scale = 1.0
	assert_eq(_actions, 0, "the player is still watching")
	_rec.interstitial_closed.emit()
	assert_eq(_actions, 1)


func test_a_second_break_while_an_ad_opens_is_dropped() -> void:
	_ready_with_ad()
	_make_due()
	Ads.ad_break(_count_action)
	Ads.ad_break(_count_other_action)
	_rec.interstitial_closed.emit()
	assert_eq(_actions, 1)
	assert_eq(_other_actions, 0)
	assert_eq(_rec.count("show"), 1)


func test_a_failed_load_retries_at_the_next_run_end() -> void:
	Ads.start()
	_rec.consent_finished.emit(true, false)
	Ads.note_run_end(5.0, false)
	assert_eq(_rec.count("load"), 1, "no second load while one is in flight")
	_rec.interstitial_failed_to_load.emit()
	Ads.note_run_end(5.0, false)
	assert_eq(_rec.count("load"), 2)


func test_every_break_skips_the_pacing_but_not_consent_or_the_load() -> void:
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, true)
	Ads.start()
	_rec.consent_finished.emit(true, false)
	assert_false(Ads.is_break_due(), "still needs a loaded ad")
	_rec.interstitial_loaded.emit()
	assert_true(Ads.is_break_due(), "no games needed")


func test_sound_muted_before_the_ad_stays_muted() -> void:
	AudioServer.set_bus_mute(0, true)
	_ready_with_ad()
	_make_due()
	Ads.ad_break(_count_action)
	_rec.interstitial_closed.emit()
	assert_true(AudioServer.is_bus_mute(0))


func test_privacy_options_go_to_the_backend() -> void:
	Ads.show_privacy_options()
	assert_eq(_rec.calls, ["privacy"] as Array[String])


## ADS R11 (Copilot, PR #15): an ad loaded under the old consent is not shown under the new.
func test_a_consent_change_drops_the_loaded_ads_and_loads_again() -> void:
	_ready_with_ad()
	_rec.rewarded_loaded.emit()
	_make_due()
	_rec.consent_finished.emit(true, true)
	assert_false(Ads.is_break_due(), "the old interstitial is gone")
	assert_false(Ads.is_reward_ready(), "the old rewarded ad is gone")
	assert_eq(_rec.count("load " + AdsConfig.interstitial_id()), 2, "a fresh one loads")
	assert_eq(_rec.count("reward_load " + AdsConfig.rewarded_id()), 2)
	_rec.interstitial_loaded.emit()
	assert_true(Ads.is_break_due(), "the fresh one shows")


func test_withdrawn_consent_drops_the_loaded_ads_and_loads_nothing() -> void:
	_ready_with_ad()
	_rec.rewarded_loaded.emit()
	_rec.consent_finished.emit(false, true)
	assert_false(Ads.is_ad_loaded)
	assert_false(Ads.is_rewarded_loaded)
	assert_eq(_rec.count("load"), 1, "only the load from the first consent")
	assert_eq(_rec.count("reward_load"), 1)


func test_config_uses_a_set_id_and_falls_back_to_googles_test_id() -> void:
	var saved: Variant = ProjectSettings.get_setting(AdsConfig.INTERSTITIAL_ID_SETTING)
	ProjectSettings.set_setting(AdsConfig.INTERSTITIAL_ID_SETTING, "")
	assert_eq(AdsConfig.interstitial_id(), AdsConfig.TEST_INTERSTITIAL_ID)
	ProjectSettings.set_setting(AdsConfig.INTERSTITIAL_ID_SETTING, "ca-app-pub-1/2")
	assert_eq(AdsConfig.interstitial_id(), "ca-app-pub-1/2")
	ProjectSettings.set_setting(AdsConfig.INTERSTITIAL_ID_SETTING, saved)


func test_off_android_the_autoload_runs_on_the_null_backend() -> void:
	assert_false(Engine.has_singleton(AndroidAdsBackend.SINGLETON))
	assert_false(_previous is AndroidAdsBackend)


## Consent granted and one rewarded ad loaded.
func _ready_with_reward() -> void:
	Ads.start()
	_rec.consent_finished.emit(true, false)
	_rec.rewarded_loaded.emit()


func test_consent_loads_a_rewarded_ad_too() -> void:
	Ads.start()
	_rec.consent_finished.emit(true, false)
	assert_eq(_rec.count("reward_load " + AdsConfig.rewarded_id()), 1)
	assert_false(Ads.is_reward_ready(), "not before it loads")
	_rec.rewarded_loaded.emit()
	assert_true(Ads.is_reward_ready())


func test_a_rewarded_ad_rewards_once_then_runs_on_done() -> void:
	_ready_with_reward()
	Ads.show_rewarded(_count_other_action, _count_action)
	assert_eq(_rec.count("reward_show"), 1)
	assert_true(AudioServer.is_bus_mute(0), "the game is silent under the ad")
	assert_false(Ads.is_reward_ready(), "used")
	_rec.rewarded_opened.emit()
	_rec.rewarded_earned.emit()
	_rec.rewarded_earned.emit()
	assert_eq(_other_actions, 1, "the reward, once")
	assert_eq(_actions, 0, "on_done waits for the close")
	_rec.rewarded_closed.emit()
	assert_eq(_actions, 1)
	assert_false(AudioServer.is_bus_mute(0), "sound is back")
	assert_eq(_rec.count("reward_load"), 2, "the next rewarded ad loads")


func test_a_rewarded_ad_closed_early_gives_nothing() -> void:
	_ready_with_reward()
	Ads.show_rewarded(_count_other_action, _count_action)
	_rec.rewarded_opened.emit()
	_rec.rewarded_closed.emit()
	assert_eq(_other_actions, 0)
	assert_eq(_actions, 1)


func test_a_rewarded_ad_that_fails_to_show_gives_nothing() -> void:
	_ready_with_reward()
	Ads.show_rewarded(_count_other_action, _count_action)
	_rec.rewarded_failed_to_show.emit()
	_rec.rewarded_earned.emit()
	assert_eq(_other_actions, 0)
	assert_eq(_actions, 1)
	assert_false(AudioServer.is_bus_mute(0))


func test_a_rewarded_ad_not_ready_runs_on_done_at_once() -> void:
	Ads.start()
	_rec.consent_finished.emit(true, false)
	Ads.show_rewarded(_count_other_action, _count_action)
	assert_eq(_actions, 1)
	assert_eq(_rec.count("reward_show"), 0)


func test_a_rewarded_ad_counts_as_the_ad_for_the_pacing() -> void:
	_ready_with_reward()
	_rec.interstitial_loaded.emit()
	_make_due()
	Ads.show_rewarded(_count_other_action, _count_action)
	_rec.rewarded_opened.emit()
	_rec.rewarded_closed.emit()
	assert_eq(Ads.pacing.games_since_ad, 0)
	Ads.ad_break(_count_action)
	assert_eq(_rec.count("show"), 0, "no interstitial right after it")
	assert_eq(_actions, 2)


## ADS R9 (user: "if they manually select the 3x points to view ads, reset the count").
func test_choosing_the_rewarded_ad_resets_the_pacing_at_the_tap() -> void:
	_ready_with_reward()
	_rec.interstitial_loaded.emit()
	_make_due()
	Ads.note_run_end(AdPacing.PLAY_SECONDS_PER_AD, false)
	Ads.show_rewarded(_count_other_action, _count_action)
	assert_eq(Ads.pacing.games_since_ad, 0, "before the ad opens")
	assert_eq(Ads.pacing.play_seconds_since_ad, 0.0)
	assert_eq(SaveStore.read_int(SaveStore.load_dict(Ads.SAVE_PATH), "games_since_ad", -1), 0)
	_rec.rewarded_failed_to_show.emit()
	Ads.ad_break(_count_action)
	assert_eq(_rec.count("show"), 0, "no interstitial, even though the ad never showed")
	assert_eq(_actions, 2)


func test_the_rewarded_ad_opening_does_not_restart_the_pacing_again() -> void:
	_ready_with_reward()
	Ads.show_rewarded(_count_other_action, _count_action)
	var gap: int = Ads.pacing.games_per_ad
	Ads.note_run_end(AdPacing.MIN_RUN_SECONDS, false)
	_rec.rewarded_opened.emit()
	assert_eq(Ads.pacing.games_since_ad, 1, "counted from the tap")
	assert_eq(Ads.pacing.games_per_ad, gap, "one gap drawn")


func test_a_rewarded_ad_not_ready_leaves_the_pacing_alone() -> void:
	Ads.start()
	_rec.consent_finished.emit(true, false)
	_make_due()
	Ads.show_rewarded(_count_other_action, _count_action)
	assert_true(Ads.pacing.is_due(), "no ad was chosen")


func test_a_late_rewarded_ad_still_rewards_after_the_watchdog() -> void:
	_ready_with_reward()
	Engine.time_scale = 20.0
	Ads.show_rewarded(_count_other_action, _count_action)
	await get_tree().create_timer(Ads.OPEN_TIMEOUT_SECONDS + 0.5).timeout
	Engine.time_scale = 1.0
	assert_eq(_actions, 1, "the watchdog let the game go on")
	_rec.rewarded_opened.emit()
	_rec.rewarded_earned.emit()
	_rec.rewarded_closed.emit()
	assert_eq(_other_actions, 1, "a reward the player earned is still given")
	assert_eq(_actions, 1, "on_done ran once")


func test_a_break_while_a_rewarded_ad_opens_is_dropped() -> void:
	_ready_with_reward()
	_rec.interstitial_loaded.emit()
	_make_due()
	Ads.show_rewarded(_count_other_action, _count_action)
	Ads.ad_break(_count_action)
	assert_eq(_rec.count("show"), 0)
	assert_eq(_actions, 0)


func test_rewarded_changed_tells_the_run_over() -> void:
	watch_signals(Ads)
	_ready_with_reward()
	assert_signal_emitted(Ads, "rewarded_changed")


## ADS R12 (Copilot, PR #15): the watchdog lets the game go on, but the ad stays out until its
## own close; no other ad shows meanwhile, so its late close cannot end a newer break.
func test_a_timed_out_ad_holds_off_other_ads_until_it_ends() -> void:
	_ready_with_ad()
	_make_due()
	Engine.time_scale = 20.0
	Ads.ad_break(_count_action)
	await get_tree().create_timer(Ads.OPEN_TIMEOUT_SECONDS + 0.5).timeout
	Engine.time_scale = 1.0
	assert_eq(_actions, 1, "the watchdog runs the action")
	_rec.interstitial_loaded.emit()
	_rec.rewarded_loaded.emit()
	assert_false(Ads.is_break_due(), "the first ad is still out")
	assert_false(Ads.is_reward_ready())
	Ads.ad_break(_count_other_action)
	assert_eq(_other_actions, 1, "the next break goes on without an ad")
	assert_eq(_rec.count("show"), 1)
	_rec.interstitial_opened.emit()
	_rec.interstitial_closed.emit()
	assert_eq(_actions, 1, "the late close runs nothing")
	assert_eq(_other_actions, 1)
	_make_due()  # its late opening started the pacing over
	assert_true(Ads.is_break_due(), "ads show again once it has ended")


func test_an_interstitial_callback_does_not_end_a_rewarded_show() -> void:
	_ready_with_reward()
	Ads.show_rewarded(_count_other_action, _count_action)
	_rec.interstitial_opened.emit()
	_rec.interstitial_closed.emit()
	_rec.interstitial_failed_to_show.emit()
	assert_eq(_actions, 0, "on_done waits for its own ad")
	assert_true(Ads.is_break_pending())
	_rec.rewarded_closed.emit()
	assert_eq(_actions, 1)
