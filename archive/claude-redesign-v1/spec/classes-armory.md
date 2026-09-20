# classes-armory.md — CSS classes emitted by `ArmoryUI.ts`

Agent: **armory** (owns `/src/tilt-to-live/ArmoryUI.ts` and
`/src/tilt-to-live/ProgressionManager.ts`).

`ProgressionManager.ts` emits exactly one class: `ship-preview-svg`, on the `<svg>`
returned by `getShipSvgPreview()` (existing, unchanged — keep its rules). Everything
else below comes from `ArmoryUI.render()`.

**No element in this file carries an inline `style` attribute any more, and no colour
or size is set from TypeScript.** Every colour, width and fill below must come from
CSS. There is no `--hazard` / red anywhere in the markup.

Shared classes documented by the shell and menu agents are reused as-is and appear
here only where I attach a layout modifier: `btn-secondary`, `tilt-icon`,
`tilt-btn-text`, `hidden`, `game-overlay`, `custom-scrollbar`, `armory-header`,
`armory-title-group`, `armory-header-right`, `armory-close-btn`, `tuning-value-pill`,
`slider-wrapper`, `slider-boundary`.

I emit **no** `btn-primary`, **no** `btn-ghost` and **no** `opt-switch`.

---

## Shell

- `tilt-armory-overlay` — existing. Modifier on `#tilt-armory-modal` (set in
  `initDOM()`, alongside `game-overlay` + `hidden`). **Must now be a full-bleed
  ground, not a centring flexbox for a nested card** (§6: "Full-screen shell, not a
  nested modal panel"). `--void` ground, `inset: 0`.
- `armory-shell` — **new.** Replaces `overlay-panel tilt-armory-panel`. The
  full-screen shell itself: column flex, `100%` width/height, no border-radius, no
  shadow, no max-width. `role="dialog"`.
- `armory-content` + `custom-scrollbar` — existing. The single scroll region under the
  header. **Keep this exact class name** — `render()` reads `.armory-content` to save
  and restore `scrollTop` across re-renders.
- `armory-panel` — **new.** Base wrapper inside `armory-content`, one per tab. Holds
  the max-width/gutter rhythm shared by all four panels.
- `armory-panel-weapons` / `armory-panel-ships` / `armory-panel-arena` /
  `armory-panel-handling` — **new** per-tab layout modifiers on `armory-panel`.

## Header

One row: title, tabs, points, close.

- `armory-header` — existing (shared with GoalsHUD + TiltMenu). Now a three-part row:
  title group | tab nav | right cluster. Must survive a 1280px viewport without the
  tab row wrapping or overflowing.
- `armory-title-group` — existing. Holds **only** `<h2>Armory</h2>`. The
  `TILT TO LIVE // THE VAULT` eyebrow is gone (see the dead-class list).
- `armory-header-right` — existing. Points readout + close button, ~12px gap.
- `armory-points` — **new.** Wrapper for the points readout. Replaces
  `armory-points-pill`. No pill chrome required; a plain baseline-aligned pair reads
  better here.
- `armory-points-label` — **new.** The word `Points`. 10–11px mono, uppercase via CSS,
  letter-spaced, `--text-4`.
- `armory-points-value` — **new.** `#armory-points-val`. **FIXED 15px** mono,
  `font-variant-numeric: tabular-nums`, `var(--flare)` (§3). **This is the bug being
  fixed** — the old `.armory-points-pill strong` sized/coloured itself off the value
  and rendered a small balance huge and red. The size must never depend on the value,
  and it must never be `--hazard`.
- `armory-close-btn` — existing. `#btn-armory-close`, 44px icon button, now holds the
  close (X) SVG instead of `✕`.
- `tilt-icon` — shell-shared. On that close SVG and on every check SVG below.

## Tabs

- `armory-tabs` — **existing name, new treatment.** `role="tablist"`. Exactly four
  buttons, sentence case, no icons, no emoji. **No uppercase, no letter-spacing** —
  that is what used to overflow. Horizontally scrollable at <=640px (§6 mobile).
- `armory-tab-btn` — existing. One tab: `Weapons` / `Ships` / `Arena` / `Handling`.
  Transparent, >=44px tall, `--text-3`, sentence case, 13–14px body face.
- `active` — existing modifier on `armory-tab-btn`: `--panel-2` fill, `--ion` bottom
  edge or border, `--ion-soft` text. No glow.

## Weapons panel — left list

- `armory-weapon-list` — **new.** The fixed **300px** left column (`<nav>`), column
  flex, 4px gap. Full width above the two-column breakpoint collapse.
- `armory-weapon-item` — **new.** One weapon row, rendered as a `<button>`. Name left,
  rank readout right, `space-between`, min-height 44px, `--panel` fill,
  `1px solid var(--line)`, `--radius-l`, `text-align: left`.
- `is-selected` — **new modifier** on `armory-weapon-item`: border `var(--ion)`, fill
  `var(--panel-2)` (§3 selected card). No glow, no transform. Same modifier name the
  menu agent uses on `menu-mode-row`.
- `armory-weapon-item-name` — **new.** 14px body, 500, `--text-2`.
- `armory-weapon-item-rank` — **new.** The `3/5`-style readout (ranks owned / ranks
  available for that weapon). Mono, tabular, 12px, `--text-4`.

## Weapons panel — main pane

- `armory-weapon-main` — **new.** The right pane (`<section>`), column, ~20px gap.
- `armory-weapon-head` — **new.** `<header>` for the title + description.
- `armory-weapon-title` — **new.** `<h3>`, e.g. `Blackhole`. Display face, 700, ~22px,
  `--text`.
- `armory-weapon-desc` — **new.** The one-sentence description, e.g.
  `Drags dots in, then collapses.` 13px body, `--text-3`.

## Upgrade rows

- `armory-upgrade-list` — **new.** Column of rows, 8px gap.
- `armory-upgrade-row` — **new.** One upgrade. Row: text | meter | cost button.
  `--panel` fill, `1px solid var(--line)`, `--radius-l`, min-height 56px. Stacks to
  two lines at <=640px.
- `armory-upgrade-text` — **new.** Column: name over effect, 2px gap, flexible width.
- `armory-upgrade-name` — **new.** One or two words (`Radius`, `Pull`, `Duration`).
  14px body, 500, `--text-2`.
- `armory-upgrade-effect` — **new.** The bare delta (`+35px / rank`). 12px **mono**,
  tabular, `--text-4`. (Mono here because the string is a numeric delta.)
- `armory-upgrade-meter` — **new.** Row holding the pips and the readout, 10px gap.
- `rank-pips` — existing. Now a `<span>` (was a `<div>`), `aria-hidden`. Row of pips,
  4px gap.
- `pip` — existing. One 6px pip, `--panel-2`, `--radius-s`.
- `filled` — existing modifier on `pip`: `var(--ion)`. No glow.
- `armory-rank-readout` — **new.** `n/5`. 12px mono, tabular, `--text-4`. Needs a
  fixed min-width so rows do not jump as ranks are bought.
- `armory-cost-btn` — **new.** The cost control. Always applied **with**
  `btn-secondary` when it is a real `<button>`. Label is the bare `400 pts` — never
  `Rank 1 - 400`. Auto width, `white-space: nowrap`, >=44px tall, reserve a
  `min-width` (~92px) so the row does not reflow when the cost ticks up. The numeral
  should be mono/tabular.
- `is-maxed` — **new modifier** on `armory-cost-btn`, rendered as a non-interactive
  `<span>` reading `Maxed`. No `btn-secondary` base. `--text-5`, no border fill.
- `is-owned` — **new modifier** on `armory-cost-btn`, a non-interactive `<span>`
  reading `Unlocked` with a check SVG. `var(--ok)` text, `--ok` at low alpha for the
  border. Shares the name with the unlock card modifier below.
- `tilt-btn-text` — shell-shared. The text span beside the check SVG.

## One-off unlocks

- `armory-unlocks` — **new.** `<section>` below the upgrade list, ~12px top gap and a
  hairline `--line` top rule.
- `armory-section-label` — **new.** Section heading (`Unlocks`, and the Arena panel's
  `Themes` / `Dots`). 10px mono, uppercase via CSS, letter-spaced, `--text-4`.
  Rendered as `<h4>`/`<h3>` in sentence case; uppercasing is CSS's job.
- `armory-unlock-grid` — **new.** The **two-up** grid (`repeat(2, 1fr)`), 10px gap.
  Single column at <=640px.
- `armory-unlock-card` — **new.** One one-off unlock. Styled with **`--plasma`**:
  `--panel` fill, `1px solid` a plasma-tinted line, `--radius-l`. Column layout.
- `is-owned` — **new modifier** on `armory-unlock-card` for an already-bought unlock:
  drop to `--ok`-tinted border, dim the body copy.
- `armory-unlock-name` — **new.** `Aegis` / `Supernova`. 14px body, 600,
  `var(--plasma)`.
- `armory-unlock-effect` — **new.** `You are safe inside the well.` 12.5px body,
  `--text-3`.

## Ships grid

- `armory-ship-grid` — **new.** **3-column** card grid (`repeat(3, 1fr)`), 12px gap.
  2-up under ~980px, 1-up at <=640px.
- `armory-ship-card` — **new.** `<article>`. `--panel`, `1px solid var(--line)`,
  `--radius-l`, column, 10px gap, 16px padding.
- `is-equipped` — **new modifier** on `armory-ship-card` (and on `armory-tile`):
  border `var(--ok)` or `var(--ion)`, fill `--panel-2`. No glow.
- `armory-ship-plate` — **new.** The silhouette plate holding the ship SVG: square-ish
  (~100px tall), `--panel-2` fill, `--radius`, `display: grid; place-items: center`.
  Replaces `catalog-preview-box ship-preview-box`.
- `ship-preview-svg` — existing, emitted by `ProgressionManager.getShipSvgPreview()`.
  Keep. Drop any hover-scale/glow rules on it.
- `armory-ship-name` — **new.** `<h4>`: `Arrow`, `Viper`, `Phantom`, `Aegis`,
  `Matrix`, `Shuriken`, `Sovereign`. 15px body, 600, `--text`.
- `armory-ship-trait` — **new.** `<p>`: `Balanced`, `Aggressive`, `Evasive`, `Heavy`,
  `Fast cooldown`, `Spin drift`, `Radiant`. 12px body, `--text-4`. (Comes from
  `ShipSkinConfig.description`, which now holds the trait.)
- `armory-stat-bars` — **new.** Column of the two stat rows, 6px gap.
- `armory-stat-row` — **new.** Row: label left, track right (track flexes).
- `armory-stat-name` — **new.** `Hitbox` / `Turn`. 11px mono, uppercase via CSS,
  `--text-4`, fixed ~52px width so the two tracks align.
- `armory-stat-track` — **new.** 3–4px track, `--panel-2`, `--radius-s`, `flex: 1`.
- `armory-stat-fill` — **new.** `--ion` fill. **Width comes from a level class, not an
  inline style.**
- `lvl-1` … `lvl-5` — **new modifiers** on `armory-stat-fill`: width `20%` / `40%` /
  `60%` / `80%` / `100%`. Only these five values are ever emitted.
- `armory-action-btn` — **new.** The single action button per card/tile, always
  applied **with** `btn-secondary`. Full card width, >=44px tall. Labels: `Equip`, or
  `<n> pts` when locked.
- `is-equipped` — **new modifier** on `armory-action-btn`: rendered as a
  non-interactive `<span>` reading `Equipped` with a check SVG, in **`var(--ok)`**
  (text and border tint). Replaces the old `Piloting ✓`.

## Arena panel

Holds the folded **arena themes** and **enemy dot skins** as two sub-sections.

- `armory-subsection` — **new.** `<section>`, ~20px bottom gap.
- `armory-section-label` — see above. Used for `Themes` and `Dots`.
- `armory-tile-grid` — **new.** 3-up grid, 12px gap; 2-up under ~980px, 1-up at
  <=640px.
- `armory-tile` — **new.** One theme/dot card. Same card treatment as
  `armory-ship-card` but with a shorter plate.
- `is-equipped` — same modifier as above, on `armory-tile`.
- `armory-tile-plate` — **new.** The preview plate, ~64px tall, `--radius`,
  `overflow: hidden`, `display: grid; place-items: center`.
- `armory-tile-name` — **new.** `<h4>`. 15px body, 600, `--text`.
- `armory-tile-trait` — **new.** `<p>`, the short trait line. 12px body, `--text-4`.

### Preview swatches — **these carry all the colour, and CSS owns it**

The old build painted these with inline gradients built from `ProgressionManager`
data. That is gone. Each plate now gets a static identity class instead:

- `armory-swatch` — **new.** Base class for an arena-theme swatch. Fills the plate.
- `theme-void` / `theme-synthwave` / `theme-nebula` / `theme-matrix` /
  `theme-supernova` / `theme-blueprint` — **new.** One per `arenaThemeCatalog` id.
  Each should reproduce that theme's `bgGradient` + `gridColor` (the values still live
  in `ProgressionManager.arenaThemeCatalog` — read them from there).
