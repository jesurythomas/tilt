## ads_config.gd
## PORTS: nothing — new file (ruling ADS R1, docs/superpowers/plans/2026-10-13-in-game-ads.md)
class_name AdsConfig
extends RefCounted
## The AdMob IDs and the ad test switches, kept in project settings so the game and the export
## plugin (godot/addons/peril_ads) read the same values. Unset, both IDs are Google's test IDs,
## which serve only test ads; the real ones go in project.godot once the AdMob app exists.

## Google's sample AdMob app ID (developers.google.com/admob/android/quick-start).
const TEST_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
## Google's test interstitial unit (developers.google.com/admob/android/interstitial).
const TEST_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"

const APP_ID_SETTING: String = "peril/ads/android_app_id"
const INTERSTITIAL_ID_SETTING: String = "peril/ads/android_interstitial_id"
## The device's hashed ID from logcat: a UMP debug device and an SDK test device (test ads).
const TEST_DEVICE_SETTING: String = "peril/ads/test_device_hashed_id"
## UMP's DebugGeography (1 EEA, 2 not EEA); applies only to the test device. 0 is off.
const DEBUG_GEOGRAPHY_SETTING: String = "peril/ads/debug_geography"
## True skips the pacing at the ad break, for checking ads on a device. Never commit it on.
const EVERY_BREAK_SETTING: String = "peril/ads/every_break"


## The AdMob app ID the manifest declares.
static func app_id() -> String:
	return _text(APP_ID_SETTING, TEST_APP_ID)


## The interstitial ad unit shown at the break.
static func interstitial_id() -> String:
	return _text(INTERSTITIAL_ID_SETTING, TEST_INTERSTITIAL_ID)


## Blank unless a test device is set.
static func test_device_hashed_id() -> String:
	return _text(TEST_DEVICE_SETTING, "")


## 0 unless a debug geography is set.
static func debug_geography() -> int:
	var value: Variant = ProjectSettings.get_setting(DEBUG_GEOGRAPHY_SETTING, 0)
	if value is int:
		return value
	return 0


## True when the pacing is switched off for a device check.
static func is_every_break() -> bool:
	var value: Variant = ProjectSettings.get_setting(EVERY_BREAK_SETTING, false)
	if value is bool:
		return value
	return false


static func _text(setting: String, fallback: String) -> String:
	var value: Variant = ProjectSettings.get_setting(setting, "")
	if value is String:
		var text: String = value
		if not text.is_empty():
			return text
	return fallback
