# Module 1 — Core Loop and Input: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Boot Peril Point into a landscape run on a physical Android device where the ship is steerable by tilt and by touch, over a live spring-mass grid, at 60 fps, with the first constant-parity spec green.

**Architecture:** `GameRoot` (Node2D, main scene) owns the subsystems, reproduces `resizeCanvas()` including `arenaScale`, and drives frame-order steps 1–3 (grid, particles, player) in `_physics_process`. `GameStateMachine` holds the phase. Input is a plain `InputRouter` fed by `TouchInput` (screen drag) and `TiltInput` (the `GyroscopeController.ts` port, bridged to `Input.get_gravity()`). Two `Node2D._draw()` layers render: `GridLayer` (background, grid, perimeter) and `EntityLayer` (the player ship). No sim system is an autoload.

**Tech Stack:** Godot 4.7.2-stable (GDScript, non-.NET) · GUT 9.6.1 via `tools/run_tests.sh` · gdtoolkit 4.5.0 · Node 24 (`tools/parity/`) · adb for device verification.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` (§8 Module 1, §4.1, §4.3, §4.4, §5.1, §5.4, §5.5, §6.3)

**Index:** `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md`

**Conventions (binding):** `godot/CONVENTIONS.md`

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

- **Engine:** Godot **4.7.2-stable**, GDScript, standard (non-.NET) build.
- **Godot is not on PATH:**
  `GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`
  Always the `_console` variant.
- **adb is not on PATH:** `ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"`, and **always pass `-s RRCXB04L8EJ`** (the phone appears twice, USB + wireless).
- **Orientation:** landscape. **Target:** Android only through M10 (iOS deferred to M11, D1).
- **`content_scale_mode = disabled`.** The sim reads `get_viewport_rect().size` directly. UI is responsive, never pinned to a base resolution.
- **`max_fps = 60`.** Sim in `_physics_process`; `_process` only calls `queue_redraw()`.
- **`arenaScale = clamp(min(width, height) / 680, 0.60, 1.15)`** — verbatim.
- **`GAME_SPEED = 0.75`** (`web/src/tilt-to-live/TiltGame.ts:35`).
- **Static typing is mandatory and machine-enforced.** Nine GDScript warnings are Error; the engine refuses to run violations. This applies to test scripts too.
- **No sim system may be an autoload or singleton** (spec §5.2). Only `Log` is autoloaded in this module.
- **Signals are sim→UI and sim→audio only. Never sim→sim** (spec §5.3). M1 adds no signals at all.
- **Frame order is fixed** (spec §5.4). M1 implements steps 1, 2, 3 only. No later module may reorder them.
- **Tests:** only via `tools/run_tests.sh`. Never `gut_cmdln.gd` directly.
- **Lint/format:** `gdlint godot/src godot/tests` and `gdformat --check godot/src godot/tests` must be clean before the module is done. Never run either against `godot/addons/`.
- **Commits:** one line, imperative, ≤72 chars, no trailers, prefixed `M1:`.

---

## Open questions — resolve with the user BEFORE Task 1

These are Law 5 stops found while writing this plan. Two change code; three are recorded so no later module re-discovers them.

> **The three blocking questions were put to the user and resolved on 2026-09-20. The resolutions are inline below and are binding. Do not re-ask them, and do not re-litigate them mid-task.**

**Q1 (blocking, changes Task 4 and Task 10) — physics tick rate.**
`TiltGame.loop()` substeps the sim at **1/120 s** and passes `fixedDt * GAME_SPEED` to `update()` (`TiltGame.ts:1844-1848`). Spec §4.3 says `_physics_process` **at 60 Hz**. These are not equivalent: `VectorGrid.update()` **ignores its `dt`** (`VectorGrid.ts:45`) and integrates once per *call*, so at 60 Hz the grid springs back at exactly half the web game's rate. `PlayerShip`'s acceleration smoothing (`accelRate / 200`, `PlayerShip.ts:180`) also lands differently per step.
- **Option A (spec as written):** `physics_ticks_per_second = 60`, `update(delta * GAME_SPEED)`. Half-rate grid spring. One `# PORT-NOTE:`.
- **Option B (recommended):** `physics_ticks_per_second = 120`, `max_fps` stays 60 (that is a *render* cap; 120 Hz physics under 60 fps rendering is ordinary in Godot). Exact substep parity with the TS. Costs CPU on the phone, measured in Task 13.
This is a spec amendment either way, so it is the user's call. CONVENTIONS says report a spec conflict rather than resolve it silently.

**RESOLVED 2026-09-20 — Option B, 120 Hz physics.** Set `physics/common/physics_ticks_per_second=120` in `project.godot` (Task 10 Step 5). `max_fps` stays 60. Spec §4.3 is amended by this decision; say so in `HANDOFF.md` and in `PORT-PROGRESS.md`.

**Q2 (blocking, changes Task 11) — "the grid reacts to motion".**
Nothing in M1's scope can disturb the grid. `applyExplosion` is only ever called by enemy kills, player death, weapons and the cinematic (`TiltGame.ts:1780,1983,2063,2080`, `WeaponSystem.ts:127,239,265,343,546`, `TiltEntranceCinematic.ts:70`) — all M2+. Player motion never touches the grid in the web game. Also `showGridlines` defaults to **false** (`GameOptions.ts:88`), so the web game does not even draw it by default.
- **Recommended resolution:** M1 draws the grid unconditionally (`# TODO(M7):` gate on `GameOptions.showGridlines` once it exists) so it is observable, ports `apply_explosion` faithfully, and proves the spring behaviour in `test_vector_grid.gd`. The device criterion is then read as *"the grid renders, and settles visibly after a resize/orientation event"* — not *"the player disturbs it"*, which would be invented behaviour (Law 4). Record the reinterpretation in `PORT-PROGRESS.md`.

**RESOLVED 2026-09-20 — take the recommended resolution.** Draw the grid unconditionally with `# TODO(M7):`, port `apply_explosion` faithfully, prove the spring in `test_vector_grid.gd`, and record the reinterpreted device criterion.

**Q3 (blocking, changes Task 13) — how both control schemes get tested in one module.**
`controlScheme` defaults to `'hybrid'` (`GameOptions.ts:80`), under which gyro never engages; only `'gyro'` enables tilt, and under `'gyro'` the touch handler is explicitly skipped (`TiltGame.ts:1280`). The two are mutually exclusive by design and the toggle lives in the options modal (M11) backed by `GameOptions` (M7).
- **Recommended resolution:** two device builds in Task 13 — one with the committed default `HYBRID` (verifies touch), one with a single-line temporary flip to `GYRO` (verifies tilt), reverted before the commit. No debug UI is invented (Law 4).

**RESOLVED 2026-09-20 — two builds.** `control_scheme` ships as `HYBRID`. The `GYRO` flip in Task 13 Step 4 is temporary and must be reverted before Task 14.

**Q4 (non-blocking, recorded) — `TiltRenderer.ts:144` passes a `CursorSkinConfig` where `PlayerShip.render` declares `shipSkin?: ShipSkinConfig`.** Almost certainly a bug in the source. Both are absent in M1 so nothing changes here; flagged for M7/M8. Law 2: do not fix it when those modules land — raise it.

**Q5 (non-blocking, recorded) — gyro calibration persistence.** `GyroscopeController` uses a **fourth** localStorage key, `tilt_gyro_calibration` (`GyroscopeController.ts:39`), which spec §2.2 does not list among the three. M1 writes `user://tilt_gyro_calibration.json` with the identical `{beta, gamma}` shape via `FileAccess`, with `# TODO(M7): route through SaveStore`. Add the fourth key to spec §2.2/§4.6 when M7 lands.

---

## File Structure

| File | Responsibility | Ports |
|---|---|---|
| `godot/src/core/log.gd` | leveled logging; the only sanctioned output path | nothing — spec §7 / CONVENTIONS §6 |
| `godot/src/core/types.gd` | enums + plain-data records | `Types.ts` (139) |
| `godot/src/core/tuning.gd` | weapon tuning table, `get_tuned_value`, `GAME_SPEED` | `WeaponTuning.ts` (87) + `TiltGame.ts:35` per spec §4.3 |
| `godot/src/sim/vector_grid.gd` | spring-mass mesh | `VectorGrid.ts` (118) |
| `godot/src/sim/particle_engine.gd` | pooled particles — **partial**, only what `PlayerShip` calls | `ParticleEngine.ts` (235), completed in M2 |
| `godot/src/sim/player_ship.gd` | inertia ship physics | `PlayerShip.ts:1-269` (update half) |
| `godot/src/input/tilt_input.gd` | accelerometer tilt + calibration | `GyroscopeController.ts` (190) |
| `godot/src/input/touch_input.gd` | screen drag → pointer position | `TiltGame.ts:1253-1285` per spec §5.1 |
| `godot/src/input/input_router.gd` | movement vector, key direction, control-scheme resolution | `TiltGame.ts:1869-1878, 2388-2417` per spec §5.1 |
| `godot/src/core/game_state_machine.gd` | phase transitions | `TiltGame.ts:1472-1642` per spec §5.1 |
| `godot/src/core/game_root.gd` | subsystem ownership, resize, frame order | `TiltGame.ts:1822-1891, 2259-2318, 2419-2439` per spec §5.1 |
| `godot/src/render/grid_layer.gd` | background, grid, perimeter | `VectorGrid.ts:86-117` + `TiltRenderer.ts:59-127` per spec §4.2/D4 |
| `godot/src/render/entity_layer.gd` | the player ship | `PlayerShip.ts:271-632` per spec §4.2/D4 |
| `godot/scenes/main.tscn` | **replaces** the M0b placeholder | — |
| `tools/parity/dump_constants.mjs` | TS constant tables → JSON fixtures | spec §6.3 Tier 2 |
| `godot/tests/fixtures/*.json` | generated, committed | — |
| `godot/tests/test_*.gd` | GUT specs | — |

`godot/src/**/.gitkeep` files are deleted as each directory gains a real file.

---

## Task 1: `Log` autoload

**Files:**
- Create: `godot/src/core/log.gd`
- Modify: `godot/project.godot` (`[autoload]`)
- Test: `godot/tests/test_log.gd`
- Delete: `godot/src/core/.gitkeep`

**Interfaces:**
- Consumes: nothing.
- Produces: autoload `Log` with `Log.debug(msg: String) -> void`, `Log.info(msg: String) -> void`, `Log.warn(msg: String) -> void`, `Log.error(msg: String) -> void`, `Log.min_level: Log.Level`, `enum Level { DEBUG, INFO, WARN, ERROR }`. Every later file uses these instead of `print()`.

- [x] **Step 1: Write the failing test**

`godot/tests/test_log.gd`:

```gdscript
## test_log.gd
## PORTS: nothing — new file, covers src/core/log.gd
extends GutTest
## Proves the Log autoload resolves and filters by level.


func test_log_autoload_is_reachable() -> void:
	assert_not_null(Log, "Log autoload must be registered in project.godot")


func test_levels_are_ordered() -> void:
	assert_true(Log.Level.DEBUG < Log.Level.INFO, "DEBUG sorts below INFO")
	assert_true(Log.Level.WARN < Log.Level.ERROR, "WARN sorts below ERROR")


func test_min_level_suppresses_lower_levels() -> void:
	var restore: Log.Level = Log.min_level
	Log.min_level = Log.Level.WARN
	assert_false(Log.is_enabled(Log.Level.INFO), "INFO is below the WARN floor")
	assert_true(Log.is_enabled(Log.Level.ERROR), "ERROR is at or above the WARN floor")
	Log.min_level = restore
```

- [x] **Step 2: Run it and watch it fail**

```bash
tools/run_tests.sh
```
Expected: FAIL — `collected 1 of 2 test scripts` (the new script cannot parse: `Log` does not exist yet).

- [x] **Step 3: Write `godot/src/core/log.gd`**

```gdscript
## log.gd
## PORTS: nothing — new file per spec §7; CONVENTIONS §6 bans bare print()
extends Node
## Leveled logging. Autoloaded as `Log`; the only sanctioned output path in
## this project. Not a simulation system, so autoloading it is permitted
## (spec §5.2 constrains sim systems only).

## Severity floor. Messages below `min_level` are dropped.
enum Level { DEBUG, INFO, WARN, ERROR }

## Messages below this level are not emitted.
var min_level: Level = Level.DEBUG

## True when a message at `level` would be emitted.
func is_enabled(level: Level) -> bool:
	return level >= min_level


## Verbose developer detail.
func debug(msg: String) -> void:
	if is_enabled(Level.DEBUG):
		_emit("DEBUG", msg)


## Ordinary lifecycle information.
func info(msg: String) -> void:
	if is_enabled(Level.INFO):
		_emit("INFO", msg)


## A recoverable problem worth seeing in logcat.
func warn(msg: String) -> void:
	if is_enabled(Level.WARN):
		_emit("WARN", msg)
		push_warning(msg)


## A failure. Never silently swallowed.
func error(msg: String) -> void:
	if is_enabled(Level.ERROR):
		_emit("ERROR", msg)
		push_error(msg)


# PORT-NOTE: this is the single sanctioned print() in the project. CONVENTIONS
# §6 bans bare print() everywhere else; the ban needs one sink.
func _emit(tag: String, msg: String) -> void:
	print("[%s] %s" % [tag, msg])
```

- [x] **Step 4: Register the autoload**

Add to `godot/project.godot` (alphabetical section placement; put it after `[application]`):

```ini
[autoload]

Log="*res://src/core/log.gd"
```

- [x] **Step 5: Verify**

```bash
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s src/core/log.gd   # expect exit 0
tools/run_tests.sh                                                 # expect OK: 2/2
gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
```
Expected: `OK: 2/2 scripts collected, all tests passed.`

> If `Log` collides with the global `log()` function, the parse error will say so. Fall back to autoload name `Logger` and update every reference in later tasks — record the change in `HANDOFF.md`.

- [x] **Step 6: Commit**

```bash
git add godot/src/core/log.gd godot/tests/test_log.gd godot/project.godot
git rm --cached godot/src/core/.gitkeep 2>/dev/null; rm -f godot/src/core/.gitkeep
git add -A godot/src/core
git commit -m "M1: add the Log autoload so no ported file needs bare print"
```

---

## Task 2: `core/types.gd` — port `Types.ts`

**Files:**
- Create: `godot/src/core/types.gd`
- Test: `godot/tests/test_types.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name Types` carrying enums `GamePhase`, `GameMode`, `WeaponType`, `EnemyType`, `EnemyState`, `ControlMode`, `ControlScheme`, `MoveDirection`, and inner record classes `Types.WeaponOrb`, `Types.ActiveWeapon`, `Types.HomingMissile`, `Types.LightningArc`, `Types.Enemy`, `Types.FloatingText`, `Types.GameStats`. **Every later module in the port uses these names**, so `Array[Types.Enemy]` must be proven to compile here.

- [x] **Step 1: Write the failing test — including the typed-array spike**

`godot/tests/test_types.gd`:

```gdscript
## test_types.gd
## PORTS: nothing — new file, covers src/core/types.gd
extends GutTest
## Covers the enum shapes and proves typed arrays of inner record classes
## compile, which every later module depends on.


func test_enum_members_match_the_typescript_unions() -> void:
	assert_eq(Types.GamePhase.size(), 5, "Types.ts:5 lists five phases")
	assert_eq(Types.GameMode.size(), 3, "Types.ts:7 lists three modes")
	assert_eq(Types.WeaponType.size(), 7, "Types.ts:9-16 lists seven weapons")
	assert_eq(Types.EnemyType.size(), 13, "Types.ts:18-31 lists thirteen enemies")


func test_typed_array_of_inner_record_compiles_and_holds() -> void:
	var enemies: Array[Types.Enemy] = []
	var e: Types.Enemy = Types.Enemy.new()
	e.type = Types.EnemyType.SEEKER
	e.radius = 5.0
	enemies.append(e)
	assert_eq(enemies.size(), 1, "typed array of an inner class accepts an element")
	assert_eq(enemies[0].type, Types.EnemyType.SEEKER, "element keeps its typed field")


func test_optional_fields_use_the_absent_sentinel() -> void:
	var e: Types.Enemy = Types.Enemy.new()
	assert_eq(e.state, Types.ABSENT, "state? is absent until a module sets it")
	assert_eq(e.leader_id, Types.ABSENT, "leaderId? is absent until a module sets it")
```

- [x] **Step 2: Run it and watch it fail**

```bash
tools/run_tests.sh
```
Expected: FAIL — `collected 2 of 3 test scripts`.

- [x] **Step 3: Write `godot/src/core/types.gd`**

Member order per CONVENTIONS §2: enums, constants, then inner classes last.

