# Module 11c (part 1) — Performance on the A55: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A late Classic run (100–120 enemies on screen) holds 60 fps on the Galaxy A55, and formation spawns and power-up mass kills no longer spike. Today that run falls to 12–14 fps.

**Architecture:** Measure first, then fix the four measured roots one at a time, re-measuring on the A55 after each. The roots, in cost order: the swarm step, the grid springs, the enemy draw, and the catch-up spiral that multiplies the first two. Every fix is either bit-exact with the current port (proven by an oracle test against the unoptimised code) or a tagged `DIVERGENCE(M11c P<n>)` ruling below.

**Tech Stack:** Godot 4.7.2-stable, GDScript (static typing enforced), GUT 9.6.1 headless, gdtoolkit 4.5.0, adb + SurfaceFlinger on the SM_A556E.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` §8 Module 11 ("sustained 60 fps across a 5-minute run"), §9 risk register ("GDScript + 200 enemies + per-frame `_draw`" → "MultiMesh escape hatch, only if profiling demands it"), §4.5 (glow), D8 (120 Hz tick). Read `godot/CONVENTIONS.md` before any task.

This is **part 1 of M11c**. Part 2 (glow, icons/splash, signed release, the rest of the device pass) is planned after this lands. Part 1 comes first because its measurements decide part 2's glow: the port misses 60 fps before any glow exists.

---

## Evidence (A55, 2026-09-26, debug build of `fbf7e94` + a temporary probe)

**`dumpsys gfxinfo` is blind to Godot.** It reports `Total frames rendered: 0`, because it counts Android's HWUI frames, not the Vulkan SurfaceView. Every frame-time check in `VERIFY-ME.md` that uses it has measured nothing. `dumpsys SurfaceFlinger --latency '<layer>'` works: it returns the last 128 present timestamps of the Godot surface (Task 1 ships the sampler). The panel refreshes at 120 Hz (8.33 ms vsync), and `max_fps` caps the game at 60.

**The probe** (per rendered frame, `avg/peak` ms; `steps` = sim ticks that second, `maxsteps` = most ticks in one frame, `en` = enemies):

| Scene | fps | maxsteps | swarm | grid | weapons | hud signal | entity draw | GPU |
|---|---|---|---|---|---|---|---|---|
| menu, backdrop only | 59 | 5 | — | (in backdrop) | — | — | 0.6 | 7.8 |
| early run, en≈24 | 60 | 2 | 0.4 | 2.8 | 0.0 | 0.5 | 2.1 | 6.3 |
| power-up kills, en≈7 | 42 | 4 | 0.3 | 6.5 | 3.2 | 1.0 | 1.5 | 6.2 |
| late run, en≈105–113 | **12–14** | **8** | **22–27** | **18–19** | 0.2 | 2.2–3.4 | **14–17** | 6.5 |
| game over, en=113, sim stopped | 25–30 | 5–6 | — | — | — | — | **16–21** | 7–10 |

GPU time never exceeds ~10 ms, so the frame drops are CPU time in GDScript:

1. **The catch-up spiral.** The sim runs at 120 Hz (D8). When a frame's sim plus draw exceeds 16.6 ms, Godot runs extra ticks the next frame, up to `physics/common/max_physics_steps_per_frame` (default 8). At 110 enemies every frame runs 8 ticks, which is why swarm and grid read 8× their per-tick cost. The TS loop (`TiltGame.ts:1843-1848`) is also uncapped, but a browser's JIT runs it fast enough to never spiral.
2. **Swarm step, ~3 ms per tick at 110 enemies.** `EnemySwarm.apply_flocking_separation` (`enemy_swarm.gd:1285`) visits all n²/2 pairs (~6,000 at 110). It re-tests the inner partner's five eligibility conditions inside the inner loop, and walls, bullets and satellites stay in both loops. The per-type updates add the rest; Task 3 splits the number.
3. **Grid springs, ~2.3 ms per tick, even with gridlines off.** `VectorGrid` on the A55 is 62 × 31 = 1,922 `GridPoint` objects (`vector_grid.gd:28`), stepped every tick. **Every enemy kill** calls `apply_explosion` (`run_controller.gd:319`), which scans all 1,922 points. A power-up that kills 30 enemies in one tick means 30 full scans, so this is the kill spike the user reported. Gridlines are **off** by default (`grid_layer.gd:62`), and `grid_layer._draw_grid` is the only reader of the points, so all this work is invisible by default.
4. **Enemy draw, ~140 µs per enemy.** A default dot (`entity_layer.gd:809`) issues 7 canvas commands: 2 × `draw_arc` of 24 segments, 4 × `draw_circle`, and 2 transform sets. Each is re-tessellated on the CPU every frame (~880 draw calls at 110 enemies).
5. **HUD signal, 0.25–0.4 ms per tick.** `score_changed` fires every tick (`run_controller.gd:258`). `HudController._on_score_changed` (`hud_controller.gd:420`) builds a new `StyleBoxFlat` and re-applies two theme overrides on every call (`_style_multiplier`, `:446`), which re-themes the chip 120 times a second.

**Also reported by the user on the A55 (2026-09-26), not yet investigated:** "some options don't show correctly"; "the Peril Point loading screen isn't centered" (the ColdOpen board, M11b); "the circle spawn that surrounds you gives no way to escape, it is too tightly packed". These are Tasks 7–8 and Open questions 1–2.

## Rulings (planning, 2026-09-26 — the user reviews them with this plan)

The user asked on 2026-09-26: "we need to optimize the game". That request is the licence for P2–P6. Each divergence is tagged `DIVERGENCE(M11c P<n>)`.

- **P1 — A permanent, debug-only probe.** `core/perf_probe.gd` times the sim sections and draw layers and prints one `PERF` line per second. It runs only when `OS.is_debug_build()`, so release builds pay nothing. It stays after this plan: part 2's glow measurement and every later device pass read it. `tools/frametime.sh` (the SurfaceFlinger sampler) replaces `dumpsys gfxinfo` in `VERIFY-ME.md`.
- **P2 — Cap the catch-up at 3 ticks per frame.** Set `physics/common/max_physics_steps_per_frame=3`: two ticks per 60 fps frame plus one tick of catch-up. Under overload the sim then runs slower than real time instead of spiralling to 8 ticks and 12 fps. At the target (Tasks 3–5 landing) no frame needs more than 2 ticks, so the cap never binds and changes nothing. This diverges from the uncapped TS loop.
- **P3 — The grid sleeps while it is invisible.** While gridlines are off, `VectorGrid.update` and `apply_explosion` do nothing (`GridLayer.show_gridlines` is the only reader of the points). While gridlines are on, the grid runs exactly as now, but on packed arrays: `PackedFloat32Array` × 6 replaces the 1,922 `GridPoint` objects. `apply_explosion` then scans only the rows and columns whose rest positions lie within `radius + MAX_DISPLACEMENT` of the centre. Turning gridlines on mid-run shows a flat grid instead of any ripples still settling from before, which is invisible in practice.
- **P4 — Separation prefilters, bit-exact.** Each tick, `apply_flocking_separation` builds the list of eligible indices once (the same five conditions, in the same order), then runs the same `i < j` pair loop over that list. The visiting order and every arithmetic step are unchanged, so positions match the current code bit for bit (oracle test). A spatial hash would change the pair order and is **not** taken unless Task 3's measurement shows the prefilter falls short. If it does, stop and ask (Law 5).
- **P5 — Enemy dots draw from a cached sprite.** `_draw_default_dot` and `_draw_frozen_dot` bake their layers (body, inner, border, pupil) once per colour set into an `ImageTexture` and draw them with one `draw_texture_rect`. The halo and glow draw with a second, shared white ring/disc texture, scaled by the per-enemy `pulse` and tinted. That makes 2–3 batched texture draws per dot instead of 7 tessellated commands. Charger, artillery, carrier, pulsar, specter, satellite and bullet keep their code. They are a small share of the swarm; the probe decides whether they need the same treatment later. The device pass judges the visual parity; a close screenshot compare is Task 5's step.
- **P6 — `score_changed` fires only on change.** `RunController` emits `score_changed` when score, multiplier or best differ from the last emission, and `_style_multiplier` rebuilds the chip only when the multiplier's tier changes. What the HUD shows is unchanged.
- **User rulings, 2026-09-26 (answers to the Open questions):**
  - **Q3 → P2 is withdrawn.** "It should be at regular speed. No slow motion." `max_physics_steps_per_frame` stays at Godot's default 8. Task 2 is dropped. The spiral is removed at its cause instead: Tasks 3–6 must bring a late-run frame under budget.
  - **Q2 → options display is out of scope** for now ("lets focus on performance").
  - **Q1 → P8, the start ring moves out.** It is the 8 seekers that surround the ship at the start of a Classic run (`TiltEntranceCinematic.ts:203-210`, M11b R12). "Having them further away would make it easier for players to evade." `SEEKER_RADIUS` becomes `maxf(260, 0.42 × min(width, height))`, tagged `DIVERGENCE(M11c P8)`. Keeping the TS 260 px as the floor leaves desktop-sized arenas unchanged, while the A55's 1056 px arena gets ~443 px. That is still inside the existing 40 px clamp: 528 − 443 = 85 > 40. Task 8.
- **P9 — the ring formation has fewer dots (user ruling, 2026-09-26, after playing P8).** "The circle spawns are still too close together, making it near impossible to slip past." The mid-run encirclement (`EnemySwarm.ts:884-914`) keeps its radius and timing, but Classic ramps 8 → 10 dots (8 + score/10,000, capped at 10; TS 12 → 16) and Code Red's tight ring has 11 (TS 16). The user chose this over a wider ring, both, or a deliberate exit gap. Tagged `DIVERGENCE(M11c P9)`.
- **P10 — coin magnet (user ruling, 2026-09-26).** The TS has none. Coins within `MAGNET_RADIUS` 180 arena px fly to the ship at 160 px/s at the edge, ramping to 700 px/s at the ship (`coin_system.gd`, before the TS pickup test). The user chose "nearby pull" over a wide (~400 px) or whole-screen pull. `magnet_radius` is a property so the TS-rule tests run with it at 0.
- **P11 — Milestones in one column (user ruling, 2026-09-26).** One `TierScroll` holds three stacked sections (Score, Combat, Mastery), each with its heading and count, open goals above done ones; replaces `Milestones.dc.html`'s three side-by-side columns. The user chose stacked sections over one merged list.
- **P12 — pooled particles.** Retired particles go to a free list that the next emit reuses; `update()` compacts survivors in one forward pass (same order) instead of `remove_at` per death. Values and order are unchanged; a warm pool halves emission cost (desktop: 20 explosions 950–1,130 → 410–560 µs).
- **Armory drag fix (A55 report, 2026-09-26).** "I cannot drag or move the armory": every Button and card panel inside an Armory scroll view had `MOUSE_FILTER_STOP` and swallowed the touch. `ArmoryUI._let_drags_scroll` switches them (and the nested rows) to `PASS` after each tab build; sliders and the handling preview keep `STOP`.
- **Tried and reverted:** drawing dots under the standing arena transform (no per-dot `draw_set_transform`) — no measurable gain (800 → ~830 µs, noise).
- **P7 — `GoalManager.evaluate_live_total_goals` is left alone.** It costs 0.1–1.0 ms per frame at load. Re-measure after P2–P6. If it matters then, it gets its own ruling.

## Global Constraints

- **Tests run only via `tools/run_tests.sh`.** Baseline at `fbf7e94`: `OK: 54/54 scripts (631 tests, 18076 asserts)`. Each task states its delta; if a delta differs, reconcile it and record why in `HANDOFF.md`. Never change the expectation to match.
- **Format and lint** after every task: `gdformat --check godot/src godot/tests` (baseline 98 files) and `gdlint godot/src godot/tests`.
- **Headless runs strip one default-valued line from `godot/project.godot`.** Run `git checkout godot/project.godot` before every commit, **except** in Task 2, which adds the physics cap line deliberately. There, restore the stripped line by hand and keep the new one.
- **Commits are one line, no trailers**, prefixed `M11c:`, and name the next step (CONVENTIONS §8, CLAUDE.md).
- **Every task ends with an A55 measurement**, when the phone is on `adb` (serial `RRCXB04L8EJ`):
  - Export and install the debug APK (VERIFY-ME §0).
  - The user plays a Classic run past 100 enemies while `adb logcat -s godot:I | grep PERF` runs.
  - Record in `HANDOFF.md` the median of the PERF lines with `en` between 100 and 120: `fps`, `maxsteps`, and each section.
  - If the phone is absent, record that and continue; the headless tests are the gate.
- **Law 1 still holds**: every new numeric literal carries `# PORT:` or `# DIVERGENCE(M11c P<n>)`.

