## ui_theme.gd
## PORTS: nothing — new file per docs/superpowers/specs/2026-09-23-mobile-interface-system-design.md
##        §4.1 (replaced armory_theme.gd)
class_name UiTheme
extends RefCounted
## Colour tokens, fonts, icons and component variations of the mobile
## interface system, built into a Theme at a given ui_scale.
##
## DIVERGENCE(UI-SYSTEM): System.dc.html is the visual authority (interface
## spec §2). Every size is a base px on the 844×390 board frame; build(scale)
## multiplies it. Tokens live in code rather than a .tres so every literal
## carries its citation (as the pre-M8.5 Armory theme did).
##
## Never instantiated: every member is static (port design spec §5.2 — not a singleton).

enum Weight { REGULAR, MEDIUM, SEMIBOLD }

## Colour tokens. DIVERGENCE(UI-SYSTEM): System.dc.html — colour tokens
const COLOR_VOID: Color = Color("#08090E")
const COLOR_ARENA: Color = Color("#0D1016")
const COLOR_SHELL: Color = Color("#0B0E14")
const COLOR_SHEET: Color = Color("#12161F")
const COLOR_PANEL: Color = Color("#141821")
const COLOR_RAISED: Color = Color("#1B2029")
const COLOR_LINE: Color = Color("#262C38")
const COLOR_LINE_STRONG: Color = Color("#3A4252")
const COLOR_TEXT: Color = Color("#E6E9F0")
const COLOR_TEXT_MUTED: Color = Color("#99A1B3")
const COLOR_ION: Color = Color("#5B8CFF")
const COLOR_FLARE: Color = Color("#FFB14D")
const COLOR_PLASMA: Color = Color("#A78BFA")
const COLOR_LOCKED_IN: Color = Color("#3DDC97")
## Secondary literals the boards repeat, each cited to the first board using it.
const TEXT_FAINT: Color = Color("#7A8397")  # DIVERGENCE(UI-SYSTEM): System.dc.html
const TEXT_SECONDARY: Color = Color("#C7CDDB")  # DIVERGENCE(UI-SYSTEM): System.dc.html
const POINTS_UNIT: Color = Color("#A08A5C")  # DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — PTS
const ION_TEXT: Color = Color("#8FB0FF")  # DIVERGENCE(UI-SYSTEM): System.dc.html — CostButton
const PLASMA_TEXT: Color = Color("#C4B0FD")  # DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html
const LOCKED_CARD: Color = Color("#10141B")  # DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html
const STAT_CELL: Color = Color("#161B25")  # DIVERGENCE(UI-SYSTEM): RunOver.dc.html
const DONE_CARD: Color = Color("#0F131B")  # DIVERGENCE(UI-SYSTEM): System.dc.html
## DIVERGENCE(M11c review): outline thickness (px at 1x) that keeps text readable over
## the moving dots behind it; the boards draw that text on a still, empty arena.
const OVER_PLAY_OUTLINE: int = 6
## rgba() alphas. DIVERGENCE(UI-SYSTEM): System.dc.html — CostButton/Chip fill
## 12%, Chip border 45%, IconButton rgba(20,24,33,0.85); ArmoryShips.dc.html —
## Equipped fill 10%; Pause.dc.html — sheet shadow 0.6
const FILL_ALPHA: float = 0.12
const CHIP_BORDER_ALPHA: float = 0.45
const ICON_BUTTON_ALPHA: float = 0.85
const EQUIPPED_FILL_ALPHA: float = 0.10
const SHEET_SHADOW_ALPHA: float = 0.6

