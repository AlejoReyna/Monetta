// Full cart (/cart): exact-variant lines, quantity and removal with undo,
// a summary that leaves shipping, taxes and wholesale discounts to Shopify,
// and the checkout handoff. On phones the checkout bar replaces the dock.
import { bindLineControls, cartLine } from '../components/cart-ui.js';
import { openCheckoutHandoff } from '../components/handoff.js';
import { pageBar } from '../components/page-bar.js';
import { emptyState, productCard, rail, sectionHeader } from '../components/ui.js';
import { newestProducts } from '../lib/catalog.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { formatCents, plural } from '../lib/money.js';
import { getState, subscribe, totals } from '../lib/store.js';
import { bindRails } from './page-behaviors.js';

function summary() {
  const { count, subtotal, compareAtSavings } = totals();
  return html`<aside class="summary" aria-labelledby="summary-title">
    <h2 class="summary__title" id="summary-title">Resumen de compra</h2>
    <dl>
      <div class="summary__row"><dt>Subtotal (${plural(count, 'artículo', 'artículos')})</dt><dd>${formatCents(subtotal)}</dd></div>
      ${compareAtSavings ? html`<div class="summary__row"><dt>Ahorro frente al precio anterior</dt><dd>${formatCents(compareAtSavings)}</dd></div>` : ''}
      <div class="summary__row"><dt>Envío</dt><dd>Se calcula en el checkout</dd></div>
      <div class="summary__row summary__row--total"><dt>Total estimado</dt><dd>${formatCents(subtotal, { code: true })}</dd></div>
    </dl>
    <p class="summary__note">Los descuentos de mayoreo se aplican automáticamente en el checkout de Shopify. Impuestos y envío finales también se confirman ahí.</p>
    <button type="button" class="btn btn--primary btn--block" data-checkout>${icon('lock', { size: 18 })} Continuar al checkout</button>
    <p class="secure-note">${icon('lock', { size: 14 })} Pago procesado por Shopify</p>
  </aside>`;
}

function content() {
  const { cart } = getState();
  const { count } = totals();
  if (!cart.length) {
    return html`${emptyState({
      title: 'Tu bolsa está vacía',
      body: 'Encuentra una pieza que quieras llevar contigo.',
      mark: 'bag',
      headingId: 'cart-empty',
      actions: [html`<a class="btn btn--primary" href="/collections/all?sort_by=created-descending">Volver a la tienda</a>`, html`<a class="btn btn--outline" href="/pages/favoritos">Ver favoritos</a>`],
    })}
    <section class="section" aria-labelledby="cart-novedades">
      ${sectionHeader({ id: 'cart-novedades', title: 'Novedades', action: { href: '/collections/all?sort_by=created-descending', label: 'Ver todo' }, railId: 'rail-cart' })}
      ${rail('rail-cart', newestProducts(8).map((product) => productCard(product, { density: 'compact' })), { label: 'Novedades' })}
    </section>`;
  }
  return html`<div class="cart-layout">
    <section aria-labelledby="cart-lines-title">
      <h2 class="visually-hidden" id="cart-lines-title">Piezas en tu bolsa (${count})</h2>
      <ul class="cart-lines" role="list">${cart.map((line) => cartLine(line))}</ul>
      <a class="btn btn--text" href="/collections/all" style="margin-top:8px">${icon('arrowBack', { size: 18 })} Seguir comprando</a>
    </section>
    ${summary()}
  </div>`;
}

function checkoutBar() {
  const { count, subtotal } = totals();
  if (!count) return '';
  return html`<div class="checkout-bar__total"><span>Total estimado</span><strong>${formatCents(subtotal, { code: true })}</strong></div>
    <button type="button" class="btn btn--primary" data-checkout>${icon('lock', { size: 18 })} Ir al checkout</button>`;
}

export function cartPage() {
  const { count } = totals();
  return {
    title: 'Mi bolsa · Monetta',
    meta: { page: 'cart', dock: count ? 'checkout' : 'nav', dockActive: 'cart', nav: null, bar: true },
    html: html`<div class="container">
        <div class="page-head page-head--bar">
          ${pageBar({
            title: 'Mi bolsa',
            back: '/',
            ruled: true,
            trailing: html`<p class="page-bar__trailing" data-cart-heading-count aria-live="polite">${plural(count, 'artículo', 'artículos')}</p>`,
          })}
        </div>
        <div data-cart-content>${content()}</div>
      </div>
      <div class="checkout-bar" data-checkout-bar>${checkoutBar()}</div>`,
    mount(root) {
      const contentEl = root.querySelector('[data-cart-content]');
      const bar = root.querySelector('[data-checkout-bar]');
      const unbindLines = bindLineControls(root);
      let unbindRails = bindRails(root);
      const onClick = (event) => {
        if (event.target.closest('[data-checkout]')) openCheckoutHandoff();
      };
      root.addEventListener('click', onClick);
      const unsubscribe = subscribe((state, change) => {
        if (change.type !== 'cart' && change.type !== 'reset') return;
        const active = document.activeElement;
        const line = active?.closest?.('[data-line]')?.dataset.line;
        const step = active?.dataset?.step;
        contentEl.innerHTML = String(content());
        bar.innerHTML = String(checkoutBar());
        const { count } = totals();
        root.querySelector('[data-cart-heading-count]').textContent = plural(count, 'artículo', 'artículos');
        document.body.classList.toggle('has-checkout-bar', count > 0);
        document.body.classList.toggle('has-dock', count === 0);
        unbindRails();
        unbindRails = bindRails(root);
        const restore =
          (line && step && root.querySelector(`[data-line="${line}"] [data-step="${step}"]:not(:disabled)`)) ||
          (line && root.querySelector(`[data-line="${line}"] [data-step]:not(:disabled)`)) ||
          (count === 0 ? root.querySelector('#cart-empty') : root.querySelector('.cart-line__name'));
        restore?.focus({ preventScroll: true });
      });
      return () => {
        unbindLines();
        unbindRails();
        unsubscribe();
        root.removeEventListener('click', onClick);
      };
    },
  };
}
