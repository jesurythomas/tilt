## ads.gd
## PORTS: nothing — new file (rulings ADS R1-R6, R9,
## docs/superpowers/plans/2026-10-13-in-game-ads.md)
# PORT-NOTE: no `class_name`, against CONVENTIONS §2. An autoload script cannot
# carry one (same as Telemetry, Haptics, Log and GameEvents).
extends Node
## Interstitial ads at the one ad break, the rewarded ad the Run over offers, and the consent
## they need. Autoloaded as `Ads`.
##
## The break is leaving the Run over: GameRoot routes Retry and Menu through `ad_break`, and its
## "Watch ad · 3× points" through `show_rewarded`. No sim class calls this; GameRoot does, as it
## does Telemetry. Swapping the ad vendor means replacing `backend`; nothing else names one.

## Consent was gathered or changed; Settings shows or hides its Ad privacy row.
signal consent_changed
## A rewarded ad became ready, or went (shown, failed or no longer allowed); the Run over shows
## or hides its offer.
signal rewarded_changed

## DIVERGENCE(ADS R12): which ad is out — shown, and not yet closed or failed.
enum Showing { NONE, INTERSTITIAL, REWARDED }

## DIVERGENCE(ADS R2): seconds an ad may take to open before the break goes on without it.
const OPEN_TIMEOUT_SECONDS: float = 4.0
## DIVERGENCE(ADS R12): seconds after which an ad that never opened, closed or failed stops
## holding off the next ones (a lost callback would otherwise do so for the session).
const GIVE_UP_SECONDS: float = 30.0
## DIVERGENCE(ADS R5): the pacing's counts, kept across launches.
const SAVE_PATH: String = "user://peril_point_ads.json"

## Where ad calls go: the PerilAds plugin on Android, else the null backend.
var backend: AdsBackend = null
## When the break may show an ad.
var pacing: AdPacing = null
## Draws each pacing gap. Tests seed it.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## True once consent allows ad requests.
var can_request_ads: bool = false
## True when UMP asks for a privacy options entry point (Settings → Ad privacy).
var is_privacy_options_required: bool = false
## True while a loaded interstitial waits for a break.
var is_ad_loaded: bool = false
## DIVERGENCE(ADS R6): true while a loaded rewarded ad waits for the Run over's offer.
var is_rewarded_loaded: bool = false

var _is_started: bool = false
var _is_loading: bool = false
var _is_loading_rewarded: bool = false
## The break's action (or a rewarded ad's `on_done`), held while its ad opens and shows.
var _pending: Callable = Callable()
## The shown rewarded ad's `on_reward`, run once if the player earns it.
var _on_reward: Callable = Callable()
## True from `show` until the ad opens or the break ends; the watchdog acts only then.
var _is_awaiting_open: bool = false
## DIVERGENCE(ADS R12): the ad shown, kept past the watchdog until its own close or failure,
## so a late one cannot end a newer break; no other ad shows meanwhile.
var _showing: Showing = Showing.NONE
## True once the ad out has opened; GIVE_UP_SECONDS waits only on one that has not.
var _is_open: bool = false
## Numbers each break, so a watchdog left over from an earlier one does nothing.
var _break_serial: int = 0
var _is_muting: bool = false
var _was_master_muted: bool = false


func _ready() -> void:
	# Built here, not by a static factory on AndroidAdsBackend: a static func that calls its own
	# class's new() kept every script (GUT's too) alive at exit, which tools/run_tests.sh fails on.
	if Engine.has_singleton(AndroidAdsBackend.SINGLETON):
		set_backend(AndroidAdsBackend.new(Engine.get_singleton(AndroidAdsBackend.SINGLETON)))
	else:
		set_backend(AdsBackend.new())
	rng.randomize()
	reset_session()


## Swaps the backend (tests use a recording one) and listens to it.
func set_backend(next: AdsBackend) -> void:
	if backend != null:
		backend.consent_finished.disconnect(_on_consent_finished)
		backend.interstitial_loaded.disconnect(_on_interstitial_loaded)
		backend.interstitial_failed_to_load.disconnect(_on_interstitial_failed_to_load)
		backend.interstitial_opened.disconnect(_on_interstitial_opened)
		backend.interstitial_closed.disconnect(_on_interstitial_ended)
		backend.interstitial_failed_to_show.disconnect(_on_interstitial_ended)
		backend.rewarded_loaded.disconnect(_on_rewarded_loaded)
		backend.rewarded_failed_to_load.disconnect(_on_rewarded_failed_to_load)
		backend.rewarded_opened.disconnect(_on_rewarded_opened)
		backend.rewarded_earned.disconnect(_on_rewarded_earned)
		backend.rewarded_closed.disconnect(_on_rewarded_closed)
		backend.rewarded_failed_to_show.disconnect(_on_rewarded_failed_to_show)
	backend = next
	backend.consent_finished.connect(_on_consent_finished)
	backend.interstitial_loaded.connect(_on_interstitial_loaded)
	backend.interstitial_failed_to_load.connect(_on_interstitial_failed_to_load)
	backend.interstitial_opened.connect(_on_interstitial_opened)
	backend.interstitial_closed.connect(_on_interstitial_ended)
	backend.interstitial_failed_to_show.connect(_on_interstitial_ended)
	backend.rewarded_loaded.connect(_on_rewarded_loaded)
	backend.rewarded_failed_to_load.connect(_on_rewarded_failed_to_load)
	backend.rewarded_opened.connect(_on_rewarded_opened)
	backend.rewarded_earned.connect(_on_rewarded_earned)
	backend.rewarded_closed.connect(_on_rewarded_closed)
	backend.rewarded_failed_to_show.connect(_on_rewarded_failed_to_show)


