// D11 — fidelity with the app's phone design (findings H01–H03 of the
// 2026-10-18 review). Each assertion states a fact read from the Flutter source
// (lib/features/navigation/monetta_page_header.dart, product/product_header.dart,
// product_screen.dart _Rail, catalog/product_card.dart) and measures the rendered
// prototype against it: which controls a phone header shows and in what order,
// the typographic role and anatomy of recommendations, and how much chrome sits
// above the first product. They protect specific regressions; they are not a
// pixel comparison with the app (see the side-by-side captures for that).
import { demoCartLines } from './check-layout.mjs';
import { assert, seedCart } from './report.mjs';

const PHONES = [
  [375, 812],
  [390, 844],
  [440, 956],
];
const STRIP = 28;
const TAP = 44;

const style = (page, selector, ...names) =>
  page.$eval(
    selector,
    (node, props) => {
      const computed = getComputedStyle(node);
      return Object.fromEntries(props.map((name) => [name, computed[name]]));
    },
    names,
  );

/** Visible links and buttons inside [selector], left to right. */
async function visibleControls(page, selector) {
  const controls = await page.$$eval(selector, (nodes) =>
    nodes
      .filter((node) => node.getClientRects().length && getComputedStyle(node).visibility !== 'hidden')
      .map((node) => {
        const rect = node.getBoundingClientRect();
        return { label: node.getAttribute('aria-label') || node.textContent.trim(), href: node.getAttribute('href'), x: rect.x, y: rect.y, width: rect.width, height: rect.height };
      }),
  );
  return controls.sort((a, b) => a.x - b.x);
}

async function platformFonts(page, selector) {
  const client = await page.context().newCDPSession(page);
  await client.send('DOM.enable');
  await client.send('CSS.enable');
  const { root } = await client.send('DOM.getDocument', { depth: -1 });
  const { nodeId } = await client.send('DOM.querySelector', { nodeId: root.nodeId, selector });
  assert(nodeId, `no node for ${selector}`);
  const { fonts } = await client.send('CSS.getPlatformFontsForNode', { nodeId });
  await client.detach();
  return fonts.map((font) => `${font.familyName}${font.isCustomFont ? ' (web font)' : ''}`);
}

const near = (actual, expected, tolerance, label) => assert(Math.abs(actual - expected) <= tolerance, `${label}: ${actual} (expected ${expected} ± ${tolerance})`);
const px = (value) => Number.parseFloat(value);

