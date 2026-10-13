# Dash, items (active abilities), and the play-screen rework

Branch `feat/dash-and-abilities` (from `feat/in-game-ads` at `31040da`, which already holds
`staging`). Request (user, 2026-10-14):

> 1. Dash -> Cooldown every 20 seconds, cooldown starts immediately after use and is available
>    at the start of the game. Double tapping the phone quickly triggers dash. It dashes the user
>    1/4 of the screen and makes the player shielded for 2 seconds. Actually cooldown should start
>    after the shield expires. Upgrades include Cooldown reduction -> 15 minimum CD. Upgrade
>    shield by .5 per upgrade to a max of 5 seconds
> 2. Active abilities -> Limits to 1 use per game. Users can purchase an active ability that they
>    can use in the run from the armory. e.g. User purchases a black hole item, when tapped, it
>    triggers the black hole. Doesn't refresh -- only resets during a new run. They can be
>    purchased as a usable item. We need to modify the armory to include a section where you can
>    select your usable items. 2 max.
> 3. Update the play screen. Currently it is hard to see the middle upper center due to the
>    score and multiplier.
> 4. Update the play screen. We need to show the Dash cooldown and clickable items.
> 5. Update the how to to include the new features
>
> Create a new branch for this

None of this is in the TypeScript; every line is new and tagged `DIVERGENCE(DASH Rn)`,
`DIVERGENCE(ITEM Rn)`, `DIVERGENCE(HUD Rn)` or `DIVERGENCE(HTP R3)`. Rulings below are my
calls under the standing "always proceed" (memory, 2026-09-27); the user can overrule any.

Baseline before any change (desktop, `bench/bench_sim.gd` headless, 3 runs): a full run tick
(`tick wall=false carriers=0`) 71-73 µs, late mix 61-62 µs, 30 kills 275-579 µs.

## Ruling DASH R1 — the gesture

- **Double tap anywhere on the playfield**, any finger, any control scheme, only while PLAYING
  (not paused, not in the cinematic, not on the Run over). Android's `GestureDetector` rule,
  in UI units (1 unit ≈ 1 dp; ×ui_scale on screen): the first touch is a *tap* — lifted within
  `TAP_MAX_SECONDS` = 0.3 s, moved at most `TAP_SLOP` = 16 units — and the second touch lands
  within `DOUBLE_TAP_SECONDS` = 0.3 s of that lift (and at least 0.04 s after, Android's
  `DOUBLE_TAP_MIN_TIME`) and within `DOUBLE_TAP_SLOP` = 100 units of the first. The dash fires
  on the second press (no wait for its lift). A steering drag is never a tap, so the stick
  thumb only dashes when it taps twice on purpose; a second finger can double-tap while the
  first holds the stick. Touches on HUD buttons (Pause, the item buttons) never count.
- `src/input/double_tap.gd` (`DoubleTap`, RefCounted) holds the rule; GameRoot feeds it
  `InputEventScreenTouch`/`InputEventScreenDrag` before the joystick sees them.
- **Desktop:** Shift dashes; a real (not touch-emulated) mouse double-click dashes; 1 and 2
  use the item slots.
- A dash requested while it is not ready is dropped (no buffering).

## Ruling DASH R2 — the motion

- **Direction:** the ship's velocity when it is moving (> 20 px/s, PlayerShip's own turning
  threshold), else its facing (`angle`).
- **Distance:** a quarter of the arena *along that direction*: `0.25 · |(w·dx, h·dy)|` for a
  unit direction (dx, dy) — a quarter of the width going sideways, a quarter of the height going
  up or down (the user: "1/4 of the screen").
- **A burst, not a teleport:** `DASH_SECONDS` = 0.12 s at constant speed, so the dash shield rams
  dots on the way. The ship leaves the burst moving at its top speed in the dash direction and
  facing it; steering takes over at once.
