import { VectorGrid } from './VectorGrid';
import { ParticleEngine } from './ParticleEngine';
import { WeaponSystem } from './WeaponSystem';
import { EnemySwarm } from './EnemySwarm';
import { PlayerShip } from './PlayerShip';
import { ScoreManager } from './ScoreManager';
import { GameMode, Point2D } from './Types';
import { ArenaThemeConfig, CursorSkinConfig, EnemySkinConfig } from './ProgressionManager';
import { GauntletMaze } from './GauntletMaze';

export class TiltRenderer {
  private cameraShake: number = 0;
  public scale: number = 1.0;

  public triggerShake(amount: number = 10) {
    this.cameraShake = amount;
  }

  public setScale(scale: number) {
    this.scale = Math.max(0.5, Math.min(1.8, scale));
  }

  public render(
    ctx: CanvasRenderingContext2D,
    width: number,
    height: number,
    player: PlayerShip,
    swarm: EnemySwarm,
    weapons: WeaponSystem,
    grid: VectorGrid,
    particles: ParticleEngine,
    scores: ScoreManager,
    mousePos: Point2D,
    elapsed: number,
    controlMode: 'mouse' | 'keyboard' | 'gyro' = 'mouse',
    cursorSkin?: CursorSkinConfig,
    enemySkin?: EnemySkinConfig,
    arenaTheme?: ArenaThemeConfig,
    tetherLine: boolean = true,
    highContrastHalo: boolean = true,
    gameMode: GameMode = 'classic',
    gauntletMaze?: GauntletMaze,
    showGridlines: boolean = false
  ) {
    // Screen Shake Decay
    let shakeX = 0;
    let shakeY = 0;
    if (this.cameraShake > 0.1) {
      shakeX = (Math.random() * 2 - 1) * this.cameraShake;
      shakeY = (Math.random() * 2 - 1) * this.cameraShake;
      this.cameraShake *= 0.88;
    }

    ctx.save();
    if (shakeX !== 0 || shakeY !== 0) {
      ctx.translate(shakeX, shakeY);
    }

    // 1. Arena Background (Themed by gameMode or equipped Arena Theme)
    let bgColors: [string, string, string] = ['#100c1e', '#090712', '#040308'];
    let gridColor = 'rgba(0, 220, 255, 0.28)';
    let boundaryCol = 'rgba(0, 220, 255, 0.45)';

    if (gameMode === 'code-red') {
      const alertPulse = 0.5 + 0.5 * Math.sin(elapsed * 4);
      // Plasma / deep void atmosphere (Color discipline: hazard red is quarantined strictly to hostile dots)
      bgColors = ['#180e28', '#0c0716', '#05030a'];
      gridColor = `rgba(167, 139, 250, ${0.28 + 0.08 * alertPulse})`;
      boundaryCol = `rgba(167, 139, 250, ${0.55 + 0.2 * alertPulse})`;
    } else if (gameMode === 'gauntlet') {
      bgColors = ['#221403', '#110a01', '#060301'];
      gridColor = 'rgba(255, 170, 0, 0.35)';
      boundaryCol = 'rgba(255, 180, 0, 0.75)';
    }

    if (arenaTheme) {
      bgColors = arenaTheme.bgGradient;
      gridColor = arenaTheme.gridColor;
      boundaryCol = arenaTheme.boundaryColor;
    }

    const bg = ctx.createRadialGradient(
      width / 2,
      height / 2,
      width * 0.1,
      width / 2,
      height / 2,
      width * 0.8
    );
    bg.addColorStop(0, bgColors[0]);
    bg.addColorStop(0.65, bgColors[1]);
    bg.addColorStop(1, bgColors[2]);
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, width, height);

    // 2. Interactive Reactive Spring-Mass Vector Grid (only if enabled)
    if (showGridlines) {
      grid.render(ctx, gridColor);
    }

