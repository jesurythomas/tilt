# Module 0b — Android Toolchain: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the verified M0 scaffold into a debug APK that installs and launches on a physical Android device, so that M1 can verify tilt axis mapping on real hardware.

**Architecture:** No game code. This module adds the smallest possible bootable main scene (Godot refuses to export without one), an Android export preset, and the verified build/install/launch command chain. The placeholder scene is replaced by `core/game_root.gd` in M1.

**Tech Stack:** Godot 4.7.2-stable · Temurin JDK 17.0.20.1 · Android SDK platform `android-37.0`, build-tools `36.0.0` · adb from `platform-tools`.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` §8, Module 0b

**Index:** `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md`

**Conventions (binding):** `godot/CONVENTIONS.md`

**Previous handoff:** `godot/HANDOFF.md` — read its "Three traps" section before running anything.

---

## Before you start

**The user-action part of this module is already done.** Verified 2026-09-20,
after M0 closed. Do not re-install anything; do not re-derive these.

| Requirement | Verified state |
|---|---|
| Export templates | `4.7.2.stable/` contains `android_debug.apk`, `android_release.apk` |
| `ANDROID_HOME` | `C:\Users\Jesury\AppData\Local\Android\Sdk` — **now exists** |
| Android platform | `android-37.0` |
| Build-tools | `36.0.0` |
| JDK | Temurin **17.0.20.1** at `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot` |
| Godot `export/android/java_sdk_path` | points at that Temurin 17 |
| Godot `export/android/android_sdk_path` | points at the SDK above |
| Debug keystore | `C:/Users/Jesury/AppData/Roaming/Godot/keystores/debug.keystore`, pass `android`, both already in **Editor Settings** |
| adb | `…/Sdk/platform-tools/adb.exe` |
| Device | **SM_A556E** (Galaxy A55), connected over adb-tls (wireless) |

**Two traps carried over from M0** (`HANDOFF.md`):

- `--quit` is unusable as any kind of check. Use `--import`.
- A modal `ALERT!` blocks forever under `--headless` when there is no main
  scene. **Task 1 removes that condition**, which is a second reason it comes
  first.

**PATH `java` is OpenJDK 25, not 17.** This is harmless — Godot uses its
configured `java_sdk_path`, not `PATH`. If a Gradle build ever misbehaves, check
this mismatch first. Do not "fix" it by changing `PATH`; nothing here reads it.

**One task needs you at the keyboard.** Task 2 adds the export preset through
the editor's Export dialog. As in M0 Task 2, the plan then verifies your work by
reading the file back.

---

## Global Constraints

See the index's Global Constraints section — all of it applies. The ones that bite here:

- **Godot is not on PATH.** Every command assumes:
  ```bash
  GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
  ```
  Use the `_console` variant.
- **Orientation: landscape** (D2). Already set in `project.godot` as the engine default; the export preset must not contradict it.
- **Targets: Android + iOS — but iOS is deferred to M11** (D1, `PREREQUISITES.md` §3). This module is Android-only. Do not add an iOS preset.
- **Keystore credentials must not be committed.** Spec §8 M0b. `export_presets.cfg` is tracked; the debug keystore path and password live in **Editor Settings**, which is outside the repo. Leave the preset's keystore fields empty so Godot falls back to Editor Settings. **Never paste a password into `export_presets.cfg`.**
- **Commits:** one line, imperative, ≤72 chars, no trailers, prefixed `M0b:`.
- **Law 4 — nothing new.** This module creates exactly the files listed below.
- **Law 5 — stop, do not guess.** If a command's output differs from what this plan predicts, stop and report. M0 hit three plan-versus-reality mismatches; expect more.

---

## File Structure

| Path | Responsibility |
|---|---|
| `godot/scenes/main.tscn` | Placeholder boot scene. Exists only so the project can export and launch. **Replaced in M1** by the real `game_root` scene. |
| `godot/project.godot` | **Modified** — gains `run/main_scene`. |
| `godot/export_presets.cfg` | **Created via the editor.** Android debug preset. Tracked; contains no secrets. |
| `godot/.gitignore` | **Created** — keeps built APKs out of the repo. |
| `godot/PORT-PROGRESS.md` | **Modified** — M0b ticked by the exit protocol. |
| `godot/HANDOFF.md` | **Rewritten** at module stop. |

**Interfaces**

- *Consumes from M0:* `$GODOT`, the verified GUT and gdtoolkit commands, and a project that rejects untyped GDScript.
- *Produces, for M1:*
  - `res://scenes/main.tscn` — the boot scene M1 replaces with `game_root.tscn`.
  - `EXPORT_CMD` — the verified headless APK build, recorded in `HANDOFF.md`.
  - `ADB` — the verified adb path, recorded in `HANDOFF.md`.
  - A device confirmed to install and run the build.

