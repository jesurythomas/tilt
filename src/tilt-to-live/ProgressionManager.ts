// =========================================================================
// ProgressionManager.ts - Perks, Custom Cursors, Enemy Skins, Arenas & Economy
// =========================================================================

export interface WeaponPerks {
  blackhole: {
    duration: number; // 0..5 (+0.5s per rank)
    radius: number; // 0..5 (+35px per rank)
    gravity: number; // 0..5 (+20% pull force per rank)
    invulnerableInside: boolean; // Keystone: player is invulnerable while inside blackhole!
    supernovaCollapse: boolean; // Keystone: collapse shockwave reaches 400px!
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
    crossBeam: boolean; // Keystone: 4-way perpendicular cross laser!
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
  trait: string;
  price: number;
  description: string;
  hitbox: string;
  turn: string;
  hitboxScale: number;
  turnRate: number;
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
}

const STORAGE_KEY = 'tilt_to_live_progression_v3';

export class ProgressionManager {
  public data: ProgressionData;

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
      hitbox: '58%',
      turn: '78%',
      hitboxScale: 1.16,
      turnRate: 1.30,
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
      hitbox: '28%',
      turn: '52%',
      hitboxScale: 0.56,
      turnRate: 0.87,
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
      hitbox: '84%',
      turn: '34%',
      hitboxScale: 1.68,
      turnRate: 0.57,
      tint: '#FFB14D',
      svgPath: 'M24 7 L39 17 V33 L24 41 L9 33 V17 Z',
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
      hitbox: '54%',
      turn: '70%',
      hitboxScale: 1.08,
      turnRate: 1.17,
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
      hitbox: '46%',
      turn: '92%',
      hitboxScale: 0.92,
      turnRate: 1.53,
      tint: '#8FB0FF',
      svgPath: 'M24 6 L30 18 L42 24 L30 30 L24 42 L18 30 L6 24 L18 18 Z',
      hullColor: '#082014',
      primaryColor: '#8FB0FF',
      accentColor: '#88ffcc',
      thrusterColor: '#5b8cff',
      trailColor: 'rgba(143, 176, 255, 0.4)',
      tetherColor: 'rgba(143, 176, 255, 0.35)',
      shape: 'shuriken'
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
      glowColor: 'rgba(0, 240, 255, 0.4)',
      bodyGradient: ['#88ffff', '#00bfff', '#0044aa'],
      pupilColor: '#ff0077',
      borderColor: '#00ffff'
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
      bodyGradient: ['#fff6b3', '#ffd700', '#aa7700'],
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
      gridColor: 'rgba(0, 220, 255, 0.18)',
      boundaryColor: 'rgba(0, 220, 255, 0.4)',
      dustColor: '#00ddff'
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

  public addPoints(amount: number) {
    if (amount <= 0) return;
    this.data.points += Math.floor(amount);
    this.data.lifetimePoints += Math.floor(amount);
    this.save();
  }

  // --- Perk Upgrades ---

  public getPerkCost(currentRank: number, isKeystone: boolean = false, keystoneKey?: string): number {
    if (isKeystone) {
      if (keystoneKey === 'supernovaCollapse' || keystoneKey === 'chainReaction') return 5000;
      return 2500;
    }
    const costs = [200, 300, 400, 500, 600];
    return costs[Math.min(currentRank, costs.length - 1)];
  }

  public getWeaponInvestedPoints(weapon: keyof WeaponPerks): number {
    let total = 0;
    const p = (this.data.perks as any)[weapon];
    if (!p) return 0;
    const costs = [200, 300, 400, 500, 600];
    for (const key of Object.keys(p)) {
      const val = p[key];
      if (typeof val === 'number') {
        for (let r = 0; r < val; r++) {
          total += costs[r] ?? 600;
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
          <polygon points='30,8 34,8 44,20 54,46 44,50 36,44 28,44 20,50 10,46 20,20' fill='#ffd700' stroke='#ff8800' stroke-width='2.2' stroke-linejoin='round'/>
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
          <circle cx='32' cy='27' r='3' fill='#00ffcc'/>
        </svg>`;

      case 'shuriken':
        return `<svg class='ship-preview-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <circle cx='32' cy='32' r='20' fill='none' stroke='#00ff99' stroke-width='1.2' stroke-dasharray='5,3' opacity='0.6'/>
          <path d='M 32,8 C 36,18 48,18 56,32 C 46,36 46,48 32,56 C 28,46 16,46 8,32 C 18,28 18,16 32,8 Z' fill='#082014' stroke='#00ff99' stroke-width='2.2' stroke-linejoin='round'/>
          <polygon points='32,16 40,28 32,40 24,28' fill='none' stroke='#88ffcc' stroke-width='1.4'/>
          <circle cx='32' cy='28' r='3.5' fill='#00ffaa'/>
        </svg>`;

      case 'celestial':
        return `<svg class='ship-preview-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <ellipse cx='32' cy='42' rx='18' ry='7' fill='none' stroke='#ffd700' stroke-width='2' stroke-dasharray='6,3'/>
          <polygon points='30,48 32,60 34,48' fill='#ffffff' opacity='0.95'/>
          <path d='M 32,8 Q 44,26 52,46 Q 38,44 32,40 Q 26,44 12,46 Q 20,26 32,8 Z' fill='#f8fafc' stroke='#ffd700' stroke-width='2.2' stroke-linejoin='round'/>
          <polygon points='32,18 29,28 32,32 35,28' fill='#38bdf8'/>
        </svg>`;

      default:
        return `<svg class='ship-preview-svg' xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
          <polygon points='26,50 32,59 38,50' fill='#00ddff' opacity='0.85'/>
          <polygon points='32,10 16,48 32,40 48,48' fill='#ffffff' stroke='#00ddff' stroke-width='2.2' stroke-linejoin='round'/>
          <polygon points='32,24 28,34 32,32 36,34' fill='#00ffee'/>
        </svg>`;
    }
  }
}
