// What the theme editor does to a page, done by hand: a section's markup is replaced with a fresh render from the Section
// Rendering API and `shopify:section:load` is dispatched on it; sections are moved and `shopify:section:reorder` is
// dispatched. Afterwards the behaviour bound to the new markup must still work (no stale handlers, no broken layout).
// This stands in for dragging and editing in the real editor, which would put unsaved changes on the draft.
//
//   node editor-events.mjs --base-url=http://127.0.0.1:9292 [--w=1440 --h=900]
import { Run, launch, parseArgs, settle } from '../../scripts/e2e/lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const w = Number(args.w || 1440);
const h = Number(args.h || 900);
const run = new Run(args.name || 'dl-editor-events', { baseUrl, extra: { viewport: `${w}x${h}` } });

/** Replace a rendered section with a fresh render of itself and fire the editor's load event on it. */
const reloadSection = (page, sectionId) =>
  page.evaluate(async (id) => {
    const wrapper = document.getElementById(`shopify-section-${id}`);
    if (!wrapper) return { ok: false, reason: `no #shopify-section-${id}` };
    const url = new URL(location.href);
    url.searchParams.set('section_id', id);
    const html = await (await fetch(url)).text();
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const fresh = doc.getElementById(`shopify-section-${id}`) || doc.body.firstElementChild;
    if (!fresh) return { ok: false, reason: 'empty render' };
    const node = document.importNode(fresh, true);
    // Scripts inside a re-rendered section do not run when inserted this way; the theme's own handlers must cope.
    wrapper.replaceWith(node);
    node.dispatchEvent(new CustomEvent('shopify:section:load', { bubbles: true, detail: { sectionId: id } }));
    return { ok: true };
  }, sectionId);

const { browser, page } = await launch({ width: w, height: h, reducedMotion: 'reduce' });
page.setDefaultTimeout(30000);
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
try {
  // ---- product section: gallery thumbnails and variants after a reload
  await page.goto(`${baseUrl}/products/reloj-coach-talia-saddle`, { waitUntil: 'load' });
  await settle(page);
  const productId = await page.evaluate(() => document.querySelector('[data-product-page]')?.dataset.sectionId);
  const reloaded = await reloadSection(page, productId);
  run.check('product: section re-rendered and load event dispatched', reloaded.ok, reloaded);
  await settle(page);
  await page.locator('.gallery__thumbs .thumb').nth(2).click();
  await page.waitForTimeout(400);
  const current = await page.evaluate(() => [...document.querySelectorAll('.gallery__thumbs .thumb')].findIndex((t) => t.getAttribute('aria-current') === 'true'));
  run.check('product: a thumbnail of the re-rendered gallery still moves the viewer (handlers bound to the new markup)', current === 2, current);
  const before = await page.locator('[data-variant-id]').inputValue();
  const chip = page.locator('.options__list--radios .option-chip:not(.option-chip--soldout)').nth(1);
  await chip.click();
  await page.waitForFunction((v) => document.querySelector('[data-variant-id]')?.value !== v, before, { timeout: 20000 }).catch(() => {});
  const after = await page.locator('[data-variant-id]').inputValue();
  run.check('product: choosing an option after the reload still selects another real variant', after !== before, { before, after });

  // ---- home: reorder two sections, then the rail buttons and saved hearts still work
  await page.goto(`${baseUrl}/`, { waitUntil: 'load' });
  await settle(page);
  const moved = await page.evaluate(() => {
    const sections = [...document.querySelectorAll('main > .shopify-section')];
    if (sections.length < 3) return false;
    const [a, b] = [sections[1], sections[2]];
    b.after(a);
    document.dispatchEvent(new CustomEvent('shopify:section:reorder', { bubbles: true }));
    return true;
  });
  run.check('home: two sections reordered', moved);
  const railNext = page.locator('[data-rail-next]').first();
  const railId = await railNext.getAttribute('data-rail-next');
  const startScroll = await page.evaluate((id) => document.getElementById(id).scrollLeft, railId);
  await railNext.click();
  await page.waitForTimeout(600);
  const endScroll = await page.evaluate((id) => document.getElementById(id).scrollLeft, railId);
  run.check('home: rail "next" still scrolls its rail after the reorder', endScroll > startScroll, { startScroll, endScroll });
  const railSectionId = await page.evaluate((id) => document.getElementById(id)?.closest('.shopify-section')?.id.replace('shopify-section-', ''), railId);
  const railReload = await reloadSection(page, railSectionId);
  run.check('home: the rail section re-rendered', railReload.ok, railReload);
  await page.waitForFunction(() => document.querySelector('.card__fav:not([hidden])'), null, { timeout: 10000 }).catch(() => {});
  const favVisible = await page.evaluate(() => [...document.querySelectorAll('.card__fav')].filter((b) => !b.hidden).length);
  run.check('home: favourites of the re-rendered rail are shown again (script observes new cards)', favVisible > 0, favVisible);
  const newNext = page.locator(`[data-rail-next="${railId}"]`);
  const s0 = await page.evaluate((id) => document.getElementById(id).scrollLeft, railId);
  await newNext.click();
  await page.waitForTimeout(600);
  const s1 = await page.evaluate((id) => document.getElementById(id).scrollLeft, railId);
  run.check('home: the re-rendered rail\'s "next" scrolls (delegated handler)', s1 > s0, { s0, s1 });

  // ---- header: search clear button bound again after the header section reloads
  const headerId = await page.evaluate(() => document.querySelector('#site-header')?.closest('.shopify-section')?.id.replace('shopify-section-', ''));
  const headerReload = await reloadSection(page, headerId);
  run.check('header: section re-rendered', headerReload.ok, headerReload);
  await page.fill('#header-search-input', 'bolso');
  await page.waitForTimeout(200);
  const clearShown = await page.evaluate(() => !document.querySelector('.header-search [data-search-clear]').hidden);
  run.check('header: the clear button appears while typing in the re-rendered search field', clearShown);
} catch (error) {
  run.check('unexpected error', false, String(error.message).split('\n')[0], 'error');
} finally {
  run.check('no page errors', errors.length === 0, errors.slice(0, 5));
  await browser.close();
}
const result = run.finish({ complete: true });
process.exit(result.summary.failed ? 1 : 0);
