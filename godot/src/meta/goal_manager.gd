## goal_manager.gd
## PORTS: web/src/tilt-to-live/GoalManager.ts (983 lines, source commit 7be9614)
class_name GoalManager
extends RefCounted
## Milestone-based achievement, challenge and points engine.
##
## Instantiated by GameRoot and handed to RunController and GoalsHUD. Never an
## autoload (spec §5.2).
##
## PORT-NOTE: category and metric keep the TS string spellings (M7 decision
## (a), as perk keys do): isTotalGoal's startsWith('total_') (:716) and
## GoalsHUD's tier substring tests (GoalsHUD.ts:342-349) read them as strings.
##
## PORT-NOTE: completedGoalIds is a Set (:73); here a Dictionary's keys, which
## keep insertion order as Array.from(set) does (:686).

## PORT: web/src/tilt-to-live/GoalManager.ts:69
const STORAGE_KEY: String = "tilt_to_live_completed_goals_v1"
## PORT: web/src/tilt-to-live/GoalManager.ts:70
const CUMULATIVE_STORAGE_KEY: String = "tilt_to_live_cumulative_stats_v1"
## The localStorage keys as user:// files (spec §4.6).
const SAVE_PATH: String = "user://" + STORAGE_KEY + ".json"
## M15: CONVENTIONS §5 — every public member is documented.
const CUMULATIVE_SAVE_PATH: String = "user://" + CUMULATIVE_STORAGE_KEY + ".json"

## Every goal, in the TS's order — evaluation order and the 3-per-run cap
## depend on it. PORT: web/src/tilt-to-live/GoalManager.ts:83-640
var catalog: Array[Goal] = _build_catalog()
## Lifetime totals. PORT: web/src/tilt-to-live/GoalManager.ts:642-647
var cumulative: CumulativeStats = CumulativeStats.new()

var _completed_goal_ids: Dictionary[String, bool] = {}  # PORT: :73
var _on_goal_completed_cb: Callable = Callable()  # PORT: :74
var _on_points_awarded_cb: Callable = Callable()  # PORT: :75
# Optional progression reference for the unlock-family goals (:77-81).
var _progression: ProgressionManager = null


## PORT: web/src/tilt-to-live/GoalManager.ts:649-653
func _init(p_progression: ProgressionManager = null) -> void:
	_load_completed()
	_load_cumulative()
	_progression = p_progression


## PORT: web/src/tilt-to-live/GoalManager.ts:655-661
func set_callbacks(on_goal_completed: Callable, on_points_awarded: Callable) -> void:
	_on_goal_completed_cb = on_goal_completed
	_on_points_awarded_cb = on_points_awarded


## Wires (or rewires) the progression evaluate_unlock_goals() reads. Safe to
## call never — unlock goals then simply never complete.
## PORT: web/src/tilt-to-live/GoalManager.ts:668-670
func set_progression(progression: ProgressionManager) -> void:
	_progression = progression


## PORT: web/src/tilt-to-live/GoalManager.ts:672-682
# PORT-NOTE: `new Set(parsed)` (:678) admits any element; load_string_list
# keeps strings only. The TS only ever writes goal-id strings (:686).
func _load_completed() -> void:
	for id: String in SaveStore.load_string_list(SAVE_PATH):
		_completed_goal_ids[id] = true


## PORT: web/src/tilt-to-live/GoalManager.ts:684-688
func save_completed() -> void:
	var ids: Array[String] = []
	ids.assign(_completed_goal_ids.keys())
	SaveStore.save_string_list(SAVE_PATH, ids)


## PORT: web/src/tilt-to-live/GoalManager.ts:690-703
# PORT-NOTE: `Number(x) || 0` (:696-699) also accepts numeric strings;
# read_int does not. Every total is an int the TS itself wrote (kills, floor()ed
# seconds, points, score), so no save the TS produces is read differently.
func _load_cumulative() -> void:
	var raw: Dictionary = SaveStore.load_dict(CUMULATIVE_SAVE_PATH)
	cumulative.total_kills = SaveStore.read_int(raw, "totalKills", 0)
	cumulative.total_survival_time = SaveStore.read_int(raw, "totalSurvivalTime", 0)
	cumulative.total_points_earned = SaveStore.read_int(raw, "totalPointsEarned", 0)
	cumulative.total_score = SaveStore.read_int(raw, "totalScore", 0)