- **Walls:** the burst stops at the arena edge (the ship's own padding) and, in Gauntlet, at a
  maze wall: it moves in steps no longer than the ship's radius and stops before a step that
  would overlap a wall (`GauntletMaze.blocks`), so it never tunnels.
- **Feedback:** the warp-in whoosh (`AudioBank.play_warp_in`), a spark streak behind the ship, a
  small grid ripple, a 25 ms haptic pulse (`GameEvents.dash_activated`, Haptics listens).

## Ruling DASH R3 — shield and cooldown

- Ready at the start of every run.
- A dash raises the ship's shield to at least the dash shield time (`activate_shield`, so a
  longer power-up shield is never cut short): 2.0 s base.
- **The cooldown starts when the dash's own shield window ends** (the user's correction), not
  when the ship's shield ends: a Shield orb grabbed during the window does not delay the dash.
  Cooldown 20 s base.
- The dash shield is the ship's shield: it rams dots, blocks a life loss, and the shield
  keystones that act "while shielded" (Battering Ram, Coin Vacuum) apply. Overcharge Pulse
  still arms only on a Shield orb.

## Ruling DASH R4 — dash upgrades

- **Cooldown:** 5 ranks, −1 s each: 20 → 15 s (the user's floor).
- **Shield:** 6 ranks, +0.5 s each: 2.0 → 5.0 s (the user's cap).
- Prices: the weapon-rank ladder (`ProgressionManager.get_perk_cost(rank)`, ECON R2 × ADS R8's
  `UPGRADE_PRICE_SCALE` 4): 1,000 / 1,600 / 2,600 / 4,000 / 6,400 (/ 6,400 for shield rank 6).
- Saved as `dash: {cooldown, shield}` in the progression save.

## Ruling ITEM R1 — items

- **The seven power-ups as items:** Nuke, Missiles, Lightning, Laser, Black hole, Freeze,
  Shield. Bought once (a permanent unlock), equipped into one of **2 slots**, and in every run
  each equipped item fires **once**; it is back at the next run's start.
- **Using one** fires that power-up at the ship exactly as an orb pickup would (the player's
  weapon upgrades and keystones apply; it counts for milestones and the HUD timer), without
  the orb-pickup chime. The request is taken at the next sim tick, before the weapon step.
- Prices (`ITEM_COSTS`, × `PRICE_SCALE` 2 like every other Armory price, ADS R7): Shield 1,200;
  Freeze, Missiles, Lightning 1,500; Laser 1,800; Nuke, Black hole 2,000 (shown 2,400-4,000).
- Saved as `unlockedItems` and `equippedItems` (Armory ids, at most 2, order = slot).

## Ruling ITEM R2 — the Armory

- A sixth tab, **Abilities**, after Boosts: a **Dash** section (the two upgrade rows, the shared
  `_upgrade_card`) and an **Items** section: the two slots ("Slot 1 · Black hole", "Slot 2 ·
  Empty"), then one card per item — icon, name, line, and one action: its price (buy), Equip,
  or Unequip. With both slots full, Equip is disabled and the slots line says to unequip one.
- `open("abilities")` (and the alias `items`) opens it.

## Ruling ITEM R2 addendum — the header

- Six tabs and a large balance overflowed the board's 844-px header; the Armory's tab buttons
  pad 8 px a side instead of the board's 12 (`UiTheme.TAB_BUTTON_PAD_X`). Seen, not ours: the
  weapon list clips "Blackhole" to "Blackho" next to a two-digit rank ("9/15").

## Ruling HUD R1 — the score leaves the top centre

- The score, its multiplier chip and BEST move into the left column at the top-left corner:
  score (Mono 22) with the chip on its right, BEST under it, then the lives and the toasts.
  The top centre of the playfield is clear. Score pulse and tier colours unchanged.

## Ruling HUD R2 — the ability bar

- Bottom corner, inside the arena frame: the **dash gauge** (a ring that refills over the
  cooldown, the shield draining in green while the dash shield is up, the seconds left in the
  middle while cooling, lit when ready; display only — a tap on it passes through and counts
  toward a double tap) and the **item buttons** (48 units, the orb sprite; a used item dims and
  shows a check). Empty slots show nothing.
- Bottom right by default; bottom left when Stick position is Right, so it never sits under an
  anchored stick.
- Redraws only when what it shows changes (the ring's fraction in 1/48 steps, the seconds).

## Ruling HTP R3 — the guide

- A fourth page, **Dash and items**, before The Armory: a Dash card and an Items card with the
  rules above, and a clip recorded from the game (`tools/record_htp_clips.gd`, `HTP_CLIP=dash`):
  a run with the HUD showing dashes and both items firing.
- The Armory page lists the Abilities tab; its clip is re-recorded with the new tab.

## Ruling DASH R5 — the clock

- The dash runs on the game's clock, as every timer does (power-up durations, the HUD's
  SHIELD countdown, survival time): the sim steps at `Tuning.GAME_SPEED` = 0.75
  (TiltGame.ts:35). So the 20 s cooldown and 2 s shield are game seconds, the same unit the
  Armory shows for power-ups ("6.0s"); on a stopwatch they are 26.7 s and 2.7 s. Making them
  wall-clock is one division by GAME_SPEED in `AbilitySystem.reset`, if the user wants it.

## Tasks

1. [x] Save data: dash ranks, item unlocks and loadout, costs, buy/equip (ProgressionManager);
   tests. (`test_progression_abilities.gd`, 10 tests; parity test expects the three new keys.)
2. [x] `AbilitySystem` (dash + item slots) in the run; `GauntletMaze.blocks`; tests.
   (`src/sim/ability_system.gd`, `test_abilities.gd` 17 tests; `GameEvents.dash_activated`,
   Haptics `DASH_MS` 25. Sim bench full tick 68-69 µs vs 70-73 µs before: no cost.)
3. [x] Input: `DoubleTap`, GameRoot wiring (gesture, Shift, double-click, 1/2, item use);
   `GameEvents.dash_activated`, Haptics; tests. (`src/input/double_tap.gd`,
   `GameRoot.request_dash/use_item`, `test_double_tap.gd` 12 tests. Input-only, no per-frame
   cost.)
4. [x] HUD R1 + R2 (`AbilityBar`); screenshot `bench/shot_hud.gd`; tests. (Score block in
   `LeftColumn/ScoreBlock/ScoreRow`; `src/ui/ability_bar.gd`; `test_ability_bar.gd` 8 tests;
   `build/shots/hud_{now,ready,cooldown,left}.png`. Bar update 1.3 µs/frame desktop.)
5. [x] Armory Abilities tab, glyphs (`dash`, `dashCooldown`); screenshot; tests.
   (`_render_abilities_tab`, `test_armory_abilities.gd` 9 tests, `bench/shot_armory.gd`. The
   sixth tab overflowed the header at 844 px by ~5 px with a 4-digit balance: Armory tabs now
   pad 8 a side (`UiTheme.TAB_BUTTON_PAD_X`), and a 1,234,567 balance fits at 844 and the A55.)
6. [x] How to play page + clips; tests. (Page 3 "Dash and items"; `dash.ogv` 12 s 960×540
   Theora q4 1.6 MB, `HTP_CLIP=dash`; `armory.ogv` re-recorded with the Abilities step, 24 s,
   q6 1.9 MB (`ffmpeg -ss 6 -t 24`); dash clip `ffmpeg -ss 8 -t 12 ... -q:v 4`.)
7. [x] Verify: suite, gdformat/gdlint, 0 SCRIPT ERROR headless, benches vs baseline, A55
   build; HANDOFF, VERIFY-ME, PORT-PROGRESS. (1010/1010 tests, 75/75 scripts, nothing
   leaked; clean; 0 SCRIPT ERROR. 0.1.20 code 21 on the A55, data kept; live run 16.66 ms mean,
   p95 25.0. PORT-PROGRESS untouched: no port module closes. VERIFY-ME §DASH / ITEM / HUD /
   HTP R3 lists the device checks.)

## Status

- All 7 tasks done (2026-10-14). Next: the user's A55 pass (VERIFY-ME §DASH / ITEM / HUD /
  HTP R3), then a PR from `feat/dash-and-abilities` to `staging`.
