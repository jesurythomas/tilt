## test_progression_economy.gd
## PORTS: nothing — new file, covers the economy in src/meta/progression_manager.gd
extends GutTest
## Proves points crediting, the perk cost curve, every perk and purchasable
## buy path, starting lives and the four multipliers.

var _pm: ProgressionManager = null


func _remove_save() -> void:
	var absolute: String = ProjectSettings.globalize_path(ProgressionManager.SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove_save()
	_pm = ProgressionManager.new()
	_pm.data.points = 7331  # DIVERGENCE(ECON R3): a funded save (the TS start balance)
	_pm.data.lifetime_points = 7331


func after_each() -> void:
	_remove_save()


func test_add_points_credited_applies_the_points_multiplier_and_saves() -> void:
	watch_signals(GameEvents)
	assert_eq(_pm.add_points_credited(100), 100, "rank 0 multiplier is 1.0")
	assert_eq(_pm.data.points, 7431)
	assert_eq(_pm.data.lifetime_points, 7431, "lifetime is credited the same (:529-536)")
	assert_signal_emitted_with_parameters(GameEvents, "points_changed", [7431])
	assert_true(
		FileAccess.file_exists(ProgressionManager.SAVE_PATH), "addPointsCredited saves (:548)"
	)

	_pm.data.points_multiplier = 3
	assert_eq(_pm.add_points_credited(33), 42, "floor(33 * 1.3) = 42 (:545)")
	assert_eq(_pm.data.points, 7473)


func test_add_points_ignores_zero_and_negative() -> void:
	watch_signals(GameEvents)
	assert_eq(_pm.add_points_credited(0), 0)
	assert_eq(_pm.add_points_credited(-50), 0)
	assert_eq(_pm.data.points, 7331)
	assert_signal_not_emitted(GameEvents, "points_changed")
	_pm.add_points(10)
	assert_eq(_pm.data.points, 7341, "addPoints is addPointsCredited without the return (:537-539)")


func test_perk_cost_curve() -> void:
	# DIVERGENCE(ECON R2): 250 × ~1.6 a rank (TS 300/600/1100/1800/2800).
	# ADS R8: charged at UPGRADE_PRICE_SCALE times the table.
	assert_eq(_pm.get_perk_cost(0), 250 * ProgressionManager.UPGRADE_PRICE_SCALE)
	assert_eq(_pm.get_perk_cost(1), 400 * ProgressionManager.UPGRADE_PRICE_SCALE)
	assert_eq(_pm.get_perk_cost(2), 650 * ProgressionManager.UPGRADE_PRICE_SCALE)
	assert_eq(_pm.get_perk_cost(3), 1000 * ProgressionManager.UPGRADE_PRICE_SCALE)
	assert_eq(_pm.get_perk_cost(4), 1600 * ProgressionManager.UPGRADE_PRICE_SCALE)
	assert_eq(
		_pm.get_perk_cost(5),
		1600 * ProgressionManager.UPGRADE_PRICE_SCALE,
		"clamped to the last entry (:559)"
	)
	assert_eq(_pm.get_perk_cost(99), 1600 * ProgressionManager.UPGRADE_PRICE_SCALE)


func test_keystone_cost_reads_the_tuning_table() -> void:
	# ADS R8: KEYSTONE_COSTS (and the 2500 fallback) times UPGRADE_PRICE_SCALE.
	var scale: int = ProgressionManager.UPGRADE_PRICE_SCALE
	assert_eq(_pm.get_perk_cost(0, true, "crossBeam"), 3500 * scale, "WeaponTuning.ts:74")
	assert_eq(_pm.get_perk_cost(0, true, "supernovaCollapse"), 5000 * scale)
	assert_eq(_pm.get_perk_cost(0, true, "shatterCascade"), 2500 * scale)
	assert_eq(_pm.get_perk_cost(0, true, "nosuch"), 2500 * scale, "?? 2500 (:556)")
	assert_eq(_pm.get_perk_cost(0, true), 2500 * scale, "'' is not a key either")
	assert_eq(
		_pm.get_perk_cost(3, true, "crossBeam"), 3500 * scale, "rank is ignored for keystones"
	)


func test_weapon_invested_points_at_defaults() -> void:
	# ECON R2 curve: ranks 3/2/4 = 1300 + 650 + 2300; ADS R8 prices them at UPGRADE_PRICE_SCALE.
	var scale: int = ProgressionManager.UPGRADE_PRICE_SCALE
	assert_eq(_pm.get_weapon_invested_points("blackhole"), 4250 * scale, "1300 + 650 + 2300")
	assert_eq(_pm.get_weapon_invested_points("nuke"), 250 * scale)
	assert_eq(_pm.get_weapon_invested_points("shield"), 0)
	assert_eq(_pm.get_weapon_invested_points("missiles"), 3900 * scale, "250+400+650+1000+1600")
	assert_eq(_pm.get_weapon_invested_points("laser"), 650 * scale)
	assert_eq(_pm.get_weapon_invested_points("nosuch"), 0, ":565")
	_pm.data.perks.laser.cross_beam = true
	assert_eq(
		_pm.get_weapon_invested_points("laser"), 4150 * scale, "650 + keystone 3500 (:573-574)"
	)


func test_upgrade_perk_rank_charges_the_curve_and_increments() -> void:
	assert_eq(_pm.data.perks.nuke.speed, 0)
	assert_true(_pm.upgrade_perk("nuke", "speed"))
	assert_eq(_pm.data.perks.nuke.speed, 1)
	assert_eq(_pm.data.points, 7331 - 250 * ProgressionManager.UPGRADE_PRICE_SCALE)
	assert_true(_pm.upgrade_perk("nuke", "speed"))
	assert_eq(_pm.data.points, 7331 - (250 + 400) * ProgressionManager.UPGRADE_PRICE_SCALE)
	assert_eq(_pm.data.perks.nuke.speed, 2)
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.perks.nuke.speed, 2, "upgradePerk saves (:599)")


