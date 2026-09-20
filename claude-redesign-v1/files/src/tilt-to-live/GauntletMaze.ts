// =========================================================================
// GauntletMaze.ts - Descending Wall Maze System for Gauntlet Mode
// =========================================================================

import { PlayerShip } from './PlayerShip';
import { ParticleEngine } from './ParticleEngine';

export interface WallSegment {
  x: number;
  width: number;
}

export interface MazeGap {
  x: number;
  width: number;
}

export interface GauntletWallRow {
  id: number;
  y: number;
  height: number;
  gapX: number;
  gapWidth: number;
  gaps: MazeGap[];
  segments: WallSegment[];
  pattern: number;
}

export class GauntletMaze {
  public rows: GauntletWallRow[] = [];
  public currentSpeed: number = 75;
  public scale: number = 1.0;
  private nextRowId: number = 1;
  private lastGapX: number = 400;

  public setScale(scale: number) {
    this.scale = Math.max(0.5, Math.min(1.8, scale));
  }

  public get wallHeight(): number {
    return 22 * this.scale;
  }

  public get rowSpacing(): number {
    return 230 * this.scale;
  }

  public reset(width: number = 800, _height: number = 600) {
    this.rows = [];
    this.nextRowId = 1;
    this.currentSpeed = 75 * Math.max(0.72, this.scale);
    this.lastGapX = width / 2;

    const initialRows = 4;
    for (let i = 0; i < initialRows; i++) {
      const y = -i * this.rowSpacing;
      this.spawnRow(y, width);
    }
  }

  private spawnRow(y: number, width: number) {
    const standardGap = Math.max(65, 135 * this.scale);
    const minX = Math.max(30, 60 * this.scale);
    const maxX = Math.max(minX + standardGap + 30, width - standardGap - minX);

    // Pick an obstacle archetype to ensure rich variety:
    // 0: Single guided gap (fair horizontal shift from last gap)
    // 1: Dual safe corridors (two gaps on wide screens)
    // 2: Floating short barricades / pillars (shorter walls with wide open spaces)
    // 3: Central island barrier with open flanks
    const patternRoll = Math.random();
    const segments: WallSegment[] = [];
    const gaps: MazeGap[] = [];
    let patternIndex = 0;

    if (patternRoll < 0.35) {
      patternIndex = 0;
      // Pattern 0: Single Guided Gap Wall
      // Shift gap by at most 180px from previous gap so holes are never too far apart!
      const dir = Math.random() < 0.5 ? 1 : -1;
      const shift = (70 + Math.random() * 110) * dir;
      let gapX = this.lastGapX + shift;
      if (gapX < minX) gapX = minX + 50 + Math.random() * 60;
      if (gapX > maxX) gapX = maxX - 50 - Math.random() * 60;
      gapX = Math.max(minX, Math.min(maxX, gapX));
      this.lastGapX = gapX;

      if (gapX > 1) {
        segments.push({ x: 0, width: gapX });
      }
      const rightX = gapX + standardGap;
      if (rightX < width) {
        segments.push({ x: rightX, width: width - rightX });
      }
      gaps.push({ x: gapX, width: standardGap });
    } else if (patternRoll < 0.60 && width >= 750) {
      patternIndex = 1;
      // Pattern 1: Dual Corridor Wall (two wide escape gaps, with one always nearby last gap!)
      const gWidth = 130;
      const primaryCandidate = Math.max(minX, Math.min(maxX, this.lastGapX + (Math.random() * 90 - 45)));
      let secondaryCandidate: number;
      if (primaryCandidate > width * 0.5) {
        secondaryCandidate = Math.max(minX, primaryCandidate - (250 + Math.random() * 100));
      } else {
        secondaryCandidate = Math.min(maxX, primaryCandidate + (250 + Math.random() * 100));
      }

      const gLeft = Math.min(primaryCandidate, secondaryCandidate);
      const gRight = Math.max(primaryCandidate, secondaryCandidate);

      // Left segment
      if (gLeft > 0) segments.push({ x: 0, width: gLeft });
      // Center segment
      const centerStart = gLeft + gWidth;
      const centerWidth = gRight - centerStart;
      if (centerWidth > 20) segments.push({ x: centerStart, width: centerWidth });
      // Right segment
      const rightStart = gRight + gWidth;
      if (rightStart < width) segments.push({ x: rightStart, width: width - rightStart });

      gaps.push({ x: gLeft, width: gWidth });
      gaps.push({ x: gRight, width: gWidth });

      // Keep lastGapX close to the primary candidate
      this.lastGapX = primaryCandidate;
    } else if (patternRoll < 0.85) {
      patternIndex = 2;
      // Pattern 2: Floating Shorter Barricades / Pillars
      // Instead of stretching across the screen, 2 standalone shorter blocks float down
      const blockWidth = 140 + Math.random() * 50;
      const block1X = Math.max(80, width * 0.18 + Math.random() * (width * 0.08));
      const block2X = Math.min(width - blockWidth - 80, width * 0.64 + Math.random() * (width * 0.08));

      segments.push({ x: block1X, width: blockWidth });
      if (block2X > block1X + blockWidth + 80) {
        segments.push({ x: block2X, width: blockWidth });
      }

      // Left open passage
      gaps.push({ x: 0, width: block1X });
      // Mid passage
      const midGapX = block1X + blockWidth;
      const midGapWidth = Math.max(80, block2X - midGapX);
      gaps.push({ x: midGapX, width: midGapWidth });
      // Right open passage
      const rightStart = block2X + blockWidth;
      if (width - rightStart > 0) {
        gaps.push({ x: rightStart, width: width - rightStart });
      }

      // Update lastGapX to whichever passage is closest
      let closestGapCenter = midGapX + midGapWidth / 2;
      let minGapDist = Math.abs(closestGapCenter - this.lastGapX);
      for (const g of gaps) {
        const center = g.x + g.width / 2;
        const dist = Math.abs(center - this.lastGapX);
        if (dist < minGapDist) {
          minGapDist = dist;
          closestGapCenter = center;
        }
      }
      this.lastGapX = closestGapCenter;
    } else {
      patternIndex = 3;
      // Pattern 3: Central Island Block (wide open flanks on both sides)
      // Place island offset so the side nearest lastGapX has a wide generous opening
      const islandWidth = Math.min(300, width * 0.35);
      let islandX: number;
      if (this.lastGapX < width * 0.5) {
        // Player is on left half: shift island right so left flank is huge
        islandX = width * 0.45 + Math.random() * (width * 0.12);
      } else {
        // Player is on right half: shift island left so right flank is huge
        islandX = width * 0.20 + Math.random() * (width * 0.12);
      }
      segments.push({ x: islandX, width: islandWidth });

      const leftGapWidth = islandX;
      const rightGapStart = islandX + islandWidth;
      const rightGapWidth = width - rightGapStart;

      gaps.push({ x: 0, width: leftGapWidth });
      gaps.push({ x: rightGapStart, width: rightGapWidth });

      const leftCenter = leftGapWidth / 2;
      const rightCenter = rightGapStart + rightGapWidth / 2;
      this.lastGapX = Math.abs(leftCenter - this.lastGapX) < Math.abs(rightCenter - this.lastGapX) ? leftCenter : rightCenter;
    }

    const primaryGap = gaps[0] || { x: width / 2, width: standardGap };
    this.rows.push({
      id: this.nextRowId++,
      y,
      height: this.wallHeight,
      gapX: primaryGap.x,
      gapWidth: primaryGap.width,
      gaps,
      segments,
      pattern: patternIndex
    });
  }

