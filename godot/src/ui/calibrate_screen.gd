## calibrate_screen.gd
## PORTS: nothing — new file per interface spec §6.6 (Calibrate.dc.html) and M11a R4-R5
class_name CalibrateScreen
extends Control
## The Calibrate board: a live tilt dot the player centres by holding the
## phone the way they play, then taps Set level (M11a rulings R4, R5).
##
## PORT-NOTE: TiltGame.ts has no Calibrate screen; the only related TS is
## calibrateGyro's toast (TiltGame.ts:2331-2341, ported as GameRoot.calibrate_gyro)
## and reset_run's ownership of the sensor (TiltGame.ts:1553-1557). Every
## layout literal below is board-only and tagged DIVERGENCE(UI-SYSTEM).
##
## PORT-NOTE: Disc is drawn via its own `draw` signal rather than a second
## script's _draw() override, so the whole screen stays one file (port law 3).

## The Set level button was pressed; GameRoot reads a live sensor and closes.
signal set_level_requested
## The screen closed, by Cancel or by Set level.
signal closed

## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — scrim rgba(8,9,14,0.82)
const SCRIM_ALPHA: float = 0.82

## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — left block at left 60, width 360,
## vertically centred, outer gap 18, header stack gap 8.
const LEFT_LEFT: int = 60
const LEFT_WIDTH: int = 360
const LEFT_GAP: int = 18
const HEADER_GAP: int = 8
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — h2 font-size 28
const TITLE_SIZE: int = 28
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — p font-size 14
const BODY_SIZE: int = 14
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — button column width 260, gap 10
const BUTTON_COLUMN_WIDTH: int = 260
const BUTTON_GAP: int = 10
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — Set level height 56, Cancel height 48
const SET_LEVEL_HEIGHT: int = 56
const CANCEL_HEIGHT: int = 48

## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — Disc 230×230, right 96
const DISC_SIZE: int = 230
const DISC_RIGHT: int = 96
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — crosshair inset 14
const CROSSHAIR_INSET: int = 14
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — disc fill rgba(20,24,33,0.6)
const DISC_FILL_ALPHA: float = 0.6
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — top-speed ring Ø132, dashed,
## rgba(91,140,255,0.3)
const TOP_SPEED_DIAMETER: int = 132
const TOP_SPEED_RING_ALPHA: float = 0.3
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — still ring Ø40, rgba(255,177,77,0.7).
## PORT-NOTE: drawn at the board's size, not TiltInput.DEADZONE_THRESHOLD (0.07
## of the top-speed radius = 4.6 px) — the board is the visual authority and
## the legend word is what the player reads.
const STILL_DIAMETER: int = 40
const STILL_RING_ALPHA: float = 0.7
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — dot Ø28, ion
const DOT_DIAMETER: int = 28
## DIVERGENCE(UI-SYSTEM), R4: 66 is half of the 132 top-speed ring; the dot
## reaches the ring at full deflection. The board draws the resting dot offset
## 4 px up, 1 px right (margin: -24px 0 0 -8px) as a phone-tilt mock; the port
## centres it at rest instead (PORT-NOTE).
const DOT_RADIUS: float = 66.0

## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — dashed ring: no dash length is
## given on the board, so 24 arc segments with every other one skipped.
const DASH_SEGMENTS: int = 24

## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — legend right 96, bottom 26, width
## 230, centred, item gap 18, swatch-to-text gap 7, swatch Ø9
const LEGEND_RIGHT: int = 96
const LEGEND_BOTTOM: int = 26
const LEGEND_WIDTH: int = 230
const LEGEND_GAP: int = 18
const LEGEND_ITEM_GAP: int = 7
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — "still" swatch rgba(255,177,77,0.7)
const LEGEND_STILL_RING: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="9" height="9" viewBox="0 0 9 9" fill="none">'
	+ '<circle cx="4.5" cy="4.5" r="4" stroke="#FFB14D" stroke-opacity="0.7" stroke-width="1"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — "top speed" swatch dashed rgba(91,140,255,0.6)
