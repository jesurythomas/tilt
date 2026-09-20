// =========================================================================
// WeaponSystem.ts - Weapon Orbs & Superweapon Execution Engine
// =========================================================================

import { ActiveWeapon, Enemy, GameMode, HomingMissile, LightningArc, Point2D, WeaponOrb, WeaponType } from './Types';
import { ParticleEngine } from './ParticleEngine';
import { VectorGrid } from './VectorGrid';
import { TiltAudio } from './TiltAudio';
import { PlayerShip } from './PlayerShip';
import { WeaponPerks } from './ProgressionManager';
import { WEAPON_TUNING, getTunedValue, SUPERNOVA_SHOCKWAVE } from './WeaponTuning';

export class WeaponSystem {
  public orbs: WeaponOrb[] = [];
  public activeWeapons: ActiveWeapon[] = [];
  public missiles: HomingMissile[] = [];
  public lightningArcs: LightningArc[] = [];
  public onWeaponActivated?: (type: WeaponType) => void;

  private nextOrbId: number = 1;
  private nextWeaponId: number = 1;
  private nextMissileId: number = 1;
  private orbSpawnTimer: number = 2.0;

  public readonly weaponTypes: WeaponType[] = [
    'nuke',
    'missiles',
    'lightning',
    'laser',
    'vortex',
    'freeze',
    'shield'
  ];

  public scale: number = 1.0;

  public setScale(scale: number) {
    this.scale = Math.max(0.5, Math.min(1.8, scale));
  }

  public reset() {
    this.orbs = [];
    this.activeWeapons = [];
    this.missiles = [];
    this.lightningArcs = [];
    this.nextOrbId = 1;
    this.nextWeaponId = 1;
    this.nextMissileId = 1;
    this.orbSpawnTimer = 1.5;
  }

  public update(
    dt: number,
    player: PlayerShip,
    enemies: Enemy[],
    bounds: { width: number; height: number },
    particles: ParticleEngine,
    grid: VectorGrid,
    audio: TiltAudio,
    onEnemyKilled: (enemy: Enemy, weaponType: WeaponType) => void,
    perks?: WeaponPerks,
    gameMode: GameMode = 'classic'
  ) {
    // 1. Weapon Orb Spawning (scaled by game mode)
    this.orbSpawnTimer -= dt;
    if (this.orbSpawnTimer <= 0) {
      if (this.orbs.length < 5) {
        // In ALL modes (including Code Red), all weapons spawn (shield, freeze/shockwave, nuke, missiles, laser, lightning)
        // Blackhole ('vortex') is calibrated as a rare, high-impact power-up.
        const type = this.getRandomWeaponType(gameMode);
        this.spawnOrb(bounds, type);
      }
      this.orbSpawnTimer = (gameMode === 'code-red' ? 2.2 : 3.0) + Math.random() * 1.5;
    }

    // 2. Update Orbs (lifetime and collision with player)
    for (let i = this.orbs.length - 1; i >= 0; i--) {
      const orb = this.orbs[i];
      orb.lifetime -= dt;

      if (orb.lifetime <= 0) {
        this.orbs.splice(i, 1);
        continue;
      }

      // Check collision with player ship
      const dx = player.x - orb.x;
      const dy = player.y - orb.y;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist < player.radius + orb.radius) {
        // Collect orb!
        this.activateWeapon(orb.type, orb.x, orb.y, player, enemies, particles, grid, audio, onEnemyKilled, perks);
        this.onWeaponActivated?.(orb.type);
        audio.playOrbPickup();
        particles.emitSparks(orb.x, orb.y, 20, this.getWeaponColor(orb.type), 140);
        this.orbs.splice(i, 1);
      }
    }

