// Reproduces RE-01 and RE-02 of docs/web-redesign/reaudit-gpt-2026-10-18/AUDITORIA_GPT.md against a
// served build and writes what it measures (JSON) and what it sees (PNG). The same script produced
// `antes/` (the tree as it stood when the reaudit was received, served from a hashed temporary copy)
// and `despues/` (the corrected build).
//
//   node reproducciones-reaudit.mjs --out=<folder> --label=antes   --url=http://127.0.0.1:4601
//   node reproducciones-reaudit.mjs --out=<folder> --label=despues --url=http://127.0.0.1:4602
//   node reproducciones-reaudit.mjs --out=<folder> --label=x --url=… --only=re01
//
// --out and --url are required. The sizes are CSS viewports (Playwright viewports), not the
// browser's own zoom control; the key presses are real (Tab, Shift+Tab); what is painted is read from
// screenshots (ring pixels, and a second capture without the fade over the navigation row).
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const prototype = fileURLToPath(new URL('../../../design-prototype/', import.meta.url));
const { launch } = await import(path.join(prototype, 'verify/browser.mjs'));
const { demoCartLines } = await import(path.join(prototype, 'verify/check-layout.mjs'));
const { seedCart } = await import(path.join(prototype, 'verify/report.mjs'));
const { focusProblems, keyboardTraversal, pinnedChrome, settle, tabSteps } = await import(path.join(prototype, 'verify/probes.mjs'));

const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
if (!args.out || !args.url) throw new Error('--out=<folder> and --url=<served build> are required (never point --out at an evidence set to keep)');
const out = path.resolve(args.out);
const only = args.only ? new Set(args.only.split(',')) : null;
await mkdir(out, { recursive: true });
const base = args.url.replace(/\/$/, '');
const { browser, version } = await launch();
const PRODUCT = '/products/bolso-coach-shoulder-negro-rectangular';
const results = { label: args.label ?? 'medicion', measuredAt: new Date().toISOString(), browser: version, base, findings: {} };

