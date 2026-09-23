# Peril Point — Mobile Interface System: Design

**Date:** 2026-09-23
**Status:** approved in brainstorming 2026-09-23, awaiting written-spec review
**Amends:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md`
(§4.5, §7, §8 Modules 8/9/11) and `godot/CONVENTIONS.md` §5
**Design source:** `peril-point-mobile-redesign/` (14 boards + `canvas.json`),
committed with this spec. Board file names below are relative to that folder.

---

## 1. Summary

The port so far copies the web game's look (`web/src/styles/game.css`, the
CSS injected by `TiltGame.ts`). A mobile redesign now exists as 14 boards
drawn at an 844×390 landscape reference. This spec makes those boards the
**visual authority** for every Godot UI surface, defines how code cites them,
and splits the resulting work into modules:

- **M8.5 — Interface rework (new):** shared theme and fonts; rebuild the HUD,
  Pause, Run over and all five Armory tabs to the boards.
- **M9 — Milestones (re-planned):** the goal logic stays as planned; its UI
  (rail, toast, Milestones screen, run-over rows) is built to the boards.
- **M11:** builds Menu, Cold open, Calibrate and Settings from their boards.

Order: **M8.5 first**, then M9, then the remaining modules.

## 2. Authority split

| Concern | Authority |
|---|---|
| Game logic, rules, numbers that change play, what a control *does* and when | The TypeScript source (port laws 1–5 unchanged) |
| Layout, colour, type, sizes, spacing, which surface a thing lives on, which controls a screen shows | The boards |
| Anything neither covers | Stop and ask (LAW 5) |

**Board content is placeholder.** Names, numbers and counts in the boards'
mock data (e.g. 36 milestones, "Void Walker", "Shockwave", "14/36") are
illustrative. Real content always comes from the ported catalogs. User
ruling 2026-09-23.

**Behaviour a board implies but the TS lacks** is not adopted unless this
spec lists it in §6 (each such item was ruled on individually).

## 3. Citation model (amends CONVENTIONS §5, spec §7)

- A visual literal taken from a board carries
  `# DIVERGENCE(UI-SYSTEM): <Board>.dc.html` (optionally `— <token or note>`),
  e.g. `const SHEET_RADIUS: int = 10  # DIVERGENCE(UI-SYSTEM): Pause.dc.html`.
- Token constants in `UiTheme` cite `System.dc.html` once per group.
- Behaviour keeps `# PORT: web/src/...ts:NN`.
- A `game.css` citation remains valid only for values the boards do not
  define. When a board defines a value, the board wins and the old citation
  is replaced, not kept alongside.
- M8.5 edits `CONVENTIONS.md` §5 to add the `DIVERGENCE(UI-SYSTEM)` form, and
  spec §4.5/§7 gain a one-line pointer to this document.

## 4. Foundations

### 4.1 `UiTheme` replaces `ArmoryTheme`

`src/ui/armory_theme.gd` becomes `src/ui/ui_theme.gd` (`class_name UiTheme`,
static members only, never instantiated). Every UI surface — HUD included —
uses it. Colour tokens, named as on `System.dc.html`:

| Token | Hex | Use |
|---|---|---|
| void | `#08090E` | cold open, scrims |
| arena | `#0D1016` | play field |
| shell | `#0B0E14` | full-screen menus (Armory, Milestones, Menu, Settings) |
| sheet | `#12161F` | Pause, Run over |
| panel | `#141821` | cards, rows |
| raised | `#1B2029` | selected tab, tracks |
| line | `#262C38` | hairlines |
| line_strong | `#3A4252` | button borders |
| text | `#E6E9F0` | primary |
| text_muted | `#99A1B3` | secondary |
| ion | `#5B8CFF` | action, progress |
| flare | `#FFB14D` | points, Gauntlet |
| plasma | `#A78BFA` | keystones, Code Red |
| locked_in | `#3DDC97` | owned, done |

`hazard #FF4757` is **not** a `UiTheme` token (rule 01: never in chrome); it
stays with the render layers. Secondary literals the boards use repeatedly
(`#7A8397` faint text, `#C7CDDB` secondary text, `#626B7E`, `#A08A5C` points
unit, `#8FB0FF` ion text, `#C4B0FD` plasma text, `#10141B` locked card,
`#161B25` stat cell, `#0F131B` done card) are `UiTheme` constants citing the
first board that uses each.