## Type scale, base px. DIVERGENCE(UI-SYSTEM): System.dc.html — Type · base px
## (titles 21–28, HUD score 30 / run-over 54, labels 14–15, descriptions 12–13,
## caps 10–11; nothing below 10); per-board picks cited inline.
const TITLE_SIZE: int = 21  # ArmoryWeapons.dc.html h2/h3
const SHEET_TITLE_SIZE: int = 26  # Pause.dc.html h2
const SCORE_SIZE: int = 30
const BIG_SCORE_SIZE: int = 54
const STAT_SIZE: int = 18  # RunOver.dc.html stat value
const FIELD_SIZE: int = 15  # ArmoryHandling.dc.html field label
const LABEL_SIZE: int = 14
const BODY_SIZE: int = 13
const HINT_SIZE: int = 12
const MONO_SIZE: int = 11
const CAPS_SIZE: int = 10
const POINTS_SIZE: int = 15  # ArmoryWeapons.dc.html points readout
const CHIP_SIZE: int = 14  # System.dc.html Chip
const COST_SIZE: int = 13  # System.dc.html CostButton
const PRIMARY_SIZE: int = 15  # System.dc.html PrimaryButton
## Caps tracking, em. DIVERGENCE(UI-SYSTEM): System.dc.html — +0.14em
const CAPS_TRACKING: float = 0.14
## Archivo axes. DIVERGENCE(UI-SYSTEM): System.dc.html — 700 w112 titles, w118 wordmark
const TITLE_WIDTH: float = 112.0
const WORDMARK_WIDTH: float = 118.0
const TITLE_WEIGHT: float = 700.0

## Component geometry, base px. DIVERGENCE(UI-SYSTEM): System.dc.html — Components, rule 05
const TOUCH_TARGET: int = 48
const HERO_TARGET: int = 56
const BUTTON_RADIUS: int = 6
const COST_RADIUS: int = 4
const CHIP_RADIUS: int = 3
const CARD_RADIUS: int = 6
const SHEET_RADIUS: int = 10
const SEGMENT_PAD: int = 3
const SEGMENT_RADIUS: int = 4
const METER_HEIGHT: int = 3
const METER_RADIUS: int = 2
const PIP_HEIGHT: int = 5
const PIP_GAP: int = 4
const BUTTON_PAD_X: int = 14  # Segmented button padding 0 14px
const TAB_PAD_X: int = 12  # ArmoryWeapons.dc.html — tab and list-row padding 0 12px
const CHIP_PAD_Y: int = 4
const CHIP_PAD_X: int = 8
const SHEET_PAD: int = 24  # DIVERGENCE(UI-SYSTEM): Pause.dc.html — padding 24
## Sheet drop shadow. DIVERGENCE(UI-SYSTEM): Pause.dc.html — 0 24px 64px. Godot's
## shadow_size is a blur radius; half the CSS blur is used.
const SHEET_SHADOW_OFFSET: int = 24
const SHEET_SHADOW_SIZE: int = 32

## Typefaces. DIVERGENCE(UI-SYSTEM): System.dc.html — Archivo, IBM Plex Sans,
## IBM Plex Mono (interface spec §4.2; OFL licences beside the files).
const ARCHIVO: FontFile = preload("res://assets/fonts/Archivo-Variable.ttf")
const PLEX_SANS_REGULAR: FontFile = preload("res://assets/fonts/IBMPlexSans-Regular.ttf")
const PLEX_SANS_MEDIUM: FontFile = preload("res://assets/fonts/IBMPlexSans-Medium.ttf")
const PLEX_SANS_SEMIBOLD: FontFile = preload("res://assets/fonts/IBMPlexSans-SemiBold.ttf")
const PLEX_MONO_REGULAR: FontFile = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
const PLEX_MONO_MEDIUM: FontFile = preload("res://assets/fonts/IBMPlexMono-Medium.ttf")
const PLEX_MONO_SEMIBOLD: FontFile = preload("res://assets/fonts/IBMPlexMono-SemiBold.ttf")

