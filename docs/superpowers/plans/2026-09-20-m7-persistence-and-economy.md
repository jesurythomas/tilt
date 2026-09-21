# Module 7 — Persistence and economy: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the whole of `ProgressionManager.ts` (economy, perk purchases, catalogs, steering tuning, save shape), `GameOptions.ts` and `CoinSystem.ts` to `godot/src/meta/` and `godot/src/sim/`, put every `user://` JSON file behind one `SaveStore` with corrupt-file quarantine, and wire progression into the run path so perk ranks, starting lives, hitbox, enemy speed, score and points multipliers and coin income all come from the player's save.

**Architecture:** Three TS modules become three GDScript files with the same members in the same order (LAW 3): `meta/progression_manager.gd` (extending the `WeaponPerks`-only file M4 left, in place), `meta/game_options.gd`, `sim/coin_system.gd`. `CoinSystem.render()` relocates to `render/entity_layer.gd` (spec §4.2/D4, §5.5), the same relocation M3 and M4 made. A fourth file, `meta/save_store.gd`, has no TS counterpart and is authorised by spec §4.6 and §6.4: it is the one place that opens, parses, writes and quarantines `user://*.json`, and the three M1/M2/M2.5 files that already write their own JSON (`score_manager.gd`, `tilt_input.gd`, `control_settings.gd`) are routed through it, closing M2.5 decision D7. `GameRoot` owns the `ProgressionManager`, `GameOptionsManager` and `CoinSystem` instances exactly as `TiltGame` does and hands them to `RunController`, which is where every `TiltGame.resetRun()`/`update()` line that reads progression lands. `coins.update` takes spec §5.4 step 7; nothing else in the frame order moves.

