// =========================================================================
// GoalManager.ts - Milestone-Based Achievement, Challenge & Points Engine
// =========================================================================

export interface Goal {
  id: string;
  category: 'score' | 'combat' | 'combo' | 'weapons' | 'survival' | 'modes' | 'cumulative';
  title: string;
  description: string;
  target: number;
  rewardPoints: number;
  metric:
    | 'run_score'
    | 'run_kills'
    | 'run_multiplier'
    | 'run_survival'
    | 'run_close_calls'
    | 'run_nukes'
    | 'run_vortex_absorbs'
    | 'run_laser_slices'
    | 'run_missiles'
    | 'run_freeze_shatters'
    | 'run_shield_rams'
    | 'code_red_survival'
    | 'gauntlet_survival'
    // Lifetime Cumulative Metrics:
    | 'total_kills'
    | 'total_survival'
    | 'total_points'
    | 'total_score';
}

export interface CumulativeStats {
  totalKills: number;
  totalSurvivalTime: number;
  totalPointsEarned: number;
  totalScore: number;
}

export interface RunTracker {
  mode: string;
  score: number;
  kills: number;
  multiplier: number;
  survivalTime: number;
  closeCalls: number;
  nukesDetonated: number;
  vortexAbsorbs: number;
  laserSlices: number;
  missilesFired: number;
  freezeShatters: number;
  shieldRams: number;
}

const STORAGE_KEY = 'tilt_to_live_completed_goals_v1';
const CUMULATIVE_STORAGE_KEY = 'tilt_to_live_cumulative_stats_v1';

export class GoalManager {
  private completedGoalIds: Set<string> = new Set();
  private onGoalCompletedCb?: (goal: Goal) => void;
  private onPointsAwardedCb?: (pts: number) => void;

