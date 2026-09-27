#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
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
};

} // namespace godot
