## recording_telemetry_backend.gd
## PORTS: nothing — test helper; records what Telemetry hands its backend
class_name RecordingTelemetryBackend
extends TelemetryBackend
## A backend that keeps every event so specs can assert names and params.

## Event names, in call order.
var names: Array[String] = []
## The params of each event, parallel to `names`.
var params: Array[Dictionary] = []
## Every set_collection_enabled argument, in call order.
var collection_calls: Array[bool] = []


func log_event(event: String, event_params: Dictionary) -> void:
	names.append(event)
	params.append(event_params)


func set_collection_enabled(is_on: bool) -> void:
	collection_calls.append(is_on)


## The params of the most recent `event`, or {} when none was logged.
func last_params(event: String) -> Dictionary:
	var i: int = names.rfind(event)
	return params[i] if i >= 0 else {}
