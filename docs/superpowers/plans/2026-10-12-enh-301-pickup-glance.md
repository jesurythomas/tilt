# ENH-301 — power-ups and coins at a glance

Branch `ENH-301-powerup-coin-glance` (from `main` at `c3d3aeb`).

User (2026-10-12): "When playing, give power ups and coins a better glance value. Currently,
when you are playing, and there are a lot of things happening, power ups and coins can be
hard to identify."

## Cause (read from the code)

- `EntityLayer._draw` drew coins and orbs **before** the enemies, so a dense wave covered them.
- Coins are small (sim radius 9) with an amber `#FFB14D` halo at 0.2 alpha: the same family as
  the hazard-orange enemies, the Ember/Desert/Sandstorm skins and the spark particles.
- Orb halos were 0.2 alpha in the weapon colour.

## Ruling ENH-301 R1

Options offered: (A) lift + dark outline + expanding ping ring, (B) lift + bigger/brighter,
(C) ping + outline only, keep the TS draw order. **User chose B.**

## Tasks

1. [x] `entity_layer.gd`: enemies draw before coins and orbs (player still last);
   `PICKUP_DRAW_SCALE = 1.3` (render-only, via `_begin_entity`'s `extra_scale`; the orb sprite
   bakes at the scaled pixel size) and `PICKUP_HALO_ALPHA = 0.4` for both halos. Tagged
   `DIVERGENCE(ENH-301)`. Sim radii, pickup hitboxes and magnets unchanged.
2. [x] `godot/bench/shot_pickups.gd`: windowed before/after shot (every orb and three coins
   buried in seekers, classic and ember skins, A55 size). Before: no pickup visible. After: all
   orbs read; coins visible but the weakest, most of all over the ember skin.
3. [ ] A55 pass, `godot/VERIFY-ME.md` §ENH-301. If coins still get lost, the next step is
   option A's dark outline and ping ring for coins only (no new ruling needed beyond the user
   saying so).

No headless test pins the draw order: Godot exposes no way to observe draw calls (same gap as
`queue_redraw`, HANDOFF §M2.5 Accepted gaps). The bench shot is the evidence.
