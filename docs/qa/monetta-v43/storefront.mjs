// Runs the real sections, CSS and browser JS with a local Liquid/Ajax fixture.
// Run with MONETTA_QA_DEPS pointing to a directory with liquidjs and playwright.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';

const out = resolve(process.env.MONETTA_QA_OUT || '/tmp/monetta-v43-qa/captures');
const require = createRequire(resolve(process.env.MONETTA_QA_DEPS || '.', 'package.json'));
const { Liquid } = require('liquidjs');
const { chromium } = require('playwright');
const theme = resolve(process.env.MONETTA_QA_THEME || 'storefront-theme');

const prepare = (s) => s
  .replace(/{%-?\s*(schema|doc|stylesheet|javascript)\s*-?%}[\s\S]*?{%-?\s*end\1\s*-?%}/g, '')
  .replace(/{%-?\s*(?:end)?paginate[^%]*%}/g, '')
  .replace(/{%-?\s*style\s*-?%}/g, '<style>')
  .replace(/{%-?\s*endstyle\s*-?%}/g, '</style>')
  .replace(/{%-?\s*form 'product'[^%]*%}/g, '<form action="/cart/add" method="post" data-product-form id="{{ form_id }}">')
  .replace(/{%-?\s*form [^%]*%}/g, '<form>')
  .replace(/{%-?\s*endform\s*-?%}/g, '</form>');
const liquid = new Liquid({
  root: [resolve(theme, 'snippets'), resolve(theme, 'sections')],
  extname: '.liquid',
  relativeReference: false,
  lenientIf: true,
  fs: {
    exists: async (file) => { try { await readFile(file); return true; } catch { return false; } },
    existsSync: (file) => { try { readFileSync(file); return true; } catch { return false; } },
    readFile: async (file) => prepare(await readFile(file, 'utf8')),
    readFileSync: (file) => prepare(readFileSync(file, 'utf8')),
    resolve: (root, file, ext) => resolve(root, file.endsWith(ext) ? file : file + ext),
  },
});
liquid.registerFilter('asset_url', (file) => '/assets/' + file);
liquid.registerFilter('image_url', (image) => image?.src ?? '');
liquid.registerFilter('handleize', (value) => String(value || '').toLowerCase().replaceAll(' ', '-'));
liquid.registerFilter('url_for_vendor', (value) => '/collections/vendors?q=' + encodeURIComponent(value));
liquid.registerFilter('structured_data', () => '{}');
liquid.registerFilter('money_without_trailing_zeros', (value) => '$' + (Number(value?.amount ?? value) / 100).toLocaleString('en-US'));
liquid.registerFilter('money_with_currency', (value) => '$' + (Number(value?.amount ?? value) / 100).toLocaleString('en-US') + ' MXN');
liquid.registerFilter('placeholder_svg_tag', () => '');
liquid.registerFilter('metafield_tag', () => '');
liquid.registerFilter('payment_button', () => '');

const routes = {
  root_url: '/', cart_url: '/cart', cart_add_url: '/cart/add', cart_change_url: '/cart/change',
  all_products_collection_url: '/collections/all', collections_url: '/collections', account_url: '/account',
  account_login_url: '/account/login', storefront_login_url: '/account/login?return_to=%2Fcart',
  search_url: '/search', predictive_search_url: '/search/suggest', product_recommendations_url: '/recommendations/products',
};
const img = (id, file) => ({ id, src: '/assets/' + file, width: 640, height: 640, alt: '' });
const packshot = (id) => img(id, [
  'monetta-v41-f07.webp', 'monetta-v41-f18.webp', 'monetta-v41-f08.webp', 'monetta-v41-f05.webp',
][(id - 1) % 4]);
function makeProduct(id, handle, title, options, onSale = false) {
  const variants = options.map((option, index) => {
    const image = packshot(id + index);
    return {
      id: id * 10 + index, title: option, options: [option], available: true, matched: true,
      price: 189900 + index * 3000, compare_at_price: onSale && index === 1 ? 249900 : 0,
      featured_image: image, featured_media: image, inventory_quantity: 8,
      inventory_management: 'shopify', inventory_policy: 'deny',
    };
  });
  return {
    id, handle, title, url: '/products/' + handle, vendor: 'Monetta', type: 'Bolso', tags: ['Bolso'],
    available: true, variants, featured_image: variants[0].featured_image,
    selected_or_first_available_variant: variants[0], has_only_default_variant: options.length === 1,
    images: variants.map((v) => v.featured_image),
    media: variants.map((v) => ({ ...v.featured_media, media_type: 'image', preview_image: v.featured_image })),
  };
}
const colors = makeProduct(1, 'bolso-aurora', 'Bolso Aurora', ['Café', 'Negro'], true);
colors.variants[1].metafields = { monetta: { six_msi_amount: { value: { amount: 32200 } } } };
const single = makeProduct(3, 'cartera-luz', 'Cartera Luz', ['Default Title']);
const extras = [makeProduct(4, 'accesorio-sol', 'Accesorio Sol', ['Default Title']), makeProduct(2, 'bolso-luna', 'Bolso Luna', ['Café', 'Negro'])];
for (const variant of extras[1].variants) variant.compare_at_price = 259900;
const products = [colors, single, ...extras];
const byVariant = new Map(products.flatMap((product) => product.variants.map((variant) => [variant.id, { variant, product }])));
const makeCollection = (handle, title, items, total = items.length) => ({
  id: 90, handle, title, products: items, url: '/collections/' + handle,
  products_count: total, all_products_count: total, default_sort_by: 'manual',
  sort_options: [{ value: 'manual', name: 'Destacados' }, { value: 'price-ascending', name: 'Precio ascendente' }],
});
const all = makeCollection('all', 'Catálogo', products);
const offers = makeCollection('ofertas', 'Ofertas', [colors, single], products.length);
const collections = { all, ofertas: offers, bolsas: makeCollection('bolsas', 'Bolsos', products),
  coach: makeCollection('coach', 'Coach', products) };
