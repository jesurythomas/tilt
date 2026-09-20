// =========================================================================
// ProgressionManager.ts - Perks, Custom Cursors, Enemy Skins, Arenas & Economy
// =========================================================================

import { WeaponType } from './Types';
import { KEYSTONE_COSTS } from './WeaponTuning';

export interface WeaponPerks {
  blackhole: {
    duration: number; // 0..5 (+0.5s per rank)
    radius: number; // 0..5 (+18 range per rank)
    gravity: number; // 0..5 (+20% pull force per rank)
    invulnerableInside: boolean; // Keystone: player is invulnerable while inside blackhole!
    supernovaCollapse: boolean; // Keystone: collapse shockwave reaches 320px!
  };
  nuke: {
    radius: number; // 0..5 (+22 range per rank)
    speed: number; // 0..3 (+25% blast expansion speed)
    falloutZone: boolean; // Keystone: lingering radiation for 3s
  };
  shield: {
    duration: number; // 0..5 (+1.0s per rank)
    radius: number; // 0..3 (+2 range per rank)
    batteringRam: boolean; // Keystone: ramming explodes adjacent dots
  };
  missiles: {
    count: number; // 0..5 (+1 missile per rank, 8 -> 13)
    blastRadius: number; // 0..3 (+6 range per rank)
    flightSpeed: number; // 0..3 (+20% speed & turn rate)
  };
  laser: {
    length: number; // 0..5 (+20 range per rank)
    duration: number; // 0..3 (+0.4s per rank)
    crossBeam: boolean; // Keystone: 4-way perpendicular cross laser!
  };
  lightning: {
    maxTargets: number; // 0..5 (+3 targets per rank)
    chainRange: number; // 0..3 (+22 range per rank)
  };
  freeze: {
    duration: number; // 0..5 (+0.7s per rank)
    shatterCascade: boolean; // Keystone: ramming a frozen dot shatters neighbors
  };
}

export interface ShipSkinConfig {
  id: string;
  name: string;
  trait: string;
  price: number;
  description: string;
  hitbox: string;
  turn: string;
  hitboxScale: number;
  turnRate: number;
  // Optional so existing fallback ShipSkinConfig object literals elsewhere
  // (owned by other files) don't need to be updated to remain valid.
  startingWeapon?: WeaponType;
  bonusLives?: number;
  tint: string;
  svgPath: string;
  hullColor: string;
  primaryColor: string;
  accentColor: string;
  thrusterColor: string;
  trailColor: string;
  tetherColor: string;
  shape: 'classic' | 'viper' | 'phantom' | 'solar' | 'cyber' | 'shuriken' | 'celestial';
}

export type CursorSkinConfig = ShipSkinConfig;

export interface EnemySkinConfig {
  id: string;
  name: string;
  price: number;
  description: string;
  glowColor: string;
  bodyGradient: [string, string, string]; // [inner, mid, outer]
  pupilColor: string;
  borderColor: string;
}

export interface ArenaThemeConfig {
  id: string;
  name: string;
  price: number;
  description: string;
  bgGradient: [string, string, string];
  gridColor: string;
  boundaryColor: string;
  dustColor: string;
}

export interface SteeringTuning {
  sensitivity: number; // 0.5 .. 2.0 (default 1.0)
  deadzone: number; // 0 .. 16 (default 4)
}

export interface ProgressionData {
  points: number;
  lifetimePoints: number;
  perks: WeaponPerks;
  equippedCursorId: string;
  unlockedCursors: string[];
  equippedEnemySkinId: string;
  unlockedEnemySkins: string[];
  equippedArenaThemeId: string;
  unlockedArenaThemes: string[];
  tuning: SteeringTuning;
  // --- Rank-based purchasables (top-level scalars: safe under {...def, ...parsed}) ---
  extraLives: number; // 0..2, +1 starting life per rank (hard-capped at 3 total)
  hullCompact: number; // 0..3, -6% player hitbox per rank
  enemySlow: number; // 0..3, -4% enemy speed per rank
  scoreMultiplier: number; // 0..4, +10% in-run score per rank
  pointsMultiplier: number; // 0..4, +10% earned points per rank
}

const STORAGE_KEY = 'tilt_to_live_progression_v3';

export class ProgressionManager {
  public data: ProgressionData;

