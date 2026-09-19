# Tilt to Live — "Modern Space" redesign plan

Status: **plan + reference implementation exist; nothing has been applied to this folder.**
A working implementation was built in a scratch copy and verified (`tsc --noEmit` clean,
`vite build` clean, screenshots captured). This document is the plan of record so the
work can be reviewed, adjusted, or executed here.

Companion design canvas: 17 artboards covering the system, the audit, the copy table and
every screen at desktop and phone width.

---

## 1. Why the current build reads as machine-made

Three tells do most of the damage. Everything else is downstream of them.

1. **Everything glows at once.** Cyan bloom sits on the title, the buttons, the mode
   cards, the badges, the HUD pills and the panel borders. When every element emits
   light, none of them are emphasis — and uniform neon-on-black is the most
   recognisable generated look there is.
2. **Threat red is also brand red.** Enemies are red dots. So is the Code Red badge,
   the game-over score, the `--blood` token and the danger framing. The colour that
   means "you are about to die" is spent on decoration.
3. **Ampersand titles everywhere.** *Armory & Upgrades*, *The Armory & Vault*,
   *Game Options & Settings*, *Steering Sensitivity & Cursor Responsiveness*,
   *Audio & Soundtrack*, *Visuals & Accessibility*. Pairing two nouns with an
   ampersand is the loudest copy tic in the build.

### The full audit — 19 findings

Ordered by cost to the player.

| # | Finding | Kind |
|---|---|---|
| 1 | Everything glows at once (above) | Visual |
| 2 | Threat red is also brand red (above) | Visual |
| 3 | Ampersand titles everywhere (above) | Copy |
| 4 | Every item explains itself three times — a mode card carries a badge, a tagline, a 25-word description, a multiplier and a "SELECT MODE" footer | Copy |
| 5 | The milestone rail never leaves — a 240px panel covers the left fifth of the arena during play, in a game whose entire subject is reading incoming dots | Layout |
| 6 | The HUD collides with itself — score overlapped by the multiplier pill, "Best 0" clipped behind it, and a mode banner painted over the spawn area | Bug |
| 7 | The armory tab bar overflows — "Controls & Spee…" is cut off at 1280px | Bug |
| 8 | The vault number scales with its value — 2 points renders ~60px in red, 1,200 renders small in gold | Bug |
| 9 | Dying sends you shopping — the glowing gold Armory button is primary, "Play again" is a grey ghost | Flow |
| 10 | Milestones have four front doors — stat bar, sidebar, Trophy Catalog link, menu button, death screen | Flow |
| 11 | One currency, five names — Vault, PTS, Milestone Points, Points Earned, Vault Balance | Copy |
| 12 | Mode names hide the difficulty — the middle card is the hardest and the multipliers don't sort | Flow |
| 13 | Emoji standing in for an icon set — ⚡🏆⚙️🎯📱 alongside ◈★▶✕ | Visual |
| 14 | Mono type carrying paragraphs — DM Mono at 11–13px setting two-sentence explanations | Visual |
| 15 | Dead status footers — "SELECT MODE" / "● ACTIVE MODE" restating what the border says | Layout |
| 16 | The launch button says the thing twice — "ENTER THE ARENA" over "LAUNCH CLASSIC SURVIVAL" | Copy |
| 17 | First run is a wall of zeroes — Best 0 · 0/36 · 2 PTS plus three empty bars | Flow |
| 18 | Accessibility filed under Visuals — the settings that decide whether the game is playable sit below audio | Flow |
| 19 | Mobile controls are text buttons — "Sound on", "II", "Home" below a 44px touch target | Layout |

Findings 6, 7 and 8 are rendering bugs visible in the current screenshots, not opinions.

---

## 2. The system

### Non-negotiable rules

1. Hazard red `#FF4757` is for enemies and death only. Never on chrome — no red badges,
   no red mode names, no red score, no red panel borders.
2. No glow on UI chrome. No coloured `box-shadow`, no `text-shadow`, no `drop-shadow`
   on any menu/HUD/modal element. The only permitted shadow is
   `0 32px 80px rgba(0,0,0,0.6)` on modals. Bloom belongs to canvas-drawn things —
   the ship, live weapons, threats.
