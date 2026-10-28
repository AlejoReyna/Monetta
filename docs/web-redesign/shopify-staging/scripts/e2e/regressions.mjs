// Regression checks for the nine findings of the independent audit of 2026-10-19 (docs/web-redesign/shopify-staging/audit-codex-2026-10-19/).
// Every check names the finding it covers (P1..P8). Two kinds of evidence are kept apart and labelled in each check's name:
//   [staging]    the real theme served by the dev proxy for the draft theme, with Shopify's real responses; commerce writes go only to
//                an anonymous cart of the browser context and stop at the entrance to checkout (no order, no payment). Faults (slow,
//                503, dropped connection, invalid document, out-of-order answers) are injected by intercepting the browser's requests.
//   [controlled] a document built here with the theme's real script and stubbed answers, for cases staging does not contain
//                (a selling plan) or cannot produce (Shopify rejecting an undo).
//
//   node regressions.mjs --base-url=http://127.0.0.1:9292 --w=375 --h=812 [--only=p1,p2,...]
//   Negative controls replay a defect and must fail the checks listed in --expect:
//     --old-assets=monetta-product.js,monetta-cart.js,...   serve the audited scripts (correcciones-.../codigo-previo/assets)
//     --rewrite=<name>                                       rewrite the served document (see REWRITES)
//     --inject-css=<css>                                     add a stylesheet to every document
//     --expect="check name 1|/regex/"                         names (or /regexes/) that must fail, as assertions, for the control to count as detected
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { Run, chromium, browserPath, parseArgs, settle, target } from './lib.mjs';
import { proxyHealth } from './proxy-health.mjs';
import { Intercept, gate, goto, money, previous, sleep, useOldAssets, esc } from './regress-lib.mjs';
const SHOPIFY_DEFAULT_MENU_TITLE = /^(home|catalog|contact|search|shop all|about us|blog|news|products|collections)$/i;

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const width = Number(args.w || 1440);
const height = Number(args.h || 900);
const only = args.only ? new Set(args.only.split(',')) : null;
const oldAssets = args['old-assets'] ? args['old-assets'].split(',') : [];
const rewrite = args.rewrite || null;
const injectCss = args['inject-css'] || null;
const expected = args.expect ? args.expect.split('|') : [];
const label = args.label ? `-${args.label}` : '';
const isControl = Boolean(oldAssets.length || rewrite || injectCss);
const run = new Run(`${isControl ? 'negative-control-' : 'regressions-'}${width}x${height}${label}`, { baseUrl, extra: { viewport: { width, height } } });
const incidents = [];
run.meta.incidents = incidents;
if (isControl) run.meta.control = { oldAssets, rewrite, injectCss, expectedFailures: expected };

const HANDLE = 'reloj-coach-talia-saddle';
const browser = await chromium.launch({ executablePath: browserPath(), headless: true });

/* -------------------------------------------------------------------------------- harness */
// Wraps fetch before any script runs and records, at the instant of each cart write, what the page was showing: this is how "the
// variant sent is the variant shown" is checked from the page's own state and not from a stub's point of view.
function recordCartWrites() {
  const original = window.fetch;
  window.__writes = [];
  window.fetch = function patched(input, init) {
    try {
      const url = typeof input === 'string' ? input : input.url;
      const method = (init && init.method) || (input && input.method) || 'GET';
      if (method === 'POST' && /\/cart\/(add|change)\.js/.test(url)) {
        const root = document.querySelector('[data-product-page]');
        window.__writes.push({
          path: new URL(url, location.href).pathname,
          body: init && init.body ? JSON.parse(init.body) : null,
          selection: root ? root.dataset.selection || null : null,
          hidden: Number(document.querySelector('[data-variant-id]')?.value) || null,
          chosen: [...document.querySelectorAll('[data-options] fieldset')].map((g) => g.querySelector('input:checked')?.value),
          t: performance.now(),
        });
      }
    } catch {
      /* recording must never break the page */
    }
    return original.apply(this, arguments);
  };
}

const REWRITES = {
  // Each reintroduces one audited defect in the served document, so the check that guards it must fail.
  'edit-search-href': (html) => html.replace('href="#page-search-input" data-edit-search', 'href="#header-search-input" data-edit-search'),
  // The audited markup without a script: the radio chips on screen, the links gone.
  'show-radios-no-js': (html) => html.replace('</head>', '<style>.options__list--radios{display:flex !important}.options__list--links{display:none !important}</style></head>'),
  'html-lang-store': (html) => html.replace('<html lang="es-MX"', '<html lang="en"'),
  'drop-structured-data': (html) => html.replace(/<script type="application\/ld\+json">[\s\S]*?<\/script>/g, ''),
};

async function newPage({ w = width, h = height, javaScript = true, extra = {} } = {}) {
  const context = await browser.newContext({ viewport: { width: w, height: h }, javaScriptEnabled: javaScript, reducedMotion: 'no-preference', ...extra });
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  if (javaScript) await context.addInitScript(recordCartWrites);
  if (injectCss) {
    await context.addInitScript((css) => {
      document.addEventListener('DOMContentLoaded', () => {
        const style = document.createElement('style');
        style.textContent = css;
        document.head.append(style);
      });
    }, injectCss);
  }
  if (oldAssets.length) {
    await useOldAssets(page, oldAssets);
    // The audited product script never set the class that now selects the radio chips (it did not need to: they were always shown).
    if (oldAssets.includes('monetta-product.js')) await context.addInitScript(() => document.addEventListener('DOMContentLoaded', () => document.documentElement.classList.add('mw-variants-js')));
  }
  if (rewrite) {
    const transform = REWRITES[rewrite];
    await page.route('**/*', async (route) => {
      if (route.request().resourceType() !== 'document') return route.fallback();
      const response = await route.fetch();
      const html = await response.text();
      return route.fulfill({ response, body: transform(html) });
    });
  }
  const net = await new Intercept(page).start();
  const problems = [];
  const ignored = /shop\.app|monorail|web-pixels|\/api\/collect|\.well-known|customer-privacy|Content Security Policy|favicon|chrome-error|origin_trials|shopify-marketing_assets|cdn\.shopify\.com\/shopifycloud|\/v1\/(logs|metrics|produce)|status of (4|5)\d\d|net::ERR/i;
  page.on('console', (m) => {
    if (m.type() === 'error' && !ignored.test(m.text()) && !ignored.test(m.location().url || '')) problems.push(`console: ${m.text()}`);
  });
  page.on('pageerror', (e) => problems.push(`pageerror: ${e.message}`));
  return { context, page, net, problems };
}

async function step(id, title, fn) {
  if (only && !only.has(id)) return;
  console.log(`\n== ${id} ${title}`);
  try {
    await fn();
  } catch (error) {
    run.check(`${id} ${title} — the check could not run`, false, `ERROR: ${String(error.message).split('\n')[0]}`, 'error');
  }
}

const A = (name, pass, detail = '') => run.check(name, pass, detail);
/** Waits that report instead of throwing: when the page does not reach the expected state the assertion after it fails, as an assertion. */
const until = (page, fn, arg, timeout = 8000) => page.waitForFunction(fn, arg, { timeout }).then(() => true, () => false);
const untilSelector = (page, selector, timeout = 8000) => page.waitForSelector(selector, { timeout }).then(() => true, () => false);

async function productJson(page, handle = HANDLE) {
  return page.evaluate((h) => fetch(`/products/${h}.js`).then((r) => r.json()), handle);
}

const chip = (page, value) =>
  page
    .locator('.options__list--radios label.option-chip')
    .filter({ has: page.locator('.option-chip__label', { hasText: new RegExp(`^\\s*${esc(value)}\\s*$`) }) })
    .first();

/** What the product page shows right now, from its own DOM. */
const snapshot = (page) =>
  page.evaluate(() => {
    const root = document.querySelector('[data-product-page]');
    const visible = (el) => !!el && el.getClientRects().length > 0 && !el.hidden && getComputedStyle(el).visibility !== 'hidden';
    const status = document.querySelector('[data-selection-status]');
    const error = document.querySelector('[data-add-error]');
    return {
      selection: root.dataset.selection ?? null,
      busy: root.getAttribute('aria-busy'),
      hidden: Number(document.querySelector('[data-variant-id]')?.value) || null,
      chosen: [...document.querySelectorAll('[data-options] fieldset')].map((g) => g.querySelector('input:checked')?.value),
      header: [...document.querySelectorAll('[data-option-value]')].map((e) => e.textContent.trim()),
      url: new URL(location.href).searchParams.get('variant'),
      price: document.querySelector('[data-price] .price')?.textContent.trim() ?? null,
      addDisabled: [...document.querySelectorAll('[data-add]')].map((b) => b.disabled),
      payInert: [...document.querySelectorAll('.other-ways')].map((e) => e.inert),
      status: status && visible(status) ? status.textContent.trim() : '',
      error: error && visible(error) ? error.textContent.trim() : '',
      payButtons: document.querySelectorAll('.shopify-payment-button__button').length,
    };
  });

const seenWrites = [];
/** Cart writes the page made since its last reset. Everything read is also kept, so a whole-run assertion can look at all of them. */
const writes = async (page) => {
  const list = await page.evaluate(() => window.__writes || []);
  for (const entry of list) if (!seenWrites.some((x) => x.t === entry.t && x.path === entry.path && x.body?.id === entry.body?.id)) seenWrites.push(entry);
  return list;
};
const resetWrites = async (page) => {
  await writes(page);
  await page.evaluate(() => (window.__writes.length = 0));
};

/** Tries every way a shopper (or a script on the page) can press a button, without leaving a trace if the button refuses. */
async function pressEverywhere(page, selector) {
  const count = await page.locator(selector).count();
  for (let i = 0; i < count; i++) {
    const element = page.locator(selector).nth(i);
    const box = await element.boundingBox();
    if (box && box.width > 0 && box.height > 0) await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    await element.evaluate((el) => el.click());
    await element.evaluate((el) => el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true })));
  }
  return count;
}

