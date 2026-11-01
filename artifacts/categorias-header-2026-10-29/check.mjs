// Header category row, pills and predictive panel on collections (2026-10-29). Run from the worktree root with the
// theme proxy on 127.0.0.1:9292 (draft 192576585762). Read-only: no cart, account or catalog writes.
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const require = createRequire('/Users/alexis_reyna/MyCode/Monetta/design-prototype/package.json');
const { chromium } = require('playwright-core');
const dir = path.resolve('artifacts/categorias-header-2026-10-29');
mkdirSync(dir, { recursive: true });
const base = 'http://127.0.0.1:9292';
const PILLS = 'Bolsas,Carteras,Accesorios,Relojes,Perfumes,Marcas,Mayoreo';
const checks = [];
const errors = [];
const check = (name, pass, detail) => {
  checks.push({ name, pass: !!pass, detail });
  console.log(`${pass ? 'PASS' : 'FAIL'} ${name} ${detail === undefined ? '' : JSON.stringify(detail)}`);
};

const browser = await chromium.launch({ executablePath: '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser', headless: true });

async function session(viewport) {
  const context = await browser.newContext({ viewport, deviceScaleFactor: 1, reducedMotion: 'reduce' });
  await context.route('**/*', (route) => {
    const r = route.request();
    if (r.method() !== 'GET' && /\/cart(?:\/|\.|\?)/.test(r.url())) return route.abort();
    return route.continue();
  });
  // The bug only shows with history: an empty history leaves the panel with nothing to list.
  await context.addInitScript(() => {
    try { localStorage.setItem('monetta:recent-searches', JSON.stringify(['Bolsas', 'Bolsa guess'])); } catch {}
  });
  const page = await context.newPage();
  page.on('pageerror', (e) => errors.push(`${viewport.width}: ${e.message}`));
  return { context, page };
}

async function settled(page) {
  await page.waitForSelector('.mw', { timeout: 60000 });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForLoadState('load').catch(() => {});
  await page.waitForTimeout(600); // deferred scripts, the 200 ms predictive debounce and any panel render
}

