## peril_billing_plugin.gd
## PORTS: nothing — new file (ruling IAP R1,
## docs/superpowers/plans/2026-10-25-remove-ads-purchase.md)
@tool
extends EditorPlugin
## Hands the PerilBilling AAR (built by tools/build_billing_plugin.sh) and the Play Billing
## Library to Android exports. The library's own manifest adds the BILLING permission.
## Editor-only; the game talks to the plugin through src/core/android_billing_backend.gd.

var _export_plugin: PerilBillingExportPlugin = null


func _enter_tree() -> void:
	_export_plugin = PerilBillingExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


## The Android half: library and dependency.
class PerilBillingExportPlugin:
	extends EditorExportPlugin

	## Keep in step with android/peril-billing/build.gradle (there it is compileOnly).
	const DEPENDENCIES: Array[String] = ["com.android.billingclient:billing:9.1.0"]

	func _get_name() -> String:
		return "PerilBilling"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## Paths are relative to res://addons.
	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(
			["peril_billing/bin/peril-billing-%s.aar" % ("debug" if debug else "release")]
		)

	func _get_android_dependencies(
		_platform: EditorExportPlatform, _debug: bool
	) -> PackedStringArray:
		return PackedStringArray(DEPENDENCIES)
