# gdlint:disable=max-public-methods,max-file-lines
## test_armory_ui.gd
## PORTS: nothing — new file, covers src/ui/armory_ui.gd, armory_theme.gd and
## scenes/armory.tscn
extends GutTest
## Proves the Armory shell: theme tokens, open/close, the tab aliases, the
## balance readout, and (Tasks 2-5) every purchase path from a tapped button.

const ARMORY_SCENE: PackedScene = preload("res://scenes/armory.tscn")
## The balance the purchase tests start from (the TS default, 7331).
const FUNDED_POINTS: int = 7331

var _armory: ArmoryUI = null
var _progression: ProgressionManager = null
var _settings: ControlSettings = null
## Backends displaced by _record_telemetry; after_each puts the first back.
var _displaced_backends: Array[TelemetryBackend] = []


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))
	_remove(ControlSettings.SETTINGS_PATH)
	_progression = ProgressionManager.new()
	# DIVERGENCE(ECON R3): a fresh save now starts at 500; these tests buy from a
	# funded save (the old TS start balance).
	_progression.data.points = FUNDED_POINTS
	_settings = ControlSettings.new()
	_armory = ARMORY_SCENE.instantiate() as ArmoryUI
	add_child_autofree(_armory)
	_armory.bind(_progression, _settings)
	await get_tree().process_frame


func after_each() -> void:
	if not _displaced_backends.is_empty():
		Telemetry.backend = _displaced_backends[0]
		_displaced_backends = []
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))
	_remove(ControlSettings.SETTINGS_PATH)


func _button(name: String) -> Button:
	var b: Button = _armory.find_child(name, true, false) as Button
	assert_not_null(b, "%s must exist" % name)
	return b


func _label(name: String) -> Label:
	var l: Label = _armory.find_child(name, true, false) as Label
	assert_not_null(l, "%s must exist" % name)
	return l


func _filled_pips(name: String) -> int:
	var bar: Node = _armory.find_child(name, true, false)
	assert_not_null(bar, "%s must exist" % name)
	var filled: int = 0
	for pip: Node in bar.get_children():
		if (pip as ColorRect).color != UiTheme.COLOR_LINE:  # ARMORY R2: filled in the accent
			filled += 1
	return filled


## ARMORY R2: an upgrade row's value line ("<now> → <next>") as one string.
func _value_text(name: String) -> String:
	var row: Node = _armory.find_child(name, true, false)
	assert_not_null(row, "%s must exist" % name)
	var text: String = ""
	for label: Node in row.get_children():
		text += (label as Label).text
	return text


func test_starts_hidden_and_opens_on_weapons() -> void:
	assert_false(_armory.is_open())
	assert_false(_armory.visible)
	_armory.open()
	assert_true(_armory.is_open())
	assert_true(_armory.visible)
	assert_eq(_armory.active_tab, ArmoryUI.Tab.WEAPONS)


func test_open_maps_every_legacy_tab_name() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:296-308
	var expected: Dictionary[String, int] = {
		"weapons": ArmoryUI.Tab.WEAPONS,
		"perks": ArmoryUI.Tab.WEAPONS,
		"ships": ArmoryUI.Tab.SHIPS,
		"cursors": ArmoryUI.Tab.SHIPS,
		"arena": ArmoryUI.Tab.ARENA,
		"arenas": ArmoryUI.Tab.ARENA,
		"enemies": ArmoryUI.Tab.ARENA,
		"handling": ArmoryUI.Tab.HANDLING,
		"tuning": ArmoryUI.Tab.HANDLING,
		"boosts": ArmoryUI.Tab.BOOSTS,
	}
	for name: String in expected.keys():
		_armory.open(name)
		assert_eq(_armory.active_tab as int, expected[name], name)
	_armory.open("nonsense")
	assert_eq(_armory.active_tab, ArmoryUI.Tab.WEAPONS, "unknown falls back to weapons (:308)")


func test_open_without_tab_keeps_the_last_tab() -> void:
	_armory.open("boosts")
	_armory.close()
	_armory.open()
	assert_eq(
		_armory.active_tab, ArmoryUI.Tab.BOOSTS, "ArmoryUI.ts:295 remaps only when a tab is given"
	)


func test_tab_row_has_five_buttons_and_switches() -> void:
	_armory.open()
	await get_tree().process_frame
	var tabs: HBoxContainer = _armory.find_child("Tabs", true, false) as HBoxContainer
	assert_not_null(tabs)
	assert_eq(tabs.get_child_count(), 5)
	var ships: Button = _button("Tab_ships")
	assert_true(ships.toggle_mode, "button_pressed needs toggle_mode")
	assert_true(_button("Tab_weapons").button_pressed)
	ships.pressed.emit()
	assert_eq(_armory.active_tab, ArmoryUI.Tab.SHIPS)
	assert_true(ships.button_pressed)
	assert_false(_button("Tab_weapons").button_pressed)
	assert_not_null(_armory.find_child("ShipsTab", true, false), "the ships tab body was built")


func test_balance_shows_formatted_points() -> void:
	_armory.open()
	assert_eq(_label("BalanceLabel").text, "7,331")
	assert_eq(_label("BalanceUnit").text, "PTS")
	_progression.data.points = 1
	_armory.render()
	assert_eq(_label("BalanceLabel").text, "1")
	assert_eq(_label("BalanceUnit").text, "PT", "singular at 1 (ArmoryUI.ts:70-72)")


func test_close_hides_and_emits() -> void:
	_armory.open()
	watch_signals(_armory)
	_armory.close()
	assert_false(_armory.visible)
	assert_false(_armory.is_open())
	assert_signal_emitted(_armory, "closed")


func test_back_and_play_buttons_close() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:1123-1131
	for name: String in ["BackButton", "PlayButton"]:
		_armory.open()
		_button(name).pressed.emit()
		assert_false(_armory.is_open(), name)


func test_shell_matches_the_board_on_every_platform() -> void:
	# DIVERGENCE(UI-SYSTEM): ArmoryWeapons.dc.html — Back and Play live in the
	# header on every platform; the ✕ and the sticky footer are gone (spec §6.4).
	_armory.open()
	assert_true(_button("BackButton").visible)
	assert_true(_button("PlayButton").visible)
	assert_null(_armory.find_child("CloseButton", true, false))
	assert_null(_armory.find_child("StickyFooter", true, false))
	var overlay: ColorRect = _armory.find_child("Overlay", true, false) as ColorRect
	assert_eq(overlay.color, UiTheme.COLOR_SHELL, "full-screen shell colour")


