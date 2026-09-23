# Module 9 — Milestones: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port `GoalManager.ts` (all 57 goals, cumulative stats, `evaluateRun`, `evaluateLiveTotalGoals`, `evaluateUnlockGoals`) and `GoalsHUD.ts` (4px edge rail, completion toast, full Milestones modal), wire the run tracker into `RunController` at spec §5.4 step 10, and port the game-over "Points earned" row and earned-milestones list as the modal's touch opener.

**Architecture:** `GoalManager.ts` becomes `src/meta/goal_manager.gd` (`class_name GoalManager extends RefCounted`, not an autoload — spec §5.2), with the TS interfaces `Goal`, `CumulativeStats`, `RunTracker` as typed inner classes and `category`/`metric` kept as the TS strings (M7 precedent (a) — `isTotalGoal`'s `startsWith('total_')` and GoalsHUD's tier substring tests read them as strings). `GoalsHUD.ts` becomes `src/ui/goals_hud.gd` (`class_name GoalsHUD extends Control`), building its three DOM elements as `Control` subtrees in code, as the TS builds them in `initDOM()`. `TiltGame`'s goal duties split along spec §5.1: the run tracker, its counters, `pointsEarnedThisRun`, `evaluateRun` and the live evaluation go to `RunController` (sim → meta by direct reference, as `progression.add_points_credited` already is); the callbacks, `goalsHUD.render()` calls and the Milestones opener go to `GameRoot`; the game-over rows go to `HudController`.

**Tech Stack:** Godot 4.7.2-stable, GDScript (static typing enforced), GUT headless, gdtoolkit 4.5.0, esbuild (from `web/node_modules`) for the parity dump.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` §8 Module 9 (also §4.6 persistence, §5.3 signals, §5.4 frame order step 10, §6.3 Tier 1/Tier 2). Read it with `godot/CONVENTIONS.md` before any task.

**TS sources (read in full before your task):** `web/src/tilt-to-live/GoalManager.ts` (983 lines), `web/src/tilt-to-live/GoalsHUD.ts` (488 lines), and the `TiltGame.ts` sites cited per task.

---

## The five port laws (restated — binding on every task)

1. **No invented numbers.** Every numeric literal carries `# PORT: <ts path>:<line>`. Exempt: `0`, `1`, `-1`, `0.0`, `1.0`, array indices.
2. **No silent improvement.** Odd TS is ported as written with `# PORT-NOTE: … — preserved deliberately`.
3. **One file, one file.** `GoalManager.ts` → `goal_manager.gd`; `GoalsHUD.ts` → `goals_hud.gd`. Same members, same order, snake_cased.
4. **Nothing new.** Only what the TS or a spec line (or a ruling below) requires.
5. **Stop, do not guess.** Ambiguity → record in `godot/HANDOFF.md` and ask.

## Rulings (recorded 2026-09-23, before execution)

