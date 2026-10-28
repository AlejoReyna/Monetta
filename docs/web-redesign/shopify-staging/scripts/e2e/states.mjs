// Screenshots of the states the corrections added or changed, so they can be looked at (they are not decided by pixels):
// the product page while a choice is pending / after it failed / without JavaScript, the sold-out variant, the load-more failure box,
// the bag while a change is pending / with an unconfirmed bag, the empty search after "Editar búsqueda", the undo and error toasts.
//   node states.mjs --base-url=http://127.0.0.1:9292 --w=375 --h=812 [--insets=44]
import { Run, browserPath, chromium, parseArgs, settle } from './lib.mjs';
import { Intercept, gate, goto, sleep } from './regress-lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const width = Number(args.w || 375);
const height = Number(args.h || 812);
const insets = args.insets ? Number(args.insets) : null;
const run = new Run(`states-${width}x${height}${insets ? '-insets44' : ''}`, { baseUrl, extra: { viewport: { width, height }, insets } });
const incidents = [];
run.meta.incidents = incidents;
const HANDLE = 'reloj-coach-talia-saddle';
const browser = await chromium.launch({ executablePath: browserPath(), headless: true });

async function open({ javaScript = true } = {}) {
  const context = await browser.newContext({ viewport: { width, height }, javaScriptEnabled: javaScript, reducedMotion: 'no-preference' });
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  if (insets) {
    const client = await context.newCDPSession(page);
    await client.send('Emulation.setSafeAreaInsetsOverride', { insets: { top: 0, bottom: 0, left: insets, right: insets } });
  }
  const net = await new Intercept(page).start();
  return { context, page, net };
}
const shot = async (page, name, description, { fullPage = false, scrollTo = null } = {}) => {
  if (scrollTo) await page.locator(scrollTo).first().scrollIntoViewIfNeeded().catch(() => {});
  const pending = await settle(page);
  await page.screenshot({ path: run.file(`${name}.png`), fullPage });
  run.check(`${name}: captured (${description})`, pending.length === 0, pending.length ? `images not loaded: ${pending.slice(0, 2).join(' ')}` : '');
};
const step = async (name, fn) => {
  try {
    await fn();
  } catch (error) {
    run.check(`${name} — unexpected error`, false, String(error.message).split('\n')[0], 'error');
  }
};
const chip = (page, value) => page.locator('.options__list--radios label.option-chip', { hasText: new RegExp(`^\\s*${value}\\s*$`) }).first();

await step('product', async () => {
  const { context, page, net } = await open();
  try {
    await goto(page, `${baseUrl}/products/${HANDLE}`, { incidents });
    await page.waitForFunction(() => !!window.Monetta?.product);
    await shot(page, 'product-initial', 'product page, JavaScript on, nothing pending');
    // pending
    const hold = gate();
    net.add('section', (url) => url.pathname === `/products/${HANDLE}` && url.searchParams.has('section_id'), async (route) => {
      await hold.promise;
      return route.continue();
    });
    await chip(page, 'Café').click();
    await page.waitForFunction(() => document.querySelector('[data-product-page]').dataset.selection === 'pending');
    await sleep(250);
    await shot(page, 'product-pending', 'a choice waiting for Shopify: status text, buttons disabled, chip and header value agree', { scrollTo: '[data-selection-status]' });
    hold.release();
    await page.waitForFunction(() => document.querySelector('[data-product-page]').dataset.selection === 'valid');
    net.rules.length = 0;
    // failed
    net.add('section', (url) => url.pathname === `/products/${HANDLE}` && url.searchParams.has('section_id'), (route) => route.fulfill({ status: 503, contentType: 'text/plain', body: 'Controlled failure' }));
    await chip(page, 'Negro/Plateado').click();
    await page.waitForFunction(() => document.querySelector('[data-add-error]:not([hidden])'));
    await sleep(250);
    await shot(page, 'product-failed', 'the choice failed: chips back on the shown variant, message names both options', { scrollTo: '[data-add-error]' });
  } finally {
    await context.close();
  }
});

