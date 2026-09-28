## perf_probe.gd
## DIVERGENCE(M11c P1): no TS counterpart — device instrumentation for the A55
## performance pass. Debug builds only; one PERF line per second to stdout (logcat).
class_name PerfProbe
extends RefCounted

## DIVERGENCE(M11c P1): one report per second of real time.
const WINDOW_USEC: int = 1000000
## DIVERGENCE(M11c P1): microseconds → milliseconds.
const USEC_PER_MS: float = 1000.0

## Release builds pay nothing: every entry point returns at once when false.
static var enabled: bool = OS.is_debug_build()
static var _acc: Dictionary[String, int] = {}
static var _peak: Dictionary[String, int] = {}
static var _frames: int = 0
static var _steps: int = 0
static var _steps_this_frame: int = 0
static var _max_steps: int = 0
static var _window_start: int = 0
## Main-thread frame marks (µs; 0 = unset): the first physics step of this frame, the
## process step's start, and the previous frame's end of the `_draw` flush.
static var _mark_physics: int = 0
static var _mark_process: int = 0
static var _mark_drawn: int = 0


## Start stamp for add().
static func now() -> int:
	return Time.get_ticks_usec()


## Adds the time since t0 to the section named key.
static func add(key: String, t0: int) -> void:
	if not enabled:
		return
	add_usec(key, Time.get_ticks_usec() - t0)


## Adds d microseconds, measured elsewhere (an engine monitor), to the section named key.
static func add_usec(key: String, d: int) -> void:
	if not enabled:
		return
	_acc[key] = _acc.get(key, 0) + d
	if d > _peak.get(key, 0):
		_peak[key] = d


## Microseconds recorded for key in the current window.
static func accumulated(key: String) -> int:
	return _acc.get(key, 0)


## SceneTree.physics_frame: the first one of a frame starts its physics block and ends
## the previous frame's tail.
static func mark_physics(t: int) -> void:
	if not enabled:
		return
	_close_tail(t)
	if _mark_physics == 0:
		_mark_physics = t


## SceneTree.process_frame: ends the physics block (m_phys) and starts m_proc.
static func mark_process(t: int) -> void:
	if not enabled:
		return
	_close_tail(t)
	if _mark_physics != 0:
		add_usec("m_phys", t - _mark_physics)
		_mark_physics = 0
	_mark_process = t


## Deferred after the frame's redraw requests: ends m_proc (process callbacks and the
## `_draw` flush). m_tail runs from here to the next frame's first mark — RenderingServer
## sync and draw, input, and the rest of the engine's iteration.
static func mark_drawn(t: int) -> void:
	if not enabled or _mark_process == 0:
		return
	add_usec("m_proc", t - _mark_process)
	_mark_process = 0
	_mark_drawn = t


static func _close_tail(t: int) -> void:
	if _mark_drawn != 0:
		add_usec("m_tail", t - _mark_drawn)
		_mark_drawn = 0


## Counts one sim tick.
static func step() -> void:
	if not enabled:
		return
	_steps += 1
	_steps_this_frame += 1


## Clears the current window.
static func reset() -> void:
	_acc.clear()
	_peak.clear()
	_frames = 0
	_steps = 0
	_steps_this_frame = 0
	_max_steps = 0
	_window_start = 0
	_mark_physics = 0
	_mark_process = 0
	_mark_drawn = 0


## Counts one rendered frame; prints and resets once per window. `extra` builds the
## report's extra fields and runs only when a line prints (M11c P24: a GPU-time query
## every frame forces a RenderingServer sync once rendering has its own thread).
static func frame(extra: Callable) -> void:
	if not enabled:
		return
	var t: int = Time.get_ticks_usec()
	_frames += 1
	_max_steps = maxi(_max_steps, _steps_this_frame)
	_steps_this_frame = 0
	if _window_start == 0:
		_window_start = t
		return
	if t - _window_start < WINDOW_USEC:
		return
	var extra_text: String = extra.call()
	print(format_line(_frames, _steps, _max_steps, _acc, _peak, extra_text))
	reset()
	_window_start = t


## One report line: each section as per-frame average / single-call peak, in ms.
static func format_line(
	frames: int,
	steps: int,
	max_steps: int,
	acc: Dictionary[String, int],
	peak: Dictionary[String, int],
	extra: String
) -> String:
	var keys: Array[String] = acc.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k: String in keys:
		parts.append(
			"%s=%.2f/%.1f" % [k, acc[k] / USEC_PER_MS / frames, peak.get(k, 0) / USEC_PER_MS]
		)
	return (
		"PERF fps=%d steps=%d maxsteps=%d %s | %s"
		% [frames, steps, max_steps, extra, " ".join(parts)]
	)
