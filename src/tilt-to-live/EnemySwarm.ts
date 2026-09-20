// =========================================================================
// EnemySwarm.ts - Red Dot Swarm Intelligence & Wave Director
// =========================================================================

import { Enemy, GameMode, Point2D } from './Types';
import { ParticleEngine } from './ParticleEngine';

export class EnemySwarm {
  public enemies: Enemy[] = [];
  private nextEnemyId: number = 1;
  private spawnTimer: number = 0;
  private waveTimer: number = 0;
  private elapsed: number = 0;
  private wallDirectionCycle: number = 0;

  constructor() {
    this.reset();
  }

  public scale: number = 1.0;

  public setScale(scale: number) {
    this.scale = Math.max(0.5, Math.min(1.8, scale));
  }

  // Progression-driven uniform movement slow (ProgressionManager.getEnemySpeedMultiplier()).
  // Defaults to 1.0 (unchanged) so nothing changes until wired. Scales only the
  // per-frame translation of enemy movement — never spawn timers, spawn thresholds,
  // attack/fire cooldowns, or scoring.
  private speedScale: number = 1.0;

  public setSpeedScale(scale: number) {
    this.speedScale = Math.max(0.1, Math.min(2, scale));
  }

  public reset() {
    this.enemies = [];
    this.nextEnemyId = 1;
    this.spawnTimer = 0.5;
    this.waveTimer = 4.0;
    this.elapsed = 0;
    this.wallDirectionCycle = 0;
  }

  public update(
    dt: number,
    playerPos: Point2D,
    bounds: { width: number; height: number },
    particles: ParticleEngine,
    currentScore: number = 0,
    gameMode: GameMode = 'classic'
  ) {
    this.elapsed += dt;
    this.spawnTimer -= dt;
    this.waveTimer -= dt;

    const isCodeRed = gameMode === 'code-red';

    // 1. Continuous Seeker Spawning with Mode Escalation
    if (this.spawnTimer <= 0) {
      const timeReduction = this.elapsed * 0.005;
      const scoreReduction = Math.min(0.35, (currentScore / 30000) * 0.35);

      if (isCodeRed) {
        // Code Red: fast twin spawns with elite units appearing immediately
        this.spawnTimer = 0.32 + Math.random() * 0.12;
        if (currentScore >= 24000 && Math.random() < 0.28) {
          this.spawnCarrier(bounds, playerPos);
        } else if (currentScore >= 16000 && Math.random() < 0.26) {
          this.spawnPulsar(bounds, playerPos);
        } else if (currentScore >= 10000 && Math.random() < 0.30) {
          this.spawnArtillery(bounds, playerPos);
        } else if (currentScore >= 6000 && Math.random() < 0.28) {
          this.spawnSpecter(bounds, playerPos);
        } else if (currentScore >= 2500 && Math.random() < 0.35) {
          this.spawnCharger(bounds, playerPos);
        } else {
          this.spawnSeeker(bounds);
          this.spawnSeeker(bounds);
        }
      } else {
        // Classic & Gauntlet standard pacing with score-based variety unlocks
        let baseInterval = Math.max(0.42, 1.35 - timeReduction - scoreReduction);
        this.spawnTimer = baseInterval + Math.random() * 0.15;

        // Variety unlock: chargers at 5k, specters at 10k, artillery at 16k, pulsars at 22k, carriers at 32k!
        if (currentScore >= 32000 && Math.random() < 0.22) {
          this.spawnCarrier(bounds, playerPos);
        } else if (currentScore >= 22000 && Math.random() < 0.26) {
          this.spawnPulsar(bounds, playerPos);
        } else if (currentScore >= 16000 && Math.random() < 0.28) {
          this.spawnArtillery(bounds, playerPos);
        } else if (currentScore >= 10000 && Math.random() < 0.26) {
          this.spawnSpecter(bounds, playerPos);
        } else if (currentScore >= 5000 && Math.random() < 0.32) {
          this.spawnCharger(bounds, playerPos);
        } else {
          const spawnCount = currentScore >= 12000 && Math.random() < 0.25 ? 2 : 1;
          for (let s = 0; s < spawnCount; s++) {
            this.spawnSeeker(bounds);
          }
        }
      }
    }

    // 2. Coordinated Formation Waves with Mode Specialization
    if (this.waveTimer <= 0) {
      if (isCodeRed) {
        // Code Red: rapid-fire aggressive ambushes including horizontal & vertical wall sweeps
        const roll = Math.random();
        if (roll < 0.35) {
          this.spawnWallFormation(bounds); // Line sweep (horizontal or vertical)
        } else if (roll < 0.70) {
          this.spawnArrowFormation(bounds, true); // Dual pincer attack
        } else {
          this.spawnCircleEncirclement(playerPos, bounds, currentScore, true); // Tight circle
        }
        this.waveTimer = 3.6 + Math.random() * 1.2;
      } else if (gameMode === 'gauntlet') {
        // Gauntlet: strictly excludes vertical and horizontal wall sweeps (handled by descending walls)
        this.triggerGauntletFormation(playerPos, bounds, currentScore);
        const scoreWaveReduction = Math.min(2.0, (currentScore / 25000) * 2.0);
        const baseWaveInterval = Math.max(8.5, 13.5 - this.elapsed * 0.02 - scoreWaveReduction);
        this.waveTimer = baseWaveInterval + Math.random() * 2.5;
      } else {
        // Classic: standard formations including frequent horizontal & vertical wall sweeps
        this.triggerRandomFormation(playerPos, bounds, currentScore);
        const scoreWaveReduction = Math.min(2.0, (currentScore / 25000) * 2.0);
        const baseWaveInterval = Math.max(5.5, 10.0 - this.elapsed * 0.02 - scoreWaveReduction);
        this.waveTimer = baseWaveInterval + Math.random() * 2.0;
      }
    }

    // 3. Update Individual Enemy Physics & Logic
    for (let i = this.enemies.length - 1; i >= 0; i--) {
      const e = this.enemies[i];
      e.age += dt;

      // Handle Frozen state
      if (e.frozen) {
        e.freezeTimer -= dt;
        if (e.freezeTimer <= 0) {
          e.frozen = false;
        }
        continue; // Frozen dots don't move or steer
      }

      // Movement behavior by type
      switch (e.type) {
        case 'seeker':
          this.updateSeeker(e, playerPos, dt, currentScore, isCodeRed);
          break;
        case 'arrow_drone':
          this.updateArrowDrone(e, dt);
          break;
        case 'circle_dot':
          this.updateCircleDot(e, playerPos, dt);
          break;
        case 'wall_dot':
          this.updateWallDot(e, dt);
          break;
        case 'turret_dot':
          if (e.orbitCenter) {
            this.updateRotatingGateDot(e, dt);
          } else {
            this.updateTurretDot(e, playerPos, dt);
          }
          break;
        case 'spike_mine':
          e.x += e.vx * dt * this.speedScale;
          e.y += e.vy * dt * this.speedScale;
          break;
        case 'snake_segment':
          this.updateSnakeSegment(e, dt);
          break;
        case 'charger':
          this.updateCharger(e, playerPos, dt, particles);
          break;
        case 'artillery':
          this.updateArtillery(e, playerPos, dt);
          break;
        case 'bullet':
          this.updateBullet(e, dt, bounds);
          if (e.age > 4.5 || e.x < -60 || e.x > bounds.width + 60 || e.y < -60 || e.y > bounds.height + 60) {
            this.enemies.splice(i, 1);
            continue;
          }
          break;
        case 'carrier':
          this.updateCarrier(e, playerPos, dt);
          break;
        case 'pulsar':
          this.updatePulsar(e, playerPos, dt, particles);
          break;
        case 'specter':
          this.updateSpecter(e, playerPos, dt);
          break;
      }

      // Remove out of bounds drones that completed sweeps
      if (
        (e.type === 'arrow_drone' || e.type === 'wall_dot' || e.type === 'bullet') &&
        (e.x < -140 || e.x > bounds.width + 140 || e.y < -140 || e.y > bounds.height + 140)
      ) {
        this.enemies.splice(i, 1);
        continue;
      }

      // Clamp standard enemies inside playfield
      if (e.type !== 'arrow_drone' && e.type !== 'wall_dot' && e.type !== 'bullet' && !e.orbitCenter && !e.parentCarrierId) {
        const pad = e.radius;
        if (e.x < pad) { e.x = pad; e.vx = Math.abs(e.vx) * 0.5; }
        if (e.x > bounds.width - pad) { e.x = bounds.width - pad; e.vx = -Math.abs(e.vx) * 0.5; }
        if (e.y < pad) { e.y = pad; e.vy = Math.abs(e.vy) * 0.5; }
        if (e.y > bounds.height - pad) { e.y = bounds.height - pad; e.vy = -Math.abs(e.vy) * 0.5; }
      }
    }

    // 4. Inter-Dot Flocking Separation (except hazard walls and rotating gates)
    this.applyFlockingSeparation();
  }

