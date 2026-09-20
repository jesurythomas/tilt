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

- [ ] **M1 — Core loop and input**  deps: M0b
      plan  `docs/superpowers/plans/2026-09-20-m1-core-loop-and-input.md`
      -- tilt and touch both steer correctly in landscape on a device,
         verified in **two builds**: the committed `HYBRID` default for touch,
         then a temporary `GYRO` flip for tilt, reverted before the commit.
         The two schemes are mutually exclusive in the source
         (`GameOptions.ts:80`, `TiltGame.ts:1280`) and the toggle is M11's.
      -- grid renders and its spring-mass update runs; 60 fps
         (**criterion amended 2026-09-20**, spec §8 M1: it read "grid reacts to
         motion", which nothing in M1's scope can cause — `applyExplosion` is
         only ever called by kills, weapons, death and the cinematic, all M2+,
         and player motion never disturbs the grid in the web game. M1 draws
         the grid unconditionally, `# TODO(M7)` to gate it on
         `GameOptions.showGridlines`, and proves the spring in a GUT spec.)
      -- tuning constant-parity spec passes
      note  **physics tick is 120 Hz, not 60** (spec D8, amended 2026-09-20).
            `max_fps=60` still caps rendering. Verify with
            `grep -A2 '\[physics\]' godot/project.godot`.
      note  the Android accelerometer basis is **measured on device**, not
            assumed; the measured vectors go in HANDOFF.md as BASIS-EVIDENCE.

- [ ] **M2 — Vertical slice**  deps: M1
      -- full playable loop: spawn, fly, dodge, orb, nuke, score, die, restart
      -- 60 fps with 100 seekers on device

- [ ] **M3 — Enemy roster**  deps: M2
      -- all 13 enemy types spawn and behave per the TypeScript
      -- all 8 formations trigger
      -- GUT wave-director specs pass
      note  the `Types.Enemy` optional-float representation this module depends
            on is **fixed in M1 Task 3 Step 0**, not here. If that step was
            skipped, stop and do it before porting `EnemySwarm.ts`: the
            `=== undefined` branches at `EnemySwarm.ts:300, 339, 394, 463, 486`
            cannot fire while those fields default to `0.0`.

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