    // 3. Mode-Specific Atmosphere Overlays (Color discipline: #FF4757 quarantined to hostile dots)
    if (gameMode === 'code-red') {
      const alertPulse = 0.5 + 0.5 * Math.sin(elapsed * 4);
      const vig = ctx.createRadialGradient(width / 2, height / 2, width * 0.35, width / 2, height / 2, width * 0.75);
      vig.addColorStop(0, 'rgba(167, 139, 250, 0)');
      vig.addColorStop(1, `rgba(167, 139, 250, ${0.10 * alertPulse})`);
      ctx.fillStyle = vig;
      ctx.fillRect(0, 0, width, height);
    } else if (gameMode === 'gauntlet') {
      // Industrial hazard corner brackets
      ctx.strokeStyle = 'rgba(255, 190, 0, 0.7)';
      ctx.lineWidth = 2.5;
      const s = 28;
      ctx.strokeRect(10, 10, s, s);
      ctx.strokeRect(width - 10 - s, 10, s, s);
      ctx.strokeRect(10, height - 10 - s, s, s);
      ctx.strokeRect(width - 10 - s, height - 10 - s, s, s);
    }

    // 4. Arena Perimeter Boundary
    ctx.strokeStyle = boundaryCol;
    ctx.lineWidth = 2.5;
    ctx.strokeRect(6, 6, width - 12, height - 12);