- `armory-dot` — **new.** Base class for an enemy-skin swatch: a ~28px circle,
  `border-radius: 50%`.
- `dot-classic` / `dot-toxic` / `dot-glitch` / `dot-magma` / `dot-void` / `dot-gold` —
  **new.** One per `enemySkinCatalog` id; reproduce that skin's `bodyGradient` and
  `borderColor`. **See the note at the bottom about `dot-classic` and hazard red.**

## Handling panel

- `armory-handling-grid` — **new.** Two columns: controls left, preview right
  (`minmax(0,1fr) 260px`), 20px gap. Single column at <=900px.
- `armory-handling-controls` — **new.** Column, 14px gap.
- `armory-handling-title` — **new.** `<h3>Handling</h3>`. Display face, 700, ~22px,
  `--text`. (Not `Steering Sensitivity & Cursor Responsiveness` — §0.4, no ampersand
  titles.)
- `armory-slider-card` — **new.** One slider block: `--panel`,
  `1px solid var(--line)`, `--radius-l`, 14px padding, column, 10px gap.
- `armory-slider-head` — **new.** Row: text block left, value pill right,
  `space-between`, baseline aligned.
- `armory-slider-text` — **new.** Column: label over hint, 2px gap.
- `armory-slider-name` — **new.** A real `<label for=...>`: `Turn rate` / `Deadzone`.
  14px body, 500, `--text-2`.
