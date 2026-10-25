## peril_games_plugin.gd
## PORTS: nothing — new file (rulings PGS R1, R2,
## docs/superpowers/plans/2026-10-14-play-games-leaderboards.md)
@tool
extends EditorPlugin
## Hands the PerilGames AAR (built by tools/build_games_plugin.sh), the Play Games Services SDK
## and the game's APP_ID (GamesConfig) to Android exports, once the project ID is set; until
## then exports carry none of it. Editor-only; the game talks to the plugin through
## src/core/android_games_backend.gd.

var _export_plugin: PerilGamesExportPlugin = null


func _enter_tree() -> void:
	_export_plugin = PerilGamesExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


## The Android half: library, dependency and the manifest's APP_ID.
class PerilGamesExportPlugin:
	extends EditorExportPlugin

	## Keep in step with android/peril-games/build.gradle (there it is compileOnly).
	const DEPENDENCIES: Array[String] = ["com.google.android.gms:play-services-games-v2:22.1.0"]

	func _get_name() -> String:
		return "PerilGames"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## Paths are relative to res://addons.
	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if not GamesConfig.is_configured():
			return PackedStringArray()
		return PackedStringArray(
			["peril_games/bin/peril-games-%s.aar" % ("debug" if debug else "release")]
		)

	func _get_android_dependencies(
		_platform: EditorExportPlatform, _debug: bool
	) -> PackedStringArray:
		if not GamesConfig.is_configured():
			return PackedStringArray()
		return PackedStringArray(DEPENDENCIES)

	func _get_android_manifest_application_element_contents(
		_platform: EditorExportPlatform, _debug: bool
	) -> String:
		if not GamesConfig.is_configured():
			return ""
		return (
			'<meta-data android:name="com.google.android.gms.games.APP_ID" android:value="%s"/>'
			% GamesConfig.manifest_app_id()
		)
