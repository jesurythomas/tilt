# Tilt to Live — "Modern Space" redesign spec (v2)

Every agent working on this redesign MUST follow this file exactly. It is the single
source of truth for tokens, class names and copy. Do not invent alternatives.

## 0. Non-negotiable rules

1. **Hazard red `#FF4757` is for enemies and death only.** It must not appear on any
   chrome: no red badges, no red mode names, no red score, no red borders on panels.
2. **No glow on UI chrome.** No `box-shadow` with a colored spread, no `text-shadow`,
   no `filter: drop-shadow` on any menu/HUD/modal element. Bloom is reserved for
   canvas-drawn things (ship, weapons, threats) which live in TiltRenderer, not CSS.
   The only shadows allowed in CSS are neutral black drop shadows on modals:
   `box-shadow: 0 32px 80px rgba(0,0,0,0.6)`.
3. **No emoji anywhere in the UI.** Replace every emoji with an inline SVG icon
   (see §4) or with nothing.
4. **No title joins two nouns with an ampersand.** One noun per screen.
5. **Monospace is for numerals only.** All prose uses the sans stack.
6. All interactive targets are >= 44px tall (46px on mobile breakpoints).
7. Do not change gameplay behaviour, timings, physics, scoring or persistence keys.
   This is a presentation-layer change. Renaming a *displayed* string is fine;
   renaming a `localStorage` key or a `GameMode` id is NOT.

## 1. Design tokens (defined in `src/styles/game.css` `:root`)

```
--void:      #08090E;   /* page ground, menu panel */
--arena:     #0D1016;   /* canvas ground / behind everything */
--panel:     #141821;   /* cards, rows, surfaces */
--panel-2:   #1B2029;   /* raised: active tab, selected row */
--panel-3:   #12161F;   /* modal body */
--line:      #262C38;   /* hairline borders */
--line-hi:   #3A4252;   /* secondary button borders */
--text:      #E6E9F0;   /* primary */
--text-2:    #C7CDDB;   /* secondary body */
--text-3:    #99A1B3;   /* supporting copy */
--text-4:    #7A8397;   /* labels, captions (min size 11px) */
--text-5:    #4A5264;   /* hints only, never below 11px */
--ion:       #5B8CFF;   /* primary accent: actions, player, selection */
--ion-soft:  #8FB0FF;   /* ion text on dark fills */
--ion-wash:  rgba(91,140,255,0.12);
--ion-edge:  rgba(91,140,255,0.45);
--flare:     #FFB14D;   /* points / currency ONLY */
--flare-dim: #8A7449;
--plasma:    #A78BFA;   /* rare / one-off unlocks */
--ok:        #3DDC97;   /* equipped, completed */
--hazard:    #FF4757;   /* ENEMIES AND DEATH ONLY */
--radius-s:  3px;  /* chips */
--radius:    4px;  /* controls */
--radius-l:  6px;  /* cards */
--radius-xl: 10px; /* modals */
```

Legacy tokens `--ink --paper --muted --blood --gold --neon-cyan --neon-mint
--neon-orange --panel --border` must be kept as aliases pointing at the new palette so
nothing breaks, e.g. `--neon-cyan: var(--ion); --blood: var(--hazard);
--gold: var(--flare); --paper: var(--text);`. Prefer the new names in new code.

## 2. Type

`index.html` loads exactly this stylesheet link (replacing the Unbounded/DM Mono one):

```html
<link href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@100..125,400..800&family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600&display=swap" rel="stylesheet">
```

```
--font-display: 'Archivo', system-ui, sans-serif;   /* + font-stretch: 112% (118% for the wordmark) */
--font-body:    'IBM Plex Sans', system-ui, sans-serif;
--font-mono:    'IBM Plex Mono', ui-monospace, monospace;
```

- Display face: screen titles, the wordmark, nothing else. Weight 700.
- Body face: every label and sentence.
- Mono: every numeral. Always `font-variant-numeric: tabular-nums`.
- Uppercase + letter-spacing is allowed ONLY on 10-11px mono micro-labels.
  Never uppercase a sentence or a button.

