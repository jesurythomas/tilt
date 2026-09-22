## hud_controller.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1956-1958 (updateHUD), 2088-2115 (gameOverModal)
##        per spec §5.3
class_name HudController
extends Control
## Controller for the in-game HUD, Game Over overlay and pause overlay.

# Per spec §7.2: main.tscn hardcoded 32/24/20px font sizes with no viewport
# response, which the parent spec's global constraints forbid. These are the
# base sizes; set_ui_scale() multiplies them. This is a bug fix, not a
# divergence from the TypeScript — the web game's HUD is CSS-scaled. Carries
# no DIVERGENCE tag: spec §7.2 says this fix is not a divergence.
const BASE_SCORE_FONT: int = 44
const BASE_BEST_FONT: int = 22
const BASE_MULTIPLIER_FONT: int = 26
## Viewport minimum dimension at which ui_scale is 1.0.
const UI_SCALE_REFERENCE: float = 720.0
# Per spec §7.2: provisional clamp bounds on ui_scale, pending measurement in
# the M2.5 device pass.
const MIN_UI_SCALE: float = 0.75
const MAX_UI_SCALE: float = 2.0

# Multiplier tiers for the score pulse and multiplier label (D3).
# DIVERGENCE(HUD-FEEDBACK §4): thresholds and colours are spec constants, not
# ported from the TS, which has no per-tier colour concept.
const TIER_THRESHOLD_YELLOW: int = 2  # DIVERGENCE(HUD-FEEDBACK §4)
const TIER_THRESHOLD_ORANGE: int = 5  # DIVERGENCE(HUD-FEEDBACK §4)
const TIER_THRESHOLD_MAGENTA: int = 10  # DIVERGENCE(HUD-FEEDBACK §4)
const TIER_THRESHOLD_CYAN: int = 20  # DIVERGENCE(HUD-FEEDBACK §4)
const TIER_WHITE: Color = Color.WHITE  # DIVERGENCE(HUD-FEEDBACK §4)
const TIER_YELLOW: Color = Color("#ffe14d")  # DIVERGENCE(HUD-FEEDBACK §4)
const TIER_ORANGE: Color = Color("#ffb14d")  # DIVERGENCE(HUD-FEEDBACK §4)
const TIER_MAGENTA: Color = Color("#ff3fd1")  # DIVERGENCE(HUD-FEEDBACK §4)
const TIER_CYAN: Color = Color("#3dfff0")  # DIVERGENCE(HUD-FEEDBACK §4)
## Score label scale at the peak of a kill pulse (D2).
const PULSE_SCALE: float = 1.18  # DIVERGENCE(HUD-FEEDBACK §4)
## Duration of the kill pulse's scale and colour tween, in seconds (D2).
const PULSE_SECONDS: float = 0.22  # DIVERGENCE(HUD-FEEDBACK §4)

var _pause_button: Button = null
var _pause_panel: Control = null
var _resume_button: Button = null
var _pause_armory_button: Button = null
var _game_over_armory_button: Button = null
var _pickers: Array[ControlPicker] = []
var _score_margin: MarginContainer = null
# I3: the scene-authored offsets, captured before _apply_arena_origin() ever
# runs. Used verbatim when no GameRoot is present (tests build the HUD alone).
var _fallback_score_top: float = 0.0
var _fallback_pause_right: float = 0.0
var _fallback_pause_top: float = 0.0
# DIVERGENCE(HUD-FEEDBACK §4): last multiplier seen from score_changed, so the
# kill pulse's tier agrees with the multiplier label's tier.
var _current_multiplier: int = 1
var _score_pulse_tween: Tween = null

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
	if _score_label != null:
		# DIVERGENCE(HUD-FEEDBACK §4): resized is the source of truth for the
		# pulse's pivot — size changes with digit count and font size, not
		# only on viewport resize.
		_score_label.resized.connect(_on_score_label_resized)
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
	GameEvents.enemy_killed.connect(_on_enemy_killed)
	GameEvents.run_ended.connect(_on_run_ended)
	GameEvents.phase_changed.connect(_on_phase_changed)

	_score_margin = find_child("ScoreMargin", true, false) as MarginContainer
	if _score_margin != null:
		_fallback_score_top = _score_margin.offset_top

	_pause_button = find_child("PauseButton", true, false) as Button
	if _pause_button != null:
		_pause_button.pressed.connect(_on_pause_pressed)
		_fallback_pause_right = _pause_button.offset_right
		_fallback_pause_top = _pause_button.offset_top

	_pause_panel = find_child("PausePanel", true, false) as Control
	if _pause_panel != null:
		_pause_panel.visible = false

	_resume_button = find_child("ResumeButton", true, false) as Button
	if _resume_button != null:
		_resume_button.pressed.connect(_on_pause_pressed)

	# PORT: web/src/tilt-to-live/TiltGame.ts:1436-1438, :1457-1459
	_pause_armory_button = find_child("PauseArmoryButton", true, false) as Button
	if _pause_armory_button != null:
		_pause_armory_button.pressed.connect(_on_armory_pressed)
	_game_over_armory_button = find_child("GameOverArmoryButton", true, false) as Button
	if _game_over_armory_button != null:
		_game_over_armory_button.pressed.connect(_on_armory_pressed)

	for picker: Node in find_children("*", "ControlPicker", true, false):
		var typed: ControlPicker = picker as ControlPicker
		if typed != null:
			typed.scheme_chosen.connect(_on_scheme_chosen)
			_pickers.append(typed)
	_sync_pickers()

	set_ui_scale(ui_scale_for(get_viewport_rect().size))
	get_viewport().size_changed.connect(_on_viewport_resized)

	# I3: HudController is GameRoot's descendant, so GameRoot._ready() (and the
	# resize_canvas() call that first sets arena_origin) has not necessarily
	# run yet here. Deferring one frame lets it land before the HUD reads it.
	_apply_arena_origin.call_deferred()


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
	for button: Button in [_pause_armory_button, _game_over_armory_button]:
		if button != null:
			button.custom_minimum_size.y = ControlPicker.BASE_TOUCH_TARGET * scale


