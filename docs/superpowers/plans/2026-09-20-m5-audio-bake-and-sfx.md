# Module 5 — Audio Bake and SFX: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the port its sound effects. A Node script runs `web/src/tilt-to-live/TiltAudio.ts` unchanged in headless Chrome, renders each SFX offline, and writes the results to `godot/assets/audio/sfx/*.wav`. `AudioBank` then plays those files through a polyphonic player. The remaining audio lifecycle calls (`unlock`, `setMuted`/volumes, `stopMusic`) are wired at their TS sites.

**Architecture:** Every SFX call site was ported against a silent `AudioBank` stub in M2–M4. The sim receives the bank as a parameter, as the TS passes its `TiltAudio` (`score_manager.gd:123`, `weapon_system.gd:129`, `run_controller.gd:269-332`, `coin_system.gd:93`). So M5 changes what `AudioBank` does, not who calls it. `tools/bake-audio/bake_sfx.mjs` strips the types from `TiltAudio.ts` (`node:module` `stripTypeScriptTypes`) and loads it into a Puppeteer page. There it swaps `window.AudioContext` for an `OfflineAudioContext`, calls each `play*` method, and writes 16-bit mono WAV. `AudioBank.attach(host)` loads the 37 files and adds one `AudioStreamPlayer` whose stream is an `AudioStreamPolyphonic`. Each `play_*` then calls `play_stream` on it. Music (`start_music`/`stop_music`) stays a stub for M6, but its call sites are wired now, so M6 only has to fill in the bodies.

**Tech Stack:** Godot 4.7.2-stable, GDScript (static typing enforced), GUT 9.6.1 headless, gdtoolkit 4.5.0; Node 24.14 + Puppeteer 25.9 (already a `web/` devDependency) + Chrome headless for the bake.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` §8 Module 5, D5 (§3), §4.2 layout, §6.4 "Missing baked audio", §9 risk "Baked SFX lose per-invocation variation". Read the spec's §8 M5 and `godot/CONVENTIONS.md` before any task.

**TS source (read in full before Tasks 1–2):** `web/src/tilt-to-live/TiltAudio.ts` (886 lines). The SFX are at `:481-885`, and the gain graph and mute are at `:29-80`. For Task 3, also read the `TiltGame.ts` sites cited there.

---

## The five port laws (restated — binding on every task)

1. **No invented numbers.** Every numeric literal carries `# PORT: <ts path>:<line>` (or `// TiltAudio.ts:<line>` in the bake script). Exempt: `0`, `1`, `-1`, `0.0`, `1.0`, array indices.
2. **No silent improvement.** Odd TS is ported as written with `# PORT-NOTE: … — preserved deliberately`.
3. **One file, one file.** `TiltAudio.ts` → `audio/audio_bank.gd` (music half → M6's `audio/music_sequencer.gd`, spec §8 M6). Same members, snake_cased.
4. **Nothing new.** Only what the TS, a spec line, or a ruling below requires.
5. **Stop, do not guess.** Ambiguity → record in `godot/HANDOFF.md` and ask.

## Rulings (recorded 2026-09-25, before execution)

- **R1 — WAV, not Ogg (user ruling, 2026-09-25).** This machine has no Ogg encoder (`ffmpeg`, `oggenc` and `sox` are all absent). Godot 4.7's docs recommend WAV for short, repetitive SFX: `ResourceImporterWAV` imports with lossy QOA compression by default and decodes more cheaply than Ogg Vorbis on low-end devices. The bake therefore writes **16-bit PCM mono WAV at 44 100 Hz** (Godot's default `audio/driver/mix_rate`; `project.godot` does not override it), and the default import settings are kept. A headless spike on 2026-09-25 confirmed that an imported WAV loads as `AudioStreamWAV` with `format == 3` (`FORMAT_QOA`). Task 1 amends spec §4.2 and §8 M5, and Task 6 amends `PORT-PROGRESS.md`, from `.ogg` to `.wav`.
- **R2 — 32 voices (user ruling, 2026-09-25).** Web Audio overlaps SFX without limit. A nuke can fire dozens of `playDotPop`s in one frame (`WeaponSystem.ts:211`). `AudioStreamPolyphonic.polyphony` needs a cap, and the user chose Godot's default of **32**. `play_stream` returns `INVALID_ID` (-1) once 32 voices are playing, so the extra voice is dropped silently (confirmed headless: voices 1–32 got ids and the 33rd and 34th got -1). This is tagged `DIVERGENCE(M5 R2)`.
- **R3 — The bake executes `TiltAudio.ts` unmodified in headless Chrome.** It uses Puppeteer from `web/node_modules` (`createRequire(web/package.json)`, spec §8 M5: "resolves its dependencies from `web/node_modules`"). Chrome's `OfflineAudioContext` renders the same Web Audio graph the web game plays. There are exactly three shims, all in the page and none in the TS: `window.AudioContext` returns the offline context; `ctx.resume` resolves at once, because an offline context rejects `resume()` before `startRendering()` (seen in the spike as `InvalidStateError`); and `Math.random` is pinned to `0.5` (R6). A spike on 2026-09-25 rendered `playNuke` at a peak of 0.1586, which is ≈ 0.6 × 0.28 (`:544` × `:35`).
- **R4 — The baked level is the whole TS graph.** Each file is the method's output through `sfxGain` 1.0 (`:39`) and `masterGain` 0.28 (`:35`). At run time, `AudioBank` applies only what the TS changes at run time: `set_sfx_volume` → the player's `volume_linear` (the `sfxGain`, clamped 0–1, `:66-70`), and `set_muted` → `volume_linear = 0` (`masterGain` 0, `:54`, `:62`) plus the early return every `play*` opens with (`:484`).
- **R5 — The render length is each method's last `stop()` time.** Examples: `playNuke` → 0.7 s (`:550`); `playIceCascade` → 0.08 + 0.13 = 0.21 s (`:705`, i = 2); `playMilestone` → 0.12 + 0.24 = 0.36 s (`:783`, idx = 3). The bake's table cites each one. Nothing is trimmed and no tail is added.
- **R6 — Variants.** `playDotPop(i)` plays `scale[i % 15]` (`:754`), so it is baked as **15 files** `dot_pop_00`…`dot_pop_14`, each exact. `playSpaceInvaderStep(s)` plays `notes[s % 4]` (`:830`), baked as **4 files** `space_invader_step_0`…`_3`. `playLightning` is the only SFX with randomness (`:617`, start frequency `1200 + random() * 400`). It is baked once with `random()` = 0.5 (1400 Hz), and `AudioBank` plays it at `pitch_scale = (1200 + randf() * 400) / 1400`. This is the spec §9 risk-register mitigation ("`pitch_scale` randomisation — close, not identical"). Pitch scaling also moves the 200 Hz end and shortens or lengthens the sweep, and a PORT-NOTE says so. No other SFX is pitch-randomised (Law 4).
- **R7 — No `GameEvents` wiring.** Spec §8 M5 lists "`GameEvents` → audio wiring", but the TS calls its audio object directly from the sim. M2–M4 already ported every one of those calls against `AudioBank`, and CONVENTIONS §7 forbids new `GameEvents` signals without a spec change. The direct calls satisfy the bullet, and `GameEvents` gains nothing.
- **R8 — Unused SFX are baked but not called.** `playIceCascade` and `playGauntletKlaxon` (M10 R11) are referenced only by the menu-sim no-op audio object (`TiltGame.ts:1803-1804`). `playSpaceInvaderStep` is referenced only there too (`:1801`). `playInvasionAlarm` has no reference in `web/src`. `playWarpIn`'s only caller is the entrance cinematic (`TiltEntranceCinematic.ts:74`), which is M11. All five are baked and their `play_*` methods work, but M5 adds no call site. `HANDOFF.md` hands `play_warp_in` to M11.
- **R9 — Music stays M6.** `start_music`/`stop_music` keep their bodies as `TODO(M6)` stubs. M5 wires every TS call site of `unlock`, `stopMusic`, `startMusic` and the volume setters that the port has a place for (Task 3). `set_music_volume` stores `clamp(vol, 0, 1) * 0.35` (`:74`) in a public `music_gain` for M6 to read. The cinematic's `startMusic` (`TiltGame.ts:169-172`) has no Godot site until M11, and `HANDOFF.md` records that M6 must start music at run start.
- **R10 — `attach()` stands in for `unlock()`'s context creation.** `unlock()` creates the `AudioContext` and its three gains (`:30-45`) and resumes a suspended context (`:46-48`). Godot has no gesture-gated context. Its audio needs a node in the tree, so `AudioBank.attach(host: Node)` builds the player and loads the bank. `GameRoot._ready` calls it. `unlock()` stays a no-op with a PORT-NOTE and is called at its TS site (`launch_run`, `TiltGame.ts:1492`). An unattached bank, as used in every sim test, plays nothing.
- **R11 — Sound options are applied in `RunController.reset_run`.** `TiltGame.resetRun` applies `setMuted`/`setSfxVolume`/`setMusicVolume` (`:1607-1610`). `GameRoot.restart_run` (Retry, Restart run) goes around `GameStateMachine.reset_run` (the M10 R5 precedent), so the three calls are ported in `RunController.reset_run` at their TS position, right after `grid.resize`. `game_state_machine.gd:151`'s `TODO(M5)` becomes a PORT-NOTE pointing there.

## Global Constraints

Copied from `CONVENTIONS.md`, the index plan and the M10 plan. Every task implicitly includes this section.