    // 3. Update Active Weapons (Nuke, Laser, Vortex)
    for (let i = this.activeWeapons.length - 1; i >= 0; i--) {
      const w = this.activeWeapons[i];
      w.duration -= dt;

      switch (w.type) {
        case 'nuke': {
          // Rapidly expanding blast ring
          const progress = 1 - w.duration / w.maxDuration;
          w.radius = (w.maxRadius || WEAPON_TUNING.nuke.radius.base * this.scale) * progress;

          // Vaporize enemies inside or near blast radius
          for (let eIdx = enemies.length - 1; eIdx >= 0; eIdx--) {
            const e = enemies[eIdx];
            const edx = e.x - w.x;
            const edy = e.y - w.y;
            const eDist = Math.sqrt(edx * edx + edy * edy);

            if (eDist <= w.radius + e.radius + 15) {
              onEnemyKilled(e, 'nuke');
              particles.emitExplosion(e.x, e.y, '#ff3366', 16);
              enemies.splice(eIdx, 1);
            }
          }

          // Distort grid outward
          grid.applyExplosion(w.x, w.y, 16, w.radius + 30);
          break;
        }

        case 'laser': {
          // Dual-ended beam sweeps around player ship
          w.x = player.x;
          w.y = player.y;
          w.angle = (w.angle || 0) + dt * Math.PI * 3.5; // Rapid 360 deg spin
          const beamLength = w.radius || WEAPON_TUNING.laser.length.base * this.scale;

          // Check enemies intersecting line segment from (-beamLength) to (+beamLength)
          const cosA = Math.cos(w.angle);
          const sinA = Math.sin(w.angle);

          for (let eIdx = enemies.length - 1; eIdx >= 0; eIdx--) {
            const e = enemies[eIdx];
            // Project point onto line
            const relX = e.x - w.x;
            const relY = e.y - w.y;
            const proj = relX * cosA + relY * sinA;

            if (Math.abs(proj) <= beamLength) {
              const perpDist = Math.abs(-relX * sinA + relY * cosA);
              if (perpDist <= e.radius + 14) {
                onEnemyKilled(e, 'laser');
                particles.emitSparks(e.x, e.y, 14, '#cc22ff', 200);
                enemies.splice(eIdx, 1);
              }
            }
          }

          // Laser Cross-Beam Keystone Perk
          if (w.data?.crossBeam) {
            const cosB = Math.cos((w.angle || 0) + Math.PI / 2);
            const sinB = Math.sin((w.angle || 0) + Math.PI / 2);

            for (let eIdx = enemies.length - 1; eIdx >= 0; eIdx--) {
              const e = enemies[eIdx];
              const relX = e.x - w.x;
              const relY = e.y - w.y;
              const proj = relX * cosB + relY * sinB;

              if (Math.abs(proj) <= beamLength) {
                const perpDist = Math.abs(-relX * sinB + relY * cosB);
                if (perpDist <= e.radius + 14) {
                  onEnemyKilled(e, 'laser');
                  particles.emitSparks(e.x, e.y, 14, '#cc22ff', 200);
                  enemies.splice(eIdx, 1);
                }
              }
            }
          }
          break;
        }

        case 'vortex': {
          const pullRadius = w.radius || WEAPON_TUNING.blackhole.radius.base * this.scale;
          const pullRadius2 = pullRadius * pullRadius;

          // Event Horizon Cloak Keystone Perk: Player is invulnerable while inside blackhole radius!
          if (w.data?.invulnerableInside) {
            const shipDist = Math.hypot(player.x - w.x, player.y - w.y);
            if (shipDist <= pullRadius) {
              player.activateShield(0.3); // Continuously refreshes invulnerability
              if (Math.random() < 0.25) {
                particles.emitSparks(player.x, player.y, 1, '#b84dff', 40);
              }
            }
          }

          const gravityMultiplier = 1 + (w.data?.gravity || 0) * 0.2;

          for (let eIdx = enemies.length - 1; eIdx >= 0; eIdx--) {
            const e = enemies[eIdx];
            const edx = w.x - e.x;
            const edy = w.y - e.y;
            const dist2 = edx * edx + edy * edy;

            if (dist2 < pullRadius2 && dist2 > 0.1) {
              const dist = Math.sqrt(dist2);
              if (dist <= 30) {
                // Sucked into singularity event horizon!
                onEnemyKilled(e, 'vortex');
                audio.playDotPop(Math.floor(Math.random() * 5));
                particles.emitSparks(e.x, e.y, 14, '#bb66ff', 180);
                enemies.splice(eIdx, 1);
              } else {
                const normDist = dist / pullRadius;
                // Strong quadratic gravity suction curve: up to 1600 px/s^2 near singularity
                const t = Math.max(0, 1 - normDist);
                const gravityAccel = (450 + 1350 * (t * t)) * gravityMultiplier;

                // Inward gravitational acceleration
                e.vx += (edx / dist) * gravityAccel * dt;
                e.vy += (edy / dist) * gravityAccel * dt;

                // Tangential vortex swirl acceleration (orbital accretion spiral)
                const swirlAccel = (300 + 750 * t) * dt * gravityMultiplier;
                e.vx += (-edy / dist) * swirlAccel;
                e.vy += (edx / dist) * swirlAccel;

                // Direct position suction: physically reels enemies into the singularity
                const directSuction = (90 + 340 * t) * dt * gravityMultiplier;
                e.x += (edx / dist) * directSuction;
                e.y += (edy / dist) * directSuction;
              }
            }
          }

          // Pulsing gravitational distortion on spring-mass vector grid
          const pulse = 1.0 + 0.35 * Math.sin((w.maxDuration - w.duration) * 8);
          grid.applyImplosion(w.x, w.y, 16 * pulse, pullRadius * 0.85);

          // Ambient cosmic accretion dust motes
          if (Math.random() < 0.45) {
            const angle = Math.random() * Math.PI * 2;
            const spawnR = 50 + Math.random() * (pullRadius * 0.5);
            particles.emitSparks(
              w.x + Math.cos(angle) * spawnR,
              w.y + Math.sin(angle) * spawnR,
              1,
              Math.random() < 0.5 ? '#b84dff' : '#00e5ff',
              70
            );
          }
          break;
        }
      }

      if (w.duration <= 0) {
        if (w.type === 'vortex') {
          // Collapse Shockwave Detonation!
          const blastRadius = w.data?.supernovaCollapse ? SUPERNOVA_SHOCKWAVE : 260;
          const blastRadius2 = blastRadius * blastRadius;
          audio.playNuke();
          particles.emitExplosion(w.x, w.y, '#9d4edd', w.data?.supernovaCollapse ? 65 : 45);
          particles.emitExplosion(w.x, w.y, '#00f0ff', 35);
          grid.applyExplosion(w.x, w.y, w.data?.supernovaCollapse ? 32 : 22, blastRadius + 140);

          for (let eIdx = enemies.length - 1; eIdx >= 0; eIdx--) {
            const e = enemies[eIdx];
            const dx = e.x - w.x;
            const dy = e.y - w.y;
            if (dx * dx + dy * dy <= blastRadius2) {
              onEnemyKilled(e, 'vortex');
              particles.emitSparks(e.x, e.y, 12, '#c77dff', 200);
              enemies.splice(eIdx, 1);
            }
          }
        }
        this.activeWeapons.splice(i, 1);
      }
    }