```gdscript
## types.gd
## PORTS: web/src/tilt-to-live/Types.ts (139 lines, source commit 7be9614)
class_name Types
extends RefCounted
## Enumerations and plain-data records shared across the simulation.
##
## PORT-NOTE: Types.ts's `Point2D` and `Velocity2D` (Types.ts:33-41) have no
## port. Godot's built-in Vector2 is their exact equivalent and every call site
## in the TypeScript treats them as one; a one-field-per-axis class would be
## slower and would not interoperate with the engine.
##
## PORT-NOTE: TypeScript optional fields (`targetAngle?`, `state?`, …) have no
## GDScript equivalent. Each is typed and initialised to `Types.ABSENT`, which
## stands for "the TypeScript property is undefined". Consumers must check it
## exactly where the TypeScript checks for undefined.

## Sentinel for a TypeScript optional field that is currently undefined.
const ABSENT: int = -1

## PORT: web/src/tilt-to-live/Types.ts:5
enum GamePhase { MENU, CINEMATIC, PLAYING, PAUSED, GAME_OVER }

## PORT: web/src/tilt-to-live/Types.ts:7
enum GameMode { CLASSIC, CODE_RED, GAUNTLET }

## PORT: web/src/tilt-to-live/Types.ts:9-16
enum WeaponType { NUKE, MISSILES, LIGHTNING, LASER, VORTEX, FREEZE, SHIELD }

## PORT: web/src/tilt-to-live/Types.ts:18-31
enum EnemyType {
	SEEKER,
	ARROW_DRONE,
	WALL_DOT,
	CIRCLE_DOT,
	TURRET_DOT,
	SPIKE_MINE,
	SNAKE_SEGMENT,
	CHARGER,
	ARTILLERY,
	CARRIER,
	BULLET,
	PULSAR,
	SPECTER,
}

## PORT: web/src/tilt-to-live/Types.ts:108
enum EnemyState { AIMING, CHARGING, COOLING, PATROL }

# PORT-NOTE: the next three enums are declared as inline string unions outside
# Types.ts, not inside it. GDScript needs named types and Types.ts is this
# port's enum home (Law 3 keeps one .gd per TS *module*, and these unions are
# not modules). Each carries its true source line.

## PORT: web/src/tilt-to-live/PlayerShip.ts:99
enum ControlMode { MOUSE, KEYBOARD, GYRO }

## PORT: web/src/tilt-to-live/GameOptions.ts:21
enum ControlScheme { HYBRID, MOUSE, KEYBOARD, GYRO }

## PORT: web/src/tilt-to-live/TiltGame.ts:80
enum MoveDirection { UP, DOWN, LEFT, RIGHT }


## PORT: web/src/tilt-to-live/Types.ts:43-52
class WeaponOrb:
	extends RefCounted
	var id: int = 0
	var type: WeaponType = WeaponType.NUKE
	var x: float = 0.0
	var y: float = 0.0
	var radius: float = 0.0
	var spawn_time: float = 0.0
	var lifetime: float = 0.0
	var pulse_offset: float = 0.0


## PORT: web/src/tilt-to-live/Types.ts:54-65
class ActiveWeapon:
	extends RefCounted
	var id: int = 0
	var type: WeaponType = WeaponType.NUKE
	var x: float = 0.0
	var y: float = 0.0
	var duration: float = 0.0
	var max_duration: float = 0.0
	var radius: float = 0.0
	var max_radius: float = 0.0
	var angle: float = 0.0
	# PORT-NOTE: Types.ts:64 types this `any`. Variant is the honest port and
	# CONVENTIONS §4 permits it where the data is genuinely dynamic.
	var data: Variant = null


## PORT: web/src/tilt-to-live/Types.ts:67-76
class HomingMissile:
	extends RefCounted
	var id: int = 0
	var x: float = 0.0
	var y: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	## `null` in Types.ts:73 becomes Types.ABSENT.
	var target_id: int = Types.ABSENT
	var lifetime: float = 0.0
	var smoke_timer: float = 0.0


## PORT: web/src/tilt-to-live/Types.ts:78-85
class LightningArc:
	extends RefCounted
	var x1: float = 0.0
	var y1: float = 0.0
	var x2: float = 0.0
	var y2: float = 0.0
	var intensity: float = 0.0
	var branches: Array[Vector2] = []


## PORT: web/src/tilt-to-live/Types.ts:87-116
class Enemy:
	extends RefCounted
	var id: int = 0
	var type: EnemyType = EnemyType.SEEKER
	var x: float = 0.0
	var y: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	var radius: float = 0.0
	var frozen: bool = false
	var freeze_timer: float = 0.0
	var age: float = 0.0
	var health: float = 0.0
	var target_angle: float = 0.0
	var special_timer: float = 0.0
	var leader_id: int = Types.ABSENT
	var parent_wave_id: int = Types.ABSENT
	var orbit_center: Vector2 = Vector2.ZERO
	var orbit_radius: float = 0.0
	var orbit_speed: float = 0.0
	var chilled: bool = false
	var is_hazard: bool = false
	var state: int = Types.ABSENT
	var aim_angle: float = 0.0
	var aim_timer: float = 0.0
	var fire_cooldown: float = 0.0
	var parent_carrier_id: int = Types.ABSENT
	var orbit_angle: float = 0.0
	var pulse_timer: float = 0.0
	var stealth_opacity: float = 1.0


## PORT: web/src/tilt-to-live/Types.ts:118-128
class FloatingText:
	extends RefCounted
	var id: int = 0
	var text: String = ""
	var x: float = 0.0
	var y: float = 0.0
	var vy: float = 0.0
	# PORT-NOTE: Types.ts:124 types this as a CSS colour string. Godot's Color
	# is the equivalent; conversion happens where the record is constructed.
	var color: Color = Color.WHITE
	var size: float = 0.0
	var alpha: float = 0.0
	var lifetime: float = 0.0


## PORT: web/src/tilt-to-live/Types.ts:130-139
class GameStats:
	extends RefCounted
	var score: int = 0
	var best_score: int = 0
	var multiplier: float = 1.0
	var max_multiplier: float = 1.0
	var kills: int = 0
	var survival_time: float = 0.0
	var best_combo: int = 0
	var close_calls: int = 0
```

- [x] **Step 4: Verify the spike before going further**

```bash
"$GODOT" --headless --path godot --check-only -s src/core/types.gd
tools/run_tests.sh
```
Expected: exit 0 and `OK: 3/3 scripts collected, all tests passed.`

> **If `Array[Types.Enemy]` does not compile**, that reshapes every later module. Stop, do not work around it silently. The fallback is one file per record under `godot/src/core/types/` with real `class_name`s (`Enemy`, `WeaponOrb`, …) and `types.gd` reduced to the enums — a forced split, so record it as an amendment to Law 3 in `CONVENTIONS.md` and in `HANDOFF.md`, then continue.

- [x] **Step 5: Format, lint, commit**

```bash
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add godot/src/core/types.gd godot/tests/test_types.gd
git commit -m "M1: port Types.ts enums and records to core/types.gd"
```

---

## Task 3: `core/tuning.gd` + the parity harness

**Files:**
- Create: `godot/src/core/tuning.gd`
- Create: `tools/parity/dump_constants.mjs`
- Create (generated, committed): `godot/tests/fixtures/weapon_tuning.json`, `godot/tests/fixtures/arena_scale.json`
- Test: `godot/tests/test_tuning_parity.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name Tuning` with `static var WEAPON_TUNING: Dictionary[String, Dictionary]`, `const SUPERNOVA_SHOCKWAVE: float`, `const KEYSTONE_COSTS: Dictionary[String, int]`, `const GAME_SPEED: float`, `static func get_tuned_value(weapon: String, track: String, rank: int) -> float`, inner class `Tuning.TuningEntry` (`base: float`, `per_rank: float`, `max: float`, `unit: TuningUnit`), `enum TuningUnit { RANGE, SECONDS, PERCENT, COUNT }`. M4 reads `get_tuned_value` for every weapon radius/duration; M10 reads `GAME_SPEED`. `arena_scale.json` is consumed by Task 10's spec.

- [ ] **Step 0: Settle the optional-float representation in `core/types.gd`**

Carried over from Task 2 and **assigned to Task 3 by the user on 2026-09-20.**
Do this before the parity work; it is unrelated to tuning but must not rot.

`Types.ts` marks 17 `Enemy` fields optional. Task 2 gave the id-like and
enum-state ones `Types.ABSENT` (-1 is never a real id or ordinal) but gave the
numeric ones their natural zero, because **-1 is a legal angle, timer and
scale**. That loses information `EnemySwarm.ts` actually reads:

| TypeScript | Effect of the `0.0` default |
|---|---|
| `if (e.targetAngle === undefined) e.targetAngle = targetAngle` (`EnemySwarm.ts:300`) | branch never fires |
| `if (e.aimTimer === undefined) e.aimTimer = 1.1` (`:339`) | branch never fires |
| `if (e.fireCooldown === undefined) e.fireCooldown = 2.6 + rand*0.8` (`:394`) | branch never fires |
| `if (sat.orbitRadius === undefined) sat.orbitRadius = 38` (`:463`) | branch never fires |
| `if (e.pulseTimer === undefined) e.pulseTimer = 2.2` (`:486`) | branch never fires |
| `const alpha = e.stealthOpacity ?? 0.65` (`:1517`) | port defaults to `1.0`, not `0.65` |

**Recommended fix:** `NAN` for the float optionals, with `is_nan()` as the
`=== undefined` test — NAN is never a legal reading, so it cannot collide the
way `-1` and `0.0` do. Roughly 12 initialisers in `src/core/types.gd`.

Fields to change in `Types.Enemy`: `target_angle`, `special_timer`,
`orbit_radius`, `orbit_speed`, `aim_angle`, `aim_timer`, `fire_cooldown`,
`orbit_angle`, `pulse_timer`, `stealth_opacity`; and in `Types.ActiveWeapon`:
`max_radius`, `angle` (both optional at `Types.ts:62-63`). Leave `orbit_center`
as `Vector2.ZERO` and the booleans as `false` — `undefined` is falsy in the
TypeScript, so those are already exact.

Extend `tests/test_types.gd` to assert the new sentinel, update the two
`PORT-NOTE` blocks at the top of `types.gd` to describe what the code now does,
then delete the `TODO(M1)` there, and reduce the M3 note in `PORT-PROGRESS.md`
to a plain statement of the representation chosen. Nothing in M1 reads these
fields, so no other task changes.

> If you choose **not** to adopt NAN, that is a real option — but it is then a
> knowing fidelity trade and Law 2 applies: record it in `HANDOFF.md` and move
> the blocker back to M3 rather than leaving it silently half-done.

- [ ] **Step 1: Write the parity dumper**

`tools/parity/dump_constants.mjs`:

```js
// Dumps the TypeScript constant tables to JSON fixtures the GUT specs assert
// against. Spec §6.3 Tier 2: the dominant failure mode in a 13,000-line
// mechanical translation is transcription drift, not bad design.
//
// Run from the repository root:  node tools/parity/dump_constants.mjs
// Node 24 strips the TypeScript types natively; WeaponTuning.ts is
// erasable-syntax-only (interfaces and type aliases, no enums or namespaces).

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  WEAPON_TUNING,
  SUPERNOVA_SHOCKWAVE,
  KEYSTONE_COSTS,
  getTunedValue
} from '../../web/src/tilt-to-live/WeaponTuning.ts';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = resolve(here, '../../godot/tests/fixtures');
mkdirSync(outDir, { recursive: true });

const write = (name, payload) => {
  const file = resolve(outDir, name);
  writeFileSync(file, JSON.stringify(payload, null, 2) + '\n');
  console.log(`wrote ${file}`);
};

// --- WEAPON_TUNING -------------------------------------------------------
const tunedValueSamples = [];
for (const [weapon, tracks] of Object.entries(WEAPON_TUNING)) {
  for (const track of Object.keys(tracks)) {
    for (const rank of [0, 1, 3, 5]) {
      tunedValueSamples.push({ weapon, track, rank, value: getTunedValue(weapon, track, rank) });
    }
  }
}
// getTunedValue returns 0 for an unknown pair (WeaponTuning.ts:63).
tunedValueSamples.push({ weapon: 'nosuch', track: 'nosuch', rank: 2, value: getTunedValue('nosuch', 'nosuch', 2) });

write('weapon_tuning.json', {
  source: 'web/src/tilt-to-live/WeaponTuning.ts',
  generated_by: 'tools/parity/dump_constants.mjs',
  weapon_tuning: WEAPON_TUNING,
  supernova_shockwave: SUPERNOVA_SHOCKWAVE,
  keystone_costs: KEYSTONE_COSTS,
  tuned_value_samples: tunedValueSamples
});

// --- arenaScale ----------------------------------------------------------
// Transcribed from TiltGame.resizeCanvas(), web/src/tilt-to-live/TiltGame.ts:2422-2431.
const arenaScale = (rawW, rawH) => {
  const w = Math.max(320, Math.floor(rawW));
  const h = Math.max(240, Math.floor(rawH));
  const minDim = Math.min(w, h);
  return Math.max(0.6, Math.min(1.15, minDim / 680));
};

write('arena_scale.json', {
  source: 'web/src/tilt-to-live/TiltGame.ts:2422-2431',
  generated_by: 'tools/parity/dump_constants.mjs',
  cases: [
    [100, 100],     // below both floors
    [320, 240],     // exactly the floors
    [640, 360],     // clamps to the 0.60 floor
    [680, 680],     // exactly 1.0
    [1280, 720],    // desktop-ish
    [2340, 1080],   // the Galaxy A55 in landscape
    [3000, 2000]    // clamps to the 1.15 ceiling
  ].map(([width, height]) => ({ width, height, scale: arenaScale(width, height) }))
});
```

- [ ] **Step 2: Run the dumper and read its output**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
node tools/parity/dump_constants.mjs
cat godot/tests/fixtures/weapon_tuning.json | head -30
cat godot/tests/fixtures/arena_scale.json
```
Expected: two `wrote …` lines, and JSON whose `weapon_tuning.blackhole.radius` is `{"base":340,"perRank":18,"max":430,"unit":"range"}`.

> **Contingency** if Node refuses the `.ts` import: compile first and import the `.js`.
> ```bash
> ( cd web && npx tsc src/tilt-to-live/WeaponTuning.ts --outDir ../.tmp-parity --module esnext --target es2022 --moduleResolution bundler )
> ```
> then change the import specifier to `'../../.tmp-parity/WeaponTuning.js'` and add `.tmp-parity/` to the root `.gitignore`. Record which path was used in `HANDOFF.md`.

- [ ] **Step 3: Write the failing parity spec**

`godot/tests/test_tuning_parity.gd`:

```gdscript
## test_tuning_parity.gd
## PORTS: nothing — new file, spec §6.3 Tier 2 constant-parity harness
extends GutTest
## Asserts core/tuning.gd equals the TypeScript table byte for byte, via the
## fixture generated by tools/parity/dump_constants.mjs.

const FIXTURE_PATH: String = "res://tests/fixtures/weapon_tuning.json"

var _fixture: Dictionary = {}


func before_all() -> void:
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	assert_not_null(file, "missing fixture — run: node tools/parity/dump_constants.mjs")
	var raw: String = file.get_as_text()
	file.close()
	# PORT-NOTE: Variant is unavoidable for unvalidated JSON; CONVENTIONS §4
	# permits it here and the next line narrows it immediately.
	var parsed: Variant = JSON.parse_string(raw)
	assert_true(parsed is Dictionary, "fixture must be a JSON object")
	_fixture = parsed


func test_every_weapon_and_track_matches() -> void:
	var expected: Dictionary = _fixture["weapon_tuning"]
	assert_eq(
		Tuning.WEAPON_TUNING.size(), expected.size(), "same number of weapons"
	)
	for weapon: String in expected.keys():
		assert_true(Tuning.WEAPON_TUNING.has(weapon), "tuning.gd is missing %s" % weapon)
		var expected_tracks: Dictionary = expected[weapon]
		var actual_tracks: Dictionary = Tuning.WEAPON_TUNING[weapon]
		assert_eq(actual_tracks.size(), expected_tracks.size(), "%s track count" % weapon)
		for track: String in expected_tracks.keys():
			assert_true(actual_tracks.has(track), "%s.%s is missing" % [weapon, track])
			var want: Dictionary = expected_tracks[track]
			var got: Tuning.TuningEntry = actual_tracks[track]
			assert_almost_eq(got.base, float(want["base"]), 0.0001, "%s.%s base" % [weapon, track])
			assert_almost_eq(
				got.per_rank, float(want["perRank"]), 0.0001, "%s.%s perRank" % [weapon, track]
			)
			assert_almost_eq(got.max, float(want["max"]), 0.0001, "%s.%s max" % [weapon, track])
			assert_eq(
				Tuning.unit_to_string(got.unit), String(want["unit"]), "%s.%s unit" % [weapon, track]
			)


func test_get_tuned_value_matches_every_sample() -> void:
	var samples: Array = _fixture["tuned_value_samples"]
	assert_gt(samples.size(), 0, "fixture carries samples")
	for entry: Variant in samples:
		var sample: Dictionary = entry
		var got: float = Tuning.get_tuned_value(
			String(sample["weapon"]), String(sample["track"]), int(sample["rank"])
		)
		assert_almost_eq(
			got,
			float(sample["value"]),
			0.0001,
			"get_tuned_value(%s, %s, %d)" % [sample["weapon"], sample["track"], sample["rank"]]
		)


func test_scalar_constants_match() -> void:
	assert_almost_eq(
		Tuning.SUPERNOVA_SHOCKWAVE, float(_fixture["supernova_shockwave"]), 0.0001, "shockwave"
	)
	var costs: Dictionary = _fixture["keystone_costs"]
	assert_eq(Tuning.KEYSTONE_COSTS.size(), costs.size(), "keystone count")
	for key: String in costs.keys():
		assert_eq(Tuning.KEYSTONE_COSTS.get(key, -1), int(costs[key]), "keystone %s" % key)
```

- [ ] **Step 4: Run it and watch it fail**

```bash
tools/run_tests.sh
```
Expected: FAIL — `collected 3 of 4 test scripts` (`Tuning` does not exist).

- [ ] **Step 5: Write `godot/src/core/tuning.gd`**

```gdscript
## tuning.gd
## PORTS: web/src/tilt-to-live/WeaponTuning.ts (87 lines, source commit 7be9614)
class_name Tuning
extends RefCounted
## Single source of truth for weapon range/radius/duration constants, plus the
## global simulation speed. WeaponSystem must read get_tuned_value() rather
## than re-declaring its own literals, exactly as WeaponTuning.ts:5-9 requires.

## PORT: web/src/tilt-to-live/WeaponTuning.ts:17
enum TuningUnit { RANGE, SECONDS, PERCENT, COUNT }

# PORT-NOTE: GAME_SPEED is declared in TiltGame.ts:35, not WeaponTuning.ts.
# Spec §4.3 places it here explicitly, so this file carries two sources.
## Global simulation time scale applied only to the fixed-step gameplay delta.
const GAME_SPEED: float = 0.75  # PORT: web/src/tilt-to-live/TiltGame.ts:35

## Blackhole "Supernova Collapse" keystone shockwave radius.
const SUPERNOVA_SHOCKWAVE: float = 320.0  # PORT: web/src/tilt-to-live/WeaponTuning.ts:68

