// Design-review surfaces of the style-guideline migration. They exist so the owners can judge the
// direction on real components at 390, 834 and 1440 px:
//   /design/cuenta  the signed-in account reference (the real account is Shopify-hosted; this is the
//                   target presentation for the native app and the hosted-account branding)
//   /design/board   tokens, type roles and every shared component in its states
// Both are prototype-only and never ship in the Shopify theme.
import { productCard } from '../components/ui.js';
import { productByHandle } from '../lib/catalog.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { formatMoney } from '../lib/money.js';

const SAMPLE_PHOTO = productByHandle('bolso-coach-shoulder-negro-rectangular')?.images[0] ?? '';

function row({ iconName, label, hint, href = '#', attrs = '' }) {
  return html`<li><a class="row-link" href="${href}" ${attrs}>
    <span class="row-link__icon">${icon(iconName, { size: 26 })}</span>
    <span class="row-link__text"><span class="row-link__label">${label}</span>${hint ? html`<span class="row-link__hint">${hint}</span>` : ''}</span>
    ${icon('chevronRight', { size: 22 })}
  </a></li>`;
}

export function serviceStrip() {
  const items = [
    ['truck', 'Envíos a todo México', 'Paquetería asegurada'],
    ['card', 'Pagos seguros', 'Checkout de Shopify'],
    ['shield', 'Productos 100% originales', 'Garantía de autenticidad'],
    ['headset', 'Atención personalizada', 'Escríbenos por WhatsApp'],
  ];
  return html`<ul class="service-strip" role="list" aria-label="Por qué comprar en Monetta">
    ${items.map(
      ([name, title, hint]) => html`<li class="service-strip__item">${icon(name, { size: 30 })}<span class="service-strip__title">${title}</span><span class="service-strip__hint">${hint}</span></li>`,
    )}
  </ul>`;
}

export function shareBanner() {
  return html`<section class="promo-banner" aria-labelledby="share-title">
    <div class="promo-banner__text">
      <h2 class="promo-banner__title" id="share-title">Comparte el catálogo</h2>
      <p class="promo-banner__copy">Envía a quien quieras los enlaces de bolsas, carteras y relojes.</p>
    </div>
    <div class="promo-banner__photo"><img src="${SAMPLE_PHOTO}" alt="" width="300" height="300" loading="lazy"></div>
    <div class="promo-banner__action"><button type="button" class="btn btn--dark" data-handoff="catalog">Compartir catálogo ${icon('chevronRight', { size: 18 })}</button></div>
  </section>`;
}

/* ------------------------------------------------------------ /design/cuenta */
export function designAccountPage() {
  return {
    title: 'Mi cuenta (referencia de diseño) · Monetta',
    meta: { page: 'account', dock: 'nav', dockActive: 'account', nav: null },
    html: html`<div class="container">
      <h1 class="visually-hidden" tabindex="-1">Mi cuenta</h1>
      <div class="account-layout">
        <div class="account-layout__lead">
          <div class="identity">
            <span class="identity__avatar" aria-hidden="true">A</span>
            <div>
              <p class="identity__name">Ana</p>
              <p class="identity__email">ana@email.com</p>
            </div>
          </div>
          <a class="balance-row" href="#rewards" aria-label="Monetta Rewards, saldo ${formatMoney('320.00', { code: true })}">
            <span class="balance-row__icon">${icon('gift', { size: 24 })}</span>
            <span class="balance-row__text"><span class="balance-row__label">Monetta Rewards</span><span class="balance-row__value">${formatMoney('320.00', { code: true })}</span></span>
            ${icon('chevronRight', { size: 22 })}
          </a>
          ${shareBanner()}
        </div>
        <div class="account-layout__rows">
          <ul class="row-list" role="list" aria-label="Mi cuenta">
            ${row({ iconName: 'box', label: 'Mis pedidos', href: '#pedidos' })}
            ${row({ iconName: 'heart', label: 'Favoritos', href: '/pages/favoritos' })}
            ${row({ iconName: 'bell', label: 'Notificaciones', href: '#notificaciones' })}
            ${row({ iconName: 'pin', label: 'Direcciones', href: '#direcciones' })}
            ${row({ iconName: 'settings', label: 'Preferencias', href: '#preferencias' })}
            ${row({ iconName: 'bag', label: 'Vende con Monetta', hint: 'Mayoreo desde 3 piezas', href: '/pages/mayoreo' })}
            ${row({ iconName: 'help', label: 'Ayuda y contacto', href: '/pages/contact' })}
          </ul>
          <button type="button" class="btn btn--text account-layout__signout">${icon('logout', { size: 22 })} Cerrar sesión</button>
        </div>
      </div>
      <p class="notice" style="margin:24px 0">${icon('info', { size: 18 })}<span>Referencia de diseño con datos de muestra. Pagos y direcciones se administran en la cuenta de Shopify; el saldo de Rewards es el programa vigente en pesos (MXN).</span></p>
    </div>`,
  };
}

