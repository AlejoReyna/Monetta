// Keyboard traversal with a verdict on what is painted. For each page and viewport it walks every tab stop with Tab and back with
// Shift+Tab (the skip link is a stop like any other and is never activated) and, at every stop, checks that:
//   1. the control's CENTER lies inside the visible band (between the measured top chrome and bottom chrome) and inside the safe
//      region, and a hit test at that centre reaches the control: no exemption for tall controls;
//   2. its focus ring is PAINTED: the four sides of the ring are read from a screenshot of the page (sides that physically fall
//      outside the visible band because the control is taller than it are the only ones excused);
//   3. forward and backward traversals visit the same stops.
//
//   node keyboard.mjs --base-url=http://127.0.0.1:9292 [--viewports=375x812,...] [--pages=home,collection,product,bag,search] [--insets=44]
import { Run, launch, parseArgs, settle } from './lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
const insetPx = args.insets === undefined ? 0 : Number(args.insets);
const viewports = (args.viewports || '375x812,440x956,768x1024,1024x768,1440x900,320x640,812x375,1024x200,1024x480,1024x481')
  .split(',')
  .map((v) => v.split('x').map(Number));
const pageNames = (args.pages || 'home,collection,product,bag,search').split(',');
const injectCss = args['inject-css'] || null;
const run = new Run(`${args.label ? `negative-control-${args.label}-` : ''}keyboard${insetPx ? `-insets${insetPx}` : ''}`, { baseUrl, extra: { viewports, pages: pageNames, insetPx, injectCss } });

const PRODUCT = '/products/reloj-coach-talia-saddle';
const URLS = { home: '/', collection: '/collections/all', product: PRODUCT, bag: '/cart', search: '/search?q=bolsa&type=product' };
const MAX_STOPS = 160;

/** The dev proxy answers an occasional 502 under load; a harness must not report that as the theme's result. */
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

async function seedBag(page) {
  await page.goto(`${baseUrl}${PRODUCT}`, { waitUntil: 'load' });
  await page.evaluate(async () => {
    const p = await (await fetch(`${location.pathname}.js`)).json();
    const v = p.variants.find((x) => x.available);
    await fetch('/cart/add.js', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: v.id, quantity: 1 }) });
  });
}

