## run_over_sheet.gd
## PORTS: nothing — new file per interface spec §6.3 (RunOver.dc.html). The
##        game-over modal's content is TiltGame.ts:1180-1232 (markup) and
##        :2088-2122 (population), :2132-2144 (earned milestones);
##        GoalsHUD.ts:129-135 (bindGameOverClicks). HudController fills and
##        wires it by name.
class_name RunOverSheet
extends Control
## The Run over overlay: a void scrim and a two-column Sheet, built in code so
## each board literal carries its citation. The Theme comes from the Hud above.

## Tapping the points row or the milestones list. PORT: web/src/tilt-to-live/GoalsHUD.ts:129-135
signal milestones_requested

const CONTROL_PICKER: PackedScene = preload("res://scenes/control_picker.tscn")

## DIVERGENCE(UI-SYSTEM): RunOver.dc.html — scrim rgba(8,9,14,0.86), sheet
## 700×346, column gap 28, left stack gap 16, score block gap 6, banner flare 8%
## fill / 30% border r4 pad 8 gap 8 text 13, stat cells pad 12/6 gap 4, right
## stack gap 10, steer label width 44, steer row gap 10, bottom row gap 8, the
## space in "Spend 7,331" at 14 px.
const SCRIM_ALPHA: float = 0.86
const SHEET_WIDTH: int = 700
const SHEET_HEIGHT: int = 346
const COLUMN_GAP: int = 28
const LEFT_GAP: int = 16
const SCORE_GAP: int = 6
const BANNER_FILL_ALPHA: float = 0.08
const BANNER_BORDER_ALPHA: float = 0.3
const BANNER_RADIUS: int = 4
const BANNER_PAD: int = 8
const BANNER_GAP: int = 8
const BANNER_FONT: int = 13
const CELL_PAD_Y: int = 12
const CELL_PAD_X: int = 6
const CELL_GAP: int = 4
const RIGHT_GAP: int = 10
const STEER_LABEL_WIDTH: int = 44
const STEER_GAP: int = 10
const BOTTOM_GAP: int = 8
const SPEND_GAP: int = 4

## Earned-milestone rows. DIVERGENCE(UI-SYSTEM): RunOver.dc.html — list gap 6,
## row gap 9, the HUD toast's 14 px check, text 13 #C7CDDB, points Mono 12 flare.
const LIST_GAP: int = 6
const ROW_GAP: int = 9
const ROW_POINTS_SIZE: int = 12
## DIVERGENCE(M11c review): shown under "Points earned" when a run earned none.
const EARNED_HINT: String = "Points come from milestones and coin pickups."

var _ui_scale: float = 1.0
var _points_row: HBoxContainer = null
var _coins_row: HBoxContainer = null
var _coins_detail: Label = null
var _earned_hint: Label = null
var _milestones: VBoxContainer = null
var _shown_milestones: Array[GoalManager.Goal] = []
var _sheet: PanelContainer = null
var _columns: HBoxContainer = null
var _left: VBoxContainer = null
var _right: VBoxContainer = null
var _score_block: VBoxContainer = null
var _score: Label = null
var _subtitle: Label = null
var _banner: PanelContainer = null
var _banner_row: HBoxContainer = null
var _star: TextureRect = null
var _new_best: Label = null
var _cells: Array[PanelContainer] = []
var _cell_stacks: Array[VBoxContainer] = []
var _kills: Label = null
var _chain: Label = null
var _time: Label = null
var _earned: Label = null
var _balance: Label = null
var _steer_row: HBoxContainer = null
var _steer_caption: Label = null
var _picker: ControlPicker = null
var _retry: Button = null
var _bottom: HBoxContainer = null
var _menu: Button = null
var _spend: Button = null
var _spend_row: HBoxContainer = null
var _spend_value: Label = null


func _ready() -> void:
	# The scrim swallows taps meant for the arena underneath.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	set_ui_scale(1.0)