func test_format_points() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:70-72
	assert_eq(ArmoryUI.format_points(0), "0 pts")
	assert_eq(ArmoryUI.format_points(1), "1 pt")
	assert_eq(ArmoryUI.format_points(400), "400 pts")
	assert_eq(ArmoryUI.format_points(7331), "7,331 pts")
	assert_eq(ArmoryUI.format_points(1234567), "1,234,567 pts")


func test_format_tuning_value() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:46-57
	assert_eq(ArmoryUI.format_tuning_value(4.8, Tuning.TuningUnit.SECONDS), "4.8s")
	assert_eq(ArmoryUI.format_tuning_value(6.0, Tuning.TuningUnit.SECONDS), "6.0s")
	assert_eq(ArmoryUI.format_tuning_value(20.0, Tuning.TuningUnit.PERCENT), "+20%")
	assert_eq(ArmoryUI.format_tuning_value(340.0, Tuning.TuningUnit.RANGE), "340")
	assert_eq(ArmoryUI.format_tuning_value(8.0, Tuning.TuningUnit.COUNT), "8")


func test_svg_texture_rasterises() -> void:
	var svg: String = (
		"<svg xmlns='http://www.w3.org/2000/svg' width='30' height='30'>"
		+ "<circle cx='15' cy='15' r='5' fill='#A78BFA'/></svg>"
	)
	var tex: ImageTexture = UiTheme.svg_texture(svg, 2.0)
	assert_not_null(tex)
	assert_eq(tex.get_size(), Vector2(60.0, 60.0))
	assert_eq(tex.get_image().get_pixel(30, 30), Color("#A78BFA"))


func test_ui_scale_resizes_touch_targets() -> void:
	_armory.open()
	_armory.set_ui_scale(2.0)
	await get_tree().process_frame
	assert_eq(_button("Tab_weapons").custom_minimum_size.y, UiTheme.TOUCH_TARGET * 2.0)
	assert_eq(
		_button("PlayButton").custom_minimum_size,
		Vector2(ArmoryUI.PLAY_WIDTH * 2.0, UiTheme.TOUCH_TARGET * 2.0),
		"Play is 92×48 in the header (ArmoryWeapons.dc.html)"
	)


func _open_weapons(weapon: String = "") -> void:
	if not weapon.is_empty():
		_armory.selected_weapon_id = weapon
	_armory.open("weapons")


func test_weapons_catalog_matches_the_ts() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:96-203
	var ids: Array[String] = []
	for w: ArmoryUI.WeaponConfig in _armory.weapons_catalog:
		ids.append(w.id)
	assert_eq(ids, ["blackhole", "missiles", "laser", "nuke", "freeze", "shield", "lightning"])
	var blackhole: ArmoryUI.WeaponConfig = _armory.weapons_catalog[0]
	assert_eq(blackhole.name, "Blackhole")
	# ICONS R1: one colour per weapon, the orb colour lifted for the UI.
	assert_eq(blackhole.dot, WeaponIcons.ui_color_of(Types.WeaponType.VORTEX))
	assert_eq(blackhole.tracks.size(), 3)
	assert_eq(blackhole.tracks[2].key, "gravity")
	assert_eq(blackhole.tracks[2].effect, "+20% / rank")
	# KEY R1/R2: three keystones; the inside-shield is innate, said in the description.
	assert_eq(blackhole.keystones.size(), 3)
	assert_eq(blackhole.keystones[0].key, "supernovaCollapse")
	assert_true(blackhole.description.contains("safe inside"))
	var freeze: ArmoryUI.WeaponConfig = _armory.weapons_catalog[4]
	assert_eq(freeze.name, "Freeze", "ARMORY R4 (the TS said Shockwave, :161)")
	assert_eq(freeze.tracks.size(), 1)
	# KEY R1 (user: "make sure abilities have atleast 3 keystones each"), each one a
	# field of the weapon's perk record (so upgrade_perk can buy it).
	var perks: Dictionary = _progression.data.perks.to_dict()
	for w: ArmoryUI.WeaponConfig in _armory.weapons_catalog:
		assert_gte(w.keystones.size(), 3, "%s has 3 keystones" % w.id)
		var record: Dictionary = perks[w.id]
		for k: ArmoryUI.WeaponKeystone in w.keystones:
			assert_true(record.get(k.key) is bool, "%s.%s is a save field" % [w.id, k.key])
	for w: ArmoryUI.WeaponConfig in _armory.weapons_catalog:
		for t: ArmoryUI.WeaponTrack in w.tracks:
			assert_true(
				Tuning.weapon_tuning[w.id].has(t.key),
				"%s.%s is a WEAPON_TUNING track" % [w.id, t.key]
			)
			assert_eq(t.max_rank, 5)
		for k: ArmoryUI.WeaponKeystone in w.keystones:
			assert_true(Tuning.KEYSTONE_COSTS.has(k.key), "%s is a KEYSTONE_COSTS key" % k.key)


func test_weapons_tab_lists_seven_weapons_with_ranks_bought() -> void:
	_open_weapons()
	await get_tree().process_frame
	# ARMORY R1: ranks bought / ranks available over the weapon's tracks.
	assert_eq(_label("WeaponRank_blackhole").text, "9/15", "3 + 2 + 4 of 3 × 5")
	assert_eq(_label("WeaponRank_missiles").text, "5/15", "count 5, the others 0")
	assert_eq(_label("WeaponRank_nuke").text, "1/10", "radius 1 of 2 tracks")
	assert_eq(_label("WeaponRank_lightning").text, "0/10")
	assert_true(_button("Weapon_blackhole").button_pressed, "selected item is active")


func test_selecting_a_weapon_rerenders_its_detail() -> void:
	_open_weapons()
	_button("Weapon_laser").pressed.emit()
	assert_eq(_armory.selected_weapon_id, "laser")
	assert_not_null(_armory.find_child("Track_length", true, false))
	assert_not_null(_armory.find_child("Keystone_crossBeam", true, false))
	assert_eq(
		_label("InvestedValue").text,
		UiTheme.group_digits((250 + 400) * ProgressionManager.PRICE_SCALE),
		"laser.length = 2 → 250 + 400 (ECON R2), times PRICE_SCALE (ADS R7)"
	)


func test_track_readout_shows_current_and_next_value() -> void:
	_open_weapons("blackhole")
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:459-472 — duration rank 3: 4.8 + 0.5*3 → 6.3s → 6.8s
	assert_eq(_value_text("TrackValue_duration"), "6.3s → 6.8s")
	assert_eq(
		_button("Track_duration").text,
		UiTheme.group_digits(ProgressionManager.PERK_COSTS[3] * ProgressionManager.PRICE_SCALE),
		"rank 3 costs PERK_COSTS[3] (ECON R2) × PRICE_SCALE (ADS R7)"
	)
	assert_false(_button("Track_duration").disabled)


