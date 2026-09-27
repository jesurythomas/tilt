#include "peril_native.h"

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

// EnemySwarm._separate_pair. True when it pushed.
bool separate_pair(std::vector<double> &xs, std::vector<double> &ys, int ii, int jj, double min_distance, double min_distance2) {
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

} // namespace

void PerilNative::_bind_methods() {
	ClassDB::bind_static_method("PerilNative", D_METHOD("version"), &PerilNative::version);
	ClassDB::bind_static_method("PerilNative", D_METHOD("separate", "xs", "ys", "min_distance"), &PerilNative::separate);
}

String PerilNative::version() {
	return String("peril-native 2");
}

PackedFloat64Array PerilNative::separate(const PackedFloat64Array &p_xs, const PackedFloat64Array &p_ys, double min_distance) {
	const int n = int(p_xs.size());
	std::vector<double> xs(p_xs.ptr(), p_xs.ptr() + n);
	std::vector<double> ys(p_ys.ptr(), p_ys.ptr() + n);
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

	PackedFloat64Array out;
	out.resize(2 * n);
	double *w = out.ptrw();
	for (int k = 0; k < n; k++) {
		w[k] = xs[k];
		w[n + k] = ys[k];
	}
	return out;
}
