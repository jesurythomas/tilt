// =========================================================================
// TiltEntranceCinematic.ts - Sleek 600ms 'Cold Open' Entrance System
// =========================================================================

import { TiltAudio } from './TiltAudio';
import { PlayerShip } from './PlayerShip';
import { EnemySwarm } from './EnemySwarm';
import { VectorGrid } from './VectorGrid';
import { ParticleEngine } from './ParticleEngine';
import { TiltRenderer } from './TiltRenderer';
import { WeaponSystem } from './WeaponSystem';
import { GameMode } from './Types';

export class TiltEntranceCinematic {
  private readonly audio: TiltAudio;
  private readonly player: PlayerShip;
  private readonly swarm: EnemySwarm;
  private readonly grid: VectorGrid;
  private readonly particles: ParticleEngine;
  public readonly renderer: TiltRenderer;
  private readonly weapons: WeaponSystem;
  private readonly onFinish: () => void;

  private gameMode: GameMode = 'classic';
  public isPlaying: boolean = false;
  public elapsed: number = 0;
  public readonly duration: number = 0.6; // 600ms sleek cold open hold

  private overlayEl: HTMLElement | null = null;
  private boundSkipHandler: ((e: Event) => void) | null = null;

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
  }

  public start(width: number, height: number, mode: GameMode = 'classic') {
    this.gameMode = mode;
    this.isPlaying = true;
    this.elapsed = 0;

    // Reset arena state for clean match launch
    this.swarm.reset();
    this.weapons.reset();

    // Center player ship pointing up
    const cx = width / 2;
    const cy = height / 2;
    this.player.reset(cx, cy);
    this.player.angle = -Math.PI / 2;

    // Grid ripple and particles at launch origin
    this.grid.applyExplosion(cx, cy, 260, 60);
    this.particles.emitExplosion(cx, cy, '#5B8CFF', 24);

    // Audio cue
    this.audio.playWarpIn();

    // Update overlay with Board 08 'Cold Open' DOM layout
    if (this.overlayEl) {
      this.overlayEl.innerHTML = `
        <div class="tilt-cold-open-root">
          <div class="cold-open-glow"></div>
          <div class="cold-open-center">
            <svg class="cold-open-ship-svg" width="72" height="72" viewBox="0 0 72 72" fill="none" aria-hidden="true">
              <path d="M62 36 L20 13 L28 36 L20 59 Z" fill="#5B8CFF"></path>
            </svg>
            <h1 class="cold-open-title">TILT TO LIVE</h1>
          </div>
          <div class="cold-open-bar-wrapper">
            <div class="cold-open-progress-track">
              <div id="cold-open-bar-fill" class="cold-open-progress-fill" style="width: 0%;"></div>
            </div>
          </div>
        </div>
      `;
      this.overlayEl.classList.remove('hidden');

      // Immediate skip on click, touch or tap
      this.boundSkipHandler = (e: Event) => {
        e.preventDefault();
        this.skip(width, height);
      };
      this.overlayEl.addEventListener('click', this.boundSkipHandler, { once: true });
      this.overlayEl.addEventListener('touchstart', this.boundSkipHandler, { once: true, passive: false });
    }
  }

  public update(dt: number, width: number, height: number): boolean {
    if (!this.isPlaying) return false;

    this.elapsed += dt;
    const progress = Math.min(1.0, this.elapsed / this.duration);

    // Update progress bar
    const fillEl = document.getElementById('cold-open-bar-fill');
    if (fillEl) {
      fillEl.style.width = `${Math.round(progress * 100)}%`;
    }

    // Keep player oriented and in place
    this.player.x = width / 2;
    this.player.y = height / 2;
    this.player.angle = -Math.PI / 2;

    if (this.elapsed >= this.duration) {
      this.finish(width, height);
      return true;
    }

    return false;
  }

  public render(ctx: CanvasRenderingContext2D, width: number, height: number) {
    if (!this.isPlaying) return;

    const cx = width / 2;
    const cy = height / 2;
    const progress = Math.min(1.0, this.elapsed / this.duration);

    // Canvas background radial wash
    const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(width, height) * 0.55);
    grad.addColorStop(0, 'rgba(91, 140, 255, 0.08)');
    grad.addColorStop(0.75, 'rgba(8, 9, 14, 0.95)');
    grad.addColorStop(1, '#08090E');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, width, height);

    // Render ship vector on canvas as backup/underlay
    ctx.save();
    ctx.translate(cx, cy - 30);
    ctx.shadowColor = 'rgba(91, 140, 255, 0.85)';
    ctx.shadowBlur = 24;
    ctx.fillStyle = '#5B8CFF';
    ctx.beginPath();
    ctx.moveTo(0, -32);
    ctx.lineTo(22, 28);
    ctx.lineTo(0, 16);
    ctx.lineTo(-22, 28);
    ctx.closePath();
    ctx.fill();
    ctx.restore();

    // 200px thin progress bar on canvas
    const barW = 200;
    const barH = 2;
    const barX = (width - barW) / 2;
    const barY = height - 120;

    ctx.fillStyle = '#1B2029';
    ctx.fillRect(barX, barY, barW, barH);
    ctx.fillStyle = '#5B8CFF';
    ctx.fillRect(barX, barY, barW * progress, barH);
  }

  public skip(width: number, height: number) {
    if (!this.isPlaying) return;
    this.finish(width, height);
  }

  private finish(width: number, height: number) {
    if (!this.isPlaying) return;
    this.isPlaying = false;

    // Clean up overlay element
    if (this.overlayEl) {
      this.overlayEl.classList.add('hidden');
      if (this.boundSkipHandler) {
        this.overlayEl.removeEventListener('click', this.boundSkipHandler);
        this.overlayEl.removeEventListener('touchstart', this.boundSkipHandler);
        this.boundSkipHandler = null;
      }
    }

    // Initialize mode-specific arena armada
    this.swarm.reset();

    if (this.gameMode === 'code-red') {
      this.swarm.spawnModeArmada('code-red', { width, height }, { x: this.player.x, y: this.player.y });
      this.weapons.spawnOrb({ width, height }, 'vortex', width / 2 - 80, height * 0.45);
      this.weapons.spawnOrb({ width, height }, 'nuke', width / 2 + 80, height * 0.45);
    } else if (this.gameMode === 'gauntlet') {
      this.swarm.spawnModeArmada('gauntlet', { width, height }, { x: this.player.x, y: this.player.y });
      this.weapons.spawnOrb({ width, height }, 'nuke', width / 2, height * 0.45);
    } else {
      // Standard: 8 initial seeker dots in safe radius + 1 nuke
      const count = 8;
      const radius = 260;
      for (let i = 0; i < count; i++) {
        const ang = (i / count) * Math.PI * 2;
        const x = Math.max(40, Math.min(width - 40, width / 2 + Math.cos(ang) * radius));
        const y = Math.max(40, Math.min(height - 40, height / 2 + Math.sin(ang) * radius));
        this.swarm.spawnSeeker({ width, height }, x, y);
      }
      this.weapons.spawnOrb({ width, height }, 'nuke', width / 2, height * 0.45);
    }

    // Player invulnerability shield buffer on spawn
    this.player.activateShield(2.5);

    // Seamless handover to playing phase
    this.onFinish();
  }
}
