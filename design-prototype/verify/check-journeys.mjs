// D05–D08 — observable shopping behaviour in a real browser: search, filters,
// URLs and Back, cards and favourites, quick view, variant continuity, the
// local cart with pending protection, handoffs, failures and phone controls.
import { assert, product } from './report.mjs';

async function cartCount(page) {
  return page.evaluate(() => {
    const badge = document.querySelector('.site-header [data-cart-count]') ?? document.querySelector('[data-cart-count]');
    return badge && !badge.hidden ? Number(badge.textContent.replace('+', '')) : 0;
  });
}

async function setDemo(page, key, value) {
  await page.click('.proto-strip__button');
  await page.waitForSelector('.overlay.is-open #demo-' + key);
  const box = page.locator('#demo-' + key);
  if ((await box.isChecked()) !== value) await box.click();
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => !document.querySelector('.overlay'));
}

export async function checkJourneys({ browser, url, report }) {
  const desk = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await desk.newPage();
  report.trackPage(page, 'journeys-desktop');
  const go = (path) => page.goto(`${url}${path}`, { waitUntil: 'networkidle' });

  // ---------------------------------------------------------------- Discovery
  await go('/');
  await report.step('D06', 'Predictive search shows products and suggestions while typing', async () => {
    await page.click('#header-search-input');
    await page.keyboard.type('coach', { delay: 30 });
    await page.waitForSelector('#header-search-listbox .search-option__product');
    const options = await page.locator('#header-search-listbox [role="option"]').count();
    assert(options >= 3, `only ${options} options`);
    await page.keyboard.press('ArrowDown');
    const active = await page.getAttribute('#header-search-input', 'aria-activedescendant');
    assert(active, 'ArrowDown did not set aria-activedescendant');
    await page.keyboard.press('Escape');
    assert((await page.getAttribute('#header-search-input', 'aria-expanded')) === 'false', 'Escape did not close the listbox');
    return `${options} options; keyboard active descendant ${active}`;
  });

  await report.step('D06', 'Enter carries the query to the results route', async () => {
    await page.click('#header-search-input');
    await page.keyboard.press('Enter');
    await page.waitForURL(/\/search\?q=coach&type=product$/);
    const heading = await page.textContent('main h1');
    const count = await page.textContent('[data-count]');
    assert(/coach/i.test(heading), heading);
    assert(Number.parseInt(count, 10) > 0, count);
    return `${heading} · ${count}`;
  });

  let unfiltered = '';
  await report.step('D06', 'Sidebar filter and sort update URL, count and chips together', async () => {
    unfiltered = await page.textContent('[data-count]');
    await page.check('.filter-sidebar input[data-facet="category"][value="Reloj"]');
    await page.waitForURL(/filter\.p\.m\.custom\.categoria=Reloj/);
    const filtered = await page.textContent('[data-count]');
    assert(Number.parseInt(filtered, 10) < Number.parseInt(unfiltered, 10), `${filtered} vs ${unfiltered}`);
    assert(await page.locator('.active-chips .chip--removable', { hasText: 'Relojes' }).isVisible(), 'chip missing');
    await page.selectOption('#sort-select', 'price-ascending');
    await page.waitForURL(/sort_by=price-ascending/);
    const prices = await page.$$eval('[data-grid] .card__price .price', (nodes) => nodes.slice(0, 4).map((node) => Number(node.textContent.replace(/[^\d.]/g, ''))));
    for (let index = 1; index < prices.length; index += 1) assert(prices[index - 1] <= prices[index], `not ascending: ${prices}`);
    return `${unfiltered} → ${filtered}; first prices ${prices.join(', ')}`;
  });

  await report.step('D06', 'Browser Back restores the previous sort, then the unfiltered results', async () => {
    await page.goBack();
    await page.waitForURL((current) => !current.search.includes('sort_by'));
    assert((await page.inputValue('#sort-select')) === 'relevance', 'sort not restored');
    assert(await page.isChecked('.filter-sidebar input[value="Reloj"]'), 'filter lost on first Back');
    await page.goBack();
    await page.waitForURL(/\/search\?q=coach&type=product$/);
    assert(!(await page.isChecked('.filter-sidebar input[value="Reloj"]')), 'filter still checked');
    assert((await page.textContent('[data-count]')) === unfiltered, 'count not restored');
    return 'two Back steps restore sort and filter state';
  });

  await report.step('D06', 'An impossible filter offers recovery that works', async () => {
    await go('/collections/relojes?filter.v.availability=0');
    assert((await page.textContent('.empty__title')).includes('Sin resultados'), 'no empty state');
    await page.click('.empty a:has-text("Limpiar filtros")');
    await page.waitForURL(/\/collections\/relojes$/);
    const cards = await page.locator('[data-grid] .card').count();
    assert(cards > 0, 'no cards after clearing');
    return `${cards} watches after "Limpiar filtros"`;
  });

  await report.step('D06', 'Load more keeps its page in the URL and Back returns to the same spot', async () => {
    await go('/collections/all');
    assert((await page.locator('[data-grid] .card').count()) === 24, 'first page is not 24');
    await page.click('[data-more]');
    await page.waitForURL(/page=2/);
    assert((await page.locator('[data-grid] .card').count()) === 48, 'second page not appended');
    const target = page.locator('[data-grid] .card').nth(40);
    await target.scrollIntoViewIfNeeded();
    const before = await page.evaluate(() => window.scrollY);
    await target.locator('.card__link').click();
    await page.waitForURL(/\/products\//);
    await page.goBack();
    await page.waitForURL(/page=2/);
    await page.waitForTimeout(200);
    const after = await page.evaluate(() => window.scrollY);
    assert((await page.locator('[data-grid] .card').count()) === 48, 'Back lost the loaded page');
    assert(Math.abs(after - before) < 120, `scroll ${before} → ${after}`);
    return `48 cards and scroll ${Math.round(before)} → ${Math.round(after)}`;
  });

  // ------------------------------------------------------------- Cards (D05)
  await report.step('D05', 'Cards show genuine sale, sold-out and sobre-pedido states', async () => {
    await go('/collections/guess-1');
    const sale = page.locator('[data-product="bolso-guess-crossbody-negro-1"]');
    assert(await sale.locator('.badge--sale').isVisible(), 'sale badge missing');
    assert((await sale.locator('.price-compare').textContent()) === '$1,899.00', 'compare-at missing');
    const soldOut = page.locator('[data-product="bolsa-guess-shoulder-vino-brillante"]');
    assert(await soldOut.locator('.card__soldout').isVisible(), 'sold-out seal missing');
    assert((await soldOut.locator('[data-action="quick-add"]').count()) === 0, 'sold-out card offers quick add');
    await go('/collections/coach');
    const eyebrow = await page.locator('.card__eyebrow').first().textContent();
    assert(eyebrow === 'Sobre pedido', eyebrow);
    return 'sale −10% with $1,899.00, sold-out seal without “+”, “Sobre pedido” eyebrow';
  });

  await report.step('D05', 'Long names stay complete in the DOM and clamp to two lines', async () => {
    await go('/collections/michael-kors');
    const card = page.locator('[data-product="bolso-michael-kors-marilyn-medium-signature-convertible-satchel-vanilla-rosa"] .card__name');
    const info = await card.evaluate((node) => ({ text: node.textContent, lines: Math.round(node.getBoundingClientRect().height / Number.parseFloat(getComputedStyle(node).lineHeight)) }));
    assert(info.text === 'Bolso Michael Kors Marilyn Medium Signature Convertible Satchel Crossbody', info.text);
    assert(info.lines <= 2, `${info.lines} lines`);
    return `${info.text.length} characters, ${info.lines} lines`;
  });

  await report.step('D05', 'Guest favourites toggle on cards and list on the favourites page', async () => {
    await go('/collections/coach');
    const heart = page.locator('[data-product="bolso-coach-station-tote-bag-negro"] [data-action="favorite"]');
    await heart.click();
    assert((await heart.getAttribute('aria-pressed')) === 'true', 'not pressed');
    await go('/pages/favoritos');
    assert(await page.locator('[data-product="bolso-coach-station-tote-bag-negro"]').isVisible(), 'not listed');
    assert((await page.textContent('[data-favorites] .notice')).includes('solo en este dispositivo'), 'scope notice missing');
    await page.click('[data-product="bolso-coach-station-tote-bag-negro"] [data-action="favorite"]');
    await page.waitForSelector('[data-favorites] .empty');
    return 'saved, listed with device-scope notice, removed to empty state';
  });

  // -------------------------------------------------- Variant continuity (D05)
  const coach = product('bolso-coach-shoulder-negro-rectangular');
  const cafe = coach.variants.find((variant) => variant.title === 'Café');
  await report.step('D05', 'Quick view requires a choice and hands the same variant to the product page', async () => {
    await go('/collections/coach');
    await page.click(`[data-product="${coach.handle}"] [data-action="quick-add"]`);
    await page.waitForSelector('.overlay--sheet.is-open');
    assert((await page.getAttribute('.overlay--sheet [data-add]', 'aria-disabled')) === 'true', 'add enabled without a choice');
    await page.click('.overlay--sheet .option-chip:has-text("Café")');
    const href = await page.getAttribute('.overlay--sheet [data-details]', 'href');
    assert(href.endsWith(`?variant=${cafe.id}`), href);
    await page.click('.overlay--sheet [data-details]');
    await page.waitForURL(new RegExp(`variant=${cafe.id}`));
    assert(await page.isChecked(`input[name="variant-${coach.id}"][value="${cafe.id}"]`), 'Café not selected on the product page');
    return href;
  });

  // ---------------------------------------------------------- Cart (D07)
  await report.step('D07', 'Two rapid clicks add one unit, with visible pending feedback', async () => {
    const button = page.locator('#add-inline');
    await button.click();
    await button.click({ force: true });
    const pending = await page.locator('#add-inline [data-label]').textContent();
    await page.waitForSelector('.overlay--drawer-right.is-open .cart-line');
    const quantity = await page.textContent('.overlay--drawer-right .stepper__value');
    assert(pending === 'Agregando…', `pending label "${pending}"`);
    assert(quantity.trim() === '1', `quantity ${quantity}`);
    assert((await page.textContent('.overlay--drawer-right .cart-line__variant')).includes('Café'), 'variant label missing');
    assert((await cartCount(page)) === 1, 'header count is not 1');
    const live = await page.textContent('#status-live');
    assert(live.includes('Agregado al carrito'), `live region: ${live}`);
    return `pending “${pending}”, quantity ${quantity.trim()}, announced “${live}”`;
  });

  await report.step('D07', 'Drawer quantity, removal and undo update the cart', async () => {
    await page.click('.overlay--drawer-right [data-step="1"]');
    await page.waitForFunction(() => document.querySelector('.overlay--drawer-right .stepper__value')?.textContent.trim() === '2');
    assert((await cartCount(page)) === 2, 'count not 2');
    await page.click('.overlay--drawer-right [data-remove-line]');
    await page.waitForSelector('.overlay--drawer-right .cart-drawer__empty');
    await page.click('.toast__action');
    await page.waitForSelector('.overlay--drawer-right .cart-line');
    assert((await cartCount(page)) === 2, 'undo did not restore quantity 2');
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => !document.querySelector('.overlay'));
    const focused = await page.evaluate(() => document.activeElement?.id);
    assert(focused === 'add-inline', `focus returned to ${focused}`);
    return 'quantity 1→2, removed, undone, focus back on “Agregar al carrito”';
  });

  await report.step('D07', 'Checkout explains the Shopify handoff and creates nothing', async () => {
    await go('/cart');
    await page.click('.summary [data-checkout]');
    await page.waitForSelector('.overlay--dialog.is-open');
    const text = await page.textContent('.overlay--dialog');
    assert(text.includes('No se creó ningún pedido'), 'no handoff statement');
    assert(text.includes(String(cafe.id)), 'variant id not listed');
    await page.keyboard.press('Escape');
    return 'dialog lists the exact variant and states no order or payment';
  });

  await report.step('D07', 'An emptied cart recovers to the store', async () => {
    while ((await page.locator('.cart-lines [data-remove-line]').count()) > 0) {
      await page.locator('.cart-lines [data-remove-line]').first().click();
    }
    await page.waitForSelector('#cart-empty');
    await page.click('.empty a:has-text("Volver a la tienda")');
    await page.waitForURL(/\/collections\/all\?sort_by=created-descending/);
    return 'empty state → Novedades';
  });

  await report.step('D07', 'A failed add explains the error beside the control and keeps the cart', async () => {
    await setDemo(page, 'failNextAdd', true);
    await go('/products/bolso-guess-crossbody-negro-1');
    await page.click('#add-inline');
    await page.waitForSelector('[data-add-error]:not([hidden])');
    const message = await page.textContent('[data-add-error]');
    assert(message.includes('No pudimos agregar'), message);
    assert((await cartCount(page)) === 0, 'cart changed after failure');
    await page.click('#add-inline');
    await page.waitForSelector('.overlay--drawer-right.is-open .cart-line');
    await page.keyboard.press('Escape');
    return `“${message.trim()}”, retry succeeds`;
  });

  await report.step('D06', 'Suggestions can fail without blocking search', async () => {
    await setDemo(page, 'searchError', true);
    await page.click('#header-search-input');
    await page.fill('#header-search-input', 'tote');
    await page.waitForSelector('[data-search-panel] [data-retry]');
    await page.keyboard.press('Enter');
    await page.waitForURL(/\/search\?q=tote/);
    assert((await page.locator('[data-grid] .card').count()) > 0, 'no results');
    await setDemo(page, 'searchError', false);
    return 'error with “Reintentar”, Enter still opens results';
  });

  await report.step('D05', 'Sobre pedido, sold-out and apartado states are honest', async () => {
    await go(`/products/${coach.handle}`);
    assert((await page.textContent('[data-availability]')).includes('Sobre pedido'), 'sobre pedido missing');
    await page.click('[data-apartado]');
    await page.waitForSelector('.overlay--dialog.is-open .message-preview');
    const dialog = await page.textContent('.overlay--dialog');
    assert(dialog.includes('no aparta la pieza ni cobra nada'), 'apartado promise wording');
    assert(dialog.includes('no reserva inventario'), 'message wording');
    await page.keyboard.press('Escape');
    await go('/products/bolsa-guess-shoulder-vino-brillante');
    assert((await page.textContent('#add-inline [data-label]')) === 'Agotado', 'sold-out button label');
    assert((await page.getAttribute('#add-inline', 'aria-disabled')) === 'true', 'sold-out button enabled');
    return 'sobre pedido line, manual apartado without reservation, disabled “Agotado”';
  });

  await report.step('D05', 'Blocked storage keeps favourites usable for the visit and says so', async () => {
    await setDemo(page, 'storageBlocked', true);
    await go('/pages/favoritos');
    const notice = await page.textContent('[data-favorites] .notice');
    assert(notice.includes('no permite guardar'), notice);
    await setDemo(page, 'storageBlocked', false);
    return notice.trim();
  });
  await desk.close();

  // ------------------------------------------------------------ Phone (D08)
  const phone = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, hasTouch: true });
  const mobile = await phone.newPage();
  report.trackPage(mobile, 'journeys-phone');
  const visible = (selector) =>
    mobile.evaluate((query) => {
      const element = document.querySelector(query);
      return Boolean(element) && getComputedStyle(element).display !== 'none' && element.getBoundingClientRect().height > 0;
    }, selector);

  await report.step('D08', 'Phone home: dock visible, search icon appears after the hero search scrolls away', async () => {
    await mobile.goto(`${url}/`, { waitUntil: 'networkidle' });
    assert(await visible('.dock'), 'dock hidden');
    assert(!(await visible('.site-header__search-icon')), 'header search visible over hero search');
    await mobile.evaluate(() => window.scrollTo(0, 600));
    await mobile.waitForFunction(() => !document.querySelector('.site-header__search-icon').hidden);
    return 'dock + search handover';
  });

  await report.step('D08', 'Typing hides the dock so the keyboard never stacks controls', async () => {
    await mobile.goto(`${url}/search`, { waitUntil: 'networkidle' });
    await mobile.click('#page-search-input');
    await mobile.keyboard.type('tote', { delay: 20 });
    const transform = await mobile.evaluate(() => getComputedStyle(document.querySelector('.dock')).transform);
    assert(transform !== 'none', 'dock not moved while typing');
    await mobile.waitForSelector('#page-search-listbox .search-option__product');
    await mobile.keyboard.press('Enter');
    await mobile.waitForURL(/q=tote/);
    return `dock transform while typing: ${transform}`;
  });

  await report.step('D08', 'Product: purchase dock replaces the nav dock; the add sheet covers both', async () => {
    await mobile.goto(`${url}/products/bolsa-juicy-couture-hobo-rosa`, { waitUntil: 'networkidle' });
    assert(await visible('.purchase-dock'), 'purchase dock hidden');
    assert(!(await visible('.dock')), 'nav dock also visible');
    await mobile.click('.purchase-dock [data-add]');
    await mobile.waitForSelector('.overlay--sheet.is-open');
    assert((await mobile.getAttribute('#page', 'inert')) !== null, 'page behind the sheet is not inert');
    await mobile.click('.overlay--sheet a[href="/cart"]');
    await mobile.waitForURL(/\/cart$/);
    assert(await visible('.checkout-bar'), 'checkout bar hidden');
    assert(!(await visible('.dock')) && !(await visible('.purchase-dock')), 'another bottom control is visible');
    return 'purchase dock → sheet (page inert) → cart with checkout bar only';
  });

  await report.step('D06', 'Phone filter drawer previews the count and applies to the URL', async () => {
    await mobile.goto(`${url}/collections/guess`, { waitUntil: 'networkidle' });
    await mobile.click('[data-open-filters]');
    await mobile.waitForSelector('.overlay--drawer-right.is-open');
    await mobile.click('.overlay--drawer-right label:has(input[value="Coach"])');
    const label = await mobile.textContent('.overlay--drawer-right [data-apply]');
    assert(/Ver \d+ piezas?/.test(label), label);
    await mobile.click('.overlay--drawer-right [data-apply]');
    await mobile.waitForURL(/filter\.p\.m\.custom\.marca=Coach/);
    assert(await mobile.locator('.active-chips .chip--removable', { hasText: 'Coach' }).isVisible(), 'chip missing');
    await mobile.goBack();
    await mobile.waitForURL(/\/collections\/guess$/);
    return `${label.trim()} → applied → Back removes it`;
  });

  await report.step('D09', 'Menu drawer traps focus, closes on Escape and restores focus', async () => {
    await mobile.goto(`${url}/`, { waitUntil: 'networkidle' });
    await mobile.focus('[data-action="menu"]');
    await mobile.keyboard.press('Enter');
    await mobile.waitForSelector('.overlay--drawer-left.is-open');
    for (let index = 0; index < 25; index += 1) await mobile.keyboard.press('Tab');
    const inside = await mobile.evaluate(() => Boolean(document.activeElement?.closest('.overlay')));
    assert(inside, 'focus escaped the menu');
    await mobile.keyboard.press('Escape');
    await mobile.waitForFunction(() => !document.querySelector('.overlay'));
    const restored = await mobile.evaluate(() => document.activeElement?.dataset.action);
    assert(restored === 'menu', `focus returned to ${restored}`);
    return '25 Tabs stayed inside; Escape restored focus to the menu button';
  });
  await phone.close();
}
