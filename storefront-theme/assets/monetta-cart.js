/*
 * Monetta bag behaviour. Shopify is the authority: every request goes to the store's cart endpoints and every amount,
 * discount and error shown comes back from them (rendered by Liquid through the Section Rendering API). The browser never
 * adds up prices. Lines are identified by their key, never by position, so a change made in another tab cannot hit the
 * wrong line. Without JavaScript the same controls are ordinary forms (/cart/add, /cart/change, /cart checkout).
 *
 * Mutations and checkout are coordinated here: every cart write (add, change, remove, undo) is a "mutation" that runs strictly one
 * after another, and while one is running, queued, or has ended without the bag on screen being confirmed as Shopify's, every way out
 * to checkout (the summary and bar buttons, the sheet's button, the accelerated checkout buttons, Enter on any of them) is refused.
 * The lock is released after a success or after a recovery that re-read the cart from Shopify.
 */
(() => {
  'use strict';

  const Monetta = (window.Monetta = window.Monetta || {});
  const config = window.MonettaConfig || { routes: {} };
  const routes = config.routes;
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const SHEET_SECTION = 'monetta-cart-sheet';
  const REQUEST_TIMEOUT_MS = 25000;

  const parseHtml = (html) => new DOMParser().parseFromString(html, 'text/html');
  /** `lang` for text Shopify wrote in the store's language, when that is not the page's (Spanish). */
  const storeLang = () => (config.storeLang && !/^es/i.test(config.storeLang) ? config.storeLang : '');

  async function postJson(url, payload) {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    let data = null;
    try {
      data = await response.json();
    } catch {
      /* a non-JSON error page; handled through status */
    }
    return { ok: response.ok, status: response.status, data };
  }

  /** Shopify's own wording first (stock limits, quantity rules, written in the store's language), then a calm generic message. */
  function errorMessage(result, fallback = 'No pudimos agregar la pieza. Intenta de nuevo.') {
    const data = result.data || {};
    const fromShopify = data.description || data.message;
    return { text: fromShopify || fallback, lang: fromShopify ? storeLang() : '' };
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

  /* ------------------------------------------------------------ mutations vs checkout */
  let pending = 0; // mutations started and not finished (running or waiting their turn)
  let tail = Promise.resolve(); // they run one at a time, in order
  let unconfirmed = false; // a mutation ended and the bag on screen is not known to be Shopify's

  const checkoutBlocked = () => pending > 0 || unconfirmed;

  /** Real blocking, re-applied after every render: buttons disabled, third-party checkout buttons inert, the notice shown. */
  function syncCheckoutLock() {
    const blocked = checkoutBlocked();
    for (const button of $$('[name="checkout"]')) button.disabled = blocked;
    for (const area of $$('.cart-additional-checkout')) area.inert = blocked;
    for (const notice of $$('[data-cart-sync]')) notice.hidden = !unconfirmed;
    document.documentElement.toggleAttribute('data-cart-locked', blocked);
  }

  function markConfirmed() {
    unconfirmed = false;
    syncCheckoutLock();
  }
  function markUnconfirmed() {
    unconfirmed = true;
    syncCheckoutLock();
  }

  function mutation(task) {
    pending += 1;
    syncCheckoutLock();
    const run = tail.then(task);
    tail = run.then(
      () => {},
      () => {},
    );
    return run.finally(() => {
      pending -= 1;
      syncCheckoutLock();
    });
  }

  // Capture phase: before any other listener. A checkout submitted while the bag is changing (or unconfirmed) is cancelled, whichever
  // button, key or programmatic requestSubmit() produced it.
  document.addEventListener(
    'submit',
    (event) => {
      const form = event.target;
      if (!(form instanceof HTMLFormElement) || !checkoutBlocked()) return;
      if (event.submitter?.name !== 'checkout' && !form.querySelector('[name="checkout"]')) return;
      event.preventDefault();
      event.stopImmediatePropagation();
      Monetta.announce?.(unconfirmed ? 'No pudimos confirmar tu bolsa. Actualízala antes de continuar al checkout.' : 'Estamos actualizando tu bolsa. Espera un momento y vuelve a intentarlo.');
    },
    true,
  );

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
    syncCheckoutLock();
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

  /**
   * Reads the bag from Shopify (a GET, safe to repeat). Resolves to the sections object, or null when it cannot be read or does not hold
   * every section asked for. No `Accept: application/json` here: on /cart that header makes Shopify answer with the cart object (like
   * /cart.js) and ignore `sections`, which would read back as "nothing to render".
   */
  async function fetchCartSections(ids) {
    try {
      const response = await fetch(`${routes.cart}?sections=${encodeURIComponent(ids.join(','))}`, { signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) });
      if (!response.ok) return null;
      const data = await response.json();
      return data && typeof data === 'object' && ids.every((id) => typeof data[id] === 'string') ? data : null;
    } catch {
      return null;
    }
  }

  /* ------------------------------------------------------------ the bag page */
  function cartSectionId() {
    return $('[data-cart-section]')?.dataset.sectionId || null;
  }
  const pageSections = () => [cartSectionId(), SHEET_SECTION].filter(Boolean);

  function renderCartPage(sections, { focusKey, focusStep } = {}) {
    const id = cartSectionId();
    const wrapper = $(`#shopify-section-${CSS.escape(id)}`);
    const html = sections?.[id];
    if (!wrapper || !html) return false;
    const next = parseHtml(html).querySelector(`#shopify-section-${CSS.escape(id)}`);
    if (!next || !$('[data-cart-section]', next)) return false;
    wrapper.replaceChildren(...next.childNodes);
    applySheet(sections[SHEET_SECTION]);
    const count = Number($('[data-cart-section]')?.dataset.itemCount);
    if (Number.isFinite(count)) {
      setCount(count);
      document.body.classList.toggle('has-checkout-bar', count > 0);
      document.body.classList.toggle('has-dock', count === 0);
    }
    markConfirmed();
    Monetta.refreshPinnedChrome?.();
    const line = focusKey ? $(`[data-line="${CSS.escape(focusKey)}"]`) : null;
    const target =
      (line && focusStep && $(`[data-step="${focusStep}"]:not(:disabled)`, line)) ||
      (line && $('[data-step]:not(:disabled)', line)) ||
      (count === 0 ? $('#cart-empty') : $('.cart-line__name'));
    target?.focus({ preventScroll: true });
    return true;
  }

  /**
   * After a write whose outcome is not shown from Shopify's own response (refusal, transport failure, incomplete answer): read the bag
   * again and render it. If that cannot be done either, the bag on screen stays unconfirmed and checkout stays locked until it can.
   */
  async function recoverFromServer(focus) {
    const ids = pageSections();
    const sections = await fetchCartSections(ids);
    if (cartSectionId()) {
      if (sections && renderCartPage(sections, focus)) return true;
    } else if (sections && applySheet(sections[SHEET_SECTION])) {
      markConfirmed();
      return true;
    }
    markUnconfirmed();
    return false;
  }

  /* ------------------------------------------------------------ add */
  /**
   * The single add path (product page, quick add). Returns { ok, status, message, lang }. Opening the sheet, announcing and the
   * count are done here; the caller handles pending state and its own inline error. A write whose result is unknown (no answer, a 5xx)
   * is never repeated: the bag is read back and shown, and the message tells the shopper to check it before trying again.
   */
  function add({ id, quantity = 1, properties, name = '', trigger = null }) {
    return mutation(async () => {
      const cartId = cartSectionId();
      const payload = { id: Number(id), quantity: Number(quantity), sections: [SHEET_SECTION, cartId].filter(Boolean).join(','), sections_url: cartId ? routes.cart : location.pathname };
      if (properties) payload.properties = properties;
      let result;
      try {
        result = await postJson(routes.cartAdd, payload);
      } catch {
        result = { ok: false, status: 0, data: null };
      }
      if (!result.ok && result.status >= 400 && result.status < 500) {
        const { text, lang } = errorMessage(result);
        Monetta.toast?.(text, { tone: 'error', lang });
        return { ok: false, status: result.status, message: text, lang };
      }
      if (!result.ok) return uncertainAdd(result.status, trigger);

      const shown = cartId ? renderCartPage(result.data?.sections || {}) : false;
      if (!shown && !applySheet(result.data?.sections?.[SHEET_SECTION], { highlightVariantId: Number(id) })) {
        // Shopify accepted it but the answer carries no usable bag: show the bag as Shopify has it.
        await recoverFromServer();
      } else {
        markConfirmed();
        $(`[data-variant-id="${Number(id)}"]`, $('#cart-sheet'))?.classList.add('cart-line--highlight');
      }
      openSheet(trigger);
      Monetta.announce?.(`Agregado al carrito${name ? `: ${name}` : ''}.`);
      return { ok: true, status: result.status };
    });
  }

  async function uncertainAdd(status, trigger) {
    const message = 'No pudimos confirmar si la pieza se agregó. Revisa tu bolsa antes de volver a intentarlo.';
    if (await recoverFromServer()) openSheet(trigger);
    Monetta.toast?.(message, { tone: 'error' });
    return { ok: false, status, message, lang: '', uncertain: true };
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
  Monetta.cart = { add, isLocked: checkoutBlocked };

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

  /* ------------------------------------------------------------ change, remove, undo */
  /** What identifies a line besides its variant: the properties (public and private) and the selling plan, as the line rendered them. */
  function readRestore(row) {
    try {
      const data = JSON.parse(row?.dataset.restore || '');
      if (!Number.isInteger(data.id) || !Number.isInteger(data.quantity) || data.quantity < 1) return null;
      // An object of properties; a list of [name, value] pairs is accepted too, so a different serialisation can never read as "none".
      const raw = data.properties;
      const properties = Array.isArray(raw) ? Object.fromEntries(raw.filter((pair) => Array.isArray(pair) && pair.length === 2)) : raw && typeof raw === 'object' ? raw : {};
      return { id: data.id, quantity: data.quantity, properties, selling_plan: Number.isInteger(data.selling_plan) ? data.selling_plan : null };
    } catch {
      return null;
    }
  }

  const sameProperties = (a = {}, b = {}) => {
    const left = Object.entries(a || {}).filter(([, value]) => value !== '' && value != null);
    const right = Object.entries(b || {}).filter(([, value]) => value !== '' && value != null);
    return left.length === right.length && left.every(([key, value]) => String(b?.[key]) === String(value));
  };

  /** Puts a removed line back with everything that made it that line. Shopify's refusal is shown as is; nothing else is added instead. */
  function undoRemoval(restore) {
    return mutation(async () => {
      const sections = pageSections().join(',');
      const payload = { id: restore.id, quantity: restore.quantity, sections, sections_url: routes.cart };
      if (Object.keys(restore.properties).length) payload.properties = restore.properties;
      if (restore.selling_plan) payload.selling_plan = restore.selling_plan;
      let result;
      try {
        result = await postJson(routes.cartAdd, payload);
      } catch {
        result = { ok: false, status: 0, data: null };
      }
      if (result.ok) {
        const item = result.data;
        const planId = item?.selling_plan_allocation?.selling_plan?.id ?? null;
        const identityKept = item && Number(item.variant_id ?? item.id) === restore.id && sameProperties(item.properties, restore.properties) && planId === restore.selling_plan;
        const shown = cartSectionId() ? renderCartPage(result.data?.sections || {}) : applySheet(result.data?.sections?.[SHEET_SECTION]);
        if (!shown) await recoverFromServer();
        else markConfirmed();
        if (!identityKept) Monetta.toast?.('Restauramos la pieza, pero Shopify la registró con datos distintos a los de antes. Revisa tu bolsa.', { tone: 'error' });
        return;
      }
      if (result.status >= 400 && result.status < 500) {
        const { text, lang } = errorMessage(result, 'No pudimos restaurar la pieza. Intenta de nuevo.');
        Monetta.toast?.(text, { tone: 'error', lang });
      } else {
        Monetta.toast?.('No pudimos confirmar si la pieza se restauró. Revisa tu bolsa antes de volver a intentarlo.', { tone: 'error' });
      }
      await recoverFromServer();
    });
  }

  async function changeLine({ key, quantity, step, name, restore }) {
    const id = cartSectionId();
    // One change at a time, and none on top of a bag that is not confirmed: a click made on stale numbers would send stale numbers.
    if (!id || checkoutBlocked()) {
      if (unconfirmed) Monetta.announce?.('Actualiza tu bolsa antes de hacer más cambios.');
      return;
    }
    const line = $(`[data-line="${CSS.escape(key)}"]`);
    line?.setAttribute('aria-busy', 'true');
    await mutation(async () => {
      try {
        let result;
        try {
          result = await postJson(routes.cartChange, { id: key, quantity, sections: `${id},${SHEET_SECTION}`, sections_url: routes.cart });
        } catch {
          result = { ok: false, status: 0, data: null };
        }
        if (result.ok && renderCartPage(result.data?.sections || {}, { focusKey: quantity > 0 ? key : null, focusStep: step })) {
          if (quantity === 0) {
            Monetta.toast?.(`Eliminaste ${name || 'la pieza'} del carrito.`, {
              action: restore ? { label: 'Deshacer', onClick: () => undoRemoval(restore) } : null,
            });
          }
          return;
        }
        if (result.status >= 400 && result.status < 500) {
          // Shopify refused (stock ceiling, quantity rule): say so in its words and show the cart as it really is.
          const { text, lang } = errorMessage(result, 'No pudimos actualizar la bolsa. Intenta de nuevo.');
          Monetta.toast?.(text, { tone: 'error', lang });
        } else {
          Monetta.toast?.(result.ok ? 'No pudimos mostrar tu bolsa actualizada.' : 'No pudimos confirmar el cambio. Revisamos tu bolsa para mostrarla como está.', { tone: 'error' });
        }
        await recoverFromServer({ focusKey: key, focusStep: step });
      } finally {
        line?.removeAttribute('aria-busy');
      }
    });
  }

  document.addEventListener('submit', (event) => {
    const form = event.target.closest?.('[data-line-form]');
    if (!form) return;
    event.preventDefault();
    const submitter = event.submitter;
    if (!submitter || submitter.disabled) return;
    const row = form.closest('[data-line]');
    changeLine({
      key: form.elements.id.value,
      quantity: Number(submitter.value),
      step: submitter.dataset.step || null,
      name: row?.querySelector('.cart-line__name')?.textContent?.trim(),
      restore: readRestore(row),
    });
  });

  // "Actualizar bolsa": the way out of an unconfirmed state. It reads the bag again; checkout stays locked until that succeeds.
  document.addEventListener('click', (event) => {
    if (!event.target.closest?.('[data-cart-resync]')) return;
    event.preventDefault();
    mutation(() => recoverFromServer());
  });

  // Amounts and availability in the bag were Shopify's when this page rendered; a restored or long-hidden page asks again.
  let hiddenAt = 0;
  const revalidate = async () => {
    if (!cartSectionId() || checkoutBlocked()) return;
    const sections = await fetchCartSections(pageSections());
    if (sections) renderCartPage(sections);
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
    syncCheckoutLock();
  });
})();
