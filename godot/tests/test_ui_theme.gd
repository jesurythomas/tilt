## test_ui_theme.gd
## PORTS: nothing — new file, covers src/ui/ui_theme.gd, tests/ui_checks.gd and
## HudController.ui_scale_for (interface spec §4)
extends GutTest
## Proves the interface-system foundations: tokens, fonts, variations, scale.


func test_colour_tokens_match_the_system_board() -> void:
	assert_eq(UiTheme.COLOR_VOID, Color("#08090E"))
	assert_eq(UiTheme.COLOR_ARENA, Color("#0D1016"))
	assert_eq(UiTheme.COLOR_SHELL, Color("#0B0E14"))
	assert_eq(UiTheme.COLOR_SHEET, Color("#12161F"))
	assert_eq(UiTheme.COLOR_PANEL, Color("#141821"))
	assert_eq(UiTheme.COLOR_RAISED, Color("#1B2029"))
	assert_eq(UiTheme.COLOR_LINE, Color("#262C38"))
	assert_eq(UiTheme.COLOR_LINE_STRONG, Color("#3A4252"))
	assert_eq(UiTheme.COLOR_TEXT, Color("#E6E9F0"))
	assert_eq(UiTheme.COLOR_TEXT_MUTED, Color("#99A1B3"))
	assert_eq(UiTheme.COLOR_ION, Color("#5B8CFF"))
	assert_eq(UiTheme.COLOR_FLARE, Color("#FFB14D"))
	assert_eq(UiTheme.COLOR_PLASMA, Color("#A78BFA"))
	assert_eq(UiTheme.COLOR_LOCKED_IN, Color("#3DDC97"))


func test_hazard_red_is_not_a_ui_token() -> void:
	# Rule 01 (System.dc.html): red never appears in chrome.
	var hazard: Color = Color("#FF4757")
	for token: Color in [
		UiTheme.COLOR_VOID,
		UiTheme.COLOR_ARENA,
		UiTheme.COLOR_SHELL,
		UiTheme.COLOR_SHEET,
		UiTheme.COLOR_PANEL,
		UiTheme.COLOR_RAISED,
		UiTheme.COLOR_LINE,
		UiTheme.COLOR_LINE_STRONG,
		UiTheme.COLOR_TEXT,
		UiTheme.COLOR_TEXT_MUTED,
		UiTheme.COLOR_ION,
		UiTheme.COLOR_FLARE,
		UiTheme.COLOR_PLASMA,
		UiTheme.COLOR_LOCKED_IN,
	]:
		assert_ne(token, hazard)


