// =========================================================================
// GoalsHUD.ts - Milestone rail (in run) and milestone list (menu / modal)
// =========================================================================

import { Goal, GoalManager, RunTracker } from './GoalManager';
import { ProgressionManager } from './ProgressionManager';

const ICON_STAR =
  '<svg class="tilt-icon icon-star" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M12 3.5l2.6 5.3 5.9.9-4.25 4.15 1 5.85L12 16.9l-5.25 2.8 1-5.85L3.5 9.7l5.9-.9z"></path></svg>';

const ICON_CHECK =
  '<svg class="tilt-icon icon-check" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M4.5 12.5l5 5 10-11"></path></svg>';

const ICON_CHEVRON_LEFT =
  '<svg class="tilt-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M15 5l-7 7 7 7"></path></svg>';

const ICON_CHEVRON_RIGHT =
  '<svg class="tilt-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M9 5l7 7-7 7"></path></svg>';

const ICON_CLOSE =
  '<svg class="tilt-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M6 6l12 12M18 6L6 18"></path></svg>';

export class GoalsHUD {
  private readonly goalManager: GoalManager;
  private readonly progression: ProgressionManager;
  private containerEl: HTMLElement | null = null;
  private toastContainerEl: HTMLElement | null = null;
  private allGoalsModalEl: HTMLElement | null = null;

  public isCollapsed: boolean = false;
  /** true => full milestone list (menu screen). false => 4px in-run rail. */
  private inMenuMode: boolean = true;
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

  /**
   * Mode flag. `true` renders the full milestone list (menu screen);
   * `false` collapses the sidebar to the 4px in-run completion rail.
   * Signature unchanged so existing call sites keep compiling.
   */
  public setMenuMode(inMenu: boolean) {
    const changed = this.inMenuMode !== inMenu;
    this.inMenuMode = inMenu;
    if (this.containerEl) {
      if (inMenu && typeof window !== 'undefined' && window.innerWidth <= 900) {
        this.containerEl.classList.add('mobile-menu-hide');
      } else {
        this.containerEl.classList.remove('mobile-menu-hide');
      }
    }
    if (changed) this.render();
  }

  private initDOM() {
    // 1. Left-side milestone sidebar container
    let el = document.getElementById('tilt-goals-sidebar');
    if (!el) {
      el = document.createElement('aside');
      el.id = 'tilt-goals-sidebar';
      el.className = 'tilt-goals-sidebar';
      el.setAttribute('aria-label', 'Milestones');
      const stage = document.getElementById('tilt-stage') || document.body;
      stage.appendChild(el);
    }
    this.containerEl = el;

    // 2. Milestone toast container
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

    // 3. All-milestones modal
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
        <span class="toast-icon">${ICON_CHECK}</span>
        <div class="toast-text">
          <small>MILESTONE</small>
          <strong>${goal.title}</strong>
        </div>
        <span class="toast-reward">+${goal.rewardPoints} pts</span>
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
        <span class="toast-icon">${ICON_STAR}</span>
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

    // In-run the sidebar is a text-free rail: nothing per-goal to update.
    if (!this.inMenuMode) return;
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

    if (!this.inMenuMode) {
      this.renderRail();
      return;
    }
    this.renderList();
  }

  // -----------------------------------------------------------------------
  // In-run: 4px completion rail pinned to the left edge. No text, no cards,
  // no toggle button, and it takes no width from the playfield.
  // -----------------------------------------------------------------------
  private renderRail() {
    if (!this.containerEl) return;

    const completed = this.goalManager.getCompletedCount();
    const total = Math.max(1, this.goalManager.getTotalGoalsCount());
    const pct = Math.min(100, Math.round((completed / total) * 100));

    // One tick per milestone boundary, so the rail reads as segments.
    const tickCount = Math.min(total, 28);
    let ticks = '';
    for (let i = 1; i < tickCount; i++) {
      ticks += `<span class="goals-rail-tick" style="top:${(i / tickCount) * 100}%"></span>`;
    }

    this.containerEl.className = 'tilt-goals-sidebar is-rail';
    this.containerEl.setAttribute('aria-label', `Milestones ${completed} of ${total}`);
    this.containerEl.innerHTML = `
      <div class="goals-rail" role="presentation">
        <div class="goals-rail-fill" style="height:${pct}%"></div>
        ${ticks}
      </div>
    `;
  }

