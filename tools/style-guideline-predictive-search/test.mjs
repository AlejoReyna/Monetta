import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { existsSync } from 'node:fs';
import { mkdir, writeFile, readFile } from 'node:fs/promises';
import path from 'node:path';
import { startServer } from './demo.mjs';
import { evidence, theme, products, responseHTML } from './fixture.mjs';

const require = createRequire(import.meta.url);
const { chromium } = require('../../design-prototype/node_modules/playwright-core');
const axePath = require.resolve('../../design-prototype/node_modules/axe-core/axe.min.js');
const executablePath = [
  process.env.PREDICTIVE_BROWSER,
  '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  chromium.executablePath(),
].find((candidate) => candidate && existsSync(candidate));
if (!executablePath) throw new Error('No installed Chromium browser. Set PREDICTIVE_BROWSER; do not install dependencies.');

const server = await startServer();
const browser = await chromium.launch({ executablePath, headless: true });
await mkdir(path.join(evidence, 'screenshots'), { recursive: true });
const report = {
  timestamp: new Date().toISOString(),
  scope: 'Local HTML fixtures; real delivered JS/CSS; simulated Shopify section responses. No store validation or uploads.',
  browser: { executablePath, version: browser.version() },
  tests: [],
};
const selector = (name) => '[data-monetta-predictive-' + name + ']';
const instance = (page, index = 0) => page.locator('monetta-predictive-search').nth(index);
const input = (page, index = 0) => instance(page, index).locator(selector('input'));
async function state(page, expected, index = 0) {
  await page.waitForFunction(({ expected, index }) => document.querySelectorAll('monetta-predictive-search')[index]?.dataset.state === expected, { expected, index });
}
const isClosed = async (page, index = 0) => {
  assert.equal(await instance(page, index).locator(selector('panel')).isVisible(), false);
  assert.equal(await input(page, index).getAttribute('aria-expanded'), 'false');
  assert.equal(await input(page, index).getAttribute('aria-activedescendant'), null);
};
async function open(page, term = 'bolsa', index = 0) {
  await input(page, index).fill(term);
  await state(page, 'results', index);
}
async function nextPaint(page) {
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}
async function controlledFetch(page) {
  await page.addInitScript(() => {
    const original = window.fetch;
    window.__requests = [];
    window.fetch = (url, options = {}) => {
      if (!String(url).includes('/search/suggest')) return original(url, options);
      return new Promise((resolve, reject) => {
        window.__requests.push({
          url: String(url), signal: options.signal,
          resolve: (html, status = 200) => resolve(new Response(html, { status, headers: { 'Content-Type': 'text/html' } })),
          reject,
        });
      }); // Intentionally ignore abort to test the stale-response guard.
    };
  });
}
async function waitRequests(page, count) {
  await page.waitForFunction((count) => window.__requests.length === count, count);
}
async function resolveRequest(page, index, title, status = 200) {
  const html = responseHTML(title === null ? [] : [{ ...products[0], title }]);
  await page.evaluate(({ index, html, status }) => window.__requests[index].resolve(html, status), { index, html, status });
  await nextPaint(page);
}
async function preventSubmission(page) {
  await instance(page).locator('form').evaluate((form) => form.addEventListener('submit', (event) => event.preventDefault()));
}
async function test(name, run, options = {}) {
  const context = await browser.newContext({ viewport: { width: 834, height: 1000 }, ...options });
  const page = await context.newPage();
  page.setDefaultTimeout(7000);
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  const started = Date.now();
  try {
    await run(page, context);
    assert.deepEqual(errors, [], 'No uncaught browser exceptions');
    report.tests.push({ name, passed: true, milliseconds: Date.now() - started });
    console.log('PASS ' + name);
  } catch (error) {
    const screenshot = path.join(evidence, 'screenshots', 'failure-' + report.tests.length + '.png');
    await page.screenshot({ path: screenshot }).catch(() => {});
    report.tests.push({ name, passed: false, milliseconds: Date.now() - started, error: error.stack, pageErrors: errors });
    console.error('FAIL ' + name + '\n' + error.stack);
  } finally {
    await context.close();
  }
}

