## how_to_play_screen.gd
## PORTS: nothing — new file per ruling HTP R1 (user 2026-10-13: "create a new branch
## called add-onboarding -- based on the data from the website
## https://perilpoint.newzenith.ph/how-to-play")
class_name HowToPlayScreen
extends Control
## The How to play guide: five pages built in code from the public guide's text, with the
## power-up clips the site plays. It opens by itself on a first launch and from the menu's
## How to play button; any way it closes counts as seen (GameRoot saves that).
##
## PORT-NOTE: TiltGame.ts has no guide. Every layout literal below is new and tagged
## DIVERGENCE(HTP R1); the text is the site's, trimmed to fit a phone held sideways, with
## one fix: the site's "calibrate button next to Steer" is gone since BUG-101 R3, so Tilt
## points at Settings instead.

## The guide closed (the close chevron, Got it, or the Android back button).
signal closed

## DIVERGENCE(HTP R1): the page titles, in order.
const PAGES: Array[String] = [
	"The basics", "Power-ups", "Lives & enemies", "Score & Points", "Tips"
]
## DIVERGENCE(HTP R1): the site's power-up clips, re-encoded to Theora (Godot plays no MP4).
const CLIP_PATH: String = "res://assets/how_to_play/%s.ogv"
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
## DIVERGENCE(HTP R1): the site's enemy table — name, what it does, how to handle it.
const ENEMIES: Array[Array] = [
	[
		"Seekers",
		"Plain dots that home in on you and speed up over time.",
		"Keep moving; lead them into a chain."
	],
	["Chargers", "Take aim for about a second, then dash at you.", "Sidestep when they lunge."],
	["Specters", "Home in while fading in and out of sight.", "Watch for the flicker."],
	[
		"Artillery",
		"Keep their distance, strafe and fire shots at you.",
		"Weave between the shots, then close in with a weapon."
	],
	["Pulsars", "Home in, giving off bursts of sparks.", "Treat them like fast seekers."],
	[
		"Carriers",
		"Slow dots ringed by orbiting seekers.",
		"Give them room, or clear them with Nuke or Lightning."
	],
	[
		"Arrow wings",
		"A wing of seven that sweeps in from an edge. In Overdrive, wings come from both sides.",
		"Move off their line."
	],
	[
		"Walls",
		"A line sweeping across the arena, with a gap.",
		"Find the gap early. (Not in Corridor.)"
	],
	[
		"Circles",
		"A ring of dots around you that pauses, then closes in.",
		"Break out before it tightens. (Not in Corridor.)"
	],
	["Turrets", "Slow drifting dots that take three hits.", "Leave them for the bigger weapons."],
	["Snakes", "A chain of eight segments that drifts and re-aims.", "Watch where the head turns."],
]
## DIVERGENCE(HTP R1): the site's Modes table, by mode (names and colours are the menu's).
const MODE_LINES: Dictionary[Types.GameMode, String] = {
	Types.GameMode.CLASSIC: "The full arsenal against swarms that ramp up as you go.",
	Types.GameMode.GAUNTLET:
	"Walls scroll down and close in. One can crush you against the bottom. Score counts 1.25×.",
	Types.GameMode.CODE_RED:
	"Double density from the first second, tougher enemies sooner, faster orbs. Score counts 1.5×.",
}
## DIVERGENCE(HTP R1): the site's Tips.
const TIPS: Array[String] = [
	"Don't wait for dots to come to you: go get the next orb.",
	"Freeze, then fly through the crystals. It's free kills.",
	"Keep chains alive. A high multiplier makes everything else worth more.",
	"Close calls pay well, but only if you don't touch.",
]
## DIVERGENCE(HTP R1): a question mark in a ring, for the menu's How to play button.
const ICON_HELP: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 16 16" fill="none">'
	+ '<circle cx="8" cy="8" r="6.6" stroke="#3DDC97" stroke-width="1.5"/>'
	+ '<path d="M6.1 6.2 A1.95 1.95 0 1 1 8.6 8.1 C8.1 8.3 8 8.6 8 9.2" stroke="#3DDC97" '
	+ 'stroke-width="1.5" stroke-linecap="round"/><circle cx="8" cy="11.4" r="0.95" '
	+ 'fill="#3DDC97"/></svg>'
)
## DIVERGENCE(HTP R1): an enemy dot (a red ring, as the clips draw them) for the enemy list.
const ENEMY_DOT: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">'
	+ '<circle cx="6" cy="6" r="4" stroke="#FF4D5E" stroke-width="2.2"/></svg>'
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
## DIVERGENCE(HTP R1): the power-up picker — a 4-wide grid of 48 px orb buttons, orbs 30 px;
## the left column is 320 wide and the clip takes the rest at 16:9.
const ORB_COLUMNS: int = 4
const ORB_BUTTON: int = 48
const ORB_SIZE: int = 30
const ORB_GAP: int = 8
const POWERUP_COLUMN_WIDTH: int = 320
const CLIP_ASPECT: float = 16.0 / 9.0
## DIVERGENCE(HTP R1): the mode bar 3×30, r 2, as the menu's mode cards.
const BAR_WIDTH: int = 3
const BAR_HEIGHT: int = 30
const BAR_RADIUS: int = 2
## DIVERGENCE(HTP R1): enemy rows — dot gap 10, line gap 2; the enemy column 1.4× the Lives one.
const ENEMY_GAP: int = 10
const LINE_GAP: int = 2
const ENEMY_COLUMN_RATIO: float = 1.4