  // Ship hitbox/turn display strings derive directly from the numeric fields:
  //   hitbox% = round(hitboxScale * 50), turn% = round(turnRate * 60)
  // Keep them in sync if hitboxScale/turnRate ever change.
  public readonly shipCatalog: ShipSkinConfig[] = [
    {
      id: 'classic',
      name: 'Arrow',
      trait: 'Balanced',
      price: 0,
      description: 'The iconic high-agility balanced arrow craft with sharp delta wings.',
      hitbox: '50%',
      turn: '60%',
      hitboxScale: 1.0,
      turnRate: 1.0,
      startingWeapon: 'shield',
      tint: '#5B8CFF',
      svgPath: 'M40 24 L14 10 L19 24 L14 38 Z',
      hullColor: '#ffffff',
      primaryColor: '#5B8CFF',
      accentColor: '#8FB0FF',
      thrusterColor: '#5B8CFF',
      trailColor: 'rgba(91, 140, 255, 0.4)',
      tetherColor: 'rgba(91, 140, 255, 0.25)',
      shape: 'classic'
    },
    {
      id: 'tactical',
      name: 'Viper',
      trait: 'Aggressive',
      price: 0,
      description: 'Aggressive forward-swept fighter jet with high turn speed.',
      hitbox: '60%',
      turn: '81%',
      hitboxScale: 1.20,
      turnRate: 1.35,
      startingWeapon: 'missiles',
      tint: '#FF8A94',
      svgPath: 'M40 24 L12 8 L20 24 L12 40 Z',
      hullColor: '#161924',
      primaryColor: '#FF8A94',
      accentColor: '#ff2a4b',
      thrusterColor: '#ff5500',
      trailColor: 'rgba(255, 138, 148, 0.4)',
      tetherColor: 'rgba(255, 138, 148, 0.35)',
      shape: 'viper'
    },
    {
      id: 'singularity',
      name: 'Phantom',
      trait: 'Evasive',
      price: 0,
      description: 'Ultra-thin evasive voidcraft with minuscule hitbox to slip past dense swarms.',
      hitbox: '20%',
      turn: '48%',
      hitboxScale: 0.40,
      turnRate: 0.80,
      startingWeapon: 'freeze',
      tint: '#A78BFA',
      svgPath: 'M42 24 L10 12 L22 24 L10 36 Z',
      hullColor: '#160826',
      primaryColor: '#A78BFA',
      accentColor: '#b84dff',
      thrusterColor: '#9933ff',
      trailColor: 'rgba(167, 139, 250, 0.4)',
      tetherColor: 'rgba(167, 139, 250, 0.35)',
      shape: 'phantom'
    },
    {
      id: 'solar',
      name: 'Aegis',
      trait: 'Heavy',
      price: 600,
      description: 'Heavy reinforced armored chassis with immense presence and slower turn rate.',
      hitbox: '95%',
      turn: '27%',
      hitboxScale: 1.90,
      turnRate: 0.45,
      startingWeapon: 'nuke',
      tint: '#FFB14D',
      svgPath: 'M41 24 L33 9 L17 9 L7 24 L17 39 L33 39 Z',
      hullColor: '#ffd700',
      primaryColor: '#FFB14D',
      accentColor: '#ffffff',
      thrusterColor: '#ffaa00',
      trailColor: 'rgba(255, 177, 77, 0.4)',
      tetherColor: 'rgba(255, 177, 77, 0.35)',
      shape: 'solar'
    },
    {
      id: 'cyber',
      name: 'Matrix',
      trait: 'Fast cooldown',
      price: 800,
      description: 'Digital diamond vector hull tuned for fast responses and tight maneuvers.',
      hitbox: '53%',
      turn: '78%',
      hitboxScale: 1.05,
      turnRate: 1.30,
      startingWeapon: 'lightning',
      tint: '#3DDC97',
      svgPath: 'M24 6 L40 24 L24 42 L8 24 Z',
      hullColor: '#0a1220',
      primaryColor: '#3DDC97',
      accentColor: '#00ffff',
      thrusterColor: '#ff00aa',
      trailColor: 'rgba(61, 220, 151, 0.4)',
      tetherColor: 'rgba(61, 220, 151, 0.32)',
      shape: 'cyber'
    },
    {
      id: 'shuriken',
      name: 'Shuriken',
      trait: 'Spin drift',
      price: 1000,
      description: 'Starframe chassis boasting extreme rotational acceleration and spin agility.',
      hitbox: '43%',
      turn: '96%',
      hitboxScale: 0.85,
      turnRate: 1.60,
      startingWeapon: 'laser',
      tint: '#8FB0FF',
      svgPath: 'M24 6 L30 18 L42 24 L30 30 L24 42 L18 30 L6 24 L18 18 Z',
      hullColor: '#082014',
      primaryColor: '#8FB0FF',
      accentColor: '#88ffcc',
      thrusterColor: '#5b8cff',
      trailColor: 'rgba(143, 176, 255, 0.4)',
      tetherColor: 'rgba(143, 176, 255, 0.35)',
      shape: 'shuriken'
    },
    {
      id: 'revenant',
      name: 'Revenant',
      trait: 'Second wind',
      price: 2500,
      description: 'A ghostly celestial hull reforged from lost light, granting one extra life to rise again.',
      hitbox: '68%',
      turn: '54%',
      hitboxScale: 1.35,
      turnRate: 0.90,
      startingWeapon: 'vortex',
      bonusLives: 1,
      tint: '#FFB14D',
      svgPath: 'M40 24 L16 8 L22 24 L16 40 Z',
      hullColor: '#f8fafc',
      primaryColor: '#FFB14D',
      accentColor: '#38bdf8',
      thrusterColor: '#38bdf8',
      trailColor: 'rgba(255, 177, 77, 0.4)',
      tetherColor: 'rgba(255, 177, 77, 0.35)',
      shape: 'celestial'
    }
  ];

