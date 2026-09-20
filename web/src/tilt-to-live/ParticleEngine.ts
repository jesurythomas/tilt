// =========================================================================
// ParticleEngine.ts - High-Performance Vector Particle System
// =========================================================================

export interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  size: number;
  color: string;
  shape: 'circle' | 'streak' | 'ring' | 'shard';
  decay: number;
  friction: number;
}

export class ParticleEngine {
  private particles: Particle[] = [];
  private readonly maxParticles: number = 900;

  public reset() {
    this.particles = [];
  }

  public update(dt: number) {
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= p.friction;
      p.vy *= p.friction;
      p.life -= dt;

      if (p.shape === 'ring') {
        p.size += 220 * dt;
      }

      if (p.life <= 0) {
        this.particles.splice(i, 1);
      }
    }
  }

  public emitSparks(x: number, y: number, count: number, color: string, speedMax: number = 180) {
    for (let i = 0; i < count; i++) {
      if (this.particles.length >= this.maxParticles) break;
      const angle = Math.random() * Math.PI * 2;
      const speed = 20 + Math.random() * speedMax;
      const life = 0.3 + Math.random() * 0.45;

      this.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life,
        maxLife: life,
        size: 2 + Math.random() * 2.5,
        color,
        shape: Math.random() < 0.4 ? 'streak' : 'circle',
        decay: 1,
        friction: 0.94
      });
    }
  }

  public emitExplosion(x: number, y: number, color: string = '#ff3344', count: number = 32) {
    this.emitSparks(x, y, count, color, 300);

    // Add expanding shockwave ring
    if (this.particles.length < this.maxParticles) {
      this.particles.push({
        x,
        y,
        vx: 0,
        vy: 0,
        life: 0.35,
        maxLife: 0.35,
        size: 8,
        color,
        shape: 'ring',
        decay: 1,
        friction: 1
      });
    }
  }

  public emitSmoke(x: number, y: number, color: string = 'rgba(200, 210, 225, 0.4)') {
    if (this.particles.length >= this.maxParticles) return;
    const angle = Math.random() * Math.PI * 2;
    const speed = 10 + Math.random() * 30;
    const life = 0.4 + Math.random() * 0.3;

    this.particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life,
      maxLife: life,
      size: 3 + Math.random() * 3,
      color,
      shape: 'circle',
      decay: 1,
      friction: 0.92
    });
  }

  public emitIceShatter(x: number, y: number, count: number = 18) {
    for (let i = 0; i < count; i++) {
      if (this.particles.length >= this.maxParticles) break;
      const angle = Math.random() * Math.PI * 2;
      const speed = 60 + Math.random() * 220;
      const life = 0.4 + Math.random() * 0.4;

      this.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life,
        maxLife: life,
        size: 3 + Math.random() * 4,
        color: Math.random() < 0.6 ? '#88eeff' : '#ffffff',
        shape: 'shard',
        decay: 1,
        friction: 0.95
      });
    }
  }

  public emitBlizzardSnow(bounds: { width: number; height: number }, count: number = 2) {
    for (let i = 0; i < count; i++) {
      if (this.particles.length >= this.maxParticles) break;
      const x = Math.random() * bounds.width;
      const y = -10;
      const life = 3.5 + Math.random() * 2.0;
      this.particles.push({
        x,
        y,
        vx: (Math.random() * 50 - 25) - 15,
        vy: 45 + Math.random() * 55,
        life,
        maxLife: life,
        size: 1.5 + Math.random() * 2.2,
        color: Math.random() < 0.6 ? '#c8f2ff' : '#ffffff',
        shape: 'circle',
        decay: 1,
        friction: 0.99
      });
    }
  }

  public emitKineticIceShards(x: number, y: number, count: number = 8) {
    for (let i = 0; i < count; i++) {
      if (this.particles.length >= this.maxParticles) break;
      const angle = (i * Math.PI * 2) / count + (Math.random() * 0.2 - 0.1);
      const speed = 340 + Math.random() * 100;
      const life = 0.45 + Math.random() * 0.25;
      this.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life,
        maxLife: life,
        size: 3.5 + Math.random() * 2.5,
        color: '#b8f0ff',
        shape: 'shard',
        decay: 1,
        friction: 0.96
      });
    }
  }

  public emitThrusterSparks(x: number, y: number, angle: number, color: string = '#ff5500') {
    if (this.particles.length >= this.maxParticles) return;
    const spread = (Math.random() - 0.5) * 0.6;
    const finalAngle = angle + spread;
    const speed = 70 + Math.random() * 120;
    const life = 0.2 + Math.random() * 0.2;
    this.particles.push({
      x,
      y,
      vx: Math.cos(finalAngle) * speed,
      vy: Math.sin(finalAngle) * speed,
      life,
      maxLife: life,
      size: 2 + Math.random() * 2,
      color,
      shape: 'streak',
      decay: 1,
      friction: 0.92
    });
  }

  public render(ctx: CanvasRenderingContext2D) {
    ctx.save();
    for (let i = 0; i < this.particles.length; i++) {
      const p = this.particles[i];
      const alpha = Math.max(0, p.life / p.maxLife);
      ctx.globalAlpha = alpha;

      if (p.shape === 'ring') {
        ctx.strokeStyle = p.color;
        ctx.lineWidth = 2.5 * alpha;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.stroke();
      } else if (p.shape === 'streak') {
        ctx.strokeStyle = p.color;
        ctx.lineWidth = p.size;
        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
        ctx.lineTo(p.x - p.vx * 0.04, p.y - p.vy * 0.04);
        ctx.stroke();
      } else if (p.shape === 'shard') {
        ctx.fillStyle = p.color;
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.life * 10);
        ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size);
        ctx.restore();
      } else {
        ctx.fillStyle = p.color;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.restore();
  }
}
