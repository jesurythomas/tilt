#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cmath>
#include <cstdint>

namespace godot {

// The enemy record. PORT: web/src/tilt-to-live/Types.ts:87-116
// DIVERGENCE(M11c N3a): was the GDScript inner class Types.Enemy (types.gd). It lives
// here so the native swarm loop reads its fields directly (a GDScript object's fields
// cost an Object::get/set each from C++). Same fields, same defaults; GDScript floats
// are 64-bit, so every float field is a double. Optional TS fields keep NAN or
// Types.ABSENT (-1) until a module sets them, as before.
class PerilEnemy : public RefCounted {
	GDCLASS(PerilEnemy, RefCounted)

protected:
	static void _bind_methods();

public:
	static constexpr int64_t ABSENT = -1; // Types.ABSENT

	int64_t id = 0;
	int64_t type = 0; // Types.EnemyType, SEEKER
	double x = 0.0;
	double y = 0.0;
	double vx = 0.0;
	double vy = 0.0;
	double radius = 0.0;
	bool frozen = false;
	double freeze_timer = 0.0;
	double age = 0.0;
	double health = 0.0;
	double target_angle = NAN; // `targetAngle?` in Types.ts:99
	double special_timer = NAN; // `specialTimer?` in Types.ts:100
	int64_t leader_id = ABSENT;
	int64_t parent_wave_id = ABSENT;
	Vector2 orbit_center; // float32, as in GDScript
	double orbit_radius = NAN; // `orbitRadius?` in Types.ts:104
	double orbit_speed = NAN; // `orbitSpeed?` in Types.ts:105
	bool chilled = false;
	bool is_hazard = false;
	int64_t state = ABSENT; // Types.EnemyState
	double aim_angle = NAN; // `aimAngle?` in Types.ts:109
	double aim_timer = NAN; // `aimTimer?` in Types.ts:110
	double fire_cooldown = NAN; // `fireCooldown?` in Types.ts:111
	int64_t parent_carrier_id = ABSENT;
	double orbit_angle = NAN; // `orbitAngle?` in Types.ts:113
	double pulse_timer = NAN; // `pulseTimer?` in Types.ts:114
	double stealth_opacity = NAN; // `stealthOpacity?` in Types.ts:115

#define PERIL_ENEMY_ACCESSORS(m_type, m_name) \
	void set_##m_name(m_type p_value) { m_name = p_value; } \
	m_type get_##m_name() const { return m_name; }

	PERIL_ENEMY_ACCESSORS(int64_t, id)
	PERIL_ENEMY_ACCESSORS(int64_t, type)
	PERIL_ENEMY_ACCESSORS(double, x)
	PERIL_ENEMY_ACCESSORS(double, y)
	PERIL_ENEMY_ACCESSORS(double, vx)
	PERIL_ENEMY_ACCESSORS(double, vy)
	PERIL_ENEMY_ACCESSORS(double, radius)
	PERIL_ENEMY_ACCESSORS(bool, frozen)
	PERIL_ENEMY_ACCESSORS(double, freeze_timer)
	PERIL_ENEMY_ACCESSORS(double, age)
	PERIL_ENEMY_ACCESSORS(double, health)
	PERIL_ENEMY_ACCESSORS(double, target_angle)
	PERIL_ENEMY_ACCESSORS(double, special_timer)
	PERIL_ENEMY_ACCESSORS(int64_t, leader_id)
	PERIL_ENEMY_ACCESSORS(int64_t, parent_wave_id)
	PERIL_ENEMY_ACCESSORS(Vector2, orbit_center)
	PERIL_ENEMY_ACCESSORS(double, orbit_radius)
	PERIL_ENEMY_ACCESSORS(double, orbit_speed)
	PERIL_ENEMY_ACCESSORS(bool, chilled)
	PERIL_ENEMY_ACCESSORS(bool, is_hazard)
	PERIL_ENEMY_ACCESSORS(int64_t, state)
	PERIL_ENEMY_ACCESSORS(double, aim_angle)
	PERIL_ENEMY_ACCESSORS(double, aim_timer)
	PERIL_ENEMY_ACCESSORS(double, fire_cooldown)
	PERIL_ENEMY_ACCESSORS(int64_t, parent_carrier_id)
	PERIL_ENEMY_ACCESSORS(double, orbit_angle)
	PERIL_ENEMY_ACCESSORS(double, pulse_timer)
	PERIL_ENEMY_ACCESSORS(double, stealth_opacity)

#undef PERIL_ENEMY_ACCESSORS
};

} // namespace godot
