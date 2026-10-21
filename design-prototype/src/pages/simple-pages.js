// Supporting views: favourites, wholesale, story, contact, account entry,
// policies and not-found.
import { openAccountHandoff } from '../components/handoff.js';
import { emptyState, productCard, rail, sectionHeader } from '../components/ui.js';
import { ABOUT, CONTACT, FAQ, PARTNER, SOCIAL_LINKS } from '../data/content.js';
import { newestProducts } from '../lib/catalog.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { plural } from '../lib/money.js';
import { favoriteEntries, isStoragePersistent, subscribe, toggleFavorite } from '../lib/store.js';
import { bindRails } from './page-behaviors.js';

function faqList(items, { open = 0 } = {}) {
  return html`<div>${items.map(
    (item, index) => html`<details class="accordion" ${index < open ? 'open' : ''}>
      <summary>${item.question}${icon('expand', { size: 20 })}</summary>
      <div class="accordion__body"><p>${item.answer}</p></div>
    </details>`,
  )}</div>`;
}

/* ------------------------------------------------------------ Favoritos */
function favoritesContent() {
  const entries = favoriteEntries();
  const available = entries.filter((entry) => entry.product);
  const missing = entries.filter((entry) => !entry.product);
  const persistent = isStoragePersistent();
  const scope = persistent
    ? 'Tus favoritos se guardan solo en este dispositivo y navegador. Para verlos en otro dispositivo hará falta una función de cuenta que todavía no existe.'
    : 'Este navegador no permite guardar datos del sitio: tus favoritos se perderán al cerrar o recargar la pestaña.';
  return html`
    <p class="notice${persistent ? '' : ' notice--error'}" style="margin-top:16px">${icon(persistent ? 'info' : 'error', { size: 18 })}<span>${scope}</span></p>
    ${missing.map(
      (entry) => html`<div class="unavailable-row" style="margin-top:16px"><span>Una pieza que guardaste ya no está disponible en el catálogo.</span><button type="button" class="btn btn--text" data-remove-missing="${entry.handle}">Quitar</button></div>`,
    )}
    ${
      available.length
        ? html`<ul class="product-grid product-grid--wide" role="list" style="margin-top:24px">${available.map((entry) => html`<li>${productCard(entry.product)}</li>`)}</ul>`
        : emptyState({
            title: 'Aún no tienes favoritos',
            body: 'Toca el corazón de cualquier pieza para guardarla aquí.',
            mark: 'heart',
            actions: [html`<a class="btn btn--primary" href="/collections/all?sort_by=created-descending">Explorar novedades</a>`],
          })
    }`;
}

export function favoritesPage() {
  const count = favoriteEntries().filter((entry) => entry.product).length;
  return {
    title: 'Favoritos · Monetta',
    meta: { page: 'favorites', dock: 'nav', dockActive: null, nav: null },
    html: html`<div class="container">
      <div class="page-head">
        <div class="page-head__row">
          <h1 class="display display--page" tabindex="-1">Favoritos</h1>
          <p class="page-head__count" data-fav-count>${plural(count, 'pieza guardada', 'piezas guardadas')}</p>
        </div>
      </div>
      <div data-favorites>${favoritesContent()}</div>
    </div>`,
    mount(root) {
      const container = root.querySelector('[data-favorites]');
      const onClick = (event) => {
        const missing = event.target.closest('[data-remove-missing]');
        if (missing) toggleFavorite(missing.dataset.removeMissing);
      };
      root.addEventListener('click', onClick);
      const unsubscribe = subscribe((state, change) => {
        if (!['favorites', 'reset', 'demo'].includes(change.type)) return;
        const focusedHandle = document.activeElement?.dataset?.handle;
        container.innerHTML = String(favoritesContent());
        root.querySelector('[data-fav-count]').textContent = plural(
          favoriteEntries().filter((entry) => entry.product).length,
          'pieza guardada',
          'piezas guardadas',
        );
        const next = focusedHandle && container.querySelector(`[data-action="favorite"][data-handle="${focusedHandle}"]`);
        (next || root.querySelector('h1'))?.focus({ preventScroll: true });
      });
      return () => {
        unsubscribe();
        root.removeEventListener('click', onClick);
      };
    },
  };
}

