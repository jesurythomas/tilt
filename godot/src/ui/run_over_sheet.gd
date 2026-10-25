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
## DIVERGENCE(ADS R6): "Watch ad · 3× points" was tapped.
signal reward_requested
## DIVERGENCE(IAP R1): the Support the dev banner was tapped while it offers Remove ads.
signal support_requested

## DIVERGENCE(IAP R1): what the Support the dev banner shows. HIDDEN: no offer (owned before
## this sheet, or Play has not priced it). WAITING: Play's sheet is opening. PENDING: Play holds
## an unpaid purchase. THANKS: bought from this sheet.
enum SupportState { HIDDEN, OFFERED, WAITING, PENDING, THANKS }

const CONTROL_PICKER: PackedScene = preload("res://scenes/control_picker.tscn")

## DIVERGENCE(UI-SYSTEM): RunOver.dc.html — scrim rgba(8,9,14,0.86), sheet
## 700×346, column gap 28, left stack gap 16, score block gap 6, banner flare 8%
## fill / 30% border r4 pad 8 gap 8 text 13, stat cells pad 12/6 gap 4, right
## stack gap 10, steer label width 44, steer row gap 10, bottom row gap 8.
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

## Earned-milestone rows. DIVERGENCE(UI-SYSTEM): RunOver.dc.html — list gap 6,
## row gap 9, the HUD toast's 14 px check, text 13 #C7CDDB, points Mono 12 flare.
const LIST_GAP: int = 6
const ROW_GAP: int = 9
const ROW_POINTS_SIZE: int = 12
## DIVERGENCE(RUNOVER R1): the earned figure is the hero (score size, flare) and counts
## up from 0 over this long; a tap on the sheet skips to the total.
const COUNT_UP_SECONDS: float = 0.6
## DIVERGENCE(ADS R6): the rewarded ad's offer, under the figure it multiplies (its tooltip).
const REWARD_TEXT: String = "Watch ad · 3× points"
## DIVERGENCE(ADS R10, user 2026-10-14: "make it more appealing to look at"): the offer is a
## flare button — the points' colour — with a "3×" badge, "Watch ad", and the figure the run's
## points would become; a light sweeps across it every few seconds. Badge pad 6/1, row gap
## 10, sweep 0.8 s then 2.2 s still, the band 0.9 of the height wide, warm white at 22%; while its
## ad is on its way the row dims to 45% and reads "Opening ad…".
const REWARD_LABEL: String = "Watch ad"
const REWARD_WAITING_LABEL: String = "Opening ad…"
const REWARD_GAP: int = 10
const BADGE_PAD_X: int = 6
const BADGE_PAD_Y: int = 1
const SHINE_SECONDS: float = 0.8
const SHINE_REST_SECONDS: float = 2.2
const SHINE_WIDTH: float = 0.9
const SHINE_ALPHA: float = 0.22
const SHINE_COLOR: Color = Color("#FFE7C2")
const REWARD_WAITING_ALPHA: float = 0.45
## DIVERGENCE(IAP R1, user 2026-10-25: "We should add it in the game over screen ... removes
## ads ... at 25php"): the banner's words, a heart, and Play's price in a plasma chip; under the
## achievements, in their scroll, so it never grows the sheet. Content gap 10, text gap 1; while
## Play's sheet opens or a payment is pending the row dims as the 3× offer does.
const SUPPORT_TITLE: String = "Support the dev"
const SUPPORT_SUB: String = "Remove ads for good"
const SUPPORT_WAITING_SUB: String = "Opening Google Play…"
const SUPPORT_PENDING_SUB: String = "Payment pending"
const SUPPORT_THANKS_TITLE: String = "Thank you!"
const SUPPORT_THANKS_SUB: String = "Ads removed"
const SUPPORT_GAP: int = 10
const SUPPORT_TEXT_GAP: int = 1

