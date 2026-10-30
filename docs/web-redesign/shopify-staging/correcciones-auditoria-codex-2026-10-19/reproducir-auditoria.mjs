// Copia de audit-codex-2026-10-19/reproduce.mjs (lógica sin cambios) para repetir las reproducciones de la auditoría ANTES de corregir.
// Diferencias, todas de procedencia y no de lógica: la carpeta de salida se elige con --out (la auditoría original no se toca),
// los casos de carrito cargan el monetta-cart.js previo guardado en codigo-previo/ y el resultado lleva el estado del código y la salud del proxy.
//   node docs/web-redesign/shopify-staging/correcciones-auditoria-codex-2026-10-19/reproducir-auditoria.mjs --out=antes     (código auditado)
//   node docs/web-redesign/shopify-staging/correcciones-auditoria-codex-2026-10-19/reproducir-auditoria.mjs --out=despues   (código corregido)
// En «despues» cada caso conserva SU aserción (`defectReproduced` debe ser false); solo cambian selectores y pasos que el defecto hacía
// posibles y la corrección hace imposibles, y cada uno está marcado con `ADAPTADO (despues)`:
//   · sin JavaScript los chips son enlaces, no radios: se pulsa el enlace de la otra opción;
//   · tras un fallo de «Ver más piezas» el enlace deja de interceptarse y aparece «Reintentar»: se prueba el reintento y el enlace;
//   · el botón de checkout queda deshabilitado mientras la mutación está pendiente: el clic se intenta con espera acotada;
//   · el documento de prueba del carrito lleva `data-restore`, como lo emite ahora la línea del carrito.
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const base_dir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(base_dir, '../../../..');
const outArg = process.argv.find((a) => a.startsWith('--out='));
const AFTER = outArg?.slice(6) === 'despues';
if (!outArg) throw new Error('usa --out=<carpeta dentro de correcciones-auditoria-codex-2026-10-19>');
const here = path.resolve(base_dir, outArg.slice(6));
if (path.relative(base_dir, here).startsWith('..')) throw new Error('la salida debe quedar dentro de la carpeta de correcciones');
const require = createRequire(path.join(root, 'design-prototype/package.json'));
const { chromium } = require('playwright-core');
const base = process.env.AUDIT_BASE_URL || 'http://127.0.0.1:9292';
const product = '/products/reloj-coach-talia-saddle';
const results = { startedAt: new Date().toISOString(), mode: AFTER ? 'despues (código corregido)' : 'antes (código auditado)', base, mutationsSentToShopify: 0, cases: [] };
mkdirSync(here, { recursive: true });
const browser = await chromium.launch({ executablePath: '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser', headless: true });

async function context(options = {}) {
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, ...options });
  await ctx.route('**/*', async (route) => {
    if (!['GET', 'HEAD', 'OPTIONS'].includes(route.request().method())) {
      await route.fulfill({ status: 409, contentType: 'application/json', body: JSON.stringify({ message: 'Commerce mutation blocked by independent audit' }) });
    } else await route.continue();
  });
  return ctx;
}
async function visit(page, url) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const res = await page.goto(base + url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    if (res?.ok() && await page.locator('body.mw').count()) return;
  }
  throw new Error('Proxy did not serve the expected theme document: ' + url);
}
async function run(name, action) {
  try {
    const detail = await action();
    results.cases.push({ name, ...detail });
    console.log(JSON.stringify({ name, ...detail }));
  } catch (error) {
    results.cases.push({ name, auditError: String(error.stack || error) });
    console.log(name + ': AUDIT ERROR ' + error.message);
  }
  writeFileSync(path.join(here, 'browser-evidence.json'), JSON.stringify(results, null, 2) + '\n');
}

await run('control-variant-after-server-response', async () => {
  const ctx = await context();
  const page = await ctx.newPage();
  try {
    await visit(page, product);
    await page.waitForFunction(() => !!window.Monetta?.cart?.add);
    const chosen = await page.evaluate(() => {
      window.auditAdds = [];
      window.Monetta.cart.add = async (payload) => { window.auditAdds.push(payload); return { ok: true, status: 200 }; };
      const initial = Number(document.querySelector('[data-variant-id]').value);
      const variants = JSON.parse(document.querySelector('[data-product-variants]').textContent);
      const current = variants.find((v) => v.id === initial);
      const target = variants.find((v) => v.available && v.options[0] !== current.options[0]);
      const radio = [...document.querySelectorAll('[data-options] fieldset:first-child input')].find((i) => i.value === target.options[0]);
      radio.checked = true;
      radio.dispatchEvent(new Event('change', { bubbles: true }));
      return target.id;
    });
    await page.waitForFunction((id) => document.querySelector('[data-variant-id]').value === String(id), chosen);
    await page.locator('.product-panel [data-add]').click();
    const sent = await page.evaluate(() => window.auditAdds[0]?.id);
    return { source: 'live rendered theme, real section response, add stubbed', controlPassed: sent === chosen, chosen, sent };
  } finally { await ctx.close(); }
});