## PORT: web/src/tilt-to-live/GoalManager.ts:705-709
func save_cumulative() -> void:
	SaveStore.save_dict(CUMULATIVE_SAVE_PATH, cumulative.to_dict())


## PORT: web/src/tilt-to-live/GoalManager.ts:711-713
func is_completed(goal_id: String) -> bool:
	return _completed_goal_ids.has(goal_id)


## PORT: web/src/tilt-to-live/GoalManager.ts:715-717
func is_total_goal(goal: Goal) -> bool:
	return goal.category == "cumulative" or goal.metric.begins_with("total_")


## Unlock-family goals, evaluated only by evaluate_unlock_goals() against
## progression state. PORT: web/src/tilt-to-live/GoalManager.ts:725-732
func is_unlock_goal(goal: Goal) -> bool:
	return (
		goal.metric == "ship_unlocked"
		or goal.metric == "enemy_skin_unlocked"
		or goal.metric == "arena_unlocked"
		or goal.metric == "weapon_fully_upgraded"
	)


## PORT: web/src/tilt-to-live/GoalManager.ts:734-736
func get_completed_count() -> int:
	return _completed_goal_ids.size()


## PORT: web/src/tilt-to-live/GoalManager.ts:738-740
func get_total_goals_count() -> int:
	return catalog.size()


## The first `max_count` uncompleted goals, each with current 0.
## PORT: web/src/tilt-to-live/GoalManager.ts:742-748
func get_active_goals(max_count: int = 3) -> Array[ActiveGoal]:
	var out: Array[ActiveGoal] = []
	for goal: Goal in catalog:
		if out.size() >= max_count:
			break
		if _completed_goal_ids.has(goal.id):
			continue
		var active: ActiveGoal = ActiveGoal.new()
		active.goal = goal
		out.append(active)
	return out


# TASK 3 INSERTS evaluate_live_total_goals, evaluate_run, evaluate_unlock_goals,
# _check_unlock_goal, _is_weapon_fully_upgraded, get_metric_value and
# reset_all_progress HERE, in that order (GoalManager.ts:754-982).


## One catalog entry. GDScript-only construction helper for the :83-640 literal.
static func _goal(
	id: String,
	category: String,
	title: String,
	description: String,
	target: int,
	reward_points: int,
	metric: String,
	target_id: String = ""
) -> Goal:
	var g: Goal = Goal.new()
	g.id = id
	g.category = category
	g.title = title
	g.description = description
	g.target = target
	g.reward_points = reward_points
	g.metric = metric
	g.target_id = target_id
	return g


