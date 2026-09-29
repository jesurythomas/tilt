## test_telemetry.gd
## PORTS: nothing — new file, covers src/core/telemetry.gd (spec 2026-09-29 §3, §4)
extends GutTest
## Proves the Telemetry facade: event names and params reach the backend, the
## opt-out silences it, and the autoload is wired to GameEvents.

var _rec: RecordingTelemetryBackend = null
var _previous: TelemetryBackend = null


func before_each() -> void:
	_rec = RecordingTelemetryBackend.new()
	_previous = Telemetry.backend
	Telemetry.backend = _rec
	Telemetry.enabled = true
	Telemetry.run_count = 0


func after_each() -> void:
	Telemetry.backend = _previous
	Telemetry.enabled = true


func _stats() -> Types.GameStats:
	var s: Types.GameStats = Types.GameStats.new()
	s.score = 4200
	s.kills = 31
	s.survival_time = 75.6
	s.best_combo = 9
	s.close_calls = 4
	s.max_multiplier = 6.0
	s.killer = "chaser"
	return s


func test_log_event_reaches_the_backend() -> void:
	Telemetry.log_event("mode_select", {"mode": "classic"})
	assert_eq(_rec.names, ["mode_select"] as Array[String])
	assert_eq(_rec.params[0], {"mode": "classic"})


func test_disabled_drops_events_and_tells_the_backend() -> void:
	Telemetry.set_enabled(false)
	Telemetry.log_event("run_start")
	Telemetry.upgrade_buy("perk", "laser.width", 2, 300, 100)
	assert_eq(_rec.names.size(), 0, "opted out: nothing is sent")
	assert_eq(_rec.collection_calls, [false] as Array[bool])
	Telemetry.set_enabled(true)
	Telemetry.log_event("run_start")
	assert_eq(_rec.names.size(), 1, "opted back in")
	assert_eq(_rec.collection_calls, [false, true] as Array[bool])


func test_run_start_params_and_session_run_index() -> void:
	Telemetry.run_start("code-red", true, "solar", "grid")
	assert_eq(
		_rec.last_params("run_start"),
		{"mode": "code-red", "first_run": 1, "run_index": 1, "ship": "solar", "arena": "grid"}
	)
	Telemetry.run_start("classic", false, "solar", "grid")
	assert_eq(
		_rec.last_params("run_start"),
		{"mode": "classic", "first_run": 0, "run_index": 2, "ship": "solar", "arena": "grid"},
		"counts runs this session"
	)


func test_run_end_params() -> void:
	Telemetry.run_end("gauntlet", _stats(), false, 3, true)
	assert_eq(
		_rec.last_params("run_end"),
		{
			"mode": "gauntlet",
			"score": 4200,
			"seconds": 76,
			"kills": 31,
			"best_combo": 9,
			"close_calls": 4,
			"max_mult": 6.0,
			"lives_used": 3,
			"is_best": 1,
			"first_run": 0,
			"killer": "chaser",
		}
	)


func test_upgrade_buy_params() -> void:
	Telemetry.upgrade_buy("boost", "extraLives", 2, 500, 1200)
	assert_eq(
		_rec.last_params("upgrade_buy"),
		{"kind": "boost", "id": "extraLives", "rank": 2, "cost": 500, "balance_after": 1200}
	)


func test_goal_completed_logs_an_achievement() -> void:
	GameEvents.goal_completed.emit("score_1k")
	assert_eq(_rec.names, ["achievement"] as Array[String])
	assert_eq(_rec.params[0], {"id": "score_1k"})


func test_base_backend_is_a_silent_no_op() -> void:
	var b: TelemetryBackend = TelemetryBackend.new()
	b.log_event("x", {})
	b.set_collection_enabled(false)
	pass_test("the null backend accepts every call")
