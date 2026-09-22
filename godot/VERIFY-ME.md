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

- [ ] **Seven uncommitted files in `godot/src/`** (your 02:56 device-tuning
      edits — see `HANDOFF.md` "Uncommitted edits in the tree"). Commit them
      (one line, `M2.5: tune … from A55 device measurements`) or discard
      them; M4 implementation is waiting on a clean tree. Note three of them
      touch files M2.5 spec §2.3 says the module must not touch.
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

Not observable in any mode yet: `freeze_all` (callerless by design — M4 froze inline as the TS does),
`spawn_sequential_gauntlet_wall`, `spawn_rotating_gate`, `spawn_mode_armada`,
and the gauntlet/code-red director branches. `spike_mine` has no spawner in
the web game either.

When done: tick M3 in `PORT-PROGRESS.md` with the SHA you tested.

---

## M4 — Weapons (device pass, plan Task 7)

Unattended evidence at `d30d86e`: 33/33 GUT scripts (220 tests) pass; headless
`--quit-after 120` exits 0; the APK exports (30.3 MB). The A55 was still off
adb — **no install, launch or screenshot happened.** Run §0 first. Orbs drop
from a weighted table (missiles 20, nuke/laser 18, lightning/freeze/shield 16,
vortex 5 of 109), so a vortex orb takes a few runs to see.

- [ ] Each orb type shows its own white glyph on the coloured bubble:
      nuke trefoil (red), rocket (orange), bolt (yellow), crossed beams
      (violet), spiral (purple), snowflake (pale blue), shield outline (green).
- [ ] **Missiles:** eight rockets fan out from the orb with orange smoke,
      curve onto the nearest dots, and each detonates in a small orange
      burst that takes out a cluster.
- [ ] **Lightning:** a jagged yellow chain hops dot to dot from the orb,
      up to 14 hops, and fades in about a quarter second; every dot it
      touched is gone.
- [ ] **Laser:** a white-cored violet beam through the ship, both ends,
      spinning about 1.75 turns a second for 1.8 s, slicing dots it crosses.
- [ ] **Vortex:** a spinning six-arm purple/cyan spiral with three faint
      rings; nearby dots are reeled in and pop at the centre; after 4.8 s it
      collapses with a purple/cyan burst that clears everything within
      about 260 px.
- [ ] **Freeze:** every dot turns pale blue and stops for 4.5 s; flying into
      a frozen dot shatters it with an ice sound; a shatter burst and grid
      ripple appear at the orb.
- [ ] **Shield:** the ship's bubble appears for 6 s (silently — the TS has no
      shield sound); ramming dots kills them.
- [ ] Beams, rings, missiles and arcs draw **above** enemies and the ship
      (spec §5.5) — the web game draws them *under*. If that reads wrong on
      the phone, say so; it is a one-line swap (M4 plan open question 3).
- [ ] Frame time with a vortex and eight missiles live, and again when a
      nuke clears a big cluster (your `MAX_PARTICLES 400` / `emit_sparks 6`
      tuning is what M4 inherited):
      `"$ADB" -s RRCXB04L8EJ shell dumpsys gfxinfo com.jtg.perilpoint | grep -A3 50th`
      — 50th percentile at or under 16 ms.

Not observable yet (no rank source until M7): every perk-rank change. They
are proven headless in `tests/test_weapon_*.gd` and `test_run_controller.gd`.

When done: tick M4 in `PORT-PROGRESS.md` with the SHA you tested.

---

## HUD score feedback

- [ ] Kill pulse reads well: score scales 1.18× and flashes the tier colour
      for 0.22 s; multiplier label sits in the tier colour; no text piles up
      at kill sites — tune `PULSE_SCALE` / `PULSE_SECONDS` / tier colours in
      `hud_controller.gd` if not.

---

## M7 — Persistence and economy (device pass, plan Task 10)

Unattended evidence at fc19300: 40/40 GUT scripts pass; headless `--quit-after
120` exits 0 with no script error; the APK exports (30,431,782 bytes).
The A55 was still off adb, so no install, launch or screenshot happened.
Run §0 first. There is no Armory yet (M8), so nothing can be bought on the
phone; every purchase path is proven headless in `tests/test_progression_*.gd`.
What the phone can show is the save surviving a restart, the corrupt-file
fallback, coins, and the classic ship's shield orb.

- [ ] **Starting orb is a green shield**, not the red nuke M4 showed — the
      classic ship's `startingWeapon` (ProgressionManager.ts:138). If you'd
      rather the first orb stayed a nuke, say so: it is plan Open question 3.
- [ ] **Coins:** an amber disc with a white rim and a dark "S" bar appears
      2.5-4 s in, another every few seconds, never more than six; each fades
      over its last 3 s; flying through one gives a spark burst and a
      pickup sound (silent until M5 — the AudioBank stub logs it).
- [ ] **Coins draw under the orbs** (spec §5.5) — an orb and a coin
      overlapping should show the orb on top.
