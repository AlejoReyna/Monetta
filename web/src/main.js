import './styles.css';

const references = [
  {
    id: 'home',
    index: '01',
    src: '/live/2026-08-29-home.png',
    label: 'Inicio',
    title: 'Inicio / campaña editorial',
    meta: 'Hero actual y búsqueda por icono',
    alt: 'Inicio actual de Monetta con búsqueda por icono',
  },
  {
    id: 'home-menu',
    index: '02',
    src: '/live/2026-08-29-home-menu.png',
    label: 'Menú',
    title: 'Inicio / menú lateral',
    meta: 'Categorías, notificaciones y enlaces',
    alt: 'Menú lateral actual de Monetta',
  },
  {
    id: 'search-empty',
    index: '03',
    src: '/live/2026-08-29-search-empty.png',
    label: 'Buscar',
    title: 'Búsqueda / estado inicial',
    meta: 'Sugerencias frecuentes y novedades',
    alt: 'Estado inicial de búsqueda de Monetta',
  },
  {
    id: 'search-results',
    index: '04',
    src: '/live/2026-08-29-search-results.png',
    label: 'Resultados',
    title: 'Búsqueda / con resultados',
    meta: 'Consulta Steve y grilla filtrada',
    alt: 'Resultados de búsqueda actuales de Monetta',
  },
  {
    id: 'search-no-results',
    index: '05',
    src: '/live/2026-08-29-search-no-results.png',
    label: 'Sin resultados',
    title: 'Búsqueda / sin coincidencias',
    meta: 'Mensaje de recuperación y novedades',
    alt: 'Búsqueda sin resultados en Monetta',
  },
  {
    id: 'collection-bags',
    index: '06',
    src: '/live/2026-08-29-collection-bags.png',
    label: 'Colección Bolsas',
    title: 'Colección / Bolsas',
    meta: 'Siluetas, orden y productos',
    alt: 'Colección de bolsas actual de Monetta',
  },
  {
    id: 'collection-filter',
    index: '07',
    src: '/live/2026-08-29-collection-filter.png',
    label: 'Filtros colección',
    title: 'Colección / filtros y orden',
    meta: 'Marca, silueta, stock y orden',
    alt: 'Filtros de colección actuales de Monetta',
  },
  {
    id: 'notifications',
    index: '08',
    src: '/live/2026-08-29-notifications.png',
    label: 'Notificaciones',
    title: 'Preferencias / notificaciones',
    meta: 'Avisos, ofertas y anuncios',
    alt: 'Preferencias de notificaciones de Monetta',
  },
  {
    id: 'about',
    index: '09',
    src: '/live/2026-08-29-about.png',
    label: 'Nuestra historia',
    title: 'Editorial / Nuestra historia',
    meta: 'Historia, propuesta e imagen editorial',
    alt: 'Página Nuestra historia de Monetta',
  },
  {
    id: 'partner',
    index: '10',
    src: '/live/2026-08-29-partner.png',
    label: 'Mayoreo',
    title: 'Mayoreo / Vende con Monetta',
    meta: 'Propuesta comercial y pasos',
    alt: 'Página de mayoreo de Monetta',
  },
  {
    id: 'customer-experiences',
    index: '11',
    src: '/live/2026-08-29-customer-experiences.png',
    label: 'Experiencias',
    title: 'Experiencias / reseñas',
    meta: 'Calificación y testimonios de clientes',
    alt: 'Experiencias de clientes de Monetta',
  },
  {
    id: 'onboarding',
    index: '12',
    src: '/live/2026-08-29-onboarding.png',
    label: 'Onboarding',
    title: 'Onboarding / preferencias',
    meta: 'Categorías y marcas de interés',
    alt: 'Selección de preferencias de Monetta',
  },
  {
    id: 'catalog',
    index: '13',
    src: '/live/2026-08-29-catalog.png',
    label: 'Catálogo',
    title: 'Catálogo / categorías',
    meta: 'Colección, filtros y grilla editorial',
    alt: 'Catálogo actual de Monetta con categorías y filtros',
  },
  {
    id: 'catalog-filter',
    index: '14',
    src: '/live/2026-08-29-catalog-filter.png',
    label: 'Filtros catálogo',
    title: 'Catálogo / filtros y orden',
    meta: 'Orden, tipo, marca, precio y stock',
    alt: 'Filtros del catálogo actual de Monetta',
  },
  {
    id: 'catalog-monetta',
    index: '15',
    src: '/live/2026-08-29-catalog-monetta.png',
    label: 'Selección Monetta',
    title: 'Catálogo / Selección Monetta',
    meta: 'Filtro de inventario propio',
    alt: 'Selección Monetta en el catálogo',
  },
  {
    id: 'catalog-bags',
    index: '16',
    src: '/live/2026-08-29-catalog-bags.png',
    label: 'Bolsas',
    title: 'Catálogo / Bolsas',
    meta: 'Filtro por vertical de bolsas',
    alt: 'Categoría Bolsas del catálogo Monetta',
  },
  {
    id: 'catalog-perfumes',
    index: '17',
    src: '/live/2026-08-29-catalog-perfumes.png',
    label: 'Perfumes vacío',
    title: 'Catálogo / Perfumes sin resultados',
    meta: 'Categoría seleccionada y estado vacío',
    alt: 'Estado vacío de Perfumes en el catálogo Monetta',
  },
  {
    id: 'product',
    index: '18',
    src: '/live/2026-08-29-product.png',
    label: 'Producto',
    title: 'Producto / acciones de compra',
    meta: 'Imagen real, precio, bolsa y apartado',
    alt: 'Detalle actual de un producto de Monetta',
  },
  {
    id: 'mini-cart',
    index: '19',
    src: '/live/2026-08-29-mini-cart.png',
    label: 'Minicart',
    title: 'Bolsa / confirmación rápida',
    meta: 'Artículo agregado y acceso a bolsa',
    alt: 'Minicart con un producto de Monetta',
  },
  {
    id: 'bag',
    index: '20',
    src: '/live/2026-08-29-bag.png',
    label: 'Bolsa',
    title: 'Bolsa / con producto',
    meta: 'Cantidad, resumen y entrega',
    alt: 'Bolsa de Monetta con un producto',
  },
  {
    id: 'checkout-delivery',
    index: '21',
    src: '/live/2026-08-29-checkout-delivery.png',
    label: 'Entrega',
    title: 'Checkout / datos de entrega',
    meta: 'Contacto, dirección y envío',
    alt: 'Formulario de entrega del checkout de Monetta',
  },
  {
    id: 'checkout-review',
    index: '22',
    src: '/live/2026-08-29-checkout-review.png',
    label: 'Revisar pedido',
    title: 'Checkout / revisión del pedido',
    meta: 'Contacto, entrega, método y resumen',
    alt: 'Revisión del pedido en el checkout de Monetta',
  },
  {
    id: 'bag-empty',
    index: '23',
    src: '/live/2026-08-29-bag-empty.png',
    label: 'Bolsa vacía',
    title: 'Bolsa / estado vacío',
    meta: 'Estado vacío, mensaje y retorno a catálogo',
    alt: 'Estado actual de la bolsa vacía de Monetta',
  },
];