try {
  await test('Debounce, Shopify locale endpoint, real fragment destinations, images and price display', async (page) => {
    const requests = [];
    page.on('request', (request) => { if (request.url().includes('/search/suggest')) requests.push(new URL(request.url())); });
    await page.goto(server.url);
    await input(page).fill('b');
    await input(page).fill('bo');
    await input(page).fill('bolsa & piel');
    await state(page, 'results');
    assert.equal(requests.length, 1);
    const url = requests[0];
    assert.equal(url.pathname, '/es-mx/search/suggest');
    for (const [key, value] of Object.entries({
      q: 'bolsa & piel', 'resources[type]': 'product', 'resources[limit]': '6',
      'resources[limit_scope]': 'each', 'resources[options][unavailable_products]': 'last',
      section_id: 'monetta-predictive-results',
    })) assert.equal(url.searchParams.get(key), value);
    assert.equal(await instance(page).locator(selector('option')).count(), 3);
    const first = instance(page).locator(selector('option')).first();
    assert.match(await first.getAttribute('href'), /\/es-mx\/products\/bolsa-muestra.*variant=100/);
    assert.match(await first.textContent(), /\$1,250.00 MXN/);
    await page.waitForFunction(() => document.querySelector('[data-monetta-predictive-option] img')?.naturalWidth > 0);
    assert.match(await instance(page).locator(selector('live')).textContent(), /Sugerencias de productos: 3/);
    assert.equal(await instance(page).locator(selector('list')).getAttribute('aria-busy'), 'false');
  });

  await test('Out-of-order response cannot overwrite the newest results even when fetch ignores abort', async (page) => {
    await controlledFetch(page);
    await page.goto(server.url);
    await input(page).fill('primera');
    await waitRequests(page, 1);
    await input(page).fill('segunda');
    await waitRequests(page, 2);
    assert.equal(await page.evaluate(() => window.__requests[0].signal.aborted), true);
    await resolveRequest(page, 1, 'Resultado actual');
    await state(page, 'results');
    await resolveRequest(page, 0, 'Resultado obsoleto');
    assert.match(await instance(page).locator(selector('list')).textContent(), /Resultado actual/);
    assert.doesNotMatch(await instance(page).locator(selector('list')).textContent(), /obsoleto/);
  });

  await test('Response arriving during debounce is discarded immediately', async (page) => {
    await controlledFetch(page);
    await page.goto(server.url);
    await input(page).fill('vieja');
    await waitRequests(page, 1);
    await input(page).fill('nueva');
    await resolveRequest(page, 0, 'Obsoleto en debounce');
    assert.equal(await instance(page).getAttribute('data-state'), 'loading');
    assert.equal(await instance(page).locator(selector('option')).count(), 0);
    await waitRequests(page, 2);
    await resolveRequest(page, 1, 'Nueva búsqueda');
    await state(page, 'results');
  });

  await test('Network failure announces error and Enter keeps the native GET search working', async (page) => {
    await page.route('**/search/suggest?**', (route) => route.abort('internetdisconnected'));
    await page.goto(server.url);
    await input(page).fill('bolsa azul');
    await state(page, 'error');
    assert.match(await instance(page).locator(selector('live')).textContent(), /no están disponibles/);
    const all = new URL(await instance(page).locator(selector('all')).getAttribute('href'));
    assert.equal(all.pathname, '/es-mx/search');
    assert.equal(all.searchParams.get('q'), 'bolsa azul');
    await Promise.all([page.waitForURL('**/es-mx/search?**'), input(page).press('Enter')]);
    const destination = new URL(page.url());
    assert.equal(destination.searchParams.get('q'), 'bolsa azul');
    assert.equal(destination.searchParams.get('type'), 'product');
    assert.equal(destination.searchParams.get('options[prefix]'), 'last');
    assert.match(await page.locator('[data-demo-submitted]').textContent(), /bolsa azul/);
  });

  await test('Empty results and the all-results link preserve the full query', async (page) => {
    await page.goto(server.url);
    await input(page).fill('vacío');
    await state(page, 'empty');
    assert.equal(await instance(page).locator(selector('option')).count(), 0);
    assert.match(await instance(page).locator(selector('message')).textContent(), /Sin productos/);
    const all = instance(page).locator(selector('all'));
    assert.equal(await all.isVisible(), true);
    await Promise.all([page.waitForURL('**/es-mx/search?**'), all.click()]);
    assert.equal(new URL(page.url()).searchParams.get('q'), 'vacío');
  });

  await test('HTTP 417/429/503 and malformed section responses degrade to a usable search', async (page) => {
    await page.goto(server.url);
    for (const status of [417, 429, 503, 200]) {
      await page.route('**/search/suggest?**', (route) => route.fulfill({ status, contentType: 'text/html', body: '<html><body>Unexpected document</body></html>' }));
      await input(page).fill('error-' + status);
      await state(page, 'error');
      assert.equal(await instance(page).locator(selector('all')).isVisible(), true);
      assert.equal(await instance(page).locator(selector('list')).getAttribute('aria-busy'), 'false');
      await page.unroute('**/search/suggest?**');
    }
  });

  await test('A stalled request times out and its late response cannot reopen results', async (page) => {
    await controlledFetch(page);
    await page.goto(server.url);
    await page.clock.install();
    await input(page).fill('sin respuesta');
    await page.clock.fastForward(230);
    await waitRequests(page, 1);
    await page.clock.fastForward(8010);
    await state(page, 'error');
    assert.equal(await page.evaluate(() => window.__requests[0].signal.aborted), true);
    await resolveRequest(page, 0, 'Demasiado tarde');
    assert.equal(await instance(page).getAttribute('data-state'), 'error');
  });

  await test('Keyboard arrows wrap, maintain combobox focus and Enter opens the selected Shopify destination', async (page) => {
    await page.goto(server.url);
    await open(page);
    const field = input(page);
    await field.press('ArrowUp');
    let active = await field.getAttribute('aria-activedescendant');
    assert.equal(await instance(page).locator('#' + active).textContent().then((text) => text.includes('Reloj')), true);
    await field.press('ArrowDown');
    active = await field.getAttribute('aria-activedescendant');
    assert.equal(await instance(page).locator('#' + active).getAttribute('aria-selected'), 'true');
    assert.equal(await field.evaluate((element) => element === document.activeElement), true);
    await Promise.all([page.waitForURL('**/es-mx/products/bolsa-muestra?**'), field.press('Enter')]);
    assert.equal(new URL(page.url()).searchParams.get('variant'), '100');
  });

  await test('Escape preserves the query, aborts pending work, and late responses remain closed', async (page) => {
    await controlledFetch(page);
    await page.goto(server.url);
    await input(page).fill('pendiente');
    await waitRequests(page, 1);
    await input(page).press('Escape');
    await isClosed(page);
    assert.equal(await input(page).inputValue(), 'pendiente');
    assert.equal(await page.evaluate(() => window.__requests[0].signal.aborted), true);
    await resolveRequest(page, 0, 'Ignorado después de cerrar');
    await isClosed(page);
  });

  await test('Close, clear, Tab, outside pointer and focus use independent, non-trapping controls', async (page) => {
    await page.goto(server.url);
    await open(page);
    await input(page).press('ArrowDown');
    await input(page).press('Tab');
    assert.equal(await instance(page).locator(selector('clear')).evaluate((element) => element === document.activeElement), true);
    assert.equal(await input(page).getAttribute('aria-activedescendant'), null);
    await instance(page).locator(selector('close')).click();
    await isClosed(page);
    assert.equal(await input(page).evaluate((element) => element === document.activeElement), true);
    assert.equal(await instance(page).locator(selector('list')).getAttribute('aria-busy'), 'false');
    await input(page).fill('cartera');
    await state(page, 'results');
    await page.locator('#outside').click();
    await isClosed(page);
    await input(page).focus();
    await state(page, 'results');
    await page.locator('#outside').focus();
    await isClosed(page);
    await input(page).focus();
    await state(page, 'results');
    await instance(page).locator(selector('clear')).click();
    assert.equal(await input(page).inputValue(), '');
    assert.equal(await instance(page).locator(selector('clear')).isVisible(), false);
    await isClosed(page);
  });

  await test('Multiple instances isolate requests, active IDs, focus and query state', async (page) => {
    await controlledFetch(page);
    await page.goto(server.url);
    await input(page).fill('primaria');
    await waitRequests(page, 1);
    await input(page, 1).fill('secundaria');
    await waitRequests(page, 2);
    await resolveRequest(page, 1, 'Solo secundaria');
    await state(page, 'results', 1);
    await resolveRequest(page, 0, 'No debe abrir primaria');
    await isClosed(page);
    assert.equal(await input(page).inputValue(), 'primaria');
    assert.equal(await input(page, 1).inputValue(), 'secundaria');
    assert.match(await instance(page, 1).locator(selector('list')).textContent(), /Solo secundaria/);
    const ids = await page.locator('[id]').evaluateAll((elements) => elements.map((element) => element.id));
    assert.equal(new Set(ids).size, ids.length);
  });

  await test('Reconnect and repeated module tags do not duplicate requests or clear events with monetta-core.js', async (page) => {
    let requests = 0;
    page.on('request', (request) => { if (request.url().includes('/search/suggest')) requests += 1; });
    await page.goto(server.url + '/?core=1&autofocus=1');
    await page.waitForFunction(() => !!window.Monetta?.openDialog);
    await open(page);
    assert.equal(requests, 1);
    await input(page).evaluate((element) => {
      window.__inputEvents = 0;
      element.addEventListener('input', () => window.__inputEvents++);
    });
    await instance(page).locator(selector('clear')).click();
    assert.equal(await page.evaluate(() => window.__inputEvents), 1);
    await instance(page).evaluate((element) => {
      const parent = element.parentElement;
      element.remove();
      parent.append(element);
    });
    await open(page, 'reconectada');
    assert.equal(requests, 2);
    assert.equal(await page.locator('[data-search-clear]').count(), 0);
    assert.equal(await page.locator('.search-field').count(), 0);
  });

  await test('Reconnect with the same query rejects responses from the previous connection', async (page) => {
    await controlledFetch(page);
    await page.goto(server.url + '/?q=misma');
    await input(page).focus();
    await waitRequests(page, 1);
    await instance(page).evaluate((element) => {
      const parent = element.parentElement;
      element.remove();
      parent.append(element);
    });
    await input(page).focus();
    await waitRequests(page, 2);
    assert.equal(await page.evaluate(() => window.__requests[0].signal.aborted), true);
    await resolveRequest(page, 1, 'Vigente tras reconectar');
    await state(page, 'results');
    await resolveRequest(page, 0, 'Respuesta de la conexión anterior');
    assert.match(await instance(page).locator(selector('list')).textContent(), /Vigente tras reconectar/);
    assert.doesNotMatch(await instance(page).locator(selector('list')).textContent(), /conexión anterior/);
  });

  await test('Inside the current Monetta dialog, first Escape closes suggestions and second closes the dialog', async (page) => {
    await page.goto(server.url + '/?core=1');
    await page.waitForFunction(() => !!window.Monetta?.openDialog);
    await instance(page).evaluate((element) => {
      const dialog = document.createElement('dialog');
      dialog.id = 'demo-dialog';
      dialog.className = 'overlay';
      const panel = document.createElement('div');
      panel.className = 'overlay__panel';
      element.querySelector('input[type=search]').setAttribute('data-autofocus', '');
      panel.append(element);
      dialog.append(panel);
      document.body.prepend(dialog);
      window.__dialogCancellations = 0;
      dialog.addEventListener('cancel', () => window.__dialogCancellations++);
      window.Monetta.openDialog(dialog, document.querySelector('#outside'));
    });
    await open(page);
    await input(page).press('Escape');
    await isClosed(page);
    assert.equal(await page.locator('#demo-dialog').evaluate((dialog) => dialog.open), true);
    await input(page).press('Escape');
    await page.waitForFunction(() => !document.querySelector('#demo-dialog').open);
    assert.equal(await page.evaluate(() => window.__dialogCancellations), 1);
  });

  for (const mode of ['getter', 'methods']) {
    await test('Blocked localStorage (' + mode + ') retains recent searches in memory and can clear them', async (page) => {
      await page.addInitScript((mode) => {
        if (mode === 'getter') Object.defineProperty(window, 'localStorage', { get() { throw new DOMException('Blocked', 'SecurityError'); } });
        else for (const method of ['getItem', 'setItem']) Storage.prototype[method] = () => { throw new DOMException('Blocked', 'SecurityError'); };
      }, mode);
      await page.goto(server.url);
      await preventSubmission(page);
      await open(page, 'bolsa guardada');
      await input(page).press('Enter');
      await instance(page).locator(selector('clear')).click();
      await state(page, 'recent');
      assert.equal(await instance(page).locator(selector('option')).first().textContent(), 'bolsa guardada');
      await instance(page).locator(selector('forget')).click();
      await isClosed(page);
      assert.match(await instance(page).locator(selector('live')).textContent(), /Historial.*borrado/);
      await input(page).fill('x');
      await instance(page).locator(selector('clear')).click();
      await isClosed(page);
    });
  }

  await test('History persists on reload, is scoped by locale, and recent Enter retains the original query', async (page) => {
    await page.goto(server.url);
    await preventSubmission(page);
    await open(page, 'bolsa café');
    await input(page).press('Enter');
    await page.reload();
    await input(page).focus();
    await state(page, 'recent');
    assert.equal(await instance(page).locator(selector('option')).first().textContent(), 'bolsa café');
    await input(page).press('ArrowDown');
    await Promise.all([page.waitForURL('**/es-mx/search?**'), input(page).press('Enter')]);
    assert.equal(new URL(page.url()).searchParams.get('q'), 'bolsa café');
    await page.goto(server.url + '/?locale=en');
    await input(page).focus();
    await isClosed(page);
    await open(page);
    assert.equal(await instance(page).getAttribute('lang'), 'en');
    const all = new URL(await instance(page).locator(selector('all')).getAttribute('href'));
    assert.equal(all.pathname, '/en-us/search');
    assert.match(await instance(page).locator(selector('live')).textContent(), /Product suggestions/);
  });

  await test('Corrupt storage and untrusted recent strings stay safe and usable', async (page) => {
    const key = 'monetta:predictive:recent:v1:' + server.url + '/es-mx/search:es-MX:MX:MXN';
    await page.addInitScript(({ key }) => { localStorage.setItem(key, 'broken-json'); }, { key });
    await page.goto(server.url);
    await input(page).focus();
    await isClosed(page);
    await page.evaluate(({ key }) => {
      localStorage.setItem(key, JSON.stringify(['<img src=x onerror=alert(1)>', null, {}, 'uno', 'UNO', ...Array.from({ length: 14 }, (_, index) => 'término ' + index)]));
      window.dispatchEvent(new StorageEvent('storage', { key }));
    }, { key });
    await state(page, 'recent');
    const options = instance(page).locator(selector('option'));
    assert.equal(await options.count(), 5);
    assert.equal(await options.first().textContent(), '<img src=x onerror=alert(1)>');
    assert.equal(await options.first().locator('img').count(), 0);
    assert.equal((await options.allTextContents()).filter((text) => text.toLowerCase() === 'uno').length, 1);
  });

  await test('IME composition waits for completion before requesting suggestions', async (page) => {
    let requests = 0;
    page.on('request', (request) => { if (request.url().includes('/search/suggest')) requests++; });
    await page.goto(server.url);
    await input(page).focus();
    await input(page).dispatchEvent('compositionstart');
    await input(page).fill('日本');
    await page.waitForTimeout(300);
    assert.equal(requests, 0);
    await input(page).dispatchEvent('compositionend');
    await state(page, 'results');
    assert.equal(requests, 1);
  });

  await test('Without JavaScript, the label, submit button and GET destination work', async (page) => {
    await page.goto(server.url);
    assert.equal(await input(page).getAttribute('role'), null);
    assert.equal(await instance(page).locator(selector('clear')).isVisible(), false);
    await input(page).fill('sin JavaScript');
    await Promise.all([page.waitForURL('**/es-mx/search?**'), input(page).press('Enter')]);
    assert.equal(new URL(page.url()).searchParams.get('q'), 'sin JavaScript');
  }, { javaScriptEnabled: false });

  await test('Without fetch support, enhancement leaves the GET form usable', async (page) => {
    await page.addInitScript(() => { window.fetch = undefined; });
    await page.goto(server.url);
    assert.equal(await input(page).getAttribute('role'), null);
    await input(page).fill('sin sugerencias');
    await Promise.all([page.waitForURL('**/es-mx/search?**'), input(page).press('Enter')]);
    assert.equal(new URL(page.url()).searchParams.get('q'), 'sin sugerencias');
  });

  for (const width of [390, 834, 1440]) {
    for (const scale of [1, 2]) {
      await test('Layout ' + width + 'px, text ' + scale * 100 + '%, long names and accessible controls', async (page) => {
        await page.goto(server.url);
        if (scale === 2) await page.evaluate(() => { document.documentElement.style.fontSize = '200%'; });
        await open(page, 'nombre muy largo');
        await nextPaint(page);
        const metrics = await instance(page).evaluate((element) => {
          const panel = element.querySelector('[data-monetta-predictive-panel]');
          const rect = panel.getBoundingClientRect();
          const controls = [...element.querySelectorAll('button:not([hidden]), [data-monetta-predictive-all]')];
          return {
            viewport: { width: innerWidth, height: innerHeight },
            scrollWidth: document.documentElement.scrollWidth,
            panel: { x: rect.x, y: rect.y, right: rect.right, bottom: rect.bottom },
            overflow: [...element.querySelectorAll('[data-monetta-predictive-option], .monetta-predictive-search__toolbar, .monetta-predictive-search__footer')].some((item) => item.scrollWidth > item.clientWidth + 1),
            targets: controls.map((control) => {
              const box = control.getBoundingClientRect();
              return { width: box.width, height: box.height, overflow: control.scrollWidth > control.clientWidth + 1 };
            }),
            nameClamp: getComputedStyle(element.querySelector('.monetta-predictive-search__title')).webkitLineClamp,
          };
        });
        assert.ok(metrics.scrollWidth <= width + 1, 'No page-level horizontal overflow');
        assert.ok(metrics.panel.x >= 0 && metrics.panel.right <= width + 1, 'Panel stays inside horizontal viewport');
        assert.ok(metrics.panel.y >= 0 && metrics.panel.bottom <= metrics.viewport.height + 1, 'Panel stays inside vertical viewport');
        assert.equal(metrics.overflow, false, 'Long names and action text wrap');
        assert.ok(metrics.targets.every((target) => target.width >= 48 && target.height >= 48 && !target.overflow), 'Controls keep usable targets and uncut text');
        assert.ok(metrics.nameClamp === 'none' || metrics.nameClamp === '', 'Names are not clamped');
        const panel = instance(page).locator(selector('panel'));
        await panel.evaluate((element) => { element.scrollTop = element.scrollHeight; });
        await nextPaint(page);
        const footer = await instance(page).locator(selector('all')).boundingBox();
        const panelBox = await panel.boundingBox();
        assert.ok(footer.y >= panelBox.y && footer.y + footer.height <= panelBox.y + panelBox.height + 1, 'All-results action is reachable by scrolling');
        await panel.evaluate((element) => { element.scrollTop = 0; });
        await page.screenshot({ path: path.join(evidence, 'screenshots', 'predictive-' + width + '-' + scale * 100 + '.png') });
        await page.addScriptTag({ path: axePath });
        const accessibility = await instance(page).evaluate(async (element) => window.axe.run(element, {
          runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] },
        }));
        assert.deepEqual(accessibility.violations.map((violation) => ({ id: violation.id, description: violation.description })), [], 'Component axe checks');
      }, { viewport: { width, height: 1000 } });
    }
  }

  await test('Narrow right-edge field clamps the panel, follows resize and closes when its container hides', async (page) => {
    await page.goto(server.url);
    await page.locator('.demo-secondary').evaluate((element) => { element.style.cssText = 'position:fixed;right:0;top:110px;width:190px;margin:0'; });
    await open(page, 'borde', 1);
    let panel = await instance(page, 1).locator(selector('panel')).boundingBox();
    assert.ok(panel.x >= 0 && panel.x + panel.width <= 1440);
    await instance(page, 1).evaluate((element) => { element.style.setProperty('--safe-right', '32px'); });
    await page.setViewportSize({ width: 834, height: 700 });
    await nextPaint(page);
    panel = await instance(page, 1).locator(selector('panel')).boundingBox();
    assert.ok(panel.x >= 0 && panel.x + panel.width <= 834 - 32);
    await page.locator('.demo-secondary').evaluate((element) => { element.style.display = 'none'; });
    await state(page, 'closed', 1);
    await page.locator('.demo-secondary').evaluate((element) => { element.style.display = ''; });
    await nextPaint(page);
    await isClosed(page, 1);
  }, { viewport: { width: 1440, height: 1000 } });

  await test('Short mobile viewport places suggestions above the field without clipping actions', async (page) => {
    await page.goto(server.url);
    await page.locator('.demo-primary').evaluate((element) => { element.style.cssText = 'position:fixed;bottom:8px;left:12px;right:12px'; });
    await instance(page).evaluate((element) => {
      element.style.setProperty('--safe-left', '40px');
      element.style.setProperty('--safe-right', '28px');
      element.style.setProperty('--safe-bottom', '30px');
    });
    await open(page);
    const panel = await instance(page).locator(selector('panel')).boundingBox();
    const anchor = await instance(page).locator(selector('anchor')).boundingBox();
    assert.ok(panel.y >= 0);
    assert.ok(panel.y + panel.height < anchor.y);
    assert.ok(panel.x >= 40 && panel.x + panel.width <= 390 - 28);
  }, { viewport: { width: 390, height: 360 } });

  // Source contracts complement browser fixtures; Theme Check parses all Liquid separately.
  const snippet = await readFile(path.join(theme, 'snippets/monetta-predictive-search.liquid'), 'utf8');
  const response = await readFile(path.join(theme, 'sections/monetta-predictive-results.liquid'), 'utf8');
  assert.ok(snippet.includes('routes.search_url') && snippet.includes('routes.predictive_search_url'));
  assert.ok(response.includes('product.url | escape') && response.includes('money_with_currency') && response.includes('product.title | escape'));
  assert.ok(response.includes('product.featured_media.preview_image') && response.includes('image_url: width: 144'));
} finally {
  report.passed = report.tests.filter((test) => test.passed).length;
  report.failed = report.tests.length - report.passed;
  await writeFile(path.join(evidence, 'test-results.json'), JSON.stringify(report, null, 2) + '\n');
  await browser.close();
  await server.close();
}
console.log('\n' + report.passed + '/' + report.tests.length + ' checks passed; ' + report.failed + ' failed.');
if (report.failed) process.exitCode = 1;
