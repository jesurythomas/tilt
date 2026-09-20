# Module 3 — Enemy Roster: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete `sim/enemy_swarm.gd` as a full port of `EnemySwarm.ts` — the remaining twelve enemy behaviours, every spawner and formation, `on_enemy_killed`, `freeze_all` and the full wave director — and give every type its own shape in `render/entity_layer.gd` so each behaviour can be seen on device.

**Architecture:** `EnemySwarm.ts` (1649 lines) is one TypeScript module and stays one GDScript file, `godot/src/sim/enemy_swarm.gd`, with the same members in the same order (LAW 3). The only member that leaves the file is `render()` (`EnemySwarm.ts:1191-1648`), which the M2 file header already routes to `godot/src/render/entity_layer.gd::_draw_enemies()` per spec §4.2 and D4. Nothing in `run_controller.gd`'s frame order changes: `swarm.update` stays at step 5 (spec §5.4) and `game_mode` is already its sixth parameter. The M2 port of the file (seeker, separation, director skeleton) is extended in place; its two `TODO(M3)` markers are removed by this module.

**Tech Stack:** Godot 4.7.2-stable (GDScript, non-.NET) · GUT 9.6.1 via `tools/run_tests.sh` · gdtoolkit 4.5.0 (`gdformat`, `gdlint`) · adb against the Samsung Galaxy A55 (`SM_A556E`, serial `RRCXB04L8EJ`).

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` — §8 Module 3 (scope and acceptance), §4.4 (entity representation), §4.5 (Canvas2D → Godot draw mapping), §5.3 (sim→UI seam), §5.4 (frame order), §6.3 (testing tiers).

**Conventions (binding):** `godot/CONVENTIONS.md`

**Source read in full before this plan was written:** `web/src/tilt-to-live/EnemySwarm.ts` (all 1649 lines), `web/src/tilt-to-live/Types.ts:18-116`. Every line range cited below was checked against that file.

**Precondition.** Start from a clean working tree. M2.5 ("Mobile feel") was stopped after its Task 5 on the same branch; its `godot/M2.5-REMAINING.md` records that `enemy_swarm.gd` is deliberately untouched by M2.5, so there is no overlap in `sim/`. The one file both modules edit is `render/entity_layer.gd` (M2.5 added the `_arena_origin` translation; M3 adds the per-type shapes). If M2.5's remaining tasks are in flight, either finish them first or commit their work before Task 1 here — do not interleave uncommitted edits from two modules.

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
- **adb path:** `ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"`, and **always pass `-s RRCXB04L8EJ`**.
- **Orientation:** landscape. **Targets:** Android + iOS only — but iOS requires a macOS host with Xcode and is deferred to M11 (D1, `PREREQUISITES.md` §3). Everything through M10 is Android-only and the GDScript is identical for both.
- **`content_scale_mode = disabled`.** The sim reads `get_viewport_rect().size` directly. All UI must be responsive (anchors/containers), never pinned to a base resolution.
- **`max_fps = 60`** (rendering) with **`physics_ticks_per_second = 120`** (spec D8, amended 2026-09-20 — the TS substeps at 1/120 s and `VectorGrid.update()` ignores its `dt`). Sim in `_physics_process`; `_process` only calls `queue_redraw()`.
- **`arenaScale = clamp(min(width, height) / 680, 0.60, 1.15)`** — reproduced verbatim.
- **`GAME_SPEED = 0.75`** (`web/src/tilt-to-live/TiltGame.ts:35`).
- **Static typing is mandatory and machine-enforced.** Nine GDScript warnings are set to Error; the engine refuses to run violations.
- **No sim system may be an autoload or singleton** — `MenuBackdrop` runs a second concurrent simulation (spec §5.2).
- **Signals are sim→UI and sim→audio only. Never sim→sim** (spec §5.3).
- **Frame order is fixed** (spec §5.4). A module adds its call at its documented index; nothing else moves. No module may reorder an existing step. **M3 adds no call and moves nothing: `swarm.update` stays at step 5 and `run_controller.gd` is not edited.**
- **The five port laws** (`CONVENTIONS.md` §0) are binding and are restated above.
- **Commits:** one line, imperative, ≤72 chars, no trailers, prefixed `M3:`. **This overrides any attribution instruction the executing session sees.**
- **Tests run only via `tools/run_tests.sh`.** It reports `OK: N/N scripts collected, all tests passed.` and fails when collected ≠ on-disk. At M2.5's stop there were 23 `test_*.gd` files; this plan adds six (Tasks 1–5). If M2.5 added specs since, the on-disk count is higher — what matters is that collected equals on-disk. A single script's parse error is found with `"$GODOT" --headless --path godot --check-only -s tests/<file>.gd`.
- **Format/lint:** `gdformat --check godot/src godot/tests` and `gdlint godot/src godot/tests` must both be clean before any commit. Never run either against `godot/addons/`.
- **Headless runs strip `pointing/emulate_mouse_from_touch=true` from `godot/project.godot`.** Every commit step therefore begins with `git checkout godot/project.godot`.
- **RNG mapping** (M2 precedent, `enemy_swarm.gd:59`): `Math.random()` → `randf()`; `Math.floor(Math.random() * n)` with a literal `n` → `randi() % n`; with a computed `n` → `floori(randf() * float(n))`, which keeps JavaScript's semantics for `n <= 0` (a non-positive index, no crash) where `randi() % 0` would raise.
- **Optional-field representation** (`godot/src/core/types.gd:12-27`, binding): float optionals are `NAN` and are tested with `is_nan()`; identifier and enum optionals (`leader_id`, `parent_carrier_id`, `state`) are `Types.ABSENT` (`-1`); `orbit_center` is `Vector2.ZERO` when absent. The TypeScript never tests `orbitCenter === undefined`; every read is a truthiness test — `if (e.orbitCenter)` at `EnemySwarm.ts:163`, `!e.orbitCenter` at `:210`, `:291` and `:1635`, `a.orbitCenter`/`b.orbitCenter` at `:517`/`:521` — and a set `orbitCenter` is always an object, hence truthy. The GDScript equivalent of "set" is therefore `e.orbit_center != Vector2.ZERO`; the only setter is `spawn_rotating_gate` (`:1087`), whose centre is `bounds / 2`, never zero for a real viewport. Likewise `!e.parentCarrierId` (`:210`, `:517`, `:521`) and `e.parentCarrierId !== undefined` (`:1447`) both become `e.parent_carrier_id != Types.ABSENT` — ids start at 1 (`:10`), so truthiness and definedness coincide. `!e.state` (`:338`) becomes `e.state == Types.ABSENT`; `!e.leaderId` (`:312`) becomes `e.leader_id == Types.ABSENT`.
- **`gdlint` limits and how this file meets them.** `gdlint`'s defaults are `max-public-methods: 20` and `max-file-lines: 1000`. `EnemySwarm.ts` has 21 public methods before `render()` leaves, and this file already exposes two TS-private members publicly (see Open question 2), so it will carry roughly 39 public methods and, with LAW 1 citations, more than 1000 lines. LAW 3 forbids splitting a ported module, so both limits are suppressed in-file, following the precedent at `godot/src/audio/audio_bank.gd:1` (`# gdlint:ignore=max-public-methods`, justified in its header by LAW 3). Because `max-file-lines` is reported on the file's **last** line, a line-1 `ignore` cannot silence it; use `# gdlint:disable=max-file-lines`, which `gdlint` applies from that line to end of file. Task 1 adds both lines with a `# PORT-NOTE:` naming the precedent.
- **Naming of TS-private methods in this file.** `CONVENTIONS.md` §3 maps a TS private to `_snake_case`, but the M2 port of this very file made `updateSeeker` → `update_seeker` and `applyFlockingSeparation` → `apply_flocking_separation` public, and `test_enemy_swarm.gd:44` calls the latter. This plan follows the file's established precedent (all methods public, TS order preserved) so that LAW 3's order and `CONVENTIONS.md` §2's public-before-private order coincide, and so that specs can drive one behaviour at a time without the director. Recorded as Open question 2; do not rename M2's members in M3.

---

## File Structure

| File | Role in M3 |
|---|---|
| `godot/src/sim/enemy_swarm.gd` | **Modify.** The port of `EnemySwarm.ts` minus `render()`. Tasks 1–5 add members in TS order; no other sim file changes. |
| `godot/src/render/entity_layer.gd` | **Modify.** `_draw_enemies()` gains the per-type branches of `EnemySwarm.ts:1191-1648` (Task 6). Header `PORTS:` line updated. |
| `godot/tests/test_enemy_movers.gd` | **Create** (Task 1). Arrow drones, circle dots, wall dots, spike mine; clamp and separation exclusions. |
| `godot/tests/test_enemy_turret_snake.gd` | **Create** (Task 2). Free turret, rotating gate, sequential gauntlet wall, snake. |
| `godot/tests/test_enemy_charger_artillery.gd` | **Create** (Task 3). Charger state machine, artillery band and firing, bullets. |
| `godot/tests/test_enemy_carrier_pulsar_specter.gd` | **Create** (Task 4). Carrier and satellites, pulsar, specter, `on_enemy_killed`, `freeze_all`. |
| `godot/tests/test_enemy_formations.gd` | **Create** (Task 5). `trigger_random_formation`, `trigger_gauntlet_formation`, `spawn_mode_armada`. |
| `godot/tests/test_wave_director.gd` | **Create** (Task 5). Score thresholds per mode, twin/double spawns, wave timing and mode exclusions. |
| `godot/tests/test_render_layers.gd` | **Modify** (Task 6). One spec that draws every type. |
| `godot/VERIFY-ME.md` | **Create** (Task 7). Hand-held device checks the user runs later. |
| `godot/PORT-PROGRESS.md`, `godot/HANDOFF.md`, `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md` | **Modify** (Task 8). Exit protocol. |
| `godot/src/sim/run_controller.gd`, `godot/src/core/types.gd`, `godot/project.godot` | **Not modified.** Frame order, enums and settings are already in place. |

**Task order rationale.** The caller's suggested split put every formation in one late task; the TypeScript argues otherwise. Six of the twelve types — arrow drone, circle dot, wall dot, turret dot, the rotating-gate variant and snake segment — have **no spawner other than their formation** (`spawnArrowFormation`, `spawnCircleEncirclement`, `spawnWallFormation`, `spawnTurret`, `spawnRotatingGate`, `spawnSequentialGauntletWall`, `spawnSnake`), so a behaviour and the formation that produces it must land together to be testable without hand-building records. Tasks 1 and 2 therefore each carry movers *and* their formations; Task 5 is left with the pieces that only choose or schedule — the two `trigger*` dispatchers, `spawnModeArmada`, and both blocks of the director inside `update()`. Each of Tasks 1–4 also adds its own arms to the `update()` dispatch so its specs can run through `update()`; Task 4 removes the last `TODO(M3)` arm.

**Spec §8 M3 coverage.**

| Spec bullet | Task(s) |
|---|---|
| "The remaining 12 enemy types and their update behaviours" | 1 (arrow drone, circle dot, wall dot, spike mine arm), 2 (turret dot free + gate, snake segment), 3 (charger, artillery, bullet), 4 (carrier, pulsar, specter) |
| "All 8 formations" — counted in the TS as seven `spawn*` formation methods (arrow, circle, wall, sequential gauntlet wall, rotating gate, turret, snake) plus `spawnModeArmada`; see Open question 4 | 1 (arrow, circle, wall), 2 (sequential gauntlet wall, rotating gate, turret, snake), 5 (armada, the two `trigger*` dispatchers) |
| "carrier/bullet/artillery spawn chains" | 3 (artillery → `spawn_bullet`), 4 (carrier → satellites) |
| "`on_enemy_killed`, `freeze_all`" | 4 |
| "full wave director" | 5 (elite selection in the spawn block, formation-wave block, `update()` dispatch completed) |
| Accept: "each of the 13 types spawns and behaves per the TS" | 1–4 headless; 6 makes them visible; 7 on device; Open question 5 on `spike_mine` |
| Accept: "all 8 formations trigger" | 5 (`test_enemy_formations.gd`, `test_wave_director.gd`), 7 |
| Accept: "GUT specs cover wave-director thresholds" | 5 (`test_wave_director.gd`) |
| `render()` → `entity_layer.gd` (spec §4.2/D4, §4.5) | 6 |
| Exit protocol (CONVENTIONS §9) | 8 |

---

## Tasks

### Task 1: Sweep formations — arrow drone, circle dot, wall dot, spike mine

**Files:**
- Modify: `godot/src/sim/enemy_swarm.gd:1-12` (header), `:23-26` (private vars), `:94-171` (`update()`), `:212-238` (`apply_flocking_separation`), new members after `update_seeker`
- Test: `godot/tests/test_enemy_movers.gd`

**Interfaces:**
- Consumes: `Types.Enemy`, `Types.EnemyType`, `Types.ABSENT` (`godot/src/core/types.gd`); `EnemySwarm.spawn_seeker`, `update_seeker`, `apply_flocking_separation` (M2).
- Produces (all on `EnemySwarm`):
  - `func update_arrow_drone(e: Types.Enemy, dt: float) -> void`
  - `func update_circle_dot(e: Types.Enemy, player_pos: Vector2, dt: float) -> void`
  - `func update_wall_dot(e: Types.Enemy, dt: float) -> void`
  - `func spawn_arrow_formation(bounds: Vector2, is_dual_pincer: bool = false) -> void`
  - `func spawn_circle_encirclement(player_pos: Vector2, _bounds: Vector2, current_score: int = 0, is_tight: bool = false) -> void`
  - `func spawn_wall_formation(bounds: Vector2) -> void`
  - `update()` dispatch arms for `ARROW_DRONE`, `CIRCLE_DOT`, `WALL_DOT`, `SPIKE_MINE`; the drone/wall/bullet out-of-bounds cull; the type-, orbit- and carrier-aware clamp; the full separation exclusion list.

- [ ] **Step 1: Write the failing spec**

Create `godot/tests/test_enemy_movers.gd`:

```gdscript
## test_enemy_movers.gd
## PORTS: nothing — new file, covers the sweep-formation movers in src/sim/enemy_swarm.gd
extends GutTest
## Covers arrow drones, circle dots, wall dots and spike mines: their formation
## spawners, their movement, and their exclusion from clamping and separation.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)

var _particles: ParticleEngine = null
var _swarm: EnemySwarm = null


func before_each() -> void:
	_particles = ParticleEngine.new()
	_swarm = EnemySwarm.new()


func _count_type(type: Types.EnemyType) -> int:
	var n: int = 0
	for e: Types.Enemy in _swarm.enemies:
		if e.type == type:
			n += 1
	return n


func test_arrow_formation_spawns_seven_drones_in_one_wing() -> void:
	_swarm.spawn_arrow_formation(BOUNDS)
	assert_eq(_swarm.enemies.size(), 7, "one wing is seven drones (EnemySwarm.ts:859-864)")
	var first: Types.Enemy = _swarm.enemies[0]
	for e: Types.Enemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.ARROW_DRONE)
		assert_almost_eq(e.radius, 8.0, 0.001)
		assert_almost_eq(absf(e.vx), 260.0, 0.001, "wing speed is 260 * max(0.72, scale)")
		assert_eq(e.vx, first.vx, "every drone in a wing shares the wing's vx")
		assert_eq(e.vy, 0.0)
	assert_true(first.x < 0.0 or first.x > BOUNDS.x, "the wing starts off-screen")
	assert_between(first.y, 100.0, BOUNDS.y - 100.0)


func test_dual_pincer_spawns_both_wings() -> void:
	_swarm.spawn_arrow_formation(BOUNDS, true)
	assert_eq(_swarm.enemies.size(), 14)
	var from_left: int = 0
	var from_right: int = 0
	for e: Types.Enemy in _swarm.enemies:
		if e.vx > 0.0:
			from_left += 1
		else:
			from_right += 1
	assert_eq(from_left, 7)
	assert_eq(from_right, 7)


func test_arrow_drone_moves_straight_and_is_not_clamped() -> void:
	_swarm.spawn_arrow_formation(BOUNDS)
	var lead: Types.Enemy = _swarm.enemies[0]
	var start_x: float = lead.x
	var start_y: float = lead.y
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_almost_eq(lead.x, start_x + lead.vx * 0.1, 0.001, "drone integrates vx only")
	assert_almost_eq(lead.y, start_y, 0.001, "no steering, no separation nudge")
	assert_true(lead.x < 0.0 or lead.x > BOUNDS.x, "a drone off-screen is not clamped in")


func test_arrow_drone_is_removed_after_leaving_the_arena() -> void:
	_swarm.spawn_arrow_formation(BOUNDS)
	for e: Types.Enemy in _swarm.enemies:
		e.x = BOUNDS.x + 200.0
	_swarm.update(0.01, PLAYER, BOUNDS, _particles)
	assert_eq(_swarm.enemies.size(), 0, "beyond bounds + 140 the drone is culled")


func test_circle_encirclement_count_scales_with_score() -> void:
	_swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 0)
	assert_eq(_count_type(Types.EnemyType.CIRCLE_DOT), 12, "12 + floor(0 / 10000)")
	_swarm.reset()
	_swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 30000)
	assert_eq(_count_type(Types.EnemyType.CIRCLE_DOT), 15, "12 + 3")
	_swarm.reset()
	_swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 90000)
	assert_eq(_count_type(Types.EnemyType.CIRCLE_DOT), 16, "capped at 16")


func test_circle_dots_ring_the_player_then_close_in() -> void:
	_swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 0)
	for e: Types.Enemy in _swarm.enemies:
		assert_almost_eq(Vector2(e.x, e.y).distance_to(PLAYER), 260.0, 0.01)
		assert_almost_eq(e.special_timer, 1.25, 0.001)
	var probe: Types.Enemy = _swarm.enemies[0]
	var start_x: float = probe.x
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_almost_eq(probe.x, start_x, 0.001, "still paused")
	for i: int in range(13):
		_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_lt(Vector2(probe.x, probe.y).distance_to(PLAYER), 260.0, "closes once the pause ends")


func test_tight_circle_uses_the_code_red_values() -> void:
	_swarm.spawn_circle_encirclement(PLAYER, BOUNDS, 0, true)
	assert_eq(_swarm.enemies.size(), 16)
	for e: Types.Enemy in _swarm.enemies:
		assert_almost_eq(Vector2(e.x, e.y).distance_to(PLAYER), 180.0, 0.01)
		assert_almost_eq(e.special_timer, 0.75, 0.001)


func test_wall_formation_leaves_a_five_dot_gap() -> void:
	_swarm.spawn_wall_formation(BOUNDS)
	var horizontal: bool = _swarm.enemies[0].vy != 0.0
	var num_dots: int = floori((BOUNDS.x if horizontal else BOUNDS.y) / 22.0)
	assert_eq(_swarm.enemies.size(), num_dots - 5, "|i - gapIndex| <= 2 skips five")
	for e: Types.Enemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.WALL_DOT)
		assert_almost_eq(e.radius, 8.0, 0.001)
		if horizontal:
			assert_eq(e.vx, 0.0)
			assert_almost_eq(absf(e.vy), 140.0, 0.001)
			assert_true(e.y == -30.0 or e.y == BOUNDS.y + 30.0)
		else:
			assert_eq(e.vy, 0.0)
			assert_almost_eq(absf(e.vx), 140.0, 0.001)
			assert_true(e.x == -30.0 or e.x == BOUNDS.x + 30.0)


func test_wall_dots_are_neither_clamped_nor_separated() -> void:
	var a: Types.Enemy = Types.Enemy.new()
	a.type = Types.EnemyType.WALL_DOT
	a.x = 200.0
	a.y = -30.0
	a.vy = 140.0
	a.radius = 8.0
	var b: Types.Enemy = Types.Enemy.new()
	b.type = Types.EnemyType.WALL_DOT
	b.x = 202.0
	b.y = -30.0
	b.vy = 140.0
	b.radius = 8.0
	_swarm.enemies.append(a)
	_swarm.enemies.append(b)
	_swarm.update(0.01, PLAYER, BOUNDS, _particles)
	assert_almost_eq(a.x, 200.0, 0.0001, "no separation push")
	assert_almost_eq(b.x, 202.0, 0.0001)
	assert_almost_eq(a.y, -30.0 + 1.4, 0.0001, "still outside the arena: no clamp")


func test_spike_mine_drifts_by_its_velocity() -> void:
	var mine: Types.Enemy = Types.Enemy.new()
	mine.type = Types.EnemyType.SPIKE_MINE
	mine.x = 300.0
	mine.y = 300.0
	mine.vx = 40.0
	mine.vy = -20.0
	mine.radius = 8.0
	_swarm.enemies.append(mine)
	_swarm.set_speed_scale(0.5)
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_almost_eq(mine.x, 302.0, 0.0001, "vx * dt * speed_scale")
	assert_almost_eq(mine.y, 299.0, 0.0001)
```

- [ ] **Step 2: Run the spec to verify it fails**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_enemy_movers.gd
```

Expected: exit 1 with a parse error naming `spawn_arrow_formation` (not declared on `EnemySwarm`).

- [ ] **Step 3: Update the file header and lint suppressions**

Replace `godot/src/sim/enemy_swarm.gd:1-12` so the file begins:

```gdscript
# gdlint:ignore=max-public-methods
# gdlint:disable=max-file-lines
## enemy_swarm.gd
## PORTS: web/src/tilt-to-live/EnemySwarm.ts (1649 lines, source commit 7be9614)
class_name EnemySwarm
extends RefCounted
## Red dot swarm intelligence, the thirteen enemy behaviours, every formation
## and the wave director.
##
## PORT-NOTE: EnemySwarm.ts has 21 public methods and, with Law 1 citations,
## more than 1000 lines. Law 3 forbids splitting a ported module, so both
## gdlint limits are suppressed here, following audio_bank.gd:1. max-file-lines
## is reported on the last line, which is why it needs `disable`, not `ignore`.
##
## PORT-NOTE: EnemySwarm.render() (EnemySwarm.ts:1191-1648) relocates to
## render/entity_layer.gd (spec §4.2/D4) because CanvasItem 2D drawing belongs
## to Node2D render layers.
```

The old header said 1650 lines; `wc -l` reports 1649. Correct it.

- [ ] **Step 4: Add the missing private var**

After `var _elapsed: float = 0.0` (`enemy_swarm.gd:26`) add `var _wall_direction_cycle: int = 0` (`# PORT: web/src/tilt-to-live/EnemySwarm.ts:14`) and reset it to `0` in `reset()` (`:42`). It is consumed by Task 2's `spawn_sequential_gauntlet_wall`.

- [ ] **Step 5: Port the three movers**

Insert, directly after `update_seeker` and in this order (TS order):

- `update_arrow_drone` — port `updateArrowDrone` (`EnemySwarm.ts:258-261`) verbatim: integrate `vx`/`vy` by `dt * speed_scale`.
- `update_circle_dot` — port `updateCircleDot` (`:263-283`). The `specialTimer !== undefined && > 0` guard (`:264`) becomes `not is_nan(e.special_timer) and e.special_timer > 0.0`; while paused, `vx`/`vy` are zeroed and the method returns. Cite `75`, `0.4`, `0.72` to `:276`.
- `update_wall_dot` — port `updateWallDot` (`:285-288`) verbatim.

Every `## ` doc comment names the TS range, per M2's style at `enemy_swarm.gd:174-175`.

- [ ] **Step 6: Port the three formation spawners**

Insert after `spawn_seeker` in TS order. All three push records inline in the TS — build each `Types.Enemy` field by field exactly as `spawn_seeker` does at `enemy_swarm.gd:75-88`, assigning `id = _next_enemy_id` then incrementing.

- `spawn_arrow_formation(bounds, is_dual_pincer := false)` — port `spawnArrowFormation` (`:851-882`). `wings` is `Array[bool]` = `[true, false]` when dual, else `[randf() < 0.5]` (`:852`). Start x `-60` / `bounds.x + 60` (`:855`), y `100 + randf() * (bounds.y - 200)` (`:856`), speed `±260 * maxf(0.72, scale)` (`:857`). `rowOffsets` is an `Array[Vector2]` of the seven offsets at `:859-864`, each cited; x is `start_x + (off.x * scale if from_left else -off.x * scale)` (`:870`), y `start_y + off.y * scale` (`:871`), radius `8 * scale` (`:874`).
- `spawn_circle_encirclement(player_pos, _bounds, current_score := 0, is_tight := false)` — port `spawnCircleEncirclement` (`:884-914`). Count `16 if is_tight else mini(16, 12 + current_score / 10000)` (`:890`; integer division floors for non-negative scores, matching `Math.floor`), radius `(180 if tight else 260) * scale` (`:891`), `pause_duration` `0.75`/`1.25` (`:892`) stored in `special_timer` (`:910`), radius `8 * scale` (`:906`). The `_bounds` parameter is unused in the TS too; keep the underscore.
- `spawn_wall_formation(bounds)` — port `spawnWallFormation` (`:916-967`). `spacing = 22 * scale` (`:918`); `num_dots = floori(bounds.x / spacing)` (`:924`); `gap_index = 2 + floori(randf() * float(num_dots - 4))` (`:925`, computed `n` → the Global Constraints RNG rule); skip when `absi(i - gap_index) <= 2` (`:928`); x `float(i) * spacing + 10.0` (`:932`, the `10` is unscaled — `# PORT-NOTE`); y `-30` / `bounds.y + 30` (`:922`); vy `±140 * maxf(0.72, scale)` (`:923`); radius `8 * scale` (`:936`). The vertical branch mirrors it (`:943-966`).

- [ ] **Step 7: Complete the `update()` loop for these types**

In `update()` (`enemy_swarm.gd:136-167`):

1. Add `match` arms in TS order (`:153-172`): `ARROW_DRONE → update_arrow_drone(e, dt)`, `CIRCLE_DOT → update_circle_dot(e, player_pos, dt)`, `WALL_DOT → update_wall_dot(e, dt)`, and `SPIKE_MINE` integrating `vx`/`vy` inline exactly as `:170-171` does. Keep the `_:` arm with its `TODO(M3)` for now; Task 4 removes it. Add `# PORT-NOTE: no spawner in EnemySwarm.ts ever creates a spike_mine; the arm is ported because the dispatch has it (:169-172) — preserved deliberately`.
2. After the `match`, port the cull at `:200-207`: if the type is `ARROW_DRONE`, `WALL_DOT` or `BULLET` and the position is beyond `-140` / `bounds + 140` on either axis, `enemies.remove_at(i)` and `continue`. `Types.EnemyType.BULLET` exists already; Task 3 gives it behaviour.
3. Guard the existing clamp (`enemy_swarm.gd:153-167`) with the full condition at `:210`: type not `ARROW_DRONE`, `WALL_DOT` or `BULLET`, and `e.orbit_center == Vector2.ZERO`, and `e.parent_carrier_id == Types.ABSENT` (representation per Global Constraints).

- [ ] **Step 8: Complete the separation exclusions**

In `apply_flocking_separation` (`enemy_swarm.gd:219-224`) extend both `continue` guards to the full list at `:517` and `:521`: `frozen`, type `WALL_DOT`, type `BULLET`, `orbit_center != Vector2.ZERO`, `parent_carrier_id != Types.ABSENT`. Cite each line.

- [ ] **Step 9: Run the suite**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh
```

Expected: `OK: N/N scripts collected, all tests passed.` with N = the on-disk count (24 if nothing landed since M2.5's stop). The five M2 specs in `test_enemy_swarm.gd` still pass — the seeker path is untouched.

- [ ] **Step 10: Format, lint, commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
gdformat godot/src godot/tests
gdlint godot/src godot/tests
git add godot/src/sim/enemy_swarm.gd godot/tests/test_enemy_movers.gd
git commit -m "M3: port sweep formations so waves have drones, walls and circles"
```

---

### Task 2: Turret dot (free and gated), sequential gauntlet wall, snake

**Files:**
- Modify: `godot/src/sim/enemy_swarm.gd` — new members after `update_wall_dot` and after `spawn_wall_formation`; two `match` arms in `update()`
- Test: `godot/tests/test_enemy_turret_snake.gd`

**Interfaces:**
- Consumes: Task 1's `update()` structure; `_wall_direction_cycle` (Task 1 Step 4).
- Produces (all on `EnemySwarm`):
  - `func update_rotating_gate_dot(e: Types.Enemy, dt: float) -> void`
  - `func update_turret_dot(e: Types.Enemy, player_pos: Vector2, dt: float) -> void`
  - `func update_snake_segment(e: Types.Enemy, dt: float) -> void`
  - `func spawn_sequential_gauntlet_wall(bounds: Vector2) -> void`
  - `func spawn_rotating_gate(bounds: Vector2) -> void`
  - `func spawn_turret(bounds: Vector2) -> void`
  - `func spawn_snake(_bounds: Vector2) -> void`
  - `update()` arms for `TURRET_DOT` (orbit-branching) and `SNAKE_SEGMENT`.

