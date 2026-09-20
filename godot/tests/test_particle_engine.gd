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
