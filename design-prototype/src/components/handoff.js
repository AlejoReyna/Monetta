// Handoff dialogs. Wherever production leaves the theme (Shopify checkout,
// customer accounts, WhatsApp, external catalogs, social networks), the
// prototype explains the destination instead of imitating it.
import { APARTADO, EXTERNAL_CATALOGS, PARTNER, SOCIAL_LINKS } from '../data/content.js';
import { copyText } from '../lib/dom.js';
import { variantLabel } from '../lib/facets.js';
import { html } from '../lib/html.js';
import { icon } from '../lib/icons.js';
import { formatCents, formatMoney } from '../lib/money.js';
import { getState, resolveLine, totals } from '../lib/store.js';
import { nextOverlayId, openOverlay, overlayHeader } from './overlay.js';
import { toast } from './toast.js';

function dialog({ title, eyebrow = 'Prototipo · traspaso', body, footer, kind = 'dialog' }) {
  const titleId = nextOverlayId('handoff');
  return openOverlay({
    kind,
    labelledBy: titleId,
    content: html`${overlayHeader(titleId, title, { eyebrow })}
      <div class="overlay__body">${body}</div>
      <div class="overlay__footer">${footer ?? html`<button type="button" class="btn btn--primary btn--block" data-overlay-close>Entendido</button>`}</div>`,
    initialFocus: '.overlay__footer .btn',
  });
}

function bullets(items) {
  return html`<ul class="handoff-list">${items.map((item) => html`<li>${icon('check', { size: 18 })}<span>${item}</span></li>`)}</ul>`;
}

/** The checkout button: what Shopify would receive, and that nothing was sent. */
export function openCheckoutHandoff({ buyNow = false } = {}) {
  const { cart } = getState();
  const { count, subtotal } = totals();
  const lines = cart.map((line) => ({ line, found: resolveLine(line) })).filter((entry) => entry.found);
  dialog({
    title: 'Checkout seguro de Shopify',
    body: html`<p class="body-copy body-copy--ink">${
      buyNow ? 'Comprar ahora agrega la pieza y continúa directo al pago.' : 'Aquí termina el prototipo.'
    } En la tienda publicada, este botón envía el carrito a Shopify Checkout, donde se capturan la dirección, el envío, los impuestos, los descuentos automáticos y el pago.</p>
      ${bullets([
        'Shopify calcula envío, impuestos y descuentos de mayoreo con sus reglas reales.',
        'El pago y los datos de tarjeta los procesa Shopify; Monetta no los ve.',
        'La marca del checkout se configura en el editor de checkout de Shopify, no en el tema.',
      ])}
      <h3 class="summary__title" style="margin-top:20px">Se enviaría a Shopify</h3>
      <ul class="cart-lines" role="list">
        ${lines.map(
          ({ line, found }) => html`<li class="summary__row"><span>${line.quantity} × ${found.product.title}${
            found.variant.title ? html`<br><span class="small text-muted">${variantLabel(found.product, found.variant)} · variante ${found.variant.id}</span>` : html`<br><span class="small text-muted">Variante ${found.variant.id}</span>`
          }</span><span class="price">${formatMoney(found.variant.price)}</span></li>`,
        )}
      </ul>
      <dl><div class="summary__row summary__row--total"><dt>Subtotal (${count} ${count === 1 ? 'artículo' : 'artículos'})</dt><dd>${formatCents(subtotal, { code: true })}</dd></div></dl>
      <div class="notice" style="margin-top:16px">${icon('lock', { size: 18 })}<span>No se creó ningún pedido, no se reservó inventario y no se procesó ningún pago.</span></div>`,
    footer: html`<button type="button" class="btn btn--primary btn--block" data-overlay-close>Volver al carrito</button>`,
  });
}

export function openAccountHandoff(action = 'login') {
  const titles = {
    login: 'Acceso con cuentas de cliente de Shopify',
    orders: 'Mis pedidos',
    addresses: 'Direcciones',
  };
  dialog({
    title: titles[action] ?? titles.login,
    body: html`<p class="body-copy body-copy--ink">La tienda publicada usa las cuentas de cliente de Shopify: el acceso, los pedidos y las direcciones viven en páginas alojadas por Shopify con el logo y los colores configurados en su editor.</p>
      ${bullets([
        'Inicio de sesión con código enviado al correo, gestionado por Shopify.',
        'Pedidos y direcciones se consultan en la cuenta de Shopify.',
        'Este prototipo no implementa ni simula autenticación.',
      ])}`,
  });
}

export function openCatalogHandoff(catalogId) {
  const catalog = EXTERNAL_CATALOGS.find((entry) => entry.id === catalogId) ?? EXTERNAL_CATALOGS[0];
  dialog({
    title: `Catálogo de ${catalog.title.toLowerCase()}`,
    eyebrow: 'Catálogo externo',
    body: html`<p class="body-copy body-copy--ink">${catalog.note} Estas piezas todavía no se venden como productos de Shopify; la tienda publicada abre el catálogo en ${catalog.host} en una pestaña nueva.</p>
      ${bullets([
        'El botón se etiqueta como “Ver catálogo” para no confundirse con una colección comprable.',
        'El destino exacto se revisa antes de publicar: el menú y la portada actuales usan enlaces distintos.',
        'Para pedir, el cliente escribe por WhatsApp con el modelo elegido.',
      ])}`,
  });
}

