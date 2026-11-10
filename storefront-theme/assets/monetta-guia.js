// Guide components that need a script. The home carousel (HomeEditorialBanner in PR #33): swipe through scroll snap,
// indicator dots that follow the visible slide, previous/next buttons from 1024 px, no autoplay and no timers, as in
// the app. A slide reached with Tab is brought fully into view. «Colecciones» on phones opens on its middle card. The search
// screen's «Búsquedas recientes» (slide 05):
// the last five searches, kept in this browser only, each one removable. The preview (the client's 29 Oct reference): tapping a
// card loads sections/monetta-quick-view.liquid with the card's variant chosen; a modified click still opens the product page
// in a new tab. Rebinds when the theme editor reloads a section.
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

  // «Colecciones» on phones opens on its middle card, as monetta.mx's earlier home did. Only the scroller moves, never the page.
  function initCollections(track) {
    if (track.dataset.guiaReady) return;
    track.dataset.guiaReady = 'true';
    const items = track.children;
    if (items.length < 3 || track.scrollWidth <= track.clientWidth) return;
    const middle = items[Math.floor(items.length / 2)];
    const card = middle.getBoundingClientRect();
    const box = track.getBoundingClientRect();
    track.scrollLeft += card.left + card.width / 2 - (box.left + box.width / 2);
  }

  // Reveal the Home invitation once on arrival. Content stays visible without JS/animation support or with reduced motion.
  function initRegister(root) {
    if (root.dataset.guiaReady) return;
    root.dataset.guiaReady = 'true';
    if (reduceMotion() || !('IntersectionObserver' in window) || typeof root.animate !== 'function') return;
    const observer = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return;
      observer.disconnect();
      if (reduceMotion() || root.contains(document.activeElement)) return;
      const elements = [...root.querySelectorAll('.guia-register__inner > *')];
      const animations = elements.map((element, index) => element.animate(
        [{ opacity: 0, transform: 'translateY(20px)' }, { opacity: 1, transform: 'translateY(0)' }],
        { duration: 600, delay: index * 80, easing: 'cubic-bezier(0.22, 1, 0.36, 1)', fill: 'backwards' },
      ));
      const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
      const reveal = () => animations.forEach((animation) => animation.cancel());
      const onMotionChange = () => { if (motion.matches) reveal(); };
      // A keyboard user can always focus the button immediately, even during the staggered entrance.
      root.addEventListener('focusin', reveal);
      motion.addEventListener('change', onMotionChange);
      Promise.all(animations.map((animation) => animation.finished.catch(() => {}))).then(() => {
        root.removeEventListener('focusin', reveal);
        motion.removeEventListener('change', onMotionChange);
      });
    }, { threshold: 0.2, rootMargin: '0px 0px -48px 0px' });
    observer.observe(root);
  }

  const readRecent = () => window.MonettaSearchHistory?.read() || [];

  function initRecent(root) {
    if (root.dataset.guiaReady) return;
    root.dataset.guiaReady = 'true';
    const block = root.querySelector('[data-guia-recent-block]');
    const list = root.querySelector('[data-guia-recent-list]');
    if (!block || !list) return;
    const current = (root.dataset.current || '').trim();
    if (current) window.MonettaSearchHistory?.remember(current);
    const render = () => {
      const terms = readRecent();
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
          window.MonettaSearchHistory?.remove(term);
          const buttons = list.querySelectorAll('.guia-search__remove');
          (buttons[Math.min(index, buttons.length - 1)] || root.querySelector('.guia-search__row'))?.focus();
          window.Monetta?.announce?.(`Se quitó «${term}» de las búsquedas recientes.`);
        });
        item.append(link, remove);
        return item;
      }));
      block.hidden = terms.length === 0;
    };
    window.addEventListener('monetta:recent-searches-change', () => { if (root.isConnected) render(); });
    render();
  }

  // «Comparte y gana»: copy a catalog link; without the clipboard API the field is selected for the visitor to copy. Where the
  // browser has a share sheet (navigator.share), «Compartir enlace» opens it with the link, as the app's Share.share.
  function initCopy(root) {
    if (root.dataset.guiaReady) return;
    root.dataset.guiaReady = 'true';
    const input = root.querySelector('input');
    const notify = (message) => {
      window.Monetta?.announce?.(message);
      window.Monetta?.toast?.(message);
    };
    root.querySelector('[data-guia-copy-button]')?.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(input.value);
        notify('Enlace copiado');
      } catch {
        input.focus();
        input.select();
      }
    });
    const share = root.querySelector('[data-guia-share-button]');
    if (!share || typeof navigator.share !== 'function') return;
    share.hidden = false;
    share.addEventListener('click', async () => {
      try {
        await navigator.share({ url: input.value });
      } catch (error) {
        if (error?.name !== 'AbortError') notify('No se pudo compartir el catálogo');
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
    const stock = root.querySelector('[data-quick-view-stock]');
    let chosen = null;
    const update = () => {
      const picked = groups.map((group) => group.querySelector('input:checked')?.value ?? null);
      const complete = picked.every((value) => value !== null);
      chosen = groups.length === 0 ? variants[0] : complete ? variants.find((v) => v.options.every((o, i) => o === picked[i])) || null : null;
      if (chosen) {
        renderPrice(price, chosen);
        if (chosen.image && photo) {
          photo.src = chosen.image;
          // The highlighted thumbnail follows the variant's photo when it is one of the four shown.
          const match = root.querySelector(`[data-image-id="${chosen.imageId}"]`);
          if (match) {
            root.querySelectorAll('[data-quick-view-thumb]').forEach((t) => t.removeAttribute('aria-current'));
            match.setAttribute('aria-current', 'true');
          }
        }
      }
      const ready = Boolean(chosen?.available);
      if (stock) {
        // Shopify's own count, only when it tracks the piece and refuses overselling; otherwise just whether it can be bought.
        const low = ready && chosen.low > 0;
        stock.textContent = !chosen ? 'Elige una opción' : low ? `Últimas ${chosen.low} ${chosen.low === 1 ? 'pieza' : 'piezas'}` : ready ? 'Disponible' : 'Agotado';
        stock.dataset.tone = !chosen ? 'idle' : low || !ready ? 'alert' : 'ok';
      }
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
    const trigger = event.target.closest?.('[data-quick-view]');
    if (!trigger) return;
    // A card is a real link to the product page: a new-tab click, or a page without the preview dialog, follows it.
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    if (!document.getElementById('quick-view') || !window.Monetta?.openDialog) return;
    event.preventDefault();
    openQuickView(trigger);
  });

  function initFeature(root) {
    if (root.dataset.v41Feature) return;
    root.dataset.v41Feature = 'true';
    const stage = root.querySelector('[data-feature-stage]');
    const picks = [...root.querySelectorAll('[data-feature-pick]')];
    if (!stage || picks.length === 0) return;
    let index = 0;
    const show = (next) => {
      index = (next + picks.length) % picks.length;
      const template = picks[index].parentElement.querySelector('template');
      if (template) stage.replaceChildren(template.content.cloneNode(true));
      picks.forEach((pick, item) => {
        const selected = item === index;
        pick.classList.toggle('is-selected', selected);
        pick.setAttribute('aria-current', selected ? 'true' : 'false');
      });
      const title = picks[index].getAttribute('aria-label');
      if (title) window.Monetta?.announce?.(`Mostrando ${title}`);
    };
    root.querySelector('[data-feature-prev]')?.addEventListener('click', () => show(index - 1));
    root.querySelector('[data-feature-next]')?.addEventListener('click', () => show(index + 1));
    picks.forEach((pick, item) => pick.addEventListener('click', () => show(item)));
  }

  async function submitFeed(form, checkout) {
    const id = form.querySelector('[name="id"]')?.value;
    if (!id || !window.Monetta?.add) return false;
    const result = await window.Monetta.add({
      id,
      quantity: 1,
      name: form.dataset.productName || '',
      open: false,
      trigger: form.querySelector('button'),
    });
    if (result?.ok && checkout) window.location.assign(checkout);
    return true;
  }

  function initFeed(root) {
    if (root.dataset.v41Feed) return;
    root.dataset.v41Feed = 'true';
    root.addEventListener('submit', (event) => {
      const form = event.target;
      if (!(form instanceof HTMLFormElement)) return;
      if (!form.matches('[data-feed-add], [data-feed-buy]')) return;
      if (!window.Monetta?.add) return;
      event.preventDefault();
      submitFeed(form, form.dataset.checkout || '');
    });
  }

  const bind = (scope = document) => {
    scope.querySelectorAll('[data-guia-carousel]').forEach(initCarousel);
    scope.querySelectorAll('[data-guia-collections]').forEach(initCollections);
    scope.querySelectorAll('.guia-register').forEach(initRegister);
    scope.querySelectorAll('[data-guia-recent]').forEach(initRecent);
    scope.querySelectorAll('[data-guia-copy]').forEach(initCopy);
    scope.querySelectorAll('[data-v41-feature]').forEach(initFeature);
    scope.querySelectorAll('.v41-feed').forEach(initFeed);
  };
  bind();
  document.addEventListener('shopify:section:load', (event) => bind(event.target));
})();
