# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

**M11a in progress: Tasks 1–7 landed; next Task 8 (exit).** The user split M11 into M11a (menu, Settings, Calibrate), M11b (entrance cinematic) and M11c (export + device pass) on 2026-09-25, and ruled R1–R4 (backdrop mirrored to the board; port screen shake + wire the halo; omit Aim line; Calibrate with a live tilt dot). Plan `docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md` (8 tasks, rulings R1–R17). Plan reviewed 2026-09-25; the user ruled **Q1 = fix** (Reset also deletes progression and best score, `DIVERGENCE(M11a Q1)`, R10) and **Q2 = apply at once** (Settings' Sound/Music route to `GameRoot.set_sfx_enabled`/`set_music_enabled`, `DIVERGENCE(M11a Q2)`, R9); Q3 (Android back) stays for the device pass. Execution: **subagent-driven** (one implementer per task, then review). Task 1 (`MenuBackdrop`, `godot/src/render/menu_backdrop.gd`) landed: 51/51 scripts, 566 tests (+7), `DIVERGENCE(M11a R1)` ×3 in this file (the module's Step 4 exit check expects a cumulative total of 4 across `godot/src`, so a 4th lands in a later task). Task 2 (screen shake + halo wiring, R2) landed: `RunController.trigger_shake` Callable ported at `lose_life`/`trigger_player_death`; `GameRoot.trigger_shake`/`camera_shake`/`apply_readability` drive the arena layers' `position` and `EntityLayer.set_high_contrast_halo`; 51/51 scripts, 570 tests (+4). Task 3 (`TiltMenu`, `godot/src/ui/tilt_menu.gd`, the menu screen on Main.dc.html) landed: root Control stays visible, `show_menu`/`hide_menu` toggle only `MenuContainer` (ruling P1), `render()` rebuilds `MenuContainer`; not yet wired (Task 4 adds it to main.tscn and must anchor it full-rect); the Settings gear is inert until Task 5; 52/52 scripts, 579 tests (+9). Task 4 (the MENU phase) landed: boot enters `MENU` (menu shown, backdrop stepping at real `delta`, layers rebound to the backdrop per R13), `GameRoot.launch_run`/`return_to_menu`/`is_in_menu`, the TS key map (p/Escape, Space/Enter/r in `GAME_OVER`), `Menu` node in `main.tscn` between `Hud` and `GoalsHud`, HUD R12 menu visibility; main-scene boot tests now `await _boot_into_run()`; 52/52 scripts, 588 tests (+9, incl. a regression test for the R12 HUD guards; `launch_run` now ports `options.setMode`). Task 5 (Settings, Settings.dc.html) landed: `TiltMenu.open_options_modal`/`close_options_modal`/`is_options_open`; `OptionsModal` and `ResetConfirm` are siblings of `MenuContainer` rebuilt on every open/toggle (TS re-render); the menu gear opens it; signals `readability_changed`, `sfx_toggled`, `music_toggled`, `reset_confirmed` wired in `GameRoot._ready` to `apply_readability`, `set_sfx_enabled`, `set_music_enabled`, `reset_progress`; `GameRoot.reset_progress_files()` (static) deletes options, both goal files, progression and best score and keeps ControlSettings (`DIVERGENCE(M11a Q1)`); Settings audio applies at once (`DIVERGENCE(M11a Q2)`); the Calibrate link emits `calibrate_screen_requested` (Task 6 connects it); switch cards are 64 tall (48 px switch target) where the board draws 60; 52/52 scripts, 599 tests (+11). Task 6 (Calibrate, `godot/src/ui/calibrate_screen.gd`, Calibrate.dc.html) landed: `CalibrateScreen` (Control, single-file — `Disc`'s ring/crosshair/dot draw through its own `draw` signal rather than a second script) full-rect over a void scrim, left block (caps/title/body + Set level/Cancel), a 230×230 Disc with base circle, crosshair, dashed top-speed ring, still ring and a live dot at `dot_offset()` (`tilt_vector.limit_length(1.0) * 66.0 * ui_scale`, centred at rest — PORT-NOTE, R4), and a "still"/"top speed" legend; wired in `GameRoot._ready`/`resize_canvas` (`open_calibrate_screen` starts the sensor and opens it; `set_level_requested` fires before `closed` so calibration reads a live sensor; `_on_calibrate_closed` stops the sensor back in the menu); `game_root.gd` now carries `# gdlint:ignore=max-public-methods` (as `audio_bank.gd`) since the wiring pushed it past 20 public methods; 53/53 scripts, 605 tests (+6); `DIVERGENCE` count 232 (was 181 at the M6 exit, mostly this screen's board-only literals). Task 7 (Pause and Run over reach the menu) landed: Pause gains `QuitToMenuButton` (under Restart run) and `PauseSettingsButton` (beside Armory; opens the menu's options modal over the paused run via `GameRoot.open_options_from_pause`); Run over gains `GameOverMenuButton` (before Spend) and a `CoinsRow` ("Coin pickups", `"<n> · +<pts> pt|pts"`, shown iff a coin was picked up, R17; `RunOverSheet.set_coins`); Quit/Menu call `GameRoot.return_to_menu`; the M10 R1 Pause mode picker and `GameRoot.set_game_mode` are gone; `TiltMenu.close_options_modal` also hides `ResetConfirm`; 53/53 scripts, 609 tests (+6 −2 deleted picker tests); `DIVERGENCE` count 232. **Next: M11a Task 8 (exit).** A55 still absent from `adb` on 2026-09-25.

**M6 — Generative music: code-complete, device pass pending.** Exit verified at
`d489691` (2026-09-25); the exit commit carries this text. Plan
`docs/superpowers/plans/2026-09-20-m6-generative-music.md`. User ruling M6 R1: the TS
arrangement takes no game input, so `tools/bake-audio/bake_music.mjs` renders it once,
through `TiltAudio.ts`'s own `scheduleStep`, to a seamless loop
(`godot/assets/audio/music/music_loop.wav`). `AudioBank` plays it, and a run starts it in
`RunController.reset_run` until M11's cinematic exists. Full section:
`## M6 — what landed` below. Device checks: `VERIFY-ME.md` §M6. **Next: plan M11**
(see Next below).

**M5 — Audio bake and SFX: code-complete, device pass pending.** Exit verified at
`539d654` (2026-09-25); the exit commit is the one carrying this text. Plan
`docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md`. 37 SFX baked from
`TiltAudio.ts` to WAV (M5 R1) and played through a 32-voice `AudioBank`; music is
still `TODO(M6)`. Full section: `## M5 — what landed` below. Device checks:
`VERIFY-ME.md` §M5 (A55 absent on 2026-09-25).

**M10 — Modes: code-complete, device pass pending.** Final commit `2e6b2d2`
(exit commit for the whole module — final review fixes F-1..F-4 landed at
this same SHA). Plan `docs/superpowers/plans/2026-09-20-m10-modes.md`. Full
section: `## M10 — what landed` below.

**Final review fixes (M9)** (`.superpowers/sdd/2026-09-20-m9-milestones/final-review.md`,
`final-fix-report.md`, commit `cd77de6`): **I-1** — Run over now fills/shows 450 ms after
`run_ended`, ported from `TiltGame.ts:2084-2151` (`HudController._on_run_ended`
starts a one-shot `Timer`; stopped on Retry or any phase change so a stale
fill cannot reopen the sheet), so a total-goal completion on the death tick
(step 8, `run_controller.gd:227`) now reaches "Points earned" and the
balance. One script-level regression test pins the death-tick order (487th
test, +1 over Task 7's 486). **M-1, M-3, M-4** — PORT-NOTE added at `goals_hud.gd`'s Escape
handling; `VERIFY-ME.md`'s M9 Toast line reworded (Armory-close/mid-run total,
calibrate marked pending I-2); `goal_manager.gd:24`'s stale process-note
replaced. **I-2** (toast under Pause/Armory) is parked for the user — plan
Open question 6. Full section: "## M9 — what landed" below.

