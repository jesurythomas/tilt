## goals_hud.gd
## PORTS: web/src/tilt-to-live/GoalsHUD.ts (488 lines, source commit 7be9614)
class_name GoalsHUD
extends Control
## The milestone rail, the completion toast and the full Milestones screen.
##
## DIVERGENCE(UI-SYSTEM): Hud.dc.html (rail, toast) and Milestones.dc.html (the
## screen) are the visual authority (interface spec §6.5). Every board literal
## is a constant here; tokens come from UiTheme.
##
## PORT-NOTE: initDOM() (:59-106) appends three elements to the game container.
## Here the rail goes on the HUD's arena frame and the toast into the HUD's
## toast slot, where spec §6.5 places them; bind() takes those two hosts (M9
## plan R8) and, given none (tests), hangs both off this node. The Milestones
## screen is this node's own child.
##
## PORT-NOTE: updateLive() (:242-255) is split. Its evaluateLiveTotalGoals call
## is sim work and lives in RunController.update step 8 (spec §5.4 step 10); its
## rail write only changes on a completion, and every completion reaches
## render() through GameRoot's callbacks, so render() carries it.
##
## PORT-NOTE: TiltGame's second left rail (TiltGame.ts:1058-1078, railProgress at
## :2217-2225) is not ported (M9 plan R2).
##
## PORT-NOTE: bindGameOverClicks (:129-140) lives in RunOverSheet, which owns
## the run-over rows (M9 plan R1); HudController routes its signal to
## GameRoot.open_all_goals_modal().

## Rail. DIVERGENCE(UI-SYSTEM): Hud.dc.html — a 3 px ion line at top 11 over the
## frame's top 12, i.e. rising 1 px above the frame's edge.
const RAIL_HEIGHT: int = 3
const RAIL_RISE: int = 1
## Toast. DIVERGENCE(UI-SYSTEM): Hud.dc.html — Card at 92% panel, pad 9/12, gap 9,
## title 13/500, reward Mono 12 flare; spec §6.5 — message subtitle muted 12.
const TOAST_ALPHA: float = 0.92
const TOAST_PAD_Y: int = 9
const TOAST_PAD_X: int = 12
const TOAST_GAP: int = 9
const TOAST_TITLE_SIZE: int = 13
const TOAST_REWARD_SIZE: int = 12
const TOAST_SUBTITLE_SIZE: int = 12
## PORT: web/src/tilt-to-live/GoalsHUD.ts:209, :234
const GOAL_TOAST_SECONDS: float = 3.0
const MESSAGE_TOAST_SECONDS: float = 2.8
# I4: the message toast's ion ring (GoalsHUD.ts:217-220) lives on UiTheme as
# ICON_RING, next to ICON_CHECK (interface spec §4.1 — no file keeps a
# private copy of a token hex). See this task's UiTheme step below.

## Screen. DIVERGENCE(UI-SYSTEM): Milestones.dc.html — header padding 8/28/8/24
## and gap 12 (the Armory's), counter Mono 13, track 120×4 r2 with 8 px side
## margins, the points figure's 4 px gap to its unit, body padding 12/28/0/24,
## column gap 14, column stack gap 6, heading gap 10, card 58 tall with padding
## 0 12 and gap 11, mark 20 r4, content gap 3, bar 3 r2 with a 1 px top margin,
## points Mono 12/500, bottom fade 40.
const HEADER_PAD_Y: int = 8
const HEADER_PAD_RIGHT: int = 28
const HEADER_PAD_LEFT: int = 24
const HEADER_GAP: int = 12
const COUNTER_SIZE: int = 13
const TRACK_WIDTH: int = 120
const TRACK_HEIGHT: int = 4
const TRACK_RADIUS: int = 2
const TRACK_MARGIN: int = 8
const POINTS_GAP: int = 4
const BODY_PAD_TOP: int = 12
const BODY_PAD_RIGHT: int = 28
const BODY_PAD_LEFT: int = 24
const COLUMN_GAP: int = 14
const STACK_GAP: int = 6
const HEADING_GAP: int = 10
const CARD_HEIGHT: int = 58
const CARD_PAD_X: int = 12
const CARD_GAP: int = 11
const MARK_SIZE: int = 20
const MARK_RADIUS: int = 4
const CONTENT_GAP: int = 3
const BAR_HEIGHT: int = 3
const BAR_RADIUS: int = 2
const BAR_TOP: int = 1
const CARD_POINTS_SIZE: int = 12
const FADE_HEIGHT: int = 40
## Tier order and tints. PORT: web/src/tilt-to-live/GoalsHUD.ts:356-360 (the
## hexes are UiTheme's ion, plasma and flare)
const TIERS: Array[String] = ["Score", "Combat", "Mastery"]
const TIER_TINTS: Dictionary[String, Color] = {
	"Score": UiTheme.COLOR_ION,
	"Combat": UiTheme.COLOR_PLASMA,
	"Mastery": UiTheme.COLOR_FLARE,
}