async function pressEnterInQuantity(page) {
  const input = page.locator('[data-qty-input]').first();
  if (!(await input.count())) return false;
  await input.evaluate((el) => el.focus());
  await page.keyboard.press('Enter');
  return true;
}

function sectionRule(net, plan) {
  return net.add(
    'section',
    (url) => url.pathname === `/products/${HANDLE}` && url.searchParams.has('section_id'),
    async (route, request, entry, hits) => {
      const variant = Number(new URL(request.url()).searchParams.get('variant'));
      const behavior = (await plan(variant, hits, route, request)) || { type: 'pass' };
      if (behavior.gate) await behavior.gate.promise;
      if (behavior.delay) await sleep(behavior.delay);
      switch (behavior.type) {
        case 'status':
          return route.fulfill({ status: behavior.status, contentType: 'text/plain', body: behavior.body || 'Controlled failure' });
        case 'abort':
          return route.abort('connectionreset');
        case 'html':
          return route.fulfill({ status: 200, contentType: 'text/html', body: behavior.body });
        case 'real-for': {
          // Shopify's real section, but for another variant than the one asked for.
          const asked = new URL(request.url());
          asked.searchParams.set('variant', String(behavior.variant));
          return route.fulfill({ response: await route.fetch({ url: asked.href }) });
        }
        case 'modify': {
          const response = await route.fetch();
          return route.fulfill({ response, body: behavior.change(await response.text()) });
        }
        default:
          return route.continue();
      }
    },
  );
}

function stubAdd(net) {
  return net.add(
    'add',
    (url, request) => request.method() === 'POST' && /\/cart\/add\.js$/.test(url.pathname),
    (route) => route.fulfill({ status: 200, contentType: 'application/json', body: '{"status":"stubbed by the check; Shopify was not written"}' }),
  );
}

async function closeSheet(page) {
  // The sheet opens when the add (stubbed here) has been answered and the bag read back; closing it earlier would race with that.
  await page.waitForFunction(() => !window.Monetta?.cart?.isLocked || !window.Monetta.cart.isLocked(), null, { timeout: 8000 }).catch(() => {});
  await sleep(oldAssets.length ? 1500 : 350);
  if (await page.evaluate(() => !!document.querySelector('#cart-sheet')?.open)) await page.keyboard.press('Escape');
  await page.waitForFunction(() => !document.querySelector('#cart-sheet')?.open, null, { timeout: 3000 }).catch(() => {});
}

