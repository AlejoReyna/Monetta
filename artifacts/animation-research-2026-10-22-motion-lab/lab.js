/* Isolated evaluation code. No fetch, storage, commerce, analytics, imports or dependencies. */
'use strict';
const $ = (s, root = document) => root.querySelector(s);
const $$ = (s, root = document) => [...root.querySelectorAll(s)];
const root = document.documentElement;
const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
const curve = 'cubic-bezier(.16,1,.3,1)';
const running = new Set();
const log = [];
const record = (event, data = {}) => { log.push({event, at: Math.round(performance.now()), ...data}); if(log.length > 500) log.shift(); };
const reduced = () => $('#comparison').value === 'static' || $('#motion').value === 'reduce' || ($('#motion').value === 'system' && systemMotion.matches);
const duration = ms => reduced() ? 0 : ms * Number($('#pace').value);
function pulse(el, keyframes, ms = 180) {
  if (!el || !el.animate || reduced()) return;
  el.getAnimations().forEach(a => a.cancel());
  const animation = el.animate(keyframes, {duration:duration(ms), easing:curve});
  running.add(animation);
  animation.finished.catch(() => {}).finally(() => running.delete(animation));
}
function preferences() {
  root.dataset.mode = $('#comparison').value;
  root.dataset.motion = $('#motion').value;
  root.dataset.reduced = String(reduced());
  const scale = Number($('#pace').value);
  root.style.setProperty('--snap', `${180*scale}ms`);
  root.style.setProperty('--swap', `${280*scale}ms`);
  root.style.setProperty('--settle', `${480*scale}ms`);
  if (reduced()) {
    running.forEach(a => { try { a.finish(); } catch { a.cancel(); } });
    $('#preview-product').classList.remove('previewing');
    if(dialogPhase === 'closing') finalizeClose();
  }
  const effective = reduced() ? '0 ms · estados instantáneos' : `${180*scale} / ${280*scale} / ${480*scale} ms · cubic-bezier(.16, 1, .3, 1)`;
  $('#motion-status').textContent = `${effective} · sistema: ${systemMotion.matches ? 'reducido' : 'sin reducción'}`;
  $$('.mode-label').forEach(el => el.textContent = reduced() ? ($('#comparison').value === 'static' ? 'Base · 0 ms' : 'Reducido · 0 ms') : 'Propuesta');
  record('preferences', {reduced:reduced(), scale, mode:root.dataset.mode});
}