func test_buying_a_track_rank_charges_saves_and_emits() -> void:
	_open_weapons("blackhole")
	watch_signals(_armory)
	_button("Track_duration").pressed.emit()
	assert_eq(_progression.data.perks.blackhole.duration, 4)
	var balance: int = 7331 - ProgressionManager.PERK_COSTS[3] * ProgressionManager.PRICE_SCALE
	assert_eq(_progression.data.points, balance)
	assert_signal_emitted(_armory, "state_changed")
	assert_eq(_label("BalanceLabel").text, UiTheme.group_digits(balance), "re-rendered (:1164)")
	var reloaded: ProgressionManager = ProgressionManager.new()
	assert_eq(
		reloaded.data.perks.blackhole.duration, 4, "upgrade_perk saved (spec §8 M8 acceptance)"
	)


func test_maxed_track_is_disabled_and_labelled() -> void:
	_progression.data.perks.missiles.count = 5
	_open_weapons("missiles")
	var btn: Button = _button("Track_count")
	assert_true(btn.disabled)
	assert_eq(btn.text, "Max")
	assert_eq(_value_text("TrackValue_count"), "13", "no arrow when maxed (:470-471)")


func test_unaffordable_track_is_disabled() -> void:
	_progression.data.points = 10
	_open_weapons("blackhole")
	assert_true(_button("Track_radius").disabled)
	assert_eq(
		_button("Track_radius").text,
		UiTheme.group_digits(650 * ProgressionManager.PRICE_SCALE),
		"the plain price, disabled (user 2026-09-28; ADS R7)"
	)
	watch_signals(_armory)
	_button("Track_radius").pressed.emit()
	assert_signal_not_emitted(_armory, "state_changed", "upgrade_perk refused (:1162)")


func test_keystone_shows_its_keystone_cost_and_unlocks() -> void:
	_open_weapons("laser")
	var btn: Button = _button("Keystone_crossBeam")
	assert_eq(
		btn.text,
		UiTheme.group_digits(3500 * ProgressionManager.PRICE_SCALE),
		"KEYSTONE_COSTS.crossBeam (:507) × PRICE_SCALE (ADS R7)"
	)
	watch_signals(_armory)
	btn.pressed.emit()
	assert_true(_progression.data.perks.laser.cross_beam)
	assert_eq(_progression.data.points, 7331 - 3500 * ProgressionManager.PRICE_SCALE)
	assert_signal_emitted(_armory, "state_changed")
	assert_true(_button("Keystone_crossBeam").disabled)
	assert_eq(_button("Keystone_crossBeam").text, "Unlocked ✓")
	assert_true(
		ProgressionManager.new().data.perks.laser.cross_beam,
		"upgrade_perk saved (spec §8 M8 acceptance)"
	)


func test_starting_weapon_config_resolves_aliases() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:209-220
	assert_eq(_armory.get_starting_weapon_config(Types.WeaponType.VORTEX).id, "blackhole")
	assert_eq(_armory.get_starting_weapon_config(Types.WeaponType.SHIELD).id, "shield")
	assert_eq(_armory.get_starting_weapon_config(Types.WeaponType.FREEZE).name, "Freeze")


func test_ships_tab_lists_every_ship_with_the_right_action() -> void:
	# Defaults: classic/tactical/singularity unlocked, classic equipped (ProgressionManager.ts:455-457)
	_armory.open("ships")
	await get_tree().process_frame
	assert_eq(_label("ShipsPill").text, "Hull · 3 of 6 unlocked")
	_browse("Ship", "classic")
	assert_true(_button("EquippedShip_classic").disabled)
	_browse("Ship", "classic")
	assert_eq(_button("EquippedShip_classic").text, "Equipped")
	_browse("Ship", "tactical")
	assert_eq(_button("EquipShip_tactical").text, "Equip")
	_browse("Ship", "solar")
	# ADS R7: catalog prices are PRICE_SCALE times their figure.
	assert_eq(
		_button("BuyShip_solar").text, ArmoryUI.format_points(600 * ProgressionManager.PRICE_SCALE)
	)
	_browse("Ship", "solar")
	assert_false(_button("BuyShip_solar").disabled)
	_browse("Ship", "revenant")
	assert_eq(
		_button("BuyShip_revenant").text,
		ArmoryUI.format_points(2500 * ProgressionManager.PRICE_SCALE)
	)
	# ARMORY R7: one ship at a time; Next walks the whole catalog and wraps.
	var seen: Array[String] = []
	for i: int in range(7):
		for card: Node in _armory.find_children("Ship_*", "PanelContainer", true, false):
			seen.append(str(card.name).trim_prefix("Ship_"))
		_button("ShipNext").pressed.emit()
	var catalog: Array[String] = [
		"classic", "tactical", "singularity", "solar", "cyber", "shuriken", "revenant"
	]
	var start: int = catalog.find(seen[0])
	for i: int in range(7):
		assert_eq(seen[i], catalog[(start + i) % 7], "catalog order")
	assert_not_null(_armory.find_child("Ship_" + seen[0], true, false), "wrapped round")


func test_ship_card_shows_its_starting_weapon_by_catalog_name() -> void:
	_armory.open("ships")
	_browse("Ship", "revenant")
	var card: Control = _armory.find_child("Ship_revenant", true, false) as Control
	var loadout: Label = card.find_child("LoadoutName", true, false) as Label
	assert_eq(loadout.text, "Blackhole", "vortex is presented as Blackhole (:205-211)")


func test_equip_ship_saves_and_emits() -> void:
	_armory.open("ships")
	watch_signals(_armory)
	_browse("Ship", "tactical")
	_button("EquipShip_tactical").pressed.emit()
	assert_eq(_progression.data.equipped_cursor_id, "tactical")
	assert_signal_emitted(_armory, "state_changed")
	_browse("Ship", "tactical")
	assert_true(_button("EquippedShip_tactical").disabled, "re-rendered as equipped")
	assert_eq(ProgressionManager.new().data.equipped_cursor_id, "tactical", "persisted")


func _record_telemetry() -> RecordingTelemetryBackend:
	var rec: RecordingTelemetryBackend = RecordingTelemetryBackend.new()
	var previous: TelemetryBackend = Telemetry.backend
	Telemetry.backend = rec
	_displaced_backends.append(previous)
	return rec


