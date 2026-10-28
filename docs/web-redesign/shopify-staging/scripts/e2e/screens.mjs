// Screenshot set of the first delivery, taken only after fonts and every image are complete and decoded, plus contact sheets so the
// set can be reviewed by eye. Writes under runs/<stamp>-screens/ (explicit, never over an earlier set) and an index.json with the
// per-capture image report. A capture whose images did not load is flagged in the index instead of passing silently.
//
//   node screens.mjs --base-url=http://127.0.0.1:9292 [--viewports=375x812,...] [--insets=44]
import { writeFileSync, readFileSync } from 'node:fs';
import { Run, launch, parseArgs, settle, imageReport } from './lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const insetPx = args.insets === undefined ? 0 : Number(args.insets);
const viewports = (args.viewports || '375x812,440x956,768x1024,1024x768,1440x900,320x640,812x375,1024x200')
  .split(',')
  .map((v) => v.split('x').map(Number));
const run = new Run(`screens${insetPx ? `-insets${insetPx}` : ''}`, { baseUrl, extra: { viewports, insetPx } });
const PRODUCT = '/products/reloj-coach-talia-saddle';
const SOLD_OUT = '/products/bolso-steve-madden-crossbody-3';

const index = [];

async function gotoOk(page, url, tries = 4) {
  for (let i = 1; i <= tries; i += 1) {
    await page.goto(url, { waitUntil: 'load' });
    const broken = await page.evaluate(() => /Failed to render storefront|Bad Gateway/i.test(document.body?.innerText || ''));
    if (!broken) return;
    run.note(`proxy error page for ${url} (attempt ${i}); retrying`);
    await page.waitForTimeout(3000);
  }
  throw new Error(`proxy kept answering with an error page for ${url}`);
}

for (const [w, h] of viewports) {
  const { browser, page } = await launch({ width: w, height: h, insets: insetPx || null });
  page.setDefaultTimeout(30000);
  const phone = w < 768;
  const take = async (name, { full = false, prepare = null } = {}) => {
    try {
      if (prepare) await prepare();
      const stuck = await settle(page);
      const images = await imageReport(page);
      const file = `${w}x${h}-${name}.png`;
      await page.screenshot({ path: run.file(file), fullPage: full });
      index.push({ file, viewport: `${w}x${h}`, name, brokenImages: images.broken.length + stuck.length, visibleImages: images.total });
      run.check(`${w}×${h} ${name}: captured with every visible image loaded and decoded`, images.broken.length === 0 && stuck.length === 0, images.broken.concat(stuck).slice(0, 3));
    } catch (error) {
      run.check(`${w}×${h} ${name}: captured`, false, String(error.message).split('\n')[0]);
    }
  };
  try {
    await take('home', { prepare: () => gotoOk(page, `${baseUrl}/`) });
    if (w >= 375) await take('home-full', { full: true });
    await take('collection', { prepare: () => gotoOk(page, `${baseUrl}/collections/all`) });
    await take('collection-filtered', { prepare: () => gotoOk(page, `${baseUrl}/collections/all?filter.v.availability=1&sort_by=price-ascending`) });
    if (w < 1200 && h > 480) {
      await take('collection-filters-drawer', {
        prepare: async () => {
          await gotoOk(page, `${baseUrl}/collections/all`);
          await page.locator('[data-open-dialog="filters-drawer"]:visible').first().click();
          await page.waitForSelector('#filters-drawer.is-open');
          await page.waitForTimeout(500);
        },
      });
    }
    if (phone && h > 480) {
      await take('menu-drawer', {
        prepare: async () => {
          await gotoOk(page, `${baseUrl}/`);
          await page.locator('.site-header__menu').click();
          await page.waitForSelector('#menu-drawer.is-open');
          await page.waitForTimeout(500);
        },
      });
    }
    await take('product', { prepare: () => gotoOk(page, `${baseUrl}${PRODUCT}`) });
    await take('product-full', {
      full: true,
      prepare: async () => {
        await page.evaluate(() => document.querySelector('[data-recommendations]')?.scrollIntoView());
        await page.waitForSelector('.rail--recs .card', { timeout: 20000 }).catch(() => {});
        await page.evaluate(() => scrollTo(0, 0));
      },
    });
    const soldOutId = await page.evaluate(async (p) => (await (await fetch(`${p}.js`)).json()).variants.find((v) => !v.available)?.id, SOLD_OUT);
    await take('product-soldout-variant', { prepare: () => gotoOk(page, `${baseUrl}${SOLD_OUT}?variant=${soldOutId}`) });
    await take('search', { prepare: () => gotoOk(page, `${baseUrl}/search?q=bolsa&type=product`) });
    await take('search-empty', { prepare: () => gotoOk(page, `${baseUrl}/search`) });
    await take('bag-empty', { prepare: () => gotoOk(page, `${baseUrl}/cart`) });
    await take('bag', {
      prepare: async () => {
        await gotoOk(page, `${baseUrl}${PRODUCT}`);
        await page.evaluate(async () => {
          const p = await (await fetch(`${location.pathname}.js`)).json();
          const v = p.variants.find((x) => x.available);
          await fetch('/cart/add.js', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: v.id, quantity: 2 }) });
        });
        await gotoOk(page, `${baseUrl}/cart`);
      },
    });
  } catch (error) {
    run.check(`${w}×${h} — unexpected error`, false, String(error.message).split('\n')[0]);
  } finally {
    await browser.close();
  }
}

writeFileSync(run.file('index.json'), `${JSON.stringify(index, null, 2)}\n`);

// Contact sheets: one per viewport, the viewport-sized captures side by side, so each set can be opened and looked at.
const { browser, page } = await launch({ width: 1800, height: 1000 });
for (const [w, h] of viewports) {
  const items = index.filter((i) => i.viewport === `${w}x${h}` && !/-full$/.test(i.name));
  if (!items.length) continue;
  const cell = Math.min(420, Math.floor(1760 / Math.min(items.length, 6)));
  const html = `<body style="margin:0;background:#ddd;font:12px sans-serif"><div style="display:flex;flex-wrap:wrap;gap:8px;padding:8px">${items
    .map((i) => `<figure style="margin:0;width:${cell}px"><img style="width:100%;display:block;border:1px solid #999;background:#fff" src="data:image/png;base64,${readFileSync(run.file(i.file)).toString('base64')}"><figcaption>${i.name}${i.brokenImages ? ' — BROKEN IMAGES' : ''}</figcaption></figure>`)
    .join('')}</div></body>`;
  await page.setContent(html);
  await page.evaluate(() => Promise.all([...document.images].map((im) => im.decode())));
  await page.screenshot({ path: run.file(`sheet-${w}x${h}.png`), fullPage: true });
}
await browser.close();

const result = run.finish({ complete: !args.viewports });
process.exit(result.summary.failed ? 1 : 0);
