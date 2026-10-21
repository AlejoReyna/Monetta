// "Detalles" panel behind the prototype strip: what is demo data, switches
// for failure states, a guided list of review states and a reset.
import { catalog } from '../lib/catalog.js';
import { html } from '../lib/html.js';
import { navigate } from '../lib/router.js';
import { icon } from '../lib/icons.js';
import { addUnavailableFavorite, getState, isStoragePersistent, resetDemoState, setDemo } from '../lib/store.js';
import { nextOverlayId, openOverlay, overlayHeader } from './overlay.js';
import { toast } from './toast.js';

const SWITCHES = [
  { key: 'failNextAdd', title: 'La próxima acción de agregar falla', note: 'Muestra el error junto al botón y deja el carrito intacto.' },
  { key: 'slowNetwork', title: 'Red lenta', note: 'Alarga las respuestas simuladas para ver estados pendientes y de carga.' },
  { key: 'searchError', title: 'Falla en sugerencias de búsqueda', note: 'Las sugerencias muestran un error recuperable; Enter sigue buscando.' },
  { key: 'resultsError', title: 'Falla en la página de resultados', note: 'Muestra el estado de error con “Reintentar”.' },
  { key: 'storageBlocked', title: 'Almacenamiento bloqueado', note: 'Simula un navegador que no guarda datos: favoritos solo duran la visita.' },
];

const TOUR = [
  { label: 'Oferta real con precio anterior', href: '/products/bolso-guess-crossbody-negro-1' },
  { label: '8 colores, 2 agotados, sobre pedido', href: '/products/bolso-coach-shoulder-negro-rectangular' },
  { label: 'Nombre largo con 5 opciones', href: '/products/bolso-michael-kors-marilyn-medium-signature-convertible-satchel-vanilla-rosa' },
  { label: 'Agotado (estado de demostración)', href: '/products/bolsa-guess-shoulder-vino-brillante' },
  { label: 'Envío inmediato', href: '/products/bolsa-guess-crossbody-camera-camel' },
  { label: 'Límite de existencia (demostración)', href: '/products/cartera-guess-compacta-negro' },
  { label: 'Filtros combinados en URL', href: '/collections/guess?filter.p.m.custom.estilo=Satchel&filter.p.m.custom.marca=Steve+Madden&sort_by=price-ascending' },
  { label: 'Búsqueda sin resultados', href: '/search?q=perfume+dior&type=product' },
];

export function openDemoPanel() {
  const titleId = nextOverlayId('demo-title');
  const captured = new Date(catalog.capturedAt).toLocaleString('es-MX', { dateStyle: 'long', timeStyle: 'short', timeZone: 'America/Monterrey' });
  const { demo } = getState();
  openOverlay({
    kind: 'drawer-right',
    labelledBy: titleId,
    content: html`${overlayHeader(titleId, 'Acerca de este prototipo', { eyebrow: 'Prototipo de diseño' })}
      <div class="overlay__body">
        <p class="body-copy body-copy--ink">Prototipo navegable del rediseño web de monetta.mx. Todo ocurre en este navegador: el carrito, los favoritos y las búsquedas son datos locales de demostración.</p>
        <ul class="handoff-list">
          <li>${icon('info', { size: 18 })}<span>Catálogo: ${catalog.products.length} de ${catalog.totalLiveProducts} productos públicos de monetta.mx capturados el ${captured}. Precios y existencias son una foto fechada, no datos en vivo.</span></li>
          <li>${icon('lock', { size: 18 })}<span>Checkout, cuentas, WhatsApp y enlaces externos muestran el traspaso en lugar de abrirse. No se crean pedidos ni se envían mensajes.</span></li>
          <li>${icon('check', { size: 18 })}<span>Almacenamiento: ${isStoragePersistent() ? 'disponible (localStorage).' : 'no disponible; los datos duran solo esta visita.'}</span></li>
        </ul>
        <h3 class="summary__title" style="margin-top:24px">Estados de demostración</h3>
        ${SWITCHES.map(
          (entry) => html`<label class="demo-switch" for="demo-${entry.key}">
            <span><strong>${entry.title}</strong><p>${entry.note}</p></span>
            <input type="checkbox" id="demo-${entry.key}" data-demo="${entry.key}" ${demo[entry.key] ? 'checked' : ''}>
          </label>`,
        )}
        <div style="display:flex;flex-wrap:wrap;gap:10px;margin-top:16px">
          <button type="button" class="btn btn--quiet btn--sm" data-demo-missing-fav>Agregar un favorito no disponible</button>
          <button type="button" class="btn btn--outline btn--sm" data-demo-reset>Restablecer datos de demostración</button>
        </div>
        <h3 class="summary__title" style="margin-top:28px">Recorrido sugerido</h3>
        <ul class="demo-links" role="list">${TOUR.map((stop) => html`<li><a href="${stop.href}">${stop.label} ${icon('chevronRight', { size: 18 })}</a></li>`)}</ul>
      </div>`,
    initialFocus: '.overlay__close',
    onMount(panel, handle) {
      panel.addEventListener('change', (event) => {
        const key = event.target.dataset.demo;
        if (!key) return;
        setDemo(key, event.target.checked);
        toast(`${SWITCHES.find((entry) => entry.key === key).title}: ${event.target.checked ? 'activado' : 'desactivado'}.`);
      });
      panel.addEventListener('click', (event) => {
        if (event.target.closest('[data-demo-reset]')) {
          resetDemoState();
          handle.close();
          toast('Datos de demostración restablecidos.');
        } else if (event.target.closest('[data-demo-missing-fav]')) {
          addUnavailableFavorite();
          toast('Se agregó un favorito que ya no existe en el catálogo.', { action: { label: 'Ver favoritos', onClick: () => navigate('/pages/favoritos') } });
        }
      });
    },
  });
}