await run('variant-change-pending-and-failed', async () => {
  const ctx = await context();
  const page = await ctx.newPage();
  try {
    await visit(page, product);
    await page.waitForFunction(() => !!window.Monetta?.cart?.add);
    await page.route('**/*', async (route) => {
      const u = new URL(route.request().url());
      if (u.pathname === product && u.searchParams.has('section_id')) {
        await page.waitForTimeout(1800);
        return route.fulfill({ status: 503, body: 'Controlled audit failure', contentType: 'text/plain' });
      }
      return route.fallback();
    });
    const pending = await page.evaluate(() => {
      window.auditAdds = [];
      window.Monetta.cart.add = async (payload) => { window.auditAdds.push(payload); return { ok: true, status: 200 }; };
      const root = document.querySelector('[data-product-page]');
      const initial = Number(document.querySelector('[data-variant-id]').value);
      const variants = JSON.parse(document.querySelector('[data-product-variants]').textContent);
      const current = variants.find((v) => v.id === initial);
      const target = variants.find((v) => v.available && v.options[0] !== current.options[0]);
      const radio = [...document.querySelectorAll('[data-options] fieldset:first-child input')].find((i) => i.value === target.options[0]);
      radio.checked = true;
      radio.dispatchEvent(new Event('change', { bubbles: true }));
      const snapshot = { initial, target: target.id, selectedOption: radio.value, hiddenVariant: Number(document.querySelector('[data-variant-id]').value), busy: root.getAttribute('aria-busy'), addDisabled: document.querySelector('.product-panel [data-add]').disabled };
      document.querySelector('.product-panel [data-add]').click();
      return snapshot;
    });
    await page.waitForTimeout(100);
    const addWhilePending = await page.evaluate(() => window.auditAdds.map(({ id, quantity }) => ({ id, quantity })));
    await page.locator('.product-panel__options').screenshot({ path: path.join(here, 'variant-pending.png') });
    await page.waitForFunction(() => document.querySelector('#toast-root [role="alert"]'));
    const afterError = await page.evaluate(() => {
      document.querySelector('.product-panel [data-add]').click();
      return { selectedOption: document.querySelector('[data-options] input:checked').value, hiddenVariant: Number(document.querySelector('[data-variant-id]').value), addDisabled: document.querySelector('.product-panel [data-add]').disabled, calls: window.auditAdds.map(({ id }) => id) };
    });
    return { source: 'live rendered theme, add stubbed, variant fetch delayed then 503', defectReproduced: addWhilePending[0]?.id === pending.initial && pending.target !== pending.initial, pending, addWhilePending, afterError };
  } finally { await ctx.close(); }
});

await run('variant-without-javascript', async () => {
  const ctx = await context({ javaScriptEnabled: false });
  const page = await ctx.newPage();
  try {
    await visit(page, product);
    const before = await page.locator('[data-variant-id]').inputValue();
    const radios = page.locator('[data-options] fieldset').first().locator('input');
    if (AFTER) {
      // ADAPTADO (despues): sin JavaScript la opción se elige con un enlace nativo (?variant=ID); los radios no se muestran.
      const links = page.locator('.options__list--links a.option-chip:not([aria-current="true"])');
      await Promise.all([page.waitForURL((u) => u.searchParams.has('variant') && u.searchParams.get('variant') !== before, { timeout: 15000 }), links.first().click()]);
    } else {
      let target;
      for (let i = 0; i < await radios.count(); i++) if (!(await radios.nth(i).isChecked())) { target = radios.nth(i); break; }
      await target.locator('..').click();
    }
    const observed = await page.evaluate(() => {
      const form = document.querySelector('[data-product-form]');
      const selectedOption = (form.querySelector('[data-options] input:checked') || {}).value ?? [...document.querySelectorAll('.options__list--links .option-chip[aria-current="true"] .option-chip__label')].map((e) => e.textContent.trim())[0];
      const expectedVariant = JSON.parse(document.querySelector('[data-product-variants]').textContent).find((v) => v.options[0] === selectedOption)?.id;
      return { selectedOption, expectedVariant, nativeFormId: new FormData(form).get('id'), availableFallbackVariantSelect: !!form.querySelector('select[name="id"]'), addDisabled: form.querySelector('[data-add]').disabled };
    });
    return { source: 'live rendered theme, JavaScript disabled, native FormData (form not submitted)', defectReproduced: Number(observed.nativeFormId) !== observed.expectedVariant, initialVariant: before, ...observed };
  } finally { await ctx.close(); }
});