## Review Focus

1. **Gridlines toggled on mid-run** (Settings from Pause). The grid must appear flat and then react to the next kill, not crash on arrays that were never allocated. Task 4 tests toggling while the grid sleeps.
2. **Rotation or resize while sleeping.** `resize` must still rebuild the arrays, so the grid is the right size when it wakes. Task 4 tests it.
3. **The chilled/skinned/hazard dot variants.** Each colour set needs its own cached sprite. A skin change mid-session (Armory) must not draw the old skin's sprite. Task 5 tests that the cache key includes the skin id and the state.
4. **Multiplier reset to 1× and back.** With P6 the chip must still hide at 1× and restyle when the tier changes, including 20× → 1× on a hit. Task 6 tests both directions.
5. **A tick with no score change but a new best.** `best_score` changes only when score passes it, which is a score change anyway. Task 6 tests the combined key, so no emission is lost.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `godot/src/core/perf_probe.gd` (new) | debug-only section timer, one `PERF` line per second | 1 |
| `tools/frametime.sh` (new) | SurfaceFlinger present-interval sampler for the A55 | 1 |
| `godot/src/core/game_root.gd` | probe hooks (tick, frame, physics total) | 1 |
| `godot/src/sim/run_controller.gd` | probe hooks per sim section; P6 emit-on-change | 1, 6 |
| `godot/src/render/{entity,effect,grid}_layer.gd` | probe hooks per draw layer | 1 |
| `godot/project.godot` | P2 physics cap | 2 |
| `godot/src/sim/enemy_swarm.gd` | P4 separation prefilter | 3 |
| `godot/src/sim/vector_grid.gd` | P3 packed arrays, sleep, windowed explosion | 4 |
| `godot/src/render/grid_layer.gd` | reads the packed grid | 4 |
| `godot/src/render/entity_layer.gd` | P5 cached dot sprites | 5 |
| `godot/src/ui/hud_controller.gd` | P6 restyle only on tier change | 6 |
| tests: `test_perf_probe.gd` (new), `test_vector_grid.gd`, `test_enemy_swarm*.gd`, `test_entity_layer*.gd`, `test_hud*.gd`, `test_run_controller.gd` | oracles and regressions | 1–6 |

