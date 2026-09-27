#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27). ADB/serial are hard-coded for the dev machine.
# bot.sh SECS — flies the ship around a square (device coords, 560 px sides around the
# arena centre), one continuous drag per side, so runs are repeatable and the swarm
# trails the ship in the same shape every lap (user, 2026-09-27: "let it run in a square").
A=/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe; S="-s emulator-5554"
END=$(( $(date +%s) + ${1:-60} ))
P=("930 260 1490 260" "1490 260 1490 820" "1490 820 930 820" "930 820 930 260")
while [ "$(date +%s)" -lt "$END" ]; do
  for p in "${P[@]}"; do $A $S shell input swipe $p 900; done
done
