/*
 * Shopify section-response predictive search. No Atelier imports or global Monetta
 * handlers. Normal form submission and all destination links stay browser-native.
 */
(() => {
  'use strict';
  const tag = 'monetta-predictive-search';
  if (!window.customElements || customElements.get(tag) || !window.fetch || !window.AbortController) return;

  const memory = new Map();
  let serial = 0;
  const clean = (value) => typeof value === 'string' ? value.trim().replace(/\s+/g, ' ').slice(0, 200) : '';
  const bounded = (value, fallback, max) => {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? Math.max(0, Math.min(max, parsed)) : fallback;
  };
  const uniqueTerms = (terms) => {
    const seen = new Set();
    return terms.map(clean).filter((term) => {
      const key = term.toLocaleLowerCase();
      if (!term || seen.has(key)) return false;
      seen.add(key);
      return true;
    }).slice(0, 10);
  };
  function recentTerms(key) {
    if (!memory.has(key)) {
      let terms = [];
      try {
        const stored = JSON.parse(window.localStorage.getItem(key) || '[]');
        if (Array.isArray(stored)) terms = uniqueTerms(stored);
      } catch { /* Disabled storage, invalid JSON, or a security policy: use memory. */ }
      memory.set(key, terms);
    }
    return memory.get(key);
  }
  function storeTerms(key, terms) {
    memory.set(key, uniqueTerms(terms));
    try { window.localStorage.setItem(key, JSON.stringify(memory.get(key))); }
    catch { /* Keep usable history for this document when persistence is blocked. */ }
  }

  class MonettaPredictiveSearch extends HTMLElement {
    connectedCallback() {
      if (this.events) return;
      const find = (part) => this.querySelector('[data-monetta-predictive-' + part + ']');
      this.form = find('form');
      this.input = find('input');
      this.panel = find('panel');
      this.list = find('list');
      this.clearButton = find('clear');
      this.heading = find('heading');
      this.recentHeading = find('recent-heading');
      this.message = find('message');
      this.all = find('all');
      this.forget = find('forget');
      this.live = find('live');
      this.anchor = find('anchor');
      this.help = find('help');
      if (![this.form, this.input, this.panel, this.list, this.clearButton, this.heading,
        this.recentHeading, this.message, this.all, this.forget, this.live, this.anchor, this.help].every(Boolean)) return;

      this.uid = 'monetta-predictive-' + (++serial);
      this.list.id = this.uid + '-listbox';
      this.help.id = this.uid + '-help';
      this.input.setAttribute('role', 'combobox');
      this.input.setAttribute('aria-autocomplete', 'list');
      this.input.setAttribute('aria-haspopup', 'listbox');
      this.input.setAttribute('aria-controls', this.list.id);
      this.input.setAttribute('aria-describedby', this.help.id);
      this.input.setAttribute('aria-expanded', 'false');
      this.recentLimit = bounded(this.dataset.recentLimit, 5, 10);
      this.limit = Math.max(1, bounded(this.dataset.limit, 6, 10));
      this.historyKey = 'monetta:predictive:recent:v1:' + this.form.action + ':' + this.dataset.historyScope;
      // Keep generations monotonic across detach/reconnect; an old body read can
      // settle after reconnection even if its fetch was already aborted.
      this.epoch = this.epoch || 0;
      this.composing = false;
      this.options = [];
      this.active = -1;
      this.events = new AbortController();
      const on = (element, event, handler, options = {}) => {
        element.addEventListener(event, handler, { ...options, signal: this.events.signal });
      };

      on(this.input, 'input', (event) => {
        if (!event.isComposing && !this.composing) this.schedule();
      });
      on(this.input, 'focus', () => { if (!this.restoringFocus) this.schedule(); });
      on(this.input, 'compositionstart', () => { this.composing = true; this.close(); });
      on(this.input, 'compositionend', () => { this.composing = false; this.schedule(); });
      on(this, 'keydown', (event) => this.onKey(event));
      on(this, 'click', (event) => this.onClick(event));
      on(this.form, 'submit', () => { this.remember(); this.close(); });
      on(this.form, 'reset', () => window.setTimeout(() => { if (this.isConnected) this.schedule(); }, 0));
      on(document, 'pointerdown', (event) => {
        if (!this.contains(event.target)) this.close();
      });
      on(document, 'focusin', (event) => {
        if (!this.contains(event.target)) this.close();
      });
      on(window, 'storage', (event) => {
        if (event.key !== null && event.key !== this.historyKey) return;
        memory.delete(this.historyKey);
        if (document.activeElement === this.input && !this.query) this.showRecent();
      });
      on(window, 'resize', () => this.queuePosition(), { passive: true });
      on(document, 'scroll', () => this.queuePosition(), { passive: true, capture: true });
      if (window.visualViewport) {
        on(window.visualViewport, 'resize', () => this.queuePosition(), { passive: true });
        on(window.visualViewport, 'scroll', () => this.queuePosition(), { passive: true });
      }
      const dialog = this.closest('dialog');
      if (dialog) {
        on(dialog, 'monetta:dialog-close', () => this.close());
        on(dialog, 'close', () => this.close());
      }
      if (window.ResizeObserver) {
        this.observer = new ResizeObserver(() => this.queuePosition());
        this.observer.observe(this.anchor);
      }
      this.syncClear();
      // monetta-listing.js may have focused the server-rendered input before this module loaded.
      if (document.activeElement === this.input) this.schedule();
    }

    disconnectedCallback() {
      this.close();
      this.events?.abort();
      this.events = null;
      this.observer?.disconnect();
      cancelAnimationFrame(this.frame);
      this.frame = null;
    }

    get query() { return this.input.value.trim(); }

    invalidate() {
      this.epoch = (this.epoch || 0) + 1;
      clearTimeout(this.timer);
      clearTimeout(this.timeout);
      this.request?.abort();
      this.request = null;
    }

    syncClear() { this.clearButton.hidden = this.input.value.length === 0; }

    schedule() {
      this.invalidate(); // Invalidate immediately, including during the debounce interval.
      this.syncClear();
      this.select(-1);
      if (!this.query) { this.showRecent(); return; }
      const term = this.query;
      const epoch = this.epoch;
      this.setView('loading', this.dataset.loadingMessage);
      this.list.setAttribute('aria-busy', 'true');
      this.timer = window.setTimeout(() => this.search(term, epoch), 220);
    }

    current(epoch, term) {
      return this.isConnected && this.epoch === epoch && this.query === term;
    }

    async search(term, epoch) {
      if (!this.current(epoch, term)) return;
      const controller = new AbortController();
      this.request = controller;
      // A stalled endpoint still leaves the native search available.
      this.timeout = window.setTimeout(() => {
        if (!this.current(epoch, term)) return;
        this.invalidate();
        this.setView('error', this.dataset.errorMessage);
      }, 8000);
      try {
        const url = new URL(this.dataset.predictiveUrl, location.origin);
        if (url.origin !== location.origin) throw new Error('Predictive endpoint must be same-origin');
        url.searchParams.set('q', term);
        url.searchParams.set('resources[type]', 'product');
        url.searchParams.set('resources[limit]', String(this.limit));
        url.searchParams.set('resources[limit_scope]', 'each');
        url.searchParams.set('resources[options][unavailable_products]', 'last');
        url.searchParams.set('section_id', 'monetta-predictive-results');
        const response = await fetch(url, {
          signal: controller.signal,
          credentials: 'same-origin',
          headers: { Accept: 'text/html' },
        });
        if (!response.ok) throw new Error('Predictive response ' + response.status);
        const markup = await response.text();
        if (!this.current(epoch, term)) return;
        const parsed = new DOMParser().parseFromString(markup, 'text/html');
        const result = parsed.querySelector('[data-monetta-predictive-response]');
        const products = result?.querySelector('[data-monetta-predictive-products]');
        const count = Number(result?.dataset.count);
        const links = products?.querySelectorAll('[data-monetta-predictive-option]');
        if (!products || !Number.isInteger(count) || count < 0 || count > this.limit || links.length !== count) {
          throw new Error('Invalid predictive section');
        }
        // The fragment is rendered by our Liquid section on this store. Never inject
        // a full response (password page, error document, or an unrelated section).
        const nodes = [...products.children].map((node) => document.importNode(node, true));
        this.setView(count ? 'results' : 'empty', count ? '' : this.dataset.emptyMessage, nodes);
        if (count) this.announce(this.dataset.countMessage.replace('{count}', String(count)));
      } catch (error) {
        if (this.current(epoch, term) && !controller.signal.aborted) this.setView('error', this.dataset.errorMessage);
      } finally {
        if (this.current(epoch, term)) {
          clearTimeout(this.timeout);
          this.request = null;
          this.list.setAttribute('aria-busy', 'false');
        }
      }
    }

    setView(state, message = '', nodes = []) {
      this.dataset.state = state;
      this.list.replaceChildren(...nodes);
      this.options = [...this.list.querySelectorAll('[data-monetta-predictive-option]')];
      this.options.forEach((option, index) => {
        option.id = this.uid + '-option-' + index;
        option.setAttribute('aria-selected', 'false');
      });
      this.select(-1);
      this.list.setAttribute('aria-busy', 'false');
      this.list.hidden = this.options.length === 0;
      this.message.textContent = message;
      this.message.hidden = !message;
      const recent = state === 'recent';
      this.heading.hidden = recent;
      this.recentHeading.hidden = !recent;
      this.forget.hidden = !recent;
      this.all.hidden = !this.query;
      if (this.query) this.all.href = this.searchURL(this.query);
      this.panel.hidden = false;
      this.panel.scrollTop = 0;
      this.input.setAttribute('aria-expanded', 'true');
      if (message) this.announce(message);
      this.position();
    }

    announce(message) {
      if (this.live.textContent !== message) this.live.textContent = message;
    }

    searchURL(term) {
      const url = new URL(this.form.action);
      for (const [key, value] of new FormData(this.form)) url.searchParams.set(key, value);
      url.searchParams.set('q', term);
      return url.href;
    }

    showRecent() {
      const terms = this.recentLimit ? recentTerms(this.historyKey).slice(0, this.recentLimit) : [];
      if (!terms.length) { this.close(); return; }
      const nodes = terms.map((term) => {
        const item = document.createElement('li');
        item.setAttribute('role', 'presentation');
        const link = document.createElement('a');
        link.className = 'monetta-predictive-search__option monetta-predictive-search__option--recent';
        link.setAttribute('role', 'option');
        link.tabIndex = -1;
        link.href = this.searchURL(term);
        link.textContent = term;
        link.dataset.monettaPredictiveOption = '';
        link.dataset.monettaPredictiveTerm = term;
        item.append(link);
        return item;
      });
      this.setView('recent', '', nodes);
      this.announce(this.dataset.recentCountMessage.replace('{count}', String(terms.length)));
    }

    remember(term = this.query) {
      if (!this.recentLimit || !clean(term)) return;
      storeTerms(this.historyKey, [term, ...recentTerms(this.historyKey)].slice(0, 11));
    }

    close(restoreFocus = false) {
      this.invalidate();
      if (!this.panel || !this.input || !this.list) return;
      this.panel.hidden = true;
      this.dataset.state = 'closed';
      this.input.setAttribute('aria-expanded', 'false');
      this.list.setAttribute('aria-busy', 'false');
      this.select(-1);
      this.live.textContent = '';
      if (restoreFocus) {
        // Focusing the input must not reopen the just-dismissed suggestions.
        this.restoringFocus = true;
        this.input.focus({ preventScroll: true });
        this.restoringFocus = false;
      }
    }

    select(index) {
      this.active = index;
      this.options?.forEach((option, position) => {
        option.setAttribute('aria-selected', String(position === index));
      });
      const option = this.options?.[index];
      if (!option) { this.input?.removeAttribute('aria-activedescendant'); return; }
      this.input.setAttribute('aria-activedescendant', option.id);
      // Scroll this panel only; scrollIntoView can move the shared pinned shell.
      const outer = this.panel.getBoundingClientRect();
      const inner = option.getBoundingClientRect();
      if (inner.top < outer.top + 4) this.panel.scrollTop -= outer.top + 4 - inner.top;
      else if (inner.bottom > outer.bottom - 4) this.panel.scrollTop += inner.bottom - outer.bottom + 4;
    }

    onKey(event) {
      if (event.isComposing || this.composing || event.defaultPrevented) return;
      if (event.key === 'Escape') {
        if (!this.panel.hidden) {
          event.preventDefault();
          event.stopPropagation();
          this.close(true);
        } else {
          // A search input can consume native Escape before a dialog's cancel event.
          // Request the standard cancellation so monetta-core keeps its transition,
          // scroll lock and focus restoration, with exactly one cancel event.
          const dialog = this.closest('dialog[open]');
          if (dialog) {
            event.preventDefault();
            event.stopPropagation();
            if (typeof dialog.requestClose === 'function') dialog.requestClose();
            else if (dialog.dispatchEvent(new Event('cancel', { cancelable: true }))) dialog.close();
          }
        }
        return;
      }
      if (event.target !== this.input || event.altKey || event.ctrlKey || event.metaKey) return;
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        if (this.panel.hidden) { this.schedule(); return; }
        if (!this.options.length) return;
        event.preventDefault();
        const step = event.key === 'ArrowDown' ? 1 : -1;
        const next = this.active < 0 ? (step > 0 ? 0 : this.options.length - 1)
          : (this.active + step + this.options.length) % this.options.length;
        this.select(next);
      } else if (event.key === 'Enter' && !this.panel.hidden && this.active >= 0) {
        event.preventDefault();
        this.options[this.active].click();
      } else if (event.key === 'Tab') {
        this.select(-1); // Preserve the browser's Tab order; never trap focus.
      }
    }

    onClick(event) {
      const target = event.target.closest('button, a');
      if (!target || !this.contains(target)) return;
      if (target.hasAttribute('data-monetta-predictive-clear')) {
        this.input.value = '';
        this.input.focus({ preventScroll: true });
        this.input.dispatchEvent(new Event('input', { bubbles: true }));
      } else if (target.hasAttribute('data-monetta-predictive-close')) {
        this.close(true);
      } else if (target.hasAttribute('data-monetta-predictive-forget')) {
        storeTerms(this.historyKey, []);
        this.close(true);
        this.announce(this.dataset.forgottenMessage);
      } else if (target.hasAttribute('data-monetta-predictive-option') || target === this.all) {
        this.remember(target.dataset.monettaPredictiveTerm || this.query);
        // Let native links handle Enter, modifiers, open in new tab, and destinations.
      }
    }

    queuePosition() {
      if (!this.panel || this.panel.hidden || this.frame) return;
      this.frame = requestAnimationFrame(() => { this.frame = null; this.position(); });
    }

    position() {
      if (this.panel.hidden) return;
      const rect = this.anchor.getBoundingClientRect();
      if (!this.anchor.getClientRects().length || rect.width === 0) { this.close(); return; }
      const viewport = window.visualViewport;
      const left = viewport?.offsetLeft || 0;
      const top = viewport?.offsetTop || 0;
      const width = viewport?.width || document.documentElement.clientWidth;
      const height = viewport?.height || window.innerHeight;
      if (rect.bottom < top || rect.top > top + height) { this.close(); return; }
      const style = getComputedStyle(this);
      const margin = Number.parseFloat(style.getPropertyValue('--space-3')) || 12;
      const gap = Number.parseFloat(style.getPropertyValue('--space-2')) || 8;
      const marginLeft = Math.max(margin, Number.parseFloat(style.getPropertyValue('--safe-left')) || 0);
      const marginRight = Math.max(margin, Number.parseFloat(style.getPropertyValue('--safe-right')) || 0);
      const marginBottom = Math.max(margin, Number.parseFloat(style.getPropertyValue('--safe-bottom')) || 0);
      const availableWidth = Math.max(0, width - marginLeft - marginRight);
      const panelWidth = width < 768 ? availableWidth : Math.min(availableWidth, Math.max(rect.width, 360), 560);
      const start = style.direction === 'rtl' ? rect.right - panelWidth : rect.left;
      const panelLeft = width < 768 ? left + marginLeft
        : Math.max(left + marginLeft, Math.min(start, left + width - marginRight - panelWidth));
      const below = Math.max(0, top + height - marginBottom - rect.bottom - gap);
      const above = Math.max(0, rect.top - top - margin - gap);
      const useBelow = below >= Math.min(240, height * 0.4) || below >= above;
      this.panel.style.left = panelLeft + 'px';
      this.panel.style.width = panelWidth + 'px';
      this.panel.style.maxHeight = (useBelow ? below : above) + 'px';
      this.panel.style.top = useBelow ? Math.max(top + margin, rect.bottom + gap) + 'px' : 'auto';
      this.panel.style.bottom = useBelow ? 'auto' : Math.max(0, window.innerHeight - rect.top + gap) + 'px';
    }
  }
  customElements.define(tag, MonettaPredictiveSearch);
})();