  // -----------------------------------------------------------------------
  // Menu screen: the full milestone list.
  // -----------------------------------------------------------------------
  private renderList() {
    if (!this.containerEl) return;

    const completed = this.goalManager.getCompletedCount();
    const total = this.goalManager.getTotalGoalsCount();
    const points = this.progression.data.points;

    const hideClass = typeof window !== 'undefined' && window.innerWidth <= 900 ? ' mobile-menu-hide' : '';

    this.containerEl.setAttribute('aria-label', 'Milestones');

    if (this.isCollapsed) {
      this.containerEl.className = `tilt-goals-sidebar collapsed${hideClass}`;
      this.containerEl.innerHTML = `
        <button id="btn-toggle-goals-hud" class="goals-expand-tab" type="button" title="Show">
          <span class="goals-star-icon">${ICON_STAR}</span>
          <span class="goals-expand-label">MILESTONES</span>
          <span class="goals-expand-badge">${completed}/${total}</span>
          <span class="goals-toggle-glyph">${ICON_CHEVRON_RIGHT}</span>
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
          <span class="goals-star-icon">${ICON_STAR}</span>
          <strong>MILESTONES</strong>
          <span class="goals-count-badge">${completed}/${total}</span>
        </div>
        <div class="goals-header-right">
          <div class="goals-points-pill" title="Points">
            <span class="goals-points-label">POINTS</span>
            <span class="goals-points-value">${points.toLocaleString()}</span>
          </div>
          <button id="btn-toggle-goals-hud" class="goals-collapse-btn" type="button" title="Hide" aria-label="Hide">
            ${ICON_CHEVRON_LEFT}
          </button>
        </div>
      </div>

      <div class="goals-list">
        ${active.length === 0 ? `
          <div class="goals-all-cleared">
            <span class="goals-cleared-icon">${ICON_CHECK}</span>
            <p>All milestones complete</p>
          </div>
        ` : active.map(({ goal }) => {
          return `
            <div class="goal-hud-card" id="goal-card-${goal.id}">
              <div class="goal-card-top">
                <span class="goal-card-title">${goal.title}</span>
                <span class="goal-card-reward">+${goal.rewardPoints} pts</span>
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

      <button id="btn-view-all-goals" type="button" class="goals-view-all-btn" title="All milestones">
        <span class="tilt-btn-text">Milestones</span>
        ${ICON_CHEVRON_RIGHT}
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
      <div class="overlay-panel tilt-all-goals-panel" role="dialog" aria-modal="true" aria-label="Milestones">
        <div class="armory-header">
          <div class="armory-title-group">
            <h2>Milestones</h2>
            <span class="all-goals-count">${completed}/${total}</span>
          </div>
          <div class="armory-header-right">
            <button id="btn-close-all-goals" class="armory-close-btn" type="button" aria-label="Close">${ICON_CLOSE}</button>
          </div>
        </div>

        <div class="all-goals-scroll custom-scrollbar">
          <div class="all-goals-grid">
            ${catalog.map((goal) => {
              const isDone = this.goalManager.isCompleted(goal.id);
              return `
                <div class="catalog-goal-card ${isDone ? 'is-goal-done' : ''}">
                  <div class="catalog-goal-left">
                    <span class="goal-check-glyph">${isDone ? ICON_CHECK : ICON_STAR}</span>
                    <div class="catalog-goal-copy">
                      <h4>${goal.title}</h4>
                      <p>${goal.description}</p>
                    </div>
                  </div>
                  <div class="catalog-goal-right">
                    <span class="catalog-goal-reward">+${goal.rewardPoints} pts</span>
                    <span class="catalog-goal-status">${isDone ? 'DONE' : 'LOCKED'}</span>
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
