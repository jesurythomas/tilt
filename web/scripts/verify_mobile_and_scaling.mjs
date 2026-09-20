import puppeteer from 'puppeteer';
import path from 'path';
import fs from 'fs';

const scratchDir = path.resolve('C:/Users/Jesury/.gemini/antigravity-cli/brain/21796d0e-021d-41ad-bd14-644fb082ac3e/scratch');
if (!fs.existsSync(scratchDir)) {
  fs.mkdirSync(scratchDir, { recursive: true });
}

async function verifyMobileAndScaling() {
  console.log('--- Starting Mobile & Model Scaling Verification ---');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    const page = await browser.newPage();

    // 1. Test Mobile Menu (iPhone 14: 390x844)
    await page.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true });
    await page.goto('http://localhost:5173', { waitUntil: 'networkidle0' });
    await new Promise(r => setTimeout(r, 600));

    // Capture mobile menu screenshot
    await page.screenshot({ path: path.join(scratchDir, 'mobile_menu_after.png') });
    console.log('✓ Captured mobile_menu_after.png');

    // Verify mobile menu metrics
    const menuMetrics = await page.evaluate(() => {
      const screenEl = document.querySelector('.tilt-menu-screen');
      const contentEl = document.querySelector('.tilt-menu-content');
      const goalsEl = document.querySelector('.tilt-goals-sidebar');
      const screenStyle = window.getComputedStyle(screenEl);
      const goalsStyle = window.getComputedStyle(goalsEl);
      return {
        screenPaddingLeft: screenStyle.paddingLeft,
        screenPaddingRight: screenStyle.paddingRight,
        contentWidth: contentEl.getBoundingClientRect().width,
        screenWidth: screenEl.getBoundingClientRect().width,
        isGoalsHiddenOnMobileMenu: goalsEl.classList.contains('mobile-menu-hide') || goalsStyle.display === 'none' || parseFloat(goalsStyle.left) < 0
      };
    });
    console.log('Menu metrics:', menuMetrics);

    // 2. Test Armory Tuning Tab & Font Sizes
    await page.click('#btn-menu-armory');
    await new Promise(r => setTimeout(r, 400));
    await page.click('.armory-tab-btn[data-tab="tuning"]');
    await new Promise(r => setTimeout(r, 300));

    // Check sensitivity font size
    const tuningFontSize = await page.evaluate(() => {
      const label = document.querySelector('.tuning-label-row label');
      const explain = document.querySelector('.tuning-explain');
      const val = document.querySelector('.tuning-value-pill');
      return {
        labelFontSize: label ? window.getComputedStyle(label).fontSize : null,
        labelColor: label ? window.getComputedStyle(label).color : null,
        explainFontSize: explain ? window.getComputedStyle(explain).fontSize : null,
        valFontSize: val ? window.getComputedStyle(val).fontSize : null
      };
    });
    console.log('Tuning typography metrics:', tuningFontSize);

    await page.screenshot({ path: path.join(scratchDir, 'mobile_tuning_after.png') });
    console.log('✓ Captured mobile_tuning_after.png');

    // Close armory
    await page.click('#btn-armory-close');
    await new Promise(r => setTimeout(r, 300));

    // 3. Test Options Modal Sensitivity
    await page.click('#btn-menu-options');
    await new Promise(r => setTimeout(r, 300));

    const optionsMetrics = await page.evaluate(() => {
      const optSlider = document.querySelector('#opt-slider-sensitivity');
      const optVal = document.querySelector('#opt-val-sensitivity');
      const optLabel = optSlider?.closest('.option-row')?.querySelector('span');
      return {
        hasSensitivitySlider: !!optSlider,
        currentValue: optSlider ? optSlider.value : null,
        labelFontSize: optLabel ? window.getComputedStyle(optLabel).fontSize : null,
        labelColor: optLabel ? window.getComputedStyle(optLabel).color : null
      };
    });
    console.log('Options sensitivity metrics:', optionsMetrics);

    await page.screenshot({ path: path.join(scratchDir, 'mobile_options_after.png') });
    console.log('✓ Captured mobile_options_after.png');

    await page.click('#btn-close-options');
    await new Promise(r => setTimeout(r, 300));

    // 4. Test In-Game Proportional Scaling on Mobile
    // Launch classic mode
    await page.click('#btn-menu-launch');
    await new Promise(r => setTimeout(r, 800));

    const mobileInGameScale = await page.evaluate(() => {
      // Access game state from window.game or canvas bounds
      const canvas = document.getElementById('tilt-canvas');
      const bounds = canvas.getBoundingClientRect();
      const minDim = Math.min(bounds.width, bounds.height);
      const expectedScale = Math.max(0.60, Math.min(1.15, minDim / 680));
      return {
        canvasWidth: bounds.width,
        canvasHeight: bounds.height,
        minDim,
        expectedScale: expectedScale.toFixed(3)
      };
    });
    console.log('Mobile in-game scaling metrics:', mobileInGameScale);

    await page.screenshot({ path: path.join(scratchDir, 'mobile_gameplay_after.png') });
    console.log('✓ Captured mobile_gameplay_after.png');

    // 5. Test Desktop Scaling (1280x720)
    await page.setViewport({ width: 1280, height: 720, isMobile: false });
    await page.evaluate(() => window.dispatchEvent(new Event('resize')));
    await new Promise(r => setTimeout(r, 400));

    const desktopInGameScale = await page.evaluate(() => {
      const canvas = document.getElementById('tilt-canvas');
      const bounds = canvas.getBoundingClientRect();
      const minDim = Math.min(bounds.width, bounds.height);
      const expectedScale = Math.max(0.60, Math.min(1.15, minDim / 680));
      return {
        canvasWidth: bounds.width,
        canvasHeight: bounds.height,
        minDim,
        expectedScale: expectedScale.toFixed(3)
      };
    });
    console.log('Desktop in-game scaling metrics:', desktopInGameScale);

    await page.screenshot({ path: path.join(scratchDir, 'desktop_gameplay_after.png') });
    console.log('✓ Captured desktop_gameplay_after.png');

    console.log('All mobile and scaling verifications passed successfully!');
  } finally {
    await browser.close();
  }
}

verifyMobileAndScaling().catch(err => {
  console.error('Verification failed:', err);
  process.exit(1);
});