/* ------------------------------------------------------------- /design/board */
const SWATCHES = [
  ['canvas', 'Lienzo de página'],
  ['bar', 'Barras: encabezado y navegación'],
  ['surface', 'Superficie de contenido y formularios'],
  ['surface-warm', 'Paneles de campaña y servicio'],
  ['surface-tile', 'Tarjetas, chips y mosaicos'],
  ['ink', 'Texto principal'],
  ['ink-muted', 'Texto de apoyo'],
  ['action-primary', 'Acción principal (compra)'],
  ['action-dark', 'Píldora oscura (compartir)'],
  ['accent-text', 'Acento legible: enlaces y etiquetas'],
  ['gold', 'Dorado decorativo (nunca texto)'],
  ['divider', 'Divisor decorativo'],
  ['border-control', 'Borde de control (3:1)'],
  ['navigation-inactive', 'Navegación inactiva'],
  ['sale', 'Oferta y error'],
  ['sale-surface', 'Etiqueta de oferta'],
  ['success', 'Éxito'],
];

const ROLES = [
  ['campaign', 'Campaña', 'Nueva colección'],
  ['screen-title', 'Título de pantalla', 'Categorías'],
  ['section-title', 'Título de sección', 'Compra por estilo'],
  ['product-name', 'Nombre de producto', 'Tabby Shoulder Bag 26'],
  ['account-row', 'Fila de cuenta', 'Mis pedidos'],
  ['body', 'Texto de lectura', 'Productos originales de las marcas que amas, importados de Estados Unidos.'],
  ['card-label', 'Etiqueta de tarjeta', 'Coach · Tabby 26 Negra'],
  ['price', 'Precio', '$6,299.00 MXN'],
  ['control', 'Control', 'Agregar a bolsa'],
  ['nav-label', 'Navegación', 'Inicio · Categorías · Carrito · Cuenta'],
];

function navSample(active) {
  const items = [
    ['home', 'Inicio'],
    ['grid', 'Catálogo'],
    ['bag', 'Carrito'],
    ['person', 'Cuenta'],
  ];
  return html`<div class="dock dock--static" role="group" aria-label="Muestra de navegación inferior"><div class="dock__bar">
    ${items.map(
      ([name, label], index) =>
        html`<span class="dock__item" ${index === active ? 'aria-current="page"' : ''}><span class="dock__icon">${icon(name, { size: 22 })}</span>${label}</span>`,
    )}
  </div></div>`;
}

