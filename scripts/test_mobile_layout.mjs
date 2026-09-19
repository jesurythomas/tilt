import puppeteer from 'puppeteer';
import path from 'path';
import fs from 'fs';

const scratchDir = path.resolve('C:/Users/Jesury/.gemini/antigravity-cli/brain/21796d0e-021d-41ad-bd14-644fb082ac3e/scratch');
if (!fs.existsSync(scratchDir)) {
  fs.mkdirSync(scratchDir, { recursive: true });
}

async function testMobile() {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    const page = await browser.newPage();
    // Simulate mobile viewport (iPhone 14: 390 x 844)
    await page.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true });

    await page.goto('http://localhost:5173', { waitUntil: 'networkidle0' });
    await new Promise(r => setTimeout(r, 600));

    // Capture screenshot of start menu before fixes
    await page.screenshot({ path: path.join(scratchDir, 'mobile_menu_before.png') });
    console.log('Captured mobile_menu_before.png');

    // Check menu content bounds
    const contentBox = await page.$eval('.tilt-menu-content', el => {
      const rect = el.getBoundingClientRect();
      const style = window.getComputedStyle(el.parentElement);
      return {
        paddingLeft: style.paddingLeft,
        paddingRight: style.paddingRight,
        width: rect.width,
        scrollWidth: el.parentElement.scrollWidth,
        clientWidth: el.parentElement.clientWidth
      };
    });
    console.log('Mobile menu content metrics:', contentBox);

    // Check armory tuning tab
    await page.click('#btn-menu-armory');
    await new Promise(r => setTimeout(r, 400));
    await page.click('.armory-tab-btn[data-tab="tuning"]');
    await new Promise(r => setTimeout(r, 300));
    await page.screenshot({ path: path.join(scratchDir, 'mobile_tuning_before.png') });
    console.log('Captured mobile_tuning_before.png');

  } finally {
    await browser.close();
  }
}

testMobile().catch(console.error);
