# Tilt to Live — Godot Mobile Port: Design

Date: 2026-09-20
Status: Approved
Source commit: `7be9614`
Target engine: Godot 4.7.2-stable (GDScript; standard build, not .NET)

---

## 1. Summary

Port the existing TypeScript/Canvas 2D game **Tilt to Live** (~13,250 lines across
22 modules) to Godot 4.7.2 as a **landscape mobile game** for Android, with iOS
deferred until a macOS host is available (D1).

The port is sequenced as **13 self-contained modules** (M0, M0b, M1–M11). Each
module ends in a
runnable build, a hard stop, and a written handoff, so work can pause when
credits run out and resume cold in a new session — or jump to a different module
whose dependencies are already met.

The TypeScript game is **not** retired. It stays in the repository as the
reference implementation and as a live build dependency: the audio bake step
(Module 5) executes `TiltAudio.ts` to render the sound effects.

---

## 2. Context: what exists today

The repository is named `dread-flock` and `README.md` describes two games,
"Dread Flight" and "Curse Runner". Neither exists in the source tree.
**The README is stale.** The actual game is `web/src/tilt-to-live/`. `three` is a
declared dependency but the active code path is pure Canvas 2D.

**Repository layout.** The web game lives under `web/`, the Godot project under
`godot/`, frozen historical artifacts under `archive/`, and specs under `docs/`.
All TypeScript paths in this document and in `godot/CONVENTIONS.md` are written
relative to the repository root and therefore begin `web/src/`. The `## PORTS:`
headers and `# PORT:` citations required by Laws 1 and 3 use this same form.

### 2.1 Module inventory

| TypeScript module | LOC | DOM refs | Role |
|---|---:|---:|---|
| `TiltGame.ts` | 2,446 | 60 | Master controller |
| `EnemySwarm.ts` | 1,649 | 0 | 13 enemy types, flocking, 8 formations, wave director |
| `ArmoryUI.ts` | 1,293 | 23 | Shop: weapons, ships, arena, handling, boosts |
| `GoalManager.ts` | 983 | 0 | Milestones, cumulative stats |
| `ProgressionManager.ts` | 940 | 0 | Perks, skins, arenas, economy |
| `WeaponSystem.ts` | 923 | 0 | 7 superweapons, orbs |
| `TiltAudio.ts` | 886 | 0 | Procedural Web Audio synth + generative music |
| `PlayerShip.ts` | 633 | 0 | Inertia physics ship |
| `TiltRenderer.ts` | 566 | 0 | Canvas2D render orchestration |
| `TiltMenu.ts` | 523 | 25 | Homepage / start menu |
| `GoalsHUD.ts` | 488 | 26 | Edge rail + milestones modal |
| `GauntletMaze.ts` | 388 | 0 | Descending wall maze |
| `ParticleEngine.ts` | 235 | 0 | Pooled vector particles |
| `TiltEntranceCinematic.ts` | 221 | 5 | 600ms cold open |
| `ScoreManager.ts` | 206 | 0 | Score, multiplier, combo, floating text |
| `GyroscopeController.ts` | 190 | 1 | DeviceOrientation tilt + calibration |
| `CoinSystem.ts` | 176 | 0 | Points pickups |
| `Types.ts` | 139 | 0 | Enums, interfaces |
| `GameOptions.ts` | 137 | 0 | Modes, settings, persistence |
| `VectorGrid.ts` | 118 | 0 | Spring-mass reactive mesh |
| `WeaponTuning.ts` | 87 | 0 | Tuning constants (single source of truth) |
| `main.ts` | 20 | 2 | Bootstrap |

Approximately **10,700 lines have zero DOM coupling** and translate close to
1:1. The remaining ~2,500 lines are HTML/CSS UI requiring a rebuild as Godot
`Control` scenes.

### 2.2 Content inventory

- **3 modes:** `classic`, `code-red`, `gauntlet`
- **13 enemy types:** `seeker`, `arrow_drone`, `wall_dot`, `circle_dot`,
  `turret_dot`, `spike_mine`, `snake_segment`, `charger`, `artillery`,
  `carrier`, `bullet`, `pulsar`, `specter`
- **7 weapons:** `nuke`, `missiles`, `lightning`, `laser`, `vortex`, `freeze`,
  `shield`
