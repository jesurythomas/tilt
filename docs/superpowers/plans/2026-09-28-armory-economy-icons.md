# Armory, economy and icons rework — plan (2026-09-28)

User request (2026-09-28, verbatim essentials): "improve the mobile UI specially the
ARMORY and upgrades. research good practices for upgrades. for blackhole make being
invulnerable a already innate upgrade (no need to purchase it) - fix the money scaling
where it isnt too easy and isnt too hard, fix the scaling of getting money from playing
-> fix the texts, i dont think users need to know what the previous money was i think
just showing how much they earned is ok. no need to know how many coins. add number of
enemies destroyed. a single column for weapon upgrade is fine. we also need to update
the look of the icons for the upgrades and the icons of the powerups in the game itself.
they look really bad". Then: "plan thoroughly and implement, no need for clear and my
wait signal". Every change below is a spec change requested by the user, so it is tagged
`DIVERGENCE(ECON Rn)` / `DIVERGENCE(ARMORY Rn)` / `DIVERGENCE(ICONS Rn)` in code (Law 2
does not apply: the user asked). Rulings are Claude's under "always proceed".

## Findings that drive the plan (2026-09-28)

- **Income today** (TS as ported): points come only from coin pickups (25 × mode, 1.0 /
  1.25 / 1.5) and milestones (57 goals worth **192 pts in total**, 1–8 each). Score is
  never converted. A 9 s Code Red run paid +59 (1 coin + two milestones).
- **Too easy**: a fresh save starts at 7,331, and `load_data` resets any balance under
  500 back to 7,331 (TS `ProgressionManager.ts:491`) — money is effectively unlimited.
- **Costs today**: perk ranks 300/600/1,100/1,800/2,800 (6,600 per track); boosts up to
  15,000 a rank (91,100 in all); keystones 2,500–5,000; everything from fresh 208,300.
- **Keystones**: the Armory lists 14; 8 cannot be bought (their keys are not perk
  fields) and 3 buyable ones have no coded effect (Fallout Zone, Battering Ram,
  Shatter Cascade — none in the TS either). Only Aegis (`invulnerableInside`),
  Supernova and Cross Beam do anything.
- **Aegis**: `WeaponSystem` re-applies a 0.3 s shield each tick while the ship is inside
  an active black hole's pull radius, only if the keystone was bought (2,500 fallback).
- **Score explodes** with combos (16,149 in 9 s in Code Red): unusable for payout.
- **Icons**: Armory weapon icons are the TS 30×30 outline SVGs (strokes 1.2–2.5 px) in
  a 22 px box; playfield orbs are a flat 0.65-alpha disc with a thin 1.6 px white glyph
  drawn with draw_* lines; the two use different colours per weapon (Armory dot colours
  repeat: missiles = laser = ion, nuke = lightning = flare). HUD weapon timer has no icon.
- **Armory layout** (landscape, 844×390 reference): weapon list (196 px) | detail with
  two columns (tracks 1.65 : keystones 1). Track cards show name, "+0.5s / rank", the
  value line, pips, a cost button (disabled when unaffordable — no reason given).
  Boosts: 2-column grid, effect text truncated ("+10% in-run score …").
- **Run over**: "Points earned +59 → 33,314", a "Coin pickups 1 · +53 pts" row, milestone
  rows with +2/+3 pts, stats Kills / Best chain / Alive, "Spend 33,314" button.

Research brief (subagent, 2026-09-28; sources: vampire.survivors.wiki PowerUps, Rogue
Legacy wiki, gamedeveloper.com "Math of idle games", machinations.io inflation, NN/g
touch targets and squint test, "Juice it or lose it"): single-column cards; card = icon,
name, pips, *current → next* as numbers, cost; four states (affordable, short "need N",
MAX, locked); purchase juice; geometric ~1.6× per rank (≈16× base over 5 ranks, VS's
linear rule totals 15×); rank 1 ≈ one early run, maxing a weapon ≈ 8–12 runs, everything
≈ 60–100 runs; earnings = floor + time + sublinear performance term, never raw score;
results hero = "+N earned" count-up, skippable; no previous balance; a "next purchase"
nudge; one glyph per power-up on a 24 grid, one colour per weapon used everywhere,
silhouette/greyscale readable at 24 px.

## Rulings

