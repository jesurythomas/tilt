## telemetry.gd
## PORTS: nothing — new file per docs/superpowers/specs/2026-09-29-analytics-crashes-design.md §3
# PORT-NOTE: no `class_name`, against CONVENTIONS §2. An autoload script cannot
# carry one: `class_name Telemetry` shadows the `Telemetry` singleton and every call
# site resolves against a Nil base. Same as Log and GameEvents.
extends Node
## Anonymous usage analytics behind one facade. Autoloaded as `Telemetry`.
##
## Standing rule (spec §5.3): signals go sim→UI only, so no sim class calls this.
## The shell and UI call it, and it listens to GameEvents. Swapping the vendor
## means replacing `backend`; nothing else in the game names a vendor.

## Where events go. The null backend until a vendor plugin is installed.
var backend: TelemetryBackend = TelemetryBackend.new()
## False when the player opted out of "Share anonymous usage data".
var enabled: bool = true

## Runs started this session, for `run_index`.
var run_count: int = 0


func _ready() -> void:
	GameEvents.goal_completed.connect(_on_goal_completed)


## Applies the opt-out and tells the vendor to stop or start collecting.
func set_enabled(is_on: bool) -> void:
	enabled = is_on
	backend.set_collection_enabled(is_on)


## Sends an event unless the player opted out.
func log_event(event: String, params: Dictionary = {}) -> void:
	if enabled:
		backend.log_event(event, params)


## A run began (after the cold open starts). `mode` is the save-file id.
func run_start(mode: String, first_run: bool, ship: String, arena: String) -> void:
	run_count += 1
	log_event(
		"run_start",
		{
			"mode": mode,
			"first_run": int(first_run),
			"run_index": run_count,
			"ship": ship,
			"arena": arena,
		}
	)


## A run ended in death. `lives_used` is the starting lives (every one was spent).
func run_end(
	mode: String, stats: Types.GameStats, first_run: bool, lives_used: int, is_best: bool
) -> void:
	log_event(
		"run_end",
		{
			"mode": mode,
			"score": stats.score,
			"seconds": roundi(stats.survival_time),
			"kills": stats.kills,
			"best_combo": stats.best_combo,
			"close_calls": stats.close_calls,
			"max_mult": stats.max_multiplier,
			"lives_used": lives_used,
			"is_best": int(is_best),
			"first_run": int(first_run),
			"killer": stats.killer,
		}
	)


## A purchase went through. `kind` is perk, boost, ship, cursor, skin or arena.
func upgrade_buy(kind: String, id: String, rank: int, cost: int, balance_after: int) -> void:
	log_event(
		"upgrade_buy",
		{"kind": kind, "id": id, "rank": rank, "cost": cost, "balance_after": balance_after}
	)


func _on_goal_completed(goal_id: String) -> void:
	log_event("achievement", {"id": goal_id})
