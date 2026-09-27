## hud_controller.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1956-1958 (updateHUD), 2088-2115 (gameOverModal),
##        2173-2214 (lives pips, duration indicator) per spec §5.3
class_name HudController
extends Control
## Controller for the in-game HUD, the Run over sheet and the Pause sheet.
##
## DIVERGENCE(UI-SYSTEM): Hud.dc.html is the HUD's visual authority (interface
## spec §6.1). scenes/main.tscn holds only the node tree; every board literal is
## a constant here, applied by set_ui_scale(). Every HUD control anchors to
## %Frame, the arena outline drawn at GameRoot.arena_origin (spec §4.4).

## The boards' landscape reference frame. DIVERGENCE(UI-SYSTEM): System.dc.html — 844 × 390
const UI_REFERENCE_HEIGHT: float = 390.0
const UI_REFERENCE_WIDTH: float = 844.0
# DIVERGENCE(UI-SYSTEM): clamp bounds re-derived in M8.5 (interface spec §4.3).
# 0.75 keeps a 640×360 window legible (the M2.5 floor); 3.0 admits a
# 1170-px-tall phone (1170 / 390) and stops tablets inflating the chrome.
const MIN_UI_SCALE: float = 0.75
const MAX_UI_SCALE: float = 3.0

## HUD layout, base px measured from the arena frame (the board draws the frame
## at left 20, top 12). DIVERGENCE(UI-SYSTEM): Hud.dc.html
const FRAME_ALPHA: float = 0.28  # outline rgba(91,140,255,0.28)
const FRAME_RADIUS: int = 2
const SCORE_TOP: int = 10  # score block top 22 − 12
const SCORE_GAP: int = 4
const LEFT_COLUMN_X: int = 16  # lives column left 36 − 20
const LEFT_COLUMN_Y: int = 14  # top 26 − 12
const LEFT_COLUMN_GAP: int = 10
const LIFE_GAP: int = 6
const LIFE_GLYPH: int = 16
const PAUSE_INSET_X: int = 14  # pause right 34 − 20
const PAUSE_INSET_Y: int = 12  # top 24 − 12
const TIMER_BOTTOM: int = 14  # weapon timer bottom 26 − 12
const TIMER_GAP: int = 7
const TIMER_METER_WIDTH: int = 160

## The shield's fixed total for the indicator's fraction.
## PORT: web/src/tilt-to-live/TiltGame.ts:2190
const SHIELD_INDICATOR_TOTAL: float = 6.0
## The TS capitalises the WeaponType string (TiltGame.ts:2204; Types.ts:9-16).
const WEAPON_TIMER_NAMES: Dictionary[int, String] = {
	Types.WeaponType.NUKE: "Nuke",
	Types.WeaponType.MISSILES: "Missiles",
	Types.WeaponType.LIGHTNING: "Lightning",
	Types.WeaponType.LASER: "Laser",
	Types.WeaponType.VORTEX: "Vortex",
	Types.WeaponType.FREEZE: "Freeze",
	Types.WeaponType.SHIELD: "Shield",
}
## The timer's tint. DIVERGENCE(UI-SYSTEM): Hud.dc.html ("in the weapon's colour",
## interface spec §6.1); the colours are the Armory catalog dots, read through
## UiTheme's tokens (spec §4.1 — no private hex copies).
const WEAPON_TIMER_COLORS: Dictionary[int, Color] = {
	Types.WeaponType.VORTEX: UiTheme.COLOR_PLASMA,  # PORT: web/src/tilt-to-live/ArmoryUI.ts:100
	Types.WeaponType.MISSILES: UiTheme.COLOR_ION,  # PORT: web/src/tilt-to-live/ArmoryUI.ts:116
	Types.WeaponType.LASER: UiTheme.COLOR_ION,  # PORT: web/src/tilt-to-live/ArmoryUI.ts:132
	Types.WeaponType.NUKE: UiTheme.COLOR_FLARE,  # PORT: web/src/tilt-to-live/ArmoryUI.ts:147
	Types.WeaponType.FREEZE: UiTheme.ION_TEXT,  # PORT: web/src/tilt-to-live/ArmoryUI.ts:162
	Types.WeaponType.SHIELD: UiTheme.COLOR_LOCKED_IN,  # PORT: web/src/tilt-to-live/ArmoryUI.ts:176
	Types.WeaponType.LIGHTNING: UiTheme.COLOR_FLARE,  # PORT: web/src/tilt-to-live/ArmoryUI.ts:191
}

