// =========================================================================
// PlayerShip.ts - Mouse-Driven Arrow Ship with Inertia Physics
// =========================================================================

import { ParticleEngine } from './ParticleEngine';
import { Point2D } from './Types';
import { ShipSkinConfig } from './ProgressionManager';

export class PlayerShip {
  public x: number = 0;
  public y: number = 0;
  public vx: number = 0;
  public vy: number = 0;
  public angle: number = -Math.PI / 2;
  public scale: number = 1.0;
  public get radius(): number {
    return 9 * this.scale;
  }

  public setScale(scale: number) {
    this.scale = Math.max(0.5, Math.min(1.8, scale));
  }

  public shieldTimer: number = 0;
  public isDead: boolean = false;
  public closeCallTimer: number = 0;

  // Movement physics configuration
  public readonly baseMaxSpeed: number = 540; // Max velocity px/sec
  public readonly baseAcceleration: number = 1800; // Acceleration px/sec^2
  public readonly damping: number = 0.88; // Velocity drag

  public get maxSpeed(): number {
    return this.baseMaxSpeed * Math.max(0.72, this.scale);
  }

  public get acceleration(): number {
    return this.baseAcceleration * Math.max(0.72, this.scale);
  }

  public trailHistory: { x: number; y: number }[] = [];
  private engineParticleTimer: number = 0;
  private trailSampleTimer: number = 0;

  constructor(startX: number, startY: number) {
    this.reset(startX, startY);
  }

  public reset(x: number, y: number) {
    this.x = x;
    this.y = y;
    this.vx = 0;
    this.vy = 0;
    this.angle = -Math.PI / 2;
    this.shieldTimer = 0;
    this.isDead = false;
    this.closeCallTimer = 0;
    this.engineParticleTimer = 0;
    this.trailSampleTimer = 0;
    this.trailHistory = [];
  }

  public activateShield(duration: number = 6.0) {
    this.shieldTimer = Math.max(this.shieldTimer, duration);
  }

  public hasShield(): boolean {
    return this.shieldTimer > 0;
  }

