# Port Progress

The durable module checklist. Ticked only by the exit protocol in
`CONVENTIONS.md` §9, after the acceptance commands have actually been run.

Dependency map and resume instructions:
`docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md`

- [x] **M0 — Scaffold**  deps: none   *(2026-09-20, commit `035ccdc`)*
      ok  `$GODOT --headless --path godot --import` exits 0
      ok  GUT suite runs headless: Scripts 1 / Tests 1 / Passing 1, exit 0
          (run the suite via `tools/run_tests.sh` — see CONVENTIONS §1.3)
      ok  untyped GDScript is rejected (proof run observed — parse error
          `Variable "untyped_proof" has no static type. (Warning treated as
          error.)`; all nine required warnings confirmed at severity 2)
      ok  `gdlint` and `gdformat` 4.5.0 verified and pinned in CONVENTIONS.md §1.2
      ok  PORT-PROGRESS.md and HANDOFF.md exist

- [x] **M0b — Android toolchain**  deps: M0   *(2026-09-20, commit `e32cdea`)*
      ok  export templates installed (4.7.2.stable, android debug + release)
      ok  Temurin JDK 17.0.20.1, Android SDK platform-37.0 / build-tools 36.0.0,
          ANDROID_HOME corrected and verified to exist
      ok  debug keystore in Editor Settings; `Android` export preset added with
          **no credentials written to the tracked file**
      ok  debug APK (29,759,129 bytes) installs and launches on **SM_A556E**
          (Galaxy A55) — pid confirmed alive, Vulkan **Forward Mobile**,
          landscape confirmed (`cur=2340x1080`, `ROTATION_90`, orientation
          source = our own activity)
      note  app id `com.jtg.perilpoint`, label **Peril Point**
      note  `scenes/main.tscn` is a placeholder **M1 must replace**

- [x] **M1 — Core loop and input**  deps: M0b   *(2026-09-20, commit `01efc17`)*
      plan  `docs/superpowers/plans/2026-09-20-m1-core-loop-and-input.md`
      ok  tilt and touch both steer correctly in landscape on a device,
          verified in **two builds**: the committed `HYBRID` default for touch,
          then a temporary `GYRO` flip for tilt, reverted before the commit.
          The two schemes are mutually exclusive in the source
          (`GameOptions.ts:80`, `TiltGame.ts:1280`) and the toggle is M11's.
      ok  grid renders and its spring-mass update runs; 60 fps
          (**criterion amended 2026-09-20**, spec §8 M1: it read "grid reacts to
          motion", which nothing in M1's scope can cause — `applyExplosion` is
          only ever called by kills, weapons, death and the cinematic, all M2+,
          and player motion never disturbs the grid in the web game. M1 draws
          the grid unconditionally, `# TODO(M7)` to gate it on
          `GameOptions.showGridlines`, and proves the spring in a GUT spec.)
      ok  tuning constant-parity spec passes (`test_tuning_parity.gd`, `test_arena_scale.gd`)
      ok  **physics tick is 120 Hz, not 60** (spec D8, amended 2026-09-20).
          `max_fps=60` still caps rendering. Verified with
          `grep -A2 '\[physics\]' godot/project.godot`.
      ok  the Android gravity basis is **measured on device**, not
          assumed; the measured vectors go in HANDOFF.md as BASIS-EVIDENCE.

- [x] **M2 — Vertical slice**  deps: M1   *(2026-09-20, commit `b1ad52b`)*
      plan  `docs/superpowers/plans/2026-09-20-m2-vertical-slice.md`
      ok  full playable loop: spawn, fly, dodge, orb collection, nuke shockwave
          detonation, kills/combos/scoring, close-call floating text, player
          death, Game Over modal, and clean in-run restart via PLAY AGAIN button
          verified live on Samsung Galaxy A55 (`SM_A556E`).
      ok  solid 60 fps rendering cap / 120 Hz physics substepping maintained on
          hardware; 50th percentile frame time 17ms, GPU frame time 2ms
          (measured via `dumpsys gfxinfo`).
      ok  19/19 GUT test scripts collected and passing (99 tests, 425 asserts).
      ok  gdformat and gdlint pass with zero errors across 41 files.
      ok  render scripts pass headless syntax check (`--check-only`).

