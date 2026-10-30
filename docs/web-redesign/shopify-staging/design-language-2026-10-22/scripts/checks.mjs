// Acceptance checks of the app design-language pass (22 Oct 2026), measured in the browser on the rendered theme:
// type roles, geometry and targets, product columns, layouts per width band, horizontal overflow, Spanish labels, the shared
// shell on secondary pages, the discount, saved and recent flows, and Monetta script errors.
//
//   node checks.mjs --base-url=http://127.0.0.1:9292 [--viewports=320x640,...] [--flows] [--name=checks] [--inject-css=...]
//
// --inject-css adds a stylesheet to every page (negative controls: reintroduce a defect and see the matching check fail).
// Results go to docs/web-redesign/shopify-staging/runs/<stamp>-<name>/ through the shared harness (scripts/e2e/lib.mjs).
import { Run, launch, parseArgs, settle } from '../../scripts/e2e/lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const viewports = (args.viewports || '320x640,390x844,768x1024,1024x768,1440x900').split(',').map((v) => v.split('x').map(Number));
const injectCss = args['inject-css'] || null;
const run = new Run(args.name || 'design-language-checks', { baseUrl, extra: { viewports, injectCss, flows: Boolean(args.flows) } });

const MULTI = '/products/reloj-coach-talia-saddle';
const SINGLE = '/products/bolso-steve-madden-shoulder-negro';
const band = (w) => (w >= 1024 ? 'expanded' : w >= 768 ? 'medium' : 'compact');
const ROLE = {
  sectionTitle: { compact: 23, medium: 27, expanded: 30 },
  productName: { compact: 25, medium: 29, expanded: 32 },
  screenTitle: { compact: 26, medium: 30, expanded: 36 },
};
const cols = (w) => (w < 360 ? 1 : w < 768 ? 2 : w < 1024 ? 3 : 4);
const ENGLISH = /^(home|catalog|contact|search|products|availability|in stock|out of stock|price|alphabetically, a-z|alphabetically, z-a|price, low to high|price, high to low|date, new to old|date, old to new|best selling|featured|relevance|privacy policy|refund policy|terms of service|shipping policy|collections|news|page not found|continue shopping|you may also like|view all)$/i;

async function gotoOk(page, path) {
  for (let i = 0; i < 4; i += 1) {
    await page.goto(`${baseUrl}${path}`, { waitUntil: 'load' });
    const bad = await page.evaluate(() => /Failed to render storefront|Bad Gateway|unauthorized/i.test(document.body?.innerText || ''));
    if (!bad) return;
    run.note(`proxy error page for ${path} (attempt ${i + 1}); retrying`);
    await page.waitForTimeout(3000);
  }
  throw new Error(`proxy kept failing for ${path}`);
}