var _ui_scale: float = 1.0
var _points_row: HBoxContainer = null
var _earned_target: int = 0
var _count_tween: Tween = null
var _milestones: VBoxContainer = null
## DIVERGENCE(ACH R3): "ACHIEVEMENTS · 3" over the list.
var _achievements_header: Label = null
var _achievements_row: HBoxContainer = null
var _trophy: TextureRect = null
var _press_at: Vector2 = Vector2.ZERO
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
var _reward: Button = null
var _reward_row: HBoxContainer = null
var _reward_badge: Label = null
var _reward_label: Label = null
var _reward_payoff: Label = null
var _reward_shine: RewardShine = null
var _shine_tween: Tween = null
var _steer_row: HBoxContainer = null
var _steer_caption: Label = null
var _picker: ControlPicker = null
var _retry: Button = null
var _bottom: HBoxContainer = null
var _menu: Button = null
var _spend: Button = null
var _support: Button = null
var _support_state: SupportState = SupportState.HIDDEN
var _support_row: HBoxContainer = null
var _support_text: VBoxContainer = null
var _support_heart: TextureRect = null
var _support_title: Label = null
var _support_sub: Label = null
var _support_price: Label = null
var _left_foot: VBoxContainer = null


func _ready() -> void:
	# The scrim swallows taps meant for the arena underneath.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	set_ui_scale(1.0)


# DIVERGENCE(ADS R10): the light rests while the sheet is hidden (a Retry with no ad leaves the
# offer standing into the next run), and sweeps again when it shows with the offer open.
func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED or _reward_shine == null:
		return
	if not is_visible_in_tree():
		_stop_shine()
	elif _reward.visible and not _reward.disabled:
		_start_shine()


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
	_reward.custom_minimum_size.y = UiTheme.TOUCH_TARGET * scale
	_scale_reward(scale)
	_scale_support(scale)
	_bottom.add_theme_constant_override("separation", UiTheme.px(BOTTOM_GAP, scale))
	for button: Button in [_menu, _spend]:
		UiTheme.scale_nav_button(button, scale)
	# DIVERGENCE(UI R13): Retry carries the restart glyph, as Play carries its triangle.
	_retry.icon = UiTheme.svg_texture(UiTheme.ICON_RETRY, scale)
	_trophy.texture = UiTheme.svg_texture(UiTheme.ICON_ACHIEVEMENTS, scale)
	_achievements_row.add_theme_constant_override("separation", UiTheme.px(BANNER_GAP, scale))
	_earned.add_theme_font_size_override("font_size", UiTheme.px(UiTheme.SCORE_SIZE, scale))
	_picker.set_ui_scale(scale)
	_fit_score()
	_milestones.add_theme_constant_override("separation", UiTheme.px(LIST_GAP, scale))
	_fill_milestones(_shown_milestones)


## Fills every figure. PORT: web/src/tilt-to-live/TiltGame.ts:2093-2122
func show_result(result: RunResult) -> void:
	_score.text = UiTheme.group_digits(result.score)  # PORT: :2093
	_fit_score()
	_subtitle.text = subtitle_text(result.time_text, result.mode_name)
	_banner.visible = result.best_diff > 0  # PORT: :2097-2102
	_new_best.text = "New best — up %s" % UiTheme.group_digits(result.best_diff)  # PORT: :2098
	_kills.text = str(result.kills)  # PORT: :2104
	_chain.text = "%d×" % result.best_chain  # PORT: :2105
	_time.text = result.time_text  # PORT: :2107
	# DIVERGENCE(RUNOVER R1): only what the run earned (user 2026-09-28: "i dont think users
	# need to know what the previous money was ... just showing how much they earned is
	# ok"), counting up; the TS showed "+earned → balance" (:2121).
	_start_count_up(result.earned)
	_fill_milestones(result.milestones)  # PORT: :2132-2144


