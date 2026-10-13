## peril_ads_plugin.gd
## PORTS: nothing — new file (ruling ADS R1, docs/superpowers/plans/2026-10-13-in-game-ads.md)
@tool
extends EditorPlugin
## Hands the PerilAds AAR (built by tools/build_ads_plugin.sh), the Google Mobile Ads and UMP
## SDKs and the AdMob app ID (AdsConfig) to Android exports. Editor-only; the game talks to the
## plugin through src/core/android_ads_backend.gd.

var _export_plugin: PerilAdsExportPlugin = null


func _enter_tree() -> void:
	_export_plugin = PerilAdsExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


## The Android half: library, dependencies and the manifest's app ID.
class PerilAdsExportPlugin:
	extends EditorExportPlugin

	## Keep in step with android/peril-ads/build.gradle (there they are compileOnly).
	const DEPENDENCIES: Array[String] = [
		"com.google.android.gms:play-services-ads:25.5.0",
		"com.google.android.ump:user-messaging-platform:4.0.0",
	]

	func _get_name() -> String:
		return "PerilAds"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## Paths are relative to res://addons.
	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(
			["peril_ads/bin/peril-ads-%s.aar" % ("debug" if debug else "release")]
		)

	func _get_android_dependencies(
		_platform: EditorExportPlatform, _debug: bool
	) -> PackedStringArray:
		return PackedStringArray(DEPENDENCIES)

	func _get_android_manifest_application_element_contents(
		_platform: EditorExportPlatform, _debug: bool
	) -> String:
		return (
			'<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>'
			% AdsConfig.app_id()
		)
