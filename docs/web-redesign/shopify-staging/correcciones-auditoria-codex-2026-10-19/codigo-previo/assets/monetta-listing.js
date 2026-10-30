/*
 * Monetta listings (collections and search). Filters and sort are plain GET forms against Shopify's storefront
 * filtering, so every change is a real document with its own URL and Back/Forward step through them. This file only
 * removes the friction: the desktop sidebar applies as you choose, empty fields are not sent, the sort select submits
 * itself, and "Ver más piezas" appends the next page while it stays an ordinary link to ?page=n.
 */
(() => {
  'use strict';

  const Monetta = (window.Monetta = window.Monetta || {});
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

  // Empty price boxes would add "filter.v.price.gte=" to the address. Disabling them would survive the back/forward cache (the box
  // would stay dead after Back), so the address is built here from the non-empty fields instead. Without JavaScript the form's own
  // GET submission still works.
  document.addEventListener('submit', (event) => {
    const form = event.target.closest?.('[data-filters-form], [data-sort-form]');
    if (!form) return;
    event.preventDefault();
    const params = new URLSearchParams();
    for (const [name, value] of new FormData(form, event.submitter)) {
      if (value !== '') params.append(name, String(value));
    }
    const target = new URL(form.getAttribute('action') || location.pathname, location.href);
    target.search = params.toString();
    location.assign(target.href);
  });

  let applyTimer = 0;
  document.addEventListener('change', (event) => {
    const select = event.target.closest?.('[data-sort-select]');
    if (select) {
      select.form.requestSubmit();
      return;
    }
    const form = event.target.closest?.('[data-autosubmit]');
    if (form && event.target.matches('input[type="checkbox"], input[type="radio"]')) {
      window.clearTimeout(applyTimer);
      applyTimer = window.setTimeout(() => form.requestSubmit(), 120);
    }
  });

  // Enter in a price box applies, like the drawer's button.
  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Enter' || !event.target.closest?.('[data-price-range] input')) return;
    event.preventDefault();
    event.target.form?.requestSubmit();
  });

  /* ------------------------------------------------------------ load more */
  let loading = false;
  document.addEventListener('click', async (event) => {
    const more = event.target.closest?.('[data-more]');
    if (!more || event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;
    event.preventDefault();
    if (loading) return;
    loading = true;
    const label = more.textContent;
    more.setAttribute('aria-busy', 'true');
    more.textContent = 'Cargando…';
    try {
      const url = more.href;
      const response = await fetch(url, { headers: { Accept: 'text/html' } });
      if (!response.ok) throw new Error(String(response.status));
      const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
      const grid = $('[data-grid]');
      const incoming = $$('[data-grid] > li', doc);
      const start = grid.children.length;
      grid.append(...incoming.map((item) => document.importNode(item, true)));
      const nextBox = $('[data-load-more]', doc);
      const box = $('[data-load-more]');
      if (nextBox && box) box.replaceWith(document.importNode(nextBox, true));
      // The address names the page now shown; a pending "back" fallback must not act on it.
      history.replaceState(history.state, '', url);
      Monetta.noteNavigation?.();
      const first = grid.children[start]?.querySelector('.card__link');
      first?.focus({ preventScroll: false });
      const progress = $('[data-progress-text]')?.textContent;
      Monetta.announce?.(progress ? `${progress}.` : 'Se cargaron más piezas.');
    } catch {
      more.textContent = label;
      more.removeAttribute('aria-busy');
      Monetta.toast?.('No pudimos cargar más piezas. Usa el enlace para ir a la página siguiente.', { tone: 'error' });
      // The link still works as a normal navigation.
    } finally {
      loading = false;
    }
  });

  // Search opened empty from another screen focuses its field (the router of the prototype does the same).
  const searchInput = $('[data-search-autofocus]');
  if (searchInput && !searchInput.value) searchInput.focus({ preventScroll: true });
})();