## DIVERGENCE(RUNOVER R2, found 2026-10-12): a score too long for its column (11+ digits)
## shrinks to fit it; the TS let it overflow, and here it widened the sheet past Retry,
## Menu and Armory. The label clips, so its text never sets the column's width.
func _fit_score() -> void:
	var full: int = UiTheme.px(UiTheme.BIG_SCORE_SIZE, _ui_scale)
	var room: float = _score.size.x
	var font: Font = _score.get_theme_font("font")
	var fit: int = full
	if room > 0.0:
		while (
			fit > 1
			and font.get_string_size(_score.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x > room
		):
			fit -= 1
	_score.add_theme_font_size_override("font_size", fit)


## DIVERGENCE(ADS R6): shows the "Watch ad · 3× points" offer when `is_offered`; `is_waiting`
## greys it out while its ad is on its way. ADS R10: the light sweeps it only while it can be
## tapped.
func set_reward_offer(is_offered: bool, is_waiting: bool) -> void:
	_reward.visible = is_offered
	_reward.disabled = is_waiting
	_reward_label.text = REWARD_WAITING_LABEL if is_waiting else REWARD_LABEL
	_reward_row.modulate.a = REWARD_WAITING_ALPHA if is_waiting else 1.0
	_refresh_reward_payoff()
	if is_offered and not is_waiting:
		_start_shine()
	else:
		_stop_shine()


## True while the light sweeps the offer (ADS R10).
func is_reward_shining() -> bool:
	return _shine_tween != null


## DIVERGENCE(ADS R6): the earned figure counts up from where it stands to `earned`.
func show_bonus(earned: int) -> void:
	_start_count_up(earned, _earned_target)


## "+1,274" — the earned figure as shown.
static func earned_text(points: int) -> String:
	return "+%s" % UiTheme.group_digits(points)


## Jumps the count-up to the run's total (a tap on the sheet, or a test).
func finish_count_up() -> void:
	if _count_tween != null:
		_count_tween.kill()
		_count_tween = null
	_earned.text = earned_text(_earned_target)


func _start_count_up(target: int, from: int = 0) -> void:
	_earned_target = target
	_refresh_reward_payoff()
	if _count_tween != null:
		_count_tween.kill()
	_earned.text = earned_text(from)
	_count_tween = create_tween()
	(
		_count_tween
		. tween_method(
			func(v: float) -> void: _earned.text = earned_text(roundi(v)),
			float(from),
			float(target),
			COUNT_UP_SECONDS
		)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_CUBIC)
	)
	_count_tween.tween_callback(finish_count_up)


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and _count_tween != null:
		finish_count_up()


## "Swarmed at 1:42 — Survival". PORT: web/src/tilt-to-live/TiltGame.ts:2095
## DIVERGENCE(UI R12, user 2026-09-28: "the game over screen still shows 1.5 soemthing"):
## no ", 1.0×" (the mode cards dropped their multipliers in UI R8).
static func subtitle_text(time_text: String, mode_name: String) -> String:
	return "Swarmed at %s — %s" % [time_text, mode_name]


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
	_score.clip_text = true  # RUNOVER R2
	_score.resized.connect(_fit_score)
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
	# DIVERGENCE(RUNOVER R1): "enemies destroyed" (user 2026-09-28); the board said Kills.
	_kills = _stat_cell(grid, "FinalKillsLabel", "Destroyed")
	_chain = _stat_cell(grid, "FinalChainLabel", "Best chain")
	_time = _stat_cell(grid, "FinalTimeLabel", "Alive")
	grid_frame.add_child(grid)
	_left.add_child(grid_frame)
	# M9 plan R9: the list takes the column's free space, so a long list never grows the
	# sheet. DIVERGENCE(ACH R3): in the left column, under the stats — the right one had
	# room for one row beside Steer, Retry and the bottom row.
	# DIVERGENCE(ACH R3, user 2026-09-28: "when there are multiple achivements completed
	# on a run, the user cannot see all of those achievements"): it scrolls there, under
	# a count, instead of clipping.
	# DIVERGENCE(UI R13): the header carries the menu's trophy, as its nav button does.
	_achievements_row = HBoxContainer.new()
	_achievements_row.name = "AchievementsRow"
	_achievements_row.visible = false
	_trophy = TextureRect.new()
	_trophy.name = "AchievementsTrophy"
	_trophy.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_achievements_row.add_child(_trophy)
	_achievements_header = UiTheme.caps("")
	_achievements_header.name = "AchievementsHeader"
	_achievements_header.visible = false
	_achievements_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_achievements_row.add_child(_achievements_header)
	_left.add_child(_achievements_row)
	var clip: ScrollContainer = ScrollContainer.new()
	clip.name = "MilestonesClip"
	clip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip.mouse_filter = Control.MOUSE_FILTER_PASS
	_milestones = VBoxContainer.new()
	_milestones.name = "MilestonesList"
	_milestones.visible = false
	_milestones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# PORT: web/src/tilt-to-live/GoalsHUD.ts:131-132 (the list opens the screen) — on a
	# tap's release, so a drag scrolls instead (ACH R3).
	_milestones.mouse_filter = Control.MOUSE_FILTER_PASS
	_milestones.gui_input.connect(_on_list_gui_input)
	# DIVERGENCE(IAP R1): the list, then the Support the dev banner, scroll together.
	_left_foot = VBoxContainer.new()
	_left_foot.name = "LeftFoot"
	_left_foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_foot.mouse_filter = Control.MOUSE_FILTER_PASS
	_left_foot.add_child(_milestones)
	_left_foot.add_child(_build_support())
	clip.add_child(_left_foot)
	_left.add_child(clip)
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
	_earned.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points_row.add_child(_earned)
	# PORT: web/src/tilt-to-live/GoalsHUD.ts:133-134 (.gameover-points-box opens the screen)
	_points_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_points_row.gui_input.connect(_on_rows_gui_input)
	_right.add_child(_points_row)
	_right.add_child(_build_reward())
	# DIVERGENCE(RUNOVER R1): the TS coins row (TiltGame.ts:1217-1220) and the "+0" hint
	# went (user: "no need to know how many coins").

	# The board's flex gap: Steer, Retry and the bottom row sit at the column's foot.
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.add_child(gap)

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
	# DIVERGENCE(UI R13): Menu and Armory are the menu's nav buttons (glyph + label).
	_menu = UiTheme.nav_button("GameOverMenuButton", "Menu", UiTheme.ICON_HOME)  # PORT: :1226
	_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom.add_child(_menu)
	# DIVERGENCE(RUNOVER R1): "Armory" — the TS's "Spend <balance>" (:2122) showed the
	# balance again.
	_spend = UiTheme.nav_button("GameOverArmoryButton", "Armory", UiTheme.ICON_ARMORY)
	_spend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom.add_child(_spend)
	_right.add_child(_bottom)
	return _right


