#!/usr/bin/env bash
# Builds the PerilGames Godot Android plugin (android/peril-games, ruling PGS R1) and copies its
# AARs to godot/addons/peril_games/bin/, where the export plugin picks them up. Commit both AARs
# after a change to the Java source or the SDK version.
#
# Usage:  tools/build_games_plugin.sh
# Needs:  JDK 17, the Android SDK (ANDROID_HOME), and Godot's Android build template installed
#         at godot/android/build (Project > Install Android Build Template), whose Gradle
#         wrapper this borrows so the plugin builds with the same Gradle as the game.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-C:/Users/Jesury/AppData/Local/Android/Sdk}"
GRADLEW="$REPO/godot/android/build/gradlew"
SRC="$REPO/android/peril-games"
OUT="$REPO/godot/addons/peril_games/bin"

if [[ ! -f "$GRADLEW" ]]; then
	echo "FAIL: no Gradle wrapper at $GRADLEW (install Godot's Android build template)." >&2
	exit 1
fi

bash "$GRADLEW" -p "$SRC" --no-daemon assembleDebug assembleRelease
mkdir -p "$OUT"
cp "$SRC/build/outputs/aar/peril-games-debug.aar" "$OUT/peril-games-debug.aar"
cp "$SRC/build/outputs/aar/peril-games-release.aar" "$OUT/peril-games-release.aar"
echo "OK: $(ls -l "$OUT"/*.aar | awk '{print $5, $9}' | tr '\n' ' ')"