# Multiplier tiers for the score pulse and multiplier chip (D3).
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

var _run: RunController = null
var _state: GameStateMachine = null
var _ui_scale: float = 1.0
var _frame: Panel = null
var _score_block: VBoxContainer = null
var _left_column: VBoxContainer = null
var _lives_row: HBoxContainer = null
## The process frame and tier of the last score pulse (one pulse per frame).
var _pulse_frame: int = -1
var _pulse_tier: Color = Color.TRANSPARENT
var _weapon_timer: VBoxContainer = null
var _weapon_timer_label: Label = null
var _weapon_timer_meter: ProgressBar = null
var _life_on: ImageTexture = null
var _life_off: ImageTexture = null
var _shown_pips: Array[bool] = []
var _is_lives_dirty: bool = true
var _timer_type: int = -1
var _pause_button: Button = null
var _pause_panel: Control = null
var _pause_sheet: PauseSheet = null
var _run_over: RunOverSheet = null
var _resume_button: Button = null
var _pause_armory_button: Button = null
var _game_over_armory_button: Button = null
var _pickers: Array[ControlPicker] = []
# DIVERGENCE(HUD-FEEDBACK §4): last multiplier seen from score_changed, so the
# kill pulse's tier agrees with the multiplier chip's tier.
var _current_multiplier: int = 1
## DIVERGENCE(M11c P6): the tier colour the chip was last styled with.
var _styled_tier: Color = Color(0.0, 0.0, 0.0, 0.0)
var _score_pulse_tween: Tween = null
# PORT: web/src/tilt-to-live/TiltGame.ts:2089-2151 — the game-over modal fills
# 450 ms after the death tick, so the death tick's own live-goal completion
# (run_controller.gd step 8, evaluated after run_ended fires) reaches
# "Points earned" and the balance. Stopped by a Retry or a phase change during
# the window so a stale fill cannot reopen/overwrite the sheet.
var _run_over_timer: Timer = null
var _pending_final_score: int = 0
var _pending_stats: Types.GameStats = null

@onready var _score_label: Label = get_node_or_null("%ScoreLabel")
@onready var _best_label: Label = get_node_or_null("%BestLabel")
@onready var _multiplier_label: Label = get_node_or_null("%MultiplierLabel")
@onready var _game_over_panel: Control = get_node_or_null("%GameOverPanel")
@onready var _restart_button: Button = get_node_or_null("%RestartButton")


