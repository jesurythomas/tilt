## bench_draw.gd — windowed CPU benchmark of EntityLayer._draw (M11c Task 5; not in the suite).
## Run WITHOUT --headless (the dummy renderer skips canvas work):
##   "$GODOT" --path godot -s addons/gut/gut_cmdln.gd -gtest=res://bench/bench_draw.gd -gexit
extends GutTest

const BOUNDS: Vector2 = Vector2(2162.0, 1056.0)
const ENEMIES: int = 115
const FRAMES: int = 180


func test_bench_entity_draw() -> void:
	seed(1234)
	var progression: ProgressionManager = ProgressionManager.new()
	var player: PlayerShip = PlayerShip.new(BOUNDS.x * 0.5, BOUNDS.y * 0.5)
	var swarm: EnemySwarm = EnemySwarm.new()
	swarm.scale = 1.25
	for i: int in range(ENEMIES):
		swarm.spawn_seeker(BOUNDS, randf() * BOUNDS.x, randf() * BOUNDS.y)
	var layer: EntityLayer = EntityLayer.new()
	add_child_autofree(layer)
	layer.bind_entities(player, swarm, WeaponSystem.new(), CoinSystem.new())
	layer.set_model_scale(1.5)
	layer.set_ship_skin(progression.get_equipped_ship())
	layer.set_enemy_skin(progression.get_equipped_enemy_skin())
	PerfProbe.enabled = true
	PerfProbe.reset()
	var t: float = 0.0
	for f: int in range(FRAMES):
		t += 1.0 / 60.0
		layer.set_elapsed(t)
		layer.queue_redraw()
		await get_tree().process_frame
	var per_frame: float = PerfProbe.accumulated("d_entity") / float(FRAMES)
	print("BENCH entity _draw        %8.1f us/frame  (en=%d)" % [per_frame, swarm.enemies.size()])
	pass_test("bench")
