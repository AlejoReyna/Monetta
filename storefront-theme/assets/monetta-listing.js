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
  // "Ver más piezas" is a link to ?page=n (filters and sort travel in that address). Clicking it appends the page without leaving;
  // nothing is added to the grid and the address is not touched until the answer is a real listing page. When it fails, the box offers
  // two different things: retry the in-page load, and go to that page as an ordinary navigation (the link stops being intercepted).
  const LOAD_TIMEOUT_MS = 20000;
  let loading = false;

  /** The listing page behind `url`, or an Error when what came back is not that page (error body, login wall, an empty or foreign document). */
  async function fetchListingPage(url) {
    const response = await fetch(url, { headers: { Accept: 'text/html' }, signal: AbortSignal.timeout(LOAD_TIMEOUT_MS) });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const asked = new URL(url, location.href);
    const answered = new URL(response.url || asked.href, location.href);
    if (answered.pathname !== asked.pathname) throw new Error('redirected');
    const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
    const items = $$('[data-grid] > li', doc).filter((item) => $('.card', item));
    if (!$('[data-grid]', doc) || items.length === 0) throw new Error('not-a-listing-page');
    return { doc, items };
  }

  function showLoadFailure(box, link) {
    box.querySelector('[data-load-error]')?.remove();
    link.removeAttribute('aria-busy');
    link.removeAttribute('data-more'); // from now on the link is an ordinary navigation
    link.dataset.moreNative = 'true';
    link.textContent = 'Ir a la página siguiente';
    const failure = document.createElement('div');
    failure.dataset.loadError = '';
    failure.setAttribute('role', 'alert');
    failure.className = 'load-more__error';
    const text = document.createElement('p');
    text.className = 'form-error';
    text.textContent = 'No pudimos cargar más piezas aquí.';
    const retry = document.createElement('button');
    retry.type = 'button';
    retry.className = 'btn btn--outline';
    retry.dataset.moreRetry = link.href;
    retry.textContent = 'Reintentar';
    failure.append(text, retry);
    link.before(failure);
    retry.focus({ preventScroll: true });
  }

  async function loadMore(link) {
    if (loading) return;
    loading = true;
    const box = link.closest('[data-load-more]');
    const url = link.dataset.moreRetry || link.href;
    const trigger = link;
    trigger.setAttribute('aria-busy', 'true');
    const label = trigger.textContent;
    trigger.textContent = 'Cargando…';
    try {
      const { doc, items } = await fetchListingPage(url);
      const grid = $('[data-grid]');
      const start = grid.children.length;
      grid.append(...items.map((item) => document.importNode(item, true)));
      const nextBox = $('[data-load-more]', doc);
      if (nextBox && box) box.replaceWith(document.importNode(nextBox, true));
      else box?.remove();
      // The address names the page now shown; a pending "back" fallback must not act on it.
      history.replaceState(history.state, '', url);
      Monetta.noteNavigation?.();
      grid.children[start]?.querySelector('.card__link')?.focus({ preventScroll: false });
      const progress = $('[data-progress-text]')?.textContent;
      Monetta.announce?.(progress ? `${progress}.` : 'Se cargaron más piezas.');
    } catch {
      trigger.textContent = label;
      if (box) {
        const next = box.querySelector('[data-more], [data-more-native]');
        // After a failed retry the native link is already in place; only the first failure converts the interceptable one.
        if (next) showLoadFailure(box, next);
      }
    } finally {
      loading = false;
    }
  }

  document.addEventListener('click', (event) => {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;
    const retry = event.target.closest?.('[data-more-retry]');
    if (retry) {
      event.preventDefault();
      loadMore(retry);
      return;
    }
    const more = event.target.closest?.('[data-more]');
    if (!more) return;
    event.preventDefault();
    loadMore(more);
  });

  // "Editar búsqueda" (a search with no results) goes to the search field that is on screen. The phone hides the header field on this
  // page, so the link cannot point at one fixed id: its href is the page field (right on a phone, where the header field is hidden)
  // and this picks whichever of the two is actually visible, focuses it and selects the text so typing replaces the old terms.
  const isShown = (element) => !!element && element.getClientRects().length > 0 && getComputedStyle(element).visibility !== 'hidden';
  document.addEventListener('click', (event) => {
    const edit = event.target.closest?.('[data-edit-search]');
    if (!edit) return;
    const field = ['page-search-input', 'header-search-input'].map((id) => document.getElementById(id)).find(isShown);
    if (!field) return;
    event.preventDefault();
    field.focus();
    field.select?.();
    field.scrollIntoView({ block: 'nearest' });
  });

  // Search opened empty from another screen focuses its field (the router of the prototype does the same).
  const searchInput = $('[data-search-autofocus]');
  if (searchInput && !searchInput.value) searchInput.focus({ preventScroll: true });
})();