## Keystone perk prices, as ArmoryUI's weaponsCatalog displays them.
## PORT: web/src/tilt-to-live/WeaponTuning.ts:73-87
const KEYSTONE_COSTS: Dictionary[String, int] = {
	"crossBeam": 3500,
	"refractorLance": 4500,
	"falloutZone": 3000,
	"batteringRam": 3000,
	"overchargePulse": 4500,
	"plasmaArc": 3500,
	"superconductor": 4500,
	"shatterCascade": 2500,
	"cryoNova": 4000,
	"clusterSplit": 2500,
	"hyperThrusters": 4000,
	"supernovaCollapse": 5000,
	"chainReaction": 5000,
}

# PORT-NOTE: WeaponTuning.ts:26 types the table `Record<string, Record<string,
# TuningEntry>>`. GDScript does not accept a nested type argument, so the inner
# Dictionary is untyped in the declaration; every value is a TuningEntry.
# It is a `static var` rather than a `const` because TuningEntry.new() is not a
# constant expression.
## weapon → track → TuningEntry. PORT: web/src/tilt-to-live/WeaponTuning.ts:28-58
static var WEAPON_TUNING: Dictionary[String, Dictionary] = {}


static func _static_init() -> void:
	WEAPON_TUNING = {
		"blackhole":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:30
			"radius": TuningEntry.new(340.0, 18.0, 430.0, TuningUnit.RANGE),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:31
			"duration": TuningEntry.new(4.8, 0.5, 7.3, TuningUnit.SECONDS),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:32
			"gravity": TuningEntry.new(0.0, 20.0, 100.0, TuningUnit.PERCENT),
		},
		"nuke":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:35
			"radius": TuningEntry.new(360.0, 22.0, 470.0, TuningUnit.RANGE),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:36
			"speed": TuningEntry.new(0.0, 25.0, 75.0, TuningUnit.PERCENT),
		},
		"shield":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:39
			"duration": TuningEntry.new(6.0, 1.0, 11.0, TuningUnit.SECONDS),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:40
			"radius": TuningEntry.new(20.0, 2.0, 26.0, TuningUnit.RANGE),
		},
		"missiles":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:43
			"count": TuningEntry.new(8.0, 1.0, 13.0, TuningUnit.COUNT),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:44
			"blastRadius": TuningEntry.new(40.0, 6.0, 58.0, TuningUnit.RANGE),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:45
			"flightSpeed": TuningEntry.new(0.0, 20.0, 60.0, TuningUnit.PERCENT),
		},
		"laser":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:48
			"length": TuningEntry.new(260.0, 20.0, 360.0, TuningUnit.RANGE),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:49
			"duration": TuningEntry.new(1.8, 0.4, 3.0, TuningUnit.SECONDS),
		},
		"lightning":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:52
			"maxTargets": TuningEntry.new(14.0, 3.0, 29.0, TuningUnit.COUNT),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:53
			"chainRange": TuningEntry.new(220.0, 22.0, 286.0, TuningUnit.RANGE),
		},
		"freeze":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:56
			"duration": TuningEntry.new(4.5, 0.7, 8.2, TuningUnit.SECONDS),
		},
	}


## base + per_rank * rank for the given weapon/track pair. Returns 0 if unknown.
## PORT: web/src/tilt-to-live/WeaponTuning.ts:61-65
static func get_tuned_value(weapon: String, track: String, rank: int) -> float:
	if not WEAPON_TUNING.has(weapon):
		return 0.0
	var tracks: Dictionary = WEAPON_TUNING[weapon]
	if not tracks.has(track):
		return 0.0
	var entry: TuningEntry = tracks[track]
	return entry.base + entry.per_rank * rank


## The TuningUnit spelling used by the TypeScript, for parity assertions.
static func unit_to_string(unit: TuningUnit) -> String:
	match unit:
		TuningUnit.RANGE:
			return "range"
		TuningUnit.SECONDS:
			return "seconds"
		TuningUnit.PERCENT:
			return "percent"
		TuningUnit.COUNT:
			return "count"
	return ""


## PORT: web/src/tilt-to-live/WeaponTuning.ts:19-24
class TuningEntry:
	extends RefCounted
	var base: float = 0.0
	var per_rank: float = 0.0
	var max: float = 0.0
	var unit: TuningUnit = TuningUnit.RANGE

	func _init(p_base: float, p_per_rank: float, p_max: float, p_unit: TuningUnit) -> void:
		base = p_base
		per_rank = p_per_rank
		max = p_max
		unit = p_unit
```

- [ ] **Step 6: Run the specs green**

```bash
"$GODOT" --headless --path godot --check-only -s src/core/tuning.gd
tools/run_tests.sh
```
Expected: `OK: 4/4 scripts collected, all tests passed.`

> If `const KEYSTONE_COSTS: Dictionary[String, int]` is rejected as a non-constant expression, demote it to `static var` initialised inside `_static_init()` and add a `# PORT-NOTE:` saying why. The spec still passes unchanged.
> If a member named `max` shadows anything, the `SHADOWED_VARIABLE` error will say so; rename to `max_value` **only** if the engine forces it, and note the divergence.

- [ ] **Step 7: Format, lint, commit**

```bash
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add godot/src/core/tuning.gd tools/parity/dump_constants.mjs godot/tests/fixtures godot/tests/test_tuning_parity.gd
git commit -m "M1: port WeaponTuning.ts and add the constant-parity harness"
```

---

## Task 4: `sim/vector_grid.gd` — port `VectorGrid.ts`

**Files:**
- Create: `godot/src/sim/vector_grid.gd`
- Test: `godot/tests/test_vector_grid.gd`
- Delete: `godot/src/sim/.gitkeep`

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name VectorGrid extends RefCounted` with `const SPACING: float`, public `cols: int`, `rows: int`, `points: Array[GridPoint]`, `_init(width: float, height: float)`, `resize(width: float, height: float) -> void`, `update(dt: float) -> void`, `apply_explosion(cx: float, cy: float, force: float, radius: float) -> void`, `apply_implosion(...) -> void`, inner class `VectorGrid.GridPoint` (`x`, `y`, `orig_x`, `orig_y`, `vx`, `vy` — all `float`). `GridLayer` (Task 11) reads `cols`, `rows`, `points`. M2's weapons call `apply_explosion`.

- [ ] **Step 1: Write the failing test**

`godot/tests/test_vector_grid.gd`:

```gdscript
## test_vector_grid.gd
## PORTS: nothing — new file, covers src/sim/vector_grid.gd
extends GutTest
## Covers the point lattice, the spring settle and the explosion impulse.


func test_resize_builds_the_expected_lattice() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	# ceil(360/36) + 1 = 11 columns, ceil(180/36) + 1 = 6 rows — VectorGrid.ts:25-26
	assert_eq(grid.cols, 11, "column count")
	assert_eq(grid.rows, 6, "row count")
	assert_eq(grid.points.size(), 66, "one point per cell")
	assert_almost_eq(grid.points[0].x, 0.0, 0.0001, "first point sits on the origin")
	assert_almost_eq(grid.points[1].x, 36.0, 0.0001, "second point is one spacing over")


func test_update_pulls_a_displaced_point_back_toward_its_origin() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	var p: VectorGrid.GridPoint = grid.points[0]
	p.x = 100.0
	p.y = 0.0
	grid.update(1.0 / 60.0)
	assert_lt(p.x, 100.0, "the spring pulls the point back toward orig_x")
	assert_gt(p.x, 0.0, "one step does not snap it home")


func test_update_settles_a_displaced_point() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	var p: VectorGrid.GridPoint = grid.points[0]
	p.x = 100.0
	for i: int in range(400):
		grid.update(1.0 / 60.0)
	assert_almost_eq(p.x, 0.0, 0.5, "the point settles on its origin")


func test_apply_explosion_pushes_points_outward_within_the_radius() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	var near: VectorGrid.GridPoint = grid.points[1]  # (36, 0)
	var far: VectorGrid.GridPoint = grid.points[10]  # (360, 0)
	grid.apply_explosion(0.0, 0.0, 100.0, 60.0)
	assert_gt(near.vx, 0.0, "a point inside the radius is pushed away from the centre")
	assert_almost_eq(far.vx, 0.0, 0.0001, "a point outside the radius is untouched")


func test_apply_implosion_pulls_points_inward() -> void:
	var grid: VectorGrid = VectorGrid.new(360.0, 180.0)
	var near: VectorGrid.GridPoint = grid.points[1]
	grid.apply_implosion(0.0, 0.0, 100.0, 60.0)
	assert_lt(near.vx, 0.0, "implosion is explosion with a negated force — VectorGrid.ts:83")
```

- [ ] **Step 2: Run it and watch it fail**

```bash
tools/run_tests.sh
```
Expected: FAIL — `collected 4 of 5 test scripts`.

- [ ] **Step 3: Write `godot/src/sim/vector_grid.gd`**

```gdscript
## vector_grid.gd
## PORTS: web/src/tilt-to-live/VectorGrid.ts (118 lines, source commit 7be9614)
class_name VectorGrid
extends RefCounted
## Spring-mass reactive mesh behind the arena.
##
## Instantiated twice concurrently once MenuBackdrop lands (spec §5.2), so it
## must never become an autoload.
##
## PORT-NOTE: VectorGrid.ts:86-117 defines render(); per spec §4.2/D4 that body
## relocates to render/grid_layer.gd, which is why cols/rows/points are public
## here and private in the TypeScript (VectorGrid.ts:16-18).
##
## PORT-NOTE: update() ignores its dt (VectorGrid.ts:45 names the parameter
## `_dt`). The spring integrates once per *call*, not per second, so the settle
## rate is tied to how often the caller ticks. Preserved deliberately — it is
## part of the tuned feel. See the physics-tick decision recorded in HANDOFF.md.

const SPACING: float = 36.0  # PORT: web/src/tilt-to-live/VectorGrid.ts:15
const STIFFNESS: float = 0.08  # PORT: web/src/tilt-to-live/VectorGrid.ts:46
const DAMPING: float = 0.90  # PORT: web/src/tilt-to-live/VectorGrid.ts:47

## Lattice width in points.
var cols: int = 0
## Lattice height in points.
var rows: int = 0
## Row-major lattice: index = row * cols + col.
var points: Array[GridPoint] = []


func _init(width: float, height: float) -> void:
	resize(width, height)


## Rebuilds the lattice for a new viewport size. PORT: VectorGrid.ts:24-43
func resize(width: float, height: float) -> void:
	cols = int(ceil(width / SPACING)) + 1
	rows = int(ceil(height / SPACING)) + 1
	points = []

	for r: int in range(rows):
		for c: int in range(cols):
			var point: GridPoint = GridPoint.new()
			point.x = c * SPACING
			point.y = r * SPACING
			point.orig_x = point.x
			point.orig_y = point.y
			points.append(point)


## Advances the spring one step. PORT: VectorGrid.ts:45-63
@warning_ignore("unused_parameter")
func update(dt: float) -> void:
	for point: GridPoint in points:
		var dx: float = point.orig_x - point.x
		var dy: float = point.orig_y - point.y

		point.vx += dx * STIFFNESS
		point.vy += dy * STIFFNESS

		point.vx *= DAMPING
		point.vy *= DAMPING

		point.x += point.vx
		point.y += point.vy


## Pushes points away from (cx, cy). PORT: VectorGrid.ts:65-80
func apply_explosion(cx: float, cy: float, force: float, radius: float) -> void:
	var r2: float = radius * radius
	for point: GridPoint in points:
		var dx: float = point.x - cx
		var dy: float = point.y - cy
		var dist2: float = dx * dx + dy * dy

		if dist2 < r2 and dist2 > 0.001:  # PORT: VectorGrid.ts:73
			var dist: float = sqrt(dist2)
			var factor: float = (1.0 - dist / radius) * force
			point.vx += (dx / dist) * factor
			point.vy += (dy / dist) * factor


## Explosion with a negated force. PORT: VectorGrid.ts:82-84
func apply_implosion(cx: float, cy: float, force: float, radius: float) -> void:
	apply_explosion(cx, cy, -force, radius)


## PORT: web/src/tilt-to-live/VectorGrid.ts:5-12
class GridPoint:
	extends RefCounted
	var x: float = 0.0
	var y: float = 0.0
	var orig_x: float = 0.0
	var orig_y: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
```

Note the `@warning_ignore("unused_parameter")`: CONVENTIONS §1.1 permits it only alongside a `# PORT-NOTE:`, which the class doc carries.

- [ ] **Step 4: Run the specs green, format, lint, commit**

```bash
"$GODOT" --headless --path godot --check-only -s src/sim/vector_grid.gd
tools/run_tests.sh          # expect OK: 5/5
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
rm -f godot/src/sim/.gitkeep
git add -A godot/src/sim godot/tests/test_vector_grid.gd
git commit -m "M1: port VectorGrid.ts spring-mass mesh to sim/vector_grid.gd"
```

---

## Task 5: `sim/particle_engine.gd` — partial port

Only the surface `PlayerShip.update()` touches. M2 completes the file.

**Files:**
- Create: `godot/src/sim/particle_engine.gd`
- Test: `godot/tests/test_particle_engine.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name ParticleEngine extends RefCounted` with `const MAX_PARTICLES: int`, `particles: Array[Particle]`, `reset() -> void`, `update(dt: float) -> void`, `emit_sparks(x: float, y: float, count: int, color: Color, speed_max: float = 180.0) -> void`, inner class `ParticleEngine.Particle` (`x`, `y`, `vx`, `vy`, `life`, `max_life`, `size`, `decay`, `friction`: `float`; `color`: `Color`; `shape`: `Shape`), `enum Shape { CIRCLE, STREAK, RING, SHARD }`. `PlayerShip.update()` (Task 6) calls `emit_sparks`. M2 adds `emit_explosion`, `emit_smoke`, `emit_ice_shatter`, `emit_blizzard_snow`, `emit_kinetic_ice_shards`, `emit_thruster_sparks` and the draw body.

- [ ] **Step 1: Write the failing test**

`godot/tests/test_particle_engine.gd`:

```gdscript
## test_particle_engine.gd
## PORTS: nothing — new file, covers src/sim/particle_engine.gd
extends GutTest
## Covers the pool cap, the integration step and spark emission.


func test_emit_sparks_appends_the_requested_count() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_sparks(10.0, 20.0, 5, Color("#00ddff"))
	assert_eq(engine.particles.size(), 5, "one particle per requested spark")
	assert_almost_eq(engine.particles[0].x, 10.0, 0.0001, "spawns at the requested point")


func test_emit_sparks_respects_the_pool_cap() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_sparks(0.0, 0.0, ParticleEngine.MAX_PARTICLES + 50, Color.WHITE)
	assert_eq(
		engine.particles.size(),
		ParticleEngine.MAX_PARTICLES,
		"the pool never exceeds maxParticles — ParticleEngine.ts:48"
	)


func test_update_moves_particles_and_retires_dead_ones() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_sparks(0.0, 0.0, 3, Color.WHITE)
	engine.update(0.05)
	assert_eq(engine.particles.size(), 3, "live particles survive a short step")
	engine.update(5.0)
	assert_eq(engine.particles.size(), 0, "particles past their life are removed")


func test_reset_empties_the_pool() -> void:
	var engine: ParticleEngine = ParticleEngine.new()
	engine.emit_sparks(0.0, 0.0, 4, Color.WHITE)
	engine.reset()
	assert_eq(engine.particles.size(), 0, "reset clears every particle")
```

- [ ] **Step 2: Run it and watch it fail** — `tools/run_tests.sh`, expect `collected 5 of 6`.

- [ ] **Step 3: Write `godot/src/sim/particle_engine.gd`**

```gdscript
## particle_engine.gd
## PORTS: web/src/tilt-to-live/ParticleEngine.ts (235 lines, source commit 7be9614)
class_name ParticleEngine
extends RefCounted
## Pooled vector particles.
##
## PORT-NOTE: partial port. M1 needs only what PlayerShip.update() calls
## (ParticleEngine.ts:243-257), so this file carries reset(), update() and
## emit_sparks() alone. The remaining emitters and the draw body are M2's, per
## spec §8 Module 2. The members present are in TypeScript source order so the
## completed file still diffs side by side (Law 3).
##
## Instantiated twice concurrently once MenuBackdrop lands (spec §5.2).

## PORT: web/src/tilt-to-live/ParticleEngine.ts:14
enum Shape { CIRCLE, STREAK, RING, SHARD }

const MAX_PARTICLES: int = 900  # PORT: web/src/tilt-to-live/ParticleEngine.ts:21

# PORT-NOTE: private in ParticleEngine.ts:20; public here because
# ParticleEngine.render() relocates to render/effect_layer.gd (spec §4.2/D4).
## Live particles, oldest first.
var particles: Array[Particle] = []


## Empties the pool. PORT: ParticleEngine.ts:23-25
func reset() -> void:
	particles = []


## Integrates and retires particles. PORT: ParticleEngine.ts:27-44
func update(dt: float) -> void:
	for i: int in range(particles.size() - 1, -1, -1):
		var p: Particle = particles[i]
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.vx *= p.friction
		p.vy *= p.friction
		p.life -= dt

		if p.shape == Shape.RING:
			p.size += 220.0 * dt  # PORT: ParticleEngine.ts:37

		if p.life <= 0.0:
			particles.remove_at(i)


## Emits omnidirectional sparks. PORT: ParticleEngine.ts:46-67
func emit_sparks(x: float, y: float, count: int, color: Color, speed_max: float = 180.0) -> void:
	for i: int in range(count):
		if particles.size() >= MAX_PARTICLES:
			break
		var angle: float = randf() * PI * 2.0
		var speed: float = 20.0 + randf() * speed_max  # PORT: ParticleEngine.ts:50
		var life: float = 0.3 + randf() * 0.45  # PORT: ParticleEngine.ts:51

		var p: Particle = Particle.new()
		p.x = x
		p.y = y
		p.vx = cos(angle) * speed
		p.vy = sin(angle) * speed
		p.life = life
		p.max_life = life
		p.size = 2.0 + randf() * 2.5  # PORT: ParticleEngine.ts:60
		p.color = color
		p.shape = Shape.STREAK if randf() < 0.4 else Shape.CIRCLE  # PORT: ParticleEngine.ts:62
		p.decay = 1.0
		p.friction = 0.94  # PORT: ParticleEngine.ts:64
		particles.append(p)


# TODO(M2): port emit_explosion, emit_smoke, emit_ice_shatter,
# emit_blizzard_snow, emit_kinetic_ice_shards and emit_thruster_sparks
# (ParticleEngine.ts:69-197), and relocate render() (ParticleEngine.ts:199-234)
# into render/effect_layer.gd.


## PORT: web/src/tilt-to-live/ParticleEngine.ts:5-17
class Particle:
	extends RefCounted
	var x: float = 0.0
	var y: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	var life: float = 0.0
	var max_life: float = 0.0
	var size: float = 0.0
	# PORT-NOTE: ParticleEngine.ts:13 types this as a CSS colour string.
	var color: Color = Color.WHITE
	var shape: Shape = Shape.CIRCLE
	var decay: float = 0.0
	var friction: float = 0.0
```

