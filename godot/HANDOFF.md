# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

Last completed module: **M2 — Vertical slice** — complete, 2026-09-20
Branch: `feat/godot-port` (no upstream; nothing pushed)
Next module: **M3 — Enemy roster** — not started.

M2 is complete. All 12 tasks were executed, verified against the TypeScript source, tested headless (19/19 test scripts, 99/99 tests, 425 asserts passing), linted/formatted with 0 errors across 41 files, and accepted on a physical Samsung Galaxy A55 (`SM_A556E`).

## How to verify right now

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"

# 1. GUT suite — ALWAYS via the wrapper, never gut_cmdln.gd directly
# expect "OK: 19/19 scripts collected, all tests passed." (99 tests, 425 asserts)
tools/run_tests.sh

# 2. lint / format check       expect "no problems" / "41 files left unchanged"
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests

# 3. render scripts syntax check                         expect exit 0
"$GODOT" --headless --path godot --check-only -s src/render/grid_layer.gd -s src/render/entity_layer.gd -s src/render/render_context.gd

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
| Last APK | 29,788,683 bytes, `godot/build/peril-point-debug.apk` |

Always use the `_console` variant of the Godot exe.
**`java` on PATH is OpenJDK 25, not 17.** Harmless — Godot uses its configured `java_sdk_path`.
Always pass `-s RRCXB04L8EJ` to ADB when targeting device.

## Device Acceptance Evidence (Task 11)

Verified live on physical hardware: Samsung Galaxy A55 (`SM_A556E`, `RRCXB04L8EJ`), Vulkan Forward Mobile (Samsung Xclipse 530 GPU):

1. **Complete Playable Vertical Slice Loop**:
   - **Spawn & Fly**: Arrow ship spawns centered with realistic inertia, turn acceleration, wake spark trail, and boundary bouncing.
   - **Seeker Swarm AI**: Seeker dots spawn continuously from arena perimeter edges and track the ship. Flocking pairwise separation prevents dot collapse.
   - **Near-Miss / Close Call**: Flying within 16 px of a seeker triggers `CLOSE CALL! +250` neon floating text and audio ping without collision.
   - **Nuke Orb Collection**: Floating Nuke orb floats with pulsing glow and trefoil glyph. Approaching the orb triggers collection, pickup sound, and spark burst.
   - **Detonation & Kills**: Expanding concentric neon shockwave rings vaporize all dots in radius, perturb the reactive vector grid lattice (`grid.apply_explosion`), award kills, combo multipliers (up to 9 kills observed in single test run), and floating combo text.
   - **Player Death**: Colliding with a seeker triggers double death explosion (white + blue), stops music, plays death audio, logs best score, and displays `GAME OVER` modal.
   - **In-Game HUD**: Live score, combo multiplier, and best score display on top bar. Game Over overlay displays final score, kills count, survival time, and high score record banner.
   - **Restart Loop**: Tapping "PLAY AGAIN" (via touch or ADB) immediately resets the player, clears active swarm/weapons, spawns a new starting Nuke orb, zeroes score, recalibrates sensor neutral pose, and resumes play without restarting the application.

2. **Frame Rate & Performance Metrics (`dumpsys gfxinfo com.jtg.perilpoint`)**:
   - **Physics Substepping**: 120 Hz fixed tick rate (`common/physics_ticks_per_second=120`).
   - **Render Cap**: 60 FPS capped (`run/max_fps=60`).
   - **50th Percentile Frame Time**: 17 ms (solid 60 FPS target).
   - **GPU Frame Time**: 50th percentile = **2 ms**, 90th percentile = **2 ms**, 95th percentile = **4 ms** (comfortably within ≤ 5 ms budget).
   - **Pipeline**: Skia (Vulkan) Forward Mobile.

3. **Sensor Calibration User Requirement**:
   - Automated sensor calibration via `_tilt.calibrate_current_position()` is executed at initial launch and on every restart tap, ensuring neutral steering regardless of starting phone attitude.

## Completed Module: M2 Summary

| Task | Deliverable | Commits |
|---|---|---|
| 1 | `src/core/game_events.gd` event bus autoload + `tests/test_game_events.gd` | `47d333c` |
| 2 | `src/audio/audio_bank.gd` 28-method silent null object + `tests/test_audio_bank.gd` | `2649435` |
| 3 | `src/sim/particle_engine.gd` complete emitters + `tests/test_particle_engine.gd` | `246a301` |
| 4 | `src/sim/score_manager.gd` full scoring/combo port + `tests/test_score_manager.gd` | `fae0d22` |
| 5 | `src/sim/enemy_swarm.gd` seeker AI, separation, director + `tests/test_enemy_swarm.gd` | `d4a6343` |
| 6 | `src/sim/weapon_system.gd` orb spawn, nuke blast + `tests/test_weapon_system.gd` | `139c0e2` |
| 7 | `src/render/render_context.gd`, `effect_layer.gd`, expanded `entity_layer.gd`, `tests/test_render_layers.gd` | `b875426` |
| 8 | `src/sim/run_controller.gd` in-run frame order coordinator + `tests/test_run_controller.gd` | `0f1ecc7` |
| 9 | `src/ui/hud_controller.gd` in-game HUD & Game Over modal + `tests/test_hud_controller.gd` | `27e1a95` |
| 10 | `src/core/game_root.gd` & `scenes/main.tscn` full scene wiring | `5190bbe` |
| 11 | Galaxy A55 device acceptance, touch emulation, tilt restart calibration | `b1ad52b` |
| 12 | Exit protocol: full test suite, linters, `PORT-PROGRESS.md`, `HANDOFF.md` rewrite | this commit |

## Next Module: M3 — Enemy Roster

Scope per `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` §8:
- Complete all remaining 12 enemy types from `web/src/tilt-to-live/EnemySwarm.ts`:
  1. Arrow Drone
  2. Circle Dot
  3. Wall Dot
  4. Rotating Gate Dot
  5. Turret Dot
  6. Snake Segment
  7. Charger Drone
  8. Artillery Siege Unit
  9. Artillery Plasma Bullet
  10. Orbital Carrier Mothership
  11. Carrier Satellite
  12. Phasing Specter
- Wave director mechanics: 8 tactical swarm formations, mode-specific director multipliers, and continuous difficulty curve.
- GUT test suite verifying AI steering and formation triggers.

First task of M3:
- Author implementation plan `docs/superpowers/plans/2026-09-20-m3-enemy-roster.md`.
- Port enemy subtype update routines in `src/sim/enemy_swarm.gd`.
