// =========================================================================
// ArmoryUI.ts - In-Game Shop, Upgrades, Cosmetics & Control Tuning Modal
// =========================================================================

import { ProgressionManager, WeaponPerks } from './ProgressionManager';

export class ArmoryUI {
  private readonly progression: ProgressionManager;
  private readonly onStateChanged: () => void;
  private readonly onCloseModal: () => void;

  private containerEl: HTMLElement | null = null;
  private activeTab: 'perks' | 'cursors' | 'enemies' | 'arenas' | 'tuning' = 'perks';
  private activeWeaponCategory: 'all' | 'vortex' | 'nuke' | 'laser' | 'missiles' | 'shield' | 'lightning' | 'freeze' = 'all';

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

  public open(defaultTab?: 'perks' | 'cursors' | 'enemies' | 'arenas' | 'tuning') {
    if (defaultTab) this.activeTab = defaultTab;
    if (!this.containerEl) this.initDOM();
    if (this.containerEl) {
      this.containerEl.classList.remove('hidden');
      this.render();
    }
  }

  public close() {
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

    // Save previous scroll position so purchasing upgrades never bounces to top
    const prevContent = this.containerEl.querySelector('.armory-content');
    const prevScrollTop = prevContent ? prevContent.scrollTop : 0;

    const points = this.progression.data.points;

    this.containerEl.innerHTML = `
      <div class="overlay-panel tilt-armory-panel" role="dialog" aria-modal="true" aria-label="Tilt to Live Armory">
        <!-- Header -->
        <div class="armory-header">
          <div class="armory-title-group">
            <p class="eyebrow">TILT TO LIVE // THE VAULT</p>
            <h2>Armory & Upgrades</h2>
          </div>
          <div class="armory-header-right">
            <div class="armory-points-pill" title="Current Points Balance">
              <span class="coin-glyph">◈</span>
              <strong id="armory-points-val">${points.toLocaleString()}</strong>
              <small>PTS</small>
            </div>
            <button id="btn-armory-close" class="armory-close-btn" type="button" aria-label="Close Armory">✕</button>
          </div>
        </div>

        <!-- Navigation Tabs -->
        <nav class="armory-tabs" aria-label="Armory categories">
          <button class="armory-tab-btn ${this.activeTab === 'perks' ? 'active' : ''}" data-tab="perks" type="button">
            ⚡ Weapon Perks
          </button>
          <button class="armory-tab-btn ${this.activeTab === 'cursors' ? 'active' : ''}" data-tab="cursors" type="button">
            🚀 Ship Models
          </button>
          <button class="armory-tab-btn ${this.activeTab === 'enemies' ? 'active' : ''}" data-tab="enemies" type="button">
            👾 Enemy Skins
          </button>
          <button class="armory-tab-btn ${this.activeTab === 'arenas' ? 'active' : ''}" data-tab="arenas" type="button">
            🌌 Arena Themes
          </button>
          <button class="armory-tab-btn ${this.activeTab === 'tuning' ? 'active' : ''}" data-tab="tuning" type="button">
            ⚙️ Controls & Speed
          </button>
        </nav>

        <!-- Content Area -->
        <div class="armory-content custom-scrollbar">
          ${this.renderTabContent()}
        </div>
      </div>
    `;

    this.bindEvents();

    // Restore scroll position after re-render
    const newContent = this.containerEl.querySelector('.armory-content');
    if (newContent && prevScrollTop > 0) {
      newContent.scrollTop = prevScrollTop;
    }
  }

  private renderTabContent(): string {
    switch (this.activeTab) {
      case 'perks':
        return this.renderPerksTab();
      case 'cursors':
        return this.renderCursorsTab();
      case 'enemies':
        return this.renderEnemiesTab();
      case 'arenas':
        return this.renderArenasTab();
      case 'tuning':
        return this.renderTuningTab();
    }
  }

  // =========================================================================
  // Perks Tab Rendering
  // =========================================================================

