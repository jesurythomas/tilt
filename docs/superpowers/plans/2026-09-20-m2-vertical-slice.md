# Module 2 — Vertical Slice: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the first complete playable loop of Peril Point on device: spawn, fly, dodge, collect a nuke orb, detonate the nuke, score with multipliers and combo callouts, die upon collision, see the game over summary, and restart into a fresh run — holding solid 60 fps with 100 seekers active on a physical Samsung Galaxy A55.

**Architecture:** 
- `core/game_events.gd`: Autoload event bus for sim→UI signals (`score_changed`, `enemy_killed`, `weapon_activated`, `life_lost`, `run_ended`, `phase_changed`).
- `audio/audio_bank.gd`: Silent null-object stub containing all 28 methods from `TiltAudio.ts`, logging at DEBUG level.
- `sim/particle_engine.gd`: Completed port of remaining emitters (`emit_explosion`, `emit_smoke`, `emit_ice_shatter`, `emit_blizzard_snow`, `emit_kinetic_ice_shards`, `emit_thruster_sparks`).
- `sim/score_manager.gd`: Port of `ScoreManager.ts` (scoring, multiplier building, combo timer & callouts, floating texts, best score persistence).
- `sim/enemy_swarm.gd`: Port of `EnemySwarm.ts` limited to Seeker subtype, flocking separation, and basic wave director.
- `sim/weapon_system.gd`: Port of `WeaponSystem.ts` limited to orb spawning and nuke detonation.
- `render/render_context.gd` & `render/effect_layer.gd`: `RenderContext` parameter object (spec §5.6), `EffectLayer` for particles and floating text, expanded `EntityLayer` for seekers, orbs, and nuke shockwaves.
- `sim/run_controller.gd`: Absorbs `check_collisions`, `handle_enemy_killed`, `lose_life`, `trigger_player_death`, `spawn_starting_weapon_orb`, and steps 1–3, 5–6, 8–9, 11 of frame order (spec §5.4).
- `ui/hud_controller.gd` & HUD in `main.tscn`: Responsive in-game HUD (score, best, multiplier, lives) and Game Over modal with Restart button.
- `core/game_root.gd` & `core/game_state_machine.gd`: Main scene and state integration, wired to `RunController` and responsive UI.

**Tech Stack:** Godot 4.7.2-stable (GDScript, non-.NET) · GUT 9.6.1 via `tools/run_tests.sh` · gdtoolkit 4.5.0 · adb for device verification (`SM_A556E`).

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` (§8 Module 2, §4.2, §4.3, §4.4, §4.5, §5.1, §5.3, §5.4, §5.5, §5.6, §6.3)

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
- **Godot path:** `GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"` (console variant).
- **adb path:** `ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"`, and **always pass `-s RRCXB04L8EJ`**.
- **Orientation:** landscape. Target: Android only through M10 (iOS deferred to M11, D1).
- **`content_scale_mode = disabled`.** Viewport size is direct pixel size. All UI controls use anchors and containers.
- **`max_fps = 60`** rendering, **`physics_ticks_per_second = 120`** (spec D8).
- **`arenaScale = clamp(min(width, height) / 680, 0.60, 1.15)`** verbatim.
- **`GAME_SPEED = 0.75`** (`web/src/tilt-to-live/TiltGame.ts:35`).
- **Static typing is mandatory and machine-enforced.** Nine warnings at Error.
- **No sim system may be an autoload or singleton** (spec §5.2). Only `Log` and `GameEvents` are autoloaded.
- **Signals are sim→UI and sim→audio only. Never sim→sim** (spec §5.3).
- **Frame order is fixed** (spec §5.4). M2 implements steps 1, 2, 3, 5, 6, 8, 9, 11.
- **Tests:** run via `tools/run_tests.sh`.
- **Lint/format:** `gdlint godot/src godot/tests` and `gdformat --check godot/src godot/tests` must pass cleanly.
- **Commits:** one line, imperative, ≤72 chars, no trailers, prefixed `M2:`.