func test_upgrade_perk_refuses_max_rank_unknown_and_unaffordable() -> void:
	_pm.data.perks.missiles.count = 5
	assert_false(_pm.upgrade_perk("missiles", "count"), ">= 5 is max (:594)")
	assert_eq(_pm.data.points, 7331)
	assert_false(_pm.upgrade_perk("nosuch", "count"), ":582")
	assert_false(_pm.upgrade_perk("nuke", "nosuch"), ":582")
	_pm.data.points = 250 * ProgressionManager.UPGRADE_PRICE_SCALE - 1
	assert_false(
		_pm.upgrade_perk("nuke", "speed"), "cannot afford 250 × UPGRADE_PRICE_SCALE (:596, ADS R8)"
	)
	assert_eq(_pm.data.perks.nuke.speed, 0)
	# PORT-NOTE: the TS caps ranks at 5 for every track even where the
	# WeaponPerks comment says 0..3 (:18, :23, :28, :33, :38) — preserved.
	_pm.data.points = 100000
	_pm.data.perks.nuke.speed = 4
	assert_true(_pm.upgrade_perk("nuke", "speed"), "rank 4 -> 5 is allowed for a 0..3 track")
	assert_eq(_pm.data.perks.nuke.speed, 5)


func test_upgrade_perk_keystone_charges_its_price_once() -> void:
	_pm.data.points = 20000
	assert_true(_pm.upgrade_perk("laser", "crossBeam"))
	assert_true(_pm.data.perks.laser.cross_beam)
	assert_eq(_pm.data.points, 20000 - 3500 * ProgressionManager.UPGRADE_PRICE_SCALE)
	assert_false(_pm.upgrade_perk("laser", "crossBeam"), "already unlocked (:586)")
	assert_eq(_pm.data.points, 20000 - 3500 * ProgressionManager.UPGRADE_PRICE_SCALE)
	_pm.data.points = 3000 * ProgressionManager.UPGRADE_PRICE_SCALE - 1
	assert_false(
		_pm.upgrade_perk("nuke", "falloutZone"), "3000 × UPGRADE_PRICE_SCALE > balance (ADS R8)"
	)
	assert_false(_pm.data.perks.nuke.fallout_zone)


