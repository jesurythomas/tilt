## telemetry_backend.gd
## PORTS: nothing — new file per docs/superpowers/specs/2026-09-29-analytics-crashes-design.md §3
class_name TelemetryBackend
extends RefCounted
## What Telemetry talks to. This base class is the null backend: it accepts every
## call and sends nothing, which is what desktop, headless and the test suite get.
## The Firebase backend (spec §6 step 3) extends it and is the only file that will
## name the plugin.


## Sends one analytics event. `params` values are String, int or float.
func log_event(_event: String, _params: Dictionary) -> void:
	pass


## Turns the vendor's collection on or off (the player's opt-out).
func set_collection_enabled(_is_on: bool) -> void:
	pass