/* -------------------------------------------------------------- Mayoreo */
export function mayoreoPage() {
  const groups = [...new Set(PARTNER.catalogs.map((catalog) => catalog.group))];
  return {
    title: 'Vende con Monetta · Mayoreo',
    meta: { page: 'mayoreo', dock: 'nav', dockActive: null, nav: 'mayoreo' },
    html: html`<div class="container">
      <section class="editorial-hero" aria-labelledby="mayoreo-title">
        <div class="editorial-hero__media"><img src="/media/editorial/home_collection_bags.webp" alt="Clienta con bolsas Coach, Michael Kors, Guess y Steve Madden" width="800" height="930" style="object-position:50% 40%"></div>
        <div class="editorial-hero__copy">
          <p class="eyebrow">${PARTNER.eyebrow}</p>
          <h1 class="display display--page" id="mayoreo-title" tabindex="-1">${PARTNER.headline}</h1>
          <p class="body-copy">${PARTNER.body}</p>
          <div class="editorial-hero__actions">
            <button type="button" class="btn btn--primary" data-handoff="whatsapp" data-topic="mayoreo">${icon('chat', { size: 18 })} Quiero vender</button>
            <a class="btn btn--outline" href="#catalogos">Ver catálogos</a>
          </div>
          <p class="eyebrow eyebrow--muted">${PARTNER.note}</p>
        </div>
      </section>

      <section class="section panel panel--accent" aria-labelledby="mayoreo-descuentos">
        <p class="eyebrow">Descuentos de mayoreo</p>
        <h2 class="display display--section" id="mayoreo-descuentos" style="margin-top:8px">${PARTNER.discountTitle}</h2>
        <p class="body-copy" style="margin-top:12px;max-width:62ch">${PARTNER.discountBody}</p>
      </section>

      <section class="section" aria-labelledby="mayoreo-pasos">
        ${sectionHeader({ id: 'mayoreo-pasos', kicker: 'Cómo vender por catálogo', title: 'Tu negocio, paso a paso' })}
        <ol class="steps" role="list">
          ${PARTNER.steps.map((step) => html`<li class="step"><span class="step__number" aria-hidden="true">${step.number}</span><h3 class="step__title">${step.title}</h3><p class="body-copy">${step.body}</p></li>`)}
        </ol>
      </section>

      <section class="section" aria-labelledby="mayoreo-terminos">
        <h2 class="visually-hidden" id="mayoreo-terminos">Términos de mayoreo</h2>
        <dl class="terms">${PARTNER.terms.map((term) => html`<div class="term"><dt>${term.label}</dt><dd>${term.value}</dd></div>`)}</dl>
        <p class="small text-muted" style="margin-top:10px">Anticipo de apartado al menudeo: $400 MXN. Montos tomados de la página de mayoreo vigente; Monetta los confirma en cada pedido.</p>
      </section>

      <section class="section" id="catalogos" aria-labelledby="mayoreo-catalogos">
        ${sectionHeader({ id: 'mayoreo-catalogos', kicker: 'Catálogos para compartir', title: 'Elige cómo quieres vender' })}
        ${groups.map(
          (group) => html`<h3 class="title-sans" style="font-size:17px;margin:20px 0 10px">${group}</h3>
            <ul class="catalog-list" role="list">
              ${PARTNER.catalogs
                .filter((catalog) => catalog.group === group)
                .map(
                  (catalog) => html`<li class="catalog-item">
                    <span class="catalog-item__text"><span class="catalog-item__title">${catalog.mode}</span><span class="catalog-item__desc">${catalog.description}</span></span>
                    <button type="button" class="btn btn--outline btn--sm" data-handoff="partner-catalog" data-group="${catalog.group}" data-mode="${catalog.mode}">Ver catálogo ${icon('northEast', { size: 16 })}</button>
                  </li>`,
                )}
            </ul>`,
        )}
      </section>

      <section class="section two-col" aria-labelledby="mayoreo-faq">
        <div>
          <p class="eyebrow">Todo lo que necesitas saber</p>
          <h2 class="display display--section" id="mayoreo-faq" style="margin-top:6px">Preguntas frecuentes</h2>
          <p class="body-copy" style="margin-top:12px">¿Tienes otra duda? Escríbenos por WhatsApp al ${CONTACT.whatsappDisplay}.</p>
          <button type="button" class="btn btn--outline" style="margin-top:16px" data-handoff="whatsapp" data-topic="mayoreo">${icon('chat', { size: 18 })} Escribir por WhatsApp</button>
        </div>
        ${faqList(FAQ, { open: 1 })}
      </section>

      <section class="section" aria-labelledby="mayoreo-comunidad">
        ${sectionHeader({ id: 'mayoreo-comunidad', kicker: 'Grupos de Monetta', title: 'Únete a la comunidad' })}
        <ul class="account-grid" role="list" style="margin-top:0">
          ${PARTNER.community.map(
            (entry) => html`<li><button type="button" class="account-tile" style="width:100%" data-handoff="community" data-title="${entry.title}">
              <span class="account-tile__title">${entry.title} ${icon('northEast', { size: 18 })}</span>
              <p>${entry.body}</p>
            </button></li>`,
          )}
        </ul>
      </section>
    </div>`,
  };
}

