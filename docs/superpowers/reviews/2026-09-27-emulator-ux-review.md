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