## Forgets consent, the loaded ads and any break, and reloads the pacing's save, as at launch.
func reset_session() -> void:
	_restore_sound()
	pacing = AdPacing.new(rng)
	pacing.load_dict(SaveStore.load_dict(SAVE_PATH))
	can_request_ads = false
	is_privacy_options_required = false
	is_ad_loaded = false
	is_rewarded_loaded = false
	_is_started = false
	_is_loading = false
	_is_loading_rewarded = false
	_pending = Callable()
	_on_reward = Callable()
	_is_awaiting_open = false
	_showing = Showing.NONE
	_is_open = false
	_break_serial += 1


## Gathers consent, once per launch. GameRoot calls it after the first frame.
func start() -> void:
	if _is_started:
		return
	_is_started = true
	backend.gather_consent(AdsConfig.test_device_hashed_id(), AdsConfig.debug_geography())


## A run ended after `seconds`: counts it for the pacing and makes sure ads are on their way.
func note_run_end(seconds: float, was_first_run: bool) -> void:
	pacing.note_run_end(seconds, was_first_run)
	_save_pacing()
	_request_load()


## True when a break now would show an ad: consent, a loaded ad, no ad still out (ADS R12),
## and the pacing (ADS R5).
func is_break_due() -> bool:
	if not can_request_ads or not is_ad_loaded or _showing != Showing.NONE:
		return false
	return AdsConfig.is_every_break() or pacing.is_due()


## DIVERGENCE(ADS R2): the ad break. Shows an interstitial when one is due and runs `action`
## when it closes (or fails, or has not opened after OPEN_TIMEOUT_SECONDS); otherwise runs
## `action` at once. A break while another ad is opening is dropped.
func ad_break(action: Callable) -> void:
	if _pending.is_valid():
		return
	if not is_break_due():
		action.call()
		return
	is_ad_loaded = false
	_begin_show(action, Showing.INTERSTITIAL)
	Log.info("ads: break shows an interstitial")
	backend.show_interstitial()


## DIVERGENCE(ADS R6): true when the Run over may offer a rewarded ad: consent, a loaded one,
## and no other ad on its way or still out (ADS R12).
func is_reward_ready() -> bool:
	return can_request_ads and is_rewarded_loaded and _showing == Showing.NONE


## DIVERGENCE(ADS R6): shows the rewarded ad. `on_reward` runs once if the player earns it (even
## after the watchdog gave up on the ad); `on_done` runs when it closes or fails, or when it has
## not opened after OPEN_TIMEOUT_SECONDS. Not ready: `on_done` runs at once.
func show_rewarded(on_reward: Callable, on_done: Callable) -> void:
	if not is_reward_ready():
		on_done.call()
		return
	is_rewarded_loaded = false
	_on_reward = on_reward
	# DIVERGENCE(ADS R9, user 2026-10-14: "if they manually select the 3x points to view ads,
	# reset the count"): choosing the rewarded ad starts the pacing over at the tap, whether
	# or not the ad then opens, so no interstitial follows it closely (ADS R6 reset it only
	# once the ad opened).
	_reset_pacing()
	_begin_show(on_done, Showing.REWARDED)
	Log.info("ads: showing a rewarded ad")
	backend.show_rewarded()


## True while a break or a rewarded ad waits on its ad.
func is_break_pending() -> bool:
	return _pending.is_valid()


## Settings → Ad privacy · Manage: UMP's privacy options form.
func show_privacy_options() -> void:
	backend.show_privacy_options()


## Holds `action` until the ad has shown and closed; mutes the game and starts the watchdog.
## The Run over's offer hides: no other ad is ready while this one is out.
func _begin_show(action: Callable, showing: Showing) -> void:
	_pending = action
	_showing = showing
	_is_open = false
	_mute_sound()
	_break_serial += 1
	_is_awaiting_open = true
	# Bound to a number, not the timer: a timer bound into its own signal is a cycle that leaks.
	get_tree().create_timer(OPEN_TIMEOUT_SECONDS).timeout.connect(
		_on_open_timeout.bind(_break_serial)
	)
	get_tree().create_timer(GIVE_UP_SECONDS).timeout.connect(_on_give_up.bind(_break_serial))
	rewarded_changed.emit()