// One owner for opening/closing, frame cancellation, timer invalidation and focus restoration.
const dialog = $('#shop-dialog');
const panel = $('.dialog-panel');
const scrim = document.createElement('div');
scrim.className = 'dialog-scrim'; scrim.setAttribute('aria-hidden','true'); dialog.prepend(scrim);
let dialogPhase = 'closed', opener = null, closeTimer = 0, openFrame = 0;
const titles = {menu:'Explora Monetta', search:'Encuentra tu pieza', filters:'Tu selección'};
function openDialog(kind, trigger) {
  clearTimeout(closeTimer); cancelAnimationFrame(openFrame);
  opener = trigger || opener;
  dialog.dataset.kind = kind;
  $$('.dialog-content').forEach(el => el.hidden = el.id !== `dialog-${kind}`);
  $('#dialog-title').textContent = titles[kind];
  $('#dialog-close').textContent = 'Cerrar ×';
  $('#dialog-close').setAttribute('aria-label','Cerrar panel');
  if (!dialog.open) {
    dialog.showModal(); root.classList.add('modal-open');
    // Read only once at explicit open, not on scroll. Establish CSS start state.
    panel.getBoundingClientRect();
  }
  dialogPhase = 'opening';
  openFrame = requestAnimationFrame(() => {
    panel.classList.add('is-open'); dialog.classList.add('is-open'); dialogPhase = 'open';
  });
  (kind === 'search' ? $('#search-input') : $('#dialog-close')).focus({preventScroll:true});
  record('dialog-open',{kind});
}
function finalizeClose(restoreFocus = true) {
  clearTimeout(closeTimer); cancelAnimationFrame(openFrame);
  panel.classList.remove('is-open'); dialog.classList.remove('is-open');
  if (dialog.open) dialog.close();
  dialogPhase = 'closed'; root.classList.remove('modal-open');
  $('#dialog-close').textContent = 'Cerrar ×';
  if(restoreFocus && opener?.isConnected) opener.focus({preventScroll:true});
  record('dialog-closed');
}
function closeDialog() {
  if(dialogPhase === 'closing') { openDialog(dialog.dataset.kind, opener); record('dialog-reversed'); return; }
  if(!dialog.open) return;
  cancelAnimationFrame(openFrame); clearTimeout(closeTimer);
  dialogPhase = 'closing'; panel.classList.remove('is-open'); dialog.classList.remove('is-open');
  $('#dialog-close').textContent = 'Reabrir ↶';
  $('#dialog-close').setAttribute('aria-label','Reabrir panel durante el cierre');
  const ms = duration(280);
  if(ms === 0) finalizeClose(); else closeTimer = setTimeout(finalizeClose, ms + 34);
  record('dialog-closing',{duration:ms});
}
$$('[data-open]').forEach(b => b.addEventListener('click',()=>openDialog(b.dataset.open,b)));
$('#dialog-close').addEventListener('click',closeDialog);
dialog.addEventListener('keydown',e => {
  if(e.key === 'Escape') {e.preventDefault();if(dialogPhase !== 'closing')closeDialog();return;}
  if(e.key !== 'Tab') return;
  const focusable = $$('button, input, select, a[href], [tabindex]',panel).filter(el=>!el.disabled && el.tabIndex >= 0 && el.getClientRects().length);
  const first = focusable[0], last = focusable.at(-1);
  if(e.shiftKey && document.activeElement === first) {e.preventDefault();last?.focus();}
  else if(!e.shiftKey && document.activeElement === last) {e.preventDefault();first?.focus();}
});
dialog.addEventListener('cancel',e => { e.preventDefault(); if(dialogPhase !== 'closing') closeDialog(); });
dialog.addEventListener('click',e => { if(e.target === dialog || e.target === scrim) { if(dialogPhase !== 'closing') closeDialog(); } });
$$('[data-menu]').forEach(b => b.addEventListener('click',()=> { $('#menu-status').textContent = `${b.dataset.menu}: destino de muestra seleccionado. No hay navegación externa.`; }));
$('#apply-filters').addEventListener('click',()=>{
  const values = $$('#dialog-filters input:checked').map(el=>el.value);
  $('#filter-result').textContent = values.length ? `Filtro demo: ${values.join(', ')}. El catálogo de muestra permanece visible.` : 'Todos los estilos. Filtros locales restablecidos.';
  closeDialog();
});
$('#search-input').addEventListener('input',e=>{
  const value = e.target.value.trim().toLowerCase();
  const products = [
    {name:'Tote para cada día',file:'home_bag_tote.webp',price:'$2,890 MXN'},
    {name:'Bolsa de hombro',file:'home_bag_shoulder.webp',price:'$2,490 MXN'},
    {name:'Bolsa crossbody',file:'home_bag_crossbody.webp',price:'$2,190 MXN'}
  ];
  const match = products.find(p=>!value || p.name.toLowerCase().includes(value));
  $('#search-result').textContent = !value ? 'Escribe para buscar entre tres piezas locales.' : match ? 'Una sugerencia de muestra. No se consultó Shopify.' : 'Sin coincidencias. Prueba «tote» o «bolsa».';
  $('.search-product').hidden = !match;
  if(match) { $('#search-product-name').textContent = `${match.name} · ${match.price}`; $('.search-product img').src=`assets/${match.file}`; $('.search-product img').alt=match.name; }
});

