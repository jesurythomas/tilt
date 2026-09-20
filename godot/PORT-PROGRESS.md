# Port Progress

The durable module checklist. Ticked only by the exit protocol in
`CONVENTIONS.md` §9, after the acceptance commands have actually been run.

Dependency map and resume instructions:
`docs/superpowers/plans/2026-09-20-tilt-to-live-godot-port-index.md`

- [x] **M0 — Scaffold**  deps: none   *(2026-09-20, commit `035ccdc`)*
      ok  `$GODOT --headless --path godot --import` exits 0
      ok  GUT suite runs headless: Scripts 1 / Tests 1 / Passing 1, exit 0
      ok  untyped GDScript is rejected (proof run observed — parse error
          `Variable "untyped_proof" has no static type. (Warning treated as
          error.)`; all nine required warnings confirmed at severity 2)
      ok  `gdlint` and `gdformat` 4.5.0 verified and pinned in CONVENTIONS.md §1.2
      ok  PORT-PROGRESS.md and HANDOFF.md exist

- [ ] **M0b — Android toolchain**  deps: M0   *(user action, ~4GB downloads)*
      -- export templates installed
      -- JDK 17 installed, Android SDK installed, ANDROID_HOME correct
      -- debug keystore generated, Android export preset added
      -- debug APK installs and launches on a physical device

- [ ] **M1 — Core loop and input**  deps: M0b
      -- tilt and touch both steer correctly in landscape on a device
      -- grid reacts to motion; 60 fps
      -- tuning constant-parity spec passes

- [ ] **M2 — Vertical slice**  deps: M1
      -- full playable loop: spawn, fly, dodge, orb, nuke, score, die, restart
      -- 60 fps with 100 seekers on device

- [ ] **M3 — Enemy roster**  deps: M2
      -- all 13 enemy types spawn and behave per the TypeScript
      -- all 8 formations trigger
      -- GUT wave-director specs pass

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
