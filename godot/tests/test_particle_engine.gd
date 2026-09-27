## test_particle_engine.gd
## PORTS: nothing — new file, covers src/sim/particle_engine.gd
extends GutTest
## Covers the pool cap, the integration step and spark emission.


func test_emit_sparks_appends_the_requested_count() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_sparks(10.0, 20.0, 5, Color("#00ddff"))
	assert_eq(engine.particles.size(), 5, "one particle per requested spark")
	assert_almost_eq(engine.particles[0].x, 10.0, 0.0001, "spawns at the requested point")


func test_emit_sparks_respects_the_pool_cap() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_sparks(0.0, 0.0, ParticleEngine.MAX_PARTICLES + 50, Color.WHITE)
	assert_eq(
		engine.particles.size(),
		ParticleEngine.MAX_PARTICLES,
		"the pool never exceeds maxParticles — ParticleEngine.ts:48"
	)


func test_update_moves_particles_and_retires_dead_ones() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_sparks(0.0, 0.0, 3, Color.WHITE)
	engine.update(0.05)
	assert_eq(engine.particles.size(), 3, "live particles survive a short step")
	engine.update(5.0)
	assert_eq(engine.particles.size(), 0, "particles past their life are removed")


func test_reset_empties_the_pool() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_sparks(0.0, 0.0, 4, Color.WHITE)
	engine.reset()
	assert_eq(engine.particles.size(), 0, "reset clears every particle")


func test_emit_explosion_spawns_sparks_and_shockwave_ring() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_explosion(50.0, 50.0, Color("#ff3344"), 10)
	assert_eq(engine.particles.size(), 11, "10 sparks plus 1 expanding ring")
	var ring: ParticleEngine.Particle = engine.particles[10]
	assert_eq(ring.shape, ParticleEngine.Shape.RING, "last particle is shockwave ring")
	assert_almost_eq(ring.size, 8.0, 0.001, "initial ring size is 8.0")


func test_emit_smoke_spawns_circle_particle() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_smoke(20.0, 30.0)
	assert_eq(engine.particles.size(), 1, "smoke particle appended")
	assert_eq(engine.particles[0].shape, ParticleEngine.Shape.CIRCLE, "smoke is CIRCLE shape")


func test_emit_ice_shatter_spawns_shards() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_ice_shatter(15.0, 25.0, 6)
	assert_eq(engine.particles.size(), 6, "6 ice shards emitted")
	for p: ParticleEngine.Particle in engine.particles:
		assert_eq(p.shape, ParticleEngine.Shape.SHARD, "ice shatter is SHARD shape")


func test_emit_blizzard_snow_and_kinetic_shards() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_blizzard_snow(Vector2(500.0, 300.0), 3)
	assert_eq(engine.particles.size(), 3, "3 snow particles emitted")
	engine.emit_kinetic_ice_shards(100.0, 100.0, 4)
	assert_eq(engine.particles.size(), 7, "4 kinetic shards appended")


func test_emit_thruster_sparks_spawns_streak() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_thruster_sparks(10.0, 10.0, 0.0)
	assert_eq(engine.particles.size(), 1, "thruster spark emitted")
	assert_eq(engine.particles[0].shape, ParticleEngine.Shape.STREAK, "thruster is STREAK shape")


func test_retired_particles_are_reused_by_the_next_emit() -> void:
	# DIVERGENCE(M11c P12): pooled particles — no allocation per spark after warm-up.
	var pe: ParticleEngine = ParticleEngine.new()
	pe.emit_sparks(0.0, 0.0, 5, Color.RED)
	var retired: Array[ParticleEngine.Particle] = pe.particles.duplicate()
	pe.update(10.0)
	assert_eq(pe.particles.size(), 0, "everything retired")
	assert_eq(pe.pooled_count(), 5, "retired particles wait in the pool")
	pe.emit_sparks(0.0, 0.0, 1, Color.BLUE)
	assert_eq(pe.pooled_count(), 4, "the emit took one back out")
	assert_true(retired.has(pe.particles[0]), "the same object, reused")
	assert_eq(pe.particles[0].color, Color.BLUE, "fully re-initialised")
	assert_gt(pe.particles[0].life, 0.0)


func test_update_keeps_survivors_oldest_first() -> void:
	var pe: ParticleEngine = ParticleEngine.new()
	for i: int in range(6):
		pe.emit_smoke(float(i), 0.0)
	pe.particles[1].life = 0.001
	pe.particles[4].life = 0.001
	var survivors: Array[ParticleEngine.Particle] = [
		pe.particles[0], pe.particles[2], pe.particles[3], pe.particles[5]
	]
	pe.update(0.01)
	assert_eq(pe.particles.size(), survivors.size())
	for k: int in range(survivors.size()):
		assert_same(pe.particles[k], survivors[k], "same objects, same order (%d)" % k)


func _twin_emit(a: ParticleEngine, b: ParticleEngine) -> void:
	seed(21)
	a.emit_sparks(100.0, 50.0, 12, Color.RED, 180.0)
	seed(21)
	b.emit_sparks(100.0, 50.0, 12, Color.RED, 180.0)


func _assert_same_state(a: ParticleEngine, b: ParticleEngine, label: String) -> void:
	assert_eq(a.particles.size(), b.particles.size(), label + " count")
	for i: int in range(mini(a.particles.size(), b.particles.size())):
		var p: ParticleEngine.Particle = a.particles[i]
		var q: ParticleEngine.Particle = b.particles[i]
		assert_almost_eq(p.x, q.x, 1e-9, label + " x")
		assert_almost_eq(p.y, q.y, 1e-9, label + " y")
		assert_almost_eq(p.vx, q.vx, 1e-9, label + " vx")
		assert_almost_eq(p.life, q.life, 1e-9, label + " life")


func test_queued_steps_flush_like_single_steps() -> void:
	# M11c P25: n queued steps integrated at once match n update() calls.
	var dt: float = 1.0 / 120.0
	var a: ParticleEngine = ParticleEngine.new()
	var b: ParticleEngine = ParticleEngine.new()
	_twin_emit(a, b)
	for i: int in range(5):
		a.update(dt)
		b.step(dt)
	b.flush()
	_assert_same_state(a, b, "after 5")


func test_a_particle_emitted_mid_batch_integrates_only_later_steps() -> void:
	var dt: float = 1.0 / 120.0
	var a: ParticleEngine = ParticleEngine.new()
	var b: ParticleEngine = ParticleEngine.new()
	a.update(dt)
	a.update(dt)
	b.step(dt)
	b.step(dt)
	_twin_emit(a, b)
	for i: int in range(3):
		a.update(dt)
		b.step(dt)
	b.flush()
	_assert_same_state(a, b, "born after 2 of 5")
