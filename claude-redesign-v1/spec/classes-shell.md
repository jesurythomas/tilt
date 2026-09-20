# classes-shell.md — CSS classes emitted by `index.html` and `GoalsHUD.ts`

Agent: **shell** (owns `/index.html` and `/src/tilt-to-live/GoalsHUD.ts`).
Every class below is emitted by one of those two files. Grouped by screen.

---

## Global / shared

- `hidden` — existing utility; display:none. Toggled by TiltGame and GoalsHUD.
- `tilt-compat-hidden` — **new.** Permanently hidden (`display:none !important`). Used on elements kept only to satisfy the §8 id contract (`#btn-tilt-calibrate-pause`, `#btn-tilt-armory-pause`, `#btn-tilt-armory-hud`, and the empty cinematic sub/title/badge/skip nodes). Must beat `.hidden` being removed by script.
- `tilt-icon` — **new.** Base class on every inline stroke SVG: 1.5px stroke, `currentColor`, `flex: none`, vertical-align middle.
- `tilt-btn-text` — **new.** Text span inside a button that also holds an icon (for gap/alignment).
- `tilt-key-hint` — **new.** 11px mono, `--text-5`, centred keyboard hint ("ESC to resume", "SPACE to retry").
- `btn-primary` — **new.** §3 primary button: `--ion` fill, `--void` text, no border, `--radius-l`, 600, 54–60px tall.
- `btn-secondary` — **new.** §3 secondary: transparent, `1px solid var(--line-hi)`, `--text-2`.
- `btn-ghost` — **new.** §3 ghost/tertiary: transparent, no border, `--text-3`.
- `opt-switch` — **new.** §3 switch control, 44x26 pill. **Rendered as a bare `<button>` with no children** — the knob must be a `::after` pseudo-element, and the button's own text must be suppressed (`font-size:0` / `color:transparent`) because `TiltGame.ts` writes `textContent` into `#btn-tilt-sound`. On = `--ion`; off (`[aria-checked="false"]`) = `--panel-2` + `--line-hi` border.
- `game-screen`, `tilt-stage`, `game-overlay`, `overlay-panel`, `custom-scrollbar` — existing structural classes, unchanged.

---

## In-run HUD (`index.html`)

- `tilt-hud` / `game-hud` — existing wrapper for the in-run top bar; now a two-column flex row (left block / right icon buttons), `pointer-events: none` except on buttons.
- `hud-left` — **new.** Top-left column: score block then the multiplier chip stacked below it.
- `hud-score-block` — **new.** Score plus the one-line meta row.
- `hud-score` — **existing name, new role.** The score numeral itself (`#tilt-score`): 52px mono, tabular, `--text`. 34px at <=640px.
- `hud-meta` — **new.** The single 12px mono line under the score holding best + divider + mode.
- `hud-meta-best` — **new.** `#tilt-best` — "BEST 32,420", 12px mono, `--text-4`.
- `hud-meta-sep` — **new.** 1px x 10px hairline divider (`--line`) between best and mode. Empty span.
- `hud-meta-mode` — **new.** `#tilt-mode-badge` — mode name, 12px mono, `--text-4`. **Warning for the TiltGame agent:** today `updateHUD()` overwrites this element's `className` with `hud-mode-pill <mode>`; if that line stays, `hud-mode-pill` and the per-mode classes `classic` / `gauntlet` / `code-red` must also be styled to match `hud-meta-mode`.
- `hud-mult-chip` — **new.** `#tilt-hud-mult` — the multiplier chip **below** the score block (never beside it). `--radius-s`, 11px mono, uppercase, `--text-4`. Starts with `hidden`.
- `hud-actions` — existing. Top-right cluster of exactly two icon buttons, 8px gap.
- `hud-icon-btn` — **new.** 44x44 (46px at <=640px) icon-only button: transparent fill, `1px solid var(--line)`, `--radius`, `--text-3`. Replaces the old `icon-control`. Used by `#btn-tilt-pause` and `#btn-tilt-menu`.

### Shield readout (bottom centre)

