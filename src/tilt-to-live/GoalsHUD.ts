// =========================================================================
// GoalsHUD.ts - 4px Edge Rail HUD & Full Milestones Screen System
// =========================================================================

import { Goal, GoalManager, RunTracker } from './GoalManager';
import { ProgressionManager } from './ProgressionManager';

export class GoalsHUD {
  private readonly goalManager: GoalManager;
  private readonly progression: ProgressionManager;

  private railEl: HTMLElement | null = null;
  private toastContainerEl: HTMLElement | null = null;
  private milestonesModalEl: HTMLElement | null = null;

  public inMenuMode: boolean = false;
  private completedToastTimer: number | null = null;

  constructor(goalManager: GoalManager, progression: ProgressionManager) {
    this.goalManager = goalManager;
    this.progression = progression;

    this.initDOM();
    this.setupListeners();
    this.setupHotkey();
  }

  private initDOM() {
    // 1. In-game Left HUD: 4px Edge Rail (#tilt-edge-rail) replacing 240px sidebar (Board 05)
    let rail = document.getElementById('tilt-edge-rail');
    if (!rail) {
      // If legacy #tilt-goals-sidebar exists, repurpose or replace it
      const oldSidebar = document.getElementById('tilt-goals-sidebar');
      if (oldSidebar) {
        oldSidebar.id = 'tilt-edge-rail';
        rail = oldSidebar;
      } else {
        rail = document.createElement('div');
        rail.id = 'tilt-edge-rail';
        const stage = document.getElementById('tilt-stage') || document.body;
        stage.appendChild(rail);
      }
    }
    rail.className = 'tilt-edge-rail';
    rail.setAttribute('aria-label', 'Milestones Progress Rail (Click to open Milestones)');
    rail.setAttribute('role', 'button');
    rail.setAttribute('tabindex', '0');
    rail.setAttribute('title', 'Milestones — Press M or Click to view');
    this.railEl = rail;

    // 2. Clean Milestone Complete Toast in bottom-left during run (Board 05)
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

    // 3. Full Milestones Modal (Board 13)
    let modal = document.getElementById('tilt-all-goals-modal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'tilt-all-goals-modal';
      modal.className = 'game-overlay hidden tilt-all-goals-overlay';
      const stage = document.getElementById('tilt-stage') || document.body;
      stage.appendChild(modal);
    }
    this.milestonesModalEl = modal;

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

    // Click on edge rail opens the Milestones modal
    if (this.railEl) {
      this.railEl.addEventListener('click', () => {
        this.openAllGoalsModal();
      });
      this.railEl.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          this.openAllGoalsModal();
        }
      });
    }

    // Attach click listeners to Game Over milestones container to open milestones
    const bindGameOverClicks = () => {
      const gameOverMilestones = document.getElementById('tilt-gameover-milestones');
      gameOverMilestones?.addEventListener('click', () => this.openAllGoalsModal());
      const gameOverPoints = document.querySelector('.gameover-points-box');
      gameOverPoints?.addEventListener('click', () => this.openAllGoalsModal());
    };
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', bindGameOverClicks);
    } else {
      bindGameOverClicks();
    }
  }

  private setupHotkey() {
    window.addEventListener('keydown', (e: KeyboardEvent) => {
      // Toggle Milestones screen on 'M' key (unless typing in input)
      if ((e.key === 'm' || e.key === 'M') && !e.ctrlKey && !e.metaKey && !e.altKey) {
        const target = e.target as HTMLElement;
        if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA')) {
          return;
        }
        if (this.isModalOpen()) {
          this.closeAllGoalsModal();
        } else {
          this.openAllGoalsModal();
        }
      } else if (e.key === 'Escape' && this.isModalOpen()) {
        this.closeAllGoalsModal();
      }
    });
  }

  public isModalOpen(): boolean {
    return !!this.milestonesModalEl && !this.milestonesModalEl.classList.contains('hidden');
  }

  public setMenuMode(inMenu: boolean) {
    this.inMenuMode = inMenu;
    if (this.railEl) {
      if (inMenu) {
        this.railEl.classList.add('hidden');
      } else {
        this.railEl.classList.remove('hidden');
      }
    }
  }

  public toggleCollapse() {
    // Legacy support: toggle modal
    if (this.isModalOpen()) {
      this.closeAllGoalsModal();
    } else {
      this.openAllGoalsModal();
    }
  }

  /**
   * Clean notification toast in bottom-left during run (Board 05)
   */
  public showGoalToast(goal: Goal) {
    if (!this.toastContainerEl) return;

    this.toastContainerEl.innerHTML = `
      <div class="milestone-toast-card">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true" style="flex-shrink: 0;">
          <path d="M2 7.5 L5.5 11 L12 3.5" stroke="#3DDC97" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"></path>
        </svg>
        <span class="milestone-toast-title">${goal.title}</span>
        <span class="milestone-toast-reward">+${goal.rewardPoints}</span>
      </div>
    `;
    this.toastContainerEl.classList.remove('hidden');

    if (this.completedToastTimer !== null) {
      window.clearTimeout(this.completedToastTimer);
    }
    this.completedToastTimer = window.setTimeout(() => {
      this.toastContainerEl?.classList.add('hidden');
      this.completedToastTimer = null;
    }, 3000);
  }

  public showMessageToast(title: string, subtitle: string, rewardBadge?: string) {
    if (!this.toastContainerEl) return;

    this.toastContainerEl.innerHTML = `
      <div class="milestone-toast-card" style="border-left-color: #5B8CFF;">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true" style="flex-shrink: 0;">
          <circle cx="7" cy="7" r="5" stroke="#5B8CFF" stroke-width="1.5"></circle>
          <circle cx="7" cy="7" r="2" fill="#5B8CFF"></circle>
        </svg>
        <span class="milestone-toast-title">${title}</span>
        <span class="milestone-toast-subtitle" style="font-size: 12px; color: #99A1B3;">${subtitle}</span>
        ${rewardBadge ? `<span class="milestone-toast-reward">${rewardBadge}</span>` : ''}
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
    // Evaluate live cumulative milestones during gameplay
    this.goalManager.evaluateLiveTotalGoals(tracker);

    // Live update edge rail fill
    const completed = this.goalManager.getCompletedCount();
    const total = this.goalManager.getTotalGoalsCount();
    const pct = total > 0 ? completed / total : 0;

    const fillEl = document.getElementById('tilt-edge-rail-fill');
    if (fillEl) {
      fillEl.style.height = `${Math.round(pct * 100)}%`;
    }
  }

  public render() {
    if (!this.railEl) return;

    const completed = this.goalManager.getCompletedCount();
    const total = this.goalManager.getTotalGoalsCount();
    const pct = total > 0 ? (completed / total) * 100 : 0;

    // Render 4px Edge Rail on left screen edge with notches (Board 05)
    this.railEl.innerHTML = `
      <div id="tilt-edge-rail-fill" class="tilt-edge-rail-fill" style="height: ${pct}%;"></div>
      <div class="edge-rail-notch" style="top: 33%;"></div>
      <div class="edge-rail-notch" style="top: 66%;"></div>
      <div class="edge-rail-hover-tag">
        <span>${completed}/${total} MILESTONES</span>
      </div>
    `;

    if (this.isModalOpen()) {
      this.renderMilestonesModalContent();
    }
  }

  /**
   * Full Milestones Screen (Board 13)
   * Openable from Menu ('Milestones' link), Game Over, or hotkey 'M'.
   */
  public openAllGoalsModal() {
    if (!this.milestonesModalEl) return;
    this.renderMilestonesModalContent();
    this.milestonesModalEl.classList.remove('hidden');

    // Bind close button
    document.getElementById('btn-close-milestones')?.addEventListener('click', () => {
      this.closeAllGoalsModal();
    });
  }

  public closeAllGoalsModal() {
    if (this.milestonesModalEl) {
      this.milestonesModalEl.classList.add('hidden');
    }
  }

  private renderMilestonesModalContent() {
    if (!this.milestonesModalEl) return;

    const completed = this.goalManager.getCompletedCount();
    const total = this.goalManager.getTotalGoalsCount();
    const points = this.progression.data.points;
    const progressPct = total > 0 ? Math.round((completed / total) * 100) : 0;

    // Categorize goals into the 3 Claude Tiers: Score, Combat, Mastery
    const catalog = this.goalManager.catalog;

    const getGoalTier = (goal: Goal): 'Score' | 'Combat' | 'Mastery' => {
      if (
        goal.category === 'score' ||
        goal.metric === 'run_score' ||
        goal.metric === 'total_score' ||
        goal.metric === 'total_points'
      ) {
        return 'Score';
      }
      if (
        goal.category === 'combat' ||
        goal.category === 'combo' ||
        goal.category === 'weapons' ||
        goal.metric.includes('kills') ||
        goal.metric.includes('multiplier') ||
        goal.metric.includes('nuke') ||
        goal.metric.includes('vortex') ||
        goal.metric.includes('laser') ||
        goal.metric.includes('missile') ||
        goal.metric.includes('freeze') ||
        goal.metric.includes('shield')
      ) {
        return 'Combat';
      }
      return 'Mastery';
    };

    const tiersConfig = [
      { name: 'Score', tint: '#5B8CFF', goals: catalog.filter((g) => getGoalTier(g) === 'Score') },
      { name: 'Combat', tint: '#A78BFA', goals: catalog.filter((g) => getGoalTier(g) === 'Combat') },
      { name: 'Mastery', tint: '#FFB14D', goals: catalog.filter((g) => getGoalTier(g) === 'Mastery') }
    ];

    this.milestonesModalEl.innerHTML = `
      <div class="overlay-panel tilt-all-goals-panel tilt-milestones-screen" role="dialog" aria-modal="true" aria-label="Milestones">
        <!-- Milestones Header (Board 13) -->
        <div class="milestones-screen-header">
          <h2 class="milestones-screen-title">Milestones</h2>
          <span class="milestones-screen-counter">${completed}<span class="counter-denom">/${total}</span></span>
          <span class="milestones-header-progress-track">
            <span class="milestones-header-progress-fill" style="width: ${progressPct}%;"></span>
          </span>
          <div class="milestones-header-right">
            <span class="milestones-header-points">${points.toLocaleString()} <span class="pts-unit">PTS</span></span>
            <button id="btn-close-milestones" type="button" class="milestones-screen-close" aria-label="Close milestones">
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
                <path d="M2 2 L12 12 M12 2 L2 12" stroke="#99A1B3" stroke-width="1.5" stroke-linecap="round"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- Milestones Body: 3 Tiers (Score, Combat, Mastery) -->
        <div class="milestones-screen-body custom-scrollbar">
          ${tiersConfig.map((tier) => {
            const tierDoneCount = tier.goals.filter((g) => this.goalManager.isCompleted(g.id)).length;
            const tierTotalCount = tier.goals.length;

            return `
              <div class="milestones-tier-group">
                <div class="milestones-tier-heading">
                  <span class="tier-name" style="color: ${tier.tint};">${tier.name}</span>
                  <span class="tier-count">${tierDoneCount} of ${tierTotalCount}</span>
                </div>
                <div class="milestones-tier-grid">
                  ${tier.goals.map((goal) => {
                    const isDone = this.goalManager.isCompleted(goal.id);

                    // Compute goal progress representation
                    let currentVal = 0;
                    if (this.goalManager.isTotalGoal(goal)) {
                      currentVal = this.goalManager.getMetricValue(goal.metric, {
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
                    }

                    const pct = Math.min(100, Math.max(0, Math.round((currentVal / goal.target) * 100)));

                    if (isDone) {
                      return `
                        <div class="milestone-card is-done">
                          <span class="milestone-mark-box done">
                            <svg width="11" height="11" viewBox="0 0 11 11" fill="none" aria-hidden="true">
                              <path d="M1.5 5.8 L4.2 8.5 L9.5 2.8" stroke="#08090E" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"></path>
                            </svg>
                          </span>
                          <div class="milestone-card-content">
                            <span class="milestone-card-name">${goal.title}</span>
                            <span class="milestone-card-goal">${goal.description}</span>
                          </div>
                          <span class="milestone-card-pts done">+${goal.rewardPoints}</span>
                        </div>
                      `;
                    }

                    // Open / In-Progress Goal
                    const goalSubtitle = this.goalManager.isTotalGoal(goal)
                      ? `${currentVal.toLocaleString()} / ${goal.target.toLocaleString()}`
                      : goal.description;

                    return `
                      <div class="milestone-card is-open">
                        <span class="milestone-mark-box open"></span>
                        <div class="milestone-card-content">
                          <span class="milestone-card-name">${goal.title}</span>
                          <span class="milestone-card-goal">${goalSubtitle}</span>
                          <span class="milestone-card-bar-track">
                            <span class="milestone-card-bar-fill" style="width: ${pct}%;"></span>
                          </span>
                        </div>
                        <span class="milestone-card-pts open">+${goal.rewardPoints}</span>
                      </div>
                    `;
                  }).join('')}
                </div>
              </div>
            `;
          }).join('')}
        </div>
      </div>
    `;

    document.getElementById('btn-close-milestones')?.addEventListener('click', () => {
      this.closeAllGoalsModal();
    });
  }
}