// Latest-selection-wins image transaction. Old image + truthful caption stay until decode.
const variants = {
  shoulder:{name:'Hombro',file:'home_bag_shoulder.webp',price:'$2,490 MXN'},
  crossbody:{name:'Crossbody',file:'home_bag_crossbody.webp',price:'$2,190 MXN'},
  tote:{name:'Tote',file:'home_bag_tote.webp',price:'$2,890 MXN'}
};
let gallerySequence = 0, galleryTimer = 0, selectedVariant = 'shoulder', shownVariant = 'shoulder';
let pendingImage = null, imageAnimation = null;
function clearGalleryTransition() {
  if(imageAnimation) { imageAnimation.cancel(); imageAnimation = null; }
  pendingImage?.remove(); pendingImage = null;
}
function selectVariant(key) {
  const sequence = ++gallerySequence;
  clearTimeout(galleryTimer); clearGalleryTransition(); selectedVariant = key;
  const item = variants[key];
  $$('.variant').forEach(b=>{ const selected = b.dataset.variant === key; b.classList.toggle('selected',selected); b.setAttribute('aria-pressed',String(selected)); });
  $('#sample-price').textContent = item.price;
  const status = $('#gallery-status'); status.className = 'reserved-status';
  if (key === shownVariant) {
    $('.gallery-frame').setAttribute('aria-busy','false');
    status.textContent = `Mostrando ${item.name}. Selección actual; carga anterior cancelada.`;
    record('gallery-existing',{key,sequence}); return;
  }
  $('.gallery-frame').setAttribute('aria-busy','true');
  status.textContent = `Seleccionado ${item.name}. Cargando; imagen actual: ${variants[shownVariant].name}.`;
  const network = $('#gallery-network').value;
  record('gallery-request',{key,sequence,network});
  galleryTimer = setTimeout(async()=>{
    if(sequence !== gallerySequence) return;
    if(network === 'fail') {
      $('.gallery-frame').setAttribute('aria-busy','false'); status.classList.add('error');
      status.textContent = `No se pudo cargar ${item.name}. Se conserva la imagen de ${variants[shownVariant].name}. Reintenta o cambia de silueta.`;
      record('gallery-error',{key,sequence}); return;
    }
    const image = new Image(600,600); image.src = `assets/${item.file}`; image.alt = `Silueta ${item.name}, imagen de muestra`; image.className = 'incoming';
    try { await image.decode(); } catch {
      if(sequence !== gallerySequence) return;
      $('.gallery-frame').setAttribute('aria-busy','false'); status.classList.add('error'); status.textContent = 'No se pudo decodificar la imagen local. Se conserva la anterior.'; return;
    }
    if(sequence !== gallerySequence) return;
    pendingImage = image; $('.gallery-frame').insertBefore(image,$('#gallery-badge'));
    // Decorative transition only; selected text/price never waits for it.
    imageAnimation = !reduced() && image.animate ? image.animate([{opacity:0},{opacity:1}],{duration:duration(280),easing:curve}) : null;
    if(imageAnimation) {
      const ownedAnimation = imageAnimation; running.add(ownedAnimation);
      try { await ownedAnimation.finished; } catch { return; } finally { running.delete(ownedAnimation); }
    }
    if(sequence !== gallerySequence) return;
    $('#product-image').remove(); image.id = 'product-image'; image.classList.remove('incoming'); pendingImage = null; imageAnimation = null; shownVariant = key;
    $('#gallery-badge').textContent = item.name; $('.gallery-frame').setAttribute('aria-busy','false');
    status.textContent = `Mostrando ${item.name}. Imagen de muestra.`;
    record('gallery-commit',{key,sequence});
  },network === 'slow' ? 1200 : 220);
}
$$('.variant').forEach(b=>b.addEventListener('click',()=>selectVariant(b.dataset.variant)));
$('#gallery-retry').addEventListener('click',()=>selectVariant(selectedVariant));

