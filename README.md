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

## Repository layout

| Path | Contents |
|---|---|
| `web/` | The TypeScript / Canvas 2D game. npm root. |
| `godot/` | **Peril Point** — Godot 4.7.2 mobile port, in progress. Start with `godot/PREREQUISITES.md`. |
| `tools/` | Scripts bridging the two (audio bake, constant parity). |
| `archive/` | Frozen design boards, backups and screenshots. |
| `docs/superpowers/specs/` | Design specs. |

The web game is the reference implementation for the Godot port and is not being
retired — the audio bake step executes `web/src/tilt-to-live/TiltAudio.ts`.

### Peril Point

The Godot mobile port ships as **Peril Point** (Android id `com.jtg.perilpoint`),
landscape, Android first with iOS deferred until a macOS host is available.

Its source is the web game under `web/src/tilt-to-live/`, which **keeps its own
name** — the directory, the TypeScript filenames and every `# PORT:` citation in
the GDScript are unchanged, because the port's traceability rule (Law 1) depends
on those paths resolving.

- Port design: `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md`
- Plan index: `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md`
- Current state: `godot/HANDOFF.md` · progress: `godot/PORT-PROGRESS.md`

## Run

```bash
cd web
npm install
npm run dev
```

Open `http://127.0.0.1:5173`.

## Verify

```bash
cd web
npm run build
npm run smoke
```

`npm run smoke` expects the Vite development server to already be available at `http://127.0.0.1:5173`. Override this with `SMOKE_URL` when needed.
