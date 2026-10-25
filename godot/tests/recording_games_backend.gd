## recording_games_backend.gd
## PORTS: nothing — test helper; records what PlayGames hands its backend
class_name RecordingGamesBackend
extends GamesBackend
## An available backend that keeps every call, so specs can assert them and answer with its
## signals.

## Calls in order: "check", "sign_in", "submit <board> <score>", "show <board>".
var calls: Array[String] = []


func is_available() -> bool:
	return true


func check_sign_in() -> void:
	calls.append("check")


func sign_in() -> void:
	calls.append("sign_in")


func submit_score(leaderboard_id: String, score: int) -> void:
	calls.append("submit %s %d" % [leaderboard_id, score])


func show_leaderboard(leaderboard_id: String) -> void:
	calls.append("show " + leaderboard_id)
