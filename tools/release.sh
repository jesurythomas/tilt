#!/usr/bin/env bash
# Builds a signed release APK of Peril Point: godot/build/peril-point-<version>.apk.
#
# Usage:  tools/release.sh
# Needs:  the release native library (godot/bin/libperil.android.template_release.arm64.so;
#         rebuilt here if missing) and a release keystore, given by an env file:
#           GODOT_ANDROID_KEYSTORE_RELEASE_PATH=...
#           GODOT_ANDROID_KEYSTORE_RELEASE_USER=...      (the key alias)
#           GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
#         read from $PERIL_KEYS (default ~/.android/peril-dev-release.env). The default
#         is a throwaway dev key for sharing test builds — swap it for the real one
#         before a store release, and keep both out of git.
# Before each build you hand out, raise version/code in godot/export_presets.cfg.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
KEYS="${PERIL_KEYS:-$HOME/.android/peril-dev-release.env}"
SDK="${ANDROID_HOME:-C:/Users/Jesury/AppData/Local/Android/Sdk}"
LIB="$REPO/godot/bin/libperil.android.template_release.arm64.so"

if [[ ! -f "$KEYS" ]]; then
	echo "FAIL: no keystore env file at $KEYS (see the header of this script)." >&2
	exit 1
fi
set -a
# shellcheck disable=SC1090
source "$KEYS"
set +a

if [[ ! -f "$LIB" ]]; then
	echo "Building the release native library..."
	(cd "$REPO/native" && ANDROID_HOME="$SDK" python -m SCons platform=android arch=arm64 \
		target=template_release ndk_version=29.0.14206865)
fi

VERSION="$(sed -n 's/^version\/name="\(.*\)"$/\1/p' "$REPO/godot/export_presets.cfg")"
CODE="$(sed -n 's/^version\/code=\(.*\)$/\1/p' "$REPO/godot/export_presets.cfg")"
OUT="build/peril-point-${VERSION:-release}.apk"

"$GODOT" --headless --path "$REPO/godot" --export-release "Android" "$OUT"
# A headless run strips one default-valued line from project.godot; put it back.
git -C "$REPO" checkout godot/project.godot 2>/dev/null || true

APK="$REPO/godot/$OUT"
BT="$(ls -d "$SDK"/build-tools/* | tail -1)"
"$BT/apksigner.bat" verify "$APK"
echo "OK: $APK (version $VERSION, code $CODE, $(du -h "$APK" | cut -f1))"