- **8 formations:** arrow, dual pincer, circle encirclement, wall, sequential
  gauntlet wall, rotating gate, turret, snake
- **3 `localStorage` keys:** `tilt_to_live_settings_v1`,
  `tilt_to_live_progression_v3`, `tilt_to_live_completed_goals_v1`
  (+ `tilt_to_live_cumulative_stats_v1`)

### 2.3 Resolution model (load-bearing)

`TiltGame.resizeCanvas()` is resolution-agnostic. It sims in true device pixels
and derives an arena scale from the smaller viewport dimension:

```
arenaScale = clamp(min(width, height) / 680, 0.60, 1.15)
```

propagated to `PlayerShip`, `EnemySwarm`, `WeaponSystem`, `GauntletMaze` and
`TiltRenderer` via `setScale()`. There is no orientation logic anywhere in the
codebase.

---

## 3. Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | **Target: Android + iOS only** | Tilt controls are natively a mobile idiom. No desktop, no web, no console. **Amended 2026-09-20:** Godot requires a macOS host with Xcode to export iOS, and the development machine is Windows 11. Android is built here; iOS is deferred until a Mac or macOS CI runner is available. The GDScript is identical for both, so this blocks nothing before M11. See `godot/PREREQUISITES.md` §3. |
| D2 | **Orientation: landscape** | User decision. Gives the swarm room to flank; matches how the game currently reads. |
| D3 | **Full fidelity, slice-first sequencing** | All content ports eventually; Module 2 delivers a genuinely playable slice so every later module layers onto something that runs. |
| D4 | **Rendering: plain-data sim + `_draw()`** | Entities stay as arrays exactly as the TS has them; a handful of `Node2D._draw()` nodes mirror the `ctx` calls near line-for-line. Lowest-risk translation. |
| D5 | **Audio: bake SFX, port the sequencer** | SFX rendered offline to `.ogg` by the existing TS synth; the music scheduler's arrangement logic ports to a beat-timed GDScript sequencer firing baked stems. Music stays generative without per-sample GDScript synthesis. |
| D6 | **Repo: `godot/` subfolder, TS retained** | The TS is a live build dependency for D5, not just a reference. |
| D7 | **Language: GDScript** | The installed build is standard Godot 4.7.2, not .NET. |

---

## 4. Architecture

### 4.1 Viewport and scaling

Godot's conventional fixed-base-resolution + stretch setup **would break this
port**. The simulation works in true device pixels; stretching a fixed canvas
would land every tuned constant at the wrong effective size.

Therefore:

- `content_scale_mode = disabled`
- The sim reads `get_viewport_rect().size` directly, reproducing
  `resizeCanvas()` including the `arenaScale` formula verbatim
- **Consequence, binding on all UI modules:** every `Control` must be built
  responsive (anchors and containers), never pinned to a base resolution. This
  is what the CSS already did, so it is no additional work — but it is a rule.

`arenaScale` is unaffected by orientation: it keys off the smaller dimension
(~390px on a typical phone either way), clamping to the 0.60 floor.

### 4.2 Project layout

```
godot/
  project.godot
  export_presets.cfg
  CONVENTIONS.md            normative code standards
  PORT-PROGRESS.md          durable module checklist
  HANDOFF.md                rewritten at every module stop
  src/
    core/     game_root.gd  game_state_machine.gd  types.gd  tuning.gd  log.gd
    sim/      player_ship.gd  enemy_swarm.gd  weapon_system.gd
              particle_engine.gd  coin_system.gd  gauntlet_maze.gd
              vector_grid.gd  score_manager.gd  run_controller.gd
    meta/     progression_manager.gd  goal_manager.gd  game_options.gd
              save_store.gd
    input/    input_router.gd  tilt_input.gd  touch_input.gd
    render/   grid_layer.gd  entity_layer.gd  effect_layer.gd
              render_context.gd  menu_backdrop.gd
    ui/       *.tscn + *.gd
    audio/    audio_bank.gd  music_sequencer.gd
  assets/audio/sfx/*.ogg    generated by Module 5
  tests/                    GUT headless specs
  tests/fixtures/*.json     constant-parity fixtures
```

These sit inside `godot/`. At the repository root alongside it:

```
web/                        the TypeScript game (npm root; reference + bake source)
archive/                    frozen historical artifacts
docs/superpowers/specs/     this document
tools/bake-audio/           Node script driving web/src/tilt-to-live/TiltAudio.ts
tools/parity/               dumps web/src constant tables to JSON
```