func test_purchases_log_upgrade_buy() -> void:
	var rec: RecordingTelemetryBackend = _record_telemetry()
	_armory.open("ships")
	_browse("Ship", "solar")
	_button("BuyShip_solar").pressed.emit()
	# ADS R7: every price is PRICE_SCALE times its figure.
	var ship_cost: int = 600 * ProgressionManager.PRICE_SCALE
	var perk_cost: int = ProgressionManager.PERK_COSTS[3] * ProgressionManager.PRICE_SCALE
	assert_eq(
		rec.last_params("upgrade_buy"),
		{
			"kind": "ship",
			"id": "solar",
			"rank": 1,
			"cost": ship_cost,
			"balance_after": 7331 - ship_cost,
		}
	)
	_open_weapons("blackhole")
	_button("Track_duration").pressed.emit()
	assert_eq(
		rec.last_params("upgrade_buy"),
		{
			"kind": "perk",
			"id": "blackhole.duration",
			"rank": 4,
			"cost": perk_cost,
			"balance_after": 7331 - ship_cost - perk_cost,
		}
	)


func test_boost_purchase_logs_its_new_rank() -> void:
	var rec: RecordingTelemetryBackend = _record_telemetry()
	_armory.open("boosts")
	_button("Boost_hullCompact").pressed.emit()
	assert_eq(
		rec.last_params("upgrade_buy"),
		{
			"kind": "boost",
			"id": "hullCompact",
			"rank": 1,
			"cost": 800 * ProgressionManager.PRICE_SCALE,  # ADS R7
			"balance_after": 7331 - 800 * ProgressionManager.PRICE_SCALE,
		}
	)


func test_refused_purchase_logs_nothing() -> void:
	var rec: RecordingTelemetryBackend = _record_telemetry()
	_progression.data.points = 10
	_open_weapons("blackhole")
	_button("Track_radius").pressed.emit()
	assert_eq(rec.names.size(), 0)


func test_buy_ship_charges_and_unlocks() -> void:
	_armory.open("ships")
	_browse("Ship", "solar")
	_button("BuyShip_solar").pressed.emit()
	assert_true(_progression.data.unlocked_cursors.has("solar"))
	assert_eq(_progression.data.points, 7331 - 600 * ProgressionManager.PRICE_SCALE)
	assert_eq(
		_button("EquippedShip_solar").text, "Equipped", "buying equips (ProgressionManager.ts:720)"
	)
	_browse("Ship", "solar")
	assert_true(_button("EquippedShip_solar").disabled)
	assert_eq(_label("ShipsPill").text, "Hull · 4 of 6 unlocked")
	var reloaded: ProgressionManager = ProgressionManager.new()
	assert_true(reloaded.data.unlocked_cursors.has("solar"), "buy_ship saved")
	assert_eq(reloaded.data.equipped_cursor_id, "solar", "buy_ship's equip-on-purchase saved")


func test_unaffordable_ship_is_disabled() -> void:
	_progression.data.points = 100
	_armory.open("ships")
	_browse("Ship", "solar")
	assert_true(_button("BuyShip_solar").disabled)


func test_arena_tab_shows_both_catalogs_with_counts() -> void:
	_armory.open("arena")
	await get_tree().process_frame
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:779, :790 — counts use catalog length
	assert_eq(_label("ThemesPill").text, "Arena themes · 1 of 16 unlocked")
	_browse("Theme", "void")
	assert_true(_button("EquippedArena_void").disabled)
	_browse("Theme", "void")
	assert_eq(_button("EquippedArena_void").text, "Equipped")
	_browse("Theme", "synthwave")
	# ADS R7: catalog prices are PRICE_SCALE times their figure.
	assert_eq(
		_button("BuyArena_synthwave").text,
		ArmoryUI.format_points(400 * ProgressionManager.PRICE_SCALE)
	)
	_browse("Theme", "synthwave")
	assert_false(_button("BuyArena_synthwave").disabled)
	assert_eq(_label("EnemiesPill").text, "Enemy variations · 1 of 16 unlocked")
	_browse("Enemy", "classic")
	assert_true(_button("EquippedEnemy_classic").disabled)
	_browse("Enemy", "gold")
	assert_eq(
		_button("BuyEnemy_gold").text, ArmoryUI.format_points(1500 * ProgressionManager.PRICE_SCALE)
	)


func test_buy_then_equip_arena_theme() -> void:
	_armory.open("arena")
	_browse("Theme", "synthwave")
	_button("BuyArena_synthwave").pressed.emit()
	assert_true(_progression.data.unlocked_arena_themes.has("synthwave"))
	assert_eq(_progression.data.points, 7331 - 400 * ProgressionManager.PRICE_SCALE)
	assert_true(
		_button("EquippedArena_synthwave").disabled, "buying equips (ProgressionManager.ts:768-777)"
	)
	_browse("Theme", "nebula")
	_button("BuyArena_nebula").pressed.emit()
	watch_signals(_armory)
	_browse("Theme", "synthwave")
	_button("EquipArena_synthwave").pressed.emit()
	assert_eq(_progression.data.equipped_arena_theme_id, "synthwave")
	assert_signal_emit_count(_armory, "state_changed", 1)
	assert_eq(ProgressionManager.new().data.equipped_arena_theme_id, "synthwave", "persisted")


func test_buy_then_equip_enemy_skin() -> void:
	_armory.open("arena")
	watch_signals(_armory)
	_browse("Enemy", "toxic")
	_button("BuyEnemy_toxic").pressed.emit()
	assert_true(_progression.data.unlocked_enemy_skins.has("toxic"))
	assert_eq(
		_progression.data.equipped_enemy_skin_id,
		"toxic",
		"buying equips (ProgressionManager.ts:744-753)"
	)
	_browse("Enemy", "glitch")
	_button("BuyEnemy_glitch").pressed.emit()
	_browse("Enemy", "toxic")
	_button("EquipEnemy_toxic").pressed.emit()
	assert_eq(_progression.data.equipped_enemy_skin_id, "toxic")
	assert_eq(_label("EnemiesPill").text, "Enemy variations · 3 of 16 unlocked")
	assert_signal_emit_count(_armory, "state_changed", 3, "buy toxic, buy glitch, equip toxic")
	var reloaded: ProgressionManager = ProgressionManager.new()
	assert_true(reloaded.data.unlocked_enemy_skins.has("glitch"), "buy_enemy_skin saved")
	assert_eq(reloaded.data.equipped_enemy_skin_id, "toxic", "equip_enemy_skin saved")


func test_unaffordable_theme_is_disabled_and_locked() -> void:
	# ARMORY R6: a price the player cannot pay is disabled and carries the lock glyph.
	_progression.data.points = 0
	_armory.open("arena")
	_browse("Theme", "blueprint")
	assert_true(_button("BuyArena_blueprint").disabled)
	_browse("Theme", "blueprint")
	assert_not_null(_button("BuyArena_blueprint").icon, "lock glyph")
	_browse("Enemy", "void")
	assert_true(_button("BuyEnemy_void").disabled)
	_armory.open("ships")
	_browse("Ship", "solar")
	assert_true(_button("BuyShip_solar").disabled)
	_browse("Ship", "solar")
	assert_not_null(_button("BuyShip_solar").icon, "ships lock too")