    // 4. Update Homing Missiles
    for (let i = this.missiles.length - 1; i >= 0; i--) {
      const m = this.missiles[i];
      m.lifetime -= dt;
      m.smokeTimer += dt;

      // Smoke trail
      if (m.smokeTimer > 0.03) {
        m.smokeTimer = 0;
        particles.emitSmoke(m.x, m.y, 'rgba(255, 140, 20, 0.45)');
      }

      // Retarget closest enemy if current target died or missing
      let target: Enemy | undefined = enemies.find((e) => e.id === m.targetId);
      if (!target && enemies.length > 0) {
        let bestDist = Infinity;
        for (const e of enemies) {
          const d = (e.x - m.x) * (e.x - m.x) + (e.y - m.y) * (e.y - m.y);
          if (d < bestDist) {
            bestDist = d;
            target = e;
          }
        }
        if (target) m.targetId = target.id;
      }

      // Homing guidance
      if (target) {
        const dx = target.x - m.x;
        const dy = target.y - m.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist > 1) {
          const targetVx = (dx / dist) * 440;
          const targetVy = (dy / dist) * 440;
          m.vx += (targetVx - m.vx) * dt * 9;
          m.vy += (targetVy - m.vy) * dt * 9;
        }
      }

      m.x += m.vx * dt;
      m.y += m.vy * dt;