func test_purchasable_ladders_and_absent_past_the_end() -> void:
	# DIVERGENCE(ECON R2) prices, times PRICE_SCALE (ADS R7); ladder lengths as :607-611.
	assert_eq(_pm.get_extra_lives_cost(), 2500 * ProgressionManager.PRICE_SCALE)
	assert_eq(_pm.get_hull_compact_cost(), 800 * ProgressionManager.PRICE_SCALE)
	assert_eq(_pm.get_enemy_slow_cost(), 1000 * ProgressionManager.PRICE_SCALE)
	assert_eq(_pm.get_score_multiplier_cost(), 500 * ProgressionManager.PRICE_SCALE)
	assert_eq(_pm.get_points_multiplier_cost(), 1200 * ProgressionManager.PRICE_SCALE)
	_pm.data.extra_lives = 2
	assert_eq(_pm.get_extra_lives_cost(), Types.ABSENT, "null past the ladder (:615)")
	_pm.data.hull_compact = 3
	assert_eq(_pm.get_hull_compact_cost(), Types.ABSENT)
	_pm.data.score_multiplier = 3
	assert_eq(_pm.get_score_multiplier_cost(), 3000 * ProgressionManager.PRICE_SCALE)
	_pm.data.score_multiplier = 4
	assert_eq(_pm.get_score_multiplier_cost(), Types.ABSENT)


func test_every_buy_method_charges_increments_and_saves() -> void:
	_pm.data.points = 50000
	var scale: int = ProgressionManager.PRICE_SCALE  # ADS R7
	assert_true(_pm.buy_extra_life())
	assert_eq(_pm.data.extra_lives, 1)
	assert_eq(_pm.data.points, 50000 - 2500 * scale)
	assert_true(_pm.buy_hull_compact())
	assert_eq(_pm.data.hull_compact, 1)
	assert_eq(_pm.data.points, 50000 - (2500 + 800) * scale)
	assert_true(_pm.buy_enemy_slow())
	assert_eq(_pm.data.enemy_slow, 1)
	assert_eq(_pm.data.points, 50000 - (2500 + 800 + 1000) * scale)
	assert_true(_pm.buy_score_multiplier())
	assert_eq(_pm.data.score_multiplier, 1)
	assert_eq(_pm.data.points, 50000 - (2500 + 800 + 1000 + 500) * scale)
	assert_true(_pm.buy_points_multiplier())
	assert_eq(_pm.data.points_multiplier, 1)
	assert_eq(_pm.data.points, 50000 - (2500 + 800 + 1000 + 500 + 1200) * scale)
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.points, 50000 - 6000 * scale, "each buy saves")
	assert_eq(again.data.points_multiplier, 1)


func test_buy_refuses_when_maxed_or_unaffordable() -> void:
	_pm.data.points = 2500 * ProgressionManager.PRICE_SCALE - 1
	assert_false(_pm.buy_extra_life(), "2500 × PRICE_SCALE > balance (:621, ADS R7)")
	assert_eq(_pm.data.extra_lives, 0)
	_pm.data.points = 100000
	_pm.data.extra_lives = 2
	assert_false(_pm.buy_extra_life(), "ladder exhausted")
	assert_eq(_pm.data.points, 100000)
	_pm.data.enemy_slow = 3
	assert_false(_pm.buy_enemy_slow())
	_pm.data.points_multiplier = 4
	assert_false(_pm.buy_points_multiplier())