## ARMORY R6 (user: "let the enemy ship and background be similar to ships"; ARMORY R5's
## "when you click on something it automatically purchases it"): the cards are ship cards
## whose only tap target is the action button, both sections on one page (no sub-tab).
func test_arena_cards_are_ship_cards_that_buy_only_from_the_button() -> void:
	_armory.open("arena")
	_browse("Theme", "synthwave")
	var card: Control = _armory.find_child("ArenaCard_synthwave", true, false) as Control
	var buttons: Array[Node] = card.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), 1, "just the action button")
	assert_eq(buttons[0].name, "BuyArena_synthwave")
	assert_not_null(_armory.find_child("ArenaDesc_synthwave", true, false), "a description")
	assert_not_null(_armory.find_child("ArenaPreview", true, false), "R7: the arena preview")
	_browse("Enemy", "classic")
	assert_eq(_button("EquippedEnemy_classic").theme_type_variation, "EquippedButton")
	assert_null(_armory.find_child("ArenaSwitch", true, false), "no Themes | Enemies switch")


func test_boosts_catalog_matches_the_ts() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:222-268
	var ids: Array[String] = []
	var max_ranks: Array[int] = []
	for b: ArmoryUI.BoostConfig in _armory.boosts_catalog:
		ids.append(b.id)
		max_ranks.append(b.max_rank)
	assert_eq(
		ids, ["extraLives", "hullCompact", "enemySlow", "scoreMultiplier", "pointsMultiplier"]
	)
	assert_eq(max_ranks, [2, 3, 3, 4, 4])
	assert_eq(_armory.boosts_catalog[1].effect, "-6% hitbox / rank")
	# PORT-NOTE: Callable.call() returns Variant; narrowed with `is int` rather
	# than cast, matching armory_ui.gd's current_rank/cost locals.
	var cost_value: Variant = _armory.boosts_catalog[0].get_cost.call()
	var extra_lives_cost: int = 0
	if cost_value is int:
		extra_lives_cost = cost_value
	assert_eq(
		extra_lives_cost,
		ProgressionManager.EXTRA_LIVES_COSTS[0] * ProgressionManager.PRICE_SCALE,
		"EXTRA_LIVES_COSTS[0] (ECON R2) × PRICE_SCALE (ADS R7)"
	)


func test_boosts_tab_shows_rank_and_cost() -> void:
	_armory.open("boosts")
	await get_tree().process_frame
	assert_eq(_filled_pips("BoostPips_extraLives"), 0)
	assert_eq(_armory.find_child("BoostPips_extraLives", true, false).get_child_count(), 2)
	# ADS R7: boost prices are PRICE_SCALE times the ladder.
	assert_eq(
		_button("Boost_extraLives").text,
		UiTheme.group_digits(2500 * ProgressionManager.PRICE_SCALE)
	)
	assert_eq(
		_button("Boost_pointsMultiplier").text,
		UiTheme.group_digits(1200 * ProgressionManager.PRICE_SCALE)
	)
	assert_false(_button("Boost_hullCompact").disabled)


func test_buying_a_boost_charges_saves_and_emits() -> void:
	_armory.open("boosts")
	watch_signals(_armory)
	_button("Boost_hullCompact").pressed.emit()
	assert_eq(_progression.data.hull_compact, 1)
	assert_eq(_progression.data.points, 7331 - 800 * ProgressionManager.PRICE_SCALE)
	assert_signal_emitted(_armory, "state_changed")
	assert_eq(_filled_pips("BoostPips_hullCompact"), 1)
	assert_eq(
		_button("Boost_hullCompact").text,
		UiTheme.group_digits(1600 * ProgressionManager.PRICE_SCALE),
		"next rung of HULL_COMPACT_COSTS, times PRICE_SCALE (ADS R7)"
	)
	assert_eq(ProgressionManager.new().data.hull_compact, 1, "persisted")


func test_maxed_boost_reads_maxed() -> void:
	_progression.data.extra_lives = 2
	_armory.open("boosts")
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:896 — cost === null ⇔ Types.ABSENT
	var btn: Button = _button("Boost_extraLives")
	assert_true(btn.disabled)
	assert_eq(btn.text, "Max")
	assert_eq(_filled_pips("BoostPips_extraLives"), 2)


func test_unaffordable_boost_is_disabled() -> void:
	_progression.data.points = 2500 * ProgressionManager.PRICE_SCALE - 1
	_armory.open("boosts")
	assert_true(_button("Boost_extraLives").disabled)
	assert_false(_button("Boost_hullCompact").disabled, "800 × PRICE_SCALE is affordable (ADS R7)")


func test_locked_keystone_is_dimmed_with_a_lock() -> void:
	# Ruling L: not unlocked and not affordable → LockedCard, lock glyph, disabled.
	_progression.data.points = 10
	_open_weapons("laser")
	var btn: Button = _button("Keystone_crossBeam")
	assert_true(btn.disabled)
	assert_not_null(btn.icon, "lock glyph (ArmoryWeapons.dc.html)")
	var card: PanelContainer = (
		_armory.find_child("KeystoneCard_crossBeam", true, false) as PanelContainer
	)
	assert_eq(card.theme_type_variation, &"LockedCard")


func test_track_row_carries_pips_for_its_rank() -> void:
	_open_weapons("blackhole")
	var card: Control = _armory.find_child("TrackCard_duration", true, false) as Control
	assert_not_null(card)
	assert_eq(_filled_pips("TrackPips_duration"), 3, "duration rank 3 of 5 (ArmoryUI.ts:453-457)")
	var pips: Node = _armory.find_child("TrackPips_duration", true, false)
	assert_eq(
		(pips.get_child(0) as ColorRect).color,
		WeaponIcons.ui_color_of(Types.WeaponType.VORTEX),
		"ARMORY R2: filled in the weapon colour"
	)


func test_weapon_detail_is_one_column_with_its_keystones() -> void:
	# ARMORY R1 (user: "a single column for weapon upgrade is fine").
	_open_weapons("blackhole")
	var column: VBoxContainer = _armory.find_child("UpgradeColumn", true, false) as VBoxContainer
	assert_not_null(column)
	var names: Array[String] = []
	for child: Node in column.get_children():
		names.append(str(child.name))
	assert_eq(names.slice(0, 3), ["TrackCard_duration", "TrackCard_radius", "TrackCard_gravity"])
	for key: String in ["supernovaCollapse", "eventHorizon", "darkHarvest"]:
		assert_true(names.has("KeystoneCard_" + key), "%s in the same column" % key)
	assert_null(_armory.find_child("InnateNote", true, false), "KEY R2: no innate row")
	assert_null(_armory.find_child("Keystone_invulnerableInside", true, false), "no Aegis to buy")


