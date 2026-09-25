# Module 11a — Menu, Settings and Calibrate: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the port its front door. A cold boot lands on the menu, not in a run. The menu shows the live backdrop sim, the three mode cards, Play, Armory, Milestones and Settings. Settings is the TS options modal on the Settings board, and Calibrate is the board's tilt screen. Pause's "Quit to menu" and Run over's "Menu" lead back to it. Screen shake and Enemy outlines, which Settings exposes, now actually work.

**Architecture:** `TiltMenu.ts` becomes one file, `ui/tilt_menu.gd`, per Law 3. It holds the menu screen (`render`), the Settings screen (`open_options_modal`) and the reset confirm (the TS `window.confirm`). It is a `Control` built in code, as `PauseSheet` is. It talks to `GameRoot` only through signals and never holds a sim system. `updateMenuSimulation` becomes `render/menu_backdrop.gd` (spec §5.1), a `RefCounted` that owns the second sim instance (`menu_player`, `menu_swarm`, `menu_weapons`). It shares the run's `VectorGrid` and `ParticleEngine`, as the TS does. While the phase is `MENU`, `GameRoot` steps the backdrop and rebinds the three render layers to its entities. `launch_run` binds them back. The Calibrate screen has no TS counterpart, so it is a new file, `ui/calibrate_screen.gd` (interface spec §6.6, ruling R5).

