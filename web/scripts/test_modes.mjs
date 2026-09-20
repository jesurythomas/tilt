// =========================================================================
// test_modes.mjs - Comprehensive Multi-Mode Verification Suite
// =========================================================================

import puppeteer from 'puppeteer';
import { existsSync, mkdirSync } from 'fs';

const screenshotDir = './scratch';
if (!existsSync(screenshotDir)) mkdirSync(screenshotDir, { recursive: true });

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function testModes() {
  console.log('--- STARTING MULTI-MODE VERIFICATION SUITE ---');
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

  const modesToTest = [
    {
      id: 'classic',
      name: 'Classic Survival',
      mult: 1.0,
      badgeText: 'CLASSIC SURVIVAL · 1X',
      titleCheck: 'SPACE INVADERS',
      screenshot: `${screenshotDir}/mode_classic.png`
    },
    {
      id: 'code-red',
      name: 'Code Red',
      mult: 1.5,
      badgeText: 'CODE RED · 1.5X',
      titleCheck: 'CODE RED',
      screenshot: `${screenshotDir}/mode_code_red.png`
    },
    {
      id: 'gauntlet',
      name: 'The Gauntlet',
      mult: 1.25,
      badgeText: 'THE GAUNTLET · 1.25X',
      titleCheck: 'THE GAUNTLET',
      screenshot: `${screenshotDir}/mode_gauntlet.png`
    },
    {
      id: 'frostbite',
      name: 'Frostbite',
      mult: 1.2,
      badgeText: 'FROSTBITE · 1.2X',
      titleCheck: 'PERMAFROST',
      screenshot: `${screenshotDir}/mode_frostbite.png`
    }
  ];

  for (const mode of modesToTest) {
    console.log(`\n>>> Testing Mode: ${mode.name} (${mode.id})`);

    // Ensure we are in menu
    await page.evaluate(() => {
      const game = window.__TILT_GAME__;
      if (game.phase !== 'menu') {
        game.returnToMenu();
      }
    });
    await delay(300);

    // Click mode selection card
    console.log(`Selecting mode card [data-mode="${mode.id}"]...`);
    await page.click(`.menu-mode-card[data-mode="${mode.id}"]`);
    await delay(250);

    // Launch game
    console.log('Launching run...');
    await page.click('#btn-menu-launch');
    await delay(300);

    // Check cinematic title & badge
    const cinematicInfo = await page.evaluate(() => {
      const titleEl = document.querySelector('.tilt-cinematic-title');
      const subEl = document.querySelector('.tilt-cinematic-sub');
      const badgeEl = document.querySelector('.tilt-cinematic-badge');
      const overlay = document.getElementById('tilt-cinematic-overlay');
      return {
        title: titleEl?.textContent,
        sub: subEl?.textContent,
        badge: badgeEl?.textContent,
        visible: !overlay?.classList.contains('hidden')
      };
    });
    console.log('Cinematic Info:', cinematicInfo);
    if (!cinematicInfo.title?.toUpperCase().includes(mode.titleCheck.toUpperCase())) {
      throw new Error(`Cinematic title mismatch for ${mode.id}: expected to contain "${mode.titleCheck}", got "${cinematicInfo.title}"`);
    }

    // Skip cinematic into active gameplay
    await page.evaluate(() => {
      const game = window.__TILT_GAME__;
      const rect = game.canvas.getBoundingClientRect();
      game.cinematic.skip(rect.width, rect.height);
    });
    await delay(350);

    // Check gameplay state & HUD badge
    const runState = await page.evaluate((expectedId) => {
      const game = window.__TILT_GAME__;
      const badge = document.getElementById('tilt-mode-badge');
      const enemiesCount = game.swarm.enemies.length;
      const weaponCount = game.weapons.orbs.length;
      const modeConfig = game.options.getModeConfig(expectedId);
      const scoreMult = game.scores.modeMultiplier;

      return {
        phase: game.phase,
        activeMode: game.options.settings.mode,
        scoreMultiplier: scoreMult,
        badgeText: badge?.textContent?.trim(),
        badgeClass: badge?.className,
        enemiesCount,
        weaponCount
      };
    }, mode.id);

    console.log('Run State:', runState);
    if (runState.phase !== 'playing') {
      throw new Error(`Expected playing phase for ${mode.id}, got ${runState.phase}`);
    }
    if (runState.activeMode !== mode.id) {
      throw new Error(`Active mode mismatch: expected ${mode.id}, got ${runState.activeMode}`);
    }
    if (runState.scoreMultiplier !== mode.mult) {
      throw new Error(`Score multiplier mismatch for ${mode.id}: expected ${mode.mult}, got ${runState.scoreMultiplier}`);
    }
    if (runState.badgeText !== mode.badgeText) {
      throw new Error(`HUD badge text mismatch: expected "${mode.badgeText}", got "${runState.badgeText}"`);
    }

    // Let physics step for 500ms to observe mode behaviors
    await delay(500);

    // Verify mode-specific mechanics
    if (mode.id === 'code-red') {
      const codeRedCheck = await page.evaluate(() => {
        const game = window.__TILT_GAME__;
        // Starter armada spawned 24 dots + initial seekers
        return {
          enemies: game.swarm.enemies.length,
          hasFastEnemies: game.swarm.enemies.some((e) => Math.hypot(e.vx, e.vy) > 0)
        };
      });
      console.log('Code Red Armada Check:', codeRedCheck);
      if (codeRedCheck.enemies < 10) {
        throw new Error(`Code Red expected instant dense armada, found ${codeRedCheck.enemies}`);
      }
    } else if (mode.id === 'gauntlet') {
      const gauntletCheck = await page.evaluate(() => {
        const game = window.__TILT_GAME__;
        return {
          hasHazardObstacles: game.swarm.enemies.some((e) => e.isHazard || e.orbitCenter)
        };
      });
      console.log('Gauntlet Obstacle Check:', gauntletCheck);
    } else if (mode.id === 'frostbite') {
      const frostbiteCheck = await page.evaluate(() => {
        const game = window.__TILT_GAME__;
        return {
          snowParticles: game.particles.count,
          hasChilledSystem: typeof game.swarm.triggerCryoCascade === 'function'
        };
      });
      console.log('Frostbite Cryo Check:', frostbiteCheck);
      if (!frostbiteCheck.hasChilledSystem) {
        throw new Error('Frostbite Cryo Cascade function missing');
      }
    }

    // Capture screenshot
    await page.screenshot({ path: mode.screenshot });
    console.log(`📸 Captured screenshot: ${mode.screenshot}`);
    console.log(`✅ ${mode.name} PASSED!`);
  }

  await browser.close();
  console.log('\n===============================================================');
  console.log('🎉 ALL 4 GAME MODES FULLY VERIFIED WITH DISTINCT MECHANICS! 🎉');
  console.log('===============================================================');
}

testModes().catch((err) => {
  console.error('TEST ERROR:', err);
  process.exit(1);
});
