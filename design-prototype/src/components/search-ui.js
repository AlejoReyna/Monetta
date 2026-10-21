// Predictive search as an ARIA 1.2 combobox. The header uses it as a popup;
// the search page renders the same listbox inline. Enter always works, even
// when suggestions fail, because it submits to the full results route.
import { products } from '../lib/catalog.js';
import { announce } from '../lib/dom.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { formatMoney } from '../lib/money.js';
import { navigate } from '../lib/router.js';
import { searchProducts, suggestTerms } from '../lib/search.js';
import { addRecentSearch, clearSearches, getState, networkDelay } from '../lib/store.js';
import { newestProducts } from '../lib/catalog.js';
import { productUrl } from './ui.js';

export const SEARCH_SHORTCUTS = [
  { label: 'Bolsas', href: '/collections/guess', icon: 'bag' },
  { label: 'Carteras', href: '/collections/carteras-1', icon: 'wallet' },
  { label: 'Relojes', href: '/collections/relojes', icon: 'watch' },
  { label: 'Crossbodys', href: '/collections/crossbodys', icon: 'bag' },
  { label: 'Totes', href: '/collections/totes', icon: 'bag' },
];

export function searchUrl(query) {
  const params = new URLSearchParams({ q: query.trim(), type: 'product' });
  return `/search?${params}`;
}

export function submitSearch(query) {
  const value = query.trim();
  if (!value) return false;
  addRecentSearch(value);
  navigate(searchUrl(value));
  return true;
}

let optionCounter = 0;

function option({ href, query, content, className = '' }) {
  optionCounter += 1;
  return html`<a class="search-option ${className}" role="option" id="search-option-${optionCounter}" aria-selected="false" href="${href}" tabindex="-1" ${
    query ? html`data-query="${query}"` : ''
  }>${content}</a>`;
}

function productOption(product) {
  return option({
    href: productUrl(product),
    content: html`<span class="search-option__thumb"><img src="${product.images[0]}" alt="" width="48" height="60" loading="lazy"></span>
      <span class="search-option__product">
        <span class="search-option__brand">${product.brandLabel}</span>
        <span class="search-option__name">${product.title}</span>
      </span>
      <span class="search-option__price">${formatMoney(product.variants.find((variant) => variant.id === product.defaultVariantId)?.price ?? product.variants[0].price)}</span>`,
  });
}

function group(label, body, extra = '') {
  optionCounter += 1;
  const id = `search-group-${optionCounter}`;
  return html`<div class="search-panel__section" role="group" aria-labelledby="${id}">
    <p class="search-panel__heading" id="${id}" role="presentation"><span>${label}</span>${extra}</p>
    ${body}
  </div>`;
}

function initialView() {
  const { recentSearches } = getState();
  return {
    list: html`
      ${
        recentSearches.length
          ? group(
              'Búsquedas recientes',
              recentSearches.map((query) => option({ href: searchUrl(query), query, content: html`${icon('history', { size: 20 })}<span class="search-option__text">${query}</span>` })),
            )
          : ''
      }
      ${group(
        'Sugerencias',
        SEARCH_SHORTCUTS.map((entry) => option({ href: entry.href, content: html`${icon(entry.icon, { size: 20 })}<span class="search-option__text">${entry.label}</span>${icon('chevronRight', { size: 18 })}` })),
      )}
      ${group('Novedades', newestProducts(3).map(productOption))}`,
    footer: html`${recentSearches.length ? html`<button type="button" class="search-footer__button" data-clear-history>Borrar historial de búsqueda</button>` : ''}${catalogLink()}`,
  };
}

/** A regular, tabbable link after the options (not part of the listbox). */
function catalogLink(label = 'Ver todo el catálogo', href = '/collections/all', query = '') {
  return html`<a class="search-option search-option--all" href="${href}" ${query ? html`data-query="${query}"` : ''}><span>${label}</span>${icon('arrowForward', { size: 18 })}</a>`;
}

function resultsView(query, results, terms) {
  return {
    list: html`
      ${
        terms.length
          ? group(
              'Sugerencias',
              terms.map((term) =>
                option({ href: searchUrl(term.term), query: term.term, content: html`${icon('search', { size: 20 })}<span class="search-option__text">${term.term}</span><span class="search-option__meta">${term.count}</span>` }),
              ),
            )
          : ''
      }
      ${group('Productos', results.slice(0, 5).map(productOption))}`,
    footer: catalogLink(`Ver ${results.length === 1 ? 'el resultado' : `los ${results.length} resultados`} de “${query}”`, searchUrl(query), query),
  };
}

function emptyView(query) {
  return {
    list: group(
      'Explora',
      SEARCH_SHORTCUTS.slice(0, 3).map((entry) => option({ href: entry.href, content: html`${icon(entry.icon, { size: 20 })}<span class="search-option__text">${entry.label}</span>${icon('chevronRight', { size: 18 })}` })),
    ),
    footer: html`<div class="search-status">${icon('info', { size: 20 })}<p><strong>Sin coincidencias para “${query}”.</strong> Prueba con una marca, un color o un estilo.</p></div>${catalogLink()}`,
    statusFirst: true,
  };
}

function errorView(query) {
  return {
    list: '',
    footer: html`<div class="search-status" role="alert">${icon('error', { size: 20 })}<div>
        <p><strong>No pudimos cargar las sugerencias.</strong> Puedes reintentar o buscar de todos modos con Enter.</p>
        <div class="search-status__actions">
          <button type="button" class="btn btn--outline btn--sm" data-retry>${icon('refresh', { size: 18 })} Reintentar</button>
          <a class="btn btn--quiet btn--sm" href="${searchUrl(query)}" data-query="${query}">Buscar “${query}”</a>
        </div>
      </div></div>`,
  };
}

