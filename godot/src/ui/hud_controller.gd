## hud_controller.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1956-1958 (updateHUD), 2088-2115 (gameOverModal)
##        per spec §5.3
class_name HudController
extends Control
## Controller for the in-game HUD and Game Over overlay.

@onready var _score_label: Label = get_node_or_null("%ScoreLabel")
@onready var _best_label: Label = get_node_or_null("%BestLabel")
@onready var _multiplier_label: Label = get_node_or_null("%MultiplierLabel")
@onready var _game_over_panel: Control = get_node_or_null("%GameOverPanel")
@onready var _final_score_label: Label = get_node_or_null("%FinalScoreLabel")
@onready var _final_kills_label: Label = get_node_or_null("%FinalKillsLabel")
@onready var _final_time_label: Label = get_node_or_null("%FinalTimeLabel")
@onready var _new_best_label: Label = get_node_or_null("%NewBestLabel")
@onready var _restart_button: Button = get_node_or_null("%RestartButton")


func _ready() -> void:
	if _score_label == null:
		_score_label = find_child("ScoreLabel", true, false) as Label
	if _best_label == null:
		_best_label = find_child("BestLabel", true, false) as Label
	if _multiplier_label == null:
		_multiplier_label = find_child("MultiplierLabel", true, false) as Label
	if _game_over_panel == null:
		_game_over_panel = find_child("GameOverPanel", true, false) as Control
	if _final_score_label == null:
		_final_score_label = find_child("FinalScoreLabel", true, false) as Label
	if _final_kills_label == null:
		_final_kills_label = find_child("FinalKillsLabel", true, false) as Label
	if _final_time_label == null:
		_final_time_label = find_child("FinalTimeLabel", true, false) as Label
	if _new_best_label == null:
		_new_best_label = find_child("NewBestLabel", true, false) as Label
	if _restart_button == null:
		_restart_button = find_child("RestartButton", true, false) as Button

	if _game_over_panel != null:
		_game_over_panel.visible = false

	if _restart_button != null:
		_restart_button.pressed.connect(_on_restart_pressed)

	GameEvents.score_changed.connect(_on_score_changed)
	GameEvents.run_ended.connect(_on_run_ended)
	GameEvents.phase_changed.connect(_on_phase_changed)


func _on_score_changed(score: int, multiplier: int, best_score: int) -> void:
	if _score_label != null:
		_score_label.text = str(score)
	if _multiplier_label != null:
		_multiplier_label.text = "%dx" % multiplier
		_multiplier_label.visible = multiplier > 1
	if _best_label != null:
		_best_label.text = "BEST %d" % best_score


func _on_run_ended(final_score: int, stats: Types.GameStats) -> void:
	if _game_over_panel == null:
		return

	if _final_score_label != null:
		_final_score_label.text = "SCORE: %d" % final_score
	if _final_kills_label != null:
		_final_kills_label.text = "KILLS: %d" % (stats.kills if stats != null else 0)
	if _final_time_label != null:
		var t: float = stats.survival_time if stats != null else 0.0
		var m: int = floori(t / 60.0)
		var s: int = floori(fmod(t, 60.0))
		_final_time_label.text = "TIME: %d:%02d" % [m, s]
	if _new_best_label != null:
		var is_best: bool = (
			final_score > 0 and final_score >= (stats.best_score if stats != null else 0)
		)
		_new_best_label.visible = is_best

	_game_over_panel.visible = true


func _on_phase_changed(phase: Types.GamePhase) -> void:
	if phase == Types.GamePhase.PLAYING and _game_over_panel != null:
		_game_over_panel.visible = false


func _on_restart_pressed() -> void:
	if _game_over_panel != null:
		_game_over_panel.visible = false
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root != null:
		root.restart_run()