3. No emoji. Inline 1.5px stroke SVG at 14–16px, or nothing.
4. No title joins two nouns with an ampersand.
5. Monospace for numerals only, always `tabular-nums`. Prose uses the sans stack.
6. Touch targets ≥44px (46px on phone).
7. Presentation only — no change to gameplay, timings, physics, scoring, `localStorage`
   keys or `GameMode` ids.

### Tokens

```css
--void:      #08090E;   /* page ground, menu panel      */
--arena:     #0D1016;   /* canvas ground                */
--panel:     #141821;   /* cards, rows, surfaces        */
--panel-2:   #1B2029;   /* raised: active tab, selected */
--panel-3:   #12161F;   /* modal body                   */
--line:      #262C38;   /* hairline borders             */
--line-hi:   #3A4252;   /* secondary button borders     */
--text:      #E6E9F0;
--text-2:    #C7CDDB;
--text-3:    #99A1B3;
--text-4:    #7A8397;   /* labels, min 11px             */
--text-5:    #4A5264;   /* hints only                   */
--ion:       #5B8CFF;   /* primary accent, player       */
--ion-soft:  #8FB0FF;
--ion-wash:  rgba(91,140,255,0.12);
--ion-edge:  rgba(91,140,255,0.45);
--flare:     #FFB14D;   /* points / currency ONLY       */
--plasma:    #A78BFA;   /* rare / one-off unlocks       */
--ok:        #3DDC97;   /* equipped, completed          */
--hazard:    #FF4757;   /* ENEMIES AND DEATH ONLY       */
--radius-s: 3px; --radius: 4px; --radius-l: 6px; --radius-xl: 10px;
```

Keep the legacy names (`--ink --paper --muted --blood --gold --neon-cyan --neon-mint
--neon-orange --border`) as aliases onto the new palette so nothing breaks mid-migration.

### Type

Replaces Unbounded + DM Mono.

```html
<link href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@100..125,400..800&family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600&display=swap" rel="stylesheet">
```

- **Archivo** (`font-stretch: 112%`, 118% for the wordmark), weight 700 — screen titles
  and the wordmark, nothing else.
- **IBM Plex Sans** — every label and sentence.
- **IBM Plex Mono** — every numeral, tabular. Uppercase + tracking only on 10–11px mono
  micro-labels; never on a button or a sentence.

### Components

- **Primary button** — `--ion` fill, `--void` text, no border, 54–60px tall, weight 600.
- **Secondary** — transparent, `1px solid --line-hi`, `--text-2`.
- **Ghost** — transparent, no border, `--text-3`.
- **Card** — `--panel` on `1px solid --line`, `--radius-l`. Selected swaps to
  `--panel-2` + `--ion` border.
- **Points value** — always `--flare`, mono, tabular, **fixed size** (15px in headers,
  17px on the menu stat row). Never scales with the value. This is the fix for finding 8.
- **Switch** — 44×26 pill, knob as `::after`, `--ion` when on.
- **Focus** — `outline: 2px solid var(--ion-edge); outline-offset: 3px`. Never removed.

---

## 3. Layout changes

### In-run HUD
- Top-left: score at 52px mono, then one 12px mono line `BEST 32,420 · Standard`.
- Multiplier chip sits **below** the score block, visible only when > 1. Never overlaps.
- Top-right: exactly two 44px icon buttons — Pause, Quit. Sound, calibrate and the
  armory shortcut move into the pause overlay.
- **Delete the centre-of-arena mode banner.** Nothing is painted over the playfield.
- Shield: bottom-centre, 240px × 3px bar with a `Shield 1.6s` label.
- Milestone toast: bottom-left, tick + name + points, auto-dismiss.

### Milestone rail
During a run the sidebar collapses to a **4px vertical rail** pinned to the left edge —
overall completion with segment ticks, no text, no cards, no playfield width taken. The
full list lives on the menu and in the Milestones modal only.

