# Peril Point — Godot Port: Plan Index

> **Naming.** The product is **Peril Point** (renamed 2026-09-20, Android id
> `com.jtg.perilpoint`). The source it ports is the web game *Tilt to Live*,
> which keeps its name in `web/src/tilt-to-live/`, in every TS filename and in
> every `# PORT:` citation. Do not rename those — Law 1's citations depend on
> them.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement each module plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the web game (~13,250 lines of TypeScript in `web/src/tilt-to-live/`) to Godot 4.7.2 GDScript and ship it as **Peril Point**, a landscape Android/iOS game, in 13 modules that each end in a runnable build and a hard stop.

**Architecture:** Plain-data simulation ported near 1:1 from the TypeScript, rendered through a small number of `Node2D._draw()` layers. The web game stays in `web/` as the reference implementation and as a live build dependency (Module 5 executes `TiltAudio.ts` to bake audio). Sim→UI communication is by signal; sim→sim stays direct-reference, preserving exact frame order.

**Tech Stack:** Godot 4.7.2-stable (GDScript, non-.NET) · GUT for headless specs · gdtoolkit 4.x (`gdformat`, `gdlint`) · Node 20+ for the bake and parity tools.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md`

**Conventions (binding):** `godot/CONVENTIONS.md`

**Prerequisites (read first):** `godot/PREREQUISITES.md` — what to install by
hand before anything can run. Module 0 needs one `pip install`; Module 0b needs
roughly 6 GB of downloads and several GUI installers. It also records that
**iOS cannot be exported from this Windows machine** and is deferred to M11.

---

## Why this is an index rather than one plan

Each module ends in a runnable build and is independently reviewable, which is exactly the boundary the writing-plans skill draws a plan around. Writing all thirteen up front would also mean inventing, for example, Module 8's UI task steps before Module 7's `ProgressionManager` API exists — which Law 5 forbids and which would go stale before you reached it.

**Each module's plan is written at the start of that module's session**, from this index and the spec. The "what" and the acceptance criteria are already fixed in spec §8; only the step-by-step "how" is written just-in-time.

---

## Global Constraints

Copied verbatim from the spec and `CONVENTIONS.md`. Every task in every module plan implicitly includes this section.

- **Engine:** Godot **4.7.2-stable**, GDScript, standard (non-.NET) build.
- **Godot is not on PATH.** Invoke as:
  `GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`
  Use the `_console` variant so stdout reaches the shell.
- **Orientation:** landscape. **Targets:** Android + iOS only — but iOS requires
  a macOS host with Xcode and is deferred to M11 (D1, `PREREQUISITES.md` §3).
  Everything through M10 is Android-only and the GDScript is identical for both.
- **`content_scale_mode = disabled`.** The sim reads `get_viewport_rect().size` directly. All UI must be responsive (anchors/containers), never pinned to a base resolution.
- **`max_fps = 60`** (rendering) with **`physics_ticks_per_second = 120`** (spec D8, amended 2026-09-20 — the TS substeps at 1/120 s and `VectorGrid.update()` ignores its `dt`). Sim in `_physics_process`; `_process` only calls `queue_redraw()`.
- **`arenaScale = clamp(min(width, height) / 680, 0.60, 1.15)`** — reproduced verbatim.
- **`GAME_SPEED = 0.75`** (`web/src/tilt-to-live/TiltGame.ts:35`).
- **Static typing is mandatory and machine-enforced.** Nine GDScript warnings are set to Error; the engine refuses to run violations.
- **No sim system may be an autoload or singleton** — `MenuBackdrop` runs a second concurrent simulation (spec §5.2).
- **Signals are sim→UI and sim→audio only. Never sim→sim** (spec §5.3).
- **Frame order is fixed** (spec §5.4). A module adds its call at its documented index; nothing else moves. No module may reorder an existing step.
- **The five port laws** (`CONVENTIONS.md` §0) are binding and are restated in every module plan: no invented numbers · no silent improvement · one TS file to one `.gd` file · nothing new · stop rather than guess.
- **Commits:** one line, imperative, ≤72 chars, no trailers, prefixed `M<n>:`.

---

## Module map

| # | Module | Deps | Plan | Status |
|---|---|---|---|---|
| 0 | Scaffold | — | `2026-09-20-m0-scaffold.md` | **done** |
| 0b | **Android toolchain** | M0 | `2026-09-20-m0b-android-toolchain.md` | planned — installs done |
| 1 | Core loop and input | M0b | `2026-09-20-m1-core-loop-and-input.md` | **done** |
| 2 | **Vertical slice** — first playable | M1 | `2026-09-20-m2-vertical-slice.md` | **done** |
| 2.5 | **Mobile feel** — input, HUD, arena inset | M2 | `2026-09-20-m2.5-mobile-feel.md` | **code complete** — device pass pending (`godot/VERIFY-ME.md`) |
| 3 | Enemy roster (12 remaining types, 8 formations) | M2 | `2026-09-20-m3-enemy-roster.md` | **code complete** — device pass pending (`godot/VERIFY-ME.md`) |
| 4 | Weapons (6 remaining) | M2 | not yet written | — |
| 5 | Audio bake + SFX | M2 | not yet written | — |
| 6 | Generative music sequencer | M5 | not yet written | — |
| 7 | Persistence and economy | M2 | not yet written | — |
| 8 | Armory UI | M7 | not yet written | — |
| 9 | Milestones | M7 | not yet written | — |
| 10 | Modes (code-red, gauntlet) | M3 | not yet written | — |
| 11 | Menu, cinematic, export, device pass | all | not yet written | — |

**Independent set:** once M2 is done, modules **3, 4, 5 and 7** depend only on M2 and may be taken in any order. M6 needs M5; M8 and M9 need M7; M10 needs M3; M11 needs everything.

**Why M2.5 exists:** device play of the M2 build on the Samsung Galaxy A55 found seven defects in how the game meets the player — no control-scheme choice, mistuned and drifting tilt, no virtual joystick, a weak score block, undersized entities and UI text, an arena border running under the device bezel, and an unstyled death screen. Every one is a **divergence from the TypeScript source**, which Law 4 permits only against an explicit line of a spec — hence its own spec rather than a round of fixes folded into M2. It is numbered 2.5 rather than appended because M3, M4, M5 and M7 all build on the input and HUD surfaces it changes, and taking it later would mean reworking them. It also introduces the `DIVERGENCE(M<n> §x)` comment tag, binding from here on: `grep -rn "DIVERGENCE" godot/src/` must list every deviation from the port.

**Spec:** `docs/superpowers/specs/2026-09-20-m2.5-mobile-feel-design.md`

**Why M0b exists:** the spec originally folded "a debug APK builds" into M0. The environment check on 2026-09-20 found export templates empty, no JDK anywhere on disk, and `ANDROID_HOME` pointing at a directory that does not exist. That is several GB of user-driven installation and would block M0 indefinitely. It is now its own module so M0 can complete and stop cleanly. M1 needs it because M1's acceptance requires tilt verification on a physical device.

---

## Per-module exit protocol

No module is done until all five steps are complete, in order. This is `CONVENTIONS.md` §9 and it is not optional.

1. **Verify** — actually run the module's acceptance commands and read the output. Never claim a result you have not seen. If anything fails, the module is not done.
2. **Commit** — one line, imperative, ≤72 chars, no trailers, `M<n>:` prefix.
3. **Tick `godot/PORT-PROGRESS.md`** — check the box, record the date and commit SHA.
4. **Rewrite `godot/HANDOFF.md`** — for a reader with zero context.
5. **Stop. Report to the user. Do not begin the next module.**

Step 5 is not a suggestion. The user is managing a credit budget and has asked explicitly for a hard stop at every module boundary.

---

## Resuming cold in a new session

Paste this:

> Read `godot/HANDOFF.md`, `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md`, `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` and `godot/CONVENTIONS.md`. Then write and execute the plan for Module N.

To **jump to a different module** instead of the next one, check the Module map above: any module whose dependencies are ticked in `PORT-PROGRESS.md` may be started.

## Writing the next module's plan

At the start of a module's session, write `docs/superpowers/plans/2026-09-20-m<n>-<slug>.md` using the writing-plans skill, sourced from:

- spec §8 for that module's scope and acceptance criteria
- spec §5.4 for where its systems slot into frame order
- the TypeScript file(s) it ports, **read in full first** — the plan must cite real line numbers, because Law 1 requires every ported literal to carry one
- `CONVENTIONS.md` for the laws, naming, typing and comment rules

Then execute it, then run the exit protocol.