function formatDate(date) {
  return new Intl.DateTimeFormat('es-MX', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  }).format(date).replace(/\./g, '').toUpperCase();
}

const historyDateLabel = formatDate(new Date());
const historyReferences = references.map(reference => ({
  ...reference,
  id: `history-${reference.id}`,
  sourceId: reference.id,
  title: `Historial / ${reference.title}`,
  meta: `Vista actualizada · ${reference.meta}`,
  isHistory: true,
}));
const allReferences = [...references, ...historyReferences];

const annotations = {
  home: [
    { side: 'right', x: 90, y: 7, label: 'Búsqueda reducida a un icono' },
  ],
  'home-menu': [
    { side: 'right', x: 78, y: 18, label: 'Acceso directo a búsqueda' },
  ],
  'collection-bags': [
    { side: 'right', x: 88, y: 15, label: 'Filtros visuales por silueta' },
  ],
  catalog: [
    { side: 'left', x: 10, y: 17, label: 'Categorías rápidas' },
    { side: 'right', x: 91, y: 8, label: 'Filtrar y ordenar' },
  ],
  product: [
    { side: 'right', x: 88, y: 88, label: 'Compra siempre al alcance' },
  ],
  'mini-cart': [
    { side: 'right', x: 88, y: 79, label: 'Confirmación sin perder contexto' },
  ],
  'checkout-review': [
    { side: 'right', x: 84, y: 64, label: 'Salida al pago seguro' },
  ],
};

