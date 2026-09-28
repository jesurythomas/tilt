# gdlint:ignore=max-public-methods
# gdlint:disable=max-file-lines
## tilt_menu.gd
## PORTS: web/src/tilt-to-live/TiltMenu.ts (523 lines, source commit 7be9614)
# PORT-NOTE: TiltMenu.ts's menu and options modal together exceed gdlint's
# default max-public-methods (20), as in audio_bank.gd, and — built in code with
# a citation per board literal — its max-file-lines (1000), as in goal_manager.gd.
class_name TiltMenu
extends Control
## The start menu, the Settings (options) modal and the reset confirm, built in
## code on the Main and Settings boards (interface spec §6.6). Holds no sim
## system; every action is a signal GameRoot answers (TiltMenu.ts:15-18's callbacks).
##
## PORT-NOTE: initDOM (:45-67) creates the two DOM roots; _ready builds
## MenuContainer, OptionsModal and ResetConfirm instead. show/hide/isVisible (:69-85)
## are show_menu/hide_menu/is_menu_visible — CanvasItem already owns those names.
##
## The root stays visible and ignores the mouse; only MenuContainer hides, so the
## options modal (a sibling of MenuContainer) can open while the menu is
## hidden (controller ruling P1). The parent anchors this node full-rect.

## PORT: web/src/tilt-to-live/TiltMenu.ts:15 (onLaunchGame)
signal launch_requested(mode: Types.GameMode)
## PORT: web/src/tilt-to-live/TiltMenu.ts:16 (onOpenArmory)
signal armory_requested
## PORT: web/src/tilt-to-live/TiltMenu.ts:17 (onOpenAllGoals)
signal all_goals_requested
## The Steer row's calibrate icon opens the Calibrate screen (ruling R5).
signal calibrate_screen_requested
## The Steer row's picker or a Settings scheme card chose a scheme (ruling R7).
signal scheme_chosen(scheme: Types.ControlScheme)
## A Settings readability option (halo, grid, shake) changed and was saved (R9).
signal readability_changed
## Settings' Sound switch (R9, M11a Q2 ruling): GameRoot saves and applies it.
signal sfx_toggled(is_on: bool)
## Settings' Music switch (R9, M11a Q2 ruling): GameRoot saves and applies it.
signal music_toggled(is_on: bool)
## The reset confirm was accepted. PORT: web/src/tilt-to-live/TiltMenu.ts:510
signal reset_confirmed
## DIVERGENCE(M11a I-2): no TS counterpart. Settings has no DOM re-render to
## fall back on when it closes over the paused run's own Pause sheet, so
## GameRoot needs a hook to refresh it (final review I-2).
signal options_closed

const CONTROL_PICKER: PackedScene = preload("res://scenes/control_picker.tscn")

## DIVERGENCE(UI-SYSTEM): Main.dc.html — title block at left 32, top 26, gap 10;
## wordmark 42 px at line-height 0.9; subtitle 14.
const TITLE_LEFT: int = 32
const TITLE_TOP: int = 26
const TITLE_GAP: int = 10
const WORDMARK_SIZE: int = 42
const WORDMARK_LINE_HEIGHT: float = 0.9
const SUBTITLE_SIZE: int = 14
## DIVERGENCE(UI-SYSTEM): Main.dc.html — left block at left 32, bottom 24, width
## 392, gap 16; Steer row gap 12, label width 48, picker width 176.
const LEFT_LEFT: int = 32
const LEFT_BOTTOM: int = 24
const LEFT_WIDTH: int = 392
const LEFT_GAP: int = 16
const STEER_GAP: int = 12
const STEER_LABEL_WIDTH: int = 48
const PICKER_WIDTH: int = 208  # DIVERGENCE(UI R11): 176 before the segment glyphs
## DIVERGENCE(UI-SYSTEM): Main.dc.html — stats row padding-top 14, gap 28;
## stat column gap 3; value Mono 500 17.
const STATS_PAD_TOP: int = 14
const STATS_GAP: int = 28
const STAT_GAP: int = 3
const STAT_VALUE_SIZE: int = 17
## DIVERGENCE(UI-SYSTEM): Milestones.dc.html — milestone progress meter 4 tall
const TEASER_METER_HEIGHT: int = 4
## DIVERGENCE(UI R6): the NEXT teaser sits on its own card (user 2026-09-28: it "no longer
## read property because it closely matches the color of the background") — padding
## 14 / 6, row gap 2, card fill at 92% so the attract-mode swarm stays behind it.
## DIVERGENCE(UI R7, user 2026-09-28: "things should be dynamically scaling depending on
## device"): the least gap kept between the title block and the left column, and how
## far the menu may shrink below the device's ui_scale to keep it.
const FIT_MIN_GAP: int = 12
const FIT_MIN_FACTOR: float = 0.75
const TEASER_PAD_X: int = 14
const TEASER_PAD_Y: int = 6
const TEASER_GAP: int = 2
const TEASER_FILL_ALPHA: float = 0.92
## DIVERGENCE(UI-SYSTEM): Main.dc.html — right panel 372 wide, padding
## 22/30/22/24, rgba(8,9,14,0.92), gap 8.
const PANEL_WIDTH: int = 372
const PANEL_PAD_TOP: int = 22
const PANEL_PAD_RIGHT: int = 30
const PANEL_PAD_BOTTOM: int = 22
const PANEL_PAD_LEFT: int = 24
const PANEL_ALPHA: float = 0.92
const PANEL_GAP: int = 8
## DIVERGENCE(UI-SYSTEM): Main.dc.html — mode card 56 tall, padding 0 14 0 12,
## gap 12; tint bar 3×30 r 2; name/tagline gap 2; multiplier Mono 500 13.
const CARD_HEIGHT: int = 56
const CARD_PAD_LEFT: int = 12
const CARD_PAD_RIGHT: int = 14
const CARD_GAP: int = 12
const BAR_WIDTH: int = 3
const BAR_HEIGHT: int = 30
const BAR_RADIUS: int = 2
const NAME_GAP: int = 2
## DIVERGENCE(UI-SYSTEM): Main.dc.html — Play 18 px with a 10 px icon gap;
## nav row gap 8, margin-top 2.
const PLAY_FONT: int = 18
const PLAY_ICON_GAP: int = 10
const NAV_GAP: int = 8
## DIVERGENCE(UI R11): glyph-to-label gap inside a nav button.
const NAV_ICON_GAP: int = 8
## DIVERGENCE(UI R11): the side room a nav button keeps around its glyph and label (the
## row is centred, so it need not be the stylebox's 14 — which pushed the panel wide).
const NAV_PAD_X: int = 8
const NAV_TOP: int = 2

