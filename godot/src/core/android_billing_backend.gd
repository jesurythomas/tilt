## android_billing_backend.gd
## PORTS: nothing — new file (ruling IAP R1,
## docs/superpowers/plans/2026-10-25-remove-ads-purchase.md)
class_name AndroidBillingBackend
extends BillingBackend
## The PerilBilling Android plugin (android/peril-billing/…/PerilBillingPlugin.java) behind
## BillingBackend. The only file in the game that names it.

## The plugin's singleton name (its manifest's org.godotengine.plugin.v2.PerilBilling).
const SINGLETON: String = "PerilBilling"

var _plugin: Object = null


func _init(plugin: Object) -> void:
	_plugin = plugin
	_plugin.connect("connected", _on_connected)
	_plugin.connect("product_found", product_found.emit)
	_plugin.connect("product_missing", _on_product_missing)
	_plugin.connect("purchase_state", purchase_state.emit)
	_plugin.connect("purchases_queried", purchases_queried.emit)
	_plugin.connect("purchase_failed", _on_purchase_failed)


# PORT-NOTE: the plugin is a JNI singleton with no script class, so its Java methods are
# reached by name, as android_ads_backend.gd reaches PerilAds.
func start_connection() -> void:
	_plugin.call("startConnection")


func query_product(product_id: String) -> void:
	_plugin.call("queryProduct", product_id)


func purchase(product_id: String) -> void:
	_plugin.call("purchase", product_id)


func query_purchases() -> void:
	_plugin.call("queryPurchases")


func _on_connected(is_ok: bool, code: int, message: String) -> void:
	Log.info("billing: connected=%s (%d %s)" % [is_ok, code, message])
	connected.emit(is_ok)


func _on_product_missing(product_id: String, code: int, message: String) -> void:
	Log.info("billing: %s not found (%d %s)" % [product_id, code, message])
	product_missing.emit(product_id)


func _on_purchase_failed(code: int, message: String) -> void:
	Log.info("billing: no purchase (%d %s)" % [code, message])
	purchase_failed.emit(code)
