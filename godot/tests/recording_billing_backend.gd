## recording_billing_backend.gd
## PORTS: nothing — test helper; records what Billing hands its backend
class_name RecordingBillingBackend
extends BillingBackend
## A backend that keeps every call, so specs can assert them and answer with its signals.

## Calls in order: "connect", "product <id>", "buy <id>", "purchases".
var calls: Array[String] = []


func start_connection() -> void:
	calls.append("connect")


func query_product(product_id: String) -> void:
	calls.append("product " + product_id)


func purchase(product_id: String) -> void:
	calls.append("buy " + product_id)


func query_purchases() -> void:
	calls.append("purchases")


## Play connects and prices Remove ads; its purchases query finds nothing.
func open_store(price: String) -> void:
	connected.emit(true)
	product_found.emit(Billing.REMOVE_ADS_ID, price)
	purchases_queried.emit(true)


## Play reports a purchase of Remove ads in `state`, as its sheet or a query does.
func report(state: int) -> void:
	purchase_state.emit(Billing.REMOVE_ADS_ID, state)


## How many recorded calls start with `prefix`.
func count(prefix: String) -> int:
	var n: int = 0
	for call_name: String in calls:
		if call_name.begins_with(prefix):
			n += 1
	return n
