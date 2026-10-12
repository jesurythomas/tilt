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

## Tasks

- [x] Failing tests (`test_main_scene.gd`): boot keeps the saved calibration; Retry and choosing
      tilt do not re-arm. 3 failed before the fix.
- [x] Fix in `game_root.gd`. 857 tests green, gdformat and gdlint clean.
- [ ] A55 pass (`VERIFY-ME.md` §BUG-101). `calibrate_gyro`'s forced poll reads the real sensor and
      is not reachable headless.

## Open (not part of this fix)

User, same session: a 0:11 clip (`WhatsApp Video 2026-10-11 at 20.56.05.mp4`) where the ship
"can't go to the right" at any tilt. Not viewed: no video decoder on this machine. Possibly the
same cause (a bad pose captured at Play). Re-test on the BUG-101 build before investigating.
