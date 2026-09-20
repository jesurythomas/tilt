// =========================================================================
// ProgressionManager.ts - Perks, Custom Cursors, Enemy Skins, Arenas & Economy
// =========================================================================

export interface WeaponPerks {
  blackhole: {
    duration: number; // 0..5 (+0.5s per rank)
    radius: number; // 0..5 (+35px per rank)
    gravity: number; // 0..5 (+20% pull force per rank)
    invulnerableInside: boolean; // Keystone: player is invulnerable while inside blackhole
    supernovaCollapse: boolean; // Keystone: collapse shockwave reaches 400px
  };
  nuke: {
    radius: number; // 0..5 (+40px per rank)
    speed: number; // 0..3 (+25% blast expansion speed)
    falloutZone: boolean; // Keystone: lingering radiation for 3s
  };
  shield: {
    duration: number; // 0..5 (+1.0s per rank)
    radius: number; // 0..3 (+4px per rank)
    batteringRam: boolean; // Keystone: ramming explodes adjacent dots
  };
  missiles: {
    count: number; // 0..5 (+1 missile per rank, 8 -> 13)
    blastRadius: number; // 0..3 (+12px per rank)
    flightSpeed: number; // 0..3 (+20% speed & turn rate)
  };
  laser: {
    length: number; // 0..5 (+35px per rank)
    duration: number; // 0..3 (+0.4s per rank)
    crossBeam: boolean; // Keystone: 4-way perpendicular cross laser
  };
  lightning: {
    maxTargets: number; // 0..5 (+3 targets per rank)
    chainRange: number; // 0..3 (+40px range)
  };
  freeze: {
    duration: number; // 0..5 (+0.7s per rank)
    shatterCascade: boolean; // Keystone: ramming a frozen dot shatters neighbors
  };
}

export interface ShipSkinConfig {
  id: string;
  name: string;
  price: number;
  /** Short trait line shown on the Armory card (max 4 words). */
  description: string;
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
  /** Short trait line shown on the Armory tile (max 4 words). */
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
  /** Short trait line shown on the Armory tile (max 4 words). */
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
}

const STORAGE_KEY = 'tilt_to_live_progression_v3';

export class ProgressionManager {
  public data: ProgressionData;

  public readonly shipCatalog: ShipSkinConfig[] = [
    {
      id: 'classic',
      name: 'Arrow',
      price: 0,
      description: 'Balanced',
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
      price: 2,
      description: 'Aggressive',
      hullColor: '#161924',
      primaryColor: '#ff2a4b',
      accentColor: '#ff6680',
      thrusterColor: '#ff5500',
      trailColor: 'rgba(255, 42, 75, 0.4)',
      tetherColor: 'rgba(255, 42, 75, 0.35)',
      shape: 'viper'
    },
    {
      id: 'singularity',
      name: 'Phantom',
      price: 4,
      description: 'Evasive',
      hullColor: '#160826',
      primaryColor: '#b84dff',
      accentColor: '#e099ff',
      thrusterColor: '#9933ff',
      trailColor: 'rgba(184, 77, 255, 0.4)',
      tetherColor: 'rgba(184, 77, 255, 0.35)',
      shape: 'phantom'
    },
    {
      id: 'solar',
      name: 'Aegis',
      price: 6,
      description: 'Heavy',
      hullColor: '#FFB14D',
      primaryColor: '#ff8800',
      accentColor: '#ffffff',
      thrusterColor: '#ffaa00',
      trailColor: 'rgba(255, 170, 0, 0.4)',
      tetherColor: 'rgba(255, 170, 0, 0.35)',
      shape: 'solar'
    },
    {
      id: 'cyber',
      name: 'Matrix',
      price: 8,
      description: 'Fast cooldown',
      hullColor: '#0a1220',
      primaryColor: '#00ffff',
      accentColor: '#ff00aa',
      thrusterColor: '#ff00aa',
      trailColor: 'rgba(0, 255, 255, 0.4)',
      tetherColor: 'rgba(255, 0, 170, 0.32)',
      shape: 'cyber'
    },
    {
      id: 'shuriken',
      name: 'Shuriken',
      price: 10,
      description: 'Spin drift',
      hullColor: '#082014',
      primaryColor: '#00ff99',
      accentColor: '#88ffcc',
      thrusterColor: '#3DDC97',
      trailColor: 'rgba(0, 255, 153, 0.4)',
      tetherColor: 'rgba(0, 255, 153, 0.35)',
      shape: 'shuriken'
    },
    {
      id: 'celestial',
      name: 'Sovereign',
      price: 12,
      description: 'Radiant',
      hullColor: '#f8fafc',
      primaryColor: '#FFB14D',
      accentColor: '#38bdf8',
      thrusterColor: '#ffffff',
      trailColor: 'rgba(255, 177, 77, 0.4)',
      tetherColor: 'rgba(255, 177, 77, 0.4)',
      shape: 'celestial'
    }
  ];

