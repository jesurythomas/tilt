// =========================================================================
// ArmoryUI.ts - In-Game Shop, Upgrades, Fleet Chassis, Arena & Control Tuning
// Matching Designs: Boards 09 (Weapons), 10 (Ships), 11 (Handling), 17 (Mobile)
// =========================================================================

import { ProgressionManager, WeaponPerks } from './ProgressionManager';
import { getTunedValue, KEYSTONE_COSTS, TuningUnit, WEAPON_TUNING } from './WeaponTuning';
import { WeaponType } from './Types';

export type ArmoryTab =
  | 'weapons'
  | 'ships'
  | 'arena'
  | 'handling'
  | 'boosts'
  | 'perks'
  | 'cursors'
  | 'enemies'
  | 'arenas'
  | 'tuning';

interface WeaponTrack {
  key: string;
  name: string;
  effect: string;
  maxRank: number;
}

interface WeaponKeystone {
  key: string;
  name: string;
  description: string;
}

interface BoostConfig {
  id: string;
  name: string;
  effect: string;
  maxRank: number;
  getRank: () => number;
  getCost: () => number | null;
  buy: () => boolean;
}

/** Formats a WEAPON_TUNING value per its unit, matching the engine's own math. */
function formatTuningValue(value: number, unit: TuningUnit): string {
  switch (unit) {
    case 'seconds':
      return `${value.toFixed(1)}s`;
    case 'percent':
      return `+${Math.round(value)}%`;
    case 'range':
    case 'count':
    default:
      return `${Math.round(value)}`;
  }
}

interface WeaponConfig {
  id: keyof WeaponPerks;
  name: string;
  dot: string;
  description: string;
  iconSvg: string;
  tracks: WeaponTrack[];
  keystones: WeaponKeystone[];
}

/** Formats a points value with the correct singular/plural unit, e.g. "1 pt" / "400 pts". */
function formatPoints(n: number): string {
  return `${n.toLocaleString()} ${n === 1 ? 'pt' : 'pts'}`;
}

export class ArmoryUI {
  private readonly progression: ProgressionManager;
  private readonly onStateChanged: () => void;
  private readonly onCloseModal: () => void;

  private containerEl: HTMLElement | null = null;
  private activeTab: 'weapons' | 'ships' | 'arena' | 'handling' | 'boosts' = 'weapons';
  private selectedWeaponId: keyof WeaponPerks = 'blackhole';

  // Handling live interactive preview state
  private previewCanvas: HTMLCanvasElement | null = null;
  private previewRafId: number | null = null;
  private previewMousePos: { x: number; y: number } = { x: 0, y: 0 };
  private previewShip = {
    x: 0,
    y: 0,
    vx: 0,
    vy: 0,
    angle: -Math.PI / 2
  };
  private previewInitialized: boolean = false;