  public readonly catalog: Goal[] = [
    // Score Milestones
    {
      id: 'score_1k',
      category: 'score',
      title: 'Rookie Dodger',
      description: 'Reach 1,000 score in a run',
      target: 1000,
      rewardPoints: 1,
      metric: 'run_score'
    },
    {
      id: 'score_5k',
      category: 'score',
      title: 'Neon Striker',
      description: 'Reach 5,000 score in a run',
      target: 5000,
      rewardPoints: 2,
      metric: 'run_score'
    },
    {
      id: 'score_10k',
      category: 'score',
      title: 'Swarm Survivor',
      description: 'Reach 10,000 score in a run',
      target: 10000,
      rewardPoints: 3,
      metric: 'run_score'
    },
    {
      id: 'score_25k',
      category: 'score',
      title: 'Apex Dodger',
      description: 'Reach 25,000 score in a run',
      target: 25000,
      rewardPoints: 5,
      metric: 'run_score'
    },
    {
      id: 'score_50k',
      category: 'score',
      title: 'Orbital Ace',
      description: 'Reach 50,000 score in a run',
      target: 50000,
      rewardPoints: 8,
      metric: 'run_score'
    },

    // Combat Kills
    {
      id: 'kills_15',
      category: 'combat',
      title: 'First Extermination',
      description: 'Destroy 15 red dots in a run',
      target: 15,
      rewardPoints: 1,
      metric: 'run_kills'
    },
    {
      id: 'kills_50',
      category: 'combat',
      title: 'Pest Control',
      description: 'Destroy 50 red dots in a run',
      target: 50,
      rewardPoints: 2,
      metric: 'run_kills'
    },
    {
      id: 'kills_100',
      category: 'combat',
      title: 'Centurion',
      description: 'Destroy 100 red dots in a run',
      target: 100,
      rewardPoints: 3,
      metric: 'run_kills'
    },
    {
      id: 'kills_200',
      category: 'combat',
      title: 'Swarm Annihilator',
      description: 'Destroy 200 red dots in a run',
      target: 200,
      rewardPoints: 5,
      metric: 'run_kills'
    },

    // Combo Multipliers
    {
      id: 'mult_3',
      category: 'combo',
      title: 'Momentum',
      description: 'Reach a 3x Multiplier',
      target: 3,
      rewardPoints: 1,
      metric: 'run_multiplier'
    },
    {
      id: 'mult_5',
      category: 'combo',
      title: 'Fever Pitch',
      description: 'Reach a 5x Multiplier',
      target: 5,
      rewardPoints: 2,
      metric: 'run_multiplier'
    },
    {
      id: 'mult_8',
      category: 'combo',
      title: 'Hyper Rhythm',
      description: 'Reach an 8x Multiplier',
      target: 8,
      rewardPoints: 3,
      metric: 'run_multiplier'
    },
    {
      id: 'mult_12',
      category: 'combo',
      title: 'Ascended Multiplier',
      description: 'Reach a 12x Multiplier',
      target: 12,
      rewardPoints: 5,
      metric: 'run_multiplier'
    },

    // Survival & Near-Misses
    {
      id: 'close_call_3',
      category: 'survival',
      title: 'Living on the Edge',
      description: 'Trigger 3 Close Calls in a run',
      target: 3,
      rewardPoints: 1,
      metric: 'run_close_calls'
    },
    {
      id: 'close_call_7',
      category: 'survival',
      title: 'Daredevil',
      description: 'Trigger 7 Close Calls in a run',
      target: 7,
      rewardPoints: 2,
      metric: 'run_close_calls'
    },
    {
      id: 'survive_30',
      category: 'survival',
      title: 'Holding the Line',
      description: 'Survive for 30 seconds',
      target: 30,
      rewardPoints: 1,
      metric: 'run_survival'
    },
    {
      id: 'survive_60',
      category: 'survival',
      title: 'Minute Master',
      description: 'Survive for 60 seconds',
      target: 60,
      rewardPoints: 2,
      metric: 'run_survival'
    },
    {
      id: 'survive_120',
      category: 'survival',
      title: 'Iron Will',
      description: 'Survive for 120 seconds',
      target: 120,
      rewardPoints: 4,
      metric: 'run_survival'
    },

    // Weapons
    {
      id: 'nuke_3',
      category: 'weapons',
      title: 'Atomic Retribution',
      description: 'Detonate 3 Nukes in one run',
      target: 3,
      rewardPoints: 2,
      metric: 'run_nukes'
    },
    {
      id: 'vortex_20',
      category: 'weapons',
      title: 'Singularity Feast',
      description: 'Absorb 20 dots with Vortexes',
      target: 20,
      rewardPoints: 2,
      metric: 'run_vortex_absorbs'
    },
    {
      id: 'laser_20',
      category: 'weapons',
      title: 'Photon Slicer',
      description: 'Slice 20 dots with Laser Lances',
      target: 20,
      rewardPoints: 2,
      metric: 'run_laser_slices'
    },
    {
      id: 'missiles_30',
      category: 'weapons',
      title: 'Cluster Barrage',
      description: 'Fire 30 Homing Missiles in a run',
      target: 30,
      rewardPoints: 2,
      metric: 'run_missiles'
    },
    {
      id: 'freeze_15',
      category: 'weapons',
      title: 'Sub-Zero Shatter',
      description: 'Shatter 15 Frozen red dots',
      target: 15,
      rewardPoints: 2,
      metric: 'run_freeze_shatters'
    },
    {
      id: 'shield_10',
      category: 'weapons',
      title: 'Battering Ram',
      description: 'Ram 10 dots while Shielded',
      target: 10,
      rewardPoints: 2,
      metric: 'run_shield_rams'
    },

    // Game Mode Challenges
    {
      id: 'mode_code_red_30',
      category: 'modes',
      title: 'Red Alert Survivor',
      description: 'Survive 30s in Code Red mode',
      target: 30,
      rewardPoints: 2,
      metric: 'code_red_survival'
    },
    {
      id: 'mode_code_red_60',
      category: 'modes',
      title: 'Code Red Champion',
      description: 'Survive 60s in Code Red mode',
      target: 60,
      rewardPoints: 4,
      metric: 'code_red_survival'
    },
    {
      id: 'mode_gauntlet_30',
      category: 'modes',
      title: 'Gauntlet Runner',
      description: 'Survive 30s in Gauntlet mode',
      target: 30,
      rewardPoints: 2,
      metric: 'gauntlet_survival'
    },

    // Lifetime Cumulative Milestones (Continuous Progress across all games)
    {
      id: 'total_kills_100',
      category: 'cumulative',
      title: 'Century of Destruction',
      description: 'Destroy 100 total red dots across all games',
      target: 100,
      rewardPoints: 2,
      metric: 'total_kills'
    },
    {
      id: 'total_kills_500',
      category: 'cumulative',
      title: 'Swarm Exterminator',
      description: 'Destroy 500 total red dots across all games',
      target: 500,
      rewardPoints: 4,
      metric: 'total_kills'
    },
    {
      id: 'total_kills_1500',
      category: 'cumulative',
      title: 'Swarm Nemesis',
      description: 'Destroy 1,500 total red dots across all games',
      target: 1500,
      rewardPoints: 8,
      metric: 'total_kills'
    },
    {
      id: 'total_survival_180',
      category: 'cumulative',
      title: 'Persistent Pilot',
      description: 'Survive 3 minutes (180s) total across all games',
      target: 180,
      rewardPoints: 2,
      metric: 'total_survival'
    },
    {
      id: 'total_survival_600',
      category: 'cumulative',
      title: 'Decade of Minutes',
      description: 'Survive 10 minutes (600s) total across all games',
      target: 600,
      rewardPoints: 5,
      metric: 'total_survival'
    },
    {
      id: 'total_score_50k',
      category: 'cumulative',
      title: 'Score Accumulator',
      description: 'Accumulate 50,000 total score across all games',
      target: 50000,
      rewardPoints: 3,
      metric: 'total_score'
    },
    {
      id: 'total_score_250k',
      category: 'cumulative',
      title: 'Quarter Millionaire',
      description: 'Accumulate 250,000 total score across all games',
      target: 250000,
      rewardPoints: 6,
      metric: 'total_score'
    },
    {
      id: 'total_points_10',
      category: 'cumulative',
      title: 'Vault Apprentice',
      description: 'Earn 10 milestone points in total',
      target: 10,
      rewardPoints: 2,
      metric: 'total_points'
    },
    {
      id: 'total_points_25',
      category: 'cumulative',
      title: 'Vault Master',
      description: 'Earn 25 milestone points in total',
      target: 25,
      rewardPoints: 5,
      metric: 'total_points'
    }
  ];