## True while the menu is up; the rail hides. PORT: web/src/tilt-to-live/GoalsHUD.ts:16
var in_menu_mode: bool = false

var _goal_manager: GoalManager = null  # PORT: :9
var _progression: ProgressionManager = null  # PORT: :10
var _rail: Control = null  # PORT: :12 (railEl)
var _rail_fill: ColorRect = null
var _toast: PanelContainer = null  # PORT: :13 (toastContainerEl)
var _milestones_modal: Control = null  # PORT: :14 (milestonesModalEl)
var _toast_timer: Timer = null  # PORT: :17 (completedToastTimer)
var _is_evaluating_unlock_goals: bool = false  # PORT: :18
var _ui_scale: float = 1.0
var _inset: Vector2 = Vector2.ZERO
var _screen_margin: MarginContainer = null
var _header_margin: MarginContainer = null
var _header: HBoxContainer = null
var _back_button: Button = null
var _counter_label: Label = null
var _denom_label: Label = null
var _track_margin: MarginContainer = null
var _progress_track: Panel = null
var _progress_fill: Panel = null
var _points_row: HBoxContainer = null
var _points_label: Label = null
var _points_unit: Label = null
var _body_margin: MarginContainer = null
var _tier_columns: HBoxContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.build(_ui_scale)


## setupHotkey. PORT: web/src/tilt-to-live/GoalsHUD.ts:143-160
# PORT-NOTE: the INPUT/TEXTAREA guard (:147-150) has nothing to guard — the port
# has no text fields. Key repeats are ignored, as GameRoot's b/u keys ignore them.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo:
		return
	if (
		key.keycode == KEY_M
		and not key.ctrl_pressed
		and not key.meta_pressed
		and not key.alt_pressed
	):
		if is_modal_open():
			close_all_goals_modal()
		else:
			open_all_goals_modal()
	# PORT-NOTE(M-1): this Escape and GameRoot._unhandled_input's Escape
	# (game_root.gd:187-189) are two independent listeners, like the TS's two
	# window keydown listeners (GoalsHUD.ts:156-157, TiltGame.ts:1325). Neither
	# marks the event handled, so one Escape with the Armory open on top of
	# Milestones closes both, faithfully.
	elif key.keycode == KEY_ESCAPE and is_modal_open():
		close_all_goals_modal()


## The constructor. PORT: web/src/tilt-to-live/GoalsHUD.ts:20-37
## `rail_host` / `toast_host` are the HUD's arena frame and toast slot (R8).
# PORT-NOTE(B3): _init_dom() ends in render(), which calls check_unlock_goals()
# (:30-31, :105) before bind() calls _setup_listeners() (:109-115) — the TS
# order. Any unlock the player already owns completes here
# silently: no addPoints, no toast, only cumulative.totalPointsEarned moves.
# The explicit check_unlock_goals() below (:34-36) runs after the callbacks
# are installed but is a no-op — the goal is already completed. Preserved
# deliberately (LAW 2); see Open question 4.
func bind(
	goal_manager: GoalManager,
	progression: ProgressionManager,
	rail_host: Control = null,
	toast_host: Control = null
) -> void:
	_goal_manager = goal_manager
	_progression = progression

	# Wire progression into GoalManager here — this is the one place that
	# receives both managers (:24-28).
	_goal_manager.set_progression(_progression)

	_init_dom(rail_host if rail_host != null else self, toast_host if toast_host != null else self)
	_setup_listeners()

	# Catch unlocks the player already owned (:34-36).
	check_unlock_goals()