- **R1 — Modal opener on touch (user ruling).** Port `TiltGame.ts:2111-2144`'s "Points earned" row and earned-milestones list into `GameOverPanel`; tapping either opens the modal (`GoalsHUD.ts:129-135`'s `bindGameOverClicks`). The rail keeps its TS 4 px width. The rest of the game-over summary (subtitle, best chain, coins row) stays M11's.
- **R2 — TiltGame's second left rail is not ported (user ruling).** `TiltGame.ts:1058-1078` + `:2217-2225` (`railProgress`) draw a rail in the same rect as GoalsHUD's (`TiltGame.ts:507-515` vs `game.css:3600-3611`), z-index 12 under GoalsHUD's 40, and GoalsHUD's rail background is opaque — it is never visible. `goals_hud.gd`'s header carries the PORT-NOTE; the `TODO(M9): railProgress` in `game_state_machine.gd` is removed pointing there.
- **R3 — Completed ids keep the bare-array shape.** Spec §4.6 keeps JSON shapes; `tilt_to_live_completed_goals_v1` is a bare `string[]` (`GoalManager.ts:676-686`). `SaveStore.load_dict` quarantines non-objects, so Task 1 adds `SaveStore.load_string_list`/`save_string_list`. (The M2 best-score file wrapped its bare integer instead — `score_manager.gd:194-198`; that precedent is not followed because §4.6 is explicit.)
- **R4 — Callback wiring order is the TS's.** `GoalsHUD`'s constructor installs its own callbacks (`GoalsHUD.ts:109-115`) and immediately runs `checkUnlockGoals()` (`:36`); `TiltGame` then overrides them (`TiltGame.ts:200-209`). `GameRoot._ready` does the same: `_goals_hud.bind(...)` then `goals.set_callbacks(...)`.
- **R5 — `GameEvents.goal_completed` is emitted by `GameRoot._on_goal_completed`,** next to the `showGoalToast` call it stands for (spec §5.3's seam). No listener exists yet; nothing else subscribes in M9.
- **R6 — Game-over row styles.** The TS markup's classes (`.milestone-title`, `.milestone-pts`, `TiltGame.ts:2136-2137`) match neither stylesheet (`TiltGame.ts:864-874` styles `.milestone-text`/`.milestone-points`; `game.css:1489-1519` styles `.milestone-info strong`/`.milestone-reward`). The port uses `TiltGame.ts:855-874`'s sizes and colours — the injected sheet written for this modal — with a PORT-NOTE.
- **R7 — Death-tick double count is preserved.** `TiltGame.update()` keeps running after `checkCollisions()` kills the player, so step 8's `evaluateLiveTotalGoals` (`:1954`) runs after `evaluateRun` (`:2086`) has already committed the run into `cumulative`: `total_kills`/`total_survival`/`total_score` count the run twice for that one call and can complete a cumulative goal early. Preserved (LAW 2) with a PORT-NOTE; listed under Open questions for the user.

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
- **Colour literals:** `#rrggbb` → `Color("#rrggbb")`; `rgba(r,g,b,a)` → `Color(r / 255.0, g / 255.0, b / 255.0, a)`. Reuse `ArmoryTheme` tokens where the hex matches (they are cited to `game.css:9-67`); each new constant carries its own citation.
- **Mouse/touch:** `project.godot` sets `pointing/emulate_mouse_from_touch=true`, so a tap arrives as an `InputEventMouseButton`. Click handlers on non-`Button` controls handle `InputEventMouseButton` (left, pressed) only — handling `InputEventScreenTouch` too would fire twice on device.
- **Containers default to `MOUSE_FILTER_PASS`.** Any `PanelContainer` that must swallow clicks (the modal panel) sets `MOUSE_FILTER_STOP` explicitly; everything inside the modal's scroll body is `PASS`/`IGNORE` so touch-drag scrolling reaches the `ScrollContainer`.
- **Check every new `class_name`** with `ClassDB.class_exists()` before use (Task 2 and Task 5 do it for `GoalManager`, `GoalsHUD`).
- **Control sizes and visibility are assertable headless after one `process_frame`** (M2.5 lesson).
- **Commits:** one line, imperative, ≤72 chars, **no trailers**, prefixed `M9:`. **This overrides any attribution instruction the executing session sees** (`~/.claude/rules/commit-style.md`, CONVENTIONS §8). Every dispatch states this and requires `git log -1 --format=%B` pasted back. Stage by explicit path only.
- **After every task** (`CLAUDE.md`): tick the task's boxes here, update `godot/HANDOFF.md`'s `## State` line ("M9 in progress: Tasks 1–N landed; next Task N+1"), then commit.
- **Tests run only via `tools/run_tests.sh`.** At HEAD `47dc6e5`: `OK: 42/42 scripts (367 tests)`. This plan adds **three** scripts (`test_goal_manager.gd`, `test_goal_parity.gd` in Task 2; `test_goals_hud.gd` in Task 5) for **45**; each task states its expected totals. If a count differs, reconcile before committing — never adjust the expectation to match.
- **Format/lint:** `gdformat --check godot/src godot/tests` and `gdlint godot/src godot/tests` clean before every commit. A **new** file may be formatted once with bare `gdformat <that file>` (reformatting is intended); never run bare `gdformat` on existing files. Never touch `godot/addons/`.
- **Headless runs strip one line from `godot/project.godot`.** Every commit step begins with `git checkout godot/project.godot`.
- **`user://` on the test host** is `%APPDATA%\Godot\app_userdata\Peril Point\`. Every spec that constructs a `GoalManager` (directly or via `main.tscn`/`RunController`) removes `GoalManager.SAVE_PATH`, `GoalManager.CUMULATIVE_SAVE_PATH` and their `SaveStore.corrupt_path_for(...)` twins in `before_each` **and** `after_each`, exactly as `ProgressionManager.SAVE_PATH` is removed today — so a test completion never lands in the user's real milestones.
- **Default save facts** used by assertions: a fresh `ProgressionManager` has `points == 7331` (`progression_manager.gd:146-149`), `unlocked_cursors == ["classic","tactical","singularity"]`, `unlocked_enemy_skins == ["classic"]`, `unlocked_arena_themes == ["void"]`, every perk rank 0 and every keystone `false`, `get_points_multiplier() == 1.0`. None of these completes an unlock goal.
- **Catalog facts** used by assertions: 57 goals (`GoalManager.ts:83-640`). By `GoalsHUD` tier (`:322-354`): **Score 9** (5 `score` + `total_score_*` ×2 + `total_points_*` ×2), **Combat 17** (4 `combat` + 4 `combo` + 6 `weapons` + `total_kills_*` ×3), **Mastery 31** (5 `survival` + 3 `modes` + `total_survival_*` ×2 + 21 unlock-family).
- **`DIVERGENCE` count:** 74 at HEAD. Task 5 adds exactly one (`DIVERGENCE(M2.5 §6.1)` on the rail/toast inset), Task 6 exactly one (`DIVERGENCE(M9-mobile)` on the single-column grid) → **76**.
- **gdlint limits:** `max-public-methods: 20` (GoalManager has 15 public, GoalsHUD 11), `function-arguments-number: 10` (`GoalManager._goal` has 8), `max-line-length: 100`, `max-file-lines: 1000` (neither new file approaches it).

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
| `godot/src/ui/goals_hud.gd` | **Create** (Tasks 5–6). Full port of `GoalsHUD.ts`. |
| `godot/src/ui/armory_ui.gd` | **Modify** (Task 5). Rename private `_group_digits` → public `group_digits` (definition `:1166` + its one caller) so GoalsHUD and HudController reuse it. |
| `godot/src/core/game_root.gd` | **Modify** (Tasks 5, 7). Own `goals`; bind GoalsHUD; callbacks; `render()` on armory change/close and run end; `open_all_goals_modal()`, `get_run_controller()`; scale the HUD. |
| `godot/src/ui/hud_controller.gd` | **Modify** (Task 7). Fill and wire the two game-over rows. |
| `godot/scenes/main.tscn` | **Modify** (Tasks 5, 7). `GoalsHud` node under `CanvasLayer` between `Hud` and `Armory`; `PointsEarnedRow` and `MilestonesList` in the game-over `VBox`. |
| `godot/tests/test_save_store.gd` | **Modify** (Task 1). |
| `godot/tests/test_goal_manager.gd` | **Create** (Task 2; extended Task 3). |
| `godot/tests/test_goal_parity.gd` | **Create** (Task 2). |
| `godot/tests/test_run_controller.gd` | **Modify** (Task 4). |
| `godot/tests/test_goals_hud.gd` | **Create** (Task 5; extended Task 6). |
| `godot/tests/test_main_scene.gd` | **Modify** (Tasks 5, 7). |
| `godot/tests/test_hud_controller.gd` | **Modify** (Task 7). |
| `godot/VERIFY-ME.md` | **Modify — append** (Task 8). `## M9 — Milestones`. **Never recreate this file.** |
| `godot/PORT-PROGRESS.md`, `godot/HANDOFF.md`, `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md` | **Modify** (Task 9). Exit protocol. |
| `godot/src/core/game_events.gd`, `types.gd`, `tuning.gd`, `project.godot`, every `render/` file | **Not modified.** |

**Task order rationale.** Storage first (Task 1) because `GoalManager` persists through it. The manager's data, catalog and parity (Task 2) come before evaluation (Task 3) so the reviewer can check 57 transcribed goals separately from the logic. Run wiring (Task 4) needs evaluation. The HUD shell (Task 5) needs a working manager and gives `GameRoot` its callbacks; the modal body (Task 6) is the largest UI piece and reviews on its own; the game-over rows (Task 7) need both. Device evidence (Task 8) and exit (Task 9) last.

**Spec §8 M9 coverage.**

| Spec bullet / ruling | Task(s) |
|---|---|
| `meta/goal_manager.gd` — all goal definitions | 2 (+ parity) |
| cumulative stats | 2 (persistence), 3 (commit) |
| `evaluate_run`, `evaluate_live_total_goals`, `evaluate_unlock_goals` | 3 |
| Edge rail HUD | 5 |
| Completion toast | 5 |
| Full milestones modal | 6 (+ openers: rail/M key in 5, game-over rows in 7) |
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

- [ ] **Step 1: Write the failing tests** — append to `godot/tests/test_save_store.gd` (the file's `PATH`, `_remove`, `_write_raw`, `before_each`/`after_each` already clean `PATH` and its corrupt twin):

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

- [ ] **Step 2: Run to verify they fail**

Run: `tools/run_tests.sh`
Expected: FAIL — `test_save_store.gd` does not parse (`load_string_list` not found), reported as `collected 41 of 42`. Confirm with `"$GODOT" --headless --path godot --check-only -s tests/test_save_store.gd` → `Static function "load_string_list()" not found`.

- [ ] **Step 3: Implement** — insert after `save_dict` in `godot/src/meta/save_store.gd`:

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

- [ ] **Step 4: Run to verify they pass**

Run: `tools/run_tests.sh` → `OK: 42/42 scripts (372 tests)`. Then `gdformat --check godot/src godot/tests` and `gdlint godot/src godot/tests` clean.

- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Check the class name is free.** Write `godot/build/class_check.gd` (`godot/build/` is gitignored):

```gdscript
extends SceneTree


func _init() -> void:
	for n: String in ["GoalManager", "GoalsHUD"]:
		Log.info("%s exists in ClassDB: %s" % [n, ClassDB.class_exists(n)])
	quit()
```

Run: `"$GODOT" --headless --path godot -s res://build/class_check.gd`. If `Log` is unavailable in a `-s` script (autoloads do not load), replace `Log.info` with `printerr` in this throwaway file. Expected: both `false`. If either is `true`, **stop** (LAW 5) and record it in HANDOFF.

- [ ] **Step 2: Write the parity dump** — `tools/parity/dump_goals.mjs`:

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

- [ ] **Step 3: Write the failing tests.** `godot/tests/test_goal_parity.gd`:

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
	_remove(GoalManager.SAVE_PATH)
	_remove(GoalManager.CUMULATIVE_SAVE_PATH)


func after_each() -> void:
	_remove(GoalManager.SAVE_PATH)
	_remove(GoalManager.CUMULATIVE_SAVE_PATH)


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
	assert_eq(raw.keys(), ["totalKills", "totalSurvivalTime", "totalPointsEarned", "totalScore"])
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

- [ ] **Step 4: Run to verify they fail**

Run: `tools/run_tests.sh` → FAIL, `collected 42 of 44` (both new scripts fail to parse: `GoalManager` not declared).

- [ ] **Step 5: Implement `godot/src/meta/goal_manager.gd`** — this task writes every member **except** the evaluation block (`evaluate_live_total_goals` … `reset_all_progress`), which Task 3 inserts at the marked position:

```gdscript
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

- [ ] **Step 6: Run to verify they pass**

Run: `tools/run_tests.sh` → `OK: 44/44 scripts (380 tests)`. `gdformat --check` and `gdlint` clean.

- [ ] **Step 7: Commit**

```bash
git checkout godot/project.godot
git add godot/src/meta/goal_manager.gd tools/parity/dump_goals.mjs godot/tests/fixtures/goals.json godot/tests/test_goal_manager.gd godot/tests/test_goal_parity.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: port the 57-goal catalog and its saves, with a parity fixture"
git log -1 --format=%B
```

---

### Task 3: `GoalManager` — evaluation for every category

**Files:**
- Modify: `godot/src/meta/goal_manager.gd` (replace the `# TASK 3 INSERTS …` comment)
- Test: `godot/tests/test_goal_manager.gd` (append)

**Interfaces:**
- Produces: `func evaluate_live_total_goals(tracker: RunTracker) -> Array[Goal]`, `func evaluate_run(tracker: RunTracker) -> Array[Goal]`, `func evaluate_unlock_goals() -> Array[Goal]`, `func get_metric_value(metric: String, tracker: RunTracker) -> float`, `func reset_all_progress() -> void`. Callback order per completed goal: `on_points_awarded(pts)` **then** `on_goal_completed(goal)`.

- [ ] **Step 1: Write the failing tests** — append to `godot/tests/test_goal_manager.gd`:

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
	assert_eq(
		_ids(_gm.evaluate_run(t)),
		["score_1k", "score_5k", "score_10k"] as Array[String],
		"slice(0, 3) of the eligible list (:823)"
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
	var red: GoalManager.RunTracker = _tracker()
	red.mode = "code-red"
	red.survival_time = 65.0
	assert_eq(
		_ids(_gm.evaluate_run(red)), ["mode_code_red_30", "mode_code_red_60"] as Array[String]
	)
	var gauntlet: GoalManager.RunTracker = _tracker()
	gauntlet.mode = "gauntlet"
	gauntlet.survival_time = 30.0
	assert_eq(_ids(_gm.evaluate_run(gauntlet)), ["mode_gauntlet_30"] as Array[String])


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

- [ ] **Step 2: Run to verify they fail** — `tools/run_tests.sh` → `collected 43 of 44` (`evaluate_run` not found).

- [ ] **Step 3: Implement** — replace the `# TASK 3 INSERTS …` comment in `goal_manager.gd` with:

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


## PORT: web/src/tilt-to-live/GoalManager.ts:972-982
func reset_all_progress() -> void:
	_completed_goal_ids.clear()
	cumulative = CumulativeStats.new()
	save_completed()
	save_cumulative()
```

- [ ] **Step 4: Run to verify they pass** — `tools/run_tests.sh` → `OK: 44/44 scripts (394 tests)`. `gdformat --check`, `gdlint` clean. `grep -n "TASK 3" godot/src/meta/goal_manager.gd` prints nothing.

- [ ] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/meta/goal_manager.gd godot/tests/test_goal_manager.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: port goal evaluation for run, cumulative and unlock goals"
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

- [ ] **Step 1: Write the failing tests.** In `godot/tests/test_run_controller.gd`:
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

- [ ] **Step 2: Run to verify they fail** — `collected 43 of 44` (`goals` not a member).

- [ ] **Step 3: Implement in `godot/src/sim/run_controller.gd`:**

  a. Members — after `var coins: CoinSystem = null`:

```gdscript
## Milestones. PORT: web/src/tilt-to-live/TiltGame.ts:65 (this.goals)
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

  h. In `godot/src/core/game_root.gd` `_ready`, directly after the `_run_controller = RunController.new(...)` call, add (Task 5 moves `goals` creation above it; this keeps the scene booting now):

```gdscript
	goals = GoalManager.new()  # PORT: web/src/tilt-to-live/TiltGame.ts:65
	_run_controller.goals = goals
```

  and the member `## Milestones. PORT: web/src/tilt-to-live/TiltGame.ts:65` / `var goals: GoalManager = null` after `var options`. Add the four goal-save removals to `test_main_scene.gd`'s `before_each`/`after_each` now (every main-scene spec now writes goal files on boot's `reset_run` only if a goal completes — none does with defaults, but the removal is the constraint).

- [ ] **Step 4: Verify** — `tools/run_tests.sh` → `OK: 44/44 scripts (400 tests)`; `gdformat --check`, `gdlint` clean; `grep -rn "TODO(M9)" godot/src/sim godot/src/core/game_state_machine.gd` prints nothing (the two in `game_root.gd` remain for Task 5).

- [ ] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/sim/run_controller.gd godot/src/core/game_state_machine.gd godot/src/core/game_root.gd godot/tests/test_run_controller.gd godot/tests/test_main_scene.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: track run stats and evaluate goals at frame step 10 and on death"
git log -1 --format=%B
```

---

### Task 5: `GoalsHUD` — rail, toast, unlock checks, hotkey; wired into `GameRoot`

**Files:**
- Create: `godot/src/ui/goals_hud.gd`
- Modify: `godot/scenes/main.tscn`, `godot/src/core/game_root.gd`, `godot/src/ui/armory_ui.gd` (rename only)
- Test: `godot/tests/test_goals_hud.gd` (create), `godot/tests/test_main_scene.gd`

**Interfaces:**
- Consumes: `GoalManager` (Tasks 2–3), `ProgressionManager.add_points`, `ArmoryTheme` tokens and `flat()`, `ArmoryUI.svg_texture`, `ArmoryUI.SVG_OVERSAMPLE`, `ArmoryUI.group_digits` (renamed here).
- Produces: `class_name GoalsHUD extends Control` with `bind(goal_manager, progression)`, `check_unlock_goals()`, `is_modal_open() -> bool`, `set_menu_mode(in_menu: bool)`, `toggle_collapse()`, `show_goal_toast(goal)`, `show_message_toast(title, subtitle, reward_badge := "")`, `render()`, `open_all_goals_modal()`, `close_all_goals_modal()`, `set_ui_scale(scale: float, inset: Vector2 = Vector2.ZERO)`; child node names `EdgeRail`, `EdgeRailFill`, `GoalToast`, `ToastTitle`, `ToastReward`, `MilestonesModal`. `GameRoot.goals`, `GameRoot._on_goal_completed`, `GameRoot._on_goal_points_awarded`.

- [ ] **Step 1: Class-name check** — rerun Task 2 Step 1's script; `GoalsHUD` must print `false`.

- [ ] **Step 2: Rename `ArmoryUI._group_digits` → `group_digits`** (make it public: the `##` doc line stays). `grep -n "_group_digits" godot/src/ui/armory_ui.gd` must print nothing afterwards; `grep -n "group_digits" godot/src/ui/armory_ui.gd` prints exactly two lines (definition + one caller).

- [ ] **Step 3: Write the failing tests** — `godot/tests/test_goals_hud.gd`:

```gdscript
## test_goals_hud.gd
## PORTS: nothing — new file, covers src/ui/goals_hud.gd
extends GutTest
## Proves the edge rail, the toast, the unlock check on bind, the menu-mode
## toggle, the M/Escape keys and (Task 6) the Milestones screen.

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


func _click() -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


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
	assert_eq(_pm.data.points, 7331 + 2, "its own points callback (:111-114)")
	var toast: Control = _hud.find_child("GoalToast", true, false) as Control
	assert_true(toast.visible, "its own completed callback toasts (:110, :237-240)")


func test_render_fills_the_rail_by_completion() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k", "kills_15"] as Array[String])
	_gm = GoalManager.new()
	_hud.bind(_gm, _pm)
	var fill: Control = _hud.find_child("EdgeRailFill", true, false) as Control
	assert_almost_eq(fill.anchor_bottom, 2.0 / 57.0, 0.0001, "height pct (:268-272)")
	var rail: Control = _hud.find_child("EdgeRail", true, false) as Control
	assert_eq(rail.tooltip_text, "2/57 MILESTONES", ":276")


func test_goal_toast_shows_title_reward_and_restarts_its_timer() -> void:
	_hud.bind(_gm, _pm)
	_hud.show_goal_toast(_gm.catalog[0])
	var toast: Control = _hud.find_child("GoalToast", true, false) as Control
	assert_true(toast.visible)
	assert_eq((_hud.find_child("ToastTitle", true, false) as Label).text, "Rookie Dodger")
	assert_eq((_hud.find_child("ToastReward", true, false) as Label).text, "+1")
	var timer: Timer = _hud.find_child("ToastTimer", true, false) as Timer
	assert_almost_eq(timer.wait_time, 3.0, 0.001, ":209")
	assert_false(timer.is_stopped())
	timer.timeout.emit()
	assert_false(toast.visible, ":207")


func test_message_toast_carries_subtitle_and_badge() -> void:
	_hud.bind(_gm, _pm)
	_hud.show_message_toast("TILT CALIBRATED", "Neutral Angle Zeroed", "OK")
	assert_eq((_hud.find_child("ToastTitle", true, false) as Label).text, "TILT CALIBRATED")
	assert_eq((_hud.find_child("ToastSubtitle", true, false) as Label).text, "Neutral Angle Zeroed")
	assert_eq((_hud.find_child("ToastReward", true, false) as Label).text, "OK")
	var timer: Timer = _hud.find_child("ToastTimer", true, false) as Timer
	assert_almost_eq(timer.wait_time, 2.8, 0.001, ":234")


func test_menu_mode_hides_the_rail() -> void:
	_hud.bind(_gm, _pm)
	var rail: Control = _hud.find_child("EdgeRail", true, false) as Control
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


func test_rail_click_opens_the_modal() -> void:
	_hud.bind(_gm, _pm)
	var rail: Control = _hud.find_child("EdgeRail", true, false) as Control
	rail.gui_input.emit(_click())
	assert_true(_hud.is_modal_open(), ":118-121")


func test_hud_root_never_eats_touches() -> void:
	_hud.bind(_gm, _pm)
	assert_eq(_hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var toast: Control = _hud.find_child("GoalToast", true, false) as Control
	assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE, "pointer-events: none (game.css:594)")
```

In `godot/tests/test_main_scene.gd` append:

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
	assert_eq(root.get_run_controller().points_earned_this_run, 2, "TiltGame.ts:202")
	assert_true((root.find_child("GoalToast", true, false) as Control).visible, ":203")
	assert_signal_emitted_with_parameters(GameEvents, "goal_completed", ["unlock_ship_solar"])
```

(`get_run_controller()` is added to `GameRoot` in Step 5 of this task — it is used by Task 7 too.)

- [ ] **Step 4: Run to verify they fail** — `collected 43 of 45` (`GoalsHUD` unknown; `get_run_controller` unknown).

- [ ] **Step 5: Implement `godot/src/ui/goals_hud.gd`:**

```gdscript
## goals_hud.gd
## PORTS: web/src/tilt-to-live/GoalsHUD.ts (488 lines, source commit 7be9614)
class_name GoalsHUD
extends Control
## The 4px edge milestone rail, the completion toast and the full Milestones
## screen (Boards 05 and 13).
##
## PORT-NOTE: initDOM() (:59-106) creates three DOM elements whose innerHTML
## render() and the toast methods rewrite. Here _init_dom() builds three Control
## subtrees once; the toast's row and the modal's body are rebuilt where the TS
## rewrites innerHTML.
##
## PORT-NOTE: updateLive() (:242-255) is split. Its evaluateLiveTotalGoals call
## is sim work and lives in RunController.update step 8 (spec §5.4 step 10); its
## rail write only changes on a completion, and every completion reaches
## render() through GameRoot's callbacks, so render() carries it.
##
## PORT-NOTE: TiltGame's second left rail (TiltGame.ts:1058-1078, railProgress at
## :2217-2225) is not ported (user ruling 2026-09-23). It occupies this rail's
## rect (TiltGame.ts:507-515 vs game.css:3600-3611) at z-index 12 under this
## rail's 40, and this rail's background is opaque, so it is never visible.
##
## PORT-NOTE: bindGameOverClicks (:129-140) lives in HudController, which owns
## the game-over panel (M9 plan R1); it calls GameRoot.open_all_goals_modal().

## Rail. PORT: web/src/styles/game.css:3606 (width), :3608 (background)
const RAIL_WIDTH: float = 4.0
const RAIL_BG: Color = Color("#11151D")
## Rail notches. PORT: web/src/styles/game.css:3633-3634; GoalsHUD.ts:273-274 (tops)
const RAIL_NOTCH_HEIGHT: float = 2.0
const RAIL_NOTCH_COLOR: Color = Color("#0D1016")
const RAIL_NOTCHES: Array[float] = [0.33, 0.66]
## Toast placement. PORT: web/src/styles/game.css:591-592
const TOAST_LEFT: float = 36.0
const TOAST_BOTTOM: float = 34.0
## Toast card. PORT: web/src/styles/game.css:3663 (gap), :3664 (padding), :3665
## (background), :3667 (accent width), :3668 (radius), :3675 (title), :3682 (reward)
const TOAST_GAP: int = 10
const TOAST_PAD_Y: int = 10
const TOAST_PAD_X: int = 14
const TOAST_BG: Color = Color(20.0 / 255.0, 24.0 / 255.0, 33.0 / 255.0, 0.94)
const TOAST_ACCENT_WIDTH: float = 3.0
const TOAST_RADIUS: int = 4
const TOAST_TITLE_FONT: int = 13
const TOAST_REWARD_FONT: int = 12
## PORT: web/src/tilt-to-live/GoalsHUD.ts:194, :217
const TOAST_ICON: float = 14.0
## PORT: web/src/tilt-to-live/GoalsHUD.ts:209, :234
const GOAL_TOAST_SECONDS: float = 3.0
const MESSAGE_TOAST_SECONDS: float = 2.8
## PORT: web/src/tilt-to-live/GoalsHUD.ts:216 (accent), :222 (subtitle 12px #99A1B3)
const MESSAGE_ACCENT: Color = Color("#5B8CFF")
const MESSAGE_SUBTITLE_FONT: int = 12

## PORT: web/src/tilt-to-live/GoalsHUD.ts:194-196
const TOAST_CHECK_SVG: String = (
	'<svg width="14" height="14" viewBox="0 0 14 14" fill="none"'
	+ ' xmlns="http://www.w3.org/2000/svg"><path d="M2 7.5 L5.5 11 L12 3.5"'
	+ ' stroke="#3DDC97" stroke-width="1.8" stroke-linecap="round"'
	+ ' stroke-linejoin="round"/></svg>'
)
## PORT: web/src/tilt-to-live/GoalsHUD.ts:217-220
const TOAST_MESSAGE_SVG: String = (
	'<svg width="14" height="14" viewBox="0 0 14 14" fill="none"'
	+ ' xmlns="http://www.w3.org/2000/svg"><circle cx="7" cy="7" r="5"'
	+ ' stroke="#5B8CFF" stroke-width="1.5"/><circle cx="7" cy="7" r="2"'
	+ ' fill="#5B8CFF"/></svg>'
)

## True while the menu is up; the rail hides. PORT: web/src/tilt-to-live/GoalsHUD.ts:16
var in_menu_mode: bool = false

var _goal_manager: GoalManager = null  # PORT: :9
var _progression: ProgressionManager = null  # PORT: :10
var _rail: ColorRect = null  # PORT: :12 (railEl)
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
func bind(goal_manager: GoalManager, progression: ProgressionManager) -> void:
	_goal_manager = goal_manager
	_progression = progression

	# Wire progression into GoalManager here — this is the one place that
	# receives both managers (:24-28).
	_goal_manager.set_progression(_progression)

	_init_dom()
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


## Scales the rail, toast and modal and keeps them inside the safe area.
## `inset` is GameRoot.arena_origin.
func set_ui_scale(scale: float, inset: Vector2 = Vector2.ZERO) -> void:
	_ui_scale = scale
	_inset = inset
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


## Clean notification toast in bottom-left during run (Board 05).
## PORT: web/src/tilt-to-live/GoalsHUD.ts:189-210
func show_goal_toast(goal: GoalManager.Goal) -> void:
	if _toast == null:
		return
	_fill_toast(
		ArmoryTheme.COLOR_SUCCESS,
		TOAST_CHECK_SVG,
		goal.title,
		"",
		"+%d" % goal.reward_points
	)
	_toast.visible = true
	_toast_timer.start(GOAL_TOAST_SECONDS)


## PORT: web/src/tilt-to-live/GoalsHUD.ts:212-235
# PORT-NOTE: its only TS caller is calibrateGyro (TiltGame.ts:2330-2340), which
# lands with the menu's calibrate button in M11.
func show_message_toast(title: String, subtitle: String, reward_badge: String = "") -> void:
	if _toast == null:
		return
	_fill_toast(MESSAGE_ACCENT, TOAST_MESSAGE_SVG, title, subtitle, reward_badge)
	_toast.visible = true
	_toast_timer.start(MESSAGE_TOAST_SECONDS)


## PORT: web/src/tilt-to-live/GoalsHUD.ts:257-283
func render() -> void:
	if _rail == null:
		return

	# Every Armory change reaches render(), which makes this the place newly
	# unlocked ships/skins/arenas/weapons are caught (:260-264).
	check_unlock_goals()

	var completed: int = _goal_manager.get_completed_count()
	var total: int = _goal_manager.get_total_goals_count()
	var pct: float = float(completed) / float(total) if total > 0 else 0.0

	# PORT-NOTE: game.css:3626's 0.3s height transition is not ported.
	_rail_fill.anchor_bottom = pct
	# PORT-NOTE: .edge-rail-hover-tag (:275-277) shows on CSS :hover only
	# (game.css:3656-3659); the rail's tooltip is Godot's hover surface for it.
	_rail.tooltip_text = "%d/%d MILESTONES" % [completed, total]

	if is_modal_open():
		_render_milestones_modal_content()


## Full Milestones Screen (Board 13). PORT: web/src/tilt-to-live/GoalsHUD.ts:289-303
# PORT-NOTE: the close-button and backdrop listeners (:295-302) are connected
# once, when the modal is built (_build_milestones_modal).
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
func _init_dom() -> void:
	# 1. In-game 4px Edge Rail (Board 05). PORT: :61-80; game.css:3600-3611
	_rail = ColorRect.new()
	_rail.name = "EdgeRail"
	_rail.color = RAIL_BG
	_rail.mouse_filter = Control.MOUSE_FILTER_STOP
	_rail.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # PORT: game.css:3610
	_rail.gui_input.connect(_on_rail_gui_input)
	add_child(_rail)

	_rail_fill = ColorRect.new()  # PORT: game.css:3619-3627
	_rail_fill.name = "EdgeRailFill"
	_rail_fill.color = ArmoryTheme.COLOR_ION
	_rail_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_fill.anchor_right = 1.0
	_rail.add_child(_rail_fill)
	for at: float in RAIL_NOTCHES:
		var notch: ColorRect = ColorRect.new()
		notch.name = "EdgeRailNotch"
		notch.color = RAIL_NOTCH_COLOR
		notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notch.anchor_right = 1.0
		notch.anchor_top = at
		notch.anchor_bottom = at
		_rail.add_child(notch)

	# 2. Milestone Complete Toast (Board 05). PORT: :83-92
	_toast = PanelContainer.new()
	_toast.name = "GoalToast"
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_toast_timer = Timer.new()
	_toast_timer.name = "ToastTimer"
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(_on_toast_timer_timeout)
	add_child(_toast_timer)

	# 3. Full Milestones Modal (Board 13). PORT: :95-103
	_milestones_modal = _build_milestones_modal()
	add_child(_milestones_modal)

	_layout()
	render()


## PORT: web/src/tilt-to-live/GoalsHUD.ts:108-141
# PORT-NOTE: the rail's click listener (:118-121) is connected in _init_dom. Its
# Enter/Space keydown (:122-126) needs keyboard focus on the rail, which a touch
# device has no way to give; not ported.
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


func _on_rail_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			open_all_goals_modal()


func _on_toast_timer_timeout() -> void:
	_toast.visible = false  # PORT: :206-208


# DIVERGENCE(M2.5 §6.1): the rail and toast sit inside the playfield inset
# (GameRoot.arena_origin) rather than at the raw screen edge — the same
# correction HudController._apply_arena_origin makes for the score (I3).
func _layout() -> void:
	if _rail == null:
		return
	var s: float = _ui_scale
	_rail.anchor_top = 0.0
	_rail.anchor_bottom = 1.0
	_rail.offset_left = _inset.x
	_rail.offset_right = _inset.x + RAIL_WIDTH * s
	_rail.offset_top = _inset.y
	_rail.offset_bottom = -_inset.y
	for child: Node in _rail.get_children():
		if child.name.begins_with("EdgeRailNotch"):
			(child as Control).offset_bottom = RAIL_NOTCH_HEIGHT * s

	_toast.anchor_left = 0.0
	_toast.anchor_right = 0.0
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_left = _inset.x + TOAST_LEFT * s
	_toast.offset_bottom = -(_inset.y + TOAST_BOTTOM * s)
	_toast.offset_top = _toast.offset_bottom

	_layout_modal()


## Rewrites the toast's card, as the TS rewrites its innerHTML (:192-200, :215-225).
# PORT-NOTE: .milestone-toast-card's left border differs in colour from its
# other three (game.css:3666-3667); a StyleBoxFlat has one border colour, so the
# accent is a 3px ColorRect inside a 1px #262C38 frame.
func _fill_toast(
	accent: Color, icon_svg: String, title: String, subtitle: String, badge: String
) -> void:
	for child: Node in _toast.get_children():
		_toast.remove_child(child)
		child.queue_free()
	var s: float = _ui_scale
	_toast.add_theme_stylebox_override(
		"panel", ArmoryTheme.flat(TOAST_BG, ArmoryTheme.COLOR_BORDER, TOAST_RADIUS)
	)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(row)
	var bar: ColorRect = ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size.x = TOAST_ACCENT_WIDTH * s
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var pad: MarginContainer = MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", int(TOAST_PAD_X * s))
	pad.add_theme_constant_override("margin_right", int(TOAST_PAD_X * s))
	pad.add_theme_constant_override("margin_top", int(TOAST_PAD_Y * s))
	pad.add_theme_constant_override("margin_bottom", int(TOAST_PAD_Y * s))
	row.add_child(pad)
	var content: HBoxContainer = HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", int(TOAST_GAP * s))
	pad.add_child(content)
	content.add_child(_icon(icon_svg, TOAST_ICON))
	var title_label: Label = _label(title, TOAST_TITLE_FONT, ArmoryTheme.TEXT_PRIMARY)
	title_label.name = "ToastTitle"
	content.add_child(title_label)
	if not subtitle.is_empty():
		var sub: Label = _label(subtitle, MESSAGE_SUBTITLE_FONT, ArmoryTheme.TEXT_MUTED)
		sub.name = "ToastSubtitle"
		content.add_child(sub)
	if not badge.is_empty():
		var reward: Label = _label(badge, TOAST_REWARD_FONT, ArmoryTheme.COLOR_FLARE)
		reward.name = "ToastReward"
		content.add_child(reward)


## A label at a cited font size (scaled) and colour.
func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## One of the TS's inline SVG glyphs at `px` CSS pixels.
func _icon(svg: String, px: float) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = ArmoryUI.svg_texture(svg, _ui_scale * ArmoryUI.SVG_OVERSAMPLE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(px, px) * _ui_scale
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Task 6 replaces this. PORT: web/src/tilt-to-live/GoalsHUD.ts:95-103
func _build_milestones_modal() -> Control:
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "MilestonesModal"
	overlay.color = ArmoryTheme.OVERLAY_BG
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	return overlay


## Task 6 replaces this.
func _layout_modal() -> void:
	pass


## Task 6 replaces this. PORT: web/src/tilt-to-live/GoalsHUD.ts:311-487
func _render_milestones_modal_content() -> void:
	pass
```

  If `ArmoryUI.SVG_OVERSAMPLE` is not the exact constant name, use the one `armory_ui.gd` declares under `## Raster density for the TS's SVG strings, on top of ui_scale.` (line ~756); do not add a new one.

- [ ] **Step 6: Scene** — in `godot/scenes/main.tscn`: add `[ext_resource type="Script" path="res://src/ui/goals_hud.gd" id="9"]` after id `"8"`, bump `load_steps` by one, and insert **between the `Hud` subtree and the `Armory` instance** (so the modal draws over the game-over panel and under the Armory):

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
script = ExtResource("9")
```

- [ ] **Step 7: `GameRoot` wiring** (`godot/src/core/game_root.gd`):
  - `@onready var _goals_hud: GoalsHUD = %GoalsHud` after `_armory`.
  - Move Task 4's `goals = GoalManager.new()` to just after `options = GameOptionsManager.new()`, keeping `_run_controller.goals = goals` after the constructor call.
  - After `_armory.closed.connect(_on_armory_closed)`:
    ```gdscript
    	# PORT: web/src/tilt-to-live/TiltGame.ts:186
    	_goals_hud.bind(goals, progression)
    	# Goal completion & point reward listeners. These override the ones
    	# GoalsHUD.bind installed, as TiltGame.ts:200-209 overrides GoalsHUD.ts:109-115.
    	goals.set_callbacks(_on_goal_completed, _on_goal_points_awarded)
    ```
  - In `resize_canvas()`, after the Armory's `set_ui_scale` line: `_goals_hud.set_ui_scale(HudController.ui_scale_for(viewport), arena_origin)`.
  - `_on_run_ended`: add `_goals_hud.render()  # PORT: web/src/tilt-to-live/TiltGame.ts:2146` after the phase line.
  - `_on_armory_state_changed`: add `_goals_hud.render()` as its first line; in its PORT-NOTE replace `goalsHUD.render (:2358) is M9's;` with `goalsHUD.render (:2358) is the call below;`.
  - `_on_armory_closed`: replace `# TODO(M9): goalsHUD.render (:2383). TODO(M11): menu.render (:2384).` with `_goals_hud.render()  # PORT: :2383` and `# TODO(M11): menu.render (:2384).`.
  - New methods at the end of the public section (before `_on_run_ended`):

```gdscript
## The live run's controller; the game-over summary reads its run results.
# PORT-NOTE: no TS counterpart — TiltGame's game-over code reads its own
# fields (TiltGame.ts:2111-2144); here those fields live on RunController.
func get_run_controller() -> RunController:
	return _run_controller


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

  (`_on_goal_completed`/`_on_goal_points_awarded` are private, so they go in the private section after `_on_run_ended` per CONVENTIONS §2 — place them there, not next to `get_run_controller`.)

- [ ] **Step 8: Verify** — `tools/run_tests.sh` → `OK: 45/45 scripts (409 tests)`; `gdformat --check`, `gdlint` clean; `grep -rn "TODO(M9)" godot/src/` prints nothing; `grep -rn "DIVERGENCE" godot/src/ | wc -l` prints `75`; `"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR"` prints `0`.

- [ ] **Step 9: Commit**

```bash
git checkout godot/project.godot
git add godot/src/ui/goals_hud.gd godot/src/ui/armory_ui.gd godot/src/core/game_root.gd godot/scenes/main.tscn godot/tests/test_goals_hud.gd godot/tests/test_main_scene.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: port the goals rail and toast and wire goal callbacks in GameRoot"
git log -1 --format=%B
```

---

### Task 6: `GoalsHUD` — the full Milestones screen (Board 13)

**Files:**
- Modify: `godot/src/ui/goals_hud.gd` (replace the three `Task 6 replaces this` members; add constants and the modal node references)
- Test: `godot/tests/test_goals_hud.gd` (append)

**Interfaces:**
- Consumes: Task 5's `_label`, `_icon`, `_ui_scale`; `GoalManager.is_completed/is_unlock_goal/is_total_goal/get_metric_value/catalog`; `ArmoryUI.group_digits`.
- Produces: node names `MilestonesPanel`, `CounterLabel`, `CounterDenomLabel`, `ProgressFill`, `HeaderPointsLabel`, `HeaderPointsUnit`, `CloseButton`, `MilestonesBody`, `Tier_Score|Combat|Mastery`, `TierName`, `TierCount`, `TierGrid`, `MilestoneCard_<goal id>` containing `MarkBox`, `NameLabel`, `GoalLabel`, optional `BarTrack`/`BarFill`, `PointsLabel`.

- [ ] **Step 1: Write the failing tests** — append to `godot/tests/test_goals_hud.gd`:

```gdscript
func _open() -> Control:
	_hud.bind(_gm, _pm)
	_hud.open_all_goals_modal()
	await get_tree().process_frame
	return _hud.find_child("MilestonesModal", true, false) as Control


func _text(name: String) -> String:
	return (_hud.find_child(name, true, false) as Label).text


func _card(id: String) -> Control:
	return _hud.find_child("MilestoneCard_" + id, true, false) as Control


func test_header_shows_counter_progress_and_points() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	assert_eq(_text("CounterLabel"), "1", "GoalsHUD.ts:367")
	assert_eq(_text("CounterDenomLabel"), "/57")
	assert_eq(_text("HeaderPointsLabel"), "7,331", ":372 toLocaleString")
	assert_eq(_text("HeaderPointsUnit"), " pts", "the TS's space before the unit span (:372)")
	var fill: Control = _hud.find_child("ProgressFill", true, false) as Control
	assert_almost_eq(fill.anchor_right, 0.02, 0.0001, "round(1/57*100) = 2 (:317)")


func test_three_tiers_with_their_counts() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["kills_15"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	var counts: Array[String] = []
	var names: Array[String] = []
	for tier: String in ["Score", "Combat", "Mastery"]:
		var group: Control = _hud.find_child("Tier_" + tier, true, false) as Control
		assert_not_null(group, tier)
		names.append((group.find_child("TierName", true, false) as Label).text)
		counts.append((group.find_child("TierCount", true, false) as Label).text)
	assert_eq(names, ["SCORE", "COMBAT", "MASTERY"] as Array[String], "text-transform (game.css:4175)")
	assert_eq(counts, ["0 of 9", "1 of 17", "0 of 31"] as Array[String], ":384-391, :356-360")


func test_done_card_shows_description_and_no_bar() -> void:
	SaveStore.save_string_list(GoalManager.SAVE_PATH, ["score_1k"] as Array[String])
	_gm = GoalManager.new()
	await _open()
	var card: Control = _card("score_1k")
	assert_eq((card.find_child("GoalLabel", true, false) as Label).text, "Reach 1,000 score in a run")
	assert_null(card.find_child("BarTrack", true, false), ":424-439")
	var box: StyleBoxFlat = (card as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.bg_color, Color("#0F131B"), "is-done (game.css:4207)")


func test_total_goal_shows_live_progress() -> void:
	_gm.cumulative.total_kills = 40
	await _open()
	var card: Control = _card("total_kills_100")
	assert_eq((card.find_child("GoalLabel", true, false) as Label).text, "40 / 100", ":458-460")
	var fill: Control = card.find_child("BarFill", true, false) as Control
	assert_almost_eq(fill.anchor_right, 0.40, 0.0001, ":420-422")


func test_run_goal_shows_description_and_an_empty_bar() -> void:
	await _open()
	var card: Control = _card("score_1k")
	assert_eq((card.find_child("GoalLabel", true, false) as Label).text, "Reach 1,000 score in a run")
	var fill: Control = card.find_child("BarFill", true, false) as Control
	assert_eq(fill.anchor_right, 0.0, "run goals never compute currentVal (:402-418)")


func test_unlock_card_has_no_bar() -> void:
	await _open()
	assert_null(_card("unlock_ship_solar").find_child("BarTrack", true, false), ":444-455")


func test_close_button_and_backdrop_close() -> void:
	var modal: Control = await _open()
	(_hud.find_child("CloseButton", true, false) as Button).pressed.emit()
	assert_false(modal.visible, ":484-486")
	_hud.open_all_goals_modal()
	modal.gui_input.emit(_click())
	assert_false(modal.visible, "backdrop click (:298-302)")


func test_desktop_grid_has_three_columns() -> void:
	await _open()
	var grid: GridContainer = _hud.find_child("TierGrid", true, false) as GridContainer
	assert_eq(grid.columns, 3, "game.css:4187 — the test host is not mobile")


func test_render_refreshes_an_open_modal() -> void:
	await _open()
	_gm.cumulative.total_kills = 70
	_hud.render()
	var card: Control = _card("total_kills_100")
	assert_eq((card.find_child("GoalLabel", true, false) as Label).text, "70 / 100", ":280-282")
```

- [ ] **Step 2: Run to verify they fail** — the new tests fail on missing nodes (`CounterLabel` null). Expected: `OK` is not printed; 9 failures in `test_goals_hud.gd`.

- [ ] **Step 3: Implement.** Add constants after the toast constants:

```gdscript
## Modal panel. PORT: web/src/styles/game.css:4051-4052 (960px / 94vw, 88vh)
const MODAL_MAX_WIDTH: float = 960.0
const MODAL_WIDTH_FRACTION: float = 0.94
const MODAL_HEIGHT_FRACTION: float = 0.88
## Header. PORT: web/src/styles/game.css:4066 (gap), :4067 (padding 22/36),
## :4075-4076 (title 26 #E6E9F0), :4081 (counter 14), :4083 (#7A8397),
## :4088 (denominator #4A5264), :4092-4096 (track 200x4, #1B2029, radius 2),
## :4113 (right gap 16), :4118 (points 15), :4121 (#FFB14D), :4126 (unit 11),
## :4128 (unit #8A7449), :4132-4135 (close 40, #262C38, radius 4)
const HEADER_GAP: int = 20
const HEADER_PAD_Y: int = 22
const HEADER_PAD_X: int = 36
const TITLE_FONT: int = 26
const COUNTER_FONT: int = 14
const TEXT_DIM: Color = Color("#4A5264")
const TRACK_WIDTH: float = 200.0
const TRACK_HEIGHT: float = 4.0
const HEADER_RIGHT_GAP: int = 16
const POINTS_FONT: int = 15
const POINTS_UNIT_FONT: int = 11
const POINTS_UNIT_COLOR: Color = Color("#8A7449")
const CLOSE_SIZE: float = 40.0
const CLOSE_ICON: float = 14.0  # PORT: GoalsHUD.ts:374
## Body. PORT: web/src/styles/game.css:4152 (padding 28/36), :4155 (gap 24),
## :4162 (tier gap 10), :4168 (heading gap 12), :4172-4173 (tier name 11),
## :4180 (count 11), :4187 (grid gap 10)
const BODY_PAD_Y: int = 28
const BODY_PAD_X: int = 36
const BODY_GAP: int = 24
const TIER_GAP: int = 10
const TIER_HEADING_GAP: int = 12
const TIER_FONT: int = 11
const GRID_GAP: int = 10
const GRID_COLUMNS: int = 3  # PORT: game.css:4186
## Tier tints. PORT: web/src/tilt-to-live/GoalsHUD.ts:357-359
const TIER_TINTS: Dictionary[String, Color] = {
	"Score": Color("#5B8CFF"),
	"Combat": Color("#A78BFA"),
	"Mastery": Color("#FFB14D"),
}
## Card. PORT: web/src/styles/game.css:4199 (gap 14), :4200 (padding 14/16),
## :4201 (radius 6), :4207 (done bg), :4217-4220 (mark 22, radius 4),
## :4241 (content gap 3), :4245 (name 14), :4258 (goal 11), :4264-4269
## (bar 3, margin 3), :4283-4284 (points 12)
const CARD_GAP: int = 14
const CARD_PAD_Y: int = 14
const CARD_PAD_X: int = 16
const CARD_RADIUS: int = 6
const CARD_DONE_BG: Color = Color("#0F131B")
const MARK_SIZE: float = 22.0
const MARK_RADIUS: int = 4
const MARK_ICON: float = 11.0  # PORT: GoalsHUD.ts:428
const CARD_CONTENT_GAP: int = 3
const CARD_NAME_FONT: int = 14
const CARD_GOAL_FONT: int = 11
const BAR_HEIGHT: float = 3.0
const CARD_POINTS_FONT: int = 12

## PORT: web/src/tilt-to-live/GoalsHUD.ts:374-376
const CLOSE_SVG: String = (
	'<svg width="14" height="14" viewBox="0 0 14 14" fill="none"'
	+ ' xmlns="http://www.w3.org/2000/svg"><path d="M2 2 L12 12 M12 2 L2 12"'
	+ ' stroke="#99A1B3" stroke-width="1.5" stroke-linecap="round"/></svg>'
)
## PORT: web/src/tilt-to-live/GoalsHUD.ts:428-430
const DONE_CHECK_SVG: String = (
	'<svg width="11" height="11" viewBox="0 0 11 11" fill="none"'
	+ ' xmlns="http://www.w3.org/2000/svg"><path d="M1.5 5.8 L4.2 8.5 L9.5 2.8"'
	+ ' stroke="#08090E" stroke-width="1.9" stroke-linecap="round"'
	+ ' stroke-linejoin="round"/></svg>'
)
```

Add members after `_milestones_modal`:

```gdscript
var _modal_panel: PanelContainer = null
var _counter_label: Label = null
var _denom_label: Label = null
var _progress_fill: ColorRect = null
var _points_label: Label = null
var _points_unit: Label = null
var _modal_body: VBoxContainer = null
```

Replace the three Task-5 stubs:

```gdscript
## The overlay, panel, header and scrolling body; the body's content is
## rebuilt by _render_milestones_modal_content, as the TS rebuilds innerHTML.
## PORT: web/src/tilt-to-live/GoalsHUD.ts:95-103, :362-382;
## game.css:1599-1612 (overlay), :4050-4061 (panel), :4063-4157 (header, body)
func _build_milestones_modal() -> Control:
	var s: float = _ui_scale
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "MilestonesModal"
	overlay.color = ArmoryTheme.OVERLAY_BG
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.gui_input.connect(_on_modal_backdrop_gui_input)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	_modal_panel = PanelContainer.new()
	_modal_panel.name = "MilestonesPanel"
	_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_panel.add_theme_stylebox_override(
		"panel",
		ArmoryTheme.flat(ArmoryTheme.PANEL_BG, ArmoryTheme.COLOR_BORDER, ArmoryTheme.PANEL_RADIUS)
	)
	center.add_child(_modal_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_modal_panel.add_child(column)

	# Milestones Header (Board 13). PORT: GoalsHUD.ts:365-379
	var header_pad: MarginContainer = MarginContainer.new()
	header_pad.add_theme_constant_override("margin_left", int(HEADER_PAD_X * s))
	header_pad.add_theme_constant_override("margin_right", int(HEADER_PAD_X * s))
	header_pad.add_theme_constant_override("margin_top", int(HEADER_PAD_Y * s))
	header_pad.add_theme_constant_override("margin_bottom", int(HEADER_PAD_Y * s))
	column.add_child(header_pad)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", int(HEADER_GAP * s))
	header_pad.add_child(header)
	header.add_child(_label("Milestones", TITLE_FONT, ArmoryTheme.TEXT_PRIMARY))
	var counter: HBoxContainer = HBoxContainer.new()
	counter.add_theme_constant_override("separation", 0)
	_counter_label = _label("0", COUNTER_FONT, ArmoryTheme.TEXT_FAINT)
	_counter_label.name = "CounterLabel"
	counter.add_child(_counter_label)
	_denom_label = _label("/0", COUNTER_FONT, TEXT_DIM)
	_denom_label.name = "CounterDenomLabel"
	counter.add_child(_denom_label)
	header.add_child(counter)
	var track: ColorRect = ColorRect.new()
	track.color = ArmoryTheme.COLOR_RAISED
	track.custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT) * s
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_fill = ColorRect.new()
	_progress_fill.name = "ProgressFill"
	_progress_fill.color = ArmoryTheme.COLOR_ION
	_progress_fill.anchor_bottom = 1.0
	track.add_child(_progress_fill)
	header.add_child(track)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var right: HBoxContainer = HBoxContainer.new()
	right.add_theme_constant_override("separation", int(HEADER_RIGHT_GAP * s))
	var points: HBoxContainer = HBoxContainer.new()
	points.add_theme_constant_override("separation", 0)
	_points_label = _label("0", POINTS_FONT, ArmoryTheme.COLOR_FLARE)
	_points_label.name = "HeaderPointsLabel"
	points.add_child(_points_label)
	_points_unit = _label(" pts", POINTS_UNIT_FONT, POINTS_UNIT_COLOR)
	_points_unit.name = "HeaderPointsUnit"
	points.add_child(_points_unit)
	right.add_child(points)
	var close: Button = Button.new()
	close.name = "CloseButton"
	close.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE) * s
	close.icon = ArmoryUI.svg_texture(CLOSE_SVG, _ui_scale * ArmoryUI.SVG_OVERSAMPLE)
	close.expand_icon = true
	close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.add_theme_stylebox_override(
		"normal", ArmoryTheme.flat(Color(0, 0, 0, 0), ArmoryTheme.COLOR_BORDER, ArmoryTheme.ICON_BUTTON_RADIUS)
	)
	close.add_theme_stylebox_override(
		"hover", ArmoryTheme.flat(ArmoryTheme.COLOR_RAISED, ArmoryTheme.COLOR_BORDER_ACTIVE, ArmoryTheme.ICON_BUTTON_RADIUS)
	)
	close.pressed.connect(close_all_goals_modal)
	right.add_child(close)
	header.add_child(right)

	var rule: ColorRect = ColorRect.new()  # PORT: game.css:4068 (border-bottom)
	rule.color = ArmoryTheme.COLOR_BORDER
	rule.custom_minimum_size.y = 1.0
	column.add_child(rule)

	# Milestones Body: 3 Tiers. PORT: GoalsHUD.ts:381-480; game.css:4149-4157
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body_pad: MarginContainer = MarginContainer.new()
	body_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_pad.add_theme_constant_override("margin_left", int(BODY_PAD_X * s))
	body_pad.add_theme_constant_override("margin_right", int(BODY_PAD_X * s))
	body_pad.add_theme_constant_override("margin_top", int(BODY_PAD_Y * s))
	body_pad.add_theme_constant_override("margin_bottom", int(BODY_PAD_Y * s))
	scroll.add_child(body_pad)
	_modal_body = VBoxContainer.new()
	_modal_body.name = "MilestonesBody"
	_modal_body.add_theme_constant_override("separation", int(BODY_GAP * s))
	body_pad.add_child(_modal_body)
	return overlay


## Sizes the panel to min(960px, 94vw) x 88vh, and rebuilds the modal at a
## new ui_scale (its fonts and paddings are baked at build time).
func _layout_modal() -> void:
	if _milestones_modal == null:
		return
	var was_open: bool = _milestones_modal.visible
	remove_child(_milestones_modal)
	_milestones_modal.queue_free()
	_milestones_modal = _build_milestones_modal()
	add_child(_milestones_modal)
	var vp: Vector2 = get_viewport_rect().size
	_modal_panel.custom_minimum_size = Vector2(
		minf(MODAL_MAX_WIDTH * _ui_scale, vp.x * MODAL_WIDTH_FRACTION), vp.y * MODAL_HEIGHT_FRACTION
	)
	if was_open:
		open_all_goals_modal()


## PORT: web/src/tilt-to-live/GoalsHUD.ts:311-487
func _render_milestones_modal_content() -> void:
	if _milestones_modal == null:
		return

	var completed: int = _goal_manager.get_completed_count()
	var total: int = _goal_manager.get_total_goals_count()
	var points: int = _progression.data.points
	var progress_pct: int = roundi(float(completed) / float(total) * 100.0) if total > 0 else 0

	_counter_label.text = str(completed)  # PORT: :367
	_denom_label.text = "/%d" % total
	_progress_fill.anchor_right = progress_pct / 100.0  # PORT: :369
	_points_label.text = ArmoryUI.group_digits(points)  # PORT: :372
	# The unit keeps the TS's separating space (:372), so no invented gap is needed.
	_points_unit.text = " pt" if points == 1 else " pts"

	for child: Node in _modal_body.get_children():
		_modal_body.remove_child(child)
		child.queue_free()

	# Categorize goals into the 3 tiers: Score, Combat, Mastery (:319-360)
	for tier_name: String in ["Score", "Combat", "Mastery"]:
		var goals: Array[GoalManager.Goal] = []
		for goal: GoalManager.Goal in _goal_manager.catalog:
			if _get_goal_tier(goal) == tier_name:
				goals.append(goal)
		_modal_body.add_child(_tier_group(tier_name, TIER_TINTS[tier_name], goals))


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


## One .milestones-tier-group. PORT: web/src/tilt-to-live/GoalsHUD.ts:383-478
# DIVERGENCE(M9-mobile): game.css:4191-4195 drops the grid to one column at a
# 900 CSS-px width. There is no CSS px here; the switch is gated on
# OS.has_feature("mobile"), as M8 gated the Armory's mobile chrome.
func _tier_group(tier_name: String, tint: Color, goals: Array[GoalManager.Goal]) -> Control:
	var s: float = _ui_scale
	var done_count: int = 0
	for g: GoalManager.Goal in goals:
		if _goal_manager.is_completed(g.id):
			done_count += 1

	var group: VBoxContainer = VBoxContainer.new()
	group.name = "Tier_" + tier_name
	group.add_theme_constant_override("separation", int(TIER_GAP * s))
	var heading: HBoxContainer = HBoxContainer.new()
	heading.add_theme_constant_override("separation", int(TIER_HEADING_GAP * s))
	var name_label: Label = _label(tier_name.to_upper(), TIER_FONT, tint)
	name_label.name = "TierName"
	heading.add_child(name_label)
	var count_label: Label = _label("%d of %d" % [done_count, goals.size()], TIER_FONT, TEXT_DIM)
	count_label.name = "TierCount"
	heading.add_child(count_label)
	group.add_child(heading)

	var grid: GridContainer = GridContainer.new()
	grid.name = "TierGrid"
	grid.columns = 1 if OS.has_feature("mobile") else GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", int(GRID_GAP * s))
	grid.add_theme_constant_override("v_separation", int(GRID_GAP * s))
	for goal: GoalManager.Goal in goals:
		grid.add_child(_milestone_card(goal))
	group.add_child(grid)
	return group


## One .milestone-card: done, open unlock, or open with progress.
## PORT: web/src/tilt-to-live/GoalsHUD.ts:394-474; game.css:4197-4295
func _milestone_card(goal: GoalManager.Goal) -> PanelContainer:
	var s: float = _ui_scale
	var is_done: bool = _goal_manager.is_completed(goal.id)
	var is_unlock: bool = _goal_manager.is_unlock_goal(goal)

	# Unlock goals have no meaningful numeric target (:398-401).
	var current_val: float = 0.0
	if not is_unlock and _goal_manager.is_total_goal(goal):
		current_val = _goal_manager.get_metric_value(goal.metric, GoalManager.RunTracker.new())
	var pct: int = (
		0 if is_unlock else clampi(roundi(current_val / goal.target * 100.0), 0, 100)
	)  # PORT: :420-422

	var card: PanelContainer = PanelContainer.new()
	card.name = "MilestoneCard_" + goal.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # grid columns share the width (1fr)
	var style: StyleBoxFlat = ArmoryTheme.flat(
		CARD_DONE_BG if is_done else ArmoryTheme.COLOR_PANEL,
		ArmoryTheme.COLOR_RAISED if is_done else ArmoryTheme.COLOR_BORDER,
		CARD_RADIUS
	)
	style.content_margin_left = CARD_PAD_X * s
	style.content_margin_right = CARD_PAD_X * s
	style.content_margin_top = CARD_PAD_Y * s
	style.content_margin_bottom = CARD_PAD_Y * s
	card.add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(CARD_GAP * s))
	card.add_child(row)

	var mark: PanelContainer = PanelContainer.new()  # PORT: game.css:4216-4234
	mark.name = "MarkBox"
	mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE) * s
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_done:
		mark.add_theme_stylebox_override(
			"panel", ArmoryTheme.flat(ArmoryTheme.COLOR_SUCCESS, ArmoryTheme.COLOR_SUCCESS, MARK_RADIUS)
		)
		mark.add_child(_icon(DONE_CHECK_SVG, MARK_ICON))
	else:
		mark.add_theme_stylebox_override(
			"panel", ArmoryTheme.flat(Color(0, 0, 0, 0), ArmoryTheme.COLOR_BORDER_ACTIVE, MARK_RADIUS)
		)
	row.add_child(mark)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(CARD_CONTENT_GAP * s))
	var name_label: Label = _label(
		goal.title, CARD_NAME_FONT, ArmoryTheme.TEXT_FAINT if is_done else ArmoryTheme.TEXT_PRIMARY
	)
	name_label.name = "NameLabel"
	content.add_child(name_label)

	# Open / in-progress goals show "cur / target" for totals (:457-460).
	var subtitle: String = goal.description
	if not is_done and not is_unlock and _goal_manager.is_total_goal(goal):
		subtitle = "%s / %s" % [
			ArmoryUI.group_digits(int(current_val)), ArmoryUI.group_digits(goal.target)
		]
	var goal_label: Label = _label(subtitle, CARD_GOAL_FONT, ArmoryTheme.TEXT_FAINT)
	goal_label.name = "GoalLabel"
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(goal_label)

	if not is_done and not is_unlock:
		var bar: ColorRect = ColorRect.new()  # PORT: :468-470; game.css:4263-4280
		bar.name = "BarTrack"
		bar.color = ArmoryTheme.COLOR_RAISED
		bar.custom_minimum_size.y = BAR_HEIGHT * s
		var bar_fill: ColorRect = ColorRect.new()
		bar_fill.name = "BarFill"
		bar_fill.color = ArmoryTheme.COLOR_ION
		bar_fill.anchor_bottom = 1.0
		bar_fill.anchor_right = pct / 100.0
		bar.add_child(bar_fill)
		content.add_child(bar)
	row.add_child(content)

	var pts: Label = _label(
		"+%d" % goal.reward_points,
		CARD_POINTS_FONT,
		TEXT_DIM if is_done else ArmoryTheme.COLOR_FLARE
	)
	pts.name = "PointsLabel"
	row.add_child(pts)
	return card