  public update(
    dt: number,
    bounds: { width: number; height: number },
    player: PlayerShip,
    score: number,
    survivalTime: number,
    particles: ParticleEngine,
    onCrushed: () => void
  ) {
    // 1. Calculate speed scaling with score & survival time (tuned for fair arcade pacing)
    const baseSpeed = 75;
    const scoreBonus = Math.min(130, (score / 20000) * 45);
    const timeBonus = Math.min(75, survivalTime * 1.2);
    this.currentSpeed = (baseSpeed + scoreBonus + timeBonus) * Math.max(0.72, this.scale);

    // 2. Move all wall rows downwards
    for (let i = 0; i < this.rows.length; i++) {
      this.rows[i].y += this.currentSpeed * dt;
    }

    // 3. Remove rows that scrolled off bottom of arena
    this.rows = this.rows.filter(r => r.y < bounds.height + 60);

    // 4. Spawn new rows from top to maintain continuous maze
    let highestY = bounds.height;
    for (const r of this.rows) {
      if (r.y < highestY) {
        highestY = r.y;
      }
    }

    if (highestY > -50) {
      const newY = highestY - this.rowSpacing;
      this.spawnRow(newY, bounds.width);
    }

    // 5. Physics: Solid Collision & Blocking against Player Ship
    if (player.isDead) return;

    const r = player.radius;
    let isSqueezedByWall = false;

    for (const row of this.rows) {
      // Quick vertical culling
      if (player.y + r < row.y || player.y - r > row.y + row.height) {
        continue;
      }

      for (const seg of row.segments) {
        const rx = seg.x;
        const ry = row.y;
        const rw = seg.width;
        const rh = row.height;

        // Closest point on rectangle to circle center
        const cx = Math.max(rx, Math.min(player.x, rx + rw));
        const cy = Math.max(ry, Math.min(player.y, ry + rh));

        const dx = player.x - cx;
        const dy = player.y - cy;
        const dist2 = dx * dx + dy * dy;

        if (dist2 < r * r) {
          // Circle intersects solid wall!
          const dist = Math.sqrt(dist2);
          if (dist > 0.001) {
            const overlap = r - dist;
            player.x += (dx / dist) * overlap;
            player.y += (dy / dist) * overlap;
          } else {
            player.y += r;
          }

          // Emit friction sparks at contact point
          if (Math.random() < 0.35) {
            particles.emitSparks(cx, cy, 2, '#ffaa00', 90);
          }

          // If the player is being pushed down by descending wall:
          if (player.y >= ry - 2 && player.y <= ry + rh + r + 4) {
            player.y += this.currentSpeed * dt;
            if (player.vy < this.currentSpeed) {
              player.vy = this.currentSpeed;
            }
            isSqueezedByWall = true;
          }
        }
      }
    }

    // 6. Lethal Crush Condition
    // If the descending wall pins the player against the bottom arena border
    const bottomFloor = bounds.height - (r + 8);
    if (player.y >= bottomFloor && isSqueezedByWall) {
      // Player is squished against the bottom arena border with nowhere to go!
      onCrushed();
    }
  }