const canvas = document.querySelector('[data-canvas]');
const stage = document.querySelector('[data-stage]');
const overviewBoard = document.querySelector('[data-overview-board]');
const detailBoard = document.querySelector('[data-detail-board]');
const motionBoard = document.querySelector('[data-motion-board]');
const boardImage = document.querySelector('[data-board-image]');
const zoomLabel = document.querySelector('[data-zoom-label]');
const captureTitle = document.querySelector('[data-capture-title]');
const captureMeta = document.querySelector('[data-capture-meta]');
const captureStatus = document.querySelector('[data-capture-status]');
const openBoard = document.querySelector('[data-open-board]');
const viewButtons = [...document.querySelectorAll('[data-view]')];
const paletteList = document.querySelector('[data-palette-list]');
const historyList = document.querySelector('[data-history-list]');
const historyGroup = document.querySelector('[data-history-group]');
const historyToggle = document.querySelector('[data-history-toggle]');
const historyPanel = document.querySelector('[data-history-panel]');
const overviewGrid = document.querySelector('[data-overview-grid]');
const annotationLayer = document.querySelector('[data-annotations]');

let zoom = 1;
let activeReference = references[0];
let mode = 'overview';

function referenceButton(reference) {
  return `
    <button class="palette-card" type="button" data-reference="${reference.id}">
      <span class="palette-card__thumb"><img src="${reference.src}" alt="" /></span>
      <span class="palette-card__copy">
        <small>${reference.index}</small>
        <strong>${reference.label}</strong>
        <em>${reference.meta}</em>
      </span>
    </button>`;
}

function overviewCard(reference) {
  return `
    <button class="overview-card" type="button" data-reference="${reference.id}">
      <span class="overview-card__top"><small>${reference.index}</small><i></i><em>ACTUAL</em></span>
      <span class="overview-card__device"><img src="${reference.src}" alt="${reference.alt}" /></span>
      <span class="overview-card__label"><strong>${reference.label}</strong><small>${reference.meta}</small></span>
    </button>`;
}

function annotationMarkup(annotation) {
  const line = '<span class="callout__line"></span>';
  const dot = '<i class="callout__dot"></i>';
  const label = `<span class="callout__label">${annotation.label}</span>`;
  const content = annotation.side === 'left'
    ? `${label}${line}${dot}`
    : `${dot}${line}${label}`;

  return `
    <span
      class="callout callout--${annotation.side}"
      style="--callout-x:${annotation.x}%;--callout-y:${annotation.y}%"
    >${content}</span>`;
}

paletteList.innerHTML = references.map(referenceButton).join('');
historyList.innerHTML = historyReferences.map(referenceButton).join('');
overviewGrid.innerHTML = references.map(overviewCard).join('');
document.querySelector('[data-reference-count]').textContent = references.length;
document.querySelector('[data-history-date]').textContent = historyDateLabel;
document.querySelector('[data-history-count]').textContent = `${historyReferences.length} vistas actualizadas`;

function activeSurface() {
  if (mode === 'overview') return overviewBoard;
  if (mode === 'motion') return motionBoard;
  return detailBoard;
}

function measureBoard() {
  const surface = activeSurface();
  return {
    width: surface.offsetWidth + 128,
    height: surface.offsetHeight + 128,
  };
}

function applyZoom(next) {
  zoom = Math.min(2.4, Math.max(0.32, next));
  stage.style.transform = `scale(${zoom})`;
  const { width, height } = measureBoard();
  stage.style.width = `calc(max(100%, ${width * zoom}px))`;
  stage.style.minHeight = `calc(100% + ${Math.max(0, (height * zoom) - window.innerHeight)}px)`;
  zoomLabel.textContent = `${Math.round(zoom * 100)}%`;
}

function updateActiveCards() {
  document.querySelectorAll('[data-reference]').forEach(card => {
    const selected = card.dataset.reference === activeReference.id;
    card.classList.toggle('is-active', selected);
    card.setAttribute('aria-pressed', selected ? 'true' : 'false');
  });
}

function selectReference(id, { openDetail = true } = {}) {
  activeReference = allReferences.find(reference => reference.id === id) || references[0];
  const activeAnnotations = annotations[activeReference.sourceId || activeReference.id] || [];
  boardImage.src = activeReference.src;
  boardImage.alt = activeReference.alt;
  captureTitle.textContent = activeReference.title;
  captureMeta.textContent = `${activeReference.meta} · iPhone 17 Pro Max`;
  captureStatus.textContent = activeReference.isHistory
    ? `HISTORIAL · ${historyDateLabel}`
    : 'CAPTURA ACTUAL';
  openBoard.href = activeReference.src;
  annotationLayer.innerHTML = activeAnnotations.map(annotationMarkup).join('');
  detailBoard.classList.toggle('has-callouts', activeAnnotations.length > 0);
  updateActiveCards();
  if (openDetail) setMode('detail');
}

historyToggle.addEventListener('click', () => {
  const isOpen = !historyGroup.classList.contains('is-open');
  historyGroup.classList.toggle('is-open', isOpen);
  historyToggle.setAttribute('aria-expanded', String(isOpen));
  historyPanel.setAttribute('aria-hidden', String(!isOpen));
});