## Evaluates the unlock-family goals, guarded against the re-entry its own
## callbacks cause (they call render(), which calls this).
## PORT: web/src/tilt-to-live/GoalsHUD.ts:49-57
func check_unlock_goals() -> void:
	if _is_evaluating_unlock_goals:
		return
	_is_evaluating_unlock_goals = true
	_goal_manager.evaluate_unlock_goals()
	_is_evaluating_unlock_goals = false


## Scales the rail and the screen (HudController.ui_scale_for's value). `inset`
## is GameRoot.arena_origin; on mobile the screen's content is pulled in by it,
## as the Armory's is.
func set_ui_scale(scale: float, inset: Vector2 = Vector2.ZERO) -> void:
	_ui_scale = scale
	_inset = inset
	theme = UiTheme.build(scale)
	_layout()


## PORT: web/src/tilt-to-live/GoalsHUD.ts:162-164
func is_modal_open() -> bool:
	return _milestones_modal != null and _milestones_modal.visible


## PORT: web/src/tilt-to-live/GoalsHUD.ts:166-175
func set_menu_mode(in_menu: bool) -> void:
	in_menu_mode = in_menu
	if _rail != null:
		_rail.visible = not in_menu


## Legacy support: toggle modal. PORT: web/src/tilt-to-live/GoalsHUD.ts:177-184
func toggle_collapse() -> void:
	if is_modal_open():
		close_all_goals_modal()
	else:
		open_all_goals_modal()


## PORT: web/src/tilt-to-live/GoalsHUD.ts:189-210
func show_goal_toast(goal: GoalManager.Goal) -> void:
	if _toast == null:
		return
	_fill_toast(UiTheme.ICON_CHECK, goal.title, "", UiTheme.reward_text(goal.reward_points))
	_toast.visible = true
	_toast_timer.start(GOAL_TOAST_SECONDS)


## PORT: web/src/tilt-to-live/GoalsHUD.ts:212-235
func show_message_toast(title: String, subtitle: String, reward_badge: String = "") -> void:
	if _toast == null:
		return
	_fill_toast(UiTheme.ICON_RING, title, subtitle, reward_badge)
	_toast.visible = true
	_toast_timer.start(MESSAGE_TOAST_SECONDS)


## PORT: web/src/tilt-to-live/GoalsHUD.ts:257-283
# PORT-NOTE: the notches (:273-274) and the hover tag (:275-277) are not drawn:
# Hud.dc.html's rail is a bare line (DIVERGENCE(UI-SYSTEM), spec §6.5).
func render() -> void:
	if _rail == null:
		return

	# Every Armory change reaches render(), which makes this the place newly
	# unlocked ships/skins/arenas/weapons are caught (:260-264).
	check_unlock_goals()

	var completed: int = _goal_manager.get_completed_count()
	var total: int = _goal_manager.get_total_goals_count()
	var pct: float = float(completed) / float(total) if total > 0 else 0.0
	_rail_fill.anchor_right = pct  # DIVERGENCE(UI-SYSTEM): Hud.dc.html — width, not height

	if is_modal_open():
		_render_milestones_modal_content()


## Full Milestones Screen. PORT: web/src/tilt-to-live/GoalsHUD.ts:289-303
# PORT-NOTE: the close button's listener (:295-297) is connected once, when the
# screen is built. The backdrop listener (:298-302) has nothing to hang on: the
# screen is full-screen (Milestones.dc.html) — M9 plan R11.
func open_all_goals_modal() -> void:
	if _milestones_modal == null:
		return
	_render_milestones_modal_content()
	_milestones_modal.visible = true


## PORT: web/src/tilt-to-live/GoalsHUD.ts:305-309
func close_all_goals_modal() -> void:
	if _milestones_modal != null:
		_milestones_modal.visible = false


