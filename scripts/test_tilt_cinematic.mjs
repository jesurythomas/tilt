// =========================================================================
// test_tilt_cinematic.mjs - Tilt to Live Space Invaders Cinematic Test
// =========================================================================

import puppeteer from 'puppeteer';
import { existsSync, mkdirSync } from 'fs';

const screenshotDir = 'C:/Users/Jesury/.gemini/antigravity/brain/2c867d21-b23f-424b-83e4-19f99b8e761a/scratch';
if (!existsSync(screenshotDir)) mkdirSync(screenshotDir, { recursive: true });

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function run() {
  console.log('--- STARTING TILT TO LIVE SPACE INVADERS CINEMATIC TEST ---');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--enable-webgl',
      '--use-gl=angle',
      '--use-angle=d3d11',
      '--no-sandbox',
      '--disable-setuid-sandbox'
    ]
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });

  page.on('console', (msg) => {
    if (msg.type() === 'error') console.error('BROWSER ERROR:', msg.text());
  });

  await page.goto('http://localhost:5173', { waitUntil: 'networkidle0' });
  await delay(600);

  // 1. Launch Tilt to Live
  console.log('Launching Tilt to Live from arcade portal...');
  await page.click('#card-tilt-to-live .choice-launch');
  await delay(300);

  // 2. Verify Cinematic State & Overlay
  const cinematicInit = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.tiltGame;
    const overlay = document.getElementById('tilt-cinematic-overlay');
    return {
      phase: g.phase,
      isCinematicPlaying: g.cinematic.isPlaying,
      overlayVisible: !overlay?.classList.contains('hidden')
    };
  });
  console.log('Cinematic Init State:', cinematicInit);
  if (cinematicInit.phase !== 'cinematic') throw new Error(`Expected phase 'cinematic', got ${cinematicInit.phase}`);
  if (!cinematicInit.overlayVisible) throw new Error('Tilt cinematic overlay should be visible');

  // Capture Stage 1: The Space Invader March
  await page.screenshot({ path: `${screenshotDir}/tilt_cinematic_01_invaders_march.png` });
  console.log('📸 Captured tilt_cinematic_01_invaders_march.png (Space Invaders March)');

  // 3. Wait 1.3s for Stage 2: Hyperspace Warp-In
  await delay(1300);
  const stage2State = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.tiltGame;
    return {
      phase: g.phase,
      elapsed: g.cinematic.elapsed,
      shipX: g.player.x,
      shipY: g.player.y
    };
  });
  console.log('Cinematic Stage 2 (Hyperspace Warp):', stage2State);

  await page.screenshot({ path: `${screenshotDir}/tilt_cinematic_02_warp_in.png` });
  console.log('📸 Captured tilt_cinematic_02_warp_in.png (Player Ship Warp-In)');

  // 4. Wait 1.0s for Stage 3: Armada Scatter & "READY... GO!"
  await delay(1000);
  await page.screenshot({ path: `${screenshotDir}/tilt_cinematic_03_ready_go.png` });
  console.log('📸 Captured tilt_cinematic_03_ready_go.png (Scatter & READY... GO!)');

  // 5. Wait for Cinematic Completion -> Smooth Handoff to Active Playing
  await delay(1200);
  const playingState = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.tiltGame;
    const overlay = document.getElementById('tilt-cinematic-overlay');
    return {
      phase: g.phase,
      overlayHidden: overlay?.classList.contains('hidden'),
      enemiesCount: g.swarm.enemies.length,
      orbsCount: g.weapons.orbs.length
    };
  });
  console.log('Post-Cinematic Playing State:', playingState);
  if (playingState.phase !== 'playing') throw new Error(`Expected phase 'playing', got ${playingState.phase}`);
  if (!playingState.overlayHidden) throw new Error('Cinematic overlay should be hidden');
  if (playingState.enemiesCount === 0) throw new Error('Enemies should have spawned from scattered invaders');

  await page.screenshot({ path: `${screenshotDir}/tilt_cinematic_04_playing.png` });
  console.log('📸 Captured tilt_cinematic_04_playing.png (Active Combat Started)');

  // 6. Test Quick Skip on restart
  console.log('Testing Quick Skip on restart...');
  await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.tiltGame;
    g.restart();
  });
  await delay(200);

  const beforeSkip = await page.evaluate(() => window.__PORTAL_MANAGER__.tiltGame.phase);
  console.log('Phase before skip:', beforeSkip);
  if (beforeSkip !== 'cinematic') throw new Error(`Expected cinematic phase on restart, got ${beforeSkip}`);

  // Press Space to skip
  await page.keyboard.press('Space');
  await delay(100);

  const afterSkip = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.tiltGame;
    return {
      phase: g.phase,
      isPlaying: !g.cinematic.isPlaying
    };
  });
  console.log('Phase after skip:', afterSkip);
  if (afterSkip.phase !== 'playing') throw new Error(`Expected phase 'playing' after skip, got ${afterSkip.phase}`);

  await browser.close();
  console.log('\n======================================================');
  console.log('🎉 TILT TO LIVE SPACE INVADERS CINEMATIC VERIFIED 100% WORKING!');
  console.log('======================================================');
}

run().catch((err) => {
  console.error('TEST FAILED:', err);
  process.exit(1);
});