---

## Decided: package name

```
com.jtg.perilpoint
```

Chosen by the user 2026-09-20, who also set the app label to **Peril Point**. Valid: three lowercase segments, each starting
with a letter, and not `com.example.*` (which the Play Store rejects).

**This is permanent in practice once published.** It is the app's identity on
every device and on the Play Store; changing it after release means a new
listing and no upgrade path for installed users. It is cost-free to change
**now** — it lives in exactly two places, `export_presets.cfg` and the installed
APK, and changing it before first publication costs one edit plus an
`adb uninstall`. Revisit it before M11's release build, not after.

---

## Task 1: A scene the app can boot into

Godot cannot export a project with no main scene, and an APK without one cannot
satisfy this module's "launches" criterion. This is the minimum that makes the
acceptance test possible — not a game feature.

**Files:**
- Create: `godot/scenes/main.tscn`
- Modify: `godot/project.godot`
- Create: `godot/.gitignore`

- [ ] **Step 1: Confirm the project currently has no main scene**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
grep -n "main_scene" godot/project.godot || echo "  no main scene set"
```

Expected: `no main scene set`.

- [ ] **Step 2: Create the placeholder scene**

Write `godot/scenes/main.tscn`. A bare `Node2D` and nothing else — no script,
because a script here would be game code this module is not allowed to write.

```
[gd_scene format=3]

[node name="Main" type="Node2D"]
```

- [ ] **Step 3: Point the project at it**

Add `run/main_scene` to the `[application]` section of `godot/project.godot`,
directly below `run/max_fps=60`:

```ini
run/main_scene="res://scenes/main.tscn"
```

This key is hand-written deliberately, unlike M0 Task 2's six settings: the key
name is now known and the value is verified two ways in Step 4 — by querying
`ProjectSettings` and, later, by the APK actually launching.

- [ ] **Step 4: Verify the engine agrees**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
timeout 120 "$GODOT" --headless --path godot --import; echo "exit=$?"
```

Expected: **`exit=0`**.

Then confirm the setting resolved — note this run uses `--quit`, which is safe
**only now** that a main scene exists:

```bash
timeout 120 "$GODOT" --headless --path godot --quit; echo "exit=$?"
```

Expected: **`exit=0`** and **no hang**. If it hangs, the main scene did not take
— kill it, and stop and report. Do not retry with a longer timeout.

- [ ] **Step 5: Keep build output out of the repo**

Create `godot/.gitignore`:

```
# Build output — never commit an APK
build/
*.apk
*.aab
*.idsig
```

- [ ] **Step 6: Confirm the suite is still green**

A main scene must not disturb the tests.

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
timeout 120 "$GODOT" --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Expected: **Scripts 1 / Tests 1 / Passing 1**, `All tests passed!`.
Per `HANDOFF.md` trap 3, read those counts — do not trust the exit code alone.

- [ ] **Step 7: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git add godot/scenes/main.tscn godot/project.godot godot/.gitignore
git commit -m "M0b: add placeholder boot scene so the project can export"
```

---

## Task 2: Android export preset

**Needs you at the keyboard.** Godot has no CLI to create an export preset.

**Files:**
- Create: `godot/export_presets.cfg` (written by the editor)

- [ ] **Step 1: Confirm no preset exists**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
ls godot/export_presets.cfg 2>&1
```

Expected: `No such file or directory`.

- [ ] **Step 2: Add the preset in the editor**

```bash
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --path /c/Users/Jesury/Documents/Personal/dread-flock/godot --editor
```

**Project → Export… → Add… → Android.** Set exactly these and nothing else:

| Field | Value |
|---|---|
| Name | `Android` |
| Runnable | **on** |
| Options → Package → Unique Name | `com.jtg.perilpoint` |
| Options → Package → Name | `Peril Point` |

Leave everything else at its default. In particular:

- **Do not** fill the Keystore → Debug fields. They are already set globally in
  Editor Settings, and anything typed here lands in a tracked file.
