// =========================================================================
// GameOptions.ts - Mode Selection, Audio, Controls & Visual Settings
// =========================================================================

export type GameMode = 'classic' | 'code-red' | 'gauntlet';

export interface ModeConfig {
  id: GameMode;
  name: string;
  badge: string;
  tagline: string;
  description: string;
  color: string;
  accent: string;
  glow: string;
  scoreMultiplier: number;
}

export interface GameSettings {
  mode: GameMode;
  controlScheme: 'hybrid' | 'mouse' | 'keyboard' | 'gyro';
  sfxEnabled: boolean;
  sfxVolume: number; // 0..1
  musicEnabled: boolean;
  musicVolume: number; // 0..1
  screenShake: 'off' | 'low' | 'normal' | 'extreme';
  tetherLine: boolean;
  highContrastHalo: boolean;
  showGridlines: boolean;
}

const STORAGE_KEY = 'tilt_to_live_settings_v1';

export class GameOptionsManager {
  public settings: GameSettings;

  public readonly modes: ModeConfig[] = [
    {
      id: 'classic',
      name: 'Classic Survival',
      badge: 'STANDARD',
      tagline: 'The Definitive Arcade Arena',
      description: 'Dodge escalating swarms, detonate superweapons, chain multipliers, and survive as long as humanly possible.',
      color: '#00ddff',
      accent: '#00ffee',
      glow: 'rgba(0, 220, 255, 0.4)',
      scoreMultiplier: 1.0
    },
    {
      id: 'code-red',
      name: 'Code Red',
      badge: 'HARDCORE',
      tagline: 'Instant Hyper-Lethal Swarms',
      description: '2x initial swarm density, faster seeker dots, relentless arrow ambushes, and immediate circle encirclements. High risk, high multiplier.',
      color: '#ff2a4b',
      accent: '#ff6680',
      glow: 'rgba(255, 42, 75, 0.45)',
      scoreMultiplier: 1.5
    },
    {
      id: 'gauntlet',
      name: 'The Gauntlet',
      badge: 'MAZE RUN',
      tagline: 'Descending Maze & Survival Rush',
      description: 'Navigate descending wall barriers through moving gaps while evading normal enemy swarms. Walls push and block; speed accelerates as your survival score climbs!',
      color: '#ffaa00',
      accent: '#ffd277',
      glow: 'rgba(255, 170, 0, 0.45)',
      scoreMultiplier: 1.25
    }
  ];

  constructor() {
    this.settings = this.loadSettings();
  }

  private getDefaultSettings(): GameSettings {
    return {
      mode: 'classic',
      controlScheme: 'hybrid',
      sfxEnabled: true,
      sfxVolume: 0.8,
      musicEnabled: true,
      musicVolume: 0.7,
      screenShake: 'normal',
      tetherLine: true,
      highContrastHalo: true,
      showGridlines: false
    };
  }

  public loadSettings(): GameSettings {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return this.getDefaultSettings();
      const parsed = JSON.parse(raw);
      return {
        ...this.getDefaultSettings(),
        ...parsed,
        showGridlines: parsed.showGridlines === true
      };
    } catch {
      return this.getDefaultSettings();
    }
  }

  public save() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.settings));
    } catch {}
  }

  public getModeConfig(mode: GameMode = this.settings.mode): ModeConfig {
    return this.modes.find((m) => m.id === mode) || this.modes[0];
  }

  public setMode(mode: GameMode) {
    this.settings.mode = mode;
    this.save();
  }

  public getShakeMultiplier(): number {
    switch (this.settings.screenShake) {
      case 'off':
        return 0;
      case 'low':
        return 0.5;
      case 'normal':
        return 1.0;
      case 'extreme':
        return 1.8;
      default:
        return 1.0;
    }
  }
}