## 3. Component rules

- **Primary button**: `background: var(--ion); color: var(--void); border: none;
  border-radius: var(--radius-l); font-weight: 600;` height 54-60px desktop.
- **Secondary button**: transparent fill, `1px solid var(--line-hi)`, `color: var(--text-2)`.
- **Ghost/tertiary**: transparent, no border, `color: var(--text-3)`.
- **Card**: `background: var(--panel); border: 1px solid var(--line);
  border-radius: var(--radius-l);` Selected card swaps the border to `var(--ion)` and
  the fill to `var(--panel-2)`. No left-border accent bars except the 3px mode-colour
  rail on mode rows.
- **Chip / pill**: `--radius-s`, 11px mono, uppercase, `var(--text-4)`.
- **Points value**: always `var(--flare)`, mono, tabular, **fixed 15px** in headers and
  **fixed 17px** on the menu stat row. The size must never depend on the value.
- **Switch**: 44x26 pill, `--ion` when on, `--line-hi` + `--panel-2` when off.
- **Progress bar**: 3-4px tall, `background: var(--panel-2)`, fill `var(--ion)`.
- Focus: `outline: 2px solid var(--ion-edge); outline-offset: 3px;` — never remove it.

## 4. Icons

Delete every emoji. Where an icon is genuinely needed, inline a 1.5px stroke SVG at
14-16px using `currentColor` or an explicit token colour. The set needed:

- pause: two rounded bars
- home/quit: house outline
- close: X
- check: tick (use `--ok`)
- play: right triangle (filled)
- chevron-left: back
- gear: settings
- star: milestone (stroke, `--flare`)
- phone: tilt/gyro

Icon-only buttons need `aria-label`.

## 5. Copy — replace exactly these strings

### Menu
| current | new |
|---|---|
| `HYPER-NEON BULLET DODGE ARENA` | delete the element |
| `Weapons are your only salvation. Steer with WASD or mouse to survive relentless red dot swarms.` | `Move to dodge. The guns fire themselves.` |
| `SELECT GAME MODE` | delete the element |
| `ENTER THE ARENA` + `LAUNCH <MODE>` | a single button labelled `Play` |
| `The Armory & Vault` | `Armory` |
| `Game Options` | `Settings` |
| `Milestone Trophies` | `Milestones` |
| `BEST SCORE` / `MILESTONES` / `VAULT` stat chips | one bottom stat row: `BEST`, `POINTS`, `MILESTONES` |
| `● ACTIVE MODE` / `SELECT MODE` footers | delete the element |

### Modes (`GameOptions.ts` — keep the `id` values `classic` / `code-red` / `gauntlet`)
| id | name | tagline (becomes the one-liner) | badge |
|---|---|---|---|
| classic | `Standard` | `The full arsenal, ramping swarms.` | delete badges entirely |
| gauntlet | `Gauntlet` | `Walls close in while you dodge.` | — |
| code-red | `Code Red` | `Double density from the first second.` | — |

Drop the long `description` from the card UI (keep the field if other code reads it,
but do not render it). **Order the cards by multiplier ascending: Standard (1.0x),
Gauntlet (1.25x), Code Red (1.5x).** Mode colours become:
classic `--ion` #5B8CFF, gauntlet `--flare` #FFB14D, code-red `--plasma` #A78BFA.
Code Red must NOT be red — that colour belongs to the enemies.

### Death screen
| current | new |
|---|---|
| eyebrow `Run terminated` | delete |
| h2 `Swarmed by red dots` | a 13px line under the score: `Swarmed at <time> — <Mode>` |
| final score colour | `var(--text)`, mono, 68px. Never red. |
| `Dots Destroyed` / `Max Multiplier` / `Survival` | `Kills` / `Best chain` / `Alive` |
| `POINTS EARNED` + `Vault: N PTS` | one line: `Points earned` … `+3,331 → 7,331` |
| `⚡ Armory & Upgrades` (primary, gold) | secondary button labelled `Spend <balance>` |
| `Play again` (ghost) | **primary** button labelled `Retry`, autofocused |
| `Main Menu` | `Menu` |
| — | add a `SPACE to retry` hint, 11px mono, `--text-5` |

