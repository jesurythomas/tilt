# Achievements, keystones and a UI pass — plan (2026-09-28)

User requests (2026-09-28), in order: "rename milestones to achievements, when there are
multiple achivements completed on a run, the user cannot see all of those achievements";
"dont use eleven upgrades ready in the armory - dont use need x amount, just the standard
amount it needs to upgrade"; "dont markj blackhole as innate keystone, make sure abilities
have atleast 3 keystones each"; "also take screenshots of all sections of the app --
redesign if needed to make ui/ux feel better as a player". Rulings are Claude's under
"always proceed".

## Rulings

- **ACH R1** — player-facing "Milestone(s)" → "Achievement(s)" (screen title, menu button,
  menu stat, reset text, the two "points in total" goals). Code identifiers keep their
  names (they mirror the TS files).
- **ACH R2** — the Run over lists every achievement completed during the run
  (`RunController.run_achievements`, appended by GameRoot's goal callback), not only
  evaluate_run's.
- **ACH R3** — the list moved to the left column under the stats, scrolls, has an
  "ACHIEVEMENTS · N" header, and rows show the title + reward (a tap's release opens the
  screen; a drag scrolls).
- **ACH R4** — achievement toasts queue (1.6 s each while more wait) instead of replacing
  each other.
- **USER 2026-09-28** — no "N upgrades ready" line on the Run over; Armory buttons show the
  plain price, disabled when short (no "Need N").

## Tasks

- [x] **A1 — Achievements** (ACH R1–R4 + the two user removals). Tests: toast queue, list
  scroll + header, release-to-open, mid-run achievement listed (mutation-checked), plain
  price. A55-size render `bench/shot_run_over.gd` → `godot/build/run_over_a55.png` reviewed:
  3–4 rows visible, scrollbar, the rest reachable. Suite 733.
- [x] **A2 — Keystones: 3 per weapon, no "innate" row** (done: 21 keystones in the perk records + `Tuning.KEYSTONE_COSTS`; effects in weapon_system.gd (`_burst`, `_nuke_ended`, `_launch_missiles`, `_chain_lightning`, fallout zones, salvo queue, Overcharge) and run_controller.gd (Battering Ram, Shatter Cascade, Coin Vacuum); EffectLayer draws the fallout zone; Armory shows 3 cards per weapon; `tests/test_keystones.gd` 19 tests, each with and without its keystone; suite 752).
  **KEY R1** (user: "make sure abilities have atleast 3 keystones each"): every power-up
  sells three one-off keystones, each with a coded effect. TS names and prices are kept
  where the TS named one (its 14, none of which except Supernova and Cross Beam were
  coded); the rest are new. `DEAD_KEYSTONE_REFUNDS` shrinks to Aegis alone (Fallout,
  Battering Ram and Shatter Cascade are live again, so owners keep them).
  **KEY R2** (user: "dont markj blackhole as innate keystone"): no "Innate" row; the
  black hole's inside-shield stays innate (ECON R5) and its description says so.

  | Weapon | Keystone (save key) | Cost | Effect |
  |---|---|---|---|
  | Blackhole | Supernova (`supernovaCollapse`) | 5,000 | collapse shockwave 320 (TS) |
  | | Event Horizon (`eventHorizon`) | 3,000 | dots die at 54 px from the core (30) |
  | | Dark Harvest (`darkHarvest`) | 4,000 | +0.05 s per dot swallowed, up to +2 s |
  | Missiles | Cluster Split (`clusterSplit`) | 2,500 | a blast splits into 2 short-lived missiles (once) |
  | | Hyper Thrusters (`hyperThrusters`) | 4,000 | lock on at launch, 620 px/s, sharper turns |
  | | Second Salvo (`secondSalvo`) | 5,000 | a second full salvo from the ship 0.6 s later |
  | Laser | Cross Beam (`crossBeam`) | 3,500 | second perpendicular beam (TS) |
  | | Heavy Beam (`heavyBeam`) | 3,000 | beam hit width 14 → 28 px |
  | | Rapid Sweep (`rapidSweep`) | 4,000 | sweeps 1.5× faster |
  | Nuke | Fallout Zone (`falloutZone`) | 3,000 | 3.0 s burn zone at 40 % of the blast radius |
  | | Chain Reaction (`chainReaction`) | 5,000 | 1 in 8 vaporized dots bursts, killing within 60 px |
  | | Stun Wave (`stunWave`) | 3,500 | survivors within 1.5× the radius freeze 2 s |
  | Freeze | Shatter Cascade (`shatterCascade`) | 2,500 | a shatter also shatters frozen dots within 70 px |
  | | Cryo Nova (`cryoNova`) | 4,000 | the pickup kills every dot within 200 px |
  | | Ice Armor (`iceArmor`) | 3,000 | a 2 s shield on pickup |
  | Shield | Battering Ram (`batteringRam`) | 3,000 | a ram kills dots within 60 px of the rammed one |
  | | Overcharge (`overchargePulse`) | 4,500 | when the shield ends, a pulse kills within 180 px |
  | | Coin Vacuum (`coinVacuum`) | 3,000 | while shielded, coins anywhere fly to you |
  | Lightning | Arc Detonation (`plasmaArc`) | 3,500 | each struck dot kills within 45 px |
  | | Superconductor (`superconductor`) | 4,500 | chain jump range ×2 |
  | | Forked Lightning (`forkedLightning`) | 5,000 | a second chain from the pickup |

  Radii scale with the arena like the TS's tuned ranges. Effects are added code, so
  their numbers carry `DIVERGENCE(KEY R1)` rather than a TS citation.
- [x] **A3 — Screenshot every section, redesign what plays badly** (done). Shot on the
  emulator (fresh save): menu, Armory ×5 (Weapons scrolled to its keystones), Achievements,
  Settings, cold open, HUD in a run, Pause, Run over; all read. Fixed:
  - **UI R1** menu stats row (Best / Points / Achievements) always shows — a new player
    saw no balance (the TS hid the row until a best existed).
  - **UI R2** a void gradient behind the menu's left column; the attract-mode swarm ran
    through the title, tagline and NEXT text.
  - **UI R3** multipliers "1.0× / 1.25× / 1.5×" (was "1.50×").
  - **UI R4** Settings: the grid hint said "Off by default" (it is on since M11c); the
    Handling link fits one line.
  - **UI R5** unearned achievements show a faint star instead of an empty square that
    read as a checkbox.
  Looked fine and left: Armory Ships/Arena/Handling/Boosts, HUD, Pause, Run over, cold
  open. Noted, not changed (TS content): the run-start mode banner says "Classic
  Survival" while the menu card says "Standard".

## Keystones tried and FPS validated with max upgrades (user 2026-09-28: "try them and
## validate fps with max upgrades")

- **Tried in play** (emulator, perf test mode: every rank 5, all 21 keystones on, a
  power-up every 3 s, Code Red): screenshots show the Fallout Zone's green burn disc,
  Stun Wave's frozen ring, Event Horizon/Dark Harvest swallowing, missile swarms with
  Cluster Split children. 0 script errors in 12 runs.
- **Desktop** `bench/bench_powerups.gd` (new `test_bench_powerups_maxed`), 200 enemies,
  µs/tick total, defaults → maxed: missiles 163–169 → 257–269 (weapons 70 → 155); laser
  worst tick 400 → 770 (Heavy Beam); nuke 100 → 75 (Chain Reaction clears all 200); the
  rest flat.
- **Emulator A/B** (3 pairs, pre-keystone `0225ad4` vs keystones, both maxed), 3 s after
  each power-up, s_weapons ms/frame: missiles 5.0 → 13.9 (fps 20.5 → 14.5), nuke 0.9 →
  3.5, lightning 0.6 → 2.2, others ±0.5; overall 150–249 enemies fps 26.7 → 23.9.
- **P35 — missile snapshot** (exact): a blast that only removes enemies marks them dead
  in the snapshot instead of rebuilding it (rebuilds when a pulsar split adds some), the
  retarget reads the snapshot's own objects, and the snapshot itself is built in C++
  (`PerilNative.missile_snapshot`, `WeaponSystem.use_native_snapshot`; oracle test
  native == GDScript bytes; the pre-P32 golden hash still matches). Desktop missiles
  maxed 265 → 202 µs/tick (weapons 155 → 109), defaults 163 → 138. A native nearest-
  target scan measured no gain and was reverted.
- **Emulator A/B after P35** (3 pairs): missiles s_weapons 13.9 → 10.3 ms/frame (pre-
  keystone 4.9); fps in that window unchanged at 14.5 (the emulator's fixed tail, N6).
  With everything maxed the sim costs ~3 ms/frame more on the emulator at 150+ enemies
  (~1 ms on the A55, which ran 8.4 of 16.7 ms at 250 enemies); the A55 is the judge.

## User follow-ups (2026-09-28)

- **UI R6** — the menu's NEXT teaser ("no longer read property because it closely matches
  the color of the background"): a panel card with NEXT + reward, the title in full text
  and the description under it, over the meter.
- **UI R7** — "things should be dynamically scaling depending on device": TiltMenu fits
  itself — if the title block and the left column (with margins and the device insets)
  exceed the screen height, it shrinks its scale just enough (floor 0.75) and renders
  once more. `tests/test_device_matrix.gd` lays out the menu, all five Armory tabs and
  the Run over on 8 real resolutions (A55, Pixel 10, 20:9 FHD+, 720p, QHD+, 16:9 FHD,
  4:3 and 16:10 tablets) at their own scale and insets: nothing off screen, no
  overlapping blocks, touch targets ≥ 48 × scale. Mutation: without the fit and with
  the old card padding the menu check fails at every 1080-tall phone (−11 px) and 720p
  (−20 px) — the overlap the emulator showed. Suite 757.
- **UI R7 fix** — "clickjing tile and touch changes the scaling": a re-render measured the
  fitted menu again and the factor bounced (0.987 ↔ 0.994). Now only set_ui_scale (a new
  screen) resets it; a render may shrink it further, never grow it (1% margin).
  `test_steer_taps_keep_the_menu_scale` fails on the old code, passes now; emulator: the
  Play button's edge stays on the same pixel row across Touch/Tilt taps.
- **UI R8** — "remove 1.5x 1.0x and 1.25x from the game mode": the mode cards show no
  multiplier (the run-start banner and the Run over subtitle still name it — not asked).
- **UI R9** — "code red should actually be red": Code Red's colour, accent and glow
  #FF4D5E / #FF8A95 (TS violet #A78BFA), and its run-start banner in the same red.
  Suite 759.
- [x] **UI R10** — "if left on the menu screen - it actually fills the map with enemies
  causing it to lose fps": the backdrop gated only its own seeker spawn (< 14,
  TiltGame.ts:1673); `EnemySwarm.update`'s seeker timer and formation waves ran uncapped
  (the TS does the same) and ramp with time, and one wall is 72 dots on a phone. Ruling:
  `EnemySwarm.spawn_cap` (-1 in runs) — the menu swarm's own spawners act only below 24 —
  and `EnemySwarm.formation_pool` (the TS five in runs) — the menu drops the wall. Desktop
  10 min idle on 2424×1080 (`bench/bench_menu.gd`): peak 147 → 32 enemies, 78–118 →
  57–70 µs/tick. `test_an_idle_menu_stays_bounded` (5 min, peak ≤ 38) fails with the cap
  removed (45). PERF gains `men=` (menu swarm size); `tools/emulator/menu_idle.sh`
  idles APKs on the menu and logs PERF. Emulator A/B (`menu_idle.sh menu-before menu-after`): uncapped, `men` climbed
  to 164 within 8 min; capped, it stayed ≤ 27 (47 s logged before a deploy cut the run).
  Emulator fps did not separate them (its fixed tail, N6). Suite 762.
- [x] **UI R11** — "make steer and touch as well as the armory and achievements more
  noticeable as well aas change the settings option to the actual settings icon":
  `SegmentButton` (every segmented control: Steer on menu/Pause/Run over, Settings'
  shake) marks the selected segment ion — 22% fill, ion border, ion glyph, semibold —
  and Touch/Tilt carry glyphs (`UiTheme.ICON_TOUCH`, `ICON_TILT`; picker 176 → 208).
  The menu's Armory / Achievements are `NavButton`s (raised, bright semibold 15, line
  strong) with a glyph beside the centred label (upgrade chevrons ion, trophy flare);
  Settings is a filled eight-tooth cog (Main.dc.html's rayed circle read as a sun). The
  nav width is measured from the font (the child row has no size before the tree) with
  8 px sides; `test_device_matrix` checks each label fits its button on 8 devices, and an
  over-wide Armory pushes the panel off screen there (mutation). Menu draws unchanged on
  the emulator (217–300 vs 200–350). The Run over's Armory button keeps SecondaryButton.
- [x] **UI R12** — "the game over screen still shows 1.5 soemthing aolso fix the
  capitalization of the texts": the Run over subtitle is "Swarmed at 0:07 — Code Red"
  (no ", 1.5×") and the run-start banner sublines drop "1.5X SCORE //"; Settings' scheme
  sublabels are sentence case ("Drag anywhere", "Tilt the phone" — one line, was "phone
  gyroscope" wrapping); Armory track labels are sentence case ("Blast radius", "Shockwave
  speed") and the Arena captions ("Arena themes", "Enemy variations"). Names — weapons,
  keystones, boosts, skins, achievements — stay Title Case; the banners stay all caps.
- [x] **SKIN R1** — "instead of just base enemy colors changing, add textures to the
  enemies for unlocks": `render/enemy_textures.gd` paints each unlockable skin's pattern
  over the default dot's body (under border and pupil), from its palette: Toxic bubbles,
  Glitch scan bands, Magma obsidian crust with glowing cracks, Void swirl, Gold gleam and
  star. Baked into EntityLayer._dot_sprites (per radius key; Classic and the menu keep the
  exact old bake), so draw cost is unchanged; a bake costs ~0.4 ms more on desktop, once
  per radius (radii are a few constants). The Armory previews show the same dots (22/16
  px). `bench/skin_sheet.gd` writes build/shots/skin_sheet.png. Charger/artillery/etc. keep
  their skin colours only.
- [x] **ARMORY R5** — "arena -- when you click on something it automatically purchases
  it. it should also show the button when puchasing": a tap on an unowned Arena card picks
  it (ion 2 px edge) and swaps its price line for a "Buy 400" CostButton (dimmed when
  unaffordable); only that button buys. Owned cards still equip on tap (free). One pick
  at a time; opening the Armory or switching tabs clears it. Suite 766. *Superseded by
  R6/R7 the same day: only an explicit action button buys.*
- [x] **ARMORY R6** — "for things that are inactive or cant be clicked. make it more
  obvious like buttons where you dont have enought points or reset as well as equip":
  disabled buttons are flat with a barely-there edge (#1E232D) and dim text (#4A5162,
  was TEXT_FAINT, which read as merely secondary); an unaffordable price carries the lock
  glyph (weapons, ships, arena — keystones already did). Clickable ones read as such:
  SecondaryButton is raised with bright text (Reset, Menu, Armory, Pause), Equip is the
  new ion `EquipButton`. The Arena's small tap-anywhere cards became ship-style cards
  whose action button alone buys or equips. User: "dont add another tab for enemies and
  theme" — the brief Themes | Enemies switch was removed.
- [x] **ARMORY R7** — "instead of showing all of the themes and enemies, show only 1 with
  arrow icons on the left and right which cycles (left hand side) on the right hand side
  - show what it looks like in the arena"; "make it also the same for ships": Ships and
  Arena are showcase tabs — on the left, ◀ one card ▶ per catalog (Ships: the ship card;
  Arena: a theme carousel and an enemy carousel), arrows wrapping, "n / count" shown; on
  the right `ui/arena_preview.gd`, a still of the arena with the browsed theme (the run's
  background shader, grid, edge), nine dots in the browsed skin, and the browsed ship
  (the equipped ones for what the tab does not browse). Browsing equips nothing; opening
  the Armory resets each carousel to the equipped item. Both tabs fit a 1080- and a
  720-tall phone without scrolling (`test_showcase_tabs_fit_without_scrolling`). The
  preview draws once per change (no per-frame cost; the Armory is off the run). Suite 767.
- [x] **Release build + docs** — "cant we create a release build? do all the steps for me
  for now. we will change the keys when we need to actually deploy it": built
  `libperil.android.template_release.arm64.so`, made a throwaway dev key
  (`~/.android/peril-dev-release.keystore`, alias `perildev`; its env file sits beside it,
  outside git), set `version/name` 0.1.0, and added `tools/release.sh`, which exports and
  verifies `godot/build/peril-point-0.1.0.apk` (79 MB, not debuggable). "update the
  readme ... so that it reflects what this project really is about": README.md was
  rewritten (it still described two web games that no longer exist), and `tools/README.md`,
  `web/README.md` and the HANDOFF state were added or refreshed. Booted on the A55 as
  the phone-keyed build (save kept).
- [x] **UI R13** — "there are inconsistencies with the buttons. e.g. menu achivements has
  the icons, game over achivements do not have it": one nav button,
  `UiTheme.nav_button()` + `scale_nav_button()` (the NavButton face, with a glyph beside
  its centred label), serves the menu (Armory, Achievements, the Settings cog), the Run
  over (Menu ⌂, Armory) and Pause (Restart run ↻, Quit to menu ⌂, Armory, Settings ⚙).
  The Primary buttons carry glyphs too (Play/Resume ▶, Retry ↻), and the Run over's
  achievements header has the menu's trophy. The glyphs moved from TiltMenu into
  UiTheme. `test_every_nav_button_carries_its_glyph`.
- [x] **ORB R1** — "add a magnetic field similar to the coins to the power ups": within
  180 arena px, power-up orbs fly to the ship at 160→700 px/s (CoinSystem's numbers) and
  are picked up; `WeaponSystem.orb_magnet_radius` (0 = the TS rules). The orbs a run
  opens with (the cold open's nuke or vortex, and the ship's starting orb) are not
  magnetic (`WeaponOrb.magnetic`): they sit 27–150 px from the ship by design, and the
  player picks when to take them. The cost is a distance test per orb (≤ 5). Suite 770.
