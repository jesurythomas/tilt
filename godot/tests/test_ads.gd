# gdlint:disable=max-public-methods
## test_ads.gd
## PORTS: nothing — new file, covers src/core/ads.gd, ad_pacing.gd, ads_config.gd (ADS R1-R4)
extends GutTest
## Proves the ad break: the pacing (MVP R1), consent before any load, the action running exactly
## once whether the ad closes, fails or never opens, and the sound coming back.

var _rec: RecordingAdsBackend = null
var _previous: AdsBackend = null
var _saved_clock: Callable = Callable()
## The fake clock Ads reads, in seconds.
var _t: float = 0.0
var _actions: int = 0
var _other_actions: int = 0


func before_each() -> void:
	_t = 0.0
	_actions = 0
	_other_actions = 0
	_previous = Ads.backend
	_saved_clock = Ads.clock
	Ads.clock = func() -> float: return _t
	_rec = RecordingAdsBackend.new()
	Ads.set_backend(_rec)
	Ads.reset_session()
	AudioServer.set_bus_mute(0, false)


func after_each() -> void:
	Engine.time_scale = 1.0
	Ads.reset_session()
	Ads.set_backend(_previous)
	Ads.clock = _saved_clock
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


## Enough qualifying runs and time for the pacing to allow an ad.
func _make_due() -> void:
	for _i: int in range(AdPacing.RUNS_PER_AD):
		Ads.note_run_end(AdPacing.MIN_RUN_SECONDS, false)
	_t = AdPacing.MIN_SECONDS_BETWEEN_ADS


func test_pacing_is_never_due_before_a_run_ends() -> void:
	var pacing: AdPacing = AdPacing.new(0.0)
	assert_false(pacing.is_due(10000.0))


func test_pacing_needs_three_runs_and_three_minutes() -> void:
	var pacing: AdPacing = AdPacing.new(0.0)
	pacing.note_run_end(20.0, false)
	pacing.note_run_end(20.0, false)
	assert_false(pacing.is_due(1000.0), "two runs are not enough")
	pacing.note_run_end(20.0, false)
	assert_true(pacing.is_due(180.0))
	assert_false(pacing.is_due(179.9), "not in the first three minutes of a launch")


func test_pacing_skips_a_short_run() -> void:
	var pacing: AdPacing = AdPacing.new(0.0)
	pacing.note_run_end(60.0, false)
	pacing.note_run_end(60.0, false)
	pacing.note_run_end(19.9, false)
	assert_false(pacing.is_due(1000.0), "a run under 20 s earns no ad")
	pacing.note_run_end(20.0, false)
	assert_true(pacing.is_due(1000.0))


func test_pacing_skips_the_players_first_run() -> void:
	var pacing: AdPacing = AdPacing.new(0.0)
	pacing.note_run_end(60.0, false)
	pacing.note_run_end(60.0, false)
	pacing.note_run_end(60.0, true)
	assert_false(pacing.is_due(1000.0), "no ad after the first run ever")
	pacing.note_run_end(60.0, false)
	assert_true(pacing.is_due(1000.0))


func test_pacing_starts_over_after_an_ad() -> void:
	var pacing: AdPacing = AdPacing.new(0.0)
	for _i: int in range(3):
		pacing.note_run_end(60.0, false)
	pacing.note_ad_shown(200.0)
	assert_eq(pacing.runs_since_ad, 0)
	for _i: int in range(3):
		pacing.note_run_end(60.0, false)
	assert_false(pacing.is_due(379.9), "three minutes after the last ad")
	assert_true(pacing.is_due(380.0))


func test_start_gathers_consent_once_with_the_config() -> void:
	Ads.start()
	Ads.start()
	assert_eq(_rec.calls, ["consent  0"] as Array[String])


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
	_t = 1000.0
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
	assert_eq(Ads.pacing.runs_since_ad, 0, "an opened ad starts the pacing over")
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
	assert_eq(Ads.pacing.runs_since_ad, AdPacing.RUNS_PER_AD, "an unseen ad resets nothing")
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
	assert_true(Ads.is_break_due(), "no runs or minutes needed")


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
