// Shared markup fragments: product card, section header, rail, breadcrumbs,
// empty state, quantity stepper and image helpers.
import { defaultVariant, deliveryOf, isInStock, minPrice } from '../lib/facets.js';
import { html, raw } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { discountPercent, formatMoney } from '../lib/money.js';
import { isFavorite } from '../lib/store.js';

export function productUrl(product, variantId) {
  return `/products/${product.handle}${variantId ? `?variant=${variantId}` : ''}`;
}

export function favoriteButton(product, { className = 'card__fav', size = 20, round = false } = {}) {
  const saved = isFavorite(product.handle);
  const label = `${saved ? 'Quitar de favoritos' : 'Guardar en favoritos'}: ${product.title}`;
  const glyph = icon(saved ? 'heartFilled' : 'heart', { size });
  return html`<button type="button" class="${round ? 'round-button' : className}" data-action="favorite" data-handle="${product.handle}" aria-pressed="${String(saved)}" aria-label="${label}" title="${saved ? 'Quitar de favoritos' : 'Guardar'}">${
    round ? html`<span class="round-button__circle">${glyph}</span>` : glyph
  }</button>`;
}

/**
 * The shared product card (MonettaProductTile). [density] "grid" uses a 4:5
 * photo and two-line name; "compact" a square photo and one line, for rails.
 * [flush] is photoInset 0: the packshot fills the frame on white, as in the
 * product page's recommendation rails.
 */
export function productCard(product, { density = 'grid', flush = false, favorite = true, quickAdd = true, eager = false, heading = 'h3' } = {}) {
  const variant = defaultVariant(product);
  const inStock = isInStock(product);
  const discount = inStock ? discountPercent(variant.price, variant.compareAtPrice) : null;
  const delivery = deliveryOf(product);
  const eyebrow = inStock ? (delivery === 'pedido' ? 'Sobre pedido' : delivery === 'inmediato' ? 'Envío inmediato' : null) : null;
  const multiplePrices = new Set(product.variants.map((entry) => entry.price)).size > 1;
  const price = multiplePrices ? `Desde ${formatMoney(minPrice(product))}` : formatMoney(variant.price);
  const tag = heading === 'h2' ? 'h2' : 'h3';
  return html`<article class="card card--${density}${flush ? ' card--flush' : ''}" data-product="${product.handle}">
    <a class="card__link" href="${productUrl(product)}">
      <div class="card__media">
        <img src="${product.images[0]}" alt="" width="600" height="800" loading="${eager ? 'eager' : 'lazy'}" decoding="async" data-fallback="${product.brandLabel}">
        ${discount ? html`<span class="badge badge--sale card__badge">-${discount}%</span>` : ''}
        ${inStock ? '' : html`<span class="card__soldout"><span class="badge badge--seal">Agotado</span></span>`}
      </div>
      <div class="card__body">
        ${eyebrow ? html`<p class="card__eyebrow">${eyebrow}</p>` : ''}
        <p class="card__brand">${product.brandLabel}</p>
        ${raw(`<${tag} class="card__name">`)}${product.title}${raw(`</${tag}>`)}
        <p class="card__price"><span class="price">${price}</span>${
          discount ? html`<span class="visually-hidden">, antes</span><s class="price-compare">${formatMoney(variant.compareAtPrice)}</s>` : ''
        }${inStock ? '' : html`<span class="visually-hidden">, agotado</span>`}</p>
      </div>
    </a>
    <div class="card__actions">
      ${favorite ? favoriteButton(product) : ''}
      ${
        quickAdd && inStock
          ? html`<button type="button" class="card__quick" data-action="quick-add" data-handle="${product.handle}" aria-label="Agregar ${product.title} al carrito"><span class="card__quick-circle">${icon('add', { size: 22 })}</span></button>`
          : ''
      }
    </div>
  </article>`;
}

/**
 * [role] "product" is the heading of a section inside a product page (Inter
 * 600, boutiqueSectionHeading); the default is the editorial Playfair heading
 * of Home's sections.
 */