func _ready() -> void:
	if _score_label == null:
		_score_label = find_child("ScoreLabel", true, false) as Label
	if _score_label != null:
		_score_label.theme_type_variation = "ScoreText"
		# DIVERGENCE(HUD-FEEDBACK §4): resized is the source of truth for the
		# pulse's pivot — size changes with digit count and font size, not
		# only on viewport resize.
		_score_label.resized.connect(_on_score_label_resized)
		UiTheme.legible_over_play(_score_label)
	if _best_label == null:
		_best_label = find_child("BestLabel", true, false) as Label
	if _best_label != null:
		_best_label.theme_type_variation = "MonoFaintText"
		UiTheme.legible_over_play(_best_label)
	if _multiplier_label == null:
		_multiplier_label = find_child("MultiplierLabel", true, false) as Label
	if _multiplier_label != null:
		_multiplier_label.theme_type_variation = "ChipText"
	if _game_over_panel == null:
		_game_over_panel = find_child("GameOverPanel", true, false) as Control
	_run_over = _game_over_panel as RunOverSheet
	if _run_over != null:
		_run_over.milestones_requested.connect(_on_milestones_requested)
	if _restart_button == null:
		_restart_button = find_child("RestartButton", true, false) as Button

	_run_over_timer = Timer.new()
	_run_over_timer.name = "RunOverTimer"
	_run_over_timer.one_shot = true
	add_child(_run_over_timer)
	_run_over_timer.timeout.connect(_on_run_over_timer_timeout)

	_frame = find_child("Frame", true, false) as Panel
	_score_block = find_child("ScoreBlock", true, false) as VBoxContainer
	_left_column = find_child("LeftColumn", true, false) as VBoxContainer
	_lives_row = find_child("LivesRow", true, false) as HBoxContainer
	_weapon_timer = find_child("WeaponTimer", true, false) as VBoxContainer
	_weapon_timer_label = find_child("WeaponTimerLabel", true, false) as Label
	_weapon_timer_meter = find_child("WeaponTimerMeter", true, false) as ProgressBar
	if _weapon_timer_label != null:
		UiTheme.legible_over_play(_weapon_timer_label)

	if _game_over_panel != null:
		_game_over_panel.visible = false

	if _restart_button != null:
		_restart_button.pressed.connect(_on_restart_pressed)
		_restart_button.gui_input.connect(_on_restart_button_gui_input)

	GameEvents.score_changed.connect(_on_score_changed)
	GameEvents.enemy_killed.connect(_on_enemy_killed)
	GameEvents.run_ended.connect(_on_run_ended)
	GameEvents.phase_changed.connect(_on_phase_changed)

	_pause_button = find_child("PauseButton", true, false) as Button
	if _pause_button != null:
		_pause_button.pressed.connect(_on_pause_pressed)

	_pause_panel = find_child("PausePanel", true, false) as Control
	if _pause_panel != null:
		_pause_panel.visible = false

	_pause_sheet = _pause_panel as PauseSheet
	var restart_run: Button = find_child("RestartRunButton", true, false) as Button
	if restart_run != null:
		restart_run.pressed.connect(_on_restart_run_pressed)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1392-1393, :1428-1430 (both call returnToMenu)
	for quit_name: String in ["QuitToMenuButton", "GameOverMenuButton"]:
		var quit: Button = find_child(quit_name, true, false) as Button
		if quit != null:
			quit.pressed.connect(_on_quit_to_menu_pressed)
	var pause_settings: Button = find_child("PauseSettingsButton", true, false) as Button
	if pause_settings != null:
		pause_settings.pressed.connect(_on_settings_pressed)
	var calibrate: Button = find_child("CalibrateButton", true, false) as Button
	if calibrate != null:
		calibrate.pressed.connect(_on_calibrate_pressed)
	var sound: CheckButton = find_child("SoundSwitch", true, false) as CheckButton
	if sound != null:
		sound.toggled.connect(_on_sound_toggled)
	var music: CheckButton = find_child("MusicSwitch", true, false) as CheckButton
	if music != null:
		music.toggled.connect(_on_music_toggled)

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


func _process(_delta: float) -> void:
	# M11a R12: the menu hides LivesRow and WeaponTimer; reading the idle run here
	# would show them again.
	if _run == null or (_state != null and _state.phase == Types.GamePhase.MENU):
		return
	_show_lives(lives_pips(_run.lives, _run.max_lives))
	_show_weapon_timer(weapon_timer_for(_run.player, _run.weapons.active_weapons))


## Binds the live run the HUD reads each frame. PORT: web/src/tilt-to-live/TiltGame.ts:2173-2214
## — updateHUD reads this.lives, this.player and this.weapons directly; the port
## hands the HUD the same objects once, from GameRoot._ready().
func bind_run(run: RunController, state: GameStateMachine) -> void:
	_run = run
	_state = state


