## test_log.gd
## PORTS: nothing — new file, covers src/core/log.gd
extends GutTest
## Proves the Log autoload resolves and filters by level.


func test_log_autoload_is_reachable() -> void:
	assert_not_null(Log, "Log autoload must be registered in project.godot")


func test_levels_are_ordered() -> void:
	assert_true(Log.Level.DEBUG < Log.Level.INFO, "DEBUG sorts below INFO")
	assert_true(Log.Level.WARN < Log.Level.ERROR, "WARN sorts below ERROR")


func test_min_level_suppresses_lower_levels() -> void:
	var restore: Log.Level = Log.min_level
	Log.min_level = Log.Level.WARN
	assert_false(Log.is_enabled(Log.Level.INFO), "INFO is below the WARN floor")
	assert_true(Log.is_enabled(Log.Level.ERROR), "ERROR is at or above the WARN floor")
	Log.min_level = restore
