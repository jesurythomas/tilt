// Dumps ProgressionManager.ts and GameOptions.ts's hard-coded tables to a JSON
// fixture the GUT specs assert against. Spec §6.3 Tier 2 — the perk cost
// curve, the default save, the three catalogs, the purchasable ladders and
// the mode configs are ~330 literals; transcription drift is the risk.
//
// ProgressionManager.ts imports a type from './Types' with no extension, which
// Node's ESM loader cannot resolve and whose type-only export it cannot erase,
// so this script is bundled first. Run from the repository root:
//
//   web/node_modules/.bin/esbuild tools/parity/dump_progression.mjs --bundle \
//     --platform=node --format=esm --outfile=godot/build/dump_progression.bundle.mjs \
//   && node godot/build/dump_progression.bundle.mjs
//
// localStorage does not exist in Node; both constructors catch the
// ReferenceError and return their defaults, which is exactly what is wanted.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { ProgressionManager } from '../../web/src/tilt-to-live/ProgressionManager.ts';
import { GameOptionsManager } from '../../web/src/tilt-to-live/GameOptions.ts';
import { KEYSTONE_COSTS } from '../../web/src/tilt-to-live/WeaponTuning.ts';

// esbuild inlines the source, so resolve the output relative to the repo root
// rather than to this file's (bundled) location.
const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..', '..');
const outDir = resolve(repoRoot, 'godot/tests/fixtures');
mkdirSync(outDir, { recursive: true });

const progression = new ProgressionManager();
const options = new GameOptionsManager();

const perkCostCurve = [0, 1, 2, 3, 4, 5, 9].map((rank) => ({ rank, cost: progression.getPerkCost(rank) }));
const keystoneCosts = Object.keys(KEYSTONE_COSTS).map((key) => ({ key, cost: progression.getPerkCost(0, true, key) }));
keystoneCosts.push({ key: 'nosuch', cost: progression.getPerkCost(0, true, 'nosuch') });
keystoneCosts.push({ key: '', cost: progression.getPerkCost(0, true) });

const ladders = {};
for (const [name, getter, field] of [
  ['extraLives', 'getExtraLivesCost', 'extraLives'],
  ['hullCompact', 'getHullCompactCost', 'hullCompact'],
  ['enemySlow', 'getEnemySlowCost', 'enemySlow'],
  ['scoreMultiplier', 'getScoreMultiplierCost', 'scoreMultiplier'],
  ['pointsMultiplier', 'getPointsMultiplierCost', 'pointsMultiplier']
]) {
  const p = new ProgressionManager();
  const costs = [];
  for (let rank = 0; rank < 6; rank++) {
    p.data[field] = rank;
    costs.push(p[getter]()); // null past the ladder's end
  }
  ladders[name] = costs;
}

const invested = {};
for (const weapon of Object.keys(progression.data.perks)) {
  invested[weapon] = progression.getWeaponInvestedPoints(weapon);
}

const file = resolve(outDir, 'progression.json');
writeFileSync(
  file,
  JSON.stringify(
    {
      source: 'web/src/tilt-to-live/ProgressionManager.ts, GameOptions.ts',
      generated_by: 'tools/parity/dump_progression.mjs',
      default_data: progression.data,
      ship_catalog: progression.shipCatalog,
      enemy_skin_catalog: progression.enemySkinCatalog,
      arena_theme_catalog: progression.arenaThemeCatalog,
      perk_cost_curve: perkCostCurve,
      keystone_costs: keystoneCosts,
      purchasable_ladders: ladders,
      invested_points_at_defaults: invested,
      multipliers_at_defaults: {
        startingLives: progression.getStartingLives(),
        hitbox: progression.getHitboxMultiplier(),
        enemySpeed: progression.getEnemySpeedMultiplier(),
        score: progression.getScoreMultiplier(),
        points: progression.getPointsMultiplier()
      },
      modes: options.modes,
      default_settings: options.settings,
      shake_multipliers: ['off', 'low', 'normal', 'extreme', 'full', 'bogus'].map((screenShake) => {
        const o = new GameOptionsManager();
        o.settings.screenShake = screenShake;
        return { screenShake, multiplier: o.getShakeMultiplier() };
      })
    },
    null,
    2
  ) + '\n'
);
console.log(`wrote ${file}`);
