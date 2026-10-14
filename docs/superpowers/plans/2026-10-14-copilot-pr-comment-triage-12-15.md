# Copilot PR comment triage (PRs #12-#16)

Branch `review/copilot-pr-12-15`, from `staging` at `507e180` (PR #16 merged). User 2026-10-14:
"copilot left some comments on the pervious prs. take a look at those comments and fix if
needed". PRs #1-#11 were triaged by PR #12 (`2026-10-13-copilot-pr-comment-triage.md`). Each
comment was checked against `staging` at `507e180`.

13 inline comments across PRs #12-#15. PR #16: none (Copilot: "unable to review this pull
request because the user who requested the review has reached their quota limit").

## Verdicts

| PR | Comment | Correct? | Still open on `staging`? | Ruling |
|---|---|---|---|---|
| #12 | Triage tally says 11 fixed / 7 moot; the table has 12 / 6 | Yes | Yes | **Fixed** in the triage plan, with a note on the slip |
| #12 | HANDOFF repeats the 11 / 7 tally | Yes | Yes | **Fixed**: 12 fixed or covered, 6 moot |
| #12 | HANDOFF says "no new device behaviour", but the stick release and the Settings redraw are device behaviour | Yes | Yes | **Fixed**: no A55 build was made for it; the fixes rest on their regression tests and ship in every build from 0.1.13 |
| #13 | `run_tests.sh` has no `set -e`, so a failed `mktemp -d` runs the suite on the shared `user://` and can still print OK | Yes | Yes | **Fixed**: an empty or missing temp dir (or an empty `cygpath` result) fails with exit 1; header and CONVENTIONS §1.3 say so |
| #14 | The guide says "each run, or your Calibrate angle"; Settings says Tilt level: Each start / All runs, and Calibrate tilt | Yes (`tilt_menu.gd` `TiltLevelEachStart`, `TiltLevelAllRuns`, `SettingsCalibrateButton`) | Yes | **Fixed**: "Settings → Controls → Tilt level: Each start, or All runs from Calibrate tilt." |
| #14 | Plan ticks the merge inside the open PR | Yes at the time | No (merged) | Moot. Same pattern as #8/#9 in the first triage |
| #14 | HANDOFF says merged inside the open PR | Yes at the time | No (merged) | Moot |
| #14 | VERIFY-ME §HTP names 0.1.12 (code 13); the A55 build was 0.1.13 (code 14) | Yes | Yes (§HTP still open) | **Fixed**: 0.1.13 (code 14), noted as the same code as 0.1.12 |
| #15 | (high) Closing the privacy options form leaves ads loaded under the old consent cached and shown later | Yes | Yes | **Fixed, ADS R11**: the plugin drops held ads and in-flight loads on the form close; `Ads` clears its ready flags on every consent report and reloads only if allowed. AARs rebuilt |
| #15 | A late close or failure from a timed-out ad ends the next break early | Yes (the watchdog cleared `_pending`; the late callback then ran `_finish_break` for a newer show) | Yes | **Fixed, ADS R12**: `Ads._showing` holds an ad until its own close or failure, past the watchdog; no other ad shows meanwhile; callbacks of the wrong kind are ignored |
| #15 | The rewarded `on_reward` claims on the live `RunController`, so a late payout after Retry is lost or lands on the next run | Yes | Yes | **Fixed, ADS R13**: `RunController.run_number`; GameRoot binds the run and its credited points at the tap; `claim_reward_for` banks a stale run's bonus without touching the new run |
| #15 | First Retry hides the Run over before the break starts, so a slow ad leaves a blank screen | Yes | Yes | **Fixed, ADS R14**: the sheet stays; `_on_phase_changed` hides it at the restart |
| #15 | Plan's Open item still quotes R2 pacing (3 runs, 180 s) | Yes | Yes | **Fixed**: R5's numbers (20 s, a 5-10-game gap, 300 s of play) |

Tally: 11 fixed, 2 moot (resolved by the merge). Still deferred from the first triage: #11's
API-33 `VibrationAttributes` guard (needs a phone below Android 13).

## Tasks

- [x] Collect the comments (`gh api .../pulls/N/comments` and `/reviews`, Copilot only)
- [x] Verify each against `staging`
- [x] Fix the open ones; rulings ADS R11-R14 in `2026-10-13-in-game-ads.md`
- [x] Six regression tests, each failing with its fix removed (mutation-checked: R11 2 tests,
      R12 2, R13 1, R14 1)
- [x] Suite 1032/1032, 75/75 scripts, nothing leaked; gdformat, gdlint clean; 0 SCRIPT ERROR in
      the suite and a 600-frame headless boot
- [x] AARs rebuilt with `tools/build_ads_plugin.sh` (debug 12,051 B, release 11,453 B)
- [ ] PR `review/copilot-pr-12-15` → `staging`; the user merges it
- [ ] The next A55 build (code 26) carries R11/R14; VERIFY-ME §ADS has their rows

Frame cost: none per frame. Every change runs on an ad callback, a consent change, a Retry tap
or a run start. `bench_sim` headless: swarm.update 25.5 µs vs 24.7 on `staging`, death tick
397 vs 583, all within run-to-run noise.

Found while verifying: the R13 test first awaited the real 4 s watchdog. That rendered the
arena for several headless frames, and `test_circle_sprites` (which runs later) then read
`CircleSprites.disc()` back as a null image. The test now calls the watchdog directly. The
circle-sprite test still depends on no earlier test drawing the arena: an order dependence,
not a game bug.