- `tilt-shield-wrap` — **new.** `#tilt-shield-wrap`, absolutely positioned bottom-centre, column, 8px gap. Starts `hidden`.
- `tilt-shield-track` — **new.** 240px x 3px track, `--panel-2`, `--radius-s`. 180px at <=640px.
- `tilt-shield-fill` — **new.** `#tilt-shield-fill`, the `--ion` fill; `TiltGame` sets `style.width` as a %.
- `tilt-shield-label` — **new.** `#tilt-shield-label`, 11px mono, `--text-4`, e.g. "Shield 1.6s".

---

## Pause overlay (`index.html`)

- `tilt-pause-panel` — **new.** Modifier on `.overlay-panel` for the pause card: `--panel-3`, `--radius-xl`, neutral `0 32px 80px rgba(0,0,0,0.6)` shadow only, max-width ~380px.
- `tilt-pause-title` — **new.** The single `<h2>Paused</h2>`: display face, 700, ~28px, `--text`.
- `tilt-pause-scheme` — **new.** `#tilt-pause-scheme-desc` — 12px body, `--text-4`. Per §5 shown only on a first ever run; default it to `display:none` and let script reveal it, or hide it outright.
- `tilt-pause-primary` — **new.** Layout modifier on the `btn-primary` Resume button (full width, margin).
- `tilt-pause-action` — **new.** Layout modifier on full-width secondary pause buttons (`Restart run`, `Quit to menu`, `Calibrate`).
- `tilt-switch-list` — **new.** Container for the Sound / Music switch rows; hairline `--line` separators.
- `tilt-switch-row` — **new.** Label left, `.opt-switch` right, 44px min height, space-between.
- `tilt-switch-label` — **new.** 14px body, `--text-2`.
- `tilt-pause-link` — **new.** Layout modifier on the `btn-ghost` Settings link (centred, icon + text).

Ids living here now: `#btn-tilt-resume`, `#btn-tilt-restart-pause`, `#btn-tilt-menu-pause`, `#btn-tilt-sound`, `#btn-tilt-music-pause`, `#btn-tilt-calibrate` (the real calibrate control, toggled by `.hidden`), `#btn-tilt-settings-pause`, plus the three `tilt-compat-hidden` compatibility buttons.

---

## Game over (`index.html`)

- `tilt-gameover-panel` — **new.** Modifier on `.overlay-panel`. Desktop: centred card. <=640px: bottom sheet — pinned to the bottom, rounded top corners only, full width.
- `tilt-sheet-handle` — **new.** 40x4 grab handle, `--line-hi`, `--radius-s`. Visible only at <=640px.
- `tilt-final-score` — **new.** `#tilt-final-score`: 68px mono, tabular, **`var(--text)` — never `--hazard`**.
- `tilt-gameover-sub` — **new.** `#tilt-gameover-sub`: 13px body, `--text-3`. "Swarmed at 1:42 — Standard".
- `tilt-gameover-best` — **new.** `#tilt-gameover-best`: new-best banner. `--ion-wash` fill, `1px solid var(--ion-edge)`, `--ion-soft` text, `--radius`, 12px mono. Starts `hidden`.
- `tilt-stat-strip` — **new.** Three equal cells in a row, `--panel` card, `--radius-l`, `1px solid var(--line)`, hairline dividers between cells.
- `tilt-stat-cell` — **new.** Column: value over label, centred.
- `tilt-stat-value` — **new.** 20px mono, tabular, `--text` (`#tilt-final-kills` / `#tilt-final-mult` / `#tilt-final-time`).
- `tilt-stat-label` — **new.** 11px mono, uppercase, `--text-4` ("Kills" / "Best chain" / "Alive" — set in markup in sentence case; uppercase via CSS is optional).
- `tilt-points-line` — **new.** Single row: label left, values right, space-between.
- `tilt-points-label` — **new.** 13px body, `--text-3`. "Points earned".
- `tilt-points-earned` — **new.** `#tilt-earned-points`: **fixed 15px** mono, tabular, `var(--flare)`. Size must not depend on the value.
- `tilt-points-arrow` — **new.** The `→` between earned and balance, `--text-5`.
- `tilt-points-balance` — **new.** `#tilt-balance-points`: fixed 15px mono, tabular, `--flare-dim`.
- `gameover-milestones-list` — existing. `#tilt-gameover-milestones`; its children are injected by `TiltGame.ts` (`gameover-milestone-item`, `milestone-star`, `milestone-info`, `milestone-reward`) — not emitted by me.
- `tilt-gameover-primary` — **new.** Layout modifier on the `btn-primary` Retry button: full width, carries `autofocus`.
- `tilt-gameover-actions` — **new.** Row of two equal-width secondary buttons: `Menu` and `Spend`.