## PORT: web/src/tilt-to-live/GoalsHUD.ts:59-106
func _init_dom(rail_host: Control, toast_host: Control) -> void:
	# 1. The rail. PORT: :61-80
	_rail = Control.new()
	_rail.name = "EdgeRail"
	# DIVERGENCE(UI-SYSTEM): Hud.dc.html — not tappable (spec §6.5; R11).
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_host.add_child(_rail)
	_rail_fill = ColorRect.new()
	_rail_fill.name = "EdgeRailFill"
	_rail_fill.color = UiTheme.COLOR_ION  # DIVERGENCE(UI-SYSTEM): Hud.dc.html
	_rail_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_fill.anchor_bottom = 1.0
	_rail.add_child(_rail_fill)

	# 2. Milestone Complete Toast. PORT: :83-92
	_toast = PanelContainer.new()
	_toast.name = "GoalToast"
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast_host.add_child(_toast)
	_toast_timer = Timer.new()
	_toast_timer.name = "ToastTimer"
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(_on_toast_timer_timeout)
	add_child(_toast_timer)

	# 3. Full Milestones Screen. PORT: :95-103
	_milestones_modal = _build_milestones_modal()
	add_child(_milestones_modal)

	_layout()
	# PORT-NOTE(B3): render() -> check_unlock_goals() runs here, before bind()
	# calls _setup_listeners() — see bind()'s PORT-NOTE.
	render()


## PORT: web/src/tilt-to-live/GoalsHUD.ts:108-141
# PORT-NOTE: the rail's click and Enter/Space listeners (:118-126) are not
# connected — spec §6.5 rules the rail not tappable (R11).
func _setup_listeners() -> void:
	_goal_manager.set_callbacks(_handle_goal_completed, _on_points_awarded)


## PORT: web/src/tilt-to-live/GoalsHUD.ts:237-240
func _handle_goal_completed(goal: GoalManager.Goal) -> void:
	show_goal_toast(goal)
	render()


## The :111-114 arrow function.
func _on_points_awarded(pts: int) -> void:
	_progression.add_points(pts)
	render()


func _on_toast_timer_timeout() -> void:
	_toast.visible = false  # PORT: :206-208


func _layout() -> void:
	if _rail == null:
		return
	var s: float = _ui_scale
	_rail.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_rail.offset_left = 0.0
	_rail.offset_right = 0.0
	_rail.offset_top = -UiTheme.px(RAIL_RISE, s)
	_rail.offset_bottom = _rail.offset_top + UiTheme.px(RAIL_HEIGHT, s)
	_layout_modal()


## Rewrites the toast's card, as the TS rewrites its innerHTML (:192-200, :215-225).
# DIVERGENCE(UI-SYSTEM): Hud.dc.html — one Card (92% panel, line 1 px, r 6);
# the TS's coloured left accent (game.css:3667) is not drawn.
func _fill_toast(icon_svg: String, title: String, subtitle: String, badge: String) -> void:
	for child: Node in _toast.get_children():
		_toast.remove_child(child)
		child.queue_free()
	var s: float = _ui_scale
	_toast.add_theme_stylebox_override(
		"panel",
		UiTheme.padded(
			UiTheme.flat(
				UiTheme.tint(UiTheme.COLOR_PANEL, TOAST_ALPHA),
				UiTheme.COLOR_LINE,
				UiTheme.px(UiTheme.CARD_RADIUS, s)
			),
			UiTheme.px(TOAST_PAD_X, s),
			UiTheme.px(TOAST_PAD_Y, s)
		)
	)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ToastRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiTheme.px(TOAST_GAP, s))
	_toast.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.texture = UiTheme.svg_texture(icon_svg, s)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(
		_label(
			"ToastTitle",
			title,
			UiTheme.sans(UiTheme.Weight.MEDIUM),
			TOAST_TITLE_SIZE,
			UiTheme.COLOR_TEXT
		)
	)
	if not subtitle.is_empty():
		row.add_child(
			_label(
				"ToastSubtitle",
				subtitle,
				UiTheme.sans(UiTheme.Weight.REGULAR),
				TOAST_SUBTITLE_SIZE,
				UiTheme.COLOR_TEXT_MUTED
			)
		)
	if not badge.is_empty():
		row.add_child(
			_label(
				"ToastReward",
				badge,
				UiTheme.mono(UiTheme.Weight.REGULAR),
				TOAST_REWARD_SIZE,
				UiTheme.COLOR_FLARE
			)
		)


