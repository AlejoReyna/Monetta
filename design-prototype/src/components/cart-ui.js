// Cart surfaces shared by every page: the add flow (pending, success, error),
// the drawer (tablet/desktop), the "Agregado" sheet (phone) and line markup.
import { announce, isPhone, on } from '../lib/dom.js';
import { variantLabel } from '../lib/facets.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { discountPercent, formatCents, formatMoney, toCents } from '../lib/money.js';
import { addVariant, getState, removeFromCart, resolveLine, restoreLine, subscribe, totals, updateQuantity } from '../lib/store.js';
import { openCheckoutHandoff } from './handoff.js';
import { nextOverlayId, openOverlay, overlayHeader, topOverlay } from './overlay.js';
import { toast } from './toast.js';
import { productUrl, stepper } from './ui.js';

export function cartLine(line, { compact = false, highlight = false } = {}) {
  const found = resolveLine(line);
  if (!found) return '';
  const { product, variant } = found;
  const limit = variant.inventoryLimit ?? 99;
  const discount = discountPercent(variant.price, variant.compareAtPrice);
  const label = variantLabel(product, variant);
  return html`<li class="cart-line${highlight ? ' cart-line--highlight' : ''}" data-line="${variant.id}">
    <a class="cart-line__media" href="${productUrl(product, variant.id)}" tabindex="-1" aria-hidden="true">
      <img src="${product.images[variant.image] ?? product.images[0]}" alt="" width="600" height="800" loading="lazy">
    </a>
    <div class="cart-line__info">
      <p class="eyebrow eyebrow--muted">${product.brandLabel}</p>
      <a class="cart-line__name" href="${productUrl(product, variant.id)}">${product.title}</a>
      ${label ? html`<p class="cart-line__variant">${label}</p>` : ''}
      <p class="cart-line__price"><span class="price">${formatMoney(variant.price)}</span>${
        discount ? html`<span class="visually-hidden">, antes</span><s class="price-compare">${formatMoney(variant.compareAtPrice)}</s>` : ''
      }</p>
      <div class="cart-line__controls">
        ${stepper({
          value: line.quantity,
          min: 1,
          max: limit,
          decreaseLabel: `Quitar una pieza de ${product.title}`,
          increaseLabel: `Agregar una pieza de ${product.title}`,
          attrs: `data-line-stepper="${variant.id}"`,
        })}
        <button type="button" class="cart-line__remove" data-remove-line="${variant.id}">Eliminar<span class="visually-hidden"> ${product.title}</span></button>
        ${compact || line.quantity < 2 ? '' : html`<span class="cart-line__total"><span class="visually-hidden">Total de la línea: </span>${formatCents(toCents(variant.price) * line.quantity)}</span>`}
      </div>
      ${line.quantity >= limit && variant.inventoryLimit ? html`<p class="cart-line__note">Solo hay ${limit} disponibles de esta opción.</p>` : ''}
    </div>
  </li>`;
}

/** Quantity and removal controls inside [root]; works for drawer and page. */
export function bindLineControls(root) {
  const offStep = on(root, 'click', '[data-line-stepper] [data-step]', (event, button) => {
    const group = button.closest('[data-line-stepper]');
    const variantId = Number(group.dataset.lineStepper);
    const line = getState().cart.find((entry) => entry.variantId === variantId);
    if (!line) return;
    const result = updateQuantity(variantId, line.quantity + Number(button.dataset.step));
    if (result.limited) toast(`Solo hay ${result.limit} disponibles de esta opción.`, { tone: 'error' });
  });
  const offRemove = on(root, 'click', '[data-remove-line]', (event, button) => {
    const variantId = Number(button.dataset.removeLine);
    const index = getState().cart.findIndex((entry) => entry.variantId === variantId);
    const found = resolveLine({ variantId });
    const removed = removeFromCart(variantId);
    if (!removed) return;
    toast(`Eliminaste ${found?.product.title ?? 'la pieza'} del carrito.`, {
      action: { label: 'Deshacer', onClick: () => restoreLine(removed, index) },
    });
  });
  return () => {
    offStep();
    offRemove();
  };
}

