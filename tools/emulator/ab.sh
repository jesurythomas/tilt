#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27). ADB/serial are hard-coded for the dev machine.
A=/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe; S="-s emulator-5554"
D="$(dirname "$0")"; B="$D/../../godot/build"; L="${LOGS:-$B}"
# Usage: ab.sh <tag-a> <tag-b>: installs godot/build/peril-point-god-<tag>.apk for each,
# starts the selected mode (Code Red in the review), steers 100 s, logs PERF to ab_<tag>.log.
for v in "$@"; do
  $A $S install -r $B/peril-point-god-$v.apk >/dev/null
  $A $S shell am force-stop com.jtg.perilpoint
  sleep 3
  $A $S shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep 30
  "$D/g.sh" shot ab_menu_$v 0 >/dev/null
  $A $S logcat -c
  "$D/g.sh" tap 1567 643
  $A $S logcat -s godot:I > "$L/ab_$v.log" 2>&1 &
  LP=$!
  "$D/bot.sh" 100
  "$D/g.sh" shot ab_end_$v 0 >/dev/null
  kill $LP 2>/dev/null
  $A $S shell am force-stop com.jtg.perilpoint
done
echo AB-DONE
