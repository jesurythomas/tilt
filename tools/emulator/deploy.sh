#!/usr/bin/env bash
# Emulator helpers (2026-09-28). Usage: deploy.sh [--fresh] — exports the debug APK,
# installs it on emulator-5554 (waiting out adb restarts), optionally clears the app's
# data (--fresh: a new save), launches it and waits until the menu is up.
A=/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe; S="-s emulator-5554"
D="$(dirname "$0")"; R="$D/../.."
G="${GODOT:-/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
"$G" --headless --path "$R/godot" --export-debug "Android" build/peril-point-debug.apk 2>&1 | grep -iE "error|fail" | head -3
git -C "$R" checkout godot/project.godot 2>/dev/null   # headless runs strip one default-valued line
$A $S wait-for-device
for i in 1 2 3; do
  $A $S install -r "$R/godot/build/peril-point-debug.apk" 2>&1 | grep -q Success && break
  sleep 3; $A $S wait-for-device
done
[ "$1" = "--fresh" ] && $A $S shell pm clear com.jtg.perilpoint >/dev/null
$A $S shell am force-stop com.jtg.perilpoint
$A $S logcat -c
$A $S shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
for i in $(seq 1 60); do
  $A $S logcat -d -s Godot:V | grep -q OnGodotMainLoopStarted && break
  sleep 1
done
sleep 6   # the menu's first frames
echo "DEPLOYED pid=$($A $S shell pidof com.jtg.perilpoint)"
