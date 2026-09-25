# Module 11b — Entrance cinematic: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Play, Retry, Pause's Restart and Space/Enter/r after a death no longer drop straight into a run. They open the 600 ms cold open: a void screen with the ship glyph, "PERIL POINT" and a progress bar, plus the warp-in sound. When the bar fills, or on a tap or Space/Enter/Escape, the run gets its mode's start armada, the nuke/vortex orbs, a 2.5 s spawn shield, then the music and the ship's starting orb.

**Architecture:** `TiltEntranceCinematic.ts` becomes one file, `ui/entrance_cinematic.gd` (Law 3). It is a `Control` that holds the sim references the TS constructor takes, runs `start`/`update`/`skip`/`finish` as written, and draws the `ColdOpen.dc.html` board in place of the TS `overlayEl`. `GameStateMachine.start_cinematic` enters `CINEMATIC` after `reset_run`. `GameRoot` owns the cinematic, as it owns the menu. It starts the cinematic, ticks it in `_physics_process` and routes the skips. The TS `onFinish` (`TiltGame.ts:168-177`) is split: `GameRoot._on_cinematic_finished` sets `PLAYING`, and `RunController.finish_cinematic` starts the music and spawns the starting orb, which `reset_run` has done until now (M6 R7).

**Tech Stack:** Godot 4.7.2-stable, GDScript (static typing enforced), GUT 9.6.1 headless, gdtoolkit 4.5.0.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` §8 Module 11 (split 2026-09-25; M11b = entrance cinematic), §5.1. `docs/superpowers/specs/2026-09-23-mobile-interface-system-design.md` §6.6 ("their mock content and any behaviour they imply beyond the TS need their own rulings at M11") and §4 (tokens). Board: `peril-point-mobile-redesign/ColdOpen.dc.html`. Read `godot/CONVENTIONS.md` before any task.

**TS source (read in full before the task that ports it):**
- `web/src/tilt-to-live/TiltEntranceCinematic.ts` (221 lines, source commit 7be9614): Task 1.
- `web/src/styles/game.css:3690-3765` (`.tilt-cold-open-root` … `.cold-open-progress-fill`) and `:1042-1054` (`.tilt-cinematic-overlay`, z-index 50): Task 1.
- `TiltGame.ts:160-178` (constructor + `onFinish`), `:1302-1316` (cinematic keys, restart keys), `:1348-1364` (skip controls), `:1382-1390`, `:1423-1426` (Restart/Retry buttons), `:1496-1545` (`returnToMenu`, `restart`, `startCinematic`, `stop`), `:1612-1613` (`resetRun` hides the modals), `:1829-1837` (the cinematic tick), `:1960-1979` (`spawnStartingWeaponOrb`): Task 2.

---

## The five port laws (restated — binding on every task)

1. **No invented numbers.** Every numeric literal carries `# PORT: <ts path>:<line>` or, for a board literal, `# DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html`. Exempt: `0`, `1`, `-1`, `0.0`, `1.0`, array indices.
2. **No silent improvement.** Odd TS is ported as written, with `# PORT-NOTE: … — preserved deliberately`.
3. **One file, one file.** `TiltEntranceCinematic.ts` → `ui/entrance_cinematic.gd`, holding both the cinematic logic and its overlay.
4. **Nothing new.** Only what the TS, a spec line, or a ruling below requires.
5. **Stop, do not guess.** Ambiguity → record it in `godot/HANDOFF.md` and ask.

## Rulings (planning, 2026-09-26 — precedent-based; the user reviews them with this plan)

- **R1 — The board is the layout authority.** The TS injects its own DOM (`TiltEntranceCinematic.ts:78-93`, styled at `game.css:3690-3765`): a 72 px ship, a `clamp(48px, 6vw, 76px)` title, and a 200 × 2 bar 120 px from the bottom. `ColdOpen.dc.html` draws a 52 px ship, a 58 px title with an 18 px gap, and a 160 × 2 bar 44 px from the bottom, over a `radial-gradient(420px 260px at 50% 50%, rgba(91,140,255,0.08), transparent 72%)` glow on void. The board wins (M8.5: the boards are the visual authority for every screen). The title is `"PERIL POINT"`, not the TS `"TILT TO LIVE"` (app identity; M11a R6 precedent). Every board literal is tagged `DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html`.
- **R2 — `render()` is not ported.** `TiltEntranceCinematic.render` (`:131-171`) paints a wash, a ship and a bar on the canvas. The overlay above it is opaque: `.tilt-cold-open-root` has `background: #08090E` (`game.css:3695`) at z-index 50 (`:1045`). The player never sees that canvas layer, so it has no port. A PORT-NOTE in the file header says so.
- **R3 — The ship's glow waits for M11c.** The board's `drop-shadow(0 0 20px rgba(91,140,255,0.9))` is a glow, and spec §4.5 defers every glow to the M11c device measurement. The ship is drawn flat, with `TODO(M11c)` at the site, the same as `handling_preview.gd:16`.
- **R4 — The bar fills as the TS sets it.** The fill width is `bar_width × roundi(progress × 100) / 100` (`:110`, `:115`), set on every `update`. The 50 ms CSS `transition: width 0.05s linear` (`game.css:3764`) is not ported (PORT-NOTE). It is three frames and smooths an animation that already moves every frame.
- **R5 — `GameRoot` owns the cinematic.** `GameStateMachine` holds no UI (spec §5.1, its own header). `start_cinematic` therefore does `reset_run(mode)` and then `phase = CINEMATIC` (`:1525-1526`). `GameRoot._begin_cinematic` does the rest of `startCinematic`: the sim reset (`RunController.reset_run`) and `_cinematic.start` (`:1527-1529`). `return_to_menu`'s and `stop`'s `cinematic.skip` (`:1504-1506`, `:1538-1540`) become PORT-NOTEs in the machine. `GameRoot.return_to_menu` makes the real call.
- **R6 — The `onFinish` split.** `TiltGame.ts:168-177` is split in two. `GameRoot._on_cinematic_finished` sets `_state.phase = PLAYING` (`:169`) and emits `phase_changed(PLAYING)`. `RunController.finish_cinematic(bounds)` does music-if-enabled then `spawn_starting_weapon_orb` (`:170-176`). Both calls leave `RunController.reset_run`, which closes M6 R7's stand-in.
- **R7 — The skip inputs.** A tap or click anywhere on the overlay skips (`:96-102`). The TS `{ once: true }` is not ported: `skip` is already idempotent (`:174`). Space, Enter, keypad Enter and Escape skip in `CINEMATIC` (`:1302-1309`; `e.key === 'Enter'` matches both Enter keys). These keys are checked **before** the restart and pause keys, so Escape skips and never pauses. The `.tilt-cinematic-skip` listener (`:1349-1356`) has no element in `web/index.html`, so it gets no port (PORT-NOTE). The canvas `pointerdown` (`:1358-1364`) sits under the full-screen overlay, so the overlay tap stands for it (PORT-NOTE).
- **R8 — `return_to_menu` calls `skip` as the TS does.** `returnToMenu` sets `phase = 'menu'` and **then** calls `cinematic.skip`. If a cold open were playing, `finish` would spawn the armada and `onFinish` would set `phase = 'playing'`. The port keeps that order (Law 2). No path reaches it: `return_to_menu`'s only callers are Pause's Quit and Run over's Menu, and the opaque overlay covers both, since `CINEMATIC` hides both sheets (R9). The PORT-NOTE says so, and Open question 1 connects it to M11a's Q3 (Android back).
- **R9 — `CINEMATIC` hides the modals.** `resetRun` hides the pause and game-over modals (`:1612-1613`) before `startCinematic` sets `phase = 'cinematic'`. `HudController._on_phase_changed` therefore treats `CINEMATIC` as it treats `PLAYING`: it hides both sheets and stops the run-over timer. Without this, a restart key pressed inside the run-over's 450 ms delay (M9 I-1) would open a stale Run over sheet during the new run.
- **R10 — Every restart replays the cold open.** Pause's Restart (`:1384`), Run over's Retry (`:1389`, `:1425`) and Space/Enter/r in `GAME_OVER` (`:1315`) all call `startCinematic`. `GameRoot.restart_run` now goes through `_state.restart()` → `start_cinematic` → `reset_run`, as M10's F-2 note anticipated. This means a restart now also re-applies `reset_run`'s tilt-sensor rule and re-centres the router (TS-faithful). M2.5's `calibrate_current_position()` in `restart_run` is kept unchanged.
- **R11 — The cinematic ticks in real time.** The TS loop passes the raw `dt` to the grid, the particles and `cinematic.update` in `'cinematic'` (`:1831-1836`), with no `GAME_SPEED`. The existing `CINEMATIC` arm of `_physics_process` already does this for the grid and the particles; the cinematic joins it.
- **R12 — The start armada is new gameplay in the port, and it is faithful.** The port's runs currently start empty. After M11b a Classic run starts with 8 seekers in a 260 px ring (each clamped 40 px inside the arena), a nuke orb and a 2.5 s shield. Code Red starts with `spawnModeArmada`'s 24-seeker ring, a vortex and a nuke. Gauntlet starts with the armada's 8 edge seekers and a nuke. `spawn_mode_armada`'s `TODO(M11b)` (M10 R3) is resolved here. The device pass judges the feel (VERIFY-ME §M11b).

