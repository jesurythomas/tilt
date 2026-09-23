# gdlint:disable=max-file-lines
# PORT-NOTE: ArmoryUI.ts is 1,293 lines; LAW 3 keeps it one file. Precedent:
# progression_manager.gd:1-4.
## armory_ui.gd
## PORTS: web/src/tilt-to-live/ArmoryUI.ts (1293 lines, source commit 7be9614)
class_name ArmoryUI
extends Control
## In-game shop: weapons, ships, arena, handling, boosts (Boards 09, 10, 11, 17).
##
## PORT-NOTE: the TS rebuilds the modal's innerHTML on every render() and then
## queries the new DOM to bind handlers (:329-395, :1119-1292). Here render()
## rebuilds the body's child Controls and each button's `pressed` is connected
## as it is built; the handler bodies of bindEvents() are the `_on_*` methods
## below, in the TS's order.
##
## PORT-NOTE: the two constructor callbacks (:76-77) are the signals
## `state_changed` and `closed` — UI→game, the direction spec §5.3 allows.
##
## PORT-NOTE: the handling preview canvas (:83-94, :943-1113) relocates to
## src/ui/handling_preview.gd, a `_draw()` Control, per spec §4.2/D4 — the
## relocation M3/M4/M7 made for render() bodies.
##
## DIVERGENCE(UI-SYSTEM): ArmoryWeapons/Ships/Arena/Handling/Boosts.dc.html lay
## the Armory out (interface spec §6.4): a full-screen shell, a 64 px header
## (back, title, five tabs, points, Play) over the tab body. The close ✕ and
## the mobile sticky Play footer are gone, and with them spec §8 M8's
## mobile-chrome gate. scenes/armory.tscn holds the node tree only; every
## board literal is a constant below. On mobile the content is still inset by
## GameRoot.arena_origin so it stays inside the safe area (spec §8 M8
## acceptance); the Overlay behind it always covers the screen.

## onStateChanged (ArmoryUI.ts:76): after every successful purchase, equip or
## tuning change.
signal state_changed
## onCloseModal (ArmoryUI.ts:77): after close().
signal closed
## Handling's "Calibrate tilt" (interface spec §5): GameRoot calls calibrate_gyro().
signal calibrate_requested

## The five live tabs. PORT: web/src/tilt-to-live/ArmoryUI.ts:80
enum Tab { WEAPONS, SHIPS, ARENA, HANDLING, BOOSTS }

## Tab labels in row order. PORT: web/src/tilt-to-live/ArmoryUI.ts:353-357
const TAB_LABELS: Array[String] = ["Weapons", "Ships", "Arena", "Handling", "Boosts"]
## Canonical tab names, indexed by Tab. PORT: web/src/tilt-to-live/ArmoryUI.ts:10-15
const TAB_NAMES: Array[String] = ["weapons", "ships", "arena", "handling", "boosts"]
## The ten ArmoryTab names, legacy aliases included. PORT: web/src/tilt-to-live/ArmoryUI.ts:296-307
const TAB_ALIASES: Dictionary[String, int] = {
	"weapons": Tab.WEAPONS,
	"perks": Tab.WEAPONS,
	"ships": Tab.SHIPS,
	"cursors": Tab.SHIPS,
	"arena": Tab.ARENA,
	"arenas": Tab.ARENA,
	"enemies": Tab.ARENA,
	"handling": Tab.HANDLING,
	"tuning": Tab.HANDLING,
	"boosts": Tab.BOOSTS,
}
## Raster density for the TS's SVG strings, on top of ui_scale.
# PORT-NOTE: a raster-density choice with no TS counterpart (the browser
# rasterises SVG at device DPR); 2.0 keeps the 30 px icons crisp on the A55.
const SVG_OVERSAMPLE: float = 2.0

## Engine WeaponType → weaponsCatalog id. PORT: web/src/tilt-to-live/ArmoryUI.ts:205-211
# PORT-NOTE: the TS alias table has one entry (vortex → blackhole) because the
# other six ids coincide as strings (:218). Godot enums have no string
# identity, so all seven are listed; only VORTEX is a true alias.
const STARTING_WEAPON_IDS: Dictionary[int, String] = {
	Types.WeaponType.VORTEX: "blackhole",
	Types.WeaponType.NUKE: "nuke",
	Types.WeaponType.MISSILES: "missiles",
	Types.WeaponType.LIGHTNING: "lightning",
	Types.WeaponType.LASER: "laser",
	Types.WeaponType.FREEZE: "freeze",
	Types.WeaponType.SHIELD: "shield",
}
const TRACK_PIPS: int = 5  # PORT: web/src/tilt-to-live/ArmoryUI.ts:454
const RANK_DENOMINATOR: int = 5  # PORT: web/src/tilt-to-live/ArmoryUI.ts:431, :485
const DEFAULT_KEYSTONE_COST: int = 2500  # PORT: web/src/tilt-to-live/ArmoryUI.ts:507
## Shell header. DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — 64 px tall
## (padding 8/28/8/24 around 48 px targets), gap 12, tabs gap 2, Play 92×48,
## the space between the points figure and its unit.
const HEADER_PAD_Y: int = 8
const HEADER_PAD_RIGHT: int = 28
const HEADER_PAD_LEFT: int = 24
const SHELL_GAP: int = 12
const TABS_GAP: int = 2
const PLAY_WIDTH: int = 92
const BALANCE_GAP: int = 4
## Weapons layout. DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — list 196 wide,
## padding 10/10/0/24, row gap 2, row inner gap 10, dot 8, foot fade 36; detail
## padding 16/28/16/20, gap 14; header gap 14, icon box 44 (tint 10% / 35%) with
## a 22 px icon, title gap 2; tracks | keystones 1.65fr | 1fr, gap 12, stacks
## gap 8; track row 62 tall, padding 0/7/0/14, gap 12, info 104 wide, info gap
## 2, cost 88 wide; keystone padding 8/7/8/13, gap 10, plasma 7% fill / 30% border.
const LIST_WIDTH: int = 196
const LIST_PAD_TOP: int = 10
const LIST_PAD_RIGHT: int = 10
const LIST_PAD_LEFT: int = 24
const LIST_GAP: int = 2
const LIST_ROW_GAP: int = 10
const DOT_SIZE: int = 8
const FADE_HEIGHT: int = 36
const DETAIL_PAD_TOP: int = 16
const DETAIL_PAD_RIGHT: int = 28
const DETAIL_PAD_BOTTOM: int = 16
const DETAIL_PAD_LEFT: int = 20
const DETAIL_GAP: int = 14
const DETAIL_HEADER_GAP: int = 14
const ICON_BOX: int = 44
const ICON_SIZE: int = 22
const ICON_BOX_FILL_ALPHA: float = 0.1
const ICON_BOX_BORDER_ALPHA: float = 0.35
const TITLE_GROUP_GAP: int = 2
const TRACKS_RATIO: float = 1.65
const DETAIL_GRID_GAP: int = 12
const TRACKS_GAP: int = 8
const TRACK_ROW_HEIGHT: int = 62
const TRACK_PAD_RIGHT: int = 7
const TRACK_PAD_LEFT: int = 14
const TRACK_GAP: int = 12
const TRACK_INFO_WIDTH: int = 104
const TRACK_INFO_GAP: int = 2
const COST_WIDTH: int = 88
const KEYSTONE_PAD_Y: int = 8
const KEYSTONE_PAD_RIGHT: int = 7
const KEYSTONE_PAD_LEFT: int = 13
const KEYSTONE_GAP: int = 10
const KEYSTONE_FILL_ALPHA: float = 0.07
const KEYSTONE_BORDER_ALPHA: float = 0.3

## Tab body padding shared by ArmoryShips/Handling/Boosts.dc.html: 14 top, 16
## bottom, 24 left; 28 right except Ships, whose row bleeds off the right edge.
const BODY_PAD_TOP: int = 14
const BODY_PAD_RIGHT: int = 28
const BODY_PAD_BOTTOM: int = 16
const BODY_PAD_LEFT: int = 24
## Ships layout. DIVERGENCE(UI-SYSTEM): ArmoryShips.dc.html — gap 12; caption gap 12; card
## 172 wide, r 8, gap 12; preview 82 tall with a 44 px hull; body padding
## 11/12/12, gap 8; meter label 42 wide, meter 4 tall, gap 8; unowned hull at 45%.
const SHIPS_GAP: int = 12
const SHIP_CARD_WIDTH: int = 172
const SHIP_CARD_RADIUS: int = 8
const SHIP_PREVIEW_HEIGHT: int = 82
const SHIP_HULL_SIZE: int = 44
const SHIP_BODY_PAD_TOP: int = 11
const SHIP_BODY_PAD: int = 12
const SHIP_BODY_GAP: int = 8
const SHIP_METER_LABEL: int = 42
const SHIP_METER_HEIGHT: int = 4
const LOCKED_PREVIEW_ALPHA: float = 0.45
const LOADOUT_ICON: int = 16  # PORT: web/src/styles/game.css:2385-2386 (no board slot; Ruling N)
## "Hull · N of 6". PORT: web/src/tilt-to-live/ArmoryUI.ts:646
# PORT-NOTE: the TS hard-codes 6 while the catalog has 7 ships (the fixture
# lists classic..revenant); preserved deliberately. Open question 4.
const SHIP_COUNT_LABEL: int = 6

## Arena layout. DIVERGENCE(UI-SYSTEM): ArmoryArena.dc.html — body padding
## 12/0/14/24, gap 10 (+4 above ENEMIES); card 146 wide, r 6, gap 10; preview
## 56 tall, grid 12 px, edge inset 8/7; body padding 8/10/9, gap 3; name 13;
## enemy dots 12/9/12, gap 12.
const ARENA_PAD_TOP: int = 12
const ARENA_PAD_BOTTOM: int = 14
const ARENA_GAP: int = 10
const ENEMIES_TOP: int = 4
const ARENA_CARD_WIDTH: int = 146
const ARENA_PREVIEW_HEIGHT: int = 56
const ARENA_GRID_STEP: int = 12
const ARENA_EDGE_X: int = 8
const ARENA_EDGE_Y: int = 7
const ARENA_BODY_PAD_TOP: int = 8
const ARENA_BODY_PAD_X: int = 10
const ARENA_BODY_PAD_BOTTOM: int = 9
const ARENA_BODY_GAP: int = 3
const ARENA_NAME_FONT: int = 13
const ENEMY_DOT_LARGE: int = 12
const ENEMY_DOT_SMALL: int = 9
const ENEMY_DOT_GAP: int = 12

