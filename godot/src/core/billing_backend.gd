## billing_backend.gd
## PORTS: nothing — new file (ruling IAP R1,
## docs/superpowers/plans/2026-10-25-remove-ads-purchase.md)
class_name BillingBackend
extends RefCounted
## What `Billing` talks to. This base class is the null backend: the store never connects, so
## nothing is ever offered; desktop, headless and the test suite get it. AndroidBillingBackend
## extends it and is the only file that names the plugin.

## The store answered the connection.
signal connected(is_ok: bool)
## A product exists for this app, at `price` as the store formats it ("₱25.00").
signal product_found(product_id: String, price: String)
## A product could not be fetched (not set up in the store, or no answer).
signal product_missing(product_id: String)
## One purchase the store holds: PURCHASED or PENDING.
signal purchase_state(product_id: String, state: int)
## A purchases query ended, after its purchase_state signals; `is_ok` false: no answer.
signal purchases_queried(is_ok: bool)
## The purchase flow ended without a purchase (cancelled, failed, or would not open).
signal purchase_failed(code: int)

## Play's Purchase.PurchaseState.
const PURCHASED: int = 1
const PENDING: int = 2
## Play's BillingResponseCode.USER_CANCELED.
const USER_CANCELED: int = 1


## Connects to the store once.
func start_connection() -> void:
	pass


## Fetches one product's price.
func query_product(_product_id: String) -> void:
	pass


## Opens the store's purchase sheet for a product query_product found.
func purchase(_product_id: String) -> void:
	pass


## Reports every purchase the store holds for this account.
func query_purchases() -> void:
	pass
