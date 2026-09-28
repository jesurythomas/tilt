# tools/

Scripts for building, testing and measuring Peril Point. Paths to Godot, adb and the
Android SDK are hard-coded for the dev machine; override with `GODOT` or `ANDROID_HOME`
where a script reads them.

| Script | What it does |
|---|---|
| `run_tests.sh` | Runs the GUT suite headless. It fails if any test script didn't parse; GUT alone would silently skip those. |
| `release.sh` | Builds the signed release APK, `godot/build/peril-point-<version>.apk`. See its header for the keystore env file. |
| `frametime.sh <secs> <label>` | Device frame-time percentiles from SurfaceFlinger (`dumpsys gfxinfo` sees no Godot frames). |
| `bake-audio/` | Node scripts that run the web prototype's `TiltAudio.ts` and bake the game's sound effects and music to WAV. |
| `parity/` | Dumps constants, goals and progression tables from the TypeScript, for the GDScript parity tests. |

## emulator/

These scripts target `emulator-5554`. Tap coordinates are in the 2000×891 screenshot
space, which is ×1.212 of the 2424×1080 device.

| Script | What it does |
|---|---|
| `deploy.sh [--fresh]` | Exports the debug APK, installs and launches it. `--fresh` wipes the save. |
| `g.sh` | `shot NAME`, `tap X Y`, `swipe …`, `key K`, `log [n]`, `perf [n]`. |
| `bot.sh SECS` | Flies the ship round a square, so runs are repeatable. |
| `perf_patch.sh apply\|revert` | Temporary stress mode: no death, fast spawns and everything maxed. **Never commit it applied.** |
| `ab.sh`, `menu_idle.sh`, `power_fps.sh`, `perf_buckets.sh` | A/B two APKs, idle the menu, show the fps dip around power-ups, and average PERF lines by enemy count. |
| `verify_ui.sh OUT_DIR` | A scripted screenshot pass over the main screens. |