## Boosts layout. DIVERGENCE(UI-SYSTEM): ArmoryBoosts.dc.html — body padding
## BODY_PAD_* (Task 6), gap 10; 2-col grid gap 8; card 76 tall, padding 0/13/0/16, gap
## 14; text stack gap 7, name/effect gap 10; pips at most 180 wide; cost 92×48.
const BOOSTS_GAP: int = 10
const BOOST_COLUMNS: int = 2
const BOOST_GRID_GAP: int = 8
const BOOST_CARD_HEIGHT: int = 76
const BOOST_PAD_RIGHT: int = 13
const BOOST_PAD_LEFT: int = 16
const BOOST_CARD_GAP: int = 14
const BOOST_STACK_GAP: int = 7
const BOOST_NAME_GAP: int = 10
const BOOST_PIPS_WIDTH: int = 180
const BOOST_COST_WIDTH: int = 92
## Handling layout. DIVERGENCE(UI-SYSTEM): ArmoryHandling.dc.html — body padding
## BODY_PAD_* (Task 6), columns gap 28; left stack gap 10, field gap 2, slider 40 tall,
## value Mono 14 ion; bottom row gap 8; preview stack gap 8, box r 8; legend at
## left 14 / bottom 12, gap 16, glyph 8, glyph-label gap 6.
const HANDLING_COLUMN_GAP: int = 28
const HANDLING_STACK_GAP: int = 10
const HANDLING_FIELD_GAP: int = 2
const HANDLING_SLIDER_HEIGHT: int = 40
const HANDLING_VALUE_FONT: int = 14
const HANDLING_ROW_GAP: int = 8
const PREVIEW_RADIUS: int = 8
const LEGEND_LEFT: int = 14
const LEGEND_BOTTOM: int = 12
const LEGEND_GAP: int = 16
const LEGEND_GLYPH: int = 8
const LEGEND_GLYPH_GAP: int = 6
## Turn-rate slider range. PORT: web/src/tilt-to-live/ArmoryUI.ts:823-825
const TURN_MIN: float = 0.5
const TURN_MAX: float = 2.0
const TURN_STEP: float = 0.1
## Tilt-sensitivity slider range (interface spec §6.4; ArmoryHandling.dc.html
## 0.5–2.0 step 0.1; ruled 2026-09-23 — the stored clamp stays 0.4–2.5,
## control_settings.gd:18-19).
const TILT_MIN: float = 0.5
const TILT_MAX: float = 2.0
const TILT_STEP: float = 0.1
## Reset defaults. PORT: web/src/tilt-to-live/ArmoryUI.ts:1287-1288
const DEFAULT_SENSITIVITY: float = 1.0
const DEFAULT_DEADZONE: float = 4.0
## ControlSettings' own default. PORT: control_settings.gd:27 (M2.5 spec §4.1)
const DEFAULT_TILT_SENSITIVITY: float = 1.0

## The save every tab reads and every purchase writes. PORT: web/src/tilt-to-live/ArmoryUI.ts:75
var progression: ProgressionManager = null
## PORT: web/src/tilt-to-live/ArmoryUI.ts:80
var active_tab: Tab = Tab.WEAPONS
## PORT: web/src/tilt-to-live/ArmoryUI.ts:81
var selected_weapon_id: String = "blackhole"
## PORT: web/src/tilt-to-live/ArmoryUI.ts:96-203 — built in Task 2.
var weapons_catalog: Array[WeaponConfig] = []
## PORT: web/src/tilt-to-live/ArmoryUI.ts:222-268 — built in Task 5.
var boosts_catalog: Array[BoostConfig] = []
## Tilt sensitivity lives here (interface spec §6.4); null hides that slider.
var _settings: ControlSettings = null
var _ui_scale: float = 1.0
var _tab_buttons: Array[Button] = []
## The live steering preview shown on the handling tab. PORT: web/src/tilt-to-live/ArmoryUI.ts:84
var _preview: HandlingPreview = null

@onready var _overlay: ColorRect = %Overlay
@onready var _panel_margin: MarginContainer = %PanelMargin
@onready var _header_margin: MarginContainer = %HeaderMargin
@onready var _header: HBoxContainer = %Header
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _tabs: HBoxContainer = %Tabs
@onready var _balance: HBoxContainer = %Balance
@onready var _balance_label: Label = %BalanceLabel
@onready var _balance_unit: Label = %BalanceUnit
@onready var _play_button: Button = %PlayButton
@onready var _header_rule: ColorRect = %HeaderRule
@onready var _body: MarginContainer = %Body


func _ready() -> void:
	visible = false
	_overlay.color = UiTheme.COLOR_SHELL
	_header_rule.color = UiTheme.COLOR_RAISED  # DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html
	_balance_unit.add_theme_color_override("font_color", UiTheme.POINTS_UNIT)

	# PORT: web/src/tilt-to-live/ArmoryUI.ts:1123-1131 — back and Play both close.
	_back_button.pressed.connect(close)
	_play_button.pressed.connect(close)

	# PORT: web/src/tilt-to-live/ArmoryUI.ts:353-357, :1134-1142
	for i: int in range(TAB_LABELS.size()):
		var button: Button = Button.new()
		button.name = "Tab_" + TAB_NAMES[i]
		button.text = TAB_LABELS[i]
		button.toggle_mode = true  # button_pressed is ignored without it
		button.theme_type_variation = "TabButton"
		button.pressed.connect(_on_tab_pressed.bind(i as Tab))
		_tabs.add_child(button)
		_tab_buttons.append(button)

	weapons_catalog = _build_weapons_catalog()
	boosts_catalog = _build_boosts_catalog()
	set_ui_scale(1.0)


## Constructor half. PORT: web/src/tilt-to-live/ArmoryUI.ts:270-280
## `s` carries the tilt sensitivity the Handling tab edits (interface spec §6.4).
func bind(p: ProgressionManager, s: ControlSettings = null) -> void:
	progression = p
	_settings = s


## Resolves a ship's startingWeapon to its weaponsCatalog entry, or null.
## PORT: web/src/tilt-to-live/ArmoryUI.ts:213-220
func get_starting_weapon_config(weapon_type: Types.WeaponType) -> WeaponConfig:
	var catalog_id: String = STARTING_WEAPON_IDS.get(weapon_type, "")
	for w: WeaponConfig in weapons_catalog:
		if w.id == catalog_id:
			return w
	return null


## PORT: web/src/tilt-to-live/ArmoryUI.ts:294-315
func open(tab: String = "") -> void:
	if not tab.is_empty():
		active_tab = (TAB_ALIASES[tab] as Tab) if TAB_ALIASES.has(tab) else Tab.WEAPONS  # PORT: :308
	visible = true
	render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:317-323
func close() -> void:
	_stop_handling_preview()
	visible = false
	closed.emit()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:325-327
func is_open() -> bool:
	return visible


## PORT: web/src/tilt-to-live/ArmoryUI.ts:329-395
func render() -> void:
	if progression == null:
		return
	_stop_handling_preview()

	# Preserve scroll position if re-rendering within the same tab (:334-336)
	var prev_scroll: ScrollContainer = find_child("ScrollBody", true, false) as ScrollContainer
	var prev_scroll_top: int = prev_scroll.scroll_vertical if prev_scroll != null else 0

	var points: int = progression.data.points
	# PORT: :363 (formatPoints, singular at 1 per :70-72). DIVERGENCE(UI-SYSTEM):
	# ArmoryWeapons.dc.html splits the figure (Mono 15, flare) from its unit (caps).
	_balance_label.text = UiTheme.group_digits(points)
	_balance_unit.text = "PT" if points == 1 else "PTS"
	for i: int in range(_tab_buttons.size()):
		var is_active: bool = (i as Tab) == active_tab
		_tab_buttons[i].button_pressed = is_active  # PORT: :353-357
		# DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — the selected tab is 600.
		_tab_buttons[i].add_theme_font_override(
			"font", UiTheme.sans(UiTheme.Weight.SEMIBOLD if is_active else UiTheme.Weight.MEDIUM)
		)

	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_body.add_child(_render_tab_content())

	if active_tab == Tab.HANDLING:
		_init_handling_preview()

	var new_scroll: ScrollContainer = find_child("ScrollBody", true, false) as ScrollContainer
	if new_scroll != null and prev_scroll_top > 0:
		new_scroll.set_deferred("scroll_vertical", prev_scroll_top)  # PORT: :391-394


## Scales the Theme and every board size to the viewport (HudController's
## ui_scale). `inset` is GameRoot.arena_origin: on mobile the content is pulled
## in by it so it stays inside the safe area; desktop runs edge to edge.
func set_ui_scale(scale: float, inset: Vector2 = Vector2.ZERO) -> void:
	_ui_scale = scale
	theme = UiTheme.build(scale)
	var pad: Vector2 = inset if OS.has_feature("mobile") else Vector2.ZERO
	_panel_margin.add_theme_constant_override("margin_left", int(pad.x))
	_panel_margin.add_theme_constant_override("margin_right", int(pad.x))
	_panel_margin.add_theme_constant_override("margin_top", int(pad.y))
	_panel_margin.add_theme_constant_override("margin_bottom", int(pad.y))
	_header_margin.add_theme_constant_override("margin_left", _px(HEADER_PAD_LEFT))
	_header_margin.add_theme_constant_override("margin_top", _px(HEADER_PAD_Y))
	_header_margin.add_theme_constant_override("margin_right", _px(HEADER_PAD_RIGHT))
	_header_margin.add_theme_constant_override("margin_bottom", _px(HEADER_PAD_Y))
	_header.add_theme_constant_override("separation", _px(SHELL_GAP))
	_tabs.add_theme_constant_override("separation", _px(TABS_GAP))
	_balance.add_theme_constant_override("separation", _px(BALANCE_GAP))
	var side: float = UiTheme.TOUCH_TARGET * scale
	_back_button.custom_minimum_size = Vector2(side, side)
	_back_button.icon = UiTheme.svg_texture(UiTheme.ICON_BACK, scale)
	for button: Button in _tab_buttons:
		button.custom_minimum_size.y = side
	_play_button.custom_minimum_size = Vector2(PLAY_WIDTH * scale, side)
	if is_open():
		render()


