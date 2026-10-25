## games_config.gd
## PORTS: nothing — new file (ruling PGS R2,
## docs/superpowers/plans/2026-10-14-play-games-leaderboards.md)
class_name GamesConfig
extends RefCounted
## The Play Games Services IDs, kept in project settings so the game and the export plugin
## (godot/addons/peril_games) read the same values. While the project ID is blank, exports leave
## Play Games out and the game shows no leaderboard buttons.

## The digits under the game's name on Play Console's Play Games Services configuration page.
const PROJECT_ID_SETTING: String = "peril/games/project_id"
## One board per mode (MVP R2), named as the modes are shown.
const LEADERBOARD_SETTINGS: Dictionary[Types.GameMode, String] = {
	Types.GameMode.CLASSIC: "peril/games/leaderboard_survival",
	Types.GameMode.GAUNTLET: "peril/games/leaderboard_corridor",
	Types.GameMode.CODE_RED: "peril/games/leaderboard_overdrive",
}


## Blank until the project ID is set.
static func project_id() -> String:
	return _text(PROJECT_ID_SETTING)


## True once the project ID is set and is all digits, as Play Console shows it.
static func is_configured() -> bool:
	var id: String = project_id()
	if id.is_empty():
		return false
	for digit: String in id:
		if digit < "0" or digit > "9":
			return false
	return true


## The manifest's com.google.android.gms.games.APP_ID value. "\u003" plus the first digit is
## that digit escaped, so aapt keeps the value a string; a bare number becomes an integer the
## SDK cannot read (the GPGS Unity plugin writes it the same way).
static func manifest_app_id() -> String:
	return "\\u003" + project_id()


## The mode's board, or blank while it has none.
static func leaderboard_id(mode: Types.GameMode) -> String:
	if not LEADERBOARD_SETTINGS.has(mode):
		return ""
	return _text(LEADERBOARD_SETTINGS[mode])


static func _text(setting: String) -> String:
	var value: Variant = ProjectSettings.get_setting(setting, "")
	if value is String:
		var text: String = value
		return text.strip_edges()
	return ""