// Local commerce state machine, not connected to a Shopify service.
let cartCount = 0, quantity = 0, adding = false, addTimer = 0, quantityTimer = 0, quantitySequence = 0;
function setCartCount(value) {
  cartCount = value; $('#cart-count').textContent = value;
  $('.cart-count').setAttribute('aria-label',`${value} ${value===1?'unidad confirmada':'unidades confirmadas'} en la bolsa demo`);
  pulse($('#cart-count'),[{transform:'scale(1)',opacity:.6},{transform:'scale(1.08)',opacity:1},{transform:'scale(1)',opacity:1}]);
}
function setQuantity(value) {
  quantity = value; $('#quantity').textContent = value;
  $('#qty-less').disabled = value <= 1 || adding;
  $('#qty-more').disabled = value === 0 || value >= 10 || adding;
}
function cartMessage(text, kind='') {
  const el = $('#cart-status'); el.textContent = text; el.className = `reserved-status ${kind}`;
  if(kind !== 'error') pulse(el,[{opacity:.3,transform:'translateY(4px)'},{opacity:1,transform:'translateY(0)'}]);
}
$('#add-demo').addEventListener('click',()=>{
  if(adding) {record('cart-duplicate-ignored');return;}
  if(cartCount >= 10) {cartMessage('Límite de la demo: 10 piezas. Reduce la cantidad o restablece la bolsa. No se agregó nada.','error');record('cart-limit');return;}
  clearTimeout(quantityTimer); quantitySequence++;
  // Settle pending quantity locally before a separate add, never stack local operations.
  if(quantity !== cartCount) setQuantity(cartCount);
  adding = true; const result = $('#action-result').value;
  $('#add-demo').setAttribute('aria-disabled','true'); $('#add-demo').setAttribute('aria-busy','true');
  $('#add-label').textContent = 'Agregando · demo…'; setQuantity(quantity);
  cartMessage('Procesando una acción simulada. Los clics repetidos se ignoran.');
  record('cart-request',{result});
  addTimer = setTimeout(()=>{
    adding = false; $('#add-demo').removeAttribute('aria-disabled'); $('#add-demo').removeAttribute('aria-busy');
    $('#add-label').textContent = 'Agregar a bolsa demo';
    if(result === 'error') {setQuantity(quantity);cartMessage('No se agregó la pieza (error simulado). Tu bolsa sigue igual. Puedes reintentar.','error');record('cart-error');return;}
    setCartCount(Math.min(cartCount+1,10)); setQuantity(cartCount);
    cartMessage(`✓ Agregado a la bolsa demo. ${cartCount} ${cartCount===1?'pieza confirmada':'piezas confirmadas'}. No se creó un pedido real.`,'success');
    $('#quantity-status').textContent = 'Cantidad confirmada. Máximo de muestra: 10.';
    pulse($('.button-symbol'),[{opacity:.25},{opacity:1}]); record('cart-success',{count:cartCount});
  },result === 'slow' ? 1800 : 650);
});
function changeQuantity(delta) {
  if(!quantity || adding) return;
  const next = Math.max(1,Math.min(10,quantity+delta));
  if(next === quantity) return;
  const sequence = ++quantitySequence; clearTimeout(quantityTimer); setQuantity(next);
  $('#quantity-status').textContent = `Actualizando a ${next} (simulación). Bolsa confirmada: ${cartCount}.`;
  const result = $('#action-result').value;
  record('quantity-request',{value:next,sequence});
  quantityTimer = setTimeout(()=>{
    if(sequence !== quantitySequence) return;
    if(result === 'error') {
      setQuantity(cartCount); $('#quantity-status').textContent = `Error simulado. Se restaura la cantidad confirmada: ${cartCount}.`; record('quantity-error'); return;
    }
    setCartCount(quantity); $('#quantity-status').textContent = `Cantidad confirmada en demo: ${quantity}.`;
    record('quantity-commit',{value:quantity,sequence});
  }, result === 'slow' ? 1800 : 500);
}
$('#qty-less').addEventListener('click',()=>changeQuantity(-1));
$('#qty-more').addEventListener('click',()=>changeQuantity(1));

let previewTimer = 0;
function previewImage() {
  clearTimeout(previewTimer); $('#preview-product').classList.add('previewing');
  previewTimer = setTimeout(()=>$('#preview-product').classList.remove('previewing'),duration(650));
  $('#preview-status').textContent = 'Vista demo seleccionada. La zona de activación permanece fija; no se abrió una página real.';
  record('card-preview');
}
$('#preview-product').addEventListener('click',previewImage);
$('#preview-pulse').addEventListener('click',previewImage);
$$('[name=expression]').forEach(r=>r.addEventListener('change',()=>{
  $('#discovery-card').classList.toggle('expressive',r.value === 'expressive' && r.checked);
  record('card-expression',{value:r.value});
}));
$('#save-product').addEventListener('click',()=>{
  const button = $('#save-product'), saved = button.getAttribute('aria-pressed') !== 'true';
  button.setAttribute('aria-pressed',String(saved)); button.setAttribute('aria-label',saved?'Quitar bolsa de hombro de guardados de esta sesión':'Guardar bolsa de hombro en esta sesión');
  $('#save-status').textContent = saved ? '✓ Guardado en esta sesión. Sin sincronizar con una cuenta.' : 'Sin guardar · sólo esta sesión.';
  pulse($('svg',button),[{transform:'scale(.94)',opacity:.65},{transform:'scale(1)',opacity:1}]);
  record('saved-toggle',{saved});
});
$('#shipping-info').addEventListener('click',()=>$('#shipping-status').textContent = 'Ejemplo consultado. No se abrió un servicio externo.');

