// Product page (product_screen.dart): contained gallery with thumbnails,
// brand / name / price, variant choice, availability, quantity, primary add,
// other ways to buy, accordions, reviews and recommendations.
import { addToCartFlow } from '../components/cart-ui.js';
import { openApartadoHandoff, openCheckoutHandoff, openWhatsAppHandoff } from '../components/handoff.js';
import { toast } from '../components/toast.js';
import { breadcrumbs, emptyState, favoriteButton, productCard, rail, sectionHeader, stars, stepper } from '../components/ui.js';
import { addButton, availabilityLine, errorSlot, optionSelector, priceBlock } from '../components/variant-ui.js';
import { FAQ, SERVICE_FACTS, TESTIMONIALS } from '../data/content.js';
import { moreFromBrand, productByHandle } from '../lib/catalog.js';
import { copyText, prefersReducedMotion } from '../lib/dom.js';
import { CATEGORY_LABELS, COLOR_LABELS, PATTERN_LABELS, SILHOUETTE_LABELS, defaultVariant } from '../lib/facets.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { updateUrl } from '../lib/router.js';
import { recentlyViewed, recordView } from '../lib/store.js';
import { bindRails } from './page-behaviors.js';

const CATEGORY_COLLECTION = {
  bolsa: { handle: 'guess', label: 'Bolsas' },
  cartera: { handle: 'carteras-1', label: 'Carteras' },
  reloj: { handle: 'relojes', label: 'Relojes' },
};

const BRAND_COLLECTION = {
  coach: 'coach',
  michael_kors: 'michael-kors',
  guess: 'guess-1',
  steve_madden: 'steve-madden',
  tommy_hilfiger: 'tommy-hilfiger',
};

function brandHref(product) {
  const handle = BRAND_COLLECTION[product.brand];
  return handle ? `/collections/${handle}` : `/collections/all?filter.p.m.custom.marca=${encodeURIComponent(product.brandLabel)}`;
}

function detailsRows(product) {
  const rows = [...product.description.facts.filter((fact) => fact.label !== 'Marca')];
  const known = new Set(rows.map((row) => row.label));
  rows.unshift({ label: 'Marca', value: product.brandLabel });
  if (!known.has('Tipo')) rows.push({ label: 'Tipo', value: CATEGORY_LABELS[product.category] + (product.silhouette ? ` ${SILHOUETTE_LABELS[product.silhouette].toLowerCase()}` : '') });
  if (product.variants.length > 1) {
    rows.push({ label: `${product.options[0]?.name ?? 'Opción'} (${product.variants.length})`, value: product.variants.map((variant) => variant.title).join(' · ') });
  } else if (!known.has('Color') && product.colors.length) {
    rows.push({ label: 'Color', value: product.colors.map((slug) => COLOR_LABELS[slug]).join(', ') });
  }
  if (product.patterns.length) rows.push({ label: 'Motivo', value: product.patterns.map((slug) => PATTERN_LABELS[slug]).join(', ') });
  return rows;
}

function descriptionText(product) {
  if (product.description.paragraphs.length) return product.description.paragraphs;
  // product_screen.dart factualDescription(): one conservative sentence from facts.
  const style = product.silhouette ? ` estilo ${SILHOUETTE_LABELS[product.silhouette].toLowerCase()}` : '';
  // A colour only describes a single-variant piece; variants carry their own.
  const color =
    product.variants.length > 1
      ? ` disponible en ${product.variants.length} opciones`
      : product.colors.length
        ? ` en color ${COLOR_LABELS[product.colors[0]].toLowerCase()}`
        : '';
  return [`${CATEGORY_LABELS[product.category]} ${product.brandLabel}${style}${color}. Producto original importado de Estados Unidos.`];
}