- **Do not** enable "Use Gradle Build". It is not needed for a debug APK and
  pulls in a much longer, more fragile toolchain.
- **Do not** change orientation here — `project.godot` already governs it.

Watch the dialog's bottom panel. If it shows an error in red, **stop and report
it verbatim** rather than working around it.

Close the dialog, then close the editor.

- [ ] **Step 3: Verify by reading the file back, and check for secrets**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
cat godot/export_presets.cfg
```

Confirm by eye: a preset named `Android`, `platform="Android"`, the agreed
package name, `runnable=true`.

Then the security gate — this must print nothing:

```bash
grep -niE "password|keystore.*=.*[^\"]\"[^\"]+\"" godot/export_presets.cfg \
  | grep -viE '=\s*""' || echo "  no credentials present"
```

Expected: `no credentials present`. **If any password or keystore path has a
non-empty value, stop.** Clear it in the editor before continuing; do not commit
and fix later, because the value would remain in git history.

- [ ] **Step 4: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git add godot/export_presets.cfg
git commit -m "M0b: add android debug export preset without credentials"
```

---

## Task 3: Build a debug APK headless

**Files:** none tracked — output goes to the ignored `godot/build/`.

- [ ] **Step 1: Build**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
mkdir -p godot/build
timeout 600 "$GODOT" --headless --path godot --export-debug "Android" build/tilt-to-live-debug.apk
echo "exit=$?"
```

The preset name in quotes must match Task 2 Step 2 exactly.

Expected: **`exit=0`**.

**Do not trust the exit code by itself** — M0 found two Godot commands that
report 0 while failing. Step 2 is the real check.

- [ ] **Step 2: Verify an APK actually exists and is plausible**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
ls -la godot/build/tilt-to-live-debug.apk
```

Expected: a file of **at least several MB**. A zero-byte or missing file means
the export failed regardless of exit code.

Confirm it is a real APK (zip) containing the Android manifest:

```bash
unzip -l godot/build/tilt-to-live-debug.apk | grep -E "AndroidManifest|classes.dex|libgodot" | head
```

Expected: `AndroidManifest.xml` and at least one `.so` or `classes.dex` entry.
If `unzip` is unavailable, skip this and rely on Task 4 — an install failure
will expose a bad APK anyway.

- [ ] **Step 3: Confirm the APK is not tracked**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git status --short
```

Expected: **no** `build/` or `.apk` entries. If any appear, Task 1 Step 5's
`.gitignore` is wrong — fix it before committing anything.

- [ ] **Step 4: Commit**

Nothing to commit if the tree is clean. That is the expected outcome; say so
rather than inventing a change.

---

## Task 4: Install and launch on the device

This is the module's actual acceptance criterion.

- [ ] **Step 1: Confirm the device is still connected**

```bash
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"
"$ADB" devices -l
```

Expected: one device in state `device` (**not** `unauthorized` or `offline`).

The connection is wireless adb-tls and **does not survive a device reboot or a
Wi-Fi change**. If the list is empty, ask the user to reconnect rather than
guessing at pairing commands.

- [ ] **Step 2: Install**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"
timeout 300 "$ADB" install -r godot/build/tilt-to-live-debug.apk
echo "exit=$?"
```

Expected: `Success` and **`exit=0`**.

If it fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, a build signed with a
different key is already installed. Uninstall it first —
`"$ADB" uninstall com.jtg.perilpoint` — then repeat this step.

- [ ] **Step 3: Launch, with the log clean beforehand**

```bash
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"
PKG="com.jtg.perilpoint"
"$ADB" logcat -c
"$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
```

Expected: `Events injected: 1`.

- [ ] **Step 4: Prove it is actually running, not crashed**

`monkey` reports success merely for dispatching the intent. It is not evidence
the app survived.

```bash
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"
PKG="com.jtg.perilpoint"
"$ADB" shell pidof "$PKG"; echo "pidof exit=$?"
```

Expected: **a process id** and `exit=0`. An empty result means it launched and
died — that is a failure, and the module is not done.

Then read what Godot itself said:

```bash
"$ADB" logcat -d -s godot AndroidRuntime | tail -30
```

Expected: Godot startup lines and **no** `FATAL EXCEPTION` / `E AndroidRuntime`.

- [ ] **Step 5: Confirm orientation on the physical screen**

Landscape is D2 and is the one thing here a log cannot prove. **Look at the
device.** The app must be in landscape, regardless of how the phone is held.

