## test_billing.gd
## PORTS: nothing — new file, covers src/core/billing.gd and Ads' Remove ads gate (IAP R1-R4)
extends GutTest
## Proves the Remove ads purchase: no offer until Play prices it, ownership from Play's sheet or
## its query, kept in the save, given back by an answered query that no longer lists it, and
## that an owner gets no interstitial but keeps the rewarded ad.

var _rec: RecordingBillingBackend = null
var _previous: BillingBackend = null
var _ads_rec: RecordingAdsBackend = null
var _ads_previous: AdsBackend = null


func _remove_saves() -> void:
	for path: String in [Billing.SAVE_PATH, Ads.SAVE_PATH]:
		for each: String in [path, SaveStore.corrupt_path_for(path)]:
			var absolute: String = ProjectSettings.globalize_path(each)
			if FileAccess.file_exists(absolute):
				DirAccess.remove_absolute(absolute)


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


func test_start_connects_once_then_asks_price_and_purchases() -> void:
	Billing.start()
	Billing.start()
	assert_eq(_rec.calls, ["connect"] as Array[String])
	_rec.connected.emit(true)
	assert_eq(_rec.count("product " + Billing.REMOVE_ADS_ID), 1)
	assert_eq(_rec.count("purchases"), 1)


func test_a_failed_connection_asks_nothing() -> void:
	Billing.start()
	_rec.connected.emit(false)
	assert_eq(_rec.calls, ["connect"] as Array[String])
	assert_false(Billing.is_offered())


func test_no_offer_until_play_prices_it() -> void:
	assert_false(Billing.is_offered(), "the null store offers nothing")
	_rec.open_store("₱25.00")
	assert_true(Billing.is_offered())
	assert_eq(Billing.price_text, "₱25.00")


func test_buying_opens_plays_sheet_once() -> void:
	_rec.open_store("₱25.00")
	Billing.buy_remove_ads()
	Billing.buy_remove_ads()
	assert_eq(_rec.count("buy " + Billing.REMOVE_ADS_ID), 1)
	assert_true(Billing.is_buying)


func test_a_purchase_removes_ads_and_is_saved() -> void:
	watch_signals(Billing)
	_rec.open_store("₱25.00")
	Billing.buy_remove_ads()
	_rec.report(BillingBackend.PURCHASED)
	assert_true(Billing.is_ads_removed)
	assert_false(Billing.is_buying)
	assert_false(Billing.is_offered(), "an owner is not offered it again")
	assert_signal_emit_count(Billing, "purchased", 1)
	Billing.reset_session()
	assert_true(Billing.is_ads_removed, "a launch without Play stays ad-free")


func test_a_cancelled_purchase_offers_it_again() -> void:
	_rec.open_store("₱25.00")
	Billing.buy_remove_ads()
	_rec.purchase_failed.emit(BillingBackend.USER_CANCELED)
	assert_false(Billing.is_buying)
	assert_false(Billing.is_ads_removed)
	assert_true(Billing.is_offered())


func test_a_restored_purchase_is_not_a_new_one() -> void:
	watch_signals(Billing)
	_rec.connected.emit(true)
	_rec.report(BillingBackend.PURCHASED)
	_rec.purchases_queried.emit(true)
	assert_true(Billing.is_ads_removed)
	assert_signal_emit_count(Billing, "purchased", 0)


func test_a_pending_payment_holds_the_offer_until_paid() -> void:
	_rec.open_store("₱25.00")
	Billing.buy_remove_ads()
	_rec.report(BillingBackend.PENDING)
	assert_true(Billing.is_pending)
	assert_false(Billing.is_ads_removed, "unpaid: the ads stay")
	Billing.buy_remove_ads()
	assert_eq(_rec.count("buy "), 1, "no second sheet while one payment is pending")
	_rec.report(BillingBackend.PURCHASED)
	assert_false(Billing.is_pending)
	assert_true(Billing.is_ads_removed)


func test_an_answered_query_without_it_gives_the_ads_back() -> void:
	_rec.connected.emit(true)
	_rec.report(BillingBackend.PURCHASED)
	_rec.purchases_queried.emit(true)
	assert_true(Billing.is_ads_removed)
	_rec.purchases_queried.emit(true)
	assert_false(Billing.is_ads_removed, "refunded")
	Billing.reset_session()
	assert_false(Billing.is_ads_removed, "and saved so")


func test_an_unanswered_query_keeps_ownership() -> void:
	_rec.report(BillingBackend.PURCHASED)
	_rec.purchases_queried.emit(true)
	_rec.purchases_queried.emit(false)
	assert_true(Billing.is_ads_removed)


func test_other_products_are_ignored() -> void:
	_rec.purchase_state.emit("something_else", BillingBackend.PURCHASED)
	_rec.product_found.emit("something_else", "₱99.00")
	assert_false(Billing.is_ads_removed)
	assert_eq(Billing.price_text, "")


func test_an_owner_gets_no_interstitial_but_keeps_the_rewarded_ad() -> void:
	ProjectSettings.set_setting(AdsConfig.EVERY_BREAK_SETTING, true)
	_rec.report(BillingBackend.PURCHASED)
	Ads.start()
	_ads_rec.consent_finished.emit(true, false)
	assert_eq(_ads_rec.count("load "), 0, "no interstitial loads for an owner")
	assert_eq(_ads_rec.count("reward_load "), 1, "the rewarded ad still loads")
	_ads_rec.interstitial_loaded.emit()
	assert_false(Ads.is_break_due())
	var ran: Array[bool] = [false]
	Ads.ad_break(func() -> void: ran[0] = true)
	assert_true(ran[0], "the break's action runs at once")
	assert_eq(_ads_rec.count("show"), 0)
