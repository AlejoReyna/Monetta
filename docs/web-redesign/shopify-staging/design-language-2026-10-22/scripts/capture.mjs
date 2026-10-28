// Before/after captures for the app design-language pass (22 Oct 2026). Opens each route in the installed Brave
// (playwright-core from design-prototype/), waits for fonts and for every image to be complete and decoded, and
// writes viewport and full-page PNGs plus index.json and one contact sheet per width.
//
//   node capture.mjs --base-url=http://127.0.0.1:9292 --out=<absolute folder> [--widths=320,390,768,1024,1440] [--only=home,product]
//
// The output folder is always explicit: an earlier set is never overwritten by accident.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { launch, parseArgs, settle, imageReport } from '../../scripts/e2e/lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
if (!args.out || !path.isAbsolute(args.out)) throw new Error('--out=<absolute folder> is required');
const out = args.out;
mkdirSync(out, { recursive: true });
const HEIGHTS = { 320: 640, 360: 740, 390: 844, 768: 1024, 1024: 768, 1280: 800, 1440: 900 };
const widths = (args.widths || '320,390,768,1024,1440').split(',').map(Number);
const only = args.only ? new Set(args.only.split(',')) : null;

const PRODUCT = '/products/reloj-coach-talia-saddle';
const PARTIAL = '/products/bolso-steve-madden-crossbody-3';
const LONG = '/products/bolso-michael-kors-marilyn-medium-signature-convertible-satchel-vanilla-rosa';
const SALE = '/products/bolso-steve-madden-shoulder-negro';

async function gotoOk(page, url, tries = 4) {
  for (let i = 1; i <= tries; i += 1) {
    const response = await page.goto(url, { waitUntil: 'load' });
    const broken = await page.evaluate(() => /Failed to render storefront|Bad Gateway|unauthorized/i.test(document.body?.innerText || ''));
    if (!broken) return response;
    await page.waitForTimeout(3000);
  }
  throw new Error(`proxy kept answering with an error page for ${url}`);
}

async function addToBag(page, handles) {
  await page.evaluate(async (list) => {
    await fetch('/cart/clear.js', { method: 'POST' });
    for (const handle of list) {
      const p = await (await fetch(`/products/${handle}.js`)).json();
      const v = p.variants.find((x) => x.available);
      if (v) await fetch('/cart/add.js', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: v.id, quantity: 1 }) });
    }
  }, handles);
}

// name → { url, full, phoneOnly, prepare }
const STATES = [
  { name: 'home', url: '/', full: true },
  { name: 'collection', url: '/collections/all', full: true },
  { name: 'search', url: '/search?q=bolso&type=product' },
  { name: 'search-zero', url: '/search?q=zzqxv&type=product' },
  { name: 'product', url: PRODUCT, full: true },
  { name: 'product-sale', url: SALE },
  { name: 'product-long-name', url: LONG },
  {
    name: 'product-soldout-variant',
    url: PARTIAL,
    prepare: async (page) => {
      const id = await page.evaluate(async (p) => (await (await fetch(`${p}.js`)).json()).variants.find((v) => !v.available)?.id, PARTIAL);
      if (id) await gotoOk(page, `${baseUrl}${PARTIAL}?variant=${id}`);
    },
  },
  { name: 'bag-empty', url: '/cart', prepare: async (page) => { await page.evaluate(() => fetch('/cart/clear.js', { method: 'POST' })); await gotoOk(page, `${baseUrl}/cart`); } },
  {
    name: 'bag',
    url: '/cart',
    full: true,
    prepare: async (page) => {
      await addToBag(page, ['reloj-coach-talia-saddle', 'bolso-steve-madden-shoulder-negro']);
      await gotoOk(page, `${baseUrl}/cart`);
    },
  },
  { name: 'contact', url: '/pages/contact', full: true },
  { name: 'not-found', url: '/pages/no-existe' },
  { name: 'collections-index', url: '/collections' },
  { name: 'blog', url: '/blogs/news' },
  { name: 'policy', url: '/policies/privacy-policy' },
  {
    name: 'menu-drawer',
    url: '/',
    phoneOnly: true,
    prepare: async (page) => {
      await page.locator('.site-header__menu:visible').first().click();
      await page.waitForSelector('#menu-drawer[open]');
      await page.waitForTimeout(600);
    },
  },
  {
    name: 'saved-drawer',
    url: '/collections/all',
    prepare: async (page) => {
      await page.evaluate(() => {
        try { localStorage.setItem('monetta.web.saved.v1', JSON.stringify(['reloj-coach-talia-saddle', 'bolso-steve-madden-shoulder-negro'])); } catch {}
      });
      await gotoOk(page, `${baseUrl}/collections/all`);
      const opener = page.locator('[data-open-dialog="saved-products"]:visible').first();
      if (await opener.count()) {
        await opener.click();
      } else {
        await page.locator('.site-header__menu:visible').first().click();
        await page.waitForSelector('#menu-drawer[open]');
        await page.locator('#menu-drawer [data-open-dialog="saved-products"]').first().click();
      }
      await page.waitForSelector('#saved-products[open]');
      await page.waitForFunction(() => !/Cargando/.test(document.querySelector('[data-saved-status]')?.textContent || ''), null, { timeout: 20000 }).catch(() => {});
      await page.waitForTimeout(600);
    },
  },
];