## DIVERGENCE(ADS R6, user 2026-10-14: "during game over screen, have a watch ads button for
## 3x the coins"): under the figure it triples, hidden until GameRoot offers a rewarded ad.
## ADS R10: badge, label and payoff in a row over a sweeping light; the row ignores the
## mouse, so the button takes the tap (as UiTheme.nav_button).
func _build_reward() -> Button:
	_reward = Button.new()
	_reward.name = "WatchAdButton"
	_reward.theme_type_variation = "RewardButton"
	_reward.tooltip_text = REWARD_TEXT
	_reward.clip_contents = true  # the sweep stays inside the button
	_reward.visible = false
	_reward.pressed.connect(reward_requested.emit)
	_reward_shine = RewardShine.new()
	_reward_shine.name = "RewardShine"
	_reward_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward.add_child(_reward_shine)
	_reward.resized.connect(_size_shine)
	_reward_row = HBoxContainer.new()
	_reward_row.name = "RewardContent"
	_reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reward_badge = UiTheme.text("%d×" % GameRoot.AD_REWARD_MULTIPLIER, "ChipText")
	_reward_badge.name = "RewardBadge"
	_reward_badge.add_theme_color_override("font_color", UiTheme.COLOR_VOID)
	_reward_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reward_row.add_child(_reward_badge)
	_reward_label = UiTheme.text(REWARD_LABEL, "")
	_reward_label.name = "RewardLabel"
	_reward_label.add_theme_font_override("font", UiTheme.sans(UiTheme.Weight.SEMIBOLD))
	_reward_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	_reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_row.add_child(_reward_label)
	_reward_payoff = UiTheme.text("", "PointsText")
	_reward_payoff.name = "RewardPayoff"
	_reward_payoff.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_row.add_child(_reward_payoff)
	for node: Control in [_reward_badge, _reward_label, _reward_payoff]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward.add_child(_reward_row)
	return _reward


