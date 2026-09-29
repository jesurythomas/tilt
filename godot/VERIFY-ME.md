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

> **Gradle build (since 2026-09-27, for the dark Android system splash).** The preset has
> `gradle_build/use_gradle_build=true`. One-time local setup (the template is
> git-ignored): `"$GODOT" --headless --path godot --install-android-build-template
> --export-debug "Android" build/peril-point-debug.apk`, then append to
> `godot/android/build/gradle.properties`:
> `org.gradle.java.home=C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot` (Gradle
> 8.11 cannot run on the editor's Android Studio JBR, JDK 25) and
> `org.gradle.daemon=false` (else the headless export never returns). The APK is ~88 MB
> (native libraries stored uncompressed, which loads faster).

> **⚠ Frame-time checks (2026-09-26):** `dumpsys gfxinfo` reports
> `Total frames rendered: 0` for this app. It cannot see Godot's Vulkan
> SurfaceView, so every `gfxinfo … 50th` check below measures nothing. Use
> `dumpsys SurfaceFlinger --latency '<the app's SurfaceView (BLAST) layer>'`
> instead: `tools/frametime.sh <seconds> <label>` wraps it (M11c P1). Debug
> builds also print one `PERF` line per second (`adb logcat -s godot:I | grep PERF`):
> per-section CPU ms, GPU ms, enemies, particles, draw calls.

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
      `ui_scale`; `MIN_UI_SCALE 0.75` / `MAX_UI_SCALE 3.0` /
      `UI_REFERENCE_HEIGHT 390` / `UI_REFERENCE_WIDTH 844` in
      `src/ui/hud_controller.gd` (M8.5).
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
      `tools/frametime.sh 30 <label>` (p50 ≤ 16.7 ms, >20ms under 2%)
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
      `tools/frametime.sh 30 <label>` (p50 ≤ 16.7 ms, >20ms under 2%)
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
      `tools/frametime.sh 30 <label>` (p50 ≤ 16.7 ms, >20ms under 2%)
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
      `tools/frametime.sh 30 <label>` (p50 ≤ 16.7 ms, >20ms under 2%)
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
      `tools/frametime.sh 30 <label>` (p50 ≤ 16.7 ms, >20ms under 2%).

## M8.5 — Interface rework (device pass, plan Task 8; interface spec §7)

Folds in M8's pending Armory pass: the Armory it described is rebuilt, so
tick M8's section only through this one (spec §7). Build and install per
§0. Compare every screen with its board in `peril-point-mobile-redesign/`
(open the `.dc.html` in a browser at 844×390).

**Type and scale**
- [ ] Titles render in Archivo (wide, bold); labels in IBM Plex Sans; every number in IBM Plex Mono. The score does not jitter as it counts.
- [ ] Nothing reads smaller than the board suggests (ui_scale ≈ 2.77 on the A55). Nothing is clipped at a screen edge or under the camera cutout.

**HUD** (`Hud.dc.html`)
- [ ] A thin ion outline marks the playfield, inside the bezel and gesture bar.
- [ ] Score top-centre, BEST under it, multiplier chip from 2× in its tier colour (yellow 2–4, orange 5–9, magenta 10–19, cyan 20+); the kill pulse still fires.
- [ ] Buy **Extra Life** in the Armory, start a run: ship icons top-left, one greys out per life lost. A one-life run shows none (TS behaviour).
- [ ] Pick up a timed weapon: "NAME n.ns" and a thin meter at bottom centre in the weapon's colour; the shield after a lost life shows "SHIELD".
- [ ] Pause is a 48 px square top-right, inside the outline, easy to hit.

**Pause** (`Pause.dc.html`)
- [ ] Sheet centred over a dark scrim; "Paused", then "score · m:ss · mode".
- [ ] Resume (tall, blue) resumes; **Restart run** starts a fresh run.
- [ ] Steer: Touch | Tilt segmented; the calibrate button beside it appears **only** in Tilt, and tapping it re-zeroes tilt (no toast until M9).
- [ ] Sound and Music switches flip, and survive an app restart.
- [ ] Armory opens the Armory; closing it returns to this sheet.
- [ ] No Quit or Settings button (M11).

**Run over** (`RunOver.dc.html`)
- [ ] Big score, "Swarmed at m:ss — mode, 1.0×"; Kills · Best chain · Alive.
- [ ] Beat your best: the flare "New best — up N" banner appears; otherwise it does not.
- [ ] "Points earned +X → Y" matches the coins picked up; **Spend Y** opens the Armory.
- [ ] Retry (tall, blue, right column) starts a run. No Menu button (M11).

**Armory** (`ArmoryWeapons/Ships/Arena/Handling/Boosts.dc.html`)
- [ ] Full-screen dark shell; 64 px header: back, "Armory", five tabs, points "N PTS" in flare, blue **Play**. Back and Play both close.
- [ ] Weapons: list on the left scrolls (fade at its foot); detail with tinted icon box, INVESTED; tracks with pips and cost buttons; keystones in plasma, dimmed with a lock when unaffordable. Buying still works and persists.
- [ ] Ships: cards scroll sideways; Hitbox/Turn meters differ per ship; Equip/Buy work.
- [ ] Arena: themes and enemies rows scroll sideways; tapping a card buys or equips it; the arena changes in a run.
- [ ] Nested scrolls (Task 6 review): a sideways drag that **starts on a card** scrolls its row (Ships, Arena themes, enemies) instead of being eaten as a tap; a vertical drag starting on a row still scrolls the tab body.
- [ ] Handling: Turn rate and Tilt sensitivity sliders; the preview ship responds to tilt; **Calibrate tilt** re-zeroes; Reset restores both.
- [ ] Boosts: 2×N cards with pips; cost buttons; "Max" when maxed.

**Findings** (fill in; one line each: screen — what differs from the board)
- (none — not run: A55 absent from adb on 2026-09-23; debug APK exports at 31,561,743 bytes, +1,030,646 over M8's 30,531,097)

## M9 — Milestones (device pass, plan Task 8)

Unattended evidence: `adb devices` returned no devices on 2026-09-23 (the
A55, RRCXB04L8EJ, is absent); `tools/run_tests.sh` → `OK: 48/48 scripts
collected, all tests passed` (486 tests, 5462 asserts); `"$GODOT" --headless
--path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR"` → `0`; debug
APK export (`--export-debug "Android"`) succeeded, `godot/build/peril-point-debug.apk`
at 31,640,597 bytes, +78,854 over M8.5's 31,561,743.

Hand-held checks (tick when seen on the A55):

- [ ] **Rail** (`Hud.dc.html`): a 3 px ion line on the top edge of the arena frame, from its left corner, growing by 1/57 of the frame's width per milestone. It does not respond to taps. Hidden only in menu mode (M11).
- [ ] **Toast**: complete a milestone by buying a ship in the Armory and closing the Armory within 3 s, or by hitting a cumulative total mid-run — either shows a card under the lives icons — green check, title, `+N` in flare — for 3 s. It does not block touches or the joystick. (A toast fired while the Armory stays open draws underneath it and will not be seen — that is not a failure of this check.) Calibrate (Pause, gyro scheme) shows `TILT CALIBRATED` / `Neutral Angle Zeroed ✓` with the ion ring for 2.8 s; **pending I-2 ruling (toast drawn under Pause)** — note whether it is visible at all, but do not fail the check on it.
- [ ] **Run over**: a run that earns milestones lists them under "Points earned +X → balance" (check, `Title — description`, `+N`); the list is hidden when none were earned. With 4+ rows the list clips and Retry stays on screen (R9 — say whether clipping looks acceptable).
- [ ] **Screen from Run over** (`Milestones.dc.html`): tapping the points row or the list opens the full-screen Milestones screen: 64 px header (Back, title, `n/57`, progress track, points), three side-by-side columns (Score 9, Combat 17, Mastery 31), open goals above done ones, each column drag-scrolls with a fade at its foot. Back closes it; nothing underneath reacts to taps while it is open.
- [ ] **Unlock goals at boot**: an existing save that already owns a goal's ship/skin/arena completes that goal once at launch, silently (B3: no toast, no points paid — only cumulative.totalPointsEarned moves), never twice.
- [ ] **Persistence**: kill the app and relaunch — completed milestones and cumulative totals survive (`user://tilt_to_live_completed_goals_v1.json` is a bare JSON array).
- [ ] **Frame time** under a mass explosion unchanged from the "Mobile scale split" figure (the per-tick goal check is a 57-goal loop).

## M10 — Modes

Code-complete 2026-09-25 (head `1677df2`). Pick a mode on Pause → Mode, then tap
Restart run (or die and Retry).

A55 absent from `adb` on 2026-09-25; every check below is pending.

- [ ] **Picker.** Pause shows Mode: Standard | Gauntlet | Code Red under
      Restart run; the saved mode is highlighted; nothing clips at 844×390
      logical (the A55). A pick does not change the running run; Restart run
      starts the picked mode; the pick survives an app relaunch.
- [ ] **Banner.** Each run opens with the mode's banner under the HUD's top
      row (CLASSIC SURVIVAL / THE GAUNTLET / CODE RED PROTOCOL), fading out
      after ~3.7 s of real time (2.8 s of sim time at GAME_SPEED 0.75). It
      does not collide with the score, lives or pause button. Dying inside
      that window leaves no banner under Run over.
- [ ] **Gauntlet walls.** Walls descend from the top with sliding amber
      stripes, an amber leading edge and pulsing green gap beacons; the ship
      cannot pass through a wall from below or the side; a wall carries the
      ship down; sparks fly on contact; walls speed up with score and time.
- [ ] **Gauntlet crush.** Pinned against the floor with 2+ lives (Armory
      boost): one life lost, the shield comes up, the run continues. With one
      life: the run ends. It never drains several lives in one crush.
- [ ] **Gauntlet score.** Score climbs steadily with no kills; hazard corner
      brackets show at the four corners; no horizontal/vertical wall sweeps.
- [ ] **Code Red.** A slow plasma vignette pulse at the edges; spawns come
      fast and in pairs; elite enemies arrive early; orbs spawn faster.
- [ ] **Multipliers.** Run over's subtitle reads "— Gauntlet, 1.3×" /
      "— Code Red, 1.5×" / "— Standard, 1.0×"; Pause's stats line names the
      running run's mode even after a different pick.
- [ ] **Frame time.** A 2-minute Gauntlet run holds 60 fps (at 2340×1080
      physical px a Gauntlet frame draws roughly 650 clipped stripe polygons —
      ~130 per pattern-0 row × 4–5 rows; the clip work is shared, final review
      F-1, and the draw count is unchanged).
- [ ] **Early resize.** A Gauntlet run booted straight in: if the window
      resizes just after boot (system bars hiding), the first rows keep their
      pre-resize width until they scroll off (TS-faithful; `TiltGame.ts:2435`
      only calls setScale). Look for an open right edge in the first ~10 s.
- [ ] **Ship vs walls on mobile.** The ship is drawn at 1.5× (M2.5
      `MOBILE_MODEL_SCALE`) while walls and collisions use sim size, so the
      drawn ship overlaps a wall by ~0.5 radius before it touches. It can also
      look as if it squeezes through gaps narrower than its body. Judge
      whether this reads as wrong; it is a consequence of the M2.5
      mobile-scale divergence, not an M10 change.

## M5 — Audio bake and SFX

Code-complete 2026-09-25 (head `acce4a5`). Sound on (Pause → Sound). Music (M6) plays under
the effects; judge only the effects here. A55 absent from `adb` on 2026-09-25; no
APK was installed, so nothing below has been checked on the device yet.

- [ ] **Weapons.** Each orb pickup plays its weapon's sound, then the pickup
      chime: nuke boom, missile launch (and a pop per missile blast), laser
      zap, lightning crackle (pitch varies call to call), freeze chime,
      vortex drop. Shield is silent (as in the TS).
- [ ] **Kills.** Each kill pops a note that climbs the pentatonic scale with
      the combo and wraps after 15; combos 10, 16 and 25 add a chord chime.
- [ ] **Pickups and misses.** Coins play a quiet two-note chime; a near miss
      chirps; ramming a frozen enemy crackles like ice.
- [ ] **Lives.** Losing a life (2+ lives, Armory boost) sounds the siren;
      the last life plays the long death crash.
- [ ] **Nuke storm.** A nuke through a dense swarm pops many notes at once
      without distortion that sounds broken, and the frame rate holds. Past
      32 simultaneous voices the extras are dropped (M5 R2) — judge whether
      that is audible.
- [ ] **Sound switch.** Pause → Sound off silences everything at once,
      including a tail still playing; on again restores the same loudness;
      the choice survives Retry and an app relaunch.
- [ ] **Sync and level.** Sounds land on their events with no noticeable
      lag, and their loudness roughly matches the web build on the same phone.

## M6 — Generative music

Code-complete 2026-09-25 (head: the M6 exit commit, see `PORT-PROGRESS.md`).
Music on (Pause → Music) and Sound on (Pause → Sound — it is the master mute and
silences music too). A55 absent from `adb` on 2026-09-25; no APK was installed, so
nothing below has been checked on the device yet.

- [ ] **Starts with the run.** Music starts as the run starts (at boot and on
      Retry / Restart run). There is no cinematic until M11, so it starts
      ~0.65 s sooner than the web build (the 600 ms cold open plus the 50 ms
      lead, M6 R7/R8) — expected, not a bug.
- [ ] **Evolves across bars.** Drums, bass and arpeggio from the top; the lead
      melody enters at ~9 s (bar 4) and climbs at ~18 s (bar 8); the breakdown
      (pads, snare roll) runs ~21–28 s; the loop restarts at ~28.7 s.
- [ ] **Five minutes.** A run of 5+ minutes has no gap, click, doubled beat or
      drift at any loop point (every ~28.7 s), and no dropouts (spec §8 M6 Accept).
- [ ] **Pause and Armory.** Pause (or opening the Armory mid-run) stops the
      music at once; Resume restarts it from the top, as the web build does.
- [ ] **Music switch.** Pause → Music off keeps it off after Resume and Retry;
      on again plays from the top on Resume. The choice survives an app relaunch.
- [ ] **Sound switch.** Pause → Sound off, Resume: music stays silent with the
      effects. Sound on again, Resume: music returns at the same loudness. (The
      R6 no-burst rule has no reachable trigger yet — Pause already stops the
      music — so this check does not verify R6.)
- [ ] **Death.** The death crash stops the music; Retry starts it again.
- [ ] **Level.** The music sits under the effects roughly as it does in the
      web build on the same phone.

## M11a — Menu, Settings, Calibrate

Code-complete 2026-09-25 (Tasks 1-8; exit commit — see `PORT-PROGRESS.md`).
A55 absent from `adb` on 2026-09-25, so nothing below has run on a phone.
Run §0 first.

- [ ] 1. A cold boot shows the menu. The backdrop ship roams **left of** the
      mode panel and dodges, orbs appear there too, and nothing important
      hides behind the panel (R1). Note any overlap with the title block.
- [ ] 2. Each mode card highlights with its colour. Play starts that mode,
      and the run's banner names it.
- [ ] 3. Pause → Quit to menu → the menu, with no HUD score, no music and
      the backdrop running. Play again → the run has the equipped ship skin
      and arena theme.
- [ ] 4. Death → Run over → Menu → the menu. The Coins row appears only when
      coins were picked up.
- [ ] 5. Settings from the menu and from Pause: each switch reads correctly;
      Enemy outlines off removes the white rings at once; Background grid on
      shows the grid at once. Screen shake Off/Low/Full visibly changes the
      hit and death shake in the next run.
- [ ] 6. Settings → Sound off mutes at once; Music off stops the loop at
      once; Music on from Pause's Settings starts nothing until Resume (R9,
      Q2 ruling, same as Pause's own switch).
- [ ] 7. Calibrate from the menu icon, and from Settings' "Calibrate tilt"
      (Tilt scheme only): the dot moves with the phone and stops at the
      dashed ring. Set level → toast "TILT CALIBRATED" on the menu. The next
      Tilt run is level at that pose — **but only the first Play from the
      menu.** Restart run and Play again both re-run `restart_run`'s own
      calibrate (an M2.5 decision, VERIFY-ME check 4, "PLAY AGAIN
      recalibrates to the pose held at that moment"), which overwrites a
      Set-level pose with whatever the phone is doing at that instant.
      `launch_run` (the menu's own Play) does not recalibrate (final review
      I-1), so a Set-level pose only survives the very next Play, not a
      later Restart/PLAY AGAIN. Judge on device whether this asymmetry feels
      wrong — if so it is a one-line change (add or drop the calibrate call
      at either site) once you say which behaviour you want.
- [ ] 8. Reset progress → Cancel changes nothing. Reset → confirm → the app
      reloads to the menu, settings are back to defaults; milestones,
      points, unlocks and the best score are cleared; the control scheme and
      calibration remain (R10, Q1 ruling).
- [ ] 9. The 48 rule: every menu, Settings and Calibrate target is
      comfortably tappable. Nothing overlaps at the A55's size.
- [ ] 10. Android back gesture/button in the menu, Settings and Calibrate:
      record what happens. The TS has no back button; if it quits the app
      from Settings, raise it as **Q3**.
- [ ] 11. The mode-card taglines and the Next teaser clip with "…" —
      acceptable?
- [ ] 12. The Play button's icon sits at the button's left edge, not beside
      the label — acceptable?
- [ ] 13. Settings' Readability column fits vertically at the A55's size
      (grid hint wraps).
- [ ] 14. Calibrate's disc and legend are flush-right with no safe-area
      inset — check against the camera cutout.
- [ ] 15. With the Touch scheme, touching the menu backdrop may draw the
      floating joystick behind the menu.
- [ ] 16. The menu title lacks the board's -0.015em letter-spacing —
      visible?
- [ ] 17. The Set level toast may be hidden when Calibrate was opened from
      Settings (the opaque modal covers the Hud ToastSlot); on the menu-icon
      path the title block may overlap it. Judge on device.
- [ ] 18. The tilt sensor stays on in MENU after a cold boot and after
      picking Tilt in the Steer row, while return-to-menu and closing
      Calibrate stop it (`_on_calibrate_closed`, `GameRoot.gd`). Note any
      battery or feel issue.

When done: tick M11a in `PORT-PROGRESS.md` with the SHA you tested, and
resolve Q3 above in `HANDOFF.md`'s Open questions (M11a).

## Armory / economy / icons rework (plan `2026-09-28-armory-economy-icons.md`)

Built 2026-09-28 from the user's request; emulator-checked only (the A55 dropped off
`adb`). Install the debug APK (§0). Your existing save keeps its balance; any of the
removed keystones you owned (Aegis, Fallout Zone, Battering Ram, Shatter Cascade) is
refunded once on the first launch.

- [ ] 1. **Earning feels right.** Play 3–5 normal runs (Classic and Code Red). The Run
      over shows one "+N" (it counts up; a tap skips). A short death should pay ~100–250,
      a solid 2–3 min run ~800–1,500, Code Red ×1.5. Too stingy or too generous? The
      knobs are `ProgressionManager.RUN_PAYOUT_*` (60 base, 3/s alive, 4·kills^0.7),
      `CoinSystem.COIN_BASE_VALUE` (10) and `GoalManager.MILESTONE_REWARD_SCALE` (50).
- [ ] 2. **Prices feel right.** Perk ranks 250/400/650/1,000/1,600; boosts 500–7,000;
      keystones 3,500/5,000. Is the next upgrade usually 1–3 runs away early on?
- [ ] 3. **Armory on the phone.** Weapons: one column (tracks, then Keystone, then
      nothing else); each row reads "now → next", pips in the weapon's colour, and the
      button shows the price (dimmed when you cannot afford it) or Max. The list shows icons,
      "ranks/total" and an orange dot where something is affordable. Boosts: one column
      with icons and "hitbox 100% → 94%"-style values. Buying pops the new pip.
- [ ] 4. **Icons.** Armory, the HUD weapon timer (icon + name) and the orbs in play use
      the same glyphs and one colour per weapon. Can you tell every orb apart at a
      glance, at arm's length? (Laser = hub with two beams; black hole = swirl.)
- [ ] 5. **Black hole shield is innate.** With no purchase, standing inside an active
      black hole protects you (0.3 s shield refreshed each tick).
- [ ] 6. **Run over.** No previous balance, no coin count; "Destroyed" shows enemies
      destroyed; the right button reads "Armory".
- [ ] 7. **Keystones (2026-09-28).** Every power-up sells three; try a few in play:
      Fallout Zone's green burn zone, Chain Reaction bursts, Second Salvo, Forked
      Lightning, Overcharge's pulse when the shield ends, Coin Vacuum. Too strong or too
      weak? Prices 2,500–5,000 (`Tuning.KEYSTONE_COSTS`), numbers at the top of
      weapon_system.gd.
- [ ] 8. **Achievements.** "Milestones" reads "Achievements" everywhere; several earned at
      once toast one after another; the Run over lists all of the run's under the stats
      and scrolls.
- [ ] 9. **Menu.** Your points show under the left column from the first launch; the
      title and NEXT text read clearly over the attract-mode swarm.
- [ ] 10. **Idle menu (UI R10).** Leave the menu open 10+ minutes. The swarm behind it
      stays a light scatter (it used to fill the map, 140+ dots); fps holds. No wall
      formations sweep the menu any more (runs still have them).
- [ ] 11. **Menu controls (UI R11).** The selected Steer option (Touch or Tilt) is
      clearly blue with its glyph; Armory (chevrons) and Achievements (trophy) stand
      out; the Settings button is a cog. Same Steer look on Pause and Run over.
- [ ] 12. **No multipliers, casing (UI R12).** The Run over subtitle reads "Swarmed at 0:07
      — Code Red"; the run-start banner has no "1.5X SCORE". Settings: "Drag anywhere",
      "Tilt the phone". Any label still oddly capitalised?
- [ ] 13. **Enemy textures (SKIN R1).** Buy and equip a skin: every dot shows its pattern
      (Toxic bubbles, Glitch bands, Magma cracks, Void swirl, Gold gleam) and still reads
      as a threat at arm's length. No hitch when the first dots appear.
- [ ] 14. **Ships and Arena showcases (ARMORY R7).** One ship (Ships) and one theme plus
      one enemy skin (Arena) at a time; ◀ ▶ cycle and wrap; the arena on the right shows
      what you are browsing. Only the card's button buys or equips. Nothing scrolls.
- [ ] 15. **Clickable vs not (ARMORY R6).** Prices you can't afford are dim with a lock;
      Equip is blue; Reset, Menu and Armory look pressable. Anything still ambiguous?
- [ ] 16. **Same buttons everywhere (UI R13).** Menu, Pause and Run over buttons share
      one look with icons (⌂ Menu, ↻ Restart/Retry, ▶ Resume, chevrons Armory, ⚙ Settings,
      trophy on the Run over's achievements).
- [ ] 17. **Orb magnet (ORB R1).** Fly near a power-up orb and it flies to you, like
      coins. The run's opening orbs stay where they are until you take them. Too strong?
      `WeaponSystem.ORB_MAGNET_*`.
- [ ] 18. **Touch stick (TOUCH R1).** On Touch, drag past the stick's rim and back — the
      base follows, so the ship turns round at once. Full push is as fast as full tilt.
      Try Armory → Handling → Stick size at 60–160%. Does it now feel as good as tilt?
      Knobs: FloatingJoystick.DEAD_FRACTION, GameRoot.TOUCH_JOYSTICK_SPEED_SCALE.
- [ ] 19. **Galaxy Tab S9 FE (2026-09-29).** Plays at p50 60 fps with ~7% of frames
      > 20 ms. Watch for hitches in busy moments. Does the 16:10 layout feel right
      (menu, Armory, Run over)? The tablet logs an empty-image texture error on two
      first frames with nothing visibly missing. Report anything that looks absent.

## M11c part 1 — Performance (plan `2026-09-26-m11c-performance.md`)

Code-complete 2026-09-26. The A55 dropped off `adb` at 02:11 that day, so
nothing below has run on it. Debug builds print one `PERF` line per second:
`"$ADB" -s RRCXB04L8EJ logcat -s godot:I | grep PERF`.

- [x] 1. **Late run** — run 2026-09-26 on the P1–P8 build (`580c854`): 75 s
      of PERF lines, **no second below 55 fps** in any enemy bucket (up to
      100+), sim ~2 ms/frame (was 46–54), entity draw 7.1 ms at 100+ (was
      14–17), `maxsteps` ≤ 3 (target ≤ 2; was 8). `tools/frametime.sh 90`:
      p50 16.67, p95 16.79, p99 25.0, >20ms **1.7%**. Only 3 s were above 100
      enemies — repeat with a longer late run. Original target: a Classic run past 100 enemies (`en=` in the PERF
      line): `fps` ≥ 58, `maxsteps` ≤ 2. Before this pass: fps 12–14,
      maxsteps 8, swarm 22–27 ms, grid 18–19 ms, entity draw 14–17 ms per
      frame. Then `tools/frametime.sh 60 late-run`: p50 ≤ 16.7 ms, >20ms
      under 2%.
- [ ] 2. **Kill spikes.** A nuke or vortex through a dense swarm, and a
      wall-sweep formation spawning: no visible hitch; the PERF line around
      it keeps `maxsteps` ≤ 2.
- [ ] 3. **Dots look the same.** Enemy dots (halo, glow, body, inner,
      border, pupil), frozen dots and particles now draw from shared
      textures (P5). Edges are smoother than before; anything else that
      looks different is a finding. The kill shockwave ring keeps `draw_arc`
      once it grows large (final review): it should look exactly as before.
- [ ] 4. **Grid on.** Settings → Background grid on, mid-run: the grid
      appears (flat), ripples on the next kills, and the PERF line shows
      the awake-grid cost (`s_grid`).
- [ ] 5a. **Ring formation (P9).** The mid-run ring that pauses, then closes
      in, now has 8–10 dots in Classic and 11 in Code Red: is there room to
      slip out? (After P8 the user found it still too tight.)
- [ ] 5b. **Armory drags** (fix `04224b2`): every tab scrolls when the drag
      starts on a card or button; a tap still buys/equips; ship, theme and
      enemy rows scroll sideways; a vertical drag starting on a row scrolls
      the page; sliders and the handling preview still take their own drags.
- [ ] 5c. **Coin magnet (P10):** coins within ~180 px fly to the ship and
      are collected; coins further away stay put.
- [ ] 5d. **Milestones (P11):** one scrolling column, Score then Combat then
      Mastery, each with its "n of m" count; drag-scrolls from any card.
- [ ] 5. **Start ring.** A Classic run opens with the 8 seekers much
      further out (0.42 × the arena's short side, ~443 px on the A55, P8).
      Is it now fair to escape?
- [ ] 6. **Cold open centred.** Ship, "PERIL POINT" and the glow sit in the
      middle of the screen (was ~530 px right and ~100 px low).

### Review fixes (plan `2026-09-27-m11c-review-fixes.md`; emulator-verified only)

- [ ] 7. **Render thread (P24).** `rendering/driver/threads/thread_model=2`
      (Separate). Steering must still feel immediate (it can add up to ~2 frames of
      latency); no flicker, no crash over a long run. If it feels laggy or crashes,
      delete that one line from `project.godot` and report. (The emulator A/B,
      5 pairs, 2026-09-27: Separate is ~40–50% faster at 100–249 enemies despite
      the logcat line "Rendering thread not supported by this display server" —
      ignore that line. The latency feel still needs a person.)
- [x] 8. **Late run with walls and carriers.** A55, 2026-09-28, HEAD `b4901c1` (N7): the
      user played 212 s up to 251 enemies — **60 fps in every bucket** (150–249: 60.8,
      250+: 60.0), 0 s below 50 fps, maxsteps normal; game work at 150+ ~8.4 ms of 16.7
      (m_phys 2.7 + m_proc 5.7; m_tail is vsync wait), GPU ~5 ms. User: "FPS actually
      looks good on mobile now." Original check: The user's drop points. Classic past
      100 enemies: PERF `fps` at 150+ enemies and whether a wall formation still
      causes a visible drop. Emulator (3.4× slower than the A55 per dot) went from
      5.4 to ~18–31 fps at 150–249 enemies across P13–P24.
- [ ] 9. **Baked enemies look right (P13, P19).** Seekers, frozen dots, carriers
      and satellites, pulsars (star spins), artillery (flash at the muzzle), chargers
      (charging vs aiming colours): same shapes and colours as before, edges smoother.
- [ ] 10. **Text over the swarm.** HUD score, BEST, the weapon timer and the menu's
      title/tagline/NEXT have a dark outline; "CLOSE CALL! +N" is large and bold.
- [ ] 11. **UI fixes.** Armory → Handling preview ship is coloured (was black); a
      purchase flashes the balance green and the list keeps its scroll; "+0" runs
      show the points hint; Code Red's tagline wraps; Settings header aligns with
      Armory's.
- [ ] 12. **Grid and background.** The grid is on by default (an old install switches
      it on once; Settings can turn it off and that sticks). It ripples on kills and
      settles; the arena background has no banding rings; PERF `s_grid` stays low.
- [ ] 13. **Menu.** No border around only the left half of the screen.
- [ ] 13a. **Particles (P25).** Explosions, sparks, thruster trails and kill rings look
      and move as before (they now integrate once per frame, in closed form); nothing
      jumps when the frame rate dips.
- [ ] 13b. **Armory/Milestones/HUD details.** Boost cards show their names; milestone
      rewards read "+N pt(s)"; Pause reads "Score N · m:ss · Mode"; the HUD's BEST turns
      "NEW BEST" once passed.
- [ ] 14. **Launch.** Home-screen icon is the blue ship; opening the app shows the
      ship on the system splash (light background — needs a Gradle build to change),
      then the PERIL POINT loading screen, then the menu.
- [x] 15. **Native swarm (N3, 2026-09-28).** A55 2026-09-28 (`b4901c1`): 0 SCRIPT ERROR, 60 fps at 250+ (see 8). On the A55 (real arm64, not the
      emulator's translation): a Code Red run past 250 enemies plays like the
      emulator's (enemies chase, walls sweep, carriers orbit, pulsars pulse, rams
      and shatters kill). `adb logcat -s godot:I` shows no `SCRIPT ERROR` (a missing
      library fails to parse every script that names `PerilEnemy`). Record fps at 250+
      from the `PERF` line (emulator: 24.7).

## M11b — Entrance cinematic

Code-complete 2026-09-26 (Tasks 1-2, final review fixes F-1..F-3; exit
commit — see `PORT-PROGRESS.md`). A55 absent from `adb` on 2026-09-26 (only
an emulator attached), so nothing below has run on a phone. Run §0 first.

- [ ] 1. Play → the cold open: void, a soft blue glow, the ship glyph,
      "PERIL POINT", and a thin bar near the bottom that fills in about
      0.6 s. Then the run. Note any title clipping at the A55 size.
- [ ] 2. A tap anywhere skips it at once. Nothing is drawn behind it (no
      HUD, no Pause button reachable).
- [ ] 3. The warp-in sound plays as it opens. With Music on, the loop
      starts only as the run begins, not during the cold open.
- [ ] 4. Classic: the run opens with 8 seekers in a ring, a nuke orb above
      the ship, the ship's starting orb, and a shield bubble for about
      2.5 s. Judge whether this start is fair on a phone (R12).
- [ ] 5. Code Red: a 24-seeker ring, a vortex left and a nuke right.
      Gauntlet: 8 seekers from the edges and a nuke.
- [ ] 6. Retry, Pause → Restart and PLAY AGAIN each replay the cold open.
      The previous run's enemies are gone.
- [ ] 7. A held finger during the skip tap does not steer the ship or
      leave the joystick drawn when the run starts (Touch scheme).
- [ ] 8. The ship glyph has no glow yet (`TODO(M11c)`, R3). Judge whether
      it reads well enough flat.
- [ ] 9. Android back during the cold open: record what happens (M11a Q3,
      Open question 1 in `HANDOFF.md`'s Open questions (M11b)).
- [ ] 10. Retry / PLAY AGAIN / Pause→Restart with a tap: the new cold open
      is not skipped at once by the same tap (touch-to-mouse emulation;
      unverifiable headless).

When done: tick M11b in `PORT-PROGRESS.md` with the SHA you tested.

## MVP R5 — first run (2026-09-29)

Code-complete; nothing below has run on a phone. Use a fresh install, or Settings → Reset
(which clears the best score and the flag).

- [ ] 1. First Play on a clean save: the line "Fly into orbs. They fire themselves."
      fades in below the score and does not sit under the thumb or the stick.
- [ ] 2. The line goes away when the first orb is collected, or after about 8 s.
- [ ] 3. Pause and Resume during the first run does not show the line again.
- [ ] 4. The first run's swarm feels gentler than a normal run at the same time in. Judge
      whether 0.5× (`EnemySwarm.GENTLE_RAMP_RATE`) is right; say a number if not.
- [ ] 5. After the first death, the second run has no hint and the normal ramp.
- [ ] 6. Your existing A55 save (best score above 0) never shows the hint.

## MVP Week 1 — Android back button and focus loss (2026-09-29)

Resolves M11a Q3 (items 10 there and 9 under M11b). On the A55, with the back gesture:

- [ ] 1. Menu, nothing open: back leaves the app. Reopen: the save is intact.
- [ ] 2. Menu → Settings: back closes Settings only. Settings → Reset → back closes both.
- [ ] 3. Menu → Calibrate: back cancels it and returns to the menu.
- [ ] 4. Menu → Milestones, then Armory over a paused run: each back closes one layer.
- [ ] 5. In a run: back pauses (the sheet appears); back again resumes. Not a quit.
- [ ] 6. During the cold open: back skips it.
- [ ] 7. On the game-over sheet: back does nothing.
- [ ] 8. In a run, pull down the notification shade, or press Home: the run is paused when
      you return, and does not resume by itself.

## MVP Week 1 — haptics (2026-09-29)

Code-complete; nothing here has run on a phone. The pulse lengths (`Haptics.NUKE_MS` 120,
`DEATH_MS` 250, `CLOSE_CALL_MS` 30) are first guesses: tune them by feel and edit the
constants. The export preset now has `permissions/vibrate=true`; this needs a fresh APK.

- [ ] 1. Settings → Audio shows "Vibration", on by default.
- [ ] 2. In a run, a nuke pickup gives a medium buzz, the last life lost a longer one, and a
      close call ("CLOSE CALL!") a light tick. A hit with lives left gives none.
- [ ] 3. Turn Vibration off: none of the three buzz. Close and reopen the game: still off.
- [ ] 4. The ticks do not feel like noise in a busy swarm (many close calls in a row). If
      they do, say so; the fix is a cooldown.

## MVP Week 1 — AAB and the upload key (2026-09-29)

`tools/release.sh` builds a Play bundle with `PERIL_AAB=1` (it flips the preset's
`export_format` to AAB for that run only). A dev-key AAB was exported and checked
(`jar verified`; the cert-chain warning is expected for a self-signed key). The real
upload key exists now (interim, see item 1).

- [x] 1. Done 2026-09-29: `tools/make-upload-key.sh` wrote `~/.android/peril-upload.keystore`
      and `peril-upload.env` (a throwaway-password interim key; replace at deployment).
      Upload-key SHA-1: `32:90:37:AE:42:0E:42:95:84:D2:2B:16:C5:F6:27:28:3E:1B:CE:8D`.
      An AAB signed with it exported and `keytool -printcert -jarfile` shows that SHA-1.
- [ ] 2. Copy both files somewhere off this machine (a password manager or a drive).
      Losing the key means a reset request to Google.
- [ ] 3. Add the printed upload-key SHA-1 to the Firebase app (R6 part B) when you do that.
- [ ] 4. When the Play Console app exists, upload
      `PERIL_AAB=1 PERIL_KEYS=~/.android/peril-upload.env tools/release.sh` output and
      accept Play App Signing when it asks.

## MVP R6 — analytics and crashes (2026-09-29)

Step 1 (the facade) is code-complete; nothing here has run on a phone. Part A is code-only
checks; Part B is your Firebase setup, which blocks spec §6 steps 3-4 (the plugin and the
test crash). Spec: `docs/superpowers/specs/2026-09-29-analytics-crashes-design.md`.

### Part A — the Settings toggle

- [ ] 1. Settings → Data shows "Share anonymous usage data" above Reset progress, on by
      default, and the board still fits on the A55 and the tablet (scrolls or fits; nothing
      is cut off). Turn it off, close and reopen the game: it stays off. Settings → Reset
      progress keeps it off.

### Part B — Firebase setup (you do this once; it unblocks the plugin work)

Nothing in the game changes until this is done. Do it in a browser, no code.

- [ ] 2. Create a Firebase project at console.firebase.google.com (any name, e.g. "Peril
      Point"). Leave Google Analytics **on** when it asks; pick or create an Analytics
      account. Default data-sharing settings are fine.
- [ ] 3. In the project, **Add app → Android**. Package name must be exactly
      `com.jtg.perilpoint`. Nickname optional. Skip the "SHA-1" box for now; add them in 4.
- [ ] 4. Project settings → Your apps → the Android app → **Add fingerprint**, once per key.
      Register these two now (read from your local keystores on 2026-09-29):

      | Key | Used by | SHA-1 |
      |---|---|---|
      | Godot debug key (`androiddebugkey`) | the A55 build | `32:B2:72:54:90:D5:C6:17:4E:4E:D5:65:B1:2E:C9:BC:19:C2:65:AD` |
      | `peril-dev-release.keystore` (alias `perildev`) | the tablet build, `tools/release.sh` default | `67:3D:0C:8F:C9:C5:6E:B3:F9:C5:1E:A8:29:E2:C5:12:B8:E3:95:3B` |

      Two more come later, not now: the Play **upload key** (when you make it, replacing the
      throwaway dev key) and Google's **app-signing key** (Play Console → Setup → App
      signing, once the app is created). A key that is missing here silently drops that
      build's reports.
- [ ] 5. **Download `google-services.json`** from that page (step 1 of the console's Android
      wizard, or Project settings → Your apps). Save it as
      `godot/android/build/google-services.json`. That path is git-ignored; it is not a
      secret, and whether to commit it is your call.
- [ ] 6. Firebase console → Build → **Crashlytics** → Enable. It will wait for a first
      crash; that comes at spec §6 step 4.
- [ ] 7. Tell the next session "Firebase done". It then does spec §6 step 3: it checks which
      Firebase plugin is maintained for Godot 4.7 (or writes a small Kotlin one), wires the
      Gradle and Crashlytics plugins, and installs on the A55 to watch DebugView
      (`adb -s RRCXB04L8EJ shell setprop debug.firebase.analytics.app com.jtg.perilpoint`).
- [ ] 8. EEA/UK consent: nothing to do yet. Until the UMP dialog lands (MVP R1) collection
      is planned to be off on the EEA path; the Play Data safety form must match the
      Settings toggle (analytics collected, optional).

## MVP Week 1 — mode names (2026-09-29)

1. [ ] The menu cards, Pause, Run over and the in-run banner say Survival, Corridor and Overdrive (no Standard, Gauntlet or Code Red).
2. [ ] Goals: "Overdrive Champion", "Corridor Runner" read right, and an old save keeps its progress on them.

## Theme R1 — ten new arena themes and enemy skins (2026-09-29)

Armory → Arena tab; the carousels now hold 16 each. Buying needs points (arena 1400/1600,
skin 1600/1800), so grant yourself points or play first.

1. [ ] Each new arena reads as its own place: Arctic Lattice, Ember Ruins, Neon Tokyo Night,
   Deep Ocean, Desert Signal, then Perlas Archipelago, Rising Sun, Carnaval, Liberty Grid,
   Black Forest. Grid lines and the boundary are visible on the A55.
2. [ ] Each new enemy skin is readable in a run and its pattern shows on the dots (rays,
   rings, stripes or blossoms), not a blur, at the in-game dot size.
3. [ ] The flag pairs look like the country's colours without drawing a flag.
4. [ ] Prices feel right against the run payout.
5. [ ] The pager says "n / 16", wraps both ways, and an old save keeps its owned items.

## Theme R2 — arena patterns and motion (2026-09-29)

Armory → Arena tab, buy or browse each theme; the preview shows the effect too.

1. [ ] Each arena is recognisably its own place in a run (not just a colour): Void Vector
   plain, Synthwave sun, Nebula stars, Matrix code rain, Supernova heat, Blueprint drafting
   lines, Arctic snow, Ember sparks, Neon rain, Deep Ocean bubbles, Desert sand, Perlas rays,
   Rising Sun ripples, Carnaval diagonal bands, Liberty Grid stars and bars, Black Forest bands.
2. [ ] Enemies, orbs and coins stay easy to read over every effect (say which is too busy).
3. [ ] No stutter with an effect on: `SERIAL=RRCXB04L8EJ tools/frametime.sh` mid-run in a busy
   theme (Matrix, Neon, Snow), compare with Void Vector.
4. [ ] The Armory preview shows the same effect at a readable size.
5. [ ] Anything to strengthen, tone down or swap before phase 2 (grid line styles).

## Settings scroll (2026-09-29)

1. [ ] Menu → Settings on the A55: drag up from anywhere (including on a switch) and the board
   scrolls; "Share anonymous usage data" and "Reset progress" are reachable.
2. [ ] Toggling a switch near the bottom does not jump the board back to the top.
3. [ ] Landscape on a smaller phone or the tablet still shows everything (scroll if it does
   not fit).
4. [ ] The Touch and Tilt cards read "Drag anywhe…" and "Tilt the…" (clipped); say if you want
   that fixed.
