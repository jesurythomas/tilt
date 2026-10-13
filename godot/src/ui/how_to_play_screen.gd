## how_to_play_screen.gd
## PORTS: nothing — new file per ruling HTP R1 (user 2026-10-13: "create a new branch
## called add-onboarding -- based on the data from the website
## https://perilpoint.newzenith.ph/how-to-play")
class_name HowToPlayScreen
extends Control
## The How to play guide: three pages built in code from the public guide's text, each with
## a clip — a run dodging red dots, the site's power-up clips, and an Armory tour. It opens
## by itself on a first launch and from the menu's How to play button; any way it closes
## counts as seen (GameRoot saves that).
##
## PORT-NOTE: TiltGame.ts has no guide. Every layout literal below is new and tagged
## DIVERGENCE(HTP R1/R2); the text is the site's, trimmed to fit a phone held sideways, with
## one fix: the site's "calibrate button next to Steer" is gone since BUG-101 R3, so Tilt
## points at Settings instead.

## The guide closed (the close chevron, Got it, or the Android back button).
signal closed

## DIVERGENCE(HTP R2, user 2026-10-13: "we can remove 3 - 4 - 5 ... add in another brief
## section for the armory"): the page titles, in order.
const PAGES: Array[String] = ["The basics", "Power-ups", "The Armory"]
## DIVERGENCE(HTP R1): the clips, re-encoded to Theora (Godot plays no MP4). The power-up
## clips are the site's; dodge and armory are recorded from the game (tools/record_htp_clips.gd).
const CLIP_PATH: String = "res://assets/how_to_play/%s.ogv"
const DODGE_CLIP: String = "dodge"
const ARMORY_CLIP: String = "armory"
## DIVERGENCE(HTP R1): the site's power-up order, names and lines.
const WEAPONS: Array[Types.WeaponType] = [
	Types.WeaponType.NUKE,
	Types.WeaponType.MISSILES,
	Types.WeaponType.LIGHTNING,
	Types.WeaponType.LASER,
	Types.WeaponType.VORTEX,
	Types.WeaponType.FREEZE,
	Types.WeaponType.SHIELD,
]
const WEAPON_NAMES: Dictionary[Types.WeaponType, String] = {
	Types.WeaponType.NUKE: "Nuke",
	Types.WeaponType.MISSILES: "Missiles",
	Types.WeaponType.LIGHTNING: "Lightning",
	Types.WeaponType.LASER: "Laser",
	Types.WeaponType.VORTEX: "Blackhole",
	Types.WeaponType.FREEZE: "Freeze",
	Types.WeaponType.SHIELD: "Shield",
}
const WEAPON_LINES: Dictionary[Types.WeaponType, String] = {
	Types.WeaponType.NUKE:
	"An instant shockwave that clears the area around you. Grab it when the swarm closes in.",
	Types.WeaponType.MISSILES: "A swarm of homing warheads that track down dots on their own.",
	Types.WeaponType.LIGHTNING:
	"Arcs that jump from dot to dot in a chain. Best when dots are bunched together.",
	Types.WeaponType.LASER:
	"A continuous beam that pierces everything in its line as it sweeps through the swarm.",
	Types.WeaponType.VORTEX:
	(
		"Drags dots into a vortex, then collapses. You're safe inside the well. "
		+ "The rarest orb; the timer calls it Vortex."
	),
	Types.WeaponType.FREEZE:
	(
		"Flash-freezes every dot into a crystal. Frozen dots can't hurt you: "
		+ "fly into them to shatter them."
	),
	Types.WeaponType.SHIELD:
	"A barrier around your ship. While it lasts, ram straight through dots to destroy them.",
}
## DIVERGENCE(HTP R2): the Armory's tabs (ArmoryUI.TAB_LABELS), one line each, from the site.
const ARMORY_LINES: Array[Array] = [
	["Weapons", "Upgrade each power-up and unlock keystones that change how it works."],
	["Ships", "Seven hulls, each with its own hitbox, turn rate and starting weapon."],
	["Arena", "Themes for the arena and skins for the enemies."],
	["Handling", "Top speed, tilt sensitivity and stick size, with a live preview."],
	["Boosts", "Extra Life, a smaller hitbox, slower enemies, and score or Points multipliers."],
	# DIVERGENCE(HTP R3): the sixth tab (ITEM R2).
	["Abilities", "A faster, longer dash, and items: power-ups you fire once a run."],
]
## DIVERGENCE(HTP R1): a question mark in a ring, for the menu's How to play button.
const ICON_HELP: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 16 16" fill="none">'
	+ '<circle cx="8" cy="8" r="6.6" stroke="#3DDC97" stroke-width="1.5"/>'
	+ '<path d="M6.1 6.2 A1.95 1.95 0 1 1 8.6 8.1 C8.1 8.3 8 8.6 8 9.2" stroke="#3DDC97" '
	+ 'stroke-width="1.5" stroke-linecap="round"/><circle cx="8" cy="11.4" r="0.95" '
	+ 'fill="#3DDC97"/></svg>'
)