  public update(
    dt: number,
    targetMouse: Point2D,
    bounds: { width: number; height: number },
    particles: ParticleEngine,
    controlMode: 'mouse' | 'keyboard' | 'gyro' = 'mouse',
    moveVector: Point2D = { x: 0, y: 0 },
    tuning: { sensitivity: number; deadzone: number } = { sensitivity: 1.0, deadzone: 4 },
    shipSkin?: ShipSkinConfig,
    gyroVector: Point2D = { x: 0, y: 0 }
  ) {
    if (this.isDead) return;

    // Countdown shield
    if (this.shieldTimer > 0) {
      this.shieldTimer -= dt;
    }
    if (this.closeCallTimer > 0) {
      this.closeCallTimer -= dt;
    }

    const deadzone = tuning.deadzone;
    const sensitivity = tuning.sensitivity || 1.0;
    const dx = targetMouse.x - this.x;
    const dy = targetMouse.y - this.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (controlMode === 'gyro') {
      const isTilting = gyroVector.x !== 0 || gyroVector.y !== 0;
      if (isTilting) {
        const tiltMag = Math.sqrt(gyroVector.x * gyroVector.x + gyroVector.y * gyroVector.y);
        const clampedMag = Math.min(1, tiltMag);
        const effectiveSpeed = this.maxSpeed * clampedMag * sensitivity;
        const dirX = gyroVector.x / tiltMag;
        const dirY = gyroVector.y / tiltMag;
        const targetVx = dirX * effectiveSpeed;
        const targetVy = dirY * effectiveSpeed;

        const accelRate = this.acceleration * dt * 1.25;
        this.vx += (targetVx - this.vx) * Math.min(1, accelRate / 180);
        this.vy += (targetVy - this.vy) * Math.min(1, accelRate / 180);
      } else {
        // Natural inertia drag when resting in neutral tilt
        this.vx *= Math.pow(this.damping, dt * 60);
        this.vy *= Math.pow(this.damping, dt * 60);
        if (Math.abs(this.vx) < 0.5) this.vx = 0;
        if (Math.abs(this.vy) < 0.5) this.vy = 0;
      }
    } else if (controlMode === 'keyboard') {
      const isMoving = moveVector.x !== 0 || moveVector.y !== 0;
      if (isMoving) {
        const targetVx = moveVector.x * this.maxSpeed;
        const targetVy = moveVector.y * this.maxSpeed;

        // Smooth responsive acceleration toward target velocity
        const accelRate = this.acceleration * dt;
        this.vx += (targetVx - this.vx) * Math.min(1, accelRate / 180);
        this.vy += (targetVy - this.vy) * Math.min(1, accelRate / 180);
      } else {
        // Natural inertia drag when keys released
        this.vx *= Math.pow(this.damping, dt * 60);
        this.vy *= Math.pow(this.damping, dt * 60);
        if (Math.abs(this.vx) < 0.5) this.vx = 0;
        if (Math.abs(this.vy) < 0.5) this.vy = 0;
      }
    } else {
      // Mouse-location tilt simulation with custom sensitivity & deadzone
      if (dist > deadzone) {
        const dirX = dx / dist;
        const dirY = dy / dist;

        // Higher sensitivity allows full tilt speed with smaller cursor displacement
        const effectiveReach = Math.max(40, 160 / sensitivity);
        const tiltScale = Math.min(1, (dist - deadzone) / effectiveReach);
        const targetSpeed = this.maxSpeed * tiltScale;

        const targetVx = dirX * targetSpeed;
        const targetVy = dirY * targetSpeed;

        // Smooth acceleration toward target velocity
        const accelRate = this.acceleration * dt;
        this.vx += (targetVx - this.vx) * Math.min(1, accelRate / 200);
        this.vy += (targetVy - this.vy) * Math.min(1, accelRate / 200);
      } else {
        // Damping when resting at cursor
        this.vx *= Math.pow(this.damping, dt * 60);
        this.vy *= Math.pow(this.damping, dt * 60);
      }
    }

    // Integrate position
    this.x += this.vx * dt;
    this.y += this.vy * dt;

    // Smooth rotational alignment with motion velocity or cursor direction
    const currentSpeed = Math.sqrt(this.vx * this.vx + this.vy * this.vy);
    let targetAngle = this.angle;
    if (currentSpeed > 20) {
      targetAngle = Math.atan2(this.vy, this.vx);
    } else if (controlMode === 'mouse' && dist > deadzone) {
      targetAngle = Math.atan2(dy, dx);
    } else if (controlMode === 'gyro' && (gyroVector.x !== 0 || gyroVector.y !== 0)) {
      targetAngle = Math.atan2(gyroVector.y, gyroVector.x);
    }

    // Angular lerp
    let diff = targetAngle - this.angle;
    while (diff < -Math.PI) diff += Math.PI * 2;
    while (diff > Math.PI) diff -= Math.PI * 2;
    this.angle += diff * Math.min(1, dt * 16);

    // Boundary constraints with gentle bounce
    const pad = this.radius + 6;
    if (this.x < pad) {
      this.x = pad;
      this.vx = Math.abs(this.vx) * 0.4;
    } else if (this.x > bounds.width - pad) {
      this.x = bounds.width - pad;
      this.vx = -Math.abs(this.vx) * 0.4;
    }

    if (this.y < pad) {
      this.y = pad;
      this.vy = Math.abs(this.vy) * 0.4;
    } else if (this.y > bounds.height - pad) {
      this.y = bounds.height - pad;
      this.vy = -Math.abs(this.vy) * 0.4;
    }

    // Twin Engine exhaust particles
    this.engineParticleTimer += dt;
    if (this.engineParticleTimer > 0.02 && currentSpeed > 40) {
      this.engineParticleTimer = 0;
      const backDist = 14;
      const spread = 5;

      const rearX = this.x - Math.cos(this.angle) * backDist;
      const rearY = this.y - Math.sin(this.angle) * backDist;

      const normX = -Math.sin(this.angle);
      const normY = Math.cos(this.angle);

      const flameCol = this.hasShield() ? '#00ffee' : (shipSkin?.thrusterColor || '#00ddff');
      // Left wingtip flame
      particles.emitSparks(
        rearX + normX * spread,
        rearY + normY * spread,
        1,
        flameCol,
        40
      );
      // Right wingtip flame
      particles.emitSparks(
        rearX - normX * spread,
        rearY - normY * spread,
        1,
        flameCol,
        40
      );
    }

    // Sample trail history
    this.trailSampleTimer += dt;
    if (this.trailSampleTimer > 0.016) {
      this.trailSampleTimer = 0;
      this.trailHistory.unshift({ x: this.x, y: this.y });
      if (this.trailHistory.length > 14) {
        this.trailHistory.pop();
      }
    }
  }

