## ads_backend.gd
## PORTS: nothing — new file (ruling ADS R4, docs/superpowers/plans/2026-10-13-in-game-ads.md)
class_name AdsBackend
extends RefCounted
## What `Ads` talks to. This base class is the null backend: consent never arrives, so no ad
## ever shows; desktop, headless and the test suite get it. AndroidAdsBackend extends it and is
## the only file that names the plugin.

## Consent was gathered: at launch, and again after the privacy options form closes.
signal consent_finished(can_request_ads: bool, is_privacy_options_required: bool)
## An interstitial is loaded and ready to show.
signal interstitial_loaded
## A load failed.
signal interstitial_failed_to_load
## The interstitial covers the game.
signal interstitial_opened
## The player closed the interstitial.
signal interstitial_closed
## The interstitial could not show (none held, expired, or the SDK refused).
signal interstitial_failed_to_show


## Requests this launch's consent state and shows the consent form if it is required.
## A blank id and geography 0 leave UMP's debug settings off.
func gather_consent(_test_device_hashed_id: String, _debug_geography: int) -> void:
	pass


## Loads one interstitial from `ad_unit_id`.
func load_interstitial(_ad_unit_id: String) -> void:
	pass


## Shows the loaded interstitial.
func show_interstitial() -> void:
	pass


## Shows UMP's privacy options form.
func show_privacy_options() -> void:
	pass
