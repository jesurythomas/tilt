// EnemySwarm's per-enemy loop and separation over PerilEnemy objects (M11c N3).
#include "peril_native.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include "peril_enemy.h"
#include "peril_sweep.h"
#include "peril_types.h"

#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <vector>

using namespace godot;

namespace {

constexpr double GD_PI = 3.1415926535897932384626433833; // GDScript PI (Math_PI)

inline PerilEnemy *enemy_at(const Array &p_enemies, int64_t p_i) {
	return Object::cast_to<PerilEnemy>(p_enemies[p_i]);
}

} // namespace

// EnemySwarm.update step 3, the reverse per-enemy loop, line for line. The float
// expressions keep the GDScript operand order (no contraction: SConstruct), and the
// transcendental calls go through the engine's own functions (UtilityFunctions), so
// every value matches the GDScript loop bit for bit. The types that draw randf() or
// emit particles run their GDScript update_* in place, keeping the RNG order.
void PerilNative::swarm_step(Object *p_swarm, const Array &p_enemies, Object *p_particles,
		const Vector2 &p_player_pos, const Vector2 &p_bounds, double dt, double speed_scale,
		double seeker_speed, double seeker_steer, double circle_speed, double specter_speed) {
	static const StringName sn_charger("update_charger");
	static const StringName sn_artillery("update_artillery");
	static const StringName sn_pulsar("update_pulsar");
	static const StringName sn_snake("update_snake_segment");

	Array enemies = p_enemies; // shares the swarm's array (Arrays are references)
	const double px = p_player_pos.x;
	const double py = p_player_pos.y;
	const double bx = p_bounds.x;
	const double by = p_bounds.y;
	const Variant v_player_pos = p_player_pos;
	const Variant v_dt = dt;
	const Variant v_particles = p_particles;

	// P17's map: carrier id -> its satellites in array order. Satellites never leave
	// the array inside the loop (only bullets and sweep dots do) and
	// parent_carrier_id changes only in on_enemy_killed.
	std::unordered_map<int64_t, std::vector<PerilEnemy *>> sats;
	const int64_t n0 = enemies.size();
	for (int64_t k = 0; k < n0; k++) {
		PerilEnemy *s = enemy_at(enemies, k);
		if (s->parent_carrier_id != PerilEnemy::ABSENT) {
			sats[s->parent_carrier_id].push_back(s);
		}
	}

	for (int64_t i = n0 - 1; i >= 0; i--) {
		PerilEnemy *e = enemy_at(enemies, i);
		e->age += dt;

		if (e->frozen) {
			e->freeze_timer -= dt;
			if (e->freeze_timer <= 0.0) {
				e->frozen = false;
			}
			continue;
		}

		switch (e->type) {
			case SEEKER: {
				double ex = e->x;
				double ey = e->y;
				double evx = e->vx;
				double evy = e->vy;
				const double sdx = px - ex;
				const double sdy = py - ey;
				const double sdist = std::sqrt(sdx * sdx + sdy * sdy);
				if (sdist > 1.0) {
					double target_speed = seeker_speed;
					if (e->chilled) {
						target_speed *= 0.45;
					}
					const double target_vx = (sdx / sdist) * target_speed;
					const double target_vy = (sdy / sdist) * target_speed;
					evx += (target_vx - evx) * seeker_steer;
					evy += (target_vy - evy) * seeker_steer;
				}
				ex += evx * dt * speed_scale;
				ey += evy * dt * speed_scale;
				if (e->orbit_center == Vector2() && e->parent_carrier_id == PerilEnemy::ABSENT) {
					const double spad = e->radius;
					if (ex < spad) {
						ex = spad;
						evx = std::fabs(evx) * 0.5;
					}
					if (ex > bx - spad) {
						ex = bx - spad;
						evx = -std::fabs(evx) * 0.5;
					}
					if (ey < spad) {
						ey = spad;
						evy = std::fabs(evy) * 0.5;
					}
					if (ey > by - spad) {
						ey = by - spad;
						evy = -std::fabs(evy) * 0.5;
					}
				}
				e->x = ex;
				e->y = ey;
				e->vx = evx;
				e->vy = evy;
				continue;
			}
			case ARROW_DRONE:
			case WALL_DOT: {
				const double wx = e->x + e->vx * dt * speed_scale;
				const double wy = e->y + e->vy * dt * speed_scale;
				e->x = wx;
				e->y = wy;
				if (wx < -140.0 || wx > bx + 140.0 || wy < -140.0 || wy > by + 140.0) {
					enemies.remove_at(i);
				}
				continue;
			}
			case CIRCLE_DOT: {
				// update_circle_dot
				if (!std::isnan(e->special_timer) && e->special_timer > 0.0) {
					e->special_timer -= dt;
					e->vx = 0.0;
					e->vy = 0.0;
					break;
				}
				const double dx = px - e->x;
				const double dy = py - e->y;
				const double dist = std::sqrt(dx * dx + dy * dy);
				if (dist > 1.0) {
					e->vx = (dx / dist) * circle_speed;
					e->vy = (dy / dist) * circle_speed;
				}
				e->x += e->vx * dt * speed_scale;
				e->y += e->vy * dt * speed_scale;
				break;
			}
			case TURRET_DOT: {
				if (e->orbit_center != Vector2()) {
					// update_rotating_gate_dot (orbit_center is non-zero on this branch)
					if (std::isnan(e->orbit_radius) || std::isnan(e->orbit_speed)) {
						break;
					}
					if (std::isnan(e->target_angle)) {
						e->target_angle = 0.0;
					}
					e->target_angle += e->orbit_speed * dt * speed_scale;
					e->x = double(e->orbit_center.x) + UtilityFunctions::cos(e->target_angle) * e->orbit_radius;
					e->y = double(e->orbit_center.y) + UtilityFunctions::sin(e->target_angle) * e->orbit_radius;
				} else {
					// update_turret_dot
					const double target_angle = UtilityFunctions::atan2(py - e->y, px - e->x);
					if (std::isnan(e->target_angle)) {
						e->target_angle = target_angle;
					}
					double diff = target_angle - e->target_angle;
					while (diff < -GD_PI) {
						diff += GD_PI * 2.0;
					}
					while (diff > GD_PI) {
						diff -= GD_PI * 2.0;
					}
					e->target_angle += diff * std::min(1.0, dt * 2.5);
					e->x += e->vx * dt * speed_scale;
					e->y += e->vy * dt * speed_scale;
				}
				break;
			}
			case SPIKE_MINE:
				e->x += e->vx * dt * speed_scale;
				e->y += e->vy * dt * speed_scale;
				break;
			case SNAKE_SEGMENT:
				p_swarm->call(sn_snake, enemies[i], v_dt);
				break;
			case CHARGER:
				p_swarm->call(sn_charger, enemies[i], v_player_pos, v_dt, v_particles);
				break;
			case ARTILLERY:
				p_swarm->call(sn_artillery, enemies[i], v_player_pos, v_dt);
				break;
			case BULLET:
				// update_bullet, then its 60-px cull (it always fires before the 140-px one).
				e->x += e->vx * dt * speed_scale;
				e->y += e->vy * dt * speed_scale;
				if (e->age > 4.5 || e->x < -60.0 || e->x > bx + 60.0 || e->y < -60.0 || e->y > by + 60.0) {
					enemies.remove_at(i);
				}
				continue;
			case CARRIER: {
				// update_carrier
				const double dx = px - e->x;
				const double dy = py - e->y;
				const double dist = std::sqrt(dx * dx + dy * dy);
				if (dist > 1.0) {
					const double target_speed = 55.0;
					const double target_vx = (dx / dist) * target_speed;
					const double target_vy = (dy / dist) * target_speed;
					e->vx += (target_vx - e->vx) * 1.5 * dt;
					e->vy += (target_vy - e->vy) * 1.5 * dt;
				}
				e->x += e->vx * dt * speed_scale;
				e->y += e->vy * dt * speed_scale;
				const auto found = sats.find(e->id);
				if (found != sats.end()) {
					for (PerilEnemy *sat : found->second) {
						if (sat->parent_carrier_id != e->id) {
							continue;
						}
						if (std::isnan(sat->orbit_angle)) {
							sat->orbit_angle = 0.0;
						}
						if (std::isnan(sat->orbit_radius)) {
							sat->orbit_radius = 38.0;
						}
						sat->orbit_angle += 2.0 * dt * speed_scale;
						sat->x = e->x + UtilityFunctions::cos(sat->orbit_angle) * sat->orbit_radius;
						sat->y = e->y + UtilityFunctions::sin(sat->orbit_angle) * sat->orbit_radius;
						sat->vx = 0.0;
						sat->vy = 0.0;
					}
				}
				break;
			}
			case PULSAR:
				p_swarm->call(sn_pulsar, enemies[i], v_player_pos, v_dt, v_particles);
				break;
			case SPECTER: {
				// update_specter
				const double dx = px - e->x;
				const double dy = py - e->y;
				const double dist = std::sqrt(dx * dx + dy * dy);
				if (dist > 1.0) {
					e->vx += ((dx / dist) * specter_speed - e->vx) * 3.8 * dt;
					e->vy += ((dy / dist) * specter_speed - e->vy) * 3.8 * dt;
				}
				e->x += e->vx * dt * speed_scale;
				e->y += e->vy * dt * speed_scale;
				e->stealth_opacity =
						0.25 + 0.75 * UtilityFunctions::pow(UtilityFunctions::sin(e->age * 3.2), 2.0);
				break;
			}
			default:
				break;
		}

		// Clamp standard enemies inside playfield (no sweep type reaches here).
		if (e->orbit_center == Vector2() && e->parent_carrier_id == PerilEnemy::ABSENT) {
			const double pad = e->radius;
			if (e->x < pad) {
				e->x = pad;
				e->vx = std::fabs(e->vx) * 0.5;
			}
			if (e->x > bx - pad) {
				e->x = bx - pad;
				e->vx = -std::fabs(e->vx) * 0.5;
			}
			if (e->y < pad) {
				e->y = pad;
				e->vy = std::fabs(e->vy) * 0.5;
			}
			if (e->y > by - pad) {
				e->y = by - pad;
				e->vy = -std::fabs(e->vy) * 0.5;
			}
		}
	}
}