var _options: GameOptionsManager = null
var _ui_scale: float = 1.0
var _inset: Vector2 = Vector2.ZERO
var _is_open: bool = false
var _page: int = 0
var _weapon: Types.WeaponType = Types.WeaponType.NUKE
var _clip: VideoStreamPlayer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Stands in for a constructor: the mode catalog the Modes column lists.
func bind(options: GameOptionsManager) -> void:
	_options = options


## Shows the guide at `start_page`.
func open(start_page: int = 0) -> void:
	_is_open = true
	_page = clampi(start_page, 0, PAGES.size() - 1)
	_build()


## Hides the guide, stops its clip, and emits `closed`.
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


## The clip on screen, or null off the Power-ups page and while closed.
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
	match _page:
		0:
			_basics_page(columns)
		1:
			_powerups_page(columns)
		2:
			_lives_page(columns)
		3:
			_score_page(columns)
		_:
			_tips_page(columns)
	body.add_child(columns)
	UiTheme.let_drags_scroll(body)
	return body


func _basics_page(columns: HBoxContainer) -> void:
	var left: VBoxContainer = _column(columns, "Stay alive")
	_paragraph(
		left,
		(
			"Steer a small ship around an arena that keeps filling with red dots. "
			+ "Touch one and you lose a life."
		)
	)
	_paragraph(left, "You never shoot. Fly into a weapon orb and its weapon fires by itself.")
	_paragraph(
		left, "Stay alive, chain kills for score, and spend the Points each run pays on upgrades."
	)
	var right: VBoxContainer = _column(columns, "Steering · pick one under Steer")
	right.add_child(
		_card(
			UiTheme.ICON_TOUCH,
			"Touch",
			"Put a finger down anywhere and drag. A joystick appears under it; the ship follows."
		)
	)
	right.add_child(
		_card(
			UiTheme.ICON_TILT,
			"Tilt",
			(
				"Tilt the phone to steer. Settings → Controls sets the level: each run start, "
				+ "or your Calibrate angle for every run."
			)
		)
	)
	_hint(
		right,
		"Armory → Handling tunes turn rate, tilt sensitivity and stick size, with a live preview."
	)


func _powerups_page(columns: HBoxContainer) -> void:
	var left: VBoxContainer = _column(columns, "Fly into an orb to fire it", POWERUP_COLUMN_WIDTH)
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
	var frame: AspectRatioContainer = AspectRatioContainer.new()
	frame.name = "ClipFrame"
	frame.ratio = CLIP_ASPECT
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.alignment_vertical = AspectRatioContainer.ALIGNMENT_BEGIN
	_clip = VideoStreamPlayer.new()
	_clip.name = "Clip"
	_clip.stream = load(CLIP_PATH % WeaponIcons.weapon_key(_weapon)) as VideoStream
	_clip.expand = true
	_clip.loop = true
	_clip.autoplay = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_clip)
	columns.add_child(frame)


func _lives_page(columns: HBoxContainer) -> void:
	var left: VBoxContainer = _column(columns, "Lives")
	_paragraph(
		left, "Touching a red dot costs a life, unless you're shielded or the dot is frozen."
	)
	_paragraph(
		left,
		(
			"You start with one life. The Extra Life boost and the Revenant ship add more, "
			+ "up to three."
		)
	)
	_paragraph(left, "Losing a life that isn't your last gives you a short shield to get clear.")
	_hint(left, "Everything red is dangerous. Tougher dots join as your score climbs.")
	var right: VBoxContainer = _column(columns, "Enemies", 0, ENEMY_COLUMN_RATIO)
	right.name = "EnemyList"
	right.add_theme_constant_override("separation", _px(STACK_GAP))
	for enemy: Array in ENEMIES:
		right.add_child(_enemy_row(str(enemy[0]), str(enemy[1]), str(enemy[2])))


