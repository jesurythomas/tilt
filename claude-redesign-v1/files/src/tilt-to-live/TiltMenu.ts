// =========================================================================
// TiltMenu.ts - Interactive Homepage & Start Menu Controller
// =========================================================================

import { GameMode, GameOptionsManager, GameSettings } from './GameOptions';
import { ProgressionManager } from './ProgressionManager';
import { GoalManager } from './GoalManager';
import { ScoreManager } from './ScoreManager';

const ICON_CLOSE = `<svg class="tilt-icon" width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" aria-hidden="true"><path d="M4 4l8 8M12 4l-8 8"/></svg>`;

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

  /** `1` -> `1.0x`, `1.25` -> `1.25x`, `1.5` -> `1.5x`. Never truncates a real value. */
  private formatMultiplier(value: number): string {
    const fixed = value.toFixed(2);
    return `${fixed.endsWith('0') ? fixed.slice(0, -1) : fixed}x`;
  }

  public render() {
    if (!this.menuContainerEl) return;

    const currentMode = this.options.settings.mode;
    const completedGoals = this.goals.getCompletedCount();
    const totalGoals = this.goals.getTotalGoalsCount();
    const bestScore = this.scores.stats.bestScore;
    const points = this.progression.data.points;

    // First run: nothing survived and nothing earned yet.
    const isFirstRun = bestScore === 0 && completedGoals === 0;

    const modeRows = this.options.modes
      .map((m) => {
        const isSelected = m.id === currentMode;
        return `
          <button type="button" role="radio" aria-checked="${isSelected}"
                  class="menu-mode-row mode-${m.id}${isSelected ? ' is-selected' : ''}"
                  data-mode="${m.id}">
            <span class="mode-rail" aria-hidden="true"></span>
            <span class="mode-row-body">
              <span class="mode-row-head">
                <span class="mode-row-name">${m.name}</span>
                <span class="mode-row-mult">${this.formatMultiplier(m.scoreMultiplier)}</span>
              </span>
              <span class="mode-row-line">${m.tagline}</span>
            </span>
            <span class="mode-row-dot" aria-hidden="true"></span>
          </button>
        `;
      })
      .join('');

    const statRow = isFirstRun
      ? `<p class="menu-first-run">First milestone at 1,000 points</p>`
      : `
        <div class="menu-stat-row">
          <div class="menu-stat">
            <span class="menu-stat-value">${bestScore.toLocaleString()}</span>
            <span class="menu-stat-label">BEST</span>
          </div>
          <button type="button" id="menu-btn-armory-quick" class="menu-stat menu-stat-action" aria-label="Open the Armory">
            <span class="menu-stat-value menu-stat-points">${points.toLocaleString()}</span>
            <span class="menu-stat-label">POINTS</span>
          </button>
          <div class="menu-stat">
            <span class="menu-stat-value">${completedGoals}/${totalGoals}</span>
            <span class="menu-stat-label">MILESTONES</span>
          </div>
        </div>
      `;

    this.menuContainerEl.innerHTML = `
      <div class="tilt-menu-content">
        <div class="menu-panel">
          <div class="menu-hero">
            <h1 class="menu-title">
              <span class="menu-title-line">TILT TO</span>
              <span class="menu-title-line">LIVE</span>
            </h1>
            <p class="menu-subtitle">Move to dodge. The guns fire themselves.</p>
          </div>

          <div class="menu-modes" role="radiogroup" aria-label="Game mode">
            ${modeRows}
          </div>

          <button id="btn-menu-launch" type="button" class="btn-primary menu-play-btn">Play</button>

          <nav class="menu-links" aria-label="Menu">
            <button id="btn-menu-armory" type="button" class="btn-ghost menu-link">Armory</button>
            <button id="btn-menu-goals" type="button" class="btn-ghost menu-link">Milestones</button>
            <button id="btn-menu-options" type="button" class="btn-ghost menu-link">Settings</button>
          </nav>

          ${statRow}
        </div>
      </div>
    `;

    this.bindEvents();
  }

  private bindEvents() {
    if (!this.menuContainerEl) return;

    // Mode row selection
    this.menuContainerEl.querySelectorAll('.menu-mode-row').forEach((row) => {
      row.addEventListener('click', (e) => {
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

    // Quick Armory shortcut (the POINTS stat; absent on a first run)
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

    // Goals / Milestones Modal
    this.menuContainerEl.querySelector('#btn-menu-goals')?.addEventListener('click', () => {
      this.onOpenAllGoals();
    });
  }

  private switchMarkup(id: string, label: string, on: boolean): string {
    // Rendered childless on purpose: the knob is a ::after pseudo-element.
    return `<button id="${id}" type="button" class="opt-switch" role="switch" aria-checked="${on}" aria-label="${label}"></button>`;
  }

  private toggleRow(id: string, label: string, hint: string, on: boolean): string {
    return `
      <div class="options-row opt-row">
        <div class="opt-row-text">
          <span class="opt-row-label">${label}</span>
          ${hint ? `<span class="opt-row-hint">${hint}</span>` : ''}
        </div>
        ${this.switchMarkup(id, label, on)}
      </div>
    `;
  }

  public openOptionsModal() {
    if (!this.optionsModalEl) return;

    const s = this.options.settings;
    const tuning = this.progression.data.tuning;

    const schemes: Array<{ val: GameSettings['controlScheme']; title: string; sub: string }> = [
      { val: 'mouse', title: 'Mouse', sub: 'point to steer' },
      { val: 'keyboard', title: 'Keys', sub: 'WASD / arrows' },
      { val: 'hybrid', title: 'Both', sub: 'whichever moves' },
      { val: 'gyro', title: 'Tilt', sub: 'phone gyroscope' }
    ];

    const schemeButtons = schemes
      .map(
        (o) => `
          <button type="button" class="opt-btn opt-btn-stack ${s.controlScheme === o.val ? 'active' : ''}"
                  data-opt="controlScheme" data-val="${o.val}">
            <span class="opt-btn-title">${o.title}</span>
            <span class="opt-btn-sub">${o.sub}</span>
          </button>
        `
      )
      .join('');

    // `extreme` is no longer offered, but a stored `extreme` still reads as Full
    // so the group never renders with nothing selected. Picking Full normalises it.
    const shakeOptions: Array<{ val: 'off' | 'low' | 'normal'; title: string }> = [
      { val: 'off', title: 'Off' },
      { val: 'low', title: 'Low' },
      { val: 'normal', title: 'Full' }
    ];
    const shakeButtons = shakeOptions
      .map((o) => {
        const active = s.screenShake === o.val || (o.val === 'normal' && s.screenShake === 'extreme');
        return `<button type="button" class="opt-btn ${active ? 'active' : ''}" data-opt="screenShake" data-val="${o.val}">${o.title}</button>`;
      })
      .join('');

    this.optionsModalEl.innerHTML = `
      <div class="overlay-panel tilt-options-panel" role="dialog" aria-modal="true" aria-label="Settings">
        <div class="armory-header">
          <div class="armory-title-group">
            <h2>Settings</h2>
          </div>
          <div class="armory-header-right">
            <button id="btn-close-options" class="armory-close-btn" type="button" aria-label="Close settings">${ICON_CLOSE}</button>
          </div>
        </div>

        <div class="options-body custom-scrollbar">
          <div class="options-section">
            <span class="options-section-label">Readability</span>
            ${this.toggleRow('opt-toggle-halo', 'Enemy outlines', 'Adds a white ring to every hostile dot.', s.highContrastHalo)}
            ${this.toggleRow('opt-toggle-tether', 'Aim line', 'Draws the line from ship to cursor.', s.tetherLine)}
            ${this.toggleRow('opt-toggle-grid', 'Background grid', 'Off by default — it competes with the dots.', s.showGridlines)}
            <div class="options-row opt-row opt-row-stack">
              <div class="opt-row-text">
                <span class="opt-row-label">Screen shake</span>
              </div>
              <div class="options-button-group">${shakeButtons}</div>
            </div>
          </div>

          <div class="options-section">
            <span class="options-section-label">Controls</span>
            <div class="options-row opt-row opt-row-stack">
              <div class="options-button-group opt-scheme-group">${schemeButtons}</div>
            </div>
            <div class="options-row opt-row opt-row-stack">
              <div class="opt-slider-head">
                <div class="opt-row-text">
                  <span class="opt-row-label">Turn rate</span>
                  <span class="opt-row-hint">Higher turns sharper.</span>
                </div>
                <span id="opt-val-sensitivity" class="tuning-value-pill">${tuning.sensitivity.toFixed(1)}x</span>
              </div>
              <div class="slider-wrapper">
                <span class="slider-boundary">0.5x</span>
                <input id="opt-slider-sensitivity" type="range" min="0.5" max="2.0" step="0.1" value="${tuning.sensitivity}" aria-label="Turn rate">
                <span class="slider-boundary">2.0x</span>
              </div>
            </div>
            ${
              s.controlScheme === 'gyro'
                ? `
            <div class="options-row opt-row">
              <div class="opt-row-text">
                <span class="opt-row-label">Neutral tilt</span>
                <span class="opt-row-hint">Hold the phone how you want to hold it, then tap.</span>
              </div>
              <button id="opt-btn-calibrate-gyro" class="btn-secondary opt-row-btn" type="button">Calibrate</button>
            </div>
            `
                : ''
            }
          </div>

          <div class="options-section">
            <span class="options-section-label">Audio</span>
            ${this.toggleRow('opt-toggle-sfx', 'Sound', '', s.sfxEnabled)}
            ${this.toggleRow('opt-toggle-music', 'Music', '', s.musicEnabled)}
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

    // Control scheme & screen shake button groups
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

    // Switches
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
      btn.textContent = 'Calibrating';
      if (this.onCalibrateGyro) {
        await this.onCalibrateGyro();
      }
      btn.disabled = false;
      btn.textContent = 'Calibrated';
      setTimeout(() => {
        if (btn) btn.textContent = 'Calibrate';
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
