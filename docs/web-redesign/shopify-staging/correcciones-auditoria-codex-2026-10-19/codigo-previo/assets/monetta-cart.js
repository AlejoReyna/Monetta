/*
 * Monetta bag behaviour. Shopify is the authority: every request goes to the store's cart endpoints and every amount,
 * discount and error shown comes back from them (rendered by Liquid through the Section Rendering API). The browser never
 * adds up prices. Lines are identified by their key, never by position, so a change made in another tab cannot hit the
 * wrong line. Without JavaScript the same controls are ordinary forms (/cart/add, /cart/change, /cart checkout).
 */
(() => {
  'use strict';

  const Monetta = (window.Monetta = window.Monetta || {});
  const config = window.MonettaConfig || { routes: {} };
  const routes = config.routes;
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const SHEET_SECTION = 'monetta-cart-sheet';

  const parseHtml = (html) => new DOMParser().parseFromString(html, 'text/html');

  async function postJson(url, payload) {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(payload),
    });
    let data = null;
    try {
      data = await response.json();
    } catch {
      /* a non-JSON error page; handled through status */
    }
    return { ok: response.ok, status: response.status, data };
  }

  /** Shopify's own wording first (stock limits, quantity rules), then a calm generic message. */
  function errorMessage(result) {
    const data = result.data || {};
    return data.description || data.message || 'No pudimos agregar la pieza. Intenta de nuevo.';
  }

  /* ------------------------------------------------------------ counts */
  function setCount(count) {
    for (const badge of $$('[data-cart-count]')) {
      badge.hidden = count === 0;
      badge.textContent = count > 9 ? '9+' : String(count);
    }
    const label = count ? `Carrito, ${count} ${count === 1 ? 'artículo' : 'artículos'}` : 'Carrito, vacío';
    $('[data-cart-link]')?.setAttribute('aria-label', label);
    $('[data-dock="cart"]')?.setAttribute('aria-label', count ? label : 'Carrito');
  }
  Monetta.setCartCount = setCount;

  /* ------------------------------------------------------------ the "En tu bolsa" sheet */
  function applySheet(html, { highlightVariantId } = {}) {
    const sheet = $('#cart-sheet');
    if (!sheet || !html) return null;
    const next = parseHtml(html).querySelector('#cart-sheet');
    if (!next) return null;
    sheet.replaceChildren(...next.childNodes);
    const total = Number($('[data-cart-total]', sheet)?.textContent);
    if (Number.isFinite(total)) setCount(total);
    if (highlightVariantId) {
      $(`[data-variant-id="${highlightVariantId}"]`, sheet)?.classList.add('cart-line--highlight');
    }
    return sheet;
  }

  function openSheet(trigger) {
    const sheet = $('#cart-sheet');
    if (!sheet) return;
    // Right drawer from 768 px, bottom sheet below (the ported .overlay--* rules are mutually exclusive).
    const wide = window.matchMedia('(min-width: 768px)').matches;
    sheet.classList.toggle('overlay--drawer-right', wide);
    sheet.classList.toggle('overlay--sheet', !wide);
    if (sheet.open) {
      sheet.querySelector('.overlay__footer .btn--primary')?.focus({ preventScroll: true });
      return;
    }
    Monetta.openDialog(sheet, trigger);
    sheet.querySelector('.overlay__footer .btn--primary')?.focus({ preventScroll: true });
  }

  /* ------------------------------------------------------------ add */
  /**
   * The single add path (product page, quick add). Returns { ok, status, message }. Opening the sheet, announcing and the
   * count are done here; the caller handles pending state and its own inline error.
   */
  async function add({ id, quantity = 1, properties, name = '', trigger = null }) {
    const payload = { id: Number(id), quantity: Number(quantity), sections: SHEET_SECTION, sections_url: location.pathname };
    if (properties) payload.properties = properties;
    let result;
    try {
      result = await postJson(routes.cartAdd, payload);
    } catch {
      const message = 'No pudimos conectar con la tienda. Revisa tu conexión e intenta de nuevo.';
      Monetta.toast?.(message, { tone: 'error' });
      return { ok: false, status: 0, message };
    }
    if (!result.ok) {
      const message = errorMessage(result);
      Monetta.toast?.(message, { tone: 'error' });
      return { ok: false, status: result.status, message };
    }
    applySheet(result.data?.sections?.[SHEET_SECTION], { highlightVariantId: Number(id) });
    openSheet(trigger);
    Monetta.announce?.(`Agregado al carrito${name ? `: ${name}` : ''}.`);
    return { ok: true, status: result.status };
  }

  function setPending(button, pending, label = 'Agregando…') {
    if (!button) return;
    const text = button.querySelector('[data-label]');
    const spinner = button.querySelector('[data-spinner]');
    if (pending) {
      button.dataset.pending = 'true';
      button.setAttribute('aria-busy', 'true');
      button.setAttribute('aria-disabled', 'true');
      if (text) {
        button.dataset.originalLabel = text.textContent;
        text.textContent = label;
      }
      spinner?.removeAttribute('hidden');
    } else {
      delete button.dataset.pending;
      button.removeAttribute('aria-busy');
      button.removeAttribute('aria-disabled');
      if (text && button.dataset.originalLabel) text.textContent = button.dataset.originalLabel;
      delete button.dataset.originalLabel;
      spinner?.setAttribute('hidden', '');
    }
  }
  Monetta.setPending = setPending;
  Monetta.cart = { add };

  // Quick add on cards: one buyable variant, added directly.
  document.addEventListener('submit', async (event) => {
    const form = event.target.closest?.('[data-quick-add]');
    if (!form) return;
    event.preventDefault();
    const button = form.querySelector('button');
    if (button?.dataset.pending) return;
    button?.setAttribute('aria-busy', 'true');
    button.dataset.pending = 'true';
    const card = form.closest('.card');
    const name = card?.querySelector('.card__name')?.textContent?.trim() || '';
    await add({ id: form.elements.id.value, quantity: 1, name, trigger: button });
    button?.removeAttribute('aria-busy');
    delete button.dataset.pending;
  });

  /* ------------------------------------------------------------ the bag page */
  function cartSectionId() {
    return $('[data-cart-section]')?.dataset.sectionId || null;
  }

  async function fetchCartSections() {
    const id = cartSectionId();
    if (!id) return null;
    const response = await fetch(`${routes.cart}?sections=${encodeURIComponent(`${id},${SHEET_SECTION}`)}`, { headers: { Accept: 'application/json' } });
    if (!response.ok) return null;
    return response.json();
  }

  function renderCartPage(sections, { focusKey, focusStep } = {}) {
    const id = cartSectionId();
    const wrapper = $(`#shopify-section-${CSS.escape(id)}`);
    const html = sections?.[id];
    if (!wrapper || !html) return false;
    const next = parseHtml(html).querySelector(`#shopify-section-${CSS.escape(id)}`);
    if (!next) return false;
    wrapper.replaceChildren(...next.childNodes);
    applySheet(sections[SHEET_SECTION]);
    const count = Number($('[data-cart-section]')?.dataset.itemCount);
    if (Number.isFinite(count)) {
      setCount(count);
      document.body.classList.toggle('has-checkout-bar', count > 0);
      document.body.classList.toggle('has-dock', count === 0);
    }
    Monetta.refreshPinnedChrome?.();
    const line = focusKey ? $(`[data-line="${CSS.escape(focusKey)}"]`) : null;
    const target =
      (line && focusStep && $(`[data-step="${focusStep}"]:not(:disabled)`, line)) ||
      (line && $('[data-step]:not(:disabled)', line)) ||
      (count === 0 ? $('#cart-empty') : $('.cart-line__name'));
    target?.focus({ preventScroll: true });
    return true;
  }

  let changing = false;
  async function changeLine({ key, quantity, step, name, variantId, previousQuantity }) {
    if (changing) return;
    const id = cartSectionId();
    if (!id) return;
    changing = true;
    const line = $(`[data-line="${CSS.escape(key)}"]`);
    line?.setAttribute('aria-busy', 'true');
    try {
      const result = await postJson(routes.cartChange, {
        id: key,
        quantity,
        sections: `${id},${SHEET_SECTION}`,
        sections_url: routes.cart,
      });
      if (result.ok && result.data?.sections) {
        renderCartPage(result.data.sections, { focusKey: quantity > 0 ? key : null, focusStep: step });
        if (quantity === 0) {
          Monetta.toast?.(`Eliminaste ${name || 'la pieza'} del carrito.`, {
            action: {
              label: 'Deshacer',
              onClick: async () => {
                const restored = await postJson(routes.cartAdd, { id: variantId, quantity: previousQuantity, sections: `${id},${SHEET_SECTION}`, sections_url: routes.cart });
                if (restored.ok && restored.data?.sections) renderCartPage(restored.data.sections);
                else Monetta.toast?.(errorMessage(restored), { tone: 'error' });
              },
            },
          });
        }
      } else {
        // Shopify refused (stock ceiling, quantity rule): say so in its words and show the cart as it really is.
        Monetta.toast?.(result.data?.description || result.data?.message || 'No pudimos actualizar la bolsa. Intenta de nuevo.', { tone: 'error' });
        renderCartPage(await fetchCartSections(), { focusKey: key, focusStep: step });
      }
    } catch {
      Monetta.toast?.('No pudimos conectar con la tienda. Revisa tu conexión e intenta de nuevo.', { tone: 'error' });
    } finally {
      changing = false;
      line?.removeAttribute('aria-busy');
    }
  }

  document.addEventListener('submit', (event) => {
    const form = event.target.closest?.('[data-line-form]');
    if (!form) return;
    event.preventDefault();
    const submitter = event.submitter;
    if (!submitter || submitter.disabled) return;
    const row = form.closest('[data-line]');
    const quantity = Number(submitter.value);
    changeLine({
      key: form.elements.id.value,
      quantity,
      step: submitter.dataset.step || null,
      name: row?.querySelector('.cart-line__name')?.textContent?.trim(),
      variantId: Number(row?.dataset.variantId),
      previousQuantity: Number(form.querySelector('.stepper__value')?.textContent) || 1,
    });
  });

  // Amounts and availability in the bag were Shopify's when this page rendered; a restored or long-hidden page asks again.
  let hiddenAt = 0;
  const revalidate = async () => {
    if (!cartSectionId() || changing) return;
    renderCartPage(await fetchCartSections());
  };
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      hiddenAt = Date.now();
    } else if (hiddenAt && Date.now() - hiddenAt > 30000) {
      hiddenAt = 0;
      revalidate();
    }
  });
  window.addEventListener('pageshow', (event) => {
    if (event.persisted) revalidate();
  });

  // The theme editor swaps section markup; keep the count honest after it.
  document.addEventListener('shopify:section:load', () => {
    const total = Number($('[data-cart-total]')?.textContent);
    if (Number.isFinite(total)) setCount(total);
  });
})();
