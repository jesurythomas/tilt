// =========================================================================
// GoalsHUD.ts - Always-Visible Left-Side Milestones & Goal Tracker HUD
// =========================================================================

import { Goal, GoalManager, RunTracker } from './GoalManager';
import { ProgressionManager } from './ProgressionManager';

export class GoalsHUD {
  private readonly goalManager: GoalManager;
  private readonly progression: ProgressionManager;
  private containerEl: HTMLElement | null = null;
  private toastContainerEl: HTMLElement | null = null;
  private allGoalsModalEl: HTMLElement | null = null;

  public isCollapsed: boolean = false;
  private inMenuMode: boolean = false;
  private completedToastTimer: number | null = null;

  constructor(goalManager: GoalManager, progression: ProgressionManager) {
    this.goalManager = goalManager;
    this.progression = progression;

    this.loadCollapsedState();
    this.initDOM();
    this.setupListeners();
  }

  private loadCollapsedState() {
    try {
      const saved = localStorage.getItem('tilt_goals_hud_collapsed');
      if (saved !== null) {
        this.isCollapsed = saved === 'true';
      } else {
        this.isCollapsed = typeof window !== 'undefined' && window.innerWidth <= 900;
      }
    } catch {
      this.isCollapsed = typeof window !== 'undefined' && window.innerWidth <= 900;
    }
  }

  private saveCollapsedState() {
    try {
      localStorage.setItem('tilt_goals_hud_collapsed', this.isCollapsed ? 'true' : 'false');
    } catch {}
  }

  public toggleCollapse() {
    this.isCollapsed = !this.isCollapsed;
    this.saveCollapsedState();
    this.render();
  }

  public setMenuMode(inMenu: boolean) {
    this.inMenuMode = inMenu;
    if (this.containerEl) {
      if (inMenu && typeof window !== 'undefined' && window.innerWidth <= 900) {
        this.containerEl.classList.add('mobile-menu-hide');
      } else {
        this.containerEl.classList.remove('mobile-menu-hide');
      }
    }
  }

  private initDOM() {
    // 1. Left-Side Goals Sidebar Container
    let el = document.getElementById('tilt-goals-sidebar');
    if (!el) {
      el = document.createElement('aside');
      el.id = 'tilt-goals-sidebar';
      el.className = 'tilt-goals-sidebar';
      el.setAttribute('aria-label', 'Active Milestones');
      const stage = document.getElementById('tilt-stage') || document.body;
      stage.appendChild(el);
    }
    this.containerEl = el;

    // 2. Goal Complete Toast Banner Container
    let toast = document.getElementById('tilt-goal-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'tilt-goal-toast';
      toast.className = 'tilt-goal-toast hidden';
      toast.setAttribute('aria-live', 'polite');
      const stage = document.getElementById('tilt-stage') || document.body;
      stage.appendChild(toast);
    }
    this.toastContainerEl = toast;

    // 3. Full Trophies / Goals Modal
    let modal = document.getElementById('tilt-all-goals-modal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'tilt-all-goals-modal';
      modal.className = 'game-overlay hidden tilt-all-goals-overlay';
      const stage = document.getElementById('tilt-stage') || document.body;
      stage.appendChild(modal);
    }
    this.allGoalsModalEl = modal;

    this.render();
  }

  private setupListeners() {
    this.goalManager.setCallbacks(
      (goal) => this.handleGoalCompleted(goal),
      (pts) => {
        this.progression.addPoints(pts);
        this.render();
      }
    );
  }

  public showGoalToast(goal: Goal) {
    if (!this.toastContainerEl) return;
    this.toastContainerEl.innerHTML = `
      <div class="goal-toast-inner">
        <span class="toast-star">★</span>
        <div class="toast-text">
          <small>MILESTONE COMPLETE!</small>
          <strong>${goal.title}</strong>
        </div>
        <span class="toast-reward">+${goal.rewardPoints} ${goal.rewardPoints === 1 ? 'POINT' : 'POINTS'}</span>
      </div>
    `;
    this.toastContainerEl.classList.remove('hidden');

    if (this.completedToastTimer !== null) {
      window.clearTimeout(this.completedToastTimer);
    }
    this.completedToastTimer = window.setTimeout(() => {
      this.toastContainerEl?.classList.add('hidden');
      this.completedToastTimer = null;
    }, 3200);
  }

  public showMessageToast(title: string, subtitle: string, rewardBadge?: string) {
    if (!this.toastContainerEl) return;
    this.toastContainerEl.innerHTML = `
      <div class="goal-toast-inner">
        <span class="toast-star">🎯</span>
        <div class="toast-text">
          <small>${title}</small>
          <strong>${subtitle}</strong>
        </div>
        ${rewardBadge ? `<span class="toast-reward">${rewardBadge}</span>` : ''}
      </div>
    `;
    this.toastContainerEl.classList.remove('hidden');

    if (this.completedToastTimer !== null) {
      window.clearTimeout(this.completedToastTimer);
    }
    this.completedToastTimer = window.setTimeout(() => {
      this.toastContainerEl?.classList.add('hidden');
      this.completedToastTimer = null;
    }, 2800);
  }

  private handleGoalCompleted(goal: Goal) {
    this.showGoalToast(goal);
    this.render();
  }