func test_fonts_load_and_archivo_is_widened() -> void:
	assert_not_null(UiTheme.sans(UiTheme.Weight.REGULAR))
	assert_not_null(UiTheme.sans(UiTheme.Weight.SEMIBOLD))
	assert_not_null(UiTheme.mono(UiTheme.Weight.MEDIUM).base_font)
	var plain: float = (
		UiTheme.ARCHIVO.get_string_size("Armory", HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	)
	var title: float = (
		UiTheme
		. archivo(UiTheme.TITLE_WIDTH)
		. get_string_size("Armory", HORIZONTAL_ALIGNMENT_LEFT, -1, 21)
		. x
	)
	assert_gt(title, plain, "wdth 112 / wght 700 renders wider than the default instance")


func test_build_scales_every_text_variation() -> void:
	var one: Theme = UiTheme.build(1.0)
	var two: Theme = UiTheme.build(2.0)
	for name: String in ["TitleText", "ScoreText", "CapsText", "BodyText", "PointsText"]:
		assert_true(one.is_type_variation(name, "Label"), name)
		assert_eq(
			two.get_font_size("font_size", name),
			UiTheme.px(one.get_font_size("font_size", name), 2.0),
			name + " doubles at scale 2"
		)
	assert_eq(one.get_font_size("font_size", "TitleText"), UiTheme.TITLE_SIZE)
	assert_eq(one.get_font_size("font_size", "CapsText"), UiTheme.CAPS_SIZE)


func test_build_carries_every_component_variation() -> void:
	var theme: Theme = UiTheme.build(1.0)
	for name: String in [
		"PrimaryButton",
		"SecondaryButton",
		"IconButton",
		"FlatIconButton",
		"GhostIconButton",
		"CostButton",
		"PlasmaCostButton",
		"EquippedButton",
		"TabButton",
		"SegmentButton",
		"ListItemButton",
		"CardButton",
	]:
		assert_true(theme.is_type_variation(name, "Button"), name)
	assert_true(theme.is_type_variation("Switch", "CheckButton"))
	for name: String in ["Card", "LockedCard", "Sheet", "Segmented"]:
		assert_true(theme.is_type_variation(name, "PanelContainer"), name)
	assert_true(theme.is_type_variation("Meter", "ProgressBar"))


func test_only_the_sheet_casts_a_shadow() -> void:
	# Rule 02 (System.dc.html): nothing in the UI glows; the Sheet's drop
	# shadow is the one exception.
	var theme: Theme = UiTheme.build(1.0)
	var sheet: StyleBoxFlat = theme.get_stylebox("panel", "Sheet") as StyleBoxFlat
	assert_gt(sheet.shadow_size, 0)
	for name: String in ["Card", "LockedCard", "Segmented"]:
		var box: StyleBoxFlat = theme.get_stylebox("panel", name) as StyleBoxFlat
		assert_eq(box.shadow_size, 0, name)


func test_primary_button_is_ion_with_void_text() -> void:
	var theme: Theme = UiTheme.build(1.0)
	var normal: StyleBoxFlat = theme.get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
	assert_eq(normal.bg_color, UiTheme.COLOR_ION)
	assert_eq(theme.get_color("font_color", "PrimaryButton"), UiTheme.COLOR_VOID)


func test_group_digits() -> void:
	assert_eq(UiTheme.group_digits(0), "0")
	assert_eq(UiTheme.group_digits(999), "999")
	assert_eq(UiTheme.group_digits(7331), "7,331")
	assert_eq(UiTheme.group_digits(1234567), "1,234,567")


func test_svg_texture_rasterises_at_scale() -> void:
	var tex: ImageTexture = UiTheme.svg_texture(UiTheme.ICON_PAUSE, 2.0)
	assert_eq(tex.get_width(), 32, "16 px icon at scale 2")
	var glyph: ImageTexture = UiTheme.svg_texture(
		UiTheme.ship_glyph_svg(UiTheme.TEXT_SECONDARY, 16), 1.0
	)
	assert_eq(glyph.get_width(), 16)


func test_pips_fill_rank_of_max() -> void:
	var bar: HBoxContainer = UiTheme.pips(3, 5, 1.0)
	add_child_autofree(bar)
	assert_eq(bar.get_child_count(), 5)
	var filled: int = 0
	for pip: Node in bar.get_children():
		if (pip as ColorRect).color == UiTheme.COLOR_ION:
			filled += 1
	assert_eq(filled, 3)


func test_ui_scale_for_the_reference_frames() -> void:
	assert_almost_eq(HudController.ui_scale_for(Vector2(844, 390)), 1.0, 0.0001)
	assert_almost_eq(HudController.ui_scale_for(Vector2(2340, 1080)), 1080.0 / 390.0, 0.0001)
	assert_almost_eq(
		HudController.ui_scale_for(Vector2(1280, 720)),
		1280.0 / 844.0,
		0.0001,
		"16:9 is narrower than the boards: width shrinks the scale"
	)
	assert_almost_eq(HudController.ui_scale_for(Vector2(390, 844)), 1.0, 0.0001, "orientation-free")
	assert_eq(HudController.ui_scale_for(Vector2(8000, 4000)), HudController.MAX_UI_SCALE)
	assert_eq(HudController.ui_scale_for(Vector2(320, 240)), HudController.MIN_UI_SCALE)


func test_ui_checks_flag_short_buttons_and_overflow() -> void:
	var host: Control = Control.new()
	host.size = Vector2(200, 100)
	add_child_autofree(host)
	var box: VBoxContainer = VBoxContainer.new()
	host.add_child(box)
	var tall: Button = Button.new()
	tall.name = "Tall"
	tall.custom_minimum_size = Vector2(40, 48)
	var short: Button = Button.new()
	short.name = "Short"
	short.custom_minimum_size = Vector2(40, 20)
	var wide: Button = Button.new()
	wide.name = "Wide"
	wide.custom_minimum_size = Vector2(400, 48)
	box.add_child(tall)
	box.add_child(short)
	box.add_child(wide)
	await get_tree().process_frame
	var short_names: Array[String] = UiChecks.short_buttons(host, 48.0)
	assert_eq(short_names.size(), 1)
	assert_true(short_names.has("Short"))
	assert_true(UiChecks.outside(host, host.get_global_rect()).has("Wide"))
	assert_true(UiChecks.overlapping_siblings(host).is_empty())