  public render(ctx: CanvasRenderingContext2D, elapsed: number, shipSkin?: ShipSkinConfig) {
    if (this.isDead) return;

    const skin: ShipSkinConfig = shipSkin || {
      id: 'classic',
      name: 'Arrow',
      trait: 'Balanced',
      price: 0,
      description: '',
      hitbox: '50%',
      turn: '60%',
      hitboxScale: 1.0,
      turnRate: 1.0,
      tint: '#5B8CFF',
      svgPath: 'M40 24 L14 10 L19 24 L14 38 Z',
      hullColor: '#ffffff',
      primaryColor: '#00ddff',
      accentColor: '#00ffee',
      thrusterColor: '#00ddff',
      trailColor: 'rgba(0, 220, 255, 0.4)',
      tetherColor: 'rgba(0, 220, 255, 0.25)',
      shape: 'classic'
    };

    // 0. Smooth Glowing Energy Wake Ribbon (Themed by Ship)
    if (this.trailHistory.length > 1) {
      ctx.save();
      for (let i = 0; i < this.trailHistory.length - 1; i++) {
        const pt1 = this.trailHistory[i];
        const pt2 = this.trailHistory[i + 1];
        const progress = 1 - i / this.trailHistory.length;
        ctx.strokeStyle = this.hasShield()
          ? `rgba(0, 255, 220, ${progress * 0.45})`
          : skin.trailColor.replace(/[\d\.]+\)$/, `${progress * 0.42})`);
        ctx.lineWidth = progress * 5.5 * this.scale;
        ctx.beginPath();
        ctx.moveTo(pt1.x, pt1.y);
        ctx.lineTo(pt2.x, pt2.y);
        ctx.stroke();
      }
      ctx.restore();
    }

    ctx.save();
    ctx.translate(this.x, this.y);
    ctx.rotate(this.angle);
    ctx.scale(this.scale, this.scale);