## Scales the sheet and every board size in it.
func set_ui_scale(scale: float) -> void:
	_ui_scale = scale
	_sheet.custom_minimum_size = Vector2(SHEET_WIDTH, SHEET_HEIGHT) * scale
	_columns.add_theme_constant_override("separation", UiTheme.px(COLUMN_GAP, scale))
	_left.add_theme_constant_override("separation", UiTheme.px(LEFT_GAP, scale))
	_right.add_theme_constant_override("separation", UiTheme.px(RIGHT_GAP, scale))
	_score_block.add_theme_constant_override("separation", UiTheme.px(SCORE_GAP, scale))
	_banner.add_theme_stylebox_override(
		"panel",
		UiTheme.padded(
			UiTheme.flat(
				UiTheme.tint(UiTheme.COLOR_FLARE, BANNER_FILL_ALPHA),
				UiTheme.tint(UiTheme.COLOR_FLARE, BANNER_BORDER_ALPHA),
				UiTheme.px(BANNER_RADIUS, scale)
			),
			UiTheme.px(BANNER_PAD, scale),
			UiTheme.px(BANNER_PAD, scale)
		)
	)
	_banner_row.add_theme_constant_override("separation", UiTheme.px(BANNER_GAP, scale))
	_star.texture = UiTheme.svg_texture(UiTheme.ICON_STAR, scale)
	_new_best.add_theme_font_size_override("font_size", UiTheme.px(BANNER_FONT, scale))
	for cell: PanelContainer in _cells:
		cell.add_theme_stylebox_override(
			"panel",
			UiTheme.padded(
				UiTheme.flat(UiTheme.STAT_CELL, Color.TRANSPARENT, 0),
				UiTheme.px(CELL_PAD_X, scale),
				UiTheme.px(CELL_PAD_Y, scale)
			)
		)
	for stack: VBoxContainer in _cell_stacks:
		stack.add_theme_constant_override("separation", UiTheme.px(CELL_GAP, scale))
	_steer_row.add_theme_constant_override("separation", UiTheme.px(STEER_GAP, scale))
	_steer_caption.custom_minimum_size.x = STEER_LABEL_WIDTH * scale
	_retry.custom_minimum_size.y = UiTheme.HERO_TARGET * scale
	_bottom.add_theme_constant_override("separation", UiTheme.px(BOTTOM_GAP, scale))
	for button: Button in [_menu, _spend]:
		button.custom_minimum_size.y = UiTheme.TOUCH_TARGET * scale
	_spend_row.add_theme_constant_override("separation", UiTheme.px(SPEND_GAP, scale))
	_picker.set_ui_scale(scale)
	_milestones.add_theme_constant_override("separation", UiTheme.px(LIST_GAP, scale))
	_fill_milestones(_shown_milestones)


## Fills every figure. PORT: web/src/tilt-to-live/TiltGame.ts:2093-2122
func show_result(result: RunResult) -> void:
	_score.text = UiTheme.group_digits(result.score)  # PORT: :2093
	_subtitle.text = subtitle_text(result.time_text, result.mode_name, result.mode_multiplier)
	_banner.visible = result.best_diff > 0  # PORT: :2097-2102
	_new_best.text = "New best — up %s" % UiTheme.group_digits(result.best_diff)  # PORT: :2098
	_kills.text = str(result.kills)  # PORT: :2104
	_chain.text = "%d×" % result.best_chain  # PORT: :2105
	_time.text = result.time_text  # PORT: :2107
	_earned.text = "+%s" % UiTheme.group_digits(result.earned)  # PORT: :2121
	_earned_hint.visible = result.earned == 0
	_balance.text = UiTheme.group_digits(result.balance)  # PORT: :2121
	_spend_value.text = UiTheme.group_digits(result.balance)  # PORT: :2122
	_fill_milestones(result.milestones)  # PORT: :2132-2144


## The coins row, shown only after a pickup. PORT: web/src/tilt-to-live/TiltGame.ts:2124-2130
func set_coins(collected: int, points: int) -> void:
	_coins_row.visible = collected > 0  # PORT: :2124, :2127, :2129
	var unit: String = "pt" if points == 1 else "pts"  # PORT: :2126
	_coins_detail.text = "%d · +%s %s" % [collected, UiTheme.group_digits(points), unit]


## The coins row's figures, e.g. "3 · +120 pts" (TiltGame.ts:2126).
func coins_detail_text() -> String:
	return _coins_detail.text


## "Swarmed at 1:42 — Standard, 1.0×". PORT: web/src/tilt-to-live/TiltGame.ts:2095
static func subtitle_text(time_text: String, mode_name: String, mode_multiplier: float) -> String:
	return "Swarmed at %s — %s, %.1f×" % [time_text, mode_name, mode_multiplier]


func _build() -> void:
	_sheet = UiTheme.build_sheet(self, SCRIM_ALPHA)
	_columns = HBoxContainer.new()
	_sheet.add_child(_columns)
	_columns.add_child(_build_left())
	# DIVERGENCE(UI-SYSTEM): RunOver.dc.html — border-left
	_columns.add_child(UiTheme.hairline(true, UiTheme.COLOR_LINE))
	_columns.add_child(_build_right())


