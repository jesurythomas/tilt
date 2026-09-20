# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

Last completed module: **M0b — Android toolchain** — complete, 2026-09-20
Branch: `feat/godot-port` (no upstream; nothing pushed)
Current module: **M1 — Core loop and input — IN PROGRESS, do not restart it.**

> **Read this before writing any code.** M1 is mid-flight, which is unusual for
> this file — it is normally rewritten only at a module *stop*.
>
> 1. **`docs/superpowers/plans/2026-09-20-m1-core-loop-and-input.md`** — the
>    approved 14-task plan. Tasks 1 and 2 are done and ticked; **resume at
>    Task 3** (`core/tuning.gd` + the parity harness). Its "Open questions"
>    section is already resolved — do not re-ask those.
> 2. **`godot/CONVENTIONS.md`** — normative, read in full. The five port laws
>    and the nine warnings-as-errors are machine-enforced.
> 3. **This file's *Open questions*** — one deferred decision is owed before
>    M3, not now. It is marked BLOCKER on M3 in `PORT-PROGRESS.md`.
>
> **The plan's code blocks are drafts, not gospel.** Two were wrong already —
> a `gdlint` member-order violation and a doc comment contradicting its own
> code. Diff every block against the TypeScript it cites before typing it in.

Verify the state you are inheriting before adding to it:

```bash
tools/run_tests.sh                                  # OK: 3/3, 7 tests passing
gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
```

Every command below was run fresh and passed. Nothing here is predicted or
assumed; every value was read off a command's output.

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

## Current module — M1, in progress

**M1 — Core loop and input.** The plan is written and approved:
`docs/superpowers/plans/2026-09-20-m1-core-loop-and-input.md` — 14 tasks.
**Tasks 1 and 2 are complete and committed, verified green 2026-09-20.
Tasks 3-14 remain — resume at Task 3 (`core/tuning.gd` + the parity harness),
which has not been started.** See *State* at the top for the read order and the
commands that verify what you are inheriting.

What landed, and the commit for each:

| | |
|---|---|
| `src/core/log.gd` + autoload, `tests/test_log.gd` | `55795d7` |
| `src/core/types.gd`, `tests/test_types.gd` | `bba32fe` |
| `tools/run_tests.sh` re-imports before GUT | `d784471` |

Two corrections the plan's own code blocks need, both already applied — expect
more of the same, so diff the plan against the TypeScript rather than typing it
in: the plan puts `const ABSENT` *before* the enums in `types.gd`, which
CONVENTIONS §2 forbids and `gdlint` rejects (`class-definitions-order`); and
its `types.gd` doc comment claimed every optional field takes `Types.ABSENT`,
which is not what its own code does (see the M3 blocker under *Open questions*).

It delivers `core/log.gd`, `core/types.gd` (ports `Types.ts`), `core/tuning.gd`
(ports `WeaponTuning.ts`), `tools/parity/`, `sim/vector_grid.gd`,
`sim/particle_engine.gd` (partial — only the surface `PlayerShip` calls),
`sim/player_ship.gd`, `input/tilt_input.gd` (ports `GyroscopeController.ts`),
`input/input_router.gd`, `input/touch_input.gd`, `core/game_state_machine.gd`,
`core/game_root.gd`, and the two render layers.

**M1 must replace `scenes/main.tscn`** — it is a scriptless `Node2D` placeholder
that exists only so M0b could export and launch something.

iOS is still deferred to M11 (D1, `PREREQUISITES.md` §3); it needs a macOS host.

### Four decisions taken 2026-09-20, before M1 started

Writing the M1 plan meant reading the TypeScript in full, which surfaced four
Law 5 stops. All four were put to the user and answered. They are binding —
**do not re-ask them**, and do not quietly implement the other branch.

1. **Physics runs at 120 Hz, not 60.** Spec §4.3 said 60 Hz; the TS substeps at
   1/120 s (`TiltGame.ts:1844`) and `VectorGrid.update()` **ignores its `dt`**
   (`VectorGrid.ts:45`), so 60 Hz would halve the grid's spring rate and shift
   `PlayerShip`'s acceleration smoothing. Now **spec D8**; §4.3 amended.
   `max_fps = 60` is unchanged — it caps rendering, not physics. The CPU cost
   is measured on device in M1's frame-rate pass.

2. **The grid is drawn unconditionally in M1, and M1's "grid reacts to motion"
   criterion is reinterpreted.** Nothing in M1's scope can disturb the grid:
   `applyExplosion` is only ever called by kills, weapons, death and the
   cinematic (all M2+), and player motion never touches the grid in the web
   game. `showGridlines` also defaults to `false` (`GameOptions.ts:88`). M1
   draws it anyway (`# TODO(M7)` to gate it) and proves the spring in a GUT
   spec. Spec §8 M1 amended.

3. **Both control schemes are verified in two device builds** — the committed
   `HYBRID` default for touch, then a one-line temporary flip to `GYRO` for
   tilt, reverted before the commit. They are mutually exclusive in the source
   (`GameOptions.ts:80`, `TiltGame.ts:1280`) and the toggle is M11's. No debug
   UI is invented.

4. **Execution is subagent-driven** (superpowers:subagent-driven-development),
   one implementer per task with a review between each.

### Two source findings recorded for later modules