/** What the page shows right now: the focused control, the chrome around it and its ring, all in viewport coordinates. */
const probe = (page) =>
  page.evaluate(() => {
    const el = document.activeElement;
    if (!el || el === document.body || el === document.documentElement) return null;
    // The ring may be drawn by the control, or by its first child (the "+" circle of a card, the gallery's round buttons).
    const ownsRing = (n) => getComputedStyle(n).outlineStyle !== 'none' && Number.parseFloat(getComputedStyle(n).outlineWidth) > 0;
    const labelEl = el.closest('label');
    const tiny = el.getBoundingClientRect().width <= 1;
    const ringEl = tiny && labelEl && ownsRing(labelEl) ? labelEl : ownsRing(el) ? el : [...el.children].find(ownsRing) || (labelEl && ownsRing(labelEl) ? labelEl : null) || el;
    const r = ringEl.getBoundingClientRect();
    const s = getComputedStyle(ringEl);
    // A visually hidden radio is judged through its label: that is what the shopper sees and presses.
    const hiddenInput = el instanceof HTMLInputElement && r.width > 1 && el.getBoundingClientRect().width <= 1 && labelEl;
    const controlRect = (hiddenInput ? labelEl : el).getBoundingClientRect();
    const label = (el.getAttribute('aria-label') || el.textContent || el.getAttribute('name') || el.className || '').toString().trim().replace(/\s+/g, ' ').slice(0, 48);
    const bars = [];
    for (const sel of ['#site-top', '[data-page-bar]', '.dock', '.purchase-dock', '.checkout-bar']) {
      for (const bar of document.querySelectorAll(sel)) {
        const bs = getComputedStyle(bar);
        if (bs.display === 'none' || (bs.position !== 'sticky' && bs.position !== 'fixed')) continue;
        const br = bar.getBoundingClientRect();
        if (br.height === 0) continue;
        bars.push({ sel, top: br.top, bottom: br.bottom });
      }
    }
    const topReserve = Math.max(0, ...bars.filter((b) => b.top < innerHeight / 2).map((b) => b.bottom));
    const bottomEdge = Math.min(innerHeight, ...bars.filter((b) => b.top >= innerHeight / 2).map((b) => b.top));
    const insideBar = bars.some((b) => el.closest(b.sel));
    const cx = controlRect.left + controlRect.width / 2;
    const cy = controlRect.top + controlRect.height / 2;
    const hit = document.elementFromPoint(Math.min(Math.max(cx, 0), innerWidth - 1), Math.min(Math.max(cy, 0), innerHeight - 1));
    const wrapper = el.closest('.search-field');
    return {
      key: `${[...document.querySelectorAll('*')].indexOf(el)}|${el.tagName.toLowerCase()}|${label}`,
      id: `${el.tagName.toLowerCase()}.${(el.className || '').toString().split(' ')[0]} "${label}"`,
      rect: { left: r.left, top: r.top, right: r.right, bottom: r.bottom, width: r.width, height: r.height },
      controlRect: { left: controlRect.left, top: controlRect.top, right: controlRect.right, bottom: controlRect.bottom, width: controlRect.width, height: controlRect.height },
      ringOn: ringEl === el ? 'control' : `child ${ringEl.className}`,
      focusVisible: el.matches(':focus-visible'),
      radius: Math.min(Number.parseFloat(s.borderTopLeftRadius) || 0, r.width / 2, r.height / 2),
      outline: { style: s.outlineStyle, width: Number.parseFloat(s.outlineWidth), offset: Number.parseFloat(s.outlineOffset), color: s.outlineColor },
      wrapperRing: wrapper && getComputedStyle(wrapper).boxShadow !== 'none' ? { shadow: getComputedStyle(wrapper).boxShadow } : null,
      topReserve: insideBar || el.classList.contains('skip-link') ? 0 : topReserve,
      bottomEdge: insideBar || el.classList.contains('skip-link') ? innerHeight : bottomEdge,
      insideBar,
      skipOverlay: el.classList.contains('skip-link'),
      hitOk: Boolean(hit && (el === hit || el.contains(hit) || hit.contains(el) || (el.labels && [...el.labels].some((l) => l.contains(hit))))),
      domIndex: [...document.querySelectorAll('*')].indexOf(el),
      multiline: ringEl.getClientRects().length > 1,
      hitDescr: hit ? `${hit.tagName.toLowerCase()}.${(hit.className || '').toString().split(' ')[0]}` : null,
      viewport: { w: innerWidth, h: innerHeight },
    };
  });