function drawerBody(highlightId) {
  const { cart } = getState();
  if (!cart.length) {
    return html`<div class="cart-drawer__empty empty">
      <span class="empty__mark" aria-hidden="true">${icon('bag', { size: 28 })}</span>
      <p class="empty__title">Tu bolsa está vacía</p>
      <p class="body-copy">Encuentra una pieza que quieras llevar contigo.</p>
      <div class="empty__actions"><a class="btn btn--primary" href="/collections/all?sort_by=created-descending">Ver novedades</a></div>
    </div>`;
  }
  return html`<ul class="cart-lines cart-drawer__lines" role="list">${cart.map((line) => cartLine(line, { compact: true, highlight: line.variantId === highlightId }))}</ul>`;
}

function drawerFooter() {
  const { count, subtotal } = totals();
  if (!count) return '';
  return html`<div class="cart-drawer__summary">
      <p class="cart-drawer__subtotal"><span>Subtotal</span><span>${formatCents(subtotal, { code: true })}</span></p>
      <p class="small text-muted">Envío, impuestos y descuentos de mayoreo se calculan en el checkout de Shopify.</p>
    </div>
    <div class="cart-drawer__buttons">
      <button type="button" class="btn btn--primary btn--block" data-checkout>${icon('lock', { size: 18 })} Continuar al checkout</button>
      <a class="btn btn--outline btn--block" href="/cart">Ver carrito</a>
    </div>`;
}

export function openCartDrawer({ highlightId } = {}) {
  const existing = topOverlay();
  if (existing?.panel.dataset.cartDrawer) existing.close({ restoreFocus: false });
  const titleId = nextOverlayId('cart-title');
  const { count } = totals();
  let unsubscribe = () => {};
  let unbind = () => {};
  openOverlay({
    kind: 'drawer-right',
    labelledBy: titleId,
    content: html`${overlayHeader(titleId, count ? `Carrito (${count})` : 'Carrito')}
      <div class="overlay__body" style="padding:16px 0" data-drawer-body>${drawerBody(highlightId)}</div>
      <div class="overlay__footer" data-drawer-footer ${count ? '' : 'hidden'}>${drawerFooter()}</div>`,
    initialFocus: highlightId ? '[data-checkout]' : '.overlay__close',
    onMount(panel, handle) {
      panel.dataset.cartDrawer = 'true';
      unbind = bindLineControls(panel);
      panel.addEventListener('click', (event) => {
        if (event.target.closest('[data-checkout]')) openCheckoutHandoff();
      });
      unsubscribe = subscribe((state, change) => {
        if (change.type !== 'cart' && change.type !== 'reset') return;
        if (handle.closed) return;
        const focusedLine = document.activeElement?.closest('[data-line]')?.dataset.line;
        const focusedStep = document.activeElement?.dataset.step;
        panel.querySelector('[data-drawer-body]').innerHTML = String(drawerBody());
        const footer = panel.querySelector('[data-drawer-footer]');
        footer.innerHTML = String(drawerFooter());
        footer.hidden = totals().count === 0;
        const title = panel.querySelector('.overlay__title');
        const { count: next } = totals();
        title.textContent = next ? `Carrito (${next})` : 'Carrito';
        const restore =
          (focusedLine && focusedStep && panel.querySelector(`[data-line="${focusedLine}"] [data-step="${focusedStep}"]:not(:disabled)`)) ||
          (focusedLine && panel.querySelector(`[data-line="${focusedLine}"] [data-step]:not(:disabled)`)) ||
          panel.querySelector('.overlay__close');
        restore?.focus({ preventScroll: true });
      });
    },
    onClose() {
      unsubscribe();
      unbind();
    },
  });
}

