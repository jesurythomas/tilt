import puppeteer from 'puppeteer';
import { preview } from 'vite';
import fs from 'fs';
import path from 'path';

const screenshotDir = path.resolve('scratch/redesign_verification');
fs.mkdirSync(screenshotDir, { recursive: true });

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function main() {
  console.log('--- STARTING IN-PROCESS VITE PREVIEW SERVER ---');
  const server = await preview({
    root: '.',
    preview: { port: 5173, strictPort: true }
  });

  const serverUrl = server.resolvedUrls.local[0];
  console.log(`Server listening on ${serverUrl}`);

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1440, height: 900 });

    page.on('console', (msg) => {
      if (msg.type() === 'error') console.error('[Browser console error]:', msg.text());
    });

    console.log(`Navigating to ${serverUrl} ...`);
    await page.goto(serverUrl, { waitUntil: 'networkidle0' });
    await delay(500);

    // 1. Desktop Start Menu
    console.log('Capturing: 01_desktop_start_menu.png');
    await page.screenshot({ path: path.join(screenshotDir, '01_desktop_start_menu.png') });

    // 2. Open Settings modal
    console.log('Opening Settings...');
    await page.click('#btn-menu-options');
    await delay(500);
    console.log('Capturing: 02_settings_modal.png');
    await page.screenshot({ path: path.join(screenshotDir, '02_settings_modal.png') });

    // Close Settings
    console.log('Closing Settings...');
    await page.click('#btn-close-options');
    await delay(300);

    // 3. Open Milestones modal
    console.log('Opening Milestones...');
    await page.click('#btn-menu-goals');
    await delay(500);
    console.log('Capturing: 03_milestones_modal.png');
    await page.screenshot({ path: path.join(screenshotDir, '03_milestones_modal.png') });

    // Close Milestones
    console.log('Closing Milestones...');
    await page.click('#btn-close-milestones');
    await delay(300);

    // 4. Open Armory - Weapons tab
    console.log('Opening Armory (Weapons)...');
    await page.click('#btn-menu-armory');
    await delay(500);
    console.log('Capturing: 04_armory_weapons.png');
    await page.screenshot({ path: path.join(screenshotDir, '04_armory_weapons.png') });

    // 5. Armory - Ships tab
    console.log('Switching to Armory (Ships)...');
    await page.click('.armory-v2-tab[data-tab="ships"]');
    await delay(500);
    console.log('Capturing: 05_armory_ships.png');
    await page.screenshot({ path: path.join(screenshotDir, '05_armory_ships.png') });

    // 6. Armory - Handling tab
    console.log('Switching to Armory (Handling)...');
    await page.click('.armory-v2-tab[data-tab="handling"]');
    await delay(500);
    console.log('Capturing: 06_armory_handling.png');
    await page.screenshot({ path: path.join(screenshotDir, '06_armory_handling.png') });

    // Close Armory
    console.log('Closing Armory...');
    await page.click('#btn-armory-close');
    await delay(300);

    // 7. Launch game -> Cold Open
    console.log('Launching Game -> Cold Open...');
    await page.click('#btn-menu-launch');
    await delay(250);
    console.log('Capturing: 07_cold_open.png');
    await page.screenshot({ path: path.join(screenshotDir, '07_cold_open.png') });

    // Wait for Cold Open to finish and gameplay to start
    await delay(800);

    // 8. In-Run HUD
    console.log('Capturing: 08_in_run_hud.png');
    await page.screenshot({ path: path.join(screenshotDir, '08_in_run_hud.png') });

    // 9. Pause overlay
    console.log('Pausing game...');
    await page.keyboard.press('Escape');
    await delay(400);
    console.log('Capturing: 09_pause_overlay.png');
    await page.screenshot({ path: path.join(screenshotDir, '09_pause_overlay.png') });

    // Resume game
    await page.keyboard.press('Escape');
    await delay(300);

    // 10. Trigger death / Run Over
    console.log('Triggering player death for Run Over screen...');
    await page.evaluate(() => {
      window.__TILT_GAME__.triggerPlayerDeath();
    });
    await delay(700);
    console.log('Capturing: 10_run_over_screen.png');
    await page.screenshot({ path: path.join(screenshotDir, '10_run_over_screen.png') });

    // 11. Mobile Viewport Check (390x844)
    console.log('Setting mobile viewport (390x844)...');
    await page.setViewport({ width: 390, height: 844 });
    await page.evaluate(() => {
      window.__TILT_GAME__.returnToMenu();
    });
    await delay(500);
    console.log('Capturing: 11_mobile_menu.png');
    await page.screenshot({ path: path.join(screenshotDir, '11_mobile_menu.png') });

    console.log('--- ALL VISUAL VERIFICATIONS COMPLETED SUCCESSFULLY ---');
  } finally {
    await browser.close();
    await server.close();
  }
}

main().catch(err => {
  console.error('Verification failed:', err);
  process.exit(1);
});
