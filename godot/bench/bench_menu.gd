## bench_menu.gd — the menu backdrop left running (UI R10): its enemy count and µs/tick
## per simulated minute. Not part of the suite:
##   "$GODOT" --headless --path godot -s addons/gut/gut_cmdln.gd \
##     -gtest=res://bench/bench_menu.gd -gexit
extends GutTest

const BOUNDS: Vector2 = Vector2(2424.0, 1080.0)


func test_bench_menu_idle() -> void:
	seed(7)
	var b: MenuBackdrop = MenuBackdrop.new()
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	for minute: int in range(10):
		var us: int = 0
		var peak: int = 0
		for i: int in range(3600):
			var t0: int = Time.get_ticks_usec()
			b.update(1.0 / 60.0, BOUNDS, grid, particles)
			us += Time.get_ticks_usec() - t0
			peak = maxi(peak, b.menu_swarm.enemies.size())
		print(
			(
				"BENCH menu min %2d  en=%4d peak=%4d  %6.1f us/tick"
				% [minute + 1, b.menu_swarm.enemies.size(), peak, us / 3600.0]
			)
		)
	pass_test("bench")
