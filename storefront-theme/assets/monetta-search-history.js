// One history shared by the search page and every predictive field. Storage may be blocked by the browser.
(() => {
  'use strict';
  if (window.MonettaSearchHistory) return;
  const key = 'monetta:recent-searches';
  const event = 'monetta:recent-searches-change';
  let memory = [];
  const normalize = (terms) => {
    const seen = new Set();
    return terms.filter((term) => typeof term === 'string').map((term) => term.trim().replace(/\s+/g, ' ').slice(0, 200)).filter((term) => {
      const lower = term.toLocaleLowerCase();
      if (!term || seen.has(lower)) return false;
      seen.add(lower);
      return true;
    }).slice(0, 5);
  };
  const read = () => {
    try {
      const stored = JSON.parse(localStorage.getItem(key) || '[]');
      memory = normalize(Array.isArray(stored) ? stored : []);
    } catch { /* Retain the document's history when storage is unavailable. */ }
    return [...memory];
  };
  const write = (terms) => {
    memory = normalize(terms);
    try { localStorage.setItem(key, JSON.stringify(memory)); }
    catch { /* The document's in-memory history remains usable. */ }
    window.dispatchEvent(new Event(event));
  };
  window.MonettaSearchHistory = {
    read,
    remember: (term) => { if (typeof term === 'string' && term.trim()) write([term, ...read()]); },
    remove: (term) => write(read().filter((value) => value !== term)),
  };
  window.addEventListener('storage', (change) => {
    if (change.key === key || change.key === null) window.dispatchEvent(new Event(event));
  });
})();
