# fix/runover-score-and-scheme-cards — Run over big score, Settings scheme cards

Branch `fix/runover-score-and-scheme-cards` (from `main` at `179cc45`). User (2026-10-12):
"read handoff create a new branch and fix the issues found". The handoff listed two layout
defects, both found 2026-10-12 and not ticketed.

## 1. Run over big score (fixed)

**Symptom.** `FinalScoreLabel` had no width cap. A score of 11+ digits set the left column's
minimum width, so the sheet grew past its 700-unit board width and Retry/Menu/Armory left it.

**Evidence (RED).** New tests in `tests/test_run_over_sheet.gd` with a score of
99,999,999,999,999: the sheet measured 982 px against 700 on the board frame (844x390), and
2721 px against 1938 on the A55 (2340x1080), which is wider than the screen.

**Ruling RUNOVER R2.** Every digit stays visible. The label clips (so its text never sets the
column width) and `RunOverSheet._fit_score` steps its font size down from `BIG_SCORE_SIZE`
until the text fits the label. It runs on `resized`, `show_result` and `set_ui_scale`. A
short score keeps the board size. The TS let the score overflow.

**GREEN.** `test_a_big_score_fits_the_board_frame`, `test_a_big_score_fits_the_a55` and
`test_a_short_score_keeps_the_board_size` pass. A windowed shot at 2340x1080 showed
"99,999,999,999,999" inside the left column with the right column intact.

## 2. Settings scheme cards clip (not a phone defect, left as is)

The handoff said the Touch and Tilt cards clip "Drag anywhe…" and "Tilt the…" at 2340x1080.
That came from `bench/shot_settings.gd`, which runs on desktop, where the Keys card is shown
(three cards). A rerun with the phone's layout (Keys hidden, Touch stick card shown) showed
"Drag anywhere" and "Tilt the phone" on one line each. `ui_scale` takes `long/844`, so every
device (A55, Tab S9 FE, any desktop window) lays the board out at the same logical width:
the clip happens on desktop with three cards, and on no phone or tablet. Not changed; the
user's call whether desktop needs it.

## Tasks

1. [x] RED: three tests; two failed on the sheet width (982 vs 700, 2721 vs 1938).
2. [x] Fix `run_over_sheet.gd` (RUNOVER R2); 17/17 in the file.
3. [x] Phone-layout check of the scheme cards (no clip; finding above).
4. [x] Full suite: `OK: 67/67 scripts collected, all tests passed, nothing leaked` (852 tests,
   20239 asserts); `gdformat --check` 120 unchanged; `gdlint` clean; headless boot 0 SCRIPT
   ERROR.
5. [ ] User: a look at a big score on the A55 (optional; the layout is asserted headless),
   then merge into `main`.