---

### Task 1: The probe and the sampler (P1)

**Status:** done `f27e02a` (+ `godot/bench/bench_sim.gd`); A55 baseline skipped (phone off adb) — the Evidence table is the baseline.

**Files:**
- Create: `godot/src/core/perf_probe.gd`, `godot/tests/test_perf_probe.gd`, `tools/frametime.sh`
- Modify: `godot/src/core/game_root.gd` (`_physics_process`, `_process`), `godot/src/sim/run_controller.gd` (`update`), `godot/src/render/entity_layer.gd`, `effect_layer.gd`, `grid_layer.gd` (`_draw`), `godot/VERIFY-ME.md` (every `gfxinfo` line)

**Interfaces:**
- Produces: `PerfProbe.now() -> int`, `PerfProbe.add(key: String, t0: int) -> void`, `PerfProbe.step() -> void`, `PerfProbe.frame(extra: String) -> void`, `PerfProbe.enabled: bool` (static, defaults to `OS.is_debug_build()`), `PerfProbe.format_line(frames: int, steps: int, max_steps: int, acc: Dictionary[String, int], peak: Dictionary[String, int], extra: String) -> String` (pure, for the test).

- [ ] **Step 1: Write the failing test** `godot/tests/test_perf_probe.gd`:

```gdscript
extends GutTest


func test_format_line_averages_per_frame_and_sorts_keys() -> void:
	var acc: Dictionary[String, int] = {"s_swarm": 6000, "d_entity": 3000}
	var peak: Dictionary[String, int] = {"s_swarm": 2500, "d_entity": 1100}
	var line: String = PerfProbe.format_line(2, 4, 2, acc, peak, "en=10")
	assert_eq(line, "PERF fps=2 steps=4 maxsteps=2 en=10 | d_entity=1.50/1.1 s_swarm=3.00/2.5")


func test_disabled_probe_records_nothing() -> void:
	PerfProbe.enabled = false
	PerfProbe.reset()
	PerfProbe.add("x", PerfProbe.now() - 1000)
	assert_eq(PerfProbe.accumulated("x"), 0)
	PerfProbe.enabled = OS.is_debug_build()
```

