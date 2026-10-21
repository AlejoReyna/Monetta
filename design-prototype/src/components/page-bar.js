// Compact interior header for phones (lib/features/navigation/
// monetta_page_header.dart): back, Playfair title and the page's own actions in
// one pinned bar. Tablet and desktop keep the global header and breadcrumbs, so
// there the bar is only the title row (back and actions are hidden by CSS).
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';

/** Filter and sort entry (collection_screen.dart _CollectionFilterIconButton), with the active count. */
export function filtersAction(count = 0) {
  const label = count ? `Filtrar y ordenar, ${count} ${count === 1 ? 'activo' : 'activos'}` : 'Filtrar y ordenar';
  return html`<button type="button" class="icon-button page-bar__action" data-open-filters aria-haspopup="dialog" aria-label="${label}" title="Filtrar y ordenar">${icon('tune', { size: 24 })}${
    count ? html`<span class="page-bar__badge" aria-hidden="true">${count}</span>` : ''
  }</button>`;
}

/** The web has no other one-tap way into search from a listing; the app reaches it from Home. */
export function searchAction() {
  return html`<a class="icon-button page-bar__action" href="/search" aria-label="Buscar productos" title="Buscar">${icon('search', { size: 22 })}</a>`;
}

/**
 * [heading] false renders the title as plain text when the page's h1 lives
 * elsewhere (search results). [phoneOnly] hides the whole bar from tablet up.
 * [sub] and [trailing] arrive as markup so the page keeps its live regions.
 * [back] is the parent screen, used only when the visit began on this page.
 * [ruled] keeps the hairline under the bar even before the page scrolls (the
 * bag: the app's first line draws its top border right under the header).
 */
export function pageBar({ title, heading = true, phoneOnly = false, back = '/', sub = '', trailing = '', actions = [], ruled = false }) {
  const classes = ['page-bar', phoneOnly ? 'page-bar--phone' : '', trailing ? 'page-bar--trailing' : '', ruled ? 'page-bar--ruled' : ''].filter(Boolean).join(' ');
  const hasActions = actions.some(Boolean);
  return html`<div class="${classes}" data-page-bar>
    <a class="icon-button page-bar__back" href="${back}" data-action="back" aria-label="Volver">${icon('arrowBack', { size: 20 })}</a>
    <div class="page-bar__titles${hasActions ? ' page-bar__titles--actions' : ''}">
      ${
        heading
          ? html`<h1 class="display display--page page-bar__title" tabindex="-1">${title}</h1>`
          : html`<p class="display display--page page-bar__title">${title}</p>`
      }
      ${sub}
    </div>
    ${trailing}
    ${hasActions ? html`<div class="page-bar__actions">${actions}</div>` : ''}
  </div>`;
}