## PORT: web/src/tilt-to-live/GoalManager.ts:83-640
static func _build_catalog() -> Array[Goal]:
	var out: Array[Goal] = [
		# Score Milestones
		# PORT: web/src/tilt-to-live/GoalManager.ts:85-93
		_goal(
			"score_1k", "score", "Rookie Dodger", "Reach 1,000 score in a run", 1000, 1, "run_score"
		),
		# PORT: :94-102
		_goal(
			"score_5k", "score", "Neon Striker", "Reach 5,000 score in a run", 5000, 2, "run_score"
		),
		# PORT: :103-111
		_goal(
			"score_10k",
			"score",
			"Swarm Survivor",
			"Reach 10,000 score in a run",
			10000,
			3,
			"run_score"
		),
		# PORT: :112-120
		_goal(
			"score_25k",
			"score",
			"Apex Dodger",
			"Reach 25,000 score in a run",
			25000,
			5,
			"run_score"
		),
		# PORT: :121-129
		_goal(
			"score_50k",
			"score",
			"Orbital Ace",
			"Reach 50,000 score in a run",
			50000,
			8,
			"run_score"
		),
		# Combat Kills
		# PORT: :132-140
		_goal(
			"kills_15",
			"combat",
			"First Extermination",
			"Destroy 15 red dots in a run",
			15,
			1,
			"run_kills"
		),
		# PORT: :141-149
		_goal(
			"kills_50", "combat", "Pest Control", "Destroy 50 red dots in a run", 50, 2, "run_kills"
		),
		# PORT: :150-158
		_goal(
			"kills_100", "combat", "Centurion", "Destroy 100 red dots in a run", 100, 3, "run_kills"
		),
		# PORT: :159-167
		_goal(
			"kills_200",
			"combat",
			"Swarm Annihilator",
			"Destroy 200 red dots in a run",
			200,
			5,
			"run_kills"
		),
		# Combo Multipliers
		# PORT: :170-178
		_goal("mult_3", "combo", "Momentum", "Reach a 3x Multiplier", 3, 1, "run_multiplier"),
		# PORT: :179-187
		_goal("mult_5", "combo", "Fever Pitch", "Reach a 5x Multiplier", 5, 2, "run_multiplier"),
		# PORT: :188-196
		_goal("mult_8", "combo", "Hyper Rhythm", "Reach an 8x Multiplier", 8, 3, "run_multiplier"),
		# PORT: :197-205
		_goal(
			"mult_12",
			"combo",
			"Ascended Multiplier",
			"Reach a 12x Multiplier",
			12,
			5,
			"run_multiplier"
		),
		# Survival & Near-Misses
		# PORT: :208-216
		_goal(
			"close_call_3",
			"survival",
			"Living on the Edge",
			"Trigger 3 Close Calls in a run",
			3,
			1,
			"run_close_calls"
		),
		# PORT: :217-225
		_goal(
			"close_call_7",
			"survival",
			"Daredevil",
			"Trigger 7 Close Calls in a run",
			7,
			2,
			"run_close_calls"
		),
		# PORT: :226-234
		_goal(
			"survive_30",
			"survival",
			"Holding the Line",
			"Survive for 30 seconds",
			30,
			1,
			"run_survival"
		),
		# PORT: :235-243
		_goal(
			"survive_60",
			"survival",
			"Minute Master",
			"Survive for 60 seconds",
			60,
			2,
			"run_survival"
		),
		# PORT: :244-252
		_goal(
			"survive_120",
			"survival",
			"Iron Will",
			"Survive for 120 seconds",
			120,
			4,
			"run_survival"
		),
		# Weapons
		# PORT: :255-263
		_goal(
			"nuke_3",
			"weapons",
			"Atomic Retribution",
			"Detonate 3 Nukes in one run",
			3,
			2,
			"run_nukes"
		),
		# PORT: :264-272
		_goal(
			"vortex_20",
			"weapons",
			"Singularity Feast",
			"Absorb 20 dots with Vortexes",
			20,
			2,
			"run_vortex_absorbs"
		),
		# PORT: :273-281
		_goal(
			"laser_20",
			"weapons",
			"Photon Slicer",
			"Slice 20 dots with Laser Lances",
			20,
			2,
			"run_laser_slices"
		),
		# PORT: :282-290
		_goal(
			"missiles_30",
			"weapons",
			"Cluster Barrage",
			"Fire 30 Homing Missiles in a run",
			30,
			2,
			"run_missiles"
		),
		# PORT: :291-299
		_goal(
			"freeze_15",
			"weapons",
			"Sub-Zero Shatter",
			"Shatter 15 Frozen red dots",
			15,
			2,
			"run_freeze_shatters"
		),
		# PORT: :300-308
		_goal(
			"shield_10",
			"weapons",
			"Battering Ram",
			"Ram 10 dots while Shielded",
			10,
			2,
			"run_shield_rams"
		),
		# Game Mode Challenges
		# PORT: :311-319
		_goal(
			"mode_code_red_30",
			"modes",
			"Red Alert Survivor",
			"Survive 30s in Code Red mode",
			30,
			2,
			"code_red_survival"
		),
		# PORT: :320-328
		_goal(
			"mode_code_red_60",
			"modes",
			"Code Red Champion",
			"Survive 60s in Code Red mode",
			60,
			4,
			"code_red_survival"
		),
		# PORT: :329-337
		_goal(
			"mode_gauntlet_30",
			"modes",
			"Gauntlet Runner",
			"Survive 30s in Gauntlet mode",
			30,
			2,
			"gauntlet_survival"
		),
		# Lifetime Cumulative Milestones
		# PORT: :340-348
		_goal(
			"total_kills_100",
			"cumulative",
			"Century of Destruction",
			"Destroy 100 total red dots across all games",
			100,
			2,
			"total_kills"
		),
		# PORT: :349-357
		_goal(
			"total_kills_500",
			"cumulative",
			"Swarm Exterminator",
			"Destroy 500 total red dots across all games",
			500,
			4,
			"total_kills"
		),
		# PORT: :358-366
		_goal(
			"total_kills_1500",
			"cumulative",
			"Swarm Nemesis",
			"Destroy 1,500 total red dots across all games",
			1500,
			8,
			"total_kills"
		),
		# PORT: :367-375
		_goal(
			"total_survival_180",
			"cumulative",
			"Persistent Pilot",
			"Survive 3 minutes (180s) total across all games",
			180,
			2,
			"total_survival"
		),
		# PORT: :376-384
		_goal(
			"total_survival_600",
			"cumulative",
			"Decade of Minutes",
			"Survive 10 minutes (600s) total across all games",
			600,
			5,
			"total_survival"
		),
		# PORT: :385-393
		_goal(
			"total_score_50k",
			"cumulative",
			"Score Accumulator",
			"Accumulate 50,000 total score across all games",
			50000,
			3,
			"total_score"
		),
		# PORT: :394-402
		_goal(
			"total_score_250k",
			"cumulative",
			"Quarter Millionaire",
			"Accumulate 250,000 total score across all games",
			250000,
			6,
			"total_score"
		),
		# PORT: :403-411
		_goal(
			"total_points_10",
			"cumulative",
			"Vault Apprentice",
			"Earn 10 milestone points in total",
			10,
			2,
			"total_points"
		),
		# PORT: :412-420
		_goal(
			"total_points_25",
			"cumulative",
			"Vault Master",
			"Earn 25 milestone points in total",
			25,
			5,
			"total_points"
		),
		# Unlock Milestones: Ships
		# PORT: :423-432
		_goal(
			"unlock_ship_solar",
			"unlocks",
			"Aegis Ascendant",
			"Unlock the Aegis ship",
			1,
			2,
			"ship_unlocked",
			"solar"
		),
		# PORT: :433-442
		_goal(
			"unlock_ship_cyber",
			"unlocks",
			"Matrix Runner",
			"Unlock the Matrix ship",
			1,
			3,
			"ship_unlocked",
			"cyber"
		),
		# PORT: :443-452
		_goal(
			"unlock_ship_shuriken",
			"unlocks",
			"Bladed Vanguard",
			"Unlock the Shuriken ship",
			1,
			3,
			"ship_unlocked",
			"shuriken"
		),
		# PORT: :453-462
		_goal(
			"unlock_ship_revenant",
			"unlocks",
			"Reborn in Fire",
			"Unlock the Revenant ship",
			1,
			6,
			"ship_unlocked",
			"revenant"
		),
		# Unlock Milestones: Enemy Skins
		# PORT: :465-474
		_goal(
			"unlock_skin_toxic",
			"unlocks",
			"Biohazard Collector",
			"Unlock the Toxic Biohazard enemy skin",
			1,
			2,
			"enemy_skin_unlocked",
			"toxic"
		),
		# PORT: :475-484
		_goal(
			"unlock_skin_glitch",
			"unlocks",
			"Glitch Collector",
			"Unlock the Cyber Glitch enemy skin",
			1,
			2,
			"enemy_skin_unlocked",
			"glitch"
		),
		# PORT: :485-494
		_goal(
			"unlock_skin_magma",
			"unlocks",
			"Magma Collector",
			"Unlock the Molten Magma enemy skin",
			1,
			3,
			"enemy_skin_unlocked",
			"magma"
		),
		# PORT: :495-504
		_goal(
			"unlock_skin_void",
			"unlocks",
			"Void Collector",
			"Unlock the Abyssal Void enemy skin",
			1,
			3,
			"enemy_skin_unlocked",
			"void"
		),
		# PORT: :505-514
		_goal(
			"unlock_skin_gold",
			"unlocks",
			"Gold Collector",
			"Unlock the Midas Gold enemy skin",
			1,
			4,
			"enemy_skin_unlocked",
			"gold"
		),
		# Unlock Milestones: Arena Themes
		# PORT: :517-526
		_goal(
			"unlock_arena_synthwave",
			"unlocks",
			"Sunset Cartographer",
			"Unlock the Synthwave Sunset arena",
			1,
			2,
			"arena_unlocked",
			"synthwave"
		),
		# PORT: :527-536
		_goal(
			"unlock_arena_nebula",
			"unlocks",
			"Nebula Cartographer",
			"Unlock the Cosmic Nebula arena",
			1,
			2,
			"arena_unlocked",
			"nebula"
		),
		# PORT: :537-546
		_goal(
			"unlock_arena_matrix",
			"unlocks",
			"Terminal Cartographer",
			"Unlock the Matrix Terminal arena",
			1,
			3,
			"arena_unlocked",
			"matrix"
		),
		# PORT: :547-556
		_goal(
			"unlock_arena_supernova",
			"unlocks",
			"Furnace Cartographer",
			"Unlock the Supernova Furnace arena",
			1,
			3,
			"arena_unlocked",
			"supernova"
		),
		# PORT: :557-566
		_goal(
			"unlock_arena_blueprint",
			"unlocks",
			"Blueprint Cartographer",
			"Unlock the Architectural Blueprint arena",
			1,
			4,
			"arena_unlocked",
			"blueprint"
		),
		# Unlock Milestones: Weapons Fully Upgraded
		# PORT: :570-579
		_goal(
			"weapon_maxed_blackhole",
			"unlocks",
			"Singularity Perfected",
			"Fully upgrade the Vortex: max every perk rank and unlock every keystone",
			1,
			6,
			"weapon_fully_upgraded",
			"blackhole"
		),
		# PORT: :580-589
		_goal(
			"weapon_maxed_nuke",
			"unlocks",
			"Nuclear Doctrine",
			"Fully upgrade the Nuke: max every perk rank and unlock every keystone",
			1,
			6,
			"weapon_fully_upgraded",
			"nuke"
		),
		# PORT: :590-599
		_goal(
			"weapon_maxed_shield",
			"unlocks",
			"Absolute Defense",
			"Fully upgrade the Shield: max every perk rank and unlock every keystone",
			1,
			6,
			"weapon_fully_upgraded",
			"shield"
		),
		# PORT: :600-609
		_goal(
			"weapon_maxed_missiles",
			"unlocks",
			"Missile Command",
			"Fully upgrade Homing Missiles: max every perk rank",
			1,
			6,
			"weapon_fully_upgraded",
			"missiles"
		),
		# PORT: :610-619
		_goal(
			"weapon_maxed_laser",
			"unlocks",
			"Photon Perfection",
			"Fully upgrade the Laser Lance: max every perk rank and unlock every keystone",
			1,
			6,
			"weapon_fully_upgraded",
			"laser"
		),
		# PORT: :620-629
		_goal(
			"weapon_maxed_lightning",
			"unlocks",
			"Storm Overlord",
			"Fully upgrade Chain Lightning: max every perk rank",
			1,
			6,
			"weapon_fully_upgraded",
			"lightning"
		),
		# PORT: :630-639
		_goal(
			"weapon_maxed_freeze",
			"unlocks",
			"Absolute Zero",
			"Fully upgrade Freeze: max every perk rank and unlock every keystone",
			1,
			6,
			"weapon_fully_upgraded",
			"freeze"
		),
	]
	return out


