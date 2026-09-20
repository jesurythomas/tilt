# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

Last completed module: **M2 — Vertical slice** (2026-09-20).
**M2.5 — Mobile feel** — *code complete 2026-09-21, head `37f9fd4`*.
**M3 — Enemy roster** — *code complete 2026-09-21, head `5bb5cc9`*.
Neither is ticked in `PORT-PROGRESS.md`: their device passes have not been
run. The A55 dropped off adb mid-session on 2026-09-20 and never came back, so
**nothing from M2.5 onward has run on a phone.**
Next module: **M4 — Weapons** (deps: M2 — may start before the device passes).
Branch: `feat/godot-port` (no upstream; nothing pushed).

> ### ⚠ Read `godot/VERIFY-ME.md`
> Every check that needs a hand on the phone or a decision from the user is
> collected there, per module. M2.5's constants are all provisional until its
> section is run. M3 appends its own section.

## How to verify right now

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

tools/run_tests.sh                        # expect: OK: 30/30 scripts (184 tests)
gdformat --check godot/src godot/tests    # expect: 56 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "DIVERGENCE" godot/src/ | wc -l  # expect: 35
"$GODOT" --headless --path godot --quit-after 120   # expect: exit 0, no SCRIPT ERROR
git checkout godot/project.godot          # headless runs strip one default-valued line; never commit that
```

Every command above was run fresh at `5bb5cc9` and passed. `grep -rn "TODO(M3)" godot/src/` is empty.

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

## Next: M4 — Weapons

Scope per spec §8 M4: the six remaining weapons in `src/sim/weapon_system.gd`
(M2 ported `nuke` + orb spawning), `WEAPON_TUNING` parity spec via
`tools/parity/`, perk-rank effects on radius/duration. Deps: M2 only.
First step: write `docs/superpowers/plans/2026-09-20-m4-weapons.md` from
`web/src/tilt-to-live/WeaponSystem.ts` (923 lines) and `WeaponTuning.ts` (87
lines), read in full, following the M3 plan's form. `freeze_all` in
`enemy_swarm.gd` is waiting for its M4 caller (`WeaponSystem.ts:542-543`
freezes inline — decide whether to route through it; either way cite it).