## A one-off label at a board size (scaled), font and colour.
# M7: `font_size`, not `size` — `size` shadows Control.size (SHADOWED_VARIABLE_BASE_CLASS).
func _label(label_name: String, content: String, font: Font, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.text = content
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", UiTheme.px(font_size, _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The screen's fixed frame: shell, header and body; the tier columns are
## rebuilt by _render_milestones_modal_content, as the TS rebuilds innerHTML.
## PORT: web/src/tilt-to-live/GoalsHUD.ts:95-103, :362-382
## DIVERGENCE(UI-SYSTEM): Milestones.dc.html — full screen in shell, the
## Armory's 64 px header (interface spec §6.5).
func _build_milestones_modal() -> Control:
	var screen: ColorRect = ColorRect.new()
	screen.name = "MilestonesModal"
	screen.color = UiTheme.COLOR_SHELL
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The screen swallows taps meant for Run over and the arena underneath.
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.visible = false

	_screen_margin = MarginContainer.new()
	_screen_margin.name = "ScreenMargin"
	_screen_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	screen.add_child(_screen_margin)
	_screen_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_screen_margin.add_child(column)

	_header_margin = MarginContainer.new()
	_header_margin.name = "HeaderMargin"
	column.add_child(_header_margin)
	_header = HBoxContainer.new()
	_header.name = "Header"
	_header_margin.add_child(_header)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.theme_type_variation = "FlatIconButton"
	_back_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# PORT: web/src/tilt-to-live/GoalsHUD.ts:484-486 (btn-close-milestones)
	_back_button.pressed.connect(close_all_goals_modal)
	_header.add_child(_back_button)
	var title: Label = UiTheme.text("Milestones", "TitleText")  # PORT: :364
	title.name = "TitleLabel"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(title)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(fill)

	var counter: HBoxContainer = HBoxContainer.new()  # PORT: :367
	counter.add_theme_constant_override("separation", 0)
	_counter_label = _header_label("CounterLabel", UiTheme.COLOR_TEXT_MUTED)
	counter.add_child(_counter_label)
	_denom_label = _header_label("CounterDenomLabel", UiTheme.TEXT_FAINT)
	counter.add_child(_denom_label)
	_header.add_child(counter)

	_track_margin = MarginContainer.new()  # PORT: :368-370
	_track_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_track = Panel.new()
	_progress_track.name = "ProgressTrack"
	_progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_fill = Panel.new()
	_progress_fill.name = "ProgressFill"
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_fill.anchor_bottom = 1.0
	_progress_track.add_child(_progress_fill)
	_track_margin.add_child(_progress_track)
	_header.add_child(_track_margin)

	_points_row = HBoxContainer.new()  # PORT: :372
	_points_label = UiTheme.text("", "PointsText")
	_points_label.name = "HeaderPointsLabel"
	_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points_row.add_child(_points_label)
	# M14: keeps the CapsText variation (Mono 600, tracking 0.14) as board-copy
	# tolerance; the board's unit is Mono 500/10px/0.1em with margin 0 6px 0 2px
	# on the title. Check against Milestones.dc.html at the device pass (Task 8).
	_points_unit = UiTheme.text("", "CapsText")
	_points_unit.name = "HeaderPointsUnit"
	_points_unit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points_unit.add_theme_color_override("font_color", UiTheme.POINTS_UNIT)
	_points_row.add_child(_points_unit)
	_header.add_child(_points_row)

	var rule: ColorRect = ColorRect.new()
	rule.name = "HeaderRule"
	rule.color = UiTheme.COLOR_RAISED  # DIVERGENCE(UI-SYSTEM): Milestones.dc.html — border-bottom
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_body_margin = MarginContainer.new()
	_body_margin.name = "BodyMargin"
	_body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body_margin)
	_tier_columns = HBoxContainer.new()
	_tier_columns.name = "TierColumns"
	_body_margin.add_child(_tier_columns)
	return screen