export function openSocialHandoff(networkId) {
  const network = SOCIAL_LINKS.find((entry) => entry.id === networkId) ?? SOCIAL_LINKS[0];
  dialog({
    title: network.label,
    eyebrow: 'Enlace externo',
    body: html`<p class="body-copy body-copy--ink">En la tienda publicada se abre el perfil ${network.handle} de ${network.label} en una pestaña nueva. El prototipo no sale del sitio.</p>`,
  });
}

export function openCommunityHandoff(title) {
  const entry = PARTNER.community.find((item) => item.title === title) ?? PARTNER.community[0];
  dialog({
    title: entry.title,
    eyebrow: 'Enlace externo',
    body: html`<p class="body-copy body-copy--ink">${entry.body} En la tienda publicada el botón abre ${entry.host}. Unirse no aprueba un estatus de revendedor ni crea un pedido.</p>`,
  });
}

export function openPartnerCatalogHandoff(group, mode) {
  const entry = PARTNER.catalogs.find((item) => item.group === group && item.mode === mode) ?? PARTNER.catalogs[0];
  dialog({
    title: `${entry.group} · ${entry.mode}`,
    eyebrow: 'Catálogo para compartir',
    body: html`<p class="body-copy body-copy--ink">${entry.description} En la tienda publicada se abre el catálogo en ${entry.host}; los enlaces vigentes se toman del contenido editable de Mayoreo.</p>`,
  });
}

function whatsappDialog({ title, message, intro }) {
  dialog({
    title,
    eyebrow: 'WhatsApp · traspaso',
    body: html`<p class="body-copy body-copy--ink">${intro}</p>
      <p class="message-preview" aria-label="Mensaje que se prepararía">${message}</p>
      <p class="small text-muted" style="margin-top:12px">En el prototipo no se abre WhatsApp ni se envía ningún mensaje.</p>`,
    footer: html`<button type="button" class="btn btn--outline btn--block" data-copy-message>${icon('copy', { size: 18 })} Copiar mensaje</button>
      <button type="button" class="btn btn--primary btn--block" data-overlay-close>Cerrar</button>`,
  });
  document.querySelector('[data-copy-message]')?.addEventListener('click', async () => {
    const copied = await copyText(message);
    toast(copied ? 'Mensaje copiado.' : 'No pudimos copiar el mensaje; selecciónalo y cópialo manualmente.', { tone: copied ? 'default' : 'error' });
  });
}

export function openWhatsAppHandoff(topic = 'contacto', product) {
  const messages = {
    contacto: '¡Hola Monetta! Tengo una pregunta sobre un producto.',
    mayoreo: '¡Hola Monetta! Quiero vender por catálogo y cotizar un pedido de mayoreo.',
    disponibilidad: product ? `¡Hola Monetta! ¿Tendrán de nuevo esta pieza?\n\n*${product.title}*\nhttps://monetta.mx/products/${product.handle}` : '',
    producto: product ? `¡Hola Monetta! Tengo una pregunta sobre esta pieza:\n\n*${product.title}*\nhttps://monetta.mx/products/${product.handle}` : '',
  };
  whatsappDialog({
    title: 'Escribir por WhatsApp',
    intro: `En la tienda publicada se abre WhatsApp con el número ${APARTADO.whatsappDisplay} y este mensaje listo para revisar antes de enviarlo:`,
    message: messages[topic] || messages.contacto,
  });
}

/** Mirrors ApartadoRequest in lib/data/shopify/cart_attribution.dart. */
/** AttributionCodeGenerator: no vowels and no 0/O/1/I, so codes read cleanly. */
function attributionCode(seed = Date.now()) {
  const alphabet = '23456789BCDFGHJKLMNPQRSTVWXYZ';
  let value = Math.abs(seed);
  let code = 'MN-';
  for (let index = 0; index < 4; index += 1) {
    code += alphabet[value % alphabet.length];
    value = Math.floor(value / alphabet.length);
  }
  return code;
}

export function openApartadoHandoff(product, variant) {
  const code = attributionCode(Date.now() * 1000 + Math.floor(Math.random() * 1000));
  const option = variant?.title ? `\n${variantLabel(product, variant)}` : '';
  const message = `¡Hola Monetta! Quiero solicitar apartado de este producto:\n\n*${product.title}*${option}\nPrecio: ${formatMoney(variant.price, { code: true })}\nhttps://monetta.mx/products/${product.handle}\n\nEntiendo que el anticipo es de $${APARTADO.retailDeposit} MXN y que puedo liquidar en hasta ${APARTADO.days} días.\nSé que este mensaje no reserva inventario ni confirma el anticipo hasta que Monetta responda y registre el pedido.\n\nCódigo: ${code}`;
  whatsappDialog({
    title: 'Solicitar apartado',
    intro: `El apartado es una solicitud manual por WhatsApp: Monetta confirma disponibilidad, registra el anticipo y crea el pedido. Anticipo de referencia: $${APARTADO.retailDeposit} MXN menudeo o $${APARTADO.wholesaleDeposit} MXN mayoreo, con hasta ${APARTADO.days} días para liquidar. Enviar el mensaje no aparta la pieza ni cobra nada.`,
    message,
  });
}

export function openPolicyNotice() {
  dialog({
    title: 'Páginas de políticas',
    body: html`<p class="body-copy body-copy--ink">Shopify genera y aloja las políticas de la tienda. El tema solo enlaza a ellas.</p>`,
  });
}