  public readonly cursorCatalog: ShipSkinConfig[] = this.shipCatalog;

  public readonly enemySkinCatalog: EnemySkinConfig[] = [
    {
      id: 'classic',
      name: 'Crimson',
      price: 0,
      description: 'The original red',
      glowColor: 'rgba(255, 30, 60, 0.35)',
      bodyGradient: ['#ff6677', '#ee1133', '#990011'],
      pupilColor: '#110005',
      borderColor: '#ff8899'
    },
    {
      id: 'toxic',
      name: 'Toxic',
      price: 2,
      description: 'Caustic green cells',
      glowColor: 'rgba(0, 255, 100, 0.35)',
      bodyGradient: ['#88ff99', '#11ee44', '#007722'],
      pupilColor: '#021805',
      borderColor: '#aaffbb'
    },
    {
      id: 'glitch',
      name: 'Glitch',
      price: 4,
      description: 'Flickering wireframe',
      glowColor: 'rgba(0, 240, 255, 0.4)',
      bodyGradient: ['#88ffff', '#00bfff', '#0044aa'],
      pupilColor: '#ff0077',
      borderColor: '#00ffff'
    },
    {
      id: 'magma',
      name: 'Magma',
      price: 6,
      description: 'Cracked molten rock',
      glowColor: 'rgba(255, 120, 0, 0.4)',
      bodyGradient: ['#ffcc00', '#ff5500', '#881100'],
      pupilColor: '#2b0800',
      borderColor: '#ffaa33'
    },
    {
      id: 'void',
      name: 'Void',
      price: 8,
      description: 'Violet event horizon',
      glowColor: 'rgba(180, 50, 255, 0.45)',
      bodyGradient: ['#9944ff', '#330066', '#080014'],
      pupilColor: '#ffffff',
      borderColor: '#cc88ff'
    },
    {
      id: 'gold',
      name: 'Gold',
      price: 12,
      description: 'Polished metal',
      glowColor: 'rgba(255, 177, 77, 0.45)',
      bodyGradient: ['#fff6b3', '#FFB14D', '#aa7700'],
      pupilColor: '#442a00',
      borderColor: '#fff088'
    }
  ];

  public readonly arenaThemeCatalog: ArenaThemeConfig[] = [
    // Arena chrome sits on the --arena ground (#0D1016) and falls off to --void.
    // Boundaries are a quiet edge, never a neon tube, and hazard red is reserved
    // for the enemies: no theme may use it.
    {
      id: 'void',
      name: 'Void',
      price: 0,
      description: 'Ion mesh on black',
      bgGradient: ['#0D1016', '#0A0D13', '#08090E'],
      gridColor: 'rgba(91, 140, 255, 0.14)',
      boundaryColor: 'rgba(91, 140, 255, 0.38)',
      dustColor: '#5B8CFF'
    },
    {
      id: 'synthwave',
      name: 'Synthwave',
      price: 4,
      description: 'Magenta grid',
      bgGradient: ['#170B1C', '#0F0714', '#08090E'],
      gridColor: 'rgba(236, 72, 200, 0.15)',
      boundaryColor: 'rgba(236, 72, 200, 0.40)',
      dustColor: '#EC48C8'
    },
    {
      id: 'nebula',
      name: 'Nebula',
      price: 6,
      description: 'Drifting violet dust',
      bgGradient: ['#12101F', '#0C0A16', '#08090E'],
      gridColor: 'rgba(167, 139, 250, 0.16)',
      boundaryColor: 'rgba(167, 139, 250, 0.40)',
      dustColor: '#A78BFA'
    },
    {
      id: 'matrix',
      name: 'Matrix',
      price: 8,
      description: 'Emerald circuit grid',
      bgGradient: ['#0A1714', '#07100D', '#08090E'],
      gridColor: 'rgba(61, 220, 151, 0.16)',
      boundaryColor: 'rgba(61, 220, 151, 0.40)',
      dustColor: '#3DDC97'
    },
    {
      id: 'supernova',
      name: 'Supernova',
      price: 10,
      description: 'Amber heat lines',
      bgGradient: ['#17120B', '#0E0B08', '#08090E'],
      gridColor: 'rgba(255, 177, 77, 0.16)',
      boundaryColor: 'rgba(255, 177, 77, 0.42)',
      dustColor: '#FFB14D'
    },
    {
      id: 'blueprint',
      name: 'Blueprint',
      price: 12,
      description: 'White grid on navy',
      bgGradient: ['#0E1626', '#0A101B', '#08090E'],
      gridColor: 'rgba(230, 233, 240, 0.18)',
      boundaryColor: 'rgba(230, 233, 240, 0.45)',
      dustColor: '#E6E9F0'
    }
  ];

