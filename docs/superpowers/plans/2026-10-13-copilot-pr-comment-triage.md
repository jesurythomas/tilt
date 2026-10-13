# Copilot PR comment triage (PRs #1-#11)

Branch `review/copilot-pr-comments`, merged by PR #12. User 2026-10-13: "check all comments left by copilot on all
recent PRs - create an overall branch to verify if all the comments are correct and resolvable
or are even necessary". Each comment was checked against `main` at `84ec5ac`.

19 inline comments across PRs #5-#11 (PRs #1 and #3: none; #3's overview had 0 findings).

## Verdicts

| PR | Comment | Correct? | Still open on `main`? | Ruling |
|---|---|---|---|---|
| #5 | `run_tests.sh` prints a literal `$GODOT` / relative `godot` in its diagnostic commands | Yes | Yes | **Fixed**: prints the resolved, shell-quoted engine and project paths |
| #5 | CONVENTIONS §1.3 "exactly one check" contradicts the leak gate | Yes | Yes | **Fixed**: "a collection check" |
| #5 | `run_tests.sh` header "exactly one check" contradicts the leak gate | Yes | Yes | **Fixed**: same rewording |
| #5 | "10 of 59" not reconcilable with the plan's table | Partly: it is the 22+9+13+15 subset, unlabelled | Yes | **Fixed**: the table's full total, 13 of 85 |
| #6 | Re-anchoring a held stick keeps the old vector and owner | Yes (Settings → Stick position from Pause with a finger down) | Yes | **Fixed**: `GameRoot._on_stick_anchor_changed` resets the stick first; resize and Armory re-anchors keep the live touch as before. Test `test_stick_position_change_releases_the_held_stick` |
| #6 | HANDOFF says four tunables, there are five | Yes | Yes | **Fixed**: names all five |
| #7 | Big-score tests don't cover a live rescale | Partly: removing `set_ui_scale`'s `_fit_score()` stays green, but `resized` re-fits too | Yes | **Added** `test_a_shown_big_score_fits_after_a_rescale` (guards the live path; the mutation still survives because `resized` covers it) |
| #7 | HANDOFF still says the big score has no width cap | Yes | Yes (two places) | **Fixed** |
| #8 | Plan ticks the merge task inside the open PR | Yes at the time | No (merged) | Moot |
| #8 | HANDOFF claims merged inside the open PR | Yes at the time | No (merged) | Moot. The pattern (writing "merged" before the merge) recurs in #9; a note, not a change |
| #8 | VERIFY-ME asks for the removed Deadzone control | Yes | Yes | **Fixed** |
| #8 | VERIFY-ME says the preview takes tilt and Reset restores "both" | Yes (`HandlingPreview._gui_input` takes touch only; Reset restores three) | Yes | **Fixed** |
| #9 | Set level from Settings leaves the Settings board showing Each start | Yes | Yes | **Fixed**: `calibrate_gyro` redraws an open Settings board. Test `test_set_level_from_settings_refreshes_the_board` |
| #9 | Plan marks merged, then schedules merge | Yes at the time | No | Moot |
| #9 | HANDOFF claims merged before the A55 pass | Yes at the time | No (merged, A55 passed) | Moot |
| #10 | Settings Vibration on → preview pulse not tested | Yes | Yes | **Added** `test_vibration_switch_on_previews_one_pulse` |
| #11 | `JavaClassWrapper.wrap("android.os.VibrationAttributes")` logs an engine error below API 33 | Plausible (not reproduced: no device below API 33) | Yes | **Deferred**: the fallback works, only a startup log line; a guard needs an API < 33 device to verify. Reopen if a pre-13 phone is targeted |
| #11 | HANDOFF missing R4 | Yes at the time | No (`84ec5ac` covers R4) | Moot |
| #11 | VERIFY-ME missing R4 checks | Yes at the time | No (§BUG-101 R4 rows exist, passed) | Moot |

Tally: 11 fixed or covered, 1 deferred, 7 moot (resolved by later commits).

## Tasks

- [x] Collect the comments (`gh api .../pulls/N/comments`, Copilot only)
- [x] Verify each against `main`
- [x] Fix the open ones; mutation-check the new tests (each fails with its fix removed, except
      the rescale test, as noted)
- [x] 880 tests green, gdformat and gdlint clean, 0 SCRIPT ERROR
- [x] PR #12 opened and merged (2026-10-13). Copilot threads not replied to (not asked)

Frame cost: none per frame. The stick reset runs on a Settings change, the board redraw on Set level.

Found while verifying: two runs of `tools/run_tests.sh` at once (here, another session's suite in
the `dread-flock-staging` worktree) share `user://` and flake save tests (`test_armory_ui`
enemy skin, `test_main_scene` tilt level). Not a code bug. Isolate a run with
`APPDATA=<empty dir> tools/run_tests.sh`; that run gave 880/880.