await run('product-structured-data-and-language', async () => {
  const ctx = await context();
  const page = await ctx.newPage();
  try {
    await visit(page, product);
    const observed = await page.evaluate(() => ({
      lang: document.documentElement.lang,
      jsonLdCount: document.querySelectorAll('script[type="application/ld+json"]').length,
      microdataProducts: document.querySelectorAll('[itemtype*="schema.org/Product"]').length,
      addCopy: document.querySelector('[data-add]')?.textContent.trim(),
      canonical: document.querySelector('link[rel="canonical"]')?.href,
    }));
    return { source: 'live rendered theme', defectReproduced: observed.jsonLdCount === 0 && observed.microdataProducts === 0, ...observed };
  } finally { await ctx.close(); }
});

await run('search-empty-edit-link-on-phone', async () => {
  const ctx = await context({ viewport: { width: 375, height: 812 } });
  const page = await ctx.newPage();
  try {
    await visit(page, '/search?q=codexauditnotfound7654321&type=product');
    await page.locator('[data-edit-search]').click();
    const observed = await page.evaluate(() => {
      const edit = document.querySelector('[data-edit-search]');
      const target = document.querySelector(edit.getAttribute('href'));
      return { href: edit.getAttribute('href'), targetVisible: !!target?.getClientRects().length, activeElement: document.activeElement?.id || document.activeElement?.tagName, realSearchVisible: !!document.querySelector('#page-search-input')?.getClientRects().length };
    });
    await page.screenshot({ path: path.join(here, 'search-edit-on-phone.png') });
    return { source: 'live rendered theme, 375x812', defectReproduced: !observed.targetVisible && observed.activeElement !== 'page-search-input', ...observed };
  } finally { await ctx.close(); }
});

await run('load-more-retry-fallback', async () => {
  const ctx = await context();
  const page = await ctx.newPage();
  try {
    await visit(page, '/collections/all');
    let failedFetches = 0;
    let documentNavigations = 0;
    await page.route('**/*', async (route) => {
      const req = route.request();
      const u = new URL(req.url());
      if (u.pathname === '/collections/all' && u.searchParams.get('page') === '2') {
        if (req.isNavigationRequest()) { documentNavigations++; return route.fallback(); }
        failedFetches++;
        return route.fulfill({ status: 503, contentType: 'text/plain', body: 'Controlled audit failure' });
      }
      return route.fallback();
    });
    await page.locator('[data-more]').click();
    if (AFTER) {
      // ADAPTADO (despues): el aviso ahora es un cuadro con «Reintentar» y un enlace aparte que ya no se intercepta. Se prueba lo que
      // el defecto impedía: que, tras el fallo, ir a la página siguiente sea una navegación real.
      await page.waitForSelector('[data-load-error]');
      await page.locator('[data-more-native]').click();
      await page.waitForURL((u) => u.searchParams.get('page') === '2', { timeout: 15000 }).catch(() => {});
    } else {
      await page.waitForSelector('#toast-root [role="alert"]');
      await page.locator('[data-more]').click();
    }
    await page.waitForTimeout(150);
    return { source: 'live rendered theme, controlled 503 for next page', defectReproduced: AFTER ? documentNavigations === 0 : failedFetches === 2 && documentNavigations === 0, failedFetches, documentNavigations, url: page.url(), toast: await page.locator('#toast-root').innerText() };
  } finally { await ctx.close(); }
});

