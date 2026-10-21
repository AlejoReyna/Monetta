// Site chrome: prototype strip, header (phone / tablet / desktop), category
// navigation, footer, phone dock and the menu drawer.
import { FASHION_BRANDS, SEARCH_PROMPTS } from '../data/content.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { getState, totals } from '../lib/store.js';
import { nextOverlayId, openOverlay } from './overlay.js';

export const NAV_LINKS = [
  { id: 'novedades', label: 'Novedades', href: '/collections/all?sort_by=created-descending' },
  { id: 'bolsas', label: 'Bolsas', href: '/collections/guess' },
  { id: 'carteras', label: 'Carteras', href: '/collections/carteras-1' },
  { id: 'relojes', label: 'Relojes', href: '/collections/relojes' },
];

const LOGO_SRCSET = '/media/brand/logo-monetta.png 1x, /media/brand/logo-monetta@2x.png 2x, /media/brand/logo-monetta@3x.png 3x';

export function wordmarkImage(height = 24) {
  const width = Math.round((height * 132) / 38);
  return html`<img src="/media/brand/logo-monetta@3x.png" srcset="${LOGO_SRCSET}" width="${width}" height="${height}" alt="Monetta">`;
}

let promptIndex = 0;
export function nextPrompt() {
  const prompt = SEARCH_PROMPTS[promptIndex % SEARCH_PROMPTS.length];
  promptIndex += 1;
  return prompt;
}

