## test_hud_controller.gd
## Verifies HUD signal response and game over display.
extends GutTest


func test_hud_score_changed_updates_labels() -> void:
	var hud: HudController = HudController.new()
	var score_lbl: Label = Label.new()
	score_lbl.name = "ScoreLabel"
	var mult_lbl: Label = Label.new()
	mult_lbl.name = "MultiplierLabel"
	var best_lbl: Label = Label.new()
	best_lbl.name = "BestLabel"

	hud.add_child(score_lbl)
	hud.add_child(mult_lbl)
	hud.add_child(best_lbl)
	add_child_autofree(hud)

	GameEvents.score_changed.emit(1500, 4, 3000)
	assert_eq(score_lbl.text, "1500")
	assert_eq(mult_lbl.text, "4x")
	assert_true(mult_lbl.visible)
	assert_eq(best_lbl.text, "BEST 3000")


func test_hud_run_ended_shows_game_over() -> void:
	var hud: HudController = HudController.new()
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "GameOverPanel"
	var final_score_lbl: Label = Label.new()
	final_score_lbl.name = "FinalScoreLabel"
	var final_kills_lbl: Label = Label.new()
	final_kills_lbl.name = "FinalKillsLabel"
	var final_time_lbl: Label = Label.new()
	final_time_lbl.name = "FinalTimeLabel"

	hud.add_child(panel)
	hud.add_child(final_score_lbl)
	hud.add_child(final_kills_lbl)
	hud.add_child(final_time_lbl)
	add_child_autofree(hud)

	var stats: Types.GameStats = Types.GameStats.new()
	stats.kills = 25
	stats.survival_time = 75.0
	stats.best_score = 5000

	GameEvents.run_ended.emit(4200, stats)
	assert_true(panel.visible, "GameOverPanel must be visible on run_ended")
	assert_eq(final_score_lbl.text, "SCORE: 4200")
	assert_eq(final_kills_lbl.text, "KILLS: 25")
	assert_eq(final_time_lbl.text, "TIME: 1:15")

	GameEvents.phase_changed.emit(Types.GamePhase.PLAYING)
	assert_false(panel.visible, "GameOverPanel hidden on return to playing")
