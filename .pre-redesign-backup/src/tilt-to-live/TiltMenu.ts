// =========================================================================
// TiltMenu.ts - Interactive Homepage & Start Menu Controller
// =========================================================================

import { GameMode, GameOptionsManager } from './GameOptions';
import { ProgressionManager } from './ProgressionManager';
import { GoalManager } from './GoalManager';
import { ScoreManager } from './ScoreManager';

export class TiltMenu {
  private readonly options: GameOptionsManager;
  private readonly progression: ProgressionManager;
  private readonly goals: GoalManager;
  private readonly scores: ScoreManager;
  private readonly onLaunchGame: (mode: GameMode) => void;
  private readonly onOpenArmory: () => void;
  private readonly onOpenAllGoals: () => void;
  private readonly onCalibrateGyro?: () => Promise<boolean> | void;

  private menuContainerEl: HTMLElement | null = null;
  private optionsModalEl: HTMLElement | null = null;

  constructor(
    options: GameOptionsManager,
    progression: ProgressionManager,
    goals: GoalManager,
    scores: ScoreManager,
    onLaunchGame: (mode: GameMode) => void,
    onOpenArmory: () => void,
    onOpenAllGoals: () => void,
    onCalibrateGyro?: () => Promise<boolean> | void
  ) {
    this.options = options;
    this.progression = progression;
    this.goals = goals;
    this.scores = scores;
    this.onLaunchGame = onLaunchGame;
    this.onOpenArmory = onOpenArmory;
    this.onOpenAllGoals = onOpenAllGoals;
    this.onCalibrateGyro = onCalibrateGyro;

    this.initDOM();
  }

  private initDOM() {
    let menu = document.getElementById('tilt-menu-screen');
    if (!menu) {
      menu = document.createElement('div');
      menu.id = 'tilt-menu-screen';
      menu.className = 'tilt-menu-screen';
      const stage = document.getElementById('tilt-stage') || document.body;
      stage.appendChild(menu);
    }
    this.menuContainerEl = menu;

    let optsModal = document.getElementById('tilt-options-modal');
    if (!optsModal) {
      optsModal = document.createElement('div');
      optsModal.id = 'tilt-options-modal';
      optsModal.className = 'game-overlay hidden tilt-options-overlay';
      const stage = document.getElementById('tilt-stage') || document.body;
      stage.appendChild(optsModal);
    }
    this.optionsModalEl = optsModal;

    this.render();
  }

  public show() {
    if (!this.menuContainerEl) this.initDOM();
    if (this.menuContainerEl) {
      this.menuContainerEl.classList.remove('hidden');
      this.render();
    }
  }

  public hide() {
    if (this.menuContainerEl) {
      this.menuContainerEl.classList.add('hidden');
    }
  }

  public isVisible(): boolean {
    return !!this.menuContainerEl && !this.menuContainerEl.classList.contains('hidden');
  }

