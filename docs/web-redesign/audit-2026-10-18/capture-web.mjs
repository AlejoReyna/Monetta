// Independent design audit: capture the existing prototype without changing it.
// Run from the repository root with:
// node docs/web-redesign/audit-2026-10-18/capture-web.mjs
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { launch, watch } from '../../../design-prototype/verify/browser.mjs';
import { demoCartLines } from '../../../design-prototype/verify/check-layout.mjs';
import { seedCart, scrollThrough } from '../../../design-prototype/verify/report.mjs';
import { startPreview } from '../../../design-prototype/verify/server.mjs';

const output = fileURLToPath(new URL('./web/', import.meta.url));
await mkdir(output, { recursive: true });
const server = await startPreview(4184);
const { browser, version } = await launch();
const captures = [];
const routes = [
  ['inicio', '/'],
  ['coleccion', '/collections/guess'],
  ['ficha', '/products/bolso-michael-kors-marilyn-medium-signature-convertible-satchel-vanilla-rosa'],
  ['busqueda', '/search?q=bolsa&type=product'],
  ['bolsa', '/cart'],
];
const viewports = [
  { width: 375, height: 812 },
  { width: 440, height: 956 },
  { width: 768, height: 1024 },
  { width: 1440, height: 900 },
];

async function metrics(page) {
  return page.evaluate(() => {
    const rect = (element) => {
      if (!element) return null;
      const r = element.getBoundingClientRect();
      return Object.fromEntries(['x', 'y', 'width', 'height'].map((key) => [key, Math.round(r[key] * 100) / 100]));
    };
    const role = (selector) => {
      const element = document.querySelector(selector);
      if (!element) return null;
      const style = getComputedStyle(element);
      return {
        text: element.textContent.trim(), rect: rect(element),
        family: style.fontFamily, size: style.fontSize, weight: style.fontWeight,
        color: style.color, display: style.display,
      };
    };
    return {
      scroll: { x: scrollX, y: scrollY },
      width: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
      prototypeStrip: rect(document.querySelector('.proto-strip')),
      header: rect(document.querySelector('.site-header')),
      firstCard: rect(document.querySelector('.card')),
      pageTitle: role('main h1'),
      homeHeading: role('#home-novedades'),
      recommendationHeading: role('#product-more'),
      recentHeading: role('#product-recent'),
      summaryHeading: role('.summary__title'),
      productName: role('.product-panel__name'),
      cardBrand: role('.card__brand'),
      cardName: role('.card__name'),
      cardPrice: role('.card__price'),
      headerControls: [...document.querySelectorAll('.site-header a, .site-header button')]
        .filter((el) => el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden')
        .map((el) => ({ label: el.getAttribute('aria-label') || el.textContent.trim(), rect: rect(el) })),
    };
  });
}

try {
  for (const viewport of viewports) {
    for (const [name, route] of routes) {
      const context = await browser.newContext({ viewport, deviceScaleFactor: 1, reducedMotion: 'reduce' });
      if (name === 'bolsa') await seedCart(context, demoCartLines());
      const page = await context.newPage();
      const problems = watch(page);
      await page.goto(`${server.url}${route}`, { waitUntil: 'networkidle' });
      await page.evaluate(() => document.fonts.ready);
      await page.locator('main').waitFor();
      const file = `${name}_${viewport.width}x${viewport.height}.jpg`;
      await page.screenshot({ path: `${output}${file}`, type: 'jpeg', quality: 85 });
      captures.push({ file, route, viewport, metrics: await metrics(page), problems });
      console.log(`Captured ${file}`);
      if (name === 'ficha' && viewport.width < 768) {
        await page.locator('#product-more').scrollIntoViewIfNeeded();
        await page.screenshot({ path: `${output}ficha_recomendaciones_${viewport.width}x${viewport.height}.jpg`, type: 'jpeg', quality: 85 });
      }
      if (name === 'inicio' && viewport.width === 375) {
        await scrollThrough(page);
        await page.screenshot({ path: `${output}inicio_completo_375.jpg`, fullPage: true, type: 'jpeg', quality: 80 });
      }
      await context.close();
    }
  }
} finally {
  await browser.close();
  server.stop();
}
await writeFile(`${output}metrics.json`, `${JSON.stringify({ capturedAt: new Date().toISOString(), browser: version, captures }, null, 2)}\n`);
console.log(`Saved ${captures.length} viewport captures plus detail captures to ${output}`);
