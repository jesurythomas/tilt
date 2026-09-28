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
