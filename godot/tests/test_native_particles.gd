## test_native_particles.gd
## M11c N7: particles in C++. PerilNative.particles_flush must leave every particle and
## the pool exactly as ParticleEngine's GDScript flush does (ParticleEngine.use_native =
## false), and PerilParticleDrawer must ask the layer for the same ring textures the
## GDScript loop draws. The pixels are checked windowed by bench/pixel_native_particles.gd
## (the headless renderer draws nothing).
extends GutTest

const BOUNDS: Vector2 = Vector2(1280.0, 720.0)
const DT: float = 1.0 / 120.0


## Logs the textures PerilParticleDrawer asks for.
class LoggingEffectLayer:
	extends EffectLayer
	var ring_keys: Array[int] = []
	var discs: int = 0
	var draws: int = 0

	func _draw() -> void:
		super()
		draws += 1

	func _particle_disc() -> Texture2D:
		discs += 1
		return super()

	func _particle_ring(key: int) -> Texture2D:
		ring_keys.append(key)
		return super(key)


func after_each() -> void:
	ParticleEngine.use_native = true
	EffectLayer.use_native_draw = true


## Every emitter, at several points and batch lengths, with emits between queued steps
## (particles born mid-batch) and flushes that retire some. Returns every particle's
## fields, the pool's, and the RNG afterwards, as bytes.
func _run(native: bool) -> PackedByteArray:
	ParticleEngine.use_native = native
	seed(77)
	var pe: ParticleEngine = ParticleEngine.new()
	var rows: Array = []
	for r: int in range(40):
		var x: float = randf() * BOUNDS.x
		var y: float = randf() * BOUNDS.y
		match r % 7:
			0:
				pe.emit_explosion(x, y, Color(1.0, 0.3, 0.2), 24)
			1:
				pe.emit_sparks(x, y, 9, Color.CYAN, 120.0 + randf() * 200.0)
			2:
				pe.emit_ice_shatter(x, y, 10)
			3:
				pe.emit_blizzard_snow(BOUNDS, 3)
			4:
				pe.emit_kinetic_ice_shards(x, y, 8)
			5:
				pe.emit_thruster_sparks(x, y, randf() * TAU)
			6:
				pe.emit_smoke(x, y)
		for s: int in range(1 + r % 8):
			pe.step(DT)
			if s == 2:
				pe.emit_sparks(x, y, 4, Color.YELLOW)
		pe.flush()
		rows.append(_fields(pe.particles))
		rows.append(pe.pooled_count())
	pe.reset()
	rows.append(_fields(pe._pool))
	rows.append(randi())
	return var_to_bytes(rows)


func _fields(list: Array[PerilParticle]) -> Array:
	var out: Array = []
	for p: PerilParticle in list:
		out.append(
			[p.x, p.y, p.vx, p.vy, p.life, p.max_life, p.size, p.color, p.shape, p.friction, p.born]
		)
	return out


func test_native_flush_matches_the_gdscript_flush_bit_for_bit() -> void:
	var gd: PackedByteArray = _run(false)
	var cpp: PackedByteArray = _run(true)
	assert_gt(gd.size(), 20000, "the run produced particles")
	assert_eq(cpp, gd, "every particle, the pool and the RNG are identical")


func test_native_flush_retires_to_the_pool_in_order() -> void:
	var pe: ParticleEngine = ParticleEngine.new()
	for i: int in range(6):
		pe.emit_smoke(float(i), 0.0)
	var dying: Array[PerilParticle] = [pe.particles[1], pe.particles[4]]
	pe.particles[1].life = 0.001
	pe.particles[4].life = 0.001
	pe.update(0.01)
	assert_eq(pe.particles.size(), 4)
	assert_eq(pe.pooled_count(), 2)
	assert_same(pe._pool[0], dying[0], "retired oldest first")
	assert_same(pe._pool[1], dying[1])


func _layer_with_particles() -> LoggingEffectLayer:
	seed(3)
	var pe: ParticleEngine = ParticleEngine.new()
	# One old ring (too large and thin for a texture: the draw_arc path) ...
	pe.emit_explosion(640.0, 600.0, Color.RED, 4)
	for s: int in range(20):
		pe.step(DT)
	pe.flush()
	# ... then rings of six ages (six ring keys), shards and streaks.
	for i: int in range(6):
		pe.emit_explosion(100.0 + 150.0 * i, 300.0, Color.RED, 6)
		pe.emit_ice_shatter(100.0 + 150.0 * i, 500.0, 3)
		pe.emit_thruster_sparks(100.0 + 150.0 * i, 100.0, 0.5)
		pe.step(DT)
		pe.step(DT)
		pe.flush()
	var layer: LoggingEffectLayer = LoggingEffectLayer.new()
	layer.bind(pe, null, null)
	add_child_autofree(layer)
	return layer


## The ring keys the GDScript loop would draw textures for (its faithful rings), in order.
func _expected_ring_keys(pe: ParticleEngine) -> Array[int]:
	var keys: Array[int] = []
	for p: PerilParticle in pe.particles:
		if p.shape != ParticleEngine.Shape.RING:
			continue
		var width: float = maxf(1.0, 2.5 * maxf(0.0, p.life / p.max_life))
		if CircleSprites.ring_is_faithful(p.size, width):
			var key: int = CircleSprites.ring_key(p.size, width)
			if not keys.has(key):
				keys.append(key)
	return keys


func test_native_drawer_asks_for_the_same_ring_textures_once_each() -> void:
	var layer: LoggingEffectLayer = _layer_with_particles()
	var expected: Array[int] = _expected_ring_keys(layer._particles)
	assert_gt(expected.size(), 1, "several ring sizes on screen")
	var unfaithful: int = 0
	for p: PerilParticle in layer._particles.particles:
		if p.shape == ParticleEngine.Shape.RING and not CircleSprites.ring_is_faithful(p.size, 1.0):
			unfaithful += 1
	assert_gt(unfaithful, 0, "one ring takes the draw_arc path")
	layer.queue_redraw()
	await get_tree().process_frame
	layer.queue_redraw()
	await get_tree().process_frame
	assert_eq(layer.draws, 2, "drawn twice")
	assert_eq(layer.ring_keys, expected, "each faithful ring key, asked once, in draw order")
	assert_eq(layer.discs, 1, "the disc texture, asked once")
