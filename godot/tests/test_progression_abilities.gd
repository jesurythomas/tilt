## test_progression_abilities.gd
## PORTS: nothing — new file, covers DASH R4 and ITEM R1/R2 in src/meta/progression_manager.gd
extends GutTest
## Proves the dash upgrade ladders (20 → 15 s cooldown, 2.0 → 5.0 s shield), item buying and
## the two-slot loadout, their save round trip, and the load-time clean-up of a bad save.

var _pm: ProgressionManager = null


func _remove_save() -> void:
	var absolute: String = ProjectSettings.globalize_path(ProgressionManager.SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove_save()
	_pm = ProgressionManager.new()
	_pm.data.points = 100000


func after_each() -> void:
	_remove_save()


func test_a_fresh_save_has_the_base_dash_and_no_items() -> void:
	var fresh: ProgressionManager = ProgressionManager.new()
	assert_almost_eq(fresh.get_dash_cooldown(), 20.0, 0.0001, "user: every 20 seconds")
	assert_almost_eq(fresh.get_dash_shield(), 2.0, 0.0001, "user: shielded for 2 seconds")
	assert_eq(fresh.data.unlocked_items, [] as Array[String])
	assert_eq(fresh.data.equipped_items, [] as Array[String])


func test_cooldown_ranks_reach_fifteen_seconds_and_stop() -> void:
	var seen: Array[float] = []
	for i: int in range(ProgressionManager.DASH_COOLDOWN_RANKS):
		assert_eq(
			_pm.get_dash_cooldown_cost(), _pm.get_perk_cost(i), "priced as weapon rank %d" % i
		)
		assert_true(_pm.buy_dash_cooldown())
		seen.append(_pm.get_dash_cooldown())
	assert_eq(seen, [19.0, 18.0, 17.0, 16.0, 15.0] as Array[float])
	assert_eq(_pm.get_dash_cooldown_cost(), Types.ABSENT, "user: 15 minimum")
	assert_false(_pm.buy_dash_cooldown())
	assert_almost_eq(_pm.get_dash_cooldown(), 15.0, 0.0001)


func test_shield_ranks_add_half_a_second_up_to_five() -> void:
	var seen: Array[float] = []
	for i: int in range(ProgressionManager.DASH_SHIELD_RANKS):
		assert_true(_pm.buy_dash_shield())
		seen.append(_pm.get_dash_shield())
	assert_eq(seen, [2.5, 3.0, 3.5, 4.0, 4.5, 5.0] as Array[float])
	assert_eq(_pm.get_dash_shield_cost(), Types.ABSENT, "user: a max of 5 seconds")
	assert_false(_pm.buy_dash_shield())


func test_a_dash_rank_needs_the_points() -> void:
	_pm.data.points = _pm.get_dash_shield_cost() - 1
	assert_false(_pm.buy_dash_shield())
	assert_eq(_pm.data.dash.shield, 0)
	_pm.data.points += 1
	assert_true(_pm.buy_dash_shield())
	assert_eq(_pm.data.points, 0)


func test_every_item_is_priced_at_its_table_figure_times_price_scale() -> void:
	for id: String in ProgressionManager.ITEM_COSTS:
		assert_eq(
			_pm.get_item_cost(id),
			ProgressionManager.ITEM_COSTS[id] * ProgressionManager.PRICE_SCALE,
			"ADS R7 scale on %s" % id
		)
		assert_ne(WeaponIcons.weapon_type(id), Types.ABSENT, "%s is a power-up" % id)
	assert_eq(_pm.get_item_cost("ghost"), Types.ABSENT)
	assert_false(_pm.buy_item("ghost"))


func test_buying_items_fills_the_two_slots_then_only_unlocks() -> void:
	assert_true(_pm.buy_item("blackhole"))
	assert_true(_pm.buy_item("nuke"))
	assert_true(_pm.buy_item("shield"))
	assert_eq(_pm.data.unlocked_items, ["blackhole", "nuke", "shield"] as Array[String])
	assert_eq(_pm.data.equipped_items, ["blackhole", "nuke"] as Array[String], "2 max")
	assert_false(_pm.buy_item("nuke"), "bought once")


func test_equip_and_unequip_keep_two_slots_in_order() -> void:
	for id: String in ["blackhole", "nuke", "shield"]:
		_pm.buy_item(id)
	assert_false(_pm.equip_item("shield"), "both slots full")
	assert_false(_pm.equip_item("laser"), "not bought")
	assert_true(_pm.unequip_item("blackhole"))
	assert_eq(_pm.data.equipped_items, ["nuke"] as Array[String], "the later slot moves up")
	assert_false(_pm.unequip_item("blackhole"))
	assert_true(_pm.equip_item("shield"))
	assert_eq(_pm.data.equipped_items, ["nuke", "shield"] as Array[String])
	assert_true(_pm.is_item_equipped("shield"))
	assert_false(_pm.is_item_equipped("blackhole"))
	assert_true(_pm.is_item_unlocked("blackhole"))


func test_an_item_needs_the_points() -> void:
	_pm.data.points = _pm.get_item_cost("laser") - 1
	assert_false(_pm.buy_item("laser"))
	assert_false(_pm.is_item_unlocked("laser"))


func test_dash_ranks_and_items_survive_a_save() -> void:
	_pm.buy_dash_cooldown()
	_pm.buy_dash_shield()
	_pm.buy_dash_shield()
	_pm.buy_item("freeze")
	_pm.buy_item("laser")
	_pm.unequip_item("freeze")
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.dash.cooldown, 1)
	assert_eq(again.data.dash.shield, 2)
	assert_eq(again.data.unlocked_items, ["freeze", "laser"] as Array[String])
	assert_eq(again.data.equipped_items, ["laser"] as Array[String])
	var text: String = FileAccess.get_file_as_string(ProgressionManager.SAVE_PATH)
	for key: String in ['"dash"', '"unlockedItems"', '"equippedItems"']:
		assert_true(text.contains(key), "saved as %s" % key)


func test_a_bad_save_is_cleaned_on_load() -> void:
	(
		SaveStore
		. save_dict(
			ProgressionManager.SAVE_PATH,
			{
				"dash": {"cooldown": 99, "shield": -3},
				"unlockedItems": ["nuke", "nuke", "ghost", "laser", "shield"],
				"equippedItems": ["ghost", "laser", "freeze", "laser", "nuke", "shield"],
			}
		)
	)
	SaveStore.flush()
	var loaded: ProgressionManager = ProgressionManager.new()
	assert_eq(loaded.data.dash.cooldown, ProgressionManager.DASH_COOLDOWN_RANKS)
	assert_eq(loaded.data.dash.shield, 0)
	assert_eq(loaded.data.unlocked_items, ["nuke", "laser", "shield"] as Array[String])
	assert_eq(
		loaded.data.equipped_items,
		["laser", "nuke"] as Array[String],
		"bought, once each, at most two"
	)
