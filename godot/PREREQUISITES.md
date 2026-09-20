# Prerequisites — read this before Module 0

Everything you must install or do **by hand** before the port can proceed.
Nothing here can be automated: the downloads are large, several require GUI
installers, and two require physical hardware.

Status verified on this machine **2026-09-20**. Re-run §5 to re-check.

---

## 1. What you already have

Nothing to do for these.

| Requirement | Found | Used by |
|---|---|---|
| Godot | `4.7.2.stable.official.ed1daf0bf` | everything |
| Python | 3.13.1 | gdtoolkit |
| pip | 24.3.1 | gdtoolkit |
| Node | v24.14.0 | audio bake (M5), parity harness (M1) |
| npm | 11.9.0 | the `web/` game |
| Git | 2.44.0.windows.1 | everything |
| Free disk | 499 GB | ~6 GB needed |

**Godot is not on `PATH`.** It lives at:

```
C:\Users\Jesury\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
```

Every command in the plans uses the `_console` variant deliberately — the plain
`.exe` detaches from the shell, so you see no output and get no usable exit
code. Adding the folder to `PATH` is optional; the plans work without it.

---

## 2. What is missing

| Requirement | Status | Blocks |
|---|---|---|
| gdtoolkit (`gdformat`, `gdlint`) | not installed | **Module 0** |
| Godot export templates | directory **empty** | Module 0b |
| OpenJDK 17 | **absent from the entire disk** | Module 0b |
| Android SDK | **absent** — `C:\Program Files\Android` is an empty leftover folder | Module 0b |
| `ANDROID_HOME` | set to `C:\Users\Jesury\AppData\Local\Android\Sdk`, **which does not exist** | Module 0b |
| adb | absent (arrives with the SDK) | Module 0b |
| A physical Android device | unknown | M1 onward |

---

## 3. iOS cannot be built on this machine

Godot's official 4.7 documentation is explicit: exporting for iOS **requires a
macOS computer with Xcode installed**. There is no Windows path to an iOS build
— not with Godot, not with any workaround.

The spec targets Android **and** iOS. Android is fully achievable here. iOS is
deferred until you have one of:

- a Mac (or a Mac VM you are licensed to run), or
- a macOS CI runner — GitHub Actions and Codemagic both offer these.

**This does not block anything before Module 11.** Modules 0b–10 are Android-only
and the GDScript is identical for both platforms. Plan for it, don't wait on it.

---

## 4. What to install, in order

### Step 1 — gdtoolkit *(1 minute, ~10 MB)* — **required for Module 0**

```bash
pip install "gdtoolkit==4.*"
gdlint --version
gdformat --version
```

Both must print a 4.x version. If the commands are not found afterwards, pip
installed to a directory outside `PATH` — find it with
`python -m site --user-base` and add its `Scripts` folder to `PATH`.

> **This is the only install Module 0 needs.** You can stop here, run Module 0,
> and come back for the rest.

---

Everything below is for **Module 0b** and can wait.

### Step 2 — Godot export templates *(~15 minutes, ~1 GB)*

Open the Godot editor:

```bash
"/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" \
  --path /c/Users/Jesury/Documents/Personal/dread-flock/godot --editor
```

Then **Editor → Manage Export Templates → Download and Install**.

The version must match the editor exactly — `4.7.2.stable`. A mismatched
template set fails at export time with a confusing error.

### Step 3 — OpenJDK 17 *(~5 minutes, ~200 MB)*

Godot 4.7 requires **OpenJDK 17** specifically. Not 21, not 11.

