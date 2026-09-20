// =========================================================================
// TiltEntranceCinematic.ts - 600ms wordmark hold over the arena
// =========================================================================
//
// The old letterboxed "space invaders" cutscene is gone. What remains is a
// short hold on the TILT TO LIVE wordmark over the live arena, which any
// input cuts short. The skip / timeout / completion plumbing is unchanged so
// nothing can hang: update() still returns true on the frame it finishes,
// skip() still finishes immediately, and finish() still seeds the run.

import { TiltAudio } from './TiltAudio';
import { PlayerShip } from './PlayerShip';
import { EnemySwarm } from './EnemySwarm';
import { VectorGrid } from './VectorGrid';
import { ParticleEngine } from './ParticleEngine';
import { TiltRenderer } from './TiltRenderer';
import { WeaponSystem } from './WeaponSystem';

import { GameMode } from './Types';

interface InvaderUnit {
  gridCol: number;
  gridRow: number;
  x: number;
  y: number;
  targetX: number;
  targetY: number;
  scatterVx: number;
  scatterVy: number;
}

export class TiltEntranceCinematic {
  private readonly audio: TiltAudio;
  private readonly player: PlayerShip;
  private readonly swarm: EnemySwarm;
  private readonly grid: VectorGrid;
  private readonly particles: ParticleEngine;
  private readonly renderer: TiltRenderer;
  private readonly weapons: WeaponSystem;
  private readonly onFinish: () => void;
  private gameMode: GameMode = 'classic';

  public isPlaying: boolean = false;
  public elapsed: number = 0;
  /** 600ms hold on the wordmark. */
  public readonly duration: number = 0.6;

  private overlayEl: HTMLElement | null = null;
  private wordmarkEl: HTMLElement | null = null;
  private invaders: InvaderUnit[] = [];

  constructor(
    audio: TiltAudio,
    player: PlayerShip,
    swarm: EnemySwarm,
    grid: VectorGrid,
    particles: ParticleEngine,
    renderer: TiltRenderer,
    weapons: WeaponSystem,
    onFinish: () => void
  ) {
    this.audio = audio;
    this.player = player;
    this.swarm = swarm;
    this.grid = grid;
    this.particles = particles;
    this.renderer = renderer;
    this.weapons = weapons;
    this.onFinish = onFinish;
    this.overlayEl = document.getElementById('tilt-cinematic-overlay');
    this.wordmarkEl = document.querySelector('.tilt-cinematic-wordmark');
  }

  public start(width: number, height: number, mode: GameMode = 'classic') {
    this.gameMode = mode;
    this.isPlaying = true;
    this.elapsed = 0;

    // The only copy the cinematic carries. The legacy sub / title / badge
    // nodes are left untouched: they stay empty and permanently hidden.
    if (this.wordmarkEl) {
      this.wordmarkEl.textContent = 'TILT TO LIVE';
    }

    if (mode === 'code-red') {
      this.audio.playSiren();
    } else if (mode === 'gauntlet') {
      this.audio.playGauntletKlaxon();
    }

    if (this.overlayEl) {
      this.overlayEl.classList.remove('hidden');
    }

    // Clear active swarm for the hold
    this.swarm.reset();
    this.weapons.reset();

    // Position player ship in lower center, already pointing up
    const cx = width / 2;
    const cy = height / 2 + 100;
    this.player.reset(cx, cy);
    this.player.angle = -Math.PI / 2;

    // Seed positions for the classic opening armada. These are the same 6x4
    // formation coordinates the old cutscene used, so finish() spawns the
    // opening seekers exactly where it always did.
    this.invaders = [];
    const cols = 6;
    const rows = 4;
    const spacingX = 46;
    const spacingY = 36;
    const startX = cx - ((cols - 1) * spacingX) / 2;
    const startY = height * 0.22;

    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const x = startX + c * spacingX;
        const y = startY + r * spacingY;
        const angle = Math.atan2(y - height * 0.4, x - cx) + (Math.random() * 0.4 - 0.2);
        const speed = 260 + Math.random() * 180;
        this.invaders.push({
          gridCol: c,
          gridRow: r,
          x,
          y,
          targetX: x,
          targetY: y,
          scatterVx: Math.cos(angle) * speed,
          scatterVy: Math.sin(angle) * speed
        });
      }
    }

    // One soft ripple under the wordmark so the arena is not static.
    this.grid.applyExplosion(cx, height * 0.5, 60, 90);
  }

  public update(dt: number, width: number, height: number): boolean {
    if (!this.isPlaying) return false;

    this.elapsed += dt;
    this.player.angle = -Math.PI / 2;

    if (this.elapsed >= this.duration) {
      this.finish(width, height);
      return true;
    }

    return false;
  }

  /**
   * The wordmark is a DOM element over the arena, so the cinematic paints
   * nothing on the canvas. Kept for signature compatibility with TiltGame.
   */
  public render(_ctx: CanvasRenderingContext2D, _width: number, _height: number) {
    // Intentionally empty.
  }

  public skip(width: number, height: number) {
    if (!this.isPlaying) return;
    this.finish(width, height);
  }

  private finish(width: number, height: number) {
    this.isPlaying = false;

    if (this.overlayEl) {
      this.overlayEl.classList.add('hidden');
    }

    // Convert cinematic into initial mode-specific armada
    this.swarm.reset();

    if (this.gameMode === 'code-red') {
      // 24-dot perimeter armada closing in immediately + Vortex and Nuke
      this.swarm.spawnModeArmada('code-red', { width, height }, { x: this.player.x, y: this.player.y });
      this.weapons.spawnOrb({ width, height }, 'vortex', width / 2 - 80, height * 0.45);
      this.weapons.spawnOrb({ width, height }, 'nuke', width / 2 + 80, height * 0.45);
    } else if (this.gameMode === 'gauntlet') {
      // Normal seeker swarm + initial weapon orb
      this.swarm.spawnModeArmada('gauntlet', { width, height }, { x: this.player.x, y: this.player.y });
      this.weapons.spawnOrb({ width, height }, 'nuke', width / 2, height * 0.45);
    } else {
      // Classic: standard 8 seekers + 1 nuke
      for (let i = 0; i < Math.min(8, this.invaders.length); i++) {
        const inv = this.invaders[i];
        const safeX = Math.max(40, Math.min(width - 40, inv.x));
        const safeY = Math.max(40, Math.min(height - 40, inv.y));
        this.swarm.spawnSeeker({ width, height }, safeX, safeY);
      }
      this.weapons.spawnOrb({ width, height }, 'nuke', width / 2, height * 0.45);
    }

    this.player.activateShield(2.5);
    this.particles.emitSparks(this.player.x, this.player.y, 12, '#5B8CFF', 90);
    this.renderer.triggerShake(6);
    this.onFinish();
  }
}
