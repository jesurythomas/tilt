// =========================================================================
// TiltGame.ts - Tilt to Live Master Game Controller
// =========================================================================

import { VectorGrid } from './VectorGrid';
import { ParticleEngine } from './ParticleEngine';
import { TiltAudio } from './TiltAudio';
import { PlayerShip } from './PlayerShip';
import { EnemySwarm } from './EnemySwarm';
import { WeaponSystem } from './WeaponSystem';
import { ScoreManager } from './ScoreManager';
import { TiltRenderer } from './TiltRenderer';
import { TiltEntranceCinematic } from './TiltEntranceCinematic';
import { ProgressionManager } from './ProgressionManager';
import { ArmoryUI } from './ArmoryUI';
import { Enemy, GameMode, GamePhase, Point2D, WeaponType } from './Types';
import { GoalManager, RunTracker } from './GoalManager';
import { GameOptionsManager } from './GameOptions';
import { GoalsHUD } from './GoalsHUD';
import { TiltMenu } from './TiltMenu';
import { GauntletMaze } from './GauntletMaze';
import { GyroscopeController } from './GyroscopeController';

export class TiltGame {
  private readonly canvas: HTMLCanvasElement;
  private readonly ctx: CanvasRenderingContext2D;
  private readonly onReturnToPortal?: () => void;

  public phase: GamePhase = 'menu';

  // Core Sub-systems
  public readonly grid: VectorGrid;
  public readonly particles: ParticleEngine = new ParticleEngine();
  public readonly audio: TiltAudio = new TiltAudio();
  public readonly player: PlayerShip;
  public readonly swarm: EnemySwarm = new EnemySwarm();
  public readonly weapons: WeaponSystem = new WeaponSystem();
  public readonly scores: ScoreManager = new ScoreManager();
  public readonly renderer: TiltRenderer = new TiltRenderer();
  public readonly cinematic: TiltEntranceCinematic;
  public readonly progression: ProgressionManager = new ProgressionManager();
  public readonly armoryUI: ArmoryUI;

  // Gyroscope / Device Tilt Controller
  public readonly gyro: GyroscopeController = new GyroscopeController();

  // Gauntlet Descending Maze
  public readonly gauntletMaze: GauntletMaze = new GauntletMaze();

  // New Modes, Options & Milestones Sub-systems
  public readonly options: GameOptionsManager = new GameOptionsManager();
  public readonly goals: GoalManager = new GoalManager();
  public readonly goalsHUD: GoalsHUD;
  public readonly menu: TiltMenu;

  // Mouse / Pointer, Keyboard & Gyro State
  public mousePos: Point2D = { x: 400, y: 300 };
  public controlMode: 'mouse' | 'keyboard' | 'gyro' = 'mouse';
  private activeMovementKeys: Set<'up' | 'down' | 'left' | 'right'> = new Set();

  // Run Milestone Tracker
  public runTracker: RunTracker = {
    mode: 'classic',
    score: 0,
    kills: 0,
    multiplier: 1,
    survivalTime: 0,
    closeCalls: 0,
    nukesDetonated: 0,
    vortexAbsorbs: 0,
    laserSlices: 0,
    missilesFired: 0,
    freezeShatters: 0,
    shieldRams: 0
  };
  public pointsEarnedThisRun: number = 0;

  // Loop & Timing
  private isRunning: boolean = false;
  private animationFrame: number | null = null;
  private lastTime: number = 0;
  private accumulator: number = 0;
  private elapsed: number = 0;
  private pixelRatio: number = 1;

  // DOM Elements
  private scoreEl!: HTMLElement;
  private bestScoreEl!: HTMLElement;
  private pauseModal!: HTMLElement;
  private gameOverModal!: HTMLElement;
  private finalScoreEl!: HTMLElement;
  private finalKillsEl!: HTMLElement;
  private finalMultEl!: HTMLElement;
  private finalTimeEl!: HTMLElement;
  private modeBadgeEl: HTMLElement | null = null;

  constructor(canvas: HTMLCanvasElement, onReturnToPortal?: () => void) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d')!;
    this.onReturnToPortal = onReturnToPortal;