## DIVERGENCE(UI-SYSTEM): Settings.dc.html — header 64 tall, padding 8/28/8/24,
## gap 12; body padding 14/28/16/24, three columns with gap 20, column gap 8.
const HEADER_HEIGHT: int = 64
const HEADER_PAD_Y: int = 8
const HEADER_PAD_RIGHT: int = 28
const HEADER_PAD_LEFT: int = 24
const HEADER_GAP: int = 12
const BODY_PAD_TOP: int = 14
const BODY_PAD_RIGHT: int = 28
const BODY_PAD_BOTTOM: int = 16
const BODY_PAD_LEFT: int = 24
const COLUMN_GAP: int = 20
const COLUMN_STACK_GAP: int = 8
## DIVERGENCE(UI-SYSTEM): Settings.dc.html — scheme card 64 tall, row gap 8,
## padding 0 14, name/keys gap 3; Calibrate icon gap 8; Handling link 12 px.
const SCHEME_CARD_HEIGHT: int = 64
const SCHEME_GAP: int = 8
const SCHEME_PAD_X: int = 14
const SCHEME_NAME_GAP: int = 3
const CALIBRATE_ICON_GAP: int = 8
const LINK_SIZE: int = 12
## DIVERGENCE(UI-SYSTEM): Settings.dc.html — switch card min 60 tall, padding
## 8/12/8/14, gap 12, label/hint gap 2; shake card padding 10/12/12/14, gap 8;
## Data caps margin-top 8; Reset button r 4, text 13.
const SWITCH_CARD_HEIGHT: int = 60
const SWITCH_PAD_Y: int = 8
const SWITCH_PAD_RIGHT: int = 12
const SWITCH_PAD_LEFT: int = 14
const SWITCH_GAP: int = 12
const SWITCH_TEXT_GAP: int = 2
const SHAKE_PAD_TOP: int = 10
const SHAKE_PAD_BOTTOM: int = 12
const SHAKE_GAP: int = 8
const DATA_TOP: int = 8
const RESET_RADIUS: int = 4
const RESET_FONT: int = 13
## DIVERGENCE(M11c review): card sub-lines wrap to at most two lines before trimming.
const WRAP_MAX_LINES: int = 2
## PORT: web/src/tilt-to-live/TiltMenu.ts:508 (the window.confirm text)
const RESET_CONFIRM_TEXT: String = (
	# DIVERGENCE(ACH R1): "Achievements" (user 2026-09-28: "rename milestones to achievements")
	"Are you sure you want to reset all progress? Your scores, points, achievements, "
	+ "and armory unlocks will be permanently deleted."
)

## DIVERGENCE(UI-SYSTEM): Main.dc.html — Play glyph (verbatim but for the xmlns)
const ICON_PLAY: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">'
	+ '<path d="M4 2.5 L13 8 L4 13.5 Z" fill="#08090E"/></svg>'
)
## DIVERGENCE(UI R11, user 2026-09-28: "change the settings option to the actual settings
## icon"): an eight-tooth cog; Main.dc.html's rayed circle read as a brightness sun.
const ICON_GEAR: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 16 16" fill="none">'
	+ '<path fill="#E6E9F0" fill-rule="evenodd" d="'
	+ "M12.97 6.46 L15.06 6.57 L15.06 9.43 L12.97 9.54 L12.60 10.43 L14.00 "
	+ "11.98 L11.98 14.00 L10.43 12.60 L9.54 12.97 L9.43 15.06 L6.57 15.06 "
	+ "L6.46 12.97 L5.57 12.60 L4.02 14.00 L2.00 11.98 L3.40 10.43 L3.03 9.54 "
	+ "L0.94 9.43 L0.94 6.57 L3.03 6.46 L3.40 5.57 L2.00 4.02 L4.02 2.00 "
	+ "L5.57 3.40 L6.46 3.03 L6.57 0.94 L9.43 0.94 L9.54 3.03 L10.43 3.40 "
	+ "L11.98 2.00 L14.00 4.02 L12.60 5.57 Z M10.40 8 A2.4 2.4 0 1 0 5.60 8 "
	+ "A2.4 2.4 0 1 0 10.40 8 Z"
	+ '"/></svg>'
)
## DIVERGENCE(UI R11, user 2026-09-28: "make steer and touch as well as the armory and
## achievements more noticeable"): the nav
## buttons' glyphs — upgrade chevrons (ion) and a trophy (flare).
const ICON_ARMORY: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 16 16" fill="none">'
	+ '<path d="M3.5 8.5 L8 4 L12.5 8.5 M3.5 13 L8 8.5 L12.5 13" stroke="#8FB0FF" '
	+ 'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'
)
const ICON_ACHIEVEMENTS: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 16 16" fill="none">'
	+ '<path d="M4.5 2 H11.5 V6.5 A3.5 3.5 0 0 1 4.5 6.5 Z" fill="#FFB14D"/>'
	+ '<path d="M4.5 3.5 H2.5 V5 A2.5 2.5 0 0 0 5 7.5 M11.5 3.5 H13.5 V5 A2.5 2.5 0 0 1 11 7.5" '
	+ 'stroke="#FFB14D" stroke-width="1.2" stroke-linecap="round"/>'
	+ '<path d="M8 10 V12.5 M5 14 H11" stroke="#FFB14D" stroke-width="1.6" '
	+ 'stroke-linecap="round"/></svg>'
)
## The mode card's radio ring, %s = the ring colour.
## PORT: web/src/tilt-to-live/TiltMenu.ts:155, :158
const RING_OFF: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18" fill="none">'
	+ '<circle cx="9" cy="9" r="8" stroke="#%s" stroke-width="1.5"/></svg>'
)
## The selected ring and its dot, %s = the mode colour (both).
## PORT: web/src/tilt-to-live/TiltMenu.ts:155-157
const RING_ON: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18" fill="none">'
	+ '<circle cx="9" cy="9" r="8" stroke="#%s" stroke-width="1.5"/>'
	+ '<circle cx="9" cy="9" r="4" fill="#%s"/></svg>'
)

var _options: GameOptionsManager = null
var _progression: ProgressionManager = null
var _goals: GoalManager = null
var _scores: ScoreManager = null
var _settings: ControlSettings = null
var _ui_scale: float = 1.0
var _inset: Vector2 = Vector2.ZERO
## DIVERGENCE(UI R7): the device's ui_scale, and the factor render() applies to it so the
## title and the left column both fit this screen's height.
var _base_scale: float = 1.0
var _fit: float = 1.0
var _is_fitting: bool = false
var _menu_container: Control = null
var _options_modal: PanelContainer = null
var _reset_confirm: Control = null
var _drawn_mode: Types.GameMode = Types.GameMode.CLASSIC


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_container = Control.new()
	_menu_container.name = "MenuContainer"
	_menu_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_container)
	_menu_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# PORT: web/src/tilt-to-live/TiltMenu.ts:56-64 (the options modal root, hidden)
	_options_modal = PanelContainer.new()
	_options_modal.name = "OptionsModal"
	# DIVERGENCE(UI-SYSTEM): Settings.dc.html — a full-screen shell surface
	_options_modal.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_SHELL, Color.TRANSPARENT, 0)
	)
	_options_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_options_modal.visible = false
	add_child(_options_modal)
	_options_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The TS window.confirm (:507-509) as a sheet over the modal (ruling R11).
	_reset_confirm = Control.new()
	_reset_confirm.name = "ResetConfirm"
	_reset_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_confirm.visible = false
	add_child(_reset_confirm)
	_reset_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	render()


## Stands in for the constructor (TiltMenu.ts:23-43): the callbacks are signals.
func bind(
	options: GameOptionsManager,
	progression: ProgressionManager,
	goals: GoalManager,
	scores: ScoreManager,
	settings: ControlSettings
) -> void:
	_options = options
	_progression = progression
	_goals = goals
	_scores = scores
	_settings = settings
	render()  # PORT: web/src/tilt-to-live/TiltMenu.ts:42 (initDOM → render)


## PORT: web/src/tilt-to-live/TiltMenu.ts:69-75
func show_menu() -> void:
	if _menu_container == null:
		return
	_menu_container.visible = true
	render()