- [ ] **Step 4: Green, format, lint, commit**

```bash
tools/run_tests.sh          # expect OK: 6/6
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add godot/src/sim/particle_engine.gd godot/tests/test_particle_engine.gd
git commit -m "M1: port the ParticleEngine surface PlayerShip needs"
```

---

## Task 6: `sim/player_ship.gd` — port `PlayerShip.ts:1-269`

**Files:**
- Create: `godot/src/sim/player_ship.gd`
- Test: `godot/tests/test_player_ship.gd`

**Interfaces:**
- Consumes: `ParticleEngine` (Task 5), `Types.ControlMode` (Task 2).
- Produces: `class_name PlayerShip extends RefCounted` with public `x`, `y`, `vx`, `vy`, `angle`, `scale`, `shield_timer`, `is_dead`, `close_call_timer`, `trail_history: Array[Vector2]`; read-only properties `radius`, `max_speed`, `acceleration`; `const BASE_MAX_SPEED`, `BASE_ACCELERATION`, `DAMPING`; `_init(start_x: float, start_y: float)`, `reset(x: float, y: float) -> void`, `set_hitbox_multiplier(m: float) -> void`, `set_shield_radius(r: float) -> void`, `set_scale(new_scale: float) -> void`, `activate_shield(duration: float = 6.0) -> void`, `has_shield() -> bool`, and:
  ```gdscript
  func update(
      dt: float, target_mouse: Vector2, bounds: Vector2, particles: ParticleEngine,
      control_mode: Types.ControlMode, move_vector: Vector2, sensitivity: float,
      deadzone: float, hitbox_scale: float, turn_rate: float, thruster_color: Color,
      gyro_vector: Vector2
  ) -> void
  ```
  `EntityLayer` (Task 11) reads `x`, `y`, `angle`, `scale`, `trail_history`, `has_shield()`, `shield_radius`. M2's `run_controller` reads `radius` and `is_dead`.

- [ ] **Step 1: Write the failing test**

`godot/tests/test_player_ship.gd`:

```gdscript
## test_player_ship.gd
## PORTS: nothing — new file, covers src/sim/player_ship.gd
extends GutTest
## Covers the radius formula, scale clamp, the three control modes, angular
## alignment and the boundary bounce.

const BOUNDS: Vector2 = Vector2(1280.0, 720.0)

var _particles: ParticleEngine = null


func before_each() -> void:
	_particles = ParticleEngine.new()


func _step(
	ship: PlayerShip, control_mode: Types.ControlMode, target: Vector2, gyro: Vector2, steps: int
) -> void:
	for i: int in range(steps):
		ship.update(
			1.0 / 120.0,
			target,
			BOUNDS,
			_particles,
			control_mode,
			Vector2.ZERO,
			1.0,
			4.0,
			1.0,
			1.0,
			Color("#00ddff"),
			gyro
		)


func test_radius_is_nine_times_the_scale_chain() -> void:
	var ship: PlayerShip = PlayerShip.new(100.0, 100.0)
	ship.set_scale(1.0)
	assert_almost_eq(ship.radius, 9.0, 0.0001, "PlayerShip.ts:40 — 9 * scale * hitbox * mult")
	ship.set_hitbox_multiplier(0.5)
	assert_almost_eq(ship.radius, 4.5, 0.0001, "the hull-compact multiplier halves it")


func test_set_scale_clamps_to_the_ported_range() -> void:
	var ship: PlayerShip = PlayerShip.new(0.0, 0.0)
	ship.set_scale(0.1)
	assert_almost_eq(ship.scale, 0.5, 0.0001, "floor is 0.5 — PlayerShip.ts:44")
	ship.set_scale(9.0)
	assert_almost_eq(ship.scale, 1.8, 0.0001, "ceiling is 1.8 — PlayerShip.ts:44")


func test_reset_restores_the_initial_pose() -> void:
	var ship: PlayerShip = PlayerShip.new(0.0, 0.0)
	ship.vx = 100.0
	ship.is_dead = true
	ship.reset(50.0, 60.0)
	assert_almost_eq(ship.x, 50.0, 0.0001, "reset places the ship")
	assert_almost_eq(ship.vx, 0.0, 0.0001, "reset clears velocity")
	assert_almost_eq(ship.angle, -PI / 2.0, 0.0001, "reset faces up — PlayerShip.ts:77")
	assert_false(ship.is_dead, "reset revives the ship")


func test_gyro_tilt_drives_the_ship_along_the_tilt_vector() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	_step(ship, Types.ControlMode.GYRO, Vector2(640.0, 360.0), Vector2(1.0, 0.0), 30)
	assert_gt(ship.x, 640.0, "a rightward tilt moves the ship right")
	assert_almost_eq(ship.y, 360.0, 0.5, "a pure-x tilt does not move it vertically")


func test_neutral_gyro_damps_velocity_to_a_standstill() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	ship.vx = 300.0
	_step(ship, Types.ControlMode.GYRO, Vector2(640.0, 360.0), Vector2.ZERO, 200)
	assert_almost_eq(ship.vx, 0.0, 0.0001, "neutral tilt snaps sub-0.5 velocity to zero")


func test_mouse_mode_steers_toward_the_pointer() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	_step(ship, Types.ControlMode.MOUSE, Vector2(900.0, 360.0), Vector2.ZERO, 30)
	assert_gt(ship.x, 640.0, "the ship accelerates toward the pointer")


func test_mouse_inside_the_deadzone_does_not_accelerate() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	_step(ship, Types.ControlMode.MOUSE, Vector2(642.0, 360.0), Vector2.ZERO, 30)
	assert_almost_eq(ship.x, 640.0, 0.0001, "2px < the 4px deadzone — PlayerShip.ts:166")


func test_the_boundary_bounces_the_ship_back_inside() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	ship.set_scale(1.0)
	_step(ship, Types.ControlMode.GYRO, Vector2.ZERO, Vector2(1.0, 0.0), 600)
	var pad: float = ship.radius + 6.0  # PORT: PlayerShip.ts:211
	assert_almost_eq(ship.x, BOUNDS.x - pad, 0.51, "the ship stops at the padded edge")
	assert_lte(ship.vx, 0.0, "the bounce reverses horizontal velocity")


func test_moving_fast_emits_engine_sparks() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	_step(ship, Types.ControlMode.GYRO, Vector2.ZERO, Vector2(1.0, 0.0), 60)
	assert_gt(_particles.particles.size(), 0, "twin engine exhaust fires above 40 px/s")


func test_trail_history_is_capped() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	_step(ship, Types.ControlMode.GYRO, Vector2.ZERO, Vector2(1.0, 0.0), 600)
	assert_lte(ship.trail_history.size(), 14, "trail is capped at 14 — PlayerShip.ts:265")
```

- [ ] **Step 2: Run it and watch it fail** — expect `collected 6 of 7`.

- [ ] **Step 3: Write `godot/src/sim/player_ship.gd`**

```gdscript
## player_ship.gd
## PORTS: web/src/tilt-to-live/PlayerShip.ts:1-269 (633 lines total, source commit 7be9614)
class_name PlayerShip
extends RefCounted
## Tilt/pointer-driven arrow ship with inertia physics.
##
## Instantiated twice concurrently once MenuBackdrop lands (spec §5.2), so it
## must never become an autoload.
##
## PORT-NOTE: PlayerShip.ts:271-632 defines render(); per spec §4.2/D4 that
## body relocates to render/entity_layer.gd.
##
## PORT-NOTE: update() flattens two TypeScript object-literal parameters into
## typed scalars, because GDScript has no anonymous struct type.
## `tuning: {sensitivity, deadzone}` (PlayerShip.ts:101) becomes `sensitivity`
## and `deadzone`; `shipSkin?: ShipSkinConfig` (PlayerShip.ts:102) becomes the
## three fields update() actually reads — `hitbox_scale`, `turn_rate` and
## `thruster_color` (PlayerShip.ts:109-110, 241). M7 supplies real values from
## ProgressionManager; until then callers pass the TypeScript defaults
## (1.0, 4.0, 1.0, 1.0, #00ddff).

const BASE_MAX_SPEED: float = 540.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:52
const BASE_ACCELERATION: float = 1800.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:53
const DAMPING: float = 0.88  # PORT: web/src/tilt-to-live/PlayerShip.ts:54

## Arena-space position.
var x: float = 0.0
var y: float = 0.0
## Velocity in px/sec.
var vx: float = 0.0
var vy: float = 0.0
## Facing, radians. PORT: web/src/tilt-to-live/PlayerShip.ts:14
var angle: float = -PI / 2.0
## Arena scale, driven by resize(). PORT: web/src/tilt-to-live/PlayerShip.ts:15
var scale: float = 1.0
## Seconds of shield remaining.
var shield_timer: float = 0.0
## True between death and the next reset().
var is_dead: bool = false
## Close-call cooldown, read by ScoreManager in M2.
var close_call_timer: float = 0.0
## Most recent positions, newest first, for the wake ribbon.
var trail_history: Array[Vector2] = []

## Collision radius. PORT: web/src/tilt-to-live/PlayerShip.ts:39-41
var radius: float:
	get:
		return 9.0 * scale * _ship_hitbox_scale * _hitbox_multiplier

## Top speed at the current scale. PORT: web/src/tilt-to-live/PlayerShip.ts:56-58
var max_speed: float:
	get:
		return BASE_MAX_SPEED * maxf(0.72, scale)

## Acceleration at the current scale. PORT: web/src/tilt-to-live/PlayerShip.ts:60-62
var acceleration: float:
	get:
		return BASE_ACCELERATION * maxf(0.72, scale)

## Shield bubble radius, read by render/entity_layer.gd.
## PORT: web/src/tilt-to-live/PlayerShip.ts:33
var shield_radius: float = 20.0

var _ship_hitbox_scale: float = 1.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:20
var _ship_turn_rate: float = 1.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:21
var _hitbox_multiplier: float = 1.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:25
var _engine_particle_timer: float = 0.0
var _trail_sample_timer: float = 0.0


func _init(start_x: float, start_y: float) -> void:
	reset(start_x, start_y)


## PORT: web/src/tilt-to-live/PlayerShip.ts:27-29
func set_hitbox_multiplier(m: float) -> void:
	_hitbox_multiplier = m


## PORT: web/src/tilt-to-live/PlayerShip.ts:35-37
func set_shield_radius(r: float) -> void:
	shield_radius = r


## PORT: web/src/tilt-to-live/PlayerShip.ts:43-45
func set_scale(new_scale: float) -> void:
	scale = maxf(0.5, minf(1.8, new_scale))


## PORT: web/src/tilt-to-live/PlayerShip.ts:72-84
func reset(new_x: float, new_y: float) -> void:
	x = new_x
	y = new_y
	vx = 0.0
	vy = 0.0
	angle = -PI / 2.0
	shield_timer = 0.0
	is_dead = false
	close_call_timer = 0.0
	_engine_particle_timer = 0.0
	_trail_sample_timer = 0.0
	trail_history = []


## PORT: web/src/tilt-to-live/PlayerShip.ts:86-88
func activate_shield(duration: float = 6.0) -> void:
	shield_timer = maxf(shield_timer, duration)


## PORT: web/src/tilt-to-live/PlayerShip.ts:90-92
func has_shield() -> bool:
	return shield_timer > 0.0


## Advances one simulation step. PORT: web/src/tilt-to-live/PlayerShip.ts:94-269
func update(
	dt: float,
	target_mouse: Vector2,
	bounds: Vector2,
	particles: ParticleEngine,
	control_mode: Types.ControlMode,
	move_vector: Vector2,
	sensitivity: float,
	deadzone: float,
	hitbox_scale: float,
	turn_rate: float,
	thruster_color: Color,
	gyro_vector: Vector2
) -> void:
	if is_dead:
		return

	_ship_hitbox_scale = hitbox_scale
	_ship_turn_rate = turn_rate

	if shield_timer > 0.0:
		shield_timer -= dt
	if close_call_timer > 0.0:
		close_call_timer -= dt

	var effective_sensitivity: float = sensitivity if sensitivity != 0.0 else 1.0
	var dx: float = target_mouse.x - x
	var dy: float = target_mouse.y - y
	var dist: float = sqrt(dx * dx + dy * dy)

	if control_mode == Types.ControlMode.GYRO:
		var is_tilting: bool = gyro_vector.x != 0.0 or gyro_vector.y != 0.0
		if is_tilting:
			var tilt_mag: float = sqrt(
				gyro_vector.x * gyro_vector.x + gyro_vector.y * gyro_vector.y
			)
			var clamped_mag: float = minf(1.0, tilt_mag)
			var effective_speed: float = max_speed * clamped_mag * effective_sensitivity
			var dir_x: float = gyro_vector.x / tilt_mag
			var dir_y: float = gyro_vector.y / tilt_mag
			var target_vx: float = dir_x * effective_speed
			var target_vy: float = dir_y * effective_speed

			# PORT: web/src/tilt-to-live/PlayerShip.ts:137-139
			var accel_rate: float = acceleration * dt * 1.25
			vx += (target_vx - vx) * minf(1.0, accel_rate / 180.0)
			vy += (target_vy - vy) * minf(1.0, accel_rate / 180.0)
		else:
			# PORT: web/src/tilt-to-live/PlayerShip.ts:142-145
			vx *= pow(DAMPING, dt * 60.0)
			vy *= pow(DAMPING, dt * 60.0)
			if absf(vx) < 0.5:
				vx = 0.0
			if absf(vy) < 0.5:
				vy = 0.0
	elif control_mode == Types.ControlMode.KEYBOARD:
		var is_moving: bool = move_vector.x != 0.0 or move_vector.y != 0.0
		if is_moving:
			var target_vx: float = move_vector.x * max_speed
			var target_vy: float = move_vector.y * max_speed

			# PORT: web/src/tilt-to-live/PlayerShip.ts:154-156
			var accel_rate: float = acceleration * dt
			vx += (target_vx - vx) * minf(1.0, accel_rate / 180.0)
			vy += (target_vy - vy) * minf(1.0, accel_rate / 180.0)
		else:
			# PORT: web/src/tilt-to-live/PlayerShip.ts:159-162
			vx *= pow(DAMPING, dt * 60.0)
			vy *= pow(DAMPING, dt * 60.0)
			if absf(vx) < 0.5:
				vx = 0.0
			if absf(vy) < 0.5:
				vy = 0.0
	else:
		if dist > deadzone:
			var dir_x: float = dx / dist
			var dir_y: float = dy / dist

			# PORT: web/src/tilt-to-live/PlayerShip.ts:171-173
			var effective_reach: float = maxf(40.0, 160.0 / effective_sensitivity)
			var tilt_scale: float = minf(1.0, (dist - deadzone) / effective_reach)
			var target_speed: float = max_speed * tilt_scale

			var target_vx: float = dir_x * target_speed
			var target_vy: float = dir_y * target_speed

			# PORT: web/src/tilt-to-live/PlayerShip.ts:179-181
			var accel_rate: float = acceleration * dt
			vx += (target_vx - vx) * minf(1.0, accel_rate / 200.0)
			vy += (target_vy - vy) * minf(1.0, accel_rate / 200.0)
		else:
			# PORT: web/src/tilt-to-live/PlayerShip.ts:184-185
			vx *= pow(DAMPING, dt * 60.0)
			vy *= pow(DAMPING, dt * 60.0)

	x += vx * dt
	y += vy * dt

	# PORT: web/src/tilt-to-live/PlayerShip.ts:194-202
	var current_speed: float = sqrt(vx * vx + vy * vy)
	var target_angle: float = angle
	if current_speed > 20.0:
		target_angle = atan2(vy, vx)
	elif control_mode == Types.ControlMode.MOUSE and dist > deadzone:
		target_angle = atan2(dy, dx)
	elif control_mode == Types.ControlMode.GYRO and (gyro_vector.x != 0.0 or gyro_vector.y != 0.0):
		target_angle = atan2(gyro_vector.y, gyro_vector.x)

	# PORT: web/src/tilt-to-live/PlayerShip.ts:205-208
	var diff: float = target_angle - angle
	while diff < -PI:
		diff += PI * 2.0
	while diff > PI:
		diff -= PI * 2.0
	angle += diff * minf(1.0, dt * 16.0 * _ship_turn_rate)

	# PORT: web/src/tilt-to-live/PlayerShip.ts:211-226
	var pad: float = radius + 6.0
	if x < pad:
		x = pad
		vx = absf(vx) * 0.4
	elif x > bounds.x - pad:
		x = bounds.x - pad
		vx = -absf(vx) * 0.4

	if y < pad:
		y = pad
		vy = absf(vy) * 0.4
	elif y > bounds.y - pad:
		y = bounds.y - pad
		vy = -absf(vy) * 0.4

	# PORT: web/src/tilt-to-live/PlayerShip.ts:229-258
	_engine_particle_timer += dt
	if _engine_particle_timer > 0.02 and current_speed > 40.0:
		_engine_particle_timer = 0.0
		var back_dist: float = 14.0
		var spread: float = 5.0

		var rear_x: float = x - cos(angle) * back_dist
		var rear_y: float = y - sin(angle) * back_dist

		var norm_x: float = -sin(angle)
		var norm_y: float = cos(angle)

		var flame_col: Color = Color("#00ffee") if has_shield() else thruster_color
		particles.emit_sparks(rear_x + norm_x * spread, rear_y + norm_y * spread, 1, flame_col, 40.0)
		particles.emit_sparks(rear_x - norm_x * spread, rear_y - norm_y * spread, 1, flame_col, 40.0)

	# PORT: web/src/tilt-to-live/PlayerShip.ts:261-268
	_trail_sample_timer += dt
	if _trail_sample_timer > 0.016:
		_trail_sample_timer = 0.0
		trail_history.push_front(Vector2(x, y))
		if trail_history.size() > 14:
			trail_history.pop_back()
```

