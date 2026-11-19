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
    if (document.querySelector('[data-offers]')) {
      const query = new URLSearchParams(location.search).get('oferta');
      if (query) params.set('oferta', query);
    }
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
  // The search page's own field on phones, the header's from 768 px, where the page's is hidden. Only the search page
  // carries the hook: a collection shares this script, and focusing the header field there opens the predictive panel.
  const searchHook = $('[data-search-autofocus]');
  const searchInput = searchHook && [searchHook, document.getElementById('header-search-input')].find(isShown);
  if (searchInput && !searchInput.value) searchInput.focus({ preventScroll: true });
})();

/* Ofertas: Liquid emits only eligible variants. Search the whole filtered
 * collection before applying the local text query, preserving Shopify ordering. */
(() => {
  const root = document.querySelector('[data-offers]');
  const grid = root?.querySelector('[data-grid]');
  const form = root?.querySelector('[data-offers-search]');
  if (!root || !form) return;
  const field = form.elements.oferta;
  const status = root.querySelector('[data-offers-status]');
  const empty = root.querySelector('[data-offers-empty]');
  const retry = root.querySelector('[data-offers-retry]');
  const pagination = root.querySelector('[data-offers-pagination]');
  const items = [...(grid?.children || [])];
  const normalize = (value) => value.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLocaleLowerCase('es-MX');
  const more = (scope, base = location.href) => {
    const href = scope.querySelector('[data-offers-pagination] a')?.getAttribute('href');
    return href ? new URL(href, base).href : null;
  };
  let next = more(root);
  let loaded = !next;
  let pending = false;
  let query = new URLSearchParams(location.search).get('oferta') || '';
  form.hidden = false;
  field.value = query;

  function display() {
    if (!grid) return;
    const words = normalize(query).trim().split(/\s+/).filter(Boolean);
    const matches = items.filter((item) => words.every((word) => normalize(item.dataset.offerTerms).includes(word)));
    const order = new URLSearchParams(location.search).get('sort_by');
    if (order === 'price-ascending' || order === 'price-descending') {
      const direction = order === 'price-ascending' ? 1 : -1;
      matches.sort((a, b) => direction * (Number(a.dataset.offerPrice) - Number(b.dataset.offerPrice)));
    }
    grid.replaceChildren(...matches);
    status.textContent = loaded ? `${matches.length} ${matches.length === 1 ? 'oferta' : 'ofertas'}` : '';
    empty.hidden = !loaded || matches.length > 0;
  }

  async function load() {
    if (pending) return;
    if (loaded) {
      display();
      return;
    }
    pending = true;
    retry.hidden = true;
    status.textContent = 'Cargando ofertas…';
    try {
      while (next) {
        const response = await fetch(next, { signal: AbortSignal.timeout(15000) });
        if (!response.ok) throw new Error('offers');
        const page = new DOMParser().parseFromString(await response.text(), 'text/html').querySelector('[data-offers]');
        if (!page) throw new Error('offers');
        items.push(...page.querySelectorAll('[data-offer-price]'));
        const following = more(page, response.url);
        if (following === next) throw new Error('offers');
        next = following;
      }
      loaded = true;
      if (pagination) pagination.hidden = true;
      display();
      if (history.state?.monettaOffersScroll != null) window.scrollTo(0, history.state.monettaOffersScroll);
    } catch {
      status.textContent = 'No pudimos consultar todas las ofertas.';
      retry.hidden = false;
    } finally {
      pending = false;
    }
  }

  root.addEventListener('click', (event) => {
    if (event.target.closest('a[data-product-url]')) {
      history.replaceState({ ...history.state, monettaOffersScroll: window.scrollY }, '', location.href);
    }
  });

  form.addEventListener('submit', (event) => {
    event.preventDefault();
    query = field.value.trim();
    const url = new URL(location.href);
    if (query) url.searchParams.set('oferta', query);
    else url.searchParams.delete('oferta');
    history.replaceState({ ...history.state, monettaOffersScroll: null }, '', url);
    load();
  });

  retry.addEventListener('click', load);
  for (const link of root.querySelectorAll('.chip--removable, a[href*="sort_by="]')) {
    if (!query) break;
    const url = new URL(link.href);
    url.searchParams.set('oferta', query);
    link.href = url;
  }
  load();
})();
