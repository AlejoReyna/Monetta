import './styles.css';

const canvas = document.querySelector('[data-canvas]');
const boardWrap = document.querySelector('[data-board-wrap]');
const boardImage = document.querySelector('[data-board-image]');
const zoomLabel = document.querySelector('[data-zoom-label]');
const captureHead = document.querySelector('[data-capture-head]');
const captureTitle = document.querySelector('[data-capture-title]');
const captureMeta = document.querySelector('[data-capture-meta]');
const captureEyebrow = document.querySelector('[data-capture-eyebrow]');
const captureStatus = document.querySelector('[data-capture-status]');
const openBoard = document.querySelector('[data-open-board]');
const tabs = [...document.querySelectorAll('[data-board]')];
let zoom = 1;
let boardWidth = 420;
let boardHeight = 2868;

function applyZoom(next) {
  zoom = Math.min(2.4, Math.max(0.32, next));
  boardWrap.style.transform = `scale(${zoom})`;
  const pad = boardWrap.classList.contains('is-live') ? 300 : 152;
  boardWrap.style.width = `calc(max(100%, ${boardWidth * zoom + pad}px))`;
  boardWrap.style.minHeight = `calc(100% + ${Math.max(0, (boardHeight * zoom) - window.innerHeight)}px)`;
  zoomLabel.textContent = `${Math.round(zoom * 100)}%`;
}

function switchBoard(button) {
  boardImage.src = button.dataset.board;
  const isLive = button.dataset.kind === 'live';
  boardWrap.classList.toggle('is-live', isLive);
  boardWrap.classList.toggle('is-svg', !isLive);
  boardWidth = isLive ? 420 : 1800;
  boardHeight = isLive ? 2868 : 6300;
  captureEyebrow.textContent = isLive ? 'RUNNING BUILD' : 'REFERENCE BOARD';
  captureStatus.innerHTML = isLive ? '<i></i> LIVE CAPTURE' : '<i></i> SVG GUIDELINE';
  captureTitle.textContent = button.dataset.title || 'Current UI';
  captureMeta.textContent = button.dataset.meta || 'Monetta current UI';
  openBoard.href = button.dataset.board;
  boardImage.alt = isLive ? `Monetta live app capture: ${button.dataset.title}` : 'Monetta current UI screen atlas';
  tabs.forEach(tab => tab.classList.toggle('is-active', tab === button));
  canvas.scrollTo({ top: 0, left: 0, behavior: 'smooth' });
  applyZoom(1);
}

tabs.forEach(tab => tab.addEventListener('click', () => switchBoard(tab)));
document.querySelector('[data-zoom-in]').addEventListener('click', () => applyZoom(zoom + 0.1));
document.querySelector('[data-zoom-out]').addEventListener('click', () => applyZoom(zoom - 0.1));
document.querySelector('[data-fit]').addEventListener('click', () => {
  const available = canvas.clientWidth - (boardWrap.classList.contains('is-live') ? 300 : 152);
  applyZoom(Math.min(1, available / boardWidth));
  canvas.scrollTo({ top: 0, left: 0, behavior: 'smooth' });
});

canvas.addEventListener('wheel', event => {
  if (!(event.metaKey || event.ctrlKey)) return;
  event.preventDefault();
  applyZoom(zoom + (event.deltaY < 0 ? 0.08 : -0.08));
}, { passive: false });

let pointer = null;
canvas.addEventListener('pointerdown', event => {
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
  canvas.releasePointerCapture(event.pointerId);
});
canvas.addEventListener('pointercancel', () => { pointer = null; canvas.classList.remove('is-panning'); });

window.addEventListener('keydown', event => {
  if (!(event.metaKey || event.ctrlKey)) return;
  if (event.key === '=') { event.preventDefault(); applyZoom(zoom + 0.1); }
  if (event.key === '-') { event.preventDefault(); applyZoom(zoom - 0.1); }
  if (event.key === '0') { event.preventDefault(); document.querySelector('[data-fit]').click(); }
});

switchBoard(tabs[0]);