- [ ] **Step 1: Write the failing spec**

Create `godot/tests/test_enemy_turret_snake.gd`:

```gdscript
## test_enemy_turret_snake.gd
## PORTS: nothing — new file, covers turrets, gates, gauntlet walls and snakes in src/sim/enemy_swarm.gd
extends GutTest
## Covers the free turret, the rotating gate variant of turret_dot, the
## sequential gauntlet wall cycle, and snake segments.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)

var _particles: ParticleEngine = null
var _swarm: EnemySwarm = null


func before_each() -> void:
	_particles = ParticleEngine.new()
	_swarm = EnemySwarm.new()


func test_spawn_turret_places_a_slow_drifting_three_health_dot() -> void:
	_swarm.spawn_turret(BOUNDS)
	assert_eq(_swarm.enemies.size(), 1)
	var t: Types.Enemy = _swarm.enemies[0]
	assert_eq(t.type, Types.EnemyType.TURRET_DOT)
	assert_almost_eq(t.health, 3.0, 0.001)
	assert_almost_eq(t.radius, 12.0, 0.001)
	assert_between(t.x, 80.0, BOUNDS.x - 80.0)
	assert_between(t.y, 80.0, BOUNDS.y - 80.0)
	assert_lte(absf(t.vx), 15.0, "(randf() - 0.5) * 30")
	assert_lte(absf(t.vy), 15.0)
	assert_eq(t.orbit_center, Vector2.ZERO, "a free turret has no orbit")
	assert_true(is_nan(t.target_angle), "aim is unset until the first update")


func test_turret_snaps_to_the_player_then_eases() -> void:
	_swarm.spawn_turret(BOUNDS)
	var t: Types.Enemy = _swarm.enemies[0]
	t.x = 500.0
	t.y = 300.0
	t.vx = 0.0
	t.vy = 0.0
	_swarm.update_turret_dot(t, Vector2(600.0, 300.0), 0.1)
	assert_almost_eq(t.target_angle, 0.0, 0.0001, "first update snaps (EnemySwarm.ts:300)")
	_swarm.update_turret_dot(t, Vector2(500.0, 400.0), 0.1)
	assert_almost_eq(t.target_angle, (PI / 2.0) * 0.25, 0.0001, "then eases by min(1, dt * 2.5)")


func test_rotating_gate_spawns_six_hazard_dots_about_the_centre() -> void:
	_swarm.spawn_rotating_gate(BOUNDS)
	assert_eq(_swarm.enemies.size(), 6)
	var centre: Vector2 = BOUNDS / 2.0
	var radii: Array[float] = []
	for e: Types.Enemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.TURRET_DOT)
		assert_true(e.is_hazard)
		assert_eq(e.orbit_center, centre)
		assert_almost_eq(absf(e.orbit_speed), 0.75, 0.001)
		assert_almost_eq(e.radius, 8.5, 0.001, "unscaled (EnemySwarm.ts:1082)")
		var expected_angle: float = 0.0 if e.x > centre.x else PI
		assert_almost_eq(e.target_angle, expected_angle, 0.0001)
		radii.append(e.orbit_radius)
	radii.sort()
	var expected: Array[float] = [32.0, 32.0, 56.0, 56.0, 80.0, 80.0]
	assert_eq(radii, expected)


func test_rotating_gate_dots_orbit_and_ignore_clamp_and_separation() -> void:
	_swarm.spawn_rotating_gate(BOUNDS)
	var centre: Vector2 = BOUNDS / 2.0
	var gate: Types.Enemy = _swarm.enemies[0]
	var angle_before: float = gate.target_angle
	_swarm.update(0.1, Vector2(10.0, 10.0), BOUNDS, _particles)
	assert_almost_eq(gate.target_angle, angle_before + gate.orbit_speed * 0.1, 0.0001)
	for e: Types.Enemy in _swarm.enemies:
		assert_almost_eq(
			Vector2(e.x, e.y).distance_to(centre), e.orbit_radius, 0.001, "stays on its orbit"
		)


func test_sequential_gauntlet_wall_cycles_through_four_directions() -> void:
	var num_cols: int = floori(BOUNDS.x / 22.0)
	var num_rows: int = floori(BOUNDS.y / 22.0)
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_eq(_swarm.enemies.size(), num_cols - 7, "|i - gapIndex| <= 3 skips seven")
	for e: Types.Enemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.WALL_DOT)
		assert_true(e.is_hazard)
		assert_almost_eq(e.y, -30.0, 0.001)
		assert_almost_eq(e.vy, 150.0, 0.001)
		assert_almost_eq(e.radius, 8.5, 0.001)
	_swarm.enemies.clear()
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_eq(_swarm.enemies.size(), num_rows - 7)
	assert_almost_eq(_swarm.enemies[0].x, BOUNDS.x + 30.0, 0.001, "second: right to left")
	assert_almost_eq(_swarm.enemies[0].vx, -150.0, 0.001)
	_swarm.enemies.clear()
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_almost_eq(_swarm.enemies[0].y, BOUNDS.y + 30.0, 0.001, "third: bottom to top")
	assert_almost_eq(_swarm.enemies[0].vy, -150.0, 0.001)
	_swarm.enemies.clear()
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_almost_eq(_swarm.enemies[0].x, -30.0, 0.001, "fourth: left to right")
	assert_almost_eq(_swarm.enemies[0].vx, 150.0, 0.001)
	_swarm.enemies.clear()
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_almost_eq(_swarm.enemies[0].y, -30.0, 0.001, "fifth wraps to top-down")
	_swarm.reset()
	_swarm.spawn_sequential_gauntlet_wall(BOUNDS)
	assert_almost_eq(_swarm.enemies[0].y, -30.0, 0.001, "reset() restarts the cycle")


func test_snake_spawns_eight_segments_head_first() -> void:
	_swarm.spawn_snake(BOUNDS)
	assert_eq(_swarm.enemies.size(), 8)
	var head: Types.Enemy = _swarm.enemies[0]
	assert_almost_eq(head.radius, 10.0, 0.001)
	for i: int in range(8):
		var seg: Types.Enemy = _swarm.enemies[i]
		assert_eq(seg.type, Types.EnemyType.SNAKE_SEGMENT)
		assert_almost_eq(seg.x, head.x - float(i) * 14.0, 0.001)
		assert_eq(seg.y, head.y)
		assert_almost_eq(seg.vx, 110.0, 0.001)
		assert_eq(seg.leader_id, Types.ABSENT, "EnemySwarm.ts never assigns leaderId")
		if i > 0:
			assert_almost_eq(seg.radius, 8.0, 0.001)


func test_snake_segment_advances_then_may_re_aim() -> void:
	_swarm.spawn_snake(BOUNDS)
	var head: Types.Enemy = _swarm.enemies[0]
	var start_x: float = head.x
	_swarm.update_snake_segment(head, 0.1)
	assert_almost_eq(head.x, start_x + 11.0, 0.0001, "moves by the old velocity before any re-aim")
	var speed: float = Vector2(head.vx, head.vy).length()
	assert_true(
		absf(speed - 110.0) < 0.001 or absf(speed - 120.0) < 0.001,
		"keeps 110 or re-aims at 120 — true for any roll"
	)
```

- [ ] **Step 2: Run the spec to verify it fails**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_enemy_turret_snake.gd
```

Expected: exit 1, parse error naming `spawn_turret`.

- [ ] **Step 3: Port the three update routines**

Insert after `update_wall_dot`, in TS order:

- `update_rotating_gate_dot` — port `updateRotatingGateDot` (`EnemySwarm.ts:290-296`). The guard at `:291` becomes `if e.orbit_center == Vector2.ZERO or is_nan(e.orbit_radius) or is_nan(e.orbit_speed): return`; the default at `:292` becomes `if is_nan(e.target_angle): e.target_angle = 0.0`. Advance by `orbit_speed * dt * speed_scale` (`:293`) and place on the orbit (`:294-295`).
- `update_turret_dot` — port `updateTurretDot` (`:298-309`). First-update snap at `:300` via `is_nan`; wrap `diff` into `[-PI, PI]` with the two `while` loops (`:303-304`); ease by `minf(1.0, dt * 2.5)` (`:305`); integrate (`:307-308`).
- `update_snake_segment` — port `updateSnakeSegment` (`:311-335`). `if e.leader_id == Types.ABSENT:` integrate, then with probability `0.05` (`:315`) re-aim at speed `120` (`:316`) and a random angle (`:317`). The follower branch (`:321-334`) ports verbatim with a linear search for the leader (`:322`), target distance `18` (`:327`), factor `0.4` (`:330-331`). Add `# PORT-NOTE: nothing in EnemySwarm.ts assigns leaderId, so every segment is a leader and this branch is unreachable; it also moves without dt — preserved deliberately`.

- [ ] **Step 4: Port the four spawners**

Insert after `spawn_wall_formation`, in TS order (`spawnSequentialGauntletWall`, `spawnRotatingGate`, `spawnTurret`, `spawnSnake`):

- `spawn_sequential_gauntlet_wall(bounds)` — port `:972-1063`. `dir = _wall_direction_cycle % 4` then increment (`:973-974`); `spacing = 22 * scale` (`:975`); `speed = 150 * maxf(0.72, scale)` (`:976`). Four branches with gap indices `floori(num_dots * 0.25)` (`:981`), `* 0.7` (`:1002`), `* 0.75` (`:1023`), `* 0.3` (`:1044`); skip `absi(i - gap_index) <= 3` (`:983`); offsets `±30` (`:988`, `:1008`, `:1030`, `:1050`); `is_hazard = true`. Add `# PORT-NOTE: the top-down wall uses radius 8.5 * scale (:991) while the other three use unscaled 8.5 (:1012, :1033, :1054) — preserved deliberately`.
- `spawn_rotating_gate(bounds)` — port `:1068-1094`. Centre `bounds / 2` (`:1069-1070`); speed `(1.0 if randf() < 0.5 else -1.0) * 0.75` (`:1071`); offsets `[-80, -56, -32, 32, 56, 80]` (`:1072`); radius `8.5` unscaled (`:1082`); `orbit_center = Vector2(cx, cy)` (`:1087`); `orbit_radius = absf(off)` (`:1088`); `target_angle = 0.0 if off > 0 else PI` (`:1090`); `is_hazard = true` (`:1091`). `# PORT-NOTE: the gate ignores this.scale entirely — preserved deliberately`.
- `spawn_turret(bounds)` — port `:1098-1116`. `pad = 80` (`:1099`); position uniformly inside the padded arena (`:1100-1101`); `vx`/`vy = (randf() - 0.5) * 30` (`:1108-1109`); radius `12 * scale` (`:1110`); `health = 3` (`:1114`).
- `spawn_snake(_bounds)` — port `:1118-1139`. The TS names the parameter `_bounds` and then uses it; keep the name and add `# PORT-NOTE: named _bounds in the TS yet read at :1119-1120 — preserved deliberately`. Start `60 + randf() * (_bounds.x - 120)` (`:1119-1120`); `length = 8` (`:1121`); x `start_x - float(i) * 14.0 * scale` (`:1127`); vx `110 * maxf(0.72, scale)` (`:1129`); radius `(10 if i == 0 else 8) * scale` (`:1131`).

- [ ] **Step 5: Add the dispatch arms**

In `update()`'s `match`, after `WALL_DOT`: `TURRET_DOT` branches on `e.orbit_center != Vector2.ZERO` → `update_rotating_gate_dot(e, dt)`, else `update_turret_dot(e, player_pos, dt)` (`:162-168`). After `SPIKE_MINE`: `SNAKE_SEGMENT → update_snake_segment(e, dt)` (`:173-175`).

- [ ] **Step 6: Run the suite**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh
```

Expected: `OK: N/N scripts collected, all tests passed.` (N one higher than Task 1).

- [ ] **Step 7: Format, lint, commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
gdformat godot/src godot/tests
gdlint godot/src godot/tests
git add godot/src/sim/enemy_swarm.gd godot/tests/test_enemy_turret_snake.gd
git commit -m "M3: port turrets, gates and snakes to complete the formation set"
```

---

### Task 3: Charger, artillery and the bullet chain

**Files:**
- Modify: `godot/src/sim/enemy_swarm.gd` — `update()` signature (`_particles` → `particles`), three `match` arms, new members after `update_snake_segment` and after `spawn_seeker`
- Test: `godot/tests/test_enemy_charger_artillery.gd`

**Interfaces:**
- Consumes: `ParticleEngine.emit_thruster_sparks(x: float, y: float, angle: float, color: Color = Color("#ff5500"))` (`godot/src/sim/particle_engine.gd:196`); `Types.EnemyState`.
- Produces (all on `EnemySwarm`):
  - `func update_charger(e: Types.Enemy, player_pos: Vector2, dt: float, particles: ParticleEngine) -> void`
  - `func update_artillery(e: Types.Enemy, player_pos: Vector2, dt: float) -> void`
  - `func update_bullet(e: Types.Enemy, dt: float, _bounds: Vector2) -> void`
  - `func spawn_charger(bounds: Vector2, player_pos: Vector2) -> Types.Enemy`
  - `func spawn_artillery(bounds: Vector2, player_pos: Vector2) -> Types.Enemy`
  - `func spawn_bullet(origin_x: float, origin_y: float, target_pos: Vector2) -> Types.Enemy`
  - `update()` arms for `CHARGER`, `ARTILLERY`, `BULLET` (with the bullet age/distance cull).

- [ ] **Step 1: Write the failing spec**

Create `godot/tests/test_enemy_charger_artillery.gd`:

```gdscript
## test_enemy_charger_artillery.gd
## PORTS: nothing — new file, covers chargers, artillery and bullets in src/sim/enemy_swarm.gd
extends GutTest
## Covers the charger's aim/charge/cool cycle, artillery's distance band and
## firing, and bullet flight and expiry.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)
## 1/8 s: exactly representable, so timer comparisons against 1.1, 0.75 and
## 0.9 land where the arithmetic says they do.
const DT: float = 0.125

var _particles: ParticleEngine = null
var _swarm: EnemySwarm = null


func before_each() -> void:
	_particles = ParticleEngine.new()
	_swarm = EnemySwarm.new()


func _speed(e: Types.Enemy) -> float:
	return Vector2(e.vx, e.vy).length()


func test_spawn_charger_starts_aiming_at_the_player() -> void:
	var c: Types.Enemy = _swarm.spawn_charger(BOUNDS, PLAYER)
	assert_eq(c.type, Types.EnemyType.CHARGER)
	assert_almost_eq(c.radius, 11.0, 0.001)
	assert_eq(c.state, Types.EnemyState.AIMING)
	assert_almost_eq(c.aim_timer, 1.1, 0.001)
	assert_almost_eq(c.aim_angle, atan2(PLAYER.y - c.y, PLAYER.x - c.x), 0.0001)
	assert_true(c.x < 0.0 or c.x > BOUNDS.x or c.y < 0.0 or c.y > BOUNDS.y, "25 px outside an edge")


func test_charger_cycles_aiming_charging_cooling() -> void:
	var c: Types.Enemy = _swarm.spawn_charger(BOUNDS, PLAYER)
	c.x = 100.0
	c.y = 300.0
	_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.AIMING)
	assert_almost_eq(_speed(c), 35.0, 0.001, "creeps at 35 while locking on")
	assert_almost_eq(c.x, 100.0 + 35.0 * DT, 0.0001)
	for i: int in range(7):
		_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.AIMING, "1.1 - 8 * 0.125 = 0.1 > 0")
	_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.CHARGING, "ninth tick expires the aim timer")
	assert_almost_eq(_speed(c), 480.0, 0.001)
	assert_almost_eq(c.special_timer, 0.75, 0.001)
	for i: int in range(6):
		_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.COOLING, "0.75 - 6 * 0.125 = 0")
	assert_almost_eq(c.special_timer, 0.9, 0.001)
	_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_lt(_speed(c), 480.0, "cooling decays velocity by 0.08^dt")
	for i: int in range(7):
		_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.AIMING, "0.9 - 8 * 0.125 < 0: back to aiming")
	assert_almost_eq(c.aim_timer, 1.1, 0.001)


func test_charging_charger_emits_thruster_sparks() -> void:
	var c: Types.Enemy = _swarm.spawn_charger(BOUNDS, PLAYER)
	c.x = 100.0
	c.y = 300.0
	c.state = Types.EnemyState.CHARGING
	c.special_timer = 100.0
	c.aim_angle = 0.0
	for i: int in range(100):
		_swarm.update_charger(c, PLAYER, 0.01, _particles)
	assert_gt(_particles.particles.size(), 0, "p = 0.6 per tick; 0.4^100 chance of none")
	assert_lte(_particles.particles.size(), 100, "at most one spark per tick")


func test_charger_defaults_state_and_aim_timer_when_absent() -> void:
	var c: Types.Enemy = Types.Enemy.new()
	c.type = Types.EnemyType.CHARGER
	c.x = 100.0
	c.y = 300.0
	_swarm.update_charger(c, PLAYER, DT, _particles)
	assert_eq(c.state, Types.EnemyState.AIMING, "EnemySwarm.ts:338")
	assert_almost_eq(c.aim_timer, 1.1 - DT, 0.0001, "EnemySwarm.ts:339 then one tick")


func test_spawn_artillery_is_a_two_health_ranged_unit() -> void:
	var a: Types.Enemy = _swarm.spawn_artillery(BOUNDS, PLAYER)
	assert_eq(a.type, Types.EnemyType.ARTILLERY)
	assert_almost_eq(a.health, 2.0, 0.001)
	assert_almost_eq(a.radius, 13.0, 0.001)
	assert_between(a.fire_cooldown, 2.2, 3.0)
	assert_almost_eq(a.aim_angle, atan2(PLAYER.y - a.y, PLAYER.x - a.x), 0.0001)


func _place(a: Types.Enemy) -> void:
	a.x = 500.0
	a.y = 300.0
	a.vx = 0.0
	a.vy = 0.0


func test_artillery_keeps_its_distance_band() -> void:
	var a: Types.Enemy = _swarm.spawn_artillery(BOUNDS, PLAYER)
	a.fire_cooldown = 100.0
	_place(a)
	_swarm.update_artillery(a, Vector2(600.0, 300.0), 0.1)
	assert_lt(a.vx, 0.0, "inside 220: retreats")
	_place(a)
	_swarm.update_artillery(a, Vector2(900.0, 300.0), 0.1)
	assert_gt(a.vx, 0.0, "beyond 320: closes")
	_place(a)
	_swarm.update_artillery(a, Vector2(770.0, 300.0), 0.1)
	assert_almost_eq(a.vx, 0.0, 0.0001, "inside the band: only strafes")
	assert_almost_eq(absf(a.vy), 40.0 * 3.0 * 0.1, 0.0001, "strafe 40 eased by 3.0 * dt")


func test_artillery_fires_a_bullet_at_the_player_and_recoils() -> void:
	var target: Vector2 = Vector2(800.0, 300.0)
	var a: Types.Enemy = _swarm.spawn_artillery(BOUNDS, target)
	_place(a)
	a.fire_cooldown = 0.05
	_swarm.update_artillery(a, target, 0.1)
	assert_eq(_swarm.enemies.size(), 2, "one bullet spawned")
	var b: Types.Enemy = _swarm.enemies[1]
	assert_eq(b.type, Types.EnemyType.BULLET)
	assert_almost_eq(b.x, a.x + 22.0, 0.0001, "muzzle is 22 along the aim from the post-move position")
	assert_almost_eq(b.y, a.y, 0.0001)
	assert_almost_eq(_speed(b), 260.0, 0.001)
	assert_almost_eq(b.radius, 5.5, 0.001)
	assert_lt(a.vx, -80.0, "recoil of 90 against the aim")
	assert_between(a.fire_cooldown, 2.8, 3.6, "reload is 2.8 + rand * 0.8, not the spawn value")


func test_spawn_bullet_flies_toward_its_target() -> void:
	var b: Types.Enemy = _swarm.spawn_bullet(100.0, 100.0, Vector2(100.0, 400.0))
	assert_eq(b.type, Types.EnemyType.BULLET)
	assert_almost_eq(b.vx, 0.0, 0.0001)
	assert_almost_eq(b.vy, 260.0, 0.0001)
	assert_almost_eq(b.radius, 5.5, 0.001)
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_almost_eq(b.y, 126.0, 0.0001, "flies straight; not clamped, not steered")


func test_bullets_expire_by_age_or_distance() -> void:
	var old: Types.Enemy = _swarm.spawn_bullet(500.0, 300.0, Vector2(600.0, 300.0))
	old.age = 4.5
	_swarm.spawn_bullet(-61.0, 300.0, Vector2(-100.0, 300.0))
	var live: Types.Enemy = _swarm.spawn_bullet(500.0, 300.0, Vector2(600.0, 300.0))
	_swarm.update(0.01, PLAYER, BOUNDS, _particles)
	assert_eq(_swarm.enemies.size(), 1, "age > 4.5 and x < -60 are both culled")
	assert_eq(_swarm.enemies[0], live)
```

- [ ] **Step 2: Run the spec to verify it fails**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_enemy_charger_artillery.gd
```

Expected: exit 1, parse error naming `spawn_charger`.

- [ ] **Step 3: Port the three update routines**

Rename `update()`'s fourth parameter from `_particles` to `particles` — it is used from here on. Insert after `update_snake_segment`, in TS order:

- `update_charger` — port `updateCharger` (`EnemySwarm.ts:337-391`). Defaults at `:338-339`: `if e.state == Types.ABSENT: e.state = Types.EnemyState.AIMING`; `if is_nan(e.aim_timer): e.aim_timer = 1.1`. Add `# PORT-NOTE: spawn_charger always sets both (:601-603), so these defaults are dead for spawned chargers — preserved deliberately`. Aiming: `creep_speed = 35` (`:347`), on `aim_timer <= 0` → `CHARGING`, `special_timer = 0.75` (`:356`), `charge_speed = 480` (`:357`). Charging: with probability `0.6` (`:365`) call `particles.emit_thruster_sparks(e.x, e.y, back_angle, Color("#ff5500"))` where `back_angle = (e.aim_angle if not is_nan(e.aim_angle) else 0.0) + PI` (`:366` — `||` treats `undefined`, `NaN` and `0` alike, and all three give `0`); on `special_timer <= 0` → `COOLING`, `special_timer = 0.9` (`:374`). Cooling: `vx *= pow(0.08, dt)` (`:378-379`); on expiry → `AIMING`, `aim_timer = 1.1` (`:387`). The `specialTimer !== undefined` guards (`:370`, `:383`) become `not is_nan(...)`.
- `update_artillery` — port `updateArtillery` (`:393-436`). Default cooldown `2.6 + randf() * 0.8` when `is_nan` (`:394`) with `# PORT-NOTE: three different cooldowns — 2.2 at spawn (:695), 2.6 here, 2.8 on reload (:426) — preserved deliberately`. Band: retreat at `65` inside `220` (`:406-408`), close at `60` beyond `320` (`:409-411`), strafe `40` with `strafe_dir = 1 if e.id % 2 == 0 else -1` (`:413-415`); steer `3.0 * dt` (`:418`); fire when the cooldown expires: `barrel_len = 22` (`:427`), `spawn_bullet(fire_x, fire_y, player_pos)` (`:430`), recoil `90` (`:433-434`).
- `update_bullet(e, dt, _bounds)` — port `updateBullet` (`:438-441`); the TS parameter is `_bounds` and unused; keep it.

- [ ] **Step 4: Port the three spawners**

Insert after `spawn_seeker`, in TS order (`spawnCharger`, then — Task 4 will put `spawn_pulsar` and `spawn_specter` between — `spawnArtillery`, `spawnBullet`). To keep TS order without churn, insert `spawn_charger` now and `spawn_artillery`, `spawn_bullet` after it; Task 4 inserts `spawn_pulsar` and `spawn_specter` between `spawn_charger` and `spawn_artillery`.

- `spawn_charger(bounds, player_pos)` — port `:576-607`: edge pick `randi() % 4`, `margin = 25` (`:578`), `aim_angle = atan2(player_pos.y - y, player_pos.x - x)` (`:588`), radius `11 * scale` (`:596`), `state = Types.EnemyState.AIMING` (`:601`), `aim_timer = 1.1` (`:603`).
- `spawn_artillery(bounds, player_pos)` — port `:669-699`: `margin = 28` (`:671`), radius `13 * scale` (`:689`), `health = 2` (`:693`), `fire_cooldown = 2.2 + randf() * 0.8` (`:695`).
- `spawn_bullet(origin_x, origin_y, target_pos)` — port `:701-722`: `dist = maxf(1.0, sqrt(...))` (`:704`), `speed = 260 * maxf(0.72, scale)` (`:705`), radius `5.5 * scale` (`:714`).

- [ ] **Step 5: Add the dispatch arms and the bullet cull**

In `update()`'s `match`, after `SNAKE_SEGMENT` (TS order `:176-188`): `CHARGER → update_charger(e, player_pos, dt, particles)`; `ARTILLERY → update_artillery(e, player_pos, dt)`; `BULLET → update_bullet(e, dt, bounds)` followed by the cull at `:184-187`: if `e.age > 4.5` or the position is beyond `-60` / `bounds + 60` on either axis, `enemies.remove_at(i)` and `continue`. In Godot 4 a `continue` inside a `match` arm continues the enclosing `for` (`match` is not a loop and the 3.x fall-through meaning was removed); if `--check-only` rejects it, hoist the cull into a `var culled: bool` tested immediately after the `match`, with a `# PORT-NOTE` saying so. Add `# PORT-NOTE: the 140-px cull at :202 also names bullets, but this 60-px cull always fires first — preserved deliberately`.

- [ ] **Step 6: Run the suite**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh
```

Expected: `OK: N/N scripts collected, all tests passed.`

- [ ] **Step 7: Format, lint, commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
gdformat godot/src godot/tests
gdlint godot/src godot/tests
git add godot/src/sim/enemy_swarm.gd godot/tests/test_enemy_charger_artillery.gd
git commit -m "M3: port charger and artillery so elites telegraph and fire"
```

---

### Task 4: Carrier and satellites, pulsar, specter, `on_enemy_killed`, `freeze_all`

**Files:**
- Modify: `godot/src/sim/enemy_swarm.gd` — three `match` arms (and removal of the `_:` `TODO(M3)` arm), new members after `update_bullet`, after `spawn_charger`, after `spawn_artillery`/`spawn_bullet`; replace the `on_enemy_killed` stub; add `freeze_all`
- Test: `godot/tests/test_enemy_carrier_pulsar_specter.gd`

**Interfaces:**
- Consumes: `ParticleEngine.emit_sparks(x, y, count: int, color: Color, speed_max: float = 180.0)` (`particle_engine.gd:49`), `ParticleEngine.emit_explosion(x, y, color, count)` (`:74`).
- Produces (all on `EnemySwarm`):
  - `func update_carrier(e: Types.Enemy, player_pos: Vector2, dt: float) -> void`
  - `func update_pulsar(e: Types.Enemy, player_pos: Vector2, dt: float, particles: ParticleEngine) -> void`
  - `func update_specter(e: Types.Enemy, player_pos: Vector2, dt: float) -> void`
  - `func spawn_pulsar(bounds: Vector2, _player_pos: Vector2) -> Types.Enemy`
  - `func spawn_specter(bounds: Vector2, _player_pos: Vector2) -> Types.Enemy`
  - `func spawn_carrier(bounds: Vector2, _player_pos: Vector2) -> Types.Enemy`
  - `func on_enemy_killed(enemy: Types.Enemy, particles: ParticleEngine = null) -> void` (signature unchanged from M2; body ported)
  - `func freeze_all(duration: float = 7.0) -> void`
  - `update()` dispatch complete for all 13 types; no `_:` arm remains.

- [ ] **Step 1: Write the failing spec**

Create `godot/tests/test_enemy_carrier_pulsar_specter.gd`:

```gdscript
## test_enemy_carrier_pulsar_specter.gd
## PORTS: nothing — new file, covers carriers, pulsars, specters and kill reactions in src/sim/enemy_swarm.gd
extends GutTest
## Covers the carrier and its satellites, pulsar pulses and splitting, specter
## phasing, on_enemy_killed and freeze_all.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)

var _particles: ParticleEngine = null
var _swarm: EnemySwarm = null


func before_each() -> void:
	_particles = ParticleEngine.new()
	_swarm = EnemySwarm.new()


func _dist(a: Types.Enemy, b: Types.Enemy) -> float:
	return Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))


func test_spawn_carrier_brings_four_orbiting_satellites() -> void:
	var carrier: Types.Enemy = _swarm.spawn_carrier(BOUNDS, PLAYER)
	assert_eq(carrier.type, Types.EnemyType.CARRIER)
	assert_almost_eq(carrier.health, 4.0, 0.001)
	assert_almost_eq(carrier.radius, 18.0, 0.001)
	assert_eq(_swarm.enemies.size(), 5)
	for i: int in range(1, 5):
		var sat: Types.Enemy = _swarm.enemies[i]
		assert_eq(sat.type, Types.EnemyType.SEEKER)
		assert_eq(sat.parent_carrier_id, carrier.id)
		assert_almost_eq(sat.radius, 6.0, 0.001)
		assert_almost_eq(sat.orbit_radius, 38.0, 0.001)
		assert_almost_eq(sat.orbit_angle, float(i - 1) * TAU / 4.0, 0.0001)
		assert_almost_eq(_dist(sat, carrier), 38.0, 0.001)


func test_carrier_drifts_toward_the_player_and_carries_its_satellites() -> void:
	var carrier: Types.Enemy = _swarm.spawn_carrier(BOUNDS, PLAYER)
	carrier.x = 200.0
	carrier.y = 300.0
	_swarm.update_carrier(carrier, PLAYER, 0.1)
	assert_almost_eq(carrier.vx, 55.0 * 1.5 * 0.1, 0.0001, "target 55 eased by 1.5 * dt")
	for i: int in range(1, 5):
		var sat: Types.Enemy = _swarm.enemies[i]
		assert_almost_eq(_dist(sat, carrier), 38.0, 0.001)
		assert_eq(sat.vx, 0.0)
		assert_eq(sat.vy, 0.0)
		assert_almost_eq(sat.orbit_angle, float(i - 1) * TAU / 4.0 + 2.0 * 0.1, 0.0001)


func test_tethered_satellites_are_neither_clamped_nor_separated() -> void:
	var carrier: Types.Enemy = _swarm.spawn_carrier(BOUNDS, PLAYER)
	carrier.x = 30.0
	carrier.y = 300.0
	_swarm.update(0.01, PLAYER, BOUNDS, _particles)
	for i: int in range(1, 5):
		var sat: Types.Enemy = _swarm.enemies[i]
		assert_almost_eq(_dist(sat, carrier), 38.0, 0.001, "left on orbit even at x < 0")


func test_killing_a_carrier_frees_and_flings_its_satellites() -> void:
	var carrier: Types.Enemy = _swarm.spawn_carrier(BOUNDS, PLAYER)
	_swarm.on_enemy_killed(carrier, _particles)
	for i: int in range(1, 5):
		var sat: Types.Enemy = _swarm.enemies[i]
		assert_eq(sat.parent_carrier_id, Types.ABSENT)
		assert_between(Vector2(sat.vx, sat.vy).length(), 160.0, 240.0)
	assert_eq(_swarm.enemies.size(), 5, "the caller removes the carrier (TiltGame.ts:2021)")
	assert_eq(_particles.particles.size(), 4 * 8 + 40 + 1, "8 sparks per satellite, a 40-spark explosion and its ring")


func test_on_enemy_killed_tolerates_a_null_particle_engine() -> void:
	var carrier: Types.Enemy = _swarm.spawn_carrier(BOUNDS, PLAYER)
	_swarm.on_enemy_killed(carrier)
	assert_eq(_swarm.enemies[1].parent_carrier_id, Types.ABSENT)


func test_spawn_pulsar_and_periodic_pulse() -> void:
	var p: Types.Enemy = _swarm.spawn_pulsar(BOUNDS, PLAYER)
	assert_eq(p.type, Types.EnemyType.PULSAR)
	assert_almost_eq(p.health, 2.0, 0.001)
	assert_almost_eq(p.radius, 12.5, 0.001)
	assert_almost_eq(p.pulse_timer, 2.2, 0.001)
	p.x = 200.0
	p.y = 300.0
	for i: int in range(17):
		_swarm.update_pulsar(p, PLAYER, 0.125, _particles)
	assert_eq(_particles.particles.size(), 0, "2.125 s elapsed: no pulse yet")
	_swarm.update_pulsar(p, PLAYER, 0.125, _particles)
	assert_eq(_particles.particles.size(), 14, "one 14-spark pulse at 2.2 s")
	assert_almost_eq(p.pulse_timer, 2.2, 0.001, "timer re-armed")
	assert_gt(p.vx, 0.0, "drifts toward the player")


func test_killing_a_pulsar_splits_it_into_two_mini_seekers() -> void:
	var p: Types.Enemy = _swarm.spawn_pulsar(BOUNDS, PLAYER)
	p.x = 400.0
	p.y = 300.0
	_swarm.on_enemy_killed(p, _particles)
	assert_eq(_swarm.enemies.size(), 3)
	for i: int in range(1, 3):
		var mini: Types.Enemy = _swarm.enemies[i]
		assert_eq(mini.type, Types.EnemyType.SEEKER)
		assert_almost_eq(mini.radius, 6.5, 0.001)
		assert_almost_eq(_dist(mini, p), 10.0, 0.001)
		assert_between(Vector2(mini.vx, mini.vy).length(), 135.0, 180.0)
	assert_eq(_particles.particles.size(), 24 + 1, "24-spark explosion plus its ring")


func test_specter_phases_with_age() -> void:
	var s: Types.Enemy = _swarm.spawn_specter(BOUNDS, PLAYER)
	assert_eq(s.type, Types.EnemyType.SPECTER)
	assert_almost_eq(s.radius, 8.0, 0.001)
	assert_almost_eq(s.stealth_opacity, 0.8, 0.001)
	s.x = 200.0
	s.y = 300.0
	s.age = 0.5
	_swarm.update_specter(s, PLAYER, 0.1)
	assert_almost_eq(s.stealth_opacity, 0.25 + 0.75 * pow(sin(0.5 * 3.2), 2.0), 0.0001)
	assert_almost_eq(s.vx, 145.0 * 3.8 * 0.1, 0.0001, "target 145 eased by 3.8 * dt")


func test_freeze_all_halts_every_enemy_for_the_duration() -> void:
	var c: Types.Enemy = _swarm.spawn_charger(BOUNDS, PLAYER)
	_swarm.spawn_specter(BOUNDS, PLAYER)
	_swarm.freeze_all()
	for e: Types.Enemy in _swarm.enemies:
		assert_true(e.frozen)
		assert_almost_eq(e.freeze_timer, 7.0, 0.001)
	c.x = 300.0
	c.y = 300.0
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_almost_eq(c.x, 300.0, 0.0001, "frozen enemies do not move")
	assert_almost_eq(c.freeze_timer, 6.9, 0.001)
	_swarm.freeze_all(0.05)
	_swarm.update(0.1, PLAYER, BOUNDS, _particles)
	assert_false(c.frozen, "thaws when the timer runs out")
```

- [ ] **Step 2: Run the spec to verify it fails**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_enemy_carrier_pulsar_specter.gd
```

Expected: exit 1, parse error naming `spawn_carrier`.

- [ ] **Step 3: Port the three update routines**

Insert after `update_bullet`, in TS order:

- `update_carrier` — port `updateCarrier` (`EnemySwarm.ts:443-471`). `target_speed = 55` (`:449`), easing `1.5 * dt` (`:452-453`); then the satellite sweep over `enemies` (`:459-470`): for each with `parent_carrier_id == e.id`, default `orbit_angle` to `0.0` and `orbit_radius` to `38` when `is_nan` (`:462-463`), advance by `2.0 * dt * speed_scale` (`:464`), place on the orbit, zero `vx`/`vy`. Add `# PORT-NOTE: update() iterates in reverse (:135), so a satellite runs update_seeker first and is then overwritten here by its carrier, which always has the lower index — preserved deliberately`.
- `update_pulsar` — port `updatePulsar` (`:473-492`). Speed `72 * maxf(0.72, scale)` (`:479`), easing `2.2 * dt` (`:480-481`); `pulse_timer` default `2.2` when `is_nan` (`:486`); on expiry re-arm to `2.2` (`:489`) and `particles.emit_sparks(e.x, e.y, 14, Color("#ff4757"), 140.0)` (`:490`).
- `update_specter` — port `updateSpecter` (`:494-508`). Speed `145 * maxf(0.72, scale)` (`:500`), easing `3.8 * dt`; `stealth_opacity = 0.25 + 0.75 * pow(sin(e.age * 3.2), 2.0)` (`:507`).

- [ ] **Step 4: Port the three spawners**

- `spawn_pulsar(bounds, _player_pos)` and `spawn_specter(bounds, _player_pos)` go between `spawn_charger` and `spawn_artillery` (TS order `:609-667`). Pulsar: `margin = 26` (`:611`), radius `12.5 * scale` (`:628`), `health = 2` (`:632`), `pulse_timer = 2.2` (`:633`). Specter: `margin = 20` (`:641`), radius `8 * scale` (`:658`), `stealth_opacity = 0.8` (`:663`). Both TS parameters are `_playerPos` and unused; keep the underscore.
- `spawn_carrier(bounds, _player_pos)` goes after `spawn_bullet` (`:724-776`): `margin = 35` (`:726`), radius `18 * scale` (`:743`), `health = 4` (`:747`); then `satellite_count = 4` (`:752`) seekers pushed inline (not via `spawn_seeker` — the TS builds them by hand at `:756-771`), each at angle `k * TAU / 4` (`:754`), `orbit_radius = 38 * scale` (`:755`), radius `6 * scale` (`:763`), `parent_carrier_id = carrier.id` (`:768`), `orbit_angle = angle` (`:769`). Returns the carrier.

- [ ] **Step 5: Port `on_enemy_killed` and `freeze_all`**

Replace the M2 stub at `enemy_swarm.gd:241-245` with the port of `onEnemyKilled` (`:1141-1182`); rename the parameters to `enemy` and `particles`. Carrier branch (`:1142-1158`): each satellite gets `parent_carrier_id = Types.ABSENT` (`:1146`), a random scatter angle (`:1147`), speed `160 + randf() * 80` (`:1148`), and — `if particles != null` — `emit_sparks(e.x, e.y, 8, Color("#00e5ff"), 200.0)` (`:1152`); then `emit_explosion(enemy.x, enemy.y, Color("#ff1155"), 40)` (`:1157`). Pulsar branch (`:1159-1181`): two seekers pushed inline at angle `i * PI + (randf() * 0.8 - 0.4)` (`:1162`), speed `135 + randf() * 45` (`:1163`), offset `10` (`:1167-1168`), radius `6.5 * scale` (`:1171`); then `emit_explosion(enemy.x, enemy.y, Color("#ff4757"), 24)` (`:1179`). Note in a `# PORT-NOTE` that the method never removes `enemy` — `TiltGame.ts:1984` calls it and `:2021` splices.

Add `freeze_all(duration: float = 7.0)` after it — port `:1184-1189`. `# PORT-NOTE: no TypeScript caller exists (WeaponSystem.ts:542-543 freezes inline); ported because spec §8 M3 names it. TODO(M4): the freeze weapon decides whether to route through this.`

- [ ] **Step 6: Complete the dispatch**

Add the last three arms after `BULLET` in TS order (`:189-197`): `CARRIER → update_carrier(e, player_pos, dt)`, `PULSAR → update_pulsar(e, player_pos, dt, particles)`, `SPECTER → update_specter(e, player_pos, dt)`. Delete the `_:` arm and its `TODO(M3)` comment — all thirteen `Types.EnemyType` values now have an arm.

- [ ] **Step 7: Run the suite**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh
```

Expected: `OK: N/N scripts collected, all tests passed.` `test_run_controller.gd` still passes: `handle_enemy_killed` → `swarm.on_enemy_killed(enemy, particles)` is unchanged at the call site.

- [ ] **Step 8: Format, lint, commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
gdformat godot/src godot/tests
gdlint godot/src godot/tests
git add godot/src/sim/enemy_swarm.gd godot/tests/test_enemy_carrier_pulsar_specter.gd
git commit -m "M3: port carrier, pulsar and specter with kill reactions and freeze"
```

---

### Task 5: Wave director — elite selection, formation waves, dispatchers, armada

**Files:**
- Modify: `godot/src/sim/enemy_swarm.gd` — `update()` blocks 1 and 2 (currently `:108-132`); new members after `spawn_carrier`
- Test: `godot/tests/test_enemy_formations.gd`, `godot/tests/test_wave_director.gd`

**Interfaces:**
- Consumes: every spawner from Tasks 1–4 by the exact names listed in their Produces blocks.
- Produces (all on `EnemySwarm`):
  - `func spawn_mode_armada(mode: Types.GameMode, bounds: Vector2, player_pos: Vector2) -> void`
  - `func trigger_random_formation(player_pos: Vector2, bounds: Vector2, current_score: int = 0) -> void`
  - `func trigger_gauntlet_formation(_player_pos: Vector2, bounds: Vector2, _current_score: int = 0) -> void`
  - `update()` with the full continuous-spawn block (`:59-104`) and formation-wave block (`:106-132`); no `TODO(M3)` remains in the file.

- [ ] **Step 1: Write the failing formation spec**

Create `godot/tests/test_enemy_formations.gd`:

```gdscript
## test_enemy_formations.gd
## PORTS: nothing — new file, covers the formation dispatchers and the armada in src/sim/enemy_swarm.gd
extends GutTest
## Covers trigger_random_formation, trigger_gauntlet_formation and
## spawn_mode_armada. Choice-dependent assertions hold for any roll; the seed
## only makes a failing run reproducible.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)
## Array[int] rather than Array[Types.EnemyType]: enum-typed arrays are not
## relied on; EnemyType values are ints and has() compares by value.
const FORMATION_TYPES: Array[int] = [
	Types.EnemyType.ARROW_DRONE,
	Types.EnemyType.CIRCLE_DOT,
	Types.EnemyType.WALL_DOT,
	Types.EnemyType.TURRET_DOT,
	Types.EnemyType.SNAKE_SEGMENT,
]

var _swarm: EnemySwarm = null


func before_each() -> void:
	_swarm = EnemySwarm.new()
	seed(20260920)


func test_random_formation_only_produces_the_five_classic_formations() -> void:
	var seen: Dictionary = {}
	var stray: int = 0
	for i: int in range(200):
		_swarm.trigger_random_formation(PLAYER, BOUNDS, 0)
		assert_gt(_swarm.enemies.size(), 0, "every roll spawns something")
		for e: Types.Enemy in _swarm.enemies:
			if not FORMATION_TYPES.has(e.type):
				stray += 1
			seen[e.type] = true
		_swarm.enemies.clear()
	assert_eq(stray, 0, "no non-formation type ever appears")
	assert_eq(seen.size(), 5, "200 rolls at 1/5 each: a missing formation has odds under 1e-18")


func test_gauntlet_formation_never_walls_or_encircles() -> void:
	var seen: Dictionary = {}
	var forbidden: int = 0
	for i: int in range(200):
		_swarm.trigger_gauntlet_formation(PLAYER, BOUNDS, 0)
		for e: Types.Enemy in _swarm.enemies:
			if e.type == Types.EnemyType.WALL_DOT or e.type == Types.EnemyType.CIRCLE_DOT:
				forbidden += 1
			seen[e.type] = true
		_swarm.enemies.clear()
	assert_eq(forbidden, 0)
	assert_eq(seen.size(), 3, "arrow, turret and snake all occur")


func test_code_red_armada_rings_the_player_with_24_seekers() -> void:
	_swarm.spawn_mode_armada(Types.GameMode.CODE_RED, BOUNDS, PLAYER)
	assert_eq(_swarm.enemies.size(), 24)
	for e: Types.Enemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.SEEKER)
		assert_almost_eq(Vector2(e.x, e.y).distance_to(PLAYER), 600.0 * 0.44, 0.01)


func test_classic_and_gauntlet_armadas_are_eight_edge_seekers() -> void:
	_swarm.spawn_mode_armada(Types.GameMode.CLASSIC, BOUNDS, PLAYER)
	assert_eq(_swarm.enemies.size(), 8)
	_swarm.reset()
	_swarm.spawn_mode_armada(Types.GameMode.GAUNTLET, BOUNDS, PLAYER)
	assert_eq(_swarm.enemies.size(), 8)
	for e: Types.Enemy in _swarm.enemies:
		assert_eq(e.type, Types.EnemyType.SEEKER)
		assert_true(e.x < 0.0 or e.x > BOUNDS.x or e.y < 0.0 or e.y > BOUNDS.y, "edge spawn")
```

- [ ] **Step 2: Write the failing director spec**

Create `godot/tests/test_wave_director.gd`:

```gdscript
## test_wave_director.gd
## PORTS: nothing — new file, covers the wave director inside EnemySwarm.update()
extends GutTest
## Covers the score thresholds that unlock elite types per mode, the twin and
## double seeker spawns, the first wave time, and which formations each mode
## may schedule. Each update() call runs the spawn block at most once and the
## wave block at most once, and enemies are cleared between calls, so what is
## present after a call is exactly what that call spawned. Threshold
## assertions hold for any roll: the rarest branch checked (a charger once
## every elite is unlocked) has p >= 0.09 per spawn event, and 400 one-second
## calls sample at least 200 events (the classic interval is at most 1.5 s), so
## a false negative has odds under 1e-8; the seed only makes a failing run
## reproducible.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)
const PLAYER: Vector2 = Vector2(500.0, 300.0)
const ELITES: Array[int] = [
	Types.EnemyType.CHARGER,
	Types.EnemyType.SPECTER,
	Types.EnemyType.ARTILLERY,
	Types.EnemyType.PULSAR,
	Types.EnemyType.CARRIER,
]
const FORMATION_TYPES: Array[int] = [
	Types.EnemyType.ARROW_DRONE,
	Types.EnemyType.CIRCLE_DOT,
	Types.EnemyType.WALL_DOT,
	Types.EnemyType.TURRET_DOT,
	Types.EnemyType.SNAKE_SEGMENT,
]

var _particles: ParticleEngine = null
var _swarm: EnemySwarm = null


func before_each() -> void:
	_particles = ParticleEngine.new()
	_swarm = EnemySwarm.new()
	seed(20260920)


func _count_type(type: Types.EnemyType) -> int:
	var n: int = 0
	for e: Types.Enemy in _swarm.enemies:
		if e.type == type:
			n += 1
	return n


func _count_in(types: Array[int]) -> int:
	var n: int = 0
	for e: Types.Enemy in _swarm.enemies:
		if types.has(e.type):
			n += 1
	return n


## Runs `calls` one-second updates at `score` in `mode` and returns the set of
## elite types that spawned (keys are Types.EnemyType values).
func _elites_seen(score: int, mode: Types.GameMode, calls: int) -> Dictionary:
	var seen: Dictionary = {}
	for i: int in range(calls):
		_swarm.update(1.0, PLAYER, BOUNDS, _particles, score, mode)
		for e: Types.Enemy in _swarm.enemies:
			if ELITES.has(e.type):
				seen[e.type] = true
		_swarm.enemies.clear()
	return seen


func _assert_elites(seen: Dictionary, expected: Array[int], label: String) -> void:
	assert_eq(seen.size(), expected.size(), label + ": exactly these elites")
	for t: int in expected:
		assert_true(seen.has(t), label + ": type %d unlocked" % t)


func test_classic_unlocks_elites_at_5k_10k_16k_22k_32k() -> void:
	var classic: Types.GameMode = Types.GameMode.CLASSIC
	_assert_elites(_elites_seen(4999, classic, 400), [], "below 5000")
	_swarm.reset()
	_assert_elites(_elites_seen(5000, classic, 400), [Types.EnemyType.CHARGER], "5000")
	_swarm.reset()
	_assert_elites(
		_elites_seen(10000, classic, 400),
		[Types.EnemyType.CHARGER, Types.EnemyType.SPECTER],
		"10000"
	)
	_swarm.reset()
	_assert_elites(
		_elites_seen(16000, classic, 400),
		[Types.EnemyType.CHARGER, Types.EnemyType.SPECTER, Types.EnemyType.ARTILLERY],
		"16000"
	)
	_swarm.reset()
	_assert_elites(
		_elites_seen(22000, classic, 400),
		[
			Types.EnemyType.CHARGER,
			Types.EnemyType.SPECTER,
			Types.EnemyType.ARTILLERY,
			Types.EnemyType.PULSAR,
		],
		"22000"
	)
	_swarm.reset()
	_assert_elites(_elites_seen(32000, classic, 400), ELITES, "32000")


func test_code_red_unlocks_elites_at_2500_6k_10k_16k_24k() -> void:
	var red: Types.GameMode = Types.GameMode.CODE_RED
	_assert_elites(_elites_seen(2499, red, 400), [], "below 2500")
	_swarm.reset()
	_assert_elites(_elites_seen(2500, red, 400), [Types.EnemyType.CHARGER], "2500")
	_swarm.reset()
	_assert_elites(
		_elites_seen(6000, red, 400), [Types.EnemyType.CHARGER, Types.EnemyType.SPECTER], "6000"
	)
	_swarm.reset()
	_assert_elites(
		_elites_seen(10000, red, 400),
		[Types.EnemyType.CHARGER, Types.EnemyType.SPECTER, Types.EnemyType.ARTILLERY],
		"10000"
	)
	_swarm.reset()
	_assert_elites(
		_elites_seen(16000, red, 400),
		[
			Types.EnemyType.CHARGER,
			Types.EnemyType.SPECTER,
			Types.EnemyType.ARTILLERY,
			Types.EnemyType.PULSAR,
		],
		"16000"
	)
	_swarm.reset()
	_assert_elites(_elites_seen(24000, red, 400), ELITES, "24000")


func test_code_red_spawns_seekers_in_pairs() -> void:
	for i: int in range(30):
		_swarm.update(1.0, PLAYER, BOUNDS, _particles, 0, Types.GameMode.CODE_RED)
		var seekers: int = _count_type(Types.EnemyType.SEEKER)
		assert_true(seekers == 0 or seekers == 2, "twin spawns: got %d" % seekers)
		_swarm.enemies.clear()


func test_classic_doubles_seeker_spawns_only_from_12k() -> void:
	var max_below: int = 0
	for i: int in range(100):
		_swarm.update(1.0, PLAYER, BOUNDS, _particles, 11999)
		max_below = maxi(max_below, _count_type(Types.EnemyType.SEEKER))
		_swarm.enemies.clear()
	assert_eq(max_below, 1, "below 12000 a spawn event yields one seeker")
	_swarm.reset()
	var max_at: int = 0
	for i: int in range(300):
		_swarm.update(1.0, PLAYER, BOUNDS, _particles, 12000)
		max_at = maxi(max_at, _count_type(Types.EnemyType.SEEKER))
		_swarm.enemies.clear()
	assert_eq(max_at, 2, "from 12000 a quarter of non-elite events spawn two")


func test_first_formation_wave_fires_at_four_seconds() -> void:
	for i: int in range(7):
		_swarm.update(0.5, PLAYER, BOUNDS, _particles)
	assert_eq(_count_in(FORMATION_TYPES), 0, "3.5 s: no wave yet")
	_swarm.update(0.5, PLAYER, BOUNDS, _particles)
	assert_gt(_count_in(FORMATION_TYPES), 0, "wave_timer starts at 4.0 (EnemySwarm.ts:40)")


func test_code_red_waves_are_walls_pincers_or_tight_circles() -> void:
	var waves: int = 0
	for i: int in range(200):
		_swarm.update(0.5, PLAYER, BOUNDS, _particles, 0, Types.GameMode.CODE_RED)
		var arrows: int = _count_type(Types.EnemyType.ARROW_DRONE)
		var circles: int = _count_type(Types.EnemyType.CIRCLE_DOT)
		var walls: int = _count_type(Types.EnemyType.WALL_DOT)
		assert_true(arrows == 0 or arrows == 14, "code red arrows are the dual pincer")
		assert_true(circles == 0 or circles == 16, "code red circles are tight")
		assert_eq(_count_type(Types.EnemyType.TURRET_DOT), 0)
		assert_eq(_count_type(Types.EnemyType.SNAKE_SEGMENT), 0)
		if arrows + circles + walls > 0:
			waves += 1
		_swarm.enemies.clear()
	assert_gte(waves, 20, "interval 3.6-4.8 s over 100 s")


func test_gauntlet_waves_exclude_walls_and_circles() -> void:
	var waves: int = 0
	var forbidden: int = 0
	for i: int in range(400):
		_swarm.update(0.5, PLAYER, BOUNDS, _particles, 0, Types.GameMode.GAUNTLET)
		forbidden += _count_type(Types.EnemyType.WALL_DOT)
		forbidden += _count_type(Types.EnemyType.CIRCLE_DOT)
		if _count_in(FORMATION_TYPES) > 0:
			waves += 1
		_swarm.enemies.clear()
	assert_eq(forbidden, 0)
	assert_gte(waves, 12, "interval at most 16 s over 200 s")
```

- [ ] **Step 3: Run both specs to verify they fail**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s tests/test_enemy_formations.gd
tools/run_tests.sh
```

Expected: the first exits 1 naming `trigger_random_formation`; the second reports the director spec's threshold tests failing (`test_wave_director.gd` parses — it uses only existing members — but at 5000 no charger spawns because M2's block only spawns seekers).

- [ ] **Step 4: Port the armada and the two dispatchers**

Insert after `spawn_carrier`, in TS order:

- `spawn_mode_armada(mode, bounds, player_pos)` — port `spawnModeArmada` (`EnemySwarm.ts:781-799`). Code red: `count = 24` (`:784`), radius `minf(bounds.x, bounds.y) * 0.44` (`:785`), seekers via `spawn_seeker(bounds, x, y)` (`:790`); otherwise `count = 8` (`:794`) edge seekers. `# TODO(M10): the cinematic calls this (TiltEntranceCinematic.ts:196, :200); no M3 caller.`
- `trigger_random_formation(player_pos, bounds, current_score := 0)` — port `:801-826`. `choices: Array[String] = ["arrow", "circle", "wall", "turret", "snake"]` (`:806`), `choice = choices[randi() % choices.size()]` (`:807`), `match` on the string dispatching to `spawn_arrow_formation(bounds)`, `spawn_circle_encirclement(player_pos, bounds, current_score)`, `spawn_wall_formation(bounds)`, `spawn_turret(bounds)`, `spawn_snake(bounds)`. Keep the strings — no formation enum exists in the TS and LAW 4 forbids adding one.
- `trigger_gauntlet_formation(_player_pos, bounds, _current_score := 0)` — port `:828-849`: choices `["arrow", "turret", "snake"]` (`:835`). Both unused parameters keep their underscores as in the TS.

- [ ] **Step 5: Port the continuous-spawn block**

Replace `enemy_swarm.gd:108-127` with the full port of `:59-104`. Code red (`:64-80`): timer `0.32 + randf() * 0.12` (`:66`); the `if/elif` ladder in TS order — `>= 24000 and randf() < 0.28 → spawn_carrier(bounds, player_pos)` (`:67`), `>= 16000, < 0.26 → spawn_pulsar` (`:69`), `>= 10000, < 0.30 → spawn_artillery` (`:71`), `>= 6000, < 0.28 → spawn_specter` (`:73`), `>= 2500, < 0.35 → spawn_charger` (`:75`), else two `spawn_seeker(bounds)` (`:78-79`). Classic and gauntlet (`:81-103`): `base_interval` and timer as M2 has them (`:83-84`); ladder `>= 32000, < 0.22 → carrier` (`:87`), `>= 22000, < 0.26 → pulsar` (`:89`), `>= 16000, < 0.28 → artillery` (`:91`), `>= 10000, < 0.26 → specter` (`:93`), `>= 5000, < 0.32 → charger` (`:95`), else the existing `spawn_count` loop (`:98-101`). Each threshold and probability carries its own `# PORT:`. Delete M2's "In M2, all spawns are seekers" comment.

- [ ] **Step 6: Port the formation-wave block**

Replace `enemy_swarm.gd:129-132` (the `TODO(M3)` and placeholder timer) with the port of `:106-132`. Code red (`:108-118`): `roll = randf()`; `< 0.35 → spawn_wall_formation(bounds)` (`:111-112`), `< 0.70 → spawn_arrow_formation(bounds, true)` (`:113-114`), else `spawn_circle_encirclement(player_pos, bounds, current_score, true)` (`:116`); timer `3.6 + randf() * 1.2` (`:118`). Gauntlet (`:119-124`): `trigger_gauntlet_formation(player_pos, bounds, current_score)`; `score_wave_reduction = minf(2.0, (float(current_score) / 25000.0) * 2.0)` (`:122`); `base_wave_interval = maxf(8.5, 13.5 - _elapsed * 0.02 - score_wave_reduction)` (`:123`); timer `+ randf() * 2.5` (`:124`). Classic (`:125-131`): `trigger_random_formation(...)`; `maxf(5.5, 10.0 - _elapsed * 0.02 - score_wave_reduction)` (`:129`); `+ randf() * 2.0` (`:130`). `# TODO(M10): gauntlet and code-red modes are selected by run_controller in M10; the branches are ported now because they live inside update().`

