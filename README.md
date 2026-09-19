# Elden Arcade

A two-game, original horror arcade built with TypeScript, Canvas 2D, and Three.js.

## Games

### Dread Flight

An endless flyer about guiding a cursed raven through ruined gate towers. The flight model uses fixed-step simulation, pooled procedural gates, progressive but bounded difficulty, local high scores, and procedural Web Audio effects.

- Click/tap the game, `Space`, or `Up` to flap.
- `P` or `Escape` pauses.
- `R` restarts.

### Curse Runner

A 3D endless escape through a cursed jungle temple. Choose lanes, jump, slide, make turns, collect coins, and stay ahead of the hunter.

- `A`/`Left` and `D`/`Right`: change lanes or turn at a junction.
- `W`/`Space`/`Up`: jump.
- `S`/`Down`: slide.
- `P` or `Escape`: pause.
- `R`: restart.
- Mobile controls use directional swipes.

The games use original procedural models, textures, effects, names, and sound design. They are genre tributes, not reproductions of third-party assets or branding.

## Run

```bash
npm install
npm run dev
```

Open `http://127.0.0.1:5173`.

## Verify

```bash
npm run build
npm run smoke
```

`npm run smoke` expects the Vite development server to already be available at `http://127.0.0.1:5173`. Override this with `SMOKE_URL` when needed.