## DIVERGENCE(IAP R1): the Support the dev banner: heart, two lines, Play's price. The row
## ignores the mouse, so the button takes the tap (as the 3× offer).
func _build_support() -> Button:
	_support = Button.new()
	_support.name = "SupportBanner"
	_support.theme_type_variation = "SupportButton"
	_support.tooltip_text = "%s · %s" % [SUPPORT_TITLE, SUPPORT_SUB]
	_support.visible = false
	_support.pressed.connect(_on_support_pressed)
	_support_row = HBoxContainer.new()
	_support_row.name = "SupportContent"
	_support_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_support_heart = TextureRect.new()
	_support_heart.name = "SupportHeart"
	_support_heart.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_support_row.add_child(_support_heart)
	_support_text = VBoxContainer.new()
	_support_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_support_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_support_title = UiTheme.text(SUPPORT_TITLE, "")
	_support_title.name = "SupportTitle"
	_support_title.add_theme_font_override("font", UiTheme.sans(UiTheme.Weight.SEMIBOLD))
	_support_title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	_support_text.add_child(_support_title)
	_support_sub = UiTheme.caps(SUPPORT_SUB)
	_support_sub.name = "SupportSub"
	_support_text.add_child(_support_sub)
	_support_row.add_child(_support_text)
	_support_price = UiTheme.text("", "ChipText")
	_support_price.name = "SupportPrice"
	_support_price.add_theme_color_override("font_color", UiTheme.COLOR_VOID)
	_support_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_support_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_support_row.add_child(_support_price)
	for node: Control in [
		_support_row, _support_heart, _support_text, _support_title, _support_sub, _support_price
	]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_support.add_child(_support_row)
	return _support


func _scale_support(scale: float) -> void:
	_left_foot.add_theme_constant_override("separation", UiTheme.px(LEFT_GAP, scale))
	_support.custom_minimum_size.y = UiTheme.TOUCH_TARGET * scale
	var pad: int = UiTheme.px(UiTheme.BUTTON_PAD_X, scale)
	_support_row.offset_left = pad
	_support_row.offset_right = -pad
	_support_row.add_theme_constant_override("separation", UiTheme.px(SUPPORT_GAP, scale))
	_support_text.add_theme_constant_override("separation", UiTheme.px(SUPPORT_TEXT_GAP, scale))
	_support_title.add_theme_font_size_override("font_size", UiTheme.px(UiTheme.LABEL_SIZE, scale))
	_support_price.add_theme_stylebox_override(
		"normal",
		UiTheme.padded(
			UiTheme.flat(
				UiTheme.COLOR_PLASMA, UiTheme.COLOR_PLASMA, UiTheme.px(UiTheme.COST_RADIUS, scale)
			),
			UiTheme.px(BADGE_PAD_X, scale),
			UiTheme.px(BADGE_PAD_Y, scale)
		)
	)
	_paint_support(scale)


## DIVERGENCE(IAP R1): GameRoot's word on the banner; `price` is Play's ("₱25.00").
func set_support_offer(state: SupportState, price: String) -> void:
	_support_state = state
	_support_price.text = price
	_paint_support(_ui_scale)


## What the banner shows now (tests).
func support_state() -> SupportState:
	return _support_state


func _paint_support(scale: float) -> void:
	var is_thanks: bool = _support_state == SupportState.THANKS
	_support.visible = _support_state != SupportState.HIDDEN
	_support_title.text = SUPPORT_THANKS_TITLE if is_thanks else SUPPORT_TITLE
	match _support_state:
		SupportState.WAITING:
			_support_sub.text = SUPPORT_WAITING_SUB
		SupportState.PENDING:
			_support_sub.text = SUPPORT_PENDING_SUB
		SupportState.THANKS:
			_support_sub.text = SUPPORT_THANKS_SUB
		_:
			_support_sub.text = SUPPORT_SUB
	_support_price.visible = (
		_support_state == SupportState.OFFERED or _support_state == SupportState.WAITING
	)
	_support_heart.texture = UiTheme.svg_texture(
		UiTheme.ICON_CHECK if is_thanks else UiTheme.ICON_HEART, scale
	)
	var is_dim: bool = (
		_support_state == SupportState.WAITING or _support_state == SupportState.PENDING
	)
	_support_row.modulate.a = REWARD_WAITING_ALPHA if is_dim else 1.0


## Only an open offer buys; the other states ignore the tap.
func _on_support_pressed() -> void:
	if _support_state == SupportState.OFFERED:
		support_requested.emit()


