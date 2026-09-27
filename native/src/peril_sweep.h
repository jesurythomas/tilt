#pragma once

#include <vector>

// The separation sweep shared by PerilNative.separate and PerilNative.separate_enemies.
namespace peril {

// EnemySwarm._separate_pair. True when it pushed.
bool separate_pair(std::vector<double> &xs, std::vector<double> &ys, int ii, int jj, double min_distance, double min_distance2);

// EnemySwarm._separate_sweep, in place on xs/ys.
void separate_sweep(std::vector<double> &xs, std::vector<double> &ys, double min_distance);

} // namespace peril
