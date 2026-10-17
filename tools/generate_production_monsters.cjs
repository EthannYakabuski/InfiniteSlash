/** Export original art through the actual public Creature Mixer UI.
 * Uses only menu clicks: full Randomize, then Save spritesheet at 8x.
 * No Unity internals, drawing calls, recoloring or synthetic sprite generation.
 */
const { chromium } = require('C:/Users/swimr/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '..');
const out = path.join(root, 'output', 'review', 'production-mixer');
const monsterDir = path.join(root, 'Assets', 'Monsters');
const appUrl = 'https://html-classic.itch.zone/html/9229894/index.html';
fs.mkdirSync(out, { recursive: true });
const digest = b => crypto.createHash('sha256').update(b).digest('hex');
(async () => {
  const existingRoster = JSON.parse(fs.readFileSync(path.join(root,'data','monsters.json'),'utf8'));
  if(existingRoster.length > 100) throw new Error('This expansion is already finalized. Refusing to create a duplicate batch.');
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const previous = fs.existsSync(path.join(out,'exports.json')) ? JSON.parse(fs.readFileSync(path.join(out,'exports.json'),'utf8')) : null;
  const evidence = { source: 'https://kenney.itch.io/creature-mixer', embeddedApp: appUrl,
    tool: 'Kenney Creature Mixer v1.6.0', browser: 'Microsoft Edge / Playwright', scale: 8,
    requestedWorkflow: 'full Randomize -> Save spritesheet', startedUtc: new Date().toISOString(), downloads: [] };
  try {
    const context = await browser.newContext({ acceptDownloads: true, viewport: { width: 1366, height: 1000 } });
    const page = await context.newPage();
    page.on('pageerror', e => console.log('PAGE_ERROR', e.message));
    await page.goto(appUrl, { waitUntil: 'networkidle', timeout: 60000 });
    await page.locator('#loading-cover').waitFor({ state: 'hidden', timeout: 60000 });
    await page.waitForTimeout(1800);
    await page.screenshot({ path: path.join(out, '01_license.png') });
    await page.mouse.click(1009,274); // inspected license close
    await page.waitForTimeout(300);
    await page.mouse.click(49,50); // inspected hamburger menu
    await page.waitForTimeout(300);
    for(let i = 0; i < 7; i++) { await page.mouse.click(302,200); await page.waitForTimeout(180); }
    await page.screenshot({ path: path.join(out, '02_scale8.png') });
    const roster = JSON.parse(fs.readFileSync(path.join(root, 'data', 'monsters.json'), 'utf8'));
    const known = new Set(roster.map(m => m.sha256));
    known.add(digest(fs.readFileSync(path.join(monsterDir, 'creature-sheet (2).png'))));
    let exported = 0;
    let menuOpen = true;
    while(exported < 100) {
      const index = 101 + exported;
      const target = path.join(monsterDir, `production_${String(index).padStart(3,'0')}.png`);
      if(fs.existsSync(target)) {
        const b = fs.readFileSync(target); const hash = digest(b);
        if(!known.has(hash) && b.readUInt32BE(16) === 768 && b.readUInt32BE(20) === 192) {
          known.add(hash); exported++;
          evidence.downloads.push(previous?.downloads?.find(d => d.index === index) || { index, target: path.relative(root,target), sha256: hash, resumed: true });
          continue;
        }
        throw new Error(`Existing invalid or duplicate export ${target}`);
      }
      if(!menuOpen) { await page.mouse.click(49,50); await page.waitForTimeout(220); menuOpen=true; }
      await page.mouse.click(170,449); // full Randomize, NOT shapes/colors
      await page.waitForTimeout(330);
      const downloadEvent = page.waitForEvent('download', { timeout: 20000 });
      await page.mouse.click(170,253); // Save spritesheet
      const download = await downloadEvent;
      await download.saveAs(target);
      menuOpen = false; // Save spritesheet closes the app menu.
      const b = fs.readFileSync(target); const hash = digest(b);
      if(b.readUInt32BE(16) !== 768 || b.readUInt32BE(20) !== 192) throw new Error(`Export is not8x: ${target}`);
      if(known.has(hash)) throw new Error(`Duplicate export: ${target}`);
      known.add(hash);
      exported++;
      evidence.downloads.push({ index, target: path.relative(root,target), suggestedFilename: download.suggestedFilename(),
        sha256: hash, bytes: b.length, dimensions: [768,192], savedUtc: new Date().toISOString() });
      fs.writeFileSync(path.join(out, 'exports.json'), JSON.stringify(evidence,null,2)+'\n');
      if(exported===1 || exported%25===0) {
        await page.screenshot({ path: path.join(out, `export_${String(index).padStart(3,'0')}.png`) });
        console.log(`EXPORTED ${exported}/100 (${hash.slice(0,12)})`);
      }
      await page.waitForTimeout(200);
    }
    evidence.completedUtc = new Date().toISOString();
    evidence.pass = true;
    fs.writeFileSync(path.join(out, 'exports.json'), JSON.stringify(evidence,null,2)+'\n');
    console.log('PASS:100new actual Creature Mixer Save spritesheet downloads at8x.');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
