# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

Last completed module: **M8 — Armory UI (+ cosmetics in the renderer)**,
final-review fix wave landed 2026-09-22 (head is this commit — `git log -1
--format=%H` — a commit cannot cite its own hash inside its own tree).
Code-complete, **device pass pending** (none ticked in `PORT-PROGRESS.md`):
**M2.5 — Mobile feel** (head `37f9fd4` + the user's tuning `c023e09`),
**M3 — Enemy roster** (head `5bb5cc9`), **M4 — Weapons** (head `0b7fccf`),
**M7 — Persistence and economy** (head `dba9126`),
**M8 — Armory UI** (head is this commit, see above).
Nothing since M2 has run on a phone: the A55 dropped off adb on 2026-09-20 and
did not return; the user then ran their own pass and committed tuning as
`c023e09` (gyro feel + FPS under mass explosions). It was still absent from
adb on 2026-09-21 during M7 and **remains absent on 2026-09-22** during M8
(`adb devices` returns an empty list).
Also landed after M4: **HUD score feedback** (`9cc3e8f..31bf2ce`, spec
`docs/superpowers/specs/2026-09-21-hud-score-feedback-design.md`) — kill-site
callouts removed; the score pulses in a multiplier-tier colour instead.
Next module: **M5 (Audio bake + SFX) or M9 (Milestones)** — both open, see
`## Next` at the end of this file.
Branch: `feat/godot-port` (no upstream; nothing pushed).

> ### ⚠ Read `godot/VERIFY-ME.md`
> Every check that needs a hand on the phone or a decision from the user is
> collected there, per module. M2.5's constants are all provisional until its
> section is run. M3, M4, M7 and M8 each append their own section; **M7's
> device checks and M8's eleven device checks (below) are unrun.**

## How to verify right now

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

tools/run_tests.sh                        # expect: OK: 42/42 scripts (362 tests, 4289 asserts)
gdformat --check godot/src godot/tests    # expect: 75 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "DIVERGENCE" godot/src/ | wc -l  # expect: 71
"$GODOT" --headless --path godot --quit-after 120   # expect: exit 0, no SCRIPT ERROR
git checkout godot/project.godot          # headless runs strip one default-valued line; never commit that
```

Every command above was run fresh at this commit (2026-09-22, the
final-review fix wave) and passed: `OK: 42/42 scripts collected, all tests
passed` (Tests 362, Passing Tests 362, Asserts 4289 — one test grew by the
final-review fix wave's new spec, `test_armory_root_and_overlay_cover_the_
whole_viewport`); `gdformat --check` reported `75 files would be left
unchanged`; `gdlint` reported `Success: no problems found`; `grep -rn
"DIVERGENCE" godot/src/ | wc -l` printed `71` (one divergence — the
mobile-chrome gate on `OS.has_feature("mobile")` — cited twice in
`armory_ui.gd`, so 70 divergences show as 71 grep hits); the headless run's
`grep -c "SCRIPT ERROR"` printed `0`; `git status --short` was empty before
and after. `grep -rn "TODO(M8)" godot/src/ godot/tests/` is empty; `grep -n
"draw_set_transform(Vector2(" godot/src/render/` is empty. `adb devices`
returns no attached devices.

`--check-only -s` on `src/meta/progression_manager.gd`, `game_options.gd`,
`save_store.gd`, `sim/coin_system.gd` each fail with `Identifier not found:
Log` or `GameEvents` — **expected and inconclusive**: `--check-only` does not
load autoloads, so any file that calls `Log.*` or `GameEvents.*` at class
scope fails this check regardless of correctness. The real compile evidence
is `tools/run_tests.sh` passing: it compiles every script under the project's
nine warnings-as-errors. Don't read a `--check-only` failure on these four
files as a regression.

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

## M4 — what landed

Plan `docs/superpowers/plans/2026-09-20-m4-weapons.md`; ledger
`.superpowers/sdd/2026-09-20-m4-weapons/progress.md` (Rulings 0-13). 8 commits,
`c023e09..0b7fccf`.

| Area | Files |
|---|---|
| Full `WeaponSystem.ts` port minus `render()`/`renderOrbGlyph()` | `src/sim/weapon_system.gd` (738 lines) |
| `WeaponPerks` record only — M7 extends the file in place | `src/meta/progression_manager.gd` |
| `weapon_activated` re-emit, public `perks`, shield-radius perk at run start | `src/sim/run_controller.gd` (frame order untouched — only `weapons.update`'s 9th argument was added) |
| Weapon FX (`_draw_weapon_fx`) + `set_elapsed` | `src/render/effect_layer.gd`; `game_root.gd` binds weapons into it |
| All 7 orb glyphs; nuke rings moved OUT to the effect layer | `src/render/entity_layer.gd` |
| Tests | `tests/test_weapon_missiles.gd`, `test_weapon_lightning_laser.gd`, `test_weapon_vortex_freeze_shield.gd`; additions to `test_weapon_system.gd`, `test_run_controller.gd`, `test_render_layers.gd` |

**Rulings on the plan's eight open questions** (ledger): every `base + rank*k`
duration/count the TS writes inline is read through `Tuning.get_tuned_value`
(spec §8 acceptance outranks LAW 2; numerically identical; percent multipliers
stay inline) · freeze applied inline per `WeaponSystem.ts:541-544`, `freeze_all`
stays callerless · **weapon FX draw above enemies** (spec §5.5) where the web
game draws them under — `VERIFY-ME.md` §M4 asks you to judge; the swap is one
line in `effect_layer.gd::_draw()` · `ActiveWeapon.data` is a Dictionary keyed
by the TS spellings (`crossBeam`, `invulnerableInside`, `gravity`,
`supernovaCollapse`) · `spawn_orb` keeps its NUKE default · `chilled` has no
writer anywhere (asserted to stay false) · `missilesFired += 16` is M9's
(`TODO(M9)` in `run_controller.gd`) · no pre-emptive gdlint suppression (738 lines).

**Perk ranks have no source until M7.** `RunController.perks` is an all-zero
`WeaponPerks` (`# TODO(M7)` at the assignment). Every rank effect is proven
headless in the weapon specs; nothing on the phone changes with rank yet.

**Process defect worth knowing:** the plan mandated a `_p` local and
de-underscored parameters before any arm used them; gdlint rejects both. Ruling
10: parameters lose their `_` only when an arm starts using them. Eighth plan
defect found by an implementer stopping to ask, across three modules.

**Deferred minors:** `WeaponTuning.ts:56` declares `freeze.duration.max = 8.2`
while `base + 5*perRank = 8.0`; `getTunedValue` never reads `max`, and
`tuning.gd:102` reproduces it — M7's Armory (which displays `max`) should note
it. `game_state_machine.gd:121` `TODO(M2): setModeMultiplier` is really M10's;
`:151` `TODO(M2): updateHUD` is done by `GameEvents` signals — both stale.
`weapons.update` gets its 10th argument (active mode) in M8/M10 (`TODO(M8)`).

## M7 — what landed

Plan `docs/superpowers/plans/2026-09-20-m7-persistence-and-economy.md` (11
tasks); ledger `.superpowers/sdd/2026-09-20-m7-persistence-and-economy/`
(rulings summarised below). 14 commits, `66e4ceb..dba9126`, plus this exit
pass's one-line citation fix `ae4a364`.

| Area | Files |
|---|---|
| Shared `user://` read/write/quarantine layer, used by everything below | `src/meta/save_store.gd` |
| Full `ProgressionManager.ts` port minus 2 SVG methods (OQ 1) | `src/meta/progression_manager.gd` (~1,200 lines; `gdlint:disable=max-public-methods,max-file-lines` at line 1; a `max-returns,no-elif-return` disable/enable region around `upgrade_perk` only) |
| Settings save/load, web shape | `src/meta/game_options.gd` |
| Full `CoinSystem.ts` port, coins drawn under orbs | `src/sim/coin_system.gd`, `src/render/entity_layer.gd` (spec §5.5) |
| Run reads lives, hitbox, speed, score/points multipliers, equipped ship's starting weapon from the save at reset | `src/sim/run_controller.gd` |
| Tests | `tests/test_save_store.gd`, `test_progression_*.gd` (records/catalogs/defaults, economy, catalogs), `test_game_options.gd`, `test_coin_system.gd`, `tests/fixtures/progression.json` (~330-literal parity fixture); additions to `test_control_settings.gd`, `test_run_controller.gd` |

**Nine Open questions, each carried verbatim with its ruling taken (all on
the plan's *recommended* reading):**

1. *`getCursorSvgDataUri`/`getShipSvgPreview` are not ported* — `ProgressionManager.ts:802-939`
   return SVG markup with no Godot consumer (Android has no pointer; M8's
   Armory will draw a preview with `_draw` or a texture). **Ruling:** not
   ported; named with line ranges and `TODO(M8)` in the file header; counted
   as the two deliberate omissions in the Task 6 member reconciliation.
2. *`upgradePerk`/`getWeaponInvestedPoints` index perks by string* — CONVENTIONS
   §6 forbids `get("prop")`/`set("prop")`, but the TS's
   `(this.data.perks as any)[weapon][perkName]` is exactly the dictionary view
   the save shape needs. **Ruling:** routed through `WeaponPerks.to_dict()`/
   `from_dict()`, no reflection; `upgrade_perk` takes the TS key spellings
   (`"crossBeam"`) — **M8 calls it the same way.**
3. *Starting orb changes from nuke to shield* — `TiltGame.ts:1965` spawns
   `getEquippedShip().startingWeapon`; the default ship's is `'shield'`.
   **Ruling:** ported; the device pass judges the visible effect (VERIFY-ME
   §M7 item 1) — reverting is a one-line change if the user prefers the nuke.
4. *Retag the render `TODO(M7)`s to `TODO(M8)`* — `entity_layer.gd:13`/`:174`
   and `grid_layer.gd:93` were tagged M7 on the old assumption "M7 = skins";
   spec §8 M7 delivers catalogs only, and nothing can equip alternates until
   M8's Armory exists. **Ruling:** retagged to `TODO(M8)`, each naming the
   catalog getter to read.
5. *`GameOptions.controlScheme` vs. `ControlSettings.scheme`* — two sources of
   truth would be a defect. **Ruling:** `GameOptionsManager` ports
   `controlScheme` for save-shape fidelity only; nothing reads it;
   `ControlSettings` (M2.5) stays the live source; `input_router.gd`'s comment
   is now a `PORT-NOTE` saying exactly that.
6. *Where `points_changed` is emitted* — `GameEvents.points_changed` existed
   with no emitter. **Ruling:** emitted from `add_points_credited` only (the
   one place the TS notifies anything); **M8's Armory reads `data.points`
   directly after its own purchases**, as `ArmoryUI.ts` does.
7. *Saving the mode multiplier on `reset_run`* — `TiltGame.ts:1548` calls
   `options.setMode(mode)` (which saves) before reading the mode config;
   `RunController.reset_run` takes no mode (M10 owns modes). **Ruling:**
   `RunController` reads `options.settings.mode` directly and ports
   `:1549-1551`; `setMode` stays with `GameStateMachine`'s existing M10
   marker. Consequence: a boot does not create `tilt_to_live_settings_v1.json`
   until something calls `set_mode` or `save()`.
8. *`SteeringTuning.deadzone` as float* — TS types it `number` (default `4`);
   both sides parse to the same value either way. **Ruling:** kept float (it
   is compared against a float distance and set from a slider); a
   `PORT-NOTE` records it.
9. *Non-object JSON is quarantined, not merged* — the TS would spread a
   parsed number/array into the defaults and silently produce defaults; spec
   §6.4 wants corrupt saves moved aside. **Ruling:** `SaveStore` treats
   "parses but is not an object" as corrupt — **one step stricter than the
   TS**, on purpose; the evidence is worth more than a silent default.

**Three representation decisions M8 and M9 read directly** (also OQ 2, 6, and
the mode-config signature): **(a)** perks are edited by TS spelling through
`upgrade_perk("laser", "crossBeam")`, and the keystone key doubles as the
`Tuning.KEYSTONE_COSTS` key; **(b)** every `get_*_cost()` returns
`Types.ABSENT` for the TS `null`; **(c)** `GameOptionsManager.get_mode_config(mode)`
takes the mode explicitly rather than reading it internally.

**Other facts M8/M9 need:** `RunController.perks` no longer exists — ranks
live on `progression.data.perks`. The starting orb is the equipped ship's
weapon (shield for the default/classic ship, OQ 3). `# TODO(M8)` tags:
`entity_layer.gd` (six ship hull shapes, enemy skin colours),
`grid_layer.gd` (arena theme override) — retagged per OQ 4. `# TODO(M10)` at
the two `options.settings.mode` reads in `run_controller.gd` (one now cites
`TiltGame.ts:1547` for `reset_run`'s own read, `:1931` for `update()`'s) and
the weapons `update()` call's tenth argument. `# TODO(M11)` for the
game-over coin summary (`coins.coins_collected`, `coins.points_from_coins`).
`# TODO(M9)` for `missilesFired` (carried from M4).

**Member reconciliation (Task 6):** `ProgressionManager.ts` has 40 real
methods — 38 ported, 2 deliberately not (OQ 1). GDScript has 46 funcs = 38 +
`_init` + 7 GDScript-only helpers (`_unique_union`, `_find_ship`/
`_find_enemy_skin`/`_find_arena_theme`, `_build_ship_catalog`/
`_build_enemy_skin_catalog`/`_build_arena_theme_catalog`).

**Rulings taken during execution, beyond the plan's nine (found by
implementers stopping to ask — three more plan defects, see Process
lessons):**
- `SaveStore.load_dict` uses `JSON.new().parse()`, not `JSON.parse_string` —
  the latter logs an engine error that GUT counts as a test failure even when
  the caller handles the parse error correctly.
- `ShipSkinConfig.trait` renamed `trait_text` — `trait` is a Godot 4.7
  reserved word; the save/fixture JSON key stays `"trait"`.
- An `is`-narrowed `Variant` does not narrow for call arguments — bind a
  typed local first.
- `# gdlint:ignore=` covers only the next line; a body-level exemption
  (`upgrade_perk`'s `max-returns`/`no-elif-return`) needs a `disable`/`enable`
  region instead. The final review overturned the controller's original
  ruling (a file-wide lint disable) by verifying gdtoolkit actually supports
  region-scoped disables — **reviewers should verify tool claims, not accept
  them.**
- The pre-existing `test_malformed_json_falls_back_to_defaults` spec was
  rewritten to assert quarantine (it previously asserted silent-merge
  behaviour that OQ 9's ruling supersedes).

**Device evidence:** headless `--quit-after 120` clean (0 SCRIPT ERROR) at
`fc19300`; debug APK exports 30,431,782 bytes. **A55 absent from `adb` on
2026-09-21** — no install, launch, or on-device check happened. `VERIFY-ME.md`
§M7 (appended at `64c6f67`) has five device checks unrun: starting-orb colour,
coin appearance/fade/pickup/draw-order, save-survives-restart, corrupt-save
fallback-and-backup, and frame time with six coins + a vortex live.
`PORT-PROGRESS.md`'s M7 box stays **unticked**, `DEVICE PASS PENDING`, same as
M2.5/M3/M4.

**Accepted gaps (deferred minors from reviews):** coin-draw spec is
smoke-only (same class as M2.5's render smoke tests); `gdformat` wraps
`SaveStore.save_dict` calls into parenthesised dot-chains; two catalog
description strings under 100 chars got parenthesised by `gdformat`;
always-free id literals are duplicated between `load_data` and
`_get_default_data`, as the TS duplicates them; catalog-spec reason strings
cite bare `:NNN` line numbers; `showGridlines` relies on its `= false`
default to match the TS's `=== true` check; `update()` re-looks-up
`get_mode_config` every frame, as the TS does; `player_ship.gd` got a
comment-only edit even though the plan's file table said "not modified".

## M8 — what landed

Plan `docs/superpowers/plans/2026-09-20-m8-armory-ui.md` (11 tasks); ledger
`.superpowers/sdd/2026-09-20-m8-armory-ui/` (rulings summarised below). 14
commits, `b8567e2..f0cac03`, plus the exit commit `19c4e22`, plus this
final-review fix commit — 16 commits total, `b8567e2..HEAD` (a commit cannot
cite its own hash; `git rev-list --count b8567e2..HEAD` is 15, +1 inclusive
of `b8567e2` itself = 16).

| Area | Files |
|---|---|
| Theme tokens from `game.css`, built at runtime, no `.tres` (OQ 7) | `src/ui/armory_theme.gd` (241 lines) |
| Shell scene: overlay, panel, header, tab row, balance, close, sticky Play footer | `scenes/armory.tscn` |
| Full port of `ArmoryUI.ts` (20 methods/handlers) — five tabs (Weapons, Ships, Arena, Handling, Boosts) | `src/ui/armory_ui.gd` (1833 lines) |
| `getShipSvgPreview` (`ProgressionManager.ts:873-939`) ported for the ship-card hull previews | `src/meta/progression_manager.gd` (Task 3) |
| The handling tab's live steering preview, `initHandlingPreview`/`stopHandlingPreview` as `start`/`stop` | `src/ui/handling_preview.gd` (257 lines) |
| Armory instanced under `CanvasLayer`; `PauseArmoryButton`, `GameOverArmoryButton`; `set_pause_panel_visible` | `scenes/main.tscn`, `src/ui/hud_controller.gd` |
| `open_armory`/`close_armory`/state-changed/closed hooks, `_apply_equipped_cosmetics`, `b`/`u`/Escape keys (`TiltGame.ts:1319-1328`, `:2343-2385`) | `src/core/game_root.gd` |
| `set_ship_skin` + six hull arms (`PlayerShip.ts:359-592`); `set_enemy_skin` + every skin arm (`EnemySwarm.ts:1191-1648`) | `src/render/entity_layer.gd` |
| `set_arena_theme` (`TiltRenderer.ts:76-80`) | `src/render/grid_layer.gd` |
| Tests | `tests/test_armory_ui.gd` (560 lines), `tests/test_handling_preview.gd` (109 lines); additions to `test_progression_catalogs.gd`, `test_main_scene.gd`, `test_render_layers.gd` |
| Device evidence + hand-held checks | `godot/VERIFY-ME.md` §M8 |

**Nine Open questions, each carried verbatim with its ruling taken (eight on
the plan's *recommended* reading; OQ 5 is the port-exactly case the plan
itself calls out — the "recommended" reading and the only correct one, since
LAW 2 forbids silent improvement):**

1. **The mobile layout of the weapons tab.** `game.css:2817-2911` (≤820 CSS
   px) stacks the sidebar above the detail and switches to back-button +
   sticky Play; this plan gates the *chrome* on `OS.has_feature("mobile")`
   but keeps the two-column weapons *layout* even on the 2340 px-wide A55.
   **Ruling:** two columns everywhere; the device pass (VERIFY-ME §M8 item 2)
   judges it. A stacked layout is a layout change, not a port change, if the
   user wants it.
2. **The HUD's own Armory button is not ported.** `TiltGame.ts:1453-1455`
   binds `btn-tilt-armory-hud`, a second in-run open button. **Ruling:**
   pause and game-over entries only; the HUD button goes to M11 with the
   menu's entry (`TODO(M11)` in `game_root.gd`'s key handler comment).
3. **`getShipSvgPreview`'s dead `'celestial'` arm.**
   `ProgressionManager.ts:924-930` switches on ship id `'celestial'`, but the
   celestial-shaped ship's id is `revenant` (`:255-276`) — the arm is
   unreachable in the web game too. **Ruling:** ported as written with a
   `PORT-NOTE` (LAW 2); the Revenant card shows the classic arrow preview,
   same as the web game.
4. **"Hull · N of 6 unlocked" over a seven-ship catalog.** `ArmoryUI.ts:646`
   hard-codes 6; `shipCatalog` has 7 entries. **Ruling:** ported the literal
   (`SHIP_COUNT_LABEL`) with a `PORT-NOTE`; the arena tab's pills use
   `themes.length`/`enemies.length` and are correct as-is.
5. **The classic enemy skin changes what a live run draws.** With the skin
   always passed in a live run (`TiltGame.ts:2311`), porting the gates
   exactly changes the run's look under the default skin: hazard dots lose
   their orange, the pulsar's ring/stroke go `#ff4757`/`#ffa502` →
   `#ff8899`, and the arena perimeter/grid alphas go 0.45/0.28 → 0.4/0.18.
   **Ruling:** port exactly — this **is** what the web game shows in a
   run — both facts are in VERIFY-ME §M8 for the user to accept or override
   on device; a reversion would be a `DIVERGENCE`, not a port fix. This
   stayed the plan's stated position throughout; no ruling changed it.
6. **Where the equipped cosmetics are read.** The TS reads
   `getEquippedShip/EnemySkin/ArenaTheme` on every render call. **Ruling:**
   pushed into the layers on boot and on `ArmoryUI.state_changed`/`closed`
   (`_apply_equipped_cosmetics`), since equipping happens nowhere else and
   the layers must stay dumb (spec §5.2, M11's backdrop needs `null`).
7. **The `Theme` lives in code, not a `.tres`.** A `.tres` cannot carry
   `# PORT:` citations and would duplicate every colour already needed as a
   typed constant. **Ruling:** `ArmoryTheme.build(scale)` returns a `Theme`
   at runtime; the tokens are cited constants; nothing is saved to disk.
8. **Fonts.** `game.css:53-55` specifies Archivo / IBM Plex Sans / IBM Plex
   Mono; no font asset exists in the project. **Ruling:** Godot's default
   font at the cited sizes with a `PORT-NOTE`; M11's export pass (which owns
   icons and splash screens) owns fonts too.
9. **Glow on the handling preview's ship.** `ArmoryUI.ts:1085-1086` sets
   `shadowColor`/`shadowBlur = 14` on the preview silhouette; spec §4.5
   defers every glow to M11's on-device cost measurement. **Ruling:** skipped
   with a `TODO(M11)`, the same ruling M2/M3/M4 applied to in-arena glow.

**Representation decisions later modules read directly:** **(a)**
`GameRoot.open_armory(tab)` takes the TS tab strings (`"perks"`,
`"cursors"`, …), so M9's milestones modal and M11's menu call it the way
`TiltGame.ts:2343` is called. **(b)** `ArmoryUI.state_changed` is the
`handleProgressionChanged` hook — M9's `goalsHUD.render()` and M11's
`menu.render()` connect there (`game_root.gd:373` names both TODOs and the
TS line numbers). **(c)** the layers take cosmetics through
`set_ship_skin`/`set_enemy_skin`/`set_arena_theme` with `null` meaning the
menu-backdrop arm — M11's `MenuBackdrop` passes `null` for all three
(`TiltGame.ts:2274-2276`). **(d)** `HudController.set_pause_panel_visible`
exists for anything else that overlays the pause modal.

**`TODO` tags M8 left** (grepped fresh, see `## How to verify right now`):
`TODO(M5)` — `game_root.gd:275` `audio.stopMusic()` on Armory open
(`TiltGame.ts:2347`); `TODO(M9)` — `game_root.gd:373` `goalsHUD.render()`
(`:2383`); `TODO(M10)` — `grid_layer.gd:92,116` mode colours (code-red/
gauntlet) precede the theme override (`TiltRenderer.ts:64-74`); `TODO(M11)`
— `game_root.gd:147` `p`/Escape pause toggle, `game_root.gd:373`
`menu.render()` (`:2384`), `handling_preview.gd:16` the preview ship's tint
glow (OQ 9), and font assets (OQ 8, no literal tag — noted in
`armory_theme.gd:16`).

**Member reconciliation:** `ArmoryUI.ts` has 20 methods/handlers → all
ported (`initHandlingPreview`/`stopHandlingPreview` as
`HandlingPreview.start`/`stop`). `ProgressionManager.ts` is now **39 of 40**
ported — `getShipSvgPreview` reversed half of M7 OQ 1; `getCursorSvgDataUri`
(`:802-871`, no Android pointer to draw for) is the one remaining omission.

**Rulings taken during execution, beyond the plan's nine Open questions**
(plan defects #12-#22, twenty-two across six modules now; each found by an
implementer stopping to ask or a reviewer checking a claim):
- **#12** (Task 1, implementer): `Theme.has_type_variation` does not exist in
  4.7.2 — both calls became `theme.is_type_variation("TabButton"/"PlayButton",
  "Button")`.
- **#13** (Task 2, implementer): blackhole's `invulnerableInside` keystone is
  absent from `KEYSTONE_COSTS` and priced by the `?? 2500` fallback — the
  test asserts the fallback equals `get_perk_cost`'s result instead of
  requiring dictionary membership.
- **#14** (Task 2, reviewer, while ruling on a separate finding): `PIP_GAP`
  cited `game.css:1943` (`.track-info`'s gap, 3px) instead of
  `.track-pips-bar`'s own `gap: 5px` at `:1974` — fixed to `PIP_GAP = 5`.
- **#15** (Task 3, implementer): `buy_ship` equips on purchase
  (`ProgressionManager.ts:720`, M7 ported it) — the buy-then-equip test was
  wrong to expect a separate "Equip" step.
- **#16** (Task 4, implementer): `buyArenaTheme`/`buyEnemySkin` also equip on
  buy (`:744-753`, `:768-777`) — same class as #15, fixed under the Task 3
  ruling.
- **#17** (Task 4, implementer): `assert_eq(get_signal_emit_count(...))` does
  not compile under Tier-1 strict typing — replaced with GUT's
  `assert_signal_emit_count`.
- **#18** (Task 4, reviewer): the arena border-2 citation `game.css:2535` is
  wrong (that line is `justify-content`) — the 2px border is inline at
  `ArmoryUI.ts:756`.
- **#19** (Task 5, implementer): `cost_getter.call() as int` trips
  `UNSAFE_CAST` under Tier-1 — three sites used scoped
  `@warning_ignore("unsafe_cast")`, which the reviewer then overturned (#see
  process lessons: `is`-narrowing compiles clean).
- **#20** (Task 6, implementer stopped to ask): the brief's legend-as-
  sibling-row diverges from `game.css:2755-2761` (absolute overlay, bottom-
  left inside the preview box) — ported the overlay instead.
- **#21** (Task 7, implementer stopped to ask): the brief's pause→Armory spec
  assumed the pause panel hides; `TiltGame.ts:2343-2347` hides it only on a
  playing→paused transition, and from the pause button the phase is already
  paused — the panel stays visible under the Armory's z-100 overlay, which is
  what the port does (LAW 2).
- **#22** (Task 7, implementer stopped to ask): the brief assumed
  `_state.phase == GAME_OVER` after death; `TiltGame.ts:2073` sets it inside
  `triggerPlayerDeath`, which the port put in the sim
  (`run_controller.gd:266-278`) with nothing on the game side mirroring it —
  a pre-existing M2 gap. `GameRoot` now connects `GameEvents.run_ended` and
  sets `_state.phase = GAME_OVER`, `# PORT: TiltGame.ts:2073`. Consequence:
  the sim stops ticking after death (the death explosion freezes in place),
  matching the web game's own loop, which has no game-over branch.

**Accepted gaps (deferred minors from the ledger):** several `ArmoryTheme`
tokens sat unused between Tasks 1-6, confirmed all used by Task 6's close —
the final review found one that had regressed, `OVERLAY_BG` (read nowhere,
`armory.tscn`'s Overlay duplicated the literal); fixed by wiring
`%Overlay.color = ArmoryTheme.OVERLAY_BG` into `ArmoryUI._ready()`, so the
claim is true again;
`_open_weapons` test helper has no PORT tag (test scaffolding); locked ship
cards keep `COLOR_PANEL` where `game.css:2306/2315` darkens further
(brief-level simplification); `_draw_dashed_circle`'s segment loop is
unbounded by ring size (safe at the preview's constant radius); slider
handlers do `find_child` per change (TS `querySelector` idiom, file-
consistent); `_on_run_ended` has no re-entry guard (the sim's
`is_run_active` guards upstream); static `_quad` duplicates
`_quadratic_points`'s lerp (forced by `hull_points_for` being static, brief-
mandated, lacks its own PORT-NOTE tag); `test_entity_layer_draws_every_
enemy_type_under_every_skin` is smoke-only (OQ 5's gate asymmetry is not
individually asserted); `background_colors()` reallocates per `_draw()`.

**Final-review accepted gaps (2026-09-22, recorded rather than fixed):**
`HandlingPreview` is recreated on every `render()` (`armory_ui.gd::_render_handling_tab`,
PORT-NOTE at the `_preview = HandlingPreview.new()` site), so the TS instance's
`previewShip`/`previewInitialized` (`ArmoryUI.ts:83-94`) reset on tab return
and on a same-tab re-tap, and `HandlingPreview.start()` reads `size` before
first layout (`handling_preview.gd:105-106`) so the initial placement uses
the 280×260 floor for one frame; the fix (reparent the existing preview,
defer placement one frame) is deferred. Test-only getters with no production
reader: `EntityLayer.get_ship_skin`/`get_enemy_skin`,
`GridLayer.get_arena_theme`/`background_texture`, `GameRoot.is_armory_open`.
`armory.tscn`'s footer margins (12/16/20) and header/tab separations
(20/4/16) are not scaled by `ArmoryUI.set_ui_scale`. Every `state_changed`
(including each slider tick) drives `_apply_equipped_cosmetics` →
`set_arena_theme` → a full `_build_background()` rebake in `grid_layer.gd`;
the fix is a guard on id-change. The weapons-tab swatch
(`item.add_child(_swatch(...))`, `armory_ui.gd` weapons sidebar) is a raw
`Panel` child of a `Button`, so it sits at (0,0) over the button's padding
instead of in a flex row beside the label — `VERIFY-ME.md` §M8 has the
device-pass line.

**The `_on_run_ended`/GAME_OVER behaviour change (plan defect #22, above):**
before M8, nothing set `phase = GAME_OVER` on death, so the sim kept ticking
under the death screen. `GameRoot` now mirrors `run_ended`/`phase_changed`
from the sim (spec §5.3's sim→game direction) and the run freezes at the
moment of death, as in the web game. Any later module that assumed the sim
kept running after death must re-read this.

## Process lessons carried forward (M7 addition)

- **Implementers stopping to ask found three more plan defects this module**
  (`JSON.parse_string` logging on parse failure, `trait` being a reserved
  word, `Variant` not narrowing for call arguments) — **eleven such defects
  across five modules now.** Treat a failing brief-specified test as evidence
  the brief may be wrong, and say so rather than working around it silently.
- The final review overturned a controller ruling (a file-wide gdlint
  disable) by actually checking whether gdtoolkit supports region-scoped
  disables instead of accepting the claim. Reviewers verify tool claims.

## Process lessons carried forward (M8 addition)

- **Implementers stopping to ask found five more plan defects this module**
  (#12, #13, #15, #21, #22); **reviewers found five more** (#14, #16, #17,
  #18, #19 — #19 overturned by the reviewer, see below) — **twenty-two such
  defects across six modules now.**
- gdtoolkit 4.5.0: a second `gdlint:disable`/`enable` region for the same
  rule in one file silently breaks — every `enable` clamps every `disable`
  range for that rule project-wide in that file. Restructure the code (e.g.
  single-return) instead of adding a second region.
- `Theme.has_type_variation` does not exist in Godot 4.7.2; use
  `is_type_variation(name, base)`.
- `assert_eq(get_signal_emit_count(...))` does not compile under Tier-1; use
  GUT's `assert_signal_emit_count`.
- `Callable.call() as T` trips `UNSAFE_CAST`; narrow with `var v: Variant =
  cb.call(); if v is T: local = v` (the `tilt_input.gd:353` / `save_store.gd:66`
  pattern) — a reviewer verified this compiles clean under Tier-1, overturning
  an implementer's "no alternative" claim (defect #19). Reviewers verify tool
  and language claims, not just accept them — second module running this
  lesson (M7 did the same for gdlint region scoping).
- `buy_ship`/`buy_arena_theme`/`buy_enemy_skin` all **equip on purchase**
  (`ProgressionManager.ts:720`/`:750`/`:774`) — three brief specs across two
  tasks assumed a separate equip step; check this pattern before writing any
  future buy-flow test.
- `GameRoot` now sets `phase = GAME_OVER` on `run_ended`
  (`TiltGame.ts:2073`); the sim stops ticking after death, as in the web
  game — was a pre-existing M2 divergence, closed here.

## Next

Both **M5** (deps M2) and **M9** (deps M7) are open; spec §8 lists no
priority between them — pick either.

**M5 — literal first step:** read spec §8 Module 5 and
`web/src/tilt-to-live/TiltAudio.ts` in full, then write
`docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md`;
`audio/audio_bank.gd` is the M2 null-object stub every sim system already
calls; `game_root.gd`'s `TODO(M5)` marks `stopMusic` on Armory open.

**M9 — literal first step:** read spec §8 Module 9 and
`web/src/tilt-to-live/GoalManager.ts` + `GoalsHUD.ts` in full, then write
`docs/superpowers/plans/2026-09-20-m9-milestones.md`;
`GameEvents.goal_completed` exists with no emitter; `ArmoryUI.state_changed`
is where `goalsHUD.render()` hooks (`game_root.gd` `TODO(M9)`);
`GameRoot.open_armory("perks")` is how a goal row deep-links into the shop.

Before starting either: `git status --short` must be clean under `godot/`
(the user may leave device tuning uncommitted — never stash or revert it),
and read `godot/VERIFY-ME.md` for the outstanding M2.5/M3/M4/M7/M8 device
checks.
