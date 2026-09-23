# gdlint:disable=max-public-methods
## test_armory_ui.gd
## PORTS: nothing — new file, covers src/ui/armory_ui.gd, armory_theme.gd and
## scenes/armory.tscn
extends GutTest
## Proves the Armory shell: theme tokens, open/close, the tab aliases, the
## balance readout, and (Tasks 2-5) every purchase path from a tapped button.

const ARMORY_SCENE: PackedScene = preload("res://scenes/armory.tscn")

var _armory: ArmoryUI = null
var _progression: ProgressionManager = null
var _settings: ControlSettings = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))
	_remove(ControlSettings.SETTINGS_PATH)
	_progression = ProgressionManager.new()
	_settings = ControlSettings.new()
	_armory = ARMORY_SCENE.instantiate() as ArmoryUI
	add_child_autofree(_armory)
	_armory.bind(_progression, _settings)
	await get_tree().process_frame


func after_each() -> void:
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
		if (pip as ColorRect).color == UiTheme.COLOR_ION:
			filled += 1
	return filled


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
	assert_eq(blackhole.dot, Color("#A78BFA"))
	assert_eq(blackhole.tracks.size(), 3)
	assert_eq(blackhole.tracks[2].key, "gravity")
	assert_eq(blackhole.tracks[2].effect, "+20% / rank")
	assert_eq(blackhole.keystones[1].key, "supernovaCollapse")
	var freeze: ArmoryUI.WeaponConfig = _armory.weapons_catalog[4]
	assert_eq(freeze.name, "Shockwave", "the freeze weapon is presented as Shockwave (:161)")
	assert_eq(freeze.tracks.size(), 1)
	for w: ArmoryUI.WeaponConfig in _armory.weapons_catalog:
		for t: ArmoryUI.WeaponTrack in w.tracks:
			assert_true(
				Tuning.weapon_tuning[w.id].has(t.key),
				"%s.%s is a WEAPON_TUNING track" % [w.id, t.key]
			)
			assert_eq(t.max_rank, 5)
		for k: ArmoryUI.WeaponKeystone in w.keystones:
			# PORT-NOTE: blackhole's invulnerableInside is absent from KEYSTONE_COSTS
			# (WeaponTuning.ts:73-87) and priced by the fallback at ProgressionManager.ts:556.
			if k.key == "invulnerableInside":
				assert_eq(
					_progression.get_perk_cost(0, true, k.key),
					2500,
					"invulnerableInside uses the 2500 fallback (ProgressionManager.ts:556)"
				)  # PORT: web/src/tilt-to-live/ProgressionManager.ts:556
			else:
				assert_true(Tuning.KEYSTONE_COSTS.has(k.key), "%s is a KEYSTONE_COSTS key" % k.key)


func test_weapons_tab_lists_seven_weapons_with_primary_rank() -> void:
	_open_weapons()
	await get_tree().process_frame
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:429-431 — duration, else count, else radius, else 0
	assert_eq(_label("WeaponRank_blackhole").text, "3/5", "blackhole.duration = 3 at defaults")
	assert_eq(_label("WeaponRank_missiles").text, "5/5", "missiles.count = 5")
	assert_eq(_label("WeaponRank_nuke").text, "1/5", "nuke has no duration/count → radius = 1")
	assert_eq(_label("WeaponRank_lightning").text, "0/5", "lightning has none of the three → 0")
	assert_true(_button("Weapon_blackhole").button_pressed, "selected item is active")


func test_selecting_a_weapon_rerenders_its_detail() -> void:
	_open_weapons()
	_button("Weapon_laser").pressed.emit()
	assert_eq(_armory.selected_weapon_id, "laser")
	assert_not_null(_armory.find_child("Track_length", true, false))
	assert_not_null(_armory.find_child("Keystone_crossBeam", true, false))
	assert_eq(
		_label("InvestedValue").text,
		"900",
		"laser.length = 2 → 300 + 600 (ProgressionManager.ts:566-571)"
	)


func test_track_readout_shows_current_and_next_value() -> void:
	_open_weapons("blackhole")
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:459-472 — duration rank 3: 4.8 + 0.5*3 → 6.3s → 6.8s
	assert_eq(_label("TrackValue_duration").text, "6.3s → 6.8s")
	assert_eq(_button("Track_duration").text, "1,800", "rank 3 costs costs[3] (:450, :558)")
	assert_false(_button("Track_duration").disabled)


func test_buying_a_track_rank_charges_saves_and_emits() -> void:
	_open_weapons("blackhole")
	watch_signals(_armory)
	_button("Track_duration").pressed.emit()
	assert_eq(_progression.data.perks.blackhole.duration, 4)
	assert_eq(_progression.data.points, 7331 - 1800)
	assert_signal_emitted(_armory, "state_changed")
	assert_eq(_label("BalanceLabel").text, UiTheme.group_digits(7331 - 1800), "re-rendered (:1164)")
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
	assert_eq(_label("TrackValue_count").text, "13", "no arrow when maxed (:470-471)")


