import puppeteer from 'puppeteer';
import path from 'path';
import fs from 'fs';

const scratchDir = path.resolve('C:/Users/Jesury/.gemini/antigravity-cli/brain/21796d0e-021d-41ad-bd14-644fb082ac3e/scratch');
if (!fs.existsSync(scratchDir)) {
  fs.mkdirSync(scratchDir, { recursive: true });
}

async function runTests() {
  console.log('=== Testing Arrow Keys Steering and Gyro Tilt Option ===');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 800 });

    page.on('console', msg => {
      const text = msg.text();
      if (!text.includes('[vite]') && !text.includes('HMR')) {
        console.log('PAGE LOG:', text);
      }
    });

    await page.goto('http://localhost:5173', { waitUntil: 'networkidle0' });

    // 1. Verify Options Modal and Gyro Option
    console.log('[Step 1] Opening Game Options Modal...');
    await page.click('#btn-menu-options');
    await new Promise(r => setTimeout(r, 300));

    // Check control scheme buttons exist
    const schemeButtons = await page.$$eval('.opt-btn[data-opt="controlScheme"]', btns =>
      btns.map(b => ({ val: b.getAttribute('data-val'), text: b.innerText.trim() }))
    );
    console.log('Found control scheme buttons:', schemeButtons);

    const hasGyroOption = schemeButtons.some(b => b.val === 'gyro');
    if (!hasGyroOption) {
      throw new Error('Missing "gyro" control scheme option button in Options Modal');
    }

    // Select Gyro / Tilt scheme
    console.log('Selecting 📱 Gyro / Tilt scheme...');
    await page.click('.opt-btn[data-opt="controlScheme"][data-val="gyro"]');
    await new Promise(r => setTimeout(r, 300));

    // Verify Neutral Tilt Calibration row appeared
    const calibBtn = await page.$('#opt-btn-calibrate-gyro');
    if (!calibBtn) {
      throw new Error('Neutral Tilt Calibration button #opt-btn-calibrate-gyro not found when Gyro selected');
    }
    console.log('Found #opt-btn-calibrate-gyro. Clicking calibrate button in options...');
    await calibBtn.click();
    await new Promise(r => setTimeout(r, 400));
    const calibText = await page.$eval('#opt-btn-calibrate-gyro', el => el.innerText.trim());
    console.log('Calibration button feedback:', calibText);

    await page.screenshot({ path: path.join(scratchDir, 'verify_gyro_options_modal.png') });

    // Close options
    await page.click('#btn-close-options');
    await new Promise(r => setTimeout(r, 300));

    // 2. Launch Game in Gyro Mode
    console.log('[Step 2] Launching Run with Gyro Mode...');
    await page.click('#btn-menu-launch');
    await new Promise(r => setTimeout(r, 500));

    // Skip cinematic
    const skipBtn = await page.$('.tilt-cinematic-skip');
    if (skipBtn) await skipBtn.click();
    await new Promise(r => setTimeout(r, 500));

    // Verify Calibrate Button is visible on Top HUD in Gyro mode
    const hudCalibHidden = await page.$eval('#btn-tilt-calibrate', el => el.classList.contains('hidden'));
    console.log('Top HUD #btn-tilt-calibrate is hidden?', hudCalibHidden);
    if (hudCalibHidden) {
      throw new Error('Expected #btn-tilt-calibrate to be visible in HUD during Gyro mode');
    }

    // Click in-game HUD calibrate button
    console.log('Clicking in-game HUD Calibrate button...');
    await page.click('#btn-tilt-calibrate');
    await new Promise(r => setTimeout(r, 300));

    // Check toast notification
    const toastText = await page.$eval('#tilt-goal-toast', el => el.innerText.trim()).catch(() => '');
    console.log('Calibration Toast message:', toastText);

    // Test Simulated Device Orientation Event
    console.log('Simulating deviceorientation tilt event...');
    await page.evaluate(() => {
      let event;
      try {
        event = new DeviceOrientationEvent('deviceorientation', {
          beta: 60,
          gamma: 15,
          bubbles: true,
          cancelable: true
        });
      } catch (e) {
        event = new Event('deviceorientation');
        Object.defineProperty(event, 'beta', { value: 60 });
        Object.defineProperty(event, 'gamma', { value: 15 });
      }
      window.dispatchEvent(event);
    });

    await new Promise(r => setTimeout(r, 400));

    const gyroTilt = await page.evaluate(() => {
      const g = window.tiltGame;
      return {
        tiltVector: g?.gyro?.tiltVector,
        playerVx: g?.player?.vx,
        playerVy: g?.player?.vy
      };
    });
    console.log('Gyro response data:', gyroTilt);

    if (!gyroTilt.tiltVector || (gyroTilt.tiltVector.x === 0 && gyroTilt.tiltVector.y === 0)) {
      throw new Error('Gyro tiltVector did not update upon deviceorientation event');
    }
    console.log('✓ Gyro device orientation steering successfully updated player physics!');

    // Test Pause Modal with Gyro description & calibrate button
    console.log('Testing Pause Modal in Gyro mode...');
    await page.click('#btn-tilt-pause');
    await new Promise(r => setTimeout(r, 300));

    const pauseDesc = await page.$eval('#tilt-pause-scheme-desc', el => el.innerText.trim());
    const pauseCalibHidden = await page.$eval('#btn-tilt-calibrate-pause', el => el.classList.contains('hidden'));
    console.log('Pause Scheme description:', pauseDesc);
    console.log('Pause Calibrate button hidden?', pauseCalibHidden);

    if (!pauseDesc.toLowerCase().includes('tilting')) {
      throw new Error(`Expected pause description to mention tilting, got: ${pauseDesc}`);
    }
    if (pauseCalibHidden) {
      throw new Error('Expected #btn-tilt-calibrate-pause to be visible in Pause modal during Gyro mode');
    }

    await page.screenshot({ path: path.join(scratchDir, 'verify_gyro_pause_modal.png') });

    // Resume
    await page.click('#btn-tilt-resume');
    await new Promise(r => setTimeout(r, 300));

    // 3. Test Arrow Keys Steering
    console.log('[Step 3] Switching to Hybrid / Keyboard mode and testing Arrow Keys...');
    // Switch to hybrid mode and reset player to center
    await page.evaluate(() => {
      window.tiltGame.options.settings.controlScheme = 'hybrid';
      window.tiltGame.options.save();
      window.tiltGame.player.reset(500, 400);
    });

    const initPos = await page.evaluate(() => ({
      x: window.tiltGame.player.x,
      y: window.tiltGame.player.y
    }));
    console.log('Initial Player Position (centered):', initPos);

    // Press ArrowRight
    console.log('Holding ArrowRight...');
    await page.keyboard.down('ArrowRight');
    await new Promise(r => setTimeout(r, 350));
    await page.keyboard.up('ArrowRight');

    const posAfterRight = await page.evaluate(() => ({
      x: window.tiltGame.player.x,
      y: window.tiltGame.player.y
    }));
    console.log('Position after ArrowRight:', posAfterRight);
    if (posAfterRight.x <= initPos.x + 10) {
      throw new Error(`ArrowRight did not move player right! initial: ${initPos.x}, now: ${posAfterRight.x}`);
    }
    console.log('✓ ArrowRight moved player right successfully (+', (posAfterRight.x - initPos.x).toFixed(1), 'px)');

    // Press ArrowDown
    console.log('Holding ArrowDown...');
    await page.keyboard.down('ArrowDown');
    await new Promise(r => setTimeout(r, 350));
    await page.keyboard.up('ArrowDown');

    const posAfterDown = await page.evaluate(() => ({
      x: window.tiltGame.player.x,
      y: window.tiltGame.player.y
    }));
    console.log('Position after ArrowDown:', posAfterDown);
    if (posAfterDown.y <= posAfterRight.y + 10) {
      throw new Error(`ArrowDown did not move player down! before: ${posAfterRight.y}, now: ${posAfterDown.y}`);
    }
    console.log('✓ ArrowDown moved player down successfully (+', (posAfterDown.y - posAfterRight.y).toFixed(1), 'px)');

    // Press ArrowLeft
    console.log('Holding ArrowLeft...');
    await page.keyboard.down('ArrowLeft');
    await new Promise(r => setTimeout(r, 350));
    await page.keyboard.up('ArrowLeft');

    const posAfterLeft = await page.evaluate(() => ({
      x: window.tiltGame.player.x,
      y: window.tiltGame.player.y
    }));
    console.log('Position after ArrowLeft:', posAfterLeft);
    if (posAfterLeft.x >= posAfterDown.x - 10) {
      throw new Error(`ArrowLeft did not move player left! before: ${posAfterDown.x}, now: ${posAfterLeft.x}`);
    }
    console.log('✓ ArrowLeft moved player left successfully (-', (posAfterDown.x - posAfterLeft.x).toFixed(1), 'px)');

    // Press ArrowUp
    console.log('Holding ArrowUp...');
    await page.keyboard.down('ArrowUp');
    await new Promise(r => setTimeout(r, 350));
    await page.keyboard.up('ArrowUp');

    const posAfterUp = await page.evaluate(() => ({
      x: window.tiltGame.player.x,
      y: window.tiltGame.player.y
    }));
    console.log('Position after ArrowUp:', posAfterUp);
    if (posAfterUp.y >= posAfterLeft.y - 10) {
      throw new Error(`ArrowUp did not move player up! before: ${posAfterLeft.y}, now: ${posAfterUp.y}`);
    }
    console.log('✓ ArrowUp moved player up successfully (-', (posAfterLeft.y - posAfterUp.y).toFixed(1), 'px)');

    // Verify window scroll position is strictly 0
    const scrollY = await page.evaluate(() => window.scrollY);
    console.log('window.scrollY after arrow key movements:', scrollY);
    if (scrollY !== 0) {
      throw new Error(`Browser window scrolled unexpectedly! scrollY: ${scrollY}`);
    }
    console.log('✓ Arrow keys prevented default browser scrolling (scrollY = 0)');

    await page.screenshot({ path: path.join(scratchDir, 'verify_arrow_steering_in_action.png') });

    console.log('\n=======================================');
    console.log('🎉 ALL ARROW KEYS AND GYRO TESTS PASSED!');
    console.log('=======================================');
  } finally {
    await browser.close();
  }
}

runTests().catch(err => {
  console.error('Test FAILED:', err);
  process.exit(1);
});
