// Accessibility scan with axe-core (already a dependency of the prototype; nothing is installed) on every page of the first delivery
// and the guide 1:1 pages, in its closed state and with each dialog open, at a phone and a desktop width. Serious and critical findings fail the run.
//
//   node axe.mjs --base-url=http://127.0.0.1:9292
import { createRequire } from 'node:module';
import path from 'node:path';
import { Run, launch, parseArgs, root, settle } from './lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const require = createRequire(path.join(root, 'design-prototype/package.json'));
const axePath = require.resolve('axe-core/axe.min.js');
const run = new Run('axe', { baseUrl, extra: { axe: require('axe-core/package.json').version } });
const PRODUCT = '/products/reloj-coach-talia-saddle';

async function scan(page, label) {
  await page.addScriptTag({ path: axePath });
  const res = await page.evaluate(async () => {
    const r = await axe.run(document, { resultTypes: ['violations'] });
    return r.violations.map((v) => ({ id: v.id, impact: v.impact, help: v.help, nodes: v.nodes.slice(0, 3).map((n) => n.target.join(' ')) }));
  });
  const serious = res.filter((v) => v.impact === 'serious' || v.impact === 'critical');
  run.check(`${label}: no serious or critical axe violations`, serious.length === 0, serious.slice(0, 4).map((v) => `${v.id} (${v.impact}): ${v.nodes.join(' | ')}`));
  const rest = res.filter((v) => !serious.includes(v));
  if (rest.length) run.note(`${label}: ${rest.length} minor/moderate finding(s): ${rest.map((v) => `${v.id}/${v.impact}`).join(', ')}`);
}

for (const [w, h] of [[375, 812], [1440, 900]]) {
  const { browser, page } = await launch({ width: w, height: h, reducedMotion: 'reduce' });
  page.setDefaultTimeout(30000);
  const open = async (url) => {
    for (let i = 0; i < 4; i += 1) {
      await page.goto(`${baseUrl}${url}`, { waitUntil: 'load' });
      if (!(await page.evaluate(() => /Failed to render storefront/i.test(document.body.innerText)))) break;
      await page.waitForTimeout(3000);
    }
    await settle(page);
  };
  try {
    for (const [name, url] of [['home', '/'], ['collection', '/collections/all'], ['product', PRODUCT], ['search results', '/search?q=bolsa&type=product'], ['search empty', '/search'], ['bag empty', '/cart'], ['Categorías', '/collections'], ['Mayoreo', '/pages/contact?view=guia-mayoreo'], ['Contacto', '/pages/contact?view=guia-contacto'], ['Rewards', '/pages/contact?view=guia-rewards']]) {
      await open(url);
      await scan(page, `${w}×${h} ${name}`);
    }
    // Dialogs open.
    await open('/collections/all');
    // From 1200px the filters live in the sidebar and the drawer button is hidden by design.
    if (w < 1200) {
      await page.locator('[data-open-dialog="filters-drawer"]:visible').first().click();
      await page.waitForSelector('#filters-drawer.is-open');
      await page.waitForTimeout(450);
      await scan(page, `${w}×${h} collection with the filters drawer open`);
    }
    await open('/');
    if (w < 768) {
      await page.locator('.site-header__menu').click();
      await page.waitForSelector('#menu-drawer.is-open');
      await page.waitForTimeout(450);
      await scan(page, `${w}×${h} home with the menu drawer open`);
    }
    // The guide's quick view (slide 12): a sheet on phones, a dialog on desktop.
    await open('/collections/vendors?q=Coach');
    await page.locator('[data-quick-view]').first().click();
    await page.waitForSelector('#quick-view[open] [data-quick-view-root]');
    await page.waitForTimeout(450);
    await scan(page, `${w}×${h} collection with the quick view open`);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(450);
    await open(PRODUCT);
    await page.locator(w < 768 ? '.purchase-dock [data-add]' : '.product-panel [data-add]').first().click();
    await page.waitForSelector('#cart-sheet.is-open');
    await page.waitForTimeout(450);
    await scan(page, `${w}×${h} product with the "En tu bolsa" sheet open`);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(450);
    await open('/cart');
    await scan(page, `${w}×${h} bag with one line`);
  } catch (error) {
    run.check(`${w}×${h} — unexpected error`, false, String(error.message).split('\n')[0]);
  } finally {
    await browser.close();
  }
}
const result = run.finish();
process.exit(result.summary.failed ? 1 : 0);