## PORT: web/src/tilt-to-live/TiltMenu.ts:77-81
func hide_menu() -> void:
	if _menu_container != null:
		_menu_container.visible = false


## PORT: web/src/tilt-to-live/TiltMenu.ts:83-85
func is_menu_visible() -> bool:
	return _menu_container != null and _menu_container.visible


## Rebuilds MenuContainer, as the TS rewrites innerHTML.
## PORT: web/src/tilt-to-live/TiltMenu.ts:87-212
func render() -> void:
	if _menu_container == null or _options == null:
		return

	# PORT: web/src/tilt-to-live/TiltMenu.ts:90-94
	var current_mode: Types.GameMode = _options.settings.mode
	var completed_goals: int = _goals.get_completed_count()
	var total_goals: int = _goals.get_total_goals_count()
	var best_score: int = _scores.stats.best_score
	var points: int = _progression.data.points

	for child: Node in _menu_container.get_children():
		_menu_container.remove_child(child)
		child.queue_free()

	_menu_container.add_child(_text_scrim())  # DIVERGENCE(UI R2)
	var title_block: VBoxContainer = _title_block()
	_menu_container.add_child(title_block)
	_menu_container.add_child(_mode_panel(current_mode))
	var left: VBoxContainer = VBoxContainer.new()
	left.name = "LeftBlock"
	left.add_theme_constant_override("separation", _px(LEFT_GAP))
	left.custom_minimum_size.x = _px(LEFT_WIDTH)
	_menu_container.add_child(left)
	left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	left.offset_left = _px(LEFT_LEFT) + _inset.x
	left.offset_bottom = -(_px(LEFT_BOTTOM) + _inset.y)
	left.offset_top = left.offset_bottom
	var teaser: Control = _next_teaser()
	if teaser != null:
		left.add_child(teaser)
	var picker: ControlPicker = _steer_row(left)
	# PORT: web/src/tilt-to-live/TiltMenu.ts:180 — the TS showed stats only once a best
	# existed. DIVERGENCE(UI R1): always — a new player's 500 points are spendable from the first run.
	left.add_child(_stats_row(best_score, points, completed_goals, total_goals))
	picker.set_active_scheme(_settings.scheme)
	_bind_events()
	_fit_height(title_block, left)


## DIVERGENCE(UI R7): if the title block and the left column (plus their margins and the
## device insets) are taller than this screen, shrinks the menu's scale just enough — at
## most to FIT_MIN_FACTOR — and renders once more. Taller screens keep the device scale.
## Only set_ui_scale (a new screen size) resets the factor: a re-render (a tap on Touch or
## Tilt) never grows it back, so the scale stays put (user 2026-09-28: tapping them
## "changes the scaling" — the factor bounced between two values).
func _fit_height(title_block: Control, left: Control) -> void:
	if _is_fitting or size.y <= 0.0:
		return
	var margins: float = float(_px(TITLE_TOP) + _px(FIT_MIN_GAP) + _px(LEFT_BOTTOM))
	var content: float = (
		title_block.get_combined_minimum_size().y + left.get_combined_minimum_size().y + margins
	)
	var room: float = size.y - _inset.y * 2.0
	if content <= room:
		return
	# A 1% margin, so pixel rounding at the new scale cannot overflow again.
	var wanted: float = clampf(_fit * room / content * 0.99, FIT_MIN_FACTOR, 1.0)
	if wanted >= _fit:
		return
	_fit = wanted
	_ui_scale = _base_scale * _fit
	theme = UiTheme.build(_ui_scale)
	_is_fitting = true
	render()
	_is_fitting = false


## The factor UI R7 applied to the device scale (1 when everything fits).
func fit_factor() -> float:
	return _fit


## Rebuilds the board sizes at `scale` and insets the left and title blocks by
## `inset`; the right panel stays flush right, as the board draws it.
func set_ui_scale(scale: float, inset: Vector2) -> void:
	_base_scale = scale
	_fit = 1.0
	_ui_scale = scale
	_inset = inset
	theme = UiTheme.build(scale)
	render()
	if is_options_open():
		open_options_modal()


## Rebuilds the Settings modal from the saved options and shows it; every
## handler calls it again to re-render, as the TS does.
## PORT: web/src/tilt-to-live/TiltMenu.ts:257-413
func open_options_modal() -> void:
	if _options_modal == null or _options == null:
		return
	for root: Control in [_options_modal, _reset_confirm]:
		for child: Node in root.get_children():
			root.remove_child(child)
			child.queue_free()
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	page.add_child(_options_header())
	# DIVERGENCE(UI-SYSTEM): Settings.dc.html — header bottom border in raised
	page.add_child(UiTheme.hairline(false, UiTheme.COLOR_RAISED))
	page.add_child(_options_body())
	_options_modal.add_child(page)
	_build_reset_confirm()
	_options_modal.visible = true  # PORT: web/src/tilt-to-live/TiltMenu.ts:411
	_bind_options_events()


## PORT: web/src/tilt-to-live/TiltMenu.ts:419-421 (the close button's hide)
func close_options_modal() -> void:
	if _options_modal != null:
		_options_modal.visible = false
	# The confirm is the modal's sibling (ruling P1); it must not outlive it.
	if _reset_confirm != null:
		_reset_confirm.visible = false
	options_closed.emit()


## True while the Settings modal is up.
func is_options_open() -> bool:
	return _options_modal != null and _options_modal.visible


## True when `mode`'s card is drawn selected.
func is_mode_selected(mode: Types.GameMode) -> bool:
	return _menu_container != null and _options != null and _drawn_mode == mode


# PORT: web/src/tilt-to-live/TiltMenu.ts:214-255
# PORT-NOTE: the card Enter/Space keys (:226-234) are the Button's own
# ui_accept, so they need no code here.
func _bind_events() -> void:
	for config: GameOptionsManager.ModeConfig in _options.modes:
		var card: Button = _find_button("ModeCard_" + GameOptionsManager.MODE_IDS[config.id])
		card.pressed.connect(_on_mode_card_pressed.bind(config.id))
	_find_button("PlayButton").pressed.connect(_on_play_pressed)
	# PORT: web/src/tilt-to-live/TiltMenu.ts:244-250
	_find_button("MenuArmoryButton").pressed.connect(armory_requested.emit)
	_find_button("MenuMilestonesButton").pressed.connect(all_goals_requested.emit)
	_find_button("MenuSettingsButton").pressed.connect(open_options_modal)  # PORT: :252-254
	_find_button("MenuCalibrateButton").pressed.connect(calibrate_screen_requested.emit)


func _on_mode_card_pressed(mode: Types.GameMode) -> void:
	_options.set_mode(mode)  # PORT: web/src/tilt-to-live/TiltMenu.ts:222
	render()  # PORT: web/src/tilt-to-live/TiltMenu.ts:223


func _on_play_pressed() -> void:
	hide_menu()  # PORT: web/src/tilt-to-live/TiltMenu.ts:239
	launch_requested.emit(_options.settings.mode)  # PORT: :240


func _find_button(button_name: String) -> Button:
	return _menu_container.find_child(button_name, true, false) as Button