- **`TiltRenderer.ts:144` passes a `CursorSkinConfig` where
  `PlayerShip.render` declares `shipSkin?: ShipSkinConfig`.** Almost certainly a
  real bug in the web game. Both are absent in M1 so nothing changes there.
  **Law 2 applies when M7/M8 land: raise it, do not silently fix it.**
- **There is a fourth `localStorage` key**, `tilt_gyro_calibration`
  (`GyroscopeController.ts:39`), which spec §2.2 had missed. Spec §2.2 and §4.6
  are amended. M1 writes `user://tilt_gyro_calibration.json` with the same
  `{beta, gamma}` shape straight through `FileAccess`, with a `# TODO(M7):`
  marking the `SaveStore` seam.

### A new `class_name` needs a project re-import — `run_tests.sh` now does it

Found in Task 2, and it will recur in every module that adds a class. Godot
registers `class_name` in `.godot/global_script_class_cache.cfg`, **which is
gitignored.** Until the project is re-imported the identifier does not exist:
`src/core/types.gd` passed `--check-only` on its own while `tests/test_types.gd`
failed with `Identifier "Types" not declared in the current scope`, and the
suite reported `collected 2 of 3`.

`tools/run_tests.sh` now runs `--headless --path godot --import` before GUT.
Verified by deleting the cache to simulate a fresh clone and re-running:
`OK: 3/3 scripts collected, all tests passed.` This cannot hide a real parse
error — `--import` is silent and exits 0 on one (CONVENTIONS §1.3), so the
collection check still catches it.

**If you see `Identifier "<Class>" not declared` anywhere else** — a manual
`--check-only`, an export, the editor — re-import first; it is almost never a
real error in the script you are looking at.

### One CONVENTIONS conflict, measured in Task 1

`CONVENTIONS.md` §2 makes `class_name` mandatory on every file. **An autoload
script cannot have one.** `src/core/log.gd` is autoloaded as `Log`; adding
`class_name Log` makes the class shadow the singleton, so `Log.min_level`
resolves against a `Nil` base and the suite fails with *"Invalid access to
property or key 'min_level' on a base object of type 'Nil'"*. Measured
2026-09-20 by adding the line, running `tools/run_tests.sh` (2 of 4 tests
failed) and reverting.

So `log.gd` carries no `class_name`, and a `# PORT-NOTE:` in the file says why.
**Do not "fix" that omission.** CONVENTIONS §2 should be amended to exempt
autoload scripts; it is reported here rather than edited unilaterally, per its
own preamble.

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
- ~~The 60 Hz vs 120 Hz physics tick.~~ **Resolved 2026-09-20: 120 Hz**, spec
  D8. See *Four decisions* above.
- ~~M1's "grid reacts to motion" acceptance criterion.~~ **Resolved
  2026-09-20**, spec §8 M1 amended. See *Four decisions* above.
- ~~How M1 verifies tilt and touch when the schemes are mutually exclusive.~~
  **Resolved 2026-09-20: two device builds.** See *Four decisions* above.
- ~~Does `Array[Types.Enemy]` compile?~~ **Resolved 2026-09-20: yes.** The M1
  Task 2 spike (`test_typed_array_of_inner_record_compiles_and_holds` in
  `godot/tests/test_types.gd`) declares `Array[Types.Enemy]`, appends an
  element and reads a typed field back. `OK: 3/3 scripts collected, all tests
  passed.` **Law 3 needs no amendment** and the records stay in one file.
- **The float optionals in `Types.Enemy` are not a faithful port yet — M3
  blocker.** `Types.ts` marks 17 `Enemy` fields optional. `types.gd` gives the
  id-like and enum-state ones `Types.ABSENT` (-1 can never be a real id or
  ordinal) but gives the numeric ones their natural zero, because **-1 is a
  legal angle, timer and scale** so ABSENT cannot serve there. That loses
  information `EnemySwarm.ts` actually reads:
  `if (e.targetAngle === undefined) e.targetAngle = targetAngle` (:300),
  `aimTimer === undefined → 1.1` (:339),
  `fireCooldown === undefined → 2.6 + rand*0.8` (:394),
  `orbitRadius === undefined → 38` (:463),
  `pulseTimer === undefined → 2.2` (:486). With a 0.0 default **none of those
  branches can ever fire.** Separately, `stealth_opacity` defaults to 1.0 here
  while the TypeScript fallback is `?? 0.65` (`EnemySwarm.ts:1517`).
  Nothing in M1 reads any of these fields, so M1 is unaffected and the port was
  left as the approved plan wrote it (Law 2: raise, do not silently fix).
  **Put to the user 2026-09-20 and deliberately deferred — do not re-ask
  whether to raise it, and do not quietly apply a fix in the meantime.** The
  decision owed is *which* representation, and it is owed **before M3 ports
  `EnemySwarm.ts`**, not before the next M1 task. The candidate on the table is
  `NAN` for the float optionals — `is_nan()` is then the exact `=== undefined`
  test and NAN is never a legal reading — costing ~12 initialisers in
  `src/core/types.gd`. Also carried as a BLOCKER line on M3 in
  `PORT-PROGRESS.md` and as `TODO(M3)` in `src/core/types.gd:27`.
- **Does Node 24 import `WeaponTuning.ts` directly?** The parity dumper relies
  on native type stripping. M1 Task 3 carries a `tsc` fallback. Unknown until
  that task runs.
