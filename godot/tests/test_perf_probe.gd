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


func test_add_usec_accumulates_and_keeps_the_peak() -> void:
	PerfProbe.enabled = true
	PerfProbe.reset()
	PerfProbe.add_usec("e", 300)
	PerfProbe.add_usec("e", 200)
	assert_eq(PerfProbe.accumulated("e"), 500)
	var line: String = PerfProbe.format_line(1, 1, 1, {"e": 500}, {"e": 300}, "")
	assert_string_contains(line, "e=0.50/0.3")


func test_disabled_probe_ignores_add_usec() -> void:
	PerfProbe.enabled = false
	PerfProbe.reset()
	PerfProbe.add_usec("e", 300)
	assert_eq(PerfProbe.accumulated("e"), 0)


func test_frame_marks_split_a_frame_into_phys_proc_and_tail() -> void:
	PerfProbe.enabled = true
	PerfProbe.reset()
	PerfProbe.mark_physics(1000)
	PerfProbe.mark_physics(1400)  # a second step in the same frame keeps the first mark
	PerfProbe.mark_process(2000)
	PerfProbe.mark_drawn(2500)
	PerfProbe.mark_process(3100)  # a frame with no physics step
	assert_eq(PerfProbe.accumulated("m_phys"), 1000)
	assert_eq(PerfProbe.accumulated("m_proc"), 500)
	assert_eq(PerfProbe.accumulated("m_tail"), 600)
	PerfProbe.mark_drawn(3300)
	PerfProbe.mark_physics(4000)
	assert_eq(PerfProbe.accumulated("m_proc"), 700)
	assert_eq(PerfProbe.accumulated("m_tail"), 1300)


func test_mark_drawn_without_a_process_mark_records_nothing() -> void:
	PerfProbe.enabled = true
	PerfProbe.reset()
	PerfProbe.mark_drawn(2500)
	PerfProbe.mark_physics(3000)
	assert_eq(PerfProbe.accumulated("m_proc"), 0)
	assert_eq(PerfProbe.accumulated("m_tail"), 0)