Install [Eclipse Temurin JDK 17](https://adoptium.net/temurin/releases/?version=17)
(Windows x64 `.msi`). During setup, enable **"Set JAVA_HOME variable"**.

Verify in a **new** terminal:

```bash
java -version    # expect: openjdk version "17.x.x"
echo "$JAVA_HOME"
```

### Step 4 — Android SDK *(~30 minutes, ~4 GB)*

Easiest route is [Android Studio](https://developer.android.com/studio) — it
installs the SDK and `adb`, and creates the debug keystore for you.

If you prefer the smaller command-line-only install, download
**cmdline-tools** from the same page and run:

```bash
sdkmanager --sdk_root=<android_sdk_path> "platform-tools" "build-tools;35.0.1" "platforms;android-35" "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;28.1.13356709"
```

These package versions come from the Godot 4.7 docs and are **not**
interchangeable — Godot checks for these specific build-tools, platform and NDK
versions.

### Step 5 — Fix `ANDROID_HOME` *(1 minute)*

It currently points at a directory that does not exist. Set it to wherever
Step 4 actually installed the SDK — with Android Studio's defaults that is:

```
C:\Users\Jesury\AppData\Local\Android\Sdk
```

Set it via **System Properties → Environment Variables**, then verify in a
**new** terminal:

```bash
ls "$ANDROID_HOME/platform-tools/adb.exe"   # must exist
adb --version
```

### Step 6 — Point Godot at both SDKs *(2 minutes)*

In the Godot editor: **Editor → Editor Settings → Export → Android**.

| Field | Value |
|---|---|
| Java SDK Path | your `JAVA_HOME` from Step 3 |
| Android SDK Path | your `ANDROID_HOME` from Step 5 |

### Step 7 — Debug keystore *(1 minute)*

Android Studio creates `~/.android/debug.keystore` automatically. Check first:

```bash
ls ~/.android/debug.keystore
```

If it is missing, generate it — Step 3's JDK provides `keytool`:

```bash
cd ~/.android
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
  -keystore debug.keystore -storepass android \
  -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
```

> **Never commit a keystore or its password.** `export_presets.cfg` is tracked
> in git; release credentials are supplied by environment variable at export
> time. The debug keystore's `android`/`android` password is a published
> Android convention and is not a secret, but the file still stays out of the
> repository.

### Step 8 — A physical Android device *(5 minutes)*

You need real hardware. An emulator cannot validate the two things Module 1
exists to prove: **accelerometer behaviour in landscape**, and **real GPU cost**.

On the phone: **Settings → About phone → tap "Build number" seven times** to
unlock Developer Options, then **Developer Options → USB debugging → on**.

Connect by USB and accept the debugging prompt. Verify:

```bash
adb devices     # your device must appear, listed as "device" not "unauthorized"
```

---

## 5. Verify everything

Run this after finishing the steps above. It checks each prerequisite
independently and prints a clear verdict.

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

echo "--- Module 0 prerequisites ---"
"$GODOT" --version                               || echo "FAIL: godot"
gdlint --version                                 || echo "FAIL: gdlint"
gdformat --version                               || echo "FAIL: gdformat"

echo "--- Module 0b prerequisites ---"
[ -n "$(ls -A ~/AppData/Roaming/Godot/export_templates 2>/dev/null)" ] \
  && echo "ok: export templates present" || echo "FAIL: export templates empty"
java -version 2>&1 | head -1                     || echo "FAIL: no jdk"
[ -d "$ANDROID_HOME" ] \
  && echo "ok: ANDROID_HOME -> $ANDROID_HOME" || echo "FAIL: ANDROID_HOME missing or wrong"
adb --version 2>/dev/null | head -1              || echo "FAIL: no adb"
ls ~/.android/debug.keystore 2>/dev/null         || echo "FAIL: no debug keystore"
adb devices 2>/dev/null | tail -n +2 | grep -w device \
  && echo "ok: device connected" || echo "FAIL: no authorised device"
```

Any `FAIL` on a Module 0 line blocks Module 0. Any `FAIL` on a Module 0b line
blocks Module 0b and therefore M1 onward.

---

## 6. Manual vs automated, per module

Knowing which steps need you at the keyboard makes it easier to judge what a
session will cost.

| Module | Needs you | What exactly |
|---|---|---|
| **0** | yes, twice | Open the Godot editor to set six Project Settings (Task 2) and the nine GDScript warnings (Task 4). Neither can be scripted — they are GUI dialogs. |
| **0b** | yes, throughout | All of §4 Steps 2–8 above. |
| **1** | yes, briefly | Hold the phone and confirm tilt steers the right way in landscape. |
| **2–10** | occasional | Device smoke pass at the end of each: install, play ~60 seconds, watch frame time. |
| **11** | yes | Release signing; and the iOS half needs a Mac (§3). |

Everything else — writing GDScript, running GUT, linting, committing, updating
`PORT-PROGRESS.md` and `HANDOFF.md` — is automated.