## Formats a WEAPON_TUNING value per its unit. PORT: web/src/tilt-to-live/ArmoryUI.ts:46-57
static func format_tuning_value(value: float, unit: Tuning.TuningUnit) -> String:
	match unit:
		Tuning.TuningUnit.SECONDS:
			return "%.1fs" % value
		Tuning.TuningUnit.PERCENT:
			return "+%d%%" % roundi(value)
		_:
			return "%d" % roundi(value)


## "1 pt" / "400 pts" with thousands grouping. PORT: web/src/tilt-to-live/ArmoryUI.ts:70-72
static func format_points(n: int) -> String:
	return "%s %s" % [UiTheme.group_digits(n), "pt" if n == 1 else "pts"]


## PORT: web/src/tilt-to-live/ArmoryUI.ts:397-410
func _render_tab_content() -> Control:
	match active_tab:
		Tab.SHIPS:
			return _render_ships_tab()
		Tab.ARENA:
			return _render_arena_tab()
		Tab.HANDLING:
			return _render_handling_tab()
		Tab.BOOSTS:
			return _render_boosts_tab()
		_:
			return _render_weapons_tab()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:416-569
## DIVERGENCE(UI-SYSTEM): laid out to ArmoryWeapons.dc.html (interface spec §6.4).
func _render_weapons_tab() -> Control:
	var perks: Dictionary = progression.data.perks.to_dict()  # PORT: :417, :429
	var points: int = progression.data.points

	var selected: WeaponConfig = weapons_catalog[0]
	for w: WeaponConfig in weapons_catalog:
		if w.id == selected_weapon_id:
			selected = w
	var invested_points: int = progression.get_weapon_invested_points(selected.id)

	var layout: HBoxContainer = HBoxContainer.new()
	layout.name = "WeaponsTab"
	layout.add_theme_constant_override("separation", 0)
	layout.add_child(_weapon_list(perks, selected))  # PORT: :427-442, :533-535
	layout.add_child(_vrule())

	# Right panel: detail, upgrades, keystones. PORT: :538-566
	var detail: VBoxContainer = VBoxContainer.new()
	detail.add_theme_constant_override("separation", _px(DETAIL_GAP))
	detail.add_child(_weapon_header(selected, invested_points))
	var grid: HBoxContainer = HBoxContainer.new()
	grid.add_theme_constant_override("separation", _px(DETAIL_GRID_GAP))
	var weapon_data: Dictionary = SaveStore.read_dict(perks, selected.id)
	# Upgrade tracks with five discrete pips. PORT: :445-498
	var tracks: VBoxContainer = VBoxContainer.new()
	tracks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracks.size_flags_stretch_ratio = TRACKS_RATIO
	tracks.add_theme_constant_override("separation", _px(TRACKS_GAP))
	for track: WeaponTrack in selected.tracks:
		tracks.add_child(_track_card(selected, track, weapon_data, points))
	grid.add_child(tracks)
	# One-off unlocks (Aegis, Supernova, ...). PORT: :501-528, :560-565
	var keystones: VBoxContainer = VBoxContainer.new()
	keystones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keystones.add_theme_constant_override("separation", _px(TRACKS_GAP))
	for k: WeaponKeystone in selected.keystones:
		keystones.add_child(_keystone_card(selected, k, weapon_data, points))
	grid.add_child(keystones)
	detail.add_child(grid)

	var detail_margin: MarginContainer = _pad(
		DETAIL_PAD_TOP, DETAIL_PAD_RIGHT, DETAIL_PAD_BOTTOM, DETAIL_PAD_LEFT
	)
	detail_margin.add_child(detail)
	var detail_scroll: ScrollContainer = _scroll_body(detail_margin)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(detail_scroll)
	return layout


## The weapon list (Board 09). PORT: web/src/tilt-to-live/ArmoryUI.ts:427-442
func _weapon_list(perks: Dictionary, selected: WeaponConfig) -> Control:
	var box: Control = Control.new()
	box.name = "WeaponList"
	box.custom_minimum_size.x = _px(LIST_WIDTH)
	box.clip_contents = true
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad: MarginContainer = _pad(LIST_PAD_TOP, LIST_PAD_RIGHT, 0, LIST_PAD_LEFT)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", _px(LIST_GAP))
	for w: WeaponConfig in weapons_catalog:
		var p: Dictionary = SaveStore.read_dict(perks, w.id)
		# PORT: :430 — duration, else count, else radius, else 0
		var primary_val: int = 0
		if p.get("duration") is int:
			primary_val = p["duration"]
		elif p.get("count") is int:
			primary_val = p["count"]
		elif p.get("radius") is int:
			primary_val = p["radius"]
		var is_selected: bool = w.id == selected.id
		var item: Button = Button.new()
		item.name = "Weapon_" + w.id
		item.toggle_mode = true
		item.button_pressed = is_selected
		item.theme_type_variation = "ListItemButton"
		item.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
		item.pressed.connect(_on_weapon_item_pressed.bind(w.id))
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", _px(LIST_ROW_GAP))
		var dot: ColorRect = ColorRect.new()  # PORT: :436
		dot.color = w.dot
		dot.custom_minimum_size = Vector2.ONE * _px(DOT_SIZE)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var name_label: Label = _one_line(w.name, "LabelText")  # PORT: :437
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_override("font", UiTheme.sans(UiTheme.Weight.MEDIUM))
		if is_selected:
			name_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)
		# PORT: :431, :438
		var rank: Label = UiTheme.text("%d/%d" % [primary_val, RANK_DENOMINATOR], "MonoFaintText")
		rank.name = "WeaponRank_" + w.id
		rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rank)
		item.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = _px(UiTheme.TAB_PAD_X)
		row.offset_right = -_px(UiTheme.TAB_PAD_X)
		rows.add_child(item)
	pad.add_child(rows)
	scroll.add_child(pad)
	# The shell-coloured fade over the list's foot. DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, UiTheme.tint(UiTheme.COLOR_SHELL, 0.0))
	gradient.set_color(1, UiTheme.COLOR_SHELL)
	var fade_texture: GradientTexture2D = GradientTexture2D.new()
	fade_texture.gradient = gradient
	fade_texture.fill_to = Vector2(0.0, 1.0)
	var fade: TextureRect = TextureRect.new()
	fade.texture = fade_texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fade.offset_top = -_px(FADE_HEIGHT)
	return box


## Icon, title, description and invested points. PORT: web/src/tilt-to-live/ArmoryUI.ts:540-552
func _weapon_header(selected: WeaponConfig, invested_points: int) -> HBoxContainer:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", _px(DETAIL_HEADER_GAP))
	header.add_child(_icon_box(selected))  # PORT: :541-543
	var title_group: VBoxContainer = VBoxContainer.new()
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_group.alignment = BoxContainer.ALIGNMENT_CENTER
	title_group.add_theme_constant_override("separation", _px(TITLE_GROUP_GAP))
	title_group.add_child(_one_line(selected.name, "TitleText"))  # PORT: :545
	title_group.add_child(_one_line(selected.description, "BodyText"))  # PORT: :546
	header.add_child(title_group)
	var badge: VBoxContainer = VBoxContainer.new()  # PORT: :548-551
	badge.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_theme_constant_override("separation", _px(TITLE_GROUP_GAP))
	var caption: Label = UiTheme.caps("Invested")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_child(caption)
	var invested: Label = UiTheme.text(UiTheme.group_digits(invested_points), "PointsText")
	invested.name = "InvestedValue"
	invested.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_child(invested)
	header.add_child(badge)
	return header


## One upgrade-track row. PORT: web/src/tilt-to-live/ArmoryUI.ts:447-495
func _track_card(
	selected: WeaponConfig, track: WeaponTrack, weapon_data: Dictionary, points: int
) -> PanelContainer:
	var current_rank: int = SaveStore.read_int(weapon_data, track.key, 0)  # PORT: :448
	var is_maxed: bool = current_rank >= track.max_rank
	var cost: int = progression.get_perk_cost(current_rank, false)  # PORT: :450
	var can_afford: bool = points >= cost and not is_maxed

	var card: PanelContainer = PanelContainer.new()
	card.name = "TrackCard_" + track.key
	card.theme_type_variation = "Card"
	card.custom_minimum_size.y = _px(TRACK_ROW_HEIGHT)
	var inner: MarginContainer = _pad(0, TRACK_PAD_RIGHT, 0, TRACK_PAD_LEFT)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(TRACK_GAP))
	var info: VBoxContainer = VBoxContainer.new()
	info.custom_minimum_size.x = _px(TRACK_INFO_WIDTH)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", _px(TRACK_INFO_GAP))
	info.add_child(_one_line(track.name, "StrongText"))
	info.add_child(_one_line(track.effect, "MonoText"))
	# Current (and, unless maxed, next-rank) value straight from WEAPON_TUNING (:459-473).
	# Ruling N: kept as the row's second Mono line.
	var tuning_tracks: Dictionary = Tuning.weapon_tuning.get(selected.id, {})
	if tuning_tracks.has(track.key):
		var entry: Tuning.TuningEntry = tuning_tracks[track.key]
		var current_text: String = format_tuning_value(
			Tuning.get_tuned_value(selected.id, track.key, current_rank), entry.unit
		)
		var value_text: String = current_text
		if not is_maxed:
			var next_text: String = format_tuning_value(
				Tuning.get_tuned_value(selected.id, track.key, current_rank + 1), entry.unit
			)
			value_text = "%s → %s" % [current_text, next_text]  # PORT: :469 (&rarr;)
		var value_label: Label = _one_line(value_text, "MonoFaintText")
		value_label.name = "TrackValue_" + track.key
		info.add_child(value_label)
	row.add_child(info)
	var pips: HBoxContainer = UiTheme.pips(current_rank, TRACK_PIPS, _ui_scale)  # PORT: :453-457
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	var buy: Button = Button.new()  # PORT: :486-494
	buy.name = "Track_" + track.key
	buy.theme_type_variation = "CostButton"
	buy.custom_minimum_size = Vector2(_px(COST_WIDTH), _px(UiTheme.TOUCH_TARGET))
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = is_maxed or not can_afford
	buy.text = "Max" if is_maxed else UiTheme.group_digits(cost)  # Ruling K
	buy.pressed.connect(_on_track_pressed.bind(selected.id, track.key))
	row.add_child(buy)
	inner.add_child(row)
	card.add_child(inner)
	return card