## Scales every board size on the screen; rebuilds the columns when it is open
## (their sizes are baked at build time), as ArmoryUI.set_ui_scale does.
func _layout_modal() -> void:
	if _screen_margin == null:
		return
	var s: float = _ui_scale
	var pad: Vector2 = _inset if OS.has_feature("mobile") else Vector2.ZERO
	_screen_margin.add_theme_constant_override("margin_left", int(pad.x))
	_screen_margin.add_theme_constant_override("margin_right", int(pad.x))
	_screen_margin.add_theme_constant_override("margin_top", int(pad.y))
	_screen_margin.add_theme_constant_override("margin_bottom", int(pad.y))
	_header_margin.add_theme_constant_override("margin_left", UiTheme.px(HEADER_PAD_LEFT, s))
	_header_margin.add_theme_constant_override("margin_top", UiTheme.px(HEADER_PAD_Y, s))
	_header_margin.add_theme_constant_override("margin_right", UiTheme.px(HEADER_PAD_RIGHT, s))
	_header_margin.add_theme_constant_override("margin_bottom", UiTheme.px(HEADER_PAD_Y, s))
	_header.add_theme_constant_override("separation", UiTheme.px(HEADER_GAP, s))
	var side: float = UiTheme.TOUCH_TARGET * s
	_back_button.custom_minimum_size = Vector2(side, side)
	_back_button.icon = UiTheme.svg_texture(UiTheme.ICON_BACK, s)
	for label: Label in [_counter_label, _denom_label]:
		label.add_theme_font_size_override("font_size", UiTheme.px(COUNTER_SIZE, s))
	_track_margin.add_theme_constant_override("margin_left", UiTheme.px(TRACK_MARGIN, s))
	_track_margin.add_theme_constant_override("margin_right", UiTheme.px(TRACK_MARGIN, s))
	_progress_track.custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT) * s
	var r: int = UiTheme.px(TRACK_RADIUS, s)
	_progress_track.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_RAISED, Color.TRANSPARENT, r)
	)
	_progress_fill.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_ION, Color.TRANSPARENT, r)
	)
	_points_row.add_theme_constant_override("separation", UiTheme.px(POINTS_GAP, s))
	_body_margin.add_theme_constant_override("margin_left", UiTheme.px(BODY_PAD_LEFT, s))
	_body_margin.add_theme_constant_override("margin_top", UiTheme.px(BODY_PAD_TOP, s))
	_body_margin.add_theme_constant_override("margin_right", UiTheme.px(BODY_PAD_RIGHT, s))
	_body_margin.add_theme_constant_override("margin_bottom", 0)
	_tier_columns.add_theme_constant_override("separation", UiTheme.px(COLUMN_GAP, s))
	if is_modal_open():
		_render_milestones_modal_content()


## PORT: web/src/tilt-to-live/GoalsHUD.ts:311-487
func _render_milestones_modal_content() -> void:
	if _milestones_modal == null:
		return

	var completed: int = _goal_manager.get_completed_count()
	var total: int = _goal_manager.get_total_goals_count()
	var points: int = _progression.data.points
	# PORT: :317
	var progress_pct: int = roundi(float(completed) / float(total) * 100.0) if total > 0 else 0

	_counter_label.text = str(completed)  # PORT: :367
	_denom_label.text = "/%d" % total
	_progress_fill.anchor_right = progress_pct / 100.0  # PORT: :369
	_points_label.text = UiTheme.group_digits(points)  # PORT: :372
	# PORT: :372 (pt at 1). DIVERGENCE(UI-SYSTEM): Milestones.dc.html — caps unit.
	_points_unit.text = "PT" if points == 1 else "PTS"

	for child: Node in _tier_columns.get_children():
		_tier_columns.remove_child(child)
		child.queue_free()

	_tier_columns.add_child(_milestone_list())


## The TS's local getGoalTier. PORT: web/src/tilt-to-live/GoalsHUD.ts:322-354
func _get_goal_tier(goal: GoalManager.Goal) -> String:
	# Unlock-family goals are collection/mastery achievements (:323-329).
	if _goal_manager.is_unlock_goal(goal):
		return "Mastery"
	if (
		goal.category == "score"
		or goal.metric == "run_score"
		or goal.metric == "total_score"
		or goal.metric == "total_points"
	):
		return "Score"
	if (
		goal.category == "combat"
		or goal.category == "combo"
		or goal.category == "weapons"
		or goal.metric.contains("kills")
		or goal.metric.contains("multiplier")
		or goal.metric.contains("nuke")
		or goal.metric.contains("vortex")
		or goal.metric.contains("laser")
		or goal.metric.contains("missile")
		or goal.metric.contains("freeze")
		or goal.metric.contains("shield")
	):
		return "Combat"
	return "Mastery"


