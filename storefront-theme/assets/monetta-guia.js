// Guide components that need a script. The home carousel (HomeEditorialBanner in PR #33): swipe through scroll snap,
// indicator dots that follow the visible slide, previous/next buttons from 1024 px, no autoplay and no timers, as in
// the app. A slide reached with Tab is brought fully into view. Rebinds when the theme editor reloads a section.
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

  const bind = (scope = document) => scope.querySelectorAll('[data-guia-carousel]').forEach(initCarousel);
  bind();
  document.addEventListener('shopify:section:load', (event) => bind(event.target));
})();