## One keystone card. PORT: web/src/tilt-to-live/ArmoryUI.ts:502-526
func _keystone_card(
	selected: WeaponConfig, k: WeaponKeystone, weapon_data: Dictionary, points: int
) -> PanelContainer:
	var is_unlocked: bool = SaveStore.read_bool(weapon_data, k.key, false)  # PORT: :504
	# KEYSTONE_COSTS is the same table get_perk_cost() charges from (:505-507)
	var cost: int = Tuning.KEYSTONE_COSTS.get(k.key, DEFAULT_KEYSTONE_COST)
	var can_afford: bool = points >= cost and not is_unlocked
	var is_locked: bool = not is_unlocked and not can_afford  # Ruling L

	var card: PanelContainer = PanelContainer.new()
	card.name = "KeystoneCard_" + k.key
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if is_locked:
		card.theme_type_variation = "LockedCard"
	elif is_unlocked:
		card.theme_type_variation = "Card"
	else:
		card.add_theme_stylebox_override(
			"panel",
			UiTheme.flat(
				UiTheme.tint(UiTheme.COLOR_PLASMA, KEYSTONE_FILL_ALPHA),
				UiTheme.tint(UiTheme.COLOR_PLASMA, KEYSTONE_BORDER_ALPHA),
				_px(UiTheme.CARD_RADIUS)
			)
		)
	var inner: MarginContainer = _pad(
		KEYSTONE_PAD_Y, KEYSTONE_PAD_RIGHT, KEYSTONE_PAD_Y, KEYSTONE_PAD_LEFT
	)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(KEYSTONE_GAP))
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", _px(TITLE_GROUP_GAP))
	var title: Label = _one_line(k.name, "StrongText")
	var desc: Label = UiTheme.text(k.description, "HintText")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_locked:
		title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_MUTED)
		desc.add_theme_color_override("font_color", UiTheme.TEXT_FAINT)
	info.add_child(title)
	info.add_child(desc)
	row.add_child(info)
	var buy: Button = Button.new()  # PORT: :516-524
	buy.name = "Keystone_" + k.key
	buy.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_unlocked:
		buy.theme_type_variation = "EquippedButton"
		buy.text = "Unlocked ✓"
		buy.disabled = true
	else:
		buy.theme_type_variation = "PlasmaCostButton"
		buy.text = UiTheme.group_digits(cost)  # Ruling K
		buy.disabled = not can_afford
		if is_locked:
			buy.icon = UiTheme.svg_texture(UiTheme.ICON_LOCK, _ui_scale)
	buy.pressed.connect(_on_keystone_pressed.bind(selected.id, k.key))
	row.add_child(buy)
	inner.add_child(row)
	card.add_child(inner)
	return card


## PORT: web/src/tilt-to-live/ArmoryUI.ts:575-656
## DIVERGENCE(UI-SYSTEM): laid out to ArmoryShips.dc.html (interface spec §6.4).
func _render_ships_tab() -> Control:
	var equipped_id: String = progression.data.equipped_cursor_id
	var unlocked_ids: Array[String] = progression.data.unlocked_cursors
	var ships: Array[ProgressionManager.ShipSkinConfig] = progression.ship_catalog

	var unlocked_count: int = 0
	var hitboxes: Array[float] = []
	var turns: Array[float] = []
	for s: ProgressionManager.ShipSkinConfig in ships:
		if unlocked_ids.has(s.id):
			unlocked_count += 1
		hitboxes.append(s.hitbox_scale)
		turns.append(s.turn_rate)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "ShipsTab"
	column.add_theme_constant_override("separation", _px(SHIPS_GAP))
	# Subheader (Board 10). PORT: :645-648
	column.add_child(
		_caption_row(
			"ShipsPill",
			"Hull · %d of %d unlocked" % [unlocked_count, SHIP_COUNT_LABEL],
			"Changes hitbox and turn rate. Nothing else."
		)
	)
	var row: HBoxContainer = HBoxContainer.new()  # PORT: :651-653
	row.add_theme_constant_override("separation", _px(SHIPS_GAP))
	for ship: ProgressionManager.ShipSkinConfig in ships:
		row.add_child(
			_ship_card(
				ship,
				unlocked_ids.has(ship.id),
				equipped_id == ship.id,
				ship_meter_fraction(ship.hitbox_scale, hitboxes),
				ship_meter_fraction(ship.turn_rate, turns)
			)
		)
	column.add_child(_scroll_row("ShipsRow", row))
	var margin: MarginContainer = _pad(BODY_PAD_TOP, 0, BODY_PAD_BOTTOM, BODY_PAD_LEFT)
	margin.add_child(column)
	return _scroll_body(margin)


## A ship's stat against the catalog's largest value of that stat, for the
## Hitbox and Turn meters (interface spec §6.4, ruled; ArmoryShips.dc.html).
static func ship_meter_fraction(value: float, values: Array[float]) -> float:
	var top: float = 0.0
	for v: float in values:
		top = maxf(top, v)
	return value / top if top > 0.0 else 0.0


## One ship card. PORT: web/src/tilt-to-live/ArmoryUI.ts:586-636
## DIVERGENCE(UI-SYSTEM): ArmoryShips.dc.html — card, preview, meters, action.
func _ship_card(
	ship: ProgressionManager.ShipSkinConfig,
	is_unlocked: bool,
	is_equipped: bool,
	hitbox: float,
	turn: float
) -> PanelContainer:
	var points: int = progression.data.points
	var can_afford: bool = points >= ship.price
	var card: PanelContainer = PanelContainer.new()  # PORT: :623
	card.name = "Ship_" + ship.id
	card.custom_minimum_size.x = _px(SHIP_CARD_WIDTH)
	var border: Color = UiTheme.COLOR_LOCKED_IN if is_equipped else UiTheme.COLOR_LINE
	var fill: Color = UiTheme.COLOR_PANEL
	if not is_unlocked:
		fill = UiTheme.LOCKED_CARD
		border = UiTheme.COLOR_RAISED
	card.add_theme_stylebox_override("panel", UiTheme.flat(fill, border, _px(SHIP_CARD_RADIUS)))
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)

	# Preview. PORT: :624-626
	var preview: PanelContainer = PanelContainer.new()
	preview.custom_minimum_size.y = _px(SHIP_PREVIEW_HEIGHT)
	var preview_box: StyleBoxFlat = UiTheme.flat(UiTheme.COLOR_ARENA, UiTheme.COLOR_RAISED, 0)
	preview_box.set_border_width_all(0)
	preview_box.border_width_bottom = 1
	preview.add_theme_stylebox_override("panel", preview_box)
	var hull: TextureRect = TextureRect.new()
	hull.texture = UiTheme.svg_texture(
		progression.get_ship_svg_preview(ship.id), SVG_OVERSAMPLE * _ui_scale
	)
	hull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hull.custom_minimum_size = Vector2.ONE * _px(SHIP_HULL_SIZE)
	if not is_unlocked:
		hull.modulate.a = LOCKED_PREVIEW_ALPHA
	var preview_center: CenterContainer = CenterContainer.new()
	preview_center.add_child(hull)
	preview.add_child(preview_center)
	stack.add_child(preview)

	# Body. PORT: :627-636
	var body: MarginContainer = _pad(SHIP_BODY_PAD_TOP, SHIP_BODY_PAD, SHIP_BODY_PAD, SHIP_BODY_PAD)
	var body_stack: VBoxContainer = VBoxContainer.new()
	body_stack.add_theme_constant_override("separation", _px(SHIP_BODY_GAP))
	var header: HBoxContainer = HBoxContainer.new()  # PORT: :628-631
	var name_label: Label = _one_line(ship.name, "FieldText")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not is_unlocked:
		name_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_MUTED)
	header.add_child(name_label)
	header.add_child(UiTheme.text(ship.trait_text, "MonoFaintText"))
	body_stack.add_child(header)
	body_stack.add_child(_meter_row("Hitbox", "HitboxMeter_" + ship.id, hitbox))
	body_stack.add_child(_meter_row("Turn", "TurnMeter_" + ship.id, turn))

	var starting: WeaponConfig = get_starting_weapon_config(ship.starting_weapon)  # PORT: :609
	if starting != null:  # PORT: :610-620 — Ruling N
		var loadout: HBoxContainer = HBoxContainer.new()
		var starts_with: Label = UiTheme.text("Starts with", "MonoFaintText")
		starts_with.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		loadout.add_child(starts_with)
		var icon: TextureRect = TextureRect.new()
		icon.texture = UiTheme.svg_texture(starting.icon_svg, SVG_OVERSAMPLE * _ui_scale)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2.ONE * _px(LOADOUT_ICON)
		loadout.add_child(icon)
		var loadout_name: Label = UiTheme.text(starting.name, "MonoText")
		loadout_name.name = "LoadoutName"
		loadout.add_child(loadout_name)
		body_stack.add_child(loadout)

	# PORT: :589-605
	var action: Button = Button.new()
	action.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
	if is_equipped:
		action.name = "EquippedShip_" + ship.id
		action.theme_type_variation = "EquippedButton"
		action.text = "Equipped"
		action.disabled = true
	elif is_unlocked:
		action.name = "EquipShip_" + ship.id
		action.theme_type_variation = "SecondaryButton"
		action.text = "Equip"
		action.pressed.connect(_on_equip_ship_pressed.bind(ship.id))
	else:
		action.name = "BuyShip_" + ship.id
		action.theme_type_variation = "CostButton"
		action.text = format_points(ship.price)  # ArmoryShips.dc.html keeps the unit (Ruling K)
		action.disabled = not can_afford
		action.pressed.connect(_on_buy_ship_pressed.bind(ship.id))
	body_stack.add_child(action)
	body.add_child(body_stack)
	stack.add_child(body)
	card.add_child(stack)
	return card


