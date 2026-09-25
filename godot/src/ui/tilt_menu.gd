# gdlint:ignore=max-public-methods
## tilt_menu.gd
## PORTS: web/src/tilt-to-live/TiltMenu.ts (523 lines, source commit 7be9614)
# PORT-NOTE: TiltMenu.ts's menu and options modal (Task 5) together exceed
# gdlint's default max-public-methods (20), as in audio_bank.gd.
class_name TiltMenu
extends Control
## The start menu, the Settings (options) modal and the reset confirm, built in
## code on the Main and Settings boards (interface spec §6.6). Holds no sim
## system; every action is a signal GameRoot answers (TiltMenu.ts:15-18's callbacks).
##
## PORT-NOTE: initDOM (:45-67) creates the two DOM roots; _ready builds
## MenuContainer and (Task 5) OptionsModal instead. show/hide/isVisible (:69-85)
## are show_menu/hide_menu/is_menu_visible — CanvasItem already owns those names.
##
## The root stays visible and ignores the mouse; only MenuContainer hides, so the
## options modal (a sibling of MenuContainer, Task 5) can open while the menu is
## hidden (controller ruling P1). The parent anchors this node full-rect.

## PORT: web/src/tilt-to-live/TiltMenu.ts:15 (onLaunchGame)
signal launch_requested(mode: Types.GameMode)
## PORT: web/src/tilt-to-live/TiltMenu.ts:16 (onOpenArmory)
signal armory_requested
## PORT: web/src/tilt-to-live/TiltMenu.ts:17 (onOpenAllGoals)
signal all_goals_requested
## The Steer row's calibrate icon opens the Calibrate screen (ruling R5).
signal calibrate_screen_requested
## The Steer row's picker chose a scheme (ruling R7).
signal scheme_chosen(scheme: Types.ControlScheme)

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
const PICKER_WIDTH: int = 176
## DIVERGENCE(UI-SYSTEM): Main.dc.html — stats row padding-top 14, gap 28;
## stat column gap 3; value Mono 500 17.
const STATS_PAD_TOP: int = 14
const STATS_GAP: int = 28
const STAT_GAP: int = 3
const STAT_VALUE_SIZE: int = 17
## DIVERGENCE(UI-SYSTEM): Milestones.dc.html — milestone progress meter 4 tall
const TEASER_METER_HEIGHT: int = 4
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
const MULT_SIZE: int = 13
## DIVERGENCE(UI-SYSTEM): Main.dc.html — Play 18 px with a 10 px icon gap;
## nav row gap 8, margin-top 2.
const PLAY_FONT: int = 18
const PLAY_ICON_GAP: int = 10
const NAV_GAP: int = 8
const NAV_TOP: int = 2

## DIVERGENCE(UI-SYSTEM): Main.dc.html — Play glyph (verbatim but for the xmlns)
const ICON_PLAY: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">'
	+ '<path d="M4 2.5 L13 8 L4 13.5 Z" fill="#08090E"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): Main.dc.html — Settings gear (verbatim but for the xmlns)
const ICON_GEAR: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 16 16" fill="none">'
	+ '<circle cx="8" cy="8" r="2.4" stroke="#C7CDDB" stroke-width="1.3"/>'
	+ '<path d="M8 1.6 V3.4 M8 12.6 V14.4 M1.6 8 H3.4 M12.6 8 H14.4 M3.5 3.5 L4.7 4.7 '
	+ 'M11.3 11.3 L12.5 12.5 M12.5 3.5 L11.3 4.7 M4.7 11.3 L3.5 12.5" stroke="#C7CDDB" '
	+ 'stroke-width="1.3" stroke-linecap="round"/></svg>'
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
var _menu_container: Control = null
var _drawn_mode: Types.GameMode = Types.GameMode.CLASSIC


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_container = Control.new()
	_menu_container.name = "MenuContainer"
	_menu_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_container)
	_menu_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	_menu_container.add_child(_title_block())
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
	var teaser: VBoxContainer = _next_teaser()
	if teaser != null:
		left.add_child(teaser)
	var picker: ControlPicker = _steer_row(left)
	# PORT: web/src/tilt-to-live/TiltMenu.ts:180 — stats only once a best exists
	if best_score > 0:
		left.add_child(_stats_row(best_score, points, completed_goals, total_goals))
	picker.set_active_scheme(_settings.scheme)
	_bind_events()