/* ================================================================================ P1 · variant coherence */
await step('p1', 'variant choice pending / failed (product page)', async () => {
  const { context, page, net, problems } = await newPage();
  try {
    await goto(page, `${baseUrl}/products/${HANDLE}`, { incidents });
    await page.waitForFunction(() => !!window.Monetta?.cart?.add);
    await settle(page);
    const product = await productJson(page);
    const initial = product.variants.find((v) => v.available);
    const choices = product.variants.filter((v) => v.available && v.option1 !== initial.option1);
    const [B, C] = choices;
    run.note(`P1 page: ${HANDLE}; initial variant ${initial.id} "${initial.option1}", B ${B.id} "${B.option1}", C ${C.id} "${C.option1}"`);
    stubAdd(net);

    // ---- control: wait for the answer, then add -> the chosen variant (the audit's positive control)
    await chip(page, B.option1).click();
    await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), B.id);
    let s = await snapshot(page);
    A('P1 [staging] control: after Shopify answers, id, chip, header, address and price are the chosen variant\'s', s.hidden === B.id && s.chosen[0] === B.option1 && s.header[0] === B.option1 && s.url === String(B.id) && money(s.price) === B.price / 100, JSON.stringify(s));
    A('P1 [staging] control: the page is confirmed (selection=valid) and not busy', s.selection === 'valid' && s.busy === null, JSON.stringify({ selection: s.selection, busy: s.busy }));
    await page.evaluate(() => document.querySelector('[data-add]').click());
    await until(page, () => window.__writes?.some((w) => w.path.endsWith('add.js')));
    let sent = (await writes(page)).filter((w) => w.path.endsWith('add.js'));
    A('P1 [staging] control: adding after confirmation sends the chosen variant, once', sent.length === 1 && sent[0].body.id === B.id, JSON.stringify(sent.map((w) => w.body)));
    await closeSheet(page);
    // back to the initial variant for the next scenarios
    await chip(page, initial.option1).click();
    await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), initial.id);
    await resetWrites(page);
    net.reset();

    // ---- slow answer: nothing may be added or paid while the choice is unconfirmed
    const hold = gate();
    const rule = sectionRule(net, (variant) => (variant === B.id ? { gate: hold } : { type: 'pass' }));
    await chip(page, B.option1).click();
    await page.waitForFunction(() => document.querySelector('[data-product-page]').getAttribute('aria-busy') === 'true');
    await sleep(150);
    s = await snapshot(page);
    A('P1 [staging] slow answer: the page reports the choice as pending (selection=pending, aria-busy, status text)', s.selection === 'pending' && s.busy === 'true' && /Confirmando disponibilidad/.test(s.status), JSON.stringify({ selection: s.selection, busy: s.busy, status: s.status }));
    A('P1 [staging] slow answer: the chip and the value beside the option name agree on the chosen option', s.chosen[0] === B.option1 && s.header[0] === B.option1, JSON.stringify({ chosen: s.chosen, header: s.header }));
    A('P1 [staging] slow answer: every add button is really disabled (not only dimmed)', s.addDisabled.length >= 1 && s.addDisabled.every(Boolean), JSON.stringify(s.addDisabled));
    A('P1 [staging] slow answer: the accelerated-checkout / WhatsApp area is inert', s.payInert.length >= 1 && s.payInert.every(Boolean), JSON.stringify(s.payInert));
    const payBefore = net.count('cartCreate');
    const graphql = net.add('cartCreate', (url, request) => request.method() === 'POST' && /graphql\.json/.test(url.pathname) && /cartCreate/.test(url.search + (request.postData() || '')), (route) => route.abort('blockedbyclient'));
    const pressed = await pressEverywhere(page, '[data-add]');
    const enter = await pressEnterInQuantity(page);
    await page.locator('.shopify-payment-button__button').evaluateAll((els) => els.forEach((el) => { el.click(); el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true })); }));
    const payBox = await page.locator('.shopify-payment-button__button').first().boundingBox().catch(() => null);
    if (payBox) await page.mouse.click(payBox.x + payBox.width / 2, payBox.y + payBox.height / 2);
    await sleep(400);
    sent = (await writes(page)).filter((w) => w.path.endsWith('add.js'));
    A(`P1 [staging] slow answer: pressing every add button (${pressed}) by mouse, click() and dispatch, and Enter in the quantity field, sends no add request`, sent.length === 0 && net.count('add') === 0, `enter=${enter} adds=${sent.length} ${JSON.stringify(sent.map((w) => w.body?.id))}`);
    A('P1 [staging] slow answer: the accelerated-checkout button (Buy it now) starts nothing: no cartCreate request', net.count('cartCreate') === payBefore && s.payButtons >= 1, `payment buttons=${s.payButtons} cartCreate=${net.count('cartCreate') - payBefore}`);
    net.remove(graphql);
    await closeSheet(page); // with the audited scripts the presses above did add (stubbed) and open the sheet
    hold.release();
    await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), B.id);
    await sleep(100);
    s = await snapshot(page);
    A('P1 [staging] slow answer: when it arrives, id, chip, header, address and price are B\'s together and buying is open again', s.hidden === B.id && s.chosen[0] === B.option1 && s.header[0] === B.option1 && s.url === String(B.id) && money(s.price) === B.price / 100 && s.selection === 'valid' && s.addDisabled.every((d) => !d) && s.payInert.every((d) => !d), JSON.stringify(s));
    await page.evaluate(() => document.querySelector('[data-add]').click());
    await until(page, () => window.__writes?.some((w) => w.path.endsWith('add.js')));
    sent = (await writes(page)).filter((w) => w.path.endsWith('add.js'));
    A('P1 [staging] slow answer: adding afterwards sends exactly B, with the page showing B at that instant', sent.length === 1 && sent[0].body.id === B.id && sent[0].hidden === B.id && sent[0].chosen[0] === B.option1 && sent[0].selection === 'valid', JSON.stringify(sent));
    await closeSheet(page);
    net.remove(rule);
    await chip(page, initial.option1).click();
    await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), initial.id);

    // ---- failures: 503, dropped connection, invalid document (HTTP 200), incomplete document, another variant rendered
    const failures = [
      ['HTTP 503', { type: 'status', status: 503, body: 'Controlled audit failure', delay: 600 }],
      ['dropped connection', { type: 'abort', delay: 300 }],
      ['HTTP 200 with a document that is not the product section', { type: 'html', body: '<!doctype html><html><body><p>Error inesperado</p></body></html>', delay: 300 }],
      ['HTTP 200 with a section that has no product form', { type: 'modify', delay: 200, change: (html) => html.replace(/data-product-form/g, 'data-x-form') }],
      ['HTTP 200 with a section whose chips disagree with its variant', { type: 'modify', delay: 200, change: (html) => html.replace(/(<input class="visually-hidden" type="radio"[^>]*) checked/g, '$1') }],
    ];
    for (const [name, behavior] of failures) {
      await closeSheet(page);
      await resetWrites(page);
      const failing = sectionRule(net, (variant) => (variant === B.id ? behavior : { type: 'pass' }));
      await chip(page, B.option1).click();
      await page.waitForFunction(() => document.querySelector('[data-product-page]').getAttribute('aria-busy') === 'true');
      await until(page, () => document.querySelector('[data-product-page]').getAttribute('aria-busy') !== 'true', null, 15000);
      await sleep(150);
      s = await snapshot(page);
      const tag = `P1 [staging] ${name}`;
      A(`${tag}: the chips, the header value, the id and the address go back to the variant the page really shows`, s.hidden === initial.id && s.chosen[0] === initial.option1 && s.header[0] === initial.option1 && s.url === String(initial.id) && money(s.price) === initial.price / 100, JSON.stringify(s));
      A(`${tag}: the page says it could not confirm and which option stayed (role=alert)`, /No pudimos confirmar/.test(s.error) && s.error.includes(initial.option1), s.error);
      A(`${tag}: adding sends the variant shown (the initial one), never the failed choice`, await (async () => {
        await page.evaluate(() => document.querySelector('[data-add]').click());
        await until(page, () => window.__writes?.some((w) => w.path.endsWith('add.js')));
        const w = (await writes(page)).filter((x) => x.path.endsWith('add.js'));
        await closeSheet(page);
        return w.length === 1 && w[0].body.id === initial.id && w[0].hidden === initial.id && w[0].chosen[0] === initial.option1;
      })(), JSON.stringify(await writes(page)));
      net.remove(failing);
      // choosing it again (now answered normally) is the explicit retry
      await chip(page, B.option1).click();
      await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), B.id);
      s = await snapshot(page);
      A(`${tag}: choosing the option again retries and succeeds`, s.hidden === B.id && s.selection === 'valid' && s.error === '', JSON.stringify({ hidden: s.hidden, selection: s.selection, error: s.error }));
      await chip(page, initial.option1).click();
      await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), initial.id);
      net.reset();
    }

    // ---- Shopify renders another variant than the one asked for (the combination no longer exists)
    await closeSheet(page);
    {
      const other = sectionRule(net, (variant) => (variant === B.id ? { type: 'real-for', variant: C.id, delay: 200 } : { type: 'pass' }));
      await chip(page, B.option1).click();
      await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), C.id);
      await sleep(150);
      s = await snapshot(page);
      A('P1 [staging] another variant rendered than asked: the page adopts what Shopify rendered and shows it everywhere', s.hidden === C.id && s.chosen[0] === C.option1 && s.header[0] === C.option1 && s.url === String(C.id) && money(s.price) === C.price / 100 && s.selection === 'valid', JSON.stringify(s));
      A('P1 [staging] another variant rendered than asked: the shopper is told (alert toast)', (await page.locator('#toast-root [role="alert"]').count()) >= 1 && /ya no está disponible/.test(await page.locator('#toast-root').innerText()), await page.locator('#toast-root').innerText());
      net.remove(other);
      await chip(page, initial.option1).click();
      await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), initial.id);
      net.reset();
    }

    // ---- A -> B -> C with the answers out of order
    {
      const slowB = gate();
      const fastC = gate();
      const order = [];
      const rule2 = sectionRule(net, async (variant) => {
        order.push(`ask ${variant === B.id ? 'B' : variant === C.id ? 'C' : variant}`);
        if (variant === B.id) return { gate: slowB };
        if (variant === C.id) return { gate: fastC };
        return { type: 'pass' };
      });
      await resetWrites(page);
      await chip(page, B.option1).click();
      await chip(page, C.option1).click();
      await page.waitForFunction(() => window.Monetta && document.querySelector('[data-product-page]').getAttribute('aria-busy') === 'true');
      fastC.release(); // C answers first
      await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), C.id);
      const atC = await snapshot(page);
      slowB.release(); // B answers after C: it must change nothing
      await sleep(900);
      s = await snapshot(page);
      A('P1 [staging] A→B→C, B answers after C: the page ends on C (id, chip, header, address, price) and B\'s late answer changed nothing', s.hidden === C.id && s.chosen[0] === C.option1 && s.header[0] === C.option1 && s.url === String(C.id) && money(s.price) === C.price / 100 && JSON.stringify(s) === JSON.stringify(atC) && s.selection === 'valid', `${order.join(' · ')} | ${JSON.stringify(s)}`);
      await page.evaluate(() => document.querySelector('[data-add]').click());
      await until(page, () => window.__writes?.some((w) => w.path.endsWith('add.js')));
      sent = (await writes(page)).filter((w) => w.path.endsWith('add.js'));
      A('P1 [staging] A→B→C out of order: adding sends C', sent.length === 1 && sent[0].body.id === C.id && sent[0].hidden === C.id, JSON.stringify(sent.map((w) => w.body)));
      await closeSheet(page);
      net.remove(rule2);
      await chip(page, initial.option1).click();
      await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), initial.id);
      net.reset();
    }

    // ---- A -> B -> C where B answers (late) and C fails: the page must end on A, never on B or C
    {
      const slowB = gate();
      const failC = gate();
      const rule3 = sectionRule(net, async (variant) => {
        if (variant === B.id) return { gate: slowB };
        if (variant === C.id) return { gate: failC, type: 'status', status: 503 };
        return { type: 'pass' };
      });
      await resetWrites(page);
      await chip(page, B.option1).click();
      await chip(page, C.option1).click();
      await page.waitForFunction(() => document.querySelector('[data-product-page]').getAttribute('aria-busy') === 'true');
      slowB.release();
      await sleep(500);
      const midway = await snapshot(page);
      A('P1 [staging] A→B→C, B answers while C is pending: nothing of B is applied and buying stays closed', midway.hidden === initial.id && midway.selection === 'pending' && midway.addDisabled.every(Boolean), JSON.stringify(midway));
      failC.release();
      await until(page, () => document.querySelector('[data-product-page]').getAttribute('aria-busy') !== 'true');
      await sleep(150);
      s = await snapshot(page);
      A('P1 [staging] A→B→C, C then fails: the page ends on A everywhere (id, chip, header, address, price)', s.hidden === initial.id && s.chosen[0] === initial.option1 && s.header[0] === initial.option1 && s.url === String(initial.id) && money(s.price) === initial.price / 100 && s.selection === 'valid', JSON.stringify(s));
      net.remove(rule3);
      net.reset();
    }

    // ---- [controlled] two options: staging has no product with two options, so the page's options are replaced by two options laid over
    // four real variants (R1=A/x, R2=A/y, R3=B/x; B/y does not exist). The requests still go to Shopify for the real ids.
    {
      await closeSheet(page);
      await chip(page, initial.option1).click().catch(() => {});
      await until(page, (id) => document.querySelector('[data-variant-id]')?.value === String(id), initial.id);
      await page.evaluate(({ r1, r2, r3 }) => {
        const list = document.querySelector('[data-product-variants]');
        list.textContent = JSON.stringify([
          { id: r1, options: ['A', 'x'], available: true },
          { id: r2, options: ['A', 'y'], available: true },
          { id: r3, options: ['B', 'x'], available: true },
        ]);
        const group = (position, values) => {
          const fieldset = document.createElement('fieldset');
          fieldset.className = 'options';
          fieldset.dataset.optionPosition = String(position);
          fieldset.innerHTML = `<legend><span data-option-value>${values[0]}</span></legend>${values.map((v, i) => `<label class="option-chip"><input class="visually-hidden" type="radio" name="ctl-${position}" value="${v}"${i === 0 ? ' checked' : ''} data-option-input><span class="option-chip__label">${v}</span></label>`).join('')}`;
          return fieldset;
        };
        document.querySelector('[data-options]').replaceChildren(group(1, ['A', 'B']), group(2, ['x', 'y']));
      }, { r1: initial.id, r2: B.id, r3: C.id });
      const asked = [];
      const twoOption = sectionRule(net, (variant) => {
        asked.push(variant);
        return { gate: gate() }; // never answered: what is on screen while it waits is what is being judged
      });
      const radio = (position, value) => page.locator(`fieldset[data-option-position="${position}"] input[value="${value}"]`);
      const view = () => page.evaluate(() => ({ chosen: [...document.querySelectorAll('[data-options] fieldset')].map((g) => g.querySelector('input:checked')?.value), header: [...document.querySelectorAll('[data-option-value]')].map((e) => e.textContent) }));
      await radio(1, 'B').evaluate((el) => el.click());
      await sleep(250);
      let seen = await view();
      A('P1 [controlled] two options: choosing B with x checked requests exactly the variant A/x→B/x (R3) and shows B / x', asked.at(-1) === C.id && seen.chosen.join('/') === 'B/x' && seen.header.join('/') === 'B/x', JSON.stringify({ asked, seen }));
      twoOption.hits = 0;
      net.remove(twoOption);
      const twoOption2 = sectionRule(net, (variant) => {
        asked.push(variant);
        return { gate: gate() };
      });
      await radio(1, 'A').evaluate((el) => el.click());
      await radio(2, 'y').evaluate((el) => el.click());
      await sleep(250);
      await radio(1, 'B').evaluate((el) => el.click());
      await sleep(250);
      seen = await view();
      A('P1 [controlled] two options: B/y does not exist, so the nearest variant that keeps B (R3 = B/x) is requested and the chips show B / x at once', asked.at(-1) === C.id && seen.chosen.join('/') === 'B/x' && seen.header.join('/') === 'B/x', JSON.stringify({ asked, seen }));
      net.remove(twoOption2);
    }

    // ---- over the whole page: no cart write ever carried a variant different from the one displayed at that instant
    await writes(page);
    const allWrites = seenWrites.filter((w) => w.path.endsWith('add.js'));
    A(`P1 [staging] over all ${allWrites.length} adds of this run, the id sent equalled the variant shown, the chips and a confirmed selection at that instant`, allWrites.length >= 6 && allWrites.every((w) => w.body.id === w.hidden && w.selection === 'valid' && w.chosen[0] === product.variants.find((v) => v.id === w.body.id)?.option1), JSON.stringify(allWrites.map((w) => [w.body.id, w.hidden, w.selection, w.chosen[0]])));
    A('P1 [staging] no console or page errors from the theme during the scenarios', problems.length === 0, problems.slice(0, 4));
  } finally {
    await context.close();
  }
});

