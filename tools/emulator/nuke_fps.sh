#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27).
# Usage: nuke_fps.sh LOG... — for each "NUKE en=N" in a perf-patch run, the PERF fps and
# enemy count for the 3 lines (seconds) before and the 4 after, to show the nuke-time dip.
for f in "$@"; do
  echo "== $f"
  grep -E "NUKE en=|PERF fps" "$f" | sed 's/.*godot *: //' | awk '
    /^NUKE/ { nuke[++nn] = NR; label[nn] = $0; next }
    { line[NR] = $0 }
    END {
      for (k = 1; k <= nn; k++) {
        out = label[k] ":"
        for (r = nuke[k] - 3; r <= nuke[k] + 4; r++) {
          if (!(r in line)) continue
          split(line[r], a, " "); fps = a[2]; sub("fps=", "", fps)
          en = ""; for (i = 1; i <= NF + 20; i++) if (a[i] ~ /^en=/) { en = a[i]; sub("en=", "", en) }
          out = out sprintf(" %s%s/%s", (r > nuke[k] ? "" : ""), fps, en)
          if (r == nuke[k] - 1) out = out " |"
        }
        print out
      }
    }'
done
