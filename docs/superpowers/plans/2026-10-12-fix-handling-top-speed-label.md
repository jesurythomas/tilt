# fix/handling-top-speed-label — the Handling "Turn rate" slider sets top speed

Branch `fix/handling-top-speed-label` (from `main` at `0c46195`). Report pasted by the user
(2026-10-12): Armory → Handling's "Turn rate" slider ("Higher turns sharper.") changes how fast
the ship moves, not how sharply it turns. The public guide (perilpoint.newzenith.ph/how-to-play)
names the slider; the user updates it once this lands.

## Findings (verified in code)

- The slider writes `tuning.sensitivity` (`armory_ui.gd`, `_render_handling_tab`).
- Phones (tilt, and touch through the same GYRO branch, `game_root.gd`): `player_ship.gd`
  `effective_speed = max_speed * clamped_mag * effective_sensitivity`, so 0.5×–2.0× top speed.
- Desktop mouse: top speed unchanged; full speed is reached closer to the cursor
  (`effective_reach = maxf(40, 160 / sensitivity)`). Keyboard: no effect.
- Turning: `angle += diff * minf(1.0, dt * 16.0 * _ship_turn_rate)` reads only the ship's own
  turn rate. The slider never touches it.
- Inherited from the TS: `ArmoryUI.ts:815-818` has the same label and hint, and
  `PlayerShip.ts:131`/`:171` the same maths. The Handling preview (`ArmoryUI.ts:1078`) also scaled
  its turn by sensitivity, so the preview turned sharper while the real ship did not.

## Ruling HANDLING R1 (user, 2026-10-12: "Rename it")

Copy only; the feel and the saved value's meaning do not change.
- Slider: **Top speed**, hint "Higher moves faster." Node names (`TurnSlider`, `TurnValue`) kept.
- Settings link: "Speed & sensitivity: Armory › Handling".
- The Handling preview turns at the ship's base rate, as the game does (no `* sensitivity`).
- Rejected: making the slider change turning (a gameplay change that would alter every saved
  value's meaning and fix phone top speed at 1.0×); leaving it as is.

## Tasks

1. [x] RED: `test_the_speed_slider_says_what_it_does` (armory), `test_the_speed_setting_does_not_change_turning`
   (preview), the ArmoryLink text in `test_tilt_menu.gd`: all three failed on the old code.
2. [x] Rename and preview fix; the three files pass.
3. [x] `README.md` and `VERIFY-ME.md` copy; new `VERIFY-ME.md` §HANDLING R1.
4. [x] Full suite: `OK: 67/67 scripts collected, all tests passed, nothing leaked` (854 tests);
   `gdformat --check` 120 unchanged; `gdlint` clean; headless boot 0 SCRIPT ERROR. A windowed
   shot of the Handling tab at 2340x1080: "Top speed" / "Higher moves faster." on one line each.
5. [x] Merged into `main` by its PR (user: "commit push create PR - merge"). Left to the user:
   the public guide, the A55 pass `VERIFY-ME.md` §HANDLING R1.

## Offered, not ruled

The ship's turn rate (Ships tab, 0.45×–1.60×) and Top speed never overlap in code
(`run_controller.gd` passes both to `player.update`). The Handling preview turns at 1.0× for every
ship; it could read `progression.get_equipped_ship().turn_rate`, a one-line change plus a test.