func test_unaffordable_track_is_disabled() -> void:
	_progression.data.points = 10
	_open_weapons("blackhole")
	assert_true(_button("Track_radius").disabled)
	watch_signals(_armory)
	_button("Track_radius").pressed.emit()
	assert_signal_not_emitted(_armory, "state_changed", "upgrade_perk refused (:1162)")


func test_keystone_shows_its_keystone_cost_and_unlocks() -> void:
	_open_weapons("laser")
	var btn: Button = _button("Keystone_crossBeam")
	assert_eq(btn.text, "3,500", "KEYSTONE_COSTS.crossBeam (:507)")
	watch_signals(_armory)
	btn.pressed.emit()
	assert_true(_progression.data.perks.laser.cross_beam)
	assert_eq(_progression.data.points, 7331 - 3500)
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
	assert_eq(_armory.get_starting_weapon_config(Types.WeaponType.FREEZE).name, "Shockwave")


func test_ships_tab_lists_every_ship_with_the_right_action() -> void:
	# Defaults: classic/tactical/singularity unlocked, classic equipped (ProgressionManager.ts:455-457)
	_armory.open("ships")
	await get_tree().process_frame
	assert_eq(_label("ShipsPill").text, "Hull · 3 of 6 unlocked")
	assert_true(_button("EquippedShip_classic").disabled)
	assert_eq(_button("EquippedShip_classic").text, "Equipped")
	assert_eq(_button("EquipShip_tactical").text, "Equip")
	assert_eq(_button("BuyShip_solar").text, "600 pts")
	assert_false(_button("BuyShip_solar").disabled)
	assert_eq(_button("BuyShip_revenant").text, "2,500 pts")
	for id: String in [
		"classic", "tactical", "singularity", "solar", "cyber", "shuriken", "revenant"
	]:
		assert_not_null(_armory.find_child("Ship_" + id, true, false), id)


func test_ship_card_shows_its_starting_weapon_by_catalog_name() -> void:
	_armory.open("ships")
	var card: Control = _armory.find_child("Ship_revenant", true, false) as Control
	var loadout: Label = card.find_child("LoadoutName", true, false) as Label
	assert_eq(loadout.text, "Blackhole", "vortex is presented as Blackhole (:205-211)")


func test_equip_ship_saves_and_emits() -> void:
	_armory.open("ships")
	watch_signals(_armory)
	_button("EquipShip_tactical").pressed.emit()
	assert_eq(_progression.data.equipped_cursor_id, "tactical")
	assert_signal_emitted(_armory, "state_changed")
	assert_true(_button("EquippedShip_tactical").disabled, "re-rendered as equipped")
	assert_eq(ProgressionManager.new().data.equipped_cursor_id, "tactical", "persisted")


func test_buy_ship_charges_and_unlocks() -> void:
	_armory.open("ships")
	_button("BuyShip_solar").pressed.emit()
	assert_true(_progression.data.unlocked_cursors.has("solar"))
	assert_eq(_progression.data.points, 7331 - 600)
	assert_eq(
		_button("EquippedShip_solar").text, "Equipped", "buying equips (ProgressionManager.ts:720)"
	)
	assert_true(_button("EquippedShip_solar").disabled)
	assert_eq(_label("ShipsPill").text, "Hull · 4 of 6 unlocked")
	var reloaded: ProgressionManager = ProgressionManager.new()
	assert_true(reloaded.data.unlocked_cursors.has("solar"), "buy_ship saved")
	assert_eq(reloaded.data.equipped_cursor_id, "solar", "buy_ship's equip-on-purchase saved")


func test_unaffordable_ship_is_disabled() -> void:
	_progression.data.points = 100
	_armory.open("ships")
	assert_true(_button("BuyShip_solar").disabled)


func test_arena_tab_shows_both_catalogs_with_counts() -> void:
	_armory.open("arena")
	await get_tree().process_frame
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:779, :790 — counts use catalog length
	assert_eq(_label("ThemesPill").text, "Arena Themes · 1 of 6 unlocked")
	assert_eq(_label("EnemiesPill").text, "Enemy Variations · 1 of 6 unlocked")
	assert_true(_button("EquippedArena_void").disabled)
	assert_eq(_label("ArenaState_void").text, "✓ Equipped")
	assert_eq(_label("ArenaState_synthwave").text, "400 pts")
	assert_false(_button("BuyArena_synthwave").disabled)
	assert_true(_button("EquippedEnemy_classic").disabled)
	assert_eq(_label("EnemyState_gold").text, "1,500 pts")


