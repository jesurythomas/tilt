import puppeteer from 'puppeteer';
import path from 'path';
import fs from 'fs';

const scratchDir = path.resolve('C:/Users/Jesury/.gemini/antigravity-cli/brain/21796d0e-021d-41ad-bd14-644fb082ac3e/scratch');
if (!fs.existsSync(scratchDir)) {
  fs.mkdirSync(scratchDir, { recursive: true });
}

async function testGridless() {
  console.log('--- Testing Gridless Background & Visibility ---');
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

  // Clear any existing settings in localStorage to test fresh default
  await page.goto('http://localhost:5173', { waitUntil: 'networkidle0' });
  await page.evaluate(() => {
    localStorage.removeItem('tilt_to_live_settings_v1');
  });
  await page.reload({ waitUntil: 'networkidle0' });

  // 1. Verify Game Options Modal has Grid toggle & defaults to DISABLED
  console.log('Checking Game Options modal...');
  await page.click('#btn-menu-options');
  await new Promise(r => setTimeout(r, 300));

  const gridBtnText = await page.$eval('#opt-toggle-grid', el => el.innerText.trim());
  console.log('Default Background Grid toggle state:', gridBtnText);
  if (!gridBtnText.includes('DISABLED')) {
    throw new Error(`Expected grid toggle to be DISABLED by default, got: ${gridBtnText}`);
  }

  // Take screenshot of options modal
  await page.screenshot({ path: path.join(scratchDir, 'verify_options_grid_toggle.png') });

  // Close options
  await page.click('#btn-close-options');
  await new Promise(r => setTimeout(r, 300));

  // 2. Launch Gauntlet mode without gridlines
  console.log('Selecting Gauntlet Mode and Launching...');
  await page.click('.menu-mode-card[data-mode="gauntlet"]');
  await new Promise(r => setTimeout(r, 300));
  await page.click('#btn-menu-launch');
  await new Promise(r => setTimeout(r, 500));

  const skipBtn = await page.$('.tilt-cinematic-skip');
  if (skipBtn) await skipBtn.click();

  // Play for 3 seconds
  await new Promise(r => setTimeout(r, 3000));

  // Verify game options in memory has showGridlines: false
  const showGridlinesInMemory = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    return game.options.settings.showGridlines;
  });
  console.log('showGridlines in memory:', showGridlinesInMemory);
  if (showGridlinesInMemory !== false) {
    throw new Error('showGridlines in memory should be false');
  }

  // Capture screenshot of clean, pristine, gridless arena gameplay
  await page.screenshot({ path: path.join(scratchDir, 'verify_gridless_arena_gameplay.png') });
  console.log('Screenshot saved: verify_gridless_arena_gameplay.png');

  // 3. Launch Classic Survival as well to capture clean classic arena
  await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    game.returnToMenu();
  });
  await new Promise(r => setTimeout(r, 500));

  await page.click('.menu-mode-card[data-mode="classic"]');
  await new Promise(r => setTimeout(r, 300));
  await page.click('#btn-menu-launch');
  await new Promise(r => setTimeout(r, 500));

  await page.evaluate(() => {
    const btn = document.querySelector('.tilt-cinematic-skip');
    if (btn) btn.click();
  });

  await new Promise(r => setTimeout(r, 3000));
  await page.screenshot({ path: path.join(scratchDir, 'verify_gridless_classic_gameplay.png') });
  console.log('Screenshot saved: verify_gridless_classic_gameplay.png');

  await browser.close();
  console.log('--- ALL GRIDLESS BACKGROUND TESTS PASSED ---');
}

testGridless().catch(err => {
  console.error('Test error:', err);
  process.exit(1);
});
