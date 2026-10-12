# Peril Point

A landscape arcade survival game for Android. You steer a small ship through an
arena that fills with a swarm of red dots. You never shoot: you fly into weapon orbs,
and each one fires by itself. Survive as long as you can, chain kills for score, and
spend the points each run pays on upgrades.

Android package `com.jtg.perilpoint`. iOS waits on a macOS host.

## The game

- **Steer** by touch (drag anywhere) or by tilting the phone (gyroscope, with a
  calibrate screen). Off mobile, the keyboard works too.
- **Three modes.** *Standard* is the full arsenal against ramping swarms. *Gauntlet*
  has walls that close in while you dodge. *Code Red* starts at double density from
  the first second.
- **Seven power-ups**, picked up as orbs: Blackhole, Missiles, Laser, Nuke, Freeze,
  Shield and Lightning.
- **Thirteen enemy behaviours**, from plain seekers to chargers, artillery, carriers,
  pulsars, specters, snakes, turrets and wall, arrow and circle formations.
- **The Armory**, where each run's points are spent:
  - *Weapons*: upgrade tracks per power-up, plus three keystones each (21 in all).
  - *Ships*: seven hulls, each with its own hitbox, turn rate and starting weapon.
  - *Arena*: six themes and six enemy skins; the skins add patterns to the dots.
  - *Handling*: top speed and tilt sensitivity.
  - *Boosts*: extra life, smaller hull, enemy slow, and score and points multipliers.
  - The Ships and Arena tabs preview your choice in a live arena view.
- **57 achievements**, each paying points. A run's completions queue as toasts and are
  listed on the Run over screen.
- **Audio:** sound effects and generative music, baked from the web prototype's Web
  Audio synthesis.

## Repository layout

| Path | Contents |
|---|---|
| `godot/` | **The game.** A Godot 4.7.2 project, in GDScript. |
| `native/` | A C++ GDExtension (`libperil`) with the hot loops: swarm step, separation, enemy and particle drawing, and the missile snapshot. Built with SCons against the `godot-cpp` submodule. |
| `web/` | The original TypeScript / Canvas 2D prototype (`web/src/tilt-to-live/`). It is the reference that the Godot code is ported from, line by line. |
| `tools/` | The test runner, audio bake, constant-parity dumps, and emulator/perf scripts. |
| `docs/superpowers/` | Design specs, module plans and reviews. |
| `peril-point-mobile-redesign/` | The mobile interface design boards (`*.dc.html`). |
| `archive/` | Frozen earlier designs, backups and screenshots. |

### How the port works

The Godot code is a faithful translation of the web prototype, not a rewrite:

- **Numbers.** Every tuned number cites its source, e.g.
  `# PORT: web/src/tilt-to-live/PlayerShip.ts:118`.
- **Deliberate changes.** Every change the TypeScript didn't have is tagged with the
  ruling that allowed it, e.g. `DIVERGENCE(ARMORY R7)`.
- **Speed.** The native extension keeps the GDScript version of each routine it
  replaces, and tests check the two match bit for bit.

The rules are in `godot/CONVENTIONS.md`. The prototype keeps its working name
(`tilt-to-live`) so that every citation still resolves.

## Where to start

| Read | For |
|---|---|
| `godot/HANDOFF.md` | The current state and what to do next. |
| `godot/PREREQUISITES.md` | Toolchain setup (Godot, Android SDK, JDK, gdtoolkit). |
| `godot/CONVENTIONS.md` | The port laws, style and the module exit protocol. |
| `godot/PORT-PROGRESS.md` | The module checklist (M0–M11). |
| `godot/VERIFY-ME.md` | Checks that need a real phone and a person. |
| `CLAUDE.md` | The working loop for AI-assisted sessions. |

## Build and run

Godot is not on `PATH` on the dev machine. Set it once:

```bash
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
```

**Play on desktop.** Open `godot/project.godot` in the Godot editor and press Play.

**Run the tests.** The GUT suite (767 tests) runs headless:

```bash
tools/run_tests.sh
```

**Lint.** Warnings are errors, and gdtoolkit is pinned in CONVENTIONS:

```bash
gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
```

**Build the native extension.** The built libraries in `godot/bin/` are committed, so
this is only needed after editing `native/src/`:

```bash
git submodule update --init native/godot-cpp
cd native
python -m SCons platform=windows target=template_debug
python -m SCons platform=macos arch=universal target=template_debug   # on a Mac
ANDROID_HOME=C:/Users/Jesury/AppData/Local/Android/Sdk \
  python -m SCons platform=android arch=arm64 target=template_debug ndk_version=29.0.14206865
```

**Build a release APK to share:**

```bash
tools/release.sh
```

This writes `godot/build/peril-point-<version>.apk`, signed, for 64-bit ARM phones
running Android 10+. Raise `version/code` in `godot/export_presets.cfg` before each
build you hand out, so it installs over the last one.

The signing key comes from an env file: by default `~/.android/peril-dev-release.env`,
or wherever `PERIL_KEYS` points. It holds the `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
`_USER` and `_PASSWORD` variables. The default key is a throwaway dev key; make a real
one before a store release (header of `tools/release.sh`). Keys never go in git.

**Build a debug APK** (it includes the per-second PERF log):

```bash
"$GODOT" --headless --path godot --export-debug "Android" build/peril-point-debug.apk
```

**Try it on the emulator.** `tools/emulator/deploy.sh [--fresh]` exports the APK,
installs it on `emulator-5554` and launches it. `--fresh` wipes the save. The other
scripts in `tools/emulator/` script taps, screenshots and PERF captures.

## The web prototype

```bash
cd web
npm install
npm run dev        # http://127.0.0.1:5173
npm run build && npm run smoke
```

The prototype stays in the repo for two reasons. It is the port's reference, and
`tools/bake-audio/` runs its `TiltAudio.ts` to render the game's sound effects and music.
