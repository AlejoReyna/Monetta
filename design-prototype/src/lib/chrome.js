// How much of the viewport the pinned chrome covers, measured and published as
// --pinned-top / --pinned-bottom on <html>. Focus scrolling, anchors and
// scrollIntoView keep their targets clear of the strip, header and page bar above
// and the dock, purchase bar and checkout bar below (see scroll-padding in base.css).
//
// The numbers are never assumed: the page bar grows with a two-line title, the dock
// with the home indicator, the header with the loaded font and the reader's text size,
// and below a certain height the same elements stop being pinned at all.

const TOP_SELECTOR = '#site-top, [data-page-bar]';
const BOTTOM_SELECTOR = '.dock, .purchase-dock, .checkout-bar';

/**
 * Pixels the described elements cover from one viewport edge while the page scrolls.
 * [offset] is the distance the element keeps from that edge when pinned (computed
 * `top` for sticky bars, `bottom` for fixed ones) and [size] its extent across it.
 * An element that is hidden, or not pinned, or has no offset to pin at, covers nothing.
 */
export function pinnedReserve(items) {
  let reserve = 0;
  for (const { display, position, offset, size } of items) {
    if (display === 'none') continue;
    if (position !== 'sticky' && position !== 'fixed') continue;
    if (!Number.isFinite(offset)) continue;
    reserve = Math.max(reserve, offset + size);
  }
  return Math.round(reserve * 100) / 100;
}

function describe(element, edge) {
  const style = getComputedStyle(element);
  return {
    display: style.display,
    position: style.position,
    offset: Number.parseFloat(style[edge]),
    // Layout height: a transform (the dock slides away while typing) must not shrink the reserve.
    size: element.getBoundingClientRect().height,
  };
}

const published = {};

function publish(name, pixels) {
  if (published[name] === pixels) return;
  published[name] = pixels;
  document.documentElement.style.setProperty(name, `${pixels}px`);
}

/** Measures the chrome that is on screen right now and publishes it. */
export function measurePinnedChrome() {
  const top = [...document.querySelectorAll(TOP_SELECTOR)].map((element) => describe(element, 'top'));
  const bottom = [...document.querySelectorAll(BOTTOM_SELECTOR)].map((element) => describe(element, 'bottom'));
  publish('--pinned-top', pinnedReserve(top));
  publish('--pinned-bottom', pinnedReserve(bottom));
}

let resizeObserver = null;
const observed = new Set();

/**
 * Brings the observed set in line with the elements that exist now (a page swaps its
 * bar and bottom controls on every render) and measures once. Observing fires an
 * initial callback per element, so the callback only measures and never observes.
 */
export function refreshPinnedChrome() {
  if (!resizeObserver) return;
  const current = new Set(document.querySelectorAll(`${TOP_SELECTOR}, ${BOTTOM_SELECTOR}`));
  for (const element of observed) {
    if (!current.has(element)) {
      resizeObserver.unobserve(element);
      observed.delete(element);
    }
  }
  for (const element of current) {
    if (!observed.has(element)) {
      // The border box: the dock grows with the home indicator through its padding, which the
      // default content box would never report.
      resizeObserver.observe(element, { box: 'border-box' });
      observed.add(element);
    }
  }
  measurePinnedChrome();
}

/** Starts keeping --pinned-top / --pinned-bottom current. Call once, after the shell exists. */
export function watchPinnedChrome() {
  if (resizeObserver || typeof ResizeObserver === 'undefined') return;
  resizeObserver = new ResizeObserver(measurePinnedChrome);
  // The reserve can change without any element changing size: a breakpoint or a short
  // viewport turns sticky bars static, and routes toggle body classes that show or hide bars.
  window.addEventListener('resize', measurePinnedChrome);
  window.addEventListener('orientationchange', measurePinnedChrome);
  new MutationObserver(measurePinnedChrome).observe(document.body, { attributes: true, attributeFilter: ['class'] });
  // A webfont that arrives late changes the bar's line breaks, hence its height.
  document.fonts?.addEventListener?.('loadingdone', measurePinnedChrome);
  document.fonts?.ready?.then(measurePinnedChrome);
  refreshPinnedChrome();
}