## Scales the HUD to the viewport: the Theme, the frame and every board offset.
func set_ui_scale(scale: float) -> void:
	_ui_scale = scale
	theme = UiTheme.build(scale)
	if _frame != null:
		_frame.add_theme_stylebox_override(
			"panel",
			UiTheme.flat(
				Color.TRANSPARENT,
				UiTheme.tint(UiTheme.COLOR_ION, FRAME_ALPHA),
				UiTheme.px(FRAME_RADIUS, scale)
			)
		)
	if _score_block != null:
		_score_block.offset_top = SCORE_TOP * scale
		_score_block.offset_bottom = _score_block.offset_top
		_score_block.add_theme_constant_override("separation", UiTheme.px(SCORE_GAP, scale))
	if _left_column != null:
		_left_column.offset_left = LEFT_COLUMN_X * scale
		_left_column.offset_top = LEFT_COLUMN_Y * scale
		_left_column.add_theme_constant_override("separation", UiTheme.px(LEFT_COLUMN_GAP, scale))
	if _lives_row != null:
		_lives_row.add_theme_constant_override("separation", UiTheme.px(LIFE_GAP, scale))
	_life_on = UiTheme.svg_texture(
		UiTheme.ship_glyph_svg(UiTheme.TEXT_SECONDARY, LIFE_GLYPH), scale
	)
	_life_off = UiTheme.svg_texture(
		UiTheme.ship_glyph_svg(UiTheme.COLOR_LINE_STRONG, LIFE_GLYPH), scale
	)
	_is_lives_dirty = true
	if _pause_button != null:
		var side: float = UiTheme.TOUCH_TARGET * scale
		_pause_button.custom_minimum_size = Vector2(side, side)
		_pause_button.offset_right = -PAUSE_INSET_X * scale
		_pause_button.offset_left = _pause_button.offset_right - side
		_pause_button.offset_top = PAUSE_INSET_Y * scale
		_pause_button.offset_bottom = _pause_button.offset_top + side
		_pause_button.icon = UiTheme.svg_texture(UiTheme.ICON_PAUSE, scale)
	if _weapon_timer != null:
		_weapon_timer.offset_bottom = -TIMER_BOTTOM * scale
		_weapon_timer.offset_top = _weapon_timer.offset_bottom
		_weapon_timer.add_theme_constant_override("separation", UiTheme.px(TIMER_GAP, scale))
	if _weapon_timer_meter != null:
		_weapon_timer_meter.custom_minimum_size = Vector2(
			TIMER_METER_WIDTH * scale, UiTheme.px(UiTheme.METER_HEIGHT, scale)
		)
	_timer_type = -1
	if _multiplier_label != null:
		_style_multiplier()
	if _pause_sheet != null:
		_pause_sheet.set_ui_scale(scale)
	if _run_over != null:
		_run_over.set_ui_scale(scale)
	for picker: ControlPicker in _pickers:
		picker.set_ui_scale(scale)
	for button: Button in [_pause_armory_button, _game_over_armory_button]:
		if button != null:
			button.custom_minimum_size.y = UiTheme.TOUCH_TARGET * scale


## Shows or hides the pause overlay without changing the phase.
## PORT: web/src/tilt-to-live/TiltGame.ts:2346 (hidden under the Armory), :2381 (restored)
func set_pause_panel_visible(is_visible: bool) -> void:
	if _pause_panel != null:
		_pause_panel.visible = is_visible
		if is_visible:
			_refresh_pause_sheet()


## The ui_scale implied by a viewport size: the short side against 390 and the
## long side against 844, whichever is smaller — width can shrink the chrome,
## never grow it (interface spec §4.3, ruled 2026-09-23).
static func ui_scale_for(viewport: Vector2) -> float:
	var short_side: float = minf(viewport.x, viewport.y)
	var long_side: float = maxf(viewport.x, viewport.y)
	return clampf(
		minf(short_side / UI_REFERENCE_HEIGHT, long_side / UI_REFERENCE_WIDTH),
		MIN_UI_SCALE,
		MAX_UI_SCALE
	)


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


## One entry per life slot, true = remaining; empty for a one-life run.
## PORT: web/src/tilt-to-live/TiltGame.ts:2173-2185
static func lives_pips(lives: int, max_lives: int) -> Array[bool]:
	var pips: Array[bool] = []
	if max_lives > 1:
		for i: int in range(max_lives):
			pips.append(i < lives)
	return pips


## The duration indicator: the shield if up, else the timed weapon with the
## most time left. PORT: web/src/tilt-to-live/TiltGame.ts:2187-2214
static func weapon_timer_for(
	player: PlayerShip, active_weapons: Array[Types.ActiveWeapon]
) -> WeaponTimer:
	var reading: WeaponTimer = WeaponTimer.new()
	if player.has_shield():
		reading.is_shown = true
		reading.weapon_type = Types.WeaponType.SHIELD
		reading.remaining = maxf(0.0, player.shield_timer)
		reading.fraction = clampf(reading.remaining / SHIELD_INDICATOR_TOTAL, 0.0, 1.0)
		return reading
	var active: Types.ActiveWeapon = null
	for w: Types.ActiveWeapon in active_weapons:
		if w.duration > 0.0 and (active == null or w.duration > active.duration):
			active = w
	if active != null and active.max_duration > 0.0:
		reading.is_shown = true
		reading.weapon_type = active.type
		reading.remaining = maxf(0.0, active.duration)
		reading.fraction = clampf(reading.remaining / active.max_duration, 0.0, 1.0)
	return reading


