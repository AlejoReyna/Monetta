// Filter controls: the desktop sidebar applies each change at once; the
// drawer (phone, tablet, narrow desktop) edits a draft with a live count and
// applies on "Ver N piezas", like the app's filter sheet.
import { SWATCH_FILLS, COLOR_LABELS, slugify } from '../lib/facets.js';
import { SORTS, applyFilters, clearFilters, cloneState, facetOptions, priceBounds, withPrice, withSort, withValue } from '../lib/filters.js';
import { preserveFocus } from '../lib/dom.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { nextOverlayId, openOverlay, overlayHeader } from './overlay.js';

const COLOR_BY_LABEL = Object.fromEntries(Object.entries(COLOR_LABELS).map(([slug, label]) => [label, SWATCH_FILLS[slug]]));
const OPEN_BY_DEFAULT = new Set(['availability', 'category', 'style', 'brand']);

function facetGroup(facet, prefix) {
  const selectedCount = facet.options.filter((option) => option.selected).length;
  return html`<details class="filter-group" ${OPEN_BY_DEFAULT.has(facet.id) || selectedCount ? 'open' : ''}>
    <summary>${facet.label}${selectedCount ? html`<span class="filter-group__selected">${selectedCount} ${selectedCount === 1 ? 'elegido' : 'elegidos'}</span>` : ''}${icon('expand', { size: 20 })}</summary>
    <fieldset class="filter-group__body options">
      <legend class="visually-hidden">${facet.label}</legend>
      ${facet.options.map((option) => {
        const id = `${prefix}-${facet.id}-${slugify(option.value) || option.value}`;
        const disabled = option.count === 0 && !option.selected;
        const fill = facet.id === 'color' ? COLOR_BY_LABEL[option.value] : null;
        return html`<label class="check${disabled ? ' check--disabled' : ''}" for="${id}">
          <input type="checkbox" id="${id}" data-facet="${facet.id}" value="${option.value}" ${option.selected ? 'checked' : ''} ${disabled ? 'disabled' : ''}>
          ${fill ? html`<span class="swatch-dot" style="background:${fill}" aria-hidden="true"></span>` : ''}
          <span>${option.label}</span>
          <span class="check__count">${option.count}<span class="visually-hidden"> ${option.count === 1 ? 'pieza' : 'piezas'}</span></span>
        </label>`;
      })}
    </fieldset>
  </details>`;
}

function priceGroup(products, state, prefix, { withApply }) {
  const bounds = priceBounds(products);
  const active = state.priceMin !== null || state.priceMax !== null;
  return html`<details class="filter-group" ${active ? 'open' : ''}>
    <summary>Precio${active ? html`<span class="filter-group__selected">Activo</span>` : ''}${icon('expand', { size: 20 })}</summary>
    <div class="filter-group__body">
      <div class="price-range" data-price-range>
        <label class="field" for="${prefix}-price-min"><span class="field__label">Desde ($)</span>
          <input class="input" id="${prefix}-price-min" name="min" type="number" inputmode="numeric" min="0" step="1" placeholder="${bounds.min}" value="${state.priceMin ?? ''}"></label>
        <label class="field" for="${prefix}-price-max"><span class="field__label">Hasta ($)</span>
          <input class="input" id="${prefix}-price-max" name="max" type="number" inputmode="numeric" min="0" step="1" placeholder="${bounds.max}" value="${state.priceMax ?? ''}"></label>
        <p class="price-range__hint">Precios entre $${bounds.min.toLocaleString('en-US')} y $${bounds.max.toLocaleString('en-US')} MXN.</p>
        ${withApply ? html`<button type="button" class="btn btn--outline btn--sm" data-apply-price>Aplicar precio</button>` : ''}
      </div>
    </div>
  </details>`;
}

export function filterControls(products, state, { prefix, hide = [], withApply = false }) {
  return html`<div class="filters">
    ${facetOptions(products, state, { hide }).map((facet) => facetGroup(facet, prefix))}
    ${priceGroup(products, state, prefix, { withApply })}
  </div>`;
}

function sortGroup(state, prefix) {
  return html`<details class="filter-group" open>
    <summary>Ordenar por${icon('expand', { size: 20 })}</summary>
    <fieldset class="filter-group__body options">
      <legend class="visually-hidden">Ordenar por</legend>
      ${SORTS[state.mode].map(
        (sort) => html`<label class="check" for="${prefix}-sort-${sort.value}"><input type="radio" name="${prefix}-sort" id="${prefix}-sort-${sort.value}" value="${sort.value}" data-sort ${sort.value === state.sort ? 'checked' : ''}><span>${sort.label}</span></label>`,
      )}
    </fieldset>
  </details>`;
}

export function readPrice(root) {
  const range = root.querySelector('[data-price-range]');
  if (!range) return [null, null];
  return [range.querySelector('[name="min"]').value, range.querySelector('[name="max"]').value];
}

export function openFiltersDrawer({ products, state, hide, onApply }) {
  let draft = cloneState(state);
  const titleId = nextOverlayId('filters-title');
  const prefix = nextOverlayId('dr');
  const countLabel = () => {
    const count = applyFilters(products, draft).length;
    return count === 0 ? 'Sin resultados con estos filtros' : count === 1 ? 'Ver 1 pieza' : `Ver ${count} piezas`;
  };
  const body = () => html`${sortGroup(draft, prefix)}${filterControls(products, draft, { prefix, hide })}`;

  openOverlay({
    kind: 'drawer-right',
    labelledBy: titleId,
    content: html`${overlayHeader(titleId, 'Filtrar y ordenar')}
      <div class="overlay__body" data-filters-body>${body()}</div>
      <div class="overlay__footer" style="grid-template-columns:auto 1fr;align-items:center">
        <button type="button" class="btn btn--text" data-clear-draft>Limpiar</button>
        <button type="button" class="btn btn--primary" data-apply>${countLabel()}</button>
      </div>`,
    initialFocus: '.overlay__close',
    onMount(panel, handle) {
      const bodyEl = panel.querySelector('[data-filters-body]');
      const apply = panel.querySelector('[data-apply]');
      const refresh = () => {
        const open = [...bodyEl.querySelectorAll('details')].map((details) => details.open);
        preserveFocus(() => {
          bodyEl.innerHTML = String(body());
        });
        [...bodyEl.querySelectorAll('details')].forEach((details, index) => {
          if (open[index] !== undefined) details.open = open[index] || details.open;
        });
        const count = applyFilters(products, draft).length;
        apply.textContent = countLabel();
        apply.toggleAttribute('disabled', count === 0);
      };
      panel.addEventListener('change', (event) => {
        const target = event.target;
        if (target.matches('[data-facet]')) draft = withValue(draft, target.dataset.facet, target.value, target.checked);
        else if (target.matches('[data-sort]')) draft = withSort(draft, target.value);
        else if (target.closest('[data-price-range]')) draft = withPrice(draft, ...readPrice(bodyEl));
        else return;
        refresh();
      });
      panel.addEventListener('click', (event) => {
        if (event.target.closest('[data-clear-draft]')) {
          draft = clearFilters(draft);
          refresh();
        } else if (event.target.closest('[data-apply]')) {
          draft = withPrice(draft, ...readPrice(bodyEl));
          handle.close();
          onApply(draft);
        }
      });
    },
  });
}