- [ ] **Step 4: Green, format, lint, commit**

```bash
tools/run_tests.sh          # expect OK: 7/7
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add godot/src/sim/player_ship.gd godot/tests/test_player_ship.gd
git commit -m "M1: port PlayerShip inertia physics to sim/player_ship.gd"
```

---

## Task 7: `input/tilt_input.gd` — port `GyroscopeController.ts` (pure half)

The Godot sensor bridge is Task 12; this task is the fully testable port.

**Files:**
- Create: `godot/src/input/tilt_input.gd`
- Test: `godot/tests/test_tilt_input.gd`
- Delete: `godot/src/input/.gitkeep`

**Interfaces:**
- Consumes: `Log` (Task 1).
- Produces: `class_name TiltInput extends RefCounted` with `enum PermissionState { UNKNOWN, GRANTED, DENIED }`, `const CALIBRATION_PATH: String`, `MAX_TILT_ANGLE`, `DEADZONE_THRESHOLD`, `DEFAULT_CALIBRATED_BETA`; public `is_supported`, `is_listening`, `permission_state`, `calibrated_beta`, `calibrated_gamma`, `tilt_vector: Vector2`; `save_calibration() -> void`, `request_permission_and_start() -> bool`, `start_listening() -> void`, `stop_listening() -> void`, `calibrate_current_position() -> void`, `set_on_calibrated(cb: Callable) -> void`, `has_sensor_data() -> bool`, `apply_orientation(beta: float, gamma: float, screen_angle: int) -> void`. Task 12 adds `poll() -> void`. `GameRoot` (Task 10) reads `tilt_vector`.

- [ ] **Step 1: Write the failing test**

`godot/tests/test_tilt_input.gd`:

```gdscript
## test_tilt_input.gd
## PORTS: nothing — new file, covers src/input/tilt_input.gd
extends GutTest
## Covers the four screen-angle axis mappings, the 24° full-deflection clamp
## and the 7% radial deadzone, all from GyroscopeController.handleOrientation.

var _tilt: TiltInput = null


func before_each() -> void:
	_tilt = TiltInput.new()
	_tilt.calibrated_beta = 0.0
	_tilt.calibrated_gamma = 0.0


func test_default_calibrated_beta_is_the_resting_phone_angle() -> void:
	var fresh: TiltInput = TiltInput.new()
	assert_almost_eq(
		fresh.calibrated_beta, 38.0, 0.0001, "GyroscopeController.ts:18 — ~38° resting tilt"
	)


func test_neutral_orientation_inside_the_deadzone_yields_zero() -> void:
	_tilt.apply_orientation(1.0, 1.0, 90)
	assert_eq(_tilt.tilt_vector, Vector2.ZERO, "1° of 24° is inside the 7% deadzone")


func test_landscape_left_maps_beta_to_x_and_negated_gamma_to_y() -> void:
	_tilt.apply_orientation(24.0, 0.0, 90)
	assert_gt(_tilt.tilt_vector.x, 0.9, "beta drives x at 90° — GyroscopeController.ts:155")
	_tilt.apply_orientation(0.0, 24.0, 90)
	assert_lt(_tilt.tilt_vector.y, -0.9, "gamma is negated at 90° — GyroscopeController.ts:156")


func test_landscape_right_negates_beta_and_keeps_gamma() -> void:
	_tilt.apply_orientation(24.0, 0.0, 270)
	assert_lt(_tilt.tilt_vector.x, -0.9, "beta is negated at 270° — GyroscopeController.ts:159")
	_tilt.apply_orientation(0.0, 24.0, 270)
	assert_gt(_tilt.tilt_vector.y, 0.9, "gamma drives y at 270° — GyroscopeController.ts:160")


func test_portrait_maps_gamma_to_x_and_beta_to_y() -> void:
	_tilt.apply_orientation(0.0, 24.0, 0)
	assert_gt(_tilt.tilt_vector.x, 0.9, "gamma drives x in portrait — GyroscopeController.ts:167")
	_tilt.apply_orientation(24.0, 0.0, 0)
	assert_gt(_tilt.tilt_vector.y, 0.9, "beta drives y in portrait — GyroscopeController.ts:168")


func test_inverted_portrait_negates_both_axes() -> void:
	_tilt.apply_orientation(24.0, 24.0, 180)
	assert_lt(_tilt.tilt_vector.x, 0.0, "both axes negate at 180° — GyroscopeController.ts:163-164")
	assert_lt(_tilt.tilt_vector.y, 0.0, "both axes negate at 180° — GyroscopeController.ts:163-164")


func test_deflection_saturates_beyond_the_max_tilt_angle() -> void:
	_tilt.apply_orientation(90.0, 0.0, 90)
	assert_almost_eq(
		_tilt.tilt_vector.length(), 1.0, 0.0001, "clamped at 24° — GyroscopeController.ts:172-174"
	)


func test_calibration_offsets_the_neutral_pose() -> void:
	_tilt.calibrated_beta = 38.0
	_tilt.apply_orientation(38.0, 0.0, 90)
	assert_eq(_tilt.tilt_vector, Vector2.ZERO, "the calibrated pose reads as neutral")


func test_calibrate_without_sensor_data_falls_back_to_the_default() -> void:
	_tilt.calibrated_beta = 12.0
	_tilt.calibrate_current_position()
	assert_almost_eq(
		_tilt.calibrated_beta, 38.0, 0.0001, "GyroscopeController.ts:115 — comfortable default"
	)
	assert_eq(_tilt.tilt_vector, Vector2.ZERO, "calibrating zeroes the output")


func test_calibration_round_trips_through_the_user_file() -> void:
	_tilt.calibrated_beta = 21.5
	_tilt.calibrated_gamma = -3.25
	_tilt.save_calibration()
	var reloaded: TiltInput = TiltInput.new()
	assert_almost_eq(reloaded.calibrated_beta, 21.5, 0.0001, "beta survives a reload")
	assert_almost_eq(reloaded.calibrated_gamma, -3.25, 0.0001, "gamma survives a reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TiltInput.CALIBRATION_PATH))
```

- [ ] **Step 2: Run it and watch it fail** — expect `collected 7 of 8`.

- [ ] **Step 3: Write `godot/src/input/tilt_input.gd`**

```gdscript
## tilt_input.gd
## PORTS: web/src/tilt-to-live/GyroscopeController.ts (190 lines, source commit 7be9614)
class_name TiltInput
extends RefCounted
## Device tilt steering with a calibrated neutral pose.
##
## PORT-NOTE: the browser delivers `deviceorientation` events carrying beta and
## gamma in degrees. Godot has no such event; the equivalent reading is derived
## from Input.get_gravity() and pushed in by poll() (added in this module's
## Android bridge task). apply_orientation() below is the verbatim body of
## GyroscopeController.handleOrientation (GyroscopeController.ts:133-189) and
## is therefore fully testable headless.

## PORT: web/src/tilt-to-live/GyroscopeController.ts:10
enum PermissionState { UNKNOWN, GRANTED, DENIED }

# PORT-NOTE: GyroscopeController.ts:39 uses the localStorage key
# `tilt_gyro_calibration`, a fourth key spec §2.2 does not list. Same JSON
# shape, written straight to user:// for now.
# TODO(M7): route this through meta/save_store.gd once it exists.
## Where the calibrated neutral pose is persisted.
const CALIBRATION_PATH: String = "user://tilt_gyro_calibration.json"

## Degrees of tilt for full deflection.
const MAX_TILT_ANGLE: float = 24.0  # PORT: web/src/tilt-to-live/GyroscopeController.ts:172
## Radial neutral deadzone for steady resting hands.
const DEADZONE_THRESHOLD: float = 0.07  # PORT: web/src/tilt-to-live/GyroscopeController.ts:178
## Default resting phone tilt.
const DEFAULT_CALIBRATED_BETA: float = 38.0  # PORT: web/src/tilt-to-live/GyroscopeController.ts:18

## True when the platform reports motion sensors.
var is_supported: bool = false
## True while the sensor is being polled.
var is_listening: bool = false
## Motion permission state. Android grants implicitly.
var permission_state: PermissionState = PermissionState.UNKNOWN
## Calibrated neutral front-back angle, degrees.
var calibrated_beta: float = DEFAULT_CALIBRATED_BETA
## Calibrated neutral left-right angle, degrees.
var calibrated_gamma: float = 0.0
## Steering output, normalised to [-1, 1] per axis.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:22
var tilt_vector: Vector2 = Vector2.ZERO

var _raw_beta: float = 0.0
var _raw_gamma: float = 0.0
var _has_received_data: bool = false
var _on_calibrated: Callable = Callable()


func _init() -> void:
	_check_support()
	_load_calibration()


## Persists the calibrated pose. PORT: GyroscopeController.ts:48-55
func save_calibration() -> void:
	var file: FileAccess = FileAccess.open(CALIBRATION_PATH, FileAccess.WRITE)
	if file == null:
		Log.warn("tilt calibration could not be written to %s" % CALIBRATION_PATH)
		return
	file.store_string(JSON.stringify({"beta": calibrated_beta, "gamma": calibrated_gamma}))
	file.close()


## Starts listening. PORT: GyroscopeController.ts:60-91
func request_permission_and_start() -> bool:
	if not is_supported:
		Log.warn("motion sensors are not supported on this platform")
		return false

	# PORT-NOTE: GyroscopeController.ts:66-84 handles iOS 13+ Safari's
	# DeviceOrientationEvent.requestPermission(). Android needs no runtime
	# permission for the accelerometer, so this is the Android branch
	# (GyroscopeController.ts:86-90) alone.
	# TODO(M11): revisit when the iOS export lands (spec D1).
	permission_state = PermissionState.GRANTED
	start_listening()
	return true


## PORT: web/src/tilt-to-live/GyroscopeController.ts:93-97
func start_listening() -> void:
	if is_listening:
		return
	is_listening = true


## PORT: web/src/tilt-to-live/GyroscopeController.ts:99-104
func stop_listening() -> void:
	if not is_listening:
		return
	is_listening = false
	tilt_vector = Vector2.ZERO


## Zeroes the neutral pose at the current attitude.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:109-123
func calibrate_current_position() -> void:
	if _has_received_data:
		calibrated_beta = _raw_beta
		calibrated_gamma = _raw_gamma
	else:
		calibrated_beta = DEFAULT_CALIBRATED_BETA
		calibrated_gamma = 0.0
	save_calibration()
	if _on_calibrated.is_valid():
		_on_calibrated.call(calibrated_beta, calibrated_gamma)
	tilt_vector = Vector2.ZERO


## PORT: web/src/tilt-to-live/GyroscopeController.ts:125-127
func set_on_calibrated(cb: Callable) -> void:
	_on_calibrated = cb


## PORT: web/src/tilt-to-live/GyroscopeController.ts:129-131
func has_sensor_data() -> bool:
	return _has_received_data


## Maps a device attitude to the steering vector.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:133-189
func apply_orientation(beta: float, gamma: float, screen_angle: int) -> void:
	_has_received_data = true
	_raw_beta = beta
	_raw_gamma = gamma

	var roll: float = 0.0
	var pitch: float = 0.0

	if screen_angle == 90:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:154-156 (landscape left)
		roll = beta - calibrated_beta
		pitch = -(gamma - calibrated_gamma)
	elif screen_angle == -90 or screen_angle == 270:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:158-160 (landscape right)
		roll = -(beta - calibrated_beta)
		pitch = gamma - calibrated_gamma
	elif screen_angle == 180:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:162-164 (inverted portrait)
		roll = -(gamma - calibrated_gamma)
		pitch = -(beta - calibrated_beta)
	else:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:166-168 (portrait)
		roll = gamma - calibrated_gamma
		pitch = beta - calibrated_beta

	var vx: float = maxf(-1.0, minf(1.0, roll / MAX_TILT_ANGLE))
	var vy: float = maxf(-1.0, minf(1.0, pitch / MAX_TILT_ANGLE))

	var mag: float = sqrt(vx * vx + vy * vy)

	if mag < DEADZONE_THRESHOLD:
		tilt_vector = Vector2.ZERO
	else:
		# PORT: web/src/tilt-to-live/GyroscopeController.ts:183-187
		var scaled_mag: float = (mag - DEADZONE_THRESHOLD) / (1.0 - DEADZONE_THRESHOLD)
		tilt_vector = Vector2((vx / mag) * scaled_mag, (vy / mag) * scaled_mag)


# PORT-NOTE: GyroscopeController.ts:31-35 probes for DeviceOrientationEvent on
# window. The Godot equivalent is the platform: sensors are Android/iOS only
# (Input.get_gravity() returns Vector3.ZERO everywhere else).
func _check_support() -> void:
	var os_name: String = OS.get_name()
	is_supported = os_name == "Android" or os_name == "iOS"


## PORT: web/src/tilt-to-live/GyroscopeController.ts:37-46
func _load_calibration() -> void:
	if not FileAccess.file_exists(CALIBRATION_PATH):
		return
	var file: FileAccess = FileAccess.open(CALIBRATION_PATH, FileAccess.READ)
	if file == null:
		return
	var raw: String = file.get_as_text()
	file.close()
	# PORT-NOTE: Variant is unavoidable for unvalidated JSON (CONVENTIONS §4).
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		Log.warn("tilt calibration is not a JSON object; keeping defaults")
		return
	var data: Dictionary = parsed
	if data.has("beta"):
		calibrated_beta = float(data["beta"])
	if data.has("gamma"):
		calibrated_gamma = float(data["gamma"])
```

- [ ] **Step 4: Green, format, lint, commit**

```bash
tools/run_tests.sh          # expect OK: 8/8
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
rm -f godot/src/input/.gitkeep
git add -A godot/src/input godot/tests/test_tilt_input.gd
git commit -m "M1: port GyroscopeController tilt mapping and calibration"
```

---

## Task 8: `input/input_router.gd` + `input/touch_input.gd`

**Files:**
- Create: `godot/src/input/input_router.gd`, `godot/src/input/touch_input.gd`
- Test: `godot/tests/test_input_router.gd`

**Interfaces:**
- Consumes: `Types` (Task 2).
- Produces:
  - `class_name InputRouter extends RefCounted` — `control_scheme: Types.ControlScheme`, `control_mode: Types.ControlMode`, `mouse_pos: Vector2`, `has_active_movement_keys() -> bool`, `press_movement_key(dir: Types.MoveDirection) -> void`, `release_movement_key(dir: Types.MoveDirection) -> void`, `clear_movement_keys() -> void`, `get_movement_key_direction(keycode: Key) -> int` (returns a `Types.MoveDirection` or `Types.ABSENT`), `get_movement_vector() -> Vector2`, `resolve_control_mode() -> Types.ControlMode`.
  - `class_name TouchInput extends RefCounted` — `handle_event(event: InputEvent, router: InputRouter) -> void`.
  - `GameRoot` (Task 10) owns one of each; `GameStateMachine` (Task 9) calls `clear_movement_keys()`.

- [ ] **Step 1: Write the failing test**

`godot/tests/test_input_router.gd`:

```gdscript
## test_input_router.gd
## PORTS: nothing — new file, covers src/input/input_router.gd and touch_input.gd
extends GutTest
## Covers the movement vector, key mapping, control-scheme resolution and the
## screen-drag handler.

var _router: InputRouter = null


func before_each() -> void:
	_router = InputRouter.new()


func test_defaults_match_the_typescript() -> void:
	assert_eq(
		_router.control_scheme, Types.ControlScheme.HYBRID, "GameOptions.ts:80 defaults to hybrid"
	)
	assert_eq(_router.control_mode, Types.ControlMode.MOUSE, "TiltGame.ts:79 defaults to mouse")
	assert_eq(_router.mouse_pos, Vector2(400.0, 300.0), "TiltGame.ts:78 seeds the pointer")


func test_movement_vector_is_zero_with_no_keys() -> void:
	assert_eq(_router.get_movement_vector(), Vector2.ZERO, "no keys, no movement")


func test_opposing_keys_cancel() -> void:
	_router.press_movement_key(Types.MoveDirection.LEFT)
	_router.press_movement_key(Types.MoveDirection.RIGHT)
	assert_eq(_router.get_movement_vector(), Vector2.ZERO, "left and right cancel")


func test_diagonals_are_normalised() -> void:
	_router.press_movement_key(Types.MoveDirection.UP)
	_router.press_movement_key(Types.MoveDirection.RIGHT)
	var v: Vector2 = _router.get_movement_vector()
	assert_almost_eq(v.length(), 1.0, 0.0001, "TiltGame.ts:2410-2414 divides by sqrt(2)")
	assert_almost_eq(v.x, 0.70710678, 0.0001, "x component")
	assert_almost_eq(v.y, -0.70710678, 0.0001, "up is negative y")


func test_release_and_clear() -> void:
	_router.press_movement_key(Types.MoveDirection.UP)
	assert_true(_router.has_active_movement_keys(), "a pressed key registers")
	_router.release_movement_key(Types.MoveDirection.UP)
	assert_false(_router.has_active_movement_keys(), "releasing removes it")
	_router.press_movement_key(Types.MoveDirection.DOWN)
	_router.clear_movement_keys()
	assert_false(_router.has_active_movement_keys(), "clear empties the set")


func test_key_direction_mapping() -> void:
	assert_eq(_router.get_movement_key_direction(KEY_W), Types.MoveDirection.UP, "W is up")
	assert_eq(_router.get_movement_key_direction(KEY_UP), Types.MoveDirection.UP, "ArrowUp is up")
	assert_eq(_router.get_movement_key_direction(KEY_KP_8), Types.MoveDirection.UP, "Numpad8 is up")
	assert_eq(_router.get_movement_key_direction(KEY_S), Types.MoveDirection.DOWN, "S is down")
	assert_eq(_router.get_movement_key_direction(KEY_A), Types.MoveDirection.LEFT, "A is left")
	assert_eq(_router.get_movement_key_direction(KEY_D), Types.MoveDirection.RIGHT, "D is right")
	assert_eq(_router.get_movement_key_direction(KEY_Q), Types.ABSENT, "Q is not a movement key")


func test_control_scheme_resolution_pins_each_explicit_scheme() -> void:
	_router.control_mode = Types.ControlMode.MOUSE
	_router.control_scheme = Types.ControlScheme.GYRO
	assert_eq(_router.resolve_control_mode(), Types.ControlMode.GYRO, "TiltGame.ts:1874-1875")
	_router.control_scheme = Types.ControlScheme.KEYBOARD
	assert_eq(_router.resolve_control_mode(), Types.ControlMode.KEYBOARD, "TiltGame.ts:1872-1873")
	_router.control_scheme = Types.ControlScheme.MOUSE
	assert_eq(_router.resolve_control_mode(), Types.ControlMode.MOUSE, "TiltGame.ts:1870-1871")


func test_hybrid_falls_through_to_keyboard_only_while_keys_are_held() -> void:
	_router.control_scheme = Types.ControlScheme.HYBRID
	_router.control_mode = Types.ControlMode.MOUSE
	assert_eq(_router.resolve_control_mode(), Types.ControlMode.MOUSE, "hybrid keeps control_mode")
	_router.press_movement_key(Types.MoveDirection.UP)
	assert_eq(
		_router.resolve_control_mode(), Types.ControlMode.KEYBOARD, "TiltGame.ts:1876-1877"
	)


func test_screen_drag_moves_the_pointer_and_selects_mouse_mode() -> void:
	var touch: TouchInput = TouchInput.new()
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.position = Vector2(123.0, 456.0)
	_router.control_mode = Types.ControlMode.KEYBOARD
	touch.handle_event(drag, _router)
	assert_eq(_router.mouse_pos, Vector2(123.0, 456.0), "the drag sets the pointer")
	assert_eq(_router.control_mode, Types.ControlMode.MOUSE, "TiltGame.ts:1283")


func test_screen_drag_is_ignored_under_the_gyro_scheme() -> void:
	var touch: TouchInput = TouchInput.new()
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.position = Vector2(123.0, 456.0)
	_router.control_scheme = Types.ControlScheme.GYRO
	touch.handle_event(drag, _router)
	assert_eq(_router.mouse_pos, Vector2(400.0, 300.0), "TiltGame.ts:1280 skips gyro")
```