---

## Tasks

### Task 1: `core/game_events.gd` Autoload & Unit Test
- **Files:**
  - `godot/src/core/game_events.gd`
  - `godot/tests/test_game_events.gd`
  - `godot/project.godot` (add `GameEvents="*res://src/core/game_events.gd"` under `[autoload]`)
- **Details:**
  - `extends Node` without `class_name` (per CONVENTIONS §2 and Ruling in M1: autoload identifiers must not have `class_name` to prevent singleton shadowing).
  - Declare signals per spec §5.3:
    - `signal score_changed(score: int, multiplier: int, best_score: int)`
    - `signal enemy_killed(enemy: Types.Enemy, weapon_type: Types.WeaponType)`
    - `signal weapon_activated(weapon_type: Types.WeaponType)`
    - `signal life_lost(lives_remaining: int)`
    - `signal run_ended(final_score: int, stats: Types.GameStats)`
    - `signal goal_completed(goal_id: String)`
    - `signal points_changed(total_points: int)`
    - `signal phase_changed(new_phase: Types.GamePhase)`
- **Verification:**
  - Headless test: `test_signals_exist_and_emit` in `test_game_events.gd`.

---

### Task 2: `audio/audio_bank.gd` Silent Null-Object Stub
- **Files:**
  - `godot/src/audio/audio_bank.gd`
  - `godot/tests/test_audio_bank.gd`
- **Details:**
  - Class `class_name AudioBank extends RefCounted`.
  - Stub all 28 public methods from `web/src/tilt-to-live/TiltAudio.ts`:
    - `unlock()`, `toggle_mute() -> bool`, `set_muted(muted: bool)`, `set_sfx_volume(vol: float)`, `set_music_volume(vol: float)`, `is_muted() -> bool`, `start_music()`, `stop_music()`
    - `play_orb_pickup()`, `play_coin_pickup()`, `play_nuke()`, `play_missile_launch()`, `play_missile_explode()`, `play_laser_beam()`, `play_lightning()`, `play_freeze()`, `play_ice_shatter()`, `play_siren()`, `play_ice_cascade()`, `play_gauntlet_klaxon()`, `play_vortex()`, `play_dot_pop(combo_index: int = 0)`, `play_milestone()`, `play_player_death()`, `play_close_call()`, `play_space_invader_step(step: int)`, `play_warp_in()`, `play_invasion_alarm()`
  - Every method calls `Log.debug("AudioBank.<method>")` and returns cleanly.
- **Verification:**
  - Unit test in `test_audio_bank.gd` verifying all methods callable without throwing.

---

### Task 3: Complete `sim/particle_engine.gd` Emitters
- **Files:**
  - `godot/src/sim/particle_engine.gd`
  - `godot/tests/test_particle_engine.gd`
- **Details:**
  - Port remaining emitters from `ParticleEngine.ts:69-197`:
    - `emit_explosion(x: float, y: float, color: Color = Color("#ff3344"), count: int = 32)`: calls `emit_sparks(x, y, count, color, 300.0)` and adds expanding shockwave ring (`size: 8.0`, `life: 0.35`, `friction: 1.0`).
    - `emit_smoke(x: float, y: float, color: Color = Color(200.0/255.0, 210.0/255.0, 225.0/255.0, 0.4))`
    - `emit_ice_shatter(x: float, y: float, count: int = 18)`: shards with random speed 60..280, colors `#88eeff` / `#ffffff`.
    - `emit_blizzard_snow(bounds: Vector2, count: int = 2)`: falling snow motes.
    - `emit_kinetic_ice_shards(x: float, y: float, count: int = 8)`: radial kinetic shards.
    - `emit_thruster_sparks(x: float, y: float, angle: float, color: Color = Color("#ff5500"))`: rocket exhaust sparks.
- **Verification:**
  - Extend `test_particle_engine.gd` testing `emit_explosion`, `emit_smoke`, `emit_ice_shatter`, `emit_kinetic_ice_shards`, `emit_thruster_sparks`.