  private readonly weaponsCatalog: WeaponConfig[] = [
    {
      id: 'blackhole',
      name: 'Blackhole',
      dot: '#A78BFA',
      description: 'Drags dots in, then collapses.',
      iconSvg: `<svg width="30" height="30" viewBox="0 0 30 30" fill="none" aria-hidden="true"><circle cx="15" cy="15" r="11" stroke="#A78BFA" stroke-width="1.4"></circle><circle cx="15" cy="15" r="5" fill="#A78BFA"></circle></svg>`,
      tracks: [
        { key: 'duration', name: 'Duration', effect: '+0.5s / rank', maxRank: 5 },
        { key: 'radius', name: 'Radius', effect: '+18 range / rank', maxRank: 5 },
        { key: 'gravity', name: 'Pull', effect: '+20% / rank', maxRank: 5 }
      ],
      keystones: [
        { key: 'invulnerableInside', name: 'Aegis', description: 'You are safe inside the well.' },
        { key: 'supernovaCollapse', name: 'Supernova', description: 'Collapse fires a 320 range shockwave.' }
      ]
    },
    {
      id: 'missiles',
      name: 'Missiles',
      dot: '#5B8CFF',
      description: 'Swarm homing warheads track and annihilate dots.',
      iconSvg: `<svg width="30" height="30" viewBox="0 0 30 30" fill="none" aria-hidden="true"><path d="M15 4 L20 12 L19 22 L15 20 L11 22 L10 12 Z" stroke="#5B8CFF" stroke-width="1.4" fill="rgba(91,140,255,0.2)"></path><circle cx="15" cy="11" r="2.5" fill="#5B8CFF"></circle></svg>`,
      tracks: [
        { key: 'count', name: 'Salvo Count', effect: '+1 missile / rank', maxRank: 5 },
        { key: 'blastRadius', name: 'Detonation Radius', effect: '+6 range / rank', maxRank: 5 },
        { key: 'flightSpeed', name: 'Propulsion', effect: '+20% / rank', maxRank: 5 }
      ],
      keystones: [
        { key: 'clusterSplit', name: 'Cluster Split', description: 'Warheads divide into twins on intercept.' },
        { key: 'hyperThrusters', name: 'Hyper Thrusters', description: 'Instant target lock and hypersonic velocity.' }
      ]
    },
    {
      id: 'laser',
      name: 'Laser',
      dot: '#5B8CFF',
      description: 'Continuous piercing beam sweeps through swarms.',
      iconSvg: `<svg width="30" height="30" viewBox="0 0 30 30" fill="none" aria-hidden="true"><line x1="4" y1="15" x2="26" y2="15" stroke="#5B8CFF" stroke-width="2.5" stroke-linecap="round"></line><line x1="8" y1="9" x2="22" y2="21" stroke="#5B8CFF" stroke-width="1.2" stroke-dasharray="2,3"></line></svg>`,
      tracks: [
        { key: 'length', name: 'Beam Reach', effect: '+20 range / rank', maxRank: 5 },
        { key: 'duration', name: 'Emission Time', effect: '+0.4s / rank', maxRank: 5 }
      ],
      keystones: [
        { key: 'crossBeam', name: 'Cross Beam', description: 'Splits beam into 4-way perpendicular cross.' },
        { key: 'refractorLance', name: 'Refractor Lance', description: 'Beams bounce off arena perimeter walls.' }
      ]
    },
    {
      id: 'nuke',
      name: 'Nuke',
      dot: '#FFB14D',
      description: 'Instantaneous arena-clearing shockwave explosion.',
      iconSvg: `<svg width="30" height="30" viewBox="0 0 30 30" fill="none" aria-hidden="true"><circle cx="15" cy="15" r="11" stroke="#FFB14D" stroke-width="1.4"></circle><path d="M15 7 L15 11 M9 20 L12 17 M21 20 L18 17" stroke="#FFB14D" stroke-width="2" stroke-linecap="round"></path><circle cx="15" cy="15" r="3" fill="#FFB14D"></circle></svg>`,
      tracks: [
        { key: 'radius', name: 'Blast Radius', effect: '+22 range / rank', maxRank: 5 },
        { key: 'speed', name: 'Shockwave Velocity', effect: '+25% / rank', maxRank: 5 }
      ],
      keystones: [
        { key: 'falloutZone', name: 'Fallout Zone', description: 'Detonation leaves a 3.0s radioactive burn zone.' },
        { key: 'chainReaction', name: 'Chain Reaction', description: 'Vaporized dots trigger miniature secondary bombs.' }
      ]
    },
    {
      id: 'freeze',
      name: 'Shockwave',
      dot: '#8FB0FF',
      description: 'Flash-freezes all dots into shatterable crystals.',
      iconSvg: `<svg width="30" height="30" viewBox="0 0 30 30" fill="none" aria-hidden="true"><circle cx="15" cy="15" r="11" stroke="#8FB0FF" stroke-width="1.4" stroke-dasharray="4,3"></circle><path d="M15 5 L15 25 M5 15 L25 15 M8 8 L22 22 M8 22 L22 8" stroke="#8FB0FF" stroke-width="1.3"></path></svg>`,
      tracks: [
        { key: 'duration', name: 'Freeze Duration', effect: '+0.7s / rank', maxRank: 5 }
      ],
      keystones: [
        { key: 'shatterCascade', name: 'Shatter Cascade', description: 'Shattering one enemy destroys nearby frozen dots.' },
        { key: 'cryoNova', name: 'Cryo Nova', description: 'Emits an expansive 360° cryogenic pulse ring.' }
      ]
    },
    {
      id: 'shield',
      name: 'Shield',
      dot: '#3DDC97',
      description: 'Kinetic barrier allowing safe ramming through enemies.',
      iconSvg: `<svg width="30" height="30" viewBox="0 0 30 30" fill="none" aria-hidden="true"><path d="M15 5 L23 8 V15 C23 20 15 25 15 25 C15 25 7 20 7 15 V8 Z" stroke="#3DDC97" stroke-width="1.4" fill="rgba(61,220,151,0.15)"></path></svg>`,
      tracks: [
        { key: 'duration', name: 'Shield Duration', effect: '+1.0s / rank', maxRank: 5 },
        { key: 'radius', name: 'Bubble Radius', effect: '+2 range / rank', maxRank: 5 }
      ],
      keystones: [
        { key: 'batteringRam', name: 'Battering Ram', description: 'Ramming enemies triggers kinetic shockwaves.' },
        { key: 'overchargePulse', name: 'Overcharge', description: 'Releases a blast pulse when barrier expires.' }
      ]
    },
    {
      id: 'lightning',
      name: 'Lightning',
      dot: '#FFB14D',
      description: 'Arcs jump between dots in high-voltage cascade.',
      iconSvg: `<svg width="30" height="30" viewBox="0 0 30 30" fill="none" aria-hidden="true"><path d="M17 4 L9 16 H16 L13 26 L23 13 H15 Z" stroke="#FFB14D" stroke-width="1.4" fill="rgba(255,177,77,0.2)"></path></svg>`,
      tracks: [
        { key: 'maxTargets', name: 'Arc Targets', effect: '+3 targets / rank', maxRank: 5 },
        { key: 'chainRange', name: 'Chain Distance', effect: '+22 range / rank', maxRank: 5 }
      ],
      keystones: [
        { key: 'plasmaArc', name: 'Arc Detonation', description: 'Chained enemies explode upon electrocution.' },
        { key: 'superconductor', name: 'Superconductor', description: 'Electric arcs bridge across screen instantly.' }
      ]
    }
  ];

  // Ship catalog `startingWeapon` values are the engine's WeaponType ids, which don't
  // all match a weaponsCatalog entry id 1:1 (e.g. the engine's 'vortex' is presented
  // to the player as 'Blackhole'). Map the mismatches here so the Armory never shows
  // a raw engine id or disagrees with the weapons tab's own naming.
  private readonly startingWeaponIdAliases: Partial<Record<WeaponType, WeaponConfig['id']>> = {
    vortex: 'blackhole'
  };

  /** Resolves a ship's optional startingWeapon to its weaponsCatalog entry, if any. */
  private getStartingWeaponConfig(weaponType?: WeaponType): WeaponConfig | undefined {
    if (!weaponType) {
      return undefined;
    }
    const catalogId = this.startingWeaponIdAliases[weaponType] ?? (weaponType as WeaponConfig['id']);
    return this.weaponsCatalog.find((w) => w.id === catalogId);
  }

  private readonly boostsCatalog: BoostConfig[] = [
    {
      id: 'extraLives',
      name: 'Extra Life',
      effect: '+1 starting life / rank',
      maxRank: 2,
      getRank: () => this.progression.data.extraLives,
      getCost: () => this.progression.getExtraLivesCost(),
      buy: () => this.progression.buyExtraLife()
    },
    {
      id: 'hullCompact',
      name: 'Hull Compact',
      effect: '-6% hitbox / rank',
      maxRank: 3,
      getRank: () => this.progression.data.hullCompact,
      getCost: () => this.progression.getHullCompactCost(),
      buy: () => this.progression.buyHullCompact()
    },
    {
      id: 'enemySlow',
      name: 'Enemy Slow',
      effect: '-4% enemy speed / rank',
      maxRank: 3,
      getRank: () => this.progression.data.enemySlow,
      getCost: () => this.progression.getEnemySlowCost(),
      buy: () => this.progression.buyEnemySlow()
    },
    {
      id: 'scoreMultiplier',
      name: 'Score Multiplier',
      effect: '+10% in-run score / rank',
      maxRank: 4,
      getRank: () => this.progression.data.scoreMultiplier,
      getCost: () => this.progression.getScoreMultiplierCost(),
      buy: () => this.progression.buyScoreMultiplier()
    },
    {
      id: 'pointsMultiplier',
      name: 'Points Multiplier',
      effect: '+10% points earned / rank',
      maxRank: 4,
      getRank: () => this.progression.data.pointsMultiplier,
      getCost: () => this.progression.getPointsMultiplierCost(),
      buy: () => this.progression.buyPointsMultiplier()
    }
  ];

