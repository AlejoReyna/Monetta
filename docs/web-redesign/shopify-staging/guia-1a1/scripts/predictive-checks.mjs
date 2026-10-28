// F9 acceptance checks use real Shopify section responses. Network faults are injected only for the race/error cases.
import { launch, settle } from '../../scripts/e2e/lib.mjs';

export async function predictiveChecks({ run, open, overflow, platformFonts, inputPlatformFonts }) {
  for (const [w, h] of [[390, 844], [768, 1024], [1024, 768], [1440, 900]]) {
    const { browser, context, page } = await launch({ width: w, height: h, hasTouch: w === 390 });
    page.setDefaultTimeout(20000);
    const id = w < 768 ? '#page-search-input' : '#header-search-input';
    const check = (name, pass, detail) => run.check(`F9 ${w}: ${name}`, pass, detail);
    try {
      await open(page, w < 768 ? '/search' : '/');
      const input = page.locator(id);
      const root = page.locator(`monetta-predictive-search:has(${id})`);
      if (!check('the existing field is connected to predictive search', await root.count() === 1)) continue;
      const panel = root.locator('[data-monetta-predictive-panel]');
      const options = root.locator('[data-monetta-predictive-option]');
      const live = root.locator('[data-monetta-predictive-live]');
      const ready = (state) => page.waitForFunction(({ id, state }) => document.querySelector(id)?.closest('monetta-predictive-search')?.dataset.state === state, { id, state });
      const requests = [];
      page.on('request', (request) => { if (request.url().includes('/search/suggest?')) requests.push(new URL(request.url())); });
      await page.evaluate(() => { localStorage.removeItem('monetta:recent-searches'); window.dispatchEvent(new Event('monetta:recent-searches-change')); });
      await input.fill('c');
      await page.waitForTimeout(350);
      check('one character makes no API request and opens no panel', requests.length === 0 && !(await panel.isVisible()));
      await input.fill('co');
      await ready('results');
      check('two characters open suggestions, up to six products and view all', await panel.isVisible() && await root.locator('[data-predictive-kind="query"]').count() > 0 && await root.locator('[data-predictive-kind="product"]').count() > 0 && await root.locator('[data-predictive-kind="product"]').count() <= 6 && await root.locator('[data-predictive-kind="all"]').count() === 1);
      check('API requests query, product and collection with six results each', requests.some((url) => url.searchParams.get('resources[type]') === 'query,product,collection' && url.searchParams.get('resources[limit]') === '6' && url.searchParams.get('resources[limit_scope]') === 'each' && url.searchParams.get('resources[options][unavailable_products]') === 'last' && url.searchParams.get('section_id') === 'monetta-predictive-results'));
      const highlights = await root.locator('[data-predictive-kind="query"] mark').allTextContents();
      check('the written part is highlighted in query suggestions', highlights.length > 0 && highlights.every((t) => t.toLowerCase() === 'co'), highlights);
      const productRows = await root.locator('[data-predictive-kind="product"]').evaluateAll((rows) => rows.map((row) => ({ image: !!row.querySelector('img'), vendor: row.querySelector('[data-predictive-vendor]')?.textContent.trim(), title: row.querySelector('.monetta-predictive-search__title')?.textContent.trim(), price: row.querySelector('.monetta-predictive-search__price')?.textContent.trim() })));
      check('products include a picture, brand, name and price', productRows.length > 0 && productRows.every((r) => r.image && r.vendor && r.title && /\$/.test(r.price)), productRows);
      const aria = await input.evaluate((node) => ({ role: node.getAttribute('role'), expanded: node.getAttribute('aria-expanded'), autocomplete: node.getAttribute('aria-autocomplete'), list: document.getElementById(node.getAttribute('aria-controls'))?.getAttribute('role') }));
      check('combobox controls an expanded listbox; polite region announces results', aria.role === 'combobox' && aria.expanded === 'true' && aria.autocomplete === 'list' && aria.list === 'listbox' && await live.getAttribute('aria-live') === 'polite' && /^\d+ resultados$/.test(await live.textContent()), aria);
      const all = root.locator('[data-predictive-kind="all"]');
      const allURL = new URL(await all.getAttribute('href'), page.url());
      check('view all includes the query and product type', await all.textContent() === 'Ver todos los resultados para «co»' && allURL.pathname === '/search' && allURL.searchParams.get('q') === 'co' && allURL.searchParams.get('type') === 'product');
      const targets = await options.evaluateAll((nodes) => nodes.map((n) => n.getBoundingClientRect().height));
      check('all options are at least 48px high and fit the viewport', targets.every((height) => height >= 48) && await overflow(page) <= 1, targets);
      const inputFonts = await inputPlatformFonts(page, id, 'typed');
      const optionFonts = await platformFonts(page, `${id === '#page-search-input' ? '.search-page' : '.site-header'} .monetta-predictive-search__title`);
      check('input and panel text are drawn in Playfair Display', inputFonts.length > 0 && inputFonts.every((f) => /Playfair/.test(f)) && optionFonts.length > 0 && optionFonts.every((f) => /Playfair/.test(f)), { inputFonts, optionFonts });
      if (w === 390 || w === 1440) {
        await settle(page);
        await page.screenshot({ path: run.file(`f9-${w}-results.png`) });
      }
      await input.press('ArrowDown');
      const first = await input.getAttribute('aria-activedescendant');
      await input.press('ArrowDown');
      const second = await input.getAttribute('aria-activedescendant');
      await input.press('ArrowUp');
      check('arrows change the active option while focus stays in the input', first && first !== second && await input.getAttribute('aria-activedescendant') === first && await input.evaluate((node) => document.activeElement === node));
      const queryURL = new URL(await options.first().getAttribute('href'), page.url());
      await Promise.all([page.waitForURL((url) => url.pathname === queryURL.pathname && url.searchParams.get('q') === queryURL.searchParams.get('q')), input.press('Enter')]);
      check('Enter navigates the active query to product search', new URL(page.url()).searchParams.get('type') === 'product');
      await open(page, w < 768 ? '/search' : '/');
      await input.fill('co');
      await ready('results');
      await input.press('Escape');
      check('first Escape closes the panel and keeps the query', !(await panel.isVisible()) && await input.inputValue() === 'co' && !(await input.getAttribute('aria-activedescendant')));
      await input.press('Escape');
      check('second Escape clears the query', await input.inputValue() === '');
      await input.fill('co');
      await ready('results');
      const requestCount = requests.length;
      await root.locator('[data-search-clear]').click();
      check('the existing clear button empties and keeps input focus', await input.inputValue() === '' && await input.evaluate((node) => document.activeElement === node));
      await input.fill('co');
      await ready('results');
      check('repeated queries reuse session cache', requests.length === requestCount);
      await input.press('Tab');
      check('Tab closes the panel and leaves the input', !(await panel.isVisible()) && !(await input.evaluate((node) => document.activeElement === node)));
      await input.focus();
      await ready('results');
      await page.locator('h1').first().click();
      check('click outside closes the panel', !(await panel.isVisible()));
      await input.fill('zzqx');
      await ready('empty');
      check('empty state names the query, offers four real categories and announces no results', (await panel.textContent()).includes('No encontramos resultados para «zzqx»') && (await root.locator('[data-predictive-kind="category"]').allTextContents()).join('|') === 'Bolsas|Carteras|Relojes|Perfumes' && await live.textContent() === 'Sin resultados');
      if (w === 390 || w === 1440) await page.screenshot({ path: run.file(`f9-${w}-empty.png`) });
      await page.evaluate(() => { localStorage.setItem('monetta:recent-searches', JSON.stringify(['Coach', 'Guess'])); window.dispatchEvent(new Event('monetta:recent-searches-change')); });
      await input.fill('');
      await ready('recent');
      check('empty focused input shows the shared recent history', (await root.locator('[data-predictive-kind="recent"]').allTextContents()).join('|') === 'Coach|Guess');
      if (w === 390 || w === 1440) await page.screenshot({ path: run.file(`f9-${w}-recent.png`) });
      await root.locator('[data-predictive-remove]').first().click();
      const history = await page.evaluate(() => JSON.parse(localStorage.getItem('monetta:recent-searches')));
      check('removing a recent updates the one shared key', history.join('|') === 'Guess' && await root.locator('[data-predictive-kind="recent"]').count() === 1, history);
      await open(page, '/search');
      check('the search page reads the same updated history', (await page.locator('[data-guia-recent-list] a span').allTextContents()).join('|') === 'Guess');
      await page.locator('.guia-search__remove').click();
      await page.locator('#page-search-input').focus();
      check('removing from the page also empties the predictive history', await page.evaluate(() => localStorage.getItem('monetta:recent-searches')) === '[]' && !(await page.locator('monetta-predictive-search:has(#page-search-input) [data-monetta-predictive-panel]').isVisible()));

      await open(page, w < 768 ? '/search' : '/');
      // Return a real older response late even though its signal is aborted, exercising the generation guard too.
      await page.evaluate(() => {
        const original = window.fetch;
        window.fetch = async (url, init) => {
          if (new URL(url, location.href).searchParams.get('q') !== 'michael') return original(url, init);
          init.signal.addEventListener('abort', () => { window.__predictiveAborted = true; });
          const response = await original(url, { ...init, signal: undefined });
          window.__predictiveOlderReady = true;
          await new Promise((resolve) => { window.__releasePredictiveOlder = resolve; });
          return response;
        };
      });
      await input.fill('michael');
      await page.waitForFunction(() => window.__predictiveOlderReady);
      await input.fill('guess');
      await ready('results');
      await page.evaluate(() => window.__releasePredictiveOlder());
      await page.waitForTimeout(300);
      check('an aborted older response cannot replace the newer results', await page.evaluate(() => window.__predictiveAborted === true) && (await root.locator('[data-predictive-vendor]').allTextContents()).every((v) => /guess/i.test(v)) && (await all.textContent()).includes('«guess»'));
      await page.route('**/search/suggest?*', (route) => route.fulfill({ status: 503, body: 'unavailable' }));
      await input.fill('failure-case');
      await page.waitForTimeout(700);
      check('API failure silently closes the panel', !(await panel.isVisible()));
      await Promise.all([page.waitForURL((url) => url.pathname === '/search' && url.searchParams.get('q') === 'failure-case'), input.press('Enter')]);
      check('Enter still submits normally after API failure', new URL(page.url()).searchParams.get('type') === 'product');
      await page.unroute('**/search/suggest?*');
      await open(page, w < 768 ? '/search' : '/');
      await input.fill('co');
      await ready('results');
      const product = root.locator('[data-predictive-kind="product"]').first();
      const destination = new URL(await product.getAttribute('href'), page.url());
      await Promise.all([page.waitForURL((url) => url.pathname === destination.pathname), product.click()]);
      check('click or touch on a product reaches its URL', new URL(page.url()).pathname === destination.pathname);

      const native = await context.newPage();
      await native.route('**/*', (route) => route.request().resourceType() === 'script' ? route.abort() : route.continue());
      await open(native, w < 768 ? '/search' : '/');
      await native.locator(id).fill('coach');
      await Promise.all([native.waitForURL((url) => url.pathname === '/search' && url.searchParams.get('q') === 'coach'), native.locator(id).press('Enter')]);
      check('with scripts blocked, Enter still performs native product search', new URL(native.url()).searchParams.get('type') === 'product');
      await native.close();
      for (const width of [320, 390, 768, 1024, 1440]) {
        await page.setViewportSize({ width, height: h });
        await open(page, width < 768 ? '/search' : '/');
        await page.locator(width < 768 ? '#page-search-input' : '#header-search-input').fill('co');
        await page.waitForSelector('monetta-predictive-search[data-state="results"]');
        check(`open panel has no overflow at ${width}px`, await overflow(page) <= 1);
      }
    } catch (error) {
      check('checks complete without an unexpected error', false, String(error.stack || error));
    } finally {
      await browser.close();
    }
  }
}
