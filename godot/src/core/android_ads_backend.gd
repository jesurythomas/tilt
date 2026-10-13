## android_ads_backend.gd
## PORTS: nothing — new file (ruling ADS R1, docs/superpowers/plans/2026-10-13-in-game-ads.md)
class_name AndroidAdsBackend
extends AdsBackend
## The PerilAds Android plugin (android/peril-ads/…/PerilAdsPlugin.java) behind AdsBackend.
## The only file in the game that names it.

## The plugin's singleton name (its manifest's org.godotengine.plugin.v2.PerilAds).
const SINGLETON: String = "PerilAds"

var _plugin: Object = null


func _init(plugin: Object) -> void:
	_plugin = plugin
	_plugin.connect("consent_finished", _on_consent_finished)
	_plugin.connect("interstitial_loaded", interstitial_loaded.emit)
	_plugin.connect("interstitial_failed_to_load", _on_interstitial_failed_to_load)
	_plugin.connect("interstitial_opened", interstitial_opened.emit)
	_plugin.connect("interstitial_closed", interstitial_closed.emit)
	_plugin.connect("interstitial_failed_to_show", _on_interstitial_failed_to_show)


## The plugin's backend on Android, else null.
static func create() -> AndroidAdsBackend:
	if not Engine.has_singleton(SINGLETON):
		return null
	return AndroidAdsBackend.new(Engine.get_singleton(SINGLETON))


# PORT-NOTE: the plugin is a JNI singleton with no script class, so its Java methods are
# reached by name, as haptics.gd reaches the Android Vibrator.
func gather_consent(test_device_hashed_id: String, debug_geography: int) -> void:
	_plugin.call("gatherConsent", test_device_hashed_id, debug_geography)


func load_interstitial(ad_unit_id: String) -> void:
	_plugin.call("loadInterstitial", ad_unit_id)


func show_interstitial() -> void:
	_plugin.call("showInterstitial")


func show_privacy_options() -> void:
	_plugin.call("showPrivacyOptions")


func _on_consent_finished(can_request_ads: bool, is_privacy_required: bool, error: String) -> void:
	Log.info(
		(
			"ads: consent can_request_ads=%s privacy_options_required=%s %s"
			% [can_request_ads, is_privacy_required, error]
		)
	)
	consent_finished.emit(can_request_ads, is_privacy_required)


func _on_interstitial_failed_to_load(code: int, message: String) -> void:
	Log.info("ads: interstitial failed to load (%d %s)" % [code, message])
	interstitial_failed_to_load.emit()


func _on_interstitial_failed_to_show(code: int, message: String) -> void:
	Log.info("ads: interstitial failed to show (%d %s)" % [code, message])
	interstitial_failed_to_show.emit()
