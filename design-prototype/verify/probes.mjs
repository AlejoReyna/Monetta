// Browser probes shared by the audit-fix checks (check-audit-fixes.mjs) and the
// reproduction script of docs/web-redesign/correcciones-auditoria-gpt-2026-10-18/.
// They measure what the viewer actually gets — what is painted over a focused
// control, which headings the accessibility tree exposes, how much of a short
// viewport the pinned bars leave to the content, where the safe region starts —
// and not what the CSS declares.
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

export const AXE_PATH = require.resolve('axe-core/axe.min.js');
export const AXE_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'];

/** Everything the prototype pins over the content: strip and header, page bar, the three bottom controls. */
export const CHROME_SELECTOR = '.dock, .purchase-dock, .checkout-bar, .site-top, [data-page-bar]';

/** Two animation frames: layout, observers and scroll-linked updates have run. */
export const settle = (page) => page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));

/**
 * The pinned bars and what they leave. A bar counts only while its own (or an
 * ancestor's) computed position is fixed or sticky, so a bar that reflow turns
 * into normal flow stops counting.
 */
export function pinnedChrome(page) {
  return page.evaluate(() => {
    const shown = (element) => Boolean(element) && element.getClientRects().length > 0 && getComputedStyle(element).visibility !== 'hidden';
    const pinnedPosition = (element) => {
      for (let node = element; node && node !== document.body; node = node.parentElement) {
        const { position } = getComputedStyle(node);
        if (position === 'fixed' || position === 'sticky') return position;
      }
      return null;
    };
    const top = [];
    const bottom = [];
    for (const [name, selector] of [
      ['site-top', '#site-top'],
      ['page-bar', '[data-page-bar]'],
      ['dock', '.dock__bar'],
      ['purchase-dock', '.purchase-dock'],
      ['checkout-bar', '.checkout-bar'],
    ]) {
      const element = document.querySelector(selector);
      if (!shown(element)) continue;
      const position = pinnedPosition(element);
      if (!position) continue;
      const rect = element.getBoundingClientRect();
      if (rect.bottom <= 0 || rect.top >= innerHeight) continue;
      (rect.top + rect.height / 2 < innerHeight / 2 ? top : bottom).push({ name, position, top: rect.top, bottom: rect.bottom, height: rect.height });
    }
    const pinnedTop = Math.max(0, ...top.map((entry) => entry.bottom));
    const pinnedBottom = Math.max(0, ...bottom.map((entry) => innerHeight - entry.top));
    const free = Math.max(0, innerHeight - pinnedTop - pinnedBottom);
    return { viewport: [innerWidth, innerHeight], pinnedTop, pinnedBottom, free, ratio: free / innerHeight, top, bottom };
  });
}

/**
 * What a keyboard user gets from the control that has focus: its box, the ring
 * that marks it, and whether pinned chrome is painted over either. Hit testing
 * uses the rendered stacking (`elementFromPoint`), so a bar that overlaps the
 * control is found even when the CSS outline exists.
 */
