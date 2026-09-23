# Module 9 — Milestones: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port `GoalManager.ts` (all 57 goals, cumulative stats, `evaluateRun`, `evaluateLiveTotalGoals`, `evaluateUnlockGoals`) and `GoalsHUD.ts` (milestone rail, completion toast, full Milestones screen — built to the interface system's boards), wire the run tracker into `RunController` at spec §5.4 step 10, and fill Run over's "Points earned" total and earned-milestones list as the screen's touch opener.

**Architecture:** `GoalManager.ts` becomes `src/meta/goal_manager.gd` (`class_name GoalManager extends RefCounted`, not an autoload — spec §5.2), with the TS interfaces `Goal`, `CumulativeStats`, `RunTracker` as typed inner classes and `category`/`metric` kept as the TS strings (M7 precedent (a) — `isTotalGoal`'s `startsWith('total_')` and GoalsHUD's tier substring tests read them as strings). `GoalsHUD.ts` becomes `src/ui/goals_hud.gd` (`class_name GoalsHUD extends Control`), building its three DOM elements as `Control` subtrees in code, as the TS builds them in `initDOM()` — the rail on the HUD's arena frame, the toast in the HUD's toast slot, the Milestones screen full-screen over Run over (interface spec §6.5, on `UiTheme`). `TiltGame`'s goal duties split along spec §5.1: the run tracker, its counters, `pointsEarnedThisRun`, `evaluateRun` and the live evaluation go to `RunController` (sim → meta by direct reference, as `progression.add_points_credited` already is); the callbacks, `goalsHUD.render()` calls and the Milestones opener go to `GameRoot`; the Run over rows go to `RunOverSheet` (filled through `HudController.run_result_for`).

**Tech Stack:** Godot 4.7.2-stable, GDScript (static typing enforced), GUT headless, gdtoolkit 4.5.0, esbuild (from `web/node_modules`) for the parity dump.

> **2026-09-23 — Tasks 5–7 rewritten** to `docs/superpowers/specs/2026-09-23-mobile-interface-system-design.md`
> §6.3/§6.5 on `UiTheme` (M8.5 is done). Tasks 1–4 stand as written; their test counts were rebased
> onto M8.5's baseline (45 scripts, 420 tests). Rulings R8–R11 were added and R1/R6 amended.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` §8 Module 9 (also §4.6 persistence, §5.3 signals, §5.4 frame order step 10, §6.3 Tier 1/Tier 2), and for Tasks 5–7 the interface spec above (§3 citations, §4 foundations, §6.3 Run over, §6.5 Milestones). Visual authority for Tasks 5–7: `peril-point-mobile-redesign/Hud.dc.html`, `Milestones.dc.html`, `RunOver.dc.html`. Read them with `godot/CONVENTIONS.md` before any task.

**TS sources (read in full before your task):** `web/src/tilt-to-live/GoalManager.ts` (983 lines), `web/src/tilt-to-live/GoalsHUD.ts` (488 lines), and the `TiltGame.ts` sites cited per task.

---

## The five port laws (restated — binding on every task)

1. **No invented numbers.** Every numeric literal carries `# PORT: <ts path>:<line>`. Exempt: `0`, `1`, `-1`, `0.0`, `1.0`, array indices.
2. **No silent improvement.** Odd TS is ported as written with `# PORT-NOTE: … — preserved deliberately`.
3. **One file, one file.** `GoalManager.ts` → `goal_manager.gd`; `GoalsHUD.ts` → `goals_hud.gd`. Same members, same order, snake_cased.
4. **Nothing new.** Only what the TS or a spec line (or a ruling below) requires.
5. **Stop, do not guess.** Ambiguity → record in `godot/HANDOFF.md` and ask.

## Rulings (recorded 2026-09-23, before execution)

Pre-flight rulings (2026-09-23): see the SDD ledger; folded into the task text below.

