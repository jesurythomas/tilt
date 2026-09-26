#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27). ADB/serial are hard-coded for the dev machine.
# bot.sh SECS — steers in loops with continuous drags (display coords x1.212).
A=/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe; S="-s emulator-5554"
END=$(( $(date +%s) + ${1:-60} ))
P=("1210 545 1690 790" "1690 790 970 850" "970 850 730 420" "730 420 1210 545" "1210 545 1450 300" "1450 300 850 250" "850 250 1210 545")
while [ "$(date +%s)" -lt "$END" ]; do
  for p in "${P[@]}"; do $A $S shell input swipe $p 700; done
done
