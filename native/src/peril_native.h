#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

// Native hot paths for the swarm tick (M11c). Static methods only.
class PerilNative : public RefCounted {
	GDCLASS(PerilNative, RefCounted)

protected:
	static void _bind_methods();

public:
	static String version();
	// EnemySwarm._separate_sweep, ported line for line (same pair order and float
	// arithmetic). Returns xs then ys (2n values); the inputs are not modified.
	static PackedFloat64Array separate(const PackedFloat64Array &p_xs, const PackedFloat64Array &p_ys, double p_min_distance);
	// VectorGrid.update, ported line for line (same float arithmetic). Returns
	// [px, py, vx, vy, active, is_active, max_displacement]; the inputs are not modified.
	static Array grid_step(const PackedFloat64Array &p_px, const PackedFloat64Array &p_py,
			const PackedFloat64Array &p_ox, const PackedFloat64Array &p_oy,
			const PackedFloat64Array &p_vx, const PackedFloat64Array &p_vy,
			const PackedInt32Array &p_active, const PackedByteArray &p_is_active,
			double p_stiffness, double p_damping, double p_settle_eps);
	// VectorGrid.apply_explosion's windowed scan, ported line for line. Returns
	// [vx, vy, active, is_active, touched]; the inputs are not modified.
	static Array grid_explode(const PackedFloat64Array &p_px, const PackedFloat64Array &p_py,
			const PackedFloat64Array &p_vx, const PackedFloat64Array &p_vy,
			const PackedInt32Array &p_active, const PackedByteArray &p_is_active,
			int64_t p_c0, int64_t p_c1, int64_t p_r0, int64_t p_r1, int64_t p_cols,
			double p_cx, double p_cy, double p_force, double p_radius);
	// EnemySwarm.update's per-enemy loop (step 3) on the live enemies array, bit for
	// bit (peril_swarm.cpp); charger/artillery/pulsar/snake call back into the swarm's
	// update_* (randf, particles, bullets). Per-tick constants come from the caller.
	static void swarm_step(Object *p_swarm, const Array &p_enemies, Object *p_particles,
			const Vector2 &p_player_pos, const Vector2 &p_bounds, double p_dt, double p_speed_scale,
			double p_seeker_speed, double p_seeker_steer, double p_circle_speed, double p_specter_speed);
	// EnemySwarm.apply_flocking_separation over the enemies, bit for bit.
	static void separate_enemies(const Array &p_enemies, double p_min_distance, int64_t p_sweep_min);
	// RunController.check_collisions' x reject: indices p_start..0 (descending) that
	// can touch or near-miss the player.
	static PackedInt32Array collision_candidates(const Array &p_enemies, double p_plx, double p_plr, int64_t p_start);
	// ParticleEngine.flush on its live particles and pool arrays (peril_particle.cpp),
	// bit for bit: integrates the steps queued since p_flushed (up to p_total) and
	// retires the dead to the pool.
	static void particles_flush(const Array &p_particles, const Array &p_pool, int64_t p_total, int64_t p_flushed,
			double p_dt);
	// ParticleEngine's emitters on its live particles and pool arrays, bit for bit
	// (peril_particle.cpp): the same randf() calls in the same order. p_steps is the
	// engine's queued step count (a new particle's `born`).
	static void particles_emit_sparks(const Array &p_particles, const Array &p_pool, int64_t p_steps, double p_x,
			double p_y, int64_t p_count, const Color &p_color, double p_speed_max);
	static void particles_emit_explosion(const Array &p_particles, const Array &p_pool, int64_t p_steps, double p_x,
			double p_y, const Color &p_color, int64_t p_count);
	static void particles_emit_smoke(const Array &p_particles, const Array &p_pool, int64_t p_steps, double p_x,
			double p_y, const Color &p_color);
	static void particles_emit_ice_shatter(const Array &p_particles, const Array &p_pool, int64_t p_steps, double p_x,
			double p_y, int64_t p_count);
	static void particles_emit_blizzard_snow(const Array &p_particles, const Array &p_pool, int64_t p_steps,
			const Vector2 &p_bounds, int64_t p_count);
	static void particles_emit_kinetic_ice_shards(const Array &p_particles, const Array &p_pool, int64_t p_steps,
			double p_x, double p_y, int64_t p_count);
	static void particles_emit_thruster_sparks(const Array &p_particles, const Array &p_pool, int64_t p_steps,
			double p_x, double p_y, double p_angle, const Color &p_color);
	// WeaponSystem._missile_snapshot over the live enemies (M11c P35), bit for bit: returns
	// [xs, ys, radii, order, sorted_q, max_radius, index (id -> slot), enemies (a copy)].
	static Array missile_snapshot(const Array &p_enemies, double p_quant, double p_offset, int64_t p_bits);
	// The EnemyType ordinals the native loop assumes, by name.
	static Dictionary enemy_type_ids();
};

} // namespace godot
