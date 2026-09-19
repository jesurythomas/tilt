import puppeteer from 'puppeteer';

const baseUrl = process.env.SMOKE_URL || 'http://127.0.0.1:5173';
const browser = await puppeteer.launch({ headless: true });
const errors = [];

const createPage = async (viewport) => {
  const page = await browser.newPage();
  await page.setViewport(viewport);
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });
  await page.goto(baseUrl, { waitUntil: 'networkidle0' });
  return page;
};

try {
  const flight = await createPage({ width: 390, height: 844, isMobile: true, hasTouch: true });
  await flight.$eval('#card-dread-flock', (element) => element.click());
  await flight.$eval('#btn-flight-start', (element) => element.click());
  for (let flap = 0; flap < 7; flap++) {
    await new Promise((resolve) => setTimeout(resolve, 220));
    await flight.keyboard.press('Space');
  }
  await new Promise((resolve) => setTimeout(resolve, 350));
  await flight.screenshot({ path: 'dread-flight-mobile.png' });

  const runner = await createPage({ width: 1440, height: 900 });
  await runner.$eval('#card-temple-run', (element) => element.click());
  await runner.$eval('#btn-temple-start', (element) => element.click());
  await new Promise((resolve) => setTimeout(resolve, 180));
  await runner.screenshot({ path: 'curse-runner-desktop.png' });

  if (errors.length > 0) throw new Error(`Browser errors: ${errors.join(' | ')}`);
  console.log('Visual check passed: dread-flight-mobile.png and curse-runner-desktop.png generated.');
} finally {
  await browser.close();
}
