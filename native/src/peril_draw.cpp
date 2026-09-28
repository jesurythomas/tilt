// EntityLayer._draw_enemies over PerilEnemy objects (M11c N4).
#include "peril_draw.h"

#include <godot_cpp/classes/canvas_item.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "peril_enemy.h"
#include "peril_types.h"

using namespace godot;

namespace {

// EntityLayer.DOT_KEY_STEPS and LOOK_KEY_STRIDE (entity_layer.gd).
constexpr double DOT_KEY_STEPS = 8.0;
constexpr int64_t LOOK_KEY_STRIDE = 256;

// A texture drawn at its own size, centred on p_pos: the expressions of
// _draw_default_dot / _draw_frozen_dot (Vector2 math in float32, as in GDScript).
inline void draw_centred(CanvasItem *p_ci, const Ref<Texture2D> &p_tex, const Vector2 &p_pos, double p_half) {
	const Vector2 h(p_half, p_half);
	p_ci->draw_texture_rect(p_tex, Rect2(p_pos - h, h * 2.0), false);
}

} // namespace

void PerilEnemyDrawer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("draw", "layer", "enemies", "frame_sats", "elapsed", "look_slot", "arena_origin", "model_scale"),
			&PerilEnemyDrawer::draw);
	ClassDB::bind_method(D_METHOD("clear"), &PerilEnemyDrawer::clear);
	ClassDB::bind_method(D_METHOD("cached_count"), &PerilEnemyDrawer::cached_count);
}

void PerilEnemyDrawer::clear() {
	dots.clear();
	frozen.clear();
}

int64_t PerilEnemyDrawer::cached_count() const {
	return int64_t(dots.size() + frozen.size());
}

// EntityLayer._draw_enemies, line for line: the same satellite map, the same type
// dispatch in the same order, and _draw_default_dot / _draw_frozen_dot inline (their
// sprites come from the layer's own _dot_sprites / _frozen_sprite on a miss). The
// draw calls are the CanvasItem methods GDScript calls, with the same arguments.
void PerilEnemyDrawer::draw(Object *p_layer, const Array &p_enemies, Dictionary p_frame_sats, double p_elapsed,
		int64_t p_look_slot, const Vector2 &p_arena_origin, double p_model_scale) {
	static const StringName sn_frozen_sprite("_frozen_sprite");
	static const StringName sn_dot_sprites("_dot_sprites");
	static const StringName sn_outer("outer");
	static const StringName sn_outer_half("outer_half");
	static const StringName sn_inner("inner");
	static const StringName sn_inner_half("inner_half");
	static const StringName sn_charger("_draw_charger");
	static const StringName sn_artillery("_draw_artillery");
	static const StringName sn_bullet("_draw_bullet");
	static const StringName sn_carrier("_draw_carrier");
	static const StringName sn_satellite("_draw_satellite");
	static const StringName sn_pulsar("_draw_pulsar");
	static const StringName sn_specter("_draw_specter");

	CanvasItem *ci = Object::cast_to<CanvasItem>(p_layer);
	ERR_FAIL_NULL(ci);
	const int64_t n = p_enemies.size();

	p_frame_sats.clear();
	for (int64_t i = 0; i < n; i++) {
		const Variant v = p_enemies[i];
		PerilEnemy *e = Object::cast_to<PerilEnemy>(v);
		if (e->parent_carrier_id != PerilEnemy::ABSENT) {
			const Variant key = e->parent_carrier_id;
			if (!p_frame_sats.has(key)) {
				p_frame_sats[key] = Array();
			}
			Array list = p_frame_sats[key];
			list.append(v);
		}
	}

	// Turret indicator (_begin_entity / _end_entity and draw_line's arguments).
	const Vector2 model_scale = Vector2(1, 1) * p_model_scale;
	const Color turret_col(1.0, 50.0 / 255.0, 50.0 / 255.0, 0.5);

	for (int64_t i = 0; i < n; i++) {
		const Variant v = p_enemies[i];
		PerilEnemy *e = Object::cast_to<PerilEnemy>(v);
		if (e->frozen) {
			const int64_t key = UtilityFunctions::roundi(e->radius * DOT_KEY_STEPS);
			auto it = frozen.find(key);
			if (it == frozen.end()) {
				FrozenEntry entry;
				entry.tex = p_layer->call(sn_frozen_sprite, e->radius);
				// The texture's own size (review fix): a radius sharing its key may differ slightly.
				entry.half = entry.tex->get_width() * 0.5;
				it = frozen.emplace(key, entry).first;
			}
			draw_centred(ci, it->second.tex, Vector2(e->x, e->y), it->second.half);
			continue;
		}
		switch (e->type) {
			case CHARGER:
				p_layer->call(sn_charger, v);
				continue;
			case ARTILLERY:
				p_layer->call(sn_artillery, v);
				continue;
			case BULLET:
				p_layer->call(sn_bullet, v);
				continue;
			case CARRIER:
				p_layer->call(sn_carrier, v);
				continue;
			default:
				break;
		}
		if (e->parent_carrier_id != PerilEnemy::ABSENT) {
			p_layer->call(sn_satellite, v);
			continue;
		}
		if (e->type == PULSAR) {
			p_layer->call(sn_pulsar, v);
			continue;
		}
		if (e->type == SPECTER) {
			p_layer->call(sn_specter, v);
			continue;
		}

		// _draw_default_dot
		const Vector2 e_pos(e->x, e->y);
		const double pulse = 0.85 + 0.15 * UtilityFunctions::sin(p_elapsed * 9.0 + double(e->id));
		const int64_t variant = e->chilled ? 2 : (e->is_hazard ? 1 : 0);
		const int64_t key = (UtilityFunctions::roundi(e->radius * DOT_KEY_STEPS) * 4 + variant) * LOOK_KEY_STRIDE + p_look_slot;
		auto it = dots.find(key);
		if (it == dots.end()) {
			const Variant sv = p_layer->call(sn_dot_sprites, e->radius, e->chilled, e->is_hazard);
			Object *s = sv;
			DotEntry entry;
			entry.outer = s->get(sn_outer);
			entry.outer_half = s->get(sn_outer_half);
			entry.inner = s->get(sn_inner);
			entry.inner_half = s->get(sn_inner_half);
			it = dots.emplace(key, entry).first;
		}
		draw_centred(ci, it->second.outer, e_pos, it->second.outer_half * pulse);
		draw_centred(ci, it->second.inner, e_pos, it->second.inner_half);

		// Turret dot warning indicator (PORT: EnemySwarm.ts:1635-1643)
		if (e->type == TURRET_DOT && !std::isnan(e->target_angle) && e->orbit_center == Vector2()) {
			ci->draw_set_transform(p_arena_origin + e_pos, e->target_angle, model_scale);
			ci->draw_line(Vector2(e->radius, 0.0), Vector2(e->radius + 18.0, 0.0), turret_col, 1.5);
			ci->draw_set_transform(p_arena_origin, 0.0, Vector2(1, 1));
		}
	}
}
