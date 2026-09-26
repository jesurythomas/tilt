# M11c part 1b — Review fixes (performance, then UI/UX)

**Source:** `docs/superpowers/reviews/2026-09-27-emulator-ux-review.md` (emulator
play review, 2026-09-27). **Authority:** the user said "for now always proceed"
(2026-09-27), so the rulings below are Claude's calls, made without a stop. The
user can overrule any of them; each carries its tag in the code.

Verification per task: `tools/run_tests.sh` green, `gdformat --check` and `gdlint`
clean, and the bench where one applies (`godot/bench/bench_draw.gd`, windowed;
`bench_sim.gd`, headless). Numbers are desktop µs.

## Rulings

- **P13 — baked default dots.** Each default-dot look (radius × {normal, hazard,
  chilled}) bakes its six layers into two cached `ImageTexture`s at screen
  resolution: glow + halo (scaled by the pulse) and body + inner + border + pupil.
  That is 2 `draw_texture_rect` per dot instead of 6 draws + 2 transforms. The
  halo's 1.2 px stroke now scales with the pulse (1.02–1.2 px). Frozen dots bake
  into one texture. Baking is C++ (`GradientTexture2D.get_image` +
  `Image.blend_rect`): about 1 ms per look on desktop, once.
- **P14 — the remaining circles.** Coins, orbs, artillery, bullets, carriers,
  satellites, pulsars and specters draw full circles from `CircleSprites`
  (`_ring` falls back to `draw_arc` when a ring texture would blur, the P5 rule).
  Dashed lines and dashed arcs go into one `draw_multiline` each (arcs as 3
  chords per dash). Player-ship circles are unchanged (one ship).

## Tasks

### Task 1: Entity draw (P13, P14)
**Status:** done — `bench_draw`: 115 seekers 911 → 356 µs/frame; late mix (90
seekers, a wall, carriers, artillery, pulsars, specters, aiming chargers; 155
enemies) 2,288 → 920 µs/frame. 665 tests (+3: bake composite order, hollow ring,
dot cache keys and rebakes). A visual comparison at 1:1 matched P5.

### Task 2: Sim cost under load
**Status:** done — ruling **P15**: separation visits only the jj an x-sorted window
says can reach ii (same ii-then-jj order; skipped pairs are the no-ops the plain
loop skips; falls back to the plain scan within a round when xs[ii] moves more
than 4 px), from 32 candidates up. Bit-exact: two new oracle cases (300 seekers
with a clump, 60 ticks; a 120-seeker pack that hit the fallback 72 times).
Bench: separation 277 → 114 µs/tick (115 spread); plain vs sweep at 180
candidates 646 → 138 (spread), 996 → 419 (converged); `swarm.update` 489 → 358;
late mix (212) 949 → 761. The 120 Hz tick stays: the TS substeps at 1/120 s
(`TiltGame.ts:1843`, spec D8). 667 tests.

### Task 3: Death-tick hitch
**Status:** done — the cost was file I/O: `save_completed` 317 µs + `save_cumulative`
274 µs of `evaluate_run`'s 1,048 (desktop); the metric pass is 44 µs. Ruling
**P16**: `SaveStore.write_behind` — saves serialise on the game thread and one
`WorkerThreadPool` task writes them (last save of a path wins); loads flush
first; `GameRoot` turns it on in `_ready`, flushes on
`NOTIFICATION_APPLICATION_PAUSED` / `WM_CLOSE_REQUEST`, and flushes and turns it
off in `_exit_tree` (tests keep synchronous writes). Bench: death tick 1,622 →
395 µs, `evaluate_run` 1,048 → 181, shield ram ×20 1,833 → 1,146. 670 tests (+3:
flush reaches disk, last save wins, loads see queued saves).

### Task 4: HUD and menu text above entities
Enemies draw over the score, BEST, the shield bar and the menu tagline/title.

### Task 5: Handling preview ship draws black

### Task 6: Close-call popup legibility

### Task 7: Run-over payout explanation ("+0 → 5,531")

### Task 8: Armory purchase feedback and kept scroll position

### Task 9: Truncations, Settings header alignment, small UI items
The rest of the review's UI list, in its order.
