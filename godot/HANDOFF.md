# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

Last completed module: **M1 — Core loop and input** — complete, 2026-09-20
Branch: `feat/godot-port` (no upstream; nothing pushed)
Next module: **M2 — Vertical slice** — not started.

M1 is complete. All 14 tasks were executed, verified against the TypeScript source, tested headless (11/11 test scripts, 64/64 tests, 300 asserts passing), linted/formatted, and accepted on a physical Samsung Galaxy A55 (`SM_A556E`).

## How to verify right now

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"

# 1. GUT suite — ALWAYS via the wrapper, never gut_cmdln.gd directly
# expect "OK: 11/11 scripts collected, all tests passed." (64 tests, 300 asserts)
tools/run_tests.sh

# 2. lint / format check       expect "no problems" / "24 files left unchanged"
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests

# 3. render scripts syntax check                         expect exit 0
"$GODOT" --headless --path godot --check-only -s src/render/grid_layer.gd -s src/render/entity_layer.gd

# 4. build a debug APK                                   expect exit 0
"$GODOT" --headless --path godot --export-debug "Android" build/peril-point-debug.apk

# 5. install and launch on device (pass -s RRCXB04L8EJ)
"$ADB" -s RRCXB04L8EJ install -r godot/build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1
"$ADB" -s RRCXB04L8EJ shell pidof com.jtg.perilpoint     # a pid = it survived startup
```

Every command above was run fresh and passed. Nothing here is predicted or assumed.

## App identity

| | |
|---|---|
| Package | `com.jtg.perilpoint` |
| Label | **Peril Point** |
| `config/name` in `project.godot` | `Peril Point` |

**The project was renamed to Peril Point on 2026-09-20, and the rename is done.**
The source web game keeps the name *Tilt to Live* — `web/src/tilt-to-live/`, every TypeScript filename (`TiltGame.ts`, `TiltAudio.ts`, …) and every `# PORT:` citation. Law 1 requires those citations to resolve, so renaming them would break traceability for the whole port. Read "Tilt to Live" anywhere in this repo as *the source codebase*, never as the product.

## Toolchain facts

| Thing | Value |
|---|---|
| Godot | `4.7.2.stable.official.ed1daf0bf` — **not on PATH**, use the path above |
| GUT | **9.6.1** vendored at `godot/addons/gut/` |
| gdtoolkit | **4.5.0**, `gdformat` and `gdlint` on PATH |
| JDK | Temurin **17.0.20.1**, set as Godot's `export/android/java_sdk_path` |
| Android SDK | `C:\Users\Jesury\AppData\Local\Android\Sdk`, platform `android-37.0`, build-tools `36.0.0` |
| Device | **SM_A556E** (Galaxy A55), serial `RRCXB04L8EJ` |
| Last APK | 29,776,339 bytes, `godot/build/` (gitignored) |

Always use the `_console` variant of the Godot exe.
**`java` on PATH is OpenJDK 25, not 17.** Harmless — Godot uses its configured `java_sdk_path`.

## adb: two transports, always pass `-s`

The phone is usually visible **twice** — once over USB (`RRCXB04L8EJ`) and once over wireless adb-tls. Plain `adb install` fails as ambiguous. **Always pass `-s RRCXB04L8EJ`.**

## Verified project.godot keys

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
[physics]
common/physics_ticks_per_second=120
[input_devices]
sensors/enable_accelerometer=true
sensors/enable_gravity=true
[debug]
gdscript/warnings/{untyped_declaration,inferred_declaration,unsafe_call_argument,
  unsafe_method_access,unsafe_property_access,unsafe_cast,shadowed_variable,
  unused_variable}=2