If it is portrait, `display/window/handheld/orientation` did not survive the
export — stop and report; do not patch the preset to compensate.

- [ ] **Step 6: Record what you observed**

No commit. Carry these into the exit protocol: the APK size, the launch pid,
and whether orientation was correct on the device.

---

## Task 5: Module exit protocol

`CONVENTIONS.md` §9. All five steps, in order. Do not skip step 5.

- [ ] **Step 1: Verify — run every acceptance command and read the output**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"

echo "--- project loads ---"
timeout 120 "$GODOT" --headless --path godot --import >/dev/null 2>&1; echo "exit=$?"

echo "--- GUT suite (read the counts, not the exit code) ---"
timeout 120 "$GODOT" --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 \
  | grep -E "Scripts|Tests|Passing|All tests passed|ERROR"

echo "--- lint ---"
gdlint godot/tests; echo "exit=$?"

echo "--- format check ---"
gdformat --check godot/tests; echo "exit=$?"

echo "--- APK present ---"
ls -la godot/build/tilt-to-live-debug.apk

echo "--- no credentials in tracked preset (expect none) ---"
grep -niE "password" godot/export_presets.cfg | grep -viE '=\s*""' || echo "  none"

echo "--- app alive on device ---"
"$ADB" shell pidof com.jtg.perilpoint; echo "pidof exit=$?"

echo "--- working tree (expect clean, and no .apk) ---"
git status --short
```

Every one must pass. If any fails, **the module is not done**.

- [ ] **Step 2: Commit any remaining changes**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git add -A
git commit -m "M0b: complete android toolchain with device-verified apk" || echo "nothing to commit"
git log --oneline -1
```

- [ ] **Step 3: Tick `godot/PORT-PROGRESS.md`**

Tick M0b, record the date and commit SHA, change each `--` bullet to `ok`, and
append the observed APK size and device model.

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git add godot/PORT-PROGRESS.md
git commit -m "M0b: mark android toolchain module complete"
```

- [ ] **Step 4: Rewrite `godot/HANDOFF.md`**

Keep M0's "Three traps" section — it stays true and M1 needs it. Add:

- the verified `EXPORT_CMD` and `ADB` path
- the agreed package name
- the device model, and that adb here is **wireless and drops on reboot**
- that `scenes/main.tscn` is a placeholder **M1 must replace**
- that `java` on PATH is 25 while Godot uses its configured 17

```bash
git add godot/HANDOFF.md
git commit -m "M0b: record verified export and device commands in handoff"
```

- [ ] **Step 5: STOP and report**

Do **not** begin M1. Report:

- each acceptance command and what it returned
- the APK size and where it was written
- the device model, the launch pid, and that orientation was confirmed by eye
- that `scenes/main.tscn` is a placeholder M1 replaces
- anything that surprised you

Then wait.

---

## Self-Review

**Spec coverage (§8, Module 0b).** Export templates, JDK, SDK, `ANDROID_HOME`,
editor Java/SDK paths and the debug keystore were all verified already and are
recorded in *Before you start* rather than given tasks — re-doing them would be
busywork. Export preset → Task 2. "Keystore credentials must not be committed" →
Task 2 Step 3's grep gate plus Task 1 Step 5's `.gitignore`. "A debug APK builds,
installs and launches on a physical device" → Tasks 3 and 4.

**Deviation from spec §8, recorded deliberately.** The spec does not mention a
main scene, but Godot cannot export without one and "launches" cannot be tested
without one. Task 1 adds the smallest possible placeholder — a scriptless
`Node2D` — and flags it in three places as M1's to replace. The alternative,
dropping the "launches" criterion, would leave the toolchain unproven until M1
and defeat the point of the module.

**Placeholder scan.** None remain. The package name was the only open value and
is now fixed at `com.jtg.perilpoint` in the *Decided* section and in every command
that uses it.

**Type consistency.** No code interfaces. The named artefacts `$GODOT`, `ADB`,
`EXPORT_CMD` and the preset name `Android` are used identically in Tasks 2–5 and
in `HANDOFF.md`.

**Known risk not designed around.** Task 3 may fail if Godot decides this export
needs the Gradle build template. The plan deliberately does not pre-empt that
with `--install-android-build-template`: it would add a large, slow dependency
on a guess. If it happens, Law 5 applies — stop and report the actual error.
