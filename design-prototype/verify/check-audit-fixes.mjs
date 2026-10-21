// D11 — the six defects the independent audit of 2026-10-18 left open (GPT-01 … GPT-06 in
// docs/web-redesign/audit-gpt-2026-10-18/AUDITORIA_GPT.md) and the rail focus defect found
// while reproducing them (A1). Every check measures what the viewer gets with a real
// browser — Tab presses and the stacking that is painted, the history stack, the
// accessibility tree and axe, the geometry of the pinned bars, the safe region — and each
// was written to fail on the build that carried the defect (see
// docs/web-redesign/correcciones-auditoria-gpt-2026-10-18/logs/).
//
// Not covered here, on purpose: the 320×200, 360×225 and 640×400 viewports are CSS-pixel
// equivalents of 1280×800 and 1440×900 at 400 % and 1280×800 at 200 % zoom, not the
// browser's own zoom control; the safe-area insets are Chromium's emulation
// (Emulation.setSafeAreaInsetsOverride), not a physical device.
//
//   node verify/check-audit-fixes.mjs --url=http://127.0.0.1:4401     # any served build
//   npm run verify -- --only=fixes
import { pathToFileURL } from 'node:url';
import { launch } from './browser.mjs';
import { demoCartLines } from './check-layout.mjs';
import { axeViolations, emulateSafeArea, exposedHeadings, focusProblems, keyboardTraversal, pinnedChrome, readSafeArea, settle } from './probes.mjs';
import { assert, catalog, createReport, seedCart } from './report.mjs';

const PRODUCT = '/products/bolso-coach-shoulder-negro-rectangular';
const DEMO_KEY = 'monetta-proto:v1:demo';
const px = Number.parseFloat;
/** A computed length, where `auto` (nothing reserved) is zero. */
const length = (value) => (Number.isNaN(px(value)) ? 0 : px(value));
const near = (actual, expected, tolerance, label) => assert(Math.abs(actual - expected) <= tolerance, `${label}: ${actual} (expected ${expected} ± ${tolerance})`);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Fails with every message at once, so one broken page does not hide the others. */
function assertNone(problems, heading) {
  assert(problems.length === 0, `${heading}: ${problems.slice(0, 6).join(' · ')}${problems.length > 6 ? ` (+${problems.length - 6})` : ''}`);
}