## Loads whichever of the interstitial and the rewarded ad is missing.
func _request_load() -> void:
	if not can_request_ads or _pending.is_valid():
		return
	if not is_ad_loaded and not _is_loading:
		_is_loading = true
		backend.load_interstitial(AdsConfig.interstitial_id())
	if not is_rewarded_loaded and not _is_loading_rewarded:
		_is_loading_rewarded = true
		backend.load_rewarded(AdsConfig.rewarded_id())


## DIVERGENCE(ADS R11): consent was gathered, or the privacy options form closed. An ad loaded
## (or loading) under the old answer is dropped — the plugin drops its own — and ads load
## again only if the new answer allows it.
func _on_consent_finished(can_request: bool, is_privacy_required: bool) -> void:
	can_request_ads = can_request
	is_privacy_options_required = is_privacy_required
	is_ad_loaded = false
	is_rewarded_loaded = false
	_is_loading = false
	_is_loading_rewarded = false
	consent_changed.emit()
	rewarded_changed.emit()
	_request_load()


func _on_interstitial_loaded() -> void:
	_is_loading = false
	is_ad_loaded = true


func _on_interstitial_failed_to_load() -> void:
	_is_loading = false
	is_ad_loaded = false


## An interstitial covers the game: the watchdog stands down and the pacing starts over.
func _on_interstitial_opened() -> void:
	if _showing != Showing.INTERSTITIAL:
		return
	_is_open = true
	_is_awaiting_open = false
	_reset_pacing()
	Log.info("ads: interstitial opened")


func _on_rewarded_loaded() -> void:
	_is_loading_rewarded = false
	is_rewarded_loaded = true
	rewarded_changed.emit()


func _on_rewarded_failed_to_load() -> void:
	_is_loading_rewarded = false
	is_rewarded_loaded = false
	rewarded_changed.emit()


## The interstitial closed or could not show. DIVERGENCE(ADS R12): only the one shown ends.
func _on_interstitial_ended() -> void:
	if _showing != Showing.INTERSTITIAL:
		return
	_showing = Showing.NONE
	_finish_break()


## The rewarded ad covers the game: the watchdog stands down. The pacing started over at the
## tap (ADS R9).
func _on_rewarded_opened() -> void:
	if _showing != Showing.REWARDED:
		return
	_is_open = true
	_is_awaiting_open = false
	Log.info("ads: rewarded ad opened")


func _on_rewarded_earned() -> void:
	var reward: Callable = _on_reward
	_on_reward = Callable()
	if reward.is_valid():
		Log.info("ads: reward earned")
		reward.call()


## The rewarded ad closed. DIVERGENCE(ADS R12): only the one shown ends.
func _on_rewarded_closed() -> void:
	if _showing != Showing.REWARDED:
		return
	_showing = Showing.NONE
	_finish_break()


func _on_rewarded_failed_to_show() -> void:
	if _showing != Showing.REWARDED:
		return
	_showing = Showing.NONE
	_on_reward = Callable()
	_finish_break()


## An ad opened, or the player chose the rewarded one: both counts start over, saved.
func _reset_pacing() -> void:
	pacing.note_ad_shown()
	_save_pacing()


func _on_open_timeout(serial: int) -> void:
	if serial == _break_serial and _is_awaiting_open:
		Log.info("ads: the ad did not open in time; the game goes on")
		_finish_break()


## DIVERGENCE(ADS R12): an ad still out GIVE_UP_SECONDS after `show`, never opened, is let go,
## so the next break and offer may show ads again. An opened ad waits for its close.
func _on_give_up(serial: int) -> void:
	if serial == _break_serial and _showing != Showing.NONE and not _is_open:
		Log.info("ads: the ad never opened, closed or failed; no longer waiting for it")
		_showing = Showing.NONE
		_finish_break()


## The ad closed or failed, or never opened: sound back, the action runs once, missing ads load.
func _finish_break() -> void:
	_is_awaiting_open = false
	var action: Callable = _pending
	_pending = Callable()
	_restore_sound()
	_request_load()
	rewarded_changed.emit()
	if action.is_valid():
		Log.info("ads: break over")
		action.call()


func _mute_sound() -> void:
	_was_master_muted = AudioServer.is_bus_mute(0)
	_is_muting = true
	AudioServer.set_bus_mute(0, true)


func _restore_sound() -> void:
	if _is_muting:
		_is_muting = false
		AudioServer.set_bus_mute(0, _was_master_muted)


func _save_pacing() -> void:
	SaveStore.save_dict(SAVE_PATH, pacing.to_dict())
