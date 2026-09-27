#include "peril_enemy.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

#define PERIL_ENEMY_BIND(m_variant, m_name)                                                      \
	ClassDB::bind_method(D_METHOD("set_" #m_name, "value"), &PerilEnemy::set_##m_name);        \
	ClassDB::bind_method(D_METHOD("get_" #m_name), &PerilEnemy::get_##m_name);                 \
	ADD_PROPERTY(PropertyInfo(Variant::m_variant, #m_name), "set_" #m_name, "get_" #m_name);

void PerilEnemy::_bind_methods() {
	PERIL_ENEMY_BIND(INT, id)
	PERIL_ENEMY_BIND(INT, type)
	PERIL_ENEMY_BIND(FLOAT, x)
	PERIL_ENEMY_BIND(FLOAT, y)
	PERIL_ENEMY_BIND(FLOAT, vx)
	PERIL_ENEMY_BIND(FLOAT, vy)
	PERIL_ENEMY_BIND(FLOAT, radius)
	PERIL_ENEMY_BIND(BOOL, frozen)
	PERIL_ENEMY_BIND(FLOAT, freeze_timer)
	PERIL_ENEMY_BIND(FLOAT, age)
	PERIL_ENEMY_BIND(FLOAT, health)
	PERIL_ENEMY_BIND(FLOAT, target_angle)
	PERIL_ENEMY_BIND(FLOAT, special_timer)
	PERIL_ENEMY_BIND(INT, leader_id)
	PERIL_ENEMY_BIND(INT, parent_wave_id)
	PERIL_ENEMY_BIND(VECTOR2, orbit_center)
	PERIL_ENEMY_BIND(FLOAT, orbit_radius)
	PERIL_ENEMY_BIND(FLOAT, orbit_speed)
	PERIL_ENEMY_BIND(BOOL, chilled)
	PERIL_ENEMY_BIND(BOOL, is_hazard)
	PERIL_ENEMY_BIND(INT, state)
	PERIL_ENEMY_BIND(FLOAT, aim_angle)
	PERIL_ENEMY_BIND(FLOAT, aim_timer)
	PERIL_ENEMY_BIND(FLOAT, fire_cooldown)
	PERIL_ENEMY_BIND(INT, parent_carrier_id)
	PERIL_ENEMY_BIND(FLOAT, orbit_angle)
	PERIL_ENEMY_BIND(FLOAT, pulse_timer)
	PERIL_ENEMY_BIND(FLOAT, stealth_opacity)
}
