## armory_theme.gd
## PORTS: web/src/styles/game.css:9-67 (design tokens) and the armory chrome
##        blocks cited inline, per spec §8 Module 8 ("a Theme resource carrying
##        the design tokens from game.css")
class_name ArmoryTheme
extends RefCounted
## Builds the Armory's Theme from game.css's tokens at a given ui_scale.
##
## PORT-NOTE: the tokens live in code rather than a .tres so every literal
## carries its `# PORT:` citation (LAW 1) — a .tres cannot. build() returns a
## real Theme resource; ArmoryUI assigns it at runtime and rebuilds it when
## the viewport's ui_scale changes.
##
## PORT-NOTE: game.css:53-55 names Archivo / IBM Plex Sans / IBM Plex Mono.
## No font asset exists in the project; Godot's default font is used at the
## cited sizes. Font assets are M11's decision.
##
## Never instantiated: every member is static (spec §5.2 — not a singleton).

## Surface tokens. PORT: web/src/styles/game.css:11-14
const COLOR_VOID: Color = Color("#08090E")
const COLOR_ARENA: Color = Color("#0D1016")
const COLOR_PANEL: Color = Color("#141821")
const COLOR_RAISED: Color = Color("#1B2029")
## Border tokens. PORT: web/src/styles/game.css:19-21
const COLOR_BORDER: Color = Color("#262C38")
const COLOR_BORDER_ACTIVE: Color = Color("#3A4252")
## Accent tokens. PORT: web/src/styles/game.css:24-38
const COLOR_ION: Color = Color("#5B8CFF")
const COLOR_ION_HOVER: Color = Color("#8FB0FF")
const COLOR_ION_FILL: Color = Color(91.0 / 255.0, 140.0 / 255.0, 1.0, 0.12)
const COLOR_FLARE: Color = Color("#FFB14D")
const COLOR_PLASMA: Color = Color("#A78BFA")
const COLOR_SUCCESS: Color = Color("#3DDC97")
const COLOR_SUCCESS_FILL: Color = Color(61.0 / 255.0, 220.0 / 255.0, 151.0 / 255.0, 0.10)
## Text tokens. PORT: web/src/styles/game.css:45-50
const TEXT_PRIMARY: Color = Color("#E6E9F0")
const TEXT_SECONDARY: Color = Color("#C7CDDB")
const TEXT_MUTED: Color = Color("#99A1B3")
const TEXT_FAINT: Color = Color("#7A8397")
const TEXT_SUBTLE: Color = Color("#626B7E")

## Overlay and panel. PORT: web/src/styles/game.css:1607, :1621-1623
const OVERLAY_BG: Color = Color(8.0 / 255.0, 9.0 / 255.0, 14.0 / 255.0, 0.88)
const PANEL_BG: Color = Color("#0B0E14")
const PANEL_RADIUS: int = 8
## Header padding. PORT: web/src/styles/game.css:1632 (desktop), :2831 (mobile)
const HEADER_PAD_Y: int = 18
const HEADER_PAD_X: int = 32
const HEADER_PAD_Y_MOBILE: int = 12
const HEADER_PAD_X_MOBILE: int = 16
const TITLE_FONT: int = 26  # PORT: web/src/styles/game.css:1663
## Tabs. PORT: web/src/styles/game.css:1688, :1693
const TAB_RADIUS: int = 4
const TAB_FONT: int = 14
## Balance and the two icon buttons. PORT: web/src/styles/game.css:1721, :1738-1741
const BALANCE_FONT: int = 15
const ICON_BUTTON: int = 38
const ICON_BUTTON_RADIUS: int = 4
## Body text. PORT: web/src/styles/game.css:2012 (.track-cost-btn font-size)
const BODY_FONT: int = 13
## Action buttons. PORT: web/src/styles/game.css:2005-2008
const ACTION_BUTTON_WIDTH: int = 130
const ACTION_BUTTON_HEIGHT: int = 40
const ACTION_RADIUS: int = 4
## Cards. PORT: web/src/styles/game.css:1935-1937
const CARD_RADIUS: int = 6
## Sticky Play. PORT: web/src/styles/game.css:2801-2806
const PLAY_BUTTON_HEIGHT: int = 50
const PLAY_RADIUS: int = 6
const PLAY_FONT: int = 16
## Keystone surfaces. PORT: web/src/styles/game.css:2183-2184, :2190-2191, :2229-2230
const KEYSTONE_FILL: Color = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0, 0.07)
const KEYSTONE_BORDER: Color = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0, 0.28)
const KEYSTONE_UNLOCKED_FILL: Color = Color(61.0 / 255.0, 220.0 / 255.0, 151.0 / 255.0, 0.08)
const KEYSTONE_UNLOCKED_BORDER: Color = Color(61.0 / 255.0, 220.0 / 255.0, 151.0 / 255.0, 0.35)
const KEYSTONE_BUTTON_FILL: Color = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0, 0.12)
const KEYSTONE_TEXT: Color = Color("#C4B0FD")
## Secondary text sizes. PORT: web/src/styles/game.css:1948, :1954, :1964, :1795
const HEADING_FONT: int = 15
const MUTED_FONT: int = 12
const FAINT_FONT: int = 11
const WEAPON_ITEM_RADIUS: int = 5