- [ ] **Step 2: Run it to see it fail.** `tools/run_tests.sh` → FAIL: `Identifier "PerfProbe" not declared`.

- [ ] **Step 3: Implement** `godot/src/core/perf_probe.gd`:

```gdscript
## perf_probe.gd
## DIVERGENCE(M11c P1): no TS counterpart — device instrumentation for the A55
## performance pass. Debug builds only; one PERF line per second to stdout (logcat).
class_name PerfProbe
extends RefCounted

## DIVERGENCE(M11c P1): one report per second of real time.
const WINDOW_USEC: int = 1000000
## DIVERGENCE(M11c P1): microseconds → milliseconds.
const USEC_PER_MS: float = 1000.0

static var enabled: bool = OS.is_debug_build()
static var _acc: Dictionary[String, int] = {}
static var _peak: Dictionary[String, int] = {}
static var _frames: int = 0
static var _steps: int = 0
static var _steps_this_frame: int = 0
static var _max_steps: int = 0
static var _window_start: int = 0


static func now() -> int:
	return Time.get_ticks_usec()


static func add(key: String, t0: int) -> void:
	if not enabled:
		return
	var d: int = Time.get_ticks_usec() - t0
	_acc[key] = _acc.get(key, 0) + d
	if d > _peak.get(key, 0):
		_peak[key] = d


static func accumulated(key: String) -> int:
	return _acc.get(key, 0)


static func step() -> void:
	if not enabled:
		return
	_steps += 1
	_steps_this_frame += 1


static func reset() -> void:
	_acc.clear()
	_peak.clear()
	_frames = 0
	_steps = 0
	_steps_this_frame = 0
	_max_steps = 0
	_window_start = 0


static func frame(extra: String) -> void:
	if not enabled:
		return
	var t: int = Time.get_ticks_usec()
	_frames += 1
	_max_steps = maxi(_max_steps, _steps_this_frame)
	_steps_this_frame = 0
	if _window_start == 0:
		_window_start = t
		return
	if t - _window_start < WINDOW_USEC:
		return
	print(format_line(_frames, _steps, _max_steps, _acc, _peak, extra))
	reset()
	_window_start = t


static func format_line(
	frames: int,
	steps: int,
	max_steps: int,
	acc: Dictionary[String, int],
	peak: Dictionary[String, int],
	extra: String
) -> String:
	var keys: Array[String] = acc.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k: String in keys:
		parts.append(
			"%s=%.2f/%.1f" % [k, acc[k] / USEC_PER_MS / frames, peak.get(k, 0) / USEC_PER_MS]
		)
	return "PERF fps=%d steps=%d maxsteps=%d %s | %s" % [
		frames, steps, max_steps, extra, " ".join(parts)
	]
```

- [ ] **Step 4: Hook it in.** Use this exact pattern at each site (`pt_<key>` locals, so hooks never collide):

```gdscript
var pt_swarm: int = PerfProbe.now()
swarm.update(dt, Vector2(player.x, player.y), bounds, particles, scores.stats.score, mode)
PerfProbe.add("s_swarm", pt_swarm)
```

Keys: in `RunController.update`, `s_grid`, `s_particles`, `s_player`, `s_swarm`, `s_weapons` (around the whole multi-line call), `s_coins`, `s_collide`, `s_goals`, `s_hud_signal`. In `GameRoot._physics_process`, call `PerfProbe.step()` first and wrap the `match` as `phys`. In the `MENU` arm, wrap `_update_menu` as `s_menu`. Each layer's `_draw` gets `d_entity` / `d_effect` / `d_grid`: take `t0` after its first `draw_set_transform` (the grid layer: after its `_grid == null` return) and `add` before its final `draw_set_transform(Vector2.ZERO, …)`.

At the top of `GameRoot._process`:

```gdscript
if PerfProbe.enabled:
	var vp: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	PerfProbe.frame(
		(
			"gpu=%.2f en=%d pa=%d draws=%d"
			% [
				RenderingServer.viewport_get_measured_render_time_gpu(vp),
				_run_controller.swarm.enemies.size(),
				_particles.particles.size(),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			]
		)
	)
```

