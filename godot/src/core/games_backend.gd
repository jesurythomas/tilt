## games_backend.gd
## PORTS: nothing — new file (rulings PGS R1, R3,
## docs/superpowers/plans/2026-10-14-play-games-leaderboards.md)
class_name GamesBackend
extends RefCounted
## What `PlayGames` talks to. This base class is the null backend: Play Games is not there, so
## the game shows no leaderboard buttons; desktop, headless and the test suite get it.
## AndroidGamesBackend extends it and is the only file that names the plugin.

## A sign-in check or a sign-in finished.
signal sign_in_checked(is_signed_in: bool)
## The player signed out from Play Games' own screens (PGS R7).
signal signed_out


## True when Play Games is in this build.
func is_available() -> bool:
	return false


## Reads the launch's automatic sign-in; answers with sign_in_checked.
func check_sign_in() -> void:
	pass


## Shows Play Games' sign-in; answers with sign_in_checked.
func sign_in() -> void:
	pass


## Posts `score` to the board `leaderboard_id`.
func submit_score(_leaderboard_id: String, _score: int) -> void:
	pass


## Opens the board `leaderboard_id`, or every board when it is blank.
func show_leaderboard(_leaderboard_id: String) -> void:
	pass
