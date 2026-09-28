#include "peril_native.h"
#include "peril_sweep.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

using namespace godot;

namespace {

// Mirrors EnemySwarm's SWEEP_* constants (enemy_swarm.gd); keep in step.
constexpr double SWEEP_SLACK = 4.0;
constexpr double SWEEP_REBUILD = 8.0;
constexpr double SWEEP_QUANT = 16.0;
constexpr double SWEEP_OFFSET = 65536.0;
constexpr int SWEEP_INDEX_BITS = 20;
constexpr int64_t SWEEP_INDEX_MASK = (int64_t(1) << SWEEP_INDEX_BITS) - 1;

// EnemySwarm._sweep_index: order sorted by quantised x, and those x values.
void sweep_index(const std::vector<double> &xs, std::vector<int32_t> &order, std::vector<double> &sorted_q) {
	const size_t n = xs.size();
	std::vector<int64_t> keys(n);
	for (size_t k = 0; k < n; k++) {
		const int64_t q = int64_t(std::floor((xs[k] + SWEEP_OFFSET) * SWEEP_QUANT));
		keys[k] = (q << SWEEP_INDEX_BITS) | int64_t(k);
	}
	std::sort(keys.begin(), keys.end());
	order.resize(n);
	sorted_q.resize(n);
	for (size_t t = 0; t < n; t++) {
		order[t] = int32_t(keys[t] & SWEEP_INDEX_MASK);
		sorted_q[t] = double(keys[t] >> SWEEP_INDEX_BITS) / SWEEP_QUANT - SWEEP_OFFSET;
	}
}

} // namespace

bool peril::separate_pair(std::vector<double> &xs, std::vector<double> &ys, int ii, int jj, double min_distance, double min_distance2) {
	const double dx = xs[jj] - xs[ii];
	if (dx * dx >= min_distance2) {
		return false;
	}
	const double dy = ys[jj] - ys[ii];
	const double dist2 = dx * dx + dy * dy;
	if (dist2 < min_distance2 && dist2 > 0.0001) {
		const double dist = std::sqrt(dist2);
		const double push = (min_distance - dist) * 0.15;
		const double px = (dx / dist) * push;
		const double py = (dy / dist) * push;
		xs[ii] -= px;
		ys[ii] -= py;
		xs[jj] += px;
		ys[jj] += py;
		return true;
	}
	return false;
}

void PerilNative::_bind_methods() {
	ClassDB::bind_static_method("PerilNative", D_METHOD("version"), &PerilNative::version);
	ClassDB::bind_static_method("PerilNative", D_METHOD("separate", "xs", "ys", "min_distance"), &PerilNative::separate);
	ClassDB::bind_static_method("PerilNative",
			D_METHOD("grid_step", "px", "py", "ox", "oy", "vx", "vy", "active", "is_active", "stiffness", "damping", "settle_eps"),
			&PerilNative::grid_step);
	ClassDB::bind_static_method("PerilNative",
			D_METHOD("grid_explode", "px", "py", "vx", "vy", "active", "is_active", "c0", "c1", "r0", "r1", "cols", "cx", "cy", "force", "radius"),
			&PerilNative::grid_explode);
	ClassDB::bind_static_method("PerilNative",
			D_METHOD("swarm_step", "swarm", "enemies", "particles", "player_pos", "bounds", "dt", "speed_scale",
					"seeker_speed", "seeker_steer", "circle_speed", "specter_speed"),
			&PerilNative::swarm_step);
	ClassDB::bind_static_method("PerilNative", D_METHOD("separate_enemies", "enemies", "min_distance", "sweep_min"),
			&PerilNative::separate_enemies);
	ClassDB::bind_static_method("PerilNative", D_METHOD("collision_candidates", "enemies", "plx", "plr", "start"),
			&PerilNative::collision_candidates);
	ClassDB::bind_static_method("PerilNative", D_METHOD("enemy_type_ids"), &PerilNative::enemy_type_ids);
	ClassDB::bind_static_method("PerilNative", D_METHOD("missile_snapshot", "enemies", "quant", "offset", "bits"),
			&PerilNative::missile_snapshot);
	ClassDB::bind_static_method("PerilNative", D_METHOD("particles_flush", "particles", "pool", "total", "flushed", "dt"),
			&PerilNative::particles_flush);
	ClassDB::bind_static_method("PerilNative",
			D_METHOD("particles_emit_sparks", "particles", "pool", "steps", "x", "y", "count", "color", "speed_max"),
			&PerilNative::particles_emit_sparks);
	ClassDB::bind_static_method("PerilNative",
			D_METHOD("particles_emit_explosion", "particles", "pool", "steps", "x", "y", "color", "count"),
			&PerilNative::particles_emit_explosion);
	ClassDB::bind_static_method("PerilNative",
			D_METHOD("particles_emit_smoke", "particles", "pool", "steps", "x", "y", "color"),
			&PerilNative::particles_emit_smoke);
	ClassDB::bind_static_method("PerilNative",
			D_METHOD("particles_emit_ice_shatter", "particles", "pool", "steps", "x", "y", "count"),
			&PerilNative::particles_emit_ice_shatter);
	ClassDB::bind_static_method("PerilNative",
			D_METHOD("particles_emit_blizzard_snow", "particles", "pool", "steps", "bounds", "count"),
			&PerilNative::particles_emit_blizzard_snow);
	ClassDB::bind_static_method("PerilNative",
			D_METHOD("particles_emit_kinetic_ice_shards", "particles", "pool", "steps", "x", "y", "count"),
			&PerilNative::particles_emit_kinetic_ice_shards);
	ClassDB::bind_static_method("PerilNative",
			D_METHOD("particles_emit_thruster_sparks", "particles", "pool", "steps", "x", "y", "angle", "color"),
			&PerilNative::particles_emit_thruster_sparks);
}

