// D11 — the two defects the reaudit of 2026-10-18 left open after the audit corrections
// (docs/web-redesign/reaudit-gpt-2026-10-18/AUDITORIA_GPT.md):
//
//   RE-01  the short-window fix stopped at 1024px wide: at 1024×200 the header stayed pinned and left 54
//          of 200px to the page, and the desktop columns that stick under it (filters, product panel and
//          gallery, bag summary) were still sized against it;
//   RE-02  the last link of the tablet category row sat under the fade that closes the row, and the focus
//          ring of every link in that row lost its top and bottom edges to the row's own clip.
//
// Like check-audit-fixes.mjs, every check measures what the viewer gets with a real browser: Tab and
// Shift+Tab (the skip link is not used to jump over the header), the stacking, the pinned elements, and
// above all pixels — the ring is read from the screenshot at its four sides and the focused link is compared
// with a second capture of the same page without the fade, because a mask or a clip of the control's own
// container leaves the link on top in `elementFromPoint` and the outline in the CSS.
//
// The sizes are CSS viewports (Playwright viewports), not the browser's own zoom control; the 44px side
// insets are Chromium's emulation. Each check was written to fail on the build that carried the defect (see
// docs/web-redesign/correcciones-reaudit-gpt-2026-10-18/logs/).
//
//   node verify/check-reaudit-fixes.mjs --url=http://127.0.0.1:4601     # any served build (--grep=RE-02 runs part)
//   npm run verify -- --only=reaudit
import { pathToFileURL } from 'node:url';
import { launch } from './browser.mjs';
import { demoCartLines } from './check-layout.mjs';
import { emulateSafeArea, focusProblems, keyboardTraversal, outsideSafeRegion, pinnedChrome, pinnedElements, readSafeArea, settle, tabSteps } from './probes.mjs';
import { assert, createReport, seedCart } from './report.mjs';

const PRODUCT = '/products/bolso-coach-shoulder-negro-rectangular';
const PAGES = [
  ['home', '/'],
  ['collection', '/collections/guess'],
  ['product', PRODUCT],
  ['search', '/search?q=bolsa&type=product'],
  ['cart', '/cart'],
];
const NAV = '.site-nav__list';
const INSETS = { left: 44, right: 44, top: 0, bottom: 21 };
const px = Number.parseFloat;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Fails with every message at once, so one broken page does not hide the others. */
function assertNone(problems, heading) {
  assert(problems.length === 0, `${heading}: ${problems.slice(0, 6).join(' · ')}${problems.length > 6 ? ` (+${problems.length - 6})` : ''}`);
}

