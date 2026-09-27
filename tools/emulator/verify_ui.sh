#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27).
# Usage: verify_ui.sh OUT_DIR — one scripted pass over the screens the M11c review
# fixes touch; screenshots land in OUT_DIR, plus errors.txt (logcat) and pid.txt.
A=/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe; S="-s emulator-5554"
D="$(dirname "$0")"; OUT="$1"; mkdir -p "$OUT"
shot() { sleep "${2:-2.5}"; $A $S exec-out screencap -p > "$OUT/$1.png"; }
tap() { SHOTS="$OUT" "$D/g.sh" tap "$1" "$2"; }
$A $S shell am force-stop com.jtg.perilpoint; sleep 2; $A $S logcat -c
$A $S shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
for i in $(seq -w 1 28); do $A $S exec-out screencap -p > "$OUT/launch_$i.png"; done
shot 01_menu 10
tap 1349 786; shot 02_armory_weapons
tap 1240 83;  shot 03_armory_boosts
tap 1064 83;  shot 04_armory_handling
tap 188 83;   shot 05_menu_again
tap 1657 786; shot 06_milestones
tap 188 83;   shot 07_menu_again2
tap 1875 786; shot 08_settings
tap 188 83;   shot 09_menu_again3
tap 1567 405; shot 10_code_red_selected 2
tap 1567 643; shot 11_run_start 2
shot 12_run_hud 1.5
tap 1832 92;  shot 13_pause 2
tap 640 356;  shot 14_resumed 1.5
shot 15_run_over 8
$A $S logcat -d | grep -E "SCRIPT ERROR|E godot|FATAL|AndroidRuntime" | grep -v "viewport_get_measured" > "$OUT/errors.txt"
$A $S shell pidof com.jtg.perilpoint > "$OUT/pid.txt"
echo "verify_ui done: $OUT"
