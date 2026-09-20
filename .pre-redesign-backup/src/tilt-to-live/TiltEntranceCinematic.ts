// =========================================================================
// TiltEntranceCinematic.ts - Space Invaders March & Hyperspace Warp Cutscene
// =========================================================================

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
  public readonly duration: number = 3.2; // 3.2s total

  private overlayEl: HTMLElement | null = null;
  private invaders: InvaderUnit[] = [];
  private marchStep: number = 0;
  private nextMarchTime: number = 0;
  private warpTriggered: boolean = false;

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
    this.marchStep = 0;
    this.nextMarchTime = 0.05;
    this.warpTriggered = false;

    // Update cinematic cutscene titles per mode
    const titleEl = document.querySelector('.tilt-cinematic-title');
    const subEl = document.querySelector('.tilt-cinematic-sub');
    const badgeEl = document.querySelector('.tilt-cinematic-badge');

    if (mode === 'code-red') {
      if (titleEl) titleEl.textContent = 'CODE RED PROTOCOL';
      if (subEl) subEl.textContent = '⚠️ EMERGENCY ALERT // HYPER-LETHAL SECTOR';
      if (badgeEl) badgeEl.textContent = '1.5X SCORE // INSTANT HOSTILE ARMADA';
      this.audio.playSiren();
    } else if (mode === 'gauntlet') {
      if (titleEl) titleEl.textContent = 'THE GAUNTLET';
      if (subEl) subEl.textContent = '⚠️ DESCENDING WALL MAZE // FIND THE GAPS';
      if (badgeEl) badgeEl.textContent = '1.25X MULTIPLIER // SURVIVAL SCORE ACCELERATION';
      this.audio.playGauntletKlaxon();
    } else {
      if (titleEl) titleEl.textContent = 'SPACE INVADERS DETECTED';
      if (subEl) subEl.textContent = 'RED DOT FLEET INCOMING // SECTOR 01';
      if (badgeEl) badgeEl.textContent = '1.0X SCORE // TILT TO SURVIVE';
    }

    if (this.overlayEl) {
      this.overlayEl.classList.remove('hidden');
    }

    // Clear active swarm for cinematic
    this.swarm.reset();
    this.weapons.reset();

    // Position player ship in lower center
    const cx = width / 2;
    const cy = height / 2 + 100;
    this.player.reset(cx, cy);

    // Build 6x4 Space Invader formation centered in upper half
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
        // Pre-compute outward scatter velocity
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
  }

  public update(dt: number, width: number, height: number): boolean {
    if (!this.isPlaying) return false;

    this.elapsed += dt;
    const t = this.elapsed;
    const cx = width / 2;
    const cy = height / 2 + 100;

    // -----------------------------------------------------------------------
    // STAGE 1: Space Invader March (0.0s - 1.2s)
    // -----------------------------------------------------------------------
    if (t < 1.2) {
      if (t >= this.nextMarchTime && this.marchStep < 4) {
        this.audio.playSpaceInvaderStep(this.marchStep);

        // Step offsets: Right, Right, Down, Left
        let dx = 0;
        let dy = 0;
        if (this.marchStep === 0 || this.marchStep === 1) dx = 24;
        else if (this.marchStep === 2) dy = 26;
        else if (this.marchStep === 3) dx = -24;

        for (const inv of this.invaders) {
          inv.targetX += dx;
          inv.targetY += dy;
        }

        // Ripple grid under invaders
        const marchCenterY = height * 0.25 + this.marchStep * 8;
        this.grid.applyExplosion(cx, marchCenterY, 180, 45);

        this.marchStep++;
        this.nextMarchTime += 0.28;
      }

      // Smooth step slide
      for (const inv of this.invaders) {
        inv.x += (inv.targetX - inv.x) * Math.min(1.0, dt * 14);
        inv.y += (inv.targetY - inv.y) * Math.min(1.0, dt * 14);
      }

    } else if (t < 2.0) {
      // -----------------------------------------------------------------------
      // STAGE 2: Player Hyperspace Warp-In (1.2s - 2.0s)
      // -----------------------------------------------------------------------
      if (!this.warpTriggered) {
        this.warpTriggered = true;
        this.audio.playInvasionAlarm();
        this.audio.playWarpIn();
        this.renderer.triggerShake(14);
        this.grid.applyExplosion(cx, cy, 320, 110);
        this.particles.emitExplosion(cx, cy, '#00f0ff', 40);
      }

      const warpProgress = (t - 1.2) / 0.8;

      // Ship angle spins into alignment pointing up towards armada
      this.player.angle = -Math.PI / 2 + (1.0 - warpProgress) * Math.PI * 2;
      this.player.x = cx;
      this.player.y = cy;

      // Spawn engine wake sparks
      this.particles.emitSparks(cx, cy + 15, 2, '#00e5ff', 40);

    } else if (t < this.duration) {
      // -----------------------------------------------------------------------
      // STAGE 3: Armada Scatter & "READY... GO!" (2.0s - 3.2s)
      // -----------------------------------------------------------------------
      this.player.angle = -Math.PI / 2;

      // Invaders scatter across the playfield
      for (const inv of this.invaders) {
        inv.x += inv.scatterVx * dt;
        inv.y += inv.scatterVy * dt;
        // Bounce on boundary during scatter
        if (inv.x < 30 || inv.x > width - 30) inv.scatterVx *= -1;
        if (inv.y < 30 || inv.y > height - 30) inv.scatterVy *= -1;
      }

      // Spawn starter weapon orb if not yet spawned
      if (this.weapons.orbs.length === 0) {
        this.weapons.spawnOrb({ width, height }, 'nuke', cx, height * 0.45);
      }

    } else {
      // Cinematic finished!
      this.finish(width, height);
      return true;
    }

    return false;
  }

  public render(ctx: CanvasRenderingContext2D, width: number, height: number) {
    if (!this.isPlaying) return;

    const t = this.elapsed;

    // 1. Draw Space Invaders Formation (Stages 1 & 2) or Scattered (Stage 3)
    for (const inv of this.invaders) {
      ctx.save();
      ctx.translate(inv.x, inv.y);

      // Glowing red invader body
      ctx.shadowColor = '#ff2050';
      ctx.shadowBlur = 12;
      ctx.fillStyle = '#ff3366';

      // Retro Space Invader Glyph (stylized vector crab)
      ctx.beginPath();
      ctx.arc(0, 0, 7, 0, Math.PI * 2);
      ctx.fill();

      // Invader Horns / Antennas
      ctx.strokeStyle = '#ff7090';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(-4, -6);
      ctx.lineTo(-7, -11);
      ctx.moveTo(4, -6);
      ctx.lineTo(7, -11);
      // Feet
      const legPhase = Math.sin(t * 8) > 0;
      if (legPhase) {
        ctx.moveTo(-4, 6);
        ctx.lineTo(-7, 10);
        ctx.moveTo(4, 6);
        ctx.lineTo(7, 10);
      } else {
        ctx.moveTo(-4, 6);
        ctx.lineTo(-3, 10);
        ctx.moveTo(4, 6);
        ctx.lineTo(3, 10);
      }
      ctx.stroke();

      // Yellow glowing eye slits
      ctx.fillStyle = '#ffea00';
      ctx.fillRect(-3, -2, 2, 2);
      ctx.fillRect(1, -2, 2, 2);

      ctx.restore();
    }

    // 2. Hyperspace Warp Vector Rings (Stage 2)
    if (t >= 1.2 && t < 2.2) {
      const cx = width / 2;
      const cy = height / 2 + 100;
      const progress = (t - 1.2) / 1.0;
      const radius = progress * 140;

      ctx.save();
      ctx.strokeStyle = `rgba(0, 240, 255, ${Math.max(0, 1 - progress)})`;
      ctx.lineWidth = 3;
      ctx.shadowColor = '#00f0ff';
      ctx.shadowBlur = 16;
      ctx.beginPath();
      ctx.arc(cx, cy, radius, 0, Math.PI * 2);
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(cx, cy, radius * 0.6, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }

    // 3. "READY... GO!" Arcade Callout (Stage 3)
    if (t >= 2.0 && t < this.duration) {
      ctx.save();
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.font = '800 48px "Cabinet Grotesk", sans-serif';
      ctx.fillStyle = '#00f0ff';
      ctx.shadowColor = '#00f0ff';
      ctx.shadowBlur = 24;
      const calloutText = t < 2.6 ? 'READY...' : 'GO!';
      ctx.fillText(calloutText, width / 2, height / 2);
      ctx.restore();
    }
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
    this.onFinish();
  }
}