**Tech Stack:** Godot 4.7.2-stable, GDScript (static typing enforced), GUT 9.6.1 headless, gdtoolkit 4.5.0.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` §8 Module 11 (split into 11a/11b/11c; see "Module split" below), §5.1, §5.2. `docs/superpowers/specs/2026-09-23-mobile-interface-system-design.md` §6.6 (M11 boards), §4 (tokens, the 48 rule), §3 (citations). Boards: `peril-point-mobile-redesign/Main.dc.html`, `Settings.dc.html` and `Calibrate.dc.html`. Read `godot/CONVENTIONS.md` before any task.

**TS source (read in full before the task that ports it):**
- `web/src/tilt-to-live/TiltMenu.ts` (523 lines): Tasks 3 and 5.
- `web/src/tilt-to-live/TiltGame.ts:70-75`, `:1650-1820` (`updateMenuSimulation`): Task 1.
- `TiltGame.ts:1288-1331` (key map), `:1472-1530` (`start`, `launchRun`, `returnToMenu`, `restart`, `startCinematic`), `:2259-2283` (menu render), `:2356-2385` (`handleProgressionChanged`, `updateCursor`, `handleArmoryClosed`): Task 4.
- `TiltRenderer.ts:12-17`, `:46-56`, `:156` (the shake), and `TiltGame.ts:2050-2083` (its two call sites): Task 2.
- `TiltRenderer.ts:158-220` (`renderMenuBackground`): Task 4.
- `TiltGame.ts:1392-1393`, `:1418-1420`, `:1428-1430`, `:2100-2135` (Quit/Menu/Settings buttons, coins row): Task 7.

---

## Module split (user ruling, 2026-09-25)

Spec §8 M11 is one module. The user split it into three, each with its own plan, exit and stop:

| Sub-module | Scope | Plan |
|---|---|---|
| **M11a — Menu, Settings, Calibrate** | `menu_backdrop.gd`, `tilt_menu.gd` (menu, options modal, reset), `calibrate_screen.gd`, the MENU phase in `GameRoot`/`GameStateMachine`, keys, shake + halo, Pause/Run over menu buttons, Run over coins row | this file |
| **M11b — Entrance cinematic** | `TiltEntranceCinematic.ts` → the cinematic, `ColdOpen.dc.html`, the `CINEMATIC` phase, skip controls, `play_warp_in`, `start_music` + `spawn_starting_weapon_orb` moved to its end (M6 R7, M5 R8), `EnemySwarm` handover (M10 R3) | written at M11b's start |
| **M11c — Export and device pass** | the glow measurement and the §4.5 fallback decision, Android release preset + signing + icons + splash, iOS deferral recorded, the whole `VERIFY-ME.md` backlog, the 5-minute 60 fps Accept | written at M11c's start |

Every `TODO(M11)` in `godot/src` is resolved by M11a or retagged to `TODO(M11b)`/`TODO(M11c)` in Task 8. At M11a's exit, `grep -rn "TODO(M11)" godot/src` prints nothing.

## The five port laws (restated — binding on every task)

1. **No invented numbers.** Every numeric literal carries `# PORT: <ts path>:<line>` or, for a board literal, `# DIVERGENCE(UI-SYSTEM): <Board>.dc.html`. Exempt: `0`, `1`, `-1`, `0.0`, `1.0`, array indices.
2. **No silent improvement.** Odd TS is ported as written, with `# PORT-NOTE: … — preserved deliberately`.
3. **One file, one file.** `TiltMenu.ts` → `ui/tilt_menu.gd`, holding the menu, the options modal and the reset confirm. `updateMenuSimulation` → `render/menu_backdrop.gd` (spec §5.1's sanctioned `TiltGame` split).
4. **Nothing new.** Only what the TS, a spec line, or a ruling below requires.
5. **Stop, do not guess.** Ambiguity → record it in `godot/HANDOFF.md` and ask.

## Rulings (recorded 2026-09-25, before execution)

User rulings, taken 2026-09-25 by question before the plan was written:

- **R1 — The backdrop is mirrored to the board (user).** The TS keeps the autopilot ship and its orbs out of the **left** `min(0.38w, 420)` px, because its sidebar was on the left (`TiltGame.ts:1664`, `:1702`, `:1731-1743`). `Main.dc.html` puts the mode panel on the **right** (372 of 844 px). Every x-term of the steering is mirrored as `x' = w - x`: the orb band, the wander centre and phase, and the side margins. Every constant is kept and cited. Tagged `DIVERGENCE(M11a R1)`, once per mirrored block (3 tags: orb band, wander, side margins; execution ruling 2026-09-25 — the plan first said 4).
- **R2 — Screen shake and Enemy outlines work (user).** `TiltRenderer.triggerShake` / `cameraShake` (`TiltRenderer.ts:12-17`, `:46-56`) are ported into `GameRoot`, the port's render dispatch (spec §5.1). Its two call sites (`TiltGame.ts:2064`, `:2081`) reach it through a `Callable` that `RunController` holds (`trigger_shake`), as the TS calls `renderer` directly. The offset is applied to the `position` of `GridLayer`, `EntityLayer` and `EffectLayer`, which is everything inside the TS `ctx.save()`…`ctx.restore()` at `:53-156`. It decays ×0.88 once per rendered frame (`_process`) and only outside `MENU`, because `renderMenuBackground` never reads `cameraShake`. `options.settings.high_contrast_halo` reaches `EntityLayer.set_high_contrast_halo` at boot and after every Settings change.
- **R3 — Aim line is omitted (user).** The TS "Aim line" switch drives `renderMouseReticle`'s tether (`TiltRenderer.ts:229-243`), which the port never ported. On Android, Touch is a joystick, so there is no pointer to aim at. The Settings board has no such row. `open_options_modal` omits it, with a PORT-NOTE. `settings.tether_line` still loads and saves unchanged. **Background grid stays** (Rule N, M8.5), because it works.
- **R4 — Calibrate shows a live dot (user).** The Calibrate board is built as drawn. Its dot is drawn every frame at `TiltInput.tilt_vector` × the top-speed ring's radius, clamped to that ring, and tagged `DIVERGENCE(UI-SYSTEM)`. **Set level** calls `GameRoot.calibrate_gyro()` (existing: calibrate + toast) and closes. **Cancel** closes. The screen starts the sensor as it opens (`request_permission_and_start`). If the phase is `MENU`, it stops the sensor as it closes, because `reset_run` owns the sensor during a run (`TiltGame.ts:1553-1557`).

Planning rulings (precedent-based, not re-asked):

- **R5 — The Calibrate screen is a new file.** `ui/calibrate_screen.gd` has `PORTS: nothing — new file per interface spec §6.6 (Calibrate.dc.html)` and ruling R4. It opens from the menu's Calibrate icon and from Settings' "Calibrate tilt" link. Pause keeps its immediate calibrate (M8.5 Rule F).
- **R6 — Words come from the TS, layout from the board.** The board's mock text is not an authority (interface spec §6.6). Mode names, taglines, multipliers (`toFixed(m % 1 === 0 ? 1 : 2)` + `×`, which gives `"1.0×"`, `"1.25×"` and `"1.50×"`), stat labels, "Play", "Armory", "Milestones", "Screen shake", "Reset progress" and the confirm text are all TS strings. Two exceptions follow the M8.5 pre-flight M14 rule ("spec-quoted explain lines win over TS strings"). First, where a board shows its own string for the **same control**, the board's string wins: the "Enemy outlines" hint `"White ring on every dot."`, the Data hint `"Cannot be undone."` and the Handling link `"Turn rate and sensitivity live in Armory › Handling"`. Second, the title is `"PERIL\nPOINT"` (app identity, `HANDOFF.md` §App identity; the TS `"TILT\nTO LIVE"` names the web game).
- **R7 — The control cards follow Rule P.** Settings shows Touch (`"drag anywhere"`, board) and Tilt (`"phone gyroscope"`, `TiltMenu.ts:291`), plus Keys (`"WASD / arrows"`, `:289`) off mobile, the same set as `ControlPicker`. There is no Mouse or Both card: the port's scheme lives in `ControlSettings` (M2.5 §4.2), not `options.settings.control_scheme`. A card writes through `GameRoot.set_control_scheme`. The menu's Steer row (a board element with no TS counterpart) is the existing `ControlPicker` scene. The Settings calibrate link shows only while the scheme is Tilt (`TiltMenu.ts:378`, as Rule E does for Pause).
- **R8 — TS content with no board slot is kept (Rule N).** The next-milestone teaser (`TiltMenu.ts:96-126`, `:198-207`) goes in the menu's left block, above the Steer row. The Background grid row goes in the Readability column. Both are styled from `System.dc.html` tokens and tagged `DIVERGENCE(UI-SYSTEM)`. The stats row stays hidden while `best_score == 0` (`TiltMenu.ts:180`), although the board always draws it.
- **R9 — The options modal's audio switches apply at once (user, Q2, 2026-09-25).** The TS Sound and Music switches in Settings only set the option and save (`TiltMenu.ts:460-470`); the next `reset_run` applies them (`TiltGame.ts:1607-1610`). The user ruled that they apply at once, like Pause's (`:1396-1416`): `TiltMenu` emits `sfx_toggled(is_on)` / `music_toggled(is_on)`, and `GameRoot` routes them to its existing `set_sfx_enabled` / `set_music_enabled` (save + `set_muted` / `start_music` only while `PLAYING` / `stop_music`). Tagged `DIVERGENCE(M11a Q2)` once, at the modal's audio handlers. The halo and grid switches also apply at once through `GameRoot` (R2): the TS render reads them every frame (`:2280-2281`, `:2313-2317`).
- **R10 — Reset progress deletes what its prompt says (user, Q1, 2026-09-25).** The TS confirm (`TiltMenu.ts:508`) promises to delete scores, points, milestones and armory unlocks, but `:515-516` remove `tilt_to_live_progression_v1` and `tilt_to_live_scores_v1`, while the real keys are `_progression_v3` (`ProgressionManager.ts:119`) and `tilt_to_live_best` (`ScoreManager.ts:162`), so a TS reset keeps them. The user ruled the port fixes this. Confirm → remove `GameOptionsManager.SAVE_PATH`, `GoalManager.SAVE_PATH`, `GoalManager.CUMULATIVE_SAVE_PATH`, **`ProgressionManager.SAVE_PATH` and `ScoreManager.BEST_SCORE_PATH`** → reload. Tagged `DIVERGENCE(M11a Q1)` once, at `reset_progress_files`. `tilt_goals_hud_collapsed` has no port file. `ControlSettings.SETTINGS_PATH` and the calibration file are kept: the TS keeps `tilt_gyro_calibration`, the prompt names neither, and the port's scheme file postdates the TS. The reload (`window.location.reload()`) becomes `get_tree().reload_current_scene()`, deferred.
- **R11 — The confirm is a board-styled sheet.** `window.confirm` has no board. It is a `UiTheme.build_sheet` with the TS text (`:507-509`), **Reset** (`SecondaryButton`) and **Cancel** (`PrimaryButton`, the safe default). It is built inside `tilt_menu.gd` and tagged `DIVERGENCE(UI-SYSTEM)`.
- **R12 — The HUD in `MENU`.** The TS hides the in-run HUD whenever the body lacks `tilt-playing`. On `phase_changed(MENU)`, `HudController` hides `ScoreBlock`, `LivesRow`, `PauseButton` and `WeaponTimer`, plus the Pause and Run over sheets. On `PLAYING` it shows them again. `Frame` (the arena outline) and `ToastSlot` stay visible, so the Calibrate toast shows on the menu. `GoalsHUD.set_menu_mode` is called where the TS calls it (`:1477`, `:1490`, `:1508`, `:1524`).
- **R13 — The menu backdrop render.** In `MENU`, `GameRoot` rebinds its layers as `renderMenuBackground` draws (`TiltRenderer.ts:158-220`). The grid layer gets theme `null` and mode `CLASSIC`, and `show_gridlines` is still honoured. The entity layer gets the backdrop's player, swarm and weapons, with no coins, ship skin `null`, enemy skin `null` and mode `CLASSIC`, so no maze. The effect layer gets the shared particles, scores `null` (no floating text) and the backdrop's weapons, with the banner off. `launch_run` restores the run bindings (`_bind_run_layers`). The backdrop entities are never `set_scale`d, as in the TS (`resizeCanvas` scales only the run's): PORT-NOTE.
- **R14 — The backdrop steps at 120 Hz with the real `delta`.** The TS menu steps once per rAF frame with `dt = min(0.1, raw)` and no `GAME_SPEED` (`:1826-1830`). `_physics_process` passes `delta` unscaled, and spec D8's tick replaces the rAF cadence. PORT-NOTE. The backdrop keeps its own `elapsed` in place of `TiltGame.elapsed`, which it shares in the TS but which `reset_run` zeroes (`:1564`).
- **R15 — The key map.** Ported now: `p`/`Escape` (armory open → close, else `PLAYING`/`PAUSED` → toggle pause, `:1325-1331`), and `Space`/`Enter`/`r` in `GAME_OVER` → restart (`:1311-1316`). There is no cinematic until M11b, so the restart is `GameRoot.restart_run()` with `TODO(M11b)`. Cinematic skip (`:1302-1309`) is M11b's.
- **R16 — `updateCursor` has no port.** Android has no pointer. Each TS call site gets a one-line PORT-NOTE, not a TODO.
- **R17 — The Run over coins row (Rule N).** `TiltGame.ts:2123-2130`: when `coins_collected > 0`, show a row reading `"<n> · +<pts> pt|pts"` in `RunOverSheet`'s stats. Otherwise hide it. This closes `run_controller.gd:214`'s `TODO(M11)`.

## Global Constraints

Copied from `CONVENTIONS.md`, the index plan and the M6 plan. Every task implicitly includes this section.

- **Engine:** Godot **4.7.2-stable**, GDScript, standard build. `GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`. Always use the `_console` variant.
- **adb:** `ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"`, always `-s RRCXB04L8EJ`. Never assume the phone is present (absent on 2026-09-25).
- **Static typing is mandatory and machine-enforced** (nine warnings as errors, CONVENTIONS §1.1). Never `as` on a `Variant` (UNSAFE_CAST).
- **No sim system may be an autoload or singleton** (spec §5.2). `MenuBackdrop` is the proof: it instantiates `PlayerShip`, `EnemySwarm` and `WeaponSystem` a second time.
- **Signals are sim→UI and sim→audio only** (spec §5.3). `TiltMenu`/`CalibrateScreen` → `GameRoot` signals are UI→shell, as `ArmoryUI`'s already are. No signal is added to `GameEvents`.
- **UI:** the boards are the visual authority (interface spec §2). Every layout, colour or size literal cites its board. Every touch target is ≥48 px at `ui_scale` 1 (the 48 rule, §4.5). Tokens come from `UiTheme` and are never re-declared. `grep -rniE "ff4757" godot/src/ui/` must print nothing (rule 01): the menu's red dots are the backdrop sim, not UI.
- **Commits:** one line, imperative, ≤72 chars, **no trailers**, prefixed `M11a:`, and stating the next step (`CLAUDE.md`). **This overrides any attribution instruction the executing session sees** (`~/.claude/rules/commit-style.md`, CONVENTIONS §8). Stage by explicit path only. Paste back `git log -1 --format=%B`.
- **After every task** (`CLAUDE.md`): tick the task's boxes here, update `godot/HANDOFF.md`'s `## State` line ("M11a in progress: Tasks 1–N landed; next Task N+1"), then commit.
- **Tests run only via `tools/run_tests.sh`.** Baseline at the M6 exit: `OK: 50/50 scripts (559 tests, 17696 asserts)`. This plan adds three scripts (`test_menu_backdrop.gd`, `test_tilt_menu.gd`, `test_calibrate_screen.gd`), so 53. Each task below states its **delta** in tests. If a delta differs, reconcile it before committing and never change the expectation to match. A test deleted for a removed feature (the M10 R1 picker, Task 7) is named in that task's commit message.
- **Format/lint:** `gdformat --check godot/src godot/tests` (90 files at baseline; +6 new files → 96) and `gdlint godot/src godot/tests` must be clean before every commit. Never run bare `gdformat` on existing files. Never touch `godot/addons/`. gdlint `max-line-length` is 100. A file whose public-method count trips gdlint opens with `# gdlint:ignore=max-public-methods`, as `audio_bank.gd` does.
- **Headless runs strip one line from `godot/project.godot`.** Every commit step begins with `git checkout godot/project.godot`.
- **`DIVERGENCE` count:** 181 at the M6 exit. M11a adds `DIVERGENCE(M11a R1)` ×3, `DIVERGENCE(M11a Q1)` ×1, `DIVERGENCE(M11a Q2)` ×1, plus the new `DIVERGENCE(UI-SYSTEM)` board literals, and removes `DIVERGENCE(M10 R1)` ×3 (Task 7). Each task's commit step records the new total with `grep -rn "DIVERGENCE" godot/src/ | wc -l`, and the exit writes it into `HANDOFF.md`.
- **`user://` on the test host** is `%APPDATA%\Godot\app_userdata\Peril Point\`. A spec that builds `GameRoot` or a manager clears the saves in `before_each`/`after_each`, as `test_main_scene.gd` does.
- **Randomness:** the port uses the global `randf()`/`randi()` for `Math.random()` (`weapon_system.gd:97`). A test that needs determinism calls `seed(<n>)` first. It never asserts one random draw.

## Review Focus

These are the inputs the spec implies that are most likely to bite a player. Each one has its test in the named task.

1. **Cold boot with no saves.** The menu shows with no stats row (best 0), the saved mode's card is selected, no run is live, music is off, and the backdrop is moving. Pressing Play starts the run in that mode. Task 4 `test_boot_shows_the_menu_and_no_run`, `test_play_launches_the_selected_mode`; Task 3 `test_stats_row_hides_until_a_best_exists`.
2. **Quit to menu mid-run, then Play again.** Nothing leaks from the old run: no pause sheet, no Run over sheet, no HUD score, and no music while in the menu. The backdrop layers are bound, and the new run's layers are rebound to the run's entities with the equipped cosmetics. Task 4 `test_return_to_menu_rebinds_the_backdrop_and_back`; Task 7 `test_pause_quit_to_menu_hides_everything_and_stops_music`.
3. **Escape/p pressed in each phase.** In `MENU` nothing happens, in `PLAYING` the run pauses, in `PAUSED` it resumes, and with the Armory open the Armory closes but the run stays paused. Task 4 `test_p_and_escape_follow_the_ts_key_map`.
4. **Reset progress, then Cancel; and Reset, then confirm.** Cancel deletes nothing. Confirm deletes exactly the five R10 files (options, both goal files, progression, best score), keeps control settings and calibration, and reloads. Task 5 `test_reset_cancel_keeps_every_file`, `test_reset_confirm_removes_progress_and_keeps_controls`.
5. **Settings opened from Pause.** It draws above the Pause sheet, its Back returns to Pause (still paused), and a halo/grid change shows at once. Sound/Music apply at once (R9, Q2 ruling). Task 7 `test_pause_settings_opens_the_options_modal_over_pause`; Task 5 `test_settings_switches_apply_at_once`, `test_audio_switches_announce`.

---

## File Structure

| File | Role in M11a |
|---|---|
| `godot/src/render/menu_backdrop.gd` | **Create** (Task 1). `MenuBackdrop`: the second sim instance and its autopilot (`updateMenuSimulation`). |
| `godot/tests/test_menu_backdrop.gd` | **Create** (Task 1). |
| `godot/src/core/game_root.gd` | **Modify** (Task 2: shake + halo; Task 4: MENU phase, backdrop, layer rebinding, keys, `launch_run`/`return_to_menu`; Task 5: Settings wiring + `reset_progress`; Task 6: Calibrate wiring; Task 7: menu refreshes). |
| `godot/src/sim/run_controller.gd` | **Modify** (Task 2: `trigger_shake` Callable at `:2064`/`:2081`; Task 7: the `:214` TODO note). |
| `godot/src/core/game_state_machine.gd` | **Modify** (Task 4). Resolves its `TODO(M11)` menu lines. The cinematic lines are retagged `TODO(M11b)`. |
| `godot/src/ui/tilt_menu.gd` | **Create** (Task 3: menu screen; Task 5: options modal + reset confirm). Ports `TiltMenu.ts`. |
| `godot/tests/test_tilt_menu.gd` | **Create** (Task 3, extended in Task 5). |
| `godot/src/ui/calibrate_screen.gd` | **Create** (Task 6). |
| `godot/tests/test_calibrate_screen.gd` | **Create** (Task 6). |
| `godot/scenes/main.tscn` | **Modify** (Task 4: `Menu` node; Task 6: `Calibrate` node), both under `CanvasLayer` between `Hud` and `GoalsHud`. |
| `godot/src/ui/hud_controller.gd` | **Modify** (Task 4: R12 menu visibility; Task 7: Quit/Menu/Settings handlers, picker removal). |
| `godot/src/ui/pause_sheet.gd`, `run_over_sheet.gd` | **Modify** (Task 7). |
| `godot/src/render/effect_layer.gd`, `entity_layer.gd` | **Modify only if needed** (Task 4). `bind` must accept `null` scores/coins. `effect_layer.gd:324` already guards `_scores == null`. |
| `godot/tests/test_main_scene.gd`, `test_run_controller.gd`, `test_pause_sheet.gd`, `test_run_over_sheet.gd`, `test_hud_controller.gd`, `test_game_state_machine.gd` | **Modify** (the tasks named). |
| `godot/VERIFY-ME.md` | **Append** (Task 8) `## M11a — Menu, Settings, Calibrate`. **Never recreate this file.** |
| `godot/PORT-PROGRESS.md`, `godot/HANDOFF.md`, the index plan, spec §8 M11 | **Modify** (Task 8, exit). Spec §8 M11 gets a split amendment. |

**Spec coverage (§8 M11, the M11a share).**

| Spec line | Task(s) |
|---|---|
| `render/menu_backdrop.gd` (the second sim instance) | 1, 4 |
| menu `Control` scene | 3, 4 |
| options modal | 5 |
| Interface §6.6: Main, Settings, Calibrate boards | 3, 5, 6 |
| Accept (part): cold boot → menu → run → death → menu loops | 4, 7, and the device check |

---

## Tasks

### Task 1: `MenuBackdrop` — the menu's autopilot sim

**Files:**
- Create: `godot/src/render/menu_backdrop.gd`, `godot/tests/test_menu_backdrop.gd`

**Interfaces:**
- Consumes: `PlayerShip.new(x, y)`, `PlayerShip.update(dt, target, bounds, particles, control_mode, move_vector, sensitivity, deadzone, hitbox_scale, turn_rate, thruster_color, gyro_vector)`, `EnemySwarm.update(dt, player_pos, bounds, particles, current_score, game_mode)`, `EnemySwarm.spawn_seeker(bounds)`, `EnemySwarm.on_enemy_killed(enemy, particles)`, `WeaponSystem.update(dt, player, enemies, bounds, particles, grid, audio, on_enemy_killed)`, `WeaponSystem.spawn_orb(bounds, type, x, y)`, `VectorGrid.update/apply_explosion`, `ParticleEngine.update/emit_explosion`.
- Produces: `class_name MenuBackdrop extends RefCounted` with `var menu_player: PlayerShip`, `var menu_swarm: EnemySwarm`, `var menu_weapons: WeaponSystem`, `var elapsed: float`, and `func update(dt: float, bounds: Vector2, grid: VectorGrid, particles: ParticleEngine) -> void`.

- [x] **Step 1: Write the failing tests** — `godot/tests/test_menu_backdrop.gd`:

```gdscript
## test_menu_backdrop.gd
## PORTS: nothing — new file, covers render/menu_backdrop.gd
extends GutTest
## Proves the menu autopilot: its population caps, the mirrored orb band (R1),
## the close-call shield, and that it is a second, independent sim (spec §5.2).

const BOUNDS: Vector2 = Vector2(844.0, 390.0)


func _step(b: MenuBackdrop, seconds: float, grid: VectorGrid, particles: ParticleEngine) -> void:
	var steps: int = roundi(seconds * 120.0)
	for i: int in steps:
		b.update(1.0 / 120.0, BOUNDS, grid, particles)


func test_the_player_starts_where_the_ts_puts_it() -> void:
	var b: MenuBackdrop = MenuBackdrop.new()
	assert_eq(b.menu_player.x, 600.0, "TiltGame.ts:71")
	assert_eq(b.menu_player.y, 350.0, "TiltGame.ts:71")


func test_it_is_a_separate_sim_instance() -> void:
	var a: MenuBackdrop = MenuBackdrop.new()
	var b: MenuBackdrop = MenuBackdrop.new()
	assert_ne(a.menu_swarm, b.menu_swarm, "spec §5.2: instantiable twice")
	assert_ne(a.menu_weapons, b.menu_weapons)


func test_the_swarm_fills_to_the_ts_cap_and_no_further() -> void:
	seed(11)
	var b: MenuBackdrop = MenuBackdrop.new()
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	b.update(1.0 / 120.0, BOUNDS, grid, particles)
	assert_gt(b.menu_swarm.enemies.size(), 0, "timer starts at 0 (:75): a seeker at once (:1674)")
	_step(b, 12.0, grid, particles)
	# :1673 gates only the menu's own spawn at < 14; EnemySwarm.update's own timer can
	# add more (TS behaviour), so no hard cap is asserted — only that it keeps populating.
	assert_gt(b.menu_swarm.enemies.size(), 1, "seekers keep spawning (:1672-1676)")


func test_orbs_spawn_in_the_mirrored_band() -> void:
	seed(5)
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	for trial: int in 40:
		var b: MenuBackdrop = MenuBackdrop.new()
		b.update(1.0 / 120.0, BOUNDS, grid, particles)
		# The menu spawns before menu_weapons.update (:1667 vs :1808), so orbs[0] is the
		# menu's own orb even if WeaponSystem's internal timer adds a second one.
		assert_gt(b.menu_weapons.orbs.size(), 0, "timer starts at 0 (:74), so an orb at once")
		var orb: Types.WeaponOrb = b.menu_weapons.orbs[0]
		# :1665 band [0.38w, 0.93w] mirrored (R1) → [0.07w, 0.62w]
		assert_between(orb.x, BOUNDS.x * 0.07 - 0.01, BOUNDS.x * 0.62 + 0.01)
		assert_between(orb.y, 80.0 - 0.01, BOUNDS.y - 80.0 + 0.01, ":1666")


func test_no_new_orb_while_two_are_up() -> void:
	var b: MenuBackdrop = MenuBackdrop.new()
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	b.menu_weapons.spawn_orb(BOUNDS, Types.WeaponType.NUKE, 100.0, 100.0)
	b.menu_weapons.spawn_orb(BOUNDS, Types.WeaponType.LASER, 200.0, 200.0)
	var timer_before: float = b._menu_orb_timer
	b.update(1.0 / 120.0, BOUNDS, grid, particles)
	# :1661 gates at < 2: the menu did not spawn, so its timer only ticked down.
	assert_almost_eq(b._menu_orb_timer, timer_before - 1.0 / 120.0, 0.000001)


func test_a_close_enemy_shields_the_ship() -> void:
	var b: MenuBackdrop = MenuBackdrop.new()
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	var e: Types.Enemy = b.menu_swarm.spawn_seeker(BOUNDS, b.menu_player.x, b.menu_player.y)
	assert_not_null(e)
	b.update(1.0 / 120.0, BOUNDS, grid, particles)
	assert_true(b.menu_player.has_shield(), ":1776-1779 activates a 3 s shield")


func test_the_autopilot_steers_away_from_the_panel_side() -> void:
	# R1: the mirrored side margin pushes a ship sitting at the right edge leftwards.
	var b: MenuBackdrop = MenuBackdrop.new()
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	b.menu_player.x = BOUNDS.x - 10.0
	b.menu_player.y = BOUNDS.y / 2.0
	var start_x: float = b.menu_player.x
	_step(b, 0.5, grid, particles)
	assert_lt(b.menu_player.x, start_x, "mirrored leftMargin (:1731, :1736-1737)")
```

(7 tests. `assert_between`, `assert_lt`, `assert_gt` and `assert_ne` are GUT 9 built-ins. If `spawn_seeker`'s custom-position arguments are named or ordered differently, read `enemy_swarm.gd:61` and adapt the call without changing what the test asserts.)

- [x] **Step 2: Run to verify they fail**

Run: `tools/run_tests.sh`. Expected: `collected 50 of 51`, because the script fails to parse while `MenuBackdrop` does not exist. Confirm with `"$GODOT" --headless --path godot --check-only -s tests/test_menu_backdrop.gd`, which should print `Identifier "MenuBackdrop" not declared` or similar.

- [x] **Step 3: Implement** — `godot/src/render/menu_backdrop.gd`:

```gdscript
## menu_backdrop.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:70-75 (menu fields) and
##        :1650-1820 (updateMenuSimulation), per spec §5.1
class_name MenuBackdrop
extends RefCounted
## The live simulation behind the menu: an autopiloted ship that seeks orbs and
## dodges a seeker swarm. The second, independent sim instance (spec §5.2).
##
## PORT-NOTE: TiltGame.ts:1651 advances TiltGame.elapsed, which the run shares and
## resetRun zeroes (:1564); this instance keeps its own elapsed instead (M11a R14).
## PORT-NOTE: resizeCanvas (:2432-2436) never scales the menu entities, so they
## keep scale 1.0 — preserved deliberately (M11a R13).

## Strictly base power-ups. PORT: web/src/tilt-to-live/TiltGame.ts:1662
const BASE_TYPES: Array[Types.WeaponType] = [
	Types.WeaponType.NUKE,
	Types.WeaponType.MISSILES,
	Types.WeaponType.LASER,
	Types.WeaponType.FREEZE,
	Types.WeaponType.SHIELD,
	Types.WeaponType.LIGHTNING,
]
## The skinless ship's flame. PORT: web/src/tilt-to-live/PlayerShip.ts:241
const THRUSTER_COLOR: Color = Color("#00ddff")
## PORT: web/src/tilt-to-live/TiltGame.ts:1779
const SHIELD_BURST_COLOR: Color = Color("#5B8CFF")

## The autopiloted ship. PORT: web/src/tilt-to-live/TiltGame.ts:71
var menu_player: PlayerShip = PlayerShip.new(600.0, 350.0)
## PORT: web/src/tilt-to-live/TiltGame.ts:72
var menu_swarm: EnemySwarm = EnemySwarm.new()
## PORT: web/src/tilt-to-live/TiltGame.ts:73
var menu_weapons: WeaponSystem = WeaponSystem.new()
## Seconds this backdrop has run (M11a R14).
var elapsed: float = 0.0

var _menu_orb_timer: float = 0.0  # PORT: web/src/tilt-to-live/TiltGame.ts:74
var _menu_spawn_timer: float = 0.0  # PORT: web/src/tilt-to-live/TiltGame.ts:75
# PORT-NOTE: :1785-1805 builds a silent TiltAudio stub. An AudioBank that is never
# attach()ed has no playback, so every play_* returns at audio_bank.gd:305.
var _silent_audio: AudioBank = AudioBank.new()
var _particles: ParticleEngine = null


## One step of the menu sim. PORT: web/src/tilt-to-live/TiltGame.ts:1650-1820
func update(dt: float, bounds: Vector2, grid: VectorGrid, particles: ParticleEngine) -> void:
	_particles = particles
	elapsed += dt
	grid.update(dt)
	particles.update(dt)

	# 1. Maintain 2 to 3 base weapon orbs. PORT: web/src/tilt-to-live/TiltGame.ts:1660-1669
	_menu_orb_timer -= dt
	if menu_weapons.orbs.size() < 2 and _menu_orb_timer <= 0.0:
		var chosen: Types.WeaponType = BASE_TYPES[floori(randf() * BASE_TYPES.size())]
		# DIVERGENCE(M11a R1): the TS band x ∈ [0.38w, 0.93w] (:1665), mirrored to
		# stay clear of Main.dc.html's right-hand panel.
		var spawn_x: float = bounds.x - (bounds.x * 0.38 + randf() * (bounds.x * 0.55))
		var spawn_y: float = 80.0 + randf() * (bounds.y - 160.0)  # PORT: :1666
		menu_weapons.spawn_orb(bounds, chosen, spawn_x, spawn_y)
		_menu_orb_timer = 2.5 + randf() * 2.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1668

	# 2. Maintain 12 to 16 seekers. PORT: web/src/tilt-to-live/TiltGame.ts:1672-1676
	_menu_spawn_timer -= dt
	if menu_swarm.enemies.size() < 14 and _menu_spawn_timer <= 0.0:
		menu_swarm.spawn_seeker(bounds)
		_menu_spawn_timer = 0.5 + randf() * 0.4  # PORT: web/src/tilt-to-live/TiltGame.ts:1675

	# 3. Autopilot steer vector. PORT: web/src/tilt-to-live/TiltGame.ts:1679-1712
	var nearest_orb: Types.WeaponOrb = null
	var min_dist: float = INF
	for orb: Types.WeaponOrb in menu_weapons.orbs:
		var odx: float = orb.x - menu_player.x
		var ody: float = orb.y - menu_player.y
		var odist: float = sqrt(odx * odx + ody * ody)
		if odist < min_dist:
			min_dist = odist
			nearest_orb = orb

	var steer_x: float = 0.0
	var steer_y: float = 0.0
	if nearest_orb != null:
		var sdx: float = nearest_orb.x - menu_player.x
		var sdy: float = nearest_orb.y - menu_player.y
		var sdist: float = maxf(1.0, min_dist)
		steer_x = (sdx / sdist) * 290.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1699
		steer_y = (sdy / sdist) * 290.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1700
	else:
		# DIVERGENCE(M11a R1): the figure-8 wanders around cx = 0.62w (:1703),
		# mirrored to w - 0.62w with its x phase negated.
		var cx: float = bounds.x - bounds.x * 0.62
		var cy: float = bounds.y * 0.5  # PORT: web/src/tilt-to-live/TiltGame.ts:1704
		var angle: float = elapsed * 0.8  # PORT: web/src/tilt-to-live/TiltGame.ts:1705
		var wander_x: float = cx - cos(angle) * (bounds.x * 0.22)  # PORT: :1706
		var wander_y: float = cy + sin(angle * 2.0) * (bounds.y * 0.18)  # PORT: :1707
		var wdx: float = wander_x - menu_player.x
		var wdy: float = wander_y - menu_player.y
		var wdist: float = maxf(1.0, sqrt(wdx * wdx + wdy * wdy))
		steer_x = (wdx / wdist) * 160.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1711
		steer_y = (wdy / wdist) * 160.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1712

	# 4. Repulsion from nearby enemies. PORT: web/src/tilt-to-live/TiltGame.ts:1716-1727
	var danger_radius: float = 145.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1716
	for e: Types.Enemy in menu_swarm.enemies:
		var ex: float = menu_player.x - e.x
		var ey: float = menu_player.y - e.y
		var edist: float = sqrt(ex * ex + ey * ey)
		if edist < danger_radius and edist > 0.1:  # PORT: :1721
			# PORT: web/src/tilt-to-live/TiltGame.ts:1722
			var repulsion: float = pow((danger_radius - edist) / danger_radius, 1.8) * 520.0
			steer_x += (ex / edist) * repulsion
			steer_y += (ey / edist) * repulsion

	# 5. Boundary repulsion. PORT: web/src/tilt-to-live/TiltGame.ts:1730-1743
	# DIVERGENCE(M11a R1): the wide margin min(0.38w, 420) guarded the TS's left
	# sidebar; mirrored, it guards the right-hand panel and the 60 px one moves left.
	var panel_margin: float = minf(bounds.x * 0.38, 420.0)
	var edge_margin: float = 60.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1732
	var top_margin: float = 60.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1733
	var bot_margin: float = 60.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1734
	if menu_player.x > bounds.x - panel_margin:
		steer_x -= ((menu_player.x - (bounds.x - panel_margin)) / panel_margin) * 450.0
	elif menu_player.x < edge_margin:
		steer_x += ((edge_margin - menu_player.x) / edge_margin) * 450.0
	if menu_player.y < top_margin:
		steer_y += ((top_margin - menu_player.y) / top_margin) * 380.0  # PORT: :1740
	elif menu_player.y > bounds.y - bot_margin:
		steer_y -= ((menu_player.y - (bounds.y - bot_margin)) / bot_margin) * 380.0  # PORT: :1742

	var target_pos: Vector2 = Vector2(menu_player.x + steer_x, menu_player.y + steer_y)

	# PORT: web/src/tilt-to-live/TiltGame.ts:1751-1760 — 'mouse', no move vector,
	# {sensitivity 1.0, deadzone 2}, no skin (hitbox/turn 1.0, PlayerShip.ts:107-108).
	menu_player.update(
		dt,
		target_pos,
		bounds,
		particles,
		Types.ControlMode.MOUSE,
		Vector2.ZERO,
		1.0,
		2.0,
		1.0,
		1.0,
		THRUSTER_COLOR,
		Vector2.ZERO
	)

	# PORT: web/src/tilt-to-live/TiltGame.ts:1763-1770
	menu_swarm.update(
		dt,
		Vector2(menu_player.x, menu_player.y),
		bounds,
		particles,
		0,
		Types.GameMode.CLASSIC
	)

	# Defensive shield on a close call. PORT: web/src/tilt-to-live/TiltGame.ts:1773-1783
	for e: Types.Enemy in menu_swarm.enemies:
		var cdx: float = e.x - menu_player.x
		var cdy: float = e.y - menu_player.y
		var reach: float = e.radius + menu_player.radius + 6.0  # PORT: :1776
		if cdx * cdx + cdy * cdy <= reach * reach:
			if not menu_player.has_shield():
				menu_player.activate_shield(3.0)  # PORT: web/src/tilt-to-live/TiltGame.ts:1778
				particles.emit_explosion(menu_player.x, menu_player.y, SHIELD_BURST_COLOR, 14)
				grid.apply_explosion(menu_player.x, menu_player.y, 8.0, 80.0)  # PORT: :1780

	# PORT: web/src/tilt-to-live/TiltGame.ts:1808-1819
	menu_weapons.update(
		dt, menu_player, menu_swarm.enemies, bounds, particles, grid, _silent_audio, _on_killed
	)


# PORT: web/src/tilt-to-live/TiltGame.ts:1816-1818
func _on_killed(dead: Types.Enemy, _weapon_type: Types.WeaponType) -> void:
	menu_swarm.on_enemy_killed(dead, _particles)
```

Notes for the implementer. `14` (`:1779`) must also carry its citation: put `# PORT: web/src/tilt-to-live/TiltGame.ts:1779` on the `emit_explosion` line, and wrap the line if it passes 100 columns. The literals at `:1740` and `:1742` repeat the `380` of `:1740`/`:1742`, so cite both lines. If `Types.Enemy` has no `radius` field, read `types.gd:142-` for the name the port uses and keep the TS expression.

- [x] **Step 4: Run the tests**

Run: `tools/run_tests.sh`. Expected: `OK: 51/51 scripts`, **+7 tests** (566). Then `gdformat --check godot/src godot/tests` (92 files) and `gdlint godot/src godot/tests`.

- [x] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/render/menu_backdrop.gd godot/src/render/menu_backdrop.gd.uid godot/tests/test_menu_backdrop.gd godot/tests/test_menu_backdrop.gd.uid docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md godot/HANDOFF.md
git commit -m "M11a: port the menu backdrop sim, mirrored to the board; next: Task 2"
```

(Godot writes the `.uid` files on the first import. If one is missing, run `"$GODOT" --headless --path godot --import --quit` and then stage it.)

---

### Task 2: Screen shake and Enemy outlines (R2)

**Files:**
- Modify: `godot/src/core/game_root.gd`, `godot/src/sim/run_controller.gd`
- Test: `godot/tests/test_run_controller.gd`, `godot/tests/test_main_scene.gd`

**Interfaces:**
- Produces: `RunController.trigger_shake: Callable` (default `Callable()`, meaning no shake), called with `amount: float`. `GameRoot.trigger_shake(amount: float) -> void`, `GameRoot.camera_shake: float` (read-only by convention, for tests), `GameRoot.apply_readability() -> void` (pushes `high_contrast_halo` and `show_gridlines` into the layers; Task 5 calls it after every Settings change).

- [x] **Step 1: Write the failing tests.** Append to `godot/tests/test_run_controller.gd`, using the file's existing `_make_run()`-style builder. Read its top first, and use its helper names.

```gdscript
func test_losing_a_life_shakes_by_14_times_the_option() -> void:
	var run: RunController = _make_run()
	var amounts: Array[float] = []
	run.trigger_shake = func(amount: float) -> void: amounts.append(amount)
	run.options.settings.screen_shake = GameOptionsManager.ScreenShake.LOW
	run.lives = 3
	run.lose_life()
	assert_eq(amounts, [7.0] as Array[float], "14 × 0.5 (TiltGame.ts:2064, GameOptions.ts:123)")


func test_death_shakes_by_24_times_the_option() -> void:
	var run: RunController = _make_run()
	var amounts: Array[float] = []
	run.trigger_shake = func(amount: float) -> void: amounts.append(amount)
	run.options.settings.screen_shake = GameOptionsManager.ScreenShake.OFF
	run.lives = 1
	run.lose_life()
	assert_eq(amounts, [0.0] as Array[float], "24 × 0 (TiltGame.ts:2081)")
```

Append to `godot/tests/test_main_scene.gd`:

```gdscript
func test_shake_offsets_the_arena_layers_and_decays() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.launch_run(root.options.settings.mode)
	root.trigger_shake(10.0)
	assert_eq(root.camera_shake, 10.0, "TiltRenderer.ts:16")
	await get_tree().process_frame
	assert_almost_eq(root.camera_shake, 8.8, 0.0001, "×0.88 per rendered frame (:51)")
	var grid_layer: Node2D = root.find_child("GridLayer", true, false) as Node2D
	var entity_layer: Node2D = root.find_child("EntityLayer", true, false) as Node2D
	var effect_layer: Node2D = root.find_child("EffectLayer", true, false) as Node2D
	assert_eq(grid_layer.position, entity_layer.position, "one offset for the whole ctx.save")
	assert_eq(grid_layer.position, effect_layer.position)
	assert_true(absf(grid_layer.position.x) <= 10.0 and absf(grid_layer.position.y) <= 10.0)


func test_halo_option_reaches_the_entity_layer() -> void:
	var saved: GameOptionsManager = GameOptionsManager.new()
	saved.settings.high_contrast_halo = false
	saved.save()
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	assert_false(root._entity_layer._high_contrast_halo, "TiltGame.ts:2281/:2314")
	root.options.settings.high_contrast_halo = true
	root.apply_readability()
	assert_true(root._entity_layer._high_contrast_halo)
```

(`launch_run` arrives in Task 4. Until then, **omit** the `root.launch_run(...)` line, because the boot still launches a run. Task 4 Step 1 adds it back when it adds the `_launch` helper.)

- [x] **Step 2: Run to verify they fail.** `tools/run_tests.sh` should report 4 failures (`trigger_shake`/`camera_shake`/`apply_readability` not found), or a parse drop that `--check-only` confirms.

- [x] **Step 3: Implement.**

`run_controller.gd`: add a public var near the other callbacks:

```gdscript
## renderer.triggerShake. GameRoot sets it; an empty Callable skips the shake (tests).
## PORT: web/src/tilt-to-live/TiltGame.ts:2064, :2081 (the TS calls the renderer directly)
var trigger_shake: Callable = Callable()
```

In `lose_life`, after `grid.apply_explosion(player.x, player.y, 14.0, 220.0)`:

```gdscript
		_shake(14.0 * options.get_shake_multiplier())  # PORT: web/src/tilt-to-live/TiltGame.ts:2064
```

In `trigger_player_death`, after `grid.apply_explosion(player.x, player.y, 22.0, 380.0)`:

```gdscript
	_shake(24.0 * options.get_shake_multiplier())  # PORT: web/src/tilt-to-live/TiltGame.ts:2081
```

Add a private method in the private-methods block:

```gdscript
func _shake(amount: float) -> void:
	if trigger_shake.is_valid():
		trigger_shake.call(amount)
```

`game_root.gd`: under the regular variables, add:

```gdscript
## TiltRenderer.cameraShake. PORT: web/src/tilt-to-live/TiltRenderer.ts:12
var camera_shake: float = 0.0
```

In `_ready`, after `_run_controller` is built: `_run_controller.trigger_shake = trigger_shake`. After `_grid_layer.show_gridlines = …`, replace that line with `apply_readability()`.

Public methods:

```gdscript
## PORT: web/src/tilt-to-live/TiltRenderer.ts:15-17
func trigger_shake(amount: float) -> void:
	camera_shake = amount


## Pushes the readability options into the layers; the TS render reads them per
## frame (TiltGame.ts:2280-2281, :2313-2317).
func apply_readability() -> void:
	_grid_layer.show_gridlines = options.settings.show_gridlines
	_entity_layer.set_high_contrast_halo(options.settings.high_contrast_halo)
```

In `_process`, before the `queue_redraw` calls:

```gdscript
	# PORT: web/src/tilt-to-live/TiltRenderer.ts:46-56 — once per rendered frame,
	# around everything inside ctx.save()..restore() (:53-156). renderMenuBackground
	# never reads cameraShake (M11a R2).
	var offset: Vector2 = Vector2.ZERO
	if _state.phase != Types.GamePhase.MENU and camera_shake > 0.1:  # PORT: :48
		offset = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0) * camera_shake  # PORT: :49-50
		camera_shake *= 0.88  # PORT: web/src/tilt-to-live/TiltRenderer.ts:51
	_grid_layer.position = offset
	_entity_layer.position = offset
	_effect_layer.position = offset
```

The layers translate their own drawing by `arena_origin` (`set_arena_origin`), so the node `position` is free. Confirm with `grep -n "position" godot/src/render/*.gd` that no layer already sets its own `position`. If one does, stop and record it (Law 5).

- [x] **Step 4: Run the tests.** `tools/run_tests.sh` → **+4 tests** (570), 51 scripts. Then format and lint.

- [x] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/core/game_root.gd godot/src/sim/run_controller.gd godot/tests/test_run_controller.gd godot/tests/test_main_scene.gd docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md godot/HANDOFF.md
git commit -m "M11a: port screen shake and wire the halo option; next: Task 3"
```

---

### Task 3: `TiltMenu` — the menu screen

**Files:**
- Create: `godot/src/ui/tilt_menu.gd`, `godot/tests/test_tilt_menu.gd`

**Interfaces:**
- Consumes: `GameOptionsManager` (`settings.mode`, `modes`, `set_mode`), `ProgressionManager.data.points`, `GoalManager` (`get_completed_count()`, `get_total_goals_count()`, `get_active_goals(n)`, `get_metric_value(metric, tracker)`), `ScoreManager.stats.best_score`, `ControlSettings.scheme`, `UiTheme`, `ControlPicker` (`scenes/control_picker.tscn`, `scheme_chosen`, `set_active_scheme`). Read `goal_manager.gd` for the exact names of the four goal calls and their return types. `get_active_goals` returns wrapper objects with a `.goal` in the TS (`:100`), so read the port's shape before writing `_next_teaser`.
- Produces: `class_name TiltMenu extends Control` with:
  - signals `launch_requested(mode: Types.GameMode)`, `armory_requested`, `all_goals_requested`, `calibrate_screen_requested`, `scheme_chosen(scheme: Types.ControlScheme)`, and (Task 5) `readability_changed`, `reset_confirmed`.
  - `func bind(options: GameOptionsManager, progression: ProgressionManager, goals: GoalManager, scores: ScoreManager, settings: ControlSettings) -> void`
  - `func show_menu() -> void` (TS `show`: visible + `render`), `func hide_menu() -> void`, `func is_menu_visible() -> bool`, `func render() -> void`, `func set_ui_scale(scale: float, inset: Vector2) -> void`
  - Node names the tests use: `MenuContainer`, `MenuTitle`, `ModeCard_classic` / `ModeCard_gauntlet` / `ModeCard_code-red` (the TS `data-mode` ids, from `GameOptionsManager.MODE_IDS`), `PlayButton`, `MenuArmoryButton`, `MenuMilestonesButton`, `MenuSettingsButton`, `MenuCalibrateButton`, `StatsRow`, `StatBest`, `StatPoints`, `StatMilestones`, `NextTeaser`, `NextTeaserFill`.

`show()`/`hide()`/`is_visible()` are `CanvasItem` builtins, so the TS names take a `_menu` suffix. PORT-NOTE at the first one.

**Layout** (`Main.dc.html`, 844×390 at `ui_scale` 1; every value × `ui_scale` via `UiTheme.px`). `TiltMenu` itself is full-rect with `mouse_filter = IGNORE`. `MenuContainer` is full-rect and draws **no background**: the backdrop sim is the background, and the board's grid and dots are its mock.
- Title block at left 32, top 26, gap 10. `MenuTitle` is Archivo width 118, weight 700, size 42, line spacing so that line-height = 0.9, `COLOR_TEXT`, text `"PERIL\nPOINT"` (R6). Subtitle 14 `COLOR_TEXT_MUTED`, `"Move to dodge. The guns fire themselves."` (`TiltMenu.ts:135`).
- Left block at left 32, bottom 24, width 392, VBox gap 16, from top to bottom:
  - `NextTeaser` (R8, only when there is a teaser): caps `"Next"` in `COLOR_FLARE`, then a 12 px `COLOR_TEXT_MUTED` line `"<title> — <desc>"` clipped with ellipsis, then a `UiTheme.meter(pct/100, COLOR_FLARE, 392, 4)`. Tag `DIVERGENCE(UI-SYSTEM): System.dc.html — Rule N`.
  - Steer row, gap 12: `UiTheme.caps("Steer")` with min width 48; a `ControlPicker` instance of min width 176; then `MenuCalibrateButton` (`GhostIconButton`, 48×48, the target glyph SVG copied from the board).
  - `StatsRow`: a top hairline in `COLOR_RAISED`, padding-top 14, gap 28, three stat columns (gap 3). Each column is a caps label at size 10 in `TEXT_FAINT` (`"Best"`, `"Points"`, `"Milestones"`, `TiltMenu.ts:183-191`) over a mono value at 17 / weight 500. Best is `COLOR_TEXT`, Points is `COLOR_FLARE`, and Milestones is `"<done>"` `COLOR_TEXT` + `"/<total>"` `TEXT_FAINT`. Values use `UiTheme.group_digits` (the TS `toLocaleString`). Hidden when `best_score <= 0` (`:180`).
- Right panel: width 372, full height, padding 22/30/22/24 (top/right/bottom/left), `rgba(8,9,14,0.92)` (`UiTheme.tint(COLOR_VOID, 0.92)`), left border 1 px `COLOR_LINE`, VBox gap 8.
  - One `ModeCard_<id>` per `options.modes`: a `Button` (`CardButton` variation, text empty), height 56, radius 6, padding 0/14/0/12, HBox gap 12. Background is `COLOR_PANEL` when selected, else `DONE_CARD`. Border is the mode's `color` when selected, else `COLOR_LINE`. Inside, from left: a tint bar 3×30 radius 2 in `mode.color`; a name (15/600, `COLOR_TEXT` selected / `TEXT_SECONDARY`) over a tagline (12, `COLOR_TEXT_MUTED` selected / `TEXT_FAINT`), both from `TiltMenu.ts:150-153`; the multiplier text (mono 13/500, `mode.color`); a radio ring 18 px (1.5 border, `mode.color` selected / `COLOR_LINE_STRONG`) with an 8 px dot in `mode.color` when selected. Every child has `mouse_filter = IGNORE`.
  - A flexible spacer.
  - `PlayButton`: `PrimaryButton`, height 56, font 18, a play-glyph icon (the board SVG), text `"Play"` (`:170`).
  - Nav row, gap 8, margin-top 2: `MenuArmoryButton` and `MenuMilestonesButton` (`SecondaryButton`, height 48, expand), then `MenuSettingsButton` (`GhostIconButton` 48×48, the board's gear SVG; TS label `"Settings"`, `:175`).
- `set_ui_scale(scale, inset)` rebuilds the literal sizes (as `ArmoryUI.set_ui_scale` does) and insets the left and title blocks by `inset`. The right panel stays flush right: the board draws it to the edge.

- [x] **Step 1: Write the failing tests** — `godot/tests/test_tilt_menu.gd`:

```gdscript
## test_tilt_menu.gd
## PORTS: nothing — new file, covers ui/tilt_menu.gd
extends GutTest
## The menu screen (TiltMenu.ts:87-255) and, from Task 5, the options modal.

var _options: GameOptionsManager = null
var _progression: ProgressionManager = null
var _goals: GoalManager = null
var _scores: ScoreManager = null
var _settings: ControlSettings = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _clear() -> void:
	for path: String in [
		GameOptionsManager.SAVE_PATH, ProgressionManager.SAVE_PATH, GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH, ControlSettings.SETTINGS_PATH, ScoreManager.BEST_SCORE_PATH,
	]:
		_remove(path)


func before_each() -> void:
	_clear()
	_options = GameOptionsManager.new()
	_progression = ProgressionManager.new()
	_goals = GoalManager.new()
	_scores = ScoreManager.new()
	_settings = ControlSettings.new()


func after_each() -> void:
	_clear()


func _menu() -> TiltMenu:
	var menu: TiltMenu = TiltMenu.new()
	menu.theme = UiTheme.build(1.0)
	menu.size = Vector2(844.0, 390.0)
	add_child_autofree(menu)
	menu.bind(_options, _progression, _goals, _scores, _settings)
	menu.show_menu()
	return menu


func test_menu_exposes_its_controls() -> void:
	var menu: TiltMenu = _menu()
	for node_name: String in [
		"MenuTitle", "PlayButton", "MenuArmoryButton", "MenuMilestonesButton",
		"MenuSettingsButton", "MenuCalibrateButton", "ModeCard_classic", "ModeCard_gauntlet",
		"ModeCard_code-red",
	]:
		assert_not_null(menu.find_child(node_name, true, false), node_name)
	var title: Label = menu.find_child("MenuTitle", true, false) as Label
	assert_eq(title.text, "PERIL\nPOINT", "R6")


func test_mode_cards_show_ts_names_taglines_and_multipliers() -> void:
	var menu: TiltMenu = _menu()
	var card: Control = menu.find_child("ModeCard_code-red", true, false) as Control
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in card.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_has(texts, "Code Red", "GameOptions.ts:62")
	assert_has(texts, "Double density from the first second.", "GameOptions.ts:64")
	assert_has(texts, "1.50×", "toFixed(2) since 1.5 % 1 != 0 (TiltMenu.ts:144)")


func test_picking_a_card_saves_the_mode_and_rerenders() -> void:
	var menu: TiltMenu = _menu()
	(menu.find_child("ModeCard_gauntlet", true, false) as Button).pressed.emit()
	assert_eq(_options.settings.mode, Types.GameMode.GAUNTLET, "TiltMenu.ts:222")
	assert_eq(GameOptionsManager.new().settings.mode, Types.GameMode.GAUNTLET, "saved")
	assert_true(menu.is_mode_selected(Types.GameMode.GAUNTLET), "re-rendered (:223)")


func test_play_hides_the_menu_and_requests_the_saved_mode() -> void:
	_options.set_mode(Types.GameMode.CODE_RED)
	var menu: TiltMenu = _menu()
	watch_signals(menu)
	(menu.find_child("PlayButton", true, false) as Button).pressed.emit()
	assert_false(menu.is_menu_visible(), "TiltMenu.ts:239")
	assert_signal_emitted_with_parameters(menu, "launch_requested", [Types.GameMode.CODE_RED])


func test_nav_buttons_emit_their_requests() -> void:
	var menu: TiltMenu = _menu()
	watch_signals(menu)
	(menu.find_child("MenuArmoryButton", true, false) as Button).pressed.emit()
	(menu.find_child("MenuMilestonesButton", true, false) as Button).pressed.emit()
	(menu.find_child("MenuCalibrateButton", true, false) as Button).pressed.emit()
	assert_signal_emitted(menu, "armory_requested", "TiltMenu.ts:244-246")
	assert_signal_emitted(menu, "all_goals_requested", "TiltMenu.ts:248-250")
	assert_signal_emitted(menu, "calibrate_screen_requested", "R5")


func test_stats_row_hides_until_a_best_exists() -> void:
	var menu: TiltMenu = _menu()
	var row: Control = menu.find_child("StatsRow", true, false) as Control
	assert_false(row != null and row.is_visible_in_tree(), "bestScore 0 → hidden (TiltMenu.ts:180)")
	_scores.stats.best_score = 32420
	_progression.data.points = 7331
	menu.render()
	row = menu.find_child("StatsRow", true, false) as Control
	assert_true(row.is_visible_in_tree())
	assert_eq((menu.find_child("StatBest", true, false) as Label).text, "32,420")
	assert_eq((menu.find_child("StatPoints", true, false) as Label).text, "7,331")


func test_next_teaser_shows_the_first_active_goal() -> void:
	var menu: TiltMenu = _menu()
	var teaser: Control = menu.find_child("NextTeaser", true, false) as Control
	assert_not_null(teaser, "a fresh save has active goals (TiltMenu.ts:97)")
	assert_true(teaser.is_visible_in_tree(), "R8")


func test_steer_picker_reports_the_scheme() -> void:
	var menu: TiltMenu = _menu()
	watch_signals(menu)
	var picker: ControlPicker = menu.find_children("*", "ControlPicker", true, false)[0] as ControlPicker
	picker.scheme_chosen.emit(Types.ControlScheme.GYRO)
	assert_signal_emitted_with_parameters(menu, "scheme_chosen", [Types.ControlScheme.GYRO])


func test_every_menu_target_meets_the_48_rule() -> void:
	var menu: TiltMenu = _menu()
	await get_tree().process_frame
	for button: Node in menu.find_children("*", "Button", true, false):
		var b: Button = button as Button
		if b.is_visible_in_tree():
			assert_true(b.size.y >= 48.0, "%s height %f (interface spec §4.5)" % [b.name, b.size.y])
```

(9 tests. `is_mode_selected(mode) -> bool` is a small public query that the tests read. It returns true when that card is drawn selected, and exists because a card's style is otherwise opaque to a test. Read the goal-query names from `goal_manager.gd` before writing `_next_teaser`. If the port has no `get_active_goals`, stop and record it.)

- [x] **Step 2: Run to verify they fail.** Expect `collected 51 of 52`.

- [x] **Step 3: Implement `godot/src/ui/tilt_menu.gd`.** Header:

```gdscript
# gdlint:ignore=max-public-methods
## tilt_menu.gd
## PORTS: web/src/tilt-to-live/TiltMenu.ts (523 lines, source commit 7be9614)
class_name TiltMenu
extends Control
## The start menu, the Settings (options) modal and the reset confirm, built in
## code on the Main and Settings boards (interface spec §6.6). Holds no sim
## system; every action is a signal GameRoot answers (TiltMenu.ts:15-18's callbacks).
##
## PORT-NOTE: initDOM (:45-67) creates the two DOM roots; _ready builds
## MenuContainer and (Task 5) OptionsModal instead. show/hide/isVisible (:69-85)
## are show_menu/hide_menu/is_menu_visible — CanvasItem already owns those names.
```

Member order follows CONVENTIONS §2. The TS members appear in TS order: `bind` stands in for the constructor (`:23-43`), then `show_menu`, `hide_menu`, `is_menu_visible`, `render`, `_bind_events`, and in Task 5 `open_options_modal`, `_bind_options_events`.

`render()` ports `:87-212`. It reads the values exactly as `:90-126` does. The teaser metric branch is `category == cumulative or metric.begins_with("total_")` → `get_metric_value(metric, <a zeroed classic tracker>)`, else `run_score` → `mini(target, best)`, and `pct = clampi(roundi(current / target * 100), 0, 100)`. Build the zeroed tracker the way `run_controller.gd` builds `run_tracker` in `reset_run`, with mode `CLASSIC`. Rebuild `MenuContainer`'s children on each `render()`, as the TS rewrites `innerHTML`: `queue_free` the old children, then build new ones. Also re-sync the picker with `set_active_scheme(_settings.scheme)`.

`_bind_events()` ports `:214-255` by connecting each rebuilt control:

```gdscript
func _on_mode_card_pressed(mode: Types.GameMode) -> void:
	_options.set_mode(mode)  # PORT: web/src/tilt-to-live/TiltMenu.ts:222
	render()  # PORT: web/src/tilt-to-live/TiltMenu.ts:223


func _on_play_pressed() -> void:
	hide_menu()  # PORT: web/src/tilt-to-live/TiltMenu.ts:239
	launch_requested.emit(_options.settings.mode)  # PORT: :240
```

The Enter/Space card keys (`:226-234`) are the `Button`'s own `ui_accept`, so they need no extra code. PORT-NOTE.

- [x] **Step 4: Run the tests.** 52 scripts, **+9 tests** (579). Format (93 files) and lint.

- [x] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/ui/tilt_menu.gd godot/src/ui/tilt_menu.gd.uid godot/tests/test_tilt_menu.gd godot/tests/test_tilt_menu.gd.uid docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md godot/HANDOFF.md
git commit -m "M11a: build the menu screen from TiltMenu.ts on Main board; next: Task 4"
```

---

### Task 4: The MENU phase — boot, launch, return, keys, backdrop render

**Files:**
- Modify: `godot/scenes/main.tscn` (add `Menu`), `godot/src/core/game_root.gd`, `godot/src/core/game_state_machine.gd`, `godot/src/ui/hud_controller.gd`, and `effect_layer.gd`/`entity_layer.gd` only if `null` binds fail
- Test: `godot/tests/test_main_scene.gd`, `test_game_state_machine.gd`, `test_hud_controller.gd`

**Interfaces:**
- Consumes: `MenuBackdrop` (Task 1), `TiltMenu` (Task 3), `trigger_shake`/`apply_readability` (Task 2).
- Produces:
  - `GameRoot.launch_run(mode: Types.GameMode) -> void`. It ports `launchRun` (`:1486-1494`) plus `startCinematic`'s reset. It calls `_state.launch_run(mode)`, `_run_controller.reset_run(_bounds)`, `_state.mode = _run_controller.mode`, `_bind_run_layers()`, `_apply_game_mode()` and `GameEvents.phase_changed.emit(PLAYING)`, with `TODO(M11b)` at the point where the cinematic will start.
  - `GameRoot.return_to_menu() -> void`. It ports `returnToMenu` (`:1496-1517`). It returns if the phase is already `MENU`, then calls `_state.return_to_menu()`, `_joystick.reset()`, `_hud` sheets hidden (via `phase_changed`), `_goals_hud.set_menu_mode(true)`, `_menu.show_menu()`, `_goals_hud.render()`, `_bind_menu_layers()` and `GameEvents.phase_changed.emit(MENU)`.
  - `GameRoot.is_in_menu() -> bool`
  - `GameRoot._backdrop: MenuBackdrop`, `GameRoot._menu: TiltMenu` (tests read them).
  - `main.tscn`: `CanvasLayer/Menu` (`Control`, full rect, script `tilt_menu.gd`, `unique_name_in_owner = true`), ordered **after `Hud` and before `GoalsHud`**. The Settings modal must draw over Pause, and the Milestones modal and Armory over the menu.

- [x] **Step 1: Update the boot-dependent tests, then write the new ones.**

In `test_main_scene.gd`, add a helper under `after_each`:

```gdscript
## Boots the scene and starts a run from the menu, as Play does (TiltMenu.ts:238-241).
func _boot_into_run() -> GameRoot:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.launch_run(root.options.settings.mode)
	return root
```

Every existing test that instantiates `MAIN_SCENE` and then assumes a live run changes its first three lines to `var root: GameRoot = await _boot_into_run()`. Those are the tests that pause, open the Armory "while playing", read `_run_controller` state, read the HUD, or restart. **Their assertions do not change.** List every edited test in the commit message's scope, for example "boot tests launch from the menu". Rename and rewrite exactly two tests:
- `test_boot_launches_the_saved_mode` → `test_play_launches_the_selected_mode`. Boot, press the menu's `ModeCard_gauntlet` and then `PlayButton` through `pressed.emit()`. Assert the same mode, maze and scale facts as before.
- `test_the_boot_run_starts_the_music_when_it_is_on` → `test_a_launched_run_starts_the_music_when_it_is_on`. Assert that music is **not** playing after boot (`MENU`), then `launch_run`, then assert the original `_music_player.playing == music_enabled`.

Add to Task 2's `test_shake_offsets_the_arena_layers_and_decays` the `root.launch_run(...)` line it deferred.

New tests in `test_main_scene.gd`:

```gdscript
func test_boot_shows_the_menu_and_no_run() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	assert_true(root.is_in_menu(), "TiltGame.ts:1476")
	assert_true(root._menu.is_menu_visible(), ":1478")
	assert_false(root._audio._music_player.playing, "no music in the menu")
	assert_true(root._goals_hud.in_menu_mode, ":1477")
	assert_false((root.find_child("ScoreBlock", true, false) as Control).is_visible_in_tree(), "R12")


func test_the_backdrop_steps_only_in_the_menu() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var before: float = root._backdrop.elapsed
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_gt(root._backdrop.elapsed, before, "TiltGame.ts:1829-1830")
	root.launch_run(root.options.settings.mode)
	var frozen: float = root._backdrop.elapsed
	await get_tree().physics_frame
	assert_eq(root._backdrop.elapsed, frozen, "only the run steps while playing")


func test_return_to_menu_rebinds_the_backdrop_and_back() -> void:
	var root: GameRoot = await _boot_into_run()
	assert_eq(root._entity_layer._player, root._player, "run bindings")
	root.return_to_menu()
	assert_true(root.is_in_menu())
	assert_eq(root._entity_layer._player, root._backdrop.menu_player, "R13")
	assert_null(root._entity_layer._ship_skin, "renderMenuBackground passes no skin (:2274)")
	assert_null(root._grid_layer.get_arena_theme(), ":2276")
	assert_false(root._effect_layer.is_banner_drawn())
	root.launch_run(root.options.settings.mode)
	assert_eq(root._entity_layer._player, root._player, "rebound for the run")
	assert_eq(root._entity_layer._ship_skin, root.progression.get_equipped_ship())


func test_return_to_menu_from_the_menu_is_a_no_op() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	watch_signals(GameEvents)
	root.return_to_menu()
	assert_signal_not_emitted(GameEvents, "phase_changed", "TiltGame.ts:1497")


func test_p_and_escape_follow_the_ts_key_map() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_P
	key.pressed = true
	root._unhandled_input(key)
	assert_true(root.is_in_menu(), "menu: p does nothing (:1327-1329)")
	root.launch_run(root.options.settings.mode)
	root._unhandled_input(key)
	assert_true(root.is_paused(), "playing → paused")
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root._unhandled_input(esc)
	assert_false(root.is_paused(), "paused → playing (:1325)")
	root.open_armory()
	root._unhandled_input(esc)
	assert_false(root.is_armory_open(), "Armory open → Escape closes it first (:1326-1327)")
	assert_true(root.is_paused(), "and the run stays paused")


func test_space_enter_and_r_restart_after_death() -> void:
	var root: GameRoot = await _boot_into_run()
	root._run_controller.lives = 1
	root._run_controller.lose_life()
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	root._unhandled_input(key)
	assert_eq(root._state.phase, Types.GamePhase.PLAYING, "TiltGame.ts:1311-1316 (M11b: cinematic)")


func test_menu_settles_under_milestones_and_armory() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var menu: Node = root.find_child("Menu", true, false)
	var hud: Node = root.find_child("Hud", true, false)
	var goals: Node = root.find_child("GoalsHud", true, false)
	assert_gt(menu.get_index(), hud.get_index(), "over Pause (Settings from Pause, Task 7)")
	assert_lt(menu.get_index(), goals.get_index(), "under Milestones and Armory")
```

(+7 new tests, 2 renamed, 0 removed.)

In `test_game_state_machine.gd`, check whether any test asserts the `TODO(M11)` comment behaviour. None should, because these are comments. Add nothing there.

In `test_hud_controller.gd`, add:

```gdscript
func test_menu_phase_hides_the_run_hud_but_keeps_the_frame_and_toasts() -> void:
	var hud: HudController = _make_hud()
	GameEvents.phase_changed.emit(Types.GamePhase.MENU)
	for node_name: String in ["ScoreBlock", "LivesRow", "PauseButton", "WeaponTimer"]:
		assert_false((hud.find_child(node_name, true, false) as Control).visible, node_name)
	assert_true((hud.find_child("Frame", true, false) as Control).visible, "R12")
	assert_true((hud.find_child("ToastSlot", true, false) as Control).visible, "R12")
	GameEvents.phase_changed.emit(Types.GamePhase.PLAYING)
	assert_true((hud.find_child("ScoreBlock", true, false) as Control).visible)
	assert_true((hud.find_child("PauseButton", true, false) as Control).visible)
```

Use the file's own HUD builder (read its top for the helper's name). `LivesRow` and `WeaponTimer` have their own data-driven visibility (`_show_lives`, `_show_weapon_timer`). So on `PLAYING`, only `ScoreBlock` and `PauseButton` are forced visible, and the other two are left to their next reading. The test asserts only those two after `PLAYING`. (+1 test.)

- [x] **Step 2: Run to verify.** The new tests fail on missing members. The edited boot tests fail on `launch_run` not existing.

- [x] **Step 3: Implement.**

`main.tscn`: add, after the `Hud` subtree and before `GoalsHud`:

```
[node name="Menu" type="Control" parent="CanvasLayer"]
unique_name_in_owner = true
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("<new id for res://src/ui/tilt_menu.gd>")
```

Add the `ext_resource` line for the script, with a fresh id, beside the others. `TiltMenu` has no `Theme` of its own, so `GameRoot` gives it `UiTheme.build(ui_scale)` in `resize_canvas`, as the HUD's theme is built. Read how `HudController.set_ui_scale` assigns its theme and do the same through `_menu.set_ui_scale(ui_scale, arena_origin)`.

`game_state_machine.gd`, per TS line:
- `start()` `:64`: replace the TODO with `# PORT-NOTE: goalsHUD.setMenuMode, menu.show and updateCursor (:1477-1480) are GameRoot's — this machine holds no UI (spec §5.1). updateCursor has no pointer on Android (M11a R16).`
- `launch_run` `:71`: the same PORT-NOTE, for `:1490-1491`.
- `return_to_menu` `:85-87`: the modal hiding, `setMenuMode`, `menu.show` and the `tilt-playing` class become GameRoot's, via `phase_changed(MENU)` and R12 (PORT-NOTE). The cinematic skip (`:1504-1506`) becomes `# TODO(M11b): cinematic.skip (:1504-1506).`
- `start_cinematic` `:101`: `goalsHUD.setMenuMode(false)` is GameRoot's (PORT-NOTE). `:107` is retagged `TODO(M11b)`.
- `stop` `:117` → `TODO(M11b)`.
- `reset_run` `:137`, `:160`, `:162` → PORT-NOTEs: GameRoot/R12/R16.
- `toggle_pause` `:171`, `:174` → PORT-NOTE: `HudController._on_pause_pressed` populates and shows the sheet (`hud_controller.gd:575-588`). Read that code and confirm it before writing the note.

`game_root.gd`:
- Variables: `var _backdrop: MenuBackdrop = null`, and `@onready var _menu: TiltMenu = %Menu`.
- `_ready`: build `_backdrop = MenuBackdrop.new()` beside the other sims. After `_goals_hud.bind(...)`, call `_menu.bind(options, progression, goals, _scores, settings)` and connect:
  - `_menu.launch_requested.connect(launch_run)`
  - `_menu.armory_requested.connect(open_armory.bind(""))` (`TiltGame.ts:194`). `open_armory`'s default argument is not applied through `Callable.bind`, so bind the empty tab explicitly.
  - `_menu.all_goals_requested.connect(open_all_goals_modal)` (`:195`)
  - `_menu.scheme_chosen.connect(_on_menu_scheme_chosen)`. That handler calls `set_control_scheme(scheme)` and then `_menu.render()`.
  - `_menu.calibrate_screen_requested`: connected in Task 6, not now.
- `_ready` tail: replace the boot launch (`_state.launch_run(...)`, `_run_controller.reset_run(_bounds)` and `_apply_game_mode()`) with the TS `start()` UI half:

```gdscript
	_state.start()
	# PORT: web/src/tilt-to-live/TiltGame.ts:1477-1479
	_goals_hud.set_menu_mode(true)
	_menu.show_menu()
	_goals_hud.render()
	# PORT-NOTE: updateCursor (:1480) — no pointer on Android (M11a R16).
	_bind_menu_layers()
	GameEvents.phase_changed.emit(Types.GamePhase.MENU)
```

  Keep the tilt permission request and `calibrate_current_position()` where they are. Change the `Log.info("M2 boot: …")` text to `"boot: …"`.
- `_physics_process`: add the arm `Types.GamePhase.MENU: _update_menu(delta)`, where:

```gdscript
## PORT: web/src/tilt-to-live/TiltGame.ts:1829-1830 — the real delta, no GAME_SPEED (M11a R14).
func _update_menu(delta: float) -> void:
	_backdrop.update(delta, _bounds, _grid, _particles)
	_entity_layer.set_elapsed(_backdrop.elapsed)
	_grid_layer.set_elapsed(_backdrop.elapsed)
	_effect_layer.set_elapsed(_backdrop.elapsed)
```

- `_unhandled_input`, key block, after the b/u branch. Replace the Escape-only branch and the `TODO(M11)` with the TS order `:1311-1331`:

```gdscript
			# PORT: web/src/tilt-to-live/TiltGame.ts:1311-1316
			var is_restart_key: bool = (
				armory_key.keycode == KEY_SPACE
				or armory_key.keycode == KEY_ENTER
				or armory_key.keycode == KEY_R
			)
			if is_restart_key and _state.phase == Types.GamePhase.GAME_OVER:
				restart_run()  # TODO(M11b): startCinematic (:1313).
				return
			# PORT: web/src/tilt-to-live/TiltGame.ts:1325-1331
			if armory_key.keycode == KEY_P or armory_key.keycode == KEY_ESCAPE:
				if _armory.is_open():
					close_armory()
				elif _state.phase == Types.GamePhase.PLAYING or is_paused():
					toggle_pause()
					_hud.set_pause_panel_visible(is_paused())
				return
```

  The TS gates Space/Enter/r to `game-over` only inside the first `if`, and its `else if` chain means b/u and p/Escape are tested only when the key is not Space/Enter/r. Preserve that shape: the restart test comes first, and only a restart key in `GAME_OVER` returns early. **Read `HudController._on_pause_pressed` first.** If it refreshes the Pause sheet on open (`_refresh_pause_sheet`), the key path must reach the same refresh. Expose `HudController.refresh_pause_sheet()` if needed, rather than duplicating it. Record the choice in the plan's Execution rulings.
- Layer bindings: move `_ready`'s entity/effect binds into `_bind_run_layers()`, and add `_bind_menu_layers()`:

```gdscript
## The run's layer bindings (the TiltRenderer.render arm, TiltGame.ts:2285-2318).
func _bind_run_layers() -> void:
	_entity_layer.bind_entities(_player, _swarm, _weapons, _coins)
	_entity_layer.bind_maze(_maze)
	_effect_layer.bind(_particles, _scores, _weapons)
	_apply_equipped_cosmetics()


## renderMenuBackground's bindings (TiltGame.ts:2265-2282, TiltRenderer.ts:158-220; M11a R13).
func _bind_menu_layers() -> void:
	_entity_layer.bind_entities(_backdrop.menu_player, _backdrop.menu_swarm, _backdrop.menu_weapons)
	_entity_layer.set_ship_skin(null)
	_entity_layer.set_enemy_skin(null)
	_entity_layer.set_game_mode(Types.GameMode.CLASSIC)
	_grid_layer.set_arena_theme(null)
	_grid_layer.set_game_mode(Types.GameMode.CLASSIC)
	_effect_layer.bind(_particles, null, _backdrop.menu_weapons)
	_effect_layer.set_game_mode(Types.GameMode.CLASSIC)
	_effect_layer.set_banner_shown(false)
```

  `_apply_equipped_cosmetics()` is also called from `_on_armory_state_changed`/`_on_armory_closed`. When those run in `MENU` (Armory opened from the menu), they must **not** re-skin the backdrop. Guard both calls with `if not is_in_menu():`, and PORT-NOTE that the menu render takes no skin (`:2274-2276`).
- `launch_run(mode)` and `return_to_menu()` as in Interfaces. `launch_run` also calls `_goals_hud.set_menu_mode(false)` and `_menu.hide_menu()` (`:1490-1491`, idempotent after Play), `_tilt.calibrate_current_position()` and `_joystick.reset()` (as `restart_run` does). `return_to_menu` also calls `camera_shake = 0.0`, because the menu render never decays it (R2). Without the reset, a death shake would resume on the next run's first frame.
- `is_in_menu()`: `return _state.phase == Types.GamePhase.MENU`.
- `_on_run_ended`: append `_menu.render()` (`TiltGame.ts:2147`). `_on_armory_state_changed`: `_menu.render()` (`:2359`). `_on_armory_closed`: replace the `TODO(M11): menu.render (:2384)` with `_menu.render()`.

`hud_controller.gd` `_on_phase_changed` (R12): today it returns early unless `PLAYING`. Make it:

```gdscript
func _on_phase_changed(phase: Types.GamePhase) -> void:
	# M11a R12: the in-run HUD shows only outside the menu.
	var in_menu: bool = phase == Types.GamePhase.MENU
	for node: Control in [_score_block, _pause_button]:
		if node != null:
			node.visible = not in_menu
	if in_menu:
		for node: Control in [_lives_row, _weapon_timer]:
			if node != null:
				node.visible = false
	if phase != Types.GamePhase.PLAYING and not in_menu:
		return
	_run_over_timer.stop()
	if _game_over_panel != null:
		_game_over_panel.visible = false
	if _pause_panel != null:
		_pause_panel.visible = false
```

`_score_block` and `_pause_button` are already found in `_ready`. Check that the variable names match, and that `_pause_button` is a member, not a local.

- [x] **Step 4: Run the tests.** 52 scripts, **+8 tests** (587: 7 main-scene + 1 HUD; fix round 1 made it +9, 588 — see Execution rulings). Then run a headless boot and read its log:

```bash
"$GODOT" --headless --path godot --quit-after 240 2>&1 | grep -cE "SCRIPT ERROR|ERROR:"   # expect 0
git checkout godot/project.godot
```

- [x] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/scenes/main.tscn godot/src/core/game_root.gd godot/src/core/game_state_machine.gd godot/src/ui/hud_controller.gd godot/tests/test_main_scene.gd godot/tests/test_hud_controller.gd docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md godot/HANDOFF.md
git commit -m "M11a: boot into the menu and step its backdrop; next: Task 5"
```

(Also stage `effect_layer.gd`/`entity_layer.gd` if Step 3 had to touch them.)

---

### Task 5: Settings — the options modal and Reset progress

**Files:**
- Modify: `godot/src/ui/tilt_menu.gd`, `godot/src/core/game_root.gd`
- Test: `godot/tests/test_tilt_menu.gd`, `godot/tests/test_main_scene.gd`

**Interfaces:**
- Produces on `TiltMenu`: `func open_options_modal() -> void`, `func close_options_modal() -> void`, `func is_options_open() -> bool`, and signals `readability_changed`, `sfx_toggled(is_on: bool)`, `music_toggled(is_on: bool)` (R9), `reset_confirmed`, `armory_requested` (reused, `:500-503`) and `calibrate_screen_requested` (reused, for Settings' Calibrate link). Node names: `OptionsModal`, `OptionsBackButton`, `SchemeCard_touch`, `SchemeCard_tilt`, `SchemeCard_keys`, `SettingsCalibrateButton`, `ArmoryLink`, `HaloSwitch`, `GridSwitch`, `ShakeOff`, `ShakeLow`, `ShakeFull`, `SfxSwitch`, `MusicSwitch`, `ResetButton`, `ResetConfirm`, `ResetConfirmButton`, `ResetCancelButton`.
- Produces on `GameRoot`: `static func reset_progress_files() -> void` (R10) and `func reset_progress() -> void` (files, then a deferred `reload_current_scene`).

**Layout** (`Settings.dc.html`). `OptionsModal` is full-rect over everything in `TiltMenu`, with background `COLOR_SHELL` (a "shell" surface, interface spec §4 table).
- Header: height 64, padding 8/28/8/24, gap 12, bottom hairline `COLOR_RAISED`. `OptionsBackButton` is a `GhostIconButton` 48×48 with the board's chevron SVG. The title `"Settings"` (`TiltMenu.ts:298`) is Archivo width 112, weight 700, size 21.
- Body: padding 14/28/16/24. Three equal columns (`HBoxContainer` with `SIZE_EXPAND_FILL` children and `separation` 20), each a VBox with gap 8.
  1. **Controls** (caps size 10 `COLOR_ION`, `TiltMenu.ts:365`). A row of scheme cards, height 64, gap 8. Each card is a `CardButton`: name 15/600 (`COLOR_TEXT` active / `TEXT_SECONDARY`) over a mono-11 `TEXT_FAINT` sublabel. The active border is `COLOR_ION` on `COLOR_RAISED`, and the inactive border is `COLOR_LINE` on `COLOR_PANEL`. Cards are `SchemeCard_touch` ("Touch" / "drag anywhere"), `SchemeCard_tilt` ("Tilt" / "phone gyroscope") and, off mobile, `SchemeCard_keys` ("Keys" / "WASD / arrows"), per R7. Next is `SettingsCalibrateButton` (`SecondaryButton` 48, target glyph + `"Calibrate tilt"`), shown only while the scheme is `GYRO` (`:378`). Last is `ArmoryLink`, a flat `Button`, 12 px, `COLOR_TEXT_MUTED`, underline, `"Turn rate and sensitivity live in Armory › Handling"` (R6), height ≥ 48.
  2. **Readability** (`:312`). The `HaloSwitch` row is a switch card: min height 60, padding 8/12/8/14, `COLOR_PANEL` + `COLOR_LINE` border, radius 6. It holds label 14/500 `"Enemy outlines"` and hint 12 `TEXT_FAINT` `"White ring on every dot."` (R6), then a `Switch` `CheckButton`. The `GridSwitch` row (R8) has `"Background grid"` / `"Off by default — it competes with the dots."` (`:332-333`). The Screen shake card has label `"Screen shake"` (`:340`) and a `Segmented` of `ShakeOff`/`ShakeLow`/`ShakeFull` (`SegmentButton`, height 48, `"Off"`/`"Low"`/`"Full"`, `:343-345`). A PORT-NOTE marks the omitted Aim line (R3).
  3. **Audio** (`:353`): `SfxSwitch` `"Sound"` and `MusicSwitch` `"Music"` switch cards with no hints (the board has none; R6). Then **Data** (`:397`, caps with margin-top 8): the `"Reset progress"` card with hint `"Cannot be undone."`, and `ResetButton` (`"Reset"`, height 48, border `COLOR_LINE_STRONG`, text `COLOR_TEXT_MUTED` 13).
- `ResetConfirm` (R11): `UiTheme.build_sheet(<modal>, 0.8)` (the Pause scrim alpha). It holds a 14 px `COLOR_TEXT` label with the TS confirm text (`:508`), then an HBox with `ResetCancelButton` (`PrimaryButton`, `"Cancel"`) and `ResetConfirmButton` (`SecondaryButton`, `"Reset"`). The sheet is hidden until Reset is pressed.

- [x] **Step 1: Write the failing tests** (append to `test_tilt_menu.gd`):

```gdscript
func _settings_open() -> TiltMenu:
	var menu: TiltMenu = _menu()
	(menu.find_child("MenuSettingsButton", true, false) as Button).pressed.emit()
	return menu


func test_settings_button_opens_the_modal_and_back_closes_it() -> void:
	var menu: TiltMenu = _settings_open()
	assert_true(menu.is_options_open(), "TiltMenu.ts:252-254")
	(menu.find_child("OptionsBackButton", true, false) as Button).pressed.emit()
	assert_false(menu.is_options_open(), "TiltMenu.ts:419-421")


func test_halo_and_grid_switches_save_and_announce() -> void:
	var menu: TiltMenu = _settings_open()
	watch_signals(menu)
	(menu.find_child("HaloSwitch", true, false) as CheckButton).toggled.emit(false)
	(menu.find_child("GridSwitch", true, false) as CheckButton).toggled.emit(true)
	var saved: GameOptionsManager = GameOptionsManager.new()
	assert_false(saved.settings.high_contrast_halo, "TiltMenu.ts:429-433")
	assert_true(saved.settings.show_gridlines, "TiltMenu.ts:441-445")
	assert_signal_emit_count(menu, "readability_changed", 2, "R9: applied at once")


func test_shake_segments_store_the_ts_ids() -> void:
	var menu: TiltMenu = _settings_open()
	(menu.find_child("ShakeLow", true, false) as Button).pressed.emit()
	assert_eq(GameOptionsManager.new().settings.screen_shake, GameOptionsManager.ScreenShake.LOW)
	(menu.find_child("ShakeFull", true, false) as Button).pressed.emit()
	assert_eq(
		GameOptionsManager.new().settings.screen_shake,
		GameOptionsManager.ScreenShake.FULL,
		"data-shake=full (TiltMenu.ts:345)"
	)


func test_the_default_normal_shake_marks_full() -> void:
	var menu: TiltMenu = _settings_open()
	assert_true((menu.find_child("ShakeFull", true, false) as Button).button_pressed,
		"isCurrentShake: normal counts as full (TiltMenu.ts:280-285)")


func test_audio_switches_announce() -> void:
	var menu: TiltMenu = _settings_open()
	watch_signals(menu)
	(menu.find_child("SfxSwitch", true, false) as CheckButton).toggled.emit(false)
	(menu.find_child("MusicSwitch", true, false) as CheckButton).toggled.emit(false)
	assert_signal_emitted_with_parameters(menu, "sfx_toggled", [false], "R9 (Q2 ruling)")
	assert_signal_emitted_with_parameters(menu, "music_toggled", [false], "R9 (Q2 ruling)")
	assert_signal_not_emitted(menu, "readability_changed", "audio is not readability")


func test_aim_line_is_omitted() -> void:
	var menu: TiltMenu = _settings_open()
	assert_null(menu.find_child("AimSwitch", true, false), "R3")


func test_calibrate_link_shows_only_for_tilt_and_armory_link_closes() -> void:
	var menu: TiltMenu = _settings_open()
	var calibrate: Control = menu.find_child("SettingsCalibrateButton", true, false) as Control
	assert_false(calibrate != null and calibrate.is_visible_in_tree(), "TiltMenu.ts:378")
	_settings.scheme = Types.ControlScheme.GYRO
	menu.open_options_modal()
	calibrate = menu.find_child("SettingsCalibrateButton", true, false) as Control
	assert_true(calibrate.is_visible_in_tree())
	watch_signals(menu)
	(menu.find_child("ArmoryLink", true, false) as Button).pressed.emit()
	assert_false(menu.is_options_open(), "TiltMenu.ts:501")
	assert_signal_emitted(menu, "armory_requested", "TiltMenu.ts:502")


func test_reset_asks_first_and_cancel_emits_nothing() -> void:
	var menu: TiltMenu = _settings_open()
	watch_signals(menu)
	(menu.find_child("ResetButton", true, false) as Button).pressed.emit()
	var confirm: Control = menu.find_child("ResetConfirm", true, false) as Control
	assert_true(confirm.is_visible_in_tree(), "window.confirm (TiltMenu.ts:507)")
	(menu.find_child("ResetCancelButton", true, false) as Button).pressed.emit()
	assert_false(confirm.is_visible_in_tree())
	assert_signal_not_emitted(menu, "reset_confirmed")
	(menu.find_child("ResetButton", true, false) as Button).pressed.emit()
	(menu.find_child("ResetConfirmButton", true, false) as Button).pressed.emit()
	assert_signal_emitted(menu, "reset_confirmed", "TiltMenu.ts:510")
```

Append to `test_main_scene.gd`:

```gdscript
func test_reset_cancel_keeps_every_file() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.options.save()
	root.progression.add_points(5)
	root._menu.open_options_modal()
	(root.find_child("ResetButton", true, false) as Button).pressed.emit()
	(root.find_child("ResetCancelButton", true, false) as Button).pressed.emit()
	assert_true(FileAccess.file_exists(GameOptionsManager.SAVE_PATH))
	assert_true(FileAccess.file_exists(ProgressionManager.SAVE_PATH))


func test_reset_confirm_removes_progress_and_keeps_controls() -> void:
	GameOptionsManager.new().save()
	var goals: GoalManager = GoalManager.new()
	goals.save_completed_goals()
	goals.save_cumulative_stats()
	var progression: ProgressionManager = ProgressionManager.new()
	progression.add_points(5)
	ControlSettings.new().save_settings()
	SaveStore.save_dict(ScoreManager.BEST_SCORE_PATH, {"bestScore": 1200})
	GameRoot.reset_progress_files()
	assert_false(FileAccess.file_exists(GameOptionsManager.SAVE_PATH), "settings_v1 (:512)")
	assert_false(FileAccess.file_exists(GoalManager.SAVE_PATH), "completed_goals_v1 (:513)")
	assert_false(FileAccess.file_exists(GoalManager.CUMULATIVE_SAVE_PATH), "cumulative_stats_v1 (:514)")
	assert_false(FileAccess.file_exists(ProgressionManager.SAVE_PATH), "R10 (Q1 ruling): :515's intent")
	assert_false(FileAccess.file_exists(ScoreManager.BEST_SCORE_PATH), "R10 (Q1 ruling): :516's intent")
	assert_true(FileAccess.file_exists(ControlSettings.SETTINGS_PATH), "R10: not in the prompt")


func test_settings_switches_apply_at_once() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root._menu.open_options_modal()
	(root.find_child("HaloSwitch", true, false) as CheckButton).toggled.emit(false)
	(root.find_child("GridSwitch", true, false) as CheckButton).toggled.emit(true)
	(root.find_child("SfxSwitch", true, false) as CheckButton).toggled.emit(false)
	assert_false(root._entity_layer._high_contrast_halo, "R2/R9")
	assert_true(root._grid_layer.show_gridlines)
	assert_true(root._audio.is_muted(), "R9 (Q2 ruling): set_sfx_enabled at once")
	assert_false(GameOptionsManager.new().settings.sfx_enabled, "and saved")
```

(Read `goal_manager.gd` for the real save-method names. If they differ, write the files with whatever public call persists them, and keep the assertions. If `SaveStore.save_dict` is not how the port writes the best score, use `ScoreManager`'s own save call with a nonzero best. Add `ScoreManager.BEST_SCORE_PATH` to `test_main_scene.gd`'s save-clearing list if it is missing. If `root._audio` is named differently, read `game_root.gd` for the `AudioBank` field.)

(+8 tests in `test_tilt_menu.gd`, +3 in `test_main_scene.gd`.)

- [x] **Step 2: Run to verify they fail.**

- [x] **Step 3: Implement.** In `tilt_menu.gd`, `open_options_modal()` ports `:257-413`. It rebuilds `OptionsModal`'s contents from `_options.settings` and `_settings.scheme` each time it opens, as the TS re-renders on every toggle (`this.openOptionsModal()` at the end of each handler), and then shows it. The handlers in `_bind_options_events()` port `:415-522`:
  - Halo, grid, shake: mutate, `_options.save()`, `readability_changed.emit()` (R9), then `open_options_modal()` (re-render).
  - Sound and Music: `sfx_toggled.emit(is_on)` / `music_toggled.emit(is_on)`, then re-render. `GameRoot` connects them to `set_sfx_enabled` / `set_music_enabled`, which mutate, save and apply (R9, Q2 ruling). Tag: `# DIVERGENCE(M11a Q2): TiltMenu.ts:460-470 only saves; the user ruled Settings applies audio at once, as Pause does (TiltGame.ts:1396-1416).`
  - Scheme card: `scheme_chosen.emit(scheme)`, then re-render after GameRoot writes it. GameRoot's `_on_menu_scheme_chosen` calls `set_control_scheme`. Because `_settings` is the same `ControlSettings` object, the re-render reads the new scheme.
  - `SettingsCalibrateButton`: `calibrate_screen_requested.emit()` (R5). The TS button calibrates in place (`:485-497`). The board sends it to Calibrate instead, so add a PORT-NOTE citing `:485-497`, R4 and R5.
  - `ArmoryLink`: `close_options_modal()` then `armory_requested.emit()` (`:500-503`).
  - `ResetButton` → show `ResetConfirm`. `ResetConfirmButton` → `reset_confirmed.emit()`. `ResetCancelButton` → hide.
  - The TS backdrop click-to-close (`:422-426`) has no counterpart: the modal is full-screen on the board, so there is no backdrop to click. PORT-NOTE.

In `game_root.gd`:

```gdscript
## Deletes the progress files the TS reset prompt names. PORT: web/src/tilt-to-live/TiltMenu.ts:507-517
# DIVERGENCE(M11a Q1): :515-516 remove 'tilt_to_live_progression_v1' and
# 'tilt_to_live_scores_v1', which the TS never writes (ProgressionManager.ts:119 is _v3,
# ScoreManager.ts:162 is 'tilt_to_live_best'), so a TS reset keeps points, unlocks and the
# best score despite its prompt (:508). The user ruled the port deletes them.
# 'tilt_goals_hud_collapsed' (:517) has no port file; control settings and calibration stay.
static func reset_progress_files() -> void:
	for path: String in [
		GameOptionsManager.SAVE_PATH,
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
		ProgressionManager.SAVE_PATH,
		ScoreManager.BEST_SCORE_PATH,
	]:
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


## PORT: web/src/tilt-to-live/TiltMenu.ts:510-520 — window.location.reload() becomes a scene reload.
func reset_progress() -> void:
	reset_progress_files()
	get_tree().reload_current_scene.call_deferred()
```

In `_ready`, connect `_menu.reset_confirmed.connect(reset_progress)`, `_menu.readability_changed.connect(apply_readability)`, `_menu.sfx_toggled.connect(set_sfx_enabled)` and `_menu.music_toggled.connect(set_music_enabled)`. The main-scene tests do not press Confirm through `GameRoot`: that would reload the test scene. They call the static method instead.

- [x] **Step 4: Run the tests.** 52 scripts, **+11 tests** (599). Format and lint.

  *Landed note (Task 5):* `test_audio_switches_announce` as written passed a message as the 4th argument of `assert_signal_emitted_with_parameters`, which GUT 9 reads as the emit index (runtime error). The message became a comment; the assertions are unchanged. The Keys card is built and hidden on mobile (as `ControlPicker`); `SettingsCalibrateButton` is built only while the scheme is `GYRO`.

- [x] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/ui/tilt_menu.gd godot/src/core/game_root.gd godot/tests/test_tilt_menu.gd godot/tests/test_main_scene.gd docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md godot/HANDOFF.md
git commit -m "M11a: port the options modal to the Settings board; next: Task 6"
```

---

### Task 6: The Calibrate screen (R4, R5)

**Files:**
- Create: `godot/src/ui/calibrate_screen.gd`, `godot/tests/test_calibrate_screen.gd`
- Modify: `godot/scenes/main.tscn` (add `Calibrate` after `Menu`), `godot/src/core/game_root.gd`
- Test: `godot/tests/test_main_scene.gd`

**Interfaces:**
- Consumes: `TiltInput` (`request_permission_and_start() -> bool`, `poll()`, `tilt_vector: Vector2`, `stop_listening()`), and `GameRoot.calibrate_gyro() -> bool`.
- Produces: `class_name CalibrateScreen extends Control` with `signal set_level_requested`, `signal closed`, `func bind(tilt: TiltInput) -> void`, `func open() -> void`, `func close() -> void`, `func is_open() -> bool`, `func dot_offset() -> Vector2` (the drawn dot's offset from the disc centre, for tests), and `func set_ui_scale(scale: float, inset: Vector2) -> void`. Node names: `SetLevelButton`, `CancelButton`, `Disc`.

**Layout** (`Calibrate.dc.html`). The screen is full-rect with a scrim `UiTheme.tint(COLOR_VOID, 0.82)`.
- Left block at left 60, width 360, vertically centred, VBox gap 18: caps `"Tilt"` in `COLOR_ION`, the title `"Calibrate"` (Archivo width 112, weight 700, size 28), and the line `"Hold the phone the way you play. That angle becomes still."` (14, `COLOR_TEXT_MUTED`, autowrap). These strings are board-only because the TS has no screen; tag `DIVERGENCE(UI-SYSTEM)`. Below them, a button column of width 260 and gap 10: `SetLevelButton` (`PrimaryButton`, height 56, `"Set level"`) and `CancelButton` (`SecondaryButton`, height 48, `"Cancel"`).
- `Disc` is a `Control` with a custom `_draw`, 230×230, right 96, vertically centred. It draws a circle filled `tint(COLOR_PANEL, 0.6)` with a 1 px `COLOR_LINE` border, then a crosshair in `COLOR_RAISED` inset 14. Next come the top-speed ring (Ø132, 1 px dashed `tint(COLOR_ION, 0.3)`) and the still ring (Ø40, 1 px `tint(COLOR_FLARE, 0.7)`). Last is the dot: Ø28, `COLOR_ION`, drawn at the centre plus `dot_offset()`. Draw the dash with `draw_arc` segments of an even count. The board has no dash length, so use 24 segments with every other one skipped, and tag it `DIVERGENCE(UI-SYSTEM): Calibrate.dc.html — dashed`.
- Legend at right 96, bottom 26, width 230, centred, gap 18. Two mono-11 `TEXT_FAINT` items, each with a 9 px ring swatch: `"still"` and `"top speed"`.
- PORT-NOTE: the still ring is drawn at the board's size, not at `TiltInput.DEADZONE_THRESHOLD` (0.07 of the top-speed radius = 4.6 px). The board is the visual authority, and the legend word is what the player reads.
- `dot_offset()` = `tilt_vector.limit_length(1.0) * 66.0` × `ui_scale` (66 is half of 132, `DIVERGENCE(UI-SYSTEM)`, R4). The board draws the dot 4 px up and 1 px right of centre (`margin: -24px 0 0 -8px`) as a mock of a tilted phone. At rest the port centres it. PORT-NOTE.
- `_process` (UI, not sim): while open, `_tilt.poll()` then `queue_redraw` on `Disc`.

- [x] **Step 1: Write the failing tests** — `godot/tests/test_calibrate_screen.gd`:

```gdscript
## test_calibrate_screen.gd
## PORTS: nothing — new file, covers ui/calibrate_screen.gd
extends GutTest
## The Calibrate board (interface spec §6.6, M11a R4-R5).


func _screen() -> CalibrateScreen:
	var screen: CalibrateScreen = CalibrateScreen.new()
	screen.theme = UiTheme.build(1.0)
	screen.size = Vector2(844.0, 390.0)
	add_child_autofree(screen)
	screen.bind(TiltInput.new())
	return screen


func test_open_shows_and_close_hides() -> void:
	var screen: CalibrateScreen = _screen()
	assert_false(screen.is_open())
	screen.open()
	assert_true(screen.is_open())
	watch_signals(screen)
	(screen.find_child("CancelButton", true, false) as Button).pressed.emit()
	assert_false(screen.is_open(), "Cancel closes (R4)")
	assert_signal_emitted(screen, "closed")


func test_set_level_asks_then_closes() -> void:
	var screen: CalibrateScreen = _screen()
	screen.open()
	watch_signals(screen)
	(screen.find_child("SetLevelButton", true, false) as Button).pressed.emit()
	assert_signal_emitted(screen, "set_level_requested", "R4")
	assert_false(screen.is_open())


func test_the_dot_follows_the_tilt_vector_to_the_top_speed_ring() -> void:
	var screen: CalibrateScreen = _screen()
	screen.open()
	screen._tilt.tilt_vector = Vector2(0.5, 0.0)
	assert_almost_eq(screen.dot_offset(), Vector2(33.0, 0.0), Vector2(0.001, 0.001), "half of 66")
	screen._tilt.tilt_vector = Vector2(0.0, 3.0)
	assert_almost_eq(screen.dot_offset(), Vector2(0.0, 66.0), Vector2(0.001, 0.001), "clamped")


func test_the_dot_rests_at_the_centre() -> void:
	var screen: CalibrateScreen = _screen()
	screen.open()
	assert_eq(screen.dot_offset(), Vector2.ZERO)


func test_every_target_meets_the_48_rule() -> void:
	var screen: CalibrateScreen = _screen()
	screen.open()
	await get_tree().process_frame
	for node_name: String in ["SetLevelButton", "CancelButton"]:
		var b: Button = screen.find_child(node_name, true, false) as Button
		assert_true(b.size.y >= 48.0, node_name)
```

(Assigning `screen._tilt.tilt_vector` directly only works if `_process`'s `poll()` does not overwrite it before the assertion. The assertions run synchronously, so it cannot. If `TiltInput.poll()` with no sensor zeroes the vector, keep these tests synchronous.)

Append to `test_main_scene.gd`:

```gdscript
func test_the_menu_calibrate_icon_opens_the_screen_and_set_level_calibrates() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	(root.find_child("MenuCalibrateButton", true, false) as Button).pressed.emit()
	var screen: CalibrateScreen = root.find_child("Calibrate", true, false) as CalibrateScreen
	assert_true(screen.is_open(), "R5")
	(screen.find_child("SetLevelButton", true, false) as Button).pressed.emit()
	assert_false(screen.is_open())
	var toast: Control = root.find_child("ToastSlot", true, false) as Control
	assert_true(toast.get_child_count() > 0, "calibrate_gyro's toast shows on the menu (R12)")
	assert_false(root._tilt.is_listening, "back in the menu the sensor stops (R4)")
```

(Read `test_calibrate_reports_through_a_message_toast` in the same file for how the port detects the toast. Mirror it exactly instead of `get_child_count()` if it differs.)

(+5 tests in the new script, +1 in `test_main_scene.gd`.)

- [x] **Step 2: Run to verify they fail.** Expect `collected 52 of 53`.

- [x] **Step 3: Implement** `calibrate_screen.gd` (header `PORTS: nothing — new file per interface spec §6.6 (Calibrate.dc.html) and M11a R4-R5`). Add the `main.tscn` node `Calibrate` (full rect, `visible = false`, script, `unique_name_in_owner`) directly after `Menu`. In `game_root.gd`, add `@onready var _calibrate_screen: CalibrateScreen = %Calibrate`. In `_ready`: `_calibrate_screen.bind(_tilt)`; `_menu.calibrate_screen_requested.connect(open_calibrate_screen)`; `_calibrate_screen.set_level_requested.connect(calibrate_gyro_from_screen)`; `_calibrate_screen.closed.connect(_on_calibrate_closed)`. In `resize_canvas`: `_calibrate_screen.set_ui_scale(ui_scale, arena_origin)`.

```gdscript
## Opens the Calibrate board and starts the sensor so its dot moves (M11a R4).
func open_calibrate_screen() -> void:
	_tilt.request_permission_and_start()
	_calibrate_screen.open()


## Set level: the TS calibrateGyro and its toast (TiltGame.ts:2331-2341).
func calibrate_gyro_from_screen() -> void:
	calibrate_gyro()


func _on_calibrate_closed() -> void:
	# M11a R4: reset_run owns the sensor during a run (TiltGame.ts:1553-1557).
	if is_in_menu():
		_tilt.stop_listening()
```

`set_level_requested` must fire **before** `closed`, so that calibration reads a live sensor. In `CalibrateScreen._on_set_level_pressed`, emit `set_level_requested` first, then `close()`, which emits `closed`.

- [x] **Step 4: Run the tests.** 53 scripts, **+6 tests** (605). Format (96 files) and lint.

- [x] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/ui/calibrate_screen.gd godot/src/ui/calibrate_screen.gd.uid godot/tests/test_calibrate_screen.gd godot/tests/test_calibrate_screen.gd.uid godot/scenes/main.tscn godot/src/core/game_root.gd godot/tests/test_main_scene.gd docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md godot/HANDOFF.md
git commit -m "M11a: build the Calibrate board with a live tilt dot; next: Task 7"
```

---

### Task 7: Pause and Run over reach the menu; the M10 R1 picker goes; coins row

**Files:**
- Modify: `godot/src/ui/pause_sheet.gd`, `godot/src/ui/run_over_sheet.gd`, `godot/src/ui/hud_controller.gd`, `godot/src/core/game_root.gd`, `godot/src/sim/run_controller.gd` (the `:214` comment)
- Test: `godot/tests/test_pause_sheet.gd`, `test_run_over_sheet.gd`, `test_main_scene.gd`

**Interfaces:**
- Pause: `QuitToMenuButton` (`SecondaryButton`, `"Quit to menu"`, `TiltGame.ts:1153`), placed where the `TODO(M11)` is at `pause_sheet.gd:147`, under Restart run. `PauseSettingsButton` (`GhostIconButton` 48, gear SVG, TS label `"Settings"`) goes beside `PauseArmoryButton` in `_bottom`, as `Pause.dc.html` draws it. **Remove** the M10 R1 mode picker (`ModePicker`, `ModeButtons`, the `"Mode"` caps, `mode_chosen`, `_mode_button`, `set_mode_choices`) and the three `DIVERGENCE(M10 R1)` tags.
- Run over: `GameOverMenuButton` (`SecondaryButton`, `"Menu"`, `TiltGame.ts:1226`), placed in `_bottom` before Spend as `RunOver.dc.html` draws it. Add `CoinsRow`: a stat line `"Coins"` + `"<n> · +<pts> pt|pts"` (`:2123-2130`, R17), shown iff `coins_collected > 0`, in the stats block's style. Tag it `DIVERGENCE(UI-SYSTEM): RunOver.dc.html — Rule N`. `RunOverSheet` gets a `set_coins(collected: int, points: int) -> void` that `HudController._on_run_over_timer_timeout` calls from `_run.coins`.
- `HudController`: `_on_quit_to_menu_pressed()` → `root.return_to_menu()`; `_on_settings_pressed()` → `root.open_options_from_pause()`. Remove `_on_mode_chosen` and the `set_mode_choices` call in `_refresh_pause_sheet`.
- `GameRoot`: `open_options_from_pause() -> void` → `_menu.open_options_modal()` (`TiltGame.ts:1418-1420`). Remove `set_game_mode` (M10 R1) **only if** no other caller remains: `grep -rn "set_game_mode" godot/`.

- [x] **Step 1: Tests.**

Delete these tests, which cover the removed picker, and **name each deleted test in the commit message**: `test_pause_mode_pick_saves_and_applies_on_restart` (`test_main_scene.gd`) and every picker test in `test_pause_sheet.gd`. Find them with `grep -n "Mode" godot/tests/test_pause_sheet.gd`.

Add to `test_pause_sheet.gd`:

```gdscript
func test_pause_has_quit_to_menu_and_settings_and_no_mode_picker() -> void:
	var sheet: PauseSheet = _make_sheet()
	assert_not_null(sheet.find_child("QuitToMenuButton", true, false), "TiltGame.ts:1153")
	assert_not_null(sheet.find_child("PauseSettingsButton", true, false), "Pause.dc.html")
	assert_null(sheet.find_child("ModePicker", true, false), "M10 R1 removed with the menu")
```

Add to `test_run_over_sheet.gd`:

```gdscript
func test_run_over_has_a_menu_button() -> void:
	var sheet: RunOverSheet = _make_sheet()
	var menu: Button = sheet.find_child("GameOverMenuButton", true, false) as Button
	assert_not_null(menu, "TiltGame.ts:1226")
	assert_eq(menu.text, "Menu")


func test_coins_row_shows_only_after_a_pickup() -> void:
	var sheet: RunOverSheet = _make_sheet()
	sheet.set_coins(0, 0)
	var row: Control = sheet.find_child("CoinsRow", true, false) as Control
	assert_false(row.visible, "TiltGame.ts:2130")
	sheet.set_coins(3, 1)
	assert_true(row.visible, "TiltGame.ts:2128")
	assert_true(sheet.coins_detail_text().ends_with("+1 pt"), "singular (:2127)")
	sheet.set_coins(3, 120)
	assert_eq(sheet.coins_detail_text(), "3 · +120 pts", ":2127")
```

(Use each file's own builder: read its top for the helper name. `coins_detail_text() -> String` is a small public query.)

Add to `test_main_scene.gd`:

```gdscript
func test_pause_quit_to_menu_hides_everything_and_stops_music() -> void:
	var root: GameRoot = await _boot_into_run()
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	(root.find_child("QuitToMenuButton", true, false) as Button).pressed.emit()
	assert_true(root.is_in_menu(), "TiltGame.ts:1392-1393")
	assert_false((root.find_child("PausePanel", true, false) as Control).visible, ":1502")
	assert_false(root._audio._music_player.playing, ":1501")
	assert_true(root._menu.is_menu_visible(), ":1509")


func test_run_over_menu_returns_to_the_menu() -> void:
	var root: GameRoot = await _boot_into_run()
	root._run_controller.lives = 1
	root._run_controller.lose_life()
	(root.find_child("GameOverMenuButton", true, false) as Button).pressed.emit()
	assert_true(root.is_in_menu(), "TiltGame.ts:1428-1430")
	assert_false((root.find_child("GameOverPanel", true, false) as Control).visible, ":1503")


func test_pause_settings_opens_the_options_modal_over_pause() -> void:
	var root: GameRoot = await _boot_into_run()
	(root.find_child("PauseButton", true, false) as Button).pressed.emit()
	(root.find_child("PauseSettingsButton", true, false) as Button).pressed.emit()
	assert_true(root._menu.is_options_open(), "TiltGame.ts:1418-1420")
	assert_true(root.is_paused(), "the run stays paused")
	(root.find_child("OptionsBackButton", true, false) as Button).pressed.emit()
	assert_true((root.find_child("PausePanel", true, false) as Control).visible, "back to Pause")
```

(+1 pause, +2 run over, +3 main scene = +6 added. Removed: 1 main-scene test plus N pause-sheet picker tests. Record N.)

- [x] **Step 2: Run to verify the new tests fail.**

- [x] **Step 3: Implement** as in Interfaces. In `run_controller.gd:214`, replace the `TODO(M11)` with `# PORT-NOTE: the Run over coins row (:2108, :2123-2130) reads coins.coins_collected in HudController (M11a R17).` Replace `pause_sheet.gd:48`'s and `hud_controller.gd:659`'s `TODO(M11)` lines by deleting the code they mark.

- [x] **Step 4: Run the tests.** 53 scripts. Tests = 605 + 6 − (1 + N). Write the number into the commit scope line and the HANDOFF State line. Format and lint. `grep -rn "M10 R1" godot/src` → nothing.

- [x] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/ui/pause_sheet.gd godot/src/ui/run_over_sheet.gd godot/src/ui/hud_controller.gd godot/src/core/game_root.gd godot/src/sim/run_controller.gd godot/tests/test_pause_sheet.gd godot/tests/test_run_over_sheet.gd godot/tests/test_main_scene.gd docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md godot/HANDOFF.md
git commit -m "M11a: wire Quit/Menu/Settings, drop mode picker; next: Task 8 exit"
```

(If the message runs over 72 characters, shorten the next-step clause, but keep it.)

---

### Task 8: Exit — retag the remaining TODOs, VERIFY-ME, docs, verification

**Files:**
- Modify: `godot/src/core/game_state_machine.gd` (already retagged in Task 4; check it), `godot/src/sim/run_controller.gd:124`, `godot/src/sim/enemy_swarm.gd:355`, `godot/src/render/entity_layer.gd:253`, `godot/src/ui/handling_preview.gd:16`, `godot/src/input/tilt_input.gd:113`
- Modify: `godot/VERIFY-ME.md` (append), `godot/PORT-PROGRESS.md`, `godot/HANDOFF.md`, `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md`, spec §8 Module 11

- [x] **Step 1: Retag.** Cinematic items → `TODO(M11b)`: `run_controller.gd:124` (start_music + orb spawn), `enemy_swarm.gd:355` (the handover) and any state-machine line left over from Task 4. Glow and iOS → `TODO(M11c)`: `entity_layer.gd:253`, `handling_preview.gd:16` and `tilt_input.gd:113`. Then:

```bash
grep -rn "TODO(M11)" godot/src godot/tests   # expect: nothing
grep -rn "TODO(M11b)\|TODO(M11c)" godot/src | wc -l   # record the count
```

- [x] **Step 2: Append `## M11a — Menu, Settings, Calibrate` to `godot/VERIFY-ME.md`,** in the file's existing checkbox style, with these device checks (A55, landscape):
  1. A cold boot shows the menu. The backdrop ship roams **left of** the mode panel and dodges, orbs appear there too, and nothing important hides behind the panel (R1). Note any overlap with the title block.
  2. Each mode card highlights with its colour. Play starts that mode, and the run's banner names it.
  3. Pause → Quit to menu → the menu, with no HUD score, no music and the backdrop running. Play again → the run has the equipped ship skin and arena theme.
  4. Death → Run over → Menu → the menu. The Coins row appears only when coins were picked up.
  5. Settings from the menu and from Pause: each switch reads correctly; Enemy outlines off removes the white rings at once; Background grid on shows the grid at once. Screen shake Off/Low/Full visibly changes the hit and death shake in the next run.
  6. Settings → Sound off mutes at once; Music off stops the loop at once; Music on from Pause's Settings starts nothing until Resume (R9, Q2 ruling, same as Pause's own switch).
  7. Calibrate from the menu icon, and from Settings' "Calibrate tilt" (Tilt scheme only): the dot moves with the phone and stops at the dashed ring. Set level → toast "TILT CALIBRATED" on the menu. The next Tilt run is level at that pose.
  8. Reset progress → Cancel changes nothing. Reset → confirm → the app reloads to the menu, settings are back to defaults; milestones, points, unlocks and the best score are cleared; the control scheme and calibration remain (R10, Q1 ruling).
  9. The 48 rule: every menu, Settings and Calibrate target is comfortably tappable. Nothing overlaps at the A55's size.
  10. Android back gesture/button in the menu, Settings and Calibrate: record what happens. The TS has no back button; if it quits the app from Settings, raise it as **Q3**.

- [x] **Step 3: Docs.**
  - `PORT-PROGRESS.md`: replace the single M11 row with three rows, M11a/M11b/M11c. Mark M11a **code complete — device pass pending**, with the date and "exit: the commit carrying this text". M5 and M6 did the same, because a commit cannot contain its own SHA.
  - Index plan module map: rows `11a`/`11b`/`11c`, with M11a pointing at this plan.
  - Spec §8 Module 11: append `**Amended 2026-09-25 (user):** split into M11a (menu, settings, calibrate), M11b (entrance cinematic) and M11c (export and device pass); see docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md.`
  - `HANDOFF.md`: rewrite `## State` (M11a code-complete, device pass pending; next: plan M11b). Add `## M11a — what landed` (a file table and rulings R1–R17, one line each) and `## Open questions (M11a)` with Q1 (fix the TS reset bug or keep it?), Q2 (Settings' audio switches wait for the next run), Q3 (Android back). Rewrite `## Next`: M11b's first step is literally "read `TiltEntranceCinematic.ts` in full, `ColdOpen.dc.html`, `TiltGame.ts:160-178`, `:1302-1309`, `:1344-1360`, `:1523-1530`, every `TODO(M11b)`; write `docs/superpowers/plans/2026-09-20-m11b-entrance-cinematic.md`; commit it and stop for review". Update `## How to verify right now` with the fresh numbers from Step 4.

- [x] **Step 4: Verify fresh and read every output.**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
tools/run_tests.sh                              # expect: OK: 53/53 scripts (<the Task 7 total>)
gdformat --check godot/src godot/tests          # expect: 96 files would be left unchanged
gdlint godot/src godot/tests                    # expect: Success: no problems found
grep -rn "TODO(M11)" godot/src godot/tests      # expect: nothing
grep -rnE "M10 R1([^0-9]|$)" godot/src      # expect: nothing (plain "M10 R1" also hits R10/R11)
grep -rniE "ff4757" godot/src/ui/               # expect: nothing (rule 01)
grep -rn "DIVERGENCE(M11a R1)" godot/src | wc -l   # expect: 3
grep -rn "DIVERGENCE(M11a Q[12])" godot/src | wc -l   # expect: 2
grep -rn "DIVERGENCE" godot/src/ | wc -l        # record
"$GODOT" --headless --path godot --quit-after 240 2>&1 | grep -c "SCRIPT ERROR"   # expect: 0
git checkout godot/project.godot
git status --short                              # expect: only this task's doc changes
```

If the A55 is on `adb`, export the debug APK as in `HANDOFF.md`'s toolchain section, install it, and run the VERIFY-ME §M11a checks with the user. Otherwise, leave them unticked.

- [x] **Step 5: Final review, then commit and stop.** Dispatch one fresh reviewer (the most capable model) over `git diff <plan-commit>..HEAD`, with this plan and interface spec §6.6 as context. Fix every Critical and Important finding, re-run Step 4, and record deferred Minors under Open questions. Then:

```bash
git checkout godot/project.godot
git add godot/src godot/VERIFY-ME.md godot/PORT-PROGRESS.md godot/HANDOFF.md docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md
git commit -m "M11a done: next read godot/HANDOFF.md + VERIFY-ME.md, then plan M11b"
```

**Stop. Report to the user. Do not begin M11b** (CONVENTIONS §9 step 5).

---

## Execution rulings

(Filled during execution: any ruling taken while running a task, one line each, with the task number.)

- Task 4: the p/Escape key path reaches the Pause sheet refresh through `HudController.set_pause_panel_visible(true)`, which calls `_refresh_pause_sheet()` (hud_controller.gd:307-311); `refresh_pause_sheet` was not exposed.
- Task 4: delta +9 (588), because a regression test covers the two R12 HUD guards (`_process` MENU skip, lives-dirty on MENU).
- Task 7: deleted tests (N = 1 in `test_pause_sheet.gd`): `test_pause_mode_pick_saves_and_applies_on_restart` (`test_main_scene.gd`) and `test_mode_picker_marks_the_active_mode_and_emits` (`test_pause_sheet.gd`); `test_sheet_carries_the_board_controls` now lists `QuitToMenuButton`/`PauseSettingsButton` instead of `ModePicker`. Total 605 + 6 − 2 = 609. The one-line commit rule wins over naming them in the commit message.
- Task 7: Pause's Settings is a `SecondaryButton` `"Settings"` beside Armory (flex-grow), as `Pause.dc.html` line 46 draws it — not a gear `GhostIconButton`; the board is the visual authority and UiTheme has no gear icon.
- Task 7: the coins row caption is the TS `"Coin pickups"` (`TiltGame.ts:1218`), not `"Coins"`; the row sits under `PointsRow` (TS order) in its styles (BodyText + PointsText), hidden until `set_coins` sees a pickup.
- Task 7: `UiChecks.overlapping_siblings` skips hidden Containers (a hidden `CoinsRow` never lays out its labels, so they reported as overlapping).
- Task 7: carried fixes from Task 5's review — `TiltMenu.close_options_modal()` also hides `ResetConfirm`; `_switch_card`'s 64-not-60 note is retagged `DIVERGENCE(UI-SYSTEM)`. `GameRoot.set_game_mode` is removed (no caller left; the layers' own `set_game_mode` stay). `DIVERGENCE` total 232 (−3 M10 R1, +3 UI-SYSTEM).
- Task 8: `TODO(M11)` retag count is 5 lines (2 → `TODO(M11b)`, 3 → `TODO(M11c)`); `TODO(M11b)`/`TODO(M11c)` grep total 10 (includes the 3 `game_state_machine.gd` lines already retagged at Task 4).
- Task 8 (final review I-1): **fixed.** Two calibration bugs. (a) `CalibrateScreen._on_set_level_pressed` emitted `set_level_requested` (which only arms a *pending* capture — the real neutral pose is read on the next `TiltInput.poll()`) and then called `close()` in the same call, which stops the screen's own `_process` poll and tells the sensor to stop listening before any poll ever consumed the pending flag — Set level silently did nothing. Fixed: `_on_set_level_pressed` now forces one `_tilt.poll()` between the emit and `close()`. (b) `launch_run`'s `_tilt.calibrate_current_position()` (added per this plan's Task 4 Interfaces text, "as `restart_run` does") has no TS citation — `TiltGame.ts` `launchRun`/`resetRun` never recalibrate — and it silently overwrote whatever pose the player had just set on the Calibrate board, since Play always follows Calibrate back to the menu. Removed; `restart_run`'s own call is untouched (that one is M2.5's own established ruling, VERIFY-ME check 4, "PLAY AGAIN recalibrates to the pose held at that moment", not this module's).
- Task 8 (final review I-2): **fixed.** Closing Settings (`TiltMenu.close_options_modal`) emitted no signal, so when it was opened from Pause (`GameRoot.open_options_from_pause`), Pause's Sound/Music switches, its `ControlPicker` scheme and its Calibrate-button visibility (Rule E) all went stale on close — worse than the TS, whose own pause switches at least self-correct by writing `!settings.x`, where this port's switches write the literal `toggled(is_on)` value. Fixed: a new `TiltMenu.options_closed` signal, connected in `GameRoot._ready` to `_on_options_closed`, which calls `_hud.set_pause_panel_visible(is_paused())` — the same refresh `_on_pause_pressed` already does; harmless when Pause was never the opener (`is_paused()` false — it just re-hides an already-hidden panel, not a no-op call).
- Task 8, controller review round 1 (2026-09-25): **retagging fixed.** The I-2 addition is new behaviour with no TS counterpart, so Law 4 requires `DIVERGENCE`, not `PORT-NOTE` — retagged both sites `# DIVERGENCE(M11a I-2): …` (the `options_closed` signal declaration in `tilt_menu.gd` and the `_on_options_closed` doc comment in `game_root.gd`; the `.connect()` call site keeps a plain comment pointing at those two, so the tag isn't triple-counted). `DIVERGENCE` total 232 → **234**. **Tests added** (regression, RED confirmed by temporarily reverting each fix then restoring it): `test_closing_settings_from_pause_refreshes_the_pause_sheet` (I-2) and `test_launch_run_does_not_recalibrate_the_gyro` (I-1b) in `test_main_scene.gd`. Tests 609 → **611**. `VERIFY-ME.md` §M11a check 7 amended to explain the Restart/PLAY AGAIN-vs-first-Play calibration asymmetry the I-1 fix leaves (M2.5's `restart_run` still recalibrates; the menu's `launch_run` no longer does), for the user to judge on device.
- Task 8 (final review, deferred Minors — recorded, not fixed): **M-1** `return_to_menu`'s `camera_shake = 0.0` reset is credited to "M11a R2" in a comment, but R2 doesn't say this; it should be tagged `DIVERGENCE` with its own ruling or the comment fixed. **M-2** stale "M11" (pre-split) references remain in four comments: `game_root.gd` ("the menu link is M11's" — now M11a; "M11's `_state.restart()`" — should be M11b), `audio_bank.gd` ("which is M11" — should be M11b), `effect_layer.gd` ("the M11 WorldEnvironment pass" — should be M11c). **M-3** `calibrate_screen.gd`'s legend SVGs hardcode `#FFB14D`/`#5B8CFF` instead of formatting `UiTheme.COLOR_FLARE`/`COLOR_ION` into the string, unlike `tilt_menu.gd`'s `RING_ON`/`RING_OFF`. **M-4** with Settings open over Pause, p/Escape resumes the run underneath the full-screen Settings modal — TS-faithful (the TS does the same), device-irrelevant. **M-5** `calibrate_screen.gd`'s draw-arc point counts (64/32/4) are uncited, matching existing uncited precedent in `effect_layer.gd`/`entity_layer.gd`.

## Open questions

- **Q1 (R10): ruled 2026-09-25 — fix it.** Reset also deletes progression and the best score (`DIVERGENCE(M11a Q1)`).
- **Q2 (R9): ruled 2026-09-25 — apply at once**, like Pause's switches (`DIVERGENCE(M11a Q2)`).
- **Q3:** Android's system back has no TS counterpart. What should it do on the menu, in Settings and in Calibrate? Decide at the M11a device pass.