- [ ] **Step 5: Add `tools/frametime.sh`.** Copy it from the session scratchpad version (reproduced here):

```bash
#!/usr/bin/env bash
# Usage: tools/frametime.sh <seconds> <label>
# Polls SurfaceFlinger's 128-frame present ring for the Godot surface every
# 1.5 s, dedups by timestamp, prints present-interval percentiles.
# dumpsys gfxinfo cannot see Godot's Vulkan SurfaceView (it reports 0 frames).
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"
D="-s RRCXB04L8EJ"
SECS=${1:-30}; LABEL=${2:-run}
OUT="$(mktemp)"
L=$("$ADB" $D shell dumpsys SurfaceFlinger --list | grep -o '[0-9a-f]* SurfaceView\[com.jtg.perilpoint[^ ]*(BLAST)#[0-9]*' | head -1)
[ -n "$L" ] || { echo "no Peril Point surface — is the app in the foreground?"; exit 1; }
END=$(( $(date +%s) + SECS ))
while [ "$(date +%s)" -lt "$END" ]; do
  "$ADB" $D shell "dumpsys SurfaceFlinger --latency '$L'" | awk 'NR>1 && $2>0 && $2<9e18 {print $2}' >> "$OUT"
  sleep 1.5
done
sort -n -u "$OUT" | awk '{if(p) print ($1-p)/1e6; p=$1}' | awk '$1<200' | sort -n |
  awk -v l="$LABEL" '{a[NR]=$1; s+=$1; if($1>20) j++} END{printf "%s: n=%d mean=%.2fms p50=%.2f p95=%.2f p99=%.2f max=%.2f >20ms=%.1f%%\n", l, NR, s/NR, a[int(NR*.5)], a[int(NR*.95)], a[int(NR*.99)], a[NR], 100*j/NR}'
rm -f "$OUT"
```

In `VERIFY-ME.md`, replace every `dumpsys gfxinfo … | grep -A3 50th` line with `tools/frametime.sh 30 <label>` and "p50 at or under 16.7 ms, >20ms under 2%". Add one line under §0 saying why.

- [ ] **Step 6: Verify.** `tools/run_tests.sh` → `OK: 55/55 scripts (633 tests, …)`; gdformat (100 files) and gdlint clean; headless `--quit-after 240` prints `PERF` lines and 0 `SCRIPT ERROR` (headless runs are debug builds).
- [ ] **Step 7: Baseline on the A55.** Record the late-run median (en 100–120) in `HANDOFF.md`, next to the Evidence table above.
- [ ] **Step 8: Commit** `M11c: add debug perf probe and SurfaceFlinger sampler; next: Task 2`.

### Task 2: DROPPED (user ruling Q3, 2026-09-26 — no catch-up cap)

The steps below are kept for the record only; do not execute them.


**Files:** Modify `godot/project.godot` (`[physics]`), test `godot/tests/test_main_scene.gd` (or the existing project-settings test, if one exists; `grep -rn "physics_ticks_per_second" godot/tests`).

- [ ] **Step 1: Failing test** (in the file that already pins `physics_ticks_per_second`):

```gdscript
func test_catch_up_is_capped_at_three_ticks() -> void:
	# DIVERGENCE(M11c P2): two 120 Hz ticks per 60 fps frame + one of catch-up.
	assert_eq(ProjectSettings.get_setting("physics/common/max_physics_steps_per_frame"), 3)
```

- [ ] **Step 2: Run** → FAIL (8).
- [ ] **Step 3: Implement.** Under `[physics]` add `common/max_physics_steps_per_frame=3`. Add one line to CONVENTIONS' settings note, or to HANDOFF's toolchain table, citing P2 (`project.godot` cannot hold a comment the editor keeps).
- [ ] **Step 4: Run** → PASS; delta +1 test. Before committing, diff `project.godot` by hand: keep the new line, and restore any line the headless run stripped.
- [ ] **Step 5: A55.** Late-run median: `maxsteps` ≤ 3, and `fps` should rise, but the sim now runs slow under load. Record both, and whether the slow-down is noticeable.
- [ ] **Step 6: Commit** `M11c: cap physics catch-up at 3 ticks to stop the spiral; next: Task 3`.

### Task 3: Separation prefilter (P4)

**Status:** done `5472607` — extended to packed 64-bit copies + dx² early reject, still bit-exact (ledger ruling).

**Files:** Modify `godot/src/sim/enemy_swarm.gd:1285-1321`; test `godot/tests/test_enemy_swarm_separation.gd` (new).

- [ ] **Step 1: Failing oracle test.** Copy today's `apply_flocking_separation` body verbatim into the test as `_reference_separation(enemies: Array[Types.Enemy])`. Build a seeded (`seed(1234)`) swarm of 150 enemies: a mix of seekers, `WALL_DOT`, `BULLET`, frozen ones, satellites (`parent_carrier_id = 1`) and orbiters (`orbit_center = Vector2(5, 5)`), packed into a 120 × 120 px box so many pairs overlap. Deep-copy it. Run the reference on one copy and `swarm.apply_flocking_separation()` on the other, 30 times each. Assert every `x`/`y` is **exactly** equal (`assert_eq`, not `assert_almost_eq`). Add a second test that `EnemySwarm.separation_candidates()` excludes each ineligible kind. It fails until Step 3 exists.
- [ ] **Step 2: Run** → the oracle passes (same code) and the candidates test fails. The oracle is the guard for Step 3.
- [ ] **Step 3: Implement.**