# PORT: web/src/tilt-to-live/TiltMenu.ts:133-136 (title and subtitle)
func _title_block() -> VBoxContainer:
	var block: VBoxContainer = VBoxContainer.new()
	block.name = "TitleBlock"
	block.add_theme_constant_override("separation", _px(TITLE_GAP))
	var title: Label = UiTheme.text("PERIL\nPOINT", "TitleText")  # ruling R6
	title.name = "MenuTitle"
	var wordmark: FontVariation = UiTheme.archivo(UiTheme.WORDMARK_WIDTH)
	var size_px: int = _px(WORDMARK_SIZE)
	title.add_theme_font_override("font", wordmark)
	title.add_theme_font_size_override("font_size", size_px)
	# CSS line-height 0.9: Godot's line height is the font height plus line_spacing.
	title.add_theme_constant_override(
		"line_spacing", roundi(WORDMARK_LINE_HEIGHT * size_px - wordmark.get_height(size_px))
	)
	UiTheme.legible_over_play(title, _px(UiTheme.OVER_PLAY_OUTLINE))
	block.add_child(title)
	var subtitle: Label = UiTheme.text("Move to dodge. The guns fire themselves.", "BodyText")  # :135
	subtitle.name = "MenuTagline"
	subtitle.add_theme_font_size_override("font_size", _px(SUBTITLE_SIZE))
	UiTheme.legible_over_play(subtitle, _px(UiTheme.OVER_PLAY_OUTLINE))
	block.add_child(subtitle)
	block.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	block.offset_left = _px(TITLE_LEFT) + _inset.x
	block.offset_top = _px(TITLE_TOP) + _inset.y
	return block


# The next-milestone teaser. PORT: web/src/tilt-to-live/TiltMenu.ts:96-126, :198-207
# DIVERGENCE(UI-SYSTEM): System.dc.html — Rule N: TS content with no board slot,
# kept above the Steer row and styled from System tokens (ruling R8).
func _next_teaser() -> Control:
	var active_goals: Array[GoalManager.ActiveGoal] = _goals.get_active_goals(1)
	if active_goals.is_empty():
		return null
	var g: GoalManager.Goal = active_goals[0].goal
	var current_val: float = 0.0
	if g.category == "cumulative" or g.metric.begins_with("total_"):
		# PORT: web/src/tilt-to-live/TiltMenu.ts:102-116 — a zeroed classic tracker
		var tracker: GoalManager.RunTracker = GoalManager.RunTracker.new()
		tracker.mode = GameOptionsManager.MODE_IDS[Types.GameMode.CLASSIC]
		current_val = _goals.get_metric_value(g.metric, tracker)
	elif g.metric == "run_score":
		current_val = mini(g.target, _scores.stats.best_score)  # PORT: :118
	# PORT: web/src/tilt-to-live/TiltMenu.ts:120
	var pct: int = clampi(roundi(current_val / float(g.target) * 100.0), 0, 100)
	var teaser: VBoxContainer = VBoxContainer.new()
	teaser.name = "NextTeaser"
	teaser.add_theme_constant_override("separation", _px(TEASER_GAP))
	# DIVERGENCE(UI R6): "NEXT" and the reward on one line, then the title in full-strength
	# text and the description under it — the TS ran "title — description" as one faint
	# line straight over the playfield (:201-202).
	var top: HBoxContainer = HBoxContainer.new()
	var tag: Label = UiTheme.caps("Next")  # PORT: :201
	tag.add_theme_color_override("font_color", UiTheme.COLOR_FLARE)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tag)
	var reward: Label = UiTheme.text(UiTheme.reward_text(g.reward_points), "MonoText")
	reward.name = "NextTeaserReward"
	reward.add_theme_color_override("font_color", UiTheme.COLOR_FLARE)
	top.add_child(reward)
	teaser.add_child(top)
	var title: Label = UiTheme.text(g.title, "StrongText")  # PORT: :202
	title.name = "NextTeaserTitle"
	title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	teaser.add_child(title)
	var desc: Label = UiTheme.text(g.description, "HintText")  # PORT: :202
	desc.name = "NextTeaserText"
	desc.add_theme_color_override("font_color", UiTheme.TEXT_SECONDARY)
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.clip_text = true
	teaser.add_child(desc)
	var fill: ProgressBar = UiTheme.meter(
		pct / 100.0,
		UiTheme.COLOR_FLARE,
		_px(LEFT_WIDTH) - 2 * _px(TEASER_PAD_X),
		_px(TEASER_METER_HEIGHT)
	)
	fill.name = "NextTeaserFill"
	teaser.add_child(fill)
	var card: PanelContainer = PanelContainer.new()
	card.name = "NextTeaserCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel",
		UiTheme.padded(
			UiTheme.flat(
				UiTheme.tint(UiTheme.COLOR_PANEL, TEASER_FILL_ALPHA),
				UiTheme.COLOR_LINE,
				_px(UiTheme.CARD_RADIUS)
			),
			_px(TEASER_PAD_X),
			_px(TEASER_PAD_Y)
		)
	)
	card.add_child(teaser)
	return card


# DIVERGENCE(UI-SYSTEM): Main.dc.html — the Steer row (no TS counterpart; ruling R7).
func _steer_row(left: VBoxContainer) -> ControlPicker:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "SteerRow"
	row.add_theme_constant_override("separation", _px(STEER_GAP))
	var label: Label = UiTheme.caps("Steer")
	label.custom_minimum_size.x = _px(STEER_LABEL_WIDTH)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var picker: ControlPicker = CONTROL_PICKER.instantiate() as ControlPicker
	picker.custom_minimum_size.x = _px(PICKER_WIDTH)
	row.add_child(picker)
	var calibrate: Button = _button("MenuCalibrateButton", "IconButton", "")
	calibrate.custom_minimum_size = Vector2.ONE * _px(UiTheme.TOUCH_TARGET)
	calibrate.icon = UiTheme.svg_texture(UiTheme.ICON_CALIBRATE, _ui_scale)
	calibrate.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(calibrate)
	left.add_child(row)
	picker.set_ui_scale(_ui_scale)
	picker.scheme_chosen.connect(scheme_chosen.emit)
	return picker


# PORT: web/src/tilt-to-live/TiltMenu.ts:179-196
func _stats_row(best_score: int, points: int, completed: int, total: int) -> VBoxContainer:
	var row: VBoxContainer = VBoxContainer.new()
	row.name = "StatsRow"
	row.add_theme_constant_override("separation", 0)
	# DIVERGENCE(UI-SYSTEM): Main.dc.html — stats top border in raised
	row.add_child(UiTheme.hairline(false, UiTheme.COLOR_RAISED))
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_top", _px(STATS_PAD_TOP))
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", _px(STATS_GAP))
	# PORT: web/src/tilt-to-live/TiltMenu.ts:184 — toLocaleString
	var best: Label = _stat_value("StatBest", UiTheme.group_digits(best_score), UiTheme.COLOR_TEXT)
	columns.add_child(_stat_column("Best", best))  # PORT: :183
	var pts: Label = _stat_value("StatPoints", UiTheme.group_digits(points), UiTheme.COLOR_FLARE)
	columns.add_child(_stat_column("Points", pts))  # PORT: :187
	var milestones: HBoxContainer = HBoxContainer.new()
	milestones.name = "StatMilestones"
	milestones.add_theme_constant_override("separation", 0)
	milestones.add_child(_stat_value("StatDone", str(completed), UiTheme.COLOR_TEXT))  # PORT: :192
	milestones.add_child(_stat_value("StatTotal", "/%d" % total, UiTheme.TEXT_FAINT))  # PORT: :192
	# PORT: :191
	# DIVERGENCE(ACH R1): "Achievements" — user 2026-09-28: "rename milestones to
	# achievements"
	columns.add_child(_stat_column("Achievements", milestones))
	pad.add_child(columns)
	row.add_child(pad)
	return row