func test_buy_then_equip_arena_theme() -> void:
	_armory.open("arena")
	_button("BuyArena_synthwave").pressed.emit()
	assert_true(_progression.data.unlocked_arena_themes.has("synthwave"))
	assert_eq(_progression.data.points, 7331 - 400)
	assert_eq(
		_label("ArenaState_synthwave").text,
		"✓ Equipped",
		"buying equips (ProgressionManager.ts:768-777)"
	)
	assert_true(_button("EquippedArena_synthwave").disabled)
	_button("BuyArena_nebula").pressed.emit()
	watch_signals(_armory)
	_button("EquipArena_synthwave").pressed.emit()
	assert_eq(_progression.data.equipped_arena_theme_id, "synthwave")
	assert_signal_emit_count(_armory, "state_changed", 1)
	assert_eq(ProgressionManager.new().data.equipped_arena_theme_id, "synthwave", "persisted")


func test_buy_then_equip_enemy_skin() -> void:
	_armory.open("arena")
	watch_signals(_armory)
	_button("BuyEnemy_toxic").pressed.emit()
	assert_true(_progression.data.unlocked_enemy_skins.has("toxic"))
	assert_eq(
		_progression.data.equipped_enemy_skin_id,
		"toxic",
		"buying equips (ProgressionManager.ts:744-753)"
	)
	_button("BuyEnemy_glitch").pressed.emit()
	_button("EquipEnemy_toxic").pressed.emit()
	assert_eq(_progression.data.equipped_enemy_skin_id, "toxic")
	assert_eq(_label("EnemiesPill").text, "Enemy Variations · 3 of 6 unlocked")
	assert_signal_emit_count(_armory, "state_changed", 3, "buy toxic, buy glitch, equip toxic")
	var reloaded: ProgressionManager = ProgressionManager.new()
	assert_true(reloaded.data.unlocked_enemy_skins.has("glitch"), "buy_enemy_skin saved")
	assert_eq(reloaded.data.equipped_enemy_skin_id, "toxic", "equip_enemy_skin saved")


func test_unaffordable_theme_is_disabled() -> void:
	_progression.data.points = 0
	_armory.open("arena")
	assert_true(_button("BuyArena_blueprint").disabled)
	assert_true(_button("BuyEnemy_void").disabled)


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
	assert_eq(extra_lives_cost, 4000, "EXTRA_LIVES_COSTS[0]")


func test_boosts_tab_shows_rank_and_cost() -> void:
	_armory.open("boosts")
	await get_tree().process_frame
	assert_eq(_filled_pips("BoostPips_extraLives"), 0)
	assert_eq(_armory.find_child("BoostPips_extraLives", true, false).get_child_count(), 2)
	assert_eq(_button("Boost_extraLives").text, "4,000")
	assert_eq(_button("Boost_pointsMultiplier").text, "2,500")
	assert_false(_button("Boost_hullCompact").disabled)


func test_buying_a_boost_charges_saves_and_emits() -> void:
	_armory.open("boosts")
	watch_signals(_armory)
	_button("Boost_hullCompact").pressed.emit()
	assert_eq(_progression.data.hull_compact, 1)
	assert_eq(_progression.data.points, 7331 - 1500)
	assert_signal_emitted(_armory, "state_changed")
	assert_eq(_filled_pips("BoostPips_hullCompact"), 1)
	assert_eq(_button("Boost_hullCompact").text, "3,000", "next rung of HULL_COMPACT_COSTS")
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
	_progression.data.points = 3999
	_armory.open("boosts")
	assert_true(_button("Boost_extraLives").disabled)
	assert_false(_button("Boost_hullCompact").disabled, "1,500 is affordable")


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
	var filled: int = 0
	for node: Node in card.find_children("*", "ColorRect", true, false):
		if (node as ColorRect).color == UiTheme.COLOR_ION:
			filled += 1
	assert_eq(filled, 3, "duration rank 3 of 5 (ArmoryUI.ts:453-457)")


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


func test_ship_and_arena_rows_scroll_sideways() -> void:
	_armory.open("ships")
	var ships: ScrollContainer = _armory.find_child("ShipsRow", true, false) as ScrollContainer
	assert_eq(ships.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	_armory.open("arena")
	for row: String in ["ThemesRow", "EnemiesRow"]:
		var scroll: ScrollContainer = _armory.find_child(row, true, false) as ScrollContainer
		assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, row)


func test_owned_theme_reads_owned() -> void:
	_armory.open("arena")
	_button("BuyArena_synthwave").pressed.emit()
	_button("BuyArena_nebula").pressed.emit()
	assert_eq(_label("ArenaState_synthwave").text, "Owned")
	assert_false(_button("EquipArena_synthwave").disabled)


func test_ships_tab_fits_the_board_frame() -> void:
	await _assert_tab_fits("ships", Vector2(844, 390), 1.0)


func test_ships_tab_fits_the_a55() -> void:
	await _assert_tab_fits("ships", Vector2(2340, 1080), 1080.0 / 390.0)


func test_arena_tab_fits_the_board_frame() -> void:
	await _assert_tab_fits("arena", Vector2(844, 390), 1.0)


func test_arena_tab_fits_the_a55() -> void:
	await _assert_tab_fits("arena", Vector2(2340, 1080), 1080.0 / 390.0)
