# web/ — the Peril Point prototype

This is the original browser version of the game, in TypeScript and Canvas 2D, built
with Vite. The shipping game is the Godot project in `../godot/`, a line-by-line port
of the code here.

It stays for two reasons:

- **Reference.** Every tuned number in the GDScript cites its line here, e.g.
  `# PORT: web/src/tilt-to-live/EnemySwarm.ts:566`. The folder keeps its working name,
  `tilt-to-live`, so those citations resolve.
- **Audio source.** `../tools/bake-audio/` runs `src/tilt-to-live/TiltAudio.ts` to bake
  the game's sound effects and music.

```bash
npm install
npm run dev                  # http://127.0.0.1:5173
npm run build && npm run smoke
```

Where the Godot game deliberately differs from this code, the GDScript says so with a
`DIVERGENCE(...)` tag.
