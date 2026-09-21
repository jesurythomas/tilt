# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

Last completed module: **M7 — Persistence and economy**, code-complete
2026-09-21 (head `dba9126`; this exit pass adds `ae4a364`).
Code-complete, **device pass pending** (none ticked in `PORT-PROGRESS.md`):
**M2.5 — Mobile feel** (head `37f9fd4` + the user's tuning `c023e09`),
**M3 — Enemy roster** (head `5bb5cc9`), **M4 — Weapons** (head `0b7fccf`),
**M7 — Persistence and economy** (head `dba9126`).
Nothing since M2 has run on a phone: the A55 dropped off adb on 2026-09-20 and
did not return; the user then ran their own pass and committed tuning as
`c023e09` (gyro feel + FPS under mass explosions). It was **still absent from
adb on 2026-09-21** during M7.
Also landed after M4: **HUD score feedback** (`9cc3e8f..31bf2ce`, spec
`docs/superpowers/specs/2026-09-21-hud-score-feedback-design.md`) — kill-site
callouts removed; the score pulses in a multiplier-tier colour instead.
Next module: **M8 (Armory UI + cosmetics)** — plan written 2026-09-22, not
started; see `## Next` at the end of this file.
Branch: `feat/godot-port` (no upstream; nothing pushed).

> ### ⚠ Read `godot/VERIFY-ME.md`
> Every check that needs a hand on the phone or a decision from the user is
> collected there, per module. M2.5's constants are all provisional until its
> section is run. M3, M4 and M7 each append their own section; **M7's four
> device checks (starting orb, coins, save restart, corrupt-save fallback,
> calibration/scheme persistence, frame time) are unrun.**

## How to verify right now

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

tools/run_tests.sh                        # expect: OK: 40/40 scripts (301 tests, 3876 asserts)
gdformat --check godot/src godot/tests    # expect: 70 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "DIVERGENCE" godot/src/ | wc -l  # expect: 69
"$GODOT" --headless --path godot --quit-after 120   # expect: exit 0, no SCRIPT ERROR
git checkout godot/project.godot          # headless runs strip one default-valued line; never commit that
```

Every command above was run fresh at `ae4a364` (M7 head `dba9126` + this exit
pass's one-line citation fix) and passed. `grep -rn "TODO(M3)\|TODO(M4)\|TODO(M7)" godot/src/` is empty.

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

## Process lessons carried forward (M7 addition)

- **Implementers stopping to ask found three more plan defects this module**
  (`JSON.parse_string` logging on parse failure, `trait` being a reserved
  word, `Variant` not narrowing for call arguments) — **eleven such defects
  across five modules now.** Treat a failing brief-specified test as evidence
  the brief may be wrong, and say so rather than working around it silently.
- The final review overturned a controller ruling (a file-wide gdlint
  disable) by actually checking whether gdtoolkit supports region-scoped
  disables instead of accepting the claim. Reviewers verify tool claims.

## Next: execute the M8 plan (written 2026-09-22)

The user chose **M8 (Armory UI)** on 2026-09-22 and ruled that M8 **also
makes purchased cosmetics visible in the run** (the three `TODO(M8)` render
sites: six ship hulls, enemy-skin colour arms, arena-theme override).
The plan is written: `docs/superpowers/plans/2026-09-20-m8-armory-ui.md`
(11 tasks; `.superpowers/sdd/` ledger not yet created — Task 1 creates
`.superpowers/sdd/2026-09-20-m8-armory-ui/progress.md`).

**Literal first step:** read the plan's header, Global Constraints and File
Structure, then execute Task 1 with `superpowers:subagent-driven-development`
(fresh subagent per task, two-stage review, commit per task). Every task
states its expected `tools/run_tests.sh` count.

Facts the plan established that the executor must not re-derive:
- `Image.load_svg_from_string` exists in 4.7.2 and rasterises the TS's own
  SVG strings (verified 2026-09-22: the blackhole icon at 2× → 60×60, centre
  pixel `#A78BFA`). Icons and ship previews use it; `getShipSvgPreview`
  (`ProgressionManager.ts:873-939`) is therefore ported (Task 3), reversing
  half of M7 OQ 1. `getCursorSvgDataUri` stays unported.
- `ArmoryUI`, `HandlingPreview`, `ArmoryTheme` clash with no engine class.
- **In the live web run the enemy skin and arena theme are always passed**
  (`TiltGame.ts:2310-2312`), so M3/M1 ported the menu-backdrop arms: wiring
  the classic skin/theme changes the run's look (hazard dots lose their
  orange; pulsar ring/stroke `#ff8899`; perimeter alpha 0.45→0.4, grid
  0.28→0.18). LAW 2: port exactly; plan Open question 5 + VERIFY-ME §M8.
- The Armory opens from **pause** and **game over** only; the HUD's own
  button (`TiltGame.ts:1453`) is deferred to M11 (plan OQ 2).
- Mobile chrome (edge-to-edge panel inset by `arena_origin`, back button,
  sticky Play) is gated on `OS.has_feature("mobile")` — the module's one
  `DIVERGENCE(spec §8 M8)`; expect the count to go 69 → 70.

M5 (audio) stays open with M2 as its only dependency; its first step is
unchanged: read spec §8 Module 5 and `web/src/tilt-to-live/TiltAudio.ts`
in full, then write `docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md`.

Before Task 1: `git status --short` must be clean under `godot/` (the user
may leave device tuning uncommitted — never stash or revert it), and read
`godot/VERIFY-ME.md` for the outstanding M2.5/M3/M4/M7 device checks.