## "HITBOX ▬▬▬──". DIVERGENCE(UI-SYSTEM): ArmoryShips.dc.html (label caps, 42 wide; 4 px meter)
func _meter_row(caption: String, meter_name: String, fraction: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(SHIP_BODY_GAP))
	var label: Label = UiTheme.caps(caption)
	label.custom_minimum_size.x = _px(SHIP_METER_LABEL)
	row.add_child(label)
	var meter: ProgressBar = UiTheme.meter(fraction, UiTheme.COLOR_ION, 0.0, _px(SHIP_METER_HEIGHT))
	meter.name = meter_name
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(meter)
	return row


## A caps caption with its one-line explanation (the boards' section heads),
## carrying the TS's pill text (Ruling M).
## DIVERGENCE(UI-SYSTEM): ArmoryShips.dc.html — caps caption + 13 px faint line, gap 12
func _caption_row(pill_name: String, pill: String, explain: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(SHIPS_GAP))
	var pill_label: Label = UiTheme.caps(pill)
	pill_label.name = pill_name
	pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(pill_label)
	if not explain.is_empty():
		var explain_label: Label = _one_line(explain, "BodyText")
		explain_label.add_theme_color_override("font_color", UiTheme.TEXT_FAINT)
		explain_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(explain_label)
	return row


## A horizontally scrolling row (the boards' overflow rows).
func _scroll_row(row_name: String, content: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = row_name
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


## PORT: web/src/tilt-to-live/ArmoryUI.ts:662-799
## DIVERGENCE(UI-SYSTEM): laid out to ArmoryArena.dc.html (interface spec §6.4).
func _render_arena_tab() -> Control:
	var points: int = progression.data.points
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "ArenaTab"
	column.add_theme_constant_override("separation", _px(ARENA_GAP))

	# 1. Arena themes. PORT: :666-717, :777-785
	var equipped_theme_id: String = progression.data.equipped_arena_theme_id
	var unlocked_themes: Array[String] = progression.data.unlocked_arena_themes
	var themes: Array[ProgressionManager.ArenaThemeConfig] = progression.arena_theme_catalog
	var unlocked_theme_count: int = 0
	for t: ProgressionManager.ArenaThemeConfig in themes:
		if unlocked_themes.has(t.id):
			unlocked_theme_count += 1
	column.add_child(
		_caption_row(
			"ThemesPill",
			"Arena Themes · %d of %d unlocked" % [unlocked_theme_count, themes.size()],
			""
		)
	)
	var themes_row: HBoxContainer = HBoxContainer.new()
	themes_row.add_theme_constant_override("separation", _px(ARENA_GAP))
	for theme_config: ProgressionManager.ArenaThemeConfig in themes:
		var preview: Control = _grid_lines(theme_config.grid_color)
		var edge: Panel = Panel.new()
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.add_theme_stylebox_override(
			"panel", UiTheme.flat(Color.TRANSPARENT, theme_config.boundary_color, 2)
		)  # DIVERGENCE(UI-SYSTEM): ArmoryArena.dc.html — edge r 2
		preview.add_child(edge)
		edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		edge.offset_left = _px(ARENA_EDGE_X)
		edge.offset_right = -_px(ARENA_EDGE_X)
		edge.offset_top = _px(ARENA_EDGE_Y)
		edge.offset_bottom = -_px(ARENA_EDGE_Y)
		themes_row.add_child(
			_arena_card_button(
				"Arena",
				theme_config.id,
				theme_config.name,
				theme_config.price,
				unlocked_themes.has(theme_config.id),
				equipped_theme_id == theme_config.id,
				points,
				preview
			)
		)
	column.add_child(_scroll_row("ThemesRow", themes_row))

	# 2. Enemy variations. PORT: :720-772, :788-796
	var equipped_enemy_id: String = progression.data.equipped_enemy_skin_id
	var unlocked_enemies: Array[String] = progression.data.unlocked_enemy_skins
	var enemies: Array[ProgressionManager.EnemySkinConfig] = progression.enemy_skin_catalog
	var unlocked_enemy_count: int = 0
	for s: ProgressionManager.EnemySkinConfig in enemies:
		if unlocked_enemies.has(s.id):
			unlocked_enemy_count += 1
	var enemies_caption: HBoxContainer = _caption_row(
		"EnemiesPill",
		"Enemy Variations · %d of %d unlocked" % [unlocked_enemy_count, enemies.size()],
		""
	)
	var caption_pad: MarginContainer = _pad(ENEMIES_TOP, 0, 0, 0)
	caption_pad.add_child(enemies_caption)
	column.add_child(caption_pad)
	var enemies_row: HBoxContainer = HBoxContainer.new()
	enemies_row.add_theme_constant_override("separation", _px(ARENA_GAP))
	for skin: ProgressionManager.EnemySkinConfig in enemies:
		# Three dots in the skin's body and rim; glow dropped (rule 02, interface spec §6.4).
		# PORT-NOTE: the body is the gradient's mid stop, as the M3 two-circle rule does.
		var dots: HBoxContainer = HBoxContainer.new()
		dots.alignment = BoxContainer.ALIGNMENT_CENTER
		dots.add_theme_constant_override("separation", _px(ENEMY_DOT_GAP))
		dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for dot_size: int in [ENEMY_DOT_LARGE, ENEMY_DOT_SMALL, ENEMY_DOT_LARGE]:
			var dot: Panel = Panel.new()
			dot.custom_minimum_size = Vector2.ONE * _px(dot_size)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.add_theme_stylebox_override(
				"panel",
				UiTheme.flat(skin.body_gradient[1], skin.border_color, int(_px(dot_size) / 2.0))
			)
			dots.add_child(dot)
		var preview: Control = Control.new()
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(dots)
		dots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		enemies_row.add_child(
			_arena_card_button(
				"Enemy",
				skin.id,
				skin.name,
				skin.price,
				unlocked_enemies.has(skin.id),
				equipped_enemy_id == skin.id,
				points,
				preview
			)
		)
	column.add_child(_scroll_row("EnemiesRow", enemies_row))

	var margin: MarginContainer = _pad(ARENA_PAD_TOP, 0, ARENA_PAD_BOTTOM, BODY_PAD_LEFT)
	margin.add_child(column)
	return _scroll_body(margin)


## One tappable arena/enemy card: a Card with a transparent CardButton laid over
## it. Tapping buys or equips, as the TS's buttons do (:677-693, :731-747).
## DIVERGENCE(UI-SYSTEM): ArmoryArena.dc.html
# The tap target is a Button over a PanelContainer rather than a Button holding
# the content: a Button is not a Container and would not size to its children,
# while a PanelContainer fits every child — the Button included — to its rect.
func _arena_card_button(
	kind: String,
	id: String,
	title: String,
	price: int,
	is_unlocked: bool,
	is_equipped: bool,
	points: int,
	preview: Control
) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = "%sCard_%s" % [kind, id]
	card.custom_minimum_size.x = _px(ARENA_CARD_WIDTH)
	card.add_theme_stylebox_override(
		"panel",
		UiTheme.flat(
			UiTheme.COLOR_PANEL,
			UiTheme.COLOR_LOCKED_IN if is_equipped else UiTheme.COLOR_LINE,
			_px(UiTheme.CARD_RADIUS)
		)
	)
	var tap: Button = Button.new()
	tap.theme_type_variation = "CardButton"
	var state_text: String = format_points(price)
	var state_color: Color = UiTheme.COLOR_FLARE
	if is_equipped:
		tap.name = "Equipped%s_%s" % [kind, id]
		tap.disabled = true
		state_text = "✓ Equipped"
		state_color = UiTheme.COLOR_LOCKED_IN
	elif is_unlocked:
		tap.name = "Equip%s_%s" % [kind, id]
		state_text = "Owned"
		state_color = UiTheme.COLOR_TEXT_MUTED
		if kind == "Arena":
			tap.pressed.connect(_on_equip_arena_pressed.bind(id))
		else:
			tap.pressed.connect(_on_equip_enemy_pressed.bind(id))
	else:
		tap.name = "Buy%s_%s" % [kind, id]
		tap.disabled = points < price
		if kind == "Arena":
			tap.pressed.connect(_on_buy_arena_pressed.bind(id))
		else:
			tap.pressed.connect(_on_buy_enemy_pressed.bind(id))

	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	# Preview fill + bottom hairline. DIVERGENCE(UI-SYSTEM): ArmoryArena.dc.html:30,:40
	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.custom_minimum_size.y = _px(ARENA_PREVIEW_HEIGHT)
	var preview_box: StyleBoxFlat = UiTheme.flat(UiTheme.COLOR_ARENA, UiTheme.COLOR_RAISED, 0)
	preview_box.set_border_width_all(0)
	preview_box.border_width_bottom = 1
	var card_radius: int = _px(UiTheme.CARD_RADIUS)
	preview_box.corner_radius_top_left = card_radius
	preview_box.corner_radius_top_right = card_radius
	preview_panel.add_theme_stylebox_override("panel", preview_box)
	preview_panel.add_child(preview)
	stack.add_child(preview_panel)
	var body: MarginContainer = _pad(
		ARENA_BODY_PAD_TOP, ARENA_BODY_PAD_X, ARENA_BODY_PAD_BOTTOM, ARENA_BODY_PAD_X
	)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines: VBoxContainer = VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", _px(ARENA_BODY_GAP))
	var name_label: Label = _one_line(title, "StrongText")
	name_label.add_theme_font_size_override("font_size", _px(ARENA_NAME_FONT))
	if not is_unlocked:
		name_label.add_theme_color_override("font_color", UiTheme.TEXT_SECONDARY)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(name_label)
	var state: Label = UiTheme.text(state_text, "MonoText")
	state.name = "%sState_%s" % [kind, id]
	state.add_theme_color_override("font_color", state_color)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(state)
	body.add_child(lines)
	stack.add_child(body)
	card.add_child(stack)
	card.add_child(tap)  # last: drawn and hit-tested above the content
	return card


## PORT: web/src/tilt-to-live/ArmoryUI.ts:805-880
## DIVERGENCE(UI-SYSTEM): laid out to ArmoryHandling.dc.html (interface spec §6.4).
func _render_handling_tab() -> Control:
	var tuning: ProgressionManager.SteeringTuning = progression.data.tuning

	var layout: HBoxContainer = HBoxContainer.new()
	layout.name = "HandlingTab"
	layout.add_theme_constant_override("separation", _px(HANDLING_COLUMN_GAP))

	# Left column: controls (Board 11). PORT: :811-860
	var controls: VBoxContainer = VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", _px(HANDLING_STACK_GAP))
	controls.add_child(
		_handling_field(
			"Turn rate",
			"TurnValue",
			"%.1f×" % tuning.sensitivity,  # PORT: :816
			"Higher turns sharper.",
			"TurnSlider",
			[TURN_MIN, TURN_MAX, TURN_STEP, tuning.sensitivity],
			_on_turn_rate_changed
		)
	)
	if _settings != null:
		# DIVERGENCE(UI-SYSTEM): ArmoryHandling.dc.html — label and hint copy.
		controls.add_child(
			_handling_field(
				"Tilt sensitivity",
				"TiltValue",
				"%.1f×" % _settings.tilt_sensitivity,
				"Less wrist for full speed.",
				"TiltSlider",
				[TILT_MIN, TILT_MAX, TILT_STEP, _settings.tilt_sensitivity],
				_on_tilt_sensitivity_changed
			)
		)
	var fill: Control = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(fill)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", _px(HANDLING_ROW_GAP))
	var calibrate: Button = Button.new()  # interface spec §5
	calibrate.name = "CalibrateTiltButton"
	calibrate.theme_type_variation = "SecondaryButton"
	calibrate.text = "Calibrate tilt"
	calibrate.icon = UiTheme.svg_texture(UiTheme.ICON_CALIBRATE, _ui_scale)
	calibrate.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
	calibrate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calibrate.pressed.connect(_on_calibrate_pressed)
	actions.add_child(calibrate)
	var reset: Button = Button.new()  # PORT: :859
	reset.name = "ResetButton"
	reset.theme_type_variation = "SecondaryButton"
	reset.text = "Reset"
	reset.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_MUTED)  # ArmoryHandling.dc.html
	reset.custom_minimum_size.y = _px(UiTheme.TOUCH_TARGET)
	reset.pressed.connect(_on_handling_reset_pressed)
	actions.add_child(reset)
	controls.add_child(actions)
	layout.add_child(controls)

	# Right column: interactive live preview (Board 11). PORT: :863-877
	var preview_column: VBoxContainer = VBoxContainer.new()
	preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_column.add_theme_constant_override("separation", _px(HANDLING_ROW_GAP))
	preview_column.add_child(UiTheme.caps("Live preview — tilt or drag"))  # interface spec §6.4
	var box: PanelContainer = PanelContainer.new()  # PORT: :865
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_ARENA, UiTheme.COLOR_LINE, _px(PREVIEW_RADIUS))
	)
	# PORT-NOTE: render() rebuilds the whole tab, so a new HandlingPreview is
	# instanced every time this tab is (re)rendered — see the M8 note this
	# replaces (final review finding 4); unchanged by M8.5.
	_preview = HandlingPreview.new()
	_preview.name = "HandlingPreview"
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_preview)
	preview_column.add_child(box)
	# The legend is an overlay inside the box (ArmoryHandling.dc.html). PORT: :868-875
	var legend: HBoxContainer = HBoxContainer.new()
	legend.name = "PreviewLegend"
	legend.add_theme_constant_override("separation", _px(LEGEND_GAP))
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_child(_legend_item(HandlingPreview.DEADZONE_COLOR, "still"))  # interface spec §6.4
	legend.add_child(_legend_item(HandlingPreview.TOP_SPEED_COLOR, "top speed"))
	_preview.add_child(legend)
	legend.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	legend.grow_vertical = Control.GROW_DIRECTION_BEGIN
	legend.offset_left = _px(LEGEND_LEFT)
	legend.offset_bottom = -_px(LEGEND_BOTTOM)
	layout.add_child(preview_column)

	var margin: MarginContainer = _pad(BODY_PAD_TOP, BODY_PAD_RIGHT, BODY_PAD_BOTTOM, BODY_PAD_LEFT)
	margin.add_child(layout)
	return _scroll_body(margin)