  private renderPerksTab(): string {
    const perks = this.progression.data.perks;
    const points = this.progression.data.points;

    const renderRankPips = (current: number, max: number = 5) => {
      let pips = '';
      for (let i = 0; i < max; i++) {
        pips += `<span class="pip ${i < current ? 'filled' : ''}"></span>`;
      }
      return `<div class="rank-pips">${pips}</div>`;
    };

    const renderUpgradeBtn = (weapon: keyof WeaponPerks, perk: string, currentVal: number | boolean, maxRank: number = 5) => {
      if (typeof currentVal === 'boolean') {
        if (currentVal) {
          return `<button class="armory-btn equipped" disabled>Unlocked ✓</button>`;
        }
        const cost = this.progression.getPerkCost(0, true);
        const canAfford = points >= cost;
        const ptsSuffix = cost === 1 ? 'PT' : 'PTS';
        return `
          <button class="armory-btn upgrade-perk-btn" data-weapon="${weapon}" data-perk="${perk}" ${canAfford ? '' : 'disabled'}>
            Unlock ◈ ${cost} ${ptsSuffix}
          </button>
        `;
      } else {
        if (currentVal >= maxRank) {
          return `<button class="armory-btn equipped" disabled>Maxed ✓</button>`;
        }
        const cost = this.progression.getPerkCost(currentVal, false);
        const canAfford = points >= cost;
        const ptsSuffix = cost === 1 ? 'PT' : 'PTS';
        return `
          <button class="armory-btn upgrade-perk-btn" data-weapon="${weapon}" data-perk="${perk}" ${canAfford ? '' : 'disabled'}>
            Rank ${currentVal + 1} • ◈ ${cost} ${ptsSuffix}
          </button>
        `;
      }
    };

    const cat = this.activeWeaponCategory;
    const showAll = cat === 'all';

    return `
      <!-- Weapon Categories Sub-Nav -->
      <div class="weapons-category-filter-bar" role="tablist" aria-label="Weapon Categories">
        <button class="weapon-filter-chip ${cat === 'all' ? 'active' : ''}" data-filter="all" type="button">All Weapons (7)</button>
        <button class="weapon-filter-chip ${cat === 'vortex' ? 'active' : ''}" data-filter="vortex" type="button">🌀 Vortex</button>
        <button class="weapon-filter-chip ${cat === 'nuke' ? 'active' : ''}" data-filter="nuke" type="button">💣 Nuke</button>
        <button class="weapon-filter-chip ${cat === 'laser' ? 'active' : ''}" data-filter="laser" type="button">⚡ Laser</button>
        <button class="weapon-filter-chip ${cat === 'missiles' ? 'active' : ''}" data-filter="missiles" type="button">🚀 Missiles</button>
        <button class="weapon-filter-chip ${cat === 'shield' ? 'active' : ''}" data-filter="shield" type="button">🛡️ Shield</button>
        <button class="weapon-filter-chip ${cat === 'lightning' ? 'active' : ''}" data-filter="lightning" type="button">🌩️ Lightning</button>
        <button class="weapon-filter-chip ${cat === 'freeze' ? 'active' : ''}" data-filter="freeze" type="button">❄️ Freeze</button>
      </div>

      <div class="perks-grid">
        <!-- BLACKHOLE / VORTEX -->
        ${(showAll || cat === 'vortex') ? `
        <div class="perk-card perk-card-vortex">
          <div class="perk-card-header">
            <span class="perk-badge" style="background: rgba(180, 70, 255, 0.2); border-color: #b446ff; color: #d896ff;">VORTEX</span>
            <h3>Singularity Blackhole</h3>
          </div>
          <p class="perk-desc">Spawn gravity wells that suck red dot swarms into event horizons and implode.</p>

          <div class="perk-rows">
            <div class="perk-row">
              <div class="perk-meta">
                <strong>Duration</strong>
                <span>+0.5s active pull per rank (up to +2.5s)</span>
                ${renderRankPips(perks.blackhole.duration, 5)}
              </div>
              ${renderUpgradeBtn('blackhole', 'duration', perks.blackhole.duration, 5)}
            </div>

            <div class="perk-row">
              <div class="perk-meta">
                <strong>Event Horizon Radius</strong>
                <span>+35px gravitational capture range per rank</span>
                ${renderRankPips(perks.blackhole.radius, 5)}
              </div>
              ${renderUpgradeBtn('blackhole', 'radius', perks.blackhole.radius, 5)}
            </div>

            <div class="perk-row">
              <div class="perk-meta">
                <strong>Gravitational Force</strong>
                <span>+20% pull acceleration towards center per rank</span>
                ${renderRankPips(perks.blackhole.gravity, 5)}
              </div>
              ${renderUpgradeBtn('blackhole', 'gravity', perks.blackhole.gravity, 5)}
            </div>

            <div class="perk-row keystone-row">
              <div class="perk-meta">
                <strong class="keystone-title">★ Event Horizon Aegis (Invulnerability)</strong>
                <span>Your ship gains total invulnerability while inside the blackhole!</span>
              </div>
              ${renderUpgradeBtn('blackhole', 'invulnerableInside', perks.blackhole.invulnerableInside)}
            </div>

            <div class="perk-row keystone-row">
              <div class="perk-meta">
                <strong class="keystone-title">★ Supernova Collapse</strong>
                <span>Vortex collapse produces a devastating 420px shockwave!</span>
              </div>
              ${renderUpgradeBtn('blackhole', 'supernovaCollapse', perks.blackhole.supernovaCollapse)}
            </div>
          </div>
        </div>
        ` : ''}

        <!-- NUKE -->
        ${(showAll || cat === 'nuke') ? `
        <div class="perk-card perk-card-nuke">
          <div class="perk-card-header">
            <span class="perk-badge" style="background: rgba(255, 60, 40, 0.2); border-color: #ff3c28; color: #ff8577;">EXPLOSIVE</span>
            <h3>Thermonuclear Warhead</h3>
          </div>
          <p class="perk-desc">Devastating screen-clearing explosion that vaporizes any red dot in range.</p>

          <div class="perk-rows">
            <div class="perk-row">
              <div class="perk-meta">
                <strong>Blast Radius</strong>
                <span>+40px blast radius per rank (up to 500px screen coverage)</span>
                ${renderRankPips(perks.nuke.radius, 5)}
              </div>
              ${renderUpgradeBtn('nuke', 'radius', perks.nuke.radius, 5)}
            </div>

            <div class="perk-row">
              <div class="perk-meta">
                <strong>Shockwave Velocity</strong>
                <span>+25% wave expansion speed per rank</span>
                ${renderRankPips(perks.nuke.speed, 3)}
              </div>
              ${renderUpgradeBtn('nuke', 'speed', perks.nuke.speed, 3)}
            </div>

            <div class="perk-row keystone-row">
              <div class="perk-meta">
                <strong class="keystone-title">★ Lingering Radiation Cloud</strong>
                <span>Detonation leaves a 3.0-second radioactive zone that burns incoming enemies!</span>
              </div>
              ${renderUpgradeBtn('nuke', 'falloutZone', perks.nuke.falloutZone)}
            </div>
          </div>
        </div>
        ` : ''}

        <!-- LASER -->
        ${(showAll || cat === 'laser') ? `
        <div class="perk-card perk-card-laser">
          <div class="perk-card-header">
            <span class="perk-badge" style="background: rgba(0, 240, 255, 0.2); border-color: #00f0ff; color: #85f8ff;">BEAM</span>
            <h3>Photon Beam Lance</h3>
          </div>
          <p class="perk-desc">Concentrated directional beam cutting through swarms with piercing energy.</p>

          <div class="perk-rows">
            <div class="perk-row">
              <div class="perk-meta">
                <strong>Beam Length</strong>
                <span>+35px length per rank (up to 495px reach)</span>
                ${renderRankPips(perks.laser.length, 5)}
              </div>
              ${renderUpgradeBtn('laser', 'length', perks.laser.length, 5)}
            </div>

            <div class="perk-row">
              <div class="perk-meta">
                <strong>Beam Duration</strong>
                <span>+0.4s beam emission duration per rank</span>
                ${renderRankPips(perks.laser.duration, 3)}
              </div>
              ${renderUpgradeBtn('laser', 'duration', perks.laser.duration, 3)}
            </div>

            <div class="perk-row keystone-row">
              <div class="perk-meta">
                <strong class="keystone-title">★ Perpendicular Cross Beam</strong>
                <span>Splits your laser into a 4-way perpendicular cross that sweeps the arena!</span>
              </div>
              ${renderUpgradeBtn('laser', 'crossBeam', perks.laser.crossBeam)}
            </div>
          </div>
        </div>
        ` : ''}

        <!-- MISSILES -->
        ${(showAll || cat === 'missiles') ? `
        <div class="perk-card perk-card-missiles">
          <div class="perk-card-header">
            <span class="perk-badge" style="background: rgba(255, 170, 0, 0.2); border-color: #ffaa00; color: #ffd277;">ORDNANCE</span>
            <h3>Cluster Homing Missiles</h3>
          </div>
          <p class="perk-desc">Multi-target heat-seeking warheads tracking and eradicating targets.</p>

          <div class="perk-rows">
            <div class="perk-row">
              <div class="perk-meta">
                <strong>Missile Count</strong>
                <span>+1 missile per rank (fires up to 13 simultaneous warheads!)</span>
                ${renderRankPips(perks.missiles.count, 5)}
              </div>
              ${renderUpgradeBtn('missiles', 'count', perks.missiles.count, 5)}
            </div>

            <div class="perk-row">
              <div class="perk-meta">
                <strong>Detonation Radius</strong>
                <span>+12px explosion AOE per rank</span>
                ${renderRankPips(perks.missiles.blastRadius, 3)}
              </div>
              ${renderUpgradeBtn('missiles', 'blastRadius', perks.missiles.blastRadius, 3)}
            </div>

            <div class="perk-row">
              <div class="perk-meta">
                <strong>Propulsion & Agility</strong>
                <span>+20% flight speed and tighter turning circles</span>
                ${renderRankPips(perks.missiles.flightSpeed, 3)}
              </div>
              ${renderUpgradeBtn('missiles', 'flightSpeed', perks.missiles.flightSpeed, 3)}
            </div>
          </div>
        </div>
        ` : ''}

        <!-- SHIELD -->
        ${(showAll || cat === 'shield') ? `
        <div class="perk-card perk-card-shield">
          <div class="perk-card-header">
            <span class="perk-badge" style="background: rgba(0, 255, 170, 0.2); border-color: #00ffaa; color: #85ffd2;">DEFENSE</span>
            <h3>Kinetic Aegis Shield</h3>
          </div>
          <p class="perk-desc">Invulnerability bubble allowing you to charge and ram directly into enemies.</p>

          <div class="perk-rows">
            <div class="perk-row">
              <div class="perk-meta">
                <strong>Duration</strong>
                <span>+1.0s shield active time per rank (up to 10 seconds total)</span>
                ${renderRankPips(perks.shield.duration, 5)}
              </div>
              ${renderUpgradeBtn('shield', 'duration', perks.shield.duration, 5)}
            </div>

            <div class="perk-row">
              <div class="perk-meta">
                <strong>Bubble Radius</strong>
                <span>+4px protective radius per rank</span>
                ${renderRankPips(perks.shield.radius, 3)}
              </div>
              ${renderUpgradeBtn('shield', 'radius', perks.shield.radius, 3)}
            </div>

            <div class="perk-row keystone-row">
              <div class="perk-meta">
                <strong class="keystone-title">★ Battering Ram</strong>
                <span>Ramming an enemy triggers a kinetic explosion vaporizing nearby dots!</span>
              </div>
              ${renderUpgradeBtn('shield', 'batteringRam', perks.shield.batteringRam)}
            </div>
          </div>
        </div>
        ` : ''}

        <!-- LIGHTNING -->
        ${(showAll || cat === 'lightning') ? `
        <div class="perk-card perk-card-lightning">
          <div class="perk-card-header">
            <span class="perk-badge" style="background: rgba(255, 230, 0, 0.2); border-color: #ffe600; color: #fff380;">ELECTRIC</span>
            <h3>Tesla Arc Lightning</h3>
          </div>
          <p class="perk-desc">Discharges high-voltage branching arcs that jump between clustered foes.</p>

          <div class="perk-rows">
            <div class="perk-row">
              <div class="perk-meta">
                <strong>Max Chain Targets</strong>
                <span>+3 enemies per rank (up to 33 chain electrocutions!)</span>
                ${renderRankPips(perks.lightning.maxTargets, 5)}
              </div>
              ${renderUpgradeBtn('lightning', 'maxTargets', perks.lightning.maxTargets, 5)}
            </div>

            <div class="perk-row">
              <div class="perk-meta">
                <strong>Arc Leap Distance</strong>
                <span>+40px lightning jump range per rank</span>
                ${renderRankPips(perks.lightning.chainRange, 3)}
              </div>
              ${renderUpgradeBtn('lightning', 'chainRange', perks.lightning.chainRange, 3)}
            </div>
          </div>
        </div>
        ` : ''}

        <!-- FREEZE -->
        ${(showAll || cat === 'freeze') ? `
        <div class="perk-card perk-card-freeze">
          <div class="perk-card-header">
            <span class="perk-badge" style="background: rgba(120, 200, 255, 0.2); border-color: #78c8ff; color: #b8e2ff;">CRYOGENIC</span>
            <h3>Absolute Zero Freeze</h3>
          </div>
          <p class="perk-desc">Freezes all active enemies solid into fragile ice orbs ready to be shattered.</p>

          <div class="perk-rows">
            <div class="perk-row">
              <div class="perk-meta">
                <strong>Freeze Duration</strong>
                <span>+0.7s immobilization time per rank (up to 7.5s)</span>
                ${renderRankPips(perks.freeze.duration, 5)}
              </div>
              ${renderUpgradeBtn('freeze', 'duration', perks.freeze.duration, 5)}
            </div>

            <div class="perk-row keystone-row">
              <div class="perk-meta">
                <strong class="keystone-title">★ Shatter Cascade</strong>
                <span>Shattering a frozen enemy unleashes ice shards that shatter adjacent enemies!</span>
              </div>
              ${renderUpgradeBtn('freeze', 'shatterCascade', perks.freeze.shatterCascade)}
            </div>
          </div>
        </div>
        ` : ''}
      </div>
    `;
  }

