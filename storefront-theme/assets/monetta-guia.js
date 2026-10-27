// Guide components that need a script. The home carousel (HomeEditorialBanner in PR #33): swipe through scroll snap,
// indicator dots that follow the visible slide, previous/next buttons from 1024 px, no autoplay and no timers, as in
// the app. A slide reached with Tab is brought fully into view. The search screen's «Búsquedas recientes» (slide 05):
// the last five searches, kept in this browser only, each one removable. Rebinds when the theme editor reloads a section.
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

  const bind = (scope = document) => {
    scope.querySelectorAll('[data-guia-carousel]').forEach(initCarousel);
    scope.querySelectorAll('[data-guia-recent]').forEach(initRecent);
  };
  bind();
  document.addEventListener('shopify:section:load', (event) => bind(event.target));
})();
