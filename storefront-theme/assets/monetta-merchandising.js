/* Guest saved/recent lists contain handles only. Cards, prices and stock are always fetched from Shopify. */
(() => {
  'use strict';
  const root = window.MonettaConfig?.routes?.root || '/';
  const key = name => `monetta.web.${name}.v1`;
  const valid = value => typeof value === 'string' && /^[a-z0-9][a-z0-9-]{0,240}$/.test(value);
  const memory = {};
  const read = name => {
    if (memory[name]) return memory[name];
    try { const value = JSON.parse(localStorage.getItem(key(name)) || '[]'); return Array.isArray(value) ? [...new Set(value.filter(valid))].slice(0,24) : []; }
    catch { return memory[name] || []; }
  };
  const write = (name,value) => { try { localStorage.setItem(key(name),JSON.stringify(value)); delete memory[name]; } catch { memory[name] = value; } };
  const sync = () => {
    const saved = read('saved');
    document.querySelectorAll('[data-save-product]').forEach(button => {
      button.hidden = false;
      const active = saved.includes(button.dataset.saveProduct);
      button.setAttribute('aria-pressed',String(active));
      button.setAttribute('aria-label',`${active ? 'Quitar de guardados:' : 'Guardar'} ${button.dataset.productTitle || 'esta pieza'}`);
    });
    document.querySelectorAll('[data-saved-entry]').forEach(button => { button.hidden = false; });
  };
  const html = async url => {
    const response = await fetch(url,{signal:AbortSignal.timeout(12000)});
    if (!response.ok) throw new Error('No se pudo cargar');
    return new DOMParser().parseFromString(await response.text(),'text/html');
  };
  async function cards(handles,target) {
    const results = await Promise.allSettled(handles.map(async handle => {
      const page = await html(`${root}products/${encodeURIComponent(handle)}?section_id=monetta-product-card`);
      const card = page.querySelector('.card');
      if (!card) throw new Error('Pieza no disponible');
      return card;
    }));
    target.replaceChildren();
    let failures = 0;
    results.forEach(result => {
      if (result.status !== 'fulfilled') { failures++; return; }
      if (target.tagName === 'UL') { const li = document.createElement('li'); li.append(result.value); target.append(li); }
      else target.append(result.value);
    });
    sync();
    return failures;
  }
  let savedRun = 0;
  async function showSaved() {
    const target = document.querySelector('[data-saved-grid]');
    const status = document.querySelector('[data-saved-status]');
    if (!target || !status) return;
    const run = ++savedRun;
    const handles = read('saved');
    status.textContent = handles.length ? 'Cargando tus piezas…' : 'Aún no has guardado piezas.';
    const emptyState = document.querySelector('[data-saved-empty]');
    if (emptyState) emptyState.hidden = handles.length > 0;
    // Stage offscreen so a slower older request cannot replace a newer list.
    const staged = document.createElement('div');
    const failures = await cards(handles,staged);
    if (run !== savedRun) return;
    target.replaceChildren(...staged.childNodes);
    status.textContent = failures ? 'Algunas piezas no se pudieron cargar. Cierra y vuelve a abrir para intentar de nuevo.' : handles.length ? `${handles.length} ${handles.length === 1 ? 'pieza guardada' : 'piezas guardadas'}.` : 'Aún no has guardado piezas.';
    const empty = document.querySelector('[data-saved-empty]');
    if (empty) empty.hidden = handles.length > 0;
    sync();
  }
  document.addEventListener('click',event => {
    const button = event.target.closest('[data-save-product]');
    if (!button) return;
    const handle = button.dataset.saveProduct;
    if (!valid(handle)) return;
    const saved = read('saved');
    const active = saved.includes(handle);
    write('saved',active ? saved.filter(value => value !== handle) : [handle,...saved].slice(0,24));
    sync();
    window.Monetta?.announce?.(active ? 'Pieza eliminada de guardados.' : 'Pieza guardada.');
    if (button.closest('#saved-products')) showSaved();
  });
  document.addEventListener('monetta:dialog-open',event => { if (event.target.id === 'saved-products') showSaved(); });
  window.addEventListener('storage',event => { if (event.key === key('saved')) { sync(); if (document.querySelector('#saved-products')?.open) showSaved(); } });
  new MutationObserver(sync).observe(document.querySelector('#MainContent') || document.body,{childList:true,subtree:true});
  async function discovery() {
    const recent = document.querySelector('[data-recent-products]');
    if (recent) {
      const handle = recent.dataset.recentProducts;
      const previous = read('recent').filter(value => value !== handle).slice(0,8);
      if (valid(handle)) write('recent',[handle,...previous].slice(0,12));
      if (previous.length) { await cards(previous,recent.querySelector('[data-recent-track]')); recent.hidden = !recent.querySelector('.card'); }
    }
  }
  async function sameBrand() {
    const rail = document.querySelector('[data-brand-rail]');
    if (!rail) return;
    try {
      const query = new URLSearchParams({type:'product',q:rail.dataset.brandRail,section_id:'monetta-brand-products'});
      const page = await html(`${window.MonettaConfig.routes.search}?${query}`);
      const items = [...page.querySelectorAll('[data-brand-results] > li')].filter(li => li.querySelector('.card')?.dataset.productHandle !== rail.dataset.currentProduct).slice(0,8);
      rail.querySelector('[data-brand-products]').replaceChildren(...items);
      rail.hidden = !items.length;
      sync();
    } catch { /* Generic Shopify recommendations remain available. */ }
  }
  sync(); discovery(); sameBrand();
  // Theme editor: a re-rendered discovery section gets its rails filled again (recording the visit is idempotent).
  document.addEventListener('shopify:section:load',event => {
    if (event.target.querySelector?.('[data-recent-products],[data-brand-rail]')) { discovery(); sameBrand(); }
    sync();
  });
})();
