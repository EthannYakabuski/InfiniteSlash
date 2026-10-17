// Inspect the public Creature Mixer before choosing canvas UI controls.
const { chromium } = require('C:/Users/swimr/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const root = path.resolve(__dirname, '..');
  const out = path.join(root, 'output', 'review', 'production-mixer');
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const context = await browser.newContext({ acceptDownloads: true, viewport: { width: 1366, height: 1000 } });
  const page = await context.newPage();
  page.on('console', m => console.log('BROWSER', m.type(), m.text().slice(0, 300)));
  page.on('pageerror', e => console.log('ERROR', e.message));
  await page.goto('https://html-classic.itch.zone/html/9229894/index.html', { waitUntil: 'networkidle', timeout: 60000 });
  console.log(JSON.stringify(await page.locator('iframe').evaluateAll(es => es.map(e => ({ src:e.src, id:e.id, width:e.width, height:e.height }))), null, 2));
  console.log((await page.locator('body').innerText()).slice(0, 2500));
  fs.writeFileSync(path.join(out, 'inspect_dom.html'), await page.content());
  await page.locator('#loading-cover').waitFor({state:'hidden',timeout:60000});
  await page.waitForTimeout(1000);
  console.log('CANVAS', await page.locator('canvas').evaluateAll(es => es.map(e => ({ id:e.id, width:e.width,height:e.height, bounds:e.getBoundingClientRect().toJSON() }))));
  await page.screenshot({ path: path.join(out, 'inspect_initial.png'), fullPage: true });
  if(process.argv.includes('--initial-only')) { await browser.close(); return; }
  await page.mouse.click(1009, 274);
  await page.waitForTimeout(500);
  await page.mouse.click(49, 50);
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(out, 'inspect_menu.png'), fullPage: true });
  for(let i = 0; i < 3; i++) { await page.mouse.click(302,200); await page.waitForTimeout(250); }
  await page.screenshot({ path: path.join(out, 'inspect_scale.png'), fullPage: true });
  await browser.close();
})().catch(e => { console.error(e); process.exitCode = 1; });
