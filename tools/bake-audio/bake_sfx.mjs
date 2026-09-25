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