func _score_page(columns: HBoxContainer) -> void:
	var score: VBoxContainer = _column(columns, "Score")
	_paragraph(score, "Kills score points, times your multiplier.")
	_paragraph(
		score,
		(
			"Chains: a kill within about a second and a half of the last keeps it going. "
			+ "Every eight kills adds +1×, up to 50×."
		)
	)
	_paragraph(score, "Close calls: brush past a dot without touching it for a big bonus.")
	var modes: VBoxContainer = _column(columns, "Modes")
	if _options != null:
		for config: GameOptionsManager.ModeConfig in _options.modes:
			modes.add_child(_mode_row(config))
	var points: VBoxContainer = _column(columns, "Points & the Armory")
	_paragraph(
		points,
		(
			"Every run pays Points: more the longer you survive and the more you destroy. "
			+ "Coins in the arena add more."
		)
	)
	_paragraph(
		points,
		(
			"Spend them in the Armory: weapon upgrades and keystones, seven ships, "
			+ "arena themes, handling and boosts."
		)
	)


func _tips_page(columns: HBoxContainer) -> void:
	var left: VBoxContainer = _column(columns, "Tips")
	for i: int in range(TIPS.size()):
		left.add_child(_card(UiTheme.ICON_CHECK, "", TIPS[i]))
	var right: VBoxContainer = _column(columns, "Achievements")
	_paragraph(right, "Achievements pay Points too. The menu shows the next one to go for.")
	_paragraph(right, "Open this guide again any time from How to play on the menu.")


## A titled, scrolling column: `width` base px wide, or else a `ratio` share of the page.
## Returns the column's content stack.
func _column(
	columns: HBoxContainer, heading: String, width: int = 0, ratio: float = 1.0
) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	if width > 0:
		column.custom_minimum_size.x = _px(width)
	else:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_stretch_ratio = ratio
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", _px(STACK_GAP))
	var label: Label = UiTheme.caps(heading)
	label.add_theme_color_override("font_color", UiTheme.COLOR_ION)
	column.add_child(label)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", _px(PARAGRAPH_GAP))
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll(content))
	columns.add_child(column)
	return content


func _scroll(content: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(content)
	return scroll


func _paragraph(parent: Control, content: String) -> Label:
	var label: Label = UiTheme.text(content, "LabelText")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _hint(parent: Control, content: String) -> void:
	var label: Label = _paragraph(parent, content)
	label.theme_type_variation = "HintText"


## A card: an optional glyph, an optional bold name, and a wrapped line.
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
	icon.modulate = UiTheme.ION_TEXT if glyph != UiTheme.ICON_CHECK else Color.WHITE
	row.add_child(icon)
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", _px(LINE_GAP))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not card_name.is_empty():
		text.add_child(UiTheme.text(card_name, "StrongText"))
	_paragraph(text, line)
	row.add_child(text)
	card.add_child(row)
	return card


func _enemy_row(enemy_name: String, does: String, handle: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(ENEMY_GAP))
	var dot: TextureRect = TextureRect.new()
	dot.texture = UiTheme.svg_texture(ENEMY_DOT, _ui_scale)
	dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(dot)
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", _px(LINE_GAP))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UiTheme.text(enemy_name, "StrongText"))
	_paragraph(text, does)
	var tip: Label = _paragraph(text, handle)
	tip.theme_type_variation = "HintText"
	tip.add_theme_color_override("font_color", UiTheme.ION_TEXT)
	row.add_child(text)
	return row


func _mode_row(config: GameOptionsManager.ModeConfig) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(CARD_GAP))
	var bar: Panel = Panel.new()
	bar.custom_minimum_size = Vector2(_px(BAR_WIDTH), _px(BAR_HEIGHT))
	bar.add_theme_stylebox_override(
		"panel", UiTheme.flat(config.color, Color.TRANSPARENT, _px(BAR_RADIUS))
	)
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(bar)
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", _px(LINE_GAP))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UiTheme.text(config.name, "StrongText"))
	var line: Label = _paragraph(text, MODE_LINES[config.id])
	line.theme_type_variation = "HintText"
	row.add_child(text)
	return row


func _button(button_name: String, variation: String, label: String) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.theme_type_variation = variation
	button.text = label
	return button


func _px(base: float) -> int:
	return UiTheme.px(base, _ui_scale)
