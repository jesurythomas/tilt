# VERIFY-ME — checks that need you at the phone

Everything in this file is something a session could not do unattended:
either it needs a hand on the Galaxy A55 (`SM_A556E`, serial `RRCXB04L8EJ`),
or it needs you to make a choice. Sections are appended per module; each
says what was **not** done and exactly how to do it. Tick as you go.

The A55 dropped off adb mid-session on 2026-09-20 before any M2.5 build
reached it, so **nothing from M2.5 onward has run on a phone.**

## 0. Build, install, launch (do this once, first)

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"

"$ADB" devices                      # must list RRCXB04L8EJ; if not, replug / allow USB debugging
"$GODOT" --headless --path godot --export-debug "Android" build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ install -r godot/build/peril-point-debug.apk
"$ADB" -s RRCXB04L8EJ logcat -c
"$ADB" -s RRCXB04L8EJ shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1
"$ADB" -s RRCXB04L8EJ shell pidof com.jtg.perilpoint        # a pid = survived startup
"$ADB" -s RRCXB04L8EJ logcat -d | grep -i "script error\|godot.*error"   # expect nothing
"$ADB" -s RRCXB04L8EJ exec-out screencap -p > godot/build/screen-m2.5.png
```

The APK at `godot/build/peril-point-debug.apk` was exported from a tree one
temporary log line ahead of HEAD; re-export as above rather than reusing it.

---

## M2.5 — Mobile feel (device pass, plan Task 8; spec §9)

Every constant M2.5 introduced is **provisional**. Only this pass settles them.

### Safe-area readout (spec §6.2 open question)

Temporarily add, in `godot/src/core/game_root.gd::resize_canvas()` right
after `arena_origin = inset`:

```gdscript
Log.info("M2.5-T8 viewport=%s safe=%s origin=%s" % [viewport, safe, arena_origin])
```

Rebuild, launch, then `"$ADB" -s RRCXB04L8EJ logcat -d | grep M2.5-T8`.

- [ ] `safe` is reported in the same pixel space as `viewport` (a 2340×1080
      viewport should show a safe rect of similar magnitude, not e.g. 780×360).
      If it is not, `arena_inset()` must fall back to the fixed floor — record
      the numbers in `HANDOFF.md` and remove the log line either way.

### The seven acceptance checks (spec §9) — record the actual result

- [ ] 1. Pause (top-right `II` button) shows the overlay; TILT / TOUCH each
      selectable there and on the death screen; force-stop + relaunch keeps
      the choice. KEYBOARD must be hidden on the phone.
- [ ] 2. TILT: hold the phone still for 10 s after a run starts — the ship does
      not drift.
- [ ] 3. TILT: tilt left → ship goes left; a single-axis wrist movement does not
      produce diagonal motion; magnitude feels proportionate. If not, tune
      `tilt_sensitivity` / `tilt_smoothing` defaults in
      `src/native/control_settings.gd`.
- [ ] 4. PLAY AGAIN recalibrates to the pose held at that moment.
- [ ] 5. TOUCH: the joystick appears under the thumb, tracks the drag, clears
      on release, and **on release the ship coasts to a stop** (it must not fly
      back to the arena centre — fix `fae4e51` `route TOUCH scheme through the
      gyro branch`, untestable headless because `OS.has_feature("mobile")` is
      false on the test host). This is also the only guard for
      `GameRoot._process()` calling `_joystick_layer.queue_redraw()`.
      Knob size: `KNOB_RADIUS = 34.0`, base/dead radii in
      `src/native/floating_joystick.gd` — all provisional.
- [ ] 6. Score block centred at the top, BEST beneath, multiplier beneath that;
      legible at arm's length. `ScoreMargin.offset_bottom = 140` in
      `scenes/main.tscn` is a fixed height and may be short at large
      `ui_scale`; `MIN_UI_SCALE 0.75` / `MAX_UI_SCALE 2.0` /
      `UI_SCALE_REFERENCE 720` in `src/ui/hud_controller.gd`.
- [ ] 7. Arena border clears the bezel and cutout on all four sides, no
      letterbox (`MIN_INSET_X 8.0`, `MIN_INSET_Y 12.0`, `MAX_INSET_RATIO 0.04`
      in `src/core/game_root.gd`). Entities read as larger without the game
      becoming unplayable (`MAX_ARENA_SCALE 1.75`, same file — read
      `HANDOFF.md` "Why MAX_ARENA_SCALE is 1.75" before changing it). The score
      block and pause button now follow `arena_origin`, so they should sit just
      inside the border, not under the bezel. If inset and scale fight,
      **the inset yields first** (spec §7.3).

### Added during the session

- [ ] 8. Ship hitbox matches its drawing: with TOUCH, nudge the ship's nose onto
      a seeker. Death should happen at visible contact, with no gap and no
      early death. (Fix `1476647` — the ship was drawn without the arena
      origin, 8–12 px up-left of its hitbox. Not testable headless.)
- [ ] 8b. Pause and death screens both show the current scheme's button pressed
      as soon as they open, and switching on one is reflected on the other.
- [ ] 8c. On the death screen, tapping the lower edge of TILT/TOUCH must not
      trigger PLAY AGAIN (the picker used to collapse to 0 px and overlap it).
- [ ] 9. Pause overlay: `PausePanel` panel min size 280×220 and the `II`
      placeholder glyph are provisional; judge them.
- [ ] 10. Grid density: cell spacing is fixed in px, so the A55 draws many more
      cells than the desktop. Judge it *after* seeing the larger entities;
      nothing was changed.

### Choices only you can make

- [ ] Death-screen assets (spec §7.5, decision D8): research was **deferred to
      M11** (HANDOFF.md, rulings). The panel is hand-styled. Say if you want the
      2–3 candidate list earlier.

### When done

Write the measured values back into the constants above, change each
`DIVERGENCE(M2.5 …)` comment to say the value was *measured on SM_A556E*, run
`tools/run_tests.sh`, `gdformat --check godot/src godot/tests`,
`gdlint godot/src godot/tests`, then commit one line:
`M2.5: tune inset, scale and tilt from A55 device measurements`.
Then tick M2.5 in `PORT-PROGRESS.md` with that SHA.