---

## Cinematic (`index.html`)

- `tilt-cinematic-overlay` — existing. `#tilt-cinematic-overlay`; full-bleed, transparent over the arena (no letterbox bars any more), centred content, `pointer-events: none`.
- `tilt-cinematic-content` — existing. Centring wrapper.
- `tilt-cinematic-wordmark` — **new.** "TILT TO LIVE" in the display face, 700, `font-stretch: 118%`, `--text`. 600ms hold, no glow.
- `tilt-cinematic-sub`, `tilt-cinematic-title`, `tilt-cinematic-badge`, `tilt-cinematic-skip` — existing, **kept empty and carrying `tilt-compat-hidden`** because `TiltEntranceCinematic.ts` still does `document.querySelector('.tilt-cinematic-title')` etc. and writes `textContent`. They must stay `display:none` no matter what text gets written into them.
- Removed from the DOM: `tilt-cinematic-bar`, `tilt-cinematic-bar-top`, `tilt-cinematic-bar-bottom` — **delete these rules from the stylesheet.**

---

## Milestone rail — in run (`GoalsHUD.ts`)

- `tilt-goals-sidebar` — existing. `#tilt-goals-sidebar`. In rail mode it must take **no playfield width**: `position: absolute; left: 0; top/bottom inset; width: 4px; pointer-events: none;`.
- `is-rail` — **new.** Modifier set on the sidebar during a run. Turns off every list style: no padding, no background, no border, no text.
- `goals-rail` — **new.** The 4px vertical track, `--panel-2`, full height of the inset, `position: relative`.
- `goals-rail-fill` — **new.** `--ion` fill anchored to the bottom; `style.height` set inline as a % of overall completion.
- `goals-rail-tick` — **new.** 1px full-width segment tick, `--void` (or `--line`), absolutely positioned; `top` set inline as a %.
- `mobile-menu-hide` — existing. Hides the sidebar on the menu at <=900px.

---

## Milestone list — menu screen (`GoalsHUD.ts`)

- `collapsed` — existing modifier on `tilt-goals-sidebar`.
- `goals-expand-tab` — existing. `#btn-toggle-goals-hud` in the collapsed state. Title/aria copy is now **"Show"**.
- `goals-star-icon` — existing wrapper, now holds the inline star SVG instead of `★`.
- `goals-expand-label` — existing. 11px mono, uppercase, "MILESTONES".
- `goals-expand-badge` — existing. `7/28` count, mono tabular.
- `goals-toggle-glyph` — existing wrapper, now holds the chevron-right SVG.
- `goals-sidebar-header` — existing. Header row of the expanded list.
- `goals-header-title` — existing. Star + "MILESTONES" + count.
- `goals-count-badge` — existing. `7/28`, mono tabular, `--text-4`.
- `goals-header-right` — existing. Points pill + collapse button.
- `goals-points-pill` — **new, replaces `goals-vault-pill`.** Points readout. **Delete `goals-vault-pill` from the stylesheet.**
- `goals-points-label` — **new.** 10px mono, uppercase, `--text-4`, "POINTS".
- `goals-points-value` — **new.** Fixed 15px mono, tabular, `var(--flare)`. The `◈` glyph and the "PTS" suffix are gone.
- `goals-collapse-btn` — existing. `#btn-toggle-goals-hud` in the expanded state; now a 44px icon button holding the chevron-left SVG. Title/aria copy is now **"Hide"**.
- `goals-list` — existing. Column of active goal cards.
- `goals-all-cleared` — existing. Empty state; copy is now "All milestones complete".
- `goals-cleared-icon` — **new.** Wrapper for the check SVG in the empty state (replaces the `🏆` emoji).
- `goal-hud-card` — existing. One active goal card (`--panel`, `--line`, `--radius-l`).
- `goal-card-top` — existing. Title + reward row.
- `goal-card-title` — existing. 13px body, `--text-2`.
- `goal-card-reward` — existing. `+40 pts`, mono, `--flare`.
- `goal-card-desc` — existing. 12px body, `--text-4`.
- `goal-progress-row` — existing. Track + value.
- `goal-progress-track` — existing. 3–4px, `--panel-2`.
- `goal-progress-fill` — existing. `--ion` fill; width set inline by `updateLive`.
- `goal-progress-val` — existing. 11px mono, tabular, `--text-4`.
- `goals-view-all-btn` — existing. `#btn-view-all-goals`; label **"Milestones"**, `title="All milestones"`, plus a chevron-right SVG. Style as ghost/tertiary.