/* ------------------------------------------------------- Nuestra historia */
export function storyPage() {
  return {
    title: 'Nuestra historia · Monetta',
    meta: { page: 'story', dock: 'nav', dockActive: null, nav: 'historia' },
    html: html`<div class="container">
      <section class="editorial-hero" aria-labelledby="story-title">
        <div class="editorial-hero__media"><img src="${ABOUT.image}" alt="Fundadora de Monetta con bolsas y carteras en la boutique" width="1200" height="900"></div>
        <div class="editorial-hero__copy">
          <p class="eyebrow">Más sobre Monetta</p>
          <h1 class="display display--page" id="story-title" tabindex="-1">${ABOUT.headline}</h1>
          <p class="body-copy">${ABOUT.body}</p>
          <div class="editorial-hero__actions">
            <a class="btn btn--primary" href="/collections/all">Ver catálogo</a>
            <a class="btn btn--outline" href="/pages/mayoreo">Vende con Monetta</a>
          </div>
        </div>
      </section>
      <section class="section two-col" aria-labelledby="story-timeline">
        <div>
          <p class="eyebrow">Nuestra historia</p>
          <h2 class="display display--section" id="story-timeline" style="margin:6px 0 24px">De Montemorelos a todo México</h2>
          <ol class="timeline" role="list">
            ${ABOUT.milestones.map((item) => html`<li><span class="timeline__year">${item.year}</span><h3 class="timeline__title">${item.title}</h3><p class="body-copy">${item.body}</p></li>`)}
          </ol>
        </div>
        <div>
          <h2 class="display display--section" style="margin-bottom:16px">Por qué elegirnos</h2>
          <ul class="trust-list" role="list">${ABOUT.trustFacts.map((fact) => html`<li>${icon('check', { size: 20 })}<span>${fact}</span></li>`)}</ul>
          <div class="panel" style="margin-top:24px">
            <h3 class="title-sans" style="font-size:17px">¿Buscas un modelo en especial?</h3>
            <p class="body-copy" style="margin-top:8px">Escríbenos y te ayudamos a encontrarlo.</p>
            <a class="btn btn--outline" href="/pages/contact" style="margin-top:14px">Contacto</a>
          </div>
        </div>
      </section>
    </div>`,
  };
}

/* -------------------------------------------------------------- Contacto */
export function contactPage() {
  return {
    title: 'Contacto · Monetta',
    meta: { page: 'contact', dock: 'nav', dockActive: null, nav: null },
    html: html`<div class="container">
      <div class="page-head">
        <p class="eyebrow">${CONTACT.eyebrow}</p>
        <h1 class="display display--page" tabindex="-1">Contáctanos</h1>
        <p class="body-copy page-intro">${CONTACT.body}</p>
      </div>
      <section class="section two-col" aria-label="Formas de contacto" style="margin-top:24px">
        <div class="panel">
          <h2 class="title-sans" style="font-size:19px">${CONTACT.headline}</h2>
          <p class="body-copy" style="margin-top:8px">Atención personalizada por WhatsApp al ${CONTACT.whatsappDisplay}.</p>
          <button type="button" class="btn btn--primary" style="margin-top:16px" data-handoff="whatsapp" data-topic="contacto">${icon('chat', { size: 18 })} Contactar por WhatsApp</button>
          <h2 class="title-sans" style="font-size:17px;margin-top:28px">Nuestras redes</h2>
          <ul class="chips" role="list" style="margin-top:12px">
            ${SOCIAL_LINKS.map((link) => html`<li><button type="button" class="chip" data-handoff="social" data-network="${link.id}">${link.label} ${icon('northEast', { size: 14 })}</button></li>`)}
          </ul>
        </div>
        <div>
          <h2 class="display display--section" style="margin-bottom:12px">Preguntas frecuentes</h2>
          ${faqList(FAQ, { open: 0 })}
        </div>
      </section>
    </div>`,
  };
}

