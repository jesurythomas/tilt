## game_state_machine.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1472-1648 (start, launchRun,
## returnToMenu, restart, startCinematic, stop, resetRun, togglePause,
## formatTime), per spec §5.1
class_name GameStateMachine
extends RefCounted
## Owns the game phase and the transitions between menu, playing and paused.
##
## PORT-NOTE: the TypeScript methods also drive the DOM (modals, body classes,
## the menu, the HUD), audio, progression, scores, the swarm, weapons, coins,
## the gauntlet maze, lives and the run tracker. None of those exist yet; each
## omission carries a module-tagged TODO below rather than being dropped
## silently. Nothing that does exist in M1 has been reordered.

## Current phase. PORT: web/src/tilt-to-live/TiltGame.ts:42
var phase: Types.GamePhase = Types.GamePhase.MENU
## Active mode. PORT: web/src/tilt-to-live/GameOptions.ts:79
var mode: Types.GameMode = Types.GameMode.CLASSIC
## Seconds of simulation since the run began. PORT: web/src/tilt-to-live/TiltGame.ts:109
var elapsed: float = 0.0

var _player: PlayerShip = null
var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _router: InputRouter = null
var _tilt: TiltInput = null
var _audio: AudioBank = null
var _options: GameOptionsManager = null
var _bounds: Vector2 = Vector2.ZERO
var _is_running: bool = false


func _init(
	player: PlayerShip,
	grid: VectorGrid,
	particles: ParticleEngine,
	router: InputRouter,
	tilt: TiltInput,
	audio: AudioBank,
	options: GameOptionsManager
) -> void:
	_player = player
	_grid = grid
	_particles = particles
	_router = router
	_tilt = tilt
	_audio = audio
	_options = options


## Keeps the arena size the transitions reset against.
func set_bounds(bounds: Vector2) -> void:
	_bounds = bounds


## Marks the sim running and enters the menu phase.
## PORT: web/src/tilt-to-live/TiltGame.ts:1472-1484
func start() -> void:
	# PORT-NOTE: resizeCanvas() (ts:1473) and the requestAnimationFrame loop
	# (ts:1482-1483) belong to GameRoot's _ready/_physics_process — there is
	# no canvas or animation frame in Godot's fixed-step model.
	_is_running = true
	phase = Types.GamePhase.MENU
	# TODO(M11): goalsHUD.setMenuMode(true), menu.show(), updateCursor().


## Switches to the requested mode and begins the entrance cinematic.
## PORT: web/src/tilt-to-live/TiltGame.ts:1486-1494
func launch_run(new_mode: Types.GameMode) -> void:
	mode = new_mode
	# TODO(M11): goalsHUD.setMenuMode(false), menu.hide().
	_audio.unlock()  # PORT: web/src/tilt-to-live/TiltGame.ts:1492
	start_cinematic()


## Leaves a run and returns to the menu, clearing input and the tilt sensor.
## PORT: web/src/tilt-to-live/TiltGame.ts:1496-1517
func return_to_menu() -> void:
	if phase == Types.GamePhase.MENU:
		return
	phase = Types.GamePhase.MENU
	_router.clear_movement_keys()
	_tilt.stop_listening()
	_audio.stop_music()  # PORT: web/src/tilt-to-live/TiltGame.ts:1501
	# TODO(M11): hide the pause and game-over modals, skip the cinematic,
	# goalsHUD.setMenuMode(true), menu.show(), updateCursor().
	# TODO(M11): document.body.classList.remove('tilt-playing') (TiltGame.ts:1512).
	# PORT-NOTE: TiltGame.ts:1514-1516's onReturnToPortal callback has no
	# port — the Godot build has no host portal to return to.


## Restarts the current mode from a fresh cinematic.
## PORT: web/src/tilt-to-live/TiltGame.ts:1519-1521
func restart() -> void:
	start_cinematic()


## Resets the run and begins the entrance cinematic for the active mode.
## PORT: web/src/tilt-to-live/TiltGame.ts:1523-1530
func start_cinematic() -> void:
	# TODO(M11): goalsHUD.setMenuMode(false) (TiltGame.ts:1524).
	reset_run(mode)
	# PORT-NOTE: TiltGame.ts:1526 sets phase = 'cinematic' here and
	# TiltEntranceCinematic drives the 600 ms cold open. The cinematic is M11
	# (spec §8), so M1 leaves the phase where reset_run() put it — PLAYING —
	# rather than entering a phase nothing can leave.
	# TODO(M11): set phase = CINEMATIC and start the entrance cinematic.


