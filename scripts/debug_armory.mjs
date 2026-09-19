import puppeteer from 'puppeteer';
import path from 'path';

const scratchDir = path.resolve('C:/Users/Jesury/.gemini/antigravity-cli/brain/21796d0e-021d-41ad-bd14-644fb082ac3e/scratch');

async function inspectArmory() {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 800 });
  await page.goto('http://localhost:5173', { waitUntil: 'networkidle0' });

  // Click armory button on start menu
  await page.click('#btn-menu-armory');
  await new Promise(r => setTimeout(r, 600));

  await page.screenshot({ path: path.join(scratchDir, 'armory_weapons_tab_debug.png') });
  console.log('Screenshot saved: armory_weapons_tab_debug.png');

  // Let's check bounding box of armory tabs and perk cards
  const info = await page.evaluate(() => {
    const tabs = document.querySelector('.armory-tabs');
    const tabsRect = tabs?.getBoundingClientRect();
    const content = document.querySelector('.armory-content');
    const contentRect = content?.getBoundingClientRect();
    const cards = Array.from(document.querySelectorAll('.perk-card')).map(c => {
      const r = c.getBoundingClientRect();
      const title = c.querySelector('h3')?.textContent;
      return { title, x: r.x, y: r.y, width: r.width, height: r.height };
    });
    return { tabsRect, contentRect, cards };
  });

  console.log('Armory Debug Info:', JSON.stringify(info, null, 2));
  await browser.close();
}

inspectArmory().catch(console.error);
