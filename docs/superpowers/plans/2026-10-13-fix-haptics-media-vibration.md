# fix/haptics-media-vibration — vibration plays on phones with touch feedback off

Branch `fix/haptics-media-vibration` (from `main` at the BUG-101 merge). Report (user,
2026-10-13): "vibration isnt working".

## Findings (verified on the A55)

- The game did call the motor: `dumpsys vibrator_manager` listed every nuke (120 ms), death
  (250 ms) and close call (30 ms) from `com.jtg.perilpoint`, each `ignored_for_settings`.
- Godot's `Input.vibrate_handheld` tags pulses `usage: TOUCH`, and the A55's touch-feedback
  vibration is off (`VibrationIntensities: TOUCH = OFF`; MEDIA = MEDIUM). Android drops them.

## Ruling HAPTICS R1

- On Android 13+ `Haptics` calls the Vibrator itself through `JavaClassWrapper` and the
  `AndroidRuntime` singleton, with `VibrationAttributes.createForUsage(USAGE_MEDIA)` (games
  vibrate as media). Anything missing keeps `Input.vibrate_handheld`.
- Switching Vibration on in Settings gives one 60 ms buzz (`Haptics.preview`).

## Tasks

- [x] `haptics.gd` media path + preview; tests in `test_haptics.gd`. 871 tests green, gdformat
      and gdlint clean.
- [x] A55: 0.1.9 (code 10, `build/peril-point-0.1.9-a55.apk`) installed 2026-10-13 14:46; log
      `haptics: media vibration bound`; three pulses at 14:48 `usage: MEDIA`, `finished`.
- [x] User on the A55, 2026-10-13: "vibration works now as well".
- [x] Settings switch buzz confirmed on the A55, 0.1.10 (user 2026-10-13). Merged by PR #10.