// EnemySwarm.apply_flocking_separation over the enemies: separation_candidates(),
// the x/y copies, the sweep (or the plain pair loop below p_sweep_min candidates)
// and the write-back, with the same arithmetic as the GDScript.
void PerilNative::separate_enemies(const Array &p_enemies, double min_distance, int64_t p_sweep_min) {
	const int64_t count = p_enemies.size();
	std::vector<PerilEnemy *> cand;
	cand.reserve(size_t(count));
	for (int64_t i = 0; i < count; i++) {
		PerilEnemy *e = enemy_at(p_enemies, i);
		if (e->frozen || e->type == WALL_DOT || e->type == BULLET || e->orbit_center != Vector2() ||
				e->parent_carrier_id != PerilEnemy::ABSENT) {
			continue;
		}
		cand.push_back(e);
	}
	const int n = int(cand.size());
	std::vector<double> xs(cand.size());
	std::vector<double> ys(cand.size());
	for (int k = 0; k < n; k++) {
		xs[k] = cand[k]->x;
		ys[k] = cand[k]->y;
	}
	if (n >= p_sweep_min) {
		peril::separate_sweep(xs, ys, min_distance);
	} else {
		const double min_distance2 = min_distance * min_distance;
		for (int ii = 0; ii < n; ii++) {
			for (int jj = ii + 1; jj < n; jj++) {
				const double dx = xs[jj] - xs[ii];
				if (dx * dx >= min_distance2) {
					continue;
				}
				peril::separate_pair(xs, ys, ii, jj, min_distance, min_distance2);
			}
		}
	}
	for (int k = 0; k < n; k++) {
		cand[k]->x = xs[k];
		cand[k]->y = ys[k];
	}
}

