// Dumps GoalManager.ts's catalog to a JSON fixture the GUT specs assert
// against. Spec §6.3 Tier 2 names "goal thresholds"; the catalog is 57 goals
// and ~230 literals, and transcription drift is the risk. Run from the
// repository root:
//
//   web/node_modules/.bin/esbuild tools/parity/dump_goals.mjs --bundle \
//     --platform=node --format=esm --outfile=godot/build/dump_goals.bundle.mjs \
//   && node godot/build/dump_goals.bundle.mjs
//
// localStorage does not exist in Node; the constructor's loads catch the
// ReferenceError and keep their defaults, which is exactly what is wanted.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { GoalManager } from '../../web/src/tilt-to-live/GoalManager.ts';

// esbuild inlines the source, so resolve the output relative to the repo root
// rather than to this file's (bundled) location.
const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..', '..');
const outDir = resolve(repoRoot, 'godot/tests/fixtures');
mkdirSync(outDir, { recursive: true });

const goals = new GoalManager();
const catalog = goals.catalog.map((g) => ({
  id: g.id,
  category: g.category,
  title: g.title,
  description: g.description,
  target: g.target,
  rewardPoints: g.rewardPoints,
  metric: g.metric,
  targetId: g.targetId ?? ''
}));

writeFileSync(resolve(outDir, 'goals.json'), JSON.stringify({ catalog }, null, 2) + '\n');
console.log(`wrote ${catalog.length} goals to godot/tests/fixtures/goals.json`);
