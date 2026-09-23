# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

Last completed module: **M8 — Armory UI (+ cosmetics in the renderer)**,
final-review fix wave landed 2026-09-22 (head is this commit — `git log -1
--format=%H` — a commit cannot cite its own hash inside its own tree).
Code-complete, **device pass pending** (none ticked in `PORT-PROGRESS.md`):
**M2.5 — Mobile feel** (head `37f9fd4` + the user's tuning `c023e09`),
**M3 — Enemy roster** (head `5bb5cc9`), **M4 — Weapons** (head `0b7fccf`),
**M7 — Persistence and economy** (head `dba9126`),
**M8 — Armory UI** (head is this commit, see above).
Landed after M8 (2026-09-22): **mobile scale split** — on mobile only, the
arena scale is capped (`GameRoot.MOBILE_ARENA_SCALE_CEILING`) and entities
are drawn larger (`GameRoot.MOBILE_MODEL_SCALE`, applied by
`EntityLayer.set_model_scale()`); the orb glyph scales with its bubble
everywhere. Desktop unchanged; device checks in `VERIFY-ME.md` under
"Mobile scale split".
Nothing since M2 has run on a phone: the A55 dropped off adb on 2026-09-20 and
did not return; the user then ran their own pass and committed tuning as
`c023e09` (gyro feel + FPS under mass explosions). It was still absent from
adb on 2026-09-21 during M7 and **remains absent on 2026-09-22** during M8
(`adb devices` returns an empty list).
Also landed after M4: **HUD score feedback** (`9cc3e8f..31bf2ce`, spec
`docs/superpowers/specs/2026-09-21-hud-score-feedback-design.md`) — kill-site
callouts removed; the score pulses in a multiplier-tier colour instead.
Next module: **M9 (Milestones)** — chosen by the user 2026-09-23; plan
written, **not started**, see `## Next

**M9 — Milestones**, plan `docs/superpowers/plans/2026-09-20-m9-milestones.md`
(9 tasks; user rulings R1–R2 and plan rulings R3–R7 are recorded at its top).
**Literal first step:** read that plan's header, rulings and Global
Constraints, then execute **Task 1** (SaveStore string-list files) with
superpowers:subagent-driven-development. After each task: tick it in the plan,
update this file's `## State` line ("M9 in progress: Tasks 1–N landed; next
Task N+1"), commit per the task's commit step.

The plan's Open questions (R7 death-tick double count, the 4px rail on a
phone, unported CSS animations) are for the user — raise them at M9's stop.

M5 (deps M2) and M10 (deps M3) are the modules open after M9.

Before starting: `git status --short` must be clean under `godot/` (the user
may leave device tuning uncommitted — never stash or revert it), and read
`godot/VERIFY-ME.md` for the outstanding M2.5/M3/M4/M7/M8 and "Mobile scale
split" device checks.