/** Phone confirmation after an add — the app's mini cart ("En tu bolsa"). */
function openAddedSheet(product, variant) {
  const titleId = nextOverlayId('added-title');
  const { count, subtotal } = totals();
  const label = variantLabel(product, variant);
  openOverlay({
    kind: 'sheet',
    labelledBy: titleId,
    content: html`${overlayHeader(titleId, 'En tu bolsa')}
      <div class="overlay__body">
        <div class="cart-line" style="border:0;padding:0">
          <span class="cart-line__media"><img src="${product.images[variant.image] ?? product.images[0]}" alt="" width="600" height="800"></span>
          <div class="cart-line__info">
            <p class="eyebrow eyebrow--muted">${product.brandLabel}</p>
            <p class="cart-line__name">${product.title}</p>
            ${label ? html`<p class="cart-line__variant">${label}</p>` : ''}
            <p class="cart-line__price"><span class="price">${formatMoney(variant.price)}</span></p>
          </div>
        </div>
        <p class="summary__row summary__row--total" style="margin-top:16px"><span>Subtotal · ${count} ${count === 1 ? 'artículo' : 'artículos'}</span><span>${formatCents(subtotal, { code: true })}</span></p>
      </div>
      <div class="overlay__footer">
        <a class="btn btn--primary btn--block" href="/cart">Ver carrito</a>
        <button type="button" class="btn btn--outline btn--block" data-overlay-close>Seguir comprando</button>
      </div>`,
    initialFocus: '.overlay__footer .btn--primary',
  });
}

/**
 * The single add path for product page, quick view and quick add. [button]
 * shows the pending state; [errorEl] receives an inline error next to it.
 */
export async function addToCartFlow({ product, variant, quantity = 1, button, errorEl, pendingLabel = 'Agregando…', onDone, onAdded }) {
  if (!variant) return { status: 'invalid' };
  const originalLabel = button?.querySelector('[data-label]')?.textContent;
  if (button) {
    button.setAttribute('aria-disabled', 'true');
    button.setAttribute('aria-busy', 'true');
    button.dataset.pending = 'true';
    const labelEl = button.querySelector('[data-label]');
    if (labelEl) labelEl.textContent = pendingLabel;
    button.querySelector('[data-spinner]')?.removeAttribute('hidden');
  }
  if (errorEl) errorEl.hidden = true;
  const result = await addVariant(product, variant, quantity);
  if (button) {
    button.removeAttribute('aria-disabled');
    button.removeAttribute('aria-busy');
    delete button.dataset.pending;
    const labelEl = button.querySelector('[data-label]');
    if (labelEl && originalLabel) labelEl.textContent = originalLabel;
    button.querySelector('[data-spinner]')?.setAttribute('hidden', '');
  }
  const label = variantLabel(product, variant);
  const name = `${product.title}${label ? ` (${label})` : ''}`;
  switch (result.status) {
    case 'busy':
      break;
    case 'failed': {
      const message = 'No pudimos agregar la pieza. Intenta de nuevo.';
      if (errorEl) {
        errorEl.hidden = false;
        errorEl.querySelector('[data-error-text]').textContent = message;
      }
      toast(message, { tone: 'error' });
      break;
    }
    case 'soldOut':
      toast('Esta opción está agotada.', { tone: 'error' });
      break;
    case 'limited':
      toast(
        result.added > 0
          ? `Agregamos ${result.added}; solo hay ${result.limit} disponibles de esta opción.`
          : `Ya tienes en el carrito las ${result.limit} piezas disponibles de esta opción.`,
        { tone: result.added > 0 ? 'default' : 'error' },
      );
      if (result.added > 0) (onAdded ?? (() => showAdded(product, variant, name)))(result);
      break;
    case 'added':
      if (onAdded) {
        announce(`Agregado al carrito: ${name}.`);
        onAdded(result);
      } else {
        showAdded(product, variant, name);
      }
      break;
    default:
      break;
  }
  onDone?.(result);
  return result;
}

function showAdded(product, variant, name) {
  const current = topOverlay();
  if (current) current.close({ restoreFocus: false });
  if (isPhone()) openAddedSheet(product, variant);
  else openCartDrawer({ highlightId: variant.id });
  announce(`Agregado al carrito: ${name}.`);
}