  // =========================================================================
  // Cursors Tab Rendering
  // =========================================================================

  private renderCursorsTab(): string {
    const points = this.progression.data.points;
    const equippedId = this.progression.data.equippedCursorId;
    const unlocked = this.progression.data.unlockedCursors;

    return `
      <div class="catalog-grid">
        ${this.progression.shipCatalog.map((ship) => {
          const isUnlocked = unlocked.includes(ship.id);
          const isEquipped = equippedId === ship.id;
          const canAfford = points >= ship.price;

          let btnHtml = '';
          if (isEquipped) {
            btnHtml = `<button class="armory-btn equipped" disabled>Piloting ✓</button>`;
          } else if (isUnlocked) {
            btnHtml = `<button class="armory-btn equip-cursor-btn" data-id="${ship.id}">Pilot Ship</button>`;
          } else {
            btnHtml = `
              <button class="armory-btn buy-cursor-btn" data-id="${ship.id}" ${canAfford ? '' : 'disabled'}>
                Unlock ◈ ${ship.price.toLocaleString()}
              </button>
            `;
          }

          return `
            <div class="catalog-card ${isEquipped ? 'is-active-card' : ''}">
              <div class="catalog-preview-box ship-preview-box">
                ${this.progression.getShipSvgPreview(ship.id)}
              </div>
              <div class="catalog-card-body">
                <div class="catalog-card-header">
                  <h4>${ship.name}</h4>
                  <span class="item-cost">${ship.price === 0 ? 'FREE' : `◈ ${ship.price.toLocaleString()}`}</span>
                </div>
                <p class="catalog-desc">${ship.description}</p>
                <div class="catalog-action">
                  ${btnHtml}
                </div>
              </div>
            </div>
          `;
        }).join('')}
      </div>
    `;
  }

