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
	assert_eq(_pm.get_perk_cost(0), 300, "ProgressionManager.ts:558")
	assert_eq(_pm.get_perk_cost(1), 600)
	assert_eq(_pm.get_perk_cost(2), 1100)
	assert_eq(_pm.get_perk_cost(3), 1800)
	assert_eq(_pm.get_perk_cost(4), 2800)
	assert_eq(_pm.get_perk_cost(5), 2800, "clamped to the last entry (:559)")
	assert_eq(_pm.get_perk_cost(99), 2800)


func test_keystone_cost_reads_the_tuning_table() -> void:
	assert_eq(_pm.get_perk_cost(0, true, "crossBeam"), 3500, "WeaponTuning.ts:74")
	assert_eq(_pm.get_perk_cost(0, true, "supernovaCollapse"), 5000)
	assert_eq(_pm.get_perk_cost(0, true, "shatterCascade"), 2500)
	assert_eq(_pm.get_perk_cost(0, true, "nosuch"), 2500, "?? 2500 (:556)")
	assert_eq(_pm.get_perk_cost(0, true), 2500, "'' is not a key either")
	assert_eq(_pm.get_perk_cost(3, true, "crossBeam"), 3500, "rank is ignored for keystones")


func test_weapon_invested_points_at_defaults() -> void:
	assert_eq(_pm.get_weapon_invested_points("blackhole"), 6700, "2000 + 900 + 3800")
	assert_eq(_pm.get_weapon_invested_points("nuke"), 300)
	assert_eq(_pm.get_weapon_invested_points("shield"), 0)
	assert_eq(_pm.get_weapon_invested_points("missiles"), 6600, "300+600+1100+1800+2800")
	assert_eq(_pm.get_weapon_invested_points("laser"), 900)
	assert_eq(_pm.get_weapon_invested_points("nosuch"), 0, ":565")
	_pm.data.perks.laser.cross_beam = true
	assert_eq(_pm.get_weapon_invested_points("laser"), 4400, "900 + keystone 3500 (:573-574)")


func test_upgrade_perk_rank_charges_the_curve_and_increments() -> void:
	assert_eq(_pm.data.perks.nuke.speed, 0)
	assert_true(_pm.upgrade_perk("nuke", "speed"))
	assert_eq(_pm.data.perks.nuke.speed, 1)
	assert_eq(_pm.data.points, 7331 - 300)
	assert_true(_pm.upgrade_perk("nuke", "speed"))
	assert_eq(_pm.data.points, 7331 - 300 - 600)
	assert_eq(_pm.data.perks.nuke.speed, 2)
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.perks.nuke.speed, 2, "upgradePerk saves (:599)")


func test_upgrade_perk_refuses_max_rank_unknown_and_unaffordable() -> void:
	_pm.data.perks.missiles.count = 5
	assert_false(_pm.upgrade_perk("missiles", "count"), ">= 5 is max (:594)")
	assert_eq(_pm.data.points, 7331)
	assert_false(_pm.upgrade_perk("nosuch", "count"), ":582")
	assert_false(_pm.upgrade_perk("nuke", "nosuch"), ":582")
	_pm.data.points = 299
	assert_false(_pm.upgrade_perk("nuke", "speed"), "cannot afford 300 (:596)")
	assert_eq(_pm.data.perks.nuke.speed, 0)
	# PORT-NOTE: the TS caps ranks at 5 for every track even where the
	# WeaponPerks comment says 0..3 (:18, :23, :28, :33, :38) — preserved.
	_pm.data.points = 100000
	_pm.data.perks.nuke.speed = 4
	assert_true(_pm.upgrade_perk("nuke", "speed"), "rank 4 -> 5 is allowed for a 0..3 track")
	assert_eq(_pm.data.perks.nuke.speed, 5)


func test_upgrade_perk_keystone_charges_its_price_once() -> void:
	_pm.data.points = 10000
	assert_true(_pm.upgrade_perk("laser", "crossBeam"))
	assert_true(_pm.data.perks.laser.cross_beam)
	assert_eq(_pm.data.points, 10000 - 3500)
	assert_false(_pm.upgrade_perk("laser", "crossBeam"), "already unlocked (:586)")
	assert_eq(_pm.data.points, 6500)
	_pm.data.points = 2999
	assert_false(_pm.upgrade_perk("nuke", "falloutZone"), "3000 > 2999")
	assert_false(_pm.data.perks.nuke.fallout_zone)


func test_purchasable_ladders_and_absent_past_the_end() -> void:
	assert_eq(_pm.get_extra_lives_cost(), 4000, ":607")
	assert_eq(_pm.get_hull_compact_cost(), 1500, ":608")
	assert_eq(_pm.get_enemy_slow_cost(), 2000, ":609")
	assert_eq(_pm.get_score_multiplier_cost(), 1800, ":610")
	assert_eq(_pm.get_points_multiplier_cost(), 2500, ":611")
	_pm.data.extra_lives = 2
	assert_eq(_pm.get_extra_lives_cost(), Types.ABSENT, "null past the ladder (:615)")
	_pm.data.hull_compact = 3
	assert_eq(_pm.get_hull_compact_cost(), Types.ABSENT)
	_pm.data.score_multiplier = 3
	assert_eq(_pm.get_score_multiplier_cost(), 11000)
	_pm.data.score_multiplier = 4
	assert_eq(_pm.get_score_multiplier_cost(), Types.ABSENT)


func test_every_buy_method_charges_increments_and_saves() -> void:
	_pm.data.points = 50000
	assert_true(_pm.buy_extra_life())
	assert_eq(_pm.data.extra_lives, 1)
	assert_eq(_pm.data.points, 46000)
	assert_true(_pm.buy_hull_compact())
	assert_eq(_pm.data.hull_compact, 1)
	assert_eq(_pm.data.points, 44500)
	assert_true(_pm.buy_enemy_slow())
	assert_eq(_pm.data.enemy_slow, 1)
	assert_eq(_pm.data.points, 42500)
	assert_true(_pm.buy_score_multiplier())
	assert_eq(_pm.data.score_multiplier, 1)
	assert_eq(_pm.data.points, 40700)
	assert_true(_pm.buy_points_multiplier())
	assert_eq(_pm.data.points_multiplier, 1)
	assert_eq(_pm.data.points, 38200)
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.points, 38200, "each buy saves")
	assert_eq(again.data.points_multiplier, 1)


func test_buy_refuses_when_maxed_or_unaffordable() -> void:
	_pm.data.points = 3999
	assert_false(_pm.buy_extra_life(), "4000 > 3999 (:621)")
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
