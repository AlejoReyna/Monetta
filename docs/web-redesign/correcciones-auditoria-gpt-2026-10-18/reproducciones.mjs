// Reproduces the six defects of ../audit-gpt-2026-10-18/AUDITORIA_GPT.md (GPT-01 … GPT-06)
// against a served build and writes what it measures (JSON) and what it sees (PNG).
// The same script produced `antes/` (the build before the corrections, served from
// baseline-pre-correcciones.tgz) and `despues/` (the corrected build).
//
//   node reproducciones.mjs --out=<folder> --label=antes --url=http://127.0.0.1:4401
//   node reproducciones.mjs --out=<folder> --label=despues --port=4402      # serves design-prototype/dist
//   node reproducciones.mjs --out=<folder> --only=gpt01,gpt03
//
// --out is required. Measurements come from verify/probes.mjs: hit testing of the
// rendered stacking, pixels read from real screenshots, the accessibility tree's
// exposed headings, the geometry of the pinned bars. Safe-area insets are Chromium's
// CDP emulation, not a physical device; the 320×200, 360×225 and 640×400 viewports
// are CSS-pixel equivalents of 400 % and 200 % zoom, not the browser's own zoom.
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const prototype = fileURLToPath(new URL('../../../design-prototype/', import.meta.url));
const { launch } = await import(path.join(prototype, 'verify/browser.mjs'));
const { demoCartLines } = await import(path.join(prototype, 'verify/check-layout.mjs'));
const { seedCart } = await import(path.join(prototype, 'verify/report.mjs'));
const { startPreview } = await import(path.join(prototype, 'verify/server.mjs'));
const probes = await import(path.join(prototype, 'verify/probes.mjs'));
const { axeViolations, describeFocus, emulateSafeArea, exposedHeadings, focusProblems, horizontalEdges, keyboardTraversal, pinnedChrome, readSafeArea, settle } = probes;

const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
if (!args.out) throw new Error('--out=<folder> is required (never point it at an evidence set to keep)');
const out = path.resolve(args.out);
const only = args.only ? new Set(args.only.split(',')) : null;
await mkdir(out, { recursive: true });

const server = args.url ? { url: args.url.replace(/\/$/, ''), stop() {} } : await startPreview(Number(args.port ?? 4402));
const { browser, version } = await launch();
const PRODUCT = '/products/bolso-coach-shoulder-negro-rectangular';
const results = { label: args.label ?? 'medicion', measuredAt: new Date().toISOString(), browser: version, base: server.url, findings: {} };

