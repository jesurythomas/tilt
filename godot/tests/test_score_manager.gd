## test_score_manager.gd
## PORTS: nothing — new file, covers src/sim/score_manager.gd
extends GutTest
## Proves ScoreManager scoring, combo multipliers, close calls and text popups.

var _audio: AudioBank = null


func before_each() -> void:
	_audio = AudioBank.new()
	if FileAccess.file_exists(ScoreManager.BEST_SCORE_PATH):
		DirAccess.remove_absolute(ScoreManager.BEST_SCORE_PATH)


func after_each() -> void:
	if FileAccess.file_exists(ScoreManager.BEST_SCORE_PATH):
		DirAccess.remove_absolute(ScoreManager.BEST_SCORE_PATH)


func test_initial_state_and_reset() -> void:
	var sm: ScoreManager = ScoreManager.new()
	assert_eq(sm.stats.score, 0)
	assert_eq(sm.stats.multiplier, 1.0)
	assert_eq(sm.stats.kills, 0)
	assert_eq(sm.combo_count, 0)
	assert_eq(sm.floating_texts.size(), 0)

	sm.stats.score = 500
	sm.combo_count = 5
	sm.reset()
	assert_eq(sm.stats.score, 0, "reset clears score")
	assert_eq(sm.combo_count, 0, "reset clears combo count")


func test_register_kill_increments_kills_and_score() -> void:
	var sm: ScoreManager = ScoreManager.new()
	sm.register_kill(10.0, 20.0, Types.WeaponType.NUKE, _audio)
	assert_eq(sm.stats.kills, 1)
	assert_eq(sm.combo_count, 1)
	assert_eq(sm.stats.score, 10, "first kill gives 10 * 1 = 10 pts")
	assert_almost_eq(sm.combo_timer, 1.6, 0.01, "combo window is 1.6s")


func test_multiplier_increases_every_eight_kills_in_combo() -> void:
	var sm: ScoreManager = ScoreManager.new()
	for i: int in range(7):
		sm.register_kill(0.0, 0.0, Types.WeaponType.NUKE, _audio)
	assert_eq(sm.stats.multiplier, 1.0, "multiplier stays 1x before 8 kills")

	sm.register_kill(0.0, 0.0, Types.WeaponType.NUKE, _audio)
	assert_eq(sm.stats.multiplier, 2.0, "multiplier advances to 2x at 8th kill")
	assert_true(sm.floating_texts.size() > 0, "multiplier callout spawned")


func test_combo_timer_decays_and_resets_combo() -> void:
	var sm: ScoreManager = ScoreManager.new()
	sm.register_kill(0.0, 0.0, Types.WeaponType.NUKE, _audio)
	assert_eq(sm.combo_count, 1)

	sm.update(1.0)
	assert_eq(sm.combo_count, 1, "combo survives 1.0s")
	sm.update(0.7)
	assert_eq(sm.combo_count, 0, "combo resets to 0 after 1.7s (exceeding 1.6s window)")


func test_register_close_call_awards_bonus() -> void:
	var sm: ScoreManager = ScoreManager.new()
	sm.register_close_call(50.0, 50.0, _audio)
	assert_eq(sm.stats.close_calls, 1)
	assert_eq(sm.stats.score, 250, "close call gives 250 * 1 = 250 pts")
	assert_true(sm.floating_texts.size() > 0, "close call callout spawned")


func test_floating_text_updates_and_expires() -> void:
	var sm: ScoreManager = ScoreManager.new()
	sm.add_floating_text("TEST", 0.0, 0.0, Color.WHITE)
	assert_eq(sm.floating_texts.size(), 1)

	sm.update(0.5)
	assert_eq(sm.floating_texts.size(), 1, "text alive at 0.5s")
	assert_true(sm.floating_texts[0].y < 0.0, "floating text moves upward")

	sm.update(1.0)
	assert_eq(sm.floating_texts.size(), 0, "floating text expires after 1.5s total (> 1.1s)")


func test_finalize_game_updates_and_saves_best_score() -> void:
	var sm: ScoreManager = ScoreManager.new()
	sm.stats.score = 1200
	sm.finalize_game()
	assert_true(sm.is_new_best)
	assert_eq(sm.stats.best_score, 1200)

	var sm2: ScoreManager = ScoreManager.new()
	assert_eq(sm2.stats.best_score, 1200, "best score persisted and reloaded")
