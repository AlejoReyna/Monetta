// Home: the app's merchandising sequence (home_screen.dart
// _kBoutiqueSectionOrder) with a desktop composition for wide screens.
import { nextPrompt } from '../components/shell.js';
import { brandLogo, productCard, rail, sectionHeader, stars } from '../components/ui.js';
import { ABOUT, BEAUTY_BRANDS, COLLECTION_CARDS, FASHION_BRANDS, SOCIAL_LINKS, STYLE_TILES, TESTIMONIALS } from '../data/content.js';
import { featuredProducts, newestProducts } from '../lib/catalog.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { bindRails, observeHeroSearch } from './page-behaviors.js';

export function homePage() {
  const fresh = newestProducts(8);
  const featured = featuredProducts();
  return {
    title: 'Monetta · Bolsas, carteras y relojes originales',
    meta: { page: 'home', dock: 'nav', dockActive: 'home', nav: null },
    html: html`
      <h1 class="visually-hidden" tabindex="-1">Monetta: bolsas, carteras y relojes originales</h1>
      <section class="home-hero" aria-label="Portada">
        <div class="home-hero__photo">
          <img src="/media/editorial/home_banner.jpg" alt="" width="736" height="981" fetchpriority="high" decoding="async">
        </div>
        <div class="home-hero__search">
          <a class="search-pill" href="/search" data-hero-search>${icon('search', { size: 20 })}<span>${nextPrompt()}</span><span class="visually-hidden"> — buscar productos</span></a>
        </div>
        <div class="home-hero__panel">
          <p class="eyebrow">Boutique Monetta</p>
          <p class="display display--hero">Bolsas, carteras y relojes originales.</p>
          <p class="body-copy">Piezas importadas de Estados Unidos, elegidas para consentirte o para hacer crecer tu negocio, con envíos a todo México.</p>
          <div class="home-hero__actions">
            <a class="btn btn--primary" href="/collections/all?sort_by=created-descending">Ver novedades</a>
            <a class="btn btn--outline" href="/collections/guess">Comprar bolsas</a>
          </div>
          <ul class="home-hero__facts" role="list">
            <li>${icon('check', { size: 16 })} Productos originales</li>
            <li>${icon('truck', { size: 16 })} Envíos a todo México</li>
            <li>${icon('work', { size: 16 })} Mayoreo desde 3 piezas</li>
          </ul>
        </div>
      </section>

      <section class="section container" aria-labelledby="home-novedades">
        ${sectionHeader({ id: 'home-novedades', title: 'Novedades', action: { href: '/collections/all?sort_by=created-descending', label: 'Ver todo' }, railId: 'rail-novedades' })}
        ${rail('rail-novedades', fresh.map((product, index) => productCard(product, { density: 'compact', eager: index < 2 })), { label: 'Novedades' })}
      </section>

      <section class="section container style-grid" aria-labelledby="home-estilo">
        ${sectionHeader({ id: 'home-estilo', title: 'Compra por estilo', action: { href: '/collections/guess', label: 'Ver todo' } })}
        ${rail(
          'rail-estilo',
          [
            ...STYLE_TILES.map(
              (tile) => html`<a class="style-tile" href="/collections/${tile.handle}"><span class="style-tile__art"><img src="${tile.image}" alt="" width="600" height="600" loading="lazy"></span><span>${tile.title}</span></a>`,
            ),
            html`<a class="style-tile style-tile--all" href="/collections/guess"><span class="style-tile__art"><span class="style-tile__circle">${icon('arrowForward', { size: 24 })}</span></span><span>Todas las bolsas</span></a>`,
          ],
          { label: 'Estilos de bolsa' },
        )}
      </section>

      <section class="section container collections-rail" aria-labelledby="home-colecciones">
        ${sectionHeader({ id: 'home-colecciones', title: 'Colecciones' })}
        ${rail(
          'rail-colecciones',
          COLLECTION_CARDS.map(
            (card) => html`<a class="collection-card" href="/collections/${card.handle}">
              <img src="${card.image}" alt="" width="${card.width}" height="${card.height}" loading="lazy" style="object-position:${card.focal}">
              <span class="collection-card__label"><span class="collection-card__title">${card.title}</span>${icon('arrowForward', { size: 22 })}</span>
            </a>`,
          ),
          { label: 'Colecciones' },
        )}
      </section>

      <section class="section container" aria-labelledby="home-seleccion">
        ${sectionHeader({ id: 'home-seleccion', kicker: 'Selección Monetta', title: 'Catálogo de hoy', action: { href: '/collections/all', label: 'Ver catálogo' } })}
        <ul class="product-grid product-grid--four" role="list">
          ${featured.map((product) => html`<li>${productCard(product)}</li>`)}
        </ul>
      </section>

      <section class="section container" aria-labelledby="home-marcas">
        ${sectionHeader({ id: 'home-marcas', title: 'Marcas' })}
        <ul class="brand-grid" role="list">
          ${FASHION_BRANDS.map((brand) => html`<li><a class="brand-tile" href="/collections/${brand.handle}">${brandLogo(brand)}</a></li>`)}
        </ul>
        <div class="beauty-panel">
          <div>
            <p class="eyebrow">Catálogo externo</p>
            <h3 class="title-sans" style="font-size:17px;margin-top:6px">Belleza y perfumes</h3>
            <p class="small text-muted" style="margin-top:6px">Skincare, maquillaje y perfumes se consultan en catálogos fuera de la tienda y se piden por WhatsApp.</p>
            <div class="beauty-panel__actions" style="margin-top:12px">
              <button type="button" class="btn btn--outline btn--sm" data-handoff="catalog" data-catalog="beauty">Ver catálogo de belleza ${icon('northEast', { size: 16 })}</button>
              <button type="button" class="btn btn--quiet btn--sm" data-handoff="catalog" data-catalog="perfumes">Perfumes ${icon('northEast', { size: 16 })}</button>
            </div>
          </div>
          <ul class="beauty-panel__logos" role="list">${BEAUTY_BRANDS.map((brand) => html`<li>${brandLogo(brand)}</li>`)}</ul>
        </div>
      </section>

      <section class="section container" aria-labelledby="home-historia" data-reveal>
        ${sectionHeader({ id: 'home-historia', title: 'Más sobre Monetta' })}
        <div class="about-card">
          <div class="about-card__intro">
            <div class="about-card__image"><img src="${ABOUT.image}" alt="Fundadora de Monetta con bolsas y carteras en la boutique" width="1200" height="900" loading="lazy"></div>
            <div class="about-card__heading">
              <p class="eyebrow">${ABOUT.eyebrow}</p>
              <p class="display display--section" style="margin-top:12px">${ABOUT.headline}</p>
            </div>
          </div>
          <div class="about-card__details">
            <p class="body-copy">${ABOUT.body}</p>
            <a class="btn btn--primary" href="/pages/nuestra-historia">Conoce nuestra historia ${icon('arrowForward', { size: 20 })}</a>
            <a class="btn btn--text" href="/pages/mayoreo">Vende con Monetta ${icon('northEast', { size: 16 })}</a>
          </div>
        </div>
      </section>

      <section class="section container" aria-labelledby="home-redes" data-reveal>
        ${sectionHeader({ id: 'home-redes', title: 'Nuestras redes' })}
        <ul class="social-row" role="list">
          ${SOCIAL_LINKS.map(
            (link) => html`<li><button type="button" class="social-tile" data-handoff="social" data-network="${link.id}">
              <img src="${link.image}" alt="" width="440" height="420" loading="lazy">
              <span class="social-tile__label">${link.label}</span>
              <span class="social-tile__handle">${link.handle}</span>
            </button></li>`,
          )}
        </ul>
      </section>

      <section class="section container" aria-labelledby="home-experiencias" data-reveal>
        ${sectionHeader({ id: 'home-experiencias', kicker: 'Lo que dicen', title: 'Experiencias de clientes' })}
        ${rail(
          'rail-experiencias',
          TESTIMONIALS.map(
            (review) => html`<figure class="review-card">
              <img src="${review.image}" alt="Foto compartida por ${review.reviewer}" width="1080" height="1440" loading="lazy">
              <div class="review-card__body">
                ${stars(review.rating)}
                <blockquote class="review-card__text">“${review.body}”</blockquote>
                <figcaption class="review-card__name">${review.reviewer}</figcaption>
              </div>
            </figure>`,
          ),
          { label: 'Experiencias de clientes', className: 'reviews-rail', focusable: true },
        )}
        <p class="sample-note">${icon('info', { size: 16 })} Muestra de diseño con reseñas del respaldo de la app. En la tienda, Loox muestra las reseñas reales.</p>
      </section>`,
    mount(root) {
      const cleanups = [bindRails(root), observeHeroSearch(root)];
      return () => cleanups.forEach((cleanup) => cleanup?.());
    },
  };
}