- **ECON R1 — Run payout.** At the death tick, before `run_ended`, the run banks
  `round((60 + 3·t + 4·k^0.7) × mode)` where t = `stats.survival_time` (the "Alive"
  seconds shown) and k = `stats.kills`, mode = the mode's score multiplier (1.0 / 1.25 /
  1.5), through `add_points_credited` (so the Points Multiplier boost applies). Coins
  stay as a live income at **10** × mode (was 25). Milestone rewards × **50** (catalog
  values scaled once at construction: 50–400 each, 9,600 in all).
  Model (Classic, coins at ~40% pickup): novice 40 s/30 kills ≈ 250; early 70 s/90 ≈
  420; mid 150 s/500 ≈ 970; good 300 s/1,800 ≈ 2,070; expert 540 s/5,000 ≈ 3,840.
  Code Red ×1.5. Constants live in `ProgressionManager` (`RUN_PAYOUT_*`), one place to
  retune after the device pass.
- **ECON R2 — Costs.** Perk ranks 250 / 400 / 650 / 1,000 / 1,600 (×1.6, 3,900 a track).
  Keystones keep the TS prices (Cross Beam 3,500, Supernova 5,000). Boost ladders:
  extra life 2,500 / 6,000; hull compact 800 / 1,600 / 3,000; enemy slow 1,000 / 2,000 /
  3,600; score multiplier 500 / 1,000 / 1,800 / 3,000; points multiplier 1,200 / 2,400 /
  4,200 / 7,000. Ships, enemy skins and arenas keep their TS prices (the cosmetic sink).
  Everything from fresh ≈ 112,750 → ~115 mid runs, ~55 good runs, ~30 expert runs;
  first rank-1 perk after ~1 early run; one weapon (3 tracks) ≈ 12 mid runs.
- **ECON R3 — Starting balance and the reset quirk.** A fresh save starts with **500**
  (was 7,331). The "< 500 → 7,331" load reset and the 7,331 lifetime floor are removed.
  Existing balances are kept as they are (no rescale of saved points).
- **ECON R4 — Dead keystones leave the shop, with refunds.** The Armory shows only
  keystones with an effect: Supernova (blackhole) and Cross Beam (laser). The other 12
  cards go. Saves that own Fallout Zone, Battering Ram, Shatter Cascade or Aegis get
  their price back once on load (3,000 / 3,000 / 2,500 / 2,500) and the flag is cleared
  (the save keys stay, so old files load). Weapons with no keystone show none.
- **ECON R5 — Aegis is innate** (user). The black hole always shields the ship inside
  its pull radius; `invulnerableInside` no longer gates it. The Blackhole detail shows
  an "Innate · Safe inside the well" line instead of a card.
- **ARMORY R1 — Weapons tab single column** (user). Detail = header, then one column:
  track cards, then (if any) a "Keystone" caps label and its card(s). The weapon list
  keeps its column; rows gain the weapon's icon (20 px) instead of the square dot, the
  rank text becomes ranks bought / ranks total ("9/15"), and a small flare dot marks a
  weapon with an affordable upgrade.
- **ARMORY R2 — Upgrade card** (shared by tracks and boosts): icon-free row (the weapon
  header carries the icon; boost cards carry theirs) with name, the value as *current →
  next* (next in the weapon colour; bare value when maxed), 5 pips, and a 48 px action:
  cost (affordable), "need N" (short: dimmed, disabled — the shortfall, not a silent
  disabled button), or a MAX badge. The "+0.5s / rank" line goes (current → next says
  it). A purchase pops the newly filled pip (scale tween) and flashes the balance
  (existing).
- **ARMORY R3 — Boosts tab single column** with icons, same card, value current → next
  ("Lives 1 → 2", "Hitbox 94% → 88%", …), no truncated effect text.
- **ICONS R1 — One icon set.** New `godot/src/render/weapon_icons.gd` (no TS
  counterpart, like circle_sprites.gd): a 24-unit SVG glyph per weapon (nuke, missiles,
  lightning, laser, black hole, freeze, shield) and per boost (life, hull compact, enemy
  slow, score, points) — filled silhouettes, one visual weight, rasterised and cached
  per size. One colour per weapon everywhere = the playfield orb colours
  (`WeaponSystem.get_weapon_color`): Armory icon boxes, list icons, HUD timer tint and
  orbs. Checked by rendering the sheet at 24/48 px and in greyscale.
- **ICONS R2 — Playfield orbs** drawn from a baked sprite per weapon (dark core disc,
  weapon-colour rim, white glyph at ~60% of the diameter), rasterised at the orb's
  on-screen size; glow halo, pulse and expiry blink unchanged. One texture draw per
  orb (was ~6 draw calls).
- **ICONS R3 — HUD weapon timer** gets the weapon's icon (16 px) left of its label.
- **RUNOVER R1** (user): hero line "+N pts" earned (the whole run's credited total:
  payout + coins + milestones, counting up over ~0.6 s, a tap skips); no "→ balance",
  no coin row. Stats: **Destroyed** (enemies destroyed — was "Kills"), Best chain,
  Alive. Milestone rows keep their (scaled) reward. A hint "N upgrades ready" when the
  new balance affords any next rank (else hidden). The Armory button reads "Armory".

