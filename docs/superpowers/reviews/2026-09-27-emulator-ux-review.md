# Emulator play review: flaws and UI/UX (2026-09-27)

Build: debug APK of `e9eb79c` (arm64, running under ARM translation on the
x86_64 `sdk_gphone16k` emulator at 2424×1080, Vulkan through gfxstream). Driven by
`adb input` taps and swipes, with screenshots. Caveats: emulator input lags by
roughly 1 s, there is no tilt, and performance was not measured. Nothing here is
fixed yet; each item needs a ruling (fix, or keep as a TS-faithful port).

Side effect: one test tap bought Blackhole Duration rank 4 on the **emulator** save
(7,331 → 5,531 pts). The A55 save is untouched.

## Flaws (ranked)

1. **Entities draw over the HUD.** In a run, enemy dots sit inside the score
   digits, on "BEST 590" and on the SHIELD label and bar. On the menu, attract-mode
   enemies (a whole wall formation) cross the tagline "Move to dodge…" and make it
   unreadable, and faint dots bleed behind the right-hand mode column. The HUD and
   menu text need to sit above the entity layer, or the attract layer needs dimming.
2. **The Handling live preview draws the ship black.** It is almost invisible on
   the dark preview (Armory → Handling). The drag target is a 2 px blue dot.
3. **The HUD hides part of the playfield.** The ship can fly under the pause button
   and the score. I died in the top-right corner, hidden behind the pause button.
   The ship's nose also crosses the arena frame line at the top edge.
4. **Close-call popups are unreadable.** "CLOSE CALL! +1250" is about 12 px tall,
   green, and drawn over the ship; at the top-right it clips off-screen.
5. **The run payout reads "+0 → 5,531".** It showed after a 590-score, 8-kill run,
   with no hint of how score converts to points. A zero payout with no explanation
   feels broken.
6. **A new player dies at 0:03.** The ship spawns overlapping the crimson nuke orb,
   which uses the enemy palette and reads as an enemy. The 8-seeker ring closes in
   right after the 2.5 s shield ends, so an idle first-timer is dead at 0:03 (my
   first run).
7. **Touch drag gain is high.** A 300 px drag took the ship across most of the
   arena and pinned it to an edge. Re-check on the A55, since emulator lag may
   exaggerate it.
8. **Armory purchases give no feedback.** No flash, sound cue or toast; the tab
   rebuilds and the weapon list **jumps back to the top**. A maxed stat (Missiles
   5/5) has no "MAX" state.
9. **The mode banner is developer-speak and overlaps things.** "STANDARD 1.0X SCORE
   // THE NEON ARENA" sits over the multiplier chip and the orbs for about 3 s.
10. **Text truncates.** "Double density from the first seco…" (menu, Code Red) and
    "phone gyrosc…" (Settings, Tilt).
11. **Settings header is out of line.** It sits about 10 px higher (y≈72) than the
    Armory and Milestones headers (y≈83), so the back button jumps between screens.

## FPS under load (emulator, Code Red)

To reach high enemy counts, a **temporary, uncommitted** debug APK skipped
`lose_life` (reverted right after export). A bot steered in loops for about 3 min.
The emulator runs the arm64 build under translation: per enemy it is about 3.4×
slower than the A55 (A55: 7.1 ms entity draw at 100+ enemies; emulator: about
0.24 ms per dot). **Absolute fps here is pessimistic; the proportions are what
carry over.** PERF averages per bucket:

| enemies | fps | sim steps/s (of 120) | d_entity ms | phys ms | s_swarm ms | draws |
|---|---|---|---|---|---|---|
| <50 | 35.5 | 119 | 8.3 | 8.2 | 1.9 | 227 |
| 50–99 | 18.8 | 108 | 32.6 | 20.6 | 10.4 | 407 |
| 100–149 | 9.0 | 72 | 70.7 | 34.3 | 20.0 | 572 |
| 150+ | 5.4 | 43 | 127.9 | 58.6 | 43.8 | 1,126 |

Findings:
1. **Entity draw is about two thirds of the frame at every load.** Scaled to the
   A55 (÷3.4), 187 enemies would be about 30 ms of draw plus about 10 ms of swarm:
   roughly 20–25 fps.