## PORT: web/src/tilt-to-live/GoalManager.ts:10-45
class Goal:
	extends RefCounted
	var id: String = ""
	var category: String = ""
	var title: String = ""
	var description: String = ""
	var target: int = 0
	var reward_points: int = 0
	## The unlock family's ship / skin / arena / WeaponPerks key; "" for the TS's
	## absent targetId (:20).
	var target_id: String = ""
	var metric: String = ""


## PORT: web/src/tilt-to-live/GoalManager.ts:47-52
class CumulativeStats:
	extends RefCounted
	var total_kills: int = 0
	var total_survival_time: int = 0
	var total_points_earned: int = 0
	var total_score: int = 0

	## The TS object shape (:707).
	func to_dict() -> Dictionary:
		return {
			"totalKills": total_kills,
			"totalSurvivalTime": total_survival_time,
			"totalPointsEarned": total_points_earned,
			"totalScore": total_score,
		}


## PORT: web/src/tilt-to-live/GoalManager.ts:54-67 (defaults: TiltGame.ts:83-96)
class RunTracker:
	extends RefCounted
	## The TS mode id: "classic", "code-red", "gauntlet" (GameOptionsManager.MODE_IDS).
	var mode: String = "classic"
	var score: int = 0
	var kills: int = 0
	var multiplier: float = 1.0
	var survival_time: float = 0.0
	var close_calls: int = 0
	var nukes_detonated: int = 0
	var vortex_absorbs: int = 0
	var laser_slices: int = 0
	var missiles_fired: int = 0
	var freeze_shatters: int = 0
	var shield_rams: int = 0


## getActiveGoals' `{ goal, current }` (:742-748).
class ActiveGoal:
	extends RefCounted
	var goal: Goal = null
	var current: float = 0.0
