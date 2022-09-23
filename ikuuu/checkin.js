const { chromium } = require('playwright');
// const { chromium } = require('playwright-chromium');
const { solve } = require('recaptcha-solver');

(async () => {
  const { IKUUU_USERNAME, IKUUU_PASSWORD } = process.env;
  if (!IKUUU_USERNAME || !IKUUU_PASSWORD) {
    console.log('[ERR] require IKUUU_USERNAME / IKUUU_PASSWORD');
    return;
  }
  const browser = await chromium.launch({
    headless: true,
  });
  const context = await browser.newContext();

  // Open new page
  const page = await context.newPage();

  // // Go to https://ikuuu.dev/
  // await page.goto('https://ikuuu.dev/');

  // Go to https://ikuuu.dev/auth/login
  await page.goto('https://ikuuu.dev/auth/login');

  await page.locator('input[name="email"]').fill(IKUUU_USERNAME);

  await page.locator('input[name="password"]').fill(IKUUU_PASSWORD);

  try {
    const recaptcha = await page.waitForSelector('iframe[title="reCAPTCHA"]', { state: 'attached', timeout: 5000 });
    // const recaptchaUrl = await page.locator('iframe[title="reCAPTCHA"]').getAttribute('src');
    const solveResult = await solve(page);
    console.log('[INFO] Solve reCAPTCHA: ' + solveResult);
  } catch(e) {}

  await Promise.all([
    page.waitForLoadState('networkidle'),
    page.locator('button[type="submit"]').click(),
  ]);

  await page.locator('button >> text=Read').click();

  const res = await page.evaluate(async () => {
    return await fetch('/user/checkin', { method: 'POST' })
      .then(r => r.ok ? r.json() : Promise.reject(r))
  });
  console.log('[INFO] ' + res.msg);
  // const [response] = await Promise.all([
  //   page.waitForResponse(res => res.url().includes('/user/checkin') && response.status() === 200),
  //   page.locator('div#checkin-div > a').click(),
  // ]);
  // console.log(response && response.msg ? response.msg : 'Failed to checkin.');

  // const [response] = await Promise.all([
  //   page.waitForResponse(response => response.url().includes('/user/trafficlog') && response.status() === 200),
  //   page.locator('div#loadTrafficChart-div > a').click(),
  // ]);
  // const trafficData = await response.text();
  // console.log(trafficData);

  const trafficSummary = await page.locator('#pie-chart').innerText();
  if (trafficSummary) {
    console.log('[INFO] ' + trafficSummary.split('\n').filter(text => /B$/.test(text)).join(' / '));
  }

  await context.close();
  await browser.close();
})();

