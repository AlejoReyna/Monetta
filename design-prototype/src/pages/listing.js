// Product listing shared by collections, brand pages and search results:
// title and count, shortcuts, sort, filter sidebar or drawer, removable
// chips, load more, and empty-result recovery. All state lives in the URL.
import { filterControls, openFiltersDrawer, readPrice } from '../components/filters-ui.js';
import { filtersAction, pageBar, searchAction } from '../components/page-bar.js';
import { breadcrumbs, emptyState, productCard } from '../components/ui.js';
import { announce, on } from '../lib/dom.js';
import {
  PAGE_SIZE,
  SORTS,
  activeChips,
  activeFilterCount,
  clearFilters,
  runQuery,
  serializeState,
  withPrice,
  withSort,
  withValue,
} from '../lib/filters.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { plural } from '../lib/money.js';
import { navigate, updateUrl } from '../lib/router.js';

export function listingUrl(basePath, state) {
  const query = serializeState(state).toString();
  return query ? `${basePath}?${query}` : basePath;
}

function chipsRow(state, basePath) {
  const chips = activeChips(state);
  if (!chips.length) return '';
  return html`<div class="active-chips">
    <h2 class="visually-hidden">Filtros activos</h2>
    <ul class="chips" role="list">
      ${chips.map(
        (chip) => html`<li><a class="chip chip--removable" href="${listingUrl(basePath, chip.next)}" data-keep-scroll aria-label="Quitar filtro: ${chip.label}">${chip.label}${icon('close', { size: 16 })}</a></li>`,
      )}
      <li><a class="chip" href="${listingUrl(basePath, clearFilters(state))}" data-keep-scroll>Limpiar todo</a></li>
    </ul>
  </div>`;
}

function sortSelect(state, id) {
  return html`<label class="toolbar__sort" for="${id}">Ordenar
    <select class="select" id="${id}" data-sort-select>
      ${SORTS[state.mode].map((sort) => html`<option value="${sort.value}" ${sort.value === state.sort ? 'selected' : ''}>${sort.label}</option>`)}
    </select>
  </label>`;
}

/** The filter entry the visitor can actually see: the phone bar's icon or the toolbar button. */
function visibleFiltersButton() {
  return [...document.querySelectorAll('[data-open-filters]')].find((button) => button.getClientRects().length > 0) ?? null;
}

/**
 * [base] is the scoped product list in its default order (collection order
 * or search relevance). [hide] lists facets that make no sense in the scope.
 * [bar] (collections) draws the title row as the phone's compact page bar;
 * without it the row is the plain title and count (search results, whose own
 * bar belongs to the search page). [bare] omits the container when the page
 * already provides one; [kind] names the listing for page-specific styling.
 */
export function renderListing({ basePath, base, state, title, crumbs, intro, shortcuts, hide = [], empty, headingExtra, bar, kind = 'collection', bare = false }) {
  const { total, visible, hasMore } = runQuery(base, state);
  const filters = activeFilterCount(state);
  const countText = plural(total, 'pieza', 'piezas');
  const sidebar = html`<aside class="filter-sidebar" aria-label="Filtros">
      ${filterControls(base, state, { prefix: 'sb', hide, withApply: true })}
    </aside>`;
  const results = total
    ? html`<div>
        <h2 class="visually-hidden" id="results-heading">Productos</h2>
        <ul class="product-grid product-grid--wide product-grid--flush" role="list" aria-labelledby="results-heading" data-grid>
          ${visible.map((product, index) => html`<li>${productCard(product, { eager: index < 4 })}</li>`)}
        </ul>
        ${
          hasMore
            ? html`<div class="load-more" data-load-more>
                <p class="small text-muted" data-progress-text>Se muestran ${visible.length} de ${total} piezas</p>
                <div class="load-more__progress" aria-hidden="true"><span style="width:${Math.round((visible.length / total) * 100)}%"></span></div>
                <a class="btn btn--outline" href="${listingUrl(basePath, { ...state, page: state.page + 1 })}" data-more>Ver más piezas</a>
              </div>`
            : total > PAGE_SIZE
              ? html`<p class="load-more small text-muted">Viste las ${total} piezas.</p>`
              : ''
        }
      </div>`
    : emptyState(
        filters
          ? {
              title: 'Sin resultados',
              body: 'No hay piezas con esos filtros. Quita uno para volver a ver productos.',
              mark: 'tune',
              headingId: 'empty-heading',
              actions: [
                html`<a class="btn btn--primary" href="${listingUrl(basePath, clearFilters(state))}" data-keep-scroll>Limpiar filtros</a>`,
                html`<a class="btn btn--outline" href="/collections/all">Ver todo el catálogo</a>`,
              ],
            }
          : empty,
      );

  // A scope with nothing in it (a search without matches) has nothing to filter.
  const controls =
    base.length === 0
      ? html`<div class="results" data-results>${results}</div>`
      : html`<div class="toolbar">
          <div class="toolbar__start">
            <button type="button" class="btn btn--quiet btn--sm filters-button" data-open-filters aria-haspopup="dialog">${icon('tune', { size: 20 })} Filtrar y ordenar${
              filters ? html`<span class="filters-button__count"><span class="visually-hidden">, </span>${filters}<span class="visually-hidden"> activos</span></span>` : ''
            }</button>
          </div>
          <div class="toolbar__end">${sortSelect(state, 'sort-select')}</div>
        </div>
        ${chipsRow(state, basePath)}
        <div class="collection-layout collection-layout--filters">
          ${sidebar}
          <div class="results" data-results>${results}</div>
        </div>`;

  const head = bar
    ? pageBar({
        title,
        back: bar.back,
        sub: html`<p class="page-bar__sub" data-count aria-live="polite">${countText}</p>`,
        actions: [bar.search === false ? '' : searchAction(), base.length ? filtersAction(filters) : ''],
      })
    : html`<div class="page-head__row">
        <h1 class="display display--page" tabindex="-1">${title}</h1>
        <p class="page-head__count" data-count aria-live="polite">${countText}</p>
      </div>`;

  return html`<div class="${bare ? '' : 'container '}listing listing--${kind}" data-listing>
    <div class="page-head${bar ? ' page-head--bar' : ''}">
      ${crumbs ? breadcrumbs(crumbs) : ''}
      ${head}
      ${headingExtra ?? ''}
      ${intro ? html`<p class="body-copy page-intro">${intro}</p>` : ''}
    </div>
    ${shortcuts ? html`<nav class="collection-shortcuts" aria-label="Atajos">${shortcuts}</nav>` : ''}
    ${controls}
  </div>`;
}