### Menu
Left panel (576px desktop, full width under 900px) over the live arena: wordmark,
one subtitle line, three compact mode rows, a `Play` button, three quiet text links
(Armory / Milestones / Settings), then a bottom stat row (BEST / POINTS / MILESTONES).

Mode rows are compact — a 3px colour rail, name + multiplier on one line, a one-liner
under it, a radio dot on the right. No badges, no paragraphs, no footers.

**Modes reorder by ascending multiplier** so difficulty sorts: Standard 1.0× →
Gauntlet 1.25× → Code Red 1.5×. Mode colours become ion / flare / plasma. Code Red is
not red — that colour belongs to the enemies.

**First run** (best 0, no milestones): hide the stat row, show
`First milestone at 1,000 points`.

### Armory
Full-screen shell, not a nested modal. Header row: title, four tabs, points, close.
Tabs become `Weapons` / `Ships` / `Arena` / `Handling` — sentence case, no icons,
cursors and enemy skins folded into Arena, fits 1280px.

- **Weapons** — 300px left list (name + rank), main pane with upgrade rows: name +
  short effect, 5-pip meter, `n/5`, cost button. One-off unlocks in a two-up grid below.
- **Ships** — 3-column cards: silhouette plate, name + trait, Hitbox and Turn bars,
  one action button (`Equipped` / `Equip` / `<n> pts`).
- **Handling** — two sliders (Turn rate, Deadzone) with a preview panel and one `Reset`.

### Death screen
Score in `--text` at 68px mono — never red. Under it, `Swarmed at 1:42 — Standard`.
A `New best — up N` banner when earned. A three-cell stat strip: Kills / Best chain /
Alive. One points line: `Points earned  +3,331 → 7,331`.

**Retry is the primary button and takes focus. Space retries.** Menu and
`Spend <balance>` sit below it as a secondary row. This inverts the current flow, where
the gold Armory button is primary.

### Settings
Sections reorder to **Readability → Controls → Audio**, because readability is what
decides whether the game is playable. Real switch controls replace ENABLED/MUTED text
buttons. Control schemes become `Mouse` / `Keys` / `Both` / `Tilt` with mono sub-lines,
mapped to the unchanged stored values.

### Cold open
Cut the letterboxed cinematic and all of its copy (`RED DOT FLEET INCOMING // SECTOR 01`,
`SPACE INVADERS DETECTED`, `TILT TO SURVIVE`, `Space or Tap to Skip`). Replace with a
600ms hold on the wordmark, cut short by any input. Keep the skip/timeout plumbing.

### Mobile (≤640px)
Menu stacks full width, 24px gutters, 46px targets. HUD score 34px, two 46px icon
buttons, 180px shield bar. **Death screen becomes a bottom sheet** so Retry sits under
the thumb. Armory goes single column with a scrollable tab row.

---

## 4. Copy

Roughly 1,100 words of interface copy down to under 300. Three rules produced all of it:
no ampersand titles; no description that restates the number; no word the player
wouldn't say out loud — no *salvation*, *relentless*, *definitive*, *hyper-lethal*.