String PerilNative::version() {
	return String("peril-native 5");
}

void peril::separate_sweep(std::vector<double> &xs, std::vector<double> &ys, double min_distance) {
	const int n = int(xs.size());
	const double min_distance2 = min_distance * min_distance;

	std::vector<double> built_x = xs;
	std::vector<int32_t> order;
	std::vector<double> sorted_q;
	sweep_index(xs, order, sorted_q);
	double drift = 0.0;
	std::vector<int32_t> window;
	window.reserve(64);
	const double reach_y = min_distance + SWEEP_SLACK + 1.0 / SWEEP_QUANT;
	for (int ii = 0; ii < n; ii++) {
		const double x0 = xs[ii];
		const double y0 = ys[ii];
		const double reach = min_distance + drift + SWEEP_SLACK + 1.0 / SWEEP_QUANT;
		// bsearch(v, true) = first >= v; bsearch(v, false) = first > v.
		const int lo = int(std::lower_bound(sorted_q.begin(), sorted_q.end(), x0 - reach) - sorted_q.begin());
		const int hi = int(std::upper_bound(sorted_q.begin(), sorted_q.end(), x0 + reach) - sorted_q.begin());
		window.clear();
		for (int t = lo; t < hi; t++) {
			const int k = order[t];
			if (k > ii && std::fabs(ys[k] - y0) < reach_y) {
				window.push_back(k);
			}
		}
		if (window.size() > 1) {
			std::sort(window.begin(), window.end());
		}
		for (size_t w = 0; w < window.size(); w++) {
			const int jj = window[w];
			const double dx = xs[jj] - xs[ii];
			if (dx * dx >= min_distance2) {
				continue;
			}
			const double dy = ys[jj] - ys[ii];
			const double dist2 = dx * dx + dy * dy;
			if (dist2 < min_distance2 && dist2 > 0.0001) {
				const double dist = std::sqrt(dist2);
				const double push = (min_distance - dist) * 0.15;
				const double px = (dx / dist) * push;
				const double py = (dy / dist) * push;
				xs[ii] -= px;
				ys[ii] -= py;
				xs[jj] += px;
				ys[jj] += py;
				drift = std::max(drift, std::fabs(xs[jj] - built_x[jj]));
				if (std::fabs(xs[ii] - x0) >= SWEEP_SLACK || std::fabs(ys[ii] - y0) >= SWEEP_SLACK) {
					for (int later = jj + 1; later < n; later++) {
						const double ldx = xs[later] - xs[ii];
						if (ldx * ldx >= min_distance2) {
							continue;
						}
						if (separate_pair(xs, ys, ii, later, min_distance, min_distance2)) {
							drift = std::max(drift, std::fabs(xs[later] - built_x[later]));
						}
					}
					break;
				}
			}
		}
		if (drift >= SWEEP_REBUILD) {
			built_x = xs;
			sweep_index(xs, order, sorted_q);
			drift = 0.0;
		}
	}
}


PackedFloat64Array PerilNative::separate(const PackedFloat64Array &p_xs, const PackedFloat64Array &p_ys, double min_distance) {
	const int n = int(p_xs.size());
	std::vector<double> xs(p_xs.ptr(), p_xs.ptr() + n);
	std::vector<double> ys(p_ys.ptr(), p_ys.ptr() + n);
	peril::separate_sweep(xs, ys, min_distance);

	PackedFloat64Array out;
	out.resize(2 * n);
	double *w = out.ptrw();
	for (int k = 0; k < n; k++) {
		w[k] = xs[k];
		w[n + k] = ys[k];
	}
	return out;
}