/** Reads the focus ring's four sides from the page's own pixels. Returns, per side, the share of dark samples (null = not sampled). */
async function paintedRing(page, info) {
  const { outline, viewport, topReserve, bottomEdge } = info;
  const rect = { ...info.rect, radius: info.radius };
  const centreOffset = outline.offset + outline.width / 2; // distance of the ring's centre line outward from the border box
  const clip = {
    x: Math.max(0, Math.floor(rect.left - 16)),
    y: Math.max(0, Math.floor(rect.top - 16)),
    width: Math.min(viewport.w, Math.ceil(rect.right + 16)) - Math.max(0, Math.floor(rect.left - 16)),
    height: Math.min(viewport.h, Math.ceil(rect.bottom + 16)) - Math.max(0, Math.floor(rect.top - 16)),
  };
  if (clip.width <= 0 || clip.height <= 0) return null;
  const buffer = await page.screenshot({ clip });
  return page.evaluate(
    async ({ b64, clip: c, rect: r, centreOffset: d, band }) => {
      const blob = await (await fetch(`data:image/png;base64,${b64}`)).blob();
      const bmp = await createImageBitmap(blob);
      const cv = new OffscreenCanvas(bmp.width, bmp.height);
      const ctx = cv.getContext('2d');
      ctx.drawImage(bmp, 0, 0);
      const luma = (x, y) => {
        const px = Math.round(x - c.x);
        const py = Math.round(y - c.y);
        if (px < 0 || py < 0 || px >= bmp.width || py >= bmp.height) return null;
        const [R, G, B] = ctx.getImageData(px, py, 1, 1).data;
        return 0.2126 * R + 0.7152 * G + 0.0722 * B;
      };
      const side = (points) => {
        const sampled = points.filter(([x, y]) => y >= band.top && y <= band.bottom && x >= 0 && x <= band.width);
        if (!sampled.length) return null;
        const dark = sampled.filter(([x, y]) => {
          // Look across a 3px window around the ring's centre line: sub-pixel placement must not read as a gap.
          const values = [-1, 0, 1].map((k) => luma(x + (points.axis === 'x' ? k : 0), y + (points.axis === 'y' ? k : 0))).filter((v) => v !== null);
          return values.length && Math.min(...values) < 90;
        }).length;
        return { share: dark / sampled.length, samples: sampled.length, of: points.length };
      };
      // The ring follows the border radius: only the straight stretch of a side is a line. A circle has none, so its four sides
      // are single points; a rounded rectangle keeps the part between its corners (the corners themselves are not judged).
      const span = (from, to, radius) => {
        const lo = from + radius;
        const hi = to - radius;
        return hi - lo < 6 ? [(from + to) / 2] : [0.2, 0.5, 0.8].map((t) => lo + (hi - lo) * t);
      };
      const xs = span(r.left, r.right, r.radius);
      const ys = span(r.top, r.bottom, r.radius);
      const top = xs.map((x) => [x, r.top - d]);
      top.axis = 'y';
      const bottom = xs.map((x) => [x, r.bottom + d]);
      bottom.axis = 'y';
      const left = ys.map((y) => [r.left - d, y]);
      left.axis = 'x';
      const right = ys.map((y) => [r.right + d, y]);
      right.axis = 'x';
      return { top: side(top), bottom: side(bottom), left: side(left), right: side(right) };
    },
    { b64: buffer.toString('base64'), clip, rect, centreOffset, band: { top: topReserve, bottom: bottomEdge, width: viewport.w } },
  );
}

async function traverse(page, direction, { paint = false, startAt = null } = {}) {
  const stops = [];
  const seen = new Set();
  // Sequential focus navigation starts from the last focus, click or selection; put it at the start (or end) of the document.
  await page.evaluate((d) => {
    const body = document.body;
    body.tabIndex = -1;
    body.focus({ preventScroll: true });
    body.removeAttribute('tabindex');
    document.activeElement?.blur?.();
    scrollTo(0, d === 'back' ? document.documentElement.scrollHeight : 0);
  }, direction);
  await page.waitForTimeout(150);
  const key = direction === 'back' ? 'Shift+Tab' : 'Tab';
  if (direction === 'back' && startAt !== null) {
    // Shift+Tab from the start of the document leaves the page; begin at the last stop forward reached, then walk back.
    await page.evaluate((i) => document.querySelectorAll('*')[i].focus(), startAt);
    await page.waitForTimeout(70);
    const first = await probe(page);
    if (first) {
      seen.add(first.key);
      stops.push(first);
    }
  }
  for (let i = 0; i < MAX_STOPS; i += 1) {
    await page.keyboard.press(key);
    await page.waitForTimeout(70);
    const info = await probe(page);
    if (!info) break;
    if (seen.has(info.key)) break;
    seen.add(info.key);
    // The ring must be read while the control has focus.
    const hasRing = info.focusVisible && info.outline.style !== 'none' && info.outline.width > 0;
    if (paint && hasRing && info.hitOk && !info.multiline) info.sides = await paintedRing(page, info);
    stops.push(info);
  }
  return stops;
}