    this.grid = new VectorGrid(800, 600);
    this.player = new PlayerShip(400, 300);

    this.cinematic = new TiltEntranceCinematic(
      this.audio,
      this.player,
      this.swarm,
      this.grid,
      this.particles,
      this.renderer,
      this.weapons,
      () => {
        this.phase = 'playing';
        if (this.options.settings.musicEnabled) {
          this.audio.startMusic();
        }
      }
    );

    this.armoryUI = new ArmoryUI(
      this.progression,
      () => this.handleProgressionChanged(),
      () => this.handleArmoryClosed()
    );

    this.goalsHUD = new GoalsHUD(this.goals, this.progression);

    this.menu = new TiltMenu(
      this.options,
      this.progression,
      this.goals,
      this.scores,
      (mode) => this.launchRun(mode),
      () => this.openArmory(),
      () => this.goalsHUD.openAllGoalsModal(),
      () => this.calibrateGyro()
    );

    // Goal completion & point reward listeners
    this.goals.setCallbacks(
      (goal) => {
        this.pointsEarnedThisRun += goal.rewardPoints;
        this.goalsHUD.showGoalToast(goal);
      },
      (pts) => {
        this.progression.addPoints(pts);
        this.goalsHUD.render();
      }
    );

    // Track superweapon activation
    this.weapons.onWeaponActivated = (type: WeaponType) => {
      if (type === 'nuke') {
        this.runTracker.nukesDetonated++;
      } else if (type === 'missiles') {
        this.runTracker.missilesFired += 16;
      }
    };

