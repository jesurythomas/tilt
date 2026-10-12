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
2. [ ] `FloatingJoystick`: anchor mode (`set_anchor`), grab zone, fixed base, recentre on
   release. Dynamic unchanged. Tests in `test_floating_joystick.gd`.
3. [ ] `GameRoot`: place the anchor in `resize_canvas` and when the setting changes, mid-run
   included. `JoystickLayer`: the idle stick (R4).
4. [ ] `TiltMenu`: the Stick position row and the Touch card subtitle. Tests in
   `test_tilt_menu.gd`.
5. [ ] Bench render at A55 size (idle and held, both corners); full suite, gdformat, gdlint.
6. [ ] A55 pass, `godot/VERIFY-ME.md` §ENH-302.