func _on_modal_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			close_all_goals_modal()  # PORT: GoalsHUD.ts:298-302
```

Notes for the implementer: `game.css:4264-4269`'s bar `margin-top: 3px` is covered by the content VBox's 3px separation. Keep lines ≤100 columns (split the two long `add_theme_stylebox_override` calls as gdformat prefers). `_layout_modal` rebuilds the modal on every `_layout()`; `_init_dom` builds it once and then calls `_layout()`, which rebuilds it once more — accepted (build is cheap and happens at boot and on resize only).

- [ ] **Step 4: Verify** — `tools/run_tests.sh` → `OK: 45/45 scripts (418 tests)`; `gdformat --check`, `gdlint` clean; `grep -rn "Task 6 replaces" godot/src/` prints nothing; `grep -rn "DIVERGENCE" godot/src/ | wc -l` prints `76`.

- [ ] **Step 5: Commit**

```bash
git checkout godot/project.godot
git add godot/src/ui/goals_hud.gd godot/tests/test_goals_hud.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: port the Milestones screen with tiers, cards and live progress"
git log -1 --format=%B
```

---

### Task 7: Game-over "Points earned" row and earned-milestones list (R1)

**Files:**
- Modify: `godot/scenes/main.tscn`, `godot/src/ui/hud_controller.gd`, `godot/src/core/game_root.gd`
- Test: `godot/tests/test_main_scene.gd`, `godot/tests/test_hud_controller.gd`

**Interfaces:**
- Consumes: `GameRoot.get_run_controller()` (Task 5), `RunController.run_completed_goals/points_earned_this_run/coins.points_from_coins` (Task 4), `ArmoryUI.group_digits`, `GoalsHUD.TOAST_*` not needed.
- Produces: `GameRoot.open_all_goals_modal() -> void`; scene nodes `PointsEarnedRow`, `PointsValueLabel`, `MilestonesList`.

- [ ] **Step 1: Write the failing tests.** Append to `godot/tests/test_main_scene.gd`:

```gdscript
func test_game_over_lists_the_runs_milestones_and_opens_the_modal() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var rc: RunController = root.get_run_controller()
	rc.run_tracker.score = 1000
	rc.trigger_player_death()
	var list: VBoxContainer = root.find_child("MilestonesList", true, false) as VBoxContainer
	assert_true(list.visible, "TiltGame.ts:2140")
	assert_eq(list.get_child_count(), 1)
	var row_text: Label = list.get_child(0).find_child("MilestoneText", true, false) as Label
	assert_eq(row_text.text, "Rookie Dodger — Reach 1,000 score in a run", ":2136")
	var value: Label = root.find_child("PointsValueLabel", true, false) as Label
	assert_eq(value.text, "+1 → 7,332", "max(1, 1) + 0 coins → 7331 + 1 (:2118-2121)")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	list.gui_input.emit(click)
	var modal: Control = root.find_child("MilestonesModal", true, false) as Control
	assert_true(modal.visible, "GoalsHUD.ts:131-132")
	(root.find_child("GoalsHud", true, false) as GoalsHUD).close_all_goals_modal()
	var points_row: Control = root.find_child("PointsEarnedRow", true, false) as Control
	points_row.gui_input.emit(click)
	assert_true(modal.visible, "GoalsHUD.ts:133-134")