2. **Wall formations double the count at once.** En went 102 → 181 within one
   second (one wall is about 80 dots). This is the reported "formation spike": a
   sustained load, not a one-tick cost. The A55 pass had only 3 s above 100
   enemies and never measured a wall on top of a late swarm.
3. **The run turns into slow motion when frames are long.** Godot's 8-steps-per-frame
   ceiling holds the sim to 43–72 of 120 steps/s at 100+ enemies, so the game runs
   at 35–60% speed (P2's catch-up cap was withdrawn; this is the engine's own cap).
4. **The non-dot enemies still use `draw_circle`/`draw_arc`.** In `entity_layer.gd`:
   carrier satellites (3 calls each, 4 per carrier), pulsar, specter, bullet,
   artillery, coins, weapon orbs. Dashed aim lines issue one `draw_line` per dash,
   and `_draw_dashed_arc` one `draw_arc` per dash. Carriers and artillery are
   common late (see the 150+ screenshots).
5. **The death tick hitches.** `s_collide` peaks at 36–45 ms on the death tick
   (maxsteps 6–8 that second), from finalize, `evaluate_run` and the save.
   About 12 ms on the A55: one visible hitch as the run ends.
6. **The first run frame spikes.** `d_entity` max 25.6 ms with `en=0` on the
   cinematic handover (first use of textures?). The reviewer's pre-warm idea
   applies here.
7. Smaller costs at 150+: `s_particles` 2–5 ms, `s_goals` about 2.3 ms per frame (P7).

Candidates for a ruling (not started): MultiMesh or batched sprites for all dot-like
enemies (spec §9; removes about 7 canvas commands and the per-dot GDScript for each
dot); move the remaining enemy and pickup circles to `CircleSprites`; one
polyline per dashed line; defer the save off the death tick; pre-warm the circle
textures at boot.

## UI/UX improvements

**Menu**
- The right column has a large dead gap between Code Red and Play.
- Multipliers mix precision: "1.0×" vs "1.25×" / "1.50×". Use 1.00× for all.
- The NEXT goal bar has no number (e.g. "best 590 / 1,000").
- Steer Touch/Tilt: the selected state is only a slightly lighter fill; use the
  accent colour. The calibrate icon button has no label.

**Armory**
- Price buttons have no verb or unit ("1,800" rather than "Upgrade · 1,800 pts"),
  and there is no visible can't-afford state.
- Price styling differs across tabs: blue buttons (Weapons, Ships, Boosts) vs
  orange text (Arena).
- Boosts cards have no title and no rank number: just mono effect text plus bars.
- The arena theme previews are near-identical dark grids; show the theme's
  background and dot colours.
- The Ship "Aegis" and the Blackhole perk "Aegis" share a name.
- Ships: "Starts with ✳Shockwave" has no icon gap, and the equipped card's top
  border is clipped by the scroll view.
- Handling: slider fills are grey while the values are accent blue, and the
  0.5×/2.0× range labels float closer to the next heading than to their own slider.
- The weapon perk cards (Aegis, Supernova) do not show owned or locked.

**Milestones**
- The rewards "+1 / +2 / +5" have no unit, next to prices in the thousands.
- The cards are tall: 4 of 57 fit on screen. Show per-goal progress.
- The empty checkboxes look tappable.

**Settings**
- Reset progress is not styled as destructive (no red, no confirm hint visible).
- The "Turn rate and sensitivity live in Armory › Handling" link wraps, leaving
  "Handling" alone on the next line. Make it a button.
- Sound and Music are on/off only; there are no volume sliders.

**Run over**
- The right column is mostly empty space. Use it for "You can afford: Blackhole
  Radius 1,100", or for goal progress.
- The time is shown twice ("Swarmed at 0:13" and "0:13 ALIVE").
- "New best — up 250" on a first run (from 0) reads oddly.

**Pause**
- The subtitle "0 · 0:01 · Standard" is cryptic: label the score.
- There is no resume countdown.

**HUD**
- "BEST 590" does not change when the current score beats it mid-run.
- An unlabeled purple icon sits next to the score (the active weapon?).
- The multiplier chip ("5×", dark orange on brown) has low contrast.
- Coins are tiny next to the other orbs.

**Cold open**
- The glyph is a flat right-pointing triangle, not the equipped ship (the Arrow
  points up in-game).
