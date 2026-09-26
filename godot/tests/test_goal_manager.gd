# gdlint:disable=max-public-methods
## test_goal_manager.gd
## PORTS: nothing — new file, covers src/meta/goal_manager.gd (spec §6.3 Tier 1)
extends GutTest
## Proves the goal catalog's shape, persistence in the TS shapes, the queries,
## and (Task 3) evaluation for every category.

var _gm: GoalManager = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _remove_saves() -> void:
	for path: String in [
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
		ProgressionManager.SAVE_PATH,
	]:
		_remove(path)
		_remove(SaveStore.corrupt_path_for(path))


func _ids(goals: Array[GoalManager.Goal]) -> Array[String]:
	var out: Array[String] = []
	for g: GoalManager.Goal in goals:
		out.append(g.id)
	return out


func before_each() -> void:
	_remove_saves()
	_gm = GoalManager.new()


func after_each() -> void:
	_remove_saves()


func test_catalog_has_57_goals_with_unique_ids() -> void:
	assert_eq(_gm.catalog.size(), 57)
	assert_eq(_gm.get_total_goals_count(), 57)
	var seen: Dictionary[String, bool] = {}
	for g: GoalManager.Goal in _gm.catalog:
		assert_false(seen.has(g.id), "duplicate id " + g.id)
		seen[g.id] = true


func test_fresh_manager_has_nothing_completed() -> void:
	assert_eq(_gm.get_completed_count(), 0)
	assert_false(_gm.is_completed("score_1k"))
	assert_eq(_gm.cumulative.total_kills, 0)
	assert_eq(_gm.cumulative.total_survival_time, 0)
	assert_eq(_gm.cumulative.total_points_earned, 0)
	assert_eq(_gm.cumulative.total_score, 0)


func test_total_and_unlock_predicates_split_the_catalog() -> void:
	var totals: int = 0
	var unlocks: int = 0
	for g: GoalManager.Goal in _gm.catalog:
		if _gm.is_unlock_goal(g):
			unlocks += 1
		elif _gm.is_total_goal(g):
			totals += 1
	assert_eq(totals, 9, "the nine 'cumulative' goals, all metric total_* (:340-420)")
	assert_eq(unlocks, 21, "4 ships + 5 skins + 5 arenas + 7 weapons (:423-639)")


func test_completed_ids_persist_as_a_bare_json_array() -> void:
	var probe: Array[String] = ["kills_15", "score_1k"]
	SaveStore.save_string_list(GoalManager.SAVE_PATH, probe)
	var reloaded: GoalManager = GoalManager.new()
	assert_true(reloaded.is_completed("kills_15"))
	assert_true(reloaded.is_completed("score_1k"))
	assert_eq(reloaded.get_completed_count(), 2)
	reloaded.save_completed()
	assert_eq(
		SaveStore.load_string_list(GoalManager.SAVE_PATH),
		probe,
		"Array.from(set) keeps insertion order (:686)"
	)


func test_cumulative_stats_persist_in_the_ts_shape() -> void:
	_gm.cumulative.total_kills = 120
	_gm.cumulative.total_survival_time = 200
	_gm.cumulative.total_points_earned = 7
	_gm.cumulative.total_score = 60000
	_gm.save_cumulative()
	var raw: Dictionary = SaveStore.load_dict(GoalManager.CUMULATIVE_SAVE_PATH)
	# B2: JSON objects are unordered and save_dict sorts keys; compare the sorted
	# key set, not an assumed write order.
	var keys: Array = raw.keys()
	keys.sort()
	var expected: Array = ["totalKills", "totalPointsEarned", "totalScore", "totalSurvivalTime"]
	expected.sort()
	assert_eq(keys, expected)
	var reloaded: GoalManager = GoalManager.new()
	assert_eq(reloaded.cumulative.total_kills, 120)
	assert_eq(reloaded.cumulative.total_survival_time, 200)
	assert_eq(reloaded.cumulative.total_points_earned, 7)
	assert_eq(reloaded.cumulative.total_score, 60000)