- [ ] **Step 2: Run it and watch it fail** — expect `collected 8 of 9`.

- [ ] **Step 3: Write `godot/src/input/input_router.gd`**

```gdscript
## input_router.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1869-1878 (control-scheme resolution)
## and TiltGame.ts:2388-2417 (movement helpers), per spec §5.1
class_name InputRouter
extends RefCounted
## Resolves which control scheme is driving the ship and turns held movement
## keys into a normalised direction.
##
## Not a signal emitter: input is read by GameRoot each physics tick, exactly
## as TiltGame.update() reads it (spec §5.3 bans sim→sim signals).

## Configured scheme. PORT: web/src/tilt-to-live/GameOptions.ts:80
# TODO(M7): read this from meta/game_options.gd once it exists.
var control_scheme: Types.ControlScheme = Types.ControlScheme.HYBRID

## Last-used input device. PORT: web/src/tilt-to-live/TiltGame.ts:79
var control_mode: Types.ControlMode = Types.ControlMode.MOUSE

## Pointer position in arena space. PORT: web/src/tilt-to-live/TiltGame.ts:78
var mouse_pos: Vector2 = Vector2(400.0, 300.0)

# PORT-NOTE: TiltGame.ts:80 holds a Set<'up'|'down'|'left'|'right'>. GDScript
# has no Set; a typed array with has()/erase() is the closest honest port.
var _active_movement_keys: Array[Types.MoveDirection] = []


## PORT: web/src/tilt-to-live/TiltGame.ts:2388-2390
func has_active_movement_keys() -> bool:
	return _active_movement_keys.size() > 0


## PORT: web/src/tilt-to-live/TiltGame.ts:1297
func press_movement_key(dir: Types.MoveDirection) -> void:
	if not _active_movement_keys.has(dir):
		_active_movement_keys.append(dir)


## PORT: web/src/tilt-to-live/TiltGame.ts:1337-1340
func release_movement_key(dir: Types.MoveDirection) -> void:
	_active_movement_keys.erase(dir)


## PORT: web/src/tilt-to-live/TiltGame.ts:1499
func clear_movement_keys() -> void:
	_active_movement_keys.clear()


## Maps a keycode to a movement direction, or Types.ABSENT.
## PORT: web/src/tilt-to-live/TiltGame.ts:2392-2399
func get_movement_key_direction(keycode: Key) -> int:
	# PORT-NOTE: the TypeScript matches both KeyboardEvent.code and .key, which
	# in the browser is how one handles layout differences. Godot delivers a
	# single physical keycode, so each line collapses to its keycode set.
	if keycode == KEY_W or keycode == KEY_UP or keycode == KEY_KP_8:
		return Types.MoveDirection.UP
	if keycode == KEY_S or keycode == KEY_DOWN or keycode == KEY_KP_2:
		return Types.MoveDirection.DOWN
	if keycode == KEY_A or keycode == KEY_LEFT or keycode == KEY_KP_4:
		return Types.MoveDirection.LEFT
	if keycode == KEY_D or keycode == KEY_RIGHT or keycode == KEY_KP_6:
		return Types.MoveDirection.RIGHT
	return Types.ABSENT


## PORT: web/src/tilt-to-live/TiltGame.ts:2401-2417
func get_movement_vector() -> Vector2:
	var dx: float = 0.0
	var dy: float = 0.0

	if _active_movement_keys.has(Types.MoveDirection.UP):
		dy -= 1.0
	if _active_movement_keys.has(Types.MoveDirection.DOWN):
		dy += 1.0
	if _active_movement_keys.has(Types.MoveDirection.LEFT):
		dx -= 1.0
	if _active_movement_keys.has(Types.MoveDirection.RIGHT):
		dx += 1.0

	if dx != 0.0 and dy != 0.0:
		var inv_len: float = 1.0 / sqrt(2.0)  # PORT: web/src/tilt-to-live/TiltGame.ts:2411
		dx *= inv_len
		dy *= inv_len

	return Vector2(dx, dy)


## Which mode actually drives the ship this frame.
## PORT: web/src/tilt-to-live/TiltGame.ts:1869-1878
func resolve_control_mode() -> Types.ControlMode:
	if control_scheme == Types.ControlScheme.MOUSE:
		return Types.ControlMode.MOUSE
	if control_scheme == Types.ControlScheme.KEYBOARD:
		return Types.ControlMode.KEYBOARD
	if control_scheme == Types.ControlScheme.GYRO:
		return Types.ControlMode.GYRO
	if has_active_movement_keys():
		return Types.ControlMode.KEYBOARD
	return control_mode
```

- [ ] **Step 4: Write `godot/src/input/touch_input.gd`**

```gdscript
## touch_input.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1253-1285 (pointermove and touchmove), per spec §5.1
class_name TouchInput
extends RefCounted
## Turns screen touches into the pointer position the ship steers toward.
##
## PORT-NOTE: TiltGame.ts:1256-1258 rescales client coordinates by the canvas
## backing-store ratio. With content_scale_mode = disabled (spec §4.1) a Godot
## event position is already in the same pixels the sim works in, so there is
## no rescale to port.


## Applies one input event to the router. PORT: TiltGame.ts:1273-1285
func handle_event(event: InputEvent, router: InputRouter) -> void:
	var position: Vector2 = Vector2.ZERO

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		position = drag.position
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if not touch.pressed:
			return
		position = touch.position
	else:
		return

	# PORT: web/src/tilt-to-live/TiltGame.ts:1280
	if router.control_scheme == Types.ControlScheme.GYRO:
		return

	router.mouse_pos = position
	router.control_mode = Types.ControlMode.MOUSE
```

- [ ] **Step 5: Green, format, lint, commit**

```bash
tools/run_tests.sh          # expect OK: 9/9
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add godot/src/input godot/tests/test_input_router.gd
git commit -m "M1: route touch and key input through a plain InputRouter"
```

---

## Task 9: `core/game_state_machine.gd`

**Files:**
- Create: `godot/src/core/game_state_machine.gd`
- Test: `godot/tests/test_game_state_machine.gd`

**Interfaces:**
- Consumes: `Types`, `VectorGrid`, `ParticleEngine`, `PlayerShip`, `InputRouter`, `TiltInput`.
- Produces: `class_name GameStateMachine extends RefCounted` with `phase: Types.GamePhase`, `mode: Types.GameMode`, `elapsed: float`, `_init(player, grid, particles, router, tilt)`, `set_bounds(bounds: Vector2) -> void`, `start() -> void`, `launch_run(new_mode: Types.GameMode) -> void`, `return_to_menu() -> void`, `restart() -> void`, `start_cinematic() -> void`, `stop() -> void`, `reset_run(new_mode: Types.GameMode) -> void`, `toggle_pause() -> void`, `format_time(secs: float) -> String`. `GameRoot` (Task 10) owns one and reads `phase`/`elapsed`.

- [ ] **Step 1: Write the failing test**

`godot/tests/test_game_state_machine.gd`:

```gdscript
## test_game_state_machine.gd
## PORTS: nothing — new file, covers src/core/game_state_machine.gd
extends GutTest
## Covers the menu/playing/paused transitions M1 owns.

const BOUNDS: Vector2 = Vector2(1280.0, 720.0)

var _player: PlayerShip = null
var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _router: InputRouter = null
var _tilt: TiltInput = null
var _machine: GameStateMachine = null


func before_each() -> void:
	_player = PlayerShip.new(0.0, 0.0)
	_grid = VectorGrid.new(BOUNDS.x, BOUNDS.y)
	_particles = ParticleEngine.new()
	_router = InputRouter.new()
	_tilt = TiltInput.new()
	_machine = GameStateMachine.new(_player, _grid, _particles, _router, _tilt)
	_machine.set_bounds(BOUNDS)


func test_start_enters_the_menu() -> void:
	_machine.start()
	assert_eq(_machine.phase, Types.GamePhase.MENU, "TiltGame.ts:1476")


func test_reset_run_centres_the_ship_and_enters_playing() -> void:
	_machine.reset_run(Types.GameMode.CLASSIC)
	assert_eq(_machine.phase, Types.GamePhase.PLAYING, "TiltGame.ts:1562")
	assert_almost_eq(_player.x, 640.0, 0.0001, "TiltGame.ts:1593 centres the ship")
	assert_almost_eq(_player.y, 360.0, 0.0001, "TiltGame.ts:1593 centres the ship")
	assert_eq(_router.mouse_pos, Vector2(640.0, 360.0), "TiltGame.ts:1594")
	assert_eq(_router.control_mode, Types.ControlMode.MOUSE, "TiltGame.ts:1596")
	assert_almost_eq(_machine.elapsed, 0.0, 0.0001, "TiltGame.ts:1564")


func test_reset_run_starts_the_tilt_sensor_only_under_the_gyro_scheme() -> void:
	_router.control_scheme = Types.ControlScheme.GYRO
	_machine.reset_run(Types.GameMode.CLASSIC)
	assert_true(_tilt.is_listening, "TiltGame.ts:1553-1554")
	_router.control_scheme = Types.ControlScheme.HYBRID
	_machine.reset_run(Types.GameMode.CLASSIC)
	assert_false(_tilt.is_listening, "TiltGame.ts:1555-1556")


func test_toggle_pause_round_trips_between_playing_and_paused() -> void:
	_machine.reset_run(Types.GameMode.CLASSIC)
	_machine.toggle_pause()
	assert_eq(_machine.phase, Types.GamePhase.PAUSED, "TiltGame.ts:1621")
	_machine.toggle_pause()
	assert_eq(_machine.phase, Types.GamePhase.PLAYING, "TiltGame.ts:1636")


func test_toggle_pause_does_nothing_in_the_menu() -> void:
	_machine.start()
	_machine.toggle_pause()
	assert_eq(_machine.phase, Types.GamePhase.MENU, "only playing/paused toggle")


func test_return_to_menu_from_a_run_clears_input_and_stops_the_sensor() -> void:
	_router.control_scheme = Types.ControlScheme.GYRO
	_machine.reset_run(Types.GameMode.CLASSIC)
	_router.press_movement_key(Types.MoveDirection.UP)
	_machine.return_to_menu()
	assert_eq(_machine.phase, Types.GamePhase.MENU, "TiltGame.ts:1498")
	assert_false(_router.has_active_movement_keys(), "TiltGame.ts:1499")
	assert_false(_tilt.is_listening, "TiltGame.ts:1500")


func test_return_to_menu_is_a_no_op_when_already_in_the_menu() -> void:
	_machine.start()
	_machine.elapsed = 5.0
	_machine.return_to_menu()
	assert_almost_eq(_machine.elapsed, 5.0, 0.0001, "TiltGame.ts:1497 early-returns")


func test_format_time_pads_seconds() -> void:
	assert_eq(_machine.format_time(65.0), "1:05", "TiltGame.ts:1644-1648")
	assert_eq(_machine.format_time(9.9), "0:09", "TiltGame.ts:1644-1648")
```

- [ ] **Step 2: Run it and watch it fail** — expect `collected 9 of 10`.

- [ ] **Step 3: Write `godot/src/core/game_state_machine.gd`**

```gdscript
## game_state_machine.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1472-1648 (start, launchRun,
## returnToMenu, restart, startCinematic, stop, resetRun, togglePause,
## formatTime), per spec §5.1
class_name GameStateMachine
extends RefCounted
## Owns the game phase and the transitions between menu, playing and paused.
##
## PORT-NOTE: the TypeScript methods also drive the DOM (modals, body classes,
## the menu, the HUD), audio, progression, scores, the swarm, weapons, coins,
## the gauntlet maze, lives and the run tracker. None of those exist yet; each
## omission carries a module-tagged TODO below rather than being dropped
## silently. Nothing that does exist in M1 has been reordered.

## Current phase. PORT: web/src/tilt-to-live/TiltGame.ts:42
var phase: Types.GamePhase = Types.GamePhase.MENU
## Active mode. PORT: web/src/tilt-to-live/GameOptions.ts:79
var mode: Types.GameMode = Types.GameMode.CLASSIC
## Seconds of simulation since the run began. PORT: TiltGame.ts:109
var elapsed: float = 0.0

var _player: PlayerShip = null
var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _router: InputRouter = null
var _tilt: TiltInput = null
var _bounds: Vector2 = Vector2.ZERO
var _is_running: bool = false


func _init(
	player: PlayerShip,
	grid: VectorGrid,
	particles: ParticleEngine,
	router: InputRouter,
	tilt: TiltInput
) -> void:
	_player = player
	_grid = grid
	_particles = particles
	_router = router
	_tilt = tilt


## Keeps the arena size the transitions reset against.
func set_bounds(bounds: Vector2) -> void:
	_bounds = bounds


## PORT: web/src/tilt-to-live/TiltGame.ts:1472-1484
func start() -> void:
	_is_running = true
	phase = Types.GamePhase.MENU
	# TODO(M11): goalsHUD.setMenuMode(true), menu.show(), updateCursor().


## PORT: web/src/tilt-to-live/TiltGame.ts:1486-1494
func launch_run(new_mode: Types.GameMode) -> void:
	mode = new_mode
	# TODO(M11): goalsHUD.setMenuMode(false), menu.hide().
	# TODO(M5): audio.unlock().
	start_cinematic()


## PORT: web/src/tilt-to-live/TiltGame.ts:1496-1517
func return_to_menu() -> void:
	if phase == Types.GamePhase.MENU:
		return
	phase = Types.GamePhase.MENU
	_router.clear_movement_keys()
	_tilt.stop_listening()
	# TODO(M5): audio.stopMusic().
	# TODO(M11): hide the pause and game-over modals, skip the cinematic,
	# goalsHUD.setMenuMode(true), menu.show(), updateCursor().


## PORT: web/src/tilt-to-live/TiltGame.ts:1519-1521
func restart() -> void:
	start_cinematic()


## PORT: web/src/tilt-to-live/TiltGame.ts:1523-1530
func start_cinematic() -> void:
	reset_run(mode)
	# PORT-NOTE: TiltGame.ts:1526 sets phase = 'cinematic' here and
	# TiltEntranceCinematic drives the 600 ms cold open. The cinematic is M11
	# (spec §8), so M1 leaves the phase where reset_run() put it — PLAYING —
	# rather than entering a phase nothing can leave.
	# TODO(M11): set phase = CINEMATIC and start the entrance cinematic.


## PORT: web/src/tilt-to-live/TiltGame.ts:1532-1545
func stop() -> void:
	_is_running = false
	_router.clear_movement_keys()
	_tilt.stop_listening()
	# TODO(M5): audio.stopMusic().
	# TODO(M11): skip the cinematic.


## PORT: web/src/tilt-to-live/TiltGame.ts:1547-1617
func reset_run(new_mode: Types.GameMode) -> void:
	mode = new_mode
	# TODO(M2): scores.setModeMultiplier(modeConfig.scoreMultiplier).
	# TODO(M7): scores.setProgressionMultiplier(progression.getScoreMultiplier()).

	# PORT: web/src/tilt-to-live/TiltGame.ts:1553-1557
	if _router.control_scheme == Types.ControlScheme.GYRO:
		_tilt.start_listening()
	else:
		_tilt.stop_listening()

	phase = Types.GamePhase.PLAYING
	elapsed = 0.0
	# TODO(M7): pointsEarnedThisRun, lives, maxLivesThisRun,
	# player.setHitboxMultiplier(), player.setShieldRadius().
	# TODO(M9): railProgress and the run tracker.

	_player.reset(_bounds.x / 2.0, _bounds.y / 2.0)
	_router.mouse_pos = Vector2(_bounds.x / 2.0, _bounds.y / 2.0)
	_router.clear_movement_keys()
	_router.control_mode = Types.ControlMode.MOUSE

	# TODO(M3): swarm.reset() and swarm.setSpeedScale().
	# TODO(M4): weapons.reset().
	# TODO(M7): coins.reset().
	_particles.reset()
	# TODO(M2): scores.reset().
	# TODO(M10): gauntletMaze.reset().
	_grid.resize(_bounds.x, _bounds.y)
	# TODO(M5): audio.setMuted/setSfxVolume/setMusicVolume.
	# TODO(M2): updateHUD().


## PORT: web/src/tilt-to-live/TiltGame.ts:1619-1642
func toggle_pause() -> void:
	if phase == Types.GamePhase.PLAYING:
		phase = Types.GamePhase.PAUSED
		# TODO(M5): audio.stopMusic().
		# TODO(M11): populate and show the pause modal.
	elif phase == Types.GamePhase.PAUSED:
		phase = Types.GamePhase.PLAYING
		# TODO(M11): hide the pause modal.
		# TODO(M5): audio.startMusic() when music is enabled.


## PORT: web/src/tilt-to-live/TiltGame.ts:1644-1648
func format_time(secs: float) -> String:
	var m: int = int(floor(secs / 60.0))
	var s: int = int(floor(fmod(secs, 60.0)))
	return "%d:%02d" % [m, s]
```

