# Gamepad stick (PAD R1)

User 2026-10-23: "what would be needed to get my odin controls working on stick mode", then
"try making a pr branch on this". Device: AYN Odin 2 (Android 13, built-in controller reported
as KEYBOARD | GAMEPAD | JOYSTICK). Branch `feat/gamepad-stick` from `staging` (`5c61e75`).

## Ruling PAD R1

- Under the Touch scheme (`ControlScheme.MOUSE` on a phone), a controller's left stick steers
  in place of the on-screen stick whenever it is pushed past a 0.2 radial dead zone. It feeds
  `GameRoot._update` the same value the touch stick does (direction with magnitude, 0..1), so
  `TOUCH_JOYSTICK_SPEED_SCALE` and the gyro branch apply unchanged. Released, the touch stick
  takes over again.
- Buttons (positional, Godot's SDL layout): A skips the cinematic, retries from the Run over,
  dashes in play; LB / RB fire item 1 / 2; Start pauses, resumes, or closes the Armory. Same
  rules as Space/Enter, Shift, 1/2 and Escape.
- Not in R1 (R2-R4 below add badges, menus and pad families): menus with a controller (the menus are touch-first; focus navigation is a separate
  piece of work), the stick under the Tilt and Keyboard schemes, remapping, hiding the
  on-screen stick while the pad steers.

## Rulings PAD R2-R4 (user 2026-10-23)

- **R2** "we probably need a button hint like a small A on the icon if gamepad mode is used":
  a small pill badge in the bottom-right corner of the dash gauge (A) and each item orb (LB,
  RB). Shown from a pad button press or a stick push past the dead zone, hidden by a screen
  touch (`GamepadInput.is_active_after`).
- **R3** "and UI support for the controller": `PadFocus`, last on the CanvasLayer. While the pad
  is in use, the top screen (`GameRoot.pad_focus_root`, go_back's order) keeps the focus, or its
  first shown, enabled, focusable control takes it; a cyan ring marks it (the theme's focus box
  is empty on purpose, for touch). Godot's ui_* actions do the rest (D-pad / stick moves, A
  presses, sliders take left/right); scroll boxes under the screen follow the focus. In play
  and the cold open, no screen: focus is dropped so A dashes / skips. B is `go_back()` (never
  quits the app).
- **R4** "and handler consideration for different controller types": buttons stay positional
  (Godot's SDL mapping: the bottom face button dashes on every pad); only the badge labels
  change, by `Input.get_joy_name()`: Xbox A/LB/RB (also the default for unknown pads, e.g. the
  Odin in its generic mode; its Xbox mode names itself as an Xbox pad), PlayStation ×/L1/R1,
  Nintendo A/L/R. Nintendo was B/L/R at first (the bottom button), but Android maps Switch-style
  pads by label: on the user's "Nintendo Switch Pro Controller" (USB 2020:0111) the printed A
  arrived as BTN_SOUTH → BUTTON_A (getevent, 2026-10-23), and Nintendo's own Pro Controller
  layout maps the printed A to BUTTON_A too. So on a Switch pad the printed A dashes and accepts
  and the printed B is Back, as on a Switch.

## Fixes and PAD R5 (user's Odin 2 pass, 2026-10-23)

- "I cant select play with a or b": Godot's default ui_accept is keys only. `GamepadInput.map_accept`
  adds the bottom face button to it at start; B stays Back.
- Picking a mode re-renders the menu and freed the focused row, so the ring jumped to the top:
  `PadFocus` now refocuses the control nearest where the ring was.
- The Run over opened on Watch ad (a quick A after a death started an ad): a screen now opens on
  its `PrimaryButton` (Play, Resume, Retry, Next, Set level, the reset sheet's Cancel).
- The Run over is one node reused run to run, so "keep the ring near where it was" reopened it
  on the last run's Armory. The remembered spot is dropped when the screen closes or a touch
  ends controller mode; a reopened screen starts on its primary button again (checked on the
  Odin: Armory → touch Retry → next Run over opens on Retry).
- The Odin's Controller style (Odin settings → Controller Settings; `persist.sys.gamepad.type`
  0 = Odin, 1 = Xbox): Xbox presents "Xbox Wireless Controller" (USB 2020:0112, BTN_SOUTH →
  BUTTON_A); A started a run and the badge read A. Set back to Odin afterwards. The user's
  Switch pad is an Onikuma presenting as "Nintendo Switch Pro Controller" (2020:0111).
- **R6** "I cant scroll down on achievements check on other screens too": a D-pad up/down that
  cannot move the focus (Godot leaves it unhandled; Achievements' rows and How to play's text are
  not buttons) scrolls the screen's list by 35 % of its height; the right stick scrolls any list.
  Each open screen remembers where the ring was, so closing a sheet lands back on what opened it
  (Settings → gear, Achievements → Achievements); cleared in a run or by a touch. The Armory
  header is linked Back → tabs → Play (Godot's nearest-right from Back picked the weapon list, so
  the tabs were unreachable). Checked on the Odin, screen by screen: Achievements (D-pad and stick
  scroll, B back to its button), Settings (rows, stick scroll to Reset), Armory (Play, upgrade
  rows, keystones, weapon list, tabs → Abilities), How to play (Next pages, B back), Pause →
  Settings → B back to Settings. A test step of mine picked Tilt on the menu by mistake; set back
  to Touch.
- **R5** "onehanded play optimization - stick button triggers the dash": L3 (left stick click)
  dashes too. The badge still reads A.
- Checked on the Odin 2 with its own controller (events sent to `/dev/input/event8`, the "Odin
  Controller"; `adb shell input gamepad` does not reach Godot as a joypad): ring starts on Play,
  A starts the run, L3 dashes (shield up, gauge spent), Start pauses with the ring on Resume.

## Tasks

- [x] 1. `src/input/gamepad_input.gd`: `shape()` (dead zone, rescale, cap at 1), `action_for()`
  (button map), `poll()` (strongest left stick of the connected pads). Tests
  `tests/test_gamepad_input.gd`.
- [x] 2. `GameRoot`: `_gamepad` polled in `_update` under the Touch scheme;
  `_handle_pad_button` from `_unhandled_input`.
- [x] 3. Checks, 2026-10-23 (macOS, Godot 4.7.2): suite 1043/1043, 76/76 scripts, nothing
  leaked; gdformat/gdlint clean.
- [x] 4. Debug APK (`com.jtg.perilpoint`, 0.1.25 code 26, Godot's debug key) installed on the
  Odin 2 next to the Play build; not yet played.
- [x] 5. R2 badges (`AbilityBar.PadBadge`), R3 `src/ui/pad_focus.gd` + `GameRoot.pad_focus_root`
  + B, R4 `GamepadInput.Family` / `family_for` / `label_for`. Tests in `test_gamepad_input`,
  `test_ability_bar`, new `test_pad_focus`. Suite 1058/1058, 77/77 scripts, nothing leaked;
  gdformat/gdlint clean.
- [x] 6. The fixes and R5 above; suite 1062/1062, 77/77 scripts, nothing leaked.
- [x] 7. Regression pass for touch play, 2026-10-23, on the Odin 2 (touches sent to the
  touchscreen, `synaptics_dsx`): Resume, drag steering, double-tap dash (shield up), pause button,
  Retry, Menu, Achievements / Settings swipe scroll, Armory Ships tab, back buttons; no ring and
  no badges in touch mode; steering stayed Touch. Frame time (SurfaceFlinger, 20 s menu ×2, 15 s
  steered run) against a `staging` build (`5c61e75`) on the same Odin: branch 16.67 / 16.67 ms
  mean, 0.0 % > 20 ms on the menu, run 16.68 ms, 0.1 %; staging 16.67 / 16.68 ms, 0.0 / 0.1 %,
  run 16.72 ms, 0.1 %. `tools/frametime.sh` needed its layer grep loosened on this phone (no hex
  prefix before `SurfaceView[`); not changed in the repo. Tilt steering not run on the Odin; its
  code path is unchanged (the pad only feeds the Touch branch).
- [ ] 8. User's Odin 2 pass per VERIFY-ME §PAD.