export function renderShell() {
  const top = document.getElementById('site-top');
  top.innerHTML = String(html`
    <aside class="proto-strip" aria-label="Aviso de prototipo">
      <div class="proto-strip__inner container">
        <span class="proto-strip__dot" aria-hidden="true"></span>
        <span>Prototipo de diseño · datos de muestra<span class="proto-strip__long"> del 17 oct 2026 · nada se compra ni se envía</span></span>
        <button type="button" class="proto-strip__button" data-action="demo-panel" aria-haspopup="dialog">Detalles</button>
      </div>
    </aside>
    <header class="site-header" id="site-header">
      <div class="site-header__bar">
        <div class="site-header__start">
          <a class="icon-button site-header__back" href="/" data-action="back" aria-label="Volver" hidden>${icon('arrowBack', { size: 22 })}</a>
          <button type="button" class="icon-button site-header__menu" data-action="menu" aria-label="Abrir menú" aria-haspopup="dialog">${icon('menu', { size: 24 })}</button>
          <a class="icon-button site-header__search-start" href="/search" aria-label="Buscar productos">${icon('search', { size: 22 })}</a>
        </div>
        <a class="wordmark" href="/" aria-label="Monetta, ir al inicio">${wordmarkImage(24)}</a>
        <form class="header-search" role="search" aria-label="Buscar en la tienda" action="/search" method="get" data-search-form>
          <div class="search-field">
            ${icon('search', { size: 20 })}
            <label class="visually-hidden" for="header-search-input">Buscar productos</label>
            <input id="header-search-input" type="search" name="q" placeholder="${nextPrompt()}" autocomplete="off" spellcheck="false"
              role="combobox" aria-expanded="false" aria-controls="header-search-listbox" aria-autocomplete="list" enterkeyhint="search">
            <button type="button" class="icon-button search-field__clear" data-search-clear aria-label="Borrar búsqueda" hidden>${icon('close', { size: 20 })}</button>
          </div>
          <div class="search-panel" data-search-panel hidden>
            <div class="search-panel__inner" id="header-search-listbox" role="listbox" aria-label="Sugerencias de búsqueda"></div>
            <div class="search-footer" data-search-footer></div>
          </div>
        </form>
        <div class="site-header__end">
          <a class="icon-button site-header__search-icon" href="/search" aria-label="Buscar productos">${icon('search', { size: 24 })}</a>
          <a class="icon-button header-utility header-utility--account" href="/account" aria-label="Cuenta">${icon('person', { size: 24 })}<span class="header-utility__label" aria-hidden="true">Cuenta</span></a>
          <a class="icon-button header-utility header-utility--favorites" href="/pages/favoritos" aria-label="Favoritos">${icon('heart', { size: 22 })}<span class="header-utility__label" aria-hidden="true">Favoritos</span><span class="count-badge" data-favorites-count hidden></span></a>
          <button type="button" class="icon-button header-utility header-utility--cart" data-action="cart" aria-label="Carrito" aria-haspopup="dialog">${icon('bag', { size: 23 })}<span class="header-utility__label" aria-hidden="true">Carrito</span><span class="count-badge" data-cart-count hidden></span></button>
        </div>
      </div>
      <nav class="site-nav" aria-label="Categorías">
        <ul class="site-nav__list" role="list">
          ${NAV_LINKS.map((link) => html`<li><a class="site-nav__link" href="${link.href}" data-nav="${link.id}">${link.label}</a></li>`)}
          <li><button type="button" class="site-nav__link" data-action="brands-menu" aria-haspopup="dialog">Marcas ${icon('expand', { size: 18 })}</button></li>
          <li><button type="button" class="site-nav__link" data-handoff="catalog" data-catalog="perfumes">Perfumes ${icon('northEast', { size: 14 })}</button></li>
          <li><button type="button" class="site-nav__link" data-handoff="catalog" data-catalog="beauty">Maquillaje y skincare ${icon('northEast', { size: 14 })}</button></li>
          <li><a class="site-nav__link" href="/pages/mayoreo" data-nav="mayoreo">Vende con Monetta</a></li>
          <li><a class="site-nav__link" href="/pages/nuestra-historia" data-nav="historia">Nuestra historia</a></li>
        </ul>
      </nav>
    </header>`);

  document.getElementById('site-footer').innerHTML = String(html`
    <div class="container">
      <div class="footer-grid">
        <div class="footer-brand">
          <a class="wordmark" href="/" aria-label="Monetta, ir al inicio">${wordmarkImage(26)}</a>
          <p>Boutique mexicana de bolsas, carteras y relojes originales importados de Estados Unidos. Envíos a todo México.</p>
          <button type="button" class="btn btn--outline btn--sm" data-handoff="whatsapp" data-topic="contacto">${icon('chat', { size: 18 })} WhatsApp 826 106 6868</button>
        </div>
        <div class="footer-col">
          <h2>Comprar</h2>
          <ul role="list">
            ${NAV_LINKS.map((link) => html`<li><a href="${link.href}">${link.label}</a></li>`)}
            <li><a href="/collections/all">Todo el catálogo</a></li>
            <li><a href="/pages/favoritos">Favoritos</a></li>
          </ul>
        </div>
        <div class="footer-col">
          <h2>Ayuda</h2>
          <ul role="list">
            <li><a href="/pages/contact">Contacto y preguntas frecuentes</a></li>
            <li><a href="/policies/shipping-policy">Envíos</a></li>
            <li><a href="/policies/refund-policy">Cambios y devoluciones</a></li>
            <li><a href="/account">Mi cuenta</a></li>
          </ul>
        </div>
        <div class="footer-col">
          <h2>Monetta</h2>
          <ul role="list">
            <li><a href="/pages/nuestra-historia">Nuestra historia</a></li>
            <li><a href="/pages/mayoreo">Vende con Monetta (mayoreo)</a></li>
            <li><button type="button" data-handoff="social" data-network="instagram">Instagram</button></li>
            <li><button type="button" data-handoff="social" data-network="tiktok">TikTok</button></li>
            <li><button type="button" data-handoff="social" data-network="facebook">Facebook</button></li>
          </ul>
        </div>
      </div>
      <div class="footer-bottom">
        <span>© 2026 Monetta</span>
        <span><a href="/policies/privacy-policy">Aviso de privacidad</a> · <a href="/policies/terms-of-service">Términos del servicio</a></span>
      </div>
    </div>`);

  document.getElementById('dock').innerHTML = String(html`
    <div class="dock__bar">
      <a class="dock__item" href="/" data-dock="home"><span class="dock__icon">${icon('home', { size: 22 })}</span>Inicio</a>
      <a class="dock__item" href="/collections/all" data-dock="catalog"><span class="dock__icon">${icon('grid', { size: 22 })}</span>Catálogo</a>
      <a class="dock__item" href="/cart" data-dock="cart"><span class="dock__icon">${icon('bag', { size: 22 })}<span class="count-badge" data-cart-count hidden></span></span><span data-dock-cart-label>Carrito</span></a>
      <a class="dock__item" href="/account" data-dock="account"><span class="dock__icon">${icon('person', { size: 22 })}</span>Cuenta</a>
    </div>`);
  updateCounts();
}

/** Page chrome: which dock shows, active links, back button. */
export function applyPageChrome(meta) {
  const body = document.body;
  body.classList.toggle('has-dock', meta.dock === 'nav');
  body.classList.toggle('has-purchase-dock', meta.dock === 'purchase');
  body.classList.toggle('has-checkout-bar', meta.dock === 'checkout');
  // Phone: the page draws its own compact bar (back, title, actions) in place of the global header.
  body.classList.toggle('has-page-bar', Boolean(meta.bar));
  body.dataset.page = meta.page;
  for (const link of document.querySelectorAll('[data-nav]')) {
    if (link.dataset.nav === meta.nav) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  }
  for (const item of document.querySelectorAll('[data-dock]')) {
    if (item.dataset.dock === meta.dockActive) item.setAttribute('aria-current', 'page');
    else item.removeAttribute('aria-current');
  }
  const back = document.querySelector('.site-header__back');
  back.hidden = !meta.back;
  if (meta.back) back.setAttribute('href', meta.back);
  // Phone: without the dock, the header carries the cart and account.
  document.querySelector('.site-header').classList.toggle('site-header--no-dock', meta.dock !== 'nav');
  // Phone product page (product_header.dart): back + search · logo · account + bag.
  document.querySelector('.site-header').classList.toggle('site-header--product', meta.page === 'product');
  document.querySelector('.site-header__search-icon').hidden = meta.page === 'home' || meta.page === 'search';
}