export function describeFocus(page, chrome = CHROME_SELECTOR) {
  return page.evaluate(async (chromeSelector) => {
    // Reduced motion turns outline changes into 0.01 ms transitions, and a snapping rail finishes its
    // scroll a few frames after the key press: measure once the box and the scroll position stop moving.
    const frame = () => new Promise((resolve) => requestAnimationFrame(resolve));
    const stamp = () => {
      const active = document.activeElement;
      const rect = active?.getBoundingClientRect();
      return rect ? `${Math.round(scrollX)}|${Math.round(scrollY)}|${rect.left.toFixed(1)}|${rect.top.toFixed(1)}` : '';
    };
    let previous = '';
    let steady = 0;
    for (let index = 0; index < 40 && steady < 3; index += 1) {
      await frame();
      const current = stamp();
      steady = current === previous ? steady + 1 : 0;
      previous = current;
    }
    const element = document.activeElement;
    if (!element || element === document.body || element === document.documentElement) return null;
    const inChrome = Boolean(element.closest(chromeSelector));
    const ringOwner = () => {
      const field = element.closest('.search-field');
      // The search field draws its ring on the wrapper (border and 1px shadow), not as an outline.
      if (field && element.matches('input')) return { owner: 'wrapper', target: field, style: { outlineWidth: '0px', outlineOffset: '0px' } };
      const own = getComputedStyle(element);
      if (own.outlineStyle !== 'none' && Number.parseFloat(own.outlineWidth) > 0) return { owner: 'self', target: element, style: own };
      const inner = element.querySelector('.card__quick-circle, .round-button__circle');
      if (inner) {
        const style = getComputedStyle(inner);
        if (style.outlineStyle !== 'none' && Number.parseFloat(style.outlineWidth) > 0) return { owner: 'inner', target: inner, style };
      }
      return { owner: null, target: element, style: own };
    };
    // Only a bar that stays on screen as the page scrolls can cover a ring: a header or a dock that
    // reflow turned into normal flow is a neighbour, and an outline is painted over its box.
    const pinned = (node) => {
      for (let current = node; current && current !== document.body; current = current.parentElement) {
        const { position } = getComputedStyle(current);
        if (position === 'fixed' || position === 'sticky') return true;
      }
      return false;
    };
    const probe = (x, y) => {
      if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) return { offscreen: true, covered: false, hit: null };
      const hit = document.elementFromPoint(x, y);
      const bar = hit?.closest(chromeSelector);
      const covered = Boolean(hit) && !element.contains(hit) && !hit.contains(element) && Boolean(bar) && pinned(bar) && !inChrome;
      return { offscreen: false, covered, hit: hit ? String(hit.className || hit.tagName).slice(0, 48) : null };
    };
    // What the pinned bars leave of the viewport, to tell a control that is hidden from one that cannot fit.
    let reservedTop = 0;
    let reservedBottom = 0;
    for (const bar of document.querySelectorAll(chromeSelector)) {
      if (getComputedStyle(bar).display === 'none' || !pinned(bar)) continue;
      const rect = bar.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0 || rect.bottom <= 0 || rect.top >= innerHeight) continue;
      if (rect.top + rect.height / 2 < innerHeight / 2) reservedTop = Math.max(reservedTop, rect.bottom);
      else reservedBottom = Math.max(reservedBottom, innerHeight - rect.top);
    }
    const free = innerHeight - reservedTop - reservedBottom;
    const box = element.getBoundingClientRect();
    const { owner, target, style } = ringOwner();
    const ringBox = target.getBoundingClientRect();
    const width = owner ? Number.parseFloat(style.outlineWidth) : 0;
    const offset = owner ? Number.parseFloat(style.outlineOffset) || 0 : 0;
    const distance = offset + width / 2;
    const points = owner && owner !== 'wrapper'
      ? {
          top: [ringBox.left + ringBox.width / 2, ringBox.top - distance],
          bottom: [ringBox.left + ringBox.width / 2, ringBox.bottom + distance],
          left: [ringBox.left - distance, ringBox.top + ringBox.height / 2],
          right: [ringBox.right + distance, ringBox.top + ringBox.height / 2],
        }
      : {};
    const ring = Object.fromEntries(Object.entries(points).map(([side, [x, y]]) => [side, { x, y, ...probe(x, y) }]));
    const region = element.closest('#site-footer')
      ? 'footer'
      : element.closest('[data-page-bar]')
        ? 'bar'
        : element.closest('.dock')
          ? 'dock'
          : element.closest('.site-nav')
            ? 'nav'
            : element.closest('.site-top')
              ? 'header'
              : element.closest('main')
                ? 'main'
                : 'other';
    // Where the words themselves sit: a fade or a clip can take the end of a label without touching its box.
    const textRange = document.createRange();
    textRange.selectNodeContents(element);
    const textRect = textRange.getBoundingClientRect();
    const center = probe(box.left + box.width / 2, box.top + box.height / 2);
    return {
      viewport: [innerWidth, innerHeight],
      textRect: { left: textRect.left, right: textRect.right, top: textRect.top, bottom: textRect.bottom },
      free,
      // Taller than the space left between the pinned bars (with its ring): no scroll position shows both edges.
      oversize: box.height + 2 * distance > free,
      label: (element.getAttribute('aria-label') || element.textContent || element.tagName).trim().replace(/\s+/g, ' ').slice(0, 60),
      tag: element.tagName.toLowerCase(),
      region,
      inChrome,
      box: { x: box.x, y: box.y, width: box.width, height: box.height, top: box.top, bottom: box.bottom },
      centerCovered: center.covered,
      centerOffscreen: center.offscreen,
      centerHit: center.hit,
      indicator: Boolean(owner),
      ringOwner: owner,
      ring,
      ringCovered: Object.entries(ring).filter(([, point]) => point.covered).map(([side]) => side),
      ringOffscreen: Object.entries(ring).filter(([, point]) => point.offscreen).map(([side]) => side),
      scrollY: Math.round(scrollY),
    };
  }, chrome);
}