func test_every_weapon_lists_three_keystone_cards() -> void:
	for w: ArmoryUI.WeaponConfig in _armory.weapons_catalog:
		_open_weapons(w.id)
		assert_eq(_armory.find_children("KeystoneCard_*", "", true, false).size(), 3, w.id)


func test_can_buy_dot_marks_weapons_with_an_affordable_upgrade() -> void:
	_progression.data.points = 300 * ProgressionManager.PRICE_SCALE
	_open_weapons()
	assert_true(
		(_armory.find_child("CanBuy_lightning", true, false) as Control).visible,
		"250 × PRICE_SCALE (ADS R7)"
	)
	_progression.data.points = 100
	_armory.render()
	assert_false((_armory.find_child("CanBuy_lightning", true, false) as Control).visible)


func test_buying_a_rank_pops_its_new_pip() -> void:
	_open_weapons("blackhole")
	_button("Track_duration").pressed.emit()
	var pips: Node = _armory.find_child("TrackPips_duration", true, false)
	var newest: ColorRect = pips.get_child(3) as ColorRect
	assert_true(newest.has_meta("pop"), "ARMORY R2: rank 4's pip pops")
	assert_gt(newest.scale.y, 1.0, "starts tall, settles to 1")


func _hosted(size: Vector2, scale: float) -> ArmoryUI:
	var host: Control = Control.new()
	host.size = size
	add_child_autofree(host)
	var armory: ArmoryUI = ARMORY_SCENE.instantiate() as ArmoryUI
	host.add_child(armory)
	armory.bind(_progression, _settings)
	armory.set_ui_scale(scale)
	return armory


func _assert_tab_fits(tab: String, size: Vector2, scale: float) -> void:
	var armory: ArmoryUI = _hosted(size, scale)
	armory.open(tab)
	await get_tree().process_frame
	await get_tree().process_frame
	var outside: Array[String] = UiChecks.outside(armory, armory.get_global_rect())
	assert_true(outside.is_empty(), "%s fits %s: %s" % [tab, size, outside])
	var short: Array[String] = UiChecks.short_buttons(armory, UiTheme.TOUCH_TARGET * scale)
	assert_true(short.is_empty(), "%s rule 05 at %s: %s" % [tab, size, short])
	var header: Node = armory.find_child("Header", true, false)
	assert_true(UiChecks.overlapping_siblings(header).is_empty(), "header")


func test_weapons_tab_fits_the_board_frame() -> void:
	await _assert_tab_fits("weapons", Vector2(844, 390), 1.0)


func test_weapons_tab_fits_the_a55() -> void:
	await _assert_tab_fits("weapons", Vector2(2340, 1080), 1080.0 / 390.0)


func test_weapon_list_names_are_not_squeezed_to_one_pixel() -> void:
	# The list row's name label must expand to fill its HBox, or clip_text's
	# 1 px floor collapses it and the rank label rides up against the dot.
	var armory: ArmoryUI = _hosted(Vector2(844, 390), 1.0)
	armory.open("weapons")
	await get_tree().process_frame
	var row: Button = armory.find_child("Weapon_blackhole", true, false) as Button
	var rank_label: Label = armory.find_child("WeaponRank_blackhole", true, false) as Label
	var name_label: Label = null
	for node: Node in row.find_children("*", "Label", true, false):
		if node != rank_label:
			name_label = node as Label
			break
	assert_not_null(name_label, "the weapon name label must exist")
	assert_true(name_label.size.x > 1.0, "name label width %s must exceed 1 px" % name_label.size.x)
	assert_true(
		rank_label.global_position.x > name_label.global_position.x + name_label.size.x - 0.5,
		"WeaponRank_blackhole must sit to the right of the name label"
	)


func _slider(name: String) -> HSlider:
	var s: HSlider = _armory.find_child(name, true, false) as HSlider
	assert_not_null(s, "%s must exist" % name)
	return s


func test_handling_tab_shows_the_tuning_and_starts_the_preview() -> void:
	_armory.open("handling")
	await get_tree().process_frame
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:816
	assert_eq(_label("TurnValue").text, "1.0×")
	assert_eq(_label("TiltValue").text, "1.0×")
	var turn: HSlider = _slider("TurnSlider")
	assert_eq(turn.min_value, 0.5)
	assert_eq(turn.max_value, 2.0)
	assert_eq(turn.step, 0.1)
	# Interface spec §6.4 + 2026-09-23 ruling: 0.5–2.0 slider, stored clamp 0.4–2.5.
	var tilt: HSlider = _slider("TiltSlider")
	assert_eq(tilt.min_value, 0.5)
	assert_eq(tilt.max_value, 2.0)
	assert_eq(tilt.step, 0.1)
	assert_null(_armory.find_child("DeadzoneSlider", true, false), "deadzone left the UI")
	var preview: HandlingPreview = (
		_armory.find_child("HandlingPreview", true, false) as HandlingPreview
	)
	assert_not_null(preview)
	assert_true(preview.is_running(), "initHandlingPreview on the handling tab (:387-389)")


func test_the_speed_slider_says_what_it_does() -> void:
	# HANDLING R1 (2026-10-12): tuning.sensitivity scales top speed, never turning
	# (player_ship.gd); the TS's "Turn rate" / "Higher turns sharper." misnamed it.
	_armory.open("handling")
	var field: Node = _label("TurnValue").get_parent().get_parent()
	var texts: Array[String] = []
	for label: Node in field.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_has(texts, "Top speed")
	assert_has(texts, "Higher moves faster.")
	assert_does_not_have(texts, "Turn rate")


func test_sliders_write_through_and_emit_without_rerender() -> void:
	_armory.open("handling")
	watch_signals(_armory)
	var preview: HandlingPreview = (
		_armory.find_child("HandlingPreview", true, false) as HandlingPreview
	)
	_slider("TurnSlider").value = 1.7
	assert_almost_eq(_progression.data.tuning.sensitivity, 1.7, 0.0001)
	assert_eq(_label("TurnValue").text, "1.7×")
	_slider("TiltSlider").value = 1.4
	assert_almost_eq(_settings.tilt_sensitivity, 1.4, 0.0001)
	assert_eq(_label("TiltValue").text, "1.4×")
	assert_signal_emit_count(_armory, "state_changed", 2)
	var same: HandlingPreview = (
		_armory.find_child("HandlingPreview", true, false) as HandlingPreview
	)
	assert_eq(same, preview, "slider input updates the pill in place, no render() (:1264-1270)")
	var reloaded: ProgressionManager = ProgressionManager.new()
	assert_almost_eq(reloaded.data.tuning.sensitivity, 1.7, 0.0001, "slider write-through saved")
	assert_almost_eq(
		ControlSettings.new().tilt_sensitivity, 1.4, 0.0001, "tilt write-through saved"
	)


