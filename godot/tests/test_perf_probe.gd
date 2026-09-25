## test_perf_probe.gd
## Tests PerfProbe's report line and its debug-only gate (M11c P1).
extends GutTest


func after_each() -> void:
	PerfProbe.enabled = OS.is_debug_build()
	PerfProbe.reset()


func test_format_line_averages_per_frame_and_sorts_keys() -> void:
	var acc: Dictionary[String, int] = {"s_swarm": 6000, "d_entity": 3000}
	var peak: Dictionary[String, int] = {"s_swarm": 2500, "d_entity": 1100}
	var line: String = PerfProbe.format_line(2, 4, 2, acc, peak, "en=10")
	assert_eq(line, "PERF fps=2 steps=4 maxsteps=2 en=10 | d_entity=1.50/1.1 s_swarm=3.00/2.5")


func test_disabled_probe_records_nothing() -> void:
	PerfProbe.enabled = false
	PerfProbe.reset()
	PerfProbe.add("x", PerfProbe.now() - 1000)
	assert_eq(PerfProbe.accumulated("x"), 0)


func test_enabled_probe_accumulates_elapsed_time() -> void:
	PerfProbe.enabled = true
	PerfProbe.reset()
	PerfProbe.add("x", PerfProbe.now() - 1000)
	assert_gte(PerfProbe.accumulated("x"), 1000)