Button order: Retry (primary, full width) → row of [Menu] [Spend N].

### Pause
| current | new |
|---|---|
| eyebrow `Paused` + h2 `The swarm waits` | one h2: `Paused` |
| scheme description line | show only on the player's first ever run |
| `Resume` | `Resume` (primary) |
| `⚡ Armory & Upgrades` | drop from pause |
| `Main Menu` | `Quit to menu` |
| — | add `Restart run`, and Sound/Music switches, and a link to Settings |
| — | `ESC to resume` hint |

### Armory
| current | new |
|---|---|
| eyebrow `TILT TO LIVE // THE VAULT` | delete |
| `Armory & Upgrades` | `Armory` |
| tabs `WEAPON PERKS / CURSORS / ENEMY SKINS / ARENA THEMES / CONTROLS & SPEED` | `Weapons` / `Ships` / `Arena` / `Handling` — sentence case, no icons. Fold cursors + enemy skins into `Arena`. Tabs must not overflow at 1280px. |
| `Singularity Blackhole` | `Blackhole` |
| `Spawn gravity wells that suck red dot swarms into event horizons and implode.` | `Drags dots in, then collapses.` |
| `Duration` `+0.5s active pull per rank (up to +2.5s)` | `Duration` `+0.5s / rank` |
| `Event Horizon Radius` `+35px gravitational capture range per rank` | `Radius` `+35px / rank` |
| `Gravitational Force` `+20% pull acceleration towards center per rank` | `Pull` `+20% / rank` |
| `★ Event Horizon Aegis (Invulnerability)` + `Your ship gains total invulnerability while inside the blackhole!` | `Aegis` + `You are safe inside the well.` |
| `★ Supernova Collapse` + `Vortex collapse produces a devastating 420px shockwave!` | `Supernova` + `Collapse fires a 420px shockwave.` |
| `Rank 1 • ◈ 400` | `400 pts` with a separate `1/5` rank readout |
| `Piloting ✓` | `Equipped` |
| `Unlock ◈ 2,500` | `2,500 pts` |
| `Steering Sensitivity & Cursor Responsiveness` | `Handling` |
| `Cursor Steering Responsiveness / Speed` + its 2-sentence help | `Turn rate` + `Higher turns sharper.` |
| `Center Resting Deadzone` + its 2-sentence help | `Deadzone` + `Stops drift when you hold still.` |
| `0.5x (Stable)` / `2.0x (Hyper)` | `0.5x` / `2.0x` |
| `↺ Reset to Defaults (1.0x / 4px)` | `Reset` |

Apply the same treatment to every other weapon/perk in ProgressionManager: cut the
description to one short sentence (max 8 words), cut every upgrade name to one or two
words, cut every upgrade effect to the bare delta (`+20% / rank`). Strip all
exclamation marks. Ship descriptions become `<trait>` one-liners of at most 4 words
(`Balanced`, `Aggressive`, `Evasive`, `Heavy`, `Fast cooldown`, `Spin drift`).

