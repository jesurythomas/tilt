## bench_particles.gd — desktop cost of the particle flush and draw, GDScript vs C++
## (M11c N7). Not part of the suite. Windowed (the draw half needs a renderer):
##   "$GODOT" --path godot --render-thread safe -s addons/gut/gut_cmdln.gd -gtest=res://bench/bench_particles.gd -gexit
## The pool is kept full (400, MAX_PARTICLES): each frame re-emits what retired, and
## the sim queues 2 steps per frame (120 Hz sim, 60 fps).
extends GutTest

const BOUNDS: Vector2 = Vector2(2162.0, 1056.0)
const FRAMES: int = 240
const DT: float = 1.0 / 120.0


func after_each() -> void:
	ParticleEngine.use_native = true
	EffectLayer.use_native_draw = true


func _top_up(pe: ParticleEngine) -> void:
	while pe.particles.size() < ParticleEngine.MAX_PARTICLES:
		var x: float = randf() * BOUNDS.x
		var y: float = randf() * BOUNDS.y
		pe.emit_explosion(x, y, Color(1.0, 0.3, 0.2), 20)
		pe.emit_ice_shatter(x, y, 6)


func _bench(native: bool) -> Vector2:
	ParticleEngine.use_native = native
	EffectLayer.use_native_draw = native
	seed(8)
	var pe: ParticleEngine = ParticleEngine.new()
	var layer: EffectLayer = EffectLayer.new()
	add_child_autofree(layer)
	layer.bind(pe, null, null)
	var flush_us: int = 0
	PerfProbe.enabled = true
	PerfProbe.reset()
	for f: int in range(FRAMES):
		_top_up(pe)
		pe.step(DT)
		pe.step(DT)
		var t0: int = Time.get_ticks_usec()
		pe.flush()
		flush_us += Time.get_ticks_usec() - t0
		layer.queue_redraw()
		await get_tree().process_frame
	return Vector2(flush_us / float(FRAMES), PerfProbe.accumulated("d_effect") / float(FRAMES))


func test_bench_particles() -> void:
	for run: int in range(3):
		var gd: Vector2 = await _bench(false)
		var cpp: Vector2 = await _bench(true)
		print(
			(
				"BENCH particles (400)  flush %6.1f -> %6.1f us/frame   draw %6.1f -> %6.1f us/frame"
				% [gd.x, cpp.x, gd.y, cpp.y]
			)
		)
	pass_test("bench")