---

### Task 4: `sim/score_manager.gd` Full Port
- **Files:**
  - `godot/src/sim/score_manager.gd`
  - `godot/tests/test_score_manager.gd`
- **Details:**
  - Ports `web/src/tilt-to-live/ScoreManager.ts` (207 lines) in full:
    - `stats: Types.GameStats` (holds score, best_score, multiplier, max_multiplier, kills, survival_time, best_combo, close_calls).
    - `floating_texts: Array[Types.FloatingText]`
    - `mode_multiplier: float = 1.0`, `progression_multiplier: float = 1.0`
    - `combo_count: int = 0`, `combo_timer: float = 0.0`, `is_new_best: bool = false`, `best_score_diff: int = 0`
    - `update(dt: float, game_mode: Types.GameMode = Types.GameMode.CLASSIC)`: advances survival time, decays combo timer (clearing combo count at <= 0), updates floating text positions and alphas, removing expired texts.
    - `register_kill(x: float, y: float, weapon_type: Types.WeaponType, audio: AudioBank)`: increments kills, advances combo count, resets combo timer to 1.6s, increments multiplier every 8 combo kills up to 50x, adds points (`10 * multiplier * mode_multiplier * progression_multiplier`), triggers musical combo notes and milestone floating text callouts (`TRIPLE!`, `MULTI KILL!`, `MEGA KILL!`, `UNBELIEVABLE!`, `HOLY CRAP!`).
    - `register_close_call(x: float, y: float, audio: AudioBank)`: adds close call bonus (`250 * multiplier * mode_multiplier * progression_multiplier`), adds floating text.
    - `add_floating_text(text: String, x: float, y: float, color: Color, size: float = 18.0)`
    - `finalize_game()` & `load_best_score()`: loads/saves best score via `user://tilt_to_live_best.json` (`# TODO(M7): route through SaveStore`).
- **Verification:**
  - Tests in `test_score_manager.gd`: reset, kill scoring, combo multiplier progression, combo window decay, close call bonuses, floating text lifecycle, best score loading/saving.

---

### Task 5: `sim/enemy_swarm.gd` (Seeker Subtype + Separation + Director)
- **Files:**
  - `godot/src/sim/enemy_swarm.gd`
  - `godot/tests/test_enemy_swarm.gd`
- **Details:**
  - Ports `web/src/tilt-to-live/EnemySwarm.ts` limited to Seeker + flocking separation + basic wave director:
    - `enemies: Array[Types.Enemy]`
    - `scale: float = 1.0`, `speed_scale: float = 1.0`
    - `reset()`, `set_scale(scale)`, `set_speed_scale(scale)`
    - `spawn_seeker(bounds: Vector2, custom_x: float = NAN, custom_y: float = NAN) -> Types.Enemy`: spawns Seeker at random edge (margin 20) or custom pos, `radius = 8.5 * scale`, `health = 1`.
    - `update(dt: float, player_pos: Vector2, bounds: Vector2, particles: ParticleEngine, current_score: int = 0, game_mode: Types.GameMode = Types.GameMode.CLASSIC)`:
      - Continuous Seeker spawning: `spawn_timer` counts down; interval decays with elapsed time and score down to 0.42s; spawns 1 (or 2 above 12k score) seekers.
      - Individual physics: calls `update_seeker(e, player_pos, dt, current_score, is_code_red)`: calculates direction to player, target speed (`105 + elapsed * 0.5 + score_bonus`, capped at 195, scaled by `max(0.72, scale)`), steers velocity with `steer_strength = 3.2 * dt`, integrates pos with `speed_scale`. Clamps inside arena bounds with bounce.
      - `apply_flocking_separation()`: O(N^2) pairwise separation pushing dots apart if closer than `min_distance = 16.0` (`EnemySwarm.ts:510-540`).
    - `on_enemy_killed(enemy: Types.Enemy, particles: ParticleEngine)`: emits kill sparks / burst.
