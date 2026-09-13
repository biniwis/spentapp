// Real browser soak of the generated page; no delivery globals or renderer stubs.
// NODE_PATH=<directory containing playwright> node scripts/check_city_soak.js
const { chromium } = require('playwright');
const { pathToFileURL } = require('url');
const path = require('path');
const assert = require('assert/strict');
(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true
  });
  try {
    const page = await browser.newPage({ viewport: { width: 800, height: 700 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(pathToFileURL(path.resolve(__dirname, '../MoneyCity/Resources/diorama.html')).href);
    await page.waitForFunction(() => window.__diorama);
    let previous = 0;
    for (let sample = 1; sample <= 10; sample++) {
      await page.waitForTimeout(30000);
      const state = await page.evaluate(() => ({
        clock: window.__diorama.life.ambient.clock,
        frame: window.__diorama.renderer.info.render.frame,
        events: window.__diorama.life.encounters.map(e => e.kind)
      }));
      assert.equal(errors.length, 0, errors.join('\n'));
      assert(state.frame > previous, 'Renderer must continue producing frames');
      previous = state.frame;
      console.log(JSON.stringify({ elapsedSeconds: sample * 30, ...state }));
    }
    console.log('PASS: five wall-clock minutes of rendering without runtime errors.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