  public cumulative: CumulativeStats = {
    totalKills: 0,
    totalSurvivalTime: 0,
    totalPointsEarned: 0,
    totalScore: 0
  };

  constructor() {
    this.loadCompleted();
    this.loadCumulative();
  }

  public setCallbacks(
    onGoalCompleted: (goal: Goal) => void,
    onPointsAwarded: (pts: number) => void
  ) {
    this.onGoalCompletedCb = onGoalCompleted;
    this.onPointsAwardedCb = onPointsAwarded;
  }

  private loadCompleted() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) {
          this.completedGoalIds = new Set(parsed);
        }
      }
    } catch {}
  }

  public saveCompleted() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(Array.from(this.completedGoalIds)));
    } catch {}
  }

  private loadCumulative() {
    try {
      const raw = localStorage.getItem(CUMULATIVE_STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        this.cumulative = {
          totalKills: Number(parsed.totalKills) || 0,
          totalSurvivalTime: Number(parsed.totalSurvivalTime) || 0,
          totalPointsEarned: Number(parsed.totalPointsEarned) || 0,
          totalScore: Number(parsed.totalScore) || 0
        };
      }
    } catch {}
  }

  public saveCumulative() {
    try {
      localStorage.setItem(CUMULATIVE_STORAGE_KEY, JSON.stringify(this.cumulative));
    } catch {}
  }

  public isCompleted(goalId: string): boolean {
    return this.completedGoalIds.has(goalId);
  }

  public isTotalGoal(goal: Goal): boolean {
    return goal.category === 'cumulative' || goal.metric.startsWith('total_');
  }

  public getCompletedCount(): number {
    return this.completedGoalIds.size;
  }

  public getTotalGoalsCount(): number {
    return this.catalog.length;
  }

  public getActiveGoals(maxCount: number = 3): { goal: Goal; current: number }[] {
    const uncompleted = this.catalog.filter((g) => !this.completedGoalIds.has(g.id));
    return uncompleted.slice(0, maxCount).map((goal) => ({
      goal,
      current: 0
    }));
  }

  /**
   * Evaluates ONLY cumulative / total milestones during active gameplay.
   * Single-run milestones are intentionally NEVER completed mid-run.
   */
  public evaluateLiveTotalGoals(tracker: RunTracker): Goal[] {
    const newlyCompleted: Goal[] = [];

    for (const goal of this.catalog) {
      if (this.completedGoalIds.has(goal.id)) continue;
      if (!this.isTotalGoal(goal)) continue;

      const current = this.getMetricValue(goal.metric, tracker);
      if (current >= goal.target) {
        this.completedGoalIds.add(goal.id);
        this.cumulative.totalPointsEarned += goal.rewardPoints;
        newlyCompleted.push(goal);
        this.saveCompleted();
        this.saveCumulative();

        if (this.onPointsAwardedCb) {
          this.onPointsAwardedCb(goal.rewardPoints);
        }
        if (this.onGoalCompletedCb) {
          this.onGoalCompletedCb(goal);
        }
      }
    }

    return newlyCompleted;
  }

  /**
   * Finalizes milestones when a game completes (player death / game over).
   * At most 3 per-run milestones can be achieved in a single game.
   * Also commits run stats into lifetime cumulative totals.
   */
  public evaluateRun(tracker: RunTracker): Goal[] {
    // 1. Commit run stats to cumulative lifetime totals
    this.cumulative.totalKills += tracker.kills;
    this.cumulative.totalSurvivalTime += Math.floor(tracker.survivalTime);
    this.cumulative.totalScore += tracker.score;

    const newlyCompleted: Goal[] = [];

    // 2. Evaluate Total / Cumulative milestones (unlimited per game)
    for (const goal of this.catalog) {
      if (this.completedGoalIds.has(goal.id)) continue;
      if (!this.isTotalGoal(goal)) continue;

      const current = this.getMetricValue(goal.metric, tracker);
      if (current >= goal.target) {
        this.completedGoalIds.add(goal.id);
        this.cumulative.totalPointsEarned += goal.rewardPoints;
        newlyCompleted.push(goal);
      }
    }

    // 3. Evaluate Single-Run milestones (STRICTLY CAPPED AT 3 PER GAME)
    const eligibleRunGoals: Goal[] = [];
    for (const goal of this.catalog) {
      if (this.completedGoalIds.has(goal.id)) continue;
      if (this.isTotalGoal(goal)) continue;

      const current = this.getMetricValue(goal.metric, tracker);
      if (current >= goal.target) {
        eligibleRunGoals.push(goal);
      }
    }

    // Award top / first 3 eligible run milestones
    const awardedRunGoals = eligibleRunGoals.slice(0, 3);
    for (const goal of awardedRunGoals) {
      this.completedGoalIds.add(goal.id);
      this.cumulative.totalPointsEarned += goal.rewardPoints;
      newlyCompleted.push(goal);
    }

    this.saveCompleted();
    this.saveCumulative();

    // Trigger callbacks for awarded goals
    for (const goal of newlyCompleted) {
      if (this.onPointsAwardedCb) {
        this.onPointsAwardedCb(goal.rewardPoints);
      }
      if (this.onGoalCompletedCb) {
        this.onGoalCompletedCb(goal);
      }
    }

    return newlyCompleted;
  }

  public getMetricValue(metric: Goal['metric'], tracker: RunTracker): number {
    switch (metric) {
      case 'run_score':
        return tracker.score;
      case 'run_kills':
        return tracker.kills;
      case 'run_multiplier':
        return tracker.multiplier;
      case 'run_survival':
        return Math.floor(tracker.survivalTime);
      case 'run_close_calls':
        return tracker.closeCalls;
      case 'run_nukes':
        return tracker.nukesDetonated;
      case 'run_vortex_absorbs':
        return tracker.vortexAbsorbs;
      case 'run_laser_slices':
        return tracker.laserSlices;
      case 'run_missiles':
        return tracker.missilesFired;
      case 'run_freeze_shatters':
        return tracker.freezeShatters;
      case 'run_shield_rams':
        return tracker.shieldRams;
      case 'code_red_survival':
        return tracker.mode === 'code-red' ? Math.floor(tracker.survivalTime) : 0;
      case 'gauntlet_survival':
        return tracker.mode === 'gauntlet' ? Math.floor(tracker.survivalTime) : 0;

      // Cumulative Lifetime Metrics:
      case 'total_kills':
        return this.cumulative.totalKills + tracker.kills;
      case 'total_survival':
        return this.cumulative.totalSurvivalTime + Math.floor(tracker.survivalTime);
      case 'total_points':
        return this.cumulative.totalPointsEarned;
      case 'total_score':
        return this.cumulative.totalScore + tracker.score;

      default:
        return 0;
    }
  }

  public resetAllProgress() {
    this.completedGoalIds.clear();
    this.cumulative = {
      totalKills: 0,
      totalSurvivalTime: 0,
      totalPointsEarned: 0,
      totalScore: 0
    };
    this.saveCompleted();
    this.saveCumulative();
  }
}