## Board icons, verbatim but for the xmlns the rasteriser needs (the
## armory_ui.gd catalog PORT-NOTE). Sizes are base px.
## DIVERGENCE(UI-SYSTEM): Hud.dc.html — pause
const ICON_PAUSE: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">'
	+ '<rect x="4" y="3" width="3" height="10" rx="1" fill="#C7CDDB"/>'
	+ '<rect x="9" y="3" width="3" height="10" rx="1" fill="#C7CDDB"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — back
const ICON_BACK: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">'
	+ '<path d="M10 3 L5 8 L10 13" stroke="#C7CDDB" stroke-width="1.5" '
	+ 'stroke-linecap="round" stroke-linejoin="round"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): Pause.dc.html — calibrate tilt
const ICON_CALIBRATE: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 16 16" fill="none">'
	+ '<circle cx="8" cy="8" r="6" stroke="#C7CDDB" stroke-width="1.3"/>'
	+ '<circle cx="9.5" cy="6.8" r="1.8" fill="#C7CDDB"/>'
	+ '<path d="M8 1 V3 M8 13 V15 M1 8 H3 M13 8 H15" stroke="#C7CDDB" stroke-width="1.3" '
	+ 'stroke-linecap="round"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): Hud.dc.html — toast check
const ICON_CHECK: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 14 14" fill="none">'
	+ '<path d="M2 7.5 L5.5 11 L12 3.5" stroke="#3DDC97" stroke-width="1.8" '
	+ 'stroke-linecap="round" stroke-linejoin="round"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): Milestones.dc.html — done mark check (void stroke)
const ICON_MARK: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="11" height="11" viewBox="0 0 11 11" fill="none">'
	+ '<path d="M1.5 5.8 L4.2 8.5 L9.5 2.8" stroke="#08090E" stroke-width="1.9" '
	+ 'stroke-linecap="round" stroke-linejoin="round"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): Hud.dc.html — message toast ring.
## PORT: web/src/tilt-to-live/GoalsHUD.ts:217-220
const ICON_RING: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 14 14" fill="none">'
	+ '<circle cx="7" cy="7" r="5" stroke="#5B8CFF" stroke-width="1.5"/>'
	+ '<circle cx="7" cy="7" r="2" fill="#5B8CFF"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): RunOver.dc.html — new-best star
const ICON_STAR: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 13 13" fill="none">'
	+ '<path d="M6.5 1 L8.2 4.7 L12 5.2 L9.2 8 L9.9 12 L6.5 10.1 L3.1 12 L3.8 8 L1 5.2 '
	+ 'L4.8 4.7 Z" stroke="#FFB14D" stroke-width="1.1" stroke-linejoin="round"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — locked keystone
const ICON_LOCK: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">'
	+ '<rect x="2" y="5.5" width="8" height="5.5" rx="1" stroke="#7A8397" stroke-width="1.2"/>'
	+ '<path d="M4 5.5 V3.8 A2 2 0 0 1 8 3.8 V5.5" stroke="#7A8397" stroke-width="1.2"/></svg>'
)
## Switch track + knob, 48×28. DIVERGENCE(UI-SYSTEM): Pause.dc.html — p-sfx (on), p-mus (off)
const SWITCH_ON: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="48" height="28" viewBox="0 0 48 28" fill="none">'
	+ '<rect x="0.5" y="0.5" width="47" height="27" rx="13.5" fill="#5B8CFF" '
	+ 'fill-opacity="0.2" stroke="#5B8CFF"/><circle cx="34" cy="14" r="10" fill="#5B8CFF"/></svg>'
)
const SWITCH_OFF: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="48" height="28" viewBox="0 0 48 28" fill="none">'
	+ '<rect x="0.5" y="0.5" width="47" height="27" rx="13.5" fill="#1B2029" stroke="#3A4252"/>'
	+ '<circle cx="14" cy="14" r="10" fill="#626B7E"/></svg>'
)


## A base size at `scale`, rounded to whole pixels.
static func px(base: float, scale: float) -> int:
	return roundi(base * scale)