- [ ] **Step 7: Confirm no marker remains**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
grep -n "TODO(M3)" godot/src/sim/enemy_swarm.gd godot/src/render/entity_layer.gd
```

Expected: no output.

- [ ] **Step 8: Run the suite**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh
```

Expected: `OK: N/N scripts collected, all tests passed.` (N two higher than Task 4). The director spec takes a few seconds — it runs about 5,500 `update()` calls with the enemy list cleared between them — which is acceptable; if it exceeds ten seconds, reduce the 400-iteration gauntlet loop to 200 and the expected wave floor to 6, and nothing else.

- [ ] **Step 9: Format, lint, commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
gdformat godot/src godot/tests
gdlint godot/src godot/tests
git add godot/src/sim/enemy_swarm.gd godot/tests/test_enemy_formations.gd godot/tests/test_wave_director.gd
git commit -m "M3: complete the wave director so score unlocks elites and waves"
```

---

### Task 6: Per-type rendering in `entity_layer.gd`

**Files:**
- Modify: `godot/src/render/entity_layer.gd:1-13` (header), `:154-215` (`_draw_enemies`), new private draw helpers after it
- Test: `godot/tests/test_render_layers.gd` (append one spec)

**Interfaces:**
- Consumes: `EnemySwarm.enemies`, every `Types.Enemy` field; `_elapsed`, `_high_contrast_halo`, `_arena_origin`, `_closed()` already in the file.
- Produces (private, on `EntityLayer`): `_draw_enemies()` dispatching in TS order to `_draw_frozen_dot(e)`, `_draw_charger(e)`, `_draw_artillery(e)`, `_draw_bullet(e)`, `_draw_carrier(e)`, `_draw_satellite(e)`, `_draw_pulsar(e)`, `_draw_specter(e)`, `_draw_default_dot(e)`; two dash helpers `_draw_dashed_line_offset(from: Vector2, to: Vector2, dash: float, gap: float, line_dash_offset: float, color: Color, width: float) -> void` and `_draw_dashed_arc(center: Vector2, radius: float, dash: float, gap: float, line_dash_offset: float, color: Color, width: float) -> void`.

**Draw-mapping rules for this task** (spec §4.5, plus the file's own precedents):

- `ctx.translate(e.x, e.y)` + `ctx.rotate(angle)` → `draw_set_transform(_arena_origin + Vector2(e.x, e.y), angle, Vector2.ONE)`, draw in local coordinates, then restore `draw_set_transform(_arena_origin, 0.0, Vector2.ONE)`. `draw_set_transform` is absolute, not cumulative, so **`_arena_origin` must be included** in the per-entity transform. (The player at `entity_layer.gd:224` omits it — an M2.5 defect, Open question 6; do not copy it.) Types that never rotate (frozen, satellite, pulsar, specter, default) draw at `Vector2(e.x, e.y)` under the standing arena transform, as the M2 code does.
- `ctx.arc` fill → `draw_circle`; `ctx.arc` stroke → `draw_arc(center, r, 0.0, TAU, 24, color, width)` (the file's precedent at `:173`).
- Closed polygon fill → `draw_colored_polygon(points, color)`; its stroke → `draw_polyline(_closed(points), color, width)` (precedent `:236-237`).
- `fillRect`/`strokeRect` → `draw_rect(Rect2(...), color)` / `draw_rect(Rect2(...), color, false, width)`.
- `createRadialGradient(0,0,1, 0,0,r)` with stops `(0, inner)`, `(s, mid)`, `(1, outer)` → the M2 precedent at `:187-199`: `draw_circle(pos, r, mid)` then `draw_circle(pos, r * s, inner)`. Spec §4.5's baked radial texture is not built in this module (Open question 3); add one `# PORT-NOTE` at `_draw_enemies` saying so.
- `createLinearGradient` across a triangle → `draw_polygon(points, colors)` with one colour per vertex; for the bullet tail the gradient axis runs along the triangle's x extent, so per-vertex interpolation reproduces it exactly.
- `setLineDash([a, b])` + `lineDashOffset = -k` → the two helpers above. Both walk the pattern in arc-length: `period = dash + gap`; the first dash starts at `s = fposmod(-line_dash_offset, period) - period`; for each `s < length` draw the segment `[maxf(s, 0.0), minf(s + dash, length)]` (as `draw_line` between the two points on the segment, or `draw_arc(center, radius, s0 / radius, s1 / radius, 6, color, width)` on the circle), then `s += period`. This preserves the animated offset that `draw_dashed_line` would lose. `# PORT-NOTE: Godot has no dash offset or dashed arc; these two helpers are the setLineDash equivalent, analogous to _closed()`.
- `ctx.globalAlpha = a` → multiply `a` into `Color.a` of every draw in that block.
- `skin` (`EnemySkinConfig`) → port only the non-skin branch of every ternary and leave one `# TODO(M7): enemy skins (skin.bodyGradient, borderColor, glowColor, pupilColor)` at `_draw_enemies`. Add `# PORT-NOTE: charger, artillery and carrier gate the skin on skin.id !== 'classic' (:1260, :1293, :1406) while pulsar, specter and the default dot gate on skin alone (:1476, :1521, :1561) — M7 must preserve the asymmetry`.
- `highContrastHalo` is already `_high_contrast_halo`; `_gameMode` is unused in the TS (`:1196`) and gets no port.

- [ ] **Step 1: Write the failing spec**

Append to `godot/tests/test_render_layers.gd`:

```gdscript
func test_entity_layer_draws_every_enemy_type_without_error() -> void:
	var layer: EntityLayer = EntityLayer.new()
	var player: PlayerShip = PlayerShip.new(500.0, 300.0)
	var swarm: EnemySwarm = EnemySwarm.new()
	var weapons: WeaponSystem = WeaponSystem.new()
	layer.bind_entities(player, swarm, weapons)
	layer.set_elapsed(2.0)
	layer.set_arena_origin(Vector2(8.0, 12.0))
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var player_pos: Vector2 = Vector2(500.0, 300.0)

	swarm.spawn_seeker(bounds)
	swarm.spawn_arrow_formation(bounds)
	swarm.spawn_sequential_gauntlet_wall(bounds)
	swarm.spawn_circle_encirclement(player_pos, bounds, 0)
	swarm.spawn_turret(bounds)
	swarm.spawn_rotating_gate(bounds)
	swarm.spawn_snake(bounds)
	swarm.spawn_charger(bounds, player_pos)
	var charging: Types.Enemy = swarm.spawn_charger(bounds, player_pos)
	charging.state = Types.EnemyState.CHARGING
	charging.vx = 100.0
	var artillery: Types.Enemy = swarm.spawn_artillery(bounds, player_pos)
	artillery.fire_cooldown = 0.3
	swarm.spawn_bullet(100.0, 100.0, player_pos)
	swarm.spawn_carrier(bounds, player_pos)
	swarm.spawn_pulsar(bounds, player_pos)
	swarm.spawn_specter(bounds, player_pos)
	var mine: Types.Enemy = Types.Enemy.new()
	mine.type = Types.EnemyType.SPIKE_MINE
	mine.radius = 8.0
	swarm.enemies.append(mine)
	var frozen: Types.Enemy = swarm.spawn_seeker(bounds)
	frozen.frozen = true
	var turret: Types.Enemy = Types.Enemy.new()
	turret.type = Types.EnemyType.TURRET_DOT
	turret.radius = 12.0
	turret.target_angle = 1.0
	swarm.enemies.append(turret)

	add_child_autofree(layer)
	layer.queue_redraw()
	await wait_frames(2)
	assert_eq(swarm.enemies.size(), 1 + 7 + 38 + 12 + 1 + 6 + 8 + 2 + 1 + 1 + 5 + 1 + 1 + 1 + 1 + 1)
```

The final count pins the fixture in spawn order — seeker, arrow wing, gauntlet wall, circle, turret, gate, snake, two chargers, artillery, bullet, carrier with four satellites, pulsar, specter, mine, frozen seeker, hand-built turret. The gauntlet wall is used rather than `spawn_wall_formation` because its first call is always top-down (`floori(1000 / 22) - 7 = 38` dots), whereas the classic wall picks an orientation at random and would make the count non-deterministic. The assertion also fails loudly if a spawner's count drifts. A runtime error inside `_draw` is printed by Godot as `SCRIPT ERROR:` rather than failing the assertion — Step 4 greps for it.

- [ ] **Step 2: Run the spec to verify it fails**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
tools/run_tests.sh 2>&1 | tee /tmp/m3-t6-before.log | tail -20
```

Expected: the suite passes (every spawner exists after Task 5) — this spec is a regression guard, not a red bar. What must be false before this task is visual: `_draw_enemies` still draws a charger as a red dot. Proceed.

- [ ] **Step 3: Restructure `_draw_enemies` and port the branches**

Update the header `PORTS:` line 3 to `web/src/tilt-to-live/EnemySwarm.ts:1191-1648 (render)`. Then rewrite `_draw_enemies()` as the loop at `:1199-1646`, in this order, each branch ending the iteration as the TS `continue` does:

1. **Frozen** (`:1204-1222`) → `_draw_frozen_dot(e)`: fill `r + 3` in `Color(136/255, 238/255, 1.0, 0.45)`; stroke `r + 1` white, width `1.5`; fill `r - 1` in `Color("#4488aa")`.
2. **Charger** (`:1225-1286`) → `_draw_charger(e)`: `angle = atan2(e.vy, e.vx) if e.state == Types.EnemyState.CHARGING else (e.aim_angle if not is_nan(e.aim_angle) else 0.0)` (`:1226`). While `AIMING`: under the rotated transform, `_draw_dashed_line_offset(Vector2(14, 0), Vector2(480, 0), 8.0, 6.0, -fmod(_elapsed * 50.0, 16.0), Color(1.0, 60/255, 30/255, 0.4 + 0.4 * sin(_elapsed * 22.0)), 1.5)` (`:1232-1240`). While `CHARGING`: `jet_len = 14 + randf() * 8` (`:1249`), plume `[(-8, -4), (-8 - jet_len, 0), (-8, 4)]` in `#ffaa00` (`:1250-1256`). Hull `[(14, 0), (-10, -11), (-6, 0), (-10, 11)]` (`:1266-1269`) filled `#ff2a00` when charging else `#dd1c00` (`:1260`), stroked `#ffaa33` width `1.8` (`:1261-1264`). Core `[(6, 0), (-2, -3.5), (0, 0), (-2, 3.5)]` (`:1277-1280`) filled white when charging else `#FFB14D` (`:1275`).
3. **Artillery** (`:1289-1350`) → `_draw_artillery(e)`: rotate by `aim_angle` or `0`. Barrel `Rect2(4, -4, 18, 8)` filled `#180e22`, stroked `#ff0066` width `1.5` (`:1295-1299`). Muzzle flash when `not is_nan(e.fire_cooldown) and e.fire_cooldown < 0.8` (`:1302`): `charge_ratio = (0.8 - fc) / 0.8`, circle at `(22, 0)` radius `3 + ratio * 4` in `Color(1.0, 0.0, 150/255, 0.5 + ratio * 0.5)` (`:1303-1307`). Hex hull radius `13` (`:1317`), vertices at `h * PI / 3`, filled `#1c0a1a` stroked `#ff0077` width `2.2` (`:1311-1327`). Struts: two lines across the hex in `Color(1, 1, 1, 0.25)` width `1` (`:1330-1335`). Optic `5 * (0.8 + 0.2 * sin(_elapsed * 14))` in `#ff00bb` (`:1338-1342`), then white radius `2` (`:1343-1346`).
4. **Bullet** (`:1353-1385`) → `_draw_bullet(e)`: rotate by `atan2(e.vy, e.vx)`. Tail `draw_polygon([(-18, 0), (0, -4), (0, 4)], [Color(1, 0, 128/255, 0), Color(1, 0, 180/255, 0.85), Color(1, 0, 180/255, 0.85)])` (`:1358-1367`). Core gradient white → `#ff2299` at `0.5` → `#880055` (`:1370-1373`) by the two-circle rule; white stroke width `1.2` (`:1379-1381`).
5. **Carrier** (`:1388-1444`) → `_draw_carrier(e)`: first, under the arena transform, a tether `draw_line` from the carrier to each enemy whose `parent_carrier_id == e.id`, colour `Color(0, 229/255, 1, 0.4 + 0.3 * sin(_elapsed * 12 + float(sat.id)))` width `1.2` (`:1390-1401`). Then rotate by `_elapsed * 0.45` (`:1403`): `_draw_dashed_arc(Vector2.ZERO, r + 8, 10.0, 8.0, -_elapsed * 30.0, Color(1, 30/255, 80/255, 0.45), 2.0)` (`:1406-1414`); diamond `[(r + 4, 0), (0, -r - 4), (-r - 4, 0), (0, r + 4)]` filled `#220816` stroked `#ff2a55` width `2.4` (`:1417-1429`); core `8` in `#ff1144` (`:1432-1435`), white `3.5` (`:1437-1440`).
6. **Satellite** (`:1447-1466`, `e.parent_carrier_id != Types.ABSENT`) → `_draw_satellite(e)`: stroke `r + 3` in `#00e5ff` width `1.5`; fill `r + 2` in `Color(0, 229/255, 1, 0.35)`; white fill `r * 0.5`. This test comes **after** the four type tests above, as in the TS.
7. **Pulsar** (`:1469-1513`) → `_draw_pulsar(e)`: `pulse_phase = (2.2 - e.pulse_timer) / 2.2 if not is_nan(e.pulse_timer) else 0.0` (`:1470`); ring radius `r + 5 + phase * 16`, alpha `(1 - phase) * 0.8` clamped at `0` (`:1471-1475`), stroke `#ff4757` width `2` with that alpha; body gradient `#ff8899` → `#ee1133` at `0.6` → `#990011` (`:1483-1487`), stroke `#ffa502` width `2.2` (`:1490-1495`); eight-point star, `a = p * PI / 4 + _elapsed * 3`, radius `r * 0.55` on even `p` and `r * 0.22` on odd (`:1500-1509`), filled white via `draw_colored_polygon`.
8. **Specter** (`:1516-1552`) → `_draw_specter(e)`: `alpha = e.stealth_opacity if not is_nan(e.stealth_opacity) else 0.65` (`:1517`) multiplied into every colour below; `_draw_dashed_arc(pos, r + 3, 4.0, 4.0, -_elapsed * 25.0, #a78bfa, 1.6)` (`:1521-1528`); body gradient `#c4b5fd` → `#8b5cf6` at `0.65` → `#4c1d95` (`:1530-1534`), stroke `#e0e7ff` width `1.5` (`:1537-1542`); white core `2.5` (`:1545-1548`).
9. **Default dot** (`:1554-1632`) → `_draw_default_dot(e)`: move the existing M2 code at `:158-215` here unchanged. Then the **turret indicator** (`:1635-1643`): if `e.type == Types.EnemyType.TURRET_DOT and not is_nan(e.target_angle) and e.orbit_center == Vector2.ZERO`, under a transform rotated by `target_angle`, `draw_line(Vector2(r, 0), Vector2(r + 18, 0), Color(1, 50/255, 50/255, 0.5), 1.5)`.