async function open(viewport, { cart = false, demo = null } = {}) {
  const context = await browser.newContext({ viewport, reducedMotion: 'reduce' });
  if (cart) await seedCart(context, demoCartLines());
  if (demo) await context.addInitScript((flags) => sessionStorage.setItem('monetta-proto:v1:demo', JSON.stringify(flags)), demo);
  const page = await context.newPage();
  return { context, page };
}
const go = async (page, route) => {
  await page.goto(server.url + route, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await settle(page);
};
const shot = (page, name) => page.screenshot({ path: path.join(out, `${name}.png`) });

// ------------------------------------------------------------------ GPT-01
async function gpt01() {
  const { context, page } = await open({ width: 390, height: 844 }, { cart: true });
  const report = {};
  let first = null;
  for (const [name, route] of [
    ['collection', '/collections/guess'],
    ['product', PRODUCT],
    ['cart', '/cart'],
    ['home', '/'],
    ['search', '/search?q=bolsa&type=product'],
  ]) {
    await go(page, route);
    const stops = await keyboardTraversal(page, {
      onStop: async (stop) => {
        if (first || !focusProblems([stop]).length) return;
        first = name;
        await shot(page, 'gpt-01-foco-oculto');
      },
    });
    const problems = focusProblems(stops);
    report[name] = {
      stops: stops.length,
      footerStops: stops.filter((stop) => stop.region === 'footer').length,
      footerWithPixels: stops.filter((stop) => stop.pixels).length,
      problems: problems.length,
      examples: problems.slice(0, 6),
    };
  }
  // The audit's own case, kept verbatim: the footer links of the collection at 390×844.
  await go(page, '/collections/guess');
  await context.close();
  return { viewport: '390×844', method: 'real Tab presses from the skip link; hit test of the rendered stacking and pixels of the screenshot at the four sides of the ring and inside the box', pages: report };
}

// ------------------------------------------------------------------ GPT-02
async function gpt02() {
  const { context, page } = await open({ width: 390, height: 844 });
  await go(page, '/');
  await page.click('.dock [data-dock="catalog"]');
  await page.waitForURL(/\/collections\/all$/);
  await page.locator('[data-grid] .card__link').first().click();
  await page.waitForURL(/\/products\//);
  const original = page.url();
  const started = Date.now();
  await page.click('.site-header__back');
  await page.waitForURL(/\/collections\/all$/);
  const backAt = Date.now() - started;
  await page.goForward({ waitUntil: 'domcontentloaded' });
  const forwardAt = Date.now() - started;
  const immediate = page.url();
  await page.waitForTimeout(900);
  const after = page.url();
  await shot(page, 'gpt-02-adelante');
  await context.close();
  return { original, backMs: backAt, forwardMs: forwardAt, raceWindowOk: forwardAt < 450, urlRightAfterForward: immediate, urlAfter900ms: after, forwardPreserved: after === original };
}

// ------------------------------------------------------------------ GPT-03
async function searchState(page, state, width) {
  const routes = { empty: '/search', results: '/search?q=bolsa&type=product', noResults: '/search?q=zzzz-no-match&type=product', suggestions: '/search?q=bolsa&type=product', error: '/search?q=bolsa&type=product' };
  if (state === 'error') await page.evaluate(() => sessionStorage.setItem('monetta-proto:v1:demo', JSON.stringify({ resultsError: true })));
  await go(page, routes[state]);
  if (state === 'suggestions') {
    await page.fill('#page-search-input', 'tote');
    await page.waitForSelector('#page-search-listbox .search-option__product');
    await settle(page);
  }
  const headings = await exposedHeadings(page);
  const violations = await axeViolations(page);
  if (state === 'error' || state === 'suggestions') await shot(page, `gpt-03-busqueda-${state}-${width}`);
  if (state === 'error') await page.evaluate(() => sessionStorage.removeItem('monetta-proto:v1:demo'));
  return { exposedH1: headings.exposed.length, texts: headings.exposed.map((entry) => `${entry.tag}${entry.role ? `[role=${entry.role}]` : ''}: ${entry.text}`), hiddenH1: headings.hidden, h2: headings.h2, axe: violations.map((violation) => `${violation.id} (${violation.impact})`) };
}
async function gpt03() {
  const report = {};
  for (const width of [390, 1440]) {
    const { context, page } = await open({ width, height: width === 390 ? 844 : 900 });
    report[width] = {};
    for (const state of ['empty', 'results', 'suggestions', 'noResults', 'error']) report[width][state] = await searchState(page, state, width);
    await context.close();
  }
  return report;
}

// ------------------------------------------------------------------ GPT-04
async function gpt04() {
  const { context, page } = await open({ width: 320, height: 812 });
  await go(page, '/collections/tommy-hilfiger');
  const measure = () =>
    page.evaluate(() => {
      const bar = document.querySelector('[data-page-bar]').getBoundingClientRect();
      const element = document.activeElement.getBoundingClientRect();
      return { barHeight: bar.height, barBottom: bar.bottom, scrollPaddingTop: getComputedStyle(document.documentElement).scrollPaddingTop, focusTop: element.top, overlap: Math.max(0, bar.bottom - element.top) };
    });
  await page.evaluate(() => scrollTo(0, 3000));
  await settle(page);
  await page.locator('[data-grid] li:nth-child(4) .card__link').evaluate((element) => {
    element.focus({ preventScroll: true });
    element.scrollIntoView({ block: 'nearest', behavior: 'instant' });
  });
  await settle(page);
  const nearest = await measure();
  await shot(page, 'gpt-04-titulo-largo-nearest');

  await page.evaluate(() => scrollTo(0, 1600));
  await settle(page);
  await page.locator('[data-grid] .card__fav').first().focus();
  await page.keyboard.press('Shift+Tab');
  await settle(page);
  const keyboard = await measure();

  // Real keyboard, the case that does reproduce: the card above is half hidden under the bar and Shift+Tab brings it in.
  await page.evaluate(() => {
    const link = document.querySelector('[data-grid] li:nth-child(9) .card__link');
    const bar = document.querySelector('[data-page-bar]').getBoundingClientRect();
    scrollTo(0, scrollY + link.getBoundingClientRect().top - (bar.bottom - 30));
  });
  await settle(page);
  await page.locator('[data-grid] li:nth-child(9) .card__fav').focus({ preventScroll: true });
  await page.keyboard.press('Shift+Tab');
  await settle(page);
  const keyboardPeeking = await page.evaluate(() => {
    const bar = document.querySelector('[data-page-bar]').getBoundingClientRect();
    const element = document.activeElement.getBoundingClientRect();
    return { focused: String(document.activeElement.className).slice(0, 24), barBottom: bar.bottom, scrollPaddingTop: getComputedStyle(document.documentElement).scrollPaddingTop, focusTop: element.top, overlap: Math.max(0, bar.bottom - element.top) };
  });
  await shot(page, 'gpt-04-shift-tab-tarjeta-oculta');

  await page.evaluate(() => scrollTo(0, 3000));
  await settle(page);
  await page.locator('[data-grid] li:nth-child(10)').evaluate((element) => element.scrollIntoView({ block: 'start', behavior: 'instant' }));
  await settle(page);
  const anchorStart = await page.evaluate(() => {
    const bar = document.querySelector('[data-page-bar]').getBoundingClientRect();
    const target = document.querySelector('[data-grid] li:nth-child(10)').getBoundingClientRect();
    return { barBottom: bar.bottom, targetTop: target.top, overlap: Math.max(0, bar.bottom - target.top) };
  });
  await context.close();
  return { viewport: '320×812', nearest, keyboardShiftTab: keyboard, keyboardShiftTabPeeking: keyboardPeeking, anchorStart };
}

// ------------------------------------------------------------------ GPT-05
async function gpt05() {
  const report = {};
  for (const [width, height, equivalent] of [
    [320, 200, '1280×800 at 400 % (CSS-pixel reflow viewport, not the browser\'s zoom control)'],
    [360, 225, '1440×900 at 400 % (CSS-pixel reflow viewport, not the browser\'s zoom control)'],
    [640, 400, '1280×800 at 200 % (CSS-pixel reflow viewport, not the browser\'s zoom control)'],
    [667, 375, 'a phone on its side (an orientation, not a zoom)'],
    [812, 375, 'a phone on its side (an orientation, not a zoom)'],
    [844, 390, 'a phone on its side (an orientation, not a zoom)'],
  ]) {
    const { context, page } = await open({ width, height }, { cart: true });
    const key = `${width}×${height}`;
    report[key] = { equivalent };
    for (const [name, route] of [
      ['home', '/'],
      ['collection', '/collections/guess'],
      ['product', PRODUCT],
      ['search', '/search?q=bolsa&type=product'],
      ['cart', '/cart'],
    ]) {
      await go(page, route);
      await page.evaluate(() => scrollTo(0, Math.min(400, document.documentElement.scrollHeight - innerHeight)));
      await settle(page);
      const chrome = await pinnedChrome(page);
      report[key][name] = { free: Math.round(chrome.free), ratio: Number(chrome.ratio.toFixed(2)), pinnedTop: Math.round(chrome.pinnedTop), pinnedBottom: Math.round(chrome.pinnedBottom), pinned: [...chrome.top, ...chrome.bottom].map((entry) => `${entry.name}:${entry.position}`) };
      await shot(page, `gpt-05-${name}-${width}x${height}`);
    }
    await context.close();
  }
  return report;
}

// ------------------------------------------------------------------ GPT-06
const EDGES = {
  home: ['.site-header__menu', '.search-pill', '#rail-novedades .card', '.footer-grid'],
  collection: ['[data-page-bar] .page-bar__back', '[data-page-bar] .page-bar__actions .icon-button:last-child', '[data-grid] .card', '.collection-shortcuts .chip', '.site-header__menu', '.header-utility--cart'],
  product: ['.site-header__back', '.site-header .header-utility--cart', '.product-panel__name', '.gallery__tools .round-button', '.purchase-dock .btn', '.buy-inline .btn'],
  cart: ['[data-page-bar] .page-bar__back', '[data-page-bar] .page-bar__trailing', '.cart-line__media', '.checkout-bar .btn', '.summary .btn'],
  search: ['[data-page-bar] .page-bar__back', '.search-field', '[data-grid] .card'],
};
async function gpt06() {
  const report = {};
  for (const [width, height] of [
    [667, 375],
    [812, 375],
  ]) {
    const { context, page } = await open({ width, height }, { cart: true });
    const cdp = await emulateSafeArea(page, { left: 44, right: 44, top: 0, bottom: 21 });
    const key = `${width}×${height}`;
    report[key] = {};
    for (const [name, route] of [
      ['home', '/'],
      ['collection', '/collections/guess'],
      ['product', PRODUCT],
      ['cart', '/cart'],
      ['search', '/search?q=bolsa&type=product'],
    ]) {
      await go(page, route);
      const insets = await readSafeArea(page);
      const edges = await horizontalEdges(page, EDGES[name]);
      const violations = Object.entries(edges)
        .filter(([, edge]) => edge && (edge.left < insets.left - 0.5 || edge.right > width - insets.right + 0.5))
        .map(([selector, edge]) => `${selector}: ${edge.left.toFixed(1)}…${edge.right.toFixed(1)}`);
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
      report[key][name] = { envInsets: `${insets.left}/${insets.right}`, safeRegion: `${insets.left}…${width - insets.right}`, violations, overflow, firstCard: edges['[data-grid] .card'] ?? null };
      await shot(page, `gpt-06-${name}-${width}x${height}`);
    }
    await cdp.clear();
    await context.close();
  }
  return report;
}

const steps = [
  ['gpt01', 'GPT-01 focused controls hidden by the dock', gpt01],
  ['gpt02', 'GPT-02 arrow fallback races a valid Forward', gpt02],
  ['gpt03', 'GPT-03 search headings and axe in every state', gpt03],
  ['gpt04', 'GPT-04 reserve of a bar that grows (two-line title at 320)', gpt04],
  ['gpt05', 'GPT-05 content left between pinned bars in a short viewport', gpt05],
  ['gpt06', 'GPT-06 lateral safe-area insets', gpt06],
];
try {
  for (const [id, title, run] of steps) {
    if (only && !only.has(id)) continue;
    try {
      results.findings[id] = { title, data: await run() };
      console.log(`measured ${id}`);
    } catch (error) {
      results.findings[id] = { title, error: error.message.split('\n')[0] };
      console.log(`ERROR ${id}: ${error.message.split('\n')[0]}`);
    }
  }
} finally {
  await browser.close();
  server.stop();
}
await writeFile(path.join(out, `resultados-${results.label}.json`), `${JSON.stringify(results, null, 2)}\n`);
console.log(`Saved ${path.join(out, `resultados-${results.label}.json`)}`);