### Settings
| current | new |
|---|---|
| eyebrow `CONFIGURATION` + `Game Options & Settings` | `Settings` |
| section `STEERING CONTROLS` | `Controls` (sentence case, 10px mono label) |
| control scheme labels | `Mouse` / `Keys` / `Both` / `Tilt` with a mono sub-line (`point to steer`, `WASD / arrows`, `whichever moves`, `phone gyroscope`) |
| section `AUDIO & SOUNDTRACK` | `Audio` |
| `Sound Effects` / `Synthwave Music` | `Sound` / `Music` |
| section `VISUALS & ACCESSIBILITY` | **`Readability`, moved to the TOP of the modal, above Controls and Audio** |
| `Targeting Tether Line` | `Aim line` + hint `Draws the line from ship to cursor.` |
| `High-Contrast Dot Halo` | `Enemy outlines` + hint `Adds a white ring to every hostile dot.` |
| `Background Vector Grid` | `Background grid` + hint `Off by default — it competes with the dots.` |
| `Screen Shake Impact` Off/Low/Normal/Extreme | `Screen shake` with `Off` / `Low` / `Full` (map Full -> the existing `extreme`? NO — map `Full` -> `normal` and drop `extreme` from the UI only if trivial; otherwise keep all four) |
| `ENABLED` / `MUTED` / `DISABLED` text buttons | real switch controls (§3) |
| `Neutral Tilt Calibration` + long help | `Calibrate` button with hint `Hold the phone how you want to hold it, then tap.` |

### Milestones
| current | new |
|---|---|
| `Trophy Catalog →` | `Milestones` |
| `View all 28 milestones` | `All milestones` |
| `Vault Balance` | `Points` |
| `Show Milestones (Click to unhide)` / `Hide Milestones` | `Show` / `Hide` |

### Cinematic
Remove the letterbox cinematic copy entirely: `RED DOT FLEET INCOMING // SECTOR 01`,
`SPACE INVADERS DETECTED`, `TILT TO SURVIVE`, `Space or Tap to Skip`. Replace with a
600ms hold on the wordmark (`TILT TO LIVE` in the display face) over the arena, which
any input cuts short. Keep the existing skip/timeout plumbing so nothing hangs.

### Global
- One currency name: **Points**. Never "Vault", "PTS balance", "Milestone Points".
  The unit suffix in running text is `pts`; a bare number is fine next to a `POINTS`
  label. The `◈` glyph is deleted.
- `1x`/`2x` multipliers render as `1.0x` etc. in mono.

## 6. Layout changes

### In-run HUD (`index.html` + `TiltGame.ts` + `game.css`)
- Top-left block, in this order and never overlapping: score (52px mono),
  then one 12px mono line `BEST 32,420 · Standard`.
- The multiplier is a separate chip **below** the score block (not beside it), only
  visible when the multiplier is > 1. Never overlaps the score or "best".
- Top-right: exactly two 44px icon buttons — Pause, Quit. The sound toggle, the
  calibrate button and the armory shortcut all move into the pause overlay.
- **Delete the centre-of-arena mode banner** (`CLASSIC SURVIVAL / STANDARD 1.0X SCORE
  // THE NEON ARENA`). Nothing is painted over the middle of the playfield.
- Shield indicator: bottom-centre, a 240px 3px bar with a `Shield 1.6s` mono label.
- Milestone toast: bottom-left, a small card with a tick, the milestone name, and the
  points earned. Auto-dismiss as today.

### Milestone rail (`GoalsHUD.ts`)
- **During a run the sidebar must not occupy playfield width.** Collapse it to a 4px
  vertical rail pinned to the left edge showing overall completion, with segment ticks.
  No text, no cards, no toggle button in play.
- The full milestone list renders on the menu screen and in the Milestones modal only.
- Keep the existing show/hide persistence if present, but the default in-run state is
  the 4px rail.

### Menu (`TiltMenu.ts`)
- Left panel (576px on desktop, full width under 900px) over the live arena:
  wordmark, one-line subtitle, three mode rows, Play, then a row of three text links
  (Armory / Milestones / Settings), then a bottom stat row (BEST / POINTS / MILESTONES).
- Mode rows are compact: 3px colour rail, name + multiplier on one line, one-liner
  under it, a radio-style dot on the right. No badges, no paragraphs, no footers.
- **First run** (best score is 0 and no points earned): hide the bottom stat row and
  show instead a single line `First milestone at 1,000 points`.

### Armory (`ArmoryUI.ts`)
- Full-screen shell, not a nested modal panel: header row (title, tabs, points, close),
  then content.
- Weapons tab: 300px left list of weapons (name + `3/5` rank), main pane shows the
  selected weapon with its upgrade rows. Each upgrade row: name + effect, a 5-pip rank
  meter, `n/5`, and a cost button. One-off unlocks in a two-up grid below.