`tools/` sits at the root rather than inside either project because both scripts
bridge the two: they read TypeScript from `web/` and write artifacts into
`godot/`.

Filenames are `snake_case` with `PascalCase` `class_name`, per the Godot style
guide (this avoids cross-platform case-sensitivity bugs). `src/sim/` and
`src/meta/` mirror the TS modules one-to-one, same member names, so every port
module is a mechanical diff a reviewer can check side by side.

### 4.3 Timing

The simulation runs in `_physics_process` at 60 Hz; Godot's fixed step replaces
the hand-rolled accumulator in `TiltGame.loop()`. `_process` only calls
`queue_redraw()`.

`max_fps = 60` on mobile. Many phones present at 120 Hz, and drawing twice per
simulation step without interpolation would judder and halve battery life for no
visual gain.

`GAME_SPEED = 0.75` (`TiltGame.ts:35`) carries over verbatim into `tuning.gd`.

### 4.4 Entity representation

Enemies, particles, orbs, missiles and floating text are plain data held in
typed arrays — but as typed `RefCounted` classes, **not** `Dictionary`. Typed
property access is substantially faster than dictionary lookup in GDScript 4 and
maps 1:1 to the `Types.ts` interfaces. The existing particle pooling carries
over.

Documented escape hatch, **only** if on-device profiling in Module 11 shows the
draw loop is the bottleneck: MultiMesh for the swarm. This is not to be built
speculatively (see Law 4).

### 4.5 Canvas2D → Godot draw mapping

| Canvas 2D | Godot | Note |
|---|---|---|
| `ctx.arc` + fill | `draw_circle()` | direct |
| `beginPath`/`lineTo`/`stroke` | `draw_polyline()` | direct |
| `createRadialGradient` | one baked white radial-gradient texture, tinted via `modulate` | the workhorse: orbs, explosions, glows |
| `shadowBlur` glow | `WorldEnvironment` 2D glow + HDR colours | replaces hundreds of per-draw calls |
| `globalAlpha` | per-draw `Color.a` | direct |
| `save`/`restore`/`translate` | `draw_set_transform()` | direct |

The glow decision carries real risk: Godot's 2D glow is a fullscreen GPU pass
and is genuinely expensive on mid-range phones. It is measured on hardware in
Module 11, with a documented per-draw fallback if it does not hold 60 fps.

### 4.6 Persistence

The three `localStorage` keys become three JSON files under `user://`, **keeping
the exact same JSON shapes and version suffixes**. This costs nothing now and
keeps a future web→mobile save import possible. `SaveStore` is responsible for
corruption handling (§6.3).

---

## 5. Components and data flow

### 5.1 Decomposing `TiltGame` (2,446 lines)

It performs six distinct jobs and becomes six files:

| New file | Absorbs from `TiltGame.ts` | ~LOC |
|---|---|---|
| `core/game_root.gd` | subsystem ownership, resize, wiring | 200 |
| `core/game_state_machine.gd` | `start`, `launchRun`, `returnToMenu`, `restart`, `resetRun`, `togglePause`, `stop`, `startCinematic` | 250 |
| `sim/run_controller.gd` | `update`, `checkCollisions`, `handleEnemyKilled`, `loseLife`, `triggerPlayerDeath`, `spawnStartingWeaponOrb` | 600 |
| `input/input_router.gd` | `getMovementVector`, `getMovementKeyDirection`, `hasActiveMovementKeys`, control-scheme resolution | 200 |
| `ui/hud_controller.gd` | `updateHUD` → signals | 200 |
| `render/menu_backdrop.gd` | `updateMenuSimulation` | 250 |

### 5.2 Binding constraint: no singletons for sim systems

`TiltGame.updateMenuSimulation()` runs a **second, independent simulation**
(`menuPlayer`, `menuSwarm`, `menuWeapons`) as the live menu background.

**Therefore no simulation system may be an autoload or singleton.** Every sim
class must be instantiable twice concurrently. This is trivial to honour if
known up front and painful to unwind if Module 3 makes `EnemySwarm` global and
Module 11 discovers it cannot have two.

### 5.3 Sim → UI seam

The 60 direct DOM reaches become signals on a `GameEvents` autoload:

