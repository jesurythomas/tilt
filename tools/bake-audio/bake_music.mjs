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
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
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
// Chrome's offline render is not bit-exact run to run: a handful of samples land
// either side of an int16 rounding step. A render within 1 LSB of the committed
// file keeps that file, so a re-bake leaves git clean.
const outPath = resolve(outDir, 'music_loop.wav');
const encoded = wav(samples, SAMPLE_RATE);
let unchanged = false;
if (existsSync(outPath)) {
  const old = readFileSync(outPath);
  unchanged = old.length === encoded.length;
  for (let i = 44; unchanged && i < encoded.length; i += 2) {
    unchanged = Math.abs(old.readInt16LE(i) - encoded.readInt16LE(i)) <= 1;
  }
}
if (!unchanged) {
  mkdirSync(outDir, { recursive: true });
  writeFileSync(outPath, encoded);
}
console.log(
  `${unchanged ? 'kept' : 'wrote'} music_loop.wav  frames ${result.begin}..${result.end}  ` +
    `peak ${peak.toFixed(4)}`
);
console.log(`OK: music_loop.wav ${samples.length} frames (loop_end) in ${outDir}`);
