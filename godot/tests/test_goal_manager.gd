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