func test_reset_restores_defaults_and_rerenders() -> void:
	_progression.set_sensitivity(1.9)
	_progression.set_deadzone(12.0)
	_settings.tilt_sensitivity = 1.8
	_armory.open("handling")
	watch_signals(_armory)
	_button("ResetButton").pressed.emit()
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:1286-1291
	assert_eq(_progression.data.tuning.sensitivity, 1.0)
	assert_eq(_progression.data.tuning.deadzone, 4.0, "deadzone still resets (Ruling O)")
	assert_eq(_settings.tilt_sensitivity, 1.0, "tilt resets to control_settings.gd:27")
	assert_signal_emitted(_armory, "state_changed")
	assert_eq(_slider("TurnSlider").value, 1.0)
	assert_eq(_label("TiltValue").text, "1.0×")


func test_calibrate_tilt_button_requests_calibration() -> void:
	# Interface spec §5: Calibrate tilt → GameRoot.calibrate_gyro().
	_armory.open("handling")
	watch_signals(_armory)
	_button("CalibrateTiltButton").pressed.emit()
	assert_signal_emitted(_armory, "calibrate_requested")


func test_handling_tab_fits_the_board_frame() -> void:
	await _assert_tab_fits("handling", Vector2(844, 390), 1.0)


func test_handling_tab_fits_the_a55() -> void:
	await _assert_tab_fits("handling", Vector2(2340, 1080), 1080.0 / 390.0)


func test_boosts_tab_fits_the_board_frame() -> void:
	await _assert_tab_fits("boosts", Vector2(844, 390), 1.0)


func test_boosts_tab_fits_the_a55() -> void:
	await _assert_tab_fits("boosts", Vector2(2340, 1080), 1080.0 / 390.0)


func test_leaving_the_handling_tab_stops_the_preview() -> void:
	_armory.open("handling")
	var preview: HandlingPreview = (
		_armory.find_child("HandlingPreview", true, false) as HandlingPreview
	)
	_armory.close()
	assert_false(preview.is_running(), "close() → stopHandlingPreview (:318)")


func test_handling_without_settings_hides_the_tilt_slider() -> void:
	# bind(p) alone: `s` defaults to null, which hides the tilt field.
	var armory: ArmoryUI = ARMORY_SCENE.instantiate() as ArmoryUI
	add_child_autofree(armory)
	armory.bind(_progression)
	armory.open("handling")
	assert_null(armory.find_child("TiltSlider", true, false))
	(armory.find_child("ResetButton", true, false) as Button).pressed.emit()
	assert_eq(_progression.data.tuning.sensitivity, 1.0, "Reset works without settings")


func test_ship_meter_fraction() -> void:
	# Interface spec §6.4 (ruled): value ÷ the catalog's largest value of that stat.
	var values: Array[float] = [1.0, 1.2, 0.4, 1.9]
	assert_almost_eq(ArmoryUI.ship_meter_fraction(1.9, values), 1.0, 0.0001)
	assert_almost_eq(ArmoryUI.ship_meter_fraction(0.95, values), 0.5, 0.0001)
	var none: Array[float] = []
	assert_eq(ArmoryUI.ship_meter_fraction(1.0, none), 0.0)


func test_ship_cards_carry_normalised_meters() -> void:
	_armory.open("ships")
	var top_hitbox: float = 0.0
	for s: ProgressionManager.ShipSkinConfig in _progression.ship_catalog:
		top_hitbox = maxf(top_hitbox, s.hitbox_scale)
	var meter: ProgressBar = _armory.find_child("HitboxMeter_classic", true, false) as ProgressBar
	assert_almost_eq(meter.value, 1.0 / top_hitbox, 0.0001, "classic hitbox_scale 1.0")
	assert_not_null(_armory.find_child("TurnMeter_classic", true, false))


## ARMORY R7 (user: "show only 1 with arrow icons on the left and right which cycles ...
## on the right hand side - show what it looks like in the arena"; "make it also the same
## for ships"): the carousels show one item, wrap both ways, and redraw the preview.
func test_carousels_cycle_one_item_and_preview_it() -> void:
	_armory.open("arena")
	assert_eq(_armory.find_children("ArenaCard_*", "PanelContainer", true, false).size(), 1)
	assert_eq(_label("ThemePager").text, "1 / 16")
	_button("ThemePrev").pressed.emit()
	assert_eq(_label("ThemePager").text, "16 / 16", "Prev wraps to the last")
	_button("ThemeNext").pressed.emit()
	assert_not_null(_armory.find_child("ArenaCard_void", true, false))
	var preview: ArenaPreview = _armory.find_child("ArenaPreview", true, false) as ArenaPreview
	var void_grid: Color = preview.grid_color
	_button("ThemeNext").pressed.emit()
	preview = _armory.find_child("ArenaPreview", true, false) as ArenaPreview
	assert_ne(preview.grid_color, void_grid, "the preview shows the browsed theme")
	assert_eq(_progression.data.equipped_arena_theme_id, "void", "browsing equips nothing")
	_button("EnemyNext").pressed.emit()
	assert_not_null(_armory.find_child("EnemyCard_toxic", true, false))
	_armory.open("ships")
	assert_eq(_armory.find_children("Ship_*", "PanelContainer", true, false).size(), 1)
	assert_not_null(_armory.find_child("ArenaPreview", true, false), "ships preview too")
	_armory.open("arena")
	assert_not_null(_armory.find_child("ArenaCard_void", true, false), "open resets to equipped")


## Steps `kind`'s carousel (Ship, Theme, Enemy) until `id` is the card shown.
func _browse(kind: String, id: String) -> void:
	var prefixes: Dictionary[String, String] = {
		"Ship": "Ship_", "Theme": "ArenaCard_", "Enemy": "EnemyCard_"
	}
	for i: int in range(20):
		if _armory.find_child(prefixes[kind] + id, true, false) != null:
			return
		_button(kind + "Next").pressed.emit()
	fail_test("no %s card %s" % [kind, id])


