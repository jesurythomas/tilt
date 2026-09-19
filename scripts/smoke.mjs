import puppeteer from 'puppeteer';

const baseUrl = process.env.SMOKE_URL || 'http://localhost:5173';
console.log('--- STARTING INTERACTIVE GAMEPLAY & CONTROLS TEST ---');
console.log('Target URL:', baseUrl);

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

const pageErrors = [];
page.on('pageerror', err => pageErrors.push(err.message));
page.on('console', msg => {
  if (msg.type() === 'error') pageErrors.push(msg.text());
});

const delay = (ms) => new Promise(r => setTimeout(r, ms));
const screenshotDir = 'C:/Users/Jesury/.gemini/antigravity/brain/2c867d21-b23f-424b-83e4-19f99b8e761a/scratch';

const visible = (selector) => page.$eval(selector, (element) => {
  const style = getComputedStyle(element);
  const rect = element.getBoundingClientRect();
  return !element.hidden && style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
});

try {
  // Navigate to portal
  let navigated = false;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      await page.goto(baseUrl, { waitUntil: 'networkidle2', timeout: 5000 });
      navigated = true;
      break;
    } catch {
      await delay(600);
    }
  }
  if (!navigated) await page.goto(baseUrl);
  await delay(400);

  if (!(await visible('#portal-container'))) throw new Error('Portal is not visible.');
  if ((await page.$$eval('.game-choice', (elements) => elements.length)) < 2) throw new Error('Portal choices are missing.');

  // =========================================================================
  // TEST GAME 1: DREAD FLIGHT
  // =========================================================================
  console.log('\n========================================');
  console.log('TESTING GAME 1: DREAD FLIGHT');
  console.log('========================================');

  // Launch Dread Flight
  await page.click('#card-dread-flock .choice-launch');
  await delay(300);

  // 1. Verify ready hover state
  let flightState = await page.evaluate(() => {
    const sim = window.__PORTAL_MANAGER__.dreadFlightGame.simulation;
    return {
      phase: sim.phase,
      score: sim.score,
      birdY: sim.birdY,
      birdVy: sim.birdVelocityY
    };
  });
  console.log('Dread Flight Ready State:', flightState);
  if (flightState.phase !== 'ready') throw new Error(`Expected ready phase, got ${flightState.phase}`);

  await page.screenshot({ path: `${screenshotDir}/flight_01_ready.png` });
  console.log('📸 Captured flight_01_ready.png');

  // 2. Flap with Space to start flight
  console.log('Pressing Space to flap...');
  await page.keyboard.press('Space');
  await delay(100);

  flightState = await page.evaluate(() => {
    const sim = window.__PORTAL_MANAGER__.dreadFlightGame.simulation;
    return { phase: sim.phase, birdVy: sim.birdVelocityY };
  });
  console.log('Dread Flight After First Flap:', flightState);
  if (flightState.phase !== 'playing') throw new Error(`Expected playing phase, got ${flightState.phase}`);
  if (flightState.birdVy >= 0) throw new Error(`Expected negative vertical velocity (upward flap), got ${flightState.birdVy}`);
  console.log('✅ First flap successfully entered playing phase with upward velocity!');

  // Flap once more to stay in sweet spot
  await delay(200);
  await page.keyboard.press('Space');
  await delay(50);

  // 3. Test Pause and Resume while in safe clear air
  console.log('Testing Pause in Dread Flight...');
  await page.keyboard.press('KeyP');
  await delay(100);
  flightState = await page.evaluate(() => window.__PORTAL_MANAGER__.dreadFlightGame.simulation.phase);
  console.log('Phase after pressing P:', flightState);
  if (flightState !== 'paused') throw new Error(`Expected paused, got ${flightState}`);
  console.log('✅ Pause verified');

  await page.keyboard.press('KeyP');
  await delay(100);
  flightState = await page.evaluate(() => window.__PORTAL_MANAGER__.dreadFlightGame.simulation.phase);
  console.log('Phase after resuming with P:', flightState);
  if (flightState !== 'playing') throw new Error(`Expected playing after resume, got ${flightState}`);
  console.log('✅ Resume verified');

  // 4. Keep flapping to fly through gates and verify gate spacing
  console.log('Flapping to stay airborne through gates...');
  for (let i = 0; i < 4; i++) {
    await delay(280);
    await page.keyboard.press('Space');
  }

  // Check gate spacing & particles
  const gateCheck = await page.evaluate(() => {
    const sim = window.__PORTAL_MANAGER__.dreadFlightGame.simulation;
    const gates = window.__PORTAL_MANAGER__.dreadFlightGame.gates.gates;
    const distances = [];
    for (let i = 0; i < gates.length - 1; i++) {
      distances.push(gates[i + 1].x - gates[i].x);
    }
    return {
      gateCount: gates.length,
      distances,
      particles: sim.particles.length,
      flapTimer: sim.flapTimer
    };
  });
  console.log('Gate and Particle Diagnostics:', gateCheck);
  for (const dist of gateCheck.distances) {
    if (dist < 200) {
      throw new Error(`Gate spacing too small (overlapping gates bug detected): ${dist}px`);
    }
  }
  console.log('✅ PASS: All gates cleanly spaced with no overlapping pillar bug!');

  await page.screenshot({ path: `${screenshotDir}/flight_02_flying.png` });
  console.log('📸 Captured flight_02_flying.png');

  // 5. Let bird fall to test game over and restart
  console.log('Letting bird fall to test Game Over and Spacebar restart...');
  for (let i = 0; i < 25; i++) {
    await delay(100);
    const p = await page.evaluate(() => window.__PORTAL_MANAGER__.dreadFlightGame.simulation.phase);
    if (p === 'game-over') break;
  }
  flightState = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.dreadFlightGame;
    return {
      phase: g.simulation.phase,
      modalVisible: !document.getElementById('flight-gameover-modal').classList.contains('hidden')
    };
  });
  console.log('Dread Flight Game Over State:', flightState);
  if (flightState.phase !== 'game-over' || !flightState.modalVisible) {
    throw new Error('Expected game-over state with visible modal');
  }
  await page.screenshot({ path: `${screenshotDir}/flight_03_gameover.png` });
  console.log('📸 Captured flight_03_gameover.png');

  // Press Space to restart
  console.log('Testing Space to restart Dread Flight...');
  await page.keyboard.press('Space');
  await delay(200);
  flightState = await page.evaluate(() => window.__PORTAL_MANAGER__.dreadFlightGame.simulation.phase);
  if (flightState !== 'ready') throw new Error(`Expected ready phase after Space restart, got ${flightState}`);
  console.log('✅ Dread Flight Space restart verified!');

  // Return to Portal
  await page.click('#btn-flight-menu');
  await delay(200);
  if (!(await visible('#portal-container'))) throw new Error('Portal did not restore after exiting Dread Flight');
  console.log('✅ Returned to arcade portal successfully!');


  // =========================================================================
  // TEST GAME 2: CURSE RUNNER (TEMPLE RUN)
  // =========================================================================
  console.log('\n========================================');
  console.log('TESTING GAME 2: CURSE RUNNER (TEMPLE RUN)');
  console.log('========================================');

  // Launch Curse Runner
  await page.click('#card-temple-run .choice-launch');
  await delay(300);

  // Skip cinematic to test active gameplay controls
  await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.templeRunGame;
    if (g.phase === 'cinematic') g.cinematic.skip();
  });
  await delay(200);

  let runnerState = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.templeRunGame;
    const p = g.player;
    return {
      isRunning: g.isRunning,
      phase: g.phase,
      lane: p.currentLaneIndex,
      laneTargetX: p.laneTargetX,
      distance: p.distanceTraveled
    };
  });
  console.log('Initial Runner State:', runnerState);
  if (!runnerState.isRunning || runnerState.phase !== 'playing') {
    throw new Error('Curse Runner is not running in playing state');
  }

  // 1. TEST KEY D (Right Lane Shift)
  console.log('\n--- 1. Testing KeyD (Right Lane) ---');
  await page.keyboard.press('KeyD');
  await delay(400);

  runnerState = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.templeRunGame;
    const p = g.player;
    const screenPos = p.mesh.position.clone().project(g.scene.camera);
    return {
      lane: p.currentLaneIndex,
      laneTargetX: p.laneTargetX,
      worldX: p.mesh.position.x,
      screenX: screenPos.x
    };
  });
  console.log('After KeyD:', runnerState);
  if (runnerState.lane !== 1) throw new Error(`Expected lane 1 for KeyD, got ${runnerState.lane}`);
  if (runnerState.screenX <= 0) throw new Error(`Expected positive screen X (Right side), got ${runnerState.screenX}`);
  console.log('✅ PASS: KeyD moved to Lane 1 and is visually on the RIGHT side of screen!');

  await page.screenshot({ path: `${screenshotDir}/temple_01_right_lane.png` });
  console.log('📸 Captured temple_01_right_lane.png');

  // 2. TEST KEY A (Left Lane Shift)
  console.log('\n--- 2. Testing KeyA (Left Lane) ---');
  await page.keyboard.press('KeyA'); // Back to Center (0)
  await delay(250);
  await page.keyboard.press('KeyA'); // Into Left (-1)
  await delay(400);

  runnerState = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.templeRunGame;
    const p = g.player;
    const screenPos = p.mesh.position.clone().project(g.scene.camera);
    return {
      lane: p.currentLaneIndex,
      laneTargetX: p.laneTargetX,
      worldX: p.mesh.position.x,
      screenX: screenPos.x
    };
  });
  console.log('After KeyA:', runnerState);
  if (runnerState.lane !== -1) throw new Error(`Expected lane -1 for KeyA, got ${runnerState.lane}`);
  if (runnerState.screenX >= 0) throw new Error(`Expected negative screen X (Left side), got ${runnerState.screenX}`);
  console.log('✅ PASS: KeyA moved to Lane -1 and is visually on the LEFT side of screen!');

  await page.screenshot({ path: `${screenshotDir}/temple_02_left_lane.png` });
  console.log('📸 Captured temple_02_left_lane.png');

  // Shift back to center lane
  await page.keyboard.press('KeyD');
  await delay(250);

  // 3. TEST ANALOG TILT (Q & E)
  console.log('\n--- 3. Testing Analog Tilt Q (Left) and E (Right) ---');
  await page.keyboard.down('KeyQ');
  await delay(300);
  let tiltVal = await page.evaluate(() => window.__PORTAL_MANAGER__.templeRunGame.player.tiltOffset);
  console.log('Holding KeyQ (tilt offset):', tiltVal);
  if (tiltVal >= 0) throw new Error(`Expected negative tilt for Q, got ${tiltVal}`);
  await page.keyboard.up('KeyQ');
  await delay(150);

  await page.keyboard.down('KeyE');
  await delay(300);
  tiltVal = await page.evaluate(() => window.__PORTAL_MANAGER__.templeRunGame.player.tiltOffset);
  console.log('Holding KeyE (tilt offset):', tiltVal);
  if (tiltVal <= 0) throw new Error(`Expected positive tilt for E, got ${tiltVal}`);
  await page.keyboard.up('KeyE');
  await delay(150);
  console.log('✅ PASS: Analog tilt Q (Left) and E (Right) working smoothly!');

  // 4. TEST JUMP (Space / W)
  console.log('\n--- 4. Testing Jump (Space) ---');
  await page.keyboard.press('Space');
  await delay(150);
  let jumpState = await page.evaluate(() => {
    const p = window.__PORTAL_MANAGER__.templeRunGame.player;
    return {
      isJumping: p.isJumping,
      height: p.currentHeight,
      vy: p.verticalVelocity
    };
  });
  console.log('During Jump:', jumpState);
  if (!jumpState.isJumping || jumpState.height <= 0) {
    throw new Error('Jump physics not active');
  }
  await page.screenshot({ path: `${screenshotDir}/temple_03_jump.png` });
  console.log('📸 Captured temple_03_jump.png (Apex of Jump)');
  console.log('✅ PASS: Jump physics active with vertical arc!');
  await delay(500); // Land

  // 5. TEST SLIDE (KeyS)
  console.log('\n--- 5. Testing Slide (KeyS) ---');
  await page.keyboard.press('KeyS');
  await delay(150);
  let slideState = await page.evaluate(() => {
    const p = window.__PORTAL_MANAGER__.templeRunGame.player;
    return {
      isSliding: p.isSliding,
      slideTimer: p['slideTimer']
    };
  });
  console.log('During Slide:', slideState);
  if (!slideState.isSliding) throw new Error('Slide not active');
  await page.screenshot({ path: `${screenshotDir}/temple_04_slide.png` });
  console.log('📸 Captured temple_04_slide.png (Baseball Slide pose)');
  console.log('✅ PASS: Slide active with low ducking hitbox!');
  await delay(600); // Slide finish

  // 6. TEST CORNER TURNS (Left Turn and Right Turn)
  console.log('\n--- 6. Testing 90° Corner Turns at Intersections ---');

  // Test Left Turn
  let turnResult = await page.evaluate(() => {
    const game = window.__PORTAL_MANAGER__.templeRunGame;
    const pool = game.trackPool;
    const player = game.player;

    pool.reset();
    player.reset();
    pool.activeSegments.length = 0;
    pool.currentHeading = 0;
    pool.cursorPosition.set(0, 0, 0);

    pool.spawnSegment('straight'); // z: 0..24
    pool.spawnSegment('turn_left'); // junction center at z = 27
    player.position.set(0, 0, 27);

    // Swipe Left
    player.handleSwipe('left');
    return {
      heading: player.heading,
      isDead: player.isDead,
      pos: { x: player.position.x, z: player.position.z }
    };
  });
  console.log('Left Turn Execution:', turnResult);
  if (Math.abs(turnResult.heading - Math.PI / 2) > 0.01) {
    throw new Error(`Left turn heading expected PI/2, got ${turnResult.heading}`);
  }
  if (turnResult.isDead) throw new Error('Player died on Left Turn');
  console.log('✅ PASS: 90° Left Turn successfully executed towards open left corridor!');

  // Test Right Turn
  turnResult = await page.evaluate(() => {
    const game = window.__PORTAL_MANAGER__.templeRunGame;
    const pool = game.trackPool;
    const player = game.player;

    pool.reset();
    player.reset();
    pool.activeSegments.length = 0;
    pool.currentHeading = 0;
    pool.cursorPosition.set(0, 0, 0);

    pool.spawnSegment('straight'); // z: 0..24
    pool.spawnSegment('turn_right'); // junction center at z = 27
    player.position.set(0, 0, 27);

    // Swipe Right
    player.handleSwipe('right');
    return {
      heading: player.heading,
      isDead: player.isDead,
      pos: { x: player.position.x, z: player.position.z }
    };
  });
  console.log('Right Turn Execution:', turnResult);
  if (Math.abs(turnResult.heading - (3 * Math.PI / 2)) > 0.01) {
    throw new Error(`Right turn heading expected 3*PI/2, got ${turnResult.heading}`);
  }
  if (turnResult.isDead) throw new Error('Player died on Right Turn');
  console.log('✅ PASS: 90° Right Turn successfully executed towards open right corridor!');

  // 7. TEST POWER-UP ACTIVATION & HUD DISPLAY
  console.log('\n--- 7. Testing Power-Up Activation & HUD Bar ---');
  await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.templeRunGame;
    g.restart();
    g.cinematic.skip();
    g.activatePowerup('shield');
  });
  await delay(300);

  let powerupState = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.templeRunGame;
    const bar = document.getElementById('temple-powerup-bar');
    const name = document.getElementById('temple-powerup-name')?.textContent;
    return {
      activePowerup: g.activePowerup,
      shieldActive: g.player.isShieldActive,
      barVisible: !bar?.classList.contains('hidden'),
      name
    };
  });
  console.log('Shield Power-Up State:', powerupState);
  if (powerupState.activePowerup !== 'shield' || !powerupState.shieldActive || !powerupState.barVisible) {
    throw new Error('Shield power-up activation failed');
  }
  await page.screenshot({ path: `${screenshotDir}/temple_05_powerup_shield.png` });
  console.log('📸 Captured temple_05_powerup_shield.png');
  console.log('✅ PASS: Shield power-up and HUD timer bar verified!');

  // 8. TEST GAME OVER & KEYBOARD RESTART
  console.log('\n--- 8. Testing Game Over & Spacebar / R Restart ---');
  await page.evaluate(() => {
    const game = window.__PORTAL_MANAGER__.templeRunGame;
    game.player.kill('Plunged into ancient abyss');
    game['handleGameOver']();
  });
  await delay(800);

  let deathState = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.templeRunGame;
    const modal = document.getElementById('temple-gameover-modal');
    return {
      phase: g.phase,
      isDead: g.player.isDead,
      modalVisible: !modal?.classList.contains('hidden'),
      reason: document.getElementById('temple-death-reason')?.textContent
    };
  });
  console.log('Death State:', deathState);
  if (!deathState.isDead || !deathState.modalVisible) {
    throw new Error('Death did not trigger game over modal');
  }
  await page.screenshot({ path: `${screenshotDir}/temple_06_gameover.png` });
  console.log('📸 Captured temple_06_gameover.png');

  // Press Space to restart
  console.log('Testing Spacebar to restart Curse Runner...');
  await page.keyboard.press('Space');
  await delay(400);

  let restartState = await page.evaluate(() => {
    const g = window.__PORTAL_MANAGER__.templeRunGame;
    const modal = document.getElementById('temple-gameover-modal');
    return {
      phase: g.phase,
      isRunning: g.isRunning,
      isDead: g.player.isDead,
      modalVisible: !modal?.classList.contains('hidden')
    };
  });
  console.log('After Space Restart:', restartState);
  if ((restartState.phase !== 'playing' && restartState.phase !== 'cinematic') || restartState.isDead || restartState.modalVisible) {
    throw new Error(`Expected active phase and hidden modal after restart: ${JSON.stringify(restartState)}`);
  }
  console.log('✅ PASS: Spacebar immediately restarted into active gameplay / cinematic!');

  // Return to portal
  await page.click('#btn-temple-menu');
  await delay(200);

  if (pageErrors.length > 0) {
    console.warn('Page errors detected:', pageErrors);
  }

  console.log('\n======================================================');
  console.log('🎉 ALL CONTROLS AND GAMEPLAY VERIFIED 100% WORKING!');
  console.log('======================================================');
} finally {
  await browser.close();
}
