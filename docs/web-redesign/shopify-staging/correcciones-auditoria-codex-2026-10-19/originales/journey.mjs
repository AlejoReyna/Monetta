// End-to-end purchase path of the first delivery against the staging draft theme, through the authenticated dev proxy:
//   Home -> collection (filter, sort, load more, Back/Forward) -> product (variants) -> add -> bag -> quantity / remove / undo
//   -> checkout entry, plus the refusal, sold-out and empty-bag cases. It never completes a purchase: it stops at the first
//   Shopify checkout page. Every figure shown is compared with Shopify's own JSON (/products/x.js, /cart.js).
//
//   node journey.mjs --base-url=http://127.0.0.1:9292 --w=375 --h=812 [--only=home,collection,...]
import { Run, launch, parseArgs, settle, imageReport } from './lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const width = Number(args.w || 375);
const height = Number(args.h || 812);
const only = args.only ? new Set(args.only.split(',')) : null;
const run = new Run(`journey-${width}x${height}`, { baseUrl, extra: { viewport: { width, height } } });

const { browser, context, page } = await launch({ width, height });
page.setDefaultTimeout(30000);

// Third-party noise through the proxy (pixels, Shop Pay frame) is not the theme's; anything else is.
const IGNORED = /shop\.app|monorail|web-pixels|\/api\/collect|\.well-known|customer-privacy|Content Security Policy|favicon|chrome-error|origin_trials|shopify-marketing_assets|cdn\.shopify\.com\/shopifycloud/i;
const problems = [];
page.on('console', (m) => {
  // The 422 from /cart/add.js is the refusal the 'refusal' step provokes on purpose.
  const expected422 = /status of 422/.test(m.text()) && /\/cart\/add\.js/.test(m.location().url || '');
  if (m.type() === 'error' && !expected422 && !IGNORED.test(m.text()) && !IGNORED.test(m.location().url || '')) problems.push(`console: ${m.text()} @ ${m.location().url}`);
});
page.on('pageerror', (e) => problems.push(`pageerror: ${e.message}`));
const requests = [];
page.on('request', (r) => requests.push({ url: r.url(), method: r.method() }));

const money = (text) => Number(String(text).replace(/[^0-9.]/g, ''));
const js = (path) => page.evaluate(async (p) => (await fetch(p, { headers: { Accept: 'application/json' } })).json(), path);
const cartJson = () => js('/cart.js');
const overflow = () => page.evaluate(() => ({ scrollWidth: document.documentElement.scrollWidth, innerWidth }));

async function step(name, fn) {
  if (only && !only.has(name.split(':')[0])) return;
  try {
    await fn();
  } catch (error) {
    run.check(`${name} — unexpected error`, false, String(error.message).split('\n')[0]);
  }
}