`score_changed` · `enemy_killed` · `weapon_activated` · `life_lost` ·
`run_ended` · `goal_completed` · `points_changed` · `phase_changed`

**Standing rule: signals are sim→UI and sim→audio only. Never sim→sim.**
Simulation systems keep direct references and `Callable` callbacks exactly as
the TS does. Without this rule the event bus becomes a global mutable dumping
ground in which frame order stops being knowable — and preserving frame order is
the entire point of this port.

The existing callbacks passed into `update()` (`loseLife`, `handleEnemyKilled`,
`addPointsCredited`) port directly as GDScript `Callable`s.

### 5.4 Frame order — preserved exactly

Transcribed from `TiltGame.update()` (`TiltGame.ts:1855`). Every physics tick:

1. `grid.update(dt)`
2. `particles.update(dt)`
3. `player.update(...)` — after control-scheme resolution and `get_movement_vector()`
4. `gauntlet_maze.update(...)` — **gauntlet mode only**
5. `swarm.update(...)`
6. `weapons.update(...)`
7. `coins.update(...)`
8. `scores.update(dt, mode)`
9. `check_collisions()`
10. run-tracker sync → live goal evaluation
11. HUD signal emission

**Particles update before the player and swarm.** This means particles emitted
during this tick draw unaged. It looks accidental and is not safe to "fix" — it
is part of the tuned feel. Recorded here so no later module tidies it away.

This is the **final** frame order. Module 2 implements only the subset it owns
(steps 1, 2, 3, 5, 6, 8, 9, 11 — no maze, no coins, no goals). Later modules
slot their systems into the positions documented above. **No module may reorder
an existing step**; a module adds its call at its documented index and nothing
else moves.

### 5.5 Render order

`GridLayer` → `EntityLayer` (maze, coins, orbs, enemies, player) →
`EffectLayer` (particles, weapon FX, floating text) → UI `CanvasLayer`.

Menu phase substitutes `MenuBackdrop` and skips the run layers entirely,
mirroring the early return in `TiltGame.render()` (`TiltGame.ts:2265`).

### 5.6 One targeted cleanup

`TiltRenderer.render()` takes **19 positional parameters**. Ported literally it
is a landmine in every subsequent module. It becomes a `RenderContext`
`RefCounted` with named fields, populated once per frame.

This is the **only** structural liberty taken with the renderer. Everything else
is mechanical translation.

---

## 6. Module protocol, testing, error handling

### 6.1 Stop/resume mechanism

There is no `TodoWrite` tool in this environment, and an in-session todo list
would not survive a new session regardless. The checklist is therefore **two
files in the repository**.

**`godot/PORT-PROGRESS.md`** — one entry per module with explicit acceptance
criteria, so "done" is never a judgment call:

```markdown
- [x] Module 0 — Scaffold          done 2026-09-20  a1b2c3d
      ok  godot --headless --quit exits 0
      ok  debug APK builds
- [ ] Module 3 — Enemy roster      deps: M2
      --  all 13 types spawn and behave per TS
      --  8 formations trigger
      --  GUT wave-director specs pass
```

**`godot/HANDOFF.md`** — rewritten at every stop, written *for a session with
zero context*: what just landed, the exact commands to verify it right now, the
next module and its literal first step, and anything that surprised us.

### 6.2 Per-module exit protocol

Every module ends with these five steps, in order:

1. **Verify** — run the module's acceptance commands and read the output. Never
   "should work".
2. **Commit** — one line, imperative, ≤72 chars, no trailers, prefixed `M<n>:`.
3. **Tick `PORT-PROGRESS.md`** — box checked, date and commit SHA recorded.
4. **Rewrite `HANDOFF.md`.**
5. **Stop and report to the user. Do not begin the next module.**

Resume incantation from a cold session:

> Read `godot/HANDOFF.md` and
> `docs/superpowers/specs/2026-09-20-tilt-to-live-godot-port-design.md`,
> then execute Module N.

### 6.3 Testing

**Tier 1 — GUT headless unit specs** on the pure-logic ports:
`ProgressionManager` (perk cost curve, all `buy_*` paths, multipliers),
`GoalManager` (evaluation per category, cumulative stats), `ScoreManager`
(multiplier and combo decay), `Tuning` (`get_tuned_value`). Deterministic, no
emulator, seconds to run.