- `armory-slider-hint` — **new.** `Higher turns sharper.` /
  `Stops drift when you hold still.` 12px body, `--text-5`.
- `tuning-value-pill` — existing, **shared with TiltMenu's Settings modal**.
  `#val-sensitivity` (`1.0x`) and `#val-deadzone` (`4px`). Mono tabular, `--text-2`.
  Needs a `min-width` so the row does not jump as the slider moves.
- `slider-wrapper` — existing, shared with TiltMenu. `0.5x` — range — `2.0x`.
- `slider-boundary` — existing, shared with TiltMenu. Bare `0.5x` / `2.0x` / `0px` /
  `16px` — no `(Stable)` / `(Hyper)` parentheticals any more. 11px mono, `--text-5`.
- `armory-slider-input` — **new.** Class on the `<input type="range">` itself, so the
  track/thumb can be styled without relying on the
  `.slider-wrapper input[type='range']` descendant selector. `flex: 1`, >=44px hit
  height, `--ion` thumb.
- `armory-handling-actions` — **new.** Row holding the single reset button.
- `armory-reset-btn` — **new.** Layout modifier on `btn-secondary` for
  `#btn-tuning-reset`, label `Reset` (not `↺ Reset to Defaults (1.0x / 4px)`). Auto
  width, ~18px horizontal padding, >=44px tall.