  public readonly cursorCatalog: ShipSkinConfig[] = this.shipCatalog;

  public readonly enemySkinCatalog: EnemySkinConfig[] = [
    {
      id: 'classic',
      name: 'Classic Crimson',
      price: 0,
      description: 'The iconic evil red dots with sinister crimson body and dark pupil.',
      glowColor: 'rgba(255, 30, 60, 0.35)',
      bodyGradient: ['#ff6677', '#ee1133', '#990011'],
      pupilColor: '#110005',
      borderColor: '#ff8899'
    },
    {
      id: 'toxic',
      name: 'Toxic Biohazard',
      price: 400,
      description: 'Radioactive neon-green cellular organisms with bubbling caustic cores.',
      glowColor: 'rgba(0, 255, 100, 0.35)',
      bodyGradient: ['#88ff99', '#11ee44', '#007722'],
      pupilColor: '#021805',
      borderColor: '#aaffbb'
    },
    {
      id: 'glitch',
      name: 'Cyber Glitch',
      price: 600,
      description: 'Polygon wireframe cyber dots flickering between electric cyan and hot magenta.',
      glowColor: 'rgba(91, 140, 255, 0.4)',
      bodyGradient: ['#88ffff', '#00bfff', '#0044aa'],
      pupilColor: '#ff0077',
      borderColor: '#5B8CFF'
    },
    {
      id: 'magma',
      name: 'Molten Magma',
      price: 800,
      description: 'Volcanic burning ember cores encased in cracked obsidian rock.',
      glowColor: 'rgba(255, 120, 0, 0.4)',
      bodyGradient: ['#ffcc00', '#ff5500', '#881100'],
      pupilColor: '#2b0800',
      borderColor: '#ffaa33'
    },
    {
      id: 'void',
      name: 'Abyssal Void',
      price: 1000,
      description: 'Pitch-black shadow orbs surrounded by a pulsating violet event horizon.',
      glowColor: 'rgba(180, 50, 255, 0.45)',
      bodyGradient: ['#9944ff', '#330066', '#080014'],
      pupilColor: '#ffffff',
      borderColor: '#cc88ff'
    },
    {
      id: 'gold',
      name: 'Midas Gold',
      price: 1500,
      description: 'Polished metallic reflective 24K gold spheres with radiant star gleams.',
      glowColor: 'rgba(255, 215, 0, 0.45)',
      bodyGradient: ['#fff6b3', '#FFB14D', '#aa7700'],
      pupilColor: '#442a00',
      borderColor: '#fff088'
    }
  ];

  public readonly arenaThemeCatalog: ArenaThemeConfig[] = [
    {
      id: 'void',
      name: 'Void Vector',
      price: 0,
      description: 'Deep midnight void canvas with classic reactive cyan vector mesh.',
      bgGradient: ['#100c1e', '#090712', '#040308'],
      gridColor: 'rgba(91, 140, 255, 0.18)',
      boundaryColor: 'rgba(91, 140, 255, 0.4)',
      dustColor: '#5B8CFF'
    },
    {
      id: 'synthwave',
      name: 'Synthwave Sunset',
      price: 400,
      description: 'Ultraviolet to magenta gradient with electric hot-pink grid lines.',
      bgGradient: ['#280838', '#140020', '#08000d'],
      gridColor: 'rgba(255, 0, 160, 0.22)',
      boundaryColor: 'rgba(255, 0, 180, 0.5)',
      dustColor: '#ff00aa'
    },
    {
      id: 'nebula',
      name: 'Cosmic Nebula',
      price: 600,
      description: 'Living deep-space expanse with cobalt-purple stars and drifting violet dust.',
      bgGradient: ['#0f1738', '#070b1c', '#02040b'],
      gridColor: 'rgba(130, 90, 255, 0.22)',
      boundaryColor: 'rgba(150, 100, 255, 0.5)',
      dustColor: '#aa77ff'
    },
    {
      id: 'matrix',
      name: 'Matrix Terminal',
      price: 800,
      description: 'Dark circuit-board grid with emerald data pulses and digital matrix ambience.',
      bgGradient: ['#041a0d', '#020d06', '#010502'],
      gridColor: 'rgba(0, 255, 120, 0.22)',
      boundaryColor: 'rgba(0, 255, 120, 0.5)',
      dustColor: '#00ff88'
    },
    {
      id: 'supernova',
      name: 'Supernova Furnace',
      price: 1000,
      description: 'Blazing solar core with incandescent amber-orange heatwave grid lines.',
      bgGradient: ['#2e0c00', '#140500', '#080200'],
      gridColor: 'rgba(255, 130, 0, 0.24)',
      boundaryColor: 'rgba(255, 140, 0, 0.55)',
      dustColor: '#ffaa00'
    },
    {
      id: 'blueprint',
      name: 'Architectural Blueprint',
      price: 1200,
      description: 'Classic CAD drafting technical navy with crisp white coordinate grid lines.',
      bgGradient: ['#0c2848', '#061628', '#020b16'],
      gridColor: 'rgba(255, 255, 255, 0.28)',
      boundaryColor: 'rgba(255, 255, 255, 0.65)',
      dustColor: '#ffffff'
    }
  ];