func _stat_column(caption: String, value: Control) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", _px(STAT_GAP))
	column.add_child(UiTheme.caps(caption))
	column.add_child(value)
	return column


func _stat_value(label_name: String, content: String, color: Color) -> Label:
	var value: Label = UiTheme.text(content, "StatText")
	value.name = label_name
	value.add_theme_font_size_override("font_size", _px(STAT_VALUE_SIZE))
	value.add_theme_color_override("font_color", color)
	return value


# The right panel: mode cards, Play, nav row. PORT: web/src/tilt-to-live/TiltMenu.ts:139-177
func _mode_panel(current_mode: Types.GameMode) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ModePanel"
	var box: StyleBoxFlat = UiTheme.flat(
		UiTheme.tint(UiTheme.COLOR_VOID, PANEL_ALPHA), UiTheme.COLOR_LINE, 0
	)
	box.set_border_width_all(0)
	box.border_width_left = 1
	box.content_margin_top = _px(PANEL_PAD_TOP)
	box.content_margin_right = _px(PANEL_PAD_RIGHT)
	box.content_margin_bottom = _px(PANEL_PAD_BOTTOM)
	box.content_margin_left = _px(PANEL_PAD_LEFT)
	panel.add_theme_stylebox_override("panel", box)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -_px(PANEL_WIDTH)
	panel.offset_right = 0.0
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", _px(PANEL_GAP))
	for config: GameOptionsManager.ModeConfig in _options.modes:
		stack.add_child(_mode_card(config, config.id == current_mode))  # PORT: :142-143
	var fill: Control = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(fill)
	var play: Button = _button("PlayButton", "PrimaryButton", "Play")  # PORT: :168-171
	play.custom_minimum_size.y = _px(UiTheme.HERO_TARGET)
	play.add_theme_font_size_override("font_size", _px(PLAY_FONT))
	play.add_theme_constant_override("h_separation", _px(PLAY_ICON_GAP))
	play.icon = UiTheme.svg_texture(ICON_PLAY, _ui_scale)
	stack.add_child(play)
	var nav_pad: MarginContainer = MarginContainer.new()
	nav_pad.add_theme_constant_override("margin_top", _px(NAV_TOP))
	var nav: HBoxContainer = HBoxContainer.new()
	nav.add_theme_constant_override("separation", _px(NAV_GAP))
	nav.add_child(_nav_button("MenuArmoryButton", "Armory", ICON_ARMORY))  # PORT: :173
	# PORT: :174
	# DIVERGENCE(ACH R1): "Achievements" — user 2026-09-28: "rename milestones to
	# achievements"
	nav.add_child(_nav_button("MenuMilestonesButton", "Achievements", ICON_ACHIEVEMENTS))
	# PORT: web/src/tilt-to-live/TiltMenu.ts:175 — "Settings", drawn as the board's gear
	var settings: Button = _button("MenuSettingsButton", "NavButton", "")
	settings.tooltip_text = "Settings"
	settings.custom_minimum_size = Vector2.ONE * _px(UiTheme.TOUCH_TARGET)
	settings.icon = UiTheme.svg_texture(ICON_GEAR, _ui_scale)
	settings.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(settings)
	nav_pad.add_child(nav)
	stack.add_child(nav_pad)
	panel.add_child(stack)
	return panel


## DIVERGENCE(UI R11): a NavButton whose glyph sits beside its centred label (a Button's
## own icon hugs the left edge); the row ignores the mouse so the button takes the tap.
func _nav_button(button_name: String, label: String, glyph: String) -> Button:
	var button: Button = _button(button_name, "NavButton", "")
	button.tooltip_text = label
	button.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "NavContent"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _px(NAV_ICON_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon: TextureRect = TextureRect.new()
	icon.texture = UiTheme.svg_texture(glyph, _ui_scale)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text: Label = UiTheme.text(label, "")
	text.name = "NavLabel"
	text.add_theme_font_override("font", UiTheme.sans(UiTheme.Weight.SEMIBOLD))
	text.add_theme_font_size_override("font_size", _px(UiTheme.NAV_LABEL_SIZE))
	text.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	button.add_child(row)
	# The label is a child, so the button's own minimum width must hold it — measured from
	# the font, as the row has no theme (so no size) until it enters the tree.
	var font_px: int = _px(UiTheme.NAV_LABEL_SIZE)
	var label_w: float = (
		UiTheme
		. sans(UiTheme.Weight.SEMIBOLD)
		. get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
		. x
	)
	var pad: int = _px(NAV_PAD_X) * 2
	button.custom_minimum_size.x = ceilf(
		icon.texture.get_width() + _px(NAV_ICON_GAP) + label_w + pad
	)
	return button


# One mode card. PORT: web/src/tilt-to-live/TiltMenu.ts:142-162
func _mode_card(config: GameOptionsManager.ModeConfig, is_selected: bool) -> Button:
	if is_selected:
		_drawn_mode = config.id
	var card: Button = _button(
		"ModeCard_" + GameOptionsManager.MODE_IDS[config.id], "CardButton", ""
	)
	card.custom_minimum_size.y = _px(CARD_HEIGHT)
	# PORT: web/src/tilt-to-live/TiltMenu.ts:146 (border and background)
	var face: PanelContainer = PanelContainer.new()
	var face_box: StyleBoxFlat = UiTheme.flat(
		UiTheme.COLOR_PANEL if is_selected else UiTheme.DONE_CARD,
		config.color if is_selected else UiTheme.COLOR_LINE,
		_px(UiTheme.CARD_RADIUS)
	)
	face_box.content_margin_left = _px(CARD_PAD_LEFT)
	face_box.content_margin_right = _px(CARD_PAD_RIGHT)
	face.add_theme_stylebox_override("panel", face_box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(CARD_GAP))
	var bar: Panel = Panel.new()  # PORT: :147
	bar.custom_minimum_size = Vector2(_px(BAR_WIDTH), _px(BAR_HEIGHT))
	bar.add_theme_stylebox_override(
		"panel", UiTheme.flat(config.color, Color.TRANSPARENT, _px(BAR_RADIUS))
	)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var info: VBoxContainer = VBoxContainer.new()
	info.add_theme_constant_override("separation", _px(NAME_GAP))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mode_name: Label = UiTheme.text(config.name, "FieldText")  # PORT: :150
	mode_name.add_theme_color_override(
		"font_color", UiTheme.COLOR_TEXT if is_selected else UiTheme.TEXT_SECONDARY
	)
	info.add_child(mode_name)
	var tagline: Label = UiTheme.text(config.tagline, "HintText")  # PORT: :153
	tagline.add_theme_color_override(
		"font_color", UiTheme.COLOR_TEXT_MUTED if is_selected else UiTheme.TEXT_FAINT
	)
	# DIVERGENCE(M11c review): Code Red's tagline was cut to "first seco…"; wrap to a
	# second line (the column has the height) before trimming.
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.max_lines_visible = WRAP_MAX_LINES
	tagline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(tagline)
	row.add_child(info)
	# DIVERGENCE(UI R8, user 2026-09-28: "remove 1.5x 1.0x and 1.25x from the game mode"):
	# the card shows no score multiplier (the TS's multiplier label, TiltMenu.ts:151).
	var hex: String = config.color.to_html(false)
	var ring: TextureRect = TextureRect.new()
	ring.texture = UiTheme.svg_texture(
		(
			RING_ON % [hex, hex]
			if is_selected
			else RING_OFF % UiTheme.COLOR_LINE_STRONG.to_html(false)
		),
		_ui_scale
	)
	ring.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ring)
	face.add_child(row)
	card.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node: Node in face.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


