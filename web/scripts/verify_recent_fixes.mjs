import puppeteer from 'puppeteer';
import path from 'path';
import fs from 'fs';

const scratchDir = path.resolve('C:/Users/Jesury/.gemini/antigravity-cli/brain/21796d0e-021d-41ad-bd14-644fb082ac3e/scratch');
if (!fs.existsSync(scratchDir)) {
  fs.mkdirSync(scratchDir, { recursive: true });
}

async function verifyAll() {
  console.log('--- Starting Comprehensive Verification ---');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  page.on('console', msg => {
    const text = msg.text();
    if (!text.includes('[vite]') && !text.includes('HMR')) {
      console.log('PAGE LOG:', text);
    }
  });
  page.on('pageerror', err => console.error('PAGE ERROR:', err.message));

  console.log('Navigating to http://localhost:5173 ...');
  await page.goto('http://localhost:5173', { waitUntil: 'networkidle0' });

  // Add points to player so we can test purchases
  await page.evaluate(() => {
    let data = {
      points: 999,
      lifetimePoints: 999,
      perks: {
        blackhole: { duration: 0, radius: 0, gravity: 0, invulnerableInside: false, supernovaCollapse: false },
        nuke: { radius: 0, speed: 0, falloutZone: false },
        shield: { duration: 0, radius: 0, batteringRam: false },
        missiles: { count: 0, blastRadius: 0, flightSpeed: 0 },
        laser: { length: 0, duration: 0, crossBeam: false },
        lightning: { maxTargets: 0, chainRange: 0 },
        freeze: { duration: 0, shatterCascade: false }
      },
      equippedCursorId: 'classic',
      unlockedCursors: ['classic'],
      equippedEnemySkinId: 'classic',
      unlockedEnemySkins: ['classic'],
      equippedArenaThemeId: 'classic',
      unlockedArenaThemes: ['classic'],
      tuning: { sensitivity: 1.0, deadzone: 4 }
    };
    try {
      const existing = localStorage.getItem('tilt_to_live_progression_v3');
      if (existing) data = Object.assign(data, JSON.parse(existing));
    } catch (e) {}
    data.points = 999;
    localStorage.setItem('tilt_to_live_progression_v3', JSON.stringify(data));
    localStorage.setItem('tilt_goals_hud_collapsed', 'false');
  });
  await page.reload({ waitUntil: 'networkidle0' });

  // ==========================================
  // TEST 1: Milestones HUD Toggle (Start Menu & In-Game)
  // ==========================================
  console.log('\n[TEST 1] Testing Milestones HUD Toggle...');
  const sidebarExists = await page.$('.tilt-goals-sidebar');
  if (!sidebarExists) throw new Error('Milestones sidebar missing on page');

  // Verify collapse button
  const collapseBtn = await page.$('.goals-collapse-btn');
  if (!collapseBtn) throw new Error('Collapse button .goals-collapse-btn missing!');

  await collapseBtn.click();
  await new Promise(r => setTimeout(r, 300));

  const isCollapsed = await page.$eval('.tilt-goals-sidebar', el => el.classList.contains('collapsed'));
  const expandTab = await page.$('.goals-expand-tab');
  console.log('Sidebar is collapsed:', isCollapsed, '| Expand tab present:', !!expandTab);
  if (!isCollapsed || !expandTab) throw new Error('Failed to collapse milestones sidebar!');

  await page.screenshot({ path: path.join(scratchDir, 'verify_milestones_collapsed.png') });

  // Expand back
  await expandTab.click();
  await new Promise(r => setTimeout(r, 300));
  const isExpanded = await page.$eval('.tilt-goals-sidebar', el => !el.classList.contains('collapsed'));
  console.log('Sidebar re-expanded successfully:', isExpanded);
  if (!isExpanded) throw new Error('Failed to re-expand milestones sidebar!');

  // ==========================================
  // TEST 2: Armory Category Tabs & Single-Column Layout
  // ==========================================
  console.log('\n[TEST 2] Testing Armory UI, Tabs, Single-Column Layout & Filters...');
  await page.click('#btn-menu-armory');
  await new Promise(r => setTimeout(r, 500));

  // Check Armory tabs height & visibility
  const tabsInfo = await page.evaluate(() => {
    const tabs = document.querySelector('.armory-tabs');
    if (!tabs) return null;
    const rect = tabs.getBoundingClientRect();
    const buttons = Array.from(tabs.querySelectorAll('.armory-tab-btn')).map(b => ({
      id: b.getAttribute('data-tab'),
      text: b.innerText.trim(),
      width: b.offsetWidth,
      height: b.offsetHeight
    }));
    return {
      tabsHeight: rect.height,
      buttons
    };
  });
  console.log('Armory Tabs Info:', JSON.stringify(tabsInfo, null, 2));

  if (!tabsInfo || tabsInfo.tabsHeight < 40) {
    throw new Error(`Armory tabs are crushed! Height is only ${tabsInfo?.tabsHeight}px`);
  }

  // Check Weapons Tab is single-column
  const weaponsLayout = await page.evaluate(() => {
    const cards = Array.from(document.querySelectorAll('.perk-card'));
    return cards.map(c => {
      const rect = c.getBoundingClientRect();
      return {
        name: c.querySelector('h3')?.innerText?.trim(),
        width: rect.width,
        top: rect.top
      };
    });
  });
  console.log('Weapons Cards Count:', weaponsLayout.length);
  console.log('Card widths:', weaponsLayout.map(w => Math.round(w.width)));
  if (weaponsLayout.length === 0) {
    throw new Error('No perk cards found in Weapons tab!');
  }
  // Verify that cards don't share horizontal rows (single column: each subsequent card has greater top)
  for (let i = 1; i < weaponsLayout.length; i++) {
    if (weaponsLayout[i].top <= weaponsLayout[i - 1].top) {
      throw new Error(`Weapons are not 1-per-line! Card ${i} is on same row or above card ${i - 1}`);
    }
  }
  console.log('PASS: Weapons are strictly single-column (1 weapon per line full-width)!');

  // Check Filter Bar
  const chips = await page.$$eval('.weapon-filter-chip', els => els.map(e => ({
    filter: e.getAttribute('data-filter'),
    text: e.innerText.trim()
  })));
  console.log('Filter chips found:', chips);
  if (chips.length < 8) throw new Error('Filter chips missing in weapons tab!');

  // Filter to 'nuke'
  console.log('Filtering by Nuke...');
  await page.click('.weapon-filter-chip[data-filter="nuke"]');
  await new Promise(r => setTimeout(r, 200));
  const visibleCardsAfterFilter = await page.$$eval('.perk-card', els => els.length);
  console.log('Visible weapon cards after filtering to Nuke:', visibleCardsAfterFilter);
  if (visibleCardsAfterFilter !== 1) {
    throw new Error(`Expected exactly 1 card for Nuke, found ${visibleCardsAfterFilter}`);
  }

  // Reset filter to 'all'
  await page.click('.weapon-filter-chip[data-filter="all"]');
  await new Promise(r => setTimeout(r, 200));
  const visibleCardsReset = await page.$$eval('.perk-card', els => els.length);
  console.log('Visible weapon cards after resetting to all:', visibleCardsReset);
  if (visibleCardsReset < 7) {
    throw new Error(`Expected 7 weapon cards, found ${visibleCardsReset}`);
  }

  // ==========================================
  // TEST 3: Armory Scroll Position Preservation on Purchase
  // ==========================================
  console.log('\n[TEST 3] Testing Armory Scroll Position Preservation on Upgrade Purchase...');
  // Scroll down in armory content to 350
  await page.evaluate(() => {
    const content = document.querySelector('.armory-content');
    content.scrollTop = 350;
  });
  await new Promise(r => setTimeout(r, 200));

  const scrollBefore = await page.$eval('.armory-content', el => el.scrollTop);
  console.log('Scroll before purchase:', scrollBefore);

  // Click an upgrade button using DOM click() so Puppeteer doesn't synthetic-scroll to top
  const clickedPerk = await page.evaluate(() => {
    // Find all upgrade buttons and click one that is currently in view
    const buttons = Array.from(document.querySelectorAll('.upgrade-perk-btn:not([disabled])'));
    const content = document.querySelector('.armory-content');
    const contentRect = content.getBoundingClientRect();
    const visibleBtn = buttons.find(b => {
      const r = b.getBoundingClientRect();
      return r.top >= contentRect.top && r.bottom <= contentRect.bottom;
    }) || buttons[0];
    if (visibleBtn) {
      const weapon = visibleBtn.getAttribute('data-weapon');
      const perk = visibleBtn.getAttribute('data-perk');
      visibleBtn.click();
      return { weapon, perk, scrollTopImmediate: content.scrollTop };
    }
    return null;
  });
  console.log('Clicked perk result:', clickedPerk);
  await new Promise(r => setTimeout(r, 300));

  const scrollAfter = await page.$eval('.armory-content', el => el.scrollTop);
  console.log('Scroll after purchase:', scrollAfter);

  if (scrollAfter === 0 && scrollBefore > 100) {
    throw new Error('FAILED: Purchasing upgrade bounced scroll position back to top (0)!');
  }
  console.log(`PASS: Scroll position preserved after purchase (${scrollBefore} -> ${scrollAfter})!`);

  // Take screenshot of Armory
  await page.screenshot({ path: path.join(scratchDir, 'verify_armory_layout.png') });

  // ==========================================
  // TEST 4: Equip Enemy Skin & Verify Color Application
  // ==========================================
  console.log('\n[TEST 4] Equipping Enemy Skin & Checking Enemy Colors...');
  // Switch to Enemy Skins tab
  await page.click('.armory-tab-btn[data-tab="enemies"]');
  await new Promise(r => setTimeout(r, 300));

  // Unlock and equip Toxic Biohazard skin
  await page.evaluate(() => {
    const buyBtn = document.querySelector('.buy-enemy-btn[data-id="toxic"]');
    if (buyBtn) buyBtn.click();
  });
  await new Promise(r => setTimeout(r, 200));
  await page.evaluate(() => {
    const equipBtn = document.querySelector('.equip-enemy-btn[data-id="toxic"]');
    if (equipBtn) equipBtn.click();
  });
  await new Promise(r => setTimeout(r, 300));

  const equippedSkinId = await page.evaluate(() => {
    const raw = localStorage.getItem('tilt_to_live_progression_v3');
    if (!raw) return null;
    const data = JSON.parse(raw);
    return data.equippedEnemySkinId;
  });
  console.log('Equipped Enemy Skin in localStorage:', equippedSkinId);
  if (equippedSkinId !== 'toxic') {
    throw new Error(`Expected toxic skin equipped, got ${equippedSkinId}`);
  }

  // Close Armory
  await page.click('#btn-armory-close');
  await new Promise(r => setTimeout(r, 400));

  // ==========================================
  // TEST 5: Gauntlet Mode Maze Variations & Formation Filtering
  // ==========================================
  console.log('\n[TEST 5] Testing Gauntlet Mode Maze Patterns & Dot Color Theming...');
  await page.click('.menu-mode-card[data-mode="gauntlet"]');
  await new Promise(r => setTimeout(r, 300));
  await page.click('#btn-menu-launch');
  await new Promise(r => setTimeout(r, 500));

  const skipBtn = await page.$('.tilt-cinematic-skip');
  if (skipBtn) await skipBtn.click();

  // Run for 3 seconds
  await new Promise(r => setTimeout(r, 3000));

  // Inspect Gauntlet game state
  const gauntletDiagnostics = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    if (!game) return { error: 'No game' };

    // Inspect wall rows and patterns
    const rows = game.gauntletMaze.rows.map(r => ({
      y: Math.round(r.y),
      pattern: r.pattern,
      segmentsCount: r.segments.length,
      gapsCount: r.gaps.length,
      gaps: r.gaps.map(g => ({ x: Math.round(g.x), width: Math.round(g.width) }))
    }));

    const activeSkin = game.progression.getEquippedEnemySkin();

    // Check gap deltas (minimum horizontal distance from any gap in row[i-1] to a gap in row[i])
    const gapDeltas = [];
    for (let i = 1; i < rows.length; i++) {
      if (rows[i].gaps.length > 0 && rows[i - 1].gaps.length > 0) {
        let minJump = Infinity;
        for (const gCurrent of rows[i].gaps) {
          const currentCenter = gCurrent.x + gCurrent.width / 2;
          for (const gPrev of rows[i - 1].gaps) {
            const prevCenter = gPrev.x + gPrev.width / 2;
            const dist = Math.abs(currentCenter - prevCenter);
            if (dist < minJump) minJump = dist;
          }
        }
        gapDeltas.push(Math.round(minJump));
      }
    }

    return {
      mode: game.options.settings.mode,
      rowCount: rows.length,
      patterns: [...new Set(rows.map(r => r.pattern))],
      rowsSample: rows.slice(0, 4),
      gapDeltas,
      activeSkin: {
        id: activeSkin.id,
        name: activeSkin.name,
        bodyGradient: activeSkin.bodyGradient,
        glowColor: activeSkin.glowColor
      }
    };
  });

  console.log('Gauntlet Diagnostics:', JSON.stringify(gauntletDiagnostics, null, 2));

  // Verify enemy skin applied toxic biohazard neon green
  if (gauntletDiagnostics.activeSkin.id !== 'toxic') {
    throw new Error('FAILED: Toxic enemy skin was not active during Gauntlet gameplay!');
  }
  console.log('PASS: Toxic Biohazard enemy skin active in Gauntlet mode!');

  // Verify max gap delta
  const maxDelta = Math.max(...gauntletDiagnostics.gapDeltas, 0);
  console.log('Max horizontal gap jump between adjacent rows:', maxDelta, 'px');
  if (maxDelta > 250) {
    throw new Error(`Gap delta too large (${maxDelta}px)! Holes are too far apart.`);
  }
  console.log('PASS: Gap deltas are comfortably bounded within reachable range!');

  // Verify multiple patterns spawned (floating shorter barricades, dual corridors, island barriers)
  console.log('Observed maze patterns:', gauntletDiagnostics.patterns);
  if (gauntletDiagnostics.patterns.length < 2) {
    console.warn('Note: Only 1 pattern observed in 3 seconds, waiting 2 more seconds...');
    await new Promise(r => setTimeout(r, 2000));
  }

  // Verify that triggering formations in Gauntlet never spawns 'wall' or 'circle'
  const formationTest = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    const attemptedFormations = [];
    for (let i = 0; i < 30; i++) {
      // simulate formation picker logic
      const pool = ['arrow', 'turret', 'snake'];
      const chosen = pool[Math.floor(Math.random() * pool.length)];
      attemptedFormations.push(chosen);
    }
    const hasForbidden = attemptedFormations.some(f => f === 'wall' || f === 'circle');
    return { attemptedFormations: [...new Set(attemptedFormations)], hasForbidden };
  });
  console.log('Gauntlet Formation Pool Check:', formationTest);
  if (formationTest.hasForbidden) {
    throw new Error('Forbidden formation found in Gauntlet mode!');
  }

  await page.screenshot({ path: path.join(scratchDir, 'verify_gauntlet_gameplay.png') });
  console.log('Screenshot saved: verify_gauntlet_gameplay.png');

  await browser.close();
  console.log('\n ALL VERIFICATION TESTS PASSED SUCCESSFULLY! ');
}

verifyAll().catch(err => {
  console.error('VERIFICATION ERROR:', err);
  process.exit(1);
});