async function open(viewport, { cart = false } = {}) {
  const context = await browser.newContext({ viewport, reducedMotion: 'reduce' });
  if (cart) await seedCart(context, demoCartLines());
  const page = await context.newPage();
  return { context, page };
}
const go = async (page, route) => {
  await page.goto(base + route, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await settle(page);
};
const shot = (page, name) => page.screenshot({ path: path.join(out, `${name}.png`) });
const round = (value, digits = 2) => (typeof value === 'number' ? Math.round(value * 10 ** digits) / 10 ** digits : value);

// ------------------------------------------------------------------ RE-01
const PAGES = [
  ['home', '/'],
  ['collection', '/collections/guess'],
  ['product', PRODUCT],
  ['search', '/search?q=bolsa&type=product'],
  ['cart', '/cart'],
];

/** The columns that stick under the header on desktop, and the product gallery they are sized against. */
const columns = (page) =>
  page.evaluate(() => {
    const read = (selector) => {
      const element = document.querySelector(selector);
      if (!element || element.getClientRects().length === 0) return null;
      const style = getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return { position: style.position, top: style.top, maxHeight: style.maxHeight, height: rect.height, width: rect.width, rectTop: rect.top };
    };
    return {
      filterSidebar: read('.collection-layout--filters .filter-sidebar'),
      productPanel: read('.product-panel'),
      galleryViewer: read('.gallery__main'),
      galleryThumbs: read('.gallery__thumbs'),
      cartSummary: read('.summary'),
    };
  });

async function re01() {
  const report = { pair: {}, matrix: {}, boundary: {}, normal: {} };

  // The reaudit's pair: one pixel of width apart, 200px tall, collection scrolled 800px.
  for (const width of [1023, 1024]) {
    const { context, page } = await open({ width, height: 200 });
    await go(page, '/collections/guess');
    await page.evaluate(() => scrollTo(0, 800));
    await settle(page);
    const header = await page.evaluate(() => {
      const element = document.getElementById('site-top');
      return { position: getComputedStyle(element).position, bottom: element.getBoundingClientRect().bottom, scrollPaddingTop: getComputedStyle(document.documentElement).scrollPaddingTop };
    });
    const chrome = await pinnedChrome(page);
    report.pair[`${width}×200`] = { header: { ...header, bottom: round(header.bottom) }, free: round(chrome.free), ratio: round(chrome.ratio), pinned: [...chrome.top, ...chrome.bottom].map((entry) => `${entry.name}:${entry.position}`) };
    await shot(page, `re-01-colección-${width}x200-desplazada-800`);
    await context.close();
  }

  // Five pages × viewports below, across and above the 1024 limit and the 480 height limit.
  for (const [width, height, note] of [
    [1023, 200, 'one pixel below the width limit'],
    [1024, 200, 'the width limit'],
    [1280, 200, ''],
    [1440, 200, ''],
    [1024, 360, ''],
    [1440, 360, ''],
    [1024, 480, 'the height limit (still short)'],
    [1440, 480, 'the height limit (still short)'],
  ]) {
    const { context, page } = await open({ width, height }, { cart: true });
    const key = `${width}×${height}`;
    report.matrix[key] = { note };
    for (const [name, route] of PAGES) {
      await go(page, route);
      await page.evaluate(() => scrollTo(0, Math.min(800, document.documentElement.scrollHeight - innerHeight)));
      await settle(page);
      const chrome = await pinnedChrome(page);
      report.matrix[key][name] = {
        free: round(chrome.free),
        ratio: round(chrome.ratio),
        pinnedTop: round(chrome.pinnedTop),
        pinned: [...chrome.top, ...chrome.bottom].map((entry) => `${entry.name}:${entry.position}`),
        columns: await columns(page),
      };
      if (width === 1280 && height === 200 && ['product', 'cart', 'collection'].includes(name)) await shot(page, `re-01-${name}-${width}x${height}`);
    }
    await context.close();
  }

  // Either side of the 480px height limit, at the two widths that matter.
  for (const width of [1024, 1440]) {
    for (const height of [480, 481]) {
      const { context, page } = await open({ width, height });
      await go(page, PRODUCT);
      await page.evaluate(() => scrollTo(0, 400));
      await settle(page);
      const header = await page.evaluate(() => getComputedStyle(document.getElementById('site-top')).position);
      report.boundary[`${width}×${height}`] = { header, columns: await columns(page) };
      await context.close();
    }
  }

  // Normal windows: what must not change.
  for (const [width, height] of [
    [1024, 768],
    [1440, 900],
  ]) {
    const { context, page } = await open({ width, height }, { cart: true });
    const key = `${width}×${height}`;
    report.normal[key] = {};
    for (const [name, route] of PAGES) {
      await go(page, route);
      await page.evaluate(() => scrollTo(0, Math.min(400, document.documentElement.scrollHeight - innerHeight)));
      await settle(page);
      const chrome = await pinnedChrome(page);
      report.normal[key][name] = { pinnedTop: round(chrome.pinnedTop), pinned: [...chrome.top, ...chrome.bottom].map((entry) => `${entry.name}:${entry.position}`), columns: await columns(page) };
    }
    await context.close();
  }
  return report;
}

// ------------------------------------------------------------------ RE-02
const NAV = '.site-nav__list';

/** Tab from the page's first stop to the last category link without activating the skip link, then Shift+Tab back. */
async function walkNavigation(page, width, label) {
  const forward = await keyboardTraversal(page, {
    enterContent: false,
    pixelRegions: ['nav'],
    maskedScroller: NAV,
    stopWhen: (stop) => stop.region === 'nav' && stop.label === 'Nuestra historia',
  });
  const last = forward.at(-1);
  const scroller = await page.evaluate((selector) => {
    const list = document.querySelector(selector);
    const rect = list.getBoundingClientRect();
    const mask = getComputedStyle(list).maskImage || getComputedStyle(list).webkitMaskImage || 'none';
    const percent = /(\d+(?:\.\d+)?)%/.exec(mask)?.[1];
    return {
      scrollLeft: list.scrollLeft,
      maxScroll: list.scrollWidth - list.clientWidth,
      scrollport: { left: rect.left, right: rect.right, width: rect.width, height: rect.height },
      paddingRight: getComputedStyle(list).paddingRight,
      scrollPaddingInline: getComputedStyle(list).scrollPaddingInline,
      mask,
      fadeStartsAt: percent ? rect.left + (rect.width * Number(percent)) / 100 : null,
    };
  }, NAV);
  await shot(page, `re-02-${label}-${width}-último-enlace`);
  const summary = (stop) => ({
    label: stop.label,
    box: { left: round(stop.box.x), right: round(stop.box.x + stop.box.width), top: round(stop.box.y), height: round(stop.box.height) },
    text: { left: round(stop.textRect.left), right: round(stop.textRect.right) },
    outline: stop.ringOwner,
    ringPainted: stop.pixels ? `${stop.pixels.ringDark}/${stop.pixels.ringSampled}` : null,
    textInk: stop.pixels?.textInk ?? null,
    maskDiffering: stop.mask?.differing ?? null,
    maskMaxDelta: stop.mask?.maxDelta ?? null,
  });
  const backward = await tabSteps(page, 'Shift+Tab', 8, { pixelRegions: ['nav'], maskedScroller: NAV });
  return {
    navigationStops: forward.filter((stop) => stop.region === 'nav').length,
    last: summary(last),
    scroller,
    forward: forward.filter((stop) => stop.region === 'nav').map(summary),
    backward: backward.filter((stop) => stop.region === 'nav').map(summary),
    problemsForward: focusProblems(forward.filter((stop) => stop.region === 'nav')).map((entry) => `${entry.label}: ${entry.reasons.join(', ')}`),
    problemsBackward: focusProblems(backward.filter((stop) => stop.region === 'nav')).map((entry) => `${entry.label}: ${entry.reasons.join(', ')}`),
  };
}

async function re02() {
  const report = {};
  for (const [width, height] of [
    [768, 1024],
    [812, 1024],
    [1023, 768],
    [1024, 768],
    [1440, 900],
  ]) {
    const { context, page } = await open({ width, height });
    await go(page, '/');
    report[`${width}×${height}`] = await walkNavigation(page, width, 'inicio');
    await context.close();
  }
  return report;
}

const steps = [
  ['re01', 'RE-01 pinned header and sticky columns in short windows from 1024px up', re01],
  ['re02', 'RE-02 the last category link of the tablet navigation under the fade, keyboard forward and back', re02],
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
}
await writeFile(path.join(out, `resultados-${results.label}.json`), `${JSON.stringify(results, null, 2)}\n`);
console.log(`Saved ${path.join(out, `resultados-${results.label}.json`)}`);
