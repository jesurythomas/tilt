## test_goal_parity.gd
## PORTS: nothing — new file, spec §6.3 Tier 2 constant-parity harness
extends GutTest
## Asserts meta/goal_manager.gd's catalog equals GoalManager.ts's, field for
## field and in order, via the fixture tools/parity/dump_goals.mjs generates.

const FIXTURE_PATH: String = "res://tests/fixtures/goals.json"


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	# M11: Global Constraints line 65 also removes the corrupt-file twins.
	_remove(GoalManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH))
	_remove(GoalManager.CUMULATIVE_SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.CUMULATIVE_SAVE_PATH))


func after_each() -> void:
	_remove(GoalManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH))
	_remove(GoalManager.CUMULATIVE_SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.CUMULATIVE_SAVE_PATH))


func test_catalog_matches_the_typescript_in_order() -> void:
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	assert_not_null(file, "missing fixture — see tools/parity/dump_goals.mjs header")
	if file == null:
		return
	var json: JSON = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK)
	file.close()
	if not (json.data is Dictionary):
		fail_test("fixture root is not an object")
		return
	var root: Dictionary = json.data
	var entries_v: Variant = root.get("catalog")
	if not (entries_v is Array):
		fail_test("fixture has no catalog array")
		return
	var entries: Array = entries_v

	var gm: GoalManager = GoalManager.new()
	assert_eq(entries.size(), 57, "GoalManager.ts:83-640")
	assert_eq(gm.catalog.size(), entries.size())
	for i: int in range(mini(gm.catalog.size(), entries.size())):
		var e: Dictionary = entries[i]
		var g: GoalManager.Goal = gm.catalog[i]
		var at: String = " @%d (%s)" % [i, SaveStore.read_string(e, "id", "?")]
		assert_eq(g.id, SaveStore.read_string(e, "id", "?"), "id" + at)
		assert_eq(g.category, SaveStore.read_string(e, "category", "?"), "category" + at)
		assert_eq(g.title, SaveStore.read_string(e, "title", "?"), "title" + at)
		# DIVERGENCE(ECON R1): rewards ×50, and the two "milestone points" goals count
		# in those units (targets 500 / 1,250, their descriptions say so).
		var id: String = SaveStore.read_string(e, "id", "?")
		var target: int = SaveStore.read_int(e, "target", -1)
		if id.begins_with("total_points_"):
			target *= GoalManager.MILESTONE_REWARD_SCALE
		else:
			var want_desc: String = SaveStore.read_string(e, "description", "?")
			assert_eq(g.description, want_desc, "description" + at)
		assert_eq(g.target, target, "target" + at)
		var reward: int = SaveStore.read_int(e, "rewardPoints", -1)
		assert_eq(g.reward_points, reward * GoalManager.MILESTONE_REWARD_SCALE, "reward" + at)
		assert_eq(g.metric, SaveStore.read_string(e, "metric", "?"), "metric" + at)
		assert_eq(g.target_id, SaveStore.read_string(e, "targetId", "?"), "targetId" + at)