  // =========================================================================
  // Enemy Skins Tab Rendering
  // =========================================================================

  private renderEnemiesTab(): string {
    const points = this.progression.data.points;
    const equippedId = this.progression.data.equippedEnemySkinId;
    const unlocked = this.progression.data.unlockedEnemySkins;

    return `
      <div class="catalog-grid">
        ${this.progression.enemySkinCatalog.map((skin) => {
          const isUnlocked = unlocked.includes(skin.id);
          const isEquipped = equippedId === skin.id;
          const canAfford = points >= skin.price;

          let btnHtml = '';
          if (isEquipped) {
            btnHtml = `<button class="armory-btn equipped" disabled>Equipped ✓</button>`;
          } else if (isUnlocked) {
            btnHtml = `<button class="armory-btn equip-enemy-btn" data-id="${skin.id}">Equip</button>`;
          } else {
            btnHtml = `
              <button class="armory-btn buy-enemy-btn" data-id="${skin.id}" ${canAfford ? '' : 'disabled'}>
                Unlock ◈ ${skin.price.toLocaleString()}
              </button>
            `;
          }

          const [inner, mid, outer] = skin.bodyGradient;

          return `
            <div class="catalog-card ${isEquipped ? 'is-active-card' : ''}">
              <div class="catalog-preview-box">
                <div class="enemy-preview-glyph" style="
                  background: radial-gradient(circle, ${inner} 0%, ${mid} 60%, ${outer} 100%);
                  box-shadow: 0 0 16px ${skin.glowColor};
                  border: 2px solid ${skin.borderColor};
                ">
                  <span class="enemy-preview-pupil" style="background: ${skin.pupilColor};"></span>
                </div>
              </div>
              <div class="catalog-card-body">
                <div class="catalog-card-header">
                  <h4>${skin.name}</h4>
                  <span class="item-cost">${skin.price === 0 ? 'FREE' : `◈ ${skin.price.toLocaleString()}`}</span>
                </div>
                <p class="catalog-desc">${skin.description}</p>
                <div class="catalog-action">
                  ${btnHtml}
                </div>
              </div>
            </div>
          `;
        }).join('')}
      </div>
    `;
  }