    ctx.strokeStyle = boundaryCol.replace(/[\d\.]+\)$/, '0.12)');
    ctx.lineWidth = 8;
    ctx.strokeRect(6, 6, width - 12, height - 12);

    // 4.5. Gauntlet Descending Maze Walls
    if (gameMode === 'gauntlet' && gauntletMaze) {
      gauntletMaze.render(ctx, { width, height }, elapsed);
    }

    // 5. Floating Weapon Orbs & Active Weapons (Bloom / canvas glow preserved)
    weapons.render(ctx, elapsed);

    // 6. Red Dot Enemies (Themed by equipped skin and gameMode; highContrastHalo respected)
    swarm.render(ctx, elapsed, enemySkin, highContrastHalo, gameMode);

    // 7. Particle Explosions & Shards
    particles.render(ctx);

    // 8. Player Ship (Themed by equipped Ship Model; bloom on shield & thruster glow preserved)
    player.render(ctx, elapsed, cursorSkin);

    // 9. Mouse Location Guidance Reticle (Themed by equipped Cursor Skin; tetherLine respected)
    if (!player.isDead && controlMode === 'mouse') {
      this.renderMouseReticle(ctx, mousePos, player, elapsed, cursorSkin, tetherLine);
    }

    // 10. Floating Score & Combo Milestone Texts (Strict color discipline)
    scores.renderFloatingTexts(ctx);

    // Finding 6 Fix: Nothing painted over arena centre; HUD is cleanly managed by DOM in-run HUD without collision
    ctx.restore();
  }

  public renderMenuBackground(
    ctx: CanvasRenderingContext2D,
    width: number,
    height: number,
    grid: VectorGrid,
    particles: ParticleEngine,
    mousePos: Point2D,
    _elapsed: number,
    arenaTheme?: ArenaThemeConfig,
    showGridlines: boolean = false
  ) {
    // 1. Arena Background
    const bg = ctx.createRadialGradient(
      width / 2,
      height / 2,
      width * 0.1,
      width / 2,
      height / 2,
      width * 0.8
    );
    if (arenaTheme) {
      bg.addColorStop(0, arenaTheme.bgGradient[0]);
      bg.addColorStop(0.65, arenaTheme.bgGradient[1]);
      bg.addColorStop(1, arenaTheme.bgGradient[2]);
    } else {
      bg.addColorStop(0, '#100c1e');
      bg.addColorStop(0.65, '#090712');
      bg.addColorStop(1, '#040308');
    }
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, width, height);

    // 2. Vector Grid (only if enabled)
    if (showGridlines) {
      grid.render(ctx, arenaTheme?.gridColor);
    }

    // 3. Subtle ambient disturbance from mouse
    grid.applyExplosion(mousePos.x, mousePos.y, 0.4, 45);

    // 4. Ambient floating particles
    particles.render(ctx);
  }

  private renderMouseReticle(
    ctx: CanvasRenderingContext2D,
    mousePos: Point2D,
    player: PlayerShip,
    elapsed: number,
    cursorSkin?: CursorSkinConfig,
    tetherLine: boolean = true
  ) {
    const dx = mousePos.x - player.x;
    const dy = mousePos.y - player.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist < 1) return; // Keep reticle visible

    const skinId = cursorSkin?.id || 'classic';
    const primary = cursorSkin?.primaryColor || '#00ddff';
    const accent = cursorSkin?.accentColor || '#00ffee';
    const tetherColor = cursorSkin?.tetherColor || 'rgba(0, 220, 255, 0.2)';

    // 1. Custom Tether Line toward ship (if enabled in options)
    if (tetherLine && dist > 30) {
      ctx.save();
      ctx.strokeStyle = tetherColor;
      ctx.lineWidth = skinId === 'tactical' ? 1.5 : 1.2;

      if (skinId === 'tactical') {
        // Solid high-visibility laser tracer
        ctx.beginPath();
        ctx.moveTo(player.x, player.y);
        ctx.lineTo(mousePos.x, mousePos.y);
        ctx.stroke();
      } else if (skinId === 'cyber') {
        // High-tech telemetry dotted tether
        ctx.setLineDash([2, 5]);
        ctx.beginPath();
        ctx.moveTo(player.x, player.y);
        ctx.lineTo(mousePos.x, mousePos.y);
        ctx.stroke();
      } else if (skinId === 'solar') {
        // Dual golden energy filament
        ctx.setLineDash([6, 3]);
        ctx.beginPath();
        ctx.moveTo(player.x, player.y);
        ctx.lineTo(mousePos.x, mousePos.y);
        ctx.stroke();
      } else {
        // Classic & default dashed laser tether
        ctx.setLineDash([4, 6]);
        ctx.beginPath();
        ctx.moveTo(player.x, player.y);
        ctx.lineTo(mousePos.x, mousePos.y);
        ctx.stroke();
      }
      ctx.restore();
    }

    // 2. Custom Reticle Geometry
    ctx.save();
    ctx.translate(mousePos.x, mousePos.y);
    if (this.scale !== 1.0) {
      ctx.scale(this.scale, this.scale);
    }

    const pulse = 0.6 + 0.4 * Math.sin(elapsed * 7);

    switch (skinId) {
      case 'tactical': {
        // 4-Axis Precision Crosshair
        ctx.strokeStyle = primary;
        ctx.lineWidth = 1.6;
        const tick = 7;
        ctx.beginPath();
        ctx.moveTo(0, -tick - 4); ctx.lineTo(0, -4);
        ctx.moveTo(0, 4); ctx.lineTo(0, tick + 4);
        ctx.moveTo(-tick - 4, 0); ctx.lineTo(-4, 0);
        ctx.moveTo(4, 0); ctx.lineTo(tick + 4, 0);
        ctx.stroke();

        // Outer corner brackets
        ctx.strokeStyle = accent;
        ctx.lineWidth = 1;
        ctx.strokeRect(-9, -9, 18, 18);

        // Center Laser Diode
        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.arc(0, 0, 1.8, 0, Math.PI * 2);
        ctx.fill();
        break;
      }

      case 'singularity': {
        // Swirling Gravitational Vortex Ring
        ctx.rotate(elapsed * 5);
        ctx.strokeStyle = primary;
        ctx.lineWidth = 1.8;
        ctx.beginPath();
        ctx.arc(0, 0, 8.5, 0, Math.PI * 2);
        ctx.stroke();

        // 3 Orbiting Event Horizon Motes
        for (let i = 0; i < 3; i++) {
          const a = (i * Math.PI * 2) / 3;
          ctx.fillStyle = accent;
          ctx.beginPath();
          ctx.arc(Math.cos(a) * 8.5, Math.sin(a) * 8.5, 2, 0, Math.PI * 2);
          ctx.fill();
        }

        // Dark singularity center core
        ctx.fillStyle = '#0b0014';
        ctx.beginPath();
        ctx.arc(0, 0, 4.5, 0, Math.PI * 2);
        ctx.fill();
        break;
      }

      case 'solar': {
        // Blazing 8-Point Sunburst Corona
        ctx.rotate(elapsed * 2.5);
        ctx.strokeStyle = primary;
        ctx.lineWidth = 1.5;

        for (let i = 0; i < 8; i++) {
          const a = (i * Math.PI) / 4;
          const r1 = 6;
          const r2 = 10 + pulse * 2;
          ctx.beginPath();
          ctx.moveTo(Math.cos(a) * r1, Math.sin(a) * r1);
          ctx.lineTo(Math.cos(a) * r2, Math.sin(a) * r2);
          ctx.stroke();
        }

        // Molten Yellow-Gold Core
        ctx.fillStyle = accent;
        ctx.beginPath();
        ctx.arc(0, 0, 3.5, 0, Math.PI * 2);
        ctx.fill();
        break;
      }

      case 'cyber': {
        // Rotating Dual Hexagon Matrix
        ctx.rotate(elapsed * 3);
        ctx.strokeStyle = primary;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        for (let i = 0; i < 6; i++) {
          const a = (i * Math.PI) / 3;
          const hx = Math.cos(a) * 9;
          const hy = Math.sin(a) * 9;
          if (i === 0) ctx.moveTo(hx, hy);
          else ctx.lineTo(hx, hy);
        }
        ctx.closePath();
        ctx.stroke();

        // Center Digital Square
        ctx.fillStyle = accent;
        ctx.fillRect(-2, -2, 4, 4);
        break;
      }

      case 'shuriken': {
        // Spinning 3-Blade Emerald Shuriken
        ctx.rotate(elapsed * 10);
        ctx.fillStyle = primary;
        ctx.beginPath();
        for (let i = 0; i < 3; i++) {
          const a = (i * Math.PI * 2) / 3;
          const tipX = Math.cos(a) * 11;
          const tipY = Math.sin(a) * 11;
          const waistX = Math.cos(a + 0.5) * 4;
          const waistY = Math.sin(a + 0.5) * 4;
          if (i === 0) ctx.moveTo(tipX, tipY);
          else ctx.lineTo(tipX, tipY);
          ctx.lineTo(waistX, waistY);
        }
        ctx.closePath();
        ctx.fill();

        // Center jade highlight
        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.arc(0, 0, 2, 0, Math.PI * 2);
        ctx.fill();
        break;
      }

      case 'celestial': {
        // Counter-Rotating Celestial Gimbal Rings
        ctx.strokeStyle = primary;
        ctx.lineWidth = 1.4;
        ctx.beginPath();
        ctx.arc(0, 0, 9, 0, Math.PI * 2);
        ctx.stroke();

        ctx.save();
        ctx.rotate(-elapsed * 3);
        ctx.strokeStyle = accent;
        ctx.lineWidth = 1;
        ctx.strokeRect(-5, -5, 10, 10);
        ctx.restore();

        // Center Star Diamond
        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.moveTo(0, -3); ctx.lineTo(3, 0); ctx.lineTo(0, 3); ctx.lineTo(-3, 0);
        ctx.closePath();
        ctx.fill();
        break;
      }

      default: {
        // Classic Cyan Minimalist Ring
        ctx.strokeStyle = primary;
        ctx.lineWidth = 1.4;
        ctx.beginPath();
        ctx.arc(0, 0, 7, 0, Math.PI * 2);
        ctx.stroke();

        ctx.fillStyle = accent;
        ctx.beginPath();
        ctx.arc(0, 0, 2, 0, Math.PI * 2);
        ctx.fill();
        break;
      }
    }

    ctx.restore();
  }

  public renderInGameHUD(
    ctx: CanvasRenderingContext2D,
    width: number,
    _height: number,
    scores: ScoreManager,
    player: PlayerShip,
    _elapsed: number,
    _gameMode: GameMode = 'classic'
  ) {
    ctx.save();

    // Multiplier Badge (Top Left under Score) - Ion blue tint, NEVER in hazard red
    const mult = scores.stats.multiplier;
    const multColor = '#5B8CFF';

    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';

    const badgeW = 96;
    const badgeH = 24;
    ctx.fillStyle = 'rgba(20, 24, 33, 0.85)';
    ctx.strokeStyle = 'rgba(91, 140, 255, 0.45)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.roundRect(20, 72, badgeW, badgeH, 4);
    ctx.fill();
    ctx.stroke();

    ctx.font = '600 12px "IBM Plex Mono", monospace';
    ctx.fillStyle = multColor;
    ctx.fillText(`${mult}× CHAIN`, 28, 77);

    // Kills counter next to badge
    ctx.font = '500 11px "IBM Plex Mono", monospace';
    ctx.fillStyle = '#7A8397';
    ctx.fillText(`KILLS: ${scores.stats.kills}`, 128, 77);

    // Shield remaining indicator if active
    if (player.hasShield()) {
      const shieldSecs = player.shieldTimer.toFixed(1);
      ctx.textAlign = 'center';
      ctx.font = '500 11px "IBM Plex Mono", monospace';
      ctx.fillStyle = '#5B8CFF';
      ctx.fillText(`SHIELD: ${shieldSecs}s`, width / 2, 52);

      // Duration bar
      const barWidth = 120;
      const barHeight = 3;
      const fill = (player.shieldTimer / 6.0) * barWidth;
      ctx.fillStyle = '#1B2029';
      ctx.fillRect(width / 2 - barWidth / 2, 66, barWidth, barHeight);
      ctx.fillStyle = '#5B8CFF';
      ctx.fillRect(width / 2 - barWidth / 2, 66, fill, barHeight);
    }

    ctx.restore();
  }

  public renderModeAnnouncementBanner(
    ctx: CanvasRenderingContext2D,
    width: number,
    _height: number,
    gameMode: GameMode,
    elapsed: number
  ) {
    const alpha = elapsed > 2.2 ? Math.max(0, (2.8 - elapsed) / 0.6) : Math.min(1, elapsed / 0.3);
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    let title = 'CLASSIC SURVIVAL';
    let sub = 'STANDARD 1.0X SCORE // THE NEON ARENA';
    let color = '#5B8CFF';
    let boxBg = 'rgba(20, 24, 33, 0.92)';

    if (gameMode === 'code-red') {
      title = 'CODE RED PROTOCOL';
      sub = '1.5X SCORE // INSTANT HYPER-SWARM AMBUSH';
      color = '#A78BFA'; // Plasma purple, never hazard red
      boxBg = 'rgba(26, 18, 38, 0.92)';
    } else if (gameMode === 'gauntlet') {
      title = 'THE GAUNTLET';
      sub = '1.25X MULTIPLIER // DESCENDING WALL MAZE';
      color = '#FFB14D';
      boxBg = 'rgba(38, 28, 16, 0.92)';
    }

    const boxW = Math.min(460, width - 32);
    const boxH = 46;
    const boxY = 88;

    ctx.fillStyle = boxBg;
    ctx.strokeStyle = color;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.roundRect(width / 2 - boxW / 2, boxY, boxW, boxH, 6);
    ctx.fill();
    ctx.stroke();

    const isNarrow = width < 480;
    ctx.font = isNarrow ? '700 12px "Archivo", sans-serif' : '700 14px "Archivo", sans-serif';
    ctx.fillStyle = color;
    ctx.fillText(title, width / 2, boxY + 16);

    ctx.font = isNarrow ? '500 9.5px "IBM Plex Mono", monospace' : '500 11px "IBM Plex Mono", monospace';
    ctx.fillStyle = '#99A1B3';
    ctx.fillText(sub, width / 2, boxY + 32);

    ctx.restore();
  }
}
