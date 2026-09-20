# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

Last completed module: **M0b — Android toolchain** — complete, 2026-09-20
Branch: `feat/godot-port`
Next module: **M1 — Core loop and input** (nothing blocks it)

Every command below was run fresh at module close and passed. Nothing here is
predicted or assumed; every value was read off a command's output.

## App identity

| | |
|---|---|
| Package | `com.jtg.perilpoint` |
| Label | **Peril Point** |
| `config/name` in `project.godot` | `Peril Point` |

**The project was renamed to Peril Point on 2026-09-20, and the rename is done.**
It covered `config/name`, the spec, the plan index, `CONVENTIONS.md`, the README
and this file; the spec and index files were themselves renamed to
`2026-09-20-peril-point-godot-port-*.md`.

**What deliberately did *not* change, and must not:** the source web game keeps
the name *Tilt to Live* — `web/src/tilt-to-live/`, every TypeScript filename
(`TiltGame.ts`, `TiltAudio.ts`, …) and every `# PORT:` citation. Law 1 requires
those citations to resolve, so renaming them would break traceability for the
whole port. `archive/` is historical and was left untouched. Read "Tilt to Live"
anywhere in this repo as *the source codebase*, never as the product.

## How to verify right now

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"

# project loads                                          expect exit 0
"$GODOT" --headless --path godot --import

# GUT suite — ALWAYS via the wrapper, never gut_cmdln.gd directly
# expect "OK: 1/1 scripts collected, all tests passed."   and exit 0
tools/run_tests.sh

# lint / format                expect "no problems" / "left unchanged"
gdlint godot/tests
gdformat --check godot/tests

# build a debug APK                                      expect exit 0
"$GODOT" --headless --path godot --export-debug "Android" build/peril-point-debug.apk

# install and launch
"$ADB" -s RRCXB04L8EJ install -r godot/build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1
"$ADB" -s RRCXB04L8EJ shell pidof com.jtg.perilpoint     # a pid = it survived startup
```

## Toolchain facts

| Thing | Value |
|---|---|
| Godot | `4.7.2.stable.official.ed1daf0bf` — **not on PATH**, use the path above |
| GUT | **9.6.1** vendored at `godot/addons/gut/` |
| gdtoolkit | **4.5.0**, `gdformat` and `gdlint` on PATH |
| JDK | Temurin **17.0.20.1**, set as Godot's `export/android/java_sdk_path` |
| Android SDK | `C:\Users\Jesury\AppData\Local\Android\Sdk`, platform `android-37.0`, build-tools `36.0.0` |
| Device | **SM_A556E** (Galaxy A55), serial `RRCXB04L8EJ` |
| Last APK | 29,759,129 bytes, `godot/build/` (gitignored) |

Always use the `_console` variant of the Godot exe.

**`java` on PATH is OpenJDK 25, not 17.** Harmless — Godot uses its configured
`java_sdk_path`. If a Gradle build ever misbehaves, check this first. Do not
"fix" `PATH`; nothing in this project reads it.

## adb: two transports, always pass `-s`

The phone is usually visible **twice** — once over USB (`RRCXB04L8EJ`) and once
over wireless adb-tls. Plain `adb install` then fails as ambiguous. **Always
pass `-s RRCXB04L8EJ`.**

The wireless link **drops on reboot, sleep or a Wi-Fi change** and it did drop
mid-module. USB is the reliable path: plug in, accept the prompt. If neither
shows in `adb devices`, ask the user to reconnect — do not guess at pairing
commands.

## Four traps, all hit and verified

**1. `--quit` was unusable, and now is not.** It exits **0** for any directory
that exists, even with no `project.godot`, so it cannot fail for the right
reason — prefer `--import`, which exits 1 on a directory with no project.
Its other defect is **fixed**: with no main scene, Godot 4.7.2 used to open a
modal `ALERT!` **even under `--headless`** and block forever. M0b added a main
scene, and `--quit` now returns 0 promptly. Confirmed after the change.

**2. `--import` is silent about script errors.** It proves the *project* loads,
not that any GDScript compiles — a file with a fatal parse error produced no
output and exit 0. To check one script:
`"$GODOT" --headless --path godot --check-only -s <path/to.gd>` (exits 1, prints
the parse error).

**3. GUT exits 0 when a test script fails to parse — now guarded.** It logs
`Ignoring script ... because it does not extend GutTest` (misleading — the parse
failed, so the base class was never seen) and continues without that script.
Reproduced with two scripts, one with a typing violation: GUT printed
`All tests passed!` and exited **0** while that spec never ran.

**Fixed by `tools/run_tests.sh`** (CONVENTIONS §1.3), which asserts that the
`Scripts` count GUT reports equals the number of `test_*.gd` files on disk.
Verified green → red → green against exactly that two-script case.

**Always run the suite with `tools/run_tests.sh`.** Calling `gut_cmdln.gd`
directly reopens the hole. GUT's exit code *is* reliable for ordinary assertion
failures — a failing `assert` gives exit 1, verified — the gap was collection
only.

**4. `monkey` reporting `Events injected: 1` is not proof the app runs.** It only
means an intent was dispatched; the app can die immediately after. Use
`adb shell pidof <pkg>` — a pid is the evidence.

**But `pidof` races the launch.** Run immediately after `monkey` it returns
empty and exit 1 on a perfectly healthy app — observed, and briefly mistaken for
a regression. Godot needs a few seconds to reach `OnGodotMainLoopStarted`. Give
it ~5s, or retry, before concluding anything. An empty `pidof` is only evidence
of a crash if it is still empty after the app has had time to start **and** the
log shows a failure.

## Verified project.godot keys

Godot omits any setting left at its default, so the file is shorter than the set
of things that are in force. All values confirmed by querying `ProjectSettings`
at runtime, not by reading the file.

```ini
[application]
config/name="Peril Point"
run/main_scene="res://scenes/main.tscn"
run/max_fps=60
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="mobile"
textures/vram_compression/import_etc2_astc=true
[debug]
gdscript/warnings/{untyped_declaration,inferred_declaration,unsafe_call_argument,
  unsafe_method_access,unsafe_property_access,unsafe_cast,shadowed_variable,
  unused_variable}=2