- `armory-preview` — **new.** `<aside>`, the right preview panel: `--panel`,
  `1px solid var(--line)`, `--radius-l`, column, 14px gap, 16px padding.
- `armory-preview-plate` — **new.** Same treatment as `armory-ship-plate`; holds the
  equipped ship's SVG.
- `armory-preview-stats` — **new.** Column of readout rows, 8px gap, hairline `--line`
  separators.
- `armory-preview-row` — **new.** Row, `space-between`, min-height 28px.
- `armory-preview-key` — **new.** `Ship` / `Turn rate` / `Deadzone`. 11px mono,
  uppercase via CSS, `--text-4`.
- `armory-preview-val` — **new.** The value. Mono, tabular, 13px, `--text-2`.

---

## Classes now unused — safe to delete from `game.css`

Every class below had rules in `game.css`, was emitted **only** by the old
`ArmoryUI.render()`, and is now absent from the whole of `src/` and `index.html`
(verified by a full-text scan after my rewrite). They are grouped by where they lived
in the stylesheet.

**Header / shell**

- `tilt-armory-panel` — replaced by `armory-shell`. Also delete its rule inside the
  `@media` mobile block.
- `armory-points-pill` — replaced by `armory-points`. **This rule is the source of the
  huge red balance;** do not carry any of it over.
