# classes-menu.md — CSS classes emitted by `TiltMenu.ts`

Agent: **menu** (owns `/src/tilt-to-live/TiltMenu.ts` and `/src/tilt-to-live/GameOptions.ts`).
`GameOptions.ts` emits no markup. Every class below comes from `TiltMenu.render()` or
`TiltMenu.openOptionsModal()`. Grouped by area. Nothing in these files sets an inline
`style` attribute any more, so **every colour and size below must come from CSS**.

Shared classes that the shell agent already documents (`btn-primary`, `btn-secondary`,
`btn-ghost`, `opt-switch`, `tilt-icon`, `hidden`, `overlay-panel`, `custom-scrollbar`,
`game-overlay`) are reused as-is and listed here only where I attach a layout modifier.

---

## Menu shell

- `tilt-menu-screen` — existing. `#tilt-menu-screen`, the full-stage menu layer over the live arena. Must be transparent so the arena reads through.
- `tilt-menu-content` — existing. Outer positioning wrapper; now left-aligns its child instead of centring it.
- `menu-panel` — **new.** The left panel itself: 576px wide on desktop, full width + 24px gutters at <=900px. `--void` ground, `1px solid var(--line)` on its right edge (or none), column flex, generous vertical rhythm. No glow.
- `game-overlay` + `tilt-options-overlay` — existing. Set on `#tilt-options-modal` by `initDOM()`; unchanged.

## Wordmark / hero

- `menu-hero` — existing. Column wrapper for the wordmark and the one subtitle line.
- `menu-title` — **existing name, new role.** The `<h1>` wordmark. Display face, 700, `font-stretch: 118%`, `--text`, tight leading (~0.92), **two stacked lines**. No text-shadow, no gradient.
- `menu-title-line` — **new.** Each of the two `<span>` lines inside `menu-title` (`TILT TO` / `LIVE`). `display: block`.
- `menu-subtitle` — existing. The single line `Move to dodge. The guns fire themselves.` Body face, ~14-15px, `--text-3`. Not uppercase.

## Mode rows

- `menu-modes` — **new.** `role="radiogroup"` column of the three rows, ~8px gap. Replaces `menu-modes-section` + `menu-modes-grid`.
- `menu-mode-row` — **new.** One compact row, rendered as a `<button role="radio">`. Grid/flex: rail | body | dot. `--panel` fill, `1px solid var(--line)`, `--radius-l`, min-height 64px (>=44px target), full width, text-align left. Replaces `menu-mode-card`.
- `is-selected` — **new modifier** on `menu-mode-row`. Border -> `var(--ion)`, fill -> `var(--panel-2)`. No glow, no scale transform.
- `mode-classic` / `mode-gauntlet` / `mode-code-red` — **new modifiers** on `menu-mode-row`. Their **only** job is to colour the child `mode-rail` (and the `mode-row-dot` fill when selected): `#5B8CFF` / `#FFB14D` / `#A78BFA` respectively. These replace the per-mode inline `style` that used to carry `m.color` / `m.glow`.
- `mode-rail` — **new.** Empty span. The 3px full-height colour rail on the left edge of the row, `--radius-s` on the left corners only. The one permitted left accent bar (§3).
- `mode-row-body` — **new.** Column between the rail and the dot: head row over the one-liner, 2px gap.
- `mode-row-head` — **new.** One line: name left, multiplier right (`space-between`, baseline aligned).
- `mode-row-name` — **new.** `Standard` / `Gauntlet` / `Code Red`. Body face, 15px, 600, `--text`. **Never coloured by mode** — the rail carries the colour.
- `mode-row-mult` — **new.** `1.0x` / `1.25x` / `1.5x`. Mono, 12px, `font-variant-numeric: tabular-nums`, `--text-4`.
- `mode-row-line` — **new.** The single tagline. Body face, 12.5px, `--text-4`, one line, `text-overflow: ellipsis`.
- `mode-row-dot` — **new.** Empty span on the right: a 16px radio ring, `1px solid var(--line-hi)`. When the row is `is-selected`, it gains a filled `--ion` core (a `::after`). 

## Actions

