// Collection, category and brand pages (/collections/:handle).
import { STYLE_TILES } from '../data/content.js';
import { collectionByHandle, collectionProducts } from '../lib/catalog.js';
import { CATEGORY_LABELS, CATEGORY_PLURALS } from '../lib/facets.js';
import { applyFilters, parseState, withValue } from '../lib/filters.js';
import { html } from '../lib/html.js';
import { listingUrl, mountListing, renderListing } from './listing.js';
import { notFoundPage } from './simple-pages.js';

const NAV_FOR = {
  guess: 'bolsas',
  crossbodys: 'bolsas',
  totes: 'bolsas',
  hombro: 'bolsas',
  'carteras-1': 'carteras',
  carteras: 'carteras',
  relojes: 'relojes',
  'relojes-1': 'relojes',
};

function styleShortcuts(currentHandle) {
  return html`<ul class="chips chips--scroll" role="list">
    <li><a class="chip" href="/collections/guess" ${currentHandle === 'guess' ? html`aria-current="page"` : ''}>Todas las bolsas</a></li>
    ${STYLE_TILES.map(
      (tile) => html`<li><a class="chip" href="/collections/${tile.handle}" ${currentHandle === tile.handle ? html`aria-current="page"` : ''}><img class="chip__thumb" src="${tile.image}" alt="" width="32" height="32">${tile.title}</a></li>`,
    )}
  </ul>`;
}

function categoryShortcuts() {
  return html`<ul class="chips chips--scroll" role="list">
    <li><a class="chip" href="/collections/guess">Bolsas</a></li>
    <li><a class="chip" href="/collections/carteras-1">Carteras</a></li>
    <li><a class="chip" href="/collections/relojes">Relojes</a></li>
    ${STYLE_TILES.map((tile) => html`<li><a class="chip" href="/collections/${tile.handle}"><img class="chip__thumb" src="${tile.image}" alt="" width="32" height="32">${tile.title}</a></li>`)}
  </ul>`;
}

/** Brand pages: category chips toggle the category filter inside the brand. */
function filterShortcuts(basePath, base, state, facetId, values, labelFor) {
  const counts = new Map();
  for (const value of values) counts.set(value, applyFilters(base, withValue({ ...state, selected: {} }, facetId, value, true)).length);
  const selected = state.selected[facetId] ?? new Set();
  return html`<ul class="chips chips--scroll" role="list">
    ${values
      .filter((value) => counts.get(value) > 0)
      .map((value) => {
        const on = selected.has(value);
        return html`<li><a class="chip" href="${listingUrl(basePath, withValue(state, facetId, value, !on))}" data-keep-scroll ${on ? html`aria-current="true"` : ''}>${labelFor(value)} <span class="chip__count">${counts.get(value)}</span></a></li>`;
      })}
  </ul>`;
}

export function collectionPage({ params, url }) {
  const collection = collectionByHandle(params.handle);
  if (!collection) return notFoundPage();
  const basePath = `/collections/${collection.handle}`;
  const base = collectionProducts(collection);
  const state = parseState(url.searchParams, { mode: 'collection' });
  const hide = [];
  let shortcuts = null;
  const crumbs = [{ label: 'Inicio', href: '/' }];

  if (collection.kind === 'category') {
    hide.push('category');
    if (collection.category === 'bolsa') shortcuts = styleShortcuts(collection.handle);
  } else if (collection.kind === 'style') {
    hide.push('category');
    crumbs.push({ label: 'Bolsas', href: '/collections/guess' });
    shortcuts = styleShortcuts(collection.handle);
  } else if (collection.kind === 'brand') {
    hide.push('brand');
    crumbs.push({ label: 'Marcas', href: '/collections/all' });
    const categories = [...new Set(base.map((product) => CATEGORY_LABELS[product.category]))];
    const slugByLabel = Object.fromEntries(Object.entries(CATEGORY_LABELS).map(([slug, label]) => [label, slug]));
    shortcuts = filterShortcuts(basePath, base, state, 'category', categories, (label) => CATEGORY_PLURALS[slugByLabel[label]] ?? label);
  } else {
    shortcuts = categoryShortcuts();
  }
  if (!hide.includes('style') && collection.kind === 'category' && collection.category !== 'bolsa') hide.push('style');
  crumbs.push({ label: collection.title, href: basePath });

  const title = state.sort === 'created-descending' && collection.kind === 'all' ? 'Novedades' : collection.title;
  const empty = {
    title: 'Muy pronto encontrarás nuevas piezas aquí',
    body: 'Esta colección no tiene piezas disponibles en la muestra.',
    mark: 'bag',
    actions: [html`<a class="btn btn--primary" href="/collections/all">Ver todo el catálogo</a>`],
  };
  const aliasNote =
    collection.aliasOf && collectionByHandle(collection.aliasOf)
      ? html`<p class="small text-muted">Ruta conservada: /collections/${collection.handle} (mismo contenido que /collections/${collection.aliasOf}).</p>`
      : '';

  // The bar's back arrow leaves the screen; this is where it goes when the visit began here.
  const back = collection.kind === 'style' ? '/collections/guess' : '/';

  return {
    title: `${title} · Monetta`,
    meta: { page: 'collection', dock: 'nav', dockActive: 'catalog', nav: title === 'Novedades' ? 'novedades' : NAV_FOR[collection.handle] ?? null, bar: true },
    html: renderListing({ basePath, base, state, title, crumbs, shortcuts, hide, empty, headingExtra: aliasNote, bar: { back } }),
    mount: (root) => mountListing(root, { basePath, base, state, hide }),
  };
}
