// =========================================================================
// ArmoryUI.ts - Armory shell: Weapons, Ships, Arena and Handling
// =========================================================================

import { ProgressionManager, WeaponPerks } from './ProgressionManager';

const ICON_CLOSE =
  '<svg class="tilt-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M6 6l12 12M18 6L6 18"></path></svg>';

const ICON_CHECK =
  '<svg class="tilt-icon icon-check" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M4.5 12.5l5 5 10-11"></path></svg>';

/** The four panels of the redesigned Armory. */
type ArmoryTab = 'weapons' | 'ships' | 'arena' | 'handling';

/** Legacy tab keys still passed in by TiltGame.openArmory(). */
type LegacyTab = 'perks' | 'cursors' | 'enemies' | 'arenas' | 'tuning';

const LEGACY_TAB_MAP: Record<LegacyTab, ArmoryTab> = {
  perks: 'weapons',
  cursors: 'ships',
  enemies: 'arena',
  arenas: 'arena',
  tuning: 'handling'
};

interface UpgradeDef {
  /** Key on the weapon's perk record. Unchanged from ProgressionManager. */
  key: string;
  /** One or two words. */
  name: string;
  /** The bare delta, e.g. "+35px / rank". */
  effect: string;
  /** Display rank cap — unchanged from the previous build. */
  max: number;
}

interface UnlockDef {
  key: string;
  name: string;
  effect: string;
}

interface WeaponDef {
  key: keyof WeaponPerks;
  /** One or two words. */
  name: string;
  /** One short sentence, max 8 words. */
  desc: string;
  upgrades: UpgradeDef[];
  unlocks: UnlockDef[];
}

const WEAPONS: WeaponDef[] = [
  {
    key: 'blackhole',
    name: 'Blackhole',
    desc: 'Drags dots in, then collapses.',
    upgrades: [
      { key: 'duration', name: 'Duration', effect: '+0.5s / rank', max: 5 },
      { key: 'radius', name: 'Radius', effect: '+35px / rank', max: 5 },
      { key: 'gravity', name: 'Pull', effect: '+20% / rank', max: 5 }
    ],
    unlocks: [
      { key: 'invulnerableInside', name: 'Aegis', effect: 'You are safe inside the well.' },
      { key: 'supernovaCollapse', name: 'Supernova', effect: 'Collapse fires a 420px shockwave.' }
    ]
  },
  {
    key: 'nuke',
    name: 'Nuke',
    desc: 'Clears every dot in range.',
    upgrades: [
      { key: 'radius', name: 'Radius', effect: '+40px / rank', max: 5 },
      { key: 'speed', name: 'Speed', effect: '+25% / rank', max: 3 }
    ],
    unlocks: [{ key: 'falloutZone', name: 'Fallout', effect: 'Leaves a 3s burning zone.' }]
  },
  {
    key: 'laser',
    name: 'Laser',
    desc: 'Cuts a line through the swarm.',
    upgrades: [
      { key: 'length', name: 'Length', effect: '+35px / rank', max: 5 },
      { key: 'duration', name: 'Duration', effect: '+0.4s / rank', max: 3 }
    ],
    unlocks: [{ key: 'crossBeam', name: 'Cross beam', effect: 'Fires four beams at once.' }]
  },
  {
    key: 'missiles',
    name: 'Missiles',
    desc: 'Homing warheads chase scattered dots.',
    upgrades: [
      { key: 'count', name: 'Count', effect: '+1 / rank', max: 5 },
      { key: 'blastRadius', name: 'Blast', effect: '+12px / rank', max: 3 },
      { key: 'flightSpeed', name: 'Speed', effect: '+20% / rank', max: 3 }
    ],
    unlocks: []
  },
  {
    key: 'shield',
    name: 'Shield',
    desc: 'A bubble you can ram with.',
    upgrades: [
      { key: 'duration', name: 'Duration', effect: '+1.0s / rank', max: 5 },
      { key: 'radius', name: 'Radius', effect: '+4px / rank', max: 3 }
    ],
    unlocks: [{ key: 'batteringRam', name: 'Ram', effect: 'Ramming detonates nearby dots.' }]
  },
  {
    key: 'lightning',
    name: 'Lightning',
    desc: 'Arcs jump between clustered dots.',
    upgrades: [
      { key: 'maxTargets', name: 'Targets', effect: '+3 / rank', max: 5 },
      { key: 'chainRange', name: 'Range', effect: '+40px / rank', max: 3 }
    ],
    unlocks: []
  },
  {
    key: 'freeze',
    name: 'Freeze',
    desc: 'Locks every dot in ice.',
    upgrades: [{ key: 'duration', name: 'Duration', effect: '+0.7s / rank', max: 5 }],
    unlocks: [{ key: 'shatterCascade', name: 'Cascade', effect: 'Shattering breaks the dots nearby.' }]
  }
];