const LEGEND_TOP_SPEED_RING: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="9" height="9" viewBox="0 0 9 9" fill="none">'
	+ '<circle cx="4.5" cy="4.5" r="4" stroke="#5B8CFF" stroke-opacity="0.6" stroke-width="1" '
	+ 'stroke-dasharray="1.5 1.5"/></svg>'
)

var _tilt: TiltInput = null
var _ui_scale: float = 1.0
var _inset: Vector2 = Vector2.ZERO
var _is_open: bool = false
var _disc: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	_build()


## Stands in for a constructor: the sensor GameRoot drives.
func bind(tilt: TiltInput) -> void:
	_tilt = tilt


## Shows the board and starts polling the sensor for the live dot.
func open() -> void:
	_is_open = true
	visible = true
	set_process(true)


## Hides the board, stops polling, and emits `closed`.
func close() -> void:
	_is_open = false
	visible = false
	set_process(false)
	closed.emit()


func is_open() -> bool:
	return _is_open


## The drawn dot's offset from the disc centre. PORT-NOTE (R4): at rest the
## port centres the dot (Vector2.ZERO), unlike the board's tilted-phone mock.
func dot_offset() -> Vector2:
	if _tilt == null:
		return Vector2.ZERO
	return _tilt.tilt_vector.limit_length(1.0) * DOT_RADIUS * _ui_scale


## Rebuilds the board at `scale`, insetting the left block by `inset` (as
## GameRoot.resize_canvas insets TiltMenu's left block); the disc and legend
## stay flush right, as the board draws them.
func set_ui_scale(scale: float, inset: Vector2) -> void:
	_ui_scale = scale
	_inset = inset
	theme = UiTheme.build(scale)
	_build()


func _process(_delta: float) -> void:
	if _tilt != null:
		_tilt.poll()
	if _disc != null:
		_disc.queue_redraw()


func _build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	var scrim: ColorRect = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiTheme.tint(UiTheme.COLOR_VOID, SCRIM_ALPHA)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	add_child(_left_block())
	_disc = _build_disc()
	add_child(_disc)
	add_child(_legend())

	visible = _is_open


func _left_block() -> VBoxContainer:
	var block: VBoxContainer = VBoxContainer.new()
	block.name = "LeftBlock"
	block.add_theme_constant_override("separation", _px(LEFT_GAP))
	block.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	block.offset_left = _px(LEFT_LEFT) + _inset.x
	block.custom_minimum_size.x = _px(LEFT_WIDTH)

	var header: VBoxContainer = VBoxContainer.new()
	header.name = "HeaderStack"
	header.add_theme_constant_override("separation", _px(HEADER_GAP))
	var caps: Label = UiTheme.caps("Tilt")
	caps.add_theme_color_override("font_color", UiTheme.COLOR_ION)
	header.add_child(caps)
	var title: Label = UiTheme.text("Calibrate", "TitleText")
	title.add_theme_font_override("font", UiTheme.archivo(UiTheme.TITLE_WIDTH))
	title.add_theme_font_size_override("font_size", _px(TITLE_SIZE))
	header.add_child(title)
	var body: Label = (
		UiTheme
		. text(
			# DIVERGENCE(BUG-101 R2): Set level picks "All runs", so the board says so.
			"Hold the phone the way you play. That angle becomes still for every run.",
			"BodyText"
		)
	)
	body.add_theme_font_size_override("font_size", _px(BODY_SIZE))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = _px(LEFT_WIDTH)
	header.add_child(body)
	block.add_child(header)

	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.name = "ButtonColumn"
	buttons.add_theme_constant_override("separation", _px(BUTTON_GAP))
	buttons.custom_minimum_size.x = _px(BUTTON_COLUMN_WIDTH)
	var set_level: Button = _button("SetLevelButton", "PrimaryButton", "Set level")
	set_level.custom_minimum_size.y = _px(SET_LEVEL_HEIGHT)
	set_level.pressed.connect(_on_set_level_pressed)
	buttons.add_child(set_level)
	var cancel: Button = _button("CancelButton", "SecondaryButton", "Cancel")
	cancel.custom_minimum_size.y = _px(CANCEL_HEIGHT)
	cancel.pressed.connect(close)
	buttons.add_child(cancel)
	block.add_child(buttons)

	return block