func _build_left() -> VBoxContainer:
	_left = UiTheme.sheet_column("LeftColumn")
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_score_block = VBoxContainer.new()
	_score = _centered("FinalScoreLabel", "BigScoreText")
	_score_block.add_child(_score)
	_subtitle = _centered("FinalSubtitleLabel", "BodyText")
	_subtitle.add_theme_color_override("font_color", UiTheme.TEXT_FAINT)
	_score_block.add_child(_subtitle)
	_left.add_child(_score_block)

	_banner = PanelContainer.new()
	_banner.name = "NewBestBanner"
	_banner_row = HBoxContainer.new()
	_banner_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_star = TextureRect.new()
	_star.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_banner_row.add_child(_star)
	_new_best = UiTheme.text("", "StrongText")
	_new_best.name = "NewBestLabel"
	_new_best.add_theme_color_override("font_color", UiTheme.COLOR_FLARE)
	_banner_row.add_child(_new_best)
	_banner.add_child(_banner_row)
	_left.add_child(_banner)

	# 3-cell stat grid; the line-coloured frame shows through the 1 px gaps.
	# DIVERGENCE(UI-SYSTEM): RunOver.dc.html — gap 1px on #262C38, r 6
	var grid_frame: PanelContainer = PanelContainer.new()
	grid_frame.name = "StatGrid"
	grid_frame.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_LINE, UiTheme.COLOR_LINE, UiTheme.CARD_RADIUS)
	)
	var grid: HBoxContainer = HBoxContainer.new()
	grid.add_theme_constant_override("separation", 1)
	_kills = _stat_cell(grid, "FinalKillsLabel", "Kills")
	_chain = _stat_cell(grid, "FinalChainLabel", "Best chain")
	_time = _stat_cell(grid, "FinalTimeLabel", "Alive")
	grid_frame.add_child(grid)
	_left.add_child(grid_frame)
	return _left


func _build_right() -> VBoxContainer:
	_right = UiTheme.sheet_column("RightColumn")
	_points_row = HBoxContainer.new()
	_points_row.name = "PointsRow"
	var caption: Label = UiTheme.text("Points earned", "BodyText")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points_row.add_child(caption)
	_earned = UiTheme.text("", "PointsText")
	_earned.name = "PointsEarnedLabel"
	_points_row.add_child(_earned)
	var arrow: Label = UiTheme.text("→", "PointsText")
	arrow.add_theme_color_override("font_color", UiTheme.TEXT_FAINT)
	_points_row.add_child(arrow)
	_balance = UiTheme.text("", "PointsText")
	_balance.name = "PointsBalanceLabel"
	_points_row.add_child(_balance)
	# PORT: web/src/tilt-to-live/GoalsHUD.ts:133-134 (.gameover-points-box opens the screen)
	_points_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_points_row.gui_input.connect(_on_rows_gui_input)
	_right.add_child(_points_row)
	# DIVERGENCE(M11c review, emulator play 2026-09-27): "+0 → 5,531" after a 590-score
	# run read as broken. Points come only from milestones and coins (the TS sums
	# those, TiltGame.ts:2118), so a zero run says where points come from.
	_earned_hint = UiTheme.text(EARNED_HINT, "HintText")
	_earned_hint.name = "PointsEarnedHint"
	_earned_hint.visible = false
	_right.add_child(_earned_hint)

	# M11a R17: the TS coins row (TiltGame.ts:1217-1220) under the points row.
	# DIVERGENCE(UI-SYSTEM): RunOver.dc.html — Rule N: the board has no coins row; it
	# takes the Points earned row's styles.
	_coins_row = HBoxContainer.new()
	_coins_row.name = "CoinsRow"
	_coins_row.visible = false
	var coins_caption: Label = UiTheme.text("Coin pickups", "BodyText")  # PORT: :1218
	coins_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coins_row.add_child(coins_caption)
	_coins_detail = UiTheme.text("", "PointsText")
	_coins_detail.name = "CoinsDetailLabel"
	_coins_row.add_child(_coins_detail)
	_right.add_child(_coins_row)

	# M9 plan R9: the list sits in the board's flex gap (RunOver.dc.html's
	# flex-grow spacer) and clips there, so a long list never grows the sheet.
	var clip: Control = Control.new()
	clip.name = "MilestonesClip"
	clip.clip_contents = true
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_milestones = VBoxContainer.new()
	_milestones.name = "MilestonesList"
	_milestones.visible = false
	# PORT: web/src/tilt-to-live/GoalsHUD.ts:131-132 (the list opens the screen)
	_milestones.mouse_filter = Control.MOUSE_FILTER_STOP
	_milestones.gui_input.connect(_on_rows_gui_input)
	clip.add_child(_milestones)
	_milestones.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_right.add_child(clip)

	_steer_row = HBoxContainer.new()
	_steer_caption = UiTheme.caps("Steer")
	_steer_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_steer_row.add_child(_steer_caption)
	_picker = CONTROL_PICKER.instantiate() as ControlPicker
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steer_row.add_child(_picker)
	_right.add_child(_steer_row)

	_retry = Button.new()
	_retry.name = "RestartButton"
	_retry.theme_type_variation = "PrimaryButton"
	_retry.text = "Retry"  # PORT: web/src/tilt-to-live/TiltGame.ts:1223
	_right.add_child(_retry)

	_bottom = HBoxContainer.new()
	_menu = Button.new()
	_menu.name = "GameOverMenuButton"
	_menu.theme_type_variation = "SecondaryButton"
	_menu.text = "Menu"  # PORT: web/src/tilt-to-live/TiltGame.ts:1226
	_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom.add_child(_menu)
	_spend = Button.new()
	_spend.name = "GameOverArmoryButton"
	_spend.theme_type_variation = "SecondaryButton"
	_spend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# "Spend <points>": two colours, so two Labels over an empty-text Button.
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spend_row = HBoxContainer.new()
	_spend_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var word: Label = UiTheme.text("Spend", "LabelText")  # PORT: web/src/tilt-to-live/TiltGame.ts:2122
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spend_row.add_child(word)
	_spend_value = UiTheme.text("", "PointsText")
	_spend_value.name = "SpendValueLabel"
	_spend_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spend_row.add_child(_spend_value)
	center.add_child(_spend_row)
	_spend.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bottom.add_child(_spend)
	_right.add_child(_bottom)
	return _right