## "SHIELD 1.6s". PORT: web/src/tilt-to-live/TiltGame.ts:2192, :2205
## DIVERGENCE(UI-SYSTEM): Hud.dc.html — the name is a caps label.
static func weapon_timer_text(reading: WeaponTimer) -> String:
	return "%s %.1fs" % [WEAPON_TIMER_NAMES[reading.weapon_type].to_upper(), reading.remaining]


## Gathers what gameOverModal shows. PORT: web/src/tilt-to-live/TiltGame.ts:2088-2122
## `run` may be null (tests build the HUD alone); the run-dependent figures then
## keep RunResult's defaults.
static func run_result_for(
	final_score: int, stats: Types.GameStats, run: RunController
) -> RunOverSheet.RunResult:
	var result: RunOverSheet.RunResult = RunOverSheet.RunResult.new()
	result.score = final_score
	if stats != null:
		result.kills = stats.kills  # PORT: :2104
		result.best_chain = int(maxf(1.0, stats.max_multiplier))  # PORT: :2105
		result.time_text = GameStateMachine.format_time(stats.survival_time)  # PORT: :2090
	if run != null:
		# PORT-NOTE: :2091 reads settings.mode; the run's captured mode is the
		# same value in the TS and the only correct one here (M10 R4).
		var mode: GameOptionsManager.ModeConfig = run.options.get_mode_config(run.mode)
		result.mode_name = mode.name
		result.mode_multiplier = mode.score_multiplier
		if run.scores.is_new_best and run.scores.best_score_diff > 0:  # PORT: :2097
			result.best_diff = run.scores.best_score_diff
		var milestone_points: int = 0
		for goal: GoalManager.Goal in run.run_completed_goals:
			milestone_points += goal.reward_points  # PORT: :2111-2114
		# PORT: :2118 — coins are a second income stream folded into the one total.
		result.earned = (
			maxi(run.points_earned_this_run, milestone_points) + run.coins.points_from_coins
		)
		result.milestones = run.run_completed_goals.duplicate()  # PORT: :2132
		result.balance = run.progression.data.points  # PORT: :2119
	return result


# PORT-NOTE: updateHUD's mode badge (TiltGame.ts:2158-2162) is not ported —
# Hud.dc.html draws none; Pause and Run over name the mode (M10 R10).
func _on_score_changed(score: int, multiplier: int, best_score: int) -> void:
	# DIVERGENCE(UI-SYSTEM): Hud.dc.html — grouped Mono numerals, "7×" Chip.
	if _score_label != null:
		_score_label.text = UiTheme.group_digits(score)
	_current_multiplier = multiplier
	if _multiplier_label != null:
		_multiplier_label.text = "%d×" % multiplier
		_multiplier_label.visible = multiplier > 1
		# DIVERGENCE(M11c P6): rebuild the chip only when its tier colour changes.
		if tier_color_for(multiplier) != _styled_tier:
			_style_multiplier()
	if _best_label != null:
		# DIVERGENCE(M11c review): the TS best only updates when a run ends, so the HUD
		# kept "BEST 590" under a 3,640 score. Past a previous best it says so.
		var is_new_best: bool = best_score > 0 and score > best_score
		_best_label.text = (
			"NEW BEST" if is_new_best else "BEST %s" % UiTheme.group_digits(best_score)
		)
		if is_new_best:
			_best_label.add_theme_color_override("font_color", UiTheme.COLOR_FLARE)
		else:
			_best_label.remove_theme_color_override("font_color")


# DIVERGENCE(HUD-FEEDBACK §4): the multiplier sits permanently in its tier
# colour (D2), now as a Chip: tier text, 12% fill, 45% border (System.dc.html).
func _style_multiplier() -> void:
	var tier: Color = tier_color_for(_current_multiplier)
	_styled_tier = tier
	_multiplier_label.add_theme_color_override("font_color", tier)
	_multiplier_label.add_theme_stylebox_override("normal", UiTheme.chip_style(tier, _ui_scale))