  constructor() {
    this.data = this.loadData();
  }

  private resolveShipId(id: string): string {
    const map: Record<string, string> = {
      arrow: 'classic',
      viper: 'tactical',
      phantom: 'singularity',
      aegis: 'solar',
      matrix: 'cyber'
    };
    return map[id.toLowerCase()] || id;
  }

  private getDefaultData(): ProgressionData {
    return {
      points: 7331,
      lifetimePoints: 7331,
      perks: {
        blackhole: {
          duration: 3,
          radius: 2,
          gravity: 4,
          invulnerableInside: false,
          supernovaCollapse: false
        },
        nuke: {
          radius: 1,
          speed: 0,
          falloutZone: false
        },
        shield: {
          duration: 0,
          radius: 0,
          batteringRam: false
        },
        missiles: {
          count: 5,
          blastRadius: 0,
          flightSpeed: 0
        },
        laser: {
          length: 2,
          duration: 0,
          crossBeam: false
        },
        lightning: {
          maxTargets: 0,
          chainRange: 0
        },
        freeze: {
          duration: 0,
          shatterCascade: false
        }
      },
      equippedCursorId: 'classic',
      unlockedCursors: ['classic', 'tactical', 'singularity'],
      equippedEnemySkinId: 'classic',
      unlockedEnemySkins: ['classic'],
      equippedArenaThemeId: 'void',
      unlockedArenaThemes: ['void'],
      tuning: {
        sensitivity: 1.0,
        deadzone: 4
      },
      extraLives: 0,
      hullCompact: 0,
      enemySlow: 0,
      scoreMultiplier: 0,
      pointsMultiplier: 0
    };
  }

