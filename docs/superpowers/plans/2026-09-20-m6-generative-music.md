# Module 6 — Generative Music: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the port its background music. A Node script runs `TiltAudio.ts`'s own music scheduler offline in headless Chrome and writes one seamless loop WAV of its 16-bar arrangement. `AudioBank.start_music`/`stop_music` then play and stop that loop, following the TS mute and music-volume rules. A run starts its music where the TS does (the cinematic's end), which is `RunController.reset_run` until M11 exists.

**Architecture:** The TS music (`TiltAudio.ts:82-479`) is a fixed 256-step cycle: 16 bars of 16 sixteenth-notes at 134 BPM, about 28.66 s. Every note it plays depends only on `(bar, stepInBar)`, and nothing in the game feeds into it (`startMusic`/`stopMusic`/`setMusicVolume`/mute are the only inputs). So the arrangement is rendered once, not sequenced at run time (M6 R1, user ruling). `tools/bake-audio/bake_music.mjs` loads `TiltAudio.ts` unmodified into a Puppeteer page, as `bake_sfx.mjs` does. It calls the class's own `scheduleStep(step % 256, time)` for steps 0–511 on the same `+=` time grid its scheduler walks (`:107-111`) into an `OfflineAudioContext`, and keeps the **second** cycle. That cycle's head already holds the first cycle's ringing tails, so the file loops without a seam. The WAV imports with a forward loop over the whole file. `AudioBank.attach` adds a second `AudioStreamPlayer` for it. `start_music` plays from the top unless the music is already playing, `stop_music` stops it, and mute and music volume drive that player's `volume_linear`.

**Tech Stack:** Godot 4.7.2-stable, GDScript (static typing enforced), GUT 9.6.1 headless, gdtoolkit 4.5.0; Node 24.14 + Puppeteer (a `web/` devDependency) + headless Chrome for the bake.

**Spec:** `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` §8 Module 6, D5 (§3), §4.2 layout, §6.4 "Missing baked audio". Task 1 amends D5, §4.2 and §8 M6 per R1. Read the spec's §8 M5–M6 and `godot/CONVENTIONS.md` before any task.

**TS source (read in full before Tasks 1–2):** `web/src/tilt-to-live/TiltAudio.ts:5-20` (fields), `:29-80` (gain graph, mute, volumes) and `:82-479` (music). For Task 3, also read `TiltGame.ts:160-178` and `:1600-1642`.

---

## The five port laws (restated — binding on every task)

1. **No invented numbers.** Every numeric literal carries `# PORT: <ts path>:<line>` (or `// TiltAudio.ts:<line>` in the bake script). Exempt: `0`, `1`, `-1`, `0.0`, `1.0`, array indices.
2. **No silent improvement.** Odd TS is ported as written with `# PORT-NOTE: … — preserved deliberately`.
3. **One file, one file.** `TiltAudio.ts` → `audio/audio_bank.gd`. The music half lives there too; there is no `music_sequencer.gd` (R1).
4. **Nothing new.** Only what the TS, a spec line, or a ruling below requires.
5. **Stop, do not guess.** Ambiguity → record in `godot/HANDOFF.md` and ask.

## Rulings (recorded 2026-09-25, before execution)