export function sectionHeader({ id, title, kicker, action, railId, role = 'editorial' }) {
  return html`<div class="section-header">
    <div class="section-header__titles">
      ${kicker ? html`<p class="eyebrow">${kicker}</p>` : ''}
      ${
        role === 'product'
          ? html`<h2 class="product-section-title" id="${id}">${title}</h2>`
          : html`<h2 class="display display--section" id="${id}">${title}</h2>`
      }
    </div>
    <div class="section-header__actions">
      ${action ? html`<a class="link-action" href="${action.href}">${action.label} ${icon('chevronRight', { size: 16 })}<span class="visually-hidden"> ${title}</span></a>` : ''}
      ${
        railId
          ? html`<span class="rail-nav">
              <button type="button" class="icon-button" data-rail-prev="${railId}" aria-controls="${railId}" aria-label="Anteriores: ${title}">${icon('chevronLeft', { size: 22 })}</button>
              <button type="button" class="icon-button" data-rail-next="${railId}" aria-controls="${railId}" aria-label="Siguientes: ${title}">${icon('chevronRight', { size: 22 })}</button>
            </span>`
          : ''
      }
    </div>
  </div>`;
}

/**
 * Horizontal rail. [focusable] gives the scroller its own tab stop, needed
 * when its items hold no links (reviews) so keyboard users can still scroll.
 */
export function rail(id, items, { label, className = '', focusable = false } = {}) {
  return html`<div class="rail ${className}">
    <ul class="rail__track" id="${id}" role="list" aria-label="${label}" ${focusable ? raw('tabindex="0"') : ''}>
      ${items.map((item) => html`<li>${item}</li>`)}
    </ul>
  </div>`;
}

export function breadcrumbs(items) {
  return html`<nav class="breadcrumbs" aria-label="Ruta de navegación">
    <ol>
      ${items.map((item, index) =>
        index === items.length - 1
          ? html`<li><span aria-current="page">${item.label}</span></li>`
          : html`<li><a href="${item.href}">${item.label}</a></li>`,
      )}
    </ol>
  </nav>`;
}

export function emptyState({ title, body, actions = [], mark = 'search', headingId, level = 2 }) {
  const tag = level === 1 ? 'h1' : 'h2';
  return html`<div class="empty">
    <span class="empty__mark" aria-hidden="true">${icon(mark, { size: 28 })}</span>
    ${raw(`<${tag} class="empty__title"${headingId ? ` id="${headingId}"` : ''} tabindex="-1">`)}${title}${raw(`</${tag}>`)}
    ${body ? html`<p class="body-copy">${body}</p>` : ''}
    ${actions.length ? html`<div class="empty__actions">${actions}</div>` : ''}
  </div>`;
}

export function stepper({ value, min = 1, max = 99, decreaseLabel, increaseLabel, id, attrs = '' }) {
  return html`<div class="stepper" role="group" aria-label="Cantidad" ${raw(attrs)}>
    <button type="button" class="stepper__button" data-step="-1" aria-label="${decreaseLabel}" ${value <= min ? raw('disabled') : ''}>${icon('remove', { size: 20 })}</button>
    <output class="stepper__value" ${id ? raw(`id="${id}"`) : ''} aria-live="polite">${value}</output>
    <button type="button" class="stepper__button" data-step="1" aria-label="${increaseLabel}" ${value >= max ? raw('disabled') : ''}>${icon('add', { size: 20 })}</button>
  </div>`;
}

/** Brand logo cropped to its artwork bounds (see content.js LOGO_BOUNDS). */
export function brandLogo(brand) {
  const [left, top, right, bottom] = brand.bounds;
  const style = `--bl:${left};--bt:${top};--bw:${right - left};--bh:${bottom - top}`;
  return html`<span class="brand-logo" style="${style}"><img src="${brand.logo}" alt="${brand.title}" width="600" height="600" loading="lazy" decoding="async"></span>`;
}

export function stars(rating) {
  return html`<span class="review-card__stars" role="img" aria-label="${rating} de 5 estrellas">${Array.from({ length: 5 }, (_, index) =>
    icon('star', { size: 16, className: index < rating ? '' : 'is-off' }),
  )}</span>`;
}
