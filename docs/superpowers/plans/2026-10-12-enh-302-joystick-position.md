# ENH-302 — Stick position: Dynamic, Left or Right

Branch `ENH-302-joystick-position` (from `main` at `a99bfd9`). GitHub #4.

User (2026-10-12): "Make the joystick stick to a single section to avoid blocking the view --
Add option to sticky it to the corner or have it dynamic. Currently some players dont want the
joystick to be dynamic - some want to have it static at a certain area. Give those players the
option."

## Rulings (brainstorm, 2026-10-12, bounded path, design approved: "proceed")

- **R1 — Positions.** Stick position is Dynamic / Left / Right. Left and Right fix the stick
  in the bottom-left or bottom-right corner of the playfield. Dynamic (the default) is the
  current floating stick, unchanged.
- **R2 — Grab zone.** A fixed stick is grabbed by a touch within 2x its radius of its centre;
  the knob jumps to the thumb. Touches outside do nothing. The base never moves: an
  overshooting thumb clamps the knob at the rim. Same dead zone and ramp as Dynamic; Stick size
  scales the stick and the zone.
- **R3 — Place.** Settings → Controls, a segmented Dynamic / Left / Right row under the scheme
  cards, phones only. The Touch card's subtitle follows it ("Drag anywhere", "Stick left",
  "Stick right").
- **R4 — Look.** During a run, a fixed stick is drawn faintly at rest in its corner, and at
  the normal look while held. Not drawn in the menu.

## Tasks

1. [x] `ControlSettings.stick_anchor` (`ControlSettings.StickAnchor` DYNAMIC/LEFT/RIGHT), saved as
   `"stick_anchor"`, unknown values keep Dynamic. Tests in `test_control_settings.gd`.
2. [x] `FloatingJoystick`: anchor mode (`set_anchor`), grab zone, fixed base, recentre on
   release. Dynamic unchanged. Tests in `test_floating_joystick.gd`.
3. [x] `GameRoot`: place the anchor in `resize_canvas` and when the setting changes, mid-run
   included. `JoystickLayer`: the idle stick (R4). Placement is `FloatingJoystick.anchor_centre`
   / `apply_anchor` (`ANCHOR_INSET` 1.5 radii, tested); `GameRoot._apply_stick_anchor` after each
   `set_size`; `_is_touch_stick_live` names the routing condition and drives
   `JoystickLayer.show_idle` (`IDLE_ALPHA` 0.4). No headless test sees draw calls; the bench does.
   Seen once each in 2 of 3 suite runs here, never on `main` (2 runs) nor in 3 `--verbose` runs:
   "1 ObjectDB instance was leaked at exit". Recheck at task 5: it predates ENH-302 (main
   2/15, pre-ENH-301 `c3d3aeb` 1/9); verbose names a leaked `Image` plus a texture RID. Fixed
   on its own branch `fix/exit-image-leak` (user 2026-10-12: "Fix it first", "create a new
   branch for this issue"); merge that first, then rebase this branch onto main.
4. [x] `TiltMenu`: the Stick position row and the Touch card subtitle. Tests in
   `test_tilt_menu.gd`. `StickCard` ("Touch stick": `StickDynamic`/`StickLeft`/`StickRight`, built
   as Screen shake's card, hidden off mobile), `TiltMenu.touch_hint`, signal
   `stick_anchor_changed` → `GameRoot._apply_stick_anchor`.
5. [ ] Bench render at A55 size (idle and held, both corners); full suite, gdformat, gdlint.
   `godot/bench/shot_stick.gd` done and reviewed (Settings row, idle Left, held Right look
   right); 845/845 green, gdformat and gdlint clean. Open: the exit leak above.
6. [ ] A55 pass, `godot/VERIFY-ME.md` §ENH-302.
