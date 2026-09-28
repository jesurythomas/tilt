#!/usr/bin/env bash
# Emulator helper (UI R10, 2026-09-28). Usage: menu_idle.sh <tag>... — installs
# godot/build/peril-point-<tag>.apk for each, leaves it on the menu for IDLE seconds
# (default 240) and logs its PERF lines to menu_<tag>.log (en= is the menu swarm).
A=/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe; S="-s emulator-5554"
D="$(dirname "$0")"; B="$D/../../godot/build"; L="${LOGS:-$B}"
for v in "$@"; do
  $A $S install -r "$B/peril-point-$v.apk" >/dev/null
  $A $S shell am force-stop com.jtg.perilpoint
  sleep 3
  $A $S logcat -c
  $A $S shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  $A $S logcat -s godot:I > "$L/menu_$v.log" 2>&1 &
  LP=$!
  sleep "${IDLE:-240}"
  "$D/g.sh" shot menu_end_$v 0 >/dev/null
  kill $LP 2>/dev/null
  $A $S shell am force-stop com.jtg.perilpoint
done
echo MENU-IDLE-DONE