export async function checkReauditFixes({ browser, url, report }) {
  async function open(label, viewport, { cart = false, insets = null } = {}) {
    const context = await browser.newContext({ viewport, reducedMotion: 'reduce' });
    if (cart) await seedCart(context, demoCartLines());
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
  const scrollDown = async (page, pixels) => {
    await page.evaluate((amount) => scrollTo(0, Math.min(amount, document.documentElement.scrollHeight - innerHeight)), pixels);
    await settle(page);
  };
  /** The desktop columns that stick under the header and the gallery they are sized against. */
  const columns = (page) =>
    page.evaluate(() => {
      const read = (selector) => {
        const element = document.querySelector(selector);
        if (!element || element.getClientRects().length === 0) return null;
        const style = getComputedStyle(element);
        const rect = element.getBoundingClientRect();
        return { position: style.position, maxHeight: style.maxHeight, maxWidth: style.maxWidth, width: rect.width, height: rect.height };
      };
      return {
        header: read('#site-top'),
        filterSidebar: read('.collection-layout--filters .filter-sidebar'),
        productPanel: read('.product-panel'),
        galleryViewer: read('.gallery__main'),
        galleryThumbs: read('.gallery__thumbs'),
        cartSummary: read('.summary'),
      };
    });
  /** A control that has to be reachable: on screen, not covered, and the thing under its centre. */
  const reachable = async (page, selector, label, failures) => {
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

  // ============================================================= RE-01 · short windows from 1024px up
  await report.step('D11', 'RE-01 1024×200 behaves like 1023×200: the collection scrolled 800px leaves the whole window to the products on both sides of the width limit', async () => {
    const seen = {};
    for (const width of [1023, 1024]) {
      const { context, page } = await open(`re01-pair-${width}`, { width, height: 200 });
      await go(page, '/collections/guess');
      await scrollDown(page, 800);
      const header = await page.$eval('#site-top', (element) => ({ position: getComputedStyle(element).position, bottom: element.getBoundingClientRect().bottom }));
      const chrome = await pinnedChrome(page);
      seen[width] = { ...header, free: chrome.free };
      await context.close();
    }
    for (const width of [1023, 1024]) {
      assert(seen[width].position === 'static', `${width}×200: #site-top is ${seen[width].position}, ends at ${seen[width].bottom.toFixed(0)}px and leaves ${seen[width].free}px of 200 to the products`);
    }
    assert(seen[1024].free === seen[1023].free, `free window differs across the limit: ${seen[1023].free}px at 1023 vs ${seen[1024].free}px at 1024`);
    return `free ${seen[1023].free}px at 1023 and ${seen[1024].free}px at 1024`;
  });

  for (const width of [1023, 1024, 1280, 1440]) {
    await report.step('D11', `RE-01 ${width}px wide, 200, 360 and 480px tall: the five pages leave the window to the content, with no header, bar or column pinned over it`, async () => {
      const problems = [];
      const seen = [];
      for (const height of [200, 360, 480]) {
        const { context, page } = await open(`re01-${width}x${height}`, { width, height }, { cart: true });
        for (const [name, route] of PAGES) {
          await go(page, route);
          await scrollDown(page, 800);
          const chrome = await pinnedChrome(page);
          const pinned = await pinnedElements(page);
          if (chrome.ratio < 0.9) problems.push(`${width}×${height} ${name}: ${Math.round(chrome.free)}px of ${height} free (${[...chrome.top, ...chrome.bottom].map((entry) => entry.name).join('+')})`);
          if (pinned.length) problems.push(`${width}×${height} ${name}: still pinned ${pinned.join(', ')}`);
          const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
          if (overflow > 0) problems.push(`${width}×${height} ${name}: ${overflow}px of horizontal overflow`);
          if (name === 'collection') seen.push(`${height}: ${Math.round(chrome.free)}`);
        }
        await context.close();
      }
      assertNone(problems, 'content squeezed under pinned chrome');
      return `collection free px — ${seen.join(' · ')}`;
    });
  }

  await report.step('D11', 'RE-01 in a short window the desktop columns flow with the page: filters, product panel and bag summary are not sticky and the gallery keeps its natural size (1024×200, 1280×200, 1440×360)', async () => {
    const problems = [];
    const seen = [];
    for (const [width, height] of [
      [1024, 200],
      [1280, 200],
      [1440, 360],
    ]) {
      const { context, page } = await open(`re01-columns-${width}`, { width, height }, { cart: true });
      await go(page, '/collections/guess');
      const collection = await columns(page);
      if (width >= 1200) {
        const sidebar = collection.filterSidebar;
        if (!sidebar) problems.push(`${width}×${height}: no filter sidebar`);
        else {
          if (sidebar.position !== 'static') problems.push(`${width}×${height}: filter sidebar is ${sidebar.position}`);
          if (sidebar.maxHeight !== 'none' || sidebar.height < 400) problems.push(`${width}×${height}: filter sidebar is ${Math.round(sidebar.height)}px tall (max-height ${sidebar.maxHeight})`);
        }
      }
      await go(page, PRODUCT);
      const product = await columns(page);
      if (product.productPanel.position !== 'static') problems.push(`${width}×${height}: product panel is ${product.productPanel.position}`);
      const viewer = product.galleryViewer;
      if (viewer.width < 300 || viewer.height < 300) problems.push(`${width}×${height}: gallery viewer is ${Math.round(viewer.width)}×${Math.round(viewer.height)}px`);
      if (product.galleryThumbs.height < 100) problems.push(`${width}×${height}: gallery thumbnails are ${Math.round(product.galleryThumbs.height)}px tall`);
      await go(page, '/cart');
      const cart = await columns(page);
      if (cart.cartSummary.position !== 'static') problems.push(`${width}×${height}: bag summary is ${cart.cartSummary.position}`);
      seen.push(`${width}×${height} viewer ${Math.round(viewer.width)}×${Math.round(viewer.height)}`);
      await context.close();
    }
    assertNone(problems, 'columns tuned to a pinned header');
    return seen.join(' · ');
  });

  await report.step('D11', 'RE-01 across the 480px height limit the header changes (static at 480, pinned at 481) and normal windows keep their pinned header, sticky columns and fitted gallery (1024 and 1440 wide, 481 / 768 / 900 tall)', async () => {
    const problems = [];
    const seen = [];
    for (const [width, height, short] of [
      [1024, 480, true],
      [1440, 480, true],
      [1024, 481, false],
      [1440, 481, false],
      [1024, 768, false],
      [1440, 900, false],
    ]) {
      const { context, page } = await open(`re01-limit-${width}x${height}`, { width, height }, { cart: true });
      const label = `${width}×${height}`;
      const fit = ((height - 235) * 0.8) + 1.5; // the gallery's own formula: (window − strip − header − category row − 90) × 0.8
      await go(page, PRODUCT);
      await scrollDown(page, 300);
      const product = await columns(page);
      const wantedHeader = short ? 'static' : 'sticky';
      if (product.header.position !== wantedHeader) problems.push(`${label} product: header is ${product.header.position}, expected ${wantedHeader}`);
      if (product.productPanel.position !== wantedHeader) problems.push(`${label} product: panel is ${product.productPanel.position}, expected ${wantedHeader}`);
      if (!short && product.galleryViewer.width > fit) problems.push(`${label} product: gallery viewer ${Math.round(product.galleryViewer.width)}px wide is not fitted to the window (≤ ${Math.round(fit)})`);
      if (short && product.galleryViewer.width < 300) problems.push(`${label} product: gallery viewer collapsed to ${Math.round(product.galleryViewer.width)}px`);
      await go(page, '/cart');
      const cart = await columns(page);
      if (cart.cartSummary.position !== wantedHeader) problems.push(`${label} bag: summary is ${cart.cartSummary.position}, expected ${wantedHeader}`);
      if (width >= 1200) {
        await go(page, '/collections/guess');
        const collection = await columns(page);
        if (collection.filterSidebar.position !== wantedHeader) problems.push(`${label} collection: filters are ${collection.filterSidebar.position}, expected ${wantedHeader}`);
        if (!short && collection.filterSidebar.maxHeight === 'none') problems.push(`${label} collection: the sticky filters lost their max-height`);
      }
      if (!short) {
        await go(page, '/collections/guess');
        await scrollDown(page, 400);
        const chrome = await pinnedChrome(page);
        if (Math.round(chrome.pinnedTop) !== 146) problems.push(`${label}: pinned header is ${chrome.pinnedTop}px, expected 146`);
      }
      seen.push(`${label} ${wantedHeader}`);
      await context.close();
    }
    assertNone(problems, 'limit or normal view changed');
    return seen.join(' · ');
  });

  for (const [width, height] of [
    [1024, 200],
    [1280, 240],
    [1440, 360],
  ]) {
    await report.step('D11', `RE-01 ${width}×${height}: add to bag, bag checkout, filters, search and the browser's Back and Forward work and are not covered`, async () => {
      const failures = [];

      // Product: the inline button.
      {
        const { context, page } = await open(`re01-product-${width}`, { width, height });
        page.setDefaultTimeout(6000);
        await go(page, PRODUCT);
        const button = await reachable(page, '[data-add]:visible', 'product add button', failures);
        const before = await page.evaluate(() => JSON.parse(localStorage.getItem('monetta-proto:v1:cart') ?? '[]').length);
        await button.click();
        await page.waitForFunction((count) => JSON.parse(localStorage.getItem('monetta-proto:v1:cart') ?? '[]').length > count, before, { timeout: 4000 }).catch(() => failures.push('product: adding did not reach the bag'));
        await context.close();
      }
      // Bag: the summary's checkout.
      {
        const { context, page } = await open(`re01-cart-${width}`, { width, height }, { cart: true });
        page.setDefaultTimeout(6000);
        await go(page, '/cart');
        const button = await reachable(page, '[data-checkout]:visible', 'bag checkout button', failures);
        await button.click();
        const dialog = page.locator('[role="dialog"]');
        await dialog.waitFor({ state: 'visible', timeout: 3000 }).catch(() => failures.push('bag: checkout did not open its dialog'));
        await page.keyboard.press('Escape');
        await context.close();
      }
      // Filters: the sidebar from 1200px, the toolbar's drawer below.
      {
        const { context, page } = await open(`re01-filters-${width}`, { width, height });
        page.setDefaultTimeout(6000);
        await go(page, '/collections/guess');
        if (width >= 1200) {
          const facet = await reachable(page, '.filter-sidebar .check', 'filter checkbox', failures);
          await facet.click();
          await page.waitForURL(/filter\./, { timeout: 4000 }).catch(() => failures.push('filters: checking a facet did not change the address'));
        } else {
          const open = await reachable(page, '[data-open-filters]:visible', 'filters button', failures);
          await open.click();
          const apply = page.locator('[data-apply]');
          await apply.waitFor({ state: 'visible', timeout: 3000 }).catch(() => failures.push('filters: the drawer did not open'));
          const box = await apply.boundingBox();
          if (!box || box.y < 0 || box.y + box.height > height + 0.5) failures.push(`filters: the apply button is at ${box?.y}…${box ? box.y + box.height : '?'} of ${height}`);
        }
        await context.close();
      }
      // Search: the header field, its suggestions and the results link.
      {
        const { context, page } = await open(`re01-search-${width}`, { width, height });
        page.setDefaultTimeout(6000);
        await go(page, '/');
        await page.fill('#header-search-input', 'tote');
        await page.waitForSelector('.search-panel:not([hidden]) .search-option__product', { timeout: 3000 }).catch(() => failures.push('search: no suggestions'));
        const link = await reachable(page, '.search-footer .search-option--all[data-query]', 'search results link', failures).catch(() => null);
        if (link) {
          await link.click();
          await page.waitForURL(/\/search\?q=tote/, { timeout: 3000 }).catch(() => failures.push('search: the results link did not navigate'));
        }
        await context.close();
      }
      // Back and Forward: home → collection → product, back, forward; the scroll comes back too.
      {
        const { context, page } = await open(`re01-history-${width}`, { width, height });
        page.setDefaultTimeout(6000);
        await go(page, '/');
        await page.locator('.site-nav a[href="/collections/guess"]').click();
        await page.waitForURL(/\/collections\/guess$/);
        await settle(page);
        await scrollDown(page, 600);
        const before = await page.evaluate(() => scrollY);
        await page.evaluate(() => document.querySelectorAll('[data-grid] .card__link')[2].click());
        await page.waitForURL(/\/products\//);
        const product = page.url();
        await page.goBack({ waitUntil: 'commit' });
        await page.waitForURL(/\/collections\/guess$/);
        await settle(page);
        await sleep(150);
        const back = await page.evaluate(() => scrollY);
        if (Math.abs(back - before) > 2) failures.push(`history: Back restored scroll ${back}, expected ${before}`);
        await page.goForward({ waitUntil: 'commit' });
        await sleep(300);
        if (page.url() !== product) failures.push(`history: Forward ended on ${page.url().replace(url, '')}`);
        await context.close();
      }
      assertNone(failures, 'a control is unusable in a short desktop window');
    });
  }

  await report.step('D11', 'RE-01 Tab traversal in short desktop windows (product at 1024×200, bag at 1280×240, collection at 1440×360): no focused control, text or ring is hidden, footer links included', async () => {
    const problems = [];
    for (const [width, height, name, route] of [
      [1024, 200, 'product', PRODUCT],
      [1280, 240, 'cart', '/cart'],
      [1440, 360, 'collection', '/collections/guess'],
    ]) {
      const { context, page } = await open(`re01-keys-${width}`, { width, height }, { cart: true });
      await go(page, route);
      const stops = await keyboardTraversal(page);
      problems.push(...focusProblems(stops).map((entry) => `${width}×${height} ${name}: ${entry.label} (${entry.region}): ${entry.reasons.join(', ')}`));
      assert(stops.filter((stop) => stop.region === 'footer').length >= 15, `${width}×${height} ${name}: the traversal reached ${stops.filter((stop) => stop.region === 'footer').length} footer stops`);
      await context.close();
    }
    assertNone(problems, 'hidden stops');
  });

  await report.step('D11', 'RE-01 with 44px emulated insets the header is not pinned at 1024×200 or 812×300 and controls and text stay inside the safe region (home, collection, product, bag, search)', async () => {
    const problems = [];
    for (const [width, height] of [
      [1024, 200],
      [812, 300],
    ]) {
      const { context, page, safeArea } = await open(`re01-insets-${width}`, { width, height }, { cart: true, insets: INSETS });
      for (const [name, route] of PAGES) {
        await go(page, route);
        const insets = await readSafeArea(page);
        if (insets.left !== 44 || insets.right !== 44) problems.push(`${name}: the page resolved insets ${insets.left}/${insets.right}`);
        await scrollDown(page, 600);
        const chrome = await pinnedChrome(page);
        if (chrome.ratio < 0.9) problems.push(`${width}×${height} ${name}: ${Math.round(chrome.free)}px of ${height} free`);
        await page.evaluate(() => scrollTo(0, 0));
        await settle(page);
        const { offenders } = await outsideSafeRegion(page);
        for (const offender of offenders.slice(0, 4)) problems.push(`${width}×${height} ${name}: ${offender}`);
      }
      await safeArea.clear();
      await context.close();
    }
    assertNone(problems, 'short window with insets');
  });

  // ============================================================= RE-02 · the category row with the keyboard
  /** Tab to the last category link without the skip link, Shift+Tab back, and require the link whole and painted. */
  async function walkCategoryRow(page) {
    const forward = await keyboardTraversal(page, {
      enterContent: false,
      pixelRegions: ['nav'],
      maskedScroller: NAV,
      stopWhen: (stop) => stop.region === 'nav' && stop.label === 'Nuestra historia',
    });
    const forwardNav = forward.filter((stop) => stop.region === 'nav');
    const row = await page.evaluate((selector) => {
      const list = document.querySelector(selector);
      const rect = list.getBoundingClientRect();
      const mask = getComputedStyle(list).maskImage || getComputedStyle(list).webkitMaskImage || 'none';
      const percent = /(\d+(?:\.\d+)?)%/.exec(mask)?.[1];
      return { links: list.children.length, scrollLeft: list.scrollLeft, mask, fadeStart: percent ? rect.left + (rect.width * Number(percent)) / 100 : null };
    }, NAV);
    const backward = await tabSteps(page, 'Shift+Tab', row.links - 1, { pixelRegions: ['nav'], maskedScroller: NAV });
    return { forwardNav, backward: backward.filter((stop) => stop.region === 'nav'), row };
  }
  /** What a keyboard user must be left with on a category link: a whole ring and whole words. */
  function judgeLink(stop, row, where) {
    const problems = focusProblems([stop]).map((entry) => `${where} ${entry.label}: ${entry.reasons.join(', ')}`);
    if (!stop.pixels || stop.pixels.ringSampled !== 4 || stop.pixels.ringDark !== 4) problems.push(`${where} ${stop.label}: ring painted on ${stop.pixels?.ringDark}/${stop.pixels?.ringSampled} sides`);
    if (!stop.mask || stop.mask.differing !== 0) problems.push(`${where} ${stop.label}: the fade changes ${stop.mask?.differing} painted pixels (up to ${stop.mask?.maxDelta}/255)`);
    const right = stop.box.x + stop.box.width;
    if (row.fadeStart !== null && right > row.fadeStart + 0.5) problems.push(`${where} ${stop.label}: ends at ${right.toFixed(1)}, the fade starts at ${row.fadeStart.toFixed(1)}`);
    if (row.fadeStart !== null && stop.textRect.right > row.fadeStart + 0.5) problems.push(`${where} ${stop.label}: its words end at ${stop.textRect.right.toFixed(1)}, the fade starts at ${row.fadeStart.toFixed(1)}`);
    return problems;
  }

  for (const [width, height, label, insets] of [
    [768, 1024, 'tablet', null],
    [812, 1024, 'tablet', null],
    [1023, 768, 'tablet, one pixel below the width limit', null],
    [1024, 768, 'desktop, one pixel above it', null],
    [1440, 900, 'desktop', null],
    [768, 1024, 'tablet with 44px emulated insets', INSETS],
    [812, 375, 'short tablet with 44px emulated insets', INSETS],
  ]) {
    await report.step('D11', `RE-02 ${width}×${height} (${label}): Tab without the skip link and Shift+Tab back through the category row leave every link whole, outside the fade, with its ring painted on four sides`, async () => {
      const problems = [];
      const { context, page, safeArea } = await open(`re02-${width}x${height}`, { width, height }, { insets });
      await go(page, '/');
      const { forwardNav, backward, row } = await walkCategoryRow(page);
      assert(forwardNav.length === row.links, `Tab reached ${forwardNav.length} of ${row.links} category links`);
      assert(backward.length === row.links - 1, `Shift+Tab went back over ${backward.length} of ${row.links - 1} links`);
      for (const stop of forwardNav) problems.push(...judgeLink(stop, row, 'Tab'));
      for (const stop of backward) problems.push(...judgeLink(stop, row, 'Shift+Tab'));
      // The design stays: the row still fades on tablets and not on desktop.
      if (width < 1024 && row.mask === 'none') problems.push('the tablet row lost its fade');
      if (width >= 1024 && row.mask !== 'none') problems.push(`the desktop row has a fade (${row.mask})`);
      if (insets) {
        await page.evaluate(() => scrollTo(0, 0));
        await settle(page);
        const { offenders } = await outsideSafeRegion(page);
        for (const offender of offenders.slice(0, 4)) problems.push(`safe region: ${offender}`);
      }
      const last = forwardNav.at(-1);
      await safeArea?.clear();
      await context.close();
      assertNone(problems, 'category row');
      return `${row.links} links, last “${last.label}” ${last.box.x.toFixed(0)}…${(last.box.x + last.box.width).toFixed(0)} (text to ${last.textRect.right.toFixed(0)}), fade from ${row.fadeStart?.toFixed(0) ?? 'none'}`;
    });
  }

  await report.step('D11', 'RE-02 the desktop row stays centred when its links fit (1280, 1440) and starts on the gutter, or on the inset, when they overflow a little (1024 with and without 44px insets)', async () => {
    const problems = [];
    const seen = [];
    for (const [width, insets] of [
      [1280, null],
      [1440, null],
      [1024, null],
      [1024, INSETS],
    ]) {
      const { context, page, safeArea } = await open(`re02-row-${width}`, { width, height: 800 }, { insets });
      await go(page, '/');
      const row = await page.evaluate((selector) => {
        const list = document.querySelector(selector);
        const links = [...list.querySelectorAll(':scope > li > *')];
        const first = links[0].getBoundingClientRect();
        const last = links.at(-1).getBoundingClientRect();
        return { first: first.left, last: last.right, overflow: list.scrollWidth - list.clientWidth, view: innerWidth, padLeft: Number.parseFloat(getComputedStyle(list).paddingLeft) };
      }, NAV);
      const label = `${width}px${insets ? ' with insets' : ''}`;
      if (width === 1024) {
        if (row.overflow <= 0) problems.push(`${label}: the links no longer overflow, the case this check is about is gone`);
        if (Math.abs(row.first - row.padLeft) > 0.5) problems.push(`${label}: the first link starts at ${row.first.toFixed(1)}, the row's padding is ${row.padLeft}`);
        if (row.last > row.view + 0.5) problems.push(`${label}: the last link ends at ${row.last.toFixed(1)} of ${row.view}`);
      } else {
        if (row.overflow > 0) problems.push(`${label}: the row overflows by ${row.overflow}px`);
        const right = row.view - row.last;
        if (Math.abs(row.first - right) > 1) problems.push(`${label}: not centred (${row.first.toFixed(1)}px on the left, ${right.toFixed(1)}px on the right)`);
      }
      seen.push(`${label}: ${row.first.toFixed(1)}…${row.last.toFixed(1)}${row.overflow > 0 ? ` (overflow ${row.overflow}px)` : ''}`);
      await safeArea?.clear();
      await context.close();
    }
    assertNone(problems, 'desktop category row');
    return seen.join(' · ');
  });

  for (const [width, height] of [
    [768, 1024],
    [812, 1024],
    [1023, 768],
  ]) {
    await report.step('D11', `RE-02 ${width}×${height}: entering the category row backwards (skip link, then Shift+Tab) lands on the last link already whole and painted`, async () => {
      const problems = [];
      const { context, page } = await open(`re02-back-${width}`, { width, height });
      await go(page, '/');
      await page.keyboard.press('Tab');
      await page.keyboard.press('Enter');
      const [stop] = await tabSteps(page, 'Shift+Tab', 1, { pixelRegions: ['nav'], maskedScroller: NAV });
      assert(stop && stop.region === 'nav' && stop.label === 'Nuestra historia', `Shift+Tab from the content landed on “${stop?.label}” (${stop?.region})`);
      const row = await page.evaluate((selector) => {
        const list = document.querySelector(selector);
        const rect = list.getBoundingClientRect();
        const mask = getComputedStyle(list).maskImage || getComputedStyle(list).webkitMaskImage || 'none';
        const percent = /(\d+(?:\.\d+)?)%/.exec(mask)?.[1];
        return { scrollLeft: list.scrollLeft, fadeStart: percent ? rect.left + (rect.width * Number(percent)) / 100 : null };
      }, NAV);
      problems.push(...judgeLink(stop, row, 'Shift+Tab'));
      if (row.scrollLeft <= 0) problems.push('the row did not scroll to bring the last link in');
      await context.close();
      assertNone(problems, 'last link entered from the end');
      return `scrolled to ${row.scrollLeft.toFixed(0)}, link ends at ${(stop.box.x + stop.box.width).toFixed(0)}, fade from ${row.fadeStart?.toFixed(0)}`;
    });
  }
}

// Standalone: node verify/check-reaudit-fixes.mjs --url=http://127.0.0.1:4601
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
  if (!args.url) throw new Error('--url=<served build> is required');
  const report = createReport();
  // --grep=<text> runs only the checks whose name contains it (used by the mutation runs).
  if (args.grep) {
    const run = report.step.bind(report);
    report.step = (gate, name, fn) => (name.includes(args.grep) ? run(gate, name, fn) : Promise.resolve(true));
  }
  const { browser } = await launch();
  const started = Date.now();
  try {
    await checkReauditFixes({ browser, url: args.url.replace(/\/$/, ''), report });
  } finally {
    await browser.close();
  }
  for (const result of report.results) console.log(`${result.passed ? 'PASS' : 'FAIL'} [${result.gate}] ${result.name}${result.passed ? (result.details ? ` — ${result.details}` : '') : ` — ${result.details}`}`);
  const failed = report.results.filter((result) => !result.passed).length;
  console.log(`\n${report.results.length - failed}/${report.results.length} checks passed in ${Math.round((Date.now() - started) / 1000)}s against ${args.url}`);
  process.exitCode = failed ? 1 : 0;
}
