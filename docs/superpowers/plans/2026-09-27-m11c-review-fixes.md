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
- Grid FPS (emulator A/B, god builds): turning the grid on with a full-lattice step
  cost `s_grid` ~21–23 ms/frame while rippling (13 of 100 s above 5 ms; early-game
  kills keep it awake: 13–16 fps until it settles). **Active set:** `VectorGrid.update`
  steps only disturbed points (each springs to its own origin alone, and a point at
  rest is a fixed point, so skipping it is exact); an explosion adds the points it
  pushes; a point leaves once within 0.02 px/step of rest (snapped). vs the pre-P3
  grid: max 0.000086 px position / 0.000008 velocity difference (oracle now bounds by
  SETTLE_EPS). Result: `s_grid` 2.75 → 0.45 ms/frame, hot seconds 13 → 1; 50–99
  enemies 35.9 → 50.8 fps. `touch(i)` wakes a point moved directly (tests).

### Task 12: Loading screen and app icons (user, 2026-09-27: "please also add a new loading screen")
- Boot splash: `godot/assets/splash/boot_splash.png`, rendered by
  `godot/tools/make_splash.gd` (GUT, windowed, `--render-thread safe`) from the
  ColdOpen board itself (void, ion glow, ship, "PERIL POINT", empty bar) at 2340×1080,
  so the hand-over to the cold open is seamless. `application/boot_splash/image`,
  `bg_color` #08090E (the image's edge), `stretch_mode=4` (Cover).
- Icons: `godot/tools/make_icons.gd` (headless) draws the ship glyph with an ion glow
  on the void colour → `assets/icon/` (project icon 512, launcher 192, adaptive
  foreground/background/monochrome 432); `config/icon` set (clears the export's
  "No project icon" error); export `launcher_icons/*` and `splash_screen/icon` set.
