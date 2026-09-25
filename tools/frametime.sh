#!/usr/bin/env bash
# Usage: tools/frametime.sh <seconds> <label>
# Polls SurfaceFlinger's 128-frame present ring for the Godot surface every
# 1.5 s, dedups by timestamp, prints present-interval percentiles.
# dumpsys gfxinfo cannot see Godot's Vulkan SurfaceView (it reports 0 frames).
ADB="${ADB:-/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe}"
D="-s ${SERIAL:-RRCXB04L8EJ}"
SECS=${1:-30}; LABEL=${2:-run}
OUT="$(mktemp)"
L=$("$ADB" $D shell dumpsys SurfaceFlinger --list | grep -o '[0-9a-f]* SurfaceView\[com.jtg.perilpoint[^ ]*(BLAST)#[0-9]*' | head -1)
[ -n "$L" ] || { echo "no Peril Point surface — is the app in the foreground?"; exit 1; }
END=$(( $(date +%s) + SECS ))
while [ "$(date +%s)" -lt "$END" ]; do
  "$ADB" $D shell "dumpsys SurfaceFlinger --latency '$L'" | awk 'NR>1 && $2>0 && $2<9e18 {print $2}' >> "$OUT"
  sleep 1.5
done
sort -n -u "$OUT" | awk '{if(p) print ($1-p)/1e6; p=$1}' | awk '$1<200' | sort -n |
  awk -v l="$LABEL" '{a[NR]=$1; s+=$1; if($1>20) j++} END{printf "%s: n=%d mean=%.2fms p50=%.2f p95=%.2f p99=%.2f max=%.2f >20ms=%.1f%%\n", l, NR, s/NR, a[int(NR*.5)], a[int(NR*.95)], a[int(NR*.99)], a[NR], 100*j/NR}'
rm -f "$OUT"
