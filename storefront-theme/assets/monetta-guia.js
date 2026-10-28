// Guide components that need a script. The home carousel (HomeEditorialBanner in PR #33): swipe through scroll snap,
// indicator dots that follow the visible slide, previous/next buttons from 1024 px, no autoplay and no timers, as in
// the app. A slide reached with Tab is brought fully into view. The search screen's «Búsquedas recientes» (slide 05):
// the last five searches, kept in this browser only, each one removable. The quick view (slide 12): a card's «+» on a piece
// with several variants loads sections/monetta-quick-view.liquid and nothing is added until a variant is chosen. Rebinds when
// the theme editor reloads a section.
(() => {
  const reduceMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function initCarousel(root) {
    if (root.dataset.guiaReady) return;
    root.dataset.guiaReady = 'true';
    const track = root.querySelector('.guia-carousel__track');
    if (!track) return;
    const slides = [...track.children];
    const dots = [...root.querySelectorAll('.guia-carousel__dots > span')];
    const current = () => Math.round(track.scrollLeft / Math.max(1, track.clientWidth));
    const show = (index) => {
      const next = (index + slides.length) % slides.length;
      track.scrollTo({ left: next * track.clientWidth, behavior: reduceMotion() ? 'auto' : 'smooth' });
    };
    const sync = () => {
      const index = current();
      dots.forEach((dot, k) => dot.classList.toggle('is-active', k === index));
    };
    track.addEventListener('scroll', () => window.requestAnimationFrame(sync), { passive: true });
    root.querySelector('[data-guia-prev]')?.addEventListener('click', () => show(current() - 1));
    root.querySelector('[data-guia-next]')?.addEventListener('click', () => show(current() + 1));
    track.addEventListener('focusin', (event) => {
      const index = slides.findIndex((slide) => slide.contains(event.target));
      if (index >= 0 && index !== current()) show(index);
    });
  }

  const RECENT_KEY = 'monetta:recent-searches';
  const readRecent = () => {
    try {
      const list = JSON.parse(window.localStorage.getItem(RECENT_KEY) || '[]');
      return Array.isArray(list) ? list.filter((t) => typeof t === 'string' && t.trim()) : [];
    } catch {
      return [];
    }
  };
  const writeRecent = (list) => {
    try {
      window.localStorage.setItem(RECENT_KEY, JSON.stringify(list.slice(0, 5)));
      return true;
    } catch {
      return false;
    }
  };

  function initRecent(root) {
    if (root.dataset.guiaReady) return;
    root.dataset.guiaReady = 'true';
    const block = root.querySelector('[data-guia-recent-block]');
    const list = root.querySelector('[data-guia-recent-list]');
    if (!block || !list) return;
    const current = (root.dataset.current || '').trim();
    let terms = readRecent();
    if (current) {
      terms = [current, ...terms.filter((t) => t.toLowerCase() !== current.toLowerCase())].slice(0, 5);
      if (!writeRecent(terms)) return;
    }
    const render = () => {
      list.replaceChildren(...terms.map((term) => {
        const item = document.createElement('li');
        item.className = 'guia-search__recent';
        const link = document.createElement('a');
        link.className = 'guia-search__row';
        link.href = `${window.Shopify?.routes?.root || '/'}search?type=product&q=${encodeURIComponent(term)}`;
        link.innerHTML = '<svg class="icon guia-search__icon" viewBox="0 0 24 24" width="22" height="22" aria-hidden="true" focusable="false"><path fill="currentColor" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 18a8 8 0 1 1 0-16 8 8 0 0 1 0 16Zm.5-13H11v6l5.2 3.2.8-1.3-4.5-2.7V7Z"/></svg>';
        const label = document.createElement('span');
        label.textContent = term;
        link.append(label);
        const remove = document.createElement('button');
        remove.type = 'button';
        remove.className = 'icon-button guia-search__remove';
        remove.setAttribute('aria-label', `Quitar «${term}» de las búsquedas recientes`);
        remove.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false"><path fill="currentColor" d="M19 6.4 17.6 5 12 10.6 6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12z"/></svg>';
        remove.addEventListener('click', () => {
          const index = terms.indexOf(term);
          terms = terms.filter((t) => t !== term);
          writeRecent(terms);
          render();
          const buttons = list.querySelectorAll('.guia-search__remove');
          (buttons[Math.min(index, buttons.length - 1)] || root.querySelector('.guia-search__row'))?.focus();
          window.Monetta?.announce?.(`Se quitó «${term}» de las búsquedas recientes.`);
        });
        item.append(link, remove);
        return item;
      }));
      block.hidden = terms.length === 0;
    };
    render();
  }

  // «Comparte y gana»: copy a catalog link; without the clipboard API the field is selected for the visitor to copy.
  function initCopy(root) {
    if (root.dataset.guiaReady) return;
    root.dataset.guiaReady = 'true';
    const input = root.querySelector('input');
    root.querySelector('[data-guia-copy-button]')?.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(input.value);
        window.Monetta?.announce?.('Enlace copiado.');
        window.Monetta?.toast?.('Enlace copiado.');
      } catch {
        input.focus();
        input.select();
      }
    });
  }

  function renderPrice(target, variant) {
    const price = document.createElement('span');
    price.className = 'price';
    price.textContent = variant.price;
    const parts = [price];
    if (variant.compare) {
      const compare = document.createElement('s');
      compare.className = 'price-compare';
      compare.textContent = variant.compare;
      const badge = document.createElement('span');
      badge.className = 'badge badge--sale';
      badge.textContent = `-${variant.pct}%`;
      parts.push(compare, badge);
    }
    target.replaceChildren(...parts);
  }

  function bindQuickView(root, dialog, trigger) {
    const variants = JSON.parse(root.querySelector('[data-quick-view-variants]')?.textContent || '[]');
    const groups = [...root.querySelectorAll('[data-quick-view-group]')];
    const add = root.querySelector('[data-quick-view-add]');
    const hint = root.querySelector('[data-quick-view-hint]');
    const price = root.querySelector('[data-quick-view-price]');
    const photo = root.querySelector('[data-quick-view-photo]');
    let chosen = null;
    const update = () => {
      const picked = groups.map((group) => group.querySelector('input:checked')?.value ?? null);
      const complete = picked.every((value) => value !== null);
      chosen = groups.length === 0 ? variants[0] : complete ? variants.find((v) => v.options.every((o, i) => o === picked[i])) || null : null;
      if (chosen) {
        renderPrice(price, chosen);
        if (chosen.image && photo) photo.src = chosen.image;
      }
      const ready = Boolean(chosen?.available);
      add.disabled = !ready;
      hint.textContent = ready ? '' : !complete ? 'Elige una opción para agregarla a tu bolsa.' : !chosen ? 'Esa combinación no está disponible.' : 'Esta opción está agotada.';
      hint.hidden = ready;
    };
    root.addEventListener('change', update);
    root.querySelectorAll('[data-quick-view-thumb]').forEach((thumb) => {
      thumb.addEventListener('click', () => {
        if (photo) photo.src = thumb.dataset.quickViewThumb;
        root.querySelectorAll('[data-quick-view-thumb]').forEach((t) => t.removeAttribute('aria-current'));
        thumb.setAttribute('aria-current', 'true');
      });
    });
    add.addEventListener('click', async () => {
      if (!chosen?.available || add.dataset.pending) return;
      add.dataset.pending = 'true';
      window.Monetta.closeDialog(dialog, { restoreFocus: false });
      const option = groups.length ? ` (${chosen.options.join(' / ')})` : '';
      await window.Monetta.cart.add({ id: chosen.id, quantity: 1, name: `${root.dataset.productTitle || ''}${option}`, trigger });
      delete add.dataset.pending;
    });
    update();
  }

  async function openQuickView(button) {
    const dialog = document.getElementById('quick-view');
    const panel = dialog?.querySelector('[data-quick-view-panel]');
    if (!dialog || !panel || !window.Monetta?.openDialog || button.dataset.pending) return;
    button.dataset.pending = 'true';
    button.setAttribute('aria-busy', 'true');
    try {
      const root = window.Shopify?.routes?.root || '/';
      const response = await fetch(`${root}products/${encodeURIComponent(button.dataset.quickView)}?section_id=monetta-quick-view`, { credentials: 'same-origin' });
      const view = response.ok ? new DOMParser().parseFromString(await response.text(), 'text/html').querySelector('[data-quick-view-root]') : null;
      if (!view) {
        window.location.assign(button.dataset.productUrl);
        return;
      }
      panel.replaceChildren(view);
      bindQuickView(view, dialog, button);
      window.Monetta.openDialog(dialog, button);
    } catch {
      window.location.assign(button.dataset.productUrl);
    } finally {
      delete button.dataset.pending;
      button.removeAttribute('aria-busy');
    }
  }

  document.addEventListener('click', (event) => {
    const button = event.target.closest?.('[data-quick-view]');
    if (!button) return;
    event.preventDefault();
    openQuickView(button);
  });

  const bind = (scope = document) => {
    scope.querySelectorAll('[data-guia-carousel]').forEach(initCarousel);
    scope.querySelectorAll('[data-guia-recent]').forEach(initRecent);
    scope.querySelectorAll('[data-guia-copy]').forEach(initCopy);
  };
  bind();
  document.addEventListener('shopify:section:load', (event) => bind(event.target));
})();