```

Correct but **absent because they are already the Godot 4.7.2 default**:
- `display/window/handheld/orientation = 0` (Landscape)
- `display/window/stretch/mode = "disabled"` (spec §4.1)
- `debug/gdscript/warnings/unsafe_void_return = 2` (Error)

## BASIS-EVIDENCE: Android gravity orientation

Measured live on Samsung Galaxy A55 (`SM_A556E`, `RRCXB04L8EJ`) running Godot 4.7.2 with `sensors/enable_gravity=true` in landscape orientation (`DisplayServer.screen_get_orientation()` = `SCREEN_LANDSCAPE`, screen rotation = 90°).

### Measured Raw Poses

| Pose | `g.x` (m/s²) | `g.y` (m/s²) | `g.z` (m/s²) | Roll (deg) | Pitch (deg) | Derived Tilt (X, Y) |
|---|---|---|---|---|---|---|
| 1. Flat on table (screen to ceiling) | `+0.002` | `-0.170` | `-9.805` | `0.0°` | `1.0°` | `(0.000, 0.000)` (inside deadzone) |
| 2. Neutral held landscape (~38° pitch) | `-0.058` | `-7.992` | `-5.683` | `-0.3°` | `54.6°` | `(0.000, 0.000)` (neutral rest) |
| 3. Nose left (roll left) | `-2.375` | `-6.034` | `-7.357` | `-14.5°` | `39.3°` | `(-0.725, -0.066)` (steers left) |
| 4. Nose right (roll right) | `+3.004` | `-4.368` | `-8.250` | `+18.7°` | `27.9°` | `(+0.935, +0.506)` (steers right) |
| 5a. Top away (pitch forward / flat) | `-0.058` | `-1.513` | `-9.689` | `-0.3°` | `8.9°` | `(0.000, +1.000)` (steers forward/up) |
| 5b. Top toward (pitch back / upright) | `-0.219` | `-9.489` | `-2.467` | `-1.3°` | `75.4°` | `(0.000, -1.000)` (steers down) |

### Coordinate Discovery & Derivation

1. **Godot Android gravity is already display-aligned** when `display/window/handheld/orientation` is Landscape (rotation 90°):
   - `g.x` aligns with screen horizontal (nose left = negative, nose right = positive).
   - `g.y` aligns with screen vertical (neutral = `-7.99 m/s²`; top-away towards horizontal = `-1.51 m/s²`; top-toward upright = `-9.49 m/s²`).
   - `g.z` aligns with screen normal (facing sky = `-9.8 m/s²`).
2. **Angle extraction**:
   - `roll_deg = rad_to_deg(atan2(g.x, sqrt(g.y * g.y + g.z * g.z)))`
   - `pitch_deg = rad_to_deg(atan2(-g.y, -g.z))`
3. **Bridge to `apply_orientation(beta, gamma, screen_angle)`**:
   Under `SCREEN_LANDSCAPE` (screen angle = 90°), `apply_orientation` computes:
   - `roll = beta - calibrated_beta` (default `calibrated_beta = 38.0`)
   - `pitch = -gamma`
   Therefore:
   - `beta = DEFAULT_CALIBRATED_BETA + roll_deg`
   - `gamma = -(pitch_deg - DEFAULT_CALIBRATED_BETA)`
   At neutral resting pose (`roll_deg = 0`, `pitch_deg = 38°`):
   - `beta = 38.0`, `gamma = 0.0`
   - `roll = 38.0 - 38.0 = 0.0`, `pitch = -0.0 = 0.0` -> `tilt_vector = (0, 0)`
   When the user runs `calibrate_current_position()`:
   - `calibrated_beta = beta_0 = DEFAULT_CALIBRATED_BETA + roll_0`
   - `calibrated_gamma = gamma_0 = -(pitch_0 - DEFAULT_CALIBRATED_BETA)`
   - `roll = beta - calibrated_beta = roll_deg - roll_0`
   - `pitch = -(gamma - calibrated_gamma) = (pitch_deg - pitch_0)`
   The mathematical offsets cancel out identically, ensuring seamless re-calibration at any physical resting angle.

## Device Acceptance Evidence (Task 13)

Verified on Samsung Galaxy A55 (`SM_A556E`, `RRCXB04L8EJ`), Vulkan Forward Mobile (Samsung Xclipse 530):
- **HYBRID touch mode (production default build)**:
  - Ship steers toward pointer / drag point with realistic inertia and turn acceleration.
  - Ship points in direction of travel.
  - Boundary bounce reflection active on all four edges (`[-width/2, +width/2]`, `[-height/2, +height/2]`) with spark particle bursts.
  - Trail ribbon follows ship smoothly with fade-out.
  - Vector grid renders behind ship.
- **GYRO tilt mode (temporary build, verified and restored)**:
  - Steering works smoothly across all directions (left, right, top-away forward, top-toward backward).
  - Tilt deflection scales speed smoothly, saturating at `max_tilt_angle` (30°).
  - Code restored to `HYBRID` default in `src/input/input_router.gd`.
- **Frame Rate & Performance (`dumpsys gfxinfo com.jtg.perilpoint`)**:
  - Physics substepping: 120 Hz fixed tick rate (`common/physics_ticks_per_second=120`).
  - Render frame rate: 60 FPS (capped by `run/max_fps=60`).
  - Render frame time percentiles: 50th = 16ms, 90th = 17ms, 95th = 17ms, 99th = 19ms.
  - GPU frame time percentiles: 50th = 2ms, 90th = 2ms, 95th = 2ms, 99th = 3ms.
  - Result: Solid, hitch-free performance well under mobile thermal and frame budgets.

## User Observations for Later Modules

1. **Touch Steering Ergonomics (M11 UI/Settings)**: User suggested adding a directional touch circle / virtual joystick on the lower right and/or lower left (configurable, default right).
2. **Boundary Cutout / Display Corners (M11/M12)**: On physical devices with rounded display corners and camera cutouts, the 6px boundary glow extends slightly past the display edge at certain screen corners. Consider safe area inset or boundary padding.
3. **Sensor Calibration Flow (M11 Menus / Run Start)**: Different users hold the phone at different resting angles. Gyro calibration should trigger before starting the run (e.g. upon tapping Start / Play) as well as via calibration settings.

## Completed Module: M1 Summary

| Task | Deliverable | Commits |
|---|---|---|
| 1 | `src/core/log.gd` + autoload, `tests/test_log.gd` | `55795d7` |
| 2 | `src/core/types.gd`, `tests/test_types.gd` | `bba32fe` |
| 3 Step 0 | Float optionals in `Types.Enemy`/`ActiveWeapon` → `NAN` sentinel | `00495ab` |
| 3 | `src/core/tuning.gd`, `tools/parity/dump_constants.mjs`, JSON fixtures, `tests/test_tuning_parity.gd` | `47b1897` |
| 4 | `src/sim/vector_grid.gd`, `tests/test_vector_grid.gd` | `3e1a48a`, `d3eb1c6` |
| 5 | `src/sim/particle_engine.gd` (sparks), `tests/test_particle_engine.gd` | `c55ac8e` |
| 6 | `src/sim/player_ship.gd`, `tests/test_player_ship.gd` | `e932eef`, `daba26f` |
| 7 | `src/input/tilt_input.gd` (core math & save), `tests/test_tilt_input.gd` | `1841206`, `241ddaa` |
| 8 | `src/input/input_router.gd`, `src/input/touch_input.gd`, `tests/test_input_router.gd` | `cedd8cd` |
| 9 | `src/core/game_state_machine.gd`, `tests/test_game_state_machine.gd` | `b5f5391`, `019749e` |
| 11 | `src/render/grid_layer.gd`, `src/render/entity_layer.gd` | `53e0daa`, `30b84f6` |
| 10 | `src/core/game_root.gd`, `scenes/main.tscn`, `tests/test_arena_scale.gd`, 120 Hz physics | `6455173` |
| 12 | Device gravity bridge `tilt_input.gd:poll()`, sensor config in `project.godot`, basis logging | `01efc17` |
| 13 | Device acceptance pass on Galaxy A55 (HYBRID + GYRO + gfxinfo) | verified |
| 14 | Exit protocol: full test suite, linters, `PORT-PROGRESS.md`, `HANDOFF.md` rewrite | this commit |

## Next Module: M2 — Vertical Slice

Plan to author: `docs/superpowers/plans/2026-09-20-m2-vertical-slice.md`
Scope: Deliver the complete playable survival loop:
1. Enemy spawner and Seeker AI (`EnemySwarm.ts` Seeker subtype).
2. Collision detection between player, enemies, and arena boundaries (`CollisionSystem.ts`).
3. Weapon spawns & orb collection mechanics (`WeaponSpawner.ts`).
4. Blast wave / nuke detonation, killing seekers and perturbing the `VectorGrid`.
5. Score tracking, player death sequence, game over screen, restart flow.
6. Target: Solid 60 FPS with 100 seekers active on Galaxy A55.

Files M2 touches first:
- `godot/src/sim/enemy_spawner.gd`
- `godot/src/sim/seeker.gd` (or enemy entity hierarchy)
- `godot/src/sim/collision_system.gd`
- `godot/src/sim/weapon_spawner.gd`

## CONVENTIONS Wording Gaps to Report

Per CONVENTIONS §9.4, two minor documentation gaps were discovered during M1:
1. **§3 lacks a `static var` naming convention row**: `gdlint` treats `static var` under `class-variable-name` (requiring `snake_case`), rejecting `CONSTANT_CASE`. For immutable-table static vars like `Tuning.weapon_tuning`, `snake_case` was used. §3 should explicitly state that `static var` follows `snake_case`.
2. **§1.1 `@warning_ignore` clause**: §1.1 permits `@warning_ignore` "only where the TS genuinely requires it". Parity tests reading JSON fixtures into typed GDScript data structures require `@warning_ignore("unsafe_call_argument")` due to toolchain limitations. §1.1 should acknowledge toolchain-forced test fixture typing suppressions.

## Open Questions

- **The app has no icon**: Every Android export logs `ERROR: No project icon specified`. Supplying one is an art decision, not a port decision. Harmless for M1-M10 device testing; resolve before M11 release build.
- ~~Tilt gravity basis orientation on Android~~: **Resolved in M1 Task 12 & 13** (measured and documented in BASIS-EVIDENCE).
- ~~120 Hz vs 60 Hz physics tick~~: **Resolved in M1 Task 10** (120 Hz tick, spec D8).
- ~~Arena scale parity~~: **Resolved in M1 Task 10** (`test_arena_scale.gd` passing).
- ~~Grid spring reaction~~: **Resolved in M1 Task 11** (`vector_grid.gd` 120 Hz spring update + `grid_layer.gd` custom CanvasItem drawing).