## DIVERGENCE(UI R2): the void, fading out left to right behind the title and left
## column, so the attract-mode swarm reads as background (the text sat on it bare).
func _text_scrim() -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, UiTheme.tint(UiTheme.COLOR_VOID, 0.82))
	gradient.set_color(1, UiTheme.tint(UiTheme.COLOR_VOID, 0.0))
	gradient.add_point(0.55, UiTheme.tint(UiTheme.COLOR_VOID, 0.6))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(1.0, 0.0)
	var scrim: TextureRect = TextureRect.new()
	scrim.name = "TextScrim"
	scrim.texture = texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	scrim.anchor_right = 0.5
	return scrim


# PORT: web/src/tilt-to-live/TiltMenu.ts:415-522
# PORT-NOTE: the backdrop click-to-close (:422-426) has no counterpart: the
# Settings board is full-screen, so there is no backdrop to click.
# PORT-NOTE: the TS handlers flip the saved flag (`!x`); a CheckButton reports
# its new state, so the handlers store `is_on` — the same value.
func _bind_options_events() -> void:
	_find_options_button("OptionsBackButton").pressed.connect(close_options_modal)
	_find_options_button("HaloSwitch").toggled.connect(_on_halo_toggled)
	_find_options_button("GridSwitch").toggled.connect(_on_grid_toggled)
	# PORT: web/src/tilt-to-live/TiltMenu.ts:447-457 — data-shake off / low / full
	_find_options_button("ShakeOff").pressed.connect(
		_on_shake_pressed.bind(GameOptionsManager.ScreenShake.OFF)
	)
	_find_options_button("ShakeLow").pressed.connect(
		_on_shake_pressed.bind(GameOptionsManager.ScreenShake.LOW)
	)
	_find_options_button("ShakeFull").pressed.connect(
		_on_shake_pressed.bind(GameOptionsManager.ScreenShake.FULL)
	)
	# DIVERGENCE(M11a Q2): TiltMenu.ts:460-470 only saves; the user ruled Settings
	# applies audio at once, as Pause does (TiltGame.ts:1396-1416).
	_find_options_button("SfxSwitch").toggled.connect(_on_sfx_toggled)
	_find_options_button("MusicSwitch").toggled.connect(_on_music_toggled)
	# PORT: web/src/tilt-to-live/TiltMenu.ts:472-483 (ruling R7: the ControlSettings schemes)
	_find_options_button("SchemeCard_touch").pressed.connect(
		_on_scheme_card_pressed.bind(Types.ControlScheme.MOUSE)
	)
	_find_options_button("SchemeCard_tilt").pressed.connect(
		_on_scheme_card_pressed.bind(Types.ControlScheme.GYRO)
	)
	_find_options_button("SchemeCard_keys").pressed.connect(
		_on_scheme_card_pressed.bind(Types.ControlScheme.KEYBOARD)
	)
	# PORT-NOTE: the TS button calibrates in place (:485-497); the Settings board
	# links to the Calibrate screen instead (rulings R4, R5).
	var calibrate: Button = _find_options_button("SettingsCalibrateButton")
	if calibrate != null:
		calibrate.pressed.connect(calibrate_screen_requested.emit)
	_find_options_button("ArmoryLink").pressed.connect(_on_armory_link_pressed)
	# PORT: web/src/tilt-to-live/TiltMenu.ts:506-521 (window.confirm → ResetConfirm)
	_find_options_button("ResetButton").pressed.connect(_reset_confirm.show)
	_find_confirm_button("ResetConfirmButton").pressed.connect(reset_confirmed.emit)
	_find_confirm_button("ResetCancelButton").pressed.connect(_reset_confirm.hide)


# PORT: web/src/tilt-to-live/TiltMenu.ts:429-433
func _on_halo_toggled(is_on: bool) -> void:
	_options.settings.high_contrast_halo = is_on
	_options.save()
	readability_changed.emit()  # ruling R9: applied at once
	open_options_modal()


# PORT: web/src/tilt-to-live/TiltMenu.ts:441-445
func _on_grid_toggled(is_on: bool) -> void:
	_options.settings.show_gridlines = is_on
	_options.save()
	readability_changed.emit()  # ruling R9: applied at once
	open_options_modal()


# PORT: web/src/tilt-to-live/TiltMenu.ts:448-456
func _on_shake_pressed(shake: GameOptionsManager.ScreenShake) -> void:
	_options.settings.screen_shake = shake
	_options.save()
	readability_changed.emit()  # ruling R9: applied at once
	open_options_modal()


# PORT: web/src/tilt-to-live/TiltMenu.ts:460-464 (M11a Q2: GameRoot saves and applies)
func _on_sfx_toggled(is_on: bool) -> void:
	sfx_toggled.emit(is_on)
	open_options_modal()


# PORT: web/src/tilt-to-live/TiltMenu.ts:466-470 (M11a Q2: GameRoot saves and applies)
func _on_music_toggled(is_on: bool) -> void:
	music_toggled.emit(is_on)
	open_options_modal()


# PORT: web/src/tilt-to-live/TiltMenu.ts:474-481 — GameRoot writes the scheme into
# the shared ControlSettings before the emit returns, so the re-render reads it.
func _on_scheme_card_pressed(scheme: Types.ControlScheme) -> void:
	scheme_chosen.emit(scheme)
	open_options_modal()


# PORT: web/src/tilt-to-live/TiltMenu.ts:500-503
func _on_armory_link_pressed() -> void:
	close_options_modal()
	armory_requested.emit()


func _find_options_button(button_name: String) -> Button:
	return _options_modal.find_child(button_name, true, false) as Button


func _find_confirm_button(button_name: String) -> Button:
	return _reset_confirm.find_child(button_name, true, false) as Button


# The Settings header. PORT: web/src/tilt-to-live/TiltMenu.ts:297-305
func _options_header() -> MarginContainer:
	var header: MarginContainer = MarginContainer.new()
	header.custom_minimum_size.y = _px(HEADER_HEIGHT)
	# DIVERGENCE(M11c review): the top inset too, as the Armory and Milestones headers
	# have it — the back button sat ~10 px higher on Settings than on those screens.
	header.add_theme_constant_override("margin_top", _px(HEADER_PAD_Y) + roundi(_inset.y))
	header.add_theme_constant_override("margin_bottom", _px(HEADER_PAD_Y))
	header.add_theme_constant_override("margin_right", _px(HEADER_PAD_RIGHT) + roundi(_inset.x))
	header.add_theme_constant_override("margin_left", _px(HEADER_PAD_LEFT) + roundi(_inset.x))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(HEADER_GAP))
	# DIVERGENCE(UI-SYSTEM): Settings.dc.html — Back chevron (the ICON_BACK glyph)
	var back: Button = _button("OptionsBackButton", "GhostIconButton", "")
	back.tooltip_text = "Close settings"  # PORT: :300 (aria-label)
	back.custom_minimum_size = Vector2.ONE * _px(UiTheme.TOUCH_TARGET)
	back.icon = UiTheme.svg_texture(UiTheme.ICON_BACK, _ui_scale)
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(back)
	var title: Label = UiTheme.text("Settings", "TitleText")  # PORT: :298
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	header.add_child(row)
	return header


