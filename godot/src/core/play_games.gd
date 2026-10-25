## play_games.gd
## PORTS: nothing — new file (rulings PGS R1-R5, R7,
## docs/superpowers/plans/2026-10-14-play-games-leaderboards.md)
# PORT-NOTE: no `class_name`, against CONVENTIONS §2. An autoload script cannot
# carry one (same as Ads, Telemetry, Haptics, Log and GameEvents).
extends Node
## Play Games Services: the launch's sign-in, a run's score to its mode's board, and the board
## screens. Autoloaded as `PlayGames`. GameRoot calls it, as it does Ads; swapping the vendor
## means replacing `backend`.

## Which sign-in answer is awaited.
enum Request { NONE, CHECK, SIGN_IN }

var backend: GamesBackend = null
var is_signed_in: bool = false

var _request: Request = Request.NONE
var _is_started: bool = false
## A board the player asked for while signed out; opened if the sign-in succeeds.
var _waiting_board: String = ""
var _is_board_waiting: bool = false


func _ready() -> void:
	# Built here, as Ads builds its backend (a static factory kept scripts alive at exit).
	if Engine.has_singleton(AndroidGamesBackend.SINGLETON):
		set_backend(AndroidGamesBackend.new(Engine.get_singleton(AndroidGamesBackend.SINGLETON)))
	else:
		set_backend(GamesBackend.new())


## Swaps the backend (tests use a recording one) and listens to it.
func set_backend(next: GamesBackend) -> void:
	if backend != null:
		backend.sign_in_checked.disconnect(_on_sign_in_checked)
		backend.signed_out.disconnect(_on_signed_out)
	backend = next
	backend.sign_in_checked.connect(_on_sign_in_checked)
	backend.signed_out.connect(_on_signed_out)
	reset_session()


## Forgets the sign-in and any waiting board, as at launch.
func reset_session() -> void:
	is_signed_in = false
	_request = Request.NONE
	_is_started = false
	_waiting_board = ""
	_is_board_waiting = false


## True when Play Games is in this build; the leaderboard buttons show only then (PGS R5).
func is_available() -> bool:
	return backend.is_available()


## Reads the launch's automatic sign-in, once per launch (PGS R3). GameRoot calls it after the
## first frame.
func start() -> void:
	if _is_started or not is_available():
		return
	_is_started = true
	_request = Request.CHECK
	backend.check_sign_in()


## A run in `mode` ended with `score`: it goes to the mode's board when the player is signed
## in, the score is above 0 and the board exists (PGS R4).
func submit_run(mode: Types.GameMode, score: int) -> void:
	var board: String = GamesConfig.leaderboard_id(mode)
	if not is_signed_in or score <= 0 or board.is_empty():
		return
	backend.submit_score(board, score)


## Opens the mode's board, or every board while that mode has none (PGS R5).
func show_leaderboard(mode: Types.GameMode) -> void:
	_show(GamesConfig.leaderboard_id(mode))


## Opens every board (PGS R5).
func show_all_leaderboards() -> void:
	_show("")


func _show(board: String) -> void:
	if not is_available():
		return
	if is_signed_in:
		backend.show_leaderboard(board)
		return
	# PGS R3: signed out, so the board waits for a sign-in. A launch check still out answers
	# first; only if it fails is the player asked.
	_waiting_board = board
	_is_board_waiting = true
	if _request == Request.NONE:
		_request = Request.SIGN_IN
		backend.sign_in()


func _on_sign_in_checked(signed_in: bool) -> void:
	var answered: Request = _request
	_request = Request.NONE
	is_signed_in = signed_in
	if not _is_board_waiting:
		return
	if signed_in:
		_is_board_waiting = false
		backend.show_leaderboard(_waiting_board)
	elif answered == Request.CHECK:
		_request = Request.SIGN_IN
		backend.sign_in()
	else:
		_is_board_waiting = false  # the player's own sign-in failed or was cancelled


func _on_signed_out() -> void:
	is_signed_in = false  # PGS R7
