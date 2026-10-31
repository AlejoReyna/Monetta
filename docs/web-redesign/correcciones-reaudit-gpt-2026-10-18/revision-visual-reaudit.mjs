// Captures for the final visual confirmation of RE-01 and RE-02: the normal views the correction must not
// change, the limit cases on both sides of 1023/1024 px and 480/481 px, the 44px emulated insets, the flows the
// reaudit asks to look at (filters, search, product, bag, Back and Forward, the footer focus) in short desktop
// windows, and the keyboard walk through the tablet category row, one crop per stop.
//
//   node revision-visual-reaudit.mjs --out=<folder> --url=http://127.0.0.1:4602
//
// JPEG, viewport-sized, one fresh page per shot. The insets are Chromium's CDP emulation, and the sizes are CSS
// viewports, not the browser's zoom control; the file names say so.
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const prototype = fileURLToPath(new URL('../../../design-prototype/', import.meta.url));
const { launch } = await import(path.join(prototype, 'verify/browser.mjs'));
const { demoCartLines } = await import(path.join(prototype, 'verify/check-layout.mjs'));
const { scrollThrough, seedCart } = await import(path.join(prototype, 'verify/report.mjs'));
const { describeFocus, emulateSafeArea, keyboardTraversal, settle } = await import(path.join(prototype, 'verify/probes.mjs'));

const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
if (!args.out || !args.url) throw new Error('--out=<folder> and --url=<served build> are required');
const out = path.resolve(args.out);
const base = args.url.replace(/\/$/, '');
await mkdir(out, { recursive: true });

const PRODUCT = '/products/bolso-coach-shoulder-negro-rectangular';
const INSETS = { left: 44, right: 44, top: 0, bottom: 21 };
const PAGES = [
  ['home', '/'],
  ['collection', '/collections/guess'],
  ['product', PRODUCT],
  ['search', '/search?q=bolsa&type=product'],
  ['cart', '/cart'],
  ['account', '/account'],
];
const NORMAL = [
  [375, 812],
  [440, 956],
  [768, 1024],
  [1024, 768],
  [1440, 900],
];

const { browser, version } = await launch();
const index = { capturedAt: new Date().toISOString(), browser: version, base, shots: [] };
const problems = [];

