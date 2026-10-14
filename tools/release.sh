#!/usr/bin/env bash
# Builds a signed release APK of Peril Point: godot/build/peril-point-<version>.apk.
# PERIL_AAB=1 builds the Play Store bundle (.aab) instead; sign it with the upload key
# (PERIL_KEYS=~/.android/peril-upload.env, made by tools/make-upload-key.sh). A bundle carries
# the Play listing's package, ph.newzenith.perilpoint (ruling PGS R6); an APK keeps the
# preset's com.jtg.perilpoint, so sideloads install over the A55's build and keep its save.
# PERIL_PACKAGE=<id> sets the package for either.
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
# PERIL_OUT=<name>.apk writes godot/build/<name>.apk instead (e.g. a build signed with
# another key, so it does not overwrite the shared APK).

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
EXT=apk
PRESETS="$REPO/godot/export_presets.cfg"
PACKAGE="${PERIL_PACKAGE:-}"
if [[ "${PERIL_AAB:-}" == 1 ]]; then
	EXT=aab
	PACKAGE="${PACKAGE:-ph.newzenith.perilpoint}"
fi
if [[ "$EXT" == aab || -n "$PACKAGE" ]]; then
	# The preset stays on APK and its own package; this run's edits are undone on exit.
	cp "$PRESETS" "$PRESETS.release-bak"
	trap 'mv -f "$PRESETS.release-bak" "$PRESETS"' EXIT
fi
if [[ "$EXT" == aab ]]; then
	sed -i 's/^gradle_build\/export_format=0/gradle_build\/export_format=1/' "$PRESETS"
fi
if [[ -n "$PACKAGE" ]]; then
	sed -i "s/^package\/unique_name=\".*\"$/package\/unique_name=\"$PACKAGE\"/" "$PRESETS"
	grep -q "^package/unique_name=\"$PACKAGE\"$" "$PRESETS"
fi
PACKAGE="$(sed -n 's/^package\/unique_name="\(.*\)"$/\1/p' "$PRESETS")"
OUT="build/${PERIL_OUT:-peril-point-${VERSION:-release}.$EXT}"

"$GODOT" --headless --path "$REPO/godot" --export-release "Android" "$OUT"
# A headless run strips one default-valued line from project.godot; put it back.
git -C "$REPO" checkout godot/project.godot 2>/dev/null || true

APK="$REPO/godot/$OUT"
if [[ "$EXT" == aab ]]; then
	jarsigner -verify "$APK"
else
	BT="$(ls -d "$SDK"/build-tools/* | tail -1)"
	"$BT/apksigner.bat" verify "$APK"
fi
echo "OK: $APK (version $VERSION, code $CODE, $PACKAGE, $(du -h "$APK" | cut -f1))"
