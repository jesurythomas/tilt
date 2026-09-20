# classes-game.md — CSS classes toggled or emitted at runtime by TiltGame.ts

Agent: **game** (owns `TiltGame.ts`, `TiltRenderer.ts`, `TiltEntranceCinematic.ts`).
`TiltRenderer.ts` and `TiltEntranceCinematic.ts` emit **no** classes — the renderer
is canvas only, and the cinematic only writes `textContent` into the existing
`.tilt-cinematic-wordmark` and toggles `hidden` on `#tilt-cinematic-overlay`.

Everything below is added/removed by script, so it must exist in the stylesheet
even though it never appears in `index.html`.

---

## State modifiers (new)

- `is-on` — **new.** Set on `#btn-tilt-sound` and `#btn-tilt-music-pause`
  (`.opt-switch`) while that switch is on; removed when off. Always written
  together with `aria-checked="true"/"false"`, so the stylesheet may key off
  either. The button's `textContent` is never written, so the `::after` knob is
  safe. Style the on state as `--ion` fill and the off state as
  `--panel-2` + `--line-hi`.

- `mode-classic` / `mode-gauntlet` / `mode-code-red` — **new, on
  `#tilt-mode-badge` (`.hud-meta-mode`).** Exactly one is present at a time;
  the other two are removed on every HUD tick. `updateHUD()` no longer writes
  `className`, so `.hud-meta-mode` survives and `hud-mode-pill` plus the bare
  `classic` / `gauntlet` / `code-red` classes are **never written again** —
  they can be deleted from `game.css`.
  These are *optional* colour hooks: the badge reads correctly with no rule at
  all. If they are styled, use `--ion` / `--flare` / `--plasma` respectively
  (never `--hazard`) and keep the text at the `.hud-meta-mode` size.
  The same `mode-<id>` names are already emitted by `TiltMenu.ts` on
  `.menu-mode-row`, so scope the rules (`.hud-meta-mode.mode-classic`, …).

## `hidden` (existing utility) — elements script shows/hides

`hidden` is added/removed on each of these; all of them start hidden in markup
except where noted:

- `#tilt-hud-mult` (`.hud-mult-chip`) — shown only while the multiplier is > 1.
- `#tilt-shield-wrap` (`.tilt-shield-wrap`) — shown only while a shield is
  active; `aria-hidden` is flipped in step with it.
- `#tilt-gameover-best` (`.tilt-gameover-best`) — shown only on a new best.
- `#tilt-gameover-milestones` (`.gameover-milestones-list`) — shown only when
  the run completed at least one milestone.
- `#btn-tilt-calibrate` and `#btn-tilt-calibrate-pause` — shown only when the
  control scheme is `gyro`. (`#btn-tilt-calibrate-pause` also carries
  `tilt-compat-hidden`, which must keep winning.)
- `#tilt-pause-scheme-desc` (`.tilt-pause-scheme`) — **starts visible in
  markup**; script adds `hidden` on every run after the player's first, per
  §5. It must therefore be styled as a normal visible paragraph, with
  `.hidden` doing the hiding.
- `#tilt-pause-overlay`, `#tilt-gameover-modal` — unchanged behaviour.
- `#tilt-cinematic-overlay` — unchanged behaviour (cinematic start/finish).

## Injected markup — `#tilt-gameover-milestones` children

`TiltGame.ts` writes this list as innerHTML on the death screen:

- `gameover-milestone-item` — existing. One completed-milestone row.
- `milestone-star` — existing wrapper. **Now holds an inline star SVG
  (`.tilt-icon`, 14px, 1.5px stroke, `currentColor`) instead of the `★`
  character.** Colour it via the wrapper (`--flare`).
- `milestone-info` — existing. `<strong>` title over `<small>` description.
- `milestone-reward` — existing. Reads `+40 pts` (mono, `--flare`); the `PTS`
  suffix is gone.
- `tilt-icon` — already in `classes-shell.md`; reused here.

## Inline styles set by script (no class needed, but the base rule must allow it)

- `#tilt-shield-fill` — `style.width` is set to a percentage string
  (`"64.0%"`). `.tilt-shield-fill` must not set its own `width`, and should
  not transition width faster than a frame.
- `--custom-cursor` on `:root` — unchanged.

---

## No longer written by TiltGame.ts — safe to delete

- `hud-mode-pill`, and the bare `classic` / `gauntlet` / `code-red` classes on
  `#tilt-mode-badge` (the `className =` line is gone).
- Nothing writes `Sound on` / `Sound off` text into `#btn-tilt-sound` any more,
  so `.opt-switch` no longer needs `font-size: 0` to suppress a label — the
  element is genuinely empty. Keeping the suppression is harmless.