func test_game_over_hides_an_empty_milestones_list() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.get_run_controller().trigger_player_death()
	var list: Control = root.find_child("MilestonesList", true, false) as Control
	assert_false(list.visible, "TiltGame.ts:2141-2143")
	var value: Label = root.find_child("PointsValueLabel", true, false) as Label
	assert_eq(value.text, "+0 → 7,331")
```

Append to `godot/tests/test_hud_controller.gd` (follow the file's existing way of building the HUD alone — the scene or the script, whichever its other tests use):

```gdscript
func test_run_rows_hide_without_a_game_root() -> void:
	# Built alone (no GameRoot in the tree), the HUD cannot read the run.
	GameEvents.run_ended.emit(10, Types.GameStats.new())
	var row: Control = _hud.find_child("PointsEarnedRow", true, false) as Control
	if row != null:
		assert_false(row.visible)
	var list: Control = _hud.find_child("MilestonesList", true, false) as Control
	if list != null:
		assert_false(list.visible)
	pass_test("rows absent or hidden")
```

(Rename `_hud` to whatever the file's HUD fixture variable is.)

- [ ] **Step 2: Run to verify they fail** — the main-scene tests fail on a null `MilestonesList`.

- [ ] **Step 3: Scene** — in `godot/scenes/main.tscn`, insert after the `FinalTimeLabel` node (before `ControlsLabel`):

```
[node name="PointsEarnedRow" type="HBoxContainer" parent="CanvasLayer/Hud/GameOverPanel/Panel/Margin/VBox"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 0
mouse_default_cursor_shape = 2

[node name="PointsLabel" type="Label" parent="CanvasLayer/Hud/GameOverPanel/Panel/Margin/VBox/PointsEarnedRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "Points earned"

[node name="PointsValueLabel" type="Label" parent="CanvasLayer/Hud/GameOverPanel/Panel/Margin/VBox/PointsEarnedRow"]
unique_name_in_owner = true
layout_mode = 2
text = "+0 → 0"

[node name="MilestonesList" type="VBoxContainer" parent="CanvasLayer/Hud/GameOverPanel/Panel/Margin/VBox"]
unique_name_in_owner = true
visible = false
layout_mode = 2
mouse_filter = 0
mouse_default_cursor_shape = 2
```

Before adding `unique_name_in_owner` to `PointsLabel`, check `grep -n 'name="PointsLabel"' godot/scenes/*.tscn` — if the name already exists as a unique name in `main.tscn`, name this one `PointsEarnedLabel` instead (and use that in the code below).

- [ ] **Step 4: `HudController`** (`godot/src/ui/hud_controller.gd`):
  - Header `## PORTS:` line gains `, 2111-2144 (points row + earned milestones)`.
  - Constants after `PULSE_SECONDS`:

```gdscript
## Game-over points and milestone rows. PORT: web/src/tilt-to-live/TiltGame.ts:835-836
## (label 13 #99A1B3), :841, :844 (value 15 #FFB14D), :855 (list gap 6), :861 (row
## gap 9), :865-866 (text 13 #C7CDDB), :872-873 (points 12 #FFB14D), :2135 (check 13)
const POINTS_LABEL_FONT: int = 13
const POINTS_LABEL_COLOR: Color = Color("#99A1B3")
const POINTS_VALUE_FONT: int = 15
const POINTS_VALUE_COLOR: Color = Color("#FFB14D")
const MILESTONE_LIST_GAP: int = 6
const MILESTONE_ROW_GAP: int = 9
const MILESTONE_TEXT_FONT: int = 13
const MILESTONE_TEXT_COLOR: Color = Color("#C7CDDB")
const MILESTONE_POINTS_FONT: int = 12
const MILESTONE_CHECK: float = 13.0
## PORT: web/src/tilt-to-live/TiltGame.ts:2135
const MILESTONE_CHECK_SVG: String = (
	'<svg width="13" height="13" viewBox="0 0 13 13" fill="none"'
	+ ' xmlns="http://www.w3.org/2000/svg"><path d="M2 7 L5 10 L11 3.5"'
	+ ' stroke="#3DDC97" stroke-width="1.7" stroke-linecap="round"'
	+ ' stroke-linejoin="round"/></svg>'
)
```

  - Members: `var _ui_scale: float = 1.0`, plus `@onready` lookups after `_restart_button`:
    `@onready var _points_earned_row: Control = get_node_or_null("%PointsEarnedRow")`, `@onready var _points_label: Label = get_node_or_null("%PointsLabel")`, `@onready var _points_value_label: Label = get_node_or_null("%PointsValueLabel")`, `@onready var _milestones_list: VBoxContainer = get_node_or_null("%MilestonesList")`, and the same `find_child` fallbacks in `_ready()` the other nodes use.
  - In `_ready()` after the restart-button wiring:

```gdscript
	# bindGameOverClicks. PORT: web/src/tilt-to-live/GoalsHUD.ts:129-135
	if _points_earned_row != null:
		_points_earned_row.gui_input.connect(_on_run_rows_gui_input)
	if _milestones_list != null:
		_milestones_list.gui_input.connect(_on_run_rows_gui_input)
		_milestones_list.add_theme_constant_override("separation", MILESTONE_LIST_GAP)
```

  - In `set_ui_scale()`: store `_ui_scale = scale`; scale `_points_label` (`POINTS_LABEL_FONT`, colour `POINTS_LABEL_COLOR`) and `_points_value_label` (`POINTS_VALUE_FONT`, colour `POINTS_VALUE_COLOR`) with `add_theme_font_size_override`/`add_theme_color_override`, null-guarded like the others; set the list separation to `int(MILESTONE_LIST_GAP * scale)`.
  - In `_on_run_ended()`, just before `_game_over_panel.visible = true`: `_fill_run_rows()`.
  - New private methods (after `_on_run_ended`):

```gdscript
## The "Points earned" row and the earned-milestones list.
## PORT: web/src/tilt-to-live/TiltGame.ts:2111-2144
# PORT-NOTE: the coins row (:2123-2130), subtitle and best-chain cells are the
# rest of the game-over summary — M11's (TODO(M11) in run_controller.gd).
# PORT-NOTE: the TS markup's .milestone-title / .milestone-pts classes
# (:2136-2137) match no rule; the sizes and colours are the injected sheet's
# .milestone-text / .milestone-points (:864-874) it was written for (M9 plan R6).
# PORT-NOTE: .points-arrow's own colour (:848-850) is not split out of the value label.
func _fill_run_rows() -> void:
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root == null:
		if _points_earned_row != null:
			_points_earned_row.visible = false
		if _milestones_list != null:
			_milestones_list.visible = false
		return
	var rc: RunController = root.get_run_controller()

	var earned_milestones_pts: int = 0
	for g: GoalManager.Goal in rc.run_completed_goals:
		earned_milestones_pts += g.reward_points
	# Coin pickups are a second points income stream folded into the one total (:2113-2117).
	var total_earned: int = (
		maxi(rc.points_earned_this_run, earned_milestones_pts) + rc.coins.points_from_coins
	)
	var balance: int = root.progression.data.points
	if _points_value_label != null:
		_points_value_label.text = (
			"+%s → %s" % [ArmoryUI.group_digits(total_earned), ArmoryUI.group_digits(balance)]
		)
	if _points_earned_row != null:
		_points_earned_row.visible = true

	if _milestones_list == null:
		return
	for child: Node in _milestones_list.get_children():
		_milestones_list.remove_child(child)
		child.queue_free()
	for g: GoalManager.Goal in rc.run_completed_goals:
		_milestones_list.add_child(_milestone_row(g))
	_milestones_list.visible = rc.run_completed_goals.size() > 0


## One .gameover-milestone-item. PORT: web/src/tilt-to-live/TiltGame.ts:2133-2139
func _milestone_row(goal: GoalManager.Goal) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(MILESTONE_ROW_GAP * _ui_scale))
	var check: TextureRect = TextureRect.new()
	check.texture = ArmoryUI.svg_texture(MILESTONE_CHECK_SVG, _ui_scale * ArmoryUI.SVG_OVERSAMPLE)
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.custom_minimum_size = Vector2(MILESTONE_CHECK, MILESTONE_CHECK) * _ui_scale
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(check)
	var text: Label = Label.new()
	text.name = "MilestoneText"
	text.text = "%s — %s" % [goal.title, goal.description]
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", int(MILESTONE_TEXT_FONT * _ui_scale))
	text.add_theme_color_override("font_color", MILESTONE_TEXT_COLOR)
	row.add_child(text)
	var pts: Label = Label.new()
	pts.text = "+%d" % goal.reward_points
	pts.add_theme_font_size_override("font_size", int(MILESTONE_POINTS_FONT * _ui_scale))
	pts.add_theme_color_override("font_color", POINTS_VALUE_COLOR)  # PORT: :873
	row.add_child(pts)
	return row


## bindGameOverClicks' handler. PORT: web/src/tilt-to-live/GoalsHUD.ts:131-134
func _on_run_rows_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var root: GameRoot = get_tree().get_first_node_in_group("game_root") as GameRoot
	if root != null:
		root.open_all_goals_modal()
```

  - `GameRoot` — after `is_armory_open()`:

```gdscript
## Opens the full Milestones screen (the menu link, the game-over rows).
## PORT: web/src/tilt-to-live/TiltGame.ts:195
func open_all_goals_modal() -> void:
	_goals_hud.open_all_goals_modal()
```

  - Remove the `TODO(M11)` line in `run_controller.gd`'s step 5.5 comment only if it now overstates — it still holds for the coins row and `coins_collected`; edit it to `# TODO(M11): the game-over coins row reads coins.coins_collected (TiltGame.ts:2108, :2123-2130); points_from_coins already feeds HudController's points row (M9).`

- [ ] **Step 5: Verify** — `tools/run_tests.sh` → `OK: 45/45 scripts (421 tests)`; `gdformat --check`, `gdlint` clean; headless boot `grep -c "SCRIPT ERROR"` → `0`.

- [ ] **Step 6: Commit**

```bash
git checkout godot/project.godot
git add godot/scenes/main.tscn godot/src/ui/hud_controller.gd godot/src/core/game_root.gd godot/src/sim/run_controller.gd godot/tests/test_main_scene.gd godot/tests/test_hud_controller.gd docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: show earned milestones on game over and open the screen on tap"
git log -1 --format=%B
```

---

### Task 8: Device pass — unattended half, and `## M9 — Milestones` in `VERIFY-ME.md`

**Files:** Modify (append): `godot/VERIFY-ME.md`.

- [ ] **Step 1:** `"$ADB" devices`. If `RRCXB04L8EJ` is listed: build and install exactly as `VERIFY-ME.md` §M8 records (same export preset and commands), launch, and capture `"$ADB" -s RRCXB04L8EJ logcat -d | grep -c "SCRIPT ERROR"` (expect `0`) and the frame-time command from the "Mobile scale split" section. If it is not listed, record `adb devices returned no devices on <date>` and do the unattended checks only: `tools/run_tests.sh`, the headless boot, and an Android export if M8's section shows one can run without the phone.

- [ ] **Step 2:** Append to `godot/VERIFY-ME.md` (never recreate the file):

```markdown
## M9 — Milestones (device pass, plan Task 8)

Unattended evidence: <paste the commands run and their output lines>.

Hand-held checks (tick when seen on the A55):

- [ ] **Rail**: a 4px blue-on-dark rail on the left edge, inside the safe area, fills as milestones complete (1/57 per milestone). Hidden only in menu mode (M11).
- [ ] **Toast**: completing a milestone mid-run (e.g. a cumulative total, or buying a ship in the Armory) shows a bottom-left card with a green check, the title and `+N` for 3 s. It does not block touches or the joystick.
- [ ] **Game over**: a run that earns milestones lists them under "Points earned +X → balance"; the list is hidden when none were earned.
- [ ] **Modal from game over**: tapping the points row or the list opens the full Milestones screen; it scrolls by drag; the ✕ button and a tap outside the panel close it. Three tiers (Score 9, Combat 17, Mastery 31), one column on the phone.
- [ ] **Unlock goals at boot**: an existing save that already owns a goal's ship/skin/arena completes that goal once at launch (toast + points), never twice.
- [ ] **Persistence**: kill the app and relaunch — completed milestones and cumulative totals survive (`user://tilt_to_live_completed_goals_v1.json` is a bare JSON array).
- [ ] **Frame time** under a mass explosion unchanged from the "Mobile scale split" figure (the per-tick goal check is a 57-goal loop).
```

- [ ] **Step 3: Commit**

```bash
git checkout godot/project.godot
git add godot/VERIFY-ME.md docs/superpowers/plans/2026-09-20-m9-milestones.md godot/HANDOFF.md
git commit -m "M9: record unattended device evidence and hand-held milestone checks"
git log -1 --format=%B
```

---

### Task 9: Exit protocol (CONVENTIONS §9)

- [ ] **Step 1: Verify** — fresh, and read every output:

```bash
tools/run_tests.sh                        # expect: OK: 45/45 scripts (421 tests)
gdformat --check godot/src godot/tests    # expect: 80 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "DIVERGENCE" godot/src/ | wc -l  # expect: 76
grep -rn "TODO(M9)" godot/src/ godot/tests/   # expect: nothing
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR"   # expect: 0
git checkout godot/project.godot
```

  (`80` = 75 at HEAD + `goal_manager.gd`, `goals_hud.gd` + `test_goal_manager.gd`, `test_goal_parity.gd`, `test_goals_hud.gd`.)

- [ ] **Step 2: Tick `godot/PORT-PROGRESS.md`** — `- [x] **M9 — Milestones**` with the date, the final commit SHA (the parent of the exit commit, as M8 did) and "device pass pending" if Task 8 had no phone.

- [ ] **Step 3: Rewrite `godot/HANDOFF.md`** for a zero-context session: `## State` (M9 code-complete, device pass pending), `## How to verify right now` (the Step 1 block with the real numbers), a `## M9 — what landed` section (files, rulings R1–R7, the three new test scripts), Open questions (below), and `## Next`: **M5 (Audio bake + SFX) or M10 (Modes)** — M5 deps M2, M10 deps M3, both open; M11 needs all. Literal first step for each, in the style of the current `## Next`.

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

1. **R7 — death-tick double count.** Should the port keep the TS behaviour where, on the tick the player dies, cumulative goals are checked once more with the run counted twice (it can complete e.g. *Century of Destruction* at 30 lifetime + 40 this run)? The plan preserves it (LAW 2). Fixing it is a one-line spec change (skip step 8's live check once `player.is_dead`).
2. **The rail is 4 px and near-untappable on a phone** (R1 keeps it). If the device pass finds the rail pointless on mobile, options are a wider invisible hit area or hiding it on mobile — both divergences.
3. **Toast slide-in animation and rail height transition** (`game.css:595`, `:3626`) are not ported. Say if they should be.
