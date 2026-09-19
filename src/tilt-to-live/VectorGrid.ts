// =========================================================================
// VectorGrid.ts - Spring-Mass 2D Reactive Mesh Grid
// =========================================================================

interface GridPoint {
  x: number;
  y: number;
  origX: number;
  origY: number;
  vx: number;
  vy: number;
}

export class VectorGrid {
  private readonly spacing: number = 36;
  private cols: number = 0;
  private rows: number = 0;
  private points: GridPoint[] = [];

  constructor(width: number, height: number) {
    this.resize(width, height);
  }

  public resize(width: number, height: number) {
    this.cols = Math.ceil(width / this.spacing) + 1;
    this.rows = Math.ceil(height / this.spacing) + 1;
    this.points = [];

    for (let r = 0; r < this.rows; r++) {
      for (let c = 0; c < this.cols; c++) {
        const x = c * this.spacing;
        const y = r * this.spacing;
        this.points.push({
          x,
          y,
          origX: x,
          origY: y,
          vx: 0,
          vy: 0
        });
      }
    }
  }

  public update(_dt: number) {
    const stiffness = 0.08;
    const damping = 0.90;

    for (let i = 0; i < this.points.length; i++) {
      const p = this.points[i];
      const dx = p.origX - p.x;
      const dy = p.origY - p.y;

      p.vx += dx * stiffness;
      p.vy += dy * stiffness;

      p.vx *= damping;
      p.vy *= damping;

      p.x += p.vx;
      p.y += p.vy;
    }
  }

  public applyExplosion(cx: number, cy: number, force: number, radius: number) {
    const r2 = radius * radius;
    for (let i = 0; i < this.points.length; i++) {
      const p = this.points[i];
      const dx = p.x - cx;
      const dy = p.y - cy;
      const dist2 = dx * dx + dy * dy;

      if (dist2 < r2 && dist2 > 0.001) {
        const dist = Math.sqrt(dist2);
        const factor = (1 - dist / radius) * force;
        p.vx += (dx / dist) * factor;
        p.vy += (dy / dist) * factor;
      }
    }
  }

  public applyImplosion(cx: number, cy: number, force: number, radius: number) {
    this.applyExplosion(cx, cy, -force, radius);
  }

  public render(ctx: CanvasRenderingContext2D, gridColor?: string) {
    ctx.save();
    ctx.strokeStyle = gridColor || 'rgba(0, 220, 255, 0.09)';
    ctx.lineWidth = 1;

    // Draw horizontal lines
    for (let r = 0; r < this.rows; r++) {
      ctx.beginPath();
      const rowOffset = r * this.cols;
      ctx.moveTo(this.points[rowOffset].x, this.points[rowOffset].y);

      for (let c = 1; c < this.cols; c++) {
        const p = this.points[rowOffset + c];
        ctx.lineTo(p.x, p.y);
      }
      ctx.stroke();
    }

    // Draw vertical lines
    for (let c = 0; c < this.cols; c++) {
      ctx.beginPath();
      ctx.moveTo(this.points[c].x, this.points[c].y);

      for (let r = 1; r < this.rows; r++) {
        const p = this.points[r * this.cols + c];
        ctx.lineTo(p.x, p.y);
      }
      ctx.stroke();
    }

    ctx.restore();
  }
}