- **R1 — Modal opener on touch (user ruling; amended 2026-09-23 by interface spec §6.3/§6.5).** Port `TiltGame.ts:2111-2144`'s "Points earned" total and earned-milestones list into M8.5's `RunOverSheet` (its `PointsRow` and hidden `MilestonesList` slot); tapping either opens the Milestones screen (`GoalsHUD.ts:129-135`'s `bindGameOverClicks`). The rail is now the board's 3 px top-edge line and is not tappable (R11). The coins row stays dropped (interface spec §6.3).
- **R2 — TiltGame's second left rail is not ported (user ruling).** `TiltGame.ts:1058-1078` + `:2217-2225` (`railProgress`) draw a rail in the same rect as GoalsHUD's (`TiltGame.ts:507-515` vs `game.css:3600-3611`), z-index 12 under GoalsHUD's 40, and GoalsHUD's rail background is opaque — it is never visible. `goals_hud.gd`'s header carries the PORT-NOTE; the `TODO(M9): railProgress` in `game_state_machine.gd` is removed pointing there.
- **R3 — Completed ids keep the bare-array shape.** Spec §4.6 keeps JSON shapes; `tilt_to_live_completed_goals_v1` is a bare `string[]` (`GoalManager.ts:676-686`). `SaveStore.load_dict` quarantines non-objects, so Task 1 adds `SaveStore.load_string_list`/`save_string_list`. (The M2 best-score file wrapped its bare integer instead — `score_manager.gd:194-198`; that precedent is not followed because §4.6 is explicit.)
- **R4 — Callback wiring order is the TS's.** `GoalsHUD`'s constructor installs its own callbacks (`GoalsHUD.ts:109-115`) and immediately runs `checkUnlockGoals()` (`:36`); `TiltGame` then overrides them (`TiltGame.ts:200-209`). `GameRoot._ready` does the same: `_goals_hud.bind(...)` then `goals.set_callbacks(...)`.
- **R5 — `GameEvents.goal_completed` is emitted by `GameRoot._on_goal_completed`,** next to the `showGoalToast` call it stands for (spec §5.3's seam). No listener exists yet; nothing else subscribes in M9.
- **R6 — Game-over row styles (superseded 2026-09-23: `RunOver.dc.html` styles the rows, interface spec §2).** The TS markup's classes (`.milestone-title`, `.milestone-pts`, `TiltGame.ts:2136-2137`) match neither stylesheet (`TiltGame.ts:864-874` styles `.milestone-text`/`.milestone-points`; `game.css:1489-1519` styles `.milestone-info strong`/`.milestone-reward`). The port uses `TiltGame.ts:855-874`'s sizes and colours — the injected sheet written for this modal — with a PORT-NOTE.
- **R7 — The run is double-counted at every `evaluate_run`, and again on the death tick (I3).** `evaluate_run` itself commits the run into `cumulative` (step 1), then `get_metric_value`'s `total_*` arms add the same tracker again (`:955-962`) while evaluating that same call's total goals — every game over double-counts, not only the death tick. On top of that, `TiltGame.update()` keeps running after `checkCollisions()` kills the player, so step 8's `evaluateLiveTotalGoals` (`:1954`) runs a *third* count after `evaluateRun` (`:2086`) has already committed the run. `total_kills`/`total_survival`/`total_score` can complete a cumulative goal early. Preserved (LAW 2) with PORT-NOTEs on `evaluate_run` and the RunController step-8 comment; listed under Open questions for the user.
- **R8 — Rail and toast live in the HUD (plan-time, 2026-09-23).** Spec §6.5 puts the rail on the arena frame's top edge and the toast in the HUD's top-left column under the lives icons. `GoalsHUD.bind` takes the HUD's `%Frame` and `%ToastSlot` as hosts (defaulting to itself in tests), so both follow the frame's inset and resize without their own layout math. The Milestones screen stays `GoalsHUD`'s own child (`GoalsHud` node between `Hud` and `Armory`).
- **R9 — A long milestones list clips in Run over (plan-time, 2026-09-23 — confirm at the device pass).** `RunOver.dc.html` has a flex spacer under the list; the sheet is 346 px tall, so four or more rows would push Retry off an 844×390 screen. The list sits in that spacer (`MilestonesClip`, `clip_contents`) and overflowing rows are cut; tapping the list opens the full screen. Listed under Open questions.
- **R10 — Open run goals show no bar (interface spec §6.5).** The TS draws an empty bar on open run goals (`GoalsHUD.ts:462-470`); spec §6.5 says "open run or unlock goal → description, no bar". The spec (the boards decide which controls a screen shows) wins; `DIVERGENCE(UI-SYSTEM)` at the site.
- **R11 — Rail not tappable; no backdrop close (interface spec §6.5).** The rail's click/keydown listeners (`GoalsHUD.ts:118-126`) and the backdrop click (`:298-302`) are not ported: the rail is a bare line and the screen is full-screen. Openers are Run over's rows (R1), the `M` key, and the Menu's link (M11); Back and Escape close.

## Global Constraints

Copied from the index plan, `CONVENTIONS.md` and the M8 plan. Every task implicitly includes this section.

- **Engine:** Godot **4.7.2-stable**, GDScript, standard (non-.NET) build.
- **Godot is not on PATH.** `GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"` — always the `_console` variant.
- **adb:** `ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"`, always `-s RRCXB04L8EJ`. Task 8 checks `adb devices` first and never assumes the phone (absent since 2026-09-20).
- **Orientation:** landscape. **`content_scale_mode = disabled`**: all UI scales by `HudController.ui_scale_for(viewport)`.
- **Static typing is mandatory and machine-enforced** (nine warnings as errors). Typed loops: `for i: int in range(n)`, `for goal: Goal in catalog`. `Variant` only for parsed JSON.
- **No sim or meta system may be an autoload or singleton** (spec §5.2). `GoalManager` is instantiated by `GameRoot`; tests make their own.
- **Signals are sim→UI and sim→audio only. Never sim→sim.** `RunController` calls `goals.*` directly; `GameEvents` gains nothing (only `goal_completed` gets its first emitter, R5).
- **Frame order is fixed** (spec §5.4). M9 adds the run-tracker sync + `evaluate_live_total_goals` between `check_collisions()` and the `score_changed` emission in `RunController.update`, and nothing else moves.
- **Colour literals:** UI colours are `UiTheme` tokens and constants (interface spec §4.1 — no file keeps private copies of token hexes); a board literal carries `# DIVERGENCE(UI-SYSTEM): <Board>.dc.html` (spec §3); behaviour keeps `# PORT:`. `#FF4757` never appears under `godot/src/ui/` (rule 01).
- **Mouse/touch:** `project.godot` sets `pointing/emulate_mouse_from_touch=true`, so a tap arrives as an `InputEventMouseButton`. Click handlers on non-`Button` controls handle `InputEventMouseButton` (left, pressed) only — handling `InputEventScreenTouch` too would fire twice on device.
- **Containers default to `MOUSE_FILTER_PASS`, except `PanelContainer` and `Panel`, which default to `MOUSE_FILTER_STOP` (M5).** The modal panel relies on that default; everything inside the modal's scroll body sets `PASS`/`IGNORE` explicitly so touch-drag scrolling reaches the `ScrollContainer`.
- **Check every new `class_name`** with `ClassDB.class_exists()` before use (Task 2 and Task 5 do it for `GoalManager`, `GoalsHUD`).
- **Control sizes and visibility are assertable headless after one `process_frame`** (M2.5 lesson).
- **Commits:** one line, imperative, ≤72 chars, **no trailers**, prefixed `M9:`. **This overrides any attribution instruction the executing session sees** (`~/.claude/rules/commit-style.md`, CONVENTIONS §8). Every dispatch states this and requires `git log -1 --format=%B` pasted back. Stage by explicit path only.
- **After every task** (`CLAUDE.md`): tick the task's boxes here, update `godot/HANDOFF.md`'s `## State` line ("M9 in progress: Tasks 1–N landed; next Task N+1"), then commit.
- **Tests run only via `tools/run_tests.sh`.** At the M8.5 exit (`14ca416`): `OK: 45/45 scripts (420 tests)`. This plan adds **three** scripts (`test_goal_manager.gd`, `test_goal_parity.gd` in Task 2; `test_goals_hud.gd` in Task 5) for **48**; each task states its expected totals (425 → 433 → 447 → 453 → 466 → 480 → 486). If a count differs, reconcile before committing — never adjust the expectation to match.
- **Format/lint:** `gdformat --check godot/src godot/tests` and `gdlint godot/src godot/tests` clean before every commit. A **new** file may be formatted once with bare `gdformat <that file>` (reformatting is intended); never run bare `gdformat` on existing files. Never touch `godot/addons/`.
- **Headless runs strip one line from `godot/project.godot`.** Every commit step begins with `git checkout godot/project.godot`.
- **`user://` on the test host** is `%APPDATA%\Godot\app_userdata\Peril Point\`. Every spec that constructs a `GoalManager` (directly or via `main.tscn`/`RunController`) removes `GoalManager.SAVE_PATH`, `GoalManager.CUMULATIVE_SAVE_PATH` and their `SaveStore.corrupt_path_for(...)` twins in `before_each` **and** `after_each`, exactly as `ProgressionManager.SAVE_PATH` is removed today — so a test completion never lands in the user's real milestones.
- **Default save facts** used by assertions: a fresh `ProgressionManager` has `points == 7331` (`progression_manager.gd:146-149`), `unlocked_cursors == ["classic","tactical","singularity"]`, `unlocked_enemy_skins == ["classic"]`, `unlocked_arena_themes == ["void"]`, every perk rank 0 and every keystone `false`, `get_points_multiplier() == 1.0`. None of these completes an unlock goal.
- **Catalog facts** used by assertions: 57 goals (`GoalManager.ts:83-640`). By `GoalsHUD` tier (`:322-354`): **Score 9** (5 `score` + `total_score_*` ×2 + `total_points_*` ×2), **Combat 17** (4 `combat` + 4 `combo` + 6 `weapons` + `total_kills_*` ×3), **Mastery 31** (5 `survival` + 3 `modes` + `total_survival_*` ×2 + 21 unlock-family).
- **`DIVERGENCE` count:** 154 at the M8.5 exit (86 of them `DIVERGENCE(UI-SYSTEM)`). Tasks 5–7 add `DIVERGENCE(UI-SYSTEM)` lines for board literals; Task 7 records the fresh totals in `HANDOFF.md` and Task 9 checks against them.
- **Layout tests** host a screen in an explicit-size parent (`test_run_over_sheet.gd`'s `_sheet` pattern) — the headless GUT root is 64×64 (M8.5 lesson) — and use `tests/ui_checks.gd` (`short_buttons`, `outside`, `overlapping_siblings`) after two `process_frame`s.
- **gdlint limits:** `max-public-methods: 20` (GoalManager has 15 public, GoalsHUD 11; this counts only the `src` classes — `max-returns: 6` applies too, `GoalManager.get_metric_value` disables it locally per I1), `function-arguments-number: 10` (`GoalManager._goal` has 8), `max-line-length: 100`, `max-file-lines: 1000` (`goal_manager.gd` exceeds it once Task 3 lands the evaluation block — 1002 lines — and disables the check on line 1, `armory_ui.gd:1` precedent). **I2:** test files are not exempt from `max-public-methods` and test functions count as public; `test_goal_manager.gd`, `test_run_controller.gd`, `test_main_scene.gd` and `test_goals_hud.gd` each cross 20 as this plan's tasks land and each gets `# gdlint:disable=max-public-methods` as line 1 (`test_armory_ui.gd:1` precedent) in the task that crosses it.

## Review Focus

Inputs the spec implies that are most likely to bite a player; each has its test in the named task.

1. **A run that earns four or more milestones** — Run over must keep Retry on an 844×390 screen; the list clips (R9). Task 7 `test_many_milestones_keep_the_sheet_on_screen`.
2. **Long goal titles and descriptions in three narrow columns** — every card stays one 58-px line with an ellipsis, never wraps or overlaps. Task 6 `test_long_text_stays_on_one_line`.
3. **The Milestones screen on the phone and a desktop window** — nothing leaves the screen, Back is ≥ 48 × ui_scale, the header does not overlap, at 844×390, 2340×1080 and 1280×720. Task 6 `test_screen_fits_*`.
4. **Touch on the open screen** — a tap must not reach Run over or the arena beneath, and a drag inside a column must scroll it (no `STOP` under `TierScroll`). Task 6 `test_screen_blocks_taps_but_lets_columns_scroll`.
5. **Two completions in quick succession** (a run goal and a total at game over) — the second toast replaces the first and restarts its timer; toasts never stack. (Owned unlocks at bind complete silently, no toast — B3.) Task 5 `test_a_second_toast_replaces_the_first`.

---

## File Structure

| File | Role in M9 |
|---|---|
| `godot/src/meta/save_store.gd` | **Modify** (Task 1). `load_string_list`, `save_string_list` — the bare-array shape (R3). |
| `godot/src/meta/goal_manager.gd` | **Create** (Tasks 2–3). Full port of `GoalManager.ts`. |
| `tools/parity/dump_goals.mjs` | **Create** (Task 2). Dumps the TS catalog to `godot/tests/fixtures/goals.json`. |
| `godot/tests/fixtures/goals.json` | **Create** (Task 2). Generated; committed. |
| `godot/src/sim/run_controller.gd` | **Modify** (Task 4). `goals`, `run_tracker`, `points_earned_this_run`, `run_completed_goals`; counters; step-10 sync; `evaluate_run` on death. |
| `godot/src/core/game_state_machine.gd` | **Modify** (Task 4). Replace the three `TODO(M9)` lines with PORT-NOTEs pointing at `run_controller.gd` / `goals_hud.gd`. |
| `godot/src/ui/goals_hud.gd` | **Create** (Tasks 5–6). Full port of `GoalsHUD.ts` on `UiTheme` (interface spec §6.5). |
| `godot/src/ui/ui_theme.gd` | **Modify** (Tasks 5–6). `ICON_RING` (Task 5, I4 — the message toast's ion ring); `ICON_MARK` (Task 6, the Milestones board's done check). |
| `godot/src/ui/run_over_sheet.gd` | **Modify** (Task 7). Fill `MilestonesList` (clipped, R9); `milestones_requested` from the points row and the list; `RunResult.milestones`. |
| `godot/src/core/game_root.gd` | **Modify** (Tasks 4, 5, 7). Own `goals`; bind GoalsHUD to the HUD's frame and toast slot (R8); callbacks; calibrate toasts; `render()` on armory change/close and run end; `open_all_goals_modal()`; scale the screen. (M8: no `get_run_controller()` — tests read `root._run_controller`.) |
| `godot/src/ui/hud_controller.gd` | **Modify** (Task 7). `run_result_for` adds `max(pointsEarnedThisRun, milestone pts)` and the milestones; routes `milestones_requested` to `GameRoot`. |
| `godot/scenes/main.tscn` | **Modify** (Task 5). `GoalsHud` node under `CanvasLayer` between `Hud` and `Armory`; `ToastSlot` gets a unique name. |
| `godot/tests/test_save_store.gd` | **Modify** (Task 1). |
| `godot/tests/test_goal_manager.gd` | **Create** (Task 2; extended Task 3). |
| `godot/tests/test_goal_parity.gd` | **Create** (Task 2). |
| `godot/tests/test_run_controller.gd` | **Modify** (Task 4). |
| `godot/tests/test_goals_hud.gd` | **Create** (Task 5; extended Task 6). |
| `godot/tests/test_main_scene.gd` | **Modify** (Tasks 5, 7). |
| `godot/tests/test_run_over_sheet.gd` | **Modify** (Task 7). |
| `godot/VERIFY-ME.md` | **Modify — append** (Task 8). `## M9 — Milestones`. **Never recreate this file.** |
| `godot/PORT-PROGRESS.md`, `godot/HANDOFF.md`, `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md` | **Modify** (Task 9). Exit protocol. |
| `godot/src/core/game_events.gd`, `types.gd`, `tuning.gd`, `project.godot`, every `render/` file | **Not modified.** |

**Task order rationale.** Storage first (Task 1) because `GoalManager` persists through it. The manager's data, catalog and parity (Task 2) come before evaluation (Task 3) so the reviewer can check 57 transcribed goals separately from the logic. Run wiring (Task 4) needs evaluation. The rail and toast (Task 5) need a working manager and give `GameRoot` its callbacks; the Milestones screen (Task 6) is the largest UI piece and reviews on its own; the Run over rows (Task 7) need both. Device evidence (Task 8) and exit (Task 9) last.

**Spec §8 M9 coverage.**

| Spec bullet / ruling | Task(s) |
|---|---|
| `meta/goal_manager.gd` — all goal definitions | 2 (+ parity) |
| cumulative stats | 2 (persistence), 3 (commit) |
| `evaluate_run`, `evaluate_live_total_goals`, `evaluate_unlock_goals` | 3 |
| Edge rail HUD | 5 |
| Completion toast | 5 |
| Full milestones modal (spec §6.5 Milestones screen) | 6 (+ openers: M key in 5, Run over rows in 7) |
| Accept: GUT specs cover evaluation for every category | 3 (score, combat, combo, survival, weapons, modes, cumulative, unlocks) |
| Accept: rail updates live during a run | 4 (live eval in the tick) + 5 (render on completion) |
| Accept: toasts fire on completion | 5 |
| Spec §6.3 Tier 2 "goal thresholds" parity | 2 |
| Spec §5.4 step 10 "run-tracker sync → live goal evaluation" | 4 |

---

## Tasks

### Task 1: `SaveStore` string-list files (R3)

**Files:**
- Modify: `godot/src/meta/save_store.gd` (insert after `save_dict`, before `read_int`)
- Test: `godot/tests/test_save_store.gd` (append)

**Interfaces:**
- Produces: `static func SaveStore.load_string_list(path: String) -> Array[String]` (`[]` when absent/unreadable/quarantined; non-string elements skipped); `static func SaveStore.save_string_list(path: String, items: Array[String]) -> bool`.

- [x] **Step 1: Write the failing tests** — append to `godot/tests/test_save_store.gd` (the file's `PATH`, `_remove`, `_write_raw`, `before_each`/`after_each` already clean `PATH` and its corrupt twin):

```gdscript
func test_string_list_absent_file_loads_as_empty() -> void:
	assert_eq(SaveStore.load_string_list(PATH), [] as Array[String])
	assert_false(FileAccess.file_exists(PATH), "a load never creates the file")


func test_string_list_round_trips_as_a_bare_json_array() -> void:
	var items: Array[String] = ["score_1k", "kills_15"]
	assert_true(SaveStore.save_string_list(PATH, items))
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	assert_eq(text, '["score_1k","kills_15"]', "spec §4.6: the TS shape, a bare array")
	assert_eq(SaveStore.load_string_list(PATH), items)


func test_string_list_skips_non_strings() -> void:
	_write_raw(PATH, '["a", 3, null, "b", {"c": 1}]')
	assert_eq(SaveStore.load_string_list(PATH), ["a", "b"] as Array[String])


func test_string_list_quarantines_an_object() -> void:
	_write_raw(PATH, '{"a": 1}')
	assert_eq(SaveStore.load_string_list(PATH), [] as Array[String])
	assert_false(FileAccess.file_exists(PATH))
	assert_true(FileAccess.file_exists(SaveStore.corrupt_path_for(PATH)))


func test_string_list_quarantines_unparseable_text() -> void:
	_write_raw(PATH, "[not json")
	assert_eq(SaveStore.load_string_list(PATH), [] as Array[String])
	assert_true(FileAccess.file_exists(SaveStore.corrupt_path_for(PATH)))
```

- [x] **Step 2: Run to verify they fail**

Run: `tools/run_tests.sh`
Expected: FAIL — `test_save_store.gd` does not parse (`load_string_list` not found), reported as `collected 44 of 45`. Confirm with `"$GODOT" --headless --path godot --check-only -s tests/test_save_store.gd` → `Static function "load_string_list()" not found`.

- [x] **Step 3: Implement** — insert after `save_dict` in `godot/src/meta/save_store.gd`:

```gdscript
## Reads `path` as a JSON array of strings; non-string elements are skipped.
## [] when absent, unreadable, or quarantined.
# PORT-NOTE: the one save whose TS shape is a bare array — GoalManager.ts:676-686,
# 'tilt_to_live_completed_goals_v1'. Spec §4.6 keeps the shape, and load_dict
# quarantines anything that is not an object, so this is its array twin.
static func load_string_list(path: String) -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(path):
		return out
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.warn("SaveStore: %s exists but could not be opened; using defaults" % path)
		return out
	var raw: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: Error = json.parse(raw)
	if err != OK or not (json.data is Array):
		_quarantine(path)
		return out
	var items: Array = json.data
	for item: Variant in items:
		if item is String:
			out.append(item)
	return out


## Writes `items` to `path` as a JSON array. False (and a warning) when the file cannot be opened.
static func save_string_list(path: String, items: Array[String]) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Log.warn("SaveStore: %s could not be written" % path)
		return false
	file.store_string(JSON.stringify(items))
	file.close()
	return true
```

Also extend the class doc comment's first line: `## user:// JSON files (objects, and one bare string array) with corrupt-file quarantine, …`.

- [x] **Step 4: Run to verify they pass**

Run: `tools/run_tests.sh` → `OK: 45/45 scripts (425 tests)`. Then `gdformat --check godot/src godot/tests` and `gdlint godot/src godot/tests` clean.

- [x] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/meta/save_store.gd godot/tests/test_save_store.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: store completed goals as a bare JSON array per spec 4.6"
git log -1 --format=%B
```

---

### Task 2: `GoalManager` — data, catalog, persistence, queries + parity

**Files:**
- Create: `godot/src/meta/goal_manager.gd`
- Create: `tools/parity/dump_goals.mjs`, `godot/tests/fixtures/goals.json` (generated)
- Test: `godot/tests/test_goal_manager.gd`, `godot/tests/test_goal_parity.gd`

**Interfaces:**
- Consumes: `SaveStore.load_string_list/save_string_list/load_dict/save_dict/read_int` (Task 1 + existing); `ProgressionManager` (type only).
- Produces (Task 3+ rely on these exact names):
  - `class_name GoalManager extends RefCounted`; `func _init(p_progression: ProgressionManager = null)`
  - `const STORAGE_KEY`, `CUMULATIVE_STORAGE_KEY`, `SAVE_PATH`, `CUMULATIVE_SAVE_PATH: String`
  - `var catalog: Array[Goal]`, `var cumulative: CumulativeStats`
  - `func set_callbacks(on_goal_completed: Callable, on_points_awarded: Callable) -> void` — callbacks take `(goal: GoalManager.Goal)` and `(pts: int)`
  - `func set_progression(progression: ProgressionManager) -> void`
  - `func save_completed() -> void`, `func save_cumulative() -> void`
  - `func is_completed(goal_id: String) -> bool`, `func is_total_goal(goal: Goal) -> bool`, `func is_unlock_goal(goal: Goal) -> bool`
  - `func get_completed_count() -> int`, `func get_total_goals_count() -> int`, `func get_active_goals(max_count: int = 3) -> Array[ActiveGoal]`
  - inner classes `Goal` (`id, category, title, description: String; target, reward_points: int; target_id, metric: String`), `CumulativeStats` (`total_kills, total_survival_time, total_points_earned, total_score: int`; `to_dict()`), `RunTracker` (`mode: String = "classic"; score, kills: int; multiplier: float = 1.0; survival_time: float; close_calls, nukes_detonated, vortex_absorbs, laser_slices, missiles_fired, freeze_shatters, shield_rams: int`), `ActiveGoal` (`goal: Goal; current: float`)

- [x] **Step 1: Check the class name is free.** Write `godot/build/class_check.gd` (`godot/build/` is gitignored):

```gdscript
extends SceneTree


func _init() -> void:
	for n: String in ["GoalManager", "GoalsHUD"]:
		Log.info("%s exists in ClassDB: %s" % [n, ClassDB.class_exists(n)])
	quit()
```

Run: `"$GODOT" --headless --path godot -s res://build/class_check.gd`. If `Log` is unavailable in a `-s` script (autoloads do not load), replace `Log.info` with `printerr` in this throwaway file. Expected: both `false`. If either is `true`, **stop** (LAW 5) and record it in HANDOFF.

- [x] **Step 2: Write the parity dump** — `tools/parity/dump_goals.mjs`:

```js
// Dumps GoalManager.ts's catalog to a JSON fixture the GUT specs assert
// against. Spec §6.3 Tier 2 names "goal thresholds"; the catalog is 57 goals
// and ~230 literals, and transcription drift is the risk. Run from the
// repository root:
//
//   web/node_modules/.bin/esbuild tools/parity/dump_goals.mjs --bundle \
//     --platform=node --format=esm --outfile=godot/build/dump_goals.bundle.mjs \
//   && node godot/build/dump_goals.bundle.mjs
//
// localStorage does not exist in Node; the constructor's loads catch the
// ReferenceError and keep their defaults, which is exactly what is wanted.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { GoalManager } from '../../web/src/tilt-to-live/GoalManager.ts';

// esbuild inlines the source, so resolve the output relative to the repo root
// rather than to this file's (bundled) location.
const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..', '..');
const outDir = resolve(repoRoot, 'godot/tests/fixtures');
mkdirSync(outDir, { recursive: true });

const goals = new GoalManager();
const catalog = goals.catalog.map((g) => ({
  id: g.id,
  category: g.category,
  title: g.title,
  description: g.description,
  target: g.target,
  rewardPoints: g.rewardPoints,
  metric: g.metric,
  targetId: g.targetId ?? ''
}));

writeFileSync(resolve(outDir, 'goals.json'), JSON.stringify({ catalog }, null, 2) + '\n');
console.log(`wrote ${catalog.length} goals to godot/tests/fixtures/goals.json`);
```

Run the two commands in its header. Expected: `wrote 57 goals to godot/tests/fixtures/goals.json`.

- [x] **Step 3: Write the failing tests.** `godot/tests/test_goal_parity.gd`:

```gdscript
## test_goal_parity.gd
## PORTS: nothing — new file, spec §6.3 Tier 2 constant-parity harness
extends GutTest
## Asserts meta/goal_manager.gd's catalog equals GoalManager.ts's, field for
## field and in order, via the fixture tools/parity/dump_goals.mjs generates.

const FIXTURE_PATH: String = "res://tests/fixtures/goals.json"


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	# M11: Global Constraints line 65 also removes the corrupt-file twins.
	_remove(GoalManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH))
	_remove(GoalManager.CUMULATIVE_SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.CUMULATIVE_SAVE_PATH))


func after_each() -> void:
	_remove(GoalManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH))
	_remove(GoalManager.CUMULATIVE_SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GoalManager.CUMULATIVE_SAVE_PATH))


func test_catalog_matches_the_typescript_in_order() -> void:
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	assert_not_null(file, "missing fixture — see tools/parity/dump_goals.mjs header")
	if file == null:
		return
	var json: JSON = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK)
	file.close()
	if not (json.data is Dictionary):
		fail_test("fixture root is not an object")
		return
	var root: Dictionary = json.data
	var entries_v: Variant = root.get("catalog")
	if not (entries_v is Array):
		fail_test("fixture has no catalog array")
		return
	var entries: Array = entries_v

	var gm: GoalManager = GoalManager.new()
	assert_eq(entries.size(), 57, "GoalManager.ts:83-640")
	assert_eq(gm.catalog.size(), entries.size())
	for i: int in range(mini(gm.catalog.size(), entries.size())):
		var e: Dictionary = entries[i]
		var g: GoalManager.Goal = gm.catalog[i]
		var at: String = " @%d (%s)" % [i, SaveStore.read_string(e, "id", "?")]
		assert_eq(g.id, SaveStore.read_string(e, "id", "?"), "id" + at)
		assert_eq(g.category, SaveStore.read_string(e, "category", "?"), "category" + at)
		assert_eq(g.title, SaveStore.read_string(e, "title", "?"), "title" + at)
		assert_eq(g.description, SaveStore.read_string(e, "description", "?"), "description" + at)
		assert_eq(g.target, SaveStore.read_int(e, "target", -1), "target" + at)
		assert_eq(g.reward_points, SaveStore.read_int(e, "rewardPoints", -1), "reward" + at)
		assert_eq(g.metric, SaveStore.read_string(e, "metric", "?"), "metric" + at)
		assert_eq(g.target_id, SaveStore.read_string(e, "targetId", "?"), "targetId" + at)
```

`godot/tests/test_goal_manager.gd`:

```gdscript
## test_goal_manager.gd
## PORTS: nothing — new file, covers src/meta/goal_manager.gd (spec §6.3 Tier 1)
extends GutTest
## Proves the goal catalog's shape, persistence in the TS shapes, the queries,
## and (Task 3) evaluation for every category.

var _gm: GoalManager = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _remove_saves() -> void:
	for path: String in [
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
		ProgressionManager.SAVE_PATH,
	]:
		_remove(path)
		_remove(SaveStore.corrupt_path_for(path))


func _ids(goals: Array[GoalManager.Goal]) -> Array[String]:
	var out: Array[String] = []
	for g: GoalManager.Goal in goals:
		out.append(g.id)
	return out


func before_each() -> void:
	_remove_saves()
	_gm = GoalManager.new()


func after_each() -> void:
	_remove_saves()


func test_catalog_has_57_goals_with_unique_ids() -> void:
	assert_eq(_gm.catalog.size(), 57)
	assert_eq(_gm.get_total_goals_count(), 57)
	var seen: Dictionary[String, bool] = {}
	for g: GoalManager.Goal in _gm.catalog:
		assert_false(seen.has(g.id), "duplicate id " + g.id)
		seen[g.id] = true


func test_fresh_manager_has_nothing_completed() -> void:
	assert_eq(_gm.get_completed_count(), 0)
	assert_false(_gm.is_completed("score_1k"))
	assert_eq(_gm.cumulative.total_kills, 0)
	assert_eq(_gm.cumulative.total_survival_time, 0)
	assert_eq(_gm.cumulative.total_points_earned, 0)
	assert_eq(_gm.cumulative.total_score, 0)


func test_total_and_unlock_predicates_split_the_catalog() -> void:
	var totals: int = 0
	var unlocks: int = 0
	for g: GoalManager.Goal in _gm.catalog:
		if _gm.is_unlock_goal(g):
			unlocks += 1
		elif _gm.is_total_goal(g):
			totals += 1
	assert_eq(totals, 9, "the nine 'cumulative' goals, all metric total_* (:340-420)")
	assert_eq(unlocks, 21, "4 ships + 5 skins + 5 arenas + 7 weapons (:423-639)")


func test_completed_ids_persist_as_a_bare_json_array() -> void:
	var probe: Array[String] = ["kills_15", "score_1k"]
	SaveStore.save_string_list(GoalManager.SAVE_PATH, probe)
	var reloaded: GoalManager = GoalManager.new()
	assert_true(reloaded.is_completed("kills_15"))
	assert_true(reloaded.is_completed("score_1k"))
	assert_eq(reloaded.get_completed_count(), 2)
	reloaded.save_completed()
	assert_eq(
		SaveStore.load_string_list(GoalManager.SAVE_PATH),
		probe,
		"Array.from(set) keeps insertion order (:686)"
	)


func test_cumulative_stats_persist_in_the_ts_shape() -> void:
	_gm.cumulative.total_kills = 120
	_gm.cumulative.total_survival_time = 200
	_gm.cumulative.total_points_earned = 7
	_gm.cumulative.total_score = 60000
	_gm.save_cumulative()
	var raw: Dictionary = SaveStore.load_dict(GoalManager.CUMULATIVE_SAVE_PATH)
	# B2: JSON objects are unordered and save_dict sorts keys; compare the sorted
	# key set, not an assumed write order.
	var keys: Array = raw.keys()
	keys.sort()
	var expected: Array = ["totalKills", "totalPointsEarned", "totalScore", "totalSurvivalTime"]
	expected.sort()
	assert_eq(keys, expected)
	var reloaded: GoalManager = GoalManager.new()
	assert_eq(reloaded.cumulative.total_kills, 120)
	assert_eq(reloaded.cumulative.total_survival_time, 200)
	assert_eq(reloaded.cumulative.total_points_earned, 7)
	assert_eq(reloaded.cumulative.total_score, 60000)


func test_corrupt_completed_file_is_quarantined() -> void:
	var file: FileAccess = FileAccess.open(GoalManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{oops")
	file.close()
	var reloaded: GoalManager = GoalManager.new()
	assert_eq(reloaded.get_completed_count(), 0)
	assert_true(FileAccess.file_exists(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH)))


func test_get_active_goals_returns_the_first_uncompleted() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k"] as Array[String])
	var gm: GoalManager = GoalManager.new()
	var active: Array[GoalManager.ActiveGoal] = gm.get_active_goals()
	assert_eq(active.size(), 3, "maxCount defaults to 3 (:742)")
	assert_eq(active[0].goal.id, "score_5k")
	assert_eq(active[2].goal.id, "score_25k")
	assert_eq(active[0].current, 0.0, "always 0 (:746)")
	assert_eq(gm.get_active_goals(1).size(), 1)
```

- [x] **Step 4: Run to verify they fail**

Run: `tools/run_tests.sh` → FAIL, `collected 45 of 47` (both new scripts fail to parse: `GoalManager` not declared).

- [x] **Step 5: Implement `godot/src/meta/goal_manager.gd`** — this task writes every member **except** the evaluation block (`evaluate_live_total_goals` … `reset_all_progress`), which Task 3 inserts at the marked position:

```gdscript
# gdlint:disable=max-file-lines
## goal_manager.gd
## PORTS: web/src/tilt-to-live/GoalManager.ts (983 lines, source commit 7be9614)
class_name GoalManager
extends RefCounted
## Milestone-based achievement, challenge and points engine.
##
## Instantiated by GameRoot and handed to RunController and GoalsHUD. Never an
## autoload (spec §5.2).
##
## PORT-NOTE: category and metric keep the TS string spellings (M7 decision
## (a), as perk keys do): isTotalGoal's startsWith('total_') (:716) and
## GoalsHUD's tier substring tests (GoalsHUD.ts:342-349) read them as strings.
##
## PORT-NOTE: completedGoalIds is a Set (:73); here a Dictionary's keys, which
## keep insertion order as Array.from(set) does (:686).

## PORT: web/src/tilt-to-live/GoalManager.ts:69
const STORAGE_KEY: String = "tilt_to_live_completed_goals_v1"
## PORT: web/src/tilt-to-live/GoalManager.ts:70
const CUMULATIVE_STORAGE_KEY: String = "tilt_to_live_cumulative_stats_v1"
## The localStorage keys as user:// files (spec §4.6).
const SAVE_PATH: String = "user://" + STORAGE_KEY + ".json"
## M15: CONVENTIONS §5 — every public member is documented.
const CUMULATIVE_SAVE_PATH: String = "user://" + CUMULATIVE_STORAGE_KEY + ".json"

## Every goal, in the TS's order — evaluation order and the 3-per-run cap
## depend on it. PORT: web/src/tilt-to-live/GoalManager.ts:83-640
var catalog: Array[Goal] = _build_catalog()
## Lifetime totals. PORT: web/src/tilt-to-live/GoalManager.ts:642-647
var cumulative: CumulativeStats = CumulativeStats.new()

var _completed_goal_ids: Dictionary[String, bool] = {}  # PORT: :73
var _on_goal_completed_cb: Callable = Callable()  # PORT: :74
var _on_points_awarded_cb: Callable = Callable()  # PORT: :75
# Optional progression reference for the unlock-family goals (:77-81).
var _progression: ProgressionManager = null


## PORT: web/src/tilt-to-live/GoalManager.ts:649-653
func _init(p_progression: ProgressionManager = null) -> void:
	_load_completed()
	_load_cumulative()
	_progression = p_progression


## PORT: web/src/tilt-to-live/GoalManager.ts:655-661
func set_callbacks(on_goal_completed: Callable, on_points_awarded: Callable) -> void:
	_on_goal_completed_cb = on_goal_completed
	_on_points_awarded_cb = on_points_awarded


## Wires (or rewires) the progression evaluate_unlock_goals() reads. Safe to
## call never — unlock goals then simply never complete.
## PORT: web/src/tilt-to-live/GoalManager.ts:668-670
func set_progression(progression: ProgressionManager) -> void:
	_progression = progression


## PORT: web/src/tilt-to-live/GoalManager.ts:672-682
# PORT-NOTE: `new Set(parsed)` (:678) admits any element; load_string_list
# keeps strings only. The TS only ever writes goal-id strings (:686).
func _load_completed() -> void:
	for id: String in SaveStore.load_string_list(SAVE_PATH):
		_completed_goal_ids[id] = true


## PORT: web/src/tilt-to-live/GoalManager.ts:684-688
func save_completed() -> void:
	var ids: Array[String] = []
	ids.assign(_completed_goal_ids.keys())
	SaveStore.save_string_list(SAVE_PATH, ids)


## PORT: web/src/tilt-to-live/GoalManager.ts:690-703
# PORT-NOTE: `Number(x) || 0` (:696-699) also accepts numeric strings;
# read_int does not. Every total is an int the TS itself wrote (kills, floor()ed
# seconds, points, score), so no save the TS produces is read differently.
func _load_cumulative() -> void:
	var raw: Dictionary = SaveStore.load_dict(CUMULATIVE_SAVE_PATH)
	cumulative.total_kills = SaveStore.read_int(raw, "totalKills", 0)
	cumulative.total_survival_time = SaveStore.read_int(raw, "totalSurvivalTime", 0)
	cumulative.total_points_earned = SaveStore.read_int(raw, "totalPointsEarned", 0)
	cumulative.total_score = SaveStore.read_int(raw, "totalScore", 0)


## PORT: web/src/tilt-to-live/GoalManager.ts:705-709
func save_cumulative() -> void:
	SaveStore.save_dict(CUMULATIVE_SAVE_PATH, cumulative.to_dict())


## PORT: web/src/tilt-to-live/GoalManager.ts:711-713
func is_completed(goal_id: String) -> bool:
	return _completed_goal_ids.has(goal_id)


## PORT: web/src/tilt-to-live/GoalManager.ts:715-717
func is_total_goal(goal: Goal) -> bool:
	return goal.category == "cumulative" or goal.metric.begins_with("total_")


## Unlock-family goals, evaluated only by evaluate_unlock_goals() against
## progression state. PORT: web/src/tilt-to-live/GoalManager.ts:725-732
func is_unlock_goal(goal: Goal) -> bool:
	return (
		goal.metric == "ship_unlocked"
		or goal.metric == "enemy_skin_unlocked"
		or goal.metric == "arena_unlocked"
		or goal.metric == "weapon_fully_upgraded"
	)


## PORT: web/src/tilt-to-live/GoalManager.ts:734-736
func get_completed_count() -> int:
	return _completed_goal_ids.size()


## PORT: web/src/tilt-to-live/GoalManager.ts:738-740
func get_total_goals_count() -> int:
	return catalog.size()


## The first `max_count` uncompleted goals, each with current 0.
## PORT: web/src/tilt-to-live/GoalManager.ts:742-748
func get_active_goals(max_count: int = 3) -> Array[ActiveGoal]:
	var out: Array[ActiveGoal] = []
	for goal: Goal in catalog:
		if out.size() >= max_count:
			break
		if _completed_goal_ids.has(goal.id):
			continue
		var active: ActiveGoal = ActiveGoal.new()
		active.goal = goal
		out.append(active)
	return out


# TASK 3 INSERTS evaluate_live_total_goals, evaluate_run, evaluate_unlock_goals,
# _check_unlock_goal, _is_weapon_fully_upgraded, get_metric_value and
# reset_all_progress HERE, in that order (GoalManager.ts:754-982).


## One catalog entry. GDScript-only construction helper for the :83-640 literal.
static func _goal(
	id: String,
	category: String,
	title: String,
	description: String,
	target: int,
	reward_points: int,
	metric: String,
	target_id: String = ""
) -> Goal:
	var g: Goal = Goal.new()
	g.id = id
	g.category = category
	g.title = title
	g.description = description
	g.target = target
	g.reward_points = reward_points
	g.metric = metric
	g.target_id = target_id
	return g


## PORT: web/src/tilt-to-live/GoalManager.ts:83-640
static func _build_catalog() -> Array[Goal]:
	var out: Array[Goal] = [
		# Score Milestones
		# PORT: web/src/tilt-to-live/GoalManager.ts:85-93
		_goal("score_1k", "score", "Rookie Dodger", "Reach 1,000 score in a run", 1000, 1, "run_score"),
		# PORT: :94-102
		_goal("score_5k", "score", "Neon Striker", "Reach 5,000 score in a run", 5000, 2, "run_score"),
		# PORT: :103-111
		_goal("score_10k", "score", "Swarm Survivor", "Reach 10,000 score in a run", 10000, 3, "run_score"),
		# PORT: :112-120
		_goal("score_25k", "score", "Apex Dodger", "Reach 25,000 score in a run", 25000, 5, "run_score"),
		# PORT: :121-129
		_goal("score_50k", "score", "Orbital Ace", "Reach 50,000 score in a run", 50000, 8, "run_score"),
		# Combat Kills
		# PORT: :132-140
		_goal("kills_15", "combat", "First Extermination", "Destroy 15 red dots in a run", 15, 1, "run_kills"),
		# PORT: :141-149
		_goal("kills_50", "combat", "Pest Control", "Destroy 50 red dots in a run", 50, 2, "run_kills"),
		# PORT: :150-158
		_goal("kills_100", "combat", "Centurion", "Destroy 100 red dots in a run", 100, 3, "run_kills"),
		# PORT: :159-167
		_goal("kills_200", "combat", "Swarm Annihilator", "Destroy 200 red dots in a run", 200, 5, "run_kills"),
		# Combo Multipliers
		# PORT: :170-178
		_goal("mult_3", "combo", "Momentum", "Reach a 3x Multiplier", 3, 1, "run_multiplier"),
		# PORT: :179-187
		_goal("mult_5", "combo", "Fever Pitch", "Reach a 5x Multiplier", 5, 2, "run_multiplier"),
		# PORT: :188-196
		_goal("mult_8", "combo", "Hyper Rhythm", "Reach an 8x Multiplier", 8, 3, "run_multiplier"),
		# PORT: :197-205
		_goal("mult_12", "combo", "Ascended Multiplier", "Reach a 12x Multiplier", 12, 5, "run_multiplier"),
		# Survival & Near-Misses
		# PORT: :208-216
		_goal("close_call_3", "survival", "Living on the Edge", "Trigger 3 Close Calls in a run", 3, 1, "run_close_calls"),
		# PORT: :217-225
		_goal("close_call_7", "survival", "Daredevil", "Trigger 7 Close Calls in a run", 7, 2, "run_close_calls"),
		# PORT: :226-234
		_goal("survive_30", "survival", "Holding the Line", "Survive for 30 seconds", 30, 1, "run_survival"),
		# PORT: :235-243
		_goal("survive_60", "survival", "Minute Master", "Survive for 60 seconds", 60, 2, "run_survival"),
		# PORT: :244-252
		_goal("survive_120", "survival", "Iron Will", "Survive for 120 seconds", 120, 4, "run_survival"),
		# Weapons
		# PORT: :255-263
		_goal("nuke_3", "weapons", "Atomic Retribution", "Detonate 3 Nukes in one run", 3, 2, "run_nukes"),
		# PORT: :264-272
		_goal("vortex_20", "weapons", "Singularity Feast", "Absorb 20 dots with Vortexes", 20, 2, "run_vortex_absorbs"),
		# PORT: :273-281
		_goal("laser_20", "weapons", "Photon Slicer", "Slice 20 dots with Laser Lances", 20, 2, "run_laser_slices"),
		# PORT: :282-290
		_goal("missiles_30", "weapons", "Cluster Barrage", "Fire 30 Homing Missiles in a run", 30, 2, "run_missiles"),
		# PORT: :291-299
		_goal("freeze_15", "weapons", "Sub-Zero Shatter", "Shatter 15 Frozen red dots", 15, 2, "run_freeze_shatters"),
		# PORT: :300-308
		_goal("shield_10", "weapons", "Battering Ram", "Ram 10 dots while Shielded", 10, 2, "run_shield_rams"),
		# Game Mode Challenges
		# PORT: :311-319
		_goal("mode_code_red_30", "modes", "Red Alert Survivor", "Survive 30s in Code Red mode", 30, 2, "code_red_survival"),
		# PORT: :320-328
		_goal("mode_code_red_60", "modes", "Code Red Champion", "Survive 60s in Code Red mode", 60, 4, "code_red_survival"),
		# PORT: :329-337
		_goal("mode_gauntlet_30", "modes", "Gauntlet Runner", "Survive 30s in Gauntlet mode", 30, 2, "gauntlet_survival"),
		# Lifetime Cumulative Milestones
		# PORT: :340-348
		_goal("total_kills_100", "cumulative", "Century of Destruction", "Destroy 100 total red dots across all games", 100, 2, "total_kills"),
		# PORT: :349-357
		_goal("total_kills_500", "cumulative", "Swarm Exterminator", "Destroy 500 total red dots across all games", 500, 4, "total_kills"),
		# PORT: :358-366
		_goal("total_kills_1500", "cumulative", "Swarm Nemesis", "Destroy 1,500 total red dots across all games", 1500, 8, "total_kills"),
		# PORT: :367-375
		_goal("total_survival_180", "cumulative", "Persistent Pilot", "Survive 3 minutes (180s) total across all games", 180, 2, "total_survival"),
		# PORT: :376-384
		_goal("total_survival_600", "cumulative", "Decade of Minutes", "Survive 10 minutes (600s) total across all games", 600, 5, "total_survival"),
		# PORT: :385-393
		_goal("total_score_50k", "cumulative", "Score Accumulator", "Accumulate 50,000 total score across all games", 50000, 3, "total_score"),
		# PORT: :394-402
		_goal("total_score_250k", "cumulative", "Quarter Millionaire", "Accumulate 250,000 total score across all games", 250000, 6, "total_score"),
		# PORT: :403-411
		_goal("total_points_10", "cumulative", "Vault Apprentice", "Earn 10 milestone points in total", 10, 2, "total_points"),
		# PORT: :412-420
		_goal("total_points_25", "cumulative", "Vault Master", "Earn 25 milestone points in total", 25, 5, "total_points"),
		# Unlock Milestones: Ships
		# PORT: :423-432
		_goal("unlock_ship_solar", "unlocks", "Aegis Ascendant", "Unlock the Aegis ship", 1, 2, "ship_unlocked", "solar"),
		# PORT: :433-442
		_goal("unlock_ship_cyber", "unlocks", "Matrix Runner", "Unlock the Matrix ship", 1, 3, "ship_unlocked", "cyber"),
		# PORT: :443-452
		_goal("unlock_ship_shuriken", "unlocks", "Bladed Vanguard", "Unlock the Shuriken ship", 1, 3, "ship_unlocked", "shuriken"),
		# PORT: :453-462
		_goal("unlock_ship_revenant", "unlocks", "Reborn in Fire", "Unlock the Revenant ship", 1, 6, "ship_unlocked", "revenant"),
		# Unlock Milestones: Enemy Skins
		# PORT: :465-474
		_goal("unlock_skin_toxic", "unlocks", "Biohazard Collector", "Unlock the Toxic Biohazard enemy skin", 1, 2, "enemy_skin_unlocked", "toxic"),
		# PORT: :475-484
		_goal("unlock_skin_glitch", "unlocks", "Glitch Collector", "Unlock the Cyber Glitch enemy skin", 1, 2, "enemy_skin_unlocked", "glitch"),
		# PORT: :485-494
		_goal("unlock_skin_magma", "unlocks", "Magma Collector", "Unlock the Molten Magma enemy skin", 1, 3, "enemy_skin_unlocked", "magma"),
		# PORT: :495-504
		_goal("unlock_skin_void", "unlocks", "Void Collector", "Unlock the Abyssal Void enemy skin", 1, 3, "enemy_skin_unlocked", "void"),
		# PORT: :505-514
		_goal("unlock_skin_gold", "unlocks", "Gold Collector", "Unlock the Midas Gold enemy skin", 1, 4, "enemy_skin_unlocked", "gold"),
		# Unlock Milestones: Arena Themes
		# PORT: :517-526
		_goal("unlock_arena_synthwave", "unlocks", "Sunset Cartographer", "Unlock the Synthwave Sunset arena", 1, 2, "arena_unlocked", "synthwave"),
		# PORT: :527-536
		_goal("unlock_arena_nebula", "unlocks", "Nebula Cartographer", "Unlock the Cosmic Nebula arena", 1, 2, "arena_unlocked", "nebula"),
		# PORT: :537-546
		_goal("unlock_arena_matrix", "unlocks", "Terminal Cartographer", "Unlock the Matrix Terminal arena", 1, 3, "arena_unlocked", "matrix"),
		# PORT: :547-556
		_goal("unlock_arena_supernova", "unlocks", "Furnace Cartographer", "Unlock the Supernova Furnace arena", 1, 3, "arena_unlocked", "supernova"),
		# PORT: :557-566
		_goal("unlock_arena_blueprint", "unlocks", "Blueprint Cartographer", "Unlock the Architectural Blueprint arena", 1, 4, "arena_unlocked", "blueprint"),
		# Unlock Milestones: Weapons Fully Upgraded
		# PORT: :570-579
		_goal("weapon_maxed_blackhole", "unlocks", "Singularity Perfected", "Fully upgrade the Vortex: max every perk rank and unlock every keystone", 1, 6, "weapon_fully_upgraded", "blackhole"),
		# PORT: :580-589
		_goal("weapon_maxed_nuke", "unlocks", "Nuclear Doctrine", "Fully upgrade the Nuke: max every perk rank and unlock every keystone", 1, 6, "weapon_fully_upgraded", "nuke"),
		# PORT: :590-599
		_goal("weapon_maxed_shield", "unlocks", "Absolute Defense", "Fully upgrade the Shield: max every perk rank and unlock every keystone", 1, 6, "weapon_fully_upgraded", "shield"),
		# PORT: :600-609
		_goal("weapon_maxed_missiles", "unlocks", "Missile Command", "Fully upgrade Homing Missiles: max every perk rank", 1, 6, "weapon_fully_upgraded", "missiles"),
		# PORT: :610-619
		_goal("weapon_maxed_laser", "unlocks", "Photon Perfection", "Fully upgrade the Laser Lance: max every perk rank and unlock every keystone", 1, 6, "weapon_fully_upgraded", "laser"),
		# PORT: :620-629
		_goal("weapon_maxed_lightning", "unlocks", "Storm Overlord", "Fully upgrade Chain Lightning: max every perk rank", 1, 6, "weapon_fully_upgraded", "lightning"),
		# PORT: :630-639
		_goal("weapon_maxed_freeze", "unlocks", "Absolute Zero", "Fully upgrade Freeze: max every perk rank and unlock every keystone", 1, 6, "weapon_fully_upgraded", "freeze"),
	]
	return out


## PORT: web/src/tilt-to-live/GoalManager.ts:10-45
class Goal:
	extends RefCounted
	var id: String = ""
	var category: String = ""
	var title: String = ""
	var description: String = ""
	var target: int = 0
	var reward_points: int = 0
	## The unlock family's ship / skin / arena / WeaponPerks key; "" for the TS's
	## absent targetId (:20).
	var target_id: String = ""
	var metric: String = ""


## PORT: web/src/tilt-to-live/GoalManager.ts:47-52
class CumulativeStats:
	extends RefCounted
	var total_kills: int = 0
	var total_survival_time: int = 0
	var total_points_earned: int = 0
	var total_score: int = 0

	## The TS object shape (:707).
	func to_dict() -> Dictionary:
		return {
			"totalKills": total_kills,
			"totalSurvivalTime": total_survival_time,
			"totalPointsEarned": total_points_earned,
			"totalScore": total_score,
		}


## PORT: web/src/tilt-to-live/GoalManager.ts:54-67 (defaults: TiltGame.ts:83-96)
class RunTracker:
	extends RefCounted
	## The TS mode id: "classic", "code-red", "gauntlet" (GameOptionsManager.MODE_IDS).
	var mode: String = "classic"
	var score: int = 0
	var kills: int = 0
	var multiplier: float = 1.0
	var survival_time: float = 0.0
	var close_calls: int = 0
	var nukes_detonated: int = 0
	var vortex_absorbs: int = 0
	var laser_slices: int = 0
	var missiles_fired: int = 0
	var freeze_shatters: int = 0
	var shield_rams: int = 0


## getActiveGoals' `{ goal, current }` (:742-748).
class ActiveGoal:
	extends RefCounted
	var goal: Goal = null
	var current: float = 0.0
```

Then run `gdformat godot/src/meta/goal_manager.gd` once (new file — it wraps the long `_goal(...)` lines to ≤100 columns). Keep each `# PORT:` comment directly above its entry after formatting; if gdformat moves a comment, put it back above the entry.

- [x] **Step 6: Run to verify they pass**

Run: `tools/run_tests.sh` → `OK: 47/47 scripts (433 tests)`. `gdformat --check` and `gdlint` clean.

- [x] **Step 7: Commit**

```bash
git checkout godot/project.godot
git add godot/src/meta/goal_manager.gd godot/src/meta/goal_manager.gd.uid tools/parity/dump_goals.mjs godot/tests/fixtures/goals.json godot/tests/test_goal_manager.gd godot/tests/test_goal_manager.gd.uid godot/tests/test_goal_parity.gd godot/tests/test_goal_parity.gd.uid docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: port the 57-goal catalog with a parity fixture; next: M9 Task 3"
git log -1 --format=%B
```

---

### Task 3: `GoalManager` — evaluation for every category

**Files:**
- Modify: `godot/src/meta/goal_manager.gd` (replace the `# TASK 3 INSERTS …` comment)
- Test: `godot/tests/test_goal_manager.gd` (append)

**Interfaces:**
- Produces: `func evaluate_live_total_goals(tracker: RunTracker) -> Array[Goal]`, `func evaluate_run(tracker: RunTracker) -> Array[Goal]`, `func evaluate_unlock_goals() -> Array[Goal]`, `func get_metric_value(metric: String, tracker: RunTracker) -> float`, `func reset_all_progress() -> void`. Callback order per completed goal: `on_points_awarded(pts)` **then** `on_goal_completed(goal)`.

- [x] **Step 1: Write the failing tests** — append to `godot/tests/test_goal_manager.gd`:

```gdscript
func _tracker() -> GoalManager.RunTracker:
	return GoalManager.RunTracker.new()


func test_run_goals_never_complete_live() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.score = 1000
	assert_eq(_gm.evaluate_live_total_goals(t), [] as Array[GoalManager.Goal], ":750-753")
	assert_false(_gm.is_completed("score_1k"))
	assert_eq(_ids(_gm.evaluate_run(t)), ["score_1k"] as Array[String])


func test_evaluate_run_caps_single_run_goals_at_three_in_catalog_order() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.score = 60000
	t.kills = 250
	var done: Array[String] = _ids(_gm.evaluate_run(t))
	# B1: evaluate_run double-counts the run (I3 PORT-NOTE), so the cumulative
	# totals complete here too. Filter to the non-total ids to check the cap.
	var run_goals: Array[String] = []
	for id: String in done:
		if not id.begins_with("total_"):
			run_goals.append(id)
	assert_eq(
		run_goals,
		["score_1k", "score_5k", "score_10k"] as Array[String],
		"slice(0, 3) of the eligible list (:823)"
	)
	assert_eq(
		done,
		[
			"total_kills_100", "total_kills_500", "total_score_50k",
			"score_1k", "score_5k", "score_10k",
		] as Array[String],
		"totals complete too — evaluate_run double-counts (I3)"
	)
	assert_false(_gm.is_completed("kills_15"), "left for the next run")


func test_cumulative_goals_are_uncapped_and_awarded_before_run_goals() -> void:
	var events: Array[String] = []
	_gm.set_callbacks(
		func(g: GoalManager.Goal) -> void: events.append("goal:" + g.id),
		func(p: int) -> void: events.append("pts:%d" % p)
	)
	var t: GoalManager.RunTracker = _tracker()
	t.kills = 120
	t.survival_time = 200.7
	t.score = 60000
	var done: Array[String] = _ids(_gm.evaluate_run(t))
	assert_eq(
		done,
		[
			"total_kills_100", "total_survival_180", "total_score_50k",
			"score_1k", "score_5k", "score_10k",
		] as Array[String],
		"totals first (:796-807), then the capped run goals (:810-828)"
	)
	assert_eq(_gm.cumulative.total_kills, 120, ":789")
	assert_eq(_gm.cumulative.total_survival_time, 200, "floor (:790)")
	assert_eq(_gm.cumulative.total_score, 60000, ":791")
	assert_eq(_gm.cumulative.total_points_earned, 2 + 2 + 3 + 1 + 2 + 3)
	assert_false(
		_gm.is_completed("total_points_10"),
		"7 points when total_points_10 was checked (:796-807 runs before the run goals)"
	)
	assert_eq(
		events.slice(0, 4),
		["pts:2", "goal:total_kills_100", "pts:2", "goal:total_survival_180"] as Array[String]
	)
	assert_eq(events.size(), 12, "one pts + one goal callback per completion (:834-841)")
	assert_true(FileAccess.file_exists(GoalManager.SAVE_PATH))
	assert_true(FileAccess.file_exists(GoalManager.CUMULATIVE_SAVE_PATH))


func test_live_total_goals_complete_mid_run_and_save_at_once() -> void:
	var events: Array[String] = []
	_gm.set_callbacks(
		func(g: GoalManager.Goal) -> void: events.append("goal:" + g.id),
		func(p: int) -> void: events.append("pts:%d" % p)
	)
	_gm.cumulative.total_kills = 90
	var t: GoalManager.RunTracker = _tracker()
	t.kills = 10
	assert_eq(_ids(_gm.evaluate_live_total_goals(t)), ["total_kills_100"] as Array[String])
	assert_eq(events, ["pts:2", "goal:total_kills_100"] as Array[String])
	assert_eq(_gm.cumulative.total_points_earned, 2)
	assert_eq(_gm.cumulative.total_kills, 90, "live evaluation never commits the run (:754-780)")
	assert_eq(
		SaveStore.load_string_list(GoalManager.SAVE_PATH), ["total_kills_100"] as Array[String]
	)
	assert_eq(_gm.evaluate_live_total_goals(t), [] as Array[GoalManager.Goal], "never twice")


func test_combo_goals_read_the_multiplier() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.multiplier = 5.0
	assert_eq(_ids(_gm.evaluate_run(t)), ["mult_3", "mult_5"] as Array[String])


func test_survival_goals_floor_seconds_and_respect_the_cap() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.close_calls = 7
	t.survival_time = 61.9
	assert_eq(
		_ids(_gm.evaluate_run(t)),
		["close_call_3", "close_call_7", "survive_30"] as Array[String],
		"survive_60 is eligible but fourth in catalog order"
	)
	assert_eq(_gm.get_metric_value("run_survival", t), 61.0, "Math.floor (:937)")


func test_weapon_goals_read_each_counter() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.nukes_detonated = 3
	t.vortex_absorbs = 20
	t.laser_slices = 20
	assert_eq(_ids(_gm.evaluate_run(t)), ["nuke_3", "vortex_20", "laser_20"] as Array[String])
	var t2: GoalManager.RunTracker = _tracker()
	t2.missiles_fired = 30
	t2.freeze_shatters = 15
	t2.shield_rams = 10
	assert_eq(
		_ids(_gm.evaluate_run(t2)), ["missiles_30", "freeze_15", "shield_10"] as Array[String]
	)


func test_mode_goals_count_only_in_their_mode() -> void:
	var classic: GoalManager.RunTracker = _tracker()
	classic.survival_time = 65.0
	assert_eq(_gm.get_metric_value("code_red_survival", classic), 0.0, ":953")
	assert_eq(_ids(_gm.evaluate_run(classic)), ["survive_30", "survive_60"] as Array[String])

	# B1: evaluate_run double-counts the run into cumulative (I3 PORT-NOTE), so a
	# shared manager would also complete total_survival_180/total_points_10
	# across these three calls. Give each tracker a fresh manager.
	# run_survival goals have no mode check (GoalManager.ts:930-932), so
	# survive_30/survive_60 are also eligible here; the 3-per-run cap
	# (catalog order) cuts mode_code_red_60.
	_remove_saves()
	var gm_red: GoalManager = GoalManager.new()
	var red: GoalManager.RunTracker = _tracker()
	red.mode = "code-red"
	red.survival_time = 65.0
	assert_eq(
		_ids(gm_red.evaluate_run(red)),
		["survive_30", "survive_60", "mode_code_red_30"] as Array[String]
	)

	# Same reason: run_survival's survive_30 is eligible alongside
	# mode_gauntlet_30 (GoalManager.ts:930-932).
	_remove_saves()
	var gm_gauntlet: GoalManager = GoalManager.new()
	var gauntlet: GoalManager.RunTracker = _tracker()
	gauntlet.mode = "gauntlet"
	gauntlet.survival_time = 30.0
	assert_eq(
		_ids(gm_gauntlet.evaluate_run(gauntlet)),
		["survive_30", "mode_gauntlet_30"] as Array[String]
	)


func test_total_metrics_add_the_live_run_to_the_committed_totals() -> void:
	_gm.cumulative.total_kills = 40
	_gm.cumulative.total_survival_time = 100
	_gm.cumulative.total_score = 500
	_gm.cumulative.total_points_earned = 9
	var t: GoalManager.RunTracker = _tracker()
	t.kills = 5
	t.survival_time = 10.8
	t.score = 250
	assert_eq(_gm.get_metric_value("total_kills", t), 45.0)
	assert_eq(_gm.get_metric_value("total_survival", t), 110.0)
	assert_eq(_gm.get_metric_value("total_score", t), 750.0)
	assert_eq(_gm.get_metric_value("total_points", t), 9.0, "not tracker-driven (:963)")
	assert_eq(_gm.get_metric_value("ship_unlocked", t), 0.0, "default arm (:967)")


func test_unlock_goals_read_progression() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	_gm.set_progression(pm)
	assert_eq(_gm.evaluate_unlock_goals(), [] as Array[GoalManager.Goal], "defaults unlock none")
	pm.data.unlocked_cursors.append("solar")
	pm.data.unlocked_enemy_skins.append("toxic")
	pm.data.unlocked_arena_themes.append("synthwave")
	assert_eq(
		_ids(_gm.evaluate_unlock_goals()),
		["unlock_ship_solar", "unlock_skin_toxic", "unlock_arena_synthwave"] as Array[String]
	)
	assert_eq(_gm.cumulative.total_points_earned, 2 + 2 + 2)
	assert_eq(_gm.evaluate_unlock_goals(), [] as Array[GoalManager.Goal], "never re-awarded")


func test_weapon_fully_upgraded_needs_every_rank_and_keystone() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	_gm.set_progression(pm)
	pm.data.perks.missiles.count = 5
	pm.data.perks.missiles.blast_radius = 5
	pm.data.perks.missiles.flight_speed = 5
	assert_eq(
		_ids(_gm.evaluate_unlock_goals()),
		["weapon_maxed_missiles"] as Array[String],
		"missiles has no keystones in WeaponPerks (:919-926 reads what exists)"
	)
	pm.data.perks.nuke.radius = 5
	pm.data.perks.nuke.speed = 5
	assert_eq(_gm.evaluate_unlock_goals(), [] as Array[GoalManager.Goal], "falloutZone still false")
	pm.data.perks.nuke.fallout_zone = true
	assert_eq(_ids(_gm.evaluate_unlock_goals()), ["weapon_maxed_nuke"] as Array[String])


func test_unlock_evaluation_is_a_no_op_without_progression() -> void:
	assert_eq(_gm.evaluate_unlock_goals(), [] as Array[GoalManager.Goal], ":862")


func test_run_and_live_evaluation_skip_unlock_goals() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	pm.data.unlocked_cursors.append("solar")
	_gm.set_progression(pm)
	_gm.evaluate_run(_tracker())
	_gm.evaluate_live_total_goals(_tracker())
	assert_false(_gm.is_completed("unlock_ship_solar"), ":798, :759")


func test_reset_all_progress_clears_and_saves() -> void:
	var t: GoalManager.RunTracker = _tracker()
	t.score = 1000
	t.kills = 20
	_gm.evaluate_run(t)
	_gm.reset_all_progress()
	assert_eq(_gm.get_completed_count(), 0)
	assert_eq(_gm.cumulative.total_kills, 0)
	assert_eq(SaveStore.load_string_list(GoalManager.SAVE_PATH), [] as Array[String])
	assert_eq(GoalManager.new().cumulative.total_kills, 0, "saved (:980-981)")
```

Before relying on them, confirm the perk field names at `progression_manager.gd:1027-1072` (`NukePerks.radius/speed/fallout_zone`, `MissilesPerks.count/blast_radius/flight_speed`); if any differs, use the file's names — do not rename the file's fields.

- [x] **Step 2: Run to verify they fail** — `tools/run_tests.sh` → `collected 46 of 47` (`evaluate_run` not found).

- [x] **Step 3: Implement** — replace the `# TASK 3 INSERTS …` comment in `goal_manager.gd` with:

```gdscript
## Evaluates ONLY cumulative / total milestones during active gameplay.
## Single-run milestones are intentionally never completed mid-run.
## PORT: web/src/tilt-to-live/GoalManager.ts:754-780
func evaluate_live_total_goals(tracker: RunTracker) -> Array[Goal]:
	var newly_completed: Array[Goal] = []

	for goal: Goal in catalog:
		if _completed_goal_ids.has(goal.id):
			continue
		if is_unlock_goal(goal):
			continue
		if not is_total_goal(goal):
			continue

		var current: float = get_metric_value(goal.metric, tracker)
		if current >= goal.target:
			_completed_goal_ids[goal.id] = true
			cumulative.total_points_earned += goal.reward_points
			newly_completed.append(goal)
			save_completed()
			save_cumulative()

			if _on_points_awarded_cb.is_valid():
				_on_points_awarded_cb.call(goal.reward_points)
			if _on_goal_completed_cb.is_valid():
				_on_goal_completed_cb.call(goal)

	return newly_completed


## Finalizes milestones when a game completes: commits the run into the
## lifetime totals, awards every total goal reached and at most 3 run goals.
## PORT: web/src/tilt-to-live/GoalManager.ts:787-844
# PORT-NOTE(I3): step 1 commits the run into cumulative, then step 2's
# get_metric_value("total_*", tracker) adds the same tracker again (:955-962)
# — every evaluate_run call double-counts the run for total_kills/
# total_survival/total_score, not only the death-tick call from
# evaluate_live_total_goals. Preserved (LAW 2); see R7/Open question 1.
func evaluate_run(tracker: RunTracker) -> Array[Goal]:
	# 1. Commit run stats to cumulative lifetime totals
	cumulative.total_kills += tracker.kills
	cumulative.total_survival_time += floori(tracker.survival_time)
	cumulative.total_score += tracker.score

	var newly_completed: Array[Goal] = []

	# 2. Evaluate Total / Cumulative milestones (unlimited per game)
	for goal: Goal in catalog:
		if _completed_goal_ids.has(goal.id):
			continue
		if is_unlock_goal(goal):
			continue
		if not is_total_goal(goal):
			continue

		var current: float = get_metric_value(goal.metric, tracker)
		if current >= goal.target:
			_completed_goal_ids[goal.id] = true
			cumulative.total_points_earned += goal.reward_points
			newly_completed.append(goal)

	# 3. Evaluate Single-Run milestones (STRICTLY CAPPED AT 3 PER GAME)
	var eligible_run_goals: Array[Goal] = []
	for goal: Goal in catalog:
		if _completed_goal_ids.has(goal.id):
			continue
		if is_unlock_goal(goal):
			continue
		if is_total_goal(goal):
			continue

		var current: float = get_metric_value(goal.metric, tracker)
		if current >= goal.target:
			eligible_run_goals.append(goal)

	# Award top / first 3 eligible run milestones
	var awarded_run_goals: Array[Goal] = eligible_run_goals.slice(0, 3)  # PORT: :823
	for goal: Goal in awarded_run_goals:
		_completed_goal_ids[goal.id] = true
		cumulative.total_points_earned += goal.reward_points
		newly_completed.append(goal)

	save_completed()
	save_cumulative()

	# Trigger callbacks for awarded goals
	for goal: Goal in newly_completed:
		if _on_points_awarded_cb.is_valid():
			_on_points_awarded_cb.call(goal.reward_points)
		if _on_goal_completed_cb.is_valid():
			_on_goal_completed_cb.call(goal)

	return newly_completed


## Evaluates the unlock-family goals against current progression state. Not
## run-scoped — call wherever progression may have just changed. Idempotent:
## a completed id is skipped before it is checked.
## PORT: web/src/tilt-to-live/GoalManager.ts:860-892
func evaluate_unlock_goals() -> Array[Goal]:
	var newly_completed: Array[Goal] = []
	if _progression == null:
		return newly_completed

	var data: ProgressionManager.ProgressionData = _progression.data

	for goal: Goal in catalog:
		if _completed_goal_ids.has(goal.id):
			continue
		if not is_unlock_goal(goal):
			continue

		if _check_unlock_goal(goal, data):
			_completed_goal_ids[goal.id] = true
			cumulative.total_points_earned += goal.reward_points
			newly_completed.append(goal)

	if newly_completed.size() > 0:
		save_completed()
		save_cumulative()

		for goal: Goal in newly_completed:
			if _on_points_awarded_cb.is_valid():
				_on_points_awarded_cb.call(goal.reward_points)
			if _on_goal_completed_cb.is_valid():
				_on_goal_completed_cb.call(goal)

	return newly_completed


## PORT: web/src/tilt-to-live/GoalManager.ts:894-910
func _check_unlock_goal(goal: Goal, data: ProgressionManager.ProgressionData) -> bool:
	var id: String = goal.target_id
	if id.is_empty():
		return false

	match goal.metric:
		"ship_unlocked":
			return data.unlocked_cursors.has(id)
		"enemy_skin_unlocked":
			return data.unlocked_enemy_skins.has(id)
		"arena_unlocked":
			return data.unlocked_arena_themes.has(id)
		"weapon_fully_upgraded":
			return _is_weapon_fully_upgraded(data.perks, id)
	return false


## True when every numeric perk on the weapon is at max rank 5 and every
## boolean keystone is unlocked. Reads whatever fields the weapon's perks
## carry. PORT: web/src/tilt-to-live/GoalManager.ts:919-926
# PORT-NOTE: WeaponPerks.to_dict() is the `perks[weapon]` view (M7 decision
# (a)); an unknown weapon key is the TS's `undefined` → false (:921).
func _is_weapon_fully_upgraded(perks: ProgressionManager.WeaponPerks, weapon: String) -> bool:
	var all_perks: Dictionary = perks.to_dict()
	if not all_perks.has(weapon):
		return false
	var weapon_perks: Dictionary = SaveStore.read_dict(all_perks, weapon)

	for key: Variant in weapon_perks.keys():
		var k: String = str(key)
		if weapon_perks[k] is bool:
			if not SaveStore.read_bool(weapon_perks, k, false):
				return false
		elif SaveStore.read_int(weapon_perks, k, 0) < 5:  # PORT: :924
			return false
	return true


## The goal metric's current value for this run (run_*), this mode
## (*_survival), or lifetime plus this run (total_*).
## PORT: web/src/tilt-to-live/GoalManager.ts:928-970
# I1: one return per metric arm mirrors the TS switch (LAW 3); 18 returns
# exceeds gdlint's default max-returns 6, same as progression_manager.gd:232-234.
# gdlint:disable=max-returns
func get_metric_value(metric: String, tracker: RunTracker) -> float:
	match metric:
		"run_score":
			return float(tracker.score)
		"run_kills":
			return float(tracker.kills)
		"run_multiplier":
			return tracker.multiplier
		"run_survival":
			return floorf(tracker.survival_time)
		"run_close_calls":
			return float(tracker.close_calls)
		"run_nukes":
			return float(tracker.nukes_detonated)
		"run_vortex_absorbs":
			return float(tracker.vortex_absorbs)
		"run_laser_slices":
			return float(tracker.laser_slices)
		"run_missiles":
			return float(tracker.missiles_fired)
		"run_freeze_shatters":
			return float(tracker.freeze_shatters)
		"run_shield_rams":
			return float(tracker.shield_rams)
		"code_red_survival":
			return floorf(tracker.survival_time) if tracker.mode == "code-red" else 0.0
		"gauntlet_survival":
			return floorf(tracker.survival_time) if tracker.mode == "gauntlet" else 0.0
		# Cumulative Lifetime Metrics:
		"total_kills":
			return float(cumulative.total_kills + tracker.kills)
		"total_survival":
			return float(cumulative.total_survival_time) + floorf(tracker.survival_time)
		"total_points":
			return float(cumulative.total_points_earned)
		"total_score":
			return float(cumulative.total_score + tracker.score)
	return 0.0


# gdlint:enable=max-returns


## PORT: web/src/tilt-to-live/GoalManager.ts:972-982
func reset_all_progress() -> void:
	_completed_goal_ids.clear()
	cumulative = CumulativeStats.new()
	save_completed()
	save_cumulative()
```

- [x] **Step 4: Run to verify they pass** — `tools/run_tests.sh` → `OK: 47/47 scripts (447 tests)`. `gdformat --check`, `gdlint` clean. `grep -n "TASK 3" godot/src/meta/goal_manager.gd` prints nothing.

- [x] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/meta/goal_manager.gd godot/tests/test_goal_manager.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: port goal evaluation for run/cumulative/unlock; next: M9 Task 4"
git log -1 --format=%B
```

---

### Task 4: Run tracker in `RunController` (spec §5.4 step 10)

**Files:**
- Modify: `godot/src/sim/run_controller.gd`, `godot/src/core/game_state_machine.gd`
- Test: `godot/tests/test_run_controller.gd`

**Interfaces:**
- Consumes: `GoalManager` (Tasks 2–3), `GameOptionsManager.MODE_IDS`.
- Produces: `RunController.goals: GoalManager` (assigned after construction), `run_tracker: GoalManager.RunTracker`, `points_earned_this_run: int`, `run_completed_goals: Array[GoalManager.Goal]`.

- [x] **Step 1: Write the failing tests.** In `godot/tests/test_run_controller.gd`:
  - I2: this task's six new tests take the file from 16 to 22 public methods, over gdlint's
    `max-public-methods: 20`. Add `# gdlint:disable=max-public-methods` as line 1 of the file
    (`test_armory_ui.gd:1` precedent).
  - In `before_each` **and** `after_each`, add after the existing `_remove` lines:
    ```gdscript
    	_remove(GoalManager.SAVE_PATH)
    	_remove(SaveStore.corrupt_path_for(GoalManager.SAVE_PATH))
    	_remove(GoalManager.CUMULATIVE_SAVE_PATH)
    	_remove(SaveStore.corrupt_path_for(GoalManager.CUMULATIVE_SAVE_PATH))
    ```
  - In `before_each`, directly after the `_rc = RunController.new(...)` call: `_rc.goals = GoalManager.new(_progression)`.
  - Append:

```gdscript
func test_reset_run_starts_a_fresh_tracker_in_the_active_mode() -> void:
	_rc.run_tracker.kills = 9
	_rc.points_earned_this_run = 4
	_options.settings.mode = Types.GameMode.CODE_RED
	_rc.reset_run(_bounds)
	assert_eq(_rc.run_tracker.kills, 0, "TiltGame.ts:1578-1591")
	assert_eq(_rc.run_tracker.multiplier, 1.0)
	assert_eq(_rc.run_tracker.mode, "code-red", "options.settings.mode (:1579)")
	assert_eq(_rc.points_earned_this_run, 0, ":1566")


func test_weapon_kills_bump_their_tracker_counters() -> void:
	_rc.reset_run(_bounds)
	var kinds: Array[Types.WeaponType] = [
		Types.WeaponType.VORTEX,
		Types.WeaponType.LASER,
		Types.WeaponType.MISSILES,
		Types.WeaponType.FREEZE,
		Types.WeaponType.SHIELD,
		Types.WeaponType.NUKE,
		Types.WeaponType.LIGHTNING,
	]
	for kind: Types.WeaponType in kinds:
		var e: Types.Enemy = Types.Enemy.new()
		e.x = 100.0
		e.y = 100.0
		_rc.handle_enemy_killed(e, kind)
	var t: GoalManager.RunTracker = _rc.run_tracker
	assert_eq(t.vortex_absorbs, 1, "TiltGame.ts:1988-1990")
	assert_eq(t.laser_slices, 1, ":1991-1993")
	assert_eq(t.missiles_fired, 1, ":1994-1996")
	assert_eq(t.freeze_shatters, 1, ":1997-1999")
	assert_eq(t.shield_rams, 1, ":2000-2002")
	assert_eq(t.nukes_detonated, 0, "nuke kills are not counted — only activations")


func test_weapon_activation_counts_nukes_and_sixteen_missiles() -> void:
	_rc.reset_run(_bounds)
	_weapons.on_weapon_activated.call(Types.WeaponType.NUKE)
	_weapons.on_weapon_activated.call(Types.WeaponType.MISSILES)
	_weapons.on_weapon_activated.call(Types.WeaponType.LASER)
	assert_eq(_rc.run_tracker.nukes_detonated, 1, "TiltGame.ts:213-214")
	assert_eq(_rc.run_tracker.missiles_fired, 16, "a fixed 16 per pickup (:216)")


func test_update_syncs_the_tracker_from_scores_and_elapsed() -> void:
	_rc.reset_run(_bounds)
	_scores.stats.score = 1234
	_scores.stats.kills = 7
	_rc.update(1.0 / 120.0, Types.ControlMode.MOUSE, Vector2(200, 200), Vector2.ZERO, Vector2.ZERO)
	assert_eq(_rc.run_tracker.score, _scores.stats.score, "TiltGame.ts:1949")
	assert_eq(_rc.run_tracker.kills, _scores.stats.kills, ":1950")
	assert_eq(_rc.run_tracker.multiplier, _scores.stats.multiplier, ":1951")
	assert_eq(_rc.run_tracker.survival_time, _rc.elapsed, ":1952")
	assert_eq(_rc.run_tracker.close_calls, _scores.stats.close_calls, ":1953")


func test_update_completes_live_total_goals() -> void:
	_rc.reset_run(_bounds)
	_rc.goals.cumulative.total_kills = 99
	_scores.stats.kills = 1
	_rc.update(1.0 / 120.0, Types.ControlMode.MOUSE, Vector2(200, 200), Vector2.ZERO, Vector2.ZERO)
	assert_true(_rc.goals.is_completed("total_kills_100"), "TiltGame.ts:1954 → GoalsHUD.ts:244")


func test_death_evaluates_the_run_and_keeps_the_result() -> void:
	_rc.reset_run(_bounds)
	_rc.run_tracker.score = 1000
	_rc.trigger_player_death()
	var ids: Array[String] = []
	for g: GoalManager.Goal in _rc.run_completed_goals:
		ids.append(g.id)
	assert_eq(ids, ["score_1k"] as Array[String], "TiltGame.ts:2086")
	assert_true(_rc.goals.is_completed("score_1k"))
```

If `_scores.stats.score = 1234` is overwritten inside `update()` before step 8 (it is not — `scores.update(dt)` decays combos, it does not reset score), the sync assertion still holds because it compares against `_scores.stats` after the call. If `Types.Enemy.new()` needs other fields for `handle_enemy_killed` → `swarm.on_enemy_killed`, copy the enemy set-up the existing shield-ram test (`:92`) uses.

- [x] **Step 2: Run to verify they fail** — `collected 46 of 47` (`goals` not a member).

- [x] **Step 3: Implement in `godot/src/sim/run_controller.gd`:**

  a. Members — after `var coins: CoinSystem = null`:

```gdscript
## Milestones. PORT: web/src/tilt-to-live/TiltGame.ts:66 (this.goals)
# PORT-NOTE: assigned after construction (GameRoot._ready) — an eleventh
# constructor parameter would pass gdlint's function-arguments-number: 10.
var goals: GoalManager = null
## Run Milestone Tracker. PORT: web/src/tilt-to-live/TiltGame.ts:83-96
var run_tracker: GoalManager.RunTracker = GoalManager.RunTracker.new()
## PORT: web/src/tilt-to-live/TiltGame.ts:97
var points_earned_this_run: int = 0
## triggerPlayerDeath's `newlyCompleted` (TiltGame.ts:2086).
# PORT-NOTE: a local in the TS, read by the game-over setTimeout closure
# (:2111-2144); kept here so HudController's run_ended handler can read it.
var run_completed_goals: Array[GoalManager.Goal] = []
```

  b. `reset_run` — after `elapsed = 0.0` add `points_earned_this_run = 0  # PORT: web/src/tilt-to-live/TiltGame.ts:1566`. After the `player.set_shield_radius(...)` call add:

```gdscript
	# PORT-NOTE: railProgress (:1575-1576) is not ported — see goals_hud.gd's header.
	# PORT: web/src/tilt-to-live/TiltGame.ts:1578-1591
	run_tracker = GoalManager.RunTracker.new()
	run_tracker.mode = GameOptionsManager.MODE_IDS[options.settings.mode]
```

  and as the last line of `reset_run` (after the `score_changed` emit, which stands for `updateHUD()` :1614):

```gdscript
	# PORT: web/src/tilt-to-live/TiltGame.ts:1615 — goalsHUD.updateLive's
	# evaluation half; see step 8 in update() for the split.
	goals.evaluate_live_total_goals(run_tracker)
```

  c. `update` — replace the block from `# 8. Emit HUD signal` to the end of the function with:

```gdscript
	# 8. Update Run Tracker & Goals HUD
	# PORT: web/src/tilt-to-live/TiltGame.ts:1949-1954
	run_tracker.score = scores.stats.score
	run_tracker.kills = scores.stats.kills
	run_tracker.multiplier = scores.stats.multiplier
	run_tracker.survival_time = elapsed
	run_tracker.close_calls = scores.stats.close_calls
	# PORT-NOTE: goalsHUD.updateLive (:1954, GoalsHUD.ts:242-255) is the
	# evaluation below plus a rail-height write. The height changes only when a
	# goal completes, and every completion reaches GoalsHUD.render() through
	# GameRoot's callbacks, so the sim keeps only the evaluation (spec §5.3).
	# PORT-NOTE: on the death tick this runs after trigger_player_death's
	# evaluate_run has committed the run into goals.cumulative, so total_*
	# metrics count this run twice for this one call and can complete a
	# cumulative goal early. TiltGame.update() does the same (:2086 then :1954).
	# Preserved deliberately (LAW 2); raised in HANDOFF open questions.
	goals.evaluate_live_total_goals(run_tracker)

	# 9. Emit HUD signal
	GameEvents.score_changed.emit(
		scores.stats.score, scores.stats.multiplier, scores.stats.best_score
	)
```

  (Keep the existing `score_changed.emit(...)` arguments exactly as they are in the file — copy them, do not retype.)

  d. `handle_enemy_killed` — delete the `# TODO(M9): runTracker weapon-kill counters …` line above the function; after `swarm.on_enemy_killed(enemy, particles)` and before the `enemy_killed` emit, add:

```gdscript
	# Update weapon kill statistics for milestones. PORT: web/src/tilt-to-live/TiltGame.ts:1986-2003
	match weapon_type:
		Types.WeaponType.VORTEX:
			run_tracker.vortex_absorbs += 1
		Types.WeaponType.LASER:
			run_tracker.laser_slices += 1
		Types.WeaponType.MISSILES:
			run_tracker.missiles_fired += 1
		Types.WeaponType.FREEZE:
			run_tracker.freeze_shatters += 1
		Types.WeaponType.SHIELD:
			run_tracker.shield_rams += 1
```

  e. `trigger_player_death` — after `scores.finalize_game()`:

```gdscript
	# Finalize run goals check (capped at 3 run milestones, plus any cumulative
	# total milestones). PORT: web/src/tilt-to-live/TiltGame.ts:2085-2086
	run_completed_goals = goals.evaluate_run(run_tracker)
```

  f. `_on_weapon_activated` — replace its header comment block and body with:

```gdscript
## Tracks superweapon activation, then relays the pickup to the UI bus.
## PORT: web/src/tilt-to-live/TiltGame.ts:212-218
# PORT-NOTE: missiles count a fixed 16 per pickup (:216), not the launched
# salvo size — preserved deliberately.
func _on_weapon_activated(type: Types.WeaponType) -> void:
	if type == Types.WeaponType.NUKE:
		run_tracker.nukes_detonated += 1
	elif type == Types.WeaponType.MISSILES:
		run_tracker.missiles_fired += 16  # PORT: :216
	GameEvents.weapon_activated.emit(type)
```

  g. `godot/src/core/game_state_machine.gd` — replace `# ported in run_controller.gd::reset_run. TODO(M9): pointsEarnedThisRun.` and the following `# TODO(M9): railProgress and the run tracker.` with:

```gdscript
	# ported in run_controller.gd::reset_run, as are pointsEarnedThisRun (:1566)
	# and the run tracker (:1578-1591); railProgress (:1575-1576) is not ported
	# (goals_hud.gd header).
```

  and replace `# TODO(M9): goalsHUD.updateLive(runTracker) (TiltGame.ts:1615).` with `# PORT-NOTE: goalsHUD.updateLive (:1615) is ported in run_controller.gd::reset_run.`

  h. In `godot/src/core/game_root.gd` `_ready`, directly after the `_run_controller = RunController.new(...)` call, add:

```gdscript
	goals = GoalManager.new()  # PORT: web/src/tilt-to-live/TiltGame.ts:66
	_run_controller.goals = goals
```

  and the member `## Milestones. PORT: web/src/tilt-to-live/TiltGame.ts:66` / `var goals: GoalManager = null` after `var options`. Add the four goal-save removals to `test_main_scene.gd`'s `before_each`/`after_each` now (every main-scene spec now writes goal files on boot's `reset_run` only if a goal completes — none does with defaults, but the removal is the constraint).

- [x] **Step 4: Verify** — `tools/run_tests.sh` → `OK: 47/47 scripts (453 tests)`; `gdformat --check`, `gdlint` clean; `grep -rn "TODO(M9)" godot/src/sim godot/src/core/game_state_machine.gd` prints nothing (the two in `game_root.gd` remain for Task 5; `hud_controller.gd`'s and `run_over_sheet.gd`'s for Task 7).

- [x] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/sim/run_controller.gd godot/src/core/game_state_machine.gd godot/src/core/game_root.gd godot/tests/test_run_controller.gd godot/tests/test_main_scene.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: sync run stats and evaluate goals at step 10; next: M9 Task 5"
git log -1 --format=%B
```

---

### Task 5: `GoalsHUD` — rail, toast, unlock checks, hotkey; wired into `GameRoot`

> **Rewritten 2026-09-23** to interface spec §6.5 on `UiTheme` (the M8.5 system).
> Visual authority: `peril-point-mobile-redesign/Hud.dc.html`. Rulings R8, R10, R11 apply.

**Files:**
- Create: `godot/src/ui/goals_hud.gd`
- Modify: `godot/scenes/main.tscn`, `godot/src/core/game_root.gd`, `godot/src/ui/ui_theme.gd` (I4 — `ICON_RING`)
- Test: `godot/tests/test_goals_hud.gd` (create), `godot/tests/test_main_scene.gd`

**Interfaces:**
- Consumes: `GoalManager` (Tasks 2–3: `set_progression`, `set_callbacks`, `evaluate_unlock_goals`, `get_completed_count`, `get_total_goals_count`, `is_completed`, `catalog`, `Goal.title/reward_points`), `RunController.points_earned_this_run` (Task 4), `GameRoot.goals` (Task 4), `ProgressionManager.add_points`, `UiTheme` (`build`, `px`, `tint`, `flat`, `padded`, `svg_texture`, `sans`, `mono`, `Weight`, `COLOR_*`, `CARD_RADIUS`, `ICON_CHECK`), `HudController.ui_scale_for`.
- Produces: `class_name GoalsHUD extends Control` with `in_menu_mode: bool`, `bind(goal_manager: GoalManager, progression: ProgressionManager, rail_host: Control = null, toast_host: Control = null)`, `check_unlock_goals()`, `set_ui_scale(scale: float, inset: Vector2 = Vector2.ZERO)`, `is_modal_open() -> bool`, `set_menu_mode(in_menu: bool)`, `toggle_collapse()`, `show_goal_toast(goal: GoalManager.Goal)`, `show_message_toast(title: String, subtitle: String, reward_badge: String = "")`, `render()`, `open_all_goals_modal()`, `close_all_goals_modal()`; private hooks Task 6 replaces: `_build_milestones_modal() -> Control`, `_layout_modal()`, `_render_milestones_modal_content()`. Node names `EdgeRail`, `EdgeRailFill`, `GoalToast`, `ToastRow`, `ToastTitle`, `ToastSubtitle`, `ToastReward`, `ToastTimer`, `MilestonesModal`. `GameRoot._on_goal_completed`, `GameRoot._on_goal_points_awarded` (M8: no `get_run_controller()` — tests read `root._run_controller`, `test_main_scene.gd:296` precedent). `main.tscn`: `%GoalsHud`, `%ToastSlot`.

- [x] **Step 1: Class-name check** — rerun Task 2 Step 1's script; `GoalsHUD` must print `false`.

- [x] **Step 2: Write the failing tests** — `godot/tests/test_goals_hud.gd`:

```gdscript
## test_goals_hud.gd
## PORTS: nothing — new file, covers src/ui/goals_hud.gd (interface spec §6.5)
extends GutTest
## Proves the rail, the toast, the unlock check on bind, the menu-mode toggle,
## the M/Escape keys and (Task 6) the Milestones screen.

var _hud: GoalsHUD = null
var _gm: GoalManager = null
var _pm: ProgressionManager = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _remove_saves() -> void:
	for path: String in [
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
		ProgressionManager.SAVE_PATH,
	]:
		_remove(path)
		_remove(SaveStore.corrupt_path_for(path))


func _key(code: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func _node(name: String) -> Node:
	var node: Node = _hud.find_child(name, true, false)
	assert_not_null(node, name)
	return node


func before_each() -> void:
	_remove_saves()
	_gm = GoalManager.new()
	_pm = ProgressionManager.new()
	_hud = GoalsHUD.new()
	add_child_autofree(_hud)


func after_each() -> void:
	_remove_saves()


func test_bind_wires_progression_and_completes_owned_unlocks() -> void:
	_pm.data.unlocked_cursors.append("solar")
	_hud.bind(_gm, _pm)
	assert_true(_gm.is_completed("unlock_ship_solar"), "GoalsHUD.ts:28, :36")
	# B3: bind() runs _init_dom(), which ends in render() and calls
	# check_unlock_goals() BEFORE _setup_listeners() installs the callbacks
	# (GoalsHUD.ts:30-31, :105) — the TS order. A pre-owned unlock completes
	# with no addPoints and no toast; only cumulative.totalPointsEarned moves.
	assert_eq(_pm.data.points, 7331, "no callback installed yet — see PORT-NOTE on bind()")
	assert_false(
		(_node("GoalToast") as Control).visible, "no callback installed yet — see PORT-NOTE"
	)
	assert_eq(_gm.cumulative.total_points_earned, 2, "the goal itself still records the reward")


func test_render_fills_the_rail_by_completion() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k", "kills_15"] as Array[String])
	_gm = GoalManager.new()
	_hud.bind(_gm, _pm)
	var fill: Control = _node("EdgeRailFill") as Control
	assert_almost_eq(fill.anchor_right, 2.0 / 57.0, 0.0001, "frame width × done ÷ total (spec §6.5)")


func test_rail_is_a_line_on_its_hosts_top_edge() -> void:
	var frame: Control = Control.new()
	add_child_autofree(frame)
	_hud.bind(_gm, _pm, frame)
	_hud.set_ui_scale(2.0)
	# B4: the rail hosts under `frame`, not `_hud` — look it up there directly.
	var rail: Control = frame.find_child("EdgeRail", true, false) as Control
	assert_not_null(rail, "EdgeRail")
	assert_eq(rail.get_parent(), frame, "on the arena frame (R8)")
	assert_eq(rail.anchor_left, 0.0, "from the frame's left corner")
	assert_eq(rail.anchor_right, 1.0)
	assert_eq(rail.offset_top, -2.0, "Hud.dc.html: top 11 over the frame's 12, × 2")
	assert_eq(rail.offset_bottom - rail.offset_top, 6.0, "3 px × 2")
	assert_eq(rail.mouse_filter, Control.MOUSE_FILTER_IGNORE, "not tappable (spec §6.5, R11)")
	var fill: ColorRect = frame.find_child("EdgeRailFill", true, false) as ColorRect
	assert_not_null(fill, "EdgeRailFill")
	assert_eq(fill.color, UiTheme.COLOR_ION)


func test_goal_toast_shows_title_reward_and_restarts_its_timer() -> void:
	_hud.bind(_gm, _pm)
	_hud.show_goal_toast(_gm.catalog[0])
	assert_true((_node("GoalToast") as Control).visible)
	assert_eq((_node("ToastTitle") as Label).text, "Rookie Dodger")
	assert_eq((_node("ToastReward") as Label).text, "+1")
	var timer: Timer = _node("ToastTimer") as Timer
	assert_almost_eq(timer.wait_time, 3.0, 0.001, "GoalsHUD.ts:209")
	assert_false(timer.is_stopped())
	timer.timeout.emit()
	assert_false((_node("GoalToast") as Control).visible, ":207")


func test_a_second_toast_replaces_the_first() -> void:
	_hud.bind(_gm, _pm)
	_hud.show_goal_toast(_gm.catalog[0])
	var timer: Timer = _node("ToastTimer") as Timer
	timer.time_left = 0.4
	_hud.show_goal_toast(_gm.catalog[1])
	var toast: Control = _node("GoalToast") as Control
	assert_eq(toast.get_child_count(), 1, "innerHTML is rewritten, not appended (:192)")
	assert_eq((_node("ToastTitle") as Label).text, _gm.catalog[1].title)
	# M9: Review Focus 5 — the second toast restarts the timer, it does not stack.
	assert_almost_eq(timer.time_left, 3.0, 0.001, "restarted, not left counting down")


func test_message_toast_carries_subtitle_and_badge() -> void:
	_hud.bind(_gm, _pm)
	_hud.show_message_toast("TILT CALIBRATED", "Neutral Angle Zeroed ✓", "OK")
	assert_eq((_node("ToastTitle") as Label).text, "TILT CALIBRATED")
	assert_eq((_node("ToastSubtitle") as Label).text, "Neutral Angle Zeroed ✓")
	assert_eq((_node("ToastReward") as Label).text, "OK")
	assert_almost_eq((_node("ToastTimer") as Timer).wait_time, 2.8, 0.001, ":234")


func test_toast_goes_into_its_host_at_content_width() -> void:
	var slot: VBoxContainer = VBoxContainer.new()
	add_child_autofree(slot)
	_hud.bind(_gm, _pm, null, slot)
	# B4: the toast hosts under `slot`, not `_hud` — look it up there directly.
	var toast: Control = slot.find_child("GoalToast", true, false) as Control
	assert_not_null(toast, "GoalToast")
	assert_eq(toast.get_parent(), slot, "under the lives icons (spec §6.5, R8)")
	assert_eq(toast.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN)


func test_menu_mode_hides_the_rail() -> void:
	_hud.bind(_gm, _pm)
	var rail: Control = _node("EdgeRail") as Control
	_hud.set_menu_mode(true)
	assert_false(rail.visible, ":166-175")
	assert_true(_hud.in_menu_mode)
	_hud.set_menu_mode(false)
	assert_true(rail.visible)


func test_m_toggles_and_escape_closes_the_modal() -> void:
	_hud.bind(_gm, _pm)
	_hud._unhandled_input(_key(KEY_M))
	assert_true(_hud.is_modal_open(), ":146-155")
	_hud._unhandled_input(_key(KEY_M))
	assert_false(_hud.is_modal_open())
	_hud._unhandled_input(_key(KEY_M))
	_hud._unhandled_input(_key(KEY_ESCAPE))
	assert_false(_hud.is_modal_open(), ":156-158")


func test_rail_and_toast_never_eat_touches() -> void:
	_hud.bind(_gm, _pm)
	assert_eq(_hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_node("GoalToast") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_node("EdgeRailFill") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
```

In `godot/tests/test_main_scene.gd`: I2 — this task's three new tests take the file from 20 to 23
public methods, over gdlint's `max-public-methods: 20`. Add `# gdlint:disable=max-public-methods` as
line 1 of the file (`test_armory_ui.gd:1` precedent), if it is not already there. Then append:

```gdscript
func test_an_armory_unlock_completes_its_goal_through_game_root() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	watch_signals(GameEvents)
	root.progression.data.unlocked_cursors.append("solar")
	var armory: ArmoryUI = root.find_child("Armory", true, false) as ArmoryUI
	armory.state_changed.emit()
	assert_true(root.goals.is_completed("unlock_ship_solar"), "TiltGame.ts:2358 → GoalsHUD.ts:264")
	assert_eq(root.progression.data.points, 7331 + 2, "TiltGame.ts:206")
	assert_eq(root._run_controller.points_earned_this_run, 2, "TiltGame.ts:202")
	assert_true((root.find_child("GoalToast", true, false) as Control).visible, ":203")
	assert_signal_emitted_with_parameters(GameEvents, "goal_completed", ["unlock_ship_solar"])


func test_rail_and_toast_live_in_the_hud() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var rail: Node = root.find_child("EdgeRail", true, false)
	assert_eq(String(rail.get_parent().name), "Frame", "interface spec §6.5: the frame's top edge")
	var toast: Node = root.find_child("GoalToast", true, false)
	assert_eq(String(toast.get_parent().name), "ToastSlot", "under the lives icons")


func test_calibrate_reports_through_a_message_toast() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var ok: bool = root.calibrate_gyro()
	var title: Label = root.find_child("ToastTitle", true, false) as Label
	var subtitle: Label = root.find_child("ToastSubtitle", true, false) as Label
	# PORT: web/src/tilt-to-live/TiltGame.ts:2335, :2337
	assert_eq(title.text, "TILT CALIBRATED" if ok else "GYRO SENSOR")
	assert_eq(
		subtitle.text, "Neutral Angle Zeroed ✓" if ok else "Sensor Unavailable or Blocked"
	)
```

- [x] **Step 3: Run to verify they fail** — `tools/run_tests.sh` → `collected 47 of 48` (`test_goals_hud.gd`: `GoalsHUD` unknown). `test_main_scene.gd` parses (M8: it reads `root._run_controller` directly, already a member since Task 4) but its three new tests fail their assertions until `goals_hud.gd` and the `GameRoot` wiring below land.

- [x] **Step 4: Implement.** First, I4: add the message toast's ion ring to `godot/src/ui/ui_theme.gd`,
  after `ICON_CHECK`:

```gdscript
## DIVERGENCE(UI-SYSTEM): Hud.dc.html — message toast ring. PORT: web/src/tilt-to-live/GoalsHUD.ts:217-220
const ICON_RING: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 14 14" fill="none">'
	+ '<circle cx="7" cy="7" r="5" stroke="#5B8CFF" stroke-width="1.5"/>'
	+ '<circle cx="7" cy="7" r="2" fill="#5B8CFF"/></svg>'
)
```

  Then implement `godot/src/ui/goals_hud.gd`:

```gdscript
## goals_hud.gd
## PORTS: web/src/tilt-to-live/GoalsHUD.ts (488 lines, source commit 7be9614)
class_name GoalsHUD
extends Control
## The milestone rail, the completion toast and the full Milestones screen.
##
## DIVERGENCE(UI-SYSTEM): Hud.dc.html (rail, toast) and Milestones.dc.html (the
## screen) are the visual authority (interface spec §6.5). Every board literal
## is a constant here; tokens come from UiTheme.
##
## PORT-NOTE: initDOM() (:59-106) appends three elements to the game container.
## Here the rail goes on the HUD's arena frame and the toast into the HUD's
## toast slot, where spec §6.5 places them; bind() takes those two hosts (M9
## plan R8) and, given none (tests), hangs both off this node. The Milestones
## screen is this node's own child.
##
## PORT-NOTE: updateLive() (:242-255) is split. Its evaluateLiveTotalGoals call
## is sim work and lives in RunController.update step 8 (spec §5.4 step 10); its
## rail write only changes on a completion, and every completion reaches
## render() through GameRoot's callbacks, so render() carries it.
##
## PORT-NOTE: TiltGame's second left rail (TiltGame.ts:1058-1078, railProgress at
## :2217-2225) is not ported (M9 plan R2).
##
## PORT-NOTE: bindGameOverClicks (:129-140) lives in RunOverSheet, which owns
## the run-over rows (M9 plan R1); HudController routes its signal to
## GameRoot.open_all_goals_modal().

## Rail. DIVERGENCE(UI-SYSTEM): Hud.dc.html — a 3 px ion line at top 11 over the
## frame's top 12, i.e. rising 1 px above the frame's edge.
const RAIL_HEIGHT: int = 3
const RAIL_RISE: int = 1
## Toast. DIVERGENCE(UI-SYSTEM): Hud.dc.html — Card at 92% panel, pad 9/12, gap 9,
## title 13/500, reward Mono 12 flare; spec §6.5 — message subtitle muted 12.
const TOAST_ALPHA: float = 0.92
const TOAST_PAD_Y: int = 9
const TOAST_PAD_X: int = 12
const TOAST_GAP: int = 9
const TOAST_TITLE_SIZE: int = 13
const TOAST_REWARD_SIZE: int = 12
const TOAST_SUBTITLE_SIZE: int = 12
## PORT: web/src/tilt-to-live/GoalsHUD.ts:209, :234
const GOAL_TOAST_SECONDS: float = 3.0
const MESSAGE_TOAST_SECONDS: float = 2.8
# I4: the message toast's ion ring (GoalsHUD.ts:217-220) lives on UiTheme as
# ICON_RING, next to ICON_CHECK (interface spec §4.1 — no file keeps a
# private copy of a token hex). See this task's UiTheme step below.

## True while the menu is up; the rail hides. PORT: web/src/tilt-to-live/GoalsHUD.ts:16
var in_menu_mode: bool = false

var _goal_manager: GoalManager = null  # PORT: :9
var _progression: ProgressionManager = null  # PORT: :10
var _rail: Control = null  # PORT: :12 (railEl)
var _rail_fill: ColorRect = null
var _toast: PanelContainer = null  # PORT: :13 (toastContainerEl)
var _milestones_modal: Control = null  # PORT: :14 (milestonesModalEl)
var _toast_timer: Timer = null  # PORT: :17 (completedToastTimer)
var _is_evaluating_unlock_goals: bool = false  # PORT: :18
var _ui_scale: float = 1.0
var _inset: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.build(_ui_scale)


## setupHotkey. PORT: web/src/tilt-to-live/GoalsHUD.ts:143-160
# PORT-NOTE: the INPUT/TEXTAREA guard (:147-150) has nothing to guard — the port
# has no text fields. Key repeats are ignored, as GameRoot's b/u keys ignore them.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo:
		return
	if (
		key.keycode == KEY_M
		and not key.ctrl_pressed
		and not key.meta_pressed
		and not key.alt_pressed
	):
		if is_modal_open():
			close_all_goals_modal()
		else:
			open_all_goals_modal()
	elif key.keycode == KEY_ESCAPE and is_modal_open():
		close_all_goals_modal()


## The constructor. PORT: web/src/tilt-to-live/GoalsHUD.ts:20-37
## `rail_host` / `toast_host` are the HUD's arena frame and toast slot (R8).
# PORT-NOTE(B3): _init_dom() ends in render(), which calls check_unlock_goals()
# (:30-31, :105) before _setup_listeners() installs the callbacks (:109-115) —
# the TS order. Any unlock the player already owns completes here silently: no
# addPoints, no toast, only cumulative.totalPointsEarned moves. The explicit
# check_unlock_goals() below (:34-36) runs after the callbacks are installed
# but is a no-op — the goal is already completed. Preserved deliberately
# (LAW 2); see Open question 4.
func bind(
	goal_manager: GoalManager,
	progression: ProgressionManager,
	rail_host: Control = null,
	toast_host: Control = null
) -> void:
	_goal_manager = goal_manager
	_progression = progression

	# Wire progression into GoalManager here — this is the one place that
	# receives both managers (:24-28).
	_goal_manager.set_progression(_progression)

	_init_dom(rail_host if rail_host != null else self, toast_host if toast_host != null else self)
	_setup_listeners()

	# Catch unlocks the player already owned (:34-36).
	check_unlock_goals()


## Evaluates the unlock-family goals, guarded against the re-entry its own
## callbacks cause (they call render(), which calls this).
## PORT: web/src/tilt-to-live/GoalsHUD.ts:49-57
func check_unlock_goals() -> void:
	if _is_evaluating_unlock_goals:
		return
	_is_evaluating_unlock_goals = true
	_goal_manager.evaluate_unlock_goals()
	_is_evaluating_unlock_goals = false


## Scales the rail and the screen (HudController.ui_scale_for's value). `inset`
## is GameRoot.arena_origin; on mobile the screen's content is pulled in by it,
## as the Armory's is.
func set_ui_scale(scale: float, inset: Vector2 = Vector2.ZERO) -> void:
	_ui_scale = scale
	_inset = inset
	theme = UiTheme.build(scale)
	_layout()


## PORT: web/src/tilt-to-live/GoalsHUD.ts:162-164
func is_modal_open() -> bool:
	return _milestones_modal != null and _milestones_modal.visible


## PORT: web/src/tilt-to-live/GoalsHUD.ts:166-175
func set_menu_mode(in_menu: bool) -> void:
	in_menu_mode = in_menu
	if _rail != null:
		_rail.visible = not in_menu


## Legacy support: toggle modal. PORT: web/src/tilt-to-live/GoalsHUD.ts:177-184
func toggle_collapse() -> void:
	if is_modal_open():
		close_all_goals_modal()
	else:
		open_all_goals_modal()


## PORT: web/src/tilt-to-live/GoalsHUD.ts:189-210
func show_goal_toast(goal: GoalManager.Goal) -> void:
	if _toast == null:
		return
	_fill_toast(UiTheme.ICON_CHECK, goal.title, "", "+%d" % goal.reward_points)
	_toast.visible = true
	_toast_timer.start(GOAL_TOAST_SECONDS)


## PORT: web/src/tilt-to-live/GoalsHUD.ts:212-235
func show_message_toast(title: String, subtitle: String, reward_badge: String = "") -> void:
	if _toast == null:
		return
	_fill_toast(UiTheme.ICON_RING, title, subtitle, reward_badge)
	_toast.visible = true
	_toast_timer.start(MESSAGE_TOAST_SECONDS)


## PORT: web/src/tilt-to-live/GoalsHUD.ts:257-283
# PORT-NOTE: the notches (:273-274) and the hover tag (:275-277) are not drawn:
# Hud.dc.html's rail is a bare line (DIVERGENCE(UI-SYSTEM), spec §6.5).
func render() -> void:
	if _rail == null:
		return

	# Every Armory change reaches render(), which makes this the place newly
	# unlocked ships/skins/arenas/weapons are caught (:260-264).
	check_unlock_goals()

	var completed: int = _goal_manager.get_completed_count()
	var total: int = _goal_manager.get_total_goals_count()
	var pct: float = float(completed) / float(total) if total > 0 else 0.0
	_rail_fill.anchor_right = pct  # DIVERGENCE(UI-SYSTEM): Hud.dc.html — width, not height

	if is_modal_open():
		_render_milestones_modal_content()


## Full Milestones Screen. PORT: web/src/tilt-to-live/GoalsHUD.ts:289-303
# PORT-NOTE: the close button's listener (:295-297) is connected once, when the
# screen is built. The backdrop listener (:298-302) has nothing to hang on: the
# screen is full-screen (Milestones.dc.html) — M9 plan R11.
func open_all_goals_modal() -> void:
	if _milestones_modal == null:
		return
	_render_milestones_modal_content()
	_milestones_modal.visible = true


## PORT: web/src/tilt-to-live/GoalsHUD.ts:305-309
func close_all_goals_modal() -> void:
	if _milestones_modal != null:
		_milestones_modal.visible = false


## PORT: web/src/tilt-to-live/GoalsHUD.ts:59-106
func _init_dom(rail_host: Control, toast_host: Control) -> void:
	# 1. The rail. PORT: :61-80
	_rail = Control.new()
	_rail.name = "EdgeRail"
	# DIVERGENCE(UI-SYSTEM): Hud.dc.html — not tappable (spec §6.5; R11).
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_host.add_child(_rail)
	_rail_fill = ColorRect.new()
	_rail_fill.name = "EdgeRailFill"
	_rail_fill.color = UiTheme.COLOR_ION  # DIVERGENCE(UI-SYSTEM): Hud.dc.html
	_rail_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_fill.anchor_bottom = 1.0
	_rail.add_child(_rail_fill)

	# 2. Milestone Complete Toast. PORT: :83-92
	_toast = PanelContainer.new()
	_toast.name = "GoalToast"
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast_host.add_child(_toast)
	_toast_timer = Timer.new()
	_toast_timer.name = "ToastTimer"
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(_on_toast_timer_timeout)
	add_child(_toast_timer)

	# 3. Full Milestones Screen. PORT: :95-103
	_milestones_modal = _build_milestones_modal()
	add_child(_milestones_modal)

	_layout()
	# PORT-NOTE(B3): render() -> check_unlock_goals() runs here, before bind()
	# calls _setup_listeners() — see bind()'s PORT-NOTE.
	render()


## PORT: web/src/tilt-to-live/GoalsHUD.ts:108-141
# PORT-NOTE: the rail's click and Enter/Space listeners (:118-126) are not
# connected — spec §6.5 rules the rail not tappable (R11).
func _setup_listeners() -> void:
	_goal_manager.set_callbacks(_handle_goal_completed, _on_points_awarded)


## PORT: web/src/tilt-to-live/GoalsHUD.ts:237-240
func _handle_goal_completed(goal: GoalManager.Goal) -> void:
	show_goal_toast(goal)
	render()


## The :111-114 arrow function.
func _on_points_awarded(pts: int) -> void:
	_progression.add_points(pts)
	render()


func _on_toast_timer_timeout() -> void:
	_toast.visible = false  # PORT: :206-208


func _layout() -> void:
	if _rail == null:
		return
	var s: float = _ui_scale
	_rail.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_rail.offset_left = 0.0
	_rail.offset_right = 0.0
	_rail.offset_top = -UiTheme.px(RAIL_RISE, s)
	_rail.offset_bottom = _rail.offset_top + UiTheme.px(RAIL_HEIGHT, s)
	_layout_modal()


## Rewrites the toast's card, as the TS rewrites its innerHTML (:192-200, :215-225).
# DIVERGENCE(UI-SYSTEM): Hud.dc.html — one Card (92% panel, line 1 px, r 6);
# the TS's coloured left accent (game.css:3667) is not drawn.
func _fill_toast(icon_svg: String, title: String, subtitle: String, badge: String) -> void:
	for child: Node in _toast.get_children():
		_toast.remove_child(child)
		child.queue_free()
	var s: float = _ui_scale
	_toast.add_theme_stylebox_override(
		"panel",
		UiTheme.padded(
			UiTheme.flat(
				UiTheme.tint(UiTheme.COLOR_PANEL, TOAST_ALPHA),
				UiTheme.COLOR_LINE,
				UiTheme.px(UiTheme.CARD_RADIUS, s)
			),
			UiTheme.px(TOAST_PAD_X, s),
			UiTheme.px(TOAST_PAD_Y, s)
		)
	)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ToastRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiTheme.px(TOAST_GAP, s))
	_toast.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.texture = UiTheme.svg_texture(icon_svg, s)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(
		_label("ToastTitle", title, UiTheme.sans(UiTheme.Weight.MEDIUM), TOAST_TITLE_SIZE, UiTheme.COLOR_TEXT)
	)
	if not subtitle.is_empty():
		row.add_child(
			_label(
				"ToastSubtitle",
				subtitle,
				UiTheme.sans(UiTheme.Weight.REGULAR),
				TOAST_SUBTITLE_SIZE,
				UiTheme.COLOR_TEXT_MUTED
			)
		)
	if not badge.is_empty():
		row.add_child(
			_label(
				"ToastReward",
				badge,
				UiTheme.mono(UiTheme.Weight.REGULAR),
				TOAST_REWARD_SIZE,
				UiTheme.COLOR_FLARE
			)
		)


## A one-off label at a board size (scaled), font and colour.
# M7: `font_size`, not `size` — `size` shadows Control.size (SHADOWED_VARIABLE_BASE_CLASS).
func _label(label_name: String, content: String, font: Font, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.text = content
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", UiTheme.px(font_size, _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Task 6 replaces this. PORT: web/src/tilt-to-live/GoalsHUD.ts:95-103
func _build_milestones_modal() -> Control:
	var screen: ColorRect = ColorRect.new()
	screen.name = "MilestonesModal"
	screen.color = UiTheme.COLOR_SHELL
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	return screen


## Task 6 replaces this.
func _layout_modal() -> void:
	pass


## Task 6 replaces this. PORT: web/src/tilt-to-live/GoalsHUD.ts:311-487
func _render_milestones_modal_content() -> void:
	pass
```

  Run `gdformat godot/src/ui/goals_hud.gd godot/tests/test_goals_hud.gd` once (new files — it wraps the long `row.add_child(_label(...))` line).

- [x] **Step 5: Scene** — in `godot/scenes/main.tscn`:
  - Add `[ext_resource type="Script" path="res://src/ui/goals_hud.gd" id="11"]` after the id `"10"` line and bump `load_steps=10` → `load_steps=11`.
  - Give the HUD's toast slot a unique name — the `ToastSlot` node gains `unique_name_in_owner = true` as its first property.
  - Insert **after the `GameOverPanel` node and before the `Armory` instance** (the screen then draws over Run over and under the Armory):

```
[node name="GoalsHud" type="Control" parent="CanvasLayer"]
unique_name_in_owner = true
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("11")
```

- [x] **Step 6: `GameRoot` wiring** (`godot/src/core/game_root.gd`):
  - After `@onready var _armory: ArmoryUI = %Armory` add:
    ```gdscript
    @onready var _goals_hud: GoalsHUD = %GoalsHud
    @onready var _hud_frame: Control = %Frame
    @onready var _toast_slot: Control = %ToastSlot
    ```
  - After `_armory.calibrate_requested.connect(calibrate_gyro)`:
    ```gdscript
    	# PORT: web/src/tilt-to-live/TiltGame.ts:186
    	_goals_hud.bind(goals, progression, _hud_frame, _toast_slot)
    	# Goal completion & point reward listeners. These override the ones
    	# GoalsHUD.bind installed, as TiltGame.ts:200-209 overrides GoalsHUD.ts:109-115 (R4).
    	goals.set_callbacks(_on_goal_completed, _on_goal_points_awarded)
    ```
  - `calibrate_gyro()`: replace its body and the `TODO(M9)` sentence of its comment. The comment becomes `# PORT-NOTE: the TS awaits the permission promise; request_permission_and_start()` / `# is synchronous here (see _ready). updateHUD (:2339) is signal-driven here.` and the body:
    ```gdscript
    	var success: bool = _tilt.request_permission_and_start()
    	if success:
    		_tilt.calibrate_current_position()
    		_goals_hud.show_message_toast("TILT CALIBRATED", "Neutral Angle Zeroed ✓")  # PORT: :2335
    	else:
    		_goals_hud.show_message_toast("GYRO SENSOR", "Sensor Unavailable or Blocked")  # PORT: :2337
    	return success
    ```
  - In `resize_canvas()`, after the `_armory.set_ui_scale(...)` line: `_goals_hud.set_ui_scale(HudController.ui_scale_for(viewport), arena_origin)`.
  - `_on_run_ended`: add `_goals_hud.render()  # PORT: web/src/tilt-to-live/TiltGame.ts:2146` after the phase line.
  - `_on_armory_state_changed`: add `_goals_hud.render()` as its first line; in its PORT-NOTE replace `goalsHUD.render (:2358) is M9's;` with `goalsHUD.render (:2358) is the first call below;`.
  - `_on_armory_closed`: replace `# TODO(M9): goalsHUD.render (:2383). TODO(M11): menu.render (:2384).` with `_goals_hud.render()  # PORT: :2383` then `# TODO(M11): menu.render (:2384).`.
  - M8: no new public accessor for `_run_controller` — the Milestones wiring (and its tests) read
    `root._run_controller` directly (`test_main_scene.gd:296` precedent, LAW 4: nothing new).
  - Private methods after `_on_run_ended` (CONVENTIONS §2 — private section):
    ```gdscript
    ## PORT: web/src/tilt-to-live/TiltGame.ts:200-204 (the onGoalCompleted callback)
    func _on_goal_completed(goal: GoalManager.Goal) -> void:
    	_run_controller.points_earned_this_run += goal.reward_points
    	_goals_hud.show_goal_toast(goal)
    	GameEvents.goal_completed.emit(goal.id)  # spec §5.3; M9 plan R5


    ## PORT: web/src/tilt-to-live/TiltGame.ts:205-208 (the onPointsAwarded callback)
    func _on_goal_points_awarded(pts: int) -> void:
    	progression.add_points(pts)
    	_goals_hud.render()
    ```

- [x] **Step 7: Glyph check** — the calibrate subtitle carries `✓` (U+2713). Run `"$GODOT" --headless --path godot -s` on a throwaway script in the scratchpad that prints `UiTheme.sans(UiTheme.Weight.REGULAR).has_char(0x2713)`, or add the one-line assert to `test_ui_theme.gd` temporarily and remove it. If it prints `false`, keep the string (LAW 2) and add to `## Open questions` below: "Plex Sans has no ✓; the calibrate toast renders it with the fallback font". Do not change the text.

- [x] **Step 8: Verify** — `tools/run_tests.sh` → `OK: 48/48 scripts (466 tests)` (Task 4's 453 + 10 in `test_goals_hud.gd` + 3 in `test_main_scene.gd`); `gdformat --check godot/src godot/tests` (`86 files would be left unchanged`), `gdlint godot/src godot/tests` clean; `grep -rn "TODO(M9)" godot/src/core/` prints nothing; `grep -rniE "ff4757" godot/src/ui/` prints nothing; `"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR"` prints `0`.

- [x] **Step 9: Commit**

```bash
git checkout godot/project.godot
git add godot/src/ui/goals_hud.gd godot/src/ui/goals_hud.gd.uid godot/src/ui/ui_theme.gd godot/src/core/game_root.gd godot/scenes/main.tscn godot/tests/test_goals_hud.gd godot/tests/test_goals_hud.gd.uid godot/tests/test_main_scene.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: add the milestone rail and toast to the HUD; next: M9 Task 6"
git log -1 --format=%B
```

---

### Task 6: `GoalsHUD` — the Milestones screen (`Milestones.dc.html`)

> **Rewritten 2026-09-23** to interface spec §6.5 on `UiTheme`. Rulings R10, R11 apply.

**Files:**
- Modify: `godot/src/ui/goals_hud.gd` (replace the three `Task 6 replaces this` members; add constants and node references), `godot/src/ui/ui_theme.gd` (one icon constant)
- Test: `godot/tests/test_goals_hud.gd` (append)

**Interfaces:**
- Consumes: Task 5's `_ui_scale`, `_inset`, `_label`; `GoalManager.is_completed/is_unlock_goal/is_total_goal/get_metric_value/catalog`; `UiTheme` (`text`, `caps`, `group_digits`, `px`, `flat`, `padded`, `tint`, `svg_texture`, `sans`, `mono`, `ICON_BACK`, `COLOR_*`, `TEXT_FAINT`, `POINTS_UNIT`, `DONE_CARD`, `CARD_RADIUS`, `TOUCH_TARGET`; variations `TitleText`, `BodyText`, `MonoFaintText`, `MonoText`, `PointsText`, `CapsText`, `FlatIconButton`).
- Produces: `UiTheme.ICON_MARK`. Node names `ScreenMargin`, `HeaderMargin`, `Header`, `BackButton`, `TitleLabel`, `CounterLabel`, `CounterDenomLabel`, `ProgressTrack`, `ProgressFill`, `HeaderPointsLabel`, `HeaderPointsUnit`, `HeaderRule`, `BodyMargin`, `TierColumns`, `Tier_Score|Combat|Mastery` each with `TierName`, `TierCount`, `TierScroll`, `TierCards`, `TierFade`; cards `MilestoneCard_<goal id>` containing `MarkBox`, `NameLabel`, `GoalLabel`, optional `BarTrack`/`BarFill`, `PointsLabel`.

- [x] **Step 1: Write the failing tests.** I2: this task's 14 new tests take `test_goals_hud.gd`
  from 12 to 26 public methods, over gdlint's `max-public-methods: 20`. Add
  `# gdlint:disable=max-public-methods` as line 1 of the file (`test_armory_ui.gd:1` precedent).
  Then append:

```gdscript
func _open() -> Control:
	_hud.bind(_gm, _pm)
	_hud.open_all_goals_modal()
	await get_tree().process_frame
	return _hud.find_child("MilestonesModal", true, false) as Control


func _text(name: String) -> String:
	return (_node(name) as Label).text


func _card(id: String) -> Control:
	return _hud.find_child("MilestoneCard_" + id, true, false) as Control


## A GoalsHUD in an explicit-size host (the headless root snaps to 64×64 — M8.5 lesson).
func _hosted(size: Vector2, scale: float) -> GoalsHUD:
	var host: Control = Control.new()
	host.size = size
	add_child_autofree(host)
	var hud: GoalsHUD = GoalsHUD.new()
	host.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.bind(_gm, _pm)
	hud.set_ui_scale(scale)
	hud.open_all_goals_modal()
	return hud


func _assert_screen_fits(size: Vector2, scale: float) -> void:
	var hud: GoalsHUD = _hosted(size, scale)
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: Control = hud.find_child("MilestonesModal", true, false) as Control
	var outside: Array[String] = UiChecks.outside(screen, screen.get_global_rect())
	assert_true(outside.is_empty(), "fits %s: %s" % [size, outside])
	var short: Array[String] = UiChecks.short_buttons(screen, UiTheme.TOUCH_TARGET * scale)
	assert_true(short.is_empty(), "rule 05 at %s: %s" % [size, short])
	var header: Node = hud.find_child("Header", true, false)
	assert_true(UiChecks.overlapping_siblings(header).is_empty(), "header at %s" % size)
	for tier: String in ["Score", "Combat", "Mastery"]:
		var column: Control = hud.find_child("Tier_" + tier, true, false) as Control
		assert_gt(column.size.x, 0.0, "%s column has width at %s" % [tier, size])


func test_header_shows_counter_progress_and_points() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	assert_eq(_text("TitleLabel"), "Milestones")
	assert_eq(_text("CounterLabel"), "1", "GoalsHUD.ts:367")
	assert_eq(_text("CounterDenomLabel"), "/57")
	assert_eq(_text("HeaderPointsLabel"), "7,331", ":372 toLocaleString")
	assert_eq(_text("HeaderPointsUnit"), "PTS", "Milestones.dc.html caps unit")
	var fill: Control = _node("ProgressFill") as Control
	assert_almost_eq(fill.anchor_right, 0.02, 0.0001, "round(1/57*100) = 2 (:317)")


func test_three_tier_columns_with_their_counts() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["kills_15"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	var names: Array[String] = []
	var counts: Array[String] = []
	for tier: String in ["Score", "Combat", "Mastery"]:
		var group: Control = _hud.find_child("Tier_" + tier, true, false) as Control
		assert_not_null(group, tier)
		var tier_name: Label = group.find_child("TierName", true, false) as Label
		assert_true(tier_name.uppercase, "caps label")
		names.append(tier_name.text)
		counts.append((group.find_child("TierCount", true, false) as Label).text)
	assert_eq(names, ["Score", "Combat", "Mastery"] as Array[String], ":356-360")
	assert_eq(counts, ["0 of 9", "1 of 17", "0 of 31"] as Array[String], ":384-391")
	var score_name: Label = _hud.find_child("Tier_Score", true, false).find_child(
		"TierName", true, false
	) as Label
	assert_eq(score_name.get_theme_color("font_color"), UiTheme.COLOR_ION, ":357 tint")


func test_open_goals_come_before_done_goals() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	var cards: Node = _hud.find_child("Tier_Score", true, false).find_child("TierCards", true, false)
	var last: Node = cards.get_child(cards.get_child_count() - 1)
	assert_eq(String(last.name), "MilestoneCard_score_1k", "done last (interface spec §6.5)")
	assert_ne(String(cards.get_child(0).name), "MilestoneCard_score_1k")


func test_done_card_shows_description_and_no_bar() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	var card: Control = _card("score_1k")
	assert_eq((card.find_child("GoalLabel", true, false) as Label).text, "Reach 1,000 score in a run")
	assert_null(card.find_child("BarTrack", true, false), ":424-439")
	var box: StyleBoxFlat = (card as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.bg_color, UiTheme.DONE_CARD, "Milestones.dc.html done card")
	var pts: Label = card.find_child("PointsLabel", true, false) as Label
	assert_eq(pts.get_theme_color("font_color"), UiTheme.TEXT_FAINT, "done points are faint")


func test_total_goal_shows_live_progress() -> void:
	_gm.cumulative.total_kills = 40
	await _open()
	var card: Control = _card("total_kills_100")
	assert_eq((card.find_child("GoalLabel", true, false) as Label).text, "40 / 100", ":458-460")
	var fill: Control = card.find_child("BarFill", true, false) as Control
	assert_almost_eq(fill.anchor_right, 0.40, 0.0001, ":420-422")


func test_open_run_goal_shows_description_and_no_bar() -> void:
	await _open()
	var card: Control = _card("score_1k")
	assert_eq((card.find_child("GoalLabel", true, false) as Label).text, "Reach 1,000 score in a run")
	assert_null(card.find_child("BarTrack", true, false), "interface spec §6.5 (R10)")


func test_unlock_card_has_no_bar() -> void:
	await _open()
	assert_null(_card("unlock_ship_solar").find_child("BarTrack", true, false), ":444-455")


func test_back_button_closes_the_screen() -> void:
	var screen: Control = await _open()
	(_node("BackButton") as Button).pressed.emit()
	assert_false(screen.visible, ":484-486")


func test_render_refreshes_an_open_screen() -> void:
	await _open()
	_gm.cumulative.total_kills = 70
	_hud.render()
	var card: Control = _card("total_kills_100")
	assert_eq((card.find_child("GoalLabel", true, false) as Label).text, "70 / 100", ":280-282")


func test_screen_fits_the_board_frame() -> void:
	await _assert_screen_fits(Vector2(844, 390), 1.0)


func test_screen_fits_the_a55() -> void:
	await _assert_screen_fits(Vector2(2340, 1080), 1080.0 / 390.0)


func test_screen_fits_a_desktop_window() -> void:
	await _assert_screen_fits(Vector2(1280, 720), HudController.ui_scale_for(Vector2(1280, 720)))


func test_long_text_stays_on_one_line() -> void:
	var hud: GoalsHUD = _hosted(Vector2(844, 390), 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	for node: Node in hud.find_children("MilestoneCard_*", "PanelContainer", true, false):
		var card: Control = node as Control
		assert_almost_eq(card.size.y, 58.0, 0.5, "%s stays 58 px (one line each)" % card.name)
	var goal: Label = hud.find_child("GoalLabel", true, false) as Label
	assert_eq(goal.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "rule 03")


func test_screen_blocks_taps_but_lets_columns_scroll() -> void:
	var screen: Control = await _open()
	assert_eq(screen.mouse_filter, Control.MOUSE_FILTER_STOP, "nothing under it takes the tap")
	var scroll: Node = _hud.find_child("TierScroll", true, false)
	# B5: ScrollContainer's own internal scrollbars (mouse_filter STOP) are also
	# under `scroll` — walk from its content node (TierCards) down, not from the
	# ScrollContainer itself, so the assertion never inspects them.
	var content: Node = scroll.find_child("TierCards", false, false)
	var nodes: Array[Node] = [content]
	nodes.append_array(content.find_children("*", "Control", true, false))
	for node: Node in nodes:
		var control: Control = node as Control
		assert_ne(control.mouse_filter, Control.MOUSE_FILTER_STOP, "%s must pass drags" % node.name)
```

- [x] **Step 2: Run to verify they fail** — `tools/run_tests.sh` does not print `OK`; the 14 new tests fail on missing nodes (`TitleLabel` null, etc.).

- [x] **Step 3: Add the mark icon to `godot/src/ui/ui_theme.gd`**, after `ICON_CHECK`:

```gdscript
## DIVERGENCE(UI-SYSTEM): Milestones.dc.html — done mark check (void stroke)
const ICON_MARK: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="11" height="11" viewBox="0 0 11 11" fill="none">'
	+ '<path d="M1.5 5.8 L4.2 8.5 L9.5 2.8" stroke="#08090E" stroke-width="1.9" '
	+ 'stroke-linecap="round" stroke-linejoin="round"/></svg>'
)
```

- [x] **Step 4: Implement in `goals_hud.gd`.** Constants after `MESSAGE_TOAST_SECONDS`:

```gdscript
## Screen. DIVERGENCE(UI-SYSTEM): Milestones.dc.html — header padding 8/28/8/24
## and gap 12 (the Armory's), counter Mono 13, track 120×4 r2 with 8 px side
## margins, the points figure's 4 px gap to its unit, body padding 12/28/0/24,
## column gap 14, column stack gap 6, heading gap 10, card 58 tall with padding
## 0 12 and gap 11, mark 20 r4, content gap 3, bar 3 r2 with a 1 px top margin,
## points Mono 12/500, bottom fade 40.
const HEADER_PAD_Y: int = 8
const HEADER_PAD_RIGHT: int = 28
const HEADER_PAD_LEFT: int = 24
const HEADER_GAP: int = 12
const COUNTER_SIZE: int = 13
const TRACK_WIDTH: int = 120
const TRACK_HEIGHT: int = 4
const TRACK_RADIUS: int = 2
const TRACK_MARGIN: int = 8
const POINTS_GAP: int = 4
const BODY_PAD_TOP: int = 12
const BODY_PAD_RIGHT: int = 28
const BODY_PAD_LEFT: int = 24
const COLUMN_GAP: int = 14
const STACK_GAP: int = 6
const HEADING_GAP: int = 10
const CARD_HEIGHT: int = 58
const CARD_PAD_X: int = 12
const CARD_GAP: int = 11
const MARK_SIZE: int = 20
const MARK_RADIUS: int = 4
const CONTENT_GAP: int = 3
const BAR_HEIGHT: int = 3
const BAR_RADIUS: int = 2
const BAR_TOP: int = 1
const CARD_POINTS_SIZE: int = 12
const FADE_HEIGHT: int = 40
## Tier order and tints. PORT: web/src/tilt-to-live/GoalsHUD.ts:356-360 (the
## hexes are UiTheme's ion, plasma and flare)
const TIERS: Array[String] = ["Score", "Combat", "Mastery"]
const TIER_TINTS: Dictionary[String, Color] = {
	"Score": UiTheme.COLOR_ION,
	"Combat": UiTheme.COLOR_PLASMA,
	"Mastery": UiTheme.COLOR_FLARE,
}
```

  Members after `_inset`:

```gdscript
var _screen_margin: MarginContainer = null
var _header_margin: MarginContainer = null
var _header: HBoxContainer = null
var _back_button: Button = null
var _counter_label: Label = null
var _denom_label: Label = null
var _track_margin: MarginContainer = null
var _progress_track: Panel = null
var _progress_fill: Panel = null
var _points_row: HBoxContainer = null
var _points_label: Label = null
var _points_unit: Label = null
var _body_margin: MarginContainer = null
var _tier_columns: HBoxContainer = null
```

  Replace the three `Task 6 replaces this` members with:

```gdscript
## The screen's fixed frame: shell, header and body; the tier columns are
## rebuilt by _render_milestones_modal_content, as the TS rebuilds innerHTML.
## PORT: web/src/tilt-to-live/GoalsHUD.ts:95-103, :362-382
## DIVERGENCE(UI-SYSTEM): Milestones.dc.html — full screen in shell, the
## Armory's 64 px header (interface spec §6.5).
func _build_milestones_modal() -> Control:
	var screen: ColorRect = ColorRect.new()
	screen.name = "MilestonesModal"
	screen.color = UiTheme.COLOR_SHELL
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The screen swallows taps meant for Run over and the arena underneath.
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.visible = false

	_screen_margin = MarginContainer.new()
	_screen_margin.name = "ScreenMargin"
	_screen_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	screen.add_child(_screen_margin)
	_screen_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_screen_margin.add_child(column)

	_header_margin = MarginContainer.new()
	_header_margin.name = "HeaderMargin"
	column.add_child(_header_margin)
	_header = HBoxContainer.new()
	_header.name = "Header"
	_header_margin.add_child(_header)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.theme_type_variation = "FlatIconButton"
	_back_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# PORT: web/src/tilt-to-live/GoalsHUD.ts:484-486 (btn-close-milestones)
	_back_button.pressed.connect(close_all_goals_modal)
	_header.add_child(_back_button)
	var title: Label = UiTheme.text("Milestones", "TitleText")  # PORT: :364
	title.name = "TitleLabel"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(title)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(fill)

	var counter: HBoxContainer = HBoxContainer.new()  # PORT: :367
	counter.add_theme_constant_override("separation", 0)
	_counter_label = _header_label("CounterLabel", UiTheme.COLOR_TEXT_MUTED)
	counter.add_child(_counter_label)
	_denom_label = _header_label("CounterDenomLabel", UiTheme.TEXT_FAINT)
	counter.add_child(_denom_label)
	_header.add_child(counter)

	_track_margin = MarginContainer.new()  # PORT: :368-370
	_track_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_track = Panel.new()
	_progress_track.name = "ProgressTrack"
	_progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_fill = Panel.new()
	_progress_fill.name = "ProgressFill"
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_fill.anchor_bottom = 1.0
	_progress_track.add_child(_progress_fill)
	_track_margin.add_child(_progress_track)
	_header.add_child(_track_margin)

	_points_row = HBoxContainer.new()  # PORT: :372
	_points_label = UiTheme.text("", "PointsText")
	_points_label.name = "HeaderPointsLabel"
	_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points_row.add_child(_points_label)
	# M14: keeps the CapsText variation (Mono 600, tracking 0.14) as board-copy
	# tolerance; the board's unit is Mono 500/10px/0.1em with margin 0 6px 0 2px
	# on the title. Check against Milestones.dc.html at the device pass (Task 8).
	_points_unit = UiTheme.text("", "CapsText")
	_points_unit.name = "HeaderPointsUnit"
	_points_unit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points_unit.add_theme_color_override("font_color", UiTheme.POINTS_UNIT)
	_points_row.add_child(_points_unit)
	_header.add_child(_points_row)

	var rule: ColorRect = ColorRect.new()
	rule.name = "HeaderRule"
	rule.color = UiTheme.COLOR_RAISED  # DIVERGENCE(UI-SYSTEM): Milestones.dc.html — border-bottom
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_body_margin = MarginContainer.new()
	_body_margin.name = "BodyMargin"
	_body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body_margin)
	_tier_columns = HBoxContainer.new()
	_tier_columns.name = "TierColumns"
	_body_margin.add_child(_tier_columns)
	return screen


## Scales every board size on the screen; rebuilds the columns when it is open
## (their sizes are baked at build time), as ArmoryUI.set_ui_scale does.
func _layout_modal() -> void:
	if _screen_margin == null:
		return
	var s: float = _ui_scale
	var pad: Vector2 = _inset if OS.has_feature("mobile") else Vector2.ZERO
	_screen_margin.add_theme_constant_override("margin_left", int(pad.x))
	_screen_margin.add_theme_constant_override("margin_right", int(pad.x))
	_screen_margin.add_theme_constant_override("margin_top", int(pad.y))
	_screen_margin.add_theme_constant_override("margin_bottom", int(pad.y))
	_header_margin.add_theme_constant_override("margin_left", UiTheme.px(HEADER_PAD_LEFT, s))
	_header_margin.add_theme_constant_override("margin_top", UiTheme.px(HEADER_PAD_Y, s))
	_header_margin.add_theme_constant_override("margin_right", UiTheme.px(HEADER_PAD_RIGHT, s))
	_header_margin.add_theme_constant_override("margin_bottom", UiTheme.px(HEADER_PAD_Y, s))
	_header.add_theme_constant_override("separation", UiTheme.px(HEADER_GAP, s))
	var side: float = UiTheme.TOUCH_TARGET * s
	_back_button.custom_minimum_size = Vector2(side, side)
	_back_button.icon = UiTheme.svg_texture(UiTheme.ICON_BACK, s)
	for label: Label in [_counter_label, _denom_label]:
		label.add_theme_font_size_override("font_size", UiTheme.px(COUNTER_SIZE, s))
	_track_margin.add_theme_constant_override("margin_left", UiTheme.px(TRACK_MARGIN, s))
	_track_margin.add_theme_constant_override("margin_right", UiTheme.px(TRACK_MARGIN, s))
	_progress_track.custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT) * s
	var r: int = UiTheme.px(TRACK_RADIUS, s)
	_progress_track.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_RAISED, Color.TRANSPARENT, r)
	)
	_progress_fill.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_ION, Color.TRANSPARENT, r)
	)
	_points_row.add_theme_constant_override("separation", UiTheme.px(POINTS_GAP, s))
	_body_margin.add_theme_constant_override("margin_left", UiTheme.px(BODY_PAD_LEFT, s))
	_body_margin.add_theme_constant_override("margin_top", UiTheme.px(BODY_PAD_TOP, s))
	_body_margin.add_theme_constant_override("margin_right", UiTheme.px(BODY_PAD_RIGHT, s))
	_body_margin.add_theme_constant_override("margin_bottom", 0)
	_tier_columns.add_theme_constant_override("separation", UiTheme.px(COLUMN_GAP, s))
	if is_modal_open():
		_render_milestones_modal_content()


## PORT: web/src/tilt-to-live/GoalsHUD.ts:311-487
func _render_milestones_modal_content() -> void:
	if _milestones_modal == null:
		return

	var completed: int = _goal_manager.get_completed_count()
	var total: int = _goal_manager.get_total_goals_count()
	var points: int = _progression.data.points
	# PORT: :317
	var progress_pct: int = roundi(float(completed) / float(total) * 100.0) if total > 0 else 0

	_counter_label.text = str(completed)  # PORT: :367
	_denom_label.text = "/%d" % total
	_progress_fill.anchor_right = progress_pct / 100.0  # PORT: :369
	_points_label.text = UiTheme.group_digits(points)  # PORT: :372
	# PORT: :372 (pt at 1). DIVERGENCE(UI-SYSTEM): Milestones.dc.html — caps unit.
	_points_unit.text = "PT" if points == 1 else "PTS"

	for child: Node in _tier_columns.get_children():
		_tier_columns.remove_child(child)
		child.queue_free()

	# Categorize goals into the 3 tiers: Score, Combat, Mastery (:319-360)
	for tier_name: String in TIERS:
		var goals: Array[GoalManager.Goal] = []
		for goal: GoalManager.Goal in _goal_manager.catalog:
			if _get_goal_tier(goal) == tier_name:
				goals.append(goal)
		_tier_columns.add_child(_tier_column(tier_name, goals))


## The TS's local getGoalTier. PORT: web/src/tilt-to-live/GoalsHUD.ts:322-354
func _get_goal_tier(goal: GoalManager.Goal) -> String:
	# Unlock-family goals are collection/mastery achievements (:323-329).
	if _goal_manager.is_unlock_goal(goal):
		return "Mastery"
	if (
		goal.category == "score"
		or goal.metric == "run_score"
		or goal.metric == "total_score"
		or goal.metric == "total_points"
	):
		return "Score"
	if (
		goal.category == "combat"
		or goal.category == "combo"
		or goal.category == "weapons"
		or goal.metric.contains("kills")
		or goal.metric.contains("multiplier")
		or goal.metric.contains("nuke")
		or goal.metric.contains("vortex")
		or goal.metric.contains("laser")
		or goal.metric.contains("missile")
		or goal.metric.contains("freeze")
		or goal.metric.contains("shield")
	):
		return "Combat"
	return "Mastery"


## One tier column. PORT: web/src/tilt-to-live/GoalsHUD.ts:383-478
## DIVERGENCE(UI-SYSTEM): Milestones.dc.html — three side-by-side columns, each
## scrolling on its own under a 40 px shell fade (replaces game.css's grid).
func _tier_column(tier_name: String, goals: Array[GoalManager.Goal]) -> Control:
	var s: float = _ui_scale
	var open: Array[GoalManager.Goal] = []
	var done: Array[GoalManager.Goal] = []
	for g: GoalManager.Goal in goals:
		if _goal_manager.is_completed(g.id):
			done.append(g)
		else:
			open.append(g)

	var column: Control = Control.new()
	column.name = "Tier_" + tier_name
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.clip_contents = true
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", UiTheme.px(STACK_GAP, s))
	column.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var heading: HBoxContainer = HBoxContainer.new()
	heading.add_theme_constant_override("separation", UiTheme.px(HEADING_GAP, s))
	var name_label: Label = UiTheme.caps(tier_name)
	name_label.name = "TierName"
	name_label.add_theme_color_override("font_color", TIER_TINTS[tier_name])
	heading.add_child(name_label)
	# PORT: :384-391
	var count: Label = UiTheme.text("%d of %d" % [done.size(), goals.size()], "MonoFaintText")
	count.name = "TierCount"
	heading.add_child(count)
	stack.add_child(heading)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "TierScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cards: VBoxContainer = VBoxContainer.new()
	cards.name = "TierCards"
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", UiTheme.px(STACK_GAP, s))
	# DIVERGENCE(UI-SYSTEM): interface spec §6.5 — open goals first, then done
	# ones, each in catalog order (departs from GoalsHUD.ts:394's catalog order).
	for g: GoalManager.Goal in open + done:
		cards.add_child(_milestone_card(g))
	scroll.add_child(cards)
	stack.add_child(scroll)

	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, UiTheme.tint(UiTheme.COLOR_SHELL, 0.0))
	gradient.set_color(1, UiTheme.COLOR_SHELL)
	var fade_texture: GradientTexture2D = GradientTexture2D.new()
	fade_texture.gradient = gradient
	fade_texture.fill_to = Vector2(0.0, 1.0)
	var fade: TextureRect = TextureRect.new()
	fade.name = "TierFade"
	fade.texture = fade_texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fade.offset_top = -UiTheme.px(FADE_HEIGHT, s)
	return column


## One card: done, open unlock or run goal, or open lifetime goal with progress.
## PORT: web/src/tilt-to-live/GoalsHUD.ts:394-474
## DIVERGENCE(UI-SYSTEM): Milestones.dc.html — card, mark and text styles.
func _milestone_card(goal: GoalManager.Goal) -> PanelContainer:
	var s: float = _ui_scale
	var is_done: bool = _goal_manager.is_completed(goal.id)
	var is_unlock: bool = _goal_manager.is_unlock_goal(goal)
	var is_total: bool = not is_unlock and _goal_manager.is_total_goal(goal)

	# Unlock goals have no meaningful numeric target (:398-401).
	var current_val: float = 0.0
	if is_total:
		current_val = _goal_manager.get_metric_value(goal.metric, GoalManager.RunTracker.new())
	# PORT: :419-422
	var pct: int = 0 if is_unlock else clampi(roundi(current_val / goal.target * 100.0), 0, 100)

	var card: PanelContainer = PanelContainer.new()
	card.name = "MilestoneCard_" + goal.id
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.custom_minimum_size.y = CARD_HEIGHT * s
	card.add_theme_stylebox_override(
		"panel",
		UiTheme.padded(
			UiTheme.flat(
				UiTheme.DONE_CARD if is_done else UiTheme.COLOR_PANEL,
				UiTheme.COLOR_RAISED if is_done else UiTheme.COLOR_LINE,
				UiTheme.px(UiTheme.CARD_RADIUS, s)
			),
			UiTheme.px(CARD_PAD_X, s),
			0.0
		)
	)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", UiTheme.px(CARD_GAP, s))
	card.add_child(row)

	var mark: Panel = Panel.new()
	mark.name = "MarkBox"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE) * s
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mr: int = UiTheme.px(MARK_RADIUS, s)
	if is_done:
		mark.add_theme_stylebox_override(
			"panel", UiTheme.flat(UiTheme.COLOR_LOCKED_IN, UiTheme.COLOR_LOCKED_IN, mr)
		)
		var check: TextureRect = TextureRect.new()
		check.texture = UiTheme.svg_texture(UiTheme.ICON_MARK, s)
		check.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_child(check)
		check.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		mark.add_theme_stylebox_override(
			"panel", UiTheme.flat(Color.TRANSPARENT, UiTheme.COLOR_LINE_STRONG, mr)
		)
	row.add_child(mark)

	var content: VBoxContainer = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("separation", UiTheme.px(CONTENT_GAP, s))
	var name_label: Label = _one_line("NameLabel", goal.title, "BodyText")
	name_label.add_theme_font_override("font", UiTheme.sans(UiTheme.Weight.MEDIUM))
	name_label.add_theme_color_override(
		"font_color", UiTheme.COLOR_TEXT_MUTED if is_done else UiTheme.COLOR_TEXT
	)
	content.add_child(name_label)

	# Open lifetime goals show "cur / target" (:457-460); everything else its
	# description (interface spec §6.5).
	var subtitle: String = goal.description
	if not is_done and is_total:
		subtitle = "%s / %s" % [
			UiTheme.group_digits(int(current_val)), UiTheme.group_digits(goal.target)
		]
	content.add_child(_one_line("GoalLabel", subtitle, "MonoFaintText"))

	# DIVERGENCE(UI-SYSTEM): interface spec §6.5 — only open lifetime goals carry
	# a bar; the TS also draws an empty one on open run goals (:462-470) (R10).
	if not is_done and is_total:
		var bar_margin: MarginContainer = MarginContainer.new()
		bar_margin.mouse_filter = Control.MOUSE_FILTER_PASS
		bar_margin.add_theme_constant_override("margin_top", UiTheme.px(BAR_TOP, s))
		var bar: Panel = Panel.new()
		bar.name = "BarTrack"
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size.y = BAR_HEIGHT * s
		var br: int = UiTheme.px(BAR_RADIUS, s)
		bar.add_theme_stylebox_override(
			"panel", UiTheme.flat(UiTheme.COLOR_RAISED, Color.TRANSPARENT, br)
		)
		var bar_fill: Panel = Panel.new()
		bar_fill.name = "BarFill"
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_fill.anchor_bottom = 1.0
		bar_fill.anchor_right = pct / 100.0  # PORT: :468
		bar_fill.add_theme_stylebox_override(
			"panel", UiTheme.flat(UiTheme.COLOR_ION, Color.TRANSPARENT, br)
		)
		bar.add_child(bar_fill)
		bar_margin.add_child(bar)
		content.add_child(bar_margin)
	row.add_child(content)

	var pts: Label = _label(
		"PointsLabel",
		"+%d" % goal.reward_points,
		UiTheme.mono(UiTheme.Weight.MEDIUM),
		CARD_POINTS_SIZE,
		UiTheme.TEXT_FAINT if is_done else UiTheme.COLOR_FLARE
	)
	row.add_child(pts)
	return card


## A single-line label that ellipsises (rule 03) in a theme variation.
func _one_line(label_name: String, content: String, variation: String) -> Label:
	var label: Label = UiTheme.text(content, variation)
	label.name = label_name
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A header numeral in Mono at the counter size (set in _layout_modal).
func _header_label(label_name: String, color: Color) -> Label:
	var label: Label = UiTheme.text("", "MonoText")
	label.name = label_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	return label
```

  Notes for the implementer: every Control under `TierScroll` must be `PASS` or `IGNORE` (the drag must reach the `ScrollContainer`); `Panel` and `TextureRect` default to `STOP`/`PASS` differently, which is why each sets its filter explicitly. `open + done` concatenates two typed arrays — if the analyzer rejects the result's type, build a third `Array[GoalManager.Goal]` with `append_array` instead. If a card measures taller than 58 px in `test_long_text_stays_on_one_line`, the cause is a label's minimum width, not the style: check `clip_text` is set on both labels before changing any constant.

- [x] **Step 5: Verify** — `tools/run_tests.sh` → `OK: 48/48 scripts (480 tests)`; `gdformat --check`, `gdlint` clean; `grep -rn "Task 6 replaces" godot/src/` prints nothing; `grep -rniE "ff4757" godot/src/ui/` prints nothing.

- [x] **Step 6: Commit**

```bash
git checkout godot/project.godot
git add godot/src/ui/goals_hud.gd godot/src/ui/ui_theme.gd godot/tests/test_goals_hud.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: build the Milestones screen to its board; next: M9 Task 7"
git log -1 --format=%B
```

---

### Task 7: Run over — points total, earned-milestones list, and the screen opener (R1)

> **Rewritten 2026-09-23** to interface spec §6.3/§6.5 on `UiTheme`. Visual authority:
> `RunOver.dc.html`. Rulings R1, R9 apply.

**Files:**
- Modify: `godot/src/ui/run_over_sheet.gd`, `godot/src/ui/hud_controller.gd`, `godot/src/core/game_root.gd`, `godot/src/sim/run_controller.gd` (comment only)
- Test: `godot/tests/test_run_over_sheet.gd`, `godot/tests/test_main_scene.gd`

**Interfaces:**
- Consumes: `RunController.run_completed_goals/points_earned_this_run/coins.points_from_coins` (Task 4), `GoalsHUD.open_all_goals_modal()` (Task 5), `UiTheme.ICON_CHECK`.
- Produces: `RunOverSheet.milestones_requested` signal; `RunOverSheet.RunResult.milestones: Array[GoalManager.Goal]`; node names `PointsRow` (now tappable), `MilestonesClip`, `MilestonesList`, rows `MilestoneRow_<goal id>` containing `MilestoneText`, `MilestonePoints`; `GameRoot.open_all_goals_modal() -> void`.

- [ ] **Step 1: Write the failing tests.** In `godot/tests/test_run_over_sheet.gd`:
  - In `test_sheet_carries_the_board_controls`, change the last assertion's message from `"hidden until M9 fills it"` to `"hidden until a result lists milestones"`, and add `"MilestonesClip"` to the name list.
  - Append:

```gdscript
func _goal(id: String, title: String, description: String, reward: int) -> GoalManager.Goal:
	var goal: GoalManager.Goal = GoalManager.Goal.new()
	goal.id = id
	goal.title = title
	goal.description = description
	goal.reward_points = reward
	return goal


func _click() -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func test_milestones_list_shows_each_earned_goal() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2132-2140
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var result: RunOverSheet.RunResult = _result()
	result.milestones = [
		_goal("score_1k", "Rookie Dodger", "Reach 1,000 score in a run", 1),
		_goal("kills_15", "First Blood", "Destroy 15 red dots in a run", 1),
	] as Array[GoalManager.Goal]
	sheet.show_result(result)
	var list: VBoxContainer = sheet.find_child("MilestonesList", true, false) as VBoxContainer
	assert_true(list.visible)
	assert_eq(list.get_child_count(), 2)
	var row: Node = list.get_child(0)
	assert_eq(String(row.name), "MilestoneRow_score_1k")
	assert_eq(
		(row.find_child("MilestoneText", true, false) as Label).text,
		"Rookie Dodger — Reach 1,000 score in a run",
		":2136"
	)
	assert_eq((row.find_child("MilestonePoints", true, false) as Label).text, "+1", ":2137")


func test_milestones_list_hides_when_none_were_earned() -> void:
	# PORT: web/src/tilt-to-live/TiltGame.ts:2141-2143
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var result: RunOverSheet.RunResult = _result()
	result.milestones = [_goal("score_1k", "Rookie Dodger", "x", 1)] as Array[GoalManager.Goal]
	sheet.show_result(result)
	sheet.show_result(_result())
	var list: VBoxContainer = sheet.find_child("MilestonesList", true, false) as VBoxContainer
	assert_false(list.visible)
	assert_eq(list.get_child_count(), 0, "innerHTML = '' (:2142)")


func test_tapping_the_points_row_or_the_list_requests_the_screen() -> void:
	# PORT: web/src/tilt-to-live/GoalsHUD.ts:129-135 (M9 plan R1)
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	watch_signals(sheet)
	(sheet.find_child("PointsRow", true, false) as Control).gui_input.emit(_click())
	assert_signal_emit_count(sheet, "milestones_requested", 1)
	(sheet.find_child("MilestonesList", true, false) as Control).gui_input.emit(_click())
	assert_signal_emit_count(sheet, "milestones_requested", 2)
	var release: InputEventMouseButton = _click()
	release.pressed = false
	(sheet.find_child("PointsRow", true, false) as Control).gui_input.emit(release)
	assert_signal_emit_count(sheet, "milestones_requested", 2, "a release is not a second tap")


func test_many_milestones_keep_the_sheet_on_screen() -> void:
	# M9 plan R9: the list takes the column's free space and clips.
	var sheet: RunOverSheet = _sheet(Vector2(844, 390), 1.0)
	var result: RunOverSheet.RunResult = _result()
	var many: Array[GoalManager.Goal] = []
	for i: int in range(7):
		many.append(_goal("g%d" % i, "Milestone %d" % i, "a long description for row %d" % i, 2))
	result.milestones = many
	sheet.show_result(result)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Control = sheet.find_child("Sheet", true, false) as Control
	assert_true(
		sheet.get_global_rect().grow(0.5).encloses(panel.get_global_rect()),
		"the sheet stays inside 844×390"
	)
	var retry: Control = sheet.find_child("RestartButton", true, false) as Control
	# M1: wrapped by hand — gdformat --check would fail an existing file at >100 columns.
	assert_true(
		panel.get_global_rect().grow(0.5).encloses(retry.get_global_rect()), "Retry on the sheet"
	)
	assert_true((sheet.find_child("MilestonesClip", true, false) as Control).clip_contents)
```

  Append to `godot/tests/test_main_scene.gd`:

```gdscript
func test_run_over_lists_the_runs_milestones_and_opens_the_screen() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var rc: RunController = root._run_controller
	rc.run_tracker.score = 1000
	rc.trigger_player_death()
	var list: VBoxContainer = root.find_child("MilestonesList", true, false) as VBoxContainer
	assert_true(list.visible, "TiltGame.ts:2140")
	assert_eq(list.get_child_count(), 1)
	var text: Label = list.get_child(0).find_child("MilestoneText", true, false) as Label
	assert_eq(text.text, "Rookie Dodger — Reach 1,000 score in a run", ":2136")
	var earned: Label = root.find_child("PointsEarnedLabel", true, false) as Label
	assert_eq(earned.text, "+1", "max(1, 1) + 0 coins (:2118)")
	var balance: Label = root.find_child("PointsBalanceLabel", true, false) as Label
	assert_eq(balance.text, "7,332", "7331 + 1 (:2119)")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	list.gui_input.emit(click)
	var screen: Control = root.find_child("MilestonesModal", true, false) as Control
	assert_true(screen.visible, "GoalsHUD.ts:131-132")
	(root.find_child("GoalsHud", true, false) as GoalsHUD).close_all_goals_modal()
	(root.find_child("PointsRow", true, false) as Control).gui_input.emit(click)
	assert_true(screen.visible, "GoalsHUD.ts:133-134")


func test_run_over_hides_an_empty_milestones_list() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root._run_controller.trigger_player_death()
	assert_false((root.find_child("MilestonesList", true, false) as Control).visible, ":2141-2143")
	assert_eq((root.find_child("PointsEarnedLabel", true, false) as Label).text, "+0")
	assert_eq((root.find_child("PointsBalanceLabel", true, false) as Label).text, "7,331")
```

- [ ] **Step 2: Run to verify they fail** — `tools/run_tests.sh` → `collected 47 of 48` (`test_run_over_sheet.gd` does not parse: `RunResult.milestones` unknown); the two new `test_main_scene.gd` tests fail (the list stays hidden).

- [ ] **Step 3: `RunOverSheet`** (`godot/src/ui/run_over_sheet.gd`):
  - Header `## PORTS:` block: after `:2088-2122 (population)` add `, :2132-2144 (earned milestones);` and a line `##        GoalsHUD.ts:129-135 (bindGameOverClicks).`
  - **Before** `const CONTROL_PICKER ...` (gdlint's class-definitions-order puts signals ahead of constants): `## Tapping the points row or the milestones list. PORT: web/src/tilt-to-live/GoalsHUD.ts:129-135` / `signal milestones_requested`, then a blank line.
  - Constants after `SPEND_GAP`:

```gdscript
## Earned-milestone rows. DIVERGENCE(UI-SYSTEM): RunOver.dc.html — list gap 6,
## row gap 9, the HUD toast's 14 px check, text 13 #C7CDDB, points Mono 12 flare.
const LIST_GAP: int = 6
const ROW_GAP: int = 9
const ROW_POINTS_SIZE: int = 12
```

  - Members: `var _ui_scale: float = 1.0`, `var _points_row: HBoxContainer = null`, `var _milestones: VBoxContainer = null`, `var _shown_milestones: Array[GoalManager.Goal] = []`.
  - `set_ui_scale`: first line `_ui_scale = scale`; last lines `_milestones.add_theme_constant_override("separation", UiTheme.px(LIST_GAP, scale))` and `_fill_milestones(_shown_milestones)` (rows bake their sizes).
  - `show_result`: after the `_spend_value` line, `_fill_milestones(result.milestones)  # PORT: :2132-2144`.
  - In `_build_right()`: `points_row` becomes `_points_row` (keep its name `PointsRow`), and before `_right.add_child(_points_row)` replace the two-line `TODO(M9)` comment with:

```gdscript
	# PORT: web/src/tilt-to-live/GoalsHUD.ts:133-134 (.gameover-points-box opens the screen)
	_points_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_points_row.gui_input.connect(_on_rows_gui_input)
```

  and replace the block from `var milestones: VBoxContainer = VBoxContainer.new()` through `_right.add_child(fill)` with:

```gdscript
	# M9 plan R9: the list sits in the board's flex gap (RunOver.dc.html's
	# flex-grow spacer) and clips there, so a long list never grows the sheet.
	var clip: Control = Control.new()
	clip.name = "MilestonesClip"
	clip.clip_contents = true
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_milestones = VBoxContainer.new()
	_milestones.name = "MilestonesList"
	_milestones.visible = false
	# PORT: web/src/tilt-to-live/GoalsHUD.ts:131-132 (the list opens the screen)
	_milestones.mouse_filter = Control.MOUSE_FILTER_STOP
	_milestones.gui_input.connect(_on_rows_gui_input)
	clip.add_child(_milestones)
	_milestones.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_right.add_child(clip)
```

  - New private methods after `_stat_cell`:

```gdscript
## PORT: web/src/tilt-to-live/TiltGame.ts:2132-2144
func _fill_milestones(goals: Array[GoalManager.Goal]) -> void:
	_shown_milestones = goals
	for child: Node in _milestones.get_children():
		_milestones.remove_child(child)
		child.queue_free()
	for goal: GoalManager.Goal in goals:
		_milestones.add_child(_milestone_row(goal))
	_milestones.visible = not goals.is_empty()


## One earned milestone. PORT: web/src/tilt-to-live/TiltGame.ts:2133-2139
## DIVERGENCE(UI-SYSTEM): RunOver.dc.html — row styles (M9 plan R6 is superseded).
func _milestone_row(goal: GoalManager.Goal) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "MilestoneRow_" + goal.id
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiTheme.px(ROW_GAP, _ui_scale))
	var check: TextureRect = TextureRect.new()
	check.texture = UiTheme.svg_texture(UiTheme.ICON_CHECK, _ui_scale)
	check.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(check)
	var text: Label = UiTheme.text("%s — %s" % [goal.title, goal.description], "BodyText")
	text.name = "MilestoneText"
	text.add_theme_color_override("font_color", UiTheme.TEXT_SECONDARY)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var pts: Label = UiTheme.text("+%d" % goal.reward_points, "PointsText")
	pts.name = "MilestonePoints"
	pts.add_theme_font_override("font", UiTheme.mono(UiTheme.Weight.REGULAR))
	pts.add_theme_font_size_override("font_size", UiTheme.px(ROW_POINTS_SIZE, _ui_scale))
	pts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pts)
	return row


## bindGameOverClicks' handler. PORT: web/src/tilt-to-live/GoalsHUD.ts:131-134
func _on_rows_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		milestones_requested.emit()
```

  - `RunResult` gains, after `balance`: `## The goals evaluateRun completed. PORT: web/src/tilt-to-live/TiltGame.ts:2086` / `var milestones: Array[GoalManager.Goal] = []`.

- [ ] **Step 4: `HudController`** (`godot/src/ui/hud_controller.gd`):
  - In `run_result_for`, replace the two lines from `# TODO(M9): + Math.max(...)` through `result.earned = run.coins.points_from_coins  # PORT: :2118` with:

```gdscript
		var milestone_points: int = 0
		for goal: GoalManager.Goal in run.run_completed_goals:
			milestone_points += goal.reward_points  # PORT: :2111-2114
		# PORT: :2118 — coins are a second income stream folded into the one total.
		result.earned = (
			maxi(run.points_earned_this_run, milestone_points) + run.coins.points_from_coins
		)
		result.milestones = run.run_completed_goals.duplicate()  # PORT: :2132
```

  - In `_ready()`, after `_run_over = _game_over_panel as RunOverSheet`: `if _run_over != null:` / `_run_over.milestones_requested.connect(_on_milestones_requested)`.
  - A private method after `_on_armory_pressed`:

```gdscript
## bindGameOverClicks' target. PORT: web/src/tilt-to-live/GoalsHUD.ts:131-134
func _on_milestones_requested() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root != null:
		root.open_all_goals_modal()
```

- [ ] **Step 5: `GameRoot`** — after `is_armory_open()` (M8: `get_run_controller()` was dropped there in Task 5):

```gdscript
## Opens the full Milestones screen (the Run over rows, the M key; the menu link is M11's).
## PORT: web/src/tilt-to-live/TiltGame.ts:195
func open_all_goals_modal() -> void:
	_goals_hud.open_all_goals_modal()
```

  In `godot/src/sim/run_controller.gd`, if a `TODO(M11)` comment still says the game-over reads `points_from_coins` (step 5.5), edit it to `# TODO(M11): the coins row reads coins.coins_collected (TiltGame.ts:2108, :2123-2130); points_from_coins already feeds the Run over total (M9).` — otherwise leave the file alone and drop it from `git add`.

- [ ] **Step 6: Verify** — `tools/run_tests.sh` → `OK: 48/48 scripts (486 tests)`; `gdformat --check` (`86 files would be left unchanged`), `gdlint` clean; `grep -rn "TODO(M9)" godot/src/ godot/tests/` prints nothing; `grep -rniE "ff4757" godot/src/ui/` prints nothing; headless boot `grep -c "SCRIPT ERROR"` → `0`. Record `grep -rn "DIVERGENCE" godot/src/ | wc -l` and `grep -rn "DIVERGENCE(UI-SYSTEM)" godot/src/ | wc -l` in `HANDOFF.md`'s verify block — Task 9 checks against them.

- [ ] **Step 7: Commit**

```bash
git checkout godot/project.godot
git add godot/src/ui/run_over_sheet.gd godot/src/ui/hud_controller.gd godot/src/core/game_root.gd godot/src/sim/run_controller.gd godot/tests/test_run_over_sheet.gd godot/tests/test_main_scene.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: list earned milestones on Run over; next: M9 Task 8"
git log -1 --format=%B
```

---

### Task 8: Device pass — unattended half, and `## M9 — Milestones` in `VERIFY-ME.md`

**Files:** Modify (append): `godot/VERIFY-ME.md`.

- [ ] **Step 1:** `"$ADB" devices`. If `RRCXB04L8EJ` is listed: build and install exactly as `VERIFY-ME.md` §0 records (same export preset and commands — M13: §0, not §M8, holds the commands; M8.5 is the latest device section), launch, and capture `"$ADB" -s RRCXB04L8EJ logcat -d | grep -c "SCRIPT ERROR"` (expect `0`) and the frame-time command from the "Mobile scale split" section. If it is not listed, record `adb devices returned no devices on <date>` and do the unattended checks only: `tools/run_tests.sh`, the headless boot, and an Android export if §0 shows one can run without the phone.

- [ ] **Step 2:** Append to `godot/VERIFY-ME.md` (never recreate the file):

```markdown
## M9 — Milestones (device pass, plan Task 8)

Unattended evidence: <paste the commands run and their output lines>.

Hand-held checks (tick when seen on the A55):

- [ ] **Rail** (`Hud.dc.html`): a 3 px ion line on the top edge of the arena frame, from its left corner, growing by 1/57 of the frame's width per milestone. It does not respond to taps. Hidden only in menu mode (M11).
- [ ] **Toast**: completing a milestone (buying a ship in the Armory, or a cumulative total mid-run) shows a card under the lives icons — green check, title, `+N` in flare — for 3 s. It does not block touches or the joystick. Calibrate (Pause, gyro scheme) shows `TILT CALIBRATED` / `Neutral Angle Zeroed ✓` with the ion ring for 2.8 s; note whether the ✓ renders.
- [ ] **Run over**: a run that earns milestones lists them under "Points earned +X → balance" (check, `Title — description`, `+N`); the list is hidden when none were earned. With 4+ rows the list clips and Retry stays on screen (R9 — say whether clipping looks acceptable).
- [ ] **Screen from Run over** (`Milestones.dc.html`): tapping the points row or the list opens the full-screen Milestones screen: 64 px header (Back, title, `n/57`, progress track, points), three side-by-side columns (Score 9, Combat 17, Mastery 31), open goals above done ones, each column drag-scrolls with a fade at its foot. Back closes it; nothing underneath reacts to taps while it is open.
- [ ] **Unlock goals at boot**: an existing save that already owns a goal's ship/skin/arena completes that goal once at launch, silently (B3: no toast, no points paid — only cumulative.totalPointsEarned moves), never twice.
- [ ] **Persistence**: kill the app and relaunch — completed milestones and cumulative totals survive (`user://tilt_to_live_completed_goals_v1.json` is a bare JSON array).
- [ ] **Frame time** under a mass explosion unchanged from the "Mobile scale split" figure (the per-tick goal check is a 57-goal loop).
```

- [ ] **Step 3: Commit**

```bash
git checkout godot/project.godot
git add godot/VERIFY-ME.md docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: record device evidence and hand-held checks; next: M9 Task 9"
git log -1 --format=%B
```

---

### Task 9: Exit protocol (CONVENTIONS §9)

- [ ] **Step 1: Verify** — fresh, and read every output:

```bash
tools/run_tests.sh                        # expect: OK: 48/48 scripts (486 tests)
gdformat --check godot/src godot/tests    # expect: 86 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "DIVERGENCE" godot/src/ | wc -l  # expect: the total Task 7 recorded in HANDOFF.md
grep -rniE "ff4757" godot/src/ui/         # expect: nothing (rule 01)
grep -rn "TODO(M9)" godot/src/ godot/tests/   # expect: nothing
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR"   # expect: 0
git checkout godot/project.godot
```

  (`86` = 81 at the M8.5 exit + `goal_manager.gd`, `goals_hud.gd` + `test_goal_manager.gd`, `test_goal_parity.gd`, `test_goals_hud.gd`.)

- [ ] **Step 2: Tick `godot/PORT-PROGRESS.md`** — `- [x] **M9 — Milestones**` with the date, the final commit SHA (the parent of the exit commit, as M8 did) and "device pass pending" if Task 8 had no phone.

- [ ] **Step 3: Rewrite `godot/HANDOFF.md`** for a zero-context session: `## State` (M9 code-complete, device pass pending), `## How to verify right now` (the Step 1 block with the real numbers), a `## M9 — what landed` section (files, rulings R1–R11, the three new test scripts), Open questions (below), and `## Next`: **M5 (Audio bake + SFX) or M10 (Modes)** — M5 deps M2, M10 deps M3, both open; M11 needs all. Literal first step for each, in the style of the current `## Next`.

- [ ] **Step 4: Index plan** — in `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md`, mark M9 done exactly as M8's row/line was marked.

- [ ] **Step 5: Commit and stop**

```bash
git checkout godot/project.godot
git add godot/PORT-PROGRESS.md godot/HANDOFF.md docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md docs/superpowers/plans/2026-09-20-m9-milestones.md
git commit -m "M9 done: next read godot/HANDOFF.md + VERIFY-ME.md, then plan M5 or M10"
git log -1 --format=%B
```

Then **stop and report to the user** (CONVENTIONS §9 step 5). Do not begin M5 or M10.

---

## Open questions (for the user; record answers here and in HANDOFF)

1. **R7/I3 — the run is double-counted at every `evaluate_run`, not only the death tick.** `evaluate_run` commits the run into `cumulative` (step 1) and then, while evaluating that call's own total goals, `get_metric_value`'s `total_*` arms add the same tracker a second time (`:955-962`) — every game over double-counts a cumulative goal's progress by one run's worth, not just the extra death-tick call from `evaluate_live_total_goals` (it can complete e.g. *Century of Destruction* at 30 lifetime + 40 this run, twice over on death). The plan preserves it (LAW 2). Fixing it is a spec change to `evaluate_run`'s step 2/3 ordering, not a one-line skip.
2. **R9 — a long Run over list clips** rather than scrolling or growing the sheet. Confirm at the device pass, or choose another treatment.
3. **R10 — open run goals show no progress bar** (spec §6.5), where the TS draws an empty one. Confirm.
4. **B3 — pre-owned unlocks at bind complete without paying spendable points or showing a toast**, as in the TS (`bind()` runs `_init_dom()`, which calls `check_unlock_goals()` before `_setup_listeners()` installs the callbacks). Only `cumulative.totalPointsEarned` moves; `ProgressionManager.data.points` and the toast are untouched. Confirm this is kept (LAW 2), or rule that owned unlocks at boot should pay out like a normal completion.
5. **Toast slide-in** (`game.css:595`) is not ported; the boards draw no motion. Say if it should be.