  public render() {
    if (!this.menuContainerEl) return;

    const currentMode = this.options.settings.mode;
    const completedGoals = this.goals.getCompletedCount();
    const totalGoals = this.goals.getTotalGoalsCount();
    const bestScore = this.scores.stats.bestScore;
    const points = this.progression.data.points;

    this.menuContainerEl.innerHTML = `
      <div class="tilt-menu-content">
        <!-- Top Stats Pill Bar -->
        <header class="menu-top-bar">
          <div class="menu-stat-chip">
            <span class="stat-glyph">🏆</span>
            <small>BEST SCORE</small>
            <strong>${bestScore.toLocaleString()}</strong>
          </div>
          <div class="menu-stat-chip">
            <span class="stat-glyph">★</span>
            <small>MILESTONES</small>
            <strong>${completedGoals}/${totalGoals}</strong>
          </div>
          <div class="menu-stat-chip menu-vault-chip" id="menu-btn-armory-quick">
            <span class="stat-glyph">◈</span>
            <small>VAULT</small>
            <strong>${points.toLocaleString()} PTS</strong>
          </div>
        </header>

        <!-- Main Title & Branding -->
        <div class="menu-hero">
          <p class="menu-eyebrow">HYPER-NEON BULLET DODGE ARENA</p>
          <h1 class="menu-title">TILT TO LIVE</h1>
          <p class="menu-subtitle">Weapons are your only salvation. Steer with WASD or mouse to survive relentless red dot swarms.</p>
        </div>

        <!-- Mode Selector Cards -->
        <section class="menu-modes-section" aria-label="Game Modes">
          <p class="section-label">SELECT GAME MODE</p>
          <div class="menu-modes-grid">
            ${this.options.modes.map((m) => {
              const isSelected = m.id === currentMode;
              return `
                <div class="menu-mode-card ${isSelected ? 'selected' : ''}" data-mode="${m.id}" role="button" tabindex="0">
                  <div class="mode-card-header">
                    <span class="mode-badge" style="border-color: ${m.color}; color: ${m.color}; background: ${m.glow};">
                      ${m.badge}
                    </span>
                    <span class="mode-mult">${m.scoreMultiplier}x SCORE</span>
                  </div>
                  <h3>${m.name}</h3>
                  <p class="mode-tagline">${m.tagline}</p>
                  <p class="mode-desc">${m.description}</p>
                  <div class="mode-select-indicator">
                    <span>${isSelected ? '● ACTIVE MODE' : 'SELECT MODE'}</span>
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        </section>

        <!-- Action Button Controls -->
        <div class="menu-actions-row">
          <button id="btn-menu-launch" type="button" class="menu-launch-button" aria-label="Launch selected game mode">
            <span class="launch-icon">▶</span>
            <div class="launch-text">
              <small>ENTER THE ARENA</small>
              <strong>LAUNCH ${this.options.getModeConfig().name.toUpperCase()}</strong>
            </div>
          </button>

          <div class="menu-sub-buttons">
            <button id="btn-menu-armory" type="button" class="menu-sub-btn">
              <span>⚡</span> The Armory & Vault
            </button>
            <button id="btn-menu-options" type="button" class="menu-sub-btn">
              <span>⚙️</span> Game Options
            </button>
            <button id="btn-menu-goals" type="button" class="menu-sub-btn">
              <span>🏆</span> Milestone Trophies
            </button>
          </div>
        </div>
      </div>
    `;

    this.bindEvents();
  }

  private bindEvents() {
    if (!this.menuContainerEl) return;

    // Mode card clicks
    this.menuContainerEl.querySelectorAll('.menu-mode-card').forEach((card) => {
      card.addEventListener('click', (e) => {
        const mode = (e.currentTarget as HTMLElement).getAttribute('data-mode') as GameMode;
        if (mode) {
          this.options.setMode(mode);
          this.render();
        }
      });
    });

    // Launch Game button
    this.menuContainerEl.querySelector('#btn-menu-launch')?.addEventListener('click', () => {
      this.hide();
      this.onLaunchGame(this.options.settings.mode);
    });

    // Quick Armory shortcut
    this.menuContainerEl.querySelector('#menu-btn-armory-quick')?.addEventListener('click', () => {
      this.onOpenArmory();
    });

    this.menuContainerEl.querySelector('#btn-menu-armory')?.addEventListener('click', () => {
      this.onOpenArmory();
    });

    // Options Modal
    this.menuContainerEl.querySelector('#btn-menu-options')?.addEventListener('click', () => {
      this.openOptionsModal();
    });

    // Goals / Trophies Modal
    this.menuContainerEl.querySelector('#btn-menu-goals')?.addEventListener('click', () => {
      this.onOpenAllGoals();
    });
  }

  public openOptionsModal() {
    if (!this.optionsModalEl) return;

    const s = this.options.settings;
    const tuning = this.progression.data.tuning;

    this.optionsModalEl.innerHTML = `
      <div class="overlay-panel tilt-options-panel" role="dialog" aria-modal="true" aria-label="Game Settings">
        <div class="armory-header">
          <div class="armory-title-group">
            <p class="eyebrow">CONFIGURATION</p>
            <h2>Game Options & Settings</h2>
          </div>
          <div class="armory-header-right">
            <button id="btn-close-options" class="armory-close-btn" type="button" aria-label="Close Options">✕</button>
          </div>
        </div>

        <div class="options-body custom-scrollbar">
          <!-- Controls Section -->
          <div class="options-section">
            <span class="options-section-label">STEERING CONTROLS</span>
            <div class="options-row">
              <label>Control Scheme</label>
              <div class="options-button-group">
                <button class="opt-btn ${s.controlScheme === 'hybrid' ? 'active' : ''}" data-opt="controlScheme" data-val="hybrid" type="button">
                  WASD / Arrows + Mouse
                </button>
                <button class="opt-btn ${s.controlScheme === 'mouse' ? 'active' : ''}" data-opt="controlScheme" data-val="mouse" type="button">
                  Mouse Only
                </button>
                <button class="opt-btn ${s.controlScheme === 'keyboard' ? 'active' : ''}" data-opt="controlScheme" data-val="keyboard" type="button">
                  Keyboard (WASD / Arrows)
                </button>
                <button class="opt-btn ${s.controlScheme === 'gyro' ? 'active' : ''}" data-opt="controlScheme" data-val="gyro" type="button">
                  📱 Gyro / Tilt
                </button>
              </div>
            </div>
            <div class="options-row" style="flex-direction: column; align-items: stretch; gap: 8px;">
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <label style="font-size: 11.5px; font-weight: 700; text-transform: uppercase;">Steering Sensitivity</label>
                <span id="opt-val-sensitivity" class="tuning-value-pill">${tuning.sensitivity.toFixed(1)}x</span>
              </div>
              <div class="slider-wrapper">
                <span class="slider-boundary">0.5x</span>
                <input id="opt-slider-sensitivity" type="range" min="0.5" max="2.0" step="0.1" value="${tuning.sensitivity}">
                <span class="slider-boundary">2.0x</span>
              </div>
            </div>
            ${s.controlScheme === 'gyro' ? `
            <div class="options-row" style="background: rgba(0, 221, 255, 0.08); border-color: rgba(0, 221, 255, 0.3);">
              <div>
                <strong style="color: var(--neon-cyan); display: block; font-size: 13px;">Neutral Tilt Calibration</strong>
                <small style="color: var(--paper); opacity: 0.85; font-size: 11px;">Hold device at your comfortable resting angle, then tap Calibrate.</small>
              </div>
              <button id="opt-btn-calibrate-gyro" class="command-button" type="button" style="width: auto; padding: 10px 18px; font-size: 11.5px; white-space: nowrap;">
                🎯 Calibrate Neutral Tilt
              </button>
            </div>
            ` : ''}
          </div>

          <!-- Audio Section -->
          <div class="options-section">
            <span class="options-section-label">AUDIO & SOUNDTRACK</span>
            <div class="options-row">
              <label>Sound Effects</label>
              <button id="opt-toggle-sfx" class="opt-toggle-btn ${s.sfxEnabled ? 'active' : ''}" type="button">
                ${s.sfxEnabled ? 'ENABLED' : 'MUTED'}
              </button>
            </div>
            <div class="options-row">
              <label>Synthwave Music</label>
              <button id="opt-toggle-music" class="opt-toggle-btn ${s.musicEnabled ? 'active' : ''}" type="button">
                ${s.musicEnabled ? 'ENABLED' : 'MUTED'}
              </button>
            </div>
          </div>

          <!-- Visuals & Screen FX Section -->
          <div class="options-section">
            <span class="options-section-label">VISUALS & ACCESSIBILITY</span>
            <div class="options-row">
              <label>Screen Shake Impact</label>
              <div class="options-button-group">
                <button class="opt-btn ${s.screenShake === 'off' ? 'active' : ''}" data-opt="screenShake" data-val="off" type="button">Off</button>
                <button class="opt-btn ${s.screenShake === 'low' ? 'active' : ''}" data-opt="screenShake" data-val="low" type="button">Low</button>
                <button class="opt-btn ${s.screenShake === 'normal' ? 'active' : ''}" data-opt="screenShake" data-val="normal" type="button">Normal</button>
                <button class="opt-btn ${s.screenShake === 'extreme' ? 'active' : ''}" data-opt="screenShake" data-val="extreme" type="button">Extreme</button>
              </div>
            </div>
            <div class="options-row">
              <label>Targeting Tether Line</label>
              <button id="opt-toggle-tether" class="opt-toggle-btn ${s.tetherLine ? 'active' : ''}" type="button">
                ${s.tetherLine ? 'ENABLED' : 'DISABLED'}
              </button>
            </div>
            <div class="options-row">
              <label>High-Contrast Dot Halo</label>
              <button id="opt-toggle-halo" class="opt-toggle-btn ${s.highContrastHalo ? 'active' : ''}" type="button">
                ${s.highContrastHalo ? 'ENABLED' : 'DISABLED'}
              </button>
            </div>
            <div class="options-row">
              <label>Background Vector Grid</label>
              <button id="opt-toggle-grid" class="opt-toggle-btn ${s.showGridlines ? 'active' : ''}" type="button">
                ${s.showGridlines ? 'ENABLED' : 'DISABLED'}
              </button>
            </div>
          </div>
        </div>
      </div>
    `;

    this.optionsModalEl.classList.remove('hidden');
    this.bindOptionsEvents();
  }

  private bindOptionsEvents() {
    if (!this.optionsModalEl) return;

    this.optionsModalEl.querySelector('#btn-close-options')?.addEventListener('click', () => {
      this.optionsModalEl?.classList.add('hidden');
    });

    // Control scheme & Screen shake button groups
    this.optionsModalEl.querySelectorAll('.opt-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const target = e.currentTarget as HTMLElement;
        const opt = target.getAttribute('data-opt');
        const val = target.getAttribute('data-val');
        if (opt === 'controlScheme' && val) {
          this.options.settings.controlScheme = val as any;
          this.options.save();
          this.openOptionsModal();
        } else if (opt === 'screenShake' && val) {
          this.options.settings.screenShake = val as any;
          this.options.save();
          this.openOptionsModal();
        }
      });
    });

    // Toggle buttons
    this.optionsModalEl.querySelector('#opt-toggle-sfx')?.addEventListener('click', () => {
      this.options.settings.sfxEnabled = !this.options.settings.sfxEnabled;
      this.options.save();
      this.openOptionsModal();
    });

    this.optionsModalEl.querySelector('#opt-toggle-music')?.addEventListener('click', () => {
      this.options.settings.musicEnabled = !this.options.settings.musicEnabled;
      this.options.save();
      this.openOptionsModal();
    });

    this.optionsModalEl.querySelector('#opt-toggle-tether')?.addEventListener('click', () => {
      this.options.settings.tetherLine = !this.options.settings.tetherLine;
      this.options.save();
      this.openOptionsModal();
    });

    this.optionsModalEl.querySelector('#opt-toggle-halo')?.addEventListener('click', () => {
      this.options.settings.highContrastHalo = !this.options.settings.highContrastHalo;
      this.options.save();
      this.openOptionsModal();
    });

    this.optionsModalEl.querySelector('#opt-toggle-grid')?.addEventListener('click', () => {
      this.options.settings.showGridlines = !this.options.settings.showGridlines;
      this.options.save();
      this.openOptionsModal();
    });

    this.optionsModalEl.querySelector('#opt-btn-calibrate-gyro')?.addEventListener('click', async (e) => {
      const btn = e.currentTarget as HTMLButtonElement;
      btn.disabled = true;
      btn.innerText = 'Calibrating...';
      if (this.onCalibrateGyro) {
        await this.onCalibrateGyro();
      }
      btn.disabled = false;
      btn.innerText = 'Calibrated ✓';
      setTimeout(() => {
        if (btn) btn.innerText = '🎯 Calibrate Neutral Tilt';
      }, 1600);
    });

    const sensSlider = this.optionsModalEl.querySelector('#opt-slider-sensitivity') as HTMLInputElement | null;
    sensSlider?.addEventListener('input', () => {
      const val = parseFloat(sensSlider.value);
      this.progression.data.tuning.sensitivity = val;
      this.progression.save();
      const valEl = this.optionsModalEl?.querySelector('#opt-val-sensitivity');
      if (valEl) valEl.textContent = `${val.toFixed(1)}x`;
    });
  }
}
