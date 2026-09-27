## pause_sheet.gd
## PORTS: nothing — new file per interface spec §6.2 (Pause.dc.html). The pause
##        modal's behaviour is TiltGame.ts:1143-1177 (markup), :1396-1416
##        (switches), :1619-1642 (togglePause); HudController wires it by name.
class_name PauseSheet
extends Control
## The Pause overlay: a void scrim and a two-column Sheet, built in code so each
## board literal carries its citation. The Theme comes from the Hud above it.

const CONTROL_PICKER: PackedScene = preload("res://scenes/control_picker.tscn")

## DIVERGENCE(UI-SYSTEM): Pause.dc.html — scrim rgba(8,9,14,0.8), sheet 620×342,
## column gap 28, column stack gap 10, title gap 4 and 10 below it, row gap 8,
## switch rows 48 tall, Resume text 16, stats Mono 13.
const SCRIM_ALPHA: float = 0.8
const SHEET_WIDTH: int = 620
const SHEET_HEIGHT: int = 342
const COLUMN_GAP: int = 28
const STACK_GAP: int = 10
const TITLE_GAP: int = 4
const TITLE_BOTTOM: int = 10
const ROW_GAP: int = 8
const SWITCH_ROW: int = 48
const RESUME_FONT: int = 16
const STATS_FONT: int = 13

var _sheet: PanelContainer = null
var _columns: HBoxContainer = null
var _left: VBoxContainer = null
var _right: VBoxContainer = null
var _title_block: VBoxContainer = null
var _title_spacer: Control = null
var _stats: Label = null
var _resume: Button = null
var _restart: Button = null
var _quit: Button = null
var _steer_row: HBoxContainer = null
var _picker: ControlPicker = null
var _calibrate: Button = null
var _sound: CheckButton = null
var _music: CheckButton = null
var _bottom: HBoxContainer = null
var _armory: Button = null
var _settings: Button = null


func _ready() -> void:
	# The scrim swallows taps meant for the arena underneath.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	set_ui_scale(1.0)


## Scales the sheet and every board size in it.
func set_ui_scale(scale: float) -> void:
	_sheet.custom_minimum_size = Vector2(SHEET_WIDTH, SHEET_HEIGHT) * scale
	_columns.add_theme_constant_override("separation", UiTheme.px(COLUMN_GAP, scale))
	for column: VBoxContainer in [_left, _right]:
		column.add_theme_constant_override("separation", UiTheme.px(STACK_GAP, scale))
	_title_block.add_theme_constant_override("separation", UiTheme.px(TITLE_GAP, scale))
	_title_spacer.custom_minimum_size.y = TITLE_BOTTOM * scale
	_stats.add_theme_font_size_override("font_size", UiTheme.px(STATS_FONT, scale))
	_resume.custom_minimum_size.y = UiTheme.HERO_TARGET * scale
	_resume.add_theme_font_size_override("font_size", UiTheme.px(RESUME_FONT, scale))
	for button: Button in [_restart, _quit, _armory, _settings]:
		button.custom_minimum_size.y = UiTheme.TOUCH_TARGET * scale
	for row: HBoxContainer in [_steer_row, _bottom]:
		row.add_theme_constant_override("separation", UiTheme.px(ROW_GAP, scale))
	_calibrate.custom_minimum_size = Vector2.ONE * UiTheme.TOUCH_TARGET * scale
	_calibrate.icon = UiTheme.svg_texture(UiTheme.ICON_CALIBRATE, scale)
	for switch: CheckButton in [_sound, _music]:
		switch.custom_minimum_size.y = SWITCH_ROW * scale
	_picker.set_ui_scale(scale)


## Fills the stats line under the title.
func set_stats(score: int, time_text: String, mode_name: String) -> void:
	_stats.text = stats_text(score, time_text, mode_name)


