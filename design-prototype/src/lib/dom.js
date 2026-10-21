// Small DOM helpers shared by pages and components.
import { escapeHtml } from './html.js';

export function qs(selector, root = document) {
  return root.querySelector(selector);
}

export function qsa(selector, root = document) {
  return [...root.querySelectorAll(selector)];
}

/** Delegated listener; the handler receives the matched element. */
export function on(root, type, selector, handler, options) {
  const listener = (event) => {
    const target = event.target instanceof Element ? event.target.closest(selector) : null;
    if (target && root.contains(target)) handler(event, target);
  };
  root.addEventListener(type, listener, options);
  return () => root.removeEventListener(type, listener, options);
}

export function prefersReducedMotion() {
  return globalThis.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
}

export function isPhone() {
  return globalThis.matchMedia?.('(max-width: 767.98px)').matches ?? false;
}

export function isDesktop() {
  return globalThis.matchMedia?.('(min-width: 1024px)').matches ?? false;
}

const FOCUSABLE =
  'a[href], area[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"]), summary';

export function focusables(root) {
  return qsa(FOCUSABLE, root).filter(
    (element) => !element.closest('[inert]') && element.getClientRects().length > 0 && getComputedStyle(element).visibility !== 'hidden',
  );
}

let liveTimer = 0;

/** Screen-reader announcement through the polite or assertive live region. */
export function announce(message, { assertive = false } = {}) {
  const region = document.getElementById(assertive ? 'alert-live' : 'status-live');
  if (!region) return;
  region.textContent = '';
  clearTimeout(liveTimer);
  liveTimer = setTimeout(() => {
    region.textContent = message;
  }, 60);
}

/** Restores focus to the element with the same id after a re-render. */
export function preserveFocus(render) {
  const active = document.activeElement;
  const id = active?.id;
  const selection = active && 'selectionStart' in active ? [active.selectionStart, active.selectionEnd] : null;
  render();
  if (!id) return;
  const next = document.getElementById(id);
  if (next && next !== document.activeElement) {
    next.focus({ preventScroll: true });
    if (selection && 'setSelectionRange' in next) {
      try {
        next.setSelectionRange(...selection);
      } catch {
        // Some input types do not support selection ranges.
      }
    }
  }
}

export function escapeAttr(value) {
  return escapeHtml(value);
}

export async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}