## The single scrolling column of tier sections.
## DIVERGENCE(M11c P11): user ruling 2026-09-26 — one column, the three tiers stacked
## under one scroll (Milestones.dc.html drew three side-by-side columns, each
## scrolling on its own, replacing game.css's grid), under the 40 px shell fade.
func _milestone_list() -> Control:
	var s: float = _ui_scale
	var list: Control = Control.new()
	list.name = "MilestoneList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.clip_contents = true
	list.mouse_filter = Control.MOUSE_FILTER_PASS

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "TierScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sections: VBoxContainer = VBoxContainer.new()
	sections.name = "TierSections"
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", UiTheme.px(COLUMN_GAP, s))
	sections.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(sections)

	# Categorize goals into the 3 tiers: Score, Combat, Mastery (:319-360)
	for tier_name: String in TIERS:
		var goals: Array[GoalManager.Goal] = []
		for goal: GoalManager.Goal in _goal_manager.catalog:
			if _get_goal_tier(goal) == tier_name:
				goals.append(goal)
		sections.add_child(_tier_section(tier_name, goals))

	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, UiTheme.tint(UiTheme.COLOR_SHELL, 0.0))
	gradient.set_color(1, UiTheme.COLOR_SHELL)
	var fade_texture: GradientTexture2D = GradientTexture2D.new()
	fade_texture.gradient = gradient
	fade_texture.fill_to = Vector2(0.0, 1.0)
	var fade: TextureRect = TextureRect.new()
	fade.name = "TierFade"
	fade.texture = fade_texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fade.offset_top = -UiTheme.px(FADE_HEIGHT, s)
	return list


## One tier section: heading, then its cards. PORT: web/src/tilt-to-live/GoalsHUD.ts:383-478
func _tier_section(tier_name: String, goals: Array[GoalManager.Goal]) -> Control:
	var s: float = _ui_scale
	var open: Array[GoalManager.Goal] = []
	var done: Array[GoalManager.Goal] = []
	for g: GoalManager.Goal in goals:
		if _goal_manager.is_completed(g.id):
			done.append(g)
		else:
			open.append(g)

	var section: VBoxContainer = VBoxContainer.new()
	section.name = "Tier_" + tier_name
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", UiTheme.px(STACK_GAP, s))
	section.mouse_filter = Control.MOUSE_FILTER_PASS

	var heading: HBoxContainer = HBoxContainer.new()
	heading.add_theme_constant_override("separation", UiTheme.px(HEADING_GAP, s))
	heading.mouse_filter = Control.MOUSE_FILTER_PASS
	var name_label: Label = UiTheme.caps(tier_name)
	name_label.name = "TierName"
	name_label.add_theme_color_override("font_color", TIER_TINTS[tier_name])
	heading.add_child(name_label)
	# PORT: :384-391
	var count: Label = UiTheme.text("%d of %d" % [done.size(), goals.size()], "MonoFaintText")
	count.name = "TierCount"
	heading.add_child(count)
	section.add_child(heading)

	var cards: VBoxContainer = VBoxContainer.new()
	cards.name = "TierCards"
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", UiTheme.px(STACK_GAP, s))
	cards.mouse_filter = Control.MOUSE_FILTER_PASS
	# DIVERGENCE(UI-SYSTEM): interface spec §6.5 — open goals first, then done
	# ones, each in catalog order (departs from GoalsHUD.ts:394's catalog order).
	for g: GoalManager.Goal in open + done:
		cards.add_child(_milestone_card(g))
	section.add_child(cards)
	return section