    this.bindDOM();
    this.bindInputs();
  }

  private bindDOM() {
    this.scoreEl = this.requireElement('tilt-score');
    this.bestScoreEl = this.requireElement('tilt-best');
    this.pauseModal = this.requireElement('tilt-pause-overlay');
    this.gameOverModal = this.requireElement('tilt-gameover-modal');
    this.finalScoreEl = this.requireElement('tilt-final-score');
    this.finalKillsEl = this.requireElement('tilt-final-kills');
    this.finalMultEl = this.requireElement('tilt-final-mult');
    this.finalTimeEl = this.requireElement('tilt-final-time');
    this.modeBadgeEl = document.getElementById('tilt-mode-badge');
  }

  private bindInputs() {
    // Mouse movement steering
    window.addEventListener('pointermove', (e) => {
      if (!this.isRunning) return;
      const rect = this.canvas.getBoundingClientRect();
      const scaleX = this.canvas.width / this.pixelRatio / rect.width;
      const scaleY = this.canvas.height / this.pixelRatio / rect.height;

      this.mousePos.x = (e.clientX - rect.left) * scaleX;
      this.mousePos.y = (e.clientY - rect.top) * scaleY;

      // Switch to mouse control if user is moving mouse without holding movement keys and not in gyro mode
      if (
        this.activeMovementKeys.size === 0 &&
        this.options.settings.controlScheme !== 'keyboard' &&
        this.options.settings.controlScheme !== 'gyro'
      ) {
        this.controlMode = 'mouse';
      }
    });

    // Touch support (drag or tap)
    this.canvas.addEventListener('touchmove', (e) => {
      if (!this.isRunning || e.touches.length === 0) return;
      e.preventDefault();
      const rect = this.canvas.getBoundingClientRect();
      const scaleX = this.canvas.width / this.pixelRatio / rect.width;
      const scaleY = this.canvas.height / this.pixelRatio / rect.height;

      if (this.options.settings.controlScheme !== 'gyro') {
        this.mousePos.x = (e.touches[0].clientX - rect.left) * scaleX;
        this.mousePos.y = (e.touches[0].clientY - rect.top) * scaleY;
        this.controlMode = 'mouse';
      }
    }, { passive: false });

    // Keyboard Shortcuts & Movement
    window.addEventListener('keydown', (e) => {
      if (!this.isRunning) return;
      const key = e.key.toLowerCase();

      // Check for WASD / Arrow movement keys
      const moveDir = this.getMovementKeyDirection(e.code, e.key);
      if (moveDir) {
        e.preventDefault(); // Always prevent browser scrolling on movement keys
        if (this.options.settings.controlScheme !== 'mouse' && this.options.settings.controlScheme !== 'gyro') {
          this.activeMovementKeys.add(moveDir);
          this.controlMode = 'keyboard';
        }
      }

      if (this.phase === 'cinematic') {
        if (e.code === 'Space' || e.key === 'Enter' || key === 'escape') {
          e.preventDefault();
          const width = this.canvas.width / this.pixelRatio;
          const height = this.canvas.height / this.pixelRatio;
          this.cinematic.skip(width, height);
          return;
        }
      }

      if (e.code === 'Space' || key === 'r') {
        if (this.phase === 'game-over') {
          e.preventDefault();
          this.startCinematic();
        }
      } else if (key === 'b' || key === 'u') {
        e.preventDefault();
        if (this.armoryUI.isOpen()) {
          this.closeArmory();
        } else {
          this.openArmory();
        }
      } else if (key === 'p' || e.key === 'Escape') {
        e.preventDefault();
        if (this.armoryUI.isOpen()) {
          this.closeArmory();
        } else if (this.phase === 'playing' || this.phase === 'paused') {
          this.togglePause();
        }
      }
    });

    window.addEventListener('keyup', (e) => {
      if (!this.isRunning) return;
      const moveDir = this.getMovementKeyDirection(e.code, e.key);
      if (moveDir) {
        this.activeMovementKeys.delete(moveDir);
        e.preventDefault();
      }
    });

    window.addEventListener('blur', () => {
      this.activeMovementKeys.clear();
    });

    // Cinematic Skip Controls
    document.querySelector('.tilt-cinematic-skip')?.addEventListener('click', (e) => {
      e.stopPropagation();
      if (this.phase === 'cinematic') {
        const width = this.canvas.width / this.pixelRatio;
        const height = this.canvas.height / this.pixelRatio;
        this.cinematic.skip(width, height);
      }
    });

    this.canvas.addEventListener('pointerdown', () => {
      if (this.phase === 'cinematic') {
        const width = this.canvas.width / this.pixelRatio;
        const height = this.canvas.height / this.pixelRatio;
        this.cinematic.skip(width, height);
      }
    });

    // UI Buttons
    document.getElementById('btn-tilt-sound')?.addEventListener('click', () => {
      const active = this.audio.toggleMute();
      this.options.settings.sfxEnabled = active;
      this.options.settings.musicEnabled = active;
      this.options.save();
      const btn = document.getElementById('btn-tilt-sound');
      if (btn) btn.textContent = active ? 'Sound on' : 'Sound off';
    });

    document.getElementById('btn-tilt-pause')?.addEventListener('click', () => {
      this.togglePause();
    });

    document.getElementById('btn-tilt-resume')?.addEventListener('click', () => {
      this.togglePause();
    });

    document.getElementById('btn-tilt-restart')?.addEventListener('click', (e) => {
      (e.currentTarget as HTMLElement)?.blur();
      this.startCinematic();
    });

    document.getElementById('btn-tilt-menu')?.addEventListener('click', () => {
      this.returnToMenu();
    });

    document.getElementById('btn-tilt-portal')?.addEventListener('click', () => {
      this.returnToMenu();
    });

    document.getElementById('btn-tilt-menu-gameover')?.addEventListener('click', () => {
      this.returnToMenu();
    });

    document.getElementById('btn-tilt-menu-pause')?.addEventListener('click', () => {
      this.returnToMenu();
    });

    document.getElementById('btn-tilt-armory-hud')?.addEventListener('click', () => {
      this.openArmory();
    });

    document.getElementById('btn-tilt-armory-pause')?.addEventListener('click', () => {
      this.openArmory();
    });

    document.getElementById('btn-tilt-armory-gameover')?.addEventListener('click', () => {
      this.openArmory();
    });

    document.getElementById('btn-tilt-calibrate')?.addEventListener('click', () => {
      this.calibrateGyro();
    });

    document.getElementById('btn-tilt-calibrate-pause')?.addEventListener('click', () => {
      this.calibrateGyro();
    });

    window.addEventListener('resize', () => this.resizeCanvas());
  }

  public start() {
    this.resizeCanvas();
    this.isRunning = true;
    this.lastTime = performance.now();
    this.phase = 'menu';
    this.goalsHUD.setMenuMode(true);
    this.menu.show();
    this.goalsHUD.render();
    this.updateCursor();

    if (this.animationFrame !== null) cancelAnimationFrame(this.animationFrame);
    this.animationFrame = requestAnimationFrame((time) => this.loop(time));
  }

  public launchRun(mode?: GameMode) {
    if (mode) {
      this.options.setMode(mode);
    }
    this.goalsHUD.setMenuMode(false);
    this.menu.hide();
    this.audio.unlock();
    this.startCinematic();
  }

  public returnToMenu() {
    if (this.phase === 'menu') return;
    this.phase = 'menu';
    this.activeMovementKeys.clear();
    this.gyro.stopListening();
    this.audio.stopMusic();
    this.pauseModal.classList.add('hidden');
    this.gameOverModal.classList.add('hidden');
    const width = this.canvas.width / this.pixelRatio;
    const height = this.canvas.height / this.pixelRatio;
    this.cinematic.skip(width, height);

    this.goalsHUD.setMenuMode(true);
    this.menu.show();
    this.goalsHUD.render();
    this.updateCursor();

    if (this.onReturnToPortal) {
      this.onReturnToPortal();
    }
  }

  public restart() {
    this.startCinematic();
  }

  public startCinematic() {
    this.goalsHUD.setMenuMode(false);
    this.resetRun(this.options.settings.mode);
    this.phase = 'cinematic';
    const width = this.canvas.width / this.pixelRatio;
    const height = this.canvas.height / this.pixelRatio;
    this.cinematic.start(width, height, this.options.settings.mode);
  }

  public stop() {
    this.isRunning = false;
    this.activeMovementKeys.clear();
    this.gyro.stopListening();
    this.audio.stopMusic();
    const width = this.canvas.width / this.pixelRatio;
    const height = this.canvas.height / this.pixelRatio;
    this.cinematic.skip(width, height);
    if (this.animationFrame !== null) {
      cancelAnimationFrame(this.animationFrame);
      this.animationFrame = null;
    }
  }

  public resetRun(mode: GameMode = this.options.settings.mode) {
    this.options.setMode(mode);
    const modeConfig = this.options.getModeConfig(mode);
    this.scores.setModeMultiplier(modeConfig.scoreMultiplier);

    if (this.options.settings.controlScheme === 'gyro') {
      this.gyro.startListening();
    } else {
      this.gyro.stopListening();
    }

    const width = this.canvas.width / this.pixelRatio;
    const height = this.canvas.height / this.pixelRatio;

    this.phase = 'playing';
    this.elapsed = 0;
    this.accumulator = 0;
    this.pointsEarnedThisRun = 0;

    this.runTracker = {
      mode: this.options.settings.mode,
      score: 0,
      kills: 0,
      multiplier: 1,
      survivalTime: 0,
      closeCalls: 0,
      nukesDetonated: 0,
      vortexAbsorbs: 0,
      laserSlices: 0,
      missilesFired: 0,
      freezeShatters: 0,
      shieldRams: 0
    };

    this.player.reset(width / 2, height / 2);
    this.mousePos = { x: width / 2, y: height / 2 };
    this.activeMovementKeys.clear();
    this.controlMode = 'mouse';

    this.swarm.reset();
    this.weapons.reset();
    this.particles.reset();
    this.scores.reset();
    this.gauntletMaze.reset(width, height);
    this.grid.resize(width, height);

    // Apply sound options
    this.audio.setMuted(!this.options.settings.sfxEnabled);
    this.audio.setSfxVolume(this.options.settings.sfxVolume);
    this.audio.setMusicVolume(this.options.settings.musicVolume);

    this.pauseModal.classList.add('hidden');
    this.gameOverModal.classList.add('hidden');
    this.updateHUD();
    this.goalsHUD.updateLive(this.runTracker);
    this.updateCursor();
  }

  public togglePause() {
    if (this.phase === 'playing') {
      this.phase = 'paused';
      this.pauseModal.classList.remove('hidden');
      this.audio.stopMusic();
    } else if (this.phase === 'paused') {
      this.phase = 'playing';
      this.pauseModal.classList.add('hidden');
      if (this.options.settings.musicEnabled) {
        this.audio.startMusic();
      }
    }
  }

  private loop(currentTime: number) {
    if (!this.isRunning) return;

    const rawDelta = (currentTime - this.lastTime) / 1000;
    this.lastTime = currentTime;
    const dt = Math.min(0.1, rawDelta);

    if (this.phase === 'menu') {
      this.grid.update(dt);
      this.particles.update(dt);
    } else if (this.phase === 'cinematic') {
      const width = this.canvas.width / this.pixelRatio;
      const height = this.canvas.height / this.pixelRatio;
      this.grid.update(dt);
      this.particles.update(dt);
      this.cinematic.update(dt, width, height);
    } else if (this.phase === 'playing') {
      this.accumulator += dt;
      const fixedDt = 1 / 120; // 120Hz physics sub-stepping for silky precision
      while (this.accumulator >= fixedDt) {
        this.update(fixedDt);
        this.accumulator -= fixedDt;
      }
    }

    this.render();
    this.animationFrame = requestAnimationFrame((time) => this.loop(time));
  }

  private update(dt: number) {
    this.elapsed += dt;
    const width = this.canvas.width / this.pixelRatio;
    const height = this.canvas.height / this.pixelRatio;
    const bounds = { width, height };
    const activeMode = this.options.settings.mode;

    // 1. Update Grid
    this.grid.update(dt);

    // 2. Update Particles
    this.particles.update(dt);

    // 3. Update Player Ship with scheme checks
    let effectiveMode: 'mouse' | 'keyboard' | 'gyro' = this.controlMode;
    if (this.options.settings.controlScheme === 'mouse') {
      effectiveMode = 'mouse';
    } else if (this.options.settings.controlScheme === 'keyboard') {
      effectiveMode = 'keyboard';
    } else if (this.options.settings.controlScheme === 'gyro') {
      effectiveMode = 'gyro';
    } else if (this.activeMovementKeys.size > 0) {
      effectiveMode = 'keyboard';
    }

    const moveVector = this.getMovementVector();
    this.player.update(
      dt,
      this.mousePos,
      bounds,
      this.particles,
      effectiveMode,
      moveVector,
      this.progression.data.tuning,
      this.progression.getEquippedShip(),
      this.gyro.tiltVector
    );

    // 3.5 Update Gauntlet Descending Maze Walls (blocks player, pushes downwards)
    if (activeMode === 'gauntlet') {
      this.gauntletMaze.update(
        dt,
        bounds,
        this.player,
        this.scores.stats.score,
        this.elapsed,
        this.particles,
        () => this.triggerPlayerDeath()
      );
    }

    // 4. Update Swarm Enemies (scaling with score, mode, and wave director)
    this.swarm.update(
      dt,
      { x: this.player.x, y: this.player.y },
      bounds,
      this.particles,
      this.scores.stats.score,
      activeMode
    );

    // 5. Update Weapons (with granular weapon perks and mode modifiers)
    this.weapons.update(
      dt,
      this.player,
      this.swarm.enemies,
      bounds,
      this.particles,
      this.grid,
      this.audio,
      (enemy, weaponType) => this.handleEnemyKilled(enemy, weaponType),
      this.progression.data.perks,
      activeMode
    );

    // 6. Update Scores and Combos
    this.scores.update(dt, activeMode);

    // 7. Check Player vs Red Dot Collisions & Near-Misses
    this.checkCollisions();

    // 8. Update Run Tracker & Goals HUD
    this.runTracker.score = this.scores.stats.score;
    this.runTracker.kills = this.scores.stats.kills;
    this.runTracker.multiplier = this.scores.stats.multiplier;
    this.runTracker.survivalTime = this.elapsed;
    this.runTracker.closeCalls = this.scores.stats.closeCalls;
    this.goalsHUD.updateLive(this.runTracker);

    // 9. Update HUD DOM
    this.updateHUD();
  }

  private handleEnemyKilled(enemy: Enemy, weaponType: WeaponType) {
    this.scores.registerKill(enemy.x, enemy.y, weaponType, this.audio);
    this.grid.applyExplosion(enemy.x, enemy.y, 4.5, 60);
    this.swarm.onEnemyKilled(enemy, this.particles);

    // Update weapon kill statistics for milestones
    switch (weaponType) {
      case 'vortex':
        this.runTracker.vortexAbsorbs++;
        break;
      case 'laser':
        this.runTracker.laserSlices++;
        break;
      case 'missiles':
        this.runTracker.missilesFired++;
        break;
      case 'freeze':
        this.runTracker.freezeShatters++;
        break;
      case 'shield':
        this.runTracker.shieldRams++;
        break;
    }
  }

  private checkCollisions() {
    if (this.player.isDead) return;

    for (let i = this.swarm.enemies.length - 1; i >= 0; i--) {
      const e = this.swarm.enemies[i];
      const dx = this.player.x - e.x;
      const dy = this.player.y - e.y;
      const dist = Math.sqrt(dx * dx + dy * dy);

      // Direct Touch / Collision
      if (dist < this.player.radius + e.radius) {
        if (this.player.hasShield()) {
          // Shield rams and kills red dot!
          this.handleEnemyKilled(e, 'shield');
          this.particles.emitExplosion(e.x, e.y, '#00ffcc', 20);
          this.swarm.enemies.splice(i, 1);
          continue;
        } else if (e.frozen) {
          // Ramming frozen dot shatters it!
          this.audio.playIceShatter();
          this.scores.registerKill(e.x, e.y, 'freeze', this.audio);
          this.particles.emitIceShatter(e.x, e.y, 16);
          this.swarm.enemies.splice(i, 1);
          continue;
        } else {
          // Lethal Crash!
          this.triggerPlayerDeath();
          return;
        }
      }

      // Close Call / Near-Miss Detection
      if (dist < this.player.radius + e.radius + 16 && this.player.closeCallTimer <= 0) {
        this.player.closeCallTimer = 0.75;
        this.scores.registerCloseCall(this.player.x, this.player.y, this.audio);
      }
    }
  }

  private triggerPlayerDeath() {
    this.player.isDead = true;
    this.phase = 'game-over';
    this.audio.playPlayerDeath();
    this.audio.stopMusic();

    this.particles.emitExplosion(this.player.x, this.player.y, '#ffffff', 50);
    this.particles.emitExplosion(this.player.x, this.player.y, '#00ddff', 30);
    this.grid.applyExplosion(this.player.x, this.player.y, 22, 380);
    this.renderer.triggerShake(24 * this.options.getShakeMultiplier());

    this.scores.finalizeGame();

    // Finalize run goals check (capped at 3 run milestones, plus any cumulative total milestones)
    const newlyCompleted = this.goals.evaluateRun(this.runTracker);

    // Show Game Over Modal (strictly milestone-based points economy!)
    window.setTimeout(() => {
      this.finalScoreEl.textContent = this.scores.stats.score.toLocaleString();
      this.finalKillsEl.textContent = this.scores.stats.kills.toString();
      this.finalMultEl.textContent = `${this.scores.stats.maxMultiplier}x`;
      this.finalTimeEl.textContent = `${Math.floor(this.scores.stats.survivalTime)}s`;

      const earnedEl = document.getElementById('tilt-earned-points');
      if (earnedEl) {
        earnedEl.textContent = this.pointsEarnedThisRun > 0
          ? `+${this.pointsEarnedThisRun} PTS`
          : `0 PTS (Check Milestones)`;
      }
      const balanceEl = document.getElementById('tilt-balance-points');
      if (balanceEl) {
        balanceEl.textContent = `Vault: ${this.progression.data.points.toLocaleString()} PTS`;
      }

      const milestonesListEl = document.getElementById('tilt-gameover-milestones');
      if (milestonesListEl) {
        if (newlyCompleted.length > 0) {
          milestonesListEl.innerHTML = newlyCompleted.map(g => `
            <div class="gameover-milestone-item">
              <span class="milestone-star">★</span>
              <div class="milestone-info">
                <strong>${g.title}</strong>
                <small>${g.description}</small>
              </div>
              <span class="milestone-reward">+${g.rewardPoints} PTS</span>
            </div>
          `).join('');
          milestonesListEl.classList.remove('hidden');
        } else {
          milestonesListEl.innerHTML = '';
          milestonesListEl.classList.add('hidden');
        }
      }

      this.goalsHUD.render();
      this.menu.render();

      this.gameOverModal.classList.remove('hidden');
    }, 450);
  }

  private updateHUD() {
    this.scoreEl.textContent = this.scores.stats.score.toLocaleString();
    this.bestScoreEl.textContent = `Best ${this.scores.stats.bestScore.toLocaleString()}`;

    if (this.modeBadgeEl) {
      const mode = this.options.settings.mode;
      const cfg = this.options.getModeConfig(mode);
      this.modeBadgeEl.className = `hud-mode-pill ${mode}`;
      this.modeBadgeEl.textContent = `${cfg.name.toUpperCase()} · ${cfg.scoreMultiplier}X`;
    }

    const calibrateBtn = document.getElementById('btn-tilt-calibrate');
    const calibratePauseBtn = document.getElementById('btn-tilt-calibrate-pause');
    const pauseDesc = document.getElementById('tilt-pause-scheme-desc');
    const isGyro = this.options.settings.controlScheme === 'gyro';

    if (calibrateBtn) {
      if (isGyro) {
        calibrateBtn.classList.remove('hidden');
      } else {
        calibrateBtn.classList.add('hidden');
      }
    }
    if (calibratePauseBtn) {
      if (isGyro) {
        calibratePauseBtn.classList.remove('hidden');
      } else {
        calibratePauseBtn.classList.add('hidden');
      }
    }
    if (pauseDesc) {
      if (isGyro) {
        pauseDesc.textContent = 'Steer by tilting your device (Neutral resting angle active)';
      } else if (this.options.settings.controlScheme === 'keyboard') {
        pauseDesc.textContent = 'Steer with WASD or Arrow Keys';
      } else if (this.options.settings.controlScheme === 'mouse') {
        pauseDesc.textContent = 'Steer with Mouse Cursor or Touch';
      } else {
        pauseDesc.textContent = 'Steer with WASD / Arrow Keys or Mouse';
      }
    }
  }

  private render() {
    const width = this.canvas.width / this.pixelRatio;
    const height = this.canvas.height / this.pixelRatio;

    this.ctx.setTransform(this.pixelRatio, 0, 0, this.pixelRatio, 0, 0);

    if (this.phase === 'menu') {
      // Interactive vector grid ripples and stars behind start menu
      this.renderer.renderMenuBackground(
        this.ctx,
        width,
        height,
        this.grid,
        this.particles,
        this.mousePos,
        this.elapsed,
        this.progression.getEquippedArenaTheme(),
        this.options.settings.showGridlines
      );
      return;
    }

    let effectiveMode: 'mouse' | 'keyboard' | 'gyro' = this.controlMode;
    if (this.options.settings.controlScheme === 'mouse') {
      effectiveMode = 'mouse';
    } else if (this.options.settings.controlScheme === 'keyboard') {
      effectiveMode = 'keyboard';
    } else if (this.options.settings.controlScheme === 'gyro') {
      effectiveMode = 'gyro';
    } else if (this.activeMovementKeys.size > 0) {
      effectiveMode = 'keyboard';
    }

    this.renderer.render(
      this.ctx,
      width,
      height,
      this.player,
      this.swarm,
      this.weapons,
      this.grid,
      this.particles,
      this.scores,
      this.mousePos,
      this.elapsed,
      effectiveMode,
      this.progression.getEquippedCursor(),
      this.progression.getEquippedEnemySkin(),
      this.progression.getEquippedArenaTheme(),
      this.options.settings.tetherLine,
      this.options.settings.highContrastHalo,
      this.options.settings.mode,
      this.gauntletMaze,
      this.options.settings.showGridlines
    );

    if (this.phase === 'cinematic') {
      this.cinematic.render(this.ctx, width, height);
    }
  }

  public async calibrateGyro(): Promise<boolean> {
    const success = await this.gyro.requestPermissionAndStart();
    if (success) {
      this.gyro.calibrateCurrentPosition();
      this.goalsHUD.showMessageToast('TILT CALIBRATED', 'Neutral Angle Zeroed ✓');
    } else {
      this.goalsHUD.showMessageToast('GYRO SENSOR', 'Sensor Unavailable or Blocked');
    }
    this.updateHUD();
    return success;
  }

  public openArmory(tab?: 'perks' | 'cursors' | 'enemies' | 'arenas' | 'tuning') {
    if (this.phase === 'playing') {
      this.phase = 'paused';
      this.pauseModal.classList.add('hidden');
      this.audio.stopMusic();
    }
    this.armoryUI.open(tab);
  }

  public closeArmory() {
    this.armoryUI.close();
  }

  private handleProgressionChanged() {
    this.updateHUD();
    this.goalsHUD.render();
    this.menu.render();
    this.updateCursor();
  }

  public updateCursor() {
    const skin = this.progression.getEquippedCursor();
    const uri = this.progression.getCursorSvgDataUri(skin.id);
    const cursorVal = `url("${uri}") 16 16, crosshair`;

    if (this.phase === 'playing') {
      this.canvas.style.cursor = 'none';
    } else {
      this.canvas.style.cursor = cursorVal;
    }
    document.documentElement.style.setProperty('--custom-cursor', cursorVal);
  }

  private handleArmoryClosed() {
    if (this.phase === 'paused') {
      this.pauseModal.classList.remove('hidden');
    }
    this.goalsHUD.render();
    this.menu.render();
    this.updateCursor();
  }

  public hasActiveMovementKeys(): boolean {
    return this.activeMovementKeys.size > 0;
  }

  private getMovementKeyDirection(code: string, key: string): 'up' | 'down' | 'left' | 'right' | null {
    const k = key.toLowerCase();
    if (code === 'KeyW' || code === 'ArrowUp' || k === 'w' || k === 'arrowup' || k === 'up' || code === 'Numpad8') return 'up';
    if (code === 'KeyS' || code === 'ArrowDown' || k === 's' || k === 'arrowdown' || k === 'down' || code === 'Numpad2') return 'down';
    if (code === 'KeyA' || code === 'ArrowLeft' || k === 'a' || k === 'arrowleft' || k === 'left' || code === 'Numpad4') return 'left';
    if (code === 'KeyD' || code === 'ArrowRight' || k === 'd' || k === 'arrowright' || k === 'right' || code === 'Numpad6') return 'right';
    return null;
  }

  private getMovementVector(): Point2D {
    let dx = 0;
    let dy = 0;

    if (this.activeMovementKeys.has('up')) dy -= 1;
    if (this.activeMovementKeys.has('down')) dy += 1;
    if (this.activeMovementKeys.has('left')) dx -= 1;
    if (this.activeMovementKeys.has('right')) dx += 1;

    if (dx !== 0 && dy !== 0) {
      const invLen = 1 / Math.SQRT2;
      dx *= invLen;
      dy *= invLen;
    }

    return { x: dx, y: dy };
  }

  private resizeCanvas() {
    this.pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
    const bounds = this.canvas.getBoundingClientRect();
    const w = Math.max(320, Math.floor(bounds.width));
    const h = Math.max(240, Math.floor(bounds.height));

    this.canvas.width = w * this.pixelRatio;
    this.canvas.height = h * this.pixelRatio;

    // Proportional scaling for mobile vs desktop viewports
    // Baseline reference: 680px minimum dimension (mobile phones ~360-390px, tablets ~600-800px, desktop 720-1080px+)
    const minDim = Math.min(w, h);
    const arenaScale = Math.max(0.60, Math.min(1.15, minDim / 680));
    this.player.setScale(arenaScale);
    this.swarm.setScale(arenaScale);
    this.weapons.setScale(arenaScale);
    this.gauntletMaze.setScale(arenaScale);
    this.renderer.setScale(arenaScale);

    this.grid.resize(w, h);
  }

  private requireElement(id: string): HTMLElement {
    const el = document.getElementById(id);
    if (!el) throw new Error(`Missing Tilt to Live element: ${id}`);
    return el;
  }
}
