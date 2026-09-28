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
- [ ] **A2 — Keystones: 3 per weapon, no "innate" row** (next).
- [ ] **A3 — Screenshot every section, redesign what plays badly.**