  // =========================================================================
  // Arena Themes Tab Rendering
  // =========================================================================

  private renderArenasTab(): string {
    const points = this.progression.data.points;
    const equippedId = this.progression.data.equippedArenaThemeId;
    const unlocked = this.progression.data.unlockedArenaThemes;

    return `
      <div class="catalog-grid">
        ${this.progression.arenaThemeCatalog.map((arena) => {
          const isUnlocked = unlocked.includes(arena.id);
          const isEquipped = equippedId === arena.id;
          const canAfford = points >= arena.price;

          let btnHtml = '';
          if (isEquipped) {
            btnHtml = `<button class="armory-btn equipped" disabled>Equipped ✓</button>`;
          } else if (isUnlocked) {
            btnHtml = `<button class="armory-btn equip-arena-btn" data-id="${arena.id}">Equip</button>`;
          } else {
            btnHtml = `
              <button class="armory-btn buy-arena-btn" data-id="${arena.id}" ${canAfford ? '' : 'disabled'}>
                Unlock ◈ ${arena.price.toLocaleString()}
              </button>
            `;
          }

          const [c1, c2, c3] = arena.bgGradient;

          return `
            <div class="catalog-card ${isEquipped ? 'is-active-card' : ''}">
              <div class="catalog-preview-box arena-preview-box" style="
                background: radial-gradient(circle, ${c1} 0%, ${c2} 55%, ${c3} 100%);
                border: 1px solid ${arena.boundaryColor};
              ">
                <div class="arena-grid-mockup" style="--grid-line: ${arena.gridColor};"></div>
                <div class="arena-dust-mockup" style="background: ${arena.dustColor};"></div>
              </div>
              <div class="catalog-card-body">
                <div class="catalog-card-header">
                  <h4>${arena.name}</h4>
                  <span class="item-cost">${arena.price === 0 ? 'FREE' : `◈ ${arena.price.toLocaleString()}`}</span>
                </div>
                <p class="catalog-desc">${arena.description}</p>
                <div class="catalog-action">
                  ${btnHtml}
                </div>
              </div>
            </div>
          `;
        }).join('')}
      </div>
    `;
  }