function loadingView() {
  const row = html`<div class="search-skeleton__row"><span class="skeleton" style="height:60px"></span><span style="display:grid;gap:8px"><span class="skeleton" style="height:12px;width:40%"></span><span class="skeleton" style="height:12px;width:85%"></span></span></div>`;
  return { list: '', footer: html`<div class="search-skeleton" aria-hidden="true">${[row, row, row]}</div><p class="visually-hidden">Cargando sugerencias…</p>` };
}

/**
 * Binds a combobox. [panel] is the popup container (hidden when closed) or,
 * for the inline variant, the always-visible container of [listbox].
 */
export function createPredictiveSearch({ form, input, panel, listbox, inline = false, onInlineChange }) {
  let requestId = 0;
  let activeIndex = -1;
  let timer = 0;
  let lastQuery = null;
  let open = false;
  const clear = form.querySelector('[data-search-clear]');
  const footer = panel.querySelector('[data-search-footer]');

  function options() {
    return [...listbox.querySelectorAll('[role="option"]')];
  }

  function setActive(index) {
    const list = options();
    list.forEach((element) => element.setAttribute('aria-selected', 'false'));
    activeIndex = index;
    if (index < 0 || !list[index]) {
      input.removeAttribute('aria-activedescendant');
      return;
    }
    list[index].setAttribute('aria-selected', 'true');
    input.setAttribute('aria-activedescendant', list[index].id);
    list[index].scrollIntoView({ block: 'nearest' });
  }

  function show(view) {
    listbox.innerHTML = String(view.list ?? '');
    listbox.hidden = !String(view.list ?? '').trim();
    footer.innerHTML = String(view.footer ?? '');
    footer.classList.toggle('search-footer--first', Boolean(view.statusFirst));
    setActive(-1);
  }

  function setOpen(next) {
    open = next;
    input.setAttribute('aria-expanded', String(next));
    if (!inline) panel.hidden = !next;
    if (!next) setActive(-1);
  }

  async function run(query) {
    const id = ++requestId;
    lastQuery = query;
    if (!query.trim()) {
      show(initialView());
      onInlineChange?.('initial');
      return;
    }
    const spinner = setTimeout(() => {
      if (id === requestId) {
        listbox.setAttribute('aria-busy', 'true');
        show(loadingView());
      }
    }, 120);
    await networkDelay(280);
    clearTimeout(spinner);
    if (id !== requestId) return;
    listbox.removeAttribute('aria-busy');
    onInlineChange?.('predict');
    if (getState().demo.searchError) {
      show(errorView(query.trim()));
      announce('No pudimos cargar las sugerencias. Puedes buscar con Enter.', { assertive: true });
      return;
    }
    const results = searchProducts(products, query);
    const terms = suggestTerms(products, query);
    if (!results.length) {
      show(emptyView(query.trim()));
      announce(`Sin coincidencias para ${query.trim()}.`);
      return;
    }
    show(resultsView(query.trim(), results, terms));
    announce(`${results.length} ${results.length === 1 ? 'producto' : 'productos'} para ${query.trim()}.`);
  }

  function schedule() {
    clearTimeout(timer);
    if (clear) clear.hidden = !input.value;
    timer = setTimeout(() => run(input.value), 160);
  }

  function activate(element) {
    if (element.dataset.query) addRecentSearch(element.dataset.query);
    setOpen(false);
    navigate(element.getAttribute('href'));
  }

  input.addEventListener('focus', () => {
    if (!inline) {
      if (lastQuery !== input.value) run(input.value);
      setOpen(true);
    }
  });

  input.addEventListener('input', () => {
    if (!open) setOpen(true);
    schedule();
  });

  input.addEventListener('keydown', (event) => {
    const list = options();
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      if (!open) setOpen(true);
      setActive(list.length ? (activeIndex + 1) % list.length : -1);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      setActive(list.length ? (activeIndex - 1 + list.length) % list.length : -1);
    } else if (event.key === 'Enter' && activeIndex >= 0 && list[activeIndex]) {
      event.preventDefault();
      activate(list[activeIndex]);
    } else if (event.key === 'Escape') {
      if (open && !inline) {
        event.preventDefault();
        setOpen(false);
      } else if (input.value) {
        event.preventDefault();
        input.value = '';
        schedule();
      }
    }
  });

  form.addEventListener('submit', (event) => {
    event.preventDefault();
    if (submitSearch(input.value)) {
      setOpen(false);
      if (!inline) input.blur();
    } else {
      input.focus();
    }
  });

  panel.addEventListener('mousedown', (event) => {
    if (event.target.closest('[role="option"], button, a')) event.preventDefault();
  });

  panel.addEventListener('click', (event) => {
    const element = event.target.closest('[role="option"], a[data-query]');
    if (element) {
      event.preventDefault();
      activate(element);
      return;
    }
    if (event.target.closest('[data-retry]')) run(input.value);
    if (event.target.closest('[data-clear-history]')) {
      clearSearches();
      show(initialView());
      input.focus();
    }
  });

  clear?.addEventListener('click', () => {
    input.value = '';
    clear.hidden = true;
    input.focus();
    run('');
    onInlineChange?.('initial');
  });

  if (!inline) {
    form.addEventListener('focusout', (event) => {
      if (!form.contains(event.relatedTarget)) setOpen(false);
    });
  }

  return {
    refresh: () => run(input.value),
    focus: () => input.focus(),
    close: () => setOpen(false),
  };
}