# The three board columns. PORT: web/src/tilt-to-live/TiltMenu.ts:307-408
func _options_body() -> MarginContainer:
	var body: MarginContainer = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("margin_top", _px(BODY_PAD_TOP))
	body.add_theme_constant_override("margin_bottom", _px(BODY_PAD_BOTTOM))
	body.add_theme_constant_override("margin_right", _px(BODY_PAD_RIGHT) + roundi(_inset.x))
	body.add_theme_constant_override("margin_left", _px(BODY_PAD_LEFT) + roundi(_inset.x))
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", _px(COLUMN_GAP))
	columns.add_child(_controls_column())
	columns.add_child(_readability_column())
	columns.add_child(_audio_column())
	body.add_child(columns)
	return body


func _options_column(heading: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", _px(COLUMN_STACK_GAP))
	column.add_child(_section_heading(heading))
	return column


# DIVERGENCE(UI-SYSTEM): Settings.dc.html — section headings are caps in ion
func _section_heading(heading: String) -> Label:
	var label: Label = UiTheme.caps(heading)
	label.add_theme_color_override("font_color", UiTheme.COLOR_ION)
	return label


# PORT: web/src/tilt-to-live/TiltMenu.ts:362-393 (Controls)
func _controls_column() -> VBoxContainer:
	var column: VBoxContainer = _options_column("Controls")  # PORT: :365
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override("separation", _px(SCHEME_GAP))
	# Ruling R7: Touch (board sublabel), Tilt (:291) and, off mobile, Keys (:289).
	# DIVERGENCE(UI R12, user 2026-09-28: "fix the capitalization of the texts"): sentence case
	# (the board's "drag anywhere", "phone gyroscope"), and "Tilt the phone" fits one line.
	cards.add_child(
		_scheme_card("SchemeCard_touch", "Touch", "Drag anywhere", Types.ControlScheme.MOUSE)
	)
	cards.add_child(
		_scheme_card("SchemeCard_tilt", "Tilt", "Tilt the phone", Types.ControlScheme.GYRO)
	)
	var keys: Button = _scheme_card(
		"SchemeCard_keys", "Keys", "WASD / arrows", Types.ControlScheme.KEYBOARD
	)
	# A phone has no keyboard (ControlPicker's rule).
	keys.visible = not OS.has_feature("mobile")
	cards.add_child(keys)
	column.add_child(cards)
	# PORT: web/src/tilt-to-live/TiltMenu.ts:378 — only while the scheme is gyro
	if _settings.scheme == Types.ControlScheme.GYRO:
		var calibrate: Button = _button(
			"SettingsCalibrateButton", "SecondaryButton", "Calibrate tilt"
		)
		calibrate.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
		calibrate.icon = UiTheme.svg_texture(UiTheme.ICON_CALIBRATE, _ui_scale)
		calibrate.add_theme_constant_override("h_separation", _px(CALIBRATE_ICON_GAP))
		column.add_child(calibrate)
	column.add_child(_armory_link())
	return column


# One scheme card. PORT: web/src/tilt-to-live/TiltMenu.ts:367-375
func _scheme_card(
	card_name: String, scheme_name: String, keys: String, scheme: Types.ControlScheme
) -> Button:
	var is_active: bool = _settings.scheme == scheme
	var card: Button = _button(card_name, "CardButton", "")
	card.custom_minimum_size.y = _px(SCHEME_CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# DIVERGENCE(UI-SYSTEM): Settings.dc.html — active ion on raised, else line on panel
	var face: PanelContainer = PanelContainer.new()
	var face_box: StyleBoxFlat = UiTheme.flat(
		UiTheme.COLOR_RAISED if is_active else UiTheme.COLOR_PANEL,
		UiTheme.COLOR_ION if is_active else UiTheme.COLOR_LINE,
		_px(UiTheme.CARD_RADIUS)
	)
	face_box.content_margin_left = _px(SCHEME_PAD_X)
	face_box.content_margin_right = _px(SCHEME_PAD_X)
	face.add_theme_stylebox_override("panel", face_box)
	var info: VBoxContainer = VBoxContainer.new()
	info.add_theme_constant_override("separation", _px(SCHEME_NAME_GAP))
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label: Label = UiTheme.text(scheme_name, "FieldText")
	name_label.add_theme_color_override(
		"font_color", UiTheme.COLOR_TEXT if is_active else UiTheme.TEXT_SECONDARY
	)
	info.add_child(name_label)
	var keys_label: Label = UiTheme.text(keys, "MonoFaintText")
	# DIVERGENCE(M11c review): "phone gyroscope" was cut to "phone gyrosc…"; wrap first.
	keys_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys_label.max_lines_visible = WRAP_MAX_LINES
	keys_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(keys_label)
	face.add_child(info)
	card.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node: Node in face.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


# The Handling link. PORT: web/src/tilt-to-live/TiltMenu.ts:390-392; board text (R6).
# DIVERGENCE(UI-SYSTEM): Settings.dc.html — 12 px muted, underlined in line_strong.
# A flat Button carries the 48 px target; a RichTextLabel draws the underline,
# which a Button's own text cannot.
func _armory_link() -> Button:
	var link: Button = _button("ArmoryLink", "", "")
	link.flat = true
	link.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
	var words: RichTextLabel = RichTextLabel.new()
	words.bbcode_enabled = true
	words.text = (
		# DIVERGENCE(UI R4): shorter, so it fits one line on the phone.
		"[u color=#%s]Turn rate & sensitivity: Armory › Handling[/u]"
		% UiTheme.COLOR_LINE_STRONG.to_html(false)
	)
	words.scroll_active = false
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.add_theme_color_override("default_color", UiTheme.COLOR_TEXT_MUTED)
	words.add_theme_font_size_override("normal_font_size", _px(LINK_SIZE))
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	link.add_child(words)
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return link


# PORT: web/src/tilt-to-live/TiltMenu.ts:310-349 (Readability)
# PORT-NOTE: the Aim line switch (:323-328, :435-439) is omitted — the port never
# drew the tether (ruling R3); settings.tether_line still loads and saves.
func _readability_column() -> VBoxContainer:
	var column: VBoxContainer = _options_column("Readability")  # PORT: :312
	var s: GameOptionsManager.GameSettings = _options.settings
	# PORT: :315-318; hint from the board (R6)
	column.add_child(
		_switch_card(
			"HaloSwitch", "Enemy outlines", "White ring on every dot.", s.high_contrast_halo
		)
	)
	# DIVERGENCE(UI-SYSTEM): System.dc.html — Rule N: the grid row has no board
	# slot and is kept in the Readability column (ruling R8). PORT: :330-335
	# DIVERGENCE(UI R4): the hint said "Off by default"; the grid is on by default since M11c.
	column.add_child(
		_switch_card(
			"GridSwitch", "Background grid", "Ripples when things explode.", s.show_gridlines
		)
	)
	column.add_child(_shake_card())
	return column


# PORT: web/src/tilt-to-live/TiltMenu.ts:337-347 (Screen shake)
func _shake_card() -> PanelContainer:
	var card: PanelContainer = _options_card()
	var box: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	box.content_margin_top = _px(SHAKE_PAD_TOP)
	box.content_margin_bottom = _px(SHAKE_PAD_BOTTOM)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", _px(SHAKE_GAP))
	stack.add_child(_card_label("Screen shake"))  # PORT: :340
	var segmented: PanelContainer = PanelContainer.new()
	segmented.theme_type_variation = "Segmented"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(UiTheme.SEGMENT_PAD))
	row.add_child(_shake_button("ShakeOff", "Off", GameOptionsManager.ScreenShake.OFF))  # :343
	row.add_child(_shake_button("ShakeLow", "Low", GameOptionsManager.ScreenShake.LOW))  # :344
	row.add_child(_shake_button("ShakeFull", "Full", GameOptionsManager.ScreenShake.FULL))  # :345
	segmented.add_child(row)
	stack.add_child(segmented)
	card.add_child(stack)
	return card


func _shake_button(
	button_name: String, label: String, shake: GameOptionsManager.ScreenShake
) -> Button:
	var button: Button = _button(button_name, "SegmentButton", label)
	# button_pressed is ignored unless toggle_mode is true.
	button.toggle_mode = true
	button.set_pressed_no_signal(_is_current_shake(shake))
	button.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


# isCurrentShake: 'normal' and 'full' mark the same segment.
# PORT: web/src/tilt-to-live/TiltMenu.ts:280-285
func _is_current_shake(val: GameOptionsManager.ScreenShake) -> bool:
	var current: GameOptionsManager.ScreenShake = _options.settings.screen_shake
	if val == GameOptionsManager.ScreenShake.NORMAL or val == GameOptionsManager.ScreenShake.FULL:
		return (
			current == GameOptionsManager.ScreenShake.NORMAL
			or current == GameOptionsManager.ScreenShake.FULL
		)
	return current == val


# PORT: web/src/tilt-to-live/TiltMenu.ts:351-357 (Audio) and :395-405 (Data)
# PORT-NOTE: the TS audio hints (:355-356) are dropped; the board has none (R6).
func _audio_column() -> VBoxContainer:
	var column: VBoxContainer = _options_column("Audio")  # PORT: :353
	var s: GameOptionsManager.GameSettings = _options.settings
	column.add_child(_switch_card("SfxSwitch", "Sound", "", s.sfx_enabled))  # PORT: :355
	column.add_child(_switch_card("MusicSwitch", "Music", "", s.music_enabled))  # PORT: :356
	var data: MarginContainer = MarginContainer.new()
	data.add_theme_constant_override("margin_top", _px(DATA_TOP))
	data.add_child(_section_heading("Data"))  # PORT: :397
	column.add_child(data)
	var card: PanelContainer = _options_card()
	# PORT: :400 (label); the hint is the board's (R6)
	var row: HBoxContainer = _card_row("Reset progress", "Cannot be undone.")
	var reset: Button = _button("ResetButton", "SecondaryButton", "Reset")  # PORT: :403
	reset.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# DIVERGENCE(UI-SYSTEM): Settings.dc.html — Reset: line_strong 1px, r 4, muted 13
	var reset_box: StyleBoxFlat = UiTheme.padded(
		UiTheme.flat(Color.TRANSPARENT, UiTheme.COLOR_LINE_STRONG, _px(RESET_RADIUS)),
		_px(UiTheme.BUTTON_PAD_X),
		0.0
	)
	reset.add_theme_stylebox_override("normal", reset_box)
	reset.add_theme_stylebox_override("hover", reset_box)
	reset.add_theme_font_override("font", UiTheme.sans(UiTheme.Weight.REGULAR))
	reset.add_theme_font_size_override("font_size", _px(RESET_FONT))
	reset.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_MUTED)
	reset.add_theme_color_override("font_hover_color", UiTheme.COLOR_TEXT_MUTED)
	row.add_child(reset)
	card.add_child(row)
	column.add_child(card)
	return column