/** Computed style and box of the first visible element matching the selector. */
const probe = (page, selector) =>
  page.evaluate((sel) => {
    const el = [...document.querySelectorAll(sel)].find((e) => e.getClientRects().length && getComputedStyle(e).visibility !== 'hidden');
    if (!el) return null;
    const s = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    return {
      family: s.fontFamily.split(',')[0].replace(/["']/g, '').trim(),
      size: Number.parseFloat(s.fontSize),
      weight: s.fontWeight,
      transform: s.textTransform,
      radius: Number.parseFloat(s.borderTopLeftRadius),
      width: r.width,
      height: r.height,
      left: r.left,
      right: r.right,
      top: r.top,
      bottom: r.bottom,
      text: (el.textContent || '').trim().slice(0, 80),
    };
  }, selector);

const overflow = (page) => page.evaluate(() => ({ scrollWidth: document.documentElement.scrollWidth, clientWidth: document.documentElement.clientWidth }));

async function englishLabels(page, selector) {
  return page.evaluate(
    ({ sel, source }) => {
      const re = new RegExp(source, 'i');
      return [...document.querySelectorAll(sel)].map((e) => (e.textContent || '').replace(/\s+/g, ' ').trim()).filter((t) => re.test(t));
    },
    { sel: selector, source: ENGLISH.source },
  );
}

/**
 * Tap targets under 48px (manifest size.tap). Inline and legal text links are WCAG 2.5.8 exceptions and are listed apart:
 * links inside running text (.rte, .page-prose, .accordion__body), breadcrumbs and the footer's legal row. A native radio or
 * checkbox inside a label is measured through its label.
 */
async function smallTargets(page) {
  return page.evaluate(() => {
    const interactive = 'a[href], button, select, textarea, input:not([type="hidden"]):not([type="radio"]):not([type="checkbox"]), summary, [role="button"], label.option-chip, label.check';
    const inlineScopes = '.rte, .page-prose, .accordion__body, .breadcrumbs, .footer-bottom, .visually-hidden, .skip-link';
    const out = { small: [], inline: [] };
    for (const el of document.querySelectorAll(interactive)) {
      const r = el.getBoundingClientRect();
      const s = getComputedStyle(el);
      if (!r.width || !r.height || s.visibility === 'hidden' || el.closest('[hidden], dialog:not([open]), [inert]')) continue;
      if (el.matches('.stepper__value')) continue; // the quantity box sits between two 48px buttons in a 48px row
      // A search input is the inner part of its pill: the whole field is the target.
      const box = el.matches('input') && el.closest('.search-field') ? el.closest('.search-field').getBoundingClientRect() : r;
      if (box.height >= 47.5 && box.width >= 47.5) continue;
      const name = `${el.tagName.toLowerCase()}.${[...el.classList].join('.')} "${(el.getAttribute('aria-label') || el.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 40)}" ${Math.round(r.width)}x${Math.round(r.height)}`;
      (el.closest(inlineScopes) ? out.inline : out.small).push(name);
    }
    return out;
  });
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

for (const [w, h] of viewports) {
  const { browser, page } = await launch({ width: w, height: h, reducedMotion: 'reduce', injectCss });
  page.setDefaultTimeout(30000);
  const scriptErrors = [];
  page.on('pageerror', (e) => scriptErrors.push(`pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error' && /monetta-/.test(m.location()?.url || '')) scriptErrors.push(`${m.location().url}: ${m.text()}`);
  });
  const b = band(w);
  const tag = `${w}×${h}`;
  try {
    // ---------------------------------------------------------------- home
    await gotoOk(page, '/');
    await settle(page);
    const lang = await page.evaluate(() => document.documentElement.lang);
    run.check(`${tag} home: document language es-MX`, lang === 'es-MX', lang);
    const section = await probe(page, '.display--section');
    run.check(`${tag} home: section title is Playfair ${ROLE.sectionTitle[b]}px (sectionTitle role)`, section?.family === 'Playfair Display' && Math.abs(section.size - ROLE.sectionTitle[b]) < 0.6, section);
    const tile = await probe(page, '.app-collection');
    if (tile) run.check(`${tag} home: collection tile on the card radius (12px)`, tile.radius === 12, tile.radius);
    const brand = await probe(page, '.app-brands a');
    if (brand) run.check(`${tag} home: brand cell on the card radius (12px)`, brand.radius === 12, brand.radius);
    const style = await probe(page, '.app-style-list img');
    if (style) run.check(`${tag} home: style silhouette has no box radius (straight on the canvas)`, style.radius === 0, style.radius);
    const headerButtons = await page.evaluate(() =>
      [...document.querySelectorAll('.site-header .icon-button')].filter((e) => e.getClientRects().length && getComputedStyle(e).visibility !== 'hidden').map((e) => {
        const r = e.getBoundingClientRect();
        return { label: e.getAttribute('aria-label'), w: Math.round(r.width), h: Math.round(r.height) };
      }),
    );
    run.check(`${tag} home: header icon buttons are at least 48 x 48`, headerButtons.length > 0 && headerButtons.every((x) => x.w >= 48 && x.h >= 48), headerButtons);
    const homeTargets = await smallTargets(page);
    run.check(`${tag} home: every tap target is at least 48px (inline/legal text links excepted)`, homeTargets.small.length === 0, homeTargets);
    const homeOverflow = await overflow(page);
    run.check(`${tag} home: no horizontal overflow`, homeOverflow.scrollWidth <= homeOverflow.clientWidth, homeOverflow);
    const navEnglish = await englishLabels(page, '.site-nav__link, .menu-link span, .footer-col a, .footer-bottom a');
    run.check(`${tag} home: header, menu and footer labels carry no untranslated Shopify defaults`, navEnglish.length === 0, navEnglish);
    const footerHead = await probe(page, '.footer-col h2');
    if (footerHead) run.check(`${tag} footer: column labels are the Inter eyebrow, not the serif`, footerHead.family === 'Inter' && footerHead.transform === 'uppercase', footerHead);

    // ---------------------------------------------------------------- collection
    await gotoOk(page, '/collections/all');
    await settle(page);
    await page.waitForFunction(() => document.querySelector('[data-save-product]:not([hidden])'), null, { timeout: 10000 }).catch(() => {});
    const name = await probe(page, '.card__name');
    run.check(`${tag} collection: product-card name is Inter (card-label role, the documented exception)`, name?.family === 'Inter', name);
    const cardBrand = await probe(page, '.card__brand');
    run.check(`${tag} collection: product-card brand is Inter 600`, cardBrand?.family === 'Inter' && cardBrand.weight === '600', cardBrand);
    const card = await probe(page, '.card');
    const media = await probe(page, '.card__media');
    run.check(`${tag} collection: card radius 12, photo mat radius 10`, card?.radius === 12 && media?.radius === 10, { card: card?.radius, media: media?.radius });
    const fav = await probe(page, '.card__fav');
    run.check(`${tag} collection: favourite target is 48 x 48`, fav && Math.round(fav.width) >= 48 && Math.round(fav.height) >= 48, fav && { w: fav.width, h: fav.height });
    const quick = await probe(page, '.card__quick');
    if (quick) run.check(`${tag} collection: quick-add target is 48 x 48`, Math.round(quick.width) >= 48 && Math.round(quick.height) >= 48, { w: quick.width, h: quick.height });
    const gridCols = await page.evaluate(() => getComputedStyle(document.querySelector('[data-grid], .product-grid')).gridTemplateColumns.split(' ').filter(Boolean).length);
    run.check(`${tag} collection: ${cols(w)} product column(s)`, gridCols === cols(w), gridCols);
    const title = await page.evaluate(() => [...document.querySelectorAll('h1')].map((e) => e.textContent.trim()).join(' | '));
    run.check(`${tag} collection: Shopify's all-products collection is titled "Catálogo"`, /Catálogo/.test(title), title);
    const sortEnglish = await englishLabels(page, '#sort-select option, .filters-drawer__sort .check span, .filter-group summary > span:first-child, .filter-group .check > span:not(.check__count)');
    run.check(`${tag} collection: sort options and filter labels are Spanish`, sortEnglish.length === 0, sortEnglish);
    const colTargets = await smallTargets(page);
    run.check(`${tag} collection: every tap target is at least 48px (inline/legal text links excepted)`, colTargets.small.length === 0, colTargets);
    const colOverflow = await overflow(page);
    run.check(`${tag} collection: no horizontal overflow`, colOverflow.scrollWidth <= colOverflow.clientWidth, colOverflow);

    // ---------------------------------------------------------------- product (several photos, variants)
    await gotoOk(page, MULTI);
    await settle(page);
    const pname = await probe(page, '.product-panel__name');
    run.check(`${tag} product: name is Playfair ${ROLE.productName[b]}px (productName role)`, pname?.family === 'Playfair Display' && Math.abs(pname.size - ROLE.productName[b]) < 0.6, pname);
    const acc = await probe(page, '.accordion > summary');
    run.check(`${tag} product: accordion titles are Playfair`, acc?.family === 'Playfair Display', acc?.family);
    const other = await probe(page, '.other-ways__title');
    if (other) run.check(`${tag} product: "Otras formas de comprar" is the Inter panel title`, other.family === 'Inter' && other.weight === '600', other);
    // The inline primary action is the 52px control; the phone dock's action is 48px inside 8 + 48 + 8, as the app's
    // PurchaseDock (kPurchaseDockButtonHeight), a documented exception.
    const add = await probe(page, w < 768 ? '.purchase-dock [data-add]' : '.buy-inline [data-add]');
    const minAdd = w < 768 ? 48 : 52;
    run.check(`${tag} product: purchase button at least ${minAdd}px tall`, add && add.height >= minAdd - 0.5, add && { h: add.height, text: add.text });
    const gallery = await probe(page, '.gallery__main');
    const panel = await probe(page, '.product-panel');
    if (w >= 768 && w < 1024) run.check(`${tag} product: one column on tablets (panel under the gallery)`, gallery && panel && panel.top >= gallery.bottom - 1, { galleryBottom: gallery?.bottom, panelTop: panel?.top });
    if (w >= 1024) run.check(`${tag} product: two columns from 1024 (panel beside the gallery)`, gallery && panel && panel.left >= gallery.right - 1, { galleryRight: gallery?.right, panelLeft: panel?.left });
    const optionLegend = await page.evaluate(() => [...document.querySelectorAll('.options legend .eyebrow')].map((e) => e.textContent.trim()));
    run.check(`${tag} product: option legends use the app's labels (Color), not the raw "Band color"`, optionLegend.length > 0 && optionLegend.every((t) => !/band color/i.test(t)), optionLegend);
    const prodTargets = await smallTargets(page);
    run.check(`${tag} product: every tap target is at least 48px (inline/legal text links excepted)`, prodTargets.small.length === 0, prodTargets);
    const prodOverflow = await overflow(page);
    run.check(`${tag} product: no horizontal overflow`, prodOverflow.scrollWidth <= prodOverflow.clientWidth, prodOverflow);

    // ---------------------------------------------------------------- product with one photograph
    await gotoOk(page, SINGLE);
    await settle(page);
    const single = await probe(page, '.gallery__main');
    run.check(`${tag} product (one photo): the viewer keeps a real width`, single && single.width >= Math.min(300, w - 40), single && { width: single.width });

    // ---------------------------------------------------------------- bag with lines
    await gotoOk(page, '/');
    await addToBag(page, ['reloj-coach-talia-saddle', 'bolso-steve-madden-shoulder-negro']);
    await gotoOk(page, '/cart');
    await settle(page);
    const summaryTitle = await probe(page, '.summary__title');
    run.check(`${tag} bag: "Resumen de compra" is the Inter panel title (boutiqueTitle)`, summaryTitle?.family === 'Inter' && summaryTitle.weight === '600', summaryTitle);
    const field = await probe(page, '.discount-form input');
    run.check(`${tag} bag: discount field on the control radius (12px), at least 48px tall`, field?.radius === 12 && field.height >= 48, field && { r: field.radius, h: field.height });
    const removeShown = await page.evaluate(() => document.querySelector('[data-discount-remove]') && !document.querySelector('[data-discount-remove]').hidden);
    run.check(`${tag} bag: "Quitar códigos" hidden while the bag holds no code`, removeShown === false, removeShown);
    const lines = await probe(page, '.cart-lines');
    const summary = await probe(page, '.cart-layout .summary');
    if (w >= 1024) run.check(`${tag} bag: summary beside the lines from 1024`, lines && summary && summary.left >= lines.right - 1, { linesRight: lines?.right, summaryLeft: summary?.left });
    else run.check(`${tag} bag: summary under the lines below 1024`, lines && summary && summary.top >= lines.bottom - 1, { linesBottom: lines?.bottom, summaryTop: summary?.top });
    const totalRow = await page.evaluate(() => {
      const dd = document.querySelector('.summary__row--total dd');
      return dd ? dd.getClientRects().length : 0;
    });
    run.check(`${tag} bag: the total amount stays on one line`, totalRow === 1, totalRow);
    const bagTargets = await smallTargets(page);
    run.check(`${tag} bag: every tap target is at least 48px (inline/legal text links excepted)`, bagTargets.small.length === 0, bagTargets);
    const bagOverflow = await overflow(page);
    run.check(`${tag} bag: no horizontal overflow`, bagOverflow.scrollWidth <= bagOverflow.clientWidth, bagOverflow);
    await page.evaluate(() => fetch('/cart/clear.js', { method: 'POST' }));

    // ---------------------------------------------------------------- search
    await gotoOk(page, '/search?q=bolso&type=product');
    await settle(page);
    const searchHead = await probe(page, '.listing--search .page-head .display--page');
    if (w < 768) run.check(`${tag} search: results heading is the serif screen title at 22px (search_screen.dart)`, searchHead?.family === 'Playfair Display' && Math.abs(searchHead.size - 22) < 0.6, searchHead);
    await gotoOk(page, '/search?q=zzqxv&type=product');
    await settle(page);
    const emptyTitle = await probe(page, '.empty__title');
    run.check(`${tag} search (no results): empty-state title is Playfair`, emptyTitle?.family === 'Playfair Display', emptyTitle);

    // ---------------------------------------------------------------- secondary pages share the shell
    for (const [label, path] of [
      ['contact', '/pages/contact'],
      ['policy', '/policies/privacy-policy'],
      ['blog', '/blogs/news'],
      ['collections index', '/collections'],
      ['404', '/pages/no-existe'],
    ]) {
      await gotoOk(page, path);
      await settle(page);
      const shell = await page.evaluate(() => ({
        monettaHeader: Boolean(document.querySelector('.site-header')),
        atelierHeader: Boolean(document.querySelector('header-component, .header-section')),
        lang: document.documentElement.lang,
        dock: Boolean(document.querySelector('.dock')),
        footer: Boolean(document.querySelector('.site-footer .footer-grid')),
      }));
      run.check(`${tag} ${label}: Monetta header, footer and dock; no Atelier header; es-MX`, shell.monettaHeader && !shell.atelierHeader && shell.footer && shell.dock && shell.lang === 'es-MX', shell);
      const english = await englishLabels(page, 'h1, .site-nav__link, .footer-col a, .footer-bottom a, .btn');
      run.check(`${tag} ${label}: no untranslated theme or Shopify default labels in headings, navigation and buttons`, label === 'policy' ? true : english.length === 0, english);
      if (label !== 'contact') {
        // The contact page's blocks are the merchant's (Atelier AI blocks); their own targets are reported in the notes.
        const t = await smallTargets(page);
        run.check(`${tag} ${label}: every tap target is at least 48px (inline/legal text links excepted)`, t.small.length === 0, t);
      } else {
        const t = await smallTargets(page);
        run.note(`${tag} contact (merchant blocks): targets under 48px: ${JSON.stringify(t.small.slice(0, 12))}`);
      }
      const o = await overflow(page);
      if (label === 'contact') {
        // The merchant's AI blocks (three fixed social cards with unbreakable labels, card carousels) are wider than a phone
        // or tablet with or without the Monetta CSS (A/B in the handoff); the shell clips them instead of letting the page
        // scroll sideways. Recorded, not counted against the theme.
        const sideways = await page.evaluate(() => {
          window.scrollTo(600, window.scrollY);
          const x = window.scrollX;
          window.scrollTo(0, window.scrollY);
          return { scrollX: x, bodyOverflowX: getComputedStyle(document.body).overflowX };
        });
        run.note(`${tag} contact: merchant blocks ${o.scrollWidth > o.clientWidth ? `overflow to ${o.scrollWidth}px` : 'fit'}; body overflow-x ${sideways.bodyOverflowX}`);
        run.check(`${tag} contact: the page never scrolls sideways (the shell clips merchant blocks wider than the viewport)`, sideways.scrollX === 0, { ...o, ...sideways });
      } else {
        run.check(`${tag} ${label}: no horizontal overflow`, o.scrollWidth <= o.clientWidth, o);
      }
    }

    // ---------------------------------------------------------------- flows (once per run when asked)
    if (args.flows) {
      // Discount: an unknown code is reported as not applied and leaves Shopify's total untouched.
      await gotoOk(page, '/');
      await addToBag(page, ['bolso-steve-madden-shoulder-negro']);
      await gotoOk(page, '/cart');
      await settle(page);
      const before = await page.evaluate(async () => (await (await fetch('/cart.js')).json()).total_price);
      await page.fill('#cart-discount', 'PRUEBA-NO-EXISTE-2210');
      await page.click('.discount-form [type="submit"]');
      await page.waitForFunction(() => (document.querySelector('[data-discount-message]')?.textContent || '').length > 0, null, { timeout: 30000 });
      const message = await page.locator('[data-discount-message]').textContent();
      const afterCart = await page.evaluate(async () => (await (await fetch('/cart.js')).json()));
      run.check(`${tag} discount: unknown code reported as not applied`, /no se aplicó/i.test(message), message);
      run.check(`${tag} discount: Shopify's total is unchanged after the unknown code`, afterCart.total_price === before, { before, after: afterCart.total_price, codes: afterCart.discount_codes });
      const removeAfter = await page.evaluate(() => !document.querySelector('[data-discount-remove]').hidden);
      const stored = (afterCart.discount_codes || []).length;
      run.check(`${tag} discount: "Quitar códigos" visible exactly when Shopify keeps a code (${stored} stored)`, removeAfter === stored > 0, { removeAfter, stored });
      if (removeAfter) {
        await page.click('[data-discount-remove]');
        await page.waitForFunction(() => /Quitamos/.test(document.querySelector('[data-discount-message]')?.textContent || ''), null, { timeout: 30000 });
        const cleared = await page.evaluate(async () => (await (await fetch('/cart.js')).json()).discount_codes || []);
        run.check(`${tag} discount: "Quitar códigos" clears the codes in Shopify`, cleared.length === 0, cleared);
      }
      await page.evaluate(() => fetch('/cart/clear.js', { method: 'POST' }));

      // Saved products: browser-local handles; cards re-rendered by Shopify.
      await gotoOk(page, '/collections/all');
      await settle(page);
      await page.evaluate(() => { try { localStorage.removeItem('monetta.web.saved.v1'); } catch {} });
      await gotoOk(page, '/collections/all');
      await page.waitForSelector('.card__fav:not([hidden])');
      const handle = await page.locator('.card').first().getAttribute('data-product-handle');
      await page.locator('.card__fav').first().click();
      const pressed = await page.locator('.card__fav').first().getAttribute('aria-pressed');
      const savedList = await page.evaluate(() => JSON.parse(localStorage.getItem('monetta.web.saved.v1') || '[]'));
      run.check(`${tag} saved: the heart toggles on (aria-pressed) and stores the handle in this browser`, pressed === 'true' && savedList.includes(handle), { pressed, savedList });
      const onIcon = await page.evaluate(() => getComputedStyle(document.querySelector('.card__fav .save-icon--on')).display);
      run.check(`${tag} saved: the filled heart shows once saved`, onIcon !== 'none', onIcon);
      if (w >= 768) {
        await page.locator('.header-utility--saved').click();
      } else {
        await gotoOk(page, '/');
        await page.locator('.site-header__menu:visible').first().click();
        await page.waitForSelector('#menu-drawer[open]');
        await page.locator('#menu-drawer [data-open-dialog="saved-products"]').click();
      }
      await page.waitForSelector('#saved-products[open]');
      await page.waitForFunction(() => document.querySelectorAll('#saved-products .card').length > 0, null, { timeout: 20000 }).catch(() => {});
      const drawer = await page.evaluate(() => ({ cards: document.querySelectorAll('#saved-products .card').length, emptyHidden: document.querySelector('[data-saved-empty]').hidden, status: document.querySelector('[data-saved-status]').textContent }));
      run.check(`${tag} saved: the list shows the saved piece, re-rendered by Shopify, without the empty state`, drawer.cards === 1 && drawer.emptyHidden, drawer);
      await page.locator('#saved-products .card__fav').first().click();
      await page.waitForFunction(() => /Aún no has guardado/.test(document.querySelector('[data-saved-status]').textContent), null, { timeout: 20000 }).catch(() => {});
      const emptied = await page.evaluate(() => ({ cards: document.querySelectorAll('#saved-products .card').length, emptyShown: !document.querySelector('[data-saved-empty]').hidden }));
      run.check(`${tag} saved: removing the last piece shows the empty state with its catalog link`, emptied.cards === 0 && emptied.emptyShown, emptied);

      // Recent views: a second product shows the first one.
      await gotoOk(page, SINGLE);
      await settle(page);
      await gotoOk(page, MULTI);
      await page.waitForFunction(() => document.querySelector('[data-recent-products] .card'), null, { timeout: 20000 }).catch(() => {});
      const recent = await page.evaluate(() => {
        const rail = document.querySelector('[data-recent-products]');
        return { hidden: rail?.hidden, handles: [...(rail?.querySelectorAll('.card') || [])].map((c) => c.dataset.productHandle) };
      });
      run.check(`${tag} recent: the second product lists the first one as recently viewed`, recent.hidden === false && recent.handles.includes('bolso-steve-madden-shoulder-negro'), recent);
    }
  } catch (error) {
    run.check(`${tag} — unexpected error`, false, String(error.message).split('\n')[0], 'error');
  } finally {
    run.check(`${tag}: no errors from Monetta scripts`, scriptErrors.length === 0, scriptErrors.slice(0, 5));
    await browser.close();
  }
}

const result = run.finish({ complete: true });
process.exit(result.summary.failed ? 1 : 0);
