#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

// Native hot paths for the swarm tick (M11c). Static methods only.
class PerilNative : public RefCounted {
	GDCLASS(PerilNative, RefCounted)

protected:
	static void _bind_methods();

public:
	static String version();
};

} // namespace godot