/* ================================================================================ P3 · no JavaScript */
await step('p3', 'variant choice without JavaScript', async () => {
  const { context, page } = await newPage({ javaScript: false });
  try {
    await goto(page, `${baseUrl}/products/${HANDLE}`, { incidents });
    const product = await (await context.request.get(`${baseUrl}/products/${HANDLE}.js`)).json();
    const initial = product.variants.find((v) => v.available);
    const B = product.variants.find((v) => v.available && v.option1 !== initial.option1);
    const formId = () => page.evaluate(() => Number(new FormData(document.querySelector('[data-product-form]')).get('id')));
    const view = () =>
      page.evaluate(() => {
        const shown = (el) => el.getClientRects().length > 0 && getComputedStyle(el).display !== 'none';
        return {
          radiosShown: [...document.querySelectorAll('.options__list--radios .option-chip')].filter(shown).length,
          linksShown: [...document.querySelectorAll('.options__list--links .option-chip')].filter(shown).length,
          current: [...document.querySelectorAll('.options__list--links .option-chip[aria-current="true"] .option-chip__label')].map((e) => e.textContent.trim()),
          price: document.querySelector('[data-price] .price')?.textContent.trim(),
          addDisabled: document.querySelector('[data-product-form] [data-add]')?.disabled,
          seal: !document.querySelector('[data-seal]')?.hidden,
        };
      });
    let v = await view();
    A('P3 [staging] without JavaScript, the initial variant is what the form sends', (await formId()) === initial.id, `form id ${await formId()} vs ${initial.id}`);
    A('P3 [staging] without JavaScript, no radio chip is shown (nothing that looks selectable but sends nothing); the option links are', v.radiosShown === 0 && v.linksShown >= 2 && v.current[0] === initial.option1, JSON.stringify(v));
    // choose another available variant: a native navigation
    const named = new RegExp(`^\\s*${esc(B.option1)}\\s*$`);
    const link = page.locator('.options__list--links a.option-chip', { hasText: named }).first();
    if (await link.isVisible()) {
      await Promise.all([page.waitForURL((u) => u.searchParams.get('variant') === String(B.id), { timeout: 10000 }).catch(() => {}), link.click({ timeout: 5000 }).catch(() => {})]);
    } else {
      // No link on screen: what is shown is the radio group (the audited markup), so that is what the shopper would press.
      await page.locator('.options__list--radios label.option-chip', { hasText: named }).first().click({ timeout: 5000 }).catch(() => {});
    }
    v = await view();
    A('P3 [staging] without JavaScript, choosing another available variant makes the form send exactly that variant', (await formId()) === B.id && v.current[0] === B.option1, `form id ${await formId()} vs ${B.id}; ${JSON.stringify(v.current)}`);
    A('P3 [staging] without JavaScript, the price on the page is that variant\'s price', money(v.price) === B.price / 100, `${v.price} vs ${B.price / 100}`);
    // a real native submission: the anonymous cart must gain exactly B
    const before = await (await context.request.get(`${baseUrl}/cart.js`)).json();
    await Promise.all([page.waitForURL(/\/cart(\?|$)/, { timeout: 15000 }).catch(() => {}), page.locator('[data-add]:visible').first().click({ timeout: 5000 }).catch(() => {})]);
    const after = await (await context.request.get(`${baseUrl}/cart.js`)).json();
    A('P3 [staging] without JavaScript, a native form submission adds exactly the chosen variant to the anonymous cart', after.items.length === before.items.length + 1 && after.items.some((i) => i.variant_id === B.id && i.quantity === 1) && !after.items.some((i) => i.variant_id === initial.id), JSON.stringify(after.items.map((i) => [i.variant_id, i.quantity])));
    // a sold-out variant of a multi-variant product
    const partial = await (await context.request.get(`${baseUrl}/products/bolso-steve-madden-crossbody-3.js`)).json();
    const soldOut = partial.variants.find((x) => !x.available);
    await goto(page, `${baseUrl}/products/bolso-steve-madden-crossbody-3?variant=${soldOut.id}`, { incidents });
    v = await view();
    A('P3 [staging] without JavaScript, a sold-out variant is reachable, is marked, and its add button is disabled', v.addDisabled === true && v.seal === true && v.current[0] === soldOut.option1 && v.radiosShown === 0, JSON.stringify(v));
    const soldFormId = await formId();
    A('P3 [staging] without JavaScript, the sold-out variant\'s form carries that variant (never an available one)', soldFormId === soldOut.id, `form id ${soldFormId} vs ${soldOut.id}`);
  } finally {
    await context.close();
  }
});

/* ================================================================================ P4 · structured data and canonical */
await step('p4', 'structured data on the product page', async () => {
  const { context, page } = await newPage();
  try {
    for (const handle of [HANDLE, 'bolso-steve-madden-crossbody-3']) {
      await goto(page, `${baseUrl}/products/${handle}`, { incidents });
      const product = await productJson(page, handle);
      const facts = await page.evaluate(() => {
        const blocks = [...document.querySelectorAll('script[type="application/ld+json"]')].map((s) => s.textContent);
        const parsed = [];
        const errors = [];
        for (const text of blocks) {
          try {
            parsed.push(JSON.parse(text));
          } catch (error) {
            errors.push(String(error.message));
          }
        }
        return { count: blocks.length, parsed, errors, canonical: document.querySelector('link[rel="canonical"]')?.href, description: document.querySelector('meta[name="description"]')?.content ?? null, ogTitle: document.querySelector('meta[property="og:title"]')?.content ?? null, microdata: document.querySelectorAll('[itemtype*="schema.org/Product"]').length };
      });
      const data = facts.parsed.find((d) => d['@type'] === 'ProductGroup' || d['@type'] === 'Product');
      const variants = data ? (data.hasVariant || [data]) : [];
      A(`P4 [staging] ${handle}: one valid JSON-LD block is rendered (the legacy markup had none)`, facts.count === 1 && facts.errors.length === 0 && Boolean(data), JSON.stringify({ count: facts.count, errors: facts.errors, type: data?.['@type'] }));
      A(`P4 [staging] ${handle}: its type is native (${product.variants.length > 1 ? 'ProductGroup' : 'Product'}) and it names the product`, data && data['@type'] === (product.variants.length > 1 ? 'ProductGroup' : 'Product') && data.name === product.title, JSON.stringify({ type: data?.['@type'], name: data?.name, title: product.title }));
      const wanted = product.variants.map((x) => x.id).sort();
      const offered = variants.map((x) => Number(String(x.offers?.url || x.url || '').match(/variant=(\d+)/)?.[1])).sort();
      A(`P4 [staging] ${handle}: it lists every variant Shopify has (${product.variants.length}), by id`, product.variants.length > 1 ? JSON.stringify(wanted) === JSON.stringify(offered) : true, `${offered.length} offered of ${wanted.length}`);
      const priceOk = variants.every((x) => {
        const id = Number(String(x.offers?.url || x.url || '').match(/variant=(\d+)/)?.[1]) || product.variants[0].id;
        const v = product.variants.find((y) => y.id === id);
        const offer = x.offers;
        return v && offer && Math.abs(Number(offer.price) - v.price / 100) < 0.005 && String(offer.availability).endsWith(v.available ? 'InStock' : 'OutOfStock');
      });
      A(`P4 [staging] ${handle}: each offer's price and availability equal Shopify's for that variant`, priceOk, JSON.stringify(variants.map((x) => [x.offers?.price, x.offers?.availability]).slice(0, 4)));
      A(`P4 [staging] ${handle}: canonical and page metadata are kept`, Boolean(facts.canonical) && facts.canonical.endsWith(`/products/${handle}`) && Boolean(facts.ogTitle) && facts.microdata === 0, JSON.stringify({ canonical: facts.canonical, og: facts.ogTitle, microdata: facts.microdata }));
    }
    const source = readFileSync(path.join(target.themeDir, 'sections/monetta-product.liquid'), 'utf8');
    const block = /<script type="application\/ld\+json">([\s\S]*?)<\/script>/.exec(source)?.[1] ?? '';
    A('P4 [source] the markup is produced by the native structured_data filter; the section has no literal price, availability or id in it', /\{\{\s*product\s*\|\s*structured_data\s*\}\}/.test(block) && !/\d{4,}|InStock|OutOfStock|"price"/.test(block), block.trim());
  } finally {
    await context.close();
  }
});

