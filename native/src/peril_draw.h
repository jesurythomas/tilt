#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cstdint>
#include <unordered_map>

namespace godot {

// EntityLayer._draw_enemies' loop (M11c N4). One per EntityLayer: it keeps its own
// copy of the layer's default-dot and frozen-dot sprite caches (filled from the
// layer's, so the same textures), which the layer clears with clear() whenever it
// clears its own.
class PerilEnemyDrawer : public RefCounted {
	GDCLASS(PerilEnemyDrawer, RefCounted)

protected:
	static void _bind_methods();

public:
	// Draws p_enemies in array order on p_layer (an EntityLayer inside _draw, under
	// the standing arena transform), and refills p_frame_sats (carrier id -> its
	// satellites) first. Default and frozen dots draw here; every other type calls
	// the layer's own _draw_* method in place, so the draw order is unchanged.
	void draw(Object *p_layer, const Array &p_enemies, Dictionary p_frame_sats, double p_elapsed,
			int64_t p_look_slot, const Vector2 &p_arena_origin, double p_model_scale);
	void clear();
	// Cached sprites (for tests).
	int64_t cached_count() const;

private:
	struct DotEntry {
		Ref<Texture2D> atlas; // N5: both sprites are regions of one texture
		Rect2 outer_src;
		double outer_half = 0.0;
		Rect2 inner_src;
		double inner_half = 0.0;
	};
	struct FrozenEntry {
		Ref<Texture2D> tex;
		double half = 0.0;
	};
	std::unordered_map<int64_t, DotEntry> dots;
	std::unordered_map<int64_t, FrozenEntry> frozen;
};

} // namespace godot