## Shows or hides the pause overlay without changing the phase.
## PORT: web/src/tilt-to-live/TiltGame.ts:2346 (hidden under the Armory), :2381 (restored)
func set_pause_panel_visible(is_visible: bool) -> void:
	if _pause_panel != null:
		_pause_panel.visible = is_visible
		if is_visible:
			_sync_pickers()


## The ui_scale implied by a viewport size.
static func ui_scale_for(viewport: Vector2) -> float:
	return clampf(minf(viewport.x, viewport.y) / UI_SCALE_REFERENCE, MIN_UI_SCALE, MAX_UI_SCALE)


## Tier colour for a multiplier, per D3's five-tier neon palette.
static func tier_color_for(multiplier: int) -> Color:
	if multiplier >= TIER_THRESHOLD_CYAN:
		return TIER_CYAN
	if multiplier >= TIER_THRESHOLD_MAGENTA:
		return TIER_MAGENTA
	if multiplier >= TIER_THRESHOLD_ORANGE:
		return TIER_ORANGE
	if multiplier >= TIER_THRESHOLD_YELLOW:
		return TIER_YELLOW
	return TIER_WHITE


func _on_score_changed(score: int, multiplier: int, best_score: int) -> void:
	if _score_label != null:
		_score_label.text = str(score)
	if _multiplier_label != null:
		_multiplier_label.text = "%dx" % multiplier
		_multiplier_label.visible = multiplier > 1
		# DIVERGENCE(HUD-FEEDBACK §4): multiplier label sits permanently in its tier colour (D2).
		_multiplier_label.modulate = tier_color_for(multiplier)
	if _best_label != null:
		_best_label.text = "BEST %d" % best_score
	_current_multiplier = multiplier


# DIVERGENCE(HUD-FEEDBACK §4): the score label pulses and flashes the tier
# colour on every kill, replacing the sim's kill-site floating texts (D1/D2).
# Tier comes from the last score_changed multiplier so both handlers agree.
func _on_enemy_killed(_enemy: Types.Enemy, _weapon_type: Types.WeaponType) -> void:
	if _score_label == null:
		return
	if _score_pulse_tween != null:
		_score_pulse_tween.kill()

	var tier: Color = tier_color_for(_current_multiplier)
	_score_label.scale = Vector2(PULSE_SCALE, PULSE_SCALE)
	_score_label.modulate = tier

	_score_pulse_tween = create_tween()
	_score_pulse_tween.set_parallel(true)
	(
		_score_pulse_tween
		. tween_property(_score_label, "scale", Vector2.ONE, PULSE_SECONDS)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_score_pulse_tween
		. tween_property(_score_label, "modulate", TIER_WHITE, PULSE_SECONDS)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


# DIVERGENCE(HUD-FEEDBACK §4): keeps the pulse's pivot at the label's centre
# as its size changes with digit count or font size, not only on resize.
func _on_score_label_resized() -> void:
	_score_label.pivot_offset = _score_label.size / 2.0


func _on_run_ended(final_score: int, stats: Types.GameStats) -> void:
	if _game_over_panel == null:
		return

	# I1: GameRoot._ready() (and its `settings`) has not necessarily run before
	# HudController._ready() calls _sync_pickers() the first time — HudController
	# is GameRoot's descendant, so the ancestor's _ready() runs after this
	# node's — so the death screen's picker shows no active scheme until the
	# player changes it. Re-syncing whenever this surface opens covers it.
	_sync_pickers()

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
	_apply_arena_origin()


# I3 (DIVERGENCE M2.5 §6.1): main.tscn anchors ScoreMargin and PauseButton to
# the viewport edge with fixed offsets, but GameRoot insets the playfield from
# the edge for phone bezels, camera cutouts and gesture bars (arena_origin).
# Null-tolerant: tests build the HUD without a GameRoot and keep the scene's
# authored offsets.
func _apply_arena_origin() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if _score_margin != null:
		_score_margin.offset_top = root.arena_origin.y if root != null else _fallback_score_top
	if _pause_button != null:
		_pause_button.offset_right = (
			-root.arena_origin.x if root != null else _fallback_pause_right
		)
		_pause_button.offset_top = root.arena_origin.y if root != null else _fallback_pause_top


func _on_pause_pressed() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root == null:
		return
	root.toggle_pause()
	if _pause_panel != null:
		_pause_panel.visible = root.is_paused()
	if root.is_paused():
		# I1: see the comment in _on_run_ended — the same _ready() ordering
		# gap leaves the pause overlay's picker unmarked until this surface
		# opens.
		_sync_pickers()


## PORT: web/src/tilt-to-live/TiltGame.ts:1436-1438, :1457-1459
func _on_armory_pressed() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root == null:
		return
	root.open_armory()


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