## PORT: web/src/tilt-to-live/ArmoryUI.ts:889-937
## DIVERGENCE(UI-SYSTEM): laid out to ArmoryBoosts.dc.html (interface spec §6.4).
func _render_boosts_tab() -> Control:
	var points: int = progression.data.points
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "BoostsTab"
	column.add_theme_constant_override("separation", _px(BOOSTS_GAP))
	# PORT: :928-931
	column.add_child(_caption_row("BoostsPill", "Boosts", "Permanent. They stack into every run."))

	var grid: GridContainer = GridContainer.new()  # PORT: :932-934
	grid.columns = BOOST_COLUMNS
	grid.add_theme_constant_override("h_separation", _px(BOOST_GRID_GAP))
	grid.add_theme_constant_override("v_separation", _px(BOOST_GRID_GAP))
	for boost: BoostConfig in boosts_catalog:
		# PORT-NOTE: Callable.call() always returns Variant in GDScript 4.7.2,
		# even though get_rank/get_cost are typed `func() -> int` closures —
		# Callable carries no generic signature. Narrowed with `is int` rather
		# than cast, matching tilt_input.gd:353 and save_store.gd:66-68.
		var rank_value: Variant = boost.get_rank.call()
		var current_rank: int = 0
		if rank_value is int:
			current_rank = rank_value
		var cost_value: Variant = boost.get_cost.call()
		var cost: int = 0
		if cost_value is int:
			cost = cost_value
		var is_maxed: bool = cost == Types.ABSENT  # PORT: :896 (cost === null)
		var can_afford: bool = not is_maxed and points >= cost

		var card: PanelContainer = PanelContainer.new()  # PORT: :906-921
		card.name = "BoostCard_" + boost.id
		card.theme_type_variation = "Card"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = _px(BOOST_CARD_HEIGHT)
		var inner: MarginContainer = _pad(0, BOOST_PAD_RIGHT, 0, BOOST_PAD_LEFT)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", _px(BOOST_CARD_GAP))
		var text_stack: VBoxContainer = VBoxContainer.new()
		text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		text_stack.add_theme_constant_override("separation", _px(BOOST_STACK_GAP))
		var names: HBoxContainer = HBoxContainer.new()
		names.add_theme_constant_override("separation", _px(BOOST_NAME_GAP))
		names.add_child(_one_line(boost.name, "StrongText"))
		var effect: Label = _one_line(boost.effect, "MonoText")
		effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_child(effect)
		text_stack.add_child(names)
		var pips: HBoxContainer = UiTheme.pips(current_rank, boost.max_rank, _ui_scale)  # PORT: :899-903
		pips.name = "BoostPips_" + boost.id
		pips.custom_minimum_size.x = _px(BOOST_PIPS_WIDTH)
		pips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		text_stack.add_child(pips)
		row.add_child(text_stack)
		var buy: Button = Button.new()  # PORT: :913-920
		buy.name = "Boost_" + boost.id
		buy.theme_type_variation = "CostButton"
		buy.custom_minimum_size = Vector2(_px(BOOST_COST_WIDTH), _px(UiTheme.TOUCH_TARGET))
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.disabled = is_maxed or not can_afford
		buy.text = "Max" if is_maxed else UiTheme.group_digits(cost)  # Ruling K
		buy.pressed.connect(_on_boost_pressed.bind(boost.id))
		row.add_child(buy)
		inner.add_child(row)
		card.add_child(inner)
		grid.add_child(card)
	column.add_child(grid)

	var margin: MarginContainer = _pad(BODY_PAD_TOP, BODY_PAD_RIGHT, BODY_PAD_BOTTOM, BODY_PAD_LEFT)
	margin.add_child(column)
	return _scroll_body(margin)


## PORT: web/src/tilt-to-live/ArmoryUI.ts:943-1106 — the body is HandlingPreview.start().
func _init_handling_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.start(progression)


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1108-1113
func _stop_handling_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.stop()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1134-1142
# PORT-NOTE: the TS skips render() when the tapped tab is already active
# (:1137). A toggle Button un-presses itself on a second tap, so render() runs
# unconditionally here to re-assert button_pressed; the visible result is the
# same.
func _on_tab_pressed(tab: Tab) -> void:
	if tab != active_tab:
		active_tab = tab
	render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1145-1153
# PORT-NOTE: the TS skips render() when the tapped weapon is already selected
# (:1148-1150). A toggle Button un-presses itself on a second tap, so render() runs
# unconditionally here to re-assert button_pressed; the visible result is the
# same.
func _on_weapon_item_pressed(id: String) -> void:
	if id != selected_weapon_id:
		selected_weapon_id = id
	render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1156-1168
func _on_track_pressed(weapon: String, track: String) -> void:
	if progression.upgrade_perk(weapon, track):
		state_changed.emit()
		render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1171-1183
func _on_keystone_pressed(weapon: String, keystone: String) -> void:
	if progression.upgrade_perk(weapon, keystone):
		state_changed.emit()
		render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1186-1196
func _on_boost_pressed(boost_id: String) -> void:
	for boost: BoostConfig in boosts_catalog:
		if boost.id == boost_id:
			if boost.buy.call():
				state_changed.emit()
				render()
			return


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1199-1207
func _on_buy_ship_pressed(id: String) -> void:
	if progression.buy_ship(id):
		state_changed.emit()
		render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1209-1217
func _on_equip_ship_pressed(id: String) -> void:
	if progression.equip_ship(id):
		state_changed.emit()
		render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1220-1228
func _on_buy_arena_pressed(id: String) -> void:
	if progression.buy_arena_theme(id):
		state_changed.emit()
		render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1230-1238
func _on_equip_arena_pressed(id: String) -> void:
	if progression.equip_arena_theme(id):
		state_changed.emit()
		render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1241-1249
func _on_buy_enemy_pressed(id: String) -> void:
	if progression.buy_enemy_skin(id):
		state_changed.emit()
		render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1251-1259
func _on_equip_enemy_pressed(id: String) -> void:
	if progression.equip_enemy_skin(id):
		state_changed.emit()
		render()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1262-1271 — updates the pill in place, no render().