| Current | New |
|---|---|
| `HYPER-NEON BULLET DODGE ARENA` | cut |
| `Weapons are your only salvation. Steer with WASD or mouse to survive relentless red dot swarms.` | `Move to dodge. The guns fire themselves.` |
| `SELECT GAME MODE` | cut |
| `ENTER THE ARENA` / `LAUNCH CLASSIC SURVIVAL` | `Play` |
| `The Armory & Vault` / `Armory & Upgrades` | `Armory` |
| `Game Options` / `Game Options & Settings` | `Settings` |
| `Milestone Trophies` / `Trophy Catalog →` | `Milestones` |
| `Classic Survival — The Definitive Arcade Arena — Dodge escalating swarms, detonate superweapons…` | `Standard — 1.0× — The full arsenal, ramping swarms.` |
| `Code Red — Instant Hyper-Lethal Swarms — 2x initial swarm density…` | `Code Red — 1.5× — Double density from the first second.` |
| `The Gauntlet — Descending Maze & Survival Rush — Navigate descending wall barriers…` | `Gauntlet — 1.25× — Walls close in while you dodge.` |
| `Run terminated` / `Swarmed by red dots` | one small line under the score |
| `Dots Destroyed` / `Max Multiplier` / `Survival` | `Kills` / `Best chain` / `Alive` |
| `POINTS EARNED +3,331 PTS` / `Vault: 7,331 PTS` | `Points earned  +3,331 → 7,331` |
| `Paused` / `The swarm waits` | `Paused` |
| `Singularity Blackhole` | `Blackhole` |
| `Spawn gravity wells that suck red dot swarms into event horizons and implode.` | `Drags dots in, then collapses.` |
| `Event Horizon Radius` — `+35px gravitational capture range per rank` | `Radius` — `+35px / rank` |
| `Gravitational Force` — `+20% pull acceleration towards center per rank` | `Pull` — `+20% / rank` |
| `★ Event Horizon Aegis (Invulnerability)` | `Aegis` — `You are safe inside the well.` |
| `★ Supernova Collapse` | `Supernova` — `Collapse fires a 420px shockwave.` |
| `Rank 1 • ◈ 400` | `400 pts` + a separate `1/5` |
| `Piloting ✓` | `Equipped` |
| `Classic Arrow — The iconic high-agility white arrow craft with aerodynamic delta wings…` | `Arrow — Balanced` |
| `Solar Aegis — Heavy reinforced warship chassis encased in polished 24K gold armor plates…` | `Aegis — Heavy` |
| `Steering Sensitivity & Cursor Responsiveness` | `Handling` |
| `Cursor Steering Responsiveness / Speed` + two sentences | `Turn rate` — `Higher turns sharper.` |
| `Center Resting Deadzone` + two sentences | `Deadzone` — `Stops drift when you hold still.` |
| `Targeting Tether Line` | `Aim line` |
| `High-Contrast Dot Halo` | `Enemy outlines` |
| `Background Vector Grid` | `Background grid` |
| `↺ Reset to Defaults (1.0x / 4px)` | `Reset` |
| `ENABLED` / `MUTED` / `DISABLED` | a switch |

One currency name everywhere: **Points**, unit `pts`. The `◈` glyph is deleted.

---

## 5. Work breakdown

Five parallel tracks over non-overlapping files, then a stylesheet pass, then cleanup.
Two contracts make the parallelism safe and must hold in any re-run:

- **No existing element `id` is renamed or removed.** Elements may move between
  containers but keep their id. `TiltGame`, `GoalsHUD` and `ArmoryUI` look them up.
- **Every agent reports the CSS classes its markup emits**, so the stylesheet can be
  written from the union of those reports rather than guesswork.

| Track | Files | Work | Status |
|---|---|---|---|
| A — Shell | `index.html`, `GoalsHUD.ts` | Font link, HUD restructure, pause rebuild, death-screen rebuild, cold open, 4px rail | Done in scratch copy |
| B — Menu | `TiltMenu.ts`, `GameOptions.ts` | Menu rebuild, mode reorder + recolour, settings modal reorder | Done in scratch copy |
| C — Armory | `ArmoryUI.ts`, `ProgressionManager.ts` | Four-tab shell, weapons/ships/handling panels, all catalog copy | Done in scratch copy |
| D — Runtime | `TiltGame.ts`, `TiltRenderer.ts`, `TiltEntranceCinematic.ts` | Wire new ids, kill the arena banner and canvas chrome, Space-to-retry, palette | Done in scratch copy |
| E — Stylesheet | `game.css` | Full rewrite against the four class reports; dead-rule deletion; responsive | Done in scratch copy |
| F — Cleanup | palette stragglers + polish | **Not started** — see below |

### New ids track D wires (all null-guarded)

```
tilt-hud-mult          multiplier chip, hidden when mult <= 1
tilt-shield-wrap       shield readout container
tilt-shield-label      "Shield 1.6s"
tilt-shield-fill       bar fill (width set inline by script)
tilt-gameover-sub      "Swarmed at 1:42 — Standard"
tilt-gameover-best     "New best — up N", hidden unless earned
btn-tilt-restart-pause  "Restart run" in pause
btn-tilt-music-pause    music switch in pause
btn-tilt-settings-pause link to settings from pause
```