async function visit(page, route) {
  await page.goto(base + route + (route.includes('?') ? '&' : '?') + 'pb=0', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await settled(page);
}

const state = (page) => page.evaluate(() => {
  const vis = (el) => !!el && getComputedStyle(el).display !== 'none' && el.getBoundingClientRect().width > 0;
  const panel = document.querySelector('#site-header [data-monetta-predictive-panel]');
  return {
    path: location.pathname + location.search.replace(/[?&]pb=0/, ''),
    template: document.getElementById('site-top')?.dataset.template,
    siteNav: [...document.querySelectorAll('.site-nav .site-nav__link')].filter(vis).map((a) => a.textContent.trim()),
    pills: [...document.querySelectorAll('.guia-pills .guia-pill:not(.guia-pill--icon)')].map((a) => a.textContent.trim()),
    current: document.querySelector('.guia-pills [aria-current="page"]')?.textContent.trim() || null,
    active: document.activeElement?.id || document.activeElement?.tagName,
    panelOpen: !!panel && !panel.hidden && vis(panel),
    expanded: document.getElementById('header-search-input')?.getAttribute('aria-expanded'),
    overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
  };
});

try {
  // Desktop: the reported flow, each header category clicked from the home.
  {
    const { context, page } = await session({ width: 1440, height: 900 });
    await visit(page, '/');
    const home = await state(page);
    check('1440 home: header category row is still there', home.siteNav.join(',') === 'Bolsas,Carteras,Relojes,Perfumes,Marcas,Mayoreo', home.siteNav);
    const targets = [
      { label: 'Bolsas', current: 'Bolsas', collection: true },
      { label: 'Carteras', current: 'Carteras', collection: true },
      { label: 'Relojes', current: 'Relojes', collection: true },
      // Staging has no product tagged perfume: Shopify answers /collections/all/perfume with a 301 to /collections/all,
      // the whole catalogue, so no pill is current there (the header link always landed there too).
      { label: 'Perfumes', current: null, collection: true, redirect: '/collections/all' },
      { label: 'Marcas', collection: false },
      { label: 'Mayoreo', collection: false },
    ];
    for (const t of targets) {
      await visit(page, '/');
      await page.locator('.site-nav__link', { hasText: t.label }).click();
      await page.waitForLoadState('domcontentloaded');
      await settled(page);
      const s = await state(page);
      check(`1440 ${t.label}: arrival leaves the search unfocused and the predictive panel closed`, s.active !== 'header-search-input' && !s.panelOpen && s.expanded !== 'true', { path: s.path, active: s.active, panelOpen: s.panelOpen });
      if (t.collection) {
        check(`1440 ${t.label}: no header category row on the collection`, s.siteNav.length === 0 && !(await page.locator('.site-nav').count()), s.siteNav);
        check(`1440 ${t.label}: pills ${PILLS}, current ${t.current || 'none'}${t.redirect ? ` (staging redirects it to ${t.redirect})` : ''}`, s.pills.join(',') === PILLS && s.current === t.current && (!t.redirect || s.path === t.redirect), { path: s.path, pills: s.pills, current: s.current });
        if (t.label === 'Relojes') await page.screenshot({ path: `${dir}/relojes-1440x900.png` });
      } else {
        check(`1440 ${t.label}: not a collection, keeps the header category row`, s.template !== 'collection' && s.siteNav.length === 6, { template: s.template, nav: s.siteNav });
      }
    }

    // Every pill leads somewhere real and the same destinations as the header row.
    await visit(page, '/');
    const navLinks = await page.locator('.site-nav__link').evaluateAll((links) => Object.fromEntries(links.map((a) => [a.textContent.trim(), a.getAttribute('href')])));
    await visit(page, '/collections/types?q=Reloj');
    const pillLinks = await page.locator('.guia-pill:not(.guia-pill--icon)').evaluateAll((links) => Object.fromEntries(links.map((a) => [a.textContent.trim(), a.getAttribute('href')])));
    const shared = Object.keys(navLinks).filter((k) => pillLinks[k] !== navLinks[k]);
    check('1440 pills share the header row destinations', shared.length === 0, { navLinks, pillLinks });
    for (const label of ['Perfumes', 'Marcas', 'Mayoreo']) {
      const res = await page.request.get(base + pillLinks[label]);
      check(`1440 «${label}» pill destination answers 200`, res.status() === 200, { href: pillLinks[label], status: res.status() });
    }

    // A pill click keeps the panel closed too, and a brand sits under Marcas.
    await page.locator('.guia-pill', { hasText: 'Carteras' }).click();
    await page.waitForLoadState('domcontentloaded');
    await settled(page);
    let s = await state(page);
    check('1440 pill Carteras: panel closed, current Carteras', !s.panelOpen && s.active !== 'header-search-input' && s.current === 'Carteras', s);
    await visit(page, '/collections/vendors?q=Coach');
    s = await state(page);
    check('1440 Coach: current pill Marcas, panel closed', s.current === 'Marcas' && !s.panelOpen, { current: s.current, panelOpen: s.panelOpen });

    // The search field still opens its panel when the shopper focuses it.
    await page.locator('#header-search-input').click();
    await page.waitForTimeout(400);
    s = await state(page);
    check('1440 collection: clicking the search field still opens recent searches', s.panelOpen && s.expanded === 'true', { panelOpen: s.panelOpen, expanded: s.expanded });
    await page.screenshot({ path: `${dir}/coach-search-open-1440x900.png` });

    // The search page keeps its autofocus.
    await visit(page, '/search');
    s = await state(page);
    const focusedSearch = await page.evaluate(() => document.activeElement?.matches?.('input[type="search"]') || false);
    check('1440 /search: empty search still focuses its field', focusedSearch, { active: s.active });
    await context.close();
  }

  // Sticky sidebar without the 45px category row (1200 uses the measured reserve now; 1440 unchanged rule).
  for (const width of [1200, 1440]) {
    const { context, page } = await session({ width, height: 900 });
    await visit(page, '/collections/all/bolsa');
    await page.evaluate(() => window.scrollTo(0, 1400));
    await page.waitForTimeout(400);
    const g = await page.evaluate(() => {
      const side = document.querySelector('.filter-sidebar');
      const top = document.getElementById('site-top').getBoundingClientRect();
      const r = side?.getBoundingClientRect();
      return { sticky: side && getComputedStyle(side).position, sidebarTop: r && Math.round(r.top), chromeBottom: Math.round(top.bottom), reserve: parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--pinned-top')) };
    });
    check(`${width} Bolsas scrolled: sidebar sticks 16px under the header`, g.sticky === 'sticky' && Math.abs(g.sidebarTop - (g.chromeBottom + 16)) <= 1, g);
    await page.screenshot({ path: `${dir}/bolsas-scrolled-${width}x900.png` });
    await context.close();
  }

  // Tablet and phone: pills scroll or wrap, no overflow, nothing focused.
  for (const viewport of [{ width: 390, height: 844 }, { width: 768, height: 1024 }]) {
    const { context, page } = await session(viewport);
    await visit(page, '/collections/types?q=Reloj');
    const s = await state(page);
    const focused = await page.evaluate(() => document.activeElement?.matches?.('input') || false);
    check(`${viewport.width} Relojes: pills ${PILLS}, no page overflow, no input focused`, s.pills.join(',') === PILLS && s.current === 'Relojes' && s.overflow <= 0 && !focused, { pills: s.pills, overflow: s.overflow, focused });
    await page.screenshot({ path: `${dir}/relojes-${viewport.width}x${viewport.height}.png` });
    await context.close();
  }
  check('no page JavaScript errors', errors.length === 0, errors);
} finally {
  await browser.close();
  writeFileSync(`${dir}/results.json`, JSON.stringify(checks, null, 2));
  const failed = checks.filter((c) => !c.pass).length;
  console.log(`${checks.length - failed}/${checks.length} pass`);
  process.exitCode = failed ? 1 : 0;
}