function panelDynamic(product, selected, quantity) {
  const max = selected?.inventoryLimit ?? 99;
  const available = selected?.available;
  return html`
    ${priceBlock(product, selected, { idPrefix: 'product' })}
    <p class="product-panel__tax">El envío y los descuentos se calculan en el checkout.</p>
    ${availabilityLine(product, selected)}
    ${
      product.synthetic
        ? html`<p class="notice" style="margin-top:12px">${icon('info', { size: 18 })}<span><strong>Estado de demostración.</strong> ${product.synthetic.note}</span></p>`
        : ''
    }
    <div class="product-panel__options">${optionSelector(product, selected, { name: `variant-${product.id}` })}</div>
    <div class="product-panel__buy">
      ${
        available
          ? html`<div class="buy-row">
              <div class="field">
                <span class="field__label" id="qty-label">Cantidad</span>
                ${stepper({ value: quantity, min: 1, max, decreaseLabel: 'Quitar una pieza', increaseLabel: 'Agregar una pieza', id: 'product-qty', attrs: 'data-qty aria-labelledby="qty-label"' })}
              </div>
              <div class="buy-inline" style="flex:1;align-self:end">${addButton(product, selected, { className: 'btn btn--primary btn--block', id: 'add-inline' })}</div>
            </div>
            ${selected.inventoryLimit ? html`<p class="small text-muted">Quedan ${selected.inventoryLimit} piezas de esta opción en la muestra.</p>` : ''}`
          : html`<div class="buy-inline">${addButton(product, selected, { className: 'btn btn--primary btn--block', id: 'add-inline' })}</div>`
      }
      ${errorSlot('add-error')}
    </div>
    <div class="other-ways">
      <h2 class="other-ways__title">Otras formas de comprar</h2>
      ${available ? html`<button type="button" class="btn btn--outline btn--block" data-buy-now>Comprar ahora</button>` : ''}
      <div class="other-ways__apartado">
        <strong>${available ? 'Apartar por WhatsApp' : 'Preguntar por disponibilidad'}</strong>
        <span class="text-muted">${
          available
            ? 'Solicitud manual con anticipo. Enviar el mensaje no aparta la pieza ni cobra nada.'
            : 'Te confirmamos por WhatsApp si la pieza volverá o si hay una alternativa.'
        }</span>
        <button type="button" class="btn btn--text" style="justify-self:start;padding:0" data-apartado>${available ? 'Solicitar apartado' : 'Preguntar por WhatsApp'} ${icon('arrowForward', { size: 18 })}</button>
      </div>
    </div>`;
}