export function designBoardPage() {
  const inStock = productByHandle('bolso-coach-shoulder-negro-rectangular');
  const sale = productByHandle('bolso-guess-crossbody-negro-1');
  const soldOut = productByHandle('bolsa-guess-shoulder-vino-brillante');
  const cards = [inStock, sale, soldOut].filter(Boolean);
  return {
    title: 'Tablero de componentes · Monetta',
    meta: { page: 'design-board', dock: 'nav', dockActive: null, nav: null },
    html: html`<div class="container board">
      <div class="page-head">
        <h1 class="display display--page" tabindex="-1">Tablero de componentes</h1>
        <p class="body-copy page-intro">Fundamentos de la guía de estilo, generados desde <code>design-system/monetta.tokens.json</code>. Los valores de color y tamaño de abajo se leen de los estilos aplicados en esta página.</p>
      </div>

      <section class="board-section" aria-labelledby="board-colors">
        <h2 class="board-title" id="board-colors">Color semántico</h2>
        <ul class="board-swatches" role="list" data-board-swatches>
          ${SWATCHES.map(
            ([token, label]) => html`<li class="board-swatch" data-token="${token}"><span class="board-swatch__chip" style="background:var(--color-${token})"></span><span class="board-swatch__name">--color-${token}</span><span class="board-swatch__label">${label}</span><span class="board-swatch__hex" data-hex></span></li>`,
          )}
        </ul>
      </section>

      <section class="board-section" aria-labelledby="board-type">
        <h2 class="board-title" id="board-type">Tipografía</h2>
        <ul class="board-roles" role="list" data-board-roles>
          ${ROLES.map(
            ([token, label, sample]) => html`<li class="board-role" data-role="${token}">
              <span class="board-role__meta"><strong>${label}</strong><span data-spec></span></span>
              <span class="board-role__sample" style="font-family:var(--type-${token}-font);font-weight:var(--type-${token}-weight);font-size:var(--type-${token}-size);line-height:var(--type-${token}-lh);letter-spacing:var(--type-${token}-track)">${sample}</span>
            </li>`,
          )}
        </ul>
      </section>

      <section class="board-section" aria-labelledby="board-buttons">
        <h2 class="board-title" id="board-buttons">Botones y controles</h2>
        <div class="board-row">
          <button type="button" class="btn btn--primary">Agregar a bolsa</button>
          <button type="button" class="btn btn--outline">Comprar ahora</button>
          <button type="button" class="btn btn--dark btn--sm">Compartir catálogo ${icon('chevronRight', { size: 18 })}</button>
          <button type="button" class="btn btn--quiet btn--sm">Guardar preferencias</button>
          <button type="button" class="btn btn--primary" disabled>No disponible</button>
        </div>
        <div class="board-row">
          <ul class="chips" role="list">
            <li><button type="button" class="chip" aria-pressed="true">Bolsas</button></li>
            <li><button type="button" class="chip" aria-pressed="false">Carteras</button></li>
            <li><button type="button" class="chip" aria-pressed="false">Relojes</button></li>
          </ul>
          <span class="badge badge--sale">-26%</span>
          <span class="badge badge--quiet">Sobre pedido</span>
          <span class="badge badge--seal">Agotado</span>
        </div>
        <div class="board-row board-row--field">
          <div class="search-field board-field">${icon('search', { size: 20 })}<label class="visually-hidden" for="board-search">Buscar</label><input id="board-search" type="search" placeholder="Bolsa Coach negra" autocomplete="off"></div>
        </div>
        <div class="board-row">
          <div class="option-row">
            <label class="option-chip"><input type="radio" name="board-o" checked class="visually-hidden"><span class="option-chip__check">${icon('check', { size: 16 })}</span>Negro</label>
            <label class="option-chip"><input type="radio" name="board-o" class="visually-hidden">Café</label>
            <label class="option-chip option-chip--soldout"><input type="radio" name="board-o" class="visually-hidden" disabled><span class="option-chip__label">Beige</span></label>
          </div>
        </div>
      </section>

      <section class="board-section" aria-labelledby="board-cards">
        <h2 class="board-title" id="board-cards">Tarjetas de producto</h2>
        <ul class="product-grid board-cards" role="list">${cards.map((product) => html`<li>${productCard(product, { quickAdd: false })}</li>`)}</ul>
      </section>

      <section class="board-section" aria-labelledby="board-nav">
        <h2 class="board-title" id="board-nav">Navegación inferior (teléfono)</h2>
        ${navSample(0)}
        <p class="small text-muted" style="margin-top:8px">Barra a ancho completo, plana, sobre el borde seguro. Activo: color de acento, peso 600 y una línea de 2 px.</p>
      </section>

      <section class="board-section" aria-labelledby="board-rows">
        <h2 class="board-title" id="board-rows">Filas, servicio y campaña</h2>
        <div class="board-split">
          <ul class="row-list" role="list">
            ${row({ iconName: 'box', label: 'Mis pedidos' })}
            ${row({ iconName: 'pin', label: 'Direcciones', hint: 'Se administran en Shopify' })}
          </ul>
          ${shareBanner()}
        </div>
        ${serviceStrip()}
      </section>
    </div>`,
    mount(root) {
      for (const item of root.querySelectorAll('[data-board-swatches] [data-token]')) {
        const chip = item.querySelector('.board-swatch__chip');
        const rgb = getComputedStyle(chip).backgroundColor.match(/[\d.]+/g).map(Number);
        const hex = `#${rgb.slice(0, 3).map((v) => Math.round(v).toString(16).padStart(2, '0')).join('')}${rgb[3] !== undefined && rgb[3] < 1 ? ` · ${Math.round(rgb[3] * 100)}%` : ''}`;
        item.querySelector('[data-hex]').textContent = hex.toUpperCase().replace('#', '#');
      }
      for (const item of root.querySelectorAll('[data-board-roles] [data-role]')) {
        const sample = getComputedStyle(item.querySelector('.board-role__sample'));
        const family = sample.fontFamily.split(',')[0].replace(/"/g, '');
        item.querySelector('[data-spec]').textContent = `${family} ${sample.fontWeight} · ${sample.fontSize} / ${Number.parseFloat(sample.lineHeight).toFixed(0)}px`;
      }
      return null;
    },
  };
}
