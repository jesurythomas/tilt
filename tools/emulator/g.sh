#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27). ADB/serial are hard-coded for the dev machine.
# Usage: g.sh shot NAME [wait] | tap X Y | swipe X1 Y1 X2 Y2 MS | key K | log [n] | perf [n]
# Coordinates are in 2000x891 screenshot space (x1.212 to the 2424x1080 device).
# g.sh shot NAME | tap X Y (display coords, x1.212) | swipe X1 Y1 X2 Y2 MS | key K | log
A=/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe
S="-s emulator-5554"
DIR="${SHOTS:-$(dirname "$0")/../../godot/build/shots}"; mkdir -p "$DIR"
f(){ awk -v v="$1" 'BEGIN{printf "%d", v*1.212}'; }
case "$1" in
  shot) sleep ${3:-1.5}; $A $S exec-out screencap -p > "$DIR/$2.png"; echo "$DIR/$2.png";;
  tap) $A $S shell input tap $(f $2) $(f $3);;
  swipe) $A $S shell input swipe $(f $2) $(f $3) $(f $4) $(f $5) ${6:-300};;
  key) $A $S shell input keyevent $2;;
  log) $A $S logcat -d -s godot:* | grep -v PERF | tail -${2:-30};;
  perf) $A $S logcat -d -s godot:* | grep PERF | tail -${2:-10};;
esac