- `eyebrow` — the `TILT TO LIVE // THE VAULT` line was its last consumer anywhere.
  Also simplify the selector `.overlay-panel p:not(.eyebrow)` at `game.css:1042`,
  which is now a no-op negation. (The menu and shell agents both reported dropping it
  too — worth a re-check at stylesheet-rewrite time in case a late edit re-adds it.)

**Weapons (old perk cards)**

- `weapons-category-filter-bar`, `weapon-filter-chip` — the emoji filter chip row.
- `perks-grid`, `perk-card`, `perk-card-header`, `perk-badge`, `perk-desc`,
  `perk-rows`, `perk-row`, `perk-meta` — the whole fat perk-card interior. Also delete
  `.perk-card:hover`, `.perk-row:hover` and `.perk-meta strong` / `.perk-meta span`.
- `keystone-row`, `keystone-title` — replaced by `armory-unlock-card` /
  `armory-unlock-name`.
- `armory-btn` — replaced by `btn-secondary` + `armory-cost-btn` /
  `armory-action-btn`. Also delete `.armory-btn:hover:not(:disabled)`,
  `.armory-btn:disabled`, `.armory-btn.equipped` and `.catalog-action .armory-btn`.

**Catalog cards (old ships / enemies / arenas)**

- `catalog-grid`, `catalog-card`, `is-active-card`, `catalog-preview-box`,
  `ship-preview-box`, `catalog-card-header`, `catalog-desc`, `catalog-action`,
  `item-cost`. Also delete `.catalog-card:hover`,
  `.catalog-card:hover .ship-preview-svg` and `.catalog-card-header h4`, plus the
  `.catalog-grid` rule inside the `@media` mobile block.
  (**Careful:** `catalog-goal-card` / `catalog-goal-left` / `catalog-goal-right` /
  `catalog-goal-reward` / `catalog-goal-status` belong to GoalsHUD — **keep those.**)
- `enemy-preview-glyph`, `enemy-preview-pupil` — replaced by `armory-dot` +
  `dot-<id>`.
- `arena-preview-box`, `arena-grid-mockup` — replaced by `armory-swatch` +
  `theme-<id>`. The `--grid-line` custom property they consumed is no longer set from
  TypeScript.

**Handling (old tuning tab)**

