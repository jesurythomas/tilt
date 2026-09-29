# Arena looks: every arena theme gets its own pattern, motion and grid style

Written 2026-09-29. Ruling THEME R2 (user: "arena themes kinda look similar which makes
getting other arenas kinda pointless"; scope: pattern + motion first, then grid styles, on
all 16 themes). Cause: a theme was a dark radial gradient plus a grid colour and a boundary
colour on the same square grid; `dust_color` was never drawn in the arena.

## Design

- `ArenaThemeConfig.pattern` (enum `ProgressionManager.ArenaPattern`, one per theme, all
  distinct) picks a procedural effect in `arena_background.gdshader`. The shader also gets
  `accent` (the theme's `dust_color`), `accent2` (its boundary colour) and `unit` (height /
  1080, so a small preview is a scaled picture of the arena). Motion is `TIME`, so it costs no
  CPU. `GridLayer` and `ArenaPreview` set the same uniforms, so the shop matches the game.
- Effects stay dim (alpha at most about 0.3) so enemies stay readable.
- Patterns: void none · synthwave horizon sun · nebula twinkling stars and cloud · matrix
  falling code · supernova heat waves · blueprint drafting lines · arctic snow · ember rising
  sparks · neon slanted rain · ocean bubbles and caustics · desert blown sand · ph turning
  rays · jp ripple rings · br drifting diagonal bands · us stars and bars · de three bands.
  The flag themes use colours and abstract structure only, no emblem.
- Phase 2 (grid styles, after the user has seen phase 1): a per-theme style for how the
  lattice is drawn (lines, dots, crosses, brick, diagonal), from the same reactive points.

## Tasks

- [x] **1. Pattern field, shader effects, both consumers.** Tests: every theme has a distinct
  pattern; the game layer and the preview set the shader's pattern uniforms. A bench script
  (`godot/bench/arena_sheet.gd`) renders all 16 to a contact sheet to look at. Done
  2026-09-29 (828 tests; the contact sheet was reviewed, and the faint effects were
  strengthened after a half-size look).
- [ ] **2. A55 pass on phase 1** (`VERIFY-ME.md` §Theme R2): look, readability of enemies,
  frame time (`tools/frametime.sh`).
- [ ] **3. Grid styles** (phase 2), only after task 2.