await step('product-no-js', async () => {
  const { context, page } = await open({ javaScript: false });
  try {
    await goto(page, `${baseUrl}/products/${HANDLE}`, { incidents });
    await shot(page, 'product-no-js', 'JavaScript disabled: the options are links, the first one current', { scrollTo: '.options' });
    await goto(page, `${baseUrl}/products/bolso-steve-madden-crossbody-3?variant=68550844121122`, { incidents });
    await shot(page, 'product-no-js-soldout', 'JavaScript disabled, sold-out variant reached through its link', { scrollTo: '.options' });
  } finally {
    await context.close();
  }
});

await step('listing', async () => {
  const { context, page, net } = await open();
  try {
    await goto(page, `${baseUrl}/collections/all?filter.v.availability=1&sort_by=price-ascending`, { incidents });
    await page.waitForSelector('[data-more]');
    net.add('page2', (url, request) => url.searchParams.get('page') === '2' && request.resourceType() !== 'document', (route) => route.fulfill({ status: 503, contentType: 'text/plain', body: 'Controlled failure' }));
    await page.locator('[data-more]').scrollIntoViewIfNeeded();
    await page.locator('[data-more]').click();
    await page.waitForSelector('[data-load-error]');
    await shot(page, 'listing-load-failure', 'load more failed: retry button and a separate link to the next page', { scrollTo: '[data-load-error]' });
  } finally {
    await context.close();
  }
});

await step('bag', async () => {
  const { context, page, net } = await open();
  try {
    await goto(page, `${baseUrl}/`, { incidents });
    await page.evaluate(() => fetch('/cart/add.js', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: 68551021592610, quantity: 1, properties: { Grabado: 'ANA' } }) }));
    await goto(page, `${baseUrl}/cart`, { incidents });
    await page.waitForFunction(() => !!window.Monetta?.cart);
    await shot(page, 'bag-initial', 'bag with a personalised line');
    const hold = gate();
    net.add('change', (url, request) => request.method() === 'POST' && /change\.js$/.test(url.pathname), async (route) => {
      await hold.promise;
      return route.continue();
    });
    await page.locator('[data-line] [data-step="1"]').first().click();
    await page.waitForFunction(() => document.documentElement.hasAttribute('data-cart-locked'));
    await sleep(250);
    await shot(page, 'bag-change-pending', 'a quantity change on the wire: every checkout button disabled');
    hold.release();
    await page.waitForFunction(() => !document.documentElement.hasAttribute('data-cart-locked'));
    net.rules.length = 0;
    // unconfirmed
    net.add('change', (url, request) => request.method() === 'POST' && /change\.js$/.test(url.pathname), (route) => route.abort('connectionreset'));
    net.add('read', (url, request) => request.method() === 'GET' && url.pathname === '/cart' && url.searchParams.has('sections'), (route) => route.abort('connectionreset'));
    await page.locator('[data-line] [data-step="1"]').first().click();
    await page.waitForSelector('[data-cart-sync]:not([hidden])');
    await sleep(250);
    await shot(page, 'bag-unconfirmed', 'the change failed and the bag could not be read back: notice with "Actualizar bolsa", checkout disabled');
    net.rules.length = 0;
    await page.locator('[data-cart-resync]:visible').first().click();
    await page.waitForFunction(() => !document.documentElement.hasAttribute('data-cart-locked'));
    // remove and undo toast
    await page.locator('[data-line] [data-remove-line]').first().click();
    await page.waitForSelector('.toast__action');
    await sleep(300);
    await shot(page, 'bag-undo-toast', 'line removed: the "Deshacer" toast (it restores the personalised line)');
  } finally {
    await context.close();
  }
});

await step('search', async () => {
  const { context, page } = await open();
  try {
    await goto(page, `${baseUrl}/search?q=zzcorreccionesnoexiste987&type=product`, { incidents });
    await page.waitForSelector('[data-edit-search]');
    await shot(page, 'search-empty', 'no results, before pressing "Editar búsqueda"');
    await page.locator('[data-edit-search]').click();
    await sleep(250);
    await shot(page, 'search-edit-focused', 'after "Editar búsqueda": the visible field is focused with its text selected');
  } finally {
    await context.close();
  }
});

await browser.close();
run.note(`proxy incidents during the run: ${incidents.length}`);
const result = run.finish({ complete: true });
process.exit(result.summary.failed ? 1 : 0);