async function session(width, height, { cart = true, insets = null } = {}) {
  const context = await browser.newContext({ viewport: { width, height }, reducedMotion: 'reduce', deviceScaleFactor: 1 });
  if (cart) await seedCart(context, demoCartLines());
  const page = await context.newPage();
  const label = `${width}x${height}`;
  page.on('console', (message) => message.type() === 'error' && problems.push(`${label} console: ${message.text()}`));
  page.on('pageerror', (error) => problems.push(`${label} pageerror: ${error.message}`));
  page.on('requestfailed', (request) => problems.push(`${label} requestfailed: ${request.url()}`));
  const safeArea = insets ? await emulateSafeArea(page, insets) : null;
  return { context, page, safeArea };
}
async function load(page, route, { lazy = true } = {}) {
  await page.goto(base + route, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  if (lazy) await scrollThrough(page);
  await settle(page);
}
async function shot(page, name, meta, options = {}) {
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  await page.screenshot({ path: path.join(out, `${name}.jpg`), type: 'jpeg', quality: 84, ...options });
  index.shots.push({ file: `${name}.jpg`, overflow, ...meta });
  if (overflow > 0) problems.push(`${name}: ${overflow}px of horizontal overflow`);
}
const scrollTo = async (page, pixels) => {
  await page.evaluate((amount) => scrollTo(0, Math.min(amount, document.documentElement.scrollHeight - innerHeight)), pixels);
  await settle(page);
};

// ----------------------------------------------------------------------- A · the normal views
for (const [width, height] of NORMAL) {
  const { context, page } = await session(width, height);
  for (const [name, route] of PAGES) {
    await load(page, route);
    await shot(page, `A-${width}x${height}-${name}`, { section: 'normal', viewport: `${width}×${height}`, page: name });
  }
  await context.close();
}

// ----------------------------------------------------------------------- B · limits, both sides
for (const [width, height, route, name, scroll] of [
  [1023, 200, '/collections/guess', 'coleccion', 800],
  [1024, 200, '/collections/guess', 'coleccion', 800],
  [1024, 200, PRODUCT, 'ficha', 600],
  [1024, 200, '/cart', 'bolsa', 400],
  [1280, 200, PRODUCT, 'ficha', 500],
  [1280, 200, '/collections/guess', 'coleccion-con-filtros', 500],
  [1280, 200, '/cart', 'bolsa', 400],
  [1440, 360, '/collections/guess', 'coleccion-con-filtros', 700],
  [1440, 360, PRODUCT, 'ficha', 500],
  [1024, 480, PRODUCT, 'ficha-limite-480', 300],
  [1024, 481, PRODUCT, 'ficha-limite-481', 300],
  [1440, 480, PRODUCT, 'ficha-limite-480', 300],
  [1440, 481, PRODUCT, 'ficha-limite-481', 300],
]) {
  const { context, page } = await session(width, height);
  await load(page, route);
  await scrollTo(page, scroll);
  await shot(page, `B-${width}x${height}-${name}`, { section: 'limit', viewport: `${width}×${height}`, page: name, scrolled: scroll });
  await context.close();
}
for (const [width, height] of [
  [1024, 200],
  [812, 300],
]) {
  const { context, page, safeArea } = await session(width, height, { insets: INSETS });
  for (const [name, route, scroll] of [
    ['inicio', '/', 0],
    ['coleccion', '/collections/guess', 500],
  ]) {
    await load(page, route);
    await scrollTo(page, scroll);
    await shot(page, `B-${width}x${height}-insets44-${name}`, { section: 'limit', viewport: `${width}×${height}`, page: name, insets: '44 px (CDP emulation)' });
  }
  await safeArea.clear();
  await context.close();
}

// ----------------------------------------------------------------------- C · flows in short desktop windows
{
  const [width, height] = [1024, 300];
  const { context, page } = await session(width, height);

  await load(page, '/collections/guess');
  await page.locator('[data-open-filters]:visible').first().click();
  await page.locator('[data-apply]').waitFor({ state: 'visible' });
  await page.waitForTimeout(400);
  await shot(page, `C-${width}x${height}-filtros-abiertos`, { section: 'flow', page: 'collection', state: 'filters drawer' });
  await page.keyboard.press('Escape');

  await load(page, '/');
  await page.fill('#header-search-input', 'tote');
  await page.waitForSelector('.search-panel:not([hidden]) .search-option__product');
  await settle(page);
  await shot(page, `C-${width}x${height}-busqueda-sugerencias`, { section: 'flow', page: 'home', state: 'header search suggestions' });

  await load(page, PRODUCT);
  const add = page.locator('[data-add]:visible').first();
  await add.scrollIntoViewIfNeeded();
  await add.click();
  await page.waitForTimeout(500);
  await shot(page, `C-${width}x${height}-ficha-agregada`, { section: 'flow', page: 'product', state: 'after adding to the bag' });

  const bag = await session(width, height);
  await load(bag.page, '/cart');
  const checkout = bag.page.locator('[data-checkout]:visible').first();
  await checkout.scrollIntoViewIfNeeded();
  await checkout.click();
  await bag.page.locator('[role="dialog"]').waitFor({ state: 'visible' });
  await bag.page.waitForTimeout(400);
  await shot(bag.page, `C-${width}x${height}-bolsa-checkout`, { section: 'flow', page: 'cart', state: 'checkout handoff' });
  await bag.context.close();

  const history = await session(width, height);
  await load(history.page, '/');
  await history.page.locator('.site-nav a[href="/collections/guess"]').click();
  await history.page.waitForURL(/\/collections\/guess$/);
  await settle(history.page);
  await scrollTo(history.page, 600);
  await history.page.evaluate(() => document.querySelectorAll('[data-grid] .card__link')[2].click());
  await history.page.waitForURL(/\/products\//);
  await settle(history.page);
  await history.page.goBack({ waitUntil: 'commit' });
  await history.page.waitForURL(/\/collections\/guess$/);
  await history.page.waitForTimeout(500);
  await shot(history.page, `C-${width}x${height}-atras`, { section: 'flow', page: 'collection', state: 'after the browser Back (scroll restored)' });
  await history.page.goForward({ waitUntil: 'commit' });
  await history.page.waitForTimeout(500);
  await shot(history.page, `C-${width}x${height}-adelante`, { section: 'flow', page: 'product', state: 'after the browser Forward' });
  await history.context.close();

  const facet = await session(1440, 360);
  await load(facet.page, '/collections/guess');
  await facet.page.locator('.filter-sidebar .check').first().click();
  await facet.page.waitForURL(/filter\./);
  await facet.page.waitForTimeout(500);
  await shot(facet.page, 'C-1440x360-filtro-barra-lateral', { section: 'flow', page: 'collection', state: 'sidebar facet applied' });
  await facet.context.close();
  await context.close();
}
for (const [width, height] of [
  [1024, 300],
  [1440, 900],
]) {
  const { context, page } = await session(width, height, { cart: false });
  await load(page, '/collections/guess', { lazy: false });
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  const wanted = ['Novedades', 'Envíos', 'Mi cuenta'];
  const seen = new Set();
  for (let step = 0; step < 160 && seen.size < wanted.length; step += 1) {
    await page.keyboard.press('Tab');
    await settle(page);
    const label = await page.evaluate(() => (document.activeElement.closest('#site-footer') ? document.activeElement.textContent.trim() : ''));
    if (wanted.includes(label) && !seen.has(label)) {
      seen.add(label);
      await page.waitForTimeout(150);
      await shot(page, `C-${width}x${height}-foco-pie-${label.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, '-').toLowerCase()}`, { section: 'flow', page: 'collection', state: `keyboard focus on the footer link "${label}"` });
    }
  }
  if (seen.size < wanted.length) problems.push(`footer focus ${width}×${height}: only reached ${[...seen].join(', ')}`);
  await context.close();
}

// ----------------------------------------------------------------------- D · the category row with the keyboard, one crop per stop
for (const [width, height, insets] of [
  [768, 1024, null],
  [812, 1024, null],
  [1023, 768, null],
  [1024, 768, null],
  [812, 375, INSETS],
]) {
  const { context, page, safeArea } = await session(width, height, { cart: false, insets });
  await load(page, '/', { lazy: false });
  const suffix = insets ? `${width}x${height}-insets44` : `${width}x${height}`;
  const row = await page.evaluate(() => {
    const rect = document.querySelector('.site-nav').getBoundingClientRect();
    return { top: rect.top, height: rect.height };
  });
  const clip = { x: 0, y: Math.max(0, Math.floor(row.top - 8)), width, height: Math.ceil(row.height + 16) };
  const cropAt = async (label, direction, step) => shot(page, `D-${suffix}-${direction}-${String(step).padStart(2, '0')}-${label.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/gi, '-').toLowerCase()}`, { section: 'category-row', viewport: suffix, direction, step, label }, { clip });
  let step = 0;
  const forward = await keyboardTraversal(page, {
    enterContent: false,
    pixelRegions: ['nav'],
    maskedScroller: '.site-nav__list',
    onStop: async (stop) => {
      if (stop.region !== 'nav') return;
      step += 1;
      await cropAt(stop.label, 'tab', step);
    },
    stopWhen: (stop) => stop.region === 'nav' && stop.label === 'Nuestra historia',
  });
  // And back: one Shift+Tab at a time, described once the row has settled, then cropped.
  for (let back = 1; back <= 8; back += 1) {
    await page.keyboard.press('Shift+Tab');
    const stop = await describeFocus(page);
    await cropAt(stop?.label ?? `stop-${back}`, 'shift-tab', back);
  }
  if (!forward.length) problems.push(`category row ${suffix}: no stops`);
  await safeArea?.clear();
  await context.close();
}

await browser.close();
index.problems = problems;
index.count = index.shots.length;
await writeFile(path.join(out, 'index.json'), `${JSON.stringify(index, null, 2)}\n`);
console.log(`${index.count} captures, ${problems.length} problems${problems.length ? `: ${problems.slice(0, 5).join(' | ')}` : ''}`);