  constructor(
    progression: ProgressionManager,
    onStateChanged: () => void,
    onCloseModal: () => void
  ) {
    this.progression = progression;
    this.onStateChanged = onStateChanged;
    this.onCloseModal = onCloseModal;

    this.initDOM();
  }

  private initDOM() {
    let modal = document.getElementById('tilt-armory-modal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'tilt-armory-modal';
      modal.className = 'game-overlay hidden tilt-armory-overlay';
      const stage = document.getElementById('tilt-stage') || document.body;
      stage.appendChild(modal);
    }
    this.containerEl = modal;
  }

  public open(tab?: ArmoryTab) {
    if (tab) {
      const map: Record<string, 'weapons' | 'ships' | 'arena' | 'handling' | 'boosts'> = {
        weapons: 'weapons',
        perks: 'weapons',
        ships: 'ships',
        cursors: 'ships',
        arena: 'arena',
        arenas: 'arena',
        enemies: 'arena',
        handling: 'handling',
        tuning: 'handling',
        boosts: 'boosts'
      };
      this.activeTab = map[tab] || 'weapons';
    }
    if (!this.containerEl) this.initDOM();
    if (this.containerEl) {
      this.containerEl.classList.remove('hidden');
      this.render();
    }
  }

  public close() {
    this.stopHandlingPreview();
    if (this.containerEl) {
      this.containerEl.classList.add('hidden');
    }
    this.onCloseModal();
  }

  public isOpen(): boolean {
    return !!this.containerEl && !this.containerEl.classList.contains('hidden');
  }

  public render() {
    if (!this.containerEl) return;

    this.stopHandlingPreview();

    // Preserve scroll position if re-rendering within the same tab
    const prevScrollEl = this.containerEl.querySelector('.armory-scroll-body');
    const prevScrollTop = prevScrollEl ? prevScrollEl.scrollTop : 0;

    const points = this.progression.data.points;

    this.containerEl.innerHTML = `
      <div class="tilt-armory-panel" role="dialog" aria-modal="true" aria-label="Tilt to Live Armory">
        <!-- Header (Board 09, 10, 11, 17) -->
        <header class="armory-v2-header">
          <button id="btn-armory-mobile-back" class="armory-mobile-back-btn" type="button" aria-label="Back">
            <svg width="15" height="15" viewBox="0 0 15 15" fill="none" aria-hidden="true">
              <path d="M9.5 2.5 L4.5 7.5 L9.5 12.5" stroke="#C7CDDB" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </button>
          
          <h2 class="armory-v2-title">Armory</h2>

          <nav class="armory-v2-tabs" aria-label="Armory categories">
            <button class="armory-v2-tab ${this.activeTab === 'weapons' ? 'active' : ''}" data-tab="weapons" type="button">Weapons</button>
            <button class="armory-v2-tab ${this.activeTab === 'ships' ? 'active' : ''}" data-tab="ships" type="button">Ships</button>
            <button class="armory-v2-tab ${this.activeTab === 'arena' ? 'active' : ''}" data-tab="arena" type="button">Arena</button>
            <button class="armory-v2-tab ${this.activeTab === 'handling' ? 'active' : ''}" data-tab="handling" type="button">Handling</button>
            <button class="armory-v2-tab ${this.activeTab === 'boosts' ? 'active' : ''}" data-tab="boosts" type="button">Boosts</button>
          </nav>

          <div class="armory-v2-header-right">
            <!-- Fixed tabular mono font, amber #FFB14D currency display (Findings 8 & 11) -->
            <span class="armory-v2-balance" title="Available Points">
              ${formatPoints(points)}
            </span>
            <button id="btn-armory-close" class="armory-v2-close-btn" type="button" aria-label="Close Armory">
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
                <path d="M2 2 L12 12 M12 2 L2 12" stroke="#99A1B3" stroke-width="1.5" stroke-linecap="round"/>
              </svg>
            </button>
          </div>
        </header>

        <!-- Main Content Area -->
        <div class="armory-v2-body">
          ${this.renderTabContent()}
        </div>

        <!-- Sticky Play Button on Mobile (Board 17) -->
        <div class="armory-mobile-sticky-footer">
          <button id="btn-armory-mobile-play" class="armory-mobile-play-btn" type="button">Play</button>
        </div>
      </div>
    `;

    this.bindEvents();

    if (this.activeTab === 'handling') {
      this.initHandlingPreview();
    }

    const newScrollEl = this.containerEl.querySelector('.armory-scroll-body');
    if (newScrollEl && prevScrollTop > 0) {
      newScrollEl.scrollTop = prevScrollTop;
    }
  }

  private renderTabContent(): string {
    switch (this.activeTab) {
      case 'weapons':
        return this.renderWeaponsTab();
      case 'ships':
        return this.renderShipsTab();
      case 'arena':
        return this.renderArenaTab();
      case 'handling':
        return this.renderHandlingTab();
      case 'boosts':
        return this.renderBoostsTab();
    }
  }

  // =========================================================================
  // Tab 1: Weapons (Board 09 & 17)
  // =========================================================================

