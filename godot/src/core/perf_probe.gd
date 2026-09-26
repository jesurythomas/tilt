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


## Start stamp for add().
static func now() -> int:
	return Time.get_ticks_usec()


## Adds the time since t0 to the section named key.
static func add(key: String, t0: int) -> void:
	if not enabled:
		return
	var d: int = Time.get_ticks_usec() - t0
	_acc[key] = _acc.get(key, 0) + d
	if d > _peak.get(key, 0):
		_peak[key] = d


## Microseconds recorded for key in the current window.
static func accumulated(key: String) -> int:
	return _acc.get(key, 0)


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
