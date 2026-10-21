// Quick view (lib/features/product/quick_view.dart). Opened by the "+" of a
// multi-variant card, it asks for an explicit choice and hands the same
// variant to the product page link and to the cart.
import { defaultVariant } from '../lib/facets.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { addToCartFlow } from './cart-ui.js';
import { nextOverlayId, openOverlay } from './overlay.js';
import { productUrl } from './ui.js';
import { addButton, availabilityLine, errorSlot, optionSelector, priceBlock } from './variant-ui.js';

export function openQuickView(product, { requireChoice = false } = {}) {
  let selected = requireChoice && product.variants.length > 1 ? null : defaultVariant(product);
  const titleId = nextOverlayId('qv-title');
  const errorId = nextOverlayId('qv-error');
  const name = `qv-${product.id}`;
  const image = (variant) => product.images[variant?.image ?? 0] ?? product.images[0];

  const info = () => html`
    <p class="eyebrow eyebrow--muted">${product.brandLabel}</p>
    <h2 class="product-panel__name" id="${titleId}">${product.title}</h2>
    ${priceBlock(product, selected, { idPrefix: `qv-${product.id}` })}
    ${availabilityLine(product, selected)}
    <div class="product-panel__options">${optionSelector(product, selected, { name })}</div>
    <div class="product-panel__buy">
      ${addButton(product, selected, { className: 'btn btn--primary btn--block' })}
      ${errorSlot(errorId)}
      <a class="btn btn--text" href="${productUrl(product, selected?.id)}" data-details>Ver detalles completos ${icon('arrowForward', { size: 18 })}</a>
    </div>`;

  openOverlay({
    kind: 'sheet',
    labelledBy: titleId,
    content: html`<div class="overlay__header" style="border:0;padding-bottom:0">
        <p class="eyebrow" style="margin-top:14px">Vista rápida</p>
        <button type="button" class="icon-button overlay__close" data-overlay-close aria-label="Cerrar vista rápida">${icon('close', { size: 22 })}</button>
      </div>
      <div class="overlay__body">
        <div class="quick-view">
          <div class="quick-view__media"><img src="${image(selected)}" alt="${product.title}" width="600" height="800" data-qv-image></div>
          <div class="quick-view__info" data-qv-info>${info()}</div>
        </div>
      </div>`,
    initialFocus: requireChoice ? 'input[type="radio"]' : '[data-add]',
    onMount(panel) {
      const infoEl = panel.querySelector('[data-qv-info]');
      const refresh = () => {
        const focusedValue = document.activeElement?.value;
        infoEl.innerHTML = String(info());
        panel.querySelector('[data-qv-image]').src = image(selected);
        if (focusedValue) panel.querySelector(`input[value="${focusedValue}"]`)?.focus({ preventScroll: true });
      };
      panel.addEventListener('change', (event) => {
        if (event.target.name !== name) return;
        selected = product.variants.find((variant) => String(variant.id) === event.target.value) ?? null;
        refresh();
      });
      panel.addEventListener('click', (event) => {
        const button = event.target.closest('[data-add]');
        if (!button || button.dataset.pending) return;
        if (!selected) {
          panel.querySelector('[data-option-value]')?.classList.add('is-required');
          panel.querySelector('input[type="radio"]')?.focus();
          return;
        }
        if (!selected.available) return;
        addToCartFlow({ product, variant: selected, button, errorEl: panel.querySelector('[data-add-error]') });
      });
    },
  });
}
