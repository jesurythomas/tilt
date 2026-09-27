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

### Task 4: HUD and menu text over the dots
**Status:** done — correction to the review: the HUD is a CanvasLayer above the
entity layers; dots showed *through* thin glyphs and between letters, not over
them. `UiTheme.legible_over_play` (6 px void outline, ×ui scale on the menu) on
the HUD score, BEST and weapon-timer labels and the menu title, subtitle and
NEXT teaser.

### Task 5: Handling preview ship draws black
**Status:** done — a real bug: the SVG was built with `to_html(false)` (no `#`),
so `fill='00ddff'` was invalid (black fill, no stroke). Emulator: ship drawn in
its tint with the white stroke.

### Task 6: Close-call popup legibility
**Status:** done — floating texts scale by `_ui_scale` (TS sizes are CSS px) in
Archivo 700 (`ScoreManager.ts:193`), shadow offset scaled, kept inside the arena
width. Emulator: "CLOSE CALL! +375" large and legible.

### Task 7: Run-over payout explanation ("+0 → 5,531")
**Status:** done — points come only from milestones and coins
(`TiltGame.ts:2118`); a zero payout shows "Points come from milestones and coin
pickups." under the row. Emulator-verified.

### Task 8: Armory purchase feedback and kept scroll position
**Status:** done — every named scroll view (weapon list, card rows, page) keeps
its x/y offsets across a re-render; a successful spend pulses the balance
(1.15×, green, 0.45 s). Not yet exercised on the emulator (no purchase made in
the check, to spare the save).