func test_corrupt_completed_file_is_quarantined() -> void:
	var file: FileAccess = FileAccess.open(GoalManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{oops")
	file.close()
	var reloaded: GoalManager = GoalManager.new()
	assert_eq(reloaded.get_completed_count(), 0)
	assert_true(FileAccess.file_exists(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH)))


func test_get_active_goals_returns_the_first_uncompleted() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k"] as Array[String])
	var gm: GoalManager = GoalManager.new()
	var active: Array[GoalManager.ActiveGoal] = gm.get_active_goals()
	assert_eq(active.size(), 3, "maxCount defaults to 3 (:742)")
	assert_eq(active[0].goal.id, "score_5k")
	assert_eq(active[2].goal.id, "score_25k")
	assert_eq(active[0].current, 0.0, "always 0 (:746)")
	assert_eq(gm.get_active_goals(1).size(), 1)


func _tracker() -> GoalManager.RunTracker:
	return GoalManager.RunTracker.new()


func test_run_goals_never_complete_live() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.score = 1000
	assert_eq(_gm.evaluate_live_total_goals(t), [] as Array[GoalManager.Goal], ":750-753")
	assert_false(_gm.is_completed("score_1k"))
	assert_eq(_ids(_gm.evaluate_run(t)), ["score_1k"] as Array[String])


func test_evaluate_run_caps_single_run_goals_at_three_in_catalog_order() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.score = 60000
	t.kills = 250
	var done: Array[String] = _ids(_gm.evaluate_run(t))
	# B1: evaluate_run double-counts the run (I3 PORT-NOTE), so the cumulative
	# totals complete here too. Filter to the non-total ids to check the cap.
	var run_goals: Array[String] = []
	for id: String in done:
		if not id.begins_with("total_"):
			run_goals.append(id)
	assert_eq(
		run_goals,
		["score_1k", "score_5k", "score_10k"] as Array[String],
		"slice(0, 3) of the eligible list (:823)"
	)
	assert_eq(
		done,
		(
			[
				"total_kills_100",
				"total_kills_500",
				"total_score_50k",
				"score_1k",
				"score_5k",
				"score_10k",
			]
			as Array[String]
		),
		"totals complete too — evaluate_run double-counts (I3)"
	)
	assert_false(_gm.is_completed("kills_15"), "left for the next run")


func test_cumulative_goals_are_uncapped_and_awarded_before_run_goals() -> void:
	var events: Array[String] = []
	_gm.set_callbacks(
		func(g: GoalManager.Goal) -> void: events.append("goal:" + g.id),
		func(p: int) -> void: events.append("pts:%d" % p)
	)
	var t: GoalManager.RunTracker = _tracker()
	t.kills = 120
	t.survival_time = 200.7
	t.score = 60000
	var done: Array[String] = _ids(_gm.evaluate_run(t))
	assert_eq(
		done,
		(
			[
				"total_kills_100",
				"total_survival_180",
				"total_score_50k",
				"score_1k",
				"score_5k",
				"score_10k",
			]
			as Array[String]
		),
		"totals first (:796-807), then the capped run goals (:810-828)"
	)
	assert_eq(_gm.cumulative.total_kills, 120, ":789")
	assert_eq(_gm.cumulative.total_survival_time, 200, "floor (:790)")
	assert_eq(_gm.cumulative.total_score, 60000, ":791")
	assert_eq(_gm.cumulative.total_points_earned, 2 + 2 + 3 + 1 + 2 + 3)
	assert_false(
		_gm.is_completed("total_points_10"),
		"7 points when total_points_10 was checked (:796-807 runs before the run goals)"
	)
	assert_eq(
		events.slice(0, 4),
		["pts:2", "goal:total_kills_100", "pts:2", "goal:total_survival_180"] as Array[String]
	)
	assert_eq(events.size(), 12, "one pts + one goal callback per completion (:834-841)")
	assert_true(FileAccess.file_exists(GoalManager.SAVE_PATH))
	assert_true(FileAccess.file_exists(GoalManager.CUMULATIVE_SAVE_PATH))


func test_live_total_goals_complete_mid_run_and_save_at_once() -> void:
	var events: Array[String] = []
	_gm.set_callbacks(
		func(g: GoalManager.Goal) -> void: events.append("goal:" + g.id),
		func(p: int) -> void: events.append("pts:%d" % p)
	)
	_gm.cumulative.total_kills = 90
	var t: GoalManager.RunTracker = _tracker()
	t.kills = 10
	assert_eq(_ids(_gm.evaluate_live_total_goals(t)), ["total_kills_100"] as Array[String])
	assert_eq(events, ["pts:2", "goal:total_kills_100"] as Array[String])
	assert_eq(_gm.cumulative.total_points_earned, 2)
	assert_eq(_gm.cumulative.total_kills, 90, "live evaluation never commits the run (:754-780)")
	assert_eq(
		SaveStore.load_string_list(GoalManager.SAVE_PATH), ["total_kills_100"] as Array[String]
	)
	assert_eq(_gm.evaluate_live_total_goals(t), [] as Array[GoalManager.Goal], "never twice")


func test_combo_goals_read_the_multiplier() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.multiplier = 5.0
	assert_eq(_ids(_gm.evaluate_run(t)), ["mult_3", "mult_5"] as Array[String])


func test_survival_goals_floor_seconds_and_respect_the_cap() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.close_calls = 7
	t.survival_time = 61.9
	assert_eq(
		_ids(_gm.evaluate_run(t)),
		["close_call_3", "close_call_7", "survive_30"] as Array[String],
		"survive_60 is eligible but fourth in catalog order"
	)
	assert_eq(_gm.get_metric_value("run_survival", t), 61.0, "Math.floor (:937)")


func test_weapon_goals_read_each_counter() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.nukes_detonated = 3
	t.vortex_absorbs = 20
	t.laser_slices = 20
	assert_eq(_ids(_gm.evaluate_run(t)), ["nuke_3", "vortex_20", "laser_20"] as Array[String])
	var t2: GoalManager.RunTracker = _tracker()
	t2.missiles_fired = 30
	t2.freeze_shatters = 15
	t2.shield_rams = 10
	assert_eq(
		_ids(_gm.evaluate_run(t2)), ["missiles_30", "freeze_15", "shield_10"] as Array[String]
	)


func test_mode_goals_count_only_in_their_mode() -> void:
	var classic: GoalManager.RunTracker = _tracker()
	classic.survival_time = 65.0
	assert_eq(_gm.get_metric_value("code_red_survival", classic), 0.0, ":953")
	assert_eq(_ids(_gm.evaluate_run(classic)), ["survive_30", "survive_60"] as Array[String])

	# B1: evaluate_run double-counts the run into cumulative (I3 PORT-NOTE), so a
	# shared manager would also complete total_survival_180/total_points_10
	# across these three calls. Give each tracker a fresh manager.
	# run_survival goals have no mode check (GoalManager.ts:930-932), so
	# survive_30/survive_60 are also eligible here; the 3-per-run cap
	# (catalog order) cuts mode_code_red_60.
	_remove_saves()
	var gm_red: GoalManager = GoalManager.new()
	var red: GoalManager.RunTracker = _tracker()
	red.mode = "code-red"
	red.survival_time = 65.0
	assert_eq(
		_ids(gm_red.evaluate_run(red)),
		["survive_30", "survive_60", "mode_code_red_30"] as Array[String]
	)

	# Same reason: run_survival's survive_30 is eligible alongside
	# mode_gauntlet_30 (GoalManager.ts:930-932).
	_remove_saves()
	var gm_gauntlet: GoalManager = GoalManager.new()
	var gauntlet: GoalManager.RunTracker = _tracker()
	gauntlet.mode = "gauntlet"
	gauntlet.survival_time = 30.0
	assert_eq(
		_ids(gm_gauntlet.evaluate_run(gauntlet)),
		["survive_30", "mode_gauntlet_30"] as Array[String]
	)


func test_total_metrics_add_the_live_run_to_the_committed_totals() -> void:
	_gm.cumulative.total_kills = 40
	_gm.cumulative.total_survival_time = 100
	_gm.cumulative.total_score = 500
	_gm.cumulative.total_points_earned = 9
	var t: GoalManager.RunTracker = _tracker()
	t.kills = 5
	t.survival_time = 10.8
	t.score = 250
	assert_eq(_gm.get_metric_value("total_kills", t), 45.0)
	assert_eq(_gm.get_metric_value("total_survival", t), 110.0)
	assert_eq(_gm.get_metric_value("total_score", t), 750.0)
	assert_eq(_gm.get_metric_value("total_points", t), 9.0, "not tracker-driven (:963)")
	assert_eq(_gm.get_metric_value("ship_unlocked", t), 0.0, "default arm (:967)")


func test_unlock_goals_read_progression() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	_gm.set_progression(pm)
	assert_eq(_gm.evaluate_unlock_goals(), [] as Array[GoalManager.Goal], "defaults unlock none")
	pm.data.unlocked_cursors.append("solar")
	pm.data.unlocked_enemy_skins.append("toxic")
	pm.data.unlocked_arena_themes.append("synthwave")
	assert_eq(
		_ids(_gm.evaluate_unlock_goals()),
		["unlock_ship_solar", "unlock_skin_toxic", "unlock_arena_synthwave"] as Array[String]
	)
	assert_eq(_gm.cumulative.total_points_earned, 2 + 2 + 2)
	assert_eq(_gm.evaluate_unlock_goals(), [] as Array[GoalManager.Goal], "never re-awarded")


func test_weapon_fully_upgraded_needs_every_rank_and_keystone() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	_gm.set_progression(pm)
	pm.data.perks.missiles.count = 5
	pm.data.perks.missiles.blast_radius = 5
	pm.data.perks.missiles.flight_speed = 5
	assert_eq(
		_ids(_gm.evaluate_unlock_goals()),
		["weapon_maxed_missiles"] as Array[String],
		"missiles has no keystones in WeaponPerks (:919-926 reads what exists)"
	)
	pm.data.perks.nuke.radius = 5
	pm.data.perks.nuke.speed = 5
	assert_eq(_gm.evaluate_unlock_goals(), [] as Array[GoalManager.Goal], "falloutZone still false")
	pm.data.perks.nuke.fallout_zone = true
	assert_eq(_ids(_gm.evaluate_unlock_goals()), ["weapon_maxed_nuke"] as Array[String])


func test_unlock_evaluation_is_a_no_op_without_progression() -> void:
	assert_eq(_gm.evaluate_unlock_goals(), [] as Array[GoalManager.Goal], ":862")


func test_run_and_live_evaluation_skip_unlock_goals() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	pm.data.unlocked_cursors.append("solar")
	_gm.set_progression(pm)
	_gm.evaluate_run(_tracker())
	_gm.evaluate_live_total_goals(_tracker())
	assert_false(_gm.is_completed("unlock_ship_solar"), ":798, :759")


func test_reset_all_progress_clears_and_saves() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.score = 1000
	t.kills = 20
	_gm.evaluate_run(t)
	_gm.reset_all_progress()
	assert_eq(_gm.get_completed_count(), 0)
	assert_eq(_gm.cumulative.total_kills, 0)
	assert_eq(SaveStore.load_string_list(GoalManager.SAVE_PATH), [] as Array[String])
	assert_eq(GoalManager.new().cumulative.total_kills, 0, "saved (:980-981)")


func test_live_total_goals_return_after_a_progress_reset() -> void:
	# M11c P22: the cached live list must follow completions and resets.
	_gm.cumulative.total_kills = 90
	var t: GoalManager.RunTracker = _tracker()
	t.kills = 10
	assert_eq(_ids(_gm.evaluate_live_total_goals(t)), ["total_kills_100"] as Array[String])
	assert_eq(
		_gm.evaluate_live_total_goals(t), [] as Array[GoalManager.Goal], "cache rebuilt clean"
	)
	_gm.reset_all_progress()
	_gm.cumulative.total_kills = 90
	assert_eq(
		_ids(_gm.evaluate_live_total_goals(t)),
		["total_kills_100"] as Array[String],
		"evaluated again after reset"
	)
