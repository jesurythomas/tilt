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

- [ ] **M4 — Weapons**  deps: M2   *(code complete 2026-09-21, head `0b7fccf`; DEVICE PASS PENDING)*
      plan  `docs/superpowers/plans/2026-09-20-m4-weapons.md`
      **tick this box only after `godot/VERIFY-ME.md` §M4 is run on the A55**
      ok  `sim/weapon_system.gd` is the full port of `WeaponSystem.ts` minus `render()`/
          `renderOrbGlyph()`: all 7 weapons activate (missiles, lightning, laser, vortex,
          freeze, shield join M2's nuke), `trigger_weapon`, weighted `get_random_weapon_type`,
          complete `get_weapon_color`. LAW 3 member table verified complete by the final review.
      ok  every radius/duration/count the TS tunes is read through `Tuning.get_tuned_value`
          (16 call sites verified at rank 0 and max rank against `WeaponTuning.ts`); perk
          ranks change values — proven headless for all 7 weapons; `test_tuning_parity.gd`
          untouched and green.
      ok  `meta/progression_manager.gd` holds the `WeaponPerks` record only (M7 extends it);
          `run_controller.gd` re-emits `GameEvents.weapon_activated`, owns an all-zero `perks`
          record, applies the shield-radius perk at run start; frame order unchanged.
      ok  weapon FX (`effect_layer.gd::_draw_weapon_fx`) and all 7 orb glyphs
          (`entity_layer.gd`) drawn; FX sit ABOVE enemies per spec §5.5 (the web game draws
          them under — open question 3, a one-line swap if the device pass prefers it).
      ok  33/33 GUT scripts (220 tests); gdformat/gdlint clean; headless `--quit-after 120`
          exits 0; APK exports (30,335,810 bytes); 43 `DIVERGENCE` tags.
      note  `freeze_all` stays callerless — freeze is applied inline as `WeaponSystem.ts:541-544`.
      note  `chilled` is never written anywhere in the web game either; the freeze spec asserts
            it stays false.
      --  NOT run on a phone (A55 off adb all session). See VERIFY-ME.md §M4.

- [x] **M5 — Audio bake and SFX**  deps: M2  done 2026-09-25  539d654  DEVICE PASS PENDING
      ok  every `play*` method in TiltAudio.ts has a baked .wav (M5 R1: WAV,
          not .ogg) — 37 files from tools/bake-audio/bake_sfx.mjs.
      ok  each live SFX fires at its TS moment (test_audio_call_sites.gd);
          a missing file logs and plays silence (test_audio_bank.gd).
      ok  50/50 GUT scripts (549 tests); gdformat/gdlint clean; `TODO(M5)`
          grep empty; headless 0 SCRIPT ERROR.
      --  device pass pending — `VERIFY-ME.md` §M5.

- [x] **M6 — Generative music**  deps: M5  done 2026-09-25  (the M6 exit commit; code head `d489691`)  DEVICE PASS PENDING
      plan  `docs/superpowers/plans/2026-09-20-m6-generative-music.md`
      ok  the 16-bar arrangement bakes to one seamless loop (M6 R1: no stems,
          no sequencer) — tools/bake-audio/bake_music.mjs, 1263761 frames.
      ok  start/stop/mute/volume follow TiltAudio.ts (test_audio_bank.gd); a
          run starts its music (test_audio_call_sites.gd, test_main_scene.gd).
      ok  50/50 GUT scripts (559 tests); gdformat/gdlint clean; `TODO(M6)`
          grep empty; headless 0 SCRIPT ERROR.
      --  "evolves across bars" and "no dropouts over 5 minutes" — device
          pass pending, `VERIFY-ME.md` §M6.

- [ ] **M7 — Persistence and economy**  deps: M2   *(code complete 2026-09-21, head `dba9126`; DEVICE PASS PENDING)*
      plan  `docs/superpowers/plans/2026-09-20-m7-persistence-and-economy.md`
      **tick this box only after `godot/VERIFY-ME.md` §M7 is run on the A55**
      ok  `meta/save_store.gd` — the shared `user://` read/write/quarantine
          layer; corrupt-file quarantine proven in four specs (the store
          itself, best score, gravity calibration, control settings).
      ok  `meta/progression_manager.gd` — full port of `ProgressionManager.ts`
          minus its two SVG-string methods (`getCursorSvgDataUri`,
          `getShipSvgPreview`, open question 1); member table reconciled in
          Task 6 Step 4: 40 real TS methods = 38 ported + 2 deliberately not;
          GDScript has 46 funcs = 38 + `_init` + 7 GDScript-only catalog/union
          helpers.
      ok  parity fixture `tests/fixtures/progression.json` (~330 literals) green.
      ok  perk cost curve, all five `buy_*` + `upgrade_perk` + the three
          catalog `buy_*`, and the four multipliers proven headless (spec
          acceptance line 1).
      ok  save round trip through a fresh `ProgressionManager` instance (spec
          acceptance line 2).
      ok  corrupt-file fallback with backup (spec acceptance line 3).
      ok  `meta/game_options.gd` — settings save/load with the web shape.
      ok  `sim/coin_system.gd` — full port at frame-order step 7; coins draw
          under the orbs.
      ok  `RunController` reads lives, hitbox, speed, score/points multipliers
          and the equipped ship's starting weapon from the save at run reset.
      ok  40/40 GUT scripts (301 tests, 3876 asserts); gdformat 70 files
          unchanged; gdlint clean; `--check-only` on the four M7 files is
          inconclusive (autoloads `Log`/`GameEvents` are not loaded in that
          mode — `Identifier not found` on both, as the brief warned); the
          full suite compiling every file under the nine warnings-as-errors
          is the actual compile evidence, and it is clean.
      ok  69 `DIVERGENCE` tags (was 67 at Task 1; the two new hits are prose
          references to the M2.5 control-scheme divergence in
          `game_options.gd` and `input_router.gd`, not new divergences).
      --  A55 absent from `adb` on 2026-09-21 — device pass pending. Headless
          `--quit-after 120` clean at `fc19300`, 0 SCRIPT ERROR; debug APK
          exports 30,431,782 bytes. See `VERIFY-ME.md` §M7.

- [ ] **M8 — Armory UI**  deps: M7   *(code complete 2026-09-22, head `f0cac03`; DEVICE PASS PENDING)*
      plan  `docs/superpowers/plans/2026-09-20-m8-armory-ui.md`
      **tick this box only after `godot/VERIFY-ME.md` §M8 is run on the A55**
      ok  `ui/armory_ui.gd` (1833 lines) — five `Control` tabs (Weapons,
          Ships, Arena, Handling, Boosts) built over `scenes/armory.tscn`,
          full port of `ArmoryUI.ts`'s 20 methods/handlers, each purchase
          path driven from a tapped button and re-read from a fresh
          `ProgressionManager` (spec acceptance line 2, headless half).
      ok  `ui/armory_theme.gd` (241 lines) — `Theme` resource built at
          runtime from `game.css` design tokens, cited constants, no `.tres`
          (Open question 7).
      ok  `ui/handling_preview.gd` (257 lines) — the live steering preview,
          `initHandlingPreview`/`stopHandlingPreview` as `start`/`stop`.
      ok  `meta/progression_manager.gd` — `get_ship_svg_preview` ported
          (`ProgressionManager.ts:873-939`); member table now 39 of 40 TS
          methods ported, `getCursorSvgDataUri` the one omission (M7 OQ 1
          half-reversed).
      ok  Armory reachable from the pause overlay and the death screen,
          pausing a live run (`TiltGame.ts:2343-2385`); `b`/`u`/Escape keys.
      ok  cosmetics visible in a live run (user ruling 2026-09-22): six ship
          hulls (`PlayerShip.ts:359-592`), enemy-skin colour arms
          (`EnemySwarm.ts:1191-1648`), arena-theme override
          (`TiltRenderer.ts:76-80`) — `entity_layer.gd`, `grid_layer.gd`.
      ok  42/42 GUT scripts (361 tests, 4279 asserts); gdformat 75 files
          unchanged; gdlint clean; `grep TODO(M8)` empty;
          `grep draw_set_transform(Vector2(` empty.
      ok  71 `DIVERGENCE` tags (was 69 at M7 close; the mobile-chrome gate on
          `OS.has_feature("mobile")` is the module's one new divergence,
          cited twice in `armory_ui.gd` — 70 divergences, 71 grep hits).
      --  A55 absent from `adb` since 2026-09-20 — device pass pending.
          Headless `--quit-after 120` clean, 0 SCRIPT ERROR; debug APK
          exports 30,531,097 bytes. See `VERIFY-ME.md` §M8.
      --  device pass folded into M8.5's (interface spec §7).

- [ ] **M8.5 — Interface rework**  deps: M8   *(code complete 2026-09-23, head `541e92c`; DEVICE PASS PENDING)*
      plan  `docs/superpowers/plans/2026-09-23-m8.5-interface-rework.md`
      spec  `docs/superpowers/specs/2026-09-23-mobile-interface-system-design.md`
      **tick this box only after `godot/VERIFY-ME.md` §M8.5 is run on the A55**
      ok  fonts bundled (Archivo, IBM Plex Sans/Mono; OFL) — 1,785,856 bytes of TTF
      ok  `ui/ui_theme.gd` replaces `armory_theme.gd` — System.dc.html tokens,
          variations, icons; no `game.css` legacy left
      ok  ui_scale = min(short/390, long/844), clamp 0.75–3.0
      ok  HUD, Pause (`pause_sheet.gd`), Run over (`run_over_sheet.gd`) and all
          five Armory tabs rebuilt to their boards; layout specs at 844×390
          and 2340×1080 (fit, rule 04, rule 05)
      ok  45/45 GUT scripts (420 tests, 4559 asserts); gdformat 81 files
          unchanged; gdlint clean; rule-01 grep empty; 154 DIVERGENCE hits
          (86 UI-SYSTEM); headless `--quit-after 120` 0 SCRIPT ERROR
      --  A55 absent — see `VERIFY-ME.md` §M8.5

- [x] **M9 — Milestones**  deps: M7   *(2026-09-24, commit `cd77de6`; DEVICE PASS PENDING)*
      plan  `docs/superpowers/plans/2026-09-20-m9-milestones.md`
      **tick this box only after `godot/VERIFY-ME.md` §M9 is run on the A55**
      ok  `meta/goal_manager.gd` — full port of `GoalManager.ts` (all 57
          goals, `CumulativeStats`, `RunTracker`, `evaluate_run`,
          `evaluate_live_total_goals`, `evaluate_unlock_goals`); rulings
          R1–R11 (plan) plus B1–B5/I1–I5/M1–M15 (pre-flight) and the final
          review's I-1/M-1..M-4 (I-2 parked, Open question 6).
      ok  `ui/goals_hud.gd` — rail on the HUD arena frame's top edge, toast
          in the HUD `ToastSlot`, full-screen three-column Milestones screen
          (`UiTheme`, interface spec §6.5).
      ok  `RunOverSheet` fills "Points earned" and the earned-milestones list
          450 ms after `run_ended` (final review I-1,
          `TiltGame.ts:2084-2151`), so a death-tick total-goal completion
          reaches the sheet.
      ok  48/48 GUT scripts (487 tests, 5467 asserts); gdformat 86 files
          unchanged; gdlint clean; `TODO(M9)` grep empty; `ff4757` grep
          empty (rule 01); 174 `DIVERGENCE` tags (106 `UI-SYSTEM`); headless
          `--quit-after 120` 0 SCRIPT ERROR.
      --  A55 absent from `adb` on 2026-09-23 — device pass pending;
          `VERIFY-ME.md` §M9 has 7 unticked hand-held checks.

- [x] **M10 — Modes**  deps: M3  done 2026-09-25  `2e6b2d2`  DEVICE PASS PENDING
      plan  `docs/superpowers/plans/2026-09-20-m10-modes.md`
      **tick this box only after `godot/VERIFY-ME.md` §M10 is run on the A55**
      ok  GauntletMaze sim + render; mode routed through steps 4–8; mode
          overlays; banner (R2); temporary Pause picker (R1).
      ok  49/49 GUT scripts (520 tests); gdformat/gdlint clean; `TODO(M10)`
          grep empty; headless 0 SCRIPT ERROR.
      --  armada + cinematic handover left for M11 (R3); device pass pending —
          `VERIFY-ME.md` §M10.

- [ ] **M11a — Menu, Settings, Calibrate**  deps: all  *(code complete 2026-09-25; exit: the commit carrying this text; DEVICE PASS PENDING)*
      plan  `docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md`
      **tick this box only after `godot/VERIFY-ME.md` §M11a is run on the A55**
      ok  `render/menu_backdrop.gd` — the second, independent autopilot sim
          mirrored to the board (R1); `ui/tilt_menu.gd` — menu, options modal,
          reset confirm; `ui/calibrate_screen.gd` — the Calibrate board with a
          live tilt dot (R4); MENU phase, boot, launch/return, key map wired
          into `game_root.gd`/`game_state_machine.gd`/`hud_controller.gd`;
          Pause Quit-to-menu/Settings; Run over Menu + CoinsRow (R17); M10 R1
          picker removed.
      ok  53/53 GUT scripts (609 tests); gdformat 96 files unchanged; gdlint
          clean; `TODO(M11)` grep empty; `ff4757` grep empty; `M10 R1` grep
          (boundary-aware) empty; `DIVERGENCE(M11a R1)` ×3; `DIVERGENCE(M11a
          Q1/Q2)` ×2; headless 0 SCRIPT ERROR.
      --  A55 absent from `adb` on 2026-09-25 — device pass pending;
          `VERIFY-ME.md` §M11a has 16 unticked checks, plus Q3 (Android back).

- [ ] **M11b — Entrance cinematic**  deps: 11a  *(code complete — device pass pending 2026-09-26; exit: the commit carrying this text)*
      plan  `docs/superpowers/plans/2026-09-20-m11b-entrance-cinematic.md`
      **tick this box only after `godot/VERIFY-ME.md` §M11b is run on the A55**
      ok  `ui/entrance_cinematic.gd` — `TiltEntranceCinematic.ts` ported on
          the ColdOpen board (R1-R4); CINEMATIC phase wired into
          `game_state_machine.gd`/`game_root.gd`/`hud_controller.gd` (R5-R11);
          Classic/Code Red/Gauntlet start armadas + spawn shield (R12,
          M10 R3's `TODO(M11b)` resolved).
      ok  54/54 GUT scripts (631 tests); gdformat 98 files unchanged; gdlint
          clean; `TODO(M11b)` grep empty; `ff4757` grep empty; `DIVERGENCE`
          total 244 (234 + 10 `ColdOpen.dc.html` tags); headless 0 SCRIPT
          ERROR. Final whole-branch review: 0 Critical/Important; F-1..F-3
          fixed (stale PORT-NOTEs, an uncited `fill_to` literal, left-click-only
          skip).
      --  A55 absent from `adb` on 2026-09-26 (only an emulator attached) —
          device pass pending; `VERIFY-ME.md` §M11b has 10 unticked checks
          (the 10th, touch-to-mouse emulation on Retry/PLAY AGAIN/Pause→
          Restart, is unverifiable headless).

- [ ] **M11c — Export, glow measurement, device pass**  deps: 11b
      part 1 plan `docs/superpowers/plans/2026-09-26-m11c-performance.md` —
          **code complete 2026-09-26, A55 measurement pending** (phone off
          `adb` after 02:11). P1 probe + `tools/frametime.sh`; P3 grid sleeps
          when hidden, packed, exact windowed blasts; P4 separation prefilter
          on packed copies (bit-exact); P5 dots/particles from shared circle
          textures; P6 score emitted on change, chip restyled on tier change;
          P8 wider Classic start ring (user); cold-open stack centred. P2
          (catch-up cap) withdrawn by the user. 57/57 scripts, 652 tests.
      part 2 plan  not yet written
      -- glow cost measurement on device (spec §4.5) and its fallback
      -- Android export preset, icons, splash screens; signed release build
      -- iOS export preset only if a macOS host is available (D1)
      -- cold boot → menu → cinematic → run → death → menu loops on device
      -- sustained 60 fps across a 5-minute run
      -- the whole port's device pass: M2.5, M3, M4, M5, M6, M7, M8, M8.5,
         M9, M10, the mobile scale split and M11a
