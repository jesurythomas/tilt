## bench_draw_types.gd — entity draw cost per enemy type (windowed; not in the suite).
## Run WITHOUT --headless: "$GODOT" --path godot -s addons/gut/gut_cmdln.gd -gtest=res://bench/bench_draw_types.gd -gexit
extends GutTest
const BOUNDS: Vector2 = Vector2(2162.0, 1056.0)


func _cost(kind: String) -> void:
	seed(7)
	var sw: EnemySwarm = EnemySwarm.new()
	sw.scale = 1.25
	var c: Vector2 = BOUNDS * 0.5
	for i: int in range(30):
		match kind:
			"seeker":
				sw.spawn_seeker(BOUNDS, randf() * BOUNDS.x, randf() * BOUNDS.y)
			"carrier":
				sw.spawn_carrier(BOUNDS, c)
			"artillery":
				sw.spawn_artillery(BOUNDS, c)
			"pulsar":
				sw.spawn_pulsar(BOUNDS, c)
			"specter":
				sw.spawn_specter(BOUNDS, c)
			"charger":
				var ch: Types.Enemy = sw.spawn_charger(BOUNDS, c)
				ch.state = Types.EnemyState.AIMING
	for e: Types.Enemy in sw.enemies:
		e.x = clampf(e.x, 40.0, BOUNDS.x - 40.0)
		e.y = clampf(e.y, 40.0, BOUNDS.y - 40.0)
	var layer: EntityLayer = EntityLayer.new()
	add_child_autofree(layer)
	layer.bind_entities(null, sw)
	layer.set_model_scale(1.5)
	layer.set_enemy_skin(ProgressionManager.new().get_equipped_enemy_skin())
	PerfProbe.enabled = true
	await get_tree().process_frame
	PerfProbe.reset()
	for f: int in range(60):
		layer.set_elapsed(f / 60.0)
		layer.queue_redraw()
		await get_tree().process_frame
	print(
		(
			"TYPE %-9s %6.1f us per enemy (n=%d)"
			% [kind, PerfProbe.accumulated("d_entity") / 60.0 / 30.0, sw.enemies.size()]
		)
	)
	layer.queue_free()


func test_x() -> void:
	for k: String in ["seeker", "carrier", "artillery", "pulsar", "specter", "charger"]:
		await _cost(k)
	pass_test("ok")