Last completed module before M10: **M9 — Milestones**, code complete
2026-09-24 (head `cd77de6`).
Code-complete, **device pass pending** (none ticked in `PORT-PROGRESS.md`,
all marked `DEVICE PASS PENDING`):
**M2.5 — Mobile feel** (head `37f9fd4` + the user's tuning `c023e09`),
**M3 — Enemy roster** (head `5bb5cc9`), **M4 — Weapons** (head `0b7fccf`),
**M7 — Persistence and economy** (head `dba9126`),
**M8 — Armory UI** (head `f0cac03`; its device pass is folded into M8.5's),
**M8.5 — Interface rework** (head `541e92c`),
**M9 — Milestones** (head `cd77de6`; its device pass is its own, `VERIFY-ME.md` §M9),
**M10 — Modes** (head `2e6b2d2`; its device pass is its own, `VERIFY-ME.md` §M10,
10 unticked checks — the A55 was absent from `adb` on 2026-09-25).
Also landed after M4/M8, still device-unchecked: **HUD score feedback**
(`9cc3e8f..31bf2ce`) and the **mobile scale split** (2026-09-22, see its
section below; the user skipped its A55 pass while the phone is absent).

What M8.5 did: the mobile-redesign boards (`peril-point-mobile-redesign/*.dc.html`)
became the visual authority for every screen (spec
`docs/superpowers/specs/2026-09-23-mobile-interface-system-design.md`, plan
`docs/superpowers/plans/2026-09-23-m8.5-interface-rework.md`). Fonts
(Archivo, IBM Plex Sans/Mono, OFL) are bundled; `ui/ui_theme.gd` replaces
`armory_theme.gd` with the System board's tokens and variations; HUD, Pause,
Run over and all five Armory tabs are rebuilt on it. Table in
`## M8.5 — what landed`.

**ui_scale ruling** (spec §4.3, plan time): `ui_scale = min(short/390,
long/844)`, clamped 0.75–3.0 — the width term keeps a 1280×720 window (1.52)
from overflowing the 700-px Run over sheet.

**Rulings A–P** (the plan's "Rulings" table has the citations):
- A — HUD lives hidden for a one-life run; count = `maxLivesThisRun`.
- B — weapon timer: shield wins, else the longest-remaining timed weapon.
- C — multiplier `"n×"` Chip tinted by `tier_color_for`, hidden at 1×.
- D — Pause stats `"<score> · <m:ss> · <mode>"`.
- E — Pause Calibrate shown only for the GYRO scheme.
- F — Calibrate = request permission, then calibrate; the toast is `TODO(M9)`.
- G — Sound/Music switches write and save options; music only while PLAYING.
- H — New best banner iff `is_new_best and best_score_diff > 0`.
- I — Run over earned = coin points (+ milestones, `TODO(M9)`); Spend = balance.
- J — Best chain `"%d×"` of `max(1, max_multiplier)`.
- K — cost buttons: grouped digits, no unit; ship buy `"600 pts"`; `"Max"` disabled.
- L — keystone locked = not unlocked and not affordable → LockedCard + lock glyph.
- M — Armory captions keep the TS strings in caps; preview caption/legend use spec strings.
- N — TS content with no board slot kept in board style (`TrackValue_*`, `LoadoutName`).
- O — Handling: tilt slider 0.5–2.0 (stored clamp 0.4–2.5); Reset still resets deadzone to 4.0.
- P — `ControlPicker` is Segmented, Touch | Tilt (+ Keyboard off-mobile), no `ButtonGroup`.
- Pre-flight M14 (applied in Tasks 6–7): spec-quoted explain lines win over TS strings.

Branch: `feat/godot-port` (no upstream; nothing pushed).

> ### ⚠ Read `godot/VERIFY-ME.md`
> Every check that needs a hand on the phone or a decision from the user is
> collected there, per module. M2.5's constants are all provisional until its
> section is run. **M7, M8 (folded into M8.5), M8.5, M9, M10 and "Mobile
> scale split" device checks are all unrun** — the A55 has been absent from
> `adb` since 2026-09-21. The M8.5 debug APK exported at 31,561,743
> bytes (+1,030,646 over M8, mostly fonts).

## How to verify right now

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

node tools/bake-audio/bake_sfx.mjs | tail -1     # expect: OK: 37 files in …
node tools/bake-audio/bake_music.mjs | tail -1   # expect: OK: music_loop.wav 1263761 frames (loop_end) in …
git status --short godot/assets/audio/           # expect: empty (both bakes are deterministic)
tools/run_tests.sh                        # expect: OK: 50/50 scripts (559 tests, 17696 asserts)
gdformat --check godot/src godot/tests    # expect: 90 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "TODO(M6)" godot/src/ godot/tests/   # expect: nothing
grep -rniE "ff4757" godot/src/ui/         # expect: nothing (rule 01)
grep -rn "DIVERGENCE" godot/src/ | wc -l  # expect: 181
grep -rn "DIVERGENCE(M6" godot/src/ | wc -l   # expect: 3
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR"   # expect: 0
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "missing baked"   # expect: 0
git checkout godot/project.godot          # headless runs strip one default-valued line; never commit that
```

Every command above was run fresh at M9 Task 7 (2026-09-23) and passed:
`OK: 48/48 scripts collected, all tests passed` (Tests 486, Passing 486,
Asserts 5462; GUT also prints `Deprecated 5`, pre-existing); `86 files would
be left unchanged`; `Success: no problems found`; the TODO(M9) grep printed
nothing; the ff4757 grep printed nothing; DIVERGENCE `174`, UI-SYSTEM `106`;
SCRIPT ERROR count `0`; `git status --short` empty afterwards (working tree,
before this task's own changes were staged). The module's leftover-marker
grep (a `TODO` tagged with the module id) finds nothing under `godot/`.

Re-run after the final review's I-1 fix and again fresh at Task 9's exit
(2026-09-24, commit `cd77de6`): `OK: 48/48 scripts collected, all tests
passed` (Tests 487, Passing 487, Asserts 5467 — +1 script-level regression
test for the death-tick order over Task 7's 486); `86 files would be left
unchanged`; `Success: no problems found`; TODO(M9) grep empty; ff4757 grep
empty; DIVERGENCE `174`, UI-SYSTEM `106` (unchanged from Task 7 — the I-1 fix
added no new UI literals); SCRIPT ERROR count `0`; `git status --short` empty
before and after. See "Final review fixes" above and "## M9 — what landed"
below.

Re-run fresh at **M10 Task 5's exit** (2026-09-25, temporary Pause mode
picker, R1): `OK: 49/49 scripts collected, all tests passed` (Tests 519,
Passing 519, Asserts 17277); `gdformat --check` — `88 files would be left
unchanged`; `gdlint` — `Success: no problems found`; DIVERGENCE **177** total,
`DIVERGENCE(UI-SYSTEM)` **106** (unchanged), `DIVERGENCE(M10 R1)` **3** (the
picker's stand-in tags in `pause_sheet.gd` and `hud_controller.gd`).

Re-run fresh again at **M10 Task 7's exit** (2026-09-25, commit `2e6b2d2`,
after the final-review fix wave F-1..F-4 — see "## M10 — what landed"):
`OK: 49/49 scripts collected, all tests passed` (Tests **520**, Passing 520,
Asserts **17359** — +1 script over Task 5's 519, the F-1 stripe brute-force
equality test); `gdformat --check` — `88 files would be left unchanged`;
`gdlint` — `Success: no problems found`; `grep -rn "TODO(M10)"` printed
nothing; `grep -rniE "ff4757" godot/src/ui/` printed nothing; DIVERGENCE
**177** total, `DIVERGENCE(UI-SYSTEM)` **106**, `DIVERGENCE(M10 R1)` **3**
(all unchanged from Task 5 — F-1..F-4 added no new literals or picker tags);
headless `--quit-after 120` SCRIPT ERROR count **0**; `git status --short`
empty both before this task's own doc changes were staged and after
`git checkout godot/project.godot`. This is the module's exit evidence —
M10 is now code-complete, device pass pending.

Re-run fresh at **M5 Task 6's exit** (2026-09-25, at `539d654`): bake printed
`OK: 37 files` and left `godot/assets/audio/sfx/` unchanged; `OK: 50/50 scripts
collected, all tests passed` (Tests **549**, Passing 549, Asserts **17667**);
`90 files would be left unchanged`; `Success: no problems found`; TODO(M5) and
ff4757 greps empty; DIVERGENCE **178**, `DIVERGENCE(M5 R2)` **1**; headless
SCRIPT ERROR **0**, "missing baked sfx" **0**; `git status --short` empty after
`git checkout godot/project.godot`. This is M5's exit evidence.

Re-run fresh at **M6 Task 4's exit** (2026-09-25, at `d489691` plus the review's
VERIFY-ME wording fix): the SFX bake printed `OK: 37 files`, the music bake printed
`OK: music_loop.wav 1263761 frames` (`kept`: within 1 LSB of the committed file), and
`godot/assets/audio/` was unchanged; `OK: 50/50 scripts collected, all tests passed`
(Tests **559**, Asserts **17696**); `90 files would be left unchanged`; `Success: no
problems found`; TODO(M6) and ff4757 greps empty; DIVERGENCE **181**,
`DIVERGENCE(M6` **3**; headless SCRIPT ERROR **0**, "missing baked" **0**. This is
M6's exit evidence.

`--check-only -s` on `src/meta/progression_manager.gd`, `game_options.gd`,
`save_store.gd`, `sim/coin_system.gd` each fail with `Identifier not found:
Log` or `GameEvents` — **expected and inconclusive**: `--check-only` does not
load autoloads, so any file that calls `Log.*` or `GameEvents.*` at class
scope fails this check regardless of correctness. The real compile evidence
is `tools/run_tests.sh` passing: it compiles every script under the project's
nine warnings-as-errors. Don't read a `--check-only` failure on these four
files as a regression.

## App identity and toolchain

| | |
|---|---|
| Package / label | `com.jtg.perilpoint` / **Peril Point** |
| Godot | `4.7.2.stable` — **not on PATH**, use the path above, always the `_console` exe |
| GUT | 9.6.1 vendored at `godot/addons/gut/` (never lint/format it) |
| gdtoolkit | 4.5.0 on PATH |
| Device | **SM_A556E** (Galaxy A55), serial `RRCXB04L8EJ`; always pass `-s` |
| ADB | `C:\Users\Jesury\AppData\Local\Android\Sdk\platform-tools\adb.exe` |

The source web game keeps the name *Tilt to Live* in `web/src/tilt-to-live/`
and in every `# PORT:` citation. Never rename those — Law 1 depends on them.

## M2.5 — what landed

Spec `docs/superpowers/specs/2026-09-20-m2.5-mobile-feel-design.md`; plan
`docs/superpowers/plans/2026-09-20-m2.5-mobile-feel.md`. 23 commits,
`7de1fa2..37f9fd4`.

| Area | Files |
|---|---|
| Control-scheme persistence | `src/native/control_settings.gd` → `user://peril_point_settings.json` |
| Tilt rework (deferred calibration, one rotation transform, sensitivity/smoothing) | `src/input/tilt_input.gd` |
| Floating joystick | `src/native/floating_joystick.gd`, `src/render/joystick_layer.gd` |
| Arena inset (origin-offset model) | `src/core/game_root.gd` (`arena_origin`, `arena_inset()`, `MAX_ARENA_SCALE`), the four render layers, `src/input/touch_input.gd` |
| Picker, pause, UI scale, HUD anchoring | `src/ui/control_picker.gd`, `src/ui/hud_controller.gd`, `scenes/control_picker.tscn`, `scenes/main.tscn` |
| Tests | `tests/test_control_settings.gd`, `test_floating_joystick.gd`, `test_arena_inset.gd`, `test_tilt_input_device.gd`, `test_main_scene.gd` (+ additions to existing specs) |

**Deliberately untouched (spec §2.3):** `player_ship.gd`, `enemy_swarm.gd`,
`weapon_system.gd`, `run_controller.gd`, `particle_engine.gd`,
`score_manager.gd`. The inset is an origin offset; the simulation never learns
it exists. Verified zero changes across the whole range.

**Deferred to M11 knowingly:** death-screen asset research (spec §7.5, D8).

### Why `MAX_ARENA_SCALE` is 1.75 (read before touching it)

`arena_scale()` is `clamp(min(w,h)/680, 0.60, MAX_ARENA_SCALE)`, cited from
`TiltGame.ts:2422-2431`. On the desktop window (1267×717) the raw value is
1.054 — under the old 1.15 ceiling and confirmed good by the user. On the A55
(2340×1080) the raw value is 1.588 and the old ceiling cut it to 1.15; that cut
*was* the "everything is too small" defect. The proportion the phone needs
(1080/717 = 1.506) equals the formula's own unclamped ratio (1.588/1.054), so
the formula was always right. A post-hoc multiplier was rejected because it
would also inflate the desktop. `tests/fixtures/arena_scale.json` is TS ground
truth and must **not** be regenerated; `test_arena_scale.gd` enforces exact
parity below `TS_CEILING = 1.15` and bounds the divergence above it.

### Final-review fixes (2026-09-21) — the ones the device pass must confirm

The whole-module review found two Critical and four Important defects, all
fixed headless and re-reviewed clean:

- TOUCH scheme: on release the ship used to fly to the arena centre
  (`game_root.gd` routed on `is_active`, falling back to a frozen `mouse_pos`).
  Now routes on scheme; idle stick → damping. Untestable headless
  (`OS.has_feature("mobile")` is false on the test host) → VERIFY-ME check 5.
- `ControlPicker` root had no minimum size → collapsed to 0 px, buttons
  overlapping PLAY AGAIN / RESUME. Now sized in `set_ui_scale()`; asserted in
  `test_main_scene.gd`.
- Scheme never indicated at launch (`_sync_pickers` ran before
  `GameRoot._ready`). Now synced when each surface opens; tested.
- `effect_layer.gd` SHARD transform and `entity_layer.gd` player transform
  both dropped `_arena_origin` (`draw_set_transform` replaces, never composes).
  Both fixed; `grep "draw_set_transform(Vector2(" godot/src/render/` is empty.
- HUD anchored to the viewport edge instead of `arena_origin`. Now reads it.
- Gravity calibration was persisted one calibration stale. Now saved at capture.

### Accepted gaps

- `GameRoot._process()` must call `_joystick_layer.queue_redraw()`; deleting
  that line regresses silently with all tests green (Godot exposes no way to
  observe `queue_redraw`). The guard is VERIFY-ME check 5.
- Portrait (180/0) tilt axis mappings in `tilt_input.gd::apply_gravity` are
  unverified; only landscape (90) is backed by measured poses. Landscape-locked.
- `DisplayServer.get_display_safe_area()` under `content_scale_mode = disabled`
  is assumed to report in viewport pixels. Not verified — VERIFY-ME §safe-area.
- Deferred minors: base font sizes duplicated between scene (32/20/24) and
  controller (44/22/26) — spec §7.2 wanted them in the scene only; joystick's
  `OS.has_feature("mobile")` gate is undocumented in its tag; a few named
  radii/segment counts in `joystick_layer.gd:124`, `control_settings.gd:145-149`,
  `floating_joystick.gd:17-19` lack citations; a re-press by the same touch
  index after a lost release is ignored for one cycle; TILT is offered on
  desktop; `test_render_layers.gd` origin tests are smoke-only; three
  `@warning_ignore("unsafe_cast")` in `control_settings.gd` could follow
  `tilt_input.gd:353`'s cast-free pattern; the round-trip calibration test
  still calls `save_calibration()` redundantly.

## Process lessons carried forward

- **Seven of seven implementers that stopped to ask found a real plan defect**
  (enum cast, swapped tilt axes, native `VirtualJoystick` class-name clash,
  fixture regeneration, missing `queue_redraw`, `Button.button_pressed` no-op
  without `toggle_mode`, plus the final review's transform-replacement class).
  Treat a failing brief-specified test as evidence the brief may be wrong.
- Check every new `class_name` with `ClassDB.class_exists()`.
- `draw_set_transform` is absolute: every per-entity transform must add
  `_arena_origin`. Grep for `draw_set_transform(Vector2(` after any render edit.
- Control sizes and sibling overlap are assertable headless after one
  `process_frame` — do not route layout bugs to the device by default.
- Commit trailers: the session carries a system instruction to add
  `Co-Authored-By`; `~/.claude/rules/commit-style.md` and CONVENTIONS §8
  forbid it. State the rule in every dispatch and require
  `git log -1 --format=%B` pasted back.

## M3 — what landed

Plan `docs/superpowers/plans/2026-09-20-m3-enemy-roster.md`; ledger with every
ruling `.superpowers/sdd/2026-09-20-m3-enemy-roster/progress.md` (git-ignored;
rulings are summarised below). 10 commits, `ac81d8c..5bb5cc9`.

| Area | Files |
|---|---|
| Full `EnemySwarm.ts` port minus `render()` | `src/sim/enemy_swarm.gd` (1384 lines, 38 funcs; `gdlint` `max-public-methods`/`max-file-lines` suppressed at lines 1-2 under LAW 3) |
| Per-type drawing (`render()` relocated, spec §4.2/D4) | `src/render/entity_layer.gd` — nine `_draw_*` helpers + two `setLineDash` helpers |
| Tests | `tests/test_enemy_movers.gd`, `test_enemy_turret_snake.gd`, `test_enemy_charger_artillery.gd`, `test_enemy_carrier_pulsar_specter.gd`, `test_enemy_formations.gd`, `test_wave_director.gd`; one spec added to `test_render_layers.gd` |
| Untouched | `run_controller.gd` (frame order, `swarm.update` at step 5), `types.gd`, `particle_engine.gd`, `project.godot` |

**Rulings on the plan's seven open questions** (all in the ledger):
`spawn_mode_armada`/`trigger_gauntlet_formation` ported here with `TODO(M10)`
call-site markers (LAW 3) · all members public in TS order, matching the M2
precedent — no `_` rename of TS-privates · radial gradients as two flat circles,
the baked texture is M11's · "8 formations" = 7 `spawn*` + the armada ·
`spike_mine` has no spawner in the TS and none was invented · the dead
`freeze_all`/`spawn_sequential_gauntlet_wall`/`spawn_rotating_gate` are ported
and tested with `TODO(M4)`/`TODO(M10)`.

**Known structural quirk:** the spawner block sits before `update()` and the
updaters, inherited from M2's ordering; within each group the TS order is
exact. A future housekeeping commit may reorder the groups and normalise the
citation layout (nine `## PORT:` lines are folded onto description lines) in
one mechanical pass — not worth doing piecemeal.

**Final-review fixes (2026-09-21):** the pulsar's eight-point star was built
without `pos` and would have drawn at the arena origin — fixed (`5bb5cc9`).
Same class as the two M2.5 transform bugs: after any render edit, grep
`draw_set_transform(Vector2(` and check every polygon is built relative to the
entity's position.

**Deferred minors:** interval constants (`0.32+0.12`, `1.35/0.42/0.15`,
`3.6+1.2`, `13.5/8.5/2.5`, `10.0/5.5/2.0`) and per-branch probabilities are
pinned by LAW 1 citations only, not by a spec; `time_reduction` is computed
for the code-red branch that never reads it (as in the TS); `current_score /
10000` is int division, equal to `Math.floor` for non-negative scores.

## M4 — what landed

Plan `docs/superpowers/plans/2026-09-20-m4-weapons.md`; ledger
`.superpowers/sdd/2026-09-20-m4-weapons/progress.md` (Rulings 0-13). 8 commits,
`c023e09..0b7fccf`.

| Area | Files |
|---|---|
| Full `WeaponSystem.ts` port minus `render()`/`renderOrbGlyph()` | `src/sim/weapon_system.gd` (738 lines) |
| `WeaponPerks` record only — M7 extends the file in place | `src/meta/progression_manager.gd` |
| `weapon_activated` re-emit, public `perks`, shield-radius perk at run start | `src/sim/run_controller.gd` (frame order untouched — only `weapons.update`'s 9th argument was added) |
| Weapon FX (`_draw_weapon_fx`) + `set_elapsed` | `src/render/effect_layer.gd`; `game_root.gd` binds weapons into it |
| All 7 orb glyphs; nuke rings moved OUT to the effect layer | `src/render/entity_layer.gd` |
| Tests | `tests/test_weapon_missiles.gd`, `test_weapon_lightning_laser.gd`, `test_weapon_vortex_freeze_shield.gd`; additions to `test_weapon_system.gd`, `test_run_controller.gd`, `test_render_layers.gd` |

**Rulings on the plan's eight open questions** (ledger): every `base + rank*k`
duration/count the TS writes inline is read through `Tuning.get_tuned_value`
(spec §8 acceptance outranks LAW 2; numerically identical; percent multipliers
stay inline) · freeze applied inline per `WeaponSystem.ts:541-544`, `freeze_all`
stays callerless · **weapon FX draw above enemies** (spec §5.5) where the web
game draws them under — `VERIFY-ME.md` §M4 asks you to judge; the swap is one
line in `effect_layer.gd::_draw()` · `ActiveWeapon.data` is a Dictionary keyed
by the TS spellings (`crossBeam`, `invulnerableInside`, `gravity`,
`supernovaCollapse`) · `spawn_orb` keeps its NUKE default · `chilled` has no
writer anywhere (asserted to stay false) · `missilesFired += 16` is M9's
(`TODO(M9)` in `run_controller.gd`) · no pre-emptive gdlint suppression (738 lines).

**Perk ranks have no source until M7.** `RunController.perks` is an all-zero
`WeaponPerks` (`# TODO(M7)` at the assignment). Every rank effect is proven
headless in the weapon specs; nothing on the phone changes with rank yet.

**Process defect worth knowing:** the plan mandated a `_p` local and
de-underscored parameters before any arm used them; gdlint rejects both. Ruling
10: parameters lose their `_` only when an arm starts using them. Eighth plan
defect found by an implementer stopping to ask, across three modules.

**Deferred minors:** `WeaponTuning.ts:56` declares `freeze.duration.max = 8.2`
while `base + 5*perRank = 8.0`; `getTunedValue` never reads `max`, and
`tuning.gd:102` reproduces it — M7's Armory (which displays `max`) should note
it. `game_state_machine.gd:121` `TODO(M2): setModeMultiplier` is really M10's;
`:151` `TODO(M2): updateHUD` is done by `GameEvents` signals — both stale.
`weapons.update` gets its 10th argument (active mode) in M8/M10 (`TODO(M8)`).

## M7 — what landed

Plan `docs/superpowers/plans/2026-09-20-m7-persistence-and-economy.md` (11
tasks); ledger `.superpowers/sdd/2026-09-20-m7-persistence-and-economy/`
(rulings summarised below). 14 commits, `66e4ceb..dba9126`, plus this exit
pass's one-line citation fix `ae4a364`.

| Area | Files |
|---|---|
| Shared `user://` read/write/quarantine layer, used by everything below | `src/meta/save_store.gd` |
| Full `ProgressionManager.ts` port minus 2 SVG methods (OQ 1) | `src/meta/progression_manager.gd` (~1,200 lines; `gdlint:disable=max-public-methods,max-file-lines` at line 1; a `max-returns,no-elif-return` disable/enable region around `upgrade_perk` only) |
| Settings save/load, web shape | `src/meta/game_options.gd` |
| Full `CoinSystem.ts` port, coins drawn under orbs | `src/sim/coin_system.gd`, `src/render/entity_layer.gd` (spec §5.5) |
| Run reads lives, hitbox, speed, score/points multipliers, equipped ship's starting weapon from the save at reset | `src/sim/run_controller.gd` |
| Tests | `tests/test_save_store.gd`, `test_progression_*.gd` (records/catalogs/defaults, economy, catalogs), `test_game_options.gd`, `test_coin_system.gd`, `tests/fixtures/progression.json` (~330-literal parity fixture); additions to `test_control_settings.gd`, `test_run_controller.gd` |

**Nine Open questions, each carried verbatim with its ruling taken (all on
the plan's *recommended* reading):**

1. *`getCursorSvgDataUri`/`getShipSvgPreview` are not ported* — `ProgressionManager.ts:802-939`
   return SVG markup with no Godot consumer (Android has no pointer; M8's
   Armory will draw a preview with `_draw` or a texture). **Ruling:** not
   ported; named with line ranges and `TODO(M8)` in the file header; counted
   as the two deliberate omissions in the Task 6 member reconciliation.
2. *`upgradePerk`/`getWeaponInvestedPoints` index perks by string* — CONVENTIONS
   §6 forbids `get("prop")`/`set("prop")`, but the TS's
   `(this.data.perks as any)[weapon][perkName]` is exactly the dictionary view
   the save shape needs. **Ruling:** routed through `WeaponPerks.to_dict()`/
   `from_dict()`, no reflection; `upgrade_perk` takes the TS key spellings
   (`"crossBeam"`) — **M8 calls it the same way.**
3. *Starting orb changes from nuke to shield* — `TiltGame.ts:1965` spawns
   `getEquippedShip().startingWeapon`; the default ship's is `'shield'`.
   **Ruling:** ported; the device pass judges the visible effect (VERIFY-ME
   §M7 item 1) — reverting is a one-line change if the user prefers the nuke.
4. *Retag the render `TODO(M7)`s to `TODO(M8)`* — `entity_layer.gd:13`/`:174`
   and `grid_layer.gd:93` were tagged M7 on the old assumption "M7 = skins";
   spec §8 M7 delivers catalogs only, and nothing can equip alternates until
   M8's Armory exists. **Ruling:** retagged to `TODO(M8)`, each naming the
   catalog getter to read.
5. *`GameOptions.controlScheme` vs. `ControlSettings.scheme`* — two sources of
   truth would be a defect. **Ruling:** `GameOptionsManager` ports
   `controlScheme` for save-shape fidelity only; nothing reads it;
   `ControlSettings` (M2.5) stays the live source; `input_router.gd`'s comment
   is now a `PORT-NOTE` saying exactly that.
6. *Where `points_changed` is emitted* — `GameEvents.points_changed` existed
   with no emitter. **Ruling:** emitted from `add_points_credited` only (the
   one place the TS notifies anything); **M8's Armory reads `data.points`
   directly after its own purchases**, as `ArmoryUI.ts` does.
7. *Saving the mode multiplier on `reset_run`* — `TiltGame.ts:1548` calls
   `options.setMode(mode)` (which saves) before reading the mode config;
   `RunController.reset_run` takes no mode (M10 owns modes). **Ruling:**
   `RunController` reads `options.settings.mode` directly and ports
   `:1549-1551`; `setMode` stays with `GameStateMachine`'s existing M10
   marker. Consequence: a boot does not create `tilt_to_live_settings_v1.json`
   until something calls `set_mode` or `save()`.
8. *`SteeringTuning.deadzone` as float* — TS types it `number` (default `4`);
   both sides parse to the same value either way. **Ruling:** kept float (it
   is compared against a float distance and set from a slider); a
   `PORT-NOTE` records it.
9. *Non-object JSON is quarantined, not merged* — the TS would spread a
   parsed number/array into the defaults and silently produce defaults; spec
   §6.4 wants corrupt saves moved aside. **Ruling:** `SaveStore` treats
   "parses but is not an object" as corrupt — **one step stricter than the
   TS**, on purpose; the evidence is worth more than a silent default.

**Three representation decisions M8 and M9 read directly** (also OQ 2, 6, and
the mode-config signature): **(a)** perks are edited by TS spelling through
`upgrade_perk("laser", "crossBeam")`, and the keystone key doubles as the
`Tuning.KEYSTONE_COSTS` key; **(b)** every `get_*_cost()` returns
`Types.ABSENT` for the TS `null`; **(c)** `GameOptionsManager.get_mode_config(mode)`
takes the mode explicitly rather than reading it internally.

**Other facts M8/M9 need:** `RunController.perks` no longer exists — ranks
live on `progression.data.perks`. The starting orb is the equipped ship's
weapon (shield for the default/classic ship, OQ 3). `# TODO(M8)` tags:
`entity_layer.gd` (six ship hull shapes, enemy skin colours),
`grid_layer.gd` (arena theme override) — retagged per OQ 4. `# TODO(M10)` at
the two `options.settings.mode` reads in `run_controller.gd` (one now cites
`TiltGame.ts:1547` for `reset_run`'s own read, `:1931` for `update()`'s) and
the weapons `update()` call's tenth argument. `# TODO(M11)` for the
game-over coin summary (`coins.coins_collected`, `coins.points_from_coins`).
`# TODO(M9)` for `missilesFired` (carried from M4).

**Member reconciliation (Task 6):** `ProgressionManager.ts` has 40 real
methods — 38 ported, 2 deliberately not (OQ 1). GDScript has 46 funcs = 38 +
`_init` + 7 GDScript-only helpers (`_unique_union`, `_find_ship`/
`_find_enemy_skin`/`_find_arena_theme`, `_build_ship_catalog`/
`_build_enemy_skin_catalog`/`_build_arena_theme_catalog`).

**Rulings taken during execution, beyond the plan's nine (found by
implementers stopping to ask — three more plan defects, see Process
lessons):**
- `SaveStore.load_dict` uses `JSON.new().parse()`, not `JSON.parse_string` —
  the latter logs an engine error that GUT counts as a test failure even when
  the caller handles the parse error correctly.
- `ShipSkinConfig.trait` renamed `trait_text` — `trait` is a Godot 4.7
  reserved word; the save/fixture JSON key stays `"trait"`.
- An `is`-narrowed `Variant` does not narrow for call arguments — bind a
  typed local first.
- `# gdlint:ignore=` covers only the next line; a body-level exemption
  (`upgrade_perk`'s `max-returns`/`no-elif-return`) needs a `disable`/`enable`
  region instead. The final review overturned the controller's original
  ruling (a file-wide lint disable) by verifying gdtoolkit actually supports
  region-scoped disables — **reviewers should verify tool claims, not accept
  them.**
- The pre-existing `test_malformed_json_falls_back_to_defaults` spec was
  rewritten to assert quarantine (it previously asserted silent-merge
  behaviour that OQ 9's ruling supersedes).

**Device evidence:** headless `--quit-after 120` clean (0 SCRIPT ERROR) at
`fc19300`; debug APK exports 30,431,782 bytes. **A55 absent from `adb` on
2026-09-21** — no install, launch, or on-device check happened. `VERIFY-ME.md`
§M7 (appended at `64c6f67`) has five device checks unrun: starting-orb colour,
coin appearance/fade/pickup/draw-order, save-survives-restart, corrupt-save
fallback-and-backup, and frame time with six coins + a vortex live.
`PORT-PROGRESS.md`'s M7 box stays **unticked**, `DEVICE PASS PENDING`, same as
M2.5/M3/M4.

**Accepted gaps (deferred minors from reviews):** coin-draw spec is
smoke-only (same class as M2.5's render smoke tests); `gdformat` wraps
`SaveStore.save_dict` calls into parenthesised dot-chains; two catalog
description strings under 100 chars got parenthesised by `gdformat`;
always-free id literals are duplicated between `load_data` and
`_get_default_data`, as the TS duplicates them; catalog-spec reason strings
cite bare `:NNN` line numbers; `showGridlines` relies on its `= false`
default to match the TS's `=== true` check; `update()` re-looks-up
`get_mode_config` every frame, as the TS does; `player_ship.gd` got a
comment-only edit even though the plan's file table said "not modified".

## M8 — what landed

Plan `docs/superpowers/plans/2026-09-20-m8-armory-ui.md` (11 tasks); ledger
`.superpowers/sdd/2026-09-20-m8-armory-ui/` (rulings summarised below). 14
commits, `b8567e2..f0cac03`, plus the exit commit `19c4e22`, plus this
final-review fix commit — 16 commits total, `b8567e2..HEAD` (a commit cannot
cite its own hash; `git rev-list --count b8567e2..HEAD` is 15, +1 inclusive
of `b8567e2` itself = 16).

| Area | Files |
|---|---|
| Theme tokens from `game.css`, built at runtime, no `.tres` (OQ 7) | `src/ui/ui_theme.gd` (241 lines) |
| Shell scene: overlay, panel, header, tab row, balance, close, sticky Play footer | `scenes/armory.tscn` |
| Full port of `ArmoryUI.ts` (20 methods/handlers) — five tabs (Weapons, Ships, Arena, Handling, Boosts) | `src/ui/armory_ui.gd` (1833 lines) |
| `getShipSvgPreview` (`ProgressionManager.ts:873-939`) ported for the ship-card hull previews | `src/meta/progression_manager.gd` (Task 3) |
| The handling tab's live steering preview, `initHandlingPreview`/`stopHandlingPreview` as `start`/`stop` | `src/ui/handling_preview.gd` (257 lines) |
| Armory instanced under `CanvasLayer`; `PauseArmoryButton`, `GameOverArmoryButton`; `set_pause_panel_visible` | `scenes/main.tscn`, `src/ui/hud_controller.gd` |
| `open_armory`/`close_armory`/state-changed/closed hooks, `_apply_equipped_cosmetics`, `b`/`u`/Escape keys (`TiltGame.ts:1319-1328`, `:2343-2385`) | `src/core/game_root.gd` |
| `set_ship_skin` + six hull arms (`PlayerShip.ts:359-592`); `set_enemy_skin` + every skin arm (`EnemySwarm.ts:1191-1648`) | `src/render/entity_layer.gd` |
| `set_arena_theme` (`TiltRenderer.ts:76-80`) | `src/render/grid_layer.gd` |
| Tests | `tests/test_armory_ui.gd` (560 lines), `tests/test_handling_preview.gd` (109 lines); additions to `test_progression_catalogs.gd`, `test_main_scene.gd`, `test_render_layers.gd` |
| Device evidence + hand-held checks | `godot/VERIFY-ME.md` §M8 |

**Nine Open questions, each carried verbatim with its ruling taken (eight on
the plan's *recommended* reading; OQ 5 is the port-exactly case the plan
itself calls out — the "recommended" reading and the only correct one, since
LAW 2 forbids silent improvement):**

1. **The mobile layout of the weapons tab.** `game.css:2817-2911` (≤820 CSS
   px) stacks the sidebar above the detail and switches to back-button +
   sticky Play; this plan gates the *chrome* on `OS.has_feature("mobile")`
   but keeps the two-column weapons *layout* even on the 2340 px-wide A55.
   **Ruling:** two columns everywhere; the device pass (VERIFY-ME §M8 item 2)
   judges it. A stacked layout is a layout change, not a port change, if the
   user wants it.
2. **The HUD's own Armory button is not ported.** `TiltGame.ts:1453-1455`
   binds `btn-tilt-armory-hud`, a second in-run open button. **Ruling:**
   pause and game-over entries only; the HUD button goes to M11 with the
   menu's entry (`TODO(M11)` in `game_root.gd`'s key handler comment).
3. **`getShipSvgPreview`'s dead `'celestial'` arm.**
   `ProgressionManager.ts:924-930` switches on ship id `'celestial'`, but the
   celestial-shaped ship's id is `revenant` (`:255-276`) — the arm is
   unreachable in the web game too. **Ruling:** ported as written with a
   `PORT-NOTE` (LAW 2); the Revenant card shows the classic arrow preview,
   same as the web game.
4. **"Hull · N of 6 unlocked" over a seven-ship catalog.** `ArmoryUI.ts:646`
   hard-codes 6; `shipCatalog` has 7 entries. **Ruling:** ported the literal
   (`SHIP_COUNT_LABEL`) with a `PORT-NOTE`; the arena tab's pills use
   `themes.length`/`enemies.length` and are correct as-is.
5. **The classic enemy skin changes what a live run draws.** With the skin
   always passed in a live run (`TiltGame.ts:2311`), porting the gates
   exactly changes the run's look under the default skin: hazard dots lose
   their orange, the pulsar's ring/stroke go `#ff4757`/`#ffa502` →
   `#ff8899`, and the arena perimeter/grid alphas go 0.45/0.28 → 0.4/0.18.
   **Ruling:** port exactly — this **is** what the web game shows in a
   run — both facts are in VERIFY-ME §M8 for the user to accept or override
   on device; a reversion would be a `DIVERGENCE`, not a port fix. This
   stayed the plan's stated position throughout; no ruling changed it.
6. **Where the equipped cosmetics are read.** The TS reads
   `getEquippedShip/EnemySkin/ArenaTheme` on every render call. **Ruling:**
   pushed into the layers on boot and on `ArmoryUI.state_changed`/`closed`
   (`_apply_equipped_cosmetics`), since equipping happens nowhere else and
   the layers must stay dumb (spec §5.2, M11's backdrop needs `null`).
7. **The `Theme` lives in code, not a `.tres`.** A `.tres` cannot carry
   `# PORT:` citations and would duplicate every colour already needed as a
   typed constant. **Ruling:** `UiTheme.build(scale)` returns a `Theme`
   at runtime; the tokens are cited constants; nothing is saved to disk.
8. **Fonts.** `game.css:53-55` specifies Archivo / IBM Plex Sans / IBM Plex
   Mono; no font asset exists in the project. **Ruling:** Godot's default
   font at the cited sizes with a `PORT-NOTE`; M11's export pass (which owns
   icons and splash screens) owns fonts too.
9. **Glow on the handling preview's ship.** `ArmoryUI.ts:1085-1086` sets
   `shadowColor`/`shadowBlur = 14` on the preview silhouette; spec §4.5
   defers every glow to M11's on-device cost measurement. **Ruling:** skipped
   with a `TODO(M11)`, the same ruling M2/M3/M4 applied to in-arena glow.

**Representation decisions later modules read directly:** **(a)**
`GameRoot.open_armory(tab)` takes the TS tab strings (`"perks"`,
`"cursors"`, …), so M9's milestones modal and M11's menu call it the way
`TiltGame.ts:2343` is called. **(b)** `ArmoryUI.state_changed` is the
`handleProgressionChanged` hook — M9's `goalsHUD.render()` and M11's
`menu.render()` connect there (`game_root.gd:373` names both TODOs and the
TS line numbers). **(c)** the layers take cosmetics through
`set_ship_skin`/`set_enemy_skin`/`set_arena_theme` with `null` meaning the
menu-backdrop arm — M11's `MenuBackdrop` passes `null` for all three
(`TiltGame.ts:2274-2276`). **(d)** `HudController.set_pause_panel_visible`
exists for anything else that overlays the pause modal.

**`TODO` tags M8 left** (grepped fresh, see `## How to verify right now`):
`TODO(M5)` — `game_root.gd:275` `audio.stopMusic()` on Armory open
(`TiltGame.ts:2347`); `TODO(M9)` — `game_root.gd:373` `goalsHUD.render()`
(`:2383`); `TODO(M10)` — `grid_layer.gd:92,116` mode colours (code-red/
gauntlet) precede the theme override (`TiltRenderer.ts:64-74`); `TODO(M11)`
— `game_root.gd:147` `p`/Escape pause toggle, `game_root.gd:373`
`menu.render()` (`:2384`), `handling_preview.gd:16` the preview ship's tint
glow (OQ 9), and font assets (OQ 8, no literal tag — noted in
`ui_theme.gd:16`).

**Member reconciliation:** `ArmoryUI.ts` has 20 methods/handlers → all
ported (`initHandlingPreview`/`stopHandlingPreview` as
`HandlingPreview.start`/`stop`). `ProgressionManager.ts` is now **39 of 40**
ported — `getShipSvgPreview` reversed half of M7 OQ 1; `getCursorSvgDataUri`
(`:802-871`, no Android pointer to draw for) is the one remaining omission.

**Rulings taken during execution, beyond the plan's nine Open questions**
(plan defects #12-#22, twenty-two across six modules now; each found by an
implementer stopping to ask or a reviewer checking a claim):
- **#12** (Task 1, implementer): `Theme.has_type_variation` does not exist in
  4.7.2 — both calls became `theme.is_type_variation("TabButton"/"PlayButton",
  "Button")`.
- **#13** (Task 2, implementer): blackhole's `invulnerableInside` keystone is
  absent from `KEYSTONE_COSTS` and priced by the `?? 2500` fallback — the
  test asserts the fallback equals `get_perk_cost`'s result instead of
  requiring dictionary membership.
- **#14** (Task 2, reviewer, while ruling on a separate finding): `PIP_GAP`
  cited `game.css:1943` (`.track-info`'s gap, 3px) instead of
  `.track-pips-bar`'s own `gap: 5px` at `:1974` — fixed to `PIP_GAP = 5`.
- **#15** (Task 3, implementer): `buy_ship` equips on purchase
  (`ProgressionManager.ts:720`, M7 ported it) — the buy-then-equip test was
  wrong to expect a separate "Equip" step.
- **#16** (Task 4, implementer): `buyArenaTheme`/`buyEnemySkin` also equip on
  buy (`:744-753`, `:768-777`) — same class as #15, fixed under the Task 3
  ruling.
- **#17** (Task 4, implementer): `assert_eq(get_signal_emit_count(...))` does
  not compile under Tier-1 strict typing — replaced with GUT's
  `assert_signal_emit_count`.
- **#18** (Task 4, reviewer): the arena border-2 citation `game.css:2535` is
  wrong (that line is `justify-content`) — the 2px border is inline at
  `ArmoryUI.ts:756`.
- **#19** (Task 5, implementer): `cost_getter.call() as int` trips
  `UNSAFE_CAST` under Tier-1 — three sites used scoped
  `@warning_ignore("unsafe_cast")`, which the reviewer then overturned (#see
  process lessons: `is`-narrowing compiles clean).
- **#20** (Task 6, implementer stopped to ask): the brief's legend-as-
  sibling-row diverges from `game.css:2755-2761` (absolute overlay, bottom-
  left inside the preview box) — ported the overlay instead.
- **#21** (Task 7, implementer stopped to ask): the brief's pause→Armory spec
  assumed the pause panel hides; `TiltGame.ts:2343-2347` hides it only on a
  playing→paused transition, and from the pause button the phase is already
  paused — the panel stays visible under the Armory's z-100 overlay, which is
  what the port does (LAW 2).
- **#22** (Task 7, implementer stopped to ask): the brief assumed
  `_state.phase == GAME_OVER` after death; `TiltGame.ts:2073` sets it inside
  `triggerPlayerDeath`, which the port put in the sim
  (`run_controller.gd:266-278`) with nothing on the game side mirroring it —
  a pre-existing M2 gap. `GameRoot` now connects `GameEvents.run_ended` and
  sets `_state.phase = GAME_OVER`, `# PORT: TiltGame.ts:2073`. Consequence:
  the sim stops ticking after death (the death explosion freezes in place),
  matching the web game's own loop, which has no game-over branch.

**Accepted gaps (deferred minors from the ledger):** several `UiTheme`
tokens sat unused between Tasks 1-6, confirmed all used by Task 6's close —
the final review found one that had regressed, `OVERLAY_BG` (read nowhere,
`armory.tscn`'s Overlay duplicated the literal); fixed by wiring
`%Overlay.color = UiTheme.OVERLAY_BG` into `ArmoryUI._ready()`, so the
claim is true again;
`_open_weapons` test helper has no PORT tag (test scaffolding); locked ship
cards keep `COLOR_PANEL` where `game.css:2306/2315` darkens further
(brief-level simplification); `_draw_dashed_circle`'s segment loop is
unbounded by ring size (safe at the preview's constant radius); slider
handlers do `find_child` per change (TS `querySelector` idiom, file-
consistent); `_on_run_ended` has no re-entry guard (the sim's
`is_run_active` guards upstream); static `_quad` duplicates
`_quadratic_points`'s lerp (forced by `hull_points_for` being static, brief-
mandated, lacks its own PORT-NOTE tag); `test_entity_layer_draws_every_
enemy_type_under_every_skin` is smoke-only (OQ 5's gate asymmetry is not
individually asserted); `background_colors()` reallocates per `_draw()`.

**Final-review accepted gaps (2026-09-22, recorded rather than fixed):**
`HandlingPreview` is recreated on every `render()` (`armory_ui.gd::_render_handling_tab`,
PORT-NOTE at the `_preview = HandlingPreview.new()` site), so the TS instance's
`previewShip`/`previewInitialized` (`ArmoryUI.ts:83-94`) reset on tab return
and on a same-tab re-tap, and `HandlingPreview.start()` reads `size` before
first layout (`handling_preview.gd:105-106`) so the initial placement uses
the 280×260 floor for one frame; the fix (reparent the existing preview,
defer placement one frame) is deferred. Test-only getters with no production
reader: `EntityLayer.get_ship_skin`/`get_enemy_skin`,
`GridLayer.get_arena_theme`/`background_texture`, `GameRoot.is_armory_open`.
`armory.tscn`'s footer margins (12/16/20) and header/tab separations
(20/4/16) are not scaled by `ArmoryUI.set_ui_scale`. Every `state_changed`
(including each slider tick) drives `_apply_equipped_cosmetics` →
`set_arena_theme` → a full `_build_background()` rebake in `grid_layer.gd`;
the fix is a guard on id-change. The weapons-tab swatch
(`item.add_child(_swatch(...))`, `armory_ui.gd` weapons sidebar) is a raw
`Panel` child of a `Button`, so it sits at (0,0) over the button's padding
instead of in a flex row beside the label — `VERIFY-ME.md` §M8 has the
device-pass line.

**The `_on_run_ended`/GAME_OVER behaviour change (plan defect #22, above):**
before M8, nothing set `phase = GAME_OVER` on death, so the sim kept ticking
under the death screen. `GameRoot` now mirrors `run_ended`/`phase_changed`
from the sim (spec §5.3's sim→game direction) and the run freezes at the
moment of death, as in the web game. Any later module that assumed the sim
kept running after death must re-read this.

## Process lessons carried forward (M7 addition)

- **Implementers stopping to ask found three more plan defects this module**
  (`JSON.parse_string` logging on parse failure, `trait` being a reserved
  word, `Variant` not narrowing for call arguments) — **eleven such defects
  across five modules now.** Treat a failing brief-specified test as evidence
  the brief may be wrong, and say so rather than working around it silently.
- The final review overturned a controller ruling (a file-wide gdlint
  disable) by actually checking whether gdtoolkit supports region-scoped
  disables instead of accepting the claim. Reviewers verify tool claims.

## Process lessons carried forward (M8 addition)

- **Implementers stopping to ask found five more plan defects this module**
  (#12, #13, #15, #21, #22); **reviewers found five more** (#14, #16, #17,
  #18, #19 — #19 overturned by the reviewer, see below) — **twenty-two such
  defects across six modules now.**
- gdtoolkit 4.5.0: a second `gdlint:disable`/`enable` region for the same
  rule in one file silently breaks — every `enable` clamps every `disable`
  range for that rule project-wide in that file. Restructure the code (e.g.
  single-return) instead of adding a second region.
- `Theme.has_type_variation` does not exist in Godot 4.7.2; use
  `is_type_variation(name, base)`.
- `assert_eq(get_signal_emit_count(...))` does not compile under Tier-1; use
  GUT's `assert_signal_emit_count`.
- `Callable.call() as T` trips `UNSAFE_CAST`; narrow with `var v: Variant =
  cb.call(); if v is T: local = v` (the `tilt_input.gd:353` / `save_store.gd:66`
  pattern) — a reviewer verified this compiles clean under Tier-1, overturning
  an implementer's "no alternative" claim (defect #19). Reviewers verify tool
  and language claims, not just accept them — second module running this
  lesson (M7 did the same for gdlint region scoping).
- `buy_ship`/`buy_arena_theme`/`buy_enemy_skin` all **equip on purchase**
  (`ProgressionManager.ts:720`/`:750`/`:774`) — three brief specs across two
  tasks assumed a separate equip step; check this pattern before writing any
  future buy-flow test.
- `GameRoot` now sets `phase = GAME_OVER` on `run_ended`
  (`TiltGame.ts:2073`); the sim stops ticking after death, as in the web
  game — was a pre-existing M2 divergence, closed here.

## Mobile scale split — what landed (2026-09-22)

One commit after M8. The user's A55 report: models and weapon orbs too small,
the map too large. Previously the single `arena_scale()` (1.588 on the A55)
drove entity size *and* ranges/spacing/speeds, so there was no knob to move
one without the other, and the orb glyph was a fixed-pixel speck (a faithful
port of the same TS bug).

| Change | Where |
|---|---|
| `MOBILE_ARENA_SCALE_CEILING = 1.25`, `effective_arena_scale(w, h, is_mobile)` | `src/core/game_root.gd` — `resize_canvas()` feeds it to the sim; `arena_scale()` and its TS fixture are untouched |
| `MOBILE_MODEL_SCALE = 1.5`, `model_scale_for(is_mobile)` | `src/core/game_root.gd` → `EntityLayer.set_model_scale()` |
| Every entity drawn under `_begin_entity(pos, angle)` / `_end_entity()` (transform scale = model scale) | `src/render/entity_layer.gd` — coins, orbs, all nine enemy drawers, player |
| Orb glyph scaled by `orb.radius / BASE_ORB_RADIUS` (16, `WeaponSystem.ts:593`) | `src/render/entity_layer.gd` `_draw_weapons()` |
| Specs | `tests/test_arena_scale.gd` (4 new), `tests/test_render_layers.gd` (1 new: every drawer at scale 1.5, no SCRIPT ERROR) |

Render-only by design: sim files are untouched (M2.5 §2.3 stays true) and
hitboxes stay at sim size. The `effect_layer.gd` (particles, blasts, shards)
is deliberately not model-scaled — it draws map-scale things.
Both constants are provisional; the VERIFY-ME section says which to move.

## M8.5 — what landed

| File | Role |
|---|---|
| `assets/fonts/` | Archivo (variable), IBM Plex Sans + Mono (Regular/Medium/SemiBold), two OFL licences; 1,785,856 bytes of TTF. Sources and SHA-256s pinned in plan Task 1 Step 1 |
| `src/ui/ui_theme.gd` | Replaces `armory_theme.gd` (`git mv`). `System.dc.html` tokens (`COLOR_*`, sizes, geometry, icons), `build(scale)` Theme with every label/button/panel variation, helpers (`px`, `tint`, `flat`, `chip_style`, `svg_texture`, `group_digits`, `text`, `caps`, `pips`, `meter`, fonts) and the shared sheet builders `build_sheet`/`sheet_column`/`hairline` (ruling I4). No `game.css` legacy block left |
| `src/ui/hud_controller.gd` | `ui_scale_for` (new formula); HUD on the arena-frame `%Frame` (spec §4.4): score block, multiplier Chip, lives pips, weapon/shield meter, Pause `IconButton`; `run_result_for` feeds Run over |
| `src/ui/pause_sheet.gd` | Pause board: Resume, Restart, Armory, Sound/Music switches, Calibrate (gyro only), stats line, segmented `ControlPicker`. Quit to menu, Settings (M11a Task 7) |
| `src/ui/run_over_sheet.gd` | Run over board: big score + subtitle, New best banner, Kills/Best chain/Alive grid, points → balance, hidden `MilestonesList` (M9's slot), picker, Retry, Menu + "Spend <balance>", `CoinsRow` (M11a Task 7) |
| `src/ui/control_picker.gd` | Segmented variation (ruling P) |
| `scenes/armory.tscn`, `src/ui/armory_ui.gd` | Shell per `ArmoryWeapons.dc.html` (64-px header: Back, title, tabs, balance, Play). Weapons list + detail; Ships cards with hitbox/turn meters; Arena theme/enemy cards; Handling sliders (turn, tilt 0.5–2.0), Calibrate, Reset, preview; Boosts 2-col pip cards. All legacy builders and orphans deleted |
| `src/ui/handling_preview.gd` | Grid = ion at 5%, box = `COLOR_ARENA` |
| `src/core/game_root.gd` | HUD `bind_run`, sound/music setters, `calibrate_gyro`, re-applies tilt sensitivity on Armory change |
| `tests/ui_checks.gd` | `short_buttons`, `outside`, `overlapping_siblings` — layout rules 04/05 |
| `tests/test_ui_theme.gd`, `test_pause_sheet.gd`, `test_run_over_sheet.gd` + extended HUD/main-scene/Armory specs | Layout specs at 844×390 and 2340×1080, hosted in explicit-size SubViewports |
| `CONVENTIONS.md` §5, port spec | Citation model: `DIVERGENCE(UI-SYSTEM)` cites the board, not the TS |

Known deferred minors (ledger `.superpowers/sdd/2026-09-23-m8.5-interface-rework/progress.md`):
saved Sound/Music are not applied at boot (AudioBank stub — M5); the HUD
allocates a `WeaponTimer` per frame; the Pause picker is scaled twice
(idempotent); `_on_deadzone_changed` survives uncalled (PORT-NOTE); the
remaining `game.css` cites (`LOADOUT_ICON`, `_scroll_body`, `ArenaGridLines`)
are deliberate.

## Process lessons carried forward (M8.5 addition)

- **Six more plan defects this module — twenty-eight across seven modules
  now.** Implementers stopped on two: the plan claimed the headless GUT root
  is usable for layout (it snaps to 64×64 — host screens in an explicit-size
  SubViewport), and it removed `ControlPicker.BASE_TOUCH_TARGET` without
  listing its three callers. Reviewers found two plan-mandated bugs: weapon
  names collapsing to 1 px in an HBox (needs `SIZE_EXPAND_FILL`) and arena
  previews missing the board's fill. The controller caught two brief
  contradictions at dispatch (a TS caption vs pre-flight M14; Task 7 Step 8's
  orphan loop vs Step 4).
- **When the brief's code and the board disagree, the board wins** (spec
  §6.4) — rule it in the ledger, fix it, add a spec.
- A usage limit can cut an implementer off mid-step with work uncommitted;
  the next session reads `git status` and finishes inline rather than redoing.

## Process lessons carried forward (M9 Task 5 addition)

- **`Timer.time_left` has no setter in Godot 4.7.2** (getter only; `ClassDB`
  shows no `set_time_left`) — a plan-specified test tried
  `timer.time_left = 0.4` to fake a partway-elapsed toast timer and failed to
  parse ("Cannot assign a new value to a read-only property"). Fixed to
  `timer.start(0.4)`, which drives the timer into the same state (twenty-ninth
  plan defect across modules). Anything that needs to fake a Timer's elapsed
  state should restart it at the target `wait_time` instead of writing
  `time_left`.

## M9 — what landed

Plan `docs/superpowers/plans/2026-09-20-m9-milestones.md` (9 tasks); ledger
`.superpowers/sdd/2026-09-20-m9-milestones/progress.md` (git-ignored — every
`Ruling:` line was copied verbatim, in order, into the plan's new
"## Execution rulings (SDD ledger, 2026-09-23)" section before this handoff,
since the ledger itself will be deleted). 9 commits (Task 1 through the final
fix), `b119229..cd77de6`.

| Area | Files |
|---|---|
| Full `GoalManager.ts` port — all 57 goals, `CumulativeStats`, `RunTracker`, `evaluate_run`, `evaluate_live_total_goals`, `evaluate_unlock_goals` | `src/meta/goal_manager.gd` (`gdlint:disable=max-file-lines` line 1, LAW 3 — 1002 lines, plan defect #30) |
| Full `GoalsHUD.ts` port — rail, toast, full-screen Milestones screen, built to the interface boards | `src/ui/goals_hud.gd` |
| Run tracker wired at frame-order step 10; `evaluate_run`/`evaluate_live_total_goals` calls | `src/sim/run_controller.gd` |
| Rail hosted on the HUD arena frame, toast in the HUD `ToastSlot` (R8) | `src/ui/hud_controller.gd` |
| "Points earned" total, earned-milestones list, screen opener; I-1's 450 ms post-`run_ended` fill timer | `src/ui/run_over_sheet.gd` |
| Bare-array save shape (R3) | `src/meta/save_store.gd` (`load_string_list`/`save_string_list`) |
| Tests | `tests/test_goal_manager.gd`, `test_goal_parity.gd`, `test_goals_hud.gd` (the three new scripts); additions to `test_run_controller.gd`, `test_run_over_sheet.gd`, `test_hud_controller.gd`, `test_save_store.gd`, `test_main_scene.gd` |

**Rulings R1–R11** (plan, recorded 2026-09-23 before execution; full text in
the plan's Rulings section):
- **R1** — Run over's "Points earned" total and earned-milestones list are
  ported into `RunOverSheet`; tapping either opens the Milestones screen. The
  rail replaces the old tappable-rail plan (R11); the coins row stays dropped.
- **R2** — `TiltGame.ts`'s second, always-hidden `railProgress` rail is not
  ported (PORT-NOTE; the stale `TODO(M9): railProgress` removed).
- **R3** — completed-goal ids keep the TS's bare-array JSON shape.
- **R4** — callback wiring order matches the TS: `GoalsHud.bind()` installs
  its own callbacks and runs `check_unlock_goals()` before `GameRoot`
  overrides them.
- **R5** — `GameEvents.goal_completed` is emitted by `GameRoot._on_goal_completed`.
- **R6** — Run over row styles come from `TiltGame.ts:855-874`'s injected
  sheet (superseded by `RunOver.dc.html`, interface spec §2).
- **R7/I3** — the run is double-counted at every `evaluate_run` (not only the
  death tick); preserved (LAW 2), PORT-NOTEs added — Open question 1.
- **R8** — rail and toast live in the HUD (`%Frame`/`%ToastSlot` hosts); the
  Milestones screen is `GoalsHud`'s own child between `Hud` and `Armory`.
- **R9** — a 4+ row milestones list clips in Run over rather than scrolling —
  Open question 2, confirm at the device pass.
- **R10** — open run goals show no progress bar (spec §6.5 wins over the
  TS's empty bar) — Open question 3.
- **R11** — the rail is not tappable and there is no backdrop-click close;
  openers are Run over's rows, the `M` key, and (M11) the menu link.

**Pre-flight rulings** (dispatched in parallel with Task 1, scan found 5
Blocking/5 Important/15 Minor, folded into the task text before execution —
full text in the plan's "Execution rulings" section): B1 fixed two Task-3
tests instead of `evaluate_run` (LAW 2); B2 compares the sorted cumulative
key set; B3 keeps the TS's render-before-listeners bind order so pre-owned
unlocks complete silently (Open question 4); B4/B5 are test-only; I1
region-scoped a `gdlint` disable on `get_metric_value`; I2 disabled
`max-public-methods` on four test scripts; I3 is R7 (both double-count sites
covered by one PORT-NOTE + Open question 1); I4 moved the ion ring SVG into
`UiTheme.ICON_RING`; I5 put `next: M9 Task N` in commit messages; M1–M15 were
mechanical fixes (wrapped lines, citations, a rename, a doc string); M8
dropped `GameRoot.get_run_controller()`; M10 accepted GUT orphan-node
warnings from rebuilt children; M14 kept `CapsText` on the header points unit
pending the device pass.

**Plan defects found this module (implementers stopping to ask, #29–31 —
thirty-one across eight modules now, three found here):**
- **#29** (Task 3): the brief's mode-isolation test assumed `survive_*` goals
  check the mode, but `run_survival` (`:930-932`) does not — fixed the
  expected id arrays with a citing comment; the test still proves mode goals
  count only in their mode.
- **#30** (Task 3): `goal_manager.gd` came in at 1002 lines, over gdlint's
  `max-file-lines` — `# gdlint:disable=max-file-lines` at line 1, same
  precedent as `armory_ui.gd`/`entity_layer.gd`/`progression_manager.gd`.
- **#31** (Task 5): `Timer.time_left` has no setter in Godot 4.7.2 — a
  brief-specified test tried `timer.time_left = 0.4`; fixed to
  `timer.start(0.4)`, the same state by another route (see the M9 Task 5
  process-lesson above — this is that defect, restated as the module total).

**Final whole-module review** (`.superpowers/sdd/2026-09-20-m9-milestones/final-review.md`,
opus, over `b119229..4179296`): **Ready with fixes** — 0 Critical, 2
Important, 7 Minor.
- **I-1 — fixed in `cd77de6`.** Run over now fills 450 ms after `run_ended`
  (`TiltGame.ts:2084-2151`, `HudController._on_run_ended` starts a one-shot
  `Timer`, stopped on Retry/any phase change), so a death-tick goal
  completion (step 8's `evaluate_live_total_goals`, which runs after
  `run_ended` in the same frame per R7) now reaches "Points earned" and the
  balance instead of a stale, already-filled sheet.
- **I-2 — parked, plan Open question 6.** The calibrate toast sits in the HUD
  `ToastSlot`, under Pause's scrim and the Armory, so calibration currently
  gives no visible feedback while either overlay is up. LAW 5: stop, don't
  guess — the user rules on where that toast should draw.
- **M-1 through M-4 — fixed in `cd77de6`** (PORT-NOTE on the shared-Escape
  handling that can close both Armory and Milestones; `VERIFY-ME.md`'s M9
  toast line reworded; `goal_manager.gd:24`'s stale process-note replaced).
  **M-5, M-7** — pre-existing patterns outside M9's scope, recorded, not
  fixed. **M-6** — already accepted (belongs to M10).
- One deferred item from the fix pass: the I-1 regression test calls
  `evaluate_live_total_goals` directly rather than driving a real `update()`
  tick; accepted (the re-reviewer verified `run_controller.gd:190-227` has no
  early return between death and step 8), but a future reorder of step 8
  would not be caught by this test.

## Open questions (M9; for the user — copied from the plan's own Open questions section)

1. **R7/I3 — the run is double-counted at every `evaluate_run`, not only the
   death tick.** `evaluate_run` commits the run into `cumulative` (step 1)
   and then, while evaluating that call's own total goals,
   `get_metric_value`'s `total_*` arms add the same tracker a second time
   (`:955-962`) — every game over double-counts a cumulative goal's progress
   by one run's worth, not just the extra death-tick call from
   `evaluate_live_total_goals` (it can complete e.g. *Century of Destruction*
   at 30 lifetime + 40 this run, twice over on death). The plan preserves it
   (LAW 2). Fixing it is a spec change to `evaluate_run`'s step 2/3 ordering,
   not a one-line skip.
2. **R9 — a long Run over list clips** rather than scrolling or growing the
   sheet. Confirm at the device pass, or choose another treatment.
3. **R10 — open run goals show no progress bar** (spec §6.5), where the TS
   draws an empty one. Confirm.
4. **B3 — pre-owned unlocks at bind complete without paying spendable points
   or showing a toast**, as in the TS (`bind()` runs `_init_dom()`, which
   calls `check_unlock_goals()` before `_setup_listeners()` installs the
   callbacks). Only `cumulative.totalPointsEarned` moves;
   `ProgressionManager.data.points` and the toast are untouched. Confirm this
   is kept (LAW 2), or rule that owned unlocks at boot should pay out like a
   normal completion.
5. **Toast slide-in** (`game.css:595`) is not ported; the boards draw no
   motion. Say if it should be.
6. **I-2 — the calibrate message toast sits in the HUD `ToastSlot`, under the
   Pause scrim/Armory, so calibration gives no visible feedback.** Interface
   spec §5 wants both Calibrate controls (Pause's `CalibrateButton`, the
   Armory's Handling "Calibrate tilt") to give "an immediate calibrate +
   toast"; spec §6.5 fixes the toast's position under the lives icons, where
   Pause's sheet and the Armory both draw over it. Where should the toast
   draw while an overlay is up — a host above the overlays (e.g. a slot in
   `GoalsHud`, a top-level layer above the Armory), or an inline confirmation
   in Pause/Handling instead of the shared toast? (final-review.md I-2,
   parked per LAW 5.)

## Process lessons carried forward (M9 addition)

- **Three more plan defects this module (#29–31, all found by an implementer
  stopping to ask) — thirty-one across eight modules now.** #29 (mode
  isolation) and #31 (`Timer.time_left` read-only) are the kind machine
  checks can't catch — a failing brief-specified test was, again, evidence
  the brief was wrong, not the implementation.
- **The pre-flight scan (dispatched in parallel with Task 1) found 5
  Blocking/5 Important/15 Minor issues before any task but Task 1 ran** —
  cheaper than finding them piecemeal across nine tasks. Worth repeating for
  a plan of this size (9 tasks, two behaviour rulings R7/R9 flagged for the
  user at plan time).
- **A ledger `Ruling:` line is load-bearing and the ledger is git-ignored.**
  Every ruling that isn't restated in the plan or `HANDOFF.md` is lost at
  session end. This module's exit copied all of them into the plan verbatim
  (`## Execution rulings`) specifically so a future session (or the user)
  can still see the reasoning behind R1–R11, B1–B5, I1–I5, M1–M15, I-1/I-2,
  M-1–M-7 without the ledger.
- Docs-only task steps (Task 8's VERIFY-ME append) don't always need a
  reviewer seat — the controller reading the diff in place of one is a
  legitimate ruling, but log it as a ruling, not a silent skip, and let the
  final review cover the gap explicitly.

## M10 — what landed

Plan `docs/superpowers/plans/2026-09-20-m10-modes.md` (7 tasks; rulings
R1–R11 at its top, plus an `## Execution rulings` section added at this
exit copying the SDD ledger verbatim); ledger
`.superpowers/sdd/2026-09-20-m10-modes/execution-rulings.md` (git-ignored,
13 lines, copied into the plan before this exit). 8 commits, `2c235eb..2e6b2d2`:
`2c235eb`, `1da36c2` (Task 1, GauntletMaze sim), `42883d0` (Task 2, run
wiring), `5c723b9` (Task 3, mode visuals), `62c1402` (Task 4, banner),
`1677df2` (Task 5, Pause picker), `bbb3b5c` (Task 6, device checks recorded
unrun), `2e6b2d2` (final-review fixes F-1..F-4, folded in before Task 7 per
the ledger's "final review runs before Task 7" ruling).

| Area | Files |
|---|---|
| Full `GauntletMaze.ts` port minus `render()` | `src/sim/gauntlet_maze.gd` (new) |
| Mode captured at `reset_run`; owns the maze; passed through steps 4–8 | `src/sim/run_controller.gd` |
| `TODO(M10)` retags (R3, R7) | `src/sim/enemy_swarm.gd`, `src/core/game_state_machine.gd` |
| Owns/scales the maze; boots the saved mode; `_apply_game_mode()`/`set_game_mode()`; `restart_run` syncs `_state.mode` (F-2); grid clock refreshed on resize (F-3) | `src/core/game_root.gd` |
| Mode colours (R6), code-red vignette, gauntlet corner brackets | `src/render/grid_layer.gd` |
| Maze drawing (`bind_maze`, `_draw_maze`), shared-clip `stripe_polygons` (F-1), `beacon_pulse` | `src/render/entity_layer.gd` |
| Mode announcement banner, 0–2.8 s of run clock (R2) | `src/render/effect_layer.gd` |
| Temporary Pause mode picker, `DIVERGENCE(M10 R1)` (R1) | `src/ui/pause_sheet.gd` |
| Pause stats / Run over subtitle read `run.mode` (R4); R10 no-badge note | `src/ui/hud_controller.gd` |
| Tests | `tests/test_gauntlet_maze.gd` (new); additions to `test_run_controller.gd`, `test_main_scene.gd`, `test_render_layers.gd` (+ F-1's brute-force equality test), `test_pause_sheet.gd` |
| Device evidence (unrun, phone absent) | `godot/VERIFY-ME.md` §M10, 10 unticked checks |

**Rulings R1–R11** (plan, recorded 2026-09-24 before execution; full text in
the plan's Rulings section):
- **R1** — a temporary Pause-sheet mode picker (Segmented `Standard |
  Gauntlet | Code Red`) stands in for `Main.dc.html`'s mode cards (M11).
  Picking calls `GameRoot.set_game_mode` (saves); the running run keeps its
  mode until the next Restart run or Retry. `DIVERGENCE(M10 R1)`,
  `TODO(M11): remove when Main.dc.html's mode cards land`.
- **R2** — the mode banner (`TiltRenderer.ts:513-565`, uncalled in `web/src`)
  is drawn by `EffectLayer` from the run clock (`RunController.elapsed`) over
  each run's first 2.8 s; it hides at run end and shows again at reset.
- **R3** — the opening armada (`spawn_mode_armada`) stays with M11's
  cinematic handover; M10 retags its `TODO(M10)` as `TODO(M11)` and adds no
  stand-in.
- **R4** — `RunController` captures `mode` once in `reset_run`; every in-run
  read and both HUD reads use it (needed because R1 can change the saved
  choice mid-run).
- **R5** — `RunController` owns and resets the maze at its TS position (after
  `scores.reset()`, before `grid.resize`); assigned after construction, like
  `goals`, to keep the constructor under gdlint's 10-argument limit.
- **R6** — mode backgrounds in `TiltRenderer.ts:64-74` are dead in the TS
  (the equipped arena theme always overrides them) — ported anyway per LAW 2;
  what the player actually sees of a mode is the overlays, the maze and the
  banner.
- **R7** — `spawn_sequential_gauntlet_wall`/`spawn_rotating_gate` stay
  uncalled (the TS never calls them; `GauntletMaze.ts` builds the walls
  instead) — their `TODO(M10)`s become PORT-NOTEs.
- **R8** — each 6-px stripe stroke is its true clipped rectangle
  (`Geometry2D.intersect_polygons`), standing in for `ctx.clip()`, which has
  no CanvasItem equivalent; F-1 later shares this clip's work without
  changing the geometry.
- **R9** — the beacon glow (`shadowColor`/`shadowBlur`) waits for M11's
  on-device glow-cost ruling, same class as M2–M4's in-arena glow.
- **R10** — no HUD mode badge; the boards decide what a screen shows (M9 R10
  precedent) — the mode name appears on Pause and Run over instead.
- **R11** — `playGauntletKlaxon` stays uncalled (only referenced by the menu
  audio stub, out of scope).

**Final-review fix wave** (`.superpowers/sdd/2026-09-20-m10-modes/final-fix-report.md`,
base `bbb3b5c`, commit `2e6b2d2`):
- **F-1** — `stripe_polygons` shares one interior stroke's clip, translated
  per stripe instead of re-clipping each one; end stripes still fall back to
  the original full clip. Geometry is byte-for-byte identical (a new
  brute-force equality test proves it) — only the work changed. Benchmark:
  2.06 ms → 0.63 ms per synthetic frame on desktop (~3.3x).
- **F-2** — `GameRoot.restart_run` now sets `_state.mode =
  _run_controller.mode` after `reset_run`, so `GameStateMachine.mode` never
  goes stale after a Pause pick + restart (M11 reads it for the cinematic
  handover).
- **F-3** — `resize_canvas` now also calls `_grid_layer.set_elapsed(...)`, so
  the code-red vignette pulse keeps ticking through a resize.
- **F-4** — `VERIFY-ME.md` §M10's frame-time line corrected to the real scale
  (~650 clipped stripe polygons at 2340×1080, not full-arena-width estimate),
  plus two new device checks: **Early resize** (pre-resize row width persists
  until scroll-off, TS-faithful) and **Ship vs walls on mobile** (the 1.5×
  mobile ship overlaps sim-size walls/gaps, a consequence of the M2.5
  mobile-scale divergence, not an M10 change).

**Deferred minors** (left by ruling, ledger line 65 — final-review triage):
- `_draw_mode_banner` allocates a `StyleBoxFlat` every frame for the banner's
  2.8 s window instead of caching it.
- `BANNER_SUB` duplicates `UiTheme.COLOR_TEXT_MUTED` — kept as a render
  colour with its own `# PORT:` citation rather than reaching into the UI
  theme from a render layer.

**Verification**: 49/49 GUT scripts, 520 tests (519 plan total + the F-1
equality test), 17359 asserts; `gdformat`/`gdlint` clean; `TODO(M10)` grep
empty; `ff4757` grep empty; DIVERGENCE 177 total (106 `UI-SYSTEM`, 3
`M10 R1`); headless `--quit-after 120` 0 SCRIPT ERROR. Full command block
and fresh output: "## How to verify right now" above.

**Device pass pending**: the A55 was absent from `adb` on 2026-09-25.
`VERIFY-ME.md` §M10 has 10 unticked checks (picker, banner, gauntlet walls,
gauntlet crush, gauntlet score, Code Red, multipliers, frame time, early
resize, ship-vs-walls).

## Open questions (M10)

None raised during execution beyond the plan's own rulings (all resolved by
user ruling at plan time, R1–R11 above) and the final review's four fixes
(F-1..F-4, all fixed, none parked). `M11` must still: **remove the R1 Pause
picker** (`DIVERGENCE(M10 R1)`, `TODO(M11)` in `pause_sheet.gd` and
`hud_controller.gd`) once `Main.dc.html`'s mode cards land, and **port the
cinematic handover** (R3 — `TiltEntranceCinematic.ts:192-215`'s
`spawn_mode_armada` call plus Classic's 8-seeker/nuke-orb/2.5 s-shield
opening).

## M5 — what landed

Plan `docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md` (Tasks 1–6,
commits `160ebb2`..exit). No SDD ledger was kept; execution rulings are in the
plan's `## Execution rulings`.

| File | What |
|---|---|
| `tools/bake-audio/bake_sfx.mjs` | Runs `TiltAudio.ts` unmodified in headless Chrome (Puppeteer from `web/node_modules`), renders each `play*` through `OfflineAudioContext`, and writes 37 16-bit mono 44.1 kHz WAVs. Deterministic. |
| `godot/assets/audio/sfx/*.wav` (+ `.import`) | 37 baked files (15 `dot_pop_NN`, 4 `space_invader_step_N`, 18 singles), imported as QOA. |
| `godot/src/audio/audio_bank.gd` | `attach(host)` builds a 32-voice `AudioStreamPolyphonic` player and loads the bank. Every `play_*` plays its file. Mute and sfx volume drive `volume_linear`. Lightning is pitch-randomised. `music_gain` is stored for M6. `start_music`/`stop_music` are still `TODO(M6)`. |
| `godot/src/core/game_root.gd` | Calls `audio.attach(self)` in `_ready` (R10). |
| `godot/src/core/game_state_machine.gd` | `_init` takes `audio, options`. `unlock` fires at `launch_run`, `stop_music` at menu/stop/pause/armory, and `start_music` on resume when music is on. |
| `godot/src/sim/run_controller.gd` | Applies the mute/sfx/music options in `reset_run` (R11). |
| `godot/tests/spy_audio_bank.gd` | `SpyAudioBank`, a helper that records play and music-lifecycle requests. |
| `godot/tests/test_audio_bank.gd`, `test_audio_call_sites.gd` | Bank behaviour, plus proof that each live SFX fires at its TS moment. `test_game_state_machine.gd`, `test_run_controller.gd` and `test_main_scene.gd` were extended. |
| spec §4.2, §8 M5 | `.ogg` changed to `.wav`. |

Rulings, one line each:
- **R1** WAV (QOA import), not Ogg: this host has no Ogg encoder.
- **R2** 32-voice cap; overflow is dropped (`DIVERGENCE(M5 R2)`).
- **R3** The bake runs `TiltAudio.ts` unmodified, with only three page shims (offline context, instant `resume`, `Math.random` = 0.5).
- **R4** The baked level is the full TS graph (sfx 1.0 × master 0.28). At run time only sfx volume and mute are applied.
- **R5** Render length is each method's last `stop()` time, with no trim and no added tail.
- **R6** `dot_pop` ×15 and `space_invader_step` ×4. Lightning is baked at 1400 Hz and pitch-scaled at play time.
- **R7** No `GameEvents` wiring: the sim calls `AudioBank` directly, as the TS does.
- **R8** `ice_cascade`, `gauntlet_klaxon`, `space_invader_step`, `invasion_alarm` and `warp_in` are baked but not called. `play_warp_in` belongs to M11's cinematic.
- **R9** Music stays in M6. `music_gain` = clamp(vol) × 0.35 is public for M6.
- **R10** `attach()` stands in for `unlock()`'s context creation. `unlock()` is a no-op called at its TS site.
- **R11** Sound options are applied in `RunController.reset_run`, because Retry bypasses the state machine.

## Open questions (M5)

None raised during execution. The Task 4 milestone correction (a plan error,
not a port change) is recorded in the plan's `## Execution rulings`.

## M6 — what landed

Plan `docs/superpowers/plans/2026-09-20-m6-generative-music.md` (Tasks 1–4, commits
`c00cbfd`..exit), executed inline. The execution rulings are in the plan's
`## Execution rulings`. The final whole-branch review (fresh reviewer) found 0 Critical
and 0 Important issues. Two Minor findings about VERIFY-ME wording were re-graded
Important and fixed. The deferred Minors are listed under Open questions (M6).

| File | What |
|---|---|
| `tools/bake-audio/bake_music.mjs` | Loads `TiltAudio.ts` unmodified in headless Chrome and calls its `scheduleStep` for steps 0–511 on the scheduler's `+=` grid. It keeps cycle 2 (frames 1263761..2527522) and writes a 16-bit mono 44.1 kHz WAV. A fresh render within 1 LSB of the committed file keeps that file (Chrome jitters about 4 samples by 1 LSB). |
| `tools/bake-audio/wav.mjs` | The WAV encoder, shared by both bakes (moved out of `bake_sfx.mjs`, whose output is byte-identical). |
| `godot/assets/audio/music/music_loop.wav` (+ `.import`) | 28.66 s, peak 0.058. The import is QOA with `loop_mode=2`, `loop_begin=0` and `loop_end=1263761`. |
| `godot/src/audio/audio_bank.gd` | `attach` adds `_music_player`. `start_music` has the `:86` guard and plays from 0. `stop_music` stops. `_apply_volume` sets music to `0` when muted, else `music_gain / 0.35`. `set_music_volume` applies live. A PORT-NOTE marks the scheduler methods, which run inside the bake. |
| `godot/src/sim/run_controller.gd` | `reset_run` calls `start_music` when `music_enabled`, just before the starting-orb spawn (`TODO(M11)`: both move to the cinematic's end). |
| tests | `test_audio_bank.gd` +7 (now has `gdlint:disable=max-public-methods`), `test_audio_call_sites.gd` +2, `test_main_scene.gd` +1. |
| spec | D5, §4.2 and §8 M6 amended (R1). |

Rulings, one line each:
- **R1** One baked loop: no stems and no `music_sequencer.gd` (user ruling 2026-09-25).
- **R2** Steps 0–511 on the TS `+=` grid; keep cycle 2, whose head holds cycle 1's tails; 1263761 frames.
- **R3** The noise buffer is filled from a seeded mulberry32 (`0x5eed`), not `Math.random`. The bake is deterministic to ±1 LSB.
- **R4** Baked level = musicGain 0.35 × master 0.28. Run time: `volume_linear = music_gain / 0.35`, and 0 when muted.
- **R5** `start_music` returns early if playing, else plays from 0. `stop_music` stops. Resume restarts from the top, as in the TS. `unlock()` is not called.
- **R6** Mute keeps the loop running silently. The TS backlog burst is dropped (`DIVERGENCE(M6 R6)`). Today nothing reaches it: Pause has already stopped the music.
- **R7** Run start is at the end of `RunController.reset_run` until M11.
- **R8** No 50 ms lead-in, stop is immediate, and the first cycle carries the bar-15 tails (`DIVERGENCE(M6 R8)` ×2).
- **R9** The import loop settings are set explicitly. `loop_end=-1` would drop a frame.

## Open questions (M6)

None raised during execution. Deferred Minors from the final review, for the user:
- `test_the_boot_run_starts_the_music_when_it_is_on` checks only the silent branch if
  the host's saved options have music off.
- `bake_music.mjs` prints `kept` for a real TS change whose effect is ≤1 LSB. It could
  print the number of differing samples.
- `bake_music.mjs`'s mulberry32 and WAV-header literals have no citation comment.
- Spec §8 M6 still lists the old stems / `music_sequencer.gd` bullets above the R1
  amendment.

## Next

**M11a is planned** (`docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md`). Stop for the user's review of that plan; once approved, execute it from Task 1 with the execution method they choose. M11b and M11c plans are written at their own starts (see the plan's "Module split").

Before starting: `git status --short` must be clean under `godot/` (the user may leave device tuning uncommitted — never stash or revert it), and read `godot/VERIFY-ME.md`. If the A55 is back on `adb`, offer the device pass first.

Carried from the M6 exit into M11b/M11c:
- M11b: move `start_music` + `spawn_starting_weapon_orb` out of `RunController.reset_run`
  into the cinematic's completion callback (`TiltGame.ts:168-176`, M6 R7), and call
  `play_warp_in` from the cinematic (`TiltEntranceCinematic.ts:74`, M5 R8).
- If a mid-play mute is ever ported (`btn-tilt-sound` → `toggleMute`, `TiltGame.ts:1441`),
  M6 R6's silent-loop mute becomes reachable — add a device check for it.
- Re-bake the music only if `TiltAudio.ts:82-479` changes (`node tools/bake-audio/bake_music.mjs`,
  then `--import`); update `edit/loop_end` if the frame count changes.
- M11c owns the device pass: M2.5, M3, M4, M5, M6, M7, M8.5, M9, M10, the scale split and
  M11a are all pending in `VERIFY-ME.md`.