## One card: done, open unlock or run goal, or open lifetime goal with progress.
## PORT: web/src/tilt-to-live/GoalsHUD.ts:394-474
## DIVERGENCE(UI-SYSTEM): Milestones.dc.html — card, mark and text styles.
func _milestone_card(goal: GoalManager.Goal) -> PanelContainer:
	var s: float = _ui_scale
	var is_done: bool = _goal_manager.is_completed(goal.id)
	var is_unlock: bool = _goal_manager.is_unlock_goal(goal)
	var is_total: bool = not is_unlock and _goal_manager.is_total_goal(goal)

	# Unlock goals have no meaningful numeric target (:398-401).
	var current_val: float = 0.0
	if is_total:
		current_val = _goal_manager.get_metric_value(goal.metric, GoalManager.RunTracker.new())
	# PORT: :419-422
	var pct: int = 0 if is_unlock else clampi(roundi(current_val / goal.target * 100.0), 0, 100)

	var card: PanelContainer = PanelContainer.new()
	card.name = "MilestoneCard_" + goal.id
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.custom_minimum_size.y = CARD_HEIGHT * s
	card.add_theme_stylebox_override(
		"panel",
		UiTheme.padded(
			UiTheme.flat(
				UiTheme.DONE_CARD if is_done else UiTheme.COLOR_PANEL,
				UiTheme.COLOR_RAISED if is_done else UiTheme.COLOR_LINE,
				UiTheme.px(UiTheme.CARD_RADIUS, s)
			),
			UiTheme.px(CARD_PAD_X, s),
			0.0
		)
	)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", UiTheme.px(CARD_GAP, s))
	card.add_child(row)

	var mark: Panel = Panel.new()
	mark.name = "MarkBox"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE) * s
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mr: int = UiTheme.px(MARK_RADIUS, s)
	if is_done:
		mark.add_theme_stylebox_override(
			"panel", UiTheme.flat(UiTheme.COLOR_LOCKED_IN, UiTheme.COLOR_LOCKED_IN, mr)
		)
		var check: TextureRect = TextureRect.new()
		check.texture = UiTheme.svg_texture(UiTheme.ICON_MARK, s)
		check.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_child(check)
		check.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		mark.add_theme_stylebox_override(
			"panel", UiTheme.flat(Color.TRANSPARENT, UiTheme.COLOR_LINE_STRONG, mr)
		)
	row.add_child(mark)

	var content: VBoxContainer = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("separation", UiTheme.px(CONTENT_GAP, s))
	var name_label: Label = _one_line("NameLabel", goal.title, "BodyText")
	name_label.add_theme_font_override("font", UiTheme.sans(UiTheme.Weight.MEDIUM))
	name_label.add_theme_color_override(
		"font_color", UiTheme.COLOR_TEXT_MUTED if is_done else UiTheme.COLOR_TEXT
	)
	content.add_child(name_label)

	# Open lifetime goals show "cur / target" (:457-460); everything else its
	# description (interface spec §6.5).
	var subtitle: String = goal.description
	if not is_done and is_total:
		subtitle = (
			"%s / %s" % [UiTheme.group_digits(int(current_val)), UiTheme.group_digits(goal.target)]
		)
	content.add_child(_one_line("GoalLabel", subtitle, "MonoFaintText"))

	# DIVERGENCE(UI-SYSTEM): interface spec §6.5 — only open lifetime goals carry
	# a bar; the TS also draws an empty one on open run goals (:462-470) (R10).
	if not is_done and is_total:
		var bar_margin: MarginContainer = MarginContainer.new()
		bar_margin.mouse_filter = Control.MOUSE_FILTER_PASS
		bar_margin.add_theme_constant_override("margin_top", UiTheme.px(BAR_TOP, s))
		var bar: Panel = Panel.new()
		bar.name = "BarTrack"
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size.y = BAR_HEIGHT * s
		var br: int = UiTheme.px(BAR_RADIUS, s)
		bar.add_theme_stylebox_override(
			"panel", UiTheme.flat(UiTheme.COLOR_RAISED, Color.TRANSPARENT, br)
		)
		var bar_fill: Panel = Panel.new()
		bar_fill.name = "BarFill"
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_fill.anchor_bottom = 1.0
		bar_fill.anchor_right = pct / 100.0  # PORT: :468
		bar_fill.add_theme_stylebox_override(
			"panel", UiTheme.flat(UiTheme.COLOR_ION, Color.TRANSPARENT, br)
		)
		bar.add_child(bar_fill)
		bar_margin.add_child(bar)
		content.add_child(bar_margin)
	row.add_child(content)

	var pts: Label = _label(
		"PointsLabel",
		UiTheme.reward_text(goal.reward_points),
		UiTheme.mono(UiTheme.Weight.MEDIUM),
		CARD_POINTS_SIZE,
		UiTheme.TEXT_FAINT if is_done else UiTheme.COLOR_FLARE
	)
	row.add_child(pts)
	return card


## A single-line label that ellipsises (rule 03) in a theme variation.
func _one_line(label_name: String, content: String, variation: String) -> Label:
	var label: Label = UiTheme.text(content, variation)
	label.name = label_name
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A header numeral in Mono at the counter size (set in _layout_modal).
func _header_label(label_name: String, color: Color) -> Label:
	var label: Label = UiTheme.text("", "MonoText")
	label.name = label_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	return label
