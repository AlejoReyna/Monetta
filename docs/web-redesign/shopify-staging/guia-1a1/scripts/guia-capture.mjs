// Captures of the guide 1:1 pass, one per guide slide, at the phone and desktop widths of the comparison sheets
// (390x844 and 1440x900). Each capture waits for the web fonts and for every image to be complete and decoded (the page is
// scrolled through first so lazy images load), then writes a viewport PNG and a full-page PNG. index.json records the URL,
// the theme state and any image that did not load.
//
//   node guia-capture.mjs --base-url=http://127.0.0.1:9292 --out=<absolute folder> [--only=03,06] [--widths=390,1440]
//
// The output folder is always explicit, so an earlier set is never overwritten by accident.
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { browserPath, chromium, parseArgs, target, treeDigest } from '../../scripts/e2e/lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
if (!args.out || !path.isAbsolute(args.out)) throw new Error('--out=<absolute folder> is required');
const out = args.out;
mkdirSync(out, { recursive: true });
const HEIGHTS = { 390: 844, 1440: 900 };
const widths = (args.widths || '390,1440').split(',').map(Number);
const only = args.only ? new Set(args.only.split(',')) : null;

const openDrawer = async (page) => {
  await page.locator('[data-open-menu], [aria-controls="menu-drawer"]').first().click();
  await page.waitForSelector('dialog[open]');
  await page.waitForTimeout(450);
};
const openSearch = async (page) => {
  const input = page.locator('input[type="search"]:visible').first();
  if (await input.count()) {
    await input.click();
    await input.fill('bolso coach');
    await page.waitForTimeout(1500);
  }
};
const openQuickView = async (page) => {
  const trigger = page.locator('[data-quick-view]:visible').first();
  if (await trigger.count()) {
    await trigger.click();
    await page.waitForSelector('dialog[open]');
    await page.waitForTimeout(600);
  }
};

// slide → route. A slide without a web page here is listed in RESULTADO.md with the reason.
const SLIDES = [
  { slide: '01', name: 'bienvenida', url: '/password' },
  { slide: '03', name: 'inicio', url: '/' },
  { slide: '05', name: 'busqueda', url: '/search?q=bolso+coach&type=product' },
  { slide: '05b', name: 'busqueda-predictiva', url: '/', prepare: openSearch },
  { slide: '06', name: 'coleccion-coach', url: '/collections/vendors?q=Coach' },
  { slide: '07', name: 'coleccion-michael-kors', url: '/collections/vendors?q=Michael%20Kors' },
  { slide: '08', name: 'coleccion-steve-madden', url: '/collections/vendors?q=Steve%20Madden' },
  { slide: '09', name: 'coleccion-tory-burch', url: '/collections/vendors?q=Tory%20Burch' },
  { slide: '12', name: 'preview', url: '/collections/vendors?q=Coach', prepare: openQuickView },
  { slide: '13', name: 'producto', url: '/products/bolso-coach-shoulder-negro-rectangular' },
  { slide: '14', name: 'coleccion-totes', url: '/collections/all/tote' },
  { slide: '15', name: 'coleccion-shoulder', url: '/collections/all/shoulder' },
  { slide: '17', name: 'coleccion-carteras', url: '/collections/all/carteras' },
  { slide: '19', name: 'coleccion-accesorios', url: '/collections/all/reloj' },
  { slide: '20', name: 'coleccion-crossbody', url: '/collections/all/crossbody' },
  { slide: '21', name: 'mayoreo', url: '/pages/contact?view=mayoreo' },
  { slide: '25', name: 'rewards', url: '/pages/contact?view=rewards' },
  { slide: '27', name: 'contacto', url: '/pages/contact' },
  { slide: '28', name: 'carrito', url: '/cart', bag: true },
  { slide: '29', name: 'categorias', url: '/collections' },
  { slide: '30', name: 'menu', url: '/', prepare: openDrawer },
];

async function settle(page) {
  await page.evaluate(async () => {
    await document.fonts.ready;
    const step = Math.max(200, Math.floor(window.innerHeight * 0.8));
    for (let y = 0; y < document.documentElement.scrollHeight; y += step) {
      window.scrollTo(0, y);
      await new Promise((r) => setTimeout(r, 120));
    }
    window.scrollTo(0, 0);
    // Lazy images off screen sideways (rails) may never load: wait for the rest, at most 8 s, and report the stragglers.
    const loaded = Promise.all([...document.images].map((img) => (img.complete ? img.decode().catch(() => {}) : new Promise((r) => {
      img.addEventListener('load', r, { once: true });
      img.addEventListener('error', r, { once: true });
    }))));
    await Promise.race([loaded, new Promise((r) => setTimeout(r, 8000))]);
  });
  await page.waitForTimeout(400);
}

const browser = await chromium.launch({ executablePath: browserPath(), headless: true });
const index = { baseUrl, theme: target, storefrontTheme: treeDigest(), startedAt: new Date().toISOString(), captures: [] };
try {
  for (const width of widths) {
    const context = await browser.newContext({ viewport: { width, height: HEIGHTS[width] || 900 }, deviceScaleFactor: 1, locale: 'es-MX' });
    const page = await context.newPage();
    for (const s of SLIDES) {
      if (only && !only.has(s.slide)) continue;
      if (s.bag) {
        await page.goto(`${baseUrl}/`, { waitUntil: 'load' });
        await page.evaluate(async () => {
          await fetch('/cart/clear.js', { method: 'POST' });
          const p = await (await fetch('/products.json?limit=30')).json();
          const v = p.products.flatMap((x) => x.variants).find((x) => x.available);
          if (v) await fetch('/cart/add.js', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: v.id, quantity: 1 }) });
        });
      }
      const response = await page.goto(`${baseUrl}${s.url}`, { waitUntil: 'load' });
      await settle(page);
      if (s.prepare) await s.prepare(page).catch((e) => index.captures.push({ slide: s.slide, width, prepareError: String(e.message || e) }));
      const broken = await page.evaluate(() => [...document.images].filter((i) => i.loading !== "lazy" && i.currentSrc && !i.naturalWidth).map((i) => i.currentSrc));
      const base = `${s.slide}-${s.name}-${width}`;
      await page.screenshot({ path: path.join(out, `${base}.png`) });
      if (!s.prepare) await page.screenshot({ path: path.join(out, `${base}-full.png`), fullPage: true });
      index.captures.push({ slide: s.slide, name: s.name, width, url: s.url, status: response?.status(), finalUrl: page.url(), brokenImages: broken });
      console.log(`${base}  ${response?.status()}  ${broken.length ? `broken: ${broken.length}` : ''}`);
    }
    await context.close();
  }
} finally {
  await browser.close();
  index.finishedAt = new Date().toISOString();
  writeFileSync(path.join(out, 'index.json'), `${JSON.stringify(index, null, 2)}\n`);
}