  public loadData(): ProgressionData {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return this.getDefaultData();
      const parsed = JSON.parse(raw);
      const def = this.getDefaultData();

      // Deep merge with defaults to safeguard new properties
      return {
        ...def,
        ...parsed,
        points: (parsed.points && parsed.points >= 500) ? parsed.points : 7331,
        lifetimePoints: Math.max(parsed.lifetimePoints || 0, 7331),
        perks: {
          ...def.perks,
          ...(parsed.perks || {}),
          blackhole: { ...def.perks.blackhole, ...(parsed.perks?.blackhole || {}) },
          nuke: { ...def.perks.nuke, ...(parsed.perks?.nuke || {}) },
          shield: { ...def.perks.shield, ...(parsed.perks?.shield || {}) },
          missiles: { ...def.perks.missiles, ...(parsed.perks?.missiles || {}) },
          laser: { ...def.perks.laser, ...(parsed.perks?.laser || {}) },
          lightning: { ...def.perks.lightning, ...(parsed.perks?.lightning || {}) },
          freeze: { ...def.perks.freeze, ...(parsed.perks?.freeze || {}) }
        },
        unlockedCursors: Array.from(new Set(['classic', 'tactical', 'singularity', ...(parsed.unlockedCursors || [])])),
        unlockedEnemySkins: Array.from(new Set(['classic', ...(parsed.unlockedEnemySkins || [])])),
        unlockedArenaThemes: Array.from(new Set(['void', ...(parsed.unlockedArenaThemes || [])])),
        tuning: {
          ...def.tuning,
          ...(parsed.tuning || {})
        }
      };
    } catch {
      return this.getDefaultData();
    }
  }

  public save() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.data));
    } catch (e) {
      console.warn('Failed to save progression to localStorage:', e);
    }
  }

  // Points earned during a run pass through here before landing in the
  // player's spendable/lifetime totals, so the points-purchases multiplier
  // is applied once, at this single chokepoint.
  //
  // Decision: lifetimePoints IS multiplied the same as points. lifetimePoints
  // is a running total of everything ever credited via addPoints (it floors
  // the default/reset value and is otherwise additive only) - it is not a
  // separate "raw, unboosted" ledger. Crediting a boosted amount to `points`
  // while recording the unboosted amount to `lifetimePoints` would let the
  // two totals silently diverge and would undercount a stat that's meant to
  // reflect real lifetime earnings (including the multiplier the player paid
  // points to unlock).
  public addPoints(amount: number) {
    this.addPointsCredited(amount);
  }

  /** Banks `amount` (applying the points multiplier) and returns what was actually
   *  credited, so callers can report real earnings rather than the pre-multiplier figure. */
  public addPointsCredited(amount: number): number {
    if (amount <= 0) return 0;
    const credited = Math.floor(amount * this.getPointsMultiplier());
    this.data.points += credited;
    this.data.lifetimePoints += credited;
    this.save();
    return credited;
  }

  // --- Perk Upgrades ---

  public getPerkCost(currentRank: number, isKeystone: boolean = false, keystoneKey?: string): number {
    if (isKeystone) {
      return KEYSTONE_COSTS[keystoneKey || ''] ?? 2500;
    }
    const costs = [300, 600, 1100, 1800, 2800];
    return costs[Math.min(currentRank, costs.length - 1)];
  }

  public getWeaponInvestedPoints(weapon: keyof WeaponPerks): number {
    let total = 0;
    const p = (this.data.perks as any)[weapon];
    if (!p) return 0;
    const costs = [300, 600, 1100, 1800, 2800];
    for (const key of Object.keys(p)) {
      const val = p[key];
      if (typeof val === 'number') {
        for (let r = 0; r < val; r++) {
          total += costs[r] ?? 2800;
        }
      } else if (typeof val === 'boolean' && val) {
        total += this.getPerkCost(0, true, key);
      }
    }
    return total;
  }

  public upgradePerk(weapon: keyof WeaponPerks, perkName: string): boolean {
    const weaponPerks = (this.data.perks as any)[weapon];
    if (!weaponPerks || weaponPerks[perkName] === undefined) return false;

    const val = weaponPerks[perkName];
    if (typeof val === 'boolean') {
      if (val) return false; // Already unlocked
      const cost = this.getPerkCost(0, true, perkName);
      if (this.data.points < cost) return false;
      this.data.points -= cost;
      weaponPerks[perkName] = true;
      this.save();
      return true;
    } else if (typeof val === 'number') {
      if (val >= 5) return false; // Max rank reached
      const cost = this.getPerkCost(val, false);
      if (this.data.points < cost) return false;
      this.data.points -= cost;
      weaponPerks[perkName] += 1;
      this.save();
      return true;
    }
    return false;
  }

  // --- Rank-Based Purchasables ---

  private static readonly EXTRA_LIVES_COSTS = [4000, 9000];
  private static readonly HULL_COMPACT_COSTS = [1500, 3000, 5500];
  private static readonly ENEMY_SLOW_COSTS = [2000, 4200, 7500];
  private static readonly SCORE_MULTIPLIER_COSTS = [1800, 3600, 6500, 11000];
  private static readonly POINTS_MULTIPLIER_COSTS = [2500, 5000, 9000, 15000];

  public getExtraLivesCost(): number | null {
    const rank = this.data.extraLives;
    if (rank >= ProgressionManager.EXTRA_LIVES_COSTS.length) return null;
    return ProgressionManager.EXTRA_LIVES_COSTS[rank];
  }

  public buyExtraLife(): boolean {
    const cost = this.getExtraLivesCost();
    if (cost === null || this.data.points < cost) return false;
    this.data.points -= cost;
    this.data.extraLives += 1;
    this.save();
    return true;
  }

  public getHullCompactCost(): number | null {
    const rank = this.data.hullCompact;
    if (rank >= ProgressionManager.HULL_COMPACT_COSTS.length) return null;
    return ProgressionManager.HULL_COMPACT_COSTS[rank];
  }

  public buyHullCompact(): boolean {
    const cost = this.getHullCompactCost();
    if (cost === null || this.data.points < cost) return false;
    this.data.points -= cost;
    this.data.hullCompact += 1;
    this.save();
    return true;
  }

  public getEnemySlowCost(): number | null {
    const rank = this.data.enemySlow;
    if (rank >= ProgressionManager.ENEMY_SLOW_COSTS.length) return null;
    return ProgressionManager.ENEMY_SLOW_COSTS[rank];
  }

  public buyEnemySlow(): boolean {
    const cost = this.getEnemySlowCost();
    if (cost === null || this.data.points < cost) return false;
    this.data.points -= cost;
    this.data.enemySlow += 1;
    this.save();
    return true;
  }

  public getScoreMultiplierCost(): number | null {
    const rank = this.data.scoreMultiplier;
    if (rank >= ProgressionManager.SCORE_MULTIPLIER_COSTS.length) return null;
    return ProgressionManager.SCORE_MULTIPLIER_COSTS[rank];
  }

  public buyScoreMultiplier(): boolean {
    const cost = this.getScoreMultiplierCost();
    if (cost === null || this.data.points < cost) return false;
    this.data.points -= cost;
    this.data.scoreMultiplier += 1;
    this.save();
    return true;
  }

  public getPointsMultiplierCost(): number | null {
    const rank = this.data.pointsMultiplier;
    if (rank >= ProgressionManager.POINTS_MULTIPLIER_COSTS.length) return null;
    return ProgressionManager.POINTS_MULTIPLIER_COSTS[rank];
  }

  public buyPointsMultiplier(): boolean {
    const cost = this.getPointsMultiplierCost();
    if (cost === null || this.data.points < cost) return false;
    this.data.points -= cost;
    this.data.pointsMultiplier += 1;
    this.save();
    return true;
  }

  // Starting lives = 1 base + extraLives rank + the equipped ship's bonusLives,
  // hard-capped at 3 total.
  public getStartingLives(): number {
    const bonus = this.getEquippedShip().bonusLives || 0;
    return Math.min(3, 1 + this.data.extraLives + bonus);
  }

  public getHitboxMultiplier(): number {
    return 1 - 0.06 * this.data.hullCompact;
  }

  public getEnemySpeedMultiplier(): number {
    return 1 - 0.04 * this.data.enemySlow;
  }

  public getScoreMultiplier(): number {
    return 1 + 0.10 * this.data.scoreMultiplier;
  }

  public getPointsMultiplier(): number {
    return 1 + 0.10 * this.data.pointsMultiplier;
  }

  // --- Ship Models & Fleet Chassis ---

  public buyShip(id: string): boolean {
    const canonical = this.resolveShipId(id);
    if (this.data.unlockedCursors.includes(canonical)) return true;
    const item = this.shipCatalog.find(c => c.id === canonical);
    if (!item || this.data.points < item.price) return false;
    this.data.points -= item.price;
    this.data.unlockedCursors.push(canonical);
    this.data.equippedCursorId = canonical;
    this.save();
    return true;
  }

  public equipShip(id: string): boolean {
    const canonical = this.resolveShipId(id);
    if (!this.data.unlockedCursors.includes(canonical)) return false;
    this.data.equippedCursorId = canonical;
    this.save();
    return true;
  }

  public getEquippedShip(): ShipSkinConfig {
    return this.shipCatalog.find(c => c.id === this.data.equippedCursorId) || this.shipCatalog[0];
  }

  // Backwards compatibility aliases
  public buyCursor(id: string): boolean { return this.buyShip(id); }
  public equipCursor(id: string): boolean { return this.equipShip(id); }
  public getEquippedCursor(): ShipSkinConfig { return this.getEquippedShip(); }

  // --- Enemy Skins ---

  public buyEnemySkin(id: string): boolean {
    if (this.data.unlockedEnemySkins.includes(id)) return true;
    const item = this.enemySkinCatalog.find(e => e.id === id);
    if (!item || this.data.points < item.price) return false;
    this.data.points -= item.price;
    this.data.unlockedEnemySkins.push(id);
    this.data.equippedEnemySkinId = id;
    this.save();
    return true;
  }

  public equipEnemySkin(id: string): boolean {
    if (!this.data.unlockedEnemySkins.includes(id)) return false;
    this.data.equippedEnemySkinId = id;
    this.save();
    return true;
  }

  public getEquippedEnemySkin(): EnemySkinConfig {
    return this.enemySkinCatalog.find(e => e.id === this.data.equippedEnemySkinId) || this.enemySkinCatalog[0];
  }

  // --- Arena Themes ---

  public buyArenaTheme(id: string): boolean {
    if (this.data.unlockedArenaThemes.includes(id)) return true;
    const item = this.arenaThemeCatalog.find(a => a.id === id);
    if (!item || this.data.points < item.price) return false;
    this.data.points -= item.price;
    this.data.unlockedArenaThemes.push(id);
    this.data.equippedArenaThemeId = id;
    this.save();
    return true;
  }

  public equipArenaTheme(id: string): boolean {
    if (!this.data.unlockedArenaThemes.includes(id)) return false;
    this.data.equippedArenaThemeId = id;
    this.save();
    return true;
  }

  public getEquippedArenaTheme(): ArenaThemeConfig {
    return this.arenaThemeCatalog.find(a => a.id === this.data.equippedArenaThemeId) || this.arenaThemeCatalog[0];
  }

  // --- Tuning Controls ---

  public setSensitivity(value: number) {
    this.data.tuning.sensitivity = Math.max(0.5, Math.min(2.0, value));
    this.save();
  }

  public setDeadzone(value: number) {
    this.data.tuning.deadzone = Math.max(0, Math.min(16, value));
    this.save();
  }

  public getCursorSvgDataUri(skinId: string = this.data.equippedCursorId): string {
    const skin = this.cursorCatalog.find(c => c.id === skinId) || this.cursorCatalog[0];
    const pri = encodeURIComponent(skin.primaryColor);
    const acc = encodeURIComponent(skin.accentColor);

    let svgContent = '';
    switch (skin.id) {
      case 'tactical':
        svgContent = `<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>
          <rect x='7' y='7' width='18' height='18' fill='none' stroke='${acc}' stroke-width='1.2' stroke-dasharray='4,3'/>
          <line x1='16' y1='2' x2='16' y2='10' stroke='${pri}' stroke-width='2'/>
          <line x1='16' y1='22' x2='16' y2='30' stroke='${pri}' stroke-width='2'/>
          <line x1='2' y1='16' x2='10' y2='16' stroke='${pri}' stroke-width='2'/>
          <line x1='22' y1='16' x2='30' y2='16' stroke='${pri}' stroke-width='2'/>
          <circle cx='16' cy='16' r='2.5' fill='white'/>
        </svg>`;
        break;
      case 'singularity':
        svgContent = `<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>
          <circle cx='16' cy='16' r='10' fill='none' stroke='${pri}' stroke-width='2' stroke-dasharray='10,4'/>
          <circle cx='16' cy='6' r='2' fill='${acc}'/>
          <circle cx='24' cy='22' r='2' fill='${acc}'/>
          <circle cx='8' cy='22' r='2' fill='${acc}'/>
          <circle cx='16' cy='16' r='4' fill='#080010'/>
        </svg>`;
        break;
      case 'solar':
        svgContent = `<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>
          <circle cx='16' cy='16' r='6' fill='${acc}' stroke='${pri}' stroke-width='1.5'/>
          <line x1='16' y1='2' x2='16' y2='7' stroke='${pri}' stroke-width='2'/>
          <line x1='16' y1='25' x2='16' y2='30' stroke='${pri}' stroke-width='2'/>
          <line x1='2' y1='16' x2='7' y2='16' stroke='${pri}' stroke-width='2'/>
          <line x1='25' y1='16' x2='30' y2='16' stroke='${pri}' stroke-width='2'/>
          <line x1='6' y1='6' x2='10' y2='10' stroke='${pri}' stroke-width='1.5'/>
          <line x1='22' y1='22' x2='26' y2='26' stroke='${pri}' stroke-width='1.5'/>
          <line x1='6' y1='26' x2='10' y2='22' stroke='${pri}' stroke-width='1.5'/>
          <line x1='22' y1='10' x2='26' y2='6' stroke='${pri}' stroke-width='1.5'/>
        </svg>`;
        break;
      case 'cyber':
        svgContent = `<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>
          <polygon points='16,5 26,10.5 26,21.5 16,27 6,21.5 6,10.5' fill='none' stroke='${pri}' stroke-width='1.8'/>
          <rect x='13' y='13' width='6' height='6' fill='${acc}' stroke='white' stroke-width='1'/>
        </svg>`;
        break;
      case 'shuriken':
        svgContent = `<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>
          <polygon points='16,4 19,13 28,16 19,19 16,28 13,19 4,16 13,13' fill='${pri}' stroke='${acc}' stroke-width='1'/>
          <circle cx='16' cy='16' r='3' fill='white'/>
        </svg>`;
        break;
      case 'celestial':
        svgContent = `<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>
          <circle cx='16' cy='16' r='11' fill='none' stroke='${pri}' stroke-width='1.8'/>
          <circle cx='16' cy='16' r='6' fill='none' stroke='${acc}' stroke-width='1.4' stroke-dasharray='4,2'/>
          <circle cx='16' cy='16' r='2' fill='white'/>
        </svg>`;
        break;
      default:
        // Classic cyan ring with center dot
        svgContent = `<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>
          <circle cx='16' cy='16' r='9' fill='none' stroke='${pri}' stroke-width='2'/>
          <circle cx='16' cy='16' r='3' fill='${acc}'/>
        </svg>`;
        break;
    }

    const encoded = svgContent.replace(/\s+/g, ' ').trim();
    return `data:image/svg+xml;utf8,${encoded}`;
  }

  public getShipSvgPreview(shipId: string = this.data.equippedCursorId): string {
    switch (shipId) {
      case 'tactical':
        return `<svg class='ship-preview-svg ship-hull-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <polygon points='25,50 28,60 31,50' fill='#ff5500' opacity='0.85'/>
          <polygon points='33,50 36,60 39,50' fill='#ff5500' opacity='0.85'/>
          <polygon points='25.6,25.6 17.6,30.4 25.6,33.6' fill='#ff2a4b'/>
          <polygon points='38.4,25.6 46.4,30.4 38.4,33.6' fill='#ff2a4b'/>
          <polygon points='32,3.2 24,28.8 9.6,48 14.4,52.8 25.6,44.8 22.4,54.4 41.6,54.4 38.4,44.8 49.6,52.8 54.4,48 40,28.8' fill='#161924' stroke='#ff2a4b' stroke-width='2.2' stroke-linejoin='round'/>
          <circle cx='9.6' cy='48' r='3.2' fill='#ff2a4b'/>
          <circle cx='54.4' cy='48' r='3.2' fill='#ff2a4b'/>
          <polygon points='32,19.2 28,35.2 32,40 36,35.2' fill='#ff6680'/>
        </svg>`;

      case 'singularity':
        return `<svg class='ship-preview-svg ship-hull-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <polygon points='28,48 32,58 36,48' fill='#9933ff' opacity='0.9'/>
          <polygon points='32,3.1 11.6,28.6 16.7,55.8 32,42.2 47.3,55.8 52.4,28.6' fill='#160826' stroke='#b84dff' stroke-width='2.2' stroke-linejoin='round'/>
          <line x1='32' y1='3.1' x2='32' y2='42.2' stroke='#d88dff' stroke-width='1.2'/>
          <polygon points='32,25.2 25.9,35.4 32,42.2 38.1,35.4' fill='#e099ff'/>
        </svg>`;

      case 'solar':
        return `<svg class='ship-preview-svg ship-hull-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <polygon points='22,50 25,58 28,50' fill='#ffaa00' opacity='0.85'/>
          <polygon points='30,48 32,58 34,48' fill='#ffffff' opacity='0.95'/>
          <polygon points='36,50 39,58 42,50' fill='#ffaa00' opacity='0.85'/>
          <polygon points='26.6,3.2 37.4,3.2 48.2,24.8 48.2,39.2 57.2,53.6 53.6,57.2 41,50 32,55.4 23,50 10.4,57.2 6.8,53.6 15.8,39.2 15.8,24.8' fill='#ffd700' stroke='#ff8800' stroke-width='2.2' stroke-linejoin='round'/>
          <rect x='19.4' y='28.4' width='5.4' height='7.2' fill='#aa7700'/>
          <rect x='39.2' y='28.4' width='5.4' height='7.2' fill='#aa7700'/>
          <polygon points='32,21.2 27.5,35.6 32,39.2 36.5,35.6' fill='#ffffff'/>
        </svg>`;

      case 'cyber':
        return `<svg class='ship-preview-svg ship-hull-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <polygon points='22,50 25,59 28,50' fill='#ff00aa' opacity='0.9'/>
          <polygon points='36,50 39,59 42,50' fill='#00ffff' opacity='0.9'/>
          <polyline points='9.25,35.5 5.75,46 12.75,53' fill='none' stroke='#00ffff' stroke-width='1.8'/>
          <polyline points='54.75,35.5 58.25,46 51.25,53' fill='none' stroke='#ff00aa' stroke-width='1.8'/>
          <polygon points='32,4 21.5,18 16.25,46 23.25,54.75 32,46 40.75,54.75 47.75,46 42.5,18' fill='#0a1220' stroke='#00ffff' stroke-width='2' stroke-linejoin='round'/>
          <rect x='26.75' y='25' width='10.5' height='10.5' fill='none' stroke='#ff00aa' stroke-width='1.5'/>
          <circle cx='32' cy='30.25' r='3.85' fill='#00ffcc'/>
        </svg>`;

      case 'shuriken':
        return `<svg class='ship-preview-svg ship-hull-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <path d='M 32,3.1 Q 40.5,18.4 35.4,28.6 L 59.2,32 Q 45.6,40.5 35.4,35.4 L 32,57.5 Q 23.5,45.6 28.6,35.4 L 4.8,32 Q 18.4,23.5 28.6,28.6 Z' fill='#082014' stroke='#00ff99' stroke-width='1.8' stroke-linejoin='round'/>
          <rect x='26.9' y='26.9' width='10.2' height='10.2' fill='none' stroke='#88ffcc' stroke-width='1.4'/>
          <circle cx='32' cy='32' r='4.25' fill='#00ffaa'/>
        </svg>`;

      case 'celestial':
        return `<svg class='ship-preview-svg ship-hull-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <ellipse cx='32' cy='43.2' rx='22.4' ry='8' fill='none' stroke='#ffd700' stroke-width='1.6' stroke-dasharray='6,3'/>
          <polygon points='30,48 32,60 34,48' fill='#ffffff' opacity='0.95'/>
          <path d='M 32,3.2 Q 19.2,25.6 12.8,51.2 Q 32,44.8 32,41.6 Q 32,44.8 51.2,51.2 Q 44.8,25.6 32,3.2 Z' fill='#f8fafc' stroke='#ffd700' stroke-width='1.8' stroke-linejoin='round'/>
          <polygon points='32,22.4 27.2,33.6 32,36.8 36.8,33.6' fill='#38bdf8'/>
        </svg>`;

      default:
        return `<svg class='ship-preview-svg ship-hull-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <polygon points='26,50 32,59 38,50' fill='#00ddff' opacity='0.85'/>
          <polygon points='32,3.5 14.9,54.8 32,45.3 49.1,54.8' fill='#ffffff' stroke='#00ddff' stroke-width='2.2' stroke-linejoin='round'/>
          <polygon points='32,22.5 26.3,39.6 32,35.8 37.7,39.6' fill='#00ffee'/>
        </svg>`;
    }
  }
}