  private renderWeaponsTab(): string {
    const perks = this.progression.data.perks;
    const points = this.progression.data.points;

    const selectedConfig =
      this.weaponsCatalog.find((w) => w.id === this.selectedWeaponId) ||
      this.weaponsCatalog[0];

    const investedPoints = this.progression.getWeaponInvestedPoints(selectedConfig.id);

    // Compute weapon ranks for list display
    const weaponItemsHtml = this.weaponsCatalog
      .map((w) => {
        const p = (perks as any)[w.id] || {};
        const primaryVal = typeof p.duration === 'number' ? p.duration : (p.count ?? p.radius ?? 0);
        const rankText = `${primaryVal}/5`;
        const isActive = w.id === selectedConfig.id;

        return `
          <div class="weapon-list-item ${isActive ? 'active' : ''}" data-weapon-id="${w.id}" role="button" tabindex="0">
            <span class="weapon-color-dot" style="background: ${w.dot};"></span>
            <span class="weapon-list-name">${w.name}</span>
            <span class="weapon-list-rank">${rankText}</span>
          </div>
        `;
      })
      .join('');

    // Render upgrade tracks with 5 discrete pips
    const weaponTracksHtml = selectedConfig.tracks
      .map((track) => {
        const weaponData = (perks as any)[selectedConfig.id] || {};
        const currentRank = typeof weaponData[track.key] === 'number' ? weaponData[track.key] : 0;
        const isMaxed = currentRank >= track.maxRank;
        const cost = this.progression.getPerkCost(currentRank, false);
        const canAfford = points >= cost && !isMaxed;

        let pipsHtml = '';
        for (let i = 0; i < 5; i++) {
          const filled = i < currentRank;
          pipsHtml += `<span class="track-pip ${filled ? 'filled' : 'empty'}"></span>`;
        }

        // Current (and, unless maxed, next-rank) value straight from WEAPON_TUNING,
        // so the readout can never drift from what the engine actually applies.
        const tuningEntry = WEAPON_TUNING[selectedConfig.id]?.[track.key];
        let currentValueHtml = '';
        if (tuningEntry) {
          const currentVal = getTunedValue(selectedConfig.id, track.key, currentRank);
          const currentText = formatTuningValue(currentVal, tuningEntry.unit);
          if (!isMaxed) {
            const nextVal = getTunedValue(selectedConfig.id, track.key, currentRank + 1);
            const nextText = formatTuningValue(nextVal, tuningEntry.unit);
            currentValueHtml = `<span class="track-current-value">${currentText} &rarr; ${nextText}</span>`;
          } else {
            currentValueHtml = `<span class="track-current-value">${currentText}</span>`;
          }
        }

        return `
          <div class="upgrade-track-card">
            <div class="track-info">
              <strong class="track-title">${track.name}</strong>
              <span class="track-effect">${track.effect}</span>
              ${currentValueHtml}
            </div>
            <div class="track-pips-bar">
              ${pipsHtml}
            </div>
            <span class="track-rank-num">${currentRank}/5</span>
            <button
              type="button"
              class="track-cost-btn ${isMaxed ? 'is-maxed' : ''}"
              data-weapon="${selectedConfig.id}"
              data-track="${track.key}"
              ${isMaxed || !canAfford ? 'disabled' : ''}
            >
              ${isMaxed ? 'Maxed ✓' : formatPoints(cost)}
            </button>
          </div>
        `;
      })
      .join('');

    // Render one-off unlocks (Aegis, Supernova, etc.)
    const weaponKeystonesHtml = selectedConfig.keystones
      .map((k) => {
        const weaponData = (perks as any)[selectedConfig.id] || {};
        const isUnlocked = !!weaponData[k.key];
        // KEYSTONE_COSTS is the same table ProgressionManager.getPerkCost() charges
        // from, so a displayed price can never undercharge the player again.
        const cost = KEYSTONE_COSTS[k.key] ?? 2500;
        const canAfford = points >= cost && !isUnlocked;

        return `
          <div class="keystone-card ${isUnlocked ? 'is-unlocked' : ''} ${!isUnlocked && !canAfford ? 'is-locked' : ''}">
            <div class="keystone-info">
              <strong class="keystone-title">${k.name}</strong>
              <span class="keystone-desc">${k.description}</span>
            </div>
            <button
              type="button"
              class="keystone-cost-btn ${isUnlocked ? 'is-unlocked' : ''}"
              data-weapon="${selectedConfig.id}"
              data-keystone="${k.key}"
              ${isUnlocked || !canAfford ? 'disabled' : ''}
            >
              ${isUnlocked ? 'Unlocked ✓' : formatPoints(cost)}
            </button>
          </div>
        `;
      })
      .join('');

    return `
      <div class="armory-weapons-layout">
        <!-- Left Column: Weapon List (Board 09) -->
        <aside class="armory-weapons-sidebar custom-scrollbar" aria-label="Weapons Selection">
          ${weaponItemsHtml}
        </aside>

        <!-- Right Panel: Weapon Details, Upgrades & Keystones (Board 09) -->
        <section class="armory-weapons-detail armory-scroll-body custom-scrollbar">
          <!-- Weapon Header -->
          <div class="weapon-detail-header">
            <div class="weapon-icon-box" style="background: ${selectedConfig.dot}18; border-color: ${selectedConfig.dot}55;">
              ${selectedConfig.iconSvg}
            </div>
            <div class="weapon-detail-title-group">
              <h3 class="weapon-detail-name">${selectedConfig.name}</h3>
              <p class="weapon-detail-desc">${selectedConfig.description}</p>
            </div>
            <div class="weapon-invested-badge">
              <span class="invested-label">Invested</span>
              <span class="invested-val">${investedPoints.toLocaleString()}</span>
            </div>
          </div>

          <!-- Upgrade Tracks -->
          <div class="upgrade-tracks-list">
            ${weaponTracksHtml}
          </div>

          <!-- One-off unlocks -->
          <div class="keystones-section">
            <span class="keystones-section-label">One-off unlocks</span>
            <div class="keystones-grid">
              ${weaponKeystonesHtml}
            </div>
          </div>
        </section>
      </div>
    `;
  }

  // =========================================================================
  // Tab 2: Ships (Board 10)
  // =========================================================================