func _on_turn_rate_changed(value: float) -> void:
	progression.set_sensitivity(value)
	var disp: Label = find_child("TurnValue", true, false) as Label
	if disp != null:
		disp.text = "%.1f×" % value
	state_changed.emit()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1274-1283
# PORT-NOTE: no control calls this since M8.5 — deadzone left the UI (interface
# spec §6.4, ruled); kept so the handlers still read in ArmoryUI.ts's order
# (LAW 3). The value keeps its saved setting and stays in effect.
func _on_deadzone_changed(value: float) -> void:
	progression.set_deadzone(value)
	var disp: Label = find_child("DeadzoneValue", true, false) as Label
	if disp != null:
		disp.text = "%dpx" % int(value)
	state_changed.emit()


## The tilt slider (interface spec §6.4, ruled 2026-09-23). Updates the value in
## place without render(), as the turn slider does (:1262-1271).
func _on_tilt_sensitivity_changed(value: float) -> void:
	_settings.tilt_sensitivity = value
	_settings.save_settings()
	var disp: Label = find_child("TiltValue", true, false) as Label
	if disp != null:
		disp.text = "%.1f×" % value
	state_changed.emit()


## Handling's "Calibrate tilt" (interface spec §5).
func _on_calibrate_pressed() -> void:
	calibrate_requested.emit()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1286-1291
func _on_handling_reset_pressed() -> void:
	progression.set_sensitivity(DEFAULT_SENSITIVITY)
	progression.set_deadzone(DEFAULT_DEADZONE)
	# Ruling O: the tilt slider resets to ControlSettings' default too.
	if _settings != null:
		_settings.tilt_sensitivity = DEFAULT_TILT_SENSITIVITY
		_settings.save_settings()
	state_changed.emit()
	render()


## A base size at the current ui_scale.
func _px(base: float) -> int:
	return UiTheme.px(base, _ui_scale)


## A MarginContainer with per-side board padding, in CSS order.
func _pad(top: int, right: int, bottom: int, left: int) -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_top", _px(top))
	m.add_theme_constant_override("margin_right", _px(right))
	m.add_theme_constant_override("margin_bottom", _px(bottom))
	m.add_theme_constant_override("margin_left", _px(left))
	return m


## One idea per line: a Label that clips with an ellipsis (System.dc.html rule 03).
## Clipping floors the minimum width at 1 px; a caller placing it in an HBox
## alongside other content (as _weapon_list does) must also set
## size_flags_horizontal = Control.SIZE_EXPAND_FILL or it collapses to 1 px.
func _one_line(content: String, variation: String) -> Label:
	var label: Label = UiTheme.text(content, variation)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	return label


## One slider field: label + value, hint, 40 px slider, min/max row.
## PORT: web/src/tilt-to-live/ArmoryUI.ts:813-832 (structure).
## `range_value` is [min, max, step, value]; gdlint caps a function at 10 arguments.
func _handling_field(
	label: String,
	value_name: String,
	value_text: String,
	hint: String,
	slider_name: String,
	range_value: Array[float],
	on_changed: Callable
) -> VBoxContainer:
	var field: VBoxContainer = VBoxContainer.new()
	field.add_theme_constant_override("separation", _px(HANDLING_FIELD_GAP))
	var header: HBoxContainer = HBoxContainer.new()
	var name_label: Label = UiTheme.text(label, "FieldText")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var value: Label = UiTheme.text(value_text, "MonoText")
	value.name = value_name
	value.add_theme_font_override("font", UiTheme.mono(UiTheme.Weight.MEDIUM))
	value.add_theme_font_size_override("font_size", _px(HANDLING_VALUE_FONT))
	value.add_theme_color_override("font_color", UiTheme.COLOR_ION)
	header.add_child(value)
	field.add_child(header)
	field.add_child(_one_line(hint, "HintText"))
	var slider: HSlider = HSlider.new()
	slider.name = slider_name
	slider.min_value = range_value[0]
	slider.max_value = range_value[1]
	slider.step = range_value[2]
	slider.value = range_value[3]
	slider.custom_minimum_size.y = _px(HANDLING_SLIDER_HEIGHT)
	slider.value_changed.connect(on_changed)
	field.add_child(slider)
	var bounds: HBoxContainer = HBoxContainer.new()  # PORT: :828-831
	var low: Label = UiTheme.text("%.1f×" % range_value[0], "MonoFaintText")
	low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bounds.add_child(low)
	bounds.add_child(UiTheme.text("%.1f×" % range_value[1], "MonoFaintText"))
	field.add_child(bounds)
	return field


## A legend item. DIVERGENCE(UI-SYSTEM): ArmoryHandling.dc.html (8 px ring, gap 6, Mono 11)
func _legend_item(color: Color, text: String) -> HBoxContainer:
	var item: HBoxContainer = HBoxContainer.new()
	item.add_theme_constant_override("separation", _px(LEGEND_GLYPH_GAP))
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph: Panel = Panel.new()
	glyph.custom_minimum_size = Vector2.ONE * _px(LEGEND_GLYPH)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.add_theme_stylebox_override(
		"panel", UiTheme.flat(Color.TRANSPARENT, color, int(_px(LEGEND_GLYPH) / 2.0))
	)
	item.add_child(glyph)
	item.add_child(UiTheme.text(text, "MonoFaintText"))
	return item


## The preview's 12 px grid. DIVERGENCE(UI-SYSTEM): ArmoryArena.dc.html
# PORT-NOTE: a repeating linear-gradient background; drawn as lines by a
# small _draw() Control built inline, sampled at ARENA_GRID_STEP.
func _grid_lines(color: Color) -> Control:
	var lines: ArenaGridLines = ArenaGridLines.new()
	lines.color = color
	lines.step = ARENA_GRID_STEP * _ui_scale
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lines


## A 1 px vertical rule in raised (the list's border-right).
## DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html
func _vrule() -> ColorRect:
	return UiTheme.hairline(true, UiTheme.COLOR_RAISED)