```gdscript
## DIVERGENCE(M11c P4): the eligibility test runs once per enemy per tick instead of
## once per pair; the i<j visiting order and the arithmetic are unchanged.
func separation_candidates() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in range(enemies.size()):
		var e: Types.Enemy = enemies[i]
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:517, :521
		if (
			e.frozen
			or e.type == Types.EnemyType.WALL_DOT
			or e.type == Types.EnemyType.BULLET
			or e.orbit_center != Vector2.ZERO
			or e.parent_carrier_id != Types.ABSENT
		):
			continue
		out.append(i)
	return out


## PORT: web/src/tilt-to-live/EnemySwarm.ts:509-539
func apply_flocking_separation() -> void:
	var min_distance: float = 16.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:511
	var min_distance2: float = min_distance * min_distance
	var idx: PackedInt32Array = separation_candidates()
	var n: int = idx.size()
	for ii: int in range(n):
		var a: Types.Enemy = enemies[idx[ii]]
		for jj: int in range(ii + 1, n):
			var b: Types.Enemy = enemies[idx[jj]]
			var dx: float = b.x - a.x
			var dy: float = b.y - a.y
			var dist2: float = dx * dx + dy * dy
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:527-537
			if dist2 < min_distance2 and dist2 > 0.0001:
				var dist: float = sqrt(dist2)
				var push: float = (min_distance - dist) * 0.15  # PORT: web/src/tilt-to-live/EnemySwarm.ts:529
				var px: float = (dx / dist) * push
				var py: float = (dy / dist) * push
				a.x -= px
				a.y -= py
				b.x += px
				b.y += py
```

Eligibility cannot change inside the loop, since the loop only writes `x`/`y`, so this is exact.

- [ ] **Step 4: Run** → both pass; delta +1 script, +2 tests.
- [ ] **Step 5: Split the swarm cost.** Temporarily add `s_sep` around the call inside `EnemySwarm.update`, and measure on the A55. If `s_swarm − s_sep` (the per-type updates) is still above 1 ms per tick at 110 enemies, **stop and report** with the numbers. The next step (per-type hot spots or a spatial hash) needs its own ruling. Remove the temporary key before committing.
- [ ] **Step 6: Commit** `M11c: prefilter separation candidates, same pair order; next: Task 4`.

### Task 4: The grid (P3)

**Status:** done `48f459a` — Float64 (not Float32) and an exact window from the tracked max displacement, so bit-exact (ledger ruling).

**Files:** Modify `godot/src/sim/vector_grid.gd` (whole file), `godot/src/render/grid_layer.gd:210-230` (the reader), `godot/src/core/game_root.gd:376` (tell the grid it is visible); test `godot/tests/test_vector_grid.gd`.

**Interfaces:**
- Produces: `VectorGrid.awake: bool` (set by `GameRoot` from `show_gridlines`, the menu backdrop included), `VectorGrid.px/py/ox/oy/vx/vy: PackedFloat32Array`, `VectorGrid.point_at(index: int) -> Vector2` for the reader. `GridPoint` and `points` are removed. `grep -rn "\.points\b\|GridPoint" godot/src godot/tests` must be empty afterwards, except the oracle.

- [ ] **Step 1: Failing oracle test.** Keep a copy of today's `VectorGrid` (object-per-point) inside the test as `ReferenceGrid`. For a 900 × 400 grid, apply the same script to both: explosion at (300, 200, 16, 90), 20 updates, implosion at (450, 100, 16, 200), 40 updates, 30 explosions of (random seeded point, 4.5, 60). Assert every point's position equals within `1e-4`: Float32 storage replaces GDScript's 64-bit floats, so bit-exact is not possible here, and 1e-4 px is invisible. Add tests that:
  - `awake = false` makes `update` and `apply_explosion` leave every value unchanged;
  - `resize` while asleep produces the right `cols × rows` and rest positions;
  - waking after a resize reacts to the next explosion (Review Focus 1–2).
- [ ] **Step 2: Run** → FAIL (`awake`, `point_at` missing).
- [ ] **Step 3: Implement** the packed grid:
  - `update` loops `for i in range(n)` over the six arrays with the same arithmetic.
  - `apply_explosion` computes a column window `[floor((cx - reach) / SPACING), ceil((cx + reach) / SPACING)]` clamped to the grid, and the same for rows, where `reach = radius + MAX_DISPLACEMENT`. `MAX_DISPLACEMENT` is `DIVERGENCE(M11c P3)`: set it to 3 × `SPACING`, and assert in the oracle test that no point in the script ever strays further than that from rest. Loop only that window, with the same test on the **current** position as today.
  - Both functions `return` at once when `not awake`.
  - `GridLayer._draw_grid` reads `_grid.point_at(r * cols + c)`.
  - `GameRoot` sets `_grid.awake = options.settings.show_gridlines` wherever it sets `_grid_layer.show_gridlines` (`:376`), and at boot.