  // =========================================================================
  // Controls & Tuning Tab Rendering
  // =========================================================================

  private renderTuningTab(): string {
    const tuning = this.progression.data.tuning;

    return `
      <div class="tuning-container">
        <div class="tuning-hero">
          <h3>Steering Sensitivity</h3>
          <p>Adjust cursor and tilt responsiveness for optimal control.</p>
        </div>

        <div class="tuning-controls">
          <!-- Sensitivity Slider -->
          <div class="tuning-control-card">
            <div class="tuning-label-row">
              <label for="tuning-sensitivity">Sensitivity / Speed</label>
              <span id="val-sensitivity" class="tuning-value-pill">${tuning.sensitivity.toFixed(1)}x</span>
            </div>
            <p class="tuning-explain">Ship acceleration rate toward target or tilt angle.</p>
            <div class="slider-wrapper">
              <span class="slider-boundary">0.5x</span>
              <input id="tuning-sensitivity" type="range" min="0.5" max="2.0" step="0.1" value="${tuning.sensitivity}">
              <span class="slider-boundary">2.0x</span>
            </div>
          </div>

          <!-- Deadzone Slider -->
          <div class="tuning-control-card">
            <div class="tuning-label-row">
              <label for="tuning-deadzone">Resting Deadzone</label>
              <span id="val-deadzone" class="tuning-value-pill">${tuning.deadzone}px</span>
            </div>
            <p class="tuning-explain">Neutral radius around cursor/center to eliminate drift.</p>
            <div class="slider-wrapper">
              <span class="slider-boundary">0px</span>
              <input id="tuning-deadzone" type="range" min="0" max="16" step="1" value="${tuning.deadzone}">
              <span class="slider-boundary">16px</span>
            </div>
          </div>

          <!-- Actions -->
          <div class="tuning-actions">
            <button id="btn-tuning-reset" type="button" class="secondary-button" style="width: auto; padding: 8px 16px; font-size: 11px;">
              ↺ Reset Defaults
            </button>
          </div>
        </div>
      </div>
    `;
  }

