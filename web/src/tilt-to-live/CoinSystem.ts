// =========================================================================
// CoinSystem.ts - Points Coin Pickups
// =========================================================================
// A currency-drop system independent of WeaponSystem's orb spawner (see
// WeaponSystem.orbSpawnTimer). Coins spawn on their own cadence so points
// income no longer depends solely on milestone rewards. Collecting a coin
// credits the run's single currency ("Points") via ProgressionManager.addPointsCredited,
// which already applies the player's purchased points multiplier - the value
// passed in here must stay unmultiplied or that multiplier double-applies.

import { PlayerShip } from './PlayerShip';
import { ParticleEngine } from './ParticleEngine';
import { TiltAudio } from './TiltAudio';

export interface CoinPickup {
  id: number;
  x: number;
  y: number;
  radius: number;
  lifetime: number;
  maxLifetime: number;
  pulseOffset: number;
}

// --flare (#FFB14D) is the design system's reserved points/currency colour.
// Never reuse hazard red (#FF4757, enemies-only) here.
const COIN_COLOR = '#FFB14D';

const MAX_COINS_ON_SCREEN = 6;
const COIN_LIFETIME = 12.0;
const COIN_RADIUS = 9;
const COIN_BASE_VALUE = 25;
const FADE_WARNING_TIME = 3.0; // seconds remaining at which the coin starts fading out
const MIN_DISTANCE_FROM_PLAYER = 110;
const SPAWN_INTERVAL_MIN = 2.5;
const SPAWN_INTERVAL_MAX = 4.0;

export class CoinSystem {
  public coins: CoinPickup[] = [];
  public coinsCollected: number = 0;
  public pointsFromCoins: number = 0;

  private nextCoinId: number = 1;
  private spawnTimer: number = SPAWN_INTERVAL_MIN + Math.random() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN);

  public reset() {
    this.coins = [];
    this.coinsCollected = 0;
    this.pointsFromCoins = 0;
    this.nextCoinId = 1;
    this.spawnTimer = SPAWN_INTERVAL_MIN + Math.random() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN);
  }

  public update(
    dt: number,
    player: PlayerShip,
    bounds: { width: number; height: number },
    particles: ParticleEngine,
    audio: TiltAudio,
    modeMultiplier: number,
    onCollected: (value: number) => number
  ) {
    // 1. Coin spawning - runs entirely on its own timer, independent of
    // WeaponSystem's orb cooldown.
    this.spawnTimer -= dt;
    if (this.spawnTimer <= 0) {
      if (this.coins.length < MAX_COINS_ON_SCREEN) {
        this.spawnCoin(bounds, player);
      }
      this.spawnTimer = SPAWN_INTERVAL_MIN + Math.random() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN);
    }

    // 2. Lifetime + pickup collision
    for (let i = this.coins.length - 1; i >= 0; i--) {
      const coin = this.coins[i];
      coin.lifetime -= dt;

      if (coin.lifetime <= 0) {
        this.coins.splice(i, 1);
        continue;
      }

      const dx = player.x - coin.x;
      const dy = player.y - coin.y;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist < player.radius + coin.radius) {
        const value = Math.round(COIN_BASE_VALUE * modeMultiplier);
        this.coinsCollected++;
        audio.playCoinPickup();
        particles.emitSparks(coin.x, coin.y, 16, COIN_COLOR, 160);
        // onCollected banks the coin and returns what was ACTUALLY credited, which
        // differs from `value` once the player owns the Points Multiplier upgrade.
        // Track the credited figure so the run summary cannot under-report earnings.
        this.pointsFromCoins += onCollected(value);
        this.coins.splice(i, 1);
      }
    }
  }

  private spawnCoin(bounds: { width: number; height: number }, player: PlayerShip) {
    const pad = 50;
    const minDist2 = MIN_DISTANCE_FROM_PLAYER * MIN_DISTANCE_FROM_PLAYER;

    let x = 0;
    let y = 0;
    for (let attempt = 0; attempt < 10; attempt++) {
      x = pad + Math.random() * (bounds.width - pad * 2);
      y = pad + Math.random() * (bounds.height - pad * 2);
      const dx = x - player.x;
      const dy = y - player.y;
      if (dx * dx + dy * dy >= minDist2) break;
    }

    this.coins.push({
      id: this.nextCoinId++,
      x,
      y,
      radius: COIN_RADIUS,
      lifetime: COIN_LIFETIME,
      maxLifetime: COIN_LIFETIME,
      pulseOffset: Math.random() * Math.PI * 2
    });
  }

  public render(ctx: CanvasRenderingContext2D, elapsed: number) {
    if (this.coins.length === 0) return;

    ctx.save();
    for (const coin of this.coins) {
      const pulse = 0.9 + 0.1 * Math.sin(elapsed * 7 + coin.pulseOffset);
      const fadeAlpha = coin.lifetime < FADE_WARNING_TIME ? Math.max(0.15, coin.lifetime / FADE_WARNING_TIME) : 1;

      ctx.save();
      ctx.translate(coin.x, coin.y);
      ctx.globalAlpha = fadeAlpha;

      // Soft amber glow halo
      ctx.fillStyle = `${COIN_COLOR}33`;
      ctx.beginPath();
      ctx.arc(0, 0, (coin.radius + 7) * pulse, 0, Math.PI * 2);
      ctx.fill();

      // Solid coin disc (flat fill, distinct silhouette from the translucent
      // weapon-orb bubbles and from enemy dots)
      const coinGrad = ctx.createRadialGradient(-2, -2, 1, 0, 0, coin.radius);
      coinGrad.addColorStop(0, '#FFE3B0');
      coinGrad.addColorStop(0.55, COIN_COLOR);
      coinGrad.addColorStop(1, '#B8792A');
      ctx.fillStyle = coinGrad;
      ctx.beginPath();
      ctx.arc(0, 0, coin.radius * pulse, 0, Math.PI * 2);
      ctx.fill();

      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 1.4;
      ctx.stroke();

      // Currency glyph (dollar-style bar) so it reads as "points" at a glance
      ctx.strokeStyle = '#4A2E0A';
      ctx.lineWidth = 1.8;
      ctx.beginPath();
      ctx.moveTo(0, -coin.radius * 0.55);
      ctx.lineTo(0, coin.radius * 0.55);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(-coin.radius * 0.4, -coin.radius * 0.25);
      ctx.quadraticCurveTo(coin.radius * 0.45, -coin.radius * 0.25, coin.radius * 0.4, 0);
      ctx.quadraticCurveTo(coin.radius * 0.45, coin.radius * 0.25, -coin.radius * 0.4, coin.radius * 0.25);
      ctx.stroke();

      ctx.restore();
    }
    ctx.restore();
  }
}