**Component variations** (`theme_type_variation`, from `System.dc.html`):

| Variation | Base | Spec |
|---|---|---|
| PrimaryButton | Button | h 56 hero / 48, ion fill, text void, r 6 |
| SecondaryButton | Button | h 48, transparent, line_strong 1px, text `#C7CDDB`, r 6 |
| IconButton | Button | 48×48, 16px stroke icon, line 1px, r 6 |
| CostButton | Button | h 48, Plex Mono, ion 12% fill + ion border, text `#8FB0FF`, r 4 |
| Segmented | HBoxContainer + ButtonGroup | h 48, arena bg, line border, pad 3, gap 3; selected: raised + line_strong |
| Switch | CheckButton | 48×28; the whole row (48 tall) is the target |
| Pips | HBoxContainer of ColorRect | 5px tall, gap 4, ion filled / line empty |
| Chip | Label + StyleBoxFlat | tint text, tint 12% fill, tint 45% border, r 3 |
| Card | PanelContainer | panel, line 1px, r 6 |
| Sheet | PanelContainer | sheet, line 1px, r 10, drop shadow |
| Meter | ProgressBar | 3px, raised track, no label |

`ArmoryUI`, `HandlingPreview`, `HudController`, `GoalsHUD` and every later
screen reference `UiTheme`; no file keeps private copies of token hexes.

### 4.2 Fonts

Bundle, with their SIL OFL licence files, in `godot/assets/fonts/`:

- **Archivo** (variable; `wdth` and `wght` axes) — titles and wordmark via a
  `FontVariation` at width 112 (titles) / 118 (wordmark), weight 700.
- **IBM Plex Sans** 400/500/600 — labels, body, buttons.
- **IBM Plex Mono** 400/500/600 — **every numeral**, with tabular figures
  (`tnum` OpenType feature enabled on the `FontVariation`).

Type scale (base px, from `System.dc.html`): wordmark 42–58; screen/item
titles 21–28; HUD score 30, run-over score 54; labels and button text 14–15
(600); one-line descriptions 12–13 (400); caps labels 10–11 (Mono 600,
uppercase). **Nothing below 10 base px.** Letter-spacing (+0.14em on caps
labels) is applied where Godot supports it (`FontVariation.spacing_glyph`);
where it does not, it is omitted with a note.

Downloaded from the official sources (Google Fonts for Archivo; the
`IBM/plex` GitHub release for Plex). The M8.5 plan records exact file names,
versions and sizes; the APK grows by roughly 1–2 MB.

### 4.3 Scale reference

All board sizes are base values × `ui_scale`. The boards are drawn at a
390-px landscape height, so:

```
ui_scale = min(viewport.x, viewport.y) / 390
```

replacing `HudController.UI_SCALE_REFERENCE = 720`. On the A55 (≈2340×1080
physical) this is ≈2.77, up from 1.5 — every existing HUD element grows
≈1.85×, which is the intent (48 base px ≈ a 48 dp touch target). Width never
drives scale: extra width on longer phones goes to the arena and to
scrolling rows, never to bigger chrome (`System.dc.html`). The clamp bounds
are re-derived in M8.5 so a 1280×720 desktop window stays usable (it yields
≈1.85, which the plan checks fits every screen).

### 4.4 Arena frame

A 1px outline in ion at 28% alpha (`Hud.dc.html`) is drawn at the existing
playfield inset (`GameRoot.arena_inset`, unchanged: min 8/12 px, max 4% per
axis). Every HUD control anchors to this frame, never to the screen edge.

### 4.5 Rules as checks

The five `System.dc.html` rules are enforced where a test can see them:

1. Red never in chrome → no `UiTheme` token or UI file literal equals
   `#FF4757` (grep check in the plan's verification block).
2. Nothing in the UI glows → no shadow/glow on Controls except the Sheet's
   drop shadow (review check).
3. One idea per line → descriptions render single-line with ellipsis where
   the board does (`text_overrun_behavior`).
4. Thumbs own the bottom corners → primary actions bottom-right on sheets
   (layout test asserts the primary button's rect is in the right half).
5. **48 or it does not ship** → headless test: every visible `Button` in each
   rebuilt screen has `size.y >= 48 * ui_scale`; hero buttons `>= 56 * ui_scale`.

## 5. Unbuilt features policy (user ruling 2026-09-23)

A control on a board is built when something real backs it; otherwise it is
hidden and tagged `TODO(Mx)` for its owning module:

| Control | Backing | M8.5 treatment |
|---|---|---|
| Restart run (Pause) | `GameRoot.restart_run()` | built |
| Sound / Music switches (Pause) | `GameOptionsManager.settings.sfx_enabled / music_enabled` (persisted today) | built; audible effect lands with M5/M6 |
| Calibrate IconButton (Pause), Calibrate tilt (Handling) | `TiltInput.calibrate_current_position()` + `GoalsHUD.show_message_toast` (`TiltGame.ts:2330-2340`) | built as an immediate calibrate + toast; the Calibrate *screen* (`Calibrate.dc.html`) is M11 |
| Quit to menu (Pause), Menu (Run over) | no menu until M11 | hidden, `TODO(M11)` |
| Settings (Pause) | no settings screen until M11 | hidden, `TODO(M11)` |
| Spend N (Run over) | `GameRoot.open_armory()` (`TiltGame.ts` spendBtn) | built |

Before M9 lands, the calibrate toast has no `GoalsHUD` to show on; M8.5
calibrates silently and tags `TODO(M9)` for the toast.

## 6. Screens

Behaviour is unchanged unless listed under "New" (each New item is a port
of existing TS behaviour, cited `# PORT:`) or "Ruled" (a user ruling).

### 6.1 HUD — `Hud.dc.html` (M8.5)

- Arena frame (§4.4).
- Top centre: score (Mono 500, 30), "BEST n" (Mono 11, faint), multiplier as
  a **Chip** tinted by the existing HUD-feedback tier colour
  (`HudController.tier_color_for`, thresholds 2/5/10/20 match
  `System.dc.html`'s tier row). The kill pulse (2026-09-21 spec) is kept.
  The chip hides at 1×, as the label does today.
- Top-left column inside the frame: **lives icons** (New — ship glyphs,
  `#C7CDDB` filled for remaining, `line_strong` for lost, count =
  `maxLivesThisRun`; `TiltGame.ts` lives HUD), then the goal-toast slot
  (filled by M9).
- Top-right: Pause IconButton 48×48.
- Bottom centre: **weapon timer meter** (New — `TiltGame.ts:2195-2214`):
  caps label "SHIELD 1.6s" in the weapon's colour, Meter 160×3 below it;
  hidden when no timed weapon is active.
- The floating joystick is unchanged.

### 6.2 Pause — `Pause.dc.html` (M8.5)

Sheet 620×342 (r10, pad 24) centred over a void 80% scrim; two columns,
gap 28, hairline divider.

- Left: "Paused" (Archivo 26); line "score · m:ss · Mode name" (Mono 13,
  faint); **Resume** (Primary 56); **Restart run** (Secondary); Quit to menu
  hidden (§5).
- Right: caps "STEER"; Segmented **Touch | Tilt** + Calibrate IconButton;
  Sound and Music Switch rows (48 tall, hairline between); bottom row
  **Armory** (Secondary); Settings hidden (§5).
- **Ruled:** the Keyboard steer option is shown only when
  `not OS.has_feature("mobile")` (desktop testing); the board shows Touch |
  Tilt only.

### 6.3 Run over — `RunOver.dc.html` (M8.5; rows' content M9)

Sheet 700×346 over a void 86% scrim; two columns, gap 28.

- Left: score (Mono 54); subtitle "Swarmed at m:ss — Mode, 1.0×"
  (`TiltGame.ts` finalSubtitle); **New best — up N** banner (flare 8% fill,
  30% border) when `isNewBest && bestScoreDiff > 0`; 3-cell stat grid
  **Kills · Best chain · Alive** (cells `#161B25`, 1px line gaps).
- Right: **Points earned +X → Y** row; earned-milestones list (M9 fills it;
  hidden when empty); caps "STEER" + Segmented; **Retry** (Primary 56);
  bottom row Menu (hidden, §5) + **Spend N** (Secondary, points in flare
  Mono) → `open_armory()`.
- **Ruled:** the coins stat cell and coins row are dropped (the board shows
  three stats); coin points stay inside the "Points earned" total.
- **Ruled (R1, kept):** tapping the points row or the milestones list opens
  the Milestones screen (the board draws no affordance; the behaviour is
  `GoalsHUD.ts:129-135`'s).

### 6.4 Armory — `ArmoryWeapons|Ships|Arena|Handling|Boosts.dc.html` (M8.5)

All purchase/equip/tuning behaviour and M8's tests unchanged.

- **Shell:** full screen, shell colour (no overlay panel, no inset panel on
  mobile). 64px header (pad 8/28/8/24, line-bottom `raised`): Back IconButton
  (= close), "Armory" (Archivo 21), five 48px tabs (selected: raised fill,
  text 600), flex gap, points "7,331 PTS" (Mono 15 flare + 10px unit
  `#A08A5C`), **Play** Primary 92×48 in the header. The close ✕ and the
  mobile sticky Play footer are removed.
- **Weapons:** left list 196px (48px rows: 8px colour dot, name, rank
  "n/max" Mono 11; selected raised + line_strong); bottom fade 36px. Detail:
  44px tinted icon box, title (Archivo 21) + one-line description,
  "INVESTED" caps + flare Mono value right-aligned. Grid 1.65fr | 1fr, gap
  12: tracks as 62px Card rows (name 14/600 + per-rank effect Mono 11, Pips,
  CostButton 88×48); keystones as plasma-tinted cards with a cost button
  (locked: `#10141B` card, lock glyph, disabled cost).
- **Ships:** caps "HULL · n of 7" + "Changes hitbox and turn rate. Nothing
  else."; horizontally scrolling row of 172px cards (r8): 82px arena-colour
  preview, name 15/600 + trait Mono 11, **Hitbox** and **Turn** meters, 48px
  action (Equipped: locked_in border + 10% fill; Equip: Secondary; Buy:
  CostButton "600 pts"; unowned card `#10141B` and muted name).
  **Ruled (New):** meter fraction = the ship's value ÷ the largest value of
  that stat across the ship catalog (`hitbox_scale`, `turn_rate`).
- **Arena:** caps "ARENA" and "ENEMIES" rows, each a horizontally scrolling
  row of 146px card-buttons: 56px preview (theme: grid + edge in the theme's
  colours; enemy: three dots in the skin's body/rim), name 13/600, state line
  Mono 11 ("✓ Equipped" locked_in, "Owned" muted, "N pts" flare). Tapping
  the card buys or equips, as the current buttons do. Enemy-dot glow on the
  preview is dropped (rule 02 applies to UI previews).
- **Handling:** two columns, gap 28. Left: **Turn rate** slider (as today)
  and **Tilt sensitivity** slider; each field: label 15/600, value Mono 14
  ion, hint 12 muted, 40px slider, min/max row Mono 11. Bottom row:
  **Calibrate tilt** (Secondary, §5) + **Reset** (Secondary). Right: caps
  "LIVE PREVIEW — TILT OR DRAG", the `HandlingPreview` box (arena, 34px grid,
  line border, r8) with its "still" / "top speed" legend.
  **Ruled:** the second slider is `ControlSettings.tilt_sensitivity`
  (range 0.5–2.0×, as the board), replacing Deadzone. The deadzone value
  keeps its saved setting and stays in effect; it leaves the UI (candidate
  for M11 Settings). Reset restores both sliders' defaults.
- **Boosts:** caps "BOOSTS" + "Permanent. They stack into every run."; 2-col
  grid, gap 8, of 76px Cards: name 14/600 + effect Mono 11, Pips (max width
  180), cost button 92×48 (CostButton; at max rank: text "Max", line border,
  faint text, disabled).

### 6.5 Milestones and goal UI (M9)

Goal logic, the 57-goal catalog and rulings R3–R7 of the M9 plan are
unchanged. UI:

- **Rail:** a 3px ion line on the **top edge of the arena frame**, starting at
  the frame's left corner, width = frame width × completed ÷ total
  (`Hud.dc.html`). Not tappable. Hidden in menu mode.
- **Toast:** Card at 92% panel alpha, line 1px, r6, pad 9/12, gap 9: 14px
  locked_in check, title 13/500, "+N" Mono 12 flare. Placed in the HUD's
  top-left column **under the lives icons**. Timers 3.0 s (goal) and 2.8 s
  (message) as `GoalsHUD.ts`. The message toast uses the same card with the
  ion ring icon and the subtitle in muted 12.
- **Milestones screen** (`Milestones.dc.html`): full screen, shell colour,
  the Armory's 64px header pattern: Back, "Milestones" (Archivo 21), flex
  gap, counter "n/57" (Mono 13; denominator faint), 120×4 track (raised;
  ion fill), points "N PTS". Body pad 12/28/0/24: **three tier columns side
  by side** (Score, Combat, Mastery; gap 14), each independently scrolling,
  with a 40px shell-colour fade at its bottom. Column head: caps tier name in
  the tier tint (10) + "d of t" (Mono 11 faint). Cards 58px (pad 0 12,
  gap 11): 20px mark (done: locked_in fill + check; open: line_strong
  border), name 13/500 single line with ellipsis (done: text_muted; open:
  text), goal line Mono 11 faint single line with ellipsis, optional 3px bar,
  "+N" Mono 12 (done: faint; open: flare).
  **Ordering:** within each tier, open goals first then done goals, each in
  catalog order. **Content:** done → description; open lifetime goal →
  "x / y" + bar; open run or unlock goal → description, no bar (as
  `GoalsHUD.ts`).
- **Openers:** tapping the run-over points row or milestones list (§6.3, R1);
  the `M` key on desktop; the Menu's Milestones button (M11). Back and
  Escape close it.

### 6.6 M11 boards

`Main.dc.html`, `ColdOpen.dc.html`, `Calibrate.dc.html` and
`Settings.dc.html` are built in M11 to this system. Their mock content and
any behaviour they imply beyond the TS need their own rulings at M11.

## 7. Testing and verification

- **Behaviour guard:** every existing spec (M8's purchase paths, pause ↔
  Armory flow, HUD score pulse, control picker) keeps passing. Tests that
  assert on node names or layout the redesign removes are updated in the
  same task, with the reason in the commit message; tests asserting
  behaviour are never weakened.
- **Per-screen headless specs:** required nodes exist; the 48 rule (§4.5);
  no overlapping siblings after one `process_frame`; key surfaces carry
  their token colours; hidden-until-M11 controls are absent or invisible.
- **New pure logic gets unit specs:** `ui_scale_for` at 390/844×390, A55 and
  desktop sizes; ship meter normalisation; lives icon counts; weapon timer
  label and fraction; milestone open-before-done ordering.
- **Rule 01 check:** `grep -rniE "ff4757" godot/src/ui/` prints nothing.
- **Device:** each module appends a `VERIFY-ME.md` section of eyeball checks
  against the boards on the A55. M8's pending device pass is folded into
  M8.5's (the Armory it would check is rebuilt).

## 8. Module changes

| Module | Change |
|---|---|
| **M8.5 — Interface rework** (new, deps M8) | §4 foundations, §5, §6.1–§6.4. Plan: `docs/superpowers/plans/2026-09-23-m8.5-interface-rework.md`. Task order: fonts + `UiTheme` + scale → HUD → Pause → Run over → Armory shell + Weapons → Ships + Arena → Handling + Boosts → device pass → exit. |
| **M9 — Milestones** | Tasks 1–4 of `2026-09-20-m9-milestones.md` (SaveStore list, GoalManager, evaluation, run tracker) unchanged. Tasks 5–7 are rewritten to §6.5 on `UiTheme`. Deps become M7 + M8.5. |
| **M11** | Adds §6.6. |
| `PORT-PROGRESS.md` | Gains an M8.5 row. M8 stays "code complete"; its device pass moves to M8.5's. |

## 9. Out of scope

- New goal content or mechanics implied by the boards' mock data (per-run
  best tracking, new goals).
- Menu backdrop, cold open and Settings behaviour (M11).
- Audio (M5/M6); the Sound/Music switches only persist settings until then.
- Any change to sim, render layers or frame order.