# DIVERGENCE(HUD-FEEDBACK §4): the score label pulses and flashes the tier
# colour on every kill, replacing the sim's kill-site floating texts (D1/D2).
# Tier comes from the last score_changed multiplier so both handlers agree.
# DIVERGENCE(M11c review, power-up FPS): a mass kill (a nuke clears ~150 dots in one
# tick) restarted the tween once per kill; every restart in a frame starts from the
# same pulse, so one per frame looks the same. A later kill in the frame restarts it
# only when the tier changed, so the last tier still wins.
func _on_enemy_killed(_enemy: Types.Enemy, _weapon_type: Types.WeaponType) -> void:
	if _score_label == null:
		return
	var tier: Color = tier_color_for(_current_multiplier)
	var frame: int = Engine.get_process_frames()
	if frame == _pulse_frame and tier == _pulse_tier:
		return
	_pulse_frame = frame
	_pulse_tier = tier
	if _score_pulse_tween != null:
		_score_pulse_tween.kill()

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


func _show_lives(pips: Array[bool]) -> void:
	if _lives_row == null or (not _is_lives_dirty and pips == _shown_pips):
		return
	_is_lives_dirty = false
	_shown_pips = pips
	for child: Node in _lives_row.get_children():
		_lives_row.remove_child(child)
		child.queue_free()
	for is_filled: bool in pips:
		var icon: TextureRect = TextureRect.new()
		icon.texture = _life_on if is_filled else _life_off
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lives_row.add_child(icon)
	_lives_row.visible = not pips.is_empty()


func _show_weapon_timer(reading: WeaponTimer) -> void:
	if _weapon_timer == null:
		return
	_weapon_timer.visible = reading.is_shown
	if not reading.is_shown:
		return
	_weapon_timer_label.text = weapon_timer_text(reading)
	_weapon_timer_meter.value = reading.fraction
	if int(reading.weapon_type) == _timer_type:
		return
	_timer_type = reading.weapon_type
	var tint: Color = WEAPON_TIMER_COLORS.get(reading.weapon_type, UiTheme.COLOR_ION)
	_weapon_timer_label.add_theme_color_override("font_color", tint)
	_weapon_timer_meter.add_theme_stylebox_override(
		"fill", UiTheme.flat(tint, Color.TRANSPARENT, UiTheme.px(UiTheme.METER_RADIUS, _ui_scale))
	)


func _on_run_ended(final_score: int, stats: Types.GameStats) -> void:
	if _game_over_panel == null:
		return
	_pending_final_score = final_score
	_pending_stats = stats
	# PORT: web/src/tilt-to-live/TiltGame.ts:2151 — fill and show the sheet 450 ms
	# after the death tick, not inside run_ended's own emission (I-1).
	_run_over_timer.start(0.45)


func _on_run_over_timer_timeout() -> void:
	if _game_over_panel == null or _run_over == null:
		return
	# Guard: a Retry or a phase change during the 450 ms window (both stop
	# _run_over_timer below) must drop this fill, and a node that left the tree
	# cannot process the timer that would have fired it.
	if not is_inside_tree():
		return
	# I1: GameRoot._ready() (and its `settings`) has not necessarily run before
	# HudController._ready() calls _sync_pickers() the first time — HudController
	# is GameRoot's descendant, so the ancestor's _ready() runs after this
	# node's — so the death screen's picker shows no active scheme until the
	# player changes it. Re-syncing whenever this surface opens covers it.
	_sync_pickers()
	_run_over.show_result(run_result_for(_pending_final_score, _pending_stats, _run))
	if _run != null:
		# PORT: web/src/tilt-to-live/TiltGame.ts:2124-2130 (M11a R17)
		_run_over.set_coins(_run.coins.coins_collected, _run.coins.points_from_coins)
	_game_over_panel.visible = true


func _on_phase_changed(phase: Types.GamePhase) -> void:
	# M11a R12: the in-run HUD shows only outside the menu.
	var in_menu: bool = phase == Types.GamePhase.MENU
	for node: Control in [_score_block, _pause_button]:
		if node != null:
			node.visible = not in_menu
	# DIVERGENCE(M11c review): the menu's right column covers half the arena, so the
	# frame's outline read as a border around half the screen. self_modulate hides the
	# panel's own outline only; the HUD controls it parents are unaffected.
	if _frame != null:
		_frame.self_modulate.a = 0.0 if in_menu else 1.0
	if in_menu:
		for node: Control in [_lives_row, _weapon_timer]:
			if node != null:
				node.visible = false
		# The next run's first reading must redraw the row, even with the same pips.
		_is_lives_dirty = true
	# PORT: web/src/tilt-to-live/TiltGame.ts:1612-1613 — resetRun hides both modals
	# before startCinematic sets 'cinematic' (:1525-1526), so CINEMATIC hides them too (M11b R9).
	if phase != Types.GamePhase.PLAYING and phase != Types.GamePhase.CINEMATIC and not in_menu:
		return
	_run_over_timer.stop()
	if _game_over_panel != null:
		_game_over_panel.visible = false
	if _pause_panel != null:
		_pause_panel.visible = false