export function productPage({ params, url }) {
  const product = productByHandle(params.handle);
  if (!product) return productUnavailablePage(params.handle);
  const requested = Number(url.searchParams.get('variant'));
  let selected = product.variants.find((variant) => variant.id === requested) ?? defaultVariant(product);
  let quantity = 1;
  const category = CATEGORY_COLLECTION[product.category] ?? { handle: 'all', label: 'Catálogo' };
  const related = moreFromBrand(product);
  const images = product.images;
  const crumbs = [
    { label: 'Inicio', href: '/' },
    { label: category.label, href: `/collections/${category.handle}` },
    { label: product.title, href: '#' },
  ];

  const gallery = html`<section class="gallery" aria-label="Fotos de ${product.title}">
    <div class="gallery__main">
      <div class="gallery__track" data-gallery tabindex="0" role="group" aria-roledescription="carrusel" aria-label="Galería: usa las flechas para cambiar de foto">
        ${images.map(
          (src, index) => html`<figure class="gallery__slide" id="slide-${index}" aria-label="Foto ${index + 1} de ${images.length}">
            <img src="${src}" alt="${product.title}, foto ${index + 1} de ${images.length}" width="800" height="1067" ${index === 0 ? html`fetchpriority="high"` : html`loading="lazy"`} decoding="async">
          </figure>`,
        )}
      </div>
      <div class="gallery__seal" data-seal ${selected.available ? 'hidden' : ''}><span class="badge badge--seal">Agotado</span></div>
      <div class="gallery__tools">
        ${favoriteButton(product, { round: true, size: 19 })}
        <button type="button" class="round-button" data-share aria-label="Compartir ${product.title}"><span class="round-button__circle">${icon('share', { size: 19 })}</span></button>
      </div>
      ${images.length > 1 ? html`<div class="gallery__rules" aria-hidden="true">${images.map((_, index) => html`<span data-active="${String(index === (selected.image ?? 0))}"></span>`)}</div>` : ''}
    </div>
    ${
      images.length > 1
        ? html`<div class="gallery__thumbs" role="group" aria-label="Miniaturas">
            ${images.map(
              (src, index) => html`<button type="button" class="thumb" data-thumb="${index}" aria-label="Ver foto ${index + 1} de ${images.length}" aria-current="${String(index === (selected.image ?? 0))}"><img src="${src}" alt="" width="72" height="96" loading="lazy"></button>`,
            )}
          </div>`
        : ''
    }
  </section>`;

  const recent = recentlyViewed(product.handle).slice(0, 8);

  return {
    title: `${product.title} · Monetta`,
    meta: { page: 'product', dock: 'purchase', dockActive: null, nav: CATEGORY_COLLECTION[product.category] ? { bolsa: 'bolsas', cartera: 'carteras', reloj: 'relojes' }[product.category] : null, back: `/collections/${category.handle}` },
    html: html`<article class="product-page" data-product-page>
        <div class="container product-breadcrumbs">${breadcrumbs(crumbs)}</div>
        <div class="product-layout">
          ${gallery}
          <div class="product-panel container-phone" data-panel>
            <a class="eyebrow eyebrow--muted product-panel__brand" href="${brandHref(product)}" style="text-decoration:none">${product.brandLabel}</a>
            <h1 class="product-panel__name" tabindex="-1">${product.title}</h1>
            <div data-dynamic>${panelDynamic(product, selected, quantity)}</div>
            <ul class="service-rows" role="list">
              <li>${icon('truck', { size: 20 })}<span>${SERVICE_FACTS.shipping}</span></li>
              <li>${icon('refresh', { size: 20 })}<span>${SERVICE_FACTS.returns}</span></li>
              <li>${icon('check', { size: 20 })}<span>${SERVICE_FACTS.original}</span></li>
            </ul>
            <div class="product-panel__accordions">
              <details class="accordion" open>
                <summary>Descripción${icon('expand', { size: 20 })}</summary>
                <div class="accordion__body">${descriptionText(product).map((paragraph) => html`<p>${paragraph}</p>`)}</div>
              </details>
              <details class="accordion">
                <summary>Detalles${icon('expand', { size: 20 })}</summary>
                <div class="accordion__body"><dl class="facts">${detailsRows(product).map((row) => html`<div><dt>${row.label}</dt><dd>${row.value}</dd></div>`)}</dl></div>
              </details>
              <details class="accordion">
                <summary>Envíos y cambios${icon('expand', { size: 20 })}</summary>
                <div class="accordion__body">
                  <p>${FAQ[3].answer}</p>
                  <p style="margin-top:10px">${FAQ[4].answer}</p>
                  ${product.flags.sobrePedido ? html`<p style="margin-top:10px">${FAQ[5].answer}</p>` : ''}
                </div>
              </details>
            </div>
            <button type="button" class="whatsapp-link" data-handoff="whatsapp" data-topic="producto" data-handle="${product.handle}">${icon('chat', { size: 18 })} Escribir por WhatsApp</button>
          </div>
        </div>

        <section class="section container" aria-labelledby="product-reviews">
          <h2 class="product-section-title" id="product-reviews" style="margin-bottom:12px">Reseñas</h2>
          <div class="reviews-block">
            <div class="reviews-block__summary">
              <p class="eyebrow">Integración Loox</p>
              <p class="body-copy body-copy--ink">En la tienda, el bloque de Loox muestra aquí las reseñas y fotos de esta pieza. El prototipo usa opiniones de muestra de la tienda.</p>
            </div>
            ${rail(
              'rail-reviews',
              TESTIMONIALS.map(
                (review) => html`<figure class="review-card"><div class="review-card__body">${stars(review.rating)}<blockquote class="review-card__text">“${review.body}”</blockquote><figcaption class="review-card__name">${review.reviewer} · muestra</figcaption></div></figure>`,
              ),
              { label: 'Opiniones de muestra', className: 'reviews-rail', focusable: true },
            )}
          </div>
        </section>

        ${
          related.length
            ? html`<section class="section container" aria-labelledby="product-more">
                ${sectionHeader({ id: 'product-more', title: `Más de ${product.brandLabel}`, action: { href: brandHref(product), label: 'Ver todo' }, railId: 'rail-more', role: 'product' })}
                ${rail('rail-more', related.map((item) => productCard(item, { flush: true })), { label: `Más de ${product.brandLabel}`, className: 'rail--recs' })}
              </section>`
            : ''
        }
        ${
          recent.length
            ? html`<section class="section container" aria-labelledby="product-recent">
                ${sectionHeader({ id: 'product-recent', title: 'Vistas hace un momento', railId: 'rail-recent', role: 'product' })}
                ${rail('rail-recent', recent.map((item) => productCard(item, { flush: true })), { label: 'Vistas hace un momento', className: 'rail--recs' })}
              </section>`
            : ''
        }
      </article>
      <div class="purchase-dock" data-purchase-dock>${addButton(product, selected, { className: 'btn btn--primary', id: 'add-dock' })}</div>`,
    mount(root) {
      recordView(product.handle);
      const track = root.querySelector('[data-gallery]');
      const thumbs = [...root.querySelectorAll('[data-thumb]')];
      const rules = [...root.querySelectorAll('.gallery__rules span')];
      const dynamic = root.querySelector('[data-dynamic]');
      const dock = document.querySelector('[data-purchase-dock]');
      const behavior = () => (prefersReducedMotion() ? 'auto' : 'smooth');

      let current = selected.image ?? 0;
      const markSlide = (index) => {
        current = index;
        thumbs.forEach((thumb, i) => thumb.setAttribute('aria-current', String(i === index)));
        rules.forEach((rule, i) => (rule.dataset.active = String(i === index)));
      };
      const goTo = (index, smooth = true) => {
        const clamped = Math.max(0, Math.min(images.length - 1, index));
        track.scrollTo({ left: clamped * track.clientWidth, behavior: smooth ? behavior() : 'auto' });
        markSlide(clamped);
      };
      const resnap = new ResizeObserver(() => {
        track.scrollTo({ left: current * track.clientWidth, behavior: 'auto' });
      });
      resnap.observe(track);
      let scrollTimer = 0;
      track.addEventListener(
        'scroll',
        () => {
          clearTimeout(scrollTimer);
          scrollTimer = setTimeout(() => markSlide(Math.round(track.scrollLeft / Math.max(1, track.clientWidth))), 60);
        },
        { passive: true },
      );
      track.addEventListener('keydown', (event) => {
        const current = Math.round(track.scrollLeft / Math.max(1, track.clientWidth));
        if (event.key === 'ArrowRight') {
          event.preventDefault();
          goTo(current + 1);
        } else if (event.key === 'ArrowLeft') {
          event.preventDefault();
          goTo(current - 1);
        }
      });
      thumbs.forEach((thumb) => thumb.addEventListener('click', () => goTo(Number(thumb.dataset.thumb))));
      if (selected.image) requestAnimationFrame(() => goTo(selected.image, false));

      const refresh = () => {
        const focusedId = document.activeElement?.id;
        const focusedValue = document.activeElement?.name === `variant-${product.id}` ? document.activeElement.value : null;
        dynamic.innerHTML = String(panelDynamic(product, selected, quantity));
        dock.innerHTML = String(addButton(product, selected, { className: 'btn btn--primary', id: 'add-dock' }));
        root.querySelector('[data-seal]').hidden = selected.available;
        if (focusedValue) dynamic.querySelector(`input[value="${focusedValue}"]`)?.focus({ preventScroll: true });
        else if (focusedId) document.getElementById(focusedId)?.focus({ preventScroll: true });
      };

      const onChange = (event) => {
        if (event.target.name !== `variant-${product.id}`) return;
        selected = product.variants.find((variant) => String(variant.id) === event.target.value) ?? selected;
        quantity = Math.min(quantity, selected.inventoryLimit ?? 99);
        updateUrl(`/products/${product.handle}?variant=${selected.id}`);
        refresh();
        goTo(selected.image ?? 0);
      };

      const add = (button) => {
        if (button.dataset.pending || !selected?.available) return;
        addToCartFlow({ product, variant: selected, quantity, button, errorEl: root.querySelector('[data-add-error]') });
      };

      const onClick = async (event) => {
        const target = event.target;
        const step = target.closest('[data-qty] [data-step]');
        if (step) {
          quantity = Math.max(1, Math.min(selected.inventoryLimit ?? 99, quantity + Number(step.dataset.step)));
          refresh();
          return;
        }
        const addBtn = target.closest('[data-add]');
        if (addBtn) {
          add(addBtn);
          return;
        }
        if (target.closest('[data-buy-now]')) {
          const button = target.closest('[data-buy-now]');
          if (button.dataset.pending) return;
          await addToCartFlow({
            product,
            variant: selected,
            quantity,
            button,
            errorEl: root.querySelector('[data-add-error]'),
            onAdded: () => openCheckoutHandoff({ buyNow: true }),
          });
          return;
        }
        if (target.closest('[data-apartado]')) {
          if (selected.available) openApartadoHandoff(product, selected);
          else openWhatsAppHandoff('disponibilidad', product);
          return;
        }
        if (target.closest('[data-share]')) {
          const copied = await copyText(`${location.origin}/products/${product.handle}?variant=${selected.id}`);
          toast(copied ? 'Enlace de la pieza copiado.' : 'No pudimos copiar el enlace en este navegador.', { tone: copied ? 'default' : 'error' });
        }
      };

      root.addEventListener('change', onChange);
      root.addEventListener('click', onClick);
      dock.addEventListener('click', onClick);
      const unbindRails = bindRails(root);
      return () => {
        resnap.disconnect();
        root.removeEventListener('change', onChange);
        root.removeEventListener('click', onClick);
        dock.removeEventListener('click', onClick);
        unbindRails();
      };
    },
  };
}

function productUnavailablePage(handle) {
  return {
    title: 'Pieza no disponible · Monetta',
    meta: { page: 'product-missing', dock: 'nav', dockActive: 'catalog', nav: null },
    html: html`<div class="container">${emptyState({
      title: 'Esta pieza ya no está disponible',
      level: 1,
      body: `No encontramos “${handle}” en la muestra del catálogo. Puede haberse vendido o retirado.`,
      mark: 'bag',
      actions: [html`<a class="btn btn--primary" href="/collections/all?sort_by=created-descending">Ver novedades</a>`, html`<a class="btn btn--outline" href="/search">Buscar otra pieza</a>`],
    })}</div>`,
  };
}