- **Verification:**
  - Tests in `test_enemy_swarm.gd`: seeker spawning, movement towards player position, arena clamping, flocking separation distance between two overlapping seekers, speed scaling.

---

### Task 6: `sim/weapon_system.gd` (Orb Spawning + Nuke Detonation)
- **Files:**
  - `godot/src/sim/weapon_system.gd`
  - `godot/tests/test_weapon_system.gd`
- **Details:**
  - Ports `web/src/tilt-to-live/WeaponSystem.ts` limited to orb spawning and nuke detonation:
    - `orbs: Array[Types.WeaponOrb]`, `active_weapons: Array[Types.ActiveWeapon]`
    - `scale: float = 1.0`
    - `reset()`, `set_scale(scale)`
    - `spawn_orb(bounds: Vector2, specific_type: Types.WeaponType = Types.WeaponType.NUKE, custom_x: float = NAN, custom_y: float = NAN)`: pad = `max(30.0, 60.0 * scale)`, `radius = 16.0 * scale`, `lifetime = 12.0`.
    - `activate_weapon(type, x, y, player, enemies, particles, grid, audio, on_enemy_killed)`:
      - For `WeaponType.NUKE`: plays nuke audio (`audio.play_nuke()`), reads `max_radius = Tuning.get_tuned_value("nuke", "radius", 0) * scale` (260.0 * scale), duration = 0.65s, creates `ActiveWeapon` of type NUKE.
    - `update(dt, player, enemies, bounds, particles, grid, audio, on_enemy_killed)`:
      - Orb spawn timer counts down (spawns orb if `orbs.size() < 5`, timer = 3.0 + randf() * 1.5).
      - Updates orbs: lifetime decay, player collision (`dist < player.radius + orb.radius`) -> calls `activate_weapon`, plays orb pickup audio, emits sparks, removes orb.
      - Updates active weapons: for `NUKE`: expands blast radius (`progress = 1 - duration / max_duration`, `radius = max_radius * progress`), vaporizes enemies inside `radius + enemy.radius + 15`, calls `on_enemy_killed(e, WeaponType.NUKE)`, emits explosion particles (`#ff3366`, 16), distorts grid with `grid.apply_explosion(w.x, w.y, 16.0, w.radius + 30.0)`. Removes expired active weapons.
    - `get_weapon_color(type: Types.WeaponType) -> Color`: NUKE = `#ff0055`, etc.
- **Verification:**
  - Tests in `test_weapon_system.gd`: orb spawning, orb collection on player proximity, nuke expansion, enemy kill detection in radius, grid explosion application.

---

### Task 7: Render Layers (`RenderContext`, `EffectLayer`, `EntityLayer` Expansion)
- **Files:**
  - `godot/src/render/render_context.gd`
  - `godot/src/render/effect_layer.gd`
  - `godot/src/render/entity_layer.gd`
- **Details:**
  - `RenderContext` (`class_name RenderContext extends RefCounted`): packs per-frame render parameters per spec §5.6.
  - `EffectLayer` (`class_name EffectLayer extends Node2D`):
    - `bind(particles: ParticleEngine, scores: ScoreManager)`
    - `_draw()`:
      - Renders particles: rings (`draw_arc`), streaks (`draw_line`), shards (`draw_rect`), circles (`draw_circle`) with life-based alpha fade.
      - Renders floating score texts: `draw_string` with shadow offset (+2, +2) and alpha fade.
  - Expand `EntityLayer` (`Node2D`):
    - `bind_entities(player: PlayerShip, swarm: EnemySwarm, weapons: WeaponSystem)`
    - `_draw()` draws in order (spec §5.5, `TiltRenderer.ts:134-144`):
      1. Weapon Orbs: outer glow circle, translucent gradient bubble, white neon perimeter, nuke radioactive trefoil glyph (`renderOrbGlyph`).
      2. Active Nuke Shockwave: multiple concentric expanding rings (`Color(1.0, 0.0, 85/255, alpha * 0.9)`, width `6 * alpha`), inner core fill (`Color(1.0, 30/255, 80/255, alpha * 0.25)`).
      3. Red Dot Enemies: outer halo stroke, outer glow fill, core radial body gradient (`#ff6677` -> `#ee1133` -> `#990011`), border `#ff8899`, dark core pupil circle at `0.38 * radius`.
      4. Player ship (existing M1 implementation).