## Wraps a Control in the tab's scrolling body (.armory-scroll-body, game.css:1768).
func _scroll_body(inner: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ScrollBody"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	return scroll


## .weapon-icon-box tinted by the weapon's dot. PORT: web/src/tilt-to-live/ArmoryUI.ts:541-543
## DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — 44 box, 10% / 35% tint, 22 icon.
func _icon_box(config: WeaponConfig) -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	var inset: float = _px(ICON_BOX - ICON_SIZE) / 2.0  # PORT-NOTE: half the size — radius / centring
	box.add_theme_stylebox_override(
		"panel",
		UiTheme.padded(
			UiTheme.flat(
				UiTheme.tint(config.dot, ICON_BOX_FILL_ALPHA),
				UiTheme.tint(config.dot, ICON_BOX_BORDER_ALPHA),
				_px(UiTheme.CARD_RADIUS)
			),
			inset,
			inset
		)
	)
	box.custom_minimum_size = Vector2.ONE * _px(ICON_BOX)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon: TextureRect = TextureRect.new()
	icon.texture = UiTheme.svg_texture(config.icon_svg, SVG_OVERSAMPLE * _ui_scale)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2.ONE * _px(ICON_SIZE)
	box.add_child(icon)
	return box


## PORT-NOTE: the TS's inline-SVG-in-HTML strings carry `aria-hidden` and no
## `xmlns` (the host document supplies the SVG namespace). Godot's rasteriser
## has no host document, so `xmlns="http://www.w3.org/2000/svg"` is added and
## `aria-hidden` (meaningless off the DOM) is dropped from every icon below.
## PORT: web/src/tilt-to-live/ArmoryUI.ts:96-203
func _build_weapons_catalog() -> Array[WeaponConfig]:
	var out: Array[WeaponConfig] = []
	# PORT: :97-112
	(
		out
		. append(
			_weapon(
				"blackhole",
				"Blackhole",
				Color("#A78BFA"),
				"Drags dots in, then collapses.",
				(
					'<svg width="30" height="30" viewBox="0 0 30 30" fill="none" '
					+ 'xmlns="http://www.w3.org/2000/svg">'
					+ '<circle cx="15" cy="15" r="11" stroke="#A78BFA" stroke-width="1.4"></circle>'
					+ '<circle cx="15" cy="15" r="5" fill="#A78BFA"></circle></svg>'
				),
				[
					_track("duration", "Duration", "+0.5s / rank"),
					_track("radius", "Radius", "+18 range / rank"),
					_track("gravity", "Pull", "+20% / rank"),
				],
				[
					_keystone("invulnerableInside", "Aegis", "You are safe inside the well."),
					_keystone(
						"supernovaCollapse", "Supernova", "Collapse fires a 320 range shockwave."
					),
				]
			)
		)
	)
	# PORT: :113-128
	(
		out
		. append(
			_weapon(
				"missiles",
				"Missiles",
				Color("#5B8CFF"),
				"Swarm homing warheads track and annihilate dots.",
				(
					'<svg width="30" height="30" viewBox="0 0 30 30" fill="none" '
					+ 'xmlns="http://www.w3.org/2000/svg">'
					+ '<path d="M15 4 L20 12 L19 22 L15 20 L11 22 L10 12 Z" stroke="#5B8CFF" '
					+ 'stroke-width="1.4" fill="rgba(91,140,255,0.2)"></path>'
					+ '<circle cx="15" cy="11" r="2.5" fill="#5B8CFF"></circle></svg>'
				),
				[
					_track("count", "Salvo Count", "+1 missile / rank"),
					_track("blastRadius", "Detonation Radius", "+6 range / rank"),
					_track("flightSpeed", "Propulsion", "+20% / rank"),
				],
				[
					_keystone(
						"clusterSplit", "Cluster Split", "Warheads divide into twins on intercept."
					),
					_keystone(
						"hyperThrusters",
						"Hyper Thrusters",
						"Instant target lock and hypersonic velocity."
					),
				]
			)
		)
	)
	# PORT: :129-143
	(
		out
		. append(
			_weapon(
				"laser",
				"Laser",
				Color("#5B8CFF"),
				"Continuous piercing beam sweeps through swarms.",
				(
					'<svg width="30" height="30" viewBox="0 0 30 30" fill="none" '
					+ 'xmlns="http://www.w3.org/2000/svg">'
					+ '<line x1="4" y1="15" x2="26" y2="15" stroke="#5B8CFF" stroke-width="2.5" '
					+ 'stroke-linecap="round"></line>'
					+ '<line x1="8" y1="9" x2="22" y2="21" stroke="#5B8CFF" stroke-width="1.2" '
					+ 'stroke-dasharray="2,3"></line></svg>'
				),
				[
					_track("length", "Beam Reach", "+20 range / rank"),
					_track("duration", "Emission Time", "+0.4s / rank"),
				],
				[
					_keystone(
						"crossBeam", "Cross Beam", "Splits beam into 4-way perpendicular cross."
					),
					_keystone(
						"refractorLance",
						"Refractor Lance",
						"Beams bounce off arena perimeter walls."
					),
				]
			)
		)
	)
	# PORT: :144-158
	(
		out
		. append(
			_weapon(
				"nuke",
				"Nuke",
				Color("#FFB14D"),
				"Instantaneous arena-clearing shockwave explosion.",
				(
					'<svg width="30" height="30" viewBox="0 0 30 30" fill="none" '
					+ 'xmlns="http://www.w3.org/2000/svg">'
					+ '<circle cx="15" cy="15" r="11" stroke="#FFB14D" stroke-width="1.4"></circle>'
					+ '<path d="M15 7 L15 11 M9 20 L12 17 M21 20 L18 17" stroke="#FFB14D" '
					+ 'stroke-width="2" stroke-linecap="round"></path>'
					+ '<circle cx="15" cy="15" r="3" fill="#FFB14D"></circle></svg>'
				),
				[
					_track("radius", "Blast Radius", "+22 range / rank"),
					_track("speed", "Shockwave Velocity", "+25% / rank"),
				],
				[
					_keystone(
						"falloutZone",
						"Fallout Zone",
						"Detonation leaves a 3.0s radioactive burn zone."
					),
					_keystone(
						"chainReaction",
						"Chain Reaction",
						"Vaporized dots trigger miniature secondary bombs."
					),
				]
			)
		)
	)
	# PORT: :159-172
	(
		out
		. append(
			_weapon(
				"freeze",
				"Shockwave",
				Color("#8FB0FF"),
				"Flash-freezes all dots into shatterable crystals.",
				(
					'<svg width="30" height="30" viewBox="0 0 30 30" fill="none" '
					+ 'xmlns="http://www.w3.org/2000/svg">'
					+ '<circle cx="15" cy="15" r="11" stroke="#8FB0FF" stroke-width="1.4" '
					+ 'stroke-dasharray="4,3"></circle>'
					+ '<path d="M15 5 L15 25 M5 15 L25 15 M8 8 L22 22 M8 22 L22 8" stroke="#8FB0FF" '
					+ 'stroke-width="1.3"></path></svg>'
				),
				[_track("duration", "Freeze Duration", "+0.7s / rank")],
				[
					_keystone(
						"shatterCascade",
						"Shatter Cascade",
						"Shattering one enemy destroys nearby frozen dots."
					),
					_keystone(
						"cryoNova", "Cryo Nova", "Emits an expansive 360° cryogenic pulse ring."
					),
				]
			)
		)
	)
	# PORT: :173-187
	(
		out
		. append(
			_weapon(
				"shield",
				"Shield",
				Color("#3DDC97"),
				"Kinetic barrier allowing safe ramming through enemies.",
				(
					'<svg width="30" height="30" viewBox="0 0 30 30" fill="none" '
					+ 'xmlns="http://www.w3.org/2000/svg">'
					+ '<path d="M15 5 L23 8 V15 C23 20 15 25 15 25 C15 25 7 20 7 15 V8 Z" '
					+ 'stroke="#3DDC97" stroke-width="1.4" fill="rgba(61,220,151,0.15)"></path></svg>'
				),
				[
					_track("duration", "Shield Duration", "+1.0s / rank"),
					_track("radius", "Bubble Radius", "+2 range / rank"),
				],
				[
					_keystone(
						"batteringRam",
						"Battering Ram",
						"Ramming enemies triggers kinetic shockwaves."
					),
					_keystone(
						"overchargePulse",
						"Overcharge",
						"Releases a blast pulse when barrier expires."
					),
				]
			)
		)
	)
	# PORT: :188-202
	(
		out
		. append(
			_weapon(
				"lightning",
				"Lightning",
				Color("#FFB14D"),
				"Arcs jump between dots in high-voltage cascade.",
				(
					'<svg width="30" height="30" viewBox="0 0 30 30" fill="none" '
					+ 'xmlns="http://www.w3.org/2000/svg">'
					+ '<path d="M17 4 L9 16 H16 L13 26 L23 13 H15 Z" stroke="#FFB14D" '
					+ 'stroke-width="1.4" fill="rgba(255,177,77,0.2)"></path></svg>'
				),
				[
					_track("maxTargets", "Arc Targets", "+3 targets / rank"),
					_track("chainRange", "Chain Distance", "+22 range / rank"),
				],
				[
					_keystone(
						"plasmaArc", "Arc Detonation", "Chained enemies explode upon electrocution."
					),
					_keystone(
						"superconductor",
						"Superconductor",
						"Electric arcs bridge across screen instantly."
					),
				]
			)
		)
	)
	return out


## PORT: web/src/tilt-to-live/ArmoryUI.ts:222-268
func _build_boosts_catalog() -> Array[BoostConfig]:
	var out: Array[BoostConfig] = []
	# PORT: :223-231
	out.append(
		_boost(
			"extraLives",
			"Extra Life",
			"+1 starting life / rank",
			2,
			func() -> int: return progression.data.extra_lives,
			func() -> int: return progression.get_extra_lives_cost(),
			func() -> bool: return progression.buy_extra_life()
		)
	)
	# PORT: :232-240
	out.append(
		_boost(
			"hullCompact",
			"Hull Compact",
			"-6% hitbox / rank",
			3,
			func() -> int: return progression.data.hull_compact,
			func() -> int: return progression.get_hull_compact_cost(),
			func() -> bool: return progression.buy_hull_compact()
		)
	)
	# PORT: :241-249
	out.append(
		_boost(
			"enemySlow",
			"Enemy Slow",
			"-4% enemy speed / rank",
			3,
			func() -> int: return progression.data.enemy_slow,
			func() -> int: return progression.get_enemy_slow_cost(),
			func() -> bool: return progression.buy_enemy_slow()
		)
	)
	# PORT: :250-258
	out.append(
		_boost(
			"scoreMultiplier",
			"Score Multiplier",
			"+10% in-run score / rank",
			4,
			func() -> int: return progression.data.score_multiplier,
			func() -> int: return progression.get_score_multiplier_cost(),
			func() -> bool: return progression.buy_score_multiplier()
		)
	)
	# PORT: :259-267
	out.append(
		_boost(
			"pointsMultiplier",
			"Points Multiplier",
			"+10% points earned / rank",
			4,
			func() -> int: return progression.data.points_multiplier,
			func() -> int: return progression.get_points_multiplier_cost(),
			func() -> bool: return progression.buy_points_multiplier()
		)
	)
	return out


func _boost(
	id: String,
	name: String,
	effect: String,
	max_rank: int,
	get_rank: Callable,
	get_cost: Callable,
	buy: Callable
) -> BoostConfig:
	var b: BoostConfig = BoostConfig.new()
	b.id = id
	b.name = name
	b.effect = effect
	b.max_rank = max_rank
	b.get_rank = get_rank
	b.get_cost = get_cost
	b.buy = buy
	return b


## Every track in the TS catalog has maxRank 5 (:104-196).
func _track(key: String, name: String, effect: String) -> WeaponTrack:
	var t: WeaponTrack = WeaponTrack.new()
	t.key = key
	t.name = name
	t.effect = effect
	t.max_rank = 5  # PORT: web/src/tilt-to-live/ArmoryUI.ts:104
	return t


func _keystone(key: String, name: String, description: String) -> WeaponKeystone:
	var k: WeaponKeystone = WeaponKeystone.new()
	k.key = key
	k.name = name
	k.description = description
	return k


func _weapon(
	id: String,
	name: String,
	dot: Color,
	description: String,
	icon_svg: String,
	tracks: Array[WeaponTrack],
	keystones: Array[WeaponKeystone]
) -> WeaponConfig:
	var w: WeaponConfig = WeaponConfig.new()
	w.id = id
	w.name = name
	w.dot = dot
	w.description = description
	w.icon_svg = icon_svg
	w.tracks = tracks
	w.keystones = keystones
	return w


## PORT: web/src/tilt-to-live/ArmoryUI.ts:22-27
class WeaponTrack:
	extends RefCounted
	var key: String = ""
	var name: String = ""
	var effect: String = ""
	var max_rank: int = 0


## PORT: web/src/tilt-to-live/ArmoryUI.ts:29-33
class WeaponKeystone:
	extends RefCounted
	var key: String = ""
	var name: String = ""
	var description: String = ""


## PORT: web/src/tilt-to-live/ArmoryUI.ts:35-43
class BoostConfig:
	extends RefCounted
	var id: String = ""
	var name: String = ""
	var effect: String = ""
	var max_rank: int = 0
	## func() -> int
	var get_rank: Callable = Callable()
	## func() -> int; Types.ABSENT stands for the TS null
	var get_cost: Callable = Callable()
	## func() -> bool
	var buy: Callable = Callable()


## PORT: web/src/tilt-to-live/ArmoryUI.ts:59-67
class WeaponConfig:
	extends RefCounted
	## A WeaponPerks key: blackhole, missiles, laser, nuke, freeze, shield, lightning.
	var id: String = ""
	var name: String = ""
	var dot: Color = Color.WHITE
	var description: String = ""
	## The TS <svg> markup verbatim, rasterised by svg_texture().
	var icon_svg: String = ""
	var tracks: Array[WeaponTrack] = []
	var keystones: Array[WeaponKeystone] = []


## The .arena-grid-lines overlay. PORT: web/src/styles/game.css:2501-2508
class ArenaGridLines:
	extends Control
	var color: Color = Color.WHITE
	var step: float = 18.0

	func _draw() -> void:
		var x: float = 0.0
		while x < size.x:
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), color, 1.0)
			x += step
		var y: float = 0.0
		while y < size.y:
			draw_line(Vector2(0.0, y), Vector2(size.x, y), color, 1.0)
			y += step
