// Short confirmations above whatever bottom control the page shows (dock,
// purchase dock or checkout bar). Always mirrored to a live region.
import { announce } from '../lib/dom.js';
import { icon } from '../lib/icons.js';
import { escapeHtml } from '../lib/html.js';

let current = null;

export function toast(message, { action, tone = 'default', duration = 4800 } = {}) {
  const root = document.getElementById('toast-root');
  current?.remove();
  const element = document.createElement('div');
  element.className = `toast toast--${tone}`;
  element.innerHTML = `<span class="toast__icon">${icon(tone === 'error' ? 'error' : 'check', { size: 18 })}</span><p class="toast__text">${escapeHtml(message)}</p>${
    action ? `<button type="button" class="toast__action">${escapeHtml(action.label)}</button>` : ''
  }`;
  if (action) {
    element.querySelector('.toast__action').addEventListener('click', () => {
      action.onClick();
      element.remove();
    });
  }
  root.append(element);
  current = element;
  announce(message, { assertive: tone === 'error' });
  requestAnimationFrame(() => element.classList.add('is-visible'));
  const timer = setTimeout(() => element.remove(), action ? duration + 2400 : duration);
  element.addEventListener('focusin', () => clearTimeout(timer), { once: true });
  return element;
}