/**
 * Display-only silhouette stats for the ship cards, 1..5.
 * Ships carry no gameplay stats today; these describe the drawn silhouette so
 * the two bars in the card have something honest to show.
 */
const SHIP_STATS: Record<string, { hitbox: number; turn: number }> = {
  classic: { hitbox: 3, turn: 3 },
  tactical: { hitbox: 4, turn: 4 },
  singularity: { hitbox: 2, turn: 4 },
  solar: { hitbox: 5, turn: 2 },
  cyber: { hitbox: 3, turn: 4 },
  shuriken: { hitbox: 4, turn: 5 },
  celestial: { hitbox: 3, turn: 5 }
};

function esc(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function pts(value: number): string {
  // Singular unit when the cost is exactly one point.
  return `${value.toLocaleString()} ${value === 1 ? 'pt' : 'pts'}`;
}

export class ArmoryUI {
  private readonly progression: ProgressionManager;
  private readonly onStateChanged: () => void;
  private readonly onCloseModal: () => void;

  private containerEl: HTMLElement | null = null;
  private activeTab: ArmoryTab = 'weapons';
  private selectedWeapon: keyof WeaponPerks = 'blackhole';

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

  public open(defaultTab?: LegacyTab) {
    if (defaultTab) this.activeTab = LEGACY_TAB_MAP[defaultTab] || 'weapons';
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

    const tabs: Array<{ id: ArmoryTab; label: string }> = [
      { id: 'weapons', label: 'Weapons' },
      { id: 'ships', label: 'Ships' },
      { id: 'arena', label: 'Arena' },
      { id: 'handling', label: 'Handling' }
    ];

    this.containerEl.innerHTML = `
      <div class="armory-shell" role="dialog" aria-modal="true" aria-label="Armory">
        <div class="armory-header">
          <div class="armory-title-group">
            <h2>Armory</h2>
          </div>

          <nav class="armory-tabs" role="tablist" aria-label="Armory sections">
            ${tabs
              .map(
                (t) => `
              <button class="armory-tab-btn ${this.activeTab === t.id ? 'active' : ''}"
                      type="button" role="tab" data-tab="${t.id}"
                      aria-selected="${this.activeTab === t.id ? 'true' : 'false'}">${t.label}</button>`
              )
              .join('')}
          </nav>

          <div class="armory-header-right">
            <div class="armory-points">
              <span class="armory-points-label">Points</span>
              <span id="armory-points-val" class="armory-points-value">${points.toLocaleString()}</span>
            </div>
            <button id="btn-armory-close" class="armory-close-btn" type="button" aria-label="Close armory">${ICON_CLOSE}</button>
          </div>
        </div>

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
      case 'weapons':
        return this.renderWeaponsPanel();
      case 'ships':
        return this.renderShipsPanel();
      case 'arena':
        return this.renderArenaPanel();
      case 'handling':
        return this.renderHandlingPanel();
    }
  }

  // =========================================================================
  // Shared fragments
  // =========================================================================

  private renderPips(current: number, max: number): string {
    let pips = '';
    for (let i = 0; i < max; i++) {
      pips += `<span class="pip ${i < current ? 'filled' : ''}"></span>`;
    }
    return `<span class="rank-pips" aria-hidden="true">${pips}</span>`;
  }

  private weaponRank(def: WeaponDef): { owned: number; total: number } {
    const perks = this.progression.data.perks[def.key] as unknown as Record<string, number | boolean>;
    let owned = 0;
    let total = 0;
    for (const up of def.upgrades) {
      owned += Math.min(Number(perks[up.key] ?? 0), up.max);
      total += up.max;
    }
    for (const un of def.unlocks) {
      owned += perks[un.key] ? 1 : 0;
      total += 1;
    }
    return { owned, total };
  }

  // =========================================================================
  // Weapons panel
  // =========================================================================

  private renderWeaponsPanel(): string {
    const def = WEAPONS.find((w) => w.key === this.selectedWeapon) || WEAPONS[0];
    const points = this.progression.data.points;
    const perks = this.progression.data.perks[def.key] as unknown as Record<string, number | boolean>;

    const list = WEAPONS.map((w) => {
      const rank = this.weaponRank(w);
      return `
        <button class="armory-weapon-item ${w.key === def.key ? 'is-selected' : ''}"
                type="button" data-weapon-select="${w.key}"
                aria-pressed="${w.key === def.key ? 'true' : 'false'}">
          <span class="armory-weapon-item-name">${esc(w.name)}</span>
          <span class="armory-weapon-item-rank">${rank.owned}/${rank.total}</span>
        </button>`;
    }).join('');

    const rows = def.upgrades
      .map((up) => {
        const current = Math.min(Number(perks[up.key] ?? 0), up.max);
        const maxed = current >= up.max;
        const cost = this.progression.getPerkCost(current, false);
        const afford = points >= cost;
        const action = maxed
          ? `<span class="armory-cost-btn is-maxed">Maxed</span>`
          : `<button class="btn-secondary armory-cost-btn upgrade-perk-btn" type="button"
                     data-weapon="${def.key}" data-perk="${up.key}" ${afford ? '' : 'disabled'}>${pts(cost)}</button>`;
        return `
          <div class="armory-upgrade-row">
            <span class="armory-upgrade-text">
              <span class="armory-upgrade-name">${esc(up.name)}</span>
              <span class="armory-upgrade-effect">${esc(up.effect)}</span>
            </span>
            <span class="armory-upgrade-meter">
              ${this.renderPips(current, up.max)}
              <span class="armory-rank-readout">${current}/${up.max}</span>
            </span>
            ${action}
          </div>`;
      })
      .join('');

    const unlockCost = this.progression.getPerkCost(0, true);
    const unlocks = def.unlocks.length
      ? `
        <section class="armory-unlocks">
          <h4 class="armory-section-label">Unlocks</h4>
          <div class="armory-unlock-grid">
            ${def.unlocks
              .map((un) => {
                const owned = !!perks[un.key];
                const afford = points >= unlockCost;
                const action = owned
                  ? `<span class="armory-cost-btn is-owned">${ICON_CHECK}<span class="tilt-btn-text">Unlocked</span></span>`
                  : `<button class="btn-secondary armory-cost-btn upgrade-perk-btn" type="button"
                             data-weapon="${def.key}" data-perk="${un.key}" ${afford ? '' : 'disabled'}>${pts(unlockCost)}</button>`;
                return `
                  <div class="armory-unlock-card ${owned ? 'is-owned' : ''}">
                    <span class="armory-unlock-name">${esc(un.name)}</span>
                    <span class="armory-unlock-effect">${esc(un.effect)}</span>
                    ${action}
                  </div>`;
              })
              .join('')}
          </div>
        </section>`
      : '';

    return `
      <div class="armory-panel armory-panel-weapons">
        <nav class="armory-weapon-list" aria-label="Weapons">${list}</nav>

        <section class="armory-weapon-main">
          <header class="armory-weapon-head">
            <h3 class="armory-weapon-title">${esc(def.name)}</h3>
            <p class="armory-weapon-desc">${esc(def.desc)}</p>
          </header>

          <div class="armory-upgrade-list">${rows}</div>

          ${unlocks}
        </section>
      </div>
    `;
  }

  // =========================================================================
  // Ships panel
  // =========================================================================

  private renderShipsPanel(): string {
    const points = this.progression.data.points;
    const equippedId = this.progression.data.equippedCursorId;
    const unlocked = this.progression.data.unlockedCursors;

    const cards = this.progression.shipCatalog
      .map((ship) => {
        const isUnlocked = unlocked.includes(ship.id);
        const isEquipped = equippedId === ship.id;
        const afford = points >= ship.price;
        const stats = SHIP_STATS[ship.id] || { hitbox: 3, turn: 3 };

        let action = '';
        if (isEquipped) {
          action = `<span class="btn-secondary armory-action-btn is-equipped">${ICON_CHECK}<span class="tilt-btn-text">Equipped</span></span>`;
        } else if (isUnlocked) {
          action = `<button class="btn-secondary armory-action-btn equip-cursor-btn" type="button" data-id="${ship.id}">Equip</button>`;
        } else {
          action = `<button class="btn-secondary armory-action-btn buy-cursor-btn" type="button" data-id="${ship.id}" ${afford ? '' : 'disabled'}>${pts(ship.price)}</button>`;
        }

        return `
          <article class="armory-ship-card ${isEquipped ? 'is-equipped' : ''}">
            <div class="armory-ship-plate">${this.progression.getShipSvgPreview(ship.id)}</div>
            <h4 class="armory-ship-name">${esc(ship.name)}</h4>
            <p class="armory-ship-trait">${esc(ship.description)}</p>
            <div class="armory-stat-bars">
              <div class="armory-stat-row">
                <span class="armory-stat-name">Hitbox</span>
                <span class="armory-stat-track"><span class="armory-stat-fill lvl-${stats.hitbox}"></span></span>
              </div>
              <div class="armory-stat-row">
                <span class="armory-stat-name">Turn</span>
                <span class="armory-stat-track"><span class="armory-stat-fill lvl-${stats.turn}"></span></span>
              </div>
            </div>
            ${action}
          </article>`;
      })
      .join('');

    return `
      <div class="armory-panel armory-panel-ships">
        <div class="armory-ship-grid">${cards}</div>
      </div>
    `;
  }

  // =========================================================================
  // Arena panel (themes + enemy dots)
  // =========================================================================

  private renderArenaPanel(): string {
    const points = this.progression.data.points;

    const themeTiles = this.progression.arenaThemeCatalog
      .map((arena) => {
        const isUnlocked = this.progression.data.unlockedArenaThemes.includes(arena.id);
        const isEquipped = this.progression.data.equippedArenaThemeId === arena.id;
        const afford = points >= arena.price;

        let action = '';
        if (isEquipped) {
          action = `<span class="btn-secondary armory-action-btn is-equipped">${ICON_CHECK}<span class="tilt-btn-text">Equipped</span></span>`;
        } else if (isUnlocked) {
          action = `<button class="btn-secondary armory-action-btn equip-arena-btn" type="button" data-id="${arena.id}">Equip</button>`;
        } else {
          action = `<button class="btn-secondary armory-action-btn buy-arena-btn" type="button" data-id="${arena.id}" ${afford ? '' : 'disabled'}>${pts(arena.price)}</button>`;
        }

        return `
          <article class="armory-tile ${isEquipped ? 'is-equipped' : ''}">
            <span class="armory-tile-plate armory-swatch theme-${arena.id}" aria-hidden="true"></span>
            <h4 class="armory-tile-name">${esc(arena.name)}</h4>
            <p class="armory-tile-trait">${esc(arena.description)}</p>
            ${action}
          </article>`;
      })
      .join('');

    const dotTiles = this.progression.enemySkinCatalog
      .map((skin) => {
        const isUnlocked = this.progression.data.unlockedEnemySkins.includes(skin.id);
        const isEquipped = this.progression.data.equippedEnemySkinId === skin.id;
        const afford = points >= skin.price;

        let action = '';
        if (isEquipped) {
          action = `<span class="btn-secondary armory-action-btn is-equipped">${ICON_CHECK}<span class="tilt-btn-text">Equipped</span></span>`;
        } else if (isUnlocked) {
          action = `<button class="btn-secondary armory-action-btn equip-enemy-btn" type="button" data-id="${skin.id}">Equip</button>`;
        } else {
          action = `<button class="btn-secondary armory-action-btn buy-enemy-btn" type="button" data-id="${skin.id}" ${afford ? '' : 'disabled'}>${pts(skin.price)}</button>`;
        }

        return `
          <article class="armory-tile ${isEquipped ? 'is-equipped' : ''}">
            <span class="armory-tile-plate armory-dot dot-${skin.id}" aria-hidden="true"></span>
            <h4 class="armory-tile-name">${esc(skin.name)}</h4>
            <p class="armory-tile-trait">${esc(skin.description)}</p>
            ${action}
          </article>`;
      })
      .join('');

    return `
      <div class="armory-panel armory-panel-arena">
        <section class="armory-subsection">
          <h3 class="armory-section-label">Themes</h3>
          <div class="armory-tile-grid">${themeTiles}</div>
        </section>

        <section class="armory-subsection">
          <h3 class="armory-section-label">Dots</h3>
          <div class="armory-tile-grid">${dotTiles}</div>
        </section>
      </div>
    `;
  }

  // =========================================================================
  // Handling panel
  // =========================================================================

  private renderHandlingPanel(): string {
    const tuning = this.progression.data.tuning;
    const ship = this.progression.getEquippedShip();

    return `
      <div class="armory-panel armory-panel-handling">
        <section class="armory-handling-grid">
          <div class="armory-handling-controls">
            <h3 class="armory-handling-title">Handling</h3>

            <div class="armory-slider-card">
              <div class="armory-slider-head">
                <span class="armory-slider-text">
                  <label class="armory-slider-name" for="tuning-sensitivity">Turn rate</label>
                  <span class="armory-slider-hint">Higher turns sharper.</span>
                </span>
                <span id="val-sensitivity" class="tuning-value-pill">${tuning.sensitivity.toFixed(1)}x</span>
              </div>
              <div class="slider-wrapper">
                <span class="slider-boundary">0.5x</span>
                <input id="tuning-sensitivity" class="armory-slider-input" type="range" min="0.5" max="2.0" step="0.1" value="${tuning.sensitivity}">
                <span class="slider-boundary">2.0x</span>
              </div>
            </div>

            <div class="armory-slider-card">
              <div class="armory-slider-head">
                <span class="armory-slider-text">
                  <label class="armory-slider-name" for="tuning-deadzone">Deadzone</label>
                  <span class="armory-slider-hint">Stops drift when you hold still.</span>
                </span>
                <span id="val-deadzone" class="tuning-value-pill">${tuning.deadzone}px</span>
              </div>
              <div class="slider-wrapper">
                <span class="slider-boundary">0px</span>
                <input id="tuning-deadzone" class="armory-slider-input" type="range" min="0" max="16" step="1" value="${tuning.deadzone}">
                <span class="slider-boundary">16px</span>
              </div>
            </div>

            <div class="armory-handling-actions">
              <button id="btn-tuning-reset" class="btn-secondary armory-reset-btn" type="button">Reset</button>
            </div>
          </div>

          <aside class="armory-preview">
            <div class="armory-preview-plate">${this.progression.getShipSvgPreview(ship.id)}</div>
            <div class="armory-preview-stats">
              <div class="armory-preview-row">
                <span class="armory-preview-key">Ship</span>
                <span class="armory-preview-val">${esc(ship.name)}</span>
              </div>
              <div class="armory-preview-row">
                <span class="armory-preview-key">Turn rate</span>
                <span class="armory-preview-val">${tuning.sensitivity.toFixed(1)}x</span>
              </div>
              <div class="armory-preview-row">
                <span class="armory-preview-key">Deadzone</span>
                <span class="armory-preview-val">${tuning.deadzone}px</span>
              </div>
            </div>
          </aside>
        </section>
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
        const tab = (e.currentTarget as HTMLElement).getAttribute('data-tab') as ArmoryTab | null;
        if (tab && tab !== this.activeTab) {
          this.activeTab = tab;
          this.render();
        }
      });
    });

    // Weapon selection in the left list
    this.containerEl.querySelectorAll('[data-weapon-select]').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const key = (e.currentTarget as HTMLElement).getAttribute('data-weapon-select') as keyof WeaponPerks | null;
        if (key && key !== this.selectedWeapon) {
          this.selectedWeapon = key;
          this.render();
        }
      });
    });

    // Perk upgrade / unlock buttons
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

    // Ships buy & equip
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

    // Enemy dots buy & equip
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

    // Arena themes buy & equip
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

    // Turn rate slider
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