# DIVERGENCE(UI-SYSTEM): Settings.dc.html — switch card: panel, line 1px, r 6,
# min 60 tall, padding 8/12/8/14.
func _options_card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiTheme.flat(
		UiTheme.COLOR_PANEL, UiTheme.COLOR_LINE, _px(UiTheme.CARD_RADIUS)
	)
	box.content_margin_top = _px(SWITCH_PAD_Y)
	box.content_margin_bottom = _px(SWITCH_PAD_Y)
	box.content_margin_right = _px(SWITCH_PAD_RIGHT)
	box.content_margin_left = _px(SWITCH_PAD_LEFT)
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size.y = _px(SWITCH_CARD_HEIGHT)
	return card


# A label over an optional hint, beside the card's control.
func _card_row(label: String, hint: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(SWITCH_GAP))
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", _px(SWITCH_TEXT_GAP))
	info.add_child(_card_label(label))
	if hint != "":
		# DIVERGENCE(UI-SYSTEM): Settings.dc.html — hint 12 in faint
		var hint_label: Label = UiTheme.text(hint, "HintText")
		hint_label.add_theme_color_override("font_color", UiTheme.TEXT_FAINT)
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(hint_label)
	row.add_child(info)
	return row


# DIVERGENCE(UI-SYSTEM): Settings.dc.html — card label 14 / 500 in text
func _card_label(label: String) -> Label:
	var out: Label = UiTheme.text(label, "LabelText")
	out.add_theme_font_override("font", UiTheme.sans(UiTheme.Weight.MEDIUM))
	out.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return out


# A switch card. PORT: web/src/tilt-to-live/TiltMenu.ts:262-278 (renderToggleSwitch)
# DIVERGENCE(UI-SYSTEM): Settings.dc.html — 64 not 60: the 48 rule (interface spec §4.5).
# The Switch is 48 tall for the touch target, so the card is 64 tall where the board
# draws 60.
func _switch_card(switch_name: String, label: String, hint: String, is_on: bool) -> PanelContainer:
	var card: PanelContainer = _options_card()
	var row: HBoxContainer = _card_row(label, hint)
	var switch: CheckButton = CheckButton.new()
	switch.name = switch_name
	switch.theme_type_variation = "Switch"
	switch.set_pressed_no_signal(is_on)
	switch.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
	switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(switch)
	card.add_child(row)
	return card


# The reset confirm sheet (ruling R11). PORT: web/src/tilt-to-live/TiltMenu.ts:507-509
func _build_reset_confirm() -> void:
	var sheet: PanelContainer = UiTheme.build_sheet(_reset_confirm, PauseSheet.SCRIM_ALPHA)
	sheet.custom_minimum_size.x = _px(PauseSheet.SHEET_WIDTH)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", _px(PauseSheet.STACK_GAP))
	# DIVERGENCE(UI-SYSTEM): Settings.dc.html — 14 px in text (the card label size)
	var question: Label = UiTheme.text(RESET_CONFIRM_TEXT, "LabelText")
	question.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(question)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", _px(PauseSheet.ROW_GAP))
	var cancel: Button = _button("ResetCancelButton", "PrimaryButton", "Cancel")
	var confirm: Button = _button("ResetConfirmButton", "SecondaryButton", "Reset")
	for button: Button in [cancel, confirm]:
		button.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	stack.add_child(buttons)
	sheet.add_child(stack)


func _button(button_name: String, variation: String, label: String) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.theme_type_variation = variation
	button.text = label
	return button


func _px(base: float) -> int:
	return UiTheme.px(base, _ui_scale)