- `tuning-container`, `tuning-hero`, `tuning-controls`, `tuning-control-card`,
  `tuning-label-row`, `tuning-explain`, `tuning-actions`. Also delete
  `.tuning-hero h3`, `.tuning-hero p` and `.tuning-label-row label`.
- `secondary-button` — the old reset button was its last consumer in this file, and
  the menu agent also reports dropping `command-button`; both are now fully dead.

**Keep** (still emitted by me): `armory-header`, `armory-title-group`,
`armory-header-right`, `armory-close-btn`, `armory-tabs`, `armory-tab-btn`, `active`,
`armory-content`, `rank-pips`, `pip`, `filled`, `tuning-value-pill`, `slider-wrapper`,
`slider-boundary`, `ship-preview-svg`, `tilt-armory-overlay`, `game-overlay`,
`custom-scrollbar`, `hidden`.

### Already dead before this change (armory region of the stylesheet)

These had rules but were not emitted by the old `ArmoryUI.ts` either, so they can go
in the same sweep: `armory-nav-tabs`, `armory-content-area`, `armory-perks-container`,
`weapon-group-card`, `weapon-group-header`, `perk-row-card`, `perk-name`,
`preview-reticle-ring`, `preview-reticle-core`, `cursor-preview-glyph`,
`armory-badge-control`, `armory-gold-btn`.

---

## Notes for the CSS and game-logic agents

1. **`dot-classic` is the one place enemy red can legitimately appear.** It is a
   preview swatch depicting the crimson enemy skin, not chrome. Use the skin's own
   `bodyGradient` from `ProgressionManager.enemySkinCatalog`, and do **not** let that
   colour leak onto any border, label, badge or button in this UI. Nothing else in the
   Armory may use `--hazard`.
2. **The Armory is no longer a centred modal card.** `.tilt-armory-overlay` must stop
   centring a child panel and become a full-bleed ground; `.armory-shell` fills it.
   If `game-overlay` hard-codes `place-items: center`, override it here.
3. **`armory-stat-fill` widths come only from `lvl-1` … `lvl-5`.** Those two bars
   (`Hitbox`, `Turn`) are **display-only**: ships carry no gameplay stats today, and
   the levels live in a `SHIP_STATS` table inside `ArmoryUI.ts` describing the drawn
   silhouette. If ships ever get real hitbox/turn values, that table should be
   replaced by a read from `ProgressionManager` — flagging it so nobody mistakes the
   bars for live data.
4. **Cost labels are always `<n> pts`**, including when `n` is 1 (`1 pts`). The spec's
   copy table fixes that format and perk rank costs start at 1, so the singular case
   is reachable. Say the word and I will special-case `1 pt`.
5. **The `3/5` readout in the weapon list is ranks-owned / ranks-available** summed
   across that weapon's upgrades and one-off unlocks, so the denominator varies by
   weapon (`0/17` for Blackhole, `0/9` for Lightning). Style
   `armory-weapon-item-rank` to tolerate up to five characters.
6. `ShipSkinConfig.description`, `EnemySkinConfig.description` and
   `ArenaThemeConfig.description` now hold **short trait lines** (max 4 words), not
   prose. `ShipSkinConfig.name` changed too (`Classic Arrow` -> `Arrow`). No id,
   price, colour, shape or storage key was touched. If any other file ever renders one
   of these as a paragraph, it will now render a fragment instead.
7. `ArmoryUI.open()` still accepts the legacy tab keys
   `'perks' | 'cursors' | 'enemies' | 'arenas' | 'tuning'` that `TiltGame.openArmory()`
   passes, and maps them internally (`perks`->Weapons, `cursors`->Ships,
   `enemies`/`arenas`->Arena, `tuning`->Handling). **No change needed in `TiltGame.ts`.**
8. §6 mobile asks for a sticky `Play` button at the bottom of the Armory. I did not
   emit one: the Armory has no launch path of its own (`TiltGame` owns start/resume),
   and inventing a button id would break the §8 id contract. If it is wanted, it
   belongs in `index.html` or `TiltGame.ts` with an agreed id.