  private updateSeeker(
    e: Enemy,
    playerPos: Point2D,
    dt: number,
    currentScore: number = 0,
    isCodeRed: boolean = false
  ) {
    const dx = playerPos.x - e.x;
    const dy = playerPos.y - e.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist > 1) {
      const scoreSpeedBonus = Math.min(25, (currentScore / 25000) * 25);
      let targetSpeed = Math.min(195, 105 + this.elapsed * 0.5 + scoreSpeedBonus) * Math.max(0.72, this.scale);

      // Mode-specific physics
      if (isCodeRed) {
        targetSpeed *= 1.35; // 35% faster in Code Red
      }
      if (e.chilled) {
        targetSpeed *= 0.45; // 55% slow in Cryo Aura
      }

      const targetVx = (dx / dist) * targetSpeed;
      const targetVy = (dy / dist) * targetSpeed;

      const steerStrength = (isCodeRed ? 4.5 : 3.2) * dt;
      e.vx += (targetVx - e.vx) * steerStrength;
      e.vy += (targetVy - e.vy) * steerStrength;
    }

    e.x += e.vx * dt * this.speedScale;
    e.y += e.vy * dt * this.speedScale;
  }

  private updateArrowDrone(e: Enemy, dt: number) {
    e.x += e.vx * dt * this.speedScale;
    e.y += e.vy * dt * this.speedScale;
  }

  private updateCircleDot(e: Enemy, playerPos: Point2D, dt: number) {
    if (e.specialTimer !== undefined && e.specialTimer > 0) {
      e.specialTimer -= dt;
      e.vx = 0;
      e.vy = 0;
      return;
    }

    const dx = playerPos.x - e.x;
    const dy = playerPos.y - e.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist > 1) {
      const speed = (75 + this.elapsed * 0.4) * Math.max(0.72, this.scale);
      e.vx = (dx / dist) * speed;
      e.vy = (dy / dist) * speed;
    }

    e.x += e.vx * dt * this.speedScale;
    e.y += e.vy * dt * this.speedScale;
  }

  private updateWallDot(e: Enemy, dt: number) {
    e.x += e.vx * dt * this.speedScale;
    e.y += e.vy * dt * this.speedScale;
  }

  private updateRotatingGateDot(e: Enemy, dt: number) {
    if (!e.orbitCenter || e.orbitRadius === undefined || e.orbitSpeed === undefined) return;
    if (e.targetAngle === undefined) e.targetAngle = 0;
    e.targetAngle += e.orbitSpeed * dt * this.speedScale;
    e.x = e.orbitCenter.x + Math.cos(e.targetAngle) * e.orbitRadius;
    e.y = e.orbitCenter.y + Math.sin(e.targetAngle) * e.orbitRadius;
  }

  private updateTurretDot(e: Enemy, playerPos: Point2D, dt: number) {
    const targetAngle = Math.atan2(playerPos.y - e.y, playerPos.x - e.x);
    if (e.targetAngle === undefined) e.targetAngle = targetAngle;

    let diff = targetAngle - e.targetAngle;
    while (diff < -Math.PI) diff += Math.PI * 2;
    while (diff > Math.PI) diff -= Math.PI * 2;
    e.targetAngle += diff * Math.min(1, dt * 2.5);

    e.x += e.vx * dt * this.speedScale;
    e.y += e.vy * dt * this.speedScale;
  }

  private updateSnakeSegment(e: Enemy, dt: number) {
    if (!e.leaderId) {
      e.x += e.vx * dt * this.speedScale;
      e.y += e.vy * dt * this.speedScale;
      if (Math.random() < 0.05) {
        const speed = 120;
        const angle = Math.random() * Math.PI * 2;
        e.vx = Math.cos(angle) * speed;
        e.vy = Math.sin(angle) * speed;
      }
    } else {
      const leader = this.enemies.find((other) => other.id === e.leaderId);
      if (leader) {
        const dx = leader.x - e.x;
        const dy = leader.y - e.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        const targetDist = 18;
        if (dist > targetDist) {
          const factor = (dist - targetDist) / dist;
          e.x += dx * factor * 0.4;
          e.y += dy * factor * 0.4;
        }
      }
    }
  }

  private updateCharger(e: Enemy, playerPos: Point2D, dt: number, particles: ParticleEngine) {
    if (!e.state) e.state = 'aiming';
    if (e.aimTimer === undefined) e.aimTimer = 1.1;

    if (e.state === 'aiming') {
      const dx = playerPos.x - e.x;
      const dy = playerPos.y - e.y;
      e.aimAngle = Math.atan2(dy, dx);

      // Creep forward slowly while locking on
      const creepSpeed = 35;
      e.vx = Math.cos(e.aimAngle) * creepSpeed;
      e.vy = Math.sin(e.aimAngle) * creepSpeed;
      e.x += e.vx * dt * this.speedScale;
      e.y += e.vy * dt * this.speedScale;

      e.aimTimer -= dt;
      if (e.aimTimer <= 0) {
        e.state = 'charging';
        e.specialTimer = 0.75; // Charge burst duration
        const chargeSpeed = 480;
        e.vx = Math.cos(e.aimAngle) * chargeSpeed;
        e.vy = Math.sin(e.aimAngle) * chargeSpeed;
      }
    } else if (e.state === 'charging') {
      e.x += e.vx * dt * this.speedScale;
      e.y += e.vy * dt * this.speedScale;

      if (Math.random() < 0.6) {
        const backAngle = (e.aimAngle || 0) + Math.PI;
        particles.emitThrusterSparks(e.x, e.y, backAngle, '#ff5500');
      }

      if (e.specialTimer !== undefined) {
        e.specialTimer -= dt;
        if (e.specialTimer <= 0) {
          e.state = 'cooling';
          e.specialTimer = 0.9;
        }
      }
    } else if (e.state === 'cooling') {
      e.vx *= Math.pow(0.08, dt);
      e.vy *= Math.pow(0.08, dt);
      e.x += e.vx * dt * this.speedScale;
      e.y += e.vy * dt * this.speedScale;

      if (e.specialTimer !== undefined) {
        e.specialTimer -= dt;
        if (e.specialTimer <= 0) {
          e.state = 'aiming';
          e.aimTimer = 1.1;
        }
      }
    }
  }

  private updateArtillery(e: Enemy, playerPos: Point2D, dt: number) {
    if (e.fireCooldown === undefined) e.fireCooldown = 2.6 + Math.random() * 0.8;

    const dx = playerPos.x - e.x;
    const dy = playerPos.y - e.y;
    const dist = Math.sqrt(dx * dx + dy * dy);
    e.aimAngle = Math.atan2(dy, dx);

    let moveVx = 0;
    let moveVy = 0;
    if (dist > 1) {
      const nx = dx / dist;
      const ny = dy / dist;
      if (dist < 220) {
        moveVx -= nx * 65;
        moveVy -= ny * 65;
      } else if (dist > 320) {
        moveVx += nx * 60;
        moveVy += ny * 60;
      }
      const strafeDir = (e.id % 2 === 0) ? 1 : -1;
      moveVx += -ny * strafeDir * 40;
      moveVy += nx * strafeDir * 40;
    }

    const steer = 3.0 * dt;
    e.vx += (moveVx - e.vx) * steer;
    e.vy += (moveVy - e.vy) * steer;
    e.x += e.vx * dt * this.speedScale;
    e.y += e.vy * dt * this.speedScale;

    e.fireCooldown -= dt;
    if (e.fireCooldown <= 0) {
      e.fireCooldown = 2.8 + Math.random() * 0.8;
      const barrelLen = 22;
      const fireX = e.x + Math.cos(e.aimAngle) * barrelLen;
      const fireY = e.y + Math.sin(e.aimAngle) * barrelLen;
      this.spawnBullet(fireX, fireY, playerPos);

      // Recoil
      e.vx -= Math.cos(e.aimAngle) * 90;
      e.vy -= Math.sin(e.aimAngle) * 90;
    }
  }

  private updateBullet(e: Enemy, dt: number, _bounds: { width: number; height: number }) {
    e.x += e.vx * dt * this.speedScale;
    e.y += e.vy * dt * this.speedScale;
  }

  private updateCarrier(e: Enemy, playerPos: Point2D, dt: number) {
    const dx = playerPos.x - e.x;
    const dy = playerPos.y - e.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist > 1) {
      const targetSpeed = 55;
      const targetVx = (dx / dist) * targetSpeed;
      const targetVy = (dy / dist) * targetSpeed;
      e.vx += (targetVx - e.vx) * 1.5 * dt;
      e.vy += (targetVy - e.vy) * 1.5 * dt;
    }

    e.x += e.vx * dt * this.speedScale;
    e.y += e.vy * dt * this.speedScale;

    for (let i = 0; i < this.enemies.length; i++) {
      const sat = this.enemies[i];
      if (sat.parentCarrierId === e.id) {
        if (sat.orbitAngle === undefined) sat.orbitAngle = 0;
        if (sat.orbitRadius === undefined) sat.orbitRadius = 38;
        sat.orbitAngle += 2.0 * dt * this.speedScale;
        sat.x = e.x + Math.cos(sat.orbitAngle) * sat.orbitRadius;
        sat.y = e.y + Math.sin(sat.orbitAngle) * sat.orbitRadius;
        sat.vx = 0;
        sat.vy = 0;
      }
    }
  }

  private updatePulsar(e: Enemy, playerPos: Point2D, dt: number, particles: ParticleEngine) {
    const dx = playerPos.x - e.x;
    const dy = playerPos.y - e.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist > 1) {
      const speed = 72 * Math.max(0.72, this.scale);
      e.vx += ((dx / dist) * speed - e.vx) * 2.2 * dt;
      e.vy += ((dy / dist) * speed - e.vy) * 2.2 * dt;
    }
    e.x += e.vx * dt * this.speedScale;
    e.y += e.vy * dt * this.speedScale;

    if (e.pulseTimer === undefined) e.pulseTimer = 2.2;
    e.pulseTimer -= dt;
    if (e.pulseTimer <= 0) {
      e.pulseTimer = 2.2;
      particles.emitSparks(e.x, e.y, 14, '#ff4757', 140);
    }
  }

  private updateSpecter(e: Enemy, playerPos: Point2D, dt: number) {
    const dx = playerPos.x - e.x;
    const dy = playerPos.y - e.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist > 1) {
      const speed = 145 * Math.max(0.72, this.scale);
      e.vx += ((dx / dist) * speed - e.vx) * 3.8 * dt;
      e.vy += ((dy / dist) * speed - e.vy) * 3.8 * dt;
    }
    e.x += e.vx * dt * this.speedScale;
    e.y += e.vy * dt * this.speedScale;

    e.stealthOpacity = 0.25 + 0.75 * Math.pow(Math.sin(e.age * 3.2), 2);
  }

  private applyFlockingSeparation() {
    const minDistance = 16;
    const minDistance2 = minDistance * minDistance;

    const count = this.enemies.length;
    for (let i = 0; i < count; i++) {
      const a = this.enemies[i];
      if (a.frozen || a.type === 'wall_dot' || a.type === 'bullet' || a.orbitCenter || a.parentCarrierId) continue;

      for (let j = i + 1; j < count; j++) {
        const b = this.enemies[j];
        if (b.frozen || b.type === 'wall_dot' || b.type === 'bullet' || b.orbitCenter || b.parentCarrierId) continue;

        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const dist2 = dx * dx + dy * dy;

        if (dist2 < minDistance2 && dist2 > 0.0001) {
          const dist = Math.sqrt(dist2);
          const push = (minDistance - dist) * 0.15;
          const px = (dx / dist) * push;
          const py = (dy / dist) * push;

          a.x -= px;
          a.y -= py;
          b.x += px;
          b.y += py;
        }
      }
    }
  }

  // --- Spawning Formations ---

  public spawnSeeker(bounds: { width: number; height: number }, customX?: number, customY?: number): Enemy {
    let x = customX;
    let y = customY;
    if (x === undefined || y === undefined) {
      const edge = Math.floor(Math.random() * 4);
      const margin = 20;

      switch (edge) {
        case 0: x = Math.random() * bounds.width; y = -margin; break;
        case 1: x = bounds.width + margin; y = Math.random() * bounds.height; break;
        case 2: x = Math.random() * bounds.width; y = bounds.height + margin; break;
        default: x = -margin; y = Math.random() * bounds.height; break;
      }
    }

    const enemy: Enemy = {
      id: this.nextEnemyId++,
      type: 'seeker',
      x,
      y,
      vx: 0,
      vy: 0,
      radius: 8.5 * this.scale,
      frozen: false,
      freezeTimer: 0,
      age: 0,
      health: 1
    };
    this.enemies.push(enemy);
    return enemy;
  }

  public spawnCharger(bounds: { width: number; height: number }, playerPos: Point2D): Enemy {
    const edge = Math.floor(Math.random() * 4);
    const margin = 25;
    let x = 0;
    let y = 0;
    switch (edge) {
      case 0: x = Math.random() * bounds.width; y = -margin; break;
      case 1: x = bounds.width + margin; y = Math.random() * bounds.height; break;
      case 2: x = Math.random() * bounds.width; y = bounds.height + margin; break;
      default: x = -margin; y = Math.random() * bounds.height; break;
    }

    const aimAngle = Math.atan2(playerPos.y - y, playerPos.x - x);
    const enemy: Enemy = {
      id: this.nextEnemyId++,
      type: 'charger',
      x,
      y,
      vx: 0,
      vy: 0,
      radius: 11 * this.scale,
      frozen: false,
      freezeTimer: 0,
      age: 0,
      health: 1,
      state: 'aiming',
      aimAngle,
      aimTimer: 1.1
    };
    this.enemies.push(enemy);
    return enemy;
  }

  public spawnPulsar(bounds: { width: number; height: number }, _playerPos: Point2D): Enemy {
    const edge = Math.floor(Math.random() * 4);
    const margin = 26;
    let x = 0;
    let y = 0;
    switch (edge) {
      case 0: x = Math.random() * bounds.width; y = -margin; break;
      case 1: x = bounds.width + margin; y = Math.random() * bounds.height; break;
      case 2: x = Math.random() * bounds.width; y = bounds.height + margin; break;
      default: x = -margin; y = Math.random() * bounds.height; break;
    }

    const enemy: Enemy = {
      id: this.nextEnemyId++,
      type: 'pulsar',
      x,
      y,
      vx: 0,
      vy: 0,
      radius: 12.5 * this.scale,
      frozen: false,
      freezeTimer: 0,
      age: 0,
      health: 2,
      pulseTimer: 2.2
    };
    this.enemies.push(enemy);
    return enemy;
  }

  public spawnSpecter(bounds: { width: number; height: number }, _playerPos: Point2D): Enemy {
    const edge = Math.floor(Math.random() * 4);
    const margin = 20;
    let x = 0;
    let y = 0;
    switch (edge) {
      case 0: x = Math.random() * bounds.width; y = -margin; break;
      case 1: x = bounds.width + margin; y = Math.random() * bounds.height; break;
      case 2: x = Math.random() * bounds.width; y = bounds.height + margin; break;
      default: x = -margin; y = Math.random() * bounds.height; break;
    }

    const enemy: Enemy = {
      id: this.nextEnemyId++,
      type: 'specter',
      x,
      y,
      vx: 0,
      vy: 0,
      radius: 8 * this.scale,
      frozen: false,
      freezeTimer: 0,
      age: 0,
      health: 1,
      stealthOpacity: 0.8
    };
    this.enemies.push(enemy);
    return enemy;
  }

  public spawnArtillery(bounds: { width: number; height: number }, playerPos: Point2D): Enemy {
    const edge = Math.floor(Math.random() * 4);
    const margin = 28;
    let x = 0;
    let y = 0;
    switch (edge) {
      case 0: x = Math.random() * bounds.width; y = -margin; break;
      case 1: x = bounds.width + margin; y = Math.random() * bounds.height; break;
      case 2: x = Math.random() * bounds.width; y = bounds.height + margin; break;
      default: x = -margin; y = Math.random() * bounds.height; break;
    }

    const aimAngle = Math.atan2(playerPos.y - y, playerPos.x - x);
    const enemy: Enemy = {
      id: this.nextEnemyId++,
      type: 'artillery',
      x,
      y,
      vx: 0,
      vy: 0,
      radius: 13 * this.scale,
      frozen: false,
      freezeTimer: 0,
      age: 0,
      health: 2,
      aimAngle,
      fireCooldown: 2.2 + Math.random() * 0.8
    };
    this.enemies.push(enemy);
    return enemy;
  }

  public spawnBullet(originX: number, originY: number, targetPos: Point2D): Enemy {
    const dx = targetPos.x - originX;
    const dy = targetPos.y - originY;
    const dist = Math.max(1, Math.sqrt(dx * dx + dy * dy));
    const speed = 260 * Math.max(0.72, this.scale);

    const bullet: Enemy = {
      id: this.nextEnemyId++,
      type: 'bullet',
      x: originX,
      y: originY,
      vx: (dx / dist) * speed,
      vy: (dy / dist) * speed,
      radius: 5.5 * this.scale,
      frozen: false,
      freezeTimer: 0,
      age: 0,
      health: 1
    };
    this.enemies.push(bullet);
    return bullet;
  }

  public spawnCarrier(bounds: { width: number; height: number }, _playerPos: Point2D): Enemy {
    const edge = Math.floor(Math.random() * 4);
    const margin = 35;
    let x = 0;
    let y = 0;
    switch (edge) {
      case 0: x = Math.random() * bounds.width; y = -margin; break;
      case 1: x = bounds.width + margin; y = Math.random() * bounds.height; break;
      case 2: x = Math.random() * bounds.width; y = bounds.height + margin; break;
      default: x = -margin; y = Math.random() * bounds.height; break;
    }

    const carrier: Enemy = {
      id: this.nextEnemyId++,
      type: 'carrier',
      x,
      y,
      vx: 0,
      vy: 0,
      radius: 18 * this.scale,
      frozen: false,
      freezeTimer: 0,
      age: 0,
      health: 4
    };
    this.enemies.push(carrier);

    // Spawn 4 protective orbiting satellite mini-dots around the carrier
    const satelliteCount = 4;
    for (let k = 0; k < satelliteCount; k++) {
      const angle = (k * Math.PI * 2) / satelliteCount;
      const orbitRadius = 38 * this.scale;
      const satellite: Enemy = {
        id: this.nextEnemyId++,
        type: 'seeker',
        x: x + Math.cos(angle) * orbitRadius,
        y: y + Math.sin(angle) * orbitRadius,
        vx: 0,
        vy: 0,
        radius: 6 * this.scale,
        frozen: false,
        freezeTimer: 0,
        age: 0,
        health: 1,
        parentCarrierId: carrier.id,
        orbitAngle: angle,
        orbitRadius
      };
      this.enemies.push(satellite);
    }

    return carrier;
  }

  /**
   * Spawns an immediate, dramatic start armada tailored specifically to the mode!
   */
  public spawnModeArmada(mode: GameMode, bounds: { width: number; height: number }, playerPos: Point2D) {
    if (mode === 'code-red') {
      // Massive 24-dot perimeter encirclement closing in from the start!
      const count = 24;
      const radius = Math.min(bounds.width, bounds.height) * 0.44;
      for (let i = 0; i < count; i++) {
        const angle = (i * Math.PI * 2) / count;
        const x = playerPos.x + Math.cos(angle) * radius;
        const y = playerPos.y + Math.sin(angle) * radius;
        this.spawnSeeker(bounds, x, y);
      }
    } else {
      // Classic & Gauntlet: standard perimeter swarm
      const count = 8;
      for (let i = 0; i < count; i++) {
        this.spawnSeeker(bounds);
      }
    }
  }

  public triggerRandomFormation(
    playerPos: Point2D,
    bounds: { width: number; height: number },
    currentScore: number = 0
  ) {
    const choices = ['arrow', 'circle', 'wall', 'turret', 'snake'];
    const choice = choices[Math.floor(Math.random() * choices.length)];

    switch (choice) {
      case 'arrow':
        this.spawnArrowFormation(bounds);
        break;
      case 'circle':
        this.spawnCircleEncirclement(playerPos, bounds, currentScore);
        break;
      case 'wall':
        this.spawnWallFormation(bounds);
        break;
      case 'turret':
        this.spawnTurret(bounds);
        break;
      case 'snake':
        this.spawnSnake(bounds);
        break;
    }
  }

  public triggerGauntletFormation(
    _playerPos: Point2D,
    bounds: { width: number; height: number },
    _currentScore: number = 0
  ) {
    // Gauntlet mode strictly excludes 'wall' (vertical/horizontal sweeps) and 'circle' (encirclements)
    // Only fair directional waves that can be navigated alongside descending walls:
    const choices = ['arrow', 'turret', 'snake'];
    const choice = choices[Math.floor(Math.random() * choices.length)];

    switch (choice) {
      case 'arrow':
        this.spawnArrowFormation(bounds);
        break;
      case 'turret':
        this.spawnTurret(bounds);
        break;
      case 'snake':
        this.spawnSnake(bounds);
        break;
    }
  }

  public spawnArrowFormation(bounds: { width: number; height: number }, isDualPincer: boolean = false) {
    const wings = isDualPincer ? [true, false] : [Math.random() < 0.5];

    for (const fromLeft of wings) {
      const startX = fromLeft ? -60 : bounds.width + 60;
      const startY = 100 + Math.random() * (bounds.height - 200);
      const speed = (fromLeft ? 260 : -260) * Math.max(0.72, this.scale);

      const rowOffsets = [
        { rx: 0, ry: 0 },
        { rx: -22, ry: -18 }, { rx: -22, ry: 18 },
        { rx: -44, ry: -36 }, { rx: -44, ry: 36 },
        { rx: -66, ry: -54 }, { rx: -66, ry: 54 }
      ];

      for (const off of rowOffsets) {
        this.enemies.push({
          id: this.nextEnemyId++,
          type: 'arrow_drone',
          x: startX + (fromLeft ? off.rx * this.scale : -off.rx * this.scale),
          y: startY + off.ry * this.scale,
          vx: speed,
          vy: 0,
          radius: 8 * this.scale,
          frozen: false,
          freezeTimer: 0,
          age: 0,
          health: 1
        });
      }
    }
  }

  public spawnCircleEncirclement(
    playerPos: Point2D,
    _bounds: { width: number; height: number },
    currentScore: number = 0,
    isTight: boolean = false
  ) {
    const count = isTight ? 16 : Math.min(16, 12 + Math.floor(currentScore / 10000));
    const radius = (isTight ? 180 : 260) * this.scale;
    const pauseDuration = isTight ? 0.75 : 1.25;

    for (let i = 0; i < count; i++) {
      const angle = (i * Math.PI * 2) / count;
      const x = playerPos.x + Math.cos(angle) * radius;
      const y = playerPos.y + Math.sin(angle) * radius;

      this.enemies.push({
        id: this.nextEnemyId++,
        type: 'circle_dot',
        x,
        y,
        vx: 0,
        vy: 0,
        radius: 8 * this.scale,
        frozen: false,
        freezeTimer: 0,
        age: 0,
        specialTimer: pauseDuration,
        health: 1
      });
    }
  }

  public spawnWallFormation(bounds: { width: number; height: number }) {
    const horizontal = Math.random() < 0.5;
    const spacing = 22 * this.scale;

    if (horizontal) {
      const fromTop = Math.random() < 0.5;
      const y = fromTop ? -30 : bounds.height + 30;
      const vy = (fromTop ? 140 : -140) * Math.max(0.72, this.scale);
      const numDots = Math.floor(bounds.width / spacing);
      const gapIndex = 2 + Math.floor(Math.random() * (numDots - 4));

      for (let i = 0; i < numDots; i++) {
        if (Math.abs(i - gapIndex) <= 2) continue; // Gap for player
        this.enemies.push({
          id: this.nextEnemyId++,
          type: 'wall_dot',
          x: i * spacing + 10,
          y,
          vx: 0,
          vy,
          radius: 8 * this.scale,
          frozen: false,
          freezeTimer: 0,
          age: 0,
          health: 1
        });
      }
    } else {
      const fromLeft = Math.random() < 0.5;
      const x = fromLeft ? -30 : bounds.width + 30;
      const vx = (fromLeft ? 140 : -140) * Math.max(0.72, this.scale);
      const numDots = Math.floor(bounds.height / spacing);
      const gapIndex = 2 + Math.floor(Math.random() * (numDots - 4));

      for (let i = 0; i < numDots; i++) {
        if (Math.abs(i - gapIndex) <= 2) continue;
        this.enemies.push({
          id: this.nextEnemyId++,
          type: 'wall_dot',
          x,
          y: i * spacing + 10,
          vx,
          vy: 0,
          radius: 8 * this.scale,
          frozen: false,
          freezeTimer: 0,
          age: 0,
          health: 1
        });
      }
    }
  }

  /**
   * Gauntlet mode: Sequential sweeping wall corridors with alternating safe gaps
   */
  public spawnSequentialGauntletWall(bounds: { width: number; height: number }) {
    const dir = this.wallDirectionCycle % 4;
    this.wallDirectionCycle++;
    const spacing = 22 * this.scale;
    const speed = 150 * Math.max(0.72, this.scale);

    if (dir === 0) {
      // Top to Bottom
      const numDots = Math.floor(bounds.width / spacing);
      const gapIndex = Math.floor(numDots * 0.25);
      for (let i = 0; i < numDots; i++) {
        if (Math.abs(i - gapIndex) <= 3) continue; // 80px safe corridor
        this.enemies.push({
          id: this.nextEnemyId++,
          type: 'wall_dot',
          x: i * spacing + 10,
          y: -30,
          vx: 0,
          vy: speed,
          radius: 8.5 * this.scale,
          frozen: false,
          freezeTimer: 0,
          age: 0,
          health: 1,
          isHazard: true
        });
      }
    } else if (dir === 1) {
      // Right to Left
      const numDots = Math.floor(bounds.height / spacing);
      const gapIndex = Math.floor(numDots * 0.7);
      for (let i = 0; i < numDots; i++) {
        if (Math.abs(i - gapIndex) <= 3) continue;
        this.enemies.push({
          id: this.nextEnemyId++,
          type: 'wall_dot',
          x: bounds.width + 30,
          y: i * spacing + 10,
          vx: -speed,
          vy: 0,
          radius: 8.5,
          frozen: false,
          freezeTimer: 0,
          age: 0,
          health: 1,
          isHazard: true
        });
      }
    } else if (dir === 2) {
      // Bottom to Top
      const numDots = Math.floor(bounds.width / spacing);
      const gapIndex = Math.floor(numDots * 0.75);
      for (let i = 0; i < numDots; i++) {
        if (Math.abs(i - gapIndex) <= 3) continue;
        this.enemies.push({
          id: this.nextEnemyId++,
          type: 'wall_dot',
          x: i * spacing + 10,
          y: bounds.height + 30,
          vx: 0,
          vy: -speed,
          radius: 8.5,
          frozen: false,
          freezeTimer: 0,
          age: 0,
          health: 1,
          isHazard: true
        });
      }
    } else {
      // Left to Right
      const numDots = Math.floor(bounds.height / spacing);
      const gapIndex = Math.floor(numDots * 0.3);
      for (let i = 0; i < numDots; i++) {
        if (Math.abs(i - gapIndex) <= 3) continue;
        this.enemies.push({
          id: this.nextEnemyId++,
          type: 'wall_dot',
          x: -30,
          y: i * spacing + 10,
          vx: speed,
          vy: 0,
          radius: 8.5,
          frozen: false,
          freezeTimer: 0,
          age: 0,
          health: 1,
          isHazard: true
        });
      }
    }
  }

  /**
   * Gauntlet mode: Central rotating obstacle gate cross
   */
  public spawnRotatingGate(bounds: { width: number; height: number }) {
    const cx = bounds.width / 2;
    const cy = bounds.height / 2;
    const speed = (Math.random() < 0.5 ? 1 : -1) * 0.75;
    const offsets = [-80, -56, -32, 32, 56, 80];

    for (const off of offsets) {
      this.enemies.push({
        id: this.nextEnemyId++,
        type: 'turret_dot',
        x: cx + off,
        y: cy,
        vx: 0,
        vy: 0,
        radius: 8.5,
        frozen: false,
        freezeTimer: 0,
        age: 0,
        health: 1,
        orbitCenter: { x: cx, y: cy },
        orbitRadius: Math.abs(off),
        orbitSpeed: speed,
        targetAngle: off > 0 ? 0 : Math.PI,
        isHazard: true
      });
    }
  }



  private spawnTurret(bounds: { width: number; height: number }) {
    const pad = 80;
    const x = pad + Math.random() * (bounds.width - pad * 2);
    const y = pad + Math.random() * (bounds.height - pad * 2);

    this.enemies.push({
      id: this.nextEnemyId++,
      type: 'turret_dot',
      x,
      y,
      vx: (Math.random() - 0.5) * 30,
      vy: (Math.random() - 0.5) * 30,
      radius: 12 * this.scale,
      frozen: false,
      freezeTimer: 0,
      age: 0,
      health: 3
    });
  }

  private spawnSnake(_bounds: { width: number; height: number }) {
    const startX = 60 + Math.random() * (_bounds.width - 120);
    const startY = 60 + Math.random() * (_bounds.height - 120);
    const length = 8;

    for (let i = 0; i < length; i++) {
      const enemy: Enemy = {
        id: this.nextEnemyId++,
        type: 'snake_segment',
        x: startX - i * 14 * this.scale,
        y: startY,
        vx: 110 * Math.max(0.72, this.scale),
        vy: 0,
        radius: (i === 0 ? 10 : 8) * this.scale,
        frozen: false,
        freezeTimer: 0,
        age: 0,
        health: 1
      };
      this.enemies.push(enemy);
    }
  }

  public onEnemyKilled(enemy: Enemy, particles?: ParticleEngine) {
    if (enemy.type === 'carrier') {
      // Free all orbiting satellite children and fling them outward
      for (const e of this.enemies) {
        if (e.parentCarrierId === enemy.id) {
          e.parentCarrierId = undefined;
          const scatterAngle = Math.random() * Math.PI * 2;
          const speed = 160 + Math.random() * 80;
          e.vx = Math.cos(scatterAngle) * speed;
          e.vy = Math.sin(scatterAngle) * speed;
          if (particles) {
            particles.emitSparks(e.x, e.y, 8, '#00e5ff', 200);
          }
        }
      }
      if (particles) {
        particles.emitExplosion(enemy.x, enemy.y, '#ff1155', 40);
      }
    } else if (enemy.type === 'pulsar') {
      // Pulsar explodes and splits into two aggressive mini-seekers
      for (let i = 0; i < 2; i++) {
        const angle = i * Math.PI + (Math.random() * 0.8 - 0.4);
        const speed = 135 + Math.random() * 45;
        this.enemies.push({
          id: this.nextEnemyId++,
          type: 'seeker',
          x: enemy.x + Math.cos(angle) * 10,
          y: enemy.y + Math.sin(angle) * 10,
          vx: Math.cos(angle) * speed,
          vy: Math.sin(angle) * speed,
          radius: 6.5 * this.scale,
          frozen: false,
          freezeTimer: 0,
          age: 0,
          health: 1
        });
      }
      if (particles) {
        particles.emitExplosion(enemy.x, enemy.y, '#ff4757', 24);
      }
    }
  }

  public freezeAll(duration: number = 7.0) {
    for (const e of this.enemies) {
      e.frozen = true;
      e.freezeTimer = duration;
    }
  }

  public render(
    ctx: CanvasRenderingContext2D,
    elapsed: number,
    skin?: import('./ProgressionManager').EnemySkinConfig,
    highContrastHalo: boolean = true,
    _gameMode: GameMode = 'classic'
  ) {
    ctx.save();
    for (const e of this.enemies) {
      ctx.save();
      ctx.translate(e.x, e.y);

      // Frozen Dot Appearance
      if (e.frozen) {
        ctx.fillStyle = 'rgba(136, 238, 255, 0.45)';
        ctx.beginPath();
        ctx.arc(0, 0, e.radius + 3, 0, Math.PI * 2);
        ctx.fill();

        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(0, 0, e.radius + 1, 0, Math.PI * 2);
        ctx.stroke();

        ctx.fillStyle = '#4488aa';
        ctx.beginPath();
        ctx.arc(0, 0, e.radius - 1, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
        continue;
      }

      // 1. Charger Drone (High-speed straight-line dart with targeting laser telegraph)
      if (e.type === 'charger') {
        const angle = e.state === 'charging' ? Math.atan2(e.vy, e.vx) : (e.aimAngle ?? 0);

        // Laser telegraph line while aiming
        if (e.state === 'aiming') {
          ctx.save();
          ctx.rotate(angle);
          const dashOffset = (elapsed * 50) % 16;
          ctx.strokeStyle = `rgba(255, 60, 30, ${0.4 + 0.4 * Math.sin(elapsed * 22)})`;
          ctx.lineWidth = 1.5;
          ctx.setLineDash([8, 6]);
          ctx.lineDashOffset = -dashOffset;
          ctx.beginPath();
          ctx.moveTo(14, 0);
          ctx.lineTo(480, 0);
          ctx.stroke();
          ctx.setLineDash([]);
          ctx.restore();
        }

        ctx.rotate(angle);

        // Rocket Thruster Plume if charging
        if (e.state === 'charging') {
          const jetLen = 14 + Math.random() * 8;
          ctx.fillStyle = '#ffaa00';
          ctx.beginPath();
          ctx.moveTo(-8, -4);
          ctx.lineTo(-8 - jetLen, 0);
          ctx.lineTo(-8, 4);
          ctx.closePath();
          ctx.fill();
        }

        // Arrowhead Delta Dart Chassis
        const chargerHull = skin && skin.id !== 'classic' ? skin.bodyGradient[1] : (e.state === 'charging' ? '#ff2a00' : '#dd1c00');
        const chargerEdge = skin && skin.id !== 'classic' ? skin.borderColor : '#ffaa33';
        ctx.fillStyle = chargerHull;
        ctx.strokeStyle = chargerEdge;
        ctx.lineWidth = 1.8;
        ctx.beginPath();
        ctx.moveTo(14, 0); // Nose
        ctx.lineTo(-10, -11); // Left wing
        ctx.lineTo(-6, 0); // Center notch
        ctx.lineTo(-10, 11); // Right wing
        ctx.closePath();
        ctx.fill();
        ctx.stroke();

        // Cockpit / Energy Crystal Core
        ctx.fillStyle = e.state === 'charging' ? '#ffffff' : (skin && skin.id !== 'classic' ? skin.pupilColor : '#FFB14D');
        ctx.beginPath();
        ctx.moveTo(6, 0);
        ctx.lineTo(-2, -3.5);
        ctx.lineTo(0, 0);
        ctx.lineTo(-2, 3.5);
        ctx.closePath();
        ctx.fill();

        ctx.restore();
        continue;
      }

      // 2. Artillery Siege Unit (Hexagonal tank with cannon & ranged plasma attacks)
      if (e.type === 'artillery') {
        const angle = e.aimAngle ?? 0;
        ctx.rotate(angle);

        const artBarrel = skin && skin.id !== 'classic' ? skin.borderColor : '#ff0066';
        // Cannon barrel
        ctx.fillStyle = '#180e22';
        ctx.strokeStyle = artBarrel;
        ctx.lineWidth = 1.5;
        ctx.fillRect(4, -4, 18, 8);
        ctx.strokeRect(4, -4, 18, 8);

        // Muzzle charge flash if preparing to fire
        if (e.fireCooldown !== undefined && e.fireCooldown < 0.8) {
          const chargeRatio = (0.8 - e.fireCooldown) / 0.8;
          ctx.fillStyle = `rgba(255, 0, 150, ${0.5 + chargeRatio * 0.5})`;
          ctx.beginPath();
          ctx.arc(22, 0, 3 + chargeRatio * 4, 0, Math.PI * 2);
          ctx.fill();
        }

        // Heavy Hexagonal Hull
        const artHull = skin && skin.id !== 'classic' ? skin.bodyGradient[2] : '#1c0a1a';
        const artEdge = skin && skin.id !== 'classic' ? skin.borderColor : '#ff0077';
        ctx.fillStyle = artHull;
        ctx.strokeStyle = artEdge;
        ctx.lineWidth = 2.2;
        ctx.beginPath();
        const hexRadius = 13;
        for (let h = 0; h < 6; h++) {
          const a = (h * Math.PI) / 3;
          const hx = Math.cos(a) * hexRadius;
          const hy = Math.sin(a) * hexRadius;
          if (h === 0) ctx.moveTo(hx, hy);
          else ctx.lineTo(hx, hy);
        }
        ctx.closePath();
        ctx.fill();
        ctx.stroke();

        // Armored cross struts
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(-hexRadius, 0); ctx.lineTo(hexRadius, 0);
        ctx.moveTo(0, -hexRadius); ctx.lineTo(0, hexRadius);
        ctx.stroke();

        // Pulsing optic sensor eye
        const opticPulse = 0.8 + 0.2 * Math.sin(elapsed * 14);
        ctx.fillStyle = skin && skin.id !== 'classic' ? skin.bodyGradient[0] : '#ff00bb';
        ctx.beginPath();
        ctx.arc(0, 0, 5 * opticPulse, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.arc(0, 0, 2, 0, Math.PI * 2);
        ctx.fill();

        ctx.restore();
        continue;
      }

      // 3. Artillery Plasma Bullet
      if (e.type === 'bullet') {
        const bAngle = Math.atan2(e.vy, e.vx);
        ctx.rotate(bAngle);

        // Plasma comet tail
        const tailGrad = ctx.createLinearGradient(-18, 0, 0, 0);
        tailGrad.addColorStop(0, 'rgba(255, 0, 128, 0)');
        tailGrad.addColorStop(1, 'rgba(255, 0, 180, 0.85)');
        ctx.fillStyle = tailGrad;
        ctx.beginPath();
        ctx.moveTo(-18, 0);
        ctx.lineTo(0, -4);
        ctx.lineTo(0, 4);
        ctx.closePath();
        ctx.fill();

        // Core plasma energy ball
        const bGrad = ctx.createRadialGradient(0, 0, 1, 0, 0, e.radius);
        bGrad.addColorStop(0, '#ffffff');
        bGrad.addColorStop(0.5, '#ff2299');
        bGrad.addColorStop(1, '#880055');
        ctx.fillStyle = bGrad;
        ctx.beginPath();
        ctx.arc(0, 0, e.radius, 0, Math.PI * 2);
        ctx.fill();

        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1.2;
        ctx.stroke();

        ctx.restore();
        continue;
      }

      // 4. Orbital Carrier Mothership
      if (e.type === 'carrier') {
        // Tether arcs to children satellites
        for (const sat of this.enemies) {
          if (sat.parentCarrierId === e.id) {
            ctx.save();
            ctx.strokeStyle = `rgba(0, 229, 255, ${0.4 + 0.3 * Math.sin(elapsed * 12 + sat.id)})`;
            ctx.lineWidth = 1.2;
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(sat.x - e.x, sat.y - e.y);
            ctx.stroke();
            ctx.restore();
          }
        }

        ctx.rotate(elapsed * 0.45);

        // Pulsing orbital shield ring
        const carrierRing = skin && skin.id !== 'classic' ? skin.glowColor : 'rgba(255, 30, 80, 0.45)';
        ctx.strokeStyle = carrierRing;
        ctx.lineWidth = 2;
        ctx.setLineDash([10, 8]);
        ctx.lineDashOffset = -elapsed * 30;
        ctx.beginPath();
        ctx.arc(0, 0, e.radius + 8, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);

        // Diamond Dreadnought Mothership Hull
        const carrierHull = skin && skin.id !== 'classic' ? skin.bodyGradient[2] : '#220816';
        const carrierEdge = skin && skin.id !== 'classic' ? skin.borderColor : '#ff2a55';
        ctx.fillStyle = carrierHull;
        ctx.strokeStyle = carrierEdge;
        ctx.lineWidth = 2.4;
        ctx.beginPath();
        ctx.moveTo(e.radius + 4, 0);
        ctx.lineTo(0, -e.radius - 4);
        ctx.lineTo(-e.radius - 4, 0);
        ctx.lineTo(0, e.radius + 4);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();

        // Inner glowing core
        ctx.fillStyle = skin && skin.id !== 'classic' ? skin.bodyGradient[0] : '#ff1144';
        ctx.beginPath();
        ctx.arc(0, 0, 8, 0, Math.PI * 2);
        ctx.fill();

        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.arc(0, 0, 3.5, 0, Math.PI * 2);
        ctx.fill();

        ctx.restore();
        continue;
      }

      // 5. Orbiting Satellite Mini-Dot (Shield Drone)
      if (e.parentCarrierId !== undefined) {
        ctx.strokeStyle = '#00e5ff';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(0, 0, e.radius + 3, 0, Math.PI * 2);
        ctx.stroke();

        ctx.fillStyle = 'rgba(0, 229, 255, 0.35)';
        ctx.beginPath();
        ctx.arc(0, 0, e.radius + 2, 0, Math.PI * 2);
        ctx.fill();

        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.arc(0, 0, e.radius * 0.5, 0, Math.PI * 2);
        ctx.fill();

        ctx.restore();
        continue;
      }

      // 6. Pulsar Shockwave Unit (Pulsing energy corona ring)
      if (e.type === 'pulsar') {
        const pulsePhase = e.pulseTimer !== undefined ? (2.2 - e.pulseTimer) / 2.2 : 0;
        const ringRadius = e.radius + 5 + pulsePhase * 16;
        const ringAlpha = (1 - pulsePhase) * 0.8;

        ctx.save();
        ctx.globalAlpha = Math.max(0, ringAlpha);
        ctx.strokeStyle = skin ? skin.borderColor : '#ff4757';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(0, 0, ringRadius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.restore();

        const [inner, mid, outer] = skin ? skin.bodyGradient : ['#ff8899', '#ee1133', '#990011'];
        const pulsarGrad = ctx.createRadialGradient(0, 0, 1, 0, 0, e.radius);
        pulsarGrad.addColorStop(0, inner);
        pulsarGrad.addColorStop(0.6, mid);
        pulsarGrad.addColorStop(1, outer);

        ctx.fillStyle = pulsarGrad;
        ctx.strokeStyle = skin ? skin.borderColor : '#ffa502';
        ctx.lineWidth = 2.2;
        ctx.beginPath();
        ctx.arc(0, 0, e.radius, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();

        // Pulsar spinning star core
        ctx.fillStyle = skin ? skin.pupilColor : '#ffffff';
        ctx.beginPath();
        for (let p = 0; p < 8; p++) {
          const a = (p * Math.PI) / 4 + elapsed * 3;
          const r = p % 2 === 0 ? e.radius * 0.55 : e.radius * 0.22;
          const px = Math.cos(a) * r;
          const py = Math.sin(a) * r;
          if (p === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.closePath();
        ctx.fill();

        ctx.restore();
        continue;
      }

      // 7. Phasing Specter (Translucent stealth drone)
      if (e.type === 'specter') {
        const alpha = e.stealthOpacity ?? 0.65;
        ctx.globalAlpha = alpha;

        // Phasing dashed perimeter
        ctx.strokeStyle = skin ? skin.borderColor : '#a78bfa';
        ctx.lineWidth = 1.6;
        ctx.setLineDash([4, 4]);
        ctx.lineDashOffset = -elapsed * 25;
        ctx.beginPath();
        ctx.arc(0, 0, e.radius + 3, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);

        const [inner, mid, outer] = skin ? skin.bodyGradient : ['#c4b5fd', '#8b5cf6', '#4c1d95'];
        const specterGrad = ctx.createRadialGradient(0, 0, 1, 0, 0, e.radius);
        specterGrad.addColorStop(0, inner);
        specterGrad.addColorStop(0.65, mid);
        specterGrad.addColorStop(1, outer);

        ctx.fillStyle = specterGrad;
        ctx.strokeStyle = skin ? skin.borderColor : '#e0e7ff';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(0, 0, e.radius, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();

        // White core eye
        ctx.fillStyle = skin ? skin.pupilColor : '#ffffff';
        ctx.beginPath();
        ctx.arc(0, 0, 2.5, 0, Math.PI * 2);
        ctx.fill();

        ctx.restore();
        continue;
      }

      // Evil Dot Appearance (Themed by Mode & equipped Skin)
      const pulse = 0.85 + 0.15 * Math.sin(elapsed * 9 + e.id);

      // Outer Glow & High Contrast Halo
      if (highContrastHalo) {
        if (e.chilled) {
          ctx.strokeStyle = 'rgba(140, 240, 255, 0.7)';
        } else if (skin) {
          ctx.strokeStyle = skin.glowColor;
        } else if (e.isHazard) {
          ctx.strokeStyle = 'rgba(255, 180, 0, 0.7)';
        } else {
          ctx.strokeStyle = 'rgba(255, 30, 60, 0.7)';
        }
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.arc(0, 0, (e.radius + 5) * pulse, 0, Math.PI * 2);
        ctx.stroke();
      }

      // Outer Glow Color
      if (e.chilled) {
        ctx.fillStyle = 'rgba(130, 230, 255, 0.55)';
      } else if (skin) {
        ctx.fillStyle = skin.glowColor;
      } else if (e.isHazard) {
        ctx.fillStyle = 'rgba(255, 170, 0, 0.45)';
      } else {
        ctx.fillStyle = 'rgba(255, 30, 60, 0.35)';
      }
      ctx.beginPath();
      ctx.arc(0, 0, (e.radius + 4) * pulse, 0, Math.PI * 2);
      ctx.fill();

      // Core Vibrant Body Gradient
      const bodyGrad = ctx.createRadialGradient(0, 0, 1, 0, 0, e.radius);
      if (e.chilled) {
        bodyGrad.addColorStop(0, '#e0f8ff');
        bodyGrad.addColorStop(0.65, '#55bbff');
        bodyGrad.addColorStop(1, '#115599');
      } else if (skin) {
        bodyGrad.addColorStop(0, skin.bodyGradient[0]);
        bodyGrad.addColorStop(0.65, skin.bodyGradient[1]);
        bodyGrad.addColorStop(1, skin.bodyGradient[2]);
      } else if (e.isHazard) {
        bodyGrad.addColorStop(0, '#fff066');
        bodyGrad.addColorStop(0.65, '#ffaa00');
        bodyGrad.addColorStop(1, '#884400');
      } else {
        bodyGrad.addColorStop(0, '#ff6677');
        bodyGrad.addColorStop(0.65, '#ee1133');
        bodyGrad.addColorStop(1, '#990011');
      }
      ctx.fillStyle = bodyGrad;
      ctx.beginPath();
      ctx.arc(0, 0, e.radius, 0, Math.PI * 2);
      ctx.fill();

      ctx.strokeStyle = e.chilled
        ? '#aae6ff'
        : skin
        ? skin.borderColor
        : e.isHazard
        ? '#ffd555'
        : '#ff8899';
      ctx.lineWidth = 1.2;
      ctx.stroke();

      // Theme Pupil / Core Dot
      ctx.fillStyle = e.chilled
        ? '#002244'
        : skin
        ? skin.pupilColor
        : e.isHazard
        ? '#221100'
        : '#110005';
      ctx.beginPath();
      ctx.arc(0, 0, e.radius * 0.38, 0, Math.PI * 2);
      ctx.fill();

      // Turret Dot Warning Indicator
      if (e.type === 'turret_dot' && e.targetAngle !== undefined && !e.orbitCenter) {
        ctx.rotate(e.targetAngle);
        ctx.strokeStyle = 'rgba(255, 50, 50, 0.5)';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(e.radius, 0);
        ctx.lineTo(e.radius + 18, 0);
        ctx.stroke();
      }

      ctx.restore();
    }
    ctx.restore();
  }
}