## "Score 18,940 · 1:04 · Standard". PORT: web/src/tilt-to-live/TiltGame.ts:1624-1625
## (score · time); the mode name is the board's third field (interface spec §6.2).
static func stats_text(score: int, time_text: String, mode_name: String) -> String:
	# DIVERGENCE(M11c review): the score is labelled ("0 · 0:01 · Standard" read as
	# three unexplained numbers on the emulator).
	return "Score %s · %s · %s" % [UiTheme.group_digits(score), time_text, mode_name]


## PORT: web/src/tilt-to-live/TiltGame.ts:2239-2244 — calibrate only for gyro.
func set_calibrate_shown(shown: bool) -> void:
	_calibrate.visible = shown


## Mirrors the saved switches without writing them. PORT: web/src/tilt-to-live/TiltGame.ts:1626-1630
func set_switches(sfx_on: bool, music_on: bool) -> void:
	_sound.set_pressed_no_signal(sfx_on)
	_music.set_pressed_no_signal(music_on)


func _build() -> void:
	_sheet = UiTheme.build_sheet(self, SCRIM_ALPHA)
	_columns = HBoxContainer.new()
	_sheet.add_child(_columns)

	_left = UiTheme.sheet_column("LeftColumn")
	_title_block = VBoxContainer.new()
	_title_block.add_child(UiTheme.text("Paused", "SheetTitleText"))
	_stats = UiTheme.text("", "MonoFaintText")
	_stats.name = "PauseStats"
	_title_block.add_child(_stats)
	_left.add_child(_title_block)
	_title_spacer = Control.new()
	_left.add_child(_title_spacer)
	_resume = _button("ResumeButton", "PrimaryButton", "Resume")
	_left.add_child(_resume)
	_restart = _button("RestartRunButton", "SecondaryButton", "Restart run")
	_left.add_child(_restart)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1153 (btn-tilt-menu-pause)
	_quit = _button("QuitToMenuButton", "SecondaryButton", "Quit to menu")
	_left.add_child(_quit)
	_columns.add_child(_left)
	# DIVERGENCE(UI-SYSTEM): Pause.dc.html — column rule in line
	_columns.add_child(UiTheme.hairline(true, UiTheme.COLOR_LINE))

	_right = UiTheme.sheet_column("RightColumn")
	_right.add_child(UiTheme.caps("Steer"))
	_steer_row = HBoxContainer.new()
	_picker = CONTROL_PICKER.instantiate() as ControlPicker
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steer_row.add_child(_picker)
	_calibrate = _button("CalibrateButton", "GhostIconButton", "")
	_calibrate.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_calibrate.size_flags_horizontal = Control.SIZE_SHRINK_END
	_steer_row.add_child(_calibrate)
	_right.add_child(_steer_row)
	var switches: VBoxContainer = VBoxContainer.new()
	switches.add_theme_constant_override("separation", 0)
	_sound = _switch("SoundSwitch", "Sound")
	switches.add_child(_sound)
	# DIVERGENCE(UI-SYSTEM): Pause.dc.html — switch divider in raised
	switches.add_child(UiTheme.hairline(false, UiTheme.COLOR_RAISED))
	_music = _switch("MusicSwitch", "Music")
	switches.add_child(_music)
	_right.add_child(switches)
	var fill: Control = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_child(fill)
	_bottom = HBoxContainer.new()
	_armory = _button("PauseArmoryButton", "SecondaryButton", "Armory")
	_armory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom.add_child(_armory)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1169 (btn-tilt-all-settings, "All settings").
	# DIVERGENCE(UI-SYSTEM): Pause.dc.html — a "Settings" button beside Armory.
	_settings = _button("PauseSettingsButton", "SecondaryButton", "Settings")
	_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom.add_child(_settings)
	_right.add_child(_bottom)
	_columns.add_child(_right)


func _button(button_name: String, variation: String, label: String) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.theme_type_variation = variation
	button.text = label
	return button


func _switch(switch_name: String, label: String) -> CheckButton:
	var switch: CheckButton = CheckButton.new()
	switch.name = switch_name
	switch.theme_type_variation = "Switch"
	switch.text = label
	switch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return switch