- **Verification:**
  - Check-only syntax checks and headless GUT tests loading the render scripts.

---

### Task 8: `sim/run_controller.gd`
- **Files:**
  - `godot/src/sim/run_controller.gd`
  - `godot/tests/test_run_controller.gd`
- **Details:**
  - Absorbs `TiltGame.ts:1855-2083`:
    - Owns / references `player`, `swarm`, `weapons`, `particles`, `grid`, `scores`, `audio`.
    - `lives: int = 1`, `max_lives: int = 1`
    - `reset_run(bounds: Vector2)`: resets player, swarm, weapons, particles, scores, grid, sets lives = 1, calls `spawn_starting_weapon_orb()`.
    - `update(dt: float, effective_mode: Types.ControlMode, mouse_pos: Vector2, move_vector: Vector2, tilt_vector: Vector2)`:
      - Executes fixed frame order steps (spec §5.4):
        1. `grid.update(dt)`
        2. `particles.update(dt)`
        3. `player.update(dt, ...)`
        5. `swarm.update(dt, player_pos, bounds, particles, score)`
        6. `weapons.update(dt, player, swarm.enemies, bounds, particles, grid, audio, handle_enemy_killed)`
        8. `scores.update(dt)`
        9. `check_collisions()`
        11. Emit HUD signals (`GameEvents.score_changed.emit(score, multiplier, best_score)`)
    - `check_collisions()`: iterates enemies in reverse:
      - if `dist < player.radius + e.radius`:
        - if player has shield: kills enemy (`handle_enemy_killed(e, SHIELD)`), emits shield sparks.
        - if enemy frozen: kills enemy (`handle_enemy_killed(e, FREEZE)`), emits ice shatter.
        - else: calls `lose_life()`.
      - if `dist < player.radius + e.radius + 16.0` and `player.close_call_timer <= 0.0`:
        - sets `close_call_timer = 0.75s`, calls `scores.register_close_call(player.x, player.y, audio)`.
    - `handle_enemy_killed(enemy, weapon_type)`: calls `scores.register_kill`, applies grid explosion (`4.5, 60.0`), calls `swarm.on_enemy_killed`, emits `GameEvents.enemy_killed`.
    - `lose_life()`: decrements lives. If lives > 0: activates player shield (3.0s), plays siren audio, emits explosion, applies grid explosion (`14.0, 220.0`), emits `GameEvents.life_lost`. If lives <= 0: calls `trigger_player_death()`.
    - `trigger_player_death()`: sets `player.is_dead = true`, plays death audio, emits double death explosion (white 50 sparks, blue 30 sparks), applies grid shockwave (`22.0, 380.0`), finalizes scores, emits `GameEvents.run_ended` and `GameEvents.phase_changed(GAME_OVER)`.
    - `spawn_starting_weapon_orb()`: spawns starting NUKE orb at random angle offset by `dist = min(w, h) * 0.28` from center.
- **Verification:**
  - Tests in `test_run_controller.gd`: full simulation tick, collision kill with shield, death upon dot collision, starting orb spawn position, close-call triggering.

---

### Task 9: `ui/hud_controller.gd` & Minimal In-Game HUD
- **Files:**
  - `godot/src/ui/hud_controller.gd`
  - `godot/scenes/main.tscn` (add `CanvasLayer` containing HUD and Game Over overlay)