func test_starting_lives_caps_at_three() -> void:
	assert_eq(_pm.get_starting_lives(), 1, "1 base (:692)")
	_pm.data.extra_lives = 1
	assert_eq(_pm.get_starting_lives(), 2)
	_pm.data.extra_lives = 2
	assert_eq(_pm.get_starting_lives(), 3)
	_pm.data.unlocked_cursors.append("revenant")
	_pm.data.equipped_cursor_id = "revenant"
	assert_eq(_pm.get_starting_lives(), 3, "1 + 2 + bonus 1 capped at 3")
	_pm.data.extra_lives = 0
	assert_eq(_pm.get_starting_lives(), 2, "the Revenant's bonusLives (:265, :691)")


func test_multipliers_per_rank() -> void:
	assert_almost_eq(_pm.get_hitbox_multiplier(), 1.0, 0.0001)
	assert_almost_eq(_pm.get_enemy_speed_multiplier(), 1.0, 0.0001)
	assert_almost_eq(_pm.get_score_multiplier(), 1.0, 0.0001)
	assert_almost_eq(_pm.get_points_multiplier(), 1.0, 0.0001)
	_pm.data.hull_compact = 3
	_pm.data.enemy_slow = 2
	_pm.data.score_multiplier = 4
	_pm.data.points_multiplier = 1
	assert_almost_eq(_pm.get_hitbox_multiplier(), 0.82, 0.0001, "1 - 0.06 * 3 (:696)")
	assert_almost_eq(_pm.get_enemy_speed_multiplier(), 0.92, 0.0001, "1 - 0.04 * 2 (:700)")
	assert_almost_eq(_pm.get_score_multiplier(), 1.4, 0.0001, "1 + 0.10 * 4 (:704)")
	assert_almost_eq(_pm.get_points_multiplier(), 1.1, 0.0001, "1 + 0.10 * 1 (:708)")


func test_dead_keystones_are_refunded_once_and_cleared() -> void:
	# DIVERGENCE(ECON R4): keystones that left the Armory are refunded on load.
	_pm.data.points = 1000
	_pm.data.perks.blackhole.invulnerable_inside = true
	_pm.data.perks.nuke.fallout_zone = true
	_pm.data.perks.shield.battering_ram = true
	_pm.data.perks.freeze.shatter_cascade = true
	_pm.data.perks.laser.cross_beam = true
	_pm.save()
	var loaded: ProgressionManager = ProgressionManager.new()
	assert_eq(loaded.data.points, 1000 + 2500, "KEY R1: only Aegis (now innate) is refunded")
	assert_false(loaded.data.perks.blackhole.invulnerable_inside)
	assert_true(loaded.data.perks.nuke.fallout_zone, "coded now: kept")
	assert_true(loaded.data.perks.shield.battering_ram)
	assert_true(loaded.data.perks.freeze.shatter_cascade)
	assert_true(loaded.data.perks.laser.cross_beam, "a live keystone is kept")
	loaded.save()
	assert_eq(ProgressionManager.new().data.points, 3500, "a second load refunds nothing")


func test_a_save_keeps_a_low_balance() -> void:
	# DIVERGENCE(ECON R3): the TS reset balances under 500 to 7331 (:491).
	_pm.data.points = 12
	_pm.save()
	assert_eq(ProgressionManager.new().data.points, 12)


func test_run_payout_formula() -> void:
	# DIVERGENCE(ECON R1): round((60 + 3·t + 4·kills^0.7) × mode).
	assert_eq(ProgressionManager.run_payout(0.0, 0, 1.0), 60, "the floor")
	assert_eq(ProgressionManager.run_payout(100.0, 0, 1.0), 360)
	assert_eq(ProgressionManager.run_payout(0.0, 1000, 1.0), 564, "4 × 1000^0.7 = 503.6")
	assert_eq(ProgressionManager.run_payout(10.0, 10, 1.5), 165, "(90 + 20.05) × 1.5")
	assert_eq(ProgressionManager.run_payout(-5.0, -3, 1.0), 60, "negative inputs clamp")
	assert_gt(
		ProgressionManager.run_payout(300.0, 1800, 1.0),
		ProgressionManager.run_payout(150.0, 500, 1.0),
		"a better run pays more"
	)
