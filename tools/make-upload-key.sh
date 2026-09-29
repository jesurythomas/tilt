#!/usr/bin/env bash
# Makes the Play Store upload key: ~/.android/peril-upload.keystore and the env file
# ~/.android/peril-upload.env that tools/release.sh reads (PERIL_KEYS=...).
#
# It asks for the password twice, or reads PERIL_UPLOAD_PW when set. Then BACK UP both files somewhere
# off this machine: losing the upload key means a support request to Google to reset it.
# Never commit them.
#
# Usage:  tools/make-upload-key.sh
#         PERIL_UPLOAD_PW='...' tools/make-upload-key.sh   (no prompt, e.g. from the ! prefix)

set -euo pipefail

DIR="$HOME/.android"
STORE="$DIR/peril-upload.keystore"
ENVF="$DIR/peril-upload.env"
ALIAS="peril-upload"

if [[ -e "$STORE" || -e "$ENVF" ]]; then
	echo "FAIL: $STORE or $ENVF already exists; move it aside first." >&2
	exit 1
fi

if [[ -n "${PERIL_UPLOAD_PW:-}" ]]; then
	PW="$PERIL_UPLOAD_PW"
else
	read -r -s -p "Password for the new upload key (12+ chars): " PW
	echo
	read -r -s -p "Again: " PW2
	echo
	if [[ "$PW" != "$PW2" ]]; then
		echo "FAIL: passwords differ." >&2
		exit 1
	fi
fi
if [[ ${#PW} -lt 12 ]]; then
	echo "FAIL: password is shorter than 12 characters." >&2
	exit 1
fi

# 10000 days is about 27 years; Play requires the key to outlive 2033.
keytool -genkeypair -v -keystore "$STORE" -alias "$ALIAS" -keyalg RSA -keysize 2048 \
	-validity 10000 -storepass "$PW" -keypass "$PW" -dname "CN=Peril Point upload, O=JTG"

umask 077
{
	echo "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$STORE"
	echo "GODOT_ANDROID_KEYSTORE_RELEASE_USER=$ALIAS"
	echo "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$PW"
} >"$ENVF"

echo "OK: $STORE and $ENVF written. Back both up off this machine."
echo "Next: PERIL_AAB=1 PERIL_KEYS=$ENVF tools/release.sh"
echo "Upload key SHA-1 (for Firebase and Play):"
keytool -list -v -keystore "$STORE" -alias "$ALIAS" -storepass "$PW" | grep -E "SHA1|SHA-1"
