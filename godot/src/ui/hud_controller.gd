## hud_controller.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1956-1958 (updateHUD), 2088-2115 (gameOverModal)
##        per spec §5.3
class_name HudController
extends Control
## Controller for the in-game HUD, Game Over overlay and pause overlay.

# DIVERGENCE(M2.5 §7.2 / D6): main.tscn hardcoded 32/24/20px font sizes with no
# viewport response, which the parent spec's global constraints forbid. These
# are the base sizes; set_ui_scale() multiplies them. This is a bug fix, not a
# divergence from the TypeScript — the web game's HUD is CSS-scaled.
const BASE_SCORE_FONT: int = 44
const BASE_BEST_FONT: int = 22
const BASE_MULTIPLIER_FONT: int = 26
## Viewport minimum dimension at which ui_scale is 1.0.
const UI_SCALE_REFERENCE: float = 720.0
# DIVERGENCE(M2.5 §7.2 / D6): provisional clamp bounds on ui_scale, pending
# measurement in the M2.5 device pass.
const MIN_UI_SCALE: float = 0.75
const MAX_UI_SCALE: float = 2.0

var _pause_button: Button = null
var _pause_panel: Control = null
var _resume_button: Button = null
var _pickers: Array[ControlPicker] = []

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
		_restart_button.gui_input.connect(_on_restart_button_gui_input)

	GameEvents.score_changed.connect(_on_score_changed)
	GameEvents.run_ended.connect(_on_run_ended)
	GameEvents.phase_changed.connect(_on_phase_changed)

	_pause_button = find_child("PauseButton", true, false) as Button
	if _pause_button != null:
		_pause_button.pressed.connect(_on_pause_pressed)

	_pause_panel = find_child("PausePanel", true, false) as Control
	if _pause_panel != null:
		_pause_panel.visible = false

	_resume_button = find_child("ResumeButton", true, false) as Button
	if _resume_button != null:
		_resume_button.pressed.connect(_on_pause_pressed)

	for picker: Node in find_children("*", "ControlPicker", true, false):
		var typed: ControlPicker = picker as ControlPicker
		if typed != null:
			typed.scheme_chosen.connect(_on_scheme_chosen)
			_pickers.append(typed)
	_sync_pickers()

	set_ui_scale(ui_scale_for(get_viewport_rect().size))
	get_viewport().size_changed.connect(_on_viewport_resized)


## Scales HUD text and touch targets to the viewport.
func set_ui_scale(scale: float) -> void:
	if _score_label != null:
		_score_label.add_theme_font_size_override("font_size", int(BASE_SCORE_FONT * scale))
	if _best_label != null:
		_best_label.add_theme_font_size_override("font_size", int(BASE_BEST_FONT * scale))
	if _multiplier_label != null:
		_multiplier_label.add_theme_font_size_override(
			"font_size", int(BASE_MULTIPLIER_FONT * scale)
		)
	if _pause_button != null:
		_pause_button.custom_minimum_size = Vector2(
			ControlPicker.BASE_TOUCH_TARGET * scale, ControlPicker.BASE_TOUCH_TARGET * scale
		)
	for picker: ControlPicker in _pickers:
		picker.set_ui_scale(scale)


## The ui_scale implied by a viewport size.
static func ui_scale_for(viewport: Vector2) -> float:
	return clampf(minf(viewport.x, viewport.y) / UI_SCALE_REFERENCE, MIN_UI_SCALE, MAX_UI_SCALE)


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


func _on_restart_button_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_on_restart_pressed()


func _on_viewport_resized() -> void:
	set_ui_scale(ui_scale_for(get_viewport_rect().size))


func _on_pause_pressed() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root == null:
		return
	root.toggle_pause()
	if _pause_panel != null:
		_pause_panel.visible = root.is_paused()


func _on_scheme_chosen(scheme: Types.ControlScheme) -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root == null:
		return
	root.set_control_scheme(scheme)
	_sync_pickers()


func _sync_pickers() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root == null or root.settings == null:
		return
	for picker: ControlPicker in _pickers:
		picker.set_active_scheme(root.settings.scheme)
