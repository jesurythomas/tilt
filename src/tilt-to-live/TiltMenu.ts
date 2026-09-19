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

    // Resolve next milestone teaser
    const activeGoals = this.goals.getActiveGoals(1);
    let nextTeaser: { title: string; desc: string; pct: number } | null = null;
    if (activeGoals.length > 0) {
      const g = activeGoals[0].goal;
      let currentVal = 0;
      if (g.category === 'cumulative' || g.metric.startsWith('total_')) {
        currentVal = this.goals.getMetricValue(g.metric, {
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
        });
      } else if (g.metric === 'run_score') {
        currentVal = Math.min(g.target, bestScore);
      }
      const pct = Math.min(100, Math.max(0, Math.round((currentVal / g.target) * 100)));
      nextTeaser = {
        title: g.title,
        desc: g.description,
        pct
      };
    }

    this.menuContainerEl.innerHTML = `
      <div class="tilt-menu-wrapper">
        <!-- Ambient subtle arena backdrop glow & enemy dots (Board 04) -->
        <div class="tilt-menu-arena-backdrop" aria-hidden="true">
          <div class="menu-radial-bloom"></div>
          <!-- Hostile red dot fleet preview -->
          <div class="menu-threat-dot" style="left: 64%; top: 14%; width: 6px; height: 6px;"></div>
          <div class="menu-threat-dot" style="left: 74%; top: 22%; width: 6px; height: 6px;"></div>
          <div class="menu-threat-dot" style="left: 70%; top: 32%; width: 5px; height: 5px;"></div>
          <div class="menu-threat-dot" style="left: 85%; top: 28%; width: 6px; height: 6px;"></div>
          <div class="menu-threat-dot" style="left: 92%; top: 18%; width: 5px; height: 5px;"></div>
          <div class="menu-threat-dot" style="left: 94%; top: 37%; width: 6px; height: 6px;"></div>
          <div class="menu-threat-dot" style="left: 88%; top: 48%; width: 5px; height: 5px;"></div>
          <div class="menu-threat-dot" style="left: 96%; top: 58%; width: 6px; height: 6px;"></div>
          <div class="menu-threat-dot" style="left: 78%; top: 62%; width: 5px; height: 5px;"></div>
          <div class="menu-threat-dot" style="left: 90%; top: 71%; width: 6px; height: 6px;"></div>

          <!-- Player Ship Vector -->
          <div class="menu-ship-vector-container" style="position: absolute; left: 82%; top: 43%; transform: translate(-50%, -50%);">
            <svg width="40" height="40" viewBox="0 0 36 36" fill="none" aria-hidden="true" style="filter: drop-shadow(0 0 16px rgba(91,140,255,0.9));">
              <path d="M30 18 L10 7 L14 18 L10 29 Z" fill="#5B8CFF"></path>
            </svg>
            <div style="position: absolute; right: 30px; top: 14px; width: 64px; height: 12px; background: linear-gradient(90deg, rgba(91,140,255,0), rgba(91,140,255,0.35)); border-radius: 6px;"></div>
          </div>
        </div>

        <!-- Left Menu Sidebar (Board 04) -->
        <div class="tilt-menu-sidebar">
          <!-- Hero Title & Subtitle (Cut 'HYPER-NEON BULLET DODGE ARENA') -->
          <div class="menu-hero-header">
            <h1 class="menu-hero-title">TILT<br>TO LIVE</h1>
            <p class="menu-hero-subtitle">Move to dodge. The guns fire themselves.</p>
          </div>

          <div class="menu-rule-divider"></div>

          <!-- Mode Cards (3 Cards: Standard, Gauntlet, Code Red) -->
          <div class="menu-modes-column" role="radiogroup" aria-label="Game Modes">
            ${this.options.modes.map((m) => {
              const isSelected = m.id === currentMode;
              const formattedMult = m.scoreMultiplier.toFixed(m.scoreMultiplier % 1 === 0 ? 1 : 2);
              return `
                <div class="menu-mode-card ${isSelected ? 'selected' : ''}" data-mode="${m.id}" role="radio" aria-checked="${isSelected}" tabindex="0" style="border-color: ${isSelected ? m.color : '#262C38'}; background: ${isSelected ? '#141821' : '#0F131B'};">
                  <div class="mode-left-indicator" style="background: ${m.color};"></div>
                  <div class="mode-info-block">
                    <div class="mode-header-line">
                      <strong class="mode-name" style="${isSelected ? 'color: #E6E9F0;' : 'color: #C7CDDB;'}">${m.name}</strong>
                      <span class="mode-mult-text" style="color: ${m.color};">${formattedMult}×</span>
                    </div>
                    <span class="mode-tagline-text" style="${isSelected ? 'color: #99A1B3;' : 'color: #7A8397;'}">${m.tagline}</span>
                  </div>
                  <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true" style="align-self: center; flex-shrink: 0;">
                    ${isSelected
                      ? `<circle cx="9" cy="9" r="8" stroke="${m.color}" stroke-width="1.5"></circle><circle cx="9" cy="9" r="4" fill="${m.color}"></circle>`
                      : `<circle cx="9" cy="9" r="8" stroke="#3A4252" stroke-width="1.5"></circle>`
                    }
                  </svg>
                </div>
              `;
            }).join('')}
          </div>

          <!-- Play Button & Clean Nav Links -->
          <div class="menu-launch-group">
            <button id="btn-menu-launch" type="button" class="menu-play-button" aria-label="Play game">
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true"><path d="M4 2.5 L13 8 L4 13.5 Z" fill="#08090E"></path></svg>
              Play
            </button>
            <div class="menu-nav-links-row">
              <button id="btn-menu-armory" type="button" class="menu-clean-nav-link">Armory</button>
              <button id="btn-menu-goals" type="button" class="menu-clean-nav-link">Milestones</button>
              <button id="btn-menu-options" type="button" class="menu-clean-nav-link">Settings</button>
            </div>
          </div>

          <!-- Stats Footer: If bestScore > 0, show Best, Points, Milestones. If 0 (first run), hide until first run ends -->
          ${bestScore > 0 ? `
          <div class="menu-stats-row">
            <div class="menu-stat-metric">
              <span class="stat-metric-label">Best</span>
              <span class="stat-metric-val">${bestScore.toLocaleString()}</span>
            </div>
            <div class="menu-stat-metric">
              <span class="stat-metric-label">Points</span>
              <span class="stat-metric-val stat-points-val">${points.toLocaleString()}</span>
            </div>
            <div class="menu-stat-metric">
              <span class="stat-metric-label">Milestones</span>
              <span class="stat-metric-val">${completedGoals}<span class="stat-denom">/${totalGoals}</span></span>
            </div>
          </div>
          ` : ''}
        </div>

        <!-- Next Milestone Teaser Banner (bottom right / mobile) -->
        ${nextTeaser ? `
        <div class="menu-next-milestone-teaser">
          <span class="teaser-next-tag">Next</span>
          <span class="teaser-desc">${nextTeaser.title} — ${nextTeaser.desc}</span>
          <span class="teaser-progress-track">
            <span class="teaser-progress-fill" style="width: ${nextTeaser.pct}%;"></span>
          </span>
        </div>
        ` : ''}
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
      card.addEventListener('keydown', (e) => {
        if ((e as KeyboardEvent).key === 'Enter' || (e as KeyboardEvent).key === ' ') {
          const mode = (e.currentTarget as HTMLElement).getAttribute('data-mode') as GameMode;
          if (mode) {
            this.options.setMode(mode);
            this.render();
          }
        }
      });
    });

    // Launch Game button
    this.menuContainerEl.querySelector('#btn-menu-launch')?.addEventListener('click', () => {
      this.hide();
      this.onLaunchGame(this.options.settings.mode);
    });

    // Clean Nav Links
    this.menuContainerEl.querySelector('#btn-menu-armory')?.addEventListener('click', () => {
      this.onOpenArmory();
    });

    this.menuContainerEl.querySelector('#btn-menu-goals')?.addEventListener('click', () => {
      this.onOpenAllGoals();
    });

    this.menuContainerEl.querySelector('#btn-menu-options')?.addEventListener('click', () => {
      this.openOptionsModal();
    });
  }

  public openOptionsModal() {
    if (!this.optionsModalEl) return;

    const s = this.options.settings;

    const renderToggleSwitch = (id: string, label: string, hint: string, checked: boolean) => {
      const ring = checked ? '#5B8CFF' : '#3A4252';
      const track = checked ? 'rgba(91, 140, 255, 0.2)' : '#1B2029';
      const knob = checked ? '#5B8CFF' : '#626B7E';
      const side = checked ? 'right: 3px;' : 'left: 3px;';
      return `
        <div class="settings-switch-row">
          <div class="switch-row-info">
            <span class="switch-row-label">${label}</span>
            <span class="switch-row-hint">${hint}</span>
          </div>
          <button id="${id}" type="button" role="switch" aria-checked="${checked ? 'true' : 'false'}" class="settings-switch-btn" style="border-color: ${ring}; background: ${track};">
            <span class="settings-switch-knob" style="${side} background: ${knob};"></span>
          </button>
        </div>
      `;
    };

    const isCurrentShake = (val: string) => {
      if (val === 'normal' || val === 'full') {
        return s.screenShake === 'normal' || s.screenShake === 'full';
      }
      return s.screenShake === val;
    };

    const schemes = [
      { id: 'mouse', name: 'Mouse', keys: 'point to steer' },
      { id: 'keyboard', name: 'Keys', keys: 'WASD / arrows' },
      { id: 'hybrid', name: 'Both', keys: 'whichever moves' },
      { id: 'gyro', name: 'Tilt', keys: 'phone gyroscope' }
    ];

    this.optionsModalEl.innerHTML = `
      <div class="overlay-panel tilt-options-panel" role="dialog" aria-modal="true" aria-label="Settings">
        <!-- Settings Header (Board 12) -->
        <div class="settings-modal-header">
          <h2 class="settings-modal-title">Settings</h2>
          <button id="btn-close-options" type="button" class="settings-modal-close" aria-label="Close settings">
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
              <path d="M2 2 L12 12 M12 2 L2 12" stroke="#99A1B3" stroke-width="1.5" stroke-linecap="round"></path>
            </svg>
          </button>
        </div>

        <!-- Settings Body Grid (Readability first, Audio, Controls, Data) -->
        <div class="settings-modal-body custom-scrollbar">
          <!-- Left Column: Readability & Audio -->
          <div class="settings-col">
            <!-- Readability Section (Decides whether game is playable. Changed most, sits first) -->
            <div class="settings-section">
              <span class="settings-section-heading">Readability</span>
              <p class="settings-section-caption">Decides whether the game is playable. Changed most, so it sits first.</p>

              <div class="settings-section-items">
                ${renderToggleSwitch(
                  's-halo',
                  'Enemy outlines',
                  'Adds a white ring to every hostile dot.',
                  s.highContrastHalo
                )}

                ${renderToggleSwitch(
                  's-aim',
                  'Aim line',
                  'Draws the line from ship to cursor.',
                  s.tetherLine
                )}

                ${renderToggleSwitch(
                  's-grid',
                  'Background grid',
                  'Off by default — it competes with the dots.',
                  s.showGridlines
                )}

                <!-- Screen Shake Row -->
                <div class="settings-switch-row">
                  <div class="switch-row-info">
                    <span class="switch-row-label">Screen shake</span>
                  </div>
                  <div class="settings-segmented-group">
                    <button type="button" class="settings-segment-btn ${isCurrentShake('off') ? 'active' : ''}" data-shake="off">Off</button>
                    <button type="button" class="settings-segment-btn ${isCurrentShake('low') ? 'active' : ''}" data-shake="low">Low</button>
                    <button type="button" class="settings-segment-btn ${isCurrentShake('full') ? 'active' : ''}" data-shake="full">Full</button>
                  </div>
                </div>
              </div>
            </div>

            <!-- Audio Section -->
            <div class="settings-section">
              <span class="settings-section-heading">Audio</span>
              <div class="settings-section-items">
                ${renderToggleSwitch('s-sfx', 'Sound', 'Audio effects, weapons, and impacts.', s.sfxEnabled)}
                ${renderToggleSwitch('s-mus', 'Music', 'High-tempo synthwave electronic soundtrack.', s.musicEnabled)}
              </div>
            </div>
          </div>

          <!-- Right Column: Controls & Data -->
          <div class="settings-col">
            <!-- Controls Section -->
            <div class="settings-section">
              <span class="settings-section-heading">Controls</span>
              <div class="settings-schemes-grid">
                ${schemes.map((c) => {
                  const isActive = s.controlScheme === c.id;
                  return `
                    <button type="button" class="settings-scheme-card ${isActive ? 'active' : ''}" data-scheme="${c.id}">
                      <span class="scheme-name" style="color: ${isActive ? '#E6E9F0' : '#C7CDDB'};">${c.name}</span>
                      <span class="scheme-keys">${c.keys}</span>
                    </button>
                  `;
                }).join('')}
              </div>

              ${s.controlScheme === 'gyro' ? `
              <div class="settings-gyro-calibrate-row">
                <div>
                  <strong style="color: #5B8CFF; display: block; font-size: 13px;">Neutral Tilt Calibration</strong>
                  <small style="color: #99A1B3; font-size: 11px;">Rest device at comfortable angle, then calibrate.</small>
                </div>
                <button id="opt-btn-calibrate-gyro" type="button" class="settings-calibrate-btn">
                  Calibrate Neutral Tilt
                </button>
              </div>
              ` : ''}

              <button id="btn-settings-armory-link" type="button" class="settings-sub-link">
                Turn rate and deadzone live in the Armory
              </button>
            </div>

            <!-- Data Section -->
            <div class="settings-section">
              <span class="settings-section-heading">Data</span>
              <div class="settings-reset-row">
                <div class="switch-row-info">
                  <span class="switch-row-label">Reset progress</span>
                  <span class="switch-row-hint">Scores, points and unlocks. Cannot be undone.</span>
                </div>
                <button id="btn-settings-reset-data" type="button" class="settings-reset-btn">Reset</button>
              </div>
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

    // Close settings modal
    this.optionsModalEl.querySelector('#btn-close-options')?.addEventListener('click', () => {
      this.optionsModalEl?.classList.add('hidden');
    });

    // Readability switch toggles
    this.optionsModalEl.querySelector('#s-halo')?.addEventListener('click', () => {
      this.options.settings.highContrastHalo = !this.options.settings.highContrastHalo;
      this.options.save();
      this.openOptionsModal();
    });

    this.optionsModalEl.querySelector('#s-aim')?.addEventListener('click', () => {
      this.options.settings.tetherLine = !this.options.settings.tetherLine;
      this.options.save();
      this.openOptionsModal();
    });

    this.optionsModalEl.querySelector('#s-grid')?.addEventListener('click', () => {
      this.options.settings.showGridlines = !this.options.settings.showGridlines;
      this.options.save();
      this.openOptionsModal();
    });

    // Screen Shake segmented buttons
    this.optionsModalEl.querySelectorAll('.settings-segment-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const shake = (e.currentTarget as HTMLElement).getAttribute('data-shake');
        if (shake) {
          this.options.settings.screenShake = shake as any;
          this.options.save();
          this.openOptionsModal();
        }
      });
    });

    // Audio toggles
    this.optionsModalEl.querySelector('#s-sfx')?.addEventListener('click', () => {
      this.options.settings.sfxEnabled = !this.options.settings.sfxEnabled;
      this.options.save();
      this.openOptionsModal();
    });

    this.optionsModalEl.querySelector('#s-mus')?.addEventListener('click', () => {
      this.options.settings.musicEnabled = !this.options.settings.musicEnabled;
      this.options.save();
      this.openOptionsModal();
    });

    // Controls scheme cards
    this.optionsModalEl.querySelectorAll('.settings-scheme-card').forEach((card) => {
      card.addEventListener('click', (e) => {
        const scheme = (e.currentTarget as HTMLElement).getAttribute('data-scheme');
        if (scheme) {
          this.options.settings.controlScheme = scheme as any;
          this.options.save();
          this.openOptionsModal();
        }
      });
    });

    // Gyro neutral tilt calibration
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
        if (btn) btn.innerText = 'Calibrate Neutral Tilt';
      }, 1600);
    });

    // Armory sub-link
    this.optionsModalEl.querySelector('#btn-settings-armory-link')?.addEventListener('click', () => {
      this.optionsModalEl?.classList.add('hidden');
      this.onOpenArmory();
    });

    // Reset Data
    this.optionsModalEl.querySelector('#btn-settings-reset-data')?.addEventListener('click', () => {
      const confirmed = window.confirm(
        'Are you sure you want to reset all progress? Your scores, points, milestones, and armory unlocks will be permanently deleted.'
      );
      if (confirmed) {
        try {
          localStorage.removeItem('tilt_to_live_settings_v1');
          localStorage.removeItem('tilt_to_live_completed_goals_v1');
          localStorage.removeItem('tilt_to_live_cumulative_stats_v1');
          localStorage.removeItem('tilt_to_live_progression_v1');
          localStorage.removeItem('tilt_to_live_scores_v1');
          localStorage.removeItem('tilt_goals_hud_collapsed');
        } catch {}
        window.location.reload();
      }
    });
  }
}