  public render(ctx: CanvasRenderingContext2D, bounds: { width: number; height: number }, elapsed: number) {
    ctx.save();

    for (const row of this.rows) {
      // Skip rows completely off-screen
      if (row.y + row.height < 0 || row.y > bounds.height) continue;

      // 1. Render Solid Wall Segments
      for (const seg of row.segments) {
        ctx.save();
        ctx.translate(seg.x, row.y);

        // Core Solid Barrier Body
        ctx.fillStyle = '#140c04';
        ctx.fillRect(0, 0, seg.width, row.height);

        // Hazard diagonal stripes pattern
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, 0, seg.width, row.height);
        ctx.clip();

        ctx.strokeStyle = 'rgba(255, 170, 0, 0.22)';
        ctx.lineWidth = 6;
        const stripeSpacing = 16;
        const stripeOffset = (elapsed * 20) % stripeSpacing;
        for (let sx = -row.height + stripeOffset; sx < seg.width + row.height; sx += stripeSpacing) {
          ctx.beginPath();
          ctx.moveTo(sx, 0);
          ctx.lineTo(sx + row.height, row.height);
          ctx.stroke();
        }
        ctx.restore();

        // Glowing Top & Bottom Laser Edges
        ctx.strokeStyle = '#ffaa00';
        ctx.lineWidth = 2.0;
        ctx.strokeRect(0, 0, seg.width, row.height);

        // High-contrast neon pulse line on the leading edge (bottom of descending bar)
        ctx.strokeStyle = '#FFB14D';
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.moveTo(0, row.height);
        ctx.lineTo(seg.width, row.height);
        ctx.stroke();

        ctx.restore();
      }

      // 2. Safe Gap Guidance Beacons (Green Corridor Markers)
      const beaconPulse = 0.6 + 0.4 * Math.sin(elapsed * 8 + row.id);
      const activeGaps = row.gaps && row.gaps.length > 0 ? row.gaps : [{ x: row.gapX, width: row.gapWidth }];
      const midY = row.y + row.height / 2;

      for (const gap of activeGaps) {
        const leftBeaconX = gap.x;
        const rightBeaconX = gap.x + gap.width;

        // Left gap edge light
        ctx.fillStyle = '#3DDC97';
        ctx.shadowColor = '#3DDC97';
        ctx.shadowBlur = 8;
        ctx.beginPath();
        ctx.arc(leftBeaconX, midY, 3.5 * beaconPulse, 0, Math.PI * 2);
        ctx.fill();

        // Right gap edge light
        ctx.beginPath();
        ctx.arc(rightBeaconX, midY, 3.5 * beaconPulse, 0, Math.PI * 2);
        ctx.fill();

        // Soft safe passage beam in gap
        ctx.strokeStyle = `rgba(61, 220, 151, ${0.15 * beaconPulse})`;
        ctx.lineWidth = 1.5;
        ctx.setLineDash([4, 4]);
        ctx.beginPath();
        ctx.moveTo(leftBeaconX, midY);
        ctx.lineTo(rightBeaconX, midY);
        ctx.stroke();
        ctx.setLineDash([]);
      }
    }

    ctx.restore();
  }
}
