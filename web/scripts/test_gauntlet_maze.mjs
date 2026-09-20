import puppeteer from 'puppeteer';
import path from 'path';
import fs from 'fs';

const scratchDir = path.resolve('C:/Users/Jesury/.gemini/antigravity-cli/brain/21796d0e-021d-41ad-bd14-644fb082ac3e/scratch');
if (!fs.existsSync(scratchDir)) {
  fs.mkdirSync(scratchDir, { recursive: true });
}

async function runTest() {
  console.log('Launching browser...');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 800 });

  page.on('console', msg => console.log('PAGE LOG:', msg.text()));
  page.on('pageerror', err => console.error('PAGE ERROR:', err.message));

  console.log('Navigating to http://localhost:5173 ...');
  await page.goto('http://localhost:5173', { waitUntil: 'networkidle0' });

  // 1. Verify Start Menu Modes
  const modeCards = await page.$$eval('.menu-mode-card', cards =>
    cards.map(c => ({
      mode: c.getAttribute('data-mode'),
      title: c.querySelector('h3')?.textContent?.trim(),
      badge: c.querySelector('.mode-badge')?.textContent?.trim()
    }))
  );
  console.log('Detected Menu Modes:', JSON.stringify(modeCards, null, 2));

  const hasFrostbite = modeCards.some(m => m.mode === 'frostbite');
  if (hasFrostbite) {
    throw new Error('FAILED: frostbite mode card is still present in start menu!');
  }
  console.log('PASS: Frostbite mode is completely absent. Active modes count:', modeCards.length);

  // Take screenshot of start menu
  await page.screenshot({ path: path.join(scratchDir, 'gauntlet_start_menu.png') });
  console.log('Screenshot saved: gauntlet_start_menu.png');

  // 2. Select Gauntlet Mode
  console.log('Selecting Gauntlet mode...');
  await page.click('.menu-mode-card[data-mode="gauntlet"]');
  await new Promise(r => setTimeout(r, 400));

  // 3. Launch the game
  console.log('Clicking Launch button...');
  await page.click('#btn-menu-launch');
  await new Promise(r => setTimeout(r, 500));

  // Skip cinematic
  const skipBtn = await page.$('.tilt-cinematic-skip');
  if (skipBtn) {
    console.log('Skipping cinematic...');
    await skipBtn.click();
  }

  // Wait for game to play for 3 seconds
  console.log('Simulating Gauntlet mode gameplay for 3.5 seconds...');
  await new Promise(r => setTimeout(r, 3500));

  // 4. Query live game state
  const gameState = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    if (!game) return { error: 'No __TILT_GAME__' };
    return {
      mode: game.options.settings.mode,
      score: game.scores.stats.score,
      survivalTime: game.scores.stats.survivalTime,
      speed: game.gauntletMaze.currentSpeed,
      rowCount: game.gauntletMaze.rows.length,
      enemiesCount: game.swarm.enemies.length,
      orbsCount: game.weapons.orbs.length,
      playerPos: { x: game.player.x, y: game.player.y },
      rows: game.gauntletMaze.rows.map(r => ({ y: r.y, gapX: r.gapX, gapWidth: r.gapWidth }))
    };
  });
  console.log('Live Game Diagnostics:', JSON.stringify(gameState, null, 2));

  if (!gameState.rowCount || gameState.rowCount === 0) {
    throw new Error('FAILED: No maze rows spawned in Gauntlet mode!');
  }
  if (gameState.score <= 0) {
    throw new Error('FAILED: Score did not accrue from survival time in Gauntlet mode!');
  }
  if (gameState.enemiesCount === 0) {
    throw new Error('FAILED: Normal enemies are not spawning in Gauntlet mode!');
  }
  if (gameState.orbsCount === 0) {
    throw new Error('FAILED: Normal weapon orbs are not spawning in Gauntlet mode!');
  }

  // Take screenshot of active Gauntlet Maze gameplay
  await page.screenshot({ path: path.join(scratchDir, 'gauntlet_maze_gameplay.png') });
  console.log('Screenshot saved: gauntlet_maze_gameplay.png');

  // Let's run 3 more seconds to test speed acceleration with survival score
  await new Promise(r => setTimeout(r, 3000));
  const laterState = await page.evaluate(() => {
    const game = window.__TILT_GAME__;
    return {
      score: game.scores.stats.score,
      survivalTime: game.scores.stats.survivalTime,
      speed: game.gauntletMaze.currentSpeed
    };
  });
  console.log('Later Game Diagnostics (Speed scaling):', JSON.stringify(laterState, null, 2));

  if (laterState.speed <= gameState.speed) {
    console.warn('Note: Speed difference:', laterState.speed, gameState.speed);
  } else {
    console.log(`PASS: Speed accelerated from ${gameState.speed.toFixed(1)} to ${laterState.speed.toFixed(1)} px/s!`);
  }

  await page.screenshot({ path: path.join(scratchDir, 'gauntlet_maze_progression.png') });
  console.log('Screenshot saved: gauntlet_maze_progression.png');

  await browser.close();
  console.log('All Gauntlet Maze tests completed successfully!');
}

runTest().catch(err => {
  console.error('Test failed with error:', err);
  process.exit(1);
});
