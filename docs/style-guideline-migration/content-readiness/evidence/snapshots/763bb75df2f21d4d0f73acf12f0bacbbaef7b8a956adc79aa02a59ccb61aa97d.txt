// Prototype bootstrap: routes, shell, global interactions and state wiring.
import './styles/tokens.css';
import './styles/base.css';
import './styles/components.css';
import './styles/pages.css';

import { addToCartFlow, openCartDrawer } from './components/cart-ui.js';
import { openDemoPanel } from './components/demo-panel.js';
import {
  openCatalogHandoff,
  openCommunityHandoff,
  openPartnerCatalogHandoff,
  openSocialHandoff,
  openWhatsAppHandoff,
} from './components/handoff.js';
import { closeAllOverlays } from './components/overlay.js';
import { openQuickView } from './components/quick-view.js';
import { createPredictiveSearch } from './components/search-ui.js';
import { applyPageChrome, openBrandsMenu, openMenu, renderShell, updateCounts } from './components/shell.js';
import { toast } from './components/toast.js';
import { productByHandle } from './lib/catalog.js';
import { refreshPinnedChrome, watchPinnedChrome } from './lib/chrome.js';
import { isPhone, prefersReducedMotion, preserveFocus } from './lib/dom.js';
import { icon } from './lib/icons.js';
import { revealFocusedScrollerItem } from './lib/scrollers.js';
import { defineRoute, leaveScreen, matchRoute, navigate, savedScroll, startRouter } from './lib/router.js';
import { isFavorite, subscribe, toggleFavorite } from './lib/store.js';
import { cartPage } from './pages/cart.js';
import { collectionPage } from './pages/collection.js';
import { designAccountPage, designBoardPage } from './pages/design.js';
import { homePage } from './pages/home.js';
import { productPage } from './pages/product.js';
import { searchPage } from './pages/search.js';
import {
  accountPage,
  contactPage,
  favoritesPage,
  mayoreoPage,
  notFoundPage,
  policyPage,
  storyPage,
} from './pages/simple-pages.js';

defineRoute('/', homePage);
defineRoute('/collections/:handle', collectionPage);
defineRoute('/products/:handle', productPage);
defineRoute('/search', searchPage);
defineRoute('/cart', cartPage);
defineRoute('/pages/favoritos', favoritesPage);
defineRoute('/pages/mayoreo', mayoreoPage);
defineRoute('/pages/nuestra-historia', storyPage);
defineRoute('/pages/contact', contactPage);
defineRoute('/design/cuenta', designAccountPage);
defineRoute('/design/board', designBoardPage);
defineRoute('/account', accountPage);
defineRoute('/account/login', accountPage);
defineRoute('/policies/:handle', policyPage);

let cleanup = null;
const revealObserver =
  'IntersectionObserver' in window && !prefersReducedMotion()
    ? new IntersectionObserver(
        (entries) => {
          for (const entry of entries) {
            if (entry.isIntersecting) {
              entry.target.classList.add('is-revealed');
              revealObserver.unobserve(entry.target);
            }
          }
        },
        { rootMargin: '0px 0px -8% 0px' },
      )
    : null;

if (revealObserver) document.documentElement.classList.add('reveal-ready');

function render({ mode, focus }) {
  closeAllOverlays();
  const url = new URL(location.href);
  const match = matchRoute(url.pathname);
  const page = match ? match.handler({ url, params: match.params }) : notFoundPage();
  cleanup?.();
  cleanup = null;
  const main = document.getElementById('main');
  preserveFocus(() => {
    main.innerHTML = String(page.html);
  });
  document.title = page.title;
  applyPageChrome(page.meta);
  cleanup = page.mount?.(main, { initial: mode === 'initial' }) ?? null;

  if (mode === 'restore') window.scrollTo(0, savedScroll());
  else if (mode === 'top') window.scrollTo(0, 0);

  // The heading takes focus on navigation unless the page placed it itself (an empty search focuses its field).
  const placedByPage = Boolean(page.meta.ownsFocus) && main.contains(document.activeElement) && document.activeElement !== main;
  if (focus && mode !== 'keep' && !placedByPage) main.querySelector('h1')?.focus({ preventScroll: true });
  for (const element of main.querySelectorAll('[data-reveal]')) {
    if (revealObserver) revealObserver.observe(element);
    else element.classList.add('is-revealed');
  }
  // The new page brought its own bar and bottom controls: re-measure what they cover.
  refreshPinnedChrome();
  updateHeaderRule();
}

function updateHeaderRule() {
  document.getElementById('site-top').classList.toggle('is-scrolled', window.scrollY > 4);
}

