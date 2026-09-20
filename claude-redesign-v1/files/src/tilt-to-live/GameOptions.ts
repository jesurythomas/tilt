// =========================================================================
// GameOptions.ts - Mode Selection, Audio, Controls & Visual Settings
// =========================================================================

export type GameMode = 'classic' | 'code-red' | 'gauntlet';

export interface ModeConfig {
  id: GameMode;
  name: string;
  /** Deprecated: badges are no longer rendered. Kept as an empty string for compatibility. */
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

  // Ordered by ascending score multiplier. `classic` must stay first: it is the
  // fallback returned by getModeConfig().
  public readonly modes: ModeConfig[] = [
    {
      id: 'classic',
      name: 'Standard',
      badge: '',
      tagline: 'The full arsenal, ramping swarms.',
      description: 'Every weapon unlocked, with swarms that ramp as you survive.',
      color: '#5B8CFF',
      accent: '#8FB0FF',
      glow: 'rgba(91, 140, 255, 0.45)',
      scoreMultiplier: 1.0
    },
    {
      id: 'gauntlet',
      name: 'Gauntlet',
      badge: '',
      tagline: 'Walls close in while you dodge.',
      description: 'Descending walls squeeze the arena while the swarm keeps coming.',
      color: '#FFB14D',
      accent: '#FFC87E',
      glow: 'rgba(255, 177, 77, 0.45)',
      scoreMultiplier: 1.25
    },
    {
      id: 'code-red',
      name: 'Code Red',
      badge: '',
      tagline: 'Double density from the first second.',
      description: 'Twice the starting swarm, with faster seekers throughout.',
      color: '#A78BFA',
      accent: '#C4B2FD',
      glow: 'rgba(167, 139, 250, 0.45)',
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
        return 1.0;
      case 'extreme':
        return 1.8;
      default:
        return 1.0;
    }
  }
}