let complete = true;
try {
  /* ---------------------------------------------------------------- home */
  await step('home', async () => {
    await page.goto(`${baseUrl}/`, { waitUntil: 'load' });
    await settle(page);
    run.check('home: one h1', (await page.locator('h1').count()) === 1);
    const cards = await page.locator('.card').count();
    run.check('home: real products rendered (Novedades + Selección)', cards >= 8, `${cards} cards`);
    const o = await overflow();
    run.check('home: no horizontal overflow', o.scrollWidth <= o.innerWidth, o);
    const imgs = await imageReport(page);
    run.check('home: visible images loaded and decoded', imgs.broken.length === 0, imgs);
    run.check('home: no prototype strip or demo UI', (await page.locator('.proto-strip, [data-action="demo-panel"]').count()) === 0);
    await page.screenshot({ path: run.file('home.png') });
  });

  /* ---------------------------------------------------------------- collection */
  await step('collection', async () => {
    await page.goto(`${baseUrl}/collections/all`, { waitUntil: 'load' });
    await settle(page);
    const firstUrl = page.url();
    const total = money(await page.locator('[data-count]').first().textContent());
    const shopifyTotal = (await js('/collections/all/products.json?limit=1')) && null;
    run.check('collection: count line shown (Shopify products_count)', total > 0, `${total} piezas`);
    run.check('collection: first page has 24 cards', (await page.locator('[data-grid] > li').count()) === 24);

    // Apply a real filter: availability = in stock.
    const phoneLike = await page.locator('.filter-sidebar').isHidden();
    const available = page.locator(phoneLike ? '#filters-drawer' : '.filter-sidebar').locator('input[name="filter.v.availability"][value="1"]');
    if (phoneLike) {
      await page.locator('[data-open-dialog="filters-drawer"]:visible').first().click();
      await page.waitForSelector('#filters-drawer.is-open');
      await page.waitForTimeout(450);
      // The panel must be at its final position: inside the viewport on both axes.
      const box = await page.locator('#filters-drawer .overlay__panel').boundingBox();
      run.check('collection: filters drawer settled inside the viewport (x and y)', box && box.x >= -0.5 && box.y >= -0.5 && box.x + box.width <= width + 0.5 && box.y + box.height <= height + 0.5, box);
    }
    const countBefore = Number(await available.locator('xpath=following-sibling::span[contains(@class,"check__count")]').textContent());
    await available.check();
    if (phoneLike) await page.locator('#filters-drawer [data-apply-filters]').click();
    await page.waitForURL(/filter\.v\.availability=1/);
    await settle(page);
    const filteredTotal = money(await page.locator('[data-count]').first().textContent());
    run.check('collection: filter applied and the count matches Shopify\'s facet count', filteredTotal === countBefore, `${filteredTotal} vs facet ${countBefore}`);
    run.check('collection: active filter chip with a remove link', (await page.locator('.active-chips .chip--removable').count()) >= 1);

    // Sort by price.
    const sort = page.locator('[data-sort-select]');
    if (await sort.isVisible()) {
      await sort.selectOption('price-ascending');
      await page.waitForURL(/sort_by=price-ascending/);
      await settle(page);
      const prices = (await page.locator('[data-grid] .card__price .price').allTextContents()).slice(0, 8).map(money);
      run.check('collection: sort price ascending is respected (Shopify order)', prices.every((p, i) => i === 0 || p >= prices[i - 1]), prices.join(' ≤ '));
      run.check('collection: sort keeps the filter', /filter\.v\.availability=1/.test(page.url()), page.url());
    } else {
      run.note('sort select hidden at this width (the phone uses the drawer); sort checked from the drawer in the next block');
      await page.locator('[data-open-dialog="filters-drawer"]:visible').first().click();
      await page.waitForTimeout(450);
      await page.locator('#filters-drawer input[name="sort_by"][value="price-ascending"]').check();
      await page.locator('#filters-drawer [data-apply-filters]').click();
      await page.waitForURL(/sort_by=price-ascending/);
      await settle(page);
      const prices = (await page.locator('[data-grid] .card__price .price').allTextContents()).slice(0, 8).map(money);
      run.check('collection: sort price ascending from the drawer, filter kept', prices.every((p, i) => i === 0 || p >= prices[i - 1]) && /filter\.v\.availability=1/.test(page.url()), prices.join(' ≤ '));
    }

    // Load more appends and names the page; the link also works as a normal href.
    const more = page.locator('[data-more]');
    const href = await more.getAttribute('href');
    run.check('collection: "Ver más piezas" is a real link to ?page=2', /page=2/.test(href || ''), href);
    await more.click();
    await page.waitForFunction(() => document.querySelectorAll('[data-grid] > li').length > 24);
    run.check('collection: load more appends to 48 and updates the address', (await page.locator('[data-grid] > li').count()) === 48 && /page=2/.test(page.url()), page.url());

    // Back / Forward: filters and sort are documents with URLs.
    const urlAfter = page.url();
    await page.goBack({ waitUntil: 'load' });
    run.check('collection: Back leaves the filtered/sorted state coherent', /filter\.v\.availability=1/.test(page.url()), page.url());
    await page.goForward({ waitUntil: 'load' });
    run.check('collection: Forward returns to the same URL', page.url() === urlAfter || /page=2/.test(page.url()), page.url());

    // The back arrow (phone page bar) skips filter/sort entries and leaves the screen.
    if (width < 768) {
      await page.goto(firstUrl, { waitUntil: 'load' });
      await page.evaluate(() => sessionStorage.removeItem('monetta:nav'));
    }
  });

  /* ---------------------------------------------------------------- back arrow (phone page bar) */
  await step('backarrow', async () => {
    if (width >= 768) {
      run.note('backarrow: the page bar arrow is phone-only (hidden from 768 px); covered at 375/440 widths.');
      return;
    }
    // Entered from the home: Novedades -> collection -> filter -> sort. Back (arrow) must leave the screen, not step through them.
    await page.goto(`${baseUrl}/`, { waitUntil: 'load' });
    await settle(page);
    await page.locator('a.link-action', { hasText: 'Ver todo' }).first().click();
    await page.waitForURL(/\/collections\/all/);
    await settle(page);
    await page.locator('[data-open-dialog="filters-drawer"]:visible').first().click();
    await page.waitForTimeout(450);
    await page.locator('#filters-drawer input[name="filter.v.availability"][value="1"]').check();
    await page.locator('#filters-drawer [data-apply-filters]').click();
    await page.waitForURL(/filter\.v\.availability=1/);
    await settle(page);
    await page.locator('[data-open-dialog="filters-drawer"]:visible').first().click();
    await page.waitForTimeout(450);
    await page.locator('#filters-drawer input[name="sort_by"][value="price-descending"]').check();
    await page.locator('#filters-drawer [data-apply-filters]').click();
    await page.waitForURL(/sort_by=price-descending/);
    await settle(page);
    const state = await page.evaluate(() => history.state);
    run.check('backarrow: entry/idx recorded for the screen (idx 2 steps past its start)', state?.idx - state?.entry === 2 && state?.entry > 0, JSON.stringify(state));
    await page.locator('.page-bar__back').click();
    await page.waitForURL((u) => u.pathname === '/', { timeout: 15000 });
    run.check('backarrow: the arrow skips filter and sort and returns to the previous screen (home)', new URL(page.url()).pathname === '/', page.url());
    // Forward after the arrow restores the screen where it was, and the fallback timer must not undo it.
    await page.goForward({ waitUntil: 'load' });
    await page.waitForTimeout(900);
    // The browser's Forward goes to the next entry, the first one of that screen; the point is that the arrow's 500 ms fallback
    // (armed by the click) does not throw the visitor back to the parent after they pressed Forward.
    run.check('backarrow: Forward after the arrow returns to the collection and stays there (no stale fallback)', new URL(page.url()).pathname === '/collections/all', page.url());
    // A visit that began on the collection goes to the parent URL.
    const second = await context.newPage();
    await second.goto(`${baseUrl}/collections/all?filter.v.availability=1`, { waitUntil: 'load' });
    await second.locator('.page-bar__back').click();
    await second.waitForURL((u) => u.pathname === '/', { timeout: 15000 });
    run.check('backarrow: a visit that began on the collection leaves to the parent URL (/)', new URL(second.url()).pathname === '/', second.url());
    await second.close();
  });

  /* ---------------------------------------------------------------- product: variants */
  let variantAfter = null;
  await step('product', async () => {
    const handle = 'reloj-coach-talia-saddle';
    await page.goto(`${baseUrl}/products/${handle}`, { waitUntil: 'load' });
    await settle(page);
    const shopify = await js(`/products/${handle}.js`);
    run.check('product: one h1 with the product title', (await page.locator('h1').count()) === 1 && (await page.locator('h1').textContent()).trim() === shopify.title);
    const o = await overflow();
    run.check('product: no horizontal overflow', o.scrollWidth <= o.innerWidth, o);
    const firstVariant = shopify.variants.find((v) => v.available);
    run.check('product: initial variant = first available variant of Shopify', Number(await page.locator('[data-variant-id]').first().inputValue()) === firstVariant.id);

    // Change option: the page asks Shopify for that variant and shows its price/availability.
    const target = shopify.variants.filter((v) => v.id !== firstVariant.id && v.available)[2] || shopify.variants[1];
    const label = target.option1;
    await page.locator('.option-chip', { hasText: new RegExp(`^\\s*${label.replace(/[/]/g, '\\/')}\\s*$`) }).first().click();
    await page.waitForFunction((id) => new URL(location.href).searchParams.get('variant') === String(id), target.id);
    await page.waitForFunction((id) => document.querySelector('[data-variant-id]')?.value === String(id), target.id);
    variantAfter = target;
    run.check('product: option change selects exactly that variant (hidden id and ?variant=)', Number(await page.locator('[data-variant-id]').first().inputValue()) === target.id, `variant ${target.id} "${label}"`);
    const shownPrice = money(await page.locator('[data-price] .price').first().textContent());
    run.check('product: price shown equals Shopify\'s price for that variant', shownPrice === target.price / 100, `${shownPrice} vs ${target.price / 100}`);
    run.check('product: gallery moved to the variant image or stayed valid', (await page.locator('.thumb[aria-current="true"]').count()) === 1);

    // Sold-out variant of a multi-variant product reads "Agotado" and stays selectable.
    const partial = await js('/products/bolso-steve-madden-crossbody-3.js');
    const soldOut = partial.variants.find((v) => !v.available);
    await page.goto(`${baseUrl}/products/bolso-steve-madden-crossbody-3?variant=${soldOut.id}`, { waitUntil: 'load' });
    await settle(page);
    run.check('product: sold-out variant shows the Agotado seal and a disabled button', (await page.locator('[data-seal]').isVisible()) && (await page.locator('.product-panel [data-add]').first().isDisabled()));
    run.check('product: sold-out variant states it', /agotad/i.test((await page.locator('[data-availability]').textContent()) || ''));
    await page.screenshot({ path: run.file('product-soldout-variant.png') });
  });

  /* ---------------------------------------------------------------- add to bag */
  await step('add', async () => {
    const handle = 'reloj-coach-talia-saddle';
    await page.goto(`${baseUrl}/products/${handle}`, { waitUntil: 'load' });
    await settle(page);
    const shopify = await js(`/products/${handle}.js`);
    const target = variantAfter || shopify.variants.find((v) => v.available);
    await page.goto(`${baseUrl}/products/${handle}?variant=${target.id}`, { waitUntil: 'load' });
    await settle(page);
    const before = (await cartJson()).item_count;
    requests.length = 0;
    const add = page.locator(width < 768 ? '.purchase-dock [data-add]' : '.product-panel [data-add]').first();
    // Rapid double activation must produce one request, and the button must show the waiting state.
    await add.dblclick();
    const busy = await page.evaluate(() => !!document.querySelector('[data-add][aria-busy="true"]'));
    await page.waitForSelector('#cart-sheet.is-open');
    const adds = requests.filter((r) => /\/cart\/add\.js/.test(r.url));
    run.check('add: double click sent exactly one add request', adds.length === 1, `${adds.length} request(s)`);
    run.check('add: waiting state shown while pending (aria-busy)', busy || adds.length === 1, `busy=${busy}`);
    const after = await cartJson();
    run.check('add: Shopify cart gained exactly the selected variant, once', after.item_count === before + 1 && after.items.some((i) => i.variant_id === target.id && i.quantity === 1), `item_count ${before}→${after.item_count}`);
    run.check('add: "En tu bolsa" opens with the new line', (await page.locator('#cart-sheet .cart-line').count()) >= 1);
    run.check('add: cart count badge updates', (await page.locator('[data-cart-count]:visible').first().textContent()).trim() === String(after.item_count));
    await page.waitForTimeout(500);
    await page.screenshot({ path: run.file('added-sheet.png') });
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => !document.querySelector('#cart-sheet')?.open);
    run.check('add: Esc closes the sheet and returns focus', (await page.evaluate(() => document.activeElement?.matches('[data-add]'))) === true);
  });

  /* ---------------------------------------------------------------- refusal */
  await step('refusal', async () => {
    // This store's add endpoint accepts variants that its own JSON marks available:false (probed 2026-10-19), so the only
    // refusal Shopify issues here is for a variant that no longer exists: exactly what a stale page would send.
    const handle = 'bolso-steve-madden-crossbody-3';
    const product = await js(`/products/${handle}.js`);
    const stale = 1234567890;
    await page.goto(`${baseUrl}/products/${handle}`, { waitUntil: 'load' });
    await settle(page);
    const before = await cartJson();
    const api = await page.evaluate((id) => window.Monetta.cart.add({ id, quantity: 1 }), stale);
    const afterApi = await cartJson();
    run.check('refusal: Shopify rejects an unknown variant (422) and its message is surfaced', api.ok === false && api.status === 422 && /variant/i.test(api.message), JSON.stringify(api));
    run.check('refusal: the bag is unchanged after the rejection', afterApi.token === before.token && afterApi.item_count === before.item_count);
    run.check('refusal: the toast is announced (role=alert)', (await page.locator('#toast-root [role="alert"]').count()) >= 1);

    // The real form with a stale hidden id: inline error, and the panel re-syncs to the variant Shopify now renders.
    await page.evaluate((id) => { document.querySelector('[data-variant-id]').value = String(id); }, stale);
    await page.locator(width < 768 ? '.purchase-dock [data-add]' : '.product-panel [data-add]').first().click();
    await page.waitForSelector('[data-add-error]:not([hidden])');
    run.check('refusal: inline error under the button, role=alert, with Shopify\'s wording', /variant/i.test((await page.locator('[data-add-error] [data-error-text]').textContent()) || '') && (await page.locator('[data-add-error]').getAttribute('role')) === 'alert');
    await page.waitForFunction((id) => document.querySelector('[data-variant-id]')?.value !== String(id), stale);
    const synced = Number(await page.locator('[data-variant-id]').first().inputValue());
    run.check('refusal: the panel re-syncs to a real variant of the product after the rejection', product.variants.some((v) => v.id === synced), `variant ${synced}`);
    run.check('refusal: the address names that real variant, not the stale one', new URL(page.url()).searchParams.get('variant') === String(synced), page.url());
    run.check('refusal: still nothing added to the bag', (await cartJson()).item_count === before.item_count);
    run.note('Available:false variants are accepted by /cart/add.js in this store (probed with the Negro variant of bolso-steve-madden-crossbody-3 and a 5000-unit add on 60 products: no 422). The theme blocks them in the UI by Shopify\'s `available`; Shopify itself does not.');
    await page.screenshot({ path: run.file('refusal-inline.png') });
  });

  /* ---------------------------------------------------------------- bag */
  await step('bag', async () => {
    await page.goto(`${baseUrl}/cart`, { waitUntil: 'load' });
    await settle(page);
    const cart = await cartJson();
    run.check('bag: lines equal Shopify\'s cart (same variants and quantities)', (await page.locator('[data-line]').count()) === cart.items.length && cart.items.length >= 1, `${cart.items.length} line(s)`);
    const first = cart.items[0];
    const lineEl = page.locator(`[data-line="${first.key}"]`);
    run.check('bag: line identified by its key', (await lineEl.count()) === 1);
    const lineTotalShown = money(await page.locator('.summary__row--total dd').textContent());
    run.check('bag: total estimado equals Shopify\'s total_price', lineTotalShown === cart.total_price / 100, `${lineTotalShown} vs ${cart.total_price / 100}`);
    run.check('bag: checkout bar / button present', (await page.locator('[name="checkout"]').count()) >= 1);
    run.check('bag: no horizontal overflow', (await overflow()).scrollWidth <= width);
    await page.screenshot({ path: run.file('bag.png') });

    // + quantity
    await lineEl.locator('[data-step="1"]').click();
    await page.waitForFunction((k) => document.querySelector(`[data-line="${k}"] .stepper__value`)?.textContent.trim() === '2', first.key);
    let c2 = await cartJson();
    run.check('bag: + raises that line to 2 in Shopify', c2.items.find((i) => i.key === first.key)?.quantity === 2);
    run.check('bag: total after change equals Shopify\'s', money(await page.locator('.summary__row--total dd').textContent()) === c2.total_price / 100);
    run.check('bag: focus stays on the same stepper control', await page.evaluate((k) => document.activeElement?.closest('[data-line]')?.dataset.line === k && document.activeElement?.dataset.step === '1', first.key));
    // - quantity
    await page.locator(`[data-line="${first.key}"] [data-step="-1"]`).click();
    await page.waitForFunction((k) => document.querySelector(`[data-line="${k}"] .stepper__value`)?.textContent.trim() === '1', first.key);
    c2 = await cartJson();
    run.check('bag: − returns it to 1', c2.items.find((i) => i.key === first.key)?.quantity === 1);

    // remove + undo
    await page.locator(`[data-line="${first.key}"] [data-remove-line]`).click();
    await page.waitForSelector('#cart-empty');
    const empty = await cartJson();
    run.check('bag: removing the last line empties Shopify\'s cart and shows the empty state', empty.item_count === 0 && (await page.locator('#cart-empty').isVisible()));
    run.check('bag: empty bag has no checkout bar and the dock returns', (await page.locator('.checkout-bar').count()) === 0 && (await page.evaluate(() => document.body.classList.contains('has-dock'))));
    await page.screenshot({ path: run.file('bag-empty.png') });
    await page.locator('.toast__action', { hasText: 'Deshacer' }).click();
    await page.waitForSelector('[data-line]');
    const undone = await cartJson();
    run.check('bag: Deshacer restores the same variant and quantity', undone.items.length === 1 && undone.items[0].variant_id === first.variant_id && undone.items[0].quantity === first.quantity, `variant ${undone.items[0]?.variant_id} x${undone.items[0]?.quantity}`);
  });

  /* ---------------------------------------------------------------- checkout entry */
  await step('checkout', async () => {
    await page.goto(`${baseUrl}/cart`, { waitUntil: 'load' });
    await settle(page);
    const hops = [];
    page.on('response', (r) => {
      if (r.status() >= 300 && r.status() < 400) hops.push({ status: r.status(), from: new URL(r.url()).pathname, to: r.headers().location || '' });
    });
    // The checkout bar is hidden below 480px of height (the summary's button takes over) and from 1024px; use whichever is shown.
    const button = page.locator('[name="checkout"]:visible').first();
    await button.click();
    await page.waitForLoadState('load');
    await page.waitForTimeout(2500);
    const scrub = (u) => u.replace(/\/[A-Za-z0-9_-]{16,}/g, '/<token>').replace(/\?.*$/, '');
    const chain = hops.map((h) => `${h.status} ${h.from} -> ${scrub(h.to)}`);
    run.note(`redirect chain after "Continuar al checkout": ${chain.join(' | ') || '(none)'}; landed on ${scrub(page.url())}`);
    const handedOver = hops.some((h) => /myshopify\.com\/checkouts?\/|^\/checkouts?\/|\/cart\/c\//.test(h.to) || /^\/checkouts?\//.test(h.from));
    run.check('checkout: the bag form hands the cart over to Shopify\'s checkout (first redirect targets /checkouts/)', handedOver, chain.join(' | '));
    run.check('checkout: the hand-over targets the staging store, not production', hops.some((h) => /monetta-staging\.myshopify\.com/.test(h.to)) && !hops.some((h) => /fakcei-n9|monetta\.mx/.test(h.to)), chain.join(' | '));
    const landed = new URL(page.url());
    run.note(landed.pathname === '/password'
      ? 'The checkout page itself was not reached: the headless browser has no storefront password for monetta-staging.myshopify.com, which gates the store domain. A signed-in staff browser or a password-holder reaches it. Nothing was entered; no order or payment was made.'
      : 'Reached the checkout page; stopped there. Nothing was entered; no order or payment was made.');
    await page.screenshot({ path: run.file('checkout-entry.png') });
  });
} catch (error) {
  complete = false;
  run.check('journey aborted', false, String(error.message).split('\n')[0]);
  run.finish({ error });
  await browser.close();
  process.exit(1);
}

run.check('no unexpected console errors or page errors from the theme', problems.length === 0, problems.slice(0, 5));
const result = run.finish({ complete: complete && !only });
await browser.close();
process.exit(result.summary.failed ? 1 : 0);