  // =========================================================================
  // Event Binding
  // =========================================================================

  private bindEvents() {
    if (!this.containerEl) return;

    // Close button
    this.containerEl.querySelector('#btn-armory-close')?.addEventListener('click', () => {
      this.close();
    });

    // Tab buttons
    this.containerEl.querySelectorAll('.armory-tab-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const tab = (e.currentTarget as HTMLElement).getAttribute('data-tab') as any;
        if (tab && tab !== this.activeTab) {
          this.activeTab = tab;
          this.render();
        }
      });
    });

    // Weapon category filter chips (Weapons tab sub-categories)
    this.containerEl.querySelectorAll('.weapon-filter-chip').forEach((chip) => {
      chip.addEventListener('click', (e) => {
        const filter = (e.currentTarget as HTMLElement).getAttribute('data-filter') as any;
        if (filter && filter !== this.activeWeaponCategory) {
          this.activeWeaponCategory = filter;
          this.render();
        }
      });
    });

    // Perk Upgrade buttons
    this.containerEl.querySelectorAll('.upgrade-perk-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const target = e.currentTarget as HTMLElement;
        const weapon = target.getAttribute('data-weapon') as keyof WeaponPerks;
        const perk = target.getAttribute('data-perk') as string;
        if (weapon && perk) {
          const success = this.progression.upgradePerk(weapon, perk);
          if (success) {
            this.onStateChanged();
            this.render();
          }
        }
      });
    });

    // Cursors Buy & Equip
    this.containerEl.querySelectorAll('.buy-cursor-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const id = (e.currentTarget as HTMLElement).getAttribute('data-id');
        if (id && this.progression.buyCursor(id)) {
          this.onStateChanged();
          this.render();
        }
      });
    });

    this.containerEl.querySelectorAll('.equip-cursor-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const id = (e.currentTarget as HTMLElement).getAttribute('data-id');
        if (id && this.progression.equipCursor(id)) {
          this.onStateChanged();
          this.render();
        }
      });
    });

    // Enemy Skins Buy & Equip
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

    // Arena Themes Buy & Equip
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

    // Sensitivity slider
    const sensInput = this.containerEl.querySelector('#tuning-sensitivity') as HTMLInputElement;
    if (sensInput) {
      sensInput.addEventListener('input', (e) => {
        const val = parseFloat((e.target as HTMLInputElement).value);
        this.progression.setSensitivity(val);
        const disp = this.containerEl?.querySelector('#val-sensitivity');
        if (disp) disp.textContent = `${val.toFixed(1)}x`;
        this.onStateChanged();
      });
    }

    // Deadzone slider
    const deadzoneInput = this.containerEl.querySelector('#tuning-deadzone') as HTMLInputElement;
    if (deadzoneInput) {
      deadzoneInput.addEventListener('input', (e) => {
        const val = parseInt((e.target as HTMLInputElement).value, 10);
        this.progression.setDeadzone(val);
        const disp = this.containerEl?.querySelector('#val-deadzone');
        if (disp) disp.textContent = `${val}px`;
        this.onStateChanged();
      });
    }

    // Reset tuning button
    this.containerEl.querySelector('#btn-tuning-reset')?.addEventListener('click', () => {
      this.progression.setSensitivity(1.0);
      this.progression.setDeadzone(4);
      this.onStateChanged();
      this.render();
    });
  }
}