      // Check collision with any enemy
      let hit = false;
      for (let eIdx = enemies.length - 1; eIdx >= 0; eIdx--) {
        const e = enemies[eIdx];
        const edx = e.x - m.x;
        const edy = e.y - m.y;
        if (edx * edx + edy * edy <= (e.radius + 8) * (e.radius + 8)) {
          hit = true;
          break;
        }
      }

      if (hit || m.lifetime <= 0) {
        // Missile blast radius kills cluster; perk-tuned via WeaponTuning
        const blastRadius = getTunedValue('missiles', 'blastRadius', perks?.missiles.blastRadius || 0);
        const blastRadius2 = blastRadius * blastRadius;

        audio.playMissileExplode();
        particles.emitExplosion(m.x, m.y, '#ff8800', 18);
        grid.applyExplosion(m.x, m.y, 8, blastRadius);

        for (let eIdx = enemies.length - 1; eIdx >= 0; eIdx--) {
          const e = enemies[eIdx];
          const edx = e.x - m.x;
          const edy = e.y - m.y;
          if (edx * edx + edy * edy <= blastRadius2) {
            onEnemyKilled(e, 'missiles');
            particles.emitSparks(e.x, e.y, 10, '#ffaa33', 180);
            enemies.splice(eIdx, 1);
          }
        }

        this.missiles.splice(i, 1);
      }
    }

    // 5. Fade out Lightning Arcs
    for (let i = this.lightningArcs.length - 1; i >= 0; i--) {
      this.lightningArcs[i].intensity -= dt * 4;
      if (this.lightningArcs[i].intensity <= 0) {
        this.lightningArcs.splice(i, 1);
      }
    }
  }

  public triggerWeapon(
    type: WeaponType,
    x: number,
    y: number,
    player: PlayerShip,
    enemies: Enemy[],
    particles: ParticleEngine,
    grid: VectorGrid,
    audio: TiltAudio,
    onEnemyKilledOrPerks?: ((enemy: Enemy, weaponType: WeaponType) => void) | WeaponPerks,
    perks?: WeaponPerks
  ) {
    const onKilled = typeof onEnemyKilledOrPerks === 'function' ? onEnemyKilledOrPerks : () => {};
    const effectivePerks = typeof onEnemyKilledOrPerks === 'function' ? perks : onEnemyKilledOrPerks;
    this.activateWeapon(type, x, y, player, enemies, particles, grid, audio, onKilled, effectivePerks);
  }

  public activateWeapon(
    type: WeaponType,
    x: number,
    y: number,
    player: PlayerShip,
    enemies: Enemy[],
    particles: ParticleEngine,
    grid: VectorGrid,
    audio: TiltAudio,
    onEnemyKilled: (enemy: Enemy, weaponType: WeaponType) => void,
    perks?: WeaponPerks
  ) {
    switch (type) {
      case 'nuke': {
        audio.playNuke();
        const maxRadius = getTunedValue('nuke', 'radius', perks?.nuke.radius || 0) * this.scale;
        const duration = 0.65 / (1 + (perks?.nuke.speed || 0) * 0.25);
        this.activeWeapons.push({
          id: this.nextWeaponId++,
          type: 'nuke',
          x,
          y,
          duration,
          maxDuration: duration,
          radius: 10 * this.scale,
          maxRadius
        });
        break;
      }

      case 'missiles': {
        audio.playMissileLaunch();
        const count = 8 + (perks?.missiles.count || 0);
        const speedMult = 1 + (perks?.missiles.flightSpeed || 0) * 0.2;
        for (let i = 0; i < count; i++) {
          const angle = (i * Math.PI * 2) / count + (Math.random() * 0.4 - 0.2);
          const speed = (260 + Math.random() * 80) * speedMult * Math.max(0.72, this.scale);
          this.missiles.push({
            id: this.nextMissileId++,
            x,
            y,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            targetId: null,
            lifetime: 3.5,
            smokeTimer: 0
          });
        }
        break;
      }

      case 'lightning': {
        audio.playLightning();
        let currentOrigin: Point2D = { x, y };
        const visitedIds = new Set<number>();
        const maxChains = 14 + (perks?.lightning.maxTargets || 0) * 3;
        const jumpRange = getTunedValue('lightning', 'chainRange', perks?.lightning.chainRange || 0) * this.scale;

        for (let chain = 0; chain < maxChains; chain++) {
          let nearestEnemy: Enemy | null = null;
          let nearestDist = jumpRange;

          for (const e of enemies) {
            if (visitedIds.has(e.id)) continue;
            const dx = e.x - currentOrigin.x;
            const dy = e.y - currentOrigin.y;
            const dist = Math.sqrt(dx * dx + dy * dy);
            if (dist < nearestDist) {
              nearestDist = dist;
              nearestEnemy = e;
            }
          }

          if (nearestEnemy) {
            visitedIds.add(nearestEnemy.id);

            // Generate lightning arc visual
            const branches: Point2D[] = [];
            const segments = 4;
            for (let s = 1; s < segments; s++) {
              const t = s / segments;
              const bx = currentOrigin.x + (nearestEnemy.x - currentOrigin.x) * t + (Math.random() - 0.5) * 24 * this.scale;
              const by = currentOrigin.y + (nearestEnemy.y - currentOrigin.y) * t + (Math.random() - 0.5) * 24 * this.scale;
              branches.push({ x: bx, y: by });
            }

            this.lightningArcs.push({
              x1: currentOrigin.x,
              y1: currentOrigin.y,
              x2: nearestEnemy.x,
              y2: nearestEnemy.y,
              intensity: 1.0,
              branches
            });

            currentOrigin = { x: nearestEnemy.x, y: nearestEnemy.y };
          } else {
            break;
          }
        }

        // Kill all electrocuted dots
        for (let eIdx = enemies.length - 1; eIdx >= 0; eIdx--) {
          const e = enemies[eIdx];
          if (visitedIds.has(e.id)) {
            onEnemyKilled(e, 'lightning');
            particles.emitSparks(e.x, e.y, 12, '#ffee33', 220);
            enemies.splice(eIdx, 1);
          }
        }
        break;
      }

      case 'laser': {
        audio.playLaserBeam();
        const beamLength = getTunedValue('laser', 'length', perks?.laser.length || 0) * this.scale;
        const duration = 1.8 + (perks?.laser.duration || 0) * 0.4;
        this.activeWeapons.push({
          id: this.nextWeaponId++,
          type: 'laser',
          x: player.x,
          y: player.y,
          duration,
          maxDuration: duration,
          radius: beamLength,
          angle: player.angle,
          data: { crossBeam: !!perks?.laser.crossBeam }
        });
        break;
      }

      case 'vortex': {
        audio.playVortex();
        const duration = 4.8 + (perks?.blackhole.duration || 0) * 0.5;
        const radius = getTunedValue('blackhole', 'radius', perks?.blackhole.radius || 0) * this.scale;
        this.activeWeapons.push({
          id: this.nextWeaponId++,
          type: 'vortex',
          x,
          y,
          duration,
          maxDuration: duration,
          radius,
          data: {
            invulnerableInside: !!perks?.blackhole.invulnerableInside,
            gravity: perks?.blackhole.gravity || 0,
            supernovaCollapse: !!perks?.blackhole.supernovaCollapse
          }
        });
        break;
      }

      case 'freeze': {
        audio.playFreeze();
        const freezeDuration = 4.5 + (perks?.freeze.duration || 0) * 0.7;
        for (const e of enemies) {
          e.frozen = true;
          e.freezeTimer = freezeDuration;
        }
        particles.emitIceShatter(x, y, 40);
        grid.applyExplosion(x, y, 10, 360 * this.scale);
        break;
      }

      case 'shield': {
        const shieldDuration = 6.0 + (perks?.shield.duration || 0) * 1.0;
        player.activateShield(shieldDuration);
        particles.emitSparks(player.x, player.y, 25, '#3DDC97', 160);
        break;
      }
    }
  }

  public getRandomWeaponType(_gameMode: GameMode = 'classic'): WeaponType {
    // Weighted probabilities:
    // Missiles: 20%, Nuke: 18%, Laser: 18%, Lightning: 16%, Freeze: 16%, Shield: 16%, Blackhole (Vortex): 5% (Rare!)
    const weights: Record<WeaponType, number> = {
      missiles: 20,
      nuke: 18,
      laser: 18,
      lightning: 16,
      freeze: 16,
      shield: 16,
      vortex: 5
    };

    const entries = Object.entries(weights) as [WeaponType, number][];
    const total = entries.reduce((acc, [, w]) => acc + w, 0);
    let roll = Math.random() * total;
    for (const [t, w] of entries) {
      if (roll < w) return t;
      roll -= w;
    }
    return 'missiles';
  }

  public spawnOrb(bounds: { width: number; height: number }, specificType?: WeaponType, customX?: number, customY?: number) {
    const pad = Math.max(30, 60 * this.scale);
    const x = customX !== undefined ? customX : pad + Math.random() * (bounds.width - pad * 2);
    const y = customY !== undefined ? customY : pad + Math.random() * (bounds.height - pad * 2);
    const type = specificType || this.getRandomWeaponType();

    this.orbs.push({
      id: this.nextOrbId++,
      type,
      x,
      y,
      radius: 16 * this.scale,
      spawnTime: performance.now(),
      lifetime: 12.0,
      pulseOffset: Math.random() * Math.PI * 2
    });
  }

  public getWeaponColor(type: WeaponType): string {
    switch (type) {
      case 'nuke': return '#ff0055';
      case 'missiles': return '#ff8800';
      case 'lightning': return '#ffdd00';
      case 'laser': return '#cc22ff';
      case 'vortex': return '#8822ff';
      case 'freeze': return '#8FB0FF';
      case 'shield': return '#3DDC97';
    }
  }

  public render(ctx: CanvasRenderingContext2D, elapsed: number) {
    ctx.save();

    // 1. Render Active Weapons
    for (const w of this.activeWeapons) {
      if (w.type === 'nuke') {
        const progress = 1 - w.duration / w.maxDuration;
        const alpha = Math.max(0, 1 - progress);

        // Multiple expanding concentric shockwave rings
        ctx.strokeStyle = `rgba(255, 0, 85, ${alpha * 0.9})`;
        ctx.lineWidth = 6 * alpha;
        ctx.beginPath();
        ctx.arc(w.x, w.y, w.radius, 0, Math.PI * 2);
        ctx.stroke();

        ctx.strokeStyle = `rgba(255, 230, 120, ${alpha * 0.8})`;
        ctx.lineWidth = 3 * alpha;
        ctx.beginPath();
        ctx.arc(w.x, w.y, Math.max(1, w.radius - 8), 0, Math.PI * 2);
        ctx.stroke();

        // Inner translucent core
        ctx.fillStyle = `rgba(255, 30, 80, ${alpha * 0.25})`;
        ctx.beginPath();
        ctx.arc(w.x, w.y, w.radius, 0, Math.PI * 2);
        ctx.fill();
      } else if (w.type === 'laser') {
        const beamLength = w.radius || WEAPON_TUNING.laser.length.base * this.scale;
        const cosA = Math.cos(w.angle || 0);
        const sinA = Math.sin(w.angle || 0);

        // Primary Core laser beam
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.moveTo(w.x - cosA * beamLength, w.y - sinA * beamLength);
        ctx.lineTo(w.x + cosA * beamLength, w.y + sinA * beamLength);
        ctx.stroke();

        // Primary Violet energy aura
        ctx.strokeStyle = 'rgba(204, 34, 255, 0.65)';
        ctx.lineWidth = 14;
        ctx.beginPath();
        ctx.moveTo(w.x - cosA * beamLength, w.y - sinA * beamLength);
        ctx.lineTo(w.x + cosA * beamLength, w.y + sinA * beamLength);
        ctx.stroke();

        // Perpendicular Cross-Beam
        if (w.data?.crossBeam) {
          const cosB = Math.cos((w.angle || 0) + Math.PI / 2);
          const sinB = Math.sin((w.angle || 0) + Math.PI / 2);

          ctx.strokeStyle = '#ffffff';
          ctx.lineWidth = 5;
          ctx.beginPath();
          ctx.moveTo(w.x - cosB * beamLength, w.y - sinB * beamLength);
          ctx.lineTo(w.x + cosB * beamLength, w.y + sinB * beamLength);
          ctx.stroke();

          ctx.strokeStyle = 'rgba(204, 34, 255, 0.65)';
          ctx.lineWidth = 14;
          ctx.beginPath();
          ctx.moveTo(w.x - cosB * beamLength, w.y - sinB * beamLength);
          ctx.lineTo(w.x + cosB * beamLength, w.y + sinB * beamLength);
          ctx.stroke();
        }
      } else if (w.type === 'vortex') {
        // Swirling cosmic black hole singularity
        const pulse = 0.85 + 0.15 * Math.sin(elapsed * 12);
        const radius = 36 * pulse;
        const pullRadius = w.radius || WEAPON_TUNING.blackhole.radius.base * this.scale;

        // 1. Gravitational Lensing Distortions (multiple concentric rings)
        const ringAlpha = 0.22 + 0.08 * Math.sin(elapsed * 6);
        ctx.strokeStyle = `rgba(160, 40, 255, ${ringAlpha})`;
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.arc(w.x, w.y, pullRadius * 0.75, 0, Math.PI * 2);
        ctx.stroke();

        ctx.strokeStyle = `rgba(0, 240, 255, ${ringAlpha * 0.75})`;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(w.x, w.y, pullRadius * 0.45, 0, Math.PI * 2);
        ctx.stroke();

        ctx.strokeStyle = `rgba(200, 80, 255, ${ringAlpha * 1.2})`;
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(w.x, w.y, pullRadius * 0.22, 0, Math.PI * 2);
        ctx.stroke();

        // 2. Accretion Disk Logarithmic Spiral Arms
        ctx.save();
        ctx.translate(w.x, w.y);
        ctx.rotate(elapsed * 7.5);
        ctx.shadowColor = '#bb44ff';
        ctx.shadowBlur = 20;

        for (let arm = 0; arm < 6; arm++) {
          ctx.beginPath();
          const baseAngle = (arm * Math.PI) / 3;
          ctx.strokeStyle = arm % 2 === 0 ? '#bb44ff' : '#00e5ff';
          ctx.lineWidth = 2.5;

          for (let r = 12; r < 100; r += 4) {
            const a = baseAngle + r * 0.09;
            const px = Math.cos(a) * r;
            const py = Math.sin(a) * r;
            if (r === 12) ctx.moveTo(px, py);
            else ctx.lineTo(px, py);
          }
          ctx.stroke();
        }

        // 3. Glowing Ultraviolet Photon Ring (Event Horizon)
        ctx.shadowColor = '#df80ff';
        ctx.shadowBlur = 25;
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(0, 0, radius * 0.85, 0, Math.PI * 2);
        ctx.stroke();

        // 4. Dark Singularity Core Void
        ctx.fillStyle = '#020005';
        ctx.beginPath();
        ctx.arc(0, 0, radius * 0.75, 0, Math.PI * 2);
        ctx.fill();

        ctx.restore();
      }
    }

    // 2. Render Homing Missiles
    for (const m of this.missiles) {
      const angle = Math.atan2(m.vy, m.vx);
      ctx.save();
      ctx.translate(m.x, m.y);
      ctx.rotate(angle);

      // Rocket body
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(-6, -2.5, 12, 5);

      // Warhead
      ctx.fillStyle = '#ff4400';
      ctx.beginPath();
      ctx.moveTo(6, -2.5);
      ctx.lineTo(10, 0);
      ctx.lineTo(6, 2.5);
      ctx.closePath();
      ctx.fill();

      // Rear engine thrust flame
      ctx.fillStyle = '#ffcc00';
      ctx.beginPath();
      ctx.moveTo(-6, -2);
      ctx.lineTo(-11 - Math.random() * 4, 0);
      ctx.lineTo(-6, 2);
      ctx.closePath();
      ctx.fill();

      ctx.restore();
    }

    // 3. Render Lightning Arcs
    for (const arc of this.lightningArcs) {
      ctx.strokeStyle = `rgba(255, 240, 100, ${arc.intensity})`;
      ctx.lineWidth = 2.5 * arc.intensity;
      ctx.beginPath();
      ctx.moveTo(arc.x1, arc.y1);
      for (const b of arc.branches) {
        ctx.lineTo(b.x, b.y);
      }
      ctx.lineTo(arc.x2, arc.y2);
      ctx.stroke();
    }

    // 4. Render Floating Weapon Orbs
    for (const orb of this.orbs) {
      const pulse = 0.88 + 0.12 * Math.sin(elapsed * 6 + orb.pulseOffset);
      const color = this.getWeaponColor(orb.type);
      const isExpiring = orb.lifetime < 3.0 && Math.floor(elapsed * 8) % 2 === 0;

      if (isExpiring) continue; // Blinking warning

      ctx.save();
      ctx.translate(orb.x, orb.y);

      // Outer Pulsing Glow
      ctx.fillStyle = `${color}33`;
      ctx.beginPath();
      ctx.arc(0, 0, (orb.radius + 8) * pulse, 0, Math.PI * 2);
      ctx.fill();

      // Translucent Orb Bubble
      const bubbleGrad = ctx.createRadialGradient(-3, -3, 2, 0, 0, orb.radius);
      bubbleGrad.addColorStop(0, '#ffffff');
      bubbleGrad.addColorStop(0.4, color);
      bubbleGrad.addColorStop(1, '#110520');
      ctx.fillStyle = bubbleGrad;
      ctx.beginPath();
      ctx.arc(0, 0, orb.radius, 0, Math.PI * 2);
      ctx.fill();

      // Sharp Neon Perimeter
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 1.8;
      ctx.stroke();

      // Iconic Weapon Glyph Symbols
      this.renderOrbGlyph(ctx, orb.type);

      ctx.restore();
    }

    ctx.restore();
  }

  private renderOrbGlyph(ctx: CanvasRenderingContext2D, type: WeaponType) {
    ctx.fillStyle = '#ffffff';
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 1.6;

    switch (type) {
      case 'nuke': {
        // Radioactive trefoil dot
        ctx.beginPath();
        ctx.arc(0, 0, 2.5, 0, Math.PI * 2);
        ctx.fill();
        for (let i = 0; i < 3; i++) {
          const a = (i * Math.PI * 2) / 3;
          ctx.beginPath();
          ctx.arc(0, 0, 8, a - 0.45, a + 0.45);
          ctx.stroke();
        }
        break;
      }
      case 'missiles': {
        // Rocket symbol
        ctx.beginPath();
        ctx.moveTo(0, -7);
        ctx.lineTo(4, 5);
        ctx.lineTo(0, 2);
        ctx.lineTo(-4, 5);
        ctx.closePath();
        ctx.fill();
        break;
      }
      case 'lightning': {
        // Lightning bolt
        ctx.beginPath();
        ctx.moveTo(2, -7);
        ctx.lineTo(-4, 0);
        ctx.lineTo(0, 0);
        ctx.lineTo(-2, 7);
        ctx.lineTo(4, 0);
        ctx.lineTo(0, 0);
        ctx.closePath();
        ctx.fill();
        break;
      }
      case 'laser': {
        // Crossed laser beams
        ctx.beginPath();
        ctx.moveTo(-6, -6); ctx.lineTo(6, 6);
        ctx.moveTo(6, -6); ctx.lineTo(-6, 6);
        ctx.stroke();
        break;
      }
      case 'vortex': {
        // Spiral icon
        ctx.beginPath();
        for (let r = 2; r < 8; r += 1) {
          const a = r * 0.9;
          const px = Math.cos(a) * r;
          const py = Math.sin(a) * r;
          if (r === 2) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.stroke();
        break;
      }
      case 'freeze': {
        // Snowflake crystal
        for (let i = 0; i < 6; i++) {
          const a = (i * Math.PI) / 3;
          ctx.beginPath();
          ctx.moveTo(0, 0);
          ctx.lineTo(Math.cos(a) * 7, Math.sin(a) * 7);
          ctx.stroke();
        }
        break;
      }
      case 'shield': {
        // Shield outline
        ctx.beginPath();
        ctx.moveTo(0, -6);
        ctx.lineTo(5, -3);
        ctx.lineTo(4, 3);
        ctx.lineTo(0, 7);
        ctx.lineTo(-4, 3);
        ctx.lineTo(-5, -3);
        ctx.closePath();
        ctx.stroke();
        break;
      }
    }
  }
}
