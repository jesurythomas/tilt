// =========================================================================
// WeaponTuning.ts - SINGLE SOURCE OF TRUTH for weapon range/radius/duration
// magic numbers.
//
// WeaponSystem.ts currently re-declares these as inline literals
// (e.g. `(460 + (perks?.blackhole.radius || 0) * 35)`). That file must be
// migrated to read `getTunedValue('blackhole', 'radius', rank)` (and the
// other WEAPON_TUNING entries below) instead of re-declaring its own
// base/perRank literals, so the numbers never drift out of sync again.
//
// `max` on each entry is the value at that track's maximum perk rank
// (base + perRank * maxRank), matching the 0..N rank ranges documented on
// WeaponPerks in ProgressionManager.ts. It exists so UI (e.g. the Armory)
// can display "current -> max" without redoing the rank math.
// =========================================================================

export type TuningUnit = 'range' | 'seconds' | 'percent' | 'count';

export interface TuningEntry {
  base: number;
  perRank: number;
  max: number;
  unit: TuningUnit;
}

export type WeaponTuningTable = Record<string, Record<string, TuningEntry>>;

export const WEAPON_TUNING: WeaponTuningTable = {
  blackhole: {
    radius: { base: 340, perRank: 18, max: 430, unit: 'range' }, // was base 460, perRank 35
    duration: { base: 4.8, perRank: 0.5, max: 7.3, unit: 'seconds' },
    gravity: { base: 0, perRank: 20, max: 100, unit: 'percent' }
  },
  nuke: {
    radius: { base: 360, perRank: 22, max: 470, unit: 'range' }, // was base 480, perRank 40
    speed: { base: 0, perRank: 25, max: 75, unit: 'percent' }
  },
  shield: {
    duration: { base: 6.0, perRank: 1.0, max: 11.0, unit: 'seconds' },
    radius: { base: 20, perRank: 2, max: 26, unit: 'range' } // was hardcoded 23, perRank 4
  },
  missiles: {
    count: { base: 8, perRank: 1, max: 13, unit: 'count' },
    blastRadius: { base: 40, perRank: 6, max: 58, unit: 'range' }, // was hardcoded 55, perRank 12
    flightSpeed: { base: 0, perRank: 20, max: 60, unit: 'percent' }
  },
  laser: {
    length: { base: 260, perRank: 20, max: 360, unit: 'range' }, // was base 340, perRank 35
    duration: { base: 1.8, perRank: 0.4, max: 3.0, unit: 'seconds' }
  },
  lightning: {
    maxTargets: { base: 14, perRank: 3, max: 29, unit: 'count' },
    chainRange: { base: 220, perRank: 22, max: 286, unit: 'range' } // was base 280, perRank 40
  },
  freeze: {
    duration: { base: 4.5, perRank: 0.7, max: 8.2, unit: 'seconds' }
  }
};

/** base + perRank * rank for the given weapon/track pair. Returns 0 if unknown. */
export function getTunedValue(weapon: string, track: string, rank: number): number {
  const entry = WEAPON_TUNING[weapon]?.[track];
  if (!entry) return 0;
  return entry.base + entry.perRank * rank;
}

// Blackhole "Supernova Collapse" keystone shockwave radius (was 420).
export const SUPERNOVA_SHOCKWAVE = 320;

// Keystone perk prices. These are the prices ArmoryUI.ts's weaponsCatalog
// actually displays; getPerkCost() below now charges these instead of a
// flat 2500/5000, fixing the previous undercharge bug.
export const KEYSTONE_COSTS: Record<string, number> = {
  crossBeam: 3500,
  refractorLance: 4500,
  falloutZone: 3000,
  batteringRam: 3000,
  overchargePulse: 4500,
  plasmaArc: 3500,
  superconductor: 4500,
  shatterCascade: 2500,
  cryoNova: 4000,
  clusterSplit: 2500,
  hyperThrusters: 4000,
  supernovaCollapse: 5000,
  chainReaction: 5000
};
