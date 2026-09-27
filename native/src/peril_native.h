#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
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
	// The EnemyType ordinals the native loop assumes, by name.
	static Dictionary enemy_type_ids();
};

} // namespace godot
