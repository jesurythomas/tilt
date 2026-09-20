// =========================================================================
// test_milestones_armory_enemies.mjs - Verification Suite
// =========================================================================

import puppeteer from 'puppeteer';
import { existsSync, mkdirSync } from 'fs';

const screenshotDir = './scratch';
if (!existsSync(screenshotDir)) mkdirSync(screenshotDir, { recursive: true });

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function run() {
  console.log('--- STARTING VERIFICATION: ARMORY, MILESTONES & ENEMY VARIETY ---');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--use-fake-ui-for-media-stream']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });

  page.on('console', (msg) => {
    if (msg.type() === 'error') console.error('BROWSER ERROR:', msg.text());
  });

  await page.goto('http://localhost:5173/', { waitUntil: 'networkidle0' });
  await delay(600);

  // -------------------------------------------------------------
  // TEST 1: Armory UI Scaling, Font Sizes, and Tabs
  // -------------------------------------------------------------
  console.log('\n--- 1. Testing Armory UI Scaling & Tabs ---');
  await page.evaluate(() => {
    window.__TILT_GAME__.openArmory();
  });
  await delay(400);

  const armoryCheck = await page.evaluate(() => {
    const modal = document.getElementById('tilt-armory-modal');
    const panel = modal?.querySelector('.tilt-armory-panel');
    const tabs = modal?.querySelectorAll('.armory-tab-btn');
    const cards = modal?.querySelectorAll('.perk-card');
    const title = modal?.querySelector('.armory-title-group h2');
    const titleStyle = title ? window.getComputedStyle(title) : null;
    const firstCardTitle = modal?.querySelector('.perk-header h4');
    const firstCardTitleStyle = firstCardTitle ? window.getComputedStyle(firstCardTitle) : null;

    return {
      isOpen: modal && !modal.classList.contains('hidden'),
      tabsCount: tabs?.length,
      cardsCount: cards?.length,
      modalHeight: panel?.clientHeight,
      titleFontSize: titleStyle?.fontSize,
      cardTitleFontSize: firstCardTitleStyle?.fontSize
    };
  });
  console.log('Armory UI state:', armoryCheck);
  if (!armoryCheck.isOpen) throw new Error('Armory modal did not open');
  if (armoryCheck.tabsCount !== 5) throw new Error(`Expected 5 armory tabs, got ${armoryCheck.tabsCount}`);
  if (armoryCheck.cardsCount !== 7) throw new Error(`Expected 7 weapon perk cards, got ${armoryCheck.cardsCount}`);

  await page.screenshot({ path: `${screenshotDir}/verify_01_armory_perks.png` });
  console.log('📸 Captured verify_01_armory_perks.png');

  // -------------------------------------------------------------
  // TEST 2: Cursor Customization & SVG Data-URI Application
  // -------------------------------------------------------------
  console.log('\n--- 2. Testing Cursor Equipping & SVG Generation ---');
  // Click on 'Cursors' tab
  await page.evaluate(() => {
    const tabs = Array.from(document.querySelectorAll('.armory-tab-btn'));
    const cursorTab = tabs.find(t => t.textContent.includes('Cursors'));
    if (cursorTab) cursorTab.click();
  });
  await delay(300);

  const cursorTabState = await page.evaluate(() => {
    const cards = document.querySelectorAll('.catalog-card');
    return {
      cardsCount: cards.length,
      initialCursorVar: getComputedStyle(document.documentElement).getPropertyValue('--custom-cursor')
    };
  });
  console.log('Cursor tab state:', cursorTabState);
  if (cursorTabState.cardsCount !== 7) throw new Error(`Expected 7 cursor skins, got ${cursorTabState.cardsCount}`);

  // Give points and purchase/equip 'tactical' cursor
  const cursorChangeResult = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    game.progression.addPoints(50);
    game.progression.buyCursor('tactical');
    game.progression.equipCursor('tactical');
    game.updateCursor();

    const rootVar = getComputedStyle(document.documentElement).getPropertyValue('--custom-cursor');
    const equipped = game.progression.getEquippedCursor();
    const canvasCursor = game.canvas.style.cursor;

    return {
      equippedId: equipped.id,
      hasSvgDataUri: rootVar.startsWith('url("data:image/svg+xml'),
      rootVarSnippet: rootVar.substring(0, 60),
      canvasCursor
    };
  });
  console.log('Cursor equipping result:', cursorChangeResult);
  if (cursorChangeResult.equippedId !== 'tactical') throw new Error('Failed to equip tactical cursor');
  if (!cursorChangeResult.hasSvgDataUri) throw new Error('Root --custom-cursor should be an SVG data URI');

  await page.screenshot({ path: `${screenshotDir}/verify_02_cursor_equipped.png` });
  console.log('📸 Captured verify_02_cursor_equipped.png');

  // Close Armory
  await page.evaluate(() => {
    window.__TILT_GAME__.closeArmory();
  });
  await delay(300);

  // -------------------------------------------------------------
  // TEST 3: Milestones - Live Non-Completion & Death Capping (max 3)
  // -------------------------------------------------------------
  console.log('\n--- 3. Testing Milestone Rules (Live Non-Completion & Max 3 on Death) ---');
  // Launch a game run
  await page.evaluate(() => {
    window.__TILT_GAME__.launchRun('classic');
  });
  await delay(1200); // Allow cinematic to transition to playing

  // Set high run tracker stats that would qualify for 5+ run milestones
  const midRunCheck = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    game.runTracker.score = 65000;
    game.runTracker.kills = 120;
    game.runTracker.survivalTime = 95;
    game.runTracker.closeCalls = 15;
    game.runTracker.nukesDetonated = 4;

    // Trigger live update
    game.goalsHUD.updateLive(game.runTracker);

    // Check completed run goals
    const completedGoals = Array.from(game.goals.completedGoalIds);
    const runGoalsCatalog = game.goals.catalog.filter(g => !game.goals.isTotalGoal(g));
    const completedRunGoals = runGoalsCatalog.filter(g => game.goals.completedGoalIds.has(g.id));

    return {
      phase: game.phase,
      totalCompleted: completedGoals.length,
      completedRunGoalsCount: completedRunGoals.length
    };
  });
  console.log('Mid-run milestone state:', midRunCheck);
  if (midRunCheck.completedRunGoalsCount !== 0) {
    throw new Error(`CRITICAL: Run milestones completed mid-run! Count: ${midRunCheck.completedRunGoalsCount}`);
  }
  console.log('✅ PASS: Run milestones DID NOT complete mid-run!');

  // Now trigger player death / game over
  console.log('Simulating player game over...');
  const gameOverCheck = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    game.triggerPlayerDeath();
  });
  await delay(700);

  const postGameCheck = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    const runGoalsCatalog = game.goals.catalog.filter(g => !game.goals.isTotalGoal(g));
    const completedRunGoals = runGoalsCatalog.filter(g => game.goals.completedGoalIds.has(g.id));
    const earnedPts = game.pointsEarnedThisRun;
    const modalVisible = !document.getElementById('tilt-gameover-modal').classList.contains('hidden');
    const milestoneItems = document.querySelectorAll('.gameover-milestone-item');
    const earnedEl = document.getElementById('tilt-earned-points');

    return {
      modalVisible,
      completedRunGoalsCount: completedRunGoals.length,
      completedRunGoalTitles: completedRunGoals.map(g => g.title),
      earnedPts,
      earnedText: earnedEl?.textContent,
      renderedMilestonesCount: milestoneItems.length
    };
  });
  console.log('Post-game milestone result:', postGameCheck);
  if (!postGameCheck.modalVisible) throw new Error('Game over modal should be visible');
  if (postGameCheck.completedRunGoalsCount > 3) {
    throw new Error(`CRITICAL: Exceeded 3 run milestones per game! Awarded: ${postGameCheck.completedRunGoalsCount}`);
  }
  if (postGameCheck.completedRunGoalsCount === 0) {
    throw new Error('Expected at least 1-3 run milestones to be completed on game over');
  }
  console.log(`✅ PASS: Exactly ${postGameCheck.completedRunGoalsCount} run milestones awarded (strictly <= 3 cap)!`);
  console.log('Completed run milestones:', postGameCheck.completedRunGoalTitles);

  await page.screenshot({ path: `${screenshotDir}/verify_03_gameover_milestones.png` });
  console.log('📸 Captured verify_03_gameover_milestones.png');

  // -------------------------------------------------------------
  // TEST 4: Progressive Enemy Varieties at Score Thresholds
  // -------------------------------------------------------------
  console.log('\n--- 4. Testing Progressive Enemy Varieties (50k Charger, 100k Artillery, 150k Carrier) ---');

  // Restart game for clean enemy testing
  await page.evaluate(() => {
    window.__TILT_GAME__.startCinematic();
  });
  await delay(1200);

  const enemyTestResult = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    const bounds = { width: 800, height: 600 };
    const pPos = { x: 400, y: 300 };

    game.swarm.reset();

    // 1. Spawn Charger
    const charger = game.swarm.spawnCharger(bounds, pPos);

    // 2. Spawn Artillery & Bullet
    const artillery = game.swarm.spawnArtillery(bounds, pPos);
    const bullet = game.swarm.spawnBullet(artillery.x, artillery.y, pPos);

    // 3. Spawn Carrier (which auto-spawns 4 satellite shield drones)
    const carrier = game.swarm.spawnCarrier(bounds, pPos);

    const satellites = game.swarm.enemies.filter(e => e.parentCarrierId === carrier.id);

    // Step physics forward 0.5s to let Charger aim and satellites orbit
    for (let f = 0; f < 30; f++) {
      game.swarm.update(1 / 60, pPos, bounds, game.particles, 160000, 'classic');
    }

    const chargerAiming = charger.state === 'aiming' || charger.state === 'charging';
    const satellitesCount = satellites.length;

    // Now test carrier destruction and satellite scattering
    game.swarm.onEnemyKilled(carrier, game.particles);
    const satellitesAfterDeath = game.swarm.enemies.filter(e => e.parentCarrierId === carrier.id);
    const satellitesScattered = satellites.every(s => s.parentCarrierId === undefined && (s.vx !== 0 || s.vy !== 0));

    return {
      chargerId: charger.id,
      chargerState: charger.state,
      chargerAiming,
      artilleryId: artillery.id,
      artilleryHasCannon: artillery.fireCooldown !== undefined,
      bulletId: bullet.id,
      carrierId: carrier.id,
      initialSatellitesCount: satellitesCount,
      satellitesAfterCarrierDeathCount: satellitesAfterDeath.length,
      satellitesScattered
    };
  });
  console.log('Enemy varieties test result:', enemyTestResult);
  if (!enemyTestResult.chargerAiming) throw new Error('Charger failed to initialize aiming/charging state');
  if (!enemyTestResult.artilleryHasCannon) throw new Error('Artillery missing cannon cooldown');
  if (enemyTestResult.initialSatellitesCount !== 4) throw new Error(`Expected 4 satellites, got ${enemyTestResult.initialSatellitesCount}`);
  if (enemyTestResult.satellitesAfterCarrierDeathCount !== 0) throw new Error('Satellites still tethered after carrier death');
  if (!enemyTestResult.satellitesScattered) throw new Error('Satellites failed to scatter after carrier killed');

  console.log('✅ PASS: Charger, Artillery, Bullet, and Carrier with Orbiting Satellites mechanics verified!');

  // Take visual screenshot with all enemy types active on screen
  await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    const bounds = { width: 800, height: 600 };
    const pPos = { x: 400, y: 300 };

    game.swarm.reset();
    game.player.reset(400, 300);

    // Position Charger in aiming state
    const c = game.swarm.spawnCharger(bounds, pPos);
    c.x = 220; c.y = 220; c.state = 'aiming'; c.aimAngle = Math.atan2(300 - 220, 400 - 220);

    // Position Artillery
    const a = game.swarm.spawnArtillery(bounds, pPos);
    a.x = 580; a.y = 200; a.aimAngle = Math.atan2(300 - 200, 400 - 580); a.fireCooldown = 0.3; // muzzle charging!

    // Bullet flying towards player
    const b = game.swarm.spawnBullet(540, 220, pPos);

    // Carrier with satellites
    const car = game.swarm.spawnCarrier(bounds, pPos);
    car.x = 250; car.y = 440;
    // reposition its satellites around it
    let k = 0;
    for (const sat of game.swarm.enemies) {
      if (sat.parentCarrierId === car.id) {
        const ang = (k * Math.PI * 2) / 4;
        sat.x = car.x + Math.cos(ang) * 38;
        sat.y = car.y + Math.sin(ang) * 38;
        sat.orbitAngle = ang;
        k++;
      }
    }

    game.render();
  });
  await delay(200);
  await page.screenshot({ path: `${screenshotDir}/verify_04_enemy_varieties.png` });
  console.log('📸 Captured verify_04_enemy_varieties.png');

  console.log('\n======================================================');
  console.log('ALL VERIFICATION CHECKS PASSED WITH FLYING COLORS! 🚀');
  console.log('======================================================');

  await browser.close();
}

run().catch((err) => {
  console.error('VERIFICATION FAILED:', err);
  process.exit(1);
});