**Tier 2 — constant-parity harness.** The dominant failure mode in a
13,000-line mechanical translation is transcription drift, not bad design.
`tools/parity/` dumps the TS constant tables to JSON (`WEAPON_TUNING`,
`KEYSTONE_COSTS`, perk cost curve, the `arenaScale` formula, goal thresholds)
and a GDScript spec loads that same JSON and asserts equality.

**Explicitly not built:** full behavioural parity (simulating N frames in both
engines and diffing state). Floating-point and RNG divergence make it a
maintenance sink that fails for reasons that do not matter. Constants only.

**Tier 3 — device smoke pass.** Per module: build to a real phone, play 60
seconds, watch frame time. Emulators misreport both GPU cost and accelerometer
behaviour.

The existing `npm run smoke` Puppeteer tests remain the reference-behaviour
source of truth.

### 6.4 Error handling

GDScript has no exceptions. Every case below is an explicit return-value check,
not a `try`/`catch` — a difference from the TS that is easy to port past
silently.

- **Corrupt save** → `SaveStore` detects parse failure, moves the bad file aside
  as `<name>.corrupt.json`, falls back to defaults. Never hard-fails boot.
- **Missing baked audio** → `AudioBank` logs via `Log` and plays silence rather
  than crashing the run.
- **No accelerometer** (emulator, or permission denied) → falls back to touch
  steering. This is already the TS behaviour.

---

## 7. Code standards

Normative document: **`godot/CONVENTIONS.md`**. It is binding on every module
and every module prompt carries the five port laws verbatim.

Summary of the enforcement tiers:

1. **Machine-enforced.** GDScript warnings set to **Error** in Project Settings
   → Debug → GDScript: `UNTYPED_DECLARATION`, `INFERRED_DECLARATION`,
   `UNSAFE_CALL_ARGUMENT`, `UNSAFE_METHOD_ACCESS`, `UNSAFE_PROPERTY_ACCESS`,
   `UNSAFE_CAST`, `UNSAFE_VOID_RETURN`, `SHADOWED_VARIABLE`, `UNUSED_VARIABLE`.
   The engine refuses to run violations. Plus `gdformat`/`gdlint` from
   gdtoolkit 4.x.
2. **File anatomy** — the Godot-documented member order, no deviation.
3. **Naming** — a fixed table, no judgment calls.
4. **The five port laws** — no invented numbers; no silent improvement; one TS
   file to one `.gd` file; nothing new; stop rather than guess.
5. **Comments** — required `## PORTS:` header, `##` docs on public members,
   `# PORT:` source citations, `# PORT-NOTE:` for deliberate divergence,
   module-tagged `# TODO(M7):`.
6. **Forbidden constructs** — untyped `var`, string-based `call`/`get`/`set`,
   `has_method` duck-typing, `Dictionary` entities, autoloaded sim systems,
   bare `print()`, `await` in `_physics_process`, scattered `get_node("path")`.

---

## 8. Modules

Modules **3, 4, 5 and 7** are mutually independent — each depends only on M2 —
and may be taken in any order. M6 depends on M5; M8 and M9 depend on M7; M10
depends on M3; M11 depends on all.

### Module 0 — Scaffold
**Deps:** none
- `godot/project.godot`: Godot 4.7.2, **mobile** rendering method,
  `content_scale_mode = disabled`, `handheld/orientation = landscape`,
  `max_fps = 60`
- The nine GDScript warnings set to **Error**; `project.godot` committed
- gdtoolkit 4.x installed; **exact verified `gdformat`/`gdlint` invocations
  recorded in `CONVENTIONS.md`** (verified against `--help`, not from memory)
- GUT addon installed and running an empty suite headless
- `tools/` directory created
- `CONVENTIONS.md`, `PORT-PROGRESS.md`, `HANDOFF.md` written

**Accept:** `godot --headless --path godot --quit` exits 0; the GUT suite runs
headless and passes; **untyped GDScript is observed being rejected**; `gdlint`
runs clean; no `<filled in by Module 0>` placeholder remains.

### Module 0b — Android toolchain
**Deps:** M0 · **Requires user action and several GB of downloads**

Amended 2026-09-20. The spec originally folded "a debug APK builds" into Module
0. An environment check that day found this unachievable: the export-templates
directory is empty, no JDK exists anywhere on disk, and `ANDROID_HOME` is set to
a path that does not exist. Blocking Module 0 on multi-gigabyte user-side
installs would defeat the clean module boundaries this plan is built around, so
the toolchain is its own module.

