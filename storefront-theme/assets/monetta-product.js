/*
 * Monetta product page. The server renders the page; this file only moves things without a reload:
 *  - the gallery (snap scrolling, thumbnails, arrow keys),
 *  - option changes: the browser works out which variant the shopper chose, then asks Shopify for this same section with
 *    ?variant=ID (Section Rendering API) and swaps the price / availability / buttons it returns, so nothing commercial is
 *    cached or recomputed here,
 *  - the quantity stepper and the add button's states (waiting, success, error, no double sends),
 *  - the lazily requested recommendations rail.
 * The add request carries the exact variant id; it is never substituted. A choice that Shopify has not confirmed (pending, failed,
 * answered with an incomplete document) blocks adding and the accelerated checkout; see "variants" below.
 */
(() => {
  'use strict';

  const Monetta = (window.Monetta = window.Monetta || {});
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const reduceMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const page = () => $('[data-product-page]');

  /* ------------------------------------------------------------ gallery */
  function initGallery() {
    const root = page();
    const track = $('[data-gallery]', root || document);
    if (!root || !track) return;
    const thumbs = $$('[data-thumb]', root);
    const rules = $$('.gallery__rules span', root);
    const slides = $$('.gallery__slide', track);
    let current = Number(root.dataset.selectedIndex) || 0;
    const behavior = () => (reduceMotion() ? 'auto' : 'smooth');

    const mark = (index) => {
      current = index;
      thumbs.forEach((thumb, i) => thumb.setAttribute('aria-current', String(i === index)));
      rules.forEach((rule, i) => (rule.dataset.active = String(i === index)));
    };
    const goTo = (index, smooth = true) => {
      const clamped = Math.max(0, Math.min(slides.length - 1, index));
      track.scrollTo({ left: clamped * track.clientWidth, behavior: smooth ? behavior() : 'auto' });
      mark(clamped);
    };
    Monetta.gallery = { goTo, count: () => slides.length };

    if (typeof ResizeObserver !== 'undefined') {
      new ResizeObserver(() => track.scrollTo({ left: current * track.clientWidth, behavior: 'auto' })).observe(track);
    }
    let timer = 0;
    track.addEventListener(
      'scroll',
      () => {
        window.clearTimeout(timer);
        timer = window.setTimeout(() => mark(Math.round(track.scrollLeft / Math.max(1, track.clientWidth))), 60);
      },
      { passive: true },
    );
    track.addEventListener('keydown', (event) => {
      const index = Math.round(track.scrollLeft / Math.max(1, track.clientWidth));
      if (event.key === 'ArrowRight') {
        event.preventDefault();
        goTo(index + 1);
      } else if (event.key === 'ArrowLeft') {
        event.preventDefault();
        goTo(index - 1);
      }
    });
    thumbs.forEach((thumb) => thumb.addEventListener('click', () => goTo(Number(thumb.dataset.thumb))));
    if (current > 0) requestAnimationFrame(() => goTo(current, false));
  }

  /* ------------------------------------------------------------ variants */
  // The page always shows ONE variant: the one Shopify rendered (hidden input [data-variant-id], price, availability, buttons,
  // address). A choice on the chips is only a request until Shopify renders that variant; until then the page is "pending" and adding
  // and paying are refused (not just dimmed). If the confirmation fails, the chips go back to the rendered variant. So the id a
  // button sends, the option on screen and the price beside it can only disagree while the buttons are dead.
  const readVariants = () => {
    try {
      return JSON.parse($('[data-product-variants]', page())?.textContent || '[]');
    } catch {
      return [];
    }
  };
  const variantById = (id) => readVariants().find((variant) => variant.id === Number(id)) || null;
  const shownId = (root = page()) => Number($('[data-variant-id]', root)?.value) || 0;
  const chosenValues = (root = page()) => $$('[data-options] fieldset', root).map((group) => $('input:checked', group)?.value);
  const describe = (variant) => (variant ? variant.options.join(' / ') : '');
  // Without a script the options are links (css hides the radios); with this one running the radios take over.
  document.documentElement.classList.add('mw-variants-js');

  /** True when the choice on screen is the variant the form would send AND Shopify has confirmed it. The only gate for adding and paying. */
  function purchasable() {
    const root = page();
    if (!root || root.dataset.selection !== 'valid') return false;
    const variant = variantById(shownId(root));
    if (!variant) return false;
    const chosen = chosenValues(root);
    return chosen.every((value, index) => value === variant.options[index]);
  }

  /** Puts the chips (and the value beside each option name) on a variant. */
  function showChoice(root, variant) {
    if (!variant) return;
    $$('[data-options] fieldset', root).forEach((group, index) => {
      const input = $$('[data-option-input]', group).find((radio) => radio.value === variant.options[index]);
      if (input) input.checked = true;
      const value = $('[data-option-value]', group);
      if (value) value.textContent = variant.options[index];
    });
  }

  function showError(root, text, lang = '') {
    const box = $('[data-add-error]', root);
    if (!box) return;
    const target = $('[data-error-text]', box);
    target.textContent = text;
    if (lang) target.lang = lang;
    else target.removeAttribute('lang');
    box.hidden = false;
  }
  function hideError(root) {
    const box = $('[data-add-error]', root);
    if (box) box.hidden = true;
  }

  /** Real blocking: the add buttons are disabled and the accelerated-checkout / WhatsApp area is inert. Remembers what the server had. */
  function lockPurchase(root, locked) {
    for (const button of $$('[data-add]', root)) {
      if (locked) {
        if (button.dataset.lockedWasDisabled === undefined) button.dataset.lockedWasDisabled = button.disabled ? '1' : '0';
        button.disabled = true;
      } else if (button.dataset.lockedWasDisabled !== undefined) {
        button.disabled = button.dataset.lockedWasDisabled === '1';
        delete button.dataset.lockedWasDisabled;
      }
    }
    for (const area of $$('.other-ways', root)) area.inert = locked;
  }

  function setStatus(root, text) {
    const status = $('[data-selection-status]', root);
    if (!status) return;
    status.textContent = text || '';
    status.hidden = !text;
  }

  // Capture phase, before Shopify's own listeners on the accelerated-checkout button: while the choice is unconfirmed, nothing that
  // buys (add buttons, "Buy it now", wallet buttons) or quotes (the WhatsApp request names the variant and price) may act.
  document.addEventListener(
    'click',
    (event) => {
      const root = page();
      if (!root || purchasable()) return;
      if (event.target.closest?.('[data-add], .other-ways')) {
        event.preventDefault();
        event.stopImmediatePropagation();
      }
    },
    true,
  );

  let sequence = 0; // every choice takes the next number; only the newest may touch the page
  let controller = null;
  let validatedId = 0;

  /** The section Shopify rendered for ?variant=ID, or an Error when it is not a complete, coherent product section. */
  function validateSection(doc, root) {
    const next = $('[data-product-page]', doc);
    const dynamic = next && $('[data-product-dynamic]', next);
    const dock = next && $('[data-purchase-dock]', next);
    const id = Number(dynamic && $('[data-variant-id]', dynamic)?.value);
    let variants = [];
    try {
      variants = JSON.parse((dynamic && $('[data-product-variants]', dynamic)?.textContent) || '[]');
    } catch {
      /* rejected below */
    }
    const variant = variants.find((candidate) => candidate.id === id);
    if (!next || next.dataset.sectionId !== root.dataset.sectionId || !dynamic || !dock || !variant || !$('[data-product-form]', dynamic) || !$('[data-add]', dock)) {
      throw new Error('invalid-section');
    }
    const rendered = $$('[data-options] fieldset', dynamic).map((group) => $('input:checked', group)?.value);
    if (!rendered.every((value, index) => value === variant.options[index])) throw new Error('incoherent-section');
    return { next, variant };
  }

  /**
   * Asks Shopify to render the product section for a variant and swaps it in only when it is complete and still the newest request.
   *  - 'choice':  the shopper picked a chip. Buying is locked meanwhile; on failure the chips return to the rendered variant.
   *  - 'resync':  Shopify refused an add (422): the rendered variant is not real. Locked; on failure it stays locked and asks for a reload.
   *  - 'refresh': a restored or long-hidden page asks again for the variant it already shows. Buying is not locked; failure is only reported.
   */
  async function confirmVariant(variantId, { kind = 'choice', announceAvailability = true, keepError = '' } = {}) {
    const root = page();
    if (!root) return;
    const mine = ++sequence;
    controller?.abort();
    controller = new AbortController();
    const { signal } = controller;
    const label = describe(variantById(variantId));
    if (kind !== 'refresh') {
      root.dataset.selection = 'pending';
      root.setAttribute('aria-busy', 'true');
      lockPurchase(root, true);
      hideError(root);
      setStatus(root, label ? `Confirmando disponibilidad de ${label}…` : 'Confirmando disponibilidad…');
    }
    const focused = document.activeElement;
    const focusedValue = focused?.matches?.('[data-option-input]') ? { position: focused.closest('fieldset').dataset.optionPosition, value: focused.value } : null;
    let section;
    try {
      const url = `${root.dataset.productUrl}?variant=${variantId}&section_id=${encodeURIComponent(root.dataset.sectionId)}`;
      const response = await fetch(url, { signal, headers: { Accept: 'text/html' } });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const text = await response.text();
      if (mine !== sequence) return; // a newer choice owns the page; this answer, however late, is ignored
      section = validateSection(new DOMParser().parseFromString(text, 'text/html'), root);
    } catch (error) {
      if (mine !== sequence || error?.name === 'AbortError') return;
      failConfirmation(root, { kind, label });
      return;
    }
    if (mine !== sequence) return;

    const { next, variant } = section;
    $('[data-product-dynamic]', root).replaceChildren(...$('[data-product-dynamic]', next).childNodes);
    $('[data-purchase-dock]', root).replaceChildren(...$('[data-purchase-dock]', next).childNodes);
    const seal = $('[data-seal]', root);
    const nextSeal = $('[data-seal]', next);
    if (seal && nextSeal) seal.hidden = nextSeal.hidden;
    validatedId = variant.id;
    root.dataset.selection = 'valid';
    root.removeAttribute('aria-busy');
    // The address names the variant Shopify actually rendered (an unknown id falls back to the default variant); a pending "back"
    // fallback must not act on it.
    history.replaceState(history.state, '', `${root.dataset.productUrl}?variant=${variant.id}`);
    Monetta.noteNavigation?.();
    Monetta.gallery?.goTo(Number(next.dataset.selectedIndex) || 0);
    if (focusedValue) {
      $(`fieldset[data-option-position="${focusedValue.position}"] input[value="${CSS.escape(focusedValue.value)}"]`, root)?.focus({ preventScroll: true });
    }
    if (keepError) showError(root, keepError.text, keepError.lang);
    if (variant.id !== Number(variantId) && kind !== 'refresh') {
      // Shopify rendered another variant than the one asked for (the combination no longer exists): say so, never pretend.
      Monetta.toast?.(`Esa combinación ya no está disponible. Mostramos ${describe(variant)}.`, { tone: 'error' });
    } else if (announceAvailability) {
      const text = $('[data-availability]', root)?.textContent?.trim();
      const price = $('[data-price] .price', root)?.textContent?.trim();
      if (text) Monetta.announce?.(`${price ? `${price}. ` : ''}${text}`);
    }
    Monetta.refreshPinnedChrome?.();
  }

  function failConfirmation(root, { kind, label }) {
    root.removeAttribute('aria-busy');
    setStatus(root, '');
    if (kind === 'refresh') {
      Monetta.toast?.('No pudimos actualizar la disponibilidad. Recarga la página para ver el estado real.', { tone: 'error' });
      return;
    }
    if (kind === 'resync') {
      // Shopify refused this variant and its replacement could not be fetched: the page has nothing valid to sell.
      root.dataset.selection = 'error';
      showError(root, 'No pudimos confirmar la disponibilidad de esta pieza. Recarga la página para continuar.');
      return;
    }
    // A failed choice: put the chips back on the variant the page really shows and say which one stayed.
    const kept = variantById(validatedId) || variantById(shownId(root));
    showChoice(root, kept);
    root.dataset.selection = 'valid';
    lockPurchase(root, false);
    showError(root, `No pudimos confirmar${label ? ` «${label}»` : ' esa opción'}. Se mantiene${kept ? ` «${describe(kept)}»` : ' la opción anterior'}; elígela otra vez para reintentar.`);
    Monetta.announce?.('No se pudo cambiar la opción.');
  }

  function choose(input) {
    const root = page();
    const position = Number(input.closest('fieldset').dataset.optionPosition);
    // The value beside the option name follows the chip at once, so the two never disagree.
    $$('[data-options] fieldset', root).forEach((group) => {
      const value = $('[data-option-value]', group);
      if (value) value.textContent = $('input:checked', group)?.value ?? '';
    });
    const variants = readVariants();
    const chosen = chosenValues(root);
    let variant = variants.find((candidate) => candidate.options.every((value, index) => value === chosen[index]));
    if (!variant) {
      // That exact combination does not exist: the nearest one that keeps the option just changed (available first).
      const keep = position - 1;
      const sameChanged = variants.filter((candidate) => candidate.options[keep] === chosen[keep]);
      variant = sameChanged.find((candidate) => candidate.available) || sameChanged[0] || null;
    }
    if (!variant) {
      failConfirmation(root, { kind: 'choice', label: chosen.join(' / ') });
      return;
    }
    showChoice(root, variant);
    if (variant.id === validatedId && root.dataset.selection !== 'error') {
      // Back on the variant the page already shows: nothing to confirm, and whatever was in flight must not apply.
      sequence += 1;
      controller?.abort();
      root.dataset.selection = 'valid';
      root.removeAttribute('aria-busy');
      lockPurchase(root, false);
      setStatus(root, '');
      hideError(root);
      return;
    }
    confirmVariant(variant.id);
  }

  document.addEventListener('change', (event) => {
    const input = event.target.closest?.('[data-option-input]');
    if (input) {
      choose(input);
      return;
    }
    const qty = event.target.closest?.('[data-qty-input]');
    if (qty) syncQuantity(qty.closest('[data-qty]'), Number(qty.value));
  });

  /* ------------------------------------------------------------ quantity */
  function syncQuantity(group, value) {
    const input = $('[data-qty-input]', group);
    const min = Number(input.min) || 1;
    const max = Number(input.max) || 99;
    const next = Math.max(min, Math.min(max, Number.isFinite(value) ? Math.round(value) : min));
    input.value = String(next);
    $('[data-step="-1"]', group).disabled = next <= min;
    $('[data-step="1"]', group).disabled = next >= max;
  }

  document.addEventListener('click', (event) => {
    const step = event.target.closest?.('[data-qty] [data-step]');
    if (step) {
      const group = step.closest('[data-qty]');
      syncQuantity(group, Number($('[data-qty-input]', group).value) + Number(step.dataset.step));
      return;
    }
    if (event.target.closest?.('[data-share]')) share();
  });

  async function share() {
    const root = page();
    const url = `${location.origin}${root.dataset.productUrl}${location.search}`;
    const title = $('.product-panel__name', root)?.textContent?.trim() || document.title;
    if (navigator.share) {
      try {
        await navigator.share({ title, url });
        return;
      } catch (error) {
        if (error.name === 'AbortError') return;
      }
    }
    try {
      await navigator.clipboard.writeText(url);
      Monetta.toast?.('Enlace de la pieza copiado.');
    } catch {
      Monetta.toast?.('No pudimos copiar el enlace en este navegador.', { tone: 'error' });
    }
  }

  /* ------------------------------------------------------------ add to bag */
  let adding = false;
  document.addEventListener('submit', async (event) => {
    const form = event.target.closest?.('[data-product-form]');
    if (!form) return;
    event.preventDefault();
    const root = page();
    const buttons = $$('[data-add]', root);
    // One request at a time, and only for a confirmed choice: further clicks and Enter presses are ignored until Shopify answers.
    if (adding || !purchasable() || buttons.some((button) => button.disabled)) return;
    adding = true;
    hideError(root);
    buttons.forEach((button) => Monetta.setPending(button, true));
    lockPurchase(root, true); // the accelerated checkout must not start while the add is in flight
    const variantId = shownId(root);
    const quantity = Number($('[data-qty-input]', form)?.value) || 1;
    const name = $('.product-panel__name', root)?.textContent?.trim() || '';
    const option = $$('[data-options] [data-option-value]', root).map((el) => el.textContent.trim()).filter(Boolean).join(' / ');
    const result = await Monetta.cart.add({ id: variantId, quantity, name: option ? `${name} (${option})` : name, trigger: $('[data-add]', form) });
    buttons.forEach((button) => Monetta.setPending(button, false));
    adding = false;
    if (root.dataset.selection === 'valid') lockPurchase(root, false);
    if (!result.ok) {
      const error = { text: result.message, lang: result.lang || '' };
      showError(root, error.text, error.lang);
      // Shopify refused the variant (it no longer exists): show what it renders for this product now. A connection failure or a 5xx
      // is NOT retried and not re-synced: whether the add happened is unknown, and the message says so.
      if (result.status === 422 && shownId(root) === variantId) confirmVariant(variantId, { kind: 'resync', announceAvailability: false, keepError: error });
    }
  });

  /* ------------------------------------------------------------ recommendations (lazy) */
  function loadRecommendations() {
    const holder = $('[data-recommendations][data-url]');
    if (!holder) return;
    const load = async () => {
      try {
        const response = await fetch(holder.dataset.url, { headers: { Accept: 'text/html' } });
        if (!response.ok) return;
        const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
        const next = $('[data-recommendations]', doc);
        if (next && next.children.length) holder.replaceChildren(...next.childNodes);
      } catch {
        /* the rail is a nicety; the page is complete without it */
      }
    };
    if ('IntersectionObserver' in window) {
      const observer = new IntersectionObserver(
        (entries) => {
          if (entries.some((entry) => entry.isIntersecting)) {
            observer.disconnect();
            load();
          }
        },
        { rootMargin: '600px 0px' },
      );
      observer.observe(holder);
    } else {
      load();
    }
  }

  /* ------------------------------------------------------------ never trust an old page */
  // Price and stock were true when this page was rendered. A page restored from the back/forward cache, or one that comes back to the
  // foreground after a while, asks Shopify again instead of showing them indefinitely.
  let hiddenAt = 0;
  const revalidate = () => {
    const root = page();
    const id = shownId(root);
    if (id && root.dataset.selection === 'valid') confirmVariant(id, { kind: 'refresh', announceAvailability: false });
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
    if (event.persisted) {
      reconcile();
      revalidate();
    }
  });

  /** The browser may restore radios from an older state; the rendered variant (hidden id) is the truth, so the chips follow it. */
  function reconcile() {
    const root = page();
    if (!root) return;
    const rendered = variantById(shownId(root));
    if (rendered && root.dataset.selection === 'valid' && !chosenValues(root).every((value, index) => value === rendered.options[index])) showChoice(root, rendered);
  }

  Monetta.product = { purchasable, confirmVariant };

  function start() {
    const root = page();
    if (root) {
      validatedId = shownId(root);
      root.dataset.selection = 'valid';
      reconcile();
    }
    initGallery();
    loadRecommendations();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