/** Colour of single pixels and the number of "ink" pixels inside boxes, read from a real screenshot. */
export async function samplePixels(page, { points = [], boxes = [] } = {}) {
  const png = await page.screenshot({ type: 'png' });
  return page.evaluate(
    async ({ base64, spots, areas }) => {
      const blob = await (await fetch(`data:image/png;base64,${base64}`)).blob();
      const bitmap = await createImageBitmap(blob);
      const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
      const context = canvas.getContext('2d', { willReadFrequently: true });
      context.drawImage(bitmap, 0, 0);
      const scale = bitmap.width / innerWidth;
      const luminance = (r, g, b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;
      const clamp = (value, max) => Math.max(0, Math.min(max - 1, value));
      return {
        points: spots.map(([x, y]) => {
          const data = context.getImageData(clamp(Math.round(x * scale), bitmap.width), clamp(Math.round(y * scale), bitmap.height), 1, 1).data;
          return { rgb: [data[0], data[1], data[2]], luminance: luminance(data[0], data[1], data[2]) };
        }),
        areas: areas.map(({ x, y, width, height }) => {
          const left = clamp(Math.floor(x * scale), bitmap.width);
          const topEdge = clamp(Math.floor(y * scale), bitmap.height);
          const w = Math.max(1, Math.min(bitmap.width - left, Math.ceil(width * scale)));
          const h = Math.max(1, Math.min(bitmap.height - topEdge, Math.ceil(height * scale)));
          const data = context.getImageData(left, topEdge, w, h).data;
          let ink = 0;
          for (let index = 0; index < data.length; index += 4) if (luminance(data[index], data[index + 1], data[index + 2]) < 160) ink += 1;
          return { ink, pixels: w * h };
        }),
      };
    },
    { base64: png.toString('base64'), spots: points, areas: boxes },
  );
}

/**
 * What a mask on [scrollerSelector] does to what is painted inside [rect]: a screenshot of the
 * page as it is and another with the mask removed. A mask moves nothing, so the two compare
 * pixel by pixel; the result counts the pixels that differ by more than [threshold] in some
 * channel and the largest difference. `elementFromPoint` cannot see this: a fade over a link
 * leaves the link on top and its outline in the CSS while the ink is washed out.
 */
export async function maskInfluence(page, scrollerSelector, rect, { threshold = 24, margin = 6 } = {}) {
  const viewport = page.viewportSize();
  const x = Math.max(0, Math.floor(rect.x - margin));
  const y = Math.max(0, Math.floor(rect.y - margin));
  const clip = { x, y, width: Math.min(viewport.width, Math.ceil(rect.x + rect.width + margin)) - x, height: Math.min(viewport.height, Math.ceil(rect.y + rect.height + margin)) - y };
  const maskOf = (selector) =>
    page.evaluate((query) => {
      const style = getComputedStyle(document.querySelector(query));
      return style.maskImage || style.webkitMaskImage || 'none';
    }, selector);
  const before = await maskOf(scrollerSelector);
  const masked = await page.screenshot({ clip });
  const sheet = await page.addStyleTag({ content: `${scrollerSelector} { -webkit-mask-image: none !important; mask-image: none !important; }` });
  await page.waitForFunction((query) => {
    const style = getComputedStyle(document.querySelector(query));
    return (style.maskImage || style.webkitMaskImage || 'none') === 'none';
  }, scrollerSelector);
  await settle(page);
  const bare = await page.screenshot({ clip });
  await sheet.evaluate((element) => element.remove());
  await page.waitForFunction(([query, expected]) => {
    const style = getComputedStyle(document.querySelector(query));
    return (style.maskImage || style.webkitMaskImage || 'none') === expected;
  }, [scrollerSelector, before]);
  await settle(page);
  const result = await page.evaluate(
    async ({ first, second, limit }) => {
      const decode = async (base64) => createImageBitmap(await (await fetch(`data:image/png;base64,${base64}`)).blob());
      const [one, two] = await Promise.all([decode(first), decode(second)]);
      const { width, height } = one;
      const read = (bitmap) => {
        const context = new OffscreenCanvas(width, height).getContext('2d', { willReadFrequently: true });
        context.drawImage(bitmap, 0, 0);
        return context.getImageData(0, 0, width, height).data;
      };
      const left = read(one);
      const right = read(two);
      let differing = 0;
      let maxDelta = 0;
      for (let index = 0; index < left.length; index += 4) {
        const delta = Math.max(Math.abs(left[index] - right[index]), Math.abs(left[index + 1] - right[index + 1]), Math.abs(left[index + 2] - right[index + 2]));
        if (delta > maxDelta) maxDelta = delta;
        if (delta > limit) differing += 1;
      }
      return { differing, maxDelta, width, height };
    },
    { first: masked.toString('base64'), second: bare.toString('base64'), limit: threshold },
  );
  return { ...result, clip, mask: before };
}

/**
 * Describes the control that has focus and, in [pixelRegions], reads the screenshot: the ring must
 * be painted at its sides and the control's box must hold text pixels. With [maskedScroller] a
 * control inside that container is also compared with the page without its mask (maskInfluence).
 */
async function readStop(page, { pixelRegions, maskedScroller }) {
  const stop = await describeFocus(page);
  if (!stop) return null;
  if (pixelRegions.includes(stop.region) && stop.indicator && !stop.centerOffscreen) {
    const sides = Object.values(stop.ring).filter((point) => !point.offscreen);
    const sampled = await samplePixels(page, { points: sides.map((point) => [point.x, point.y]), boxes: [stop.box] });
    stop.pixels = {
      ringDark: sampled.points.filter((point) => point.luminance < 110).length,
      ringSampled: sampled.points.length,
      textInk: sampled.areas[0].ink,
    };
  }
  if (maskedScroller && !stop.centerOffscreen && (await page.evaluate((query) => Boolean(document.activeElement?.closest(query)), maskedScroller))) {
    stop.mask = await maskInfluence(page, maskedScroller, stop.box);
  }
  return stop;
}

/**
 * Presses Tab from the top of the page, as a keyboard user does, and describes every stop.
 * By default it first activates the skip link, as the footer traversals need; with
 * `enterContent: false` it does not, so the header and its navigation are walked first.
 * [stopWhen] ends the walk after the stop it returns true for.
 */
export async function keyboardTraversal(page, { max = 260, pixelRegions = ['footer'], onStop, enterContent = true, maskedScroller = null, stopWhen = null } = {}) {
  if (enterContent) {
    await page.keyboard.press('Tab');
    await page.keyboard.press('Enter');
  }
  const stops = [];
  for (let index = 0; index < max; index += 1) {
    await page.keyboard.press('Tab');
    const stop = await readStop(page, { pixelRegions, maskedScroller });
    if (!stop) break;
    if (index > 0 && stop.label === 'Saltar al contenido') break;
    stops.push(stop);
    if (onStop) await onStop(stop, page);
    if (stopWhen?.(stop)) break;
  }
  return stops;
}

/** [count] presses of [key] (Shift+Tab for the way back) from where focus is, each stop described as above. */
export async function tabSteps(page, key, count, { pixelRegions = [], maskedScroller = null } = {}) {
  const stops = [];
  for (let index = 0; index < count; index += 1) {
    await page.keyboard.press(key);
    const stop = await readStop(page, { pixelRegions, maskedScroller });
    if (!stop) break;
    stops.push(stop);
  }
  return stops;
}

/**
 * The stops where something the user needs is hidden: covered text, covered or
 * missing ring, unpainted ring or text, a control left out of the viewport. The
 * ring's top side may sit under the header when the page is at its very top: it
 * cannot scroll any further.
 */
export function focusProblems(stops) {
  const problems = [];
  for (const stop of stops) {
    const reasons = [];
    // A control taller than the band the pinned bars leave (a product card in a 320×568 phone) is centred in
    // it by the browser: its edges must run under the bars, so only its centre is held to the standard.
    const fits = !stop.oversize;
    if (stop.centerCovered) reasons.push(`box covered by ${stop.centerHit}`);
    const covered = stop.ringCovered.filter((side) => !(side === 'top' && stop.scrollY === 0));
    if (fits && covered.length) reasons.push(`ring covered on ${covered.join('/')}`);
    if (fits && !stop.inChrome && stop.centerOffscreen) reasons.push('box offscreen');
    if (!stop.indicator) reasons.push('no focus indicator');
    if (fits && stop.pixels && stop.pixels.ringDark < stop.pixels.ringSampled) reasons.push(`ring painted on ${stop.pixels.ringDark}/${stop.pixels.ringSampled} sides`);
    if (stop.pixels && stop.pixels.textInk < 12) reasons.push(`only ${stop.pixels.textInk} text pixels`);
    if (stop.mask && stop.mask.differing > 0) reasons.push(`the container's mask washes out ${stop.mask.differing} painted pixels (by up to ${stop.mask.maxDelta}/255)`);
    if (reasons.length) problems.push({ label: stop.label, region: stop.region, y: Math.round(stop.box.y), reasons });
  }
  return problems;
}

/** The `h1`s (or level-1 headings by role) a screen reader would meet, and the ones that exist but are hidden. */
export function exposedHeadings(page) {
  return page.evaluate(() => {
    const exposed = (element) => {
      for (let node = element; node; node = node.parentElement) {
        if (node.hidden || node.getAttribute('aria-hidden') === 'true' || node.hasAttribute('inert')) return false;
        const style = getComputedStyle(node);
        if (style.display === 'none' || style.visibility === 'hidden') return false;
      }
      return true;
    };
    const text = (element) => element.textContent.trim().replace(/\s+/g, ' ');
    const level1 = [...document.querySelectorAll('h1, [role="heading"][aria-level="1"]')];
    return {
      exposed: level1.filter(exposed).map((element) => ({ tag: element.tagName.toLowerCase(), role: element.getAttribute('role'), text: text(element) })),
      hidden: level1.filter((element) => !exposed(element)).map(text),
      h2: [...document.querySelectorAll('main h2')].filter(exposed).map(text),
    };
  });
}

export async function axeViolations(page, tags = AXE_TAGS) {
  await page.addScriptTag({ path: AXE_PATH });
  return page.evaluate(async (runTags) => {
    const result = await window.axe.run(document, { runOnly: { type: 'tag', values: runTags }, resultTypes: ['violations'] });
    return result.violations.map((violation) => ({ id: violation.id, impact: violation.impact, nodes: violation.nodes.length, sample: violation.nodes[0]?.target?.join(' ') ?? '' }));
  }, tags);
}

/** Chromium's safe-area emulation (CDP): `env(safe-area-inset-*)` takes these values. Emulation, not a physical device. */
export async function emulateSafeArea(page, insets) {
  const session = await page.context().newCDPSession(page);
  await session.send('Emulation.setSafeAreaInsetsOverride', { insets });
  return {
    async clear() {
      await session.send('Emulation.setSafeAreaInsetsOverride', { insets: {} });
      await session.detach();
    },
  };
}

/** `env()` as the page resolves it, read from a throwaway element. */
export function readSafeArea(page) {
  return page.evaluate(() => {
    const probe = document.createElement('div');
    probe.style.cssText = 'position:absolute;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
    document.body.append(probe);
    const style = getComputedStyle(probe);
    const insets = { top: Number.parseFloat(style.paddingTop), right: Number.parseFloat(style.paddingRight), bottom: Number.parseFloat(style.paddingBottom), left: Number.parseFloat(style.paddingLeft) };
    probe.remove();
    return insets;
  });
}

/**
 * Interactive controls and visible text that start or end inside a cut-out (the side insets in force);
 * a card of a rail that peeks from its next position is the one exception. The same sweep as in
 * check-audit-fixes.mjs, kept here so that file stays as it was verified.
 */
export function outsideSafeRegion(page) {
  return page.evaluate(() => {
    const probe = document.createElement('div');
    probe.style.cssText = 'position:absolute;visibility:hidden;padding:0 env(safe-area-inset-right) 0 env(safe-area-inset-left)';
    document.body.append(probe);
    const style = getComputedStyle(probe);
    const insets = { left: Number.parseFloat(style.paddingLeft), right: Number.parseFloat(style.paddingRight) };
    probe.remove();
    const view = innerWidth;
    const shown = (element) => element.getClientRects().length > 0 && getComputedStyle(element).visibility !== 'hidden';
    const scrollerOf = (node) => {
      for (let element = node; element && element !== document.body; element = element.parentElement) {
        const { overflowX } = getComputedStyle(element);
        if ((overflowX === 'auto' || overflowX === 'scroll') && element.scrollWidth > element.clientWidth + 1) return element;
      }
      return null;
    };
    const name = (element) => `${element.tagName.toLowerCase()}${element.className && typeof element.className === 'string' ? `.${element.className.split(' ')[0]}` : ''}`;
    const offenders = [];
    const check = (element, rect, kind, text) => {
      if (rect.width <= 1 || rect.height <= 1 || rect.right <= 0 || rect.left >= view) return;
      const scroller = scrollerOf(element);
      const leftOut = rect.left < insets.left - 0.5;
      const rightOut = rect.right > view - insets.right + 0.5;
      if (rightOut && !leftOut && scroller) return;
      if (leftOut || rightOut) offenders.push(`${kind} ${name(element)}${text ? ` “${text.slice(0, 24)}”` : ''}: ${rect.left.toFixed(0)}…${rect.right.toFixed(0)}`);
    };
    for (const element of document.querySelectorAll('a[href], button, input:not([type="hidden"]), select, textarea, summary, [role="button"]')) {
      if (!shown(element)) continue;
      check(element, element.getBoundingClientRect(), 'control', (element.getAttribute('aria-label') || element.textContent || '').trim().replace(/\s+/g, ' '));
    }
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      const text = node.textContent.trim();
      const parent = node.parentElement;
      if (!text || !parent || ['SCRIPT', 'STYLE', 'NOSCRIPT'].includes(parent.tagName) || parent.closest('.visually-hidden') || !shown(parent)) continue;
      const range = document.createRange();
      range.selectNodeContents(node);
      for (const rect of range.getClientRects()) check(parent, rect, 'text', text.replace(/\s+/g, ' '));
    }
    return { insets, offenders: [...new Set(offenders)] };
  });
}

/** Every element that stays on screen as the page scrolls (sticky or fixed), outside the overlays and the toast. */
export function pinnedElements(page) {
  return page.evaluate(() => {
    const found = [];
    for (const element of document.querySelectorAll('body *')) {
      if (element.closest('#overlay-root, #toast-root')) continue;
      const { position, display, visibility } = getComputedStyle(element);
      if ((position !== 'sticky' && position !== 'fixed') || display === 'none' || visibility === 'hidden' || element.getClientRects().length === 0) continue;
      found.push(`${element.tagName.toLowerCase()}${element.className && typeof element.className === 'string' ? `.${element.className.split(' ')[0]}` : ''}:${position}`);
    }
    return found;
  });
}

/** Left and right edge of the first visible element of each selector. */
export function horizontalEdges(page, selectors) {
  return page.evaluate((list) => {
    const shown = (element) => element.getClientRects().length > 0 && getComputedStyle(element).visibility !== 'hidden';
    return Object.fromEntries(
      list.map((selector) => {
        const element = [...document.querySelectorAll(selector)].find(shown);
        if (!element) return [selector, null];
        const rect = element.getBoundingClientRect();
        return [selector, { left: rect.left, right: rect.right, width: rect.width }];
      }),
    );
  }, selectors);
}