## Rebuilds the board sizes at `scale` and insets the left and title blocks by
## `inset`; the right panel stays flush right, as the board draws it.
func set_ui_scale(scale: float, inset: Vector2) -> void:
	_ui_scale = scale
	_inset = inset
	theme = UiTheme.build(scale)
	render()


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
	# TODO(M11a): Task 5 connects MenuSettingsButton to open_options_modal (:252-254).
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
	block.add_child(title)
	var subtitle: Label = UiTheme.text("Move to dodge. The guns fire themselves.", "BodyText")  # :135
	subtitle.add_theme_font_size_override("font_size", _px(SUBTITLE_SIZE))
	block.add_child(subtitle)
	block.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	block.offset_left = _px(TITLE_LEFT) + _inset.x
	block.offset_top = _px(TITLE_TOP) + _inset.y
	return block


# The next-milestone teaser. PORT: web/src/tilt-to-live/TiltMenu.ts:96-126, :198-207
# DIVERGENCE(UI-SYSTEM): System.dc.html — Rule N: TS content with no board slot,
# kept above the Steer row and styled from System tokens (ruling R8).
func _next_teaser() -> VBoxContainer:
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
	# DIVERGENCE(UI-SYSTEM): Main.dc.html — the stat column's caps-over-value gap 3
	teaser.add_theme_constant_override("separation", _px(STAT_GAP))
	var tag: Label = UiTheme.caps("Next")  # PORT: :201
	tag.add_theme_color_override("font_color", UiTheme.COLOR_FLARE)
	teaser.add_child(tag)
	var desc: Label = UiTheme.text("%s — %s" % [g.title, g.description], "HintText")  # PORT: :202
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.clip_text = true
	teaser.add_child(desc)
	var fill: ProgressBar = UiTheme.meter(
		pct / 100.0, UiTheme.COLOR_FLARE, _px(LEFT_WIDTH), _px(TEASER_METER_HEIGHT)
	)
	fill.name = "NextTeaserFill"
	teaser.add_child(fill)
	return teaser


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
	columns.add_child(_stat_column("Milestones", milestones))  # PORT: :191
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
	nav.add_child(_nav_button("MenuArmoryButton", "Armory"))  # PORT: :173
	nav.add_child(_nav_button("MenuMilestonesButton", "Milestones"))  # PORT: :174
	# PORT: web/src/tilt-to-live/TiltMenu.ts:175 — "Settings", drawn as the board's gear
	var settings: Button = _button("MenuSettingsButton", "GhostIconButton", "")
	settings.tooltip_text = "Settings"
	settings.custom_minimum_size = Vector2.ONE * _px(UiTheme.TOUCH_TARGET)
	settings.icon = UiTheme.svg_texture(ICON_GEAR, _ui_scale)
	settings.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(settings)
	nav_pad.add_child(nav)
	stack.add_child(nav_pad)
	panel.add_child(stack)
	return panel


func _nav_button(button_name: String, label: String) -> Button:
	var button: Button = _button(button_name, "SecondaryButton", label)
	button.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	tagline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tagline.clip_text = true
	info.add_child(tagline)
	row.add_child(info)
	var mult: Label = UiTheme.text(_format_multiplier(config.score_multiplier), "MonoText")
	mult.add_theme_font_override("font", UiTheme.mono(UiTheme.Weight.MEDIUM))
	mult.add_theme_font_size_override("font_size", _px(MULT_SIZE))
	mult.add_theme_color_override("font_color", config.color)
	mult.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mult)
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


# PORT: web/src/tilt-to-live/TiltMenu.ts:144 — toFixed(m % 1 === 0 ? 1 : 2) + "×" (:151)
func _format_multiplier(multiplier: float) -> String:
	return ("%.1f×" if fmod(multiplier, 1.0) == 0.0 else "%.2f×") % multiplier


func _button(button_name: String, variation: String, label: String) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.theme_type_variation = variation
	button.text = label
	return button


func _px(base: float) -> int:
	return UiTheme.px(base, _ui_scale)
