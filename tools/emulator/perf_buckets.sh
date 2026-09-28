#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27).
# Usage: perf_buckets.sh LOG... — averages the debug PERF lines of a run by enemy count.
# Line 1 per bucket: fps, sim steps/s and the script sections (ms/frame). Line 2: frame ms
# (1000/fps) and the main thread's split of it (PerfProbe marks: m_phys the physics steps,
# m_proc process + the _draw flush, m_tail RenderingServer sync/draw and the rest), the
# engine's slowest process step of each second (pmax), the render thread's CPU and GPU
# time, and draw calls.
for f in "$@"; do
  echo "== $f"
  grep PERF "$f" | grep s_swarm | sed 's/.*PERF //' | awk '{
    delete v
    for (i = 1; i <= NF; i++) { split($i, kv, "="); v[kv[1]] = kv[2] }
    split(v["d_entity"], de, "/"); split(v["s_swarm"], sw, "/"); split(v["phys"], ph, "/")
    split(v["m_phys"], mp, "/"); split(v["m_proc"], mc, "/"); split(v["m_tail"], mt, "/")
    en = v["en"]; b = (en < 50) ? "a <50" : (en < 100) ? "b 50-99" : (en < 150) ? "c 100-149" : (en < 250) ? "d 150-249" : "e 250+"
    n[b]++; f[b] += v["fps"]; s[b] += v["steps"]; e[b] += de[1]; w[b] += sw[1]; p[b] += ph[1]
    fm[b] += (v["fps"] > 0) ? 1000 / v["fps"] : 0; a1[b] += mp[1]; a2[b] += mc[1]; a3[b] += mt[1]; pm[b] += v["pmax"]
    rc[b] += v["rcpu"]; gp[b] += v["gpu"]; dr[b] += v["draws"]
  } END {
    for (b in n) {
      printf "%s1	%-10s n=%3d fps=%5.1f steps=%4.0f d_entity=%6.1f phys=%6.1f s_swarm=%6.1f\n", b, substr(b, 3), n[b], f[b] / n[b], s[b] / n[b], e[b] / n[b], p[b] / n[b], w[b] / n[b]
      printf "%s2	%-10s       frame=%5.1f m_phys=%5.1f m_proc=%5.1f m_tail=%5.1f pmax=%5.1f rcpu=%5.1f gpu=%5.1f draws=%4.0f\n", b, substr(b, 3), fm[b] / n[b], a1[b] / n[b], a2[b] / n[b], a3[b] / n[b], pm[b] / n[b], rc[b] / n[b], gp[b] / n[b], dr[b] / n[b]
    }
  }' | sort | cut -f2-
done