/* ================================================================================ P5 · load more recovery */
await step('p5', 'load more failure, recovery and native navigation', async () => {
  const listing = '/collections/all?filter.v.availability=1&sort_by=price-ascending';
  const open = async () => {
    const env = await newPage();
    await goto(env.page, `${baseUrl}${listing}`, { incidents });
    await env.page.waitForFunction(() => document.querySelector('[data-more]'));
    await settle(env.page);
    return env;
  };
  const gridCount = (page) => page.locator('[data-grid] > li').count();
  const pageTwo = (url, request) => url.pathname === '/collections/all' && url.searchParams.get('page') === '2' && request.resourceType() !== 'document';

  // 1. failure: 503 then the recovery box offers two different things
  {
    const { context, page, net } = await open();
    try {
      const first = await gridCount(page);
      const href = await page.locator('[data-more]').getAttribute('href');
      A('P5 [staging] "Ver más piezas" is a link that keeps the filters and the sort in its address', /filter\.v\.availability=1/.test(href) && /sort_by=price-ascending/.test(href) && /page=2/.test(href), href);
      net.add('fetch2', pageTwo, (route) => route.fulfill({ status: 503, contentType: 'text/plain', body: 'Controlled audit failure' }));
      await page.locator('[data-more]').click();
      await untilSelector(page, '[data-load-error]');
      A('P5 [staging] after a 503 nothing is appended and the address does not change', (await gridCount(page)) === first && new URL(page.url()).searchParams.get('page') === null, `${await gridCount(page)} items; ${page.url()}`);
      const ui = await page.evaluate(() => ({ retry: !!document.querySelector('[data-more-retry]'), native: document.querySelector('[data-more-native]')?.getAttribute('href') ?? null, interceptable: !!document.querySelector('[data-more]'), alert: document.querySelector('[data-load-error]')?.getAttribute('role'), focus: document.activeElement?.matches('[data-more-retry]') }));
      A('P5 [staging] the failure box offers a retry button and, separately, a link that is no longer intercepted (still filtered and sorted)', ui.retry && !ui.interceptable && /filter\.v\.availability=1/.test(ui.native || '') && /sort_by=price-ascending/.test(ui.native || '') && ui.alert === 'alert', JSON.stringify(ui));
      // retry while still failing: another fetch, still no navigation
      const fetchesBefore = net.count('fetch2');
      await page.locator('[data-more-retry]').click({ timeout: 3000 }).catch(() => {});
      await sleep(500);
      A('P5 [staging] retrying while Shopify still fails sends one more fetch, adds nothing and leaves the box in place', net.count('fetch2') === fetchesBefore + 1 && (await gridCount(page)) === first && (await page.locator('[data-load-error]').count()) === 1, `fetches ${net.count('fetch2')}`);
      // the native link navigates for real
      const navigations = [];
      page.on('request', (request) => request.isNavigationRequest() && request.frame() === page.mainFrame() && navigations.push(request.url()));
      await Promise.all([page.waitForURL((u) => u.searchParams.get('page') === '2', { timeout: 8000 }).catch(() => {}), page.locator('[data-more-native], [data-more]').first().click()]);
      const final = new URL(page.url());
      A('P5 [staging] the native link performs a real navigation to page 2, keeping filter and sort', navigations.length === 1 && final.searchParams.get('filter.v.availability') === '1' && final.searchParams.get('sort_by') === 'price-ascending', `${navigations.length} navigation(s); ${page.url()}`);
    } finally {
      await context.close();
    }
  }

  // 2. recovery: first fetch fails, the retry works
  {
    const { context, page, net } = await open();
    try {
      const first = await gridCount(page);
      net.add('fetch2', pageTwo, (route, request, entry, hit) => (hit === 1 ? route.fulfill({ status: 503, contentType: 'text/plain', body: 'Controlled audit failure' }) : route.continue()));
      await page.locator('[data-more]').click();
      await untilSelector(page, '[data-more-retry]');
      await page.locator('[data-more-retry]').click({ timeout: 3000 }).catch(() => {});
      await until(page, (n) => document.querySelectorAll('[data-grid] > li').length > n, first);
      const u = new URL(page.url());
      A('P5 [staging] recovery: the retry appends page 2, updates the address and keeps filter and sort', (await gridCount(page)) === first * 2 && u.searchParams.get('page') === '2' && u.searchParams.get('filter.v.availability') === '1' && u.searchParams.get('sort_by') === 'price-ascending' && (await page.locator('[data-load-error]').count()) === 0, `${await gridCount(page)} items; ${page.url()}`);
    } finally {
      await context.close();
    }
  }

  // 3. invalid answers with HTTP 200 never reach the grid or the address
  const invalid = [
    ['a body that is not a listing', '<!doctype html><html><body><p>oops</p></body></html>'],
    ['a listing page with an empty grid', '<!doctype html><html><body><ul data-grid></ul></body></html>'],
    ['a password wall', '<!doctype html><html><body><form action="/password"><input name="password"></form></body></html>'],
  ];
  for (const [name, body] of invalid) {
    const { context, page, net } = await open();
    try {
      const first = await gridCount(page);
      net.add('fetch2', pageTwo, (route) => route.fulfill({ status: 200, contentType: 'text/html', body }));
      await page.locator('[data-more]').click();
      await untilSelector(page, '[data-load-error]');
      A(`P5 [staging] HTTP 200 with ${name}: nothing is added and the address is untouched`, (await gridCount(page)) === first && new URL(page.url()).searchParams.get('page') === null, `${await gridCount(page)} items; ${page.url()}`);
    } finally {
      await context.close();
    }
  }
});

/* ================================================================================ P6 · edit search */
await step('p6', 'edit-search link on empty results', async () => {
  for (const [w, h, name] of [[375, 812, 'phone 375×812'], [1440, 900, 'desktop 1440×900']]) {
    for (const how of ['mouse', 'keyboard']) {
      const { context, page } = await newPage({ w, h });
      try {
        await goto(page, `${baseUrl}/search?q=zzcorreccionesnoexiste987&type=product`, { incidents });
        await page.waitForFunction(() => !!document.querySelector('[data-edit-search]'));
        await settle(page);
        // The search page autofocuses an empty field; with terms present nothing is focused, so start from the body.
        await page.evaluate(() => document.activeElement?.blur());
        if (how === 'mouse') {
          await page.locator('[data-edit-search]').click();
        } else {
          await page.locator('[data-edit-search]').focus();
          await page.keyboard.press('Enter');
        }
        await sleep(200);
        const seen = await page.evaluate(() => {
          const active = document.activeElement;
          const rect = active?.getBoundingClientRect();
          const visible = !!active && active.getClientRects().length > 0 && getComputedStyle(active).visibility !== 'hidden';
          const inView = !!rect && rect.top >= 0 && rect.bottom <= innerHeight && rect.left >= 0 && rect.right <= innerWidth;
          return { id: active?.id || active?.tagName, visible, inView, selected: active?.selectionStart === 0 && active?.selectionEnd === (active?.value || '').length && (active?.value || '').length > 0, value: active?.value };
        });
        A(`P6 [staging] ${name}, ${how}: the focus lands on a search field that is visible and on screen, with its text selected`, /search-input$/.test(seen.id) && seen.visible && seen.inView && seen.selected, JSON.stringify(seen));
        const href = await page.locator('[data-edit-search]').getAttribute('href');
        const hrefTarget = await page.evaluate((h) => { const el = document.querySelector(h); return !!el && el.getClientRects().length > 0; }, href);
        A(`P6 [staging] ${name}, ${how}: the link's own href (without JavaScript) points at a visible field`, hrefTarget, href);
      } finally {
        await context.close();
      }
    }
  }
});

