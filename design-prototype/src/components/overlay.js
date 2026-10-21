// Dialogs, drawers and sheets with one behaviour: the page behind becomes
// inert, focus moves in and stays in, Escape and the backdrop close, and
// focus returns to the control that opened the overlay.
import { focusables, prefersReducedMotion } from '../lib/dom.js';
import { icon } from '../lib/icons.js';
import { html } from '../lib/html.js';

const stack = [];
let idCounter = 0;

function page() {
  return document.getElementById('page');
}

function lockPage() {
  const root = document.documentElement;
  if (root.classList.contains('is-locked')) return;
  const scrollbar = window.innerWidth - root.clientWidth;
  root.style.setProperty('--scrollbar-comp', `${scrollbar}px`);
  root.classList.add('is-locked');
  page()?.setAttribute('inert', '');
}

function unlockPage() {
  const root = document.documentElement;
  root.classList.remove('is-locked');
  root.style.removeProperty('--scrollbar-comp');
  page()?.removeAttribute('inert');
}

function trapTab(event, panel) {
  const items = focusables(panel);
  if (!items.length) {
    event.preventDefault();
    panel.focus();
    return;
  }
  const first = items[0];
  const last = items[items.length - 1];
  if (event.shiftKey && (document.activeElement === first || document.activeElement === panel)) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
}

/** Standard header with a title and a 48px close button. */
export function overlayHeader(titleId, title, { eyebrow } = {}) {
  return html`<div class="overlay__header">
    <div>
      ${eyebrow ? html`<p class="eyebrow">${eyebrow}</p>` : ''}
      <h2 class="overlay__title" id="${titleId}">${title}</h2>
    </div>
    <button type="button" class="icon-button overlay__close" data-overlay-close aria-label="Cerrar">${icon('close', { size: 22 })}</button>
  </div>`;
}

export function nextOverlayId(prefix) {
  idCounter += 1;
  return `${prefix}-${idCounter}`;
}

/**
 * Opens an overlay. [kind] is dialog | sheet | drawer-right | drawer-left.
 * Returns a handle with close() and the panel element.
 */
export function openOverlay({ kind = 'dialog', labelledBy, label, content, className = '', initialFocus, onMount, onClose }) {
  const returnFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
  const root = document.getElementById('overlay-root');
  const wrapper = document.createElement('div');
  wrapper.className = `overlay overlay--${kind} ${className}`.trim();
  wrapper.innerHTML = `<div class="overlay__backdrop" data-overlay-close></div><div class="overlay__panel" role="dialog" aria-modal="true" tabindex="-1"></div>`;
  const panel = wrapper.querySelector('.overlay__panel');
  if (labelledBy) panel.setAttribute('aria-labelledby', labelledBy);
  else if (label) panel.setAttribute('aria-label', label);
  panel.innerHTML = String(content);
  root.append(wrapper);
  lockPage();

  const handle = { panel, wrapper, closed: false, close: (options) => closeOverlay(handle, options), onClose, returnFocus };
  stack.push(handle);

  wrapper.addEventListener('click', (event) => {
    const trigger = event.target instanceof Element ? event.target.closest('[data-overlay-close]') : null;
    if (trigger && wrapper.contains(trigger)) handle.close();
  });
  wrapper.addEventListener('keydown', (event) => {
    if (stack[stack.length - 1] !== handle) return;
    if (event.key === 'Escape') {
      event.stopPropagation();
      handle.close();
    } else if (event.key === 'Tab') {
      trapTab(event, panel);
    }
  });

  onMount?.(panel, handle);
  requestAnimationFrame(() => {
    wrapper.classList.add('is-open');
    const target = (initialFocus && panel.querySelector(initialFocus)) || panel;
    target.focus({ preventScroll: true });
  });
  return handle;
}

export function closeOverlay(handle, { restoreFocus = true } = {}) {
  if (handle.closed) return;
  handle.closed = true;
  const index = stack.indexOf(handle);
  if (index >= 0) stack.splice(index, 1);
  handle.wrapper.classList.remove('is-open');
  handle.wrapper.classList.add('is-closing');
  const remove = () => handle.wrapper.remove();
  if (prefersReducedMotion()) remove();
  else setTimeout(remove, 280);
  if (!stack.length) unlockPage();
  handle.onClose?.();
  if (restoreFocus) {
    const target = handle.returnFocus;
    if (target && target.isConnected && !target.closest('[inert]')) target.focus({ preventScroll: true });
    else if (stack.length) stack[stack.length - 1].panel.focus({ preventScroll: true });
  }
}

export function closeAllOverlays() {
  while (stack.length) closeOverlay(stack[stack.length - 1], { restoreFocus: false });
}

export function topOverlay() {
  return stack[stack.length - 1] ?? null;
}