Array PerilNative::grid_step(const PackedFloat64Array &p_px, const PackedFloat64Array &p_py,
		const PackedFloat64Array &p_ox, const PackedFloat64Array &p_oy,
		const PackedFloat64Array &p_vx, const PackedFloat64Array &p_vy,
		const PackedInt32Array &p_active, const PackedByteArray &p_is_active,
		double stiffness, double damping, double settle_eps) {
	// Copies (copy-on-write: the first ptrw() detaches them from the caller's arrays).
	PackedFloat64Array px = p_px;
	PackedFloat64Array py = p_py;
	PackedFloat64Array vx = p_vx;
	PackedFloat64Array vy = p_vy;
	PackedByteArray is_active = p_is_active;
	double *pxw = px.ptrw();
	double *pyw = py.ptrw();
	double *vxw = vx.ptrw();
	double *vyw = vy.ptrw();
	uint8_t *actw = is_active.ptrw();
	const double *ox = p_ox.ptr();
	const double *oy = p_oy.ptr();
	const int32_t *act = p_active.ptr();
	const int64_t n_active = p_active.size();

	double max_d = 0.0;
	bool any_still = false;
	for (int64_t k = 0; k < n_active; k++) {
		const int32_t i = act[k];
		const double dx = ox[i] - pxw[i];
		const double dy = oy[i] - pyw[i];

		vxw[i] += dx * stiffness;
		vyw[i] += dy * stiffness;

		vxw[i] *= damping;
		vyw[i] *= damping;

		pxw[i] += vxw[i];
		pyw[i] += vyw[i];
		const double d = std::max(std::fabs(pxw[i] - ox[i]), std::fabs(pyw[i] - oy[i]));
		if (d < settle_eps && std::max(std::fabs(vxw[i]), std::fabs(vyw[i])) < settle_eps) {
			pxw[i] = ox[i];
			pyw[i] = oy[i];
			vxw[i] = 0.0;
			vyw[i] = 0.0;
			actw[i] = 0;
			any_still = true;
		} else {
			max_d = std::max(max_d, d);
		}
	}
	PackedInt32Array active;
	if (any_still) {
		active.resize(n_active);
		int32_t *aw = active.ptrw();
		int64_t kept = 0;
		for (int64_t k = 0; k < n_active; k++) {
			if (actw[act[k]] == 1) {
				aw[kept++] = act[k];
			}
		}
		active.resize(kept);
	} else {
		active = p_active;
	}

	Array out;
	out.resize(7);
	out[0] = px;
	out[1] = py;
	out[2] = vx;
	out[3] = vy;
	out[4] = active;
	out[5] = is_active;
	out[6] = max_d;
	return out;
}

Array PerilNative::grid_explode(const PackedFloat64Array &p_px, const PackedFloat64Array &p_py,
		const PackedFloat64Array &p_vx, const PackedFloat64Array &p_vy,
		const PackedInt32Array &p_active, const PackedByteArray &p_is_active,
		int64_t c0, int64_t c1, int64_t r0, int64_t r1, int64_t cols,
		double cx, double cy, double force, double radius) {
	PackedFloat64Array vx = p_vx;
	PackedFloat64Array vy = p_vy;
	PackedInt32Array active = p_active;
	PackedByteArray is_active = p_is_active;
	double *vxw = vx.ptrw();
	double *vyw = vy.ptrw();
	uint8_t *actw = is_active.ptrw();
	const double *px = p_px.ptr();
	const double *py = p_py.ptr();
	const double r2 = radius * radius;
	bool touched = false;
	std::vector<int32_t> added;
	for (int64_t r = r0; r <= r1; r++) {
		const int64_t row_offset = r * cols;
		for (int64_t c = c0; c <= c1; c++) {
			const int64_t i = row_offset + c;
			const double dx = px[i] - cx;
			const double dy = py[i] - cy;
			const double dist2 = dx * dx + dy * dy;
			if (dist2 < r2 && dist2 > 0.001) {
				const double dist = std::sqrt(dist2);
				const double factor = (1.0 - dist / radius) * force;
				vxw[i] += (dx / dist) * factor;
				vyw[i] += (dy / dist) * factor;
				if (actw[i] == 0) {
					actw[i] = 1;
					added.push_back(int32_t(i));
				}
				touched = true;
			}
		}
	}
	if (!added.empty()) {
		const int64_t base = active.size();
		active.resize(base + int64_t(added.size()));
		int32_t *aw = active.ptrw();
		for (size_t k = 0; k < added.size(); k++) {
			aw[base + int64_t(k)] = added[k];
		}
	}
	Array out;
	out.resize(5);
	out[0] = vx;
	out[1] = vy;
	out[2] = active;
	out[3] = is_active;
	out[4] = touched;
	return out;
}
