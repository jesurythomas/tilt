// Dumps the TypeScript constant tables to JSON fixtures the GUT specs assert
// against. Spec §6.3 Tier 2: the dominant failure mode in a 13,000-line
// mechanical translation is transcription drift, not bad design.
//
// Run from the repository root:  node tools/parity/dump_constants.mjs
// Node 24 strips the TypeScript types natively; WeaponTuning.ts is
// erasable-syntax-only (interfaces and type aliases, no enums or namespaces).

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  WEAPON_TUNING,
  SUPERNOVA_SHOCKWAVE,
  KEYSTONE_COSTS,
  getTunedValue
} from '../../web/src/tilt-to-live/WeaponTuning.ts';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = resolve(here, '../../godot/tests/fixtures');
mkdirSync(outDir, { recursive: true });

const write = (name, payload) => {
  const file = resolve(outDir, name);
  writeFileSync(file, JSON.stringify(payload, null, 2) + '\n');
  console.log(`wrote ${file}`);
};

// --- WEAPON_TUNING -------------------------------------------------------
const tunedValueSamples = [];
for (const [weapon, tracks] of Object.entries(WEAPON_TUNING)) {
  for (const track of Object.keys(tracks)) {
    for (const rank of [0, 1, 3, 5]) {
      tunedValueSamples.push({ weapon, track, rank, value: getTunedValue(weapon, track, rank) });
    }
  }
}
// getTunedValue returns 0 for an unknown pair (WeaponTuning.ts:63).
tunedValueSamples.push({ weapon: 'nosuch', track: 'nosuch', rank: 2, value: getTunedValue('nosuch', 'nosuch', 2) });

write('weapon_tuning.json', {
  source: 'web/src/tilt-to-live/WeaponTuning.ts',
  generated_by: 'tools/parity/dump_constants.mjs',
  weapon_tuning: WEAPON_TUNING,
  supernova_shockwave: SUPERNOVA_SHOCKWAVE,
  keystone_costs: KEYSTONE_COSTS,
  tuned_value_samples: tunedValueSamples
});

// --- arenaScale ----------------------------------------------------------
// Transcribed from TiltGame.resizeCanvas(), web/src/tilt-to-live/TiltGame.ts:2422-2431.
const arenaScale = (rawW, rawH) => {
  const w = Math.max(320, Math.floor(rawW));
  const h = Math.max(240, Math.floor(rawH));
  const minDim = Math.min(w, h);
  return Math.max(0.6, Math.min(1.15, minDim / 680));
};

write('arena_scale.json', {
  source: 'web/src/tilt-to-live/TiltGame.ts:2422-2431',
  generated_by: 'tools/parity/dump_constants.mjs',
  cases: [
    [100, 100],     // below both floors
    [320, 240],     // exactly the floors
    [640, 360],     // clamps to the 0.60 floor
    [680, 680],     // exactly 1.0
    [1280, 720],    // desktop-ish
    [2340, 1080],   // the Galaxy A55 in landscape
    [3000, 2000]    // clamps to the 1.15 ceiling
  ].map(([width, height]) => ({ width, height, scale: arenaScale(width, height) }))
});