/** [controlsRoot] is where the filter button may live when it sits outside [root] (the phone search bar). */
export function mountListing(root, { basePath, base, state, hide = [], controlsRoot = root }) {
  const go = (next) => navigate(listingUrl(basePath, next), { keepScroll: true, focus: false });
  const cleanups = [];
  cleanups.push(
    on(root, 'change', '[data-sort-select]', (event, select) => go(withSort(state, select.value))),
    on(root, 'change', '.filter-sidebar [data-facet]', (event, input) => go(withValue(state, input.dataset.facet, input.value, input.checked))),
    on(root, 'click', '.filter-sidebar [data-apply-price]', () => go(withPrice(state, ...readPrice(root.querySelector('.filter-sidebar'))))),
    on(root, 'keydown', '.filter-sidebar [data-price-range] input', (event) => {
      if (event.key === 'Enter') {
        event.preventDefault();
        go(withPrice(state, ...readPrice(root.querySelector('.filter-sidebar'))));
      }
    }),
    on(root, 'click', '[data-keep-scroll]', (event, link) => {
      event.preventDefault();
      navigate(link.getAttribute('href'), { keepScroll: true, focus: false });
      requestAnimationFrame(() => {
        const target = document.querySelector('[data-listing] h1');
        if (!document.activeElement || document.activeElement === document.body) target?.focus({ preventScroll: true });
      });
    }),
    on(controlsRoot, 'click', '[data-open-filters]', (event, button) => {
      openFiltersDrawer({
        products: base,
        state,
        hide,
        onApply: (next) => {
          navigate(listingUrl(basePath, next), { keepScroll: true, focus: false });
          requestAnimationFrame(() => visibleFiltersButton()?.focus({ preventScroll: true }));
        },
      });
      button.blur();
    }),
    on(root, 'click', '[data-more]', (event) => {
      event.preventDefault();
      loadMore(root, { basePath, base, state });
    }),
  );
  return () => cleanups.forEach((cleanup) => cleanup());
}

function loadMore(root, { basePath, base, state }) {
  state.page += 1;
  const { total, visible, hasMore } = runQuery(base, state);
  const grid = root.querySelector('[data-grid]');
  const start = grid.children.length;
  const fragment = document.createElement('template');
  fragment.innerHTML = String(html`${visible.slice(start).map((product) => html`<li>${productCard(product)}</li>`)}`);
  grid.append(fragment.content);
  updateUrl(listingUrl(basePath, state));
  const box = root.querySelector('[data-load-more]');
  if (hasMore) {
    box.querySelector('[data-progress-text]').textContent = `Se muestran ${visible.length} de ${total} piezas`;
    box.querySelector('.load-more__progress span').style.width = `${Math.round((visible.length / total) * 100)}%`;
    box.querySelector('[data-more]').setAttribute('href', listingUrl(basePath, { ...state, page: state.page + 1 }));
  } else {
    box.outerHTML = `<p class="load-more small text-muted">Viste las ${total} piezas.</p>`;
  }
  grid.children[start]?.querySelector('.card__link')?.focus({ preventScroll: false });
  announce(`Se muestran ${visible.length} de ${total} piezas.`);
}
