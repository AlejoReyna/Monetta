// Behaviours several pages share: rail arrows and the home search handover.
import { prefersReducedMotion } from '../lib/dom.js';

/** Previous/next buttons for rails; disabled at either end. */
export function bindRails(root) {
  const controllers = [];
  for (const track of root.querySelectorAll('.rail__track')) {
    const prev = root.querySelector(`[data-rail-prev="${track.id}"]`);
    const next = root.querySelector(`[data-rail-next="${track.id}"]`);
    if (!prev || !next) continue;
    const update = () => {
      const max = track.scrollWidth - track.clientWidth - 2;
      prev.disabled = track.scrollLeft <= 2;
      next.disabled = track.scrollLeft >= max;
    };
    const page = (direction) => {
      track.scrollBy({ left: direction * track.clientWidth * 0.92, behavior: prefersReducedMotion() ? 'auto' : 'smooth' });
    };
    const onPrev = () => page(-1);
    const onNext = () => page(1);
    prev.addEventListener('click', onPrev);
    next.addEventListener('click', onNext);
    track.addEventListener('scroll', update, { passive: true });
    const observer = new ResizeObserver(update);
    observer.observe(track);
    update();
    controllers.push(() => {
      prev.removeEventListener('click', onPrev);
      next.removeEventListener('click', onNext);
      track.removeEventListener('scroll', update);
      observer.disconnect();
    });
  }
  return () => controllers.forEach((cleanup) => cleanup());
}

/**
 * Phone home: the header search icon appears once the hero's search pill
 * leaves the viewport (home_screen.dart search handover).
 */
export function observeHeroSearch(root) {
  const pill = root.querySelector('[data-hero-search]');
  const icon = document.querySelector('.site-header__search-icon');
  if (!pill || !icon) return () => {};
  const observer = new IntersectionObserver(
    ([entry]) => {
      icon.hidden = entry.isIntersecting && entry.boundingClientRect.width > 0;
    },
    { rootMargin: `-${88}px 0px 0px 0px` },
  );
  observer.observe(pill);
  return () => observer.disconnect();
}
