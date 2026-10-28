// One-off screenshot helper for development (not a test): opens a URL in the installed Brave via playwright-core,
// waits for fonts and for every <img> to be complete and decoded, and writes a PNG.
//   node shot.mjs --url=http://127.0.0.1:9292/ --out=/abs/path/home.png [--w=375 --h=812 --full --scroll=0]
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const { chromium } = createRequire(path.join(root, 'design-prototype/package.json'))('playwright-core');
const arg = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const text = a.replace(/^--/, '');
    const at = text.indexOf('=');
    return at < 0 ? [text, 'true'] : [text.slice(0, at), text.slice(at + 1)];
  }),
);
if (!arg.url || !arg.out || !path.isAbsolute(arg.out)) throw new Error('--url and an absolute --out are required');

const executablePath = process.env.BROWSER_PATH || '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser';
const browser = await chromium.launch({ executablePath, headless: true });
const context = await browser.newContext({ viewport: { width: Number(arg.w ?? 375), height: Number(arg.h ?? 812) }, deviceScaleFactor: 1, reducedMotion: 'reduce' });
const page = await context.newPage();
const problems = [];
page.on('console', (m) => { if (m.type() === 'error') problems.push(`console: ${m.text()}`); });
page.on('pageerror', (e) => problems.push(`pageerror: ${e.message}`));
page.on('requestfailed', (r) => problems.push(`requestfailed: ${r.url()} ${r.failure()?.errorText}`));
await page.goto(arg.url, { waitUntil: 'load' });
await page.evaluate(async () => {
  await document.fonts.ready;
  const imgs = [...document.images];
  imgs.forEach((i) => { i.loading = 'eager'; });
  await Promise.all(imgs.map((i) => (i.complete ? Promise.resolve() : new Promise((r) => { i.onload = i.onerror = r; }))));
  await Promise.all(imgs.map((i) => i.decode().catch(() => {})));
});
if (arg.scroll) await page.evaluate((y) => window.scrollTo(0, y), Number(arg.scroll));
await page.waitForTimeout(400);
await page.screenshot({ path: arg.out, fullPage: arg.full === 'true' });
console.log(JSON.stringify({ out: arg.out, url: page.url(), problems }, null, 1));
await browser.close();
