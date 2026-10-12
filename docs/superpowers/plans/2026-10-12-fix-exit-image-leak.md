# fix/exit-image-leak — intermittent "leaked at exit" in the test suite

Branch `fix/exit-image-leak` (from `main` at `a99bfd9`). Found while finishing ENH-302 task 5.
User (2026-10-12): "Fix it first - we dont want any issues", "create a new branch for this issue".

## Symptom

`tools/run_tests.sh` passed, but some runs ended with
`ERROR: 1 RID allocations of type '...DummyTexture' were leaked at exit` and/or
`WARNING: 1 ObjectDB instance was leaked at exit`. The runner did not fail on it.

## Investigation (systematic debugging, all full-suite runs)

| Runs | Setup | Leaked |
|---|---|---|
| 22 | `main` (`a99bfd9`), Separate render thread | 2 |
| 9 | pre-ENH-301 `c3d3aeb` | 1 |
| 13 | ENH-302 branch | 4 |
| 6 | ENH-302 source + `main`'s tests | 1 |
| 15 | ENH-302 + post-run hook clearing `CircleSprites`/`WeaponIcons` static caches | 3 |
| 20 | `--verbose` (2 leaked: `Leaked instance: Image ... Reference count: 1`) | 2 |
| 15 | `main` with `--render-thread safe` | **0** |

- Not ENH-301 or ENH-302: it predates both.
- Not the static texture caches (H1, refuted: clearing them changed nothing).
- The object and the RID leak independently. The leaked `Image` is the headless dummy texture
  store's copy for a texture RID whose free never ran.
- **Root cause (H2, confirmed):** `rendering/driver/threads/thread_model=2` (Separate, M11c P24).
  Texture create/free are queued to the render thread; at shutdown a free queued just before
  quit is sometimes dropped. Godot prints at every start that Separate is experimental. An engine
  shutdown race, not a leak in the game.

## Ruling

Keep Separate for the game (P24: ~40–50% more fps on the emulator at 100–249 enemies). Fix the
runner: `--render-thread safe` for the suite (the benches already use it), and fail any run
that prints "leaked at exit", so a real leak can no longer pass unseen.

## Tasks

1. [x] RED: a temporary probe test leaking one `Object`; the runner printed OK, exit 0.
2. [x] `tools/run_tests.sh`: `--render-thread safe`; fail on "leaked at exit" with the
   `--verbose` command to name it. With the probe: FAIL, exit 1. Probe removed.
3. [x] `godot/CONVENTIONS.md` §1.3 describes the leak gate and the Safe render thread.
4. [x] Ten gated runs of the real suite: 10/10 OK, nothing leaked (25 of 25 clean on Safe in
   all).
5. [ ] Merge to `main` (user's call), then rebase `ENH-302-joystick-position` onto it.
