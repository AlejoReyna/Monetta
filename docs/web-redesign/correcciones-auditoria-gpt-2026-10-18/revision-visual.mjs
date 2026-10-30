// Captures for the visual review of the corrections: the five main pages and the account entry
// at every viewport the review names, the flows the audit asks to look at (filters, quick
// view, variants, bag, search, account, keyboard focus above the dock) and the short
// viewports. JPEG, viewport-sized, one fresh page per shot.
//
//   node revision-visual.mjs --out=<folder> --url=http://127.0.0.1:4402
//
// Side insets are Chromium's CDP emulation (Emulation.setSafeAreaInsetsOverride), not a
// physical device; the 320×200, 360×225 and 640×400 viewports are CSS-pixel equivalents of
// 400 % and 200 % zoom, not the browser's own zoom control. File names say so.
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const prototype = fileURLToPath(new URL('../../../design-prototype/', import.meta.url));
const { launch } = await import(path.join(prototype, 'verify/browser.mjs'));
const { demoCartLines } = await import(path.join(prototype, 'verify/check-layout.mjs'));
const { catalog, scrollThrough, seedCart } = await import(path.join(prototype, 'verify/report.mjs'));
const { emulateSafeArea, settle } = await import(path.join(prototype, 'verify/probes.mjs'));

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
const VIEWPORTS = [
  { name: '320x568', width: 320, height: 568 },
  { name: '360x800', width: 360, height: 800 },
  { name: '375x812', width: 375, height: 812 },
  { name: '390x844', width: 390, height: 844 },
  { name: '440x956', width: 440, height: 956 },
  { name: '667x375-insets44', width: 667, height: 375, insets: INSETS },
  { name: '812x375-insets44', width: 812, height: 375, insets: INSETS },
  { name: '768x1024', width: 768, height: 1024 },
  { name: '1024x768', width: 1024, height: 768 },
  { name: '1440x900', width: 1440, height: 900 },
];
const SHORT = [
  { name: '320x200-reflow400', width: 320, height: 200 },
  { name: '360x225-reflow400', width: 360, height: 225 },
  { name: '640x400-reflow200', width: 640, height: 400 },
];

const { browser, version } = await launch();
const index = { capturedAt: new Date().toISOString(), browser: version, base, shots: [] };
const problems = [];

