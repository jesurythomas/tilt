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
## PORT-NOTE: scenes/armory.tscn carries the layout the TS expresses in
## game.css; a .tscn cannot hold comments, so its literals are cited here:
## overlay rgba(8,9,14,0.88) :1607 and 20px padding :1609; header gap 20 :1631;
## tab gap 4 :1676; header-right gap 16 :1714; header rule #262C38 :1633;
## footer padding 12/16/20 :2790; Play height 50 :2801; hidden tab scrollbar
## :1679-1684.
##
## DIVERGENCE(spec §8 M8): game.css:2817-2911 switches to the mobile chrome
## (edge-to-edge panel, back button instead of close, sticky Play footer) at
## an 820 CSS-px width. There is no CSS px here; the switch is gated on
## OS.has_feature("mobile"), and the edge-to-edge panel is inset by
## GameRoot.arena_origin so it stays inside the landscape safe area (spec §8
## M8 acceptance).

## onStateChanged (ArmoryUI.ts:76): after every successful purchase, equip or
## tuning change.
signal state_changed
## onCloseModal (ArmoryUI.ts:77): after close().
signal closed

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
var _ui_scale: float = 1.0
var _tab_buttons: Array[Button] = []

@onready var _panel_margin: MarginContainer = %PanelMargin
@onready var _header_margin: MarginContainer = %HeaderMargin
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _tabs: HBoxContainer = %Tabs
@onready var _balance_label: Label = %BalanceLabel
@onready var _close_button: Button = %CloseButton
@onready var _body: MarginContainer = %Body
@onready var _sticky_footer: MarginContainer = %StickyFooter
@onready var _play_button: Button = %PlayButton


func _ready() -> void:
	visible = false
	var is_mobile: bool = OS.has_feature("mobile")
	# DIVERGENCE(spec §8 M8): see the class doc. PORT: game.css:2836, :2840, :2908
	_back_button.visible = is_mobile
	_close_button.visible = not is_mobile
	_sticky_footer.visible = is_mobile

	# PORT: web/src/tilt-to-live/ArmoryUI.ts:1123-1131
	_close_button.pressed.connect(close)
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

	set_ui_scale(1.0)


## Constructor half. PORT: web/src/tilt-to-live/ArmoryUI.ts:270-280
func bind(p: ProgressionManager) -> void:
	progression = p


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
	_balance_label.text = format_points(points)  # PORT: :363
	for i: int in range(_tab_buttons.size()):
		_tab_buttons[i].button_pressed = (i as Tab) == active_tab  # PORT: :353-357

	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_body.add_child(_render_tab_content())

	if active_tab == Tab.HANDLING:
		_init_handling_preview()

	var new_scroll: ScrollContainer = find_child("ScrollBody", true, false) as ScrollContainer
	if new_scroll != null and prev_scroll_top > 0:
		new_scroll.set_deferred("scroll_vertical", prev_scroll_top)  # PORT: :391-394


## Scales fonts, paddings and touch targets to the viewport (HudController's ui_scale).
func set_ui_scale(scale: float) -> void:
	_ui_scale = scale
	theme = ArmoryTheme.build(scale)
	var is_mobile: bool = OS.has_feature("mobile")
	# PORT: game.css:1609 (20px) and :2819 (0 on mobile — the panel is inset
	# by arena_origin instead; see GameRoot.open_armory).
	var pad: int = 0 if is_mobile else int(20 * scale)
	_panel_margin.add_theme_constant_override("margin_left", pad)
	_panel_margin.add_theme_constant_override("margin_top", pad)
	_panel_margin.add_theme_constant_override("margin_right", pad)
	_panel_margin.add_theme_constant_override("margin_bottom", pad)
	var pad_y: int = ArmoryTheme.HEADER_PAD_Y_MOBILE if is_mobile else ArmoryTheme.HEADER_PAD_Y
	var pad_x: int = ArmoryTheme.HEADER_PAD_X_MOBILE if is_mobile else ArmoryTheme.HEADER_PAD_X
	_header_margin.add_theme_constant_override("margin_left", int(pad_x * scale))
	_header_margin.add_theme_constant_override("margin_top", int(pad_y * scale))
	_header_margin.add_theme_constant_override("margin_right", int(pad_x * scale))
	_header_margin.add_theme_constant_override("margin_bottom", int(pad_y * scale))
	var icon: float = ArmoryTheme.ICON_BUTTON * scale
	_back_button.custom_minimum_size = Vector2(icon, icon)
	_close_button.custom_minimum_size = Vector2(icon, icon)
	for button: Button in _tab_buttons:
		# The M2.5 §4.3 48dp touch target (ControlPicker.BASE_TOUCH_TARGET).
		button.custom_minimum_size.y = ControlPicker.BASE_TOUCH_TARGET * scale
	_play_button.custom_minimum_size.y = ArmoryTheme.PLAY_BUTTON_HEIGHT * scale
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
# PORT-NOTE: toLocaleString() groups by the browser locale; en-US commas are
# fixed here — Godot has no locale-aware number formatter.
static func format_points(n: int) -> String:
	var digits: String = str(n)
	var grouped: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	return "%s %s" % [grouped, "pt" if n == 1 else "pts"]


## Rasterises one of the TS's SVG strings (Image.load_svg_from_string, 4.7.2).
static func svg_texture(svg: String, scale: float) -> ImageTexture:
	var image: Image = Image.new()
	var err: int = image.load_svg_from_string(svg, scale)
	if err != OK:
		Log.warn("ArmoryUI: svg rasterisation failed (%d)" % err)
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)


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


## Task 2 replaces this. PORT: web/src/tilt-to-live/ArmoryUI.ts:416-569
func _render_weapons_tab() -> Control:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "WeaponsTab"
	return tab


## Task 3 replaces this. PORT: web/src/tilt-to-live/ArmoryUI.ts:575-656
func _render_ships_tab() -> Control:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "ShipsTab"
	return tab


## Task 4 replaces this. PORT: web/src/tilt-to-live/ArmoryUI.ts:662-799
func _render_arena_tab() -> Control:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "ArenaTab"
	return tab


## Task 6 replaces this. PORT: web/src/tilt-to-live/ArmoryUI.ts:805-880
func _render_handling_tab() -> Control:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "HandlingTab"
	return tab


## Task 5 replaces this. PORT: web/src/tilt-to-live/ArmoryUI.ts:889-937
func _render_boosts_tab() -> Control:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "BoostsTab"
	return tab


## Task 6 replaces this. PORT: web/src/tilt-to-live/ArmoryUI.ts:943-1106
func _init_handling_preview() -> void:
	pass


## Task 6 replaces this. PORT: web/src/tilt-to-live/ArmoryUI.ts:1108-1113
func _stop_handling_preview() -> void:
	pass


## PORT: web/src/tilt-to-live/ArmoryUI.ts:1134-1142
# PORT-NOTE: the TS skips render() when the tapped tab is already active
# (:1137). A toggle Button un-presses itself on a second tap, so render() runs
# unconditionally here to re-assert button_pressed; the visible result is the
# same.
func _on_tab_pressed(tab: Tab) -> void:
	if tab != active_tab:
		active_tab = tab
	render()


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
