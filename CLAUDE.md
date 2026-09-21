# CLAUDE.md — Peril Point (Godot port of Tilt to Live)

Port conventions and laws live in `godot/CONVENTIONS.md`; the module checklist
in `godot/PORT-PROGRESS.md`; the cold-start state in `godot/HANDOFF.md`;
device/user checks in `godot/VERIFY-ME.md`. Read `godot/HANDOFF.md` first.

## Session start

1. `git status` — the user may leave uncommitted device tuning in the tree.
   Never stash or revert it.
2. `git log -1 --format=%B` — the last commit's message says what to do next.
3. Read `godot/HANDOFF.md`, then do what the commit says.

## After every task (not only at module boundaries)

Run this loop at the end of **every** task — a plan task, a review fix, a
doc edit — before starting the next one:

1. **Update the task** — tick it in the active plan under
   `docs/superpowers/plans/` (and the SDD ledger under `.superpowers/sdd/` when
   one exists); record rulings there, not in chat.
2. **Update the handoff** — `godot/HANDOFF.md` must describe the tree as it is
   now; `godot/PORT-PROGRESS.md` when a module closes (CONVENTIONS §9).
3. **Update the plan** — if the task changed what the next step is, edit the
   plan so the next session does not re-derive it.
4. **Commit** — one line per CONVENTIONS §8, no trailers. The message must say
   what the next step is when the work is not finished, e.g.
   `next: read godot/HANDOFF.md + VERIFY-ME.md, then plan M7 per its Next`.
5. Tell the user to `/clear`. The next session resumes from the commit message
   and `HANDOFF.md`, with zero conversation context.

The commit is the handoff. If it is not in the commit, the next session will
not know it.
