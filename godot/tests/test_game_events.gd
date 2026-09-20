## test_game_events.gd
## PORTS: nothing — new file, covers src/core/game_events.gd
extends GutTest
## Proves the GameEvents autoload resolves and emits sim-to-UI signals.


func test_game_events_autoload_is_reachable() -> void:
	assert_not_null(GameEvents, "GameEvents autoload must be registered in project.godot")


func test_signals_exist_and_emit() -> void:
	watch_signals(GameEvents)
	GameEvents.score_changed.emit(100, 2, 500)
	assert_signal_emitted(GameEvents, "score_changed")

	var enemy: Types.Enemy = Types.Enemy.new()
	GameEvents.enemy_killed.emit(enemy, Types.WeaponType.NUKE)
	assert_signal_emitted(GameEvents, "enemy_killed")

	GameEvents.weapon_activated.emit(Types.WeaponType.NUKE)
	assert_signal_emitted(GameEvents, "weapon_activated")

	GameEvents.life_lost.emit(0)
	assert_signal_emitted(GameEvents, "life_lost")

	var stats: Types.GameStats = Types.GameStats.new()
	GameEvents.run_ended.emit(100, stats)
	assert_signal_emitted(GameEvents, "run_ended")

	GameEvents.goal_completed.emit("first_kill")
	assert_signal_emitted(GameEvents, "goal_completed")

	GameEvents.points_changed.emit(50)
	assert_signal_emitted(GameEvents, "points_changed")

	GameEvents.phase_changed.emit(Types.GamePhase.PLAYING)
	assert_signal_emitted(GameEvents, "phase_changed")