const pages = { mayoreo: { id: 1, url: '/pages/mayoreo', template_suffix: 'guia-mayoreo' },
  contacto: { id: 2, url: '/pages/contacto', template_suffix: 'guia-contacto' },
  rewards: { id: 3, url: '/pages/rewards', template_suffix: 'guia-rewards' } };

const quantities = new Map();
let adds = 0;
let changes = 0;
let reject = false;
let signIn = false;
let delay = 0;
let shipping = false;
let rewardsSignup = false;
let customerMetafields = null;
let omitCartSection = false;
let cartReadFailures = 0;
let checkoutVisits = 0;
let hasOffersCollection = true;
let hasGuidePages = true;
let failCollectionPage = false;
let pagedSearchCount = 0;
let rateLimitNext = 0;
const quantity = () => [...quantities.values()].reduce((sum, n) => sum + n, 0);
function cart() {
  const total = quantity();
  const eligible = (quantities.get(10) || 0) + (quantities.get(11) || 0);
  const discount = eligible >= 3 ? 15000 : 0;
  return {
    item_count: total, currency: { iso_code: 'MXN' },
    total_price: [...quantities].reduce((sum, [id, n]) => sum + byVariant.get(id).variant.price * n, 0) - discount,
    cart_level_discount_applications: discount ? [{ title: 'Mayoreo QA', total_allocated_amount: discount }] : [],
    items: [...quantities].map(([id, n]) => {
      const { variant, product } = byVariant.get(id);
      return { variant, product, variant_id: id, key: 'line-' + id, quantity: n,
        url: product.url + '?variant=' + id, image: variant.featured_image,
        original_price: variant.price, final_price: variant.price, final_line_price: variant.price * n };
    }),
  };
}
const globals = (path, type, suffix) => ({
  routes, collections: { ...collections, ofertas: hasOffersCollection ? offers : null }, pages: hasGuidePages ? pages : {}, cart: cart(), shop: { name: 'Monetta', customer_accounts_enabled: true },
  request: { path, locale: { iso_code: 'es-MX' } }, template: { name: type, suffix },
  customer: signIn ? { first_name: 'Ana', name: 'Ana QA', email: 'ana@example.test', ...(customerMetafields ? { metafields: customerMetafields } : {}) } : null,
  settings: { monetta_rewards_shipping: shipping, monetta_rewards_signup: rewardsSignup }, section: { id: 'main', settings: {} },
});
const view = (name, scope) => liquid.renderFile(name, scope, { globals: scope });
const sheet = () => view('monetta-cart-sheet', globals('/cart', 'cart'));
const headingFonts = `@font-face{font-family:"DM Sans";src:url(/assets/DMSans-Regular.ttf)}@font-face{font-family:"Cormorant Garamond";src:url(/assets/CormorantGaramond-Regular.woff2)}`;
const css = ['tokens', 'base', 'components', 'pages', 'home-22oct', 'theme', 'app-alignment', 'guia', 'predictive-search', 'tarjetas', 'home-v41', 'v43'];
const scripts = ['core', 'cart', 'merchandising', 'guia', 'listing', 'product'];
const quickDialog = '<dialog id="quick-view" class="overlay overlay--dialog overlay--preview" aria-labelledby="quick-view-title"><div class="overlay__backdrop" data-overlay-close></div><div class="overlay__panel" data-quick-view-panel></div></dialog>';
async function documentFor(scope, content) {
  const header = await view('monetta-header', { ...scope, section: { id: 'header', settings: {} } });
  const dock = await view('monetta-dock', scope);
  const config = { template: scope.template.name, storeLang: 'es-MX', routes: {
    root: '/', cart: '/cart', cartAdd: '/cart/add.js', cartChange: '/cart/change.js', cartJson: '/cart.js',
  } };
  return `<!doctype html><html lang="es-MX" class="js"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Monetta · QA local</title>
  <style>${headingFonts}</style>${css.map((x) => `<link rel="stylesheet" href="/assets/monetta-${x}.css">`).join('')}
  <script>window.MonettaConfig = ${JSON.stringify(config)}</script>${scripts.map((x) => `<script defer src="/assets/monetta-${x}.js"></script>`).join('')}
  </head><body class="mw has-dock" data-template="${scope.template.name}"><div id="page"><div id="site-top" class="site-top">${header}</div>
  <main id="MainContent" tabindex="-1">${content}</main>${dock}</div>${await sheet()}${quickDialog}
  <div id="toast-root"></div><div id="status-live" class="visually-hidden" role="status"></div><div id="alert-live" class="visually-hidden" role="alert"></div></body></html>`;
}
const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1');
  const path = url.pathname;
  const send = (body, type = 'text/html; charset=utf-8', status = 200) => res.writeHead(status, { 'content-type': type }).end(body);
  const json = (value, status) => send(JSON.stringify(value), 'application/json', status);
  try {
    if (path.startsWith('/assets/')) {
      const file = path.split('/').at(-1);
      const type = { css: 'text/css', js: 'application/javascript', svg: 'image/svg+xml', jpg: 'image/jpeg', webp: 'image/webp', png: 'image/png' }[file.split('.').at(-1)];
      try { return send(await readFile(resolve(theme, 'assets', file)), type || 'application/octet-stream'); }
      catch { return send('', 'text/plain', 404); }
    }
    if (path === '/cart/add.js' || path === '/cart/change.js') {
      let raw = '';
      for await (const chunk of req) raw += chunk;
      const body = JSON.parse(raw);
      if (path.endsWith('add.js')) adds += 1;
      else changes += 1;
      if (delay) await new Promise((done) => setTimeout(done, delay));
      if (reject) { reject = false; return json({ description: 'Stock insuficiente (QA).' }, 422); }
      const id = Number(String(body.id).replace('line-', ''));
      assert(byVariant.has(id));
      const n = path.endsWith('add.js') ? (quantities.get(id) || 0) + body.quantity : body.quantity;
      n ? quantities.set(id, n) : quantities.delete(id);
      return json({ sections: { 'monetta-cart-sheet': omitCartSection ? null : await sheet() } });
    }
    if (path === '/cart' && url.searchParams.has('sections')) {
      if (cartReadFailures > 0) {
        cartReadFailures -= 1;
        return json({}, 503);
      }
      return json({ 'monetta-cart-sheet': await sheet() });
    }
    if (path === '/checkout') {
      checkoutVisits += 1;
      return send('<h1>Checkout de prueba</h1>');
    }
    if (path === '/cart.js') return json(cart());
    if (path === '/recommendations/products') return send(await view('monetta-cart-recommendations', {
      ...globals(path, 'product'), recommendations: { performed: true, products_count: 3, products: [single, ...extras] },
    }));
    if (path.startsWith('/products/')) {
      const product = products.find((item) => item.url === path);
      const current = product.variants.find((v) => v.id === Number(url.searchParams.get('variant'))) || product.variants[0];
      const scope = { ...globals(path, 'product'), product: {
        ...product, selected_or_first_available_variant: current,
        options_with_values: product.has_only_default_variant ? [] : [{ name: 'Color', position: 1, selected_value: current.title,
          values: product.variants.map((v) => ({ selected: v.id === current.id, variant: v, available: v.available, toString: () => v.title })) }],
      }, section: { id: 'main', settings: { show_dynamic_checkout: true }, blocks: [] } };
      const section = url.searchParams.get('section_id');
      const rendered = await view(section === 'monetta-quick-view' ? section : 'monetta-product', scope);
      return send(section ? rendered : await documentFor(scope, rendered + '<div style="height:135vh"></div>'));
    }
    if (path.startsWith('/collections/')) {
      const collection = collections[path.split('/').at(-1)] || all;
      const alternate = url.searchParams.get('view') === 'ofertas';
      const offersPage = collection === offers || alternate;
      const paged = offersPage || collection.handle === 'bolsas';
      const pageNum = Math.max(1, Number(url.searchParams.get('page') || 1));
      const page2 = paged && pageNum === 2;
      if (pagedSearchCount > 2 && collection.handle === 'bolsas') {
        if (rateLimitNext > 0 && pageNum === 2) {
          rateLimitNext -= 1;
          return res.writeHead(429, { 'content-type': 'text/plain', 'retry-after': '0' }).end('Too Many Requests');
        }
        const hasNext = pageNum < pagedSearchCount;
        const nextPage = new URL(url);
        nextPage.searchParams.set('page', String(pageNum + 1));
        const pageProducts = pageNum === pagedSearchCount
          ? [extras[1]]
          : [makeProduct(100 + pageNum, 'bolso-lote-' + pageNum, 'Bolso Lote ' + pageNum, ['Default Title'])];
        const scope = { ...globals(path, 'collection'), section: { id: 'main', settings: { products_per_page: 24 } },
          collection: { ...collection, filters: [], sort_by: url.searchParams.get('sort_by'), products: pageProducts },
          paginate: { current_page: pageNum, pages: pagedSearchCount, items: pagedSearchCount,
            current_offset: pageNum - 1, next: hasNext ? { url: nextPage.pathname + nextPage.search } : null } };
        return send(await documentFor(scope, await view('monetta-collection', scope)));
      }
      if (page2 && failCollectionPage) {
        failCollectionPage = false;
        return send('Página no disponible', 'text/plain', 503);
      }
      const optionName = 'filter.v.option.color';
      const color = url.searchParams.get(optionName);
      const maxName = 'filter.v.price.lte';
      const minName = 'filter.v.price.gte';
      const amount = (name) => url.searchParams.has(name) ? Number(url.searchParams.get(name)) * 100 : null;
      const nextPage = new URL(url);
      nextPage.searchParams.set('page', '2');
      const listingProducts = paged ? (page2 ? extras : [colors, single]) : collection.products;
      const colorValues = ['Café', 'Negro'].map((value) => ({
        label: value, value, active: value === color, count: 2, param_name: optionName, url_to_remove: path,
      }));
      const filters = offersPage ? [
        { type: 'list', label: 'Color', param_name: optionName, values: colorValues, active_values: colorValues.filter((v) => v.active) },
        { type: 'price_range', label: 'Precio', range_max: 300000, url_to_remove: path,
          min_value: { value: amount(minName), param_name: minName }, max_value: { value: amount(maxName), param_name: maxName } },
      ] : [];
      const scope = { ...globals(path, 'collection', alternate ? 'ofertas' : undefined), section: { id: 'main', settings: { products_per_page: 24 } },
        collection: { ...collection, filters, sort_by: url.searchParams.get('sort_by'), products: listingProducts.map((product) => ({
          ...product,
          // Shopify supplies a deep link to the matching variant in a filtered listing.
          url: color ? product.url + '?variant=' + (product.variants.find((v) => v.title === color)?.id ?? product.variants[0].id) : product.url,
          variants: product.variants.map((v) => ({ ...v, matched: !color || v.title === color })),
        })) },
        paginate: paged ? { current_page: page2 ? 2 : 1, pages: 2, items: products.length,
          current_offset: page2 ? 2 : 0, next: page2 ? null : { url: nextPage.pathname + nextPage.search } } : { current_page: 1, pages: 1 } };
      const listing = await view('monetta-collection', scope);
      return send(await documentFor(scope, listing + (offersPage ? '<div style="height:700px"></div>' : '')));
    }
    if (path === '/collections') {
      const scope = globals(path, 'list-collections', url.searchParams.get('view'));
      return send(await documentFor(scope, await view('monetta-guia-categories', scope)));
    }
    const guideView = url.searchParams.get('view');
    if (path.startsWith('/pages/') || (path === '/' && ['guia-contacto', 'guia-mayoreo'].includes(guideView))) {
      const mode = guideView?.replace('guia-', '') || path.split('/').at(-1);
      const scope = { ...globals(path, path === '/' ? 'index' : 'page', guideView), section: { id: 'main', settings: { mode } } };
      return send(await documentFor(scope, await view('monetta-guia-page', scope)));
    }
    const scope = globals('/', 'index');
    const renderHome = (mode) => view('monetta-guia-home', {
      ...scope, section: { id: mode, settings: { mode, show_banner_categorias: true, enabled: true } },
    });
    const home = (await Promise.all(['carousel', 'categories', 'brands'].map(renderHome))).join('');
    const feature = await view('monetta-home-feature', { ...scope, source: all, heading_id: 'new', heading: 'Nueva colección', limit: 4 });
    const feed = await view('monetta-home-feed', { ...scope, source: all, heading_id: 'for-you', heading: 'Para ti', limit: 4 });
    return send(await documentFor(scope, home + feature + feed + await renderHome('offers') + await renderHome('services') + await renderHome('register')));
  } catch (error) {
    console.error(error);
    return send(String(error), 'text/plain', 500);
  }
});
await mkdir(out, { recursive: true });
await new Promise((done) => server.listen(0, '127.0.0.1', done));
const base = 'http://127.0.0.1:' + server.address().port;
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 }, reducedMotion: 'reduce' });
page.setDefaultTimeout(6500);
const screenshot = async (name, fullPage = false) => {
  await page.evaluate(async () => {
    const images = [...document.images];
    if (images.length) {
      await Promise.allSettled(images.map((image) => {
        image.loading = 'eager';
        return image.decode();
      }));
    }
    await document.fonts.ready;
  });
  await page.screenshot({ path: resolve(out, name + '.png'), fullPage });
};
const go = async (path) => assert.equal((await page.goto(base + path)).status(), 200);
const openCart = async () => {
  for (const selector of ['[data-dock="cart"]', '[data-cart-link]']) {
    const link = page.locator(selector).first();
    const box = await link.boundingBox();
    const width = page.viewportSize().width;
    const height = page.viewportSize().height;
    if (box && box.width && box.height && box.y < height && box.x < width &&
        box.y + box.height > 0 && box.x + box.width > 0) {
      await link.click();
      return;
    }
  }
  throw new Error('No visible cart entry ' + JSON.stringify(await page.evaluate(() => ({
    url: location.pathname, body: document.body.className, scrollY,
    boxes: [...document.querySelectorAll('[data-dock="cart"], [data-cart-link]')].map((node) => node.getBoundingClientRect().toJSON()),
  }))));
};
async function expectFocused(locator) {
  await locator.evaluate((node) => {
    if (document.activeElement !== node) throw new Error('El foco quedó fuera del control esperado.');
  });
}
const dialog = page.locator('#cart-sheet');
const quick = page.locator('#quick-view');
const closeCart = async () => {
  await page.keyboard.press('Escape');
  await dialog.waitFor({ state: 'hidden' });
};
try {
  await go('/');
  await page.locator('[data-open-dialog="menu-drawer"]').click();
  await page.locator('#menu-drawer').getByRole('link', { name: 'Ofertas' }).click();
  assert.equal(new URL(page.url()).pathname, '/collections/ofertas');
  await page.locator('[data-offers-status]').getByText('2 ofertas', { exact: true }).waitFor();
  await page.locator('#offers-query').fill('aurora');
  await page.locator('[data-offers-search] button').click();
  await screenshot('AT01-ofertas');
  await page.locator('[data-offer-price] [data-quick-view]').click();
  await quick.waitFor();
  assert((await quick.locator('[data-quick-view-pdp]').getAttribute('href')).endsWith('variant=11'));
  assert.equal(await quick.locator('[data-msi-line]').textContent(), '6 pagos sin intereses de $322 mxn');
  await quick.locator('input[value="Café"]').check();
  assert((await quick.locator('[data-quick-view-pdp]').getAttribute('href')).endsWith('variant=10'));
  assert.equal(await quick.locator('.v43-price__discount').count(), 0);
  assert.equal(await quick.locator('[data-msi-line]').count(), 0);
  await page.evaluate(() => scrollTo(0, 140));
  const offersScroll = await page.evaluate(() => scrollY);
  assert(offersScroll > 0);
  await quick.getByText('Ver producto').click();
  await page.locator('[data-options] label:has([data-option-input][value="Negro"]) .option-chip__label').click();
  await page.waitForURL('**/products/bolso-aurora?variant=11');
  assert.equal(await page.locator('[data-product-gallery] .gallery__slide').count(), 1);
  assert.equal(await page.locator('[data-price] .v43-price__discount').textContent(), '−23%');
  assert.equal(await page.locator('[data-price] [data-msi-line]').textContent(), '6 pagos sin intereses de $322 mxn');
  await page.goBack();
  assert.equal(await page.locator('#offers-query').inputValue(), 'aurora');
  await page.waitForFunction((position) => Math.abs(scrollY - position) <= 2, offersScroll);

  await go('/collections/ofertas?filter.v.option.color=Caf%C3%A9&filter.v.price.lte=1900');
  await page.locator('[data-offers-status]').getByText('1 oferta', { exact: true }).waitFor();
  const cafeOffer = page.locator('[data-offer-price] [data-quick-view]');
  assert.equal(await cafeOffer.getAttribute('href'), '/products/bolso-luna?variant=20');
  await cafeOffer.click();
  assert((await quick.locator('[data-quick-view-pdp]').getAttribute('href')).endsWith('variant=20'));
  await page.keyboard.press('Escape');
  await go('/collections/ofertas?filter.v.price.gte=1900&sort_by=price-ascending');
  await page.locator('[data-offers-status]').getByText('2 ofertas', { exact: true }).waitFor();
  assert.deepEqual(await page.locator('[data-offer-price] [data-quick-view]').evaluateAll((links) =>
    links.map((link) => new URL(link.href).searchParams.get('variant'))), ['11', '21']);

  hasOffersCollection = false;
  await go('/');
  await page.locator('[data-open-dialog="menu-drawer"]').click();
  await page.getByRole('link', { name: 'Ofertas' }).click();
  await page.waitForURL('**/collections/all?view=ofertas');
  assert.equal(await page.locator('main h1').textContent(), 'Ofertas');
  await page.locator('[data-offers-status]').getByText('2 ofertas', { exact: true }).waitFor();
  await page.locator('#sort-select').selectOption('price-ascending');
  await page.waitForURL((url) => url.searchParams.get('sort_by') === 'price-ascending');
  assert.equal(new URL(page.url()).searchParams.get('view'), 'ofertas');
  hasOffersCollection = true;

  await go('/collections/bolsas');
  assert.equal(await page.locator('[data-grid] .card').count(), 2);
  assert(await page.locator('[data-load-more] [data-more]').isVisible());
  const localSearch = page.locator('#collection-query');
  failCollectionPage = true;
  await localSearch.fill('luna');
  await localSearch.press('Enter');
  const retryCollection = page.locator('[data-collection-retry]');
  await retryCollection.waitFor();
  assert.equal(await localSearch.inputValue(), 'luna');
  await retryCollection.click();
  await page.locator('[data-collection-status]').getByText('1 producto', { exact: true }).waitFor();
  assert.equal(await page.locator('[data-grid] .card__name').textContent(), 'Bolso Luna');
  await page.locator('#sort-select').selectOption('price-ascending');
  await page.waitForURL((url) => url.searchParams.get('sort_by') === 'price-ascending');
  assert.equal(new URL(page.url()).searchParams.get('producto'), 'luna');
  await localSearch.fill('inexistente');
  await localSearch.press('Enter');
  await page.locator('[data-collection-status]').getByText('0 productos', { exact: true }).waitFor();
  await page.locator('[data-clear-collection-query]').click();
  await page.waitForURL((url) => !url.searchParams.has('producto'));
  await page.locator('[data-load-more] [data-more]').waitFor();

  pagedSearchCount = 12;
  rateLimitNext = 1;
  await go('/collections/bolsas');
  await page.locator('#collection-query').fill('luna');
  await page.locator('#collection-query').press('Enter');
  await page.locator('[data-collection-more]').waitFor();
  await page.locator('[data-collection-status]').getByText('Sin coincidencias en las páginas cargadas.').waitFor();
  await page.locator('[data-collection-more]').click();
  await page.locator('[data-collection-status]').getByText('1 producto', { exact: true }).waitFor();
  assert.equal(await page.locator('[data-grid] .card__name').textContent(), 'Bolso Luna');
  pagedSearchCount = 0;
  rateLimitNext = 0;

  // Registro Rewards gate and G02 metafield rendering.
  rewardsSignup = false;
  await go('/');
  assert.equal(await page.locator('.v41-register').count(), 0);
  rewardsSignup = true;
  await go('/');
  await page.locator('.v41-register').getByText('Regístrate en MONETTA REWARDS').waitFor();
  await page.locator('.v41-register').getByText('ENVÍO GRATIS para siempre').waitFor();
  await page.locator('.v41-register').getByText('GANA CASHBACK con cada compra').waitFor();

  signIn = true;
  customerMetafields = null;
  await go('/');
  await page.locator('[data-open-dialog="menu-drawer"]').click();
  assert.equal((await page.locator('#menu-drawer .guia-identity__detail').textContent()).trim(), 'Miembro');
  assert.equal(await page.locator('#menu-drawer .guia-identity-balance').count(), 0);
  customerMetafields = { monetta: { rewards_tier: { value: 'VIP' }, rewards_balance: { value: { amount: 18400 } } } };
  await go('/');
  await page.locator('[data-open-dialog="menu-drawer"]').click();
  assert.equal((await page.locator('#menu-drawer .guia-identity__detail').textContent()).trim(), 'Miembro · VIP');
  await page.locator('#menu-drawer .guia-identity-balance__label').getByText('Saldo', { exact: true }).waitFor();
  await page.locator('#menu-drawer .guia-identity-balance__amount').getByText('$184 MXN', { exact: true }).waitFor();
  signIn = false;
  customerMetafields = null;
  rewardsSignup = false;

  await go('/');
  const required = page.locator('[data-feature-stage] [data-require-option]');
  await required.click();
  assert(await quick.locator('[data-quick-view-add]').isDisabled());
  await quick.locator('input[value="Negro"]').check();
  await quick.locator('[data-quick-view-add]').click();
  await dialog.waitFor();
  await screenshot('AT02-rapida');
  await closeCart();
  assert(await quick.locator('[data-quick-view-add]').evaluate((button) => button === document.activeElement));
  await page.keyboard.press('Escape');
  await quick.waitFor({ state: 'hidden' });

  await page.locator('[data-feature-pick]').nth(1).click();
  const feature = page.locator('[data-feature-stage] [data-quick-add] button');
  delay = 150;
  const before = adds;
  await feature.dblclick();
  await dialog.waitFor();
  assert.equal(adds, before + 1);
  await closeCart();
  delay = 0;
  reject = true;
  const feed = page.locator('.v41-feed [data-quick-add]:not([data-checkout]) button').first();
  await feed.click();
  await page.locator('.v41-feed [data-feature-error]:visible').waitFor();
  assert(!(await dialog.isVisible()));
  await feed.click();
  await dialog.waitFor();
  await screenshot('AT02-inicio');
  await closeCart();

  await go('/products/bolso-aurora?variant=11');
  const pdpAdd = page.locator('[data-sticky-add]');
  await pdpAdd.evaluate((el) => el.closest('[data-inline-purchase]').scrollIntoView({ block: 'center' }));
  await page.waitForFunction(() => !document.querySelector('[data-sticky-add]').classList.contains('is-fixed-add'));
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await page.waitForFunction(() => document.querySelector('[data-sticky-add]').classList.contains('is-fixed-add'));
  await pdpAdd.click();
  await dialog.waitFor();
  await screenshot('AT02-producto');
  await closeCart();

  shipping = true;
  quantities.clear();
  quantities.set(10, 1);
  quantities.set(11, 1);
  quantities.set(30, 2);
  await go('/products/bolso-aurora?variant=11');
  await openCart();
  await dialog.waitFor();
  const line = dialog.locator('[data-variant-id="11"]');
  assert.equal(await dialog.getByText('Mayoreo QA').count(), 0);
  for (const [step, n] of [[1, 2], [1, 3], [-1, 2], [-1, 1]]) {
    await page.waitForFunction(() => !window.Monetta.cart.isLocked());
    const beforeChange = changes;
    const stepper = line.locator(`[data-step="${step}"]`);
    if (step === 1 && n === 2) await stepper.dblclick();
    else await stepper.click();
    await line.locator('.stepper__value').getByText(String(n), { exact: true }).waitFor();
    await page.waitForTimeout(260);
    assert.equal(changes, beforeChange + 1);
    assert.equal(await dialog.getByText('Mayoreo QA').count(), n + quantities.get(10) >= 3 ? 1 : 0);
    if (n === 3) await screenshot('AT03-mayoreo-fixture');
  }
  await dialog.getByRole('button', { name: 'Continuar como invitado' }).waitFor();
  await dialog.getByRole('link', { name: 'Monetta Rewards' }).waitFor();
  reject = true;
  await page.waitForFunction(() => !window.Monetta.cart.isLocked());
  await line.locator('[data-step="1"]').click();
  await line.locator('[data-line-error]:visible').waitFor();
  await screenshot('AT03-error-linea');
  signIn = true;
  await go('/');
  await openCart();
  await dialog.getByRole('button', { name: 'Continuar al pago' }).waitFor();
  assert.equal(await dialog.getByRole('link', { name: 'Monetta Rewards' }).getAttribute('href'), '/pages/rewards');
  await screenshot('AT03-cuenta-fixture');

  // Comprar ahora shares one confirmed cart across PDP, Para ti and its option picker.
  await go('/products/bolso-aurora?variant=11');
  const buyPdp = page.locator('[data-buy-now]');
  omitCartSection = true;
  cartReadFailures = 2;
  const initialBuyWrites = adds;
  const initialBuyVisits = checkoutVisits;
  const oldQuantity = quantities.get(11);
  await buyPdp.click();
  await page.locator('[data-add-error]:visible').getByText('Shopify recibió la pieza.', { exact: false }).waitFor();
  assert.equal(checkoutVisits, initialBuyVisits);
  assert.equal(quantities.get(11), oldQuantity + 1);
  assert(await page.evaluate(() => window.Monetta.cart.isLocked()));
  await buyPdp.click();
  await page.waitForFunction(() => !document.querySelector('[data-buy-now]').disabled);
  assert.equal(checkoutVisits, initialBuyVisits);
  assert.equal(adds, initialBuyWrites + 1);
  await buyPdp.click();
  await page.waitForURL('**/checkout');
  assert.equal(adds, initialBuyWrites + 1);
  assert.equal(checkoutVisits, initialBuyVisits + 1);

  await go('/');
  const buySingle = page.locator('.v41-feed form[data-checkout] button').first();
  reject = true;
  await buySingle.click();
  await page.locator('.v41-feed form[data-checkout] [data-feature-error]:visible').waitFor();
  assert.equal(checkoutVisits, initialBuyVisits + 1);
  await buySingle.click();
  await page.waitForURL('**/checkout');
  assert.equal(checkoutVisits, initialBuyVisits + 2);

  await go('/');
  const buyChoice = page.locator('.v41-feed a[data-checkout]').first();
  const beforeChoice = adds;
  await buyChoice.click();
  const confirmChoice = quick.getByRole('button', { name: 'Comprar ahora' });
  assert(await confirmChoice.isDisabled());
  await page.keyboard.press('Escape');
  assert.equal(adds, beforeChoice);
  await buyChoice.click();
  await quick.locator('input[value="Café"]').check();
  const retained = quantities.get(11);
  const beforeCafe = quantities.get(10);
  delay = 150;
  await confirmChoice.dblclick();
  await page.waitForURL('**/checkout');
  assert.equal(adds, beforeChoice + 1);
  assert.equal(quantities.get(10), beforeCafe + 1);
  assert.equal(quantities.get(11), retained);
  delay = 0;
  omitCartSection = false;

  signIn = false;
  for (const width of [320, 390, 768, 1280, 1440]) {
    await page.setViewportSize({ width, height: width < 768 ? 685 : 850 });
    await go('/');
    await screenshot(`AT05-inicio-${width}`, true);
    const openMenu = page.locator('[data-open-dialog="menu-drawer"]');
    await openMenu.click();
    const menu = page.locator('#menu-drawer[open]');
    const offerLink = menu.getByRole('link', { name: 'Ofertas' });
    await menu.getByRole('link', { name: 'Inicio', exact: true }).waitFor();
    await offerLink.click({ trial: true });
    await screenshot(`AT05-menu-${width}`);
    const fontSize = () => offerLink.evaluate((link) => parseFloat(getComputedStyle(link).fontSize));
    const normalSize = await fontSize();
    await page.keyboard.press('Escape');
    await menu.waitFor({ state: 'hidden' });
    await expectFocused(openMenu);
    await page.evaluate(() => { document.documentElement.style.fontSize = '200%'; });
    await page.keyboard.press('Enter');
    await offerLink.click({ trial: true });
    assert.equal(await fontSize(), normalSize * 2);
    for (let tab = 0; tab < 15; tab += 1) {
      if (await offerLink.evaluate((link) => document.activeElement === link)) break;
      await page.keyboard.press('Tab');
    }
    await expectFocused(offerLink);
    await screenshot(`AT05-menu-teclado-texto200-${width}`);
    await page.keyboard.press('Escape');
    await menu.waitFor({ state: 'hidden' });
    await expectFocused(openMenu);
    await go('/products/bolso-aurora?variant=11');
    const headerFits = await page.locator('#site-header .site-header__bar :is(a,button)').evaluateAll(
      (elements) => elements.filter(el => el.getClientRects().length).every(el => {
        const box = el.getBoundingClientRect();
        return box.left >= -1 && box.right <= innerWidth + 1;
      }),
    );
    assert(headerFits, `Control de cabecera fuera de vista a ${width}px`);
    await screenshot(`AT05-pdp-${width}`);
    await openCart();
    await dialog.waitFor();
    const signInFits = await dialog.getByRole('link', { name: 'Iniciar sesión' }).evaluate(el => {
      const box = el.getBoundingClientRect();
      const panel = el.closest('.overlay__panel').getBoundingClientRect();
      return box.top >= panel.top && box.bottom <= panel.bottom && box.right <= panel.right;
    });
    assert(signInFits, `Acceso del carrito recortado a ${width}px`);
    await screenshot(`AT05-carrito-${width}`);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth), width);
    await closeCart();
  }

  await page.setViewportSize({ width: 320, height: 800 });
  await go('/');
  const bannerCta = page.locator('.v41-mayoreo__cta');
  const bannerSize = () => bannerCta.evaluate((link) => parseFloat(getComputedStyle(link).fontSize));
  const normalBannerSize = await bannerSize();
  await page.evaluate(() => { document.documentElement.style.fontSize = '200%'; });
  await bannerCta.scrollIntoViewIfNeeded();
  await page.waitForFunction((expected) =>
    parseFloat(getComputedStyle(document.querySelector('.v41-mayoreo__cta')).fontSize) === expected, normalBannerSize * 2);
  assert(await bannerCta.evaluate((link) =>
    link.getBoundingClientRect().top >= link.previousElementSibling.getBoundingClientRect().bottom));
  await screenshot('AT04-b04-320-texto200');
  assert.equal(await page.locator('.v41-mayoreo__cta').count(), 1);
  await bannerCta.focus();
  await expectFocused(bannerCta);
  await page.keyboard.press('Enter');
  await page.waitForURL('**/pages/mayoreo');
  await go('/');
  const expectedBanners = ['/collections/all', '/collections?view=marcas', '/collections'];
  for (const [index, destination] of expectedBanners.entries()) {
    const banner = page.locator('.v41-banner').nth(index);
    assert.equal(await banner.getAttribute('href'), destination);
    await banner.locator('img').evaluate((img) => img.decode());
  }
  await page.locator('[data-guia-next]').click();
  await page.locator('.v41-banner').nth(1).click();
  assert.equal(new URL(page.url()).searchParams.get('view'), 'marcas');
  assert.equal(await page.locator('main h1').textContent(), 'Todas las marcas');
  hasGuidePages = false;
  await go('/');
  const fallbackWholesale = page.locator('.v41-mayoreo__cta');
  assert.equal(await fallbackWholesale.getAttribute('href'), '/?view=guia-mayoreo');
  await fallbackWholesale.click();
  await page.locator('.guia-page--mayoreo').waitFor();
  await go('/?view=guia-contacto');
  await page.locator('.guia-page--contacto').getByText('Contáctanos').waitFor();
  hasGuidePages = true;

  for (const path of ['collections/bolsas', 'collections/coach', 'pages/contacto', 'pages/mayoreo']) {
    await go('/' + path);
    await screenshot('AT04-' + path.split('/').at(-1), true);
  }
  for (const width of [320, 640, 1280]) {
    await page.setViewportSize({ width, height: 685 });
    await go('/pages/mayoreo');
    await page.evaluate(() => { document.documentElement.style.fontSize = '200%'; });
    const steps = page.locator('.guia-steps__list');
    await steps.scrollIntoViewIfNeeded();
    if (width >= 640) {
      assert(await steps.evaluate(el => el.scrollWidth <= el.clientWidth + 1));
    }
    for (const card of await steps.locator('.guia-step').all()) {
      if (width < 640) await card.scrollIntoViewIfNeeded();
      assert(await card.evaluate(el => [...el.querySelectorAll('h3,p')].every(text =>
        text.scrollWidth <= text.clientWidth + 1)));
    }
    await screenshot(`AT05-mayoreo-texto200-${width}`);
  }
  await go('/pages/contacto');
  assert.equal(await page.locator('.guia-page--contacto .guide-hero__copy').getByText(/confianza\./).count(), 1);
  const scans = [];
  const axePath = require.resolve('axe-core/axe.min.js');
  await page.setViewportSize({ width: 390, height: 844 });
  rewardsSignup = true;
  signIn = true;
  customerMetafields = { monetta: { rewards_tier: { value: 'VIP' }, rewards_balance: { value: { amount: 18400 } } } };
  for (const path of ['/', '/collections/ofertas', '/products/bolso-aurora?variant=11']) {
    await go(path);
    await page.addScriptTag({ path: axePath });
    const check = () => page.evaluate(async () => {
      const result = await window.axe.run({ runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] } });
      return result.violations.map(({ id, impact, nodes }) => ({ id, impact, nodes: nodes.map(({ target }) => target) }));
    });
    scans.push({ path, violations: await check() });
    if (path === '/') {
      await page.locator('[data-open-dialog="menu-drawer"]').click();
      await page.locator('#menu-drawer[open]').waitFor();
      scans.push({ path: 'menu autenticado G02', violations: await check() });
      await page.keyboard.press('Escape');
      await page.locator('#menu-drawer').waitFor({ state: 'hidden' });
    }
    if (path.includes('/products/')) {
      await openCart();
      await dialog.waitFor();
      scans.push({ path: 'carrito lateral', violations: await check() });
    }
  }
  rewardsSignup = false;
  signIn = false;
  customerMetafields = null;
  await writeFile(resolve(out, 'axe-fixture.json'), JSON.stringify(scans, null, 2) + '\n');
  assert(scans.every(({ violations }) => violations.length === 0), 'axe detectó infracciones en el fixture');
  console.log('AT-01 a AT-05 ejercitados con fixtures de Shopify. Capturas en ' + out);
} finally {
  await browser.close();
  server.close();
}
