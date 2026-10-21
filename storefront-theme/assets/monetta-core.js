/*
 * Monetta core: behaviour shared by every page of the redesigned templates. Plain script, no framework, no build step.
 * It is the multi-page counterpart of the prototype's SPA helpers (src/lib/chrome.js, scrollers.js, router.js) and keeps
 * their measured rules: pinned chrome is measured (never assumed), keyboard focus brings a scroller item fully into view,
 * and the in-page back arrow leaves the screen instead of stepping through filters.
 */
(() => {
  'use strict';

  const Monetta = (window.Monetta = window.Monetta || {});
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const reduceMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const isPhone = () => window.matchMedia('(max-width: 767.98px)').matches;
  Monetta.isPhone = isPhone;

  /* ---------------------------------------------------------------- live regions and toasts */
  function announce(message) {
    const region = $('#status-live');
    if (!region) return;
    region.textContent = '';
    window.setTimeout(() => {
      region.textContent = message;
    }, 30);
  }

  function toast(message, { tone = 'default', action = null, duration = 5000, lang = '' } = {}) {
    const root = $('#toast-root');
    if (!root) return;
    const element = document.createElement('div');
    element.className = `toast${tone === 'error' ? ' toast--error' : ''}`;
    element.setAttribute('role', tone === 'error' ? 'alert' : 'status');
    const text = document.createElement('span');
    text.className = 'toast__text';
    text.textContent = message;
    // Text Shopify wrote in the store's own language (stock limits, rejections) when that is not the page's.
    if (lang) text.lang = lang;
    element.append(text);
    if (action) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'toast__action';
      button.textContent = action.label;
      button.addEventListener('click', () => {
        action.onClick();
        dismiss();
      });
      element.append(button);
    }
    root.replaceChildren(element);
    requestAnimationFrame(() => element.classList.add('is-visible'));
    const dismiss = () => {
      element.classList.remove('is-visible');
      window.setTimeout(() => element.remove(), 200);
    };
    window.setTimeout(dismiss, duration);
  }
  Monetta.announce = announce;
  Monetta.toast = toast;

  /* ---------------------------------------------------------------- dialogs (menu drawer, filters, bag sheet) */
  const openDialogs = [];
  let opener = null;

  function openDialog(dialog, trigger) {
    if (!dialog || dialog.open) return;
    opener = trigger || document.activeElement;
    // Locking the page scroll removes the scrollbar; the ported html.is-locked rule pads by --scrollbar-comp so nothing shifts.
    document.documentElement.style.setProperty('--scrollbar-comp', `${Math.max(0, window.innerWidth - document.documentElement.clientWidth)}px`);
    dialog.showModal();
    document.documentElement.classList.add('is-locked');
    // Two frames: the panel must paint at its start position before the transition to .is-open.
    requestAnimationFrame(() => requestAnimationFrame(() => dialog.classList.add('is-open')));
    openDialogs.push(dialog);
    const focusTarget = $('[data-autofocus]', dialog) || $('.overlay__panel button, .overlay__panel a, .overlay__panel input', dialog);
    focusTarget?.focus({ preventScroll: true });
    dialog.dispatchEvent(new CustomEvent('monetta:dialog-open', { bubbles: true }));
  }

  function closeDialog(dialog, { restoreFocus = true } = {}) {
    if (!dialog?.open) return;
    dialog.classList.remove('is-open');
    const finish = () => {
      if (dialog.open) dialog.close();
      const index = openDialogs.indexOf(dialog);
      if (index >= 0) openDialogs.splice(index, 1);
      if (!openDialogs.length) document.documentElement.classList.remove('is-locked');
      if (restoreFocus && opener && document.contains(opener)) opener.focus({ preventScroll: true });
      dialog.dispatchEvent(new CustomEvent('monetta:dialog-close', { bubbles: true }));
    };
    if (reduceMotion()) finish();
    else window.setTimeout(finish, 280);
  }
  Monetta.openDialog = openDialog;
  Monetta.closeDialog = closeDialog;

  document.addEventListener('click', (event) => {
    const trigger = event.target.closest('[data-open-dialog]');
    if (trigger) {
      event.preventDefault();
      openDialog(document.getElementById(trigger.dataset.openDialog), trigger);
      return;
    }
    const closer = event.target.closest('[data-overlay-close]');
    if (closer) {
      closeDialog(closer.closest('dialog'));
    }
  });

  // Esc closes through the same path so the transition and focus restore run.
  document.addEventListener('cancel', (event) => {
    if (event.target instanceof HTMLDialogElement && event.target.classList.contains('overlay')) {
      event.preventDefault();
      closeDialog(event.target);
    }
  }, true);

  /* ---------------------------------------------------------------- pinned chrome (port of src/lib/chrome.js) */
  const TOP_SELECTOR = '#site-top, [data-page-bar]';
  const BOTTOM_SELECTOR = '.dock, .purchase-dock, .checkout-bar';

  function pinnedReserve(items) {
    let reserve = 0;
    for (const { display, position, offset, size } of items) {
      if (display === 'none') continue;
      if (position !== 'sticky' && position !== 'fixed') continue;
      if (!Number.isFinite(offset)) continue;
      reserve = Math.max(reserve, offset + size);
    }
    return Math.round(reserve * 100) / 100;
  }
  Monetta.pinnedReserve = pinnedReserve;

  function describe(element, edge) {
    const style = getComputedStyle(element);
    return {
      display: style.display,
      position: style.position,
      offset: Number.parseFloat(style[edge]),
      // Layout height: a transform (the dock slides away while typing) must not shrink the reserve.
      size: element.getBoundingClientRect().height,
    };
  }

  const published = {};
  function publish(name, pixels) {
    if (published[name] === pixels) return;
    published[name] = pixels;
    document.documentElement.style.setProperty(name, `${pixels}px`);
  }

  function measurePinnedChrome() {
    publish('--pinned-top', pinnedReserve($$(TOP_SELECTOR).map((element) => describe(element, 'top'))));
    publish('--pinned-bottom', pinnedReserve($$(BOTTOM_SELECTOR).map((element) => describe(element, 'bottom'))));
  }
  Monetta.measurePinnedChrome = measurePinnedChrome;

  let resizeObserver = null;
  const observed = new Set();
  function refreshPinnedChrome() {
    if (!resizeObserver) return;
    const current = new Set($$(`${TOP_SELECTOR}, ${BOTTOM_SELECTOR}`));
    for (const element of observed) {
      if (!current.has(element)) {
        resizeObserver.unobserve(element);
        observed.delete(element);
      }
    }
    for (const element of current) {
      if (!observed.has(element)) {
        // The border box: the dock grows with the home indicator through its padding.
        resizeObserver.observe(element, { box: 'border-box' });
        observed.add(element);
      }
    }
    measurePinnedChrome();
  }
  Monetta.refreshPinnedChrome = refreshPinnedChrome;

  function watchPinnedChrome() {
    if (typeof ResizeObserver === 'undefined') {
      measurePinnedChrome();
      return;
    }
    resizeObserver = new ResizeObserver(measurePinnedChrome);
    window.addEventListener('resize', measurePinnedChrome);
    window.addEventListener('orientationchange', measurePinnedChrome);
    new MutationObserver(measurePinnedChrome).observe(document.body, { attributes: true, attributeFilter: ['class'] });
    document.fonts?.addEventListener?.('loadingdone', measurePinnedChrome);
    document.fonts?.ready?.then(measurePinnedChrome);
    // The theme editor and Section Rendering replace the header group's markup.
    document.addEventListener('shopify:section:load', refreshPinnedChrome);
    refreshPinnedChrome();
  }

  /* ---------------------------------------------------------------- keyboard focus in horizontal scrollers (port of scrollers.js) */
  function scrollerTarget({ itemStart, itemEnd, scrollLeft, viewWidth, padStart, padEnd, maxScroll, snap = false }) {
    const visibleStart = scrollLeft + padStart;
    const visibleEnd = scrollLeft + viewWidth - padEnd;
    if (itemStart >= visibleStart - 0.5 && itemEnd <= visibleEnd + 0.5) return null;
    const clamp = (value) => Math.min(Math.max(value, 0), Math.max(maxScroll, 0));
    if (snap || itemEnd - itemStart > visibleEnd - visibleStart) return clamp(itemStart - padStart);
    return clamp(itemStart < visibleStart ? itemStart - padStart : itemEnd + padEnd - viewWidth);
  }
  Monetta.scrollerTarget = scrollerTarget;

  function horizontalScroller(element) {
    for (let node = element.parentElement; node && node !== document.body; node = node.parentElement) {
      const { overflowX } = getComputedStyle(node);
      if ((overflowX === 'auto' || overflowX === 'scroll') && node.scrollWidth > node.clientWidth + 1) return node;
    }
    return null;
  }

  function paddingPx(value, basis) {
    const number = Number.parseFloat(value);
    if (Number.isNaN(number)) return 0;
    return value.endsWith('%') ? (basis * number) / 100 : number;
  }

  function revealFocusedScrollerItem(event) {
    const target = event.target;
    if (!(target instanceof Element) || !target.matches(':focus-visible')) return;
    const scroller = horizontalScroller(target);
    if (!scroller) return;
    let item = target;
    while (item.parentElement !== scroller) item = item.parentElement;
    const box = scroller.getBoundingClientRect();
    const rect = item.getBoundingClientRect();
    const style = getComputedStyle(scroller);
    const origin = box.left + scroller.clientLeft - scroller.scrollLeft;
    const next = scrollerTarget({
      itemStart: rect.left - origin,
      itemEnd: rect.right - origin,
      scrollLeft: scroller.scrollLeft,
      viewWidth: scroller.clientWidth,
      padStart: paddingPx(style.scrollPaddingLeft, scroller.clientWidth),
      padEnd: paddingPx(style.scrollPaddingRight, scroller.clientWidth),
      maxScroll: scroller.scrollWidth - scroller.clientWidth,
      snap: style.scrollSnapType !== 'none',
    });
    if (next !== null) scroller.scrollTo({ left: next, behavior: 'auto' });
  }
  document.addEventListener('focusin', revealFocusedScrollerItem);

  /* ---------------------------------------------------------------- a tall control keeps its centre in view */
  // A card or the gallery can be taller than the band the pinned chrome leaves (a 200px-high window, a phone on its side): the browser
  // aligns one edge and the control's centre can stay off screen. After the browser's own scroll, keyboard focus moves the page so that
  // the control's centre is in the middle of the visible band (or, if it fits, brings it inside the band).
  function keepFocusedCentreInView(event) {
    const element = event.target;
    if (!(element instanceof Element) || !element.matches(':focus-visible')) return;
    // Controls in a dialog or in the pinned bars themselves scroll with their container, not with the page.
    if (element.closest('dialog, #site-top, [data-page-bar], .dock, .purchase-dock, .checkout-bar')) return;
    requestAnimationFrame(() => {
      const rect = element.getBoundingClientRect();
      const root = getComputedStyle(document.documentElement);
      const top = Number.parseFloat(root.getPropertyValue('--pinned-top')) || 0;
      const bottom = window.innerHeight - (Number.parseFloat(root.getPropertyValue('--pinned-bottom')) || 0);
      const centre = rect.top + rect.height / 2;
      if (centre >= top && centre <= bottom) return;
      const fits = rect.height <= bottom - top;
      const delta = fits ? (rect.top < top ? rect.top - top : rect.bottom - bottom) : centre - (top + bottom) / 2;
      window.scrollBy({ top: delta, behavior: 'auto' });
    });
  }
  document.addEventListener('focusin', keepFocusedCentreInView);

  /* ---------------------------------------------------------------- rails: previous / next */
  document.addEventListener('click', (event) => {
    const button = event.target.closest('[data-rail-prev], [data-rail-next]');
    if (!button) return;
    const rail = document.getElementById(button.dataset.railPrev || button.dataset.railNext);
    if (!rail) return;
    const direction = button.hasAttribute('data-rail-next') ? 1 : -1;
    const first = rail.firstElementChild;
    const step = first ? first.getBoundingClientRect().width + 16 : rail.clientWidth * 0.8;
    rail.scrollBy({ left: direction * step * 2, behavior: reduceMotion() ? 'auto' : 'smooth' });
  });

  /* ---------------------------------------------------------------- header: scrolled hairline, typing state, search clear */
  function watchScroll() {
    const top = $('#site-top');
    if (!top) return;
    const update = () => top.classList.toggle('is-scrolled', window.scrollY > 0);
    window.addEventListener('scroll', update, { passive: true });
    update();
  }

  // While a text field has focus on a phone the dock slides away so the keyboard and the dock never compete.
  function watchTyping() {
    const textual = (element) => element instanceof HTMLInputElement && /^(text|search|email|tel|url|number|password)$/.test(element.type);
    document.addEventListener('focusin', (event) => {
      if (isPhone() && textual(event.target)) document.body.classList.add('is-typing');
    });
    document.addEventListener('focusout', () => {
      window.setTimeout(() => {
        if (!textual(document.activeElement)) document.body.classList.remove('is-typing');
      }, 0);
    });
  }

  function watchSearchClear() {
    for (const field of $$('.search-field')) {
      const input = $('input[type="search"]', field);
      const clear = $('[data-search-clear]', field);
      if (!input || !clear) continue;
      const sync = () => {
        clear.hidden = input.value === '';
      };
      input.addEventListener('input', sync);
      clear.addEventListener('click', () => {
        input.value = '';
        sync();
        input.focus();
      });
      sync();
    }
  }

  /* ---------------------------------------------------------------- screen-level back arrow for a multi-page site */
  // history.state keeps idx (entries of this visit) and entry (the idx where the current screen began). Filters, sort and
  // pagination are document navigations on the same screen (same path), so the browser's Back steps through them one by
  // one while the arrow skips them. A screen's identity is its path.
  const NAV_KEY = 'monetta:nav';
  let navigationEpoch = 0;
  const LEAVE_FALLBACK_MS = 500;

  function readSession() {
    try {
      return JSON.parse(sessionStorage.getItem(NAV_KEY) || 'null');
    } catch {
      return null;
    }
  }
  function writeSession(value) {
    try {
      sessionStorage.setItem(NAV_KEY, JSON.stringify(value));
    } catch {
      /* storage can be blocked; the arrow then always goes to the parent */
    }
  }

  function initNavigationState() {
    const screen = location.pathname;
    let state = history.state;
    if (!(state && typeof state.idx === 'number')) {
      const previous = readSession();
      const cameFromSite = Boolean(document.referrer) && new URL(document.referrer).origin === location.origin;
      let idx = 0;
      let entry = 0;
      if (previous && cameFromSite) {
        idx = previous.idx + 1;
        entry = previous.screen === screen ? previous.entry : idx;
      }
      state = { ...(history.state || {}), idx, entry };
      history.replaceState(state, '', location.href);
    }
    writeSession({ idx: state.idx, entry: state.entry, screen });
  }

  function screenBackSteps(state) {
    const idx = state?.idx ?? 0;
    const entry = state?.entry ?? 0;
    return entry > 0 ? idx - entry + 1 : 0;
  }
  Monetta.screenBackSteps = screenBackSteps;

  /** The fallback belongs to this one click: any navigation after it bumps the epoch and it lapses. */
  function leaveScreen(parent) {
    const steps = screenBackSteps(history.state);
    if (steps <= 0) {
      location.assign(parent);
      return;
    }
    const epoch = navigationEpoch;
    history.go(-steps);
    window.setTimeout(() => {
      if (navigationEpoch === epoch) location.assign(parent);
    }, LEAVE_FALLBACK_MS);
  }
  Monetta.leaveScreen = leaveScreen;
  /** Call after changing the address in place (replaceState) so a pending fallback cannot act on the new state. */
  Monetta.noteNavigation = () => {
    navigationEpoch += 1;
  };

  window.addEventListener('popstate', () => {
    navigationEpoch += 1;
  });
  window.addEventListener('pageshow', (event) => {
    if (event.persisted) navigationEpoch += 1;
  });

  document.addEventListener('click', (event) => {
    const back = event.target.closest('[data-action="back"]');
    if (!back || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    leaveScreen(back.dataset.backParent || back.getAttribute('href') || '/');
  });

  /* ---------------------------------------------------------------- start */
  function start() {
    initNavigationState();
    watchPinnedChrome();
    watchScroll();
    watchTyping();
    watchSearchClear();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