- [ ] **Saves survive a restart:** collect a few coins, kill the app from
      recents, relaunch, then
      `adb -s RRCXB04L8EJ shell run-as com.jtg.perilpoint cat files/tilt_to_live_progression_v3.json`
      — `"points"` is above 7331 and grows across launches; `"lifetimePoints"`
      matches.
- [ ] **Corrupt save falls back and is backed up:**
      `adb -s RRCXB04L8EJ shell run-as com.jtg.perilpoint sh -c 'echo "{broken" > files/tilt_to_live_progression_v3.json'`
      then relaunch: the game boots (no crash, no black screen), and
      `run-as com.jtg.perilpoint ls files/` shows
      `tilt_to_live_progression_v3.corrupt.json` beside a fresh
      `tilt_to_live_progression_v3.json` after the next coin. Points are back
      to 7331.
- [ ] **Tilt calibration and control scheme still persist** across a
      relaunch (they now go through SaveStore — M2.5's checks 1 and 2 again).
- [ ] Frame time with six coins and a vortex live:
      `adb -s RRCXB04L8EJ shell dumpsys gfxinfo com.jtg.perilpoint | grep -A3 50th`
      — 50th percentile at or under 16 ms.

Not observable yet: perk ranks, extra lives, hull compact, enemy slow and the
two multipliers all read from the save but nothing on the phone can change
them until the Armory (M8). To see them now, edit the JSON with `run-as` and
relaunch — e.g. `"extraLives": 2` gives three lives at the next run.

## M8 — Armory UI (device pass, plan Task 10)

Unattended evidence at 41c04e8: 42/42 GUT scripts pass (361 tests); headless
`--quit-after 120` exits 0 with no script error; the APK exports
(30,531,097 bytes).
The A55 was still off adb, so no install, launch or screenshot happened.
Run §0 first. The Armory opens from **ARMORY** on the pause overlay and on the
death screen (and from the `b`/`u` keys on desktop). Every purchase path is
proven headless in `tests/test_armory_ui.gd`; what only the phone can show is
touch operability, layout inside the safe area, the look of the three
cosmetics in a run, and persistence across a real relaunch.

Facts from execution (not in the brief):
- The GUT suite is 42/42 scripts, **361 tests** (not 362).
- The DIVERGENCE grep count is **71**, not 70 — one divergence is cited twice
  in `armory_ui.gd`.
- Plan defect #22: `GameRoot._on_run_ended` sets `phase = GAME_OVER`
  (`TiltGame.ts:2073`), so `_physics_process` stops the sim after death — the
  death explosion freezes in place. This matches the web game (its loop has
  no game-over branch); note it as expected, not a bug.
- Plan defect #21: opening the Armory from the **pause** button leaves the
  pause panel visible underneath the overlay — `TiltGame.ts:2343-2347` hides
  it only on a playing→paused transition (the `b`/`u` key from a live run).
  On device the Armory overlay should cover it; if the pause panel shows
  through or around the Armory, record that as a layout finding.

- [ ] **Reachable and inside the bezel:** pause → ARMORY. The overlay now
      covers the whole screen by construction (`Armory` root and `Overlay`
      ColorRect are full-rect, final-review finding 1); only the panel's
      edges sit inside the bezel/safe area, inset by `arena_origin`
      (no chrome under the camera cutout or the gesture bar). A `<` back
      button top-left, no `X`; a blue **Play** bar along the bottom. Tapping
      Play returns to the pause overlay with RESUME. Check for defect #21:
      does the pause panel show through/around the Armory overlay?
- [ ] **All five tabs render and are operable with a thumb:** Weapons, Ships,
      Arena, Handling, Boosts. Every button is at least the size of the pause
      button; nothing overlaps its neighbour; each tab scrolls vertically if
      it overflows. **On this landscape phone the weapons tab keeps its
      two-column desktop layout** (list left, detail right) rather than the
      web's stacked mobile layout at ≤820 CSS px — plan Open question 1; say
      if it is too cramped. Known gap, not a new defect: the weapons-list
      swatch is a raw `Panel` child of its `Button` and sits at (0,0) over
      the button's padding rather than in a flex row beside the label
      (final-review finding 10) — note whether it visibly overlaps the text.
- [ ] **Buy a track rank:** Weapons → Blackhole → Duration "1,800 pts" → the
      balance drops, the pip fills, the button reads the next price, the
      readout advances (6.3s → 6.8s becomes 6.8s → 7.3s).
- [ ] **Buy a keystone:** Laser → Cross Beam "3,500 pts" → "Unlocked ✓" in
      green. Start a run, collect a laser orb: the beam is a 4-way cross
      (M4's keystone effect, now purchasable).
- [ ] **Ships:** buy Solar (600), Equip it. The card border goes green and
      the hull preview is the gold battlecruiser. **Play:** the ship in the
      run is now the gold solar hull with orange thrusters and a nuke as the
      starting orb — not the white arrow. Try Viper (already unlocked):
      forward-swept red hull; Phantom: purple stealth diamond with a pulsing
      crystal; Cyber: brackets + hex core; Shuriken: spinning star with a
      rotating rune; Revenant: the celestial hull with a dashed halo.
- [ ] **Arena → Enemy Variations:** buy Toxic (400), equip. Dots in the run
      are green with pale rims; chargers/artillery/carriers take the skin's
      colours too (they only do for non-classic skins, EnemySwarm.ts:1260).
- [ ] **Classic skin look-change (plan Open question 5):** even with the
      classic skin equipped, hazard (orange) dots are gone in a run and the
      pulsar's ring/stroke are the crimson skin's `#ff8899` rather than
      `#ff4757`/`#ffa502`. This is what the web game draws in a live run
      (the skin is always passed, TiltGame.ts:2311); M3 had ported the
      menu-backdrop arm. Say if you want the hazard orange back — that is a
      one-line spec divergence, not a port fix.
- [ ] **Arena → Arena Themes:** buy Synthwave (400), equip. The backdrop,
      grid tint (if gridlines are on) and the perimeter change colour. With
      the default Void theme the perimeter is now the theme's
      `rgba(91,140,255,0.4)` rather than M1's 0.45 and the grid 0.18 rather
      than 0.28 (same class as the skin note — the theme is always passed in
      a live run).
- [ ] **Handling:** drag the Turn rate slider — the pill updates live and the
      preview ship on the right turns sharper; Deadzone likewise grows the
      amber ring. Drag a finger inside the preview box: the ship chases it.
      Reset restores 1.0× / 4px. Play a run: the steering change is felt
      (tuning is read by PlayerShip every frame).
- [ ] **Boosts:** buy Extra Life (4,000) → a run starts with 2 lives.
- [ ] **Purchases persist across a restart:** kill the app from recents,
      relaunch, open the Armory: every purchase and equip above is still
      there; then
      `adb -s RRCXB04L8EJ shell run-as com.jtg.perilpoint cat files/tilt_to_live_progression_v3.json`
      shows `"equippedCursorId":"solar"` and the spent balance.
- [ ] **Death screen:** die → ARMORY opens over the death screen; closing it
      returns to the death screen (no pause overlay). Check for defect #22:
      the death explosion should be frozen in place (sim stops on
      `phase = GAME_OVER`), matching the web game — this is expected, not a
      bug.
- [ ] Frame time with the Armory open over a paused run and, separately, in
      a run with the Solar hull and Toxic skin:
      `adb -s RRCXB04L8EJ shell dumpsys gfxinfo com.jtg.perilpoint | grep -A3 50th`
      — 50th percentile at or under 16 ms in both.

Not observable yet: the HUD's own Armory button (`btn-tilt-armory-hud`,
TiltGame.ts:1453) is not ported — plan Open question 2; the menu's entry to
the Armory is M11's.

## Mobile scale split (2026-09-22, after M8)

The user reported on the A55: models too small, weapon orbs and their glyphs
too small, the "map" too large. `game_root.gd` now caps the arena scale on
mobile at `MOBILE_ARENA_SCALE_CEILING = 1.25` (was the raw 1.588 — ranges,
formation spacing and speeds shrink ~21 %) and `entity_layer.gd` draws every
entity `MOBILE_MODEL_SCALE = 1.5` times its sim radius (render-only; hitboxes
stay at sim size, so visuals are slightly larger than collision). The orb
glyph now scales with its bubble on every platform. Desktop is unchanged.
Both constants are guesses until you look at them.

- [ ] **Ship / enemies read at a comfortable size** (net 1.25 × 1.5 = 1.875×
      base vs 1.588 before). Too big or too small → change
      `GameRoot.MOBILE_MODEL_SCALE` only.
- [ ] **The map feels less cramped**: nuke/laser/vortex ranges, wall and
      circle formation spacing, seeker speed. Still cramped → lower
      `GameRoot.MOBILE_ARENA_SCALE_CEILING`; too sparse/slow → raise it (the
      old feel is 1.75, i.e. uncapped).
- [ ] **Orb glyph is legible** inside its bubble (nuke trefoil, missile,
      bolt, crossed beams, spiral, snowflake, shield outline).
- [ ] **Hitbox leniency is acceptable**: an enemy visually overlapping the
      ship's hull by ~⅓ of its radius does not kill. If that feels wrong, the
      alternative is to apply the multiplier to sim radii instead (a
      different change — say so).
- [ ] **Charger telegraph line** (the dashed 480 px aiming line) is now
      drawn 1.5× longer on mobile because it lives under the entity
      transform. Fine or distracting?
- [ ] Frame time under a mass explosion is unchanged:
      `adb -s RRCXB04L8EJ shell dumpsys gfxinfo com.jtg.perilpoint | grep -A3 50th`.
