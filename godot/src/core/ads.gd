## ads.gd
## PORTS: nothing — new file (rulings ADS R1-R5, docs/superpowers/plans/2026-10-13-in-game-ads.md)
# PORT-NOTE: no `class_name`, against CONVENTIONS §2. An autoload script cannot
# carry one (same as Telemetry, Haptics, Log and GameEvents).
extends Node
## Interstitial ads at the one ad break, and the consent they need. Autoloaded as `Ads`.
##
## The break is leaving the Run over: GameRoot routes Retry and Menu through `ad_break`. No sim
## class calls this; GameRoot does, as it does Telemetry. Swapping the ad vendor means
## replacing `backend`; nothing else in the game names one.

## Consent was gathered or changed; Settings shows or hides its Ad privacy row.
signal consent_changed

## DIVERGENCE(ADS R2): seconds an ad may take to open before the break goes on without it.
const OPEN_TIMEOUT_SECONDS: float = 4.0
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

var _is_started: bool = false
var _is_loading: bool = false
## The break's action, held while its ad opens and shows.
var _pending: Callable = Callable()
## True from `show` until the ad opens or the break ends; the watchdog acts only then.
var _is_awaiting_open: bool = false
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
		backend.interstitial_closed.disconnect(_finish_break)
		backend.interstitial_failed_to_show.disconnect(_finish_break)
	backend = next
	backend.consent_finished.connect(_on_consent_finished)
	backend.interstitial_loaded.connect(_on_interstitial_loaded)
	backend.interstitial_failed_to_load.connect(_on_interstitial_failed_to_load)
	backend.interstitial_opened.connect(_on_interstitial_opened)
	backend.interstitial_closed.connect(_finish_break)
	backend.interstitial_failed_to_show.connect(_finish_break)


## Forgets consent, the loaded ad and any break, and reloads the pacing's save, as at launch.
func reset_session() -> void:
	_restore_sound()
	pacing = AdPacing.new(rng)
	pacing.load_dict(SaveStore.load_dict(SAVE_PATH))
	can_request_ads = false
	is_privacy_options_required = false
	is_ad_loaded = false
	_is_started = false
	_is_loading = false
	_pending = Callable()
	_is_awaiting_open = false
	_break_serial += 1


## Gathers consent, once per launch. GameRoot calls it after the first frame.
func start() -> void:
	if _is_started:
		return
	_is_started = true
	backend.gather_consent(AdsConfig.test_device_hashed_id(), AdsConfig.debug_geography())


## A run ended after `seconds`: counts it for the pacing and makes sure an ad is on its way.
func note_run_end(seconds: float, was_first_run: bool) -> void:
	pacing.note_run_end(seconds, was_first_run)
	_save_pacing()
	_request_load()


## True when a break now would show an ad: consent, a loaded ad, and the pacing (ADS R5).
func is_break_due() -> bool:
	if not can_request_ads or not is_ad_loaded:
		return false
	return AdsConfig.is_every_break() or pacing.is_due()


## DIVERGENCE(ADS R2): the ad break. Shows an interstitial when one is due and runs `action`
## when it closes (or fails, or has not opened after OPEN_TIMEOUT_SECONDS); otherwise runs
## `action` at once. A break while another one's ad is opening is dropped.
func ad_break(action: Callable) -> void:
	if _pending.is_valid():
		return
	if not is_break_due():
		action.call()
		return
	_pending = action
	is_ad_loaded = false
	_mute_sound()
	_break_serial += 1
	_is_awaiting_open = true
	# Bound to a number, not the timer: a timer bound into its own signal is a cycle that leaks.
	get_tree().create_timer(OPEN_TIMEOUT_SECONDS).timeout.connect(
		_on_open_timeout.bind(_break_serial)
	)
	Log.info("ads: break shows an interstitial")
	backend.show_interstitial()


## True while a break waits on its ad.
func is_break_pending() -> bool:
	return _pending.is_valid()


## Settings → Ad privacy · Manage: UMP's privacy options form.
func show_privacy_options() -> void:
	backend.show_privacy_options()


func _request_load() -> void:
	if not can_request_ads or is_ad_loaded or _is_loading or _pending.is_valid():
		return
	_is_loading = true
	backend.load_interstitial(AdsConfig.interstitial_id())


func _on_consent_finished(can_request: bool, is_privacy_required: bool) -> void:
	can_request_ads = can_request
	is_privacy_options_required = is_privacy_required
	consent_changed.emit()
	_request_load()


func _on_interstitial_loaded() -> void:
	_is_loading = false
	is_ad_loaded = true


func _on_interstitial_failed_to_load() -> void:
	_is_loading = false
	is_ad_loaded = false


func _on_interstitial_opened() -> void:
	_is_awaiting_open = false
	pacing.note_ad_shown()
	_save_pacing()
	Log.info("ads: interstitial opened")


func _on_open_timeout(serial: int) -> void:
	if serial == _break_serial and _is_awaiting_open:
		Log.info("ads: interstitial did not open in time; the break goes on")
		_finish_break()


## The ad closed or failed, or never opened: sound back, the action runs once, the next ad loads.
func _finish_break() -> void:
	_is_awaiting_open = false
	var action: Callable = _pending
	_pending = Callable()
	_restore_sound()
	_request_load()
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