const index = [];
for (const w of widths) {
  const h = HEIGHTS[w] || 900;
  const { browser, page } = await launch({ width: w, height: h, reducedMotion: 'reduce' });
  page.setDefaultTimeout(30000);
  const consoleErrors = [];
  page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('pageerror', (e) => consoleErrors.push(`pageerror: ${e.message}`));
  for (const state of STATES) {
    if (only && !only.has(state.name)) continue;
    if (state.phoneOnly && w >= 768) continue;
    const errorsBefore = consoleErrors.length;
    try {
      const response = await gotoOk(page, `${baseUrl}${state.url}`);
      if (state.prepare) await state.prepare(page);
      // Twice: rails filled by script after load (recent views, more from the brand) insert their cards late.
      await settle(page);
      await page.waitForTimeout(1500);
      const stuck = await settle(page);
      const images = await imageReport(page);
      const file = `${w}-${state.name}.png`;
      await page.screenshot({ path: path.join(out, file) });
      const entry = { file, width: w, height: h, name: state.name, url: page.url().replace(baseUrl, ''), status: response?.status() ?? null, brokenImages: images.broken.length + stuck.length, visibleImages: images.total };
      if (state.full) {
        const fullFile = `${w}-${state.name}-full.png`;
        await page.screenshot({ path: path.join(out, fullFile), fullPage: true });
        entry.full = fullFile;
      }
      entry.consoleErrors = consoleErrors.slice(errorsBefore).filter((t) => !/shopify|monorail|trekkie|web-pixels|analytics|perf-kit|ERR_BLOCKED|favicon/i.test(t));
      index.push(entry);
      console.log(`ok   ${file}${entry.brokenImages ? ` broken=${entry.brokenImages}` : ''}${entry.consoleErrors.length ? ` console=${entry.consoleErrors.length}` : ''}`);
    } catch (error) {
      index.push({ name: state.name, width: w, error: String(error.message).split('\n')[0] });
      console.log(`FAIL ${w}-${state.name}: ${String(error.message).split('\n')[0]}`);
    }
  }
  await browser.close();
}
writeFileSync(path.join(out, 'index.json'), `${JSON.stringify({ baseUrl, capturedAt: new Date().toISOString(), captures: index }, null, 2)}\n`);

// One contact sheet per width (viewport captures only), to review a set by eye.
const { browser, page } = await launch({ width: 1800, height: 1000 });
for (const w of widths) {
  const items = index.filter((i) => i.width === w && i.file);
  if (!items.length) continue;
  const perRow = w >= 1024 ? 3 : w >= 768 ? 4 : 6;
  const cell = Math.floor((1784 - (perRow - 1) * 8) / perRow);
  const html = `<body style="margin:0;background:#d8d8d8;font:13px sans-serif"><div style="display:flex;flex-wrap:wrap;gap:8px;padding:8px">${items
    .map((i) => `<figure style="margin:0;width:${cell}px"><img style="width:100%;display:block;border:1px solid #999;background:#fff" src="data:image/png;base64,${readFileSync(path.join(out, i.file)).toString('base64')}"><figcaption>${w}px · ${i.name}${i.brokenImages ? ' — BROKEN IMAGES' : ''}</figcaption></figure>`)
    .join('')}</div></body>`;
  await page.setContent(html);
  await page.evaluate(() => Promise.all([...document.images].map((im) => im.decode())));
  await page.screenshot({ path: path.join(out, `sheet-${w}.png`), fullPage: true });
}
await browser.close();
console.log(`captures: ${index.filter((i) => i.file).length}, failures: ${index.filter((i) => i.error).length} → ${out}`);