- `btn-primary` + `menu-play-btn` — the single `Play` button (`#btn-menu-launch`). `menu-play-btn` is the layout modifier only: full panel width, 56px tall, ~20px top margin. Label is plain sentence-case `Play`; no icon, no second line.
- `menu-links` — **new.** The `<nav>` row of three quiet text links. `display: flex`, space-between or 20px gap, ~12px vertical padding.
- `btn-ghost` + `menu-link` — the three text links `Armory` / `Milestones` / `Settings` (`#btn-menu-armory`, `#btn-menu-goals`, `#btn-menu-options`). `menu-link` is the modifier: 13px body, `--text-3`, 44px min height, no border, no background; hover -> `--text-2`. Quiet, not buttons-looking.

## Stat row (bottom)

- `menu-stat-row` — **new.** Three equal cells across the panel bottom, separated by hairline `--line` dividers, ~14px top padding with a `1px solid var(--line)` top rule. Hidden entirely on a first run (the markup is simply not emitted).
- `menu-stat` — **new.** One cell: value over label, left-aligned (or centred), 4px gap.
- `menu-stat-action` — **new modifier** on the POINTS cell, which is a real `<button>` (`#menu-btn-armory-quick`, opens the Armory). Resets button chrome: transparent, no border, text-align inherit, cursor pointer; hover tints the label to `--text-3`. Needs the standard focus ring.
- `menu-stat-value` — **new.** The numeral. Mono, tabular, **fixed 17px**, `--text`. Used by BEST and MILESTONES.
- `menu-stat-points` — **new modifier** on the POINTS value only: `color: var(--flare)`, still **fixed 17px** mono tabular (§3 — the size must never depend on the value). No `◈`, no `PTS` suffix.
- `menu-stat-label` — **new.** `BEST` / `POINTS` / `MILESTONES`. 10-11px mono, uppercase, letter-spaced, `--text-4`.
- `menu-first-run` — **new.** The single first-run line `First milestone at 1,000 points`, rendered *instead of* `menu-stat-row`. 12px body, `--text-5`, top hairline rule to match the stat row's position.

## Settings modal

Panel and header (shared with ArmoryUI / GoalsHUD — do not restyle in isolation):

- `overlay-panel` + `tilt-options-panel` — existing. `--panel-3`, `--radius-xl`, neutral `0 32px 80px rgba(0,0,0,0.6)` shadow only, max-width ~520px.
- `armory-header` — existing. Title row.
- `armory-title-group` — existing. Now holds **only** `<h2>Settings</h2>`; the `eyebrow` element is deleted here.
- `armory-header-right` — existing. Close-button holder.
- `armory-close-btn` — existing. `#btn-close-options`, 44px, now holds the close (X) SVG instead of `✕`.
- `tilt-icon` — shell-shared. On that close SVG.
- `options-body` + `custom-scrollbar` — existing. Scroll region.

Sections (order in the DOM is **Readability, Controls, Audio**):

- `options-section` — existing. One section block, ~20px gap between sections.
- `options-section-label` — **existing name, new treatment.** `Readability` / `Controls` / `Audio`. 10px mono, uppercase, letter-spaced, `--text-4`. Sentence case in the markup; uppercasing is CSS's job.
- `options-row` — existing. One setting row: 44px min height, `--panel` fill, `1px solid var(--line)`, `--radius`, space-between.
- `opt-row` — **new modifier** always applied alongside `options-row`. Carries the new label/hint/control layout so the legacy `.options-row` rules can be replaced wholesale.
- `opt-row-stack` — **new modifier** on rows whose control sits **below** the label instead of beside it (Screen shake, the control-scheme group, Turn rate): `flex-direction: column; align-items: stretch;`.
- `opt-row-text` — **new.** Column holding the label and its hint, 2px gap.
- `opt-row-label` — **new.** 14px body, 500, `--text-2`. Sentence case, never uppercase.
- `opt-row-hint` — **new.** 12px body, `--text-5`. One short sentence; omitted on rows with no hint (Sound, Music).
- `opt-switch` — shell-shared. Emitted **childless** (`<button class="opt-switch" role="switch" aria-checked>`), so the knob must be a `::after`. Used by `#opt-toggle-halo`, `#opt-toggle-tether`, `#opt-toggle-grid`, `#opt-toggle-sfx`, `#opt-toggle-music`. On = `--ion`; `[aria-checked="false"]` = `--panel-2` + `--line-hi`.

Segmented groups:

- `options-button-group` — existing. Flex row of `opt-btn`s, 6px gap, wraps at narrow widths.
- `opt-scheme-group` — **new modifier** on the control-scheme group: 4-up equal columns on desktop, 2x2 at <=640px.
- `opt-btn` — existing. One segment: transparent, `1px solid var(--line-hi)`, `--radius`, `--text-2`, >=44px tall.
- `active` — existing modifier on `opt-btn`: `--panel-2` fill, `var(--ion)` border, `--ion-soft` text. No glow.
- `opt-btn-stack` — **new modifier** on the four control-scheme buttons: column layout for the two-line content.
- `opt-btn-title` — **new.** `Mouse` / `Keys` / `Both` / `Tilt`. 13px body, 500.
- `opt-btn-sub` — **new.** `point to steer` / `WASD / arrows` / `whichever moves` / `phone gyroscope`. 10-11px **mono**, `--text-5`. (Mono here is a deliberate spec call, §5.)

Turn-rate slider (kept in Settings — `#opt-slider-sensitivity` / `#opt-val-sensitivity` are wired inside this file):

- `opt-slider-head` — **new.** Row above the slider: `opt-row-text` on the left, the value pill on the right.
- `tuning-value-pill` — existing (shared with ArmoryUI). `#opt-val-sensitivity`, e.g. `1.0x`. Mono tabular, `--text-2`.
- `slider-wrapper` — existing (shared with ArmoryUI). `0.5x` — range — `2.0x`.
- `slider-boundary` — existing (shared with ArmoryUI). 11px mono, `--text-5`.

Calibration row (only rendered when the control scheme is `gyro`):

- `btn-secondary` + `opt-row-btn` — `#opt-btn-calibrate-gyro`, label `Calibrate`. `opt-row-btn` is the modifier: auto width, ~10px/18px padding, `white-space: nowrap`, 44px min height. The button's text is swapped to `Calibrating` / `Calibrated` / `Calibrate` by script — **do not size it off its content**, reserve a min-width of ~112px so the row does not jump.

---

## Classes now unused — safe to delete from `game.css`

Emitted only by the old `TiltMenu.render()` / `openOptionsModal()`; I checked each
against the rest of `src/` and `index.html` before listing it.

- `menu-top-bar` — the deleted top stat chip bar.
- `menu-stat-chip` — deleted; and its descendant rules `.menu-stat-chip small` / `.menu-stat-chip strong`.
- `menu-vault-chip` — deleted; and `.menu-vault-chip:hover` / `.menu-vault-chip strong`. ("Vault" is gone as a word.)
- `stat-glyph` — deleted; held the `🏆` / `★` / `◈` glyphs. No other file uses it.
- `menu-eyebrow` — the deleted `HYPER-NEON BULLET DODGE ARENA` line.
- `section-label` — the deleted `SELECT GAME MODE` label. (Nothing else uses it; `options-section-label` is a different class and stays.)
- `menu-modes-section`, `menu-modes-grid` — replaced by `menu-modes`.
- `menu-mode-card` — replaced by `menu-mode-row`; also delete `.menu-mode-card:hover`, `.menu-mode-card.selected`, `.menu-mode-card h3`, `.menu-mode-card.selected .mode-select-indicator`.
- `mode-card-header`, `mode-badge`, `mode-mult`, `mode-tagline`, `mode-desc`, `mode-select-indicator` — the whole fat-card interior. (`mode-badge` only *looked* used elsewhere: `index.html` / `TiltGame.ts` reference the **id** `tilt-mode-badge`, not this class.)
- `menu-actions-row` — replaced by the plain `btn-primary` + `menu-links` stack.
- `menu-launch-button`, `launch-icon`, `launch-text` — the deleted two-line `ENTER THE ARENA` / `LAUNCH <MODE>` button.
- `menu-sub-buttons`, `menu-sub-btn` — replaced by `menu-links` / `menu-link`.
- `opt-toggle-btn` — the `ENABLED` / `MUTED` / `DISABLED` text buttons; also `.opt-toggle-btn.active`. Replaced by `opt-switch`.
- `command-button` — my calibrate button was its last consumer in this file; the shell agent also reports dropping it, so it is fully dead.

Still referenced elsewhere — **do not delete**: `eyebrow` (ArmoryUI), `tuning-value-pill`,
`slider-wrapper`, `slider-boundary` (ArmoryUI **and** me), `armory-header`,
`armory-title-group`, `armory-header-right`, `armory-close-btn`, `options-section`,
`options-section-label`, `options-row`, `options-button-group`, `opt-btn`.
