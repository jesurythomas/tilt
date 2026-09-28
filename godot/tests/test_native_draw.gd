## test_native_draw.gd
## M11c N4: EntityLayer's enemy loop in C++ (PerilEnemyDrawer) calls the same per-type
## drawers in the same order as the GDScript loop (EntityLayer.use_native_draw = false),
## builds the same satellite map and fills the layer's own sprite caches. The pixels
## themselves are checked windowed by bench/pixel_native_draw.gd (the headless renderer
## draws nothing).
extends GutTest

const BOUNDS: Vector2 = Vector2(1280.0, 720.0)


## Logs every non-dot drawer call as "<method>:<id>" and draws nothing for it.
class LoggingLayer:
	extends EntityLayer
	var log: PackedStringArray = PackedStringArray()
	var draws: int = 0

	func _draw() -> void:
		super()
		draws += 1

	func _draw_charger(e: PerilEnemy) -> void:
		log.append("charger:%d" % e.id)

	func _draw_artillery(e: PerilEnemy) -> void:
		log.append("artillery:%d" % e.id)

	func _draw_bullet(e: PerilEnemy) -> void:
		log.append("bullet:%d" % e.id)

	func _draw_carrier(e: PerilEnemy) -> void:
		log.append("carrier:%d" % e.id)

	func _draw_satellite(e: PerilEnemy) -> void:
		log.append("satellite:%d" % e.id)

	func _draw_pulsar(e: PerilEnemy) -> void:
		log.append("pulsar:%d" % e.id)

	func _draw_specter(e: PerilEnemy) -> void:
		log.append("specter:%d" % e.id)


func after_each() -> void:
	EntityLayer.use_native_draw = true


func _swarm() -> EnemySwarm:
	seed(5)
	var sw: EnemySwarm = EnemySwarm.new()
	var c: Vector2 = BOUNDS * 0.5
	for i: int in range(3):
		sw.spawn_seeker(BOUNDS, 100.0 + 50.0 * i, 200.0)
		sw.spawn_carrier(BOUNDS, c)
		sw.spawn_charger(BOUNDS, c)
		sw.spawn_artillery(BOUNDS, c)
		sw.spawn_pulsar(BOUNDS, c)
		sw.spawn_specter(BOUNDS, c)
		sw.spawn_bullet(c.x, c.y, c + Vector2(10.0, 0.0))
		sw.spawn_turret(BOUNDS)
	# A frozen charger draws as a frozen dot, a frozen satellite too.
	for e: PerilEnemy in sw.enemies:
		if e.type == Types.EnemyType.CHARGER:
			e.frozen = true
			break
	for e: PerilEnemy in sw.enemies:
		if e.parent_carrier_id != Types.ABSENT:
			e.frozen = true
			break
	return sw


func _layer(native: bool, swarm: EnemySwarm) -> LoggingLayer:
	EntityLayer.use_native_draw = native
	var layer: LoggingLayer = LoggingLayer.new()
	add_child_autofree(layer)
	layer.bind_entities(null, swarm, null, null)
	layer.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	return layer


func _sats(layer: EntityLayer) -> Dictionary:
	var out: Dictionary = {}
	for id: int in layer._frame_sats:
		var ids: PackedInt32Array = PackedInt32Array()
		for s: PerilEnemy in layer._frame_sats[id]:
			ids.append(s.id)
		out[id] = ids
	return out


func test_the_native_loop_calls_the_same_drawers_in_the_same_order() -> void:
	var ref: LoggingLayer = await _layer(false, _swarm())
	var nat: LoggingLayer = await _layer(true, _swarm())
	assert_gt(ref.draws, 0, "_draw ran")
	assert_gt(ref.log.size(), 20, "the reference drew the non-dot types")
	assert_eq(nat.log, ref.log)
	assert_false(ref.log.has("charger:%d" % _first_id(ref, Types.EnemyType.CHARGER)), "frozen wins")


func test_the_native_loop_builds_the_same_satellite_map() -> void:
	var ref: LoggingLayer = await _layer(false, _swarm())
	var nat: LoggingLayer = await _layer(true, _swarm())
	assert_eq(ref._frame_sats.size(), 3, "three carriers with satellites")
	assert_eq(_sats(nat), _sats(ref))


func test_the_native_loop_fills_the_layers_sprite_caches() -> void:
	var ref: LoggingLayer = await _layer(false, _swarm())
	var nat: LoggingLayer = await _layer(true, _swarm())
	assert_gt(ref._dot_cache.size(), 0)
	assert_eq(nat._dot_cache.keys(), ref._dot_cache.keys())
	assert_eq(nat._frozen_cache.keys(), ref._frozen_cache.keys())
	assert_eq(nat._native_drawer.cached_count(), nat._dot_cache.size() + nat._frozen_cache.size())


func test_a_model_scale_change_clears_the_native_caches() -> void:
	var nat: LoggingLayer = await _layer(true, _swarm())
	assert_gt(nat._native_drawer.cached_count(), 0)
	nat.set_model_scale(1.5)
	assert_eq(nat._native_drawer.cached_count(), 0)
	nat.queue_redraw()
	await get_tree().process_frame
	assert_eq(nat._native_drawer.cached_count(), nat._dot_cache.size() + nat._frozen_cache.size())


func _first_id(layer: EntityLayer, type: Types.EnemyType) -> int:
	for e: PerilEnemy in layer._swarm.enemies:
		if e.type == type:
			return e.id
	return -1