- Emulator launch: system splash shows the ship icon (was Godot's), then the new boot
  splash, then the menu. **Open:** the Android 12 system splash background stays the
  light theme colour — `splash_screen/background_color` did not apply in this
  non-Gradle export; a Gradle build (Android build template) would be needed.

### Task 9 (continued) — the rest of the review's UI list, checked against the code
- **Corrections to the review:** the Armory already had a "Max" state, disabled
  unaffordable buttons and locked unaffordable keystones — every price was affordable
  in the review session, so they looked alike. Settings' Reset already opens a confirm
  dialog and its muted style is the board's (Settings.dc.html). No change.
- **Fixed:** Boosts cards showed no name — `_one_line`'s clip_text zeroes the minimum
  width, so the expanding effect label squeezed the name out; the name now keeps its
  width (emulator-verified; headless layout does not reproduce it). Milestone rewards
  read "+1 pt" / "+5 pts" (cards, toasts, Run over). Pause: "Score 0 · 0:01 ·
  Standard". HUD: "NEW BEST" (flare) once the score passes a previous best (the TS
  best only updates at the run's end).
- **Kept (TS or board content, not flaws to fix):** the ship "Aegis" vs the Blackhole
  keystone "Aegis" names; orb colours (the nuke orb's crimson); the cold-open glyph;
  Milestones card height; theme previews and the Run over spare space are design work
  for the boards, not code fixes.
- **Gradle build** (closes Task 12's open item): with `use_gradle_build=true` the export
  applies `splash_screen/background_color`, so the Android 12 system splash is the void
  colour with the ship (emulator-verified). Local one-time setup documented in
  VERIFY-ME §0 (template git-ignored; JDK 17 pinned for Gradle; daemon off so headless
  exports return, 39 s).

### Review of `5ed4a05..HEAD` (fresh reviewer, 2026-09-27)
Verified correct: SaveStore threading (no lost writes/deadlock; loads flush), the
separation sweep's bit-exactness argument, P23's arithmetic order, P17's map validity,
the grid active set and redraw keys, entity cache invalidation, P21, P22, the gridlines
migration, the PerfProbe callable. **Fixed:**
1. `GameRoot.reset_progress_files` now flushes the write-behind queue before deleting
   (a queued save could recreate a deleted file); test fails without it.
2. Skin/halo changes no longer clear the baked-sprite caches: the (skin, halo) look is
   part of each skin-dependent key, so menu↔run switches reuse bakes (each bake is a
   render-thread sync under P24). Test: a skin round trip reuses the bake.
3. Frozen and satellite sprites draw at their cached texture's size.
4. Armory scroll offsets carry over only when re-rendering the same tab (TS :334-336).
Draw bench unchanged with `--render-thread safe` (seekers ~357 µs, mix ~626 µs); under the
project's Separate render thread the desktop bench reads ~30–50% higher and noisier —
the draw benches now document the flag.

**Ruling P25 — particle steps batched per rendered frame** (visual only): the run tick
queues `particles.step(dt)`; `GameRoot` calls `particles.flush()` once per frame, which
integrates each particle over the steps since its birth/last flush in closed form
(x += vx·dt·(1−fⁿ)/(1−f), vx·fⁿ, life and ring size linear) — the per-step result up to
rounding; `update(dt)` = one step + flush, bit-identical to before (n = 1). Dead
particles retire at the flush, so at the 400 cap slightly more emits are dropped.
Tests: 5 queued steps match 5 updates (1e-9); a particle born mid-batch integrates only
later steps. Emulator Code Red A/B at 150+ enemies: `s_particles` 4.93 → 1.14 ms/frame
(more particles alive); 150–249 fps 13.7 → 21.9. `tools/emulator/ab.sh` now selects
Code Red before Play.

### Verification ×5 (user, 2026-09-27: "do a thorough verification - do it 5 times")
- [x] Automated ×5: 678/678 tests each run; gdlint clean; headless smoke 0 errors;
  `gdformat --check` flags only the pre-existing scratch `bench/bench_visual.gd`.
- [x] Emulator UI pass ×5 (`tools/emulator/verify_ui.sh`): alive every run, 0 script
  errors or fatals. **False positive found and fixed:** the menu still showed an edge
  around half the screen — the grid was drawn from the arena inset, leaving a plain
  band at the left and top. `GridLayer.grid_fills_viewport` (set while the menu
  shows) draws it from the screen origin; re-checked 5/5. Boost names, reward units,
  the Settings header, the coloured Handling ship and the payout hint were confirmed
  in all 5 runs; "Score …" on Pause only in the 2 runs that survived to pause; the
  HUD's NEW BEST only by unit test.
- [x] Launch ×5: dark system splash with the ship → a **black gap of ~3–5 s** →
  the boot splash, the same every run. Not fixed: that is Godot's engine start
  (a `windowBackground` theme attribute was tried and made no difference;
  reverted).
- [x] Desktop benches ×5: sim 566–583 µs/tick (loop ~278–286, separation ~284–292);
  draw seekers 349–364 µs (`--render-thread safe`). Stable.
- [x] **P24 confirmed** (it was suspect: Android logs "Rendering thread not
  supported by this display server"). Identical god builds differing only in
  `thread_model` (2 vs 1), 5 alternating Code Red pairs, 100 s each, fps by enemy
  count (all runs pooled, samples in brackets):
  100–149 51.9 [63] vs 36.7 [55]; 150–199 35.6 [95] vs 24.7 [69]; 200–249 20.3 [77]
  vs 13.8 [80]; 250+ ~9 vs ~9 (sim-bound). Main-thread entity draw 3.3 vs 10.1 ms at
  150–199. At 150–249 Separate led in 4 pairs, tied in 1 (28.1 vs 28.5). 0 errors or
  crashes in 10 runs. So the setting still moves rendering off the main thread
  despite the warning. Still to confirm on the A55: steering latency (VERIFY-ME
  §M11c 7).

### FPS research (user, 2026-09-27: "research more on improving FPS")
Three research passes (GDScript CPU, Godot mobile rendering, native/GPU) plus one
measurement. Ranked next steps, none started:
1. **Tighter separation window** (≈1.5–3× on separation, ½ day, exact): in
   `_separate_sweep` reject candidates with `absf(ys[k] - y0) >= min_distance +
   SWEEP_SLACK` while building the window (the slab is x-only today), and extend the
   bail-out to y. A k > ii cannot move before its own round, so the x proof carries
   over. Gate: the separation oracle test + golden hashes.
2. **Inline the remaining per-type updates** (~120 ns per GDScript call; small each,
   exact): the `update_*` dispatch for the types common at 250+ (wall, circle,
   arrow dots), like P23 did for seekers.
3. **Structure-of-arrays for hot enemy fields** (2.76× on a seeker-like loop in a
   4.7.2 microbench: 500 → 181 ns/entity; 2–4 days): x, y, vx, vy, age, radius in
   `PackedFloat64Array`s (never Float32/Vector2 — float32 breaks exactness);
   `Enemy` keeps cold fields + a slot index; keep `remove_at` order.
4. **Native separation (GDExtension, godot-cpp)** if 1–3 fall short: the pass is
   ~180 pure-numeric lines (sqrt only, no RNG). Toolchain is present (Python 3.13,
   MSVC, Rust); missing NDK 29.0.14206865 (sdkmanager). Build with
   `-ffp-contract=off` (clang fuses a*b+c on arm64 by default), no fast-math;
   return the packed array (copy-on-write). ~2–3 days incl. Android build.
5. **Swappy**: add `display/window/frame_pacing/android/swappy_mode=0`? The default
   (2, auto) may lock a 40–60 fps game to 30 on device. Not seen on the emulator (its
   fps histogram has no cluster at 30) — check on the A55 before changing.
Ruled out: release export as a big win (research cited 3.6× from a VM microbench;
measured here on Windows templates with the real sim: release only 5–12% faster —
late mix 522–554 vs 566–631 µs/tick); C# (Android export experimental, .NET 9 EOL);
GPU compute (float32, readback stalls); Compatibility renderer (GPU is not the
bottleneck); MultiMesh (the per-instance GDScript loop costs about what the draw
calls do; entity draw is no longer the main cost); physics interpolation (does not
reach `_draw` content); `max_physics_steps_per_frame` (trades slowdown for
dilation, fixes nothing). Keep `thread_model=2`: the logcat line is a GL-context
hook Android does not override; the render thread still starts.
- [x] **P26 (research #1) — y-filtered separation window** (exact): the sweep drops
  k with |ys[k] − y0| ≥ 16 + SWEEP_SLACK + 1/16 and falls back to the plain scan when
  ys[ii] moves ≥ SWEEP_SLACK. New oracle `test_sweep_matches_the_pair_loop_on_a_column`;
  removing the y fallback fails all 3 sweep oracles (mutation check). Bench late-mix
  separation 284–292 → 252–264 µs/tick (−11%, less than the research's 1.5–3×). Split
  at 135 candidates: candidates 38 µs + copy-in 25 + copy-out ~25 (object access) vs
  sweep 104 — half the pass is `Enemy` property access, which research #3 (SoA)
  removes. Ruling: skip #2 as a separate step (inlining would be rewritten by SoA);
  go straight to #3 and inline while converting.
- [x] **P27 (research #2, revised) — field locals in the swarm loop** (exact): the
  inlined seeker step reads x/y/vx/vy once into locals, writes them back once, and
  runs its clamp on the locals (11 gets + 4 sets → 5 gets + 4 sets, clamp 4 → 0 extra
  gets); the type is read once for the match and the sweep test; sweep types return
  from their cull. Bench loop 268–272 → 218–227 µs/tick (−18%). Tried and reverted:
  merging `separation_candidates()` with the x/y copy and writing back only pushed
  enemies — isolated separation got slower (149 → 172 µs; Array/packed appends cost
  more than the indexed copies). Tests added and mutation-checked (each mutant fails
  ≥1 test): the four-wall seeker clamp, satellite seekers unclamped, and a
  fallback-only push being written back (an oracle for any future write-back skip).
  Gap found: before these, dropping a clamp factor or a write-back flag passed all
  679 tests.
