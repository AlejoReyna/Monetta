// Real browser captures of the principal pages and key states.
//
//   npm run capture                         # build, serve, write ../docs/web-redesign/screenshots/
//   npm run capture -- --skip-build --only=home
import { mkdir, readdir, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { launch } from './browser.mjs';
import { demoCartLines } from './check-layout.mjs';
import { scrollThrough, seedCart } from './report.mjs';
import { build, startPreview } from './server.mjs';

const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
const root = fileURLToPath(new URL('..', import.meta.url));
const outDir = path.resolve(root, args.out ?? '../docs/web-redesign/screenshots');

const PHONE = { width: 390, height: 844 };
const SMALL = { width: 375, height: 812 };
const TABLET = { width: 768, height: 1024 };
const LAPTOP = { width: 1024, height: 768 };
const WIDE = { width: 1280, height: 800 };
const DESKTOP = { width: 1440, height: 900 };

const scrollTo = (selector, offset = 150) => async (page) => {
  await page.evaluate(
    ([query, gap]) => {
      const element = document.querySelector(query);
      if (element) window.scrollTo(0, element.getBoundingClientRect().top + window.scrollY - gap);
    },
    [selector, offset],
  );
  await page.waitForTimeout(500);
};
const click = (selector, wait = 500) => async (page) => {
  await page.click(selector);
  await page.waitForTimeout(wait);
};
const demo = (key) => async (page) => {
  await page.click('.proto-strip__button');
  await page.click(`#demo-${key}`);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(400);
};

// [name, path, viewport, { dpr, full, cart, steps }]
const JOBS = [
  ['home__phone-390__top', '/', PHONE, { dpr: 2 }],
  ['home__phone-390__full', '/', PHONE, { full: true }],
  ['home__tablet-768__full', '/', TABLET, { full: true }],
  ['home__desktop-1440__top', '/', DESKTOP, {}],
  ['home__desktop-1440__full', '/', DESKTOP, { full: true }],

  ['collection__phone-390__top', '/collections/guess', PHONE, { dpr: 2 }],
  ['collection__phone-390__full', '/collections/guess', PHONE, { full: true }],
  ['collection__tablet-768__full', '/collections/guess', TABLET, { full: true }],
  ['collection__laptop-1024__top', '/collections/guess', LAPTOP, {}],
  ['collection__wide-1280__top', '/collections/guess', WIDE, {}],
  ['collection__desktop-1440__full', '/collections/guess', DESKTOP, { full: true }],
  ['collection__desktop-1440__filtered', '/collections/guess?filter.p.m.custom.estilo=Satchel&filter.p.m.custom.marca=Guess&filter.p.m.custom.marca=Steve+Madden&sort_by=price-ascending', DESKTOP, {}],
  ['collection__phone-390__filter-drawer', '/collections/guess', PHONE, { dpr: 2, steps: [click('[data-open-filters]')] }],
  ['collection__phone-390__empty-filtered', '/collections/relojes?filter.v.availability=0', PHONE, { dpr: 2 }],
  ['collection__phone-390__scrolled', '/collections/guess', PHONE, { dpr: 2, steps: [scrollTo('[data-grid] li:nth-child(9)', 320)] }],
  ['brand__desktop-1440__coach', '/collections/coach', DESKTOP, {}],

  ['product__phone-390__top', '/products/bolso-coach-shoulder-negro-rectangular', PHONE, { dpr: 2 }],
  ['product__phone-390__options', '/products/bolso-coach-shoulder-negro-rectangular', PHONE, { dpr: 2, steps: [scrollTo('.product-panel__name', 110)] }],
  ['product__phone-375__purchase', '/products/bolso-coach-shoulder-negro-rectangular', SMALL, { dpr: 2, steps: [scrollTo('.other-ways', 140)] }],
  ['product__phone-390__full', '/products/bolso-coach-shoulder-negro-rectangular', PHONE, { full: true }],
  ['product__tablet-768__full', '/products/bolso-coach-shoulder-negro-rectangular', TABLET, { full: true }],
  ['product__desktop-1440__top', '/products/bolso-coach-shoulder-negro-rectangular', DESKTOP, {}],
  ['product__desktop-1440__full', '/products/bolso-coach-shoulder-negro-rectangular', DESKTOP, { full: true }],
  ['product__desktop-1440__sale', '/products/bolso-guess-crossbody-negro-1', DESKTOP, {}],
  ['product__desktop-1440__envio-inmediato', '/products/bolsa-guess-crossbody-camera-camel', DESKTOP, {}],
  ['product__phone-390__sold-out', '/products/bolsa-guess-shoulder-vino-brillante', PHONE, { dpr: 2, steps: [scrollTo('.product-panel__name', 110)] }],
  ['product__phone-390__recommendations', '/products/bolso-michael-kors-marilyn-medium-signature-convertible-satchel-vanilla-rosa', PHONE, { dpr: 2, steps: [scrollTo('#product-more', 300)] }],
  ['product__desktop-1440__quick-view', '/collections/coach', DESKTOP, { steps: [click('[data-product="bolso-coach-shoulder-negro-rectangular"] [data-action="quick-add"]'), click('.overlay--sheet .option-chip:has-text("Café")', 300)] }],
  ['product__desktop-1440__apartado', '/products/bolso-michael-kors-marilyn-medium-signature-convertible-satchel-vanilla-rosa', DESKTOP, { steps: [click('[data-apartado]')] }],
  ['product__phone-390__added-sheet', '/products/bolsa-juicy-couture-hobo-rosa', PHONE, { dpr: 2, steps: [click('.purchase-dock [data-add]', 1600)] }],
  ['product__desktop-1440__add-error', '/products/bolso-guess-crossbody-negro-1', DESKTOP, { steps: [demo('failNextAdd'), click('#add-inline', 1400)] }],

  ['search__phone-390__suggestions', '/search', PHONE, { dpr: 2, steps: [click('#page-search-input', 400)] }],
  ['search__phone-390__predictive', '/search', PHONE, { dpr: 2, steps: [click('#page-search-input', 100), async (page) => { await page.keyboard.type('crossbody negro', { delay: 25 }); await page.waitForTimeout(900); }] }],
  ['search__phone-390__results', '/search?q=bolsa&type=product', PHONE, { dpr: 2 }],
  ['search__tablet-768__full', '/search?q=bolsa&type=product', TABLET, { full: true }],
  ['search__desktop-1440__predictive', '/', DESKTOP, { steps: [click('#header-search-input', 100), async (page) => { await page.keyboard.type('michael', { delay: 25 }); await page.waitForTimeout(900); }] }],
  ['search__desktop-1440__results', '/search?q=bolsa&type=product', DESKTOP, { full: true }],
  ['search__desktop-1440__no-results', '/search?q=perfume+dior&type=product', DESKTOP, {}],
  ['search__desktop-1440__suggestion-error', '/', DESKTOP, { steps: [demo('searchError'), click('#header-search-input', 100), async (page) => { await page.keyboard.type('tote', { delay: 25 }); await page.waitForTimeout(900); }] }],
  ['search__desktop-1440__results-error', '/search?q=bolsa&type=product', DESKTOP, { steps: [demo('resultsError'), async (page) => { await page.reload({ waitUntil: 'networkidle' }); await page.waitForTimeout(300); }] }],

  ['cart__phone-390__top', '/cart', PHONE, { dpr: 2, cart: true }],
  ['cart__phone-375__summary', '/cart', SMALL, { dpr: 2, cart: true, steps: [scrollTo('.summary', 120)] }],
  ['cart__tablet-768__full', '/cart', TABLET, { full: true, cart: true }],
  ['cart__desktop-1440__full', '/cart', DESKTOP, { full: true, cart: true }],
  ['cart__desktop-1440__drawer', '/collections/guess', DESKTOP, { cart: true, steps: [click('[data-action="cart"]')] }],
  ['cart__desktop-1440__checkout-handoff', '/cart', DESKTOP, { cart: true, steps: [click('.summary [data-checkout]')] }],
  ['cart__phone-390__empty', '/cart', PHONE, { dpr: 2 }],

  ['menu__phone-390__open', '/', PHONE, { dpr: 2, steps: [click('[data-action="menu"]')] }],
  ['favorites__desktop-1440__items', '/collections/coach', DESKTOP, {
    steps: [
      click('[data-product="bolso-coach-station-tote-bag-negro"] [data-action="favorite"]', 200),
      click('[data-product="reloj-coach-sammy-gold-white"] [data-action="favorite"]', 200),
      async (page) => { await page.goto(page.url().replace('/collections/coach', '/pages/favoritos'), { waitUntil: 'networkidle' }); await page.waitForTimeout(300); },
    ],
  }],
  ['favorites__phone-390__empty', '/pages/favoritos', PHONE, { dpr: 2 }],
  ['mayoreo__phone-390__top', '/pages/mayoreo', PHONE, { dpr: 2 }],
  ['mayoreo__desktop-1440__full', '/pages/mayoreo', DESKTOP, { full: true }],
  ['story__desktop-1440__full', '/pages/nuestra-historia', DESKTOP, { full: true }],
  ['contact__phone-390__full', '/pages/contact', PHONE, { full: true }],
  ['account__desktop-1440__entry', '/account', DESKTOP, {}],
  ['account__desktop-1440__handoff', '/account', DESKTOP, { steps: [click('[data-account="login"]')] }],
  ['prototype-panel__desktop-1440', '/', DESKTOP, { steps: [click('.proto-strip__button')] }],
  ['not-found__tablet-768', '/collections/no-existe', TABLET, {}],
];

const only = args.only ? args.only.split(',') : null;
const jobs = JOBS.filter(([name]) => !only || only.some((prefix) => name.startsWith(prefix)));

if (!args['skip-build']) await build();
const server = await startPreview(Number(args.port ?? 4174));
const { browser } = await launch();
await mkdir(outDir, { recursive: true });
if (!only) {
  for (const file of await readdir(outDir)) if (file.endsWith('.jpg')) await unlink(path.join(outDir, file));
}

const index = [];
try {
  for (const [name, route, viewport, options = {}] of jobs) {
    const context = await browser.newContext({ viewport, deviceScaleFactor: options.dpr ?? 1 });
    if (options.cart) await seedCart(context, demoCartLines());
    const page = await context.newPage();
    const problems = [];
    page.on('pageerror', (error) => problems.push(error.message));
    page.on('console', (message) => message.type() === 'error' && problems.push(message.text()));
    await page.goto(`${server.url}${route}`, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    if (options.full || !options.steps) await scrollThrough(page);
    for (const step of options.steps ?? []) await step(page);
    await page.waitForTimeout(250);
    // Chromium's full-page capture resets horizontal scrollers to 0 while it
    // lays out the tall frame. Pin each gallery's visible slide with a
    // transform (and drop its listeners via a clone) so the capture shows the
    // slide a visitor actually sees.
    if (options.full) {
      await page.evaluate(() => {
        for (const track of document.querySelectorAll('[data-gallery]')) {
          const offset = track.scrollLeft;
          const clone = track.cloneNode(true);
          clone.style.overflow = 'hidden';
          clone.style.scrollSnapType = 'none';
          for (const slide of clone.children) slide.style.transform = `translateX(${-offset}px)`;
          track.replaceWith(clone);
        }
      });
    }
    const file = `${name}.jpg`;
    await page.screenshot({ path: path.join(outDir, file), fullPage: Boolean(options.full), type: 'jpeg', quality: 80 });
    const size = await page.evaluate(() => [document.documentElement.scrollWidth, document.documentElement.clientWidth]);
    index.push({ file, route, viewport: `${viewport.width}×${viewport.height}`, dpr: options.dpr ?? 1, full: Boolean(options.full), horizontalOverflow: size[0] > size[1], problems });
    console.log(`${problems.length ? '!' : '✓'} ${file}${problems.length ? ` ${problems.join(' | ')}` : ''}`);
    await context.close();
  }
} finally {
  await browser.close();
  server.stop();
}
if (!only) await writeFile(path.join(outDir, 'index.json'), `${JSON.stringify({ capturedAt: new Date().toISOString(), captures: index }, null, 2)}\n`);
console.log(`${index.length} captures → ${path.relative(process.cwd(), outDir)}`);
