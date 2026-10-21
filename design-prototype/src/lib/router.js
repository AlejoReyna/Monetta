// History-API router. Paths mirror the Shopify storefront (/collections/…,
// /products/…, /search, /cart, /pages/…), so links survive the move to the theme.

const routes = [];
let renderer = () => {};

// Counts every navigation of this document: a link, a history traversal, an in-place
// address change, a page restored from the back-forward cache. A fallback armed by one
// operation is valid only while the count it captured is still current.
let navigationEpoch = 0;

// A traversal that completes fires popstate well inside this window; silence past it means
// the entries were never there.
const LEAVE_FALLBACK_MS = 500;

export function defineRoute(pattern, handler) {
  const keys = [];
  const source = pattern
    .replace(/\/$/, '')
    .replace(/:([a-z]+)/gi, (_, key) => {
      keys.push(key);
      return '([^/]+)';
    });
  routes.push({ re: new RegExp(`^${source || ''}/?$`), keys, handler });
}

export function matchRoute(pathname) {
  for (const route of routes) {
    const match = pathname.match(route.re);
    if (match) {
      const params = Object.fromEntries(route.keys.map((key, index) => [key, decodeURIComponent(match[index + 1])]));
      return { handler: route.handler, params };
    }
  }
  return null;
}

function rememberScroll() {
  const state = { ...(history.state ?? {}), scrollY: window.scrollY };
  history.replaceState(state, '', location.href);
}

/**
 * State for the next history entry. [idx] counts the entries of this visit;
 * [entry] is the idx where the current screen began. Filters and sort push
 * extra entries onto the same screen (so the browser's Back restores them),
 * and the in-page back arrow uses the difference to leave the screen instead.
 */
export function nextHistoryState(current, { replace = false, keep = false } = {}) {
  const idx = (current?.idx ?? 0) + (replace ? 0 : 1);
  const entry = replace || keep ? (current?.entry ?? 0) : idx;
  return { scrollY: 0, idx, entry };
}

/** History steps back to the previous screen of this visit; 0 when the visit began on this screen. */
export function screenBackSteps(state) {
  const idx = state?.idx ?? 0;
  const entry = state?.entry ?? 0;
  return entry > 0 ? idx - entry + 1 : 0;
}

export function backSteps() {
  return screenBackSteps(history.state);
}

/**
 * The in-page back arrow: steps over this screen's own history entries (filters, sort) to
 * the screen before it. A visit that began here has nothing before it, and a restored
 * session can lose the earlier entries (history.go then does nothing and no popstate
 * follows), so in both cases the arrow goes to [parent] instead of staying dead.
 *
 * The fallback belongs to this one operation. Any navigation that happens after the click
 * (the traversal arriving, Forward, a link, a changed address, a cache restore) bumps the
 * epoch and the fallback lapses, whatever address the page is at when the timer fires.
 */
export function leaveScreen(parent) {
  const steps = backSteps();
  if (steps <= 0) {
    navigate(parent);
    return;
  }
  const epoch = navigationEpoch;
  history.go(-steps);
  setTimeout(() => {
    if (navigationEpoch === epoch) navigate(parent);
  }, LEAVE_FALLBACK_MS);
}

/** Navigates within the prototype. Same-URL navigation re-renders in place. */
export function navigate(href, { replace = false, keepScroll = false, focus = true } = {}) {
  const url = new URL(href, location.href);
  if (url.origin !== location.origin) {
    location.href = url.href;
    return;
  }
  navigationEpoch += 1;
  rememberScroll();
  const state = nextHistoryState(history.state, { replace, keep: keepScroll });
  if (replace) history.replaceState(state, '', url.pathname + url.search + url.hash);
  else history.pushState(state, '', url.pathname + url.search + url.hash);
  renderer({ mode: keepScroll ? 'keep' : 'top', focus });
}

/** Changes the address without rendering (selected variant, load-more page). */
export function updateUrl(href, { replace = true } = {}) {
  const url = new URL(href, location.href);
  navigationEpoch += 1;
  const state = { ...(history.state ?? {}), scrollY: window.scrollY };
  if (replace) history.replaceState(state, '', url.pathname + url.search);
  else history.pushState(state, '', url.pathname + url.search);
}

function shouldIntercept(event, anchor) {
  if (event.defaultPrevented || event.button !== 0) return false;
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return false;
  if (anchor.target && anchor.target !== '_self') return false;
  if (anchor.hasAttribute('download') || anchor.dataset.routerIgnore !== undefined) return false;
  const href = anchor.getAttribute('href');
  if (!href || href.startsWith('#') || /^(mailto|tel|https?):/i.test(href)) return false;
  return true;
}

export function startRouter(render) {
  renderer = render;
  if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
  document.addEventListener('click', (event) => {
    const anchor = event.target instanceof Element ? event.target.closest('a[href]') : null;
    if (!anchor || !shouldIntercept(event, anchor)) return;
    event.preventDefault();
    navigate(anchor.getAttribute('href'));
  });
  window.addEventListener('popstate', () => {
    navigationEpoch += 1;
    renderer({ mode: 'restore', focus: true });
  });
  // A document restored from the back-forward cache resumes its frozen timers; none of them
  // may act on the visit that was left behind.
  window.addEventListener('pageshow', (event) => {
    if (event.persisted) navigationEpoch += 1;
  });
  history.replaceState({ ...(history.state ?? {}), scrollY: history.state?.scrollY ?? 0 }, '', location.href);
  renderer({ mode: 'initial', focus: false });
}

export function savedScroll() {
  return history.state?.scrollY ?? 0;
}
