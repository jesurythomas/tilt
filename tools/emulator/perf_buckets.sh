#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27).
# Usage: perf_buckets.sh LOG... — averages the debug PERF lines of a run by enemy count.
for f in "$@"; do
  echo "== $f"
  grep PERF "$f" | grep s_swarm | sed 's/.*PERF //' | awk '{
    for (i = 1; i <= NF; i++) { split($i, kv, "="); v[kv[1]] = kv[2] }
    split(v["d_entity"], de, "/"); split(v["s_swarm"], sw, "/"); split(v["phys"], ph, "/")
    en = v["en"]; b = (en < 50) ? "a <50" : (en < 100) ? "b 50-99" : (en < 150) ? "c 100-149" : (en < 250) ? "d 150-249" : "e 250+"
    n[b]++; f[b] += v["fps"]; s[b] += v["steps"]; e[b] += de[1]; w[b] += sw[1]; p[b] += ph[1]
  } END {
    for (b in n) printf "%-10s n=%3d fps=%5.1f steps=%4.0f d_entity=%6.1f phys=%6.1f s_swarm=%6.1f\n", substr(b, 3), n[b], f[b] / n[b], s[b] / n[b], e[b] / n[b], p[b] / n[b], w[b] / n[b]
  }' | sort
done
