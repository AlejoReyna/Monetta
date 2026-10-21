// Faceted filtering, sorting and URL state for collection and search pages.
// Parameter names follow Shopify storefront filtering (`filter.v.*`,
// `filter.p.m.<namespace>.<key>`, `sort_by`) so the URLs map onto the theme.
import {
  CATEGORY_LABELS,
  CATEGORY_PLURALS,
  COLOR_LABELS,
  DELIVERY_LABELS,
  SILHOUETTE_LABELS,
  deliveryOf,
  isInStock,
} from './facets.js';
import { toCents } from './money.js';

export const PAGE_SIZE = 24;

const PRICE_SORTS = [
  { value: 'created-descending', label: 'Más nuevas' },
  { value: 'price-ascending', label: 'Precio: menor a mayor' },
  { value: 'price-descending', label: 'Precio: mayor a menor' },
];

export const SORTS = {
  collection: [{ value: 'manual', label: 'Destacados' }, ...PRICE_SORTS],
  search: [{ value: 'relevance', label: 'Relevancia' }, ...PRICE_SORTS],
};

const categoryPlural = Object.fromEntries(
  Object.entries(CATEGORY_LABELS).map(([slug, label]) => [label, CATEGORY_PLURALS[slug]]),
);

export const FACETS = [
  {
    id: 'availability',
    param: 'filter.v.availability',
    label: 'Disponibilidad',
    read: (product) => [isInStock(product) ? '1' : '0'],
    valueLabel: (value) => (value === '1' ? 'En existencia' : 'Agotado'),
    order: ['1', '0'],
  },
  {
    id: 'delivery',
    param: 'filter.p.m.custom.entrega',
    label: 'Entrega',
    read: (product) => {
      const delivery = deliveryOf(product);
      return delivery ? [DELIVERY_LABELS[delivery]] : [];
    },
    valueLabel: (value) => value,
    order: [DELIVERY_LABELS.inmediato, DELIVERY_LABELS.pedido],
  },
  {
    id: 'category',
    param: 'filter.p.m.custom.categoria',
    label: 'Categoría',
    read: (product) => [CATEGORY_LABELS[product.category]],
    valueLabel: (value) => categoryPlural[value] ?? value,
    order: Object.values(CATEGORY_LABELS),
  },
  {
    id: 'style',
    param: 'filter.p.m.custom.estilo',
    label: 'Estilo de bolsa',
    read: (product) => (product.silhouette ? [SILHOUETTE_LABELS[product.silhouette]] : []),
    valueLabel: (value) => value,
    order: Object.values(SILHOUETTE_LABELS),
  },
  {
    id: 'brand',
    param: 'filter.p.m.custom.marca',
    label: 'Marca',
    read: (product) => [product.brandLabel],
    valueLabel: (value) => value,
    order: null,
  },
  {
    id: 'color',
    param: 'filter.p.m.custom.color',
    label: 'Color',
    read: (product) => product.colors.map((slug) => COLOR_LABELS[slug]).filter(Boolean),
    valueLabel: (value) => value,
    order: Object.values(COLOR_LABELS),
  },
];

export const PRICE_PARAMS = { min: 'filter.v.price.gte', max: 'filter.v.price.lte' };

const FACET_BY_ID = Object.fromEntries(FACETS.map((facet) => [facet.id, facet]));

function parsePrice(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(String(value).replace(/[^\d.]/g, ''));
  return Number.isFinite(number) && number >= 0 ? Math.round(number) : null;
}

/** URLSearchParams → filter state. Unknown values are kept: they simply match nothing. */
export function parseState(params, { mode = 'collection' } = {}) {
  const selected = {};
  for (const facet of FACETS) {
    const values = params.getAll(facet.param).filter(Boolean);
    if (values.length) selected[facet.id] = new Set(values);
  }
  let priceMin = parsePrice(params.get(PRICE_PARAMS.min));
  let priceMax = parsePrice(params.get(PRICE_PARAMS.max));
  if (priceMin !== null && priceMax !== null && priceMin > priceMax) [priceMin, priceMax] = [priceMax, priceMin];
  const sorts = SORTS[mode].map((sort) => sort.value);
  const sort = sorts.includes(params.get('sort_by')) ? params.get('sort_by') : sorts[0];
  const page = Math.max(1, Number.parseInt(params.get('page') ?? '1', 10) || 1);
  const q = (params.get('q') ?? '').trim();
  return { mode, selected, priceMin, priceMax, sort, page, q };
}

/** Filter state → URLSearchParams, in a stable order, omitting defaults. */
export function serializeState(state) {
  const params = new URLSearchParams();
  if (state.mode === 'search') {
    params.set('q', state.q ?? '');
    params.set('type', 'product');
  }
  for (const facet of FACETS) {
    for (const value of state.selected[facet.id] ?? []) params.append(facet.param, value);
  }
  if (state.priceMin !== null) params.set(PRICE_PARAMS.min, String(state.priceMin));
  if (state.priceMax !== null) params.set(PRICE_PARAMS.max, String(state.priceMax));
  if (state.sort !== SORTS[state.mode][0].value) params.set('sort_by', state.sort);
  if (state.page > 1) params.set('page', String(state.page));
  return params;
}

export function cloneState(state) {
  return {
    ...state,
    selected: Object.fromEntries(Object.entries(state.selected).map(([id, values]) => [id, new Set(values)])),
  };
}

/** Any change to filters or sort goes back to the first page. */
export function withValue(state, facetId, value, on) {
  const next = cloneState(state);
  const values = next.selected[facetId] ?? new Set();
  if (on) values.add(value);
  else values.delete(value);
  if (values.size) next.selected[facetId] = values;
  else delete next.selected[facetId];
  next.page = 1;
  return next;
}