export async function checkAuditFixes({ browser, url, report }) {
  async function open(label, viewport, { cart = false, demo = null, reducedMotion = 'reduce', insets = null } = {}) {
    const context = await browser.newContext({ viewport, reducedMotion });
    if (cart) await seedCart(context, demoCartLines());
    if (demo) await context.addInitScript(([key, flags]) => sessionStorage.setItem(key, JSON.stringify(flags)), [DEMO_KEY, demo]);
    const page = await context.newPage();
    report.trackPage(page, label);
    const safeArea = insets ? await emulateSafeArea(page, insets) : null;
    return { context, page, safeArea };
  }
  const go = async (page, route) => {
    await page.goto(`${url}${route}`, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    await settle(page);
  };
  const rootStyle = (page, name) => page.evaluate((property) => getComputedStyle(document.documentElement).getPropertyValue(property).trim(), name);
  const scrollPadding = (page) => page.evaluate(() => ({ top: getComputedStyle(document.documentElement).scrollPaddingTop, bottom: getComputedStyle(document.documentElement).scrollPaddingBottom }));

  // ============================================================= GPT-01 · focus behind the dock
  {
    const { context, page } = await open('gpt01', { width: 390, height: 844 }, { cart: true });

    await report.step('D11', 'GPT-01 scroll-padding-bottom is the real height of the pinned bar of each page plus 16px (dock, purchase bar, checkout bar)', async () => {
      const seen = [];
      for (const [name, route, selector] of [
        ['collection', '/collections/guess', '.dock'],
        ['product', PRODUCT, '.purchase-dock'],
        ['cart', '/cart', '.checkout-bar'],
      ]) {
        await go(page, route);
        const bar = await page.$eval(selector, (element) => element.getBoundingClientRect().height);
        const { bottom } = await scrollPadding(page);
        near(length(bottom), bar + 16, 0.6, `${name} scroll-padding-bottom vs ${selector} (${bar.toFixed(2)}px) + 16`);
        seen.push(`${name} ${bar.toFixed(0)}`);
      }
      return seen.join(' · ');
    });

    await report.step('D11', 'GPT-01 the reserve grows with the home indicator and returns when it goes (+34px, then back)', async () => {
      await go(page, '/collections/guess');
      const base = length((await scrollPadding(page)).bottom);
      const cut = await emulateSafeArea(page, { top: 0, bottom: 34, left: 0, right: 0 });
      await settle(page);
      await sleep(100);
      const raised = length((await scrollPadding(page)).bottom);
      await cut.clear();
      await settle(page);
      await sleep(100);
      const restored = length((await scrollPadding(page)).bottom);
      near(raised, base + 34, 0.6, 'with a 34px home indicator');
      near(restored, base, 0.6, 'after clearing it');
      return `${base} → ${raised} → ${restored}`;
    });

    const traversals = {};
    for (const [name, route] of [
      ['collection', '/collections/guess'],
      ['product', PRODUCT],
      ['cart', '/cart'],
      ['home', '/'],
      ['search', '/search?q=bolsa&type=product'],
    ]) {
      await report.step('D11', `GPT-01 Tab traversal @ 390×844 · ${name}: no focused control, text or ring is hidden under the pinned bars`, async () => {
        await go(page, route);
        const stops = await keyboardTraversal(page);
        traversals[name] = stops;
        assert(stops.length > 10, `only ${stops.length} stops`);
        assertNone(focusProblems(stops).map((entry) => `${entry.label} (${entry.region}, y ${entry.y}): ${entry.reasons.join(', ')}`), 'hidden stops');
        return `${stops.length} stops, ${stops.filter((stop) => stop.pixels).length} footer stops with pixels read`;
      });
    }

    await report.step('D11', 'GPT-01 the audit\'s own footer links (Novedades, Envíos, Mi cuenta) show their text and a painted ring above the dock', async () => {
      const stops = traversals.collection ?? [];
      const dockTop = await page.evaluate(() => document.querySelector('.dock__bar').getBoundingClientRect().top);
      const seen = [];
      for (const label of ['Novedades', 'Envíos', 'Mi cuenta']) {
        const stop = stops.find((entry) => entry.region === 'footer' && entry.label === label);
        assert(stop, `no footer stop for ${label}`);
        assert(!stop.centerCovered && stop.ringCovered.length === 0, `${label} is covered (${stop.centerHit}; ring ${stop.ringCovered.join('/')})`);
        assert(stop.pixels && stop.pixels.ringDark === stop.pixels.ringSampled, `${label}: ring painted on ${stop.pixels?.ringDark}/${stop.pixels?.ringSampled} sides`);
        assert(stop.pixels.textInk >= 12, `${label}: ${stop.pixels.textInk} text pixels`);
        assert(stop.box.bottom + 5 <= dockTop + 0.5, `${label} ends at ${stop.box.bottom.toFixed(1)}, ring included it reaches the dock at ${dockTop.toFixed(1)}`);
        seen.push(`${label} bottom ${stop.box.bottom.toFixed(0)}`);
      }
      return `dock top ${dockTop.toFixed(0)} · ${seen.join(' · ')}`;
    });
    await context.close();

    for (const [width, height] of [
      [375, 812],
      [440, 956],
      [320, 568],
    ]) {
      await report.step('D11', `GPT-01 Tab traversal @ ${width}×${height} · collection, product and bag: nothing hidden under the pinned bars`, async () => {
        const { context: other, page: tab } = await open(`gpt01-${width}`, { width, height }, { cart: true });
        const problems = [];
        for (const [name, route] of [
          ['collection', '/collections/guess'],
          ['product', PRODUCT],
          ['cart', '/cart'],
        ]) {
          await go(tab, route);
          const stops = await keyboardTraversal(tab);
          problems.push(...focusProblems(stops).map((entry) => `${name}: ${entry.label} (${entry.reasons.join(', ')})`));
        }
        await other.close();
        assertNone(problems, 'hidden stops');
      });
    }
    await report.step('D11', 'GPT-01 Tab traversal @ 768×1024 · bag: the checkout bar still pins below 1024px and hides nothing', async () => {
      const { context: other, page: tab } = await open('gpt01-768', { width: 768, height: 1024 }, { cart: true });
      await go(tab, '/cart');
      const bar = await tab.$eval('.checkout-bar', (element) => element.getBoundingClientRect().height);
      near(length((await scrollPadding(tab)).bottom), bar + 16, 0.6, 'tablet scroll-padding-bottom vs the checkout bar + 16');
      const stops = await keyboardTraversal(tab);
      await other.close();
      assertNone(focusProblems(stops).map((entry) => `${entry.label} (${entry.region}): ${entry.reasons.join(', ')}`), 'hidden stops');
    });
  }

  // ============================================================= A1 · horizontal scrollers and the keyboard
  for (const [width, height] of [
    [390, 844],
    [320, 568],
  ]) {
    await report.step('D11', `A1 Tab through the rails, chip rows and thumbnails @ ${width}px (Home, collection, product): every focused item is fully on screen`, async () => {
      const { context, page } = await open(`a1-${width}`, { width, height });
      const clipped = [];
      const seen = [];
      const counts = [];
      for (const [name, route, minimum] of [
        ['home', '/', 10],
        ['collection', '/collections/guess', 3],
        ['product', PRODUCT, 6],
      ]) {
        await go(page, route);
        await page.keyboard.press('Tab');
        await page.keyboard.press('Enter');
        let inScroller = 0;
        for (let index = 0; index < 140; index += 1) {
          await page.keyboard.press('Tab');
          const stop = await page.evaluate(async () => {
            const frame = () => new Promise((resolve) => requestAnimationFrame(resolve));
            let previous = '';
            let steady = 0;
            for (let step = 0; step < 40 && steady < 3; step += 1) {
              await frame();
              const rect = document.activeElement.getBoundingClientRect();
              const stamp = `${rect.left.toFixed(1)}|${rect.top.toFixed(1)}|${Math.round(scrollY)}`;
              steady = stamp === previous ? steady + 1 : 0;
              previous = stamp;
            }
            const element = document.activeElement;
            const label = (element.getAttribute('aria-label') || element.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 40);
            // A focusable scroller itself (the review rail) is not an item inside one.
            const scroller = element.parentElement?.closest('.rail__track, .chips--scroll, .gallery__thumbs') ?? null;
            if (!scroller) return { scroller: false, label };
            let item = element;
            while (item.parentElement !== scroller) item = item.parentElement;
            const rect = item.getBoundingClientRect();
            return { scroller: true, label, left: rect.left, right: rect.right, view: innerWidth };
          });
          if (stop.label === 'Saltar al contenido') break;
          if (!stop.scroller) continue;
          inScroller += 1;
          if (stop.left < -0.5 || stop.right > stop.view + 0.5) clipped.push(`${name}: ${stop.label} ${stop.left.toFixed(0)}…${stop.right.toFixed(0)} of ${stop.view}`);
        }
        counts.push([name, inScroller, minimum]);
        seen.push(`${name} ${inScroller}`);
      }
      await context.close();
      assertNone(clipped, 'items left half outside the screen');
      assertNone(counts.filter(([, found, minimum]) => found < minimum).map(([name, found, minimum]) => `${name}: ${found} stops inside scrollers, expected at least ${minimum}`), 'the traversal did not reach the scrollers');
      return `stops inside scrollers: ${seen.join(' · ')}`;
    });
  }

  // ============================================================= GPT-02 · the arrow's fallback
  {
    const visit = async (label) => {
      const session = await open(label, { width: 390, height: 844 });
      const { page } = session;
      await go(page, '/');
      await page.click('.dock [data-dock="catalog"]');
      await page.waitForURL(/\/collections\/all$/);
      await page.locator('[data-grid] .card__link').first().click();
      await page.waitForURL(/\/products\//);
      return { ...session, product: page.url(), list: `${url}/collections/all` };
    };
    const arrow = (page) => page.click('[data-action="back"]:visible');

    await report.step('D11', 'GPT-02 Forward right after the arrow keeps the restored product (0, 150, 450 and 700 ms later)', async () => {
      const failures = [];
      for (const delay of [0, 150, 450, 700]) {
        const { context, page, product, list } = await visit(`gpt02-forward-${delay}`);
        await arrow(page);
        await page.waitForURL(list);
        await sleep(delay);
        await page.goForward({ waitUntil: 'commit' });
        await sleep(1000);
        if (page.url() !== product) failures.push(`after ${delay} ms Forward ended on ${page.url().replace(url, '')}`);
        await context.close();
      }
      assertNone(failures, 'the fallback took the user out of the restored product');
    });

    await report.step('D11', 'GPT-02 a product opened right after the arrow is not replaced by the fallback, even at the same address', async () => {
      const { context, page, product, list } = await visit('gpt02-link');
      await arrow(page);
      await page.waitForURL(list);
      await sleep(100);
      await page.locator('[data-grid] .card__link').first().click();
      await page.waitForURL(/\/products\//);
      assert(page.url() === product, `reopened ${page.url()} instead of ${product}`);
      await sleep(1000);
      assert(page.url() === product, `after 1 s the page is at ${page.url().replace(url, '')}`);
      await context.close();
    });

    await report.step('D11', 'GPT-02 the arrow still works after Forward and keeps working', async () => {
      const { context, page, product, list } = await visit('gpt02-again');
      await arrow(page);
      await page.waitForURL(list);
      await page.goForward({ waitUntil: 'commit' });
      await sleep(150);
      assert(page.url() === product, `Forward left ${page.url()}`);
      await arrow(page);
      await page.waitForURL(list);
      await sleep(1000);
      assert(page.url() === list, `arrow ended on ${page.url().replace(url, '')}`);
      await context.close();
    });

    await report.step('D11', 'GPT-02 the arrow leaves a filtered screen in one step; Forward then restores the filtered list and the fallback stays quiet', async () => {
      const { page, context } = await open('gpt02-filters', { width: 390, height: 844 });
      await go(page, '/');
      await page.click('.dock [data-dock="catalog"]');
      await page.waitForURL(/\/collections\/all$/);
      await page.evaluate(() => {
        const select = document.querySelector('[data-sort-select]');
        select.value = 'price-ascending';
        select.dispatchEvent(new Event('change', { bubbles: true }));
      });
      await page.waitForURL(/sort_by=price-ascending/);
      const filtered = page.url();
      await arrow(page);
      await page.waitForURL(`${url}/`);
      // Forward steps one entry at a time: the catalog, then its sorted entry — the address the arrow was clicked on.
      await page.goForward({ waitUntil: 'commit' });
      await page.goForward({ waitUntil: 'commit' });
      await sleep(1000);
      assert(page.url() === filtered, `Forward ended on ${page.url().replace(url, '')}`);
      // The browser's own Back still undoes the sort instead of leaving the screen.
      await page.goBack({ waitUntil: 'commit' });
      await sleep(150);
      assert(/\/collections\/all$/.test(page.url()), `Back from the sort went to ${page.url().replace(url, '')}`);
      await context.close();
    });

    await report.step('D11', 'GPT-02 a visit that began on the product: the arrow goes straight to its parent and Back returns to the product', async () => {
      const { page, context } = await open('gpt02-direct', { width: 390, height: 844 });
      await go(page, PRODUCT);
      const product = page.url();
      const started = Date.now();
      await arrow(page);
      await page.waitForURL(/\/collections\//, { timeout: 400 });
      assert(Date.now() - started < 400, 'the parent took longer than the fallback window');
      await sleep(700);
      assert(/\/collections\//.test(page.url()), `ended on ${page.url().replace(url, '')}`);
      await page.goBack({ waitUntil: 'commit' });
      await sleep(150);
      assert(page.url() === product, `Back returned to ${page.url().replace(url, '')}`);
      await context.close();
    });

    await report.step('D11', 'GPT-02 after a reload the arrow still leaves the screen and stays gone', async () => {
      const { page, context } = await open('gpt02-reload', { width: 390, height: 844 });
      await go(page, '/');
      await page.click('.dock [data-dock="catalog"]');
      await page.waitForURL(/\/collections\/all$/);
      await page.evaluate(() => {
        const select = document.querySelector('[data-sort-select]');
        select.value = 'price-ascending';
        select.dispatchEvent(new Event('change', { bubbles: true }));
      });
      await page.waitForURL(/sort_by=price-ascending/);
      await page.reload({ waitUntil: 'networkidle' });
      await settle(page);
      await arrow(page);
      await page.waitForURL(`${url}/`, { timeout: 3000 });
      await sleep(1000);
      assert(page.url() === `${url}/`, `ended on ${page.url().replace(url, '')}`);
      await context.close();
    });

    await report.step('D11', 'GPT-02 when a restored session lost the entries before this one, the arrow still reaches its parent after the fallback window', async () => {
      const { page, context } = await open('gpt02-lost', { width: 390, height: 844 });
      await go(page, PRODUCT);
      // Counters say "four screens back", the browser has none of them.
      await page.evaluate(() => history.replaceState({ scrollY: 0, idx: 6, entry: 3 }, '', location.href));
      await arrow(page);
      await sleep(250);
      assert(/\/products\//.test(page.url()), 'the arrow left before the fallback window');
      await page.waitForURL(/\/collections\//, { timeout: 1500 });
      await context.close();
    });

    await report.step('D11', 'GPT-02 the browser\'s own Back and Forward, paused for 0, 700 and 1500 ms between them, keep the history intact', async () => {
      const failures = [];
      for (const delay of [0, 700, 1500]) {
        const { context, page, product, list } = await visit(`gpt02-paused-${delay}`);
        await page.goBack({ waitUntil: 'commit' });
        await sleep(delay);
        if (page.url() !== list) failures.push(`${delay} ms: Back went to ${page.url().replace(url, '')}`);
        await page.goForward({ waitUntil: 'commit' });
        await sleep(900);
        if (page.url() !== product) failures.push(`${delay} ms: Forward ended on ${page.url().replace(url, '')}`);
        await context.close();
      }
      assertNone(failures, 'history');
    });
  }

  // ============================================================= GPT-03 · search headings
  for (const [width, height] of [
    [390, 844],
    [1440, 900],
  ]) {
    await report.step('D11', `GPT-03 search @ ${width}px: one exposed h1 and no axe violation in the empty, suggestions, results, no-results and error states`, async () => {
      const problems = [];
      const seen = [];
      for (const state of ['empty', 'suggestions', 'results', 'noResults', 'error']) {
        const { context, page } = await open(`gpt03-${width}-${state}`, { width, height }, { demo: state === 'error' ? { resultsError: true } : null });
        await go(page, { empty: '/search', suggestions: '/search?q=bolsa&type=product', results: '/search?q=bolsa&type=product', noResults: '/search?q=zzzz-no-match&type=product', error: '/search?q=bolsa&type=product' }[state]);
        if (state === 'suggestions') {
          await page.fill('#page-search-input', 'tote');
          await page.waitForSelector('#page-search-listbox .search-option__product');
          await settle(page);
        }
        const headings = await exposedHeadings(page);
        const violations = await axeViolations(page);
        const texts = headings.exposed.map((entry) => `${entry.tag}${entry.role ? `[role]` : ''} “${entry.text}”`);
        seen.push(`${state}: ${texts.join(' + ') || 'none'}`);
        if (headings.exposed.length !== 1) problems.push(`${state}: ${headings.exposed.length} exposed h1 (${texts.join(', ')})`);
        for (const violation of violations) problems.push(`${state}: axe ${violation.id} (${violation.impact}) ${violation.sample}`);
        const expected = { empty: /^Buscar$/, suggestions: /^Buscar$/, results: /^Resultados para “bolsa”$/, noResults: /^Resultados para “zzzz-no-match”$/, error: /^Buscar$/ }[state];
        if (headings.exposed[0] && !expected.test(headings.exposed[0].text)) problems.push(`${state}: heading “${headings.exposed[0].text}” does not name the screen`);
        await context.close();
      }
      assertNone(problems, 'headings');
      return seen.join(' · ');
    });
  }

  await report.step('D11', 'GPT-03 results → another query → back to the query keeps one h1 each time, and the heading role goes with the suggestions', async () => {
    const problems = [];
    for (const [width, height] of [
      [390, 844],
      [1440, 900],
    ]) {
      const { context, page } = await open(`gpt03-flow-${width}`, { width, height });
      await go(page, '/search?q=bolsa&type=product');
      const fieldTop = () => page.$eval('.search-page__field', (element) => element.getBoundingClientRect().top);
      const shape = async (label) => {
        const headings = await exposedHeadings(page);
        if (headings.exposed.length !== 1) problems.push(`${width} ${label}: ${headings.exposed.length} exposed h1`);
        return headings.exposed[0];
      };
      const before = await fieldTop();
      const first = await shape('results');
      if (first?.role) problems.push(`${width} results: the bar title already has role ${first.role}`);
      await page.fill('#page-search-input', 'tote');
      await page.waitForSelector('#page-search-listbox .search-option__product');
      await settle(page);
      const suggestions = await shape('suggestions');
      if (suggestions?.role !== 'heading') problems.push(`${width} suggestions: the exposed h1 is ${suggestions?.tag} without the heading role`);
      if (Math.abs((await fieldTop()) - before) > 0.5) problems.push(`${width}: the field moved ${(await fieldTop()) - before}px when suggestions opened`);
      await page.fill('#page-search-input', 'bolsa');
      await page.waitForSelector('[data-search-results]:not([hidden])', { timeout: 3000 });
      await settle(page);
      const restored = await shape('back to the query');
      if (restored?.role || !/^Resultados para/.test(restored?.text ?? '')) problems.push(`${width} back to the query: exposed “${restored?.text}” (${restored?.role})`);
      await context.close();
    }
    assertNone(problems, 'heading flow');
  });

  // ============================================================= GPT-04 · a reserve that grows
  {
    const barGeometry = (page) =>
      page.evaluate(() => {
        const bar = document.querySelector('[data-page-bar]')?.getBoundingClientRect();
        const top = document.getElementById('site-top').getBoundingClientRect();
        return { bar: bar ? { height: bar.height, bottom: bar.bottom } : null, siteTop: { height: top.height, bottom: top.bottom }, reserve: getComputedStyle(document.documentElement).scrollPaddingTop };
      });
    /** The reserve must equal the lowest pinned edge plus the 16px of air, within a pixel. */
    const reserveMatches = async (page, label) => {
      const geometry = await barGeometry(page);
      const edge = Math.max(geometry.siteTop.bottom, geometry.bar?.bottom ?? 0);
      near(length(geometry.reserve), edge + 16, 0.6, `${label}: scroll-padding-top vs pinned edge ${edge.toFixed(2)}`);
      return { edge, geometry };
    };
    const settleReserve = async (page, label, timeout = 1500) => {
      const started = Date.now();
      for (;;) {
        try {
          return await reserveMatches(page, label);
        } catch (error) {
          if (Date.now() - started > timeout) throw error;
          await sleep(50);
        }
      }
    };

    await report.step('D11', 'GPT-04 320px · two-line title: the bar is taller than its minimum and the reserve covers it (nearest, Shift+Tab and scrollIntoView start)', async () => {
      const { context, page } = await open('gpt04-long', { width: 320, height: 812 });
      await go(page, '/collections/tommy-hilfiger');
      const { geometry } = await reserveMatches(page, 'loaded');
      assert(geometry.bar.height > 90, `the title did not wrap: the bar is ${geometry.bar.height.toFixed(1)}px`);
      const overlap = (selector) =>
        page.evaluate((target) => {
          const bar = document.querySelector('[data-page-bar]').getBoundingClientRect();
          const element = document.querySelector(target).getBoundingClientRect();
          return Math.max(0, bar.bottom - element.top);
        }, selector);

      // 1 — scrollIntoView nearest, from below.
      await page.evaluate(() => scrollTo(0, 3000));
      await settle(page);
      await page.locator('[data-grid] li:nth-child(4) .card__link').evaluate((element) => {
        element.focus({ preventScroll: true });
        element.scrollIntoView({ block: 'nearest', behavior: 'instant' });
      });
      await settle(page);
      assert((await overlap('[data-grid] li:nth-child(4) .card__link')) < 0.5, 'nearest: the link is partly under the bar');

      // 2 — real keyboard: the card above is half hidden under the bar, Shift+Tab brings it in.
      await page.evaluate(() => {
        const link = document.querySelector('[data-grid] li:nth-child(9) .card__link');
        const bar = document.querySelector('[data-page-bar]').getBoundingClientRect();
        scrollTo(0, scrollY + link.getBoundingClientRect().top - (bar.bottom - 30));
      });
      await settle(page);
      await page.locator('[data-grid] li:nth-child(9) .card__fav').focus({ preventScroll: true });
      await page.keyboard.press('Shift+Tab');
      await settle(page);
      const focused = await page.evaluate(() => document.activeElement.className);
      assert(String(focused).includes('card__link'), `Shift+Tab landed on ${focused}`);
      assert((await overlap('[data-grid] li:nth-child(9) .card__link')) < 0.5, 'Shift+Tab: the focused link is partly under the bar');

      // 3 — anchors: the target starts below the bar.
      await page.evaluate(() => scrollTo(0, 3000));
      await settle(page);
      await page.locator('[data-grid] li:nth-child(10)').evaluate((element) => element.scrollIntoView({ block: 'start', behavior: 'instant' }));
      await settle(page);
      assert((await overlap('[data-grid] li:nth-child(10)')) < 0.5, 'scrollIntoView start: the target starts under the bar');
      await context.close();
      return `bar ${geometry.bar.height.toFixed(2)}px, reserve ${geometry.reserve}`;
    });

    await report.step('D11', 'GPT-04 375px · one-line title keeps the 120px reserve of the 76px bar (no regression)', async () => {
      const { context, page } = await open('gpt04-short', { width: 375, height: 812 });
      await go(page, '/collections/guess');
      const { geometry } = await reserveMatches(page, 'one-line title');
      near(geometry.bar.height, 76, 0.6, 'bar height');
      near(px(geometry.reserve), 120, 0.6, 'reserve');
      await context.close();
    });

    await report.step('D11', 'GPT-04 the reserve follows the bar when the text gets larger and when it shrinks back', async () => {
      const { context, page } = await open('gpt04-size', { width: 390, height: 844 });
      await go(page, '/collections/guess');
      const before = await reserveMatches(page, 'before');
      const titleSize = (size) => page.waitForFunction((expected) => getComputedStyle(document.querySelector('.page-bar__title')).fontSize === expected, size);
      const larger = await page.addStyleTag({ content: '.page-bar__title { font-size: 72px !important; }' });
      await titleSize('72px'); // the stylesheet applies a moment after addStyleTag resolves
      const grown = await settleReserve(page, 'larger text');
      assert(grown.geometry.bar.height > before.geometry.bar.height + 10, `the bar did not grow (${before.geometry.bar.height} → ${grown.geometry.bar.height})`);
      await larger.evaluate((element) => element.remove());
      await titleSize('28px');
      const shrunk = await settleReserve(page, 'text back to normal');
      near(shrunk.geometry.bar.height, before.geometry.bar.height, 0.6, 'bar height after reverting');
      await context.close();
      return `bar ${before.geometry.bar.height.toFixed(0)} → ${grown.geometry.bar.height.toFixed(0)} → ${shrunk.geometry.bar.height.toFixed(0)}`;
    });

    await report.step('D11', 'GPT-04 the reserve follows a viewport resize (375 → 320 wraps the title, 320 → 375 restores it)', async () => {
      const { context, page } = await open('gpt04-resize', { width: 375, height: 812 });
      await go(page, '/collections/tommy-hilfiger');
      const wide = await reserveMatches(page, '375');
      await page.setViewportSize({ width: 320, height: 812 });
      const narrow = await settleReserve(page, '320');
      assert(narrow.geometry.bar.height > wide.geometry.bar.height + 10, `no wrap at 320 (${wide.geometry.bar.height} → ${narrow.geometry.bar.height})`);
      await page.setViewportSize({ width: 375, height: 812 });
      const again = await settleReserve(page, '375 again');
      near(again.geometry.bar.height, wide.geometry.bar.height, 0.6, 'bar height after returning');
      await context.close();
      return `bar ${wide.geometry.bar.height.toFixed(0)} → ${narrow.geometry.bar.height.toFixed(0)} → ${again.geometry.bar.height.toFixed(0)}`;
    });

    await report.step('D11', 'GPT-04 a late web font changes the bar and the reserve tracks it (Playfair held back for 1.5 s)', async () => {
      const { context, page } = await open('gpt04-font', { width: 320, height: 812 });
      await page.route('**/fonts/playfair/*.woff2', async (route) => {
        await sleep(1500);
        await route.continue();
      });
      await page.goto(`${url}/collections/tommy-hilfiger`, { waitUntil: 'domcontentloaded' });
      await page.waitForSelector('[data-page-bar]');
      const early = await reserveMatches(page, 'with the fallback font');
      await page.evaluate(() => document.fonts.ready);
      await sleep(200);
      const late = await settleReserve(page, 'with Playfair');
      await context.close();
      return `bar ${early.geometry.bar.height.toFixed(2)} → ${late.geometry.bar.height.toFixed(2)}`;
    });

    await report.step('D11', 'GPT-04 navigating between pages swaps the reserve: bar page → product header → back to the bar page', async () => {
      const { context, page } = await open('gpt04-navigate', { width: 320, height: 812 });
      await go(page, '/collections/tommy-hilfiger');
      const bar = await reserveMatches(page, 'collection');
      await page.locator('[data-grid] .card__link').first().click();
      await page.waitForURL(/\/products\//);
      await settle(page);
      const product = await settleReserve(page, 'product');
      assert(product.geometry.bar === null, 'the product page still has a page bar');
      assert(px(product.geometry.reserve) < px(bar.geometry.reserve) - 20, `product ${product.geometry.reserve} vs collection ${bar.geometry.reserve}`);
      await page.click('[data-action="back"]:visible');
      await page.waitForURL(/\/collections\/tommy-hilfiger/);
      await settle(page);
      const back = await settleReserve(page, 'collection again');
      near(px(back.geometry.reserve), px(bar.geometry.reserve), 0.6, 'reserve after returning');
      await context.close();
      return `${bar.geometry.reserve} → ${product.geometry.reserve} → ${back.geometry.reserve}`;
    });

    for (const [width, height] of [
      [390, 844],
      [1440, 900],
    ]) {
      await report.step('D11', `GPT-04 @ ${width}px the "Ver catálogos" anchor lands below the pinned header (${width > 1000 ? 'strip, header and category row' : 'strip and header'})`, async () => {
        const { context, page } = await open(`gpt04-anchor-${width}`, { width, height });
        await go(page, '/pages/mayoreo');
        await page.locator('a[href="#catalogos"]').first().click();
        await sleep(300);
        await settle(page);
        const result = await page.evaluate(() => {
          const target = document.getElementById('catalogos').getBoundingClientRect();
          const top = document.getElementById('site-top').getBoundingClientRect();
          return { targetTop: target.top, headerBottom: top.bottom, scrollY: scrollY };
        });
        assert(result.scrollY > 100, 'the anchor did not scroll the page');
        assert(result.targetTop >= result.headerBottom - 0.5, `the section starts at ${result.targetTop.toFixed(1)} under a header that ends at ${result.headerBottom.toFixed(1)}`);
        await context.close();
        return `target ${result.targetTop.toFixed(0)} · header bottom ${result.headerBottom.toFixed(0)}`;
      });
    }
  }

  // ============================================================= GPT-05 · short viewports
  const SHORT = [
    [320, 200, '1280×800 at 400 %'],
    [360, 225, '1440×900 at 400 %'],
    [640, 400, '1280×800 at 200 %'],
  ];
  const MAIN_PAGES = [
    ['home', '/'],
    ['collection', '/collections/guess'],
    ['product', PRODUCT],
    ['search', '/search?q=bolsa&type=product'],
    ['cart', '/cart'],
  ];
  // Real orientations rather than zoom equivalents: a phone on its side keeps the pinned header too large a share.
  const ON_ITS_SIDE = [
    [667, 375],
    [812, 375],
    [844, 390],
  ];
  const GEOMETRY = [
    ...SHORT.map(([width, height, equivalent]) => [width, height, `reflow-equivalent ${width}×${height} (${equivalent}, not the browser zoom)`]),
    ...ON_ITS_SIDE.map(([width, height]) => [width, height, `a phone on its side ${width}×${height} (an orientation, not a zoom)`]),
  ];
  for (const [width, height, label] of GEOMETRY) {
    await report.step('D11', `GPT-05 ${label}: five pages leave the viewport to the content`, async () => {
      const { context, page } = await open(`gpt05-${width}`, { width, height }, { cart: true });
      const problems = [];
      const seen = [];
      for (const [name, route] of MAIN_PAGES) {
        await go(page, route);
        for (const where of ['top', 'scrolled']) {
          await page.evaluate((position) => scrollTo(0, position === 'top' ? 0 : Math.min(400, document.documentElement.scrollHeight - innerHeight)), where);
          await settle(page);
          const chrome = await pinnedChrome(page);
          // Content is free on a scrolled page; at the very top the strip and bar are simply the first things on the page.
          if (where === 'scrolled' && chrome.ratio < 0.9) problems.push(`${name} scrolled: ${Math.round(chrome.free)}px of ${height} free (${[...chrome.top, ...chrome.bottom].map((entry) => entry.name).join('+')})`);
          if (where === 'scrolled') seen.push(`${name} ${Math.round(chrome.free)}`);
        }
        const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
        if (overflow > 0) problems.push(`${name}: ${overflow}px of horizontal overflow`);
      }
      await context.close();
      assertNone(problems, 'content squeezed between pinned bars');
      return `free px: ${seen.join(' · ')}`;
    });
  }

  for (const [width, height] of SHORT) {
    await report.step('D11', `GPT-05 ${width}×${height}: the product's add button, the bag's checkout, the filters, the search and the dock all work`, async () => {
      const failures = [];
      const reachable = async (page, selector, label) => {
        const locator = page.locator(selector).first();
        await locator.scrollIntoViewIfNeeded({ timeout: 4000 });
        await settle(page);
        const hit = await locator.evaluate((element) => {
          const rect = element.getBoundingClientRect();
          const target = document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
          return { onScreen: rect.top >= 0 && rect.bottom <= innerHeight && rect.left >= 0 && rect.right <= innerWidth, hit: Boolean(target) && (element === target || element.contains(target)) };
        });
        if (!hit.onScreen) failures.push(`${label}: not fully on screen`);
        if (!hit.hit) failures.push(`${label}: covered by another element`);
        return locator;
      };

      // Product: the inline button replaces the purchase bar.
      {
        const { context, page } = await open(`gpt05-product-${width}`, { width, height });
        page.setDefaultTimeout(6000);
        await go(page, PRODUCT);
        const button = await reachable(page, '[data-add]:visible', 'product add button');
        const before = await page.evaluate(() => JSON.parse(localStorage.getItem('monetta-proto:v1:cart') ?? '[]').length);
        await button.click();
        await page.waitForFunction((count) => JSON.parse(localStorage.getItem('monetta-proto:v1:cart') ?? '[]').length > count, before, { timeout: 4000 }).catch(() => failures.push('product: adding did not reach the cart'));
        if (await page.locator('.purchase-dock').isVisible()) failures.push('product: the purchase bar is still pinned');
        await context.close();
      }
      // Cart: the summary's checkout opens the handoff and it can be closed.
      {
        const { context, page } = await open(`gpt05-cart-${width}`, { width, height }, { cart: true });
        page.setDefaultTimeout(6000);
        await go(page, '/cart');
        const button = await reachable(page, '[data-checkout]:visible', 'bag checkout button');
        await button.click();
        const dialog = page.locator('[role="dialog"]');
        await dialog.waitFor({ state: 'visible', timeout: 3000 }).catch(() => failures.push('cart: checkout did not open its dialog'));
        const close = dialog.locator('[data-overlay-close]').first();
        if (await close.count()) {
          const box = await close.boundingBox();
          if (!box || box.y < 0 || box.y + box.height > height) failures.push('cart: the dialog\'s close button is out of the viewport');
        }
        await page.keyboard.press('Escape');
        if (await page.locator('.checkout-bar').isVisible()) failures.push('cart: the checkout bar is still pinned');
        await context.close();
      }
      // Collection: filters open, and applying stays reachable.
      {
        const { context, page } = await open(`gpt05-filters-${width}`, { width, height });
        page.setDefaultTimeout(6000);
        await go(page, '/collections/guess');
        await page.locator('[data-page-bar] [data-open-filters]').click();
        const apply = page.locator('[data-apply]');
        await apply.waitFor({ state: 'visible', timeout: 3000 }).catch(() => failures.push('collection: the filters did not open'));
        const box = await apply.boundingBox();
        if (!box || box.y < 0 || box.y + box.height > height + 0.5) failures.push(`collection: the apply button is at ${box?.y}…${box ? box.y + box.height : '?'} of ${height}`);
        else await apply.click();
        await context.close();
      }
      // Search: the field takes input and the results link can be used.
      {
        const { context, page } = await open(`gpt05-search-${width}`, { width, height });
        page.setDefaultTimeout(6000);
        await go(page, '/search');
        await page.fill('#page-search-input', 'tote');
        await page.waitForSelector('#page-search-listbox .search-option__product', { timeout: 3000 }).catch(() => failures.push('search: no suggestions'));
        const link = await reachable(page, '.search-footer .search-option--all[data-query]', 'search results link').catch(() => null);
        if (link) {
          await link.click();
          await page.waitForURL(/\/search\?q=tote/, { timeout: 3000 }).catch(() => failures.push('search: the results link did not navigate'));
        }
        await context.close();
      }
      // Home: the dock sits at the end of the page and navigates.
      {
        const { context, page } = await open(`gpt05-dock-${width}`, { width, height });
        page.setDefaultTimeout(6000);
        await go(page, '/');
        const item = await reachable(page, '.dock [data-dock="catalog"]:visible', 'dock item');
        await item.click();
        await page.waitForURL(/\/collections\/all$/, { timeout: 3000 }).catch(() => failures.push('home: the dock item did not navigate'));
        await context.close();
      }
      assertNone(failures, 'controls unusable in a short viewport');
    });
  }

  await report.step('D11', 'GPT-05 320×200 Tab traversal · product and bag (no pinned bar left to hide a focus ring)', async () => {
    const { context, page } = await open('gpt05-keyboard', { width: 320, height: 200 }, { cart: true });
    const problems = [];
    for (const [name, route] of [
      ['product', PRODUCT],
      ['cart', '/cart'],
    ]) {
      await go(page, route);
      const stops = await keyboardTraversal(page);
      problems.push(...focusProblems(stops).map((entry) => `${name}: ${entry.label} (${entry.reasons.join(', ')})`));
    }
    await context.close();
    assertNone(problems, 'hidden stops');
  });

  await report.step('D11', 'GPT-05 the pinned bars come back with height: 375×812 keeps header, bar and dock pinned', async () => {
    const { context, page } = await open('gpt05-tall', { width: 375, height: 812 });
    const seen = [];
    for (const [name, route, expected] of [
      ['collection', '/collections/guess', ['site-top:sticky', 'page-bar:sticky', 'dock:fixed']],
      ['product', PRODUCT, ['site-top:sticky', 'purchase-dock:fixed']],
    ]) {
      await go(page, route);
      await page.evaluate(() => scrollTo(0, 400));
      await settle(page);
      const chrome = await pinnedChrome(page);
      const pinned = [...chrome.top, ...chrome.bottom].map((entry) => `${entry.name}:${entry.position}`);
      assert(JSON.stringify(pinned) === JSON.stringify(expected), `${name}: ${pinned.join(', ')}`);
      seen.push(`${name} ${pinned.length} pinned`);
    }
    await context.close();
    return seen.join(' · ');
  });

  // ============================================================= GPT-06 · lateral insets
  const SAFE_ROUTES = [
    ['home', '/'],
    ['collection', '/collections/guess'],
    ['product', PRODUCT],
    ['cart', '/cart'],
    ['search', '/search?q=bolsa&type=product'],
    ['favorites', '/pages/favoritos'],
    ['account', '/account'],
    ['mayoreo', '/pages/mayoreo'],
  ];
  /** Interactive controls and visible text that start or end inside a cut-out; a rail's peeking card is the one exception. */
  const outsideSafeRegion = (page) =>
    page.evaluate(() => {
      const probe = document.createElement('div');
      probe.style.cssText = 'position:absolute;visibility:hidden;padding:0 env(safe-area-inset-right) 0 env(safe-area-inset-left)';
      document.body.append(probe);
      const style = getComputedStyle(probe);
      const insets = { left: Number.parseFloat(style.paddingLeft), right: Number.parseFloat(style.paddingRight) };
      probe.remove();
      const view = innerWidth;
      const shown = (element) => element.getClientRects().length > 0 && getComputedStyle(element).visibility !== 'hidden';
      const scrollerOf = (node) => {
        for (let element = node; element && element !== document.body; element = element.parentElement) {
          const { overflowX } = getComputedStyle(element);
          if ((overflowX === 'auto' || overflowX === 'scroll') && element.scrollWidth > element.clientWidth + 1) return element;
        }
        return null;
      };
      const name = (element) => `${element.tagName.toLowerCase()}${element.className && typeof element.className === 'string' ? `.${element.className.split(' ')[0]}` : ''}`;
      const offenders = [];
      const check = (element, rect, kind, text) => {
        if (rect.width <= 1 || rect.height <= 1 || rect.right <= 0 || rect.left >= view) return;
        const scroller = scrollerOf(element);
        const leftOut = rect.left < insets.left - 0.5;
        const rightOut = rect.right > view - insets.right + 0.5;
        // Cards peeking from the next position of a rail run under the cut-out by design; where the rail rests, they do not.
        if (rightOut && !leftOut && scroller) return;
        if (leftOut || rightOut) offenders.push(`${kind} ${name(element)}${text ? ` “${text.slice(0, 24)}”` : ''}: ${rect.left.toFixed(0)}…${rect.right.toFixed(0)}`);
      };
      for (const element of document.querySelectorAll('a[href], button, input:not([type="hidden"]), select, textarea, summary, [role="button"]')) {
        if (!shown(element)) continue;
        check(element, element.getBoundingClientRect(), 'control', (element.getAttribute('aria-label') || element.textContent || '').trim().replace(/\s+/g, ' '));
      }
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      for (let node = walker.nextNode(); node; node = walker.nextNode()) {
        const text = node.textContent.trim();
        const parent = node.parentElement;
        if (!text || !parent || ['SCRIPT', 'STYLE', 'NOSCRIPT'].includes(parent.tagName) || parent.closest('.visually-hidden') || !shown(parent)) continue;
        const range = document.createRange();
        range.selectNodeContents(node);
        for (const rect of range.getClientRects()) check(parent, rect, 'text', text.replace(/\s+/g, ' '));
      }
      return { insets, offenders: [...new Set(offenders)] };
    });

  for (const [width, height] of [
    [667, 375],
    [812, 375],
  ]) {
    await report.step('D11', `GPT-06 ${width}×${height} with 44px side insets (CDP emulation): controls and text of eight pages stay inside the safe region, no horizontal overflow`, async () => {
      const { context, page, safeArea } = await open(`gpt06-${width}`, { width, height }, { cart: true, insets: { left: 44, right: 44, top: 0, bottom: 21 } });
      const problems = [];
      for (const [name, route] of SAFE_ROUTES) {
        await go(page, route);
        const insets = await readSafeArea(page);
        if (insets.left !== 44 || insets.right !== 44) problems.push(`${name}: the page resolved insets ${insets.left}/${insets.right}`);
        const { offenders } = await outsideSafeRegion(page);
        for (const offender of offenders.slice(0, 5)) problems.push(`${name}: ${offender}`);
        const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
        if (overflow > 0) problems.push(`${name}: ${overflow}px of horizontal overflow`);
      }
      await safeArea.clear();
      await context.close();
      assertNone(problems, 'content under the cut-outs');
    });

    await report.step('D11', `GPT-06 ${width}×${height}: the product grid sits between the insets (first card at x = 44, equal columns, last card ends at ${width - 44})`, async () => {
      const { context, page, safeArea } = await open(`gpt06-grid-${width}`, { width, height }, { insets: { left: 44, right: 44, top: 0, bottom: 21 } });
      const seen = [];
      for (const route of ['/collections/guess', '/search?q=bolsa&type=product']) {
        await go(page, route);
        const cards = await page.$$eval('[data-grid] > li', (items) => items.slice(0, 4).map((item) => {
          const rect = item.getBoundingClientRect();
          return { left: rect.left, right: rect.right, width: rect.width, top: rect.top };
        }));
        const first = cards[0];
        near(first.left, 44, 0.6, `${route} first card left`);
        const rowEnd = Math.max(...cards.filter((card) => Math.abs(card.top - first.top) < 2).map((card) => card.right));
        near(rowEnd, width - 44, 0.6, `${route} last card of the row ends at`);
        seen.push(`${route.split('?')[0]} ${first.left.toFixed(1)}…${rowEnd.toFixed(1)} (card ${first.width.toFixed(1)})`);
      }
      await safeArea.clear();
      await context.close();
      return seen.join(' · ');
    });
  }

  await report.step('D11', 'GPT-06 without insets nothing moves: the grid is edge to edge and the gutters are the design\'s (375px and 1440px)', async () => {
    const seen = [];
    for (const [width, height] of [
      [375, 812],
      [1440, 900],
    ]) {
      const { context, page } = await open(`gpt06-none-${width}`, { width, height });
      await go(page, '/collections/guess');
      const edges = await page.$eval('[data-grid] > li', (item) => ({ left: item.getBoundingClientRect().left }));
      const gutter = px(await rootStyle(page, '--gutter'));
      if (width < 768) near(edges.left, 0, 0.6, `${width}px first card left`);
      else assert(edges.left >= gutter - 0.6, `${width}px first card at ${edges.left}, gutter ${gutter}`);
      seen.push(`${width}px card at ${edges.left.toFixed(1)} · gutter ${gutter}`);
      await context.close();
    }
    return seen.join(' · ');
  });

  await report.step('D11', 'GPT-06 drawers, sheets and dialogs keep their content out of the cut-outs (menu, filters, quick view, bag drawer)', async () => {
    const problems = [];
    for (const [width, height] of [
      [667, 375],
      [812, 375],
    ]) {
      const check = async (label, open) => {
        const { context, page, safeArea } = await openFresh(width, height);
        await open(page);
        await sleep(450);
        await settle(page);
        const { offenders } = await outsideSafeRegion(page);
        for (const offender of offenders.filter((entry) => !/overlay__backdrop/.test(entry)).slice(0, 4)) problems.push(`${width} ${label}: ${offender}`);
        await safeArea.clear();
        await context.close();
      };
      const openFresh = (w, h) => open(`gpt06-overlay-${w}`, { width: w, height: h }, { cart: true, insets: { left: 44, right: 44, top: 0, bottom: 21 } });
      await check('menu drawer', async (page) => {
        await go(page, '/');
        await page.locator('[data-action="menu"]:visible').first().click();
        await page.locator('.overlay--drawer-left.is-open').waitFor({ timeout: 3000 });
      });
      await check('filters drawer', async (page) => {
        await go(page, '/collections/guess');
        await page.locator('[data-open-filters]:visible').first().click();
        await page.locator('.overlay--drawer-right.is-open').waitFor({ timeout: 3000 });
      });
      await check('quick view', async (page) => {
        // The first catalog page holds only single-variant products; a search finds one with choices.
        const multi = catalog.products.find((entry) => entry.variants.length > 1);
        await go(page, `/search?q=${encodeURIComponent(multi.title)}&type=product`);
        await page.locator(`[data-action="quick-add"][data-handle="${multi.handle}"]`).click({ timeout: 4000 });
        await page.locator('.overlay--sheet.is-open').waitFor({ timeout: 3000 });
      });
      if (width >= 768) {
        await check('bag drawer', async (page) => {
          await go(page, '/');
          await page.locator('[data-action="cart"]:visible').first().click();
          await page.locator('.overlay--drawer-right.is-open').waitFor({ timeout: 3000 });
        });
      }
    }
    assertNone(problems, 'overlay content under the cut-outs');
  });

  await report.step('D11', 'GPT-06 a bag with a 21px home indicator: the checkout bar and the dock add it below their buttons', async () => {
    const { context, page, safeArea } = await open('gpt06-bottom', { width: 390, height: 844 }, { cart: true, insets: { left: 0, right: 0, top: 0, bottom: 34 } });
    await go(page, '/cart');
    const bar = await page.$eval('.checkout-bar', (element) => {
      const rect = element.getBoundingClientRect();
      const button = element.querySelector('.btn').getBoundingClientRect();
      return { bottom: rect.bottom, buttonBottom: button.bottom, height: rect.height };
    });
    near(bar.bottom - bar.buttonBottom, 12 + 34, 1, 'space under the checkout button');
    await safeArea.clear();
    await context.close();
  });
}

// Standalone: node verify/check-audit-fixes.mjs --url=http://127.0.0.1:4401
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
  if (!args.url) throw new Error('--url=<served build> is required');
  const report = createReport();
  const { browser } = await launch();
  const started = Date.now();
  try {
    await checkAuditFixes({ browser, url: args.url.replace(/\/$/, ''), report });
  } finally {
    await browser.close();
  }
  for (const result of report.results) console.log(`${result.passed ? 'PASS' : 'FAIL'} [${result.gate}] ${result.name}${result.passed ? (result.details ? ` — ${result.details}` : '') : ` — ${result.details}`}`);
  const failed = report.results.filter((result) => !result.passed).length;
  console.log(`\n${report.results.length - failed}/${report.results.length} checks passed in ${Math.round((Date.now() - started) / 1000)}s against ${args.url}`);
  process.exitCode = failed ? 1 : 0;
}
