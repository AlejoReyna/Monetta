// prefers-reduced-motion: with the preference set, transitions and animations collapse to ~0 and dialogs open without sliding;
// without it, the design's 180/280 ms motion is present (so the first result is not an artefact of a broken stylesheet).
//
//   node motion.mjs --base-url=http://127.0.0.1:9292
import { Run, launch, parseArgs, settle } from './lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const run = new Run('motion', { baseUrl });
const secs = (v) => Math.max(...String(v).split(',').map((x) => Number.parseFloat(x) * (x.trim().endsWith('ms') ? 0.001 : 1)));

for (const [label, mode] of [['reduced', 'reduce'], ['no preference', 'no-preference']]) {
  const { browser, page } = await launch({ width: 375, height: 812, reducedMotion: mode });
  page.setDefaultTimeout(30000);
  try {
    await page.goto(`${baseUrl}/`, { waitUntil: 'load' });
    await settle(page);
    const d = await page.evaluate(() => {
      const t = (sel) => { const el = document.querySelector(sel); return el ? getComputedStyle(el).transitionDuration : null; };
      return { btn: t('.btn'), card: t('.card'), panel: t('#menu-drawer .overlay__panel'), backdrop: t('#menu-drawer .overlay__backdrop'), scroll: getComputedStyle(document.documentElement).scrollBehavior };
    });
    const longest = Math.max(secs(d.btn), secs(d.card), secs(d.panel), secs(d.backdrop));
    if (mode === 'reduce') {
      run.check(`${label}: every transition collapses to ~0 (buttons, cards, drawer panel and backdrop)`, longest <= 0.001, JSON.stringify(d));
      run.check(`${label}: smooth scrolling is off`, d.scroll === 'auto', d.scroll);
      await page.locator('.site-header__menu').click();
      await page.waitForSelector('#menu-drawer.is-open');
      // One frame for the transition to be evaluated; with ~0 duration it is finished by then.
      await page.waitForTimeout(120);
      const t0 = Date.now();
      const settled = await page.evaluate(() => getComputedStyle(document.querySelector('#menu-drawer .overlay__panel')).transform);
      run.check(`${label}: the menu drawer is in place at once (no slide to wait for)`, settled === 'none' || settled === 'matrix(1, 0, 0, 1, 0, 0)', `${settled} 120 ms after opening`);
    } else {
      run.check(`${label}: the design's motion is present (panel 280 ms, buttons 180 ms)`, secs(d.panel) >= 0.27 && secs(d.btn) >= 0.17, JSON.stringify(d));
    }
  } catch (error) {
    run.check(`${label} — unexpected error`, false, String(error.message).split('\n')[0]);
  } finally {
    await browser.close();
  }
}
const result = run.finish();
process.exit(result.summary.failed ? 1 : 0);
