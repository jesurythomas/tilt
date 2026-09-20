// =========================================================================
// Types.ts - Tilt to Live Data Structures & Enumerations
// =========================================================================

export type GamePhase = 'menu' | 'cinematic' | 'playing' | 'paused' | 'game-over';

export type GameMode = 'classic' | 'code-red' | 'gauntlet';

export type WeaponType =
  | 'nuke'
  | 'missiles'
  | 'lightning'
  | 'laser'
  | 'vortex'
  | 'freeze'
  | 'shield';

export type EnemyType =
  | 'seeker'
  | 'arrow_drone'
  | 'wall_dot'
  | 'circle_dot'
  | 'turret_dot'
  | 'spike_mine'
  | 'snake_segment'
  | 'charger'
  | 'artillery'
  | 'carrier'
  | 'bullet'
  | 'pulsar'
  | 'specter';

export interface Point2D {
  x: number;
  y: number;
}

export interface Velocity2D {
  vx: number;
  vy: number;
}

export interface WeaponOrb {
  id: number;
  type: WeaponType;
  x: number;
  y: number;
  radius: number;
  spawnTime: number;
  lifetime: number;
  pulseOffset: number;
}

export interface ActiveWeapon {
  id: number;
  type: WeaponType;
  x: number;
  y: number;
  duration: number;
  maxDuration: number;
  radius: number;
  maxRadius?: number;
  angle?: number;
  data?: any;
}

export interface HomingMissile {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  targetId: number | null;
  lifetime: number;
  smokeTimer: number;
}

export interface LightningArc {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  intensity: number;
  branches: { x: number; y: number }[];
}

export interface Enemy {
  id: number;
  type: EnemyType;
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  frozen: boolean;
  freezeTimer: number;
  age: number;
  health: number;
  targetAngle?: number;
  specialTimer?: number;
  leaderId?: number;
  parentWaveId?: number;
  orbitCenter?: Point2D;
  orbitRadius?: number;
  orbitSpeed?: number;
  chilled?: boolean;
  isHazard?: boolean;
  state?: 'aiming' | 'charging' | 'cooling' | 'patrol';
  aimAngle?: number;
  aimTimer?: number;
  fireCooldown?: number;
  parentCarrierId?: number;
  orbitAngle?: number;
  pulseTimer?: number;
  stealthOpacity?: number;
}

export interface FloatingText {
  id: number;
  text: string;
  x: number;
  y: number;
  vy: number;
  color: string;
  size: number;
  alpha: number;
  lifetime: number;
}

export interface GameStats {
  score: number;
  bestScore: number;
  multiplier: number;
  maxMultiplier: number;
  kills: number;
  survivalTime: number;
  bestCombo: number;
  closeCalls: number;
}