---

## Milestone toast (`GoalsHUD.ts`)

- `tilt-goal-toast` — existing. `#tilt-goal-toast`, bottom-left card, auto-dismiss unchanged.
- `goal-toast-inner` — existing. Icon + text + reward row.
- `toast-icon` — **new, replaces `toast-star`.** Wrapper for the check / star SVG. **Delete `toast-star` from the stylesheet.**
- `toast-text` — existing. `<small>` eyebrow ("MILESTONE") over `<strong>` title.
- `toast-reward` — existing. `+40 pts`, mono, `--flare`.

---

## All-milestones modal (`GoalsHUD.ts`)

- `tilt-all-goals-overlay` — existing. Modifier on `#tilt-all-goals-modal`.
- `tilt-all-goals-panel` — existing. Modifier on `.overlay-panel`.
- `armory-header` — existing (shared with ArmoryUI). Header row.
- `armory-title-group` — existing. Now holds only `<h2>Milestones</h2>` + the count; the `eyebrow` element is **deleted here**.
- `all-goals-count` — **new.** `7/28` beside the title, mono tabular, `--text-4`.
- `armory-header-right` — existing. Close-button holder.
- `armory-close-btn` — existing. `#btn-close-all-goals`, 44px, now holds the close (X) SVG instead of `✕`.
- `all-goals-scroll` + `custom-scrollbar` — existing. Scroll region.
- `all-goals-grid` — existing. Grid of catalog cards.
- `catalog-goal-card` — existing. One catalog row (`--panel`, `--line`, `--radius-l`).
- `is-goal-done` — existing modifier for a completed milestone.
- `catalog-goal-left` — existing. Glyph + copy.
- `goal-check-glyph` — existing wrapper; now holds the check SVG (`--ok`) when done, the star SVG (`--flare`) when locked.
- `catalog-goal-copy` — **new.** Wrapper around the `<h4>` + `<p>` (previously a bare `<div>`; named so the stylesheet can target it).
- `catalog-goal-right` — existing. Reward + status.
- `catalog-goal-reward` — existing. `+40 pts`, mono, `--flare`.
- `catalog-goal-status` — existing. Chip: `DONE` (`--ok`) / `LOCKED` (`--text-5`), 11px mono uppercase.

---

## Classes I removed — safe to delete from `game.css`

`icon-control`, `armory-badge-control`, `armory-gold-btn`, `command-button`, `secondary-button`, `hud-mode-pill` (see the warning above — only after `TiltGame.updateHUD` stops writing it), `eyebrow` (only on the pause / game-over / all-goals panels; other agents may still use it), `tilt-cinematic-bar`, `tilt-cinematic-bar-top`, `tilt-cinematic-bar-bottom`, `goals-vault-pill`, `toast-star`, `points-row`, `gameover-points-box`.