### Task 9: Truncations, Settings header alignment, small UI items
**Status:** partly done — mode taglines and the scheme cards' key lines wrap to
two lines before trimming ("…from the first / second.", "phone / gyroscope");
the Settings header adds the top inset (y≈83, as Armory). **Regression caught on
the emulator and fixed:** wrap + `clip_text` hid every tagline (clip_text zeroes
the label's minimum size); the new layout test did not reproduce it headless.
**Remaining** from the review's UI list: Armory price verbs/affordability, maxed
"MAX" state, Boosts titles, theme previews, name clash (Aegis), Milestones units
and density, Reset styling, run-over spare space, pause subtitle, HUD BEST on a
new best, orb vs enemy palette, cold-open glyph.

### Task 10: Sim cost per step (next)
The clean A/B (emulator, god builds of `5ed4a05` vs `4c3c7c5`): entity draw
−55–67% per bucket, fps 38→49 (<50), 11.8→19.3 (100–149), 5.4→8.7 (150–249),
3.7→6.4 (250+). At 150+ the sim now dominates (phys 62 ms vs draw 52) and both
builds run at the 8-steps-per-frame ceiling. Profile `swarm.update`'s per-enemy
loop at 150–250 enemies next.

**Task 10 progress:** probe sections `s_swarm_loop` / `s_swarm_sep` added (debug
only). Ruling **P17**: the satellites of each carrier come from a per-tick map in
`update()` (and a per-frame map for the renderer's tethers) instead of a full scan
per carrier; the loop tail reads the type once. State hash of a seeded 900-tick
late-mix run identical before/after (`c3a7204d…`). Bench (212 enemies): loop
470 → 350 µs/tick, swarm step 767 → 657; separation ~300 unchanged.

**Task 10 — emulator A/B for P17** (clean emulator, god builds `4c3c7c5` vs
`18282d0`): 100–149 enemies 14.5 → 27.1 fps (s_swarm 23.8 → 10.5 ms/frame),
150–249 8.5 → 10.1, 250+ flat (6.4 / 6.3). Research (sourced report, 2026-09-27):
polygons triangulate per call and never batch; 4.4+ batches consecutive same-texture
draws; MultiMesh, Separate thread model, Perfetto (official Android templates in
4.7), 60 Hz + interpolation and GDExtension are the larger levers — the last two
conflict with the port's rules and are left for the user.
Ruling **P18**: the fixed enemy polygons draw through
`canvas_item_add_triangle_array` with known indices (pixel-identical, 0/1981
pixels differ in a render test). Small desktop gain (mix ~890–900 µs vs 890–980).
`bench_draw_types.gd` per enemy: seeker 3.2 µs, carrier+4 sats 61.8, charger 31.3,
pulsar 25.8, artillery 23.8, specter 18.5 → next: bake the heavy types (P19).

**Ruling P19 — bake the heavy enemy types** (render only): carrier body (diamond +
stroke + core), satellites (ring + discs), pulsar body + star (drawn rotated by the
star spin; the body is round), artillery barrel + hex + struts (the muzzle flash,
x 15–29, never overlaps the hex, so it draws after), charger hull + edge + core per
state; SVG strokes miter like the canvas default. Dashed lines/arcs share one point
list per frame. Old-vs-new renders compared (same shapes, colours, angles;
anti-aliased). `bench_draw_types` per enemy: carrier+sats 61.8 → 13.9 µs, charger
31.3 → 4.9, artillery 23.8 → 4.2, pulsar 25.8 → 14.1 (its growing pulse ring keeps
the draw_arc fallback), specter 18.5 → 8.7. Late mix 890–980 → ~635 µs/frame.

**P19 emulator A/B** (`18282d0` → `2dccdff`): 100–149 20.1 → 31.1 fps, 150–249
10.9 → 18.4, 250+ 7.7 → 11.9; entity draw 43.9 → 14.1 ms/frame at 150–249. The sim
now dominates. User report (2026-09-27): drops come with wall formations and
carriers. Bench of a full tick: a wall adds ~115 µs (swarm +86, collisions +41),
eight carriers ~106 µs.
- **P21** (kept): `check_collisions` skips an enemy whose |dx| exceeds
  player.radius + e.radius + 16 + 1 px (neither test can pass; outcomes unchanged).
  Bench collide 73 → 48 µs/tick (114 → 69 with a wall); emulator 4.1–4.5 → 2.3
  ms/frame.
- **P22** (kept): `evaluate_live_total_goals` walks a cached list of uncompleted total
  goals (catalog order, rebuilt on any completion or reset). 53 → 20 µs/tick; emulator
  1.9 → 0.6 ms/frame. Test: a goal completed live comes back after a reset (fails
  without the reset hook).
- **P20** (reverted): glows-first draw order for batching made entity draw *slower*
  on the emulator (14.3 → 17.9 ms/frame at 150–249; the extra pass costs more
  GDScript than batching saves on its desktop GPU). Re-try only with A55 evidence.
- **P23** (kept): `update()` hoists `update_seeker`'s per-tick constants (same
  expressions, same order) and inlines the seeker step (`update_seeker` stays for its
  callers). Golden state hash identical (`9dc5234a…`, 900 ticks with varying score and
  mode). Bench: loop 350 → 275 µs/tick; base swarm 302 → 255.
- **P24** (kept, needs the A55 check VERIFY-ME §M11c 7): `rendering/driver/threads/
  thread_model=2` (Separate — research: overlaps rendering with game logic; lightly
  tested upstream; up to ~2 frames of input latency). The debug PerfProbe now builds
  its extra fields (incl. `viewport_get_measured_render_time_gpu`, which forces an RS
  sync per call when threaded) only when a line prints. Emulator A/B, fps by enemy
  count: P22 → P23 → P23+Separate → P24: 150–249 16.6 → 20.5 → 31.3 → 30.8; 250+
  9.6 → 11.6 → 13.3/14.1 → 23.4; 100–149 34.7 → 30.0 (3 samples) → 39.3/40.5 → 48.5.
  Main-thread entity draw 15.5 → ~4 ms/frame. No errors or crashes in the runs.

### Task 11: Menu border, background, grid back on (user, 2026-09-27)
"the issue with only half the game shows the border still exists — specifically in
the menu — background of the game itself also seems bad. re-add the grid and test
the fps."
- Menu border: the HUD `%Frame` outline and the grid perimeter both framed the arena
  under the menu's right column. The perimeter is hidden in MENU
  (`GridLayer.show_perimeter`) and the frame's own outline via `self_modulate` (its
  HUD children unaffected). Emulator: no half border.
- Background: the 256 px gradient stretched to ~3400 px showed 8-bit banding rings
  (contrast-stretched crop). Now `arena_background.gdshader`: same stops and radius,
  raw-sRGB interpolation, ±½-level dither.
- Grid on by default (ruling, user's words), with `gridlinesDefaultOn` so old saves
  (which held the old default) switch on once; a choice made since is kept; the TS
  `=== true` rule applies when the marker is present. Parity test states the one
  divergent default.
- Grid cost: `VectorGrid` sleeps once every point is within 0.02 px/step of rest
  (snapped exactly; `settled`, `revision`); `GridLayer` draws through three children:
  shader background (redrawn on size/theme change), lines in white tinted by modulate
  (redrawn only on `revision` change), frame/overlay (per frame). GameRoot calls
  `refresh()`.