- Ships tab: 3-column grid of cards — silhouette plate, name + trait, two stat bars
  (Hitbox, Turn), and an action button (`Equipped` / `Equip` / `<n> pts`).
- Handling tab: two sliders (Turn rate, Deadzone) on the left, a preview panel on the
  right, a `Reset` button.
- The points readout in the header is fixed-size (see §3).

### Mobile (<= 640px)
- Menu: same stack, full width, 24px gutters, 46px targets.
- HUD: score 34px, two 46px icon buttons, shield bar 180px.
- Death screen is a bottom sheet (rounded top corners, pinned to the bottom) so Retry
  sits under the thumb. Add a 40x4 grab handle.
- Armory: back chevron + title + points, horizontally scrollable tab row, single
  column content, a sticky `Play` button at the bottom.

## 7. Verification

`npx tsc --noEmit` must pass. `npx vite build` must pass. Do not leave unused
imports or dead CSS rules referencing deleted classes.

## 8. DOM id contract (binding on every agent)

**No existing element id may be renamed or removed.** `TiltGame.ts`, `GoalsHUD.ts` and
`ArmoryUI.ts` look these up by id. If an element moves to a different container, it
keeps its id. Existing ids that must survive:

```
tilt-canvas tilt-goals-sidebar tilt-goal-toast tilt-score tilt-best tilt-mode-badge
btn-tilt-calibrate btn-tilt-sound btn-tilt-armory-hud btn-tilt-pause btn-tilt-menu
tilt-menu-screen tilt-cinematic-overlay tilt-pause-overlay btn-tilt-resume
btn-tilt-calibrate-pause btn-tilt-armory-pause btn-tilt-menu-pause
tilt-pause-scheme-desc tilt-gameover-modal tilt-final-score tilt-final-kills
tilt-final-mult tilt-final-time tilt-earned-points tilt-balance-points
tilt-gameover-milestones btn-tilt-armory-gameover btn-tilt-restart
btn-tilt-menu-gameover tilt-options-modal tilt-all-goals-modal tilt-armory-modal
btn-toggle-goals-hud btn-view-all-goals btn-close-all-goals btn-tilt-portal
```

Elements that **move** but keep their id:
- `btn-tilt-sound`, `btn-tilt-armory-hud`, `btn-tilt-calibrate` leave the top HUD and
  live inside the pause overlay. The top HUD keeps only `btn-tilt-pause` and
  `btn-tilt-menu` as 44px icon buttons.
- `btn-tilt-armory-gameover` stays on the death screen but becomes the **secondary**
  button labelled `Spend <balance>`; `btn-tilt-restart` becomes the **primary** button
  labelled `Retry` and carries `autofocus`.

New ids that `index.html` adds and `TiltGame.ts` must wire (null-guard everything):
```
tilt-hud-mult          span, the multiplier chip (hidden when mult <= 1)
tilt-shield-wrap       container for the shield readout (hidden when no shield)
tilt-shield-label      text e.g. "Shield 1.6s"
tilt-shield-fill       the bar fill element (set style.width as a %)
tilt-gameover-sub      "Swarmed at 1:42 — Standard"
tilt-gameover-best     the "New best — up N" banner (hidden unless a new best)
btn-tilt-restart-pause "Restart run" in the pause overlay
btn-tilt-music-pause   music switch in the pause overlay
btn-tilt-settings-pause link to the settings modal from the pause overlay
```

## 9. Class-name reporting

Every agent that writes markup must also write
`.redesign/classes-<agent>.md` listing **every CSS class it emits**, one per line,
grouped by screen, with a one-line note on what each is. The stylesheet is rewritten
afterwards from the union of those files. Prefer reusing an existing class name from
`src/styles/game.css` over inventing a new one; when you do invent one, use the
existing naming style (`tilt-`, `menu-`, `hud-`, `armory-`, `opt-` prefixes).
