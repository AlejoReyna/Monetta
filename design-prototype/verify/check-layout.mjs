// D03/D08 — every principal page at every required width: no horizontal
// scrolling, no element escaping the viewport, no broken image, and the right
// fixed bottom control (dock, purchase dock or checkout bar) without overlap.
import { assert, product, scrollThrough, seedCart } from './report.mjs';

export const WIDTHS = [
  [375, 812],
  [390, 844],
  [440, 956],
  [768, 1024],
  [1024, 768],
  [1280, 800],
  [1440, 900],
];

export const PAGES = [
  { id: 'home', path: '/', phoneUi: 'dock' },
  { id: 'collection', path: '/collections/guess', phoneUi: 'dock' },
  { id: 'product', path: '/products/bolso-coach-shoulder-negro-rectangular', phoneUi: 'purchase' },
  { id: 'search', path: '/search?q=bolsa&type=product', phoneUi: 'dock' },
  { id: 'cart', path: '/cart', phoneUi: 'checkout' },
  // Style-guideline review surfaces (prototype-only).
  { id: 'design-cuenta', path: '/design/cuenta', phoneUi: 'dock' },
  { id: 'design-board', path: '/design/board', phoneUi: 'dock' },
];

export function demoCartLines() {
  const coach = product('bolso-coach-shoulder-negro-rectangular');
  const sale = product('bolso-guess-crossbody-negro-1');
  return [
    { variantId: coach.variants.find((variant) => variant.title === 'Café').id, handle: coach.handle, quantity: 1 },
    { variantId: sale.variants[0].id, handle: sale.handle, quantity: 2 },
  ];
}

async function measure(page) {
  return page.evaluate(() => {
    const viewport = document.documentElement.clientWidth;
    const escaping = [];
    for (const element of document.querySelectorAll('body *')) {
      const rect = element.getBoundingClientRect();
      if (!rect.width || !rect.height) continue;
      if (rect.right <= viewport + 1 && rect.left >= -1) continue;
      let parent = element.parentElement;
      let contained = false;
      while (parent && parent !== document.body) {
        const overflow = getComputedStyle(parent).overflowX;
        if (overflow !== 'visible') {
          contained = true;
          break;
        }
        parent = parent.parentElement;
      }
      if (!contained && getComputedStyle(element).position !== 'fixed') escaping.push(`${element.tagName.toLowerCase()}.${[...element.classList].join('.')}`);
    }
    const broken = [...document.images].filter((image) => image.complete && image.naturalWidth === 0 && image.getAttribute('src')).map((image) => image.getAttribute('src'));
    const visible = (selector) => {
      const element = document.querySelector(selector);
      if (!element) return false;
      const style = getComputedStyle(element);
      return style.display !== 'none' && style.visibility !== 'hidden' && element.getBoundingClientRect().height > 0;
    };
    const footer = document.querySelector('.site-footer');
    const bottomUi = ['.dock', '.purchase-dock', '.checkout-bar'].filter(visible);
    const uiHeight = bottomUi.length ? document.querySelector(bottomUi[0]).getBoundingClientRect().height : 0;
    return {
      scrollWidth: document.documentElement.scrollWidth,
      viewport,
      escaping: escaping.slice(0, 6),
      broken,
      bottomUi,
      footerClearance: Number.parseFloat(getComputedStyle(footer).paddingBottom) - uiHeight,
      headerHeight: Math.round(document.querySelector('#site-top').getBoundingClientRect().height),
      h1: document.querySelector('main h1')?.textContent.trim().slice(0, 40) ?? null,
    };
  });
}

export async function checkLayout({ browser, url, report, widths = WIDTHS }) {
  const matrix = [];
  for (const [width, height] of widths) {
    const context = await browser.newContext({ viewport: { width, height } });
    await seedCart(context, demoCartLines());
    const page = await context.newPage();
    report.trackPage(page, `layout-${width}`);
    for (const entry of PAGES) {
      await page.goto(`${url}${entry.path}`, { waitUntil: 'networkidle' });
      await scrollThrough(page);
      const metrics = await measure(page);
      const expectedUi = width < 768 ? entry.phoneUi : entry.id === 'cart' && width < 1024 ? 'checkout' : null;
      const uiOk = expectedUi
        ? metrics.bottomUi.length === 1 && metrics.bottomUi[0].includes(expectedUi === 'dock' ? 'dock' : expectedUi === 'purchase' ? 'purchase' : 'checkout')
        : metrics.bottomUi.length === 0;
      const passed =
        metrics.scrollWidth <= metrics.viewport && metrics.escaping.length === 0 && metrics.broken.length === 0 && uiOk && metrics.footerClearance >= 0 && metrics.h1;
      matrix.push({ page: entry.id, width, ...metrics, expectedUi, passed });
      report.check(
        'D03',
        `${entry.id} @ ${width}px`,
        passed,
        `scroll ${metrics.scrollWidth}/${metrics.viewport} · escaping ${metrics.escaping.join(',') || 'none'} · broken ${metrics.broken.length} · bottom UI ${metrics.bottomUi.join('+') || 'none'} (expected ${expectedUi ?? 'none'}) · clearance ${Math.round(metrics.footerClearance)}px · header ${metrics.headerHeight}px`,
      );
    }
    await context.close();
  }

  // 320 CSS px is the reflow width WCAG uses for 400% zoom of a 1280 px window.
  const context = await browser.newContext({ viewport: { width: 320, height: 640 } });
  await seedCart(context, demoCartLines());
  const page = await context.newPage();
  report.trackPage(page, 'layout-320');
  for (const entry of PAGES) {
    await report.step('D09', `Reflow at 320px (400% zoom equivalent): ${entry.id}`, async () => {
      await page.goto(`${url}${entry.path}`, { waitUntil: 'networkidle' });
      await scrollThrough(page);
      const metrics = await measure(page);
      assert(metrics.scrollWidth <= metrics.viewport, `horizontal scroll ${metrics.scrollWidth}px`);
      assert(metrics.escaping.length === 0, `escaping ${metrics.escaping.join(', ')}`);
      return `scroll ${metrics.scrollWidth}/${metrics.viewport}`;
    });
  }
  await context.close();
  return matrix;
}