## `color` at `alpha` (the boards' rgba()).
static func tint(color: Color, alpha: float) -> Color:
	var out: Color = color
	out.a = alpha
	return out


## A flat style box: one colour, an optional 1 px border, a radius.
static func flat(bg: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width if border.a > 0.0 else 0)
	box.set_corner_radius_all(radius)
	return box


## Sets `box`'s content margins and returns it.
static func padded(box: StyleBoxFlat, pad_x: float, pad_y: float) -> StyleBoxFlat:
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


## The Chip: tint text on a 12% tint fill with a 45% tint border.
static func chip_style(tint_color: Color, scale: float) -> StyleBoxFlat:
	return padded(
		flat(
			tint(tint_color, FILL_ALPHA),
			tint(tint_color, CHIP_BORDER_ALPHA),
			px(CHIP_RADIUS, scale)
		),
		px(CHIP_PAD_X, scale),
		px(CHIP_PAD_Y, scale)
	)


## Builds the void scrim and a centred Sheet panel, parented under `parent`.
## Shared by every modal sheet (Pause, Run over); returns the Sheet for the
## caller to fill. Node names `Scrim`/`Sheet` are the interface spec's.
static func build_sheet(parent: Control, scrim_alpha: float) -> PanelContainer:
	var scrim: ColorRect = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = tint(COLOR_VOID, scrim_alpha)
	parent.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sheet: PanelContainer = PanelContainer.new()
	sheet.name = "Sheet"
	sheet.theme_type_variation = "Sheet"
	center.add_child(sheet)
	return sheet


## A fill-width column of a sheet's two-column layout, named for `find_child`.
static func sheet_column(column_name: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = column_name
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return column


## A 1 px hairline rule (vertical between columns, horizontal between rows),
## ignoring the mouse. Never scaled (Global Constraints).
static func hairline(is_vertical: bool, color: Color) -> ColorRect:
	var rule: ColorRect = ColorRect.new()
	rule.color = color
	if is_vertical:
		rule.custom_minimum_size.x = 1.0
	else:
		rule.custom_minimum_size.y = 1.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


## Rasterises an SVG string (Image.load_svg_from_string, 4.7.2) at `scale`.
static func svg_texture(svg: String, scale: float) -> ImageTexture:
	var image: Image = Image.new()
	var err: int = image.load_svg_from_string(svg, scale)
	if err != OK:
		Log.warn("UiTheme: svg rasterisation failed (%d)" % err)
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)


## The arrow ship glyph at `size` base px in `color`.
## DIVERGENCE(UI-SYSTEM): Hud.dc.html — lives icons (path M34 20 L11 8 L16 20 L11 32 Z, viewBox 40)
static func ship_glyph_svg(color: Color, size: int) -> String:
	return (
		(
			'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 40 40" '
			+ 'fill="none"><path d="M34 20 L11 8 L16 20 L11 32 Z" fill="#%s"/></svg>'
		)
		% [size, size, color.to_html(false)]
	)


## DIVERGENCE(M11c review, emulator play 2026-09-27): dots showed through the HUD
## score, BEST and weapon timer, and through the menu's hero text over the attract
## backdrop. A void-coloured outline separates the glyphs from whatever is behind.
static func legible_over_play(label: Label, outline_px: int = OVER_PLAY_OUTLINE) -> void:
	label.add_theme_constant_override("outline_size", outline_px)
	label.add_theme_color_override("font_outline_color", COLOR_VOID)


## `n` with en-US thousands commas (the boards' numerals; ArmoryUI.format_points' grouping).
static func group_digits(n: int) -> String:
	var digits: String = str(absi(n))
	var grouped: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	return ("-" if n < 0 else "") + grouped


## A Label in a theme variation.
static func text(content: String, variation: String) -> Label:
	var label: Label = Label.new()
	label.text = content
	label.theme_type_variation = variation
	return label