- **Details:**
  - `HudController` (`class_name HudController extends Control`):
    - Subscribes to `GameEvents` signals in `_ready()`:
      - `score_changed(score, multiplier, best)`: updates `ScoreLabel` (`score`), `BestLabel` (`BEST <best>`), `MultiplierLabel` (`<mult>x`).
      - `life_lost(lives)`: updates lives pips.
      - `run_ended(final_score, stats)`: populates Game Over panel (`FinalScoreLabel`, `KillsLabel`, `TimeLabel`, `NewBestBanner` if `is_new_best`) and makes GameOver overlay visible.
      - `phase_changed(phase)`: hides GameOver on `PLAYING`.
    - Restart Button `pressed` signal: invokes `game_root.restart_run()`.
  - All UI elements positioned with anchors (top-left, top-right, center) for resolution independence (`content_scale_mode = disabled`).
- **Verification:**
  - GUT test or check-only verification of HUD signals and scene node resolution.

---

### Task 10: `core/game_root.gd` & `core/game_state_machine.gd` Integration
- **Files:**
  - `godot/src/core/game_root.gd`
  - `godot/src/core/game_state_machine.gd`
  - `godot/scenes/main.tscn`
- **Details:**
  - Update `GameStateMachine`:
    - Add `reset_run()` integration resetting `RunController`.
    - Handle `GAME_OVER` phase.
    - Provide `restart()` calling `reset_run()`.
  - Update `GameRoot`:
    - Instantiate `AudioBank`, `EnemySwarm`, `WeaponSystem`, `ScoreManager`, `RunController`.
    - Bind layers: `%GridLayer`, `%EntityLayer`, `%EffectLayer`.
    - In `_physics_process`: when `phase == PLAYING`, call `_run_controller.update(dt, ...)`.
    - In `_process`: redraw `%GridLayer`, `%EntityLayer`, `%EffectLayer`.
    - Support restart flow seamlessly.
- **Verification:**
  - Run `tools/run_tests.sh` to ensure all 11 existing test suites pass + new M2 tests pass.

---

### Task 11: Device Acceptance Pass on Samsung Galaxy A55 (`SM_A556E`)
- **Action:**
  - Build Android debug APK: `"$GODOT" --headless --path godot --export-debug "Android" build/peril-point-debug.apk`.
  - Install and launch on Galaxy A55: `"$ADB" -s RRCXB04L8EJ install -r godot/build/peril-point-debug.apk` & monkey launcher.
  - Verify complete vertical slice loop on hardware:
    1. Ship spawns centered with a starting Nuke orb reachable nearby.
    2. Seekers spawn continuously from edges and track the ship.
    3. Flocking separation keeps seekers from collapsing into a single point.
    4. Flying close to seekers triggers close call floating text (+250 * multiplier).
    5. Collecting the nuke orb triggers:
       - Pickup sound & sparks
       - Rapidly expanding blast shockwave
       - Grid explosion displacement
       - Vaporization of seekers in blast radius with spark explosions
       - Score increment, combo counter increment, multiplier badge update, combo callouts (`TRIPLE!`, `MULTI KILL!`).
    6. Steeing into a seeker triggers player death:
       - Death audio & explosion
       - Transition to `GAME_OVER`
       - Game Over overlay appears with final score, kills, survival time, best score.
    7. Tapping Restart immediately restarts the run into a clean state.
  - Performance: Run `dumpsys gfxinfo com.jtg.perilpoint` with 100 seekers on screen:
    - 50th percentile frame time ≤ 16ms (60 FPS cap).
    - GPU frame time ≤ 5ms.
    - Physics substepping smooth at 120 Hz.

---

### Task 12: Exit Protocol (CONVENTIONS §9)
- **Action:**
  1. Headless test suite: `tools/run_tests.sh` passes 100% green.
  2. Linters: `gdformat --check godot/src godot/tests` and `gdlint godot/src godot/tests` pass with zero problems.
  3. Render scripts check: `"$GODOT" --headless --path godot --check-only` on all render scripts.
  4. Tick `godot/PORT-PROGRESS.md` for M2 with date and commit SHA.
  5. Rewrite `godot/HANDOFF.md` per CONVENTIONS §9.4 with full M2 evidence, device metrics, and M3 first step.
  6. Commit handoff and stop at M2 boundary.
