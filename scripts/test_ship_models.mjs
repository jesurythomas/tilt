// =========================================================================
// test_ship_models.mjs - Verification Suite for Player Ship Models
// =========================================================================

import puppeteer from 'puppeteer';
import { existsSync, mkdirSync } from 'fs';

const screenshotDir = './scratch';
if (!existsSync(screenshotDir)) mkdirSync(screenshotDir, { recursive: true });

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function run() {
  console.log('--- STARTING SHIP MODELS VERIFICATION SUITE ---');
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

  // 1. Open Armory and verify "🚀 Ship Models" Tab
  console.log('\n1. Testing Armory Ship Models tab...');
  await page.evaluate(() => {
    window.__TILT_GAME__.openArmory();
  });
  await delay(300);

  // Click on "🚀 Ship Models" tab
  await page.evaluate(() => {
    const tabs = Array.from(document.querySelectorAll('.armory-tab-btn'));
    const shipTab = tabs.find(t => t.textContent.includes('Ship Models'));
    if (shipTab) shipTab.click();
  });
  await delay(300);

  const shipTabState = await page.evaluate(() => {
    const cards = Array.from(document.querySelectorAll('.catalog-card'));
    const shipTitles = cards.map(c => c.querySelector('h4')?.textContent?.trim());
    const svgPreviews = cards.map(c => !!c.querySelector('.ship-preview-svg'));
    return {
      cardsCount: cards.length,
      shipTitles,
      allHaveSvgPreviews: svgPreviews.every(Boolean)
    };
  });

  console.log('Ship Models Tab state:', shipTabState);
  if (shipTabState.cardsCount !== 7) throw new Error(`Expected 7 ship models, got ${shipTabState.cardsCount}`);
  if (!shipTabState.allHaveSvgPreviews) throw new Error('Some ship cards are missing SVG vector previews');

  await page.screenshot({ path: `${screenshotDir}/ship_01_armory_hangar.png` });
  console.log('📸 Captured ship_01_armory_hangar.png');
  console.log('✅ PASS: Armory Ship Models hangar verified with all 7 custom ship models!');

  // 2. Unlock and Equip Viper Interceptor
  console.log('\n2. Testing Unlocking & Piloting Viper Interceptor...');
  const viperResult = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    game.progression.addPoints(50);
    const bought = game.progression.buyShip('tactical');
    const equipped = game.progression.equipShip('tactical');
    const curShip = game.progression.getEquippedShip();
    return { bought, equipped, curShipId: curShip.id, curShipName: curShip.name, curShipShape: curShip.shape };
  });
  console.log('Viper equip result:', viperResult);
  if (viperResult.curShipId !== 'tactical' || viperResult.curShipShape !== 'viper') {
    throw new Error('Failed to equip Viper Interceptor');
  }

  // Close Armory and launch game to inspect Viper in-game
  await page.evaluate(() => {
    window.__TILT_GAME__.closeArmory();
    window.__TILT_GAME__.launchRun('classic');
  });
  await delay(1200);

  // Position player and render frame
  await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    game.player.reset(400, 300);
    game.player.angle = -Math.PI / 4; // Point diagonally for nice view
    game.render();
  });
  await delay(200);
  await page.screenshot({ path: `${screenshotDir}/ship_02_viper_in_game.png` });
  console.log('📸 Captured ship_02_viper_in_game.png (Viper Interceptor in gameplay)');

  // 3. Test Celestial Sovereign
  console.log('\n3. Testing Celestial Sovereign with floating halo ring...');
  await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    game.progression.buyShip('celestial');
    game.progression.equipShip('celestial');
    game.render();
  });
  await delay(200);
  await page.screenshot({ path: `${screenshotDir}/ship_03_celestial_in_game.png` });
  console.log('📸 Captured ship_03_celestial_in_game.png (Celestial Sovereign in gameplay)');

  // 4. Test Singularity Phantom
  console.log('\n4. Testing Singularity Phantom stealth voidcraft...');
  await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    game.progression.buyShip('singularity');
    game.progression.equipShip('singularity');
    game.render();
  });
  await delay(200);
  await page.screenshot({ path: `${screenshotDir}/ship_04_phantom_in_game.png` });
  console.log('📸 Captured ship_04_phantom_in_game.png (Singularity Phantom in gameplay)');

  // 5. Test Solar Aegis
  console.log('\n5. Testing Solar Aegis gold battlecruiser...');
  await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    game.progression.buyShip('solar');
    game.progression.equipShip('solar');
    game.render();
  });
  await delay(200);
  await page.screenshot({ path: `${screenshotDir}/ship_05_solar_in_game.png` });
  console.log('📸 Captured ship_05_solar_in_game.png (Solar Aegis in gameplay)');

  console.log('\n======================================================');
  console.log('ALL SHIP MODEL TESTS PASSED SUCCESSFULLY! 🚀');
  console.log('======================================================');

  await browser.close();
}

run().catch((err) => {
  console.error('VERIFICATION FAILED:', err);
  process.exit(1);
});
