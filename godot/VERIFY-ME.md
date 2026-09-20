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

---

## M3 — Enemy roster (device pass, plan Task 7)

Unattended evidence at `11a9165`: 30/30 GUT scripts (184 tests) pass; headless
`--quit-after 120` exits 0 with no script error; the APK exports (30.3 MB).
The A55 was still off adb, so **no install, launch or screenshot happened.**
Run §0 first. An unattended launch dies to the first seekers within seconds,
so every item below needs a thumb.

- [ ] Survive to 5,000 in classic. A **charger** appears: a dart at the arena
      edge draws a pulsing dashed red line toward you for ~1 s, then darts
      at 480 px/s with an orange plume, then coasts. Then repeats.
- [ ] 10,000: a **specter** — a violet dot with a dashed ring that fades in
      and out as it homes.
- [ ] 16,000: **artillery** — a dark hexagon with a magenta barrel that keeps
      its distance, strafes, and fires a pink comet-tailed bullet every
      ~3 s; the muzzle glows before each shot.
- [ ] 22,000: a **pulsar** — a red dot with an expanding corona every 2.2 s
      and a spinning white star; killing it splits it into two small seekers.
- [ ] 32,000: a **carrier** — a rotating diamond with a dashed ring and four
      cyan satellites on tethers; killing it scatters the satellites.
- [ ] Formations, every ~6-12 s in classic: wall sweep with a five-dot gap;
      arrow wing of seven from left or right; ring of 12-16 that pauses then
      closes; a lone turret whose aim tick follows you; a snake of eight.
- [ ] Flying near a wall dot or a tethered satellite does not push it aside
      (they are excluded from separation).
- [ ] Every enemy shape sits exactly on its hitbox (all rotated draws now
      carry the arena origin) — nudge into a charger and an artillery unit.
- [ ] Frame time with a wall sweep plus a carrier on screen:
      `"$ADB" -s RRCXB04L8EJ shell dumpsys gfxinfo com.jtg.perilpoint | grep -A3 50th`
      — 50th percentile at or under 16 ms. The carrier's tether loop is
      O(carriers × enemies) per frame, as in the TS.

Not observable in any mode yet (no caller until M4/M10): `freeze_all`,
`spawn_sequential_gauntlet_wall`, `spawn_rotating_gate`, `spawn_mode_armada`,
and the gauntlet/code-red director branches. `spike_mine` has no spawner in
the web game either.

When done: tick M3 in `PORT-PROGRESS.md` with the SHA you tested.