## Stops the sim and clears input and the tilt sensor.
## PORT: web/src/tilt-to-live/TiltGame.ts:1532-1545
func stop() -> void:
	_is_running = false
	_router.clear_movement_keys()
	_tilt.stop_listening()
	_audio.stop_music()  # PORT: web/src/tilt-to-live/TiltGame.ts:1536
	# TODO(M11): skip the cinematic.
	# PORT-NOTE: the rAF cancellation (ts:1541-1544) belongs to GameRoot,
	# same as the loop start noted in start().


## Resets state for a fresh run: centres the ship, resizes the grid, resets
## particles and enters the playing phase.
## PORT: web/src/tilt-to-live/TiltGame.ts:1547-1617
func reset_run(new_mode: Types.GameMode) -> void:
	mode = new_mode
	# PORT-NOTE: scores.setModeMultiplier (:1550) and setProgressionMultiplier (:1551)
	# are ported in run_controller.gd::reset_run, which owns the scores.

	# PORT: web/src/tilt-to-live/TiltGame.ts:1553-1557
	if _router.control_scheme == Types.ControlScheme.GYRO:
		_tilt.start_listening()
	else:
		_tilt.stop_listening()

	phase = Types.GamePhase.PLAYING
	# TODO(M11): document.body.classList.add('tilt-playing') (TiltGame.ts:1563).
	elapsed = 0.0
	# PORT-NOTE: TiltGame.ts:1565 also zeroes this.accumulator, the manual
	# rAF-loop accumulator driving fixed updates. Godot's fixed physics step
	# replaces that accumulator entirely, so there is nothing to port here.
	# PORT-NOTE: lives, maxLivesThisRun and setHitboxMultiplier (:1567-1570) are
	# ported in run_controller.gd::reset_run, as are pointsEarnedThisRun (:1566)
	# and the run tracker (:1578-1591); railProgress (:1575-1576) is not ported
	# (goals_hud.gd header).

	_player.reset(_bounds.x / 2.0, _bounds.y / 2.0)
	_router.mouse_pos = Vector2(_bounds.x / 2.0, _bounds.y / 2.0)
	_router.clear_movement_keys()
	_router.control_mode = Types.ControlMode.MOUSE

	# PORT-NOTE: swarm.setSpeedScale (:1599) and coins.reset() (:1601) are ported
	# in run_controller.gd::reset_run.
	_particles.reset()
	# PORT-NOTE: gauntletMaze.reset (:1604) is ported in run_controller.gd::reset_run (M10 R5).
	_grid.resize(_bounds.x, _bounds.y)
	# PORT-NOTE: setMuted/setSfxVolume/setMusicVolume (:1607-1610) are ported in
	# run_controller.gd::reset_run, which Retry and Restart run also reach (M5 R11).
	# TODO(M2): updateHUD().
	# TODO(M11): hide the pause and game-over modals (TiltGame.ts:1612-1613).
	# PORT-NOTE: goalsHUD.updateLive (:1615) is ported in run_controller.gd::reset_run.
	# TODO(M11): updateCursor() (TiltGame.ts:1616).


## Toggles between the playing and paused phases; no-op in any other phase.
## PORT: web/src/tilt-to-live/TiltGame.ts:1619-1642
func toggle_pause() -> void:
	if phase == Types.GamePhase.PLAYING:
		phase = Types.GamePhase.PAUSED
		_audio.stop_music()  # PORT: web/src/tilt-to-live/TiltGame.ts:1622
		# TODO(M11): populate and show the pause modal.
	elif phase == Types.GamePhase.PAUSED:
		phase = Types.GamePhase.PLAYING
		# TODO(M11): hide the pause modal.
		# PORT: web/src/tilt-to-live/TiltGame.ts:1638-1640
		if _options.settings.music_enabled:
			_audio.start_music()


## Formats elapsed seconds as `m:ss`.
## PORT: web/src/tilt-to-live/TiltGame.ts:1644-1648
static func format_time(secs: float) -> String:
	var m: int = floori(secs / 60.0)  # PORT: web/src/tilt-to-live/TiltGame.ts:1645-1646
	var s: int = floori(fmod(secs, 60.0))  # PORT: web/src/tilt-to-live/TiltGame.ts:1645-1646
	return "%d:%02d" % [m, s]