// Cart fixtures exercise the unchanged production JS with controlled Section Rendering responses.
// They do not claim that the test product in staging has a selling plan or line properties.
const restoreAttr = AFTER ? ` data-restore='{"id":111,"quantity":1,"properties":{"Grabado":"ANA"},"selling_plan":null}'` : '';
const cartMarkup = (quantity = 1) => `<div id="shopify-section-audit-cart"><div data-cart-section data-section-id="audit-cart" data-item-count="${quantity}">${quantity ? `<li data-line="111:custom" data-variant-id="111"${restoreAttr}><a class="cart-line__name" href="/products/sample">Audit item</a><p class="cart-line__variant">Grabado: ANA</p><form data-line-form method="post" action="/cart/change"><input name="id" value="111:custom"><output class="stepper__value">${quantity}</output><button data-step="1" name="quantity" value="${quantity + 1}">+</button><button data-remove-line name="quantity" value="0">Eliminar</button></form></li><form action="/cart" method="post" id="cart-checkout-form"><button name="checkout">Continuar al checkout</button></form>` : '<h2 id="cart-empty" tabindex="-1">Tu bolsa está vacía</h2>'}</div></div>`;
async function cartFixture() {
  const ctx = await context();
  const page = await ctx.newPage();
  await page.route('http://monetta-audit.invalid/cart', (route) => route.fulfill({ contentType: 'text/html', body: `<html><body>${cartMarkup()}</body></html>` }));
  await page.goto('http://monetta-audit.invalid/cart');
  await page.evaluate(() => {
    window.MonettaConfig = { routes: { cart: '/cart', cartAdd: '/cart/add.js', cartChange: '/cart/change.js' } };
    window.Monetta = { toast(message, options) { window.auditToast = { message, options }; }, refreshPinnedChrome() {} };
  });
  await page.addScriptTag({ content: readFileSync(AFTER ? path.join(root, 'storefront-theme/assets/monetta-cart.js') : path.join(base_dir, 'codigo-previo/assets/monetta-cart.js'), 'utf8') });
  return { ctx, page };
}

await run('checkout-during-cart-change', async () => {
  const { ctx, page } = await cartFixture();
  let release;
  const pending = new Promise((resolve) => { release = resolve; });
  try {
    await page.route('**/cart/change.js', async (route) => {
      await pending;
      await route.fulfill({ contentType: 'application/json', body: JSON.stringify({ sections: { 'audit-cart': cartMarkup(2) } }) });
    });
    await page.evaluate(() => {
      window.auditCheckout = [];
      document.addEventListener('submit', (event) => {
        if (event.submitter?.name === 'checkout') {
          window.auditCheckout.push({ pending: document.querySelector('[data-line]').getAttribute('aria-busy'), shownQuantity: document.querySelector('.stepper__value').textContent });
          event.preventDefault(); // prevent a real navigation in this fixture
        }
      });
    });
    await page.locator('[data-step="1"]').click();
    // ADAPTADO (despues): con el bloqueo el botón está deshabilitado; el clic se intenta con espera acotada y puede no producirse.
    await page.locator('[name="checkout"]').click(AFTER ? { timeout: 2500 } : {}).catch((error) => { if (!AFTER) throw error; });
    const observed = await page.evaluate(() => ({ checkout: window.auditCheckout, checkoutDisabled: document.querySelector('[name="checkout"]').disabled }));
    release();
    await page.waitForFunction(() => document.querySelector('.stepper__value')?.textContent === '2');
    return { source: 'controlled DOM fixture with unchanged monetta-cart.js; request held pending', defectReproduced: observed.checkout[0]?.pending === 'true' && !observed.checkoutDisabled, ...observed };
  } finally { release(); await ctx.close(); }
});

await run('undo-preserves-line-identity', async () => {
  const { ctx, page } = await cartFixture();
  const calls = [];
  try {
    await page.route('**/cart/*.js', async (route) => {
      const data = route.request().postDataJSON();
      calls.push({ pathname: new URL(route.request().url()).pathname, data });
      const removed = new URL(route.request().url()).pathname === '/cart/change.js';
      await route.fulfill({ contentType: 'application/json', body: JSON.stringify({ sections: { 'audit-cart': cartMarkup(removed ? 0 : 1) } }) });
    });
    await page.locator('[data-remove-line]').click();
    await page.waitForFunction(() => !!window.auditToast?.options?.action);
    await page.evaluate(() => window.auditToast.options.action.onClick());
    const added = calls.find((x) => x.pathname === '/cart/add.js')?.data;
    return { source: 'controlled cart fixture with line property Grabado=ANA and unchanged monetta-cart.js', defectReproduced: !!added && !added.properties, originalProperties: { Grabado: 'ANA' }, restoredPayload: added };
  } finally { await ctx.close(); }
});

results.finishedAt = new Date().toISOString();
writeFileSync(path.join(here, 'browser-evidence.json'), JSON.stringify(results, null, 2) + '\n');
await browser.close();
