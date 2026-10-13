## recording_ads_backend.gd
## PORTS: nothing — test helper; records what Ads hands its backend
class_name RecordingAdsBackend
extends AdsBackend
## A backend that keeps every call, so specs can assert them and answer with its signals.

## Calls in order: "consent <id> <geography>", "load <unit>", "show", "privacy".
var calls: Array[String] = []


func gather_consent(test_device_hashed_id: String, debug_geography: int) -> void:
	calls.append("consent %s %d" % [test_device_hashed_id, debug_geography])


func load_interstitial(ad_unit_id: String) -> void:
	calls.append("load " + ad_unit_id)


func show_interstitial() -> void:
	calls.append("show")


func show_privacy_options() -> void:
	calls.append("privacy")


## How many recorded calls start with `prefix`.
func count(prefix: String) -> int:
	var n: int = 0
	for call_name: String in calls:
		if call_name.begins_with(prefix):
			n += 1
	return n
