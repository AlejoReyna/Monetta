// Search page (/search?q=…): the app's search screen — field, recent
// searches, suggestions — plus full, filterable results that Back restores.
import { filtersAction, pageBar } from '../components/page-bar.js';
import { nextPrompt } from '../components/shell.js';
import { SEARCH_SHORTCUTS, createPredictiveSearch } from '../components/search-ui.js';
import { emptyState } from '../components/ui.js';
import { products } from '../lib/catalog.js';
import { activeFilterCount, parseState } from '../lib/filters.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { navigate } from '../lib/router.js';
import { searchProducts } from '../lib/search.js';
import { getState } from '../lib/store.js';
import { mountListing, renderListing } from './listing.js';

function searchForm(q) {
  return html`<form class="search-page__field" role="search" aria-label="Editar búsqueda" action="/search" method="get" data-page-search>
    <div class="search-field">
      ${icon('search', { size: 20 })}
      <label class="visually-hidden" for="page-search-input">Buscar productos</label>
      <input id="page-search-input" type="search" name="q" value="${q}" placeholder="${nextPrompt()}" autocomplete="off" spellcheck="false"
        role="combobox" aria-expanded="${q ? 'false' : 'true'}" aria-controls="page-search-listbox" aria-autocomplete="list" enterkeyhint="search">
      <button type="button" class="icon-button search-field__clear" data-search-clear aria-label="Borrar búsqueda" ${q ? '' : 'hidden'}>${icon('close', { size: 20 })}</button>
    </div>
  </form>`;
}

export function searchPage({ url }) {
  const q = (url.searchParams.get('q') ?? '').trim();
  const state = parseState(url.searchParams, { mode: 'search' });
  const results = q ? searchProducts(products, q) : [];
  const failed = Boolean(q) && getState().demo.resultsError;

  let body;
  if (!q) {
    body = '';
  } else if (failed) {
    body = html`<div class="search-error">${emptyState({
      title: 'No pudimos cargar los resultados',
      body: 'Revisa tu conexión e inténtalo de nuevo. Tu búsqueda se conserva.',
      mark: 'error',
      headingId: 'search-error-heading',
      actions: [html`<button type="button" class="btn btn--primary" data-retry-results>${icon('refresh', { size: 18 })} Reintentar</button>`],
    })}</div>`;
  } else {
    body = renderListing({
      basePath: '/search',
      base: results,
      state,
      kind: 'search',
      bare: true,
      title: html`Resultados para “${q}”`,
      crumbs: [
        { label: 'Inicio', href: '/' },
        { label: 'Buscar', href: '/search' },
      ],
      empty: {
        title: 'Sin resultados',
        body: `No encontramos piezas para “${q}”. Prueba con otra palabra o explora una categoría.`,
        mark: 'search',
        headingId: 'empty-heading',
        actions: [
          html`<button type="button" class="btn btn--primary" data-edit-search>Editar búsqueda</button>`,
          html`<a class="btn btn--outline" href="/search">Limpiar búsqueda</a>`,
          html`<ul class="chips" role="list" style="justify-content:center;width:100%;margin-top:8px">${SEARCH_SHORTCUTS.map(
            (entry) => html`<li><a class="chip" href="${entry.href}">${entry.label}</a></li>`,
          )}</ul>`,
        ],
      },
    });
  }

  // Phone bar (search_screen.dart: back and "Buscar"). The page always has one h1:
  // the bar's "Buscar" when there is no query or the results failed to load (the
  // bar then shows at every width), the results heading below the field when
  // there are results to name. With the results heading on duty the bar title is
  // plain text and the bar disappears from tablet up; mount() lends it the
  // heading role while suggestions hide the results. Filters sit in the bar when
  // there is something to filter.
  const filterable = Boolean(q) && !failed && results.length > 0;
  const resultsHeading = Boolean(q) && !failed;
  const bar = pageBar({
    title: 'Buscar',
    heading: !resultsHeading,
    phoneOnly: resultsHeading,
    back: '/',
    actions: [filterable ? filtersAction(activeFilterCount(state)) : ''],
  });

  return {
    title: q ? `Resultados para “${q}” · Monetta` : 'Buscar · Monetta',
    // search_screen.dart focuses the field when it opens empty; mount() does the same, so the router must not move focus to the heading.
    meta: { page: 'search', dock: 'nav', dockActive: null, nav: null, bar: true, ownsFocus: !q },
    html: html`<div class="container search-page">
        ${bar}
        ${searchForm(q)}
        <div class="search-predict" data-predict ${q ? 'hidden' : ''}>
          <div class="search-panel__inner" id="page-search-listbox" role="listbox" aria-label="Sugerencias de búsqueda"></div>
          <div class="search-footer" data-search-footer></div>
        </div>
        <div data-search-results>${body}</div>
      </div>`,
    mount(root, { initial }) {
      const form = root.querySelector('[data-page-search]');
      const input = form.querySelector('input');
      const predict = root.querySelector('[data-predict]');
      const resultsEl = root.querySelector('[data-search-results]');
      const listbox = root.querySelector('#page-search-listbox');
      const barFilters = root.querySelector('[data-page-bar] [data-open-filters]');
      const bar = root.querySelector('[data-page-bar]');
      const barTitle = bar.querySelector('.page-bar__title');
      const showPredictions = (visible) => {
        predict.hidden = !visible;
        input.setAttribute('aria-expanded', String(visible));
        if (q) resultsEl.hidden = visible;
        // The filters belong to the results; hide them while suggestions replace the results.
        if (barFilters) barFilters.hidden = visible;
        // The results heading goes with the results. While suggestions stand in for them the
        // bar's title is the page heading (see .page-bar--heading for tablet and up).
        if (resultsHeading) {
          bar.classList.toggle('page-bar--heading', visible);
          if (visible) {
            barTitle.setAttribute('role', 'heading');
            barTitle.setAttribute('aria-level', '1');
          } else {
            barTitle.removeAttribute('role');
            barTitle.removeAttribute('aria-level');
          }
        }
      };
      const controller = createPredictiveSearch({
        form,
        input,
        panel: predict,
        listbox,
        inline: true,
        onInlineChange: () => showPredictions(!q || input.value.trim() !== q),
      });
      controller.refresh();
      if (!q && !initial) input.focus({ preventScroll: true });
      const onClick = (event) => {
        if (event.target.closest('[data-edit-search]')) {
          input.focus();
          input.select();
        }
        if (event.target.closest('[data-retry-results]')) navigate(location.pathname + location.search, { replace: true });
      };
      root.addEventListener('click', onClick);
      const unbindListing = q && !failed ? mountListing(resultsEl, { basePath: '/search', base: results, state, controlsRoot: root }) : () => {};
      return () => {
        root.removeEventListener('click', onClick);
        unbindListing();
      };
    },
  };
}