  public updateLive(tracker: RunTracker) {
    if (!this.containerEl) return;

    // Evaluate live cumulative milestones (run goals only complete on game over)
    this.goalManager.evaluateLiveTotalGoals(tracker);

    if (this.isCollapsed) return;

    // Update active goals progress bars
    const active = this.goalManager.getActiveGoals(3);
    for (const { goal } of active) {
      const current = Math.min(goal.target, this.goalManager.getMetricValue(goal.metric, tracker));
      const pct = Math.min(100, Math.round((current / goal.target) * 100));

      const fillEl = document.getElementById(`goal-fill-${goal.id}`);
      const valEl = document.getElementById(`goal-val-${goal.id}`);

      if (fillEl) fillEl.style.width = `${pct}%`;
      if (valEl) valEl.textContent = `${current.toLocaleString()} / ${goal.target.toLocaleString()}`;
    }
  }

  public render() {
    if (!this.containerEl) return;

    const completed = this.goalManager.getCompletedCount();
    const total = this.goalManager.getTotalGoalsCount();
    const points = this.progression.data.points;

    const hideClass = this.inMenuMode && typeof window !== 'undefined' && window.innerWidth <= 900 ? ' mobile-menu-hide' : '';

    if (this.isCollapsed) {
      this.containerEl.className = `tilt-goals-sidebar collapsed${hideClass}`;
      this.containerEl.innerHTML = `
        <button id="btn-toggle-goals-hud" class="goals-expand-tab" type="button" title="Show Milestones (Click to unhide)">
          <span class="goals-star-icon">★</span>
          <span class="goals-expand-label">MILESTONES</span>
          <span class="goals-expand-badge">${completed}/${total}</span>
          <span class="goals-toggle-glyph">▶</span>
        </button>
      `;

      document.getElementById('btn-toggle-goals-hud')?.addEventListener('click', () => {
        this.toggleCollapse();
      });
      return;
    }

    this.containerEl.className = `tilt-goals-sidebar${hideClass}`;
    const active = this.goalManager.getActiveGoals(3);

    this.containerEl.innerHTML = `
      <div class="goals-sidebar-header">
        <div class="goals-header-title">
          <span class="goals-star-icon">★</span>
          <strong>MILESTONES</strong>
          <span class="goals-count-badge">${completed}/${total}</span>
        </div>
        <div class="goals-header-right">
          <div class="goals-vault-pill" title="Vault Balance">
            ◈ ${points.toLocaleString()} PTS
          </div>
          <button id="btn-toggle-goals-hud" class="goals-collapse-btn" type="button" title="Hide Milestones" aria-label="Hide Milestones">
            ◀
          </button>
        </div>
      </div>

      <div class="goals-list">
        ${active.length === 0 ? `
          <div class="goals-all-cleared">
            <span>🏆</span>
            <p>All milestones conquered!</p>
          </div>
        ` : active.map(({ goal }) => {
          return `
            <div class="goal-hud-card" id="goal-card-${goal.id}">
              <div class="goal-card-top">
                <span class="goal-card-title">${goal.title}</span>
                <span class="goal-card-reward">+${goal.rewardPoints} ${goal.rewardPoints === 1 ? 'PT' : 'PTS'}</span>
              </div>
              <p class="goal-card-desc">${goal.description}</p>
              <div class="goal-progress-row">
                <div class="goal-progress-track">
                  <div class="goal-progress-fill" id="goal-fill-${goal.id}" style="width: 0%;"></div>
                </div>
                <span class="goal-progress-val" id="goal-val-${goal.id}">0 / ${goal.target.toLocaleString()}</span>
              </div>
            </div>
          `;
        }).join('')}
      </div>

      <button id="btn-view-all-goals" type="button" class="goals-view-all-btn" title="View all 28 milestones">
        Trophy Catalog ➔
      </button>
    `;

    document.getElementById('btn-toggle-goals-hud')?.addEventListener('click', () => {
      this.toggleCollapse();
    });

    document.getElementById('btn-view-all-goals')?.addEventListener('click', () => {
      this.openAllGoalsModal();
    });
  }

  public openAllGoalsModal() {
    if (!this.allGoalsModalEl) return;

    const completed = this.goalManager.getCompletedCount();
    const total = this.goalManager.getTotalGoalsCount();
    const catalog = this.goalManager.catalog;

    this.allGoalsModalEl.innerHTML = `
      <div class="overlay-panel tilt-all-goals-panel" role="dialog" aria-modal="true" aria-label="Trophy Catalog">
        <div class="armory-header">
          <div class="armory-title-group">
            <p class="eyebrow">MILESTONE ACHIEVEMENTS</p>
            <h2>Trophy Catalog (${completed}/${total})</h2>
          </div>
          <div class="armory-header-right">
            <button id="btn-close-all-goals" class="armory-close-btn" type="button" aria-label="Close">✕</button>
          </div>
        </div>

        <div class="all-goals-scroll custom-scrollbar">
          <div class="all-goals-grid">
            ${catalog.map((goal) => {
              const isDone = this.goalManager.isCompleted(goal.id);
              return `
                <div class="catalog-goal-card ${isDone ? 'is-goal-done' : ''}">
                  <div class="catalog-goal-left">
                    <span class="goal-check-glyph">${isDone ? '✓' : '◈'}</span>
                    <div>
                      <h4>${goal.title}</h4>
                      <p>${goal.description}</p>
                    </div>
                  </div>
                  <div class="catalog-goal-right">
                    <span class="catalog-goal-reward">+${goal.rewardPoints} PTS</span>
                    <span class="catalog-goal-status">${isDone ? 'UNLOCKED' : 'LOCKED'}</span>
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        </div>
      </div>
    `;

    this.allGoalsModalEl.classList.remove('hidden');

    document.getElementById('btn-close-all-goals')?.addEventListener('click', () => {
      this.allGoalsModalEl?.classList.add('hidden');
    });
  }
}
