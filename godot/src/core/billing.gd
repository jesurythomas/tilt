## billing.gd
## PORTS: nothing — new file (rulings IAP R1-R4,
## docs/superpowers/plans/2026-10-25-remove-ads-purchase.md)
# PORT-NOTE: no `class_name`, against CONVENTIONS §2. An autoload script cannot
# carry one (same as Ads, Telemetry, Haptics, Log and GameEvents).
extends Node
## The one purchase: "Remove ads", a one-time product the Run over's Support the dev banner sells.
## Autoloaded as `Billing`. Owning it stops the interstitials (`Ads.is_break_due`); the rewarded
## ad stays, as the player asks for it (IAP R2).
##
## Ownership is Play's: asked at every launch and every resume (the plugin), and kept in a save
## so a launch without a connection stays ad-free (IAP R3). GameRoot starts it and reads it;
## swapping the store means replacing `backend`.

## The offer, the ownership or a purchase's progress changed; the Run over redraws its banner.
signal changed
## A purchase made this session went through (not one restored by a query).
signal purchased

## DIVERGENCE(IAP R1): the product's id in Play Console (Monetize → One-time products). Its
## price, ₱25 (user 2026-10-25: "Let's have it at 25php"), is set there, not here.
const REMOVE_ADS_ID: String = "remove_ads"
## DIVERGENCE(IAP R3): ownership as last confirmed, kept across launches.
const SAVE_PATH: String = "user://peril_point_billing.json"

## Where store calls go: the PerilBilling plugin on Android, else the null backend.
var backend: BillingBackend = null
## True once the player owns Remove ads.
var is_ads_removed: bool = false
## True while Play holds a purchase not yet paid (a cash payment, IAP R4).
var is_pending: bool = false
## The product's price as Play formats it; blank until Play has answered (no offer before).
var price_text: String = ""
## True from the tap until Play's sheet closes.
var is_buying: bool = false

var _is_started: bool = false
## What the purchases query in flight has reported so far.
var _query_saw_owned: bool = false
var _query_saw_pending: bool = false


func _ready() -> void:
	# Built here, not by a static factory (see Ads._ready: that kept scripts alive at exit).
	if Engine.has_singleton(AndroidBillingBackend.SINGLETON):
		set_backend(
			AndroidBillingBackend.new(Engine.get_singleton(AndroidBillingBackend.SINGLETON))
		)
	else:
		set_backend(BillingBackend.new())
	reset_session()


## Swaps the backend (tests use a recording one) and listens to it.
func set_backend(next: BillingBackend) -> void:
	if backend != null:
		backend.connected.disconnect(_on_connected)
		backend.product_found.disconnect(_on_product_found)
		backend.purchase_state.disconnect(_on_purchase_state)
		backend.purchases_queried.disconnect(_on_purchases_queried)
		backend.purchase_failed.disconnect(_on_purchase_failed)
	backend = next
	backend.connected.connect(_on_connected)
	backend.product_found.connect(_on_product_found)
	backend.purchase_state.connect(_on_purchase_state)
	backend.purchases_queried.connect(_on_purchases_queried)
	backend.purchase_failed.connect(_on_purchase_failed)


## Forgets the price and any purchase in progress and reloads the saved ownership, as at launch.
func reset_session() -> void:
	is_ads_removed = SaveStore.read_bool(SaveStore.load_dict(SAVE_PATH), "ads_removed", false)
	is_pending = false
	price_text = ""
	is_buying = false
	_is_started = false
	_query_saw_owned = false
	_query_saw_pending = false


## Connects to the store, once per launch. GameRoot calls it after the first frame.
func start() -> void:
	if _is_started:
		return
	_is_started = true
	backend.start_connection()


## DIVERGENCE(IAP R1): true while the Run over may offer Remove ads: not owned, and Play has
## priced it (so a build Play does not know, or no connection, offers nothing).
func is_offered() -> bool:
	return not is_ads_removed and not price_text.is_empty()


## Opens Play's purchase sheet. Nothing while one is open or a payment is pending.
func buy_remove_ads() -> void:
	if not is_offered() or is_buying or is_pending:
		return
	is_buying = true
	Log.info("billing: buying %s" % REMOVE_ADS_ID)
	backend.purchase(REMOVE_ADS_ID)
	changed.emit()


func _on_connected(is_ok: bool) -> void:
	if not is_ok:
		return
	backend.query_product(REMOVE_ADS_ID)
	_query_saw_owned = false
	_query_saw_pending = false
	backend.query_purchases()


func _on_product_found(product_id: String, price: String) -> void:
	if product_id != REMOVE_ADS_ID:
		return
	price_text = price
	changed.emit()


## One purchase, from a query or from Play's sheet.
func _on_purchase_state(product_id: String, state: int) -> void:
	if product_id != REMOVE_ADS_ID:
		return
	if state == BillingBackend.PURCHASED:
		_query_saw_owned = true
		var was_buying: bool = is_buying
		is_buying = false
		is_pending = false
		_set_ads_removed(true)
		if was_buying:
			Telemetry.log_event("remove_ads_purchase", {"price": price_text})
			purchased.emit()
	elif state == BillingBackend.PENDING:
		_query_saw_pending = true
		is_buying = false
		is_pending = true
		changed.emit()


## DIVERGENCE(IAP R3): an answered query is the truth: a purchase it no longer lists (refunded)
## gives the ads back. An unanswered one changes nothing.
func _on_purchases_queried(is_ok: bool) -> void:
	if is_ok:
		is_pending = _query_saw_pending and not _query_saw_owned
		_set_ads_removed(_query_saw_owned)
	_query_saw_owned = false
	_query_saw_pending = false
	changed.emit()


func _on_purchase_failed(_code: int) -> void:
	is_buying = false
	changed.emit()


func _set_ads_removed(is_removed: bool) -> void:
	if is_removed == is_ads_removed:
		return
	Log.info("billing: ads_removed=%s" % is_removed)
	is_ads_removed = is_removed
	SaveStore.save_dict(SAVE_PATH, {"ads_removed": is_removed})
	changed.emit()