- Export templates downloaded and installed (Editor → Manage Export Templates)
- JDK 17 installed; Android SDK installed; `ANDROID_HOME` corrected
- Godot Editor Settings → Export → Android: Java SDK and Android SDK paths set
- Debug keystore generated; Android export preset added
- **Keystore credentials must not be committed.** `export_presets.cfg` is
  tracked; passwords are supplied by environment variable.

**Accept:** a debug APK builds, installs and launches on a physical device.

**Why M1 depends on this:** M1's acceptance requires verifying landscape tilt
axis mapping on real hardware, which an emulator cannot provide.

### Module 1 — Core loop and input
**Deps:** M0b
- `core/types.gd` (ports `Types.ts`), `core/tuning.gd` (ports `WeaponTuning.ts`),
  `core/log.gd`
- `tools/parity/` dumper + first parity fixture and GUT spec
- `core/game_root.gd`, `core/game_state_machine.gd` (menu/playing/paused)
- `sim/vector_grid.gd` (ports `VectorGrid.ts`)
- `sim/player_ship.gd` (ports `PlayerShip.ts`)
- `input/input_router.gd`, `input/tilt_input.gd`, `input/touch_input.gd` —
  including **landscape accelerometer axis mapping** and the calibration concept
  from `GyroscopeController.ts`
- `render/grid_layer.gd`, minimal `render/entity_layer.gd`
- `resizeCanvas()` reproduction including `arenaScale`

**Accept:** on a physical device in landscape, tilt and touch both steer the ship
with correct axes; the grid reacts to motion; 60 fps; the tuning parity spec
passes.

**Risk:** landscape axis mapping cannot be validated on an emulator.

### Module 2 — Vertical slice
**Deps:** M1
- `sim/enemy_swarm.gd` limited to `seeker` + flocking separation + basic wave
  director
- `sim/particle_engine.gd` (full port)
- `sim/weapon_system.gd` limited to `nuke` + orb spawning
- `sim/score_manager.gd` (full port)
- `sim/run_controller.gd`: `check_collisions`, `handle_enemy_killed`,
  `lose_life`, `trigger_player_death`, `spawn_starting_weapon_orb`
- `render/effect_layer.gd`, `render/render_context.gd`
- Minimal HUD (score, best, multiplier, lives) driven by `GameEvents`
- **`audio/audio_bank.gd` as a silent null-object stub.** `ScoreManager` and
  `CoinSystem` take an audio instance as a parameter in the TS
  (`registerKill(x, y, weaponType, audio)`), so the full method surface of
  `TiltAudio.ts` must exist and accept calls from Module 2 onward even though
  Module 5 supplies the real implementation. Every method logs at debug level
  and returns. This keeps M5 and M7 independent of each other's ordering.

**Accept:** a complete playable loop on device — spawn, fly, dodge, collect an
orb, fire the nuke, score, die, restart — holding 60 fps with 100 seekers.

### Module 3 — Enemy roster
**Deps:** M2
- The remaining 12 enemy types and their update behaviours
- All 8 formations, plus carrier/bullet/artillery spawn chains
- `on_enemy_killed`, `freeze_all`, full wave director

**Accept:** each of the 13 types spawns and behaves per the TS; all 8 formations
trigger; GUT specs cover wave-director thresholds.

### Module 4 — Weapons
**Deps:** M2
- The remaining 6 weapons: missiles, lightning, laser, vortex, freeze, shield
- Homing missiles, lightning arcs and branches, perk application through
  `tuning.gd`
- `get_random_weapon_type`, `get_weapon_color`, orb glyph rendering

**Accept:** all 7 weapons activate with radius/duration read from the tuning
table; perk ranks visibly change values; the `WEAPON_TUNING` parity spec passes.

### Module 5 — Audio bake and SFX
**Deps:** M2
- `tools/bake-audio/`: a Node script that drives
  `web/src/tilt-to-live/TiltAudio.ts` to offline-render each SFX to `.ogg`,
  writing into `godot/assets/audio/sfx/`. Run from the repository root; it
  resolves its dependencies from `web/node_modules`.
- `audio/audio_bank.gd` with `pitch_scale` randomisation to retain variation
- `GameEvents` → audio wiring

