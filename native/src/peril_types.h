#pragma once

#include <cstdint>

namespace godot {

// Types.EnemyType ordinals (types.gd); test_native_swarm pins them.
enum PerilEnemyType : int64_t {
	SEEKER,
	ARROW_DRONE,
	WALL_DOT,
	CIRCLE_DOT,
	TURRET_DOT,
	SPIKE_MINE,
	SNAKE_SEGMENT,
	CHARGER,
	ARTILLERY,
	CARRIER,
	BULLET,
	PULSAR,
	SPECTER,
};

} // namespace godot
