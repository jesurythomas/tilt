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
	_fill_toast(UiTheme.ICON_CHECK, goal.title, "", "+%d" % goal.reward_points)
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


## Task 6 replaces this. PORT: web/src/tilt-to-live/GoalsHUD.ts:95-103
func _build_milestones_modal() -> Control:
	var screen: ColorRect = ColorRect.new()
	screen.name = "MilestonesModal"
	screen.color = UiTheme.COLOR_SHELL
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	return screen


## Task 6 replaces this.
func _layout_modal() -> void:
	pass


## Task 6 replaces this. PORT: web/src/tilt-to-live/GoalsHUD.ts:311-487
func _render_milestones_modal_content() -> void:
	pass
