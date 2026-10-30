/*
 * Monetta product page. The server renders the page; this file only moves things without a reload:
 *  - the gallery (snap scrolling, thumbnails, arrow keys),
 *  - option changes: the browser works out which variant the shopper chose, then asks Shopify for this same section with
 *    ?variant=ID (Section Rendering API) and swaps the price / availability / buttons it returns, so nothing commercial is
 *    cached or recomputed here,
 *  - the quantity stepper and the add button's states (waiting, success, error, no double sends),
 *  - the lazily requested recommendations rail.
 * The add request carries the exact variant id; it is never substituted.
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
  function readVariants() {
    try {
      return JSON.parse($('[data-product-variants]', page())?.textContent || '[]');
    } catch {
      return [];
    }
  }

  /** The variant the current radio selection names; when that exact combination does not exist, the closest one. */
  function pickVariant(changedPosition) {
    const variants = readVariants();
    const groups = $$('[data-options] fieldset');
    const chosen = groups.map((group) => $('input:checked', group)?.value);
    const exact = variants.find((variant) => variant.options.every((value, index) => value === chosen[index]));
    if (exact) return exact;
    const keep = changedPosition - 1;
    const sameChanged = variants.filter((variant) => variant.options[keep] === chosen[keep]);
    return sameChanged.find((variant) => variant.available) || sameChanged[0] || null;
  }

  let swapController = null;
  async function swapVariant(variantId, { announceAvailability = true } = {}) {
    const root = page();
    if (!root) return;
    swapController?.abort();
    swapController = new AbortController();
    const { signal } = swapController;
    const focused = document.activeElement;
    const focusedValue = focused?.matches?.('[data-option-input]') ? { position: focused.closest('fieldset').dataset.optionPosition, value: focused.value } : null;
    root.setAttribute('aria-busy', 'true');
    try {
      const url = `${root.dataset.productUrl}?variant=${variantId}&section_id=${encodeURIComponent(root.dataset.sectionId)}`;
      const response = await fetch(url, { signal, headers: { Accept: 'text/html' } });
      if (!response.ok) throw new Error(String(response.status));
      const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
      const next = $('[data-product-page]', doc);
      if (!next || signal.aborted) return;
      $('[data-product-dynamic]', root).replaceChildren(...$('[data-product-dynamic]', next).childNodes);
      $('[data-purchase-dock]', root).replaceChildren(...$('[data-purchase-dock]', next).childNodes);
      const seal = $('[data-seal]', root);
      const nextSeal = $('[data-seal]', next);
      if (seal && nextSeal) seal.hidden = nextSeal.hidden;
      // The address names the variant Shopify actually rendered (an unknown id falls back to the default variant); a
      // pending "back" fallback must not act on it.
      const shown = $('[data-variant-id]', root)?.value || variantId;
      history.replaceState(history.state, '', `${root.dataset.productUrl}?variant=${shown}`);
      Monetta.noteNavigation?.();
      const index = Number(next.dataset.selectedIndex) || 0;
      Monetta.gallery?.goTo(index);
      if (focusedValue) {
        $(`fieldset[data-option-position="${focusedValue.position}"] input[value="${CSS.escape(focusedValue.value)}"]`, root)?.focus({ preventScroll: true });
      }
      if (announceAvailability) {
        const text = $('[data-availability]', root)?.textContent?.trim();
        const price = $('[data-price] .price', root)?.textContent?.trim();
        if (text) Monetta.announce?.(`${price ? `${price}. ` : ''}${text}`);
      }
      Monetta.refreshPinnedChrome?.();
    } catch (error) {
      if (error.name === 'AbortError') return;
      Monetta.toast?.('No pudimos actualizar la disponibilidad. Recarga la página para ver el estado real.', { tone: 'error' });
    } finally {
      if (!signal.aborted) root.removeAttribute('aria-busy');
    }
  }

  document.addEventListener('change', (event) => {
    const input = event.target.closest?.('[data-option-input]');
    if (input) {
      const variant = pickVariant(Number(input.closest('fieldset').dataset.optionPosition));
      if (variant) swapVariant(variant.id);
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
    // One request at a time: further clicks and Enter presses are ignored until Shopify answers.
    if (adding || buttons.some((button) => button.disabled)) return;
    adding = true;
    const errorBox = $('[data-add-error]', root);
    if (errorBox) errorBox.hidden = true;
    buttons.forEach((button) => Monetta.setPending(button, true));
    const variantId = Number(form.elements.id.value);
    const quantity = Number($('[data-qty-input]', form)?.value) || 1;
    const name = $('.product-panel__name', root)?.textContent?.trim() || '';
    const option = $$('[data-options] [data-option-value]', root).map((el) => el.textContent.trim()).filter(Boolean).join(' / ');
    const result = await Monetta.cart.add({ id: variantId, quantity, name: option ? `${name} (${option})` : name, trigger: $('[data-add]', form) });
    buttons.forEach((button) => Monetta.setPending(button, false));
    adding = false;
    if (!result.ok && errorBox) {
      $('[data-error-text]', errorBox).textContent = result.message;
      errorBox.hidden = false;
      // The store refused (sold out meanwhile, stock ceiling): show what Shopify says about this variant now.
      if (result.status === 422 || result.status === 0) swapVariant(variantId, { announceAvailability: false });
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
    const id = Number($('[data-variant-id]', page())?.value);
    if (id) swapVariant(id, { announceAvailability: false });
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

  function start() {
    initGallery();
    loadRecommendations();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