/* ================================================================================ P8 · declared language */
await step('p8', 'declared language of the ported pages', async () => {
  const { context, page } = await newPage();
  try {
    const pages = [['home', '/'], ['collection', '/collections/all'], ['product', `/products/${HANDLE}`], ['cart', '/cart'], ['search', '/search?q=reloj&type=product']];
    for (const [name, url] of pages) {
      const response = await page.goto(`${baseUrl}${url}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
      const raw = await response.text(); // the document as served, before any script changed it
      const declared = /<html[^>]*\blang="([^"]*)"/.exec(raw)?.[1] ?? null;
      A(`P8 [staging] ${name}: the served HTML declares lang="es-MX" (read from the raw document, before any script)`, declared === 'es-MX', `lang=${declared}`);
    }
    await goto(page, `${baseUrl}/products/${HANDLE}`, { incidents });
    const facts = await page.evaluate(() => {
      const storeLang = window.MonettaConfig?.storeLang;
      const own = (root) => {
        // Visible text of the interface, leaving out fragments that declare another language.
        const clone = root.cloneNode(true);
        clone.querySelectorAll('[lang]:not(html)').forEach((el) => el.remove());
        clone.querySelectorAll('script, style, noscript, [hidden], .visually-hidden').forEach((el) => el.remove());
        return clone.textContent.toLowerCase();
      };
      const words = own(document.querySelector('main')).match(/[a-záéíóúñ]+/g) || [];
      const es = new Set(['de', 'la', 'el', 'en', 'para', 'y', 'una', 'tu', 'con', 'por', 'del', 'las', 'los', 'agregar', 'carrito', 'cantidad', 'envío', 'pieza', 'opción', 'disponible']);
      const en = new Set(['the', 'and', 'of', 'to', 'for', 'with', 'your', 'you', 'is', 'are', 'add', 'cart', 'quantity', 'shipping', 'available', 'buy', 'now']);
      return {
        storeLang,
        navLinks: [...document.querySelectorAll('.site-nav__link')].map((a) => [a.textContent.trim(), a.getAttribute('lang')]),
        pay: document.querySelector('.other-ways__pay')?.getAttribute('lang') ?? null,
        payText: document.querySelector('.shopify-payment-button__button')?.textContent.trim() ?? null,
        spanishWords: words.filter((x) => es.has(x)).length,
        englishWords: words.filter((x) => en.has(x)).length,
      };
    });
    A('P8 [staging] the page\'s own text is Spanish (more Spanish than English function words outside fragments marked with another language)', facts.spanishWords > facts.englishWords * 3, JSON.stringify({ es: facts.spanishWords, en: facts.englishWords }));
    // Since 22 Oct the theme writes Spanish for Shopify's untouched default menu titles (snippets/monetta-label.liquid), so a
    // menu title only needs the store language when it is still one of those English defaults.
    A('P8 [staging] fragments Shopify writes in the store\'s language are marked with it: menu titles and the accelerated checkout', !facts.storeLang || /^es/i.test(facts.storeLang) || (facts.navLinks.length > 0 && facts.navLinks.every(([text, lang]) => lang === facts.storeLang || !SHOPIFY_DEFAULT_MENU_TITLE.test(text)) && facts.pay === facts.storeLang), JSON.stringify({ storeLang: facts.storeLang, nav: facts.navLinks, pay: facts.pay, payText: facts.payText }));
  } finally {
    await context.close();
  }
});

/* ================================================================================ P2 + P7 · cart mutations, checkout, undo */
const bagFixture = (n, restore = null) => {
  const line = `<li class="cart-line" data-line="111:k${n}" data-variant-id="111" data-restore="${restore ? restore.replace(/"/g, '&quot;') : ''}"><a class="cart-line__name" href="/products/sample">Pieza de prueba</a><form class="cart-line__controls" data-line-form method="post" action="/cart/change"><input type="hidden" name="id" value="111:k${n}"><div class="stepper"><button type="submit" class="stepper__button" name="quantity" value="${n + 1}" data-step="1">+</button><output class="stepper__value">${n}</output><button type="submit" class="stepper__button" name="quantity" value="${n - 1}" data-step="-1">−</button></div><button type="submit" class="cart-line__remove" name="quantity" value="0" data-remove-line>Eliminar</button></form></li>`;
  const empty = '<h2 id="cart-empty" tabindex="-1">Tu bolsa está vacía</h2>';
  return `<div id="shopify-section-ctl-cart"><div data-cart-section data-section-id="ctl-cart" data-item-count="${n}"><div class="cart-sync" data-cart-sync hidden><button type="button" data-cart-resync>Actualizar bolsa</button></div>${n ? `<ul>${line}</ul><form action="/cart" method="post" id="cart-checkout-form"><button type="submit" name="checkout">Continuar al checkout</button><div class="cart-additional-checkout"><button type="button" class="accelerated" data-accelerated>Pagar con billetera</button></div></form>` : empty}</div></div>`;
};

async function controlledCart({ restore = null, quantity = 1 } = {}) {
  const env = await newPage();
  const { page, net } = env;
  const checkouts = [];
  await page.route('http://ctl.invalid/cart', (route) => route.fulfill({ contentType: 'text/html', body: `<!doctype html><html lang="es-MX"><body><div id="cart-sheet"></div>${bagFixture(quantity, restore)}</body></html>` }));
  await page.goto('http://ctl.invalid/cart');
  await page.evaluate(() => {
    window.MonettaConfig = { routes: { cart: '/cart', cartAdd: '/cart/add.js', cartChange: '/cart/change.js' }, storeLang: 'en' };
    window.Monetta = { toasts: [], toast(message, options) { this.toasts.push({ message, options }); }, announce(message) { this.announced = message; }, refreshPinnedChrome() {} };
  });
  const source = readFileSync(path.join(target.themeDir, 'assets/monetta-cart.js'), 'utf8');
  const oldSource = oldAssets.includes('monetta-cart.js') ? readFileSync(path.join(previous, 'assets/monetta-cart.js'), 'utf8') : source;
  await page.addScriptTag({ content: oldSource });
  await page.evaluate(() => {
    document.addEventListener('submit', (event) => {
      if (event.submitter?.name === 'checkout' || event.target.id === 'cart-checkout-form') {
        window.__checkouts = (window.__checkouts || 0) + 1;
        event.preventDefault(); // a controlled document has nowhere to go
      }
    });
  });
  env.checkouts = checkouts;
  return env;
}

const lockState = (page) =>
  page.evaluate(() => ({
    locked: document.documentElement.hasAttribute('data-cart-locked'),
    checkoutDisabled: [...document.querySelectorAll('[name="checkout"]')].map((b) => b.disabled),
    accelerated: [...document.querySelectorAll('.cart-additional-checkout')].map((e) => e.inert),
    notice: [...document.querySelectorAll('[data-cart-sync]')].map((e) => !e.hidden),
  }));

/** Every way out to checkout that exists on the page, without leaving a trace if it refuses. Returns how many were tried. */
async function tryCheckout(page) {
  return page.evaluate(async () => {
    let tried = 0;
    for (const button of document.querySelectorAll('[name="checkout"]')) {
      button.click();
      tried += 1;
      button.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
      tried += 1;
      button.form?.requestSubmit(button);
      tried += 1;
    }
    for (const form of document.querySelectorAll('#cart-checkout-form, .cart-drawer__buttons')) {
      form.requestSubmit();
      tried += 1;
    }
    return tried;
  });
}

async function realBag(page, lines) {
  for (const line of lines) {
    const result = await page.evaluate(async (payload) => (await fetch('/cart/add.js', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })).status, line);
    if (result !== 200) throw new Error(`could not prepare the anonymous cart (HTTP ${result})`);
  }
}

await step('p2', 'checkout is refused while a bag change is pending or unconfirmed', async () => {
  const product = await (await fetch(`${baseUrl}/products/${HANDLE}.js`)).json();
  const variant = product.variants.find((v) => v.available);
  const second = product.variants.filter((v) => v.available)[1];

  /** One operation held on the wire; every way to checkout is tried meanwhile; then released and a real checkout hand-over is made. */
  const scenarios = [
    { name: 'increment', setup: [{ id: variant.id, quantity: 1 }], act: (page) => page.locator('[data-line] [data-step="1"]').first().click(), hold: (url, request) => request.method() === 'POST' && /\/cart\/change\.js$/.test(url.pathname), expect: async (page) => (await (await page.request.get(`${baseUrl}/cart.js`)).json()).items[0].quantity === 2 },
    { name: 'decrement', setup: [{ id: variant.id, quantity: 2 }], act: (page) => page.locator('[data-line] [data-step="-1"]').first().click(), hold: (url, request) => request.method() === 'POST' && /\/cart\/change\.js$/.test(url.pathname), expect: async (page) => (await (await page.request.get(`${baseUrl}/cart.js`)).json()).items[0].quantity === 1 },
    { name: 'remove', setup: [{ id: variant.id, quantity: 1 }, { id: second.id, quantity: 1 }], act: (page) => page.locator('[data-line] [data-remove-line]').first().click(), hold: (url, request) => request.method() === 'POST' && /\/cart\/change\.js$/.test(url.pathname), expect: async (page) => (await (await page.request.get(`${baseUrl}/cart.js`)).json()).items.length === 1 },
    { name: 'undo', setup: [{ id: variant.id, quantity: 1 }, { id: second.id, quantity: 1 }], pre: async (page) => { await page.locator('[data-line] [data-remove-line]').first().click(); await page.waitForFunction(() => document.querySelectorAll('[data-line]').length === 1); await page.waitForSelector('.toast__action'); }, act: (page) => page.locator('.toast__action', { hasText: 'Deshacer' }).click(), hold: (url, request) => request.method() === 'POST' && /\/cart\/add\.js$/.test(url.pathname), expect: async (page) => (await (await page.request.get(`${baseUrl}/cart.js`)).json()).items.length === 2 },
  ];
  for (const scenario of scenarios) {
    const { context, page, net } = await newPage();
    try {
      await goto(page, `${baseUrl}/`, { incidents });
      await realBag(page, scenario.setup);
      await goto(page, `${baseUrl}/cart`, { incidents });
      await page.waitForFunction(() => !!window.Monetta?.cart);
      await settle(page);
      if (scenario.pre) await scenario.pre(page);
      const held = gate();
      const attempts = [];
      net.add('checkout-hand-over', (url, request) => request.method() === 'POST' && url.pathname === '/cart' && request.resourceType() === 'document', (route, request) => {
        attempts.push(request.postData());
        return route.fulfill({ status: 204 }); // keep the check inside the bag: nothing may enter checkout while the lock should hold
      });
      net.add('held', scenario.hold, async (route) => {
        await held.promise;
        return route.continue();
      });
      await scenario.act(page);
      await page.waitForFunction(() => document.documentElement.hasAttribute('data-cart-locked') || document.querySelector('[data-line][aria-busy="true"]'));
      for (let i = 0; i < 40 && net.count('held') === 0; i++) await sleep(50);
      A(`P2 [staging] ${scenario.name}: the change request is held on the wire`, net.count('held') === 1, `held=${net.count('held')}`);
      const during = await lockState(page);
      A(`P2 [staging] ${scenario.name}: while it is pending every checkout button is disabled and the lock flag is set`, during.locked && during.checkoutDisabled.length >= 1 && during.checkoutDisabled.every(Boolean), JSON.stringify(during));
      const tried = await tryCheckout(page);
      for (const selector of ['.summary [name="checkout"]', '.checkout-bar [name="checkout"]']) {
        const box = await page.locator(selector).first().boundingBox().catch(() => null);
        if (box) await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
      }
      // Keyboard: walk the tab order from the stepper; a checkout button that can be reached is pressed with Enter. A disabled one is
      // skipped by Tab, so with the lock in place nothing is reached and nothing is pressed.
      await page.locator('[data-line] [data-step]').first().focus();
      let reachedByKeyboard = 0;
      for (let i = 0; i < 24; i++) {
        await page.keyboard.press('Tab');
        if (await page.evaluate(() => document.activeElement?.matches?.('[name="checkout"]'))) {
          reachedByKeyboard += 1;
          await page.keyboard.press('Enter');
          break;
        }
      }
      await sleep(300);
      A(`P2 [staging] ${scenario.name}: the tab order never reaches a checkout button while the change is pending`, reachedByKeyboard === 0, `reached=${reachedByKeyboard}`);
      A(`P2 [staging] ${scenario.name}: ${tried} ways of submitting checkout (click, dispatched click, requestSubmit, form submit, mouse at the button, keyboard) send nothing`, attempts.length === 0 && net.count('checkout-hand-over') === 0, `hand-overs=${attempts.length}`);
      held.release();
      await until(page, () => !document.documentElement.hasAttribute('data-cart-locked'), null, 15000);
      const after = await lockState(page);
      A(`P2 [staging] ${scenario.name}: after the answer the lock is released and the bag matches Shopify's`, !after.locked && after.checkoutDisabled.every((d) => !d) && (await scenario.expect(page)), JSON.stringify(after));
      // positive control: a real hand-over to Shopify's checkout works once the lock is released
      if (scenario !== scenarios[0]) continue;
      net.reset();
      const hopsPromise = page.waitForRequest((request) => request.method() === 'POST' && new URL(request.url()).pathname === '/cart' && request.resourceType() === 'document', { timeout: 15000 }).catch(() => null);
      net.rules = net.rules.filter((rule) => rule.name !== 'checkout-hand-over');
      const hops = [];
      page.on('response', (r) => r.status() >= 300 && r.status() < 400 && hops.push(`${r.status()} ${new URL(r.url()).pathname} -> ${(r.headers().location || '').replace(/\/[A-Za-z0-9_-]{16,}/g, '/<token>').replace(/\?.*$/, '')}`));
      await page.locator('[name="checkout"]:visible').first().click();
      await hopsPromise;
      await sleep(2500);
      A(`P2 [staging] ${scenario.name}: positive control, with the lock released the bag hands over to Shopify's checkout of the staging store`, hops.some((h) => /myshopify\.com\/checkouts\/|\/checkouts\/cn\//.test(h)) && !hops.some((h) => /fakcei-n9|monetta\.mx/.test(h)), hops.join(' | '));
    } finally {
      await context.close();
    }
  }

  // ---- outcome not confirmed: the lock stays until the bag is read again from Shopify
  {
    const { context, page, net } = await newPage();
    try {
      await goto(page, `${baseUrl}/`, { incidents });
      await realBag(page, [{ id: variant.id, quantity: 1 }]);
      await goto(page, `${baseUrl}/cart`, { incidents });
      await page.waitForFunction(() => !!window.Monetta?.cart);
      await settle(page);
      const checkoutPosts = [];
      net.add('checkout-hand-over', (url, request) => request.method() === 'POST' && url.pathname === '/cart' && request.resourceType() === 'document', (route, request) => {
        checkoutPosts.push(request.postData());
        return route.fulfill({ status: 204 });
      });
      // the change never answers (connection dropped) and the bag cannot be read back either
      net.add('change', (url, request) => request.method() === 'POST' && /\/cart\/change\.js$/.test(url.pathname), (route) => route.abort('connectionreset'));
      const readBack = net.add('read-back', (url, request) => request.method() === 'GET' && url.pathname === '/cart' && url.searchParams.has('sections'), (route) => route.abort('connectionreset'));
      await page.locator('[data-line] [data-step="1"]').first().click();
      await until(page, () => document.querySelector('[data-cart-sync]:not([hidden])'), null, 8000);
      let state = await lockState(page);
      A('P2 [staging] transport failure and no read-back: the bag is unconfirmed, the notice shows and every checkout button stays disabled', state.locked && state.notice.some(Boolean) && state.checkoutDisabled.every(Boolean), JSON.stringify(state));
      await tryCheckout(page);
      await sleep(300);
      A('P2 [staging] transport failure and no read-back: checkout cannot be submitted', checkoutPosts.length === 0, `hand-overs=${checkoutPosts.length}`);
      const writeCount = net.count('change');
      await page.locator('[data-line] [data-step="1"]').first().click({ force: true }).catch(() => {});
      await sleep(300);
      A('P2 [staging] transport failure and no read-back: a further change is refused until the bag is confirmed (no blind second write)', net.count('change') === writeCount, `change requests ${net.count('change')}`);
      // recovery: the read-back works again; "Actualizar bolsa" reads Shopify's bag and releases the lock
      net.remove(readBack);
      await page.locator('[data-cart-resync]:visible').first().click();
      await until(page, () => !document.documentElement.hasAttribute('data-cart-locked'), null, 15000);
      state = await lockState(page);
      const shown = await page.evaluate(() => document.querySelector('[data-line] .stepper__value')?.textContent.trim());
      const truth = (await (await context.request.get(`${baseUrl}/cart.js`)).json()).items[0].quantity;
      A('P2 [staging] recovery: "Actualizar bolsa" shows Shopify\'s bag (the change never reached it) and releases the lock', !state.locked && state.checkoutDisabled.every((d) => !d) && shown === String(truth) && truth === 1, JSON.stringify({ shown, truth, state }));
    } finally {
      await context.close();
    }
  }

  // ---- 4xx refusal: Shopify's words, the bag read back, the lock released
  {
    const { context, page, net } = await newPage();
    try {
      await goto(page, `${baseUrl}/`, { incidents });
      await realBag(page, [{ id: variant.id, quantity: 1 }]);
      await goto(page, `${baseUrl}/cart`, { incidents });
      await page.waitForFunction(() => !!window.Monetta?.cart);
      net.add('change', (url, request) => request.method() === 'POST' && /\/cart\/change\.js$/.test(url.pathname), (route) => route.fulfill({ status: 422, contentType: 'application/json', body: JSON.stringify({ status: 422, message: 'Cart Error', description: 'You can only add 1 of this item to your cart.' }) }));
      await page.locator('[data-line] [data-step="1"]').first().click();
      await untilSelector(page, '#toast-root [role="alert"]');
      await until(page, () => !document.documentElement.hasAttribute('data-cart-locked'));
      const toast = await page.evaluate(() => ({ text: document.querySelector('.toast__text')?.textContent, lang: document.querySelector('.toast__text')?.lang }));
      const state = await lockState(page);
      A('P2 [staging] Shopify rejects a change (422): its message is shown, marked with the store language, and the lock is released after the bag is read back', /only add 1/.test(toast.text) && toast.lang === (await page.evaluate(() => window.MonettaConfig.storeLang)) && !state.locked, JSON.stringify({ toast, state }));
    } finally {
      await context.close();
    }
  }

  // ---- order: Deshacer pressed while a change is still pending waits for it (never two cart writes at once)
  {
    const { context, page, net } = await newPage();
    try {
      await goto(page, `${baseUrl}/`, { incidents });
      await realBag(page, [{ id: variant.id, quantity: 1 }, { id: second.id, quantity: 1 }]);
      await goto(page, `${baseUrl}/cart`, { incidents });
      await page.waitForFunction(() => !!window.Monetta?.cart);
      await page.locator('[data-line] [data-remove-line]').first().click();
      await page.waitForSelector('.toast__action');
      await page.waitForFunction(() => document.querySelectorAll('[data-line]').length === 1);
      const releaseChange = gate();
      let overlapping = 0;
      let inFlight = 0;
      const track = (name, match, hold) =>
        net.add(name, match, async (route) => {
          inFlight += 1;
          if (inFlight > 1) overlapping += 1;
          if (hold) await hold.promise;
          try {
            await route.continue();
          } finally {
            // the response is only complete once the browser has it; a short grace keeps the count honest
            setTimeout(() => (inFlight -= 1), 100);
          }
        });
      track('change', (url, request) => request.method() === 'POST' && /\/cart\/change\.js$/.test(url.pathname), releaseChange);
      track('add', (url, request) => request.method() === 'POST' && /\/cart\/add\.js$/.test(url.pathname), null);
      await page.locator('[data-line] [data-step="1"]').first().click();
      for (let i = 0; i < 40 && net.count('change') === 0; i++) await sleep(50);
      await page.locator('.toast__action', { hasText: 'Deshacer' }).click().catch(() => {});
      await sleep(400);
      const addedEarly = net.count('add');
      releaseChange.release();
      await until(page, () => !document.documentElement.hasAttribute('data-cart-locked'), null, 20000);
      A('P2 [staging] Deshacer pressed during a pending change does not run on top of it (waits its turn)', addedEarly === 0 && overlapping === 0, `add before the change finished: ${addedEarly}; overlapping writes: ${overlapping}`);
    } finally {
      await context.close();
    }
  }

  // ---- quick add on a card (the add path was reworked): exactly that variant, once, and the bag matches Shopify's
  {
    const { context, page, problems } = await newPage();
    try {
      await goto(page, `${baseUrl}/collections/all`, { incidents });
      await page.waitForFunction(() => !!window.Monetta?.cart);
      const card = page.locator('[data-quick-add]').first();
      const wanted = Number(await card.locator('input[name="id"]').inputValue());
      await card.locator('button').click();
      await until(page, () => document.querySelector('#cart-sheet')?.open, null, 10000);
      await until(page, () => !window.Monetta.cart.isLocked(), null, 10000);
      const cart = await (await context.request.get(`${baseUrl}/cart.js`)).json();
      const badge = (await page.locator('[data-cart-count]:visible').first().textContent().catch(() => '')).trim();
      A('P2 [staging] quick add on a card adds exactly that variant once, opens the sheet and updates the count', cart.items.length === 1 && cart.items[0].variant_id === wanted && cart.items[0].quantity === 1 && badge === String(cart.item_count) && (await page.evaluate(() => !document.documentElement.hasAttribute('data-cart-locked'))), JSON.stringify({ wanted, items: cart.items.map((i) => [i.variant_id, i.quantity]), badge }));
      A('P2 [staging] quick add: no console or page errors from the theme', problems.length === 0, problems.slice(0, 3));
    } finally {
      await context.close();
    }
  }

  // ---- accelerated checkout buttons while pending (controlled document: staging's cart page renders none)
  {
    const { context, page, net } = await controlledCart({ restore: JSON.stringify({ id: 111, quantity: 1, properties: {}, selling_plan: null }) });
    try {
      const held = gate();
      net.add('held', (url, request) => request.method() === 'POST' && /\/cart\/change\.js$/.test(url.pathname), async (route) => {
        await held.promise;
        return route.fulfill({ contentType: 'application/json', body: JSON.stringify({ sections: { 'ctl-cart': bagFixture(2), 'monetta-cart-sheet': '<dialog id="cart-sheet"></dialog>' } }) });
      });
      let accelerated = 0;
      await page.exposeFunction('countAccelerated', () => (accelerated += 1));
      await page.evaluate(() => document.addEventListener('click', (event) => event.target.closest('.accelerated') && window.countAccelerated(), false));
      await page.locator('[data-step="1"]').click();
      for (let i = 0; i < 40 && net.count('held') === 0; i++) await sleep(50);
      const during = await lockState(page);
      // The real accelerated buttons live in third-party frames and shadow trees, out of reach of a script; `inert` is what stops a
      // person from pressing them, so the check is the flag and a real pointer press at the button.
      const box = await page.locator('.accelerated').boundingBox();
      if (box) await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
      await page.keyboard.press('Tab');
      await page.keyboard.press('Enter');
      A('P2 [controlled] the accelerated-checkout area is inert while the change is pending: a pointer or keyboard press does not reach its button', during.accelerated.length === 1 && during.accelerated.every(Boolean) && accelerated === 0, JSON.stringify({ inert: during.accelerated, activations: accelerated }));
      held.release();
      await page.waitForFunction(() => !document.documentElement.hasAttribute('data-cart-locked'));
      const after = await lockState(page);
      A('P2 [controlled] the accelerated-checkout area is released with the lock', after.accelerated.every((i) => !i), JSON.stringify(after));
    } finally {
      await context.close();
    }
  }
});

await step('p7', 'undo restores the line, not just the variant', async () => {
  const product = await (await fetch(`${baseUrl}/products/${HANDLE}.js`)).json();
  const variant = product.variants.find((v) => v.available);
  const properties = { Grabado: 'ANA', _canal: 'prueba controlada' };

  // [staging] a personalised line next to a plain line of the same variant, in an anonymous cart
  {
    const { context, page } = await newPage();
    try {
      await goto(page, `${baseUrl}/`, { incidents });
      await realBag(page, [{ id: variant.id, quantity: 1 }, { id: variant.id, quantity: 2, properties }]);
      await goto(page, `${baseUrl}/cart`, { incidents });
      await page.waitForFunction(() => !!window.Monetta?.cart);
      await settle(page);
      const cart = await (await context.request.get(`${baseUrl}/cart.js`)).json();
      const custom = cart.items.find((i) => i.properties && i.properties.Grabado === 'ANA');
      const plain = cart.items.find((i) => !i.properties || Object.keys(i.properties).length === 0);
      A('P7 [staging] the anonymous cart has two distinct lines of the same variant (plain ×1, personalised ×2)', cart.items.length === 2 && custom?.quantity === 2 && plain?.quantity === 1 && custom.key !== plain.key, JSON.stringify(cart.items.map((i) => [i.key, i.quantity, i.properties])));
      const restoreAttr = await page.locator(`[data-line="${custom.key}"]`).getAttribute('data-restore');
      const parsed = JSON.parse(restoreAttr);
      A('P7 [staging] the rendered line carries its full identity (variant, quantity, public and private properties, selling plan)', parsed.id === variant.id && parsed.quantity === 2 && parsed.properties.Grabado === 'ANA' && parsed.properties._canal === 'prueba controlada' && parsed.selling_plan === null, restoreAttr);
      await page.locator(`[data-line="${custom.key}"] [data-remove-line]`).click();
      await page.waitForFunction(() => document.querySelectorAll('[data-line]').length === 1);
      await page.locator('.toast__action', { hasText: 'Deshacer' }).click();
      await until(page, () => document.querySelectorAll('[data-line]').length === 2, null, 8000);
      await until(page, () => !document.documentElement.hasAttribute('data-cart-locked'));
      const restored = await (await context.request.get(`${baseUrl}/cart.js`)).json();
      const customAfter = restored.items.find((i) => i.properties && i.properties.Grabado === 'ANA');
      const plainAfter = restored.items.find((i) => !i.properties || Object.keys(i.properties).length === 0);
      A('P7 [staging] Deshacer restores the personalised line with its quantity and both properties, under the same key', customAfter?.quantity === 2 && customAfter.properties._canal === 'prueba controlada' && customAfter.key === custom.key, JSON.stringify(restored.items.map((i) => [i.key, i.quantity, i.properties])));
      A('P7 [staging] the plain line of the same variant was not merged into (still ×1, nothing added to it)', plainAfter?.quantity === 1 && plainAfter.key === plain.key && restored.items.length === 2, JSON.stringify(restored.items.map((i) => [i.key, i.quantity])));
    } finally {
      await context.close();
    }
  }

  // [controlled] selling plan, rejection by Shopify, and a line whose identity cannot be read
  const removeAndUndo = async (restore, undoAnswer) => {
    const env = await controlledCart({ restore, quantity: 1 });
    const adds = [];
    env.net.add('change', (url, request) => request.method() === 'POST' && /\/cart\/change\.js$/.test(url.pathname), (route) => route.fulfill({ contentType: 'application/json', body: JSON.stringify({ sections: { 'ctl-cart': bagFixture(0), 'monetta-cart-sheet': '<dialog id="cart-sheet"></dialog>' } }) }));
    env.net.add('add', (url, request) => request.method() === 'POST' && /\/cart\/add\.js$/.test(url.pathname), (route, request) => {
      adds.push(JSON.parse(request.postData()));
      return undoAnswer(route);
    });
    env.net.add('read-back', (url, request) => request.method() === 'GET' && url.pathname === '/cart' && url.searchParams.has('sections'), (route) => route.fulfill({ contentType: 'application/json', body: JSON.stringify({ 'ctl-cart': bagFixture(0), 'monetta-cart-sheet': '<dialog id="cart-sheet"></dialog>' }) }));
    await env.page.locator('[data-remove-line]').click();
    await env.page.waitForFunction(() => window.Monetta.toasts.length >= 1 && document.querySelector('[data-line]') === null);
    return { ...env, adds };
  };
  {
    const planRestore = JSON.stringify({ id: 111, quantity: 3, properties: { Grabado: 'ANA' }, selling_plan: 777 });
    const env = await removeAndUndo(planRestore, (route) => route.fulfill({ contentType: 'application/json', body: JSON.stringify({ id: 111, variant_id: 111, quantity: 3, properties: { Grabado: 'ANA' }, selling_plan_allocation: { selling_plan: { id: 777 } }, sections: { 'ctl-cart': bagFixture(3, planRestore), 'monetta-cart-sheet': '<dialog id="cart-sheet"></dialog>' } }) }));
    try {
      await env.page.evaluate(() => window.Monetta.toasts.at(-1).options.action.onClick());
      await env.page.waitForFunction(() => document.querySelector('[data-line]'));
      A('P7 [controlled] Deshacer re-adds with the line\'s quantity, properties and selling plan (controlled plan 777; staging has no selling plans)', env.adds.length === 1 && env.adds[0].id === 111 && env.adds[0].quantity === 3 && env.adds[0].properties?.Grabado === 'ANA' && env.adds[0].selling_plan === 777, JSON.stringify(env.adds));
    } finally {
      await env.context.close();
    }
  }
  {
    const restore = JSON.stringify({ id: 111, quantity: 1, properties: { Grabado: 'ANA' }, selling_plan: null });
    const env = await removeAndUndo(restore, (route) => route.fulfill({ status: 422, contentType: 'application/json', body: JSON.stringify({ status: 422, message: 'Cart Error', description: 'Cannot restore: this item is sold out.' }) }));
    try {
      await env.page.evaluate(() => window.Monetta.toasts.at(-1).options.action.onClick());
      await env.page.waitForFunction(() => window.Monetta.toasts.length >= 2);
      await sleep(300);
      const toast = await env.page.evaluate(() => ({ last: window.Monetta.toasts.at(-1) }));
      A('P7 [controlled] if Shopify rejects the restore, its message is shown and no other line is added in its place', env.adds.length === 1 && /sold out/.test(toast.last.message) && toast.last.options?.tone === 'error' && (await env.page.locator('[data-line]').count()) === 0, JSON.stringify({ adds: env.adds, toast: toast.last.message }));
      A('P7 [controlled] the rejected restore is not retried without its properties (exactly one add, with the full identity)', env.adds.length === 1 && env.adds[0].properties?.Grabado === 'ANA', JSON.stringify(env.adds));
    } finally {
      await env.context.close();
    }
  }
  {
    const env = await removeAndUndo('{not json', (route) => route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }));
    try {
      const offered = await env.page.evaluate(() => !!window.Monetta.toasts.at(-1).options?.action);
      A('P7 [controlled] a line whose identity cannot be read offers no Deshacer (it would be a different purchase)', offered === false && env.adds.length === 0, JSON.stringify({ offered, adds: env.adds }));
    } finally {
      await env.context.close();
    }
  }
});

/* ================================================================================ verdict */
let proxy;
try {
  proxy = await proxyHealth(baseUrl, { timeoutMs: 20000 });
} catch (error) {
  proxy = { ok: false, error: String(error) };
}
run.meta.proxyHealthAfter = proxy;
A('proxy: after the run it still serves the expected theme with the local scripts (checked with bounded waits)', proxy.ok === true, proxy.ok ? '' : JSON.stringify(proxy.checks?.filter((c) => !c.pass) ?? proxy.error));
run.note(`proxy incidents during the run: ${incidents.length}${incidents.length ? ` (${incidents.map((i) => i.kind).join(', ')})` : ''}`);
await browser.close();
const result = run.finish({ complete: !only });
// A negative control is judged by the specific assertions that were expected to fail, never by "something failed".
if (isControl) {
  const failed = new Set(run.checks.filter((c) => !c.pass && (c.kind ?? 'assertion') === 'assertion').map((c) => c.name));
  const wants = (name, f) => (name.startsWith('/') && name.endsWith('/') ? new RegExp(name.slice(1, -1)).test(f) : f.includes(name));
  const missing = expected.filter((name) => ![...failed].some((f) => wants(name, f)));
  console.log(missing.length ? `CONTROL NOT DETECTED: expected failures missing: ${missing.join(' | ')}` : `CONTROL DETECTED: ${expected.length} expected failure(s) observed`);
  process.exit(missing.length ? 1 : 0);
}
process.exit(result.summary.failed ? 1 : 0);