func _on_restart_pressed() -> void:
	_run_over_timer.stop()
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


# I3 (DIVERGENCE M2.5 §6.1), now interface spec §4.4: the frame is the
# playfield, inset by GameRoot.arena_origin; every HUD control is its child.
# Null-tolerant: tests build the HUD without a GameRoot and keep a full-rect frame.
func _apply_arena_origin() -> void:
	if _frame == null:
		return
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	var origin: Vector2 = root.arena_origin if root != null else Vector2.ZERO
	_frame.offset_left = origin.x
	_frame.offset_top = origin.y
	_frame.offset_right = -origin.x
	_frame.offset_bottom = -origin.y


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
		_refresh_pause_sheet()


## PORT: web/src/tilt-to-live/TiltGame.ts:1436-1438, :1457-1459
func _on_armory_pressed() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root == null:
		return
	root.open_armory()


## bindGameOverClicks' target. PORT: web/src/tilt-to-live/GoalsHUD.ts:131-134
func _on_milestones_requested() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root != null:
		root.open_all_goals_modal()


# PORT: web/src/tilt-to-live/TiltGame.ts:1619-1630 — the modal is populated as it opens.
func _refresh_pause_sheet() -> void:
	_sync_pickers()
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if _pause_sheet == null or root == null:
		return
	if _run != null and _state != null:
		var mode: GameOptionsManager.ModeConfig = _run.options.get_mode_config(_run.mode)
		_pause_sheet.set_stats(
			_run.scores.stats.score, GameStateMachine.format_time(_state.elapsed), mode.name
		)
	_pause_sheet.set_switches(
		root.options.settings.sfx_enabled, root.options.settings.music_enabled
	)


## Restart run (Pause.dc.html; interface spec §5 — backed by GameRoot.restart_run()).
func _on_restart_run_pressed() -> void:
	if _pause_panel != null:
		_pause_panel.visible = false
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root != null:
		root.restart_run()


## PORT: web/src/tilt-to-live/TiltGame.ts:1465-1467 (btn-tilt-calibrate-pause)
func _on_calibrate_pressed() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root != null:
		root.calibrate_gyro()


## PORT: web/src/tilt-to-live/TiltGame.ts:1396-1403
func _on_sound_toggled(is_on: bool) -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root != null:
		root.set_sfx_enabled(is_on)


## PORT: web/src/tilt-to-live/TiltGame.ts:1405-1416
func _on_music_toggled(is_on: bool) -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root != null:
		root.set_music_enabled(is_on)


func _on_scheme_chosen(scheme: Types.ControlScheme) -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root == null:
		return
	root.set_control_scheme(scheme)
	_sync_pickers()


## Quit to menu (Pause) and Menu (Run over). PORT: web/src/tilt-to-live/TiltGame.ts:1392-1393,
## :1428-1430
func _on_quit_to_menu_pressed() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root != null:
		root.return_to_menu()


## Pause's Settings. PORT: web/src/tilt-to-live/TiltGame.ts:1418-1420
func _on_settings_pressed() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root != null:
		root.open_options_from_pause()


func _sync_pickers() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root == null or root.settings == null:
		return
	for picker: ControlPicker in _pickers:
		picker.set_active_scheme(root.settings.scheme)
	if _pause_sheet != null:
		# PORT: web/src/tilt-to-live/TiltGame.ts:2239-2244
		_pause_sheet.set_calibrate_shown(root.settings.scheme == Types.ControlScheme.GYRO)


## One reading of the duration indicator (TiltGame.ts:2187-2214's locals).
class WeaponTimer:
	extends RefCounted
	var is_shown: bool = false
	var weapon_type: Types.WeaponType = Types.WeaponType.SHIELD
	var remaining: float = 0.0
	var fraction: float = 0.0