function refreshFavoriteButtons(handle) {
  const selector = handle ? `[data-action="favorite"][data-handle="${CSS.escape(handle)}"]` : '[data-action="favorite"]';
  for (const button of document.querySelectorAll(selector)) {
    const product = productByHandle(button.dataset.handle);
    if (!product) continue;
    const saved = isFavorite(product.handle);
    button.setAttribute('aria-pressed', String(saved));
    button.setAttribute('aria-label', `${saved ? 'Quitar de favoritos' : 'Guardar en favoritos'}: ${product.title}`);
    button.setAttribute('title', saved ? 'Quitar de favoritos' : 'Guardar');
    const svg = button.querySelector('svg');
    const size = Number(svg?.getAttribute('width') ?? 20);
    if (svg) svg.outerHTML = String(icon(saved ? 'heartFilled' : 'heart', { size }));
  }
}

async function quickAdd(button) {
  const product = productByHandle(button.dataset.handle);
  if (!product) return;
  if (product.variants.length > 1) {
    openQuickView(product, { requireChoice: true });
    return;
  }
  if (button.getAttribute('aria-busy') === 'true') return;
  const circle = button.querySelector('.card__quick-circle');
  const original = circle.innerHTML;
  const label = button.getAttribute('aria-label');
  button.setAttribute('aria-busy', 'true');
  button.setAttribute('aria-label', `Agregando ${product.title} al carrito`);
  circle.innerHTML = '<span class="spinner" aria-hidden="true"></span>';
  await addToCartFlow({ product, variant: product.variants[0], quantity: 1 });
  if (button.isConnected) {
    button.removeAttribute('aria-busy');
    button.setAttribute('aria-label', label);
    circle.innerHTML = original;
  }
}

const HANDOFFS = {
  whatsapp: (target) => openWhatsAppHandoff(target.dataset.topic, productByHandle(target.dataset.handle ?? '')),
  catalog: (target) => openCatalogHandoff(target.dataset.catalog),
  social: (target) => openSocialHandoff(target.dataset.network),
  'partner-catalog': (target) => openPartnerCatalogHandoff(target.dataset.group, target.dataset.mode),
  community: (target) => openCommunityHandoff(target.dataset.title),
};

document.addEventListener('click', (event) => {
  const target = event.target instanceof Element ? event.target.closest('[data-action], [data-handoff]') : null;
  if (!target) return;
  if (target.dataset.handoff) {
    event.preventDefault();
    HANDOFFS[target.dataset.handoff]?.(target);
    return;
  }
  switch (target.dataset.action) {
    case 'menu':
      openMenu();
      break;
    case 'cart':
      if (isPhone()) navigate('/cart');
      else openCartDrawer();
      break;
    case 'demo-panel':
      openDemoPanel();
      break;
    case 'brands-menu':
      openBrandsMenu();
      break;
    case 'back':
      // Leaves the screen: filter and sort entries of this screen are skipped
      // (the browser's own Back still steps through them). A visit that began
      // here has nothing before it, so the link goes to its parent.
      event.preventDefault();
      leaveScreen(target.getAttribute('href'));
      break;
    case 'favorite': {
      event.preventDefault();
      const result = toggleFavorite(target.dataset.handle);
      toast(
        result.saved ? (result.persisted ? 'Guardado en favoritos.' : 'Guardado solo durante esta visita: el navegador no permite guardar datos.') : 'Quitado de favoritos.',
        result.saved ? { action: { label: 'Ver favoritos', onClick: () => navigate('/pages/favoritos') } } : {},
      );
      break;
    }
    case 'quick-add':
      event.preventDefault();
      quickAdd(target);
      break;
    default:
      break;
  }
});

// Broken images fall back to a quiet labelled ground, never a broken icon.
document.addEventListener(
  'error',
  (event) => {
    const image = event.target;
    if (!(image instanceof HTMLImageElement) || image.dataset.failed) return;
    image.dataset.failed = 'true';
    image.style.visibility = 'hidden';
    const label = document.createElement('span');
    label.className = 'img-fallback';
    label.textContent = image.dataset.fallback || 'Monetta';
    image.after(label);
  },
  true,
);

document.addEventListener('focusin', revealFocusedScrollerItem);
document.addEventListener('focusin', (event) => {
  const field = event.target;
  if (field instanceof HTMLInputElement && ['text', 'search', 'number', 'email', 'tel'].includes(field.type)) {
    document.body.classList.add('is-typing');
  }
});
document.addEventListener('focusout', () => document.body.classList.remove('is-typing'));

window.addEventListener('scroll', updateHeaderRule, { passive: true });

subscribe((state, change) => {
  if (['cart', 'reset'].includes(change.type)) updateCounts();
  if (['favorites', 'reset'].includes(change.type)) {
    updateCounts();
    refreshFavoriteButtons(change.type === 'favorites' ? change.handle : null);
  }
});

renderShell();
watchPinnedChrome();
const headerForm = document.querySelector('[data-search-form]');
createPredictiveSearch({
  form: headerForm,
  input: headerForm.querySelector('input'),
  panel: headerForm.querySelector('[data-search-panel]'),
  listbox: headerForm.querySelector('[role="listbox"]'),
});
startRouter(render);
