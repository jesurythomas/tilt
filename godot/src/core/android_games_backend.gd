## android_games_backend.gd
## PORTS: nothing — new file (rulings PGS R1, R7,
## docs/superpowers/plans/2026-10-14-play-games-leaderboards.md)
class_name AndroidGamesBackend
extends GamesBackend
## The PerilGames Android plugin (android/peril-games/…/PerilGamesPlugin.java) behind
## GamesBackend. The only file in the game that names it.

## The plugin's singleton name (its manifest's org.godotengine.plugin.v2.PerilGames).
const SINGLETON: String = "PerilGames"

var _plugin: Object = null


func _init(plugin: Object) -> void:
	_plugin = plugin
	_plugin.connect("sign_in_checked", _on_sign_in_checked)
	_plugin.connect("signed_out", _on_signed_out)
	_plugin.connect("leaderboard_failed", _on_leaderboard_failed)


func is_available() -> bool:
	return true


# PORT-NOTE: the plugin is a JNI singleton with no script class, so its Java methods are
# reached by name, as android_ads_backend.gd reaches PerilAds.
func check_sign_in() -> void:
	_plugin.call("checkSignIn")


func sign_in() -> void:
	_plugin.call("signIn")


func submit_score(leaderboard_id: String, score: int) -> void:
	_plugin.call("submitScore", leaderboard_id, score)


func show_leaderboard(leaderboard_id: String) -> void:
	_plugin.call("showLeaderboard", leaderboard_id)


func _on_sign_in_checked(is_signed_in: bool, error: String) -> void:
	Log.info("games: signed_in=%s %s" % [is_signed_in, error])
	sign_in_checked.emit(is_signed_in)


func _on_signed_out() -> void:
	Log.info("games: signed out from Play Games")
	signed_out.emit()


func _on_leaderboard_failed(error: String) -> void:
	Log.info("games: leaderboard failed (%s)" % error)