  private renderShipsTab(): string {
    const points = this.progression.data.points;
    const equippedId = this.progression.data.equippedCursorId;
    const unlockedIds = this.progression.data.unlockedCursors;
    const ships = this.progression.shipCatalog;

    const unlockedCount = ships.filter((s) => unlockedIds.includes(s.id)).length;

    const shipsCardsHtml = ships
      .map((ship) => {
        const isUnlocked = unlockedIds.includes(ship.id);
        const isEquipped = equippedId === ship.id;
        const canAfford = points >= ship.price;

        let actionHtml = '';
        if (isEquipped) {
          actionHtml = `<button class="ship-action-btn is-equipped" disabled type="button">Equipped</button>`;
        } else if (isUnlocked) {
          actionHtml = `<button class="ship-action-btn is-equip equip-ship-btn" data-id="${ship.id}" type="button">Equip</button>`;
        } else {
          actionHtml = `
            <button
              class="ship-action-btn is-buy buy-ship-btn"
              data-id="${ship.id}"
              type="button"
              ${canAfford ? '' : 'disabled'}
            >
              ${formatPoints(ship.price)}
            </button>
          `;
        }

        const cardStateClass = isEquipped ? 'is-equipped-card' : isUnlocked ? 'is-unlocked-card' : 'is-locked-card';

        const startingWeaponConfig = this.getStartingWeaponConfig(ship.startingWeapon);
        const startingWeaponHtml = startingWeaponConfig
          ? `
              <div class="ship-loadout-row">
                <span class="ship-loadout-label">Starts with</span>
                <span class="ship-loadout-weapon">
                  <span class="ship-loadout-icon">${startingWeaponConfig.iconSvg}</span>
                  <span class="ship-loadout-name">${startingWeaponConfig.name}</span>
                </span>
              </div>
            `
          : '';

        return `
          <div class="ship-card ${cardStateClass}">
            <div class="ship-card-preview">
              ${this.progression.getShipSvgPreview(ship.id)}
            </div>
            <div class="ship-card-body">
              <div class="ship-header-row">
                <strong class="ship-name">${ship.name}</strong>
                <span class="ship-trait">${ship.trait}</span>
              </div>
              ${startingWeaponHtml}
              <div class="ship-action-slot">
                ${actionHtml}
              </div>
            </div>
          </div>
        `;
      })
      .join('');

    return `
      <div class="armory-ships-layout armory-scroll-body custom-scrollbar">
        <!-- Subheader (Board 10) -->
        <div class="armory-sub-header">
          <span class="sub-header-pill">Hull · ${unlockedCount} of 6 unlocked</span>
          <span class="sub-header-explain">Hull changes hitbox size, turn rate, and your starting power-up.</span>
        </div>

        <!-- 6 Ships Grid (Board 10) -->
        <div class="armory-ships-grid">
          ${shipsCardsHtml}
        </div>
      </div>
    `;
  }

  // =========================================================================
  // Tab 3: Arena (Arena Themes & Enemy Skins Folded)
  // =========================================================================

  private renderArenaTab(): string {
    const points = this.progression.data.points;

    // 1. Arena Themes
    const equippedThemeId = this.progression.data.equippedArenaThemeId;
    const unlockedThemes = this.progression.data.unlockedArenaThemes;
    const themes = this.progression.arenaThemeCatalog;
    const unlockedThemeCount = themes.filter((t) => unlockedThemes.includes(t.id)).length;

    const themesHtml = themes
      .map((theme) => {
        const isUnlocked = unlockedThemes.includes(theme.id);
        const isEquipped = equippedThemeId === theme.id;
        const canAfford = points >= theme.price;

        let btnHtml = '';
        if (isEquipped) {
          btnHtml = `<button class="arena-action-btn is-equipped" disabled type="button">Equipped</button>`;
        } else if (isUnlocked) {
          btnHtml = `<button class="arena-action-btn is-equip equip-arena-btn" data-id="${theme.id}" type="button">Equip</button>`;
        } else {
          btnHtml = `
            <button
              class="arena-action-btn is-buy buy-arena-btn"
              data-id="${theme.id}"
              type="button"
              ${canAfford ? '' : 'disabled'}
            >
              ${formatPoints(theme.price)}
            </button>
          `;
        }

        const [c1, c2, c3] = theme.bgGradient;

        return `
          <div class="arena-card ${isEquipped ? 'is-equipped-card' : ''}">
            <div class="arena-preview-box" style="
              background: radial-gradient(circle at center, ${c1} 0%, ${c2} 60%, ${c3} 100%);
              border-color: ${theme.boundaryColor};
            ">
              <div class="arena-grid-lines" style="--grid-color: ${theme.gridColor};"></div>
              <div class="arena-dust-dot" style="background: ${theme.dustColor};"></div>
            </div>
            <div class="arena-card-body">
              <div class="arena-card-header">
                <strong class="arena-card-title">${theme.name}</strong>
                <span class="arena-card-cost">${theme.price === 0 ? 'FREE' : formatPoints(theme.price)}</span>
              </div>
              <p class="arena-card-desc">${theme.description}</p>
              ${btnHtml}
            </div>
          </div>
        `;
      })
      .join('');

    // 2. Enemy Variations
    const equippedEnemyId = this.progression.data.equippedEnemySkinId;
    const unlockedEnemies = this.progression.data.unlockedEnemySkins;
    const enemies = this.progression.enemySkinCatalog;
    const unlockedEnemyCount = enemies.filter((e) => unlockedEnemies.includes(e.id)).length;

    const enemiesHtml = enemies
      .map((skin) => {
        const isUnlocked = unlockedEnemies.includes(skin.id);
        const isEquipped = equippedEnemyId === skin.id;
        const canAfford = points >= skin.price;

        let btnHtml = '';
        if (isEquipped) {
          btnHtml = `<button class="arena-action-btn is-equipped" disabled type="button">Equipped</button>`;
        } else if (isUnlocked) {
          btnHtml = `<button class="arena-action-btn is-equip equip-enemy-btn" data-id="${skin.id}" type="button">Equip</button>`;
        } else {
          btnHtml = `
            <button
              class="arena-action-btn is-buy buy-enemy-btn"
              data-id="${skin.id}"
              type="button"
              ${canAfford ? '' : 'disabled'}
            >
              ${formatPoints(skin.price)}
            </button>
          `;
        }

        const [inner, mid, outer] = skin.bodyGradient;

        return `
          <div class="arena-card ${isEquipped ? 'is-equipped-card' : ''}">
            <div class="enemy-preview-box">
              <div class="enemy-preview-dot" style="
                background: radial-gradient(circle, ${inner} 0%, ${mid} 60%, ${outer} 100%);
                border: 2px solid ${skin.borderColor};
              ">
                <span class="enemy-preview-pupil" style="background: ${skin.pupilColor};"></span>
              </div>
            </div>
            <div class="arena-card-body">
              <div class="arena-card-header">
                <strong class="arena-card-title">${skin.name}</strong>
                <span class="arena-card-cost">${skin.price === 0 ? 'FREE' : formatPoints(skin.price)}</span>
              </div>
              <p class="arena-card-desc">${skin.description}</p>
              ${btnHtml}
            </div>
          </div>
        `;
      })
      .join('');

    return `
      <div class="armory-arena-layout armory-scroll-body custom-scrollbar">
        <!-- Arena Themes Section -->
        <div class="arena-section-group">
          <div class="armory-sub-header">
            <span class="sub-header-pill">Arena Themes · ${unlockedThemeCount} of ${themes.length} unlocked</span>
            <span class="sub-header-explain">Changes the backdrop, boundary, and grid colors.</span>
          </div>
          <div class="arena-cards-grid">
            ${themesHtml}
          </div>
        </div>

        <!-- Enemy Variations Section -->
        <div class="arena-section-group" style="margin-top: 24px;">
          <div class="armory-sub-header">
            <span class="sub-header-pill">Enemy Variations · ${unlockedEnemyCount} of ${enemies.length} unlocked</span>
            <span class="sub-header-explain">Changes red swarm styling and particle effects.</span>
          </div>
          <div class="arena-cards-grid">
            ${enemiesHtml}
          </div>
        </div>
      </div>
    `;
  }