function fitBoard() {
  const { width } = measureBoard();
  applyZoom(Math.min(1, (canvas.clientWidth - 48) / width));
  canvas.scrollTo({ top: 0, left: 0, behavior: 'smooth' });
}

function setMode(nextMode) {
  mode = nextMode;
  const showOverview = mode === 'overview';
  const showDetail = mode === 'detail';
  const showMotion = mode === 'motion';
  overviewBoard.hidden = !showOverview;
  detailBoard.hidden = !showDetail;
  motionBoard.hidden = !showMotion;
  stage.classList.toggle('is-overview', showOverview);
  stage.classList.toggle('is-detail', showDetail);
  stage.classList.toggle('is-motion', showMotion);
  canvas.classList.toggle('is-detail', showDetail);
  document.body.dataset.mode = mode;
  viewButtons.forEach(button => button.classList.toggle('is-active', button.dataset.view === mode));
  canvas.scrollTo({ top: 0, left: 0, behavior: 'smooth' });
  stopMotionExperience();
  requestAnimationFrame(() => {
    if (showOverview) fitBoard();
    else if (showMotion) startMotionExperience();
    else applyZoom(1);
  });
}

document.querySelectorAll('[data-reference]').forEach(card => {
  card.addEventListener('click', () => selectReference(card.dataset.reference));
});

viewButtons.forEach(button => {
  button.addEventListener('click', () => setMode(button.dataset.view));
});

document.querySelector('[data-zoom-in]').addEventListener('click', () => applyZoom(zoom + 0.1));
document.querySelector('[data-zoom-out]').addEventListener('click', () => applyZoom(zoom - 0.1));
document.querySelector('[data-fit]').addEventListener('click', fitBoard);

canvas.addEventListener('wheel', event => {
  if (mode !== 'overview') return;
  if (!(event.metaKey || event.ctrlKey)) return;
  event.preventDefault();
  applyZoom(zoom + (event.deltaY < 0 ? 0.08 : -0.08));
}, { passive: false });

let pointer = null;
canvas.addEventListener('pointerdown', event => {
  if (mode !== 'overview') return;
  if (event.target.closest('button, a')) return;
  pointer = { x: event.clientX, y: event.clientY, left: canvas.scrollLeft, top: canvas.scrollTop };
  canvas.classList.add('is-panning');
  canvas.setPointerCapture(event.pointerId);
});
canvas.addEventListener('pointermove', event => {
  if (!pointer) return;
  canvas.scrollLeft = pointer.left - (event.clientX - pointer.x);
  canvas.scrollTop = pointer.top - (event.clientY - pointer.y);
});
canvas.addEventListener('pointerup', event => {
  pointer = null;
  canvas.classList.remove('is-panning');
  if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
});
canvas.addEventListener('pointercancel', () => {
  pointer = null;
  canvas.classList.remove('is-panning');
});

window.addEventListener('keydown', event => {
  if (mode !== 'overview') return;
  if (!(event.metaKey || event.ctrlKey)) return;
  if (event.key === '=') { event.preventDefault(); applyZoom(zoom + 0.1); }
  if (event.key === '-') { event.preventDefault(); applyZoom(zoom - 0.1); }
  if (event.key === '0') { event.preventDefault(); document.querySelector('[data-fit]').click(); }
});
window.addEventListener('resize', () => {
  if (mode === 'overview') applyZoom(zoom);
});

const motionPhone = document.querySelector('[data-motion-phone]');
const motionSlides = [...document.querySelectorAll('[data-motion-slide]')];
const motionProgress = document.querySelector('[data-motion-progress]');
const motionCounter = document.querySelector('[data-motion-counter]');
const motionStatus = document.querySelector('[data-motion-status]');
const motionDemos = [...document.querySelectorAll('[data-motion-demo]')];
const reviewStudy = document.querySelector('.motion-study--reviews');
const reviewSlides = [...document.querySelectorAll('[data-review-slide]')];
const reviewCounter = document.querySelector('[data-review-counter]');
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const motionInterval = 3500;
const reviewInterval = 7000;
let motionIndex = 0;
let motionTimer = null;
let reviewIndex = 0;
let reviewTimer = null;

function stopMotionExperience() {
  window.clearTimeout(motionTimer);
  window.clearTimeout(reviewTimer);
  motionTimer = null;
  reviewTimer = null;
  motionProgress.classList.remove('is-running');
}

function runMotionProgress() {
  motionProgress.classList.remove('is-running');
  void motionProgress.offsetWidth;
  if (!prefersReducedMotion.matches && mode === 'motion') {
    motionProgress.classList.add('is-running');
  }
}