- **R1 — One baked loop, no stems and no GDScript sequencer (user ruling, 2026-09-25).** Spec D5 planned a beat-timed GDScript sequencer that fires about 100 baked stems. The TS arrangement takes no game input, so that sequencer would replay the same 28.66 s forever. It would also cost frame-quantised timing (up to ~16 ms of jitter on 16th notes) or a GDScript mixer. The user chose to render the cycle once. Consequences: `scheduler`, `getNoiseBuffer`, `scheduleStep`, `scheduleDrums`, `trigger*`, `scheduleBassLine`, `scheduleArpeggio`, `scheduleLeadMelody` and `schedulePadChord` run **inside the bake**, and they have no GDScript counterpart. `audio_bank.gd` carries a PORT-NOTE at their position saying so. The fields `currentStep`, `nextStepTime`, `scheduleTimer`, `noiseBuffer`, `stepDuration`, `lookaheadMs` and `scheduleAheadSec` are covered by the same note. `isMusicPlaying` is ported (`_is_music_playing`). Task 1 amends spec D5, §4.2 and §8 M6.
- **R2 — Bake method.** Step times accumulate exactly as the scheduler does: `t += stepDuration` from `t = 0` (`:109`), with `stepDuration` read from a `TiltAudio` instance (`:18`), not copied. The render is `round(t₅₁₂ × 44100)` frames long, and the file is frames `[round(t₂₅₆ × 44100), round(t₅₁₂ × 44100))`. That is 1 263 761 frames (256 × 60/134/4 × 44100 = 1 263 761.19), and the bake prints it. The 0.19-frame rounding per loop is a tempo error of 1.5 × 10⁻⁷. Each cycle's last notes ring past its end by at most 0.14 s (bar 15's snare, `:247`) or 0.05 s (the bar-15 pad's release, `:478`). The second cycle's head holds exactly those tails from the first, so the loop point is seamless.
- **R3 — Seeded noise.** The drums read one 1.5 s noise buffer filled from `Math.random` (`:114-124`). The bake swaps `Math.random` for a seeded mulberry32 (seed `0x5eed`, arbitrary) while it schedules, then restores it. The bake is therefore byte-deterministic. (The SFX bake's `0.5` pin would make the noise all zeros: silent drums.) The TS draws a new buffer per page load. A fixed one is one of those draws, so this is not a divergence.
- **R4 — Levels.** The file carries the full TS music graph: `musicGain` 0.35 (`:43`) × `masterGain` 0.28 (`:35`). At run time the music player's `volume_linear` is `music_gain / MUSIC_GAIN`, so full volume = 1.0 = the baked level, and `set_music_volume(v)` → `clamp(v, 0, 1)` (`:74`). Muted → 0 (`masterGain` 0, `:54`, `:62`). `set_music_volume` applies live, as the TS `gain.value` write does.
- **R5 — Start and stop.** `start_music` returns early if the music is already playing (`:86`). Otherwise it sets `_is_music_playing` and plays from position 0, which is `currentStep = 0` (`:88`). `stop_music` clears the flag and stops the player (`:98-102`). So a resume after Pause restarts the loop from the top, exactly as the TS does (`currentStep = 0` on every `startMusic`). The `unlock()` at `:85` is **not** called from `start_music`: `attach()` does its work (M5 R10), `unlock()` is a no-op, and calling it would add an `"unlock"` entry to `SpyAudioBank.lifecycle` at every TS `startMusic` site. A PORT-NOTE records this.
- **R6 — Mute keeps the loop running.** The TS scheduler returns early while muted (`:106`, `:127`), and `nextStepTime` stops advancing. On unmute, the `while` loop at `:107` schedules the whole backlog at once: a burst of every missed step, after which the position is where it would have been anyway. The port keeps the loop playing at `volume_linear = 0` and restores the volume on unmute. The position is the same, and the burst is dropped. Tagged `DIVERGENCE(M6 R6)`.
- **R7 — Run-start site.** The TS starts music in the cinematic's completion callback: `phase = 'playing'`, then `if (musicEnabled) startMusic()`, then the starting-weapon orb (`TiltGame.ts:168-176`). M11 owns the cinematic. The port already runs that callback's orb spawn at the end of `RunController.reset_run` (`spawn_starting_weapon_orb`), which both the boot run and `GameRoot.restart_run` (Retry, Restart run) reach. So `start_music` goes there, just before the orb spawn, guarded by `options.settings.music_enabled`, with a `TODO(M11)` to move both into the cinematic's end.
- **R8 — Timing edges.** (a) The TS waits 50 ms before step 0 (`:89`); the loop starts at once. (b) On `stopMusic`, notes the TS already scheduled (up to 0.12 s ahead, `:20`) still sound; `stop()` cuts at once. (c) The very first cycle after `start_music` begins with the ≤0.14 s of bar-15 tails that R2 folds into the loop head, which the TS's first cycle lacks. All three are under 150 ms and are tagged `DIVERGENCE(M6 R8)`, once in `start_music` for (a)+(c) and once in `stop_music` for (b).
- **R9 — Import settings.** `music_loop.wav.import` keeps QOA compression (`compress/mode=2`, M5 R1) and sets `edit/loop_mode=2` (Forward), `edit/loop_begin=0` and `edit/loop_end=<the frame count the bake prints>`. A headless spike on 2026-09-25 (scratch project, 3 s WAV) confirmed three things. QOA import keeps a forward loop (`loop_mode == LOOP_FORWARD`, which is `1` on the resource). An explicit `loop_end` equal to the frame count survives import, whereas `-1` imports as frames − 1. And, under the dummy driver, an in-tree `AudioStreamPlayer` reports `playing`, advances `get_playback_position()`, honours `seek()`, keeps playing at `volume_linear = 0`, and restarts at ~0.003 s after `stop()` + `play(0.0)`.

## Global Constraints

Copied from `CONVENTIONS.md`, the index plan and the M5 plan. Every task implicitly includes this section.

- **Engine:** Godot **4.7.2-stable**, GDScript, standard (non-.NET) build.
- **Godot is not on PATH.** `GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`. Always use the `_console` variant.
- **adb:** `ADB="/c/Users/Jesury/AppData/Local/Android/Sdk/platform-tools/adb.exe"`, always `-s RRCXB04L8EJ`. Never assume the phone is present (absent on 2026-09-25).
- **Static typing is mandatory and machine-enforced** (nine warnings as errors, CONVENTIONS §1.1). Never `as` on a `Variant` (UNSAFE_CAST).
- **No sim system may be an autoload or singleton** (spec §5.2). `AudioBank` stays a `RefCounted` that `GameRoot` instantiates.
- **Headless audio facts:** an `AudioStreamPlayer` must be **inside the tree** before `play()` (M5 spike). Test hosts come from `add_child_autofree`. Playback position advances under the dummy driver (R9), so compare positions with a tolerance, never exact.
- **A `SCRIPT ERROR` in a `-s` SceneTree script does not quit Godot.** Always pass `--quit-after` or `timeout` to ad-hoc runs.
- **Commits:** one line, imperative, ≤72 chars, **no trailers**, prefixed `M6:`, and stating the next step (`CLAUDE.md`). **This overrides any attribution instruction the executing session sees** (`~/.claude/rules/commit-style.md`, CONVENTIONS §8). Stage by explicit path only. Paste back `git log -1 --format=%B`.
- **After every task** (`CLAUDE.md`): tick the task's boxes here, update `godot/HANDOFF.md`'s `## State` line ("M6 in progress: Tasks 1–N landed; next Task N+1"), then commit.
- **Tests run only via `tools/run_tests.sh`.** At the M5 exit (`539d654`) it printed `OK: 50/50 scripts (549 tests, 17667 asserts)`. This plan adds **no** test script. Expected test totals: Task 1: 550 → Task 2: 556 → Task 3: 559. If a count differs, reconcile it before committing and never change the expectation to match.
- **Format/lint:** `gdformat --check godot/src godot/tests` (**90** files, unchanged) and `gdlint godot/src godot/tests` must be clean before every commit. Never run bare `gdformat` on existing files. Never touch `godot/addons/`.
- **Headless runs strip one line from `godot/project.godot`.** Every commit step begins with `git checkout godot/project.godot`.
- **`DIVERGENCE` count:** 178 at the M5 exit. Task 2 adds `DIVERGENCE(M6 R6)` ×1 and `DIVERGENCE(M6 R8)` ×2, for **181**.
- **gdlint limits:** `max-line-length: 100`. `audio_bank.gd` already opens with `# gdlint:ignore=max-public-methods`, and M6 adds no public method.
- **`user://` on the test host** is `%APPDATA%\Godot\app_userdata\Peril Point\`. Specs that build `GameOptionsManager` clear its save in `before_each` and `after_each` (`test_audio_call_sites.gd` already does).

## Review Focus

These are the inputs the spec implies that are most likely to bite a player. Each one has its test in the named task.

1. **Sound switched off on Pause mid-run, then on again.** Music goes silent at once (Sound is the TS master mute), and turning Sound back on brings it back at the saved music volume, with no burst of stacked notes (R6). Task 2 `test_mute_silences_music_but_keeps_it_running`.
2. **A second `start_music` while the loop is playing**, for example the Music switch toggled on during play, or a restart path that reaches `reset_run` with music running. It must not restart or double the loop (`:86`). Task 2 `test_start_music_while_playing_does_not_restart`.
3. **Pause → Resume, and death → Retry.** Music stops at once and comes back from the top of the arrangement (R5). Task 2 `test_stop_then_start_restarts_from_the_top`; Task 3 `test_a_new_run_starts_the_music_when_it_is_on`.
4. **Music switched off, then Retry.** The new run must stay silent (`TiltGame.ts:170`). Task 3 `test_a_new_run_stays_silent_when_music_is_off`.
5. **A long run passing the loop point (the 5-minute Accept) and a missing file on a fresh clone.** The file must be exactly one cycle with a forward loop over all of it, or a gap or doubled beat repeats every 28.66 s. A missing file warns and stays silent (§6.4). Task 1 `test_music_loop_is_one_cycle_and_loops_forward`; Task 2 `test_missing_music_file_logs_and_stays_silent`; device check "Five minutes".

---

## File Structure

| File | Role in M6 |
|---|---|
| `tools/bake-audio/wav.mjs` | **Create** (Task 1). `wav(samples, rate)` moved out of `bake_sfx.mjs` so both bakes share it. |
| `tools/bake-audio/bake_sfx.mjs` | **Modify** (Task 1). Imports `wav` from `./wav.mjs`. Its output must stay byte-identical. |
| `tools/bake-audio/bake_music.mjs` | **Create** (Task 1). The music bake (R1–R3). |
| `godot/assets/audio/music/music_loop.wav` + `.import` | **Create** (Task 1). The loop and its sidecar (R9), both committed. |
| `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md` | **Modify** (Task 1). R1 amendments at D5, §4.2 and §8 M6. |
| `godot/src/audio/audio_bank.gd` | **Modify** (Task 1: `MUSIC_PATH`; Task 2: music playback). |
| `godot/tests/test_audio_bank.gd` | **Modify** (Task 1: +1 test; Task 2: +6 tests). |
| `godot/src/sim/run_controller.gd` | **Modify** (Task 3). `start_music` in `reset_run` (R7). |
| `godot/tests/test_audio_call_sites.gd` | **Modify** (Task 3). +2 tests. |
| `godot/tests/test_main_scene.gd` | **Modify** (Task 3). +1 test. |
| `godot/VERIFY-ME.md` | **Modify — append** (Task 3). `## M6 — Generative music`. **Never recreate this file.** |
| `godot/PORT-PROGRESS.md`, `godot/HANDOFF.md`, `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md` | **Modify** (Task 4). Exit protocol. |
| `godot/src/core/game_state_machine.gd`, `game_root.gd`, `godot/tests/spy_audio_bank.gd` | **Not modified.** Every other `startMusic`/`stopMusic` site was wired in M5. |

**Spec §8 M6 coverage (as amended by R1).**

| Spec line | Task(s) |
|---|---|
| Music baked from the TS arrangement | 1 |
| `startMusic`/`stopMusic`/mute/volume ported | 2 |
| Accept: music plays and evolves across bars | 1 (whole cycle), 3 (starts with a run), device check |
| Accept: no dropouts over a 5-minute device run | 1 (seamless forward loop), device check |

## Tasks

### Task 1: The bake — `bake_music.mjs` and `music_loop.wav`

**Files:**
- Create: `tools/bake-audio/wav.mjs`, `tools/bake-audio/bake_music.mjs`, `godot/assets/audio/music/music_loop.wav`, `godot/assets/audio/music/music_loop.wav.import`
- Modify: `tools/bake-audio/bake_sfx.mjs` (lines 52-72 move to `wav.mjs`), `godot/src/audio/audio_bank.gd` (constants block), `godot/tests/test_audio_bank.gd`, the spec (D5 row, §4.2 tree, §8 M6)

**Interfaces:**
- Produces: `AudioBank.MUSIC_PATH: String = "res://assets/audio/music/music_loop.wav"`, and a loaded `AudioStreamWAV` with `loop_mode == LOOP_FORWARD`, `loop_begin == 0`, and `loop_end ==` frame count `== roundi(get_length() * mix_rate)`.

- [x] **Step 1: Write the failing test**

In `godot/tests/test_audio_bank.gd`, add these constants above `var _host: Node = null` (gdlint wants constants before variables and functions):

```gdscript
## One 16th note. PORT: web/src/tilt-to-live/TiltAudio.ts:18
const STEP_SECONDS: float = 60.0 / 134.0 / 4.0
## One cycle of the arrangement. PORT: web/src/tilt-to-live/TiltAudio.ts:110
const CYCLE_STEPS: int = 256
```

Then append this test after `test_every_baked_file_exists_and_nothing_else`:

```gdscript
func test_music_loop_is_one_cycle_and_loops_forward() -> void:
	assert_true(ResourceLoader.exists(AudioBank.MUSIC_PATH), "bake_music.mjs writes it (M6 R1)")
	var stream: AudioStreamWAV = load(AudioBank.MUSIC_PATH) as AudioStreamWAV
	assert_not_null(stream, "imported as AudioStreamWAV (M5 R1)")
	var rate: float = float(stream.mix_rate)
	# The second cycle's frame span (M6 R2).
	var frames: int = (
		roundi(2 * CYCLE_STEPS * STEP_SECONDS * rate) - roundi(CYCLE_STEPS * STEP_SECONDS * rate)
	)
	assert_eq(roundi(stream.get_length() * rate), frames, "exactly one cycle (M6 R2)")
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "M6 R9")
	assert_eq(stream.loop_begin, 0, "M6 R9")
	assert_eq(stream.loop_end, frames, "the whole file loops; -1 would drop a frame (M6 R9)")
```

Also add to the `AudioBank` constants in `godot/src/audio/audio_bank.gd`, directly after `SFX_DIR`:

```gdscript
## Where the music bake writes (M6 R1).
const MUSIC_PATH: String = "res://assets/audio/music/music_loop.wav"
```

- [x] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh`
Expected: FAIL in `test_music_loop_is_one_cycle_and_loops_forward` ("bake_music.mjs writes it"). Everything else passes (549 + 1 failing).

- [x] **Step 3: Move `wav()` into `tools/bake-audio/wav.mjs`**

Create `tools/bake-audio/wav.mjs`:

```js
// 16-bit PCM mono WAV encoder shared by bake_sfx.mjs and bake_music.mjs (M5 R1).

export function wav(samples, rate) {
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
```

In `tools/bake-audio/bake_sfx.mjs`, delete the `function wav(samples, rate) { … }` block (lines 52-72) and add `import { wav } from './wav.mjs';` after the existing `node:url` import.

Run: `node tools/bake-audio/bake_sfx.mjs | tail -1 && git status --short godot/assets/audio/sfx/`
Expected: `OK: 37 files in …`, then nothing (the SFX are byte-identical).

- [x] **Step 4: Write `tools/bake-audio/bake_music.mjs`**

```js
// Renders TiltAudio.ts's background music to one seamless loop WAV in
// godot/assets/audio/music/ (spec §8 Module 6 as amended by M6 R1).
//
// Run from the repository root:  node tools/bake-audio/bake_music.mjs
// Dependencies resolve from web/node_modules (`npm ci` in web/ first).
//
// The arrangement is a fixed 256-step cycle with no game input (TiltAudio.ts:110),
// so it is rendered once rather than sequenced at run time (M6 R1). The page calls
// TiltAudio's own scheduleStep for steps 0..511 on the same += grid its scheduler
// walks (:107-111) and keeps the second cycle: its head already holds the first
// cycle's ringing tails, so the file loops without a seam (M6 R2).

import { createRequire, stripTypeScriptTypes } from 'node:module';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { wav } from './wav.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
const outDir = resolve(repo, 'godot/assets/audio/music');
const puppeteer = createRequire(resolve(repo, 'web/package.json'))('puppeteer');

// Godot's default audio/driver/mix_rate, as bake_sfx.mjs (M5 R1).
const SAMPLE_RATE = 44100;
// One cycle: 16 bars * 16 steps (TiltAudio.ts:110).
const CYCLE = 256;
// M6 R3: arbitrary; any fixed seed makes the drums' noise buffer repeatable.
const NOISE_SEED = 0x5eed;

const source = stripTypeScriptTypes(
  readFileSync(resolve(repo, 'web/src/tilt-to-live/TiltAudio.ts'), 'utf8')
);

const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
const pageErrors = [];
let result;
try {
  const page = await browser.newPage();
  page.on('pageerror', (e) => pageErrors.push(e.message));
  await page.setContent('<!doctype html><html><body></body></html>');
  await page.addScriptTag({ type: 'module', content: `${source}\nwindow.TiltAudio = TiltAudio;` });
  await page.waitForFunction(() => window.TiltAudio !== undefined);

  result = await page.evaluate(
    async (cycle, rate, seed) => {
      // stepDuration is a TiltAudio field (:18); read it rather than copy it.
      const step = new window.TiltAudio().stepDuration;
      // The scheduler's own accumulation: nextStepTime += stepDuration (:109).
      const times = [];
      let t = 0;
      for (let s = 0; s <= 2 * cycle; s++) {
        times.push(t);
        t += step;
      }
      const begin = Math.round(times[cycle] * rate);
      const end = Math.round(times[2 * cycle] * rate);

      const ctx = new OfflineAudioContext(1, end, rate);
      // An offline context rejects resume() before startRendering() (M5 R3).
      ctx.resume = () => Promise.resolve();
      window.AudioContext = function () {
        return ctx;
      };
      // mulberry32 — M6 R3: getNoiseBuffer (:114-124) is the only Math.random reader.
      let a = seed >>> 0;
      const seeded = () => {
        a = (a + 0x6d2b79f5) >>> 0;
        let r = Math.imul(a ^ (a >>> 15), 1 | a);
        r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
        return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
      };
      const realRandom = Math.random;
      Math.random = seeded;
      try {
        const audio = new window.TiltAudio();
        audio.unlock();
        for (let s = 0; s < 2 * cycle; s++) {
          audio.scheduleStep(s % cycle, times[s]);
        }
      } finally {
        Math.random = realRandom;
      }
      const buffer = await ctx.startRendering();
      return { begin, end, samples: Array.from(buffer.getChannelData(0).subarray(begin, end)) };
    },
    CYCLE,
    SAMPLE_RATE,
    NOISE_SEED
  );
} finally {
  await browser.close();
}

const { samples } = result;
const peak = samples.reduce((p, s) => Math.max(p, Math.abs(s)), 0);
if (pageErrors.length > 0 || peak === 0 || peak >= 1) {
  console.error(`FAIL: ${pageErrors.length} page error(s), peak ${peak}`);
  for (const message of pageErrors) console.error(`  ${message}`);
  process.exit(1);
}
mkdirSync(outDir, { recursive: true });
writeFileSync(resolve(outDir, 'music_loop.wav'), wav(samples, SAMPLE_RATE));
console.log(
  `wrote music_loop.wav  frames ${result.begin}..${result.end}  peak ${peak.toFixed(4)}`
);
console.log(`OK: music_loop.wav ${samples.length} frames (loop_end) in ${outDir}`);
```

- [x] **Step 5: Run the bake twice and check it is deterministic**

Run: `node tools/bake-audio/bake_music.mjs && sha1sum godot/assets/audio/music/music_loop.wav && node tools/bake-audio/bake_music.mjs | tail -1 && sha1sum godot/assets/audio/music/music_loop.wav`
Expected: `OK: music_loop.wav 1263761 frames (loop_end) …` both times, the same SHA-1 both times, and a peak strictly between 0 and 1. If the frame count is not 1263761, stop: R2's arithmetic or the accumulation differs, so reconcile it before going on.

- [x] **Step 6: Import, set the loop, and re-import**

```bash
"$GODOT" --headless --path godot --import
sed -i -e 's/^edit\/loop_mode=.*/edit\/loop_mode=2/' -e 's/^edit\/loop_end=.*/edit\/loop_end=1263761/' godot/assets/audio/music/music_loop.wav.import
grep -n "loop\|compress" godot/assets/audio/music/music_loop.wav.import
"$GODOT" --headless --path godot --import
```

Expected grep: `edit/loop_mode=2`, `edit/loop_begin=0`, `edit/loop_end=1263761`, `compress/mode=2`.

- [x] **Step 7: Run the tests to verify they pass**

Run: `tools/run_tests.sh`
Expected: `OK: 50/50 scripts collected, all tests passed` with **550** tests.

- [x] **Step 8: Amend the spec (R1)**

In `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md`:
- Append to the D5 row's rationale cell: ` **Amended 2026-09-25 (M6 R1):** the TS arrangement takes no game input, so the music bakes to one seamless loop rendered by the TS scheduler's own \`scheduleStep\`; no stems and no GDScript sequencer.`
- In the §4.2 tree, change `audio/    audio_bank.gd  music_sequencer.gd` to `audio/    audio_bank.gd`, and add a line under the SFX one: `  assets/audio/music/music_loop.wav  generated by Module 6`.
- After the §8 M6 **Accept** line, add:

```markdown
**Amended 2026-09-25 (M6 R1):** the arrangement (`TiltAudio.ts:82-479`) is a
fixed 256-step cycle with no game input, so `tools/bake-audio/bake_music.mjs`
renders it once, through the TS's own `scheduleStep`, to a seamless loop WAV
(`godot/assets/audio/music/music_loop.wav`, QOA, forward loop).
`audio/audio_bank.gd` ports `startMusic`/`stopMusic` and the mute and music
volume against that loop. There are no stems and no `music_sequencer.gd`.
```

- [x] **Step 9: Commit**

```bash
git checkout godot/project.godot
gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add tools/bake-audio/wav.mjs tools/bake-audio/bake_sfx.mjs tools/bake-audio/bake_music.mjs godot/assets/audio/music/music_loop.wav godot/assets/audio/music/music_loop.wav.import godot/src/audio/audio_bank.gd godot/tests/test_audio_bank.gd docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md docs/superpowers/plans/2026-09-20-m6-generative-music.md godot/HANDOFF.md
git commit -m "M6: bake the music cycle to one seamless loop; next: M6 Task 2"
git log -1 --format=%B
```

---

### Task 2: `AudioBank` — play, stop, mute and scale the loop

**Files:**
- Modify: `godot/src/audio/audio_bank.gd` (header, `attach`, `set_music_volume`, `start_music`, `stop_music`, a PORT-NOTE after `stop_music`, `_apply_volume`)
- Test: `godot/tests/test_audio_bank.gd`

**Interfaces:**
- Consumes: `AudioBank.MUSIC_PATH` and the looping `music_loop.wav` (Task 1).
- Produces: `attach(host: Node, sfx_dir: String = SFX_DIR, music_path: String = MUSIC_PATH) -> void`; private `_music_player: AudioStreamPlayer`, `_music_stream: AudioStream`, `_is_music_playing: bool`. `start_music()`/`stop_music()` keep their signatures, so `SpyAudioBank` is unchanged.

- [ ] **Step 1: Write the failing tests**

Change `_attached` in `godot/tests/test_audio_bank.gd` to:

```gdscript
func _attached(
	sfx_dir: String = AudioBank.SFX_DIR, music_path: String = AudioBank.MUSIC_PATH
) -> AudioBank:
	var bank: AudioBank = AudioBank.new()
	bank.attach(_host, sfx_dir, music_path)
	return bank
```

Append:

```gdscript
func test_start_music_plays_the_loop_from_the_top() -> void:
	var bank: AudioBank = _attached()
	assert_false(bank._music_player.playing, "attach() does not start the music")
	assert_eq(bank._music_player.get_parent(), _host)
	bank.start_music()
	assert_true(bank._music_player.playing)
	assert_lt(bank._music_player.get_playback_position(), 0.1, "currentStep = 0 (TiltAudio.ts:88)")


func test_start_music_while_playing_does_not_restart() -> void:
	var bank: AudioBank = _attached()
	bank.start_music()
	bank._music_player.seek(5.0)
	bank.start_music()
	assert_gt(bank._music_player.get_playback_position(), 4.9, "the :86 guard")


func test_stop_then_start_restarts_from_the_top() -> void:
	var bank: AudioBank = _attached()
	bank.start_music()
	bank._music_player.seek(5.0)
	bank.stop_music()
	assert_false(bank._music_player.playing, "TiltAudio.ts:97-103")
	bank.start_music()
	assert_true(bank._music_player.playing)
	assert_lt(bank._music_player.get_playback_position(), 0.1, "resume restarts at step 0 (M6 R5)")


func test_mute_silences_music_but_keeps_it_running() -> void:
	var bank: AudioBank = _attached()
	bank.set_music_volume(0.5)
	bank.start_music()
	bank.set_muted(true)
	assert_eq(bank._music_player.volume_linear, 0.0, "masterGain 0 (TiltAudio.ts:62)")
	assert_true(bank._music_player.playing, "the loop plays on silently (M6 R6)")
	bank.set_music_volume(0.8)
	assert_eq(bank._music_player.volume_linear, 0.0, "a volume change does not unmute")
	bank.set_muted(false)
	assert_almost_eq(bank._music_player.volume_linear, 0.8, 0.0001, "the saved music volume")
	bank.toggle_mute()
	assert_eq(bank._music_player.volume_linear, 0.0, "toggle_mute mutes music too (:54)")


func test_music_volume_applies_live_relative_to_the_baked_gain() -> void:
	var bank: AudioBank = _attached()
	assert_almost_eq(bank._music_player.volume_linear, 1.0, 0.0001, "0.35 is baked in (M6 R4)")
	bank.set_music_volume(0.7)
	assert_almost_eq(bank._music_player.volume_linear, 0.7, 0.0001, "0.245 / 0.35")
	bank.set_music_volume(1.5)
	assert_almost_eq(bank._music_player.volume_linear, 1.0, 0.0001, "clamped (TiltAudio.ts:74)")


func test_missing_music_file_logs_and_stays_silent() -> void:
	var bank: AudioBank = _attached(AudioBank.SFX_DIR, "res://tests/fixtures/no_such_music.wav")
	assert_null(bank._music_stream, "nothing loaded")
	assert_not_null(bank._music_player, "the player still exists; only the file is missing")
	bank.start_music()
	assert_false(bank._music_player.playing, "silence, no error (spec §6.4)")
	bank.stop_music()
	assert_eq(bank._streams.size(), AudioBank.SFX_STEMS.size(), "the SFX are unaffected")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh`
Expected: the six new tests fail (`_music_player` is not a member, or `attach` takes 2 arguments), and the other 550 pass.

- [ ] **Step 3: Implement**

In `godot/src/audio/audio_bank.gd`:

(a) Header: replace `## of TiltAudio.ts (spec D5, §8 M5). The music half is M6.` with:

```gdscript
## of TiltAudio.ts (spec D5, §8 M5), and the music loop tools/bake-audio/
## bake_music.mjs renders from its scheduler (spec §8 M6, M6 R1).
```

Then append to the header's PORT-NOTE paragraph: `## The music loop carries musicGain 0.35 and masterGain 0.28 the same way (M6 R4).`

(b) Change the `music_gain` doc comment to `## The music gain; the player plays at music_gain / MUSIC_GAIN (M6 R4). PORT: web/src/tilt-to-live/TiltAudio.ts:43`. Then add after `var _muted: bool = false`:

```gdscript
var _is_music_playing: bool = false  # PORT: web/src/tilt-to-live/TiltAudio.ts:13
```

After `var _playback: AudioStreamPlaybackPolyphonic = null`, add:

```gdscript
var _music_stream: AudioStream = null
var _music_player: AudioStreamPlayer = null
```

(c) `attach`: change its signature to `func attach(host: Node, sfx_dir: String = SFX_DIR, music_path: String = MUSIC_PATH) -> void:`, change its doc's first line to `## Hangs the SFX and music players on \`host\` and loads every baked file. A missing file`, and insert before the final `_apply_volume()`:

```gdscript
	if ResourceLoader.exists(music_path):
		_music_stream = load(music_path) as AudioStream
	else:
		Log.warn("AudioBank: missing baked music %s; it plays silence" % music_path)
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = _music_stream
	host.add_child(_music_player)
```

(d) `set_music_volume`: add `_apply_volume()` as its last line.

(e) Replace `start_music` and `stop_music` with:

```gdscript
## Starts the background music. PORT: web/src/tilt-to-live/TiltAudio.ts:84-95
# PORT-NOTE: the TS calls unlock() first (:85); attach() did its work (M5 R10) and
# unlock() is a no-op, so it is not called here (M6 R5). currentStep = 0 (:88) is
# the loop's first frame.
# DIVERGENCE(M6 R8): the TS waits 50 ms before step 0 (:89) and its first cycle has
# no bar-15 tails at its head; the loop starts at once, tails included.
func start_music() -> void:
	if _is_music_playing:
		return
	_is_music_playing = true
	if _music_player != null and _music_stream != null:
		_music_player.play(0.0)


## Stops the background music. PORT: web/src/tilt-to-live/TiltAudio.ts:97-103
# DIVERGENCE(M6 R8): notes the TS already scheduled (up to scheduleAheadSec, :20)
# still sound after clearInterval; stop() cuts the loop at once.
func stop_music() -> void:
	_is_music_playing = false
	if _music_player != null:
		_music_player.stop()


# PORT-NOTE: scheduler, getNoiseBuffer, scheduleStep, scheduleDrums, triggerKick,
# triggerSnare, triggerHiHat, triggerCrash, scheduleBassLine, scheduleArpeggio,
# scheduleLeadMelody and schedulePadChord (TiltAudio.ts:105-479), with the fields
# currentStep..scheduleAheadSec (:14-20), run inside tools/bake-audio/bake_music.mjs;
# their output is music_loop.wav, so they have no GDScript counterpart (M6 R1).
```

(f) Replace `_apply_volume` and its doc comment with:

```gdscript
## masterGain is 0 while muted (TiltAudio.ts:54, :62); otherwise the sfx gain, and
## for music its gain relative to the baked MUSIC_GAIN (M6 R4).
func _apply_volume() -> void:
	if _player != null:
		_player.volume_linear = 0.0 if _muted else _sfx_volume
	if _music_player != null:
		# DIVERGENCE(M6 R6): the TS scheduler skips steps while muted (:106) and bursts
		# the backlog on unmute; the loop plays on at volume 0 instead.
		_music_player.volume_linear = 0.0 if _muted else music_gain / MUSIC_GAIN
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh`
Expected: `OK: 50/50 scripts collected, all tests passed` with **556** tests. `test_unattached_bank_is_silent_and_every_method_is_safe` still passes, which proves the null guards.

- [ ] **Step 5: Check the markers**

Run: `grep -rn "TODO(M6)" godot/src godot/tests; grep -rn "DIVERGENCE" godot/src | wc -l; grep -rn "DIVERGENCE(M6" godot/src | wc -l`
Expected: nothing; `181`; `3`.

- [ ] **Step 6: Commit**

```bash
git checkout godot/project.godot
gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add godot/src/audio/audio_bank.gd godot/tests/test_audio_bank.gd docs/superpowers/plans/2026-09-20-m6-generative-music.md godot/HANDOFF.md
git commit -m "M6: play and stop the music loop under the TS mute rules; next: Task 3"
git log -1 --format=%B
```

---

### Task 3: Start a run's music, and the device checklist

**Files:**
- Modify: `godot/src/sim/run_controller.gd:117-121` (`reset_run`)
- Test: `godot/tests/test_audio_call_sites.gd`, `godot/tests/test_main_scene.gd`
- Modify — append: `godot/VERIFY-ME.md` (`## M6 — Generative music`). **Never recreate this file.**

**Interfaces:**
- Consumes: `AudioBank.start_music()` (Task 2), `RunController.options.settings.music_enabled`, `SpyAudioBank.lifecycle`.

- [ ] **Step 1: Write the failing tests**

Append to `godot/tests/test_audio_call_sites.gd`:

```gdscript
func test_a_new_run_starts_the_music_when_it_is_on() -> void:
	var rc: RunController = _run_controller()
	rc.options.settings.music_enabled = true
	rc.reset_run(BOUNDS)
	assert_eq(_spy.lifecycle, ["start_music"] as Array[String], "TiltGame.ts:170-172 (M6 R7)")


func test_a_new_run_stays_silent_when_music_is_off() -> void:
	var rc: RunController = _run_controller()
	rc.options.settings.music_enabled = false
	rc.reset_run(BOUNDS)
	assert_true(_spy.lifecycle.is_empty(), "the musicEnabled guard (TiltGame.ts:170)")
```

Append to `godot/tests/test_main_scene.gd`, after `test_game_root_attaches_the_audio_bank`:

```gdscript
func test_the_boot_run_starts_the_music_when_it_is_on() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var bank: AudioBank = root._audio
	assert_eq(
		bank._music_player.playing,
		root.options.settings.music_enabled,
		"reset_run starts it at the cinematic's stand-in (M6 R7)"
	)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh`
Expected: `test_a_new_run_starts_the_music_when_it_is_on` fails (lifecycle empty), and so does `test_the_boot_run_starts_the_music_when_it_is_on` if the host's saved options have music on (the default). The rest pass.

- [ ] **Step 3: Implement**

In `godot/src/sim/run_controller.gd` `reset_run`, between `audio.set_music_volume(options.settings.music_volume)` and `spawn_starting_weapon_orb(bounds)`, insert:

```gdscript
	# PORT: web/src/tilt-to-live/TiltGame.ts:170-172 — the cinematic's completion
	# callback starts music, then spawns the starting orb; reset_run stands in for
	# that callback until the cinematic exists (M6 R7).
	# TODO(M11): move this and spawn_starting_weapon_orb to the cinematic's end.
	if options.settings.music_enabled:
		audio.start_music()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh`
Expected: `OK: 50/50 scripts collected, all tests passed` with **559** tests. `test_death_plays_the_crash_and_stops_the_music` and every `test_run_controller.gd` test still pass: `_run_controller()` clears the lifecycle after its own `reset_run`, and an unattached `AudioBank` ignores `start_music`.

- [ ] **Step 5: Headless boot check**

Run: `"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR\|missing baked"`
Expected: `0`.

- [ ] **Step 6: Check the phone and append the checklist**

Run: `"$ADB" devices`. If `RRCXB04L8EJ` is listed, export and install the debug APK the way earlier modules did (`godot/HANDOFF.md` "How to verify right now" and the M8.5/M9 device sections). Record the APK size delta (expect about +0.5 MB of QOA), walk the checks below with the user, and tick the ones they confirm. If the phone is absent, write the section unticked with "A55 absent from `adb` on <date>".

Append to `godot/VERIFY-ME.md`:

```markdown
## M6 — Generative music

Code-complete <date> (head `<sha>`). Music on (Pause → Music) and Sound on
(Pause → Sound — it is the master mute and silences music too).
<"A55 absent from `adb` on <date>; nothing below has been checked on the device yet." or the APK size delta>

- [ ] **Starts with the run.** Music starts as the run starts (at boot and on
      Retry / Restart run). The cinematic is M11, so it starts ~50 ms sooner
      than the web build (M6 R8).
- [ ] **Evolves across bars.** Drums, bass and arpeggio from the top; the lead
      melody enters at ~9 s (bar 4) and climbs at ~18 s (bar 8); the breakdown
      (pads, snare roll) runs ~21–28 s; the loop restarts at ~28.7 s.
- [ ] **Five minutes.** A run of 5+ minutes has no gap, click, doubled beat or
      drift at any loop point (every ~28.7 s), and no dropouts (spec §8 M6 Accept).
- [ ] **Pause and Armory.** Pause (or opening the Armory mid-run) stops the
      music at once; Resume restarts it from the top, as the web build does.
- [ ] **Music switch.** Pause → Music off keeps it off after Resume and Retry;
      on again plays from the top on Resume. The choice survives an app relaunch.
- [ ] **Sound switch.** Pause → Sound off silences music with the effects; on
      again brings it back at the same loudness with no burst of stacked notes
      (M6 R6).
- [ ] **Death.** The death crash stops the music; Retry starts it again.
- [ ] **Level.** The music sits under the effects roughly as it does in the
      web build on the same phone.
```

Also, in `godot/VERIFY-ME.md` §M5, replace `Music is M6 —\nsilence between effects is expected.` with `Music (M6) plays under the effects; judge only the effects here.`

- [ ] **Step 7: Commit**

```bash
git checkout godot/project.godot
gdformat --check godot/src godot/tests && gdlint godot/src godot/tests
git add godot/src/sim/run_controller.gd godot/tests/test_audio_call_sites.gd godot/tests/test_main_scene.gd godot/VERIFY-ME.md docs/superpowers/plans/2026-09-20-m6-generative-music.md godot/HANDOFF.md
git commit -m "M6: start a run's music at the cinematic stand-in; next: M6 Task 4 exit"
git log -1 --format=%B
```

---

## Execution rulings

Inline execution (executing-plans); ledger at `.superpowers/sdd/2026-09-20-m6-generative-music/progress.md` (git-ignored), copied here.

- **Task 1 (2026-09-25).** (a) The test gained `if stream == null: return` after `assert_not_null`, so the red run fails on the assertion rather than a null dereference. (b) Chrome's offline render is not bit-exact between runs: two bakes differed in 4 of 1 263 761 samples, each by 1 LSB (float jitter at int16 rounding boundaries). `bake_music.mjs` therefore keeps the existing `music_loop.wav` when a fresh render is within 1 LSB of it in every sample (it prints `kept`), so the exit check "`git status --short godot/assets/audio/` empty" holds. R3's "byte-deterministic" is true to ±1 LSB. The bake printed 1263761 frames and peak 0.0580. Per-bar RMS ×1000 was `4.6 4.3 4.3 4.4 5.3 5.1 5.1 5.2 5.3 5.1 5.1 5.1 2.2 1.6 2.9 4.6`: the lead adds level in bars 4–11, and the breakdown dips in bars 12–14.

### Task 4: Module exit protocol (CONVENTIONS §9)

**Files:**
- Modify: `godot/PORT-PROGRESS.md` (the M6 box), `godot/HANDOFF.md` (rewrite `## State`, add `## M6 — what landed`, rewrite `## Next`), `docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md` (row 6)

- [ ] **Step 1: Verify, fresh, and read every output**

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
node tools/bake-audio/bake_sfx.mjs | tail -1     # expect: OK: 37 files in …
node tools/bake-audio/bake_music.mjs | tail -1   # expect: OK: music_loop.wav 1263761 frames (loop_end) in …
git status --short godot/assets/audio/           # expect: empty (both bakes are deterministic)
tools/run_tests.sh                        # expect: OK: 50/50 scripts (559 tests)
gdformat --check godot/src godot/tests    # expect: 90 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "TODO(M6)" godot/src/ godot/tests/   # expect: nothing
grep -rniE "ff4757" godot/src/ui/         # expect: nothing (rule 01)
grep -rn "DIVERGENCE" godot/src/ | wc -l  # expect: 181
grep -rn "DIVERGENCE(M6" godot/src/ | wc -l   # expect: 3
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR"   # expect: 0
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "missing baked"  # expect: 0
git checkout godot/project.godot
git status --short                        # expect: empty
```

If any command differs from its expectation, the module is not done: fix it or stop and report.

- [ ] **Step 2: Tick `PORT-PROGRESS.md`**

Replace the M6 entry with:

```markdown
- [x] **M6 — Generative music**  deps: M5  done <date>  <sha>  DEVICE PASS PENDING
      plan  `docs/superpowers/plans/2026-09-20-m6-generative-music.md`
      ok  the 16-bar arrangement bakes to one seamless loop (M6 R1: no stems,
          no sequencer) — tools/bake-audio/bake_music.mjs, 1263761 frames.
      ok  start/stop/mute/volume follow TiltAudio.ts (test_audio_bank.gd); a
          run starts its music (test_audio_call_sites.gd, test_main_scene.gd).
      ok  50/50 GUT scripts (559 tests); gdformat/gdlint clean; `TODO(M6)`
          grep empty; headless 0 SCRIPT ERROR.
      --  "evolves across bars" and "no dropouts over 5 minutes" — device
          pass pending, `VERIFY-ME.md` §M6.
```

- [ ] **Step 3: Rewrite `HANDOFF.md`**

Rewrite it for a session with zero context:
- `## State`: M6 is code-complete with the device pass pending; give the final commit SHA. Move M5's paragraph down into the "code-complete, device pass pending" list.
- `## How to verify right now`: the Step 1 commands with their fresh outputs, plus the music bake line.
- A new `## M6 — what landed` section: a file-by-file table and rulings R1–R9, one line each.
- `## Open questions (M6)`: any stop raised during execution, or "None".
- `## Next`: the next module by the index plan's dependency order. Its deps are satisfied (M11 needs everything, so it is **not** next while any module is unwritten; pick the lowest-numbered unwritten module whose deps are done, and read the index plan to confirm). Its literal first step is to read that module's TS sources and spec §8 section, then write its plan, commit it, and stop for review. Carry forward:
  - M11 must move `start_music` and `spawn_starting_weapon_orb` from `RunController.reset_run` into the cinematic's end (`TODO(M11)`, M6 R7), and must call `play_warp_in` from the cinematic (`TiltEntranceCinematic.ts:74`, M5 R8).
  - Re-bake the music only if `TiltAudio.ts:82-479` changes: `node tools/bake-audio/bake_music.mjs`, then `--import`. If the frame count changes, update `edit/loop_end` in `music_loop.wav.import` (R9).
  - The device pass now covers M2.5, M3, M4, M5, M6, M7, M8.5, M9, M10 and the scale split.

Copy every execution ruling from the SDD ledger (if one was kept) into this plan under a new `## Execution rulings` section. The ledger is git-ignored (M9 lesson).

In the index plan, set row 6 to `| 6 | Generative music (baked loop, M6 R1) | M5 | \`2026-09-20-m6-generative-music.md\` | **code complete** — device pass pending (\`godot/VERIFY-ME.md\`) |`.

- [ ] **Step 4: Commit**

```bash
git add godot/PORT-PROGRESS.md godot/HANDOFF.md docs/superpowers/plans/2026-09-20-peril-point-godot-port-index.md docs/superpowers/plans/2026-09-20-m6-generative-music.md
git commit -m "M6 done: next read godot/HANDOFF.md + VERIFY-ME.md, then plan <next module>"
git log -1 --format=%B
```

- [ ] **Step 5: Stop.** Report to the user and do not begin the next module (CONVENTIONS §9 step 5).
