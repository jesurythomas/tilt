// =========================================================================
// TiltGame.ts - Tilt to Live Master Game Controller
// =========================================================================

import { VectorGrid } from './VectorGrid';
import { ParticleEngine } from './ParticleEngine';
import { TiltAudio } from './TiltAudio';
import { PlayerShip } from './PlayerShip';
import { EnemySwarm } from './EnemySwarm';
import { WeaponSystem } from './WeaponSystem';
import { CoinSystem } from './CoinSystem';
import { ScoreManager } from './ScoreManager';
import { TiltRenderer } from './TiltRenderer';
import { TiltEntranceCinematic } from './TiltEntranceCinematic';
import { ProgressionManager } from './ProgressionManager';
import { ArmoryUI } from './ArmoryUI';
import { Enemy, GameMode, GamePhase, Point2D, WeaponOrb, WeaponType } from './Types';
import { GoalManager, RunTracker } from './GoalManager';
import { getTunedValue } from './WeaponTuning';
import { GameOptionsManager } from './GameOptions';
import { GoalsHUD } from './GoalsHUD';
import { TiltMenu } from './TiltMenu';
import { GauntletMaze } from './GauntletMaze';
import { GyroscopeController } from './GyroscopeController';

// Global simulation time scale applied ONLY to the fixed-step gameplay delta
// in TiltGame.loop() (the 'playing' phase accumulator). 1.0 = original speed;
// 0.75 = 25% slower. This uniformly slows everything driven by that delta -
// enemy movement, player movement, weapons/orb timers, coin spawn timers,
// and the survival clock (this.elapsed / ScoreManager.stats.survivalTime) -
// without hand-tuning individual systems. Tune this single constant to
// retime the whole game. Deliberately NOT applied to: the cold-open
// cinematic (real-time dt), menu background simulation (real-time dt), any
// DOM/UI animation or modal timing, or the game-over setTimeout.
export const GAME_SPEED = 0.75;

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
  public readonly coins: CoinSystem = new CoinSystem();
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

  // Autonomous Menu Background Simulation
  public readonly menuPlayer: PlayerShip = new PlayerShip(600, 350);
  public readonly menuSwarm: EnemySwarm = new EnemySwarm();
  public readonly menuWeapons: WeaponSystem = new WeaponSystem();
  private menuOrbTimer: number = 0;
  private menuSpawnTimer: number = 0;

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

  // Lives (Wave 2: progression.getStartingLives(), 1-3). Losing a life grants
  // a temporary shield instead of ending the run; only 0 lives ends it.
  public lives: number = 1;
  public maxLivesThisRun: number = 1;

  // Loop & Timing
  private isRunning: boolean = false;
  private animationFrame: number | null = null;
  private lastTime: number = 0;
  private accumulator: number = 0;
  private elapsed: number = 0;
  private pixelRatio: number = 1;

  // In-Run HUD & Edge Rail (Boards 05 & 15)
  public scoreEl!: HTMLElement;
  public bestScoreEl!: HTMLElement;
  public modeBadgeEl: HTMLElement | null = null;
  public chainPillEl!: HTMLElement;
  public chainCountEl!: HTMLElement;
  public durationIndicatorEl!: HTMLElement;
  public durationLabelEl!: HTMLElement;
  public durationFillEl!: HTMLElement;
  public leftRailFillEl!: HTMLElement | null;
  public livesEl!: HTMLElement;

  // Pause Screen (Board 07)
  public pauseModal!: HTMLElement;
  public pauseStatsEl!: HTMLElement;
  public resumeBtnEl!: HTMLElement;
  public soundToggleBtn!: HTMLElement;
  public musicToggleBtn!: HTMLElement;

  // Run Over / Death Screen (Boards 06 & 16)
  public gameOverModal!: HTMLElement;
  public finalScoreEl!: HTMLElement;
  public finalSubtitleEl!: HTMLElement;
  public newBestBannerEl!: HTMLElement;
  public newBestDiffEl!: HTMLElement;
  public finalKillsEl!: HTMLElement;
  public finalChainEl!: HTMLElement;
  public finalMultEl!: HTMLElement;
  public finalTimeEl!: HTMLElement;
  public finalCoinsEl!: HTMLElement;
  public pointsEarnedRowEl!: HTMLElement;
  public coinsRowEl!: HTMLElement;
  public coinsDetailEl!: HTMLElement;
  public milestonesListEl!: HTMLElement;
  public retryBtnEl!: HTMLElement;
  public spendBtnEl!: HTMLElement;

  // Rail Progress
  public railProgress: number = 0;

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
        // Wave 2: spawn the equipped ship's starting weapon orb only after
        // resetRun() (which clears weapon state) AND the cold-open cinematic
        // has finished — spawning any earlier would be wiped by either.
        this.spawnStartingWeaponOrb();
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

  private injectV2Styles() {
    // 1. Google Fonts
    if (!document.getElementById('tilt-fonts-link')) {
      const link = document.createElement('link');
      link.id = 'tilt-fonts-link';
      link.rel = 'stylesheet';
      link.href = 'https://fonts.googleapis.com/css2?family=Archivo:wght@500;600;700;800&family=IBM+Plex+Mono:wght@400;500;600;700&family=IBM+Plex+Sans:wght@400;500;600;700&display=swap';
      document.head.appendChild(link);
    }

    // 2. Comprehensive Design System Styles (Boards 01, 05, 06, 07, 15, 16)
    if (!document.getElementById('tilt-v2-theme-styles')) {
      const style = document.createElement('style');
      style.id = 'tilt-v2-theme-styles';
      style.textContent = `
        /* In-Run Clean Top & Bottom HUD (Boards 05 & 15) */
        .tilt-hud.game-hud {
          position: absolute;
          inset: 0;
          z-index: 10;
          padding: 0;
          pointer-events: none;
          font-family: 'IBM Plex Sans', sans-serif;
          display: block;
        }

        /* Score block top-left (Board 05) */
        .hud-score-block {
          position: absolute;
          left: 40px;
          top: 36px;
          display: flex;
          flex-direction: column;
          gap: 4px;
          pointer-events: auto;
        }

        .hud-score-display {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 52px;
          font-weight: 500;
          line-height: 1;
          font-variant-numeric: tabular-nums;
          letter-spacing: -0.02em;
          color: #E6E9F0;
          text-shadow: none;
        }

        .hud-score-meta {
          display: flex;
          align-items: center;
          gap: 12px;
          margin-top: 2px;
        }

        .hud-best-display {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 12px;
          font-variant-numeric: tabular-nums;
          color: #7A8397;
        }

        .hud-meta-divider {
          width: 1px;
          height: 11px;
          background: #262C38;
        }

        .hud-mode-display {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 12px;
          letter-spacing: 0.1em;
          text-transform: uppercase;
          color: #7A8397;
        }

        /* Multiplier Chain Pill (Board 05: Ion blue tint rgba(91,140,255,0.12), text #5B8CFF) */
        .hud-chain-pill {
          position: absolute;
          left: 40px;
          top: 152px;
          display: inline-flex;
          align-items: center;
          gap: 8px;
          padding: 7px 12px;
          background: rgba(91, 140, 255, 0.12);
          border: 1px solid rgba(91, 140, 255, 0.45);
          border-radius: 3px;
          pointer-events: auto;
          transition: opacity 0.2s ease;
        }

        .hud-chain-number {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 18px;
          font-weight: 600;
          line-height: 1;
          font-variant-numeric: tabular-nums;
          color: #5B8CFF;
        }

        .hud-chain-label {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 10px;
          letter-spacing: 0.14em;
          text-transform: uppercase;
          color: #8FB0FF;
        }

        /* Lives Pips (Wave 2: sits below the chain pill, never overlapping the
           score block or multiplier chip; hazard red reserved for enemies/death
           only, so pips use --ok green / --text-4 slate instead). Hidden entirely
           for the default 1-life run so it never clutters the HUD. */
        .hud-life-block {
          position: absolute;
          left: 40px;
          top: 202px;
          display: flex;
          align-items: center;
          gap: 7px;
          pointer-events: none;
        }

        .hud-life-pip {
          width: 10px;
          height: 10px;
          border-radius: 50%;
          box-sizing: border-box;
          border: 1.5px solid #4A5264;
          background: transparent;
        }

        .hud-life-pip.is-filled {
          border-color: #3DDC97;
          background: #3DDC97;
        }

        /* Top-Right 44px Icon Buttons (Board 05) */
        .hud-top-right {
          position: absolute;
          right: 36px;
          top: 34px;
          display: flex;
          gap: 8px;
          pointer-events: auto;
        }

        .hud-square-btn {
          width: 44px;
          height: 44px;
          border: 1px solid #262C38;
          border-radius: 4px;
          background: rgba(20, 24, 33, 0.85);
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: background 0.15s ease, border-color 0.15s ease, transform 0.1s ease;
          padding: 0;
        }

        .hud-square-btn:hover {
          background: rgba(27, 32, 41, 0.95);
          border-color: #3A4252;
        }

        .hud-square-btn:active {
          transform: scale(0.96);
        }

        /* Bottom Center: Active Shield / Weapon Duration (Board 05) */
        .hud-duration-indicator {
          position: absolute;
          left: 50%;
          bottom: 34px;
          transform: translateX(-50%);
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 7px;
          pointer-events: none;
        }

        .hud-duration-text {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 10px;
          letter-spacing: 0.16em;
          text-transform: uppercase;
          color: #5B8CFF;
        }

        .hud-duration-bar-track {
          width: 240px;
          height: 3px;
          border-radius: 2px;
          background: #1B2029;
          position: relative;
          overflow: hidden;
        }

        .hud-duration-bar-fill {
          position: absolute;
          left: 0;
          top: 0;
          bottom: 0;
          border-radius: 2px;
          background: #5B8CFF;
          transition: width 0.1s linear;
        }

        /* Bottom Right: Active Secondary Ability Cooldown (Board 05) */
        .hud-secondary-ability {
          position: absolute;
          right: 40px;
          bottom: 36px;
          display: flex;
          align-items: center;
          gap: 10px;
          pointer-events: auto;
        }

        .hud-secondary-name {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 11px;
          letter-spacing: 0.1em;
          text-transform: uppercase;
          color: #4A5264;
          transition: color 0.2s ease;
        }

        .hud-secondary-ability.is-ready .hud-secondary-name {
          color: #A78BFA;
        }

        .hud-secondary-bar-track {
          width: 90px;
          height: 3px;
          border-radius: 2px;
          background: #1B2029;
          position: relative;
          overflow: hidden;
        }

        .hud-secondary-bar-fill {
          position: absolute;
          left: 0;
          top: 0;
          bottom: 0;
          border-radius: 2px;
          background: #A78BFA;
          transition: width 0.1s linear;
        }

        .hud-secondary-key {
          width: 26px;
          height: 26px;
          border: 1px solid #A78BFA;
          border-radius: 3px;
          background: rgba(167, 139, 250, 0.08);
          display: flex;
          align-items: center;
          justify-content: center;
          font-family: 'IBM Plex Mono', monospace;
          font-size: 11px;
          font-weight: 600;
          color: #A78BFA;
          cursor: pointer;
          padding: 0;
          transition: all 0.15s ease;
        }

        .hud-secondary-key:hover {
          background: rgba(167, 139, 250, 0.2);
          transform: scale(1.05);
        }

        .hud-secondary-key:disabled {
          opacity: 0.4;
          cursor: not-allowed;
          transform: none;
        }

        /* Left Edge Rail (Board 05: 4px Rail smoothly updating height) */
        .tilt-left-edge-rail {
          position: absolute;
          left: 0;
          top: 0;
          bottom: 0;
          width: 4px;
          background: #11151D;
          z-index: 12;
          pointer-events: none;
        }

        .left-rail-fill {
          position: absolute;
          left: 0;
          top: 0;
          width: 4px;
          background: #5B8CFF;
          transition: height 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
        }

        .left-rail-tick {
          position: absolute;
          left: 0;
          width: 4px;
          height: 2px;
          background: #0D1016;
        }

        /* In-run goal sidebar occlusion prevention (Board 02 Finding 5) */
        body.tilt-playing #tilt-goals-sidebar {
          display: none !important;
        }

        /* Pause Screen Modal (Board 07) */
        #tilt-pause-overlay {
          position: absolute;
          inset: 0;
          z-index: 60;
          display: flex;
          align-items: center;
          justify-content: center;
          background: rgba(8, 9, 14, 0.80);
        }

        .pause-modal-panel {
          position: relative;
          width: 420px;
          max-width: calc(100vw - 32px);
          box-sizing: border-box;
          padding: 32px;
          background: #12161F;
          border: 1px solid #262C38;
          border-radius: 10px;
          display: flex;
          flex-direction: column;
          gap: 22px;
          box-shadow: 0 32px 80px rgba(0, 0, 0, 0.6);
          font-family: 'IBM Plex Sans', sans-serif;
          color: #E6E9F0;
        }

        .pause-header {
          display: flex;
          align-items: baseline;
          justify-content: space-between;
        }

        .pause-title {
          margin: 0;
          font-family: 'Archivo', sans-serif;
          font-stretch: 112%;
          font-weight: 700;
          font-size: 26px;
          color: #E6E9F0;
        }

        .pause-stats {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 13px;
          font-variant-numeric: tabular-nums;
          color: #7A8397;
        }

        .pause-actions {
          display: flex;
          flex-direction: column;
          gap: 10px;
        }

        .pause-resume-btn {
          height: 52px;
          border: none;
          border-radius: 6px;
          background: #5B8CFF;
          color: #08090E;
          font-family: 'IBM Plex Sans', sans-serif;
          font-size: 16px;
          font-weight: 600;
          cursor: pointer;
          outline: 2px solid rgba(91, 140, 255, 0.45);
          outline-offset: 3px;
          transition: all 0.15s ease;
        }

        .pause-resume-btn:hover, .pause-resume-btn:focus {
          background: #759FFF;
          outline-color: #5B8CFF;
        }

        .pause-action-btn {
          height: 44px;
          border: 1px solid #3A4252;
          border-radius: 6px;
          background: transparent;
          color: #C7CDDB;
          font-family: 'IBM Plex Sans', sans-serif;
          font-size: 14px;
          font-weight: 500;
          cursor: pointer;
          transition: all 0.15s ease;
        }

        .pause-action-btn:hover {
          background: #1B2029;
          border-color: #5B8CFF;
          color: #E6E9F0;
        }

        .pause-divider {
          height: 1px;
          background: #262C38;
        }

        .pause-toggles {
          display: flex;
          flex-direction: column;
          gap: 14px;
        }

        .pause-toggle-row {
          display: flex;
          align-items: center;
          justify-content: space-between;
        }

        .toggle-label {
          font-size: 14px;
          color: #C7CDDB;
        }

        .switch-toggle {
          width: 44px;
          height: 26px;
          border-radius: 13px;
          position: relative;
          cursor: pointer;
          padding: 0;
          transition: all 0.2s ease;
          border: 1px solid #3A4252;
          background: #1B2029;
        }

        .switch-toggle.is-on {
          border: 1px solid #5B8CFF;
          background: rgba(91, 140, 255, 0.2);
        }

        .switch-handle {
          position: absolute;
          top: 3px;
          left: 3px;
          width: 18px;
          height: 18px;
          border-radius: 50%;
          background: #626B7E;
          display: block;
          transition: all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
        }

        .switch-toggle.is-on .switch-handle {
          transform: translateX(18px);
          background: #5B8CFF;
        }

        .pause-all-settings-link {
          font-size: 13px;
          color: #99A1B3;
          text-decoration: none;
          background: transparent;
          border: none;
          border-bottom: 1px solid #262C38;
          align-self: flex-start;
          padding: 0 0 2px 0;
          cursor: pointer;
          font-family: inherit;
          transition: color 0.15s ease, border-bottom-color 0.15s ease;
        }

        .pause-all-settings-link:hover {
          color: #E6E9F0;
          border-bottom-color: #5B8CFF;
        }

        .pause-caption {
          text-align: center;
          font-family: 'IBM Plex Mono', monospace;
          font-size: 11px;
          letter-spacing: 0.08em;
          color: #4A5264;
        }

        /* Run Over / Death Screen Modal (Boards 06 & 16) */
        #tilt-gameover-modal {
          position: absolute;
          inset: 0;
          z-index: 60;
          display: flex;
          align-items: center;
          justify-content: center;
          background: rgba(8, 9, 14, 0.86);
        }

        .gameover-modal-panel {
          position: relative;
          width: 520px;
          max-width: calc(100vw - 32px);
          box-sizing: border-box;
          padding: 40px;
          background: #12161F;
          border: 1px solid #262C38;
          border-radius: 10px;
          display: flex;
          flex-direction: column;
          gap: 26px;
          box-shadow: 0 32px 80px rgba(0, 0, 0, 0.6);
          font-family: 'IBM Plex Sans', sans-serif;
          color: #E6E9F0;
        }

        .mobile-sheet-handle {
          display: none;
        }

        .gameover-header {
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 6px;
          text-align: center;
        }

        .gameover-final-score {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 68px;
          font-weight: 500;
          line-height: 1;
          letter-spacing: -0.02em;
          font-variant-numeric: tabular-nums;
          color: #E6E9F0;
        }

        .gameover-subtitle {
          font-size: 13px;
          color: #7A8397;
        }

        .gameover-best-banner {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          padding: 9px;
          background: rgba(255, 177, 77, 0.08);
          border: 1px solid rgba(255, 177, 77, 0.30);
          border-radius: 4px;
          font-size: 13px;
          font-weight: 600;
          color: #FFB14D;
        }

        .gameover-stat-grid {
          display: grid;
          grid-template-columns: repeat(4, minmax(0, 1fr));
          gap: 1px;
          background: #262C38;
          border: 1px solid #262C38;
          border-radius: 6px;
          overflow: hidden;
        }

        .stat-cell {
          background: #161B25;
          padding: 14px 10px;
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 4px;
        }

        .stat-number {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 20px;
          font-weight: 500;
          font-variant-numeric: tabular-nums;
          color: #E6E9F0;
        }

        .stat-label {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 10px;
          letter-spacing: 0.12em;
          text-transform: uppercase;
          color: #7A8397;
        }

        .gameover-points-section {
          display: flex;
          flex-direction: column;
          gap: 10px;
        }

        .gameover-points-row {
          display: flex;
          align-items: baseline;
          justify-content: space-between;
        }

        .points-label {
          font-size: 13px;
          color: #99A1B3;
        }

        .points-val {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 15px;
          font-weight: 500;
          font-variant-numeric: tabular-nums;
          color: #FFB14D;
        }

        .points-arrow {
          color: #7A8397;
          margin: 0 4px;
        }

        .gameover-milestones-list {
          display: flex;
          flex-direction: column;
          gap: 6px;
        }

        .gameover-milestone-item {
          display: flex;
          align-items: center;
          gap: 9px;
        }

        .milestone-text {
          font-size: 13px;
          color: #C7CDDB;
          flex-grow: 1;
        }

        .milestone-points {
          font-family: 'IBM Plex Mono', monospace;
          font-size: 12px;
          color: #FFB14D;
        }

        .gameover-actions {
          display: flex;
          flex-direction: column;
          gap: 10px;
        }

        .btn-primary-retry {
          height: 54px;
          border: none;
          border-radius: 6px;
          background: #5B8CFF;
          color: #08090E;
          font-family: 'IBM Plex Sans', sans-serif;
          font-size: 17px;
          font-weight: 600;
          cursor: pointer;
          outline: 2px solid rgba(91, 140, 255, 0.45);
          outline-offset: 3px;
          transition: all 0.15s ease;
        }

        .btn-primary-retry:hover, .btn-primary-retry:focus {
          background: #759FFF;
          outline-color: #5B8CFF;
        }

        .gameover-secondary-row {
          display: flex;
          gap: 10px;
        }

        .btn-secondary-action {
          flex-grow: 1;
          height: 44px;
          border: 1px solid #3A4252;
          border-radius: 6px;
          background: transparent;
          color: #C7CDDB;
          font-family: 'IBM Plex Sans', sans-serif;
          font-size: 14px;
          font-weight: 500;
          cursor: pointer;
          transition: all 0.15s ease;
        }

        .btn-secondary-action:hover {
          background: #1B2029;
          border-color: #5B8CFF;
          color: #E6E9F0;
        }

        .gameover-caption {
          text-align: center;
          font-family: 'IBM Plex Mono', monospace;
          font-size: 11px;
          letter-spacing: 0.08em;
          color: #4A5264;
        }

        /* Mobile Responsiveness (Boards 15 & 16) */
        @media (max-width: 640px) {
          .hud-score-block {
            left: 20px;
            top: 58px;
            gap: 3px;
          }

          .hud-score-display {
            font-size: 34px;
          }

          .hud-best-display {
            font-size: 11px;
          }

          .hud-chain-pill {
            left: 20px;
            top: 122px;
            padding: 5px 9px;
          }

          .hud-chain-number {
            font-size: 14px;
          }

          .hud-life-block {
            left: 20px;
            top: 166px;
            gap: 6px;
          }

          .hud-life-pip {
            width: 8px;
            height: 8px;
          }

          .hud-top-right {
            right: 18px;
            top: 54px;
          }

          .hud-square-btn {
            width: 46px;
            height: 46px;
            border-radius: 6px;
          }

          .hud-duration-indicator {
            bottom: 52px;
          }

          .hud-duration-bar-track {
            width: 180px;
          }

          .tilt-left-edge-rail {
            width: 3px;
          }

          .left-rail-fill {
            width: 3px;
          }

          /* Mobile Run Over: Bottom Sheet (Board 16) */
          #tilt-gameover-modal {
            align-items: flex-end;
            background: rgba(8, 9, 14, 0.86);
          }

          .gameover-modal-panel {
            width: 100%;
            max-width: 100vw;
            border-radius: 16px 16px 0 0;
            border-left: none;
            border-right: none;
            border-bottom: none;
            border-top: 1px solid #262C38;
            padding: 28px 24px 34px;
            gap: 22px;
            max-height: 92vh;
            overflow-y: auto;
          }

          .mobile-sheet-handle {
            display: block;
            width: 40px;
            height: 4px;
            border-radius: 2px;
            background: #262C38;
            margin: 0 auto;
          }

          .gameover-final-score {
            font-size: 52px;
          }

          .gameover-subtitle {
            font-size: 12px;
          }

          .stat-number {
            font-size: 17px;
          }

          .btn-primary-retry {
            height: 56px;
          }

          .btn-secondary-action {
            height: 46px;
          }
        }
      `;
      document.head.appendChild(style);
    }
  }

  private bindDOM() {
    this.injectV2Styles();

    const stage = document.getElementById('tilt-stage') || document.body;

    // 1. Left Edge Rail (#tilt-left-edge-rail) - Board 05: 4px rail smoothly updating height
    let leftRail = document.getElementById('tilt-left-edge-rail');
    if (!leftRail) {
      leftRail = document.createElement('div');
      leftRail.id = 'tilt-left-edge-rail';
      leftRail.className = 'tilt-left-edge-rail';
      leftRail.innerHTML = `
        <div id="tilt-left-rail-fill" class="left-rail-fill" style="height: 0%;"></div>
        <div class="left-rail-tick" style="top: 25%;"></div>
        <div class="left-rail-tick" style="top: 50%;"></div>
        <div class="left-rail-tick" style="top: 75%;"></div>
      `;
      stage.appendChild(leftRail);
    }
    this.leftRailFillEl = document.getElementById('tilt-left-rail-fill');

    // Also link legacy #tilt-edge-rail-fill if present
    const legacyRailFill = document.getElementById('tilt-edge-rail-fill');
    if (legacyRailFill && !this.leftRailFillEl) {
      this.leftRailFillEl = legacyRailFill;
    }

    // 2. In-Run Top & Bottom HUD (Boards 05 & 15)
    let hud = document.querySelector('.tilt-hud') as HTMLElement | null;
    if (!hud) {
      hud = document.createElement('div');
      hud.className = 'tilt-hud game-hud';
      stage.appendChild(hud);
    }
    hud.innerHTML = `
      <!-- Score Top-Left Block (Board 05) -->
      <div class="hud-score-block">
        <span id="tilt-score" class="hud-score-display">0</span>
        <div class="hud-score-meta">
          <span id="tilt-best" class="hud-best-display">BEST 0</span>
          <span class="hud-meta-divider"></span>
          <span id="tilt-hud-mode" class="hud-mode-display">Standard</span>
        </div>
      </div>

      <!-- Multiplier Chain Pill (Board 05: Ion blue tint rgba(91,140,255,0.12), text #5B8CFF) -->
      <div id="tilt-hud-chain" class="hud-chain-pill">
        <span id="tilt-chain-count" class="hud-chain-number">1×</span>
        <span class="hud-chain-label">CHAIN</span>
      </div>

      <!-- Lives Pips (Wave 2: hidden for default 1-life runs) -->
      <div id="tilt-hud-lives" class="hud-life-block hidden"></div>

      <!-- Top-Right 44px Icon Buttons (Board 05) -->
      <div class="hud-top-right">
        <button id="btn-tilt-pause" type="button" class="hud-square-btn" aria-label="Pause" title="Pause (ESC)">
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
            <rect x="4" y="3" width="3" height="10" rx="1" fill="#C7CDDB"></rect>
            <rect x="9" y="3" width="3" height="10" rx="1" fill="#C7CDDB"></rect>
          </svg>
        </button>
        <button id="btn-tilt-menu" type="button" class="hud-square-btn" aria-label="Quit to menu" title="Quit to menu">
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
            <path d="M2.5 7.5 L8 2.5 L13.5 7.5 V13 H2.5 Z" stroke="#C7CDDB" stroke-width="1.4" stroke-linejoin="round"></path>
          </svg>
        </button>
      </div>

      <!-- Bottom Center Shield/Weapon Duration (Board 05) -->
      <div id="tilt-hud-duration" class="hud-duration-indicator hidden">
        <span id="tilt-hud-duration-label" class="hud-duration-text">Shield 1.6s</span>
        <div class="hud-duration-bar-track">
          <div id="tilt-hud-duration-bar-fill" class="hud-duration-bar-fill" style="width: 54%;"></div>
        </div>
      </div>

    `;

    this.scoreEl = this.requireElement('tilt-score');
    this.bestScoreEl = this.requireElement('tilt-best');
    this.modeBadgeEl = document.getElementById('tilt-hud-mode');
    this.chainPillEl = this.requireElement('tilt-hud-chain');
    this.chainCountEl = this.requireElement('tilt-chain-count');
    this.livesEl = this.requireElement('tilt-hud-lives');
    this.durationIndicatorEl = this.requireElement('tilt-hud-duration');
    this.durationLabelEl = this.requireElement('tilt-hud-duration-label');
    this.durationFillEl = this.requireElement('tilt-hud-duration-bar-fill');

    // 3. Pause Overlay Modal (Board 07)
    this.pauseModal = this.requireElement('tilt-pause-overlay');
    this.pauseModal.innerHTML = `
      <div class="pause-modal-panel">
        <div class="pause-header">
          <h2 class="pause-title">Paused</h2>
          <span id="tilt-pause-stats" class="pause-stats">0 · 0:00</span>
        </div>
        <div class="pause-actions">
          <button id="btn-tilt-resume" type="button" class="pause-resume-btn">Resume</button>
          <button id="btn-tilt-restart-pause" type="button" class="pause-action-btn">Restart run</button>
          <button id="btn-tilt-menu-pause" type="button" class="pause-action-btn">Quit to menu</button>
        </div>
        <div class="pause-divider"></div>
        <div class="pause-toggles">
          <div class="pause-toggle-row">
            <label for="p-sound" class="toggle-label">Sound</label>
            <button id="p-sound" type="button" role="switch" aria-checked="true" class="switch-toggle is-on">
              <span class="switch-handle"></span>
            </button>
          </div>
          <div class="pause-toggle-row">
            <label for="p-music" class="toggle-label">Music</label>
            <button id="p-music" type="button" role="switch" aria-checked="true" class="switch-toggle is-on">
              <span class="switch-handle"></span>
            </button>
          </div>
          <button id="btn-tilt-all-settings" type="button" class="pause-all-settings-link">All settings</button>
        </div>
        <span class="pause-caption">ESC to resume</span>
      </div>
    `;
    this.pauseStatsEl = this.requireElement('tilt-pause-stats');
    this.resumeBtnEl = this.requireElement('btn-tilt-resume');
    this.soundToggleBtn = this.requireElement('p-sound');
    this.musicToggleBtn = this.requireElement('p-music');

    // 4. Run Over / Death Screen Modal (Boards 06 & 16)
    this.gameOverModal = this.requireElement('tilt-gameover-modal');
    this.gameOverModal.innerHTML = `
      <div class="gameover-modal-panel">
        <div class="mobile-sheet-handle"></div>
        <div class="gameover-header">
          <span id="tilt-final-score" class="gameover-final-score">0</span>
          <span id="tilt-final-subtitle" class="gameover-subtitle">Swarmed at 0:00 — Standard, 1.0×</span>
        </div>
        <div id="tilt-new-best-banner" class="gameover-best-banner hidden">
          <svg width="13" height="13" viewBox="0 0 13 13" fill="none" aria-hidden="true">
            <path d="M6.5 1 L8.2 4.7 L12 5.2 L9.2 8 L9.9 12 L6.5 10.1 L3.1 12 L3.8 8 L1 5.2 L4.8 4.7 Z" stroke="#FFB14D" stroke-width="1.1" stroke-linejoin="round"></path>
          </svg>
          <span id="tilt-new-best-diff">New best — up 0</span>
        </div>
        <div class="gameover-stat-grid">
          <div class="stat-cell">
            <span id="tilt-final-kills" class="stat-number">0</span>
            <span class="stat-label">Kills</span>
          </div>
          <div class="stat-cell">
            <span id="tilt-final-chain" class="stat-number">1×</span>
            <span class="stat-label">Best chain</span>
          </div>
          <div class="stat-cell">
            <span id="tilt-final-time" class="stat-number">0:00</span>
            <span class="stat-label">Alive</span>
          </div>
          <div class="stat-cell">
            <span id="tilt-final-coins" class="stat-number" style="color: #FFB14D;">0</span>
            <span class="stat-label">Coins</span>
          </div>
        </div>
        <div class="gameover-points-section">
          <div class="gameover-points-row">
            <span class="points-label">Points earned</span>
            <span id="tilt-final-points-row" class="points-val">+0 <span class="points-arrow">→</span> 0</span>
          </div>
          <div id="tilt-gameover-coins-row" class="gameover-points-row hidden">
            <span class="points-label">Coin pickups</span>
            <span id="tilt-final-coins-detail" class="points-val">0 · +0 pts</span>
          </div>
          <div id="tilt-gameover-milestones" class="gameover-milestones-list hidden"></div>
        </div>
        <div class="gameover-actions">
          <button id="btn-tilt-retry" type="button" class="btn-primary-retry">Retry</button>
          <div class="gameover-secondary-row">
            <button id="btn-tilt-menu-gameover" type="button" class="btn-secondary-action">Menu</button>
            <button id="btn-tilt-spend" type="button" class="btn-secondary-action">Spend 0</button>
          </div>
          <span class="gameover-caption">SPACE to retry</span>
        </div>
      </div>
    `;

    this.finalScoreEl = this.requireElement('tilt-final-score');
    this.finalSubtitleEl = this.requireElement('tilt-final-subtitle');
    this.newBestBannerEl = this.requireElement('tilt-new-best-banner');
    this.newBestDiffEl = this.requireElement('tilt-new-best-diff');
    this.finalKillsEl = this.requireElement('tilt-final-kills');
    this.finalChainEl = this.requireElement('tilt-final-chain');
    this.finalMultEl = this.finalChainEl;
    this.finalTimeEl = this.requireElement('tilt-final-time');
    this.finalCoinsEl = this.requireElement('tilt-final-coins');
    this.pointsEarnedRowEl = this.requireElement('tilt-final-points-row');
    this.coinsRowEl = this.requireElement('tilt-gameover-coins-row');
    this.coinsDetailEl = this.requireElement('tilt-final-coins-detail');
    this.milestonesListEl = this.requireElement('tilt-gameover-milestones');
    this.retryBtnEl = this.requireElement('btn-tilt-retry');
    this.spendBtnEl = this.requireElement('btn-tilt-spend');
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

      if (e.code === 'Space' || e.code === 'Enter' || key === 'r') {
        if (this.phase === 'game-over') {
          e.preventDefault();
          this.startCinematic();
          return;
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

    // UI Buttons - In-Run HUD (Board 05 & 15)
    document.getElementById('btn-tilt-pause')?.addEventListener('click', () => {
      this.togglePause();
    });

    document.getElementById('btn-tilt-menu')?.addEventListener('click', () => {
      this.returnToMenu();
    });



    // Pause Screen Buttons & Switches (Board 07)
    document.getElementById('btn-tilt-resume')?.addEventListener('click', () => {
      this.togglePause();
    });

    document.getElementById('btn-tilt-restart-pause')?.addEventListener('click', (e) => {
      (e.currentTarget as HTMLElement)?.blur();
      this.startCinematic();
    });

    document.getElementById('btn-tilt-restart')?.addEventListener('click', (e) => {
      (e.currentTarget as HTMLElement)?.blur();
      this.startCinematic();
    });

    document.getElementById('btn-tilt-menu-pause')?.addEventListener('click', () => {
      this.returnToMenu();
    });

    this.soundToggleBtn?.addEventListener('click', () => {
      const active = !this.options.settings.sfxEnabled;
      this.options.settings.sfxEnabled = active;
      this.options.save();
      this.audio.setMuted(!active);
      this.soundToggleBtn.setAttribute('aria-checked', active ? 'true' : 'false');
      this.soundToggleBtn.classList.toggle('is-on', active);
    });

    this.musicToggleBtn?.addEventListener('click', () => {
      const active = !this.options.settings.musicEnabled;
      this.options.settings.musicEnabled = active;
      this.options.save();
      if (active) {
        if (this.phase === 'playing') this.audio.startMusic();
      } else {
        this.audio.stopMusic();
      }
      this.musicToggleBtn.setAttribute('aria-checked', active ? 'true' : 'false');
      this.musicToggleBtn.classList.toggle('is-on', active);
    });

    document.getElementById('btn-tilt-all-settings')?.addEventListener('click', () => {
      this.menu.openOptionsModal();
    });

    // Run Over Screen Buttons (Boards 06 & 16)
    document.getElementById('btn-tilt-retry')?.addEventListener('click', (e) => {
      (e.currentTarget as HTMLElement)?.blur();
      this.startCinematic();
    });

    document.getElementById('btn-tilt-menu-gameover')?.addEventListener('click', () => {
      this.returnToMenu();
    });

    document.getElementById('btn-tilt-spend')?.addEventListener('click', () => {
      this.openArmory();
    });

    document.getElementById('btn-tilt-armory-gameover')?.addEventListener('click', () => {
      this.openArmory();
    });

    document.getElementById('btn-tilt-sound')?.addEventListener('click', () => {
      const active = this.audio.toggleMute();
      this.options.settings.sfxEnabled = active;
      this.options.settings.musicEnabled = active;
      this.options.save();
      const btn = document.getElementById('btn-tilt-sound');
      if (btn) btn.textContent = active ? 'Sound on' : 'Sound off';
    });

    document.getElementById('btn-tilt-portal')?.addEventListener('click', () => {
      this.returnToMenu();
    });

    document.getElementById('btn-tilt-armory-hud')?.addEventListener('click', () => {
      this.openArmory();
    });

    document.getElementById('btn-tilt-armory-pause')?.addEventListener('click', () => {
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
    document.body.classList.remove('tilt-playing');

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
    document.body.classList.remove('tilt-playing');
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
    this.scores.setProgressionMultiplier(this.progression.getScoreMultiplier());

    if (this.options.settings.controlScheme === 'gyro') {
      this.gyro.startListening();
    } else {
      this.gyro.stopListening();
    }

    const width = this.canvas.width / this.pixelRatio;
    const height = this.canvas.height / this.pixelRatio;

    this.phase = 'playing';
    document.body.classList.add('tilt-playing');
    this.elapsed = 0;
    this.accumulator = 0;
    this.pointsEarnedThisRun = 0;
    this.maxLivesThisRun = this.progression.getStartingLives();
    this.lives = this.maxLivesThisRun;
    // Hull Compact shrinks the hitbox; it stacks with the equipped ship's own hitboxScale.
    this.player.setHitboxMultiplier(this.progression.getHitboxMultiplier());
    // The shield.radius perk's only consumer is the bubble PlayerShip draws.
    this.player.setShieldRadius(
      getTunedValue('shield', 'radius', this.progression.data.perks.shield.radius)
    );
    this.railProgress = 0;
    if (this.leftRailFillEl) this.leftRailFillEl.style.height = '0%';

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
    this.swarm.setSpeedScale(this.progression.getEnemySpeedMultiplier());
    this.weapons.reset();
    this.coins.reset();
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
      this.audio.stopMusic();

      const timeStr = this.formatTime(this.elapsed);
      this.pauseStatsEl.textContent = `${this.scores.stats.score.toLocaleString()} · ${timeStr}`;

      this.soundToggleBtn.setAttribute('aria-checked', this.options.settings.sfxEnabled ? 'true' : 'false');
      this.soundToggleBtn.classList.toggle('is-on', this.options.settings.sfxEnabled);

      this.musicToggleBtn.setAttribute('aria-checked', this.options.settings.musicEnabled ? 'true' : 'false');
      this.musicToggleBtn.classList.toggle('is-on', this.options.settings.musicEnabled);

      this.pauseModal.classList.remove('hidden');
      this.resumeBtnEl.focus();
    } else if (this.phase === 'paused') {
      this.phase = 'playing';
      this.pauseModal.classList.add('hidden');
      if (this.options.settings.musicEnabled) {
        this.audio.startMusic();
      }
    }
  }

  public formatTime(secs: number): string {
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  private updateMenuSimulation(dt: number) {
    this.elapsed += dt;
    const width = this.canvas.width / this.pixelRatio;
    const height = this.canvas.height / this.pixelRatio;
    const bounds = { width, height };

    this.grid.update(dt);
    this.particles.update(dt);

    // 1. Maintain 2 to 3 base weapon orbs (strictly base power ups: nuke, missiles, laser, freeze, shield, lightning)
    this.menuOrbTimer -= dt;
    if (this.menuWeapons.orbs.length < 2 && this.menuOrbTimer <= 0) {
      const baseTypes: WeaponType[] = ['nuke', 'missiles', 'laser', 'freeze', 'shield', 'lightning'];
      const chosen = baseTypes[Math.floor(Math.random() * baseTypes.length)];
      // Spawn preferentially in the right 60% of the screen so it's not hidden behind the menu sidebar
      const spawnX = bounds.width * 0.38 + Math.random() * (bounds.width * 0.55);
      const spawnY = 80 + Math.random() * (bounds.height - 160);
      this.menuWeapons.spawnOrb(bounds, chosen, spawnX, spawnY);
      this.menuOrbTimer = 2.5 + Math.random() * 2.0;
    }

    // 2. Maintain 12 to 16 seekers
    this.menuSpawnTimer -= dt;
    if (this.menuSwarm.enemies.length < 14 && this.menuSpawnTimer <= 0) {
      this.menuSwarm.spawnSeeker(bounds);
      this.menuSpawnTimer = 0.5 + Math.random() * 0.4;
    }

    // 3. Autopilot Steer Vector Calculation
    let nearestOrb: WeaponOrb | null = null;
    let minDist = Infinity;
    for (const orb of this.menuWeapons.orbs) {
      const dx = orb.x - this.menuPlayer.x;
      const dy = orb.y - this.menuPlayer.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < minDist) {
        minDist = dist;
        nearestOrb = orb;
      }
    }

    let steerX = 0;
    let steerY = 0;

    if (nearestOrb) {
      // Seek closest power-up orb
      const dx = nearestOrb.x - this.menuPlayer.x;
      const dy = nearestOrb.y - this.menuPlayer.y;
      const dist = Math.max(1, minDist);
      steerX = (dx / dist) * 290;
      steerY = (dy / dist) * 290;
    } else {
      // Wander in gentle figure-8 loop in open right arena
      const cx = bounds.width * 0.62;
      const cy = bounds.height * 0.5;
      const angle = this.elapsed * 0.8;
      const wanderX = cx + Math.cos(angle) * (bounds.width * 0.22);
      const wanderY = cy + Math.sin(angle * 2) * (bounds.height * 0.18);
      const dx = wanderX - this.menuPlayer.x;
      const dy = wanderY - this.menuPlayer.y;
      const dist = Math.max(1, Math.sqrt(dx * dx + dy * dy));
      steerX = (dx / dist) * 160;
      steerY = (dy / dist) * 160;
    }

    // 4. Repulsive force from nearby enemies (evasion!)
    const dangerRadius = 145;
    for (const e of this.menuSwarm.enemies) {
      const ex = this.menuPlayer.x - e.x;
      const ey = this.menuPlayer.y - e.y;
      const edist = Math.sqrt(ex * ex + ey * ey);
      if (edist < dangerRadius && edist > 0.1) {
        const repulsion = Math.pow((dangerRadius - edist) / dangerRadius, 1.8) * 520;
        steerX += (ex / edist) * repulsion;
        steerY += (ey / edist) * repulsion;
      }
    }

    // 5. Boundary repulsion to stay in visible playing area and avoid sidebar
    const leftMargin = Math.min(bounds.width * 0.38, 420);
    const rightMargin = 60;
    const topMargin = 60;
    const botMargin = 60;

    if (this.menuPlayer.x < leftMargin) {
      steerX += ((leftMargin - this.menuPlayer.x) / leftMargin) * 450;
    } else if (this.menuPlayer.x > bounds.width - rightMargin) {
      steerX -= ((this.menuPlayer.x - (bounds.width - rightMargin)) / rightMargin) * 450;
    }
    if (this.menuPlayer.y < topMargin) {
      steerY += ((topMargin - this.menuPlayer.y) / topMargin) * 380;
    } else if (this.menuPlayer.y > bounds.height - botMargin) {
      steerY -= ((this.menuPlayer.y - (bounds.height - botMargin)) / botMargin) * 380;
    }

    const targetPos = {
      x: this.menuPlayer.x + steerX,
      y: this.menuPlayer.y + steerY
    };

    // Update menu player
    this.menuPlayer.update(
      dt,
      targetPos,
      bounds,
      this.particles,
      'mouse',
      { x: 0, y: 0 },
      { sensitivity: 1.0, deadzone: 2 },
      undefined
    );

    // Update menu swarm
    this.menuSwarm.update(
      dt,
      { x: this.menuPlayer.x, y: this.menuPlayer.y },
      bounds,
      this.particles,
      0,
      'classic'
    );

    // Defensive shield activation if close call
    for (const e of this.menuSwarm.enemies) {
      const cdx = e.x - this.menuPlayer.x;
      const cdy = e.y - this.menuPlayer.y;
      if (cdx * cdx + cdy * cdy <= (e.radius + this.menuPlayer.radius + 6) * (e.radius + this.menuPlayer.radius + 6)) {
        if (!this.menuPlayer.hasShield()) {
          this.menuPlayer.activateShield(3.0);
          this.particles.emitExplosion(this.menuPlayer.x, this.menuPlayer.y, '#5B8CFF', 14);
          this.grid.applyExplosion(this.menuPlayer.x, this.menuPlayer.y, 8, 80);
        }
      }
    }

    // Silent audio stub for background menu simulation
    const silentAudio = {
      playSfx: () => {},
      playOrbPickup: () => {},
      playNuke: () => {},
      playMissileLaunch: () => {},
      playMissileExplode: () => {},
      playLaserBeam: () => {},
      playLightning: () => {},
      playFreeze: () => {},
      playIceShatter: () => {},
      playVortex: () => {},
      playDotPop: () => {},
      playCloseCall: () => {},
      playPlayerDeath: () => {},
      playMilestone: () => {},
      playSpaceInvaderStep: () => {},
      playSiren: () => {},
      playIceCascade: () => {},
      playGauntletKlaxon: () => {}
    } as unknown as TiltAudio;

    // Update menu weapons
    this.menuWeapons.update(
      dt,
      this.menuPlayer,
      this.menuSwarm.enemies,
      bounds,
      this.particles,
      this.grid,
      silentAudio,
      (deadEnemy) => {
        this.menuSwarm.onEnemyKilled(deadEnemy, this.particles);
      }
    );
  }

  private loop(currentTime: number) {
    if (!this.isRunning) return;

    const rawDelta = (currentTime - this.lastTime) / 1000;
    this.lastTime = currentTime;
    const dt = Math.min(0.1, rawDelta);

    if (this.phase === 'menu') {
      this.updateMenuSimulation(dt);
    } else if (this.phase === 'cinematic') {
      const width = this.canvas.width / this.pixelRatio;
      const height = this.canvas.height / this.pixelRatio;
      this.grid.update(dt);
      this.particles.update(dt);
      this.cinematic.update(dt, width, height);
    } else if (this.phase === 'playing') {
      // Accumulate REAL time so the substep cadence (how many 120Hz steps run
      // per real second) is unaffected by GAME_SPEED - only scale the
      // simulation delta actually passed to update(), so the whole sim
      // advances 25% slower per real second without destabilizing the
      // fixed-step accumulator.
      this.accumulator += dt;
      const fixedDt = 1 / 120; // 120Hz physics sub-stepping for silky precision
      while (this.accumulator >= fixedDt) {
        this.update(fixedDt * GAME_SPEED);
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
        () => this.loseLife()
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

    // 5.5 Update Coin Pickups (own spawn timer, independent of weapon orbs)
    const modeConfig = this.options.getModeConfig(activeMode);
    this.coins.update(
      dt,
      this.player,
      bounds,
      this.particles,
      this.audio,
      modeConfig.scoreMultiplier,
      (value) => this.progression.addPointsCredited(value)
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

  // Wave 2: spawns the equipped ship's startingWeapon orb, offset from the
  // player's centered spawn point so it's reachable but not sitting on top
  // of them. Called only from the cinematic-complete callback (see comment
  // there) so it always lands after resetRun() clears weapon state.
  private spawnStartingWeaponOrb() {
    const startingWeapon = this.progression.getEquippedShip().startingWeapon;
    if (!startingWeapon) return;

    const width = this.canvas.width / this.pixelRatio;
    const height = this.canvas.height / this.pixelRatio;
    const bounds = { width, height };

    const angle = Math.random() * Math.PI * 2;
    const dist = Math.min(width, height) * 0.28;
    const margin = 60;
    const x = Math.max(margin, Math.min(width - margin, width / 2 + Math.cos(angle) * dist));
    const y = Math.max(margin, Math.min(height - margin, height / 2 + Math.sin(angle) * dist));

    this.weapons.spawnOrb(bounds, startingWeapon, x, y);
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
          this.particles.emitExplosion(e.x, e.y, '#3DDC97', 20);
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
          // Crash! Costs a life — ends the run only once lives run out.
          this.loseLife();
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

  // Wave 2 lives system: called from both the direct-touch collision path and
  // the Gauntlet wall-crush callback so neither can bypass lives. Decrements
  // lives; while lives remain, grants a temporary shield and keeps the run
  // going (combo/multiplier are intentionally NOT reset — see report). Only
  // ends the run via triggerPlayerDeath() once lives reach zero.
  private loseLife() {
    if (this.player.isDead) return;
    // The Gauntlet crush callback fires every frame the player is pinned, and has no
    // shield check of its own. Without this guard a single crush drains every life in
    // consecutive frames. The post-hit shield doubles as the invulnerability window.
    if (this.player.hasShield()) return;

    this.lives--;

    if (this.lives > 0) {
      this.player.activateShield(3.0);
      this.audio.playSiren();
      this.particles.emitExplosion(this.player.x, this.player.y, '#5B8CFF', 30);
      this.grid.applyExplosion(this.player.x, this.player.y, 14, 220);
      this.renderer.triggerShake(14 * this.options.getShakeMultiplier());
      this.updateHUD();
    } else {
      this.triggerPlayerDeath();
    }
  }

  private triggerPlayerDeath() {
    this.player.isDead = true;
    this.phase = 'game-over';
    document.body.classList.remove('tilt-playing');
    this.audio.playPlayerDeath();
    this.audio.stopMusic();

    this.particles.emitExplosion(this.player.x, this.player.y, '#ffffff', 50);
    this.particles.emitExplosion(this.player.x, this.player.y, '#5B8CFF', 30);
    this.grid.applyExplosion(this.player.x, this.player.y, 22, 380);
    this.renderer.triggerShake(24 * this.options.getShakeMultiplier());

    this.scores.finalizeGame();

    // Finalize run goals check (capped at 3 run milestones, plus any cumulative total milestones)
    const newlyCompleted = this.goals.evaluateRun(this.runTracker);

    // Show Game Over Modal (strictly milestone-based points economy!)
    window.setTimeout(() => {
      const timeStr = this.formatTime(this.scores.stats.survivalTime);
      const mode = this.options.settings.mode;
      const cfg = this.options.getModeConfig(mode);

      this.finalScoreEl.textContent = this.scores.stats.score.toLocaleString();
      this.finalSubtitleEl.textContent = `Swarmed at ${timeStr} — ${cfg.name}, ${cfg.scoreMultiplier.toFixed(1)}×`;

      if (this.scores.isNewBest && this.scores.bestScoreDiff > 0) {
        this.newBestDiffEl.textContent = `New best — up ${this.scores.bestScoreDiff.toLocaleString()}`;
        this.newBestBannerEl.classList.remove('hidden');
      } else {
        this.newBestBannerEl.classList.add('hidden');
      }

      this.finalKillsEl.textContent = this.scores.stats.kills.toString();
      this.finalChainEl.textContent = `${Math.max(1, this.scores.stats.maxMultiplier)}×`;
      this.finalMultEl.textContent = `${Math.max(1, this.scores.stats.maxMultiplier)}×`;
      this.finalTimeEl.textContent = timeStr;
      this.finalCoinsEl.textContent = this.coins.coinsCollected.toString();

      let earnedMilestonesPts = 0;
      for (const g of newlyCompleted) {
        earnedMilestonesPts += g.rewardPoints;
      }
      // Coin pickups are a second, independent points income stream (on top
      // of milestone rewards) - fold their raw (pre points-multiplier) value
      // into the same single "Points earned" total. There is only ever one
      // currency here (Points, unit pts); coins are just another way to earn it.
      const totalEarned = Math.max(this.pointsEarnedThisRun, earnedMilestonesPts) + this.coins.pointsFromCoins;
      const balance = this.progression.data.points;

      this.pointsEarnedRowEl.innerHTML = `+${totalEarned.toLocaleString()} <span class="points-arrow">→</span> ${balance.toLocaleString()}`;
      this.spendBtnEl.textContent = `Spend ${balance.toLocaleString()}`;

      if (this.coins.coinsCollected > 0) {
        const coinPts = this.coins.pointsFromCoins;
        this.coinsDetailEl.textContent = `${this.coins.coinsCollected} · +${coinPts.toLocaleString()} ${coinPts === 1 ? 'pt' : 'pts'}`;
        this.coinsRowEl.classList.remove('hidden');
      } else {
        this.coinsRowEl.classList.add('hidden');
      }

      if (newlyCompleted.length > 0) {
        this.milestonesListEl.innerHTML = newlyCompleted.map(g => `
          <div class="gameover-milestone-item">
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none" aria-hidden="true"><path d="M2 7 L5 10 L11 3.5" stroke="#3DDC97" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"></path></svg>
            <span class="milestone-title">${g.title} — ${g.description}</span>
            <span class="milestone-pts">+${g.rewardPoints}</span>
          </div>
        `).join('');
        this.milestonesListEl.classList.remove('hidden');
      } else {
        this.milestonesListEl.innerHTML = '';
        this.milestonesListEl.classList.add('hidden');
      }

      this.goalsHUD.render();
      this.menu.render();

      this.gameOverModal.classList.remove('hidden');
      this.retryBtnEl.focus();
    }, 450);
  }

  private updateHUD() {
    this.scoreEl.textContent = this.scores.stats.score.toLocaleString();
    this.bestScoreEl.textContent = `BEST ${this.scores.stats.bestScore.toLocaleString()}`;

    if (this.modeBadgeEl) {
      const mode = this.options.settings.mode;
      const cfg = this.options.getModeConfig(mode);
      this.modeBadgeEl.textContent = cfg.name;
    }

    // Multiplier Chain Pill (Board 05: '7× chain' in ion blue tint)
    const multiplier = Math.max(1, this.scores.comboCount, this.scores.stats.multiplier);
    this.chainCountEl.textContent = `${multiplier}×`;
    if (multiplier > 1 || this.scores.comboCount > 0) {
      this.chainPillEl.classList.remove('hidden');
    } else {
      this.chainPillEl.classList.add('hidden');
    }

    // Lives Pips (Wave 2): hidden entirely for a default 1-life run so it
    // doesn't clutter the HUD; otherwise shows one pip per starting life,
    // filled for lives remaining.
    if (this.maxLivesThisRun > 1) {
      let pipsHtml = '';
      for (let i = 0; i < this.maxLivesThisRun; i++) {
        pipsHtml += `<span class="hud-life-pip${i < this.lives ? ' is-filled' : ''}"></span>`;
      }
      this.livesEl.innerHTML = pipsHtml;
      this.livesEl.classList.remove('hidden');
    } else {
      this.livesEl.classList.add('hidden');
    }

    // Active shield or weapon duration progress bar (Board 05: Shield 1.6s with thin progress bar)
    if (this.player.hasShield()) {
      const remaining = Math.max(0, this.player.shieldTimer);
      const total = 6.0;
      const pct = Math.min(100, Math.max(0, (remaining / total) * 100));
      this.durationLabelEl.textContent = `Shield ${remaining.toFixed(1)}s`;
      this.durationFillEl.style.width = `${pct}%`;
      this.durationIndicatorEl.classList.remove('hidden');
    } else if (this.weapons.activeWeapons.length > 0) {
      let activeW: any = null;
      for (const w of this.weapons.activeWeapons) {
        if (w.duration > 0 && (!activeW || w.duration > activeW.duration)) {
          activeW = w;
        }
      }
      if (activeW && activeW.maxDuration > 0) {
        const remaining = Math.max(0, activeW.duration);
        const pct = Math.min(100, Math.max(0, (remaining / activeW.maxDuration) * 100));
        const name = activeW.type.charAt(0).toUpperCase() + activeW.type.slice(1);
        this.durationLabelEl.textContent = `${name} ${remaining.toFixed(1)}s`;
        this.durationFillEl.style.width = `${pct}%`;
        this.durationIndicatorEl.classList.remove('hidden');
      } else {
        this.durationIndicatorEl.classList.add('hidden');
      }
    } else {
      this.durationIndicatorEl.classList.add('hidden');
    }

    // Left Edge Rail updating smoothly
    const completed = this.goals.getCompletedCount();
    const total = this.goals.getTotalGoalsCount();
    const milestonePct = total > 0 ? (completed / total) * 100 : 0;
    const survivalPct = Math.min(100, (this.elapsed / 90) * 100);
    const targetRail = Math.max(milestonePct, survivalPct * 0.4);
    this.railProgress += (targetRail - this.railProgress) * 0.1;
    if (this.leftRailFillEl) {
      this.leftRailFillEl.style.height = `${this.railProgress.toFixed(1)}%`;
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
      // Dynamic autonomous simulation behind start menu
      this.renderer.renderMenuBackground(
        this.ctx,
        width,
        height,
        this.menuPlayer,
        this.menuSwarm,
        this.menuWeapons,
        this.grid,
        this.particles,
        this.elapsed,
        undefined,
        undefined,
        undefined,
        this.options.settings.showGridlines,
        this.options.settings.highContrastHalo
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

    // Coin pickups render above the grid/renderer output but below the DOM
    // HUD overlay (HUD is a separate, independently z-indexed DOM layer).
    if (this.phase === 'playing' || this.phase === 'paused') {
      this.coins.render(this.ctx, this.elapsed);
    }

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
    if (this.phase === 'playing') {
      this.canvas.style.cursor = 'none';
    } else if (this.phase === 'menu') {
      this.canvas.style.cursor = 'default';
    } else {
      const skin = this.progression.getEquippedCursor();
      const uri = this.progression.getCursorSvgDataUri(skin.id);
      const cursorVal = `url("${uri}") 16 16, crosshair`;
      this.canvas.style.cursor = cursorVal;
      document.documentElement.style.setProperty('--custom-cursor', cursorVal);
      return;
    }
    document.documentElement.style.setProperty('--custom-cursor', 'default');
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