## A flat style box: one colour, an optional 1 px border, a radius.
static func flat(bg: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width if border.a > 0.0 else 0)
	box.set_corner_radius_all(radius)
	return box


## The Armory Theme at `scale` (HudController.ui_scale_for's value).
static func build(scale: float) -> Theme:
	var theme: Theme = Theme.new()

	theme.set_color("font_color", "Label", TEXT_PRIMARY)
	theme.set_font_size("font_size", "Label", int(BODY_FONT * scale))
	theme.set_stylebox("panel", "Panel", flat(PANEL_BG, COLOR_BORDER, PANEL_RADIUS))
	theme.set_stylebox("panel", "PanelContainer", flat(PANEL_BG, COLOR_BORDER, PANEL_RADIUS))

	# Default Button = .track-cost-btn / .boost-cost-btn. PORT: game.css:2004-2036
	theme.set_font_size("font_size", "Button", int(BODY_FONT * scale))
	theme.set_color("font_color", "Button", COLOR_ION_HOVER)
	theme.set_color("font_hover_color", "Button", COLOR_ION_HOVER)
	theme.set_color("font_pressed_color", "Button", COLOR_ION_HOVER)
	theme.set_color("font_disabled_color", "Button", TEXT_SUBTLE)
	theme.set_stylebox("normal", "Button", flat(COLOR_ION_FILL, COLOR_ION, ACTION_RADIUS))
	theme.set_stylebox("hover", "Button", flat(COLOR_ION_FILL, COLOR_ION_HOVER, ACTION_RADIUS))
	theme.set_stylebox("pressed", "Button", flat(COLOR_ION_FILL, COLOR_ION_HOVER, ACTION_RADIUS))
	theme.set_stylebox("disabled", "Button", flat(Color.TRANSPARENT, COLOR_BORDER, ACTION_RADIUS))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	_label_variation(theme, "TitleLabel", TEXT_PRIMARY, int(TITLE_FONT * scale))
	_label_variation(theme, "HeadingLabel", TEXT_PRIMARY, int(HEADING_FONT * scale))
	_label_variation(theme, "MutedLabel", TEXT_MUTED, int(MUTED_FONT * scale))
	_label_variation(theme, "FaintLabel", TEXT_FAINT, int(FAINT_FONT * scale))
	_label_variation(theme, "SubtleLabel", TEXT_SUBTLE, int(BODY_FONT * scale))
	_label_variation(theme, "MonoLabel", TEXT_FAINT, int(MUTED_FONT * scale))
	_label_variation(theme, "FlareLabel", COLOR_FLARE, int(BALANCE_FONT * scale))
	_label_variation(theme, "PillLabel", TEXT_FAINT, int(FAINT_FONT * scale))

	# .armory-v2-tab / .active. PORT: game.css:1686-1708
	_button_variation(
		theme,
		"TabButton",
		int(TAB_FONT * scale),
		TEXT_FAINT,
		TEXT_PRIMARY,
		flat(Color.TRANSPARENT, Color.TRANSPARENT, TAB_RADIUS),
		flat(COLOR_RAISED, Color.TRANSPARENT, TAB_RADIUS)
	)
	# .weapon-list-item / .active. PORT: game.css:1793-1813
	_button_variation(
		theme,
		"WeaponItem",
		int(HEADING_FONT * scale),
		TEXT_SECONDARY,
		TEXT_PRIMARY,
		flat(Color.TRANSPARENT, Color.TRANSPARENT, WEAPON_ITEM_RADIUS),
		flat(COLOR_RAISED, COLOR_BORDER_ACTIVE, WEAPON_ITEM_RADIUS)
	)
	# .armory-mobile-play-btn. PORT: game.css:2796-2810
	_button_variation(
		theme,
		"PlayButton",
		int(PLAY_FONT * scale),
		COLOR_VOID,
		COLOR_VOID,
		flat(COLOR_ION, Color.TRANSPARENT, PLAY_RADIUS),
		flat(COLOR_ION_HOVER, Color.TRANSPARENT, PLAY_RADIUS)
	)
	# .ship-action-btn.is-equip / .arena-action-btn.is-equip. PORT: game.css:2445-2456
	_button_variation(
		theme,
		"EquipButton",
		int(BODY_FONT * scale),
		TEXT_MUTED,
		COLOR_ION_HOVER,
		flat(Color.TRANSPARENT, COLOR_BORDER_ACTIVE, ACTION_RADIUS),
		flat(COLOR_ION_FILL, COLOR_ION, ACTION_RADIUS)
	)
	# .is-equipped (a disabled button that must keep its green). PORT: game.css:2424-2426
	_button_variation(
		theme,
		"EquippedButton",
		int(BODY_FONT * scale),
		COLOR_SUCCESS,
		COLOR_SUCCESS,
		flat(COLOR_SUCCESS_FILL, COLOR_SUCCESS, ACTION_RADIUS),
		flat(COLOR_SUCCESS_FILL, COLOR_SUCCESS, ACTION_RADIUS)
	)
	theme.set_color("font_disabled_color", "EquippedButton", COLOR_SUCCESS)
	theme.set_stylebox(
		"disabled", "EquippedButton", flat(COLOR_SUCCESS_FILL, COLOR_SUCCESS, ACTION_RADIUS)
	)
	# .keystone-cost-btn. PORT: game.css:2224-2232
	_button_variation(
		theme,
		"KeystoneButton",
		int(BODY_FONT * scale),
		KEYSTONE_TEXT,
		KEYSTONE_TEXT,
		flat(KEYSTONE_BUTTON_FILL, COLOR_PLASMA, ACTION_RADIUS),
		flat(KEYSTONE_BUTTON_FILL, COLOR_PLASMA, ACTION_RADIUS)
	)
	# .handling-reset-btn. PORT: game.css:2698-2707
	_button_variation(
		theme,
		"GhostButton",
		int(BODY_FONT * scale),
		TEXT_MUTED,
		TEXT_PRIMARY,
		flat(Color.TRANSPARENT, COLOR_BORDER_ACTIVE, ACTION_RADIUS),
		flat(COLOR_RAISED, COLOR_BORDER_ACTIVE, ACTION_RADIUS)
	)
	# .armory-v2-close-btn / .armory-mobile-back-btn. PORT: game.css:1737-1749, :1638-1656
	_button_variation(
		theme,
		"IconButton",
		int(BODY_FONT * scale),
		TEXT_MUTED,
		TEXT_PRIMARY,
		flat(Color.TRANSPARENT, COLOR_BORDER, ICON_BUTTON_RADIUS),
		flat(COLOR_RAISED, COLOR_BORDER_ACTIVE, ICON_BUTTON_RADIUS)
	)
	# .upgrade-track-card / .boost-card / .ship-card. PORT: game.css:1935-1937
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", flat(COLOR_PANEL, COLOR_BORDER, CARD_RADIUS))
	return theme


static func _label_variation(theme: Theme, name: String, color: Color, size: int) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_color("font_color", name, color)
	theme.set_font_size("font_size", name, size)


static func _button_variation(
	theme: Theme,
	name: String,
	size: int,
	color: Color,
	active_color: Color,
	normal: StyleBoxFlat,
	active: StyleBoxFlat
) -> void:
	theme.set_type_variation(name, "Button")
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)
	theme.set_color("font_hover_color", name, active_color)
	theme.set_color("font_pressed_color", name, active_color)
	theme.set_color("font_hover_pressed_color", name, active_color)
	theme.set_stylebox("normal", name, normal)
	theme.set_stylebox("hover", name, active)
	theme.set_stylebox("pressed", name, active)
	theme.set_stylebox("hover_pressed", name, active)
	theme.set_stylebox("focus", name, StyleBoxEmpty.new())