- [ ] **Step 4: Green, format, lint, commit**

```bash
tools/run_tests.sh          # expect OK: 10/10
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add godot/src/core/game_state_machine.gd godot/tests/test_game_state_machine.gd
git commit -m "M1: port the menu, playing and paused phase transitions"
```

---

## Task 10: `core/game_root.gd`, `scenes/main.tscn` and `resizeCanvas()`

**Files:**
- Create: `godot/src/core/game_root.gd`
- Replace: `godot/scenes/main.tscn` (the M0b placeholder)
- Test: `godot/tests/test_arena_scale.gd`
- Modify: `godot/project.godot` if Q1 resolves to 120 Hz physics

**Interfaces:**
- Consumes: everything from Tasks 1–9; `GridLayer`/`EntityLayer` are created in Task 11 — this task adds the nodes and wires them, Task 11 gives them their `_draw()`.
- Produces: `class_name GameRoot extends Node2D` with `static func arena_scale(width: float, height: float) -> float`, `_ready()`, `_physics_process(delta)`, `_process(delta)`, `_input(event)`, `resize_canvas() -> void`. The static `arena_scale` is what the parity spec asserts and what every later module reuses.

- [ ] **Step 1: Write the failing arena-scale parity test**

`godot/tests/test_arena_scale.gd`:

```gdscript
## test_arena_scale.gd
## PORTS: nothing — new file, spec §6.3 Tier 2 parity for the arenaScale formula
extends GutTest
## Asserts GameRoot.arena_scale() equals TiltGame.resizeCanvas() for every
## fixture case generated by tools/parity/dump_constants.mjs.

const FIXTURE_PATH: String = "res://tests/fixtures/arena_scale.json"


func test_arena_scale_matches_the_typescript_for_every_case() -> void:
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	assert_not_null(file, "missing fixture — run: node tools/parity/dump_constants.mjs")
	var raw: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	assert_true(parsed is Dictionary, "fixture must be a JSON object")
	var fixture: Dictionary = parsed
	var cases: Array = fixture["cases"]
	assert_gt(cases.size(), 0, "fixture carries cases")

	for entry: Variant in cases:
		var c: Dictionary = entry
		var got: float = GameRoot.arena_scale(float(c["width"]), float(c["height"]))
		assert_almost_eq(
			got, float(c["scale"]), 0.0001, "arena_scale(%s, %s)" % [c["width"], c["height"]]
		)


func test_the_clamp_bounds_are_the_ported_ones() -> void:
	assert_almost_eq(GameRoot.arena_scale(1.0, 1.0), 0.60, 0.0001, "floor — TiltGame.ts:2431")
	assert_almost_eq(GameRoot.arena_scale(9000.0, 9000.0), 1.15, 0.0001, "ceiling — TiltGame.ts:2431")
```

- [ ] **Step 2: Run it and watch it fail** — expect `collected 10 of 11`.

- [ ] **Step 3: Write `godot/src/core/game_root.gd`**

```gdscript
## game_root.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1822-1853 (loop), 1855-1891
## (update steps 1-3), 2259-2318 (render dispatch) and 2419-2439
## (resizeCanvas), per spec §5.1
class_name GameRoot
extends Node2D
## Owns every subsystem, reproduces resizeCanvas() and drives frame order.
##
## Frame order (spec §5.4) — M1 implements steps 1, 2 and 3 only:
##   1. grid.update(dt)
##   2. particles.update(dt)
##   3. player.update(...) after control-scheme resolution
## Later modules insert their systems at their documented indices. No module
## may reorder an existing step.

@onready var _grid_layer: GridLayer = %GridLayer
@onready var _entity_layer: EntityLayer = %EntityLayer

var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _player: PlayerShip = null
var _router: InputRouter = null
var _touch: TouchInput = null
var _tilt: TiltInput = null
var _state: GameStateMachine = null
var _bounds: Vector2 = Vector2.ZERO


## The arena scale for a viewport. PORT: web/src/tilt-to-live/TiltGame.ts:2422-2431
static func arena_scale(width: float, height: float) -> float:
	var w: float = maxf(320.0, floor(width))  # PORT: web/src/tilt-to-live/TiltGame.ts:2422
	var h: float = maxf(240.0, floor(height))  # PORT: web/src/tilt-to-live/TiltGame.ts:2423
	var min_dim: float = minf(w, h)
	return maxf(0.60, minf(1.15, min_dim / 680.0))  # PORT: TiltGame.ts:2431


func _ready() -> void:
	_bounds = get_viewport_rect().size
	_grid = VectorGrid.new(_bounds.x, _bounds.y)
	_particles = ParticleEngine.new()
	_player = PlayerShip.new(_bounds.x / 2.0, _bounds.y / 2.0)
	_router = InputRouter.new()
	_touch = TouchInput.new()
	_tilt = TiltInput.new()
	_state = GameStateMachine.new(_player, _grid, _particles, _router, _tilt)

	_grid_layer.bind(_grid)
	_entity_layer.bind(_player)

	resize_canvas()
	get_viewport().size_changed.connect(resize_canvas)

	if _tilt.is_supported:
		var started: bool = _tilt.request_permission_and_start()
		Log.info("tilt sensor start requested: %s" % started)

	_state.start()
	# PORT-NOTE: TiltGame.ts:1476 stops at the menu and the menu's Play button
	# calls launchRun(). TiltMenu is M11 (spec §8), so M1 launches immediately;
	# otherwise nothing is steerable and the module cannot be accepted.
	# TODO(M11): remove this and let the menu call launch_run().
	_state.launch_run(Types.GameMode.CLASSIC)
	Log.info("M1 boot: bounds=%s arena_scale=%f" % [_bounds, arena_scale(_bounds.x, _bounds.y)])


func _input(event: InputEvent) -> void:
	_touch.handle_event(event, _router)

	if event is InputEventKey:
		var key_event: InputEventKey = event
		var dir: int = _router.get_movement_key_direction(key_event.keycode)
		if dir == Types.ABSENT:
			return
		# PORT: web/src/tilt-to-live/TiltGame.ts:1296-1299
		if (
			_router.control_scheme != Types.ControlScheme.MOUSE
			and _router.control_scheme != Types.ControlScheme.GYRO
		):
			if key_event.pressed:
				_router.press_movement_key(dir)
				_router.control_mode = Types.ControlMode.KEYBOARD
			else:
				_router.release_movement_key(dir)


func _physics_process(delta: float) -> void:
	# PORT-NOTE: TiltGame.ts:1843-1848 accumulates real time and substeps at
	# 1/120 s, passing fixedDt * GAME_SPEED to update(). Godot's fixed step
	# replaces that accumulator (spec §4.3); the per-step delta still carries
	# GAME_SPEED so the sim advances 25% slower per real second, exactly as the
	# TypeScript does.
	match _state.phase:
		Types.GamePhase.PLAYING:
			_update(delta * Tuning.GAME_SPEED)
		Types.GamePhase.CINEMATIC:
			# PORT: web/src/tilt-to-live/TiltGame.ts:1834-1836
			_grid.update(delta)
			_particles.update(delta)
			# TODO(M11): cinematic.update(dt, width, height).
		Types.GamePhase.MENU:
			# TODO(M11): updateMenuSimulation(dt) — render/menu_backdrop.gd.
			pass
		_:
			pass


func _process(_delta: float) -> void:
	_grid_layer.queue_redraw()
	_entity_layer.queue_redraw()


## Reproduces resizeCanvas(). PORT: web/src/tilt-to-live/TiltGame.ts:2419-2439
func resize_canvas() -> void:
	# PORT-NOTE: TiltGame.ts:2420 and 2425-2426 resize the canvas backing store
	# by devicePixelRatio. Godot owns the framebuffer and content_scale_mode is
	# disabled (spec §4.1), so get_viewport_rect().size is already the pixel
	# size the sim works in and there is nothing to scale.
	_bounds = get_viewport_rect().size
	var scale: float = arena_scale(_bounds.x, _bounds.y)
	_player.set_scale(scale)
	# TODO(M3): swarm.setScale(scale).
	# TODO(M4): weapons.setScale(scale).
	# TODO(M10): gauntletMaze.setScale(scale).
	# TODO(M2): renderer scale — render/render_context.gd.
	_grid.resize(_bounds.x, _bounds.y)
	_state.set_bounds(_bounds)
	_entity_layer.set_elapsed(_state.elapsed)


## Frame order steps 1-3. PORT: web/src/tilt-to-live/TiltGame.ts:1855-1891
func _update(dt: float) -> void:
	_state.elapsed += dt  # PORT: web/src/tilt-to-live/TiltGame.ts:1856

	# 1. Update Grid
	_grid.update(dt)

	# 2. Update Particles
	# PORT-NOTE: particles update before the player here, matching
	# TiltGame.ts:1866. Particles emitted this tick therefore draw unaged.
	# Looks accidental; preserved deliberately — it is part of the tuned feel.
	_particles.update(dt)

	# 3. Update Player Ship with scheme checks
	var effective_mode: Types.ControlMode = _router.resolve_control_mode()
	if effective_mode == Types.ControlMode.GYRO:
		_tilt.poll()

	_player.update(
		dt,
		_router.mouse_pos,
		_bounds,
		_particles,
		effective_mode,
		_router.get_movement_vector(),
		1.0,
		4.0,
		1.0,
		1.0,
		Color("#00ddff"),
		_tilt.tilt_vector
	)
	# TODO(M7): the last five arguments come from progression.data.tuning
	# (sensitivity, deadzone) and progression.getEquippedShip() (hitboxScale,
	# turnRate, thrusterColor). PlayerShip.ts:101-102 defaults are used here.

	# TODO(M10): step 3.5 — gauntletMaze.update() in gauntlet mode.
	# TODO(M3): step 4 — swarm.update().
	# TODO(M4): step 5 — weapons.update().
	# TODO(M7): step 7 — coins.update().
	# TODO(M2): step 8 — scores.update(); step 9 — check_collisions().
	# TODO(M9): step 10 — run-tracker sync and live goal evaluation.
	# TODO(M2): step 11 — HUD signal emission.

	_entity_layer.set_elapsed(_state.elapsed)
```

`_tilt.poll()` does not exist until Task 12 — add the stub there, or temporarily comment the call and restore it in Task 12. Prefer: **do Task 12 before running the project**, and until then the headless specs (which never construct `GameRoot`) stay green.

- [ ] **Step 4: Replace `godot/scenes/main.tscn`**

```bash
cat > godot/scenes/main.tscn <<'TSCN'
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://src/core/game_root.gd" id="1"]
[ext_resource type="Script" path="res://src/render/grid_layer.gd" id="2"]
[ext_resource type="Script" path="res://src/render/entity_layer.gd" id="3"]

[node name="GameRoot" type="Node2D"]
script = ExtResource("1")

[node name="GridLayer" type="Node2D" parent="."]
unique_name_in_owner = true
script = ExtResource("2")

[node name="EntityLayer" type="Node2D" parent="."]
unique_name_in_owner = true
script = ExtResource("3")
TSCN
```

The scene references Task 11's scripts; create the two files there before opening the project. If Godot rewrites this file on first import (uid fields), commit the rewritten version.

- [ ] **Step 5: Apply the Q1 decision — 120 Hz physics**

Add to `godot/project.godot`:

```ini
[physics]

common/physics_ticks_per_second=120
```

Then extend the `# PORT-NOTE:` in `_physics_process` to record that the substep cadence now matches `TiltGame.ts:1844` exactly (1/120 s per step, `GAME_SPEED` applied to the delta), and that this amends spec §4.3's "60 Hz". `max_fps=60` is unchanged — it caps rendering, not physics. Verify the setting took effect:

```bash
"$GODOT" --headless --path godot --check-only -s src/core/game_root.gd
grep -A2 '\[physics\]' godot/project.godot
```

- [ ] **Step 6: Verify and commit**

```bash
tools/run_tests.sh          # expect OK: 11/11
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add godot/src/core/game_root.gd godot/scenes/main.tscn godot/tests/test_arena_scale.gd godot/project.godot
git commit -m "M1: own the frame order and arena scale in core/game_root.gd"
```

---

## Task 11: `render/grid_layer.gd` and `render/entity_layer.gd`

**Files:**
- Create: `godot/src/render/grid_layer.gd`, `godot/src/render/entity_layer.gd`
- Delete: `godot/src/render/.gitkeep`

**Interfaces:**
- Consumes: `VectorGrid`, `PlayerShip`.
- Produces: `class_name GridLayer extends Node2D` with `bind(grid: VectorGrid) -> void`; `class_name EntityLayer extends Node2D` with `bind(player: PlayerShip) -> void` and `set_elapsed(elapsed: float) -> void`. M2 adds `EffectLayer` below `EntityLayer` in the same scene.

- [ ] **Step 1: Write `godot/src/render/grid_layer.gd`**

```gdscript
## grid_layer.gd
## PORTS: web/src/tilt-to-live/VectorGrid.ts:86-117 (render) and
## web/src/tilt-to-live/TiltRenderer.ts:59-127 (arena background, grid tint,
## perimeter), per spec §4.2 and D4
class_name GridLayer
extends Node2D
## Bottom render layer: arena background, the reactive grid, the perimeter.
##
## PORT-NOTE: TiltRenderer.ts:97 draws the grid only when showGridlines is on,
## and GameOptions.ts:88 defaults it to false. M1 has no settings system and
## its acceptance criterion requires an observable grid, so it draws
## unconditionally.
## TODO(M7): gate this on GameOptions.showGridlines.
##
## PORT-NOTE: TiltRenderer.ts:82-92 builds a canvas radial gradient with an
## inner radius of width*0.1 and an outer radius of width*0.8, stops at 0,
## 0.65 and 1. GradientTexture2D has no inner radius, so the same three stops
## are re-expressed against the 0..width*0.8 span: 0.1/0.8 = 0.125 and
## 0.65/0.8 = 0.8125. The painted result is identical.

## PORT: web/src/tilt-to-live/TiltRenderer.ts:60 (classic arena background)
const BG_INNER: Color = Color("#100c1e")
const BG_MID: Color = Color("#090712")
const BG_OUTER: Color = Color("#040308")
## PORT: web/src/tilt-to-live/TiltRenderer.ts:61
const GRID_COLOR: Color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.28)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:62
const BOUNDARY_COLOR: Color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.45)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:125 (the 0.12-alpha outer stroke)
const BOUNDARY_HALO_ALPHA: float = 0.12
const GRADIENT_OUTER_FACTOR: float = 0.8  # PORT: web/src/tilt-to-live/TiltRenderer.ts:88
const INSET: float = 6.0  # PORT: web/src/tilt-to-live/TiltRenderer.ts:123

var _grid: VectorGrid = null
var _background: GradientTexture2D = null


func _ready() -> void:
	_background = _build_background()


## Gives this layer the grid it draws. Called by GameRoot.
func bind(grid: VectorGrid) -> void:
	_grid = grid


func _draw() -> void:
	if _grid == null:
		return
	var size: Vector2 = get_viewport_rect().size

	draw_rect(Rect2(Vector2.ZERO, size), BG_OUTER)
	if _background != null:
		var radius: float = size.x * GRADIENT_OUTER_FACTOR
		var centre: Vector2 = size / 2.0
		draw_texture_rect(
			_background,
			Rect2(centre - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)),
			false
		)

	_draw_grid()

	# PORT: web/src/tilt-to-live/TiltRenderer.ts:120-127
	var frame: Rect2 = Rect2(INSET, INSET, size.x - INSET * 2.0, size.y - INSET * 2.0)
	draw_rect(frame, BOUNDARY_COLOR, false, 2.5)
	var halo: Color = BOUNDARY_COLOR
	halo.a = BOUNDARY_HALO_ALPHA
	draw_rect(frame, halo, false, 8.0)

	# TODO(M10): code-red and gauntlet background, grid tint and overlays
	# (TiltRenderer.ts:64-74, 101-118).
	# TODO(M7): arena theme override (TiltRenderer.ts:76-80).


## PORT: web/src/tilt-to-live/VectorGrid.ts:86-117
func _draw_grid() -> void:
	for r: int in range(_grid.rows):
		var row: PackedVector2Array = PackedVector2Array()
		var row_offset: int = r * _grid.cols
		for c: int in range(_grid.cols):
			var p: VectorGrid.GridPoint = _grid.points[row_offset + c]
			row.append(Vector2(p.x, p.y))
		if row.size() > 1:
			draw_polyline(row, GRID_COLOR, 1.0)

	for c: int in range(_grid.cols):
		var col: PackedVector2Array = PackedVector2Array()
		for r: int in range(_grid.rows):
			var p: VectorGrid.GridPoint = _grid.points[r * _grid.cols + c]
			col.append(Vector2(p.x, p.y))
		if col.size() > 1:
			draw_polyline(col, GRID_COLOR, 1.0)


func _build_background() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.125, 0.8125, 1.0])
	gradient.colors = PackedColorArray([BG_INNER, BG_INNER, BG_MID, BG_OUTER])

	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture
```

- [ ] **Step 2: Write `godot/src/render/entity_layer.gd`**

