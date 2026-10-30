/* Native search forms enhanced with Shopify's rendered predictive section. */
(() => {
  'use strict';
  const tag = 'monetta-predictive-search';
  if (!window.customElements || customElements.get(tag) || !window.fetch || !window.AbortController) return;
  const cacheKey = 'monetta:predictive:responses:v1';
  const cache = new Map();
  try {
    const stored = JSON.parse(sessionStorage.getItem(cacheKey) || '[]');
    if (Array.isArray(stored)) {
      for (const entry of stored.slice(-50)) {
        if (Array.isArray(entry) && entry.length === 2 && entry.every((value) => typeof value === 'string')) cache.set(...entry);
      }
    }
  } catch { /* The in-memory cache also works when session storage is unavailable. */ }
  let serial = 0;

  class MonettaPredictiveSearch extends HTMLElement {
    connectedCallback() {
      if (this.events) return;
      const find = (name) => this.querySelector('[data-monetta-predictive-' + name + ']');
      this.form = this.querySelector('form');
      this.input = this.form?.querySelector('input[type="search"]');
      this.anchor = this.form?.querySelector('.search-field');
      this.panel = find('panel');
      this.list = find('list');
      this.heading = find('heading');
      this.message = find('message');
      this.removals = find('removals');
      this.live = find('live');
      this.help = find('help');
      this.categories = find('categories');
      if (![this.input, this.anchor, this.panel, this.list, this.heading, this.message, this.removals, this.live, this.help, this.categories].every(Boolean)) return;
      this.uid = 'monetta-predictive-' + (++serial);
      this.list.id = this.uid + '-listbox';
      this.help.id = this.uid + '-help';
      this.input.setAttribute('role', 'combobox');
      this.input.setAttribute('aria-autocomplete', 'list');
      this.input.setAttribute('aria-haspopup', 'listbox');
      this.input.setAttribute('aria-controls', this.list.id);
      this.input.setAttribute('aria-describedby', this.help.id);
      this.input.setAttribute('aria-expanded', 'false');
      this.epoch = this.epoch || 0;
      this.options = [];
      this.active = -1;
      this.limit = Math.min(6, Math.max(1, Number(this.dataset.limit) || 6));
      this.recentLimit = this.hasAttribute('data-recent-limit') ? Math.min(5, Math.max(0, Number(this.dataset.recentLimit) || 0)) : 5;
      this.composing = false;
      this.events = new AbortController();
      const on = (node, type, handler, options = {}) => node.addEventListener(type, handler, { ...options, signal: this.events.signal });
      on(this.input, 'input', (event) => { if (!event.isComposing && !this.composing) this.schedule(); });
      on(this.input, 'focus', () => this.schedule());
      on(this.input, 'compositionstart', () => { this.composing = true; this.close(); });
      on(this.input, 'compositionend', () => { this.composing = false; this.schedule(); });
      on(this.input, 'keydown', (event) => this.onKey(event));
      on(this.form, 'submit', () => { window.MonettaSearchHistory?.remember(this.query); this.close(); });
      on(this, 'click', (event) => {
        // watchSearchClear has already cleared the native input by the time the click bubbles here.
        if (event.target.closest('[data-search-clear]')) this.schedule();
        const remove = event.target.closest('[data-predictive-remove]');
        if (remove) {
          window.MonettaSearchHistory?.remove(remove.dataset.predictiveRemove);
          this.input.focus({ preventScroll: true });
        }
        const option = event.target.closest('[data-monetta-predictive-option]');
        if (option) window.MonettaSearchHistory?.remember(option.dataset.monettaPredictiveTerm || this.query);
      });
      // Keep pointer interaction in the popup from blurring the combobox before a link is activated.
      on(this.panel, 'pointerdown', (event) => { if (event.target.closest('a, button')) event.preventDefault(); });
      on(document, 'pointerdown', (event) => { if (!this.contains(event.target)) this.close(); });
      on(document, 'focusin', (event) => { if (!this.contains(event.target)) this.close(); });
      on(window, 'monetta:recent-searches-change', () => {
        if (document.activeElement === this.input && !this.query) this.showRecent();
      });
      on(window, 'resize', () => this.queuePosition(), { passive: true });
      on(document, 'scroll', () => this.queuePosition(), { passive: true, capture: true });
      if (window.visualViewport) {
        on(window.visualViewport, 'resize', () => this.queuePosition(), { passive: true });
        on(window.visualViewport, 'scroll', () => this.queuePosition(), { passive: true });
      }
      if (window.ResizeObserver) {
        this.observer = new ResizeObserver(() => this.queuePosition());
        this.observer.observe(this.anchor);
      }
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
      this.epoch += 1;
      clearTimeout(this.timer);
      clearTimeout(this.timeout);
      this.request?.abort();
      this.request = null;
    }

    schedule() {
      this.invalidate(); // Older responses are stale even during the debounce interval.
      if (document.activeElement !== this.input || this.composing) { this.close(); return; }
      if (!this.query) { this.showRecent(); return; }
      const term = this.query;
      const epoch = this.epoch;
      this.render('loading', [], 'Buscando…');
      this.list.setAttribute('aria-busy', 'true');
      this.timer = setTimeout(() => this.search(term, epoch), 200);
    }

    current(epoch, term) { return this.isConnected && this.epoch === epoch && this.query === term && document.activeElement === this.input; }

    async search(term, epoch) {
      if (!this.current(epoch, term)) return;
      const controller = new AbortController();
      this.request = controller;
      this.timeout = setTimeout(() => { if (this.current(epoch, term)) this.close(); }, 8000);
      try {
        const url = new URL(this.dataset.predictiveUrl, location.origin);
        if (url.origin !== location.origin) throw new Error('Predictive endpoint must be same-origin');
        url.searchParams.set('q', term);
        url.searchParams.set('resources[type]', 'query,product,collection');
        url.searchParams.set('resources[limit]', String(this.limit));
        url.searchParams.set('resources[limit_scope]', 'each');
        url.searchParams.set('resources[options][unavailable_products]', 'last');
        url.searchParams.set('section_id', 'monetta-predictive-results');
        const key = (window.MonettaConfig?.currency || '') + ':' + url.href.toLocaleLowerCase();
        let markup = cache.get(key);
        if (!markup) {
          const response = await fetch(url, { signal: controller.signal, credentials: 'same-origin', headers: { Accept: 'text/html' } });
          if (!response.ok) throw new Error('Predictive response ' + response.status);
          markup = await response.text();
        }
        if (!this.current(epoch, term)) return;
        const parsed = new DOMParser().parseFromString(markup, 'text/html');
        const result = parsed.querySelector('[data-monetta-predictive-response]');
        const items = result?.querySelector('[data-monetta-predictive-items]');
        const count = Number(result?.dataset.count);
        if (!items || !Number.isInteger(count) || count < 0 || count > 18 || items.querySelectorAll('[data-monetta-predictive-option]').length !== count) throw new Error('Invalid predictive section');
        cache.set(key, markup);
        if (cache.size > 50) cache.delete(cache.keys().next().value);
        try { sessionStorage.setItem(cacheKey, JSON.stringify([...cache])); }
        catch { /* Keep the in-memory cache if the session quota is full. */ }
        const nodes = count ? [...items.children].map((node) => document.importNode(node, true)) : [...this.categories.content.cloneNode(true).children];
        nodes.push(this.item('Ver todos los resultados para «' + term + '»', this.searchURL(term), 'all'));
        this.render(count ? 'results' : 'empty', nodes, count ? '' : 'No encontramos resultados para «' + term + '»');
        this.live.textContent = count ? count + ' resultados' : 'Sin resultados';
      } catch (error) {
        if (this.current(epoch, term) && !controller.signal.aborted) this.close();
      } finally {
        if (this.current(epoch, term)) {
          clearTimeout(this.timeout);
          this.request = null;
          this.list.setAttribute('aria-busy', 'false');
        }
      }
    }

    searchURL(term) {
      const url = new URL(this.form.action);
      url.search = '';
      url.searchParams.set('q', term);
      url.searchParams.set('type', 'product');
      return url.href;
    }

    item(text, href, kind) {
      const item = document.createElement('li');
      item.setAttribute('role', 'presentation');
      const link = document.createElement('a');
      link.className = 'monetta-predictive-search__option';
      link.setAttribute('role', 'option');
      link.tabIndex = -1;
      link.href = href;
      link.textContent = text;
      link.dataset.monettaPredictiveOption = '';
      link.dataset.predictiveKind = kind;
      if (kind === 'recent') link.dataset.monettaPredictiveTerm = text;
      item.append(link);
      return item;
    }

    showRecent() {
      this.invalidate();
      const terms = (window.MonettaSearchHistory?.read() || []).slice(0, this.recentLimit);
      if (!terms.length) { this.close(); return; }
      this.render('recent', terms.map((term) => this.item(term, this.searchURL(term), 'recent')));
      // Buttons are siblings of the listbox, so options never contain nested interactive controls.
      for (const term of terms) {
        const button = document.createElement('button');
        button.type = 'button';
        button.tabIndex = -1;
        button.className = 'monetta-predictive-search__remove';
        button.dataset.predictiveRemove = term;
        button.setAttribute('aria-label', 'Quitar «' + term + '» de las búsquedas recientes');
        button.textContent = '×';
        this.removals.append(button);
      }
      this.live.textContent = terms.length + ' búsquedas recientes';
    }

    render(state, nodes, message = '') {
      this.dataset.state = state;
      this.list.replaceChildren(...nodes);
      this.removals.replaceChildren();
      this.options = [...this.list.querySelectorAll('[data-monetta-predictive-option]')];
      this.options.forEach((option, index) => { option.id = this.uid + '-option-' + index; });
      this.select(-1);
      this.heading.hidden = state !== 'recent';
      this.message.textContent = message;
      this.message.hidden = !message;
      this.list.hidden = !this.options.length;
      this.list.setAttribute('aria-busy', String(state === 'loading'));
      this.panel.hidden = false;
      this.panel.scrollTop = 0;
      this.input.setAttribute('aria-expanded', 'true');
      this.position();
    }

    close() {
      this.invalidate();
      if (!this.panel || !this.input || !this.list) return;
      this.panel.hidden = true;
      this.dataset.state = 'closed';
      this.input.setAttribute('aria-expanded', 'false');
      this.list.setAttribute('aria-busy', 'false');
      this.select(-1);
      this.live.textContent = '';
    }

    select(index) {
      this.active = index;
      this.options?.forEach((option, position) => option.setAttribute('aria-selected', String(position === index)));
      const option = this.options?.[index];
      if (!option) { this.input?.removeAttribute('aria-activedescendant'); return; }
      this.input.setAttribute('aria-activedescendant', option.id);
      const outer = this.panel.getBoundingClientRect();
      const inner = option.getBoundingClientRect();
      if (inner.top < outer.top + 4) this.panel.scrollTop -= outer.top + 4 - inner.top;
      else if (inner.bottom > outer.bottom - 4) this.panel.scrollTop += inner.bottom - outer.bottom + 4;
    }

    onKey(event) {
      if (event.isComposing || this.composing || event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey) return;
      if (event.key === 'Escape') {
        event.preventDefault();
        event.stopPropagation();
        if (!this.panel.hidden) this.close();
        else {
          this.input.value = '';
          this.input.dispatchEvent(new Event('input', { bubbles: true }));
          this.close();
        }
      } else if (event.key === 'Tab') this.close();
      else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        if (this.panel.hidden) { this.schedule(); return; }
        if (!this.options.length) return;
        const step = event.key === 'ArrowDown' ? 1 : -1;
        this.select(this.active < 0 ? (step > 0 ? 0 : this.options.length - 1) : (this.active + step + this.options.length) % this.options.length);
      } else if (event.key === 'Enter' && !this.panel.hidden && this.active >= 0) {
        event.preventDefault();
        this.options[this.active].click();
      } else if (event.key === 'Delete' && !this.panel.hidden && this.options[this.active]?.dataset.predictiveKind === 'recent') {
        event.preventDefault();
        window.MonettaSearchHistory?.remove(this.options[this.active].dataset.monettaPredictiveTerm);
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
      const panelWidth = width < 768 ? width : Math.min(availableWidth, Math.max(rect.width, 360), 560);
      const start = style.direction === 'rtl' ? rect.right - panelWidth : rect.left;
      const panelLeft = width < 768 ? left
        : Math.max(left + marginLeft, Math.min(start, left + width - marginRight - panelWidth));
      const below = Math.max(0, top + height - marginBottom - rect.bottom - gap);
      this.panel.style.left = panelLeft + 'px';
      this.panel.style.width = panelWidth + 'px';
      this.panel.style.maxHeight = below + 'px';
      this.panel.style.top = Math.max(top + margin, rect.bottom + gap) + 'px';
      this.panel.style.bottom = 'auto';
    }
  }
  customElements.define(tag, MonettaPredictiveSearch);
})();