function scheduleMotionAdvance() {
  window.clearTimeout(motionTimer);
  if (prefersReducedMotion.matches || mode !== 'motion' || document.hidden) {
    motionStatus.textContent = prefersReducedMotion.matches ? 'MOVIMIENTO REDUCIDO' : 'EN PAUSA';
    return;
  }
  motionStatus.textContent = 'REPRODUCIENDO';
  runMotionProgress();
  motionTimer = window.setTimeout(() => showMotionSlide(motionIndex + 1), motionInterval);
}

function showMotionSlide(nextIndex, { immediate = false } = {}) {
  const previous = motionSlides[motionIndex];
  const normalized = (nextIndex + motionSlides.length) % motionSlides.length;
  const next = motionSlides[normalized];

  window.clearTimeout(motionTimer);
  previous.classList.remove('is-active', 'is-first');
  previous.classList.toggle('is-leaving', !immediate && previous !== next);
  previous.setAttribute('aria-hidden', 'true');

  motionIndex = normalized;
  next.classList.remove('is-leaving', 'is-first');
  next.classList.add('is-active');
  next.setAttribute('aria-hidden', 'false');
  motionCounter.textContent = `${String(motionIndex + 1).padStart(2, '0')} / ${String(motionSlides.length).padStart(2, '0')}`;

  window.setTimeout(() => previous.classList.remove('is-leaving'), immediate ? 0 : 480);
  scheduleMotionAdvance();
}

function scheduleReviewAdvance() {
  window.clearTimeout(reviewTimer);
  if (
    prefersReducedMotion.matches ||
    mode !== 'motion' ||
    document.hidden ||
    !reviewStudy.classList.contains('is-playing')
  ) return;
  reviewTimer = window.setTimeout(() => showReviewSlide(reviewIndex + 1), reviewInterval);
}

function showReviewSlide(nextIndex, { immediate = false, autoplay = true } = {}) {
  const previous = reviewSlides[reviewIndex];
  reviewIndex = (nextIndex + reviewSlides.length) % reviewSlides.length;
  const next = reviewSlides[reviewIndex];

  window.clearTimeout(reviewTimer);
  previous.classList.remove('is-active');
  previous.setAttribute('aria-hidden', 'true');
  next.classList.add('is-active');
  next.setAttribute('aria-hidden', 'false');
  if (immediate) next.style.transition = 'none';
  requestAnimationFrame(() => { next.style.transition = ''; });
  reviewCounter.textContent = `${String(reviewIndex + 1).padStart(2, '0')} / ${String(reviewSlides.length).padStart(2, '0')}`;
  if (autoplay) scheduleReviewAdvance();
}

function resetSectionDemos() {
  motionDemos.forEach(demo => demo.classList.remove('is-playing'));
  showReviewSlide(0, { immediate: true, autoplay: false });
}

function startMotionExperience() {
  resetSectionDemos();
  showMotionSlide(0, { immediate: true });
  motionSlides[0].classList.add('is-first');
  motionPhone.classList.remove('is-entering');
  void motionPhone.offsetWidth;
  motionPhone.classList.add('is-entering');
  window.setTimeout(() => motionSlides[0].classList.remove('is-first'), 800);
}

document.querySelector('[data-motion-replay]').addEventListener('click', startMotionExperience);
document.querySelector('[data-motion-prev]').addEventListener('click', () => showMotionSlide(motionIndex - 1));
document.querySelector('[data-motion-next]').addEventListener('click', () => showMotionSlide(motionIndex + 1));
document.querySelector('[data-review-prev]').addEventListener('click', () => showReviewSlide(reviewIndex - 1));
document.querySelector('[data-review-next]').addEventListener('click', () => showReviewSlide(reviewIndex + 1));

const motionDemoObserver = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (!entry.isIntersecting || mode !== 'motion') return;
    const demo = entry.target;
    demo.classList.add('is-playing');
    if (demo === reviewStudy) scheduleReviewAdvance();
  });
}, { root: canvas, threshold: 0.28 });
motionDemos.forEach(demo => motionDemoObserver.observe(demo));

prefersReducedMotion.addEventListener('change', () => {
  if (mode === 'motion') startMotionExperience();
});
document.addEventListener('visibilitychange', () => {
  if (mode !== 'motion') return;
  if (document.hidden) stopMotionExperience();
  else scheduleMotionAdvance();
});

selectReference(references[0].id, { openDetail: false });
setMode(window.matchMedia('(max-width: 700px)').matches ? 'detail' : 'overview');