## Global Constraints

- **Tests run only via `tools/run_tests.sh`.** Baseline at the M11a exit: `OK: 53/53 scripts (611 tests, 17973 asserts)`. This plan adds one script (`test_entrance_cinematic.gd`), so 54. Each task states its **delta**; if a delta differs, reconcile it and record why in the SDD ledger. Never change the expectation to match.
- **Format and lint** after every task: `gdformat --check godot/src godot/tests` (baseline 96 files; +2 after Task 1) and `gdlint godot/src godot/tests`.
- **Headless runs strip one default-valued line from `godot/project.godot`.** Run `git checkout godot/project.godot` before every commit, and never commit that line.
- **Commits are one line, no trailers** (CONVENTIONS §8, the user's global rule). A task commit names the next task, e.g. `M11b: port the entrance cinematic; next: Task 2`.
- **Colours come from `UiTheme` tokens**: `COLOR_VOID` `#08090E`, `COLOR_ION` `#5B8CFF`, `COLOR_RAISED` `#1B2029` and `COLOR_TEXT` `#E6E9F0`. The only exceptions are the TS's own `'#5B8CFF'` particle burst (`:71`, a PORT literal) and the SVG path fill, which is a board literal.
- **Scale:** every board px goes through `UiTheme.px(base, _ui_scale)`. `GameRoot.resize_canvas` passes `HudController.ui_scale_for(viewport)`, as it does for the other screens.
- **Arena coordinates:** the cinematic's `width`/`height` are `GameRoot._bounds`, the playfield size the whole sim uses. This is what the TS `canvas.width / pixelRatio` stands for.

## Review Focus

1. **A skip in the same tick as the natural end.** A tap arrives while `update` has just finished the cold open, or Escape is pressed twice. The armada, the orbs, the music and the starting orb must be handed over exactly once. Tested in Task 1 (`skip` after `finish` is a no-op) and in Task 2 (one `start_music`, orb count after a double skip).
2. **Rotation or resize mid-cinematic.** `set_ui_scale` rebuilds the overlay. It must stay visible and keep its current fill, not reset to empty or vanish. Tested in Task 1.
3. **Restart pressed inside the run-over's 450 ms delay.** Space right after death must not let the stale Run over sheet open over the new run (R9). Tested in Task 2.
4. **Escape during the cold open.** Escape must skip and not pause. The run then plays unpaused. Tested in Task 2.
5. **Retry replays the cold open, with nothing doubled.** After Retry the arena holds only the new handover (the previous run's enemies and orbs are gone), with one starting orb and music started once. Tested in Task 2.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `godot/src/ui/entrance_cinematic.gd` (new) | `TiltEntranceCinematic.ts`: start/update/skip/finish on the run's sim systems, plus the ColdOpen board overlay | 1 |
| `godot/tests/test_entrance_cinematic.gd` (new) | the cinematic in isolation, with real sim systems and a `SpyAudioBank` | 1 |
| `godot/src/core/game_state_machine.gd` | `start_cinematic` enters `CINEMATIC`; the skip PORT-NOTEs | 2 |
| `godot/src/core/game_root.gd` | owns `_cinematic`; `_begin_cinematic`, `_on_cinematic_finished`, `skip_cinematic`; launch/restart/return; keys; tick; resize | 2 |
| `godot/src/sim/run_controller.gd` | `finish_cinematic` takes over the music and the starting orb from `reset_run` | 2 |
| `godot/src/ui/hud_controller.gd` | `_on_phase_changed` hides the sheets on `CINEMATIC` (R9) | 2 |
| `godot/src/sim/enemy_swarm.gd` | `spawn_mode_armada`'s `TODO(M11b)` becomes its caller citation | 2 |
| `godot/scenes/main.tscn` | `CanvasLayer/ColdOpen` between `GoalsHud` and `Armory` | 2 |
| tests: `test_main_scene.gd`, `test_game_state_machine.gd`, `test_run_controller.gd`, `test_audio_call_sites.gd` | the phase, the handover, the moved music/orb | 2 |
| `godot/VERIFY-ME.md`, `PORT-PROGRESS.md`, `HANDOFF.md`, index plan | exit | 3 |

`ColdOpen` sits after `GoalsHud` and before `Armory` in `CanvasLayer`. This matches the TS stacking: the overlay's z-index 50 is above the goals HUD and the modals (≤ 40) and below the Armory (100, `game.css:1603`).

---

## Tasks

### Task 1: `EntranceCinematic` — the cold open

**Files:**
- Create: `godot/src/ui/entrance_cinematic.gd`
- Test: `godot/tests/test_entrance_cinematic.gd`

**Interfaces:**
- Consumes (existing): `AudioBank.play_warp_in()`; `PlayerShip.reset(x, y)`, `.x`, `.y`, `.angle`, `.activate_shield(duration)`, `.shield_timer`; `EnemySwarm.reset()`, `.spawn_seeker(bounds, x, y) -> Types.Enemy`, `.spawn_mode_armada(mode, bounds, player_pos)`, `.enemies`; `VectorGrid.apply_explosion(cx, cy, force, radius)`; `ParticleEngine.emit_explosion(x, y, color, count)`, `.particles`; `WeaponSystem.reset()`, `.spawn_orb(bounds, type, x, y)`, `.orbs`; `UiTheme.px`, `.flat`, `.tint`, `.svg_texture`, `.archivo`, `.build`, `WORDMARK_WIDTH`, the colour tokens.
- Produces (Task 2 relies on these exact names):
  - `class_name EntranceCinematic extends Control`
  - `signal skip_requested` (a tap on the overlay while playing)
  - `const DURATION: float = 0.6`
  - `var is_playing: bool`, `var elapsed: float`
  - `func bind(audio: AudioBank, player: PlayerShip, swarm: EnemySwarm, grid: VectorGrid, particles: ParticleEngine, weapons: WeaponSystem, on_finish: Callable) -> void`
  - `func start(width: float, height: float, mode: Types.GameMode) -> void`
  - `func update(dt: float, width: float, height: float) -> bool` (true on the tick it finishes)
  - `func skip(width: float, height: float) -> void`
  - `func progress() -> float`
  - `func set_ui_scale(scale: float) -> void`
  - Node names: `Void`, `Glow`, `Stack`, `Ship`, `Title`, `BarTrack`, `BarFill`

- [ ] **Step 1: Write the failing test.** Create `godot/tests/test_entrance_cinematic.gd`:

```gdscript
## test_entrance_cinematic.gd
## PORTS: nothing — new file, covers ui/entrance_cinematic.gd
extends GutTest
## The 600 ms cold open (TiltEntranceCinematic.ts) on the ColdOpen board (M11b R1).

const BOUNDS: Vector2 = Vector2(844.0, 390.0)

var _audio: SpyAudioBank = null
var _player: PlayerShip = null
var _swarm: EnemySwarm = null
var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _weapons: WeaponSystem = null
var _finished: int = 0


func _cinematic() -> EntranceCinematic:
	_audio = SpyAudioBank.new()
	_player = PlayerShip.new(0.0, 0.0)
	_swarm = EnemySwarm.new()
	_grid = VectorGrid.new(BOUNDS.x, BOUNDS.y)
	_particles = ParticleEngine.new()
	_weapons = WeaponSystem.new()
	_finished = 0
	var c: EntranceCinematic = EntranceCinematic.new()
	c.theme = UiTheme.build(1.0)
	c.size = BOUNDS
	add_child_autofree(c)
	c.bind(_audio, _player, _swarm, _grid, _particles, _weapons, func() -> void: _finished += 1)
	return c


func test_start_clears_the_arena_centres_the_ship_and_warps_in() -> void:
	var c: EntranceCinematic = _cinematic()
	_swarm.spawn_seeker(BOUNDS, 10.0, 10.0)
	_weapons.spawn_orb(BOUNDS, Types.WeaponType.NUKE, 100.0, 100.0)
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	assert_true(c.is_playing, ":56")
	assert_true(c.visible, ":94")
	assert_eq(c.elapsed, 0.0, ":57")
	assert_eq(_swarm.enemies.size(), 0, ":60")
	assert_eq(_weapons.orbs.size(), 0, ":61")
	assert_eq(Vector2(_player.x, _player.y), BOUNDS / 2.0, ":64-66")
	assert_almost_eq(_player.angle, -PI / 2.0, 0.0001, ":67")
	assert_eq(_particles.particles.size(), 25, ":71 — 24 sparks + the shockwave ring (ParticleEngine.ts:70-87)")
	assert_eq(_audio.requested, ["warp_in"] as Array[String], ":74 (M5 R8)")
	assert_eq(_finished, 0)


func test_update_holds_the_ship_and_fills_the_bar() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	_player.x = 5.0
	_player.angle = 0.0
	assert_false(c.update(0.3, BOUNDS.x, BOUNDS.y), ":128")
	assert_almost_eq(c.progress(), 0.5, 0.0001, ":110")
	assert_eq(Vector2(_player.x, _player.y), BOUNDS / 2.0, ":119-120")
	assert_almost_eq(_player.angle, -PI / 2.0, 0.0001, ":121")
	var fill: Control = c.find_child("BarFill", true, false) as Control
	assert_almost_eq(fill.size.x, 80.0, 0.001, "160 × 50% (R4)")


func test_it_finishes_on_the_tick_that_reaches_600_ms() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	assert_false(c.update(0.59, BOUNDS.x, BOUNDS.y))
	assert_eq(_finished, 0)
	assert_true(c.update(0.02, BOUNDS.x, BOUNDS.y), ":123-126")
	assert_false(c.is_playing, ":180")
	assert_false(c.visible, ":184")
	assert_eq(_finished, 1, ":219")
	assert_false(c.update(0.1, BOUNDS.x, BOUNDS.y), ":107 — idle update is a no-op")
	assert_eq(_finished, 1)


func test_classic_hands_over_eight_ringed_seekers_a_nuke_and_a_shield() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	c.skip(BOUNDS.x, BOUNDS.y)
	assert_eq(_swarm.enemies.size(), 8, ":204")
	# i = 0: x = min(844-40, 422+260) = 682, y = 195 (:207-209)
	assert_almost_eq(_swarm.enemies[0].x, 682.0, 0.001)
	assert_almost_eq(_swarm.enemies[0].y, 195.0, 0.001)
	# i = 2 (90°): y = min(390-40, 195+260) = 350 (:209 clamp)
	assert_almost_eq(_swarm.enemies[2].y, 350.0, 0.001)
	assert_eq(_weapons.orbs.size(), 1)
	assert_eq(_weapons.orbs[0].type, Types.WeaponType.NUKE, ":212")
	assert_almost_eq(_weapons.orbs[0].x, 422.0, 0.001)
	assert_almost_eq(_weapons.orbs[0].y, 175.5, 0.001, "height × 0.45")
	assert_almost_eq(_player.shield_timer, 2.5, 0.0001, ":216")
	assert_eq(_finished, 1)


func test_code_red_hands_over_its_armada_a_vortex_and_a_nuke() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CODE_RED)
	c.skip(BOUNDS.x, BOUNDS.y)
	assert_eq(_swarm.enemies.size(), 24, ":196 → EnemySwarm.ts:784")
	assert_eq(_weapons.orbs.size(), 2)
	assert_eq(_weapons.orbs[0].type, Types.WeaponType.VORTEX, ":197")
	assert_almost_eq(_weapons.orbs[0].x, 342.0, 0.001, "w/2 - 80")
	assert_eq(_weapons.orbs[1].type, Types.WeaponType.NUKE, ":198")
	assert_almost_eq(_weapons.orbs[1].x, 502.0, 0.001, "w/2 + 80")


func test_gauntlet_hands_over_its_armada_and_a_nuke() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.GAUNTLET)
	c.skip(BOUNDS.x, BOUNDS.y)
	assert_eq(_swarm.enemies.size(), 8, ":200 → EnemySwarm.ts:794")
	assert_eq(_weapons.orbs.size(), 1)
	assert_eq(_weapons.orbs[0].type, Types.WeaponType.NUKE, ":201")


func test_skip_is_idempotent_and_ignored_when_idle() -> void:
	var c: EntranceCinematic = _cinematic()
	c.skip(BOUNDS.x, BOUNDS.y)
	assert_eq(_finished, 0, ":174 — nothing playing")
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	c.skip(BOUNDS.x, BOUNDS.y)
	c.skip(BOUNDS.x, BOUNDS.y)
	assert_false(c.update(0.0, BOUNDS.x, BOUNDS.y), "idle after the skip")
	assert_eq(_finished, 1, "Review Focus 1: one handover")
	assert_eq(_swarm.enemies.size(), 8, "no second armada")


func test_a_tap_or_click_asks_to_skip_only_while_playing() -> void:
	var c: EntranceCinematic = _cinematic()
	watch_signals(c)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	c._gui_input(touch)
	assert_signal_not_emitted(c, "skip_requested", "idle overlay")
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	c._gui_input(touch)
	assert_signal_emit_count(c, "skip_requested", 1, ":102 touchstart")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	c._gui_input(click)
	assert_signal_emit_count(c, "skip_requested", 2, ":101 click")
	assert_eq(c.mouse_filter, Control.MOUSE_FILTER_STOP, "the overlay eats the tap")


func test_the_board_is_built_as_drawn() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	await get_tree().process_frame
	for node_name: String in ["Void", "Glow", "Stack", "Ship", "Title", "BarTrack", "BarFill"]:
		assert_not_null(c.find_child(node_name, true, false), node_name)
	var title: Label = c.find_child("Title", true, false) as Label
	assert_eq(title.text, "PERIL POINT", "R1: app identity")
	assert_eq(title.get_theme_font_size("font_size"), 58, "ColdOpen.dc.html h1")
	var track: Control = c.find_child("BarTrack", true, false) as Control
	assert_eq(track.size, Vector2(160.0, 2.0), "ColdOpen.dc.html bar")
	assert_almost_eq(track.position.y + track.size.y, BOUNDS.y - 44.0, 0.5, "bottom 44")
	assert_almost_eq(track.position.x + track.size.x / 2.0, BOUNDS.x / 2.0, 0.5, "centred")
	var ship: TextureRect = c.find_child("Ship", true, false) as TextureRect
	assert_eq(ship.texture.get_size(), Vector2(52.0, 52.0), "ColdOpen.dc.html svg 52")


func test_a_resize_mid_cinematic_keeps_it_showing_and_filled() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	c.update(0.3, BOUNDS.x, BOUNDS.y)
	c.set_ui_scale(2.0)
	assert_true(c.visible, "Review Focus 2")
	var track: Control = c.find_child("BarTrack", true, false) as Control
	var fill: Control = c.find_child("BarFill", true, false) as Control
	assert_eq(track.size, Vector2(320.0, 4.0))
	assert_almost_eq(fill.size.x, 160.0, 0.001, "still half full after the rebuild")
```

- [ ] **Step 2: Run it to verify it fails.** `tools/run_tests.sh` should report `collected 53 of 54`, because the script fails to parse while `EntranceCinematic` does not exist. Confirm with `"$GODOT" --headless --path godot --check-only -s tests/test_entrance_cinematic.gd`, which should print that `EntranceCinematic` is not declared.

- [ ] **Step 3: Write `godot/src/ui/entrance_cinematic.gd`.**

```gdscript
## entrance_cinematic.gd
## PORTS: web/src/tilt-to-live/TiltEntranceCinematic.ts (221 lines, source commit 7be9614)
class_name EntranceCinematic
extends Control
## The 600 ms cold open between Play/Retry and the run. It resets the arena,
## holds the ship at the centre and fills a bar, then hands the run a
## mode-specific armada and a spawn shield. Drawn on ColdOpen.dc.html (M11b R1).
##
## PORT-NOTE: the TS injects its overlay DOM (:78-93); this Control is that
## overlay, built on the board. render() (:131-171) paints the canvas under an
## opaque overlay (game.css:3695, z-index 50 at :1045) that the player never
## sees, so it has no port (M11b R2).
## PORT-NOTE: GameRoot owns this node and ticks it (M11b R5); the TS
## constructor's renderer argument (:38) is never read by the class, so bind()
## omits it.

## A tap or click on the overlay while playing. GameRoot answers with skip().
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:96-102
signal skip_requested

## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:27
const DURATION: float = 0.6
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:70
const RIPPLE_FORCE: float = 260.0
const RIPPLE_RADIUS: float = 60.0
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:71
const BURST_COLOR: Color = Color("#5B8CFF")
const BURST_COUNT: int = 24
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:204-205
const SEEKER_COUNT: int = 8
const SEEKER_RADIUS: float = 260.0
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:208-209
const SEEKER_MARGIN: float = 40.0
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:197-198
const ORB_SPREAD: float = 80.0
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:197, :201, :212
const ORB_Y_RATIO: float = 0.45
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:216
const SPAWN_SHIELD: float = 2.5
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:115 (whole-percent width)
const PERCENT: float = 100.0

## DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — radial-gradient(420px 260px at 50% 50%,
## rgba(91,140,255,0.08), rgba(0,0,0,0) 72%)
const GLOW_RADII: Vector2 = Vector2(420.0, 260.0)
const GLOW_ALPHA: float = 0.08
const GLOW_STOP: float = 0.72
## DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — centre stack gap 18
const STACK_GAP: int = 18
## DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — ship svg 52×52 on a 72 viewBox, ion fill.
## TODO(M11c): its drop-shadow(0 0 20px rgba(91,140,255,0.9)) glow (spec §4.5, M11b R3).
const SHIP_SVG: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="52" height="52" viewBox="0 0 72 72" '
	+ 'fill="none"><path d="M62 36 L20 13 L28 36 L20 59 Z" fill="#5B8CFF"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — h1 58px, letter-spacing -0.015em
const TITLE_SIZE: int = 58
const TITLE_TRACKING_EM: float = -0.015
## DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — bar 160×2, radius 2, bottom 44
const BAR_WIDTH: int = 160
const BAR_HEIGHT: int = 2
const BAR_RADIUS: int = 2
const BAR_BOTTOM: int = 44

## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:25
var is_playing: bool = false
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:26
var elapsed: float = 0.0

## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:24
var _game_mode: Types.GameMode = Types.GameMode.CLASSIC
var _audio: AudioBank = null
var _player: PlayerShip = null
var _swarm: EnemySwarm = null
var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _weapons: WeaponSystem = null
var _on_finish: Callable = Callable()
var _ui_scale: float = 1.0
var _fill: Panel = null


## The TS constructor's systems. PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:32-52
func bind(
	audio: AudioBank,
	player: PlayerShip,
	swarm: EnemySwarm,
	grid: VectorGrid,
	particles: ParticleEngine,
	weapons: WeaponSystem,
	on_finish: Callable
) -> void:
	_audio = audio
	_player = player
	_swarm = swarm
	_grid = grid
	_particles = particles
	_weapons = weapons
	_on_finish = on_finish


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:54-104
func start(width: float, height: float, mode: Types.GameMode) -> void:
	_game_mode = mode
	is_playing = true
	elapsed = 0.0

	_swarm.reset()
	_weapons.reset()

	var cx: float = width / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:64
	var cy: float = height / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:65
	_player.reset(cx, cy)
	_player.angle = -PI / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:67

	_grid.apply_explosion(cx, cy, RIPPLE_FORCE, RIPPLE_RADIUS)
	_particles.emit_explosion(cx, cy, BURST_COLOR, BURST_COUNT)

	_audio.play_warp_in()  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:74

	_set_fill(0.0)
	visible = true  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:94


## Returns true on the tick the cold open ends.
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:106-129
func update(dt: float, width: float, height: float) -> bool:
	if not is_playing:
		return false

	elapsed += dt
	_set_fill(progress())

	_player.x = width / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:119
	_player.y = height / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:120
	_player.angle = -PI / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:121

	if elapsed >= DURATION:
		_finish(width, height)
		return true
	return false


## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:110, :136
func progress() -> float:
	return minf(1.0, elapsed / DURATION)


## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:173-176
func skip(width: float, height: float) -> void:
	if not is_playing:
		return
	_finish(width, height)


## Rebuilds the board at `scale`, keeping its visibility and fill (Review Focus 2).
func set_ui_scale(scale: float) -> void:
	_ui_scale = scale
	theme = UiTheme.build(scale)
	_build()


## The overlay's click/touchstart skip. PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:96-102
# PORT-NOTE: `{ once: true }` (:101-102) is not ported; skip() is idempotent (:174) (M11b R7).
func _gui_input(event: InputEvent) -> void:
	var is_press: bool = false
	if event is InputEventScreenTouch:
		is_press = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		is_press = (event as InputEventMouseButton).pressed
	if is_press and is_playing:
		accept_event()
		skip_requested.emit()


## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:178-220
func _finish(width: float, height: float) -> void:
	if not is_playing:
		return
	is_playing = false
	visible = false  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:184

	_swarm.reset()
	var bounds: Vector2 = Vector2(width, height)
	var player_pos: Vector2 = Vector2(_player.x, _player.y)
	var orb_y: float = height * ORB_Y_RATIO

	if _game_mode == Types.GameMode.CODE_RED:
		_swarm.spawn_mode_armada(Types.GameMode.CODE_RED, bounds, player_pos)
		_weapons.spawn_orb(bounds, Types.WeaponType.VORTEX, width / 2.0 - ORB_SPREAD, orb_y)  # PORT: :197
		_weapons.spawn_orb(bounds, Types.WeaponType.NUKE, width / 2.0 + ORB_SPREAD, orb_y)  # PORT: :198
	elif _game_mode == Types.GameMode.GAUNTLET:
		_swarm.spawn_mode_armada(Types.GameMode.GAUNTLET, bounds, player_pos)
		_weapons.spawn_orb(bounds, Types.WeaponType.NUKE, width / 2.0, orb_y)  # PORT: :201
	else:
		for i: int in range(SEEKER_COUNT):
			var ang: float = (float(i) / float(SEEKER_COUNT)) * PI * 2.0  # PORT: :207
			var x: float = clampf(
				width / 2.0 + cos(ang) * SEEKER_RADIUS, SEEKER_MARGIN, width - SEEKER_MARGIN
			)  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:208
			var y: float = clampf(
				height / 2.0 + sin(ang) * SEEKER_RADIUS, SEEKER_MARGIN, height - SEEKER_MARGIN
			)  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:209
			_swarm.spawn_seeker(bounds, x, y)
		_weapons.spawn_orb(bounds, Types.WeaponType.NUKE, width / 2.0, orb_y)  # PORT: :212

	_player.activate_shield(SPAWN_SHIELD)

	if _on_finish.is_valid():
		_on_finish.call()  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:219


## Sets the fill to whole percents, as the TS sets `style.width` (M11b R4).
# PORT-NOTE: the 50 ms `transition: width 0.05s linear` (game.css:3764) is not
# ported — the bar is already set every tick.
func _set_fill(fraction: float) -> void:
	if _fill == null:
		return
	_fill.size.x = UiTheme.px(BAR_WIDTH, _ui_scale) * (roundi(fraction * PERCENT) / PERCENT)


func _build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	var void_rect: ColorRect = ColorRect.new()
	void_rect.name = "Void"
	void_rect.color = UiTheme.COLOR_VOID
	void_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(void_rect)
	void_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	add_child(_glow())
	add_child(_stack())
	add_child(_bar())

	visible = is_playing
	_set_fill(progress())


# DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — the glow ellipse, stretched from a
# radial GradientTexture2D sized to the board's diameters (2 × the 420×260 radii).
func _glow() -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, GLOW_STOP])
	gradient.colors = PackedColorArray(
		[UiTheme.tint(UiTheme.COLOR_ION, GLOW_ALPHA), UiTheme.tint(UiTheme.COLOR_ION, 0.0)]
	)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)  # DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — at 50% 50%
	texture.fill_to = Vector2(1.0, 0.5)
	var diameter: Vector2 = GLOW_RADII * 2.0  # DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — radii → size
	texture.width = roundi(diameter.x)
	texture.height = roundi(diameter.y)

	var glow: TextureRect = TextureRect.new()
	glow.name = "Glow"
	glow.texture = texture
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = Vector2(UiTheme.px(diameter.x, _ui_scale), UiTheme.px(diameter.y, _ui_scale))
	glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	return glow


func _stack() -> VBoxContainer:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "Stack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", UiTheme.px(STACK_GAP, _ui_scale))

	var ship: TextureRect = TextureRect.new()
	ship.name = "Ship"
	ship.texture = UiTheme.svg_texture(SHIP_SVG, _ui_scale)
	ship.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(ship)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "PERIL POINT"  # M11b R1: app identity (the TS :85 "TILT TO LIVE" names the web game)
	var size_px: int = UiTheme.px(TITLE_SIZE, _ui_scale)
	var wordmark: FontVariation = UiTheme.archivo(UiTheme.WORDMARK_WIDTH)
	wordmark.spacing_glyph = roundi(TITLE_TRACKING_EM * size_px)
	title.add_theme_font_override("font", wordmark)
	title.add_theme_font_size_override("font_size", size_px)
	title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title)

	stack.size = stack.get_combined_minimum_size()
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	return stack


func _bar() -> Panel:
	var width: int = UiTheme.px(BAR_WIDTH, _ui_scale)
	var height: int = UiTheme.px(BAR_HEIGHT, _ui_scale)
	var radius: int = UiTheme.px(BAR_RADIUS, _ui_scale)

	var track: Panel = Panel.new()
	track.name = "BarTrack"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.clip_contents = true  # game.css:3752 overflow: hidden
	track.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_RAISED, UiTheme.COLOR_RAISED, radius, 0)
	)
	# DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — left 50%, translateX(-50%), bottom 44
	track.anchor_left = 0.5
	track.anchor_right = 0.5
	track.anchor_top = 1.0
	track.anchor_bottom = 1.0
	track.offset_left = -width / 2.0
	track.offset_right = width / 2.0
	track.offset_bottom = -UiTheme.px(BAR_BOTTOM, _ui_scale)
	track.offset_top = track.offset_bottom - height

	_fill = Panel.new()
	_fill.name = "BarFill"
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_ION, UiTheme.COLOR_ION, radius, 0)
	)
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(0.0, height)
	track.add_child(_fill)
	return track
```

Implementation notes for this step:
- If `gdlint` flags a line as too long, wrap it the way the surrounding code does. Never drop a citation to make a line fit.
- If `UiTheme.flat`'s `border_width` of `0` still draws a border, pass the same colour for the border (as above). The visual result is the same.
- If `stack.get_combined_minimum_size()` is zero before the node enters the tree, set the stack's anchors to `PRESET_CENTER` with `grow_horizontal`/`grow_vertical = GROW_DIRECTION_BOTH` instead, and let the container size itself. The `test_the_board_is_built_as_drawn` test only checks the bar and the nodes' existence and sizes, so either approach passes. Record which one you used in the ledger.

- [ ] **Step 4: Run the tests.** `tools/run_tests.sh` → `OK: 54/54 scripts`, **+10 tests** (621). Then `gdformat --check godot/src godot/tests` (98 files) and `gdlint godot/src godot/tests`.

- [ ] **Step 5: Commit.**

```bash
git checkout godot/project.godot
git add godot/src/ui/entrance_cinematic.gd godot/src/ui/entrance_cinematic.gd.uid godot/tests/test_entrance_cinematic.gd godot/tests/test_entrance_cinematic.gd.uid docs/superpowers/plans/2026-09-20-m11b-entrance-cinematic.md
git commit -m "M11b: port the entrance cinematic on the ColdOpen board; next: Task 2"
```

(Tick this task's boxes in this plan before the commit. The `.uid` files exist only if Godot generated them. Add whichever exist.)

---

### Task 2: The CINEMATIC phase — launch, restart, skip, handover

**Files:**
- Modify: `godot/src/core/game_state_machine.gd:79-124` (`return_to_menu`, `start_cinematic`, `stop`)
- Modify: `godot/src/core/game_root.gd` (`@onready`s, `_ready` wiring, `_unhandled_input:222-234`, `_physics_process:274-276`, `launch_run:397-419`, `return_to_menu:422-434`, `restart_run:452-462`, `resize_canvas:633-639`, new `_begin_cinematic`, `_on_cinematic_finished`, `skip_cinematic`)
- Modify: `godot/src/sim/run_controller.gd:125-132` (move out), new `finish_cinematic`
- Modify: `godot/src/ui/hud_controller.gd:553` (R9)
- Modify: `godot/src/sim/enemy_swarm.gd:355` (the TODO becomes a caller citation)
- Modify: `godot/scenes/main.tscn` (ext_resource `14`, `load_steps=14`, node `ColdOpen`)
- Test: `godot/tests/test_main_scene.gd`, `godot/tests/test_game_state_machine.gd`, `godot/tests/test_run_controller.gd`, `godot/tests/test_audio_call_sites.gd`

**Interfaces:**
- Consumes: everything Task 1 produces (exact names in Task 1's Interfaces).
- Produces:
  - `GameStateMachine.start_cinematic()` leaves `phase == CINEMATIC`.
  - `RunController.finish_cinematic(arena_bounds: Vector2) -> void`
  - `GameRoot.skip_cinematic() -> void` (no-op outside `CINEMATIC`)
  - `GameRoot.launch_run` / `restart_run` leave `phase == CINEMATIC` and emit `phase_changed(CINEMATIC)`. `PLAYING` follows at the handover.

- [ ] **Step 1: Write the failing tests.**

In `test_game_state_machine.gd`, add:

```gdscript
func test_start_cinematic_resets_then_enters_the_cinematic_phase() -> void:
	_machine.start_cinematic()
	assert_eq(_machine.phase, Types.GamePhase.CINEMATIC, "TiltGame.ts:1526")
	assert_almost_eq(_player.x, 640.0, 0.0001, "resetRun ran first (:1525)")
```

and, in `test_pausing_stops_the_music_and_resuming_restarts_it` and `test_resuming_with_music_off_leaves_it_off`, insert `_machine.phase = Types.GamePhase.PLAYING  # the cinematic's handover (GameRoot, M11b R6)` right after `_machine.launch_run(...)`. Without it `toggle_pause` is a no-op in `CINEMATIC`, as the TS's is (`:1620`).

In `test_run_controller.gd`, remove the two orb assertions from `test_reset_run_initializes_state_and_spawns_orb`, rename it `test_reset_run_initializes_state`, and add `assert_eq(_weapons.orbs.size(), 0, "the starting orb waits for the cinematic (TiltGame.ts:173-176)")`. Then add:

```gdscript
func test_finish_cinematic_spawns_the_starting_orb() -> void:
	_rc.reset_run(_bounds)
	_rc.finish_cinematic(_bounds)
	assert_eq(_weapons.orbs.size(), 1, "TiltGame.ts:176")
	assert_eq(
		_weapons.orbs[0].type,
		Types.WeaponType.SHIELD,
		"the classic ship's startingWeapon (ProgressionManager.ts:138, TiltGame.ts:1965)"
	)
```

In `test_audio_call_sites.gd`, `test_a_new_run_starts_the_music_when_it_is_on` and `test_a_new_run_stays_silent_when_music_is_off` each add `rc.finish_cinematic(BOUNDS)` after `rc.reset_run(BOUNDS)`. Their assertions stay the same, and their citation strings stay `TiltGame.ts:170-172 (M6 R7)`. Add one test:

```gdscript
func test_reset_run_alone_starts_no_music() -> void:
	var rc: RunController = _run_controller()
	rc.options.settings.music_enabled = true
	rc.reset_run(BOUNDS)
	assert_true(_spy.lifecycle.is_empty(), "music waits for the cinematic's end (TiltGame.ts:168-172)")
```

In `test_main_scene.gd`, change `_boot_into_run` so that it finishes the cold open, since every existing caller tests a playing run:

```gdscript
## Boots the scene and starts a run from the menu, as Play does (TiltMenu.ts:238-241),
## then skips the cold open (M11b) so the run is PLAYING.
func _boot_into_run() -> GameRoot:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	return root
```

Tests that call `root.launch_run(...)` directly (lines ~545, 557, 604, 619, 642, 698) or `restart_run` and then expect `PLAYING`, the music or the starting orb need a `root.skip_cinematic()` after that call. Add one line, with the comment `# M11b: the cold open ends before the run plays`. Do not weaken any assertion. `test_space_enter_and_r_restart_after_death` (≈:659) must now assert `CINEMATIC` after the key and then `PLAYING` after `skip_cinematic()`. Update its citation to `TiltGame.ts:1311-1316, :1523-1530`.

Then add these tests:

```gdscript
func test_play_opens_the_cold_open_and_hands_over_to_the_run() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	watch_signals(GameEvents)
	root.launch_run(Types.GameMode.CLASSIC)
	var cold_open: EntranceCinematic = root.find_child("ColdOpen", true, false) as EntranceCinematic
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "TiltGame.ts:1526")
	assert_true(cold_open.visible)
	assert_signal_emitted_with_parameters(GameEvents, "phase_changed", [Types.GamePhase.CINEMATIC])
	assert_eq(root._weapons.orbs.size(), 0, "nothing in the arena yet (:60-61)")
	for i: int in range(40):
		root._physics_process(1.0 / 60.0)
	assert_eq(root._state.phase, Types.GamePhase.PLAYING, "onFinish (:169)")
	assert_false(cold_open.visible)
	assert_eq(root._swarm.enemies.size(), 8, "the Classic handover (:204)")
	assert_eq(root._weapons.orbs.size(), 2, "the nuke (:212) + the starting orb (:176)")


func test_music_starts_once_at_the_handover() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.options.settings.music_enabled = true
	root.launch_run(Types.GameMode.CLASSIC)
	assert_false(root._audio._music_player.playing, "not during the cold open (:168-172)")
	root.skip_cinematic()
	root.skip_cinematic()
	assert_true(root._audio._music_player.playing, "TiltGame.ts:170-172")
	assert_eq(root._weapons.orbs.size(), 2, "Review Focus 1: one handover, one starting orb")


func test_space_enter_and_escape_skip_the_cold_open_and_escape_does_not_pause() -> void:
	for keycode: Key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
		add_child_autofree(root)
		await get_tree().process_frame
		root.launch_run(Types.GameMode.CLASSIC)
		var key: InputEventKey = InputEventKey.new()
		key.keycode = keycode
		key.pressed = true
		root._unhandled_input(key)
		assert_eq(root._state.phase, Types.GamePhase.PLAYING, "TiltGame.ts:1302-1309 (%d)" % keycode)
		assert_false(root.is_paused(), "Review Focus 4: the skip returns before p/Escape")


func test_a_tap_on_the_cold_open_skips_it() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	root.launch_run(Types.GameMode.CLASSIC)
	var cold_open: EntranceCinematic = root.find_child("ColdOpen", true, false) as EntranceCinematic
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	cold_open._gui_input(touch)
	assert_eq(root._state.phase, Types.GamePhase.PLAYING, "TiltEntranceCinematic.ts:96-102")


func test_restart_inside_the_run_over_delay_keeps_the_sheet_shut() -> void:
	var root: GameRoot = await _boot_into_run()
	root._run_controller.lose_life()
	assert_eq(root._state.phase, Types.GamePhase.GAME_OVER)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root._unhandled_input(key)
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "TiltGame.ts:1315")
	var timer: Timer = root._hud._run_over_timer
	assert_true(timer.is_stopped(), "R9: resetRun hides the modals (:1612-1613)")
	var sheet: Control = root.find_child("GameOverPanel", true, false) as Control
	assert_false(sheet.visible, "Review Focus 3")


func test_retry_replays_the_cold_open_with_a_fresh_arena() -> void:
	var root: GameRoot = await _boot_into_run()
	root._swarm.spawn_seeker(root._bounds, 10.0, 10.0)
	root.restart_run()
	assert_eq(root._state.phase, Types.GamePhase.CINEMATIC, "TiltGame.ts:1519-1521 (R10)")
	assert_eq(root._swarm.enemies.size(), 0, "the cold open clears the arena (:60)")
	root.skip_cinematic()
	assert_eq(root._swarm.enemies.size(), 8, "Review Focus 5: only the new handover")
	assert_eq(root._weapons.orbs.size(), 2)
```

The existing `test_a_launched_run_starts_the_music_when_it_is_on` (≈:539) asserts `bank._music_player.playing` right after `launch_run`. Add `root.skip_cinematic()` before that assertion and change its message to `"the cinematic's handover starts it (TiltGame.ts:170-172, M11b R6)"`. If the headless `AudioStreamPlayer` never reports `playing` (the existing test compares it to `music_enabled`, so it does), use `SpyAudioBank`-style lifecycle checks instead and record that in the ledger.

- [ ] **Step 2: Run them to verify they fail.** `tools/run_tests.sh`: the new tests fail. `skip_cinematic`, `finish_cinematic` and `ColdOpen` do not exist yet, so expect a parse drop of `test_main_scene.gd` and `test_run_controller.gd`. Confirm each with `--check-only`.

- [ ] **Step 3: `RunController`.** In `reset_run`, delete lines 125-132 (the M6 R7 stand-in comment, the `TODO(M11b)`, the music block and `spawn_starting_weapon_orb(bounds)`). Add after `reset_run`:

```gdscript
## The run half of the cinematic's onFinish: music, then the starting orb, which
## lands after both resetRun and the cinematic's arena reset (M11b R6, M6 R7).
## PORT: web/src/tilt-to-live/TiltGame.ts:170-176
func finish_cinematic(arena_bounds: Vector2) -> void:
	if options.settings.music_enabled:
		audio.start_music()
	spawn_starting_weapon_orb(arena_bounds)
```

- [ ] **Step 4: `GameStateMachine`.** Replace `start_cinematic`'s body after `reset_run(mode)` (the PORT-NOTE and the `TODO(M11b)`, lines 108-112) with:

```gdscript
	phase = Types.GamePhase.CINEMATIC  # PORT: web/src/tilt-to-live/TiltGame.ts:1526
	# PORT-NOTE: cinematic.start (:1527-1529) is GameRoot's (_begin_cinematic) —
	# this machine holds no UI and the cinematic is a Control (M11b R5).
```

In `return_to_menu`, replace `# TODO(M11b): cinematic.skip (:1504-1506).` with `# PORT-NOTE: cinematic.skip (:1504-1506) is GameRoot's (return_to_menu, M11b R5, R8).` In `stop`, replace `# TODO(M11b): skip the cinematic.` with `# PORT-NOTE: cinematic.skip (:1538-1540) is GameRoot's (M11b R5); stop() has no caller in the port.` Before you write that last clause, run `grep -rn "_state.stop()\|\.stop()" godot/src/core` and confirm it. If there is a caller, write `GameRoot.<caller> skips it` and make that caller call `_cinematic.skip(_bounds.x, _bounds.y)` after `_state.stop()`.

- [ ] **Step 5: `main.tscn`.** Change `load_steps=13` to `load_steps=14`. Add `[ext_resource type="Script" path="res://src/ui/entrance_cinematic.gd" id="14"]` after id `13`. Between the `GoalsHud` node block and the `Armory` node, add:

```
[node name="ColdOpen" type="Control" parent="CanvasLayer"]
unique_name_in_owner = true
visible = false
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("14")
```

(`mouse_filter` stays at its default, STOP. The script also sets it in `_ready`.)

- [ ] **Step 6: `GameRoot`.**

Add `@onready var _cinematic: EntranceCinematic = %ColdOpen` after `_calibrate_screen`.

In `_ready`, after the Calibrate wiring and before `GameEvents.run_ended.connect`:

```gdscript
	# PORT: web/src/tilt-to-live/TiltGame.ts:160-178 (new TiltEntranceCinematic, its onFinish)
	_cinematic.bind(_audio, _player, _swarm, _grid, _particles, _weapons, _on_cinematic_finished)
	_cinematic.skip_requested.connect(skip_cinematic)
```

In `_unhandled_input`, inside `if armory_key.pressed and not armory_key.echo:`, before the `is_restart_key` block:

```gdscript
			# PORT: web/src/tilt-to-live/TiltGame.ts:1302-1309 — before the restart and
			# pause keys, so Escape skips and never pauses (M11b R7).
			if _state.phase == Types.GamePhase.CINEMATIC and (
				armory_key.keycode == KEY_SPACE
				or armory_key.keycode == KEY_ENTER
				or armory_key.keycode == KEY_KP_ENTER
				or armory_key.keycode == KEY_ESCAPE
			):
				skip_cinematic()
				return
```

and change `restart_run()  # TODO(M11b): startCinematic (:1313).` to `restart_run()  # startCinematic (:1315, M11b R10)`.

In `_physics_process`, the `CINEMATIC` arm becomes:

```gdscript
		Types.GamePhase.CINEMATIC:
			# PORT: web/src/tilt-to-live/TiltGame.ts:1831-1836 — the raw dt (M11b R11).
			_grid.update(delta)
			_particles.update(delta)
			_cinematic.update(delta, _bounds.x, _bounds.y)
```

Replace `launch_run`'s tail. Keep `options.set_mode`, `_state.launch_run`, `set_menu_mode(false)`, `hide_menu` and the I-1 PORT-NOTE. Then:

```gdscript
	_bind_run_layers()
	_begin_cinematic()
```

(The old `_joystick.reset()`, `_run_controller.reset_run(_bounds)`, `_state.mode = …`, `_apply_game_mode()`, the `TODO(M11b)` and the `phase_changed(PLAYING)` emit all move into `_begin_cinematic`.)

Replace `restart_run`:

```gdscript
## restart → startCinematic: a fresh run behind a fresh cold open (M11b R10).
## PORT: web/src/tilt-to-live/TiltGame.ts:1519-1530
func restart_run() -> void:
	_tilt.calibrate_current_position()
	_state.restart()
	_goals_hud.set_menu_mode(false)  # PORT: web/src/tilt-to-live/TiltGame.ts:1524
	_begin_cinematic()


## startCinematic's run half: the sim reset and the cold open (M11b R5).
## PORT: web/src/tilt-to-live/TiltGame.ts:1525-1529
func _begin_cinematic() -> void:
	_joystick.reset()
	_run_controller.reset_run(_bounds)
	# PORT-NOTE(M10 final review F-2): the machine's mode follows the run's
	# captured mode (R4), so _state.restart() never passes a stale mode.
	_state.mode = _run_controller.mode
	_apply_game_mode()
	_cinematic.start(_bounds.x, _bounds.y, _state.mode)
	GameEvents.phase_changed.emit(Types.GamePhase.CINEMATIC)


## The TS cinematic's onFinish, GameRoot's half (M11b R6).
## PORT: web/src/tilt-to-live/TiltGame.ts:168-177
func _on_cinematic_finished() -> void:
	_state.phase = Types.GamePhase.PLAYING  # PORT: web/src/tilt-to-live/TiltGame.ts:169
	_run_controller.finish_cinematic(_bounds)
	GameEvents.phase_changed.emit(Types.GamePhase.PLAYING)


## cinematic.skip from a tap or Space/Enter/Escape; a no-op outside the cold open.
## PORT: web/src/tilt-to-live/TiltGame.ts:1302-1309, TiltEntranceCinematic.ts:96-102
# PORT-NOTE: the .tilt-cinematic-skip listener (:1349-1356) has no element in
# web/index.html, and the canvas pointerdown (:1358-1364) sits under the
# full-screen overlay whose tap stands for it (M11b R7).
func skip_cinematic() -> void:
	if _state.phase != Types.GamePhase.CINEMATIC:
		return
	_cinematic.skip(_bounds.x, _bounds.y)
```

In `return_to_menu`, right after `_state.return_to_menu()`:

```gdscript
	# PORT: web/src/tilt-to-live/TiltGame.ts:1504-1506 — after the phase flip, as written.
	# PORT-NOTE: were a cold open playing, its onFinish would set PLAYING (:169) under
	# the menu. No path reaches this: the opaque overlay covers Pause and Run over,
	# return_to_menu's only callers (M11b R8) — preserved deliberately.
	_cinematic.skip(_bounds.x, _bounds.y)
```

In `resize_canvas`, after `_calibrate_screen.set_ui_scale(...)`, add `_cinematic.set_ui_scale(ui_scale)`.

- [ ] **Step 7: `HudController._on_phase_changed` (R9).** Replace `if phase != Types.GamePhase.PLAYING and not in_menu:` with:

```gdscript
	# PORT: web/src/tilt-to-live/TiltGame.ts:1612-1613 — resetRun hides both modals
	# before startCinematic sets 'cinematic' (:1525-1526), so CINEMATIC hides them too (M11b R9).
	if phase != Types.GamePhase.PLAYING and phase != Types.GamePhase.CINEMATIC and not in_menu:
```

- [ ] **Step 8: `EnemySwarm`.** Replace `## TODO(M11b): the cinematic's handover calls this (TiltEntranceCinematic.ts:196, :200); M10 R3.` with `## Called by the cinematic's handover (TiltEntranceCinematic.ts:196, :200; EntranceCinematic._finish, M10 R3).`

- [ ] **Step 9: Run the tests.** `tools/run_tests.sh` → `OK: 54/54 scripts`, **+9 tests** (630: state machine +1, run controller +1, audio call sites +1, main scene +6). Then run `gdformat --check`, `gdlint` and `grep -rn "TODO(M11b)" godot/src godot/tests` (expect nothing). Then `"$GODOT" --headless --path godot --quit-after 240 2>&1 | grep -c "SCRIPT ERROR"` (expect 0) and `git checkout godot/project.godot`.

- [ ] **Step 10: Commit.**

```bash
git checkout godot/project.godot
git add godot/src godot/tests godot/scenes/main.tscn docs/superpowers/plans/2026-09-20-m11b-entrance-cinematic.md
git commit -m "M11b: runs open on the cold open and hand over its armada; next: Task 3"
```

---

### Task 3: Exit — VERIFY-ME, docs, verification, review

**Files:**
- Modify: `godot/VERIFY-ME.md` (append), `godot/PORT-PROGRESS.md`, `godot/HANDOFF.md`, `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md`

- [ ] **Step 1: Greps.**

```bash
grep -rn "TODO(M11b)" godot/src godot/tests      # expect: nothing
grep -rn "TODO(M11c)" godot/src | wc -l          # expect: the M11a count + 1 (the ship glow, R3); record it
grep -rn "DIVERGENCE" godot/src/ | wc -l         # record (234 + this module's ColdOpen board tags)
```

- [ ] **Step 2: Append `## M11b — Entrance cinematic` to `godot/VERIFY-ME.md`,** in the file's checkbox style (A55, landscape):
  1. Play → the cold open: void, a soft blue glow, the ship glyph, "PERIL POINT", and a thin bar near the bottom that fills in about 0.6 s. Then the run. Note any title clipping at the A55 size.
  2. A tap anywhere skips it at once. Nothing is drawn behind it (no HUD, no Pause button reachable).
  3. The warp-in sound plays as it opens. With Music on, the loop starts only as the run begins, not during the cold open.
  4. Classic: the run opens with 8 seekers in a ring, a nuke orb above the ship, the ship's starting orb, and a shield bubble for about 2.5 s. Judge whether this start is fair on a phone (R12).
  5. Code Red: a 24-seeker ring, a vortex left and a nuke right. Gauntlet: 8 seekers from the edges and a nuke.
  6. Retry, Pause → Restart and PLAY AGAIN each replay the cold open. The previous run's enemies are gone.
  7. A held finger during the skip tap does not steer the ship or leave the joystick drawn when the run starts (Touch scheme).
  8. The ship glyph has no glow yet (`TODO(M11c)`, R3). Judge whether it reads well enough flat.
  9. Android back during the cold open: record what happens (M11a Q3, Open question 1 here).

- [ ] **Step 3: Docs.**
  - `PORT-PROGRESS.md`: in the M11b row, change `plan  not yet written` to the plan path, and mark it **code complete — device pass pending**, with the date and "exit: the commit carrying this text", plus the verification line from Step 4.
  - Index plan module map: point row `11b` at this plan.
  - `HANDOFF.md`: add an M11b `## State` paragraph at the top, and add `## M11b — what landed` (file table, rulings R1–R12 one line each, execution rulings) and `## Open questions (M11b)`. Rewrite `## Next`: **plan M11c**. Its first step is literally: read spec §4.5 and §8 Module 11, `godot/VERIFY-ME.md` in full, every `TODO(M11c)`, `export_presets.cfg` and `HANDOFF.md`'s toolchain section; write `docs/superpowers/plans/2026-09-20-m11c-export-and-device-pass.md`; commit it and stop for review. Update `## How to verify right now` with Step 4's fresh numbers. Carry the M6 notes (mid-play mute, music re-bake) forward into Next.

- [ ] **Step 4: Verify fresh and read every output.**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
tools/run_tests.sh                              # expect: OK: 54/54 scripts (630 tests)
gdformat --check godot/src godot/tests          # expect: 98 files would be left unchanged
gdlint godot/src godot/tests                    # expect: Success: no problems found
grep -rn "TODO(M11b)" godot/src godot/tests     # expect: nothing
grep -rniE "ff4757" godot/src/ui/               # expect: nothing (rule 01)
grep -rn "DIVERGENCE" godot/src/ | wc -l        # record
"$GODOT" --headless --path godot --quit-after 240 2>&1 | grep -c "SCRIPT ERROR"   # expect: 0
git checkout godot/project.godot
git status --short                              # expect: only this task's doc changes
```

If the A55 is on `adb`, export the debug APK as in `HANDOFF.md`'s toolchain section, install it, and run VERIFY-ME §M11b (and §M11a, which has never been run) with the user. Otherwise, leave both unticked.

- [ ] **Step 5: Final review, then commit and stop.** Dispatch one fresh reviewer (the most capable model) over `git diff <plan-commit>..HEAD`, with this plan, `TiltEntranceCinematic.ts` and `ColdOpen.dc.html` as context. Fix every Critical and Important finding, re-run Step 4, and record deferred Minors under Open questions. Then:

```bash
git checkout godot/project.godot
git add godot/VERIFY-ME.md godot/PORT-PROGRESS.md godot/HANDOFF.md docs/superpowers/plans/2026-09-20-m11b-entrance-cinematic.md docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md
git commit -m "M11b done: next read godot/HANDOFF.md + VERIFY-ME.md, then plan M11c"
```

**Stop. Report to the user. Do not begin M11c** (CONVENTIONS §9 step 5).

---

## Execution rulings

(Filled during execution: any ruling taken while running a task, one line each, with the task number.)

## Open questions

1. **R8's unreachable quirk.** The TS `returnToMenu` and `stop` call `cinematic.skip` after leaving the cinematic phase. A playing cold open would then spawn its armada and set `PLAYING` under the menu. Nothing reaches this today, so it is ported as written. If M11a's Q3 ruling makes Android back call `return_to_menu`, the back handler must be a no-op during `CINEMATIC`, or this needs its own ruling.
2. **R1, the layout authority.** The board's sizes are used, not the TS DOM's (72 px ship, a clamp(48–76) title, a 200 px bar at bottom 120). This follows the M8.5 precedent. The user can overrule it at review.
3. **R10, the replay cost.** Every Retry now costs 0.6 s of cold open (a tap skips it), as in the TS. The device pass judges this (VERIFY-ME §M11b check 6).