async function session(viewport, { cart = true } = {}) {
  const context = await browser.newContext({ viewport: { width: viewport.width, height: viewport.height }, reducedMotion: 'reduce', deviceScaleFactor: 1 });
  if (cart) await seedCart(context, demoCartLines());
  const page = await context.newPage();
  page.on('console', (message) => message.type() === 'error' && problems.push(`${viewport.name} console: ${message.text()}`));
  page.on('pageerror', (error) => problems.push(`${viewport.name} pageerror: ${error.message}`));
  page.on('requestfailed', (request) => problems.push(`${viewport.name} requestfailed: ${request.url()}`));
  const safeArea = viewport.insets ? await emulateSafeArea(page, viewport.insets) : null;
  return { context, page, safeArea };
}
async function load(page, route, { lazy = true } = {}) {
  await page.goto(base + route, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  if (lazy) await scrollThrough(page);
  await settle(page);
}
async function shot(page, name, meta) {
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  await page.screenshot({ path: path.join(out, `${name}.jpg`), type: 'jpeg', quality: 82 });
  index.shots.push({ file: `${name}.jpg`, overflow, ...meta });
  if (overflow > 0) problems.push(`${name}: ${overflow}px of horizontal overflow`);
}

// ----------------------------------------------------------------------- A · matrix
for (const viewport of VIEWPORTS) {
  const { context, page, safeArea } = await session(viewport);
  for (const [name, route] of PAGES) {
    await load(page, route);
    await shot(page, `A-${viewport.name}-${name}`, { section: 'matrix', viewport: viewport.name, page: name });
  }
  await safeArea?.clear();
  await context.close();
}

// ----------------------------------------------------------------------- B · flows
{
  const viewport = { name: '390x844', width: 390, height: 844 };
  const { context, page } = await session(viewport);

  await load(page, '/collections/guess');
  await page.locator('[data-page-bar] [data-open-filters]').click();
  await page.locator('[data-apply]').waitFor({ state: 'visible' });
  await page.waitForTimeout(400);
  await shot(page, 'B-390x844-filtros-abiertos', { section: 'flow', page: 'collection', state: 'filters drawer' });
  await page.keyboard.press('Escape');

  // The first catalog page holds only single-variant products; a search finds one with choices.
  const multi = catalog.products.find((entry) => entry.variants.length > 1);
  await load(page, `/search?q=${encodeURIComponent(multi.title)}&type=product`);
  await page.locator(`[data-action="quick-add"][data-handle="${multi.handle}"]`).click();
  await page.locator('.overlay--sheet.is-open').waitFor();
  await page.waitForTimeout(400);
  await shot(page, 'B-390x844-vista-rapida', { section: 'flow', page: 'collection', state: 'quick view (variant required)' });
  await page.keyboard.press('Escape');

  await load(page, PRODUCT);
  const options = page.locator('.product-panel input[type="radio"]');
  if (await options.count()) {
    await options.nth(2).check({ force: true });
    await settle(page);
  }
  await page.locator('.product-panel__options').first().scrollIntoViewIfNeeded();
  await settle(page);
  await shot(page, 'B-390x844-variantes', { section: 'flow', page: 'product', state: 'variant chosen' });

  await load(page, '/search');
  await page.fill('#page-search-input', 'tote');
  await page.waitForSelector('#page-search-listbox .search-option__product');
  await settle(page);
  await shot(page, 'B-390x844-busqueda-sugerencias', { section: 'flow', page: 'search', state: 'suggestions' });

  await load(page, '/account');
  await shot(page, 'B-390x844-cuenta', { section: 'flow', page: 'account' });

  await load(page, '/');
  await page.locator('[data-action="menu"]:visible').first().click();
  await page.locator('.overlay--drawer-left.is-open').waitFor();
  await page.waitForTimeout(400);
  await shot(page, 'B-390x844-menu', { section: 'flow', page: 'home', state: 'menu drawer' });
  await context.close();
}
{
  // Keyboard focus on the footer links the audit named: text and ring above the dock.
  const viewport = { name: '390x844', width: 390, height: 844 };
  const { context, page } = await session(viewport, { cart: false });
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
      await shot(page, `B-390x844-foco-${label.replace(/\s+/g, '-').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()}`, { section: 'flow', page: 'collection', state: `keyboard focus on footer link "${label}"` });
    }
  }
  if (seen.size < wanted.length) problems.push(`keyboard focus: only reached ${[...seen].join(', ')}`);
  await context.close();
}
for (const viewport of [VIEWPORTS.find((entry) => entry.name === '667x375-insets44'), VIEWPORTS.find((entry) => entry.name === '812x375-insets44')]) {
  const { context, page, safeArea } = await session(viewport);
  await load(page, '/');
  await page.locator('[data-action="menu"]:visible').first().click();
  await page.locator('.overlay--drawer-left.is-open').waitFor();
  await page.waitForTimeout(400);
  await shot(page, `B-${viewport.name}-menu`, { section: 'flow', page: 'home', state: 'menu drawer with insets' });
  await page.keyboard.press('Escape');
  await load(page, '/collections/guess');
  await page.locator('[data-open-filters]:visible').first().click();
  await page.locator('[data-apply]').waitFor({ state: 'visible' });
  await page.waitForTimeout(400);
  await shot(page, `B-${viewport.name}-filtros`, { section: 'flow', page: 'collection', state: 'filters drawer with insets' });
  await page.keyboard.press('Escape');
  if (viewport.width >= 768) {
    await load(page, '/');
    await page.locator('[data-action="cart"]:visible').first().click();
    await page.locator('.overlay--drawer-right.is-open').waitFor();
    await page.waitForTimeout(400);
    await shot(page, `B-${viewport.name}-carrito`, { section: 'flow', page: 'home', state: 'bag drawer with insets' });
  }
  await safeArea?.clear();
  await context.close();
}

// ----------------------------------------------------------------------- C · short viewports
for (const viewport of SHORT) {
  const { context, page } = await session(viewport);
  for (const [name, route] of PAGES.filter(([page]) => page !== 'account')) {
    await load(page, route);
    await page.evaluate(() => scrollTo(0, 0));
    await settle(page);
    await shot(page, `C-${viewport.name}-${name}-inicio`, { section: 'short', viewport: viewport.name, page: name, position: 'top' });
    await page.evaluate(() => scrollTo(0, document.documentElement.scrollHeight));
    await settle(page);
    await shot(page, `C-${viewport.name}-${name}-final`, { section: 'short', viewport: viewport.name, page: name, position: 'end' });
  }
  if (viewport.name.startsWith('320')) {
    await load(page, '/collections/guess');
    await page.locator('[data-page-bar] [data-open-filters]').click();
    await page.locator('[data-apply]').waitFor({ state: 'visible' });
    await page.waitForTimeout(400);
    await shot(page, `C-${viewport.name}-filtros-abiertos`, { section: 'short', page: 'collection', state: 'filters drawer' });
    await page.keyboard.press('Escape');
    await load(page, '/cart');
    await page.locator('.summary [data-checkout]').scrollIntoViewIfNeeded();
    await page.locator('.summary [data-checkout]').click();
    await page.locator('[role="dialog"]').waitFor({ state: 'visible' });
    await page.waitForTimeout(400);
    await shot(page, `C-${viewport.name}-checkout-abierto`, { section: 'short', page: 'cart', state: 'checkout dialog' });
  }
  await context.close();
}

await browser.close();
index.problems = problems;
index.count = index.shots.length;
await writeFile(path.join(out, 'index.json'), `${JSON.stringify(index, null, 2)}\n`);
console.log(`${index.count} captures, ${problems.length} problems${problems.length ? `: ${problems.slice(0, 5).join(' | ')}` : ''}`);