func _scale_reward(scale: float) -> void:
	var pad: int = UiTheme.px(UiTheme.BUTTON_PAD_X, scale)
	_reward_row.offset_left = pad
	_reward_row.offset_right = -pad
	_reward_row.add_theme_constant_override("separation", UiTheme.px(REWARD_GAP, scale))
	_reward_badge.add_theme_stylebox_override(
		"normal",
		UiTheme.padded(
			UiTheme.flat(
				UiTheme.COLOR_FLARE, UiTheme.COLOR_FLARE, UiTheme.px(UiTheme.COST_RADIUS, scale)
			),
			UiTheme.px(BADGE_PAD_X, scale),
			UiTheme.px(BADGE_PAD_Y, scale)
		)
	)
	_reward_label.add_theme_font_size_override("font_size", UiTheme.px(UiTheme.LABEL_SIZE, scale))
	_size_shine()


## "+3,822": what the run's points become if the player earns the reward.
func _refresh_reward_payoff() -> void:
	_reward_payoff.text = earned_text(_earned_target * GameRoot.AD_REWARD_MULTIPLIER)
	_reward_payoff.visible = _earned_target > 0


func _size_shine() -> void:
	var height: float = _reward.size.y
	_reward_shine.size = Vector2(height * (SHINE_WIDTH + RewardShine.LEAN), height)
	if _shine_tween == null:
		_place_shine(0.0)


func _start_shine() -> void:
	if _shine_tween != null:
		return
	_shine_tween = create_tween().set_loops()
	(
		_shine_tween
		. tween_method(_place_shine, 0.0, 1.0, SHINE_SECONDS)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	_shine_tween.tween_interval(SHINE_REST_SECONDS)


func _stop_shine() -> void:
	if _shine_tween != null:
		_shine_tween.kill()
		_shine_tween = null
	_place_shine(0.0)


## Puts the band `t` of the way across: 0 just off the left edge, 1 just off the right.
func _place_shine(t: float) -> void:
	_reward_shine.position = Vector2(lerpf(-_reward_shine.size.x, _reward.size.x, t), 0.0)


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
	_achievements_header.visible = not goals.is_empty()
	_achievements_row.visible = _achievements_header.visible
	# The stats sit centred until a list needs the space below them (ACH R3).
	_left.alignment = (
		BoxContainer.ALIGNMENT_BEGIN if not goals.is_empty() else BoxContainer.ALIGNMENT_CENTER
	)
	_achievements_header.text = achievements_header_text(goals.size()).to_upper()


## "Achievements · 3" (ACH R3).
static func achievements_header_text(count: int) -> String:
	return "Achievements · %d" % count


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
	# DIVERGENCE(ACH R3): the title alone (the description trimmed to "…" on the phone and
	# cost the list rows; the Achievements screen carries it).
	var text: Label = UiTheme.text(goal.title, "BodyText")
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


## The list opens the Achievements screen on a tap, not on a drag that scrolls it (ACH R3).
func _on_list_gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed:
		_press_at = click.position
	elif click.position.distance_to(_press_at) < UiTheme.TOUCH_TARGET * 0.25 * _ui_scale:
		milestones_requested.emit()


## bindGameOverClicks' handler. PORT: web/src/tilt-to-live/GoalsHUD.ts:131-134
func _on_rows_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		milestones_requested.emit()


## DIVERGENCE(ADS R10): the light band that sweeps the offer: drawn once, moved by a tween.
## Two leaning quads, clear → lit → clear, so its edges are soft.
class RewardShine:
	extends Control

	## How far the band leans over its height, as a share of that height.
	const LEAN: float = 0.5

	func _draw() -> void:
		var h: float = size.y
		var lean: float = h * LEAN
		var mid: float = (size.x - lean) * 0.5
		var lit: Color = UiTheme.tint(RunOverSheet.SHINE_COLOR, RunOverSheet.SHINE_ALPHA)
		var clear: Color = UiTheme.tint(RunOverSheet.SHINE_COLOR, 0.0)
		draw_polygon(
			PackedVector2Array(
				[Vector2(lean, 0.0), Vector2(lean + mid, 0.0), Vector2(mid, h), Vector2(0.0, h)]
			),
			PackedColorArray([clear, lit, lit, clear])
		)
		draw_polygon(
			PackedVector2Array(
				[
					Vector2(lean + mid, 0.0),
					Vector2(size.x, 0.0),
					Vector2(size.x - lean, h),
					Vector2(mid, h)
				]
			),
			PackedColorArray([lit, clear, clear, lit])
		)


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