/* ----------------------------------------------------------------- Cuenta */
export function accountPage() {
  return {
    title: 'Mi cuenta · Monetta',
    meta: { page: 'account', dock: 'nav', dockActive: 'account', nav: null },
    html: html`<div class="container">
      <div class="page-head">
        <h1 class="display display--page" tabindex="-1">Mi cuenta</h1>
        <p class="body-copy page-intro">Inicia sesión para ver tus pedidos y comprar más rápido. El acceso lo gestiona Shopify de forma segura.</p>
      </div>
      <div style="margin-top:20px;display:flex;flex-wrap:wrap;gap:12px">
        <button type="button" class="btn btn--primary" data-account="login">${icon('login', { size: 20 })} Iniciar sesión o crear cuenta</button>
      </div>
      <ul class="account-grid" role="list">
        <li><button type="button" class="account-tile" style="width:100%" data-account="orders"><span class="account-tile__title">Mis pedidos ${icon('chevronRight', { size: 20 })}</span><p>Estado y detalle de tus compras en la cuenta de Shopify.</p></button></li>
        <li><a class="account-tile" href="/pages/favoritos"><span class="account-tile__title">Favoritos ${icon('chevronRight', { size: 20 })}</span><p>Piezas guardadas en este dispositivo.</p></a></li>
        <li><button type="button" class="account-tile" style="width:100%" data-account="addresses"><span class="account-tile__title">Direcciones ${icon('chevronRight', { size: 20 })}</span><p>Se administran en la cuenta de Shopify y se usan en el checkout.</p></button></li>
      </ul>
      <p class="notice" style="margin-top:24px">${icon('info', { size: 18 })}<span>Prototipo: estas opciones explican el traspaso a las cuentas de cliente de Shopify. No hay inicio de sesión real.</span></p>
    </div>`,
    mount(root) {
      const onClick = (event) => {
        const button = event.target.closest('[data-account]');
        if (button) openAccountHandoff(button.dataset.account);
      };
      root.addEventListener('click', onClick);
      return () => root.removeEventListener('click', onClick);
    },
  };
}

/* --------------------------------------------------------------- Policies */
const POLICIES = {
  'shipping-policy': { title: 'Política de envíos', body: [FAQ[3].answer, FAQ[5].answer] },
  'refund-policy': { title: 'Cambios y devoluciones', body: [FAQ[4].answer] },
  'privacy-policy': { title: 'Aviso de privacidad', body: ['El texto legal vigente lo publica Shopify en esta misma dirección.'] },
  'terms-of-service': { title: 'Términos del servicio', body: ['El texto legal vigente lo publica Shopify en esta misma dirección.'] },
};

export function policyPage({ params }) {
  const policy = POLICIES[params.handle];
  if (!policy) return notFoundPage();
  return {
    title: `${policy.title} · Monetta`,
    meta: { page: 'policy', dock: 'nav', dockActive: null, nav: null },
    html: html`<div class="container">
      <div class="page-head"><h1 class="display display--page" tabindex="-1">${policy.title}</h1></div>
      <div class="policy-body">
        ${policy.body.map((paragraph) => html`<p class="body-copy body-copy--ink">${paragraph}</p>`)}
        <p class="notice">${icon('info', { size: 18 })}<span>Página alojada por Shopify en /policies/${params.handle}. El rediseño conserva la URL y solo cambia los enlaces del tema. Resumen tomado de las preguntas frecuentes vigentes.</span></p>
      </div>
    </div>`,
  };
}

/* -------------------------------------------------------------- Not found */
export function notFoundPage() {
  return {
    title: 'Página no encontrada · Monetta',
    meta: { page: 'not-found', dock: 'nav', dockActive: null, nav: null },
    html: html`<div class="container">
      ${emptyState({
        title: 'No encontramos esta página',
        level: 1,
        body: 'Puede que el enlace haya cambiado. Estas secciones te pueden ayudar.',
        mark: 'search',
        actions: [html`<a class="btn btn--primary" href="/">Ir al inicio</a>`, html`<a class="btn btn--outline" href="/collections/all">Ver catálogo</a>`],
      })}
      <section class="section" aria-labelledby="nf-novedades">
        ${sectionHeader({ id: 'nf-novedades', title: 'Novedades', railId: 'rail-nf' })}
        ${rail('rail-nf', newestProducts(8).map((product) => productCard(product, { density: 'compact' })), { label: 'Novedades' })}
      </section>
    </div>`,
    mount: (root) => bindRails(root),
  };
}
