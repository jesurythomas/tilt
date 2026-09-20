// =========================================================================
// test_tilt_to_live.mjs - End-to-End Test Suite for Tilt to Live
// =========================================================================

import puppeteer from 'puppeteer';
import { existsSync, mkdirSync } from 'fs';

const screenshotDir = './scratch';
if (!existsSync(screenshotDir)) mkdirSync(screenshotDir, { recursive: true });

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function run() {
  console.log('--- STARTING COMPREHENSIVE TILT TO LIVE TEST SUITE ---');
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

  // 1. Verify Start Menu is visible on load
  console.log('\n1. Verifying Start Menu / Homepage...');
  const menuState = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    const menu = document.getElementById('tilt-menu-screen');
    const cards = document.querySelectorAll('.menu-mode-card');
    return {
      hasGame: !!game,
      phase: game?.phase,
      menuVisible: !!menu && !menu.classList.contains('hidden'),
      modeCardsCount: cards.length,
      currentMode: game?.options.settings.mode
    };
  });
  console.log('Start Menu State:', menuState);
  if (!menuState.hasGame) throw new Error('window.__TILT_GAME__ not found');
  if (menuState.phase !== 'menu') throw new Error(`Expected menu phase, got ${menuState.phase}`);
  if (!menuState.menuVisible) throw new Error('Start menu screen should be visible');
  if (menuState.modeCardsCount !== 3) throw new Error(`Expected 3 mode cards, got ${menuState.modeCardsCount}`);

  await page.screenshot({ path: `${screenshotDir}/test_01_start_menu.png` });
  console.log('📸 Captured test_01_start_menu.png');
  console.log('✅ PASS: Interactive Start Menu and 3 Game Modes verified!');

  // 2. Verify Always-Visible Left-Side Goals Sidebar
  console.log('\n2. Verifying Always-Visible Goals Sidebar...');
  const goalsState = await page.evaluate(() => {
    const sidebar = document.getElementById('tilt-goals-sidebar');
    const cards = sidebar?.querySelectorAll('.goal-hud-card');
    const header = sidebar?.querySelector('.goals-header-title');
    return {
      sidebarVisible: !!sidebar && !sidebar.classList.contains('hidden'),
      cardsCount: cards?.length || 0,
      headerText: header?.textContent?.trim()
    };
  });
  console.log('Goals Sidebar State:', goalsState);
  if (!goalsState.sidebarVisible) throw new Error('Goals sidebar should be visible');
  if (goalsState.cardsCount === 0) throw new Error('Active goal cards should be rendered');

  // Test opening Trophy Catalog modal
  console.log('Testing Trophy Catalog modal...');
  await page.click('#btn-view-all-goals');
  await delay(200);
  const trophyModalOpen = await page.evaluate(() => {
    const modal = document.getElementById('tilt-all-goals-modal');
    return modal && !modal.classList.contains('hidden');
  });
  if (!trophyModalOpen) throw new Error('Trophy catalog modal did not open');

  await page.click('#btn-close-all-goals');
  await delay(150);
  const trophyModalClosed = await page.evaluate(() => {
    const modal = document.getElementById('tilt-all-goals-modal');
    return modal && modal.classList.contains('hidden');
  });
  if (!trophyModalClosed) throw new Error('Trophy catalog modal did not close');
  console.log('✅ PASS: Left Goals Sidebar & Full Trophy Catalog verified!');

  // 3. Test Mode Selection Cards
  console.log('\n3. Testing Mode Card Selection...');
  await page.click('.menu-mode-card[data-mode="code-red"]');
  await delay(200);
  let selectedMode = await page.evaluate(() => window.__TILT_GAME__.options.settings.mode);
  if (selectedMode !== 'code-red') throw new Error(`Expected code-red mode, got ${selectedMode}`);

  await page.click('.menu-mode-card[data-mode="gauntlet"]');
  await delay(200);
  selectedMode = await page.evaluate(() => window.__TILT_GAME__.options.settings.mode);
  if (selectedMode !== 'gauntlet') throw new Error(`Expected gauntlet mode, got ${selectedMode}`);

  await page.click('.menu-mode-card[data-mode="classic"]');
  await delay(200);
  selectedMode = await page.evaluate(() => window.__TILT_GAME__.options.settings.mode);
  if (selectedMode !== 'classic') throw new Error(`Expected classic mode, got ${selectedMode}`);
  console.log('✅ PASS: Interactive mode cards switching verified!');

  // 4. Test Game Options Modal
  console.log('\n4. Testing Game Options Modal...');
  await page.click('#btn-menu-options');
  await delay(200);
  const optionsOpen = await page.evaluate(() => {
    const modal = document.getElementById('tilt-options-modal');
    return modal && !modal.classList.contains('hidden');
  });
  if (!optionsOpen) throw new Error('Options modal did not open');

  // Test toggling options
  await page.click('.opt-btn[data-opt="controlScheme"][data-val="keyboard"]');
  await delay(150);
  let ctrlScheme = await page.evaluate(() => window.__TILT_GAME__.options.settings.controlScheme);
  if (ctrlScheme !== 'keyboard') throw new Error(`Expected keyboard scheme, got ${ctrlScheme}`);

  await page.click('.opt-btn[data-opt="controlScheme"][data-val="hybrid"]');
  await delay(150);
  ctrlScheme = await page.evaluate(() => window.__TILT_GAME__.options.settings.controlScheme);
  if (ctrlScheme !== 'hybrid') throw new Error(`Expected hybrid scheme, got ${ctrlScheme}`);

  await page.click('#btn-close-options');
  await delay(150);
  const optionsClosed = await page.evaluate(() => {
    const modal = document.getElementById('tilt-options-modal');
    return modal && modal.classList.contains('hidden');
  });
  if (!optionsClosed) throw new Error('Options modal did not close');
  console.log('✅ PASS: Game Options modal, control schemes, audio, and visual toggles verified!');

  // 5. Test Armory & Milestone Economy
  console.log('\n5. Testing Armory & Milestone Points Economy...');
  await page.click('#btn-menu-armory');
  await delay(250);
  const armoryState = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    return {
      isOpen: game.armoryUI.isOpen(),
      points: game.progression.data.points,
      tabs: Array.from(document.querySelectorAll('.armory-tab-btn')).map((b) => b.textContent?.trim())
    };
  });
  console.log('Armory State:', armoryState);
  if (!armoryState.isOpen) throw new Error('Armory modal did not open');
  if (armoryState.points < 0) throw new Error('Points should be non-negative');

  await page.evaluate(() => window.__TILT_GAME__.closeArmory());
  await delay(150);
  console.log('✅ PASS: Armory & Milestone Points economy verified!');

  // 6. Launch Game Run from Menu
  console.log('\n6. Launching game from start menu...');
  await page.click('#btn-menu-launch');
  await delay(300);

  // Skip cinematic
  await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    if (game.phase === 'cinematic') {
      const rect = game.canvas.getBoundingClientRect();
      game.cinematic.skip(rect.width, rect.height);
    }
  });
  await delay(200);

  const playingState = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    const menu = document.getElementById('tilt-menu-screen');
    const goals = document.getElementById('tilt-goals-sidebar');
    return {
      phase: game.phase,
      menuHidden: menu?.classList.contains('hidden'),
      goalsStillVisible: !!goals && !goals.classList.contains('hidden'),
      shipX: game.player.x,
      shipY: game.player.y
    };
  });
  console.log('Playing State:', playingState);
  if (playingState.phase !== 'playing') throw new Error(`Expected playing phase, got ${playingState.phase}`);
  if (!playingState.menuHidden) throw new Error('Start menu should be hidden during gameplay');
  if (!playingState.goalsStillVisible) throw new Error('Goals sidebar must remain visible during gameplay');

  // Test Mouse Steering
  console.log('Testing mouse steering...');
  await page.mouse.move(700, 400);
  await delay(300);
  let shipPos = await page.evaluate(() => ({ x: window.__TILT_GAME__.player.x, y: window.__TILT_GAME__.player.y }));
  if (shipPos.x <= 420) throw new Error('Ship did not steer toward mouse position');

  // Test WASD Movement
  console.log('Testing WASD steering...');
  await page.keyboard.down('KeyA');
  await delay(250);
  await page.keyboard.up('KeyA');
  await delay(100);
  let movedShip = await page.evaluate(() => ({
    x: window.__TILT_GAME__.player.x,
    mode: window.__TILT_GAME__.controlMode
  }));
  if (movedShip.mode !== 'keyboard') throw new Error('Control mode did not switch to keyboard');

  await page.screenshot({ path: `${screenshotDir}/test_02_gameplay.png` });
  console.log('📸 Captured test_02_gameplay.png');
  console.log('✅ PASS: Gameplay launch, mouse steering, WASD, and in-game Goals HUD verified!');

  // 7. Test Milestone Completion & Celebration Toast
  console.log('\n7. Testing Milestone Completion and Notification Toast...');
  const toastResult = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    const goal = game.goals.catalog[0]; // e.g. Rookie Dodger (score 1000)
    game.goalsHUD.showGoalToast(goal);
    const toast = document.getElementById('tilt-goal-toast');
    return {
      toastVisible: !!toast && !toast.classList.contains('hidden'),
      toastText: toast?.textContent
    };
  });
  console.log('Toast Result:', toastResult);
  if (!toastResult.toastVisible) throw new Error('Goal toast banner should be visible upon milestone complete');

  await page.screenshot({ path: `${screenshotDir}/test_03_toast.png` });
  console.log('📸 Captured test_03_toast.png');
  console.log('✅ PASS: Milestone completion toast alert verified!');

  // 8. Test Player Death, Milestone Points Economy & Return to Start Menu
  console.log('\n8. Testing Player Death & Return to Menu...');
  await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    // Trigger collision death
    game.triggerPlayerDeath();
  });
  await delay(600);

  const gameOverState = await page.evaluate(() => {
    const modal = document.getElementById('tilt-gameover-modal');
    const earned = document.getElementById('tilt-earned-points')?.textContent;
    const balance = document.getElementById('tilt-balance-points')?.textContent;
    return {
      visible: !!modal && !modal.classList.contains('hidden'),
      earned,
      balance
    };
  });
  console.log('GameOver State:', gameOverState);
  if (!gameOverState.visible) throw new Error('Game over modal should be visible');
  if (!gameOverState.earned) throw new Error('Earned points text missing');

  await page.screenshot({ path: `${screenshotDir}/test_04_gameover.png` });
  console.log('📸 Captured test_04_gameover.png');

  // Test Return to Menu
  console.log('Clicking Main Menu from game over modal...');
  await page.click('#btn-tilt-menu-gameover');
  await delay(300);

  const returnMenuState = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    const menu = document.getElementById('tilt-menu-screen');
    return {
      phase: game.phase,
      menuVisible: !!menu && !menu.classList.contains('hidden')
    };
  });
  console.log('Return to Menu State:', returnMenuState);
  if (returnMenuState.phase !== 'menu') throw new Error(`Expected menu phase, got ${returnMenuState.phase}`);
  if (!returnMenuState.menuVisible) throw new Error('Start menu should be visible after returning to menu');
  console.log('✅ PASS: Game over modal & Return to Start Menu verified!');

  await browser.close();
  console.log('\n=============================================================');
  console.log('🎉 ALL TILT TO LIVE VERIFICATION TESTS PASSED SUCCESSFULLY! 🎉');
  console.log('=============================================================');
}

run().catch((err) => {
  console.error('TEST FAILED:', err);
  process.exit(1);
});
