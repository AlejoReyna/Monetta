// Variant selection shared by the product page and the quick view, so both
// show the same choice, availability, price and add button for a variant.
import { SERVICE_FACTS } from '../data/content.js';
import { hasReliableSwatches, swatchFor } from '../lib/facets.js';
import { attrs, html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { discountPercent, formatMoney } from '../lib/money.js';

export function availabilityInfo(product, variant) {
  if (!variant) return { tone: 'choose', text: 'Elige una opción para ver su disponibilidad.' };
  if (!variant.available) {
    return { tone: 'soldout', text: product.variants.length > 1 ? 'Esta opción está agotada.' : 'Agotado por ahora.' };
  }
  if (product.flags.sobrePedido) return { tone: 'pedido', text: SERVICE_FACTS.sobrePedido };
  if (product.flags.envioInmediato) return { tone: 'stock', text: 'Envío inmediato · lista en el inventario de Monetta.' };
  return { tone: 'stock', text: 'Disponible.' };
}

export function availabilityLine(product, variant) {
  const info = availabilityInfo(product, variant);
  if (info.tone === 'choose') return html`<p class="availability availability--choose choice-hint" data-availability>${info.text}</p>`;
  return html`<p class="availability availability--${info.tone}" data-availability><span class="availability__dot" aria-hidden="true"></span><span>${info.text}</span></p>`;
}

export function priceBlock(product, variant, { idPrefix = 'price' } = {}) {
  const shown = variant ?? product.variants.find((entry) => entry.id === product.defaultVariantId) ?? product.variants[0];
  const discount = shown.available ? discountPercent(shown.price, shown.compareAtPrice) : null;
  return html`<div class="product-panel__price" data-price id="${idPrefix}-block">
    <span class="price">${formatMoney(shown.price, { code: true })}</span>
    ${discount ? html`<span class="visually-hidden">Precio anterior:</span><s class="price-compare">${formatMoney(shown.compareAtPrice)}</s><span class="badge badge--sale">-${discount}%</span>` : ''}
  </div>`;
}

function chip(variant, name, checked) {
  return html`<label class="option-chip${variant.available ? '' : ' option-chip--soldout'}">
    <input class="visually-hidden" type="radio" name="${name}" value="${variant.id}" ${checked ? 'checked' : ''}>
    <span class="option-chip__check" aria-hidden="true">${icon('check', { size: 16 })}</span>
    <span class="option-chip__label">${variant.title}</span>
    ${variant.available ? '' : html`<span class="option-chip__note">Agotado</span>`}
  </label>`;
}

function swatch(variant, name, checked) {
  const fill = swatchFor(variant.title).fill;
  return html`<label class="swatch${variant.available ? '' : ' swatch--soldout'}" title="${variant.title}${variant.available ? '' : ' (agotado)'}">
    <input class="visually-hidden" type="radio" name="${name}" value="${variant.id}" ${checked ? 'checked' : ''}>
    <span class="swatch__fill" style="background:${fill}" aria-hidden="true"></span>
    <span class="visually-hidden">${variant.title}${variant.available ? '' : ', agotado'}</span>
  </label>`;
}

/** ProductOptionSelector: nothing for single-variant products. */
export function optionSelector(product, selected, { name }) {
  if (product.variants.length < 2) return '';
  const option = product.options[0]?.name ?? 'Opción';
  const swatches = hasReliableSwatches(product);
  return html`<fieldset class="options" data-options>
    <legend><span class="eyebrow eyebrow--muted">${option}</span><span class="options__value" data-option-value>${selected ? selected.title : 'Elige una opción'}</span></legend>
    <div class="options__list">
      ${product.variants.map((variant) => (swatches ? swatch : chip)(variant, name, selected?.id === variant.id))}
    </div>
  </fieldset>`;
}

/** The primary add button with its label, spinner and disabled reasons. */
export function addButton(product, variant, { className = 'btn btn--primary', id } = {}) {
  const soldOut = variant && !variant.available;
  const label = !variant ? 'Elige una opción' : soldOut ? 'Agotado' : 'Agregar al carrito';
  return html`<button type="button" class="${className}" data-add ${attrs({ id, 'aria-disabled': soldOut || !variant ? 'true' : null })}>
    <span class="spinner" data-spinner hidden aria-hidden="true"></span>
    <span data-label>${label}</span>
  </button>`;
}

export function errorSlot(id) {
  return html`<p class="form-error" data-add-error id="${id}" role="alert" hidden>${icon('error', { size: 18 })}<span data-error-text></span></p>`;
}
