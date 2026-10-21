// D09 — automated axe scan of every principal page and overlay state, plus
// keyboard, focus-visibility and reduced-motion checks.
import { createRequire } from 'node:module';
import { assert, scrollThrough, seedCart } from './report.mjs';
import { PAGES, demoCartLines } from './check-layout.mjs';

const require = createRequire(import.meta.url);
const AXE = require.resolve('axe-core/axe.min.js');
const TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'];

async function scan(page) {
  await page.addScriptTag({ path: AXE });
  return page.evaluate(async (tags) => {
    const result = await window.axe.run(document, { runOnly: { type: 'tag', values: tags }, resultTypes: ['violations'] });
    return result.violations.map((violation) => ({
      id: violation.id,
      impact: violation.impact,
      nodes: violation.nodes.length,
      sample: violation.nodes[0]?.target?.join(' ') ?? '',
    }));
  }, TAGS);
}

function summarize(violations) {
  return violations.length ? violations.map((v) => `${v.id} (${v.impact}, ${v.nodes}× e.g. ${v.sample})`).join('; ') : 'no violations';
}

export async function checkA11y({ browser, url, report }) {
  const findings = [];
  for (const [width, height] of [
    [390, 844],
    [1440, 900],
  ]) {
    const context = await browser.newContext({ viewport: { width, height } });
    await seedCart(context, demoCartLines());
    const page = await context.newPage();
    report.trackPage(page, `a11y-${width}`);
    for (const entry of PAGES) {
      await page.goto(`${url}${entry.path}`, { waitUntil: 'networkidle' });
      await scrollThrough(page);
      const violations = await scan(page);
      findings.push({ state: `${entry.id} @ ${width}`, violations });
      const material = violations.filter((violation) => ['critical', 'serious'].includes(violation.impact));
      report.check('D09', `axe: ${entry.id} @ ${width}px`, material.length === 0, summarize(violations));
    }

    // Supporting views get the same automated scan.
    for (const [label, path] of [
      ['brand page', '/collections/coach'],
      ['favourites', '/pages/favoritos'],
      ['mayoreo', '/pages/mayoreo'],
      ['nuestra historia', '/pages/nuestra-historia'],
      ['contacto', '/pages/contact'],
      ['cuenta', '/account'],
      ['política de envíos', '/policies/shipping-policy'],
      ['no encontrada', '/collections/no-existe'],
    ]) {
      await page.goto(`${url}${path}`, { waitUntil: 'networkidle' });
      await scrollThrough(page);
      const violations = await scan(page);
      findings.push({ state: `${label} @ ${width}`, violations });
      const material = violations.filter((violation) => ['critical', 'serious'].includes(violation.impact));
      report.check('D09', `axe: ${label} @ ${width}px`, material.length === 0, summarize(violations));
    }

    const states = width < 768
      ? [
          ['menu drawer', '/', async () => page.click('[data-action="menu"]')],
          ['filter drawer', '/collections/guess', async () => page.click('[data-open-filters]')],
          ['quick view', '/collections/coach', async () => page.click('[data-product="bolso-coach-shoulder-negro-rectangular"] [data-action="quick-add"]')],
        ]
      : [
          ['cart drawer', '/collections/guess', async () => page.click('[data-action="cart"]')],
          ['predictive search', '/', async () => {
            await page.click('#header-search-input');
            await page.keyboard.type('guess');
            await page.waitForSelector('#header-search-listbox .search-option__product');
          }],
          ['checkout handoff', '/cart', async () => page.click('.summary [data-checkout]')],
          ['prototype panel', '/', async () => page.click('.proto-strip__button')],
        ];
    for (const [label, path, open] of states) {
      await page.goto(`${url}${path}`, { waitUntil: 'networkidle' });
      await open();
      await page.waitForTimeout(450);
      const violations = await scan(page);
      findings.push({ state: `${label} @ ${width}`, violations });
      const material = violations.filter((violation) => ['critical', 'serious'].includes(violation.impact));
      report.check('D09', `axe: ${label} @ ${width}px`, material.length === 0, summarize(violations));
    }
    await context.close();
  }

  const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const page = await context.newPage();
  report.trackPage(page, 'a11y-keyboard');
  await report.step('D09', 'Skip link is the first stop and moves focus to the main content', async () => {
    await page.goto(`${url}/collections/guess`, { waitUntil: 'networkidle' });
    await page.keyboard.press('Tab');
    const first = await page.evaluate(() => document.activeElement?.textContent.trim());
    assert(first === 'Saltar al contenido', `first stop: ${first}`);
    await page.keyboard.press('Enter');
    await page.keyboard.press('Tab');
    const next = await page.evaluate(() => Boolean(document.activeElement?.closest('main')));
    assert(next, 'focus did not move into main');
    return 'skip link → main';
  });

  await report.step('D09', 'Focused controls show a visible focus indicator', async () => {
    await page.goto(`${url}/`, { waitUntil: 'networkidle' });
    const samples = [];
    for (let index = 0; index < 14; index += 1) {
      await page.keyboard.press('Tab');
      samples.push(
        await page.evaluate(() => {
          const element = document.activeElement;
          const style = getComputedStyle(element);
          const own = style.outlineStyle !== 'none' && Number.parseFloat(style.outlineWidth) >= 2;
          const inner = element.querySelector('.card__quick-circle, .round-button__circle');
          const innerStyle = inner ? getComputedStyle(inner) : null;
          const delegated = innerStyle && innerStyle.outlineStyle !== 'none';
          const wrapper = element.closest('.option-chip, .swatch');
          return { label: element.getAttribute('aria-label') || element.textContent.trim().slice(0, 24) || element.tagName, visible: own || delegated || Boolean(wrapper) || element.id === 'header-search-input' };
        }),
      );
    }
    const missing = samples.filter((sample) => !sample.visible);
    assert(missing.length === 0, `no focus ring on ${missing.map((sample) => sample.label).join(', ')}`);
    return `${samples.length} tab stops with visible focus`;
  });

  await report.step('D09', 'Product dialog: focus trap, Escape and focus restoration', async () => {
    await page.goto(`${url}/collections/coach`, { waitUntil: 'networkidle' });
    const trigger = page.locator('[data-product="bolso-coach-shoulder-negro-rectangular"] [data-action="quick-add"]');
    await trigger.focus();
    await page.keyboard.press('Enter');
    await page.waitForSelector('.overlay--sheet.is-open');
    for (let index = 0; index < 30; index += 1) await page.keyboard.press('Tab');
    assert(await page.evaluate(() => Boolean(document.activeElement?.closest('.overlay'))), 'focus escaped');
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => !document.querySelector('.overlay'));
    const restored = await page.evaluate(() => document.activeElement?.dataset.action);
    assert(restored === 'quick-add', `restored to ${restored}`);
    return 'trap held for 30 Tabs; Escape restored the “+” button';
  });

  await report.step('D09', 'Variant options are native radios operable with arrow keys', async () => {
    await page.goto(`${url}/products/bolso-coach-shoulder-negro-rectangular`, { waitUntil: 'networkidle' });
    await page.focus('input[type="radio"]:checked');
    await page.keyboard.press('ArrowRight');
    const url2 = page.url();
    assert(/variant=\d+/.test(url2), 'variant not in URL');
    const label = await page.textContent('[data-option-value]');
    return `arrow key selected “${label.trim()}”, URL ${url2.split('/').pop()}`;
  });
  await context.close();

  const reduced = await browser.newContext({ viewport: { width: 1280, height: 800 }, reducedMotion: 'reduce' });
  const motionPage = await reduced.newPage();
  report.trackPage(motionPage, 'a11y-reduced-motion');
  await report.step('D09', 'Reduced motion: editorial sections visible at once, transitions disabled', async () => {
    await motionPage.goto(`${url}/`, { waitUntil: 'networkidle' });
    const state = await motionPage.evaluate(() => ({
      revealReady: document.documentElement.classList.contains('reveal-ready'),
      opacities: [...document.querySelectorAll('[data-reveal]')].map((element) => getComputedStyle(element).opacity),
      transition: getComputedStyle(document.querySelector('.btn')).transitionDuration,
    }));
    assert(state.opacities.every((value) => value === '1'), `reveal opacities ${state.opacities}`);
    assert(state.transition.split(',').every((value) => Number.parseFloat(value) <= 0.0001), `transition ${state.transition}`);
    return `reveal-ready=${state.revealReady}; opacities ${state.opacities.join(',')}; transition ${state.transition}`;
  });
  await reduced.close();
  return findings;
}
