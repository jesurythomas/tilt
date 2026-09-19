// =========================================================================
// ScoreManager.ts - Scoring, Multipliers, Combos & Callouts
// =========================================================================

import { FloatingText, GameMode, GameStats, WeaponType } from './Types';
import { TiltAudio } from './TiltAudio';

export class ScoreManager {
  public stats: GameStats = {
    score: 0,
    bestScore: 0,
    multiplier: 1,
    maxMultiplier: 1,
    kills: 0,
    survivalTime: 0,
    bestCombo: 0,
    closeCalls: 0
  };

  public floatingTexts: FloatingText[] = [];
  public modeMultiplier: number = 1.0;

  private comboCount: number = 0;
  private comboTimer: number = 0;
  private nextTextId: number = 1;

  constructor() {
    this.loadBestScore();
  }

  public setModeMultiplier(multiplier: number) {
    this.modeMultiplier = multiplier;
  }

  public reset() {
    this.stats.score = 0;
    this.stats.multiplier = 1;
    this.stats.maxMultiplier = 1;
    this.stats.kills = 0;
    this.stats.survivalTime = 0;
    this.stats.bestCombo = 0;
    this.stats.closeCalls = 0;

    this.comboCount = 0;
    this.comboTimer = 0;
    this.floatingTexts = [];
  }

  public update(dt: number, gameMode?: GameMode) {
    this.stats.survivalTime += dt;

    if (gameMode === 'gauntlet') {
      // In Gauntlet mode, score is continuously counted by how long the player has lasted
      this.stats.score += Math.round(250 * dt * this.modeMultiplier);
    }

    // Combo window decays
    if (this.comboTimer > 0) {
      this.comboTimer -= dt;
      if (this.comboTimer <= 0) {
        this.comboCount = 0;
      }
    }

    // Update Floating Text popups
    for (let i = this.floatingTexts.length - 1; i >= 0; i--) {
      const t = this.floatingTexts[i];
      t.y += t.vy * dt;
      t.lifetime -= dt;
      t.alpha = Math.max(0, t.lifetime / 1.0);

      if (t.lifetime <= 0) {
        this.floatingTexts.splice(i, 1);
      }
    }
  }

  public registerKill(x: number, y: number, _weaponType: WeaponType, audio: TiltAudio) {
    this.stats.kills++;
    this.comboCount++;
    this.comboTimer = 1.6; // 1.6 second combo window

    if (this.comboCount > this.stats.bestCombo) {
      this.stats.bestCombo = this.comboCount;
    }

    // Multiplier builds up: +1x every 8 kills in combo, up to 50x
    if (this.comboCount % 8 === 0 && this.stats.multiplier < 50) {
      this.stats.multiplier++;
      if (this.stats.multiplier > this.stats.maxMultiplier) {
        this.stats.maxMultiplier = this.stats.multiplier;
      }
      this.addFloatingText(`${this.stats.multiplier}x MULTIPLIER!`, x, y - 20, '#00ffee', 18);
    }

    // Base score per kill = 10 * multiplier * modeMultiplier
    const points = Math.round(10 * this.stats.multiplier * this.modeMultiplier);
    this.stats.score += points;

    // Play musical combo note
    audio.playDotPop(this.comboCount);

    // Combo Callout Milestones
    if (this.comboCount === 3) {
      this.addFloatingText('TRIPLE!', x, y - 10, '#ffee33', 18);
    } else if (this.comboCount === 6) {
      this.addFloatingText('MULTI KILL!', x, y - 10, '#ff9900', 20);
    } else if (this.comboCount === 10) {
      audio.playMilestone();
      this.addFloatingText('MEGA KILL!', x, y - 10, '#ff0055', 24);
    } else if (this.comboCount === 16) {
      audio.playMilestone();
      this.addFloatingText('UNBELIEVABLE!', x, y - 10, '#cc33ff', 26);
    } else if (this.comboCount === 25 || (this.comboCount > 25 && this.comboCount % 15 === 0)) {
      audio.playMilestone();
      this.addFloatingText('HOLY CRAP!', x, y - 10, '#ffffff', 30);
    }
  }

  public registerCloseCall(x: number, y: number, audio: TiltAudio) {
    this.stats.closeCalls++;
    audio.playCloseCall();
    const bonus = Math.round(250 * this.stats.multiplier * this.modeMultiplier);
    this.stats.score += bonus;
    this.addFloatingText('CLOSE CALL! +' + bonus, x, y - 15, '#00ffaa', 17);
  }

  public addFloatingText(text: string, x: number, y: number, color: string, size: number = 18) {
    this.floatingTexts.push({
      id: this.nextTextId++,
      text,
      x,
      y,
      vy: -48,
      color,
      size,
      alpha: 1.0,
      lifetime: 1.1
    });
  }

  public finalizeGame() {
    if (this.stats.score > this.stats.bestScore) {
      this.stats.bestScore = this.stats.score;
      try {
        localStorage.setItem('tilt_to_live_best', this.stats.bestScore.toString());
      } catch (err) {
        // LocalStorage unavailable in sandbox
      }
    }
  }

  public loadBestScore() {
    try {
      const val = localStorage.getItem('tilt_to_live_best');
      if (val) {
        const parsed = parseInt(val, 10);
        if (Number.isFinite(parsed) && parsed >= 0) {
          this.stats.bestScore = parsed;
        }
      }
    } catch (err) {
      this.stats.bestScore = 0;
    }
  }

  public renderFloatingTexts(ctx: CanvasRenderingContext2D) {
    ctx.save();
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    for (const t of this.floatingTexts) {
      ctx.globalAlpha = t.alpha;
      ctx.font = `800 ${t.size}px "Unbounded", sans-serif`;

      // Shadow
      ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
      ctx.fillText(t.text, t.x + 2, t.y + 2);

      // Text
      ctx.fillStyle = t.color;
      ctx.fillText(t.text, t.x, t.y);
    }

    ctx.restore();
  }
}