## DIVERGENCE(HTP R1): header 64 tall, padding 8/28/8/24, gap 12, as the Settings header.
const HEADER_HEIGHT: int = 64
const HEADER_PAD_Y: int = 8
const HEADER_PAD_RIGHT: int = 28
const HEADER_PAD_LEFT: int = 24
const HEADER_GAP: int = 12
const TITLE_GAP: int = 2
## DIVERGENCE(HTP R1): page dots 6 px, gap 6; Back and Next 96 wide.
const DOT_SIZE: int = 6
const DOT_GAP: int = 6
const STEP_BUTTON_WIDTH: int = 96
## DIVERGENCE(HTP R1): body padding 14/28/16/24 and column gap 20, as the Settings body.
const BODY_PAD_TOP: int = 14
const BODY_PAD_RIGHT: int = 28
const BODY_PAD_BOTTOM: int = 16
const BODY_PAD_LEFT: int = 24
const COLUMN_GAP: int = 20
const STACK_GAP: int = 8
const PARAGRAPH_GAP: int = 6
## DIVERGENCE(HTP R1): cards — padding 12/10, gap 10.
const CARD_PAD_X: int = 12
const CARD_PAD_Y: int = 10
const CARD_GAP: int = 10
const LINE_GAP: int = 2
## DIVERGENCE(HTP R1): the text column is 320 wide and the clip takes the rest at 16:9;
## the power-up picker is a 4-wide grid of 48 px orb buttons, orbs 30 px.
const TEXT_COLUMN_WIDTH: int = 320
const CLIP_ASPECT: float = 16.0 / 9.0
const ORB_COLUMNS: int = 4
const ORB_BUTTON: int = 48
const ORB_SIZE: int = 30
const ORB_GAP: int = 8

var _ui_scale: float = 1.0
var _inset: Vector2 = Vector2.ZERO
var _is_open: bool = false
var _page: int = 0
var _weapon: Types.WeaponType = Types.WeaponType.NUKE
var _clip: VideoStreamPlayer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Shows the guide at `start_page`.
func open(start_page: int = 0) -> void:
	_is_open = true
	_page = clampi(start_page, 0, PAGES.size() - 1)
	_build()


## Hides the guide, drops its clip, and emits `closed`.
func close() -> void:
	_is_open = false
	_build()
	closed.emit()


func is_open() -> bool:
	return _is_open


## The page on screen (an index into PAGES).
func page() -> int:
	return _page


## Next page; on the last page, Got it closes the guide.
func next_page() -> void:
	if _page >= PAGES.size() - 1:
		close()
		return
	_page += 1
	_build()


func previous_page() -> void:
	if _page == 0:
		return
	_page -= 1
	_build()


## The power-up the Power-ups page shows.
func selected_weapon() -> Types.WeaponType:
	return _weapon


## Picks the power-up whose clip and lines the Power-ups page shows.
func select_weapon(type: Types.WeaponType) -> void:
	_weapon = type
	_build()


## The page's clip, or null while closed.
func clip() -> VideoStreamPlayer:
	return _clip


## Rebuilds the guide at `scale`, insetting the header and body by `inset` (the safe area).
func set_ui_scale(scale: float, inset: Vector2) -> void:
	_ui_scale = scale
	_inset = inset
	theme = UiTheme.build(scale)
	_build()


func _build() -> void:
	_clip = null
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	visible = _is_open
	if not _is_open:
		return
	var surface: PanelContainer = PanelContainer.new()
	surface.name = "Surface"
	surface.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_SHELL, Color.TRANSPARENT, 0)
	)
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	stack.add_child(_header())
	stack.add_child(UiTheme.hairline(false, UiTheme.COLOR_RAISED))
	stack.add_child(_body())
	surface.add_child(stack)