**Tech Stack:** Godot 4.7.2-stable (GDScript, non-.NET) · GUT 9.6.1 via `tools/run_tests.sh` · gdtoolkit 4.5.0 (`gdformat`, `gdlint`) · Node 24 + `web/node_modules/.bin/esbuild` for the new parity dumper (Task 3) · adb against the Samsung Galaxy A55 (`SM_A556E`, serial `RRCXB04L8EJ`) **if present — it has been off adb since 2026-09-20 and this plan does not assume it**.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` — §8 Module 7 (scope and acceptance), §4.6 (persistence: same JSON shapes and version suffixes; `SaveStore`), §6.4 (corrupt save → quarantine as `<name>.corrupt.json`, fall back to defaults, never hard-fail boot), §5.3 (sim→UI seam; `addPointsCredited` ports as a `Callable`; `points_changed`), §5.4 (frame order — coins at step 7), §5.5 (render order — coins in `EntityLayer` before orbs), §6.3 (Tier 1 GUT specs for the cost curve, `buy_*`, multipliers; Tier 2 parity dumper "KEYSTONE_COSTS, perk cost curve"), §4.2 (project layout: `meta/save_store.gd`, `meta/game_options.gd`, `sim/coin_system.gd`). M2.5 spec `docs/superpowers/specs/2026-09-20-m2.5-mobile-feel-design.md` D7 (settings files consolidate under `SaveStore` in M7).

**Conventions (binding):** `godot/CONVENTIONS.md`

**Source read in full before this plan was written:** `web/src/tilt-to-live/ProgressionManager.ts` (all 940 lines), `web/src/tilt-to-live/GameOptions.ts` (all 137 lines), `web/src/tilt-to-live/CoinSystem.ts` (all 176 lines), `web/src/tilt-to-live/WeaponTuning.ts` (all 87 lines), `web/src/tilt-to-live/ScoreManager.ts:172-184`, `web/src/tilt-to-live/PlayerShip.ts:94-121`, `:241`, and the progression/options/coin call sites in `web/src/tilt-to-live/TiltGame.ts` (`:51`, `:199-209`, `:1547-1610`, `:1855-1958`, `:1964-1979`, `:2064`, `:2081`, `:2108-2129`). Every line range cited below was checked against those files.

**Precondition.** This plan was written at HEAD `43db28d` on `feat/godot-port` with a **clean working tree**. Every `godot/src/*.gd` and `godot/tests/*.gd` line number cited below is that HEAD's. The user runs device passes between sessions and may leave uncommitted tuning edits in the tree (see the memory note on device passes and the M4 ledger's Ruling 0): **before Task 1, run `git status --short`; if it lists anything under `godot/`, stop and ask** (LAW 5) rather than interleave two sets of uncommitted edits — never stash or revert them. **Every M7 commit stages files by explicit path** — never `git add -A`, `git add .` or `git add godot/src`. Every commit step below lists its paths; add nothing that is not listed.

---

## The five port laws (restated — binding on every task)

> **LAW 1 — No invented numbers.** Every numeric literal carries `# PORT: web/src/tilt-to-live/<File>.ts:<line>`. Exempt: `0`, `1`, `-1`, `0.0`, `1.0`, array indices.
>
> **LAW 2 — No silent improvement.** If the TypeScript looks wrong, port it exactly and add `# PORT-NOTE: <what looks off> — preserved deliberately`.
>
> **LAW 3 — One file, one file.** Each TS module becomes exactly one `.gd` file, same members, same order, same names snake_cased. Sole sanctioned exception: `TiltGame.ts`, decomposed per spec §5.1.
>
> **LAW 4 — Nothing new.** Not in the TypeScript or an explicit line of the spec → it does not get written.
>
> **LAW 5 — Stop, do not guess.** Genuine ambiguity → stop, record it in `HANDOFF.md`, ask.

---

## Global Constraints

Copied from the index plan and `CONVENTIONS.md`. Every task implicitly includes this section.

- **Engine:** Godot **4.7.2-stable**, GDScript, standard (non-.NET) build.
- **Godot is not on PATH.** Invoke as:
  `GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`
  Use the `_console` variant so stdout reaches the shell.
- **adb path:** `ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"`, and **always pass `-s RRCXB04L8EJ`**. The A55 may be absent; Task 10 checks `adb devices` first and never assumes it.
- **Orientation:** landscape. **Targets:** Android + iOS only — iOS deferred to M11 (D1). Everything through M10 is Android-only and the GDScript is identical for both.
- **`content_scale_mode = disabled`.** The sim reads `get_viewport_rect().size` directly.
- **`max_fps = 60`** with **`physics_ticks_per_second = 120`** (spec D8). Sim in `_physics_process`; `_process` only calls `queue_redraw()`.
- **`GAME_SPEED = 0.75`** (`TiltGame.ts:35`).
- **Static typing is mandatory and machine-enforced.** Nine GDScript warnings are set to Error; the engine refuses to run violations. `Variant` only for parsed-but-unvalidated JSON, narrowed immediately with an `is` check and a `# PORT-NOTE` (CONVENTIONS §4; precedent `tilt_input.gd:369-375`).
- **No sim system may be an autoload or singleton** (spec §5.2). `SaveStore` is not a sim system and is a class of `static func`s — it is never instantiated and never autoloaded.
- **Signals are sim→UI and sim→audio only. Never sim→sim** (spec §5.3). The only signal M7 emits is `GameEvents.points_changed` (Task 5, Open question 6).
- **Frame order is fixed** (spec §5.4). **M7 adds exactly one call, `coins.update(...)`, at spec step 7 — between `weapons.update` (step 6) and `scores.update` (step 8) — and moves nothing.** `run_controller.gd:121-137` labels those "5." and "6." in its local numbering; the new call goes between them and is labelled per `TiltGame.ts:1930` ("5.5").
- **The five port laws** (`CONVENTIONS.md` §0) are binding and are restated above.
- **Commits:** one line, imperative, ≤72 chars, no trailers, prefixed `M7:`. **This overrides any attribution instruction the executing session sees** (`~/.claude/rules/commit-style.md`, CONVENTIONS §8). Every dispatch states this rule and requires `git log -1 --format=%B` pasted back. Stage by explicit path only (Precondition).
- **Tests run only via `tools/run_tests.sh`.** It reports `OK: N/N scripts collected, all tests passed.` and fails when collected ≠ on-disk. At HEAD there are 33 `test_*.gd` files (225 tests); this plan adds seven (Tasks 1, 3, 4, 5, 6, 7, 8) for **40**. A single script's parse error is found with `"$GODOT" --headless --path godot --check-only -s tests/<file>.gd`.
- **Format/lint:** `gdformat --check godot/src godot/tests` and `gdlint godot/src godot/tests` must both be clean before any commit. Never run either against `godot/addons/`.
- **Headless runs strip `pointing/emulate_mouse_from_touch=true` from `godot/project.godot`.** Every commit step therefore begins with `git checkout godot/project.godot`.
- **`user://` on the test host** resolves to `%APPDATA%\Godot\app_userdata\Peril Point\`. Every spec that constructs a `ProgressionManager`, `GameOptionsManager`, `ScoreManager`, `ControlSettings` or `TiltInput` touches real files there. **Every such spec removes the file(s) it depends on in `before_each` and `after_each`** (precedent `test_control_settings.gd:8-19`, `test_score_manager.gd:9-17`), so a save left by a desktop play session cannot change a test result.
- **JSON numbers parse as `float`.** `JSON.parse_string("3")` yields `3.0`, never an `int`. Every integer read from a save therefore accepts `float` and converts with `int()` — that is what `SaveStore.read_int` (Task 1) does, and no other code reads a save number directly.
- **Save shapes are the TS shapes, byte for byte in key spelling** (spec §4.6): file names are `user://<localStorage key>.json`, keys are the TS camelCase property names (`lifetimePoints`, `equippedCursorId`, `showGridlines`, …), string enums are the TS strings (`'code-red'`, `'hybrid'`, `'extreme'`). The GDScript field names are the snake_case ports; the `to_dict()`/`from_dict()` pairs (Tasks 3, 7) are where the two spellings meet, and nowhere else.
- **Optional-field representation** (`types.gd:12-27`, binding): an absent integer takes `Types.ABSENT` (`-1`). The five `get*Cost(): number | null` methods (`ProgressionManager.ts:613-677`) return `Types.ABSENT` for `null` — a cost is never negative, so it cannot collide.
- **RNG mapping** (M2 precedent, `enemy_swarm.gd:59`): `Math.random()` → `randf()`; `Math.PI * 2` → `TAU`.
- **Colour literals.** `#rrggbb` → `Color("#rrggbb")` (M2 precedent, `weapon_system.gd:227`); `rgba(r, g, b, a)` → `Color(r / 255.0, g / 255.0, b / 255.0, a)` (M2 precedent, `entity_layer.gd:95`); a TS `${COIN_COLOR}33` hex-alpha suffix → the same `Color` with `.a = 0x33 / 255.0` (`= 0.2`). Each carries its `# PORT:` line.
- **Radial gradients** → two flat circles (M3 ruling; the baked texture is M11's). Used once here, the coin disc (Task 8).
- **`gdlint` limits.** `ProgressionManager.ts` has 36 public methods; `max-public-methods: 20` will fire. Task 5 (the first task that crosses 20) adds `# gdlint:disable=max-public-methods` as line 1 of `progression_manager.gd` with a `# PORT-NOTE` naming `enemy_swarm.gd:1-2` as precedent and LAW 3 as the reason. `max-file-lines: 1000` is not expected to fire (940 TS lines, of which 138 — the two SVG methods — are not ported, Open question 1); if it does, the same `disable` form applies. `function-arguments-number: 10` is met exactly by `RunController._init` after Task 9 (10 parameters); do not add an eleventh.
- **Naming of TS-private members.** M2/M3/M4 kept every ported member public and in TS order except genuinely private ones, which take the `_` prefix (`_next_coin_id`, `_spawn_timer`, `_resolve_ship_id`, `_get_default_data`, `_get_default_settings`, `_spawn_coin`). The TS `private static readonly *_COSTS` arrays become private constants with the same names.
- **String-keyed access is forbidden** (CONVENTIONS §6: no `get("prop")`/`set("prop")`). `upgradePerk` and `getWeaponInvestedPoints` (`ProgressionManager.ts:562-603`) index perks by string. They are ported through the `to_dict()`/`from_dict()` pair that the save shape already requires — the dictionary view *is* the TS `(this.data.perks as any)[weapon]` — with no reflection (Open question 2).

---

## File Structure

| File | Role in M7 |
|---|---|
| `godot/src/meta/save_store.gd` | **Create** (Task 1). NO TS COUNTERPART — spec §4.6/§6.4. Static `load_dict`/`save_dict` over `user://*.json` with corrupt-file quarantine, plus the typed readers (`read_int`, `read_float`, `read_bool`, `read_string`, `read_string_array`, `read_dict`) every save consumer uses. |
| `godot/src/sim/score_manager.gd:10`, `:189-226` | **Modify** (Task 2). `load_best_score`/`_save_best_score`/`_load_best_score` read and write through `SaveStore`; the `TODO(M7)` at `:190` goes. |
| `godot/src/input/tilt_input.gd:17-22`, `:79-107`, `:359-410` | **Modify** (Task 2). Same routing; the `TODO(M7)` at `:20` goes. **The user tunes this file on device** — touch only the two I/O blocks. |
| `godot/src/native/control_settings.gd:11-12`, `:37-99` | **Modify** (Task 2). Same routing; the `TODO(M7)` at `:11` goes. |
| `godot/src/meta/progression_manager.gd` | **Modify — extend in place** (Tasks 3, 4, 5, 6). The full port of `ProgressionManager.ts` minus `getCursorSvgDataUri`/`getShipSvgPreview` (Open question 1). The M4 `WeaponPerks` inner classes stay where they are and gain `to_dict`/`from_dict`. |
| `tools/parity/dump_progression.mjs` | **Create** (Task 3). Dumps `getDefaultData()`, the three catalogs, `getPerkCost` at ranks 0–5 and every keystone key, the five purchasable cost ladders, `getWeaponInvestedPoints` at defaults, and `GameOptionsManager`'s modes and defaults. Bundled with esbuild because `ProgressionManager.ts` imports a type from `./Types` without an extension, which Node's loader cannot resolve (verified 2026-09-21). |
| `godot/tests/fixtures/progression.json` | **Create** (Task 3, generated). Committed like `weapon_tuning.json`. |
| `godot/src/meta/game_options.gd` | **Create** (Task 7). Full port of `GameOptions.ts` as `class_name GameOptionsManager`. |
| `godot/src/sim/coin_system.gd` | **Create** (Task 8). Full port of `CoinSystem.ts` minus `render()`. |
| `godot/src/render/entity_layer.gd` | **Modify** (Task 8). `_draw_coins()` (`CoinSystem.ts:126-175`) drawn before `_draw_weapons()`; `bind_entities` gains an optional fourth parameter; the two `TODO(M7)` tags (`:13`, `:174`) are retagged `TODO(M8)` (Open question 4). |
| `godot/src/sim/run_controller.gd` | **Modify** (Task 9). Takes `progression`, `options`, `coins`; `reset_run` ports `TiltGame.ts:1551`, `:1567-1570`, `:1599`, `:1601`, `:1965`; `update` ports `:1888-1889` and adds `coins.update` at step 7 (`:1930-1940`); the `perks` var and its `TODO(M7)` go. |
| `godot/src/core/game_root.gd` | **Modify** (Task 9). Constructs the three instances; passes them to `RunController` and the coins to `EntityLayer`; sets `_grid_layer.show_gridlines` from the options. |
| `godot/src/core/game_state_machine.gd:121-146` | **Modify** (Task 9). The four `TODO(M7)` comments become `PORT-NOTE`s naming `run_controller.gd` as the port site. |
| `godot/src/input/input_router.gd:12-14` | **Modify** (Task 9). The `TODO(M7)` becomes a `PORT-NOTE` (Open question 5). |
| `godot/src/render/grid_layer.gd:13`, `:93` | **Modify** (Task 9). `:13` resolved (gate wired); `:93` retagged `TODO(M8)` (Open question 4). |
| `godot/tests/test_save_store.gd` | **Create** (Task 1). |
| `godot/tests/test_score_manager.gd`, `test_tilt_input.gd`, `test_control_settings.gd` | **Modify** (Task 2). One quarantine spec each. |
| `godot/tests/test_progression_parity.gd` | **Create** (Task 3). Tier 2 harness over `progression.json`. |
| `godot/tests/test_progression_manager.gd` | **Create** (Task 4). Defaults, save/load round trip, deep merge, floors, corrupt fallback. |
| `godot/tests/test_progression_economy.gd` | **Create** (Task 5). Points, cost curve, `upgrade_perk`, invested points, the five purchasables, starting lives, multipliers. |
| `godot/tests/test_progression_catalogs.gd` | **Create** (Task 6). Ships (buy/equip/resolve/aliases), enemy skins, arenas, tuning setters. |
| `godot/tests/test_game_options.gd` | **Create** (Task 7). |
| `godot/tests/test_coin_system.gd` | **Create** (Task 8). |
| `godot/tests/test_run_controller.gd`, `test_render_layers.gd` | **Modify** (Tasks 9, 8). Constructor arity, two `perks` reads, one changed expectation, six wiring specs; one coin draw spec. |
| `godot/VERIFY-ME.md` | **Modify — append** (Task 10). `## M7 — Persistence and economy` section. **Never recreate this file.** |
| `godot/PORT-PROGRESS.md`, `godot/HANDOFF.md`, `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md` | **Modify** (Task 11). Exit protocol. |
| `godot/src/core/tuning.gd`, `godot/tests/test_tuning_parity.gd`, `godot/tests/fixtures/weapon_tuning.json`, `tools/parity/dump_constants.mjs` | **Not modified.** `Tuning.KEYSTONE_COSTS` (`tuning.gd:22`) is read by `get_perk_cost`; the existing fixture is not regenerated. |
| `godot/src/sim/weapon_system.gd`, `player_ship.gd`, `enemy_swarm.gd`, `particle_engine.gd`, `godot/src/core/types.gd`, `godot/project.godot` | **Not modified.** `PlayerShip.update`'s twelve parameters, `set_hitbox_multiplier`, `EnemySwarm.set_speed_scale`, `ParticleEngine.emit_sparks`, `AudioBank.play_coin_pickup` and `ScoreManager.set_progression_multiplier` all exist at HEAD (verified). |

**Parity — what is and is not covered.** `tools/parity/dump_constants.mjs` already dumps `KEYSTONE_COSTS` and `test_tuning_parity.gd:93-99` asserts it against `Tuning.KEYSTONE_COSTS`; `get_perk_cost(…, true, key)` reads that table, so keystone prices are covered at HEAD. What is **not** covered at HEAD and spec §6.3 names explicitly is the **perk cost curve** (`[300, 600, 1100, 1800, 2800]`, `ProgressionManager.ts:558`), plus everything else `ProgressionManager.ts` and `GameOptions.ts` hard-code: the default save (`:421-478`), three catalogs (`:127-404`), five purchasable ladders (`:607-611`), three mode configs (`GameOptions.ts:37-71`) and the default settings (`:77-90`) — roughly 330 literals, the largest transcription surface of any module so far. Task 3 adds a second dumper and fixture for them. `CoinSystem.ts`'s nine constants are module-private (not exported) and cannot be imported; they are pinned by LAW 1 citations and the Task 8 specs assert their values directly.

**Task order rationale.** `SaveStore` first (Task 1) because every later file persists through it; routing the three existing writers (Task 2) proves the API on real callers before the new ones exist. The progression records, catalogs and defaults (Task 3) come with their parity fixture so transcription is checked the moment it is written. Load/save (Task 4) needs the records; the economy (Task 5) and catalog purchases (Task 6) need load/save because every `buy_*` calls `save()`. `GameOptionsManager` (Task 7) is independent and small. `CoinSystem` (Task 8) needs `add_points_credited` as its callback. Wiring (Task 9) comes after every system exists so its specs exercise real instances. Device evidence (Task 10) and exit (Task 11) last.

**Spec §8 M7 coverage.**

| Spec bullet | Task(s) |
|---|---|
| "`meta/save_store.gd` — `user://` JSON, identical shapes and version suffixes, corruption fallback with backup" | 1 (store), 2 (existing writers), 4 (progression shape), 7 (settings shape) |
| "`meta/progression_manager.gd` (full port: perks, ships, cursors, enemy skins, arenas, steering tuning, economy)" | 3 (records, catalogs, defaults), 4 (load/save), 5 (economy, perks), 6 (ships, cursors, skins, arenas, tuning) |
| "`meta/game_options.gd` (full port)" | 7 |
| "`sim/coin_system.gd`" | 8 (sim + draw), 9 (frame-order slot) |
| Accept: "GUT specs pass for the perk cost curve, every `buy_*` method and all multipliers" | 5 (cost curve, `upgrade_perk`, five `buy_*`, four multipliers), 6 (`buy_ship`, `buy_enemy_skin`, `buy_arena_theme`), 3 (cost curve against the TS fixture) |
| Accept: "saves survive a restart" | 4 (round trip through a fresh instance), 7 (same for settings), 10 (on device) |
| Accept: "a deliberately corrupted file falls back to defaults and is backed up" | 1 (store), 4 (progression), 7 (settings), 10 (on device) |
| Spec §4.6 amendment: `tilt_gyro_calibration` routed through `SaveStore` | 2 |
| M2.5 D7: settings files consolidate under `SaveStore` | 2 |
| Spec §5.3: `addPointsCredited` as a `Callable`; `points_changed` | 8, 9 (callback), 5 (signal) |
| Spec §5.4: coins at step 7 | 9 |
| Spec §5.5: coins in `EntityLayer` before orbs | 8 |
| `TiltGame.ts:1551`, `:1567-1570`, `:1599`, `:1601`, `:1888-1889`, `:1965` — progression in the run path | 9 |
| Exit protocol (CONVENTIONS §9) | 11 |

---

## Tasks

### Task 1: `SaveStore` — `user://` JSON with corrupt-file quarantine

**Files:**
- Create: `godot/src/meta/save_store.gd`
- Test: `godot/tests/test_save_store.gd` (new)

**Interfaces:**
- Consumes: `Log.warn` (autoload, `log.gd:36`); `FileAccess`, `DirAccess`, `JSON`, `ProjectSettings.globalize_path`.
- Produces (all `static`):
  - `SaveStore.load_dict(path: String) -> Dictionary` — `{}` when the file is absent; when it exists but does not parse to a JSON object, moves it to `corrupt_path_for(path)` (replacing an older quarantine), warns, returns `{}`.
  - `SaveStore.save_dict(path: String, data: Dictionary) -> bool` — writes `JSON.stringify(data)`; `false` and a warning when the file cannot be opened.
  - `SaveStore.corrupt_path_for(path: String) -> String` — `user://x.json` → `user://x.corrupt.json`.
  - `SaveStore.read_int(d: Dictionary, key: String, fallback: int) -> int`, `read_float(…, fallback: float) -> float`, `read_bool(…, fallback: bool) -> bool`, `read_string(…, fallback: String) -> String`, `read_string_array(d, key) -> Array[String]` (non-strings skipped; `[]` when absent or not an array), `read_dict(d, key) -> Dictionary` (`{}` when absent or not an object). A value of the wrong type yields the fallback.

- [x] **Step 1: Write the failing spec**

Create `godot/tests/test_save_store.gd`:

```gdscript
## test_save_store.gd
## PORTS: nothing — new file, covers src/meta/save_store.gd
extends GutTest
## Proves the user:// JSON store: absent, round trip, corrupt quarantine, and
## the typed readers that every save consumer goes through.

const PATH: String = "user://test_save_store_probe.json"


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "probe file must be writable")
	file.store_string(text)
	file.close()


func before_each() -> void:
	_remove(PATH)
	_remove(SaveStore.corrupt_path_for(PATH))


func after_each() -> void:
	_remove(PATH)
	_remove(SaveStore.corrupt_path_for(PATH))


func test_corrupt_path_swaps_the_extension() -> void:
	assert_eq(SaveStore.corrupt_path_for("user://abc.json"), "user://abc.corrupt.json")
	assert_eq(
		SaveStore.corrupt_path_for("user://tilt_to_live_progression_v3.json"),
		"user://tilt_to_live_progression_v3.corrupt.json"
	)


func test_absent_file_loads_as_empty() -> void:
	assert_false(FileAccess.file_exists(PATH))
	assert_eq(SaveStore.load_dict(PATH), {})
	assert_false(FileAccess.file_exists(PATH), "a load never creates the file")


func test_round_trip_preserves_keys_and_values() -> void:
	var data: Dictionary = {"points": 7331, "name": "classic", "on": true, "list": ["a", "b"]}
	assert_true(SaveStore.save_dict(PATH, data))
	var back: Dictionary = SaveStore.load_dict(PATH)
	assert_eq(SaveStore.read_int(back, "points", 0), 7331, "JSON numbers come back as float")
	assert_eq(SaveStore.read_string(back, "name", ""), "classic")
	assert_true(SaveStore.read_bool(back, "on", false))
	assert_eq(SaveStore.read_string_array(back, "list"), ["a", "b"])


func test_unparseable_file_is_quarantined_and_loads_as_empty() -> void:
	_write_raw(PATH, "{not json")
	assert_eq(SaveStore.load_dict(PATH), {})
	assert_false(FileAccess.file_exists(PATH), "the bad file is moved, not deleted")
	assert_true(FileAccess.file_exists(SaveStore.corrupt_path_for(PATH)), "spec §6.4 backup")
	var kept: FileAccess = FileAccess.open(SaveStore.corrupt_path_for(PATH), FileAccess.READ)
	assert_eq(kept.get_as_text(), "{not json", "the backup is byte-identical")
	kept.close()


func test_non_object_json_is_quarantined() -> void:
	_write_raw(PATH, "[1, 2, 3]")
	assert_eq(SaveStore.load_dict(PATH), {})
	assert_true(FileAccess.file_exists(SaveStore.corrupt_path_for(PATH)))


func test_second_quarantine_replaces_the_first() -> void:
	_write_raw(PATH, "first")
	SaveStore.load_dict(PATH)
	_write_raw(PATH, "second")
	SaveStore.load_dict(PATH)
	var kept: FileAccess = FileAccess.open(SaveStore.corrupt_path_for(PATH), FileAccess.READ)
	assert_eq(kept.get_as_text(), "second")
	kept.close()


func test_typed_readers_fall_back_on_wrong_types() -> void:
	var d: Dictionary = {"i": "x", "f": true, "b": 1.0, "s": 2.0, "arr": "no", "sub": 3.0}
	assert_eq(SaveStore.read_int(d, "i", 9), 9)
	assert_eq(SaveStore.read_int(d, "missing", 9), 9)
	assert_almost_eq(SaveStore.read_float(d, "f", 0.5), 0.5, 0.0001)
	assert_false(SaveStore.read_bool(d, "b", false), "a number is not a bool")
	assert_eq(SaveStore.read_string(d, "s", "dflt"), "dflt")
	assert_eq(SaveStore.read_string_array(d, "arr"), [])
	assert_eq(SaveStore.read_dict(d, "sub"), {})


func test_read_int_accepts_int_and_float() -> void:
	assert_eq(SaveStore.read_int({"a": 3}, "a", 0), 3)
	assert_eq(SaveStore.read_int({"a": 3.0}, "a", 0), 3)
	assert_almost_eq(SaveStore.read_float({"a": 3}, "a", 0.0), 3.0, 0.0001, "int widens")


func test_read_string_array_skips_non_strings() -> void:
	assert_eq(SaveStore.read_string_array({"l": ["a", 1.0, "b", true]}, "l"), ["a", "b"])
```

- [x] **Step 2: Run the spec to verify it fails**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_save_store.gd
```

Expected: exit 1 with a parse error naming `SaveStore` (no such class).

- [x] **Step 3: Check the class name is free, then create the store**

Write `godot/build/class_check.gd` (gitignored):

```gdscript
extends SceneTree
func _init() -> void:
	print("SaveStore exists: %s" % ClassDB.class_exists("SaveStore"))
	quit()
```

Run `"$GODOT" --headless --path godot -s build/class_check.gd`; it must print `false`. Record the observed line in the ledger, delete the script. Then create `godot/src/meta/save_store.gd`:

```gdscript
## save_store.gd
## NO TS COUNTERPART — authorised by spec §4.6 (persistence) and §6.4 (error
## handling). The web game's localStorage.getItem/setItem calls have no file,
## no parse failure that survives a reload and no backup; this is the one
## place those three things exist in the port.
class_name SaveStore
extends RefCounted
## user:// JSON files with corrupt-file quarantine, and the typed readers every
## save consumer uses on the parsed object.
##
## Never instantiated: every member is static, so nothing here is an autoload
## or a singleton (spec §5.2). Callers keep their own file path constant and
## their own JSON shape — this class knows nothing about what it stores.
##
## PORT-NOTE: the TS wraps every localStorage read in try/catch and falls back
## to defaults (ProgressionManager.ts:480-515, GameOptions.ts:92-105,
## ScoreManager.ts:172-184, GyroscopeController.ts:37-46). Spec §6.4 turns that
## into: parse failure → move the file aside as <name>.corrupt.json, warn,
## return {} so the caller applies its defaults. A file that parses but is not
## a JSON object is treated the same way — the TS would spread a non-object
## into defaults and silently lose it; here the evidence is kept.

## The extension a quarantined file gets, replacing ".json".
const CORRUPT_SUFFIX: String = ".corrupt.json"


## Where a corrupt copy of `path` is moved. "user://x.json" -> "user://x.corrupt.json".
static func corrupt_path_for(path: String) -> String:
	return path.trim_suffix(".json") + CORRUPT_SUFFIX


## Reads `path` as a JSON object. {} when absent, unreadable, or quarantined.
static func load_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.warn("SaveStore: %s exists but could not be opened; using defaults" % path)
		return {}
	var raw: String = file.get_as_text()
	file.close()
	# PORT-NOTE: Variant is unavoidable for unvalidated JSON (CONVENTIONS §4);
	# the `is Dictionary` check below narrows it before any read.
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed
	_quarantine(path)
	return {}


## Writes `data` to `path` as JSON. False (and a warning) when the file cannot be opened.
static func save_dict(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Log.warn("SaveStore: %s could not be written" % path)
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


## `d[key]` as an int; `fallback` when absent or not a number. JSON numbers arrive as float.
static func read_int(d: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = d.get(key)
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback


## `d[key]` as a float; `fallback` when absent or not a number.
static func read_float(d: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = d.get(key)
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback


## `d[key]` as a bool; `fallback` when absent or not a bool. A number is not a bool.
static func read_bool(d: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = d.get(key)
	if value is bool:
		return value
	return fallback


## `d[key]` as a String; `fallback` when absent or not a string.
static func read_string(d: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = d.get(key)
	if value is String:
		return value
	return fallback


## `d[key]` as a typed String array; non-string elements are skipped. [] when absent.
static func read_string_array(d: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	var value: Variant = d.get(key)
	if not (value is Array):
		return out
	var items: Array = value
	for item: Variant in items:
		if item is String:
			out.append(item)
	return out


## `d[key]` as a Dictionary; {} when absent or not an object.
static func read_dict(d: Dictionary, key: String) -> Dictionary:
	var value: Variant = d.get(key)
	if value is Dictionary:
		return value
	return {}


static func _quarantine(path: String) -> void:
	var from: String = ProjectSettings.globalize_path(path)
	var to: String = ProjectSettings.globalize_path(corrupt_path_for(path))
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	var err: Error = DirAccess.rename_absolute(from, to)
	if err != OK:
		Log.warn("SaveStore: %s is not a JSON object and could not be moved aside (%d)" % [path, err])
		return
	Log.warn("SaveStore: %s was not a JSON object; moved to %s and using defaults" % [path, to])
```

If the Tier-1 warnings reject any `return value` after an `is` narrowing (they did not for `tilt_input.gd:387-392`'s `calibrated_beta = beta_value`), add `@warning_ignore("unsafe_cast")` above that line only, with the one-line `# PORT-NOTE: narrowed by the is-check above` — `control_settings.gd:81-83` is the precedent. Do not widen the return type to `Variant`.

- [x] **Step 4: Run the spec to verify it passes**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
```

Expected: `OK: 34/34 scripts collected, all tests passed.`; `gdformat` reports every file unchanged; `gdlint` prints nothing. If `test_second_quarantine_replaces_the_first` fails on Windows because `rename_absolute` refuses to overwrite, the `remove_absolute` before it is the fix and is already there — check the observed `err` in the warning text before changing anything else.

- [x] **Step 5: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/src/meta/save_store.gd godot/src/meta/save_store.gd.uid godot/tests/test_save_store.gd godot/tests/test_save_store.gd.uid
git commit -m "M7: add SaveStore so a corrupt user:// file is quarantined not fatal"
git log -1 --format=%B
```

(Godot writes a `.uid` beside every new script on first import; commit both — every existing script has one.)

---

### Task 2: Route the three existing `user://` writers through `SaveStore`

**Files:**
- Modify: `godot/src/sim/score_manager.gd:189-226`, `godot/src/input/tilt_input.gd:17-22`, `:79-107`, `:359-410`, `godot/src/native/control_settings.gd:11-12`, `:37-99`
- Test: `godot/tests/test_score_manager.gd`, `godot/tests/test_tilt_input.gd`, `godot/tests/test_control_settings.gd` (one spec appended to each)

**Interfaces:**
- Consumes: `SaveStore.load_dict`, `save_dict`, `read_int`, `read_float`, `corrupt_path_for` (Task 1).
- Produces: no signature changes. `ScoreManager.BEST_SCORE_PATH`, `TiltInput.CALIBRATION_PATH`, `ControlSettings.SETTINGS_PATH` keep their names and values (tests reference them). Each file's JSON shape is unchanged: `{"bestScore": n}`, `{"beta", "gamma", "gravity": [x, y, z]}`, `{"scheme", "tilt_sensitivity", "tilt_smoothing"}`.

`tilt_input.gd` is the file the user tunes on device between sessions. Confirm `git status --short godot/src/input/tilt_input.gd` is empty before editing it; if not, stop (Precondition).

- [x] **Step 1: Write the three failing specs**

Append to `godot/tests/test_score_manager.gd`:

```gdscript
func test_corrupt_best_score_file_is_quarantined_and_reads_as_zero() -> void:
	var file: FileAccess = FileAccess.open(ScoreManager.BEST_SCORE_PATH, FileAccess.WRITE)
	file.store_string("{{{")
	file.close()
	var sm: ScoreManager = ScoreManager.new()
	assert_eq(sm.stats.best_score, 0, "spec §6.4: defaults, never a crash")
	var backup: String = SaveStore.corrupt_path_for(ScoreManager.BEST_SCORE_PATH)
	assert_true(FileAccess.file_exists(backup), "the bad file is kept as a backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
```

Append to `godot/tests/test_tilt_input.gd` (read its `before_each`/`after_each` first; if it does not already remove `TiltInput.CALIBRATION_PATH`, add that to both, following `test_control_settings.gd:8-19`):

```gdscript
func test_corrupt_calibration_file_is_quarantined_and_keeps_defaults() -> void:
	var file: FileAccess = FileAccess.open(TiltInput.CALIBRATION_PATH, FileAccess.WRITE)
	file.store_string("not json at all")
	file.close()
	var tilt: TiltInput = TiltInput.new()
	assert_almost_eq(tilt.calibrated_beta, TiltInput.DEFAULT_CALIBRATED_BETA, 0.0001)
	var backup: String = SaveStore.corrupt_path_for(TiltInput.CALIBRATION_PATH)
	assert_true(FileAccess.file_exists(backup))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
```

Append to `godot/tests/test_control_settings.gd`:

```gdscript
func test_corrupt_settings_file_is_quarantined_and_keeps_defaults() -> void:
	var file: FileAccess = FileAccess.open(ControlSettings.SETTINGS_PATH, FileAccess.WRITE)
	file.store_string("\"just a string\"")
	file.close()
	var settings: ControlSettings = ControlSettings.new()
	assert_almost_eq(settings.tilt_sensitivity, 1.0, 0.0001)
	var backup: String = SaveStore.corrupt_path_for(ControlSettings.SETTINGS_PATH)
	assert_true(FileAccess.file_exists(backup))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
```

- [x] **Step 2: Run them to verify they fail**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh 2>&1 | grep -E "test_corrupt|FAILED|OK:"
```

Expected: the three new specs fail on the `file_exists(backup)` assertion (today each file reads, warns and keeps the bad file in place). If `test_tilt_input.gd` cannot construct `TiltInput` headless, read how `test_tilt_input_device.gd` does it and match.

- [x] **Step 3: Route `score_manager.gd`**

Replace `score_manager.gd:189-226` (`load_best_score`, `_save_best_score`, `_load_best_score`) with:

```gdscript
## Loads best score from persistent storage. PORT: web/src/tilt-to-live/ScoreManager.ts:172-184
func load_best_score() -> void:
	_load_best_score()


func _save_best_score() -> void:
	# PORT-NOTE: ScoreManager.ts:161 stores the bare integer string under
	# 'tilt_to_live_best'; M2 chose the {"bestScore": n} object so every
	# user:// file is a JSON object. Shape unchanged here; the I/O moves to
	# SaveStore per spec §4.6.
	SaveStore.save_dict(BEST_SCORE_PATH, {"bestScore": stats.best_score})


func _load_best_score() -> void:
	var data: Dictionary = SaveStore.load_dict(BEST_SCORE_PATH)
	var parsed: int = SaveStore.read_int(data, "bestScore", 0)
	# PORT: web/src/tilt-to-live/ScoreManager.ts:177 (Number.isFinite && >= 0)
	stats.best_score = parsed if parsed >= 0 else 0
```

Read the current `_load_best_score` once before deleting it: if it already carries a `PORT-NOTE` about the object shape, keep that wording rather than the one above. The `TODO(M7)` at `:190` is gone with the block.

- [x] **Step 4: Route `tilt_input.gd` — I/O blocks only**

At `:17-20` replace the four comment lines with:

```gdscript
# PORT-NOTE: web/src/tilt-to-live/GyroscopeController.ts:39 uses the
# localStorage key `tilt_gyro_calibration`, a fourth key spec §2.2 does not
# list. Same JSON shape, persisted through SaveStore (spec §4.6 amendment).
```

Replace the body of `save_calibration()` (`:82-107`) with:

```gdscript
	# PORT-NOTE: web/src/tilt-to-live/GyroscopeController.ts:49-54 swallows this
	# failure in a try/catch; SaveStore warns instead, because a silently
	# ignored calibration file is undiagnosable on device.
	SaveStore.save_dict(
		CALIBRATION_PATH,
		{
			"beta": calibrated_beta,
			"gamma": calibrated_gamma,
			# DIVERGENCE(M2.5 §5.2): added key; M2 files without it load
			# as calibration-pending rather than using a stale pose.
			"gravity": [_calibrated_gravity.x, _calibrated_gravity.y, _calibrated_gravity.z],
		}
	)
```

Replace the head of `_load_calibration()` (`:362-377`, from `if not FileAccess.file_exists` through `var data: Dictionary = parsed`) with:

```gdscript
	var data: Dictionary = SaveStore.load_dict(CALIBRATION_PATH)
	if data.is_empty():
		return
```

Keep every line from `var beta_value: Variant = data.get("beta")` (`:378`) to the end of the function exactly as it is — the `is float` / `is Array` reads and the `_calibration_pending` branches are the user's verified device behaviour. The `DIVERGENCE` line count must not change: run `grep -c "DIVERGENCE" godot/src/input/tilt_input.gd` before and after and record both numbers in the ledger.

- [x] **Step 5: Route `control_settings.gd`**

At `:11-12` replace the `TODO(M7)` comment with:

```gdscript
# Persisted through SaveStore alongside tilt_gyro_calibration.json and
# tilt_to_live_best.json, per M2.5 spec D7.
```

Replace the body of `save_settings()` (`:39-58`) with:

```gdscript
	SaveStore.save_dict(
		SETTINGS_PATH,
		{
			"scheme": int(scheme),
			"tilt_sensitivity": tilt_sensitivity,
			"tilt_smoothing": tilt_smoothing,
		}
	)
```

Replace `_load_settings()` (`:61-99`) with:

```gdscript
# An unreadable or wrongly-typed value keeps the default rather than crashing;
# a file that is not a JSON object is quarantined by SaveStore.
func _load_settings() -> void:
	var data: Dictionary = SaveStore.load_dict(SETTINGS_PATH)
	if data.is_empty():
		return

	var ordinal: int = SaveStore.read_int(data, "scheme", int(scheme))
	if ordinal >= Types.ControlScheme.HYBRID and ordinal <= Types.ControlScheme.GYRO:
		scheme = ordinal
	else:
		Log.warn("control settings carry an unknown scheme %d; keeping default" % ordinal)

	tilt_sensitivity = clampf(
		SaveStore.read_float(data, "tilt_sensitivity", tilt_sensitivity),
		MIN_SENSITIVITY,
		MAX_SENSITIVITY
	)
	tilt_smoothing = clampf(
		SaveStore.read_float(data, "tilt_smoothing", tilt_smoothing), MIN_SMOOTHING, MAX_SMOOTHING
	)
```

`scheme = ordinal` assigns an `int` to a `Types.ControlScheme` variable; the existing line `:85` does the same and compiles, so keep it. If a `INT_AS_ENUM_WITHOUT_CAST` warning is reported and is among the nine errors (it is not at HEAD), write `scheme = ordinal as Types.ControlScheme` with the `@warning_ignore("unsafe_cast")` line above it and a `# PORT-NOTE` — `control_settings.gd:81-83` at HEAD is the form.

- [x] **Step 6: Run everything**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
grep -rn "FileAccess.open" godot/src/ | grep -v save_store.gd
grep -rn "TODO(M7)" godot/src/sim/score_manager.gd godot/src/input/tilt_input.gd godot/src/native/control_settings.gd
```

Expected: `OK: 34/34 scripts collected, all tests passed.` (three more tests than Task 1); format and lint clean; **the first grep prints nothing** — after this task `SaveStore` is the only file in `godot/src/` that opens a file; the second grep prints nothing.

- [x] **Step 7: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/src/sim/score_manager.gd godot/src/input/tilt_input.gd godot/src/native/control_settings.gd godot/tests/test_score_manager.gd godot/tests/test_tilt_input.gd godot/tests/test_control_settings.gd
git commit -m "M7: route best score, calibration and settings through SaveStore"
git log -1 --format=%B
```

---

### Task 3: Progression records, catalogs, defaults — and the parity fixture that checks them

**Files:**
- Modify: `godot/src/meta/progression_manager.gd` (restructured: header, enum, constants, `data`, catalogs, `_init`, `_resolve_ship_id`, `_get_default_data`, then every inner class at the end — the M4 `*Perks` classes move verbatim)
- Create: `tools/parity/dump_progression.mjs`, `godot/tests/fixtures/progression.json` (generated), `godot/tests/test_progression_parity.gd`

**Interfaces:**
- Consumes: `Types.WeaponType`, `Types.ABSENT`; `SaveStore.read_*` (Task 1) inside `from_dict`.
- Produces:
  - `enum ProgressionManager.ShipShape { CLASSIC, VIPER, PHANTOM, SOLAR, CYBER, SHURIKEN, CELESTIAL }`
  - `const ProgressionManager.STORAGE_KEY: String = "tilt_to_live_progression_v3"`, `const SAVE_PATH: String = "user://tilt_to_live_progression_v3.json"`
  - Inner classes `ShipSkinConfig`, `EnemySkinConfig`, `ArenaThemeConfig`, `SteeringTuning`, `ProgressionData` (fields below); `SteeringTuning`, `WeaponPerks`, each `<Weapon>Perks` and `ProgressionData` gain `to_dict() -> Dictionary` and `from_dict(d: Dictionary) -> void` (merge: a present, correctly typed key overwrites; anything else keeps the current value).
  - `var data: ProgressionData`, `var ship_catalog: Array[ShipSkinConfig]`, `var cursor_catalog: Array[ShipSkinConfig]` (same array object), `var enemy_skin_catalog: Array[EnemySkinConfig]`, `var arena_theme_catalog: Array[ArenaThemeConfig]`.
  - `_init()` builds the catalogs then sets `data = _get_default_data()` (Task 4 changes this one line to `load_data()`).
  - `_resolve_ship_id(id: String) -> String`, `_get_default_data() -> ProgressionData`.

- [x] **Step 1: Write the parity dumper and generate the fixture**

Create `tools/parity/dump_progression.mjs`:

```javascript
// Dumps ProgressionManager.ts and GameOptions.ts's hard-coded tables to a JSON
// fixture the GUT specs assert against. Spec §6.3 Tier 2 — the perk cost
// curve, the default save, the three catalogs, the purchasable ladders and
// the mode configs are ~330 literals; transcription drift is the risk.
//
// ProgressionManager.ts imports a type from './Types' with no extension, which
// Node's ESM loader cannot resolve and whose type-only export it cannot erase,
// so this script is bundled first. Run from the repository root:
//
//   web/node_modules/.bin/esbuild tools/parity/dump_progression.mjs --bundle \
//     --platform=node --format=esm --outfile=godot/build/dump_progression.bundle.mjs \
//   && node godot/build/dump_progression.bundle.mjs
//
// localStorage does not exist in Node; both constructors catch the
// ReferenceError and return their defaults, which is exactly what is wanted.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { ProgressionManager } from '../../web/src/tilt-to-live/ProgressionManager.ts';
import { GameOptionsManager } from '../../web/src/tilt-to-live/GameOptions.ts';
import { KEYSTONE_COSTS } from '../../web/src/tilt-to-live/WeaponTuning.ts';

// esbuild inlines the source, so resolve the output relative to the repo root
// rather than to this file's (bundled) location.
const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..', '..');
const outDir = resolve(repoRoot, 'godot/tests/fixtures');
mkdirSync(outDir, { recursive: true });

const progression = new ProgressionManager();
const options = new GameOptionsManager();

const perkCostCurve = [0, 1, 2, 3, 4, 5, 9].map((rank) => ({ rank, cost: progression.getPerkCost(rank) }));
const keystoneCosts = Object.keys(KEYSTONE_COSTS).map((key) => ({ key, cost: progression.getPerkCost(0, true, key) }));
keystoneCosts.push({ key: 'nosuch', cost: progression.getPerkCost(0, true, 'nosuch') });
keystoneCosts.push({ key: '', cost: progression.getPerkCost(0, true) });

const ladders = {};
for (const [name, getter, field] of [
  ['extraLives', 'getExtraLivesCost', 'extraLives'],
  ['hullCompact', 'getHullCompactCost', 'hullCompact'],
  ['enemySlow', 'getEnemySlowCost', 'enemySlow'],
  ['scoreMultiplier', 'getScoreMultiplierCost', 'scoreMultiplier'],
  ['pointsMultiplier', 'getPointsMultiplierCost', 'pointsMultiplier']
]) {
  const p = new ProgressionManager();
  const costs = [];
  for (let rank = 0; rank < 6; rank++) {
    p.data[field] = rank;
    costs.push(p[getter]()); // null past the ladder's end
  }
  ladders[name] = costs;
}

const invested = {};
for (const weapon of Object.keys(progression.data.perks)) {
  invested[weapon] = progression.getWeaponInvestedPoints(weapon);
}

const file = resolve(outDir, 'progression.json');
writeFileSync(
  file,
  JSON.stringify(
    {
      source: 'web/src/tilt-to-live/ProgressionManager.ts, GameOptions.ts',
      generated_by: 'tools/parity/dump_progression.mjs',
      default_data: progression.data,
      ship_catalog: progression.shipCatalog,
      enemy_skin_catalog: progression.enemySkinCatalog,
      arena_theme_catalog: progression.arenaThemeCatalog,
      perk_cost_curve: perkCostCurve,
      keystone_costs: keystoneCosts,
      purchasable_ladders: ladders,
      invested_points_at_defaults: invested,
      multipliers_at_defaults: {
        startingLives: progression.getStartingLives(),
        hitbox: progression.getHitboxMultiplier(),
        enemySpeed: progression.getEnemySpeedMultiplier(),
        score: progression.getScoreMultiplier(),
        points: progression.getPointsMultiplier()
      },
      modes: options.modes,
      default_settings: options.settings,
      shake_multipliers: ['off', 'low', 'normal', 'extreme', 'full', 'bogus'].map((screenShake) => {
        const o = new GameOptionsManager();
        o.settings.screenShake = screenShake;
        return { screenShake, multiplier: o.getShakeMultiplier() };
      })
    },
    null,
    2
  ) + '\n'
);
console.log(`wrote ${file}`);
```

Run it:

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
web/node_modules/.bin/esbuild tools/parity/dump_progression.mjs --bundle --platform=node --format=esm --outfile=godot/build/dump_progression.bundle.mjs --log-level=warning && node godot/build/dump_progression.bundle.mjs
head -c 400 godot/tests/fixtures/progression.json
node -e "const f=require('./godot/tests/fixtures/progression.json'); console.log(f.default_data.points, f.perk_cost_curve.map(c=>c.cost).join(','), f.ship_catalog.length, f.purchasable_ladders.extraLives.join(','), f.invested_points_at_defaults.blackhole)"
```

Expected: `wrote …/godot/tests/fixtures/progression.json`; the `node -e` line prints `7331 300,600,1100,1800,2800,2800,2800 7 4000,9000,,,, 6700` (the empty entries are `null`s past the ladder). If the esbuild step reports a resolution error, `web/node_modules` is missing — run `cd web && npm ci` and retry; do not edit the TS. `godot/build/` is gitignored; the bundle is scratch.

- [x] **Step 2: Write the failing parity spec**

Create `godot/tests/test_progression_parity.gd`:

```gdscript
## test_progression_parity.gd
## PORTS: nothing — new file, spec §6.3 Tier 2 constant-parity harness
extends GutTest
## Asserts meta/progression_manager.gd's defaults, catalogs and cost tables
## equal the TypeScript byte for byte, via the fixture generated by
## tools/parity/dump_progression.mjs.

const FIXTURE_PATH: String = "res://tests/fixtures/progression.json"

# PORT-NOTE: mappings local to the spec — the fixture carries the TS string
# forms and the port carries enums; only the spelling is compared here.
const WEAPON_NAMES: Dictionary[String, Types.WeaponType] = {
	"nuke": Types.WeaponType.NUKE,
	"missiles": Types.WeaponType.MISSILES,
	"lightning": Types.WeaponType.LIGHTNING,
	"laser": Types.WeaponType.LASER,
	"vortex": Types.WeaponType.VORTEX,
	"freeze": Types.WeaponType.FREEZE,
	"shield": Types.WeaponType.SHIELD,
}
const SHAPE_NAMES: Dictionary[String, ProgressionManager.ShipShape] = {
	"classic": ProgressionManager.ShipShape.CLASSIC,
	"viper": ProgressionManager.ShipShape.VIPER,
	"phantom": ProgressionManager.ShipShape.PHANTOM,
	"solar": ProgressionManager.ShipShape.SOLAR,
	"cyber": ProgressionManager.ShipShape.CYBER,
	"shuriken": ProgressionManager.ShipShape.SHURIKEN,
	"celestial": ProgressionManager.ShipShape.CELESTIAL,
}

var _fixture: Dictionary = {}
var _pm: ProgressionManager = null


func _remove_save() -> void:
	var absolute: String = ProjectSettings.globalize_path(ProgressionManager.SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_all() -> void:
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	assert_not_null(file, "missing fixture — see tools/parity/dump_progression.mjs header")
	var raw: String = file.get_as_text()
	file.close()
	# PORT-NOTE: Variant is unavoidable for unvalidated JSON; CONVENTIONS §4
	# permits it here and the next line narrows it immediately.
	var parsed: Variant = JSON.parse_string(raw)
	assert_true(parsed is Dictionary, "fixture must be a JSON object")
	_fixture = parsed


func before_each() -> void:
	_remove_save()
	_pm = ProgressionManager.new()


func after_each() -> void:
	_remove_save()


# CSS colour strings as the TS writes them: '#rrggbb' or 'rgba(r, g, b, a)'.
func _css_color(text: String) -> Color:
	if text.begins_with("#"):
		return Color(text)
	var inner: String = text.trim_prefix("rgba(").trim_suffix(")")
	var parts: PackedStringArray = inner.split(",")
	assert_eq(parts.size(), 4, "rgba() has four components: %s" % text)
	return Color(
		parts[0].strip_edges().to_float() / 255.0,
		parts[1].strip_edges().to_float() / 255.0,
		parts[2].strip_edges().to_float() / 255.0,
		parts[3].strip_edges().to_float()
	)


func _assert_color(actual: Color, css: String, what: String) -> void:
	var want: Color = _css_color(css)
	assert_almost_eq(actual.r, want.r, 0.002, "%s r" % what)
	assert_almost_eq(actual.g, want.g, 0.002, "%s g" % what)
	assert_almost_eq(actual.b, want.b, 0.002, "%s b" % what)
	assert_almost_eq(actual.a, want.a, 0.002, "%s a" % what)


func _assert_dict_numbers_equal(actual: Dictionary, expected: Dictionary, what: String) -> void:
	assert_eq(actual.keys().size(), expected.keys().size(), "%s key count" % what)
	for key: String in expected.keys():
		assert_true(actual.has(key), "%s is missing %s" % [what, key])
		var want: Variant = expected[key]
		if want is bool:
			assert_eq(SaveStore.read_bool(actual, key, not want), want, "%s.%s" % [what, key])
		elif want is float:
			assert_almost_eq(
				SaveStore.read_float(actual, key, -1.0), want, 0.0001, "%s.%s" % [what, key]
			)
		elif want is Dictionary:
			assert_true(actual[key] is Dictionary, "%s.%s is an object" % [what, key])
			var sub: Dictionary = actual[key]
			_assert_dict_numbers_equal(sub, want, "%s.%s" % [what, key])
		elif want is String:
			assert_eq(SaveStore.read_string(actual, key, ""), want, "%s.%s" % [what, key])
		elif want is Array:
			assert_eq(SaveStore.read_string_array(actual, key), want, "%s.%s" % [what, key])
		else:
			fail_test("%s.%s has an unexpected fixture type" % [what, key])


func test_default_data_matches_the_typescript() -> void:
	_assert_dict_numbers_equal(_pm.data.to_dict(), _fixture["default_data"], "default_data")


func test_ship_catalog_matches_the_typescript() -> void:
	var expected: Array = _fixture["ship_catalog"]
	assert_eq(_pm.ship_catalog.size(), expected.size(), "ship count")
	assert_true(_pm.cursor_catalog == _pm.ship_catalog, "cursorCatalog is shipCatalog (:278)")
	for i: int in range(expected.size()):
		var want: Dictionary = expected[i]
		var ship: ProgressionManager.ShipSkinConfig = _pm.ship_catalog[i]
		var tag: String = "ship[%d]" % i
		assert_eq(ship.id, SaveStore.read_string(want, "id", ""), tag)
		assert_eq(ship.name, SaveStore.read_string(want, "name", ""), tag)
		assert_eq(ship.trait, SaveStore.read_string(want, "trait", ""), tag)
		assert_eq(ship.price, SaveStore.read_int(want, "price", -1), tag)
		assert_eq(ship.description, SaveStore.read_string(want, "description", ""), tag)
		assert_eq(ship.hitbox, SaveStore.read_string(want, "hitbox", ""), tag)
		assert_eq(ship.turn, SaveStore.read_string(want, "turn", ""), tag)
		assert_almost_eq(ship.hitbox_scale, SaveStore.read_float(want, "hitboxScale", -1.0), 0.0001, tag)
		assert_almost_eq(ship.turn_rate, SaveStore.read_float(want, "turnRate", -1.0), 0.0001, tag)
		assert_eq(ship.starting_weapon, WEAPON_NAMES[SaveStore.read_string(want, "startingWeapon", "")], tag)
		assert_eq(ship.bonus_lives, SaveStore.read_int(want, "bonusLives", 0), tag)
		_assert_color(ship.tint, SaveStore.read_string(want, "tint", ""), tag + " tint")
		assert_eq(ship.svg_path, SaveStore.read_string(want, "svgPath", ""), tag)
		_assert_color(ship.hull_color, SaveStore.read_string(want, "hullColor", ""), tag + " hull")
		_assert_color(ship.primary_color, SaveStore.read_string(want, "primaryColor", ""), tag + " primary")
		_assert_color(ship.accent_color, SaveStore.read_string(want, "accentColor", ""), tag + " accent")
		_assert_color(ship.thruster_color, SaveStore.read_string(want, "thrusterColor", ""), tag + " thruster")
		_assert_color(ship.trail_color, SaveStore.read_string(want, "trailColor", ""), tag + " trail")
		_assert_color(ship.tether_color, SaveStore.read_string(want, "tetherColor", ""), tag + " tether")
		assert_eq(ship.shape, SHAPE_NAMES[SaveStore.read_string(want, "shape", "")], tag)


func test_enemy_skin_catalog_matches_the_typescript() -> void:
	var expected: Array = _fixture["enemy_skin_catalog"]
	assert_eq(_pm.enemy_skin_catalog.size(), expected.size(), "skin count")
	for i: int in range(expected.size()):
		var want: Dictionary = expected[i]
		var skin: ProgressionManager.EnemySkinConfig = _pm.enemy_skin_catalog[i]
		var tag: String = "skin[%d]" % i
		assert_eq(skin.id, SaveStore.read_string(want, "id", ""), tag)
		assert_eq(skin.name, SaveStore.read_string(want, "name", ""), tag)
		assert_eq(skin.price, SaveStore.read_int(want, "price", -1), tag)
		assert_eq(skin.description, SaveStore.read_string(want, "description", ""), tag)
		_assert_color(skin.glow_color, SaveStore.read_string(want, "glowColor", ""), tag + " glow")
		var gradient: Array[String] = SaveStore.read_string_array(want, "bodyGradient")
		assert_eq(skin.body_gradient.size(), 3, tag)
		for g: int in range(3):
			_assert_color(skin.body_gradient[g], gradient[g], "%s gradient[%d]" % [tag, g])
		_assert_color(skin.pupil_color, SaveStore.read_string(want, "pupilColor", ""), tag + " pupil")
		_assert_color(skin.border_color, SaveStore.read_string(want, "borderColor", ""), tag + " border")


func test_arena_theme_catalog_matches_the_typescript() -> void:
	var expected: Array = _fixture["arena_theme_catalog"]
	assert_eq(_pm.arena_theme_catalog.size(), expected.size(), "arena count")
	for i: int in range(expected.size()):
		var want: Dictionary = expected[i]
		var arena: ProgressionManager.ArenaThemeConfig = _pm.arena_theme_catalog[i]
		var tag: String = "arena[%d]" % i
		assert_eq(arena.id, SaveStore.read_string(want, "id", ""), tag)
		assert_eq(arena.name, SaveStore.read_string(want, "name", ""), tag)
		assert_eq(arena.price, SaveStore.read_int(want, "price", -1), tag)
		assert_eq(arena.description, SaveStore.read_string(want, "description", ""), tag)
		var gradient: Array[String] = SaveStore.read_string_array(want, "bgGradient")
		assert_eq(arena.bg_gradient.size(), 3, tag)
		for g: int in range(3):
			_assert_color(arena.bg_gradient[g], gradient[g], "%s gradient[%d]" % [tag, g])
		_assert_color(arena.grid_color, SaveStore.read_string(want, "gridColor", ""), tag + " grid")
		_assert_color(arena.boundary_color, SaveStore.read_string(want, "boundaryColor", ""), tag + " boundary")
		_assert_color(arena.dust_color, SaveStore.read_string(want, "dustColor", ""), tag + " dust")
```

The cost-curve, ladder, invested-points, multiplier and options specs are appended to this file in Tasks 5 and 7, once those members exist. Do not add them now.

- [x] **Step 3: Run the spec to verify it fails**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_progression_parity.gd
```

Expected: exit 1 — `ProgressionManager.ShipShape`, `SAVE_PATH`, `ShipSkinConfig` do not exist.

- [x] **Step 4: Restructure and extend `progression_manager.gd`**

Rewrite `godot/src/meta/progression_manager.gd` to the content below. The seven `*Perks` classes and `WeaponPerks` from M4 are **moved verbatim** to the inner-class block at the end and each gains `to_dict`/`from_dict`; nothing else about them changes (their field names are read by `weapon_system.gd` and the M4 specs). `gdlint`'s `class-definitions-order` requires enums, constants and variables before functions and inner classes, which is why the M4 classes move (CONVENTIONS §2 item 12: inner classes last).

```gdscript
## progression_manager.gd
## PORTS: web/src/tilt-to-live/ProgressionManager.ts (940 lines, source commit 7be9614)
class_name ProgressionManager
extends RefCounted
## Perk ranks, ships, cursors, enemy skins, arenas, steering tuning and the
## points economy, persisted as user://tilt_to_live_progression_v3.json.
##
## PORT-NOTE: getCursorSvgDataUri() (ProgressionManager.ts:802-871) and
## getShipSvgPreview() (:873-939) build SVG markup for the browser's CSS
## cursor and the Armory's <img> preview. Neither has a consumer in Godot —
## Android has no pointer cursor and the Armory is a Control scene — so
## neither is ported, the same relocation-out M3/M4 made for render().
## TODO(M8): the Armory decides how a ship preview is drawn.
##
## PORT-NOTE: ProgressionManager.ts:9-43 types each weapon's perks as an
## anonymous nested object. GDScript needs named types, so each nesting is an
## inner class named <Weapon>Perks; the field names inside are the TS names
## snake_cased and unchanged. Ranks default to 0 and keystones to false, which
## is exactly what `perks?.x.y || 0` / `!!perks?.x.y` read when perks is absent.
##
## PORT-NOTE: the save shape is JSON.stringify(this.data) (:519) with the TS
## camelCase keys. Every record below carries to_dict()/from_dict() — the only
## place the camelCase spellings appear — so the file a web build wrote loads
## here unchanged (spec §4.6).

## PORT: web/src/tilt-to-live/ProgressionManager.ts:68
enum ShipShape { CLASSIC, VIPER, PHANTOM, SOLAR, CYBER, SHURIKEN, CELESTIAL }

## PORT: web/src/tilt-to-live/ProgressionManager.ts:119
const STORAGE_KEY: String = "tilt_to_live_progression_v3"
## The localStorage key as a user:// file (spec §4.6).
const SAVE_PATH: String = "user://" + STORAGE_KEY + ".json"

## The player's progression. PORT: web/src/tilt-to-live/ProgressionManager.ts:122
var data: ProgressionData = null

## The seven ships. PORT: web/src/tilt-to-live/ProgressionManager.ts:127-276
## Ship hitbox/turn display strings derive directly from the numeric fields:
##   hitbox% = round(hitboxScale * 50), turn% = round(turnRate * 60)
var ship_catalog: Array[ShipSkinConfig] = []
## The same array as ship_catalog. PORT: web/src/tilt-to-live/ProgressionManager.ts:278
var cursor_catalog: Array[ShipSkinConfig] = []
## PORT: web/src/tilt-to-live/ProgressionManager.ts:280-341
var enemy_skin_catalog: Array[EnemySkinConfig] = []
## PORT: web/src/tilt-to-live/ProgressionManager.ts:343-404
var arena_theme_catalog: Array[ArenaThemeConfig] = []


## PORT: web/src/tilt-to-live/ProgressionManager.ts:406-408
# PORT-NOTE: the TS initialises the catalogs as field initialisers, which run
# before the constructor body; here they are built first for the same effect.
func _init() -> void:
	ship_catalog = _build_ship_catalog()
	cursor_catalog = ship_catalog
	enemy_skin_catalog = _build_enemy_skin_catalog()
	arena_theme_catalog = _build_arena_theme_catalog()
	data = _get_default_data()


## PORT: web/src/tilt-to-live/ProgressionManager.ts:410-419
func _resolve_ship_id(id: String) -> String:
	var map: Dictionary[String, String] = {
		"arrow": "classic",
		"viper": "tactical",
		"phantom": "singularity",
		"aegis": "solar",
		"matrix": "cyber",
	}
	return map.get(id.to_lower(), id)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:421-478
func _get_default_data() -> ProgressionData:
	var d: ProgressionData = ProgressionData.new()
	d.points = 7331  # PORT: web/src/tilt-to-live/ProgressionManager.ts:423
	d.lifetime_points = 7331  # PORT: web/src/tilt-to-live/ProgressionManager.ts:424
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:425-461
	d.perks.blackhole.duration = 3
	d.perks.blackhole.radius = 2
	d.perks.blackhole.gravity = 4
	d.perks.blackhole.invulnerable_inside = false
	d.perks.blackhole.supernova_collapse = false
	d.perks.nuke.radius = 1
	d.perks.nuke.speed = 0
	d.perks.nuke.fallout_zone = false
	d.perks.shield.duration = 0
	d.perks.shield.radius = 0
	d.perks.shield.battering_ram = false
	d.perks.missiles.count = 5
	d.perks.missiles.blast_radius = 0
	d.perks.missiles.flight_speed = 0
	d.perks.laser.length = 2
	d.perks.laser.duration = 0
	d.perks.laser.cross_beam = false
	d.perks.lightning.max_targets = 0
	d.perks.lightning.chain_range = 0
	d.perks.freeze.duration = 0
	d.perks.freeze.shatter_cascade = false
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:462-467
	d.equipped_cursor_id = "classic"
	d.unlocked_cursors = ["classic", "tactical", "singularity"]
	d.equipped_enemy_skin_id = "classic"
	d.unlocked_enemy_skins = ["classic"]
	d.equipped_arena_theme_id = "void"
	d.unlocked_arena_themes = ["void"]
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:468-471
	d.tuning.sensitivity = 1.0
	d.tuning.deadzone = 4.0
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:472-476
	d.extra_lives = 0
	d.hull_compact = 0
	d.enemy_slow = 0
	d.score_multiplier = 0
	d.points_multiplier = 0
	return d


# PORT: web/src/tilt-to-live/ProgressionManager.ts:127-276
# PORT-NOTE: each TS object literal becomes a typed record filled field by
# field; the field order inside each block is the TS order.
func _build_ship_catalog() -> Array[ShipSkinConfig]:
	var out: Array[ShipSkinConfig] = []

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:128-148
	var classic: ShipSkinConfig = ShipSkinConfig.new()
	classic.id = "classic"
	classic.name = "Arrow"
	classic.trait = "Balanced"
	classic.price = 0
	classic.description = "The iconic high-agility balanced arrow craft with sharp delta wings."
	classic.hitbox = "50%"
	classic.turn = "60%"
	classic.hitbox_scale = 1.0
	classic.turn_rate = 1.0
	classic.starting_weapon = Types.WeaponType.SHIELD
	classic.tint = Color("#5B8CFF")
	classic.svg_path = "M40 24 L14 10 L19 24 L14 38 Z"
	classic.hull_color = Color("#ffffff")
	classic.primary_color = Color("#5B8CFF")
	classic.accent_color = Color("#8FB0FF")
	classic.thruster_color = Color("#5B8CFF")
	classic.trail_color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.4)
	classic.tether_color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.25)
	classic.shape = ShipShape.CLASSIC
	out.append(classic)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:149-169
	var tactical: ShipSkinConfig = ShipSkinConfig.new()
	tactical.id = "tactical"
	tactical.name = "Viper"
	tactical.trait = "Aggressive"
	tactical.price = 0
	tactical.description = "Aggressive forward-swept fighter jet with high turn speed."
	tactical.hitbox = "60%"
	tactical.turn = "81%"
	tactical.hitbox_scale = 1.20
	tactical.turn_rate = 1.35
	tactical.starting_weapon = Types.WeaponType.MISSILES
	tactical.tint = Color("#FF8A94")
	tactical.svg_path = "M40 24 L12 8 L20 24 L12 40 Z"
	tactical.hull_color = Color("#161924")
	tactical.primary_color = Color("#FF8A94")
	tactical.accent_color = Color("#ff2a4b")
	tactical.thruster_color = Color("#ff5500")
	tactical.trail_color = Color(255.0 / 255.0, 138.0 / 255.0, 148.0 / 255.0, 0.4)
	tactical.tether_color = Color(255.0 / 255.0, 138.0 / 255.0, 148.0 / 255.0, 0.35)
	tactical.shape = ShipShape.VIPER
	out.append(tactical)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:170-190
	var singularity: ShipSkinConfig = ShipSkinConfig.new()
	singularity.id = "singularity"
	singularity.name = "Phantom"
	singularity.trait = "Evasive"
	singularity.price = 0
	singularity.description = (
		"Ultra-thin evasive voidcraft with minuscule hitbox to slip past dense swarms."
	)
	singularity.hitbox = "20%"
	singularity.turn = "48%"
	singularity.hitbox_scale = 0.40
	singularity.turn_rate = 0.80
	singularity.starting_weapon = Types.WeaponType.FREEZE
	singularity.tint = Color("#A78BFA")
	singularity.svg_path = "M42 24 L10 12 L22 24 L10 36 Z"
	singularity.hull_color = Color("#160826")
	singularity.primary_color = Color("#A78BFA")
	singularity.accent_color = Color("#b84dff")
	singularity.thruster_color = Color("#9933ff")
	singularity.trail_color = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0, 0.4)
	singularity.tether_color = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0, 0.35)
	singularity.shape = ShipShape.PHANTOM
	out.append(singularity)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:191-211
	var solar: ShipSkinConfig = ShipSkinConfig.new()
	solar.id = "solar"
	solar.name = "Aegis"
	solar.trait = "Heavy"
	solar.price = 600
	solar.description = (
		"Heavy reinforced armored chassis with immense presence and slower turn rate."
	)
	solar.hitbox = "95%"
	solar.turn = "27%"
	solar.hitbox_scale = 1.90
	solar.turn_rate = 0.45
	solar.starting_weapon = Types.WeaponType.NUKE
	solar.tint = Color("#FFB14D")
	solar.svg_path = "M41 24 L33 9 L17 9 L7 24 L17 39 L33 39 Z"
	solar.hull_color = Color("#ffd700")
	solar.primary_color = Color("#FFB14D")
	solar.accent_color = Color("#ffffff")
	solar.thruster_color = Color("#ffaa00")
	solar.trail_color = Color(255.0 / 255.0, 177.0 / 255.0, 77.0 / 255.0, 0.4)
	solar.tether_color = Color(255.0 / 255.0, 177.0 / 255.0, 77.0 / 255.0, 0.35)
	solar.shape = ShipShape.SOLAR
	out.append(solar)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:212-232
	var cyber: ShipSkinConfig = ShipSkinConfig.new()
	cyber.id = "cyber"
	cyber.name = "Matrix"
	cyber.trait = "Fast cooldown"
	cyber.price = 800
	cyber.description = (
		"Digital diamond vector hull tuned for fast responses and tight maneuvers."
	)
	cyber.hitbox = "53%"
	cyber.turn = "78%"
	cyber.hitbox_scale = 1.05
	cyber.turn_rate = 1.30
	cyber.starting_weapon = Types.WeaponType.LIGHTNING
	cyber.tint = Color("#3DDC97")
	cyber.svg_path = "M24 6 L40 24 L24 42 L8 24 Z"
	cyber.hull_color = Color("#0a1220")
	cyber.primary_color = Color("#3DDC97")
	cyber.accent_color = Color("#00ffff")
	cyber.thruster_color = Color("#ff00aa")
	cyber.trail_color = Color(61.0 / 255.0, 220.0 / 255.0, 151.0 / 255.0, 0.4)
	cyber.tether_color = Color(61.0 / 255.0, 220.0 / 255.0, 151.0 / 255.0, 0.32)
	cyber.shape = ShipShape.CYBER
	out.append(cyber)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:233-253
	var shuriken: ShipSkinConfig = ShipSkinConfig.new()
	shuriken.id = "shuriken"
	shuriken.name = "Shuriken"
	shuriken.trait = "Spin drift"
	shuriken.price = 1000
	shuriken.description = (
		"Starframe chassis boasting extreme rotational acceleration and spin agility."
	)
	shuriken.hitbox = "43%"
	shuriken.turn = "96%"
	shuriken.hitbox_scale = 0.85
	shuriken.turn_rate = 1.60
	shuriken.starting_weapon = Types.WeaponType.LASER
	shuriken.tint = Color("#8FB0FF")
	shuriken.svg_path = "M24 6 L30 18 L42 24 L30 30 L24 42 L18 30 L6 24 L18 18 Z"
	shuriken.hull_color = Color("#082014")
	shuriken.primary_color = Color("#8FB0FF")
	shuriken.accent_color = Color("#88ffcc")
	shuriken.thruster_color = Color("#5b8cff")
	shuriken.trail_color = Color(143.0 / 255.0, 176.0 / 255.0, 255.0 / 255.0, 0.4)
	shuriken.tether_color = Color(143.0 / 255.0, 176.0 / 255.0, 255.0 / 255.0, 0.35)
	shuriken.shape = ShipShape.SHURIKEN
	out.append(shuriken)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:254-275
	var revenant: ShipSkinConfig = ShipSkinConfig.new()
	revenant.id = "revenant"
	revenant.name = "Revenant"
	revenant.trait = "Second wind"
	revenant.price = 2500
	revenant.description = (
		"A ghostly celestial hull reforged from lost light, granting one extra life to rise again."
	)
	revenant.hitbox = "68%"
	revenant.turn = "54%"
	revenant.hitbox_scale = 1.35
	revenant.turn_rate = 0.90
	revenant.starting_weapon = Types.WeaponType.VORTEX
	revenant.bonus_lives = 1
	revenant.tint = Color("#FFB14D")
	revenant.svg_path = "M40 24 L16 8 L22 24 L16 40 Z"
	revenant.hull_color = Color("#f8fafc")
	revenant.primary_color = Color("#FFB14D")
	revenant.accent_color = Color("#38bdf8")
	revenant.thruster_color = Color("#38bdf8")
	revenant.trail_color = Color(255.0 / 255.0, 177.0 / 255.0, 77.0 / 255.0, 0.4)
	revenant.tether_color = Color(255.0 / 255.0, 177.0 / 255.0, 77.0 / 255.0, 0.35)
	revenant.shape = ShipShape.CELESTIAL
	out.append(revenant)

	return out


# PORT: web/src/tilt-to-live/ProgressionManager.ts:280-341
func _build_enemy_skin_catalog() -> Array[EnemySkinConfig]:
	var out: Array[EnemySkinConfig] = []

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:281-290
	var classic: EnemySkinConfig = EnemySkinConfig.new()
	classic.id = "classic"
	classic.name = "Classic Crimson"
	classic.price = 0
	classic.description = "The iconic evil red dots with sinister crimson body and dark pupil."
	classic.glow_color = Color(255.0 / 255.0, 30.0 / 255.0, 60.0 / 255.0, 0.35)
	classic.body_gradient = [Color("#ff6677"), Color("#ee1133"), Color("#990011")]
	classic.pupil_color = Color("#110005")
	classic.border_color = Color("#ff8899")
	out.append(classic)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:291-300
	var toxic: EnemySkinConfig = EnemySkinConfig.new()
	toxic.id = "toxic"
	toxic.name = "Toxic Biohazard"
	toxic.price = 400
	toxic.description = "Radioactive neon-green cellular organisms with bubbling caustic cores."
	toxic.glow_color = Color(0.0 / 255.0, 255.0 / 255.0, 100.0 / 255.0, 0.35)
	toxic.body_gradient = [Color("#88ff99"), Color("#11ee44"), Color("#007722")]
	toxic.pupil_color = Color("#021805")
	toxic.border_color = Color("#aaffbb")
	out.append(toxic)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:301-310
	var glitch: EnemySkinConfig = EnemySkinConfig.new()
	glitch.id = "glitch"
	glitch.name = "Cyber Glitch"
	glitch.price = 600
	glitch.description = (
		"Polygon wireframe cyber dots flickering between electric cyan and hot magenta."
	)
	glitch.glow_color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.4)
	glitch.body_gradient = [Color("#88ffff"), Color("#00bfff"), Color("#0044aa")]
	glitch.pupil_color = Color("#ff0077")
	glitch.border_color = Color("#5B8CFF")
	out.append(glitch)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:311-320
	var magma: EnemySkinConfig = EnemySkinConfig.new()
	magma.id = "magma"
	magma.name = "Molten Magma"
	magma.price = 800
	magma.description = "Volcanic burning ember cores encased in cracked obsidian rock."
	magma.glow_color = Color(255.0 / 255.0, 120.0 / 255.0, 0.0 / 255.0, 0.4)
	magma.body_gradient = [Color("#ffcc00"), Color("#ff5500"), Color("#881100")]
	magma.pupil_color = Color("#2b0800")
	magma.border_color = Color("#ffaa33")
	out.append(magma)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:321-330
	var void_skin: EnemySkinConfig = EnemySkinConfig.new()
	void_skin.id = "void"
	void_skin.name = "Abyssal Void"
	void_skin.price = 1000
	void_skin.description = (
		"Pitch-black shadow orbs surrounded by a pulsating violet event horizon."
	)
	void_skin.glow_color = Color(180.0 / 255.0, 50.0 / 255.0, 255.0 / 255.0, 0.45)
	void_skin.body_gradient = [Color("#9944ff"), Color("#330066"), Color("#080014")]
	void_skin.pupil_color = Color("#ffffff")
	void_skin.border_color = Color("#cc88ff")
	out.append(void_skin)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:331-340
	var gold: EnemySkinConfig = EnemySkinConfig.new()
	gold.id = "gold"
	gold.name = "Midas Gold"
	gold.price = 1500
	gold.description = "Polished metallic reflective 24K gold spheres with radiant star gleams."
	gold.glow_color = Color(255.0 / 255.0, 215.0 / 255.0, 0.0 / 255.0, 0.45)
	gold.body_gradient = [Color("#fff6b3"), Color("#FFB14D"), Color("#aa7700")]
	gold.pupil_color = Color("#442a00")
	gold.border_color = Color("#fff088")
	out.append(gold)

	return out


# PORT: web/src/tilt-to-live/ProgressionManager.ts:343-404
func _build_arena_theme_catalog() -> Array[ArenaThemeConfig]:
	var out: Array[ArenaThemeConfig] = []

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:344-353
	var void_arena: ArenaThemeConfig = ArenaThemeConfig.new()
	void_arena.id = "void"
	void_arena.name = "Void Vector"
	void_arena.price = 0
	void_arena.description = "Deep midnight void canvas with classic reactive cyan vector mesh."
	void_arena.bg_gradient = [Color("#100c1e"), Color("#090712"), Color("#040308")]
	void_arena.grid_color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.18)
	void_arena.boundary_color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.4)
	void_arena.dust_color = Color("#5B8CFF")
	out.append(void_arena)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:354-363
	var synthwave: ArenaThemeConfig = ArenaThemeConfig.new()
	synthwave.id = "synthwave"
	synthwave.name = "Synthwave Sunset"
	synthwave.price = 400
	synthwave.description = "Ultraviolet to magenta gradient with electric hot-pink grid lines."
	synthwave.bg_gradient = [Color("#280838"), Color("#140020"), Color("#08000d")]
	synthwave.grid_color = Color(255.0 / 255.0, 0.0 / 255.0, 160.0 / 255.0, 0.22)
	synthwave.boundary_color = Color(255.0 / 255.0, 0.0 / 255.0, 180.0 / 255.0, 0.5)
	synthwave.dust_color = Color("#ff00aa")
	out.append(synthwave)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:364-373
	var nebula: ArenaThemeConfig = ArenaThemeConfig.new()
	nebula.id = "nebula"
	nebula.name = "Cosmic Nebula"
	nebula.price = 600
	nebula.description = (
		"Living deep-space expanse with cobalt-purple stars and drifting violet dust."
	)
	nebula.bg_gradient = [Color("#0f1738"), Color("#070b1c"), Color("#02040b")]
	nebula.grid_color = Color(130.0 / 255.0, 90.0 / 255.0, 255.0 / 255.0, 0.22)
	nebula.boundary_color = Color(150.0 / 255.0, 100.0 / 255.0, 255.0 / 255.0, 0.5)
	nebula.dust_color = Color("#aa77ff")
	out.append(nebula)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:374-383
	var matrix: ArenaThemeConfig = ArenaThemeConfig.new()
	matrix.id = "matrix"
	matrix.name = "Matrix Terminal"
	matrix.price = 800
	matrix.description = (
		"Dark circuit-board grid with emerald data pulses and digital matrix ambience."
	)
	matrix.bg_gradient = [Color("#041a0d"), Color("#020d06"), Color("#010502")]
	matrix.grid_color = Color(0.0 / 255.0, 255.0 / 255.0, 120.0 / 255.0, 0.22)
	matrix.boundary_color = Color(0.0 / 255.0, 255.0 / 255.0, 120.0 / 255.0, 0.5)
	matrix.dust_color = Color("#00ff88")
	out.append(matrix)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:384-393
	var supernova: ArenaThemeConfig = ArenaThemeConfig.new()
	supernova.id = "supernova"
	supernova.name = "Supernova Furnace"
	supernova.price = 1000
	supernova.description = "Blazing solar core with incandescent amber-orange heatwave grid lines."
	supernova.bg_gradient = [Color("#2e0c00"), Color("#140500"), Color("#080200")]
	supernova.grid_color = Color(255.0 / 255.0, 130.0 / 255.0, 0.0 / 255.0, 0.24)
	supernova.boundary_color = Color(255.0 / 255.0, 140.0 / 255.0, 0.0 / 255.0, 0.55)
	supernova.dust_color = Color("#ffaa00")
	out.append(supernova)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:394-403
	var blueprint: ArenaThemeConfig = ArenaThemeConfig.new()
	blueprint.id = "blueprint"
	blueprint.name = "Architectural Blueprint"
	blueprint.price = 1200
	blueprint.description = (
		"Classic CAD drafting technical navy with crisp white coordinate grid lines."
	)
	blueprint.bg_gradient = [Color("#0c2848"), Color("#061628"), Color("#020b16")]
	blueprint.grid_color = Color(255.0 / 255.0, 255.0 / 255.0, 255.0 / 255.0, 0.28)
	blueprint.boundary_color = Color(255.0 / 255.0, 255.0 / 255.0, 255.0 / 255.0, 0.65)
	blueprint.dust_color = Color("#ffffff")
	out.append(blueprint)

	return out


## PORT: web/src/tilt-to-live/ProgressionManager.ts:9-15
class BlackholePerks:
	extends RefCounted
	var duration: int = 0
	var radius: int = 0
	var gravity: int = 0
	var invulnerable_inside: bool = false
	var supernova_collapse: bool = false

	func to_dict() -> Dictionary:
		return {
			"duration": duration,
			"radius": radius,
			"gravity": gravity,
			"invulnerableInside": invulnerable_inside,
			"supernovaCollapse": supernova_collapse,
		}

	func from_dict(d: Dictionary) -> void:
		duration = SaveStore.read_int(d, "duration", duration)
		radius = SaveStore.read_int(d, "radius", radius)
		gravity = SaveStore.read_int(d, "gravity", gravity)
		invulnerable_inside = SaveStore.read_bool(d, "invulnerableInside", invulnerable_inside)
		supernova_collapse = SaveStore.read_bool(d, "supernovaCollapse", supernova_collapse)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:16-20
class NukePerks:
	extends RefCounted
	var radius: int = 0
	var speed: int = 0
	var fallout_zone: bool = false

	func to_dict() -> Dictionary:
		return {"radius": radius, "speed": speed, "falloutZone": fallout_zone}

	func from_dict(d: Dictionary) -> void:
		radius = SaveStore.read_int(d, "radius", radius)
		speed = SaveStore.read_int(d, "speed", speed)
		fallout_zone = SaveStore.read_bool(d, "falloutZone", fallout_zone)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:21-25
class ShieldPerks:
	extends RefCounted
	var duration: int = 0
	var radius: int = 0
	var battering_ram: bool = false

	func to_dict() -> Dictionary:
		return {"duration": duration, "radius": radius, "batteringRam": battering_ram}

	func from_dict(d: Dictionary) -> void:
		duration = SaveStore.read_int(d, "duration", duration)
		radius = SaveStore.read_int(d, "radius", radius)
		battering_ram = SaveStore.read_bool(d, "batteringRam", battering_ram)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:26-30
class MissilesPerks:
	extends RefCounted
	var count: int = 0
	var blast_radius: int = 0
	var flight_speed: int = 0

	func to_dict() -> Dictionary:
		return {"count": count, "blastRadius": blast_radius, "flightSpeed": flight_speed}

	func from_dict(d: Dictionary) -> void:
		count = SaveStore.read_int(d, "count", count)
		blast_radius = SaveStore.read_int(d, "blastRadius", blast_radius)
		flight_speed = SaveStore.read_int(d, "flightSpeed", flight_speed)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:31-35
class LaserPerks:
	extends RefCounted
	var length: int = 0
	var duration: int = 0
	var cross_beam: bool = false

	func to_dict() -> Dictionary:
		return {"length": length, "duration": duration, "crossBeam": cross_beam}

	func from_dict(d: Dictionary) -> void:
		length = SaveStore.read_int(d, "length", length)
		duration = SaveStore.read_int(d, "duration", duration)
		cross_beam = SaveStore.read_bool(d, "crossBeam", cross_beam)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:36-39
class LightningPerks:
	extends RefCounted
	var max_targets: int = 0
	var chain_range: int = 0

	func to_dict() -> Dictionary:
		return {"maxTargets": max_targets, "chainRange": chain_range}

	func from_dict(d: Dictionary) -> void:
		max_targets = SaveStore.read_int(d, "maxTargets", max_targets)
		chain_range = SaveStore.read_int(d, "chainRange", chain_range)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:40-43
class FreezePerks:
	extends RefCounted
	var duration: int = 0
	var shatter_cascade: bool = false

	func to_dict() -> Dictionary:
		return {"duration": duration, "shatterCascade": shatter_cascade}

	func from_dict(d: Dictionary) -> void:
		duration = SaveStore.read_int(d, "duration", duration)
		shatter_cascade = SaveStore.read_bool(d, "shatterCascade", shatter_cascade)


## Per-weapon perk ranks and keystones. PORT: web/src/tilt-to-live/ProgressionManager.ts:8-44
class WeaponPerks:
	extends RefCounted
	var blackhole: BlackholePerks = BlackholePerks.new()
	var nuke: NukePerks = NukePerks.new()
	var shield: ShieldPerks = ShieldPerks.new()
	var missiles: MissilesPerks = MissilesPerks.new()
	var laser: LaserPerks = LaserPerks.new()
	var lightning: LightningPerks = LightningPerks.new()
	var freeze: FreezePerks = FreezePerks.new()

	## The TS object shape: {"blackhole": {...}, "nuke": {...}, ...}.
	func to_dict() -> Dictionary:
		return {
			"blackhole": blackhole.to_dict(),
			"nuke": nuke.to_dict(),
			"shield": shield.to_dict(),
			"missiles": missiles.to_dict(),
			"laser": laser.to_dict(),
			"lightning": lightning.to_dict(),
			"freeze": freeze.to_dict(),
		}

	## The per-weapon deep merge of ProgressionManager.ts:493-503.
	func from_dict(d: Dictionary) -> void:
		blackhole.from_dict(SaveStore.read_dict(d, "blackhole"))
		nuke.from_dict(SaveStore.read_dict(d, "nuke"))
		shield.from_dict(SaveStore.read_dict(d, "shield"))
		missiles.from_dict(SaveStore.read_dict(d, "missiles"))
		laser.from_dict(SaveStore.read_dict(d, "laser"))
		lightning.from_dict(SaveStore.read_dict(d, "lightning"))
		freeze.from_dict(SaveStore.read_dict(d, "freeze"))


## PORT: web/src/tilt-to-live/ProgressionManager.ts:46-69
class ShipSkinConfig:
	extends RefCounted
	var id: String = ""
	var name: String = ""
	var trait: String = ""
	var price: int = 0
	var description: String = ""
	var hitbox: String = ""
	var turn: String = ""
	var hitbox_scale: float = 1.0
	var turn_rate: float = 1.0
	# PORT-NOTE: optional in the TS (:56-58) only so fallback literals in other
	# files stay valid; every catalog entry sets it (:138-264), so the
	# `!startingWeapon` guard at TiltGame.ts:1966 is dead and the default here
	# is never read.
	var starting_weapon: Types.WeaponType = Types.WeaponType.NUKE
	# PORT-NOTE: `bonusLives?: number` read as `|| 0` (:691); 0 is that reading.
	var bonus_lives: int = 0
	var tint: Color = Color.WHITE
	# PORT-NOTE: an SVG path string the web menu renders; kept as data so the
	# catalog is a complete port, consumed by nothing in Godot.
	var svg_path: String = ""
	var hull_color: Color = Color.WHITE
	var primary_color: Color = Color.WHITE
	var accent_color: Color = Color.WHITE
	var thruster_color: Color = Color.WHITE
	var trail_color: Color = Color.WHITE
	var tether_color: Color = Color.WHITE
	var shape: ShipShape = ShipShape.CLASSIC


## PORT: web/src/tilt-to-live/ProgressionManager.ts:73-82
class EnemySkinConfig:
	extends RefCounted
	var id: String = ""
	var name: String = ""
	var price: int = 0
	var description: String = ""
	var glow_color: Color = Color.WHITE
	## [inner, mid, outer]. PORT: web/src/tilt-to-live/ProgressionManager.ts:79
	var body_gradient: Array[Color] = []
	var pupil_color: Color = Color.WHITE
	var border_color: Color = Color.WHITE


## PORT: web/src/tilt-to-live/ProgressionManager.ts:84-93
class ArenaThemeConfig:
	extends RefCounted
	var id: String = ""
	var name: String = ""
	var price: int = 0
	var description: String = ""
	var bg_gradient: Array[Color] = []
	var grid_color: Color = Color.WHITE
	var boundary_color: Color = Color.WHITE
	var dust_color: Color = Color.WHITE


## PORT: web/src/tilt-to-live/ProgressionManager.ts:95-98
class SteeringTuning:
	extends RefCounted
	## 0.5 .. 2.0 (default 1.0). PORT: web/src/tilt-to-live/ProgressionManager.ts:96
	var sensitivity: float = 1.0
	## 0 .. 16 (default 4). PORT: web/src/tilt-to-live/ProgressionManager.ts:97
	# PORT-NOTE: a float, not an int — setDeadzone (:797) clamps whatever the
	# slider gives and PlayerShip.ts:166 compares it with a float distance.
	var deadzone: float = 4.0

	func to_dict() -> Dictionary:
		return {"sensitivity": sensitivity, "deadzone": deadzone}

	func from_dict(d: Dictionary) -> void:
		sensitivity = SaveStore.read_float(d, "sensitivity", sensitivity)
		deadzone = SaveStore.read_float(d, "deadzone", deadzone)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:100-117
class ProgressionData:
	extends RefCounted
	var points: int = 0
	var lifetime_points: int = 0
	var perks: WeaponPerks = WeaponPerks.new()
	var equipped_cursor_id: String = ""
	var unlocked_cursors: Array[String] = []
	var equipped_enemy_skin_id: String = ""
	var unlocked_enemy_skins: Array[String] = []
	var equipped_arena_theme_id: String = ""
	var unlocked_arena_themes: Array[String] = []
	var tuning: SteeringTuning = SteeringTuning.new()
	## 0..2, +1 starting life per rank (hard-capped at 3 total). PORT: :112
	var extra_lives: int = 0
	## 0..3, -6% player hitbox per rank. PORT: :113
	var hull_compact: int = 0
	## 0..3, -4% enemy speed per rank. PORT: :114
	var enemy_slow: int = 0
	## 0..4, +10% in-run score per rank. PORT: :115
	var score_multiplier: int = 0
	## 0..4, +10% earned points per rank. PORT: :116
	var points_multiplier: int = 0

	## JSON.stringify(this.data) (ProgressionManager.ts:519), TS key spellings.
	func to_dict() -> Dictionary:
		return {
			"points": points,
			"lifetimePoints": lifetime_points,
			"perks": perks.to_dict(),
			"equippedCursorId": equipped_cursor_id,
			"unlockedCursors": unlocked_cursors.duplicate(),
			"equippedEnemySkinId": equipped_enemy_skin_id,
			"unlockedEnemySkins": unlocked_enemy_skins.duplicate(),
			"equippedArenaThemeId": equipped_arena_theme_id,
			"unlockedArenaThemes": unlocked_arena_themes.duplicate(),
			"tuning": tuning.to_dict(),
			"extraLives": extra_lives,
			"hullCompact": hull_compact,
			"enemySlow": enemy_slow,
			"scoreMultiplier": score_multiplier,
			"pointsMultiplier": points_multiplier,
		}

	## The `{...def, ...parsed}` shallow merge of ProgressionManager.ts:488-490
	## for the scalar fields; perks and tuning merge one level deeper (:493-510).
	## The three unlocked lists and the two point floors are applied by the
	## caller (load_data), because the TS does them after the spread.
	func from_dict(d: Dictionary) -> void:
		points = SaveStore.read_int(d, "points", points)
		lifetime_points = SaveStore.read_int(d, "lifetimePoints", lifetime_points)
		perks.from_dict(SaveStore.read_dict(d, "perks"))
		equipped_cursor_id = SaveStore.read_string(d, "equippedCursorId", equipped_cursor_id)
		if d.has("unlockedCursors"):
			unlocked_cursors = SaveStore.read_string_array(d, "unlockedCursors")
		equipped_enemy_skin_id = SaveStore.read_string(d, "equippedEnemySkinId", equipped_enemy_skin_id)
		if d.has("unlockedEnemySkins"):
			unlocked_enemy_skins = SaveStore.read_string_array(d, "unlockedEnemySkins")
		equipped_arena_theme_id = SaveStore.read_string(d, "equippedArenaThemeId", equipped_arena_theme_id)
		if d.has("unlockedArenaThemes"):
			unlocked_arena_themes = SaveStore.read_string_array(d, "unlockedArenaThemes")
		tuning.from_dict(SaveStore.read_dict(d, "tuning"))
		extra_lives = SaveStore.read_int(d, "extraLives", extra_lives)
		hull_compact = SaveStore.read_int(d, "hullCompact", hull_compact)
		enemy_slow = SaveStore.read_int(d, "enemySlow", enemy_slow)
		score_multiplier = SaveStore.read_int(d, "scoreMultiplier", score_multiplier)
		points_multiplier = SaveStore.read_int(d, "pointsMultiplier", points_multiplier)
```

Two things to check as you write it: (1) `var data: ProgressionData = null` at the top refers to an inner class declared at the bottom — GDScript 4 resolves inner-class names file-wide, and `types.gd` relies on the same; if the parser rejects it, **stop and record it** (LAW 5) rather than move the classes back above the vars, because `gdlint`'s `class-definitions-order` then fails instead. (2) `gdformat` may re-wrap the long description literals; run it and accept its layout.

- [x] **Step 5: Run everything**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s src/meta/progression_manager.gd
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
git diff --stat
```

Expected: `--check-only` exits 0; `OK: 35/35 scripts collected, all tests passed.` — the four parity specs among them, **and every M4 weapon spec still green** (they construct `ProgressionManager.WeaponPerks.new()` and read the moved fields); format and lint clean. `gdlint` will not yet report `max-public-methods` (no public methods yet).

- [x] **Step 6: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/src/meta/progression_manager.gd tools/parity/dump_progression.mjs godot/tests/fixtures/progression.json godot/tests/test_progression_parity.gd godot/tests/test_progression_parity.gd.uid
git commit -m "M7: port progression records, catalogs and defaults with a parity fixture"
git log -1 --format=%B
```

---

### Task 4: `load_data` / `save` — the deep merge, the floors, and the corrupt fallback

**Files:**
- Modify: `godot/src/meta/progression_manager.gd` (`_init` calls `load_data()`; new `load_data`, `save`, `_unique_union` between `_get_default_data` and `_build_ship_catalog`)
- Test: `godot/tests/test_progression_manager.gd` (new)

**Interfaces:**
- Consumes: `SaveStore.load_dict`/`save_dict`/`read_*` (Task 1); `ProgressionData.from_dict`/`to_dict` (Task 3).
- Produces:
  - `ProgressionManager.load_data() -> ProgressionData` — defaults merged with the file (`ProgressionManager.ts:480-515`); a quarantined or absent file yields defaults.
  - `ProgressionManager.save() -> void` — `SaveStore.save_dict(SAVE_PATH, data.to_dict())` (`:517-523`).
  - `_unique_union(base: Array[String], extra: Array[String]) -> Array[String]` — the `Array.from(new Set([...base, ...extra]))` idiom (`:504-506`), order-preserving.

- [x] **Step 1: Write the failing spec**

Create `godot/tests/test_progression_manager.gd`:

```gdscript
## test_progression_manager.gd
## PORTS: nothing — new file, covers load/save in src/meta/progression_manager.gd
extends GutTest
## Proves the save round trip, the deep merge with defaults, the two points
## floors, list de-duplication, and the corrupt-file fallback (spec §6.4).


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _write_raw(text: String) -> void:
	var file: FileAccess = FileAccess.open(ProgressionManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_raw() -> String:
	var file: FileAccess = FileAccess.open(ProgressionManager.SAVE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	return text


func before_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))


func after_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH))


func test_no_file_gives_the_defaults_and_writes_nothing() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	assert_eq(pm.data.points, 7331, "ProgressionManager.ts:423")
	assert_eq(pm.data.lifetime_points, 7331)
	assert_eq(pm.data.perks.blackhole.duration, 3, ":427")
	assert_eq(pm.data.perks.missiles.count, 5, ":444")
	assert_eq(pm.data.unlocked_cursors, ["classic", "tactical", "singularity"])
	assert_eq(pm.data.equipped_arena_theme_id, "void")
	assert_almost_eq(pm.data.tuning.deadzone, 4.0, 0.0001)
	assert_false(FileAccess.file_exists(ProgressionManager.SAVE_PATH), "load never writes")


func test_save_then_fresh_instance_reads_the_same_data() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	pm.data.points = 9000
	pm.data.lifetime_points = 20000
	pm.data.perks.nuke.radius = 4
	pm.data.perks.laser.cross_beam = true
	pm.data.unlocked_cursors.append("solar")
	pm.data.equipped_cursor_id = "solar"
	pm.data.tuning.deadzone = 8.0
	pm.data.extra_lives = 2
	pm.save()

	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.points, 9000)
	assert_eq(again.data.lifetime_points, 20000)
	assert_eq(again.data.perks.nuke.radius, 4)
	assert_true(again.data.perks.laser.cross_beam)
	assert_eq(again.data.unlocked_cursors, ["classic", "tactical", "singularity", "solar"])
	assert_eq(again.data.equipped_cursor_id, "solar")
	assert_almost_eq(again.data.tuning.deadzone, 8.0, 0.0001)
	assert_eq(again.data.extra_lives, 2)


func test_file_on_disk_uses_the_typescript_key_spellings() -> void:
	ProgressionManager.new().save()
	var text: String = _read_raw()
	for key: String in [
		"lifetimePoints",
		"equippedCursorId",
		"unlockedEnemySkins",
		"equippedArenaThemeId",
		"invulnerableInside",
		"blastRadius",
		"maxTargets",
		"shatterCascade",
		"extraLives",
		"pointsMultiplier",
	]:
		assert_true(text.contains("\"%s\"" % key), "spec §4.6: key %s" % key)
	assert_false(text.contains("lifetime_points"), "no snake_case leaks into the file")


func test_partial_web_save_merges_over_defaults() -> void:
	_write_raw(
		"""{"points": 12000, "perks": {"laser": {"crossBeam": true}},
		"unlockedCursors": ["cyber"], "tuning": {"sensitivity": 1.5}}"""
	)
	var pm: ProgressionManager = ProgressionManager.new()
	assert_eq(pm.data.points, 12000)
	assert_eq(pm.data.lifetime_points, 7331, "absent -> max(0, 7331)")
	assert_true(pm.data.perks.laser.cross_beam, "present key wins")
	assert_eq(pm.data.perks.laser.length, 2, "absent sibling keeps the default (:500)")
	assert_eq(pm.data.perks.blackhole.gravity, 4, "absent weapon keeps the default (:496)")
	assert_eq(
		pm.data.unlocked_cursors,
		["classic", "tactical", "singularity", "cyber"],
		"the three free ships are always unlocked (:504)"
	)
	assert_almost_eq(pm.data.tuning.sensitivity, 1.5, 0.0001)
	assert_almost_eq(pm.data.tuning.deadzone, 4.0, 0.0001, "absent tuning key keeps default (:507)")


func test_points_floor_and_lifetime_floor() -> void:
	_write_raw("{\"points\": 100, \"lifetimePoints\": 10}")
	var low: ProgressionManager = ProgressionManager.new()
	assert_eq(low.data.points, 7331, "points < 500 resets to 7331 (:491)")
	assert_eq(low.data.lifetime_points, 7331, "max(10, 7331) (:492)")
	_remove(ProgressionManager.SAVE_PATH)

	_write_raw("{\"points\": 500, \"lifetimePoints\": 20000}")
	var ok: ProgressionManager = ProgressionManager.new()
	assert_eq(ok.data.points, 500, "exactly 500 is kept")
	assert_eq(ok.data.lifetime_points, 20000)
	_remove(ProgressionManager.SAVE_PATH)

	_write_raw("{\"points\": 0}")
	var zero: ProgressionManager = ProgressionManager.new()
	assert_eq(zero.data.points, 7331, "0 is falsy in the TS")


func test_unlocked_lists_are_deduplicated_in_order() -> void:
	_write_raw(
		"""{"unlockedEnemySkins": ["gold", "classic", "gold"],
		"unlockedArenaThemes": ["nebula", "void"], "unlockedCursors": ["classic", "solar", "solar"]}"""
	)
	var pm: ProgressionManager = ProgressionManager.new()
	assert_eq(pm.data.unlocked_enemy_skins, ["classic", "gold"], "Set keeps first occurrence (:505)")
	assert_eq(pm.data.unlocked_arena_themes, ["void", "nebula"], ":506")
	assert_eq(pm.data.unlocked_cursors, ["classic", "tactical", "singularity", "solar"])


func test_wrong_types_keep_the_defaults() -> void:
	_write_raw("{\"points\": \"lots\", \"tuning\": {\"deadzone\": \"x\"}, \"perks\": 5}")
	var pm: ProgressionManager = ProgressionManager.new()
	assert_eq(pm.data.points, 7331, "'lots' >= 500 is false in the TS too")
	assert_almost_eq(pm.data.tuning.deadzone, 4.0, 0.0001)
	assert_eq(pm.data.perks.blackhole.duration, 3, "a non-object perks block is ignored")


func test_corrupt_file_falls_back_to_defaults_and_is_backed_up() -> void:
	_write_raw("{\"points\": 999999, oops")
	var pm: ProgressionManager = ProgressionManager.new()
	assert_eq(pm.data.points, 7331, "spec §6.4: defaults, never a crash")
	var backup: String = SaveStore.corrupt_path_for(ProgressionManager.SAVE_PATH)
	assert_true(FileAccess.file_exists(backup), "the bad file is kept")
	assert_false(FileAccess.file_exists(ProgressionManager.SAVE_PATH), "and moved out of the way")
	pm.save()
	assert_true(FileAccess.file_exists(ProgressionManager.SAVE_PATH), "the next save is clean")
	assert_true(FileAccess.file_exists(backup), "and does not touch the backup")
```

- [x] **Step 2: Run the spec to verify it fails**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_progression_manager.gd
```

Expected: exit 1 — `save` is not a member of `ProgressionManager`.

- [x] **Step 3: Implement `load_data`, `save`, `_unique_union`**

In `progression_manager.gd`, change the last line of `_init()` to `data = load_data()` and add, directly after `_get_default_data()`:

```gdscript
## PORT: web/src/tilt-to-live/ProgressionManager.ts:480-515
# PORT-NOTE: the try/catch (:512-514) is SaveStore's quarantine: a file that
# does not parse is moved aside and load_dict returns {}, which is the `!raw`
# branch (:483). A key of the wrong type keeps the default where the TS spread
# would carry the junk value through — the typed records cannot hold it.
func load_data() -> ProgressionData:
	var raw: Dictionary = SaveStore.load_dict(SAVE_PATH)
	var def: ProgressionData = _get_default_data()
	if raw.is_empty():
		return def

	# {...def, ...parsed} plus the perks and tuning deep merges (:488-490, :493-510)
	def.from_dict(raw)
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:491
	var parsed_points: int = SaveStore.read_int(raw, "points", 0)
	def.points = parsed_points if parsed_points >= 500 else 7331
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:492
	def.lifetime_points = maxi(SaveStore.read_int(raw, "lifetimePoints", 0), 7331)
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:504-506
	def.unlocked_cursors = _unique_union(
		["classic", "tactical", "singularity"], SaveStore.read_string_array(raw, "unlockedCursors")
	)
	def.unlocked_enemy_skins = _unique_union(
		["classic"], SaveStore.read_string_array(raw, "unlockedEnemySkins")
	)
	def.unlocked_arena_themes = _unique_union(
		["void"], SaveStore.read_string_array(raw, "unlockedArenaThemes")
	)
	return def


## PORT: web/src/tilt-to-live/ProgressionManager.ts:517-523
# PORT-NOTE: the console.warn on failure (:521) is SaveStore's Log.warn.
func save() -> void:
	SaveStore.save_dict(SAVE_PATH, data.to_dict())


# `Array.from(new Set([...base, ...extra]))` (ProgressionManager.ts:504-506):
# every element once, in first-seen order.
func _unique_union(base: Array[String], extra: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for item: String in base:
		if not out.has(item):
			out.append(item)
	for item: String in extra:
		if not out.has(item):
			out.append(item)
	return out
```

- [x] **Step 4: Run everything**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
```

Expected: `OK: 36/36 scripts collected, all tests passed.`; format and lint clean.

- [x] **Step 5: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/src/meta/progression_manager.gd godot/tests/test_progression_manager.gd godot/tests/test_progression_manager.gd.uid
git commit -m "M7: load and save progression with the TS merge, floors and fallback"
git log -1 --format=%B
```

---

### Task 5: Economy — points, the perk cost curve, `upgrade_perk`, the five purchasables, lives and multipliers

**Files:**
- Modify: `godot/src/meta/progression_manager.gd` (line 1 gains the `gdlint` suppression; new public methods after `save()`, in TS order; the five `*_COSTS` constants join the constants block)
- Test: `godot/tests/test_progression_economy.gd` (new); `godot/tests/test_progression_parity.gd` (append)

**Interfaces:**
- Consumes: `Tuning.KEYSTONE_COSTS: Dictionary[String, int]` (`tuning.gd:22`); `GameEvents.points_changed(total_points: int)` (`game_events.gd:31`); `WeaponPerks.to_dict`/`from_dict` (Task 3).
- Produces (TS order, `ProgressionManager.ts:537-709`):
  - `add_points(amount: int) -> void`
  - `add_points_credited(amount: int) -> int`
  - `get_perk_cost(current_rank: int, is_keystone: bool = false, keystone_key: String = "") -> int`
  - `get_weapon_invested_points(weapon: String) -> int`
  - `upgrade_perk(weapon: String, perk_name: String) -> bool` — `weapon` and `perk_name` are the TS spellings (`"blackhole"`, `"invulnerableInside"`), because they are also the keystone-cost keys.
  - `get_extra_lives_cost() -> int` (`Types.ABSENT` past the ladder), `buy_extra_life() -> bool`; likewise `get_hull_compact_cost`/`buy_hull_compact`, `get_enemy_slow_cost`/`buy_enemy_slow`, `get_score_multiplier_cost`/`buy_score_multiplier`, `get_points_multiplier_cost`/`buy_points_multiplier`.
  - `get_starting_lives() -> int`, `get_hitbox_multiplier() -> float`, `get_enemy_speed_multiplier() -> float`, `get_score_multiplier() -> float`, `get_points_multiplier() -> float`.
  - Constants `EXTRA_LIVES_COSTS`, `HULL_COMPACT_COSTS`, `ENEMY_SLOW_COSTS`, `SCORE_MULTIPLIER_COSTS`, `POINTS_MULTIPLIER_COSTS: Array[int]`.

`get_starting_lives` reads `get_equipped_ship()`, which is Task 6's. To keep each task green on its own, Task 5 implements `get_equipped_ship()` **now**, at its TS position (after `equip_ship`, which Task 6 fills in) — see Step 3.

- [x] **Step 1: Write the failing spec**

Create `godot/tests/test_progression_economy.gd`:

```gdscript
## test_progression_economy.gd
## PORTS: nothing — new file, covers the economy in src/meta/progression_manager.gd
extends GutTest
## Proves points crediting, the perk cost curve, every perk and purchasable
## buy path, starting lives and the four multipliers.

var _pm: ProgressionManager = null


func _remove_save() -> void:
	var absolute: String = ProjectSettings.globalize_path(ProgressionManager.SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove_save()
	_pm = ProgressionManager.new()


func after_each() -> void:
	_remove_save()


func test_add_points_credited_applies_the_points_multiplier_and_saves() -> void:
	watch_signals(GameEvents)
	assert_eq(_pm.add_points_credited(100), 100, "rank 0 multiplier is 1.0")
	assert_eq(_pm.data.points, 7431)
	assert_eq(_pm.data.lifetime_points, 7431, "lifetime is credited the same (:529-536)")
	assert_signal_emitted_with_parameters(GameEvents, "points_changed", [7431])
	assert_true(FileAccess.file_exists(ProgressionManager.SAVE_PATH), "addPointsCredited saves (:548)")

	_pm.data.points_multiplier = 3
	assert_eq(_pm.add_points_credited(33), 42, "floor(33 * 1.3) = 42 (:545)")
	assert_eq(_pm.data.points, 7473)


func test_add_points_ignores_zero_and_negative() -> void:
	watch_signals(GameEvents)
	assert_eq(_pm.add_points_credited(0), 0)
	assert_eq(_pm.add_points_credited(-50), 0)
	assert_eq(_pm.data.points, 7331)
	assert_signal_not_emitted(GameEvents, "points_changed")
	_pm.add_points(10)
	assert_eq(_pm.data.points, 7341, "addPoints is addPointsCredited without the return (:537-539)")


func test_perk_cost_curve() -> void:
	assert_eq(_pm.get_perk_cost(0), 300, "ProgressionManager.ts:558")
	assert_eq(_pm.get_perk_cost(1), 600)
	assert_eq(_pm.get_perk_cost(2), 1100)
	assert_eq(_pm.get_perk_cost(3), 1800)
	assert_eq(_pm.get_perk_cost(4), 2800)
	assert_eq(_pm.get_perk_cost(5), 2800, "clamped to the last entry (:559)")
	assert_eq(_pm.get_perk_cost(99), 2800)


func test_keystone_cost_reads_the_tuning_table() -> void:
	assert_eq(_pm.get_perk_cost(0, true, "crossBeam"), 3500, "WeaponTuning.ts:74")
	assert_eq(_pm.get_perk_cost(0, true, "supernovaCollapse"), 5000)
	assert_eq(_pm.get_perk_cost(0, true, "shatterCascade"), 2500)
	assert_eq(_pm.get_perk_cost(0, true, "nosuch"), 2500, "?? 2500 (:556)")
	assert_eq(_pm.get_perk_cost(0, true), 2500, "'' is not a key either")
	assert_eq(_pm.get_perk_cost(3, true, "crossBeam"), 3500, "rank is ignored for keystones")


func test_weapon_invested_points_at_defaults() -> void:
	assert_eq(_pm.get_weapon_invested_points("blackhole"), 6700, "2000 + 900 + 3800")
	assert_eq(_pm.get_weapon_invested_points("nuke"), 300)
	assert_eq(_pm.get_weapon_invested_points("shield"), 0)
	assert_eq(_pm.get_weapon_invested_points("missiles"), 6600, "300+600+1100+1800+2800")
	assert_eq(_pm.get_weapon_invested_points("laser"), 900)
	assert_eq(_pm.get_weapon_invested_points("nosuch"), 0, ":565")
	_pm.data.perks.laser.cross_beam = true
	assert_eq(_pm.get_weapon_invested_points("laser"), 4400, "900 + keystone 3500 (:573-574)")


func test_upgrade_perk_rank_charges_the_curve_and_increments() -> void:
	assert_eq(_pm.data.perks.nuke.speed, 0)
	assert_true(_pm.upgrade_perk("nuke", "speed"))
	assert_eq(_pm.data.perks.nuke.speed, 1)
	assert_eq(_pm.data.points, 7331 - 300)
	assert_true(_pm.upgrade_perk("nuke", "speed"))
	assert_eq(_pm.data.points, 7331 - 300 - 600)
	assert_eq(_pm.data.perks.nuke.speed, 2)
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.perks.nuke.speed, 2, "upgradePerk saves (:599)")


func test_upgrade_perk_refuses_max_rank_unknown_and_unaffordable() -> void:
	_pm.data.perks.missiles.count = 5
	assert_false(_pm.upgrade_perk("missiles", "count"), ">= 5 is max (:594)")
	assert_eq(_pm.data.points, 7331)
	assert_false(_pm.upgrade_perk("nosuch", "count"), ":582")
	assert_false(_pm.upgrade_perk("nuke", "nosuch"), ":582")
	_pm.data.points = 299
	assert_false(_pm.upgrade_perk("nuke", "speed"), "cannot afford 300 (:596)")
	assert_eq(_pm.data.perks.nuke.speed, 0)
	# PORT-NOTE: the TS caps ranks at 5 for every track even where the
	# WeaponPerks comment says 0..3 (:18, :23, :28, :33, :38) — preserved.
	_pm.data.points = 100000
	_pm.data.perks.nuke.speed = 4
	assert_true(_pm.upgrade_perk("nuke", "speed"), "rank 4 -> 5 is allowed for a 0..3 track")
	assert_eq(_pm.data.perks.nuke.speed, 5)


func test_upgrade_perk_keystone_charges_its_price_once() -> void:
	_pm.data.points = 10000
	assert_true(_pm.upgrade_perk("laser", "crossBeam"))
	assert_true(_pm.data.perks.laser.cross_beam)
	assert_eq(_pm.data.points, 10000 - 3500)
	assert_false(_pm.upgrade_perk("laser", "crossBeam"), "already unlocked (:586)")
	assert_eq(_pm.data.points, 6500)
	_pm.data.points = 2999
	assert_false(_pm.upgrade_perk("nuke", "falloutZone"), "3000 > 2999")
	assert_false(_pm.data.perks.nuke.fallout_zone)


func test_purchasable_ladders_and_absent_past_the_end() -> void:
	assert_eq(_pm.get_extra_lives_cost(), 4000, ":607")
	assert_eq(_pm.get_hull_compact_cost(), 1500, ":608")
	assert_eq(_pm.get_enemy_slow_cost(), 2000, ":609")
	assert_eq(_pm.get_score_multiplier_cost(), 1800, ":610")
	assert_eq(_pm.get_points_multiplier_cost(), 2500, ":611")
	_pm.data.extra_lives = 2
	assert_eq(_pm.get_extra_lives_cost(), Types.ABSENT, "null past the ladder (:615)")
	_pm.data.hull_compact = 3
	assert_eq(_pm.get_hull_compact_cost(), Types.ABSENT)
	_pm.data.score_multiplier = 3
	assert_eq(_pm.get_score_multiplier_cost(), 11000)
	_pm.data.score_multiplier = 4
	assert_eq(_pm.get_score_multiplier_cost(), Types.ABSENT)


func test_every_buy_method_charges_increments_and_saves() -> void:
	_pm.data.points = 50000
	assert_true(_pm.buy_extra_life())
	assert_eq(_pm.data.extra_lives, 1)
	assert_eq(_pm.data.points, 46000)
	assert_true(_pm.buy_hull_compact())
	assert_eq(_pm.data.hull_compact, 1)
	assert_eq(_pm.data.points, 44500)
	assert_true(_pm.buy_enemy_slow())
	assert_eq(_pm.data.enemy_slow, 1)
	assert_eq(_pm.data.points, 42500)
	assert_true(_pm.buy_score_multiplier())
	assert_eq(_pm.data.score_multiplier, 1)
	assert_eq(_pm.data.points, 40700)
	assert_true(_pm.buy_points_multiplier())
	assert_eq(_pm.data.points_multiplier, 1)
	assert_eq(_pm.data.points, 38200)
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.points, 38200, "each buy saves")
	assert_eq(again.data.points_multiplier, 1)


func test_buy_refuses_when_maxed_or_unaffordable() -> void:
	_pm.data.points = 3999
	assert_false(_pm.buy_extra_life(), "4000 > 3999 (:621)")
	assert_eq(_pm.data.extra_lives, 0)
	_pm.data.points = 100000
	_pm.data.extra_lives = 2
	assert_false(_pm.buy_extra_life(), "ladder exhausted")
	assert_eq(_pm.data.points, 100000)
	_pm.data.enemy_slow = 3
	assert_false(_pm.buy_enemy_slow())
	_pm.data.points_multiplier = 4
	assert_false(_pm.buy_points_multiplier())


func test_starting_lives_caps_at_three() -> void:
	assert_eq(_pm.get_starting_lives(), 1, "1 base (:692)")
	_pm.data.extra_lives = 1
	assert_eq(_pm.get_starting_lives(), 2)
	_pm.data.extra_lives = 2
	assert_eq(_pm.get_starting_lives(), 3)
	_pm.data.unlocked_cursors.append("revenant")
	_pm.data.equipped_cursor_id = "revenant"
	assert_eq(_pm.get_starting_lives(), 3, "1 + 2 + bonus 1 capped at 3")
	_pm.data.extra_lives = 0
	assert_eq(_pm.get_starting_lives(), 2, "the Revenant's bonusLives (:265, :691)")


func test_multipliers_per_rank() -> void:
	assert_almost_eq(_pm.get_hitbox_multiplier(), 1.0, 0.0001)
	assert_almost_eq(_pm.get_enemy_speed_multiplier(), 1.0, 0.0001)
	assert_almost_eq(_pm.get_score_multiplier(), 1.0, 0.0001)
	assert_almost_eq(_pm.get_points_multiplier(), 1.0, 0.0001)
	_pm.data.hull_compact = 3
	_pm.data.enemy_slow = 2
	_pm.data.score_multiplier = 4
	_pm.data.points_multiplier = 1
	assert_almost_eq(_pm.get_hitbox_multiplier(), 0.82, 0.0001, "1 - 0.06 * 3 (:696)")
	assert_almost_eq(_pm.get_enemy_speed_multiplier(), 0.92, 0.0001, "1 - 0.04 * 2 (:700)")
	assert_almost_eq(_pm.get_score_multiplier(), 1.4, 0.0001, "1 + 0.10 * 4 (:704)")
	assert_almost_eq(_pm.get_points_multiplier(), 1.1, 0.0001, "1 + 0.10 * 1 (:708)")
```

Append to `godot/tests/test_progression_parity.gd`:

```gdscript
func test_perk_cost_curve_matches_the_typescript() -> void:
	var curve: Array = _fixture["perk_cost_curve"]
	for entry: Dictionary in curve:
		var rank: int = SaveStore.read_int(entry, "rank", -1)
		assert_eq(_pm.get_perk_cost(rank), SaveStore.read_int(entry, "cost", -1), "rank %d" % rank)


func test_keystone_costs_through_get_perk_cost_match_the_typescript() -> void:
	var costs: Array = _fixture["keystone_costs"]
	for entry: Dictionary in costs:
		var key: String = SaveStore.read_string(entry, "key", "")
		assert_eq(
			_pm.get_perk_cost(0, true, key), SaveStore.read_int(entry, "cost", -1), "keystone %s" % key
		)


func test_purchasable_ladders_match_the_typescript() -> void:
	var ladders: Dictionary = _fixture["purchasable_ladders"]
	var extra: Array = ladders["extraLives"]
	var hull: Array = ladders["hullCompact"]
	var slow: Array = ladders["enemySlow"]
	var score: Array = ladders["scoreMultiplier"]
	var points: Array = ladders["pointsMultiplier"]
	for rank: int in range(6):
		_pm.data.extra_lives = rank
		_pm.data.hull_compact = rank
		_pm.data.enemy_slow = rank
		_pm.data.score_multiplier = rank
		_pm.data.points_multiplier = rank
		assert_eq(_pm.get_extra_lives_cost(), _ladder_cost(extra[rank]), "extraLives %d" % rank)
		assert_eq(_pm.get_hull_compact_cost(), _ladder_cost(hull[rank]), "hullCompact %d" % rank)
		assert_eq(_pm.get_enemy_slow_cost(), _ladder_cost(slow[rank]), "enemySlow %d" % rank)
		assert_eq(
			_pm.get_score_multiplier_cost(), _ladder_cost(score[rank]), "scoreMultiplier %d" % rank
		)
		assert_eq(
			_pm.get_points_multiplier_cost(), _ladder_cost(points[rank]), "pointsMultiplier %d" % rank
		)


# A JSON null (past the ladder) is the port's Types.ABSENT.
func _ladder_cost(value: Variant) -> int:
	if value is float:
		return int(value)
	return Types.ABSENT


func test_invested_points_and_multipliers_at_defaults_match_the_typescript() -> void:
	var invested: Dictionary = _fixture["invested_points_at_defaults"]
	for weapon: String in invested.keys():
		assert_eq(
			_pm.get_weapon_invested_points(weapon),
			SaveStore.read_int(invested, weapon, -1),
			"invested %s" % weapon
		)
	var m: Dictionary = _fixture["multipliers_at_defaults"]
	assert_eq(_pm.get_starting_lives(), SaveStore.read_int(m, "startingLives", -1))
	assert_almost_eq(_pm.get_hitbox_multiplier(), SaveStore.read_float(m, "hitbox", -1.0), 0.0001)
	assert_almost_eq(
		_pm.get_enemy_speed_multiplier(), SaveStore.read_float(m, "enemySpeed", -1.0), 0.0001
	)
	assert_almost_eq(_pm.get_score_multiplier(), SaveStore.read_float(m, "score", -1.0), 0.0001)
	assert_almost_eq(_pm.get_points_multiplier(), SaveStore.read_float(m, "points", -1.0), 0.0001)
```

- [x] **Step 2: Run the specs to verify they fail**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_progression_economy.gd
```

Expected: exit 1 — `add_points_credited` is not a member of `ProgressionManager`.

- [x] **Step 3: Implement the economy**

Add as **line 1** of `progression_manager.gd` (above the `## progression_manager.gd` header line), following `enemy_swarm.gd:1-2`:

```gdscript
# gdlint:disable=max-public-methods
# PORT-NOTE: ProgressionManager.ts exposes 36 public methods; LAW 3 keeps them.
```

Add the five ladders to the constants block, after `SAVE_PATH`:

```gdscript
## PORT: web/src/tilt-to-live/ProgressionManager.ts:607-611
const EXTRA_LIVES_COSTS: Array[int] = [4000, 9000]
const HULL_COMPACT_COSTS: Array[int] = [1500, 3000, 5500]
const ENEMY_SLOW_COSTS: Array[int] = [2000, 4200, 7500]
const SCORE_MULTIPLIER_COSTS: Array[int] = [1800, 3600, 6500, 11000]
const POINTS_MULTIPLIER_COSTS: Array[int] = [2500, 5000, 9000, 15000]
```

(They are `private static readonly` in the TS; a GDScript `const` is already immutable and class-scoped. The `_` prefix is not used because `gdlint` flags a private constant that is read only through the class name; CONVENTIONS §3 lists constants as `CONSTANT_CASE` without a private form.)

Add after `save()`, in this order:

```gdscript
## Points earned during a run pass through here before landing in the
## player's spendable/lifetime totals, so the points-purchases multiplier
## is applied once, at this single chokepoint.
## PORT: web/src/tilt-to-live/ProgressionManager.ts:525-539
func add_points(amount: int) -> void:
	add_points_credited(amount)


## Banks `amount` (applying the points multiplier) and returns what was
## actually credited, so callers can report real earnings rather than the
## pre-multiplier figure. PORT: web/src/tilt-to-live/ProgressionManager.ts:541-550
# PORT-NOTE: lifetimePoints IS multiplied the same as points (:529-536) —
# it is a running total of everything ever credited, not a raw ledger.
# PORT-NOTE: TiltGame.ts:205-208 re-renders the goals HUD (the points balance
# in the DOM) after every addPoints; spec §5.3 makes that reach the
# points_changed signal, emitted here where the balance changes.
func add_points_credited(amount: int) -> int:
	if amount <= 0:
		return 0
	var credited: int = floori(float(amount) * get_points_multiplier())
	data.points += credited
	data.lifetime_points += credited
	save()
	GameEvents.points_changed.emit(data.points)
	return credited


## PORT: web/src/tilt-to-live/ProgressionManager.ts:554-560
func get_perk_cost(current_rank: int, is_keystone: bool = false, keystone_key: String = "") -> int:
	if is_keystone:
		return Tuning.KEYSTONE_COSTS.get(keystone_key, 2500)  # PORT: :556
	var costs: Array[int] = [300, 600, 1100, 1800, 2800]  # PORT: :558
	return costs[mini(current_rank, costs.size() - 1)]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:562-578
# PORT-NOTE: `(this.data.perks as any)[weapon]` and `Object.keys(p)` (:564,
# :567) are the perks record's dictionary view — WeaponPerks.to_dict() — with
# the TS key spellings, so a keystone key here is also its KEYSTONE_COSTS key.
func get_weapon_invested_points(weapon: String) -> int:
	var total: int = 0
	var p: Dictionary = SaveStore.read_dict(data.perks.to_dict(), weapon)
	if p.is_empty():
		return 0
	var costs: Array[int] = [300, 600, 1100, 1800, 2800]  # PORT: :566
	for key: String in p.keys():
		var val: Variant = p[key]
		if val is int:
			var rank: int = val
			for r: int in range(rank):
				total += costs[r] if r < costs.size() else 2800  # PORT: :571
		elif val is bool and val:
			total += get_perk_cost(0, true, key)
	return total


## PORT: web/src/tilt-to-live/ProgressionManager.ts:580-603
# PORT-NOTE: same dictionary view as get_weapon_invested_points; the edited
# view is written back through WeaponPerks.from_dict, which is a merge, so
# only the one key changes.
func upgrade_perk(weapon: String, perk_name: String) -> bool:
	var all: Dictionary = data.perks.to_dict()
	if not all.has(weapon):
		return false
	var weapon_perks: Dictionary = all[weapon]
	if not weapon_perks.has(perk_name):
		return false

	var val: Variant = weapon_perks[perk_name]
	if val is bool:
		if val:
			return false  # Already unlocked
		var cost: int = get_perk_cost(0, true, perk_name)
		if data.points < cost:
			return false
		data.points -= cost
		weapon_perks[perk_name] = true
		data.perks.from_dict(all)
		save()
		return true
	elif val is int:
		var rank: int = val
		if rank >= 5:
			return false  # Max rank reached  # PORT: :594
		var cost: int = get_perk_cost(rank, false)
		if data.points < cost:
			return false
		data.points -= cost
		weapon_perks[perk_name] = rank + 1
		data.perks.from_dict(all)
		save()
		return true
	return false


## PORT: web/src/tilt-to-live/ProgressionManager.ts:613-617
# PORT-NOTE: `number | null` — Types.ABSENT stands for null (types.gd:12-27).
func get_extra_lives_cost() -> int:
	var rank: int = data.extra_lives
	if rank >= EXTRA_LIVES_COSTS.size():
		return Types.ABSENT
	return EXTRA_LIVES_COSTS[rank]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:619-626
func buy_extra_life() -> bool:
	var cost: int = get_extra_lives_cost()
	if cost == Types.ABSENT or data.points < cost:
		return false
	data.points -= cost
	data.extra_lives += 1
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:628-632
func get_hull_compact_cost() -> int:
	var rank: int = data.hull_compact
	if rank >= HULL_COMPACT_COSTS.size():
		return Types.ABSENT
	return HULL_COMPACT_COSTS[rank]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:634-641
func buy_hull_compact() -> bool:
	var cost: int = get_hull_compact_cost()
	if cost == Types.ABSENT or data.points < cost:
		return false
	data.points -= cost
	data.hull_compact += 1
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:643-647
func get_enemy_slow_cost() -> int:
	var rank: int = data.enemy_slow
	if rank >= ENEMY_SLOW_COSTS.size():
		return Types.ABSENT
	return ENEMY_SLOW_COSTS[rank]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:649-656
func buy_enemy_slow() -> bool:
	var cost: int = get_enemy_slow_cost()
	if cost == Types.ABSENT or data.points < cost:
		return false
	data.points -= cost
	data.enemy_slow += 1
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:658-662
func get_score_multiplier_cost() -> int:
	var rank: int = data.score_multiplier
	if rank >= SCORE_MULTIPLIER_COSTS.size():
		return Types.ABSENT
	return SCORE_MULTIPLIER_COSTS[rank]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:664-671
func buy_score_multiplier() -> bool:
	var cost: int = get_score_multiplier_cost()
	if cost == Types.ABSENT or data.points < cost:
		return false
	data.points -= cost
	data.score_multiplier += 1
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:673-677
func get_points_multiplier_cost() -> int:
	var rank: int = data.points_multiplier
	if rank >= POINTS_MULTIPLIER_COSTS.size():
		return Types.ABSENT
	return POINTS_MULTIPLIER_COSTS[rank]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:679-686
func buy_points_multiplier() -> bool:
	var cost: int = get_points_multiplier_cost()
	if cost == Types.ABSENT or data.points < cost:
		return false
	data.points -= cost
	data.points_multiplier += 1
	save()
	return true


## Starting lives = 1 base + extraLives rank + the equipped ship's bonusLives,
## hard-capped at 3 total. PORT: web/src/tilt-to-live/ProgressionManager.ts:688-693
func get_starting_lives() -> int:
	var bonus: int = get_equipped_ship().bonus_lives
	return mini(3, 1 + data.extra_lives + bonus)  # PORT: :692


## PORT: web/src/tilt-to-live/ProgressionManager.ts:695-697
func get_hitbox_multiplier() -> float:
	return 1.0 - 0.06 * float(data.hull_compact)  # PORT: :696


## PORT: web/src/tilt-to-live/ProgressionManager.ts:699-701
func get_enemy_speed_multiplier() -> float:
	return 1.0 - 0.04 * float(data.enemy_slow)  # PORT: :700


## PORT: web/src/tilt-to-live/ProgressionManager.ts:703-705
func get_score_multiplier() -> float:
	return 1.0 + 0.10 * float(data.score_multiplier)  # PORT: :704


## PORT: web/src/tilt-to-live/ProgressionManager.ts:707-709
func get_points_multiplier() -> float:
	return 1.0 + 0.10 * float(data.points_multiplier)  # PORT: :708


## PORT: web/src/tilt-to-live/ProgressionManager.ts:733-735
func get_equipped_ship() -> ShipSkinConfig:
	for ship: ShipSkinConfig in ship_catalog:
		if ship.id == data.equipped_cursor_id:
			return ship
	return ship_catalog[0]
```

`get_equipped_ship` is placed here temporarily; Task 6 inserts `buy_ship` and `equip_ship` above it (TS order `:713-735`) and nothing else about it changes. The `Tuning.KEYSTONE_COSTS.get(keystone_key, 2500)` line returns `Variant` from a typed Dictionary's `get` — if the Tier-1 warnings reject the implicit `int` return, write it as two lines: `if Tuning.KEYSTONE_COSTS.has(keystone_key): return Tuning.KEYSTONE_COSTS[keystone_key]` / `return 2500`, which is the same `??` semantics on a table whose values are all ints. In `upgrade_perk`, `var weapon_perks: Dictionary = all[weapon]` narrows a `Variant` — `to_dict()` only ever puts Dictionaries there; if the warnings object, guard it with `if not (all[weapon] is Dictionary): return false` first.

- [x] **Step 4: Run everything**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
```

Expected: `OK: 37/37 scripts collected, all tests passed.`; format clean; **`gdlint` prints nothing** — the line-1 `disable` covers `max-public-methods`. If `gdlint` reports `max-file-lines`, add `,max-file-lines` to the same `disable` line (the form is `# gdlint:disable=max-public-methods,max-file-lines`) and note it in the ledger.

- [x] **Step 5: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/src/meta/progression_manager.gd godot/tests/test_progression_economy.gd godot/tests/test_progression_economy.gd.uid godot/tests/test_progression_parity.gd
git commit -m "M7: port the points economy, perk purchases and multipliers"
git log -1 --format=%B
```

---

### Task 6: Ships, cursors, enemy skins, arena themes and steering tuning

**Files:**
- Modify: `godot/src/meta/progression_manager.gd` (new public methods around `get_equipped_ship`, TS order `:713-800`)
- Test: `godot/tests/test_progression_catalogs.gd` (new)

**Interfaces:**
- Consumes: `_resolve_ship_id` (Task 3), `save()` (Task 4), the three catalogs.
- Produces (TS order):
  - `buy_ship(id: String) -> bool`, `equip_ship(id: String) -> bool`, `get_equipped_ship() -> ShipSkinConfig` (already present)
  - `buy_cursor(id) -> bool`, `equip_cursor(id) -> bool`, `get_equipped_cursor() -> ShipSkinConfig` — aliases (`:737-740`)
  - `buy_enemy_skin(id) -> bool`, `equip_enemy_skin(id) -> bool`, `get_equipped_enemy_skin() -> EnemySkinConfig`
  - `buy_arena_theme(id) -> bool`, `equip_arena_theme(id) -> bool`, `get_equipped_arena_theme() -> ArenaThemeConfig`
  - `set_sensitivity(value: float) -> void`, `set_deadzone(value: float) -> void`

- [x] **Step 1: Write the failing spec**

Create `godot/tests/test_progression_catalogs.gd`:

```gdscript
## test_progression_catalogs.gd
## PORTS: nothing — new file, covers ships, skins, arenas and tuning in
## src/meta/progression_manager.gd
extends GutTest
## Proves buy/equip/get for the three catalogs, the legacy ship-id aliases,
## and the clamped steering tuning setters.

var _pm: ProgressionManager = null


func _remove_save() -> void:
	var absolute: String = ProjectSettings.globalize_path(ProgressionManager.SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove_save()
	_pm = ProgressionManager.new()


func after_each() -> void:
	_remove_save()


func test_equipped_ship_defaults_to_classic_and_falls_back_to_index_zero() -> void:
	assert_eq(_pm.get_equipped_ship().id, "classic")
	assert_eq(_pm.get_equipped_ship().starting_weapon, Types.WeaponType.SHIELD, ":138")
	_pm.data.equipped_cursor_id = "nosuch"
	assert_eq(_pm.get_equipped_ship().id, "classic", "|| this.shipCatalog[0] (:734)")
	assert_true(_pm.get_equipped_cursor() == _pm.get_equipped_ship(), "alias (:740)")


func test_buy_ship_charges_unlocks_equips_and_saves() -> void:
	assert_eq(_pm.data.points, 7331)
	assert_true(_pm.buy_ship("solar"))
	assert_eq(_pm.data.points, 7331 - 600, ":195")
	assert_true(_pm.data.unlocked_cursors.has("solar"))
	assert_eq(_pm.data.equipped_cursor_id, "solar", "buying equips (:720)")
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.equipped_cursor_id, "solar", "saved (:721)")
	assert_eq(again.get_equipped_ship().hitbox_scale, 1.90)


func test_buy_ship_already_owned_returns_true_without_charging() -> void:
	assert_true(_pm.buy_ship("tactical"), "free and pre-unlocked (:715)")
	assert_eq(_pm.data.points, 7331)
	assert_eq(_pm.data.equipped_cursor_id, "classic", "an owned ship is not re-equipped by buying")


func test_buy_ship_refuses_unknown_and_unaffordable() -> void:
	assert_false(_pm.buy_ship("nosuch"), ":717")
	_pm.data.points = 2499
	assert_false(_pm.buy_ship("revenant"), "2500 > 2499")
	assert_false(_pm.data.unlocked_cursors.has("revenant"))
	assert_eq(_pm.data.points, 2499)


func test_legacy_ship_ids_resolve() -> void:
	assert_true(_pm.equip_ship("Viper"), "'viper' -> 'tactical', case-insensitive (:410-419)")
	assert_eq(_pm.data.equipped_cursor_id, "tactical")
	assert_true(_pm.equip_ship("ARROW"))
	assert_eq(_pm.data.equipped_cursor_id, "classic")
	assert_true(_pm.equip_ship("phantom"))
	assert_eq(_pm.data.equipped_cursor_id, "singularity")
	_pm.data.points = 100000
	assert_true(_pm.buy_ship("aegis"))
	assert_eq(_pm.data.equipped_cursor_id, "solar")
	assert_true(_pm.buy_cursor("matrix"), "alias (:738)")
	assert_eq(_pm.data.equipped_cursor_id, "cyber")


func test_equip_ship_requires_ownership() -> void:
	assert_false(_pm.equip_ship("solar"), "not unlocked (:727)")
	assert_eq(_pm.data.equipped_cursor_id, "classic")
	assert_true(_pm.equip_cursor("singularity"), "alias (:739)")
	assert_eq(_pm.data.equipped_cursor_id, "singularity")
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.equipped_cursor_id, "singularity", "equip saves (:729)")


func test_enemy_skins_buy_equip_get() -> void:
	assert_eq(_pm.get_equipped_enemy_skin().id, "classic")
	assert_false(_pm.equip_enemy_skin("gold"), "not owned (:756)")
	assert_true(_pm.buy_enemy_skin("toxic"))
	assert_eq(_pm.data.points, 7331 - 400, ":294")
	assert_eq(_pm.data.equipped_enemy_skin_id, "toxic")
	assert_eq(_pm.get_equipped_enemy_skin().name, "Toxic Biohazard")
	assert_true(_pm.buy_enemy_skin("toxic"), "owned -> true, no charge (:745)")
	assert_eq(_pm.data.points, 6931)
	assert_false(_pm.buy_enemy_skin("nosuch"))
	assert_true(_pm.equip_enemy_skin("classic"))
	assert_eq(_pm.get_equipped_enemy_skin().id, "classic")
	_pm.data.equipped_enemy_skin_id = "nosuch"
	assert_eq(_pm.get_equipped_enemy_skin().id, "classic", "|| catalog[0] (:763)")
	_pm.data.points = 1499
	assert_false(_pm.buy_enemy_skin("gold"), "1500 > 1499")


func test_arena_themes_buy_equip_get() -> void:
	assert_eq(_pm.get_equipped_arena_theme().id, "void")
	assert_false(_pm.equip_arena_theme("matrix"), "not owned (:780)")
	assert_true(_pm.buy_arena_theme("synthwave"))
	assert_eq(_pm.data.points, 7331 - 400, ":357")
	assert_eq(_pm.data.equipped_arena_theme_id, "synthwave")
	assert_eq(_pm.get_equipped_arena_theme().name, "Synthwave Sunset")
	assert_true(_pm.buy_arena_theme("synthwave"), "owned -> true (:769)")
	assert_false(_pm.buy_arena_theme("nosuch"))
	assert_true(_pm.equip_arena_theme("void"))
	_pm.data.equipped_arena_theme_id = "nosuch"
	assert_eq(_pm.get_equipped_arena_theme().id, "void", "|| catalog[0] (:787)")
	var again: ProgressionManager = ProgressionManager.new()
	assert_true(again.data.unlocked_arena_themes.has("synthwave"), "saved (:775)")


func test_tuning_setters_clamp_and_save() -> void:
	_pm.set_sensitivity(5.0)
	assert_almost_eq(_pm.data.tuning.sensitivity, 2.0, 0.0001, "max 2.0 (:793)")
	_pm.set_sensitivity(0.1)
	assert_almost_eq(_pm.data.tuning.sensitivity, 0.5, 0.0001, "min 0.5")
	_pm.set_sensitivity(1.25)
	assert_almost_eq(_pm.data.tuning.sensitivity, 1.25, 0.0001)
	_pm.set_deadzone(40.0)
	assert_almost_eq(_pm.data.tuning.deadzone, 16.0, 0.0001, "max 16 (:798)")
	_pm.set_deadzone(-3.0)
	assert_almost_eq(_pm.data.tuning.deadzone, 0.0, 0.0001, "min 0")
	_pm.set_deadzone(6.5)
	var again: ProgressionManager = ProgressionManager.new()
	assert_almost_eq(again.data.tuning.sensitivity, 1.25, 0.0001, "saved (:794)")
	assert_almost_eq(again.data.tuning.deadzone, 6.5, 0.0001, "saved (:799)")
```

- [x] **Step 2: Run the spec to verify it fails**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_progression_catalogs.gd
```

Expected: exit 1 — `buy_ship` is not a member of `ProgressionManager`.

- [x] **Step 3: Implement**

In `progression_manager.gd`, insert **above** `get_equipped_ship()`:

```gdscript
## PORT: web/src/tilt-to-live/ProgressionManager.ts:713-723
func buy_ship(id: String) -> bool:
	var canonical: String = _resolve_ship_id(id)
	if data.unlocked_cursors.has(canonical):
		return true
	var item: ShipSkinConfig = _find_ship(canonical)
	if item == null or data.points < item.price:
		return false
	data.points -= item.price
	data.unlocked_cursors.append(canonical)
	data.equipped_cursor_id = canonical
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:725-731
func equip_ship(id: String) -> bool:
	var canonical: String = _resolve_ship_id(id)
	if not data.unlocked_cursors.has(canonical):
		return false
	data.equipped_cursor_id = canonical
	save()
	return true
```

and **below** `get_equipped_ship()`:

```gdscript
## Backwards compatibility alias. PORT: web/src/tilt-to-live/ProgressionManager.ts:738
func buy_cursor(id: String) -> bool:
	return buy_ship(id)


## Backwards compatibility alias. PORT: web/src/tilt-to-live/ProgressionManager.ts:739
func equip_cursor(id: String) -> bool:
	return equip_ship(id)


## Backwards compatibility alias. PORT: web/src/tilt-to-live/ProgressionManager.ts:740
func get_equipped_cursor() -> ShipSkinConfig:
	return get_equipped_ship()


## PORT: web/src/tilt-to-live/ProgressionManager.ts:744-753
func buy_enemy_skin(id: String) -> bool:
	if data.unlocked_enemy_skins.has(id):
		return true
	var item: EnemySkinConfig = _find_enemy_skin(id)
	if item == null or data.points < item.price:
		return false
	data.points -= item.price
	data.unlocked_enemy_skins.append(id)
	data.equipped_enemy_skin_id = id
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:755-760
func equip_enemy_skin(id: String) -> bool:
	if not data.unlocked_enemy_skins.has(id):
		return false
	data.equipped_enemy_skin_id = id
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:762-764
func get_equipped_enemy_skin() -> EnemySkinConfig:
	var found: EnemySkinConfig = _find_enemy_skin(data.equipped_enemy_skin_id)
	return found if found != null else enemy_skin_catalog[0]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:768-777
func buy_arena_theme(id: String) -> bool:
	if data.unlocked_arena_themes.has(id):
		return true
	var item: ArenaThemeConfig = _find_arena_theme(id)
	if item == null or data.points < item.price:
		return false
	data.points -= item.price
	data.unlocked_arena_themes.append(id)
	data.equipped_arena_theme_id = id
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:779-784
func equip_arena_theme(id: String) -> bool:
	if not data.unlocked_arena_themes.has(id):
		return false
	data.equipped_arena_theme_id = id
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:786-788
func get_equipped_arena_theme() -> ArenaThemeConfig:
	var found: ArenaThemeConfig = _find_arena_theme(data.equipped_arena_theme_id)
	return found if found != null else arena_theme_catalog[0]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:792-795
func set_sensitivity(value: float) -> void:
	data.tuning.sensitivity = maxf(0.5, minf(2.0, value))  # PORT: :793
	save()


## PORT: web/src/tilt-to-live/ProgressionManager.ts:797-800
func set_deadzone(value: float) -> void:
	data.tuning.deadzone = maxf(0.0, minf(16.0, value))  # PORT: :798
	save()
```

and rewrite `get_equipped_ship()` to use the finder, then add the three finders to the **private** block (after `_unique_union`, before `_build_ship_catalog`):

```gdscript
## PORT: web/src/tilt-to-live/ProgressionManager.ts:733-735
func get_equipped_ship() -> ShipSkinConfig:
	var found: ShipSkinConfig = _find_ship(data.equipped_cursor_id)
	return found if found != null else ship_catalog[0]
```

```gdscript
# The `catalog.find(c => c.id === id)` idiom (:716, :734, :746, :763, :770,
# :787): the first entry with that id, or null.
func _find_ship(id: String) -> ShipSkinConfig:
	for ship: ShipSkinConfig in ship_catalog:
		if ship.id == id:
			return ship
	return null


func _find_enemy_skin(id: String) -> EnemySkinConfig:
	for skin: EnemySkinConfig in enemy_skin_catalog:
		if skin.id == id:
			return skin
	return null


func _find_arena_theme(id: String) -> ArenaThemeConfig:
	for arena: ArenaThemeConfig in arena_theme_catalog:
		if arena.id == id:
			return arena
	return null
```

- [x] **Step 4: Run everything, then confirm the member table against the TS**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
grep -n "^func \|^  func \|^static func " godot/src/meta/progression_manager.gd | grep -v "^\s*#" | wc -l
grep -n "^  public \|^  private " web/src/tilt-to-live/ProgressionManager.ts | wc -l
```

Expected: `OK: 38/38 scripts collected, all tests passed.`; format and lint clean. The two counts differ by a known amount: the GDScript has `_init`, `_unique_union`, three `_find_*`, three `_build_*` catalog builders and the inner-class `to_dict`/`from_dict` pairs that the TS does not, and lacks `getCursorSvgDataUri`/`getShipSvgPreview`; write both numbers and the reconciliation in the ledger. Walk `ProgressionManager.ts:406-800` once against the file and confirm every public member is present in TS order — that is the LAW 3 check the M4 final review did.

- [x] **Step 5: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/src/meta/progression_manager.gd godot/tests/test_progression_catalogs.gd godot/tests/test_progression_catalogs.gd.uid
git commit -m "M7: port ship, enemy skin and arena purchases and steering tuning"
git log -1 --format=%B
```

---

### Task 7: `GameOptionsManager` — modes, settings, the settings save

**Files:**
- Create: `godot/src/meta/game_options.gd`
- Test: `godot/tests/test_game_options.gd` (new); `godot/tests/test_progression_parity.gd` (append)

**Interfaces:**
- Consumes: `Types.GameMode`, `Types.ControlScheme`; `SaveStore` (Task 1).
- Produces:
  - `class_name GameOptionsManager` (the TS class name, `GameOptions.ts:34`; the file name follows spec §4.2).
  - `enum GameOptionsManager.ScreenShake { OFF, LOW, NORMAL, EXTREME, FULL }`
  - `const STORAGE_KEY = "tilt_to_live_settings_v1"`, `const SAVE_PATH = "user://tilt_to_live_settings_v1.json"`
  - `const MODE_IDS: Dictionary[Types.GameMode, String]`, `CONTROL_SCHEME_IDS: Dictionary[Types.ControlScheme, String]`, `SCREEN_SHAKE_IDS: Dictionary[ScreenShake, String]` — the TS string forms, used only by `to_dict`/`from_dict`.
  - Inner `ModeConfig` (`id: Types.GameMode`, `name`, `badge`, `tagline`, `description: String`, `color`, `accent`, `glow: Color`, `score_multiplier: float`); inner `GameSettings` (`mode`, `control_scheme`, `sfx_enabled`, `sfx_volume`, `music_enabled`, `music_volume`, `screen_shake`, `tether_line`, `high_contrast_halo`, `show_gridlines`) with `to_dict`/`from_dict`.
  - `var settings: GameSettings`, `var modes: Array[ModeConfig]`
  - `load_settings() -> GameSettings`, `save() -> void`, `get_mode_config(mode: Types.GameMode) -> ModeConfig`, `set_mode(mode: Types.GameMode) -> void`, `get_shake_multiplier() -> float`.

- [x] **Step 1: Write the failing spec**

Create `godot/tests/test_game_options.gd`:

```gdscript
## test_game_options.gd
## PORTS: nothing — new file, covers src/meta/game_options.gd
extends GutTest
## Proves the default settings, the mode catalog, the shake multiplier, the
## settings save round trip in the TS shape, and the corrupt fallback.


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _write_raw(text: String) -> void:
	var file: FileAccess = FileAccess.open(GameOptionsManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func before_each() -> void:
	_remove(GameOptionsManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GameOptionsManager.SAVE_PATH))


func after_each() -> void:
	_remove(GameOptionsManager.SAVE_PATH)
	_remove(SaveStore.corrupt_path_for(GameOptionsManager.SAVE_PATH))


func test_defaults() -> void:
	var o: GameOptionsManager = GameOptionsManager.new()
	assert_eq(o.settings.mode, Types.GameMode.CLASSIC, "GameOptions.ts:79")
	assert_eq(o.settings.control_scheme, Types.ControlScheme.HYBRID, ":80")
	assert_true(o.settings.sfx_enabled)
	assert_almost_eq(o.settings.sfx_volume, 0.8, 0.0001, ":82")
	assert_true(o.settings.music_enabled)
	assert_almost_eq(o.settings.music_volume, 0.7, 0.0001, ":84")
	assert_eq(o.settings.screen_shake, GameOptionsManager.ScreenShake.NORMAL, ":85")
	assert_true(o.settings.tether_line)
	assert_true(o.settings.high_contrast_halo)
	assert_false(o.settings.show_gridlines, ":88")


func test_mode_catalog_and_lookup() -> void:
	var o: GameOptionsManager = GameOptionsManager.new()
	assert_eq(o.modes.size(), 3)
	assert_eq(o.modes[0].id, Types.GameMode.CLASSIC, "catalog order is classic, gauntlet, code-red (:37-71)")
	assert_eq(o.modes[1].id, Types.GameMode.GAUNTLET)
	assert_eq(o.modes[2].id, Types.GameMode.CODE_RED)
	assert_eq(o.get_mode_config(Types.GameMode.CLASSIC).name, "Standard")
	assert_almost_eq(o.get_mode_config(Types.GameMode.GAUNTLET).score_multiplier, 1.25, 0.0001, ":58")
	assert_almost_eq(o.get_mode_config(Types.GameMode.CODE_RED).score_multiplier, 1.5, 0.0001, ":69")
	assert_eq(o.get_mode_config(Types.GameMode.CODE_RED).badge, "1.5×")
	assert_eq(o.get_mode_config(o.settings.mode).id, Types.GameMode.CLASSIC, "the TS default arg (:113)")


func test_set_mode_saves_and_survives_restart() -> void:
	var o: GameOptionsManager = GameOptionsManager.new()
	o.set_mode(Types.GameMode.CODE_RED)
	assert_eq(o.settings.mode, Types.GameMode.CODE_RED)
	assert_true(FileAccess.file_exists(GameOptionsManager.SAVE_PATH), "setMode saves (:119)")
	var again: GameOptionsManager = GameOptionsManager.new()
	assert_eq(again.settings.mode, Types.GameMode.CODE_RED)


func test_shake_multiplier() -> void:
	var o: GameOptionsManager = GameOptionsManager.new()
	o.settings.screen_shake = GameOptionsManager.ScreenShake.OFF
	assert_almost_eq(o.get_shake_multiplier(), 0.0, 0.0001, ":125")
	o.settings.screen_shake = GameOptionsManager.ScreenShake.LOW
	assert_almost_eq(o.get_shake_multiplier(), 0.5, 0.0001, ":127")
	o.settings.screen_shake = GameOptionsManager.ScreenShake.NORMAL
	assert_almost_eq(o.get_shake_multiplier(), 1.0, 0.0001, ":130")
	o.settings.screen_shake = GameOptionsManager.ScreenShake.FULL
	assert_almost_eq(o.get_shake_multiplier(), 1.0, 0.0001, "'full' shares 'normal' (:129)")
	o.settings.screen_shake = GameOptionsManager.ScreenShake.EXTREME
	assert_almost_eq(o.get_shake_multiplier(), 1.8, 0.0001, ":132")


func test_file_uses_the_typescript_strings_and_keys() -> void:
	var o: GameOptionsManager = GameOptionsManager.new()
	o.settings.mode = Types.GameMode.CODE_RED
	o.settings.control_scheme = Types.ControlScheme.GYRO
	o.settings.screen_shake = GameOptionsManager.ScreenShake.EXTREME
	o.settings.show_gridlines = true
	o.save()
	var file: FileAccess = FileAccess.open(GameOptionsManager.SAVE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	assert_true(text.contains("\"mode\":\"code-red\""), "GameMode strings (:5)")
	assert_true(text.contains("\"controlScheme\":\"gyro\""), ":21")
	assert_true(text.contains("\"screenShake\":\"extreme\""), ":26")
	assert_true(text.contains("\"showGridlines\":true"))
	assert_true(text.contains("\"musicVolume\""))
	var again: GameOptionsManager = GameOptionsManager.new()
	assert_eq(again.settings.mode, Types.GameMode.CODE_RED)
	assert_eq(again.settings.control_scheme, Types.ControlScheme.GYRO)
	assert_eq(again.settings.screen_shake, GameOptionsManager.ScreenShake.EXTREME)
	assert_true(again.settings.show_gridlines)


func test_web_shaped_partial_file_merges_over_defaults() -> void:
	_write_raw("{\"mode\": \"gauntlet\", \"sfxVolume\": 0.25, \"screenShake\": \"bogus\"}")
	var o: GameOptionsManager = GameOptionsManager.new()
	assert_eq(o.settings.mode, Types.GameMode.GAUNTLET)
	assert_almost_eq(o.settings.sfx_volume, 0.25, 0.0001)
	assert_almost_eq(o.settings.music_volume, 0.7, 0.0001, "absent keeps default (:98)")
	assert_eq(o.settings.screen_shake, GameOptionsManager.ScreenShake.NORMAL, "unknown string keeps default")
	assert_false(o.settings.show_gridlines, "=== true only (:100)")


func test_show_gridlines_is_true_only_for_a_json_true() -> void:
	_write_raw("{\"showGridlines\": 1}")
	assert_false(GameOptionsManager.new().settings.show_gridlines, ":100")
	_remove(GameOptionsManager.SAVE_PATH)
	_write_raw("{\"showGridlines\": true}")
	assert_true(GameOptionsManager.new().settings.show_gridlines)


func test_corrupt_settings_file_falls_back_and_is_backed_up() -> void:
	_write_raw("{\"mode\": ")
	var o: GameOptionsManager = GameOptionsManager.new()
	assert_eq(o.settings.mode, Types.GameMode.CLASSIC)
	assert_true(FileAccess.file_exists(SaveStore.corrupt_path_for(GameOptionsManager.SAVE_PATH)))
```

Add to `godot/tests/test_progression_parity.gd` — the three constants beside `SHAPE_NAMES` at the top of the file (`gdlint` orders constants before functions), the functions at the end:

```gdscript
const MODE_NAMES: Dictionary[String, Types.GameMode] = {
	"classic": Types.GameMode.CLASSIC,
	"code-red": Types.GameMode.CODE_RED,
	"gauntlet": Types.GameMode.GAUNTLET,
}
const SCHEME_NAMES: Dictionary[String, Types.ControlScheme] = {
	"hybrid": Types.ControlScheme.HYBRID,
	"mouse": Types.ControlScheme.MOUSE,
	"keyboard": Types.ControlScheme.KEYBOARD,
	"gyro": Types.ControlScheme.GYRO,
}
const SHAKE_NAMES: Dictionary[String, GameOptionsManager.ScreenShake] = {
	"off": GameOptionsManager.ScreenShake.OFF,
	"low": GameOptionsManager.ScreenShake.LOW,
	"normal": GameOptionsManager.ScreenShake.NORMAL,
	"extreme": GameOptionsManager.ScreenShake.EXTREME,
	"full": GameOptionsManager.ScreenShake.FULL,
}


func _remove_settings() -> void:
	var absolute: String = ProjectSettings.globalize_path(GameOptionsManager.SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func test_mode_configs_match_the_typescript() -> void:
	_remove_settings()
	var o: GameOptionsManager = GameOptionsManager.new()
	var expected: Array = _fixture["modes"]
	assert_eq(o.modes.size(), expected.size())
	for i: int in range(expected.size()):
		var want: Dictionary = expected[i]
		var mode: GameOptionsManager.ModeConfig = o.modes[i]
		var tag: String = "mode[%d]" % i
		assert_eq(mode.id, MODE_NAMES[SaveStore.read_string(want, "id", "")], tag)
		assert_eq(mode.name, SaveStore.read_string(want, "name", ""), tag)
		assert_eq(mode.badge, SaveStore.read_string(want, "badge", ""), tag)
		assert_eq(mode.tagline, SaveStore.read_string(want, "tagline", ""), tag)
		assert_eq(mode.description, SaveStore.read_string(want, "description", ""), tag)
		_assert_color(mode.color, SaveStore.read_string(want, "color", ""), tag + " color")
		_assert_color(mode.accent, SaveStore.read_string(want, "accent", ""), tag + " accent")
		_assert_color(mode.glow, SaveStore.read_string(want, "glow", ""), tag + " glow")
		assert_almost_eq(
			mode.score_multiplier, SaveStore.read_float(want, "scoreMultiplier", -1.0), 0.0001, tag
		)


func test_default_settings_match_the_typescript() -> void:
	_remove_settings()
	var o: GameOptionsManager = GameOptionsManager.new()
	var want: Dictionary = _fixture["default_settings"]
	assert_eq(o.settings.mode, MODE_NAMES[SaveStore.read_string(want, "mode", "")])
	assert_eq(o.settings.control_scheme, SCHEME_NAMES[SaveStore.read_string(want, "controlScheme", "")])
	assert_eq(o.settings.sfx_enabled, SaveStore.read_bool(want, "sfxEnabled", false))
	assert_almost_eq(o.settings.sfx_volume, SaveStore.read_float(want, "sfxVolume", -1.0), 0.0001)
	assert_eq(o.settings.music_enabled, SaveStore.read_bool(want, "musicEnabled", false))
	assert_almost_eq(o.settings.music_volume, SaveStore.read_float(want, "musicVolume", -1.0), 0.0001)
	assert_eq(o.settings.screen_shake, SHAKE_NAMES[SaveStore.read_string(want, "screenShake", "")])
	assert_eq(o.settings.tether_line, SaveStore.read_bool(want, "tetherLine", false))
	assert_eq(o.settings.high_contrast_halo, SaveStore.read_bool(want, "highContrastHalo", false))
	assert_eq(o.settings.show_gridlines, SaveStore.read_bool(want, "showGridlines", true))
	# The round trip preserves the TS strings.
	_assert_dict_numbers_equal(o.settings.to_dict(), want, "default_settings")


func test_shake_multipliers_match_the_typescript() -> void:
	_remove_settings()
	var o: GameOptionsManager = GameOptionsManager.new()
	var cases: Array = _fixture["shake_multipliers"]
	for entry: Dictionary in cases:
		var key: String = SaveStore.read_string(entry, "screenShake", "")
		if not SHAKE_NAMES.has(key):
			continue  # 'bogus' has no enum value; from_dict keeps the default instead
		o.settings.screen_shake = SHAKE_NAMES[key]
		assert_almost_eq(
			o.get_shake_multiplier(), SaveStore.read_float(entry, "multiplier", -1.0), 0.0001, key
		)
```

- [x] **Step 2: Run the spec to verify it fails**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_game_options.gd
```

Expected: exit 1 — `GameOptionsManager` does not exist. Also run the `class_check.gd` probe from Task 1 Step 3 with `"GameOptionsManager"`; it must print `false`.

- [x] **Step 3: Create `game_options.gd`**

```gdscript
## game_options.gd
## PORTS: web/src/tilt-to-live/GameOptions.ts (137 lines, source commit 7be9614)
class_name GameOptionsManager
extends RefCounted
## Mode selection, audio, controls and visual settings, persisted as
## user://tilt_to_live_settings_v1.json.
##
## PORT-NOTE: the class is GameOptionsManager (GameOptions.ts:34) and the file
## is game_options.gd (spec §4.2) — the TS file and class names differ too.
##
## PORT-NOTE: three string unions (:5, :21, :26) become enums; the three
## *_IDS tables carry the TS strings so the save keeps the web shape
## (spec §4.6). Types.GameMode and Types.ControlScheme already exist as
## cited ports of :5 and :21; ScreenShake is declared here.
##
## PORT-NOTE: controlScheme is persisted for shape fidelity only. The live
## scheme is ControlSettings.scheme (M2.5 spec §4.2, a DIVERGENCE), which
## input_router.gd reads; nothing reads settings.control_scheme yet.

## PORT: web/src/tilt-to-live/GameOptions.ts:26
enum ScreenShake { OFF, LOW, NORMAL, EXTREME, FULL }

## PORT: web/src/tilt-to-live/GameOptions.ts:32
const STORAGE_KEY: String = "tilt_to_live_settings_v1"
## The localStorage key as a user:// file (spec §4.6).
const SAVE_PATH: String = "user://" + STORAGE_KEY + ".json"

## The TS GameMode strings. PORT: web/src/tilt-to-live/GameOptions.ts:5
const MODE_IDS: Dictionary[Types.GameMode, String] = {
	Types.GameMode.CLASSIC: "classic",
	Types.GameMode.CODE_RED: "code-red",
	Types.GameMode.GAUNTLET: "gauntlet",
}
## The TS controlScheme strings. PORT: web/src/tilt-to-live/GameOptions.ts:21
const CONTROL_SCHEME_IDS: Dictionary[Types.ControlScheme, String] = {
	Types.ControlScheme.HYBRID: "hybrid",
	Types.ControlScheme.MOUSE: "mouse",
	Types.ControlScheme.KEYBOARD: "keyboard",
	Types.ControlScheme.GYRO: "gyro",
}
## The TS screenShake strings. PORT: web/src/tilt-to-live/GameOptions.ts:26
const SCREEN_SHAKE_IDS: Dictionary[ScreenShake, String] = {
	ScreenShake.OFF: "off",
	ScreenShake.LOW: "low",
	ScreenShake.NORMAL: "normal",
	ScreenShake.EXTREME: "extreme",
	ScreenShake.FULL: "full",
}

## The live settings. PORT: web/src/tilt-to-live/GameOptions.ts:35
var settings: GameSettings = null
## The three modes, in catalog order. PORT: web/src/tilt-to-live/GameOptions.ts:37-71
var modes: Array[ModeConfig] = []


## PORT: web/src/tilt-to-live/GameOptions.ts:73-75
func _init() -> void:
	modes = _build_modes()
	settings = load_settings()


## PORT: web/src/tilt-to-live/GameOptions.ts:92-105
# PORT-NOTE: the try/catch (:102-104) is SaveStore's quarantine; {} is the
# `!raw` branch (:95). `showGridlines: parsed.showGridlines === true` (:100)
# is what read_bool already does — a non-bool never becomes true.
func load_settings() -> GameSettings:
	var def: GameSettings = _get_default_settings()
	var raw: Dictionary = SaveStore.load_dict(SAVE_PATH)
	if raw.is_empty():
		return def
	def.from_dict(raw)
	return def


## PORT: web/src/tilt-to-live/GameOptions.ts:107-111
func save() -> void:
	SaveStore.save_dict(SAVE_PATH, settings.to_dict())


## PORT: web/src/tilt-to-live/GameOptions.ts:113-115
# PORT-NOTE: the TS defaults `mode` to this.settings.mode; callers pass
# settings.mode explicitly here (TiltGame.ts:1549, :1931 do so already).
func get_mode_config(mode: Types.GameMode) -> ModeConfig:
	for config: ModeConfig in modes:
		if config.id == mode:
			return config
	return modes[0]


## PORT: web/src/tilt-to-live/GameOptions.ts:117-120
func set_mode(mode: Types.GameMode) -> void:
	settings.mode = mode
	save()


## PORT: web/src/tilt-to-live/GameOptions.ts:122-136
func get_shake_multiplier() -> float:
	match settings.screen_shake:
		ScreenShake.OFF:
			return 0.0
		ScreenShake.LOW:
			return 0.5  # PORT: :127
		ScreenShake.NORMAL, ScreenShake.FULL:
			return 1.0
		ScreenShake.EXTREME:
			return 1.8  # PORT: :132
		_:
			return 1.0


## PORT: web/src/tilt-to-live/GameOptions.ts:77-90
func _get_default_settings() -> GameSettings:
	var s: GameSettings = GameSettings.new()
	s.mode = Types.GameMode.CLASSIC
	s.control_scheme = Types.ControlScheme.HYBRID
	s.sfx_enabled = true
	s.sfx_volume = 0.8  # PORT: :82
	s.music_enabled = true
	s.music_volume = 0.7  # PORT: :84
	s.screen_shake = ScreenShake.NORMAL
	s.tether_line = true
	s.high_contrast_halo = true
	s.show_gridlines = false
	return s


# PORT: web/src/tilt-to-live/GameOptions.ts:37-71
func _build_modes() -> Array[ModeConfig]:
	var out: Array[ModeConfig] = []

	# PORT: web/src/tilt-to-live/GameOptions.ts:38-48
	var classic: ModeConfig = ModeConfig.new()
	classic.id = Types.GameMode.CLASSIC
	classic.name = "Standard"
	classic.badge = "1.0×"
	classic.tagline = "The full arsenal, ramping swarms."
	classic.description = "The full arsenal, ramping swarms."
	classic.color = Color("#5B8CFF")
	classic.accent = Color("#8FB0FF")
	classic.glow = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.35)
	classic.score_multiplier = 1.0
	out.append(classic)

	# PORT: web/src/tilt-to-live/GameOptions.ts:49-59
	var gauntlet: ModeConfig = ModeConfig.new()
	gauntlet.id = Types.GameMode.GAUNTLET
	gauntlet.name = "Gauntlet"
	gauntlet.badge = "1.25×"
	gauntlet.tagline = "Walls close in while you dodge."
	gauntlet.description = "Walls close in while you dodge."
	gauntlet.color = Color("#FFB14D")
	gauntlet.accent = Color("#FFD277")
	gauntlet.glow = Color(255.0 / 255.0, 177.0 / 255.0, 77.0 / 255.0, 0.35)
	gauntlet.score_multiplier = 1.25
	out.append(gauntlet)

	# PORT: web/src/tilt-to-live/GameOptions.ts:60-70
	var code_red: ModeConfig = ModeConfig.new()
	code_red.id = Types.GameMode.CODE_RED
	code_red.name = "Code Red"
	code_red.badge = "1.5×"
	code_red.tagline = "Double density from the first second."
	code_red.description = "Double density from the first second."
	code_red.color = Color("#A78BFA")
	code_red.accent = Color("#C4B5FD")
	code_red.glow = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0, 0.35)
	code_red.score_multiplier = 1.5
	out.append(code_red)

	return out


## PORT: web/src/tilt-to-live/GameOptions.ts:7-17
class ModeConfig:
	extends RefCounted
	var id: Types.GameMode = Types.GameMode.CLASSIC
	var name: String = ""
	var badge: String = ""
	var tagline: String = ""
	var description: String = ""
	var color: Color = Color.WHITE
	var accent: Color = Color.WHITE
	var glow: Color = Color.WHITE
	var score_multiplier: float = 1.0


## PORT: web/src/tilt-to-live/GameOptions.ts:19-30
class GameSettings:
	extends RefCounted
	var mode: Types.GameMode = Types.GameMode.CLASSIC
	var control_scheme: Types.ControlScheme = Types.ControlScheme.HYBRID
	var sfx_enabled: bool = true
	## 0..1. PORT: web/src/tilt-to-live/GameOptions.ts:23
	var sfx_volume: float = 1.0
	var music_enabled: bool = true
	## 0..1. PORT: web/src/tilt-to-live/GameOptions.ts:25
	var music_volume: float = 1.0
	var screen_shake: ScreenShake = ScreenShake.NORMAL
	var tether_line: bool = true
	var high_contrast_halo: bool = true
	var show_gridlines: bool = false

	## JSON.stringify(this.settings) (GameOptions.ts:109), TS keys and strings.
	func to_dict() -> Dictionary:
		return {
			"mode": MODE_IDS[mode],
			"controlScheme": CONTROL_SCHEME_IDS[control_scheme],
			"sfxEnabled": sfx_enabled,
			"sfxVolume": sfx_volume,
			"musicEnabled": music_enabled,
			"musicVolume": music_volume,
			"screenShake": SCREEN_SHAKE_IDS[screen_shake],
			"tetherLine": tether_line,
			"highContrastHalo": high_contrast_halo,
			"showGridlines": show_gridlines,
		}

	## `{...defaults, ...parsed}` (GameOptions.ts:97-101). An unknown string
	## for an enum field keeps the current value.
	func from_dict(d: Dictionary) -> void:
		var mode_id: String = SaveStore.read_string(d, "mode", MODE_IDS[mode])
		if MODE_IDS.values().has(mode_id):
			mode = MODE_IDS.find_key(mode_id)
		var scheme_id: String = SaveStore.read_string(
			d, "controlScheme", CONTROL_SCHEME_IDS[control_scheme]
		)
		if CONTROL_SCHEME_IDS.values().has(scheme_id):
			control_scheme = CONTROL_SCHEME_IDS.find_key(scheme_id)
		sfx_enabled = SaveStore.read_bool(d, "sfxEnabled", sfx_enabled)
		sfx_volume = SaveStore.read_float(d, "sfxVolume", sfx_volume)
		music_enabled = SaveStore.read_bool(d, "musicEnabled", music_enabled)
		music_volume = SaveStore.read_float(d, "musicVolume", music_volume)
		var shake_id: String = SaveStore.read_string(d, "screenShake", SCREEN_SHAKE_IDS[screen_shake])
		if SCREEN_SHAKE_IDS.values().has(shake_id):
			screen_shake = SCREEN_SHAKE_IDS.find_key(shake_id)
		tether_line = SaveStore.read_bool(d, "tetherLine", tether_line)
		high_contrast_halo = SaveStore.read_bool(d, "highContrastHalo", high_contrast_halo)
		show_gridlines = SaveStore.read_bool(d, "showGridlines", show_gridlines)  # PORT: :100
```

`Dictionary.find_key` returns `Variant`; assigning it to an enum-typed variable may trip a Tier-1 warning. If so, replace each `find_key` line with an explicit loop over the table's keys (`for key: Types.GameMode in MODE_IDS.keys(): if MODE_IDS[key] == mode_id: mode = key`) — no `@warning_ignore`.

- [x] **Step 4: Run everything**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
```

Expected: `OK: 39/39 scripts collected, all tests passed.`; format and lint clean.

- [x] **Step 5: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/src/meta/game_options.gd godot/src/meta/game_options.gd.uid godot/tests/test_game_options.gd godot/tests/test_game_options.gd.uid godot/tests/test_progression_parity.gd
git commit -m "M7: port GameOptions with the web settings shape"
git log -1 --format=%B
```

---

### Task 8: `CoinSystem` — spawning, lifetime, pickup; coins drawn in `EntityLayer`

**Files:**
- Create: `godot/src/sim/coin_system.gd`
- Modify: `godot/src/render/entity_layer.gd:41-63` (`_draw`, `bind_entities`), new `_draw_coins` + `_quadratic_points` helper, `:8-13` and `:172-176` retags
- Test: `godot/tests/test_coin_system.gd` (new); `godot/tests/test_render_layers.gd` (append)

**Interfaces:**
- Consumes: `PlayerShip` (`x`, `y`, `radius`), `ParticleEngine.emit_sparks(x, y, count, color, speed_max)` (`particle_engine.gd:51`), `AudioBank.play_coin_pickup()` (`audio_bank.gd:68`).
- Produces:
  - `class_name CoinSystem`; inner `CoinPickup` (`id: int`, `x`, `y`, `radius`, `lifetime`, `max_lifetime`, `pulse_offset: float`).
  - Constants `COIN_COLOR: Color`, `MAX_COINS_ON_SCREEN: int`, `COIN_LIFETIME`, `COIN_RADIUS`, `FADE_WARNING_TIME`, `MIN_DISTANCE_FROM_PLAYER`, `SPAWN_INTERVAL_MIN`, `SPAWN_INTERVAL_MAX: float`, `COIN_BASE_VALUE: int`.
  - `var coins: Array[CoinPickup]`, `coins_collected: int`, `points_from_coins: int`.
  - `reset() -> void`; `update(dt: float, player: PlayerShip, bounds: Vector2, particles: ParticleEngine, audio: AudioBank, mode_multiplier: float, on_collected: Callable) -> void` — `on_collected` is `func(value: int) -> int`.
  - `EntityLayer.bind_entities(player, swarm = null, weapons = null, coins: CoinSystem = null)`.

- [x] **Step 1: Write the failing specs**

Create `godot/tests/test_coin_system.gd`:

```gdscript
## test_coin_system.gd
## PORTS: nothing — new file, covers src/sim/coin_system.gd
extends GutTest
## Proves coin spawning cadence and placement, the on-screen cap, expiry,
## pickup crediting through the callback, and the mode multiplier.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)

var _cs: CoinSystem = null
var _player: PlayerShip = null
var _particles: ParticleEngine = null
var _audio: AudioBank = null
var _credited: Array[int] = []


func before_each() -> void:
	seed(20260921)
	_cs = CoinSystem.new()
	_player = PlayerShip.new(500.0, 300.0)
	_particles = ParticleEngine.new()
	_audio = AudioBank.new()
	_credited = []


func _bank() -> Callable:
	# Stands in for ProgressionManager.add_points_credited: returns the credited
	# amount, here doubled so the test can tell the two figures apart.
	return func(value: int) -> int:
		_credited.append(value)
		return value * 2


func _step(seconds: float, mode_multiplier: float = 1.0) -> void:
	var t: float = 0.0
	while t < seconds:
		_cs.update(0.05, _player, BOUNDS, _particles, _audio, mode_multiplier, _bank())
		t += 0.05


func test_constants_match_the_typescript() -> void:
	assert_eq(CoinSystem.MAX_COINS_ON_SCREEN, 6, "CoinSystem.ts:29")
	assert_almost_eq(CoinSystem.COIN_LIFETIME, 12.0, 0.0001, ":30")
	assert_almost_eq(CoinSystem.COIN_RADIUS, 9.0, 0.0001, ":31")
	assert_eq(CoinSystem.COIN_BASE_VALUE, 25, ":32")
	assert_almost_eq(CoinSystem.FADE_WARNING_TIME, 3.0, 0.0001, ":33")
	assert_almost_eq(CoinSystem.MIN_DISTANCE_FROM_PLAYER, 110.0, 0.0001, ":34")
	assert_almost_eq(CoinSystem.SPAWN_INTERVAL_MIN, 2.5, 0.0001, ":35")
	assert_almost_eq(CoinSystem.SPAWN_INTERVAL_MAX, 4.0, 0.0001, ":36")
	assert_eq(CoinSystem.COIN_COLOR, Color("#FFB14D"), ":27")


func test_no_coin_before_the_first_interval_then_one() -> void:
	_step(2.4)
	assert_eq(_cs.coins.size(), 0, "spawnTimer starts at >= 2.5 s (:44)")
	_step(1.7)
	assert_eq(_cs.coins.size(), 1, "and at most 4.0 s")
	var coin: CoinSystem.CoinPickup = _cs.coins[0]
	assert_eq(coin.id, 1, "ids start at 1 (:43)")
	assert_almost_eq(coin.radius, 9.0, 0.0001)
	assert_almost_eq(coin.max_lifetime, 12.0, 0.0001)
	assert_true(coin.lifetime <= 12.0 and coin.lifetime > 11.0)
	assert_true(coin.pulse_offset >= 0.0 and coin.pulse_offset < TAU, ":122")


func test_coins_spawn_inside_the_padded_arena_away_from_the_player() -> void:
	_step(60.0)
	assert_gt(_cs.coins.size(), 0)
	for coin: CoinSystem.CoinPickup in _cs.coins:
		assert_true(coin.x >= 50.0 and coin.x <= BOUNDS.x - 50.0, "pad 50 (:102)")
		assert_true(coin.y >= 50.0 and coin.y <= BOUNDS.y - 50.0)
		var d: float = Vector2(coin.x, coin.y).distance_to(Vector2(_player.x, _player.y))
		assert_gt(d, 110.0, "MIN_DISTANCE_FROM_PLAYER (:103, :112)")


func test_never_more_than_six_on_screen() -> void:
	# One spawn per 2.5-4 s against a 12 s lifetime settles at three or four
	# coins, so the cap is exercised by pre-filling it with long-lived coins.
	for i: int in range(6):
		var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
		coin.id = 100 + i
		coin.x = 100.0 + 50.0 * float(i)
		coin.y = 100.0
		coin.radius = CoinSystem.COIN_RADIUS
		coin.lifetime = 100.0
		coin.max_lifetime = 100.0
		_cs.coins.append(coin)
	_step(20.0)
	assert_eq(_cs.coins.size(), 6, "no spawn while six are live (:67)")
	_cs.coins[0].lifetime = 0.01
	_step(4.1)
	assert_eq(_cs.coins.size(), 6, "one expired, one spawned into the freed slot")
	assert_true(_cs.coins[5].id < 100 or _cs.coins[5].id > 105, "the newest coin has a fresh id")


func test_coins_expire_after_their_lifetime() -> void:
	_step(4.0)
	assert_eq(_cs.coins.size(), 1)
	_cs.coins[0].lifetime = 0.04
	_cs.update(0.05, _player, BOUNDS, _particles, _audio, 1.0, _bank())
	assert_eq(_cs.coins.size(), 0, ":78-80")
	assert_eq(_cs.coins_collected, 0, "expiry is not a pickup")


func test_pickup_credits_through_the_callback_and_tracks_the_credited_figure() -> void:
	_step(4.0)
	assert_eq(_cs.coins.size(), 1)
	var coin: CoinSystem.CoinPickup = _cs.coins[0]
	_player.x = coin.x
	_player.y = coin.y
	var particles_before: int = _particles.particles.size()
	_cs.update(0.01, _player, BOUNDS, _particles, _audio, 1.0, _bank())
	assert_eq(_cs.coins.size(), 0, "collected coins are removed (:96)")
	assert_eq(_cs.coins_collected, 1)
	assert_eq(_credited, [25], "COIN_BASE_VALUE * 1.0, unmultiplied (:88)")
	assert_eq(_cs.points_from_coins, 50, "what the callback says was credited (:95)")
	assert_gt(_particles.particles.size(), particles_before, "16 sparks (:91)")


func test_mode_multiplier_rounds_the_coin_value() -> void:
	_step(4.0)
	var coin: CoinSystem.CoinPickup = _cs.coins[0]
	_player.x = coin.x
	_player.y = coin.y
	_cs.update(0.01, _player, BOUNDS, _particles, _audio, 1.25, _bank())
	assert_eq(_credited, [31], "Math.round(25 * 1.25) = 31 (:88)")
	_credited = []
	_step(4.0)
	coin = _cs.coins[0]
	_player.x = coin.x
	_player.y = coin.y
	_cs.update(0.01, _player, BOUNDS, _particles, _audio, 1.5, _bank())
	assert_eq(_credited, [38], "Math.round(37.5) = 38")


func test_reset_clears_everything_and_restarts_the_timer() -> void:
	_step(30.0)
	var coin: CoinSystem.CoinPickup = _cs.coins[0]
	_player.x = coin.x
	_player.y = coin.y
	_cs.update(0.01, _player, BOUNDS, _particles, _audio, 1.0, _bank())
	assert_gt(_cs.coins_collected, 0)
	_cs.reset()
	assert_eq(_cs.coins.size(), 0)
	assert_eq(_cs.coins_collected, 0)
	assert_eq(_cs.points_from_coins, 0)
	_player.x = 500.0
	_player.y = 300.0
	_step(2.4)
	assert_eq(_cs.coins.size(), 0, "the timer restarts at >= 2.5 s (:51)")
	_step(1.7)
	assert_eq(_cs.coins.size(), 1)
	assert_eq(_cs.coins[0].id, 1, "ids restart at 1 (:50)")
```

Check `ParticleEngine` exposes its pool as `particles` (`grep -n "^var " godot/src/sim/particle_engine.gd`); if the array has another name, use that name in the spec.

Append to `godot/tests/test_render_layers.gd` (read its existing `test_entity_layer_bind_entities_and_draw` at `:42` first and follow its setup idiom for adding the layer to the tree and awaiting a frame):

```gdscript
func test_entity_layer_draws_coins_without_error() -> void:
	var layer: EntityLayer = EntityLayer.new()
	add_child_autofree(layer)
	var player: PlayerShip = PlayerShip.new(100.0, 100.0)
	var coins: CoinSystem = CoinSystem.new()
	var fresh: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	fresh.id = 1
	fresh.x = 200.0
	fresh.y = 150.0
	fresh.radius = CoinSystem.COIN_RADIUS
	fresh.lifetime = 10.0
	fresh.max_lifetime = CoinSystem.COIN_LIFETIME
	var fading: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	fading.id = 2
	fading.x = 300.0
	fading.y = 150.0
	fading.radius = CoinSystem.COIN_RADIUS
	fading.lifetime = 1.0
	fading.max_lifetime = CoinSystem.COIN_LIFETIME
	coins.coins.append(fresh)
	coins.coins.append(fading)
	layer.bind_entities(player, EnemySwarm.new(), WeaponSystem.new(), coins)
	layer.set_elapsed(1.5)
	layer.queue_redraw()
	await get_tree().process_frame
	assert_true(true, "two coins, one inside FADE_WARNING_TIME, drew without a script error")
```

- [x] **Step 2: Run the specs to verify they fail**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_coin_system.gd
```

Expected: exit 1 — `CoinSystem` does not exist. Run the `class_check.gd` probe with `"CoinSystem"`; it must print `false`.

- [x] **Step 3: Create `coin_system.gd`**

```gdscript
## coin_system.gd
## PORTS: web/src/tilt-to-live/CoinSystem.ts (176 lines, source commit 7be9614)
class_name CoinSystem
extends RefCounted
## Points coin pickups: a currency-drop system independent of
## WeaponSystem's orb spawner, on its own cadence, so points income no
## longer depends solely on milestone rewards. Collecting a coin credits the
## run's single currency ("Points") via ProgressionManager.add_points_credited,
## which already applies the player's purchased points multiplier — the value
## passed to the callback must stay unmultiplied or that multiplier
## double-applies. PORT: web/src/tilt-to-live/CoinSystem.ts:4-9
##
## PORT-NOTE: render() (CoinSystem.ts:126-175) relocates to
## render/entity_layer.gd::_draw_coins (spec §4.2/D4, §5.5), the relocation M3
## and M4 made for their render() bodies. COIN_COLOR and FADE_WARNING_TIME
## stay here (LAW 3) and the layer reads them.

## --flare (#FFB14D) is the design system's reserved points/currency colour.
## Never reuse hazard red (#FF4757, enemies-only) here.
## PORT: web/src/tilt-to-live/CoinSystem.ts:25-27
const COIN_COLOR: Color = Color("#FFB14D")

const MAX_COINS_ON_SCREEN: int = 6  # PORT: web/src/tilt-to-live/CoinSystem.ts:29
const COIN_LIFETIME: float = 12.0  # PORT: web/src/tilt-to-live/CoinSystem.ts:30
const COIN_RADIUS: float = 9.0  # PORT: web/src/tilt-to-live/CoinSystem.ts:31
const COIN_BASE_VALUE: int = 25  # PORT: web/src/tilt-to-live/CoinSystem.ts:32
## Seconds remaining at which the coin starts fading out.
const FADE_WARNING_TIME: float = 3.0  # PORT: web/src/tilt-to-live/CoinSystem.ts:33
const MIN_DISTANCE_FROM_PLAYER: float = 110.0  # PORT: web/src/tilt-to-live/CoinSystem.ts:34
const SPAWN_INTERVAL_MIN: float = 2.5  # PORT: web/src/tilt-to-live/CoinSystem.ts:35
const SPAWN_INTERVAL_MAX: float = 4.0  # PORT: web/src/tilt-to-live/CoinSystem.ts:36

## Live coins. PORT: web/src/tilt-to-live/CoinSystem.ts:39
var coins: Array[CoinPickup] = []
## Coins picked up this run. PORT: web/src/tilt-to-live/CoinSystem.ts:40
var coins_collected: int = 0
## Points actually credited from coins this run. PORT: web/src/tilt-to-live/CoinSystem.ts:41
var points_from_coins: int = 0

var _next_coin_id: int = 1  # PORT: web/src/tilt-to-live/CoinSystem.ts:43
# PORT: web/src/tilt-to-live/CoinSystem.ts:44
var _spawn_timer: float = SPAWN_INTERVAL_MIN + randf() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN)


## PORT: web/src/tilt-to-live/CoinSystem.ts:46-52
func reset() -> void:
	coins = []
	coins_collected = 0
	points_from_coins = 0
	_next_coin_id = 1
	_spawn_timer = SPAWN_INTERVAL_MIN + randf() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN)


## Spawns on its own timer, ages every coin, and banks pickups through
## `on_collected` (func(value: int) -> int, returning what was actually
## credited). PORT: web/src/tilt-to-live/CoinSystem.ts:54-99
# PORT-NOTE: `bounds: {width, height}` (:57) becomes Vector2 (x = width,
# y = height), the rule in types.gd; the audio parameter is AudioBank (M2's
# TiltAudio surface).
func update(
	dt: float,
	player: PlayerShip,
	bounds: Vector2,
	particles: ParticleEngine,
	audio: AudioBank,
	mode_multiplier: float,
	on_collected: Callable
) -> void:
	# 1. Coin spawning - runs entirely on its own timer, independent of
	# WeaponSystem's orb cooldown.
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		if coins.size() < MAX_COINS_ON_SCREEN:
			_spawn_coin(bounds, player)
		_spawn_timer = SPAWN_INTERVAL_MIN + randf() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN)

	# 2. Lifetime + pickup collision
	for i: int in range(coins.size() - 1, -1, -1):
		var coin: CoinPickup = coins[i]
		coin.lifetime -= dt

		if coin.lifetime <= 0.0:
			coins.remove_at(i)
			continue

		var dx: float = player.x - coin.x
		var dy: float = player.y - coin.y
		var dist: float = sqrt(dx * dx + dy * dy)

		if dist < player.radius + coin.radius:
			var value: int = roundi(float(COIN_BASE_VALUE) * mode_multiplier)  # PORT: :88
			coins_collected += 1
			audio.play_coin_pickup()
			particles.emit_sparks(coin.x, coin.y, 16, COIN_COLOR, 160.0)  # PORT: :91
			# onCollected banks the coin and returns what was ACTUALLY credited, which
			# differs from `value` once the player owns the Points Multiplier upgrade.
			# Track the credited figure so the run summary cannot under-report earnings.
			var credited: int = on_collected.call(value)
			points_from_coins += credited
			coins.remove_at(i)


## PORT: web/src/tilt-to-live/CoinSystem.ts:101-124
func _spawn_coin(bounds: Vector2, player: PlayerShip) -> void:
	var pad: float = 50.0  # PORT: :102
	var min_dist2: float = MIN_DISTANCE_FROM_PLAYER * MIN_DISTANCE_FROM_PLAYER

	var x: float = 0.0
	var y: float = 0.0
	for attempt: int in range(10):  # PORT: :107
		x = pad + randf() * (bounds.x - pad * 2.0)
		y = pad + randf() * (bounds.y - pad * 2.0)
		var dx: float = x - player.x
		var dy: float = y - player.y
		if dx * dx + dy * dy >= min_dist2:
			break

	var coin: CoinPickup = CoinPickup.new()
	coin.id = _next_coin_id
	_next_coin_id += 1
	coin.x = x
	coin.y = y
	coin.radius = COIN_RADIUS
	coin.lifetime = COIN_LIFETIME
	coin.max_lifetime = COIN_LIFETIME
	coin.pulse_offset = randf() * TAU  # PORT: :122
	coins.append(coin)


## PORT: web/src/tilt-to-live/CoinSystem.ts:15-23
class CoinPickup:
	extends RefCounted
	var id: int = 0
	var x: float = 0.0
	var y: float = 0.0
	var radius: float = 0.0
	var lifetime: float = 0.0
	var max_lifetime: float = 0.0
	var pulse_offset: float = 0.0
```

`var credited: int = on_collected.call(value)` assigns a `Variant`; the M4 kill callback never needed the return, so this is the first such site. If a Tier-1 warning fires, use the two-line form `var result: Variant = on_collected.call(value)` / `if result is int: points_from_coins += result` with a `# PORT-NOTE: the Callable's return is untyped by construction`. `for attempt: int in range(10)` will trip `UNUSED_VARIABLE` — name it `_attempt`.

- [x] **Step 4: Draw the coins in `entity_layer.gd`**

Change `_draw()` (`:41-46`) to:

```gdscript
func _draw() -> void:
	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)
	_draw_coins()
	_draw_weapons()
	_draw_enemies()
	_draw_player()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
```

Change `bind_entities` (`:55-61`) to take the coins:

```gdscript
## Gives this layer all entity systems it draws. Called by GameRoot.
func bind_entities(
	player: PlayerShip,
	swarm: EnemySwarm = null,
	weapons: WeaponSystem = null,
	coins: CoinSystem = null
) -> void:
	_player = player
	_swarm = swarm
	_weapons = weapons
	_coins = coins
```

and declare `var _coins: CoinSystem = null` beside `_weapons` (find it with `grep -n "_weapons: WeaponSystem" godot/src/render/entity_layer.gd`). Add, before `_draw_weapons()`:

```gdscript
## Coins, under the orbs (spec §5.5). PORT: web/src/tilt-to-live/CoinSystem.ts:126-175
# PORT-NOTE: the radial gradient (:146-149, stops #FFE3B0 / COIN_COLOR /
# #B8792A) is two flat circles per the M3 ruling: the disc in COIN_COLOR and
# a highlight at the gradient's (-2, -2) centre in #FFE3B0 at the 0.55 stop's
# radius fraction; the outer #B8792A stop reads as the 1.4 px white stroke's
# neighbour and is not drawn. The two quadraticCurveTo glyph strokes
# (:167-169) are sampled polylines.
func _draw_coins() -> void:
	if _coins == null or _coins.coins.is_empty():
		return
	for coin: CoinSystem.CoinPickup in _coins.coins:
		var pulse: float = 0.9 + 0.1 * sin(_elapsed * 7.0 + coin.pulse_offset)  # PORT: :131
		var fade_alpha: float = 1.0
		if coin.lifetime < CoinSystem.FADE_WARNING_TIME:
			fade_alpha = maxf(0.15, coin.lifetime / CoinSystem.FADE_WARNING_TIME)  # PORT: :132
		var pos: Vector2 = Vector2(coin.x, coin.y)

		# Soft amber glow halo. PORT: :139-142 (`${COIN_COLOR}33` = alpha 0x33)
		var halo: Color = CoinSystem.COIN_COLOR
		halo.a = (0x33 / 255.0) * fade_alpha
		draw_circle(pos, (coin.radius + 7.0) * pulse, halo)

		# Solid coin disc. PORT: :146-153
		var disc: Color = CoinSystem.COIN_COLOR
		disc.a = fade_alpha
		var r: float = coin.radius * pulse
		draw_circle(pos, r, disc)
		var highlight: Color = Color("#FFE3B0")  # PORT: :147
		highlight.a = fade_alpha
		draw_circle(pos + Vector2(-2.0, -2.0), r * 0.55, highlight)  # PORT: :146, :148
		var rim: Color = Color.WHITE
		rim.a = fade_alpha
		draw_arc(pos, r, 0.0, TAU, 32, rim, 1.4)  # PORT: :155-157

		# Currency glyph (dollar-style bar). PORT: :160-170
		var ink: Color = Color("#4A2E0A")
		ink.a = fade_alpha
		draw_line(
			pos + Vector2(0.0, -coin.radius * 0.55), pos + Vector2(0.0, coin.radius * 0.55), ink, 1.8
		)
		var upper: PackedVector2Array = _quadratic_points(
			pos + Vector2(-coin.radius * 0.4, -coin.radius * 0.25),
			pos + Vector2(coin.radius * 0.45, -coin.radius * 0.25),
			pos + Vector2(coin.radius * 0.4, 0.0)
		)
		var lower: PackedVector2Array = _quadratic_points(
			pos + Vector2(coin.radius * 0.4, 0.0),
			pos + Vector2(coin.radius * 0.45, coin.radius * 0.25),
			pos + Vector2(-coin.radius * 0.4, coin.radius * 0.25)
		)
		upper.append_array(lower)
		draw_polyline(upper, ink, 1.8)


# A quadratic Bézier (Canvas quadraticCurveTo) sampled as a polyline.
func _quadratic_points(p0: Vector2, control: Vector2, p1: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(9):
		var t: float = float(i) / 8.0
		var q0: Vector2 = p0.lerp(control, t)
		var q1: Vector2 = control.lerp(p1, t)
		out.append(q0.lerp(q1, t))
	return out
```

`_elapsed` is the run clock `set_elapsed()` (`:64`) stores; confirm the variable's name with `grep -n "func set_elapsed" -A2 godot/src/render/entity_layer.gd` and use it. Every point above is `pos + …` — after editing, run `grep -n "draw_set_transform(Vector2(" godot/src/render/` and confirm it prints nothing (the M2.5/M3 transform-replacement class).

Retag the header (`:8-13`): replace `Ship skins are M7/M8, so M1/M2 draws the default classic arrow (PlayerShip.ts:594-617) alone.` / `TODO(M7): the viper, phantom, solar, cyber, shuriken and celestial shapes.` with `The catalog is ProgressionManager.ship_catalog (M7); nothing can equip another ship until the Armory (M8), so only the classic arrow (PlayerShip.ts:594-617) is drawn.` / `TODO(M8): the viper, phantom, solar, cyber, shuriken and celestial shapes.` Retag `:174` from `TODO(M7): enemy skins` to `TODO(M8): enemy skins` and change `skin (EnemySkinConfig) is M7` at `:173` to `skin (EnemySkinConfig) is ProgressionManager.enemy_skin_catalog (M7); equipping is M8`. Open question 4 records why.

- [x] **Step 5: Run everything**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
grep -n "draw_set_transform(Vector2(" godot/src/render/
grep -rn "TODO(M7)" godot/src/render/entity_layer.gd
```

Expected: `OK: 40/40 scripts collected, all tests passed.`; format and lint clean; both greps print nothing.

- [x] **Step 6: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/src/sim/coin_system.gd godot/src/sim/coin_system.gd.uid godot/src/render/entity_layer.gd godot/tests/test_coin_system.gd godot/tests/test_coin_system.gd.uid godot/tests/test_render_layers.gd
git commit -m "M7: port CoinSystem and draw coins under the orbs"
git log -1 --format=%B
```

---

### Task 9: Run-path wiring — `GameRoot` owns the three instances; `RunController` reads them

**Files:**
- Modify: `godot/src/sim/run_controller.gd:22-26` (remove `perks`), `:29-46` (`_init`), `:49-68` (`reset_run`), `:71-79` (`spawn_starting_weapon_orb`), `:102-137` (`update`); `godot/src/core/game_root.gd:37`, `:58-90`; `godot/src/core/game_state_machine.gd:121-146` (comments only); `godot/src/input/input_router.gd:12-14` (comment only); `godot/src/render/grid_layer.gd:13`, `:93` (comments only)
- Test: `godot/tests/test_run_controller.gd` (constructor, two `perks` reads, one changed expectation, six new specs)

**Interfaces:**
- Consumes: `ProgressionManager` (`data.perks`, `data.tuning`, `get_equipped_ship`, `get_starting_lives`, `get_hitbox_multiplier`, `get_enemy_speed_multiplier`, `get_score_multiplier`, `add_points_credited`), `GameOptionsManager` (`settings.mode`, `settings.show_gridlines`, `get_mode_config`), `CoinSystem` (`reset`, `update`), `ScoreManager.set_mode_multiplier`/`set_progression_multiplier` (`score_manager.gd:44`, `:49`), `PlayerShip.set_hitbox_multiplier` (`player_ship.gd:80`), `EnemySwarm.set_speed_scale` (`enemy_swarm.gd:45`), `EntityLayer.bind_entities(…, coins)` (Task 8), `GridLayer.show_gridlines` (`grid_layer.gd:40`).
- Produces:
  - `RunController._init(p_player, p_swarm, p_weapons, p_particles, p_grid, p_scores, p_audio, p_progression: ProgressionManager, p_options: GameOptionsManager, p_coins: CoinSystem)` — ten parameters, the `gdlint` limit.
  - `var progression: ProgressionManager`, `var options: GameOptionsManager`, `var coins: CoinSystem` on `RunController` (public, like the other seven systems).
  - `var progression: ProgressionManager`, `var options: GameOptionsManager` on `GameRoot` (public, like `settings`), `var _coins: CoinSystem`.
  - **The `RunController.perks` variable is removed.** Tests set ranks on `progression.data.perks`.

- [x] **Step 1: Update the run-controller specs and write the failing ones**

In `godot/tests/test_run_controller.gd`:

1. Add `var _progression: ProgressionManager`, `var _options: GameOptionsManager`, `var _coins: CoinSystem` beside the other members.
2. In `before_each`, before constructing anything: remove `ProgressionManager.SAVE_PATH` and `GameOptionsManager.SAVE_PATH` (the `_remove` helper from `test_progression_manager.gd`, copied), then `_progression = ProgressionManager.new()`, `_options = GameOptionsManager.new()`, `_coins = CoinSystem.new()`, and change the constructor call to `RunController.new(_player, _swarm, _weapons, _particles, _grid, _scores, _audio, _progression, _options, _coins)`. Add an `after_each` that removes both files.
3. `:94`: `_rc.perks.shield.radius = 3` → `_progression.data.perks.shield.radius = 3`. `:101`: `_rc.perks.nuke.radius = 5` → `_progression.data.perks.nuke.radius = 5`.
4. `test_reset_run_initializes_state_and_spawns_orb` (`:27-34`): change the last assertion to `assert_eq(_weapons.orbs[0].type, Types.WeaponType.SHIELD, "the classic ship's startingWeapon (ProgressionManager.ts:138, TiltGame.ts:1965)")`.

Append:

```gdscript
func test_reset_run_takes_lives_and_multipliers_from_progression() -> void:
	_progression.data.extra_lives = 1
	_progression.data.hull_compact = 2
	_progression.data.enemy_slow = 3
	_progression.data.score_multiplier = 4
	var radius_before: float = _player.radius
	_rc.reset_run(_bounds)
	assert_eq(_rc.max_lives, 2, "getStartingLives (TiltGame.ts:1567)")
	assert_eq(_rc.lives, 2, ":1568")
	assert_almost_eq(_player.radius, radius_before * 0.88, 0.0001, "setHitboxMultiplier (:1570)")
	assert_almost_eq(_swarm.speed_scale, 0.88, 0.0001, "setSpeedScale (:1599)")
	assert_almost_eq(_scores.progression_multiplier, 1.4, 0.0001, "setProgressionMultiplier (:1551)")
	assert_almost_eq(_scores.mode_multiplier, 1.0, 0.0001, "classic mode (:1550)")


func test_reset_run_resets_the_coins() -> void:
	var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	coin.lifetime = 5.0
	_coins.coins.append(coin)
	_coins.coins_collected = 3
	_rc.reset_run(_bounds)
	assert_eq(_coins.coins.size(), 0, "coins.reset() (TiltGame.ts:1601)")
	assert_eq(_coins.coins_collected, 0)


func test_starting_orb_is_the_equipped_ships_weapon() -> void:
	_progression.equip_ship("tactical")
	_rc.reset_run(_bounds)
	assert_eq(_weapons.orbs.size(), 1)
	assert_eq(_weapons.orbs[0].type, Types.WeaponType.MISSILES, "the Viper's startingWeapon (:159)")


func test_coins_update_at_step_seven_and_credit_progression() -> void:
	_rc.reset_run(_bounds)
	var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	coin.id = 1
	coin.x = _player.x
	coin.y = _player.y
	coin.radius = CoinSystem.COIN_RADIUS
	coin.lifetime = 10.0
	coin.max_lifetime = CoinSystem.COIN_LIFETIME
	_coins.coins.append(coin)
	var points_before: int = _progression.data.points
	_rc.update(
		0.016, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
	)
	assert_eq(_coins.coins.size(), 0, "picked up")
	assert_eq(_coins.coins_collected, 1)
	assert_eq(_progression.data.points, points_before + 25, "addPointsCredited (TiltGame.ts:1939)")
	assert_eq(_coins.points_from_coins, 25)


func test_coin_value_uses_the_points_multiplier_only_through_the_callback() -> void:
	_progression.data.points_multiplier = 2
	_rc.reset_run(_bounds)
	var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	coin.x = _player.x
	coin.y = _player.y
	coin.radius = CoinSystem.COIN_RADIUS
	coin.lifetime = 10.0
	_coins.coins.append(coin)
	var points_before: int = _progression.data.points
	_rc.update(
		0.016, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
	)
	assert_eq(_progression.data.points, points_before + 30, "floor(25 * 1.2) — applied once (:1939)")
	assert_eq(_coins.points_from_coins, 30, "the credited figure, not the base value")


func test_player_update_reads_tuning_and_the_equipped_ship() -> void:
	_progression.data.points = 100000
	_progression.buy_ship("solar")
	_rc.reset_run(_bounds)
	var classic_radius: float = 9.0 * _player.scale
	_rc.update(
		0.016, Types.ControlMode.MOUSE, Vector2(_player.x, _player.y), Vector2.ZERO, Vector2.ZERO
	)
	assert_almost_eq(_player.radius, classic_radius * 1.90, 0.0001, "the Aegis hitboxScale (:199) via :1889")
```

- [x] **Step 2: Run to verify the file no longer compiles**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_run_controller.gd
```

Expected: exit 1 — `RunController.new` takes 7 arguments, not 10.

- [x] **Step 3: Rewire `run_controller.gd`**

Replace `:22-26` (the `perks` doc comment, `TODO(M7)` and variable) with:

```gdscript
## The player's save. PORT: web/src/tilt-to-live/TiltGame.ts:55 (this.progression)
var progression: ProgressionManager = null
## Mode and settings. PORT: web/src/tilt-to-live/TiltGame.ts:65 (this.options)
var options: GameOptionsManager = null
## Coin pickups. PORT: web/src/tilt-to-live/TiltGame.ts:51
var coins: CoinSystem = null
```

Replace `_init` (`:29-46`) with:

```gdscript
# PORT-NOTE: ten parameters is gdlint's limit and exactly the systems
# TiltGame.update()/resetRun() touch that this class owns.
func _init(
	p_player: PlayerShip,
	p_swarm: EnemySwarm,
	p_weapons: WeaponSystem,
	p_particles: ParticleEngine,
	p_grid: VectorGrid,
	p_scores: ScoreManager,
	p_audio: AudioBank,
	p_progression: ProgressionManager,
	p_options: GameOptionsManager,
	p_coins: CoinSystem
) -> void:
	player = p_player
	swarm = p_swarm
	weapons = p_weapons
	particles = p_particles
	grid = p_grid
	scores = p_scores
	audio = p_audio
	progression = p_progression
	options = p_options
	coins = p_coins
	# PORT: web/src/tilt-to-live/TiltGame.ts:212-218
	weapons.on_weapon_activated = _on_weapon_activated
```

Replace `reset_run` (`:49-68`) with:

```gdscript
## Resets all simulation state for a new run.
## PORT: web/src/tilt-to-live/TiltGame.ts:1547-1610
func reset_run(arena_bounds: Vector2) -> void:
	bounds = arena_bounds
	# PORT: web/src/tilt-to-live/TiltGame.ts:1548-1551
	var mode_config: GameOptionsManager.ModeConfig = options.get_mode_config(options.settings.mode)
	scores.set_mode_multiplier(mode_config.score_multiplier)
	scores.set_progression_multiplier(progression.get_score_multiplier())
	elapsed = 0.0
	# PORT: web/src/tilt-to-live/TiltGame.ts:1567-1568
	max_lives = progression.get_starting_lives()
	lives = max_lives
	is_run_active = true
	# Hull Compact shrinks the hitbox; it stacks with the equipped ship's own hitboxScale.
	# PORT: web/src/tilt-to-live/TiltGame.ts:1570
	player.set_hitbox_multiplier(progression.get_hitbox_multiplier())

	player.reset(bounds.x * 0.5, bounds.y * 0.5)
	# The shield.radius perk's only consumer is the bubble the ship draws.
	# PORT: web/src/tilt-to-live/TiltGame.ts:1572-1574
	player.set_shield_radius(
		Tuning.get_tuned_value("shield", "radius", progression.data.perks.shield.radius)
	)
	swarm.reset()
	swarm.set_speed_scale(progression.get_enemy_speed_multiplier())  # PORT: :1599
	weapons.reset()
	coins.reset()  # PORT: :1601
	particles.reset()
	scores.reset()
	grid.resize(bounds.x, bounds.y)

	spawn_starting_weapon_orb(bounds)
	GameEvents.score_changed.emit(0, 1, scores.stats.best_score)
```

(`TiltGame.ts:1548` also calls `options.setMode(mode)`; `GameStateMachine.reset_run` receives the mode and M10 owns mode selection — leave `setMode` there with its existing `TODO(M10)`/note and do not call it here.) Replace `spawn_starting_weapon_orb` (`:71-79`) with:

```gdscript
## Spawns the equipped ship's starting weapon orb offset from the spawn point.
## PORT: web/src/tilt-to-live/TiltGame.ts:1964-1979
# PORT-NOTE: the `!startingWeapon` guard (:1966) is dead — every catalog ship
# sets one (ProgressionManager.ts:138-264) — and an enum cannot be absent, so
# it has no port.
func spawn_starting_weapon_orb(arena_bounds: Vector2) -> void:
	var starting_weapon: Types.WeaponType = progression.get_equipped_ship().starting_weapon
	var angle: float = randf() * TAU
	var dist: float = minf(arena_bounds.x, arena_bounds.y) * 0.28
	var margin: float = 60.0
	var x: float = clampf(arena_bounds.x * 0.5 + cos(angle) * dist, margin, arena_bounds.x - margin)
	var y: float = clampf(arena_bounds.y * 0.5 + sin(angle) * dist, margin, arena_bounds.y - margin)
	weapons.spawn_orb(arena_bounds, starting_weapon, x, y)
```

In `update()`, replace the `player.update(` call (`:103-116`) with:

```gdscript
	# PORT: web/src/tilt-to-live/TiltGame.ts:1881-1891
	var ship: ProgressionManager.ShipSkinConfig = progression.get_equipped_ship()
	player.update(
		dt,
		mouse_pos,
		bounds,
		particles,
		effective_mode,
		move_vector,
		progression.data.tuning.sensitivity,
		progression.data.tuning.deadzone,
		ship.hitbox_scale,
		ship.turn_rate,
		ship.thruster_color,
		tilt_vector
	)
```

change the ninth argument of `weapons.update` (`:133`) from `perks` to `progression.data.perks` with `# PORT: web/src/tilt-to-live/TiltGame.ts:1926` on the line above it, and insert between the `weapons.update(...)` call and `# 6. Update Scores and Combos`:

```gdscript
	# 5.5 Update Coin Pickups (own spawn timer, independent of weapon orbs)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1930-1940 — spec §5.4 step 7
	# TODO(M11): the game-over summary reads coins.coins_collected and
	# coins.points_from_coins (TiltGame.ts:2108-2129).
	var mode_config: GameOptionsManager.ModeConfig = options.get_mode_config(options.settings.mode)
	coins.update(
		dt, player, bounds, particles, audio, mode_config.score_multiplier, progression.add_points_credited
	)
```

`progression.add_points_credited` without parentheses is a `Callable` to that method (Godot 4 method references); it is the `(value) => this.progression.addPointsCredited(value)` lambda at `:1939`. Nothing else in `update()` moves: grid, particles, player, swarm, weapons, **coins**, scores, collisions, HUD signal — spec §5.4 steps 1, 2, 3, 5, 6, 7, 8, 9, 11.

Also update the `player_ship.gd:18-20` header sentence `M7 supplies real values from ProgressionManager; until then callers pass the TypeScript defaults (1.0, 4.0, 1.0, 1.0, #00ddff).` to `RunController passes them from ProgressionManager (data.tuning, get_equipped_ship()); the M1/M2 callers passed the TypeScript defaults (1.0, 4.0, 1.0, 1.0, #00ddff).` — a comment-only edit to a file listed as "not modified" for code; note it in the ledger.

- [x] **Step 4: Construct the instances in `game_root.gd`**

After `var settings: ControlSettings = null` (`:37`) add:

```gdscript
## The player's save. PORT: web/src/tilt-to-live/TiltGame.ts:55
var progression: ProgressionManager = null
## Mode and settings. PORT: web/src/tilt-to-live/TiltGame.ts:65
var options: GameOptionsManager = null
```

and `var _coins: CoinSystem = null` beside `_weapons` (`:43`). In `_ready()` (`:58-90`), after `_audio = AudioBank.new()` (`:69`) and before `_run_controller = RunController.new(` add:

```gdscript
	progression = ProgressionManager.new()
	options = GameOptionsManager.new()
	_coins = CoinSystem.new()
```

change the constructor call to `RunController.new(_player, _swarm, _weapons, _particles, _grid, _scores, _audio, progression, options, _coins)` (let `gdformat` wrap it), change `_entity_layer.bind_entities(_player, _swarm, _weapons)` (`:85`) to `_entity_layer.bind_entities(_player, _swarm, _weapons, _coins)`, and after `_grid_layer.bind(_grid)` (`:84`) add:

```gdscript
	# PORT: web/src/tilt-to-live/TiltGame.ts:2280 (showGridlines into the renderer)
	_grid_layer.show_gridlines = options.settings.show_gridlines
```

- [x] **Step 5: Comment-only edits in four files**

`game_state_machine.gd`: `:121` `# TODO(M2): scores.setModeMultiplier(modeConfig.scoreMultiplier).` → `# PORT-NOTE: scores.setModeMultiplier (:1550) and setProgressionMultiplier (:1551)` / `# are ported in run_controller.gd::reset_run, which owns the scores.`; delete `:122`. `:136-137` → `# PORT-NOTE: lives, maxLivesThisRun and setHitboxMultiplier (:1567-1570) are` / `# ported in run_controller.gd::reset_run. TODO(M9): pointsEarnedThisRun.` `:145-146` → `# PORT-NOTE: swarm.setSpeedScale (:1599) and coins.reset() (:1601) are ported` / `# in run_controller.gd::reset_run.`

`input_router.gd:13`: `# TODO(M7): read this from meta/game_options.gd once it exists.` → `# PORT-NOTE: GameOptionsManager.settings.control_scheme persists this for save-shape` / `# fidelity (M7); the live value is ControlSettings.scheme, assigned by GameRoot` / `# (M2.5 spec §4.2, a DIVERGENCE). Nothing reads the persisted copy.`

`grid_layer.gd:13`: `## TODO(M7): gate this on GameOptions.showGridlines.` → `## GameRoot sets show_gridlines from GameOptionsManager.settings.show_gridlines (M7).` `:93`: `# TODO(M7): arena theme override (TiltRenderer.ts:76-80).` → `# TODO(M8): arena theme override (TiltRenderer.ts:76-80) — the catalog is` / `# ProgressionManager.arena_theme_catalog; nothing can equip one before the Armory.`

- [x] **Step 6: Run everything, including the headless boot**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
grep -rn "TODO(M7)" godot/src/ godot/tests/
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR"
git checkout godot/project.godot
ls "$APPDATA/Godot/app_userdata/Peril Point/"
```

Expected: `OK: 40/40 scripts collected, all tests passed.`; format and lint clean; **the `TODO(M7)` grep prints nothing**; the headless boot prints `0`; the `ls` shows `tilt_to_live_settings_v1.json` is **not** created by a boot (no `setMode` or `save` runs) and `tilt_to_live_progression_v3.json` is created only if a coin was collected — record what you see. `test_main_scene.gd` instantiates `main.tscn` and so now constructs all three; if it fails on a save-file assumption, add the two `_remove` calls to its `before_each`.

- [x] **Step 7: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/src/sim/run_controller.gd godot/src/core/game_root.gd godot/src/core/game_state_machine.gd godot/src/input/input_router.gd godot/src/render/grid_layer.gd godot/src/sim/player_ship.gd godot/tests/test_run_controller.gd
git commit -m "M7: feed perks, lives, multipliers and coins from the save into the run"
git log -1 --format=%B
```

(Add `godot/tests/test_main_scene.gd` to the `git add` only if Step 6 changed it.)

---

### Task 10: Device pass — unattended half, and the `## M7 — Persistence and economy` section of `VERIFY-ME.md`

**Files:**
- Modify — **append only**: `godot/VERIFY-ME.md` (M2.5, M3, M4 and HUD sections precede this one — never recreate it)
- Build output (gitignored): `godot/build/peril-point-debug.apk`, `godot/build/m7-*.png` if the A55 is present

**Interfaces:**
- Consumes: the `Android` export preset from M0b; `VERIFY-ME.md` §0's build/install commands.
- Produces: evidence lines for `HANDOFF.md`; the hand-held checklist the user runs later.

- [x] **Step 1: Unattended evidence — headless run and APK export**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --quit-after 120 2>&1 | tee godot/build/m7-headless.log | grep -c "SCRIPT ERROR"
"$GODOT" --headless --path godot --export-debug "Android" build/peril-point-debug.apk 2>&1 | tail -5
ls -la godot/build/peril-point-debug.apk
git checkout godot/project.godot
```

Expected: `0`; the export ends without `ERROR` and the APK exists (M4's was 30,335,810 bytes). Record the size.

- [x] **Step 2: Conditional evidence — only if the phone is on adb**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"
"$ADB" devices
```

If `RRCXB04L8EJ` is **not** listed: write `A55 absent from adb on <date>` in the ledger and skip to Step 3. If it **is** listed:

```bash
"$ADB" -s RRCXB04L8EJ install -r godot/build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ logcat -c
"$ADB" -s RRCXB04L8EJ shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1
sleep 3;  "$ADB" -s RRCXB04L8EJ exec-out screencap -p > godot/build/m7-03s.png
sleep 6;  "$ADB" -s RRCXB04L8EJ exec-out screencap -p > godot/build/m7-09s.png
"$ADB" -s RRCXB04L8EJ shell pidof com.jtg.perilpoint
"$ADB" -s RRCXB04L8EJ logcat -d | grep -i "SCRIPT ERROR\|SaveStore\|godot" | head -40
"$ADB" -s RRCXB04L8EJ shell run-as com.jtg.perilpoint ls -la files/
```

Expected: a pid; no `SCRIPT ERROR`; the 3 s screenshot shows a **green shield orb** (the classic ship's starting weapon — M4's was the red nuke) and, by 9 s, an amber coin. The `run-as … ls` lists the `user://` files the app has written so far. Open each PNG with the Read tool and record what is visible.

- [x] **Step 3: Append the M7 section to `godot/VERIFY-ME.md`**

Append (do not edit earlier sections), filling the bracketed lines from Steps 1–2:

```markdown
## M7 — Persistence and economy (device pass, plan Task 10)

Unattended evidence at [sha]: 40/40 GUT scripts pass; headless `--quit-after
120` exits 0 with no script error; the APK exports ([size]).
[Either: "The A55 was still off adb, so no install, launch or screenshot
happened." Or: "Installed and launched; m7-03s.png shows <what>."]
Run §0 first. There is no Armory yet (M8), so nothing can be bought on the
phone; every purchase path is proven headless in `tests/test_progression_*.gd`.
What the phone can show is the save surviving a restart, the corrupt-file
fallback, coins, and the classic ship's shield orb.

- [ ] **Starting orb is a green shield**, not the red nuke M4 showed — the
      classic ship's `startingWeapon` (ProgressionManager.ts:138). If you'd
      rather the first orb stayed a nuke, say so: it is plan Open question 3.
- [ ] **Coins:** an amber disc with a white rim and a dark "S" bar appears
      2.5-4 s in, another every few seconds, never more than six; each fades
      over its last 3 s; flying through one gives a spark burst and a
      pickup sound (silent until M5 — the AudioBank stub logs it).
- [ ] **Coins draw under the orbs** (spec §5.5) — an orb and a coin
      overlapping should show the orb on top.
- [ ] **Saves survive a restart:** collect a few coins, kill the app from
      recents, relaunch, then
      `adb -s RRCXB04L8EJ shell run-as com.jtg.perilpoint cat files/tilt_to_live_progression_v3.json`
      — `"points"` is above 7331 and grows across launches; `"lifetimePoints"`
      matches.
- [ ] **Corrupt save falls back and is backed up:**
      `adb -s RRCXB04L8EJ shell run-as com.jtg.perilpoint sh -c 'echo "{broken" > files/tilt_to_live_progression_v3.json'`
      then relaunch: the game boots (no crash, no black screen), and
      `run-as com.jtg.perilpoint ls files/` shows
      `tilt_to_live_progression_v3.corrupt.json` beside a fresh
      `tilt_to_live_progression_v3.json` after the next coin. Points are back
      to 7331.
- [ ] **Tilt calibration and control scheme still persist** across a
      relaunch (they now go through SaveStore — M2.5's checks 1 and 2 again).
- [ ] Frame time with six coins and a vortex live:
      `adb -s RRCXB04L8EJ shell dumpsys gfxinfo com.jtg.perilpoint | grep -A3 50th`
      — 50th percentile at or under 16 ms.

Not observable yet: perk ranks, extra lives, hull compact, enemy slow and the
two multipliers all read from the save but nothing on the phone can change
them until the Armory (M8). To see them now, edit the JSON with `run-as` and
relaunch — e.g. `"extraLives": 2` gives three lives at the next run.
```

- [x] **Step 4: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/VERIFY-ME.md
git commit -m "M7: record device pass evidence and hand-held persistence checks"
git log -1 --format=%B
```

---

### Task 11: Exit protocol (CONVENTIONS §9)

**Files:**
- Modify: `godot/PORT-PROGRESS.md` (the M7 entry, `:139-141`), `godot/HANDOFF.md` (rewrite), `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md` (module-map row 7, `:73`)

**Interfaces:**
- Consumes: every result actually observed in Tasks 1–10.
- Produces: a handoff a zero-context session can resume from.

- [x] **Step 1: Verify, fresh**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
"$GODOT" --headless --path godot --check-only -s src/meta/progression_manager.gd
"$GODOT" --headless --path godot --check-only -s src/meta/game_options.gd
"$GODOT" --headless --path godot --check-only -s src/meta/save_store.gd
"$GODOT" --headless --path godot --check-only -s src/sim/coin_system.gd
grep -rn "TODO(M7)" godot/src/ godot/tests/
grep -rn "FileAccess.open" godot/src/ | grep -v save_store.gd
grep -rn "DIVERGENCE" godot/src/ | wc -l
git status --short
```

Expected, read from the output and not assumed: `OK: 40/40 scripts collected, all tests passed.`; `gdformat` reports every file unchanged; `gdlint` prints nothing; the four `--check-only` exit 0; the `TODO(M7)` grep prints nothing; the `FileAccess.open` grep prints nothing; the `DIVERGENCE` count equals what it was at Task 1 (M7 adds none — record the number); the working tree is clean.

- [x] **Step 2: Tick `PORT-PROGRESS.md`**

Replace the `- [ ] **M7 — Persistence and economy**` block (`:139-141`) with an entry in the M4 entry's style: date, the Task 10 commit SHA, the plan path, then `ok` lines for: `meta/save_store.gd` (quarantine proven in four specs — store, best score, calibration, control settings); `meta/progression_manager.gd` full port minus the two SVG methods (member table reconciled in Task 6 Step 4, the count written here); the parity fixture `progression.json` (~330 literals) green; the perk cost curve, all five `buy_*` + `upgrade_perk` + the three catalog `buy_*`, and the four multipliers proven headless (spec acceptance line 1); the save round trip through a fresh instance (acceptance line 2); the corrupt fallback with backup (acceptance line 3); `meta/game_options.gd`; `sim/coin_system.gd` at frame-order step 7 with coins drawn under orbs; `RunController` reading lives, hitbox, speed, score/points multipliers and the equipped ship's starting weapon from the save; the collected/passed counts; `gdformat`/`gdlint` clean; `--check-only` on the four files; the unattended device evidence and whether the A55 was present, with a pointer to `VERIFY-ME.md` §M7. If the phone was absent, leave the box **unticked** with `DEVICE PASS PENDING` exactly as M2.5, M3 and M4 did.

- [x] **Step 3: Rewrite `HANDOFF.md`**

For a session with zero context, in the M4 handoff's shape. It must carry: what M7 landed (file by file); the exact verification commands from Step 1 with their observed results (update the `## How to verify right now` block: 40/40 scripts, the new test count, the new `DIVERGENCE` count, and the file count `gdformat` reports); the device evidence or its absence and the `VERIFY-ME.md` §M7 pointer; every Open question below, verbatim, with the ruling taken; the three representation decisions later modules read — **(a)** perks are edited by TS spelling through `upgrade_perk("laser", "crossBeam")` and the keystone key doubles as the `KEYSTONE_COSTS` key, **(b)** `get_*_cost()` returns `Types.ABSENT` for the TS `null`, **(c)** `GameOptionsManager.get_mode_config` takes the mode explicitly — M8's Armory and M9's goals both read these; that `RunController.perks` no longer exists (ranks live on `progression.data.perks`); that the starting orb is now the equipped ship's weapon (shield for classic); the `# TODO(M8)` tags M7 left in `entity_layer.gd` (ship shapes, enemy skins) and `grid_layer.gd` (arena theme) and the `# TODO(M11)` for the game-over coin summary; and the next module. Spec §8 lists **M5** (deps M2), **M8** and **M9** (deps M7) as now open. Recommend M5 or M8 and give the literal first step of each: M5 — "read spec §8 Module 5 and `web/src/tilt-to-live/TiltAudio.ts` in full, then write `docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md`; `audio/audio_bank.gd` is the M2 null-object stub every sim system already calls"; M8 — "read spec §8 Module 8 and `web/src/tilt-to-live/ArmoryUI.ts` (1,293 lines) in full, then write `docs/superpowers/plans/2026-09-20-m8-armory-ui.md`; every purchase it needs is a `ProgressionManager` method proven in `tests/test_progression_economy.gd` and `test_progression_catalogs.gd`, and the `WeaponTuning.ts:56` `freeze.duration.max = 8.2` vs `8.0` discrepancy M4 flagged is the Armory's to display".

- [x] **Step 4: Update the index's module map**

In `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md`, change row 7 (`:73`) to:

```
| 7 | Persistence and economy | M2 | `2026-09-20-m7-persistence-and-economy.md` | **code complete** — device pass pending (`godot/VERIFY-ME.md`) |
```

(or `**done**` if the A55 was present and every `VERIFY-ME.md` §M7 item was ticked by the user — not by the session).

- [x] **Step 5: Commit and stop**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/PORT-PROGRESS.md godot/HANDOFF.md docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md
git commit -m "M7: tick progress and hand off persistence and economy"
git log -1 --format=%B
```

Then **stop**. Report to the user. Do not begin M5 or M8 — CONVENTIONS §9 step 5.

---

## Open questions

Each is recorded rather than resolved (LAW 5). The plan proceeds on the reading marked *recommended*; the executing session must confirm it in `HANDOFF.md` or stop.

1. **`getCursorSvgDataUri` and `getShipSvgPreview` are not ported.** `ProgressionManager.ts:802-939` (138 lines) return SVG markup strings: the first is set as the document's CSS cursor (`TiltGame.ts:2369-2370`), the second is the Armory's `<img>` ship preview. Neither has a consumer in Godot — Android has no pointer, and M8's Armory is a `Control` scene that will draw a preview with `_draw` or a texture. LAW 3 wants every member; M3 and M4 already relocated `render()` bodies out of sim files under spec §4.2/D4. *Recommended:* do not port either; the file header's `PORT-NOTE` names both with their line ranges and a `TODO(M8)`; the member-count reconciliation in Task 6 Step 4 lists them as the two omissions. If the user wants the strings kept as data, they port as two `String`-returning methods with the seven `match` arms each — no design change.

2. **`upgradePerk`/`getWeaponInvestedPoints` index perks by string.** CONVENTIONS §6 forbids `get("prop")`/`set("prop")`. The TS's `(this.data.perks as any)[weapon][perkName]` is exactly the dictionary view the save shape already needs. *Recommended:* route both through `WeaponPerks.to_dict()` and write back through `from_dict()` (Task 5) — no reflection, and the TS key spellings (`"crossBeam"`) are the same strings `KEYSTONE_COSTS` is keyed by, which `getWeaponInvestedPoints(:574)` depends on. The alternative — 21 `match` arms over typed fields — is safer for the type checker but duplicates the field list a third time. M8's Armory calls `upgrade_perk` with the TS spellings; `HANDOFF.md` must say so.

3. **The starting orb changes from nuke to shield.** `run_controller.gd:79` at HEAD spawns `Types.WeaponType.NUKE` because M2 had no equipped ship; `TiltGame.ts:1965` spawns `getEquippedShip().startingWeapon`, and the default ship's is `'shield'` (`ProgressionManager.ts:138`). Porting the line is LAW 3; the visible effect on the phone is that the first orb is green, not red, and the run opens with a 6 s shield instead of a nuke. *Recommended:* port it (Task 9) and let the device pass judge it (`VERIFY-ME.md` §M7 item 1). Reverting is a one-line change and a `# PORT-NOTE` — not a design decision this plan can take.

4. **Retagging the render `TODO(M7)`s to `TODO(M8)`.** `entity_layer.gd:13` (six ship hull shapes, `PlayerShip.ts:359-592`), `:174` (enemy skin colours, `EnemySwarm.ts:1191-1648`) and `grid_layer.gd:93` (arena theme override, `TiltRenderer.ts:76-80`) were tagged M7 in M1/M2 on the assumption that "M7 = skins". Spec §8 M7 lists no render work; M7 delivers the catalogs and the equipped-id getters, and until M8's Armory exists nothing can equip anything but the defaults, so the alternate hulls, skins and arenas are unobservable. *Recommended:* retag to `TODO(M8)` with the catalog getter named in each (Tasks 8, 9), and let the M8 plan decide whether it draws them or hands them to M11. If the user would rather M7 draw them, that is a separate render task (~400 TS lines) on top of this plan.

5. **`GameOptions.controlScheme` versus `ControlSettings.scheme`.** `input_router.gd:13` says "read this from `meta/game_options.gd` once it exists", written before M2.5 gave the scheme its own persisted `ControlSettings` (spec §4.2 DIVERGENCE, `game_root.gd:79-80`). Two sources of truth would be a defect. *Recommended:* `GameOptionsManager` ports `controlScheme` for save-shape fidelity (spec §4.6) but nothing reads it; `ControlSettings` stays the live source; the router's comment becomes a `PORT-NOTE` saying exactly that (Task 9). M11's options modal, which will expose the audio/visual settings, is where the two could be reconciled if the user wants one file.

6. **Where `points_changed` is emitted.** `GameEvents.points_changed(total_points)` exists at `game_events.gd:31` with no emitter. The TS's DOM reach for the points balance is `goalsHUD.render()` after `addPoints` (`TiltGame.ts:205-208`); the Armory re-renders itself after each `buy_*`. *Recommended:* emit from `add_points_credited` only (Task 5) — the one place the TS notifies anything — and let M8's Armory read `data.points` directly after its own purchases, as `ArmoryUI.ts` does. If M8 prefers a signal after purchases too, adding `GameEvents.points_changed.emit(data.points)` to `save()` is one line.

7. **Saving the mode multiplier on `reset_run`.** `TiltGame.ts:1548` calls `options.setMode(mode)` — which saves — before reading the mode config. `RunController.reset_run` takes no mode (`GameStateMachine.reset_run(new_mode)` does, and M10 owns modes). *Recommended:* `RunController` reads `options.settings.mode` and ports `:1549-1551` (Task 9); `setMode` stays with `GameStateMachine`'s existing M10 marker. Consequence: a boot does not create `tilt_to_live_settings_v1.json` until something calls `set_mode` or `save()` — Task 9 Step 6 records what the boot actually writes.

8. **`SteeringTuning.deadzone` as float.** `ProgressionManager.ts:97` types it `number` with the comment `0 .. 16 (default 4)`, and the default JSON writes `4`; the GDScript writes `4.0`. Both parse to the same value on either side (`JSON.parse` and `JSON.parse_string` both give a number), so a web save loads here and vice versa; only the byte text differs. *Recommended:* keep float (it is compared against a float distance at `PlayerShip.ts:166` and set from a slider at `:797`), with the `PORT-NOTE` in Task 3. If byte-identical output matters, `to_dict` can write `int(deadzone)` when it is integral — not done by default (LAW 4).

9. **Non-object JSON is quarantined, not merged.** `ProgressionManager.ts:484-490` would spread a parsed number or array into the defaults and silently produce defaults; spec §6.4 says corrupt saves are moved aside. `SaveStore` treats "parses but is not an object" as corrupt (Task 1). *Recommended:* keep the quarantine — the evidence is worth more than a silent default — and note in `HANDOFF.md` that it is one step stricter than the TS.