```gdscript
## entity_layer.gd
## PORTS: web/src/tilt-to-live/PlayerShip.ts:271-632 (render), per spec §4.2 and D4
class_name EntityLayer
extends Node2D
## Middle render layer. M1 draws the player ship only.
##
## PORT-NOTE: PlayerShip.ts:359-592 branches over six alternate ship shapes
## driven by the equipped ShipSkinConfig. Ship skins are M7/M8, so M1 draws the
## default classic arrow (PlayerShip.ts:594-617) alone.
## TODO(M7): the viper, phantom, solar, cyber, shuriken and celestial shapes.
## TODO(M2): enemies, weapon orbs and active weapons (spec §5.5).

## PORT: web/src/tilt-to-live/PlayerShip.ts:284-292 (the classic skin defaults)
const HULL_COLOR: Color = Color("#ffffff")
const PRIMARY_COLOR: Color = Color("#00ddff")
const ACCENT_COLOR: Color = Color("#00ffee")
const THRUSTER_COLOR: Color = Color("#00ddff")
## PORT: web/src/tilt-to-live/PlayerShip.ts:290
const TRAIL_COLOR: Color = Color(0.0, 220.0 / 255.0, 1.0, 0.4)
## PORT: web/src/tilt-to-live/PlayerShip.ts:356-357 (shielded stroke and core)
const SHIELD_STROKE: Color = Color("#00ffff")

var _player: PlayerShip = null
var _elapsed: float = 0.0


## Gives this layer the ship it draws. Called by GameRoot.
func bind(player: PlayerShip) -> void:
	_player = player


## Run clock, for the pulsing shield and thruster flicker.
func set_elapsed(elapsed: float) -> void:
	_elapsed = elapsed


func _draw() -> void:
	if _player == null or _player.is_dead:
		return

	_draw_trail()

	draw_set_transform(Vector2(_player.x, _player.y), _player.angle, Vector2.ONE * _player.scale)

	if _player.has_shield():
		_draw_shield()

	var stroke_col: Color = SHIELD_STROKE if _player.has_shield() else PRIMARY_COLOR
	var core_col: Color = SHIELD_STROKE if _player.has_shield() else ACCENT_COLOR

	# PORT: web/src/tilt-to-live/PlayerShip.ts:596-607 (classic white arrow)
	var hull: PackedVector2Array = PackedVector2Array(
		[Vector2(15.0, 0.0), Vector2(-12.0, -9.0), Vector2(-7.0, 0.0), Vector2(-12.0, 9.0)]
	)
	draw_colored_polygon(hull, HULL_COLOR)
	draw_polyline(_closed(hull), stroke_col, 1.8)

	# PORT: web/src/tilt-to-live/PlayerShip.ts:609-616
	var cockpit: PackedVector2Array = PackedVector2Array(
		[Vector2(5.0, 0.0), Vector2(-4.0, -3.0), Vector2(-2.0, 0.0), Vector2(-4.0, 3.0)]
	)
	draw_colored_polygon(cockpit, core_col)

	# PORT: web/src/tilt-to-live/PlayerShip.ts:620-629
	var flame_col: Color = ACCENT_COLOR if _player.has_shield() else THRUSTER_COLOR
	var flame_len: float = 6.0 + randf() * 6.0
	var flame: PackedVector2Array = PackedVector2Array(
		[Vector2(-13.0, -3.5), Vector2(-13.0 - flame_len, 0.0), Vector2(-13.0, 3.5)]
	)
	draw_colored_polygon(flame, flame_col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## PORT: web/src/tilt-to-live/PlayerShip.ts:296-312
func _draw_trail() -> void:
	if _player.trail_history.size() <= 1:
		return
	for i: int in range(_player.trail_history.size() - 1):
		var pt1: Vector2 = _player.trail_history[i]
		var pt2: Vector2 = _player.trail_history[i + 1]
		var progress: float = 1.0 - float(i) / float(_player.trail_history.size())
		var col: Color = (
			Color(0.0, 1.0, 220.0 / 255.0, progress * 0.45)
			if _player.has_shield()
			else Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, progress * 0.42)
		)
		draw_line(pt1, pt2, col, progress * 5.5 * _player.scale)


## PORT: web/src/tilt-to-live/PlayerShip.ts:319-353
func _draw_shield() -> void:
	var shield_radius: float = _player.shield_radius
	var pulse: float = 0.75 + sin(_elapsed * 8.0) * 0.25

	draw_arc(
		Vector2.ZERO, shield_radius, 0.0, PI * 2.0, 64, Color(0.0, 1.0, 200.0 / 255.0, pulse * 0.8), 2.5
	)
	draw_circle(Vector2.ZERO, shield_radius, Color(0.0, 1.0, 220.0 / 255.0, 0.15))

	var hex: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var a: float = (i * PI) / 3.0 + _elapsed * 2.0
		hex.append(Vector2(cos(a) * (shield_radius - 2.0), sin(a) * (shield_radius - 2.0)))
	draw_polyline(_closed(hex), Color(180.0 / 255.0, 1.0, 240.0 / 255.0, pulse * 0.5), 1.0)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = points.duplicate()
	out.append(points[0])
	return out
```

- [ ] **Step 3: Verify the scripts parse and the suite is still green**

```bash
"$GODOT" --headless --path godot --check-only -s src/render/grid_layer.gd
"$GODOT" --headless --path godot --check-only -s src/render/entity_layer.gd
tools/run_tests.sh          # expect OK: 11/11
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
```

- [ ] **Step 4: Commit**

```bash
rm -f godot/src/render/.gitkeep
git add -A godot/src/render
git commit -m "M1: draw the arena grid and the classic arrow ship"
```

---

## Task 12: Android sensors — enablement, the gravity bridge, and the measured basis

This is the only task that cannot be settled from the source. Measure, then write down what was measured.

**Files:**
- Modify: `godot/project.godot` (sensor settings)
- Modify: `godot/src/input/tilt_input.gd` (add `poll()`, `_screen_angle_degrees()`)
- Test: extend `godot/tests/test_tilt_input.gd`

- [ ] **Step 1: Verify the sensor setting keys exist rather than assuming them**

```bash
cat > /c/Users/Jesury/AppData/Local/Temp/probe_settings.gd <<'GD'
extends SceneTree


func _init() -> void:
	for key: String in [
		"input_devices/sensors/enable_accelerometer",
		"input_devices/sensors/enable_gravity",
		"input_devices/sensors/enable_gyroscope",
		"input_devices/sensors/enable_magnetometer",
	]:
		print("%s has=%s value=%s" % [key, ProjectSettings.has_setting(key), ProjectSettings.get_setting(key, "<absent>")])
	quit()
GD
"$GODOT" --headless --path godot -s /c/Users/Jesury/AppData/Local/Temp/probe_settings.gd
```
Read the output. Godot omits settings left at their default, so `has=false` with a printed default is normal — what matters is the exact key spelling the engine recognises. Godot 4.4 stopped enabling Android sensors by default, so they must be set explicitly.

- [ ] **Step 2: Enable the sensors in `godot/project.godot`**

```ini
[input_devices]

sensors/enable_accelerometer=true
sensors/enable_gravity=true
```

Only these two: `poll()` reads gravity, with the accelerometer as the documented fallback. Do not enable the gyroscope or magnetometer — nothing reads them (Law 4).

- [ ] **Step 3: Add `poll()` and the screen-angle helper to `tilt_input.gd`**

Insert after `apply_orientation()`:

```gdscript
## Reads the device sensor and feeds apply_orientation(). Called once per
## physics tick by GameRoot while the gyro scheme is active.
##
## PORT-NOTE: there is no `deviceorientation` event in Godot. The browser's
## beta and gamma are the device's pitch and roll in degrees; both are
## recoverable from the gravity vector, which is what this converts. The axis
## basis below was measured on the target device — see BASIS-EVIDENCE in
## HANDOFF.md — not assumed from the sensor documentation.
func poll() -> void:
	if not is_listening:
		return
	var g: Vector3 = Input.get_gravity()
	if g == Vector3.ZERO:
		g = Input.get_accelerometer()
	if g == Vector3.ZERO:
		return

	var beta: float = rad_to_deg(atan2(-g.y, -g.z))
	var gamma: float = rad_to_deg(atan2(g.x, sqrt(g.y * g.y + g.z * g.z)))
	apply_orientation(beta, gamma, _screen_angle_degrees())


## The screen rotation in the degrees GyroscopeController expects.
## PORT: web/src/tilt-to-live/GyroscopeController.ts:140-147
func _screen_angle_degrees() -> int:
	match DisplayServer.screen_get_orientation():
		DisplayServer.SCREEN_LANDSCAPE:
			return 90
		DisplayServer.SCREEN_REVERSE_LANDSCAPE:
			return 270
		DisplayServer.SCREEN_REVERSE_PORTRAIT:
			return 180
		_:
			return 0
```

- [ ] **Step 4: Add a one-shot basis probe, build, and measure on the device**

Temporarily add to `GameRoot._physics_process`, above the `match`:

```gdscript
	# TEMPORARY — basis measurement, removed before the module commit.
	_basis_probe_timer += _delta_unused
```

Simpler and sufficient: add to `GameRoot._update()`, guarded so it prints about twice a second:

```gdscript
	# TEMPORARY — Task 12 basis measurement. Delete before committing.
	_probe_accum += dt
	if _probe_accum > 0.5:
		_probe_accum = 0.0
		Log.info(
			"BASIS gravity=%s accel=%s orient=%d tilt=%s"
			% [
				Input.get_gravity(),
				Input.get_accelerometer(),
				DisplayServer.screen_get_orientation(),
				_tilt.tilt_vector
			]
		)
```

Then:

```bash
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"
"$GODOT" --headless --path godot --export-debug "Android" build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ install -r godot/build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ logcat -c
"$ADB" -s RRCXB04L8EJ shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1
# wait ~5s, then confirm it is alive before reading anything into the result
"$ADB" -s RRCXB04L8EJ shell pidof com.jtg.perilpoint
"$ADB" -s RRCXB04L8EJ logcat -d | grep BASIS | tail -40
```

Ask the user to hold the phone in five poses, ~3 s each, reading the `BASIS` lines after each:
1. flat on the table, screen up
2. landscape, held upright and level (the neutral play pose)
3. tilted **nose left** from that pose
4. tilted **nose right**
5. tilted **top away** / **top toward** the player

Record the gravity vector for each pose. From poses 3–5, confirm which sign of `tilt_vector.x` corresponds to "tilt left" and which of `.y` to "tilt away".

- [ ] **Step 5: Fix the basis and lock it with a spec**

Adjust the two `atan2` expressions in `poll()` — and only those — so that a left tilt produces `tilt_vector.x < 0` and a forward/away tilt produces `tilt_vector.y < 0` (screen-up is negative y, matching `PlayerShip`'s coordinate space). Write the measured vectors into a `# PORT-NOTE:` above `poll()`, and paste the raw `BASIS` lines into `HANDOFF.md` under **BASIS-EVIDENCE**.

Add to `godot/tests/test_tilt_input.gd`:

```gdscript
func test_screen_angle_helper_reports_landscape_as_ninety() -> void:
	# On the headless host DisplayServer reports the desktop orientation, so
	# this asserts the mapping is total rather than any particular value.
	var angle: int = _tilt._screen_angle_degrees()
	assert_true(
		angle == 0 or angle == 90 or angle == 180 or angle == 270,
		"every DisplayServer orientation maps to a browser screen angle"
	)


func test_poll_is_inert_while_not_listening() -> void:
	_tilt.stop_listening()
	_tilt.apply_orientation(24.0, 0.0, 90)
	var before: Vector2 = _tilt.tilt_vector
	_tilt.poll()
	assert_eq(_tilt.tilt_vector, before, "poll() does nothing when not listening")
```

- [ ] **Step 6: Remove the probe, verify, commit**

Delete the `BASIS` logging block and `_probe_accum` from `game_root.gd`.

```bash
tools/run_tests.sh          # expect OK: 11/11
gdformat godot/src godot/tests && gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add godot/project.godot godot/src/input/tilt_input.gd godot/tests/test_tilt_input.gd
git commit -m "M1: derive tilt from the measured device gravity basis"
```

---

## Task 13: Device acceptance pass

Nothing here may be reported from expectation. Every line is read off a command or observed by the user on the phone.

- [ ] **Step 1: Build, install and confirm the app survives startup**

```bash
"$GODOT" --headless --path godot --export-debug "Android" build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ install -r godot/build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ logcat -c
"$ADB" -s RRCXB04L8EJ shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1
```
Wait ~5 s (Godot needs time to reach `OnGodotMainLoopStarted`; an immediate empty `pidof` is a race, not a crash), then:
```bash
"$ADB" -s RRCXB04L8EJ shell pidof com.jtg.perilpoint
"$ADB" -s RRCXB04L8EJ logcat -d | grep -E "M1 boot|FATAL|ERROR" | head -20
```
Expected: a pid, and an `M1 boot: bounds=(2340, 1080) arena_scale=…` line. `arena_scale` must be `0.60` (1080/680 = 1.588 → clamped to the 1.15 ceiling — **verify against the fixture rather than this sentence**; `arena_scale.json` carries the answer for 2340×1080).

- [ ] **Step 2: Touch steering (committed default, `HYBRID`)**

Ask the user to drag a finger around the screen and confirm: the ship accelerates toward the finger with visible inertia, the nose turns to face travel, it bounces off all four edges, and the wake ribbon trails it. Record what they report.

- [ ] **Step 3: Grid**

Confirm the lattice is visible, the perimeter frame is drawn, and the lattice re-settles after a viewport change (lock/unlock the phone, or rotate 180° in landscape). Per Q2 this is the reinterpreted criterion; nothing in M1 disturbs the grid from play.

- [ ] **Step 4: Tilt steering (temporary `GYRO` build)**

Change one line in `input_router.gd` — `control_scheme` default to `Types.ControlScheme.GYRO` — rebuild, reinstall, relaunch. Ask the user to confirm: tilting left moves the ship left, right moves right, tilting the top away moves it up-screen, toward them moves it down; resting flat parks the ship (the 7 % deadzone); the response saturates rather than runs away at extreme angles.

**Revert the line before Step 6.** `control_scheme` ships as `HYBRID`, per `GameOptions.ts:80`.

- [ ] **Step 5: Frame rate**

```bash
"$ADB" -s RRCXB04L8EJ shell dumpsys gfxinfo com.jtg.perilpoint | head -40
```
Read "Total frames rendered", "Janky frames" and the percentile lines. Record the actual numbers. 60 fps with the `max_fps=60` cap means ~16.7 ms frames; anything materially above that is a finding, not a footnote — and if Q1 chose 120 Hz physics, this is the measurement that justifies it.

- [ ] **Step 6: Record the evidence**

Paste the real command output — pid, boot line, gfxinfo numbers — into `HANDOFF.md`. If any criterion failed, **the module is not done** (CONVENTIONS §9.1); fix and re-run rather than narrating around it.

---

## Task 14: Exit protocol

CONVENTIONS §9. All five steps, in order, no exceptions.

- [ ] **Step 1: Verify — run every acceptance command fresh and read the output**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --headless --path godot --import        # expect exit 0
tools/run_tests.sh                               # expect OK: 11/11
gdlint godot/src godot/tests                     # expect "no problems"
gdformat --check godot/src godot/tests           # expect "left unchanged"
node tools/parity/dump_constants.mjs             # expect no diff afterwards
git diff --stat godot/tests/fixtures             # expect empty — fixtures are reproducible
```

- [ ] **Step 2: Commit**

Any remaining changes, one line, `M1:` prefix, ≤72 chars, **no trailers**.

- [ ] **Step 3: Tick `godot/PORT-PROGRESS.md`**

Check the M1 box; record the date and the commit SHA; under it record the three acceptance lines as `ok …` with the *observed* result, plus the Q2 reinterpretation of "grid reacts to motion" and the Q1 tick-rate decision.

- [ ] **Step 4: Rewrite `godot/HANDOFF.md`**

For a reader with zero context. It must carry: what landed; the exact verify commands above; **BASIS-EVIDENCE** (the measured gravity vectors and the resulting axis mapping); the Q1 decision and its consequence; the Q2 reinterpretation; Q4 (`TiltRenderer.ts:144` passes a `CursorSkinConfig` to `PlayerShip.render`) and Q5 (the fourth localStorage key) as open questions for M7/M8; whether `Array[Types.Enemy]` compiled or the record split was forced; whether the Node 24 `.ts` import worked or the `tsc` fallback was needed; that `control_scheme` ships as `HYBRID` and how to flip it for a tilt test; and that **M2 is next** with its literal first step.

- [ ] **Step 5: Stop. Report to the user. Do not begin Module 2.**

The user is managing a credit budget and has asked explicitly for a hard stop at every module boundary.

---

## Self-review against spec §8 Module 1

| Spec requirement | Task |
|---|---|
| `core/types.gd` (ports `Types.ts`) | 2 |
| `core/tuning.gd` (ports `WeaponTuning.ts`) | 3 |
| `core/log.gd` | 1 |
| `tools/parity/` dumper + first fixture and GUT spec | 3 (and 10 for `arena_scale.json`) |
| `core/game_root.gd` | 10 |
| `core/game_state_machine.gd` (menu/playing/paused) | 9 |
| `sim/vector_grid.gd` (ports `VectorGrid.ts`) | 4 |
| `sim/player_ship.gd` (ports `PlayerShip.ts`) | 6 (+ 5 for the `ParticleEngine` surface it calls) |
| `input/input_router.gd`, `touch_input.gd` | 8 |
| `input/tilt_input.gd` incl. landscape axis mapping and calibration | 7 (port) + 12 (device basis) |
| `render/grid_layer.gd`, minimal `render/entity_layer.gd` | 11 |
| `resizeCanvas()` reproduction including `arenaScale` | 10 |
| **Accept:** tilt and touch steer with correct axes in landscape on device | 13 |
| **Accept:** the grid reacts to motion | 11 + 13, reinterpreted per Q2 |
| **Accept:** 60 fps | 13 |
| **Accept:** the tuning parity spec passes | 3 |
| `scenes/main.tscn` placeholder replaced (HANDOFF) | 10 |
