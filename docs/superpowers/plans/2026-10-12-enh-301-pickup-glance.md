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

## Ruling ENH-301 R2 (supersedes R1, same day)

After R1 (1.3x, drawn over the swarm) on the emulator, the user: "keep how it previously was
prior the changes we did, but make it bigger. make the glow better. make the colors more pop
out", and earlier "a bit smaller than it currently is". So: the TS draw order again (pickups
under the swarm), size between the TS 1.0 and R1's 1.3, and a better, more saturated glow.

## Tasks

1. [x] `entity_layer.gd`: enemies draw before coins and orbs (player still last);
   `PICKUP_DRAW_SCALE = 1.3` (render-only, via `_begin_entity`'s `extra_scale`; the orb sprite
   bakes at the scaled pixel size) and `PICKUP_HALO_ALPHA = 0.4` for both halos. Tagged
   `DIVERGENCE(ENH-301)`. Sim radii, pickup hitboxes and magnets unchanged.
2. [x] `godot/bench/shot_pickups.gd`: windowed before/after shot (every orb and three coins
   buried in seekers, classic and ember skins, A55 size). Before: no pickup visible. After: all
   orbs read; coins visible but the weakest, most of all over the ember skin.
3. [x] R2: `_draw` back to the TS order (coins, orbs, enemies, player);
   `PICKUP_DRAW_SCALE = 1.15`; both halos are a soft radial glow (`CircleSprites.draw_glow`, a new
   falloff texture, `GLOW_OFFSETS`/`GLOW_ALPHAS`) `PICKUP_GLOW_PAD` (16) px past the radius at
   `PICKUP_GLOW_ALPHA` (0.85), in the pickup colour with saturation x `PICKUP_GLOW_SATURATION`
   (1.25) (`EntityLayer._glow_color`). Seen in a live run on the emulator (debug APK) and in
   `godot/bench/play_pickups.gd` (plays main.tscn windowed, packs seekers around orbs and coins).
   Known consequence: a pickup fully under a cluster is hidden again, as in the TS.
   Then, after 1.15 on the emulator (user: "make it bigger. tone the glow up a bit more"):
   `PICKUP_DRAW_SCALE` 1.25, `PICKUP_GLOW_PAD` 20, `PICKUP_GLOW_ALPHA` 1.0.
4. [x] A55 pass, `godot/VERIFY-ME.md` §ENH-301. Confirmed 2026-10-12 (user: "power ups look
   good now", then "the enhancement for powerups are confirmed"). ENH-301 is done. If pickups still get lost under clusters, ask
   the user before changing the draw order again (R2 reverted it on purpose); an outline or ping
   ring (option A without the lift) is the other lever.

No headless test pins the draw order: Godot exposes no way to observe draw calls (same gap as
`queue_redraw`, HANDOFF §M2.5 Accepted gaps). The bench shot is the evidence.