Every colour literal carries its `# PORT:` line. Where the TS builds a colour with `rgba(...)`, write `Color(r/255.0, g/255.0, b/255.0, a)` as the M2 code does at `:165-170`.

- [ ] **Step 4: Syntax-check, run, and scan for draw-time errors**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --check-only -s src/render/entity_layer.gd
tools/run_tests.sh 2>&1 | tee /tmp/m3-t6-after.log | tail -5
grep -n "SCRIPT ERROR" /tmp/m3-t6-after.log
```

Expected: `--check-only` exits 0; the suite reports `OK`; the grep prints nothing. If `_draw` provably does not execute under `--headless` (confirm once with a temporary `Log.debug` at the top of `_draw_enemies`, then remove it), record that in `HANDOFF.md` — the spec then guards parsing and binding only and Task 7's screenshots are the draw evidence.

- [ ] **Step 5: Format, lint, commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
gdformat godot/src godot/tests
gdlint godot/src godot/tests
git add godot/src/render/entity_layer.gd godot/tests/test_render_layers.gd
git commit -m "M3: draw each enemy type distinctly so behaviours are observable"
```

---

### Task 7: Device pass — unattended half, and `VERIFY-ME.md` for the hand-held half

**Files:**
- Create: `godot/VERIFY-ME.md`
- Build output (gitignored): `godot/build/peril-point-debug.apk`, `godot/build/m3-*.png`

**Interfaces:**
- Consumes: the `Android` export preset from M0b; the running app id `com.jtg.perilpoint`.
- Produces: screenshot evidence for `HANDOFF.md`; the hand-held checklist the user runs later.

Elite types unlock by score (5000 and up in classic) and formations begin at 4 s; an unattended launch dies to the first seekers within a few seconds, so this half can prove only that the build runs, draws, and logs no script error. Everything that needs a thumb goes to `VERIFY-ME.md`.

- [ ] **Step 1: Build, install, launch, capture**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"
"$GODOT" --headless --path godot --export-debug "Android" build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ install -r godot/build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ logcat -c
"$ADB" -s RRCXB04L8EJ shell am start -n com.jtg.perilpoint/com.godot.game.GodotApp
sleep 3;  "$ADB" -s RRCXB04L8EJ exec-out screencap -p > godot/build/m3-03s.png
sleep 2;  "$ADB" -s RRCXB04L8EJ exec-out screencap -p > godot/build/m3-05s.png
sleep 7;  "$ADB" -s RRCXB04L8EJ exec-out screencap -p > godot/build/m3-12s.png
"$ADB" -s RRCXB04L8EJ shell pidof com.jtg.perilpoint
"$ADB" -s RRCXB04L8EJ logcat -d | grep -i "SCRIPT ERROR\|godot" | head -40
```

Expected: export and install exit 0; `pidof` prints a pid; the logcat grep shows Godot's startup lines and **no** `SCRIPT ERROR`. If a control picker (M2.5 Task 6) blocks the run from starting, tap its TOUCH option with `"$ADB" -s RRCXB04L8EJ shell input tap <x> <y>` using coordinates read from the 3 s screenshot, then repeat the captures.

- [ ] **Step 2: Read the screenshots**

Open each PNG with the Read tool and record, in plain words, what is visible: seekers at 3 s; at 5 s the first wave — a line of wall dots with a gap, an arrow wing of seven drones, a ring of circle dots, a single larger turret dot with its aim tick, or an eight-segment snake; at 12 s most likely the game-over panel. Note frame-time only if the run survived long enough for `"$ADB" -s RRCXB04L8EJ shell dumpsys gfxinfo com.jtg.perilpoint | grep -A3 "50th"` to be meaningful.

- [ ] **Step 3: Write `godot/VERIFY-ME.md`**

Create the file with this content, filling the bracketed evidence lines from Steps 1–2:

```markdown
# VERIFY-ME — hand-held checks the agent could not run

Written by M3 (enemy roster). Each item needs a thumb on the Galaxy A55.
Tick it, note what you saw, and paste the block into HANDOFF.md.

Build under test: `godot/build/peril-point-debug.apk` from commit [sha].
Unattended evidence: [pid alive / no SCRIPT ERROR / m3-03s.png shows N seekers / m3-05s.png shows <formation>].

## M3 — enemy roster

- [ ] Survive to 5,000 in classic. A **charger** appears: a dart at the arena
      edge draws a pulsing dashed red line toward you for ~1 s, then darts
      at 480 px/s with an orange plume, then coasts. Then repeats.
- [ ] 10,000: a **specter** — a violet dot with a dashed ring that fades in
      and out as it homes.
- [ ] 16,000: **artillery** — a dark hexagon with a magenta barrel that keeps
      its distance, strafes, and fires a pink comet-tailed bullet every
      ~3 s; the muzzle glows before each shot.
- [ ] 22,000: a **pulsar** — a red dot with an expanding corona every 2.2 s
      and a spinning white star; killing it splits it into two small seekers.
- [ ] 32,000: a **carrier** — a rotating diamond with a dashed ring and four
      cyan satellites on tethers; killing it scatters the satellites.
- [ ] Formations, every ~6-12 s in classic: wall sweep with a five-dot gap;
      arrow wing of seven from left or right; ring of 12-16 that pauses then
      closes; a lone turret whose aim tick follows you; a snake of eight.
- [ ] Flying near a wall dot or a tethered satellite does not push it aside
      (they are excluded from separation).
- [ ] Frame time with a wall sweep plus a carrier on screen:
      `adb -s RRCXB04L8EJ shell dumpsys gfxinfo com.jtg.perilpoint | grep -A3 50th`
      — 50th percentile at or under 16 ms.

Not observable in any mode yet (no caller until M4/M10): `freeze_all`,
`spawn_sequential_gauntlet_wall`, `spawn_rotating_gate`, `spawn_mode_armada`.
```

- [ ] **Step 4: Commit**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/VERIFY-ME.md
git commit -m "M3: record device pass evidence and hand-held checks"
```

---

### Task 8: Exit protocol (CONVENTIONS §9)

**Files:**
- Modify: `godot/PORT-PROGRESS.md` (the M3 entry), `godot/HANDOFF.md` (rewrite), `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md` (module-map row 3)

**Interfaces:**
- Consumes: every result actually observed in Tasks 1–7.
- Produces: a handoff a zero-context session can resume from.

- [ ] **Step 1: Verify, fresh**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
tools/run_tests.sh 2>&1 | tail -5
gdformat --check godot/src godot/tests
gdlint godot/src godot/tests
"$GODOT" --headless --path godot --check-only -s src/sim/enemy_swarm.gd
"$GODOT" --headless --path godot --check-only -s src/render/entity_layer.gd
grep -c "TODO(M3)" godot/src/sim/enemy_swarm.gd godot/src/render/entity_layer.gd
grep -n "TODO(M" godot/src/sim/enemy_swarm.gd
git status --short
```

Expected, read from the output and not assumed: `OK: N/N scripts collected, all tests passed.`; `gdformat` reports every file unchanged; `gdlint` prints nothing; both `--check-only` exit 0; the `TODO(M3)` count is `0` for both files; the remaining `TODO(M` lines name only M4 (`freeze_all`), M7 (skins, in `entity_layer.gd`) and M10 (modes, armada); the working tree is clean.

- [ ] **Step 2: Tick `PORT-PROGRESS.md`**

Replace the `- [ ] **M3 — Enemy roster**` block with a ticked entry in the M2 entry's style: date, the Task 7 commit SHA, the plan path, then `ok` lines for: the 12 spawnable types plus the ported `spike_mine` arm (Open question 5), the seven formations plus the armada, the wave-director threshold spec, the collected/passed counts, `gdformat`/`gdlint` clean, `--check-only` on both files, and the unattended device evidence with a pointer to `VERIFY-ME.md` for the hand-held half.

- [ ] **Step 3: Rewrite `HANDOFF.md`**

For a session with zero context, in the M2 handoff's shape: what M3 landed (file by file); the exact verification commands from Step 1 with their observed results; the screenshot findings; the `VERIFY-ME.md` pointer; every Open question below that is still open, verbatim; M2.5's unfinished tasks if they are still unfinished; and the next module. Spec §8 lists **M4, M5 and M7** as independent of M3, and **M10 depends on M3** — name M10's literal first step: "read spec §8 Module 10 and `web/src/tilt-to-live/GauntletMaze.ts` in full, then write `docs/superpowers/plans/2026-09-20-m10-modes.md`; `run_controller.gd` already passes `game_mode` to `swarm.update` and `enemy_swarm.gd` carries `TODO(M10)` at the two mode branches".

- [ ] **Step 4: Update the index's module map**

In `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md`, change row 3 to:

```
| 3 | Enemy roster (12 remaining types, 8 formations) | M2 | `2026-09-20-m3-enemy-roster.md` | **done** |
```

- [ ] **Step 5: Commit and stop**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
git checkout godot/project.godot
git add godot/PORT-PROGRESS.md godot/HANDOFF.md docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md
git commit -m "M3: tick progress and hand off the enemy roster"
```

Then **stop**. Report to the user. Do not begin M4, M5, M7 or M10 — CONVENTIONS §9 step 5.

---

## Open questions

Each is recorded rather than resolved (LAW 5). The plan proceeds on the reading marked *recommended*; the executing session must confirm it in `HANDOFF.md` or stop.

1. **Who owns `spawn_mode_armada` and `trigger_gauntlet_formation`?** Spec §8 Module 10 lists both under M10; the M3 brief and LAW 3 ("same members, same order") put every `EnemySwarm.ts` member in M3. `triggerGauntletFormation` is called from inside `update()` (`EnemySwarm.ts:121`), so leaving it out would leave a hole in a method M3 must complete. *Recommended:* M3 ports the code (Task 5) with `TODO(M10)` at the call sites; M10 wires `run_controller.gd`'s mode and the cinematic's armada call and verifies both on device.

2. **TS-private methods are public in this file.** `CONVENTIONS.md` §3 says a TS private becomes `_snake_case`; M2 made `updateSeeker` and `applyFlockingSeparation` public (`enemy_swarm.gd:176`, `:212`) and a spec calls the latter by name. *Recommended:* keep the file self-consistent — all members public, TS order — and let a later housekeeping commit rename the whole file's TS-privates at once if the user wants CONVENTIONS §3 enforced here. The `gdlint` suppression is needed either way (21 TS publics > 20).

3. **Radial gradients.** Spec §4.5 maps `createRadialGradient` to "one baked white radial-gradient texture, tinted via `modulate`"; M2's `_draw_enemies` drew two flat circles instead (`entity_layer.gd:187-199`) and shipped. *Recommended:* Task 6 follows the M2 precedent for the five new gradients (bullet, pulsar, specter, and the existing dot) so the file stays uniform, and the baked texture is built once, for every gradient in the game, in M11's draw-cost pass.

4. **How many formations is "8"?** Counted in the TS: seven `spawn*` formation methods — `spawnArrowFormation` (`:851`), `spawnCircleEncirclement` (`:884`), `spawnWallFormation` (`:916`), `spawnSequentialGauntletWall` (`:972`), `spawnRotatingGate` (`:1068`), `spawnTurret` (`:1098`), `spawnSnake` (`:1118`) — plus `spawnModeArmada` (`:781`). The spec's "8" matches only if the armada counts, or if the dual-pincer arrow (`:852`) or tight circle (`:888`) variants count as their own. *Recommended:* read it as seven plus the armada; all are ported regardless.

5. **`spike_mine` never spawns.** `Types.ts:24` declares it and `update()` dispatches it (`EnemySwarm.ts:169-172`), but no method in the TS creates one. The acceptance "each of the 13 types spawns" therefore cannot be met literally without inventing a spawner (LAW 4). *Recommended:* accept 12 spawnable types plus the ported dispatch arm, proven by `test_spike_mine_drifts_by_its_velocity` with a hand-built record; record the wording in `PORT-PROGRESS.md`.

6. **`entity_layer.gd:224` drops `_arena_origin` for the player.** `_draw_player` calls `draw_set_transform(Vector2(_player.x, _player.y), …)` without adding `_arena_origin`, so the ship draws 8–12 px (`game_root.gd:13-14`) away from where it collides. This is an M2.5 Task 4 defect that has not yet been seen on a phone (M2.5 stopped before its device pass). *Recommended:* M2.5 Task 8 fixes it in its own device pass; Task 6 here does not touch `_draw_player` but must not copy the omission. If M2.5 is finished before M3 starts and the line is still wrong, fix it in Task 6 with a `DIVERGENCE(M2.5 §6.1)`-tagged one-line change and say so in the commit.

7. **Dead public methods.** `freezeAll` (`:1184`), `spawnSequentialGauntletWall` (`:972`) and `spawnRotatingGate` (`:1068`) have no caller anywhere in `web/src` — `WeaponSystem.ts:542-543` freezes enemies inline and gauntlet walls come from `GauntletMaze.ts`. They are ported because spec §8 M3 names `freeze_all` and "all 8 formations". *Recommended:* port, spec-test, and leave `TODO(M4)`/`TODO(M10)` markers; M4 and M10 decide whether their callers route through them.