export function withPrice(state, priceMin, priceMax) {
  const next = cloneState(state);
  next.priceMin = parsePrice(priceMin);
  next.priceMax = parsePrice(priceMax);
  if (next.priceMin !== null && next.priceMax !== null && next.priceMin > next.priceMax) {
    [next.priceMin, next.priceMax] = [next.priceMax, next.priceMin];
  }
  next.page = 1;
  return next;
}

export function withSort(state, sort) {
  const next = cloneState(state);
  next.sort = SORTS[state.mode].some((option) => option.value === sort) ? sort : SORTS[state.mode][0].value;
  next.page = 1;
  return next;
}

export function clearFilters(state) {
  return { ...cloneState(state), selected: {}, priceMin: null, priceMax: null, page: 1 };
}

export function activeFilterCount(state) {
  const values = Object.values(state.selected).reduce((sum, set) => sum + set.size, 0);
  return values + (state.priceMin !== null || state.priceMax !== null ? 1 : 0);
}

function matchesFacet(product, facet, values) {
  return facet.read(product).some((value) => values.has(value));
}

function matchesPrice(product, state) {
  if (state.priceMin === null && state.priceMax === null) return true;
  const min = state.priceMin === null ? -Infinity : state.priceMin * 100;
  const max = state.priceMax === null ? Infinity : state.priceMax * 100;
  return product.variants.some((variant) => {
    const cents = toCents(variant.price);
    return cents >= min && cents <= max;
  });
}

/** Products matching every active facet (OR inside a facet, AND across facets). */
export function applyFilters(products, state, { exclude = null } = {}) {
  return products.filter((product) => {
    for (const [facetId, values] of Object.entries(state.selected)) {
      if (facetId === exclude || !values.size) continue;
      const facet = FACET_BY_ID[facetId];
      if (facet && !matchesFacet(product, facet, values)) return false;
    }
    return exclude === 'price' || matchesPrice(product, state);
  });
}

function lowestCents(product) {
  return Math.min(...product.variants.map((variant) => toCents(variant.price)));
}

export function sortProducts(products, sort) {
  const list = [...products];
  switch (sort) {
    case 'created-descending':
      return list.sort((a, b) => b.createdAt.localeCompare(a.createdAt) || a.title.localeCompare(b.title, 'es'));
    case 'price-ascending':
      return list.sort((a, b) => lowestCents(a) - lowestCents(b) || a.title.localeCompare(b.title, 'es'));
    case 'price-descending':
      return list.sort((a, b) => lowestCents(b) - lowestCents(a) || a.title.localeCompare(b.title, 'es'));
    default:
      return list; // "manual" and "relevance" keep the incoming order.
  }
}

/**
 * Options and counts per facet. Each facet counts against the products the
 * other facets allow, so a shopper sees how many pieces a choice would add.
 */
export function facetOptions(products, state, { hide = [] } = {}) {
  return FACETS.filter((facet) => !hide.includes(facet.id))
    .map((facet) => {
      const pool = applyFilters(products, state, { exclude: facet.id });
      const counts = new Map();
      for (const product of pool) {
        for (const value of new Set(facet.read(product))) counts.set(value, (counts.get(value) ?? 0) + 1);
      }
      const selected = state.selected[facet.id] ?? new Set();
      for (const value of selected) if (!counts.has(value)) counts.set(value, 0);
      const values = [...counts.keys()];
      const order = facet.order ?? [...values].sort((a, b) => a.localeCompare(b, 'es'));
      values.sort((a, b) => {
        const ia = order.indexOf(a);
        const ib = order.indexOf(b);
        return (ia === -1 ? 999 : ia) - (ib === -1 ? 999 : ib) || a.localeCompare(b, 'es');
      });
      return {
        id: facet.id,
        param: facet.param,
        label: facet.label,
        options: values.map((value) => ({
          value,
          label: facet.valueLabel(value),
          count: counts.get(value),
          selected: selected.has(value),
        })),
      };
    })
    .filter((facet) => facet.options.length > 1 || facet.options.some((option) => option.selected));
}

/** Whole-peso bounds of every variant price in [products]. */
export function priceBounds(products) {
  let min = Infinity;
  let max = -Infinity;
  for (const product of products) {
    for (const variant of product.variants) {
      const cents = toCents(variant.price);
      min = Math.min(min, cents);
      max = Math.max(max, cents);
    }
  }
  if (!Number.isFinite(min)) return { min: 0, max: 0 };
  return { min: Math.floor(min / 100), max: Math.ceil(max / 100) };
}

/** Removable chips for every active filter value. */
export function activeChips(state) {
  const chips = [];
  for (const facet of FACETS) {
    for (const value of state.selected[facet.id] ?? []) {
      chips.push({ facetId: facet.id, value, label: facet.valueLabel(value), next: withValue(state, facet.id, value, false) });
    }
  }
  if (state.priceMin !== null || state.priceMax !== null) {
    const min = state.priceMin === null ? null : `$${state.priceMin.toLocaleString('en-US')}`;
    const max = state.priceMax === null ? null : `$${state.priceMax.toLocaleString('en-US')}`;
    const label = min && max ? `${min} – ${max}` : min ? `Desde ${min}` : `Hasta ${max}`;
    chips.push({ facetId: 'price', value: 'price', label, next: withPrice(state, null, null) });
  }
  return chips;
}

/** Products, filtered, sorted and cut to the visible page count. */
export function runQuery(products, state) {
  const filtered = applyFilters(products, state);
  const sorted = sortProducts(filtered, state.sort);
  const visible = sorted.slice(0, state.page * PAGE_SIZE);
  return { total: sorted.length, visible, hasMore: visible.length < sorted.length };
}
