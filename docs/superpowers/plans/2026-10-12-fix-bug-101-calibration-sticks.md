# fix/bug-101-calibration-sticks — a tilt calibration set on the menu holds in the run

Branch `fix/bug-101-calibration-sticks` (from `main` at `d48f8d9`). Report (user, 2026-10-12):
"When calibrated on home, user thinks it is calibrated that way throughout the game. However,
when in game, it recalibrates to the position when play is pressed. Make calibration stick when
set."

## Findings (verified in code)

- `TiltInput.calibrate_current_position()` only arms `_calibration_pending`; the pose is captured
  by the next `poll()`. In the menu nothing polls except the open Calibrate board, so an armed
  capture is taken by the run's first `GameRoot._update` poll: the pose at Play.
- The TS calls `calibrateCurrentPosition` only from its Calibrate buttons (`TiltGame.ts:2334`).
  The port added three more calls, each of which re-armed a capture:
  - `GameRoot._ready` (boot, DIVERGENCE M2.5 §5.3): every launch discarded the saved pose.
  - `GameRoot.restart_run` (Retry): TS `restart()` (`:1519-1521`) never recalibrates.
  - `GameRoot.set_control_scheme(GYRO)` (menu Steer picker).
- Armory → Handling → "Calibrate tilt" (`calibrate_gyro`) armed a capture from the menu with
  nothing polling, so it too was taken at Play. The Calibrate board's Set level already forced a
  poll (M11a final review I-1) and was correct within a session.

## Ruling BUG-101 R1 (user's report: "Make calibration stick when set")

- Remove the boot, Retry and scheme-switch calibrations. A saved pose loads in `TiltInput._init`;
  with none, the first gravity sample becomes neutral (`apply_gravity`'s zero-vector branch).
- `calibrate_gyro` polls right after arming, so the pose is captured when the button is pressed.

## Ruling BUG-101 R2 (user 2026-10-13: "give 2 options, auto-calibrate on start, or calibrate for all runs - rename it")

My calls, made without asking (standing instruction "always proceed"):
- `ControlSettings.tilt_level` (`TiltLevel` AUTO / SAVED, save key `tilt_level`), default **AUTO**.
  Settings → Controls, shown only under Tilt: card **Tilt level**, segments **Each start** /
  **All runs**. Hint: "Levels to how you hold the phone as each run starts" / "Your Calibrate
  level holds for every run".
- AUTO: `GameRoot._begin_cinematic` (Play and Retry) arms `calibrate_current_position(false)`;
  the run's first poll takes the pose and does **not** save it, so the saved level survives.
- SAVED: no run start recalibrates (R1's behaviour).
- Any Set level (Calibrate board, Armory Calibrate tilt, Pause) switches to SAVED and saves it.
  Toast subtitle "Neutral Angle Zeroed ✓" is now "Kept for every run ✓"; the Calibrate board
  reads "That angle becomes still for every run."
- Choosing a level in Settings calls `TiltInput.restore_saved_calibration()` (drops the last
  Auto capture; Auto re-levels at the next run start anyway).
- "Rename it" read as: name the two choices clearly. If it meant renaming "Calibrate", ask.

## Ruling BUG-101 R3 (user 2026-10-13, three asks)

- "remove the calibrate at the home page": the Steer row's calibrate icon (`MenuCalibrateButton`)
  is gone. Calibrate tilt stays in Settings → Controls (under Tilt), Armory → Handling and Pause.
- "the calibrate title screen seems broken. i only see set level but not the button below it":
  `CalibrateScreen`'s left block was anchored `PRESET_CENTER_LEFT` before it had a size, so it
  grew down from the centre and Cancel fell off the A55's screen (the M11c finding at
  `calibrate_screen.gd:175`). It now grows both ways (`GROW_DIRECTION_BOTH`).
- "remove touch stick it selected isnt touch": Settings' Touch stick card shows only while
  Touch steers, on a phone (`TiltMenu.shows_stick_card`).


- [x] Failing tests (`test_main_scene.gd`): boot keeps the saved calibration; Retry and choosing
      tilt do not re-arm. 3 failed before the fix.
- [x] Fix in `game_root.gd`. 857 tests green, gdformat and gdlint clean.
- [x] A55 build: 0.1.6 (code 7), `build/peril-point-0.1.6-a55.apk` (A55 key), installed on the A55
      2026-10-13 12:10 and launched. The next A55 build uses code 8.
- [x] R2: Tilt level setting. 867 tests green, gdformat and gdlint clean, 0 SCRIPT ERROR headless;
      0.1.7 (code 8) on the A55 2026-10-13 14:24 (`build/peril-point-0.1.7-a55.apk`), Settings card
      checked by screenshot. Next A55 build uses code 9. Frame cost: no per-frame code added (one
      branch at run start, one Settings card).
- [x] R3: 869 tests green (the Calibrate fit test failed first), gdformat and gdlint clean,
      0 SCRIPT ERROR headless. 0.1.8 (code 9) built (`build/peril-point-0.1.8-a55.apk`), not
      installed: the user was mid-run. Next A55 build uses code 10.
- [x] User: "once all green - commit - push - PR - merge". Merged into `main` by its PR.
- [ ] A55 pass by the user (`VERIFY-ME.md` §BUG-101) on 0.1.8. `calibrate_gyro`'s forced poll reads the real
      sensor and is not reachable headless. Then PR and merge.

## Open (not part of this fix)

User, same session: a 0:11 clip (`WhatsApp Video 2026-10-11 at 20.56.05.mp4`) where the ship
"can't go to the right" at any tilt. Viewed (ffmpeg contact sheet, 1 fps): a fresh launch
(splash) straight into Survival on Tilt with no calibration step, the path where the boot
calibration was taken at the first run poll. The ship drifts up and left and reaches the left
edge; it does move right once, along the bottom (~0:07-0:08). Consistent with an off-level pose
captured at Play, not a dead right axis. Re-test on the BUG-101 build (VERIFY-ME §BUG-101).
