// ParticleEngine.flush and EffectLayer._draw_particles over PerilParticle objects (M11c N7).
#include "peril_particle.h"
#include "peril_native.h"

#include <godot_cpp/classes/canvas_item.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cmath>

using namespace godot;

#define PERIL_PARTICLE_BIND(m_variant, m_name)                                                   \
	ClassDB::bind_method(D_METHOD("set_" #m_name, "value"), &PerilParticle::set_##m_name);     \
	ClassDB::bind_method(D_METHOD("get_" #m_name), &PerilParticle::get_##m_name);              \
	ADD_PROPERTY(PropertyInfo(Variant::m_variant, #m_name), "set_" #m_name, "get_" #m_name);

void PerilParticle::_bind_methods() {
	PERIL_PARTICLE_BIND(FLOAT, x)
	PERIL_PARTICLE_BIND(FLOAT, y)
	PERIL_PARTICLE_BIND(FLOAT, vx)
	PERIL_PARTICLE_BIND(FLOAT, vy)
	PERIL_PARTICLE_BIND(FLOAT, life)
	PERIL_PARTICLE_BIND(FLOAT, max_life)
	PERIL_PARTICLE_BIND(FLOAT, size)
	PERIL_PARTICLE_BIND(COLOR, color)
	PERIL_PARTICLE_BIND(INT, shape)
	PERIL_PARTICLE_BIND(FLOAT, decay)
	PERIL_PARTICLE_BIND(FLOAT, friction)
	PERIL_PARTICLE_BIND(INT, born)
}

// ParticleEngine.flush, line for line: the same closed form, the same float arithmetic
// (pow is the engine's, as GDScript's pow), survivors compacted in place oldest first
// and the dead appended to the pool in order.
void PerilNative::particles_flush(const Array &p_particles, const Array &p_pool, int64_t p_total, int64_t p_flushed,
		double p_dt) {
	Array particles = p_particles; // shares ParticleEngine's arrays (Arrays are references)
	Array pool = p_pool;
	const int64_t count = particles.size();
	int64_t kept = 0;
	for (int64_t i = 0; i < count; i++) {
		const Variant v = particles[i];
		PerilParticle *p = Object::cast_to<PerilParticle>(v);
		const int64_t n = p_total - (p->born > p_flushed ? p->born : p_flushed);
		if (n > 0) {
			const double f = p->friction;
			double sum = double(n);
			double fn = 1.0;
			if (f != 1.0) {
				fn = UtilityFunctions::pow(f, double(n));
				sum = n > 1 ? (1.0 - fn) / (1.0 - f) : 1.0;
			}
			p->x += p->vx * p_dt * sum;
			p->y += p->vy * p_dt * sum;
			p->vx *= fn;
			p->vy *= fn;
			p->life -= p_dt * double(n);

			if (p->shape == SHAPE_RING) {
				p->size += 220.0 * p_dt * double(n); // PORT: web/src/tilt-to-live/ParticleEngine.ts:37
			}
		}
		if (p->life <= 0.0) {
			pool.append(v);
		} else {
			particles[kept] = v;
			kept++;
		}
	}
	particles.resize(kept);
}

namespace {

constexpr int64_t MAX_PARTICLES = 400; // ParticleEngine.MAX_PARTICLES

// ParticleEngine's emit state: its live and pooled arrays (shared references) and the
// queued step count a new particle is born at.
struct Emitter {
	Array particles;
	Array pool;
	int64_t steps;

	bool full() const { return particles.size() >= MAX_PARTICLES; }

	// ParticleEngine._take.
	Ref<PerilParticle> take() {
		Ref<PerilParticle> p;
		if (pool.is_empty()) {
			p.instantiate();
		} else {
			p = pool.pop_back();
		}
		p->born = steps; // DIVERGENCE(M11c P25): it integrates from the next queued step
		return p;
	}

	void add(const Ref<PerilParticle> &p, double x, double y, double vx, double vy, double life, double size,
			const Color &color, int64_t shape, double friction) {
		p->x = x;
		p->y = y;
		p->vx = vx;
		p->vy = vy;
		p->life = life;
		p->max_life = life;
		p->size = size;
		p->color = color;
		p->shape = shape;
		p->decay = 1.0;
		p->friction = friction;
		particles.append(p);
	}
};

// GDScript's randf / sin / cos are the engine's; these are the same functions, so the
// global RNG advances identically and the trigonometry matches bit for bit.
inline double rf() {
	return UtilityFunctions::randf();
}

// The emitters' colour literals, parsed as GDScript's Color("#...") parses them.
const Color &ice_blue() {
	static const Color c = Color::html("#88eeff");
	return c;
}
const Color &snow_blue() {
	static const Color c = Color::html("#c8f2ff");
	return c;
}
const Color &kinetic_blue() {
	static const Color c = Color::html("#b8f0ff");
	return c;
}
const Color &white() {
	static const Color c = Color::html("#ffffff");
	return c;
}

// CircleSprites' constants and helpers (circle_sprites.gd), same arithmetic.
constexpr double TEX_SIZE = 64.0;
constexpr double RATIO_STEP = 0.02;
constexpr double MAX_RATIO = 2.0;
constexpr double AA = 2.0 / TEX_SIZE;
constexpr double DISC_EDGE = 1.0 - AA * 1.5;

// GDScript's maxf / clampf (core/typedefs.h MAX / CLAMP), NaN order included.
inline double maxf(double a, double b) {
	return a > b ? a : b;
}
inline double clampf(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}

inline int64_t ring_key(double radius, double width) {
	const double ratio = clampf(width / maxf(radius, 0.001), RATIO_STEP, MAX_RATIO);
	return int64_t(std::round(ratio / RATIO_STEP));
}

inline double ring_centre(int64_t key) {
	const double ratio = double(key) * RATIO_STEP;
	return (1.0 - AA * 2.0) / (1.0 + ratio * 0.5);
}

inline bool ring_is_faithful(double radius, double width) {
	if (radius <= 0.0 || width / radius < RATIO_STEP) {
		return false;
	}
	const int64_t key = ring_key(radius, width);
	const double texel_px = (radius / ring_centre(key)) / (TEX_SIZE * 0.5);
	return texel_px <= 1.0;
}

// Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0), float32 as in GDScript.
inline Rect2 centred_rect(const Vector2 &p_centre, double p_half) {
	const Vector2 h(p_half, p_half);
	return Rect2(p_centre - h, h * 2.0);
}

} // namespace

// ParticleEngine's emitters, line for line: the same randf() calls in the same order,
// the same arithmetic. PORT: web/src/tilt-to-live/ParticleEngine.ts:46-197

void PerilNative::particles_emit_sparks(const Array &p_particles, const Array &p_pool, int64_t p_steps, double p_x,
		double p_y, int64_t p_count, const Color &p_color, double p_speed_max) {
	Emitter em{ p_particles, p_pool, p_steps };
	for (int64_t i = 0; i < p_count; i++) {
		if (em.full()) {
			break;
		}
		const double angle = rf() * Math::PI * 2.0;
		const double speed = 20.0 + rf() * p_speed_max; // PORT: web/src/tilt-to-live/ParticleEngine.ts:50
		const double life = 0.3 + rf() * 0.45; // PORT: web/src/tilt-to-live/ParticleEngine.ts:51
		const Ref<PerilParticle> p = em.take();
		const double vx = UtilityFunctions::cos(angle) * speed;
		const double vy = UtilityFunctions::sin(angle) * speed;
		const double size = 2.0 + rf() * 2.5; // PORT: web/src/tilt-to-live/ParticleEngine.ts:60
		const int64_t shape = rf() < 0.4 ? SHAPE_STREAK : SHAPE_CIRCLE; // PORT: web/src/tilt-to-live/ParticleEngine.ts:62
		em.add(p, p_x, p_y, vx, vy, life, size, p_color, shape, 0.94); // PORT: web/src/tilt-to-live/ParticleEngine.ts:64
	}
}

void PerilNative::particles_emit_explosion(const Array &p_particles, const Array &p_pool, int64_t p_steps, double p_x,
		double p_y, const Color &p_color, int64_t p_count) {
	particles_emit_sparks(p_particles, p_pool, p_steps, p_x, p_y, p_count, p_color, 300.0); // PORT: :70
	// Add expanding shockwave ring. PORT: web/src/tilt-to-live/ParticleEngine.ts:72-87
	Emitter em{ p_particles, p_pool, p_steps };
	if (!em.full()) {
		const Ref<PerilParticle> p = em.take();
		em.add(p, p_x, p_y, 0.0, 0.0, 0.35, 8.0, p_color, SHAPE_RING, 1.0); // PORT: :79-83
	}
}

void PerilNative::particles_emit_smoke(const Array &p_particles, const Array &p_pool, int64_t p_steps, double p_x,
		double p_y, const Color &p_color) {
	Emitter em{ p_particles, p_pool, p_steps };
	if (em.full()) {
		return;
	}
	const double angle = rf() * Math::PI * 2.0;
	const double speed = 10.0 + rf() * 30.0; // PORT: web/src/tilt-to-live/ParticleEngine.ts:93
	const double life = 0.4 + rf() * 0.3; // PORT: web/src/tilt-to-live/ParticleEngine.ts:94
	const Ref<PerilParticle> p = em.take();
	const double vx = UtilityFunctions::cos(angle) * speed;
	const double vy = UtilityFunctions::sin(angle) * speed;
	const double size = 3.0 + rf() * 3.0; // PORT: web/src/tilt-to-live/ParticleEngine.ts:103
	em.add(p, p_x, p_y, vx, vy, life, size, p_color, SHAPE_CIRCLE, 0.92); // PORT: :105-107
}

void PerilNative::particles_emit_ice_shatter(const Array &p_particles, const Array &p_pool, int64_t p_steps,
		double p_x, double p_y, int64_t p_count) {
	Emitter em{ p_particles, p_pool, p_steps };
	for (int64_t i = 0; i < p_count; i++) {
		if (em.full()) {
			break;
		}
		const double angle = rf() * Math::PI * 2.0;
		const double speed = 60.0 + rf() * 220.0; // PORT: web/src/tilt-to-live/ParticleEngine.ts:115
		const double life = 0.4 + rf() * 0.4; // PORT: web/src/tilt-to-live/ParticleEngine.ts:116
		const Ref<PerilParticle> p = em.take();
		const double vx = UtilityFunctions::cos(angle) * speed;
		const double vy = UtilityFunctions::sin(angle) * speed;
		const double size = 3.0 + rf() * 4.0; // PORT: web/src/tilt-to-live/ParticleEngine.ts:125
		const Color &color = rf() < 0.6 ? ice_blue() : white(); // PORT: web/src/tilt-to-live/ParticleEngine.ts:126
		em.add(p, p_x, p_y, vx, vy, life, size, color, SHAPE_SHARD, 0.95); // PORT: :127-129
	}
}

void PerilNative::particles_emit_blizzard_snow(const Array &p_particles, const Array &p_pool, int64_t p_steps,
		const Vector2 &p_bounds, int64_t p_count) {
	Emitter em{ p_particles, p_pool, p_steps };
	for (int64_t i = 0; i < p_count; i++) {
		if (em.full()) {
			break;
		}
		const double x = rf() * double(p_bounds.x); // PORT: web/src/tilt-to-live/ParticleEngine.ts:137
		const double y = -10.0; // PORT: web/src/tilt-to-live/ParticleEngine.ts:138
		const double life = 3.5 + rf() * 2.0; // PORT: web/src/tilt-to-live/ParticleEngine.ts:139
		const Ref<PerilParticle> p = em.take();
		// PORT: web/src/tilt-to-live/ParticleEngine.ts:143-144
		const double vx = (rf() * 50.0 - 25.0) - 15.0;
		const double vy = 45.0 + rf() * 55.0;
		const double size = 1.5 + rf() * 2.2; // PORT: web/src/tilt-to-live/ParticleEngine.ts:147
		const Color &color = rf() < 0.6 ? snow_blue() : white(); // PORT: web/src/tilt-to-live/ParticleEngine.ts:148
		em.add(p, x, y, vx, vy, life, size, color, SHAPE_CIRCLE, 0.99); // PORT: :149-151
	}
}

void PerilNative::particles_emit_kinetic_ice_shards(const Array &p_particles, const Array &p_pool, int64_t p_steps,
		double p_x, double p_y, int64_t p_count) {
	Emitter em{ p_particles, p_pool, p_steps };
	for (int64_t i = 0; i < p_count; i++) {
		if (em.full()) {
			break;
		}
		// PORT: web/src/tilt-to-live/ParticleEngine.ts:159-161
		const double angle = (double(i) * Math::PI * 2.0) / double(p_count) + (rf() * 0.2 - 0.1);
		const double speed = 340.0 + rf() * 100.0;
		const double life = 0.45 + rf() * 0.25;
		const Ref<PerilParticle> p = em.take();
		const double vx = UtilityFunctions::cos(angle) * speed;
		const double vy = UtilityFunctions::sin(angle) * speed;
		const double size = 3.5 + rf() * 2.5; // PORT: web/src/tilt-to-live/ParticleEngine.ts:169
		em.add(p, p_x, p_y, vx, vy, life, size, kinetic_blue(), SHAPE_SHARD, 0.96); // PORT: :170-173
	}
}

void PerilNative::particles_emit_thruster_sparks(const Array &p_particles, const Array &p_pool, int64_t p_steps,
		double p_x, double p_y, double p_angle, const Color &p_color) {
	Emitter em{ p_particles, p_pool, p_steps };
	if (em.full()) {
		return;
	}
	const double spread = (rf() - 0.5) * 0.6; // PORT: web/src/tilt-to-live/ParticleEngine.ts:180
	const double final_angle = p_angle + spread;
	const double speed = 70.0 + rf() * 120.0; // PORT: web/src/tilt-to-live/ParticleEngine.ts:182
	const double life = 0.2 + rf() * 0.2; // PORT: web/src/tilt-to-live/ParticleEngine.ts:183
	const Ref<PerilParticle> p = em.take();
	const double vx = UtilityFunctions::cos(final_angle) * speed;
	const double vy = UtilityFunctions::sin(final_angle) * speed;
	const double size = 2.0 + rf() * 2.0; // PORT: web/src/tilt-to-live/ParticleEngine.ts:191
	em.add(p, p_x, p_y, vx, vy, life, size, p_color, SHAPE_STREAK, 0.92); // PORT: :193-195
}

void PerilParticleDrawer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("draw", "layer", "particles", "arena_origin"), &PerilParticleDrawer::draw);
	ClassDB::bind_method(D_METHOD("cached_count"), &PerilParticleDrawer::cached_count);
}

int64_t PerilParticleDrawer::cached_count() const {
	return int64_t(rings.size()) + (disc.is_valid() ? 1 : 0);
}

// EffectLayer._draw_particles, line for line, with CircleSprites.draw_ring / draw_disc
// inline.
void PerilParticleDrawer::draw(Object *p_layer, const Array &p_particles, const Vector2 &p_arena_origin) {
	static const StringName sn_disc("_particle_disc");
	static const StringName sn_ring("_particle_ring");

	CanvasItem *ci = Object::cast_to<CanvasItem>(p_layer);
	ERR_FAIL_NULL(ci);
	const int64_t n = p_particles.size();
	for (int64_t i = 0; i < n; i++) {
		const Variant v = p_particles[i];
		const PerilParticle *p = Object::cast_to<PerilParticle>(v);
		const double alpha = maxf(0.0, p->life / p->max_life);
		Color col = p->color;
		col.a = float(double(col.a) * alpha);

		switch (p->shape) {
			case SHAPE_RING: {
				const double ring_width = maxf(1.0, 2.5 * alpha);
				if (ring_is_faithful(p->size, ring_width)) {
					// DIVERGENCE(M11c P5): a shared ring texture replaces the arc.
					const int64_t key = ring_key(p->size, ring_width);
					auto it = rings.find(key);
					if (it == rings.end()) {
						it = rings.emplace(key, Ref<Texture2D>(p_layer->call(sn_ring, key))).first;
					}
					const Rect2 r = centred_rect(Vector2(p->x, p->y), p->size / ring_centre(key));
					ci->draw_texture_rect(it->second, r, false, col);
				} else {
					// Large thin rings blur as textures (final review), so they keep the arc.
					ci->draw_arc(Vector2(p->x, p->y), p->size, 0.0, Math::TAU, 16, col, ring_width);
				}
				break;
			}
			case SHAPE_STREAK: {
				// PORT: web/src/tilt-to-live/ParticleEngine.ts:213-218
				const Vector2 p_to(p->x - p->vx * 0.04, p->y - p->vy * 0.04);
				ci->draw_line(Vector2(p->x, p->y), p_to, col, maxf(1.0, p->size));
				break;
			}
			case SHAPE_SHARD: {
				// PORT: web/src/tilt-to-live/ParticleEngine.ts:220-225
				ci->draw_set_transform(p_arena_origin + Vector2(p->x, p->y), p->life * 10.0, Vector2(1, 1));
				ci->draw_rect(Rect2(-p->size * 0.5, -p->size * 0.5, p->size, p->size), col);
				ci->draw_set_transform(p_arena_origin, 0.0, Vector2(1, 1));
				break;
			}
			default: {
				// SHAPE_CIRCLE and default. PORT: web/src/tilt-to-live/ParticleEngine.ts:227-230
				if (disc.is_null()) {
					disc = p_layer->call(sn_disc);
				}
				ci->draw_texture_rect(disc, centred_rect(Vector2(p->x, p->y), maxf(0.5, p->size) / DISC_EDGE), false, col);
				break;
			}
		}
	}
}