- [ ] **Step 4: Run** → PASS; the delta is the new tests. `test_vector_grid.gd`'s existing tests, rewritten for the arrays, must keep their assertions.
- [ ] **Step 5: A55.** Late-run median `s_grid` ≈ 0 with gridlines off. Then turn gridlines on in Settings and measure again: record the cost of an awake grid.
- [ ] **Step 6: Commit** `M11c: sleep the invisible grid and pack its points; next: Task 5`.

### Task 5: Cached dot sprites (P5)

**Status:** done `f80b74c` — shared disc/ring GradientTexture2Ds (`render/circle_sprites.gd`) replace the per-skin baked sprite; particles included (ledger rulings).

**Files:** Modify `godot/src/render/entity_layer.gd` (`_draw_default_dot` :809, `_draw_frozen_dot` :533); test `godot/tests/test_entity_layer_sprites.gd` (new).

**Interfaces:**
- Produces: `EntityLayer.dot_sprite(key: String, radius: float, colors: PackedColorArray) -> Texture2D` (memoised on `key`), `EntityLayer.dot_key(e: Types.Enemy) -> String` returning `"<skin id or ->|<chilled|hazard|base|frozen>|<radius rounded to 0.5>"`, and `EntityLayer.ring_texture() -> Texture2D` / `disc_texture() -> Texture2D` (shared white, built once).