for (const [w, h] of viewports) {
  const { browser, context, page } = await launch({ width: w, height: h, insets: insetPx || null, reducedMotion: 'reduce', injectCss });
  page.setDefaultTimeout(30000);
  try {
    for (const name of pageNames) {
      const tag = `${w}×${h} ${name}`;
      if (name === 'bag') await seedBag(page);
      await gotoOk(page, `${baseUrl}${URLS[name]}`);
      await settle(page);
      if (name === 'product') {
        await page.evaluate(() => document.querySelector('[data-recommendations]')?.scrollIntoView());
        await page.waitForSelector('.rail--recs .card', { timeout: 15000 }).catch(() => {});
        await settle(page);
        await page.evaluate(() => scrollTo(0, 0));
      }
      const forward = await traverse(page, 'forward', { paint: true });
      const failures = [];
      const rings = [];
      for (const info of forward) {
        const bandTop = info.topReserve;
        const bandBottom = info.bottomEdge;
        const cx = info.controlRect.left + info.controlRect.width / 2;
        const cy = info.controlRect.top + info.controlRect.height / 2;
        const inset = insetPx;
        const inViewport = cy >= -0.5 && cy <= info.viewport.h + 0.5 && cx >= inset - 0.5 && cx <= info.viewport.w - inset + 0.5;
        const inBand = cy >= bandTop - 0.5 && cy <= bandBottom + 0.5;
        // "Under a bar" is decided by what is painted at the control's centre (hit test of the real stacking), not by arithmetic:
        // the skip link overlays the header on purpose and is fine; a card whose centre is behind the dock is not.
        const centreVisible = inViewport && info.hitOk;
        if (!inViewport) failures.push(`${info.id}: centre (${Math.round(cx)},${Math.round(cy)}) is outside the viewport/safe region (control ${Math.round(info.controlRect.height)}px tall)`);
        else if (!info.hitOk) failures.push(`${info.id}: centre (${Math.round(cx)},${Math.round(cy)}) is covered by ${info.hitDescr} (visible band ${Math.round(bandTop)}–${Math.round(bandBottom)}, control ${Math.round(info.rect.height)}px tall)`);
        else if (!inBand && !info.skipOverlay) failures.push(`${info.id}: centre (${Math.round(cx)},${Math.round(cy)}) outside the reserved band ${Math.round(bandTop)}–${Math.round(bandBottom)} although not covered`);
        const hasRing = info.focusVisible && info.outline.style !== 'none' && info.outline.width > 0;
        if (hasRing && centreVisible && info.multiline) {
          run.note(`${tag}: ${info.id} is an inline link that wraps over several lines (merchant content): its ring has no box to sample; visible focus and hit test only`);
        } else if (hasRing && centreVisible) {
          const sides = info.sides;
          rings.push({ id: info.id, sides });
          if (sides) {
            for (const [sideName, v] of Object.entries(sides)) {
              if (v && v.share < 0.8) failures.push(`${info.id}: focus ring ${sideName} side not painted (${Math.round(v.share * 100)}% of ${v.samples} samples dark)`);
            }
            if (Object.values(sides).every((v) => v === null)) failures.push(`${info.id}: no ring side could be sampled inside the visible band`);
          }
        } else if (!hasRing && !info.wrapperRing) {
          failures.push(`${info.id}: no visible focus indicator (outline ${info.outline.style}, focus-visible ${info.focusVisible})`);
        }
      }
      const backward = await traverse(page, 'back', { startAt: forward.at(-1)?.domIndex ?? null });
      const f = forward.map((s) => s.key);
      const b = backward.map((s) => s.key).reverse();
      const same = f.length === b.length && f.every((k, i) => k === b[i]);
      run.check(`${tag}: ${forward.length} tab stops; every centre visible, hit-testable and ring painted`, failures.length === 0, failures.slice(0, 40));
      run.check(`${tag}: Shift+Tab visits the same ${backward.length} stops in reverse`, same, same ? '' : `forward ${f.length} vs backward ${b.length}; first difference ${f.find((k, i) => k !== b[i])} / ${b.find((k, i) => k !== f[i])}`);
      run.check(`${tag}: the skip link is the first stop and was not activated`, forward[0]?.id.includes('skip-link') && !page.url().includes('#MainContent'), forward[0]?.id);
    }
  } catch (error) {
    run.check(`${w}×${h} — unexpected error`, false, String(error.message).split('\n')[0]);
  } finally {
    await browser.close();
  }
}

const result = run.finish({ complete: !args.viewports && !args.pages && !injectCss });
process.exit(result.summary.failed ? 1 : 0);