## A caps label (Mono 600 10, faint, uppercase on screen; `.text` unchanged).
static func caps(content: String) -> Label:
	var label: Label = text(content, "CapsText")
	label.uppercase = true
	return label


## Discrete pips: `total` bars, the first `filled` in ion, the rest in line.
## DIVERGENCE(UI-SYSTEM): System.dc.html — Pips (5 px, gap 4, ion / line)
static func pips(filled: int, total: int, scale: float) -> HBoxContainer:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", px(PIP_GAP, scale))
	for i: int in range(total):
		var pip: ColorRect = ColorRect.new()
		pip.color = COLOR_ION if i < filled else COLOR_LINE
		pip.custom_minimum_size.y = px(PIP_HEIGHT, scale)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(pip)
	return bar


## A Meter (label-less ProgressBar) filled to `fraction` in `fill`.
static func meter(fraction: float, fill: Color, width: float, height: float) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.theme_type_variation = "Meter"
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = clampf(fraction, 0.0, 1.0)
	bar.custom_minimum_size = Vector2(width, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", flat(fill, Color.TRANSPARENT, METER_RADIUS))
	return bar


## Plex Sans at a weight.
static func sans(weight: Weight) -> FontFile:
	match weight:
		Weight.MEDIUM:
			return PLEX_SANS_MEDIUM
		Weight.SEMIBOLD:
			return PLEX_SANS_SEMIBOLD
		_:
			return PLEX_SANS_REGULAR


## Plex Mono at a weight with tabular figures and `tracking_px` glyph spacing.
static func mono(weight: Weight, tracking_px: int = 0) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	match weight:
		Weight.MEDIUM:
			font.base_font = PLEX_MONO_MEDIUM
		Weight.SEMIBOLD:
			font.base_font = PLEX_MONO_SEMIBOLD
		_:
			font.base_font = PLEX_MONO_REGULAR
	font.opentype_features = {_tag("tnum"): 1}
	font.spacing_glyph = tracking_px
	return font


## Archivo 700 at a width axis value (112 titles, 118 wordmark).
static func archivo(width: float) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = ARCHIVO
	font.variation_opentype = {_tag("wdth"): width, _tag("wght"): TITLE_WEIGHT}
	return font


## The interface-system Theme at `scale` (HudController.ui_scale_for's value).
static func build(scale: float) -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = sans(Weight.REGULAR)
	theme.default_font_size = px(BODY_SIZE, scale)
	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_font_size("font_size", "Label", px(BODY_SIZE, scale))
	_build_text(theme, scale)
	_build_buttons(theme, scale)
	_build_panels(theme, scale)
	return theme


static func _build_text(theme: Theme, scale: float) -> void:
	var title: FontVariation = archivo(TITLE_WIDTH)
	var mono_regular: FontVariation = mono(Weight.REGULAR)
	var mono_medium: FontVariation = mono(Weight.MEDIUM)
	var caps_font: FontVariation = mono(Weight.SEMIBOLD, roundi(CAPS_TRACKING * CAPS_SIZE * scale))
	_text(theme, "TitleText", title, px(TITLE_SIZE, scale), COLOR_TEXT)
	_text(theme, "SheetTitleText", title, px(SHEET_TITLE_SIZE, scale), COLOR_TEXT)
	_text(theme, "FieldText", sans(Weight.SEMIBOLD), px(FIELD_SIZE, scale), COLOR_TEXT)
	_text(theme, "StrongText", sans(Weight.SEMIBOLD), px(LABEL_SIZE, scale), COLOR_TEXT)
	_text(theme, "LabelText", sans(Weight.REGULAR), px(LABEL_SIZE, scale), TEXT_SECONDARY)
	_text(theme, "BodyText", sans(Weight.REGULAR), px(BODY_SIZE, scale), COLOR_TEXT_MUTED)
	_text(theme, "HintText", sans(Weight.REGULAR), px(HINT_SIZE, scale), COLOR_TEXT_MUTED)
	_text(theme, "CapsText", caps_font, px(CAPS_SIZE, scale), TEXT_FAINT)
	_text(theme, "MonoText", mono_regular, px(MONO_SIZE, scale), COLOR_TEXT_MUTED)
	_text(theme, "MonoFaintText", mono_regular, px(MONO_SIZE, scale), TEXT_FAINT)
	_text(theme, "PointsText", mono_medium, px(POINTS_SIZE, scale), COLOR_FLARE)
	_text(theme, "ScoreText", mono_medium, px(SCORE_SIZE, scale), COLOR_TEXT)
	_text(theme, "BigScoreText", mono_medium, px(BIG_SCORE_SIZE, scale), COLOR_TEXT)
	_text(theme, "StatText", mono_medium, px(STAT_SIZE, scale), COLOR_TEXT)
	_text(theme, "ChipText", mono(Weight.SEMIBOLD), px(CHIP_SIZE, scale), COLOR_TEXT)


static func _build_buttons(theme: Theme, scale: float) -> void:
	var r: int = px(BUTTON_RADIUS, scale)
	var cr: int = px(COST_RADIUS, scale)
	var sr: int = px(SEGMENT_RADIUS, scale)
	var pad: float = px(BUTTON_PAD_X, scale)
	var none: Color = Color.TRANSPARENT
	var label_size: int = px(LABEL_SIZE, scale)
	var cost_font: FontVariation = mono(Weight.MEDIUM)
	var cost_off: StyleBoxFlat = padded(flat(none, COLOR_LINE, cr), pad, 0.0)
	# DIVERGENCE(UI-SYSTEM): System.dc.html — PrimaryButton (ion fill, void text, r 6)
	_button(
		theme,
		"PrimaryButton",
		sans(Weight.SEMIBOLD),
		px(PRIMARY_SIZE, scale),
		COLOR_VOID,
		padded(flat(COLOR_ION, none, r), pad, 0.0),
		padded(flat(ION_TEXT, none, r), pad, 0.0),
		padded(flat(COLOR_RAISED, none, r), pad, 0.0)
	)
	# DIVERGENCE(UI-SYSTEM): System.dc.html — SecondaryButton (line_strong 1px, r 6)
	_button(
		theme,
		"SecondaryButton",
		sans(Weight.MEDIUM),
		label_size,
		TEXT_SECONDARY,
		padded(flat(none, COLOR_LINE_STRONG, r), pad, 0.0),
		padded(flat(COLOR_RAISED, COLOR_LINE_STRONG, r), pad, 0.0),
		padded(flat(none, COLOR_LINE, r), pad, 0.0)
	)
	# DIVERGENCE(UI-SYSTEM): System.dc.html — IconButton (panel 85%, line 1px, r 6);
	# ArmoryWeapons.dc.html Back = transparent + line; Pause.dc.html Calibrate =
	# transparent + line_strong.
	_button(
		theme,
		"IconButton",
		sans(Weight.MEDIUM),
		label_size,
		TEXT_SECONDARY,
		flat(tint(COLOR_PANEL, ICON_BUTTON_ALPHA), COLOR_LINE, r),
		flat(COLOR_RAISED, COLOR_LINE_STRONG, r),
		flat(none, COLOR_LINE, r)
	)
	_button(
		theme,
		"FlatIconButton",
		sans(Weight.MEDIUM),
		label_size,
		TEXT_SECONDARY,
		flat(none, COLOR_LINE, r),
		flat(COLOR_RAISED, COLOR_LINE_STRONG, r),
		flat(none, COLOR_LINE, r)
	)
	_button(
		theme,
		"GhostIconButton",
		sans(Weight.MEDIUM),
		label_size,
		TEXT_SECONDARY,
		flat(none, COLOR_LINE_STRONG, r),
		flat(COLOR_RAISED, COLOR_LINE_STRONG, r),
		flat(none, COLOR_LINE, r)
	)
	# DIVERGENCE(UI-SYSTEM): System.dc.html — CostButton (mono, ion 12% fill + ion border, r 4);
	# ArmoryWeapons.dc.html — disabled/locked (transparent, line border, faint)
	_button(
		theme,
		"CostButton",
		cost_font,
		px(COST_SIZE, scale),
		ION_TEXT,
		padded(flat(tint(COLOR_ION, FILL_ALPHA), COLOR_ION, cr), pad, 0.0),
		padded(flat(tint(COLOR_ION, FILL_ALPHA), ION_TEXT, cr), pad, 0.0),
		cost_off
	)
	# DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — keystone cost (plasma 12%, plasma border)
	_button(
		theme,
		"PlasmaCostButton",
		cost_font,
		px(COST_SIZE, scale),
		PLASMA_TEXT,
		padded(flat(tint(COLOR_PLASMA, FILL_ALPHA), COLOR_PLASMA, cr), pad, 0.0),
		padded(flat(tint(COLOR_PLASMA, FILL_ALPHA), PLASMA_TEXT, cr), pad, 0.0),
		cost_off
	)
	# DIVERGENCE(UI-SYSTEM): ArmoryShips.dc.html — Equipped (locked_in border + 10% fill);
	# a disabled button that keeps its green.
	var equipped: StyleBoxFlat = padded(
		flat(tint(COLOR_LOCKED_IN, EQUIPPED_FILL_ALPHA), COLOR_LOCKED_IN, cr), pad, 0.0
	)
	_button(
		theme,
		"EquippedButton",
		sans(Weight.MEDIUM),
		px(BODY_SIZE, scale),
		COLOR_LOCKED_IN,
		equipped,
		equipped,
		equipped
	)
	theme.set_color("font_disabled_color", "EquippedButton", COLOR_LOCKED_IN)
	# DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — tabs (faint; selected raised, text)
	_button(
		theme,
		"TabButton",
		sans(Weight.MEDIUM),
		label_size,
		TEXT_FAINT,
		padded(flat(none, none, r), px(TAB_PAD_X, scale), 0.0),
		padded(flat(COLOR_RAISED, none, r), px(TAB_PAD_X, scale), 0.0),
		padded(flat(none, none, r), px(TAB_PAD_X, scale), 0.0)
	)
	# DIVERGENCE(UI-SYSTEM): System.dc.html — Segmented (selected raised + line_strong, r 4)
	_button(
		theme,
		"SegmentButton",
		sans(Weight.MEDIUM),
		label_size,
		TEXT_FAINT,
		padded(flat(none, none, sr), pad, 0.0),
		padded(flat(COLOR_RAISED, COLOR_LINE_STRONG, sr), pad, 0.0),
		padded(flat(none, none, sr), pad, 0.0)
	)
	# DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — weapon list row (selected raised + line_strong)
	_button(
		theme,
		"ListItemButton",
		sans(Weight.MEDIUM),
		label_size,
		TEXT_SECONDARY,
		padded(flat(none, none, r), px(TAB_PAD_X, scale), 0.0),
		padded(flat(COLOR_RAISED, COLOR_LINE_STRONG, r), px(TAB_PAD_X, scale), 0.0),
		padded(flat(none, none, r), px(TAB_PAD_X, scale), 0.0)
	)
	# DIVERGENCE(UI-SYSTEM): ArmoryArena.dc.html — the cards are buttons; the port
	# lays a transparent CardButton over a Card (armory_ui.gd _arena_card_button).
	theme.set_type_variation("CardButton", "Button")
	for box: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		theme.set_stylebox(box, "CardButton", StyleBoxEmpty.new())
	# DIVERGENCE(UI-SYSTEM): System.dc.html — Switch (CheckButton 48×28, the whole row the target)
	theme.set_type_variation("Switch", "CheckButton")
	theme.set_font("font", "Switch", sans(Weight.REGULAR))
	theme.set_font_size("font_size", "Switch", label_size)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		theme.set_color(state, "Switch", TEXT_SECONDARY)
	theme.set_color("font_hover_pressed_color", "Switch", TEXT_SECONDARY)
	for box: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(box, "Switch", StyleBoxEmpty.new())
	theme.set_icon("checked", "Switch", svg_texture(SWITCH_ON, scale))
	theme.set_icon("unchecked", "Switch", svg_texture(SWITCH_OFF, scale))


static func _build_panels(theme: Theme, scale: float) -> void:
	var r: int = px(CARD_RADIUS, scale)
	# DIVERGENCE(UI-SYSTEM): System.dc.html — Card (panel, line 1px, r 6)
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", flat(COLOR_PANEL, COLOR_LINE, r))
	# DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — locked keystone card (#10141B, raised border)
	theme.set_type_variation("LockedCard", "PanelContainer")
	theme.set_stylebox("panel", "LockedCard", flat(LOCKED_CARD, COLOR_RAISED, r))
	# DIVERGENCE(UI-SYSTEM): System.dc.html — Sheet (sheet, line 1px, r 10, drop shadow)
	var sheet: StyleBoxFlat = padded(
		flat(COLOR_SHEET, COLOR_LINE, px(SHEET_RADIUS, scale)),
		px(SHEET_PAD, scale),
		px(SHEET_PAD, scale)
	)
	sheet.shadow_color = tint(Color.BLACK, SHEET_SHADOW_ALPHA)
	sheet.shadow_size = px(SHEET_SHADOW_SIZE, scale)
	sheet.shadow_offset = Vector2(0.0, px(SHEET_SHADOW_OFFSET, scale))
	theme.set_type_variation("Sheet", "PanelContainer")
	theme.set_stylebox("panel", "Sheet", sheet)
	# DIVERGENCE(UI-SYSTEM): System.dc.html — Segmented (arena bg, line border, pad 3, r 6)
	theme.set_type_variation("Segmented", "PanelContainer")
	theme.set_stylebox(
		"panel",
		"Segmented",
		padded(flat(COLOR_ARENA, COLOR_LINE, r), px(SEGMENT_PAD, scale), px(SEGMENT_PAD, scale))
	)
	# DIVERGENCE(UI-SYSTEM): System.dc.html — Meter (3 px, raised track, no label)
	theme.set_type_variation("Meter", "ProgressBar")
	theme.set_stylebox(
		"background", "Meter", flat(COLOR_RAISED, Color.TRANSPARENT, px(METER_RADIUS, scale))
	)
	theme.set_stylebox("fill", "Meter", flat(COLOR_ION, Color.TRANSPARENT, px(METER_RADIUS, scale)))


static func _text(theme: Theme, name: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


static func _button(
	theme: Theme,
	name: String,
	font: Font,
	size: int,
	fg: Color,
	normal: StyleBox,
	pressed: StyleBox,
	disabled: StyleBox
) -> void:
	theme.set_type_variation(name, "Button")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, fg)
	theme.set_color("font_focus_color", name, fg)
	theme.set_color("font_hover_color", name, fg)
	var active: Color = COLOR_VOID if name == "PrimaryButton" else COLOR_TEXT
	theme.set_color("font_pressed_color", name, active)
	theme.set_color("font_hover_pressed_color", name, active)
	theme.set_color("font_disabled_color", name, TEXT_FAINT)
	theme.set_color("icon_normal_color", name, Color.WHITE)
	theme.set_stylebox("normal", name, normal)
	theme.set_stylebox("hover", name, normal)
	theme.set_stylebox("pressed", name, pressed)
	theme.set_stylebox("hover_pressed", name, pressed)
	theme.set_stylebox("disabled", name, disabled)
	theme.set_stylebox("focus", name, StyleBoxEmpty.new())


static func _tag(name: String) -> int:
	return TextServerManager.get_primary_interface().name_to_tag(name)