func _centered(label_name: String, variation: String) -> Label:
	var label: Label = UiTheme.text("", variation)
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _stat_cell(grid: HBoxContainer, value_name: String, caption: String) -> Label:
	var cell: PanelContainer = PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack: VBoxContainer = VBoxContainer.new()
	var value: Label = _centered(value_name, "StatText")
	stack.add_child(value)
	# The board draws these caps at 9 px; the System floor is 10 (Global Constraints).
	var label: Label = UiTheme.caps(caption)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(label)
	cell.add_child(stack)
	grid.add_child(cell)
	_cells.append(cell)
	_cell_stacks.append(stack)
	return value


## PORT: web/src/tilt-to-live/TiltGame.ts:2132-2144
func _fill_milestones(goals: Array[GoalManager.Goal]) -> void:
	_shown_milestones = goals
	for child: Node in _milestones.get_children():
		_milestones.remove_child(child)
		child.queue_free()
	for goal: GoalManager.Goal in goals:
		_milestones.add_child(_milestone_row(goal))
	_milestones.visible = not goals.is_empty()


## One earned milestone. PORT: web/src/tilt-to-live/TiltGame.ts:2133-2139
## DIVERGENCE(UI-SYSTEM): RunOver.dc.html — row styles (M9 plan R6 is superseded).
func _milestone_row(goal: GoalManager.Goal) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "MilestoneRow_" + goal.id
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiTheme.px(ROW_GAP, _ui_scale))
	var check: TextureRect = TextureRect.new()
	check.texture = UiTheme.svg_texture(UiTheme.ICON_CHECK, _ui_scale)
	check.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(check)
	var text: Label = UiTheme.text("%s — %s" % [goal.title, goal.description], "BodyText")
	text.name = "MilestoneText"
	text.add_theme_color_override("font_color", UiTheme.TEXT_SECONDARY)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var pts: Label = UiTheme.text(UiTheme.reward_text(goal.reward_points), "PointsText")
	pts.name = "MilestonePoints"
	pts.add_theme_font_override("font", UiTheme.mono(UiTheme.Weight.REGULAR))
	pts.add_theme_font_size_override("font_size", UiTheme.px(ROW_POINTS_SIZE, _ui_scale))
	pts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pts)
	return row


## bindGameOverClicks' handler. PORT: web/src/tilt-to-live/GoalsHUD.ts:131-134
func _on_rows_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		milestones_requested.emit()


## What the sheet shows, gathered by HudController.run_result_for().
class RunResult:
	extends RefCounted
	var score: int = 0
	var kills: int = 0
	var best_chain: int = 1
	var time_text: String = "0:00"
	var mode_name: String = ""
	var mode_multiplier: float = 1.0
	## 0 hides the New best banner.
	var best_diff: int = 0
	var earned: int = 0
	var balance: int = 0
	## The goals evaluateRun completed. PORT: web/src/tilt-to-live/TiltGame.ts:2086
	var milestones: Array[GoalManager.Goal] = []