  constructor() {
    this.data = this.loadData();
  }

  private getDefaultData(): ProgressionData {
    return {
      points: 2, // Starter points from milestone economy
      lifetimePoints: 2,
      perks: {
        blackhole: {
          duration: 0,
          radius: 0,
          gravity: 0,
          invulnerableInside: false,
          supernovaCollapse: false
        },
        nuke: {
          radius: 0,
          speed: 0,
          falloutZone: false
        },
        shield: {
          duration: 0,
          radius: 0,
          batteringRam: false
        },
        missiles: {
          count: 0,
          blastRadius: 0,
          flightSpeed: 0
        },
        laser: {
          length: 0,
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
      unlockedCursors: ['classic'],
      equippedEnemySkinId: 'classic',
      unlockedEnemySkins: ['classic'],
      equippedArenaThemeId: 'void',
      unlockedArenaThemes: ['void'],
      tuning: {
        sensitivity: 1.0,
        deadzone: 4
      }
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
        unlockedCursors: Array.from(new Set(['classic', ...(parsed.unlockedCursors || [])])),
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

  public addPoints(amount: number) {
    if (amount <= 0) return;
    this.data.points += Math.floor(amount);
    this.data.lifetimePoints += Math.floor(amount);
    this.save();
  }

  // --- Perk Upgrades ---

  public getPerkCost(currentRank: number, isKeystone: boolean = false): number {
    if (isKeystone) return 4;
    // Costs in Milestone Points: Rank 0->1: 1, 1->2: 2, 2->3: 3, 3->4: 4, 4->5: 5
    const costs = [1, 2, 3, 4, 5];
    return costs[Math.min(currentRank, costs.length - 1)];
  }

  public upgradePerk(weapon: keyof WeaponPerks, perkName: string): boolean {
    const weaponPerks = (this.data.perks as any)[weapon];
    if (!weaponPerks || weaponPerks[perkName] === undefined) return false;

    const val = weaponPerks[perkName];
    if (typeof val === 'boolean') {
      if (val) return false; // Already unlocked
      const cost = this.getPerkCost(0, true);
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

  // --- Ship Models & Fleet Chassis ---

  public buyShip(id: string): boolean {
    if (this.data.unlockedCursors.includes(id)) return true;
    const item = this.shipCatalog.find(c => c.id === id);
    if (!item || this.data.points < item.price) return false;
    this.data.points -= item.price;
    this.data.unlockedCursors.push(id);
    this.data.equippedCursorId = id;
    this.save();
    return true;
  }

  public equipShip(id: string): boolean {
    if (!this.data.unlockedCursors.includes(id)) return false;
    this.data.equippedCursorId = id;
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
        return `<svg class='ship-preview-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <polygon points='25,50 28,60 31,50' fill='#ff5500' opacity='0.85'/>
          <polygon points='33,50 36,60 39,50' fill='#ff5500' opacity='0.85'/>
          <polygon points='32,6 38,20 54,46 44,50 38,44 32,46 26,44 20,50 10,46 26,20' fill='#161924' stroke='#ff2a4b' stroke-width='2.2' stroke-linejoin='round'/>
          <polygon points='26,22 18,26 26,28' fill='#ff2a4b'/>
          <polygon points='38,22 46,26 38,28' fill='#ff2a4b'/>
          <circle cx='10' cy='46' r='2.5' fill='#ff2a4b'/>
          <circle cx='54' cy='46' r='2.5' fill='#ff2a4b'/>
          <polygon points='32,16 29,28 32,26 35,28' fill='#ff6680'/>
        </svg>`;

      case 'singularity':
        return `<svg class='ship-preview-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <circle cx='32' cy='32' r='20' fill='none' stroke='#b84dff' stroke-width='1.2' stroke-dasharray='4,4' opacity='0.6'/>
          <polygon points='28,48 32,58 36,48' fill='#9933ff' opacity='0.9'/>
          <polygon points='32,8 50,26 44,50 32,42 20,50 14,26' fill='#160826' stroke='#b84dff' stroke-width='2.2' stroke-linejoin='round'/>
          <line x1='32' y1='8' x2='32' y2='42' stroke='#d88dff' stroke-width='1.2'/>
          <polygon points='32,20 27,28 32,36 37,28' fill='#e099ff'/>
        </svg>`;

      case 'solar':
        return `<svg class='ship-preview-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <polygon points='22,50 25,58 28,50' fill='#ffaa00' opacity='0.85'/>
          <polygon points='30,48 32,58 34,48' fill='#ffffff' opacity='0.95'/>
          <polygon points='36,50 39,58 42,50' fill='#ffaa00' opacity='0.85'/>
          <polygon points='30,8 34,8 44,20 54,46 44,50 36,44 28,44 20,50 10,46 20,20' fill='#FFB14D' stroke='#ff8800' stroke-width='2.2' stroke-linejoin='round'/>
          <polygon points='22,24 16,38 24,36' fill='#aa7700'/>
          <polygon points='42,24 48,38 40,36' fill='#aa7700'/>
          <polygon points='32,14 29,24 32,22 35,24' fill='#ffffff'/>
        </svg>`;

      case 'cyber':
        return `<svg class='ship-preview-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <polygon points='22,50 25,59 28,50' fill='#ff00aa' opacity='0.9'/>
          <polygon points='36,50 39,59 42,50' fill='#00ffff' opacity='0.9'/>
          <polygon points='12,32 8,48 20,46' fill='none' stroke='#00ffff' stroke-width='1.8'/>
          <polygon points='52,32 56,48 44,46' fill='none' stroke='#ff00aa' stroke-width='1.8'/>
          <polygon points='32,10 40,18 38,48 32,44 26,48 24,18' fill='#0a1220' stroke='#00ffff' stroke-width='2' stroke-linejoin='round'/>
          <polygon points='32,18 36,24 36,32 32,36 28,32 28,24' fill='none' stroke='#ff00aa' stroke-width='1.5'/>
          <circle cx='32' cy='27' r='3' fill='#3DDC97'/>
        </svg>`;

      case 'shuriken':
        return `<svg class='ship-preview-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <circle cx='32' cy='32' r='20' fill='none' stroke='#00ff99' stroke-width='1.2' stroke-dasharray='5,3' opacity='0.6'/>
          <path d='M 32,8 C 36,18 48,18 56,32 C 46,36 46,48 32,56 C 28,46 16,46 8,32 C 18,28 18,16 32,8 Z' fill='#082014' stroke='#00ff99' stroke-width='2.2' stroke-linejoin='round'/>
          <polygon points='32,16 40,28 32,40 24,28' fill='none' stroke='#88ffcc' stroke-width='1.4'/>
          <circle cx='32' cy='28' r='3.5' fill='#3DDC97'/>
        </svg>`;

      case 'celestial':
        return `<svg class='ship-preview-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <ellipse cx='32' cy='42' rx='18' ry='7' fill='none' stroke='#FFB14D' stroke-width='2' stroke-dasharray='6,3'/>
          <polygon points='30,48 32,60 34,48' fill='#ffffff' opacity='0.95'/>
          <path d='M 32,8 Q 44,26 52,46 Q 38,44 32,40 Q 26,44 12,46 Q 20,26 32,8 Z' fill='#f8fafc' stroke='#FFB14D' stroke-width='2.2' stroke-linejoin='round'/>
          <polygon points='32,18 29,28 32,32 35,28' fill='#38bdf8'/>
        </svg>`;

      default:
        return `<svg class='ship-preview-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <polygon points='26,50 32,59 38,50' fill='#5B8CFF' opacity='0.85'/>
          <polygon points='32,10 16,48 32,40 48,48' fill='#ffffff' stroke='#5B8CFF' stroke-width='2.2' stroke-linejoin='round'/>
          <polygon points='32,24 28,34 32,32 36,34' fill='#8FB0FF'/>
        </svg>`;
    }
  }
}