export function updateCounts() {
  const { count } = totals();
  const favorites = getState().favorites.length;
  for (const badge of document.querySelectorAll('[data-cart-count]')) {
    badge.hidden = count === 0;
    badge.textContent = count > 9 ? '9+' : String(count);
  }
  for (const badge of document.querySelectorAll('[data-favorites-count]')) {
    badge.hidden = favorites === 0;
    badge.textContent = favorites > 9 ? '9+' : String(favorites);
  }
  const cartButton = document.querySelector('.header-utility--cart');
  cartButton?.setAttribute('aria-label', count ? `Carrito, ${count} ${count === 1 ? 'artículo' : 'artículos'}` : 'Carrito, vacío');
  const favoritesLink = document.querySelector('.header-utility--favorites');
  favoritesLink?.setAttribute('aria-label', favorites ? `Favoritos, ${favorites} guardados` : 'Favoritos');
  const dockCart = document.querySelector('[data-dock="cart"]');
  dockCart?.setAttribute('aria-label', count ? `Carrito, ${count} ${count === 1 ? 'artículo' : 'artículos'}` : 'Carrito');
}

/** lib/features/navigation/monetta_side_menu.dart */
export function openMenu() {
  const titleId = nextOverlayId('menu-title');
  const link = (href, iconName, label, extra = '') =>
    html`<a class="menu-link" href="${href}">${icon(iconName, { size: 22 })}<span>${label}</span>${extra}</a>`;
  openOverlay({
    kind: 'drawer-left',
    labelledBy: titleId,
    content: html`<nav class="menu" aria-labelledby="${titleId}">
      <h2 class="visually-hidden" id="${titleId}">Menú</h2>
      <div class="menu__top">
        ${wordmarkImage(21)}
        <button type="button" class="icon-button" data-overlay-close aria-label="Cerrar menú">${icon('close', { size: 22 })}</button>
      </div>
      <div class="menu__account">
        <a class="btn btn--quiet" href="/account">${icon('login', { size: 20 })} Inicia sesión</a>
      </div>
      <div class="menu__links">
        ${link('/collections/all?sort_by=created-descending', 'sparkle', 'Novedades')}
        ${link('/collections/guess', 'bag', 'Bolsas')}
        ${link('/collections/carteras-1', 'wallet', 'Carteras')}
        ${link('/collections/relojes', 'watch', 'Relojes')}
        <button type="button" class="menu-link" data-handoff="catalog" data-catalog="perfumes">${icon('perfume', { size: 22 })}<span class="menu-link__stack"><span>Perfumes</span><span class="menu-link__aside">Catálogo externo ${icon('northEast', { size: 12 })}</span></span></button>
        <button type="button" class="menu-link" data-handoff="catalog" data-catalog="beauty">${icon('face', { size: 22 })}<span class="menu-link__stack"><span>Maquillaje y skincare</span><span class="menu-link__aside">Catálogo externo ${icon('northEast', { size: 12 })}</span></span></button>
        ${link('/collections/all', 'store', 'Todas las marcas')}
        ${link('/pages/mayoreo', 'handshake', 'Vende con Monetta')}
        ${link('/pages/favoritos', 'heart', 'Favoritos')}
      </div>
      <div class="menu__footer">
        ${link('/pages/contact', 'chat', 'Contacto')}
        ${link('/pages/nuestra-historia', 'book', 'Nuestra historia')}
      </div>
    </nav>`,
    initialFocus: '[data-overlay-close]',
  });
}

/** Desktop "Marcas" disclosure as a small dialog anchored under the nav. */
export function openBrandsMenu() {
  const titleId = nextOverlayId('brands-title');
  openOverlay({
    kind: 'dialog',
    labelledBy: titleId,
    className: 'overlay--brands',
    content: html`<div class="overlay__header">
        <h2 class="overlay__title" id="${titleId}">Marcas</h2>
        <button type="button" class="icon-button" data-overlay-close aria-label="Cerrar">${icon('close', { size: 22 })}</button>
      </div>
      <div class="overlay__body">
        <ul class="demo-links" role="list">
          ${FASHION_BRANDS.map((brand) => html`<li><a href="/collections/${brand.handle}">${brand.title} ${icon('chevronRight', { size: 18 })}</a></li>`)}
          <li><a href="/collections/all?filter.p.m.custom.marca=Juicy+Couture">Juicy Couture <span>Filtro del catálogo</span></a></li>
          <li><a href="/collections/all?filter.p.m.custom.marca=Calvin+Klein">Calvin Klein <span>Filtro del catálogo</span></a></li>
        </ul>
        <p class="small text-muted" style="margin-top:16px">Belleza y perfumes (Dior, The Ordinary, Laneige, Rhode, Summer Fridays, Olaplex) se consultan en catálogos externos.</p>
      </div>`,
  });
}