func _header() -> MarginContainer:
	var header: MarginContainer = MarginContainer.new()
	header.custom_minimum_size.y = _px(HEADER_HEIGHT)
	header.add_theme_constant_override("margin_top", _px(HEADER_PAD_Y) + roundi(_inset.y))
	header.add_theme_constant_override("margin_bottom", _px(HEADER_PAD_Y))
	header.add_theme_constant_override("margin_right", _px(HEADER_PAD_RIGHT) + roundi(_inset.x))
	header.add_theme_constant_override("margin_left", _px(HEADER_PAD_LEFT) + roundi(_inset.x))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(HEADER_GAP))
	var close_button: Button = _button("HowToPlayCloseButton", "GhostIconButton", "")
	close_button.tooltip_text = "Close how to play"
	close_button.custom_minimum_size = Vector2.ONE * _px(UiTheme.TOUCH_TARGET)
	close_button.icon = UiTheme.svg_texture(UiTheme.ICON_BACK, _ui_scale)
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	row.add_child(close_button)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override("separation", _px(TITLE_GAP))
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var step: Label = UiTheme.caps("How to play · %d / %d" % [_page + 1, PAGES.size()])
	step.name = "HowToPlayStep"
	step.add_theme_color_override("font_color", UiTheme.COLOR_ION)
	titles.add_child(step)
	var title: Label = UiTheme.text(PAGES[_page], "TitleText")
	title.name = "HowToPlayTitle"
	titles.add_child(title)
	row.add_child(titles)
	row.add_child(_page_dots())
	var back: Button = _button("HowToPlayBackButton", "SecondaryButton", "Back")
	back.disabled = _page == 0
	back.pressed.connect(previous_page)
	row.add_child(back)
	var is_last: bool = _page == PAGES.size() - 1
	var next: Button = _button(
		"HowToPlayNextButton", "PrimaryButton", "Got it" if is_last else "Next"
	)
	next.pressed.connect(next_page)
	row.add_child(next)
	for b: Button in [back, next]:
		b.custom_minimum_size = Vector2(_px(STEP_BUTTON_WIDTH), _px(UiTheme.TOUCH_TARGET))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(row)
	return header


func _page_dots() -> HBoxContainer:
	var dots: HBoxContainer = HBoxContainer.new()
	dots.name = "PageDots"
	dots.add_theme_constant_override("separation", _px(DOT_GAP))
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i: int in range(PAGES.size()):
		var dot: Panel = Panel.new()
		dot.custom_minimum_size = Vector2.ONE * _px(DOT_SIZE)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color: Color = UiTheme.COLOR_ION if i == _page else UiTheme.COLOR_LINE_STRONG
		dot.add_theme_stylebox_override(
			"panel", UiTheme.flat(color, Color.TRANSPARENT, _px(DOT_SIZE))
		)
		dots.add_child(dot)
	return dots


## Every page is a text column on the left and its clip on the right.
func _body() -> MarginContainer:
	var body: MarginContainer = MarginContainer.new()
	body.name = "HowToPlayBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("margin_top", _px(BODY_PAD_TOP))
	body.add_theme_constant_override("margin_bottom", _px(BODY_PAD_BOTTOM) + roundi(_inset.y))
	body.add_theme_constant_override("margin_right", _px(BODY_PAD_RIGHT) + roundi(_inset.x))
	body.add_theme_constant_override("margin_left", _px(BODY_PAD_LEFT) + roundi(_inset.x))
	var columns: HBoxContainer = HBoxContainer.new()
	columns.name = "Page_%d" % _page
	columns.add_theme_constant_override("separation", _px(COLUMN_GAP))
	var clip_key: String = DODGE_CLIP
	match _page:
		0:
			_basics_page(columns)
		1:
			_powerups_page(columns)
			clip_key = WeaponIcons.weapon_key(_weapon)
		_:
			_armory_page(columns)
			clip_key = ARMORY_CLIP
	columns.add_child(_clip_frame(clip_key))
	body.add_child(columns)
	UiTheme.let_drags_scroll(body)
	return body


func _basics_page(columns: HBoxContainer) -> void:
	var left: VBoxContainer = _column(columns, "Stay alive")
	_paragraph(left, "Steer through the red dots. Touch one and you lose a life.")
	_paragraph(left, "You never shoot: fly into a weapon orb and it fires by itself.")
	left.add_child(_card(UiTheme.ICON_TOUCH, "Touch", "Drag anywhere; the ship follows."))
	left.add_child(
		_card(
			UiTheme.ICON_TILT,
			"Tilt",
			"Tilt the phone. Settings → Controls sets the level: each run, or your Calibrate angle."
		)
	)