// RunController.check_collisions' P21 x reject: the indices from p_start down to 0
// whose |dx| to the player is within player radius + enemy radius + 16 (+1 px), in
// descending order.
PackedInt32Array PerilNative::collision_candidates(const Array &p_enemies, double plx, double plr, int64_t p_start) {
	PackedInt32Array out;
	const int64_t last = std::min(p_start, p_enemies.size() - 1);
	for (int64_t i = last; i >= 0; i--) {
		const PerilEnemy *e = enemy_at(p_enemies, i);
		if (std::fabs(plx - e->x) > plr + e->radius + 16.0 + 1.0) {
			continue;
		}
		out.push_back(int32_t(i));
	}
	return out;
}

Dictionary PerilNative::enemy_type_ids() {
	Dictionary d;
	d["SEEKER"] = SEEKER;
	d["ARROW_DRONE"] = ARROW_DRONE;
	d["WALL_DOT"] = WALL_DOT;
	d["CIRCLE_DOT"] = CIRCLE_DOT;
	d["TURRET_DOT"] = TURRET_DOT;
	d["SPIKE_MINE"] = SPIKE_MINE;
	d["SNAKE_SEGMENT"] = SNAKE_SEGMENT;
	d["CHARGER"] = CHARGER;
	d["ARTILLERY"] = ARTILLERY;
	d["CARRIER"] = CARRIER;
	d["BULLET"] = BULLET;
	d["PULSAR"] = PULSAR;
	d["SPECTER"] = SPECTER;
	return d;
}


// WeaponSystem._missile_snapshot, line for line (M11c P35): the same floor((x + offset) *
// quant) keys packed with the slot, the same integer sort, the same derived arrays.
Array PerilNative::missile_snapshot(const Array &p_enemies, double p_quant, double p_offset, int64_t p_bits) {
	const int64_t n = p_enemies.size();
	PackedFloat64Array xs;
	PackedFloat64Array ys;
	PackedFloat64Array rs;
	xs.resize(n);
	ys.resize(n);
	rs.resize(n);
	Dictionary index;
	double max_r = 0.0;
	std::vector<int64_t> keys(n);
	for (int64_t k = 0; k < n; k++) {
		PerilEnemy *e = Object::cast_to<PerilEnemy>(p_enemies[k]);
		const double ex = e->x;
		xs.set(k, ex);
		ys.set(k, e->y);
		rs.set(k, e->radius);
		max_r = std::max(max_r, e->radius);
		index[e->id] = k;
		keys[k] = (int64_t(std::floor((ex + p_offset) * p_quant)) << p_bits) | k;
	}
	std::sort(keys.begin(), keys.end());
	PackedInt32Array order;
	PackedFloat64Array sorted_q;
	order.resize(n);
	sorted_q.resize(n);
	const int64_t mask = (int64_t(1) << p_bits) - 1;
	for (int64_t t = 0; t < n; t++) {
		order.set(t, int32_t(keys[t] & mask));
		sorted_q.set(t, double(keys[t] >> p_bits) / p_quant - p_offset);
	}
	Array out;
	out.append(xs);
	out.append(ys);
	out.append(rs);
	out.append(order);
	out.append(sorted_q);
	out.append(max_r);
	out.append(index);
	out.append(p_enemies.duplicate());
	return out;
}