func _build_disc() -> Control:
	var disc: Control = Control.new()
	disc.name = "Disc"
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.anchor_left = 1.0
	disc.anchor_right = 1.0
	disc.anchor_top = 0.5
	disc.anchor_bottom = 0.5
	disc.offset_right = -_px(DISC_RIGHT)
	disc.offset_left = disc.offset_right - _px(DISC_SIZE)
	disc.offset_top = -_px(DISC_SIZE) / 2.0
	disc.offset_bottom = _px(DISC_SIZE) / 2.0
	disc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	disc.draw.connect(_on_disc_draw)
	return disc


func _on_disc_draw() -> void:
	var size_px: float = _disc.size.x
	var center: Vector2 = _disc.size / 2.0
	var base_radius: float = size_px / 2.0
	_disc.draw_circle(center, base_radius, UiTheme.tint(UiTheme.COLOR_PANEL, DISC_FILL_ALPHA))
	_disc.draw_arc(center, base_radius, 0.0, TAU, 64, UiTheme.COLOR_LINE, 1.0)

	var inset: float = _px(CROSSHAIR_INSET)
	_disc.draw_line(
		Vector2(center.x, inset), Vector2(center.x, size_px - inset), UiTheme.COLOR_RAISED, 1.0
	)
	_disc.draw_line(
		Vector2(inset, center.y), Vector2(size_px - inset, center.y), UiTheme.COLOR_RAISED, 1.0
	)

	var top_speed_radius: float = _px(TOP_SPEED_DIAMETER) / 2.0
	_draw_dashed_ring(
		center, top_speed_radius, UiTheme.tint(UiTheme.COLOR_ION, TOP_SPEED_RING_ALPHA)
	)

	var still_radius: float = _px(STILL_DIAMETER) / 2.0
	_disc.draw_arc(
		center, still_radius, 0.0, TAU, 32, UiTheme.tint(UiTheme.COLOR_FLARE, STILL_RING_ALPHA), 1.0
	)

	var dot_radius: float = _px(DOT_DIAMETER) / 2.0
	_disc.draw_circle(center + dot_offset(), dot_radius, UiTheme.COLOR_ION)


func _draw_dashed_ring(center: Vector2, radius: float, color: Color) -> void:
	for i: int in range(DASH_SEGMENTS):
		if i % 2 == 0:
			var a0: float = TAU * float(i) / float(DASH_SEGMENTS)
			var a1: float = TAU * float(i + 1) / float(DASH_SEGMENTS)
			_disc.draw_arc(center, radius, a0, a1, 4, color, 1.0)


func _legend() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Legend"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _px(LEGEND_GAP))
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_right = -_px(LEGEND_RIGHT)
	row.offset_left = row.offset_right - _px(LEGEND_WIDTH)
	row.offset_bottom = -_px(LEGEND_BOTTOM)
	row.offset_top = row.offset_bottom
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.add_child(_legend_item(LEGEND_STILL_RING, "still"))
	row.add_child(_legend_item(LEGEND_TOP_SPEED_RING, "top speed"))
	return row


func _legend_item(swatch_svg: String, label: String) -> HBoxContainer:
	var item: HBoxContainer = HBoxContainer.new()
	item.add_theme_constant_override("separation", _px(LEGEND_ITEM_GAP))
	var swatch: TextureRect = TextureRect.new()
	swatch.texture = UiTheme.svg_texture(swatch_svg, _ui_scale)
	item.add_child(swatch)
	var text: Label = UiTheme.text(label, "MonoFaintText")
	item.add_child(text)
	return item


func _on_set_level_pressed() -> void:
	set_level_requested.emit()
	# PORT-NOTE (R4): calibrate_current_position() only arms a pending
	# capture; the real neutral pose is read on the next TiltInput.poll(). This
	# screen's own _process poll stops the instant close() disables it below,
	# so one poll is forced here to consume the pending flag against a fresh
	# reading before the sensor can be told to stop listening (final review I-1).
	if _tilt != null:
		_tilt.poll()
	close()


func _button(button_name: String, variation: String, label: String) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.theme_type_variation = variation
	button.text = label
	return button


func _px(base: float) -> int:
	return UiTheme.px(base, _ui_scale)