**Accept:** every `play*` method in `TiltAudio.ts` has a corresponding baked file
that fires at the correct moment; a missing file logs and continues without
crashing.

### Module 6 — Generative music
**Deps:** M5
- Baked stems: kick, snare, hi-hat (open/closed), crash, bass, arpeggio, lead,
  pad chords
- `audio/music_sequencer.gd` porting `scheduler`, `scheduleStep`,
  `scheduleDrums`, `scheduleBassLine`, `scheduleArpeggio`, `scheduleLeadMelody`,
  `schedulePadChord`

**Accept:** music plays and evolves across bars; no dropouts over a 5-minute
device run.

### Module 7 — Persistence and economy
**Deps:** M2
- `meta/save_store.gd` — `user://` JSON, identical shapes and version suffixes,
  corruption fallback with backup
- `meta/progression_manager.gd` (full port: perks, ships, cursors, enemy skins,
  arenas, steering tuning, economy)
- `meta/game_options.gd` (full port), `sim/coin_system.gd`

**Accept:** GUT specs pass for the perk cost curve, every `buy_*` method and all
multipliers; saves survive a restart; a deliberately corrupted file falls back to
defaults and is backed up.

### Module 8 — Armory UI
**Deps:** M7
- Touch-native `Control` scenes for all five tabs: weapons, ships, arena,
  handling, boosts
- A `Theme` resource carrying the design tokens from `game.css`
- The handling preview

**Accept:** all five tabs render and are operable on device within the landscape
safe area; purchases persist across a restart.

### Module 9 — Milestones
**Deps:** M7
- `meta/goal_manager.gd` (full port: all goal definitions, cumulative stats,
  `evaluate_run`, `evaluate_live_total_goals`, `evaluate_unlock_goals`)
- Edge rail HUD, completion toast, full milestones modal

**Accept:** GUT specs cover goal evaluation for every category; the rail updates
live during a run; toasts fire on completion.

### Module 10 — Modes
**Deps:** M3
- `code-red` and `gauntlet` mode configs, multipliers and spawn tables
- `sim/gauntlet_maze.gd` (full port)
- `spawn_mode_armada`, `trigger_gauntlet_formation`, mode announcement banner

**Accept:** all three modes are playable from start to death; gauntlet maze walls
block and push the player; mode multipliers apply to scoring.

### Module 11 — Menu, cinematic, export, device pass
**Deps:** all
- `render/menu_backdrop.gd` (the second sim instance), menu `Control` scene,
  options modal
- Entrance cinematic
- **Glow cost measurement on device**, and the fallback decision from §4.5
- Android export preset, icons, splash screens
- iOS export preset **only if a macOS host is available** (D1); otherwise this
  half of the module is explicitly deferred and recorded as such in
  `PORT-PROGRESS.md` rather than silently skipped

**Accept:** cold boot → menu → cinematic → run → death → menu loops correctly on
device; sustained 60 fps across a 5-minute run; a signed **Android** release
build is produced. iOS acceptance is deferred with D1.

---

## 9. Risk register

| Risk | Mitigation | Module |
|---|---|---|
| 2D glow too expensive on mid-range phones | measure on device; documented per-draw fallback | M11 |
| Baked SFX lose per-invocation variation | `pitch_scale` randomisation — close, not identical | M5 |
| GDScript + 200 enemies + per-frame `_draw` | MultiMesh escape hatch, only if profiling demands it | M11 |
| Transcription drift across 13,000 lines | constant-parity harness (§6.3 Tier 2) | M1 onward |
| Landscape tilt axis mapping | requires a physical device, not an emulator | M1 |
| Sim system accidentally made a singleton | stated constraint §5.2; breaks `MenuBackdrop` | M3, M11 |

---

## 10. Out of scope

- Web export (the TypeScript build remains the web game)
- Desktop, console and Steam targets
- Achievements, cloud saves, leaderboards, multiplayer
- Any new gameplay content or rebalancing (Law 2 and Law 4)
- C#/.NET (the installed build is standard GDScript)
- Building a web→mobile save importer (the JSON shapes are preserved so one
  remains possible, but none is written)
- Fixing the stale `README.md` game descriptions ("Dread Flight", "Curse
  Runner"), which name two games that are not in the source tree. The README's
  build paths were corrected during the `web/` restructure; its prose was not.
