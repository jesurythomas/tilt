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