## Tasks

- [x] **T1 — Economy core** (done: `PERK_COSTS`, ladders, `STARTING_POINTS`, `DEAD_KEYSTONE_REFUNDS` in progression_manager.gd; test fixtures that buy now fund themselves with 7331; suite 714) (ECON R2, R3, R4 data side): costs, ladders, start balance,
  load quirk removed, one-time keystone refunds. Tests: update
  `test_progression_economy/parity/manager/armory_ui` pins to the new numbers (parity
  test keeps comparing the TS fixture for everything else; cost fields are asserted as
  DIVERGENCE values); refund test (each dead keystone refunded once, flag cleared, a
  second load does not refund again).
- [x] **T2 — Run payout** (done: `run_payout` + `RUN_PAYOUT_*`, `RunController.credit_run_points` / `points_credited_this_run` / `run_payout_credited`, coins 10, `GoalManager.MILESTONE_REWARD_SCALE`; ruling on the way: the run's credit total resets at run start and never closes, because the death tick's step 8 live goals credit after run_ended; suite 717) (ECON R1): `ProgressionManager.run_payout(t, k, mode)` +
  constants; banked in `RunController.trigger_player_death` before `run_ended`; coin
  value 10; milestone rewards ×50 at catalog build; `points_credited_this_run` counts
  every credited point (coins, milestones, payout) for the sheet. Tests: formula values,
  banking once, points multiplier applied, coin value, goal rewards ×50 vs fixture.
- [x] **T3 — Aegis innate** (done: weapon_system.gd shields unconditionally inside the pull radius; +1 outside-radius test; suite 718) (ECON R5): `WeaponSystem` shields inside the radius
  unconditionally; test (no keystone → shielded inside, not outside).
- [x] **T4 — Icon set** (done: `render/weapon_icons.gd` (`WeaponIcons`: 12 glyphs, orb sprite, colours; `WeaponSystem.get_weapon_color` made static); `bench/icon_sheet.gd` renders `godot/build/icon_sheet.png` — reviewed; the laser needed three redesigns ("O=", then a wand, then a compass) and is now a hub with two beams and motion arcs; `tests/test_weapon_icons.gd` 4 tests) (ICONS R1): `weapon_icons.gd`, glyph SVGs, colour table, cached
  textures; a render sheet (`bench/icon_sheet.gd`, windowed) for review at 24/48 px and
  greyscale; tests (every weapon/boost has a glyph, SVG parses, texture size).
- [x] **T5 — Orbs and HUD** (done: EntityLayer draws `WeaponIcons.orb_texture` (one draw per orb; `_draw_orb_glyph` removed), main.tscn WeaponTimerRow > WeaponTimerIcon + label, tint = `WeaponIcons.ui_color_of`; emulator screenshot checked (restarted the emulator first: 13 h up, 164% irq, fps 1); the PERF line lost `rcpu` (it forced a sync and logged an engine warning)) (ICONS R2, R3): baked orb sprite in EntityLayer, HUD timer
  icon. Tests: sprite cache keys, HUD icon visible with the timer; screenshot check.
- [x] **T6 — Weapons tab** (done: `_upgrade_card` + `UpgradeRow` shared row, `weapon_ranks`, CanBuy dots, `_innate_note`, pip pop; catalog keystones = Supernova + Cross Beam; ARMORY R4 ruling on the way: the freeze weapon is "Freeze" (TS Armory: "Shockwave") to match the HUD and its icon. Emulator screenshot caught value labels collapsing to 0 px (clipping labels in an HBox) — fixed + a width test that fails on the old code. `tools/emulator/deploy.sh [--fresh]` added (waits out adb restarts). Suite 728) (ARMORY R1, R2, ECON R4/R5 UI). Tests updated/added: single
  column (no keystone column), card states (cost / need N / Max), "9/15" rank text,
  affordable dot, only Supernova/Cross Beam keystones, the innate line; fit tests at
  844×390 and 2340×1080 stay green.
- [ ] **T7 — Boosts tab** (ARMORY R3). Tests: single column, current → next strings,
  fit.
- [ ] **T8 — Run over** (RUNOVER R1). Tests: strings, no balance/coin rows, Destroyed
  label, upgrades-ready hint, count-up skip, fit.
- [ ] **T9 — Verify**: suite, gdformat/gdlint, headless boot, emulator screenshots of
  every Armory tab, the run over and orbs mid-run (Read them); FPS check (PERF line) —
  orbs must not cost more; HANDOFF, VERIFY-ME (device checks for feel and economy
  tuning), commit.