func test_owned_theme_offers_equip() -> void:
	_armory.open("arena")
	_browse("Theme", "synthwave")
	_button("BuyArena_synthwave").pressed.emit()
	_browse("Theme", "nebula")
	_button("BuyArena_nebula").pressed.emit()
	_browse("Theme", "synthwave")
	assert_eq(_button("EquipArena_synthwave").text, "Equip")
	_browse("Theme", "synthwave")
	assert_eq(_button("EquipArena_synthwave").theme_type_variation, "EquipButton")
	_browse("Theme", "synthwave")
	assert_false(_button("EquipArena_synthwave").disabled)


func test_ships_tab_fits_the_board_frame() -> void:
	await _assert_tab_fits("ships", Vector2(844, 390), 1.0)


func test_ships_tab_fits_the_a55() -> void:
	await _assert_tab_fits("ships", Vector2(2340, 1080), 1080.0 / 390.0)


func test_arena_tab_fits_the_board_frame() -> void:
	await _assert_tab_fits("arena", Vector2(844, 390), 1.0)


func test_arena_tab_fits_the_a55() -> void:
	await _assert_tab_fits("arena", Vector2(2340, 1080), 1080.0 / 390.0)


## Every control under a scroll view that would swallow a touch, except the ones
## a drag must operate (sliders, the handling preview).
func _swallowers_in_scrolls() -> Array[String]:
	var out: Array[String] = []
	var scrolls: Array[Node] = _armory.find_children("*", "ScrollContainer", true, false)
	for scroll: Node in scrolls:
		var stack: Array[Node] = scroll.get_children()
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			var c: Control = n as Control
			if c == null or c is ScrollContainer or c is Range or c is HandlingPreview:
				continue
			if c.mouse_filter == Control.MOUSE_FILTER_STOP:
				out.append("%s (%s)" % [c.name, c.get_class()])
	return out


func test_a_drag_starting_on_any_card_or_button_reaches_the_scroll_view() -> void:
	# A55 report 2026-09-26: "I cannot drag or move the armory". A STOP control
	# swallows the touch, so its ScrollContainer never sees the drag.
	for tab: String in ["weapons", "ships", "arena", "handling", "boosts"]:
		_armory.open(tab)
		await get_tree().process_frame
		assert_eq(_swallowers_in_scrolls(), [] as Array[String], "%s tab" % tab)


func test_sliders_still_take_their_own_drags() -> void:
	_armory.open("handling")
	await get_tree().process_frame
	var sliders: Array[Node] = _armory.find_children("*", "HSlider", true, false)
	assert_gt(sliders.size(), 0)
	for s: Node in sliders:
		assert_eq((s as Control).mouse_filter, Control.MOUSE_FILTER_STOP, s.name)


func test_upgrade_value_labels_have_width_on_screen() -> void:
	# A clipping label inside the value HBox collapsed to 0 px on device (T6 screenshot).
	var armory: ArmoryUI = _hosted(Vector2(844.0, 390.0), 1.0)
	armory.open("weapons")
	await get_tree().process_frame
	await get_tree().process_frame
	var value: Control = armory.find_child("TrackValue_duration", true, false) as Control
	assert_not_null(value)
	for label: Node in value.get_children():
		assert_gt((label as Control).size.x, 4.0, "'%s' is drawn" % (label as Label).text)


func test_boosts_are_one_column_with_icons_and_now_next_values() -> void:
	# ARMORY R3.
	_armory.open("boosts")
	await get_tree().process_frame
	var list: VBoxContainer = _armory.find_child("BoostList", true, false) as VBoxContainer
	assert_not_null(list)
	assert_eq(list.get_child_count(), 5, "one row per boost, stacked")
	assert_eq(_value_text("BoostValue_extraLives"), "lives 1 → 2")
	assert_eq(_value_text("BoostValue_hullCompact"), "hitbox 100% → 94%")
	assert_eq(_value_text("BoostValue_enemySlow"), "enemy speed 100% → 96%")
	assert_eq(_value_text("BoostValue_pointsMultiplier"), "points ×1.0 → ×1.1")
	var icon: TextureRect = (
		(
			(_armory.find_child("BoostCard_hullCompact", true, false) as Node)
			. find_children("*", "TextureRect", true, false)[0]
		)
		as TextureRect
	)
	assert_eq(icon.texture, WeaponIcons.texture("hullCompact", icon.texture.get_width()))


func test_maxed_boost_shows_only_its_value() -> void:
	_progression.data.hull_compact = 3
	_armory.open("boosts")
	assert_eq(_value_text("BoostValue_hullCompact"), "hitbox 82%", "no arrow when maxed")


## ARMORY R7: both Arena carousels and the Ships carousel fit a phone without scrolling.
func test_showcase_tabs_fit_without_scrolling() -> void:
	for size: Vector2 in [Vector2(2340.0, 1080.0), Vector2(1600.0, 720.0)]:
		var scale: float = HudController.ui_scale_for(size)
		for tab: String in ["arena", "ships", "handling"]:
			var armory: ArmoryUI = _hosted(size, scale)
			armory.open(tab)
			await get_tree().process_frame
			await get_tree().process_frame
			var body: ScrollContainer = (
				armory.find_child("ScrollBody", true, false) as ScrollContainer
			)
			var need: float = (body.get_child(0) as Control).get_combined_minimum_size().y
			assert_lte(need, body.size.y, "%s %s: %.0f of %.0f px" % [tab, size, need, body.size.y])


## TOUCH R1 (player: "is the stick control radius configurable"): Handling has a Stick
## size slider that saves ControlSettings.stick_size, and Reset puts it back.
func test_handling_has_a_stick_size_slider() -> void:
	_armory.open("handling")
	var slider: HSlider = _armory.find_child("StickSlider", true, false) as HSlider
	assert_not_null(slider)
	assert_eq(_label("StickValue").text, "100%")
	slider.value = 0.7
	assert_almost_eq(_settings.stick_size, 0.7, 0.0001)
	assert_eq(_label("StickValue").text, "70%")
	assert_almost_eq(ControlSettings.new().stick_size, 0.7, 0.0001, "saved")
	_button("ResetButton").pressed.emit()
	assert_eq(_settings.stick_size, 1.0, "Reset restores the default stick")


## DIVERGENCE(THEME R2): the preview draws the browsed theme's pattern, like the run.
func test_arena_preview_carries_the_theme_pattern() -> void:
	_armory.open("arena")
	_browse("Theme", "arctic")
	var preview: ArenaPreview = _armory.find_child("ArenaPreview", true, false) as ArenaPreview
	var arctic: ProgressionManager.ArenaThemeConfig = _progression.arena_theme_catalog[6]
	assert_eq(arctic.id, "arctic")
	var pattern: int = preview.background_material().get_shader_parameter("pattern")
	assert_eq(pattern, int(arctic.pattern))
