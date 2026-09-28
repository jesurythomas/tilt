## bench_emit.gd — desktop cost of the GDScript emitters (M11c N7a: PerilParticle's
## native fields vs the old GDScript Particle). Not part of the suite:
##   "$GODOT" --headless --path godot -s addons/gut/gut_cmdln.gd -gtest=res://bench/bench_emit.gd -gexit
## A warm pool; each round emits 12 explosions of 32 sparks (396 particles), timed, then
## retires them all.
extends GutTest


func test_bench_emit() -> void:
	seed(5)
	var pe: ParticleEngine = ParticleEngine.new()
	for run: int in range(3):
		var us: int = 0
		for r: int in range(200):
			var t0: int = Time.get_ticks_usec()
			for k: int in range(12):
				pe.emit_explosion(100.0 + k, 200.0, Color.RED, 32)
			us += Time.get_ticks_usec() - t0
			pe.update(10.0)
		print("BENCH emit 12x32 sparks  %6.1f us/round" % (us / 200.0))
	pass_test("bench")
