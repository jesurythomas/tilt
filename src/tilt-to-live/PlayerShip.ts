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

    // 2. Exact Ship Model Rendering Matching the Armory
    ctx.save();
    // Center the 48x48 viewBox so (24, 24) is at (0, 0)
    ctx.translate(-24, -24);

    const path = new Path2D(skin.svgPath);

    // Hull fill with canonical ship tint
    ctx.fillStyle = this.hasShield() ? '#00ffff' : skin.tint;
    ctx.fill(path);

    // High-contrast 1.4px perimeter border
    ctx.strokeStyle = this.hasShield() ? '#ffffff' : (skin.accentColor || '#ffffff');
    ctx.lineWidth = 1.4;
    ctx.stroke(path);

    // Core energy diode
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(24, 24, 2.2, 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();

    // 3. Thruster Flame Plume
    const flameCol = this.hasShield() ? '#00ffee' : (skin.thrusterColor || skin.tint);
    const flameLen = 6 + Math.random() * 6;
    ctx.fillStyle = flameCol;
    ctx.beginPath();
    ctx.moveTo(-13, -3.5);
    ctx.lineTo(-13 - flameLen, 0);
    ctx.lineTo(-13, 3.5);
    ctx.closePath();
    ctx.fill();

    ctx.restore();
  }
}