- [ ] **M2.5 — Mobile feel**  deps: M2   *(code complete 2026-09-21, head `37f9fd4`; DEVICE PASS PENDING)*
      plan  `docs/superpowers/plans/2026-09-20-m2.5-mobile-feel.md`
      spec  `docs/superpowers/specs/2026-09-20-m2.5-mobile-feel-design.md`
      **tick this box only after `godot/VERIFY-ME.md` §M2.5 is run on the A55**
      ok  all 9 plan tasks executed except the hand-held half of Task 8 and the asset
          research of Task 9 (deferred to M11): control-scheme persistence, tilt rework,
          floating joystick, arena inset, raised entity-scale ceiling, control picker,
          pause overlay, centred score block, UI scaling, restyled death screen.
      ok  24/24 GUT scripts (137 tests, 516 asserts); gdformat/gdlint clean; headless
          `--quit-after 120` run exits 0; 35 `DIVERGENCE` tags.
      ok  final whole-branch review (opus) found 2 Critical + 4 Important, all fixed and
          re-reviewed clean: TOUCH release no longer flings the ship to centre; picker has
          a real minimum height; scheme indicated at launch; shard transform carries the
          arena origin; HUD anchors to `arena_origin`; calibration saved at capture.
      --  NOT yet run on a phone (the A55 dropped off adb mid-session). Every M2.5
          constant is PROVISIONAL: `MAX_ARENA_SCALE`, `MIN_INSET_*`, `MAX_INSET_RATIO`,
          `KNOB_RADIUS`, `MIN/MAX_UI_SCALE`, tilt sensitivity/smoothing. See VERIFY-ME.md.
      note  portrait (180/0) tilt axis mappings are unverified; only landscape (90) is
            backed by measured device poses. Game is landscape-locked.

- [ ] **M3 — Enemy roster**  deps: M2   *(code complete 2026-09-21, head `5bb5cc9`; DEVICE PASS PENDING)*
      plan  `docs/superpowers/plans/2026-09-20-m3-enemy-roster.md`
      **tick this box only after `godot/VERIFY-ME.md` §M3 is run on the A55**
      ok  `sim/enemy_swarm.gd` is the full port of `EnemySwarm.ts` minus `render()`:
          12 remaining behaviours, 7 formation spawners + `spawn_mode_armada`, both
          `trigger_*` dispatchers, full wave director, `on_enemy_killed`, `freeze_all`.
          LAW 3 member table verified complete by the final review.
      ok  `render/entity_layer.gd` draws all 13 types distinctly (`render()` relocated
          per spec §4.2/D4; radial gradients as two flat circles per M2 precedent).
      ok  30/30 GUT scripts (184 tests); six new spec files incl. `test_wave_director.gd`
          pinning every elite threshold on both sides of its boundary (seeded, ≥266
          spawn events, rarest branch p ≥ 0.09). gdformat/gdlint clean.
      ok  headless `--quit-after 120` exits 0; APK exports (30,294,124 bytes).
      note  "13 types spawn" reads as 12 spawnable + the SPIKE_MINE dispatch arm — the
            web game never spawns a spike mine either (plan open question 5).
      note  "8 formations" = seven `spawn*` formation methods + `spawn_mode_armada`.
      note  `freeze_all`, `spawn_sequential_gauntlet_wall`, `spawn_rotating_gate`,
            `spawn_mode_armada` and the gauntlet/code-red director branches have no
            caller until M4/M10 (`TODO(M4)`/`TODO(M10)` markers).
      --  NOT run on a phone (A55 off adb all session). See VERIFY-ME.md §M3.

- [ ] **M4 — Weapons**  deps: M2
      -- all 7 weapons activate with radius/duration read from the tuning table
      -- perk ranks visibly change values
      -- WEAPON_TUNING parity spec passes

- [ ] **M5 — Audio bake and SFX**  deps: M2
      -- every `play*` method in TiltAudio.ts has a baked .ogg that fires correctly
      -- a missing file logs and continues without crashing

- [ ] **M6 — Generative music**  deps: M5
      -- music plays and evolves across bars
      -- no dropouts over a 5-minute device run

- [ ] **M7 — Persistence and economy**  deps: M2
      -- GUT specs pass for perk cost curve, every buy_* method, all multipliers
      -- saves survive restart; a corrupted file falls back and is backed up

- [ ] **M8 — Armory UI**  deps: M7
      -- all 5 tabs render and operate on device within the landscape safe area
      -- purchases persist across a restart

- [ ] **M9 — Milestones**  deps: M7
      -- GUT specs cover goal evaluation for every category
      -- rail updates live during a run; toasts fire on completion

- [ ] **M10 — Modes**  deps: M3
      -- all 3 modes playable start to death
      -- gauntlet maze walls block and push; mode multipliers apply

- [ ] **M11 — Menu, cinematic, export, device pass**  deps: all
      -- cold boot → menu → cinematic → run → death → menu loops on device
      -- sustained 60 fps across a 5-minute run
      -- signed release build produced
