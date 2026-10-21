// Prototype state: cart, guest favourites, recent searches, recently viewed
// and the demo switches. Everything is local to this browser.
import { addToCart, cartTotals, removeLine, setLineQuantity } from './cart.js';
import { findVariant, productByHandle } from './catalog.js';
import { readJson, readSession, setStorageBlocked, storageAvailable, writeJson, writeSession, clearAll } from './storage.js';

const listeners = new Set();

const DEMO_DEFAULTS = { failNextAdd: false, searchError: false, resultsError: false, slowNetwork: false, storageBlocked: false };

const state = {
  cart: sanitizeCart(readJson('cart', [])),
  favorites: readJson('favorites', []),
  recentSearches: readJson('recent-searches', []),
  recentlyViewed: readJson('recently-viewed', []),
  demo: { ...DEMO_DEFAULTS, ...readSession('demo', {}) },
};

function sanitizeCart(lines) {
  if (!Array.isArray(lines)) return [];
  return lines.filter((line) => line && findVariant(line.variantId) && Number.isInteger(line.quantity) && line.quantity > 0);
}

function emit(change) {
  for (const listener of listeners) listener(state, change);
}

export function subscribe(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function getState() {
  return state;
}

export function resolveLine(line) {
  return findVariant(line.variantId);
}

export function totals() {
  return cartTotals(state.cart, resolveLine);
}

export function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Simulated round trip so pending states can be seen and tested. */
export function networkDelay(base = 650) {
  return delay(state.demo.slowNetwork ? base * 3.5 : base);
}

let addInFlight = false;

/**
 * Adds an exact variant after a simulated request. While one add is pending,
 * further calls are refused, so a double click never adds two units.
 */
export async function addVariant(product, variant, quantity = 1) {
  if (addInFlight) return { status: 'busy' };
  addInFlight = true;
  emit({ type: 'add-pending', variantId: variant?.id });
  try {
    await networkDelay();
    if (state.demo.failNextAdd) {
      state.demo.failNextAdd = false;
      writeSession('demo', state.demo);
      emit({ type: 'demo' });
      return { status: 'failed' };
    }
    const result = addToCart(state.cart, product, variant, quantity);
    if (result.added > 0) {
      state.cart = result.lines;
      writeJson('cart', state.cart);
    }
    return result;
  } finally {
    addInFlight = false;
    emit({ type: 'cart', variantId: variant?.id });
  }
}

export function isAddPending() {
  return addInFlight;
}

export function updateQuantity(variantId, quantity) {
  const found = findVariant(variantId);
  if (!found) return { limited: false };
  const result = setLineQuantity(state.cart, found.variant, quantity);
  state.cart = result.lines;
  writeJson('cart', state.cart);
  emit({ type: 'cart', variantId });
  return result;
}

export function removeFromCart(variantId) {
  const removed = state.cart.find((line) => line.variantId === variantId) ?? null;
  state.cart = removeLine(state.cart, variantId);
  writeJson('cart', state.cart);
  emit({ type: 'cart', variantId });
  return removed;
}

export function restoreLine(line, index) {
  if (!line || state.cart.some((existing) => existing.variantId === line.variantId)) return;
  const next = [...state.cart];
  next.splice(Math.min(index, next.length), 0, line);
  state.cart = next;
  writeJson('cart', state.cart);
  emit({ type: 'cart', variantId: line.variantId });
}

export function isFavorite(handle) {
  return state.favorites.includes(handle);
}

export function toggleFavorite(handle) {
  const saved = isFavorite(handle);
  state.favorites = saved ? state.favorites.filter((item) => item !== handle) : [handle, ...state.favorites];
  const persisted = writeJson('favorites', state.favorites);
  emit({ type: 'favorites', handle });
  return { saved: !saved, persisted };
}

export function favoriteEntries() {
  return state.favorites.map((handle) => ({ handle, product: productByHandle(handle) }));
}

export function addRecentSearch(query) {
  const value = query.trim();
  if (!value) return;
  state.recentSearches = [value, ...state.recentSearches.filter((item) => item.toLowerCase() !== value.toLowerCase())].slice(0, 6);
  writeJson('recent-searches', state.recentSearches);
  emit({ type: 'searches' });
}

export function forgetSearch(query) {
  state.recentSearches = state.recentSearches.filter((item) => item !== query);
  writeJson('recent-searches', state.recentSearches);
  emit({ type: 'searches' });
}

export function clearSearches() {
  state.recentSearches = [];
  writeJson('recent-searches', state.recentSearches);
  emit({ type: 'searches' });
}

export function recordView(handle) {
  state.recentlyViewed = [handle, ...state.recentlyViewed.filter((item) => item !== handle)].slice(0, 12);
  writeJson('recently-viewed', state.recentlyViewed);
}

export function recentlyViewed(excludeHandle) {
  return state.recentlyViewed
    .filter((handle) => handle !== excludeHandle)
    .map(productByHandle)
    .filter(Boolean);
}

export function setDemo(key, value) {
  state.demo[key] = value;
  if (key === 'storageBlocked') setStorageBlocked(value);
  writeSession('demo', state.demo);
  emit({ type: 'demo', key });
}

export function isStoragePersistent() {
  return storageAvailable();
}

export function resetDemoState() {
  clearAll();
  state.cart = [];
  state.favorites = [];
  state.recentSearches = [];
  state.recentlyViewed = [];
  for (const key of Object.keys(DEMO_DEFAULTS)) state.demo[key] = DEMO_DEFAULTS[key];
  setStorageBlocked(false);
  writeSession('demo', state.demo);
  emit({ type: 'reset' });
}

/** Demo control: a favourite whose product left the catalog. */
export function addUnavailableFavorite() {
  const handle = 'bolsa-retirada-del-catalogo-demo';
  if (!state.favorites.includes(handle)) state.favorites = [handle, ...state.favorites];
  writeJson('favorites', state.favorites);
  emit({ type: 'favorites', handle });
}
