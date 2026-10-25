## test_support_banner.gd
## PORTS: nothing — new file, covers the Run over's Support the dev banner (IAP R1-R4) in
## RunOverSheet, HudController and GameRoot
extends GutTest
## Proves the banner shows on the Run over only while Play offers Remove ads, buys on a tap,
## dims while Play's sheet opens or a payment is pending, thanks the buyer on that sheet only,
## and that the buyer's next Retry shows no interstitial.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _rec: RecordingBillingBackend = null
var _previous: BillingBackend = null
var _ads_rec: RecordingAdsBackend = null
var _ads_previous: AdsBackend = null


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
		Billing.SAVE_PATH,
	]:
		_remove(path)
		_remove(SaveStore.corrupt_path_for(path))


func before_each() -> void:
	_remove_saves()
	_previous = Billing.backend
	_rec = RecordingBillingBackend.new()
	Billing.set_backend(_rec)
	Billing.reset_session()
	_ads_previous = Ads.backend
	_ads_rec = RecordingAdsBackend.new()
	Ads.set_backend(_ads_rec)
	Ads.reset_session()


func after_each() -> void:
	Billing.set_backend(_previous)
	Ads.reset_session()
	Ads.set_backend(_ads_previous)
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, null)
	AudioServer.set_bus_mute(0, false)
	_remove_saves()
	Billing.reset_session()
	Ads.reset_session()


func _boot() -> GameRoot:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	return root


func _die(root: GameRoot) -> void:
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	root._player.shield_timer = 0.0  # past the cold open's spawn shield
	root._run_controller.lives = 1
	root._run_controller.lose_life()
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER)


## Boots with Play pricing Remove ads, and dies in a run.
func _boot_to_offer() -> GameRoot:
	var root: GameRoot = await _boot()
	_rec.open_store("₱25.00")
	_die(root)
	return root


func _banner(root: GameRoot) -> Button:
	var banner: Button = root.find_child("SupportBanner", true, false) as Button
	assert_not_null(banner, "the Run over carries the banner")
	return banner


func _sheet(root: GameRoot) -> RunOverSheet:
	return root.find_child("GameOverPanel", true, false) as RunOverSheet


func _label(root: GameRoot, label_name: String) -> Label:
	return root.find_child(label_name, true, false) as Label


func test_launch_connects_to_play_after_the_first_frame() -> void:
	var root: GameRoot = await _boot()
	assert_not_null(root)
	await get_tree().process_frame
	assert_eq(_rec.count("connect"), 1)


func test_the_run_over_offers_remove_ads_at_plays_price() -> void:
	var root: GameRoot = await _boot_to_offer()
	assert_true(_banner(root).visible)
	assert_eq(_sheet(root).support_state(), RunOverSheet.SupportState.OFFERED)
	assert_eq(_label(root, "SupportTitle").text, RunOverSheet.SUPPORT_TITLE)
	assert_eq(_label(root, "SupportPrice").text, "₱25.00")
	assert_true(_label(root, "SupportPrice").visible)


func test_no_banner_until_play_prices_it() -> void:
	var root: GameRoot = await _boot()
	_die(root)
	assert_false(_banner(root).visible, "a build Play does not know offers nothing")
	_rec.open_store("₱25.00")
	assert_true(_banner(root).visible, "it appears when Play answers")


func test_no_banner_outside_the_run_over() -> void:
	var root: GameRoot = await _boot()
	_rec.open_store("₱25.00")
	assert_eq(root.support_state(), RunOverSheet.SupportState.HIDDEN, "the menu")


func test_a_tap_opens_plays_sheet_and_dims_the_banner() -> void:
	var root: GameRoot = await _boot_to_offer()
	_banner(root).pressed.emit()
	assert_eq(_rec.count("buy " + Billing.REMOVE_ADS_ID), 1)
	assert_eq(_sheet(root).support_state(), RunOverSheet.SupportState.WAITING)
	assert_eq(_label(root, "SupportSub").text, RunOverSheet.SUPPORT_WAITING_SUB)
	_banner(root).pressed.emit()
	assert_eq(_rec.count("buy "), 1, "a second tap while it opens does nothing")


func test_a_cancelled_purchase_offers_it_again() -> void:
	var root: GameRoot = await _boot_to_offer()
	_banner(root).pressed.emit()
	_rec.purchase_failed.emit(BillingBackend.USER_CANCELED)
	assert_eq(_sheet(root).support_state(), RunOverSheet.SupportState.OFFERED)


func test_a_purchase_thanks_the_buyer_on_this_sheet_only() -> void:
	var root: GameRoot = await _boot_to_offer()
	_banner(root).pressed.emit()
	_rec.report(BillingBackend.PURCHASED)
	assert_eq(_sheet(root).support_state(), RunOverSheet.SupportState.THANKS)
	assert_eq(_label(root, "SupportTitle").text, RunOverSheet.SUPPORT_THANKS_TITLE)
	assert_false(_label(root, "SupportPrice").visible)
	_banner(root).pressed.emit()
	assert_eq(_rec.count("buy "), 1, "the thanks is not a button")
	root.restart_run()
	root.skip_cinematic()
	root._player.shield_timer = 0.0
	root._run_controller.lives = 1
	root._run_controller.lose_life()
	assert_false(_banner(root).visible, "an owner's next Run over has no banner")


func test_a_pending_payment_dims_the_banner() -> void:
	var root: GameRoot = await _boot_to_offer()
	_banner(root).pressed.emit()
	_rec.report(BillingBackend.PENDING)
	assert_eq(_sheet(root).support_state(), RunOverSheet.SupportState.PENDING)
	assert_eq(_label(root, "SupportSub").text, RunOverSheet.SUPPORT_PENDING_SUB)
	_banner(root).pressed.emit()
	assert_eq(_rec.count("buy "), 1)


func test_the_buyers_retry_shows_no_interstitial() -> void:
	var root: GameRoot = await _boot()
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, true)
	_ads_rec.consent_finished.emit(true, false)
	_ads_rec.interstitial_loaded.emit()
	_rec.open_store("₱25.00")
	_die(root)
	_banner(root).pressed.emit()
	_rec.report(BillingBackend.PURCHASED)
	root.restart_run()
	assert_eq(_ads_rec.count("show"), 0, "no interstitial for a buyer")
	assert_ne(root._state.phase, Types.GamePhase.GAME_OVER, "Retry went straight on")


func test_a_tap_while_an_ad_opens_buys_nothing() -> void:
	var root: GameRoot = await _boot()
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, true)
	_ads_rec.consent_finished.emit(true, false)
	_ads_rec.interstitial_loaded.emit()
	_rec.open_store("₱25.00")
	_die(root)
	root.restart_run()  # Retry's ad is on its way (ADS R14 keeps the sheet up)
	assert_true(Ads.is_break_pending())
	root.buy_remove_ads()
	assert_eq(_rec.count("buy "), 0)


func test_the_banner_never_grows_the_sheet() -> void:
	var root: GameRoot = await _boot_to_offer()
	var sheet: Control = _sheet(root).find_child("Sheet", true, false) as Control
	await get_tree().process_frame
	var with_banner: float = sheet.size.y
	_sheet(root).set_support_offer(RunOverSheet.SupportState.HIDDEN, "")
	await get_tree().process_frame
	assert_eq(with_banner, sheet.size.y, "the banner scrolls with the list; the sheet holds")