- [ ] **Step 1: Failing tests.**
  - `dot_key` differs for chilled / hazard / base / frozen, and between two skins.
  - `dot_sprite` returns the same instance for the same key and a new one for a new key.
  - The sprite's image is `ceil(2 × (radius + 1) × model_scale × SUPERSAMPLE)` px square.
  - The centre pixel has the pupil colour and a pixel at `0.8 × radius` has the body colour. Build the `Image` on the CPU with `Image.create` + per-pixel fill, so it is testable headless.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.**
  - Bake body/inner/border/pupil on the CPU into an `Image` at `SUPERSAMPLE = 2`.
  - Border: an anti-aliased ring of width 1.2 px (× model scale).
  - Wrap it with `ImageTexture.create_from_image`.
  - Draw with `draw_texture_rect(tex, Rect2(-half, half * 2), false)` under the existing `_begin_entity` transform.
  - Halo: `draw_texture_rect(ring_texture(), …, halo_col)` at `(e.radius + 5) * pulse`. Glow: `disc_texture()` at `(e.radius + 4) * pulse`, tinted `glow_col`.
  - Keep every colour selection branch as it is; only the draw calls change.
  - Tag the sprite path `DIVERGENCE(M11c P5): cached raster of EnemySwarm.ts:1557-1632`.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Visual check on the A55.**
  - Take a screenshot before (Task 4's build) and after, at the same point of a run, and crop a dot at 4× zoom.
  - Record both in `HANDOFF.md`. Any visible difference beyond anti-aliasing is a finding for the user.
  - Late-run median `d_entity` should fall well below the ~15 ms baseline; record it, and `draws`.
- [ ] **Step 6: Commit** `M11c: draw enemy dots from cached sprites; next: Task 6`.

### Task 6: Score signal on change (P6)

**Status:** done `7a16ac9`; step 5 (A55 exit measurement) pending — VERIFY-ME §M11c part 1.

**Files:** Modify `godot/src/sim/run_controller.gd:257-260`, `godot/src/ui/hud_controller.gd:420-446`; tests `test_run_controller.gd`, `test_hud_controller.gd` (or wherever `_on_score_changed` is tested: `grep -rn "_on_score_changed\|score_changed" godot/tests`).

- [ ] **Step 1: Failing tests.**
  - Two `update` ticks with no score change emit `score_changed` once (`watch_signals(GameEvents)`).
  - A multiplier change alone emits.
  - `reset_run` forces the next emission (the new run's first HUD write).
  - In the HUD: 2× → 3× (same tier) does not replace the chip's stylebox (`get_theme_stylebox("normal")` is the same instance); 4× → 5× (tier change) does; 20× → 1× hides the chip (Review Focus 4).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.**
  - `RunController` keeps `_last_emitted: Vector3i` (score, multiplier, best), reset to `Vector3i(-1, -1, -1)` in `reset_run`, and emits only when it differs.
  - `HudController` keeps `_styled_tier: Color` and calls `_style_multiplier()` only when `tier_color_for(multiplier)` differs from it.
  - Tag both `DIVERGENCE(M11c P6)`.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: A55 — the full measurement.**
  - Late-run median of every section.
  - `tools/frametime.sh 60 late-run` during a run past 100 enemies.
  - A formation spawn (a wall sweep) and a nuke through a dense swarm, with the PERF lines around each.
  - **Exit target:** late-run `fps` ≥ 58, `maxsteps` ≤ 2, frametime `>20ms` under 2%.
  - If the target is missed, record the remaining largest section and **stop**: the next fix needs a ruling (P7, the other enemy draws, or MultiMesh per spec §9).
- [ ] **Step 7: Commit** `M11c: emit score only on change, restyle chip on tier change; next: Task 7`.

### Task 7: The cold open is not centred (user report)

**Status:** done `da2ef3a` — root cause: stack sized before tree entry (0×0) and grown END-ward; now grows both ways. A55 visual pending.

**Files:** investigate first, via `godot/src/ui/entrance_cinematic.gd` and `scenes/main.tscn` (the `ColdOpen` node).

- [ ] **Step 1: Reproduce on the A55.** `adb shell screenrecord --time-limit 3 /sdcard/co.mp4` started just before tapping Play. Pull it, extract a frame (`ffmpeg -ss 0.3`, if present; otherwise screencap in a loop), and measure the stack's centre against the screen centre (1170, 540).
- [ ] **Step 2: Find the cause** (systematic-debugging): the `ColdOpen` anchors, the stack's layout under `UiTheme.px` scaling, or the `arena_origin` inset. Write a headless test that lays the `ColdOpen` out at 2340 × 1080 physical px (the A55's `ui_scale`) and asserts the ship/title/bar centres within 1 px of the viewport centre. It must fail before the fix.
- [ ] **Step 3: Fix, re-run, verify on the A55, commit** `M11c: centre the cold open at phone scale; next: Task 8`.

### Task 8: Move the start ring out (P8)

**Status:** done `805d68c`; A55 visual pending.

**Files:** Modify `godot/src/ui/entrance_cinematic.gd:30-33` and its seeker loop (`:200-212`); test `godot/tests/test_entrance_cinematic.gd` (`test_classic_hands_over_eight_ringed_seekers_a_nuke_and_a_shield`, :80).

- [ ] **Step 1: Failing test.** Add `test_start_ring_scales_with_the_arena`: finish a Classic cold open with bounds 2162 × 1056 (the A55). Assert that every seeker's distance from (1081, 528) is `0.42 × 1056` ± 0.01, and that none is closer than 443. With bounds 1280 × 720, assert the radius is exactly 302.4 (0.42 × 720), since that is above the 260 floor. With 600 × 500, assert 260 (the floor). Existing assertions in `:80` that pin 260 get updated to the new formula; record that in the ledger.
- [ ] **Step 2: Run** → FAIL (the radius is 260).
- [ ] **Step 3: Implement.**

```gdscript
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:205 — now the floor.
const SEEKER_RADIUS: float = 260.0
## DIVERGENCE(M11c P8): user ruling 2026-09-26, "further away would make it easier
## for players to evade" — the ring scales with the arena's short side.
const SEEKER_RADIUS_FRACTION: float = 0.42
```

and in the loop, `var radius: float = maxf(SEEKER_RADIUS, minf(width, height) * SEEKER_RADIUS_FRACTION)`, used in place of `SEEKER_RADIUS`.
- [ ] **Step 4: Run** → PASS; full suite green.
- [ ] **Step 5: A55.** Start 3 Classic runs and screenshot the handover. The ring sits well away from the ship. Record in `VERIFY-ME.md` §M11b check 4 that the ring was moved (P8).
- [ ] **Step 6: Commit** `M11c: widen the classic start ring on large arenas; next: Task 7`.

### (Superseded) Ring spawns and options display (user report — needs the user first)

- [ ] **Step 1: Ask the user** (Open questions 1–2) which ring and which options, with a screenshot of each.
- [ ] **Step 2: Measure the ring on the A55.**
  - Screenshot the ring at spawn and compute the gap between neighbouring dots at their **drawn** size (`MOBILE_MODEL_SCALE = 1.5`) and at their **hitbox** size, against the ship's hitbox diameter.
  - If the hitbox gap exceeds the ship but the drawn gap does not, the "no escape" is visual: the M2.5 mobile model scale closes gaps that exist. That is a finding for the user, not a port bug.
  - If the hitbox gap is smaller than the ship, check the ring's radius and count against the TS with `MOBILE_ARENA_SCALE_CEILING` applied.
- [ ] **Step 3:** Record the findings and rulings in `HANDOFF.md`; any fix gets its own task after the user rules.

### Task 9: Exit of part 1

**Status:** docs done in the exit commit; the A55 measurement is the remaining gate (HANDOFF Next).

- [ ] Update `VERIFY-ME.md`: a new §M11c-perf with the exit numbers. Tick every earlier frame-time check that the Task 6 measurement now covers. Those checks were never really run, since gfxinfo was blind.
- [ ] Update `HANDOFF.md` (State, Evidence with before/after, Next = plan M11c part 2) and `PORT-PROGRESS.md` (the M11c row: part 1 done).
- [ ] Run the full verification block (tests, gdformat, gdlint, headless 0 SCRIPT ERROR, DIVERGENCE count = 244 + the new tags).
- [ ] Commit `M11c: perf pass done; next: read godot/HANDOFF.md, then plan M11c part 2`.

## Open questions (for the user)

1. **"The circle spawn mobs that surround you."** Is that the ring at the **start of the run**: 8 seekers around the ship, with the nuke orb and a 2.5 s shield (M11b R12)? Or the ring **formation** that appears every so often, pauses, then closes in (M3)? The start ring is TS-faithful and the shield is meant as the way out. The formation ring's spacing shrinks on mobile (`MOBILE_ARENA_SCALE_CEILING = 1.25`) while the dots draw 1.5× larger (`MOBILE_MODEL_SCALE`). Task 8 measures which applies.
2. **"Some options don't show correctly."** Which screen: Settings, Pause, or the menu's mode cards and Steer row? What looks wrong: clipped, overlapping, wrong value? A screenshot is enough.
3. **P2's slow-down.** With the cap, an overloaded moment plays in slow motion instead of dropping frames. If Tasks 3–6 reach the target, it never triggers. Say if you would rather keep the uncapped (TS) behaviour.
