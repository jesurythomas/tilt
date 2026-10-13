# add-onboarding — the How to play guide, in the game

Branch `add-onboarding` (from `staging` at `fdb3188`, which is `main`; PR #10's vibration fix
`52e4579` is not on it). Request (user, 2026-10-13): "create a new branch called add-onboarding
-- based on the data from the website https://perilpoint.newzenith.ph/how-to-play -- assets are
here C:\Users\Jesury\Downloads\assets we may need some other assets for how to play the game".

## Sources

- The page text (fetched 2026-10-13; the HTML is static, `guide.js` only plays the clips).
- `C:\Users\Jesury\Downloads\assets\*.mp4`: the site's seven power-up clips (800×450, 30 fps,
  5-11 s, no audio). Godot plays no MP4, so they are re-encoded to Theora:
  `ffmpeg -i X.mp4 -an -vf "scale=640:360:flags=lanczos,fps=30" -c:v libtheora -q:v 6 X.ogv`
  into `godot/assets/how_to_play/` (5.8 MB in all; Blackhole is 2.4 MB of it).
- "Other assets": none were needed. The guide draws with what the game already has: the
  playfield orb sprites (`WeaponIcons.orb_texture`), the Touch/Tilt glyphs, the mode colours,
  plus two small SVGs in `how_to_play_screen.gd` (a help glyph, an enemy ring).

## Ruling HTP R1 (my calls, standing instruction "always proceed")

- **Where:** a full-screen board, `HowToPlayScreen` (`godot/src/ui/how_to_play_screen.gd`,
  node `%HowToPlay`, topmost in `main.tscn`), styled as Settings: header with a close chevron,
  "How to play · n / 5", page dots, Back and Next (Got it on the last page).
- **Pages:** The basics (goal; Touch and Tilt; Armory → Handling), Power-ups (a 4-wide orb
  picker, the picked weapon's name and line, its clip looping at 16:9), Lives & enemies (lives;
  the 11-enemy table, scrolling), Score & Points (score, chains, close calls; the three modes
  from `GameOptionsManager.modes` with their multipliers; Points and the Armory), Tips (the four
  tips; achievements pay Points; where to reopen the guide).
- **Text:** the site's, trimmed for a sideways phone. One fix: the site says to tap "the
  calibrate button next to Steer", which BUG-101 R3 removed; Tilt now points at Settings →
  Controls (Each start / All runs). The site's ships table is left out (the Armory shows it).
  "57 achievements" is left out (the count can change; the menu shows it).
- **When:** a first launch opens it over the menu (`GameSettings.how_to_play_seen`, save key
  `howToPlaySeen`, default false); any close (chevron, Got it, Android back) sets and saves it.
  After that, the menu's **How to play** button (top right of the open area, level with the
  wordmark, so UI R7's fit is unchanged) opens it at page 1.
- **Back button:** `GameRoot.go_back` closes the guide first.
- **Frame cost:** runs gain no per-frame code. While the guide is open the menu's attract swarm
  does not simulate (the board is opaque); a clip decodes only on the Power-ups page.

## Tasks

- [x] Clips re-encoded to Theora; `.ogv` loads as `VideoStream`; all seven are in the Android
      export pack (checked with `--export-pack Android`).
- [x] `how_to_play_screen.gd` + `test_how_to_play_screen.gd` (paging, Got it, close, picker
      swaps clip and lines, enemy list, modes, 48 px targets, every page fits the A55).
- [x] `GameSettings.how_to_play_seen`; menu button and signal; `main.tscn` node; GameRoot:
      bind, first-launch open, saved on close, `go_back`, `set_ui_scale`, swarm held under it.
- [x] Tests: first launch opens once; the menu button opens it; the button clears the menu on
      the A55 at fit 1.0; back closes it over Settings; the swarm holds still under it. Two
      existing tests close the guide first (bare-menu back, backdrop steps); the TS settings
      parity test drops the new key.
- [x] 885 tests green (68/68 scripts), gdformat and gdlint clean, 0 SCRIPT ERROR headless.
      Screenshots of all five pages at 1170×540 (half the A55) checked by eye.
- [ ] A55 pass by the user (`VERIFY-ME.md` §HTP R1). Not installed: the A55 carries 0.1.8 for
      the BUG-101 pass, and this branch lacks PR #10's vibration fix. Build it after #10 merges
      into `staging` (or rebase), with code 10.
- [ ] Frame cost on the A55 while a clip plays (`tools/frametime.sh 20 htp`): desktop
      `TIME_PROCESS` was too noisy to separate (6-14 ms on the bare menu itself).

## Open

- **Two flaky suite runs.** Of 21 full runs with this change, runs 1 and 4 of the first batch failed
  2-3 save read-back tests that never touch the guide (`test_auto_tilt_level_...`,
  `test_choosing_all_runs_restores_the_saved_level`, `test_picking_a_card_saves_the_mode_and_rerenders`,
  `test_reset_confirm_removes_progress_and_keeps_controls`); the next 14 passed, and the
  baseline passed 6 of 6. No cause found. Suspect: `SaveStore.write_behind` is on while a
  GameRoot lives, and GUT runs `after_each` before it frees the root, so a queued save can
  outlive the cleanup. If it recurs, log `SaveStore.write_behind` at each test start.
- Seen, not fixed: in a windowed desktop run, opening the guide adds one engine
  `p_image.is_null() || p_image->is_empty()` error (the bare menu already prints one at boot,
  also on `main`). It is not deterministic and not the clips or the middle dot; likely a font
  atlas upload on the Separate render thread.
- The website still says "tap the calibrate button next to Steer"; it should match BUG-101 R3.