// A constrained frame makes the new mobile idea testable at every lab viewport.
const phoneScroll = $('#phone-scroll'), contextBar = $('#context-bar'), originalPurchase = $('#original-purchase');
let needsBar = false;
function syncBar() {
  // Recheck only at threshold/focus/reset boundaries. Outer clipping must not decide CTA state.
  needsBar = originalPurchase.getBoundingClientRect().bottom < phoneScroll.getBoundingClientRect().top;
  const focused = contextBar.contains(document.activeElement);
  const visible = needsBar || focused;
  contextBar.classList.toggle('visible',visible); contextBar.inert = !visible; contextBar.setAttribute('aria-hidden',String(!visible));
}
const observePurchase = () => {
  if(!('IntersectionObserver' in window)) { originalPurchase.classList.add('fallback-purchase'); return; }
  const observer = new IntersectionObserver(entries=>{
    syncBar(); record('context-bar',{visible:needsBar});
  },{root:phoneScroll,threshold:[0,1]});
  observer.observe($('#purchase-origin'));
};
contextBar.addEventListener('focusout',()=>setTimeout(syncBar,0));
function simulatedPurchase(source) { $('#purchase-status').textContent = `✓ Acción de ${source} recibida en la demo. No se hizo una solicitud de compra.`; record('purchase-demo',{source}); }
originalPurchase.addEventListener('click',()=>simulatedPurchase('la página móvil'));
$('#context-purchase').addEventListener('click',()=>simulatedPurchase('la barra móvil'));
$('#desktop-purchase').addEventListener('click',()=>simulatedPurchase('escritorio'));
$('#scroll-demo').addEventListener('click',()=>phoneScroll.scrollTo({top:700,behavior:'auto'}));
$('#phone-back').addEventListener('click',()=>phoneScroll.scrollTo({top:0,behavior:'auto'}));

function reset(which) {
  if(which === 'overlay') { finalizeClose(false); $('#filter-result').textContent='Los filtros son una simulación local.'; $$('#dialog-filters input').forEach(i=>i.checked=false); $('#search-input').value='';$('#search-input').dispatchEvent(new Event('input')); }
  if(which === 'gallery') {
    gallerySequence++; clearTimeout(galleryTimer); clearGalleryTransition(); selectedVariant='shoulder'; shownVariant='shoulder';
    $('#product-image').src='assets/home_bag_shoulder.webp';$('#product-image').alt='Silueta de hombro, imagen de muestra';
    $('#gallery-badge').textContent='Hombro';$('#sample-price').textContent=variants.shoulder.price;
    $('#gallery-network').value='normal'; $$('.variant').forEach(b=>{b.classList.toggle('selected',b.dataset.variant==='shoulder');b.setAttribute('aria-pressed',String(b.dataset.variant==='shoulder'));});
    $('.gallery-frame').setAttribute('aria-busy','false');$('#gallery-status').className='reserved-status';$('#gallery-status').textContent='Mostrando Hombro. Imagen de muestra.';
  }
  if(which === 'feedback') {
    clearTimeout(addTimer);clearTimeout(quantityTimer);quantitySequence++;adding=false;cartCount=0;
    $('#cart-count').textContent='0';$('.cart-count').setAttribute('aria-label','0 unidades confirmadas en la bolsa demo');setQuantity(0);$('#add-label').textContent='Agregar a bolsa demo';$('#add-demo').removeAttribute('aria-disabled');$('#add-demo').removeAttribute('aria-busy');$('#action-result').value='success';$('#cart-status').className='reserved-status';$('#cart-status').textContent='Bolsa demo vacía. No hay conexión con Shopify.';$('#quantity-status').textContent='El total confirmado aparece arriba.';
  }
  if(which === 'discovery') {
    clearTimeout(previewTimer);$('#preview-product').classList.remove('previewing');$('#discovery-card').classList.remove('expressive');$('[name=expression][value=quiet]').checked=true;$('#save-product').setAttribute('aria-pressed','false');$('#save-product').setAttribute('aria-label','Guardar bolsa de hombro en esta sesión');$('#save-status').textContent='Sin guardar · sólo esta sesión.';$('#preview-status').textContent='Prueba Tab para llegar a la imagen y luego al corazón. Pulsa para ver una respuesta local.';
  }
  if(which === 'disclosure') { $$('#disclosure details').forEach((el,i)=>el.open=i===0);$('#shipping-status').textContent=''; }
  if(which === 'purchase') { phoneScroll.scrollTo({top:0,behavior:'auto'}); needsBar=false;syncBar();$('#purchase-status').textContent='Desplaza el marco o usa sus controles con Tab.'; }
  record('reset',{which});
}
$$('[data-reset]').forEach(b=>b.addEventListener('click',()=>reset(b.dataset.reset)));
$('#reset-all').addEventListener('click',()=>{
  running.forEach(a=>a.cancel());['overlay','gallery','feedback','discovery','disclosure','purchase'].forEach(reset);
});
['comparison','motion','pace'].forEach(id=>$(`#${id}`).addEventListener('change',preferences));
systemMotion.addEventListener('change',preferences);
preferences(); observePurchase();
window.labEvidence = { getLog:()=>[...log], getState:()=>({reduced:reduced(),dialogPhase,selectedVariant,shownVariant,cartCount,quantity,adding,needsBar}), reset };