  // =========================================================================
  // Tab 4: Handling (Board 11) - Live Steering Tuning & Interactive Preview
  // =========================================================================

  private renderHandlingTab(): string {
    const tuning = this.progression.data.tuning;

    return `
      <div class="armory-handling-layout armory-scroll-body custom-scrollbar">
        <!-- Left Column: Controls (Board 11) -->
        <div class="handling-controls-column">
          <!-- Turn rate Slider -->
          <div class="handling-field-group">
            <div class="handling-field-header">
              <label for="h-turn" class="handling-label">Turn rate</label>
              <span id="disp-turn-rate" class="handling-value-pill">${tuning.sensitivity.toFixed(1)}×</span>
            </div>
            <span class="handling-hint">Higher turns sharper.</span>
            <input
              id="h-turn"
              class="handling-slider"
              type="range"
              min="0.5"
              max="2.0"
              step="0.1"
              value="${tuning.sensitivity}"
            />
            <div class="handling-boundary-row">
              <span>0.5×</span>
              <span>2.0×</span>
            </div>
          </div>

          <div class="handling-divider"></div>

          <!-- Deadzone Slider -->
          <div class="handling-field-group">
            <div class="handling-field-header">
              <label for="h-dead" class="handling-label">Deadzone</label>
              <span id="disp-deadzone" class="handling-value-pill">${tuning.deadzone}px</span>
            </div>
            <span class="handling-hint">Stops drift when you hold still.</span>
            <input
              id="h-dead"
              class="handling-slider"
              type="range"
              min="0"
              max="16"
              step="1"
              value="${tuning.deadzone}"
            />
            <div class="handling-boundary-row">
              <span>0px</span>
              <span>16px</span>
            </div>
          </div>

          <!-- Reset Button -->
          <button id="btn-handling-reset" type="button" class="handling-reset-btn">Reset</button>
        </div>

        <!-- Right Column: Interactive Live Preview (Board 11) -->
        <div class="handling-preview-column">
          <span class="handling-preview-label">Live preview — move the cursor</span>
          <div id="handling-live-box" class="handling-live-box">
            <canvas id="handling-preview-canvas" class="handling-preview-canvas"></canvas>
            
            <div class="handling-preview-legend">
              <span class="legend-item">
                <span class="legend-glyph legend-deadzone"></span>deadzone
              </span>
              <span class="legend-item">
                <span class="legend-glyph legend-speed"></span>top speed at
              </span>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  // =========================================================================
  // Tab 5: Boosts - permanent run-modifying purchases (extra life, hull,
  // enemy speed, score/points multipliers). These aren't weapon upgrades,
  // cosmetic hulls/skins, or control tuning, so they get their own tab
  // rather than being buried in one of the other four.
  // =========================================================================

  private renderBoostsTab(): string {
    const points = this.progression.data.points;

    const boostCardsHtml = this.boostsCatalog
      .map((boost) => {
        const currentRank = boost.getRank();
        const cost = boost.getCost();
        const isMaxed = cost === null;
        const canAfford = !isMaxed && points >= (cost as number);

        let pipsHtml = '';
        for (let i = 0; i < boost.maxRank; i++) {
          const filled = i < currentRank;
          pipsHtml += `<span class="boost-pip ${filled ? 'filled' : 'empty'}"></span>`;
        }

        return `
          <div class="boost-card">
            <strong class="boost-title">${boost.name}</strong>
            <span class="boost-effect">${boost.effect}</span>
            <div class="boost-pips">
              ${pipsHtml}
            </div>
            <span class="boost-rank">${currentRank}/${boost.maxRank}</span>
            <button
              type="button"
              class="boost-cost-btn ${isMaxed ? 'is-maxed' : ''}"
              data-boost="${boost.id}"
              ${isMaxed || !canAfford ? 'disabled' : ''}
            >
              ${isMaxed ? 'Maxed ✓' : formatPoints(cost as number)}
            </button>
          </div>
        `;
      })
      .join('');

    return `
      <div class="armory-boosts-layout armory-scroll-body custom-scrollbar">
        <div class="armory-sub-header">
          <span class="sub-header-pill">Boosts</span>
          <span class="sub-header-explain">Permanent, stacking upgrades that carry into every run.</span>
        </div>
        <div class="boost-grid">
          ${boostCardsHtml}
        </div>
      </div>
    `;
  }

  // =========================================================================
  // Interactive Live Preview Engine (Board 11)
  // =========================================================================

  private initHandlingPreview() {
    const box = this.containerEl?.querySelector('#handling-live-box') as HTMLElement;
    const canvas = this.containerEl?.querySelector('#handling-preview-canvas') as HTMLCanvasElement;
    if (!box || !canvas) return;

    this.previewCanvas = canvas;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const rect = box.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(280, rect.width) * dpr;
    canvas.height = Math.max(260, rect.height) * dpr;
    ctx.scale(dpr, dpr);

    const w = canvas.width / dpr;
    const h = canvas.height / dpr;

    if (!this.previewInitialized) {
      this.previewShip = {
        x: w / 2 + 45,
        y: h / 2 - 25,
        vx: 0,
        vy: 0,
        angle: -Math.PI / 4
      };
      this.previewMousePos = { x: w / 2 + 70, y: h / 2 - 35 };
      this.previewInitialized = true;
    }

    const onMove = (e: MouseEvent | TouchEvent) => {
      const bRect = box.getBoundingClientRect();
      const clientX = 'touches' in e ? e.touches[0].clientX : e.clientX;
      const clientY = 'touches' in e ? e.touches[0].clientY : e.clientY;
      this.previewMousePos.x = clientX - bRect.left;
      this.previewMousePos.y = clientY - bRect.top;
    };

    box.addEventListener('mousemove', onMove);
    box.addEventListener('touchmove', onMove, { passive: true });

    const step = () => {
      if (!this.previewCanvas || this.activeTab !== 'handling') return;

      const currentW = canvas.width / dpr;
      const currentH = canvas.height / dpr;
      const cx = currentW / 2;
      const cy = currentH / 2;

      ctx.clearRect(0, 0, currentW, currentH);

      // Subtle background grid
      ctx.strokeStyle = 'rgba(38, 44, 56, 0.4)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let x = 0; x < currentW; x += 40) {
        ctx.moveTo(x, 0);
        ctx.lineTo(x, currentH);
      }
      for (let y = 0; y < currentH; y += 40) {
        ctx.moveTo(0, y);
        ctx.lineTo(currentW, y);
      }
      ctx.stroke();

      const tuning = this.progression.data.tuning;
      const topSpeedRadius = 110;
      const deadzoneRadius = Math.max(4, tuning.deadzone * 3.5);

      // 1. Top speed dashed circle (#5B8CFF)
      ctx.save();
      ctx.strokeStyle = 'rgba(91, 140, 255, 0.32)';
      ctx.lineWidth = 1.2;
      ctx.setLineDash([4, 4]);
      ctx.beginPath();
      ctx.arc(cx, cy, topSpeedRadius, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();

      // 2. Deadzone solid circle (#FFB14D)
      ctx.save();
      ctx.strokeStyle = 'rgba(255, 177, 77, 0.75)';
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.arc(cx, cy, deadzoneRadius, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();

      // 3. Center origin dot (#FFB14D)
      ctx.fillStyle = '#FFB14D';
      ctx.beginPath();
      ctx.arc(cx, cy, 2.5, 0, Math.PI * 2);
      ctx.fill();

      // 4. Steer ship toward cursor with real turn rate & deadzone physics
      const ship = this.previewShip;
      const dx = this.previewMousePos.x - ship.x;
      const dy = this.previewMousePos.y - ship.y;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist > deadzoneRadius) {
        const dirX = dx / dist;
        const dirY = dy / dist;
        const speedFrac = Math.min(1.0, (dist - deadzoneRadius) / Math.max(20, topSpeedRadius - deadzoneRadius));
        const maxSpeed = 240 * tuning.sensitivity;
        const targetVx = dirX * maxSpeed * speedFrac;
        const targetVy = dirY * maxSpeed * speedFrac;

        ship.vx += (targetVx - ship.vx) * 0.14;
        ship.vy += (targetVy - ship.vy) * 0.14;
      } else {
        // Natural resting drag inside deadzone - eliminates drift
        ship.vx *= 0.84;
        ship.vy *= 0.84;
      }

      ship.x += ship.vx * (1 / 60);
      ship.y += ship.vy * (1 / 60);

      // Clamping within box
      ship.x = Math.max(16, Math.min(currentW - 16, ship.x));
      ship.y = Math.max(16, Math.min(currentH - 16, ship.y));

      // Angular lerp tuned by turn rate
      const currentSpeed = Math.sqrt(ship.vx * ship.vx + ship.vy * ship.vy);
      let targetAngle = ship.angle;
      if (currentSpeed > 8) {
        targetAngle = Math.atan2(ship.vy, ship.vx);
      } else if (dist > deadzoneRadius) {
        targetAngle = Math.atan2(dy, dx);
      }

      let diff = targetAngle - ship.angle;
      while (diff < -Math.PI) diff += Math.PI * 2;
      while (diff > Math.PI) diff -= Math.PI * 2;
      ship.angle += diff * Math.min(1.0, (1 / 60) * 16 * tuning.sensitivity);

      // 5. Draw Player Ship vector silhouette matching equipped ship
      const equippedShip = this.progression.getEquippedShip();
      ctx.save();
      ctx.translate(ship.x, ship.y);
      ctx.rotate(ship.angle);
      ctx.shadowColor = equippedShip.tint;
      ctx.shadowBlur = 14;
      ctx.translate(-24, -24);
      const shipPath = new Path2D(equippedShip.svgPath);
      ctx.fillStyle = equippedShip.tint;
      ctx.fill(shipPath);
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 1.4;
      ctx.stroke(shipPath);
      ctx.restore();

      // 6. Draw subtle mouse reticle dot
      ctx.fillStyle = 'rgba(91, 140, 255, 0.6)';
      ctx.beginPath();
      ctx.arc(this.previewMousePos.x, this.previewMousePos.y, 3, 0, Math.PI * 2);
      ctx.fill();

      this.previewRafId = requestAnimationFrame(step);
    };

    this.previewRafId = requestAnimationFrame(step);
  }

  private stopHandlingPreview() {
    if (this.previewRafId !== null) {
      cancelAnimationFrame(this.previewRafId);
      this.previewRafId = null;
    }
  }

  // =========================================================================
  // DOM Event Bindings
  // =========================================================================

  private bindEvents() {
    if (!this.containerEl) return;

    // 1. Close buttons (desktop SVG close & mobile back button)
    this.containerEl.querySelector('#btn-armory-close')?.addEventListener('click', () => {
      this.close();
    });
    this.containerEl.querySelector('#btn-armory-mobile-back')?.addEventListener('click', () => {
      this.close();
    });
    this.containerEl.querySelector('#btn-armory-mobile-play')?.addEventListener('click', () => {
      this.close();
    });

    // 2. Navigation Tabs
    this.containerEl.querySelectorAll('.armory-v2-tab').forEach((tabBtn) => {
      tabBtn.addEventListener('click', (e) => {
        const tab = (e.currentTarget as HTMLElement).getAttribute('data-tab') as any;
        if (tab && tab !== this.activeTab) {
          this.activeTab = tab;
          this.render();
        }
      });
    });

    // 3. Weapons Tab: Select active weapon in sidebar
    this.containerEl.querySelectorAll('.weapon-list-item').forEach((item) => {
      item.addEventListener('click', (e) => {
        const id = (e.currentTarget as HTMLElement).getAttribute('data-weapon-id') as keyof WeaponPerks;
        if (id && id !== this.selectedWeaponId) {
          this.selectedWeaponId = id;
          this.render();
        }
      });
    });

    // 4. Weapons Tab: Upgrade tracks
    this.containerEl.querySelectorAll('.track-cost-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const target = e.currentTarget as HTMLElement;
        const weapon = target.getAttribute('data-weapon') as keyof WeaponPerks;
        const track = target.getAttribute('data-track') as string;
        if (weapon && track) {
          if (this.progression.upgradePerk(weapon, track)) {
            this.onStateChanged();
            this.render();
          }
        }
      });
    });

    // 5. Weapons Tab: One-off unlocks (Keystones)
    this.containerEl.querySelectorAll('.keystone-cost-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const target = e.currentTarget as HTMLElement;
        const weapon = target.getAttribute('data-weapon') as keyof WeaponPerks;
        const keystone = target.getAttribute('data-keystone') as string;
        if (weapon && keystone) {
          if (this.progression.upgradePerk(weapon, keystone)) {
            this.onStateChanged();
            this.render();
          }
        }
      });
    });

    // 5b. Boosts Tab: Purchase a rank
    this.containerEl.querySelectorAll('.boost-cost-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const target = e.currentTarget as HTMLElement;
        const boostId = target.getAttribute('data-boost');
        const boost = this.boostsCatalog.find((b) => b.id === boostId);
        if (boost && boost.buy()) {
          this.onStateChanged();
          this.render();
        }
      });
    });

    // 6. Ships Tab: Equip & Buy
    this.containerEl.querySelectorAll('.buy-ship-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const id = (e.currentTarget as HTMLElement).getAttribute('data-id');
        if (id && this.progression.buyShip(id)) {
          this.onStateChanged();
          this.render();
        }
      });
    });

    this.containerEl.querySelectorAll('.equip-ship-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const id = (e.currentTarget as HTMLElement).getAttribute('data-id');
        if (id && this.progression.equipShip(id)) {
          this.onStateChanged();
          this.render();
        }
      });
    });

    // 7. Arena Tab: Themes Buy & Equip
    this.containerEl.querySelectorAll('.buy-arena-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const id = (e.currentTarget as HTMLElement).getAttribute('data-id');
        if (id && this.progression.buyArenaTheme(id)) {
          this.onStateChanged();
          this.render();
        }
      });
    });

    this.containerEl.querySelectorAll('.equip-arena-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const id = (e.currentTarget as HTMLElement).getAttribute('data-id');
        if (id && this.progression.equipArenaTheme(id)) {
          this.onStateChanged();
          this.render();
        }
      });
    });

    // 8. Arena Tab: Enemy Skins Buy & Equip
    this.containerEl.querySelectorAll('.buy-enemy-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const id = (e.currentTarget as HTMLElement).getAttribute('data-id');
        if (id && this.progression.buyEnemySkin(id)) {
          this.onStateChanged();
          this.render();
        }
      });
    });

    this.containerEl.querySelectorAll('.equip-enemy-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const id = (e.currentTarget as HTMLElement).getAttribute('data-id');
        if (id && this.progression.equipEnemySkin(id)) {
          this.onStateChanged();
          this.render();
        }
      });
    });

    // 9. Handling Tab: Turn rate slider
    const turnInput = this.containerEl.querySelector('#h-turn') as HTMLInputElement;
    if (turnInput) {
      turnInput.addEventListener('input', (e) => {
        const val = parseFloat((e.target as HTMLInputElement).value);
        this.progression.setSensitivity(val);
        const disp = this.containerEl?.querySelector('#disp-turn-rate');
        if (disp) disp.textContent = `${val.toFixed(1)}×`;
        this.onStateChanged();
      });
    }

    // 10. Handling Tab: Deadzone slider
    const deadzoneInput = this.containerEl.querySelector('#h-dead') as HTMLInputElement;
    if (deadzoneInput) {
      deadzoneInput.addEventListener('input', (e) => {
        const val = parseInt((e.target as HTMLInputElement).value, 10);
        this.progression.setDeadzone(val);
        const disp = this.containerEl?.querySelector('#disp-deadzone');
        if (disp) disp.textContent = `${val}px`;
        this.onStateChanged();
      });
    }

    // 11. Handling Tab: Reset button (defaults to 1.0x turn rate, 4px deadzone)
    this.containerEl.querySelector('#btn-handling-reset')?.addEventListener('click', () => {
      this.progression.setSensitivity(1.0);
      this.progression.setDeadzone(4);
      this.onStateChanged();
      this.render();
    });
  }
}