```

`import_etc2_astc` was added **by Godot itself** during the first Android export;
it is required for mobile texture compression and was committed deliberately.

Correct but **absent because they are already the Godot 4.7.2 default**:

| Setting | Effective | Note |
|---|---|---|
| `display/window/handheld/orientation` | `0` | Index 0 is **Landscape**, confirmed from the property's hint string |
| `display/window/stretch/mode` | `disabled` | spec §4.1, load-bearing |
| `debug/gdscript/warnings/unsafe_void_return` | `2` | already Error by default — so all **nine** required warnings are Error, though only eight appear in the file |

Severity encodes `0=Ignore, 1=Warn, 2=Error`. `exclude_addons` returns `<null>`
— that key does not exist in 4.7.2. GUT's vendored code loads fine anyway.

## Device evidence from the M0b launch

- `Godot Engine v4.7.2.stable` / `Vulkan 1.3.279 - **Forward Mobile** - Samsung
  Xclipse 530` — proves `rendering_method="mobile"` reached the device
- `OnGodotSetupCompleted`, `OnGodotMainLoopStarted`, no `FATAL EXCEPTION`
- **Landscape confirmed:** `cur=2340x1080`, `mBounds=Rect(0, 0 - 2340, 1080)`,
  `land`, `mCurrentRotation=ROTATION_90`, and `deepestLastOrientationSource` is
  our own `GodotAppLauncher` activity — the app forces it, it is not the sensor
- The `set_script` error seen in the **first** export log **does not
  reproduce**. A full clean export was captured and grepped afterwards: no
  occurrence. It was a cold-cache artifact of the very first export after GUT
  was vendored. Closed, not carried forward.
- The export does log one real error: **`No project icon specified`** — see
  Open questions.

## Export preset

`godot/export_presets.cfg` is tracked and contains **no keystore path and no
password** — Godot omits those keys entirely when they live in Editor Settings,
which is where the debug keystore is. Keep it that way: a password committed and
later removed still lives in git history. `gradle_build/use_gradle_build=false`;
architectures are **arm64-v8a only**.

## Next module

**M1 — Core loop and input.** Nothing blocks it. Per the index it needs
`core/types.gd` (ports `Types.ts`), `core/tuning.gd` (ports `WeaponTuning.ts`),
`core/log.gd`, and `tools/parity/`. Its acceptance requires tilt verification on
the physical device, which is now possible.

**M1 must replace `scenes/main.tscn`** — it is a scriptless `Node2D` placeholder
that exists only so M0b could export and launch something.

iOS is still deferred to M11 (D1, `PREREQUISITES.md` §3); it needs a macOS host.

## Open questions

- ~~Is "Peril Point" a full rename or only the Android label?~~ **Resolved
  2026-09-20: full rename, done in one pass.** See *App identity* above for what
  changed and what deliberately did not.
- ~~The GUT collection-failure gap.~~ **Closed 2026-09-20** by
  `tools/run_tests.sh` (CONVENTIONS §1.3), verified green → red → green.
- ~~The `set_script` export error.~~ **Closed 2026-09-20** — does not reproduce
  on a clean export; a first-run cache artifact.
- **The app has no icon.** Every Android export logs
  `ERROR: No project icon specified. Please specify one in the Project Settings
  under Application -> Config -> Icon`, and the APK ships Godot's default robot.
  Not fixed here: supplying one is an art decision, not a port decision, and
  Law 4 forbids inventing assets. Harmless for M1-M10 device testing. **Must be
  resolved before M11's release build.**