    // 1. Shield Bubble
    if (this.hasShield()) {
      const shieldRadius = 23;
      const pulse = 0.75 + Math.sin(elapsed * 8) * 0.25;

      // Outer glow
      ctx.strokeStyle = `rgba(0, 255, 200, ${pulse * 0.8})`;
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.arc(0, 0, shieldRadius, 0, Math.PI * 2);
      ctx.stroke();

      // Translucent cyan fill
      ctx.fillStyle = `rgba(0, 255, 220, 0.15)`;
      ctx.beginPath();
      ctx.arc(0, 0, shieldRadius, 0, Math.PI * 2);
      ctx.fill();

      // Rotating hex energy facets
      ctx.save();
      ctx.rotate(elapsed * 2);
      ctx.strokeStyle = `rgba(180, 255, 240, ${pulse * 0.5})`;
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let i = 0; i < 6; i++) {
        const a = (i * Math.PI) / 3;
        const hx = Math.cos(a) * (shieldRadius - 2);
        const hy = Math.sin(a) * (shieldRadius - 2);
        if (i === 0) ctx.moveTo(hx, hy);
        else ctx.lineTo(hx, hy);
      }
      ctx.closePath();
      ctx.stroke();
      ctx.restore();
    }

    // 2. Custom Ship Model Rendering
    const strokeCol = this.hasShield() ? '#00ffff' : skin.primaryColor;
    const coreCol = this.hasShield() ? '#00ffff' : skin.accentColor;

    switch (skin.shape) {
      case 'viper':
        // Twin canards
        ctx.fillStyle = skin.primaryColor;
        ctx.beginPath();
        ctx.moveTo(4, -4); ctx.lineTo(1, -9); ctx.lineTo(-1, -4);
        ctx.moveTo(4, 4); ctx.lineTo(1, 9); ctx.lineTo(-1, 4);
        ctx.fill();

        // Forward-swept delta hull
        ctx.fillStyle = skin.hullColor;
        ctx.beginPath();
        ctx.moveTo(18, 0); // Needle prow
        ctx.lineTo(2, -5);
        ctx.lineTo(-10, -14); // Left wingtip
        ctx.lineTo(-13, -11);
        ctx.lineTo(-8, -4);
        ctx.lineTo(-14, -6); // Left tailfin
        ctx.lineTo(-14, 6); // Right tailfin
        ctx.lineTo(-8, 4);
        ctx.lineTo(-13, 11);
        ctx.lineTo(-10, 14); // Right wingtip
        ctx.lineTo(2, 5);
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = strokeCol;
        ctx.lineWidth = 1.8;
        ctx.stroke();

        // Wingtip laser pods
        ctx.fillStyle = skin.primaryColor;
        ctx.beginPath();
        ctx.arc(-10, -14, 2, 0, Math.PI * 2);
        ctx.arc(-10, 14, 2, 0, Math.PI * 2);
        ctx.fill();

        // Cockpit canopy
        ctx.fillStyle = coreCol;
        ctx.beginPath();
        ctx.moveTo(8, 0);
        ctx.lineTo(-2, -2.5);
        ctx.lineTo(-5, 0);
        ctx.lineTo(-2, 2.5);
        ctx.closePath();
        ctx.fill();
        break;

      case 'phantom':
        // Stealth diamond faceted voidcraft
        ctx.fillStyle = skin.hullColor;
        ctx.beginPath();
        ctx.moveTo(17, 0); // Prow
        ctx.lineTo(2, -12); // Left facet
        ctx.lineTo(-14, -9); // Left rear tip
        ctx.lineTo(-6, 0); // Rear notch
        ctx.lineTo(-14, 9); // Right rear tip
        ctx.lineTo(2, 12); // Right facet
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = strokeCol;
        ctx.lineWidth = 1.8;
        ctx.stroke();

        // Spine facet line
        ctx.strokeStyle = skin.accentColor;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(17, 0);
        ctx.lineTo(-6, 0);
        ctx.stroke();

        // Central pulsing dark-matter crystal
        const pPulse = 0.8 + 0.2 * Math.sin(elapsed * 10);
        ctx.fillStyle = coreCol;
        ctx.beginPath();
        ctx.moveTo(4, 0);
        ctx.lineTo(-2, -4 * pPulse);
        ctx.lineTo(-6, 0);
        ctx.lineTo(-2, 4 * pPulse);
        ctx.closePath();
        ctx.fill();
        break;

      case 'solar':
        // Heavy reinforced battlecruiser
        ctx.fillStyle = skin.hullColor;
        ctx.beginPath();
        ctx.moveTo(16, -3);
        ctx.lineTo(16, 3);
        ctx.lineTo(4, 9);
        ctx.lineTo(-4, 9);
        ctx.lineTo(-12, 14); // Right outrigger
        ctx.lineTo(-14, 12);
        ctx.lineTo(-10, 5);
        ctx.lineTo(-13, 0); // Center rear
        ctx.lineTo(-10, -5);
        ctx.lineTo(-14, -12);
        ctx.lineTo(-12, -14); // Left outrigger
        ctx.lineTo(-4, -9);
        ctx.lineTo(4, -9);
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = strokeCol;
        ctx.lineWidth = 2.0;
        ctx.stroke();

        // Armored shoulder insets
        ctx.fillStyle = skin.primaryColor;
        ctx.fillRect(-2, -7, 4, 3);
        ctx.fillRect(-2, 4, 4, 3);

        // Bridge deck
        ctx.fillStyle = coreCol;
        ctx.beginPath();
        ctx.moveTo(6, 0);
        ctx.lineTo(-2, -2.5);
        ctx.lineTo(-4, 0);
        ctx.lineTo(-2, 2.5);
        ctx.closePath();
        ctx.fill();
        break;

      case 'cyber':
        // Floating vector brackets
        ctx.strokeStyle = skin.primaryColor;
        ctx.lineWidth = 1.6;
        ctx.beginPath();
        ctx.moveTo(-2, -13); ctx.lineTo(-8, -15); ctx.lineTo(-12, -11);
        ctx.moveTo(-2, 13); ctx.lineTo(-8, 15); ctx.lineTo(-12, 11);
        ctx.stroke();

        // Cyber hull
        ctx.fillStyle = skin.hullColor;
        ctx.beginPath();
        ctx.moveTo(16, 0);
        ctx.lineTo(8, -6);
        ctx.lineTo(-8, -9);
        ctx.lineTo(-13, -5);
        ctx.lineTo(-8, 0);
        ctx.lineTo(-13, 5);
        ctx.lineTo(-8, 9);
        ctx.lineTo(8, 6);
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = strokeCol;
        ctx.lineWidth = 1.8;
        ctx.stroke();

        // Hex matrix core
        ctx.strokeStyle = skin.accentColor;
        ctx.lineWidth = 1.2;
        ctx.strokeRect(-2, -3, 6, 6);

        ctx.fillStyle = coreCol;
        ctx.beginPath();
        ctx.arc(1, 0, 2.2, 0, Math.PI * 2);
        ctx.fill();
        break;

      case 'shuriken':
        // Dynamic quad-blade ninja star
        ctx.fillStyle = skin.hullColor;
        ctx.beginPath();
        ctx.moveTo(17, 0); // Forward blade
        ctx.quadraticCurveTo(8, 5, 2, 2);
        ctx.lineTo(0, 16); // Right blade
        ctx.quadraticCurveTo(-5, 8, -2, 2);
        ctx.lineTo(-15, 0); // Rear blade
        ctx.quadraticCurveTo(-8, -5, -2, -2);
        ctx.lineTo(0, -16); // Left blade
        ctx.quadraticCurveTo(5, -8, 2, -2);
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = strokeCol;
        ctx.lineWidth = 1.8;
        ctx.stroke();

        // Center spinning rune
        ctx.save();
        ctx.rotate(elapsed * 6);
        ctx.strokeStyle = skin.accentColor;
        ctx.lineWidth = 1.2;
        ctx.strokeRect(-3, -3, 6, 6);
        ctx.restore();

        ctx.fillStyle = coreCol;
        ctx.beginPath();
        ctx.arc(0, 0, 2.5, 0, Math.PI * 2);
        ctx.fill();
        break;

      case 'celestial':
        // Floating celestial halo ring
        ctx.save();
        ctx.strokeStyle = skin.primaryColor;
        ctx.lineWidth = 1.6;
        ctx.setLineDash([6, 3]);
        ctx.lineDashOffset = -elapsed * 12;
        ctx.beginPath();
        ctx.ellipse(-7, 0, 5, 14, 0, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.restore();

        // Sweeping divine hull
        ctx.fillStyle = skin.hullColor;
        ctx.beginPath();
        ctx.moveTo(18, 0); // Nose
        ctx.quadraticCurveTo(4, -8, -12, -12); // Left swept wing
        ctx.quadraticCurveTo(-8, 0, -6, 0); // Notch
        ctx.quadraticCurveTo(-8, 0, -12, 12); // Right swept wing
        ctx.quadraticCurveTo(4, 8, 18, 0);
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = strokeCol;
        ctx.lineWidth = 1.8;
        ctx.stroke();

        // Astral diode cockpit
        ctx.fillStyle = coreCol;
        ctx.beginPath();
        ctx.moveTo(6, 0);
        ctx.lineTo(-1, -3);
        ctx.lineTo(-3, 0);
        ctx.lineTo(-1, 3);
        ctx.closePath();
        ctx.fill();
        break;

      default:
        // Classic White Arrow Ship
        ctx.fillStyle = skin.hullColor;
        ctx.beginPath();
        ctx.moveTo(15, 0); // Nose tip
        ctx.lineTo(-12, -9); // Left rear wing
        ctx.lineTo(-7, 0); // Rear center notch
        ctx.lineTo(-12, 9); // Right rear wing
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = strokeCol;
        ctx.lineWidth = 1.8;
        ctx.stroke();

        ctx.fillStyle = coreCol;
        ctx.beginPath();
        ctx.moveTo(5, 0);
        ctx.lineTo(-4, -3);
        ctx.lineTo(-2, 0);
        ctx.lineTo(-4, 3);
        ctx.closePath();
        ctx.fill();
        break;
    }

    ctx.restore();
  }
}
