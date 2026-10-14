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


## Ruling BUG-101 R4 (user 2026-10-13: "make tilt every run on the pause menu toggle-able, toggled on -> keep on every run -> toggle off -> recalibrates when play /resume is pressed")

Branch `feat/pause-keep-tilt-level` (PR #11), stacked on `fix/haptics-media-vibration` (PR #10)
so the version codes stay in order.
- Pause sheet: switch **Keep tilt level** (`KeepTiltSwitch`) under Music, shown with the
  calibrate icon (tilt only). On = All runs, off = Each start; it mirrors the saved level.
- Each start now also levels on **Resume** (`GameRoot.toggle_pause` back to PLAYING), unsaved,
  as Play and Retry do.
- My call: switching to All runs (Pause or Settings) **keeps the level in use**
  (`TiltInput.keep_current_level`), so turning it on mid-run never jumps to an older level. This
  replaces R2's `restore_saved_calibration`.
- `GameRoot.set_tilt_level` is the one writer; `game_root.gd` now disables gdlint's
  max-file-lines, as `tilt_menu.gd` and `armory_ui.gd` do.

## Ruling BUG-101 R5 (user 2026-10-14: "theres a drift now during the tilt calibration ... i usually just press play and when on the game screen not expect it to move until i tilt. now, it tilts at around 10-11")

Built on `feat/dash-and-abilities` (the branch in hand; nothing in it touched tilt). Seen on the
A55 (screenshot 12:2x): a run paused at 0:02, Keep tilt level **on**, so Play and Resume kept a
saved level and did not re-level. Every level was one gravity reading: Each start's at the run's
first tick (0.6 s after the tap on Play), Pause's crosshair and Armory's Calibrate tilt at the
tap itself, Set level at its release. A hand moving as the thumb leaves the button gives an
off-level neutral, and the ship drifts away from it: up and left here, as in the 2026-10-11
clip. Keep tilt level then keeps that skewed level for every run. My calls:
- **Every level is taken from a still phone** (`TiltInput.settle_level`): after it is asked
  for, the samples must stay within `SETTLE_STILL_DEGREES` 1.0° of their mean for
  `SETTLE_WINDOW_SECONDS` 0.25 s; the level is that mean. Samples from before the request are
  left out (the tap's push). After `SETTLE_MAX_SECONDS` 1.5 s it takes the stillest window seen.
  The steering reads zero while it settles.
- **Each start** (Play, Retry, Resume) settles, unsaved. GameRoot reads the sensor through the
  0.6 s cold open (`_physics_phase` polls while a level settles, in any phase), so a steady hand
  is level before the run's first tick; Resume (no cold open) holds the ship until still.
- **Pause's crosshair and Armory's Calibrate tilt** settle after the tap, saved, and switch to
  All runs (R2). R1's "captured when the button is pressed" becomes "once the hand settles after
  the press"; the run's first poll still never takes it (the sensor is read in Pause and the menu).
- **The Calibrate screen's Set level** levels at once to the mean of the samples its live dot
  read over 0.3 s before the finger came down (`button_down`, `TiltInput.level_to_recent`); with
  fewer than 3 it settles instead.
- One log line a level: "tilt: level settled in X s; the first reading was Y deg off it", so the
  A55's logcat shows how far the old single reading would have been.
- The user's own setting is left alone: Keep tilt level stays on. Its saved level is the old
  skewed one until the user levels again or turns it off (told in chat).
- Cost: TiltInput keeps 1.5-3 s of recent samples (pruned in batches); a run tick's
  `apply_gravity` 0.84 → 1.08 µs on desktop; a settling tick ≤ 3 µs; the landing call ~0.1-0.3 ms
  with its log line, once per run start.
- **Review fix (2026-10-14, one review run over the repo):** a level still settling when the
  sensor stopped (Quit to menu right after Resume or the Pause crosshair) stayed armed with its
  old start time, so the next sample, maybe minutes later, was past SETTLE_MAX_SECONDS with one
  reading in the window and became the level alone; a crosshair level was saved that way. Now
  `TiltInput.start_listening` restarts a settling level's wait. Test
  `test_a_settle_cut_off_by_a_stopped_sensor_waits_again`.

## Tasks

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
      0 SCRIPT ERROR headless. 0.1.8 (code 9) on the A55 2026-10-13 14:39
      (`build/peril-point-0.1.8-a55.apk`). Next A55 build uses code 10.
- [x] User: "once all green - commit - push - PR - merge". Merged into `main` by its PR.
- [x] R4: 876 tests green (Pause fits with the new row on the board frame and the A55),
      gdformat and gdlint clean, 0 SCRIPT ERROR headless. 0.1.10 (code 11) on the A55
      2026-10-13 14:55 (`build/peril-point-0.1.10-a55.apk`). Next A55 build uses code 12.
- [x] User: "merge them all -- they all pass". PR #10 then PR #11 merged into `main`.
- [x] R5: still-phone levels. 1026 tests green (+9: seven in `test_tilt_input_device.gd`, two
      in `test_main_scene.gd`; two Each start tests now hold the phone still), gdformat and
      gdlint clean, 0 SCRIPT ERROR headless. A55 pass: `VERIFY-ME.md` §BUG-101 R5.
- [x] R5 review fix: a settle cut off by a stopped sensor waits again (2026-10-14, on
      `review/copilot-pr-12-15`, PR #17). Suite 1037/1037.
- [x] A55 pass by the user (`VERIFY-ME.md` §BUG-101) on 0.1.10: "they are working now". `calibrate_gyro`'s forced poll
      reads the real sensor and is not reachable headless.

## Open (not part of this fix)

User, same session: a 0:11 clip (`WhatsApp Video 2026-10-11 at 20.56.05.mp4`) where the ship
"can't go to the right" at any tilt. Viewed (ffmpeg contact sheet, 1 fps): a fresh launch
(splash) straight into Survival on Tilt with no calibration step, the path where the boot
calibration was taken at the first run poll. The ship drifts up and left and reaches the left
edge; it does move right once, along the bottom (~0:07-0:08). Consistent with an off-level pose
captured at Play, not a dead right axis. Re-test on the BUG-101 build (VERIFY-ME §BUG-101).
