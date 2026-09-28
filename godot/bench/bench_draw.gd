## bench_draw.gd — windowed CPU benchmark of EntityLayer._draw (M11c Task 5; not in the suite).
## Run WITHOUT --headless (the dummy renderer skips canvas work):
##   "$GODOT" --path godot --render-thread safe -s addons/gut/gut_cmdln.gd -gtest=res://bench/bench_draw.gd -gexit
## --render-thread safe: with the project's Separate render thread (P24) desktop numbers
## read ~30-50% higher and noisier (2026-09-27); single-thread keeps them comparable.
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
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print(
		(
			"BENCH entity _draw        %8.1f us/frame  (en=%d, draws=%d)"
			% [per_frame, swarm.enemies.size(), draws]
		)
	)
	pass_test("bench")


func test_bench_entity_draw_mix() -> void:
	# A late Code Red frame: seekers, one wall, and the non-dot types (emulator run, 2026-09-27).
	seed(1234)
	var progression: ProgressionManager = ProgressionManager.new()
	var player: PlayerShip = PlayerShip.new(BOUNDS.x * 0.5, BOUNDS.y * 0.5)
	var centre: Vector2 = BOUNDS * 0.5
	var swarm: EnemySwarm = EnemySwarm.new()
	swarm.scale = 1.25
	for i: int in range(90):
		swarm.spawn_seeker(BOUNDS, randf() * BOUNDS.x, randf() * BOUNDS.y)
	swarm.spawn_wall_formation(BOUNDS)
	for i: int in range(4):
		swarm.spawn_carrier(BOUNDS, centre)
	for i: int in range(3):
		swarm.spawn_artillery(BOUNDS, centre)
		swarm.spawn_pulsar(BOUNDS, centre)
		swarm.spawn_specter(BOUNDS, centre)
		var c: PerilEnemy = swarm.spawn_charger(BOUNDS, centre)
		c.state = Types.EnemyState.AIMING
	for e: PerilEnemy in swarm.enemies:
		e.x = clampf(e.x, 20.0, BOUNDS.x - 20.0)
		e.y = clampf(e.y, 20.0, BOUNDS.y - 20.0)
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
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print(
		(
			"BENCH entity _draw mix    %8.1f us/frame  (en=%d, draws=%d)"
			% [per_frame, swarm.enemies.size(), draws]
		)
	)
	pass_test("bench")