export async function checkFidelity({ browser, url, report }) {
  // ------------------------------------------------ H01 · compact interior bar
  for (const [width, height] of PHONES) {
    const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 2, hasTouch: true });
    await seedCart(context, demoCartLines());
    const page = await context.newPage();
    report.trackPage(page, `fidelity-${width}`);
    const go = (path) => page.goto(`${url}${path}`, { waitUntil: 'networkidle' });

    await report.step('D11', `H01 collection @ ${width}px: one pinned bar (back · title · search · filters) replaces header, breadcrumbs and toolbar`, async () => {
      await go('/collections/guess');
      assert(!(await page.locator('.site-header').isVisible()), 'global header still visible');
      assert(!(await page.locator('.breadcrumbs').first().isVisible()), 'breadcrumbs visible');
      assert(!(await page.locator('.toolbar').first().isVisible()), 'toolbar row visible');
      const bar = page.locator('[data-page-bar]');
      assert(await bar.isVisible(), 'page bar hidden');
      const controls = await visibleControls(page, '[data-page-bar] a, [data-page-bar] button');
      assert(
        JSON.stringify(controls.map((control) => control.label)) === JSON.stringify(['Volver', 'Buscar productos', 'Filtrar y ordenar']),
        `controls: ${controls.map((control) => control.label).join(' | ')}`,
      );
      for (const control of controls) assert(control.width >= TAP && control.height >= TAP, `${control.label} is ${control.width}×${control.height}`);
      const title = await style(page, '[data-page-bar] h1', 'fontFamily', 'fontSize', 'fontWeight');
      assert(title.fontFamily.startsWith('"Playfair Display"') && title.fontSize === '28px' && title.fontWeight === '400', `title ${JSON.stringify(title)}`);
      const count = (await page.textContent('[data-page-bar] [data-count]')).trim();
      assert(/^\d+ piezas$/.test(count), `count "${count}"`);
      return `${controls.map((control) => `${control.label} ${Math.round(control.width)}×${Math.round(control.height)}`).join(' · ')}; title Playfair 28/400; ${count}`;
    });

    await report.step('D11', `H01 collection @ ${width}px: only the bar and the style shortcuts sit above the first product`, async () => {
      await go('/collections/guess');
      const barBox = await page.locator('[data-page-bar]').boundingBox();
      const shortcuts = await page.locator('.collection-shortcuts').boundingBox();
      const card = await page.locator('[data-grid] .card').first().boundingBox();
      // The old phone layout stacked header, breadcrumbs, title, shortcuts, toolbar and chips:
      // the first card sat 324px below the strip. Everything above the card must now be
      // exactly the bar, the shortcut row and one 12px gap.
      const above = card.y - STRIP;
      const budget = barBox.height + shortcuts.height + 12;
      assert(above <= budget + 1, `first product starts ${above}px below the strip; bar + shortcuts + gap is ${budget}px`);
      near(card.x, 0, 0.5, 'card starts at the screen edge');
      near(card.width, (width - 12) / 2, 1, 'two columns share the viewport with a 12px gap');
      // The app reserves one caption height per row: the two cards of a row are equally tall.
      const cells = await page.$$eval('[data-grid] .card', (nodes) =>
        nodes.slice(0, 16).map((node) => {
          const rect = node.getBoundingClientRect();
          return { top: Math.round(rect.top + window.scrollY), height: rect.height };
        }),
      );
      const rows = Map.groupBy(cells, (cell) => cell.top);
      for (const [top, row] of rows) {
        const heights = row.map((cell) => cell.height);
        assert(Math.max(...heights) - Math.min(...heights) <= 1, `row at y=${top} has uneven cards: ${heights.join(', ')}`);
      }
      return `first product ${Math.round(above)}px below the strip (bar ${Math.round(barBox.height)} + shortcuts ${Math.round(shortcuts.height)} + 12); card ${card.width}px wide at x=${card.x}; ${rows.size} rows of equal cells`;
    });

    await report.step('D11', `H01 collection @ ${width}px: the bar stays pinned under the strip and draws its rule on scroll`, async () => {
      await go('/collections/guess');
      await page.evaluate(() => window.scrollTo(0, 900));
      await page.waitForTimeout(350);
      const pinned = await page.locator('[data-page-bar]').boundingBox();
      near(pinned.y, STRIP, 1, 'bar top while scrolled');
      const rule = await style(page, '[data-page-bar]', 'borderBottomColor', 'position');
      assert(rule.position === 'sticky', `position ${rule.position}`);
      assert(rule.borderBottomColor !== 'rgba(0, 0, 0, 0)', `no rule: ${rule.borderBottomColor}`);
      return `top ${pinned.y} while scrolled; ${rule.position}; rule ${rule.borderBottomColor}`;
    });

    await report.step('D11', `H01 collection @ ${width}px: keyboard focus lands below the pinned bar, not under it`, async () => {
      await go('/collections/guess');
      await page.evaluate(() => window.scrollTo(0, 2400));
      await page.waitForTimeout(250);
      // The first product is far above the viewport now. Tab and Shift+Tab bring the focused
      // element into view with the "nearest" alignment, which stops at the scrollport's
      // scroll-padding; WCAG 2.2 "Focus Not Obscured" needs that to clear the strip and the bar.
      await page.evaluate(() => document.querySelector('[data-grid] li:nth-child(1) .card__link').scrollIntoView({ block: 'nearest', behavior: 'instant' }));
      await page.waitForTimeout(250);
      const [bar, link] = await Promise.all([page.locator('[data-page-bar]').boundingBox(), page.locator('[data-grid] li:nth-child(1) .card__link').boundingBox()]);
      const padding = px(await page.evaluate(() => getComputedStyle(document.documentElement).scrollPaddingTop));
      assert(padding >= bar.y + bar.height, `scroll-padding-top ${padding}px does not reserve the strip and bar (${bar.y + bar.height}px)`);
      assert(link.y >= bar.y + bar.height - 0.5, `the product scrolled into view starts at y=${Math.round(link.y)}, the bar ends at y=${Math.round(bar.y + bar.height)}`);
      return `scroll-padding-top ${padding}px ≥ strip + bar ${Math.round(bar.y + bar.height)}px; product aligned at y=${Math.round(link.y)}`;
    });

    await report.step('D11', `H01 search results @ ${width}px: "Buscar" bar, field, Inter results heading, filters in the bar`, async () => {
      await go('/search?q=bolsa&type=product');
      assert(!(await page.locator('.site-header').isVisible()), 'global header still visible');
      assert(!(await page.locator('.breadcrumbs').first().isVisible()), 'breadcrumbs visible');
      assert(!(await page.locator('.toolbar').first().isVisible()), 'toolbar row visible');
      assert((await page.locator('[data-page-bar] h1').count()) === 0, 'the bar title must be plain text when results own the h1');
      assert((await page.textContent('[data-page-bar] .page-bar__title')).trim() === 'Buscar', 'bar title is not "Buscar"');
      const controls = await visibleControls(page, '[data-page-bar] a, [data-page-bar] button');
      assert(JSON.stringify(controls.map((control) => control.label)) === JSON.stringify(['Volver', 'Filtrar y ordenar']), `controls: ${controls.map((control) => control.label).join(' | ')}`);
      assert((await page.locator('h1').count()) === 1, 'the page must have exactly one h1');
      const heading = await style(page, 'main h1', 'fontFamily', 'fontSize', 'fontWeight');
      assert(heading.fontFamily.startsWith('Inter') && px(heading.fontSize) >= 20 && heading.fontWeight === '600', `heading ${JSON.stringify(heading)}`);
      const [bar, field, h1, card] = await Promise.all([
        page.locator('[data-page-bar]').boundingBox(),
        page.locator('[data-page-search]').boundingBox(),
        page.locator('main h1').boundingBox(),
        page.locator('[data-grid] .card').first().boundingBox(),
      ]);
      assert(bar.y < field.y && field.y < h1.y && h1.y < card.y, 'bar, field, heading and products are not in that order');
      assert(card.y - (h1.y + h1.height) <= 12 + 16 + 1, `${card.y - (h1.y + h1.height)}px between the results heading and the first product`);
      near(card.x, 0, 0.5, 'results grid starts at the screen edge');
      return `heading ${heading.fontFamily.split(',')[0]} ${heading.fontSize}/${heading.fontWeight}; first product ${Math.round(card.y - STRIP)}px below the strip`;
    });

    await report.step('D11', `H01 search @ ${width}px: suggestions replace the results and take the bar's filters with them`, async () => {
      await go('/search?q=bolsa&type=product');
      assert(await page.locator('[data-page-bar] [data-open-filters]').isVisible(), 'filters missing before typing');
      await page.fill('#page-search-input', 'tote');
      await page.waitForSelector('#page-search-listbox .search-option__product');
      assert(!(await page.locator('[data-page-bar] [data-open-filters]').isVisible()), 'filters still shown over suggestions');
      assert(!(await page.locator('[data-search-results]').isVisible()), 'results still shown under suggestions');
      await go('/search');
      assert((await page.locator('[data-page-bar] h1').textContent()).trim() === 'Buscar', 'empty search has no h1 in the bar');
      assert((await page.locator('[data-page-bar] [data-open-filters]').count()) === 0, 'filters offered with nothing to filter');
      return 'filters hidden while suggestions show; the empty search offers none';
    });

    await report.step('D11', `H01 bag @ ${width}px: back · Mi bolsa · count in one bar, lines right below`, async () => {
      await go('/cart');
      assert(!(await page.locator('.site-header').isVisible()), 'global header still visible');
      const controls = await visibleControls(page, '[data-page-bar] a, [data-page-bar] button');
      assert(JSON.stringify(controls.map((control) => control.label)) === JSON.stringify(['Volver']), `controls: ${controls.map((control) => control.label).join(' | ')}`);
      // The app's first line draws its top border right under the header, so the bag's bar is ruled from the start.
      const rule = await style(page, '[data-page-bar]', 'borderBottomColor');
      assert(rule.borderBottomColor !== 'rgba(0, 0, 0, 0)', `the bag bar has no rule before scrolling: ${rule.borderBottomColor}`);
      const title = await page.locator('[data-page-bar] h1').boundingBox();
      const trailing = await page.locator('[data-cart-heading-count]').boundingBox();
      const bar = await page.locator('[data-page-bar]').boundingBox();
      const firstLine = await page.locator('.cart-line').first().boundingBox();
      near(title.y + title.height / 2, trailing.y + trailing.height / 2, 3, 'title and count share the bar row');
      near(trailing.x + trailing.width, width - 20, 2, 'count ends at the 20px margin');
      assert(firstLine.y - (bar.y + bar.height) <= 28, `${firstLine.y - (bar.y + bar.height)}px between the bar and the first line`);
      assert((await page.textContent('[data-cart-heading-count]')).trim() === '3 artículos', 'count text');
      await page.locator('[data-remove-line]').first().click();
      await page.waitForFunction(() => document.querySelector('[data-cart-heading-count]')?.textContent.trim() === '2 artículos');
      return `h1 + "3 artículos" on one row; first line ${Math.round(firstLine.y - (bar.y + bar.height))}px under the bar; count follows removals`;
    });
    await context.close();
  }

  // ------------------------------ H01 · the arrow leaves the screen, Back undoes filters
  await report.step('D11', 'H01 the bar arrow leaves the screen; the browser Back still steps through filters (390px)', async () => {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true });
    const page = await context.newPage();
    report.trackPage(page, 'fidelity-back');
    await page.goto(`${url}/`, { waitUntil: 'networkidle' });
    await page.click('.dock [data-dock="catalog"]');
    await page.waitForURL(/\/collections\/all$/);
    await page.click('[data-page-bar] [data-open-filters]');
    await page.waitForSelector('.overlay--drawer-right.is-open');
    await page.click('.overlay--drawer-right label:has(input[value="Coach"])');
    await page.click('.overlay--drawer-right [data-apply]');
    await page.waitForURL(/filter\.p\.m\.custom\.marca=Coach/);
    const badge = (await page.textContent('[data-page-bar] .page-bar__badge')).trim();
    assert(badge === '1', `filter badge "${badge}"`);
    assert((await page.getAttribute('[data-page-bar] [data-open-filters]', 'aria-label')).includes('1 activo'), 'filters label does not announce the count');
    await page
      .waitForFunction(() => document.activeElement?.hasAttribute('data-open-filters'), null, { timeout: 3000 })
      .catch(() => assert(false, 'focus did not return to the filters button after applying'));
    await page.goBack();
    await page.waitForURL((current) => current.pathname === '/collections/all' && !current.search);
    await page.goForward();
    await page.waitForURL(/marca=Coach/);
    await page.click('[data-page-bar] .page-bar__back');
    await page.waitForURL((current) => current.pathname === '/');
    await page.goto(`${url}/collections/guess`, { waitUntil: 'networkidle' });
    await page.click('[data-page-bar] .page-bar__back');
    await page.waitForURL((current) => current.pathname === '/');
    await page.goto(`${url}/collections/totes`, { waitUntil: 'networkidle' });
    await page.click('[data-page-bar] .page-bar__back');
    await page.waitForURL((current) => current.pathname === '/collections/guess');
    await context.close();
    return 'Home → catálogo → filter: Back undoes the filter and Forward restores it; the arrow returns to Home; a deep link goes to its parent (Home, or Bolsas for a style)';
  });

  // ------------------------------------------------ H01 · wide layouts unchanged
  for (const [width, height] of [
    [768, 1024],
    [1024, 768],
    [1440, 900],
  ]) {
    await report.step('D11', `H01 collection, search and bag @ ${width}px keep the global header, breadcrumbs and title row`, async () => {
      const context = await browser.newContext({ viewport: { width, height } });
      await seedCart(context, demoCartLines());
      const page = await context.newPage();
      report.trackPage(page, `fidelity-wide-${width}`);
      const notes = [];
      for (const path of ['/collections/guess', '/search?q=bolsa&type=product', '/cart']) {
        await page.goto(`${url}${path}`, { waitUntil: 'networkidle' });
        assert(await page.locator('.site-header').isVisible(), `${path}: global header hidden`);
        assert(await page.locator('.site-nav').isVisible(), `${path}: category navigation hidden`);
        assert(!(await page.locator('.page-bar__back').first().isVisible()), `${path}: phone back arrow visible`);
        assert(!(await page.locator('.page-bar__actions').first().isVisible()), `${path}: phone actions visible`);
        const title = await style(page, 'main h1', 'fontFamily', 'fontSize');
        assert(title.fontFamily.startsWith('"Playfair Display"') && px(title.fontSize) >= 30, `${path}: title ${JSON.stringify(title)}`);
        if (path !== '/cart') assert(await page.locator('.breadcrumbs').first().isVisible(), `${path}: breadcrumbs hidden`);
        const position = await style(page, '.page-bar, main h1', 'position');
        assert(position.position !== 'sticky', `${path}: the title row is pinned`);
        // Below 1200 the toolbar's "Filtrar y ordenar" button is the way in; the sidebar replaces it above.
        if (path.startsWith('/collections') && width < 1200) assert(await page.locator('.toolbar [data-open-filters]').isVisible(), `${path}: filters button missing from the toolbar`);
        notes.push(`${path.split('?')[0]} ${title.fontSize}`);
      }
      await context.close();
      return `title row only (Playfair ${notes.join(', ')})`;
    });
  }

  // ------------------------------------------------------ H02 · product header
  for (const [width, height] of PHONES) {
    await report.step('D11', `H02 product header @ ${width}px: back + search · logo · account + bag`, async () => {
      const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 2, hasTouch: true });
      const page = await context.newPage();
      report.trackPage(page, `fidelity-product-${width}`);
      await page.goto(`${url}/products/bolso-coach-shoulder-negro-rectangular`, { waitUntil: 'networkidle' });
      const controls = await visibleControls(page, '.site-header a, .site-header button');
      const labels = controls.map((control) => control.label);
      assert(
        labels.length === 5 && labels[0] === 'Volver' && labels[1] === 'Buscar productos' && labels[2] === 'Monetta, ir al inicio' && labels[3] === 'Cuenta' && labels[4].startsWith('Carrito'),
        `header controls: ${labels.join(' | ')}`,
      );
      const [back, search, logo, account, bag] = controls;
      for (const control of [back, search, account, bag]) assert(control.width >= TAP && control.height >= TAP, `${control.label} is ${control.width}×${control.height}`);
      near(logo.x + logo.width / 2, width / 2, 1, 'logo centre');
      assert(search.href === '/search' && account.href === '/account', `links ${search.href}, ${account.href}`);
      assert(back.x < search.x && search.x < logo.x && logo.x < account.x && account.x < bag.x, 'controls are not in app order');
      near(back.x, 4, 1, 'left edge inset');
      near(bag.x + bag.width, width - 4, 1, 'right edge inset');
      assert(!(await page.locator('[data-action="menu"]').isVisible()), 'the menu still takes the search position');
      return `${labels.join(' · ')}; logo centred (${Math.round(logo.x + logo.width / 2)} of ${width / 2}); 4px edge insets`;
    });
  }

  await report.step('D11', 'H02 the product header search and account links work (390px)', async () => {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true });
    const page = await context.newPage();
    report.trackPage(page, 'fidelity-product-links');
    await page.goto(`${url}/products/bolso-coach-shoulder-negro-rectangular`, { waitUntil: 'networkidle' });
    await page.click('.site-header__search-start');
    await page.waitForURL(/\/search$/);
    await page.waitForFunction(() => document.activeElement?.id === 'page-search-input');
    await page.goBack();
    await page.waitForURL(/\/products\//);
    await page.click('.site-header .header-utility--account');
    await page.waitForURL(/\/account$/);
    assert((await page.textContent('main h1')).trim().length > 0, 'account page has no heading');
    await context.close();
    return 'search opens the search field focused; account opens the account entry (Shopify handoff)';
  });

  for (const [width, height] of [
    [768, 1024],
    [1440, 900],
  ]) {
    await report.step('D11', `H02 product header @ ${width}px keeps the tablet/desktop navigation`, async () => {
      const context = await browser.newContext({ viewport: { width, height } });
      const page = await context.newPage();
      report.trackPage(page, `fidelity-product-wide-${width}`);
      await page.goto(`${url}/products/bolso-coach-shoulder-negro-rectangular`, { waitUntil: 'networkidle' });
      const labels = (await visibleControls(page, '.site-header a, .site-header button')).map((control) => control.label);
      assert(!(await page.locator('.site-header__search-start').isVisible()), 'the phone-only search link is visible');
      assert(await page.locator('.header-utility--account').isVisible(), 'account missing');
      assert(await page.locator('.header-utility--favorites').isVisible(), 'favourites missing');
      assert(await page.locator('#header-search-input').isVisible(), 'header search field missing');
      if (width < 1024) assert(await page.locator('.site-header__menu').isVisible(), 'tablet menu missing');
      await context.close();
      return labels.join(' · ');
    });
  }

  // ------------------------------------------------------ H03 · recommendations
  for (const [width, height] of PHONES) {
    const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 2, hasTouch: true });
    const page = await context.newPage();
    report.trackPage(page, `fidelity-recs-${width}`);
    // Two views so that "Vistas hace un momento" has something to show.
    await page.goto(`${url}/products/bolso-coach-shoulder-negro-rectangular`, { waitUntil: 'networkidle' });
    await page.goto(`${url}/products/bolso-michael-kors-marilyn-medium-signature-convertible-satchel-vanilla-rosa`, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);

    await report.step('D11', `H03 recommendations @ ${width}px: section headings are the serif section-title role (23/400)`, async () => {
      const notes = [];
      for (const id of ['#product-more', '#product-recent', '#product-reviews']) {
        const heading = await style(page, id, 'fontFamily', 'fontSize', 'fontWeight');
        assert(heading.fontFamily.startsWith('"Playfair Display"') && heading.fontSize === '23px' && heading.fontWeight === '400', `${id}: ${JSON.stringify(heading)}`);
        notes.push(`${id.slice(1)} ${heading.fontSize}/${heading.fontWeight}`);
      }
      const rendered = await platformFonts(page, '#product-more');
      assert(rendered.length && rendered.every((name) => name.startsWith('Playfair Display') && name.includes('web font')), `renderer used ${rendered.join(', ')}`);
      return `${notes.join(', ')}; renderer: ${rendered.join(', ')}`;
    });

    await report.step('D11', `H03 recommendations @ ${width}px: tiles 52vw wide, 4:5 photo flush on the warm tile, two-line names`, async () => {
      const notes = [];
      for (const id of ['#rail-more', '#rail-recent']) {
        const cards = await page.$$eval(`${id} .card`, (nodes) =>
          nodes.map((node) => {
            const media = node.querySelector('.card__media');
            const name = node.querySelector('.card__name');
            const mediaRect = media.getBoundingClientRect();
            const nameStyle = getComputedStyle(name);
            return {
              width: node.getBoundingClientRect().width,
              height: node.getBoundingClientRect().height,
              mediaWidth: mediaRect.width,
              ratio: mediaRect.width / mediaRect.height,
              margin: getComputedStyle(media).marginLeft,
              ground: getComputedStyle(media).backgroundColor,
              clamp: nameStyle.webkitLineClamp,
              lines: Math.round(name.getBoundingClientRect().height / Number.parseFloat(nameStyle.lineHeight)),
            };
          }),
        );
        assert(cards.length > 0, `${id} has no cards`);
        const heights = cards.map((card) => card.height);
        assert(Math.max(...heights) - Math.min(...heights) <= 1, `${id} tiles are not equally tall: ${heights.map((height) => Math.round(height)).join(', ')}`);
        for (const card of cards) {
          near(card.width, Math.min(width * 0.52, 260), 1.5, `${id} tile width`);
          near(card.ratio, 0.8, 0.01, `${id} photo ratio`);
          assert(card.margin === '0px' && card.mediaWidth >= card.width - 2, `${id} photo is inset (margin ${card.margin}, ${card.mediaWidth} of ${card.width})`);
          // The photo has no ground of its own: it multiplies over the card's warm tile (--color-surface-tile).
          assert(card.ground === 'rgba(0, 0, 0, 0)', `${id} photo ground ${card.ground}`);
          assert(card.clamp === '2' && card.lines <= 2, `${id} name clamp ${card.clamp}, ${card.lines} lines`);
        }
        notes.push(`${id.slice(1)}: ${cards.length} tiles ${Math.round(cards[0].width)}px, ratio ${cards[0].ratio.toFixed(2)}, ${Math.max(...cards.map((card) => card.lines))} name lines`);
      }
      assert((await page.$$eval('#rail-more .card__name', (nodes) => nodes.some((node) => node.getBoundingClientRect().height > Number.parseFloat(getComputedStyle(node).lineHeight) * 1.5))), 'no recommendation name wraps to two lines');
      return notes.join('; ');
    });

    await report.step('D11', `H03 Home @ ${width}px keeps the Playfair heading and the compact rail tiles`, async () => {
      await page.goto(`${url}/`, { waitUntil: 'networkidle' });
      const heading = await style(page, '#home-novedades', 'fontFamily', 'fontSize', 'fontWeight');
      assert(heading.fontFamily.startsWith('"Playfair Display"') && heading.fontSize === '23px' && heading.fontWeight === '400', `Novedades ${JSON.stringify(heading)}`);
      const card = await page.$eval('#rail-novedades .card', (node) => {
        const media = node.querySelector('.card__media').getBoundingClientRect();
        return { width: node.getBoundingClientRect().width, ratio: media.width / media.height, clamp: getComputedStyle(node.querySelector('.card__name')).webkitLineClamp };
      });
      near(card.width, Math.min(Math.max(width * 0.36, 132), 190), 1.5, 'compact tile width');
      near(card.ratio, 1, 0.01, 'compact photo ratio');
      assert(card.clamp === '1', `compact name clamp ${card.clamp}`);
      return `Novedades Playfair 23/400; tile ${Math.round(card.width)}px, square photo, one-line name`;
    });
    await context.close();
  }

  await report.step('D11', 'H03 recommendations from tablet up: serif headings step to 27/30 and the tiles keep the 4:5 anatomy', async () => {
    const notes = [];
    for (const [width, height, size, visible] of [
      [768, 1024, '27px', null],
      [1024, 768, '30px', 4],
      [1440, 900, '30px', 5],
    ]) {
      const context = await browser.newContext({ viewport: { width, height } });
      const page = await context.newPage();
      report.trackPage(page, `fidelity-recs-${width}`);
      await page.goto(`${url}/products/bolso-michael-kors-marilyn-medium-signature-convertible-satchel-vanilla-rosa`, { waitUntil: 'networkidle' });
      const heading = await style(page, '#product-more', 'fontFamily', 'fontSize', 'fontWeight');
      assert(heading.fontFamily.startsWith('"Playfair Display"') && heading.fontSize === size && heading.fontWeight === '400', `${width}px heading ${JSON.stringify(heading)}`);
      const rail = await page.$eval('#rail-more', (track) => {
        const bounds = track.getBoundingClientRect();
        const cards = [...track.querySelectorAll('.card')];
        const heights = cards.map((card) => card.getBoundingClientRect().height);
        return {
          inside: cards.filter((card) => card.getBoundingClientRect().right <= bounds.right + 1).length,
          ratio: cards[0].querySelector('.card__media').getBoundingClientRect().width / cards[0].querySelector('.card__media').getBoundingClientRect().height,
          unevenness: Math.max(...heights) - Math.min(...heights),
        };
      });
      near(rail.ratio, 0.8, 0.01, `${width}px photo ratio`);
      assert(rail.unevenness <= 1, `${width}px tiles differ in height by ${rail.unevenness}px`);
      if (visible) assert(rail.inside === visible, `${width}px shows ${rail.inside} whole tiles, expected ${visible}`);
      notes.push(`${width}px ${heading.fontSize}${visible ? `, ${rail.inside} tiles` : ''}`);
      await context.close();
    }
    return notes.join(' · ');
  });
}
