#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cstdint>
#include <unordered_map>

namespace godot {

// ParticleEngine.Shape (particle_engine.gd). PORT: web/src/tilt-to-live/ParticleEngine.ts:14
enum PerilParticleShape : int64_t {
	SHAPE_CIRCLE = 0,
	SHAPE_STREAK = 1,
	SHAPE_RING = 2,
	SHAPE_SHARD = 3,
};

// One particle. PORT: web/src/tilt-to-live/ParticleEngine.ts:5-17
// DIVERGENCE(M11c N7a): was the GDScript inner class ParticleEngine.Particle. It lives
// here so the flush and the draw loop read its fields directly, as PerilEnemy does for
// the swarm (N3a). Same fields and defaults; GDScript floats are 64-bit, so every float
// field is a double; `color` stays a (float32) Color.
class PerilParticle : public RefCounted {
	GDCLASS(PerilParticle, RefCounted)

protected:
	static void _bind_methods();

public:
	double x = 0.0;
	double y = 0.0;
	double vx = 0.0;
	double vy = 0.0;
	double life = 0.0;
	double max_life = 0.0;
	double size = 0.0;
	Color color = Color(1, 1, 1, 1);
	int64_t shape = SHAPE_CIRCLE;
	double decay = 0.0;
	double friction = 0.0;
	int64_t born = 0; // DIVERGENCE(M11c P25): the queued step count when it was emitted

#define PERIL_PARTICLE_ACCESSORS(m_type, m_name) \
	void set_##m_name(m_type p_value) { m_name = p_value; } \
	m_type get_##m_name() const { return m_name; }

	PERIL_PARTICLE_ACCESSORS(double, x)
	PERIL_PARTICLE_ACCESSORS(double, y)
	PERIL_PARTICLE_ACCESSORS(double, vx)
	PERIL_PARTICLE_ACCESSORS(double, vy)
	PERIL_PARTICLE_ACCESSORS(double, life)
	PERIL_PARTICLE_ACCESSORS(double, max_life)
	PERIL_PARTICLE_ACCESSORS(double, size)
	PERIL_PARTICLE_ACCESSORS(Color, color)
	PERIL_PARTICLE_ACCESSORS(int64_t, shape)
	PERIL_PARTICLE_ACCESSORS(double, decay)
	PERIL_PARTICLE_ACCESSORS(double, friction)
	PERIL_PARTICLE_ACCESSORS(int64_t, born)

#undef PERIL_PARTICLE_ACCESSORS
};

// EffectLayer._draw_particles' loop (M11c N7c). One per EffectLayer. The disc and ring
// textures come from the layer's own _particle_disc() / _particle_ring(key) on a miss
// (CircleSprites' shared textures), so they are the same textures.
class PerilParticleDrawer : public RefCounted {
	GDCLASS(PerilParticleDrawer, RefCounted)

protected:
	static void _bind_methods();

public:
	// Draws p_particles in array order on p_layer (an EffectLayer inside _draw, under
	// the standing arena transform p_arena_origin), with the same CanvasItem calls and
	// arguments as the GDScript loop.
	void draw(Object *p_layer, const Array &p_particles, const Vector2 &p_arena_origin);
	int64_t cached_count() const;

private:
	Ref<Texture2D> disc;
	std::unordered_map<int64_t, Ref<Texture2D>> rings;
};

} // namespace godot
