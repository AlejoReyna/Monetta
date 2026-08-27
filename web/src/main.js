import './styles.css';

const references = [
  {
    id: 'home',
    index: '01',
    src: '/live/2026-08-23-home.png',
    label: 'Inicio',
    title: 'Inicio / hero editorial',
    meta: 'Portada, anuncio y navegación persistente',
    alt: 'Inicio actual de Monetta con hero editorial',
  },
  {
    id: 'catalog',
    index: '02',
    src: '/live/2026-08-23-catalog.png',
    label: 'Catálogo',
    title: 'Catálogo / colección compacta',
    meta: 'Búsqueda, secciones y grilla editorial',
    alt: 'Catálogo actual de Monetta con búsqueda y secciones',
  },
  {
    id: 'catalog-night',
    index: '03',
    src: '/live/2026-08-23-catalog-night.png',
    label: 'Catálogo nocturno',
    title: 'Catálogo / modo nocturno',
    meta: 'Carbón, marfil y acentos dorados',
    alt: 'Modo nocturno actual del catálogo de Monetta',
  },
  {
    id: 'product',
    index: '04',
    src: '/live/2026-08-23-product.png',
    label: 'Producto',
    title: 'Producto / acciones de compra',
    meta: 'Detalle, precio, bolsa y apartado',
    alt: 'Detalle actual de un producto de Monetta',
  },
  {
    id: 'bag-empty',
    index: '05',
    src: '/live/2026-08-23-bag-empty.png',
    label: 'Bolsa vacía',
    title: 'Bolsa / estado vacío',
    meta: 'Estado vacío, mensaje y retorno a catálogo',
    alt: 'Estado actual de la bolsa vacía de Monetta',
  },
];

const canvas = document.querySelector('[data-canvas]');
const stage = document.querySelector('[data-stage]');
const overviewBoard = document.querySelector('[data-overview-board]');
const detailBoard = document.querySelector('[data-detail-board]');
const boardImage = document.querySelector('[data-board-image]');
const zoomLabel = document.querySelector('[data-zoom-label]');
const captureTitle = document.querySelector('[data-capture-title]');
const captureMeta = document.querySelector('[data-capture-meta]');
const openBoard = document.querySelector('[data-open-board]');
const viewButtons = [...document.querySelectorAll('[data-view]')];
const paletteList = document.querySelector('[data-palette-list]');
const overviewGrid = document.querySelector('[data-overview-grid]');

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

paletteList.innerHTML = references.map(referenceButton).join('');
overviewGrid.innerHTML = references.map(overviewCard).join('');

function activeSurface() {
  return mode === 'overview' ? overviewBoard : detailBoard;
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
  activeReference = references.find(reference => reference.id === id) || references[0];
  boardImage.src = activeReference.src;
  boardImage.alt = activeReference.alt;
  captureTitle.textContent = activeReference.title;
  captureMeta.textContent = `${activeReference.meta} · iPhone 17 Pro Max`;
  openBoard.href = activeReference.src;
  updateActiveCards();
  if (openDetail) setMode('detail');
}

function fitBoard() {
  const { width } = measureBoard();
  applyZoom(Math.min(1, (canvas.clientWidth - 48) / width));
  canvas.scrollTo({ top: 0, left: 0, behavior: 'smooth' });
}

function setMode(nextMode) {
  mode = nextMode;
  const showOverview = mode === 'overview';
  overviewBoard.hidden = !showOverview;
  detailBoard.hidden = showOverview;
  stage.classList.toggle('is-overview', showOverview);
  stage.classList.toggle('is-detail', !showOverview);
  viewButtons.forEach(button => button.classList.toggle('is-active', button.dataset.view === mode));
  canvas.scrollTo({ top: 0, left: 0, behavior: 'smooth' });
  requestAnimationFrame(() => showOverview ? fitBoard() : applyZoom(1));
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
  if (!(event.metaKey || event.ctrlKey)) return;
  event.preventDefault();
  applyZoom(zoom + (event.deltaY < 0 ? 0.08 : -0.08));
}, { passive: false });

let pointer = null;
canvas.addEventListener('pointerdown', event => {
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
  if (!(event.metaKey || event.ctrlKey)) return;
  if (event.key === '=') { event.preventDefault(); applyZoom(zoom + 0.1); }
  if (event.key === '-') { event.preventDefault(); applyZoom(zoom - 0.1); }
  if (event.key === '0') { event.preventDefault(); document.querySelector('[data-fit]').click(); }
});
window.addEventListener('resize', () => applyZoom(zoom));

selectReference(references[0].id, { openDetail: false });
setMode('overview');