- **Engine:** Godot **4.7.2-stable**, GDScript, standard (non-.NET) build.
- **Godot is not on PATH.** `GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`. Always use the `_console` variant.
- **adb:** `ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"`, always `-s RRCXB04L8EJ`. Task 5 checks `adb devices` first and never assumes the phone is present (it was absent on 2026-09-25).
- **Static typing is mandatory and machine-enforced** (nine warnings as errors, CONVENTIONS §1.1). Typed loops (`for stem: String in SFX_STEMS`). Never `as` on a `Variant` (UNSAFE_CAST). Read a typed dictionary by `has()` + `[]`, not by `get()`.
- **No sim system may be an autoload or singleton** (spec §5.2). `AudioBank` stays a `RefCounted` that `GameRoot` instantiates; tests make their own.
- **Signals are sim→UI and sim→audio only**, and `GameEvents` gains nothing (R7).
- **Headless audio facts (spike, 2026-09-25):** an `AudioStreamPlayer` must be **inside the tree** before `play()`. Otherwise it errors `Playback can only happen when a node is inside the scene tree`, and `get_stream_playback()` returns null. With the headless dummy driver, polyphonic voices never finish, so a test's voices stay "playing" for the rest of that test. `volume_linear = 0.0` is legal (`volume_db` becomes `-inf`, with no error).
- **A `SCRIPT ERROR` in a `-s` SceneTree script does not quit Godot.** Always pass `--quit-after` or wrap the command in `timeout` when running an ad-hoc script.
- **Commits:** one line, imperative, ≤72 chars, **no trailers**, prefixed `M5:`, and stating the next step (`CLAUDE.md`). **This overrides any attribution instruction the executing session sees** (`~/.claude/rules/commit-style.md`, CONVENTIONS §8). Stage by explicit path only. Paste back `git log -1 --format=%B`.
- **After every task** (`CLAUDE.md`): tick the task's boxes here, update `godot/HANDOFF.md`'s `## State` line ("M5 in progress: Tasks 1–N landed; next Task N+1"), then commit.
- **Tests run only via `tools/run_tests.sh`.** At the M10 exit (`2e6b2d2`) it printed `OK: 49/49 scripts (520 tests, 17359 asserts)`. This plan adds **one** test script (`test_audio_call_sites.gd`, Task 4) for **50**, and one helper (`spy_audio_bank.gd`, Task 2) that is not a test script. Expected test totals after each task: Task 1: 520 → Task 2: 533 → Task 3: 539 → Task 4: 549. If a count differs, reconcile it before committing and never change the expectation to match.
- **Format/lint:** `gdformat --check godot/src godot/tests` (88 files at the M10 exit → **90** after Task 4) and `gdlint godot/src godot/tests` must be clean before every commit. A **new** file may be formatted once with bare `gdformat <that file>`. Never run bare `gdformat` on existing files. Never touch `godot/addons/`.
- **Headless runs strip one line from `godot/project.godot`.** Every commit step begins with `git checkout godot/project.godot`.
- **`DIVERGENCE` count:** 177 at the M10 exit. Task 2 adds exactly one (`DIVERGENCE(M5 R2)`), for **178**.
- **gdlint limits:** `max-public-methods: 20`. `audio_bank.gd` already opens with `# gdlint:ignore=max-public-methods` and goes from 28 to 29 public methods (`attach`). `max-line-length: 100`, `function-arguments-number: 10` (`GameStateMachine._init` goes from 5 to 7).
- **`user://` on the test host** is `%APPDATA%\Godot\app_userdata\Peril Point\`. Any spec that constructs `GameOptionsManager` and saves removes `GameOptionsManager.SAVE_PATH` and its `SaveStore.corrupt_path_for(...)` twin in `before_each` **and** `after_each`, as `test_run_controller.gd:22-31` does.

## Review Focus

These are the inputs the spec implies that are most likely to bite a player. Each one has its test in the named task.

1. **A nuke through a dense swarm.** Dozens of kills in one frame means dozens of `play_dot_pop` calls. The first 32 voices play, the rest are dropped, and nothing errors or stalls (R2). Task 2 `test_voice_cap_drops_the_thirty_third_voice`; Task 5 device check "Nuke storm".
2. **Sound switched off on Pause while a long SFX (death, nuke) is still sounding.** The tail goes silent at once (`masterGain` 0, `:62`). Switching Sound back on restores the saved SFX volume, not 1.0. Task 2 `test_muting_silences_the_player_and_blocks_new_voices`.
3. **A missing or renamed baked file**, for example a fresh clone before `--import` or a stem typo. It logs a warning, that SFX plays silence, and the run continues (spec §6.4). Task 2 `test_missing_files_log_and_play_silence`.
4. **Retry / Restart run**, which reach `RunController.reset_run` but not `GameStateMachine.reset_run`. They must still apply the saved Sound switch and volumes (R11). Task 3 `test_reset_run_applies_the_sound_options`.
5. **A combo longer than the 15-note scale, or an out-of-range volume from a hand-edited save.** Combo 16 plays note 1 again (`:754`), and a volume of 1.5 or -1 clamps to 1 or 0 (`:68`, `:74`). Task 2 `test_dot_pop_wraps_the_pentatonic_scale` and `test_sfx_volume_clamps_and_drives_the_player`.

---

## File Structure

| File | Role in M5 |
|---|---|
| `tools/bake-audio/bake_sfx.mjs` | **Create** (Task 1). The bake (R1, R3–R6). |
| `godot/assets/audio/sfx/*.wav` (37) + `*.wav.import` (37) | **Create** (Task 1). Baked output and its Godot import sidecars, both committed (fonts precedent: `godot/assets/fonts/*.ttf.import` are tracked). |
| `godot/assets/audio/sfx/.gitkeep` | **Delete** (Task 1). The folder is no longer empty. |
| `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` | **Modify** (Task 1). R1 amendment notes at §4.2 and §8 M5. |
| `godot/src/audio/audio_bank.gd` | **Rewrite** (Task 2). Real playback. |
| `godot/tests/spy_audio_bank.gd` | **Create** (Task 2). `class_name SpyAudioBank extends AudioBank` test helper (the `ui_checks.gd` precedent). |
| `godot/tests/test_audio_bank.gd` | **Rewrite** (Task 2). From 1 test to 13. |
| `godot/src/core/game_root.gd` | **Modify** (Tasks 2–3). `_audio.attach(self)`; `open_armory`'s `stop_music`; the `GameStateMachine` constructor call. |
| `godot/tests/test_main_scene.gd` | **Modify** (Task 2). +1 test. |
| `godot/src/core/game_state_machine.gd` | **Modify** (Task 3). `_audio`, `_options`; the six `TODO(M5)` sites. |
| `godot/src/sim/run_controller.gd` | **Modify** (Task 3). Sound options in `reset_run` (R11). |
| `godot/tests/test_game_state_machine.gd` | **Modify** (Task 3). New constructor; +5 tests. |
| `godot/tests/test_run_controller.gd` | **Modify** (Task 3). +1 test. |
| `godot/tests/test_audio_call_sites.gd` | **Create** (Task 4). 10 tests: each live SFX fires at its TS moment. |
| `godot/VERIFY-ME.md` | **Modify — append** (Task 5). `## M5 — Audio bake and SFX`. **Never recreate this file.** |
| `godot/PORT-PROGRESS.md`, `godot/HANDOFF.md`, `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md` | **Modify** (Task 6). Exit protocol. |
| `godot/src/sim/score_manager.gd`, `weapon_system.gd`, `coin_system.gd`, `core/game_events.gd`, `project.godot`, `scenes/main.tscn` | **Not modified.** Their SFX calls are already ported (R7). |

**Task order rationale.** The bake (Task 1) produces the files every later task loads, and its numbers need their own review against `TiltAudio.ts`. `AudioBank` (Task 2) makes those files audible and creates the spy that Tasks 3–4 assert with. The lifecycle wiring (Task 3) needs the real mute and volume behaviour. The call-site proofs (Task 4) change no production code, so they come last among the code tasks: a failure there points at an M2–M4 port bug, not at M5's new code. Device evidence (Task 5) and exit (Task 6) come last.

**Spec §8 M5 coverage.**

| Spec bullet / Accept line | Task(s) |
|---|---|
| `tools/bake-audio/` drives `TiltAudio.ts`, writes `godot/assets/audio/sfx/`, resolves deps from `web/node_modules` | 1 (format per R1) |
| `audio/audio_bank.gd` with `pitch_scale` randomisation | 2 (R6: lightning) |
| `GameEvents` → audio wiring | R7 (already direct); 3 (lifecycle calls) |
| Accept: every `play*` has a baked file | 1 (bake), 2 (`test_every_baked_file_exists_and_nothing_else`, `test_each_play_method_requests_its_file`) |
| Accept: …that fires at the correct moment | 4 (call sites), 5 (device) |
| Accept: a missing file logs and continues without crashing | 2 (`test_missing_files_log_and_play_silence`) |

---

## Tasks

### Task 1: The bake — `tools/bake-audio/bake_sfx.mjs` and the 37 WAVs

**Files:**
- Create: `tools/bake-audio/bake_sfx.mjs`
- Create (generated): `godot/assets/audio/sfx/<stem>.wav` ×37 and `<stem>.wav.import` ×37
- Delete: `godot/assets/audio/sfx/.gitkeep`
- Modify: `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` (§4.2 line `assets/audio/sfx/*.ogg    generated by Module 5`, and §8 Module 5)

**Interfaces:**
- Consumes: `web/src/tilt-to-live/TiltAudio.ts` (unmodified); `web/node_modules/puppeteer` (run `npm ci` in `web/` if it is missing).
- Produces (Task 2 relies on these exact names): 37 files in `godot/assets/audio/sfx/`: `orb_pickup`, `coin_pickup`, `nuke`, `missile_launch`, `missile_explode`, `laser_beam`, `lightning`, `freeze`, `ice_shatter`, `siren`, `ice_cascade`, `gauntlet_klaxon`, `vortex`, `dot_pop_00` … `dot_pop_14`, `milestone`, `player_death`, `close_call`, `space_invader_step_0` … `space_invader_step_3`, `warp_in`, `invasion_alarm`, each followed by `.wav`.

- [ ] **Step 1: Write the bake script**

Create `tools/bake-audio/bake_sfx.mjs`:

```js
// Renders every TiltAudio.ts sound effect to a 16-bit mono WAV in
// godot/assets/audio/sfx/ (spec §3 D5, §8 Module 5; WAV per M5 R1).
//
// Run from the repository root:  node tools/bake-audio/bake_sfx.mjs
// Dependencies resolve from web/node_modules (`npm ci` in web/ first).
//
// TiltAudio.ts runs unmodified inside headless Chrome (M5 R3): Node strips its
// types, the page swaps window.AudioContext for an OfflineAudioContext, and each
// play* call renders offline through the same gain graph the web game plays —
// so every file already carries sfxGain 1.0 and masterGain 0.28 (M5 R4).

import { createRequire, stripTypeScriptTypes } from 'node:module';
import { mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
const outDir = resolve(repo, 'godot/assets/audio/sfx');
const puppeteer = createRequire(resolve(repo, 'web/package.json'))('puppeteer');

// Godot's default audio/driver/mix_rate; project.godot does not override it (M5 R1).
const SAMPLE_RATE = 44100;

// [file stem, TiltAudio method, args, seconds]. seconds = the method's last
// osc.stop() time (M5 R5).
const SFX = [
  ['orb_pickup', 'playOrbPickup', [], 0.14], // TiltAudio.ts:499
  ['coin_pickup', 'playCoinPickup', [], 0.17], // :530
  ['nuke', 'playNuke', [], 0.7], // :550
  ['missile_launch', 'playMissileLaunch', [], 0.17], // :569
  ['missile_explode', 'playMissileExplode', [], 0.14], // :588
  ['laser_beam', 'playLaserBeam', [], 0.24], // :607
  ['lightning', 'playLightning', [], 0.1], // :626; random() pinned to 0.5 (M5 R6)
  ['freeze', 'playFreeze', [], 0.27], // :645
  ['ice_shatter', 'playIceShatter', [], 0.1], // :664
  ['siren', 'playSiren', [], 0.5], // :684
  ['ice_cascade', 'playIceCascade', [], 0.21], // :705, i = 2: 0.08 + 0.13
  ['gauntlet_klaxon', 'playGauntletKlaxon', [], 0.4], // :726
  ['vortex', 'playVortex', [], 0.37], // :745
  // One file per pentatonic note: the scale has 15 entries (:23-27); stop at :764.
  ...Array.from({ length: 15 }, (_, i) => [
    `dot_pop_${String(i).padStart(2, '0')}`, 'playDotPop', [i], 0.065
  ]),
  ['milestone', 'playMilestone', [], 0.36], // :783, idx = 3: 0.12 + 0.24
  ['player_death', 'playPlayerDeath', [], 0.6], // :803
  ['close_call', 'playCloseCall', [], 0.1], // :822
  // One file per march note: 4 notes (:829); stop at :844.
  ...Array.from({ length: 4 }, (_, s) => [
    `space_invader_step_${s}`, 'playSpaceInvaderStep', [s], 0.15
  ]),
  ['warp_in', 'playWarpIn', [], 0.52], // :864
  ['invasion_alarm', 'playInvasionAlarm', [], 0.26] // :884
];

function wav(samples, rate) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((s, i) => {
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, s)) * 32767), i * 2);
  });
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16); // PCM fmt chunk size
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(rate, 24);
  header.writeUInt32LE(rate * 2, 28); // byte rate
  header.writeUInt16LE(2, 32); // block align
  header.writeUInt16LE(16, 34); // bits per sample
  header.write('data', 36);
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}

const source = stripTypeScriptTypes(
  readFileSync(resolve(repo, 'web/src/tilt-to-live/TiltAudio.ts'), 'utf8')
);

const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
const pageErrors = [];
let silent = 0;
try {
  const page = await browser.newPage();
  page.on('pageerror', (e) => pageErrors.push(e.message));
  await page.setContent('<!doctype html><html><body></body></html>');
  await page.addScriptTag({ type: 'module', content: `${source}\nwindow.TiltAudio = TiltAudio;` });
  await page.waitForFunction(() => window.TiltAudio !== undefined);

  mkdirSync(outDir, { recursive: true });
  for (const name of readdirSync(outDir)) {
    if (name.endsWith('.wav')) rmSync(resolve(outDir, name));
  }

  for (const [stem, method, args, seconds] of SFX) {
    const samples = await page.evaluate(
      async (m, a, secs, rate) => {
        const ctx = new OfflineAudioContext(1, Math.ceil(secs * rate), rate);
        // An offline context rejects resume() before startRendering() (M5 R3).
        ctx.resume = () => Promise.resolve();
        window.AudioContext = function () {
          return ctx;
        };
        const realRandom = Math.random;
        Math.random = () => 0.5; // M5 R6: only playLightning reads it
        try {
          const audio = new window.TiltAudio();
          audio.unlock();
          audio[m](...a);
        } finally {
          Math.random = realRandom;
        }
        const buffer = await ctx.startRendering();
        return Array.from(buffer.getChannelData(0));
      },
      method,
      args,
      seconds,
      SAMPLE_RATE
    );
    const peak = samples.reduce((p, s) => Math.max(p, Math.abs(s)), 0);
    if (peak === 0) silent++;
    writeFileSync(resolve(outDir, `${stem}.wav`), wav(samples, SAMPLE_RATE));
    console.log(`wrote ${stem}.wav  ${samples.length} frames  peak ${peak.toFixed(4)}`);
  }
} finally {
  await browser.close();
}

if (pageErrors.length > 0 || silent > 0) {
  console.error(`FAIL: ${pageErrors.length} page error(s), ${silent} silent render(s)`);
  for (const message of pageErrors) console.error(`  ${message}`);
  process.exit(1);
}
console.log(`OK: ${SFX.length} files in ${outDir}`);
```

- [ ] **Step 2: Run the bake and read every line**

Run: `node tools/bake-audio/bake_sfx.mjs`
Expected: 37 `wrote …` lines, then `OK: 37 files in …`. The only stderr line allowed is Node's `ExperimentalWarning: stripTypeScriptTypes is an experimental feature`. Check the following against the TS:
- `nuke.wav` has `30870 frames` and a peak ≈ `0.16` (0.6 × 0.28, `:544`, `:35`).
- `dot_pop_00.wav` has `2867 frames` and a peak ≈ `0.03` (0.12 × 0.28, `:758`).
- Every peak is below `0.28` × the method's largest gain.
If any peak is `0.0000` or there is a page error, the script exits 1. Stop and report it. Do not change a shim.

- [ ] **Step 3: Prove the bake is deterministic**

```bash
first="$(mktemp)"
sha256sum godot/assets/audio/sfx/*.wav > "$first"
node tools/bake-audio/bake_sfx.mjs > /dev/null 2>&1
sha256sum godot/assets/audio/sfx/*.wav | diff "$first" -
```
Expected: `diff` prints nothing. (The SFX use no noise buffer, and `Math.random` is pinned.) If it prints anything, stop and report it, because a non-deterministic bake makes every re-bake show up as a diff.

- [ ] **Step 4: Import, and remove the placeholder**

```bash
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --import
ls godot/assets/audio/sfx/*.wav | wc -l          # expect: 37
ls godot/assets/audio/sfx/*.wav.import | wc -l   # expect: 37
grep -h "^compress/mode" godot/assets/audio/sfx/*.wav.import | sort -u   # expect one line: compress/mode=2 (the default, QOA; spike 2026-09-25)
git rm -q godot/assets/audio/sfx/.gitkeep
git checkout godot/project.godot
```

- [ ] **Step 5: Amend the spec (R1)**

In `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` §4.2, change `assets/audio/sfx/*.ogg    generated by Module 5` to `assets/audio/sfx/*.wav    generated by Module 5`. In §8 Module 5, change "offline-render each SFX to `.ogg`" to "offline-render each SFX to `.wav`", and append this paragraph after the Accept line:

```markdown
**Amended 2026-09-25 (M5 R1):** SFX bake to 16-bit mono WAV, imported with
Godot's default QOA compression, not `.ogg`. No Ogg encoder is available on the
build host, and Godot 4.7 recommends WAV for short, repetitive effects (cheaper
to decode than Vorbis on low-end phones). Music stems (M6) are not decided here.
```

- [ ] **Step 6: Run the suite (nothing in `godot/src` changed; this proves the import did not break collection)**

Run: `tools/run_tests.sh`
Expected: `OK: 49/49 scripts collected, all tests passed` with Tests 520.

- [ ] **Step 7: Commit**

Tick this task's boxes and set `## State` in `godot/HANDOFF.md` to "M5 in progress: Task 1 landed; next Task 2 (AudioBank playback)".

```bash
git checkout godot/project.godot
git add tools/bake-audio/bake_sfx.mjs godot/assets/audio/sfx/ docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md godot/HANDOFF.md
git commit -m "M5: bake TiltAudio SFX to wav in headless chrome; next: M5 Task 2"
git log -1 --format=%B
```

---

### Task 2: `AudioBank` — play the baked files

**Files:**
- Rewrite: `godot/src/audio/audio_bank.gd`
- Create: `godot/tests/spy_audio_bank.gd`
- Rewrite: `godot/tests/test_audio_bank.gd` (1 → 13 tests)
- Modify: `godot/src/core/game_root.gd:94` (attach), `godot/tests/test_main_scene.gd` (+1 test)

**Interfaces:**
- Consumes: Task 1's 37 files; `Log.warn(msg: String)` (`log.gd:36`); `AudioStreamPlaybackPolyphonic.play_stream(stream, from_offset, volume_db, pitch_scale) -> int`, `.is_stream_playing(id) -> bool`, `.INVALID_ID`.
- Produces (Tasks 3–4 rely on these exact names):
  - `AudioBank.attach(host: Node, sfx_dir: String = SFX_DIR) -> void`
  - `AudioBank.music_gain: float` (public; M6 reads it)
  - `AudioBank._play(stem: String, pitch_scale: float = 1.0) -> int`, which every `play_*` goes through (the override point for the spy)
  - `const SFX_STEMS: Array[String]` (the 37 stems, in bake order)
  - `class_name SpyAudioBank extends AudioBank` with `requested: Array[String]`, `pitches: Array[float]`, `lifecycle: Array[String]` (records `"unlock"`, `"start_music"`, `"stop_music"`)
  - Every existing public signature is unchanged.

- [ ] **Step 1: Write the spy helper**

Create `godot/tests/spy_audio_bank.gd`:

```gdscript
## spy_audio_bank.gd
## PORTS: nothing — test helper; records what the sim asks AudioBank to play
class_name SpyAudioBank
extends AudioBank
## An unattached, therefore silent, AudioBank that records every play request
## and music lifecycle call, so specs can assert which sound fires when.

## Stems requested through _play, in call order.
var requested: Array[String] = []
## The pitch scale of each request, parallel to `requested`.
var pitches: Array[float] = []
## "unlock", "start_music" and "stop_music" calls, in call order.
var lifecycle: Array[String] = []


## Records the TS unlock() call site.
func unlock() -> void:
	lifecycle.append("unlock")
	super()


## Records the TS startMusic() call site.
func start_music() -> void:
	lifecycle.append("start_music")
	super()


## Records the TS stopMusic() call site.
func stop_music() -> void:
	lifecycle.append("stop_music")
	super()


func _play(stem: String, pitch_scale: float = 1.0) -> int:
	requested.append(stem)
	pitches.append(pitch_scale)
	return super(stem, pitch_scale)
```

- [ ] **Step 2: Write the failing tests**

Replace `godot/tests/test_audio_bank.gd` entirely:

```gdscript
## test_audio_bank.gd
## PORTS: nothing — covers src/audio/audio_bank.gd (spec §8 M5, §6.4)
extends GutTest
## Proves the baked files exist, each play_* asks for its file, and the bank's
## mute, volume, voice cap and missing-file behaviour.

var _host: Node = null


func before_each() -> void:
	_host = Node.new()
	add_child_autofree(_host)


func _attached(sfx_dir: String = AudioBank.SFX_DIR) -> AudioBank:
	var bank: AudioBank = AudioBank.new()
	bank.attach(_host, sfx_dir)
	return bank


func test_every_baked_file_exists_and_nothing_else() -> void:
	var on_disk: Array[String] = []
	for name: String in DirAccess.get_files_at(AudioBank.SFX_DIR):
		if name.get_extension() == "wav":
			on_disk.append(name.get_basename())
	on_disk.sort()
	var expected: Array[String] = AudioBank.SFX_STEMS.duplicate()
	expected.sort()
	assert_eq(on_disk, expected, "tools/bake-audio/bake_sfx.mjs writes exactly SFX_STEMS")
	assert_eq(AudioBank.SFX_STEMS.size(), 37, "18 single SFX + 15 dot pops + 4 march steps")


func test_each_play_method_requests_its_file() -> void:
	var spy: SpyAudioBank = SpyAudioBank.new()
	spy.play_orb_pickup()
	spy.play_coin_pickup()
	spy.play_nuke()
	spy.play_missile_launch()
	spy.play_missile_explode()
	spy.play_laser_beam()
	spy.play_lightning()
	spy.play_freeze()
	spy.play_ice_shatter()
	spy.play_siren()
	spy.play_ice_cascade()
	spy.play_gauntlet_klaxon()
	spy.play_vortex()
	spy.play_dot_pop(3)
	spy.play_milestone()
	spy.play_player_death()
	spy.play_close_call()
	spy.play_space_invader_step(2)
	spy.play_warp_in()
	spy.play_invasion_alarm()
	var expected: Array[String] = [
		"orb_pickup",
		"coin_pickup",
		"nuke",
		"missile_launch",
		"missile_explode",
		"laser_beam",
		"lightning",
		"freeze",
		"ice_shatter",
		"siren",
		"ice_cascade",
		"gauntlet_klaxon",
		"vortex",
		"dot_pop_03",
		"milestone",
		"player_death",
		"close_call",
		"space_invader_step_2",
		"warp_in",
		"invasion_alarm",
	]
	assert_eq(spy.requested, expected)
	for stem: String in spy.requested:
		assert_true(AudioBank.SFX_STEMS.has(stem), "%s is a baked stem" % stem)


func test_dot_pop_wraps_the_pentatonic_scale() -> void:
	var spy: SpyAudioBank = SpyAudioBank.new()
	for combo: int in [0, 14, 15, 16, 31]:
		spy.play_dot_pop(combo)
	var expected: Array[String] = [
		"dot_pop_00", "dot_pop_14", "dot_pop_00", "dot_pop_01", "dot_pop_01"
	]
	assert_eq(spy.requested, expected, "scale[comboIndex % 15] (TiltAudio.ts:754)")


func test_space_invader_step_wraps_the_march() -> void:
	var spy: SpyAudioBank = SpyAudioBank.new()
	for step: int in range(6):
		spy.play_space_invader_step(step)
	var expected: Array[String] = [
		"space_invader_step_0",
		"space_invader_step_1",
		"space_invader_step_2",
		"space_invader_step_3",
		"space_invader_step_0",
		"space_invader_step_1",
	]
	assert_eq(spy.requested, expected, "notes[step % 4] (TiltAudio.ts:830)")


func test_lightning_pitch_spans_the_ts_start_frequencies() -> void:
	seed(5)
	var spy: SpyAudioBank = SpyAudioBank.new()
	for i: int in range(200):
		spy.play_lightning()
	var low: float = 1200.0 / 1400.0
	var high: float = 1600.0 / 1400.0
	var lowest: float = high
	var highest: float = low
	for pitch: float in spy.pitches:
		assert_between(pitch, low, high, "1200 + random() * 400 over the baked 1400 Hz")
		lowest = minf(lowest, pitch)
		highest = maxf(highest, pitch)
	assert_lt(lowest, 0.9, "the spread reaches low")
	assert_gt(highest, 1.1, "the spread reaches high")


func test_other_sounds_play_at_their_baked_pitch() -> void:
	var spy: SpyAudioBank = SpyAudioBank.new()
	spy.play_nuke()
	spy.play_dot_pop(4)
	assert_eq(spy.pitches, [1.0, 1.0] as Array[float], "only lightning is randomised (M5 R6)")


func test_attached_bank_plays_a_voice() -> void:
	var bank: AudioBank = _attached()
	var id: int = bank._play("nuke")
	assert_ne(id, AudioStreamPlaybackPolyphonic.INVALID_ID)
	assert_true(bank._playback.is_stream_playing(id))
	assert_eq(bank._player.get_parent(), _host, "attach() hangs the player on the host")


func test_unattached_bank_is_silent_and_every_method_is_safe() -> void:
	var bank: AudioBank = AudioBank.new()
	assert_eq(bank._play("nuke"), AudioStreamPlaybackPolyphonic.INVALID_ID)
	bank.unlock()
	bank.set_muted(true)
	assert_true(bank.is_muted())
	assert_true(bank.toggle_mute(), "toggle_mute returns !muted (TiltAudio.ts:56)")
	bank.set_sfx_volume(0.5)
	bank.start_music()
	bank.stop_music()
	bank.play_nuke()
	bank.play_dot_pop(7)
	bank.play_lightning()
	pass_test("an unattached bank (every sim spec) plays nothing and never errors")


func test_muting_silences_the_player_and_blocks_new_voices() -> void:
	var bank: AudioBank = _attached()
	bank.set_sfx_volume(0.6)
	bank.set_muted(true)
	assert_eq(bank._player.volume_linear, 0.0, "masterGain 0 while muted (TiltAudio.ts:62)")
	assert_eq(bank._play("nuke"), AudioStreamPlaybackPolyphonic.INVALID_ID, "the :484 guard")
	bank.set_muted(false)
	assert_almost_eq(bank._player.volume_linear, 0.6, 0.0001, "unmuting restores the sfx gain")
	assert_ne(bank._play("nuke"), AudioStreamPlaybackPolyphonic.INVALID_ID)
	bank.toggle_mute()
	assert_eq(bank._player.volume_linear, 0.0, "toggle_mute mutes too (TiltAudio.ts:54)")


func test_sfx_volume_clamps_and_drives_the_player() -> void:
	var bank: AudioBank = _attached()
	bank.set_sfx_volume(0.8)
	assert_almost_eq(bank._player.volume_linear, 0.8, 0.0001)
	bank.set_sfx_volume(1.5)
	assert_almost_eq(bank._player.volume_linear, 1.0, 0.0001, "clamped (TiltAudio.ts:68)")
	bank.set_sfx_volume(-1.0)
	assert_almost_eq(bank._player.volume_linear, 0.0, 0.0001, "clamped (TiltAudio.ts:68)")


func test_music_volume_is_scaled_by_the_music_gain() -> void:
	var bank: AudioBank = AudioBank.new()
	bank.set_music_volume(0.7)
	assert_almost_eq(bank.music_gain, 0.245, 0.0001, "0.7 * 0.35 (TiltAudio.ts:74)")
	bank.set_music_volume(2.0)
	assert_almost_eq(bank.music_gain, 0.35, 0.0001, "clamped before scaling")


func test_voice_cap_drops_the_thirty_third_voice() -> void:
	var bank: AudioBank = _attached()
	for i: int in range(AudioBank.POLYPHONY):
		assert_ne(bank._play("dot_pop_00"), AudioStreamPlaybackPolyphonic.INVALID_ID)
	assert_eq(
		bank._play("dot_pop_01"), AudioStreamPlaybackPolyphonic.INVALID_ID, "M5 R2: dropped"
	)


func test_missing_files_log_and_play_silence() -> void:
	var bank: AudioBank = _attached("res://tests/fixtures/no_such_sfx/")
	assert_true(bank._streams.is_empty(), "nothing loaded")
	assert_eq(bank._play("nuke"), AudioStreamPlaybackPolyphonic.INVALID_ID)
	bank.play_nuke()
	bank.play_dot_pop(3)
	assert_not_null(bank._player, "the player still exists; only the files are missing")
```

Append to `godot/tests/test_main_scene.gd` (same instantiate pattern as its `test_pause_overlay_marks_the_active_scheme_on_open`, `:76-79`):

```gdscript
func test_game_root_attaches_the_audio_bank() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var bank: AudioBank = root._audio
	assert_not_null(bank._playback, "GameRoot._ready attaches the bank (M5 R10)")
	assert_eq(bank._streams.size(), AudioBank.SFX_STEMS.size(), "every baked file loaded")
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `tools/run_tests.sh`
Expected: FAIL. `test_audio_bank.gd` and `spy_audio_bank.gd` cannot parse (`attach`, `SFX_STEMS`, `_play`, `POLYPHONY`, `music_gain` are undeclared), so the runner reports `collected 48 of 49` or a parse error. That is the failing state.

- [ ] **Step 4: Rewrite `AudioBank`**

Replace `godot/src/audio/audio_bank.gd` entirely:

```gdscript
# gdlint:ignore=max-public-methods
## audio_bank.gd
## PORTS: web/src/tilt-to-live/TiltAudio.ts (887 lines, source commit 7be9614)
# PORT-NOTE: TiltAudio.ts has 28 public audio methods. Law 3 requires faithfully
# porting all public methods, which exceeds gdlint's default max-public-methods (20).
class_name AudioBank
extends RefCounted
## Sound effects played from the files tools/bake-audio/bake_sfx.mjs renders out
## of TiltAudio.ts (spec D5, §8 M5). The music half is M6.
##
## Instantiated by GameRoot, which attaches it to the scene tree; the sim systems
## receive it as a parameter, as the TS passes its TiltAudio. An unattached bank
## (every sim spec) plays nothing. Never an autoload (spec §5.2).
##
## PORT-NOTE: each file is its play* method rendered through the TS gain graph,
## so it already carries sfxGain 1.0 and masterGain 0.28 (TiltAudio.ts:35, :39).
## Playback applies only what the TS changes at run time: the sfx gain and the
## master mute (M5 R4).

## Where the bake writes (spec §4.2; WAV per M5 R1).
const SFX_DIR: String = "res://assets/audio/sfx/"
## One dot_pop file per pentatonic note. PORT: web/src/tilt-to-live/TiltAudio.ts:23-27
const DOT_POP_NOTES: int = 15
## One file per march note. PORT: web/src/tilt-to-live/TiltAudio.ts:829
const INVADER_STEPS: int = 4
## playLightning's start frequency is 1200 + random() * 400.
const LIGHTNING_BASE_HZ: float = 1200.0  # PORT: web/src/tilt-to-live/TiltAudio.ts:617
const LIGHTNING_SPREAD_HZ: float = 400.0  # PORT: web/src/tilt-to-live/TiltAudio.ts:617
## The bake pins random() to 0.5, so lightning.wav starts at 1400 Hz (M5 R6).
const LIGHTNING_BAKED_HZ: float = LIGHTNING_BASE_HZ + 0.5 * LIGHTNING_SPREAD_HZ  # M5 R6
## The music bus gain at full volume. PORT: web/src/tilt-to-live/TiltAudio.ts:43, :74
const MUSIC_GAIN: float = 0.35
## Simultaneous SFX voices; a voice past the cap is dropped.
const POLYPHONY: int = 32  # DIVERGENCE(M5 R2): Web Audio overlaps without limit
## Every baked file, in bake order (tools/bake-audio/bake_sfx.mjs).
const SFX_STEMS: Array[String] = [
	"orb_pickup",
	"coin_pickup",
	"nuke",
	"missile_launch",
	"missile_explode",
	"laser_beam",
	"lightning",
	"freeze",
	"ice_shatter",
	"siren",
	"ice_cascade",
	"gauntlet_klaxon",
	"vortex",
	"dot_pop_00",
	"dot_pop_01",
	"dot_pop_02",
	"dot_pop_03",
	"dot_pop_04",
	"dot_pop_05",
	"dot_pop_06",
	"dot_pop_07",
	"dot_pop_08",
	"dot_pop_09",
	"dot_pop_10",
	"dot_pop_11",
	"dot_pop_12",
	"dot_pop_13",
	"dot_pop_14",
	"milestone",
	"player_death",
	"close_call",
	"space_invader_step_0",
	"space_invader_step_1",
	"space_invader_step_2",
	"space_invader_step_3",
	"warp_in",
	"invasion_alarm",
]

## The music gain M6's sequencer plays at. PORT: web/src/tilt-to-live/TiltAudio.ts:43
var music_gain: float = MUSIC_GAIN

var _muted: bool = false
var _sfx_volume: float = 1.0  # PORT: web/src/tilt-to-live/TiltAudio.ts:39
var _streams: Dictionary[String, AudioStream] = {}
var _player: AudioStreamPlayer = null
var _playback: AudioStreamPlaybackPolyphonic = null


## Hangs the SFX player on `host` and loads every baked file. A missing file
## logs a warning and plays silence (spec §6.4). `host` must be in the tree.
## PORT-NOTE: stands in for unlock()'s context and gain creation
## (TiltAudio.ts:30-45); Godot needs a node in the tree, not a user gesture (M5 R10).
func attach(host: Node, sfx_dir: String = SFX_DIR) -> void:
	for stem: String in SFX_STEMS:
		var path: String = sfx_dir + stem + ".wav"
		if ResourceLoader.exists(path):
			_streams[stem] = load(path) as AudioStream
		else:
			Log.warn("AudioBank: missing baked sfx %s; it plays silence" % path)
	var polyphonic: AudioStreamPolyphonic = AudioStreamPolyphonic.new()
	polyphonic.polyphony = POLYPHONY
	_player = AudioStreamPlayer.new()
	_player.stream = polyphonic
	host.add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	_apply_volume()


## Unlocks the audio context. PORT: web/src/tilt-to-live/TiltAudio.ts:29-49
# PORT-NOTE: attach() builds what unlock() creates; Godot has no suspended
# context to resume (:46-48), so the call site is kept and the body is empty.
func unlock() -> void:
	pass


## Toggles mute state. PORT: web/src/tilt-to-live/TiltAudio.ts:51-57
func toggle_mute() -> bool:
	_muted = not _muted
	_apply_volume()
	return not _muted


## Sets the muted state. PORT: web/src/tilt-to-live/TiltAudio.ts:59-64
func set_muted(muted: bool) -> void:
	_muted = muted
	_apply_volume()


## Sets sound effects volume. PORT: web/src/tilt-to-live/TiltAudio.ts:66-70
func set_sfx_volume(vol: float) -> void:
	_sfx_volume = clampf(vol, 0.0, 1.0)
	_apply_volume()


## Sets background music volume. PORT: web/src/tilt-to-live/TiltAudio.ts:72-76
func set_music_volume(vol: float) -> void:
	music_gain = clampf(vol, 0.0, 1.0) * MUSIC_GAIN


## Reports whether audio is muted. PORT: web/src/tilt-to-live/TiltAudio.ts:78-80
func is_muted() -> bool:
	return _muted


## Starts the background music sequencer. PORT: web/src/tilt-to-live/TiltAudio.ts:84-95
func start_music() -> void:
	# TODO(M6): port startMusic's lookahead scheduler (TiltAudio.ts:84-95).
	Log.debug("AudioBank.start_music()")


## Stops the background music sequencer. PORT: web/src/tilt-to-live/TiltAudio.ts:97-103
func stop_music() -> void:
	# TODO(M6): port stopMusic (TiltAudio.ts:97-103).
	Log.debug("AudioBank.stop_music()")


## Plays the orb pickup sound. PORT: web/src/tilt-to-live/TiltAudio.ts:483-500
func play_orb_pickup() -> void:
	_play("orb_pickup")


## Plays the coin pickup sound. PORT: web/src/tilt-to-live/TiltAudio.ts:505-531
func play_coin_pickup() -> void:
	_play("coin_pickup")


## Plays the nuke detonation sound. PORT: web/src/tilt-to-live/TiltAudio.ts:533-551
func play_nuke() -> void:
	_play("nuke")


## Plays the missile launch sound. PORT: web/src/tilt-to-live/TiltAudio.ts:553-570
func play_missile_launch() -> void:
	_play("missile_launch")


## Plays the missile explosion sound. PORT: web/src/tilt-to-live/TiltAudio.ts:572-589
func play_missile_explode() -> void:
	_play("missile_explode")


## Plays the laser beam sound. PORT: web/src/tilt-to-live/TiltAudio.ts:591-608
func play_laser_beam() -> void:
	_play("laser_beam")


## Plays the lightning arc sound. PORT: web/src/tilt-to-live/TiltAudio.ts:610-627
# PORT-NOTE: the TS draws a fresh start frequency per call (:617). The bake
# pins it at 1400 Hz and pitch_scale restores the spread, which also scales the
# 200 Hz end and the sweep's length: close, not identical (spec §9, M5 R6).
func play_lightning() -> void:
	var start_hz: float = LIGHTNING_BASE_HZ + randf() * LIGHTNING_SPREAD_HZ
	_play("lightning", start_hz / LIGHTNING_BAKED_HZ)


## Plays the freeze burst sound. PORT: web/src/tilt-to-live/TiltAudio.ts:629-646
func play_freeze() -> void:
	_play("freeze")


## Plays the ice shatter sound. PORT: web/src/tilt-to-live/TiltAudio.ts:648-665
func play_ice_shatter() -> void:
	_play("ice_shatter")


## Plays the life-lost siren. PORT: web/src/tilt-to-live/TiltAudio.ts:667-685
func play_siren() -> void:
	_play("siren")


## Plays the ice cascade sound. PORT: web/src/tilt-to-live/TiltAudio.ts:687-707
# PORT-NOTE: no caller in web/src outside the menu's no-op audio stub
# (TiltGame.ts:1803); baked and playable, not called (M5 R8).
func play_ice_cascade() -> void:
	_play("ice_cascade")


## Plays the gauntlet warning klaxon. PORT: web/src/tilt-to-live/TiltAudio.ts:709-727
# PORT-NOTE: uncalled in web/src (M10 R11, M5 R8).
func play_gauntlet_klaxon() -> void:
	_play("gauntlet_klaxon")


## Plays the vortex singularity sound. PORT: web/src/tilt-to-live/TiltAudio.ts:729-746
func play_vortex() -> void:
	_play("vortex")


## Plays the pentatonic combo note. PORT: web/src/tilt-to-live/TiltAudio.ts:748-765
func play_dot_pop(combo_index: int = 0) -> void:
	_play("dot_pop_%02d" % (combo_index % DOT_POP_NOTES))  # PORT: :754


## Plays the combo milestone chime. PORT: web/src/tilt-to-live/TiltAudio.ts:767-785
func play_milestone() -> void:
	_play("milestone")


## Plays the player death crash sound. PORT: web/src/tilt-to-live/TiltAudio.ts:787-804
func play_player_death() -> void:
	_play("player_death")


## Plays the close call near-miss sound. PORT: web/src/tilt-to-live/TiltAudio.ts:806-823
func play_close_call() -> void:
	_play("close_call")


## Plays one march step. PORT: web/src/tilt-to-live/TiltAudio.ts:826-845
# PORT-NOTE: referenced only by the menu's no-op audio stub (TiltGame.ts:1801);
# baked and playable, not called (M5 R8).
func play_space_invader_step(step: int) -> void:
	_play("space_invader_step_%d" % (step % INVADER_STEPS))  # PORT: :830


## Plays the warp-in sound. PORT: web/src/tilt-to-live/TiltAudio.ts:847-865
# PORT-NOTE: its caller is the entrance cinematic (TiltEntranceCinematic.ts:74),
# which is M11 (M5 R8).
func play_warp_in() -> void:
	_play("warp_in")


## Plays the invasion alarm. PORT: web/src/tilt-to-live/TiltAudio.ts:867-885
# PORT-NOTE: no reference in web/src (M5 R8).
func play_invasion_alarm() -> void:
	_play("invasion_alarm")


## Plays one baked file. Returns its voice id, or INVALID_ID when the bank is
## unattached or muted, the file is missing, or every voice is busy (M5 R2).
## PORT: web/src/tilt-to-live/TiltAudio.ts:484 (the guard every play* opens with)
func _play(stem: String, pitch_scale: float = 1.0) -> int:
	if _playback == null or _muted:
		return AudioStreamPlaybackPolyphonic.INVALID_ID
	if not _streams.has(stem):
		return AudioStreamPlaybackPolyphonic.INVALID_ID
	var stream: AudioStream = _streams[stem]
	return _playback.play_stream(stream, 0.0, 0.0, pitch_scale)


## masterGain is 0 while muted (TiltAudio.ts:54, :62); otherwise the sfx gain.
func _apply_volume() -> void:
	if _player != null:
		_player.volume_linear = 0.0 if _muted else _sfx_volume
```

In `godot/src/core/game_root.gd`, directly after `_audio = AudioBank.new()` (line 94):

```gdscript
	_audio.attach(self)  # M5 R10: stands in for unlock()'s context creation
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tools/run_tests.sh`
Expected: `OK: 49/49 scripts collected, all tests passed`, Tests **533** (520 − 1 old + 13 new + 1 main-scene).
`test_missing_files_log_and_play_silence` logs 37 warnings through `Log.warn` (→ `push_warning`). GUT's `failure_error_types` default is `["engine", "gut", "push_error"]` (`addons/gut/gut_config.gd:57`), so warnings do not fail a test, the same as the corrupt-save specs that already warn through `SaveStore`.

- [ ] **Step 6: Format, lint, count**

```bash
gdformat godot/tests/spy_audio_bank.gd
gdformat --check godot/src godot/tests    # expect: 89 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "DIVERGENCE" godot/src/ | wc -l  # expect: 178
grep -rn "TODO(M5)" godot/src/audio/      # expect: nothing
```

- [ ] **Step 7: Commit**

Tick this task's boxes and set `## State` to "M5 in progress: Tasks 1–2 landed; next Task 3 (lifecycle wiring)".

```bash
git checkout godot/project.godot
git add godot/src/audio/audio_bank.gd godot/tests/spy_audio_bank.gd godot/tests/test_audio_bank.gd godot/src/core/game_root.gd godot/tests/test_main_scene.gd docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md godot/HANDOFF.md
git commit -m "M5: play baked sfx through a 32-voice bank; next: M5 Task 3"
git log -1 --format=%B
```

---

### Task 3: Lifecycle wiring — unlock, stopMusic, startMusic, sound options

**Files:**
- Modify: `godot/src/core/game_state_machine.gd` (constructor `:31-42`; `TODO(M5)` at `:66`, `:78`, `:110`, `:151`, `:163`, `:168`)
- Modify: `godot/src/sim/run_controller.gd:116` (after `grid.resize`)
- Modify: `godot/src/core/game_root.gd:115` (constructor call), `:355` (`open_armory`)
- Test: `godot/tests/test_game_state_machine.gd` (constructor + 5 tests), `godot/tests/test_run_controller.gd` (+1 test)

**Interfaces:**
- Consumes: `SpyAudioBank.lifecycle` (Task 2); `AudioBank.is_muted()`, `._sfx_volume`, `.music_gain` (Task 2); `GameOptionsManager.settings.sfx_enabled / sfx_volume / music_enabled / music_volume` (`game_options.gd:195-200`).
- Produces: `GameStateMachine._init(player, grid, particles, router, tilt, audio: AudioBank, options: GameOptionsManager)`.

- [ ] **Step 1: Write the failing tests**

In `godot/tests/test_game_state_machine.gd`, add two members and change `before_each`'s construction:

```gdscript
var _audio: SpyAudioBank = null
var _options: GameOptionsManager = null
```

```gdscript
	_audio = SpyAudioBank.new()
	_options = GameOptionsManager.new()
	_machine = GameStateMachine.new(_player, _grid, _particles, _router, _tilt, _audio, _options)
```

`GameOptionsManager.new()` only reads the save, so these tests never write `user://`. Append:

```gdscript
func test_launch_run_unlocks_audio() -> void:
	_machine.start()
	_machine.launch_run(Types.GameMode.CLASSIC)
	assert_eq(_audio.lifecycle, ["unlock"] as Array[String], "TiltGame.ts:1492")


func test_return_to_menu_stops_the_music() -> void:
	_machine.start()
	_machine.launch_run(Types.GameMode.CLASSIC)
	_machine.return_to_menu()
	assert_eq(_audio.lifecycle.back(), "stop_music", "TiltGame.ts:1501")


func test_stop_stops_the_music() -> void:
	_machine.stop()
	assert_eq(_audio.lifecycle, ["stop_music"] as Array[String], "TiltGame.ts:1536")


func test_pausing_stops_the_music_and_resuming_restarts_it() -> void:
	_options.settings.music_enabled = true
	_machine.start()
	_machine.launch_run(Types.GameMode.CLASSIC)
	_audio.lifecycle.clear()
	_machine.toggle_pause()
	_machine.toggle_pause()
	assert_eq(
		_audio.lifecycle, ["stop_music", "start_music"] as Array[String], "TiltGame.ts:1622, :1638-1640"
	)


func test_resuming_with_music_off_leaves_it_off() -> void:
	_options.settings.music_enabled = false
	_machine.start()
	_machine.launch_run(Types.GameMode.CLASSIC)
	_audio.lifecycle.clear()
	_machine.toggle_pause()
	_machine.toggle_pause()
	assert_eq(_audio.lifecycle, ["stop_music"] as Array[String], "the musicEnabled guard (:1638)")
```

In `godot/tests/test_run_controller.gd`, append:

```gdscript
func test_reset_run_applies_the_sound_options() -> void:
	_options.settings.sfx_enabled = false
	_options.settings.sfx_volume = 0.4
	_options.settings.music_volume = 0.5
	_rc.reset_run(_bounds)
	assert_true(_audio.is_muted(), "setMuted(!sfxEnabled) (TiltGame.ts:1608)")
	assert_almost_eq(_audio._sfx_volume, 0.4, 0.0001, "setSfxVolume (:1609)")
	assert_almost_eq(_audio.music_gain, 0.175, 0.0001, "setMusicVolume: 0.5 * 0.35 (:1610)")
	_options.settings.sfx_enabled = true
	_rc.reset_run(_bounds)
	assert_false(_audio.is_muted(), "Retry re-applies the switch (M5 R11)")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh`
Expected: FAIL. `test_game_state_machine.gd` does not collect (the constructor takes 5 arguments, not 7), and `test_reset_run_applies_the_sound_options` fails its first assertion.

- [ ] **Step 3: Wire `GameStateMachine`**

In `godot/src/core/game_state_machine.gd`, add after `var _tilt: TiltInput = null`:

```gdscript
var _audio: AudioBank = null
var _options: GameOptionsManager = null
```

Extend `_init`:

```gdscript
func _init(
	player: PlayerShip,
	grid: VectorGrid,
	particles: ParticleEngine,
	router: InputRouter,
	tilt: TiltInput,
	audio: AudioBank,
	options: GameOptionsManager
) -> void:
	_player = player
	_grid = grid
	_particles = particles
	_router = router
	_tilt = tilt
	_audio = audio
	_options = options
```

Replace each `TODO(M5)` line:

| Site | Replacement |
|---|---|
| `launch_run`, `# TODO(M5): audio.unlock().` | `_audio.unlock()  # PORT: web/src/tilt-to-live/TiltGame.ts:1492` |
| `return_to_menu`, `# TODO(M5): audio.stopMusic().` | `_audio.stop_music()  # PORT: web/src/tilt-to-live/TiltGame.ts:1501` |
| `stop`, `# TODO(M5): audio.stopMusic().` | `_audio.stop_music()  # PORT: web/src/tilt-to-live/TiltGame.ts:1536` |
| `reset_run`, `# TODO(M5): audio.setMuted/setSfxVolume/setMusicVolume.` | `# PORT-NOTE: setMuted/setSfxVolume/setMusicVolume (:1607-1610) are ported in`<br>`# run_controller.gd::reset_run, which Retry and Restart run also reach (M5 R11).` |
| `toggle_pause` → PLAYING branch, `# TODO(M5): audio.stopMusic().` | `_audio.stop_music()  # PORT: web/src/tilt-to-live/TiltGame.ts:1622` |
| `toggle_pause` → PAUSED branch, `# TODO(M5): audio.startMusic() when music is enabled.` | `# PORT: web/src/tilt-to-live/TiltGame.ts:1638-1640`<br>`if _options.settings.music_enabled:`<br>`	_audio.start_music()` |

Keep each `TODO(M11)` line where it is. The PAUSED branch reads, in order: `phase = PLAYING`, the `TODO(M11): hide the pause modal.` line, then the music guard (the TS order, `:1636-1640`).

- [ ] **Step 4: Wire `GameRoot` and `RunController`**

`godot/src/core/game_root.gd:115`:

```gdscript
	_state = GameStateMachine.new(_player, _grid, _particles, _router, _tilt, _audio, options)
```

`godot/src/core/game_root.gd:355`, in `open_armory`, replace `# TODO(M5): audio.stopMusic() (:2347).` with:

```gdscript
		_audio.stop_music()  # PORT: web/src/tilt-to-live/TiltGame.ts:2347
```

`godot/src/sim/run_controller.gd`, directly after `grid.resize(bounds.x, bounds.y)` (line 116):

```gdscript
	# PORT: web/src/tilt-to-live/TiltGame.ts:1607-1610 (M5 R11)
	audio.set_muted(not options.settings.sfx_enabled)
	audio.set_sfx_volume(options.settings.sfx_volume)
	audio.set_music_volume(options.settings.music_volume)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tools/run_tests.sh`
Expected: `OK: 49/49 scripts collected, all tests passed`, Tests **539**.

- [ ] **Step 6: Format, lint, grep**

```bash
gdformat --check godot/src godot/tests    # expect: 89 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "TODO(M5)" godot/src/ godot/tests/   # expect: nothing
```

- [ ] **Step 7: Commit**

Tick this task's boxes and set `## State` to "M5 in progress: Tasks 1–3 landed; next Task 4 (call-site proofs)".

```bash
git checkout godot/project.godot
git add godot/src/core/game_state_machine.gd godot/src/sim/run_controller.gd godot/src/core/game_root.gd godot/tests/test_game_state_machine.gd godot/tests/test_run_controller.gd docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md godot/HANDOFF.md
git commit -m "M5: wire audio unlock, music stops and sound options; next: M5 Task 4"
git log -1 --format=%B
```

---

### Task 4: Prove every live SFX fires at its TS moment

**Files:**
- Create: `godot/tests/test_audio_call_sites.gd` (10 tests)

This task changes no production code. If a test fails, the M2–M4 call site is wrong: compare it with the cited TS line and fix it in its own file, with a `# PORT:` citation. If the TS and the port disagree in a way this plan did not foresee, stop and report it.

**Interfaces:**
- Consumes: `SpyAudioBank` (Task 2); `ScoreManager.register_kill(x, y, weapon_type, audio)`, `.register_close_call(x, y, audio)` (`score_manager.gd:100`, `:149`); `CoinSystem.update(dt, player, bounds, particles, audio, mode_multiplier, on_collected)` (`coin_system.gd:60`); `WeaponSystem.spawn_orb(bounds, type, x, y)`, `.update(dt, player, enemies, bounds, particles, grid, audio, on_killed)`, `.trigger_weapon(type, x, y, player, enemies, particles, grid, audio)` (`weapon_system.gd:437`); `RunController` built as in `test_run_controller.gd:34-60`, plus `.check_collisions()`, `.lives`, `.max_lives`; `EnemySwarm.spawn_seeker(bounds, x, y)`; `Types.Enemy.frozen`.

- [ ] **Step 1: Write the tests**

Create `godot/tests/test_audio_call_sites.gd`:

```gdscript
## test_audio_call_sites.gd
## PORTS: nothing — proves the M2–M4 SFX call sites fire at their TS moment (spec §8 M5 Accept)
extends GutTest
## Each live play* call (M5 R8 lists the uncalled ones), driven through the sim
## system that makes it and recorded by SpyAudioBank.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)

var _spy: SpyAudioBank = null
var _player: PlayerShip = null
var _particles: ParticleEngine = null
var _grid: VectorGrid = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _clear_saves() -> void:
	for path: String in [
		ProgressionManager.SAVE_PATH,
		GameOptionsManager.SAVE_PATH,
		GoalManager.SAVE_PATH,
		GoalManager.CUMULATIVE_SAVE_PATH,
	]:
		_remove(path)
		_remove(SaveStore.corrupt_path_for(path))


func before_each() -> void:
	_clear_saves()
	_spy = SpyAudioBank.new()
	_player = PlayerShip.new(BOUNDS.x * 0.5, BOUNDS.y * 0.5)
	_particles = ParticleEngine.new()
	_grid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))


func after_each() -> void:
	_clear_saves()


func _run_controller() -> RunController:
	var rc: RunController = RunController.new(
		_player,
		EnemySwarm.new(),
		WeaponSystem.new(),
		_particles,
		_grid,
		ScoreManager.new(),
		_spy,
		ProgressionManager.new(),
		GameOptionsManager.new(),
		CoinSystem.new()
	)
	rc.goals = GoalManager.new(rc.progression)
	rc.maze = GauntletMaze.new()
	rc.reset_run(BOUNDS)
	_spy.requested.clear()
	_spy.lifecycle.clear()
	return rc


func test_kills_pop_the_next_combo_note() -> void:
	var scores: ScoreManager = ScoreManager.new()
	for i: int in range(3):
		scores.register_kill(0.0, 0.0, Types.WeaponType.NUKE, _spy)
	var expected: Array[String] = ["dot_pop_01", "dot_pop_02", "dot_pop_03"]
	assert_eq(_spy.requested, expected, "playDotPop(comboCount) (ScoreManager.ts:115)")


func test_combo_milestones_chime_at_10_16_25_and_40() -> void:
	var scores: ScoreManager = ScoreManager.new()
	var chimes_at: Array[int] = []
	for combo: int in range(1, 41):
		scores.register_kill(0.0, 0.0, Types.WeaponType.NUKE, _spy)
		if _spy.requested.back() == "milestone":
			chimes_at.append(combo)
	assert_eq(chimes_at, [10, 16, 25, 40] as Array[int], "ScoreManager.ts:121-131")


func test_close_call_chimes() -> void:
	ScoreManager.new().register_close_call(0.0, 0.0, _spy)
	assert_eq(_spy.requested, ["close_call"] as Array[String], "ScoreManager.ts:136")


func test_coin_pickup_chimes() -> void:
	var coins: CoinSystem = CoinSystem.new()
	var on_collected: Callable = func(value: int) -> int: return value
	var t: float = 0.0
	while coins.coins.is_empty() and t < 10.0:
		coins.update(0.05, _player, BOUNDS, _particles, _spy, 1.0, on_collected)
		t += 0.05
	assert_false(coins.coins.is_empty(), "a coin spawned")
	_player.x = coins.coins[0].x
	_player.y = coins.coins[0].y
	coins.update(0.01, _player, BOUNDS, _particles, _spy, 1.0, on_collected)
	assert_eq(_spy.requested, ["coin_pickup"] as Array[String], "CoinSystem.ts:90")


func test_orb_pickup_fires_the_weapon_then_the_chime() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	ws.spawn_orb(BOUNDS, Types.WeaponType.NUKE, _player.x, _player.y)
	var enemies: Array[Types.Enemy] = []
	ws.update(
		0.016,
		_player,
		enemies,
		BOUNDS,
		_particles,
		_grid,
		_spy,
		func(_e: Types.Enemy, _w: Types.WeaponType) -> void: pass
	)
	assert_eq(
		_spy.requested,
		["nuke", "orb_pickup"] as Array[String],
		"activateWeapon then playOrbPickup (WeaponSystem.ts:93-95)"
	)


func test_each_weapon_fires_its_sound() -> void:
	var cases: Dictionary[Types.WeaponType, String] = {
		Types.WeaponType.NUKE: "nuke",  # WeaponSystem.ts:400
		Types.WeaponType.MISSILES: "missile_launch",  # :417
		Types.WeaponType.LIGHTNING: "lightning",  # :438
		Types.WeaponType.LASER: "laser_beam",  # :500
		Types.WeaponType.VORTEX: "vortex",  # :518
		Types.WeaponType.FREEZE: "freeze",  # :539
	}
	for type: Types.WeaponType in cases:
		_spy.requested.clear()
		var enemies: Array[Types.Enemy] = []
		WeaponSystem.new().trigger_weapon(
			type, _player.x, _player.y, _player, enemies, _particles, _grid, _spy
		)
		assert_eq(_spy.requested.front(), cases[type], "weapon %d" % type)
	_spy.requested.clear()
	var none: Array[Types.Enemy] = []
	WeaponSystem.new().trigger_weapon(
		Types.WeaponType.SHIELD, _player.x, _player.y, _player, none, _particles, _grid, _spy
	)
	assert_true(_spy.requested.is_empty(), "the shield is silent (WeaponSystem.ts:541-556)")


func test_missiles_explode_when_their_fuel_runs_out() -> void:
	var ws: WeaponSystem = WeaponSystem.new()
	var enemies: Array[Types.Enemy] = []
	ws.trigger_weapon(
		Types.WeaponType.MISSILES, _player.x, _player.y, _player, enemies, _particles, _grid, _spy
	)
	for i: int in range(250):
		ws.update(
			0.016,
			_player,
			enemies,
			BOUNDS,
			_particles,
			_grid,
			_spy,
			func(_e: Types.Enemy, _w: Types.WeaponType) -> void: pass
		)
	assert_true(_spy.requested.has("missile_explode"), "lifetime 3.5 s → blast (WeaponSystem.ts:341)")


func test_ramming_a_frozen_enemy_shatters_it() -> void:
	var rc: RunController = _run_controller()
	var e: Types.Enemy = rc.swarm.spawn_seeker(BOUNDS, _player.x, _player.y)
	e.frozen = true
	rc.check_collisions()
	assert_eq(
		_spy.requested,
		["ice_shatter", "dot_pop_01"] as Array[String],
		"playIceShatter then registerKill (TiltGame.ts:2025-2026)"
	)


func test_losing_a_life_sounds_the_siren() -> void:
	var rc: RunController = _run_controller()
	rc.lives = 2
	rc.max_lives = 2
	rc.swarm.spawn_seeker(BOUNDS, _player.x, _player.y)
	rc.check_collisions()
	assert_eq(_spy.requested, ["siren"] as Array[String], "TiltGame.ts:2061")
	assert_true(_spy.lifecycle.is_empty(), "the music keeps playing")


func test_death_plays_the_crash_and_stops_the_music() -> void:
	var rc: RunController = _run_controller()
	rc.swarm.spawn_seeker(BOUNDS, _player.x, _player.y)
	rc.check_collisions()
	assert_eq(_spy.requested, ["player_death"] as Array[String], "TiltGame.ts:2075")
	assert_eq(_spy.lifecycle, ["stop_music"] as Array[String], "TiltGame.ts:2076")
```

Before running, check four facts and adapt only the test code, never the production code. (1) `RunController.swarm` and `.progression` are public (`run_controller.gd:9`, `:23`; verified at plan time). (2) `WeaponSystem.trigger_weapon`'s parameter order matches `weapon_system.gd:437-448`. (3) A missile's lifetime in the port is 3.5 s (`WeaponSystem.ts:431`), so 250 × 0.016 s = 4 s covers it. (4) `rc.reset_run` spawns the starting weapon orb near the ship (`spawn_starting_weapon_orb`). If that orb overlaps the ship and `check_collisions` does not touch orbs, the tests are unaffected. If a test records an extra `orb_pickup`, move `_player` off the orb before spawning the seeker.

- [ ] **Step 2: Run the tests**

Run: `tools/run_tests.sh`
Expected: `OK: 50/50 scripts collected, all tests passed`, Tests **549**. Each of these tests passes against the M2–M4 code as it stands. A failure means that code disagrees with its TS citation (see the note under **Files**).

- [ ] **Step 3: Format, lint**

```bash
gdformat godot/tests/test_audio_call_sites.gd
gdformat --check godot/src godot/tests    # expect: 90 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
```

- [ ] **Step 4: Commit**

Tick this task's boxes and set `## State` to "M5 in progress: Tasks 1–4 landed; next Task 5 (device checks)".

```bash
git checkout godot/project.godot
git add godot/tests/test_audio_call_sites.gd docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md godot/HANDOFF.md
git commit -m "M5: prove each live sfx fires at its TS moment; next: M5 Task 5"
git log -1 --format=%B
```

---

### Task 5: Device evidence and hand-held checks

**Files:**
- Modify — append: `godot/VERIFY-ME.md` (`## M5 — Audio bake and SFX`). **Never recreate this file.**

- [ ] **Step 1: Check the phone**

Run: `"$ADB" devices`
If `RRCXB04L8EJ` is listed, export and install the debug APK the way earlier modules did (`godot/HANDOFF.md` "How to verify right now" and the M8.5/M9 device sections). Record the APK size delta, which should be small: 37 short QOA files. Then walk the checks in Step 2 with the user and tick the ones they confirm. If the phone is absent, write the section unticked and record "A55 absent from `adb` on <date>".

- [ ] **Step 2: Append the checklist**

Append to `godot/VERIFY-ME.md`:

```markdown
## M5 — Audio bake and SFX

Code-complete <date> (head `<sha>`). Sound on (Pause → Sound). Music is M6 —
silence between effects is expected.

- [ ] **Weapons.** Each orb pickup plays its weapon's sound, then the pickup
      chime: nuke boom, missile launch (and a pop per missile blast), laser
      zap, lightning crackle (pitch varies call to call), freeze chime,
      vortex drop. Shield is silent (as in the TS).
- [ ] **Kills.** Each kill pops a note that climbs the pentatonic scale with
      the combo and wraps after 15; combos 10, 16 and 25 add a chord chime.
- [ ] **Pickups and misses.** Coins play a quiet two-note chime; a near miss
      chirps; ramming a frozen enemy crackles like ice.
- [ ] **Lives.** Losing a life (2+ lives, Armory boost) sounds the siren;
      the last life plays the long death crash.
- [ ] **Nuke storm.** A nuke through a dense swarm pops many notes at once
      without distortion that sounds broken, and the frame rate holds. Past
      32 simultaneous voices the extras are dropped (M5 R2) — judge whether
      that is audible.
- [ ] **Sound switch.** Pause → Sound off silences everything at once,
      including a tail still playing; on again restores the same loudness;
      the choice survives Retry and an app relaunch.
- [ ] **Sync and level.** Sounds land on their events with no noticeable
      lag, and their loudness roughly matches the web build on the same phone.
```

Fill in `<date>` and `<sha>` (the head after Task 4).

- [ ] **Step 3: Commit**

Tick the boxes and set `## State` to "M5 in progress: Tasks 1–5 landed; next Task 6 (exit protocol)".

```bash
git add godot/VERIFY-ME.md docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md godot/HANDOFF.md
git commit -m "M5: record the sfx device checks; next: M5 Task 6 exit"
git log -1 --format=%B
```

---

### Task 6: Module exit protocol (CONVENTIONS §9)

**Files:**
- Modify: `godot/PORT-PROGRESS.md` (the M5 box and its `.ogg` acceptance line, R1), `godot/HANDOFF.md` (rewrite `## State`, add `## M5 — what landed`, rewrite `## Next`), `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md` (row 5: plan filename and status)

- [ ] **Step 1: Verify, fresh, and read every output**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
node tools/bake-audio/bake_sfx.mjs | tail -1   # expect: OK: 37 files in …
git status --short godot/assets/audio/sfx/     # expect: empty (the bake is deterministic)
tools/run_tests.sh                        # expect: OK: 50/50 scripts (549 tests)
gdformat --check godot/src godot/tests    # expect: 90 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "TODO(M5)" godot/src/ godot/tests/   # expect: nothing
grep -rniE "ff4757" godot/src/ui/         # expect: nothing (rule 01)
grep -rn "DIVERGENCE" godot/src/ | wc -l  # expect: 178
grep -rn "DIVERGENCE(M5 R2)" godot/src/ | wc -l   # expect: 1
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR"   # expect: 0
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "missing baked sfx"   # expect: 0
git checkout godot/project.godot
git status --short                        # expect: empty
```

If any command differs from its expectation, the module is not done: fix it or stop and report.

- [ ] **Step 2: Tick `PORT-PROGRESS.md`**

Replace the M5 entry with:

```markdown
- [x] **M5 — Audio bake and SFX**  deps: M2  done <date>  <sha>  DEVICE PASS PENDING
      ok  every `play*` method in TiltAudio.ts has a baked .wav (M5 R1: WAV,
          not .ogg) — 37 files from tools/bake-audio/bake_sfx.mjs.
      ok  each live SFX fires at its TS moment (test_audio_call_sites.gd);
          a missing file logs and plays silence (test_audio_bank.gd).
      ok  50/50 GUT scripts (549 tests); gdformat/gdlint clean; `TODO(M5)`
          grep empty; headless 0 SCRIPT ERROR.
      --  device pass pending — `VERIFY-ME.md` §M5.
```

Change the M6 entry's stem wording only if it names `.ogg` (it does not at the time of writing).

- [ ] **Step 3: Rewrite `HANDOFF.md`**

Rewrite it for a session with zero context:
- `## State`: M5 is code-complete with the device pass pending; give the final commit SHA.
- `## How to verify right now`: the commands above with their fresh outputs (update the expected totals: 50 scripts, 549 tests, 90 files, DIVERGENCE 178).
- A new `## M5 — what landed` section: a file-by-file table and rulings R1–R11, one line each.
- `## Open questions`: add any stop raised during execution.
- `## Next`: **M6 — Generative music** (deps M5). Its literal first step is "read `web/src/tilt-to-live/TiltAudio.ts:12-20` and `:82-479` in full, then spec §8 Module 6, then write `docs/superpowers/plans/2026-09-20-m6-generative-music.md`". Carry these forward into the Next section:
  - M6 fills `AudioBank.start_music`/`stop_music` (`TODO(M6)`), reads `AudioBank.music_gain`, and must honour `_muted` (the TS master mute silences music too, `:54`, `:106`).
  - The music drums use a noise buffer (`:114-124`, `Math.random`), so an M6 bake is not deterministic unless it pins `Math.random`. Decide this at plan time.
  - The TS starts music when the cinematic ends (`TiltGame.ts:169-172`). The cinematic is M11, so M6 must choose where a run's music starts until then.
  - M11 must call `play_warp_in` from the cinematic (`TiltEntranceCinematic.ts:74`, M5 R8).
  - `tools/bake-audio/bake_sfx.mjs` is the pattern for any music-stem bake.

Copy every execution ruling from the SDD ledger (if one was kept) into this plan under a new `## Execution rulings` section. The ledger is git-ignored (M9 lesson).

In the index plan, set row 5 to `| 5 | Audio bake + SFX | M2 | \`2026-09-20-m5-audio-bake-and-sfx.md\` | **code complete** — device pass pending (\`godot/VERIFY-ME.md\`) |`.

- [ ] **Step 4: Commit**

```bash
git add godot/PORT-PROGRESS.md godot/HANDOFF.md docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md
git commit -m "M5 done: next read godot/HANDOFF.md + VERIFY-ME.md, then plan M6"
git log -1 --format=%B
```

- [ ] **Step 5: Stop.** Report to the user and do not begin M6 (CONVENTIONS §9 step 5).