### Three wiring bugs the rebuild must fix

1. `updateHUD()` overwrites `#tilt-mode-badge`'s whole `className`, clobbering its
   styling class. Set `textContent` and toggle a single `mode-<id>` modifier instead.
2. The sound button is toggled with `btn.textContent = 'Sound on'`, which would wipe a
   switch knob. Toggle `aria-checked` and an `is-on` class; leave `textContent` alone.
3. Null-guard every `getElementById` for elements that may now be hidden or absent.

---

## 6. Remaining defects (track F)

Found by inspecting the rendered result. Everything here is inside the reference
implementation, not the current build.

1. **The arena is framed in bright glowing cyan.** `TiltRenderer` defaults the boundary
   to ion, but `arenaTheme.boundaryColor` overrides it and the default theme in
   `ProgressionManager` is still cyan. Retune the arena-theme catalog; keep every theme
   id, price and unlock rule.
2. **The player ship renders teal, not ion blue.** `PlayerShip.ts`, `ProgressionManager`
   ship skins and SVG previews, `WeaponSystem.ts`, `ScoreManager.ts` and
   `GauntletMaze.ts` still carry `#00ddff` / `#00ffee` / `#00ffaa` / `#00ffcc` /
   `#ffd700`. Map to `#5B8CFF` / `#8FB0FF` / `#3DDC97` / `#FFB14D`. Colour only.
3. **Cost buttons read `1 pts`.** Use the singular at exactly 1.
4. **The menu milestone list floats unanchored** mid-right of the arena. Anchor it with
   a consistent offset and max width; move or hide it below 900px.
5. **Empty rank pips are too faint** to read as an empty slot.
6. **The `New best` banner is ion blue**; it is a reward signal and should be `--flare`.
7. **The in-run rail fills from an odd offset** — it should anchor at the top and grow
   downward.

### Known judgement calls carried in the reference implementation

- `screenShake` now offers Off / Low / Full (mapping to `off` / `low` / `normal`);
  a stored `extreme` displays as Full and normalises when re-picked.
- Ship Hitbox/Turn bars are **decorative** — no per-ship stats exist in the codebase.
  Either wire them to real values or drop them.
- `renderInGameHUD()` was deleted from `TiltRenderer` along with the mode banner: it
  drew a multiplier badge, a kills readout and a shield bar that are now DOM elements,
  in fonts the page no longer loads. Worth a second look.
- The Settings modal flips `sfxEnabled` / `musicEnabled` but never applied them to the
  audio engine; the rebuild reconciles this each tick. The underlying bug is still in
  `TiltMenu.openOptionsModal`.

---

## 7. Verification

1. `npx tsc --noEmit` — clean.
2. `npx vite build` — clean.
3. Grep: no `#FF4757` outside the token definition and the crimson enemy-skin swatch;
   no coloured `box-shadow` / `text-shadow` / `drop-shadow` on chrome; no `#00ddff`,
   `#00ffee`, `#00ffaa`, `#00ffcc` or `#ffd700` anywhere in `src/`.
4. Screenshot at 1440×900 and 390×844: menu, in-run HUD, game over, pause, and the
   armory weapons / ships / handling tabs. Check for overlap, clipping, contrast and
   overflow — findings 6, 7 and 8 were all caught this way.
5. Play a run end to end: cold open → HUD → pause → death → Retry via Space.

---

## 8. Applying this

The reference implementation lives in a scratch copy in the session workspace, not in
this folder. Nothing here has been modified. To proceed, either:

- have the changed files written into this folder (`index.html`, `src/styles/game.css`,
  and eight files under `src/tilt-to-live/`), with track F still outstanding; or
- treat this document as the brief and implement it here directly — Claude Code can read
  and write this folder normally.

A note on the current session: a Windows update from 8 September blocks the workspace
shell from mounting this folder, so files can only be read and written one at a time
through the file bridge. Claude Code is unaffected.