func _powerups_page(columns: HBoxContainer) -> void:
	var left: VBoxContainer = _column(columns, "Fly into an orb to fire it")
	_paragraph(
		left,
		(
			"A new orb appears every few seconds and lasts about 12 seconds. "
			+ "Orbs near your ship drift toward it."
		)
	)
	var grid: GridContainer = GridContainer.new()
	grid.name = "OrbGrid"
	grid.columns = ORB_COLUMNS
	grid.add_theme_constant_override("h_separation", _px(ORB_GAP))
	grid.add_theme_constant_override("v_separation", _px(ORB_GAP))
	for type: Types.WeaponType in WEAPONS:
		var orb: Button = _button("Orb_" + WeaponIcons.weapon_key(type), "ListItemButton", "")
		orb.toggle_mode = true
		orb.button_pressed = type == _weapon
		orb.tooltip_text = WEAPON_NAMES[type]
		orb.custom_minimum_size = Vector2.ONE * _px(ORB_BUTTON)
		orb.icon = WeaponIcons.orb_texture(type, _px(ORB_SIZE))
		orb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		orb.pressed.connect(select_weapon.bind(type))
		grid.add_child(orb)
	left.add_child(grid)
	var weapon_name: Label = UiTheme.text(WEAPON_NAMES[_weapon], "FieldText")
	weapon_name.name = "WeaponName"
	weapon_name.add_theme_color_override("font_color", WeaponIcons.ui_color_of(_weapon))
	left.add_child(weapon_name)
	var line: Label = _paragraph(left, WEAPON_LINES[_weapon])
	line.name = "WeaponLine"


func _armory_page(columns: HBoxContainer) -> void:
	var left: VBoxContainer = _column(columns, "Spend your Points")
	left.name = "ArmoryList"
	_paragraph(
		left,
		"Every run pays Points: more the longer you survive and the more you destroy. Coins add more."
	)
	for tab: Array in ARMORY_LINES:
		var row: VBoxContainer = VBoxContainer.new()
		row.add_theme_constant_override("separation", _px(LINE_GAP))
		var tab_name: Label = UiTheme.text(str(tab[0]), "StrongText")
		tab_name.add_theme_color_override("font_color", UiTheme.ION_TEXT)
		row.add_child(tab_name)
		var line: Label = _paragraph(row, str(tab[1]))
		line.theme_type_variation = "HintText"
		left.add_child(row)


## The text column: 320 wide, titled, scrolling. Returns its content stack.
func _column(columns: HBoxContainer, heading: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = _px(TEXT_COLUMN_WIDTH)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", _px(STACK_GAP))
	var label: Label = UiTheme.caps(heading)
	label.add_theme_color_override("font_color", UiTheme.COLOR_ION)
	column.add_child(label)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", _px(PARAGRAPH_GAP))
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(content)
	column.add_child(scroll)
	columns.add_child(column)
	return content


## The page's clip, looping at 16:9 in the room right of the text column.
func _clip_frame(key: String) -> AspectRatioContainer:
	var frame: AspectRatioContainer = AspectRatioContainer.new()
	frame.name = "ClipFrame"
	frame.ratio = CLIP_ASPECT
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.alignment_vertical = AspectRatioContainer.ALIGNMENT_BEGIN
	_clip = VideoStreamPlayer.new()
	_clip.name = "Clip"
	_clip.stream = load(CLIP_PATH % key) as VideoStream
	_clip.expand = true
	_clip.loop = true
	_clip.autoplay = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_clip)
	return frame


func _paragraph(parent: Control, content: String) -> Label:
	var label: Label = UiTheme.text(content, "LabelText")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


## A card: a glyph, a bold name, and a wrapped line.
func _card(glyph: String, card_name: String, line: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override(
		"panel",
		UiTheme.padded(
			UiTheme.flat(UiTheme.COLOR_PANEL, UiTheme.COLOR_LINE, _px(UiTheme.CARD_RADIUS)),
			_px(CARD_PAD_X),
			_px(CARD_PAD_Y)
		)
	)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(CARD_GAP))
	var icon: TextureRect = TextureRect.new()
	icon.texture = UiTheme.svg_texture(glyph, _ui_scale)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.modulate = UiTheme.ION_TEXT
	row.add_child(icon)
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", _px(LINE_GAP))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UiTheme.text(card_name, "StrongText"))
	var hint: Label = _paragraph(text, line)
	hint.theme_type_variation = "HintText"
	row.add_child(text)
	card.add_child(row)
	return card


func _button(button_name: String, variation: String, label: String) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.theme_type_variation = variation
	button.text = label
	return button


func _px(base: float) -> int:
	return UiTheme.px(base, _ui_scale)
