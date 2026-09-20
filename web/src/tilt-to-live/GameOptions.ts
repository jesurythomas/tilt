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
  screenShake: 'off' | 'low' | 'normal' | 'extreme' | 'full';
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
      name: 'Standard',
      badge: '1.0×',
      tagline: 'The full arsenal, ramping swarms.',
      description: 'The full arsenal, ramping swarms.',
      color: '#5B8CFF',
      accent: '#8FB0FF',
      glow: 'rgba(91, 140, 255, 0.35)',
      scoreMultiplier: 1.0
    },
    {
      id: 'gauntlet',
      name: 'Gauntlet',
      badge: '1.25×',
      tagline: 'Walls close in while you dodge.',
      description: 'Walls close in while you dodge.',
      color: '#FFB14D',
      accent: '#FFD277',
      glow: 'rgba(255, 177, 77, 0.35)',
      scoreMultiplier: 1.25
    },
    {
      id: 'code-red',
      name: 'Code Red',
      badge: '1.5×',
      tagline: 'Double density from the first second.',
      description: 'Double density from the first second.',
      color: '#A78BFA',
      accent: '#C4B5FD',
      glow: 'rgba(167, 139, 250, 0.35)',
      scoreMultiplier: 1.5
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
      case 'full':
        return 1.0;
      case 'extreme':
        return 1.8;
      default:
        return 1.0;
    }
  }
}
